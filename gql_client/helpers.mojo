# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Document and store-name helpers of the normalized cache.

Port of Apollo Client 4.3.3 `src/cache/inmemory/helpers.ts` and of the
pieces of `src/utilities` that the cache uses:

| Function | Upstream |
| --- | --- |
| `field_name_from_store_name` | `fieldNameFromStoreName` (`helpers.ts`) |
| `get_store_key_name` | `getStoreKeyName` (`internal/getStoreKeyName.ts`) |
| `store_key_name_from_field` | `storeKeyNameFromField` |
| `value_to_object` | `valueToObjectRepresentation` |
| `arguments_object_from_field` | `argumentsObjectFromField` |
| `should_include` | `shouldInclude` (`internal/shouldInclude.ts`) |
| `get_default_values` | `getDefaultValues` |
| `get_fragment_query_document` | `getFragmentQueryDocument` |
| `add_typename_to_document`, `is_added_typename` | `addTypenameToDocument`, `addTypenameToDocument.added` |
| `fragment_map` | `createFragmentMap(getFragmentDefinitions(doc))` |
| `get_operation_definition` | `getOperationDefinition`, `getMainDefinition` |
| `result_key_name` | `resultKeyNameFromField` |

The values that these functions make, such as an arguments object, are
values of a `Values` arena.

Differences from upstream:

- `add_typename_to_document` marks each `__typename` field that it adds
  with `FLAG_ADDED_TYPENAME` in the node flags. Upstream compares the node
  with one shared `TYPENAME_FIELD` object.
- `get_fragment_query_document` adds the query operation after the other
  definitions. Upstream puts it first. The cache reads the first operation
  either way.
- An `@connection` key that is not a string goes in the store field name as
  its JSON text. Upstream fails with a `TypeError` on such a key.
- `check_document` refuses a forbidden alias in a document without an
  operation, as if the operation were an anonymous query. Upstream fails
  with a `TypeError` there.
"""

from std.collections import Dict

from gql_language.ast import Document, Kind, NO_NODE, OperationType, Role
from gql_client.fuzzy import is_name_byte
from gql_client.values import (
    Member,
    NO_VALUE,
    NULL_VALUE,
    UNDEFINED_VALUE,
    ValueKind,
    Values,
)

comptime FLAG_ADDED_TYPENAME: UInt8 = 64
"""The flag of a `__typename` field that `add_typename_to_document` added."""

comptime KNOWN_DIRECTIVES: Array[StaticString, 8] = [
    "connection",
    "include",
    "skip",
    "client",
    "rest",
    "export",
    "nonreactive",
    "stream",
]
"""The directives that `get_store_key_name` leaves out of a store name."""


def field_name_from_store_name(store_field_name: StringSlice) -> String:
    """Return the field name at the start of a store field name.

    The field name is the longest prefix that matches
    `/^[_a-z][_0-9a-z]*/i`. A store field name that does not match is its
    own field name.

    Args:
        store_field_name: A store field name, such as `book({"id":1})`.

    Returns:
        The field name, such as `book`.
    """
    var length = name_prefix_length(store_field_name)
    if length == 0:
        return String(store_field_name)
    return String(
        StringSlice(unsafe_from_utf8=store_field_name.as_bytes()[:length])
    )


def name_prefix_length(text: StringSlice) -> Int:
    """Return the length of the GraphQL name at the start of a text.

    Args:
        text: The text.

    Returns:
        The bytes of the match of `/^[_a-z][_0-9a-z]*/i`, or 0.
    """
    var bytes = text.as_bytes()
    var position = 0
    while position < len(bytes) and is_name_byte(bytes[position], position):
        position += 1
    return position


def result_key_name(document: Document, field: Int) -> String:
    """Return the key of a field in a result: its alias, or its name.

    Args:
        document: The document.
        field: A `Field` node.

    Returns:
        The result key.
    """
    var alias = document.child(field, Role.ALIAS)
    if alias != NO_NODE:
        return String(document.text(alias))
    return String(document.name(field))


def get_operation_definition(document: Document) raises -> Int:
    """Return the first operation definition of a checked document.

    Port of `getOperationDefinition`, which calls `checkDocument` first.

    Args:
        document: The document.

    Returns:
        The `OperationDefinition` node, or `NO_NODE`.

    Raises:
        Error: If `check_document` refuses the document.
    """
    check_document(document)
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        if document.kind(definition) == Kind.OPERATION_DEFINITION:
            return definition
        definition = document.next_sibling(definition)
    return NO_NODE


def check_document(document: Document) raises:
    """Refuse a document that the cache cannot use, as `checkDocument`.

    Args:
        document: The document.

    Raises:
        Error: For a definition that is not an operation or a fragment, for
            more than one operation, and for a field alias `__typename` or
            `__ac_...` on another field. The messages are the upstream
            messages.
    """
    var operations = 0
    var first = NO_NODE
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        var kind = document.kind(definition)
        if kind == Kind.OPERATION_DEFINITION:
            operations += 1
            if first == NO_NODE:
                first = definition
        elif kind != Kind.FRAGMENT_DEFINITION:
            raise Error(
                String(
                    'Schema type definitions not allowed in queries. Found: "',
                    kind.text(),
                    '"',
                )
            )
        definition = document.next_sibling(definition)
    if operations > 1:
        raise Error(
            String(
                "Ambiguous GraphQL document: contains ",
                operations,
                " operations",
            )
        )
    # Pairs of (node, index of its path in `paths`), depth first.
    var paths = List[List[String]]()
    paths.append(List[String]())
    var stack: List[Int] = [document.root, 0]
    while len(stack) > 0:
        var path = stack.pop()
        var node = stack.pop()
        var inner = path
        if document.kind(node) == Kind.FIELD:
            var alias = document.child(node, Role.ALIAS)
            var name = String(document.name(node))
            if alias != NO_NODE:
                var text = String(document.text(alias))
                if (text == "__typename" or text.startswith("__ac_")) and (
                    text != name
                ):
                    var field_path = paths[path].copy()
                    field_path.append(name)
                    raise Error(
                        String(
                            "`",
                            text,
                            (
                                "` is a forbidden field alias name in the"
                                " selection set for field `"
                            ),
                            ".".join(field_path),
                            "` in ",
                            _operation_text(document, first),
                            ' "',
                            _operation_name(document, first),
                            '".',
                        )
                    )
                name = text
            var extended = paths[path].copy()
            extended.append(name)
            paths.append(extended^)
            inner = len(paths) - 1
        var child = document.first_child(node)
        while child != NO_NODE:
            stack.append(child)
            stack.append(inner)
            child = document.next_sibling(child)


def _operation_text(document: Document, operation: Int) -> String:
    """Return the operation type of the first operation, or `query`."""
    if operation == NO_NODE:
        return "query"
    return String(document.operation(operation).text())


def _operation_name(document: Document, operation: Int) -> String:
    """Return the name of the first operation, as `getOperationName(doc,
    "(anonymous)")`."""
    if operation == NO_NODE or document.child(operation, Role.NAME) == NO_NODE:
        return "(anonymous)"
    return String(document.name(operation))


def fragment_map(document: Document) -> Dict[String, Int]:
    """Return the fragment definitions of a document, by name.

    Args:
        document: The document.

    Returns:
        Each fragment name and its `FragmentDefinition` node; a later
        definition with the same name replaces an earlier one.
    """
    var out = Dict[String, Int]()
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        if document.kind(definition) == Kind.FRAGMENT_DEFINITION:
            out[String(document.name(definition))] = definition
        definition = document.next_sibling(definition)
    return out^


def value_to_object(
    document: Document, value: Int, mut values: Values, variables: Int
) -> Int:
    """Return the cache value of a GraphQL value literal.

    Port of `valueToObjectRepresentation`: an `Int` or a `Float` becomes a
    number, an enum value becomes a string, and a variable becomes the
    variable's value, or `undefined`.

    Args:
        document: The document.
        value: A value node.
        values: The arena for the new value.
        variables: The variables object, or `NO_VALUE`.

    Returns:
        The new value.
    """
    var kind = document.kind(value)
    if kind == Kind.INT or kind == Kind.FLOAT:
        return values.add_number_text(document.text(value).as_bytes())
    if kind == Kind.STRING:
        return values.add_string(document.string_value(value))
    if kind == Kind.BOOLEAN:
        return values.add_bool(document.boolean_value(value))
    if kind == Kind.ENUM:
        return values.add_string(document.text(value))
    if kind == Kind.NULL:
        return NULL_VALUE
    if kind == Kind.VARIABLE:
        var found = values.get(variables, document.name(value))
        return UNDEFINED_VALUE if found == NO_VALUE else found
    if kind == Kind.LIST:
        var items = List[Int]()
        var item = document.first_child(value)
        while item != NO_NODE:
            items.append(value_to_object(document, item, values, variables))
            item = document.next_sibling(item)
        return values.add_array(items)
    # The last kind of value literal: an object.
    var members = List[Member]()
    var field = document.first_child(value)
    while field != NO_NODE:
        var name = values.names.intern(document.name(field))
        var inner = value_to_object(
            document,
            document.child(field, Role.VALUE),
            values,
            variables,
        )
        _assign(members, name, inner)
        field = document.next_sibling(field)
    return values.add_object(members)


def _assign(mut members: List[Member], name: Int, value: Int):
    """Set a member, as a JavaScript assignment `object[name] = value` does:
    a key that is there keeps its position."""
    var index = 0
    while index < len(members):
        if Int(members[index].name) == name:
            members[index].value = Int32(value)
            return
        index += 1
    members.append(Member(Int32(name), Int32(value)))


def arguments_object_from_field(
    document: Document, node: Int, mut values: Values, variables: Int
) -> Int:
    """Return the arguments of a field or a directive, as an object.

    Args:
        document: The document.
        node: A `Field` or `Directive` node.
        values: The arena for the new value.
        variables: The variables object, or `NO_VALUE`.

    Returns:
        The arguments object, or `NO_VALUE` (upstream `null`) when the node
        has no arguments.
    """
    var argument = document.child(node, Role.ARGUMENT)
    if argument == NO_NODE:
        return NO_VALUE
    var members = List[Member]()
    while argument != NO_NODE:
        var name = values.names.intern(document.name(argument))
        var inner = value_to_object(
            document, document.child(argument, Role.VALUE), values, variables
        )
        _assign(members, name, inner)
        argument = document.next_with_role(argument)
    return values.add_object(members)


def get_store_key_name(
    field_name: StringSlice, mut values: Values, args: Int, directives: Int
) -> String:
    """Return the store field name of a field, its arguments and directives.

    Port of `getStoreKeyName`. The arguments go in canonical JSON, in
    parentheses. An `@connection(key:)` directive replaces the field name,
    and its `filter` argument picks the arguments to keep. Every directive
    that is not in `KNOWN_DIRECTIVES` is added after an `@`.

    Args:
        field_name: The field name.
        values: The arena of the arguments.
        args: The arguments object, or `NO_VALUE` for none.
        directives: An object of each directive's arguments object, or
            `NO_VALUE`.

    Returns:
        The store field name.
    """
    var connection = values.get(directives, "connection")
    var key = values.get(connection, "key")
    if args != NO_VALUE and values.truthy(key):
        var filter = values.get(connection, "filter")
        if values.is_array(filter) and values.length(filter) > 0:
            var members = List[Member]()
            # The filter keys are sorted, as `filterKeys.sort()` sorts them.
            var sorted = _sorted_texts(values, filter)
            var index = 0
            while index < len(sorted):
                var name = values.names.intern(sorted[index])
                _assign(members, name, _member_or_undefined(values, args, name))
                index += 1
            var filtered = values.canonical_stringify(
                values.add_object(members)
            )
            if filtered != "{}":
                return String(_key_text(values, key), "(", filtered, ")")
        return _key_text(values, key)
    var complete = String(field_name)
    if args != NO_VALUE:
        var text = values.canonical_stringify(args)
        if text != "{}":
            complete += "(" + text + ")"
    var count = values.length(directives)
    var index = 0
    while index < count:
        var name = values.names.text(values.member_name(directives, index))
        if not _is_known_directive(name):
            var arguments = values.member_value(directives, index)
            if values.length(arguments) > 0:
                complete += String(
                    "@", name, "(", values.canonical_stringify(arguments), ")"
                )
            else:
                complete += "@" + String(name)
        index += 1
    return complete^


def _key_text(values: Values, key: Int) -> String:
    """Return the text of a `@connection` key, as a template string gives
    it: a string as it is, any other value as JSON."""
    if values.kind(key) == ValueKind.STRING:
        return String(values.text(key))
    return values.stringify(key)


def _member_or_undefined(values: Values, object: Int, name: Int) -> Int:
    """Return a member's value, or `undefined` when the key is not there."""
    var found = values.find(object, name)
    return UNDEFINED_VALUE if found == NO_VALUE else found


def _sorted_texts(values: Values, array: Int) -> List[String]:
    """Return the items of an array as texts, sorted as `Array.sort` sorts
    them."""
    var out = List[String]()
    var index = 0
    while index < values.length(array):
        var item = values.item(array, index)
        if values.kind(item) == ValueKind.STRING:
            out.append(String(values.text(item)))
        else:
            out.append(values.stringify(item))
        index += 1
    var position = 1
    while position < len(out):
        var back = position
        while back > 0 and out[back] < out[back - 1]:
            out.swap_elements(back, back - 1)
            back -= 1
        position += 1
    return out^


def _is_known_directive(name: StringSlice) -> Bool:
    """Return True for a directive that a store name leaves out."""
    var known = materialize[KNOWN_DIRECTIVES]()
    var index = 0
    while index < 8:
        if known[index] == name:
            return True
        index += 1
    return False


def directives_object(
    document: Document, field: Int, mut values: Values, variables: Int
) -> Int:
    """Return an object of each directive of a field and its arguments.

    Args:
        document: The document.
        field: A `Field` node.
        values: The arena for the new value.
        variables: The variables object, or `NO_VALUE`.

    Returns:
        An object whose keys are the directive names, in order, and whose
        values are the arguments objects.
    """
    var members = List[Member]()
    var directive = document.child(field, Role.DIRECTIVE)
    while directive != NO_NODE:
        var name = values.names.intern(document.name(directive))
        var arguments = arguments_object_from_field(
            document, directive, values, variables
        )
        if arguments == NO_VALUE:
            arguments = values.add_object(List[Member]())
        _assign(members, name, arguments)
        directive = document.next_with_role(directive)
    return values.add_object(members)


def store_key_name_from_field(
    document: Document, field: Int, mut values: Values, variables: Int
) -> String:
    """Return the store field name of a field, as `storeKeyNameFromField`.

    Args:
        document: The document.
        field: A `Field` node.
        values: The arena for the arguments.
        variables: The variables object, or `NO_VALUE`.

    Returns:
        The store field name, such as `book({"id":1})`.
    """
    var directives = directives_object(document, field, values, variables)
    var args = arguments_object_from_field(document, field, values, variables)
    return get_store_key_name(document.name(field), values, args, directives)


def should_include(
    document: Document, selection: Int, values: Values, variables: Int
) raises -> Bool:
    """Return True when `@skip` and `@include` keep a selection.

    Args:
        document: The document.
        selection: A selection node.
        values: The arena of the variables.
        variables: The variables object, or `NO_VALUE`.

    Returns:
        Whether every `@skip(if:)` is false and every `@include(if:)` is
        true.

    Raises:
        Error: For a directive with the wrong arguments, or a variable that
            has no value; the messages are the upstream messages.
    """
    var directive = document.child(selection, Role.DIRECTIVE)
    if directive == NO_NODE:
        return True
    var found = List[Int]()
    while directive != NO_NODE:
        var name = document.name(directive)
        if name == "skip" or name == "include":
            var argument = document.child(directive, Role.ARGUMENT)
            if (
                argument == NO_NODE
                or document.count(directive, Role.ARGUMENT) != 1
            ):
                raise Error(
                    String(
                        "Incorrect number of arguments for the @",
                        name,
                        " directive.",
                    )
                )
            if String(document.name(argument)) != "if":
                raise Error(
                    String("Invalid argument for the @", name, " directive.")
                )
            var value = document.child(argument, Role.VALUE)
            var kind = document.kind(value)
            if kind != Kind.VARIABLE and kind != Kind.BOOLEAN:
                raise Error(
                    String(
                        "Argument for the @",
                        name,
                        " directive must be a variable or a boolean value.",
                    )
                )
            found.append(directive)
        directive = document.next_with_role(directive)
    var index = 0
    while index < len(found):
        var name = document.name(found[index])
        var value = document.child(
            document.child(found[index], Role.ARGUMENT), Role.VALUE
        )
        var evaluated: Bool
        if document.kind(value) == Kind.VARIABLE:
            var variable = values.get(variables, document.name(value))
            if values.is_undefined(variable):
                raise Error(
                    String(
                        "Invalid variable referenced in @", name, " directive."
                    )
                )
            evaluated = values.truthy(variable)
        else:
            evaluated = document.boolean_value(value)
        if evaluated == (name == "skip"):
            return False
        index += 1
    return True


def get_default_values(
    document: Document, operation: Int, mut values: Values
) -> List[Member]:
    """Return the default values of the variables of an operation.

    Args:
        document: The document.
        operation: An `OperationDefinition` node.
        values: The arena for the values.

    Returns:
        A member for each variable with a default value, in order.
    """
    var out = List[Member]()
    var definition = document.child(operation, Role.VARIABLE_DEFINITION)
    while definition != NO_NODE:
        var default = document.child(definition, Role.DEFAULT_VALUE)
        if default != NO_NODE:
            var variable = document.child(definition, Role.VARIABLE)
            var name = values.names.intern(document.name(variable))
            _assign(
                out, name, value_to_object(document, default, values, NO_VALUE)
            )
        definition = document.next_with_role(definition)
    return out^


def get_fragment_query_document(
    document: Document, fragment_name: StringSlice = ""
) raises -> Document:
    """Return a query that spreads one fragment of a fragment document.

    Port of `getFragmentQueryDocument`: the copy gets the operation
    `query { ...fragmentName }`.

    Args:
        document: A document of fragment definitions only.
        fragment_name: The fragment to spread. Empty when the document has
            exactly one fragment.

    Returns:
        The query document.

    Raises:
        Error: If the document has an operation, or if `fragment_name` is
            empty and the document does not have exactly one fragment.
    """
    var count = 0
    var only = NO_NODE
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        if document.kind(definition) == Kind.OPERATION_DEFINITION:
            var named = String("")
            if document.child(definition, Role.NAME) != NO_NODE:
                named = String(" named '", document.name(definition), "'")
            raise Error(
                String(
                    "Found a ",
                    document.operation(definition).text(),
                    " operation",
                    named,
                    ". No operations are allowed when using a fragment as a",
                    " query. Only fragments are allowed.",
                )
            )
        if document.kind(definition) == Kind.FRAGMENT_DEFINITION:
            count += 1
            only = definition
        definition = document.next_sibling(definition)
    var name = String(fragment_name)
    if fragment_name.byte_length() == 0:
        if count != 1:
            raise Error(
                String(
                    "Found ",
                    count,
                    " fragments. `fragmentName` must be provided when there",
                    " is not exactly 1 fragment.",
                )
            )
        name = String(document.name(only))
    var query = document.copy()
    var operation = query.add_child(
        query.root,
        Kind.OPERATION_DEFINITION,
        Role.DEFINITION,
        OperationType.QUERY.value,
    )
    var selections = query.add_child(
        operation, Kind.SELECTION_SET, Role.SELECTION_SET
    )
    var spread = query.add_child(
        selections, Kind.FRAGMENT_SPREAD, Role.SELECTION
    )
    _ = query.add_name(spread, Role.NAME, name)
    return query^


def add_typename_to_document(document: Document) -> Document:
    """Return a copy of a document with `__typename` in its selection sets.

    Port of `addTypenameToDocument`. Each selection set gets a
    `__typename` field at its end, except:

    - the selection set of an operation;
    - a selection set that has a field whose name starts with `__`;
    - the selection set of a field with an `@export` directive.

    Each field that it adds has the flag `FLAG_ADDED_TYPENAME`.

    Args:
        document: The document.

    Returns:
        The new document.
    """
    var out = document.copy()
    # Pairs of (node, parent), depth first.
    var stack: List[Int] = [out.root, NO_NODE]
    var targets = List[Int]()
    while len(stack) > 0:
        var parent = stack.pop()
        var node = stack.pop()
        if out.kind(node) == Kind.SELECTION_SET and _needs_typename(
            out, node, parent
        ):
            targets.append(node)
        var child = out.first_child(node)
        while child != NO_NODE:
            stack.append(child)
            stack.append(node)
            child = out.next_sibling(child)
    var index = 0
    while index < len(targets):
        var field = out.add_child(
            targets[index], Kind.FIELD, Role.SELECTION, FLAG_ADDED_TYPENAME
        )
        _ = out.add_name(field, Role.NAME, "__typename")
        index += 1
    return out^


def _needs_typename(document: Document, selections: Int, parent: Int) -> Bool:
    """Return True when `addTypenameToDocument` adds `__typename` to a
    selection set."""
    if document.kind(parent) == Kind.OPERATION_DEFINITION:
        return False
    var selection = document.first_child(selections)
    while selection != NO_NODE:
        if document.kind(selection) == Kind.FIELD and document.name(
            selection
        ).startswith("__"):
            return False
        selection = document.next_sibling(selection)
    if document.kind(parent) == Kind.FIELD:
        var directive = document.child(parent, Role.DIRECTIVE)
        while directive != NO_NODE:
            if document.name(directive) == "export":
                return False
            directive = document.next_with_role(directive)
    return True


@always_inline
def is_added_typename(document: Document, field: Int) -> Bool:
    """Return True for a `__typename` field that the cache added.

    Args:
        document: The document.
        field: A `Field` node.

    Returns:
        Whether `add_typename_to_document` added it.
    """
    return document.nodes[field].flags & FLAG_ADDED_TYPENAME != 0
