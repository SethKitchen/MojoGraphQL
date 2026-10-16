# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Track the schema types at each point of a walk of a document.

Port of graphql-js 16.14.2 `utilities/TypeInfo.ts` (`TypeInfo`,
`getFieldDef`) and `utilities/typeFromAST.ts` (`typeFromAST`).

A `TypeInfo` keeps stacks of types, as graphql-js does. Call `enter` on
entry to each node and `leave` on exit, and the getters give the type,
parent type, input type, field, argument, default value, directive and
enum value at the current node.

A type is a `TypeRef`. A `TypeRef` whose `named` is `NO_TYPE` is the
graphql-js `undefined`; `is_defined` tells them apart. A field is an index
into `Schema.fields`, or one of the three meta fields: `TYPENAME_META_FIELD`,
`SCHEMA_META_FIELD` and `TYPE_META_FIELD`. An argument is an index into
`Schema.input_values`, or `TYPE_NAME_META_ARGUMENT`, the `name` argument of
`__type`.

**Differences from graphql-js.**

- The deprecated `getFieldDefFn` hook of the constructor is not ported.
- `get_default_value` gives the argument or input field that holds the
  default value, not the coerced value. `has_default_value` tells if the
  coerced value is defined.
- `visitWithTypeInfo` is not ported: the walk of `gql_validation.validate`
  calls `enter` and `leave` itself. A walk that edits the document is not
  possible, because `gql_language` has no editing visitor.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_schema.definition import NO_TYPE, Schema, TypeKind, TypeRef
from gql_schema.values import UNDEFINED, JsValues, default_value

comptime NO_FIELD = -1
"""The field index of no field: graphql-js `undefined`."""
comptime TYPENAME_META_FIELD = -2
"""The field index of `__typename`: graphql-js `TypeNameMetaFieldDef`."""
comptime SCHEMA_META_FIELD = -3
"""The field index of `__schema`: graphql-js `SchemaMetaFieldDef`."""
comptime TYPE_META_FIELD = -4
"""The field index of `__type`: graphql-js `TypeMetaFieldDef`."""
comptime NO_ARGUMENT = -1
"""The argument index of no argument: graphql-js `undefined`."""
comptime TYPE_NAME_META_ARGUMENT = -2
"""The argument index of the `name` argument of `__type`."""
comptime NO_TYPE_REF = TypeRef(Int32(NO_TYPE), 0, 0)
"""The type of no type: graphql-js `undefined`."""


@always_inline
def is_defined(type: TypeRef) -> Bool:
    """Return True if a type reference names a type.

    Args:
        type: The reference.

    Returns:
        False for graphql-js `undefined`.
    """
    return type.named >= 0


def type_kind(schema: Schema, type: TypeRef) -> TypeKind:
    """Return the kind of the named type of a reference.

    Args:
        schema: The schema of the type.
        type: The reference.

    Returns:
        The kind, or an invalid kind for `undefined`.
    """
    if type.named < 0:
        return TypeKind(255)
    return schema.types[Int(type.named)].kind


def type_from_ast(schema: Schema, document: Document, node: Int) -> TypeRef:
    """Return the type that a type node names, as graphql-js `typeFromAST`.

    Args:
        schema: The schema to look the named type up in.
        document: The document that holds the node.
        node: A `NamedType`, `ListType` or `NonNullType` node.

    Returns:
        The type, or `NO_TYPE_REF` when the named type is not in the schema.
    """
    var wrappers = List[Kind]()
    var current = node
    while document.kind(current) != Kind.NAMED_TYPE:
        wrappers.append(document.kind(current))
        current = document.child(current, Role.TYPE)
    var named = schema.type_named(document.name(current))
    if named == NO_TYPE:
        return NO_TYPE_REF
    var type = TypeRef.of(named)
    var index = len(wrappers) - 1
    while index >= 0:
        if wrappers[index] == Kind.LIST_TYPE:
            type = type.list_of()
        else:
            type = type.non_null()
        index -= 1
    return type


struct TypeInfo(Movable):
    """The types at the current node of a walk: graphql-js `TypeInfo`."""

    var _type_stack: List[TypeRef]
    var _parent_type_stack: List[Int32]
    var _input_type_stack: List[TypeRef]
    var _field_def_stack: List[Int32]
    var _default_value_stack: List[Int32]
    var _directive: Int
    var _argument: Int
    var _enum_value: Int
    var _query_type: Int
    var _string_type: TypeRef
    var _schema_type: TypeRef
    var _type_type: TypeRef

    def __init__(out self, schema: Schema):
        """Start a walk at a document, as `new TypeInfo(schema)`.

        Args:
            schema: The schema to look the types up in.
        """
        self._type_stack = List[TypeRef](capacity=16)
        self._parent_type_stack = List[Int32](capacity=16)
        self._input_type_stack = List[TypeRef](capacity=8)
        self._field_def_stack = List[Int32](capacity=16)
        self._default_value_stack = List[Int32](capacity=8)
        self._directive = NO_TYPE
        self._argument = NO_ARGUMENT
        self._enum_value = NO_TYPE
        self._query_type = Int(schema.query_type)
        self._string_type = _named_or_none(schema, "String")
        self._schema_type = _named_or_none(schema, "__Schema")
        self._type_type = _named_or_none(schema, "__Type")

    def __init__(out self, schema: Schema, initial_type: TypeRef):
        """Start a walk at a node of a type, as `new TypeInfo(schema,
        initialType)`.

        Args:
            schema: The schema to look the types up in.
            initial_type: The type of the node where the walk starts.
        """
        self = TypeInfo(schema)
        if not is_defined(initial_type):
            return
        var kind = schema.types[Int(initial_type.named)].kind
        if kind.is_input():
            self._input_type_stack.append(initial_type)
        if kind.is_composite() and not initial_type.is_wrapped():
            self._parent_type_stack.append(initial_type.named)
        if kind.is_output():
            self._type_stack.append(initial_type)

    # --- the getters ------------------------------------------------------

    def get_type(self) -> TypeRef:
        """Return the output type of the current node.

        Returns:
            The graphql-js `getType()`, or `NO_TYPE_REF`.
        """
        if len(self._type_stack) == 0:
            return NO_TYPE_REF
        return self._type_stack[len(self._type_stack) - 1]

    def get_parent_type(self) -> Int:
        """Return the composite type whose fields the current selection
        set selects.

        Returns:
            The graphql-js `getParentType()`: a type index, or `NO_TYPE`.
        """
        if len(self._parent_type_stack) == 0:
            return NO_TYPE
        return Int(self._parent_type_stack[len(self._parent_type_stack) - 1])

    def get_input_type(self) -> TypeRef:
        """Return the input type of the current value position.

        Returns:
            The graphql-js `getInputType()`, or `NO_TYPE_REF`.
        """
        if len(self._input_type_stack) == 0:
            return NO_TYPE_REF
        return self._input_type_stack[len(self._input_type_stack) - 1]

    def get_parent_input_type(self) -> TypeRef:
        """Return the input type of the value that holds the current value.

        Returns:
            The graphql-js `getParentInputType()`, or `NO_TYPE_REF`.
        """
        if len(self._input_type_stack) < 2:
            return NO_TYPE_REF
        return self._input_type_stack[len(self._input_type_stack) - 2]

    def get_field_def(self) -> Int:
        """Return the field of the current node.

        Returns:
            The graphql-js `getFieldDef()`: a field index, a meta field, or
            `NO_FIELD`.
        """
        if len(self._field_def_stack) == 0:
            return NO_FIELD
        return Int(self._field_def_stack[len(self._field_def_stack) - 1])

    def get_default_value(self) -> Int:
        """Return the argument or input field whose default value applies at
        the current value position.

        Returns:
            An index into `Schema.input_values`, or -1 when no default value
            applies, as in a list position or for an unknown argument.
        """
        if len(self._default_value_stack) == 0:
            return -1
        return Int(
            self._default_value_stack[len(self._default_value_stack) - 1]
        )

    def get_directive(self) -> Int:
        """Return the directive of the current node.

        Returns:
            The graphql-js `getDirective()`: a directive index, or
            `NO_TYPE`.
        """
        return self._directive

    def get_argument(self) -> Int:
        """Return the argument of the current node.

        Returns:
            The graphql-js `getArgument()`: an input value index,
            `TYPE_NAME_META_ARGUMENT`, or `NO_ARGUMENT`.
        """
        return self._argument

    def get_enum_value(self) -> Int:
        """Return the enum value of the current node.

        Returns:
            The graphql-js `getEnumValue()`: an enum value index, or
            `NO_TYPE`.
        """
        return self._enum_value

    # --- fields and arguments ---------------------------------------------

    def field_type(self, schema: Schema, field: Int) -> TypeRef:
        """Return the type of a field, meta fields included.

        Args:
            schema: The schema of the field.
            field: A field index, or a meta field.

        Returns:
            The field's type: `String!` for `__typename`, `__Schema!` for
            `__schema` and `__Type` for `__type`.
        """
        if field >= 0:
            return schema.fields[field].type
        if field == TYPENAME_META_FIELD:
            return _non_null(self._string_type)
        if field == SCHEMA_META_FIELD:
            return _non_null(self._schema_type)
        return self._type_type

    def argument_type(self, schema: Schema, argument: Int) -> TypeRef:
        """Return the type of an argument, the `name` of `__type` included.

        Args:
            schema: The schema of the argument.
            argument: An input value index, or `TYPE_NAME_META_ARGUMENT`.

        Returns:
            The argument's type; `String!` for `TYPE_NAME_META_ARGUMENT`.
        """
        if argument >= 0:
            return schema.input_values[argument].type
        return _non_null(self._string_type)

    def field_def(self, schema: Schema, parent: Int, name: StringSlice) -> Int:
        """Return the field of a parent type with a name, meta fields
        included, as graphql-js `getFieldDef`.

        Args:
            schema: The schema of the type.
            parent: The composite parent type's index.
            name: The field's name.

        Returns:
            The field index, a meta field, or `NO_FIELD`.
        """
        if name.byte_length() > 2 and name.as_bytes()[0] == 95:
            if name == "__schema" and parent == self._query_type:
                return SCHEMA_META_FIELD
            if name == "__type" and parent == self._query_type:
                return TYPE_META_FIELD
            if (
                name == "__typename"
                and schema.types[parent].kind.is_composite()
            ):
                return TYPENAME_META_FIELD
        return schema.field_named(parent, name)

    # --- the walk ---------------------------------------------------------

    @always_inline
    def enter(mut self, schema: Schema, document: Document, node: Int):
        """Update the stacks on entry to a node, as graphql-js
        `TypeInfo.enter`.

        Args:
            schema: The schema that the walk checks against.
            document: The document of the walk.
            node: The node.
        """
        var kind = document.kind(node)
        if kind == Kind.SELECTION_SET:
            var named = Int(self.get_type().named)
            if named >= 0 and schema.types[named].kind.is_composite():
                self._parent_type_stack.append(Int32(named))
            else:
                self._parent_type_stack.append(Int32(NO_TYPE))
        elif kind == Kind.FIELD:
            var parent = self.get_parent_type()
            var field = NO_FIELD
            var field_type = NO_TYPE_REF
            if parent != NO_TYPE:
                field = self.field_def(schema, parent, document.name(node))
                if field != NO_FIELD:
                    field_type = self.field_type(schema, field)
            self._field_def_stack.append(Int32(field))
            if type_kind(schema, field_type).is_output():
                self._type_stack.append(field_type)
            else:
                self._type_stack.append(NO_TYPE_REF)
        elif kind == Kind.DIRECTIVE:
            self._directive = schema.directive_named(document.name(node))
        elif kind == Kind.OPERATION_DEFINITION:
            var root = schema.root_type(document.operation(node).value)
            if root != NO_TYPE and schema.types[root].kind == TypeKind.OBJECT:
                self._type_stack.append(TypeRef.of(root))
            else:
                self._type_stack.append(NO_TYPE_REF)
        elif kind == Kind.INLINE_FRAGMENT or kind == Kind.FRAGMENT_DEFINITION:
            var condition = document.child(node, Role.TYPE_CONDITION)
            var output: TypeRef
            if condition != NO_NODE:
                output = type_from_ast(schema, document, condition)
            else:
                output = self.get_type().unwrapped()
            if type_kind(schema, output).is_output():
                self._type_stack.append(output)
            else:
                self._type_stack.append(NO_TYPE_REF)
        elif kind == Kind.VARIABLE_DEFINITION:
            var input = type_from_ast(
                schema, document, document.child(node, Role.TYPE)
            )
            self._push_input(schema, input)
        elif kind == Kind.ARGUMENT:
            var argument = NO_ARGUMENT
            var name = document.name(node)
            if self._directive != NO_TYPE:
                argument = schema.directive_argument_named(
                    self._directive, name
                )
            else:
                var field = self.get_field_def()
                if field >= 0:
                    argument = schema.argument_named(field, name)
                elif field == TYPE_META_FIELD and name == "name":
                    argument = TYPE_NAME_META_ARGUMENT
            self._argument = argument
            var argument_type = NO_TYPE_REF
            if argument != NO_ARGUMENT:
                argument_type = self.argument_type(schema, argument)
            self._default_value_stack.append(Int32(max(argument, -1)))
            self._push_input(schema, argument_type)
        elif kind == Kind.LIST:
            var list_type = self.get_input_type().nullable()
            var item_type = list_type
            if list_type.is_list():
                item_type = list_type.of_type()
            self._default_value_stack.append(-1)
            self._push_input(schema, item_type)
        elif kind == Kind.OBJECT_FIELD:
            var object = Int(self.get_input_type().named)
            var field = NO_TYPE
            var field_type = NO_TYPE_REF
            if (
                object >= 0
                and schema.types[object].kind == TypeKind.INPUT_OBJECT
            ):
                field = schema.input_field_named(object, document.name(node))
                if field != NO_TYPE:
                    field_type = schema.input_values[field].type
            self._default_value_stack.append(Int32(field))
            self._push_input(schema, field_type)
        elif kind == Kind.ENUM:
            var enum_type = Int(self.get_input_type().named)
            var value = NO_TYPE
            if enum_type >= 0 and schema.types[enum_type].kind == TypeKind.ENUM:
                value = schema.enum_value_named(enum_type, document.text(node))
            self._enum_value = value

    @always_inline
    def leave(mut self, document: Document, node: Int):
        """Update the stacks on exit from a node, as graphql-js
        `TypeInfo.leave`.

        Args:
            document: The document of the walk.
            node: The node.
        """
        var kind = document.kind(node)
        if kind == Kind.SELECTION_SET:
            _ = self._parent_type_stack.pop()
        elif kind == Kind.FIELD:
            _ = self._field_def_stack.pop()
            _ = self._type_stack.pop()
        elif kind == Kind.DIRECTIVE:
            self._directive = NO_TYPE
        elif (
            kind == Kind.OPERATION_DEFINITION
            or kind == Kind.INLINE_FRAGMENT
            or kind == Kind.FRAGMENT_DEFINITION
        ):
            _ = self._type_stack.pop()
        elif kind == Kind.VARIABLE_DEFINITION:
            _ = self._input_type_stack.pop()
        elif kind == Kind.ARGUMENT:
            self._argument = NO_ARGUMENT
            _ = self._default_value_stack.pop()
            _ = self._input_type_stack.pop()
        elif kind == Kind.LIST or kind == Kind.OBJECT_FIELD:
            _ = self._default_value_stack.pop()
            _ = self._input_type_stack.pop()
        elif kind == Kind.ENUM:
            self._enum_value = NO_TYPE

    def _push_input(mut self, schema: Schema, type: TypeRef):
        """Push a type on the input stack, or `undefined` for a type that is
        not an input type."""
        if type_kind(schema, type).is_input():
            self._input_type_stack.append(type)
        else:
            self._input_type_stack.append(NO_TYPE_REF)


def has_default_value(schema: Schema, holder: Int) raises -> Bool:
    """Return True if an argument or input field has a defined default
    value, as graphql-js `defaultValue !== undefined`.

    graphql-js coerces a default value when it builds the schema, and an
    invalid literal coerces to `undefined`. So a default that does not fit
    its type counts as no default.

    Args:
        schema: The schema of the input value.
        holder: An input value index, or -1.

    Returns:
        Whether the coerced default value is defined.

    Raises:
        Error: When the default literal reaches an output type.
    """
    if holder < 0 or not schema.input_values[holder].has_default():
        return False
    var values = JsValues()
    return default_value(schema, holder, values) != UNDEFINED


def _named_or_none(schema: Schema, name: StringSlice) -> TypeRef:
    """Return a reference to a named type, or `NO_TYPE_REF`."""
    var named = schema.type_named(name)
    if named == NO_TYPE:
        return NO_TYPE_REF
    return TypeRef.of(named)


def _non_null(type: TypeRef) -> TypeRef:
    """Wrap a type in a non-null, keeping `undefined` as it is."""
    if not is_defined(type):
        return type
    return type.non_null()
