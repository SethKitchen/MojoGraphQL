# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Apply subgraph request header rules.

Port of `modify_subgraph_request_headers` in Hive Router `1a29df9`
`bin/router/src/executor/headers/request.rs`, for named propagate,
static insert, and named remove.

Global rules run first. Rules for the subgraph run after them. Hop-by-hop
headers are skipped. `set-cookie` and `www-authenticate` are appended as
separate fields. A propagate rule uses its default only when no listed
name was present.

**Differences from upstream.** Regular expressions and VRL expressions are
not applied.
"""

from gql_router.headers import HeaderMap


@fieldwise_init
struct HeaderRuleKind(Equatable, ImplicitlyCopyable, Movable):
    """One subgraph request header action."""

    var value: UInt8
    """The kind's index. See `is_valid`."""

    comptime PROPAGATE = HeaderRuleKind(0)
    """Copy named client headers."""
    comptime INSERT = HeaderRuleKind(1)
    """Set a static header."""
    comptime REMOVE = HeaderRuleKind(2)
    """Remove named headers."""

    def is_valid(self) -> Bool:
        """Return True when the value names one of the three actions.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2


@fieldwise_init
struct HeaderRule(Copyable, Movable):
    """One request header rule."""

    var kind: HeaderRuleKind
    """Propagate, insert, or remove."""
    var subgraph: String
    """The subgraph name. Empty when the rule applies to every subgraph."""
    var names: List[String]
    """Header names to copy or remove. An insert uses the first name."""
    var value: String
    """The static value or the propagate default. Empty when there is none."""
    var has_value: Bool
    """True when `value` is set."""
    var rename: String
    """The destination name for a propagate rule. Empty when names stay."""
    var has_rename: Bool
    """True when `rename` is set."""


def apply_request_headers(
    rules: List[HeaderRule],
    subgraph: String,
    client: HeaderMap,
    mut output: HeaderMap,
):
    """Apply request header rules for one subgraph.

    Args:
        rules: The rules. Global rules run before subgraph rules.
        subgraph: The subgraph name.
        client: The client request headers.
        output: The headers sent to the subgraph. Rules update this map.
    """
    _apply_scope(rules, String(""), subgraph, client, output)
    _apply_scope(rules, subgraph, subgraph, client, output)


def header_denied(name: String) -> Bool:
    """Return True when a header must not be forwarded.

    Args:
        name: The header name.

    Returns:
        Whether the name is hop-by-hop, `host`, `content-length`, or
        `content-encoding`.
    """
    var lower = _lower_text(name)
    if lower == "connection" or lower == "keep-alive":
        return True
    if lower == "proxy-authenticate" or lower == "proxy-authorization":
        return True
    if lower == "te" or lower == "trailer" or lower == "transfer-encoding":
        return True
    if lower == "upgrade" or lower == "proxy-connection" or lower == "host":
        return True
    if lower == "content-length" or lower == "content-encoding":
        return True
    return False


def _apply_scope(
    rules: List[HeaderRule],
    scope: String,
    subgraph: String,
    client: HeaderMap,
    mut output: HeaderMap,
):
    """Apply the rules whose subgraph is `scope`.

    Args:
        rules: The rules.
        scope: Empty for global rules, or the subgraph name.
        subgraph: The subgraph being called. Unused for matching.
        client: The client request headers.
        output: The headers sent to the subgraph.
    """
    _ = subgraph
    for index in range(len(rules)):
        if rules[index].subgraph != scope:
            continue
        _apply_one(rules[index], client, output)


def _apply_one(rule: HeaderRule, client: HeaderMap, mut output: HeaderMap):
    """Apply one rule.

    Args:
        rule: The rule.
        client: The client request headers.
        output: The headers sent to the subgraph.
    """
    if rule.kind == HeaderRuleKind.PROPAGATE:
        _propagate(rule, client, output)
        return
    if rule.kind == HeaderRuleKind.INSERT:
        _insert(rule, output)
        return
    if rule.kind == HeaderRuleKind.REMOVE:
        _remove(rule, output)


def _propagate(rule: HeaderRule, client: HeaderMap, mut output: HeaderMap):
    """Copy named client headers, or the default when none match.

    Args:
        rule: The propagate rule.
        client: The client request headers.
        output: The headers sent to the subgraph.
    """
    var matched = False
    for index in range(len(rule.names)):
        if header_denied(rule.names[index]):
            continue
        var values = client.values_of(rule.names[index])
        if len(values) == 0:
            continue
        var destination = String(rule.names[index])
        if rule.has_rename:
            destination = String(rule.rename)
        if header_denied(destination):
            continue
        for place in range(len(values)):
            output.append_value(destination, values[place])
            matched = True
    if matched or not rule.has_value or len(rule.names) == 0:
        return
    var destination = String(rule.names[0])
    if rule.has_rename:
        destination = String(rule.rename)
    if header_denied(destination):
        return
    output.append_value(destination, rule.value)


def _insert(rule: HeaderRule, mut output: HeaderMap):
    """Set a static header.

    Args:
        rule: The insert rule.
        output: The headers sent to the subgraph.
    """
    if len(rule.names) == 0 or header_denied(rule.names[0]):
        return
    if _never_join(rule.names[0]):
        output.append_value(rule.names[0], rule.value)
        return
    output.insert(rule.names[0], rule.value)


def _remove(rule: HeaderRule, mut output: HeaderMap):
    """Remove named headers.

    Args:
        rule: The remove rule.
        output: The headers sent to the subgraph.
    """
    for index in range(len(rule.names)):
        if header_denied(rule.names[index]):
            continue
        output.remove(rule.names[index])


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
