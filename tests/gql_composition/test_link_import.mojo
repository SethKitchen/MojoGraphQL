# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the `@link` checks of `gql_composition.link` and `gql_composition.validate`.

Upstream has no test file for these cases. The expected errors are those of
the subgraph phase of Hive Federation Composition v0.27.0 `validate` in
Node.js on the same subgraphs.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_import_strings() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [\"Type\", \"@dir\"])\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
        ],
    )


def test_import_objects() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: \"@a\", as: \"@b\" }, { name: \"T\" }, { name: \"U\", as: \"V\" }])\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
        ],
    )


def test_import_empty_list() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [])\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
        ],
    )


def test_import_not_a_list() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: \"x\")\ntype Query { a: Int }\n"),
        ],
        [
            "THROWS Invalid import binding: \"x\": Error: Expected an array",
        ],
    )


def test_import_object_not_list() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: { name: \"x\" })\ntype Query { a: Int }\n"),
        ],
        [
            "THROWS Invalid import binding: {name: \"x\"}: Error: Expected an array",
        ],
    )


def test_import_int() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [1])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [1]: Error: Syntax",
        ],
    )


def test_import_zero() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [0])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [0]: Error: Syntax",
        ],
    )


def test_import_float() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [1.5])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [1.5]: Error: Syntax",
        ],
    )


def test_import_float_zero() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [0.0])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [0.0]: Error: Syntax",
        ],
    )


def test_import_exponent_zero() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [0e5])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [0e5]: Error: Syntax",
        ],
    )


def test_import_exponent() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [1e5])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [1e5]: Error: Syntax",
        ],
    )


def test_import_true() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [true])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [true]: Error: Syntax",
        ],
    )


def test_import_false() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [false])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [false]: Error: Syntax",
        ],
    )


def test_import_null() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [null])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [null]: TypeError: Cannot read properties of null (reading 'name')",
        ],
    )


def test_import_enum() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [Foo])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [Foo]: SyntaxError: JSON5: invalid character 'F' at 1:2",
        ],
    )


def test_import_enum_infinity() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [Infinity])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [Infinity]: Error: Syntax",
        ],
    )


def test_import_enum_infinite() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [Infinite])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [Infinite]: SyntaxError: JSON5: invalid character 'e' at 1:9",
        ],
    )


def test_import_enum_nan() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [NaN])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [NaN]: Error: Syntax",
        ],
    )


def test_import_enum_nab() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [NaB])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [NaB]: SyntaxError: JSON5: invalid character 'B' at 1:4",
        ],
    )


def test_import_enum_t() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [tru])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [tru]: SyntaxError: JSON5: invalid character ']' at 1:5",
        ],
    )


def test_import_enum_f() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [fals])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [fals]: SyntaxError: JSON5: invalid character ']' at 1:6",
        ],
    )


def test_import_enum_n() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [nul])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [nul]: SyntaxError: JSON5: invalid character ']' at 1:5",
        ],
    )


def test_import_enum_nulls() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [nulls])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [nulls]: SyntaxError: JSON5: invalid character 's' at 1:6",
        ],
    )


def test_import_enum_truex() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [truex])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [truex]: SyntaxError: JSON5: invalid character 'x' at 1:6",
        ],
    )


def test_import_enum_other() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [x_y])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [x_y]: SyntaxError: JSON5: invalid character 'x' at 1:2",
        ],
    )


def test_import_enum_second() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [\"A\", B])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [\"A\", B]: SyntaxError: JSON5: invalid character 'B' at 1:7",
        ],
    )


def test_import_enum_nested() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: X }])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [{name: X}]: SyntaxError: JSON5: invalid character 'X' at 1:9",
        ],
    )


def test_import_block_string() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [\"\"\"x\"\"\"])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [\"\"\"\nx\n\"\"\"]: SyntaxError: JSON5: invalid character '\\\"' at 1:4",
        ],
    )


def test_import_block_string_in_object() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: \"\"\"@x\"\"\" }])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [{name: \"\"\"\n@x\n\"\"\"}]: SyntaxError: JSON5: invalid character '\\\"' at 1:11",
        ],
    )


def test_import_quote_in_string() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [\"a\\\"b\"])\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
        ],
    )


def test_import_list_in_list() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [[\"a\"]])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [[\"a\"]]: Error: Syntax",
        ],
    )


def test_import_object_without_name() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ as: \"@b\" }])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [{as: \"@b\"}]: Error: Syntax",
        ],
    )


def test_import_object_empty_name() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: \"\" }])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [{name: \"\"}]: Error: Syntax",
        ],
    )


def test_import_object_name_int() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: 1 }])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [{name: 1}]: TypeError: binding.name.startsWith is not a function",
        ],
    )


def test_import_object_name_zero() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: 0 }])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [{name: 0}]: Error: Syntax",
        ],
    )


def test_import_object_name_true() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: true }])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [{name: true}]: TypeError: binding.name.startsWith is not a function",
        ],
    )


def test_import_object_name_false() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: false }])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [{name: false}]: Error: Syntax",
        ],
    )


def test_import_object_name_list() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: [] }])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [{name: []}]: TypeError: binding.name.startsWith is not a function",
        ],
    )


def test_import_object_name_object() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: {} }])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [{name: {}}]: TypeError: binding.name.startsWith is not a function",
        ],
    )


def test_import_object_name_null() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: null }])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [{name: null}]: Error: Syntax",
        ],
    )


def test_import_object_as_int() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: \"@a\", as: 1 }])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [{name: \"@a\", as: 1}]: TypeError: binding.as.startsWith is not a function",
        ],
    )


def test_import_object_as_zero() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: \"@a\", as: 0 }])\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
        ],
    )


def test_import_object_as_empty() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: \"@a\", as: \"\" }])\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
        ],
    )


def test_import_object_as_null() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: \"@a\", as: null }])\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
        ],
    )


def test_import_object_as_false() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: \"@a\", as: false }])\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
        ],
    )


def test_import_object_kind_mismatch() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: \"@a\", as: \"B\" }])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [{name: \"@a\", as: \"B\"}]: Error: @a and B must be of the same kind",
        ],
    )


def test_import_object_kind_mismatch_type() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: \"A\", as: \"@b\" }])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [{name: \"A\", as: \"@b\"}]: Error: A and @b must be of the same kind",
        ],
    )


def test_import_object_last_field_wins() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [{ name: \"@a\", name: \"@c\", as: \"@b\", as: \"@d\" }])\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
            "[INVALID_GRAPHQL] [a] There can be only one input field named \"name\".",
            "[INVALID_GRAPHQL] [a] There can be only one input field named \"as\".",
        ],
    )


def test_import_unicode_enum() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\", import: [\"é\", Foo])\ntype Query { a: Int }\n"),
        ],
        [
            "[] [a] Error: Invalid import binding: [\"é\", Foo]: SyntaxError: JSON5: invalid character 'F' at 1:7",
        ],
    )


def test_url_missing() raises:
    check(
        [
            sg("a", "extend schema @link(import: [\"@key\"])\ntype Query { a: Int }\n"),
        ],
        [
            "THROWS Invalid @link directive",
        ],
    )


def test_url_not_string() raises:
    check(
        [
            sg("a", "extend schema @link(url: 1)\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
        ],
    )


def test_url_without_import() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\")\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
        ],
    )


def test_duplicate_identity() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.0\") @link(url: \"https://example.com/thing/v2.0\") @link(url: \"https://example.com/thing/v3.0\")\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Duplicate inclusion of feature https://example.com/thing",
        ],
    )


def test_bad_version_form() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1\")\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_LINK_IDENTIFIER] [a] Expected a version string (of the form v1.2), got v1",
        ],
    )


def test_bad_version_x() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/vX.1\")\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
        ],
    )


def test_bad_version_two_digits() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v10.20\")\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
        ],
    )


def test_bad_version_dot_letter() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.x\")\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_LINK_IDENTIFIER] [a] Expected a version string (of the form v1.2), got v1.x",
        ],
    )


def test_bad_version_short() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://example.com/thing/v1.\")\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_LINK_IDENTIFIER] [a] Expected a version string (of the form v1.2), got v1.",
        ],
    )


def test_apollo_root() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev\")\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_LINK_IDENTIFIER] [a] Invalid @link url 'https://specs.apollo.dev': expected '/<feature>/vX.Y' (for example '/federation/v2.9')",
        ],
    )


def test_apollo_root_slash() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/\")\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_LINK_IDENTIFIER] [a] Invalid @link url 'https://specs.apollo.dev': expected '/<feature>/vX.Y' (for example '/federation/v2.9')",
        ],
    )


def test_apollo_no_version() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation\")\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_LINK_IDENTIFIER] [a] Expected a version string (of the form v1.2), got null",
        ],
    )


def test_apollo_version_only() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/v2.0\")\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
        ],
    )


def test_apollo_federation_bad() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v3.0\")\ntype Query { a: Int }\n"),
        ],
        [
            "[UNKNOWN_FEDERATION_LINK_VERSION] [a] Invalid version v3.0 for the federation feature in @link directive on schema",
        ],
    )


def test_apollo_federation_unknown_import() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\", \"@nope\", \"Nope\", \"FieldSet\"])\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"@nope\".",
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown element \"Nope\".",
        ],
    )


def test_apollo_federation_aliased_import() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [{ name: \"@key\", as: \"@id\" }])\ntype Query { a: Int }\ntype T @id(fields: \"a\") { a: Int }\n"),
        ],
        [
        ],
    )


def test_apollo_link_versions() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/link/v1.0\") @link(url: \"https://specs.apollo.dev/link/v2.0\")\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Duplicate inclusion of feature https://specs.apollo.dev/link",
            "[UNKNOWN_LINK_VERSION] [a] Schema uses unknown version v2.0 of the link spec",
        ],
    )


def test_apollo_tag_versions() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/tag/v0.2\") @link(url: \"https://specs.apollo.dev/inaccessible/v0.3\")\ntype Query { a: Int }\n"),
        ],
        [
            "[UNKNOWN_LINK_VERSION] [a] Schema uses unknown version v0.3 of the inaccessible spec",
        ],
    )


def test_apollo_join_versions() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/join/v0.5\") @link(url: \"https://specs.apollo.dev/core/v0.3\") @link(url: \"https://specs.apollo.dev/kotlin_labs/v0.1\")\ntype Query { a: Int }\n"),
        ],
        [
            "[UNKNOWN_LINK_VERSION] [a] Schema uses unknown version v0.3 of the core spec",
        ],
    )


def test_apollo_unknown_feature() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/other/v9.9\")\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown directive \"@link\".",
        ],
    )


def test_link_on_schema_definition() raises:
    check(
        [
            sg("a", "schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"]) { query: Query }\ntype Query { a: Int }\n"),
        ],
        [
        ],
    )


def test_two_schema_extensions() raises:
    check(
        [
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v2.0\", import: [\"@key\"])\nextend schema @link(url: \"https://specs.apollo.dev/federation/v2.1\", import: [\"@key\"])\ntype Query { a: Int }\n"),
        ],
        [
            "[INVALID_LINK_DIRECTIVE_USAGE] [a] Duplicate inclusion of feature https://specs.apollo.dev/federation",
        ],
    )


def test_links_in_two_subgraphs() raises:
    check(
        [
            sg("b", "extend schema @link(url: \"https://specs.apollo.dev/federation/v9.0\")\ntype Query { a: Int }\n"),
            sg("a", "extend schema @link(url: \"https://specs.apollo.dev/federation/v8.0\")\ntype Query { a: Int }\n"),
        ],
        [
            "[UNKNOWN_FEDERATION_LINK_VERSION] [a] Invalid version v8.0 for the federation feature in @link directive on schema",
            "[UNKNOWN_FEDERATION_LINK_VERSION] [b] Invalid version v9.0 for the federation feature in @link directive on schema",
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
