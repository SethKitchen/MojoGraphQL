# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Definition (SDL) normalization: graphql-go-tools v2 `astnormalization`
`DefinitionNormalizer`, `NormalizeDefinition`, `SubgraphSDLNormalizer` and
`NormalizeSubgraphSDL`.

Each function is one visitor of upstream, and edits an SDL document in
place:

| Function | Upstream file |
| --- | --- |
| `extend_object_type_definition` | `object_type_extending.go` |
| `extend_input_object_type_definition` | `input_object_type_extending.go` |
| `extend_enum_type_definition` | `enum_type_extending.go` |
| `extend_interface_type_definition` | `interface_type_extending.go` |
| `extend_scalar_type_definition` | `scalar_type_extending.go` |
| `extend_union_type_definition` | `union_type_extending.go` |
| `remove_merged_type_extensions` | `remove_type_extensions.go` |
| `implicit_schema_definition` | `implicit_schema_definition.go` |
| `implicit_extend_root_operation` | `implicit_extend_root_operation.go` |
| `extends_directive` | `extends_directive.go` |

An extension merges into the first type definition of its kind and name.
When there is none, a new definition takes the members of the extension,
at the end of the document, unless the pass keeps orphans. A merged
extension gets `FLAG_MERGED`, as upstream adds it to
`Index.MergedTypeExtensions`. `remove_merged_type_extensions` removes each
node with the flag.

Differences from upstream:

- Upstream shares the member lists of an extension with its definition.
  A `Document` node has one parent, so the members are copied.
- An imported definition has no description. A `gql_language` extension
  has no description.
"""

from std.collections import Dict

from gql_language.ast import Document, Kind, NO_NODE, OperationType, Role

from gql_normalization.edit import (
    clone,
    insert_after,
    recompute_roles,
    remove_child,
)

comptime FLAG_MERGED: UInt8 = 64
"""The flag of a type extension that a pass merged into a definition:
upstream `Index.MergedTypeExtensions`."""

comptime _OBJECT: UInt64 = UInt64(1) << UInt64(Kind.OBJECT_TYPE_EXTENSION.value)
comptime _INPUT: UInt64 = UInt64(1) << UInt64(
    Kind.INPUT_OBJECT_TYPE_EXTENSION.value
)
comptime _ENUM: UInt64 = UInt64(1) << UInt64(Kind.ENUM_TYPE_EXTENSION.value)
comptime _INTERFACE: UInt64 = UInt64(1) << UInt64(
    Kind.INTERFACE_TYPE_EXTENSION.value
)
comptime _SCALAR: UInt64 = UInt64(1) << UInt64(Kind.SCALAR_TYPE_EXTENSION.value)
comptime _UNION: UInt64 = UInt64(1) << UInt64(Kind.UNION_TYPE_EXTENSION.value)
comptime _ALL: UInt64 = _OBJECT | _INPUT | _ENUM | _INTERFACE | _SCALAR | _UNION


def _definition_kind(extension: Kind) -> Kind:
    """Return the definition kind that an extension kind extends."""
    if extension == Kind.OBJECT_TYPE_EXTENSION:
        return Kind.OBJECT_TYPE_DEFINITION
    if extension == Kind.INPUT_OBJECT_TYPE_EXTENSION:
        return Kind.INPUT_OBJECT_TYPE_DEFINITION
    if extension == Kind.ENUM_TYPE_EXTENSION:
        return Kind.ENUM_TYPE_DEFINITION
    if extension == Kind.INTERFACE_TYPE_EXTENSION:
        return Kind.INTERFACE_TYPE_DEFINITION
    if extension == Kind.SCALAR_TYPE_EXTENSION:
        return Kind.SCALAR_TYPE_DEFINITION
    return Kind.UNION_TYPE_DEFINITION


def _key(kind: Kind, name: StringSlice) -> String:
    """Return the index key of a definition kind and a name."""
    var key = String(kind.value)
    key += ":"
    key += name
    return key^


def root_definitions(document: Document) -> List[Int]:
    """Return the definitions of a document, in order.

    The walker of upstream reads the root nodes once, so a node that a
    visitor adds is not visited. A pass walks this list for the same reason.

    Args:
        document: The document.

    Returns:
        The definition nodes.
    """
    var out = List[Int]()
    var current = document.first_child(document.root)
    while current != NO_NODE:
        out.append(current)
        current = document.next_sibling(current)
    return out^


def _index(document: Document, nodes: List[Int]) -> Dict[String, Int]:
    """Return the first type definition of each kind and name."""
    var index = Dict[String, Int]()
    var at = 0
    while at < len(nodes):
        var node = nodes[at]
        at += 1
        var kind = document.kind(node)
        if not kind.is_type_definition():
            continue
        var key = _key(kind, document.name(node))
        if key not in index:
            index[key^] = node
    return index^


@always_inline
def _rank(role: Role) -> Int:
    """Return the place of a child role in a type definition, as the
    grammar orders them: description, name, interfaces, directives, then
    the members."""
    if role == Role.DESCRIPTION:
        return 0
    if role == Role.NAME:
        return 1
    if role == Role.INTERFACE:
        return 2
    if role == Role.DIRECTIVE:
        return 3
    return 4


def _append_members(mut document: Document, to: Int, extension: Int):
    """Copy each child of an extension but its name to the end of the
    children of a node with its role.

    The children stay in grammar order, as `gql_schema` reads the members
    of a type as its last children.
    """
    var current = document.first_child(extension)
    while current != NO_NODE:
        var role = document.role(current)
        if role != Role.NAME:
            var rank = _rank(role)
            var previous = NO_NODE
            var child = document.first_child(to)
            while child != NO_NODE and _rank(document.role(child)) <= rank:
                previous = child
                child = document.next_sibling(child)
            var copy = clone(document, current)
            insert_after(document, to, previous, copy)
        current = document.next_sibling(current)


def _extend(mut document: Document, kinds: UInt64, keep_orphans: Bool):
    """Merge the extensions of the kinds in a bit set into their
    definitions."""
    var nodes = root_definitions(document)
    var index = _index(document, nodes)
    var at = 0
    while at < len(nodes):
        var node = nodes[at]
        at += 1
        var kind = document.kind(node)
        if (UInt64(1) << UInt64(kind.value)) & kinds == 0:
            continue
        var definition_kind = _definition_kind(kind)
        var name = String(document.name(node))
        var key = _key(definition_kind, name)
        var found = index.get(key)
        if found:
            _append_members(document, found.value(), node)
        elif keep_orphans:
            continue
        else:
            var created = document.add(definition_kind, Role.DEFINITION)
            _ = document.add_name(created, Role.NAME, name)
            _append_members(document, created, node)
            document.append_child(document.root, created)
            index[key^] = created
        document.nodes[node].flags |= FLAG_MERGED


def extend_object_type_definition(
    mut document: Document, keep_orphans: Bool = False
):
    """Merge each object type extension into its definition:
    `extendObjectTypeDefinition`, or
    `extendObjectTypeDefinitionKeepingOrphans` with `keep_orphans`.

    Args:
        document: The SDL document.
        keep_orphans: Keep an extension without a definition as it is.
    """
    _extend(document, _OBJECT, keep_orphans)


def extend_input_object_type_definition(
    mut document: Document, keep_orphans: Bool = False
):
    """Merge each input object type extension into its definition:
    `extendInputObjectTypeDefinition`.

    Args:
        document: The SDL document.
        keep_orphans: Keep an extension without a definition as it is.
    """
    _extend(document, _INPUT, keep_orphans)


def extend_enum_type_definition(
    mut document: Document, keep_orphans: Bool = False
):
    """Merge each enum type extension into its definition:
    `extendEnumTypeDefinition`.

    Args:
        document: The SDL document.
        keep_orphans: Keep an extension without a definition as it is.
    """
    _extend(document, _ENUM, keep_orphans)


def extend_interface_type_definition(
    mut document: Document, keep_orphans: Bool = False
):
    """Merge each interface type extension into its definition:
    `extendInterfaceTypeDefinition`.

    Args:
        document: The SDL document.
        keep_orphans: Keep an extension without a definition as it is.
    """
    _extend(document, _INTERFACE, keep_orphans)


def extend_scalar_type_definition(
    mut document: Document, keep_orphans: Bool = False
):
    """Merge each scalar type extension into its definition:
    `extendScalarTypeDefinition`.

    Args:
        document: The SDL document.
        keep_orphans: Keep an extension without a definition as it is.
    """
    _extend(document, _SCALAR, keep_orphans)


def extend_union_type_definition(
    mut document: Document, keep_orphans: Bool = False
):
    """Merge each union type extension into its definition:
    `extendUnionTypeDefinition`.

    Args:
        document: The SDL document.
        keep_orphans: Keep an extension without a definition as it is.
    """
    _extend(document, _UNION, keep_orphans)


def remove_merged_type_extensions(mut document: Document):
    """Remove each type extension that a pass merged:
    `removeMergedTypeExtensions`.

    Args:
        document: The SDL document.
    """
    var root = document.root
    var previous = NO_NODE
    var current = document.first_child(root)
    var removed = False
    while current != NO_NODE:
        var after = document.next_sibling(current)
        if document.nodes[current].flags & FLAG_MERGED != 0:
            if previous == NO_NODE:
                document.nodes[root].first = Int32(after)
            else:
                document.nodes[previous].next = Int32(after)
            document.nodes[current].next = Int32(NO_NODE)
            removed = True
        else:
            previous = current
        current = after
    if removed:
        document.nodes[root].last = Int32(previous)
        recompute_roles(document, root)


def _object_definition_named(document: Document, name: StringSlice) -> String:
    """Return `name` if an object type definition has it, else empty:
    upstream `implicitSchemaDefinitionVisitor.nodeName`."""
    var current = document.first_child(document.root)
    while current != NO_NODE:
        if (
            document.kind(current) == Kind.OBJECT_TYPE_DEFINITION
            and document.name(current) == name
        ):
            return String(name)
        current = document.next_sibling(current)
    return String()


def _add_operation_types(
    mut document: Document,
    schema: Int,
    query: StringSlice,
    mutation: StringSlice,
    subscription: StringSlice,
):
    """Add the root operation types with a name to a schema definition:
    upstream `ImportRootOperationTypeDefinitions`."""
    var names: List[String] = [
        String(query),
        String(mutation),
        String(subscription),
    ]
    var types: List[OperationType] = [
        OperationType.QUERY,
        OperationType.MUTATION,
        OperationType.SUBSCRIPTION,
    ]
    var index = -1
    while index < 2:
        index += 1
        if names[index] == "":
            continue
        var operation = document.add_child(
            schema,
            Kind.OPERATION_TYPE_DEFINITION,
            Role.OPERATION_TYPE,
            types[index].value,
        )
        var named = document.add_child(operation, Kind.NAMED_TYPE, Role.TYPE)
        _ = document.add_name(named, Role.NAME, names[index])


def implicit_schema_definition(mut document: Document):
    """Add the schema definition that the type names imply:
    `implicitSchemaDefinition`.

    Without a schema definition, a new one goes first, with the object
    types named `Query`, `Mutation` and `Subscription` that exist. A schema
    definition without root operation types gets them.

    Args:
        document: The SDL document.
    """
    var query = _object_definition_named(document, "Query")
    var mutation = _object_definition_named(document, "Mutation")
    var subscription = _object_definition_named(document, "Subscription")
    var schema = NO_NODE
    var current = document.first_child(document.root)
    while current != NO_NODE:
        if document.kind(current) == Kind.SCHEMA_DEFINITION:
            schema = current
            break
        current = document.next_sibling(current)
    if schema == NO_NODE:
        schema = document.add(Kind.SCHEMA_DEFINITION, Role.DEFINITION)
        _add_operation_types(document, schema, query, mutation, subscription)
        insert_after(document, document.root, NO_NODE, schema)
        return
    if document.child(schema, Role.OPERATION_TYPE) != NO_NODE:
        return
    _add_operation_types(document, schema, query, mutation, subscription)


def _root_type_names(document: Document) -> List[String]:
    """Return the query, mutation and subscription type names of the schema
    definitions and extensions, as the parser of upstream indexes them."""
    var names: List[String] = [String(), String(), String()]
    var current = document.first_child(document.root)
    while current != NO_NODE:
        var kind = document.kind(current)
        if kind == Kind.SCHEMA_DEFINITION or kind == Kind.SCHEMA_EXTENSION:
            var operation = document.child(current, Role.OPERATION_TYPE)
            while operation != NO_NODE:
                var named = document.child(operation, Role.TYPE)
                names[Int(document.operation(operation).value)] = String(
                    document.name(named)
                )
                operation = document.next_with_role(operation)
        current = document.next_sibling(current)
    return names^


def implicit_extend_root_operation(mut document: Document):
    """Turn each root operation type with fields or directives into an
    extension: `implicitExtendRootOperation`.

    The root operation types are the types named `Query`, `Mutation` and
    `Subscription`, and the types that the schema definition names.

    Args:
        document: The SDL document.
    """
    var names = _root_type_names(document)
    var nodes = root_definitions(document)
    var at = 0
    while at < len(nodes):
        var node = nodes[at]
        at += 1
        if document.kind(node) != Kind.OBJECT_TYPE_DEFINITION:
            continue
        if (
            document.child(node, Role.FIELD) == NO_NODE
            and document.child(node, Role.DIRECTIVE) == NO_NODE
        ):
            continue
        var name = document.name(node)
        if (
            name == "Query"
            or name == "Mutation"
            or name == "Subscription"
            or name == names[0]
            or name == names[1]
            or name == names[2]
        ):
            document.nodes[node].kind = Kind.OBJECT_TYPE_EXTENSION


def extends_directive(mut document: Document):
    """Turn each object or interface type definition with `@extends` into
    an extension, without the first `@extends`: `extendsDirective`.

    Args:
        document: The SDL document.
    """
    var nodes = root_definitions(document)
    var at = 0
    while at < len(nodes):
        var node = nodes[at]
        at += 1
        var kind = document.kind(node)
        var extension: Kind
        if kind == Kind.OBJECT_TYPE_DEFINITION:
            extension = Kind.OBJECT_TYPE_EXTENSION
        elif kind == Kind.INTERFACE_TYPE_DEFINITION:
            extension = Kind.INTERFACE_TYPE_EXTENSION
        else:
            continue
        var directive = document.child(node, Role.DIRECTIVE)
        while directive != NO_NODE:
            if document.name(directive) == "extends":
                break
            directive = document.next_with_role(directive)
        if directive == NO_NODE:
            continue
        document.nodes[node].kind = extension
        remove_child(document, node, directive)


struct DefinitionNormalizer(Copyable, Movable):
    """Normalizes SDL documents: upstream `DefinitionNormalizer`. One
    normalizer can serve many documents."""

    var keep_orphans: Bool
    """Keep the extensions without a definition, and the schema definition
    as it is: `NewSubgraphDefinitionNormalizer`."""

    def __init__(out self):
        """Make the normalizer of `NewDefinitionNormalizer`."""
        self.keep_orphans = False

    @staticmethod
    def new_subgraph() -> DefinitionNormalizer:
        """Make the normalizer of `NewSubgraphDefinitionNormalizer`.

        It merges the extensions that have a definition, keeps the others,
        and adds no schema definition.

        Returns:
            The normalizer.
        """
        var normalizer = DefinitionNormalizer()
        normalizer.keep_orphans = True
        return normalizer^

    def normalize_definition(self, mut definition: Document):
        """Merge the type extensions into their definitions, remove the
        merged extensions and add the implied schema definition:
        `NormalizeDefinition`.

        Args:
            definition: The SDL document, changed in place.
        """
        _extend(definition, _ALL, self.keep_orphans)
        remove_merged_type_extensions(definition)
        if not self.keep_orphans:
            implicit_schema_definition(definition)


def normalize_definition(mut definition: Document):
    """Normalize an SDL document with the default normalizer:
    `NormalizeDefinition`.

    Args:
        definition: The SDL document, changed in place.
    """
    DefinitionNormalizer().normalize_definition(definition)


struct SubgraphSDLNormalizer(Copyable, Movable):
    """Normalizes the SDL of a subgraph: upstream `SubgraphSDLNormalizer`.

    It runs `implicit_extend_root_operation` and `extends_directive`.
    """

    def __init__(out self):
        """Make the normalizer of `NewSubgraphSDLNormalizer`."""
        pass

    def normalize_subgraph_sdl(self, mut definition: Document):
        """Turn the root operation types and the `@extends` types into
        extensions: `NormalizeSubgraphSDL`.

        Args:
            definition: The SDL document, changed in place.
        """
        implicit_extend_root_operation(definition)
        extends_directive(definition)


def normalize_subgraph_sdl(mut definition: Document):
    """Normalize the SDL of a subgraph: `NormalizeSubgraphSDL`.

    Args:
        definition: The SDL document, changed in place.
    """
    SubgraphSDLNormalizer().normalize_subgraph_sdl(definition)
