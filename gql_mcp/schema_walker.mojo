# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The JSON Schema of the variables of an operation.

Port of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/operations/schema_walker.rs`,
`operations/schema_walker/type.rs` and `operations/schema_walker/name.rs`.

`type_to_schema` turns the type of a variable into a JSON Schema in a
`JsonTree`. A nullable type is `{"anyOf": [inner, {"type": "null"}]}`. An
enum, an input object and a custom scalar go into a shared `definitions`
object, and the property names them with `$ref`. A default value of the
variable, or of an input field, becomes `default`, coerced to the declared
type as GraphQL input coercion does.

The result is in insertion order, as a `schemars::Schema` is. Call
`JsonTree.order_schema` where the upstream calls `serde_json::to_value`.

Differences from upstream:

- A type is a `gql_schema.TypeRef`. A variable type that the schema does
  not have is a `TypeRef` whose `named` is `NO_TYPE`; its schema is `{}`,
  as upstream.
- The upstream logs a warning for an unknown type and a custom scalar
  without a map. This module logs nothing.
- A float default is written as `serde_json` writes an `f64` (the
  layout of `serde_json` 1.0.149, such as `1.0` and `1e+16`), so the text is
  the upstream text.
"""

from gql_json.number import IntStatus, read_float64, read_int64, write_number
from gql_json.value import JsonKind, NO_NODE
from gql_language.ast import Document, Kind, Role
from gql_mcp.custom_scalar_map import CustomScalarMap
from gql_mcp.json_tree import JsonTree
from gql_schema.definition import NO_TYPE, AstRef, Schema, TypeKind, TypeRef


comptime BUILTIN_STRING = -2
"""The `named` of `ast_type_ref` for `String`."""
comptime BUILTIN_ID = -3
"""The `named` of `ast_type_ref` for `ID`."""
comptime BUILTIN_FLOAT = -4
"""The `named` of `ast_type_ref` for `Float`."""
comptime BUILTIN_INT = -5
"""The `named` of `ast_type_ref` for `Int`."""
comptime BUILTIN_BOOLEAN = -6
"""The `named` of `ast_type_ref` for `Boolean`."""


def builtin_scalar(name: StringSlice) -> Int:
    """Return the code of a specified scalar's name.

    A `gql_schema` schema has only the specified scalars that it uses, as a
    graphql-js schema. An apollo-compiler schema has all five, and the
    upstream maps them by name. So a variable type names them by a code.

    Args:
        name: A type name.

    Returns:
        One of the `BUILTIN_` codes, or `NO_TYPE` for another name.
    """
    if name == "String":
        return BUILTIN_STRING
    if name == "ID":
        return BUILTIN_ID
    if name == "Float":
        return BUILTIN_FLOAT
    if name == "Int":
        return BUILTIN_INT
    if name == "Boolean":
        return BUILTIN_BOOLEAN
    return NO_TYPE


def ast_type_ref(schema: Schema, document: Document, type_node: Int) -> TypeRef:
    """Return the type that a type node names, with its wrappers.

    Args:
        schema: The schema to look the named type up in.
        document: The document that holds the node.
        type_node: A `NamedType`, `ListType` or `NonNullType` node.

    Returns:
        The type. Its `named` is a `BUILTIN_` code for a specified scalar,
        `NO_TYPE` when the schema has no type with the name, or else the
        index of the type; do not index `schema.types` with a code.
    """
    var wrappers = List[Kind]()
    var current = type_node
    while document.kind(current) != Kind.NAMED_TYPE:
        wrappers.append(document.kind(current))
        current = document.child(current, Role.TYPE)
    var name = document.name(current)
    var named = builtin_scalar(name)
    if named == NO_TYPE:
        named = schema.type_named(name)
    var type = TypeRef.of(named)
    var index = len(wrappers) - 1
    while index >= 0:
        if wrappers[index] == Kind.LIST_TYPE:
            type = type.list_of()
        else:
            type = type.non_null()
        index -= 1
    return type


def ensure_object(mut tree: JsonTree, node: Int) -> Int:
    """Return a schema as an object, as `schemars::Schema::ensure_object`.

    Args:
        tree: The tree.
        node: A schema: an object, `true` or `false`.

    Returns:
        The node itself for an object; a new `{}` for `true`, and a new
        `{"not": {}}` for `false`.
    """
    if tree.kind(node) != JsonKind.BOOLEAN:
        return node
    var object = tree.add_object()
    if tree.text(node) == "false":
        tree.set(object, "not", tree.add_object())
    return object


def with_desc(
    mut tree: JsonTree, node: Int, description: Optional[String]
) -> Int:
    """Add a description to a schema unless it has one.

    Args:
        tree: The tree.
        node: The schema.
        description: The description, or none.

    Returns:
        The schema, an object when a description was given.
    """
    if not description:
        return node
    var object = ensure_object(tree, node)
    _ = tree.entry(object, "description", tree.add_string(description.value()))
    return object


def simple_type(mut tree: JsonTree, type: StringSlice) -> Int:
    """Add `{"type": <type>}`.

    Args:
        tree: The tree.
        type: The JSON type name, such as `string`.

    Returns:
        The new schema.
    """
    var object = tree.add_object()
    tree.set(object, "type", tree.add_string(type))
    return object


def ref_schema(mut tree: JsonTree, name: StringSlice) -> Int:
    """Add `{"$ref": "#/definitions/<name>"}`, as `Schema::new_ref`.

    Args:
        tree: The tree.
        name: The definition's name.

    Returns:
        The new schema.
    """
    var object = tree.add_object()
    tree.set(object, "$ref", tree.add_string(String("#/definitions/") + name))
    return object


def nullable(mut tree: JsonTree, inner: Int) -> Int:
    """Add `{"anyOf": [inner, {"type": "null"}]}`.

    Args:
        tree: The tree.
        inner: The schema of the non-null value.

    Returns:
        The new schema.
    """
    var options = tree.add_array()
    tree.push(options, inner)
    tree.push(options, simple_type(tree, "null"))
    var object = tree.add_object()
    tree.set(object, "anyOf", options)
    return object


def type_to_schema(
    mut tree: JsonTree,
    definitions: Int,
    schema: Schema,
    type: TypeRef,
    custom_scalars: CustomScalarMap,
    description: Optional[String],
    default_document: Document,
    default_node: Int,
) -> Int:
    """Return the JSON Schema of a type, as upstream `type_to_schema`.

    Args:
        tree: The tree to add the schema to.
        definitions: An object of `tree` that collects the named schemas;
            all the variables of an operation share it.
        schema: The GraphQL schema.
        type: The type of the variable or the input field.
        custom_scalars: The schemas of custom scalars; an empty map is the
            upstream `None`.
        description: The description of the outermost schema, or none.
        default_document: The document that holds the default value.
        default_node: The default value literal, or `NO_NODE`.

    Returns:
        The schema's index in `tree`.
    """
    var node = _walk_type(
        tree, definitions, schema, type, custom_scalars, description
    )
    return _with_default(
        tree, node, schema, type, default_document, default_node
    )


def _with_default(
    mut tree: JsonTree,
    node: Int,
    schema: Schema,
    type: TypeRef,
    document: Document,
    default_node: Int,
) -> Int:
    """Add the JSON of a default value, when it has a JSON form."""
    if default_node == NO_NODE:
        return node
    var value = graphql_value_to_json(
        tree, document, default_node, Optional(type), schema
    )
    if value == NO_NODE:
        return node
    var object = ensure_object(tree, node)
    tree.set(object, "default", value)
    return object


def _walk_type(
    mut tree: JsonTree,
    definitions: Int,
    schema: Schema,
    type: TypeRef,
    custom_scalars: CustomScalarMap,
    description: Optional[String],
) -> Int:
    """The schema of a type, from the named type out, as `type.rs`."""
    # Split the wrappers into levels, the outermost first: each level is a
    # list or the named type, and it is non-null or nullable.
    var lists = List[Bool]()
    var non_null = List[Bool]()
    var bits = type.bits
    var depth = Int(type.depth)
    var level_non_null = False
    while depth > 0:
        if bits & 1 == 0:
            level_non_null = True
        else:
            lists.append(True)
            non_null.append(level_non_null)
            level_non_null = False
        bits >>= 1
        depth -= 1
    var node = _walk_name(tree, definitions, schema, type.named, custom_scalars)
    if not level_non_null:
        node = nullable(tree, node)
    var index = len(lists) - 1
    while index >= 0:
        var array = simple_type(tree, "array")
        tree.set(array, "items", node)
        node = array
        if not non_null[index]:
            node = nullable(tree, node)
        index -= 1
    return with_desc(tree, node, description)


def _walk_name(
    mut tree: JsonTree,
    definitions: Int,
    schema: Schema,
    named: Int32,
    custom_scalars: CustomScalarMap,
) -> Int:
    """The schema of a named type, as `name.rs`."""
    var code = Int(named)
    if code >= 0:
        code = builtin_scalar(schema.types[Int(named)].name)
    if code == BUILTIN_STRING or code == BUILTIN_ID:
        return simple_type(tree, "string")
    if code == BUILTIN_FLOAT:
        return simple_type(tree, "number")
    if code == BUILTIN_INT:
        return simple_type(tree, "integer")
    if code == BUILTIN_BOOLEAN:
        return simple_type(tree, "boolean")
    if Int(named) == NO_TYPE:
        return tree.add_object()
    ref type = schema.types[Int(named)]
    if tree.position(definitions, type.name) >= 0:
        return ref_schema(tree, type.name)
    if type.kind == TypeKind.ENUM:
        tree.set(definitions, type.name, _enum_schema(tree, schema, Int(named)))
    elif type.kind == TypeKind.INPUT_OBJECT:
        _input_object(tree, definitions, schema, Int(named), custom_scalars)
    elif type.kind == TypeKind.SCALAR:
        var scalar_description = _description(schema, type.description)
        var custom = custom_scalars.get(type.name)
        var node: Int
        if custom != NO_NODE:
            node = tree.copy_from(custom_scalars.tree, custom)
            var own = NO_NODE
            if tree.kind(node) == JsonKind.OBJECT:
                own = tree.find(node, "description")
            if own != NO_NODE and tree.kind(own) == JsonKind.STRING:
                scalar_description = tree.text(own)
        else:
            node = tree.add_bool(True)
        tree.set(
            definitions, type.name, with_desc(tree, node, scalar_description)
        )
    else:
        return tree.add_object()
    return ref_schema(tree, type.name)


def _description(schema: Schema, at: AstRef) -> Optional[String]:
    """A schema description, or none when there is no description."""
    if not at.exists():
        return None
    return schema.description_text(at)


def _enum_schema(mut tree: JsonTree, schema: Schema, type: Int) -> Int:
    """`{"type": "string", "enum": [...]}` with a description that lists
    each value and its description."""
    ref named = schema.types[type]
    var values = tree.add_array()
    var lines = String()
    var index = Int(named.enum_values.start)
    var end = named.enum_values.end()
    while index < end:
        ref value = schema.enum_values[index]
        tree.push(values, tree.add_string(value.name))
        if index > Int(named.enum_values.start):
            lines += "\n"
        lines += value.name
        lines += ": "
        lines += schema.description_text(value.description)
        index += 1
    var object = simple_type(tree, "string")
    tree.set(object, "enum", values)
    var description = schema.description_text(named.description)
    description += "\n\nValues:\n"
    description += lines
    return with_desc(tree, object, description^)


def _input_object(
    mut tree: JsonTree,
    definitions: Int,
    schema: Schema,
    type: Int,
    custom_scalars: CustomScalarMap,
):
    """Put the schema of an input object into `definitions`; a placeholder
    goes in first, so a recursive reference finds the name."""
    ref named = schema.types[type]
    tree.set(definitions, named.name, tree.add_null())
    var object = simple_type(tree, "object")
    var properties = tree.add_object()
    tree.set(object, "properties", properties)
    object = with_desc(tree, object, _description(schema, named.description))
    var required = NO_NODE
    var index = Int(named.input_fields.start)
    var end = named.input_fields.end()
    while index < end:
        ref field = schema.input_values[index]
        var default_node = NO_NODE
        if field.default_value.exists():
            default_node = Int(field.default_value.node)
        var node = _walk_type(
            tree,
            definitions,
            schema,
            field.type,
            custom_scalars,
            _description(schema, field.description),
        )
        if default_node != NO_NODE:
            node = _with_default(
                tree,
                node,
                schema,
                field.type,
                schema.documents[Int(field.default_value.document)],
                default_node,
            )
        tree.set(properties, field.name, node)
        if field.type.is_non_null() and default_node == NO_NODE:
            if required == NO_NODE:
                required = tree.add_array()
                tree.set(object, "required", required)
            tree.push(required, tree.add_string(field.name))
        index += 1
    tree.set(definitions, named.name, object)


def graphql_value_to_json(
    mut tree: JsonTree,
    document: Document,
    value: Int,
    type: Optional[TypeRef],
    schema: Schema,
) -> Int:
    """Return the JSON that a client sends for a constant value of a type,
    as upstream `graphql_value_to_json`.

    A single value for a list type becomes a list of one item, an `Int`
    for `ID` becomes a string, and the fields of an input object follow
    their declared types.

    Args:
        tree: The tree to add the JSON to.
        document: The document that holds the value.
        value: The value literal.
        type: The declared type, or none to convert by the literal's shape.
        schema: The schema.

    Returns:
        The JSON value, or `NO_NODE` for a value with no faithful JSON: a
        variable, an integer outside `Int64`, a float outside `Float64`.
    """
    var item_type = Optional[TypeRef](None)
    if type and type.value().nullable().is_list():
        item_type = type.value().nullable().of_type()
    var kind = document.kind(value)
    if kind == Kind.NULL:
        return tree.add_null()
    if kind == Kind.VARIABLE:
        return NO_NODE
    if kind == Kind.LIST:
        var array = tree.add_array()
        var item = document.first_child(value)
        while item != NO_NODE:
            var converted = _value_item(tree, document, item, item_type, schema)
            if converted == NO_NODE:
                return NO_NODE
            tree.push(array, converted)
            item = document.next_sibling(item)
        return array
    if item_type:
        var converted = _value_item(tree, document, value, item_type, schema)
        if converted == NO_NODE:
            return NO_NODE
        var array = tree.add_array()
        tree.push(array, converted)
        return array
    if kind == Kind.BOOLEAN:
        return tree.add_bool(document.boolean_value(value))
    if kind == Kind.STRING:
        return tree.add_string(document.string_value(value))
    if kind == Kind.ENUM:
        return tree.add_string(document.text(value))
    if kind == Kind.INT:
        if type and _is_id(schema, type.value()):
            return tree.add_string(document.text(value))
        var parsed = read_int64(document.text(value).as_bytes())
        if parsed[1] != IntStatus.OK:
            return NO_NODE
        return tree.add_int(Int(parsed[0]))
    if kind == Kind.FLOAT:
        var number = read_float64(document.text(value).as_bytes())
        if number - number != 0.0:
            return NO_NODE
        return tree.add_number(ryu_text(number))
    return _object_value(tree, document, value, type, schema)


def _value_item(
    mut tree: JsonTree,
    document: Document,
    value: Int,
    type: Optional[TypeRef],
    schema: Schema,
) -> Int:
    """Convert an item or a field; the second half of a mutual recursion."""
    return graphql_value_to_json(tree, document, value, type, schema)


def _is_id(schema: Schema, type: TypeRef) -> Bool:
    """Whether the named type under the wrappers is `ID`."""
    var named = Int(type.named)
    if named >= 0:
        return schema.types[named].name == "ID"
    return named == BUILTIN_ID


def _object_value(
    mut tree: JsonTree,
    document: Document,
    value: Int,
    type: Optional[TypeRef],
    schema: Schema,
) -> Int:
    """Convert an object literal, each field against its declared type."""
    var input_object = NO_TYPE
    if type and Int(type.value().named) >= 0:
        var named = Int(type.value().named)
        if schema.types[named].kind == TypeKind.INPUT_OBJECT:
            input_object = named
    var object = tree.add_object()
    var field = document.first_child(value)
    while field != NO_NODE:
        var name = document.name(field)
        var field_type = Optional[TypeRef](None)
        if input_object != NO_TYPE:
            var at = schema.input_field_named(input_object, name)
            if at >= 0:
                field_type = schema.input_values[at].type
        var converted = _value_item(
            tree,
            document,
            document.child(field, Role.VALUE),
            field_type,
            schema,
        )
        if converted == NO_NODE:
            return NO_NODE
        tree.set(object, name, converted)
        field = document.next_sibling(field)
    return object


def ryu_text(value: Float64) -> String:
    """Return a finite `Float64` as `serde_json` writes it: the shortest
    digits, in the layout of `serde_json` 1.0.149 (the `zmij` crate).

    `1.0` is `1.0`, `1e16` is `1e+16`, `1.5e-7` is `1.5e-7` and `0.0001` is
    `0.0001`.

    Args:
        value: A finite number.

    Returns:
        The JSON text.
    """
    var js = List[UInt8]()
    write_number(js, value)
    var out = String()
    if value == 0.0:
        # `JSON.stringify` drops the sign of -0; 1 / -0 is -inf.
        if 1.0 / value < 0.0:
            return String("-0.0")
        return String("0.0")
    var digits = List[UInt8]()
    var exponent = 0
    var fraction = -1
    var index = 0
    if js[0] == UInt8(ord("-")):
        out += "-"
        index = 1
    while index < len(js) and js[index] != UInt8(ord("e")):
        if js[index] == UInt8(ord(".")):
            fraction = 0
        else:
            if fraction >= 0:
                fraction += 1
            if len(digits) > 0 or js[index] != UInt8(ord("0")):
                digits.append(js[index])
        index += 1
    if index < len(js):
        var start = index + 1
        if js[start] == UInt8(ord("+")):
            start += 1
        var exponent_text = String(unsafe_from_utf8=Span(js)[start : len(js)])
        exponent = Int(read_int64(exponent_text.as_bytes())[0])
    if fraction > 0:
        exponent -= fraction
    while digits[len(digits) - 1] == UInt8(ord("0")):
        _ = digits.pop()
        exponent += 1
    var length = len(digits)
    var point = length + exponent
    var text = String(unsafe_from_utf8=digits^)
    if exponent >= 0 and point <= 16:
        out += text
        out += String("0") * exponent
        out += ".0"
    elif point > 0 and point <= 16:
        out += String(text[byte=0:point])
        out += "."
        out += String(text[byte=point:length])
    elif point > -5 and point <= 0:
        out += "0."
        out += String("0") * (-point)
        out += text
    elif length == 1:
        out += text
        out += _exponent(point - 1)
    else:
        out += String(text[byte=0:1])
        out += "."
        out += String(text[byte=1:length])
        out += _exponent(point - 1)
    return out^


def _exponent(value: Int) -> String:
    """The exponent part, as `e+16` or `e-7`."""
    if value >= 0:
        return String("e+", value)
    return String("e", value)
