# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Encode an introspection result as SDL, as `rover graph introspect` does.

Port of `Schema::encode` of Rover `crates/rover-client/src/operations/
graph/introspect/schema.rs`. It reads the `__schema` of the response, not
a built schema, and keeps the upstream rules:

- the schema definition is printed when there is a mutation or a
  subscription root, or when the query root is not `Query`;
- the introspection types and the five specified scalars are left out,
  and so are `@skip`, `@include` and `@deprecated`;
- an object, interface or input object without its field list is left
  out;
- a default value is printed as the server wrote it;
- `@deprecated` is printed with its reason, when the server gives one;
- a directive is never printed `repeatable`, and `@specifiedBy` is not
  printed, because the upstream query does not ask for them;
- the definitions are grouped by kind: schema, scalars, objects,
  interfaces, unions, enums, input objects, then directives.
"""

from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_seamstress.serialize import Serializer

comptime _SKIPPED_TYPES: List[String] = [
    "__Schema",
    "__Type",
    "__TypeKind",
    "__Field",
    "__InputValue",
    "__EnumValue",
    "__DirectiveLocation",
    "__Directive",
    "Boolean",
    "Float",
    "String",
    "Int",
    "ID",
]
"""The upstream `GRAPHQL_NAMED_TYPES`."""


def _text(
    document: JsonDocument, object: Int, key: StringSlice
) -> Optional[String]:
    """Return a string member, or None when it is absent or not a string."""
    var node = document.find(object, key)
    if node == NO_NODE or document.kind(node) != JsonKind.STRING:
        return None
    return document.string_value(node)


def _list(
    document: JsonDocument, object: Int, key: StringSlice
) -> Optional[List[Int]]:
    """Return the items of an array member, or None when it is not an
    array."""
    var node = document.find(object, key)
    if node == NO_NODE or document.kind(node) != JsonKind.ARRAY:
        return None
    return document.children(node)


def _flag(document: JsonDocument, object: Int, key: StringSlice) -> Bool:
    """Return a boolean member, or False."""
    var node = document.find(object, key)
    return (
        node != NO_NODE
        and document.kind(node) == JsonKind.BOOLEAN
        and document.bool_value(node)
    )


def type_reference(document: JsonDocument, type_ref: Int) raises -> String:
    """Write a type reference such as `[String!]!`, as upstream
    `encode_type`.

    Args:
        document: The introspection result.
        type_ref: The `__Type` object of the reference.

    Returns:
        The type in SDL.

    Raises:
        Error: For a reference with no kind, an unknown kind, or a list or
            non-null with no `ofType`.
    """
    var kind = _text(document, type_ref, "kind")
    if not kind:
        raise Error("Unknown type kind: null")
    var name = kind.value()
    if name == "NON_NULL" or name == "LIST":
        var inner = document.find(type_ref, "ofType")
        if inner == NO_NODE or document.kind(inner) != JsonKind.OBJECT:
            raise Error("a " + name + " type has no ofType")
        var text = type_reference(document, inner)
        if name == "LIST":
            return "[" + text + "]"
        return text if text.endswith("!") else text + "!"
    var known: List[String] = [
        "SCALAR",
        "OBJECT",
        "INTERFACE",
        "UNION",
        "ENUM",
        "INPUT_OBJECT",
    ]
    if not name in known:
        raise Error("Unknown type kind: " + name)
    var type_name = _text(document, type_ref, "name")
    if not type_name:
        raise Error("a named type has no name")
    return type_name.take()


def _deprecated(mut out: Serializer, document: JsonDocument, node: Int):
    """Write `@deprecated`, as upstream `deprecation_directives`."""
    if not _flag(document, node, "isDeprecated"):
        return
    out.write(" @deprecated")
    var reason = _text(document, node, "deprecationReason")
    if reason:
        out.newlines = False
        out.write("(reason: ")
        out.string_value(reason.value(), False)
        out.write(")")
        out.newlines = True


def _input_value(mut out: Serializer, document: JsonDocument, node: Int) raises:
    """Write an argument or an input field, as upstream `encode_arg`."""
    out.description(_text(document, node, "description"))
    out.write(_text(document, node, "name").or_else(""))
    out.write(": ")
    out.write(type_reference(document, document.find(node, "type")))
    var default = _text(document, node, "defaultValue")
    if default and default.value() != "":
        out.write(" = ")
        out.write(default.value())
    _deprecated(out, document, node)


def _arguments(mut out: Serializer, document: JsonDocument, node: Int) raises:
    """Write an argument list, as `serialize_arguments_definition`."""
    var args = _list(document, node, "args").or_else(List[Int]())
    if len(args) == 0:
        return
    var multi_line = False
    var next = 0
    while next < len(args):
        var arg = args[next]
        next += 1
        if _text(document, arg, "description") or _flag(
            document, arg, "isDeprecated"
        ):
            multi_line = True
    var saved = out.newlines
    out.newlines = saved and multi_line
    out.write("(")
    out.indent(False)
    var index = 0
    while index < len(args):
        if index > 0:
            out.write(",")
            out.new_line_or_space()
        _input_value(out, document, args[index])
        index += 1
    if out.newlines:
        out.write(",")
    out.dedent(False)
    out.write(")")
    out.newlines = saved


def _block[
    member: def(mut Serializer, JsonDocument, Int) raises thin -> None
](mut out: Serializer, document: JsonDocument, items: List[Int]) raises:
    """Write `{ ... }` with one member a line, as
    `curly_brackets_space_separated`."""
    if len(items) == 0:
        return
    out.write(" {")
    out.indent(True)
    var index = 0
    while index < len(items):
        if index > 0:
            out.new_line_or_space()
        member(out, document, items[index])
        index += 1
    out.dedent(True)
    out.write("}")


def _field(mut out: Serializer, document: JsonDocument, node: Int) raises:
    """Write a field definition, as upstream `encode_field`."""
    out.description(_text(document, node, "description"))
    out.write(_text(document, node, "name").or_else(""))
    _arguments(out, document, node)
    out.write(": ")
    out.write(type_reference(document, document.find(node, "type")))
    _deprecated(out, document, node)


def _enum_value(mut out: Serializer, document: JsonDocument, node: Int) raises:
    """Write an enum value definition."""
    out.description(_text(document, node, "description"))
    out.write(_text(document, node, "name").or_else(""))
    _deprecated(out, document, node)


def _names(
    document: JsonDocument, type_node: Int, key: StringSlice
) -> List[String]:
    """Return the names of the type references of a list member."""
    var out = List[String]()
    for item in _list(document, type_node, key).or_else(List[Int]()):
        out.append(_text(document, item, "name").or_else(""))
    return out^


def _full_type(document: JsonDocument, node: Int) raises -> Tuple[Int, String]:
    """Encode one type, as upstream `encode_full_type`.

    Returns:
        The sort key of the definition and its text, or -1 for a type that
        is left out.
    """
    var kind = _text(document, node, "kind").or_else("")
    var name = _text(document, node, "name").or_else("")
    var out = Serializer()
    out.description(_text(document, node, "description"))
    if kind == "OBJECT" or kind == "INTERFACE":
        var fields = _list(document, node, "fields")
        if not fields:
            return (-1, String(""))
        out.write("type " if kind == "OBJECT" else "interface ")
        out.write(name)
        var interfaces = _names(document, node, "interfaces")
        if len(interfaces) > 0:
            out.write(" implements " + String(" & ").join(interfaces))
        _block[_field](out, document, fields.value())
        return (2 if kind == "OBJECT" else 3, out^.take())
    if kind == "INPUT_OBJECT":
        var fields = _list(document, node, "inputFields")
        if not fields:
            return (-1, String(""))
        out.write("input " + name)
        _block[_input_value](out, document, fields.value())
        return (6, out^.take())
    if kind == "SCALAR":
        out.write("scalar " + name)
        return (1, out^.take())
    if kind == "UNION":
        out.write("union " + name)
        var members = _names(document, node, "possibleTypes")
        if len(members) > 0:
            out.write(" = " + String(" | ").join(members))
        return (4, out^.take())
    if kind == "ENUM":
        out.write("enum " + name)
        _block[_enum_value](
            out,
            document,
            _list(document, node, "enumValues").or_else(List[Int]()),
        )
        return (5, out^.take())
    return (-1, String(""))


comptime _LOCATIONS: List[String] = [
    "QUERY",
    "MUTATION",
    "SUBSCRIPTION",
    "FIELD",
    "FRAGMENT_DEFINITION",
    "FRAGMENT_SPREAD",
    "INLINE_FRAGMENT",
    "SCHEMA",
    "SCALAR",
    "OBJECT",
    "FIELD_DEFINITION",
    "ARGUMENT_DEFINITION",
    "INTERFACE",
    "UNION",
    "ENUM",
    "ENUM_VALUE",
    "INPUT_OBJECT",
    "INPUT_FIELD_DEFINITION",
]
"""The locations that upstream `directive_location_from_query` keeps."""


def _directive(document: JsonDocument, node: Int) raises -> String:
    """Encode a directive definition, as upstream `encode_directive`."""
    var out = Serializer()
    out.description(_text(document, node, "description"))
    out.write("directive @" + _text(document, node, "name").or_else(""))
    _arguments(out, document, node)
    var locations = List[String]()
    for item in _list(document, node, "locations").or_else(List[Int]()):
        if document.kind(item) != JsonKind.STRING:
            continue
        var location = document.string_value(item)
        if location in materialize[_LOCATIONS]():
            locations.append(location)
    if len(locations) > 0:
        out.write(" on " + String(" | ").join(locations))
    return out^.take()


def _root(
    document: JsonDocument, schema: Int, key: StringSlice
) -> Optional[String]:
    """Return the name of a root type, or None when the root is null.

    A root with no name is the empty name, as upstream `unwrap_or_default`.
    """
    var node = document.find(schema, key)
    if node == NO_NODE or document.kind(node) != JsonKind.OBJECT:
        return None
    return _text(document, node, "name").or_else("")


def encode_schema(document: JsonDocument, data: Int) raises -> String:
    """Encode the `data` of an introspection response as SDL, as upstream
    `Schema::try_from` and `Schema::encode`.

    Args:
        document: The JSON response.
        data: The `data` object.

    Returns:
        The SDL, ended by a line break, or empty for a schema with no
        definitions.

    Raises:
        Error: `Schema not found in Introspection Result.` when `__schema`
            is missing or null, or the error of a type reference.
    """
    var schema = document.find(data, "__schema")
    if schema == NO_NODE or document.kind(schema) != JsonKind.OBJECT:
        raise Error("Schema not found in Introspection Result.")
    var definitions = List[Tuple[Int, String]]()
    var query_node = document.find(schema, "queryType")
    var query = Optional[String](None)
    if query_node != NO_NODE and document.kind(query_node) == JsonKind.OBJECT:
        query = _text(document, query_node, "name")
    var mutation = _root(document, schema, "mutationType")
    var subscription = _root(document, schema, "subscriptionType")
    if mutation or subscription:
        var operations = List[String]()
        if query:
            operations.append("query: " + query.value())
        if mutation:
            operations.append("mutation: " + mutation.value())
        if subscription:
            operations.append("subscription: " + subscription.value())
        definitions.append(
            (0, "schema {\n  " + String("\n  ").join(operations) + "\n}")
        )
    elif query and query.value() != "Query":
        definitions.append((0, "schema {\n  query: " + query.value() + "\n}"))
    var skipped = materialize[_SKIPPED_TYPES]()
    for node in _list(document, schema, "types").or_else(List[Int]()):
        var name = _text(document, node, "name")
        if not name or name.value() in skipped:
            continue
        var encoded = _full_type(document, node)
        if encoded[0] >= 0:
            definitions.append(encoded^)
    for node in _list(document, schema, "directives").or_else(List[Int]()):
        var name = _text(document, node, "name").or_else("")
        if name == "skip" or name == "include" or name == "deprecated":
            continue
        definitions.append((7, _directive(document, node)))
    var texts = List[String]()
    # The eight definition kinds.
    var key = 0
    while key < 8:
        for ref definition in definitions:
            if definition[0] == key:
                texts.append(definition[1])
        key += 1
    if len(texts) == 0:
        return String("")
    return String("\n\n").join(texts) + "\n"
