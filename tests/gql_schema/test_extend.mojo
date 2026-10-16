# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.build.extend_schema`, ported from graphql-js
16.14.2 `src/utilities/__tests__/extendSchema-test.ts`.

"can be used for limited execution" belongs to the execution package.
"Rejects invalid AST" checks a JavaScript type error, which
Mojo's types rule out. graphql-js `new GraphQLSchema({})` is
`build_ast_schema` of no documents, which gives the same schema.
"""

from _helpers import dedent
from _schema_nodes import (
    ast_node,
    extension_nodes,
    printed_definitions,
    schema_changes,
)
from gql_language.ast import Document
from gql_language.parser import ParseOptions, parse
from gql_schema.build import (
    BuildOptions,
    build_ast_schema,
    build_schema,
    extend_schema,
)
from gql_schema.definition import NO_TYPE, Schema
from gql_schema.print import print_schema
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def empty_schema() raises -> Schema:
    """Return graphql-js `new GraphQLSchema({})`."""
    return build_ast_schema(List[Document]())


def extend(schema: Schema, sdl: String) raises -> Schema:
    """Extend a schema with parsed SDL."""
    return extend_schema(schema, parse(sdl))


def experimental() -> ParseOptions:
    """Return parse options that allow directives on directives."""
    var options = ParseOptions()
    options.experimental_directives_on_directive_definitions = True
    return options


def test_returns_the_original_schema_without_type_definitions() raises:
    var schema = build_schema("type Query")
    var extended = extend(schema, "{ field }")
    assert_equal(print_schema(extended), print_schema(schema))
    assert_equal(len(extended.documents), len(schema.documents))


def test_extends_objects_by_adding_new_fields() raises:
    var schema = build_schema(
        '''
      type Query {
        someObject: SomeObject
      }

      type SomeObject implements AnotherInterface & SomeInterface {
        self: SomeObject
        tree: [SomeObject]!
        """Old field description."""
        oldField: String
      }

      interface SomeInterface {
        self: SomeInterface
      }

      interface AnotherInterface {
        self: SomeObject
      }
    '''
    )
    var extended = extend(
        schema,
        dedent(
            '''
      extend type SomeObject {
        """New field description."""
        newField(arg: Boolean): String
      }
    '''
        ),
    )
    assert_equal(
        schema_changes(schema, extended),
        dedent(
            '''
      type SomeObject implements AnotherInterface & SomeInterface {
        self: SomeObject
        tree: [SomeObject]!
        """Old field description."""
        oldField: String
        """New field description."""
        newField(arg: Boolean): String
      }
    '''
        ),
    )


def test_extends_objects_with_standard_type_fields() raises:
    var schema = build_schema("type Query")
    assert_equal(schema.type_named("Int"), NO_TYPE)
    assert_equal(schema.type_named("Float"), NO_TYPE)
    assert_true(schema.type_named("String") != NO_TYPE)
    assert_true(schema.type_named("Boolean") != NO_TYPE)
    assert_equal(schema.type_named("ID"), NO_TYPE)

    var extended = extend(schema, "extend type Query {\n  bool: Boolean\n}")
    assert_equal(extended.type_named("Int"), NO_TYPE)
    assert_equal(extended.type_named("Float"), NO_TYPE)
    assert_equal(extended.type_named("String"), schema.type_named("String"))
    assert_equal(extended.type_named("Boolean"), schema.type_named("Boolean"))
    assert_equal(extended.type_named("ID"), NO_TYPE)

    var twice = extend(
        schema, "extend type Query {\n  int: Int\n  float: Float\n  id: ID\n}"
    )
    var names: List[String] = ["Int", "Float", "String", "Boolean", "ID"]
    for ref name in names:
        var type = twice.type_named(name)
        assert_true(type != NO_TYPE)
        assert_true(twice.types[type].is_builtin)


def test_extends_enums_by_adding_new_values() raises:
    var schema = build_schema(
        '''
      type Query {
        someEnum(arg: SomeEnum): SomeEnum
      }

      directive @foo(arg: SomeEnum) on SCHEMA

      enum SomeEnum {
        """Old value description."""
        OLD_VALUE
      }
    '''
    )
    var extended = extend(
        schema,
        '''
      extend enum SomeEnum {
        """New value description."""
        NEW_VALUE
      }
    ''',
    )
    assert_equal(
        schema_changes(schema, extended),
        dedent(
            '''
      enum SomeEnum {
        """Old value description."""
        OLD_VALUE
        """New value description."""
        NEW_VALUE
      }
    '''
        ),
    )


def test_extends_unions_by_adding_new_types() raises:
    var schema = build_schema(
        """
      type Query {
        someUnion: SomeUnion
      }

      union SomeUnion = Foo | Biz

      type Foo { foo: String }
      type Biz { biz: String }
      type Bar { bar: String }
    """
    )
    var extended = extend(schema, "extend union SomeUnion = Bar")
    assert_equal(
        schema_changes(schema, extended), "union SomeUnion = Foo | Biz | Bar"
    )


def test_allows_extension_of_union_by_adding_itself() raises:
    var schema = build_schema("union SomeUnion")
    var extended = extend(schema, "extend union SomeUnion = SomeUnion")
    assert_equal(
        schema_changes(schema, extended), "union SomeUnion = SomeUnion"
    )


def test_extends_inputs_by_adding_new_fields() raises:
    var schema = build_schema(
        '''
      type Query {
        someInput(arg: SomeInput): String
      }

      directive @foo(arg: SomeInput) on SCHEMA

      input SomeInput {
        """Old field description."""
        oldField: String
      }
    '''
    )
    var extended = extend(
        schema,
        '''
      extend input SomeInput {
        """New field description."""
        newField: String
      }
    ''',
    )
    assert_equal(
        schema_changes(schema, extended),
        dedent(
            '''
      input SomeInput {
        """Old field description."""
        oldField: String
        """New field description."""
        newField: String
      }
    '''
        ),
    )


def test_extends_scalars_by_adding_new_directives() raises:
    var schema = build_schema(
        """
      type Query {
        someScalar(arg: SomeScalar): SomeScalar
      }

      directive @foo(arg: SomeScalar) on SCALAR

      input FooInput {
        foo: SomeScalar
      }

      scalar SomeScalar
    """
    )
    var sdl = String("extend scalar SomeScalar @foo")
    var extended = extend(schema, sdl)
    ref some_scalar = extended.types[extended.type_named("SomeScalar")]
    assert_equal(extension_nodes(extended, some_scalar.extensions), sdl)
    assert_equal(some_scalar.directives.count, 1)


def test_extends_scalars_by_adding_specified_by_directive() raises:
    var schema = build_schema(
        """
      type Query {
        foo: Foo
      }

      scalar Foo

      directive @foo on SCALAR
    """
    )
    var sdl = dedent(
        """
      extend scalar Foo @foo

      extend scalar Foo @specifiedBy(url: "https://example.com/foo_spec")
    """
    )
    var extended = extend(schema, sdl)
    ref foo = extended.types[extended.type_named("Foo")]
    assert_equal(foo.specified_by_url, "https://example.com/foo_spec")
    assert_equal(extension_nodes(extended, foo.extensions), sdl)


comptime _FIRST_EXTENSION = """
      extend type Query {
        newField(testArg: TestInput): TestEnum
      }

      extend scalar SomeScalar @foo

      extend enum SomeEnum {
        NEW_VALUE
      }

      extend union SomeUnion = SomeObject

      extend input SomeInput {
        newField: String
      }

      extend interface SomeInterface {
        newField: String
      }

      enum TestEnum {
        TEST_VALUE
      }

      input TestInput {
        testInputField: TestEnum
      }
    """

comptime _SECOND_EXTENSION = """
      extend type Query {
        oneMoreNewField: TestUnion
      }

      extend scalar SomeScalar @test

      extend enum SomeEnum {
        ONE_MORE_NEW_VALUE
      }

      extend union SomeUnion = TestType

      extend input SomeInput {
        oneMoreNewField: String
      }

      extend interface SomeInterface {
        oneMoreNewField: String
      }

      union TestUnion = TestType

      interface TestInterface {
        interfaceField: String
      }

      type TestType implements TestInterface {
        interfaceField: String
      }

      directive @test(arg: Int) repeatable on FIELD | SCALAR
    """


def test_correctly_assign_ast_nodes_to_new_and_extended_types() raises:
    var schema = build_schema(
        """
      type Query

      scalar SomeScalar
      enum SomeEnum
      union SomeUnion
      input SomeInput
      type SomeObject
      interface SomeInterface

      directive @foo on SCALAR
    """
    )
    var extended = extend(schema, _FIRST_EXTENSION)
    var twice = extend(extended, _SECOND_EXTENSION)
    # graphql-js concatenates the two documents with `concatAST`.
    var in_one_go = extend(schema, _FIRST_EXTENSION + _SECOND_EXTENSION)
    assert_equal(print_schema(in_one_go), print_schema(twice))

    var new_types: List[String] = [
        "TestInput",
        "TestEnum",
        "TestUnion",
        "TestInterface",
        "TestType",
    ]
    var nodes = List[String]()
    for ref name in new_types:
        ref named = twice.types[twice.type_named(name)]
        assert_equal(named.extensions.count, 0)
        nodes.append(ast_node(twice, named.definition))
    var test_directive = twice.directive_named("test")
    nodes.append(ast_node(twice, twice.directives[test_directive].definition))
    var extended_types: List[String] = [
        "Query",
        "SomeScalar",
        "SomeEnum",
        "SomeUnion",
        "SomeInput",
        "SomeInterface",
    ]
    for ref name in extended_types:
        ref span = twice.types[twice.type_named(name)].extensions
        for index in range(Int(span.start), span.end()):
            nodes.append(ast_node(twice, twice.ast_refs[index]))
    var expected = printed_definitions(_FIRST_EXTENSION)
    expected.extend(printed_definitions(_SECOND_EXTENSION))
    sort(nodes)
    sort(expected)
    assert_equal(len(nodes), len(expected))
    for index in range(len(nodes)):
        assert_equal(nodes[index], expected[index])

    var query = twice.type_named("Query")
    ref new_field = twice.fields[twice.field_named(query, "newField")]
    assert_equal(
        ast_node(twice, new_field.definition),
        "newField(testArg: TestInput): TestEnum",
    )
    assert_equal(
        ast_node(
            twice, twice.input_values[Int(new_field.arguments.start)].definition
        ),
        "testArg: TestInput",
    )
    assert_equal(
        ast_node(
            twice,
            twice.fields[
                twice.field_named(query, "oneMoreNewField")
            ].definition,
        ),
        "oneMoreNewField: TestUnion",
    )
    var some_enum = twice.type_named("SomeEnum")
    var values: List[String] = ["NEW_VALUE", "ONE_MORE_NEW_VALUE"]
    for ref value in values:
        assert_equal(
            ast_node(
                twice,
                twice.enum_values[
                    twice.enum_value_named(some_enum, value)
                ].definition,
            ),
            value,
        )
    var some_input = twice.type_named("SomeInput")
    var some_interface = twice.type_named("SomeInterface")
    var fields: List[String] = ["newField", "oneMoreNewField"]
    for ref field in fields:
        assert_equal(
            ast_node(
                twice,
                twice.input_values[
                    twice.input_field_named(some_input, field)
                ].definition,
            ),
            field + ": String",
        )
        assert_equal(
            ast_node(
                twice,
                twice.fields[
                    twice.field_named(some_interface, field)
                ].definition,
            ),
            field + ": String",
        )
    var test_input = twice.type_named("TestInput")
    assert_equal(
        ast_node(
            twice,
            twice.input_values[
                twice.input_field_named(test_input, "testInputField")
            ].definition,
        ),
        "testInputField: TestEnum",
    )
    var test_enum = twice.type_named("TestEnum")
    assert_equal(
        ast_node(
            twice,
            twice.enum_values[
                twice.enum_value_named(test_enum, "TEST_VALUE")
            ].definition,
        ),
        "TEST_VALUE",
    )
    var test_interface = twice.type_named("TestInterface")
    var test_type = twice.type_named("TestType")
    assert_equal(
        ast_node(
            twice,
            twice.fields[
                twice.field_named(test_interface, "interfaceField")
            ].definition,
        ),
        "interfaceField: String",
    )
    assert_equal(
        ast_node(
            twice,
            twice.fields[
                twice.field_named(test_type, "interfaceField")
            ].definition,
        ),
        "interfaceField: String",
    )
    ref directive = twice.directives[test_directive]
    assert_equal(
        ast_node(
            twice, twice.input_values[Int(directive.arguments.start)].definition
        ),
        "arg: Int",
    )


def test_builds_types_with_deprecated_fields_and_values() raises:
    var extended = extend(
        empty_schema(),
        """
      type SomeObject {
        deprecatedField: String @deprecated(reason: "not used anymore")
      }

      enum SomeEnum {
        DEPRECATED_VALUE @deprecated(reason: "do not use")
      }
    """,
    )
    var some_type = extended.type_named("SomeObject")
    assert_equal(
        extended.fields[
            extended.field_named(some_type, "deprecatedField")
        ].deprecation_reason,
        "not used anymore",
    )
    var some_enum = extended.type_named("SomeEnum")
    assert_equal(
        extended.enum_values[
            extended.enum_value_named(some_enum, "DEPRECATED_VALUE")
        ].deprecation_reason,
        "do not use",
    )


def test_extends_objects_with_deprecated_fields() raises:
    var schema = build_schema("type SomeObject")
    var extended = extend(
        schema,
        """
      extend type SomeObject {
        deprecatedField: String @deprecated(reason: "not used anymore")
      }
    """,
    )
    var some_type = extended.type_named("SomeObject")
    assert_equal(
        extended.fields[
            extended.field_named(some_type, "deprecatedField")
        ].deprecation_reason,
        "not used anymore",
    )


def test_extends_enums_with_deprecated_values() raises:
    var schema = build_schema("enum SomeEnum")
    var extended = extend(
        schema,
        """
      extend enum SomeEnum {
        DEPRECATED_VALUE @deprecated(reason: "do not use")
      }
    """,
    )
    var some_enum = extended.type_named("SomeEnum")
    assert_equal(
        extended.enum_values[
            extended.enum_value_named(some_enum, "DEPRECATED_VALUE")
        ].deprecation_reason,
        "do not use",
    )


def test_adds_new_unused_types() raises:
    var schema = build_schema("type Query {\n  dummy: String\n}")
    var sdl = dedent(
        """
      type DummyUnionMember {
        someField: String
      }

      enum UnusedEnum {
        SOME_VALUE
      }

      input UnusedInput {
        someField: String
      }

      interface UnusedInterface {
        someField: String
      }

      type UnusedObject {
        someField: String
      }

      union UnusedUnion = DummyUnionMember
    """
    )
    var extended = extend(schema, sdl)
    assert_equal(schema_changes(schema, extended), sdl)


def test_extends_objects_by_adding_new_fields_with_arguments() raises:
    var schema = build_schema(
        """
      type SomeObject

      type Query {
        someObject: SomeObject
      }
    """
    )
    var extended = extend(
        schema,
        """
      input NewInputObj {
        field1: Int
        field2: [Float]
        field3: String!
      }

      extend type SomeObject {
        newField(arg1: String, arg2: NewInputObj!): String
      }
    """,
    )
    assert_equal(
        schema_changes(schema, extended),
        dedent(
            """
      type SomeObject {
        newField(arg1: String, arg2: NewInputObj!): String
      }

      input NewInputObj {
        field1: Int
        field2: [Float]
        field3: String!
      }
    """
        ),
    )


def test_extends_objects_by_adding_new_fields_with_existing_types() raises:
    var schema = build_schema(
        """
      type Query {
        someObject: SomeObject
      }

      type SomeObject
      enum SomeEnum { VALUE }
    """
    )
    var extended = extend(
        schema,
        """
      extend type SomeObject {
        newField(arg1: SomeEnum!): SomeEnum
      }
    """,
    )
    assert_equal(
        schema_changes(schema, extended),
        "type SomeObject {\n  newField(arg1: SomeEnum!): SomeEnum\n}",
    )


def test_extends_objects_by_adding_implemented_interfaces() raises:
    var schema = build_schema(
        """
      type Query {
        someObject: SomeObject
      }

      type SomeObject {
        foo: String
      }

      interface SomeInterface {
        foo: String
      }
    """
    )
    var extended = extend(
        schema, "extend type SomeObject implements SomeInterface"
    )
    assert_equal(
        schema_changes(schema, extended),
        "type SomeObject implements SomeInterface {\n  foo: String\n}",
    )
    var some_interface = extended.type_named("SomeInterface")
    var some_object = extended.type_named("SomeObject")
    assert_true(extended.is_sub_type(some_interface, some_object))


comptime _NEW_TYPES_SDL = """
      enum NewEnum {
        VALUE
      }

      interface NewInterface {
        baz: String
      }

      type NewObject implements NewInterface {
        baz: String
      }

      scalar NewScalar

      union NewUnion = NewObject"""


def test_extends_objects_by_including_new_types() raises:
    var schema = build_schema(
        """
      type Query {
        someObject: SomeObject
      }

      type SomeObject {
        oldField: String
      }
    """
    )
    var extended = extend(
        schema,
        _NEW_TYPES_SDL
        + """
      extend type SomeObject {
        newObject: NewObject
        newInterface: NewInterface
        newUnion: NewUnion
        newScalar: NewScalar
        newEnum: NewEnum
        newTree: [SomeObject]!
      }
    """,
    )
    assert_equal(
        schema_changes(schema, extended),
        dedent(
            """
      type SomeObject {
        oldField: String
        newObject: NewObject
        newInterface: NewInterface
        newUnion: NewUnion
        newScalar: NewScalar
        newEnum: NewEnum
        newTree: [SomeObject]!
      }
    """
        )
        + "\n\n"
        + dedent(_NEW_TYPES_SDL),
    )


def test_extends_objects_by_adding_implemented_new_interfaces() raises:
    var schema = build_schema(
        """
      type Query {
        someObject: SomeObject
      }

      type SomeObject implements OldInterface {
        oldField: String
      }

      interface OldInterface {
        oldField: String
      }
    """
    )
    var extended = extend(
        schema,
        """
      extend type SomeObject implements NewInterface {
        newField: String
      }

      interface NewInterface {
        newField: String
      }
    """,
    )
    assert_equal(
        schema_changes(schema, extended),
        dedent(
            """
      type SomeObject implements OldInterface & NewInterface {
        oldField: String
        newField: String
      }

      interface NewInterface {
        newField: String
      }
    """
        ),
    )


comptime _MORE_NEW_TYPES_SDL = """
      scalar NewScalar

      scalar AnotherNewScalar

      type NewObject {
        foo: String
      }

      type AnotherNewObject {
        foo: String
      }

      interface NewInterface {
        newField: String
      }

      interface AnotherNewInterface {
        anotherNewField: String
      }
    """


def test_extends_different_types_multiple_times() raises:
    var schema = build_schema(
        """
      type Query {
        someScalar: SomeScalar
        someObject(someInput: SomeInput): SomeObject
        someInterface: SomeInterface
        someEnum: SomeEnum
        someUnion: SomeUnion
      }

      scalar SomeScalar

      type SomeObject implements SomeInterface {
        oldField: String
      }

      interface SomeInterface {
        oldField: String
      }

      enum SomeEnum {
        OLD_VALUE
      }

      union SomeUnion = SomeObject

      input SomeInput {
        oldField: String
      }
    """
    )
    var new_types = dedent(_MORE_NEW_TYPES_SDL)
    var with_new_types = extend(schema, new_types)
    assert_equal(schema_changes(schema, with_new_types), new_types)
    var extended = extend(
        with_new_types,
        """
      extend scalar SomeScalar @specifiedBy(url: "http://example.com/foo_spec")

      extend type SomeObject implements NewInterface {
        newField: String
      }

      extend type SomeObject implements AnotherNewInterface {
        anotherNewField: String
      }

      extend enum SomeEnum {
        NEW_VALUE
      }

      extend enum SomeEnum {
        ANOTHER_NEW_VALUE
      }

      extend union SomeUnion = NewObject

      extend union SomeUnion = AnotherNewObject

      extend input SomeInput {
        newField: String
      }

      extend input SomeInput {
        anotherNewField: String
      }
    """,
    )
    assert_equal(
        schema_changes(schema, extended),
        dedent(
            """
      scalar SomeScalar @specifiedBy(url: "http://example.com/foo_spec")

      type SomeObject implements SomeInterface & NewInterface & AnotherNewInterface {
        oldField: String
        newField: String
        anotherNewField: String
      }

      enum SomeEnum {
        OLD_VALUE
        NEW_VALUE
        ANOTHER_NEW_VALUE
      }

      union SomeUnion = SomeObject | NewObject | AnotherNewObject

      input SomeInput {
        oldField: String
        newField: String
        anotherNewField: String
      }
    """
        )
        + "\n\n"
        + new_types,
    )


comptime _INTERFACES_SDL = """
      interface SomeInterface {
        oldField: String
      }

      interface AnotherInterface implements SomeInterface {
        oldField: String
      }

      type SomeObject implements SomeInterface & AnotherInterface {
        oldField: String
      }

      type Query {
        someInterface: SomeInterface
      }
    """


def test_extends_interfaces_by_adding_new_fields() raises:
    var schema = build_schema(_INTERFACES_SDL)
    var extended = extend(
        schema,
        """
      extend interface SomeInterface {
        newField: String
      }

      extend interface AnotherInterface {
        newField: String
      }

      extend type SomeObject {
        newField: String
      }
    """,
    )
    assert_equal(
        schema_changes(schema, extended),
        dedent(
            """
      interface SomeInterface {
        oldField: String
        newField: String
      }

      interface AnotherInterface implements SomeInterface {
        oldField: String
        newField: String
      }

      type SomeObject implements SomeInterface & AnotherInterface {
        oldField: String
        newField: String
      }
    """
        ),
    )


def test_extends_interfaces_by_adding_new_implemented_interfaces() raises:
    var schema = build_schema(_INTERFACES_SDL)
    var extended = extend(
        schema,
        """
      interface NewInterface {
        newField: String
      }

      extend interface AnotherInterface implements NewInterface {
        newField: String
      }

      extend type SomeObject implements NewInterface {
        newField: String
      }
    """,
    )
    assert_equal(
        schema_changes(schema, extended),
        dedent(
            """
      interface AnotherInterface implements SomeInterface & NewInterface {
        oldField: String
        newField: String
      }

      type SomeObject implements SomeInterface & AnotherInterface & NewInterface {
        oldField: String
        newField: String
      }

      interface NewInterface {
        newField: String
      }
    """
        ),
    )
    var new_interface = extended.type_named("NewInterface")
    var another = extended.type_named("AnotherInterface")
    assert_true(extended.is_sub_type(new_interface, another))
    assert_true(
        extended.is_sub_type(new_interface, extended.type_named("SomeObject"))
    )


def test_allows_extension_of_interface_with_missing_object_fields() raises:
    var schema = build_schema(
        """
      type Query {
        someInterface: SomeInterface
      }

      type SomeObject implements SomeInterface {
        oldField: SomeInterface
      }

      interface SomeInterface {
        oldField: SomeInterface
      }
    """
    )
    var extended = extend(
        schema, "extend interface SomeInterface {\n  newField: String\n}"
    )
    assert_equal(
        schema_changes(schema, extended),
        dedent(
            """
      interface SomeInterface {
        oldField: SomeInterface
        newField: String
      }
    """
        ),
    )


def test_extends_interfaces_multiple_times() raises:
    var schema = build_schema(
        """
      type Query {
        someInterface: SomeInterface
      }

      interface SomeInterface {
        some: SomeInterface
      }
    """
    )
    var extended = extend(
        schema,
        """
      extend interface SomeInterface {
        newFieldA: Int
      }

      extend interface SomeInterface {
        newFieldB(test: Boolean): String
      }
    """,
    )
    assert_equal(
        schema_changes(schema, extended),
        dedent(
            """
      interface SomeInterface {
        some: SomeInterface
        newFieldA: Int
        newFieldB(test: Boolean): String
      }
    """
        ),
    )
    var some_interface = extended.type_named("SomeInterface")
    var field = extended.field_named(some_interface, "newFieldB")
    assert_true(extended.argument_named(field, "test") != NO_TYPE)


def test_may_extend_mutations_and_subscriptions() raises:
    var schema = build_schema(
        """
      type Query {
        queryField: String
      }

      type Mutation {
        mutationField: String
      }

      type Subscription {
        subscriptionField: String
      }
    """
    )
    var original = print_schema(schema)
    var extended = extend(
        schema,
        """
      extend type Query {
        newQueryField: Int
      }

      extend type Mutation {
        newMutationField: Int
      }

      extend type Subscription {
        newSubscriptionField: Int
      }
    """,
    )
    assert_equal(print_schema(schema), original)
    assert_equal(
        print_schema(extended),
        dedent(
            """
      type Query {
        queryField: String
        newQueryField: Int
      }

      type Mutation {
        mutationField: String
        newMutationField: Int
      }

      type Subscription {
        subscriptionField: String
        newSubscriptionField: Int
      }
    """
        ),
    )


def test_may_extend_directives_with_new_directive() raises:
    var schema = build_schema("type Query {\n  foo: String\n}")
    var sdl = dedent(
        '''
      """New directive."""
      directive @new(enable: Boolean!, tag: String) repeatable on QUERY | FIELD
    '''
    )
    var extended = extend(schema, sdl)
    assert_equal(schema_changes(schema, extended), sdl)


def expect_error(schema: Schema, sdl: String, message: String) raises:
    """Assert that extending a schema with SDL raises a message."""
    try:
        _ = extend(schema, sdl)
    except error:
        assert_equal(String(error), message)
        return
    raise Error("expected an error")


def test_rejects_invalid_sdl() raises:
    expect_error(
        empty_schema(),
        "extend schema @unknown",
        'Unknown directive "@unknown".',
    )


def test_does_not_allow_replacing_a_default_directive() raises:
    expect_error(
        empty_schema(),
        "directive @include(if: Boolean!) on FIELD | FRAGMENT_SPREAD",
        'Directive "@include" already exists in the schema. It cannot be'
        + " redefined.",
    )


def test_does_not_allow_replacing_an_existing_enum_value() raises:
    var schema = build_schema("enum SomeEnum {\n  ONE\n}")
    expect_error(
        schema,
        "extend enum SomeEnum {\n  ONE\n}",
        'Enum value "SomeEnum.ONE" already exists in the schema. It cannot'
        + " also be defined in this type extension.",
    )


def test_allows_to_disable_sdl_validation() raises:
    var options = BuildOptions()
    options.assume_valid_sdl = True
    _ = extend_schema(empty_schema(), parse("extend schema @unknown"), options)


def test_throws_on_unknown_types() raises:
    var options = BuildOptions()
    options.assume_valid_sdl = True
    try:
        _ = extend_schema(
            empty_schema(),
            parse("type Query {\n  unknown: UnknownType\n}"),
            options,
        )
    except error:
        assert_equal(String(error), 'Unknown type: "UnknownType".')
        return
    raise Error("expected an error")


def test_does_not_automatically_include_common_root_type_names() raises:
    var extended = extend(empty_schema(), "type Mutation")
    assert_true(extended.type_named("Mutation") != NO_TYPE)
    assert_equal(extended.mutation_type, NO_TYPE)


def test_adds_schema_definition_missing_in_the_original_schema() raises:
    var schema = build_schema("directive @foo on SCHEMA\ntype Foo")
    assert_equal(schema.query_type, NO_TYPE)
    var sdl = String("schema @foo {\n  query: Foo\n}")
    var extended = extend(schema, sdl)
    assert_equal(extended.types[Int(extended.query_type)].name, "Foo")
    assert_equal(ast_node(extended, extended.schema_definition), sdl)
    assert_equal(extended.schema_directives.count, 1)


def test_adds_new_root_types_via_schema_extension() raises:
    var schema = build_schema("type Query\ntype MutationRoot")
    var sdl = String("extend schema {\n  mutation: MutationRoot\n}")
    var extended = extend(schema, sdl)
    assert_equal(
        extended.types[Int(extended.mutation_type)].name, "MutationRoot"
    )
    assert_equal(extension_nodes(extended, extended.schema_extensions), sdl)


def test_adds_directive_via_schema_extension() raises:
    var schema = build_schema("type Query\n\ndirective @foo on SCHEMA")
    var sdl = String("extend schema @foo")
    var extended = extend(schema, sdl)
    assert_equal(extension_nodes(extended, extended.schema_extensions), sdl)


def test_adds_multiple_new_root_types_via_schema_extension() raises:
    var schema = build_schema("type Query")
    var extended = extend(
        schema,
        """
        extend schema {
          mutation: Mutation
          subscription: Subscription
        }

        type Mutation
        type Subscription
    """,
    )
    assert_equal(extended.types[Int(extended.mutation_type)].name, "Mutation")
    assert_equal(
        extended.types[Int(extended.subscription_type)].name, "Subscription"
    )


comptime _TWO_SCHEMA_EXTENSIONS = """
        extend schema {
          mutation: Mutation
        }
        type Mutation

        extend schema {
          subscription: Subscription
        }
        type Subscription
    """


def test_applies_multiple_schema_extensions() raises:
    var schema = build_schema("type Query")
    var extended = extend(schema, _TWO_SCHEMA_EXTENSIONS)
    assert_equal(extended.types[Int(extended.mutation_type)].name, "Mutation")
    assert_equal(
        extended.types[Int(extended.subscription_type)].name, "Subscription"
    )


def test_schema_extension_ast_are_available_from_schema_object() raises:
    var schema = build_schema("type Query\n\ndirective @foo on SCHEMA")
    var extended = extend(schema, _TWO_SCHEMA_EXTENSIONS)
    var twice = extend(extended, "extend schema @foo")
    assert_equal(
        extension_nodes(twice, twice.schema_extensions),
        dedent(
            """
        extend schema {
          mutation: Mutation
        }

        extend schema {
          subscription: Subscription
        }

        extend schema @foo
      """
        ),
    )
    assert_equal(twice.schema_directives.count, 1)


def test_extend_directive_to_make_it_deprecated() raises:
    var schema = build_schema("directive @isDeprecated on FIELD_DEFINITION")
    var extended = extend_schema(
        schema,
        parse(
            (
                'extend directive @isDeprecated @deprecated(reason: "use'
                ' another directive")'
            ),
            experimental(),
        ),
    )
    ref directive = extended.directives[
        extended.directive_named("isDeprecated")
    ]
    assert_equal(directive.deprecation_reason, "use another directive")
    assert_equal(directive.extensions.count, 1)


def test_preserves_deprecated_directives_when_extending_other_types() raises:
    var options = BuildOptions()
    options.parse_options = experimental()
    var schema = build_schema(
        dedent(
            """
            type Query {
              foo: String
            }

            directive @isDeprecated @deprecated(reason: "use another directive") on FIELD_DEFINITION
          """
        ),
        options,
    )
    var extended = extend(schema, "extend type Query {\n  bar: Int\n}")
    ref directive = extended.directives[
        extended.directive_named("isDeprecated")
    ]
    assert_equal(directive.deprecation_reason, "use another directive")


def test_applies_directive_extensions_defined_in_the_same_document() raises:
    var options = BuildOptions()
    options.parse_options = experimental()
    var schema = build_schema(
        dedent(
            """
            directive @onDirective on DIRECTIVE_DEFINITION
            directive @someDirective on FIELD_DEFINITION

            extend directive @someDirective @onDirective
          """
        ),
        options,
    )
    ref directive = schema.directives[schema.directive_named("someDirective")]
    assert_equal(
        extension_nodes(schema, directive.extensions),
        "extend directive @someDirective @onDirective",
    )


def test_applies_multiple_directive_extensions_in_the_same_document() raises:
    var options = BuildOptions()
    options.parse_options = experimental()
    var schema = build_schema(
        dedent(
            """
            directive @onDirective on DIRECTIVE_DEFINITION
            directive @otherDirective on DIRECTIVE_DEFINITION
            directive @someDirective on FIELD_DEFINITION

            extend directive @someDirective @onDirective
            extend directive @someDirective @otherDirective
          """
        ),
        options,
    )
    ref directive = schema.directives[schema.directive_named("someDirective")]
    assert_equal(
        extension_nodes(schema, directive.extensions),
        (
            "extend directive @someDirective @onDirective\n\nextend directive"
            " @someDirective @otherDirective"
        ),
    )


def test_extend_directive_without_adding_new_directives_is_an_error() raises:
    try:
        _ = parse("extend directive @isDeprecated", experimental())
    except error:
        assert_true(String(error).startswith("Syntax Error: Unexpected <EOF>."))
        return
    raise Error("expected an error")


def test_redefined_type_replaces_references() raises:
    # With SDL validation off, graphql-js puts a redefined type in the place
    # of the old one, and `replaceNamedType` points the references at it.
    var options = BuildOptions()
    options.assume_valid_sdl = True
    var schema = build_schema(
        """
      type Query {
        foo(arg: Foo): Foo
        bar: [Bar!]
      }

      union Bar = Query

      scalar Foo
    """
    )
    var extended = extend_schema(
        schema,
        parse(
            """
      type Foo {
        field: String
      }
    """
        ),
        options,
    )
    assert_equal(
        print_schema(extended),
        dedent(
            """
      type Query {
        foo(arg: Foo): Foo
        bar: [Bar!]
      }

      union Bar = Query

      type Foo {
        field: String
      }
    """
        ),
    )
    assert_false(extended.type_named("Foo") == schema.type_named("Foo"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
