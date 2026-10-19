# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Apply subgraph response header rules.

Port of `apply_subgraph_response_headers` and
`ResponseHeaderAggregator::write` in Hive Router `1a29df9`
`bin/router/src/executor/headers/response.rs`, for named propagate,
static insert, and named remove.

Global rules run first. Rules for the subgraph run after them. The first
rule to set a header chooses `first`, `last`, or `append`. Hop-by-hop
headers and `content-type` are skipped. `set-cookie` stays a separate
field. Several appended values are joined with a comma and a space.

**Differences from upstream.** Regular expressions and VRL expressions are
not applied. Header names are emitted in first-seen order.
"""

from gql_router.header_rules import header_denied
from gql_router.headers import HeaderMap


@fieldwise_init
struct HeaderAggregateKind(Equatable, ImplicitlyCopyable, Movable):
    """How several subgraph values of one header are combined."""

    var value: UInt8
    """The kind's index. See `is_valid`."""

    comptime FIRST = HeaderAggregateKind(0)
    """Keep the first value."""
    comptime LAST = HeaderAggregateKind(1)
    """Keep the latest value."""
    comptime APPEND = HeaderAggregateKind(2)
    """Keep every value."""

    def is_valid(self) -> Bool:
        """Return True when the value names one of the three strategies.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2


@fieldwise_init
struct ResponseHeaderRule(Copyable, Movable):
    """One response header rule."""

    var kind: UInt8
    """`0` propagates, `1` inserts, and `2` removes."""
    var subgraph: String
    """The subgraph name. Empty when the rule applies to every subgraph."""
    var names: List[String]
    """Header names to copy or remove. An insert uses the first name."""
    var value: String
    """The static value or the propagate default."""
    var has_value: Bool
    """True when `value` is set."""
    var rename: String
    """The destination name for a propagate rule."""
    var has_rename: Bool
    """True when `rename` is set."""
    var strategy: HeaderAggregateKind
    """How later values of the same header combine."""


struct ResponseAggregator(Movable):
    """Header values collected from subgraph responses."""

    var names: List[String]
    """Header names, in first-seen order."""
    var strategies: List[HeaderAggregateKind]
    """The strategy locked by the first write of each name."""
    var values: List[List[String]]
    """The values of each name, parallel to `names`."""

    def __init__(out self):
        """Start an empty aggregator."""
        self.names = List[String]()
        self.strategies = List[HeaderAggregateKind]()
        self.values = List[List[String]]()

    def write(
        mut self, name: String, value: String, strategy: HeaderAggregateKind
    ):
        """Record one header value.

        Args:
            name: The header name.
            value: The header value.
            strategy: The strategy used when the name is new. A later write
                keeps the strategy of the first write.
        """
        var used = strategy
        if _never_join(name):
            used = HeaderAggregateKind.APPEND
        var slot = _slot(self.names, name)
        if slot < 0:
            var first = List[String]()
            first.append(value)
            self.names.append(name)
            self.strategies.append(used)
            self.values.append(first^)
            return
        var stored = self.strategies[slot]
        var current = _copy_strings(self.values[slot])
        if stored == HeaderAggregateKind.FIRST:
            return
        if stored == HeaderAggregateKind.LAST:
            current = List[String]()
            current.append(value)
        else:
            current.append(value)
        _put_values(self.values, slot, current^)

    def remove(mut self, name: String):
        """Remove one header.

        Args:
            name: The header name.
        """
        var slot = _slot(self.names, name)
        if slot < 0:
            return
        var names = List[String]()
        var strategies = List[HeaderAggregateKind]()
        var values = List[List[String]]()
        for index in range(len(self.names)):
            if index == slot:
                continue
            names.append(String(self.names[index]))
            strategies.append(self.strategies[index])
            values.append(_copy_strings(self.values[index]))
        self.names = names^
        self.strategies = strategies^
        self.values = values^

    def client_headers(self) -> HeaderMap:
        """Return the headers for the client response.

        Returns:
            One field for a normal header. Appended values are joined with
            a comma and a space. `set-cookie` stays a separate field.
        """
        var headers = HeaderMap()
        var limit = len(self.names)
        if len(self.values) < limit:
            limit = len(self.values)
        for index in range(limit):
            var current = _copy_strings(self.values[index])
            if len(current) == 0:
                continue
            if _never_join(self.names[index]):
                for place in range(len(current)):
                    headers.append_value(self.names[index], current[place])
                continue
            if len(current) == 1:
                headers.insert(self.names[index], current[0])
                continue
            var joined = String(current[0])
            for place in range(1, len(current)):
                joined = joined + ", " + current[place]
            headers.insert(self.names[index], joined)
        return headers^


def apply_response_headers(
    rules: List[ResponseHeaderRule],
    subgraph: String,
    subgraph_headers: HeaderMap,
    mut aggregated: ResponseAggregator,
):
    """Apply response header rules from one subgraph.

    Args:
        rules: The rules. Global rules run before subgraph rules.
        subgraph: The subgraph name.
        subgraph_headers: The headers from that subgraph.
        aggregated: The headers collected so far.
    """
    _apply_scope(rules, String(""), subgraph_headers, aggregated)
    _apply_scope(rules, subgraph, subgraph_headers, aggregated)


def response_header_denied(name: String) -> Bool:
    """Return True when a response header must not reach the client.

    Args:
        name: The header name.

    Returns:
        Whether the name is hop-by-hop or `content-type`.
    """
    if header_denied(name):
        return True
    return _lower_text(name) == "content-type"


def _apply_scope(
    rules: List[ResponseHeaderRule],
    scope: String,
    subgraph_headers: HeaderMap,
    mut aggregated: ResponseAggregator,
):
    """Apply the rules whose subgraph is `scope`.

    Args:
        rules: The rules.
        scope: Empty for global rules, or the subgraph name.
        subgraph_headers: The headers from the subgraph.
        aggregated: The headers collected so far.
    """
    for index in range(len(rules)):
        if rules[index].subgraph != scope:
            continue
        _apply_one(rules[index], subgraph_headers, aggregated)


def _apply_one(
    rule: ResponseHeaderRule,
    subgraph_headers: HeaderMap,
    mut aggregated: ResponseAggregator,
):
    """Apply one response rule.

    Args:
        rule: The rule.
        subgraph_headers: The headers from the subgraph.
        aggregated: The headers collected so far.
    """
    if rule.kind == 0:
        _propagate(rule, subgraph_headers, aggregated)
        return
    if rule.kind == 1:
        _insert(rule, aggregated)
        return
    if rule.kind == 2:
        _remove(rule, aggregated)


def _propagate(
    rule: ResponseHeaderRule,
    subgraph_headers: HeaderMap,
    mut aggregated: ResponseAggregator,
):
    """Copy named subgraph headers, or the default when none match.

    Args:
        rule: The propagate rule.
        subgraph_headers: The headers from the subgraph.
        aggregated: The headers collected so far.
    """
    var matched = False
    for index in range(len(rule.names)):
        if response_header_denied(rule.names[index]):
            continue
        var values = subgraph_headers.values_of(rule.names[index])
        if len(values) == 0:
            continue
        var destination = String(rule.names[index])
        if rule.has_rename:
            destination = String(rule.rename)
        if response_header_denied(destination):
            continue
        var limit = len(values)
        if not _never_join(rule.names[index]):
            limit = 1
        for place in range(limit):
            aggregated.write(destination, values[place], rule.strategy)
            matched = True
    if matched or not rule.has_value or len(rule.names) == 0:
        return
    var destination = String(rule.names[0])
    if rule.has_rename:
        destination = String(rule.rename)
    if response_header_denied(destination):
        return
    aggregated.write(destination, rule.value, rule.strategy)


def _insert(rule: ResponseHeaderRule, mut aggregated: ResponseAggregator):
    """Set a static response header.

    Args:
        rule: The insert rule.
        aggregated: The headers collected so far.
    """
    if len(rule.names) == 0 or response_header_denied(rule.names[0]):
        return
    var strategy = rule.strategy
    if _never_join(rule.names[0]):
        strategy = HeaderAggregateKind.APPEND
    aggregated.write(rule.names[0], rule.value, strategy)


def _remove(rule: ResponseHeaderRule, mut aggregated: ResponseAggregator):
    """Remove named response headers.

    Args:
        rule: The remove rule.
        aggregated: The headers collected so far.
    """
    for index in range(len(rule.names)):
        if response_header_denied(rule.names[index]):
            continue
        aggregated.remove(rule.names[index])


def _slot(names: List[String], name: String) -> Int:
    """Return the index of a header name.

    Args:
        names: The header names.
        name: The candidate.

    Returns:
        The index. `-1` when the name is absent. The match ignores ASCII case.
    """
    for index in range(len(names)):
        if _same(names[index], name):
            return index
    return -1


def _put_values(
    mut groups: List[List[String]], slot: Int, var next: List[String]
):
    """Replace the values of one header.

    Args:
        groups: The values of every header.
        slot: The header to replace.
        next: The new values.
    """
    groups[slot] = next^


def _copy_strings(values: List[String]) -> List[String]:
    """Copy a list of strings.

    Args:
        values: The strings.

    Returns:
        The copy.
    """
    var copy = List[String]()
    for index in range(len(values)):
        copy.append(String(values[index]))
    return copy^


def _same(left: String, right: String) -> Bool:
    """Return True when two header names match, ignoring ASCII case.

    Args:
        left: One header name.
        right: The other header name.

    Returns:
        Whether the names are equal.
    """
    return _lower_text(left) == _lower_text(right)


def _never_join(name: String) -> Bool:
    """Return True when multiple values stay separate fields.

    Args:
        name: The header name.

    Returns:
        Whether the name is `set-cookie` or `www-authenticate`.
    """
    var lower = _lower_text(name)
    return lower == "set-cookie" or lower == "www-authenticate"


def _lower_text(text: String) -> String:
    """Return ASCII lowercase text.

    Args:
        text: The text.

    Returns:
        The lowercase text.
    """
    var bytes = text.as_bytes()
    var out = String("")
    for index in range(len(bytes)):
        var byte = bytes[index]
        if byte >= 65 and byte <= 90:
            byte = byte + 32
        out += chr(Int(byte))
    return out^
