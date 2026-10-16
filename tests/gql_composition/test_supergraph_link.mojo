# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/link.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_error_if_directive_is_defined_without_overlapping_locations_across_subgraph() raises:
    # v2.0 > error if directive is defined without overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [b] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import() raises:
    # v2.0 > error if two different major versions of the same spec were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [b] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_directive_composition_error_the_same_composed_directive_used_under_differen() raises:
    # v2.0 > DIRECTIVE_COMPOSITION_ERROR: the same composed directive used under different names (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower\"}]) @composeDirective(name: \"@lower\")\n\ndirective @lower on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lower {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower_case\"}]) @composeDirective(name: \"@lower_case\")\n\ndirective @lower_case on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  text: String! @lower_case\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [b] Cannot import unknown element \"@composeDirective\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [c] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_2() raises:
    # v2.0 > error if two different major versions of the same spec were used to import two different directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"@uppercase\"]) @composeDirective(name: \"@uppercase\")\n\ndirective @uppercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @uppercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [b] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_3() raises:
    # v2.0 > error if two different major versions of the same spec were used to import two different kind of definitions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"UppercaseString\"])\n\nscalar UppercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: UppercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_error_if_two_different_specs_were_used_to_import_the_same_directive() raises:
    # v2.0 > error if two different specs were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [b] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_0_error_if_two_different_specs_were_used_to_import_the_same_directive_alias() raises:
    # v2.0 > error if two different specs were used to import the same directive (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [{name: \"@lower\", as: \"@lowercase\"}]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@composeDirective\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [b] Cannot import unknown element \"@composeDirective\".",
        ],
    )


def test_v2_1_error_if_directive_is_defined_without_overlapping_locations_across_subgraph() raises:
    # v2.1 > error if directive is defined without overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import() raises:
    # v2.1 > error if two different major versions of the same spec were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_directive_composition_error_the_same_composed_directive_used_under_differen() raises:
    # v2.1 > DIRECTIVE_COMPOSITION_ERROR: the same composed directive used under different names (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower\"}]) @composeDirective(name: \"@lower\")\n\ndirective @lower on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lower {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower_case\"}]) @composeDirective(name: \"@lower_case\")\n\ndirective @lower_case on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  text: String! @lower_case\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_2() raises:
    # v2.1 > error if two different major versions of the same spec were used to import two different directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"@uppercase\"]) @composeDirective(name: \"@uppercase\")\n\ndirective @uppercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @uppercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_3() raises:
    # v2.1 > error if two different major versions of the same spec were used to import two different kind of definitions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"UppercaseString\"])\n\nscalar UppercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: UppercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_error_if_two_different_specs_were_used_to_import_the_same_directive() raises:
    # v2.1 > error if two different specs were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_1_error_if_two_different_specs_were_used_to_import_the_same_directive_alias() raises:
    # v2.1 > error if two different specs were used to import the same directive (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [{name: \"@lower\", as: \"@lowercase\"}]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_error_if_directive_is_defined_without_overlapping_locations_across_subgraph() raises:
    # v2.2 > error if directive is defined without overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import() raises:
    # v2.2 > error if two different major versions of the same spec were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_directive_composition_error_the_same_composed_directive_used_under_differen() raises:
    # v2.2 > DIRECTIVE_COMPOSITION_ERROR: the same composed directive used under different names (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower\"}]) @composeDirective(name: \"@lower\")\n\ndirective @lower on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lower {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower_case\"}]) @composeDirective(name: \"@lower_case\")\n\ndirective @lower_case on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  text: String! @lower_case\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_2() raises:
    # v2.2 > error if two different major versions of the same spec were used to import two different directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"@uppercase\"]) @composeDirective(name: \"@uppercase\")\n\ndirective @uppercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @uppercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_3() raises:
    # v2.2 > error if two different major versions of the same spec were used to import two different kind of definitions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"UppercaseString\"])\n\nscalar UppercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: UppercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_error_if_two_different_specs_were_used_to_import_the_same_directive() raises:
    # v2.2 > error if two different specs were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_2_error_if_two_different_specs_were_used_to_import_the_same_directive_alias() raises:
    # v2.2 > error if two different specs were used to import the same directive (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.2\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [{name: \"@lower\", as: \"@lowercase\"}]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_error_if_directive_is_defined_without_overlapping_locations_across_subgraph() raises:
    # v2.3 > error if directive is defined without overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import() raises:
    # v2.3 > error if two different major versions of the same spec were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_directive_composition_error_the_same_composed_directive_used_under_differen() raises:
    # v2.3 > DIRECTIVE_COMPOSITION_ERROR: the same composed directive used under different names (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower\"}]) @composeDirective(name: \"@lower\")\n\ndirective @lower on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lower {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower_case\"}]) @composeDirective(name: \"@lower_case\")\n\ndirective @lower_case on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  text: String! @lower_case\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_2() raises:
    # v2.3 > error if two different major versions of the same spec were used to import two different directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"@uppercase\"]) @composeDirective(name: \"@uppercase\")\n\ndirective @uppercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @uppercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_3() raises:
    # v2.3 > error if two different major versions of the same spec were used to import two different kind of definitions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"UppercaseString\"])\n\nscalar UppercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: UppercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_error_if_two_different_specs_were_used_to_import_the_same_directive() raises:
    # v2.3 > error if two different specs were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_3_error_if_two_different_specs_were_used_to_import_the_same_directive_alias() raises:
    # v2.3 > error if two different specs were used to import the same directive (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.3\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [{name: \"@lower\", as: \"@lowercase\"}]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_error_if_directive_is_defined_without_overlapping_locations_across_subgraph() raises:
    # v2.4 > error if directive is defined without overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import() raises:
    # v2.4 > error if two different major versions of the same spec were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_directive_composition_error_the_same_composed_directive_used_under_differen() raises:
    # v2.4 > DIRECTIVE_COMPOSITION_ERROR: the same composed directive used under different names (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower\"}]) @composeDirective(name: \"@lower\")\n\ndirective @lower on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lower {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower_case\"}]) @composeDirective(name: \"@lower_case\")\n\ndirective @lower_case on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  text: String! @lower_case\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_2() raises:
    # v2.4 > error if two different major versions of the same spec were used to import two different directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"@uppercase\"]) @composeDirective(name: \"@uppercase\")\n\ndirective @uppercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @uppercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_3() raises:
    # v2.4 > error if two different major versions of the same spec were used to import two different kind of definitions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"UppercaseString\"])\n\nscalar UppercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: UppercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_error_if_two_different_specs_were_used_to_import_the_same_directive() raises:
    # v2.4 > error if two different specs were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_4_error_if_two_different_specs_were_used_to_import_the_same_directive_alias() raises:
    # v2.4 > error if two different specs were used to import the same directive (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.4\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [{name: \"@lower\", as: \"@lowercase\"}]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_error_if_directive_is_defined_without_overlapping_locations_across_subgraph() raises:
    # v2.5 > error if directive is defined without overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import() raises:
    # v2.5 > error if two different major versions of the same spec were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_directive_composition_error_the_same_composed_directive_used_under_differen() raises:
    # v2.5 > DIRECTIVE_COMPOSITION_ERROR: the same composed directive used under different names (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower\"}]) @composeDirective(name: \"@lower\")\n\ndirective @lower on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lower {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower_case\"}]) @composeDirective(name: \"@lower_case\")\n\ndirective @lower_case on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  text: String! @lower_case\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_2() raises:
    # v2.5 > error if two different major versions of the same spec were used to import two different directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"@uppercase\"]) @composeDirective(name: \"@uppercase\")\n\ndirective @uppercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @uppercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_3() raises:
    # v2.5 > error if two different major versions of the same spec were used to import two different kind of definitions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"UppercaseString\"])\n\nscalar UppercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: UppercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_error_if_two_different_specs_were_used_to_import_the_same_directive() raises:
    # v2.5 > error if two different specs were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_5_error_if_two_different_specs_were_used_to_import_the_same_directive_alias() raises:
    # v2.5 > error if two different specs were used to import the same directive (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.5\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [{name: \"@lower\", as: \"@lowercase\"}]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_error_if_directive_is_defined_without_overlapping_locations_across_subgraph() raises:
    # v2.6 > error if directive is defined without overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import() raises:
    # v2.6 > error if two different major versions of the same spec were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_directive_composition_error_the_same_composed_directive_used_under_differen() raises:
    # v2.6 > DIRECTIVE_COMPOSITION_ERROR: the same composed directive used under different names (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower\"}]) @composeDirective(name: \"@lower\")\n\ndirective @lower on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lower {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower_case\"}]) @composeDirective(name: \"@lower_case\")\n\ndirective @lower_case on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  text: String! @lower_case\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_2() raises:
    # v2.6 > error if two different major versions of the same spec were used to import two different directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"@uppercase\"]) @composeDirective(name: \"@uppercase\")\n\ndirective @uppercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @uppercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_3() raises:
    # v2.6 > error if two different major versions of the same spec were used to import two different kind of definitions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"UppercaseString\"])\n\nscalar UppercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: UppercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_error_if_two_different_specs_were_used_to_import_the_same_directive() raises:
    # v2.6 > error if two different specs were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_6_error_if_two_different_specs_were_used_to_import_the_same_directive_alias() raises:
    # v2.6 > error if two different specs were used to import the same directive (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.6\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [{name: \"@lower\", as: \"@lowercase\"}]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_error_if_directive_is_defined_without_overlapping_locations_across_subgraph() raises:
    # v2.7 > error if directive is defined without overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import() raises:
    # v2.7 > error if two different major versions of the same spec were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_directive_composition_error_the_same_composed_directive_used_under_differen() raises:
    # v2.7 > DIRECTIVE_COMPOSITION_ERROR: the same composed directive used under different names (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower\"}]) @composeDirective(name: \"@lower\")\n\ndirective @lower on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lower {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower_case\"}]) @composeDirective(name: \"@lower_case\")\n\ndirective @lower_case on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  text: String! @lower_case\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_2() raises:
    # v2.7 > error if two different major versions of the same spec were used to import two different directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"@uppercase\"]) @composeDirective(name: \"@uppercase\")\n\ndirective @uppercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @uppercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_3() raises:
    # v2.7 > error if two different major versions of the same spec were used to import two different kind of definitions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"UppercaseString\"])\n\nscalar UppercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: UppercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_error_if_two_different_specs_were_used_to_import_the_same_directive() raises:
    # v2.7 > error if two different specs were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_7_error_if_two_different_specs_were_used_to_import_the_same_directive_alias() raises:
    # v2.7 > error if two different specs were used to import the same directive (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.7\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [{name: \"@lower\", as: \"@lowercase\"}]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_error_if_directive_is_defined_without_overlapping_locations_across_subgraph() raises:
    # v2.8 > error if directive is defined without overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import() raises:
    # v2.8 > error if two different major versions of the same spec were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_directive_composition_error_the_same_composed_directive_used_under_differen() raises:
    # v2.8 > DIRECTIVE_COMPOSITION_ERROR: the same composed directive used under different names (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower\"}]) @composeDirective(name: \"@lower\")\n\ndirective @lower on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lower {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower_case\"}]) @composeDirective(name: \"@lower_case\")\n\ndirective @lower_case on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  text: String! @lower_case\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_2() raises:
    # v2.8 > error if two different major versions of the same spec were used to import two different directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"@uppercase\"]) @composeDirective(name: \"@uppercase\")\n\ndirective @uppercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @uppercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_3() raises:
    # v2.8 > error if two different major versions of the same spec were used to import two different kind of definitions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"UppercaseString\"])\n\nscalar UppercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: UppercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_error_if_two_different_specs_were_used_to_import_the_same_directive() raises:
    # v2.8 > error if two different specs were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_8_error_if_two_different_specs_were_used_to_import_the_same_directive_alias() raises:
    # v2.8 > error if two different specs were used to import the same directive (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.8\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [{name: \"@lower\", as: \"@lowercase\"}]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_error_if_directive_is_defined_without_overlapping_locations_across_subgraph() raises:
    # v2.9 > error if directive is defined without overlapping locations across subgraphs and all included in @composeDirective
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}\n\ntype Query {\n  users: [User]\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import() raises:
    # v2.9 > error if two different major versions of the same spec were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") @lowercase {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lowercase {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_directive_composition_error_the_same_composed_directive_used_under_differen() raises:
    # v2.9 > DIRECTIVE_COMPOSITION_ERROR: the same composed directive used under different names (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower\"}]) @composeDirective(name: \"@lower\")\n\ndirective @lower on OBJECT | FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment @lower {\n  id: ID!\n  text: String!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
            sg(
                "c",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lowercase/v1.0\", import: [{name: \"@lowercase\", as: \"@lower_case\"}]) @composeDirective(name: \"@lower_case\")\n\ndirective @lower_case on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  reviews: [Review]\n}\n\ntype Review {\n  id: ID!\n  text: String! @lower_case\n}\n\ntype Query {\n  reviews: [Review]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_2() raises:
    # v2.9 > error if two different major versions of the same spec were used to import two different directives
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"@uppercase\"]) @composeDirective(name: \"@uppercase\")\n\ndirective @uppercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @uppercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_error_if_two_different_major_versions_of_the_same_spec_were_used_to_import_3() raises:
    # v2.9 > error if two different major versions of the same spec were used to import two different kind of definitions
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\"]) @link(url: \"https://myspecs.dev/casing/v2.3\", import: [\"UppercaseString\"])\n\nscalar UppercaseString\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: UppercaseString!\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_error_if_two_different_specs_were_used_to_import_the_same_directive() raises:
    # v2.9 > error if two different specs were used to import the same directive
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def test_v2_9_error_if_two_different_specs_were_used_to_import_the_same_directive_alias() raises:
    # v2.9 > error if two different specs were used to import the same directive (alias)
    check(
        [
            sg(
                "a",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/casing/v1.1\", import: [\"@lowercase\"]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\ntype User @key(fields: \"id\") {\n  id: ID!\n  name: String! @lowercase\n}",
            ),
            sg(
                "b",
                "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.9\", import: [\"@key\", \"@composeDirective\"]) @link(url: \"https://myspecs.dev/lower/v2.3\", import: [{name: \"@lower\", as: \"@lowercase\"}]) @composeDirective(name: \"@lowercase\")\n\ndirective @lowercase on FIELD_DEFINITION\n\nextend type User @key(fields: \"id\") {\n  id: ID!\n  comments: [Comment]\n}\n\ntype Comment {\n  id: ID!\n  text: String! @lowercase\n}\n\ntype Query {\n  comments: [Comment]\n}",
            ),
        ],
        [
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
