# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/base.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_suffix_identical_foo_vs_foo_names_with_a_number() raises:
    # v2.0 > suffix "identical" (foo vs Foo) names with a number
    check(
        [
            sg(
                "Foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Member @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_executable_directive_definition_is_retained_in_supergraph() raises:
    # v2.0 > executable directive definition is retained in supergraph
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_executable_directive_definition_is_retained_if_defined_identical_in_all_sub() raises:
    # v2.0 > executable directive definition is retained if defined identical in all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_executable_directive_definition_is_omitted_if_only_defined_within_a_single() raises:
    # v2.0 > executable directive definition is omitted if only defined within a single subgraph
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  b: Int\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_0_executable_directive_only_contains_locations_shared_between_all_subgraphs() raises:
    # v2.0 > executable directive only contains locations shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_executable_directive_is_removed_if_no_locations_are_shared_between_all_subg() raises:
    # v2.0 > executable directive is removed if no locations are shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_executable_directive_is_only_included_with_executable_definition_locations() raises:
    # v2.0 > executable directive is only included with executable definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_suffix_identical_foo_vs_foo_names_with_a_number() raises:
    # v2.1 > suffix "identical" (foo vs Foo) names with a number
    check(
        [
            sg(
                "Foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Member @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_executable_directive_definition_is_retained_in_supergraph() raises:
    # v2.1 > executable directive definition is retained in supergraph
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_executable_directive_definition_is_retained_if_defined_identical_in_all_sub() raises:
    # v2.1 > executable directive definition is retained if defined identical in all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_executable_directive_definition_is_omitted_if_only_defined_within_a_single() raises:
    # v2.1 > executable directive definition is omitted if only defined within a single subgraph
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  b: Int\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_1_executable_directive_only_contains_locations_shared_between_all_subgraphs() raises:
    # v2.1 > executable directive only contains locations shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_executable_directive_is_removed_if_no_locations_are_shared_between_all_subg() raises:
    # v2.1 > executable directive is removed if no locations are shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_executable_directive_is_only_included_with_executable_definition_locations() raises:
    # v2.1 > executable directive is only included with executable definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_executable_directive_that_is_also_a_compose_directive_is_included_with_exec() raises:
    # v2.1 > executable directive that is also a compose directive is included with executable definition and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_executable_directive_that_is_also_a_compose_directive_and_used_within_the_s() raises:
    # v2.1 > executable directive that is also a compose directive and used within the subgraph schemas is only included with executable definition locations and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int @a\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int @a\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_suffix_identical_foo_vs_foo_names_with_a_number() raises:
    # v2.2 > suffix "identical" (foo vs Foo) names with a number
    check(
        [
            sg(
                "Foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Member @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_executable_directive_definition_is_retained_in_supergraph() raises:
    # v2.2 > executable directive definition is retained in supergraph
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_executable_directive_definition_is_retained_if_defined_identical_in_all_sub() raises:
    # v2.2 > executable directive definition is retained if defined identical in all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_executable_directive_definition_is_omitted_if_only_defined_within_a_single() raises:
    # v2.2 > executable directive definition is omitted if only defined within a single subgraph
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  b: Int\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_2_executable_directive_only_contains_locations_shared_between_all_subgraphs() raises:
    # v2.2 > executable directive only contains locations shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_executable_directive_is_removed_if_no_locations_are_shared_between_all_subg() raises:
    # v2.2 > executable directive is removed if no locations are shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_executable_directive_is_only_included_with_executable_definition_locations() raises:
    # v2.2 > executable directive is only included with executable definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_executable_directive_that_is_also_a_compose_directive_is_included_with_exec() raises:
    # v2.2 > executable directive that is also a compose directive is included with executable definition and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_executable_directive_that_is_also_a_compose_directive_and_used_within_the_s() raises:
    # v2.2 > executable directive that is also a compose directive and used within the subgraph schemas is only included with executable definition locations and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int @a\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int @a\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_suffix_identical_foo_vs_foo_names_with_a_number() raises:
    # v2.3 > suffix "identical" (foo vs Foo) names with a number
    check(
        [
            sg(
                "Foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Member @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_executable_directive_definition_is_retained_in_supergraph() raises:
    # v2.3 > executable directive definition is retained in supergraph
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_executable_directive_definition_is_retained_if_defined_identical_in_all_sub() raises:
    # v2.3 > executable directive definition is retained if defined identical in all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_executable_directive_definition_is_omitted_if_only_defined_within_a_single() raises:
    # v2.3 > executable directive definition is omitted if only defined within a single subgraph
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  b: Int\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_3_executable_directive_only_contains_locations_shared_between_all_subgraphs() raises:
    # v2.3 > executable directive only contains locations shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_executable_directive_is_removed_if_no_locations_are_shared_between_all_subg() raises:
    # v2.3 > executable directive is removed if no locations are shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_executable_directive_is_only_included_with_executable_definition_locations() raises:
    # v2.3 > executable directive is only included with executable definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_executable_directive_that_is_also_a_compose_directive_is_included_with_exec() raises:
    # v2.3 > executable directive that is also a compose directive is included with executable definition and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_executable_directive_that_is_also_a_compose_directive_and_used_within_the_s() raises:
    # v2.3 > executable directive that is also a compose directive and used within the subgraph schemas is only included with executable definition locations and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int @a\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int @a\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_suffix_identical_foo_vs_foo_names_with_a_number() raises:
    # v2.4 > suffix "identical" (foo vs Foo) names with a number
    check(
        [
            sg(
                "Foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Member @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_executable_directive_definition_is_retained_in_supergraph() raises:
    # v2.4 > executable directive definition is retained in supergraph
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_executable_directive_definition_is_retained_if_defined_identical_in_all_sub() raises:
    # v2.4 > executable directive definition is retained if defined identical in all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_executable_directive_definition_is_omitted_if_only_defined_within_a_single() raises:
    # v2.4 > executable directive definition is omitted if only defined within a single subgraph
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  b: Int\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_4_executable_directive_only_contains_locations_shared_between_all_subgraphs() raises:
    # v2.4 > executable directive only contains locations shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_executable_directive_is_removed_if_no_locations_are_shared_between_all_subg() raises:
    # v2.4 > executable directive is removed if no locations are shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_executable_directive_is_only_included_with_executable_definition_locations() raises:
    # v2.4 > executable directive is only included with executable definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_executable_directive_that_is_also_a_compose_directive_is_included_with_exec() raises:
    # v2.4 > executable directive that is also a compose directive is included with executable definition and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_executable_directive_that_is_also_a_compose_directive_and_used_within_the_s() raises:
    # v2.4 > executable directive that is also a compose directive and used within the subgraph schemas is only included with executable definition locations and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int @a\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int @a\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_suffix_identical_foo_vs_foo_names_with_a_number() raises:
    # v2.5 > suffix "identical" (foo vs Foo) names with a number
    check(
        [
            sg(
                "Foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Member @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_executable_directive_definition_is_retained_in_supergraph() raises:
    # v2.5 > executable directive definition is retained in supergraph
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_executable_directive_definition_is_retained_if_defined_identical_in_all_sub() raises:
    # v2.5 > executable directive definition is retained if defined identical in all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_executable_directive_definition_is_omitted_if_only_defined_within_a_single() raises:
    # v2.5 > executable directive definition is omitted if only defined within a single subgraph
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  b: Int\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_5_executable_directive_only_contains_locations_shared_between_all_subgraphs() raises:
    # v2.5 > executable directive only contains locations shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_executable_directive_is_removed_if_no_locations_are_shared_between_all_subg() raises:
    # v2.5 > executable directive is removed if no locations are shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_executable_directive_is_only_included_with_executable_definition_locations() raises:
    # v2.5 > executable directive is only included with executable definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_executable_directive_that_is_also_a_compose_directive_is_included_with_exec() raises:
    # v2.5 > executable directive that is also a compose directive is included with executable definition and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_executable_directive_that_is_also_a_compose_directive_and_used_within_the_s() raises:
    # v2.5 > executable directive that is also a compose directive and used within the subgraph schemas is only included with executable definition locations and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int @a\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int @a\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_suffix_identical_foo_vs_foo_names_with_a_number() raises:
    # v2.6 > suffix "identical" (foo vs Foo) names with a number
    check(
        [
            sg(
                "Foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Member @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_executable_directive_definition_is_retained_in_supergraph() raises:
    # v2.6 > executable directive definition is retained in supergraph
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_executable_directive_definition_is_retained_if_defined_identical_in_all_sub() raises:
    # v2.6 > executable directive definition is retained if defined identical in all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_executable_directive_definition_is_omitted_if_only_defined_within_a_single() raises:
    # v2.6 > executable directive definition is omitted if only defined within a single subgraph
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  b: Int\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_6_executable_directive_only_contains_locations_shared_between_all_subgraphs() raises:
    # v2.6 > executable directive only contains locations shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_executable_directive_is_removed_if_no_locations_are_shared_between_all_subg() raises:
    # v2.6 > executable directive is removed if no locations are shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_executable_directive_is_only_included_with_executable_definition_locations() raises:
    # v2.6 > executable directive is only included with executable definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_executable_directive_that_is_also_a_compose_directive_is_included_with_exec() raises:
    # v2.6 > executable directive that is also a compose directive is included with executable definition and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_executable_directive_that_is_also_a_compose_directive_and_used_within_the_s() raises:
    # v2.6 > executable directive that is also a compose directive and used within the subgraph schemas is only included with executable definition locations and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int @a\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int @a\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_suffix_identical_foo_vs_foo_names_with_a_number() raises:
    # v2.7 > suffix "identical" (foo vs Foo) names with a number
    check(
        [
            sg(
                "Foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Member @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_executable_directive_definition_is_retained_in_supergraph() raises:
    # v2.7 > executable directive definition is retained in supergraph
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_executable_directive_definition_is_retained_if_defined_identical_in_all_sub() raises:
    # v2.7 > executable directive definition is retained if defined identical in all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_executable_directive_definition_is_omitted_if_only_defined_within_a_single() raises:
    # v2.7 > executable directive definition is omitted if only defined within a single subgraph
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  b: Int\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_7_executable_directive_only_contains_locations_shared_between_all_subgraphs() raises:
    # v2.7 > executable directive only contains locations shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_executable_directive_is_removed_if_no_locations_are_shared_between_all_subg() raises:
    # v2.7 > executable directive is removed if no locations are shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_executable_directive_is_only_included_with_executable_definition_locations() raises:
    # v2.7 > executable directive is only included with executable definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_executable_directive_that_is_also_a_compose_directive_is_included_with_exec() raises:
    # v2.7 > executable directive that is also a compose directive is included with executable definition and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_executable_directive_that_is_also_a_compose_directive_and_used_within_the_s() raises:
    # v2.7 > executable directive that is also a compose directive and used within the subgraph schemas is only included with executable definition locations and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int @a\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int @a\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_suffix_identical_foo_vs_foo_names_with_a_number() raises:
    # v2.8 > suffix "identical" (foo vs Foo) names with a number
    check(
        [
            sg(
                "Foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Member @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_executable_directive_definition_is_retained_in_supergraph() raises:
    # v2.8 > executable directive definition is retained in supergraph
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_executable_directive_definition_is_retained_if_defined_identical_in_all_sub() raises:
    # v2.8 > executable directive definition is retained if defined identical in all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_executable_directive_definition_is_omitted_if_only_defined_within_a_single() raises:
    # v2.8 > executable directive definition is omitted if only defined within a single subgraph
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  b: Int\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_8_executable_directive_only_contains_locations_shared_between_all_subgraphs() raises:
    # v2.8 > executable directive only contains locations shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_executable_directive_is_removed_if_no_locations_are_shared_between_all_subg() raises:
    # v2.8 > executable directive is removed if no locations are shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_executable_directive_is_only_included_with_executable_definition_locations() raises:
    # v2.8 > executable directive is only included with executable definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_executable_directive_that_is_also_a_compose_directive_is_included_with_exec() raises:
    # v2.8 > executable directive that is also a compose directive is included with executable definition and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_executable_directive_that_is_also_a_compose_directive_and_used_within_the_s() raises:
    # v2.8 > executable directive that is also a compose directive and used within the subgraph schemas is only included with executable definition locations and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int @a\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int @a\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_suffix_identical_foo_vs_foo_names_with_a_number() raises:
    # v2.9 > suffix "identical" (foo vs Foo) names with a number
    check(
        [
            sg(
                "Foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Member @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_executable_directive_definition_is_retained_in_supergraph() raises:
    # v2.9 > executable directive definition is retained in supergraph
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_executable_directive_definition_is_retained_if_defined_identical_in_all_sub() raises:
    # v2.9 > executable directive definition is retained if defined identical in all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_executable_directive_definition_is_omitted_if_only_defined_within_a_single() raises:
    # v2.9 > executable directive definition is omitted if only defined within a single subgraph
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  b: Int\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_9_executable_directive_only_contains_locations_shared_between_all_subgraphs() raises:
    # v2.9 > executable directive only contains locations shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_executable_directive_is_removed_if_no_locations_are_shared_between_all_subg() raises:
    # v2.9 > executable directive is removed if no locations are shared between all subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_executable_directive_is_only_included_with_executable_definition_locations() raises:
    # v2.9 > executable directive is only included with executable definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_executable_directive_that_is_also_a_compose_directive_is_included_with_exec() raises:
    # v2.9 > executable directive that is also a compose directive is included with executable definition and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_executable_directive_that_is_also_a_compose_directive_and_used_within_the_s() raises:
    # v2.9 > executable directive that is also a compose directive and used within the subgraph schemas is only included with executable definition locations and schema definition locations
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: Int @a\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@composeDirective"]) @link(url: "https://a.dev/a/v1.0",'
                    ' import: ["@a"]) @composeDirective(name:'
                    ' "@a")\n\ndirective @a(n: Int) on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: Int @a\n}"
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
