# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The "Did you mean" list of the validation rules, without allocations.

Port of graphql-js 16.14.2 `jsutils/suggestionList.ts` (`suggestionList`
and `LexicalDistance`). `gql_schema.suggestions.suggestion_list` is the same
function over a `List[String]`. A rule here can offer thousands of options,
such as every type of a large schema, so `Suggester` takes the options one
at a time and reuses its buffers. It rejects an option whose length, or
whose count of each character, is too far from the input before it
measures the distance. Both are lower bounds of the distance, so the result
is the same list in the same order.
"""

from gql_schema.suggestions import natural_compare


struct Suggester(Movable):
    """The graphql-js `suggestionList`, fed one option at a time."""

    var _input: String
    var _lower: List[UInt8]
    var _threshold: Int
    var _counts: SIMD[DType.int16, 128]
    var _option: List[UInt8]
    var _rows: List[Int]
    var _found: List[String]
    var _distances: List[Int]

    def __init__(out self, input: StringSlice):
        """Start a list of suggestions for a text.

        Args:
            input: The text that was given.
        """
        self._input = String(input)
        var bytes = input.as_bytes()
        self._lower = List[UInt8](capacity=len(bytes))
        for byte in bytes:
            self._lower.append(_to_lower(byte))
        self._counts = SIMD[DType.int16, 128](0)
        for byte in self._lower:
            self._counts[Int(byte & 127)] += 1
        self._threshold = (len(bytes) * 2) // 5 + 1
        self._option = List[UInt8]()
        self._rows = List[Int]()
        self._found = List[String]()
        self._distances = List[Int]()

    def consider(mut self, option: StringSlice):
        """Offer one option.

        Args:
            option: A text that is valid where the input was given.
        """
        var distance = self._measure(option)
        if distance < 0:
            return
        for ref found in self._found:
            if found == option:
                return
        # An insertion sort by distance, then natural order: the order of
        # graphql-js `Object.keys(...).sort(...)`.
        var at = len(self._found)
        while at > 0 and (
            self._distances[at - 1] > distance
            or (
                self._distances[at - 1] == distance
                and natural_compare(self._found[at - 1], option) > 0
            )
        ):
            at -= 1
        self._found.insert(at, String(option))
        self._distances.insert(at, distance)

    def take(deinit self) -> List[String]:
        """Return the suggestions, the closest first.

        Returns:
            Each option at most `floor(0.4 * length) + 1` edits away, once.
        """
        return self._found^

    def _measure(mut self, option: StringSlice) -> Int:
        """graphql-js `LexicalDistance.measure`: the edit distance, or -1
        when it is above the threshold."""
        var bytes = option.as_bytes()
        var option_length = len(bytes)
        var input_length = len(self._lower)
        var difference = option_length - input_length
        if difference < 0:
            difference = -difference
        if difference > self._threshold:
            return -1
        # The bag distance, the larger of the characters that one text has
        # more of and those it has fewer of, is never above the edit
        # distance: a cheap way to reject most options.
        var counts = self._counts
        for byte in bytes:
            counts[Int(_to_lower(byte) & 127)] -= 1
        var zero = SIMD[DType.int16, 128](0)
        var more = Int(max(counts, zero).reduce_add())
        var fewer = Int(max(-counts, zero).reduce_add())
        if max(more, fewer) > self._threshold:
            return -1
        if option == self._input:
            return 0
        self._option.clear()
        var same = option_length == input_length
        for index in range(option_length):
            var byte = _to_lower(bytes[index])
            self._option.append(byte)
            if same and byte != self._lower[index]:
                same = False
        if same:
            return 1
        if option_length < input_length:
            return _distance(
                self._lower, self._option, self._threshold, self._rows
            )
        return _distance(self._option, self._lower, self._threshold, self._rows)


@always_inline
def _to_lower(byte: UInt8) -> UInt8:
    """Return an ASCII letter in lower case, and any other byte as it is."""
    if byte >= 65 and byte <= 90:
        return byte + 32
    return byte


def _distance(
    a: List[UInt8], b: List[UInt8], threshold: Int, mut rows: List[Int]
) -> Int:
    """The rows of graphql-js `LexicalDistance.measure`; `a` is the longer
    text."""
    var a_length = len(a)
    var b_length = len(b)
    var width = b_length + 1
    if len(rows) < 3 * width:
        rows.resize(3 * width, 0)
    var column = 0
    while column < width:
        rows[column] = column
        column += 1
    var i = 1
    while i <= a_length:
        var up = ((i - 1) % 3) * width
        var current = (i % 3) * width
        var before = ((i + 1) % 3) * width
        rows[current] = i
        var smallest = i
        for j in range(1, width):
            var cost = 0 if a[i - 1] == b[j - 1] else 1
            var cell = min(
                rows[up + j] + 1,
                rows[current + j - 1] + 1,
                rows[up + j - 1] + cost,
            )
            if (
                i > 1
                and j > 1
                and a[i - 1] == b[j - 2]
                and a[i - 2] == b[j - 1]
            ):
                cell = min(cell, rows[before + j - 2] + 1)
            if cell < smallest:
                smallest = cell
            rows[current + j] = cell
        if smallest > threshold:
            return -1
        i += 1
    var distance = rows[(a_length % 3) * width + b_length]
    if distance <= threshold:
        return distance
    return -1
