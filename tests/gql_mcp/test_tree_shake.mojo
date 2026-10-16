# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.tree_shake`.

Ported from Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/schema_tree_shake.rs` (`mod test`, 17
tests). The tests after them cover the branches that the upstream tests do
not reach.
"""

from gql_language.ast import Document, Kind, OperationType
from gql_language.parser import parse
from gql_schema.build import build_schema
from gql_schema.definition import Schema
from gql_mcp.tree_shake import DepthLimit, SchemaTreeShaker
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _operation(document: Document) -> Int:
    """The first operation definition of a document."""
    for definition in document.definitions():
        if document.kind(definition) == Kind.OPERATION_DEFINITION:
            return definition
    return -1


def _shake_operation_types(
    sdl: String, mutation: Bool, depth: DepthLimit
) raises -> String:
    var schema = build_schema(sdl)
    var shaker = SchemaTreeShaker(schema)
    shaker.retain_operation_type(schema, OperationType.QUERY, depth)
    if mutation:
        shaker.retain_operation_type(schema, OperationType.MUTATION, depth)
    return shaker.shaken(schema).to_string(schema)


def _shake_operation(sdl: String, operation: String) raises -> String:
    var schema = build_schema(sdl)
    var document = parse(operation)
    var shaker = SchemaTreeShaker(schema)
    shaker.retain_operation(
        schema, document, _operation(document), DepthLimit.UNLIMITED
    )
    return shaker.shaken(schema).to_string(schema)


comptime ROOTS = """
    type Query { id: String }
    type Mutation { id: String }
    type Subscription { id: String }
"""

comptime CUSTOM_ROOTS = """
    schema {
      query: CustomQuery,
      mutation: CustomMutation,
      subscription: CustomSubscription
    }
    type CustomQuery { id: String }
    type CustomMutation { id: String }
    type CustomSubscription { id: String }
"""


def test_should_remove_type_mutation_mode_none() raises:
    assert_equal(
        _shake_operation_types(ROOTS, False, DepthLimit.UNLIMITED),
        "type Query {\n  id: String\n}\n",
    )


def test_should_remove_type_mutation_mode_all() raises:
    assert_equal(
        _shake_operation_types(ROOTS, True, DepthLimit.UNLIMITED),
        "type Query {\n  id: String\n}\n\ntype Mutation {\n  id: String\n}\n",
    )


def test_should_remove_custom_names_mutation_mode_none() raises:
    assert_equal(
        _shake_operation_types(CUSTOM_ROOTS, False, DepthLimit.UNLIMITED),
        (
            "schema {\n  query: CustomQuery\n}\n\ntype CustomQuery {\n  id:"
            " String\n}\n"
        ),
    )


def test_should_remove_custom_names_mutation_mode_all() raises:
    assert_equal(
        _shake_operation_types(CUSTOM_ROOTS, True, DepthLimit.UNLIMITED),
        (
            "schema {\n  query: CustomQuery\n  mutation:"
            " CustomMutation\n}\n\ntype CustomQuery {\n  id: String\n}\n\ntype"
            " CustomMutation {\n  id: String\n}\n"
        ),
    )


def test_should_remove_orphan_types() raises:
    assert_equal(
        _shake_operation_types(
            """
            type Query { id: UsedInQuery }
            type Mutation { id: UsedInMutation }
            type Subscription { id: UsedInSubscription }
            scalar UsedInQuery
            type UsedInMutation { id: String }
            enum UsedInSubscription { VALUE }
            """,
            True,
            DepthLimit.UNLIMITED,
        ),
        (
            "type Query {\n  id: UsedInQuery\n}\n\ntype Mutation {\n  id:"
            " UsedInMutation\n}\n\nscalar UsedInQuery\n\ntype UsedInMutation"
            " {\n  id: String\n}\n"
        ),
    )


def test_should_work_with_selection_set() raises:
    assert_equal(
        _shake_operation(
            """
            type Query { id: UsedInQuery unused: UsedInQueryButUnusedField }
            type Mutation { id: UsedInMutation }
            type Subscription { id: UsedInSubscription }
            scalar UsedInQuery
            type UsedInQueryButUnusedField { id: String, unused: String }
            type UsedInMutation { id: String }
            enum UsedInSubscription { VALUE }
            """,
            "query TestQuery { id }",
        ),
        "type Query {\n  id: UsedInQuery\n}\n\nscalar UsedInQuery\n",
    )


comptime NESTED = """
    type Query  { level1: Level1 }
    type Level1 { level2: Level2 }
    type Level2 { level3: Level3 }
    type Level3 { level4: Level4 }
    type Level4 { id: String }
"""


def _kept(start: String, depth: DepthLimit) raises -> String:
    """The names of the kept types, after a shaking from one type."""
    var schema = build_schema(NESTED)
    var shaker = SchemaTreeShaker(schema)
    shaker.retain_type(schema, schema.type_named(start), None, depth)
    var shaken = shaker.shaken(schema)
    var out = String()
    for name in ["Query", "Level1", "Level2", "Level3", "Level4"]:
        if shaken.has_type(schema, name):
            out += name + " "
    return out^


def test_should_respect_depth_limit() raises:
    assert_equal(_kept("Query", DepthLimit.limited(1)), "Query ")
    assert_equal(_kept("Query", DepthLimit.limited(2)), "Query Level1 ")
    assert_equal(_kept("Level2", DepthLimit.limited(1)), "Level2 ")
    assert_equal(_kept("Level2", DepthLimit.limited(2)), "Level2 Level3 ")
    assert_equal(
        _kept("Level2", DepthLimit.limited(5)), "Level2 Level3 Level4 "
    )


def test_should_retain_all_types_with_unlimited_depth() raises:
    assert_equal(
        _kept("Query", DepthLimit.UNLIMITED),
        "Query Level1 Level2 Level3 Level4 ",
    )


def test_should_work_with_recursive_schemas() raises:
    assert_equal(
        _shake_operation_types(
            """
            type Query { id: TypeA }
            type TypeA { id: TypeB }
            type TypeB { id: TypeA }
            """,
            False,
            DepthLimit.UNLIMITED,
        ),
        (
            "type Query {\n  id: TypeA\n}\n\ntype TypeA {\n  id:"
            " TypeB\n}\n\ntype TypeB {\n  id: TypeA\n}\n"
        ),
    )


def test_should_work_with_recursive_and_depth() raises:
    assert_equal(
        _shake_operation_types(
            """
            type Query { field1: TypeA, field2: TypeB }
            type TypeA { id: TypeB }
            type TypeB { id: TypeC }
            type TypeC { id: TypeA }
            """,
            False,
            DepthLimit.limited(3),
        ),
        (
            "type Query {\n  field1: TypeA\n  field2: TypeB\n}\n\ntype TypeA"
            " {\n  id: TypeB\n}\n\ntype TypeB {\n  id: TypeC\n}\n\ntype TypeC"
            " {\n  id: TypeA\n}\n"
        ),
    )


def test_should_retain_builtin_directives() raises:
    assert_equal(
        _shake_operation_types(
            """
            type Query {
                field1: String @deprecated(reason: "Use 'field2' instead")
                field2: String
            }
            """,
            False,
            DepthLimit.limited(3),
        ),
        (
            "type Query {\n  field1: String @deprecated(reason: \"Use 'field2'"
            ' instead")\n  field2: String\n}\n'
        ),
    )


def test_should_retain_custom_directives() raises:
    assert_equal(
        _shake_operation_types(
            """
            type Query {
                field1: String @CustomDirective(arg: "Use 'field2' instead")
                field2: String
            }
            directive @CustomDirective(arg: CustomScalar) on FIELD_DEFINITION
            scalar CustomScalar
            """,
            False,
            DepthLimit.limited(3),
        ),
        (
            "directive @CustomDirective(arg: CustomScalar) on"
            " FIELD_DEFINITION\n\ntype Query {\n  field1: String"
            " @CustomDirective(arg: \"Use 'field2' instead\")\n  field2:"
            " String\n}\n\nscalar CustomScalar\n"
        ),
    )


def test_recursive_input() raises:
    assert_equal(
        _shake_operation_types(
            """
            input Filter {
                field: String
                filter: Filter
            }
            type Query {
                field(filter: Filter): String
            }
            """,
            False,
            DepthLimit.UNLIMITED,
        ),
        (
            "input Filter {\n  field: String\n  filter: Filter\n}\n\ntype Query"
            " {\n  field(filter: Filter): String\n}\n"
        ),
    )


def _descriptions(
    sdl: String, operation: String, variable: String
) raises -> String:
    """The collected descriptions of a variable, joined with `|`, and the
    number of variables with descriptions."""
    var schema = build_schema(sdl)
    var document = parse(operation)
    var shaker = SchemaTreeShaker(schema)
    shaker.retain_operation(
        schema, document, _operation(document), DepthLimit.UNLIMITED
    )
    var descriptions = shaker.argument_descriptions()
    var out = String(len(descriptions)) + ":"
    var found = descriptions.get(variable)
    if found:
        for index in range(len(found.value())):
            if index > 0:
                out += "|"
            out += found.value()[index]
    return out^


def test_should_retain_field_argument_descriptions() raises:
    comptime SDL = """
        type Query {
            someQuery(\"\"\" an id \"\"\" id: ID!, \"\"\" other arg \"\"\" other: String): OutoutType
        }

        type OutoutType {
            value: String
        }
    """
    comptime OPERATION = (
        "query TestQuery($id1: ID, $other: String) { someQuery(id: $id1,"
        " other: $other, otherArg: $other) { value } }"
    )
    assert_equal(_descriptions(SDL, OPERATION, "id1"), "2:an id")
    assert_equal(_descriptions(SDL, OPERATION, "other"), "2:other arg")


def test_should_retain_field_argument_descriptions_when_multiple_are_found() raises:
    comptime SDL = """
        type Query {
            someQuery(\"\"\" an id \"\"\" id: ID!, \"\"\" other arg \"\"\" other: String, \"\"\" another arg \"\"\" otherArg: String): OutoutType
            someQuery2(\"\"\" another id \"\"\" id: ID!, \"\"\" arg 2 \"\"\" other: String): OutoutType
        }

        type OutoutType {
            value: String
        }
    """
    comptime OPERATION = (
        "query TestQuery($id: ID, $other2: String) { someQuery(id: $id,"
        " other: $other2, otherArg: $other2) { value } }"
    )
    assert_equal(_descriptions(SDL, OPERATION, "id"), "2:an id")
    assert_equal(
        _descriptions(SDL, OPERATION, "other2"), "2:other arg|another arg"
    )


def test_should_retain_builtin_directive_argument_descriptions() raises:
    assert_equal(
        _descriptions(
            """
            type Query {
                someQuery(id: ID!, other: Boolean!): OutoutType
            }

            type OutoutType {
                id: ID!
                value: String
            }
            """,
            (
                "query TestQuery($id: ID, $other: Boolean!) { someQuery(id:"
                " $id, other: $other) { id value @skip(if: $other) } }"
            ),
            "other",
        ),
        "1:Skipped when true.",
    )


def test_should_retain_custom_directive_argument_descriptions() raises:
    assert_equal(
        _descriptions(
            """
            type Query {
                someQuery(id: ID!, other: Boolean!): OutoutType
            }

            directive @x(\"\"\" the value \"\"\" value: String) on FIELD_DEFINITION

            type OutoutType {
                id: ID!
                value: String
            }
            """,
            (
                "query TestQuery($id: ID, $other: Boolean!) { someQuery(id:"
                " $id, other: $other) { id value @x(value: $other) } }"
            ),
            "other",
        ),
        "1:the value",
    )


comptime SEARCH = """
    type Query {
        search: [SearchResult]
    }

    union SearchResult = User | Post

    type User {
        id: ID
        name: String
    }

    type Post {
        id: ID
        title: String
    }
"""


def test_should_retain_types_referenced_in_inline_fragments() raises:
    var text = _shake_operation(
        SEARCH,
        (
            "query Search { search { ... on User { id name } ... on Post { id"
            " title } } }"
        ),
    )
    assert_true("type User {" in text)
    assert_true("type Post {" in text)


def test_should_retain_types_referenced_in_fragment_spreads() raises:
    var text = _shake_operation(
        SEARCH,
        (
            "query Search { search { ...UserFields ...PostFields } } fragment"
            " UserFields on User { id name } fragment PostFields on Post { id"
            " title }"
        ),
    )
    assert_true("type User {" in text)
    assert_true("type Post {" in text)


comptime BRANCHES = '''
    directive @mark on FIELD
    interface Thing { id: ID! name(a: Int): String }
    type Obj implements Thing { id: ID! name(""" """ a: Int): String kind: Kind }
    enum Kind { A B }
    union Any = Obj | Other
    type Other { x: Int }
    input Filter { a: Int b: Int }
    type Query { thing: Thing obj(f: Filter): Obj any: Any }
'''


def test_selection_branches() raises:
    var text = _shake_operation(
        BRANCHES,
        """
        query Q($v: Int) {
          __typename
          thing {
            __typename id name(a: $v) @mark @unknown
            ... { id } ... on Missing { x } ...Missing
          }
          obj { nope kind name(a: $v) @mark @unknown }
          any { __typename ... on Other { x } ...ObjFields ...Missing }
          missing
        }
        fragment ObjFields on Obj { id }
        """,
    )
    assert_equal(
        text,
        (
            "directive @mark on FIELD\n\ninterface Thing {\n  id: ID!\n "
            " name(a: Int): String\n}\n\ntype Obj implements Thing {\n  id:"
            ' ID!\n  name(\n    ""\n    a: Int,\n  ): String\n  kind:'
            " Kind\n}\n\nenum Kind {\n  A\n  B\n}\n\nunion Any = Obj |"
            " Other\n\ntype Other {\n  x: Int\n}\n\ninput Filter {\n  a: Int\n "
            " b: Int\n}\n\ntype Query {\n  thing: Thing\n  obj(f: Filter):"
            " Obj\n  any: Any\n}\n"
        ),
    )
    var schema = build_schema(BRANCHES)
    var document = parse(
        "query B { any } query C { any { ... on Other { x } } }"
    )
    var shaker = SchemaTreeShaker(schema)
    shaker.retain_operation(
        schema, document, document.definitions()[0], DepthLimit.UNLIMITED
    )
    assert_false(shaker.shaken(schema).has_type(schema, "Obj"))
    shaker.retain_operation(
        schema, document, document.definitions()[1], DepthLimit.UNLIMITED
    )
    var shaken = shaker.shaken(schema)
    assert_true(shaken.has_type(schema, "Other"))
    assert_false(shaken.has_type(schema, "Obj"))
    assert_equal(len(shaker.argument_descriptions()), 0)


def test_roots_and_fields() raises:
    var schema = build_schema(BRANCHES)
    var shaker = SchemaTreeShaker(schema)
    shaker.retain_operation_type(
        schema, OperationType.MUTATION, DepthLimit.UNLIMITED
    )
    shaker.retain_type(
        schema, schema.type_named("Query"), String("obj"), DepthLimit.limited(1)
    )
    shaker.retain_type(
        schema, schema.type_named("Filter"), String("b"), DepthLimit.limited(1)
    )
    var document = parse("mutation M { a }")
    shaker.retain_operation(
        schema, document, document.definitions()[0], DepthLimit.UNLIMITED
    )
    var shaken = shaker.shaken(schema)
    assert_equal(
        shaken.to_string(schema),
        (
            "input Filter {\n  b: Int\n}\n\ntype Query {\n  obj(f: Filter):"
            " Obj\n}\n"
        ),
    )
    assert_equal(shaken.type_count(), 2)
    assert_equal(shaken.type_index(0), schema.type_named("Filter"))
    assert_equal(shaken.minify_type(schema, 1), "T:Query:obj(f:Filter):Obj")
    shaker.retain_operation_type(
        schema, OperationType.QUERY, DepthLimit.limited(1)
    )
    shaker.retain_operation_type(
        schema, OperationType.QUERY, DepthLimit.limited(1)
    )
    assert_true(
        shaker.shaken(schema).to_string(schema).startswith("input Filter {")
    )


def test_empty_and_explicit_schemas() raises:
    var schema = build_schema(BRANCHES)
    var shaker = SchemaTreeShaker(schema)
    assert_equal(shaker.shaken(schema).to_string(schema), "")
    assert_false(shaker.shaken(schema).has_type(schema, "Query"))
    shaker.retain_operation_type(
        schema, OperationType.QUERY, DepthLimit.limited(0)
    )
    assert_equal(
        shaker.shaken(schema).to_string(schema), "schema {\n  query: Query\n}\n"
    )
    var directed = build_schema(
        "directive @d on SCHEMA\nschema @d { query: Query }\ntype Query { a:"
        " Int }"
    )
    var other = SchemaTreeShaker(directed)
    other.retain_operation_type(
        directed, OperationType.QUERY, DepthLimit.UNLIMITED
    )
    assert_equal(
        other.shaken(directed).to_string(directed),
        "schema @d {\n  query: Query\n}\n\ntype Query {\n  a: Int\n}\n",
    )
    assert_true(DepthLimit.UNLIMITED.is_valid())
    assert_false(DepthLimit(-2).is_valid())
    assert_true(DepthLimit.limited(0).decrement() == DepthLimit.limited(0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
