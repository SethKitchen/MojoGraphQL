# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Build a schema from SDL.

Port of graphql-js 16.14.2 `utilities/buildASTSchema.ts` (`buildASTSchema`,
`buildSchema`), `utilities/extendSchema.ts` (`extendSchema`), and the type collection of the `GraphQLSchema`
constructor in `type/schema.ts`. The types, fields, values and directives
come out in the same order as in graphql-js, so a printed schema and an
introspection result are the same.

**Differences from graphql-js.**

- A default value is kept as its literal, not as a coerced JavaScript value;
  `print_schema` coerces it when it prints it.
- `extend_schema` returns a copy when the document changes nothing, where
  graphql-js returns the same object. A Mojo schema is a value.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role, role_bit
from gql_language.directive_location import DirectiveLocation
from gql_language.parser import ParseOptions, parse
from gql_language.printer import print_node
from gql_language.scan import string_from_utf8
from gql_language.source import Source
from gql_schema.builtins import BUILTIN_SDL, DEFAULT_DEPRECATION_REASON
from gql_schema.definition import (
    HASHED_MEMBERS,
    NO_TYPE,
    AstRef,
    DirectiveDef,
    EnumValueDef,
    FieldDef,
    InputValueDef,
    NamedType,
    Range,
    Schema,
    TypeKind,
    TypeRef,
)
from gql_language.names import NOT_FOUND, NameTable
from gql_schema.sdl_validation import (
    assert_valid_sdl,
    assert_valid_sdl_extension,
)

comptime _BUILTIN_DOCUMENT = 0


@fieldwise_init
struct BuildOptions(Copyable, ImplicitlyCopyable, Movable):
    """Options of `build_schema`, as graphql-js `BuildSchemaOptions`."""

    var parse_options: ParseOptions
    """Options for parsing the SDL."""
    var assume_valid_sdl: Bool
    """Skip the SDL validation, as graphql-js `assumeValidSDL`."""
    var assume_valid: Bool
    """Assume that the schema is valid, as graphql-js `assumeValid`: the
    SDL validation is skipped too."""

    def __init__(out self):
        """Return the graphql-js defaults."""
        self.parse_options = ParseOptions()
        self.assume_valid_sdl = False
        self.assume_valid = False

    def skips_sdl_validation(self) -> Bool:
        """Return True when the SDL is not checked.

        Returns:
            Whether `assume_valid` or `assume_valid_sdl` is set.
        """
        return self.assume_valid or self.assume_valid_sdl


def _kind_of(kind: Kind) -> TypeKind:
    """Return the type kind a type definition node defines."""
    if kind == Kind.SCALAR_TYPE_DEFINITION:
        return TypeKind.SCALAR
    if kind == Kind.OBJECT_TYPE_DEFINITION:
        return TypeKind.OBJECT
    if kind == Kind.INTERFACE_TYPE_DEFINITION:
        return TypeKind.INTERFACE
    if kind == Kind.UNION_TYPE_DEFINITION:
        return TypeKind.UNION
    if kind == Kind.ENUM_TYPE_DEFINITION:
        return TypeKind.ENUM
    return TypeKind.INPUT_OBJECT


comptime _Documents = Pointer[Document, UntrackedOrigin[mut=True]]


struct _Builder(Movable):
    """The definitions of the documents, and the schema built from them.

    The documents do not change while a schema is built, so they are read
    through `docs`, a pointer taken once; that lets a method read a
    document while it adds to the schema. They move into the schema at the
    end.
    """

    var documents: List[Document]
    var docs: _Documents
    var schema: Schema
    var pending: NameTable
    var config_types: List[Int]
    var config_position: List[Int]
    var extension_names: NameTable
    var extension_lists: List[List[AstRef]]
    var directive_extension_names: NameTable
    var directive_extension_lists: List[List[AstRef]]
    var directive_defs: List[AstRef]
    var schema_def: AstRef
    var schema_extensions: List[AstRef]
    var first_document: Int
    var type_defs: Int
    var stack: List[Int]
    var redefinitions: Int

    def __init__(out self, var documents: List[Document]) raises:
        """Hold the built-ins and the documents.

        Args:
            documents: The SDL documents, in order.

        Raises:
            Error: Never; the built-in SDL is valid.
        """
        self.schema = Schema()
        self.pending = NameTable()
        self.config_types = List[Int]()
        self.config_position = List[Int]()
        self.extension_names = NameTable()
        self.extension_lists = List[List[AstRef]]()
        self.directive_extension_names = NameTable()
        self.directive_extension_lists = List[List[AstRef]]()
        self.directive_defs = List[AstRef]()
        self.schema_def = AstRef.NONE
        self.schema_extensions = List[AstRef]()
        self.first_document = 1
        self.type_defs = 0
        self.stack = List[Int](capacity=64)
        self.redefinitions = 0
        # The documents move in, after the built-ins; none is copied.
        documents.insert(0, parse(BUILTIN_SDL))
        self.documents = documents^
        # Room for every name the documents can define, so no table grows,
        # and no larger: a small table stays in the cache.
        var nodes = 0
        var definitions = 0
        var index = 0
        while index < len(self.documents):
            ref document = self.documents[index]
            nodes += len(document.nodes)
            var current = document.first_child(document.root)
            while current != NO_NODE:
                definitions += 1
                current = document.next_sibling(current)
            index += 1
        self.schema.reserve(nodes, definitions)
        self.pending = NameTable(capacity=definitions)
        self.config_position.reserve(definitions + 16)
        self.docs = self.documents.unsafe_ptr().unsafe_origin_cast[
            UntrackedOrigin[mut=True]
        ]()

    def __init__(out self, var base: Schema, var document: Document):
        """Hold a schema and one more document, to extend the schema.

        The type map seeds the type configuration, as `extendSchemaImpl`
        seeds its type map with `schemaConfig.types`.

        Args:
            base: The schema to extend.
            document: The SDL document with the extensions.
        """
        self.schema = base^
        self.documents = List[Document]()
        swap(self.documents, self.schema.documents)
        self.first_document = len(self.documents)
        self.documents.append(document^)
        self.docs = self.documents.unsafe_ptr().unsafe_origin_cast[
            UntrackedOrigin[mut=True]
        ]()
        self.pending = NameTable()
        self.config_types = List[Int]()
        self.config_position = List[Int]()
        self.extension_names = NameTable()
        self.extension_lists = List[List[AstRef]]()
        self.directive_extension_names = NameTable()
        self.directive_extension_lists = List[List[AstRef]]()
        self.directive_defs = List[AstRef]()
        self.schema_def = AstRef.NONE
        self.schema_extensions = List[AstRef]()
        self.type_defs = 0
        self.stack = List[Int](capacity=64)
        self.redefinitions = 0
        var type = 0
        while type < len(self.schema.types):
            if self.schema.types[type].is_builtin:
                _ = self.pending.insert(-1, self.schema.types[type].name, type)
            type += 1
        self.config_position = List[Int](length=len(self.schema.types), fill=-1)
        var position = 0
        while position < len(self.schema.type_map):
            var mapped = Int(self.schema.type_map[position])
            self.pending.assign(-1, self.schema.types[mapped].name, mapped)
            self.config_position[mapped] = len(self.config_types)
            self.config_types.append(mapped)
            position += 1

    # --- reading the documents --------------------------------------------

    def is_live(self, type: Int) -> Bool:
        """Return True for a built-in, or for the type that holds its name;
        a later definition of a name drops the earlier type."""
        if self.redefinitions == 0:
            return True
        ref named = self.schema.types[type]
        return named.is_builtin or self.pending.find(-1, named.name) == type

    def collect(mut self):
        """Sort the new documents' definitions, as `extendSchemaImpl`."""
        for index in range(self.first_document, len(self.documents)):
            ref document = self.docs[unsafe_offset=index]
            var current = document.first_child(document.root)
            while current != NO_NODE:
                var at = AstRef(Int32(index), Int32(current))
                var kind = document.kind(current)
                if kind == Kind.SCHEMA_DEFINITION:
                    self.schema_def = at
                elif kind == Kind.SCHEMA_EXTENSION:
                    self.schema_extensions.append(at)
                elif kind.is_type_definition():
                    self.type_defs += 1
                    self.add_type_definition(at)
                elif kind.is_type_extension():
                    _append_to(
                        self.extension_names,
                        self.extension_lists,
                        document.name(current),
                        at,
                    )
                elif kind == Kind.DIRECTIVE_DEFINITION:
                    self.directive_defs.append(at)
                elif kind == Kind.DIRECTIVE_EXTENSION:
                    _append_to(
                        self.directive_extension_names,
                        self.directive_extension_lists,
                        document.name(current),
                        at,
                    )
                current = document.next_sibling(current)

    def add_builtins(mut self):
        """Create the specified scalars and the introspection types."""
        ref document = self.docs[unsafe_offset=_BUILTIN_DOCUMENT]
        var current = document.first_child(document.root)
        while current != NO_NODE:
            if document.kind(current).is_type_definition():
                var type = self.new_type(
                    AstRef(_BUILTIN_DOCUMENT, Int32(current))
                )
                self.schema.types[type].is_builtin = True
                _ = self.pending.insert(-1, document.name(current), type)
            current = document.next_sibling(current)

    def new_type(mut self, at: AstRef) -> Int:
        """Create a type from its definition node, with no members yet."""
        ref document = self.docs[unsafe_offset=Int(at.document)]
        var node = Int(at.node)
        var type = NamedType(
            _name(document, node), _kind_of(document.kind(node))
        )
        type.definition = at
        type.description = _description_of(Int(at.document), document, node)
        self.schema.types.append(type^)
        self.config_position.append(-1)
        return len(self.schema.types) - 1

    def add_type_definition(mut self, at: AstRef):
        """Put a user type definition in the type map, as `typeMap[name] =
        stdTypeMap[name] ?? buildType(node)`.

        A later definition of a name replaces the earlier one in its place,
        as a JavaScript object key keeps its first position.
        """
        ref document = self.docs[unsafe_offset=Int(at.document)]
        var name = document.name(Int(at.node))
        var existing = self.pending.find_or_insert(
            -1, name, len(self.schema.types)
        )
        var type: Int
        var position = -1
        if existing == NOT_FOUND:
            type = self.new_type(at)
        elif self.schema.types[existing].is_builtin:
            type = existing
            position = self.config_position[existing]
        else:
            self.redefinitions += 1
            position = self.config_position[existing]
            type = self.new_type(at)
            self.pending.assign(-1, name, type)
        if position < 0:
            self.config_position[type] = len(self.config_types)
            self.config_types.append(type)
        else:
            self.config_types[position] = type
            self.config_position[type] = position

    # --- types and values -------------------------------------------------

    def resolve(self, document: Document, node: Int) raises -> TypeRef:
        """Return the type a type reference node names.

        Raises:
            Error: `Unknown type: "X".` for a name with no type.
        """
        var depth = 0
        var bits: UInt32 = 0
        var current = node
        while document.kind(current) != Kind.NAMED_TYPE:
            if document.kind(current) == Kind.LIST_TYPE:
                bits |= UInt32(1) << UInt32(depth)
            depth += 1
            current = document.child(current, Role.TYPE)
        var name = document.name(current)
        var named = self.pending.find(-1, name)
        if named == NOT_FOUND:
            raise Error('Unknown type: "' + String(name) + '".')
        return TypeRef(Int32(named), UInt8(depth), bits)

    def applied_directives(mut self, document_index: Int, node: Int) -> Range:
        """Record a node's applied directives; return their range."""
        ref document = self.docs[unsafe_offset=document_index]
        var start = len(self.schema.applied)
        # `child` reads the node's role mask, so a node with no directive
        # costs one load.
        var current = document.child(node, Role.DIRECTIVE)
        while current != NO_NODE:
            if document.role(current) == Role.DIRECTIVE:
                self.schema.applied.append(
                    AstRef(Int32(document_index), Int32(current))
                )
            current = document.next_sibling(current)
        return Range(Int32(start), Int32(len(self.schema.applied) - start))

    def input_value(
        mut self, document_index: Int, node: Int
    ) raises -> InputValueDef:
        """Build an argument or input field from its definition node.

        The node's role mask says which children it has, so a value with
        no description, default or directive reads none of them.
        """
        ref document = self.docs[unsafe_offset=document_index]
        var roles = document._node(node).roles
        var parts = _gather(document, node)
        var value = InputValueDef(
            _text(document, parts.name), self.resolve(document, parts.type)
        )
        value.definition = AstRef(Int32(document_index), Int32(node))
        if roles & role_bit(Role.DESCRIPTION) != 0:
            value.description = _description_of(document_index, document, node)
        if roles & role_bit(Role.DEFAULT_VALUE) != 0:
            value.default_value = AstRef(
                Int32(document_index),
                Int32(document.child(node, Role.DEFAULT_VALUE)),
            )
        if roles & role_bit(Role.DIRECTIVE) != 0:
            var reason = _deprecation_reason(document, node)
            if reason:
                value.deprecation_reason = reason.value()
                value.is_deprecated = True
            value.directives = self.applied_directives(document_index, node)
        else:
            value.directives = Range(Int32(len(self.schema.applied)), 0)
        return value^

    def place_input_value(
        mut self,
        key: Int,
        by_argument: Bool,
        start: Int,
        var value: InputValueDef,
    ):
        """Append an input value of an owner whose values start at `start`,
        or replace the one with its name, as a JavaScript object key keeps
        its first place.

        An owner's values are searched one at a time until it has
        `HASHED_MEMBERS` of them; from then on they are in a name table.
        """
        var count = len(self.schema.input_values) - start
        var existing = NOT_FOUND
        if count < HASHED_MEMBERS:
            var values = self.schema.input_values.unsafe_ptr()
            var index = start
            while index < start + count:
                if values[unsafe_offset=index].name == value.name:
                    existing = index
                index += 1
        elif by_argument:
            existing = self.schema._argument_names.find(key, value.name)
        else:
            existing = self.schema._member_names.find(key, value.name)
        # A name below `start` belongs to a replaced field's arguments.
        if existing >= start:
            self.schema.input_values[existing] = value^
            return
        var index = len(self.schema.input_values)
        self.schema.input_values.append(value^)
        count += 1
        var first = index
        if count == HASHED_MEMBERS:
            first = start
        if count >= HASHED_MEMBERS:
            var member = first
            while member <= index:
                ref name = self.schema.input_values[member].name
                if by_argument:
                    self.schema._argument_names.assign(key, name, member)
                else:
                    self.schema._member_names.assign(key, name, member)
                member += 1

    def add_input_values(
        mut self,
        owner: Int,
        for_directive: Bool,
        document_index: Int,
        node: Int,
        role: Role,
        mut start: Int,
    ) raises:
        """Append the input values of one node, replacing a repeated name
        in place, as `buildArgumentMap` and `buildInputFieldMap` do."""
        ref document = self.docs[unsafe_offset=document_index]
        # Directive arguments are keyed as `directive_argument_named` keys
        # them.
        self.add_values_from(
            owner,
            for_directive,
            document_index,
            document.child(node, role),
            role,
            start,
        )

    def add_values_from(
        mut self,
        owner: Int,
        for_directive: Bool,
        document_index: Int,
        first: Int,
        role: Role,
        mut start: Int,
    ) raises:
        """Append the input values with a role among `first` and its next
        siblings; see `add_input_values`."""
        ref document = self.docs[unsafe_offset=document_index]
        var key = owner
        if for_directive:
            key = -2 - owner
        # The values with a role are next to each other, so the run ends at
        # the first child with another role.
        var child = first
        while child != NO_NODE and document.role(child) == role:
            self.place_input_value(
                key,
                role == Role.ARGUMENT,
                start,
                self.input_value(document_index, child),
            )
            child = document.next_sibling(child)

    def nodes_of(self, type: Int) -> List[AstRef]:
        """Return a type's definition node and its extension nodes."""
        var out: List[AstRef] = [self.schema.types[type].definition]
        if self.schema.types[type].is_builtin or len(self.extension_lists) == 0:
            return out^
        var found = self.extension_names.find(-1, self.schema.types[type].name)
        if found != NOT_FOUND:
            out.extend(self.extension_lists[found].copy())
        return out^

    def fill_type(mut self, type: Int) raises:
        """Build a type's members from its definition and extensions."""
        var nodes = self.nodes_of(type)
        var kind = self.schema.types[type].kind
        # Extension nodes and applied directives, in node order.
        var ext_start = len(self.schema.ast_refs)
        var dir_start = len(self.schema.applied)
        var index = 0
        while index < len(nodes):
            var at = nodes[index]
            if index > 0:
                self.schema.ast_refs.append(at)
            _ = self.applied_directives(Int(at.document), Int(at.node))
            index += 1
        self.schema.types[type].extensions = Range(
            Int32(ext_start), Int32(len(self.schema.ast_refs) - ext_start)
        )
        self.schema.types[type].directives = Range(
            Int32(dir_start), Int32(len(self.schema.applied) - dir_start)
        )
        var definition = nodes[0]
        ref first_document = self.docs[unsafe_offset=Int(definition.document)]
        if kind == TypeKind.SCALAR:
            var url = _directive_string_argument(
                first_document, Int(definition.node), "specifiedBy", "url"
            )
            if url:
                self.schema.types[type].specified_by_url = url.value()
                self.schema.types[type].has_specified_by_url = True
            return
        if kind == TypeKind.INPUT_OBJECT:
            self.schema.types[type].is_one_of = _has_directive(
                first_document, Int(definition.node), "oneOf"
            )
        var values_start = len(self.schema.input_values)
        var enum_start = len(self.schema.enum_values)
        var list_start = len(self.schema.type_lists)
        var field_start = len(self.schema.fields)
        # Interfaces first, then fields: graphql-js resolves the interfaces
        # of a type before its fields.
        if kind.has_fields():
            index = 0
            while index < len(nodes):
                var at = nodes[index]
                self.add_type_list(
                    Int(at.document), Int(at.node), Role.INTERFACE
                )
                index += 1
        index = 0
        while index < len(nodes):
            var at = nodes[index]
            var document_index = Int(at.document)
            var node = Int(at.node)
            if kind == TypeKind.INPUT_OBJECT:
                self.add_input_values(
                    type, False, document_index, node, Role.FIELD, values_start
                )
            elif kind == TypeKind.ENUM:
                self.add_enum_values(type, document_index, node, enum_start)
            elif kind == TypeKind.UNION:
                self.add_type_list(document_index, node, Role.MEMBER_TYPE)
            else:
                self.add_fields(type, document_index, node, field_start)
            index += 1
        ref named = self.schema.types[type]
        if kind == TypeKind.INPUT_OBJECT:
            named.input_fields = Range(
                Int32(values_start),
                Int32(len(self.schema.input_values) - values_start),
            )
        elif kind == TypeKind.ENUM:
            named.enum_values = Range(
                Int32(enum_start),
                Int32(len(self.schema.enum_values) - enum_start),
            )
        elif kind == TypeKind.UNION:
            named.members = Range(
                Int32(list_start),
                Int32(len(self.schema.type_lists) - list_start),
            )
        else:
            named.interfaces = Range(
                Int32(list_start),
                Int32(len(self.schema.type_lists) - list_start),
            )
            named.fields = Range(
                Int32(field_start), Int32(len(self.schema.fields) - field_start)
            )

    def add_type_list(
        mut self, document_index: Int, node: Int, role: Role
    ) raises:
        """Append the named types of a node's interfaces or union members."""
        ref document = self.docs[unsafe_offset=document_index]
        var current = document.child(node, role)
        while current != NO_NODE:
            if document.role(current) == role:
                var ref_ = self.resolve(document, current)
                self.schema.type_lists.append(ref_.named)
            current = document.next_sibling(current)

    def place_enum_value(
        mut self, type: Int, start: Int, var value: EnumValueDef
    ):
        """Append an enum value, or replace the one with its name; see
        `place_input_value`."""
        var count = len(self.schema.enum_values) - start
        var existing = NOT_FOUND
        if count < HASHED_MEMBERS:
            var values = self.schema.enum_values.unsafe_ptr()
            var index = start
            while index < start + count:
                if values[unsafe_offset=index].name == value.name:
                    existing = index
                index += 1
        else:
            existing = self.schema._member_names.find(type, value.name)
        if existing >= start:
            self.schema.enum_values[existing] = value^
            return
        var index = len(self.schema.enum_values)
        self.schema.enum_values.append(value^)
        count += 1
        var first = index
        if count == HASHED_MEMBERS:
            first = start
        if count >= HASHED_MEMBERS:
            var member = first
            while member <= index:
                self.schema._member_names.assign(
                    type, self.schema.enum_values[member].name, member
                )
                member += 1

    def add_enum_values(
        mut self, type: Int, document_index: Int, node: Int, start: Int
    ) raises:
        """Append a node's enum values, replacing a repeated name in place."""
        ref document = self.docs[unsafe_offset=document_index]
        var child = document.child(node, Role.ENUM_VALUE)
        # Enum values are the last children of their node.
        while child != NO_NODE:
            var roles = document._node(child).roles
            var value = EnumValueDef(_name(document, child))
            value.definition = AstRef(Int32(document_index), Int32(child))
            if roles & role_bit(Role.DESCRIPTION) != 0:
                value.description = _description_of(
                    document_index, document, child
                )
            if roles & role_bit(Role.DIRECTIVE) != 0:
                var reason = _deprecation_reason(document, child)
                if reason:
                    value.deprecation_reason = reason.value()
                    value.is_deprecated = True
                value.directives = self.applied_directives(
                    document_index, child
                )
            else:
                value.directives = Range(Int32(len(self.schema.applied)), 0)
            self.place_enum_value(type, start, value^)
            child = document.next_sibling(child)

    def place_field(
        mut self, type: Int, start: Int, var field: FieldDef
    ) -> Int:
        """Append a field, or replace the one with its name; return its
        index. See `place_input_value`."""
        var count = len(self.schema.fields) - start
        var existing = NOT_FOUND
        if count < HASHED_MEMBERS:
            var fields = self.schema.fields.unsafe_ptr()
            var index = start
            while index < start + count:
                if fields[unsafe_offset=index].name == field.name:
                    existing = index
                index += 1
        else:
            existing = self.schema._member_names.find(type, field.name)
        if existing >= start:
            self.schema.fields[existing] = field^
            return existing
        var index = len(self.schema.fields)
        self.schema.fields.append(field^)
        count += 1
        var first = index
        if count == HASHED_MEMBERS:
            first = start
        if count >= HASHED_MEMBERS:
            var member = first
            while member <= index:
                self.schema._member_names.assign(
                    type, self.schema.fields[member].name, member
                )
                member += 1
        return index

    def add_fields(
        mut self, type: Int, document_index: Int, node: Int, start: Int
    ) raises:
        """Append a node's fields, replacing a repeated name in place."""
        ref document = self.docs[unsafe_offset=document_index]
        # Fields are the last children of their node.
        var child = document.child(node, Role.FIELD)
        while child != NO_NODE:
            var roles = document._node(child).roles
            var parts = _gather(document, child)
            var field = FieldDef(
                _text(document, parts.name),
                type,
                self.resolve(document, parts.type),
            )
            field.definition = AstRef(Int32(document_index), Int32(child))
            if roles & role_bit(Role.DESCRIPTION) != 0:
                field.description = _description_of(
                    document_index, document, child
                )
            if roles & role_bit(Role.DIRECTIVE) != 0:
                var reason = _deprecation_reason(document, child)
                if reason:
                    field.deprecation_reason = reason.value()
                    field.is_deprecated = True
                field.directives = self.applied_directives(
                    document_index, child
                )
            else:
                field.directives = Range(Int32(len(self.schema.applied)), 0)
            var index = self.place_field(type, start, field^)
            var arg_start = len(self.schema.input_values)
            if parts.argument != NO_NODE:
                self.add_values_from(
                    index,
                    False,
                    document_index,
                    parts.argument,
                    Role.ARGUMENT,
                    arg_start,
                )
            self.schema.fields[index].arguments = Range(
                Int32(arg_start),
                Int32(len(self.schema.input_values) - arg_start),
            )
            child = document.next_sibling(child)

    # --- directives -------------------------------------------------------

    def add_directive(mut self, at: AstRef, builtin: Bool) raises:
        """Build a directive from its definition, as `buildDirective`."""
        var document_index = Int(at.document)
        var node = Int(at.node)
        ref document = self.docs[unsafe_offset=document_index]
        var directive = DirectiveDef(_name(document, node))
        directive.definition = at
        directive.is_builtin = builtin
        directive.is_repeatable = document.is_repeatable(node)
        directive.description = _description_of(document_index, document, node)
        # A definition has at least one location, and the locations are its
        # last children.
        var location = document.child(node, Role.LOCATION)
        while location != NO_NODE:
            var index = DirectiveLocation.from_name(document.text(location))
            directive.locations |= UInt32(1) << UInt32(index)
            location = document.next_sibling(location)
        var reason = _deprecation_reason(document, node)
        if not builtin:
            var found = self.directive_extension_names.find(-1, directive.name)
            if found != NOT_FOUND:
                var start = len(self.schema.ast_refs)
                var extensions = self.directive_extension_lists[found].copy()
                var position = 0
                while position < len(extensions):
                    var extension = extensions[position]
                    self.schema.ast_refs.append(extension)
                    if not reason:
                        reason = _deprecation_reason(
                            self.docs[unsafe_offset=Int(extension.document)],
                            Int(extension.node),
                        )
                    position += 1
                directive.extensions = Range(
                    Int32(start), Int32(len(self.schema.ast_refs) - start)
                )
        if reason:
            directive.deprecation_reason = reason.value()
            directive.is_deprecated = True
        var index = len(self.schema.directives)
        self.schema.directives.append(directive^)
        _ = self.schema.register_directive_name(index)
        var start = len(self.schema.input_values)
        self.add_input_values(
            index, True, document_index, node, Role.ARGUMENT, start
        )
        self.schema.directives[index].arguments = Range(
            Int32(start), Int32(len(self.schema.input_values) - start)
        )

    def add_directives(mut self) raises:
        """Add the user's directives, then the specified ones they do not
        replace, as `buildASTSchema` does."""
        for index in range(len(self.directive_defs)):
            var at = self.directive_defs[index]
            self.add_directive(at, False)
        ref document = self.docs[unsafe_offset=_BUILTIN_DOCUMENT]
        var builtins = List[AstRef]()
        var current = document.first_child(document.root)
        while current != NO_NODE:
            if document.kind(current) == Kind.DIRECTIVE_DEFINITION:
                if (
                    self.schema.directive_named(document.name(current))
                    == NO_TYPE
                ):
                    builtins.append(AstRef(_BUILTIN_DOCUMENT, Int32(current)))
            current = document.next_sibling(current)
        for ref at in builtins:
            self.add_directive(at, True)

    # --- the schema -------------------------------------------------------

    def set_root_types(mut self) raises:
        """Set the root types from `schema` and `extend schema`, or, with
        neither, from the types named Query, Mutation and Subscription."""
        var nodes = List[AstRef]()
        if self.schema_def.exists():
            nodes.append(self.schema_def)
            ref document = self.docs[
                unsafe_offset=Int(self.schema_def.document)
            ]
            var node = Int(self.schema_def.node)
            self.schema.description = _description_of(
                Int(self.schema_def.document), document, node
            )
            self.schema.schema_definition = self.schema_def
        for ref at in self.schema_extensions:
            nodes.append(at)
        var dir_start = len(self.schema.applied)
        for ref at in nodes:
            _ = self.applied_directives(Int(at.document), Int(at.node))
        self.schema.schema_directives = Range(
            Int32(dir_start), Int32(len(self.schema.applied) - dir_start)
        )
        var ext_start = len(self.schema.ast_refs)
        for ref at in self.schema_extensions:
            self.schema.ast_refs.append(at)
        self.schema.schema_extensions = Range(
            Int32(ext_start), Int32(len(self.schema.ast_refs) - ext_start)
        )
        for ref at in nodes:
            ref document = self.docs[unsafe_offset=Int(at.document)]
            for operation in document.children(
                Int(at.node), Role.OPERATION_TYPE
            ):
                var ref_ = self.resolve(
                    document, document.child(operation, Role.TYPE)
                )
                var which = document.operation(operation).value
                if which == 0:
                    self.schema.query_type = ref_.named
                elif which == 1:
                    self.schema.mutation_type = ref_.named
                else:
                    self.schema.subscription_type = ref_.named
        if not self.schema_def.exists():
            for type in self.config_types:
                ref name = self.schema.types[type].name
                if name == "Query":
                    self.schema.query_type = Int32(type)
                elif name == "Mutation":
                    self.schema.mutation_type = Int32(type)
                elif name == "Subscription":
                    self.schema.subscription_type = Int32(type)

    def collect_type_map(mut self):
        """Order the type map as the `GraphQLSchema` constructor does."""
        var count = len(self.schema.types)
        # A JavaScript `Set` with `delete` then `add`: a slot list with
        # holes, and each type's slot.
        var slots = List[Int]()
        var slot_of = List[Int](length=count, fill=-1)
        # The configuration names each type once.
        for type in self.config_types:
            slot_of[type] = len(slots)
            slots.append(type)
        for type in self.config_types:
            slots[slot_of[type]] = -1
            slot_of[type] = -1
            self.collect_from(type, slots, slot_of)
        self.collect_root(self.schema.query_type, slots, slot_of)
        self.collect_root(self.schema.mutation_type, slots, slot_of)
        self.collect_root(self.schema.subscription_type, slots, slot_of)
        var directive = 0
        while directive < len(self.schema.directives):
            var arguments = self.schema.directives[directive].arguments
            for index in range(Int(arguments.start), arguments.end()):
                self.collect_from(
                    Int(self.schema.input_values[index].type.named),
                    slots,
                    slot_of,
                )
            directive += 1
        self.collect_from(self.pending.find(-1, "__Schema"), slots, slot_of)
        var slot = 0
        while slot < len(slots):
            if slots[slot] >= 0:
                _ = self.schema.register_type_name(slots[slot])
            slot += 1

    def collect_root(
        mut self, root: Int32, mut slots: List[Int], mut slot_of: List[Int]
    ):
        """Add a root type and its references, when the root is set."""
        if root != NO_TYPE:
            self.collect_from(Int(root), slots, slot_of)

    def collect_from(
        mut self, start: Int, mut slots: List[Int], mut slot_of: List[Int]
    ):
        """Add a type and the types it references, depth first, as
        `collectReferencedTypes`; types already in the set are skipped.

        A type's references are pushed last first, so the first one is
        visited first, as the recursion of graphql-js visits them.
        """
        # A type that is in the set already is not pushed: its pop would
        # be skipped anyway.
        var seen = slot_of.unsafe_ptr()
        self.stack.append(start)
        while len(self.stack) > 0:
            var type = self.stack.pop()
            if seen[unsafe_offset=type] >= 0:
                continue
            seen[unsafe_offset=type] = len(slots)
            slots.append(type)
            ref named = self.schema.types.unsafe_ptr()[unsafe_offset=type]
            var lists = self.schema.type_lists.unsafe_ptr()
            if named.kind == TypeKind.UNION:
                var index = named.members.end() - 1
                while index >= Int(named.members.start):
                    self.push_unseen(Int(lists[unsafe_offset=index]), slot_of)
                    index -= 1
            elif named.kind.has_fields():
                var fields = self.schema.fields.unsafe_ptr()
                var values = self.schema.input_values.unsafe_ptr()
                var field = named.fields.end() - 1
                while field >= Int(named.fields.start):
                    ref field_def = fields[unsafe_offset=field]
                    var arg = field_def.arguments.end() - 1
                    while arg >= Int(field_def.arguments.start):
                        self.push_unseen(
                            Int(values[unsafe_offset=arg].type.named), slot_of
                        )
                        arg -= 1
                    self.push_unseen(Int(field_def.type.named), slot_of)
                    field -= 1
                var index = named.interfaces.end() - 1
                while index >= Int(named.interfaces.start):
                    self.push_unseen(Int(lists[unsafe_offset=index]), slot_of)
                    index -= 1
            elif named.kind == TypeKind.INPUT_OBJECT:
                var values = self.schema.input_values.unsafe_ptr()
                var field = named.input_fields.end() - 1
                while field >= Int(named.input_fields.start):
                    self.push_unseen(
                        Int(values[unsafe_offset=field].type.named), slot_of
                    )
                    field -= 1

    @always_inline
    def push_unseen(mut self, type: Int, slot_of: List[Int]):
        """Push a type that is not in the set yet."""
        if slot_of.unsafe_ptr()[unsafe_offset=type] < 0:
            self.stack.append(type)

    def add_implementations(mut self):
        """Record, for each interface, the objects and interfaces that
        implement it, in type map order."""
        var count = len(self.schema.types)
        var objects = List[List[Int]](length=count, fill=List[Int]())
        var interfaces = List[List[Int]](length=count, fill=List[Int]())
        var position = 0
        while position < len(self.schema.type_map):
            var type = Int(self.schema.type_map[position])
            position += 1
            ref named = self.schema.types[type]
            if not named.kind.has_fields():
                continue
            for index in range(
                Int(named.interfaces.start), named.interfaces.end()
            ):
                var iface = Int(self.schema.type_lists[index])
                if self.schema.types[iface].kind != TypeKind.INTERFACE:
                    continue
                if named.kind == TypeKind.INTERFACE:
                    interfaces[iface].append(type)
                else:
                    objects[iface].append(type)
        var type = 0
        while type < count:
            self.schema.implementing_objects.append(
                _store(self.schema.type_lists, objects[type])
            )
            self.schema.implementing_interfaces.append(
                _store(self.schema.type_lists, interfaces[type])
            )
            type += 1

    def build(mut self) raises:
        """Build every type, directive and relation."""
        self.add_builtins()
        self.collect()
        var type = 0
        while type < len(self.schema.types):
            if self.is_live(type):
                self.fill_type(type)
            type += 1
        self.add_directives()
        self.set_root_types()
        self.collect_type_map()
        self.add_implementations()

    # --- extending a schema -----------------------------------------------

    def extensions_of(self, type: Int) -> List[AstRef]:
        """Return the new document's extension nodes of a type."""
        var found = self.extension_names.find(-1, self.schema.types[type].name)
        if found == NOT_FOUND:
            return List[AstRef]()
        return self.extension_lists[found].copy()

    def move_members(
        mut self, type: Int, span: Range, enum_values: Bool
    ) -> Int:
        """Copy a type's input fields or enum values to the end of their
        list, and name the copies when the type's names are in a table, so
        new members can follow them; return where the copies start."""
        var hashed = span.count >= HASHED_MEMBERS
        if enum_values:
            var start = len(self.schema.enum_values)
            for index in range(Int(span.start), span.end()):
                var value = self.schema.enum_values[index].copy()
                if hashed:
                    self.schema._member_names.assign(
                        type, value.name, len(self.schema.enum_values)
                    )
                self.schema.enum_values.append(value^)
            return start
        var start = len(self.schema.input_values)
        for index in range(Int(span.start), span.end()):
            var value = self.schema.input_values[index].copy()
            if hashed:
                self.schema._member_names.assign(
                    type, value.name, len(self.schema.input_values)
                )
            self.schema.input_values.append(value^)
        return start

    def move_fields(mut self, type: Int, span: Range) -> Int:
        """Copy a type's fields to the end of the field list, and name the
        copies and their arguments where those names are in tables; return
        where the copies start."""
        var start = len(self.schema.fields)
        for index in range(Int(span.start), span.end()):
            var field = self.schema.fields[index].copy()
            var moved = len(self.schema.fields)
            if span.count >= HASHED_MEMBERS:
                self.schema._member_names.assign(type, field.name, moved)
            if field.arguments.count >= HASHED_MEMBERS:
                var arg = Int(field.arguments.start)
                while arg < field.arguments.end():
                    self.schema._argument_names.assign(
                        moved, self.schema.input_values[arg].name, arg
                    )
                    arg += 1
            self.schema.fields.append(field^)
        return start

    def move_type_list(mut self, span: Range) -> Int:
        """Copy a range of `type_lists` to its end; return the new start."""
        var start = len(self.schema.type_lists)
        for index in range(Int(span.start), span.end()):
            self.schema.type_lists.append(self.schema.type_lists[index])
        return start

    def extend_type(mut self, type: Int) raises:
        """Add the new document's extensions to an existing type, as
        `extendNamedType`: the old members first, then the new ones."""
        var extensions = self.extensions_of(type)
        if len(extensions) == 0:
            return
        var old = self.schema.types[type].copy()
        var ext_start = len(self.schema.ast_refs)
        for index in range(Int(old.extensions.start), old.extensions.end()):
            self.schema.ast_refs.append(self.schema.ast_refs[index])
        var dir_start = len(self.schema.applied)
        for index in range(Int(old.directives.start), old.directives.end()):
            self.schema.applied.append(self.schema.applied[index])
        var index = 0
        while index < len(extensions):
            var at = extensions[index]
            self.schema.ast_refs.append(at)
            _ = self.applied_directives(Int(at.document), Int(at.node))
            index += 1
        self.schema.types[type].extensions = Range(
            Int32(ext_start), Int32(len(self.schema.ast_refs) - ext_start)
        )
        self.schema.types[type].directives = Range(
            Int32(dir_start), Int32(len(self.schema.applied) - dir_start)
        )
        var kind = old.kind
        var values_start = len(self.schema.input_values)
        var enum_start = len(self.schema.enum_values)
        var list_start = len(self.schema.type_lists)
        var field_start = len(self.schema.fields)
        if kind == TypeKind.INPUT_OBJECT:
            values_start = self.move_members(type, old.input_fields, False)
        elif kind == TypeKind.ENUM:
            enum_start = self.move_members(type, old.enum_values, True)
        elif kind == TypeKind.UNION:
            list_start = self.move_type_list(old.members)
        elif kind.has_fields():
            list_start = self.move_type_list(old.interfaces)
            field_start = self.move_fields(type, old.fields)
        index = 0
        while index < len(extensions):
            var at = extensions[index]
            var document_index = Int(at.document)
            var node = Int(at.node)
            if kind == TypeKind.SCALAR:
                var url = _directive_string_argument(
                    self.docs[unsafe_offset=document_index],
                    node,
                    "specifiedBy",
                    "url",
                )
                if url:
                    self.schema.types[type].specified_by_url = url.value()
                    self.schema.types[type].has_specified_by_url = True
            elif kind == TypeKind.INPUT_OBJECT:
                self.add_input_values(
                    type, False, document_index, node, Role.FIELD, values_start
                )
            elif kind == TypeKind.ENUM:
                self.add_enum_values(type, document_index, node, enum_start)
            elif kind == TypeKind.UNION:
                self.add_type_list(document_index, node, Role.MEMBER_TYPE)
            else:
                self.add_type_list(document_index, node, Role.INTERFACE)
                self.add_fields(type, document_index, node, field_start)
            index += 1
        ref named = self.schema.types[type]
        if kind == TypeKind.INPUT_OBJECT:
            named.input_fields = Range(
                Int32(values_start),
                Int32(len(self.schema.input_values) - values_start),
            )
        elif kind == TypeKind.ENUM:
            named.enum_values = Range(
                Int32(enum_start),
                Int32(len(self.schema.enum_values) - enum_start),
            )
        elif kind == TypeKind.UNION:
            named.members = Range(
                Int32(list_start),
                Int32(len(self.schema.type_lists) - list_start),
            )
        elif kind.has_fields():
            named.interfaces = Range(
                Int32(list_start),
                Int32(len(self.schema.type_lists) - list_start),
            )
            named.fields = Range(
                Int32(field_start), Int32(len(self.schema.fields) - field_start)
            )

    def replace_types(mut self, old_types: Int):
        """Point every reference to a redefined type at its new definition,
        as `replaceNamedType` looks types up by name."""
        if self.redefinitions == 0:
            return
        var remap = List[Int32](capacity=old_types)
        var type = 0
        while type < old_types:
            # Every name of an old type is in the table: the latest type
            # with the name holds it.
            remap.append(
                Int32(self.pending.find(-1, self.schema.types[type].name))
            )
            type += 1
        var index = 0
        while index < len(self.schema.fields):
            var named = Int(self.schema.fields[index].type.named)
            if named < old_types:
                self.schema.fields[index].type.named = remap[named]
            index += 1
        index = 0
        while index < len(self.schema.input_values):
            var named = Int(self.schema.input_values[index].type.named)
            if named < old_types:
                self.schema.input_values[index].type.named = remap[named]
            index += 1
        index = 0
        while index < len(self.schema.type_lists):
            var named = Int(self.schema.type_lists[index])
            if named < old_types:
                self.schema.type_lists[index] = remap[named]
            index += 1
        self.schema.query_type = _remapped(self.schema.query_type, remap)
        self.schema.mutation_type = _remapped(self.schema.mutation_type, remap)
        self.schema.subscription_type = _remapped(
            self.schema.subscription_type, remap
        )

    def extend_directives(mut self) raises:
        """Deprecate existing directives from directive extensions, as
        `extendDirective`, then add the new directives."""
        var next = 0
        while next < len(self.schema.directives):
            var index = next
            next += 1
            var found = self.directive_extension_names.find(
                -1, self.schema.directives[index].name
            )
            if found == NOT_FOUND:
                continue
            var old = self.schema.directives[index].extensions
            var start = len(self.schema.ast_refs)
            for position in range(Int(old.start), old.end()):
                self.schema.ast_refs.append(self.schema.ast_refs[position])
            var extensions = self.directive_extension_lists[found].copy()
            var position = 0
            while position < len(extensions):
                var extension = extensions[position]
                self.schema.ast_refs.append(extension)
                position += 1
                if self.schema.directives[index].is_deprecated:
                    continue
                var reason = _deprecation_reason(
                    self.docs[unsafe_offset=Int(extension.document)],
                    Int(extension.node),
                )
                if reason:
                    self.schema.directives[
                        index
                    ].deprecation_reason = reason.value()
                    self.schema.directives[index].is_deprecated = True
            self.schema.directives[index].extensions = Range(
                Int32(start), Int32(len(self.schema.ast_refs) - start)
            )
        for index in range(len(self.directive_defs)):
            var at = self.directive_defs[index]
            self.add_directive(at, False)

    def extend_root_types(mut self) raises:
        """Keep the root types, then apply the new `schema` definition and
        `extend schema` nodes, as `extendSchemaImpl`; the description comes
        from the new definition only."""
        self.schema.description = AstRef.NONE
        var nodes = List[AstRef]()
        if self.schema_def.exists():
            nodes.append(self.schema_def)
            ref document = self.docs[
                unsafe_offset=Int(self.schema_def.document)
            ]
            var node = Int(self.schema_def.node)
            self.schema.description = _description_of(
                Int(self.schema_def.document), document, node
            )
            self.schema.schema_definition = self.schema_def
        for ref at in self.schema_extensions:
            nodes.append(at)
        var old = self.schema.schema_extensions
        var ext_start = len(self.schema.ast_refs)
        for index in range(Int(old.start), old.end()):
            self.schema.ast_refs.append(self.schema.ast_refs[index])
        for ref at in self.schema_extensions:
            self.schema.ast_refs.append(at)
        self.schema.schema_extensions = Range(
            Int32(ext_start), Int32(len(self.schema.ast_refs) - ext_start)
        )
        # The schema's directives are those of its definition node and of
        # every extension node, old and new.
        var all_nodes = List[AstRef]()
        if self.schema.schema_definition.exists():
            all_nodes.append(self.schema.schema_definition)
        for index in range(ext_start, len(self.schema.ast_refs)):
            all_nodes.append(self.schema.ast_refs[index])
        var dir_start = len(self.schema.applied)
        for ref at in all_nodes:
            _ = self.applied_directives(Int(at.document), Int(at.node))
        self.schema.schema_directives = Range(
            Int32(dir_start), Int32(len(self.schema.applied) - dir_start)
        )
        for ref at in nodes:
            ref document = self.docs[unsafe_offset=Int(at.document)]
            for operation in document.children(
                Int(at.node), Role.OPERATION_TYPE
            ):
                var ref_ = self.resolve(
                    document, document.child(operation, Role.TYPE)
                )
                var which = document.operation(operation).value
                if which == 0:
                    self.schema.query_type = ref_.named
                elif which == 1:
                    self.schema.mutation_type = ref_.named
                else:
                    self.schema.subscription_type = ref_.named

    def extend(mut self) raises:
        """Extend the schema with the new document."""
        var old_types = len(self.schema.types)
        self.collect()
        var old_map = self.schema.type_map.copy()
        var position = 0
        while position < len(old_map):
            var type = Int(old_map[position])
            if not self.schema.types[type].is_builtin and self.is_live(type):
                self.extend_type(type)
            position += 1
        for type in range(old_types, len(self.schema.types)):
            if self.is_live(type):
                self.fill_type(type)
        self.replace_types(old_types)
        self.extend_directives()
        self.extend_root_types()
        self.schema.type_map = List[Int32]()
        self.schema._type_names = NameTable()
        self.collect_type_map()
        self.schema.implementing_objects = List[Range]()
        self.schema.implementing_interfaces = List[Range]()
        self.add_implementations()

    def take(deinit self) -> Schema:
        """End the builder and return the schema, with its documents."""
        self.schema.documents = self.documents^
        return self.schema^


def _remapped(root: Int32, remap: List[Int32]) -> Int32:
    """Return a root type after `replace_types`; a root that is not set
    stays. The roots are old types then: new roots are set later."""
    if root == NO_TYPE:
        return root
    return remap[Int(root)]


def _store(mut lists: List[Int32], items: List[Int]) -> Range:
    """Append items to a list; return their range."""
    var start = len(lists)
    for item in items:
        lists.append(Int32(item))
    return Range(Int32(start), Int32(len(items)))


def _append_to(
    mut names: NameTable,
    mut lists: List[List[AstRef]],
    name: StringSlice,
    at: AstRef,
):
    """Append a node to the list kept for a name."""
    var found = names.find(-1, name)
    if found == NOT_FOUND:
        _ = names.insert(-1, name, len(lists))
        lists.append([at])
    else:
        lists[found].append(at)


@fieldwise_init
struct _Parts(ImplicitlyCopyable):
    """The children of a field or input value definition that the
    builder reads, found in one pass over the children."""

    var name: Int
    var type: Int
    var argument: Int


@always_inline
def _gather(document: Document, node: Int) -> _Parts:
    """Find a definition's name, its type and its first argument."""
    var parts = _Parts(NO_NODE, NO_NODE, NO_NODE)
    var current = document.first_child(node)
    while current != NO_NODE:
        var role = document.role(current)
        if role == Role.NAME:
            parts.name = current
        elif role == Role.TYPE:
            parts.type = current
        elif role == Role.ARGUMENT and parts.argument == NO_NODE:
            parts.argument = current
        current = document.next_sibling(current)
    return parts


@always_inline
def _text(document: Document, node: Int) -> String:
    """Copy a node's text; see `_name`."""
    return string_from_utf8(document.text(node).as_bytes())


@always_inline
def _name(document: Document, node: Int) -> String:
    """Copy a node's name; the bytes come from a parsed source, so they
    are valid UTF-8 and are not checked again."""
    return string_from_utf8(document.name(node).as_bytes())


def _description_of(
    document_index: Int, document: Document, node: Int
) -> AstRef:
    """Return a definition's description node, or `AstRef.NONE`."""
    var found = document.child(node, Role.DESCRIPTION)
    if found == NO_NODE:
        return AstRef.NONE
    return AstRef(Int32(document_index), Int32(found))


def _find_directive(document: Document, node: Int, name: StaticString) -> Int:
    """Return the first directive with a name applied to a node."""
    # A node's directives are next to each other.
    var current = document.child(node, Role.DIRECTIVE)
    while current != NO_NODE and document.role(current) == Role.DIRECTIVE:
        if document.name(current) == name:
            return current
        current = document.next_sibling(current)
    return NO_NODE


def _has_directive(document: Document, node: Int, name: StaticString) -> Bool:
    """Return True if a directive with a name is applied to a node."""
    return _find_directive(document, node, name) != NO_NODE


def _argument_value(
    document: Document, directive: Int, name: StaticString
) -> Int:
    """Return the value node of a directive's argument, or `NO_NODE`."""
    # The arguments are the last children of an applied directive.
    var current = document.child(directive, Role.ARGUMENT)
    while current != NO_NODE:
        if document.name(current) == name:
            return document.child(current, Role.VALUE)
        current = document.next_sibling(current)
    return NO_NODE


def _string_argument(
    document: Document,
    directive: Int,
    name: StaticString,
    default: Optional[String],
) raises -> Optional[String]:
    """Return a `String` argument of an applied directive, as graphql-js
    `getArgumentValues` for a constant value: a `String` argument with a
    default, or a `String!` argument with none.

    Raises:
        Error: The graphql-js message for a missing, null or invalid value.
    """
    var value = _argument_value(document, directive, name)
    var argument = String(name)
    # SDL values are constant, so no value is a variable.
    if value == NO_NODE:
        if default:
            return default
        raise Error(
            'Argument "'
            + argument
            + '" of required type "String!" was not provided.'
        )
    var kind = document.kind(value)
    if kind == Kind.NULL:
        if default:
            return None
        raise Error(
            'Argument "'
            + argument
            + '" of non-null type "String!" must not be null.'
        )
    if kind != Kind.STRING:
        raise Error(
            'Argument "'
            + argument
            + '" has invalid value '
            + print_node(document, value)
            + "."
        )
    return document.string_value(value)


def _directive_string_argument(
    document: Document,
    node: Int,
    directive: StaticString,
    argument: StaticString,
) raises -> Optional[String]:
    """Return a `String!` argument of a directive applied to a node, as
    `getDirectiveValues(directive, node)?.[argument]`; none when the
    directive is not applied.

    Raises:
        Error: As graphql-js `getArgumentValues` does for a bad value.
    """
    var found = _find_directive(document, node, directive)
    if found == NO_NODE:
        return None
    return _string_argument(document, found, argument, None)


def _deprecation_reason(
    document: Document, node: Int
) raises -> Optional[String]:
    """Return a node's `@deprecated` reason, as graphql-js
    `getDeprecationReason`: the default reason when none is given, and
    none for `reason: null` or no directive.

    Raises:
        Error: As graphql-js `getArgumentValues` does for a bad value.
    """
    var found = _find_directive(document, node, "deprecated")
    if found == NO_NODE:
        return None
    return _string_argument(
        document, found, "reason", String(DEFAULT_DEPRECATION_REASON)
    )


def build_ast_schema(
    var documents: List[Document], options: BuildOptions = BuildOptions()
) raises -> Schema:
    """Build a schema from SDL documents, as graphql-js `buildASTSchema`.

    The SDL is checked first, as graphql-js `assertValidSDL`, unless
    `options` skips the check.

    Args:
        documents: The SDL documents, in order; most callers pass one.
        options: The SDL validation switches; the parse options are not
            used.

    Returns:
        The schema.

    Raises:
        Error: The SDL validation errors, joined by a blank line;
            `Unknown type: "X".` for a reference to an undefined type;
            and the errors graphql-js raises for invalid `@deprecated` and
            `@specifiedBy` arguments.
    """
    if not options.skips_sdl_validation():
        assert_valid_sdl(documents)
    var builder = _Builder(documents^)
    builder.build()
    return builder^.take()


def build_schema(
    sdl: StringSlice, options: BuildOptions = BuildOptions()
) raises -> Schema:
    """Parse SDL and build a schema from it, as graphql-js `buildSchema`.

    Args:
        sdl: The SDL text.
        options: The parser options and the SDL validation switch.

    Returns:
        The schema.

    Raises:
        Error: A syntax error, or an error of `build_ast_schema`.
    """
    var document: Document
    try:
        document = parse(sdl, options.parse_options)
    except error:
        raise Error(String(error))
    var documents = List[Document]()
    documents.append(document^)
    return build_ast_schema(documents^, options)


def _changes_schema(document: Document) -> Bool:
    """Return True when a document has a definition or an extension that
    `extendSchemaImpl` uses; with none, it returns the schema unchanged."""
    var current = document.first_child(document.root)
    while current != NO_NODE:
        var kind = document.kind(current)
        if kind.is_type_system_definition() or kind.is_type_system_extension():
            return True
        current = document.next_sibling(current)
    return False


def extend_schema(
    schema: Schema,
    var document: Document,
    options: BuildOptions = BuildOptions(),
) raises -> Schema:
    """Return a schema extended with the definitions and extensions of a
    document, as graphql-js `extendSchema`.

    The original schema does not change. A document with no type system
    definition or extension gives an equal schema.

    Args:
        schema: The schema to extend.
        document: The SDL document; operations and fragments are ignored.
        options: The SDL validation switches; the parse options are not
            used.

    Returns:
        The extended schema.

    Raises:
        Error: The SDL validation errors, as graphql-js
            `assertValidSDLExtension`; `Unknown type: "X".` for a
            reference to an undefined type; and the errors graphql-js raises
            for invalid `@deprecated` and `@specifiedBy` arguments.
    """
    var documents = List[Document]()
    documents.append(document^)
    if not options.skips_sdl_validation():
        assert_valid_sdl_extension(documents, schema)
    if not _changes_schema(documents[0]):
        return schema.copy()
    var builder = _Builder(schema.copy(), documents.pop())
    builder.extend()
    return builder^.take()
