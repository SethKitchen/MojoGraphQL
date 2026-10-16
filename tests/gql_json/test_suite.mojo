# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The parsing tests of the JSONTestSuite (Nicolas Seriot, MIT), at
revision 1ef36fa01286573e846ac449e8683f8833c5b26a, `test_parsing/`.

Every file is in `fixtures/test_parsing/`, byte for byte. A `y_` file must
parse, an `n_` file must not, and an `i_` file is a choice that the suite
leaves to the parser. `I_ACCEPTED` lists the `i_` files that `gql_json`
accepts; it refuses every other one. The reasons:

- The `i_number_` files are valid RFC 8259 numbers out of the `Float64`
  range. They parse; `as_float64` gives an infinity or a zero, as
  `JSON.parse` does.
- `i_structure_500_nested_arrays.json` is within the default depth of 1000.
- A lone surrogate in a `\\u` escape is refused: a Mojo `String` cannot
  hold it. `JSON.parse` accepts it.
- Invalid UTF-8, UTF-16 and a byte order mark are refused, as RFC 8259
  section 8.1 allows.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from _fixtures import fixture_names, parse_or_message, read_fixture

comptime I_ACCEPTED: Array[StaticString, 11] = [
    "i_number_double_huge_neg_exp.json",
    "i_number_huge_exp.json",
    "i_number_neg_int_huge_exp.json",
    "i_number_pos_double_huge_exp.json",
    "i_number_real_neg_overflow.json",
    "i_number_real_pos_overflow.json",
    "i_number_real_underflow.json",
    "i_number_too_big_neg_int.json",
    "i_number_too_big_pos_int.json",
    "i_number_very_big_negative_int.json",
    "i_structure_500_nested_arrays.json",
]
"""The implementation-defined files that the parser accepts."""


def _is_accepted(name: String) -> Bool:
    var accepted = materialize[I_ACCEPTED]()
    for index in range(len(accepted)):
        if name == accepted[index]:
            return True
    return False


def _check(prefix: String, expected_count: Int) raises:
    var count = 0
    for name in fixture_names("test_parsing"):
        if not name.startswith(prefix):
            continue
        count += 1
        var result = parse_or_message(read_fixture("test_parsing/" + name))
        var accept = prefix == "y_" or (prefix == "i_" and _is_accepted(name))
        if result[0] != accept:
            raise Error(
                String(
                    name,
                    ": expected ",
                    "accept" if accept else "reject",
                    ", got ",
                    result[1] if not result[0] else "accept",
                )
            )
    assert_equal(count, expected_count)


def test_every_y_file_is_accepted() raises:
    _check("y_", 95)


def test_every_n_file_is_rejected() raises:
    _check("n_", 188)


def test_every_i_file_follows_the_documented_choice() raises:
    _check("i_", 35)


def test_the_accepted_i_files_exist() raises:
    var names = fixture_names("test_parsing")
    var accepted = materialize[I_ACCEPTED]()
    for index in range(len(accepted)):
        var found = False
        for name in names:
            if name == accepted[index]:
                found = True
        assert_true(found, accepted[index])


def test_a_lone_surrogate_has_a_clear_error() raises:
    var result = parse_or_message(
        read_fixture("test_parsing/i_string_lone_second_surrogate.json")
    )
    assert_false(result[0])
    assert_true(result[1].startswith("Lone surrogate in a \\u escape"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
