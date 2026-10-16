# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The patterns of fuzzy `possibleTypes` subtypes.

Apollo Client 4.3.3 `Policies.addPossibleTypes` reads a subtype that is
not a plain name, such as `".*Entity"`, as `new RegExp(subtype)`. A
`__typename` is that subtype when `typename.match(regExp)[0] === typename`.
This module matches the part of the ECMAScript `RegExp` syntax that a type
name pattern needs, with the same backtracking order, so the first match
is the ECMAScript first match.

Differences from upstream:

- The syntax is literal characters, `.`, `[...]` and `[^...]` classes with
  ranges, the quantifiers `*`, `+` and `?`, the anchors `^` and `$`, and
  `\\` escapes of one character. `compile_pattern` refuses any other
  syntax, such as groups and `|`, with an error. A pattern works on bytes,
  so `.` matches one byte of a type name, which is ASCII.
"""


@fieldwise_init
struct PatternAtom(Copyable, Movable):
    """One element of a pattern and its quantifier."""

    var kind: UInt8
    """0 for a byte set, 1 for `^`, 2 for `$`."""
    var set: List[Bool]
    """For a byte set, whether each of the 256 bytes matches."""
    var min: Int
    """The fewest repeats: 0 or 1."""
    var max: Int
    """The most repeats: 1, or -1 for no limit."""


struct Pattern(Copyable, Movable):
    """A compiled pattern."""

    var atoms: List[PatternAtom]
    """The elements, in order."""

    def __init__(out self):
        """Make the empty pattern, which matches the empty string."""
        self.atoms = List[PatternAtom]()

    def first_match_is_whole(self, text: StringSlice) -> Bool:
        """Return True when the first match of the pattern is the text.

        This is `match && match[0] === text` for `text.match(regExp)`.

        Args:
            text: The text, such as a `__typename`.

        Returns:
            Whether the leftmost match starts at 0 and ends at the end.
        """
        var bytes = text.as_bytes()
        var start = 0
        while start <= len(bytes):
            var end = self.match_at(bytes, 0, start)
            if end >= 0:
                return start == 0 and end == len(bytes)
            start += 1
        return False

    def test(self, text: StringSlice) -> Bool:
        """Return True when the pattern matches somewhere in a text.

        This is `regExp.test(text)`.

        Args:
            text: The text.

        Returns:
            Whether a match exists.
        """
        var bytes = text.as_bytes()
        var start = 0
        while start <= len(bytes):
            if self.match_at(bytes, 0, start) >= 0:
                return True
            start += 1
        return False

    def match_at(self, bytes: Span[UInt8, _], atom: Int, position: Int) -> Int:
        """Return the end of the first match of the atoms from an atom on.

        The match starts at a position. The atoms are tried in the
        backtracking order of ECMAScript: each quantifier takes the most
        bytes first.

        Args:
            bytes: The text.
            atom: The first atom to match.
            position: Where the match starts.

        Returns:
            The end of the match, or -1 when there is none.
        """
        if atom == len(self.atoms):
            return position
        ref current = self.atoms[atom]
        if current.kind == 1:
            if position != 0:
                return -1
            return self.match_at(bytes, atom + 1, position)
        if current.kind == 2:
            if position != len(bytes):
                return -1
            return self.match_at(bytes, atom + 1, position)
        # Count how many bytes the set can take, then try the most first.
        var count = 0
        while (current.max < 0 or count < current.max) and (
            position + count < len(bytes)
            and current.set[Int(bytes[position + count])]
        ):
            count += 1
        while count >= current.min:
            var end = self.match_at(bytes, atom + 1, position + count)
            if end >= 0:
                return end
            count -= 1
        return -1


def is_name_byte(byte: UInt8, position: Int) -> Bool:
    """Return True for a byte that `/^[_a-z][_0-9a-z]*/i` takes.

    Args:
        byte: The byte.
        position: Its position in the name; a digit cannot be first.

    Returns:
        Whether the byte continues the name.
    """
    var lower = byte | 0x20
    if lower >= UInt8(ord("a")) and lower <= UInt8(ord("z")):
        return True
    if byte == UInt8(ord("_")):
        return True
    return position > 0 and byte >= UInt8(ord("0")) and byte <= UInt8(ord("9"))


def is_plain_name(text: StringSlice) -> Bool:
    """Return True when a subtype is a plain GraphQL name.

    Upstream checks that `/^[_a-z][_0-9a-z]*/i` matches the whole subtype.

    Args:
        text: The subtype.

    Returns:
        Whether it is a name, so not a pattern.
    """
    var bytes = text.as_bytes()
    var position = 0
    while position < len(bytes) and is_name_byte(bytes[position], position):
        position += 1
    return position > 0 and position == len(bytes)


def compile_pattern(text: StringSlice) raises -> Pattern:
    """Compile a fuzzy subtype pattern.

    Args:
        text: The pattern, such as `.*Entity` or `[E-Z]`.

    Returns:
        The pattern.

    Raises:
        Error: For syntax outside the supported part of `RegExp`.
    """
    var bytes = text.as_bytes()
    var out = Pattern()
    var position = 0
    while position < len(bytes):
        var byte = bytes[position]
        var set = List[Bool](length=256, fill=False)
        if byte == UInt8(ord("^")) or byte == UInt8(ord("$")):
            out.atoms.append(
                PatternAtom(
                    UInt8(1) if byte == UInt8(ord("^")) else UInt8(2),
                    set^,
                    1,
                    1,
                )
            )
            position += 1
            continue
        if byte == UInt8(ord(".")):
            var index = 0
            while index < 256:
                set[index] = index != 10 and index != 13
                index += 1
            position += 1
        elif byte == UInt8(ord("[")):
            position = _read_class(bytes, position + 1, set)
        elif byte == UInt8(ord("\\")):
            if position + 1 >= len(bytes):
                raise Error(String("Unsupported possibleTypes pattern: ", text))
            set[Int(bytes[position + 1])] = True
            position += 2
        elif _is_special(byte):
            raise Error(String("Unsupported possibleTypes pattern: ", text))
        else:
            set[Int(byte)] = True
            position += 1
        var low = 1
        var high = 1
        if position < len(bytes):
            var next = bytes[position]
            if (
                next == UInt8(ord("*"))
                or next == UInt8(ord("+"))
                or next == UInt8(ord("?"))
            ):
                low = 1 if next == UInt8(ord("+")) else 0
                high = 1 if next == UInt8(ord("?")) else -1
                position += 1
        out.atoms.append(PatternAtom(UInt8(0), set^, low, high))
    return out^


def _is_special(byte: UInt8) -> Bool:
    """Return True for a `RegExp` syntax byte that is not supported here."""
    return (
        byte == UInt8(ord("("))
        or byte == UInt8(ord(")"))
        or byte == UInt8(ord("|"))
        or byte == UInt8(ord("{"))
        or byte == UInt8(ord("}"))
        or byte == UInt8(ord("]"))
        or byte == UInt8(ord("*"))
        or byte == UInt8(ord("+"))
        or byte == UInt8(ord("?"))
    )


def _read_class(
    bytes: Span[UInt8, _], start: Int, mut set: List[Bool]
) raises -> Int:
    """Read a `[...]` class after its `[`; return the position after `]`."""
    var position = start
    var negate = position < len(bytes) and bytes[position] == UInt8(ord("^"))
    if negate:
        position += 1
    var closed = False
    while position < len(bytes):
        var low = bytes[position]
        if low == UInt8(ord("]")):
            closed = True
            position += 1
            break
        var high = low
        if (
            position + 2 < len(bytes)
            and bytes[position + 1] == UInt8(ord("-"))
            and bytes[position + 2] != UInt8(ord("]"))
        ):
            high = bytes[position + 2]
            position += 3
        else:
            position += 1
        var index = Int(low)
        while index <= Int(high):
            set[index] = True
            index += 1
    if not closed:
        raise Error("Unsupported possibleTypes pattern: an unclosed class")
    if negate:
        var index = 0
        while index < 256:
            set[index] = not set[index]
            index += 1
    return position
