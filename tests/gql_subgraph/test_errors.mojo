# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the errors of `build_subgraph_schema`.

`@apollo/subgraph` 2.14.4 has no tests of these messages beyond `fails on
bad linking`. The expected messages come from `@apollo/subgraph` 2.14.4
itself, run in Node.js with the same SDL, without the source excerpts.
"""

from std.testing import TestSuite, assert_equal
from _helpers import build_error

comptime INVALID = "The schema is not a valid GraphQL schema.. Caused by:\n"
comptime LINK = 'extend schema @link(url: "https://specs.apollo.dev/federation/'


def test_unknown_and_duplicate_types() raises:
    assert_equal(
        build_error("type User @foo { firstName: Bar }"), "Unknown type Bar"
    )
    assert_equal(
        build_error(LINK + 'v2.0") type Query { a: Int } type Query { b: Int }'),
        'There can be only one type named "Query"',
    )


def test_versions_that_are_not_supported() raises:
    assert_equal(
        build_error(LINK + 'v2.15") type Query { a: Int }'),
        INVALID
        + "Invalid version v2.15 for the federation feature in @link directive"
        " on schema",
    )
    assert_equal(
        build_error(LINK + 'v3.0") type Query { a: Int }'),
        INVALID
        + "Invalid version v3.0 for the federation feature in @link directive"
        " on schema",
    )
    assert_equal(
        build_error(LINK + 'v2.x") type Query { a: Int }'),
        "Expected a version string (of the form v1.2), got v2.x",
    )
    assert_equal(
        build_error(LINK + 'v2.") type Query { a: Int }'),
        "Expected a version string (of the form v1.2), got v2.",
    )
    assert_equal(
        build_error(LINK + '2.0") type Query { a: Int }'),
        "Expected a version string (of the form v1.2), got 2.0",
    )


def test_imports_of_unknown_elements() raises:
    assert_equal(
        build_error(
            LINK
            + 'v2.0", import: ["Nope", {name: "FieldSet", as: "FS"}, "@nope",'
            ' "@interfaceObject", "Scope", 7]) type Query { a: Int }'
        ),
        INVALID
        + 'Cannot import unknown element "Nope".\n\nCannot import unknown'
        ' element "@nope".\n\nCannot import unknown element'
        ' "@interfaceObject".\n\nCannot import unknown element "Scope".\n\n'
        "Invalid sub-value 7 for @link(import:) argument: values should be"
        " either strings or input object values of the form { name:"
        ' "<importedElement>", as: "<alias>" }.',
    )


def test_unknown_directives() raises:
    assert_equal(
        build_error("type Query { a: Int @foo b: Int @bar }"),
        INVALID
        + 'Unknown directive "@foo".\n\nUnknown directive "@bar". Did you mean'
        ' "@tag"?',
    )
    assert_equal(
        build_error('type A @kye(fields: "id") { id: ID }'),
        INVALID + 'Unknown directive "@kye". Did you mean "@key"?',
    )
    assert_equal(
        build_error("type A @inaccessible { id: ID }"),
        INVALID
        + 'Unknown directive "@inaccessible". If you meant the "@inaccessible"'
        " federation 2 directive, note that this schema is a federation 1"
        " schema. To be a federation 2 schema, it needs to @link to the"
        " federation specifcation v2.",
    )


def test_invalid_import_sub_values() raises:
    assert_equal(
        build_error(LINK + 'v2.0", import: [7]) type Query { a: Int }'),
        INVALID
        + "Invalid sub-value 7 for @link(import:) argument: values should be"
        ' either strings or input object values of the form { name:'
        ' "<importedElement>", as: "<alias>" }.',
    )


def test_unknown_federation_directives_in_federation_2() raises:
    assert_equal(
        build_error(
            LINK
            + 'v2.3", as: "fed", import: ["@key"]) type A @shareable'
            ' @federation__key(fields: "id") { id: ID }'
        ),
        INVALID
        + 'Unknown directive "@shareable". If you meant the "@shareable"'
        " federation directive, you should use fully-qualified name"
        ' "@fed__shareable" or add "@shareable" to the `import` argument of'
        ' the @link to the federation specification.\n\nUnknown directive'
        ' "@federation__key".',
    )
    assert_equal(
        build_error(LINK + 'v2.0", import: ["@key"]) type Query { a: Int @federation__foo }'),
        INVALID
        + 'Unknown directive "@federation__foo". Did you mean'
        ' "@federation__tag", "@federation__extends", or'
        ' "@federation__provides"?',
    )


def test_graphql_validation_errors() raises:
    assert_equal(
        build_error(
            "directive @key(fields: _FieldSet!) on OBJECT | INTERFACE scalar"
            ' _FieldSet type A @key(fields: "id", resolvable: false) { id: ID }'
        ),
        '[<unnamed>] Unknown argument "resolvable" on directive "@key".',
    )
    assert_equal(
        build_error(
            "directive @custom on FIELD_DEFINITION input In @custom { a: Int }"
            " interface I @custom { id: ID } type Query { i: I }"
        ),
        INVALID
        + '[<unnamed>] Directive "@custom" may not be used on INPUT_OBJECT.'
        '\n\n[<unnamed>] Directive "@custom" may not be used on INTERFACE.',
    )
    assert_equal(
        build_error(
            "interface I { id: ID } type T implements I { x: Int } type Query {"
            " t: T }"
        ),
        "[<unnamed>] Interface field I.id expected but T does not provide it.",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
