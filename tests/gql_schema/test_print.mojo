# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_schema.print`, ported from graphql-js 16.14.2
`src/utilities/__tests__/printSchema-test.ts`.

graphql-js builds most of these schemas with the type constructors. This
package builds schemas from SDL only, so each test builds the SDL that
the constructors describe. `expect_printed` keeps the upstream check that
printing and building agree: the SDL prints back unchanged.
"""

from _helpers import dedent
from gql_language.ast import Document
from gql_schema.build import BuildOptions, build_ast_schema, build_schema
from gql_schema.print import print_introspection_schema, print_schema
from std.testing import TestSuite, assert_equal


def expect_printed(sdl: String) raises:
    """Assert that a schema built from SDL prints the same SDL, as
    `expectPrintedSchema`."""
    var text = dedent(sdl)
    var printed = print_schema(build_schema(text))
    assert_equal(printed, text)
    assert_equal(print_schema(build_schema(printed)), printed)


def single_field(field: String) raises:
    """Assert the print of a Query type with one field, as
    `buildSingleFieldSchema`."""
    expect_printed("type Query {\n  " + field + "\n}")


def test_prints_string_field() raises:
    single_field("singleField: String")


def test_prints_list_of_string_field() raises:
    single_field("singleField: [String]")


def test_prints_non_null_string_field() raises:
    single_field("singleField: String!")


def test_prints_non_null_list_of_string_field() raises:
    single_field("singleField: [String]!")


def test_prints_list_of_non_null_string_field() raises:
    single_field("singleField: [String!]")


def test_prints_non_null_list_of_non_null_string_field() raises:
    single_field("singleField: [String!]!")


def test_print_object_field() raises:
    expect_printed(
        """
      type Foo {
        str: String
      }
    """
    )


def test_prints_string_field_with_int_arg() raises:
    single_field("singleField(argOne: Int): String")


def test_prints_string_field_with_int_arg_with_default() raises:
    single_field("singleField(argOne: Int = 2): String")


def test_prints_string_field_with_string_arg_with_default() raises:
    single_field('singleField(argOne: String = "tes\\t de\\fault"): String')


def test_prints_string_field_with_int_arg_with_default_null() raises:
    single_field("singleField(argOne: Int = null): String")


def test_prints_string_field_with_non_null_int_arg() raises:
    single_field("singleField(argOne: Int!): String")


def test_prints_string_field_with_multiple_args() raises:
    single_field("singleField(argOne: Int, argTwo: String): String")


def test_prints_multiple_args_first_is_default() raises:
    single_field(
        "singleField(argOne: Int = 1, argTwo: String, argThree: Boolean):"
        " String"
    )


def test_prints_multiple_args_second_is_default() raises:
    single_field(
        'singleField(argOne: Int, argTwo: String = "foo", argThree: Boolean):'
        " String"
    )


def test_prints_multiple_args_last_is_default() raises:
    single_field(
        "singleField(argOne: Int, argTwo: String, argThree: Boolean = false):"
        " String"
    )


def test_prints_schema_with_description() raises:
    expect_printed(
        '''
      """Schema description."""
      schema {
        query: Query
      }

      type Query
    '''
    )


def test_omits_schema_of_common_names() raises:
    expect_printed(
        """
      type Query

      type Mutation

      type Subscription
    """
    )


def test_prints_custom_query_root_types() raises:
    expect_printed(
        """
      schema {
        query: CustomType
      }

      type CustomType
    """
    )


def test_prints_custom_mutation_root_types() raises:
    expect_printed(
        """
      schema {
        mutation: CustomType
      }

      type CustomType
    """
    )


def test_prints_custom_subscription_root_types() raises:
    expect_printed(
        """
      schema {
        subscription: CustomType
      }

      type CustomType
    """
    )


def test_print_interface() raises:
    expect_printed(
        """
      type Bar implements Foo {
        str: String
      }

      interface Foo {
        str: String
      }
    """
    )


def test_print_multiple_interface() raises:
    expect_printed(
        """
      type Bar implements Foo & Baz {
        str: String
        int: Int
      }

      interface Foo {
        str: String
      }

      interface Baz {
        int: Int
      }
    """
    )


def test_print_hierarchical_interface() raises:
    expect_printed(
        """
      type Bar implements Foo & Baz {
        str: String
        int: Int
      }

      interface Foo {
        str: String
      }

      interface Baz implements Foo {
        int: Int
        str: String
      }

      type Query {
        bar: Bar
      }
    """
    )


def test_print_unions() raises:
    expect_printed(
        """
      union SingleUnion = Foo

      type Foo {
        bool: Boolean
      }

      union MultipleUnion = Foo | Bar

      type Bar {
        str: String
      }
    """
    )


def test_print_input_type() raises:
    expect_printed(
        """
      input InputType {
        int: Int
      }
    """
    )


def test_print_input_type_with_one_of_directive() raises:
    expect_printed(
        """
      input InputType @oneOf {
        int: Int
      }
    """
    )


def test_custom_scalar() raises:
    expect_printed("scalar Odd")


def test_custom_scalar_with_specified_by_url() raises:
    expect_printed(
        'scalar Foo @specifiedBy(url: "https://example.com/foo_spec")'
    )


def test_enum() raises:
    expect_printed(
        """
      enum RGB {
        RED
        GREEN
        BLUE
      }
    """
    )


def test_prints_empty_types() raises:
    expect_printed(
        """
      enum SomeEnum

      input SomeInputObject

      interface SomeInterface

      type SomeObject

      union SomeUnion
    """
    )


def test_prints_custom_directives() raises:
    expect_printed(
        '''
      directive @simpleDirective on FIELD

      """Complex Directive"""
      directive @complexDirective(stringArg: String, intArg: Int = -1) repeatable on FIELD | QUERY
    '''
    )


def test_prints_deprecated_directives() raises:
    var options = BuildOptions()
    options.parse_options.experimental_directives_on_directive_definitions = (
        True
    )
    var sdl = String(
        'directive @deprecatedDirective @deprecated(reason: "Use another'
        ' directive") on FIELD'
    )
    assert_equal(print_schema(build_schema(sdl, options)), sdl)


def test_prints_an_empty_description() raises:
    expect_printed(
        '''
      type Query {
        """"""
        singleField: String
      }
    '''
    )


def test_prints_a_description_with_only_whitespace() raises:
    expect_printed(
        """
      type Query {
        " "
        singleField: String
      }
    """
    )


def test_one_line_prints_a_short_description() raises:
    expect_printed(
        '''
      type Query {
        """This field is awesome"""
        singleField: String
      }
    '''
    )


def test_prints_described_arguments() raises:
    expect_printed(
        '''
      directive @foo(
        """First"""
        one: Int

        """Second"""
        two: Int
      ) on FIELD

      type Query {
        field(
          """First"""
          one: Int
          two: Int
        ): String
      }
    '''
    )


def test_print_introspection_schema() raises:
    var schema = build_ast_schema(List[Document]())
    assert_equal(print_introspection_schema(schema), INTROSPECTION_SDL)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()


# The print of graphql-js `printIntrospectionSchema(new GraphQLSchema({}))`.
comptime INTROSPECTION_SDL = '''"""
Directs the executor to include this field or fragment only when the `if` argument is true.
"""
directive @include(
  """Included when true."""
  if: Boolean!
) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

"""
Directs the executor to skip this field or fragment when the `if` argument is true.
"""
directive @skip(
  """Skipped when true."""
  if: Boolean!
) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

"""Marks an element of a GraphQL schema as no longer supported."""
directive @deprecated(
  """
  Explains why this element was deprecated, usually also including a suggestion for how to access supported similar data. Formatted using the Markdown syntax, as specified by [CommonMark](https://commonmark.org/).
  """
  reason: String = "No longer supported"
) on FIELD_DEFINITION | ARGUMENT_DEFINITION | INPUT_FIELD_DEFINITION | ENUM_VALUE | DIRECTIVE_DEFINITION

"""Exposes a URL that specifies the behavior of this scalar."""
directive @specifiedBy(
  """The URL that specifies the behavior of this scalar."""
  url: String!
) on SCALAR

"""
Indicates exactly one field must be supplied and this field must not be `null`.
"""
directive @oneOf on INPUT_OBJECT

"""
A GraphQL Schema defines the capabilities of a GraphQL server. It exposes all available types and directives on the server, as well as the entry points for query, mutation, and subscription operations.
"""
type __Schema {
  description: String

  """A list of all types supported by this server."""
  types: [__Type!]!

  """The type that query operations will be rooted at."""
  queryType: __Type!

  """
  If this server supports mutation, the type that mutation operations will be rooted at.
  """
  mutationType: __Type

  """
  If this server support subscription, the type that subscription operations will be rooted at.
  """
  subscriptionType: __Type

  """A list of all directives supported by this server."""
  directives(includeDeprecated: Boolean! = false): [__Directive!]!
}

"""
The fundamental unit of any GraphQL Schema is the type. There are many kinds of types in GraphQL as represented by the `__TypeKind` enum.

Depending on the kind of a type, certain fields describe information about that type. Scalar types provide no information beyond a name, description and optional `specifiedByURL`, while Enum types provide their values. Object and Interface types provide the fields they describe. Abstract types, Union and Interface, provide the Object types possible at runtime. List and NonNull types compose other types.
"""
type __Type {
  kind: __TypeKind!
  name: String
  description: String
  specifiedByURL: String
  fields(includeDeprecated: Boolean = false): [__Field!]
  interfaces: [__Type!]
  possibleTypes: [__Type!]
  enumValues(includeDeprecated: Boolean = false): [__EnumValue!]
  inputFields(includeDeprecated: Boolean = false): [__InputValue!]
  ofType: __Type
  isOneOf: Boolean
}

"""An enum describing what kind of type a given `__Type` is."""
enum __TypeKind {
  """Indicates this type is a scalar."""
  SCALAR

  """
  Indicates this type is an object. `fields` and `interfaces` are valid fields.
  """
  OBJECT

  """
  Indicates this type is an interface. `fields`, `interfaces`, and `possibleTypes` are valid fields.
  """
  INTERFACE

  """Indicates this type is a union. `possibleTypes` is a valid field."""
  UNION

  """Indicates this type is an enum. `enumValues` is a valid field."""
  ENUM

  """
  Indicates this type is an input object. `inputFields` is a valid field.
  """
  INPUT_OBJECT

  """Indicates this type is a list. `ofType` is a valid field."""
  LIST

  """Indicates this type is a non-null. `ofType` is a valid field."""
  NON_NULL
}

"""
Object and Interface types are described by a list of Fields, each of which has a name, potentially a list of arguments, and a return type.
"""
type __Field {
  name: String!
  description: String
  args(includeDeprecated: Boolean = false): [__InputValue!]!
  type: __Type!
  isDeprecated: Boolean!
  deprecationReason: String
}

"""
Arguments provided to Fields or Directives and the input fields of an InputObject are represented as Input Values which describe their type and optionally a default value.
"""
type __InputValue {
  name: String!
  description: String
  type: __Type!

  """
  A GraphQL-formatted string representing the default value for this input value.
  """
  defaultValue: String
  isDeprecated: Boolean!
  deprecationReason: String
}

"""
One possible value for a given Enum. Enum values are unique values, not a placeholder for a string or numeric value. However an Enum value is returned in a JSON response as a string.
"""
type __EnumValue {
  name: String!
  description: String
  isDeprecated: Boolean!
  deprecationReason: String
}

"""
A Directive provides a way to describe alternate runtime execution and type validation behavior in a GraphQL document.

In some cases, you need to provide options to alter GraphQL's execution behavior in ways field arguments will not suffice, such as conditionally including or skipping a field. Directives provide this by describing additional information to the executor.
"""
type __Directive {
  name: String!
  description: String
  isRepeatable: Boolean!
  locations: [__DirectiveLocation!]!
  args(includeDeprecated: Boolean = false): [__InputValue!]!
  isDeprecated: Boolean!
  deprecationReason: String
}

"""
A Directive can be adjacent to many parts of the GraphQL language, a __DirectiveLocation describes one such possible adjacencies.
"""
enum __DirectiveLocation {
  """Location adjacent to a query operation."""
  QUERY

  """Location adjacent to a mutation operation."""
  MUTATION

  """Location adjacent to a subscription operation."""
  SUBSCRIPTION

  """Location adjacent to a field."""
  FIELD

  """Location adjacent to a fragment definition."""
  FRAGMENT_DEFINITION

  """Location adjacent to a fragment spread."""
  FRAGMENT_SPREAD

  """Location adjacent to an inline fragment."""
  INLINE_FRAGMENT

  """Location adjacent to a variable definition."""
  VARIABLE_DEFINITION

  """Location adjacent to a schema definition."""
  SCHEMA

  """Location adjacent to a scalar definition."""
  SCALAR

  """Location adjacent to an object type definition."""
  OBJECT

  """Location adjacent to a field definition."""
  FIELD_DEFINITION

  """Location adjacent to an argument definition."""
  ARGUMENT_DEFINITION

  """Location adjacent to an interface definition."""
  INTERFACE

  """Location adjacent to a union definition."""
  UNION

  """Location adjacent to an enum definition."""
  ENUM

  """Location adjacent to an enum value definition."""
  ENUM_VALUE

  """Location adjacent to an input object type definition."""
  INPUT_OBJECT

  """Location adjacent to an input object field definition."""
  INPUT_FIELD_DEFINITION

  """Location adjacent to a directive definition."""
  DIRECTIVE_DEFINITION
}'''
