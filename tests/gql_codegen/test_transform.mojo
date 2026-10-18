# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `__typename` transform, in each `addTypename` mode.

Apollo Kotlin has no unit test of `ApolloExecutableDocumentTransform`: the
`ifFragments` default shows in the documents of `CodegenTest.kt`, which
`test_operation_ids.mojo` checks. These tests check the other modes, and
the documents that validation refuses, with the rules of upstream
`addRequiredFields`.
"""

from std.testing import TestSuite, assert_equal

from gql_language.ast import Document, NO_NODE, Role
from gql_language.parser import parse
from gql_schema.definition import Schema

from gql_codegen.compiler import build_codegen_schema
from gql_codegen.options import AddTypename
from gql_codegen.printer import print_executable
from gql_codegen.strings import minify
from gql_codegen.transform import add_required_fields

comptime SDL = """
interface Animal { name: String mother: Animal }
interface Lonely { name: String }
type Dog implements Animal { name: String mother: Animal barks: Boolean }
type Cat implements Animal { name: String mother: Animal }
union Pet = Dog | Cat
type Query { animal: Animal dog: Dog pet: Pet name: String }
"""


def schema() raises -> Schema:
    """Build the test schema."""
    return build_codegen_schema(SDL)


def transformed(text: String, mode: AddTypename) raises -> String:
    """Transform a document and print each definition, minified, one per
    line."""
    var document = parse(text)
    add_required_fields(document, schema(), mode)
    var out = List[String]()
    for definition in document.definitions():
        out.append(minify(print_executable(document, definition)))
    return "\n".join(out)


def test_if_fragments() raises:
    # Every `__typename` goes, with its alias and its directives, and one
    # comes first.
    assert_equal(
        transformed(
            (
                "{ dog { name t: __typename __typename @include(if: true) ..."
                " on Dog { barks } } }"
            ),
            AddTypename.IF_FRAGMENTS,
        ),
        "query { dog { __typename name ... on Dog { barks } } } ",
    )
    # The selection set of the operation is not a root, but `ifFragments`
    # looks at every selection set.
    assert_equal(
        transformed("{ ... on Query { name } }", AddTypename.IF_FRAGMENTS),
        "query { __typename ... on Query { name } } ",
    )
    # A selection set with only `__typename` keeps one.
    assert_equal(
        transformed(
            "{ dog { __typename ...F } } fragment F on Dog { name }",
            AddTypename.IF_FRAGMENTS,
        ),
        "query { dog { __typename ...F } } \nfragment F on Dog { name } ",
    )


def test_if_polymorphic() raises:
    var mode = AddTypename.IF_POLYMORPHIC
    assert_equal(
        transformed("{ animal { ... on Dog { barks } } }", mode),
        "query { animal { __typename ... on Dog { barks } } } ",
    )
    # A fragment on a super type matches every value.
    assert_equal(
        transformed("{ dog { ... on Animal { name } } }", mode),
        "query { dog { ... on Animal { name } } } ",
    )
    assert_equal(
        transformed("{ dog { ... on Animal { ... on Cat { name } } } }", mode),
        "query { dog { __typename ... on Animal { ... on Cat { name } } } } ",
    )
    assert_equal(
        transformed(
            (
                "{ dog { ...A } animal { ...D } } fragment A on Animal { name }"
                " fragment D on Dog { barks }"
            ),
            mode,
        ),
        (
            "query { dog { ...A } animal { __typename ...D } } \nfragment A on"
            " Animal { name } \nfragment D on Dog { barks } "
        ),
    )
    assert_equal(
        transformed(
            "{ dog { ...W } } fragment W on Animal { ... on Cat { name } }",
            mode,
        ),
        (
            "query { dog { __typename ...W } } \nfragment W on Animal {"
            " __typename ... on Cat { name } } "
        ),
    )
    # A fragment cycle, an unknown fragment and unknown types end the walk;
    # validation reports them.
    assert_equal(
        transformed(
            (
                "{ dog { ...C ...Missing ... on Nope { name } ...U } } fragment"
                " C on Animal { ...C } fragment U on Nope { name }"
            ),
            mode,
        ),
        (
            "query { dog { ...C ...Missing ... on Nope { name } ...U } }"
            " \nfragment C on Animal { ...C } \nfragment U on Nope { name } "
        ),
    )
    # The operation's own selection set is not a root.
    assert_equal(
        transformed("{ ... on Dog { name } }", mode),
        "query { ... on Dog { name } } ",
    )


def test_edges() raises:
    # A spread without any fragment definition.
    assert_equal(
        transformed("{ animal { ...Missing } }", AddTypename.IF_POLYMORPHIC),
        "query { animal { ...Missing } } ",
    )
    # A selection set of only `__typename` gets a new one.
    assert_equal(
        transformed("{ dog { __typename } }", AddTypename.ALWAYS),
        "query { dog { __typename } } ",
    )


def test_if_abstract() raises:
    var mode = AddTypename.IF_ABSTRACT
    assert_equal(
        transformed(
            "{ animal { name } dog { name } pet { ... on Dog { barks } } }",
            mode,
        ),
        (
            "query { animal { __typename name } dog { name } pet { __typename"
            " ... on Dog { barks } } } "
        ),
    )


def test_always() raises:
    var mode = AddTypename.ALWAYS
    assert_equal(
        transformed(
            (
                "{ dog { mother { name } } } fragment F on Dog { name }"
                " fragment G on Nope { name }"
            ),
            mode,
        ),
        (
            "query { dog { __typename mother { __typename name } } }"
            " \nfragment F on Dog { __typename name } \nfragment G on Nope {"
            " name } "
        ),
    )
    # An unknown field and a field of an unknown type are left alone.
    assert_equal(
        transformed("{ nope { name } name { x } }", mode),
        "query { nope { name } name { __typename x } } ",
    )
    # An operation type without a root type is left alone.
    assert_equal(
        transformed("mutation { dog { name } }", mode),
        "mutation { dog { name } } ",
    )


def test_empty_documents() raises:
    var empty = Document()
    add_required_fields(empty, schema(), AddTypename.ALWAYS)
    assert_equal(len(empty.definitions()), 0)
    # An empty selection set stays empty, as upstream.
    var document = parse("{ dog { name } }")
    var operation = document.definitions()[0]
    var root = document.child(operation, Role.SELECTION_SET)
    var dog = document.first_child(root)
    var selection_set = document.child(dog, Role.SELECTION_SET)
    document.nodes[selection_set].first = NO_NODE
    document.nodes[selection_set].last = NO_NODE
    add_required_fields(document, schema(), AddTypename.ALWAYS)
    assert_equal(
        minify(print_executable(document, operation)), "query { dog { } } "
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
