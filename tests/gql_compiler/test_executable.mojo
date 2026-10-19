# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `ExecutableDocument` and `ExecutableDocumentBuilder`.

Ports the tests of apollo-compiler 1.33.0 (`b7eee5c`)
`tests/executable.rs` that do not need validation. The other tests check
each `BuildError` of `src/executable/from_ast.rs`, with the messages of
`src/executable/mod.rs`.
"""

from gql_language.ast import Kind, NO_NODE, OperationType
from gql_language.names import NOT_FOUND
from gql_language.parser import ParseOptions, parse
from gql_compiler.executable import (
    BuildError,
    BuildErrorKind,
    ExecutableDocument,
    ExecutableDocumentBuilder,
    MetaField,
    NO_SELECTION_SET,
    Selection,
    SelectionKind,
)
from gql_compiler.from_ast import SchemaBuilder
from gql_compiler.schema import Schema
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

comptime _SCHEMA = """
    schema { query: Query mutation: Mutation }
    type Query { user(id: ID): User node: Node search: Result
      color: Color missing: Missing name: String }
    type Mutation { rename(name: String): User }
    interface Node { id: ID! }
    type User implements Node { id: ID! name: String friends: [User!]! }
    type Bot { id: ID! }
    union Result = User | Bot
    enum Color { RED GREEN }
    input Filter { name: String }
    """
"""A schema with each kind of type, and a field of an undefined type."""


def _schema(text: StringSlice = _SCHEMA) raises -> Schema:
    var builder = SchemaBuilder()
    builder.parse(text)
    return builder^.build()


def _errors(schema: Schema, text: StringSlice) raises -> List[String]:
    var result = ExecutableDocument.parse(schema, text)
    var out = List[String]()
    for error in result[1]:
        out.append(error.message())
    return out^


def _one_error(schema: Schema, text: StringSlice) raises -> String:
    var errors = _errors(schema, text)
    assert_equal(len(errors), 1)
    return errors[0]


def test_type_system_definition() raises:
    var schema = _schema()
    var options = ParseOptions()
    options.experimental_directives_on_directive_definitions = True
    var builder = ExecutableDocumentBuilder()
    builder.add_ast(
        schema,
        parse(
            """
        query { name }
        directive @d on FIELD
        scalar S
        type T { a: Int }
        interface I { a: Int }
        union U = T
        enum E { A }
        input In { a: Int }
        schema { query: T }
        extend schema @d
        extend scalar S @d
        extend type T @d
        extend interface I @d
        extend union U @d
        extend enum E @d
        extend input In @d
        extend directive @d @d
        """,
            options,
        ),
    )
    var result = builder^.build()
    var errors = List[String]()
    for error in result[1]:
        errors.append(error.message())
    assert_equal(len(errors), 16)
    assert_equal(
        errors[0],
        "an executable document must not contain a directive definition",
    )
    assert_equal(
        errors[1],
        "an executable document must not contain a scalar type definition",
    )
    assert_equal(
        errors[2],
        "an executable document must not contain an object type definition",
    )
    assert_equal(
        errors[3],
        "an executable document must not contain an interface type definition",
    )
    assert_equal(
        errors[4],
        "an executable document must not contain a union type definition",
    )
    assert_equal(
        errors[5],
        "an executable document must not contain an enum type definition",
    )
    assert_equal(
        errors[6],
        (
            "an executable document must not contain an input object type"
            " definition"
        ),
    )
    assert_equal(
        errors[7], "an executable document must not contain a schema definition"
    )
    assert_equal(
        errors[8], "an executable document must not contain a schema extension"
    )
    assert_equal(
        errors[9],
        "an executable document must not contain a scalar type extension",
    )
    assert_equal(
        errors[10],
        "an executable document must not contain an object type extension",
    )
    assert_equal(
        errors[11],
        "an executable document must not contain an interface type extension",
    )
    assert_equal(
        errors[12],
        "an executable document must not contain a union type extension",
    )
    assert_equal(
        errors[13],
        "an executable document must not contain an enum type extension",
    )
    assert_equal(
        errors[14],
        (
            "an executable document must not contain an input object type"
            " extension"
        ),
    )
    assert_equal(
        errors[15],
        "an executable document must not contain a directive extension",
    )


def test_type_system_definitions_are_not_errors() raises:
    var schema = _schema()
    var builder = ExecutableDocumentBuilder()
    builder.add_ast(
        schema,
        parse("query { name } type T { a: Int }"),
        type_system_definitions_are_errors=False,
    )
    var result = builder^.build()
    assert_equal(len(result[1]), 0)
    assert_equal(len(result[0].operations), 1)


def test_ambiguous_anonymous_operation() raises:
    var schema = _schema()
    var message = (
        "anonymous operation cannot be selected when the document contains"
        " other operations"
    )
    var errors = _errors(schema, "{ name } { name } { name }")
    assert_equal(len(errors), 3)
    assert_equal(errors[0], message)
    errors = _errors(schema, "query A { name } { name }")
    assert_equal(len(errors), 1)
    assert_equal(errors[0], message)
    var result = ExecutableDocument.parse(schema, "{ name } query A { name }")
    assert_equal(len(result[1]), 1)
    assert_equal(result[1][0].message(), message)
    assert_equal(Int(result[1][0].node), Int(result[0].operations[0].node))
    assert_equal(len(result[0].operations), 2)


def test_operation_name_collision() raises:
    var schema = _schema()
    assert_equal(
        _one_error(schema, "query A { name } mutation A { rename { id } }"),
        "the operation `A` is defined multiple times in the document",
    )


def test_fragment_name_collision() raises:
    var schema = _schema()
    assert_equal(
        _one_error(
            schema, "fragment F on User { id } fragment F on Bot { id }"
        ),
        "the fragment `F` is defined multiple times in the document",
    )


def test_undefined_root_operation() raises:
    var schema = _schema()
    assert_equal(
        _one_error(schema, "subscription S { name }"),
        "`subscription` root operation type is not defined",
    )
    assert_equal(
        _one_error(schema, "subscription { name }"),
        "`subscription` root operation type is not defined",
    )
    var no_query = _schema("type Mutation { a: Int }")
    assert_equal(
        _one_error(no_query, "{ a }"),
        "`query` root operation type is not defined",
    )
    assert_equal(
        _one_error(_schema("type Query { a: Int }"), "mutation { a }"),
        "`mutation` root operation type is not defined",
    )
    var result = ExecutableDocument.parse(
        schema, "subscription S { name } subscription S { name }"
    )
    assert_equal(len(result[1]), 2)
    assert_equal(len(result[0].operations), 0)


def test_undefined_type_in_named_fragment_type_condition() raises:
    var schema = _schema()
    var result = ExecutableDocument.parse(
        schema, "fragment F on Nope { id } fragment F on User { id }"
    )
    assert_equal(len(result[1]), 1)
    assert_equal(
        result[1][0].message(),
        (
            "type condition `Nope` of fragment `F` is not a type defined in the"
            " schema"
        ),
    )
    assert_equal(result[1][0].kind, BuildErrorKind(5))
    assert_equal(len(result[0].fragments), 1)


def test_undefined_type_in_inline_fragment_type_condition() raises:
    var schema = _schema()
    assert_equal(
        _one_error(schema, "{ ... on Nope { id } }"),
        (
            "type condition `Nope` of inline fragment is not a type defined in"
            " the schema"
        ),
    )


def test_subselection_on_scalar_type() raises:
    var schema = _schema()
    assert_equal(
        _one_error(schema, "{ name { length } }"),
        "field selection of scalar type `String` must not have subselections",
    )
    assert_equal(
        _one_error(schema, "{ __typename { length } }"),
        "field selection of scalar type `String` must not have subselections",
    )


def test_subselection_on_enum_type() raises:
    var schema = _schema()
    assert_equal(
        _one_error(schema, "{ color { red } }"),
        "field selection of enum type `Color` must not have subselections",
    )


def test_undefined_field() raises:
    var schema = _schema()
    assert_equal(
        _one_error(schema, "{ nope }"),
        "type `Query` does not have a field `nope`",
    )
    assert_equal(
        _one_error(schema, "{ user { __schema } }"),
        "type `User` does not have a field `__schema`",
    )
    assert_equal(
        _one_error(schema, "fragment F on Color { __typename }"),
        "type `Color` does not have a field `__typename`",
    )
    assert_equal(
        _one_error(schema, "fragment F on Filter { name }"),
        "type `Filter` does not have a field `name`",
    )
    assert_equal(
        _one_error(schema, "fragment F on Result { id }"),
        "type `Result` does not have a field `id`",
    )


def _has_operation(document: ExecutableDocument, name: String) raises -> Bool:
    try:
        var operation = document.get_operation(name)
        return document.operation_name(operation) == name
    except:
        return False


def _names(document: ExecutableDocument, fields: List[Selection]) -> String:
    var out = String()
    for field in fields:
        if out:
            out += " "
        out += document.selection_name(field)
    return out^


def test_get_operations() raises:
    var schema = _schema("type Query { name: String }")
    var doc = ExecutableDocument.parse(schema, "{ name }")
    assert_equal(len(doc[1]), 0)
    _ = doc[0].get_operation(None)
    doc = ExecutableDocument.parse(schema, "query getName { name } ")
    assert_true(_has_operation(doc[0], "getName"))
    assert_equal(doc[0].operation_name(doc[0].get_operation(None)), "getName")
    doc = ExecutableDocument.parse(
        schema, "query getName { name } query getAnotherName { name }"
    )
    assert_true(_has_operation(doc[0], "getName"))
    with assert_raises(
        contains=(
            "Ambiguous request: multiple operations but no specified"
            " `operationName`"
        )
    ):
        _ = doc[0].get_operation(None)
    # The empty document is a syntax error, so this builds from no AST.
    var empty = ExecutableDocumentBuilder().build()
    with assert_raises(contains="No operation named 'getName'"):
        _ = empty[0].get_operation(String("getName"))
    with assert_raises(contains="Ambiguous request"):
        _ = empty[0].get_operation(None)


def test_is_introspection_operation() raises:
    var schema = _schema("type Query { foo: String }")
    var doc = ExecutableDocument.parse(
        schema,
        """
        query TypeIntrospect {
          __type(name: "User") { name fields { name type { name } } }
          __schema { types { fields { name } } }
        }
        """,
    )
    assert_equal(len(doc[1]), 0)
    assert_true(doc[0].is_introspection(doc[0].get_operation(None)))


def test_is_not_introspection_operation() raises:
    var schema = _schema("type Query { isKagoshimaWagyuInstock: Boolean }")
    var doc = ExecutableDocument.parse(
        schema,
        """
        query CheckStock {
          isKagoshimaWagyuInstock
          __schema { types { fields { name } } }
        }
        """,
    )
    assert_false(doc[0].is_introspection(doc[0].get_operation(None)))
    var mutation_schema = _schema(
        "type Query { unused: Int } type Mutation { buyA5Wagyu(pounds: Int):"
        " String }"
    )
    doc = ExecutableDocument.parse(
        mutation_schema, "mutation PurchaseBasket { buyA5Wagyu(pounds: 15) }"
    )
    assert_false(doc[0].is_introspection(doc[0].get_operation(None)))


def test_is_introspection_deep() raises:
    var schema = _schema(
        """
        schema { query: Root }
        type Root { species(id: String): Species }
        type Species { name: String }
        """
    )
    var query = """
      query IntrospectDeepFragments { ...onRootTrippy }
      fragment onRootTrippy on Root { ...onRooten }
      fragment onRooten on Root { ...onRooten2 ... on Root { __schema { types { name } } } }
      fragment onRooten2 on Root { ...onRooten2InLaw }
      """
    var doc = ExecutableDocument.parse(
        schema,
        String(
            query,
            (
                "fragment onRooten2InLaw on Root { __typename __type(name:"
                ' "Root") { name } }'
            ),
        ),
    )
    assert_equal(len(doc[1]), 0)
    assert_true(doc[0].is_introspection(doc[0].get_operation(None)))
    doc = ExecutableDocument.parse(
        schema,
        String(
            query,
            'fragment onRooten2InLaw on Root { species(id: "x") { name } }',
        ),
    )
    assert_false(doc[0].is_introspection(doc[0].get_operation(None)))


def test_is_introspection_repeated_fragment() raises:
    var schema = _schema("type Query { foo: String }")
    var doc = ExecutableDocument.parse(
        schema,
        """
        query IntrospectRepeatedIndirectFragment { ...A ...B }
        fragment A on Query { ...C }
        fragment B on Query { ...C }
        fragment C on Query { __schema { types { name } } }
        """,
    )
    assert_true(doc[0].is_introspection(doc[0].get_operation(None)))
    doc = ExecutableDocument.parse(
        schema,
        """
        query IntrospectRepeatedDirectFragment { ...C ...C }
        fragment C on Query { __schema { types { name } } }
        """,
    )
    assert_true(doc[0].is_introspection(doc[0].get_operation(None)))


comptime _FIELDS_SCHEMA = """
    type Query { f1: T f2: Int f3: Int }
    type T { inner: String }
    """


def test_iter_root_fields() raises:
    var schema = _schema(_FIELDS_SCHEMA)
    var doc = ExecutableDocument.parse(
        schema,
        (
            "{ f1 { inner } ... { f2 } ... F ... F ... Undefined } fragment F"
            " on Query { f3 }"
        ),
    )
    assert_equal(len(doc[1]), 0)
    var op = doc[0].get_operation(None)
    assert_equal(
        _names(doc[0], doc[0].root_fields(Int(op.selection_set))), "f1 f2 f3"
    )


def test_iter_all_fields() raises:
    var schema = _schema(_FIELDS_SCHEMA)
    var doc = ExecutableDocument.parse(
        schema,
        "{ f1 { inner } ... { f2 } ... F ... F } fragment F on Query { f3 }",
    )
    var op = doc[0].get_operation(None)
    assert_equal(
        _names(doc[0], doc[0].all_fields(Int(op.selection_set))),
        "f1 inner f2 f3",
    )


def test_builder_from_multiple_files() raises:
    var schema = _schema(
        """
        type Query { user: User post: Post }
        type User { id: ID! name: String }
        type Post { id: ID! title: String }
        """
    )
    var builder = ExecutableDocumentBuilder()
    builder.parse(schema, "query GetUser { user { id name } }")
    builder.parse(schema, "query GetPost { post { id title } }")
    var doc = builder^.build()
    assert_equal(len(doc[1]), 0)
    assert_equal(doc[0].named_operation_count(), 2)
    assert_true(_has_operation(doc[0], "GetUser"))
    assert_true(_has_operation(doc[0], "GetPost"))
    assert_false(_has_operation(doc[0], "GetNothing"))


def test_builder_with_fragments_from_multiple_files() raises:
    var schema = _schema(
        "type Query { user: User } type User { id: ID! name: String email:"
        " String }"
    )
    var builder = ExecutableDocumentBuilder()
    builder.parse(schema, "query GetUser { user { ...UserFields } }")
    builder.parse(schema, "fragment UserFields on User { id name email }")
    var doc = builder^.build()
    assert_equal(len(doc[1]), 0)
    assert_equal(doc[0].named_operation_count(), 1)
    assert_equal(len(doc[0].fragments), 1)
    assert_true(_has_operation(doc[0], "GetUser"))
    assert_true(doc[0].get_fragment("UserFields") != NOT_FOUND)
    assert_equal(doc[0].fragment_name(doc[0].fragments[0]), "UserFields")


def test_builder_detects_operation_name_collision() raises:
    var schema = _schema("type Query { field: String }")
    var builder = ExecutableDocumentBuilder()
    builder.parse(schema, "query GetData { field }")
    builder.parse(schema, "query GetData { field }")
    var doc = builder^.build()
    assert_equal(len(doc[1]), 1)
    assert_equal(
        doc[1][0].message(),
        "the operation `GetData` is defined multiple times in the document",
    )
    assert_equal(Int(doc[1][0].source), 1)


def test_builder_detects_fragment_name_collision() raises:
    var schema = _schema("type Query { user: User } type User { id: ID }")
    var builder = ExecutableDocumentBuilder()
    builder.parse(schema, "fragment UserData on User { id }")
    builder.parse(schema, "fragment UserData on User { id }")
    var doc = builder^.build()
    assert_equal(len(doc[1]), 1)
    assert_true("UserData" in doc[1][0].message())
    assert_true("multiple times" in doc[1][0].message())


def test_builder_preserves_source_information() raises:
    var schema = _schema("type Query { field: String }")
    var builder = ExecutableDocumentBuilder()
    builder.parse(schema, "query Q1 { field }")
    builder.parse(schema, "query Q2 { field }")
    var doc = builder^.build()
    assert_equal(len(doc[1]), 0)
    assert_equal(len(doc[0].sources), 2)
    assert_equal(Int(doc[0].operations[0].source), 0)
    assert_equal(Int(doc[0].operations[1].source), 1)


def test_builder_handles_anonymous_and_named_operations() raises:
    var schema = _schema("type Query { field: String }")
    var builder = ExecutableDocumentBuilder()
    builder.parse(schema, "{ field }")
    builder.parse(schema, "query GetData { field }")
    var doc = builder^.build()
    assert_equal(len(doc[1]), 1)


def test_builder_handles_multiple_anonymous_operations() raises:
    var schema = _schema("type Query { field: String }")
    var builder = ExecutableDocumentBuilder()
    builder.parse(schema, "{ field }")
    builder.parse(schema, "{ field }")
    var doc = builder^.build()
    assert_equal(len(doc[1]), 2)
    assert_equal(Int(doc[1][0].source), 0)
    assert_equal(Int(doc[1][1].source), 1)


def test_builder_with_multiple_fragments_used_in_query() raises:
    var schema = _schema(
        """
        type Query { user: User }
        type User { id: ID! profile: Profile settings: Settings }
        type Profile { name: String bio: String }
        type Settings { theme: String notifications: Boolean }
        """
    )
    var builder = ExecutableDocumentBuilder()
    builder.parse(
        schema,
        "query GetUser { user { id ...ProfileFields ...SettingsFields } }",
    )
    builder.parse(schema, "fragment ProfileFields on Profile { name bio }")
    builder.parse(
        schema, "fragment SettingsFields on Settings { theme notifications }"
    )
    var doc = builder^.build()
    assert_equal(len(doc[1]), 0)
    assert_equal(doc[0].named_operation_count(), 1)
    assert_equal(len(doc[0].fragments), 2)
    assert_true(doc[0].get_fragment("ProfileFields") != NOT_FOUND)
    assert_true(doc[0].get_fragment("SettingsFields") != NOT_FOUND)


def test_builder_accumulates_diagnostics_from_multiple_sources() raises:
    var schema = _schema(
        "type Query { user: User } type User { id: ID! name: String }"
    )
    var builder = ExecutableDocumentBuilder()
    builder.parse(schema, "query GetUser { user { id nonexistentField } }")
    builder.parse(
        schema, "query GetUserProfile { user { id anotherUndefinedField } }"
    )
    builder.parse(schema, "fragment UserFields on User { id name }")
    builder.parse(schema, "fragment UserFields on User { id }")
    builder.parse(schema, "fragment UserName on User { name }")
    var doc = builder^.build()
    assert_equal(len(doc[1]), 3)
    assert_equal(
        doc[1][0].message(),
        "type `User` does not have a field `nonexistentField`",
    )
    assert_equal(
        doc[1][1].message(),
        "type `User` does not have a field `anotherUndefinedField`",
    )
    assert_equal(
        doc[1][2].message(),
        "the fragment `UserFields` is defined multiple times in the document",
    )
    assert_equal(doc[0].named_operation_count(), 2)
    assert_true(_has_operation(doc[0], "GetUser"))
    assert_true(_has_operation(doc[0], "GetUserProfile"))
    assert_equal(len(doc[0].fragments), 2)
    assert_true(doc[0].get_fragment("UserFields") != NOT_FOUND)
    assert_true(doc[0].get_fragment("UserName") != NOT_FOUND)
    assert_equal(Int(doc[1][0].source), 0)
    assert_equal(Int(doc[1][1].source), 1)
    assert_equal(Int(doc[1][2].source), 3)


def test_selection_model() raises:
    var schema = _schema()
    var parsed = parse(
        """
        query Q($id: ID) {
          me: user(id: $id) { id ...F ... on User { name } ... { __typename } }
          node { id __typename }
          search { __typename }
          __type(name: "User") { name }
        }
        fragment F on User { friends { id } }
        """
    )
    var doc = ExecutableDocument.from_ast(schema, parsed^)
    assert_equal(len(doc[1]), 0)
    ref d = doc[0]
    assert_equal(d.anonymous, NOT_FOUND)
    assert_equal(d.named_operation_count(), 1)
    var op = d.get_operation(String("Q"))
    assert_equal(op.operation_type, OperationType.QUERY)
    var root = Int(op.selection_set)
    assert_equal(d.selection_sets[root].ty, Int32(schema.get_type("Query")))
    assert_equal(d.selection_count(root), 4)
    var me = d.selection(root, 0)
    assert_equal(me.kind, SelectionKind.FIELD)
    assert_equal(d.selection_name(me), "user")
    assert_equal(d.response_key(me), "me")
    assert_equal(schema.component_name(me.definition), "user")
    assert_equal(me.meta, MetaField.NONE)
    var user = Int(me.selection_set)
    assert_equal(d.selection_sets[user].ty, Int32(schema.get_type("User")))
    assert_equal(d.selection_count(user), 4)
    var spread = d.selection(user, 1)
    assert_equal(spread.kind, SelectionKind.FRAGMENT_SPREAD)
    assert_equal(spread.selection_set, NO_SELECTION_SET)
    assert_equal(d.selection_name(spread), "F")
    var inline = d.selection(user, 2)
    assert_equal(inline.kind, SelectionKind.INLINE_FRAGMENT)
    assert_equal(d.type_condition(inline), "User")
    var bare = d.selection(user, 3)
    assert_equal(d.type_condition(bare), "")
    var typename = d.selection(Int(bare.selection_set), 0)
    assert_equal(typename.meta, MetaField.TYPENAME)
    assert_equal(Int(typename.definition.node), NO_NODE)
    var leaf = d.selection(user, 0)
    assert_equal(d.response_key(leaf), "id")
    assert_equal(d.selection_count(Int(leaf.selection_set)), 0)
    var node = d.selection(root, 1)
    assert_equal(
        d.selection(Int(node.selection_set), 1).meta, MetaField.TYPENAME
    )
    var search = d.selection(root, 2)
    assert_equal(
        d.selection(Int(search.selection_set), 0).meta, MetaField.TYPENAME
    )
    var type_field = d.selection(root, 3)
    assert_equal(type_field.meta, MetaField.TYPE)
    assert_equal(
        d.selection_sets[Int(type_field.selection_set)].ty,
        Int32(schema.get_type("__Type")),
    )
    var fragment = d.fragments[d.get_fragment("F")]
    assert_equal(
        d.selection_sets[Int(fragment.selection_set)].ty,
        Int32(schema.get_type("User")),
    )
    assert_equal(d.get_fragment("G"), NOT_FOUND)


def test_undefined_field_type() raises:
    var schema = _schema()
    var doc = ExecutableDocument.parse(
        schema, "{ missing { a ... { b } ... on User { id } } }"
    )
    assert_equal(len(doc[1]), 0)
    var root = Int(doc[0].operations[0].selection_set)
    var missing = doc[0].selection(root, 0)
    var inner = Int(missing.selection_set)
    assert_equal(doc[0].selection_sets[inner].ty, Int32(NOT_FOUND))
    assert_equal(doc[0].selection_count(inner), 2)


def test_anonymous_operation() raises:
    var schema = _schema()
    var doc = ExecutableDocument.parse(schema, "mutation { rename { id } }")
    assert_equal(doc[0].anonymous, 0)
    assert_equal(doc[0].named_operation_count(), 0)
    var op = doc[0].get_operation(None)
    assert_equal(op.operation_type, OperationType.MUTATION)
    assert_equal(doc[0].operation_name(op), "")
    assert_false(doc[0].is_introspection(op))


def test_parse_raises_on_syntax_error() raises:
    var schema = _schema()
    with assert_raises():
        _ = ExecutableDocument.parse(schema, "{")
    var builder = ExecutableDocumentBuilder()
    with assert_raises():
        builder.parse(schema, "query {")


def test_kinds() raises:
    assert_true(SelectionKind.INLINE_FRAGMENT.is_valid())
    assert_false(SelectionKind(3).is_valid())
    assert_equal(String(SelectionKind(1)), "SelectionKind(1)")
    assert_true(MetaField.TYPE.is_valid())
    assert_false(MetaField(4).is_valid())
    assert_equal(String(MetaField(2)), "MetaField(2)")
    assert_equal(MetaField.NONE.type_name(), "")
    assert_true(BuildErrorKind.UNDEFINED_FIELD.is_valid())
    assert_false(BuildErrorKind(10).is_valid())
    assert_equal(String(BuildErrorKind(4)), "BuildErrorKind(4)")
    var error = BuildError(
        BuildErrorKind.UNDEFINED_ROOT_OPERATION, 0, 1, "query", "", ""
    )
    assert_equal(String(error), "`query` root operation type is not defined")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
