# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The Snowball English (Porter2) stemmer.

Port of rust-stemmers 1.2.0 `src/snowball/algorithms/english.rs` (MIT arm
of MIT/BSD-3-Clause), which the tantivy `Stemmer::new(Language::English)`
filter of Apollo MCP Server's schema index uses. The generated Snowball
code is written here as plain steps over the code points of the word.

Differences from upstream: none. The input is a lowercase word, as the
tantivy `LowerCaser` gives it.
"""

comptime _Chars = List[UInt32]


def _decode(word: String) -> _Chars:
    """Return the code points of UTF-8 text."""
    var out = _Chars()
    var bytes = word.as_bytes()
    var i = 0
    while i < len(bytes):
        var b = UInt32(bytes[i])
        var size = 1
        if b >= 0xF0:
            b &= 0x07
            size = 4
        elif b >= 0xE0:
            b &= 0x0F
            size = 3
        elif b >= 0xC0:
            b &= 0x1F
            size = 2
        var j = 1
        while j < size:
            b = (b << 6) | (UInt32(bytes[i + j]) & 0x3F)
            j += 1
        out.append(b)
        i += size
    return out^


def _encode(chars: _Chars) -> String:
    """Return the UTF-8 text of code points."""
    var out = List[UInt8]()
    var i = 0
    while i < len(chars):
        var c = chars[i]
        i += 1
        if c < 0x80:
            out.append(UInt8(c))
        elif c < 0x800:
            out.append(UInt8(0xC0 | (c >> 6)))
            out.append(UInt8(0x80 | (c & 0x3F)))
        elif c < 0x10000:
            out.append(UInt8(0xE0 | (c >> 12)))
            out.append(UInt8(0x80 | ((c >> 6) & 0x3F)))
            out.append(UInt8(0x80 | (c & 0x3F)))
        else:
            out.append(UInt8(0xF0 | (c >> 18)))
            out.append(UInt8(0x80 | ((c >> 12) & 0x3F)))
            out.append(UInt8(0x80 | ((c >> 6) & 0x3F)))
            out.append(UInt8(0x80 | (c & 0x3F)))
    return String(unsafe_from_utf8=out^)


def _is_v(c: UInt32) -> Bool:
    """Whether a code point is in the grouping `v`: `aeiouy`."""
    return c == 97 or c == 101 or c == 105 or c == 111 or c == 117 or c == 121


def _is_v_wxy(c: UInt32) -> Bool:
    """Whether a code point is in the grouping `v_WXY`: `v`, `w`, `x`, `Y`."""
    return _is_v(c) or c == 119 or c == 120 or c == 89


def _is_valid_li(c: UInt32) -> Bool:
    """Whether a code point is in the grouping `valid_LI`: `cdeghkmnrt`."""
    var text = "cdeghkmnrt".as_bytes()
    var i = 0
    while i < len(text):
        if UInt32(text[i]) == c:
            return True
        i += 1
    return False


def _ends(w: Span[UInt32, _], suffix: StringSlice) -> Bool:
    """Whether the word ends with an ASCII suffix."""
    var s = suffix.as_bytes()
    if len(s) > len(w):
        return False
    var start = len(w) - len(s)
    var i = 0
    while i < len(s):
        if w[start + i] != UInt32(s[i]):
            return False
        i += 1
    return True


def _longest(w: _Chars, suffixes: StaticString) -> StaticString:
    """Return the longest of the space-separated suffixes that the word ends
    with, or an empty string, as a Snowball `among`."""
    var bytes = suffixes.as_bytes()
    var best = StaticString("")
    var start = 0
    while start < len(bytes):
        var end = start
        while end < len(bytes) and bytes[end] != 32:
            end += 1
        var suffix = suffixes[byte=start:end]
        if end - start > best.byte_length() and _ends(w, suffix):
            best = suffix
        start = end + 1
    return best


def _replace(mut w: _Chars, size: Int, by: StringSlice):
    """Replace the last `size` code points with ASCII text."""
    w.resize(len(w) - size, 0)
    var bytes = by.as_bytes()
    var i = 0
    while i < len(bytes):
        w.append(UInt32(bytes[i]))
        i += 1


def _gopast_v_nonv(w: _Chars, start: Int) -> Int:
    """Return the position after the first non-vowel that follows a vowel,
    from `start`, or -1 when there is none (`gopast v gopast non-v`)."""
    var i = start
    while i < len(w) and not _is_v(w[i]):
        i += 1
    i += 1
    while i < len(w) and _is_v(w[i]):
        i += 1
    if i >= len(w):
        return -1
    return i + 1


def _has_vowel(w: _Chars, end: Int) -> Bool:
    """Whether a vowel is before position `end`."""
    var i = 0
    while i < end:
        if _is_v(w[i]):
            return True
        i += 1
    return False


def _shortv(w: _Chars, c: Int) -> Bool:
    """Whether the word up to position `c` ends in a short syllable."""
    if c >= 3 and not _is_v_wxy(w[c - 1]) and _is_v(w[c - 2]):
        if not _is_v(w[c - 3]):
            return True
    return c == 2 and not _is_v(w[1]) and _is_v(w[0])


def _step_1a(mut w: _Chars):
    """Step 1a: apostrophes and plural endings."""
    var apostrophe = _longest(w, "' 's' 's")
    _replace(w, apostrophe.byte_length(), "")
    var suffix = _longest(w, "sses ied ies ss us s")
    if suffix == "sses":
        _replace(w, 4, "ss")
    elif suffix == "ied" or suffix == "ies":
        _replace(w, 3, "i" if len(w) - 3 >= 2 else "ie")
    elif suffix == "s" and len(w) >= 2 and _has_vowel(w, len(w) - 2):
        _replace(w, 1, "")


def _step_1b(mut w: _Chars, p1: Int):
    """Step 1b: `eed`, `ed`, `ing` and their `ly` forms."""
    var suffix = _longest(w, "ed eed ing edly eedly ingly")
    var size = suffix.byte_length()
    if suffix == "eed" or suffix == "eedly":
        if len(w) - size >= p1:
            _replace(w, size, "ee")
        return
    if size == 0 or not _has_vowel(w, len(w) - size):
        return
    _replace(w, size, "")
    var end = _longest(w, "bb dd ff gg bl mm nn pp rr at tt iz")
    if end == "at" or end == "bl" or end == "iz":
        _replace(w, 0, "e")
    elif end.byte_length() == 2:
        _replace(w, 1, "")
    elif len(w) == p1 and _shortv(w, len(w)):
        _replace(w, 0, "e")


def _step_1c(mut w: _Chars):
    """Step 1c: a final `y` after a consonant becomes `i`."""
    var n = len(w)
    if n < 3 or (w[n - 1] != 121 and w[n - 1] != 89):
        return
    if not _is_v(w[n - 2]):
        _replace(w, 1, "i")


def _step_2(mut w: _Chars, p1: Int):
    """Step 2: derivational suffixes in R1."""
    var s = _longest(
        w,
        (
            "anci enci ogi li bli abli alli fulli lessli ousli entli aliti"
            " biliti iviti tional ational alism ation ization izer ator"
            " iveness fulness ousness"
        ),
    )
    var size = s.byte_length()
    if size == 0 or len(w) - size < p1:
        return
    var by: String
    if s == "tional":
        by = "tion"
    elif s == "enci":
        by = "ence"
    elif s == "anci":
        by = "ance"
    elif s == "abli":
        by = "able"
    elif s == "entli":
        by = "ent"
    elif s == "izer" or s == "ization":
        by = "ize"
    elif s == "ational" or s == "ation" or s == "ator":
        by = "ate"
    elif s == "alism" or s == "aliti" or s == "alli":
        by = "al"
    elif s == "fulness" or s == "fulli":
        by = "ful"
    elif s == "ousli" or s == "ousness":
        by = "ous"
    elif s == "iveness" or s == "iviti":
        by = "ive"
    elif s == "biliti" or s == "bli":
        by = "ble"
    elif s == "lessli":
        by = "less"
    elif s == "ogi":
        if w[len(w) - 4] != 108:
            return
        by = "og"
    else:
        if not _is_valid_li(w[len(w) - 3]):
            return
        by = ""
    _replace(w, size, by)


def _step_3(mut w: _Chars, p1: Int, p2: Int):
    """Step 3: more derivational suffixes in R1."""
    var s = _longest(
        w,
        "icate ative alize iciti ical tional ational ful ness",
    )
    var size = s.byte_length()
    var start = len(w) - size
    if size == 0 or start < p1:
        return
    if s == "tional":
        _replace(w, size, "tion")
    elif s == "ational":
        _replace(w, size, "ate")
    elif s == "alize":
        _replace(w, size, "al")
    elif s == "icate" or s == "iciti" or s == "ical":
        _replace(w, size, "ic")
    elif s == "ative":
        if start >= p2:
            _replace(w, size, "")
    else:
        _replace(w, size, "")


def _step_4(mut w: _Chars, p2: Int):
    """Step 4: suffixes in R2."""
    var s = _longest(
        w,
        (
            "ic ance ence able ible ate ive ize iti al ism ion er ous ant ent"
            " ment ement"
        ),
    )
    var size = s.byte_length()
    var start = len(w) - size
    if size == 0 or start < p2:
        return
    if s == "ion":
        if w[start - 1] != 115 and w[start - 1] != 116:
            return
    _replace(w, size, "")


def _step_5(mut w: _Chars, p1: Int, p2: Int):
    """Step 5: a final `e`, and a final `l` after `l`."""
    var start = len(w) - 1
    if _ends(w, "e"):
        if start >= p2 or (start >= p1 and not _shortv(w, start)):
            _replace(w, 1, "")
    elif _ends(w, "l"):
        if start >= p2 and w[start - 1] == 108:
            _replace(w, 1, "")


def _exception1(word: String) -> Optional[String]:
    """Return the stem of a word that the algorithm does not change by its
    rules, or nothing."""
    var table = StaticString(
        "skis=ski skies=sky dying=die lying=lie tying=tie idly=idl"
        " gently=gentl ugly=ugli early=earli only=onli singly=singl sky=sky"
        " news=news howe=howe atlas=atlas cosmos=cosmos bias=bias andes=andes"
    )
    if word.byte_length() > 6:
        return None
    var bytes = table.as_bytes()
    var start = 0
    while start < len(bytes):
        var equals = start
        while bytes[equals] != 61:
            equals += 1
        var end = equals
        while end < len(bytes) and bytes[end] != 32:
            end += 1
        if table[byte=start:equals] == word:
            return String(table[byte = equals + 1 : end])
        start = end + 1
    return None


def _is_exception2(w: _Chars) -> Bool:
    """Whether the word, after step 1a, is one that keeps its form."""
    var found = _longest(
        w, "inning outing canning herring earring proceed exceed succeed"
    )
    return found.byte_length() > 0 and found.byte_length() == len(w)


def _prelude(mut w: _Chars) -> Bool:
    """Remove a first apostrophe and mark each consonant `y` as `Y`.

    Returns whether a `Y` was set.
    """
    if w[0] == 39:
        _ = w.pop(0)
    var found = False
    var i = 0
    while i < len(w):
        if w[i] == 121 and (i == 0 or _is_v(w[i - 1])):
            w[i] = 89
            found = True
        i += 1
    return found


def _regions(w: _Chars) -> Tuple[Int, Int]:
    """Return the starts of the regions R1 and R2."""
    var n = len(w)
    var p1 = n
    var p2 = n
    var prefixed = False
    if n >= 5 and (_ends(w[:5], "gener") or _ends(w[:5], "arsen")):
        p1 = 5
        prefixed = True
    if n >= 6 and _ends(w[:6], "commun"):
        p1 = 6
        prefixed = True
    if not prefixed:
        var found = _gopast_v_nonv(w, 0)
        if found < 0:
            return (p1, p2)
        p1 = found
    var second = _gopast_v_nonv(w, p1)
    if second >= 0:
        p2 = second
    return (p1, p2)


def stem_english(word: String) -> String:
    """Return the Snowball English (Porter2) stem of a word.

    Args:
        word: A lowercase word.

    Returns:
        The stem, as rust-stemmers `Algorithm::English` gives it.
    """
    var exception = _exception1(word)
    if exception:
        return exception.value()
    var w = _decode(word)
    if len(w) < 3:
        return word
    var y_found = _prelude(w)
    var regions = _regions(w)
    var p1 = regions[0]
    var p2 = regions[1]
    _step_1a(w)
    if not _is_exception2(w):
        _step_1b(w, p1)
        _step_1c(w)
        _step_2(w, p1)
        _step_3(w, p1, p2)
        _step_4(w, p2)
        _step_5(w, p1, p2)
    if y_found:
        var i = 0
        while i < len(w):
            if w[i] == 89:
                w[i] = 121
            i += 1
    return _encode(w)
