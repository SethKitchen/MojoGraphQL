# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The query planner AST, kept in one store.

Port of Hive Router `1a29df9` `bin/router/src/query_planner/ast/`:
`selection_item.rs`, `selection_set.rs`, `value.rs` and `arguments.rs`.

**One store, not a tree of objects.** Every name is a symbol: an index
into one table of strings. Every argument map is interned, so two equal
maps have the same id. Every selection is an `Item` in one list. A field
and an inline fragment own the run of items below them as a linked list.
A selection set is the item that owns the run: a field, a fragment, or a
`ROOT` item that has no name.

The store only grows. `rollback` cuts the items back to a mark, so a
planner can reuse one store for many plans. Symbols and argument maps
are never cut: a plan adds only a bounded set of them.

**Differences from upstream.** Upstream compares argument maps with
`BTreeMap` equality and hashes them with `DefaultHasher`. This port
interns each map by its canonical text, so the map id is both the equality
and the hash. An `Int(1)` and a `Float(1.0)` stay different, as upstream.
"""

comptime NONE = -1
"""The index that names no symbol, no value, no map and no item."""


@fieldwise_init
struct ValueKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of an argument value, as upstream `Value`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime VARIABLE = ValueKind(0)
    """A `$variable`."""
    comptime INT = ValueKind(1)
    """An integer."""
    comptime FLOAT = ValueKind(2)
    """A float."""
    comptime STRING = ValueKind(3)
    """A string."""
    comptime BOOLEAN = ValueKind(4)
    """A boolean."""
    comptime NULL = ValueKind(5)
    """`null`."""
    comptime ENUM = ValueKind(6)
    """An enum value."""
    comptime LIST = ValueKind(7)
    """A list of values."""
    comptime OBJECT = ValueKind(8)
    """An object of named values."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the nine kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 8


@fieldwise_init
struct Value(ImplicitlyCopyable, Movable):
    """One argument value. A list or an object links its members."""

    var kind: ValueKind
    """What the value is."""
    var number: Int64
    """The integer, or 1 for `true` and 0 for `false`."""
    var real: Float64
    """The float."""
    var text: Int
    """The symbol of a variable name, a string or an enum value."""
    var first: Int
    """The first member of a list or an object, or `NONE`."""
    var next: Int
    """The next member in the parent list or object, or `NONE`."""
    var key: Int
    """The symbol of the field name of an object member, or `NONE`."""


@fieldwise_init
struct Args(Copyable, Movable):
    """One interned argument map, sorted by name."""

    var names: List[Int]
    """The argument names, as symbols, in name order."""
    var values: List[Int]
    """The value of each argument."""
    var text: String
    """The upstream `Display` text: `a: 1, b: "x"`."""
    var variables: List[Int]
    """The variables the values use, as symbols, unique, in name order."""


@fieldwise_init
struct ItemKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of a selection item."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime FIELD = ItemKind(0)
    """A field."""
    comptime FRAGMENT = ItemKind(1)
    """An inline fragment with a type condition."""
    comptime SPREAD = ItemKind(2)
    """A fragment spread."""
    comptime ROOT = ItemKind(3)
    """A selection set that no field or fragment owns."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the four kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 3


@fieldwise_init
struct Item(ImplicitlyCopyable, Movable):
    """One selection: a field, an inline fragment, a spread or a set."""

    var kind: ItemKind
    """What the item is."""
    var omit: Bool
    """Upstream `omit_from_response`, for a field."""
    var name: Int
    """The field name, the type condition, or the spread name."""
    var alias: Int
    """The field alias, or `NONE`."""
    var args: Int
    """The interned argument map, or `NONE` for no arguments."""
    var skip: Int
    """The variable of `@skip(if:)`, or `NONE`."""
    var include: Int
    """The variable of `@include(if:)`, or `NONE`."""
    var first: Int
    """The first child, or `NONE`."""
    var last: Int
    """The last child, or `NONE`."""
    var next: Int
    """The next sibling, or `NONE`."""
    var directives: Int
    """The interned directive list, or `NONE`. Only normalization reads
    it; `skip` and `include` hold what the planner keeps."""


@fieldwise_init
struct Directive(Copyable, Movable):
    """One directive of an operation, kept while it is normalized."""

    var name: Int
    """The directive name, as a symbol."""
    var args: Int
    """The interned argument map, or `NONE`."""
    var if_variable: Int
    """The variable of the first `if` argument, or `NONE`."""
    var if_boolean: Int
    """1 or 0 for a boolean `if` argument, or `NONE`."""


@fieldwise_init
struct Cond(Equatable, ImplicitlyCopyable, Movable):
    """An `@skip`/`@include` condition, as upstream `Option<Condition>`.

    Both variables `NONE` is no condition. Only `skip` is `Skip`, only
    `include` is `Include`, and both is `SkipAndInclude`.
    """

    var skip: Int
    """The variable of `@skip(if:)`, or `NONE`."""
    var include: Int
    """The variable of `@include(if:)`, or `NONE`."""

    @staticmethod
    def none() -> Cond:
        """Return no condition.

        Returns:
            A condition with neither variable.
        """
        return Cond(NONE, NONE)

    def is_some(self) -> Bool:
        """Return True if there is a condition.

        Returns:
            Whether either variable is set.
        """
        return self.skip != NONE or self.include != NONE


def _rust_float_text(value: Float64) -> String:
    """Write a float as Rust `f64` `Display`: shortest digits, no exponent."""
    if value != value:
        return "NaN"
    if value == Float64.MAX_FINITE * 2.0:
        return "inf"
    if value == -Float64.MAX_FINITE * 2.0:
        return "-inf"
    var bytes = String(value).as_bytes()
    var negative = len(bytes) > 0 and Int(bytes[0]) == ord("-")
    # The decimal digits, and how many of them are before the point.
    var digits = List[UInt8]()
    var int_len = 0
    var seen_point = False
    var exponent = 0
    var exponent_sign = 1
    var in_exponent = False
    # `String(Float64)` writes digits, an optional `.`, and an optional
    # `e`, a sign and digits; never an empty text.
    var index = 1 if negative else 0
    while index < len(bytes):
        var byte = Int(bytes[index])
        index += 1
        if in_exponent:
            if byte == ord("-"):
                exponent_sign = -1
            elif byte != ord("+"):
                exponent = exponent * 10 + (byte - ord("0"))
        elif byte == ord("."):
            seen_point = True
        elif byte == ord("e"):
            in_exponent = True
        else:
            digits.append(UInt8(byte))
            if not seen_point:
                int_len += 1
    int_len += exponent * exponent_sign
    while len(digits) > 1 and Int(digits[len(digits) - 1]) == ord("0"):
        _ = digits.pop()
    while len(digits) > 1 and Int(digits[0]) == ord("0"):
        _ = digits.pop(0)
        int_len -= 1
    var out = String("-") if negative else String()
    if len(digits) == 1 and Int(digits[0]) == ord("0"):
        return out + "0"
    var text = String(unsafe_from_utf8=digits)
    if int_len <= 0:
        out += "0."
        for _ in range(-int_len):
            out += "0"
        return out + text
    if int_len >= len(digits):
        out += text
        for _ in range(int_len - len(digits)):
            out += "0"
        return out^
    return out + text[byte=:int_len] + "." + text[byte=int_len:]


def write_graphql_string(mut out: String, text: StringSlice):
    """Write a string as a GraphQL string literal, as upstream
    `write_graphql_string_literal`.

    Args:
        out: The destination.
        text: The decoded string.
    """
    out += '"'
    for cp in text.codepoints():
        var code = Int(cp)
        if code == 0x22:
            out += '\\"'
        elif code == 0x5C:
            out += "\\\\"
        elif code == 0x0A:
            out += "\\n"
        elif code == 0x0D:
            out += "\\r"
        elif code == 0x09:
            out += "\\t"
        elif code == 0x08:
            out += "\\b"
        elif code == 0x0C:
            out += "\\f"
        elif code < 0x20 or code == 0x7F:
            comptime HEX = "0123456789abcdef"
            out += "\\u00"
            out += HEX[byte=(code >> 4) & 15]
            out += HEX[byte=code & 15]
        else:
            out += String(cp)
    out += '"'
