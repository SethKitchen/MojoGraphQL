# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Find the changes between two schemas that can break a client, or that
can change what it sees.

Port of graphql-js 16.14.2 `utilities/findBreakingChanges.ts`. The change
types, the descriptions and their order are the same: the type changes in
the type map order of the old schema, then the directive changes in the
directive order of the old schema.

A default value is compared as graphql-js compares it, in the form that
introspection shows: the coerced value printed with `astFromValue`, its
object fields sorted with `sortValueNode`, and printed again.

**Differences from upstream.**

- graphql-js returns plain objects whose `type` is a string. Here the
  types are `BreakingChangeType` and `DangerousChangeType`, and `text()`
  gives the graphql-js string.
- A change in the kind of a type is found from the `TypeKind`; graphql-js
  compares the JavaScript classes, which is the same for a schema built
  from SDL.
"""

from gql_language.ast import Role
from gql_language.directive_location import DirectiveLocation
from gql_language.parser import parse_const_value
from gql_language.printer import print_ast
from gql_language.sort_value_node import sort_value_node
from gql_schema.definition import Range, Schema, TypeKind, TypeRef
from gql_schema.values import (
    UNDEFINED,
    JsValues,
    default_value,
    print_ast_from_value,
)


@fieldwise_init
struct BreakingChangeType(Equatable, ImplicitlyCopyable, Writable):
    """A kind of change that can break an existing operation, as graphql-js
    `BreakingChangeType`."""

    var value: UInt8
    """The type's index; see `is_valid`."""

    comptime TYPE_REMOVED = BreakingChangeType(0)
    """A type was removed."""
    comptime TYPE_CHANGED_KIND = BreakingChangeType(1)
    """A type changed its kind."""
    comptime TYPE_REMOVED_FROM_UNION = BreakingChangeType(2)
    """A type was removed from a union."""
    comptime VALUE_REMOVED_FROM_ENUM = BreakingChangeType(3)
    """A value was removed from an enum."""
    comptime REQUIRED_INPUT_FIELD_ADDED = BreakingChangeType(4)
    """A required field was added to an input type."""
    comptime IMPLEMENTED_INTERFACE_REMOVED = BreakingChangeType(5)
    """A type no longer implements an interface."""
    comptime FIELD_REMOVED = BreakingChangeType(6)
    """A field was removed."""
    comptime FIELD_CHANGED_KIND = BreakingChangeType(7)
    """A field changed its type in a way that is not safe."""
    comptime REQUIRED_ARG_ADDED = BreakingChangeType(8)
    """A required argument was added to a field."""
    comptime ARG_REMOVED = BreakingChangeType(9)
    """An argument was removed from a field."""
    comptime ARG_CHANGED_KIND = BreakingChangeType(10)
    """An argument changed its type in a way that is not safe."""
    comptime DIRECTIVE_REMOVED = BreakingChangeType(11)
    """A directive was removed."""
    comptime DIRECTIVE_ARG_REMOVED = BreakingChangeType(12)
    """An argument was removed from a directive."""
    comptime REQUIRED_DIRECTIVE_ARG_ADDED = BreakingChangeType(13)
    """A required argument was added to a directive."""
    comptime DIRECTIVE_REPEATABLE_REMOVED = BreakingChangeType(14)
    """A directive is no longer repeatable."""
    comptime DIRECTIVE_LOCATION_REMOVED = BreakingChangeType(15)
    """A location was removed from a directive."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the 16 types.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 15

    def text(self) -> StaticString:
        """Return the graphql-js name of the type.

        Returns:
            Such as `TYPE_REMOVED`, or `<invalid>`.
        """
        comptime names: Array[StaticString, 16] = [
            "TYPE_REMOVED",
            "TYPE_CHANGED_KIND",
            "TYPE_REMOVED_FROM_UNION",
            "VALUE_REMOVED_FROM_ENUM",
            "REQUIRED_INPUT_FIELD_ADDED",
            "IMPLEMENTED_INTERFACE_REMOVED",
            "FIELD_REMOVED",
            "FIELD_CHANGED_KIND",
            "REQUIRED_ARG_ADDED",
            "ARG_REMOVED",
            "ARG_CHANGED_KIND",
            "DIRECTIVE_REMOVED",
            "DIRECTIVE_ARG_REMOVED",
            "REQUIRED_DIRECTIVE_ARG_ADDED",
            "DIRECTIVE_REPEATABLE_REMOVED",
            "DIRECTIVE_LOCATION_REMOVED",
        ]
        if not self.is_valid():
            return "<invalid>"
        return materialize[names]()[Int(self.value)]

    def write_to(self, mut writer: Some[Writer]):
        """Write the graphql-js name of the type.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct DangerousChangeType(Equatable, ImplicitlyCopyable, Writable):
    """A kind of change that can change the result of an existing
    operation, as graphql-js `DangerousChangeType`."""

    var value: UInt8
    """The type's index; see `is_valid`."""

    comptime VALUE_ADDED_TO_ENUM = DangerousChangeType(0)
    """A value was added to an enum."""
    comptime TYPE_ADDED_TO_UNION = DangerousChangeType(1)
    """A type was added to a union."""
    comptime OPTIONAL_INPUT_FIELD_ADDED = DangerousChangeType(2)
    """An optional field was added to an input type."""
    comptime OPTIONAL_ARG_ADDED = DangerousChangeType(3)
    """An optional argument was added to a field."""
    comptime IMPLEMENTED_INTERFACE_ADDED = DangerousChangeType(4)
    """A type implements one more interface."""
    comptime ARG_DEFAULT_VALUE_CHANGE = DangerousChangeType(5)
    """The default value of an argument changed or was removed."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the 6 types.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 5

    def text(self) -> StaticString:
        """Return the graphql-js name of the type.

        Returns:
            Such as `VALUE_ADDED_TO_ENUM`, or `<invalid>`.
        """
        comptime names: Array[StaticString, 6] = [
            "VALUE_ADDED_TO_ENUM",
            "TYPE_ADDED_TO_UNION",
            "OPTIONAL_INPUT_FIELD_ADDED",
            "OPTIONAL_ARG_ADDED",
            "IMPLEMENTED_INTERFACE_ADDED",
            "ARG_DEFAULT_VALUE_CHANGE",
        ]
        if not self.is_valid():
            return "<invalid>"
        return materialize[names]()[Int(self.value)]

    def write_to(self, mut writer: Some[Writer]):
        """Write the graphql-js name of the type.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct BreakingChange(Copyable, Movable, Writable):
    """A change that can break an existing operation, as graphql-js
    `BreakingChange`."""

    var type: BreakingChangeType
    """The kind of change."""
    var description: String
    """What changed, in words."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the type and the description, for a test or a log.

        Args:
            writer: The destination.
        """
        writer.write(self.type, ": ", self.description)


@fieldwise_init
struct DangerousChange(Copyable, Movable, Writable):
    """A change that can change the result of an existing operation, as
    graphql-js `DangerousChange`."""

    var type: DangerousChangeType
    """The kind of change."""
    var description: String
    """What changed, in words."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the type and the description, for a test or a log.

        Args:
            writer: The destination.
        """
        writer.write(self.type, ": ", self.description)


@fieldwise_init
struct _Change(Copyable, Movable):
    """A breaking or a dangerous change, in the order they are found."""

    var breaking: Bool
    var code: UInt8
    var description: String


def _breaking(
    mut changes: List[_Change],
    type: BreakingChangeType,
    var description: String,
):
    """Add a breaking change."""
    changes.append(_Change(True, type.value, description^))


def _dangerous(
    mut changes: List[_Change],
    type: DangerousChangeType,
    var description: String,
):
    """Add a dangerous change."""
    changes.append(_Change(False, type.value, description^))


struct _Diff(Movable):
    """The positions of the items of two lists, matched by name, as
    graphql-js `diff`."""

    var added: List[Int]
    var removed: List[Int]
    var persisted_old: List[Int]
    var persisted_new: List[Int]

    def __init__(out self, old_names: List[String], new_names: List[String]):
        """Match the items of two lists by name; the last item with a name
        wins, as `keyMap`."""
        self.added = List[Int]()
        self.removed = List[Int]()
        self.persisted_old = List[Int]()
        self.persisted_new = List[Int]()
        var old_map = Dict[String, Int]()
        var new_map = Dict[String, Int]()
        var index = 0
        while index < len(old_names):
            old_map[old_names[index]] = index
            index += 1
        index = 0
        while index < len(new_names):
            new_map[new_names[index]] = index
            index += 1
        index = 0
        while index < len(old_names):
            var found = new_map.get(old_names[index])
            if found:
                self.persisted_old.append(index)
                self.persisted_new.append(found.value())
            else:
                self.removed.append(index)
            index += 1
        index = 0
        while index < len(new_names):
            if new_names[index] not in old_map:
                self.added.append(index)
            index += 1


def _field_names(schema: Schema, span: Range) -> List[String]:
    """Return the names of a run of fields."""
    var out = List[String](capacity=Int(span.count))
    var index = Int(span.start)
    while index < span.end():
        out.append(schema.fields[index].name)
        index += 1
    return out^


def _input_value_names(schema: Schema, span: Range) -> List[String]:
    """Return the names of a run of arguments or input fields."""
    var out = List[String](capacity=Int(span.count))
    var index = Int(span.start)
    while index < span.end():
        out.append(schema.input_values[index].name)
        index += 1
    return out^


def _enum_value_names(schema: Schema, span: Range) -> List[String]:
    """Return the names of a run of enum values."""
    var out = List[String](capacity=Int(span.count))
    var index = Int(span.start)
    while index < span.end():
        out.append(schema.enum_values[index].name)
        index += 1
    return out^


def _type_list_names(schema: Schema, span: Range) -> List[String]:
    """Return the names of the types in a run of `type_lists`."""
    var out = List[String](capacity=Int(span.count))
    var index = Int(span.start)
    while index < span.end():
        out.append(schema.types[Int(schema.type_lists[index])].name)
        index += 1
    return out^


def _type_map_names(schema: Schema) -> List[String]:
    """Return the names of the types, in type map order."""
    var out = List[String](capacity=len(schema.type_map))
    var index = 0
    while index < len(schema.type_map):
        out.append(schema.types[Int(schema.type_map[index])].name)
        index += 1
    return out^


def _directive_names(schema: Schema) -> List[String]:
    """Return the names of the directives, in order."""
    var out = List[String](capacity=len(schema.directives))
    var index = 0
    while index < len(schema.directives):
        out.append(schema.directives[index].name)
        index += 1
    return out^


def _same_name(
    old_schema: Schema, old: TypeRef, new_schema: Schema, new: TypeRef
) -> Bool:
    """Return True if two named types have the same name."""
    return (
        old_schema.types[Int(old.named)].name
        == new_schema.types[Int(new.named)].name
    )


def _is_safe_for_output(
    old_schema: Schema, old_type: TypeRef, new_schema: Schema, new_type: TypeRef
) -> Bool:
    """Return True if a field type can change from one type to the other,
    as graphql-js `isChangeSafeForObjectOrInterfaceField`.

    graphql-js recurses; at each step at most one recursive call can
    apply, so this is a loop.
    """
    var old = old_type
    var new = new_type
    while old.is_wrapped() or new.is_non_null():
        if old.is_list():
            if new.is_list():
                # Both lists: the item types must be compatible.
                old = old.of_type()
            elif not new.is_non_null():
                return False
            # A move from nullable to non-null is safe.
            new = new.of_type()
        elif old.is_non_null():
            if not new.is_non_null():
                return False
            old = old.of_type()
            new = new.of_type()
        else:
            # A named type that becomes non-null is safe.
            new = new.of_type()
    return not new.is_list() and _same_name(old_schema, old, new_schema, new)


def _is_safe_for_input(
    old_schema: Schema, old_type: TypeRef, new_schema: Schema, new_type: TypeRef
) -> Bool:
    """Return True if an argument or input field type can change from one
    type to the other, as graphql-js
    `isChangeSafeForInputObjectFieldOrFieldArg`."""
    var old = old_type
    var new = new_type
    while old.is_wrapped():
        if old.is_list():
            if not new.is_list():
                return False
            new = new.of_type()
        elif new.is_non_null():
            new = new.of_type()
        # A move from non-null to nullable is safe.
        old = old.of_type()
    return not new.is_wrapped() and _same_name(old_schema, old, new_schema, new)


def _has_default(schema: Schema, input_value: Int) raises -> Bool:
    """Return True if an input value has a default, as graphql-js
    `defaultValue !== undefined`: a default that is not valid for the type
    counts as none."""
    var values = JsValues()
    return default_value(schema, input_value, values) != UNDEFINED


def _is_required(schema: Schema, input_value: Int) raises -> Bool:
    """Return True for a non-null input value without a default, as
    graphql-js `isRequiredArgument` and `isRequiredInputField`."""
    return schema.input_values[
        input_value
    ].type.is_non_null() and not _has_default(schema, input_value)


def _stringify_default(schema: Schema, input_value: Int) raises -> String:
    """Return a default value as graphql-js `stringifyValue` does:
    `print(sortValueNode(astFromValue(value, type)))`."""
    var values = JsValues()
    var value = default_value(schema, input_value, values)
    var printed = print_ast_from_value(
        schema, values, value, schema.input_values[input_value].type
    )
    # A valid default always has a literal, as graphql-js asserts.
    var literal = parse_const_value(printed.value())
    return print_ast(sort_value_node(literal, literal.root))


def _kind_name(kind: TypeKind) -> String:
    """Return a type kind in words, as graphql-js `typeKindName`."""
    if kind == TypeKind.SCALAR:
        return "a Scalar type"
    if kind == TypeKind.OBJECT:
        return "an Object type"
    if kind == TypeKind.INTERFACE:
        return "an Interface type"
    if kind == TypeKind.UNION:
        return "a Union type"
    if kind == TypeKind.ENUM:
        return "an Enum type"
    return "an Input type"


def _find_input_object_changes(
    old: Schema,
    new: Schema,
    old_type: Int,
    new_type: Int,
    mut changes: List[_Change],
) raises:
    """Add the changes of an input object type, as graphql-js
    `findInputObjectTypeChanges`."""
    var type_name = old.types[old_type].name
    var old_span = old.types[old_type].input_fields
    var new_span = new.types[new_type].input_fields
    var diff = _Diff(
        _input_value_names(old, old_span), _input_value_names(new, new_span)
    )
    for position in diff.added:
        var field = Int(new_span.start) + position
        var name = new.input_values[field].name
        if _is_required(new, field):
            _breaking(
                changes,
                BreakingChangeType.REQUIRED_INPUT_FIELD_ADDED,
                "A required field "
                + name
                + " on input type "
                + type_name
                + " was added.",
            )
        else:
            _dangerous(
                changes,
                DangerousChangeType.OPTIONAL_INPUT_FIELD_ADDED,
                "An optional field "
                + name
                + " on input type "
                + type_name
                + " was added.",
            )
    for position in diff.removed:
        var field = Int(old_span.start) + position
        _breaking(
            changes,
            BreakingChangeType.FIELD_REMOVED,
            type_name + "." + old.input_values[field].name + " was removed.",
        )
    var index = 0
    while index < len(diff.persisted_old):
        ref old_field = old.input_values[
            Int(old_span.start) + diff.persisted_old[index]
        ]
        ref new_field = new.input_values[
            Int(new_span.start) + diff.persisted_new[index]
        ]
        if not _is_safe_for_input(old, old_field.type, new, new_field.type):
            _breaking(
                changes,
                BreakingChangeType.FIELD_CHANGED_KIND,
                type_name
                + "."
                + old_field.name
                + " changed type from "
                + old.type_name(old_field.type)
                + " to "
                + new.type_name(new_field.type)
                + ".",
            )
        index += 1


def _find_union_changes(
    old: Schema,
    new: Schema,
    old_type: Int,
    new_type: Int,
    mut changes: List[_Change],
):
    """Add the changes of a union type, as graphql-js
    `findUnionTypeChanges`."""
    var type_name = old.types[old_type].name
    var old_names = _type_list_names(old, old.types[old_type].members)
    var new_names = _type_list_names(new, new.types[new_type].members)
    var diff = _Diff(old_names, new_names)
    for position in diff.added:
        _dangerous(
            changes,
            DangerousChangeType.TYPE_ADDED_TO_UNION,
            new_names[position] + " was added to union type " + type_name + ".",
        )
    for position in diff.removed:
        _breaking(
            changes,
            BreakingChangeType.TYPE_REMOVED_FROM_UNION,
            old_names[position]
            + " was removed from union type "
            + type_name
            + ".",
        )


def _find_enum_changes(
    old: Schema,
    new: Schema,
    old_type: Int,
    new_type: Int,
    mut changes: List[_Change],
):
    """Add the changes of an enum type, as graphql-js
    `findEnumTypeChanges`."""
    var type_name = old.types[old_type].name
    var old_names = _enum_value_names(old, old.types[old_type].enum_values)
    var new_names = _enum_value_names(new, new.types[new_type].enum_values)
    var diff = _Diff(old_names, new_names)
    for position in diff.added:
        _dangerous(
            changes,
            DangerousChangeType.VALUE_ADDED_TO_ENUM,
            new_names[position] + " was added to enum type " + type_name + ".",
        )
    for position in diff.removed:
        _breaking(
            changes,
            BreakingChangeType.VALUE_REMOVED_FROM_ENUM,
            old_names[position]
            + " was removed from enum type "
            + type_name
            + ".",
        )


def _find_interface_changes(
    old: Schema,
    new: Schema,
    old_type: Int,
    new_type: Int,
    mut changes: List[_Change],
):
    """Add the changes of the interfaces of a type, as graphql-js
    `findImplementedInterfacesChanges`."""
    var type_name = old.types[old_type].name
    var old_names = _type_list_names(old, old.types[old_type].interfaces)
    var new_names = _type_list_names(new, new.types[new_type].interfaces)
    var diff = _Diff(old_names, new_names)
    for position in diff.added:
        _dangerous(
            changes,
            DangerousChangeType.IMPLEMENTED_INTERFACE_ADDED,
            new_names[position]
            + " added to interfaces implemented by "
            + type_name
            + ".",
        )
    for position in diff.removed:
        _breaking(
            changes,
            BreakingChangeType.IMPLEMENTED_INTERFACE_REMOVED,
            type_name
            + " no longer implements interface "
            + old_names[position]
            + ".",
        )


def _find_arg_changes(
    old: Schema,
    new: Schema,
    old_field: Int,
    new_field: Int,
    type_name: String,
    mut changes: List[_Change],
) raises:
    """Add the changes of the arguments of a field, as graphql-js
    `findArgChanges`."""
    var field_name = type_name + "." + old.fields[old_field].name
    var old_span = old.fields[old_field].arguments
    var new_span = new.fields[new_field].arguments
    var diff = _Diff(
        _input_value_names(old, old_span), _input_value_names(new, new_span)
    )
    for position in diff.removed:
        _breaking(
            changes,
            BreakingChangeType.ARG_REMOVED,
            field_name
            + " arg "
            + old.input_values[Int(old_span.start) + position].name
            + " was removed.",
        )
    var index = 0
    while index < len(diff.persisted_old):
        var old_arg = Int(old_span.start) + diff.persisted_old[index]
        var new_arg = Int(new_span.start) + diff.persisted_new[index]
        var old_type = old.input_values[old_arg].type
        var new_type = new.input_values[new_arg].type
        var arg_name = field_name + " arg " + old.input_values[old_arg].name
        if not _is_safe_for_input(old, old_type, new, new_type):
            _breaking(
                changes,
                BreakingChangeType.ARG_CHANGED_KIND,
                arg_name
                + " has changed type from "
                + old.type_name(old_type)
                + " to "
                + new.type_name(new_type)
                + ".",
            )
        elif _has_default(old, old_arg):
            if not _has_default(new, new_arg):
                _dangerous(
                    changes,
                    DangerousChangeType.ARG_DEFAULT_VALUE_CHANGE,
                    arg_name + " defaultValue was removed.",
                )
            else:
                # Compare the values as introspection shows them.
                var old_value = _stringify_default(old, old_arg)
                var new_value = _stringify_default(new, new_arg)
                if old_value != new_value:
                    _dangerous(
                        changes,
                        DangerousChangeType.ARG_DEFAULT_VALUE_CHANGE,
                        arg_name
                        + " has changed defaultValue from "
                        + old_value
                        + " to "
                        + new_value
                        + ".",
                    )
        index += 1
    for position in diff.added:
        var arg = Int(new_span.start) + position
        var name = new.input_values[arg].name
        if _is_required(new, arg):
            _breaking(
                changes,
                BreakingChangeType.REQUIRED_ARG_ADDED,
                "A required arg " + name + " on " + field_name + " was added.",
            )
        else:
            _dangerous(
                changes,
                DangerousChangeType.OPTIONAL_ARG_ADDED,
                "An optional arg " + name + " on " + field_name + " was added.",
            )


def _find_field_changes(
    old: Schema,
    new: Schema,
    old_type: Int,
    new_type: Int,
    mut changes: List[_Change],
) raises:
    """Add the changes of the fields of an object or interface type, as
    graphql-js `findFieldChanges`."""
    var type_name = old.types[old_type].name
    var old_span = old.types[old_type].fields
    var new_span = new.types[new_type].fields
    var diff = _Diff(_field_names(old, old_span), _field_names(new, new_span))
    for position in diff.removed:
        _breaking(
            changes,
            BreakingChangeType.FIELD_REMOVED,
            type_name
            + "."
            + old.fields[Int(old_span.start) + position].name
            + " was removed.",
        )
    var index = 0
    while index < len(diff.persisted_old):
        var old_field = Int(old_span.start) + diff.persisted_old[index]
        var new_field = Int(new_span.start) + diff.persisted_new[index]
        _find_arg_changes(old, new, old_field, new_field, type_name, changes)
        var old_field_type = old.fields[old_field].type
        var new_field_type = new.fields[new_field].type
        if not _is_safe_for_output(old, old_field_type, new, new_field_type):
            _breaking(
                changes,
                BreakingChangeType.FIELD_CHANGED_KIND,
                type_name
                + "."
                + old.fields[old_field].name
                + " changed type from "
                + old.type_name(old_field_type)
                + " to "
                + new.type_name(new_field_type)
                + ".",
            )
        index += 1


def _find_type_changes(
    old: Schema, new: Schema, mut changes: List[_Change]
) raises:
    """Add the changes of the types, as graphql-js `findTypeChanges`."""
    var diff = _Diff(_type_map_names(old), _type_map_names(new))
    for position in diff.removed:
        ref named = old.types[Int(old.type_map[position])]
        # Every schema has the introspection types, so a built-in type
        # that is removed is a specified scalar: `isSpecifiedScalarType`.
        if named.is_builtin:
            _breaking(
                changes,
                BreakingChangeType.TYPE_REMOVED,
                "Standard scalar "
                + named.name
                + " was removed because it is not referenced anymore.",
            )
        else:
            _breaking(
                changes,
                BreakingChangeType.TYPE_REMOVED,
                named.name + " was removed.",
            )
    var index = 0
    while index < len(diff.persisted_old):
        var old_type = Int(old.type_map[diff.persisted_old[index]])
        var new_type = Int(new.type_map[diff.persisted_new[index]])
        var old_kind = old.types[old_type].kind
        var new_kind = new.types[new_type].kind
        if old_kind != new_kind:
            _breaking(
                changes,
                BreakingChangeType.TYPE_CHANGED_KIND,
                old.types[old_type].name
                + " changed from "
                + _kind_name(old_kind)
                + " to "
                + _kind_name(new_kind)
                + ".",
            )
        elif old_kind == TypeKind.ENUM:
            _find_enum_changes(old, new, old_type, new_type, changes)
        elif old_kind == TypeKind.UNION:
            _find_union_changes(old, new, old_type, new_type, changes)
        elif old_kind == TypeKind.INPUT_OBJECT:
            _find_input_object_changes(old, new, old_type, new_type, changes)
        elif old_kind.has_fields():
            _find_field_changes(old, new, old_type, new_type, changes)
            _find_interface_changes(old, new, old_type, new_type, changes)
        index += 1


def _find_directive_changes(
    old: Schema, new: Schema, mut changes: List[_Change]
) raises:
    """Add the changes of the directives, as graphql-js
    `findDirectiveChanges`."""
    var old_names = _directive_names(old)
    var diff = _Diff(old_names, _directive_names(new))
    for position in diff.removed:
        _breaking(
            changes,
            BreakingChangeType.DIRECTIVE_REMOVED,
            old_names[position] + " was removed.",
        )
    var index = 0
    while index < len(diff.persisted_old):
        ref old_directive = old.directives[diff.persisted_old[index]]
        ref new_directive = new.directives[diff.persisted_new[index]]
        var name = old_directive.name
        var old_span = old_directive.arguments
        var new_span = new_directive.arguments
        var args = _Diff(
            _input_value_names(old, old_span), _input_value_names(new, new_span)
        )
        for position in args.added:
            var arg = Int(new_span.start) + position
            if _is_required(new, arg):
                _breaking(
                    changes,
                    BreakingChangeType.REQUIRED_DIRECTIVE_ARG_ADDED,
                    "A required arg "
                    + new.input_values[arg].name
                    + " on directive "
                    + name
                    + " was added.",
                )
        for position in args.removed:
            _breaking(
                changes,
                BreakingChangeType.DIRECTIVE_ARG_REMOVED,
                old.input_values[Int(old_span.start) + position].name
                + " was removed from "
                + name
                + ".",
            )
        if old_directive.is_repeatable and not new_directive.is_repeatable:
            _breaking(
                changes,
                BreakingChangeType.DIRECTIVE_REPEATABLE_REMOVED,
                "Repeatable flag was removed from " + name + ".",
            )
        # The old locations, in the order the definition lists them.
        ref definition = old_directive.definition
        ref document = old.documents[Int(definition.document)]
        var locations = document.children(Int(definition.node), Role.LOCATION)
        var at = 0
        while at < len(locations):
            var text = document.text(locations[at])
            at += 1
            var value = DirectiveLocation.from_name(text)
            if not new_directive.allows(DirectiveLocation(UInt8(value))):
                _breaking(
                    changes,
                    BreakingChangeType.DIRECTIVE_LOCATION_REMOVED,
                    String(text) + " was removed from " + name + ".",
                )
        index += 1


def _find_schema_changes(old: Schema, new: Schema) raises -> List[_Change]:
    """Return every change, the type changes first, as graphql-js
    `findSchemaChanges`."""
    var changes = List[_Change]()
    _find_type_changes(old, new, changes)
    _find_directive_changes(old, new, changes)
    return changes^


def find_breaking_changes(
    old_schema: Schema, new_schema: Schema
) raises -> List[BreakingChange]:
    """Return the changes between two schemas that can break an existing
    operation, as graphql-js `findBreakingChanges`.

    Args:
        old_schema: The schema before the change.
        new_schema: The schema after the change.

    Returns:
        The breaking changes, in the order graphql-js finds them.

    Raises:
        Error: When a default value cannot be printed, as graphql-js
            `astFromValue` raises, such as `Float cannot represent non
            numeric value: Infinity`.
    """
    var out = List[BreakingChange]()
    for ref change in _find_schema_changes(old_schema, new_schema):
        if change.breaking:
            out.append(
                BreakingChange(
                    BreakingChangeType(change.code), change.description
                )
            )
    return out^


def find_dangerous_changes(
    old_schema: Schema, new_schema: Schema
) raises -> List[DangerousChange]:
    """Return the changes between two schemas that can change the result of
    an existing operation, as graphql-js `findDangerousChanges`.

    Args:
        old_schema: The schema before the change.
        new_schema: The schema after the change.

    Returns:
        The dangerous changes, in the order graphql-js finds them.

    Raises:
        Error: When a default value cannot be printed, as
            `find_breaking_changes` raises.
    """
    var out = List[DangerousChange]()
    for ref change in _find_schema_changes(old_schema, new_schema):
        if not change.breaking:
            out.append(
                DangerousChange(
                    DangerousChangeType(change.code), change.description
                )
            )
    return out^
