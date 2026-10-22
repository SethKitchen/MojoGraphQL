# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Build a client schema from the result of an introspection query.

Port of graphql-js 16.14.2 `utilities/buildClientSchema.ts`, with its
checks and its error messages.

A `gql_schema.Schema` is built from SDL, so `build_client_schema` writes
the SDL of the introspection result and builds the schema from it, with no
SDL validation, as graphql-js builds a client schema with no validation.
The specified scalars and the introspection types are the built-in ones,
as graphql-js replaces them with its own. The checks run in the order of
graphql-js: each type, the root types, the directives, then the fields,
interfaces and members of each type.

**Differences from upstream.**

- graphql-js keeps only the directives of the introspection result. A
  `gql_schema` schema always has the specified directives, so a result
  without `@skip` still gives a schema with `@skip`.
- A directive with no locations cannot be written in SDL, so it raises
  `A directive must have at least one location: @name.`. graphql-js
  builds it.
- The type map has the order that `buildASTSchema` gives the SDL: the
  types in the order of the result, and each specified scalar where a
  field first uses it. graphql-js keeps the order of the result. A result
  from `introspectionFromSchema` has the same order in both.
- When a result has several problems, graphql-js can report another one
  first, because it reads some of them lazily.
- A result with no `types` list raises `list is not iterable`, the
  JavaScript `TypeError` that graphql-js throws there.
- A type name is read as JavaScript reads an object key from a string, a
  number or a boolean. An array or an object as a name gives `Unknown type
  reference`.
- A schema description is kept only with a root type: SDL writes it on
  the `schema` definition.
"""

from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_language.ast import Document, Kind
from gql_language.parser import parse, parse_value
from gql_schema.build import BuildOptions, build_ast_schema
from gql_schema.builtins import SPECIFIED_SCALAR_NAMES
from gql_schema.definition import Schema, TypeKind
from gql_language.names import NOT_FOUND, NameTable
from gql_schema.values import JsValues, inspect, js_number_to_string

comptime _INVALID = (
    "Invalid or incomplete introspection result. Ensure that a full"
    " introspection query is used in order to build a client schema: "
)
comptime _KINDS = "SCALAR OBJECT INTERFACE UNION ENUM INPUT_OBJECT"
comptime _INTROSPECTION_KINDS = (
    "__Schema:1 __Directive:1 __DirectiveLocation:4 __Type:1 __Field:1"
    " __InputValue:1 __EnumValue:1 __TypeKind:4"
)


def _show(document: JsonDocument, node: Int) -> String:
    """Return a JSON value as graphql-js `inspect` writes it."""
    var values = JsValues()
    return inspect(values, values.add_json(document, node))


def _find(document: JsonDocument, object: Int, key: StringSlice) -> Int:
    """Return a member of an object; `NO_NODE` for a missing member or a
    value that is not an object."""
    if document.kind(object) != JsonKind.OBJECT:
        return NO_NODE
    return document.find(object, key)


def _is_set(document: JsonDocument, node: Int) -> Bool:
    """Return True for a member that is there and is not `null`."""
    return node != NO_NODE and document.kind(node) != JsonKind.NULL


def _text(document: JsonDocument, object: Int, key: StringSlice) -> String:
    """Return a string member, or empty for none."""
    var node = _find(document, object, key)
    if node == NO_NODE or document.kind(node) != JsonKind.STRING:
        return String("")
    return document.string_value(node)


def _key(document: JsonDocument, node: Int) -> String:
    """Return a number or a boolean as JavaScript `String(value)` gives an
    object key; empty for a missing member, `null`, `false`, `0`, an array
    or an object."""
    if node == NO_NODE:
        return String("")
    var kind = document.kind(node)
    if kind == JsonKind.BOOLEAN and document.bool_value(node):
        return String("true")
    if kind == JsonKind.NUMBER and document.as_float64(node) != 0:
        return js_number_to_string(document.as_float64(node))
    return String("")


def _has_text(document: JsonDocument, object: Int, key: StringSlice) -> Bool:
    """Return True for a string member, empty or not."""
    var node = _find(document, object, key)
    return node != NO_NODE and document.kind(node) == JsonKind.STRING


def _flag(document: JsonDocument, object: Int, key: StringSlice) -> Bool:
    """Return True for a member that is `true`."""
    var node = _find(document, object, key)
    return (
        node != NO_NODE
        and document.kind(node) == JsonKind.BOOLEAN
        and document.bool_value(node)
    )


def _equals(document: JsonDocument, node: Int, text: StringSlice) -> Bool:
    """Return True for a string value with a text."""
    return (
        node != NO_NODE
        and document.kind(node) == JsonKind.STRING
        and document.text(node) == text
    )


def _unknown(name: String) -> Error:
    """Return the error of graphql-js `getNamedType` for an unknown name."""
    return Error(
        "Invalid or incomplete schema, unknown type: "
        + name
        + ". Ensure that a full introspection query is used in order to"
        " build a client schema."
    )


def _kind_code(name: StringSlice) -> Int:
    """Return the `TypeKind` value of a `__TypeKind` name, or -1."""
    var words = StringSlice(_KINDS).split(" ")
    var position = 0
    while position < len(words):
        if words[position] == name:
            return position
        position += 1
    return -1


@fieldwise_init
struct _Ref(ImplicitlyCopyable):
    """The kind of the named type of a type reference, and whether the
    reference is non-null."""

    var kind: Int
    var non_null: Bool


struct _Client[o: Origin[mut=False]](Movable):
    """The state of one `build_client_schema`: the kind of each type, and
    the SDL written so far.

    The SDL copies each name and each string as its JSON text: a JSON
    string escape is also a GraphQL string escape, so the parser of the
    SDL decodes the same value."""

    var document: Pointer[JsonDocument, Self.o]
    var kinds: NameTable
    var out: List[UInt8]

    def __init__(out self, ref[Self.o] document: JsonDocument):
        """Start with no types."""
        self.document = Pointer(to=document)
        self.kinds = NameTable(capacity=document.length(document.root) + 64)
        self.out = List[UInt8](capacity=len(document.bytes))

    @always_inline
    def put(mut self, text: StringSlice):
        """Append text to the SDL."""
        self.out.extend(text.as_bytes())

    def put_member(mut self, object: Int, key: StringSlice):
        """Append the JSON text of a string member."""
        var node = _find(self.document[], object, key)
        self.out.extend(self.document[].text(node).as_bytes())

    def put_quoted(mut self, object: Int, key: StringSlice):
        """Append a string member as a GraphQL string literal."""
        self.out.append(0x22)
        self.put_member(object, key)
        self.out.append(0x22)

    def put_description(mut self, object: Int):
        """Append the description of an element and a space, if it has one."""
        if _has_text(self.document[], object, "description"):
            self.put_quoted(object, "description")
            self.out.append(0x20)

    def put_deprecated(mut self, object: Int):
        """Append `@deprecated(reason: "...")` for an element with a
        `deprecationReason`."""
        if _has_text(self.document[], object, "deprecationReason"):
            self.put(" @deprecated(reason: ")
            self.put_quoted(object, "deprecationReason")
            self.out.append(0x29)

    def since(self, start: Int) -> String:
        """Return the SDL written after a position."""
        return String(unsafe_from_utf8=Span(self.out)[start:])

    def ref_of(mut self, ref_: Int) raises -> _Ref:
        """Append graphql-js `getType` of a type reference, as SDL."""
        ref document = self.document[]
        var kind = _find(document, ref_, "kind")
        var is_list = _equals(document, kind, "LIST")
        if is_list or _equals(document, kind, "NON_NULL"):
            var of = _find(document, ref_, "ofType")
            if not _is_set(document, of):
                raise Error("Decorated type deeper than introspection query.")
            if is_list:
                self.out.append(0x5B)
                var inner = self.inner_of(of)
                self.out.append(0x5D)
                return _Ref(inner.kind, False)
            var start = len(self.out)
            var inner = self.inner_of(of)
            if inner.non_null:
                raise Error(
                    "Expected "
                    + self.since(start)
                    + " to be a GraphQL nullable type."
                )
            self.out.append(0x21)
            return _Ref(inner.kind, True)
        return _Ref(self.named(ref_), False)

    def inner_of(mut self, ref_: Int) raises -> _Ref:
        """Append the type inside a wrapper; mutual recursion with
        `ref_of`."""
        return self.ref_of(ref_)

    def named(mut self, ref_: Int) raises -> Int:
        """Append graphql-js `getNamedType`: the name of a named type.
        Return its kind."""
        ref document = self.document[]
        var node = _find(document, ref_, "name")
        var kind: Int
        if node != NO_NODE and document.kind(node) == JsonKind.STRING:
            var name = document.text(node)
            if name.byte_length() == 0:
                raise Error(
                    "Unknown type reference: " + _show(document, ref_) + "."
                )
            kind = self.kinds.find(-1, name)
            if kind != NOT_FOUND:
                self.put(name)
                return kind
            raise _unknown(String(name))
        var name = _key(document, node)
        if name == "":
            raise Error(
                "Unknown type reference: " + _show(document, ref_) + "."
            )
        raise _unknown(name)

    def named_of_kind(mut self, ref_: Int, kind: Int) raises:
        """Append graphql-js `getObjectType` or `getInterfaceType`."""
        var start = len(self.out)
        if self.named(ref_) != kind:
            var what = (
                "Object" if kind == Int(TypeKind.OBJECT.value) else "Interface"
            )
            raise Error(
                "Expected "
                + self.since(start)
                + " to be a GraphQL "
                + what
                + " type."
            )

    def input_value(mut self, value: Int) raises:
        """Append graphql-js `buildInputValue`, as SDL."""
        ref document = self.document[]
        self.put_description(value)
        self.put_member(value, "name")
        self.put(": ")
        var start = len(self.out)
        var type = self.ref_of(_find(document, value, "type"))
        if not TypeKind(UInt8(type.kind)).is_input():
            raise Error(
                "Introspection must provide input type for arguments, but"
                " received: "
                + self.since(start)
                + "."
            )
        var default = _find(document, value, "defaultValue")
        if _is_set(document, default):
            var literal = document.string_value(default)
            var parsed: Document
            try:
                parsed = parse_value(literal)
            except e:
                raise Error(e.message)
            if not _has_variable(parsed):
                self.put(" = ")
                self.put(literal)
        self.put_deprecated(value)

    def input_values(mut self, list: Int, indent: StringSlice) raises:
        """Append graphql-js `buildInputValueDefMap`, as SDL."""
        var item = self.document[].first(list)
        while item != NO_NODE:
            self.put(indent)
            self.input_value(item)
            item = self.document[].next(item)

    def fields(mut self, type: Int) raises:
        """Append graphql-js `buildFieldDefMap`, as SDL."""
        ref document = self.document[]
        var list = _find(document, type, "fields")
        if not _is_set(document, list):
            raise Error(
                "Introspection result missing fields: "
                + _show(document, type)
                + "."
            )
        var field = document.first(list)
        if field == NO_NODE:
            return
        self.put(" {")
        while field != NO_NODE:
            self.put("\n  ")
            self.put_description(field)
            self.put_member(field, "name")
            # graphql-js checks the type before the arguments, and SDL
            # writes the arguments first: the type text moves after them.
            var type_start = len(self.out)
            self.put(": ")
            var start = len(self.out)
            var field_type = self.ref_of(_find(document, field, "type"))
            if field_type.kind == Int(TypeKind.INPUT_OBJECT.value):
                raise Error(
                    "Introspection must provide output type for fields, but"
                    " received: "
                    + self.since(start)
                    + "."
                )
            var args = _find(document, field, "args")
            if not _is_set(document, args):
                raise Error(
                    "Introspection result missing field args: "
                    + _show(document, field)
                    + "."
                )
            if document.length(args) > 0:
                var type_text = List[UInt8]()
                type_text.extend(Span(self.out)[type_start:])
                self.out.resize(type_start, 0)
                self.put("(")
                self.input_values(args, "\n    ")
                self.put("\n  )")
                self.out.extend(Span(type_text))
            self.put_deprecated(field)
            field = document.next(field)
        self.put("\n}")

    def interfaces(mut self, type: Int) raises:
        """Append graphql-js `buildImplementationsList`, as SDL."""
        ref document = self.document[]
        var list = _find(document, type, "interfaces")
        if (
            list != NO_NODE
            and document.kind(list) == JsonKind.NULL
            and _equals(document, _find(document, type, "kind"), "INTERFACE")
        ):
            return
        if not _is_set(document, list):
            raise Error(
                "Introspection result missing interfaces: "
                + _show(document, type)
                + "."
            )
        var separator = StaticString(" implements ")
        var item = document.first(list)
        while item != NO_NODE:
            self.put(separator)
            separator = " & "
            self.named_of_kind(item, Int(TypeKind.INTERFACE.value))
            item = document.next(item)

    def type_sdl(mut self, type: Int) raises:
        """Append the SDL of a named type, as the lazy parts of graphql-js
        `buildType` check it."""
        ref document = self.document[]
        var kind = _kind_code(_text(document, type, "kind"))
        self.put("\n\n")
        self.put_description(type)
        if kind == Int(TypeKind.SCALAR.value):
            self.put("scalar ")
            self.put_member(type, "name")
            if _has_text(document, type, "specifiedByURL"):
                self.put(" @specifiedBy(url: ")
                self.put_quoted(type, "specifiedByURL")
                self.put(")")
            return
        if kind == Int(TypeKind.UNION.value):
            self.put("union ")
            self.put_member(type, "name")
            var separator = StaticString(" = ")
            var item = document.first(_find(document, type, "possibleTypes"))
            while item != NO_NODE:
                self.put(separator)
                separator = " | "
                self.named_of_kind(item, Int(TypeKind.OBJECT.value))
                item = document.next(item)
            return
        if kind == Int(TypeKind.ENUM.value):
            self.put("enum ")
            self.put_member(type, "name")
            var value = document.first(_find(document, type, "enumValues"))
            if value == NO_NODE:
                return
            self.put(" {")
            while value != NO_NODE:
                self.put("\n  ")
                self.put_description(value)
                self.put_member(value, "name")
                self.put_deprecated(value)
                value = document.next(value)
            self.put("\n}")
            return
        if kind == Int(TypeKind.INPUT_OBJECT.value):
            self.put("input ")
            self.put_member(type, "name")
            if _flag(document, type, "isOneOf"):
                self.put(" @oneOf")
            var list = _find(document, type, "inputFields")
            if document.length(list) > 0:
                self.put(" {")
                self.input_values(list, "\n  ")
                self.put("\n}")
            return
        if kind == Int(TypeKind.OBJECT.value):
            self.put("type ")
        else:
            self.put("interface ")
        self.put_member(type, "name")
        self.interfaces(type)
        self.fields(type)

    def directive_sdl(mut self, directive: Int) raises:
        """Append graphql-js `buildDirective`, as SDL."""
        ref document = self.document[]
        var args = _find(document, directive, "args")
        if not _is_set(document, args):
            raise Error(
                "Introspection result missing directive args: "
                + _show(document, directive)
                + "."
            )
        var locations = _find(document, directive, "locations")
        if not _is_set(document, locations):
            raise Error(
                "Introspection result missing directive locations: "
                + _show(document, directive)
                + "."
            )
        if document.length(locations) == 0:
            raise Error(
                "A directive must have at least one location: @"
                + _text(document, directive, "name")
                + "."
            )
        self.put("\n\n")
        self.put_description(directive)
        self.put("directive @")
        self.put_member(directive, "name")
        if document.length(args) > 0:
            self.put("(")
            self.input_values(args, "\n  ")
            self.put("\n)")
        if _flag(document, directive, "isRepeatable"):
            self.put(" repeatable")
        var separator = StaticString(" on ")
        var location = document.first(locations)
        while location != NO_NODE:
            self.put(separator)
            separator = " | "
            self.out.extend(document.text(location).as_bytes())
            location = document.next(location)

    def schema_sdl(mut self, schema: Int) raises:
        """Append the `schema` definition of the root types, if there is
        one."""
        ref document = self.document[]
        var start = len(self.out)
        self.put_description(schema)
        self.put("schema {")
        var roots = False
        var keys: List[String] = [
            "queryType",
            "mutationType",
            "subscriptionType",
        ]
        var operations: List[String] = ["query", "mutation", "subscription"]
        var index = 0
        while index < 3:
            var root = _find(document, schema, keys[index])
            if _is_set(document, root):
                roots = True
                self.put("\n  " + operations[index] + ": ")
                self.named_of_kind(root, Int(TypeKind.OBJECT.value))
            index += 1
        if not roots:
            self.out.resize(start, 0)
            return
        self.put("\n}")


def _has_variable(document: Document) -> Bool:
    """Return True if a parsed value holds a variable."""
    var index = 0
    while index < len(document.nodes):
        if document.kind(index) == Kind.VARIABLE:
            return True
        index += 1
    return False


def _std_kind(name: StringSlice) -> Int:
    """Return the kind of a specified scalar or an introspection type, or
    -1 for another name."""
    var scalars = materialize[SPECIFIED_SCALAR_NAMES]()
    var index = 0
    while index < len(scalars):
        if scalars[index] == name:
            return Int(TypeKind.SCALAR.value)
        index += 1
    var entries = StringSlice(_INTROSPECTION_KINDS).split(" ")
    index = 0
    while index < len(entries):
        var colon = entries[index].find(":")
        if entries[index][byte=:colon] == name:
            return Int(entries[index].as_bytes()[colon + 1]) - 48
        index += 1
    return -1


def build_client_schema(
    document: JsonDocument, introspection: Int, assume_valid: Bool = False
) raises -> Schema:
    """Build a schema from the result of an introspection query, as
    graphql-js `buildClientSchema`.

    Args:
        document: The JSON document of the result.
        introspection: The `data` value: an object with `__schema`.
        assume_valid: The graphql-js `assumeValid` option; it is kept as
            the `assume_valid` option of the build.

    Returns:
        The schema. It has no resolvers, so it can execute introspection
        and fields that the default resolver reads.

    Raises:
        Error: The graphql-js message for an incomplete result, such as
            `Invalid or incomplete schema, unknown type: Foo. Ensure that
            a full introspection query is used in order to build a client
            schema.`, or a syntax error of a default value.
    """
    var schema = _find(document, introspection, "__schema")
    if document.kind(schema) != JsonKind.OBJECT:
        raise Error(
            "Invalid or incomplete introspection result. Ensure that you are"
            ' passing "data" property of introspection response and no'
            ' "errors" was returned alongside: '
            + _show(document, introspection)
            + "."
        )
    var client = _Client(document)
    var types = _find(document, schema, "types")
    if not _is_set(document, types):
        # graphql-js reads the list with `keyValMap`, which throws this
        # JavaScript TypeError.
        raise Error("list is not iterable")
    var type = document.first(types)
    while type != NO_NODE:
        _check_type(document, type)
        var name = document.text(_find(document, type, "name"))
        var std = _std_kind(name)
        if std < 0:
            std = _kind_code(_text(document, type, "kind"))
        client.kinds.assign(-1, name, std)
        type = document.next(type)
    client.schema_sdl(schema)
    var directives = _find(document, schema, "directives")
    var directive = document.first(directives) if _is_set(
        document, directives
    ) else NO_NODE
    while directive != NO_NODE:
        client.directive_sdl(directive)
        directive = document.next(directive)
    type = document.first(types)
    while type != NO_NODE:
        if _std_kind(document.text(_find(document, type, "name"))) < 0:
            client.type_sdl(type)
        type = document.next(type)
    var options = BuildOptions()
    options.assume_valid_sdl = True
    options.assume_valid = assume_valid
    var documents = List[Document]()
    if len(client.out) == 0:
        documents.append(Document())
    else:
        documents.append(parse(String(unsafe_from_utf8=client.out)))
    var built = build_ast_schema(documents^, options)
    directive = document.first(directives) if _is_set(
        document, directives
    ) else NO_NODE
    while directive != NO_NODE:
        if _has_text(document, directive, "deprecationReason"):
            var index = built.directive_named(
                _text(document, directive, "name")
            )
            built.directives[index].is_deprecated = True
            built.directives[index].deprecation_reason = _text(
                document, directive, "deprecationReason"
            )
        directive = document.next(directive)
    return built^


def _check_type(document: JsonDocument, type: Int) raises:
    """Raise the eager errors of graphql-js `buildType`."""
    var kind = _kind_code(_text(document, type, "kind"))
    if not _has_text(document, type, "name") or kind < 0:
        raise Error(_INVALID + _show(document, type) + ".")
    var list = String("")
    if kind == Int(TypeKind.UNION.value):
        list = "possibleTypes"
    elif kind == Int(TypeKind.ENUM.value):
        list = "enumValues"
    elif kind == Int(TypeKind.INPUT_OBJECT.value):
        list = "inputFields"
    if list != "" and not _is_set(document, _find(document, type, list)):
        raise Error(
            "Introspection result missing "
            + list
            + ": "
            + _show(document, type)
            + "."
        )
