# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Extra tests of `gql_normalization.uploads`. They are not from upstream.

`test_variables_normalizer.mojo` ports `upload_finder_test.go`. These tests
reach the other branches of the finder. Their outputs are the outputs of
the upstream finder, unless a test says otherwise.

As the `testVisitor` of upstream, `find` calls the finder for each argument
of a top-level field, and does not reset it. Each mapping prints as
`<variable> <original path> <new path>`.
"""

from _norm import schema_of
from gql_language.ast import Kind, NO_NODE, Role
from gql_language.parser import parse
from gql_normalization.go_printer import print_compact
from gql_normalization.normalize import VariablesNormalizer
from gql_normalization.schema_lookup import field_definition, root_type
from gql_normalization.uploads import UploadFinder
from std.testing import TestSuite, assert_equal


def find(
    sdl: StringSlice, operation: StringSlice, variables: StringSlice
) raises -> String:
    """Find the uploads of the arguments of the top-level fields: upstream
    `runTest`.

    Args:
        sdl: The schema.
        operation: The operation.
        variables: The variables JSON.

    Returns:
        The mappings, one per line.

    Raises:
        Error: If the inputs do not parse.
    """
    var schema = schema_of(sdl)
    var document = parse(operation)
    var finder = UploadFinder()
    var out = String()
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        var enclosing = schema.type_named(
            document.name(document.child(definition, Role.TYPE_CONDITION))
        ) if document.kind(
            definition
        ) == Kind.FRAGMENT_DEFINITION else root_type(
            schema, document, definition
        )
        var field = document.first_child(
            document.child(definition, Role.SELECTION_SET)
        )
        while field != NO_NODE:
            var field_def = field_definition(schema, document, enclosing, field)
            var argument = document.child(field, Role.ARGUMENT)
            while argument != NO_NODE:
                var input = schema.argument_named(
                    field_def, document.name(argument)
                )
                var mapping = finder.find_uploads(
                    document,
                    schema,
                    variables,
                    argument,
                    schema.input_values[input].type,
                )
                for item in mapping:
                    out += String(item) + "\n"
                argument = document.next_with_role(argument)
            field = document.next_sibling(field)
        definition = document.next_sibling(definition)
    return out^


comptime EXTRA_SCHEMA = """
scalar Upload
enum E { A }
input In { f: Upload l: [Upload] }
type Query {
  up(arg: Upload): String
  ups(arg: [Upload]): String
  obj(arg: In): String
  str(arg: String): String
  en(arg: E): String
}"""
"""The schema of the extra tests."""


def test_extra_upload_is_not_a_scalar() raises:
    assert_equal(
        find(
            "type Upload { a: Int } type Query { hello(arg: String): String }",
            '{ hello(arg: "x") }',
            "{}",
        ),
        "",
    )


def test_extra_empty_and_null_variables() raises:
    var operation = "query ($a: Upload) { up(arg: $a) }"
    assert_equal(find(EXTRA_SCHEMA, operation, ""), "")
    assert_equal(find(EXTRA_SCHEMA, operation, "null"), "")


def test_extra_inline_values() raises:
    assert_equal(
        find(
            EXTRA_SCHEMA,
            "query ($a: Upload, $b: Upload) { ups(arg: [$a, $b]) }",
            '{"a": null, "b": 1}',
        ),
        "a variables.a 0\n",
    )
    assert_equal(
        find(EXTRA_SCHEMA, "{ obj(arg: {f: null, g: 1}) }", "{}"), "  f\n"
    )
    assert_equal(
        find(EXTRA_SCHEMA, "query ($s: String) { str(arg: {a: 1}) }", "{}"),
        "",
    )
    assert_equal(find(EXTRA_SCHEMA, '{ str(arg: "x") }', "{}"), "")
    assert_equal(find(EXTRA_SCHEMA, "{ str(arg: null) }", "{}"), "")


def test_extra_variable_definitions() raises:
    assert_equal(
        find(
            EXTRA_SCHEMA,
            "fragment F on Query { str } query ($a: Upload) { up(arg: $a) }",
            '{"a": null}',
        ),
        "a variables.a \n",
    )
    assert_equal(find(EXTRA_SCHEMA, "{ up(arg: $a) }", '{"a": null}'), "")
    assert_equal(
        find(EXTRA_SCHEMA, "query ($a: String) { up(arg: $a) }", '{"a": null}'),
        "",
    )
    # Not checked against upstream: without an operation, upstream reads
    # the operation at index 0, which does not exist.
    assert_equal(
        find(
            EXTRA_SCHEMA, "fragment F on Query { up(arg: $a) }", '{"a": null}'
        ),
        "",
    )


def test_extra_variable_values() raises:
    var lists = "query ($l: [Upload]) { ups(arg: $l) }"
    assert_equal(find(EXTRA_SCHEMA, lists, '{"l": 5}'), "")
    assert_equal(
        find(EXTRA_SCHEMA, lists, '{"l": [null, 2]}'), "l variables.l.0 \n"
    )
    var objects = "query ($i: In) { obj(arg: $i) }"
    assert_equal(find(EXTRA_SCHEMA, objects, '{"i": 5}'), "")
    assert_equal(find(EXTRA_SCHEMA, objects, '{"i": {}}'), "")
    assert_equal(find(EXTRA_SCHEMA, objects, '{"i": {"l": 3}}'), "")
    assert_equal(
        find(EXTRA_SCHEMA, objects, '{"i": {"l": [null], "f": "x"}}'),
        "i variables.i.l.0 \n",
    )
    assert_equal(
        find(EXTRA_SCHEMA, "query ($e: E) { en(arg: $e) }", '{"e": "A"}'), ""
    )
    assert_equal(
        find(
            EXTRA_SCHEMA, "query ($s: String) { str(arg: $s) }", '{"s": null}'
        ),
        "",
    )


def test_extra_extracted_null_upload() raises:
    # A literal `null` upload has no path in the argument, so the
    # extraction keeps its empty paths.
    var schema = schema_of(EXTRA_SCHEMA)
    var document = parse("{ up(arg: null) }")
    var variables = String("{}")
    var uploads = VariablesNormalizer().normalize_operation(
        document, schema, variables
    )
    assert_equal(print_compact(document), "query($a: Upload){up(arg: $a)}")
    assert_equal(variables, '{"a":null}')
    assert_equal(len(uploads), 1)
    assert_equal(String(uploads[0]), "  ")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
