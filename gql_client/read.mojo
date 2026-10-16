# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Reading a query from the store.

Port of Apollo Client 4.3.3 `src/cache/inmemory/readFromStore.ts`
(`StoreReader`): `diffQueryAgainstStore`, `execSelectionSetImpl`,
`execSubSelectedArrayImpl`, `firstMissing`, `mergeDataState` and
`assertSelectionSetForIdValue`, and of `MissingFieldError` of
`src/cache/core/types/common.ts`.

The result is a new `JsonDocument`. The fields of fragments merge into the
object of their selection set, deeply, as upstream `mergeDeepArray` merges
them. The tree of missing fields is a `JsonDocument` too.

Differences from upstream:

- There is no result cache: each read builds its result.
- `@defer` and `@stream` boundaries are not tracked. The `complete`,
  `result` and `missing` of a diff are the same, because a diff that is
  not incremental reports a partial boundary as partial.
- `MissingFieldError` keeps the message and the missing tree. It does not
  keep the query and the variables.
- The `__typename` of a root object is left out as upstream does it, for
  the root type names that the policies know.
"""

from std.collections import Dict

from gql_json.value import FLAG_DECODED, JsonDocument, JsonKind, NO_NODE
from gql_language.ast import Document, Kind, NO_NODE as NO_AST_NODE, Role
from gql_client.cache import InMemoryCache
from gql_client.helpers import (
    fragment_map,
    get_default_values,
    get_operation_definition,
    is_added_typename,
    should_include,
)
from gql_client.store import member_index
from gql_client.values import (
    Member,
    NO_VALUE,
    TYPENAME,
    ValueKind,
    push_json_text,
)
from gql_client.write import Compiled, compile_into


@fieldwise_init
struct DataState(Equatable, ImplicitlyCopyable, Writable):
    """How much of a selection set the store has: upstream `DataState`."""

    var value: UInt8
    """The state's index; see `is_valid`."""

    comptime NONE = DataState(0)
    """No field yet: upstream `undefined`."""
    comptime EMPTY = DataState(1)
    """Every field is missing."""
    comptime PARTIAL = DataState(2)
    """Some fields are missing."""
    comptime COMPLETE = DataState(3)
    """No field is missing."""

    def is_valid(self) -> Bool:
        """Return True for one of the four states.

        Returns:
            Whether the index names a state.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the state's index.

        Args:
            writer: The destination.
        """
        writer.write("DataState(", self.value, ")")


def merge_data_state(current: DataState, next: DataState) -> DataState:
    """Combine the state so far with the state of one more field.

    Port of `mergeDataState` for the states that a diff without `@defer`
    and `@stream` has.

    Args:
        current: The state so far.
        next: The state of the next field.

    Returns:
        The combined state.
    """
    if next == DataState.PARTIAL or current == DataState.NONE:
        return next
    if current == next:
        return current
    return DataState.PARTIAL


struct MissingFieldError(Copyable, Movable, Writable):
    """The fields that a diff did not find: upstream `MissingFieldError`."""

    var message: String
    """The first message of the tree, such as
    `Can't find field 'name' on ROOT_QUERY object`."""
    var missing: JsonDocument
    """The tree of missing fields: an object of result keys whose leaves
    are messages."""

    def __init__(out self, var message: String, var missing: JsonDocument):
        """Make an error.

        Args:
            message: The first message.
            missing: The missing tree.
        """
        self.message = message^
        self.missing = missing^

    def write_to(self, mut writer: Some[Writer]):
        """Write the message.

        Args:
            writer: The destination.
        """
        writer.write(self.message)


struct DiffResult(Movable):
    """What `diff` gives: upstream `Cache.DiffResult`."""

    var result: Optional[JsonDocument]
    """The data, or None (upstream `null`)."""
    var complete: Bool
    """Whether no field is missing."""
    var missing: Optional[MissingFieldError]
    """The missing fields, or None."""

    def __init__(
        out self,
        var result: Optional[JsonDocument],
        complete: Bool,
        var missing: Optional[MissingFieldError],
    ):
        """Make a result.

        Args:
            result: The data, or None.
            complete: Whether no field is missing.
            missing: The missing fields, or None.
        """
        self.result = result^
        self.complete = complete
        self.missing = missing^

    def take_result(deinit self) -> Optional[JsonDocument]:
        """Return the data and end the result.

        Returns:
            The data, or None.
        """
        return self.result^


@fieldwise_init
struct Pending(Copyable, Movable):
    """One member of an object that a read builds: a key and a node."""

    var name: Int
    """The interned result key."""
    var node: Int
    """The value's node."""


struct ReadMemo(Copyable, Movable):
    """What a read keeps of one field node."""

    var typename: String
    """The type of the last store field name."""
    var valid: Bool
    """Whether `store_name` is set."""
    var store_name: Int
    """The interned store field name in `typename`."""
    var store_text: String
    """The store field name."""
    var has_read: Bool
    """Whether the field has a `read` function in `typename`."""
    var key: Int
    """The interned result key, or -1 before the first read."""

    def __init__(out self):
        """Make an empty memo."""
        self.typename = String("")
        self.valid = False
        self.store_name = -1
        self.store_text = String("")
        self.has_read = False
        self.key = -1


struct ReadContext(Movable):
    """The state of one read: upstream `ReadContext`."""

    var variables: Int
    """The variables object, with the default values."""
    var fragments: Dict[String, Int]
    """The fragment definitions, by name."""
    var out: JsonDocument
    """The result."""
    var missing: JsonDocument
    """The missing tree."""
    var memo: List[ReadMemo]
    """The memo of each node of the query, by node index."""
    var compiled: List[Int32]
    """Each selection set node and its entry in `sets`."""
    var sets: List[Compiled]
    """The compiled selection sets."""
    var members: List[Pending]
    """The members of the objects that the read builds, as a stack: an
    object owns the entries from where it started."""
    var missing_members: List[Pending]
    """The members of the missing trees, as a stack."""
    var items: List[Int]
    """The items of the arrays that the read builds, as a stack."""

    def __init__(
        out self, variables: Int, var fragments: Dict[String, Int], nodes: Int
    ):
        """Start a read.

        Args:
            variables: The variables object.
            fragments: The fragment definitions, by name.
            nodes: The number of nodes of the query.
        """
        self.variables = variables
        self.fragments = fragments^
        self.out = JsonDocument()
        self.missing = JsonDocument()
        self.memo = List[ReadMemo](length=nodes, fill=ReadMemo())
        self.compiled = List[Int32](length=nodes, fill=-1)
        self.sets = List[Compiled]()
        self.members = List[Pending]()
        self.missing_members = List[Pending]()
        self.items = List[Int]()


@fieldwise_init
struct Exec(ImplicitlyCopyable, Movable):
    """What one selection set or array read gives: upstream `ExecResult`."""

    var node: Int
    """The result's node in `ReadContext.out`."""
    var state: DataState
    """How much the store has."""
    var missing: Int
    """The missing tree's node in `ReadContext.missing`, or `NO_NODE`."""


def link(mut document: JsonDocument, container: Int, children: Span[Int, _]):
    """Make some nodes the children of an array or an object, in order.

    The nodes keep their keys. A node that had siblings loses them.

    Args:
        document: The document.
        container: An empty or full array or object; its old children go.
        children: The new children.
    """
    ref parent = document.nodes[container]
    parent.count = Int32(len(children))
    parent.start = Int32(NO_NODE)
    parent.end = Int32(NO_NODE)
    if len(children) == 0:
        return
    parent.start = Int32(children[0])
    parent.end = Int32(children[len(children) - 1])
    var index = 0
    while index < len(children):
        var next = NO_NODE
        if index + 1 < len(children):
            next = children[index + 1]
        document.nodes[children[index]].next = Int32(next)
        index += 1


def merge_json(mut document: JsonDocument, target: Int, source: Int) -> Int:
    """Deep merge two values of a document, as the default `DeepMerger`.

    Two objects merge member by member and two arrays item by item. Any
    other source replaces the target. The merge reuses the nodes, so the
    two values must not be used again.

    Args:
        document: The document.
        target: The earlier value.
        source: The later value.

    Returns:
        The merged value.
    """
    var kind = document.kind(target)
    if kind != document.kind(source) or kind.value < JsonKind.ARRAY.value:
        return source
    var items = document.children(target)
    var incoming = document.children(source)
    if kind == JsonKind.ARRAY:
        var index = 0
        while index < len(incoming):
            if index < len(items):
                items[index] = merge_json(
                    document, items[index], incoming[index]
                )
            else:
                items.append(incoming[index])
            index += 1
    else:
        for member in incoming:
            var position = -1
            var index = 0
            while index < len(items):
                if document.raw_key(items[index]) == document.raw_key(member):
                    position = index
                index += 1
            if position < 0:
                items.append(member)
            else:
                var merged = merge_json(document, items[position], member)
                items[position] = merged
    link(document, target, Span(items))
    return target


def add_pending(
    mut document: JsonDocument,
    mut members: List[Pending],
    start: Int,
    name: Int,
    node: Int,
):
    """Add a member to an object that a read builds, merging a repeated key.

    Args:
        document: The document of the nodes.
        members: The member stack.
        start: Where the object's members start in the stack.
        name: The interned key.
        node: The value.
    """
    var index = start
    while index < len(members):
        if members[index].name == name:
            members[index].node = merge_json(
                document, members[index].node, node
            )
            return
        index += 1
    members.append(Pending(name, node))


def build_object(
    cache: InMemoryCache,
    mut document: JsonDocument,
    mut members: List[Pending],
    start: Int,
) -> Int:
    """Make an object of the members that a read collected, and pop them.

    Args:
        cache: The cache, for the key texts.
        document: The document.
        members: The member stack.
        start: Where the object's members start.

    Returns:
        The new object.
    """
    var object = document.add_object()
    var index = start
    while index < len(members):
        document.add_member(
            object,
            cache.values.names.text(members[index].name),
            members[index].node,
        )
        index += 1
    members.resize(start, Pending(0, 0))
    return object


def _missing_text(mut context: ReadContext, text: String) -> Int:
    """Add a message of the missing tree."""
    return push_json_text(
        context.missing, JsonKind.STRING, FLAG_DECODED, text.as_bytes()
    )


def exec_selection_set(
    mut cache: InMemoryCache,
    mut context: ReadContext,
    document: Document,
    selection_set: Int,
    object: Int,
) raises -> Exec:
    """Read one object, as `execSelectionSetImpl`.

    Args:
        cache: The cache.
        context: The read.
        document: The query.
        selection_set: The selection set.
        object: The object or `Reference` to read.

    Returns:
        The result object, its state and its missing tree.

    Raises:
        Error: For a missing fragment or a policy function that raises.
    """
    if cache.values.is_reference(object) and not cache.has(
        cache.values.ref_id(object)
    ):
        return Exec(
            context.out.add_object(),
            DataState.EMPTY,
            _missing_text(
                context,
                String(
                    "Dangling reference to missing ",
                    cache.values.ref_text(object),
                    " object",
                ),
            ),
        )
    var typename = cache.typename_of(object)
    var start = len(context.members)
    var missing_start = len(context.missing_members)
    if typename.byte_length() > 0 and not cache.policies.is_root_typename(
        typename
    ):
        context.members.append(
            Pending(
                TYPENAME,
                push_json_text(
                    context.out,
                    JsonKind.STRING,
                    FLAG_DECODED,
                    typename.as_bytes(),
                ),
            )
        )
    var state = exec_fields(
        cache,
        context,
        document,
        selection_set,
        object,
        typename,
        start,
        missing_start,
    )
    var node = build_object(cache, context.out, context.members, start)
    var tree = NO_NODE
    if len(context.missing_members) > missing_start:
        tree = build_object(
            cache, context.missing, context.missing_members, missing_start
        )
    return Exec(node, state, tree)


def exec_fields(
    mut cache: InMemoryCache,
    mut context: ReadContext,
    document: Document,
    selection_set: Int,
    object: Int,
    typename: String,
    start: Int,
    missing_start: Int,
) raises -> DataState:
    """Read the selections of one selection set into an object's members.

    Args:
        cache: The cache.
        context: The read.
        document: The query.
        selection_set: The selection set.
        object: The object or `Reference`.
        typename: The object's type, or empty.
        start: Where the object's members start in `context.members`.
        missing_start: Where its missing members start in
            `context.missing_members`.

    Returns:
        The state of these selections.

    Raises:
        Error: For a missing fragment or a policy function that raises.
    """
    var state = DataState.NONE
    var set = compile_into(
        context.compiled, context.sets, document, selection_set
    )
    var count = len(context.sets[set].selections)
    var position = 0
    while position < count:
        ref selection = context.sets[set].selections[position]
        var node = selection.node
        var kind = selection.kind
        var subselection = selection.selection_set
        var has_directives = selection.has_directives
        position += 1
        if has_directives and not should_include(
            document, node, cache.values, context.variables
        ):
            continue
        if kind != Kind.FIELD:
            var fragment = _fragment(context, document, node)
            if _matches(cache, document, fragment, typename):
                var inner = exec_fields(
                    cache,
                    context,
                    document,
                    document.child(fragment, Role.SELECTION_SET),
                    object,
                    typename,
                    start,
                    missing_start,
                )
                state = merge_data_state(state, inner)
            continue
        var key = _field_memo(cache, context, document, node, typename)
        var value = cache.get_field_value(object, context.memo[node].store_name)
        if context.memo[node].has_read:
            var store_text = context.memo[node].store_text
            value = cache.apply_read(
                typename,
                store_text,
                document,
                node,
                context.variables,
                object,
                NO_VALUE,
                False,
                value,
            )
        var added = is_added_typename(document, node)
        if value == NO_VALUE:
            if not added:
                var place = _object_name(cache, object)
                var message = _missing_text(
                    context,
                    String(
                        "Can't find field '",
                        document.name(node),
                        "' on ",
                        place,
                    ),
                )
                add_pending(
                    context.missing,
                    context.missing_members,
                    missing_start,
                    key,
                    message,
                )
                state = merge_data_state(state, DataState.EMPTY)
            continue
        var result: Int
        var missing = NO_NODE
        if cache.values.is_array(value):
            if cache.values.length(value) > 0:
                var found = exec_array(
                    cache, context, document, node, subselection, value
                )
                result = found.node
                missing = found.missing
                state = merge_data_state(state, found.state)
            else:
                result = context.out.add_array()
                state = merge_data_state(state, DataState.COMPLETE)
        elif subselection == NO_AST_NODE:
            result = cache.values.to_json(context.out, value)
            if not added:
                state = merge_data_state(state, DataState.COMPLETE)
        elif cache.values.kind(value) != ValueKind.NULL:
            var found = exec_selection_set(
                cache, context, document, subselection, value
            )
            result = found.node
            missing = found.missing
            var inner = found.state
            if inner == DataState.EMPTY:
                inner = DataState.PARTIAL
            state = merge_data_state(state, inner)
        else:
            result = context.out.add_null()
        if missing != NO_NODE:
            add_pending(
                context.missing,
                context.missing_members,
                missing_start,
                key,
                missing,
            )
        add_pending(context.out, context.members, start, key, result)
    if state == DataState.NONE:
        return DataState.COMPLETE
    return state


def _object_name(mut cache: InMemoryCache, object: Int) raises -> String:
    """Return how a missing field message names an object."""
    if cache.values.is_reference(object):
        return String(cache.values.ref_text(object), " object")
    if cache.values.is_undefined(object):
        # Upstream shows `JSON.stringify(objectOrReference || {})`.
        return "object {}"
    var id = cache.identify_object(object, object, "", False).id
    if id.byte_length() > 0:
        return id + " object"
    return "object " + cache.values.stringify(object, 2)


def _field_memo(
    mut cache: InMemoryCache,
    mut context: ReadContext,
    document: Document,
    field: Int,
    typename: String,
) raises -> Int:
    """Fill the memo of a field for a type; return its result key."""
    if context.memo[field].key < 0:
        var alias = document.child(field, Role.ALIAS)
        var key = document.name(field)
        if alias != NO_AST_NODE:
            key = document.text(alias)
        context.memo[field].key = cache.values.names.intern(key)
    if (
        not context.memo[field].valid
        or context.memo[field].typename != typename
    ):
        var name = document.name(field)
        var text = cache.store_field_name(
            typename, name, document, field, context.variables, NO_VALUE, False
        )
        var policy = cache.policies.get_field_policy(typename, name)
        ref memo = context.memo[field]
        memo.has_read = policy >= 0 and Bool(cache.policies.fields[policy].read)
        memo.store_name = cache.values.names.intern(text)
        memo.store_text = text^
        memo.typename = typename
        memo.valid = True
    return context.memo[field].key


def _fragment(
    mut context: ReadContext, document: Document, selection: Int
) raises -> Int:
    """Return the inline fragment, or the definition that a spread names."""
    if document.kind(selection) == Kind.INLINE_FRAGMENT:
        return selection
    var name = String(document.name(selection))
    var definition = context.fragments.get(name, NO_AST_NODE)
    if definition == NO_AST_NODE:
        raise Error(String("No fragment named ", name))
    return definition


def _matches(
    mut cache: InMemoryCache,
    document: Document,
    fragment: Int,
    typename: String,
) raises -> Bool:
    """Return True when a fragment applies to a type, with no result."""
    var condition = document.child(fragment, Role.TYPE_CONDITION)
    if condition == NO_AST_NODE:
        return True
    if typename.byte_length() == 0:
        return False
    return cache.policies.fragment_matches(
        document.name(condition), typename, False
    )


def exec_array(
    mut cache: InMemoryCache,
    mut context: ReadContext,
    document: Document,
    field: Int,
    selection_set: Int,
    array: Int,
) raises -> Exec:
    """Read the items of an array field, as `execSubSelectedArrayImpl`.

    With a selection set, an item that cannot be read, such as a dangling
    `Reference`, is left out.

    Args:
        cache: The cache.
        context: The read.
        document: The query.
        field: The `Field` node.
        selection_set: The field's selection set, or `NO_NODE`.
        array: The stored array.

    Returns:
        The result array, its state and its missing tree.

    Raises:
        Error: If an item of a field without a selection set is a
            `Reference`, or for the errors of the items.
    """
    var state = DataState.COMPLETE
    var start = len(context.items)
    var missing_start = len(context.missing_members)
    var count = cache.values.length(array)
    var index = 0
    var position = 0
    while index < count:
        var item = cache.values.item(array, index)
        index += 1
        if not (
            selection_set == NO_AST_NODE
            or cache.values.is_undefined(item)
            or cache.can_read(item)
        ):
            continue
        var kind = cache.values.kind(item)
        if kind == ValueKind.NULL:
            context.items.append(context.out.add_null())
        elif kind == ValueKind.ARRAY or selection_set != NO_AST_NODE:
            var found: Exec
            if kind == ValueKind.ARRAY:
                found = exec_array(
                    cache, context, document, field, selection_set, item
                )
            else:
                found = exec_selection_set(
                    cache, context, document, selection_set, item
                )
            context.items.append(found.node)
            state = merge_data_state(state, found.state)
            if found.missing != NO_NODE:
                context.missing_members.append(
                    Pending(
                        cache.values.names.intern(String(position)),
                        found.missing,
                    )
                )
        else:
            _assert_selection_set(cache, document, field, item)
            context.items.append(cache.values.to_json(context.out, item))
        position += 1
    var node = context.out.add_array()
    link(context.out, node, Span(context.items)[start:])
    context.items.resize(start, 0)
    var tree = NO_NODE
    if len(context.missing_members) > missing_start:
        tree = build_object(
            cache, context.missing, context.missing_members, missing_start
        )
    return Exec(node, state, tree)


def _assert_selection_set(
    mut cache: InMemoryCache, document: Document, field: Int, value: Int
) raises:
    """Refuse a `Reference` inside the value of a field that has no
    selection set, as `assertSelectionSetForIdValue`."""
    var work: List[Int] = [value]
    while len(work) > 0:
        var current = work.pop()
        var kind = cache.values.kind(current)
        if kind == ValueKind.REFERENCE:
            var typename = cache.typename_of(current)
            raise Error(
                String(
                    "Missing selection set for object of type ",
                    typename if typename.byte_length() > 0 else "<undefined>",
                    " returned for query field ",
                    document.name(field),
                )
            )
        var size = cache.values.length(current)
        var index = 0
        while index < size:
            if kind == ValueKind.ARRAY:
                work.append(cache.values.item(current, index))
            else:
                work.append(cache.values.member_value(current, index))
            index += 1


def first_missing(document: JsonDocument, node: Int) -> String:
    """Return the first message of a missing tree, as `firstMissing`.

    Args:
        document: The missing tree's document.
        node: A tree node: a message or an object.

    Returns:
        The first message, depth first.
    """
    var current = node
    while document.kind(current) == JsonKind.OBJECT:
        current = document.first(current)
    return document.string_value(current)


def diff_query_against_store(
    mut cache: InMemoryCache,
    query: Document,
    variables: JsonDocument,
    root_id: String,
    return_partial_data: Bool,
) raises -> DiffResult:
    """Read a query and tell what is missing, as `diffQueryAgainstStore`.

    Args:
        cache: The cache.
        query: The query.
        variables: The variables object, or an empty document.
        root_id: The entity that the query starts at.
        return_partial_data: Whether an incomplete result is kept.

    Returns:
        The result, whether it is complete, and the missing fields.

    Raises:
        Error: If the document has no query, or for the read errors.
    """
    var operation = get_operation_definition(query)
    if operation == NO_AST_NODE or query.operation(operation).value != 0:
        raise Error("Must contain a query definition.")
    var members = get_default_values(query, operation, cache.values)
    var given = cache.values.from_json(variables, variables.root)
    var count = cache.values.length(given) if cache.values.is_object(
        given
    ) else 0
    var index = 0
    while index < count:
        var name = cache.values.member_name(given, index)
        var value = Int32(cache.values.member_value(given, index))
        var position = member_index(members, name)
        if position < 0:
            members.append(Member(Int32(name), value))
        else:
            members[position].value = value
        index += 1
    var context = ReadContext(
        cache.values.add_object(members), fragment_map(query), len(query.nodes)
    )
    var root = cache.values.add_reference(root_id)
    var found = exec_selection_set(
        cache,
        context,
        query,
        query.child(operation, Role.SELECTION_SET),
        root,
    )
    var complete = found.state == DataState.COMPLETE
    var keep = complete or (
        return_partial_data and context.out.length(found.node) > 0
    )
    var result: Optional[JsonDocument] = None
    if keep:
        context.out.root = found.node
        var out = JsonDocument()
        swap(out, context.out)
        result = out^
    var missing: Optional[MissingFieldError] = None
    if found.missing != NO_NODE:
        context.missing.root = found.missing
        var message = first_missing(context.missing, found.missing)
        var tree = JsonDocument()
        swap(tree, context.missing)
        missing = MissingFieldError(message^, tree^)
    return DiffResult(result^, complete, missing^)
