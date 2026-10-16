# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An in-memory cache with a size limit, which drops the least recently
used entry first.

Port of the `InMemoryLRUCache` of `@apollo/utils.keyvaluecache` 4.0.0
(MIT), which Apollo Server 5.5.1 uses for its document store and for
automatic persisted queries, with the parts of `lru-cache` 11.5.3 that it
uses: `maxSize`, a size per entry, and a time to live per entry.

**Differences from upstream.**
- The caller gives the size of each entry. Upstream computes it with
  `sizeCalculation`: the length of a string, or the length of the JSON of
  an object.
- The caller gives the time, in nanoseconds of a monotonic clock, so that
  a test can move it.
"""

from std.collections import Dict


comptime DEFAULT_MAX_SIZE = 30 * 1024 * 1024
"""The size limit of upstream: `Math.pow(2, 20) * 30`."""


struct InMemoryLRUCache[V: Copyable & Deinitable](Movable, Sized):
    """A map from strings to values, with a limit on the sum of the sizes
    of the entries: upstream `InMemoryLRUCache`.

    The entries are in a ring by use. Link 0 is the ring's anchor, and the
    entry in slot `s` is link `s + 1`.
    """

    var max_size: Int
    """The most that the sizes of the entries can add up to."""
    var total_size: Int
    """The sum of the sizes of the entries."""
    var _index: Dict[String, Int]
    var _keys: List[String]
    var _values: List[Self.V]
    var _sizes: List[Int]
    var _expires: List[Int]
    var _newer: List[Int]
    var _older: List[Int]

    def __init__(out self, max_size: Int = DEFAULT_MAX_SIZE):
        """Make an empty cache.

        Args:
            max_size: The most that the sizes of the entries can add up to.
        """
        self.max_size = max_size
        self.total_size = 0
        self._index = Dict[String, Int]()
        self._keys = List[String]()
        self._values = List[Self.V]()
        self._sizes = List[Int]()
        self._expires = List[Int]()
        self._newer = [0]
        self._older = [0]

    def __len__(self) -> Int:
        """Return the count of entries.

        Returns:
            The count.
        """
        return len(self._keys)

    def _unlink(mut self, link: Int):
        self._older[self._newer[link]] = self._older[link]
        self._newer[self._older[link]] = self._newer[link]

    def _link_newest(mut self, link: Int):
        var newest = self._older[0]
        self._newer[link] = 0
        self._older[link] = newest
        self._newer[newest] = link
        self._older[0] = link

    def _remove(mut self, slot: Int):
        """Drop the entry of a slot. The entry of the last slot moves into
        it, and keeps its place in the ring."""
        self._unlink(slot + 1)
        self.total_size -= self._sizes[slot]
        _ = self._index.pop(self._keys[slot], -1)
        var last = len(self._keys) - 1
        if slot < last:
            var newer = self._newer[last + 1]
            var older = self._older[last + 1]
            self._newer[slot + 1] = newer
            self._older[slot + 1] = older
            self._older[newer] = slot + 1
            self._newer[older] = slot + 1
            var key = self._keys.pop()
            var value = self._values.pop()
            var size = self._sizes.pop()
            var expires = self._expires.pop()
            self._index[key] = slot
            self._keys[slot] = key^
            self._values[slot] = value^
            self._sizes[slot] = size
            self._expires[slot] = expires
        else:
            _ = self._keys.pop()
            _ = self._values.pop()
            _ = self._sizes.pop()
            _ = self._expires.pop()
        _ = self._newer.pop()
        _ = self._older.pop()

    def get(mut self, key: String, now_ns: Int) -> Optional[Self.V]:
        """Return the value of a key, and make it the most recently used.

        Args:
            key: The key.
            now_ns: The time now.

        Returns:
            A copy of the value, or None when the key is missing or its
            entry has expired. An expired entry is dropped.
        """
        var found = self._index.get(key)
        if not found:
            return None
        var slot = found.value()
        if self._expires[slot] != 0 and now_ns >= self._expires[slot]:
            self._remove(slot)
            return None
        self._unlink(slot + 1)
        self._link_newest(slot + 1)
        return self._values[slot].copy()

    def set(
        mut self,
        key: String,
        var value: Self.V,
        size: Int,
        now_ns: Int,
        ttl_seconds: Int = 0,
    ):
        """Store a value, and drop the least recently used entries until
        the sizes fit `max_size`.

        Args:
            key: The key.
            value: The value.
            size: The size of the entry. An entry larger than `max_size`
                is not stored, and the key's old entry is dropped.
            now_ns: The time now.
            ttl_seconds: The seconds the entry lives; 0 for no limit.
        """
        var expires = now_ns + ttl_seconds * 1_000_000_000 if ttl_seconds > 0 else 0
        var found = self._index.get(key)
        if size > self.max_size:
            if found:
                self._remove(found.value())
            return
        if found:
            var slot = found.value()
            self.total_size += size - self._sizes[slot]
            self._values[slot] = value^
            self._sizes[slot] = size
            self._expires[slot] = expires
            self._unlink(slot + 1)
            self._link_newest(slot + 1)
        else:
            var slot = len(self._keys)
            self._index[key] = slot
            self._keys.append(key)
            self._values.append(value^)
            self._sizes.append(size)
            self._expires.append(expires)
            self._newer.append(0)
            self._older.append(0)
            self._link_newest(slot + 1)
            self.total_size += size
        while self.total_size > self.max_size:
            self._remove(self._newer[0] - 1)

    def delete(mut self, key: String) -> Bool:
        """Drop the entry of a key.

        Args:
            key: The key.

        Returns:
            Whether the key had an entry.
        """
        var found = self._index.get(key)
        if not found:
            return False
        self._remove(found.value())
        return True
