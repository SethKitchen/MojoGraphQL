# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The JSON Schema of the result of an operation.

Port of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/operations/schema_walker/output.rs`.

`selection_set_to_schema` walks a selection set and returns the schema of
the GraphQL response: `data`, `errors` and `extensions`. On an abstract
type, the fields of fragments apply to some members only. The walker
groups the members by the fields that apply to them and writes one
branch of `anyOf` for each group, as upstream does.

The result is in insertion order, as a `schemars::Schema` is. Call
`JsonTree.order_schema` where the upstream calls `serde_json::to_value`.

Differences from upstream:

- `@private` fields (upstream `PrivateFieldTree`) are not ported in phase
  1: every selected field is in the schema.
- The upstream logs a warning for a field or a type that the schema does
  not have. This module logs nothing.
"""

from gql_json.value import NO_NODE
from gql_language.ast import Document, Kind, Role
from gql_mcp.custom_scalar_map import CustomScalarMap
from gql_mcp.json_tree import JsonTree
from gql_mcp.schema_walker import (
    ensure_object,
    nullable,
    ref_schema,
    simple_type,
    with_desc,
)
from gql_schema.definition import NO_TYPE, Schema, TypeKind, TypeRef


@fieldwise_init
struct _Selected(Copyable, Movable):
    """A field and the members on which its enclosing fragments apply."""

    var field: Int
    """The `Field` node."""
    var declared_on: Int
    """The type that the field is selected on."""
    var members: List[Int]
    """The positions of the members, in order."""


struct _Walk(Movable):
    """The state of one walk."""

    var fragments: Dict[String, Int]
    """The fragment definitions by name; the last one of a name wins."""
    var definitions: Int
    """The object of named schemas."""

    def __init__(out self, document: Document, definitions: Int):
        """Collect the fragments of a document."""
        self.fragments = Dict[String, Int]()
        self.definitions = definitions
        var definition = document.first_child(document.root)
        while definition != NO_NODE:
            if document.kind(definition) == Kind.FRAGMENT_DEFINITION:
                self.fragments[String(document.name(definition))] = definition
            definition = document.next_sibling(definition)


def selection_set_to_schema(
    mut tree: JsonTree,
    schema: Schema,
    document: Document,
    selection_set: Int,
    root_type: Int,
    custom_scalars: CustomScalarMap,
) -> Int:
    """Return the JSON Schema of the response to a selection set.

    Args:
        tree: The tree to add the schema to.
        schema: The GraphQL schema.
        document: The document that holds the selection set and the
            fragments.
        selection_set: The `SelectionSet` node of the operation.
        root_type: The root operation type.
        custom_scalars: The schemas of custom scalars; an empty map is the
            upstream `None`.

    Returns:
        The schema of the response, with its `definitions`.
    """
    var definitions = tree.add_object()
    var walk = _Walk(document, definitions)
    var data = _selection_set(
        tree, schema, document, custom_scalars, walk, selection_set, root_type
    )
    var response = simple_type(tree, "object")
    var properties = tree.add_object()
    tree.set(response, "properties", properties)
    tree.set(properties, "data", data)
    tree.set(properties, "errors", _errors(tree))
    tree.set(properties, "extensions", simple_type(tree, "object"))
    if tree.length(definitions) > 0:
        tree.set(response, "definitions", definitions)
    return response


def _errors(mut tree: JsonTree) -> Int:
    """The schema of the `errors` of a response."""
    var location = simple_type(tree, "object")
    var location_properties = tree.add_object()
    tree.set(location, "properties", location_properties)
    tree.set(location_properties, "line", simple_type(tree, "integer"))
    tree.set(location_properties, "column", simple_type(tree, "integer"))
    var locations = simple_type(tree, "array")
    tree.set(locations, "items", location)
    var path = simple_type(tree, "array")
    tree.set(path, "items", _string_or_integer(tree))
    var error = simple_type(tree, "object")
    var properties = tree.add_object()
    tree.set(error, "properties", properties)
    tree.set(properties, "message", simple_type(tree, "string"))
    tree.set(properties, "locations", locations)
    tree.set(properties, "path", path)
    tree.set(properties, "extensions", simple_type(tree, "object"))
    var required = tree.add_array()
    tree.push(required, tree.add_string("message"))
    tree.set(error, "required", required)
    var errors = simple_type(tree, "array")
    tree.set(errors, "items", error)
    return errors


def _string_or_integer(mut tree: JsonTree) -> Int:
    """`{"oneOf": [{"type": "string"}, {"type": "integer"}]}`."""
    var options = tree.add_array()
    tree.push(options, simple_type(tree, "string"))
    tree.push(options, simple_type(tree, "integer"))
    var object = tree.add_object()
    tree.set(object, "oneOf", options)
    return object


def _response_key(document: Document, field: Int) -> String:
    """The alias of a field, or its name."""
    var alias = document.child(field, Role.ALIAS)
    if alias != NO_NODE:
        return String(document.text(alias))
    return String(document.name(field))


def _members(schema: Schema, parent: Int) -> List[Int]:
    """The concrete members of a type: a union's members, an interface's
    implementations, or the type itself."""
    var out = List[Int]()
    var kind = schema.types[parent].kind
    if kind == TypeKind.UNION or kind == TypeKind.INTERFACE:
        out = schema.possible_types(parent)
    if len(out) == 0:
        out.append(parent)
    return out^


def _matching(
    schema: Schema,
    applicable: List[Int],
    members: List[Int],
    condition: Int,
) -> List[Int]:
    """The applicable members on which a type condition applies, as
    upstream `matching_members`."""
    var out = List[Int]()
    var is_object = schema.types[condition].kind == TypeKind.OBJECT
    var index = 0
    while index < len(applicable):
        var member = members[applicable[index]]
        if member == condition or (
            not is_object and schema.is_sub_type(condition, member)
        ):
            out.append(applicable[index])
        index += 1
    return out^


def _key_of(name: String, members: List[Int]) -> String:
    """The visited key of a fragment under some members."""
    var key = name.copy()
    var index = 0
    while index < len(members):
        key += ","
        key += String(members[index])
        index += 1
    return key^


def _collect(
    schema: Schema,
    document: Document,
    walk: _Walk,
    selection_set: Int,
    parent: Int,
    members: List[Int],
) -> List[_Selected]:
    """The fields of a selection set and of its fragments, in order, each
    with the members it applies to, as upstream
    `collect_selected_fields`."""
    var fields = List[_Selected]()
    var visited = Dict[String, Bool]()
    var all = List[Int]()
    var position = 0
    while position < len(members):
        all.append(position)
        position += 1
    # A stack of frames: the next selection, its type and its members.
    var next = List[Int]()
    var declared = List[Int]()
    var applicable = List[List[Int]]()
    next.append(document.first_child(selection_set))
    declared.append(parent)
    applicable.append(all^)
    while len(next) > 0:
        var top = len(next) - 1
        var selection = next[top]
        if selection == NO_NODE:
            _ = next.pop()
            _ = declared.pop()
            _ = applicable.pop()
            continue
        next[top] = document.next_sibling(selection)
        var kind = document.kind(selection)
        if kind == Kind.FIELD:
            fields.append(
                _Selected(selection, declared[top], applicable[top].copy())
            )
            continue
        var target = declared[top]
        var body = document.child(selection, Role.SELECTION_SET)
        var visit_key = String()
        if kind == Kind.INLINE_FRAGMENT:
            var condition = document.child(selection, Role.TYPE_CONDITION)
            if condition != NO_NODE:
                target = schema.type_named(document.name(condition))
        else:
            var name = String(document.name(selection))
            var found = walk.fragments.find(name)
            if not found:
                continue
            var fragment = found.value()
            body = document.child(fragment, Role.SELECTION_SET)
            target = schema.type_named(
                document.name(document.child(fragment, Role.TYPE_CONDITION))
            )
            visit_key = name^
        if target == NO_TYPE:
            continue
        var matching = _matching(schema, applicable[top], members, target)
        if len(matching) == 0:
            continue
        if kind != Kind.INLINE_FRAGMENT:
            var key = _key_of(visit_key, matching)
            if key in visited:
                continue
            visited[key] = True
        next.append(document.first_child(body))
        declared.append(target)
        applicable.append(matching^)
    return fields^


def _less(a: List[Int], b: List[Int]) -> Bool:
    """Whether a list of positions sorts before another, as `Vec` `Ord`."""
    var index = 0
    while index < len(a) and index < len(b):
        if a[index] != b[index]:
            return a[index] < b[index]
        index += 1
    return len(a) < len(b)


def _sorted_groups(signatures: List[List[Int]]) -> List[List[Int]]:
    """The distinct signatures in order, as a `BTreeSet`."""
    var groups = List[List[Int]]()
    var index = 0
    while index < len(signatures):
        var at = 0
        while at < len(groups) and _less(groups[at], signatures[index]):
            at += 1
        if at == len(groups) or _less(signatures[index], groups[at]):
            groups.insert(at, signatures[index].copy())
        index += 1
    return groups^


def _insert_sorted(mut keys: List[String], key: String):
    """Add a key to a sorted list of distinct keys, as a `BTreeSet`."""
    var at = 0
    while at < len(keys) and keys[at] < key:
        at += 1
    if at == len(keys) or keys[at] != key:
        keys.insert(at, key)


def _string_array(mut tree: JsonTree, keys: List[String]) -> Int:
    """An array of strings."""
    var array = tree.add_array()
    var index = 0
    while index < len(keys):
        tree.push(array, tree.add_string(keys[index]))
        index += 1
    return array


def _wrap(mut tree: JsonTree, keyword: StaticString, items: List[Int]) -> Int:
    """`{keyword: [items]}`."""
    var array = tree.add_array()
    var index = 0
    while index < len(items):
        tree.push(array, items[index])
        index += 1
    var object = tree.add_object()
    tree.set(object, keyword, array)
    return object


def _selection_set(
    mut tree: JsonTree,
    schema: Schema,
    document: Document,
    custom_scalars: CustomScalarMap,
    mut walk: _Walk,
    selection_set: Int,
    parent: Int,
) -> Int:
    """One schema for each pattern of fragment applicability, as upstream
    `build_selection_set_schema`."""
    var members = _members(schema, parent)
    var fields = _collect(
        schema, document, walk, selection_set, parent, members
    )
    var common = List[_Selected]()
    var conditional = List[_Selected]()
    var common_keys = List[String]()
    var index = 0
    while index < len(fields):
        if len(fields[index].members) == len(members):
            common.append(fields[index].copy())
            _insert_sorted(
                common_keys, _response_key(document, fields[index].field)
            )
        else:
            conditional.append(fields[index].copy())
        index += 1
    var common_schema = _fields(
        tree, schema, document, custom_scalars, walk, common
    )
    if len(conditional) == 0:
        return common_schema
    var signatures = List[List[Int]]()
    index = 0
    while index < len(members):
        signatures.append(List[Int]())
        index += 1
    var exclusions = List[String]()
    index = 0
    while index < len(conditional):
        ref field = conditional[index]
        var at = 0
        while at < len(field.members):
            signatures[field.members[at]].append(index)
            at += 1
        var key = _response_key(document, field.field)
        if key not in common_keys:
            _insert_sorted(exclusions, key)
        index += 1
    var groups = _sorted_groups(signatures)
    var other_keys = NO_NODE
    if len(exclusions) > 0:
        var name = String("$otherResponseKeys", tree.length(walk.definitions))
        var excluded = tree.add_object()
        tree.set(excluded, "enum", _string_array(tree, exclusions))
        var not_ = tree.add_object()
        tree.set(not_, "not", excluded)
        tree.set(walk.definitions, name, not_)
        other_keys = ref_schema(tree, name)
    var counts = List[Int]()
    counts.resize(len(conditional), 0)
    index = 0
    while index < len(groups):
        var at = 0
        while at < len(groups[index]):
            counts[groups[index][at]] += 1
            at += 1
        index += 1
    var shared = List[Int]()
    shared.resize(len(conditional), NO_NODE)
    index = 0
    while index < len(conditional):
        if counts[index] >= 2:
            var one = List[_Selected]()
            one.append(conditional[index].copy())
            var node = _fields(
                tree, schema, document, custom_scalars, walk, one
            )
            var name = String("$sharedField", tree.length(walk.definitions))
            tree.set(walk.definitions, name, node)
            shared[index] = ref_schema(tree, name)
        index += 1
    var branches = List[Int]()
    index = 0
    while index < len(groups):
        branches.append(
            _branch(
                tree,
                schema,
                document,
                custom_scalars,
                walk,
                conditional,
                groups[index],
                shared,
                exclusions,
                other_keys,
            )
        )
        index += 1
    var parts = List[Int]()
    parts.append(common_schema)
    parts.append(_wrap(tree, "anyOf", branches))
    return _wrap(tree, "allOf", parts)


def _branch(
    mut tree: JsonTree,
    schema: Schema,
    document: Document,
    custom_scalars: CustomScalarMap,
    mut walk: _Walk,
    conditional: List[_Selected],
    signature: List[Int],
    shared: List[Int],
    exclusions: List[String],
    other_keys: Int,
) -> Int:
    """The schema of one group of members."""
    var selected = List[_Selected]()
    var refs = List[Int]()
    var keys = List[String]()
    var index = 0
    while index < len(signature):
        var field = signature[index]
        if shared[field] == NO_NODE:
            selected.append(conditional[field].copy())
        else:
            refs.append(ref_schema(tree, _ref_name(tree, shared[field])))
        var key = _response_key(document, conditional[field].field)
        if key in exclusions:
            _insert_sorted(keys, key)
        index += 1
    var branch = _fields(tree, schema, document, custom_scalars, walk, selected)
    if len(refs) > 0:
        var parts = List[Int]()
        parts.append(branch)
        parts.extend(refs^)
        branch = _wrap(tree, "allOf", parts)
    if other_keys != NO_NODE:
        var allowed = ref_schema(tree, _ref_name(tree, other_keys))
        if len(keys) > 0:
            var listed = tree.add_object()
            tree.set(listed, "enum", _string_array(tree, keys))
            var options = List[Int]()
            options.append(listed)
            options.append(allowed)
            allowed = _wrap(tree, "anyOf", options)
        tree.set(branch, "propertyNames", allowed)
    return branch


def _ref_name(tree: JsonTree, reference: Int) -> String:
    """The definition name of a `$ref` schema."""
    var text = tree.text(tree.item(reference, 0))
    return String(text[byte=14:])


def _fields(
    mut tree: JsonTree,
    schema: Schema,
    document: Document,
    custom_scalars: CustomScalarMap,
    mut walk: _Walk,
    selected: List[_Selected],
) -> Int:
    """An object schema of fields, as upstream `build_fields_schema`: a
    response key with several different schemas gets `allOf`."""
    var keys = List[String]()
    var schemas = List[List[Int]]()
    var required = List[String]()
    var index = 0
    while index < len(selected):
        ref field = selected[index]
        index += 1
        var key = _response_key(document, field.field)
        var name = document.name(field.field)
        var node: Int
        if name == "__typename":
            node = simple_type(tree, "string")
            tree.set(
                node,
                "description",
                tree.add_string("The typename of this object"),
            )
        else:
            var definition = NO_TYPE
            var kind = schema.types[field.declared_on].kind
            if kind == TypeKind.OBJECT or kind == TypeKind.INTERFACE:
                definition = schema.field_named(field.declared_on, name)
            if definition == NO_TYPE:
                continue
            ref field_def = schema.fields[definition]
            if field_def.type.is_non_null() and key not in required:
                required.append(key)
            node = _output_type(
                tree,
                schema,
                document,
                custom_scalars,
                walk,
                field_def.type,
                document.child(field.field, Role.SELECTION_SET),
            )
            if field_def.description.exists():
                node = with_desc(
                    tree, node, schema.description_text(field_def.description)
                )
        var at = 0
        while at < len(keys) and keys[at] != key:
            at += 1
        if at == len(keys):
            keys.append(key)
            schemas.append(List[Int]())
        ref list = schemas[at]
        if len(list) == 0 or not tree.equals(list[len(list) - 1], tree, node):
            list.append(node)
    var object = simple_type(tree, "object")
    if len(keys) > 0:
        var properties = tree.add_object()
        index = 0
        while index < len(keys):
            if len(schemas[index]) == 1:
                tree.set(properties, keys[index], schemas[index][0])
            else:
                tree.set(
                    properties,
                    keys[index],
                    _wrap(tree, "allOf", schemas[index]),
                )
            index += 1
        tree.set(object, "properties", properties)
    if len(required) > 0:
        tree.set(object, "required", _string_array(tree, required))
    return object


def _output_type(
    mut tree: JsonTree,
    schema: Schema,
    document: Document,
    custom_scalars: CustomScalarMap,
    mut walk: _Walk,
    type: TypeRef,
    selection_set: Int,
) -> Int:
    """The schema of an output type: a nullable type also allows `null`,
    as upstream `type_to_output_schema`."""
    var lists = List[Bool]()
    var bits = type.bits
    var depth = Int(type.depth)
    var non_null = False
    while depth > 0:
        if bits & 1 == 0:
            non_null = True
        else:
            lists.append(non_null)
            non_null = False
        bits >>= 1
        depth -= 1
    var node = _named(
        tree,
        schema,
        document,
        custom_scalars,
        walk,
        Int(type.named),
        selection_set,
    )
    if not non_null:
        node = nullable(tree, node)
    var index = len(lists) - 1
    while index >= 0:
        var array = simple_type(tree, "array")
        tree.set(array, "items", node)
        node = array
        if not lists[index]:
            node = nullable(tree, node)
        index -= 1
    return node


def _named(
    mut tree: JsonTree,
    schema: Schema,
    document: Document,
    custom_scalars: CustomScalarMap,
    mut walk: _Walk,
    named: Int,
    selection_set: Int,
) -> Int:
    """The schema of a named output type, as upstream
    `named_type_to_output_schema`."""
    ref type = schema.types[named]
    if type.name == "String":
        return simple_type(tree, "string")
    if type.name == "Int":
        return simple_type(tree, "integer")
    if type.name == "Float":
        return simple_type(tree, "number")
    if type.name == "Boolean":
        return simple_type(tree, "boolean")
    if type.name == "ID":
        return _string_or_integer(tree)
    if tree.position(walk.definitions, type.name) >= 0:
        return ref_schema(tree, type.name)
    if type.kind.is_composite():
        if selection_set == NO_NODE:
            return tree.add_object()
        return _selection_set(
            tree, schema, document, custom_scalars, walk, selection_set, named
        )
    if type.kind == TypeKind.ENUM:
        var values = tree.add_array()
        var index = Int(type.enum_values.start)
        while index < type.enum_values.end():
            tree.push(values, tree.add_string(schema.enum_values[index].name))
            index += 1
        var object = simple_type(tree, "string")
        tree.set(object, "enum", values)
        if type.description.exists():
            tree.set(
                object,
                "description",
                tree.add_string(schema.description_text(type.description)),
            )
        tree.set(walk.definitions, type.name, object)
        return ref_schema(tree, type.name)
    if type.kind == TypeKind.SCALAR:
        var description = Optional[String](None)
        if type.description.exists():
            description = schema.description_text(type.description)
        var custom = custom_scalars.get(type.name)
        if custom != NO_NODE:
            return with_desc(
                tree, tree.copy_from(custom_scalars.tree, custom), description
            )
        return with_desc(tree, tree.add_object(), description)
    return tree.add_object()
