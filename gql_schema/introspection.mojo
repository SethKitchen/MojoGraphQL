# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The introspection types, the introspection query, and the introspection
result of a schema.

Port of graphql-js 16.14.2 `type/introspection.ts`,
`utilities/getIntrospectionQuery.ts` and
`utilities/introspectionFromSchema.ts`. `get_introspection_query` gives
the same text as graphql-js for every option, and
`introspection_from_schema` gives the same data directly from the arenas
of `Schema`.

**Differences from upstream.**

- `introspection_from_schema` returns a `JsonDocument`, not a JavaScript
  object, and it raises an `Error` where graphql-js fails an invariant.
"""

from gql_json.value import JsonDocument
from gql_language.ast import NO_NODE, Role
from gql_schema.builtins import INTROSPECTION_TYPE_NAMES
from gql_schema.definition import (
    NO_TYPE,
    AstRef,
    Range,
    Schema,
    TypeKind,
    TypeRef,
)
from gql_schema.validate import assert_valid_schema
from gql_schema.values import print_default

comptime SCHEMA_META_FIELD_NAME = "__schema"
"""The name of graphql-js `SchemaMetaFieldDef`."""
comptime TYPE_META_FIELD_NAME = "__type"
"""The name of graphql-js `TypeMetaFieldDef`."""
comptime TYPE_NAME_META_FIELD_NAME = "__typename"
"""The name of graphql-js `TypeNameMetaFieldDef`."""


def is_introspection_type(name: StringSlice) -> Bool:
    """Return True if a type name is one of the eight introspection types,
    as graphql-js `isIntrospectionType`.

    Args:
        name: The type name.

    Returns:
        Whether the name is in `INTROSPECTION_TYPE_NAMES`.
    """
    var names = materialize[INTROSPECTION_TYPE_NAMES]()
    var index = 0
    while index < len(names):
        if names[index] == name:
            return True
        index += 1
    return False


@fieldwise_init
struct IntrospectionOptions(Copyable, ImplicitlyCopyable, Movable):
    """The options of graphql-js `IntrospectionOptions`."""

    var descriptions: Bool
    """Ask for descriptions."""
    var specified_by_url: Bool
    """Ask for `specifiedByURL` on scalars."""
    var directive_is_repeatable: Bool
    """Ask for `isRepeatable` on directives."""
    var schema_description: Bool
    """Ask for the schema's description."""
    var input_value_deprecation: Bool
    """Ask for deprecated arguments and input fields."""
    var experimental_directive_deprecation: Bool
    """Ask for deprecated directives."""
    var one_of: Bool
    """Ask for `isOneOf` on input object types."""
    var type_depth: Int
    """How many `ofType` levels `TypeRef` asks for."""

    def __init__(out self):
        """Make the graphql-js defaults: descriptions, and a type depth of
        9."""
        self.descriptions = True
        self.specified_by_url = False
        self.directive_is_repeatable = False
        self.schema_description = False
        self.input_value_deprecation = False
        self.experimental_directive_deprecation = False
        self.one_of = False
        self.type_depth = 9

    @staticmethod
    def all() -> IntrospectionOptions:
        """Return the defaults of graphql-js `introspectionFromSchema`:
        every option on, and a type depth of 9.

        Returns:
            The options.
        """
        return IntrospectionOptions(True, True, True, True, True, True, True, 9)


def _check_type_depth(type_depth: Int) raises:
    """Raise when `type_depth` is above 100."""
    if type_depth > 100:
        raise Error(
            "Please set typeDepth to a reasonable value between 0 and 100;"
            " the default is 9."
        )


def _of_type(level: Int, indent: String) -> String:
    """Return graphql-js `ofType(level, indent)`."""
    if level <= 0:
        return String("")
    return (
        "\n"
        + indent
        + "ofType {\n"
        + indent
        + "  name\n"
        + indent
        + "  kind"
        + _of_type_inner(level - 1, indent + "  ")
        + "\n"
        + indent
        + "}"
    )


def _of_type_inner(level: Int, indent: String) -> String:
    """Return the next `ofType` level; mutual recursion with `_of_type`."""
    return _of_type(level, indent)


def get_introspection_query(
    options: IntrospectionOptions = IntrospectionOptions(),
) raises -> String:
    """Return the introspection query, as graphql-js
    `getIntrospectionQuery`.

    Args:
        options: What to ask for.

    Returns:
        The query text, character for character as graphql-js writes it.

    Raises:
        Error: `Please set typeDepth to a reasonable value between 0 and
            100; the default is 9.` for a `type_depth` above 100.
    """
    _check_type_depth(options.type_depth)
    var descriptions = "description" if options.descriptions else ""
    var specified_by_url = "specifiedByURL" if options.specified_by_url else ""
    var directive_is_repeatable = (
        "isRepeatable" if options.directive_is_repeatable else ""
    )
    var schema_description = descriptions if options.schema_description else ""
    var input = options.input_value_deprecation
    var directive = options.experimental_directive_deprecation
    var one_of = "isOneOf" if options.one_of else ""
    var include = "(includeDeprecated: true)"
    var out = String("\n    query IntrospectionQuery {\n      __schema {\n")
    out += "        " + schema_description + "\n"
    out += "        queryType { name kind }\n"
    out += "        mutationType { name kind }\n"
    out += "        subscriptionType { name kind }\n"
    out += "        types {\n          ...FullType\n        }\n"
    out += "        directives" + (include if directive else "") + " {\n"
    out += "          name\n"
    out += "          " + descriptions + "\n"
    out += "          " + directive_is_repeatable + "\n"
    out += "          " + ("isDeprecated" if directive else "") + "\n"
    out += "          " + ("deprecationReason" if directive else "") + "\n"
    out += "          locations\n"
    out += "          args" + (include if input else "") + " {\n"
    out += "            ...InputValue\n          }\n        }\n      }\n    }\n"
    out += "\n    fragment FullType on __Type {\n      kind\n      name\n"
    out += "      " + descriptions + "\n"
    out += "      " + specified_by_url + "\n"
    out += "      " + one_of + "\n"
    out += "      fields(includeDeprecated: true) {\n        name\n"
    out += "        " + descriptions + "\n"
    out += "        args" + (include if input else "") + " {\n"
    out += "          ...InputValue\n        }\n"
    out += "        type {\n          ...TypeRef\n        }\n"
    out += "        isDeprecated\n        deprecationReason\n      }\n"
    out += "      inputFields" + (include if input else "") + " {\n"
    out += "        ...InputValue\n      }\n"
    out += "      interfaces {\n        ...TypeRef\n      }\n"
    out += "      enumValues(includeDeprecated: true) {\n        name\n"
    out += "        " + descriptions + "\n"
    out += "        isDeprecated\n        deprecationReason\n      }\n"
    out += "      possibleTypes {\n        ...TypeRef\n      }\n    }\n"
    out += "\n    fragment InputValue on __InputValue {\n      name\n"
    out += "      " + descriptions + "\n"
    out += "      type { ...TypeRef }\n      defaultValue\n"
    out += "      " + ("isDeprecated" if input else "") + "\n"
    out += "      " + ("deprecationReason" if input else "") + "\n    }\n"
    out += "\n    fragment TypeRef on __Type {\n      kind\n      name"
    out += _of_type(options.type_depth, "      ")
    out += "\n    }\n  "
    return out^


def _add_description(mut doc: JsonDocument, schema: Schema, at: AstRef) -> Int:
    """Return a decoded description node, or `null`."""
    if not at.exists():
        return doc.add_null()
    return doc.add_string(schema.description_text(at))


def _add_text_or_null(
    mut doc: JsonDocument, present: Bool, text: StringSlice
) -> Int:
    """Return a string node when `present` is True, or `null`."""
    if present:
        return doc.add_string(text)
    return doc.add_null()


def _add_root_type(mut doc: JsonDocument, schema: Schema, type: Int) -> Int:
    """Return `{ name, kind }` for a root type, or `null`."""
    if type == NO_TYPE:
        return doc.add_null()
    ref named = schema.types[type]
    var obj = doc.add_object()
    doc.add_member(obj, "name", doc.add_string(named.name))
    doc.add_member(obj, "kind", doc.add_string(named.kind.text()))
    return obj


def _add_type_ref(
    mut doc: JsonDocument,
    schema: Schema,
    type: TypeRef,
    depth: Int,
    root: Bool,
) -> Int:
    """Write a `TypeRef` or nested `ofType` object into `doc`."""
    var wrapped = type.is_wrapped()
    ref named = schema.types[Int(type.named)]
    var kind_str: StaticString
    if not wrapped:
        kind_str = named.kind.text()
    elif type.is_non_null():
        kind_str = "NON_NULL"
    else:
        kind_str = "LIST"
    var name_node = doc.add_null() if wrapped else doc.add_string(named.name)
    var kind_node = doc.add_string(kind_str)
    var obj = doc.add_object()
    if root:
        doc.add_member(obj, "kind", kind_node)
        doc.add_member(obj, "name", name_node)
    else:
        doc.add_member(obj, "name", name_node)
        doc.add_member(obj, "kind", kind_node)
    if depth > 0:
        var of_node: Int
        if not wrapped:
            of_node = doc.add_null()
        else:
            of_node = _add_of_type(doc, schema, type.of_type(), depth - 1)
        doc.add_member(obj, "ofType", of_node)
    return obj


def _add_of_type(
    mut doc: JsonDocument, schema: Schema, type: TypeRef, depth: Int
) -> Int:
    """Write a nested `ofType` object; mutual recursion with `_add_type_ref`."""
    return _add_type_ref(doc, schema, type, depth, False)


def _add_input_value(
    mut doc: JsonDocument,
    schema: Schema,
    index: Int,
    options: IntrospectionOptions,
) raises -> Int:
    """Write an `InputValue` fragment object into `doc`."""
    ref definition = schema.input_values[index]
    var obj = doc.add_object()
    doc.add_member(obj, "name", doc.add_string(definition.name))
    if options.descriptions:
        doc.add_member(
            obj,
            "description",
            _add_description(doc, schema, definition.description),
        )
    doc.add_member(
        obj,
        "type",
        _add_type_ref(doc, schema, definition.type, options.type_depth, True),
    )
    var printed: Optional[String]
    try:
        printed = print_default(schema, index)
    except:
        raise Error("Unexpected error: the introspection query failed.")
    if printed:
        doc.add_member(obj, "defaultValue", doc.add_string(printed.value()))
    else:
        doc.add_member(obj, "defaultValue", doc.add_null())
    if options.input_value_deprecation:
        doc.add_member(
            obj, "isDeprecated", doc.add_bool(definition.is_deprecated)
        )
        doc.add_member(
            obj,
            "deprecationReason",
            _add_text_or_null(
                doc, definition.is_deprecated, definition.deprecation_reason
            ),
        )
    return obj


def _add_input_values(
    mut doc: JsonDocument,
    schema: Schema,
    span: Range,
    options: IntrospectionOptions,
) raises -> Int:
    """Write a list of `InputValue` objects into `doc`."""
    var list = doc.add_array()
    var index = Int(span.start)
    while index < span.end():
        var keep = True
        if not options.input_value_deprecation:
            keep = not schema.input_values[index].is_deprecated
        if keep:
            var item = _add_input_value(doc, schema, index, options)
            doc.append(list, item)
        index += 1
    return list


def _add_full_type(
    mut doc: JsonDocument,
    schema: Schema,
    type: Int,
    options: IntrospectionOptions,
) raises -> Int:
    """Write a `FullType` fragment object into `doc`."""
    ref named = schema.types[type]
    var obj = doc.add_object()
    doc.add_member(obj, "kind", doc.add_string(named.kind.text()))
    doc.add_member(obj, "name", doc.add_string(named.name))
    if options.descriptions:
        doc.add_member(
            obj, "description", _add_description(doc, schema, named.description)
        )
    if options.specified_by_url:
        doc.add_member(
            obj,
            "specifiedByURL",
            _add_text_or_null(
                doc, named.has_specified_by_url, named.specified_by_url
            ),
        )
    if options.one_of:
        if named.kind == TypeKind.INPUT_OBJECT:
            doc.add_member(obj, "isOneOf", doc.add_bool(named.is_one_of))
        else:
            doc.add_member(obj, "isOneOf", doc.add_null())
    if not named.kind.has_fields():
        doc.add_member(obj, "fields", doc.add_null())
    else:
        var fields = doc.add_array()
        var index = Int(named.fields.start)
        while index < named.fields.end():
            ref field = schema.fields[index]
            var item = doc.add_object()
            doc.add_member(item, "name", doc.add_string(field.name))
            if options.descriptions:
                doc.add_member(
                    item,
                    "description",
                    _add_description(doc, schema, field.description),
                )
            var args = _add_input_values(doc, schema, field.arguments, options)
            doc.add_member(item, "args", args)
            doc.add_member(
                item,
                "type",
                _add_type_ref(
                    doc, schema, field.type, options.type_depth, True
                ),
            )
            doc.add_member(
                item, "isDeprecated", doc.add_bool(field.is_deprecated)
            )
            doc.add_member(
                item,
                "deprecationReason",
                _add_text_or_null(
                    doc, field.is_deprecated, field.deprecation_reason
                ),
            )
            doc.append(fields, item)
            index += 1
        doc.add_member(obj, "fields", fields)
    if named.kind != TypeKind.INPUT_OBJECT:
        doc.add_member(obj, "inputFields", doc.add_null())
    else:
        var input_fields = _add_input_values(
            doc, schema, named.input_fields, options
        )
        doc.add_member(obj, "inputFields", input_fields)
    if not named.kind.has_fields():
        doc.add_member(obj, "interfaces", doc.add_null())
    else:
        var ifaces = schema.interfaces_of(type)
        var list = doc.add_array()
        var index = 0
        while index < len(ifaces):
            var item = _add_type_ref(
                doc, schema, TypeRef.of(ifaces[index]), options.type_depth, True
            )
            doc.append(list, item)
            index += 1
        doc.add_member(obj, "interfaces", list)
    if named.kind != TypeKind.ENUM:
        doc.add_member(obj, "enumValues", doc.add_null())
    else:
        var list = doc.add_array()
        var index = Int(named.enum_values.start)
        while index < named.enum_values.end():
            ref ev = schema.enum_values[index]
            var item = doc.add_object()
            doc.add_member(item, "name", doc.add_string(ev.name))
            if options.descriptions:
                doc.add_member(
                    item,
                    "description",
                    _add_description(doc, schema, ev.description),
                )
            doc.add_member(item, "isDeprecated", doc.add_bool(ev.is_deprecated))
            doc.add_member(
                item,
                "deprecationReason",
                _add_text_or_null(doc, ev.is_deprecated, ev.deprecation_reason),
            )
            doc.append(list, item)
            index += 1
        doc.add_member(obj, "enumValues", list)
    if not named.kind.is_abstract():
        doc.add_member(obj, "possibleTypes", doc.add_null())
    else:
        var possibles = schema.possible_types(type)
        var list = doc.add_array()
        var index = 0
        while index < len(possibles):
            var item = _add_type_ref(
                doc,
                schema,
                TypeRef.of(possibles[index]),
                options.type_depth,
                True,
            )
            doc.append(list, item)
            index += 1
        doc.add_member(obj, "possibleTypes", list)
    return obj


def _add_directive(
    mut doc: JsonDocument,
    schema: Schema,
    index: Int,
    options: IntrospectionOptions,
) raises -> Int:
    """Write a directive object of `__schema.directives` into `doc`."""
    ref definition = schema.directives[index]
    var obj = doc.add_object()
    doc.add_member(obj, "name", doc.add_string(definition.name))
    if options.descriptions:
        doc.add_member(
            obj,
            "description",
            _add_description(doc, schema, definition.description),
        )
    if options.directive_is_repeatable:
        doc.add_member(
            obj, "isRepeatable", doc.add_bool(definition.is_repeatable)
        )
    if options.experimental_directive_deprecation:
        doc.add_member(
            obj, "isDeprecated", doc.add_bool(definition.is_deprecated)
        )
        doc.add_member(
            obj,
            "deprecationReason",
            _add_text_or_null(
                doc, definition.is_deprecated, definition.deprecation_reason
            ),
        )
    var locations = doc.add_array()
    var at = definition.definition
    ref document = schema.documents[Int(at.document)]
    var location = document.child(Int(at.node), Role.LOCATION)
    while location != NO_NODE:
        var text = doc.add_string(document.text(location))
        doc.append(locations, text)
        location = document.next_with_role(location)
    doc.add_member(obj, "locations", locations)
    var args = _add_input_values(doc, schema, definition.arguments, options)
    doc.add_member(obj, "args", args)
    return obj


def introspection_from_schema(
    schema: Schema,
    options: IntrospectionOptions = IntrospectionOptions.all(),
    assume_valid: Bool = False,
) raises -> JsonDocument:
    """Return the introspection result of a schema, as graphql-js
    `introspectionFromSchema`.

    Args:
        schema: The schema; it must be valid.
        options: What to ask for. The default has every option on, as the
            graphql-js defaults of this function are. Start from
            `IntrospectionOptions.all()` to turn one option off.
        assume_valid: Skip `assertValidSchema`, for a schema that is known
            to be valid, or that graphql-js built with `assumeValid`.

    Returns:
        The `data` of the introspection query: its root is the object
        with `__schema`.

    Raises:
        Error: The `assertValidSchema` error for an invalid schema,
            `Please set typeDepth to a reasonable value between 0 and 100;
            the default is 9.` for a `type_depth` above 100, or
            `Unexpected error: the introspection query failed.` when the
            result has errors, as the graphql-js invariant fails.
    """
    _check_type_depth(options.type_depth)
    if not assume_valid:
        assert_valid_schema(schema)
    if schema.query_type == NO_TYPE:
        raise Error("Unexpected error: the introspection query failed.")
    var doc = JsonDocument()
    var root = doc.add_object()
    doc.root = root
    var schema_obj = doc.add_object()
    if options.descriptions:
        if options.schema_description:
            doc.add_member(
                schema_obj,
                "description",
                _add_description(doc, schema, schema.description),
            )
    doc.add_member(
        schema_obj,
        "queryType",
        _add_root_type(doc, schema, Int(schema.query_type)),
    )
    doc.add_member(
        schema_obj,
        "mutationType",
        _add_root_type(doc, schema, Int(schema.mutation_type)),
    )
    doc.add_member(
        schema_obj,
        "subscriptionType",
        _add_root_type(doc, schema, Int(schema.subscription_type)),
    )
    var types = doc.add_array()
    var index = 0
    while index < len(schema.type_map):
        var item = _add_full_type(
            doc, schema, Int(schema.type_map[index]), options
        )
        doc.append(types, item)
        index += 1
    doc.add_member(schema_obj, "types", types)
    var directives = doc.add_array()
    index = 0
    while index < len(schema.directives):
        var keep = True
        if not options.experimental_directive_deprecation:
            keep = not schema.directives[index].is_deprecated
        if keep:
            var item = _add_directive(doc, schema, index, options)
            doc.append(directives, item)
        index += 1
    doc.add_member(schema_obj, "directives", directives)
    doc.add_member(root, "__schema", schema_obj)
    return doc^
