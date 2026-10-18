# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The consumer schema: the schema that a client of the router sees.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/consumer_schema/`: `mod.rs`,
`prune_inacessible.rs`, `strip_schema_internals.rs` and
`introspection_schema.graphql`.

`ConsumerSchema.new_from_supergraph` makes the consumer schema in three
steps, as upstream `create_consumer_schema`:

1. `PruneInaccessible.prune` removes each type, field, argument, input
   field and enum value that has `@inaccessible`.
2. `StripSchemaInternals.strip_schema_internals` removes the federation
   directives (`@join__*`, `@link`, `@tag`, `@inaccessible` and the
   others), and the definitions of the federation types (`join__Graph`,
   `link__Import` and the others).
3. The introspection schema is added. Its `__schema` and `__type` fields
   are added to the query type. A built-in directive that the supergraph
   already defines is not added again.

**Differences from upstream.** Upstream keeps the document in an `Arc`
and an `xxh3` hash of it. This port keeps the document and its printed SDL
text, and has no hash. Upstream panics when a supergraph has a type
extension, or has no query type; this port raises an `Error`.
"""

from gql_language.ast import NO_NODE, Document, Kind, OperationType, Role
from gql_language.parser import parse
from gql_language.printer import print_ast


comptime INTROSPECTION_SCHEMA = """\"Directs the executor to skip this field or fragment when the `if` argument is true.\"
directive @skip(
  \"Skipped when true.\"
  if: Boolean!
) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT
\"Directs the executor to include this field or fragment only when the `if` argument is true.\"
directive @include(
  \"Included when true.\"
  if: Boolean!
) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT
directive @deprecated(
  reason: String = \"No longer supported\"
) on FIELD_DEFINITION | ARGUMENT_DEFINITION | INPUT_FIELD_DEFINITION | ENUM_VALUE
directive @specifiedBy(url: String!) on SCALAR
directive @oneOf on INPUT_OBJECT

\"The `Boolean` scalar type represents `true` or `false` values.\"
scalar Boolean
\"The `Float` scalar type represents signed double-precision fractional values as specified by [IEEE 754](https://en.wikipedia.org/wiki/IEEE_floating_point). Float can represent values between -(2^53 - 1) and 2^53 - 1, inclusive.\"
scalar Float
\"The `Int` scalar type represents non-fractional signed whole numeric values. Int can represent values between -(2^31) and 2^31 - 1.\"
scalar Int
\"The `ID` scalar type represents a unique identifier, often used to refetch an object or as key for a cache. The ID type appears in a JSON response as a String; however, it is not intended to be human-readable. When expected as an input type, any string (such as `\\\"4\\\"`) or integer (such as `4`) input value will be accepted as an ID.\"
scalar ID
\"The `String` scalar type represents textual data, represented as UTF-8 character sequences. The String type is most often used by GraphQL to represent free-form human-readable text.\"
scalar String

type Query {
  __schema: __Schema!
  __type(name: String!): __Type
}

type __Schema {
  description: String
  types: [__Type!]!
  queryType: __Type!
  mutationType: __Type
  subscriptionType: __Type
  directives: [__Directive!]!
}

type __Type {
  kind: __TypeKind!
  name: String
  description: String

  # may be non-null for custom SCALAR, otherwise null.
  specifiedByURL: String

  # OBJECT and INTERFACE only
  fields(includeDeprecated: Boolean = false): [__Field!]

  # OBJECT only
  interfaces: [__Type!]

  # INTERFACE and UNION only
  possibleTypes: [__Type!]

  # ENUM only
  enumValues(includeDeprecated: Boolean = false): [__EnumValue!]

  # INPUT_OBJECT only
  inputFields(includeDeprecated: Boolean = false): [__InputValue!]

  # NON_NULL and LIST only
  ofType: __Type

  # must be non-null for INPUT_OBJECT, otherwise null.
  isOneOf: Boolean
}

type __Field {
  name: String!
  description: String
  args(includeDeprecated: Boolean = false): [__InputValue!]!
  type: __Type!
  isDeprecated: Boolean!
  deprecationReason: String
}

type __InputValue {
  name: String!
  description: String
  type: __Type!
  defaultValue: String
  isDeprecated: Boolean!
  deprecationReason: String
}

type __EnumValue {
  name: String!
  description: String
  isDeprecated: Boolean!
  deprecationReason: String
}

enum __TypeKind {
  SCALAR
  OBJECT
  INTERFACE
  UNION
  ENUM
  INPUT_OBJECT
  LIST
  NON_NULL
}

type __Directive {
  name: String!
  description: String
  locations: [__DirectiveLocation!]!
  args(includeDeprecated: Boolean = false): [__InputValue!]!
  isRepeatable: Boolean!
}

enum __DirectiveLocation {
  QUERY
  MUTATION
  SUBSCRIPTION
  FIELD
  FRAGMENT_DEFINITION
  FRAGMENT_SPREAD
  INLINE_FRAGMENT
  SCHEMA
  SCALAR
  OBJECT
  FIELD_DEFINITION
  ARGUMENT_DEFINITION
  INTERFACE
  UNION
  ENUM
  ENUM_VALUE
  INPUT_OBJECT
  INPUT_FIELD_DEFINITION
}
"""
"""The upstream `introspection_schema.graphql`: the built-in directives and
scalars, and the introspection types."""


def _is_stripped_directive(name: StringSlice) -> Bool:
    """Return True if a directive is one of upstream `DIRECTIVES_TO_STRIP`."""
    var names: List[StaticString] = [
        "join__type",
        "join__enumValue",
        "join__field",
        "join__implements",
        "join__unionMember",
        "join__graph",
        "join__owner",
        "join__directive",
        "link",
        "tag",
        "inaccessible",
        "core",
        "authenticated",
        "requiresScopes",
        "policy",
        "cost",
        "listSize",
    ]
    var index = 0
    while index < len(names):
        if names[index] == name:
            return True
        index += 1
    return False


def _is_stripped_definition(name: StringSlice) -> Bool:
    """Return True if a type is one of upstream `DEFINITIONS_TO_STRIP`."""
    var names: List[StaticString] = [
        "link__Purpose",
        "link__Import",
        "join__Graph",
        "join__FieldSet",
        "join__DirectiveArguments",
        "core__Purpose",
        "requiresScopes__Scope",
        "policy__Policy",
    ]
    var index = 0
    while index < len(names):
        if names[index] == name:
            return True
        index += 1
    return False


def _has_inaccessible(document: Document, node: Int) -> Bool:
    """Return True if a definition has `@inaccessible`, as upstream
    `has_inaccessible_directive`."""
    var child = document.first_child(node)
    while child != NO_NODE:
        if (
            document.kind(child) == Kind.DIRECTIVE
            and document.name(child) == "inaccessible"
        ):
            return True
        child = document.next_sibling(child)
    return False


def _is_member(kind: Kind) -> Bool:
    """Return True for a field, an input value or an enum value definition."""
    if kind == Kind.FIELD_DEFINITION:
        return True
    if kind == Kind.INPUT_VALUE_DEFINITION:
        return True
    return kind == Kind.ENUM_VALUE_DEFINITION


def _keep_child(document: Document, node: Int, prune: Bool) -> Bool:
    """Return True if a transform keeps a child of a definition.

    The prune transform drops a member with `@inaccessible`. The strip
    transform drops a federation directive.
    """
    var kind = document.kind(node)
    if prune:
        if _is_member(kind):
            return not _has_inaccessible(document, node)
        return True
    if kind == Kind.DIRECTIVE:
        return not _is_stripped_directive(document.name(node))
    return True


def _keep_definition(document: Document, node: Int, prune: Bool) raises -> Bool:
    """Return True if a transform keeps a definition of the document."""
    var kind = document.kind(node)
    if kind.is_type_extension():
        if prune:
            return True
        raise Error("TypeExtension not implemented")
    if prune:
        if kind.is_type_definition():
            return not _has_inaccessible(document, node)
        return True
    if kind == Kind.DIRECTIVE_DEFINITION:
        return not _is_stripped_directive(document.name(node))
    if kind.is_type_definition():
        return not _is_stripped_definition(document.name(node))
    return True


def _copy_definition(
    mut out: Document, source: Document, node: Int, role: Role, prune: Bool
) -> Int:
    """Copy a definition and the children that a transform keeps.

    Args:
        out: The document to copy into.
        source: The document to copy from.
        node: A definition, or a field, input value or enum value.
        role: The role of the copy.
        prune: True for the prune transform, False for the strip one.

    Returns:
        The copy, with no parent.
    """
    var copy = out.add(source.kind(node), role, source.nodes[node].flags)
    var child = source.first_child(node)
    while child != NO_NODE:
        if _keep_child(source, child, prune):
            var child_copy: Int
            if _is_member(source.kind(child)):
                child_copy = _copy_definition(
                    out, source, child, source.role(child), prune
                )
            else:
                child_copy = out.copy_subtree(source, child, source.role(child))
            out.append_child(copy, child_copy)
        child = source.next_sibling(child)
    return copy


def _transform(schema: Document, prune: Bool) raises -> Document:
    """Run one transform over every definition of a schema."""
    var out = Document()
    var definition = schema.first_child(schema.root)
    while definition != NO_NODE:
        if _keep_definition(schema, definition, prune):
            out.append_child(
                out.root,
                _copy_definition(
                    out, schema, definition, Role.DEFINITION, prune
                ),
            )
        definition = schema.next_sibling(definition)
    return out^


struct PruneInaccessible:
    """The transform that removes what has `@inaccessible`, as upstream
    `PruneInaccessible`."""

    @staticmethod
    def prune(schema: Document) raises -> Document:
        """Remove each type, field, argument, input field and enum value
        that has `@inaccessible`.

        The schema definition, the directive definitions and the type
        extensions stay.

        Args:
            schema: The supergraph.

        Returns:
            A new document without the inaccessible parts.

        Raises:
            Error: This transform does not raise. It shares its walk with
                `StripSchemaInternals`, which can raise.
        """
        return _transform(schema, True)

    @staticmethod
    def has_inaccessible_directive(document: Document, node: Int) -> Bool:
        """Return True if a definition has `@inaccessible`.

        Args:
            document: The document that holds the definition.
            node: The definition.

        Returns:
            Whether one of its directives is `@inaccessible`.
        """
        return _has_inaccessible(document, node)


struct StripSchemaInternals:
    """The transform that removes the federation internals, as upstream
    `StripSchemaInternals`."""

    @staticmethod
    def strip_schema_internals(schema: Document) raises -> Document:
        """Remove the federation directives and the federation types.

        Every use of a directive in upstream `DIRECTIVES_TO_STRIP` goes,
        with its definition. Every type in upstream `DEFINITIONS_TO_STRIP`
        goes.

        Args:
            schema: The pruned supergraph.

        Returns:
            A new document without the federation internals.

        Raises:
            Error: When the schema has a type extension, as upstream
                `todo!`.
        """
        return _transform(schema, False)


def _query_type_name(document: Document) raises -> String:
    """Return the query root type, as `graphql_tools` `query_type_name`."""
    var schema = _find(document, Kind.SCHEMA_DEFINITION, "")
    if schema != NO_NODE:
        var operation = document.first_child(schema)
        while operation != NO_NODE:
            if (
                document.kind(operation) == Kind.OPERATION_TYPE_DEFINITION
                and document.operation(operation) == OperationType.QUERY
            ):
                return String(
                    document.named_type(document.child(operation, Role.TYPE))
                )
            operation = document.next_sibling(operation)
    if _find(document, Kind.OBJECT_TYPE_DEFINITION, "Query") != NO_NODE:
        return String("Query")
    raise Error("Query type not found in schema")


def _find(document: Document, kind: Kind, name: StringSlice) -> Int:
    """Return the first definition of a kind and a name, or `NO_NODE`."""
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        if (
            document.kind(definition) == kind
            and document.name(definition) == name
        ):
            return definition
        definition = document.next_sibling(definition)
    return NO_NODE


def create_consumer_schema(supergraph: Document) raises -> Document:
    """Make the consumer schema of a supergraph, as upstream
    `create_consumer_schema`.

    Args:
        supergraph: The supergraph.

    Returns:
        The pruned and stripped supergraph, with the introspection schema.

    Raises:
        Error: When the supergraph has a type extension or no query type.
    """
    var result = StripSchemaInternals.strip_schema_internals(
        PruneInaccessible.prune(supergraph)
    )
    var introspection = parse(INTROSPECTION_SCHEMA)
    var query_type_name = _query_type_name(result)
    var definition = introspection.first_child(introspection.root)
    while definition != NO_NODE:
        var kind = introspection.kind(definition)
        var name = introspection.name(definition)
        var add = True
        if kind == Kind.OBJECT_TYPE_DEFINITION and name == "Query":
            var query = _find(
                result, Kind.OBJECT_TYPE_DEFINITION, query_type_name
            )
            if query != NO_NODE:
                # The query type exists: extend it.
                add = False
                var field = introspection.child(definition, Role.FIELD)
                while field != NO_NODE:
                    result.append_child(
                        query,
                        result.copy_subtree(introspection, field, Role.FIELD),
                    )
                    field = introspection.next_with_role(field)
        elif kind == Kind.DIRECTIVE_DEFINITION:
            # A supergraph can already define a built-in directive, such
            # as `@oneOf`: keep its definition.
            add = _find(result, kind, name) == NO_NODE
        if add:
            result.append_child(
                result.root,
                result.copy_subtree(introspection, definition, Role.DEFINITION),
            )
        definition = introspection.next_sibling(definition)
    return result^


struct ConsumerSchema(Movable):
    """The schema that a client of the router sees, as upstream
    `ConsumerSchema`."""

    var document: Document
    """The consumer schema."""
    var sdl: String
    """The consumer schema, printed."""

    def __init__(out self, var document: Document):
        """Wrap a consumer schema, and print it.

        Args:
            document: The consumer schema.
        """
        self.sdl = print_ast(document)
        self.document = document^

    @staticmethod
    def new_from_supergraph(supergraph: Document) raises -> ConsumerSchema:
        """Make the consumer schema of a supergraph, as upstream
        `ConsumerSchema::new_from_supergraph`.

        Args:
            supergraph: The supergraph.

        Returns:
            The consumer schema.

        Raises:
            Error: When the supergraph has a type extension or no query
                type.
        """
        return ConsumerSchema(create_consumer_schema(supergraph))
