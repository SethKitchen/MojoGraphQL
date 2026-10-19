# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The built-in types and directives of every schema.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `src/built_in_types.graphql`,
under the MIT arm of its MIT OR Apache-2.0 license. The text is the upstream
file, unchanged. It holds the introspection types, the built-in scalars and
the built-in directives.
"""

comptime BUILT_IN_TYPES: StaticString = (
    '"A GraphQL Schema defines the capabilities of a GraphQL server. It exposes'
    " all available types and directives on the server, as well as the entry"
    ' points for query, mutation, and subscription operations."\ntype __Schema'
    ' {\n  description: String\n  "A list of all types supported by this'
    ' server."\n  types: [__Type!]!\n  "The type that query operations will be'
    ' rooted at."\n  queryType: __Type!\n  "If this server supports mutation,'
    ' the type that mutation operations will be rooted at."\n  mutationType:'
    ' __Type\n  "If this server support subscription, the type that'
    ' subscription operations will be rooted at."\n  subscriptionType: __Type\n'
    '  "A list of all directives supported by this server."\n  directives:'
    ' [__Directive!]!\n}\n\n"The fundamental unit of any GraphQL Schema is the'
    " type. There are many kinds of types in GraphQL as represented by the"
    " `__TypeKind` enum.\\n\\nDepending on the kind of a type, certain fields"
    " describe information about that type. Scalar types provide no information"
    " beyond a name, description and optional `specifiedByURL`, while Enum"
    " types provide their values. Object and Interface types provide the fields"
    " they describe. Abstract types, Union and Interface, provide the Object"
    " types possible at runtime. List and NonNull types compose other"
    ' types."\ntype __Type {\n  kind: __TypeKind!\n  name: String\n '
    " description: String\n  # must be non-null for OBJECT and INTERFACE,"
    " otherwise null.\n  fields(includeDeprecated: Boolean = false):"
    " [__Field!]\n  # must be non-null for OBJECT and INTERFACE, otherwise"
    " null.\n  interfaces: [__Type!]\n  # must be non-null for INTERFACE and"
    " UNION, otherwise null.\n  possibleTypes: [__Type!]\n  # must be non-null"
    " for ENUM, otherwise null.\n  enumValues(includeDeprecated: Boolean ="
    " false): [__EnumValue!]\n  # must be non-null for INPUT_OBJECT, otherwise"
    " null.\n  inputFields(includeDeprecated: Boolean = false):"
    " [__InputValue!]\n  # must be non-null for NON_NULL and LIST, otherwise"
    " null.\n  ofType: __Type\n  # may be non-null for custom SCALAR, otherwise"
    ' null.\n  specifiedByURL: String\n}\n\n"An enum describing what kind of'
    ' type a given `__Type` is."\nenum __TypeKind {\n  "Indicates this type is'
    ' a scalar."\n  SCALAR\n  "Indicates this type is an object. `fields` and'
    ' `interfaces` are valid fields."\n  OBJECT\n  "Indicates this type is an'
    " interface. `fields`, `interfaces`, and `possibleTypes` are valid"
    ' fields."\n  INTERFACE\n  "Indicates this type is a union. `possibleTypes`'
    ' is a valid field."\n  UNION\n  "Indicates this type is an enum.'
    ' `enumValues` is a valid field."\n  ENUM\n  "Indicates this type is an'
    ' input object. `inputFields` is a valid field."\n  INPUT_OBJECT\n '
    ' "Indicates this type is a list. `ofType` is a valid field."\n  LIST\n '
    ' "Indicates this type is a non-null. `ofType` is a valid field."\n '
    ' NON_NULL\n}\n\n"Object and Interface types are described by a list of'
    " Fields, each of which has a name, potentially a list of arguments, and a"
    ' return type."\ntype __Field {\n  name: String!\n  description: String\n '
    " args(includeDeprecated: Boolean = false): [__InputValue!]!\n  type:"
    " __Type!\n  isDeprecated: Boolean!\n  deprecationReason:"
    ' String\n}\n\n"Arguments provided to Fields or Directives and the input'
    " fields of an InputObject are represented as Input Values which describe"
    ' their type and optionally a default value."\ntype __InputValue {\n  name:'
    ' String!\n  description: String\n  type: __Type!\n  "A GraphQL-formatted'
    ' string representing the default value for this input value."\n '
    " defaultValue: String\n  isDeprecated: Boolean!\n  deprecationReason:"
    ' String\n}\n\n"One possible value for a given Enum. Enum values are unique'
    " values, not a placeholder for a string or numeric value. However an Enum"
    ' value is returned in a JSON response as a string."\ntype __EnumValue {\n '
    " name: String!\n  description: String\n  isDeprecated: Boolean!\n "
    ' deprecationReason: String\n}\n\n"A Directive provides a way to describe'
    " alternate runtime execution and type validation behavior in a GraphQL"
    " document.\\n\\nIn some cases, you need to provide options to alter"
    " GraphQL's execution behavior in ways field arguments will not suffice,"
    " such as conditionally including or skipping a field. Directives provide"
    ' this by describing additional information to the executor."\ntype'
    " __Directive {\n  name: String!\n  description: String\n  locations:"
    " [__DirectiveLocation!]!\n  args(includeDeprecated: Boolean = false):"
    ' [__InputValue!]!\n  isRepeatable: Boolean!\n}\n\n"A Directive can be'
    " adjacent to many parts of the GraphQL language, a __DirectiveLocation"
    ' describes one such possible adjacencies."\nenum __DirectiveLocation {\n '
    ' "Location adjacent to a query operation."\n  QUERY\n  "Location adjacent'
    ' to a mutation operation."\n  MUTATION\n  "Location adjacent to a'
    ' subscription operation."\n  SUBSCRIPTION\n  "Location adjacent to a'
    ' field."\n  FIELD\n  "Location adjacent to a fragment definition."\n '
    ' FRAGMENT_DEFINITION\n  "Location adjacent to a fragment spread."\n '
    ' FRAGMENT_SPREAD\n  "Location adjacent to an inline fragment."\n '
    ' INLINE_FRAGMENT\n  "Location adjacent to a variable definition."\n '
    ' VARIABLE_DEFINITION\n  "Location adjacent to a schema definition."\n '
    ' SCHEMA\n  "Location adjacent to a scalar definition."\n  SCALAR\n '
    ' "Location adjacent to an object type definition."\n  OBJECT\n  "Location'
    ' adjacent to a field definition."\n  FIELD_DEFINITION\n  "Location'
    ' adjacent to an argument definition."\n  ARGUMENT_DEFINITION\n  "Location'
    ' adjacent to an interface definition."\n  INTERFACE\n  "Location adjacent'
    ' to a union definition."\n  UNION\n  "Location adjacent to an enum'
    ' definition."\n  ENUM\n  "Location adjacent to an enum value'
    ' definition."\n  ENUM_VALUE\n  "Location adjacent to an input object type'
    ' definition."\n  INPUT_OBJECT\n  "Location adjacent to an input object'
    ' field definition."\n  INPUT_FIELD_DEFINITION\n}\n\n"Directs the executor'
    " to skip this field or fragment when the `if` argument is"
    ' true."\ndirective @skip(\n  "Skipped when true."\n  if: Boolean!\n) on'
    ' FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT\n\n"Directs the executor to'
    " include this field or fragment only when the `if` argument is"
    ' true."\ndirective @include(\n  "Included when true."\n  if: Boolean!\n)'
    ' on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT\n\n"Marks an element of a'
    ' GraphQL schema as no longer supported."\ndirective @deprecated(\n  """\n '
    " Explains why this element was deprecated, usually also including a"
    " suggestion for how to access supported similar data. Formatted using the"
    " Markdown syntax, as specified by [CommonMark](https://commonmark.org/).\n"
    '  """\n  reason: String = "No longer supported"\n) on FIELD_DEFINITION |'
    ' ARGUMENT_DEFINITION | INPUT_FIELD_DEFINITION | ENUM_VALUE\n\n"Exposes a'
    ' URL that specifies the behavior of this scalar."\ndirective'
    ' @specifiedBy(\n    "The URL that specifies the behavior of this'
    ' scalar."\n    url: String!\n) on SCALAR\n\n"""\nThe `Int` scalar type'
    " represents non-fractional signed whole numeric values. Int can represent"
    ' values between -(2^31) and 2^31 - 1.\n"""\nscalar Int\n\n"""\nThe `Float`'
    " scalar type represents signed double-precision fractional values as"
    " specified by [IEEE"
    ' 754](https://en.wikipedia.org/wiki/IEEE_floating_point).\n"""\nscalar'
    ' Float\n\n"""\nThe `String` scalar type represents textual data,'
    " represented as UTF-8 character sequences. The String type is most often"
    ' used by GraphQL to represent free-form human-readable text.\n"""\nscalar'
    ' String\n\n"The `Boolean` scalar type represents `true` or'
    ' `false`."\nscalar Boolean\n\n"""\nThe `ID` scalar type represents a'
    " unique identifier, often used to refetch an object or as key for a cache."
    " The ID type appears in a JSON response as a String; however, it is not"
    " intended to be human-readable. When expected as an input type, any string"
    ' (such as `"4"`) or integer (such as `4`) input value will be accepted as'
    ' an ID.\n"""\nscalar ID\n'
)

"""The upstream `built_in_types.graphql`."""
