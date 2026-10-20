# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Validation of the variables JSON of a request, as graphql-go-tools v2
`pkg/variablesvalidation`.

Ported from `v2/pkg/variablesvalidation/variablesvalidation.go` of
wundergraph/graphql-go-tools (MIT), revision 9ef6e24.

A `VariablesValidator` checks the JSON variables of a request against the
variable definitions of an operation and the input types of a schema. It
reports the first problem as an `InvalidVariableError`, with the upstream
message text.

Differences from upstream:

- The schema is a `gql_schema` `Schema`, not a definition `ast.Document`
  merged with the base schema. The lookups of types, input fields and enum
  values use the `Schema` indexes.
- `validate` returns `Optional[InvalidVariableError]` and raises a
  `JsonError` when the variables are not JSON. Upstream returns one `error`
  for the two cases.
- The validator visits only the variable definitions of each operation. It
  does not walk the selection sets with an `astvisitor.Walker`, so it
  never returns an `operationreport.Report` for a field that the schema does
  not define.
- A value is written back as JSON with `gql_json` `stringify`, not with
  `astjson` `MarshalTo`.
"""

from std.collections import Dict, Optional

from gql_json.error import JsonError
from gql_json.parser import parse
from gql_json.value import JsonDocument, JsonKind
from gql_json.writer import stringify
from gql_language.ast import Document, Kind, Role
from gql_schema.definition import Schema, TypeKind, TypeRef


comptime BAD_USER_INPUT = "BAD_USER_INPUT"
"""The extension code of the Apollo Gateway compatibility, as upstream
`errorcodes.BadUserInput`."""

comptime VALIDATION_INVALID_TYPE_VARIABLE = "VALIDATION_INVALID_TYPE_VARIABLE"
"""The extension code of the Apollo Router compatibility, as upstream
`errorcodes.ValidationInvalidTypeVariable`."""


@fieldwise_init
struct ApolloCompatibilityFlags(Copyable, ImplicitlyCopyable, Movable):
    """The Apollo Gateway compatibility switches, as upstream
    `apollocompatibility.Flags`."""

    var replace_invalid_var_error: Bool
    """Add the `BAD_USER_INPUT` extension code to each error."""

    def __init__(out self):
        """Make the flags with every switch off."""
        self.replace_invalid_var_error = False


@fieldwise_init
struct ApolloRouterCompatibilityFlags(Copyable, ImplicitlyCopyable, Movable):
    """The Apollo Router compatibility switches, as upstream
    `apollocompatibility.ApolloRouterFlags`."""

    var replace_invalid_var_error: Bool
    """Replace each message with the short Apollo Router message."""
    var skip_null_variables_error: Bool
    """Accept `null` for a variable of a non-null type."""

    def __init__(out self):
        """Make the flags with every switch off."""
        self.replace_invalid_var_error = False
        self.skip_null_variables_error = False


@fieldwise_init
struct VariablesValidatorOptions(Copyable, ImplicitlyCopyable, Movable):
    """The options of a `VariablesValidator`, as upstream
    `VariablesValidatorOptions`."""

    var apollo_compatibility_flags: ApolloCompatibilityFlags
    """The Apollo Gateway compatibility switches."""
    var apollo_router_compatibility_flags: ApolloRouterCompatibilityFlags
    """The Apollo Router compatibility switches."""
    var disable_exposing_variables_content: Bool
    """Leave the variable values out of the messages."""

    def __init__(out self):
        """Make the options with every switch off."""
        self.apollo_compatibility_flags = ApolloCompatibilityFlags()
        self.apollo_router_compatibility_flags = (
            ApolloRouterCompatibilityFlags()
        )
        self.disable_exposing_variables_content = False


@fieldwise_init
struct InvalidVariableError(Copyable, Equatable, Movable, Writable):
    """A variable value that does not match its type, as upstream
    `InvalidVariableError`."""

    var extension_code: String
    """The GraphQL error extension code, or empty."""
    var message: String
    """The message, as upstream writes it."""

    def __eq__(self, other: Self) -> Bool:
        """Compare two errors.

        Args:
            other: The other error.

        Returns:
            True when the code and the message are equal.
        """
        return (
            self.extension_code == other.extension_code
            and self.message == other.message
        )

    def write_to(self, mut writer: Some[Writer]):
        """Write the message, as upstream `Error()`.

        Args:
            writer: The destination.
        """
        writer.write(self.message)


@fieldwise_init
struct _PathItemKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of one step of the value path, as upstream `pathItemKind`."""

    var value: UInt8
    """The raw kind."""

    comptime OBJECT = _PathItemKind(0)
    """A member of an object."""
    comptime ARRAY = _PathItemKind(1)
    """An item of an array."""

    def is_valid(self) -> Bool:
        """Tell whether the kind is one of the known kinds.

        Returns:
            True for `OBJECT` and `ARRAY`.
        """
        return self.value <= 1

    def __eq__(self, other: Self) -> Bool:
        """Compare two kinds.

        Args:
            other: The other kind.

        Returns:
            True when the kinds are equal.
        """
        return self.value == other.value


@fieldwise_init
struct _PathItem(Copyable, Movable):
    """One step of the value path, as upstream `pathItem`."""

    var kind: _PathItemKind
    """The kind of the step."""
    var name: String
    """The member name, for an object step."""
    var array_index: Int
    """The item index, for an array step."""


comptime _NONE = -1
"""The index of a missing JSON value, as a nil upstream `*astjson.Value`."""


def _member(json: JsonDocument, node: Int, key: StringSlice) -> Int:
    """Return the first member of an object with a key, as `astjson` `Get`.

    Args:
        json: The variables.
        node: The value's index.
        key: The decoded key.

    Returns:
        The member's index, or `_NONE` when the value is not an object or
        has no such member.
    """
    if json.kind(node) != JsonKind.OBJECT:
        return _NONE
    var current = json.first(node)
    while current != _NONE:
        if json.key_equals(current, key):
            return current
        current = json.next(current)
    return _NONE


def _is_null(json: JsonDocument, node: Int) -> Bool:
    """Tell whether a value is missing or `null`.

    Args:
        json: The variables.
        node: The value's index, or `_NONE`.

    Returns:
        True for a missing value and for `null`.
    """
    return node == _NONE or json.kind(node) == JsonKind.NULL


def _print_type(operation: Document, node: Int) -> String:
    """Write an operation type reference as SDL, as upstream `PrintType`.

    Args:
        operation: The operation document.
        node: A `NamedType`, `ListType` or `NonNullType`.

    Returns:
        The type, such as `[Int!]!`.
    """
    var kind = operation.kind(node)
    if kind == Kind.NON_NULL_TYPE:
        return _print_type(operation, operation.first_child(node)) + "!"
    if kind == Kind.LIST_TYPE:
        return "[" + _print_type(operation, operation.first_child(node)) + "]"
    return String(operation.name(node))


struct VariablesValidator(Movable):
    """Validates the variables JSON of a request, as upstream
    `VariablesValidator`.

    The validator keeps the variables map of `validate_with_remap` for the
    next calls, as upstream does.
    """

    var options: VariablesValidatorOptions
    """The options."""
    var variables_map: Optional[Dict[String, String]]
    """The operation variable names to the request variable names."""
    var _err: Optional[InvalidVariableError]
    var _name: String
    var _value: Int
    var _path: List[_PathItem]

    def __init__(out self, options: VariablesValidatorOptions):
        """Make a validator, as upstream `NewVariablesValidator`.

        Args:
            options: The options.
        """
        self.options = options
        self.variables_map = None
        self._err = None
        self._name = String()
        self._value = _NONE
        self._path = List[_PathItem]()

    def validate_with_remap(
        mut self,
        operation: Document,
        schema: Schema,
        variables: StringSlice,
        variables_map: Dict[String, String],
    ) raises JsonError -> Optional[InvalidVariableError]:
        """Validate with renamed variables, as upstream `ValidateWithRemap`.

        Args:
            operation: The operation document.
            schema: The schema.
            variables: The variables JSON.
            variables_map: The operation variable names to the request
                variable names.

        Returns:
            The first invalid variable, or None.

        Raises:
            JsonError: When the variables are not JSON.
        """
        self.variables_map = variables_map.copy()
        return self.validate(operation, schema, variables)

    def validate(
        mut self, operation: Document, schema: Schema, variables: StringSlice
    ) raises JsonError -> Optional[InvalidVariableError]:
        """Validate the variables of each operation, as upstream `Validate`.

        Args:
            operation: The operation document.
            schema: The schema.
            variables: The variables JSON.

        Returns:
            The first invalid variable, or None.

        Raises:
            JsonError: When the variables are not JSON.
        """
        var json = parse(variables)
        self._err = None
        var definitions = operation.definitions()
        var at = 0
        while at < len(definitions):
            var definition = definitions[at]
            at += 1
            if operation.kind(definition) != Kind.OPERATION_DEFINITION:
                continue
            var node = operation.child(definition, Role.VARIABLE_DEFINITION)
            while node != _NONE:
                self._enter_variable_definition(operation, schema, json, node)
                node = operation.next_with_role(node)
        return self._err.copy()

    def _enter_variable_definition(
        mut self,
        operation: Document,
        schema: Schema,
        json: JsonDocument,
        node: Int,
    ):
        """Validate one variable, as upstream `EnterVariableDefinition`.

        Args:
            operation: The operation document.
            schema: The schema.
            json: The variables.
            node: The `VariableDefinition`.
        """
        var name = String(operation.name(operation.child(node, Role.VARIABLE)))
        if self.variables_map:
            var mapped = self.variables_map.value().get(name)
            if mapped:
                name = mapped.value()
        self._name = name
        self._value = _member(json, json.root, name)
        self._path.clear()
        self._push_object_path(name)
        self._traverse_operation_type(
            operation,
            schema,
            json,
            self._value,
            operation.child(node, Role.TYPE),
        )

    def _render_path(self) -> String:
        """Write the value path, as upstream `renderPath`.

        Returns:
            The path, such as `input.list.[0]`.
        """
        var out = String()
        var index = 0
        while index < len(self._path):
            if index > 0:
                out += "."
            out += self._path[index].name
            if self._path[index].kind == _PathItemKind.ARRAY:
                out += "[" + String(self._path[index].array_index) + "]"
            index += 1
        return out^

    def _push_object_path(mut self, name: String):
        """Enter an object member, as upstream `pushObjectPath`.

        Args:
            name: The member name.
        """
        self._path.append(_PathItem(_PathItemKind.OBJECT, name, 0))

    def _push_array_path(mut self, index: Int):
        """Enter an array item, as upstream `pushArrayPath`.

        Args:
            index: The item index.
        """
        self._path.append(_PathItem(_PathItemKind.ARRAY, String(), index))

    def _pop_path(mut self):
        """Leave the last step, as upstream `popPath`."""
        _ = self._path.pop()

    def _at_path(self) -> String:
        """Write the ` at "path"` part of a nested message.

        Returns:
            The part, or empty at the top level.
        """
        if len(self._path) > 1:
            return ' at "' + self._render_path() + '"'
        return String()

    # --- messages -------------------------------------------------------

    def _invalid_value_if_allowed(self, content: String) -> String:
        """Write the `: value` part, as upstream `invalidValueIfAllowed`.

        Args:
            content: The value as JSON.

        Returns:
            The part, or empty when the options hide the values.
        """
        if self.options.disable_exposing_variables_content:
            return String()
        return ": " + content

    def _invalid_enum_value_if_allowed(self, content: String) -> String:
        """Write the `"value" ` part, as upstream
        `invalidEnumValueIfAllowed`.

        Args:
            content: The enum value.

        Returns:
            The part, or empty when the options hide the values.
        """
        if self.options.disable_exposing_variables_content:
            return String()
        return '"' + content + '" '

    def _invalid_value_message(self, content: String) -> String:
        """Write the message start, as upstream `invalidValueMessage`.

        Args:
            content: The value as JSON.

        Returns:
            `Variable "$name" got invalid value`, with the value when the
            options show the values.
        """
        var start = 'Variable "$' + self._name + '" got invalid value'
        if self.options.disable_exposing_variables_content:
            return start^
        return start + " " + content

    def _set_error(mut self, message: String):
        """Record an error, as upstream `newInvalidVariableError`.

        Args:
            message: The full message.
        """
        if (
            self.options.apollo_router_compatibility_flags.replace_invalid_var_error
        ):
            self._err = InvalidVariableError(
                String(VALIDATION_INVALID_TYPE_VARIABLE),
                "invalid type for variable: '" + self._name + "'",
            )
            return
        var code = String()
        if self.options.apollo_compatibility_flags.replace_invalid_var_error:
            code = String(BAD_USER_INPUT)
        self._err = InvalidVariableError(code^, message)

    def _render_variable_required_error(
        mut self, operation: Document, type_node: Int
    ):
        """Report a missing variable, as upstream
        `renderVariableRequiredError`.

        Args:
            operation: The operation document.
            type_node: The variable's type.
        """
        self._set_error(
            'Variable "$'
            + self._name
            + '" of required type "'
            + _print_type(operation, type_node)
            + '" was not provided.'
        )

    def _render_variable_invalid_null_error(
        mut self, operation: Document, type_node: Int
    ):
        """Report a `null` variable of a non-null type, as upstream
        `renderVariableInvalidNullError`.

        Args:
            operation: The operation document.
            type_node: The variable's type.
        """
        self._set_error(
            'Variable "$'
            + self._name
            + '" got invalid value null; Expected non-nullable type "'
            + _print_type(operation, type_node)
            + '" not to be null.'
        )

    def _render_variable_invalid_object_type_error(
        mut self, json: JsonDocument, value: Int, type_name: String
    ):
        """Report a value of the wrong shape, as upstream
        `renderVariableInvalidObjectTypeError`.

        Args:
            json: The variables.
            value: The value.
            type_name: The expected type's name.
        """
        self._set_error(
            self._invalid_value_message(stringify(json, value))
            + '; Expected type "'
            + type_name
            + '" to be an object.'
        )

    def _render_variable_required_not_provided_error(
        mut self,
        schema: Schema,
        json: JsonDocument,
        field: String,
        type: TypeRef,
    ):
        """Report a missing required input field, as upstream
        `renderVariableRequiredNotProvidedError`.

        Args:
            schema: The schema.
            json: The variables.
            field: The field's name.
            type: The field's type.
        """
        self._set_error(
            self._invalid_value_message(stringify(json, self._value))
            + '; Field "'
            + field
            + '" of required type "'
            + schema.type_name(type)
            + '" was not provided.'
        )

    def _render_variable_list_expected_error(
        mut self, json: JsonDocument, value: Int, type_name: String
    ):
        """Report a single value for a list input field, as the input object
        branch of upstream `renderVariableInvalidNestedTypeError`.

        Args:
            json: The variables.
            value: The value.
            type_name: The item type's name.
        """
        self._set_error(
            self._invalid_value_message(stringify(json, value))
            + self._at_path()
            + '; Got input type "'
            + type_name
            + '", want: "['
            + type_name
            + ']"'
        )

    def _render_variable_invalid_leaf_error(
        mut self, json: JsonDocument, value: Int, phrase: String, end: String
    ):
        """Report a value that a scalar or an enum cannot represent, as the
        leaf branches of upstream `renderVariableInvalidNestedTypeError`.

        Args:
            json: The variables.
            value: The value.
            phrase: The reason, such as `Int cannot represent non-integer
                value`.
            end: The text after the value, `.` for an enum.
        """
        var content = stringify(json, value)
        self._set_error(
            self._invalid_value_message(content)
            + self._at_path()
            + "; "
            + phrase
            + self._invalid_value_if_allowed(content)
            + end
        )

    def _render_variable_field_not_defined_error(
        mut self, json: JsonDocument, field: String, type_name: String
    ):
        """Report an input field that the type does not define, as upstream
        `renderVariableFieldNotDefinedError`.

        Args:
            json: The variables.
            field: The field's name.
            type_name: The input object type's name.
        """
        self._set_error(
            self._invalid_value_message(stringify(json, self._value))
            + ' at "'
            + self._render_path()
            + '"; Field "'
            + field
            + '" is not defined by type "'
            + type_name
            + '".'
        )

    def _render_variable_enum_value_does_not_exist_error(
        mut self, json: JsonDocument, type_name: String, enum_value: String
    ):
        """Report an unknown enum value, as upstream
        `renderVariableEnumValueDoesNotExistError`.

        Args:
            json: The variables.
            type_name: The enum type's name.
            enum_value: The value.
        """
        self._set_error(
            self._invalid_value_message(stringify(json, self._value))
            + self._at_path()
            + "; Value "
            + self._invalid_enum_value_if_allowed(enum_value)
            + 'does not exist in "'
            + type_name
            + '" enum.'
        )

    # --- traversal ------------------------------------------------------

    def _traverse_operation_type(
        mut self,
        operation: Document,
        schema: Schema,
        json: JsonDocument,
        value: Int,
        type_node: Int,
    ):
        """Check a value against an operation type, as upstream
        `traverseOperationType`.

        Args:
            operation: The operation document.
            schema: The schema.
            json: The variables.
            value: The value, or `_NONE`.
            type_node: The type reference in the operation.
        """
        var type_name = String(operation.named_type(type_node))
        var kind = operation.kind(type_node)
        if kind == Kind.NON_NULL_TYPE:
            if value == _NONE:
                self._render_variable_required_error(operation, type_node)
                return
            if (
                json.kind(value) == JsonKind.NULL
                and type_name != "Upload"
                and not self.options.apollo_router_compatibility_flags.skip_null_variables_error
            ):
                self._render_variable_invalid_null_error(operation, type_node)
                return
            self._traverse_operation_type(
                operation, schema, json, value, operation.first_child(type_node)
            )
            return
        if _is_null(json, value):
            return
        if kind == Kind.LIST_TYPE:
            if json.kind(value) != JsonKind.ARRAY:
                self._render_variable_invalid_object_type_error(
                    json, value, type_name
                )
                return
            var item_type = operation.first_child(type_node)
            var item = json.first(value)
            var index = 0
            while item != _NONE:
                self._push_array_path(index)
                self._traverse_operation_type(
                    operation, schema, json, item, item_type
                )
                self._pop_path()
                item = json.next(item)
                index += 1
            return
        self._traverse_named_type(schema, json, value, type_name)

    def _traverse_field_definition_type(
        mut self,
        schema: Schema,
        json: JsonDocument,
        field: Int,
        field_name: String,
        value: Int,
        type: TypeRef,
    ):
        """Check a value against an input field type, as upstream
        `traverseFieldDefinitionType`.

        Args:
            schema: The schema.
            json: The variables.
            field: The input value's index in `Schema.input_values`.
            field_name: The field's name.
            value: The value, or `_NONE`.
            type: The type, or a part of it under the wrappers.
        """
        if type.is_non_null():
            var inner = type.of_type()
            if _is_null(json, value):
                if (
                    not inner.is_wrapped()
                    and schema.types[Int(inner.named)].name == "Upload"
                ):
                    return
                # An undefined required input field is valid if it has a
                # default value.
                if schema.input_values[field].has_default():
                    return
                self._render_variable_required_not_provided_error(
                    schema, json, field_name, type
                )
                return
            self._traverse_field_definition_type(
                schema, json, field, field_name, value, inner
            )
            return
        if _is_null(json, value):
            return
        var type_name = String(schema.types[Int(type.named)].name)
        if type.is_list():
            if json.kind(value) != JsonKind.ARRAY:
                self._render_variable_list_expected_error(
                    json, value, type_name
                )
                return
            var item_type = type.of_type()
            var item = json.first(value)
            var index = 0
            while item != _NONE:
                self._push_array_path(index)
                self._traverse_field_definition_type(
                    schema, json, field, field_name, item, item_type
                )
                self._pop_path()
                item = json.next(item)
                index += 1
            return
        self._traverse_named_type(schema, json, value, type_name)

    def _violates_one_of_constraint(
        mut self, schema: Schema, json: JsonDocument, type: Int, value: Int
    ) -> Bool:
        """Check the `@oneOf` rule, as upstream `violatesOneOfConstraint`.

        Args:
            schema: The schema.
            json: The variables.
            type: The input object type's index.
            value: The object.

        Returns:
            True when the value breaks the rule; the error is recorded.
        """
        if not schema.types[type].is_one_of:
            return False
        var type_name = String(schema.types[type].name)
        var count = json.length(value)
        # Prioritize the count error.
        if count != 1:
            self._set_error(
                self._invalid_value_message(stringify(json, value))
                + self._at_path()
                + '; OneOf input object "'
                + type_name
                + '" must have exactly one field provided, but '
                + String(count)
                + " fields were provided."
            )
            return True
        var member = json.first(value)
        if json.kind(member) != JsonKind.NULL:
            return False
        self._set_error(
            self._invalid_value_message(stringify(json, value))
            + self._at_path()
            + '; OneOf input object "'
            + type_name
            + '" field "'
            + json.key(member)
            + '" value must be non-null.'
        )
        return True

    def _traverse_named_type(
        mut self,
        schema: Schema,
        json: JsonDocument,
        value: Int,
        type_name: String,
    ):
        """Check a value against a named type, as upstream
        `traverseNamedTypeNode`.

        Args:
            schema: The schema.
            json: The variables.
            value: The value, not missing and not `null`.
            type_name: The type's name.
        """
        if self._err:
            return
        var type = schema.type_named(type_name)
        if type == _NONE:
            return
        var kind = schema.types[type].kind
        var json_kind = json.kind(value)
        if kind == TypeKind.INPUT_OBJECT:
            if json_kind != JsonKind.OBJECT:
                self._render_variable_invalid_object_type_error(
                    json, value, type_name
                )
                return
            var fields = schema.types[type].input_fields
            var index = Int(fields.start)
            while index < fields.end():
                if self._err:
                    return
                var field_name = String(schema.input_values[index].name)
                var field_value = _member(json, value, field_name)
                self._push_object_path(field_name)
                self._traverse_field_definition_type(
                    schema,
                    json,
                    index,
                    field_name,
                    field_value,
                    schema.input_values[index].type,
                )
                self._pop_path()
                index += 1
            # Validate that all input fields present in the object are
            # defined in the input object definition.
            var member = json.first(value)
            while member != _NONE:
                var key = json.key(member)
                if schema.input_field_named(type, key) == _NONE:
                    self._render_variable_field_not_defined_error(
                        json, key, type_name
                    )
                    return
                member = json.next(member)
            _ = self._violates_one_of_constraint(schema, json, type, value)
            return
        if kind == TypeKind.ENUM:
            if json_kind != JsonKind.STRING:
                self._render_variable_invalid_leaf_error(
                    json,
                    value,
                    'Enum "'
                    + type_name
                    + '" cannot represent non-string value',
                    ".",
                )
                return
            var enum_value = json.string_value(value)
            var found = schema.enum_value_named(type, enum_value)
            if found == _NONE or _is_inaccessible(schema, found):
                self._render_variable_enum_value_does_not_exist_error(
                    json, type_name, enum_value
                )
            return
        if kind == TypeKind.SCALAR:
            self._check_scalar(json, value, type_name)

    def _check_scalar(
        mut self, json: JsonDocument, value: Int, type_name: String
    ):
        """Check a value against a built-in scalar, as the scalar branch of
        upstream `traverseNamedTypeNode`. A custom scalar takes any value.

        Args:
            json: The variables.
            value: The value, not missing and not `null`.
            type_name: The scalar's name.
        """
        var json_kind = json.kind(value)
        var phrase: String
        if type_name == "String":
            if json_kind == JsonKind.STRING:
                return
            phrase = "String cannot represent a non string value"
        elif type_name == "Int":
            if json_kind == JsonKind.NUMBER:
                return
            phrase = "Int cannot represent non-integer value"
        elif type_name == "Float":
            if json_kind == JsonKind.NUMBER:
                return
            phrase = "Float cannot represent non numeric value"
        elif type_name == "Boolean":
            if json_kind == JsonKind.BOOLEAN:
                return
            phrase = "Boolean cannot represent a non boolean value"
        elif type_name == "ID":
            if json_kind == JsonKind.STRING or json_kind == JsonKind.NUMBER:
                return
            phrase = "ID cannot represent a non-string and non-integer value"
        else:
            return
        self._render_variable_invalid_leaf_error(json, value, phrase, "")


def _is_inaccessible(schema: Schema, enum_value: Int) -> Bool:
    """Tell whether `@inaccessible` is applied to an enum value, as the
    directive check of upstream
    `EnumTypeDefinitionContainsEnumValueWithDirective`.

    Args:
        schema: The schema.
        enum_value: The value's index in `Schema.enum_values`.

    Returns:
        True when the value has `@inaccessible`.
    """
    var directives = schema.enum_values[enum_value].directives
    var index = Int(directives.start)
    while index < directives.end():
        var at = schema.applied[index]
        if (
            schema.documents[Int(at.document)].name(Int(at.node))
            == "inaccessible"
        ):
            return True
        index += 1
    return False
