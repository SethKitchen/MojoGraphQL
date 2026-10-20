# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The file uploads of an argument: graphql-go-tools v2
`astnormalization/uploads`, `UploadFinder` and `UploadPathMapping`.

An upload is a `null` in the variables JSON at a position of the scalar
type `Upload`, as the GraphQL multipart request specification sends it. The
finder walks the value of one argument, and the variables JSON that the
value names, and returns the path of each upload.

Differences from upstream:

- The variables JSON is read in place. Upstream parses it with `astjson`,
  and returns its error for text that is not JSON.
- A type is a `gql_schema` `TypeRef`, so a list item has the type of its
  list. Upstream reads `OfType` of the list type. Only the name of the type
  is read in both.
"""

from gql_language.ast import Document, Kind, NO_NODE, Role
from gql_schema.definition import Schema, TypeKind, TypeRef

from gql_normalization.values import is_list, is_non_null, unwrap
from gql_normalization.variables_json import (
    elements,
    json_kind,
    members,
    top_level_member,
)

comptime UPLOAD = "Upload"
"""The name of the upload scalar: `uploadScalarName`."""


@fieldwise_init
struct UploadPathMapping(Copyable, ImplicitlyCopyable, Movable, Writable):
    """Where an upload is: upstream `UploadPathMapping`."""

    var variable_name: String
    """The variable that holds the upload: `VariableName`."""
    var original_upload_path: String
    """The path of the upload in the request, such as `variables.f`:
    `OriginalUploadPath`."""
    var new_upload_path: String
    """The path after the extraction of an inline object, such as
    `variables.a.f`, or empty when it does not change: `NewUploadPath`."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the three fields, separated by spaces.

        Args:
            writer: The destination.
        """
        writer.write(
            self.variable_name,
            " ",
            self.original_upload_path,
            " ",
            self.new_upload_path,
        )


def _render(path: List[String]) -> String:
    """Join a path with dots: `Path.render`."""
    var out = String()
    var index = 0
    while index < len(path):
        if index > 0:
            out += "."
        out += path[index]
        index += 1
    return out^


def _member(text: StringSlice, name: StringSlice) -> Optional[String]:
    """Return the raw value of a member of a JSON object, if it has one."""
    var found = members(text)
    var index = 0
    while index < len(found):
        if found[index].key(text) == name:
            return String(found[index].value(text))
        index += 1
    return None


struct UploadFinder(Movable):
    """Finds the uploads of one argument at a time: upstream
    `UploadFinder`."""

    var _arg_path: List[String]
    var _variable_path: List[String]
    var _variable_name: String
    var _used_directly: Bool
    var _mappings: List[UploadPathMapping]

    def __init__(out self):
        """Make a finder: `NewUploadFinder`."""
        self._arg_path = List[String]()
        self._variable_path = List[String]()
        self._variable_name = String()
        self._used_directly = False
        self._mappings = List[UploadPathMapping]()

    def reset(mut self):
        """Forget the uploads found so far: `Reset`."""
        self._arg_path.clear()
        self._variable_path.clear()
        self._variable_name = String()
        self._used_directly = False
        self._mappings.clear()

    def find_uploads(
        mut self,
        operation: Document,
        schema: Schema,
        variables: StringSlice,
        argument: Int,
        type: TypeRef,
    ) -> List[UploadPathMapping]:
        """Find the uploads of an argument: `FindUploads`.

        As upstream, the uploads add to those found since the last
        `reset`, and the result has all of them.

        Args:
            operation: The operation document.
            schema: The schema.
            variables: The variables JSON; empty means `{}`.
            argument: The argument node.
            type: The type of the argument in the schema.

        Returns:
            The uploads, or an empty list when the schema has no scalar
            `Upload` or there is none.
        """
        var upload = schema.type_named(UPLOAD)
        if upload < 0 or schema.types[upload].kind != TypeKind.SCALAR:
            return List[UploadPathMapping]()
        self._arg_path.clear()
        self._variable_path.clear()
        var json = String(variables)
        if json == "" or json == "null":
            json = "{}"
        self._value(
            operation,
            schema,
            json,
            operation.child(argument, Role.VALUE),
            type,
        )
        return self._mappings.copy()

    def _add(mut self):
        """Add the current path: `AddUploadPath`."""
        var new_path = String()
        if not self._used_directly:
            new_path = _render(self._arg_path)
        self._mappings.append(
            UploadPathMapping(
                self._variable_name, _render(self._variable_path), new_path^
            )
        )

    def _value(
        mut self,
        operation: Document,
        schema: Schema,
        variables: String,
        value: Int,
        type: TypeRef,
    ):
        """Walk an argument value: `traverseValue`."""
        var kind = operation.kind(value)
        if kind == Kind.VARIABLE:
            self._used_directly = len(self._arg_path) == 0
            self._variable(operation, schema, variables, value, type)
        elif kind == Kind.LIST:
            var index = 0
            var item = operation.first_child(value)
            while item != NO_NODE:
                self._arg_path.append(String(index))
                self._value(operation, schema, variables, item, type)
                _ = self._arg_path.pop()
                index += 1
                item = operation.next_sibling(item)
        elif kind == Kind.OBJECT:
            var named = Int(type.named)
            if schema.types[named].kind != TypeKind.INPUT_OBJECT:
                return
            var field = operation.first_child(value)
            while field != NO_NODE:
                var name = operation.name(field)
                var input = schema.input_field_named(named, name)
                if input >= 0:
                    self._arg_path.append(String(name))
                    self._value(
                        operation,
                        schema,
                        variables,
                        operation.child(field, Role.VALUE),
                        schema.input_values[input].type,
                    )
                    _ = self._arg_path.pop()
                field = operation.next_sibling(field)
        elif kind == Kind.NULL:
            if schema.types[Int(type.named)].name == UPLOAD:
                self._add()

    def _variable(
        mut self,
        operation: Document,
        schema: Schema,
        variables: String,
        value: Int,
        type: TypeRef,
    ):
        """Walk the JSON of a variable: `traverseVariable`."""
        var name = String(operation.name(value))
        self._variable_name = name
        var json: Optional[String] = None
        var index = top_level_member(variables, name)
        if index >= 0:
            json = String(members(variables)[index].value(variables))
        # As upstream, the variable is looked up in the first operation.
        var definition = operation.first_child(operation.root)
        while (
            definition != NO_NODE
            and operation.kind(definition) != Kind.OPERATION_DEFINITION
        ):
            definition = operation.next_sibling(definition)
        if definition == NO_NODE:
            return
        var found = NO_NODE
        var variable = operation.child(definition, Role.VARIABLE_DEFINITION)
        while variable != NO_NODE:
            if operation.name(operation.child(variable, Role.VARIABLE)) == name:
                found = variable
                break
            variable = operation.next_with_role(variable)
        if found == NO_NODE:
            return
        var type_node = operation.child(found, Role.TYPE)
        var named = type_node
        while operation.kind(named) != Kind.NAMED_TYPE:
            named = operation.child(named, Role.TYPE)
        if not (operation.name(named) == schema.types[Int(type.named)].name):
            return
        self._variable_path.append("variables")
        self._variable_path.append(name)
        self._operation_type(operation, schema, json, type_node)
        _ = self._variable_path.pop()
        _ = self._variable_path.pop()

    def _operation_type(
        mut self,
        operation: Document,
        schema: Schema,
        json: Optional[String],
        type: Int,
    ):
        """Walk a JSON value along the type of a variable:
        `traverseOperationType`."""
        if not json:
            return
        ref text = json.value()
        var kind = operation.kind(type)
        if kind == Kind.NON_NULL_TYPE:
            self._operation_type(
                operation, schema, json, operation.child(type, Role.TYPE)
            )
            return
        if kind == Kind.LIST_TYPE:
            if json_kind(text) != UInt8(ord("[")):
                return
            var items = elements(text)
            var index = 0
            while index < len(items):
                self._arg_path.append(String(index))
                self._variable_path.append(String(index))
                self._operation_type(
                    operation,
                    schema,
                    String(text[byte = items[index][0] : items[index][1]]),
                    operation.child(type, Role.TYPE),
                )
                _ = self._arg_path.pop()
                _ = self._variable_path.pop()
                index += 1
            return
        var name = String(operation.name(type))
        if name == UPLOAD and json_kind(text) == UInt8(ord("n")):
            self._add()
            return
        self._named(schema, text, name)

    def _definition_type(mut self, schema: Schema, text: String, type: TypeRef):
        """Walk a JSON value along the type of an input field:
        `traverseFieldDefinitionType`."""
        if is_non_null(type):
            self._definition_type(schema, text, unwrap(type))
            return
        if is_list(type):
            if json_kind(text) != UInt8(ord("[")):
                return
            var items = elements(text)
            var index = 0
            while index < len(items):
                self._arg_path.append(String(index))
                self._variable_path.append(String(index))
                self._definition_type(
                    schema,
                    String(text[byte = items[index][0] : items[index][1]]),
                    unwrap(type),
                )
                _ = self._arg_path.pop()
                _ = self._variable_path.pop()
                index += 1
            return
        self._named(schema, text, schema.types[Int(type.named)].name)

    def _named(mut self, schema: Schema, text: String, name: StringSlice):
        """Walk a JSON value of a named type: `traverseNamedTypeNode`."""
        # The name is the name of a type of the schema: the type of an
        # input field, or the type of the argument that the variable fills.
        var type = schema.type_named(name)
        var kind = schema.types[type].kind
        if kind == TypeKind.INPUT_OBJECT:
            if json_kind(text) != UInt8(ord("{")):
                return
            var fields = schema.types[type].input_fields
            var index = Int(fields.start)
            while index < fields.end():
                ref field = schema.input_values[index]
                index += 1
                var value = _member(text, field.name)
                if not value:
                    continue
                self._arg_path.append(field.name)
                self._variable_path.append(field.name)
                self._definition_type(schema, value.value(), field.type)
                _ = self._arg_path.pop()
                _ = self._variable_path.pop()
        elif kind == TypeKind.SCALAR:
            if name == UPLOAD and json_kind(text) == UInt8(ord("n")):
                self._add()
