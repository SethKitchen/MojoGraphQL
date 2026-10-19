# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Suggestions for a misspelled name: "Did you mean ...?".

Port of graphql-js 16.14.2 `jsutils/suggestionList.ts` (`suggestionList` and
its `LexicalDistance`), `jsutils/didYouMean.ts` and
`jsutils/naturalCompare.ts`.

**Differences from graphql-js.**

- The text is compared byte by byte, and only ASCII letters change case.
  graphql-js compares UTF-16 code units and lowers the case of every
  letter. GraphQL names are ASCII, so a name gives the same result.
"""

from gql_language.names import NOT_FOUND, NameTable

comptime _MAX_SUGGESTIONS = 5


def _lower(text: StringSlice) -> List[UInt8]:
    """Return the bytes of a text with ASCII letters in lower case."""
    var bytes = text.as_bytes()
    var out = List[UInt8](capacity=len(bytes))
    for byte in bytes:
        if byte >= 65 and byte <= 90:
            out.append(byte + 32)
        else:
            out.append(byte)
    return out^


def lexical_distance(
    input: StringSlice, option: StringSlice, threshold: Int
) -> Int:
    """Return the edit distance between two texts, as graphql-js
    `LexicalDistance.measure`.

    An edit is an insertion, a deletion or a substitution of one character,
    or a swap of two adjacent characters. A change of case only is one edit.

    Args:
        input: The text that was given.
        option: A text to compare it with.
        threshold: The largest distance of interest.

    Returns:
        The distance, or -1 when it is larger than the threshold.
    """
    if input == option:
        return 0
    var a = _lower(option)
    var b = _lower(input)
    # Any case change counts as a single edit.
    if a == b:
        return 1
    if len(a) < len(b):
        swap(a, b)
    var a_length = len(a)
    var b_length = len(b)
    if a_length - b_length > threshold:
        return -1
    var rows = List[List[Int]]()
    rows.append(List[Int](length=b_length + 1, fill=0))
    rows.append(List[Int](length=b_length + 1, fill=0))
    rows.append(List[Int](length=b_length + 1, fill=0))
    var column = 0
    while column <= b_length:
        rows[0][column] = column
        column += 1
    var i = 1
    while i <= a_length:
        var up = (i - 1) % 3
        var current = i % 3
        rows[current][0] = i
        var smallest = i
        for j in range(1, b_length + 1):
            var cost = 0 if a[i - 1] == b[j - 1] else 1
            var cell = min(
                rows[up][j] + 1,  # delete
                rows[current][j - 1] + 1,  # insert
                rows[up][j - 1] + cost,  # substitute
            )
            if (
                i > 1
                and j > 1
                and a[i - 1] == b[j - 2]
                and a[i - 2] == b[j - 1]
            ):
                # A transposition.
                cell = min(cell, rows[(i - 2) % 3][j - 2] + 1)
            if cell < smallest:
                smallest = cell
            rows[current][j] = cell
        # The distance cannot be smaller than the smallest cell of a row.
        if smallest > threshold:
            return -1
        i += 1
    var distance = rows[a_length % 3][b_length]
    if distance <= threshold:
        return distance
    return -1


@always_inline
def _byte_at(bytes: Span[UInt8, _], index: Int) -> Int:
    """Return a byte, or -1 past the end: JavaScript `charCodeAt` NaN."""
    if index < len(bytes):
        return Int(bytes[index])
    return -1


@always_inline
def _is_digit(code: Int) -> Bool:
    """Return True for the code of `0` through `9`."""
    return code >= 48 and code <= 57


def natural_compare(a: StringSlice, b: StringSlice) -> Int:
    """Compare two texts in natural sort order, as graphql-js
    `naturalCompare`: a run of digits compares as a number.

    Args:
        a: The first text.
        b: The second text.

    Returns:
        A negative number when `a` comes first, a positive number when `b`
        comes first, and zero when they are equal.
    """
    var a_bytes = a.as_bytes()
    var b_bytes = b.as_bytes()
    var a_index = 0
    var b_index = 0
    while a_index < len(a_bytes) and b_index < len(b_bytes):
        var a_char = Int(a_bytes[a_index])
        var b_char = Int(b_bytes[b_index])
        if _is_digit(a_char) and _is_digit(b_char):
            # As graphql-js, a number ends after a leading zero.
            a_index += 1
            var a_number = a_char - 48
            a_char = _byte_at(a_bytes, a_index)
            while _is_digit(a_char) and a_number > 0:
                a_index += 1
                a_number = a_number * 10 + a_char - 48
                a_char = _byte_at(a_bytes, a_index)
            b_index += 1
            var b_number = b_char - 48
            b_char = _byte_at(b_bytes, b_index)
            while _is_digit(b_char) and b_number > 0:
                b_index += 1
                b_number = b_number * 10 + b_char - 48
                b_char = _byte_at(b_bytes, b_index)
            if a_number != b_number:
                return -1 if a_number < b_number else 1
        else:
            if a_char != b_char:
                return -1 if a_char < b_char else 1
            a_index += 1
            b_index += 1
    return len(a_bytes) - len(b_bytes)


def suggestion_list(input: StringSlice, options: List[String]) -> List[String]:
    """Return the options that are close to a text, the closest first, as
    graphql-js `suggestionList`.

    Args:
        input: The text that was given.
        options: The texts that are valid.

    Returns:
        Each option at most `floor(0.4 * length) + 1` edits away, once.
        Options with the same distance are in natural sort order.
    """
    var threshold = (input.byte_length() * 2) // 5 + 1
    var seen = NameTable()
    var found = List[String]()
    var distances = List[Int]()
    for ref option in options:
        if seen.find(-1, option) != NOT_FOUND:
            continue
        _ = seen.insert(-1, option, 0)
        var distance = lexical_distance(input, option, threshold)
        if distance < 0:
            continue
        # An insertion sort: the lists are short, and the sort is stable.
        var at = len(found)
        while at > 0 and (
            distances[at - 1] > distance
            or (
                distances[at - 1] == distance
                and natural_compare(found[at - 1], option) > 0
            )
        ):
            at -= 1
        found.insert(at, option)
        distances.insert(at, distance)
    return found^


def did_you_mean(suggestions: List[String]) -> String:
    """Return ` Did you mean "A", "B", or "C"?`, as graphql-js `didYouMean`.

    Args:
        suggestions: The suggestions; only the first five are named.

    Returns:
        The sentence, with a leading space, or empty for no suggestion.
    """
    return did_you_mean("", suggestions)


def did_you_mean(sub_message: String, suggestions: List[String]) -> String:
    """Return ` Did you mean <sub_message> "A" or "B"?`, as graphql-js
    `didYouMean(subMessage, suggestions)`.

    Args:
        sub_message: Words before the suggestions, or empty for none.
        suggestions: The suggestions; only the first five are named.

    Returns:
        The sentence, with a leading space, or empty for no suggestion.
    """
    var count = len(suggestions)
    if count == 0:
        return String("")
    var message = String(" Did you mean ")
    if sub_message != "":
        message += sub_message + " "
    if count == 1:
        return message + '"' + suggestions[0] + '"?'
    if count == 2:
        return message + '"' + suggestions[0] + '" or "' + suggestions[1] + '"?'
    var last = min(count, _MAX_SUGGESTIONS) - 1
    var index = 0
    while index < last:
        message += '"' + suggestions[index] + '", '
        index += 1
    return message + 'or "' + suggestions[last] + '"?'
