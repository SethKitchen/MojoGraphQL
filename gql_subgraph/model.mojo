# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The subgraph model: the SDL of a subgraph and what federation adds.

`@apollo/subgraph` 2.14.4 calls `buildSubgraph` of
`@apollo/federation-internals`, which is Elastic licensed and is not read.
This module implements the same result from the Apollo Federation subgraph
specification (`_Any`, `_Entity`, `_Service`, `Query._service` and
`Query._entities`), the federation/v2.x specifications (`@link`, the
imports and the `federation__` prefix), and Hive Federation Composition
v0.27.0 (MIT) as the reference. The order of the added definitions, the
error messages, and which object types join `_Entity`, are those of
`@apollo/subgraph` 2.14.4, observed as a black box.

A model keeps each type as its parts: the definition and each extension,
as in the source. Federation definitions come from SDL that the model
generates and parses into a second document.

**Differences from upstream.**

- Only the checks of `buildSubgraph` that a GraphQL schema needs run:
  duplicate and unknown types, unknown directives, the `@link` imports and
  version, the graphql-js SDL rules and the schema validation. The
  federation checks of field sets, `@external`, `@requires`, `@provides`,
  `@shareable`, `@override`, `@interfaceObject`, `@composeDirective`,
  `@context` and the cost directives do not run. Use `gql_composition` to
  validate a subgraph.
- An error message has no source excerpt.
- Only the federation and link specifications can be linked. A `@link` to
  another specification is kept as a directive application.
- A second `schema` definition is an error, as the graphql-js SDL rule
  `LoneSchemaDefinition` says. Upstream accepts it.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.names import NOT_FOUND, NameTable
from gql_subgraph.spec import FederationVersion

comptime USER = 0
"""The document of the user's SDL."""

comptime GENERATED = 1
"""The document of the SDL that federation adds."""


@fieldwise_init
struct Ref(Equatable, ImplicitlyCopyable, Movable):
    """A node in one of the two documents of a model."""

    var doc: Int
    """`USER` or `GENERATED`."""
    var node: Int
    """The node's index."""


struct Part(Copyable, Movable):
    """The definition or an extension of a type or of the schema."""

    var doc: Int
    """The document of the node."""
    var node: Int
    """The definition or extension node, or `NO_NODE` for a definition
    that federation adds."""
    var is_extension: Bool
    """Whether the part is an extension."""
    var added: List[Ref]
    """The fields that federation adds, after those of the node."""
    var prefix: List[Ref]
    """The directives that federation adds, before those of the node."""

    def __init__(out self, doc: Int, node: Int, is_extension: Bool):
        """Make a part of a node.

        Args:
            doc: The document.
            node: The node, or `NO_NODE`.
            is_extension: Whether the part is an extension.
        """
        self.doc = doc
        self.node = node
        self.is_extension = is_extension
        self.added = List[Ref]()
        self.prefix = List[Ref]()


struct TypeEntry(Copyable, Movable):
    """A named type and its parts, in source order."""

    var name: String
    """The type's name."""
    var kind: Kind
    """The kind of its definition, such as `OBJECT_TYPE_DEFINITION`."""
    var parts: List[Part]
    """The definition and the extensions."""
    var hidden: Bool
    """Whether `printSubgraphSchema` leaves the type out: a federation
    type."""

    def __init__(out self, var name: String, kind: Kind):
        """Make a type with no parts.

        Args:
            name: The name.
            kind: The kind of its definition.
        """
        self.name = name^
        self.kind = kind
        self.parts = List[Part]()
        self.hidden = False

    def has_definition(self) -> Bool:
        """Return True when a part is not an extension.

        Returns:
            Whether the type has a definition part.
        """
        var index = 0
        while index < len(self.parts):
            if not self.parts[index].is_extension:
                return True
            index += 1
        return False


@fieldwise_init
struct DirectiveEntry(ImplicitlyCopyable, Movable):
    """A directive definition."""

    var at: Ref
    """The `DirectiveDefinition` node."""
    var hidden: Bool
    """Whether `printSubgraphSchema` leaves it out: a federation or link
    definition."""


def definition_kind(kind: Kind) -> Kind:
    """Return the definition kind of a type definition or extension kind.

    Args:
        kind: A type definition or type extension kind.

    Returns:
        The type definition kind.
    """
    if kind == Kind.SCALAR_TYPE_EXTENSION:
        return Kind.SCALAR_TYPE_DEFINITION
    if kind == Kind.OBJECT_TYPE_EXTENSION:
        return Kind.OBJECT_TYPE_DEFINITION
    if kind == Kind.INTERFACE_TYPE_EXTENSION:
        return Kind.INTERFACE_TYPE_DEFINITION
    if kind == Kind.UNION_TYPE_EXTENSION:
        return Kind.UNION_TYPE_DEFINITION
    if kind == Kind.ENUM_TYPE_EXTENSION:
        return Kind.ENUM_TYPE_DEFINITION
    if kind == Kind.INPUT_OBJECT_TYPE_EXTENSION:
        return Kind.INPUT_OBJECT_TYPE_DEFINITION
    return kind


struct SubgraphModel(Movable):
    """A subgraph: its SDL, split into parts, with what federation adds."""

    var docs: List[Document]
    """The user's SDL, then the generated SDL."""
    var version: FederationVersion
    """The federation version."""
    var types: List[TypeEntry]
    """The types, in the order of their first part; the added types come
    after the user's."""
    var type_names: NameTable
    """The index of each type in `types`, by name."""
    var directives: List[DirectiveEntry]
    """The directive definitions; the added ones come after the user's."""
    var schema_parts: List[Part]
    """The schema definition, which can be added, then the extensions."""
    var roots: List[String]
    """The query, mutation and subscription types, or empty for none."""
    var declared: List[Bool]
    """Whether a schema part names each root type."""
    var names: List[String]
    """The name of each federation directive in this schema, or empty
    when the version has no such directive."""
    var type_refs: List[String]
    """The name of each federation type in this schema."""
    var entities: List[String]
    """The members of `_Entity`, sorted."""

    def __init__(out self):
        """Make an empty federation 1 model with no documents."""
        self.docs = List[Document]()
        self.version = FederationVersion.FED1
        self.types = List[TypeEntry]()
        self.type_names = NameTable()
        self.directives = List[DirectiveEntry]()
        self.schema_parts = List[Part]()
        self.roots = [String(""), String(""), String("")]
        self.declared = [False, False, False]
        self.names = List[String]()
        self.type_refs = List[String]()
        self.entities = List[String]()

    def type_index(self, name: StringSlice) -> Int:
        """Return the index of a type in `types`.

        Args:
            name: The type's name.

        Returns:
            The index, or `NOT_FOUND`.
        """
        return self.type_names.find(-1, name)

    def add_part(
        mut self, doc: Int, node: Int, kind: Kind, var name: String
    ) raises -> Int:
        """Add a definition or an extension to its type.

        Args:
            doc: The document.
            node: The type definition or extension node.
            kind: The node's kind.
            name: The type's name.

        Returns:
            The type's index.

        Raises:
            Error: `There can be only one type named "X"` for a second
                definition.
        """
        var at = self.type_index(name)
        var is_extension = kind.is_type_extension()
        if at == NOT_FOUND:
            at = len(self.types)
            _ = self.type_names.insert(-1, name, at)
            self.types.append(TypeEntry(name^, definition_kind(kind)))
        elif not is_extension and self.types[at].has_definition():
            raise Error('There can be only one type named "' + name + '"')
        # The definition prints first, before the extensions.
        var position = len(self.types[at].parts) if is_extension else 0
        self.types[at].parts.insert(position, Part(doc, node, is_extension))
        return at
