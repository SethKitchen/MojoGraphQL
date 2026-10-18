# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the errors of `build_subgraph_schema`.

`@apollo/subgraph` 2.14.4 has no tests of these messages beyond `fails on
bad linking`. The expected messages come from `@apollo/subgraph` 2.14.4
itself, run in Node.js with the same SDL, without the source excerpts.
`v2.15` is the exception: 2.14.4 rejects it, and this port accepts it.
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
        build_error(
            LINK + 'v2.0") type Query { a: Int } type Query { b: Int }'
        ),
        'There can be only one type named "Query"',
    )


def test_versions_that_are_not_supported() raises:
    assert_equal(
        build_error(LINK + 'v2.16") type Query { a: Int }'),
        INVALID
        + "Invalid version v2.16 for the federation feature in @link directive"
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
        " either strings or input object values of the form { name:"
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
        " the @link to the federation specification.\n\nUnknown directive"
        ' "@federation__key".',
    )
    assert_equal(
        build_error(
            LINK
            + 'v2.0", import: ["@key"]) type Query { a: Int @federation__foo }'
        ),
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


def _import_error(imports: String) raises -> String:
    return build_error(
        LINK + 'v2.0", import: [' + imports + "]) type Query { a: Int }"
    )


def test_invalid_import_object_fields() raises:
    assert_equal(
        _import_error('{ name: "@key", as: 5 }'),
        INVALID
        + 'Invalid value for the "as" field for sub-value {name: "@key", as:'
        " 5} of @link(import:) argument: must be a string.",
    )
    assert_equal(
        _import_error("{ name: 5, as: 6 }"),
        INVALID
        + 'Invalid value for the "name" field for sub-value {name: 5, as: 6}'
        " of @link(import:) argument: must be a string.",
    )
    assert_equal(
        _import_error("{ as: 5 }"),
        INVALID
        + 'Invalid value for the "as" field for sub-value {as: 5} of'
        " @link(import:) argument: must be a string.",
    )
    assert_equal(
        _import_error('{ as: "@k" }'),
        INVALID
        + 'Invalid sub-value {as: "@k"} for @link(import:) argument: missing'
        ' mandatory "name" field.',
    )
    assert_equal(
        _import_error('{ name: "@key", other: 1 }'),
        INVALID
        + 'Unknown field "other" for sub-value {name: "@key", other: 1} of'
        " @link(import:) argument.",
    )
    assert_equal(
        _import_error("{ other: 1, name: 5 }"),
        INVALID
        + 'Unknown field "other" for sub-value {other: 1, name: 5} of'
        " @link(import:) argument.",
    )
    assert_equal(
        _import_error('{ name: "@key", as: 5 }, { name: 6 }, "@nope"'),
        INVALID
        + 'Invalid value for the "as" field for sub-value {name: "@key", as:'
        " 5} of @link(import:) argument: must be a string.\n\nInvalid value"
        ' for the "name" field for sub-value {name: 6} of @link(import:)'
        " argument: must be a string.\n\nCannot import unknown element"
        ' "@nope".',
    )


def test_invalid_import_renaming() raises:
    assert_equal(
        _import_error('{ name: "@key", as: "k" }'),
        INVALID
        + 'Invalid @link import renaming: directive "@key" imported name'
        " should start with a '@' character, but got \"k\".",
    )
    assert_equal(
        _import_error('{ name: "FieldSet", as: "@FS" }'),
        INVALID
        + 'Invalid @link import renaming: type "FieldSet" imported name should'
        " not start with a '@' character, but got \"@FS\" (or, if @FieldSet"
        " is a directive, then it should be referred to with a '@').",
    )
    assert_equal(
        _import_error('{ name: "@nope", as: "x" }'),
        INVALID
        + 'Invalid @link import renaming: directive "@nope" imported name'
        " should start with a '@' character, but got \"x\".\n\nCannot import"
        ' unknown element "@nope".',
    )
    assert_equal(
        _import_error('{ name: "Nope", as: "@N" }'),
        INVALID
        + 'Invalid @link import renaming: type "Nope" imported name should'
        " not start with a '@' character, but got \"@N\" (or, if @Nope is a"
        " directive, then it should be referred to with a '@').\n\nCannot"
        ' import unknown element "Nope".',
    )


comptime LINK_SPEC = '@link(url: "https://specs.apollo.dev/link/v1.0")'
comptime FED = '@link(url: "https://specs.apollo.dev/federation/'
comptime ALREADY_LINKED = (
    'Cannot link feature "https://specs.apollo.dev/federation" since it has'
    " already been linked in the schema."
)


def test_duplicate_links() raises:
    assert_equal(
        build_error(
            "extend schema "
            + LINK_SPEC
            + " "
            + LINK_SPEC
            + " type Query { a: Int }"
        ),
        INVALID + "Invalid duplicate application of @core/@link",
    )
    assert_equal(
        build_error(
            "extend schema "
            + LINK_SPEC
            + " "
            + LINK_SPEC
            + " "
            + FED
            + 'v2.0") '
            + LINK_SPEC
            + " type Query { a: Int @foo }"
        ),
        INVALID
        + "Invalid duplicate application of @core/@link\n\nInvalid duplicate"
        ' application of @core/@link\n\nUnknown directive "@foo".',
    )
    assert_equal(
        build_error(
            "extend schema "
            + FED
            + 'v2.0") '
            + FED
            + 'v2.0") type Query { a: Int }'
        ),
        ALREADY_LINKED,
    )
    assert_equal(
        build_error(
            "extend schema "
            + FED
            + 'v2.0") '
            + FED
            + 'v2.99") type Query { a: Int }'
        ),
        ALREADY_LINKED,
    )
    assert_equal(
        build_error(
            "extend schema "
            + FED
            + 'v2.3") '
            + FED
            + 'v2.x") type Query { a: Int }'
        ),
        "Expected a version string (of the form v1.2), got v2.x",
    )


def test_malformed_versions() raises:
    assert_equal(
        build_error(LINK + 'v2") type Query { a: Int }'),
        "Expected a version string (of the form v1.2), got v2",
    )
    assert_equal(
        build_error(LINK + 'v2.-1") type Query { a: Int }'),
        "Expected a version string (of the form v1.2), got v2.-1",
    )


def test_executable_definitions() raises:
    comptime EXECUTABLE = (
        INVALID + "Invalid executable definition found while building schema"
    )
    assert_equal(build_error("type Query { a: Int } query Q { a }"), EXECUTABLE)
    assert_equal(
        build_error("type Query { a: Int } fragment F on Query { a }"),
        EXECUTABLE,
    )
    assert_equal(
        build_error(
            "type Query { a: Int } query Q { a } type Query { b: Int }"
        ),
        'There can be only one type named "Query"',
    )
    assert_equal(
        build_error("type Query { a: Int } query Q { a } type T { b: Nope }"),
        "Unknown type Nope",
    )


def test_duplicate_directive_definitions() raises:
    assert_equal(
        build_error(
            "directive @foo on FIELD_DEFINITION directive @foo on"
            " FIELD_DEFINITION type Query { a: Int @bar }"
        ),
        "Directive @foo already exists in this schema",
    )
    assert_equal(
        build_error(
            "directive @key(fields: _FieldSet!) on OBJECT directive"
            " @key(fields: _FieldSet!) on OBJECT scalar _FieldSet type Query {"
            " a: Int }"
        ),
        "Directive @key already exists in this schema",
    )
    assert_equal(
        build_error(
            "type Query { a: Int } type Query { b: Int } directive @foo on"
            " FIELD_DEFINITION directive @foo on FIELD_DEFINITION"
        ),
        "Directive @foo already exists in this schema",
    )


def test_a_second_schema_definition() raises:
    # Upstream accepts it; this port applies the graphql-js SDL rules.
    assert_equal(
        build_error(
            "schema { query: Query } schema { query: Query } type Query { a:"
            " Int }"
        ),
        INVALID
        + "[<unnamed>] Must provide only one schema definition.\n\n"
        "[<unnamed>] There can be only one query type in schema.",
    )


def test_link_arguments_that_are_not_strings() raises:
    # Upstream fails with a JavaScript TypeError on each of these.
    assert_equal(
        build_error("extend schema @link(url: 5) type Query { a: Int }"),
        INVALID + 'Unknown directive "@link".',
    )
    assert_equal(
        build_error(LINK + 'v2.0", as: 5) type Query { a: Int @key }'),
        INVALID
        + 'Unknown directive "@key". If you meant the "@key" federation'
        ' directive, you should use fully-qualified name "@federation__key"'
        ' or add "@key" to the `import` argument of the @link to the'
        " federation specification.",
    )
    assert_equal(
        build_error(LINK + 'v2.0", import: "@key") type Query { a: Int @key }'),
        INVALID
        + 'Unknown directive "@key". If you meant the "@key" federation'
        ' directive, you should use fully-qualified name "@federation__key"'
        ' or add "@key" to the `import` argument of the @link to the'
        " federation specification.",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
