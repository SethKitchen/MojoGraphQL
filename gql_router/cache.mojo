# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Limits and storage for one router operation cache.

Port of `build_cache` in Hive Router `1a29df9`
`bin/router/src/cache_state.rs`, and of `CacheLimitsConfig` in
`bin/router/src/config/cache.rs`.

A limit of zero entries stores nothing. A time to live or time to idle of
zero is unset. An entry expires on whichever of those two times comes
first. When the cache is full, the oldest inserted entry is removed.

**Differences from upstream.** Upstream stores the policy in the `moka`
cache and reads the system clock. This port takes the current time in
milliseconds on each call. Eviction is the oldest inserted key. Upstream
uses TinyLFU.
"""

from std.collections import Dict
from gql_json.parser import parse
from gql_json.value import NO_NODE, JsonDocument, JsonKind


@fieldwise_init
struct CacheLimits(Copyable, Movable):
    """How many entries a cache keeps, and when they expire."""

    var max_entries: Int
    """The maximum number of entries. Zero stores nothing."""
    var time_to_live_ms: Int
    """Milliseconds after a write before expiry. Zero means no time to live."""
    var time_to_idle_ms: Int
    """Milliseconds after the last read or write before expiry. Zero means
    no time to idle."""

    def with_max_entries(self, max_entries: Int) -> Self:
        """Return limits with a new maximum number of entries.

        Args:
            max_entries: The maximum. Zero stores nothing.

        Returns:
            The new limits.
        """
        return CacheLimits(
            max_entries, self.time_to_live_ms, self.time_to_idle_ms
        )

    def with_time_to_live_ms(self, time_to_live_ms: Int) -> Self:
        """Return limits with a new time to live.

        Args:
            time_to_live_ms: The time in milliseconds. Zero disables it.

        Returns:
            The new limits.
        """
        return CacheLimits(
            self.max_entries, time_to_live_ms, self.time_to_idle_ms
        )

    def with_time_to_idle_ms(self, time_to_idle_ms: Int) -> Self:
        """Return limits with a new time to idle.

        Args:
            time_to_idle_ms: The time in milliseconds. Zero disables it.

        Returns:
            The new limits.
        """
        return CacheLimits(
            self.max_entries, self.time_to_live_ms, time_to_idle_ms
        )


def default_cache_limits() -> CacheLimits:
    """Return the router default: 1000 entries and no expiry.

    Returns:
        The default limits.
    """
    return CacheLimits(1000, 0, 0)


struct RouterCacheConfig(Copyable, Movable):
    """Caches that exist once for the router process."""

    var parsing: CacheLimits
    """Limits for parsed documents."""
    var plugin_supergraph_runtimes: Int
    """How many plugin-selected supergraph runtimes stay cached. Zero
    disables that cache."""

    def __init__(
        out self, parsing: CacheLimits, plugin_supergraph_runtimes: Int
    ):
        """Start process caches.

        Args:
            parsing: Limits for parsed documents.
            plugin_supergraph_runtimes: The runtime cache size.
        """
        self.parsing = parsing.copy()
        self.plugin_supergraph_runtimes = plugin_supergraph_runtimes


struct SupergraphCacheConfig(Copyable, Movable):
    """Caches that exist once for each supergraph."""

    var validation: CacheLimits
    """Limits for validation results."""
    var normalization: CacheLimits
    """Limits for normalized operations."""
    var query_plans: CacheLimits
    """Limits for query plans."""

    def __init__(
        out self,
        validation: CacheLimits,
        normalization: CacheLimits,
        query_plans: CacheLimits,
    ):
        """Start the per-supergraph caches.

        Args:
            validation: Limits for validation results.
            normalization: Limits for normalized operations.
            query_plans: Limits for query plans.
        """
        self.validation = validation.copy()
        self.normalization = normalization.copy()
        self.query_plans = query_plans.copy()


struct CacheConfig(Copyable, Movable):
    """The operation-cache limits for one router."""

    var router: RouterCacheConfig
    """Caches shared by the process."""
    var supergraph: SupergraphCacheConfig
    """Caches copied for each supergraph."""

    def __init__(
        out self, router: RouterCacheConfig, supergraph: SupergraphCacheConfig
    ):
        """Start a cache configuration.

        Args:
            router: The process caches.
            supergraph: The per-supergraph caches.
        """
        self.router = router.copy()
        self.supergraph = supergraph.copy()


def default_cache_config() -> CacheConfig:
    """Return every cache at the router default.

    Returns:
        Parsing, validation, normalization, and query plans at 1000
        entries with no expiry, and 10 plugin supergraph runtimes.
    """
    var limits = default_cache_limits()
    return CacheConfig(
        RouterCacheConfig(limits.copy(), 10),
        SupergraphCacheConfig(limits.copy(), limits.copy(), limits.copy()),
    )


struct CacheOverride(Copyable, Movable):
    """A per-supergraph replacement for one cache.

    A dimension that was never set keeps the router configuration. Setting
    a dimension replaces only that dimension.
    """

    var has_max_entries: Bool
    """Whether `max_entries` replaces the inherited value."""
    var max_entries: Int
    """The replacement maximum. Zero turns the cache off."""
    var has_time_to_live: Bool
    """Whether time to live replaces the inherited value."""
    var time_to_live_ms: Int
    """The replacement time to live. Zero disables it."""
    var has_time_to_idle: Bool
    """Whether time to idle replaces the inherited value."""
    var time_to_idle_ms: Int
    """The replacement time to idle. Zero disables it."""

    def __init__(out self):
        """Start an override that inherits every dimension."""
        self.has_max_entries = False
        self.max_entries = 0
        self.has_time_to_live = False
        self.time_to_live_ms = 0
        self.has_time_to_idle = False
        self.time_to_idle_ms = 0

    def set_max_entries(mut self, max_entries: Int):
        """Replace the maximum number of entries.

        Args:
            max_entries: The maximum. Zero turns the cache off.
        """
        self.has_max_entries = True
        self.max_entries = max_entries

    def set_time_to_live_ms(mut self, time_to_live_ms: Int):
        """Replace the time to live.

        Args:
            time_to_live_ms: The time in milliseconds. Zero disables expiry
                even when the router configuration sets one.
        """
        self.has_time_to_live = True
        self.time_to_live_ms = time_to_live_ms

    def set_time_to_idle_ms(mut self, time_to_idle_ms: Int):
        """Replace the time to idle.

        Args:
            time_to_idle_ms: The time in milliseconds. Zero disables expiry
                even when the router configuration sets one.
        """
        self.has_time_to_idle = True
        self.time_to_idle_ms = time_to_idle_ms

    def disable(mut self):
        """Turn this cache off. This sets the maximum to zero."""
        self.set_max_entries(0)

    def inherit(mut self):
        """Go back to inheriting every dimension from the router."""
        self.has_max_entries = False
        self.max_entries = 0
        self.has_time_to_live = False
        self.time_to_live_ms = 0
        self.has_time_to_idle = False
        self.time_to_idle_ms = 0

    def resolve(self, inherited: CacheLimits) -> CacheLimits:
        """Return the limits to build, given the router configuration.

        Args:
            inherited: The limits from `cache.supergraph`.

        Returns:
            Each dimension from this override when it was set, otherwise
            from `inherited`.
        """
        var max_entries = inherited.max_entries
        if self.has_max_entries:
            max_entries = self.max_entries
        var live = inherited.time_to_live_ms
        if self.has_time_to_live:
            live = self.time_to_live_ms
        var idle = inherited.time_to_idle_ms
        if self.has_time_to_idle:
            idle = self.time_to_idle_ms
        return CacheLimits(max_entries, live, idle)


def _known_key(document: JsonDocument, node: Int, names: List[String]) raises:
    """Reject an object member whose key is not in `names`.

    Args:
        document: The JSON document.
        node: An object.
        names: The keys the object may hold.

    Raises:
        Error: When a member key is not in `names`.
    """
    var child = document.first(node)
    while child != NO_NODE:
        var key = document.key(child)
        var known = False
        # `names` is never empty.
        var index = 0
        while index < len(names):
            if names[index] == key:
                known = True
            index += 1
        if not known:
            raise Error("Unknown cache field " + key)
        child = document.next(child)


def _duration_ms(text: String) raises -> Int:
    """Return milliseconds for a humantime duration such as `30m`.

    Args:
        text: A number and a unit: `ms`, `s`, `m`, or `h`.

    Returns:
        The duration in milliseconds.

    Raises:
        Error: When the text is not a duration.
    """
    var bytes = text.as_bytes()
    var index = 0
    while index < len(bytes) and bytes[index] >= 48 and bytes[index] <= 57:
        index += 1
    if index == 0 or index == len(bytes):
        raise Error("Invalid cache duration " + text)
    var number = 0
    # There is at least one digit.
    var digit = 0
    while digit < index:
        number = number * 10 + Int(bytes[digit] - 48)
        digit += 1
    var unit = String(text[byte=index:])
    if unit == "ms":
        return number
    if unit == "s":
        return number * 1000
    if unit == "m":
        return number * 60000
    if unit == "h":
        return number * 3600000
    raise Error("Invalid cache duration " + text)


def _limits_from(document: JsonDocument, node: Int) raises -> CacheLimits:
    """Read one `CacheLimitsConfig` object.

    Args:
        document: The JSON document.
        node: The object.

    Returns:
        The limits. Missing fields keep the defaults.

    Raises:
        Error: When the node is not an object, a field is unknown, or a
            duration is invalid.
    """
    if document.kind(node) != JsonKind.OBJECT:
        raise Error("Cache limits must be an object")
    var names = List[String]()
    names.append("max_entries")
    names.append("time_to_live")
    names.append("time_to_idle")
    _known_key(document, node, names)
    var limits = default_cache_limits()
    var max_entries = document.find(node, "max_entries")
    if max_entries != NO_NODE:
        limits.max_entries = Int(document.as_int64(max_entries))
    var live = document.find(node, "time_to_live")
    if live != NO_NODE:
        limits.time_to_live_ms = _duration_ms(document.string_value(live))
    var idle = document.find(node, "time_to_idle")
    if idle != NO_NODE:
        limits.time_to_idle_ms = _duration_ms(document.string_value(idle))
    return limits^


def _router_from(document: JsonDocument, node: Int) raises -> RouterCacheConfig:
    """Read a `RouterCacheConfig` object.

    Args:
        document: The JSON document.
        node: The object.

    Returns:
        The process caches.

    Raises:
        Error: When the node is not an object or a field is unknown.
    """
    if document.kind(node) != JsonKind.OBJECT:
        raise Error("Router cache config must be an object")
    var names = List[String]()
    names.append("parsing")
    names.append("plugin_supergraph_runtimes")
    _known_key(document, node, names)
    var parsing = default_cache_limits()
    var parsing_node = document.find(node, "parsing")
    if parsing_node != NO_NODE:
        parsing = _limits_from(document, parsing_node)
    var runtimes = 10
    var runtime_node = document.find(node, "plugin_supergraph_runtimes")
    if runtime_node != NO_NODE:
        runtimes = Int(document.as_int64(runtime_node))
    return RouterCacheConfig(parsing^, runtimes)


def _supergraph_from(
    document: JsonDocument, node: Int
) raises -> SupergraphCacheConfig:
    """Read a `SupergraphCacheConfig` object.

    Args:
        document: The JSON document.
        node: The object.

    Returns:
        The per-supergraph caches.

    Raises:
        Error: When the node is not an object or a field is unknown.
    """
    if document.kind(node) != JsonKind.OBJECT:
        raise Error("Supergraph cache config must be an object")
    var names = List[String]()
    names.append("validation")
    names.append("normalization")
    names.append("query_plans")
    _known_key(document, node, names)
    var validation = default_cache_limits()
    var normalization = default_cache_limits()
    var query_plans = default_cache_limits()
    var validation_node = document.find(node, "validation")
    if validation_node != NO_NODE:
        validation = _limits_from(document, validation_node)
    var normalization_node = document.find(node, "normalization")
    if normalization_node != NO_NODE:
        normalization = _limits_from(document, normalization_node)
    var plans_node = document.find(node, "query_plans")
    if plans_node != NO_NODE:
        query_plans = _limits_from(document, plans_node)
    return SupergraphCacheConfig(validation^, normalization^, query_plans^)


def cache_config_from_json(text: String) raises -> CacheConfig:
    """Read a router cache configuration from JSON.

    Args:
        text: A JSON object. `{}` is the default configuration. A duration
            is a string such as `30m` or `5m`.

    Returns:
        The configuration. A missing object keeps the defaults.

    Raises:
        Error: When the text is not a cache configuration, a field is
            unknown, or a duration is invalid.
        JsonError: When the text is not JSON.
    """
    var document = parse(text)
    if document.kind(0) != JsonKind.OBJECT:
        raise Error("Cache config must be an object")
    var names = List[String]()
    names.append("router")
    names.append("supergraph")
    _known_key(document, 0, names)
    var router = RouterCacheConfig(default_cache_limits(), 10)
    var supergraph = SupergraphCacheConfig(
        default_cache_limits(), default_cache_limits(), default_cache_limits()
    )
    var router_node = document.find(0, "router")
    if router_node != NO_NODE:
        router = _router_from(document, router_node)
    var supergraph_node = document.find(0, "supergraph")
    if supergraph_node != NO_NODE:
        supergraph = _supergraph_from(document, supergraph_node)
    return CacheConfig(router^, supergraph^)


@fieldwise_init
struct _Entry(Copyable, Movable):
    """One stored value and the times used to expire it."""

    var value: String
    """The stored text."""
    var inserted_ms: Int
    """The write time in milliseconds."""
    var accessed_ms: Int
    """The last read or write time in milliseconds."""


struct OperationCache(Movable):
    """A string cache with the router's entry limit and expiry."""

    var limits: CacheLimits
    """The limits that govern this cache."""
    var _keys: List[String]
    """The keys, from the oldest insertion to the newest."""
    var _entries: List[_Entry]
    """The value of each key, parallel to `_keys`."""

    def __init__(out self, limits: CacheLimits):
        """Start an empty cache.

        Args:
            limits: The entry limit and expiry times.
        """
        self.limits = limits.copy()
        self._keys = List[String]()
        self._entries = List[_Entry]()

    def _find(self, key: String) -> Int:
        """Return the position of a key, or -1."""
        var index = 0
        while index < len(self._keys):
            if self._keys[index] == key:
                return index
            index += 1
        return -1

    def insert(mut self, key: String, value: String, now_ms: Int):
        """Store a value, or do nothing when the entry limit is zero.

        When the cache is full, the oldest inserted entry is removed.

        Args:
            key: The cache key.
            value: The stored text.
            now_ms: The current time in milliseconds.
        """
        if self.limits.max_entries == 0:
            return
        self._drop_expired(now_ms)
        var found = self._find(key)
        if found >= 0:
            self._entries[found] = _Entry(value, now_ms, now_ms)
            return
        while len(self._keys) >= self.limits.max_entries:
            self._remove(0)
        self._keys.append(key)
        self._entries.append(_Entry(value, now_ms, now_ms))

    def get(mut self, key: String, now_ms: Int) -> Optional[String]:
        """Return a value and mark it as read.

        Args:
            key: The cache key.
            now_ms: The current time in milliseconds.

        Returns:
            The value, or none when the key is absent or expired.
        """
        self._drop_expired(now_ms)
        var found = self._find(key)
        if found < 0:
            return None
        self._entries[found].accessed_ms = now_ms
        return self._entries[found].value

    def entry_count(mut self, now_ms: Int) -> Int:
        """Return the number of entries that have not expired.

        Args:
            now_ms: The current time in milliseconds.

        Returns:
            The number of unexpired entries.
        """
        self._drop_expired(now_ms)
        return len(self._keys)

    def _expired(self, entry: _Entry, now_ms: Int) -> Bool:
        """Return True if an entry is past its time to live or to idle."""
        var live = self.limits.time_to_live_ms
        if live > 0 and now_ms - entry.inserted_ms >= live:
            return True
        var idle = self.limits.time_to_idle_ms
        if idle > 0 and now_ms - entry.accessed_ms >= idle:
            return True
        return False

    def _drop_expired(mut self, now_ms: Int):
        """Remove every expired entry."""
        var index = 0
        while index < len(self._keys):
            if self._expired(self._entries[index], now_ms):
                self._remove(index)
            else:
                index += 1

    def _remove(mut self, index: Int):
        """Remove the entry at a position."""
        _ = self._keys.pop(index)
        _ = self._entries.pop(index)
