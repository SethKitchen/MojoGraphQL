# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/EMPTY_MERGED_INPUT_TYPE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are Hive `EMPTY_MERGED_INPUT_TYPE` from
`composeServices` on the same subgraphs. The last test locks an input
that keeps one shared field. It is not in the upstream file.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_empty_merged_input_type() raises:
    # v2.0 > EMPTY_MERGED_INPUT_TYPE
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ninput CreateUserInput {\n  name: String\n '
                    ' email: String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  users:"
                    " [User]\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\nextend input CreateUserInput {\n  tags:'
                    ' [String]\n}\n\ntype Drink @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  drinks:"
                    " [Drink]\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "CreateUserInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
        ],
    )


def test_v2_1_empty_merged_input_type() raises:
    # v2.1 > EMPTY_MERGED_INPUT_TYPE
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ninput CreateUserInput {\n  name: String\n '
                    ' email: String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  users:"
                    " [User]\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\nextend input CreateUserInput {\n  tags:'
                    ' [String]\n}\n\ntype Drink @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  drinks:"
                    " [Drink]\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "CreateUserInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
        ],
    )


def test_v2_2_empty_merged_input_type() raises:
    # v2.2 > EMPTY_MERGED_INPUT_TYPE
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ninput CreateUserInput {\n  name: String\n '
                    ' email: String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  users:"
                    " [User]\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\nextend input CreateUserInput {\n  tags:'
                    ' [String]\n}\n\ntype Drink @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  drinks:"
                    " [Drink]\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "CreateUserInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
        ],
    )


def test_v2_3_empty_merged_input_type() raises:
    # v2.3 > EMPTY_MERGED_INPUT_TYPE
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ninput CreateUserInput {\n  name: String\n '
                    ' email: String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  users:"
                    " [User]\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\nextend input CreateUserInput {\n  tags:'
                    ' [String]\n}\n\ntype Drink @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  drinks:"
                    " [Drink]\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "CreateUserInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
        ],
    )


def test_v2_4_empty_merged_input_type() raises:
    # v2.4 > EMPTY_MERGED_INPUT_TYPE
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ninput CreateUserInput {\n  name: String\n '
                    ' email: String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  users:"
                    " [User]\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\nextend input CreateUserInput {\n  tags:'
                    ' [String]\n}\n\ntype Drink @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  drinks:"
                    " [Drink]\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "CreateUserInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
        ],
    )


def test_v2_5_empty_merged_input_type() raises:
    # v2.5 > EMPTY_MERGED_INPUT_TYPE
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ninput CreateUserInput {\n  name: String\n '
                    ' email: String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  users:"
                    " [User]\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\nextend input CreateUserInput {\n  tags:'
                    ' [String]\n}\n\ntype Drink @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  drinks:"
                    " [Drink]\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "CreateUserInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
        ],
    )


def test_v2_6_empty_merged_input_type() raises:
    # v2.6 > EMPTY_MERGED_INPUT_TYPE
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ninput CreateUserInput {\n  name: String\n '
                    ' email: String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  users:"
                    " [User]\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\nextend input CreateUserInput {\n  tags:'
                    ' [String]\n}\n\ntype Drink @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  drinks:"
                    " [Drink]\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "CreateUserInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
        ],
    )


def test_v2_7_empty_merged_input_type() raises:
    # v2.7 > EMPTY_MERGED_INPUT_TYPE
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ninput CreateUserInput {\n  name: String\n '
                    ' email: String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  users:"
                    " [User]\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\nextend input CreateUserInput {\n  tags:'
                    ' [String]\n}\n\ntype Drink @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  drinks:"
                    " [Drink]\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "CreateUserInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
        ],
    )


def test_v2_8_empty_merged_input_type() raises:
    # v2.8 > EMPTY_MERGED_INPUT_TYPE
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ninput CreateUserInput {\n  name: String\n '
                    ' email: String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  users:"
                    " [User]\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\nextend input CreateUserInput {\n  tags:'
                    ' [String]\n}\n\ntype Drink @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  drinks:"
                    " [Drink]\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "CreateUserInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
        ],
    )


def test_v2_9_empty_merged_input_type() raises:
    # v2.9 > EMPTY_MERGED_INPUT_TYPE
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ninput CreateUserInput {\n  name: String\n '
                    ' email: String\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  users:"
                    " [User]\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\nextend input CreateUserInput {\n  tags:'
                    ' [String]\n}\n\ntype Drink @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}\n\ntype Query {\n  drinks:"
                    " [Drink]\n}"
                ),
            ),
        ],
        [
            (
                "[EMPTY_MERGED_INPUT_TYPE] None of the fields of input object"
                ' type "CreateUserInput" are consistently defined in all the'
                " subgraphs defining that type. As only fields common to all"
                " subgraphs are merged, this would result in an empty type."
            ),
        ],
    )


def test_one_shared_input_field_is_enough() raises:
    # `name` is in both subgraphs, so the merged input is not empty.
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ninput CreateUserInput {\n  name: String\n '
                    " email: String\n}\n\ntype Query {\n  users:"
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ninput CreateUserInput {\n  name: String\n '
                    " tags: [String]\n}\n\ntype Query {\n  drinks:"
                    ' [Drink]\n}\n\ntype Drink @key(fields: "id") {\n  id:'
                    " ID!\n}"
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
