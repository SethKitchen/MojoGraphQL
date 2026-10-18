# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The index arithmetic of the QPACK dynamic table (RFC 9204 section 3.2).

Each entry of the dynamic table has an absolute index. A field line names
an entry relative to the base of its field section, before or after it; an
encoder instruction names one relative to the insert count.
`VirtualAddressSpace` turns those indexes into the position of a live
entry, 0 for the oldest, and refuses an index of an evicted entry or of an
entry that does not exist.

This module ports `h3/src/qpack/vas.rs` of hyperium/h3 h3-v0.0.8
(22c1aa3), MIT.

Differences from upstream: the methods raise `H3Error` in place of
returning a `Result`. The absolute indexes stay 1-based, as upstream's are.
"""

from gql_http3.error import H3Error, H3ErrorCode


def index_error(what: StaticString, index: Int) -> H3Error:
    """Return the error of an index that names no live entry.

    Args:
        what: The kind of index, such as `relative`.
        index: The index.

    Returns:
        A `QPACK_DECOMPRESSION_FAILED` error.
    """
    return H3Error(what: StaticString, index: Int) -> H3Error:
    """Return the error of an index that names no live entry."""
    return H3Error(
        H3ErrorCode.QPACK_DECOMPRESSION_FAILED,
        String("bad ", what, " index ", index),
    )


@fieldwise_init
struct VirtualAddressSpace(ImplicitlyCopyable, Writable):
    """The counts of inserted and dropped entries, and the index rules.

    An absolute index here is 1-based: the first insertion returns 1.
    """

    var inserted: Int
    """The number of entries ever inserted."""
    var dropped: Int
    """The number of entries evicted."""
    var delta: Int
    """The number of live entries."""

    def __init__(out self):
        """Make the space of an empty table."""
        self.inserted = 0
        self.dropped = 0
        self.delta = 0

    def add(mut self) -> Int:
        """Count an insertion.

        Returns:
            The 1-based absolute index of the new entry.
        """
        self.inserted += 1
        self.delta += 1
        return self.inserted

    def drop(mut self):
        """Count the eviction of the oldest entry."""
        self.dropped += 1
        self.delta -= 1

    def relative(self, index: Int) raises H3Error -> Int:
        """Return the position of an entry relative to the insert count.

        Args:
            index: 0 for the newest entry.

        Returns:
            The position among the live entries, 0 for the oldest.

        Raises:
            H3Error: For an index of no live entry.
        """
        if (
            self.inserted < index
            or self.delta == 0
            or self.inserted - index <= self.dropped
        ):
            raise index_error("relative", index)
        return self.inserted - self.dropped - index - 1

    def evicted(self, index: Int) -> Bool:
        """Return True when an entry was evicted.

        Args:
            index: A 1-based absolute index.

        Returns:
            Whether the entry is gone.
        """
        return index != 0 and index <= self.dropped

    def relative_base(self, base: Int, index: Int) raises H3Error -> Int:
        """Return the position of an entry before a base.

        Args:
            base: The base of the field section.
            index: 0 for the entry just before the base.

        Returns:
            The position among the live entries.

        Raises:
            H3Error: For an index of no live entry.
        """
        if self.delta == 0 or index > base or base - index <= self.dropped:
            raise index_error("relative", index)
        return base - self.dropped - index - 1

    def post_base(self, base: Int, index: Int) raises H3Error -> Int:
        """Return the position of an entry at or after a base.

        Args:
            base: The base of the field section.
            index: 0 for the entry at the base.

        Returns:
            The position among the live entries.

        Raises:
            H3Error: For an index of no live entry.
        """
        if (
            self.delta == 0
            or base + index >= self.inserted
            or base + index < self.dropped
        ):
            raise index_error("post-base", index)
        return base + index - self.dropped

    def index(self, position: Int) raises H3Error -> Int:
        """Return the 1-based absolute index of a live entry.

        Args:
            position: The position, 0 for the oldest live entry.

        Returns:
            The absolute index.

        Raises:
            H3Error: For a position past the live entries.
        """
        if position >= self.delta:
            raise index_error("real", position)
        return position + self.dropped + 1

    def largest_ref(self) -> Int:
        """Return the number of live entries.

        Returns:
            Inserted minus dropped.
        """
        return self.inserted - self.dropped

    def total_inserted(self) -> Int:
        """Return the insert count.

        Returns:
            The number of entries ever inserted.
        """
        return self.inserted

    def write_to(self, mut writer: Some[Writer]):
        """Write the three counts.

        Args:
            writer: The destination.
        """
        writer.write(
            "inserted ", self.inserted, " dropped ", self.dropped, " live ",
            self.delta,
        )
