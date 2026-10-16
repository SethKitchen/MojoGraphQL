# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The text analysis of the schema index: identifier splitting, tokens,
lowercase and stems.

Port of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-schema-index/src/lib.rs` `expand_identifiers` and
`push_expanded_word`, of heck 0.5.0 `to_snake_case` (`src/lib.rs`
`transform` and `lowercase`, MIT), and of the tantivy 0.26.2 analyzer that
the index registers as `en_stem`: `SimpleTokenizer`
(`src/tokenizer/simple_tokenizer.rs`), `LowerCaser` and
`Stemmer::new(Language::English)` (MIT).

Differences from upstream:

- Rust classifies characters with the Unicode tables. This module knows
  ASCII exactly. For other characters it knows the letters of Latin-1,
  Latin Extended-A, Greek and Cyrillic, and the common punctuation and
  symbol blocks; it takes any other character as an uncased letter. So a
  description in such a script can give other tokens than upstream.
"""

from gql_mcp.stemmer import _decode, _encode, stem_english


comptime _NOT_ALPHANUMERIC = (
    "80-A9 AB-B1 B4 B6-B8 BB BF D7 F7 300-36F 2000-206F 20A0-20CF 2190-245F"
    " 2500-27BF 2800-2BFF 3000-3004 3008-3020 FE00-FE6F FF01-FF0F FF1A-FF20"
    " FF3B-FF40 FF5B-FF65 1F000-1FAFF "
)
"""The non-ASCII code points that are neither letters nor numbers, as
hexadecimal ranges. Each table ends with a space."""

comptime _UPPERCASE = (
    "C0-D6+ D8-DE+ 391-3A1+ 3A3-3A9+ 410-42F+ 400-40F* 100-137e"
    " 14A-177e 139-148o 179-17Eo 178= "
)
"""The non-ASCII uppercase letters that this module knows. `+` adds 32 for the
lowercase, `*` adds 80, `e` takes the even code points and adds 1, `o` the
odd ones, and `=` maps `Ÿ` to `ÿ`."""

comptime _LOWERCASE = "AA B5 BA DF-F6 F8-FF 138 149 17F 3AC-3CE 430-45F "
"""The non-ASCII lowercase letters that this module knows, besides the partners of
the `e` and `o` ranges of `_UPPERCASE`."""


def _in(c: UInt32, low: UInt32, high: UInt32) -> Bool:
    """Whether a code point is in a closed range."""
    return c >= low and c <= high


def _hex(table: StaticString, mut at: Int) -> UInt32:
    """Read a hexadecimal number of a table, and move past it. A table
    ends with a space, so the number ends inside the table."""
    var bytes = table.as_bytes()
    var value: UInt32 = 0
    var reading = True
    while reading:
        var b = bytes[at]
        var digit = Int(b) - 48 if b <= 57 else Int(b) - 55
        reading = (b >= 48 and b <= 57) or (b >= 65 and b <= 70)
        if reading:
            value = value * 16 + UInt32(digit)
            at += 1
    return value


def _lookup(c: UInt32, table: StaticString) -> UInt8:
    """Return the mark after the range of a table that holds a code point:
    `+`, `*`, `e`, `o`, `=`, a space for no mark, or 0 when no range holds
    it."""
    var bytes = table.as_bytes()
    var at = 0
    while at < len(bytes):
        var low = _hex(table, at)
        var high = low
        if bytes[at] == 45:
            at += 1
            high = _hex(table, at)
        var mark = UInt8(32)
        if bytes[at] != 32:
            mark = bytes[at]
            at += 1
        at += 1
        if _in(c, low, high):
            return mark
    return 0


def is_alphanumeric(c: UInt32) -> Bool:
    """Return whether a code point is a letter or a number, as Rust
    `char::is_alphanumeric`.

    Args:
        c: The code point.

    Returns:
        Whether the tokenizers keep it inside a word.
    """
    if c < 0x80:
        return _in(c, 48, 57) or _in(c, 65, 90) or _in(c, 97, 122)
    return _lookup(c, _NOT_ALPHANUMERIC) == 0


def _upper_to_lower(c: UInt32) -> UInt32:
    """Return the lowercase of an uppercase letter, or 0 when the code
    point is not an uppercase letter that this module knows."""
    if c < 0x80:
        return c + 32 if _in(c, 65, 90) else 0
    var mark = _lookup(c, _UPPERCASE)
    if mark == 43:
        return c + 32
    if mark == 42:
        return c + 80
    if mark == 61:
        return 0xFF
    if (mark == 101 and c % 2 == 0) or (mark == 111 and c % 2 == 1):
        return c + 1
    return 0


def is_uppercase(c: UInt32) -> Bool:
    """Return whether a code point is an uppercase letter, as Rust
    `char::is_uppercase`.

    Args:
        c: The code point.

    Returns:
        Whether it is an uppercase letter.
    """
    return _upper_to_lower(c) != 0


def is_lowercase(c: UInt32) -> Bool:
    """Return whether a code point is a lowercase letter, as Rust
    `char::is_lowercase`.

    Args:
        c: The code point.

    Returns:
        Whether it is a lowercase letter.
    """
    if c < 0x80:
        return _in(c, 97, 122)
    if _lookup(c, _LOWERCASE) != 0:
        return True
    return _upper_to_lower(c - 1) == c


def to_lowercase(c: UInt32) -> UInt32:
    """Return the lowercase of a code point, as Rust `char::to_lowercase`
    for the letters that this module knows.

    Args:
        c: The code point.

    Returns:
        The lowercase code point, or `c` when it has no lowercase.
    """
    var lower = _upper_to_lower(c)
    return lower if lower != 0 else c


def _lower_word(chars: List[UInt32], start: Int, end: Int) -> List[UInt32]:
    """Return a lowercase word, as heck `lowercase`: a final capital sigma
    becomes a final small sigma."""
    var out = List[UInt32]()
    var i = start
    while i < end:
        var c = chars[i]
        if c == 0x3A3 and i + 1 == end:
            out.append(0x3C2)
        else:
            out.append(to_lowercase(c))
        i += 1
    return out^


def _snake_words(chars: List[UInt32]) -> List[List[UInt32]]:
    """Return the lowercase words of heck `to_snake_case`, for text of
    letters, numbers and underscores."""
    var words = List[List[UInt32]]()
    var n = len(chars)
    var start = 0
    while start < n:
        var end = start
        while end < n and chars[end] != 95:
            end += 1
        var init = start
        var mode = 0
        var i = start
        while i < end:
            var c = chars[i]
            if i + 1 == end:
                words.append(_lower_word(chars, init, end))
                break
            var next = chars[i + 1]
            var next_mode = mode
            if is_lowercase(c):
                next_mode = 1
            elif is_uppercase(c):
                next_mode = 2
            if next_mode == 1 and is_uppercase(next):
                words.append(_lower_word(chars, init, i + 1))
                init = i + 1
                mode = 0
            elif mode == 2 and is_uppercase(c) and is_lowercase(next):
                words.append(_lower_word(chars, init, i))
                init = i
                mode = 0
            else:
                mode = next_mode
            i += 1
        start = end + 1
    return words^


def _push_expanded(mut out: List[UInt32], chars: List[UInt32]):
    """Append the snake-case words of an identifier, separated by spaces."""
    var words = _snake_words(chars)
    var i = 0
    while i < len(words):
        if i > 0:
            out.append(32)
        out.extend(words[i].copy())
        i += 1


def expand_identifiers(text: String) -> String:
    """Split the camelCase and PascalCase identifiers of a text into
    lowercase words, as upstream `expand_identifiers`.

    Args:
        text: The text.

    Returns:
        The text with each run of letters, numbers and underscores in
        snake case, with spaces for the underscores. Other characters do
        not change.
    """
    var chars = _decode(text)
    var out = List[UInt32]()
    var word = List[UInt32]()
    var i = 0
    while i < len(chars):
        var c = chars[i]
        if is_alphanumeric(c) or c == 95:
            word.append(c)
        else:
            _push_expanded(out, word)
            word.clear()
            out.append(c)
        i += 1
    _push_expanded(out, word)
    return _encode(out)


def analyze(text: String) -> List[String]:
    """Return the terms of a text, as the `en_stem` analyzer gives them:
    each run of letters and numbers, in lowercase, stemmed.

    Args:
        text: The text.

    Returns:
        The terms, in order.
    """
    var chars = _decode(text)
    var terms = List[String]()
    var i = 0
    while i < len(chars):
        if not is_alphanumeric(chars[i]):
            i += 1
            continue
        var token = List[UInt32]()
        while i < len(chars) and is_alphanumeric(chars[i]):
            token.append(_lower_in_word(chars, i))
            i += 1
        terms.append(stem_english(_encode(token)))
    return terms^


def _is_cased(c: UInt32) -> Bool:
    """Whether a code point is an uppercase or a lowercase letter."""
    return is_lowercase(c) or is_uppercase(c)


def _lower_in_word(chars: List[UInt32], i: Int) -> UInt32:
    """Return the lowercase of a code point, as Rust `str::to_lowercase`: a
    capital sigma after a cased letter and not before one is final."""
    var c = chars[i]
    if c != 0x3A3:
        return to_lowercase(c)
    var after_cased = i > 0 and _is_cased(chars[i - 1])
    var before_cased = i + 1 < len(chars) and _is_cased(chars[i + 1])
    return UInt32(0x3C2) if after_cased and not before_cased else UInt32(0x3C3)
