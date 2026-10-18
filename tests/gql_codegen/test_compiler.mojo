# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The compilation: documents, issues, warnings and options.

These tests check the steps of Apollo Kotlin `ApolloCompiler.kt`
`buildIrOperations`: the documents compile in the order of their names,
a parse error stops the compilation, the Apollo checks report issues,
`UnusedVariable`, `UnusedFragment` and `DeprecatedUsage` are warnings, and
`failOnWarnings` makes them errors. They also check the issue and option
types.
"""

from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from gql_language.ast import Document
from gql_language.error import GraphQLError

from gql_codegen.checks import (
    check_anonymous_operations,
    check_capitalized_fields,
    check_inline_fragments_have_type_condition,
)
from gql_schema.definition import Schema

from gql_codegen.compiler import (
    CodegenDocument,
    _issue_of,
    _kind_of,
    _Lines,
    _relocate,
    build_codegen_schema,
    compile,
)
from gql_codegen.issues import Issue, IssueKind, Severity, serialize
from gql_codegen.options import AddTypename, CodegenModels, CodegenOptions

comptime SDL = """
type Query {
  hero: Hero
  old: String @deprecated(reason: "Gone")
}
type Hero { name: String age: Int Friend: Hero }
"""


def schema() raises -> Schema:
    """Build the test schema."""
    return build_codegen_schema(SDL)


def one(
    text: String, options: CodegenOptions = CodegenOptions()
) raises -> String:
    """Compile one document and serialize its errors, then its warnings."""
    var documents = List[CodegenDocument]()
    documents.append(CodegenDocument("a.graphql", text))
    var result = compile(schema(), documents, options)
    return serialize(result.errors) + "\n==\n" + serialize(result.warnings)


def test_documents_compile_in_name_order() raises:
    var documents = List[CodegenDocument]()
    documents.append(CodegenDocument("c.graphql", "query C { hero { name } }"))
    documents.append(CodegenDocument("a.graphql", "query A { hero { name } }"))
    documents.append(CodegenDocument("b.graphql", "query B {\n  nope\n}"))
    var result = compile(schema(), documents)
    # The error is on line 2 of b.graphql, which is line 3 of the joined
    # text.
    assert_equal(len(result.errors), 1)
    assert_equal(result.errors[0].file, "b.graphql")
    assert_equal(result.errors[0].line, 2)
    assert_equal(result.errors[0].column, 3)
    _ = documents.pop()
    var good = compile(schema(), documents)
    assert_true(good.succeeded())
    var names = good.operation_names()
    assert_equal(names[0], "AQuery")
    assert_equal(names[1], "CQuery")
    assert_equal(len(good.operation_ids()), 2)


def test_parse_errors() raises:
    var documents = List[CodegenDocument]()
    documents.append(CodegenDocument("a.graphql", "query A { hero { name } }"))
    documents.append(CodegenDocument("b.graphql", "query B {"))
    documents.append(CodegenDocument("c.graphql", ""))
    var result = compile(schema(), documents)
    assert_equal(len(result.errors), 2)
    assert_equal(result.errors[0].kind, IssueKind.PARSING_ERROR)
    assert_equal(result.errors[0].file, "b.graphql")
    assert_equal(result.errors[1].file, "c.graphql")
    # One document is parsed once, in the joined text.
    assert_true(one("query A {").startswith("ParsingError (1:10)"))
    # No document at all makes a module without operations, as upstream.
    var none = compile(schema(), List[CodegenDocument]())
    assert_true(none.succeeded())
    assert_true("def _member(" in none.source)
    assert_equal(len(none.operation_ids()), 0)
    assert_equal(len(none.operation_names()), 0)


def test_apollo_checks() raises:
    assert_equal(
        one("{ hero { name } }"),
        (
            "AnonymousOperation (1:1)\nApollo does not support anonymous"
            " operations\n==\n"
        ),
    )
    assert_equal(
        one("query A { hero { ... { name } } }"),
        (
            "InlineFragmentWithoutTypeCondition (1:18)\nInline fragments"
            " without a type condition are not supported. Add the parent type"
            " to inline fragment.\n==\n"
        ),
    )
    assert_equal(
        one(
            "query A { hero { ...F } } fragment F on Hero { Name: Friend {"
            " name } }"
        ),
        (
            "UpperCaseField (1:48)\nCapitalized alias 'Name' is not supported"
            " as it causes name clashes with the generated models. Use 'name'"
            " instead.\n==\n"
        ),
    )
    # The flat models only clash in fragments; decapitalized fields never.
    var options = CodegenOptions()
    options.flatten_models = False
    assert_true(
        one("query A { hero { Friend { name } } }", options).startswith(
            "UpperCaseField (1:18)\nCapitalized field 'Friend'"
        )
    )
    options.decapitalize_fields = True
    assert_equal(one("query A { hero { Friend { name } } }", options), "\n==\n")


def test_warnings() raises:
    assert_equal(
        one("query A($x: Int) { old } fragment F on Hero { name }"),
        (
            "\n==\nDeprecatedUsage (1:20)\nThe field Query.old is deprecated."
            ' Gone\n------------\nUnusedVariable (1:9)\nVariable "$x" is never'
            ' used in operation "A".\n------------\nUnusedFragment (1:26)\n'
            'Fragment "F" is never used.'
        ),
    )
    var options = CodegenOptions()
    options.fail_on_warnings = True
    assert_true(
        one("query A { old }", options).startswith("DeprecatedUsage (1:11)")
    )


def test_cycles_and_other_issues() raises:
    assert_true(
        one(
            "query A { hero { ...F } } fragment F on Hero { Friend { ...F } }"
        ).startswith("FragmentCycle")
    )
    assert_equal(
        _kind_of('Cannot spread fragment "F" within itself.'),
        IssueKind.FRAGMENT_CYCLE,
    )
    assert_equal(_kind_of("Unknown type."), IssueKind.OTHER_VALIDATION_ISSUE)
    var issue = _issue_of(
        GraphQLError("no place"), IssueKind.OTHER_VALIDATION_ISSUE
    )
    assert_equal(issue.line, 0)
    var lines = _Lines()
    lines.names.append("first.graphql")
    lines.starts.append(1)
    var placed = _relocate(issue^, lines)
    assert_equal(placed.file, "first.graphql")
    assert_equal(placed.line, 0)


def test_checks_of_edge_documents() raises:
    var empty = Document()
    assert_equal(len(check_anonymous_operations(empty)), 0)
    assert_equal(len(check_inline_fragments_have_type_condition(empty)), 0)
    assert_equal(len(check_capitalized_fields(empty, False)), 0)
    # A small alias is fine, in a fragment too.
    assert_equal(
        one(
            "query A { hero { ...F } } fragment F on Hero { f: Friend { name }"
            " }"
        ),
        "\n==\n",
    )
    # `failOnWarnings` with no warning.
    var options = CodegenOptions()
    options.fail_on_warnings = True
    assert_equal(one("query A { hero { name } }", options), "\n==\n")


def test_invalid_options() raises:
    var options = CodegenOptions()
    options.add_typename = AddTypename(9)
    with assert_raises(contains="Unknown addTypename option: <invalid>"):
        _ = one("query A { old }", options)
    options = CodegenOptions()
    options.codegen_models = CodegenModels(3)
    with assert_raises(contains="codegenModels is not supported"):
        _ = one("query A { old }", options)


def test_schema() raises:
    with assert_raises(contains="Interface field"):
        _ = build_codegen_schema(
            "interface I { a: String } type T implements I { b: String }"
            " type Query { t: T }"
        )
    var lenient = build_codegen_schema(
        (
            "interface I { a: String } type T implements I { b: String }"
            " type Query { t: T }"
        ),
        check=False,
    )
    assert_true(lenient.type_named("T") >= 0)


def test_options() raises:
    assert_equal(AddTypename.parse("ifFragments"), AddTypename.IF_FRAGMENTS)
    assert_equal(AddTypename.parse("ifPolymorphic"), AddTypename.IF_POLYMORPHIC)
    assert_equal(AddTypename.parse("ifAbstract"), AddTypename.IF_ABSTRACT)
    assert_equal(AddTypename.parse("always"), AddTypename.ALWAYS)
    with assert_raises(contains="Unknown addTypename option: never"):
        _ = AddTypename.parse("never")
    assert_true(AddTypename.ALWAYS.is_valid())
    assert_false(AddTypename(4).is_valid())
    assert_equal(String(AddTypename.IF_ABSTRACT), "ifAbstract")
    assert_equal(
        CodegenModels.parse("operationBased"), CodegenModels.OPERATION_BASED
    )
    with assert_raises(
        contains="codegenModels='responseBased' is not supported"
    ):
        _ = CodegenModels.parse("responseBased")
    assert_true(CodegenModels.OPERATION_BASED.is_valid())
    assert_false(CodegenModels(1).is_valid())
    assert_equal(String(CodegenModels.OPERATION_BASED), "operationBased")
    assert_equal(String(CodegenModels(1)), "<invalid>")
    var options = CodegenOptions()
    assert_true(options.generate_optional_operation_variables)
    assert_true(options.flatten_models)
    assert_false(options.decapitalize_fields)


def test_issues() raises:
    var names: List[String] = [
        "ParsingError",
        "OtherValidationIssue",
        "UnusedVariable",
        "UnusedFragment",
        "DeprecatedUsage",
        "AnonymousOperation",
        "UpperCaseField",
        "InlineFragmentWithoutTypeCondition",
        "FragmentCycle",
    ]
    for index in range(len(names)):
        var kind = IssueKind(UInt8(index))
        assert_true(kind.is_valid())
        assert_equal(String(kind), names[index])
    assert_false(IssueKind(9).is_valid())
    assert_equal(String(IssueKind(9)), "<invalid>")
    assert_equal(IssueKind.UNUSED_VARIABLE.default_severity(), Severity.WARNING)
    assert_equal(IssueKind.PARSING_ERROR.default_severity(), Severity.ERROR)
    assert_true(Severity.WARNING.is_valid())
    assert_false(Severity(2).is_valid())
    assert_equal(String(Severity.ERROR), "error")
    assert_equal(String(Severity.WARNING), "warning")
    assert_equal(String(Severity(2)), "<invalid>")
    var issue = Issue(IssueKind.UPPER_CASE_FIELD, "m", "f", 2, 3)
    assert_equal(String(issue), "UpperCaseField (2:3)\nm")
    assert_equal(serialize(List[Issue]()), "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
