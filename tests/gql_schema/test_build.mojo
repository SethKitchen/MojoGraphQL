# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.build` and `gql_schema.print`, ported from
graphql-js 16.14.2 `src/utilities/__tests__/buildASTSchema-test.ts`.

`cycle_sdl` is graphql-js `cycleSDL`: build, then print. The execution
tests ("can use built schema for limited execution") belong to the
execution package. "Rejects invalid AST" checks a JavaScript type
error, which Mojo's types rule out.
"""

from _helpers import dedent
from gql_language.ast import Document, Role
from gql_language.parser import ParseOptions, parse
from gql_language.printer import print_node
from gql_schema.build import BuildOptions, build_ast_schema, build_schema
from gql_schema.definition import NO_TYPE, Schema, TypeKind
from gql_schema.print import print_schema, print_type
from gql_schema.validate import validate_schema
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def cycle_sdl(sdl: String) raises -> String:
    """Build a schema from SDL and print it back, as `cycleSDL`."""
    return print_schema(build_schema(sdl))


def expect_cycle(sdl: String) raises:
    """Assert that SDL prints back unchanged."""
    var text = dedent(sdl)
    assert_equal(cycle_sdl(text), text)


def type_names(schema: Schema) -> String:
    """Return the type map's names, space separated."""
    var out = String("")
    for index in range(len(schema.type_map)):
        if index > 0:
            out += " "
        out += schema.types[Int(schema.type_map[index])].name
    return out^


def directive_names(schema: Schema) -> String:
    """Return the directives' names, space separated."""
    var out = String("")
    for index in range(len(schema.directives)):
        if index > 0:
            out += " "
        out += schema.directives[index].name
    return out^


def ast_node(schema: Schema, document: Int, node: Int) -> String:
    """Print one node of a schema document."""
    return print_node(schema.documents[document], node)


def extension_nodes(schema: Schema, type: Int) -> String:
    """Print a type's extension nodes, as `expectExtensionASTNodes`."""
    var out = String("")
    ref span = schema.types[type].extensions
    for index in range(Int(span.start), span.end()):
        if index > Int(span.start):
            out += "\n\n"
        var at = schema.ast_refs[index]
        out += ast_node(schema, Int(at.document), Int(at.node))
    return out^


def definition_node(schema: Schema, type: Int) -> String:
    """Print a type's definition node, as `expectASTNode`."""
    var at = schema.types[type].definition
    return ast_node(schema, Int(at.document), Int(at.node))


def test_ignores_non_type_system_definitions() raises:
    _ = build_schema(
        "type Query {\n  str: String\n}\n\nfragment SomeFragment on Query {\n"
        "  str\n}"
    )


def test_match_order_of_default_types_and_directives() raises:
    var schema = build_ast_schema(List[Document]())
    assert_equal(
        type_names(schema),
        (
            "Boolean String __Schema __Type __TypeKind __Field __InputValue"
            " __EnumValue __Directive __DirectiveLocation"
        ),
    )
    assert_equal(
        directive_names(schema), "include skip deprecated specifiedBy oneOf"
    )


def test_empty_type() raises:
    expect_cycle("type EmptyType")


def test_simple_type() raises:
    var sdl = """
      type Query {
        str: String
        int: Int
        float: Float
        id: ID
        bool: Boolean
      }
    """
    expect_cycle(sdl)
    var schema = build_schema(dedent(sdl))
    var names: List[String] = ["Int", "Float", "String", "Boolean", "ID"]
    for ref name in names:
        assert_true(schema.types[schema.type_named(name)].is_builtin)


def test_include_standard_type_only_if_it_is_used() raises:
    var schema = build_schema("type Query")
    assert_equal(schema.type_named("Int"), NO_TYPE)
    assert_equal(schema.type_named("Float"), NO_TYPE)
    assert_equal(schema.type_named("ID"), NO_TYPE)


def test_with_directives() raises:
    expect_cycle(
        """
      directive @foo(arg: Int) on FIELD

      directive @repeatableFoo(arg: Int) repeatable on FIELD
    """
    )


def test_supports_descriptions() raises:
    expect_cycle(
        '''
      """Do you agree that this is the most creative schema ever?"""
      schema {
        query: Query
      }

      """This is a directive"""
      directive @foo(
        """It has an argument"""
        arg: Int
      ) on FIELD

      """Who knows what inside this scalar?"""
      scalar MysteryScalar

      """This is a input object type"""
      input FooInput {
        """It has a field"""
        field: Int
      }

      """This is a interface type"""
      interface Energy {
        """It also has a field"""
        str: String
      }

      """There is nothing inside!"""
      union BlackHole

      """With an enum"""
      enum Color {
        RED

        """Not a creative color"""
        GREEN
        BLUE
      }

      """What a great type"""
      type Query {
        """And a field to boot"""
        str: String
      }
    '''
    )


def test_maintains_include_skip_and_specified_by() raises:
    var schema = build_schema("type Query")
    assert_equal(len(schema.directives), 5)
    var names: List[String] = [
        "skip",
        "include",
        "deprecated",
        "specifiedBy",
        "oneOf",
    ]
    for ref name in names:
        assert_true(schema.directives[schema.directive_named(name)].is_builtin)


def test_overriding_directives_excludes_specified() raises:
    var schema = build_schema(
        """
      directive @skip on FIELD
      directive @include on FIELD
      directive @deprecated on FIELD_DEFINITION
      directive @specifiedBy on FIELD_DEFINITION
      directive @oneOf on OBJECT
    """
    )
    assert_equal(len(schema.directives), 5)
    for index in range(5):
        assert_false(schema.directives[index].is_builtin)


def test_adding_directives_maintains_the_specified_ones() raises:
    var schema = build_schema("directive @foo(arg: Int) on FIELD")
    assert_equal(len(schema.directives), 6)
    assert_equal(
        directive_names(schema), "foo include skip deprecated specifiedBy oneOf"
    )


def test_type_modifiers() raises:
    expect_cycle(
        """
      type Query {
        nonNullStr: String!
        listOfStrings: [String]
        listOfNonNullStrings: [String!]
        nonNullListOfStrings: [String]!
        nonNullListOfNonNullStrings: [String!]!
      }
    """
    )


def test_recursive_type() raises:
    expect_cycle(
        """
      type Query {
        str: String
        recurse: Query
      }
    """
    )


def test_two_types_circular() raises:
    expect_cycle(
        """
      type TypeOne {
        str: String
        typeTwo: TypeTwo
      }

      type TypeTwo {
        str: String
        typeOne: TypeOne
      }
    """
    )


def test_single_argument_field() raises:
    expect_cycle(
        """
      type Query {
        str(int: Int): String
        floatToStr(float: Float): String
        idToStr(id: ID): String
        booleanToStr(bool: Boolean): String
        strToStr(bool: String): String
      }
    """
    )


def test_simple_type_with_multiple_arguments() raises:
    expect_cycle(
        """
      type Query {
        str(int: Int, bool: Boolean): String
      }
    """
    )


def test_empty_interface() raises:
    var document = parse("interface EmptyInterface")
    var definition = document.definitions()[0]
    assert_equal(document.count(definition, Role.INTERFACE), 0)
    expect_cycle("interface EmptyInterface")


def test_simple_type_with_interface() raises:
    expect_cycle(
        """
      type Query implements WorldInterface {
        str: String
      }

      interface WorldInterface {
        str: String
      }
    """
    )


def test_simple_interface_hierarchy() raises:
    expect_cycle(
        """
      schema {
        query: Child
      }

      interface Child implements Parent {
        str: String
      }

      type Hello implements Parent & Child {
        str: String
      }

      interface Parent {
        str: String
      }
    """
    )


def test_empty_enum() raises:
    expect_cycle("enum EmptyEnum")


def test_simple_output_enum() raises:
    expect_cycle(
        """
      enum Hello {
        WORLD
      }

      type Query {
        hello: Hello
      }
    """
    )


def test_simple_input_enum() raises:
    expect_cycle(
        """
      enum Hello {
        WORLD
      }

      type Query {
        str(hello: Hello): String
      }
    """
    )


def test_multiple_value_enum() raises:
    expect_cycle(
        """
      enum Hello {
        WO
        RLD
      }

      type Query {
        hello: Hello
      }
    """
    )


def test_empty_union() raises:
    expect_cycle("union EmptyUnion")


def test_simple_union() raises:
    expect_cycle(
        """
      union Hello = World

      type Query {
        hello: Hello
      }

      type World {
        str: String
      }
    """
    )


def test_multiple_union() raises:
    expect_cycle(
        """
      union Hello = WorldOne | WorldTwo

      type Query {
        hello: Hello
      }

      type WorldOne {
        str: String
      }

      type WorldTwo {
        str: String
      }
    """
    )


def test_custom_scalar() raises:
    expect_cycle(
        """
      scalar CustomScalar

      type Query {
        customScalar: CustomScalar
      }
    """
    )


def test_empty_input_object() raises:
    expect_cycle("input EmptyInputObject")


def test_simple_input_object() raises:
    expect_cycle(
        """
      input Input {
        int: Int
      }

      type Query {
        field(in: Input): String
      }
    """
    )


def test_simple_argument_field_with_default() raises:
    expect_cycle(
        """
      type Query {
        str(int: Int = 2): String
      }
    """
    )


def test_custom_scalar_argument_field_with_default() raises:
    expect_cycle(
        """
      scalar CustomScalar

      type Query {
        str(int: CustomScalar = 2): String
      }
    """
    )


def test_simple_type_with_mutation() raises:
    expect_cycle(
        """
      schema {
        query: HelloScalars
        mutation: Mutation
      }

      type HelloScalars {
        str: String
        int: Int
        bool: Boolean
      }

      type Mutation {
        addHelloScalars(str: String, int: Int, bool: Boolean): HelloScalars
      }
    """
    )


def test_simple_type_with_subscription() raises:
    expect_cycle(
        """
      schema {
        query: HelloScalars
        subscription: Subscription
      }

      type HelloScalars {
        str: String
        int: Int
        bool: Boolean
      }

      type Subscription {
        subscribeHelloScalars(str: String, int: Int, bool: Boolean): HelloScalars
      }
    """
    )


def test_unreferenced_type_implementing_referenced_interface() raises:
    expect_cycle(
        """
      type Concrete implements Interface {
        key: String
      }

      interface Interface {
        key: String
      }

      type Query {
        interface: Interface
      }
    """
    )


def test_unreferenced_interface_implementing_referenced_interface() raises:
    expect_cycle(
        """
      interface Child implements Parent {
        key: String
      }

      interface Parent {
        key: String
      }

      type Query {
        interfaceField: Parent
      }
    """
    )


def test_unreferenced_type_implementing_referenced_union() raises:
    expect_cycle(
        """
      type Concrete {
        key: String
      }

      type Query {
        union: Union
      }

      union Union = Concrete
    """
    )


def test_supports_deprecated() raises:
    var sdl = """
      enum MyEnum {
        VALUE
        OLD_VALUE @deprecated
        OTHER_VALUE @deprecated(reason: "Terrible reasons")
      }

      input MyInput {
        oldInput: String @deprecated
        otherInput: String @deprecated(reason: "Use newInput")
        newInput: String
      }

      type Query {
        field1: String @deprecated
        field2: Int @deprecated(reason: "Because I said so")
        enum: MyEnum
        field3(oldArg: String @deprecated, arg: String): String
        field4(oldArg: String @deprecated(reason: "Why not?"), arg: String): String
        field5(arg: MyInput): String
      }
    """
    expect_cycle(sdl)
    var schema = build_schema(dedent(sdl))
    var my_enum = schema.type_named("MyEnum")
    ref value = schema.enum_values[schema.enum_value_named(my_enum, "VALUE")]
    assert_false(value.is_deprecated)
    ref old_value = schema.enum_values[
        schema.enum_value_named(my_enum, "OLD_VALUE")
    ]
    assert_equal(old_value.deprecation_reason, "No longer supported")
    ref other_value = schema.enum_values[
        schema.enum_value_named(my_enum, "OTHER_VALUE")
    ]
    assert_equal(other_value.deprecation_reason, "Terrible reasons")
    var query = schema.type_named("Query")
    ref field1 = schema.fields[schema.field_named(query, "field1")]
    assert_equal(field1.deprecation_reason, "No longer supported")
    ref field2 = schema.fields[schema.field_named(query, "field2")]
    assert_equal(field2.deprecation_reason, "Because I said so")
    var my_input = schema.type_named("MyInput")
    ref new_input = schema.input_values[
        schema.input_field_named(my_input, "newInput")
    ]
    assert_false(new_input.is_deprecated)
    ref old_input = schema.input_values[
        schema.input_field_named(my_input, "oldInput")
    ]
    assert_equal(old_input.deprecation_reason, "No longer supported")
    ref other_input = schema.input_values[
        schema.input_field_named(my_input, "otherInput")
    ]
    assert_equal(other_input.deprecation_reason, "Use newInput")
    var field3 = schema.field_named(query, "field3")
    ref field3_old_arg = schema.input_values[
        Int(schema.fields[field3].arguments.start)
    ]
    assert_equal(field3_old_arg.deprecation_reason, "No longer supported")
    var field4 = schema.field_named(query, "field4")
    ref field4_old_arg = schema.input_values[
        Int(schema.fields[field4].arguments.start)
    ]
    assert_equal(field4_old_arg.deprecation_reason, "Why not?")


def test_supports_specified_by() raises:
    var sdl = """
      scalar Foo @specifiedBy(url: "https://example.com/foo_spec")

      type Query {
        foo: Foo @deprecated
      }
    """
    expect_cycle(sdl)
    var schema = build_schema(dedent(sdl))
    ref foo = schema.types[schema.type_named("Foo")]
    assert_equal(foo.specified_by_url, "https://example.com/foo_spec")


def test_correctly_extend_scalar_type() raises:
    var schema = build_schema(
        """
      scalar SomeScalar
      extend scalar SomeScalar @foo
      extend scalar SomeScalar @bar

      directive @foo on SCALAR
      directive @bar on SCALAR
    """
    )
    var some_scalar = schema.type_named("SomeScalar")
    assert_equal(print_type(schema, some_scalar), "scalar SomeScalar")
    assert_equal(definition_node(schema, some_scalar), "scalar SomeScalar")
    assert_equal(
        extension_nodes(schema, some_scalar),
        "extend scalar SomeScalar @foo\n\nextend scalar SomeScalar @bar",
    )


def test_correctly_extend_object_type() raises:
    var schema = build_schema(
        """
      type SomeObject implements Foo {
        first: String
      }

      extend type SomeObject implements Bar {
        second: Int
      }

      extend type SomeObject implements Baz {
        third: Float
      }

      interface Foo
      interface Bar
      interface Baz
    """
    )
    var some_object = schema.type_named("SomeObject")
    assert_equal(
        print_type(schema, some_object),
        dedent(
            """
      type SomeObject implements Foo & Bar & Baz {
        first: String
        second: Int
        third: Float
      }
    """
        ),
    )
    assert_equal(
        definition_node(schema, some_object),
        "type SomeObject implements Foo {\n  first: String\n}",
    )
    assert_equal(
        extension_nodes(schema, some_object),
        "extend type SomeObject implements Bar {\n  second: Int\n}\n\n"
        + "extend type SomeObject implements Baz {\n  third: Float\n}",
    )


def test_correctly_extend_interface_type() raises:
    var schema = build_schema(
        dedent(
            """
      interface SomeInterface {
        first: String
      }

      extend interface SomeInterface {
        second: Int
      }

      extend interface SomeInterface {
        third: Float
      }
    """
        )
    )
    var some_interface = schema.type_named("SomeInterface")
    assert_equal(
        print_type(schema, some_interface),
        (
            "interface SomeInterface {\n  first: String\n  second: Int\n "
            " third: Float\n}"
        ),
    )
    assert_equal(
        definition_node(schema, some_interface),
        "interface SomeInterface {\n  first: String\n}",
    )
    assert_equal(
        extension_nodes(schema, some_interface),
        "extend interface SomeInterface {\n  second: Int\n}\n\n"
        + "extend interface SomeInterface {\n  third: Float\n}",
    )


def test_correctly_extend_union_type() raises:
    var schema = build_schema(
        """
      union SomeUnion = FirstType
      extend union SomeUnion = SecondType
      extend union SomeUnion = ThirdType

      type FirstType
      type SecondType
      type ThirdType
    """
    )
    var some_union = schema.type_named("SomeUnion")
    assert_equal(
        print_type(schema, some_union),
        "union SomeUnion = FirstType | SecondType | ThirdType",
    )
    assert_equal(
        definition_node(schema, some_union), "union SomeUnion = FirstType"
    )
    assert_equal(
        extension_nodes(schema, some_union),
        (
            "extend union SomeUnion = SecondType\n\nextend union SomeUnion ="
            " ThirdType"
        ),
    )


def test_correctly_extend_enum_type() raises:
    var schema = build_schema(
        dedent(
            """
      enum SomeEnum {
        FIRST
      }

      extend enum SomeEnum {
        SECOND
      }

      extend enum SomeEnum {
        THIRD
      }
    """
        )
    )
    var some_enum = schema.type_named("SomeEnum")
    assert_equal(
        print_type(schema, some_enum),
        "enum SomeEnum {\n  FIRST\n  SECOND\n  THIRD\n}",
    )
    assert_equal(
        definition_node(schema, some_enum), "enum SomeEnum {\n  FIRST\n}"
    )
    assert_equal(
        extension_nodes(schema, some_enum),
        (
            "extend enum SomeEnum {\n  SECOND\n}\n\nextend enum SomeEnum {\n "
            " THIRD\n}"
        ),
    )


def test_correctly_extend_input_object_type() raises:
    var schema = build_schema(
        dedent(
            """
      input SomeInput {
        first: String
      }

      extend input SomeInput {
        second: Int
      }

      extend input SomeInput {
        third: Float
      }
    """
        )
    )
    var some_input = schema.type_named("SomeInput")
    assert_equal(
        print_type(schema, some_input),
        "input SomeInput {\n  first: String\n  second: Int\n  third: Float\n}",
    )
    assert_equal(
        definition_node(schema, some_input),
        "input SomeInput {\n  first: String\n}",
    )
    assert_equal(
        extension_nodes(schema, some_input),
        (
            "extend input SomeInput {\n  second: Int\n}\n\nextend input"
            " SomeInput {\n  third: Float\n}"
        ),
    )


def test_correctly_assign_ast_nodes() raises:
    var sdl = dedent(
        """
      schema {
        query: Query
      }

      type Query {
        testField(testArg: TestInput): TestUnion
      }

      input TestInput {
        testInputField: TestEnum
      }

      enum TestEnum {
        TEST_VALUE
      }

      union TestUnion = TestType

      interface TestInterface {
        interfaceField: String
      }

      type TestType implements TestInterface {
        interfaceField: String
      }

      scalar TestScalar

      directive @test(arg: TestScalar) on FIELD
    """
    )
    var schema = build_schema(sdl)
    var document = parse(sdl)
    var definitions = document.definitions()
    var names: List[String] = [
        "Query",
        "TestInput",
        "TestEnum",
        "TestUnion",
        "TestInterface",
        "TestType",
        "TestScalar",
    ]
    assert_equal(schema.schema_definition.node, Int32(definitions[0]))
    for index in range(len(names)):
        ref named = schema.types[schema.type_named(names[index])]
        assert_equal(named.definition.node, Int32(definitions[index + 1]))
        assert_equal(named.definition.document, 1)
    var test_directive = schema.directive_named("test")
    assert_equal(
        schema.directives[test_directive].definition.node, Int32(definitions[8])
    )
    var query = schema.type_named("Query")
    ref test_field = schema.fields[schema.field_named(query, "testField")]
    assert_equal(
        ast_node(schema, 1, Int(test_field.definition.node)),
        "testField(testArg: TestInput): TestUnion",
    )
    ref test_arg = schema.input_values[Int(test_field.arguments.start)]
    assert_equal(
        ast_node(schema, 1, Int(test_arg.definition.node)), "testArg: TestInput"
    )
    var test_input = schema.type_named("TestInput")
    ref input_field = schema.input_values[
        schema.input_field_named(test_input, "testInputField")
    ]
    assert_equal(
        ast_node(schema, 1, Int(input_field.definition.node)),
        "testInputField: TestEnum",
    )
    var test_enum = schema.type_named("TestEnum")
    ref enum_value = schema.enum_values[
        schema.enum_value_named(test_enum, "TEST_VALUE")
    ]
    assert_equal(
        ast_node(schema, 1, Int(enum_value.definition.node)), "TEST_VALUE"
    )
    var test_interface = schema.type_named("TestInterface")
    ref interface_field = schema.fields[
        schema.field_named(test_interface, "interfaceField")
    ]
    assert_equal(
        ast_node(schema, 1, Int(interface_field.definition.node)),
        "interfaceField: String",
    )
    var test_type = schema.type_named("TestType")
    ref type_field = schema.fields[
        schema.field_named(test_type, "interfaceField")
    ]
    assert_equal(
        ast_node(schema, 1, Int(type_field.definition.node)),
        "interfaceField: String",
    )
    ref directive_arg = schema.input_values[
        Int(schema.directives[test_directive].arguments.start)
    ]
    assert_equal(
        ast_node(schema, 1, Int(directive_arg.definition.node)),
        "arg: TestScalar",
    )


def test_root_operation_types_with_custom_names() raises:
    var schema = build_schema(
        """
      schema {
        query: SomeQuery
        mutation: SomeMutation
        subscription: SomeSubscription
      }
      type SomeQuery
      type SomeMutation
      type SomeSubscription
    """
    )
    assert_equal(schema.types[Int(schema.query_type)].name, "SomeQuery")
    assert_equal(schema.types[Int(schema.mutation_type)].name, "SomeMutation")
    assert_equal(
        schema.types[Int(schema.subscription_type)].name, "SomeSubscription"
    )


def test_default_root_operation_type_names() raises:
    var schema = build_schema(
        """
      type Query
      type Mutation
      type Subscription
    """
    )
    assert_equal(schema.types[Int(schema.query_type)].name, "Query")
    assert_equal(schema.types[Int(schema.mutation_type)].name, "Mutation")
    assert_equal(
        schema.types[Int(schema.subscription_type)].name, "Subscription"
    )


def test_do_not_override_standard_types() raises:
    var schema = build_schema("scalar ID\n\nscalar __Schema")
    assert_true(schema.types[schema.type_named("ID")].is_builtin)
    ref schema_type = schema.types[schema.type_named("__Schema")]
    assert_true(schema_type.is_builtin)
    assert_equal(schema_type.kind, TypeKind.OBJECT)


def test_allows_to_reference_introspection_types() raises:
    var schema = build_schema(
        """
      type Query {
        introspectionField: __EnumValue
      }
    """
    )
    var query = schema.type_named("Query")
    ref field = schema.fields[schema.field_named(query, "introspectionField")]
    var enum_value = schema.type_named("__EnumValue")
    assert_equal(Int(field.type.named), enum_value)
    assert_true(schema.types[enum_value].is_builtin)


def test_can_build_recursive_union() raises:
    var schema = build_schema(
        """
      union Hello = Hello

      type Query {
        hello: Hello
      }
    """
    )
    assert_true(len(validate_schema(schema)) > 0)


def test_can_build_invalid_schema() raises:
    # Invalid, because the query root type is missing.
    var schema = build_schema("type Mutation")
    assert_true(len(validate_schema(schema)) > 0)


def test_rejects_invalid_sdl() raises:
    try:
        _ = build_schema("type Query {\n  foo: String @unknown\n}")
    except error:
        assert_equal(String(error), 'Unknown directive "@unknown".')
        return
    raise Error("expected an error")


def test_allows_to_disable_sdl_validation() raises:
    var options = BuildOptions()
    options.assume_valid_sdl = True
    _ = build_schema("type Query {\n  foo: String @unknown\n}", options)


def test_forwards_parser_options_to_build_schema() raises:
    var options = BuildOptions()
    options.parse_options.experimental_directives_on_directive_definitions = (
        True
    )
    var schema = build_schema(
        dedent(
            """
        type Query {
          foo: String
        }

        directive @bar @deprecated(reason: "Use another directive") on FIELD_DEFINITION
      """
        ),
        options,
    )
    ref bar = schema.directives[schema.directive_named("bar")]
    assert_equal(bar.deprecation_reason, "Use another directive")


def test_throws_on_unknown_types() raises:
    var options = BuildOptions()
    options.assume_valid_sdl = True
    try:
        _ = build_schema("type Query {\n  unknown: UnknownType\n}", options)
    except error:
        assert_equal(String(error), 'Unknown type: "UnknownType".')
        return
    raise Error("expected an error")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
