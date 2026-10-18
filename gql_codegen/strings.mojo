# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The string helpers of the code generator: names, the document minifier
and the escapes of the GraphQL and Mojo string literals.

Port of Apollo Kotlin `apollo-compiler` `Strings.kt`
(`capitalizeFirstLetter`, `decapitalizeFirstLetter`,
`upperCamelCaseIgnoringNonLetters`, `lowerCamelCaseIgnoringNonLetters`),
`internal/Inflector.kt` (`singularize`), and of `apollo-ast`
`QueryDocumentMinifier.kt` and `gqlstrings.kt`
(`encodeToGraphQLSingleQuoted`).

**Differences from upstream.**

- A letter is an ASCII letter. Kotlin `Char.isLetter` also accepts the
  other Unicode letters, but a GraphQL name holds only ASCII.
- `singularize` matches its rules as suffixes, without
  `java.util.regex`. Each rule keeps the case-insensitive match and the
  replacement of the upstream pattern.
- `escape_mojo_keyword` replaces `escapeKotlinReservedWord`: it appends
  `_` to a Mojo keyword, because the generated code is Mojo.
- Correction: `encode_single_quoted` writes `\\u0080` to `\\u009f` for
  the characters U+0080 to U+009F. Upstream (afe947c and 5.2.0)
  `Byte.hexString` reads `toByte().toInt()`, which is negative for these
  characters, so `ushr(4)` indexes past `"0123456789abcdef"` and the
  compiler throws `StringIndexOutOfBoundsException`. The counterexample
  is the operation `{ hero(name: "\\u0080") { id } }`. The GraphQL
  specification (section 2.9.4, String Value) allows the escape
  `\\u0080`, and it decodes to the same character, so the printed
  document has the value of the source. A caller loses nothing: upstream
  fails where this port prints. The other escapes are the upstream ones.
"""


def _is_upper(byte: UInt8) -> Bool:
    """Return True for an ASCII capital letter."""
    return byte >= UInt8(ord("A")) and byte <= UInt8(ord("Z"))


def _is_lower(byte: UInt8) -> Bool:
    """Return True for an ASCII small letter."""
    return byte >= UInt8(ord("a")) and byte <= UInt8(ord("z"))


def _lower(byte: UInt8) -> UInt8:
    """Return the small letter of an ASCII capital, else the byte."""
    if _is_upper(byte):
        return byte + 32
    return byte


def capitalize_first_letter(text: StringSlice) -> String:
    """Capitalize the first letter, as Apollo `capitalizeFirstLetter`.
    Characters before the first letter, such as `_`, stay.

    Args:
        text: A name, such as `__typename`.

    Returns:
        The name with its first letter capitalized, such as `__Typename`.
    """
    var bytes = List[UInt8](text.as_bytes())
    for index in range(len(bytes)):
        if _is_lower(bytes[index]):
            bytes[index] -= 32
            break
        if _is_upper(bytes[index]):
            break
    return String(unsafe_from_utf8=bytes)


def decapitalize_first_letter(text: StringSlice) -> String:
    """Make the first letter small, as Apollo `decapitalizeFirstLetter`.

    Args:
        text: A name, such as `HeroDetails`.

    Returns:
        The name with its first letter small, such as `heroDetails`.
    """
    var bytes = List[UInt8](text.as_bytes())
    for index in range(len(bytes)):
        if _is_upper(bytes[index]):
            bytes[index] += 32
            break
        if _is_lower(bytes[index]):
            break
    return String(unsafe_from_utf8=bytes)


def is_first_letter_upper_case(text: StringSlice) -> Bool:
    """Return True when the first letter is a capital, as Apollo
    `isFirstLetterUpperCase` of `checkCapitalizedFields.kt`. A name
    without a letter counts as capitalized.

    Args:
        text: A field name or an alias.

    Returns:
        Whether the first letter is a capital.
    """
    for byte in text.as_bytes():
        if _is_upper(byte):
            return True
        if _is_lower(byte):
            return False
    return True


def _ends_with(word: List[UInt8], suffix: StringSlice) -> Bool:
    """Return True when a lowercased word ends with a suffix."""
    var tail = suffix.as_bytes()
    if len(tail) > len(word):
        return False
    var start = len(word) - len(tail)
    # Every suffix of the rules has a letter.
    for index in range(len(tail)):  # pragma: no branch
        if word[start + index] != tail[index]:
            return False
    return True


def _is_vowel_or_y(byte: UInt8) -> Bool:
    """Return True for `a`, `e`, `i`, `o`, `u` and `y`."""
    return (
        byte == UInt8(ord("a"))
        or byte == UInt8(ord("e"))
        or byte == UInt8(ord("i"))
        or byte == UInt8(ord("o"))
        or byte == UInt8(ord("u"))
        or byte == UInt8(ord("y"))
    )


comptime _UNCOUNTABLE: Array[StaticString, 10] = [
    "equipment",
    "information",
    "rice",
    "money",
    "species",
    "series",
    "fish",
    "sheep",
    "jeans",
    "police",
]
"""The words that `singularize` keeps, as upstream `uncountable`."""

comptime _IRREGULAR: Array[StaticString, 14] = [
    "person",
    "people",
    "man",
    "men",
    "child",
    "children",
    "sex",
    "sexes",
    "move",
    "moves",
    "zombie",
    "zombies",
    "goose",
    "geese",
]
"""The pairs of upstream `irregular`: each singular, then its plural."""


def _replace_tail(text: StringSlice, drop: Int, add: StringSlice) -> String:
    """Drop bytes from the end of a text and append a replacement."""
    var bytes = text.as_bytes()
    var out = String(unsafe_from_utf8=Span(bytes)[: len(bytes) - drop])
    out += add
    return out^


def _rule(word: List[UInt8]) -> Tuple[Int, StaticString]:
    """Find the last upstream singularization rule that matches.

    The rules are tried from the last to the first, as upstream
    `singularizationRules.lastOrNull`. A rule replaces a suffix of the
    word.

    Returns:
        How many bytes to drop and what to append; (-1, "") for no rule.
    """
    var size = len(word)
    # "(database)s$" to "$1"
    if _ends_with(word, "databases"):
        return (1, "")
    # "(quiz)zes$" to "$1"
    if _ends_with(word, "quizzes"):
        return (3, "")
    # "(matr)ices$" to "$1ix"
    if _ends_with(word, "matrices"):
        return (4, "ix")
    # "(vert|ind)ices$" to "$1ex"
    if _ends_with(word, "vertices") or _ends_with(word, "indices"):
        return (4, "ex")
    # "^(ox)en/$" never matches a name: a name has no `/`.
    # "(alias|status)(es)?$" to "$1"
    if _ends_with(word, "aliases") or _ends_with(word, "statuses"):
        return (2, "")
    if _ends_with(word, "alias") or _ends_with(word, "status"):
        return (0, "")
    # "(octop|vir)(us|i)$" to "$1us"
    if _ends_with(word, "octopi") or _ends_with(word, "viri"):
        return (1, "us")
    if _ends_with(word, "octopus") or _ends_with(word, "virus"):
        return (0, "")
    # "^(a)x[ie]s$" to "$1xis"
    if size == 4 and (_ends_with(word, "axis") or _ends_with(word, "axes")):
        return (2, "is")
    # "(cris|test)(is|es)$" to "$1is"
    if _ends_with(word, "crisis") or _ends_with(word, "testis"):
        return (0, "")
    if _ends_with(word, "crises") or _ends_with(word, "testes"):
        return (2, "is")
    # "(shoe)s$" to "$1"
    if _ends_with(word, "shoes"):
        return (1, "")
    # "(o)es$" to "$1"
    if _ends_with(word, "oes"):
        return (2, "")
    # "(bus)(es)?$" to "$1"
    if _ends_with(word, "buses"):
        return (2, "")
    if _ends_with(word, "bus"):
        return (0, "")
    # "^(m|l)ice$" to "$1ouse"
    if size == 4 and (_ends_with(word, "mice") or _ends_with(word, "lice")):
        return (3, "ouse")
    # "(x|ch|ss|sh)es$" to "$1"
    if (
        _ends_with(word, "xes")
        or _ends_with(word, "ches")
        or _ends_with(word, "sses")
        or _ends_with(word, "shes")
    ):
        return (2, "")
    # "(m)ovies$" to "$1ovie"
    if _ends_with(word, "movies"):
        return (1, "")
    # "(s)eries$" to "$1eries"
    if _ends_with(word, "series"):
        return (0, "")
    # "([^aeiouy]|qu)ies$" to "$1y"
    if size >= 4 and _ends_with(word, "ies"):
        if _ends_with(word, "quies") or not _is_vowel_or_y(word[size - 4]):
            return (3, "y")
    # "([lr])ves$" to "$1f"
    if size >= 4 and _ends_with(word, "ves"):
        var before = word[size - 4]
        if before == UInt8(ord("l")) or before == UInt8(ord("r")):
            return (3, "f")
    # "(tive)s$" to "$1" and "(hive)s$" to "$1"
    if _ends_with(word, "tives") or _ends_with(word, "hives"):
        return (1, "")
    # "([^f])ves$" to "$1fe"
    if (
        size >= 4
        and _ends_with(word, "ves")
        and word[size - 4] != UInt8(ord("f"))
    ):
        return (3, "fe")
    # "(^analy)(sis|ses)$" to "$1sis"
    if size == 8 and (
        _ends_with(word, "analysis") or _ends_with(word, "analyses")
    ):
        return (3, "sis")
    # "([ti])a$" to "$1um"
    if size >= 2 and _ends_with(word, "a"):
        var before = word[size - 2]
        if before == UInt8(ord("t")) or before == UInt8(ord("i")):
            return (1, "um")
    # "(ss)$" to "$1"
    if _ends_with(word, "ss"):
        return (0, "")
    # "s$" to ""
    if _ends_with(word, "s"):
        return (1, "")
    return (-1, "")


def singularize(text: StringSlice) -> String:
    """Return the singular of a word, as Apollo `String.singularize`. The
    generator names the model of a list field after the singular.

    Args:
        text: A response name, such as `friends`.

    Returns:
        The singular, such as `friend`; the word itself when no rule
        applies.
    """
    var lower = List[UInt8](capacity=text.byte_length())
    for byte in text.as_bytes():
        lower.append(_lower(byte))
    var lowered = String(unsafe_from_utf8=lower)
    var uncountable = materialize[_UNCOUNTABLE]()
    for index in range(len(uncountable)):  # pragma: no branch
        if lowered == uncountable[index]:
            return String(text)
    if lowered == "data":
        return String(text)
    var irregular = materialize[_IRREGULAR]()
    for index in range(0, len(irregular), 2):  # pragma: no branch
        if lowered == irregular[index + 1]:
            var singular = String(irregular[index])
            if _is_upper(text.as_bytes()[0]):
                return capitalize_first_letter(singular)
            return singular^
    var rule = _rule(lower)
    if rule[0] < 0:
        return String(text)
    return _replace_tail(text, rule[0], rule[1])


def upper_camel_case(names: List[String]) -> String:
    """Join names, each with its first letter capitalized, as Apollo
    `upperCamelCaseIgnoringNonLetters`.

    Args:
        names: The names, such as `["hero", "friend"]`.

    Returns:
        The joined name, such as `HeroFriend`.
    """
    var out = String("")
    for ref name in names:
        out += capitalize_first_letter(name)
    return out^


def minify(document: StringSlice) -> String:
    """Minify a printed document, as Apollo `QueryDocumentMinifier.minify`:
    the regular expression `\\s *` is replaced by one space. So each
    whitespace character, with the spaces that follow it, becomes one
    space.

    Args:
        document: The document, as `print_executable` prints it.

    Returns:
        The minified document, the text that the operation id hashes.
    """
    var bytes = document.as_bytes()
    var out = List[UInt8](capacity=len(bytes))
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        index += 1
        if (
            byte == UInt8(ord(" "))
            or byte == UInt8(ord("\t"))
            or byte == UInt8(ord("\n"))
            or byte == UInt8(ord("\r"))
            or byte == 0x0B
            or byte == 0x0C
        ):
            out.append(UInt8(ord(" ")))
            while index < len(bytes) and bytes[index] == UInt8(ord(" ")):
                index += 1
        else:
            out.append(byte)
    return String(unsafe_from_utf8=out)


comptime _HEX = "0123456789abcdef"
"""The digits of a `\\u00XX` escape."""


def encode_single_quoted(text: StringSlice) -> String:
    """Escape text for a GraphQL string literal, as Apollo
    `encodeToGraphQLSingleQuoted`.

    Args:
        text: The decoded value of a string.

    Returns:
        The escaped text, without the quotes.
    """
    var bytes = text.as_bytes()
    var out = List[UInt8](capacity=len(bytes) + 2)
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        if byte == UInt8(ord('"')):
            out.extend('\\"'.as_bytes())
        elif byte == UInt8(ord("\\")):
            out.extend("\\\\".as_bytes())
        elif byte == 0x08:
            out.extend("\\b".as_bytes())
        elif byte == 0x0C:
            out.extend("\\f".as_bytes())
        elif byte == UInt8(ord("\n")):
            out.extend("\\n".as_bytes())
        elif byte == UInt8(ord("\r")):
            out.extend("\\r".as_bytes())
        elif byte == UInt8(ord("\t")):
            out.extend("\\t".as_bytes())
        elif byte < 0x20 or byte == 0x7F:
            _append_unicode_escape(out, Int(byte))
        elif byte == 0xC2 and bytes[index + 1] < 0xA0:
            # U+0080 to U+009F, two bytes in UTF-8. In valid UTF-8, a
            # continuation byte always follows 0xC2.
            _append_unicode_escape(out, Int(bytes[index + 1]))
            index += 1
        else:
            out.append(byte)
        index += 1
    return String(unsafe_from_utf8=out)


def _append_unicode_escape(mut out: List[UInt8], code: Int):
    """Append `\\u00XX` for a code point below U+0100."""
    var digits = StaticString(_HEX).as_bytes()
    out.extend("\\u00".as_bytes())
    out.append(digits[code >> 4])
    out.append(digits[code & 15])


comptime _MOJO_KEYWORDS: Array[StaticString, 50] = [
    "False",
    "None",
    "True",
    "Self",
    "alias",
    "and",
    "as",
    "assert",
    "async",
    "await",
    "break",
    "class",
    "comptime",
    "continue",
    "def",
    "deinit",
    "del",
    "elif",
    "else",
    "except",
    "finally",
    "fn",
    "for",
    "from",
    "global",
    "if",
    "import",
    "in",
    "is",
    "lambda",
    "mut",
    "nonlocal",
    "not",
    "or",
    "out",
    "owned",
    "pass",
    "raise",
    "raises",
    "read",
    "ref",
    "return",
    "self",
    "struct",
    "trait",
    "try",
    "var",
    "while",
    "with",
    "yield",
]
"""The words that a generated name must not be."""


def escape_mojo_keyword(name: StringSlice) -> String:
    """Append `_` to a name that is a Mojo keyword or a name that the
    generated code uses, as Apollo `escapeKotlinReservedWord` does for
    Kotlin.

    Args:
        name: A field, variable or enum value name.

    Returns:
        The name, or the name with `_` appended.
    """
    var keywords = materialize[_MOJO_KEYWORDS]()
    for index in range(len(keywords)):  # pragma: no branch
        if name == keywords[index]:
            return String(name) + "_"
    return String(name)
