# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Paths into a response: fields, lists and type conditions.

Port of Hive Router `1a29df9` `bin/router/src/query_planner/ast/merge_path.rs`.

A `Segment` holds only symbols and ids, so a `MergePath` is a list of
plain values. A field segment keeps the field name, the alias, the
argument map id (the upstream arguments hash) and the condition. A type
condition keeps an interned type set.
"""

from gql_router.ast import NONE, Cond
from gql_router.store import Store


@fieldwise_init
struct SegmentKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of a path segment."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime FIELD = SegmentKind(0)
    """A field, by response key, arguments and condition."""
    comptime LIST = SegmentKind(1)
    """A step into a list, written `@`."""
    comptime TYPE_CONDITION = SegmentKind(2)
    """A type condition, written `|[A|B]`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the three kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2


@fieldwise_init
struct Segment(Equatable, ImplicitlyCopyable, Movable):
    """One step of a `MergePath`, as upstream `Segment`."""

    var kind: SegmentKind
    """What the step is."""
    var name: Int
    """The field name, for a field."""
    var alias: Int
    """The field alias, or `NONE`."""
    var args: Int
    """The argument map id of a field: upstream's arguments hash."""
    var types: Int
    """The type set of a type condition."""
    var cond: Cond
    """The `@skip`/`@include` condition of a field or a type condition."""

    @staticmethod
    def field(name: Int, alias: Int, args: Int, cond: Cond) -> Segment:
        """Return a field segment.

        Args:
            name: The field name.
            alias: The alias, or `NONE`.
            args: The argument map id, or `NONE`.
            cond: The condition.

        Returns:
            The segment.
        """
        return Segment(SegmentKind.FIELD, name, alias, args, NONE, cond)

    @staticmethod
    def list() -> Segment:
        """Return a list segment.

        Returns:
            The segment.
        """
        return Segment(SegmentKind.LIST, NONE, NONE, NONE, NONE, Cond.none())

    @staticmethod
    def type_condition(types: Int, cond: Cond) -> Segment:
        """Return a type condition segment.

        Args:
            types: The type set id.
            cond: The condition.

        Returns:
            The segment.
        """
        return Segment(
            SegmentKind.TYPE_CONDITION, NONE, NONE, NONE, types, cond
        )

    def response_key(self) -> Int:
        """Return the alias of a field segment, or its name.

        Returns:
            The response key, as a symbol.
        """
        return self.alias if self.alias != NONE else self.name


def write_condition(store: Store, mut out: String, cond: Cond):
    """Write a condition as upstream `Condition` `Display`.

    Args:
        store: The store with the variable names.
        out: The destination.
        cond: A condition; it must be some.
    """
    if cond.skip != NONE:
        out += "@skip(if: $"
        out += store.name(cond.skip)
        out += ")"
        if cond.include != NONE:
            out += " "
    if cond.include != NONE:
        out += "@include(if: $"
        out += store.name(cond.include)
        out += ")"


struct MergePath(Copyable, Equatable, Movable, Sized):
    """A path into the response, as upstream `MergePath`."""

    var segments: List[Segment]
    """The steps, from the root."""

    def __init__(out self):
        """Return the empty path."""
        self.segments = List[Segment]()

    def __init__(out self, var segments: List[Segment]):
        """Wrap a list of segments.

        Args:
            segments: The steps.
        """
        self.segments = segments^

    def __eq__(self, other: Self) -> Bool:
        """Return True if two paths have the same steps.

        Args:
            other: The other path.

        Returns:
            Whether every step is equal.
        """
        if len(self.segments) != len(other.segments):
            return False
        for index in range(len(self.segments)):
            if self.segments[index] != other.segments[index]:
                return False
        return True

    def __len__(self) -> Int:
        """Return the number of steps.

        Returns:
            The length.
        """
        return len(self.segments)

    def is_empty(self) -> Bool:
        """Return True if the path has no steps.

        Returns:
            Whether the path is empty.
        """
        return len(self.segments) == 0

    def push(self, segment: Segment) -> MergePath:
        """Return the path with one more step at the end.

        Args:
            segment: The step.

        Returns:
            A new path.
        """
        var out = self.segments.copy()
        out.append(segment)
        return MergePath(out^)

    def slice_from(self, start: Int) -> MergePath:
        """Return the steps from an index on.

        Args:
            start: The first step to keep.

        Returns:
            A new path.
        """
        var out = List[Segment]()
        for index in range(start, len(self.segments)):
            out.append(self.segments[index])
        return MergePath(out^)

    def without_last(self) -> MergePath:
        """Return the path without its last step.

        Returns:
            A new path.
        """
        var out = self.segments.copy()
        _ = out.pop()
        return MergePath(out^)

    def common_prefix_len(self, other: MergePath) -> Int:
        """Return how many leading steps two paths share.

        Args:
            other: The other path.

        Returns:
            The length of the common prefix.
        """
        var total = 0
        var end = min(len(self.segments), len(other.segments))
        while total < end and self.segments[total] == other.segments[total]:
            total += 1
        return total

    def starts_with(self, other: MergePath) -> Bool:
        """Return True if another path is a prefix of this one.

        Args:
            other: The prefix.

        Returns:
            Whether this path starts with every step of `other`.
        """
        if len(other.segments) > len(self.segments):
            return False
        return self.common_prefix_len(other) == len(other.segments)

    def conditions(self) -> List[Cond]:
        """Return the conditions along the path, outermost first.

        Returns:
            The conditions of the field and type condition steps.
        """
        var out = List[Cond]()
        for segment in self.segments:
            if segment.kind != SegmentKind.LIST and segment.cond.is_some():
                out.append(segment.cond)
        return out^

    def without_type_castings(self) -> MergePath:
        """Return the path without its type condition steps.

        Returns:
            A new path.
        """
        var out = List[Segment]()
        for segment in self.segments:
            if segment.kind != SegmentKind.TYPE_CONDITION:
                out.append(segment)
        return MergePath(out^)

    def text(self, store: Store) -> String:
        """Return the path as upstream `Display`, steps joined by `.`.

        Args:
            store: The store with the names.

        Returns:
            Such as `products.@.|[Book] @include(if: $a)`.
        """
        var out = String()
        for index in range(len(self.segments)):
            if index > 0:
                out += "."
            write_segment(store, out, self.segments[index])
        return out^


def write_segment(store: Store, mut out: String, segment: Segment):
    """Write one step as upstream `Segment` `Display`.

    Args:
        store: The store with the names.
        out: The destination.
        segment: The step.
    """
    if segment.kind == SegmentKind.LIST:
        out += "@"
        return
    if segment.kind == SegmentKind.TYPE_CONDITION:
        out += "|["
        ref types = store.type_sets[segment.types]
        for index in range(len(types)):
            if index > 0:
                out += "|"
            out += store.name(types[index])
        out += "]"
    else:
        out += store.name(segment.response_key())
    if segment.cond.is_some():
        out += " "
        write_condition(store, out, segment.cond)
