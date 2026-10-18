# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""What the validation rules of one subgraph share.

Port of `createSubgraphValidationContext` of Hive Federation Composition
v0.27.0 `src/subgraph/validation/validation-context.ts`.

The context owns the subgraph's document, its state and its errors. It
knows which federation directives and types the subgraph can use, under
which names, and it merges the definitions and extensions of each object,
interface and union type.

**Differences from upstream.** Upstream copies the AST node of a type and
concatenates the fields of its extensions. A `MergedType` keeps the node
indices of those fields, interfaces and directives.
"""

from std.collections import Dict
from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.federation_spec import (
    SpecSchema,
    is_specified_scalar,
    strip_at,
)
from gql_composition.link import LinkImport
from gql_composition.state import StringSet, SubgraphState, TypeKind
from gql_composition.version import FederationVersion
from gql_composition.walk import TypeNodeInfo, Walker


comptime SPEC_DIRECTIVES: Array[StaticString, 18] = [
    "inaccessible",
    "interfaceObject",
    "authenticated",
    "policy",
    "requiresScopes",
    "cost",
    "listSize",
    "override",
    "context",
    "fromContext",
    "extends",
    "shareable",
    "key",
    "provides",
    "requires",
    "external",
    "tag",
    "composeDirective",
]
"""The federation directives that rules handle, in the upstream order of
`federationRules`."""


struct OrderedSet(Copyable):
    """A set of strings in insertion order, with hashed lookups."""

    var items: List[String]
    """The strings, in insertion order."""
    var index: Dict[String, Int]
    """The position of each string."""

    def __init__(out self):
        """Start an empty set."""
        self.items = List[String]()
        self.index = Dict[String, Int]()

    def contains(self, item: String) -> Bool:
        """Return True if the set holds a string.

        Args:
            item: The string.

        Returns:
            Whether it is in the set.
        """
        return item in self.index

    def add(mut self, item: String):
        """Add a string unless the set holds it.

        Args:
            item: The string.
        """
        if item not in self.index:
            self.index[item] = len(self.items)
            self.items.append(item)


struct MergedType(Copyable):
    """An object or interface type with all of its definitions and
    extensions, as upstream `knownObjectAndInterfaceSubgraphEntities`."""

    var name: String
    """The name."""
    var kind: Kind
    """The kind: a definition kind as soon as one definition exists."""
    var fields: List[Int]
    """The field definitions of every part, in order."""
    var interfaces: List[Int]
    """The implemented interface names of every part, as `NamedType`
    nodes."""
    var directives: List[Int]
    """The directives of every part, in order."""

    def __init__(out self, name: String, kind: Kind):
        """Start a type with no parts.

        Args:
            name: The name.
            kind: The kind of the first part.
        """
        self.name = name
        self.kind = kind
        self.fields = List[Int]()
        self.interfaces = List[Int]()
        self.directives = List[Int]()

    def is_object(self) -> Bool:
        """Return True for an object type.

        Returns:
            Whether the kind is an object definition or extension.
        """
        return (
            self.kind == Kind.OBJECT_TYPE_DEFINITION
            or self.kind == Kind.OBJECT_TYPE_EXTENSION
        )

    def is_interface(self) -> Bool:
        """Return True for an interface type.

        Returns:
            Whether the kind is an interface definition or extension.
        """
        return (
            self.kind == Kind.INTERFACE_TYPE_DEFINITION
            or self.kind == Kind.INTERFACE_TYPE_EXTENSION
        )

    def find_field(self, document: Document, name: StringSlice) -> Int:
        """Return the first field with a name.

        Args:
            document: The document that holds the fields.
            name: The name of the field.

        Returns:
            The field definition node, or `NO_NODE`.
        """
        var index = 0
        while index < len(self.fields):
            if document.name(self.fields[index]) == name:
                return self.fields[index]
            index += 1
        return NO_NODE

    def implements(self, document: Document, name: StringSlice) -> Bool:
        """Return True if a part implements an interface.

        Args:
            document: The document that holds the nodes.
            name: The name of the interface.

        Returns:
            Whether some `implements` names it.
        """
        for item in self.interfaces:
            if document.name(item) == name:
                return True
        return False


def is_object_or_interface(kind: Kind) -> Bool:
    """Return True for an object or interface definition or extension.

    Args:
        kind: A node kind.

    Returns:
        Whether it is one of the four kinds.
    """
    return (
        kind == Kind.OBJECT_TYPE_DEFINITION
        or kind == Kind.OBJECT_TYPE_EXTENSION
        or kind == Kind.INTERFACE_TYPE_DEFINITION
        or kind == Kind.INTERFACE_TYPE_EXTENSION
    )


struct SubgraphContext(Movable):
    """The validation context of one subgraph, as upstream
    `SubgraphValidationContext`."""

    var document: Document
    """The subgraph's document; spec definitions are added after the
    walk."""
    var definitions: List[Int]
    """The definitions of the subgraph, in order."""
    var name: String
    """The name of the subgraph."""
    var id: String
    """The id of the subgraph."""
    var version: FederationVersion
    """The federation version."""
    var imports: List[LinkImport]
    """The imports of the federation link."""
    var available: SpecSchema
    """The federation definitions that the subgraph can use."""
    var known: SpecSchema
    """Every federation definition of the version."""
    var merged: List[MergedType]
    """The object and interface types, in order of first appearance."""
    var merged_index: Dict[String, Int]
    """The index in `merged` of each name."""
    var union_names: List[String]
    """The union types, in order of first appearance."""
    var union_members: List[StringSet]
    """The members of each union type of `union_names`."""
    var union_index: Dict[String, Int]
    """The index in `union_names` of each name."""
    var directive_definitions: Dict[String, Int]
    """The last directive definition of each name in the subgraph."""
    var leaf_types: Dict[String, Bool]
    """The specified scalars and the scalar and enum types."""
    var errors: List[CompositionError]
    """The reported errors, in order."""
    var marked_as_external: OrderedSet
    """The `Type.field` coordinates with `@external`."""
    var marked_as_used: OrderedSet
    """The coordinates that a federation directive uses."""
    var marked_as_key_field: OrderedSet
    """The coordinates that a `@key` selects."""
    var replacements: OrderedSet
    """The federation definitions that the subgraph defines itself."""
    var directive_alternatives: List[StringSet]
    """The names under which each federation directive is available."""
    var directive_alternative_index: Dict[String, Int]
    """The index in `directive_alternatives` of each normalized name."""
    var type_alternatives: List[StringSet]
    """The names under which each federation type is available."""
    var type_alternative_index: Dict[String, Int]
    """The index in `type_alternatives` of each normalized name."""
    var directive_masks: Dict[String, Int]
    """For each local directive name, a bit per `SPEC_DIRECTIVES` entry
    that it is available as."""
    var state: SubgraphState
    """The state that the walk builds."""
    var info: TypeNodeInfo
    """Where the walk is."""

    def __init__(
        out self,
        var document: Document,
        var definitions: List[Int],
        name: String,
        id: String,
        version: FederationVersion,
        var imports: List[LinkImport],
        var available: SpecSchema,
        var known: SpecSchema,
        var state: SubgraphState,
    ):
        """Index a subgraph, as upstream
        `createSubgraphValidationContext`.

        Args:
            document: The subgraph's document.
            definitions: Its definitions, in order.
            name: The name of the subgraph.
            id: The id of the subgraph.
            version: The federation version.
            imports: The imports of the federation link.
            available: The definitions that the subgraph can use.
            known: Every definition of the version.
            state: The state to build.
        """
        self.document = document^
        self.definitions = definitions^
        self.name = name
        self.id = id
        self.version = version
        self.imports = imports^
        self.available = available^
        self.known = known^
        self.merged = List[MergedType]()
        self.merged_index = Dict[String, Int]()
        self.union_names = List[String]()
        self.union_members = List[StringSet]()
        self.union_index = Dict[String, Int]()
        self.directive_definitions = Dict[String, Int]()
        self.leaf_types = Dict[String, Bool]()
        self.errors = List[CompositionError]()
        self.marked_as_external = OrderedSet()
        self.marked_as_used = OrderedSet()
        self.marked_as_key_field = OrderedSet()
        self.replacements = OrderedSet()
        self.directive_alternatives = List[StringSet]()
        self.directive_alternative_index = Dict[String, Int]()
        self.type_alternatives = List[StringSet]()
        self.type_alternative_index = Dict[String, Int]()
        self.directive_masks = Dict[String, Int]()
        self.state = state^
        self.info = TypeNodeInfo()
        self._index_types()
        self._index_alternatives()
        self._index_masks()

    def _index_types(mut self):
        """Merge the object, interface and union types, and find the
        directive definitions, the leaf types and the replaced federation
        types."""
        ref document = self.document
        for definition in self.definitions:
            var kind = document.kind(definition)
            var name = String(document.name(definition))
            if (
                kind == Kind.UNION_TYPE_DEFINITION
                or kind == Kind.UNION_TYPE_EXTENSION
            ):
                if name not in self.union_index:
                    self.union_index[name] = len(self.union_names)
                    self.union_names.append(name)
                    self.union_members.append(StringSet())
                var at = self.union_index.get(name).value()
                var member = document.first_child(definition)
                while member != NO_NODE:
                    if document.role(member) == Role.MEMBER_TYPE:
                        self.union_members[at].add(
                            String(document.name(member))
                        )
                    member = document.next_sibling(member)
            elif is_object_or_interface(kind):
                if name not in self.merged_index:
                    self.merged_index[name] = len(self.merged)
                    self.merged.append(MergedType(name, kind))
                var at = self.merged_index.get(name).value()
                ref merged = self.merged[at]
                var child = document.first_child(definition)
                while child != NO_NODE:
                    var role = document.role(child)
                    if role == Role.FIELD:
                        merged.fields.append(child)
                    elif role == Role.INTERFACE:
                        merged.interfaces.append(child)
                    elif role == Role.DIRECTIVE:
                        merged.directives.append(child)
                    child = document.next_sibling(child)
                if (
                    kind == Kind.OBJECT_TYPE_DEFINITION
                    and merged.kind == Kind.OBJECT_TYPE_EXTENSION
                ):
                    merged.kind = Kind.OBJECT_TYPE_DEFINITION
                elif (
                    kind == Kind.INTERFACE_TYPE_DEFINITION
                    and merged.kind == Kind.INTERFACE_TYPE_EXTENSION
                ):
                    merged.kind = Kind.INTERFACE_TYPE_DEFINITION
            elif kind == Kind.DIRECTIVE_DEFINITION:
                self.directive_definitions[name] = definition
            if (
                kind == Kind.SCALAR_TYPE_DEFINITION
                or kind == Kind.SCALAR_TYPE_EXTENSION
                or kind == Kind.ENUM_TYPE_DEFINITION
                or kind == Kind.ENUM_TYPE_EXTENSION
            ):
                self.leaf_types[name] = True
            if self.available.has_type(name):
                self.replacements.add(name)

    def _index_alternatives(mut self):
        """Find the names under which each federation directive and type is
        available, as upstream `directiveAlternativeNamesMap` and
        `typeAlternativeNamesMap`."""
        # Every federation version has directives.
        var directive_index = 0
        while directive_index < len(self.available.directives):
            ref definition = self.available.directives[directive_index]
            directive_index += 1
            if definition.name.startswith("federation__"):
                var normalized = String(definition.name[byte=12:])
                if normalized not in self.directive_alternative_index:
                    var names = StringSet()
                    names.add(definition.name)
                    self.directive_alternative_index[normalized] = len(
                        self.directive_alternatives
                    )
                    self.directive_alternatives.append(names^)
                continue
            var local = definition.name
            for ref item in self.imports:
                if strip_at(item.name) == definition.name:
                    if item.alias:
                        local = strip_at(item.alias.value())
                    break
            _add_alternative(
                self.directive_alternatives,
                self.directive_alternative_index,
                definition.name,
                local,
            )
        for ref definition in self.available.types:
            if definition.name.startswith("federation__"):
                var normalized = String(definition.name[byte=12:])
                if normalized not in self.type_alternative_index:
                    var names = StringSet()
                    names.add(definition.name)
                    self.type_alternative_index[normalized] = len(
                        self.type_alternatives
                    )
                    self.type_alternatives.append(names^)
                continue
            var local = definition.name
            for ref item in self.imports:
                if item.name == definition.name:
                    if item.alias:
                        local = item.alias.value()
                    break
            _add_alternative(
                self.type_alternatives,
                self.type_alternative_index,
                definition.name,
                local,
            )

    def _index_masks(mut self):
        """Find the bits of `directive_masks`."""
        var names = materialize[SPEC_DIRECTIVES]()
        var index = 0
        while index < 18:
            var found = self.directive_alternative_index.get(
                String(names[index])
            )
            if found:
                ref alternatives = self.directive_alternatives[
                    found.value()
                ].items
                var position = 0
                while position < len(alternatives):
                    var name = alternatives[position]
                    self.directive_masks[name] = self.directive_masks.get(
                        name, 0
                    ) | (1 << index)
                    position += 1
            index += 1

    def directive_mask(self, name: StringSlice) -> Int:
        """Return the federation directives that a local directive name is
        available as.

        Args:
            name: The name in the subgraph.

        Returns:
            A bit per entry of `SPEC_DIRECTIVES`.
        """
        var found = self.directive_masks.get(String(name))
        if found:
            return found.value()
        return 0

    # --- lookups ----------------------------------------------------------

    def is_available_directive(
        self, spec_name: StringSlice, name: StringSlice
    ) -> Bool:
        """Return True if a directive name is the federation directive
        `spec_name` in this subgraph, as upstream
        `isAvailableFederationDirective`.

        Args:
            spec_name: The name in the specification, such as `key`.
            name: The name in the subgraph, such as `federation__key`.

        Returns:
            Whether the subgraph can use the directive under that name.
        """
        var found = self.directive_alternative_index.get(String(spec_name))
        if not found:
            return False
        return self.directive_alternatives[found.value()].contains(name)

    def is_available_type(self, name: StringSlice) -> Bool:
        """Return True if a federation type is available under its own
        name, as upstream `isAvailableFederationType`.

        Args:
            name: The name in the specification, such as `FieldSet`.

        Returns:
            Whether the subgraph can use the type under that name.
        """
        var found = self.type_alternative_index.get(String(name))
        if not found:
            return False
        return self.type_alternatives[found.value()].contains(name)

    def is_leaf_type(self, name: StringSlice) -> Bool:
        """Return True for a specified scalar, a scalar or an enum type.

        Args:
            name: A type name.

        Returns:
            Whether it is a leaf type of the subgraph.
        """
        return is_specified_scalar(name) or String(name) in self.leaf_types

    def merged_type(self, name: StringSlice) -> Int:
        """Return the merged object or interface type with a name.

        Args:
            name: The name.

        Returns:
            The index in `merged`, or -1.
        """
        var found = self.merged_index.get(String(name))
        if found:
            return found.value()
        return -1

    def union_type(self, name: StringSlice) -> Int:
        """Return the union type with a name.

        Args:
            name: The name.

        Returns:
            The index in `union_names`, or -1.
        """
        var found = self.union_index.get(String(name))
        if found:
            return found.value()
        return -1

    # --- reports and marks --------------------------------------------------

    def report(mut self, message: String, code: ErrorCode):
        """Report an error, as upstream `reportError`.

        Args:
            message: The message.
            code: The `extensions.code`.
        """
        self.errors.append(CompositionError(message, code, None))

    def mark_as_used(
        mut self,
        by_fields: Bool,
        is_interface: Bool,
        type_name: String,
        field_name: String,
    ) raises:
        """Mark a field as used by a federation directive, as upstream
        `markAsUsed`.

        Args:
            by_fields: True for the upstream reason `fields`.
            is_interface: Whether the type is an interface type.
            type_name: The name of the type.
            field_name: The name of the field.

        Raises:
            Error: When the state has another kind of type with the name.
        """
        if (
            by_fields
            and not field_name.startswith("__")
            and not type_name.startswith("__")
        ):
            var at = self.state.owner_field(type_name, field_name, is_interface)
            self.state.types[at.type].fields[at.field].used = True
        self.marked_as_used.add(type_name + "." + field_name)

    def fields_to_mark_as_shareable(self) -> List[String]:
        """Return the key fields of object types, as upstream
        `getFieldsToMarkAsShareable`.

        Returns:
            The `Type.field` coordinates, in order.
        """
        # A key field set names the fields of a merged type.
        var out = List[String]()
        for ref coordinate in self.marked_as_key_field.items:
            var at = self.merged_index.get(_before_dot(coordinate), 0)
            if self.merged[at].is_object():
                out.append(coordinate)
        return out^

    def collect_unused_external(self) -> List[String]:
        """Return the `@external` fields that nothing uses, as upstream
        `collectUnusedExternal`.

        Returns:
            The `Type.field` coordinates, in order.
        """
        # Upstream keeps a `v1.0` field only when it is a key field. A key
        # field is always marked as used first, so `v1.0` keeps nothing.
        var out = List[String]()
        for ref coordinate in self.marked_as_external.items:
            if self.marked_as_used.contains(coordinate):
                continue
            if self.version == FederationVersion.V1_0:
                continue
            if self._is_external_needed(coordinate):
                continue
            out.append(coordinate)
        return out^

    def _is_external_needed(self, coordinate: String) -> Bool:
        """Return True when an unused `@external` field still has a use: a
        `@shareable` output type or an interface field."""
        # An `@external` field is a field of a type in the state. The state
        # keeps an `@interfaceObject` as an interface type, and it makes an
        # interface type for each name in `implements`, or raises when the
        # name has another kind.
        var type_name = _before_dot(coordinate)
        var field_name = _after_dot(coordinate)
        ref type = self.state.types[self.state.find_type(type_name)]
        if type.kind != TypeKind.OBJECT:
            return False
        var field = type.find_field(field_name)
        var output = self.state.find_type(
            strip_type_modifiers(type.fields[field].type)
        )
        if (
            output != -1
            and self.state.types[output].kind == TypeKind.OBJECT
            and self.state.types[output].shareable
        ):
            return True
        for ref interface_name in type.interfaces.items:
            ref interface = self.state.types[
                self.state.find_type(interface_name)
            ]
            if interface.find_field(field_name) != -1:
                return True
        return False


def _add_alternative(
    mut sets: List[StringSet],
    mut index: Dict[String, Int],
    name: String,
    local: String,
):
    """Add the local name and the prefixed name of an unprefixed federation
    definition to its set of alternative names. A specification names
    each definition once, so the set is new."""
    var names = StringSet()
    names.add(local)
    names.add("federation__" + name)
    index[name] = len(sets)
    sets.append(names^)


def _before_dot(coordinate: String) -> String:
    """Return the part of `Type.field` before the dot. A coordinate always
    has one dot."""
    return String(coordinate[byte = : coordinate.find(".")])


def _after_dot(coordinate: String) -> String:
    """Return the part of `Type.field` after the dot, as upstream
    `coordinate.split(".")[1]`. A coordinate always has one dot."""
    return String(coordinate[byte = coordinate.find(".") + 1 :])


def strip_type_modifiers(type: StringSlice) -> String:
    """Return a printed type without `!`, `[` and `]`, as upstream
    `stripTypeModifiers`.

    Args:
        type: A printed type such as `[ID!]!`.

    Returns:
        The named type, such as `ID`.
    """
    var out = List[UInt8](capacity=type.byte_length())
    var bytes = type.as_bytes()
    # A printed type is never empty.
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        index += 1
        if byte != 33 and byte != 91 and byte != 93:
            out.append(byte)
    return String(unsafe_from_utf8=out)
