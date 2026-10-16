# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_validation.context`, ported from graphql-js 16.14.2
`src/validation/__tests__/ValidationContext-test.ts`, and tests beyond
upstream.

The one upstream case, `can be Object.toStringified`, checks a JavaScript
string tag, which Mojo has not, so it is not ported. The other tests check
the methods of `ValidationContext` against the output of graphql-js 16.14.2
for the same document, and the error limit.
"""

from _harness import (
    TEST_SCHEMA,
    format_errors,
    parse_query,
    schema_of,
    test_schema,
)
from gql_language.ast import Document, Role
from gql_language.parser import parse
from gql_language.source import Source, SourceLocation
from gql_language.error import print_source_location
from gql_schema.definition import NO_TYPE, Schema, TypeRef
from gql_validation.context import ValidationContext, VariableUsage
from gql_validation.rules import ValidationRule, specified_rules
from gql_validation.type_info import has_default_value, is_defined
from gql_validation.validate import ValidationOptions, validate
from std.testing import TestSuite, assert_equal, assert_true

comptime DOCUMENT = """query Q($a: ID, $b: Boolean = true) @onQuery(arg: $q) {
  dog { ...A name(surname: $b) }
  ... on QueryRoot { cat { ...B } }
  human(id: $a) { pets { ...C } }
  complicatedArgs {
    complexArgField(complexArg: { requiredField: $r, stringListField: [$s, "x"], intField: $i })
  }
}
fragment A on Dog { ...B barkVolume ... { ...D } }
fragment B on Cat { meows ...A ...Missing }
fragment C on Pet { name }
fragment D on Dog { isAtLocation(x: $x, y: 1) isHouseTrained(atOtherHomes: $h) }
fragment A on Dog { nickname ...D }
{ dog { ...D } }
"""


def _at(document: Document, node: Int) -> String:
    var location = document.location(node)
    return String(location.line) + ":" + String(location.column)


def _type(schema: Schema, type: TypeRef) -> String:
    if not is_defined(type):
        return String("undefined")
    return schema.type_name(type)


def _usages(
    schema: Schema, document: Document, usages: List[VariableUsage]
) raises -> String:
    var out = String("")
    for ref usage in usages:
        out += (
            " "
            + String(document.name(usage.node))
            + "@"
            + _at(document, usage.node)
            + ":"
            + _type(schema, usage.type)
            + ":"
            + _type(schema, usage.parent_type)
            + ":"
            + (
                "true" if has_default_value(
                    schema, usage.default_value
                ) else "false"
            )
        )
    return out^


def _nodes(document: Document, nodes: List[Int]) -> String:
    var out = String("")
    for node in nodes:
        out += " " + String(document.name(node)) + "@" + _at(document, node)
    return out^


def test_fragments_spreads_and_variable_usages() raises:
    var schema = schema_of(
        String(TEST_SCHEMA) + "directive @onQuery(arg: Int) on QUERY"
    )
    var document = parse_query(DOCUMENT)
    var context = ValidationContext(schema)
    var definitions = document.definitions()
    var query = definitions[0]
    var last = definitions[len(definitions) - 1]
    var selection_set = document.child(query, Role.SELECTION_SET)
    assert_equal(
        _nodes(document, context.get_fragment_spreads(document, selection_set)),
        " C@4:26 B@3:28 A@2:9",
    )
    assert_equal(
        _usages(
            schema,
            document,
            context.get_variable_usages(schema, document, query),
        ),
        (
            " q@1:51:Int:undefined:false b@2:28:Boolean:undefined:false"
            " a@4:13:ID:undefined:false r@6:50:Boolean!:ComplexInput:false"
            " s@6:72:String:[String]:false i@6:92:Int:ComplexInput:false"
        ),
    )
    assert_equal(
        _nodes(
            document,
            context.get_recursively_referenced_fragments(document, query),
        ),
        " C@11:1 B@10:1 A@13:1 D@12:1",
    )
    var recursive = context.get_recursive_variable_usages(
        schema, document, query
    )
    var names = String("")
    for ref usage in recursive:
        names += " " + String(document.name(usage.node))
    assert_equal(names, " q b a r s i x h")
    assert_equal(
        _usages(
            schema,
            document,
            context.get_variable_usages(schema, document, definitions[4]),
        ),
        " x@12:37:Int:undefined:false h@12:76:Boolean:undefined:true",
    )
    assert_equal(
        _nodes(
            document,
            context.get_recursively_referenced_fragments(document, last),
        ),
        " D@12:1",
    )
    var fragment_c = definitions[3]
    assert_equal(
        len(
            context.get_fragment_spreads(
                document, document.child(fragment_c, Role.SELECTION_SET)
            )
        ),
        0,
    )
    var plain = parse_query("{ dog { name } }")
    var fresh = ValidationContext(schema)
    assert_equal(
        len(
            fresh.get_recursively_referenced_fragments(
                plain, plain.first_child(plain.root)
            )
        ),
        0,
    )
    assert_equal(_at(document, context.get_fragment(document, "A")), "13:1")
    assert_equal(context.get_fragment(document, "Missing"), -1)


def _limited(
    query: String, rules: List[ValidationRule], max_errors: Int
) raises -> String:
    var options = ValidationOptions()
    options.max_errors = max_errors
    return format_errors(
        validate(test_schema(), parse_query(query), rules, options)
    )


def test_a_rule_that_reports_after_the_limit() raises:
    # UniqueArgumentNames reports three groups in one call.
    assert_equal(
        _limited(
            "{ dog { isAtLocation(x: 1, x: 2, y: 1, y: 2, z: 1, z: 2) } }",
            [ValidationRule.UNIQUE_ARGUMENT_NAMES],
            1,
        ),
        (
            'There can be only one argument named "x". (1:22, 1:28)\nToo many'
            " validation errors, error limit reached. Validation aborted. ()"
        ),
    )


def test_a_coercion_error_at_the_limit() raises:
    assert_equal(
        _limited(
            "{ dog { isAtLocation(x: true) } }",
            [ValidationRule.VALUES_OF_CORRECT_TYPE],
            0,
        ),
        (
            "Too many validation errors, error limit reached. Validation"
            " aborted. ()"
        ),
    )


def test_an_exit_handler_at_the_limit() raises:
    assert_equal(
        _limited(
            "{ complicatedArgs { multipleReqs } dog { name } }",
            [ValidationRule.PROVIDED_REQUIRED_ARGUMENTS],
            0,
        ),
        (
            "Too many validation errors, error limit reached. Validation"
            " aborted. ()"
        ),
    )


def test_an_error_at_the_first_byte() raises:
    assert_equal(
        _limited("{a} {b}", [ValidationRule.LONE_ANONYMOUS_OPERATION], 100),
        (
            "This anonymous operation must be the only defined operation."
            " (1:1)\nThis anonymous operation must be the only defined"
            " operation. (1:5)"
        ),
    )


def test_no_rules() raises:
    var rules = List[ValidationRule]()
    assert_equal(_limited("{ unknown }", rules, 100), "")


def _expect_same_excerpt(document: Document) raises:
    var errors = validate(test_schema(), document)
    assert_true(len(errors) > 0)
    for ref error in errors:
        var want = error.message
        for location in error.locations:
            want += "\n\n" + print_source_location(document.source, location)
        assert_equal(String(error), want)


def test_excerpts_of_carriage_return_lines() raises:
    var text = "# " + "x" * 5000 + "\r{\r  dog { name }\r  unknown\r}\r"
    _expect_same_excerpt(parse_query(text))


def test_excerpts_with_a_location_offset() raises:
    var text = "{" + " " * 5000 + "unknown }"
    _expect_same_excerpt(
        parse(Source(text, "request.graphql", SourceLocation(3, 7)))
    )
    var lines = "{\n" + "  dog { name }\n" * 300 + "  unknown\n}"
    _expect_same_excerpt(
        parse(Source(lines, "request.graphql", SourceLocation(3, 7)))
    )


def test_rules_that_skip_a_subtree_and_rules_that_do_not() raises:
    # ValuesOfCorrectType skips the list; UniqueInputFieldNames does not.
    assert_equal(
        _limited(
            "{ complicatedArgs { intArgField(intArg: [{a: 1, a: 2}]) } }",
            [
                ValidationRule.VALUES_OF_CORRECT_TYPE,
                ValidationRule.UNIQUE_INPUT_FIELD_NAMES,
            ],
            100,
        ),
        (
            "Int cannot represent non-integer value: [{a: 1, a: 2}] (1:41)\n"
            'There can be only one input field named "a". (1:43, 1:49)'
        ),
    )
    # MaxIntrospectionDepth skips the field; ProvidedRequiredArguments
    # still leaves each field inside it.
    assert_equal(
        _limited(
            (
                "{ __schema { types { fields { type { fields { type { fields {"
                " name } } } } } } } }"
            ),
            [
                ValidationRule.MAX_INTROSPECTION_DEPTH,
                ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
            ],
            100,
        ),
        "Maximum introspection depth exceeded (1:3)",
    )


def test_definitions_of_the_document() raises:
    # A type defined twice, and a directive that the document defines.
    assert_equal(
        _limited(
            (
                "{ dog @local @include(if: true) } scalar Local scalar Local"
                " directive @local on FIELD"
            ),
            [ValidationRule.KNOWN_DIRECTIVES, ValidationRule.KNOWN_TYPE_NAMES],
            100,
        ),
        "",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
