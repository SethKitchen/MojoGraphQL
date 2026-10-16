# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/to-categorize.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_valid_composed_directive_gets_an_empty_object_instead_of_name() raises:
    # v2.0 > valid - composed directive gets an empty object instead of { name }
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/hello/v1.0\", import: [\"@hello\", \"Person\"]) @composeDirective(name: \"@hello\")\n\ndirective @hello(person: Person) on FIELD_DEFINITION\n\ninput Person {\n  name: String!\n}\n\ntype Query {\n  words: [String!]! @hello(person: {})\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_1_valid_composed_directive_gets_an_empty_object_instead_of_name() raises:
    # v2.1 > valid - composed directive gets an empty object instead of { name }
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/hello/v1.0\", import: [\"@hello\", \"Person\"]) @composeDirective(name: \"@hello\")\n\ndirective @hello(person: Person) on FIELD_DEFINITION\n\ninput Person {\n  name: String!\n}\n\ntype Query {\n  words: [String!]! @hello(person: {})\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_valid_composed_directive_gets_an_empty_object_instead_of_name() raises:
    # v2.2 > valid - composed directive gets an empty object instead of { name }
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/hello/v1.0\", import: [\"@hello\", \"Person\"]) @composeDirective(name: \"@hello\")\n\ndirective @hello(person: Person) on FIELD_DEFINITION\n\ninput Person {\n  name: String!\n}\n\ntype Query {\n  words: [String!]! @hello(person: {})\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_valid_composed_directive_gets_an_empty_object_instead_of_name() raises:
    # v2.3 > valid - composed directive gets an empty object instead of { name }
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/hello/v1.0\", import: [\"@hello\", \"Person\"]) @composeDirective(name: \"@hello\")\n\ndirective @hello(person: Person) on FIELD_DEFINITION\n\ninput Person {\n  name: String!\n}\n\ntype Query {\n  words: [String!]! @hello(person: {})\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_valid_composed_directive_gets_an_empty_object_instead_of_name() raises:
    # v2.4 > valid - composed directive gets an empty object instead of { name }
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/hello/v1.0\", import: [\"@hello\", \"Person\"]) @composeDirective(name: \"@hello\")\n\ndirective @hello(person: Person) on FIELD_DEFINITION\n\ninput Person {\n  name: String!\n}\n\ntype Query {\n  words: [String!]! @hello(person: {})\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_valid_composed_directive_gets_an_empty_object_instead_of_name() raises:
    # v2.5 > valid - composed directive gets an empty object instead of { name }
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/hello/v1.0\", import: [\"@hello\", \"Person\"]) @composeDirective(name: \"@hello\")\n\ndirective @hello(person: Person) on FIELD_DEFINITION\n\ninput Person {\n  name: String!\n}\n\ntype Query {\n  words: [String!]! @hello(person: {})\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_valid_composed_directive_gets_an_empty_object_instead_of_name() raises:
    # v2.6 > valid - composed directive gets an empty object instead of { name }
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/hello/v1.0\", import: [\"@hello\", \"Person\"]) @composeDirective(name: \"@hello\")\n\ndirective @hello(person: Person) on FIELD_DEFINITION\n\ninput Person {\n  name: String!\n}\n\ntype Query {\n  words: [String!]! @hello(person: {})\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_valid_composed_directive_gets_an_empty_object_instead_of_name() raises:
    # v2.7 > valid - composed directive gets an empty object instead of { name }
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/hello/v1.0\", import: [\"@hello\", \"Person\"]) @composeDirective(name: \"@hello\")\n\ndirective @hello(person: Person) on FIELD_DEFINITION\n\ninput Person {\n  name: String!\n}\n\ntype Query {\n  words: [String!]! @hello(person: {})\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_valid_composed_directive_gets_an_empty_object_instead_of_name() raises:
    # v2.8 > valid - composed directive gets an empty object instead of { name }
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/hello/v1.0\", import: [\"@hello\", \"Person\"]) @composeDirective(name: \"@hello\")\n\ndirective @hello(person: Person) on FIELD_DEFINITION\n\ninput Person {\n  name: String!\n}\n\ntype Query {\n  words: [String!]! @hello(person: {})\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_valid_composed_directive_gets_an_empty_object_instead_of_name() raises:
    # v2.9 > valid - composed directive gets an empty object instead of { name }
    check(
        [
            sg(
                "users",
                "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@composeDirective\"]) @link(url: \"https://myspecs.dev/hello/v1.0\", import: [\"@hello\", \"Person\"]) @composeDirective(name: \"@hello\")\n\ndirective @hello(person: Person) on FIELD_DEFINITION\n\ninput Person {\n  name: String!\n}\n\ntype Query {\n  words: [String!]! @hello(person: {})\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
