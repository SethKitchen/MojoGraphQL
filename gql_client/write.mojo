# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Writing a result into the store.

Port of Apollo Client 4.3.3 `src/cache/inmemory/writeToStore.ts`
(`StoreWriter`): `processSelectionSet`, `processFieldValue`,
`flattenFields`, `applyMerges`, the merge trees, and
`getTypenameFromResult`. It also holds `Policies.runMergeFunction` and
`Policies.getMergeFunction`.

The writer first collects the fields of each entity in
`InMemoryCache.incoming`, in the order upstream fills
`context.incomingById`. Then it runs the merge functions and merges each
entity into the store. A write that raises changes no entity.

Differences from upstream:

- `@client` and `@defer` change nothing here. Upstream uses them only for
  development warnings.
- The development warnings (`Missing field ... while writing result`, the
  data loss warning) are not printed.
- `isFresh` is not ported: there is no result cache.
- The `storage` object of a merge function is not ported.
- The `readField("__typename", child)` that finds the type of a child
  object does not run a `read` function of `__typename`.
"""

from std.collections import Dict

from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_json.writer import stringify
from gql_language.ast import Document, Kind, NO_NODE as NO_AST_NODE, Role
from gql_client.cache import FieldFunctionOptions, Incoming, InMemoryCache
from gql_client.helpers import (
    field_name_from_store_name,
    fragment_map,
    get_default_values,
    get_operation_definition,
    result_key_name,
    should_include,
)
from gql_client.policies import FieldMergeFunction, KeyMode, MergeMode
from gql_client.store import member_index, member_value
from gql_client.values import (
    ID_NAME,
    Member,
    NO_VALUE,
    TYPENAME,
    UNDERSCORE_ID_NAME,
    ValueKind,
)


@fieldwise_init
struct MergeInfo(Copyable, Movable):
    """The merge function of a field: upstream `MergeInfo`."""

    var field: Int
    """The `Field` node."""
    var typename: String
    """The parent type, or empty."""
    var mode: MergeMode
    """`TRUE`, `FALSE` or `FUNCTION`."""
    var function: Optional[FieldMergeFunction]
    """The function, for `MergeMode.FUNCTION`."""


struct TreeNode(Copyable, Movable):
    """One node of a merge tree: upstream `MergeTree`."""

    var keys: List[Int]
    """The key of each child: a store field name id, or `-1 - index` for
    an array position."""
    var children: List[Int]
    """The node of each child."""
    var info: Optional[MergeInfo]
    """The merge function of this position, or None."""

    def __init__(out self):
        """Make an empty node."""
        self.keys = List[Int]()
        self.children = List[Int]()
        self.info = None


struct Selection(Copyable, Movable):
    """One selection of a selection set, read once per write."""

    var node: Int
    """The selection node."""
    var kind: Kind
    """`FIELD`, `INLINE_FRAGMENT` or `FRAGMENT_SPREAD`."""
    var key: String
    """A field's result key; a spread's fragment name."""
    var name: String
    """A field's name."""
    var selection_set: Int
    """A field's or fragment's selection set, or `NO_NODE`."""
    var has_directives: Bool
    """Whether the selection has directives, so `should_include` runs."""

    def __init__(out self, document: Document, node: Int):
        """Read a selection.

        Args:
            document: The document.
            node: The selection node.
        """
        self.node = node
        self.kind = document.kind(node)
        self.key = String("")
        self.name = String("")
        self.selection_set = document.child(node, Role.SELECTION_SET)
        self.has_directives = (
            document.child(node, Role.DIRECTIVE) != NO_AST_NODE
        )
        if self.kind == Kind.FIELD:
            self.key = result_key_name(document, node)
            self.name = String(document.name(node))
        elif self.kind == Kind.FRAGMENT_SPREAD:
            self.key = String(document.name(node))


struct Compiled(Copyable, Movable):
    """The selections of one selection set, and the memo of its fields."""

    var selections: List[Selection]
    """The selections, in order."""
    var typename_key: String
    """The result key of the first `__typename` field, or empty."""
    var has_typename_field: Bool
    """Whether a `__typename` field is a direct selection."""
    var memo_typename: String
    """The type of the last `flattenFields`."""
    var memo_valid: Bool
    """Whether `memo_list` holds the fields for `memo_typename`."""
    var memo_list: Int
    """The entry of `WriteContext.field_lists` that holds the fields of the
    last `flattenFields`."""

    def __init__(out self):
        """Make an empty selection set."""
        self.selections = List[Selection]()
        self.typename_key = String("")
        self.has_typename_field = False
        self.memo_typename = String("")
        self.memo_valid = False
        self.memo_list = -1


struct FieldMemo(Copyable, Movable):
    """What a write keeps of one field node: its texts, and its store field
    name for the last type it was seen in."""

    var ready: Bool
    """Whether `field_name`, `key` and `selection_set` are set."""
    var field_name: String
    """The field name."""
    var key: String
    """The result key: the alias, or the name."""
    var selection_set: Int
    """The field's selection set, or `NO_NODE`."""
    var typename: String
    """The type of `name`."""
    var valid: Bool
    """Whether `name` is set."""
    var name: Int
    """The interned store field name."""

    def __init__(out self):
        """Make an empty memo."""
        self.ready = False
        self.field_name = String("")
        self.key = String("")
        self.selection_set = NO_AST_NODE
        self.typename = String("")
        self.valid = False
        self.name = -1


struct WriteContext(Movable):
    """The state of one write: upstream `WriteContext`."""

    var variables: Int
    """The variables object, with the default values."""
    var fragments: Dict[String, Int]
    """The fragment definitions of the query, by name."""
    var overwrite: Bool
    """The `overwrite` option."""
    var tree: List[TreeNode]
    """The nodes of every merge tree."""
    var free: List[Int]
    """The empty merge tree nodes that can be used again, as upstream
    `emptyMergeTreePool`."""
    var compiled: List[Int32]
    """Each selection set node and its entry in `sets`."""
    var sets: List[Compiled]
    """The compiled selection sets."""
    var field_lists: List[List[Int]]
    """The results of `flatten_fields`, which do not change once made."""
    var stack: List[Member]
    """The incoming fields of the objects that the write processes, as a
    stack: an object owns the entries from where it started."""
    var field_memo: List[FieldMemo]
    """The memo of each field node, by node index."""
    var fuzzy: Bool
    """Whether the policies have fuzzy subtypes, so a fragment match
    depends on the result and is not memoized."""
    var key_typename: String
    """The type of the last key-mode lookup."""
    var key_default: Bool
    """Whether `key_typename` uses the default `dataIdFromObject`."""
    var key_valid: Bool
    """Whether `key_default` is set."""

    def __init__(
        out self,
        variables: Int,
        var fragments: Dict[String, Int],
        overwrite: Bool,
        fuzzy: Bool,
        nodes: Int,
    ):
        """Start a write.

        Args:
            variables: The variables object.
            fragments: The fragment definitions, by name.
            overwrite: The `overwrite` option.
            fuzzy: Whether fuzzy subtypes exist.
            nodes: The number of nodes of the query.
        """
        self.variables = variables
        self.fragments = fragments^
        self.overwrite = overwrite
        self.tree = List[TreeNode]()
        self.free = List[Int]()
        self.compiled = List[Int32](length=nodes, fill=-1)
        self.sets = List[Compiled]()
        self.field_lists = List[List[Int]]()
        self.stack = List[Member]()
        self.field_memo = List[FieldMemo](length=nodes, fill=FieldMemo())
        self.fuzzy = fuzzy
        self.key_typename = String("")
        self.key_default = False
        self.key_valid = False

    def new_tree(mut self) -> Int:
        """Add an empty merge tree node.

        Returns:
            Its index.
        """
        if len(self.free) > 0:
            var reused = self.free.pop()
            # Only an empty node goes in the pool, so it needs no reset.
            return reused
        self.tree.append(TreeNode())
        return len(self.tree) - 1

    def child_tree(mut self, tree: Int, key: Int) -> Int:
        """Return a child of a merge tree, and add it if it is new.

        Args:
            tree: The parent node.
            key: The child key.

        Returns:
            The child node, as `getChildMergeTree`.
        """
        var index = 0
        while index < len(self.tree[tree].keys):
            if self.tree[tree].keys[index] == key:
                return self.tree[tree].children[index]
            index += 1
        var child = self.new_tree()
        self.tree[tree].keys.append(key)
        self.tree[tree].children.append(child)
        return child

    def is_empty(self, tree: Int) -> Bool:
        """Return True for a tree with no merge info and no children.

        Args:
            tree: The node, or -1.

        Returns:
            Whether it is empty, as `mergeTreeIsEmpty`.
        """
        return tree < 0 or (
            not self.tree[tree].info and len(self.tree[tree].keys) == 0
        )

    def recycle(mut self, tree: Int, key: Int):
        """Remove an empty child, as `maybeRecycleChildMergeTree`.

        Args:
            tree: The parent node.
            key: The child key, which `child_tree` gave the tree.
        """
        var index = 0
        while self.tree[tree].keys[index] != key:
            index += 1
        var child = self.tree[tree].children[index]
        if self.is_empty(child):
            self.free.append(child)
            _ = self.tree[tree].keys.pop(index)
            _ = self.tree[tree].children.pop(index)

    def merge_trees(mut self, left: Int, right: Int) -> Int:
        """Merge two merge trees, as `mergeMergeTrees`.

        Args:
            left: A node, or -1.
            right: A node, or -1.

        Returns:
            The merged node, or -1.
        """
        if self.is_empty(right):
            return left
        if self.is_empty(left):
            return right
        var merged = self.new_tree()
        var info = self.tree[right].info.copy()
        if not info:
            info = self.tree[left].info.copy()
        self.tree[merged].info = info^
        var left_keys = self.tree[left].keys.copy()
        var left_children = self.tree[left].children.copy()
        var right_keys = self.tree[right].keys.copy()
        var right_children = self.tree[right].children.copy()
        var index = 0
        while index < len(left_keys):
            var other = _find_key(right_keys, right_children, left_keys[index])
            var child = self.merge_trees(left_children[index], other)
            self.tree[merged].keys.append(left_keys[index])
            self.tree[merged].children.append(child)
            index += 1
        index = 0
        while index < len(right_keys):
            if _find_key(left_keys, left_children, right_keys[index]) < 0:
                self.tree[merged].keys.append(right_keys[index])
                self.tree[merged].children.append(right_children[index])
            index += 1
        return merged


def _find_key(keys: List[Int], children: List[Int], key: Int) -> Int:
    """Return the child with a key, or -1."""
    var index = 0
    while index < len(keys):
        if keys[index] == key:
            return children[index]
        index += 1
    return -1


def write_to_store(
    mut cache: InMemoryCache,
    query: Document,
    data: JsonDocument,
    data_id: String,
    variables: JsonDocument,
    overwrite: Bool,
) raises -> String:
    """Write a result into the store, as `StoreWriter.writeToStore`.

    Args:
        cache: The cache.
        query: The query, with an operation.
        data: The result; its root is the object of `data_id`.
        data_id: The entity to write, or empty to identify the result.
        variables: The variables object, or an empty document.
        overwrite: Whether merge functions get no existing value.

    Returns:
        The id that the result was written to.

    Raises:
        Error: For the upstream invariant errors.
    """
    var operation = get_operation_definition(query)
    if operation == NO_AST_NODE:
        raise Error("Must contain a query definition.")
    var members = get_default_values(query, operation, cache.values)
    var given = cache.values.from_json(variables, variables.root)
    var count = cache.values.length(given) if cache.values.is_object(
        given
    ) else 0
    var index = 0
    while index < count:
        var name = Int32(cache.values.member_name(given, index))
        var value = Int32(cache.values.member_value(given, index))
        var position = member_index(members, Int(name))
        if position < 0:
            members.append(Member(name, value))
        else:
            members[position].value = value
        index += 1
    var context = WriteContext(
        cache.values.add_object(members),
        fragment_map(query),
        overwrite,
        len(cache.policies.fuzzy_names) > 0,
        len(query.nodes),
    )
    _ = cache.take_pending()
    var root = context.new_tree()
    var result = process_selection_set(
        cache,
        context,
        query,
        data,
        data_id,
        data.root,
        query.child(operation, Role.SELECTION_SET),
        root,
    )
    if not cache.values.is_reference(result):
        var shown = String("{}")
        if data.root != NO_NODE:
            shown = _display_json(data, data.root)
        _ = cache.take_pending()
        raise Error(String("Could not identify object ", shown))
    var reference = String(cache.values.ref_text(result))
    var entries = cache.take_pending()
    # The root object is an entity, so there is at least one entry.
    var position = 0
    while position < len(entries):
        ref entry = entries[position]
        position += 1
        var fields = List[Member]()
        swap(fields, entry.members)
        if not context.is_empty(entry.merge_tree):
            var entity = cache.values.add_reference_to(entry.id)
            var object = cache.values.add_object(fields)
            var applied = apply_merges(
                cache, context, query, entry.merge_tree, entity, object
            )
            if cache.values.is_reference(applied):
                continue
            fields = cache.values.members(applied)
        cache.merge_entity(entry.id, fields^)
    _ = cache.store.retain(reference)
    return reference^


def _display_json(data: JsonDocument, node: Int) -> String:
    """Return a JSON value as an upstream error message shows it."""
    var text = stringify(data, node, 2)
    if text.byte_length() <= 1000:
        return text^
    var cut = 1000
    while text.as_bytes()[cut] & 0xC0 == 0x80:
        cut -= 1
    return String(text[byte=:cut])


def _member(data: JsonDocument, object: Int, key: StringSlice) -> Int:
    """Return the member of a result object with a key, or `NO_NODE`."""
    if object == NO_NODE or data.kind(object) != JsonKind.OBJECT:
        return NO_NODE
    return data.find(object, key)


def compile_set(
    mut context: WriteContext, document: Document, selection_set: Int
) -> Int:
    """Return the compiled form of a selection set, made once per write.

    Args:
        context: The write.
        document: The document.
        selection_set: The `SelectionSet` node.

    Returns:
        The index in `context.sets`.
    """
    return compile_into(context.compiled, context.sets, document, selection_set)


def compile_into(
    mut compiled: List[Int32],
    mut sets: List[Compiled],
    document: Document,
    selection_set: Int,
) -> Int:
    """Return the compiled form of a selection set, made once.

    Args:
        compiled: Each selection set node and its entry in `sets`.
        sets: The compiled selection sets.
        document: The document.
        selection_set: The `SelectionSet` node.

    Returns:
        The index in `sets`.
    """
    var found = Int(compiled[selection_set])
    if found >= 0:
        return found
    var out = Compiled()
    var node = document.first_child(selection_set)
    while node != NO_AST_NODE:
        var selection = Selection(document, node)
        if (
            selection.kind == Kind.FIELD
            and not out.has_typename_field
            and selection.name == "__typename"
        ):
            out.has_typename_field = True
            out.typename_key = selection.key
        out.selections.append(selection^)
        node = document.next_sibling(node)
    var index = len(sets)
    sets.append(out^)
    compiled[selection_set] = Int32(index)
    return index


def typename_from_result(
    mut context: WriteContext,
    document: Document,
    data: JsonDocument,
    result: Int,
    selection_set: Int,
) raises -> String:
    """Return the type of a result object, as `getTypenameFromResult`.

    Args:
        context: The write.
        document: The document.
        data: The result document.
        result: The result object.
        selection_set: The selection set that wrote it.

    Returns:
        The type name, or empty when it is not a string.

    Raises:
        Error: If a fragment spread names no fragment.
    """
    var set = compile_set(context, document, selection_set)
    if context.sets[set].has_typename_field:
        return _string_member(data, result, context.sets[set].typename_key)
    var direct = _string_member(data, result, "__typename")
    if direct.byte_length() > 0:
        return direct^
    var count = len(context.sets[set].selections)
    var index = 0
    while index < count:
        if context.sets[set].selections[index].kind != Kind.FIELD:
            var fragment = _fragment_set(
                context, document, context.sets[set].selections[index].node
            )
            var inner = typename_from_result(
                context, document, data, result, fragment
            )
            if inner.byte_length() > 0:
                return inner^
        index += 1
    return ""


def _string_member(data: JsonDocument, object: Int, key: StringSlice) -> String:
    """Return a string member of a result object, or empty."""
    var found = _member(data, object, key)
    if found != NO_NODE and data.kind(found) == JsonKind.STRING:
        return data.string_value(found)
    return ""


def _fragment_set(
    mut context: WriteContext, document: Document, selection: Int
) raises -> Int:
    """Return the selection set of an inline fragment or of the fragment
    that a spread names, as `getFragmentFromSelection`."""
    return document.child(
        _fragment_node(context, document, selection), Role.SELECTION_SET
    )


def _fragment_node(
    mut context: WriteContext, document: Document, selection: Int
) raises -> Int:
    """Return the inline fragment, or the definition a spread names."""
    if document.kind(selection) == Kind.INLINE_FRAGMENT:
        return selection
    var name = String(document.name(selection))
    var definition = context.fragments.get(name, NO_AST_NODE)
    if definition == NO_AST_NODE:
        raise Error(String("No fragment named ", name))
    return definition


def fragment_matches(
    mut cache: InMemoryCache,
    document: Document,
    fragment: Int,
    typename: StringSlice,
    data: JsonDocument,
    result: Int,
    variables: Int,
) raises -> Bool:
    """Return True when a fragment applies to a result object, as
    `Policies.fragmentMatches` with a result.

    Args:
        cache: The cache.
        document: The document.
        fragment: An `InlineFragment` or `FragmentDefinition` node.
        typename: The object's type, or empty.
        data: The result document.
        result: The result object, or `NO_NODE` for none.
        variables: The variables object.

    Returns:
        Whether the fragment's fields apply.

    Raises:
        Error: If a policy cannot apply, or `@skip` or `@include` is not
            valid.
    """
    var condition = document.child(fragment, Role.TYPE_CONDITION)
    if condition == NO_AST_NODE:
        return True
    if typename.byte_length() == 0:
        return False
    var matches = False
    if result != NO_NODE and len(cache.policies.fuzzy_names) > 0:
        matches = selection_set_matches_result(
            cache,
            document,
            document.child(fragment, Role.SELECTION_SET),
            data,
            result,
            variables,
        )
    return cache.policies.fragment_matches(
        document.name(condition), typename, matches
    )


def selection_set_matches_result(
    mut cache: InMemoryCache,
    document: Document,
    selection_set: Int,
    data: JsonDocument,
    result: Int,
    variables: Int,
) raises -> Bool:
    """Return True when a result has every field of a selection set.

    Port of `selectionSetMatchesResult`.

    Args:
        cache: The cache.
        document: The document.
        selection_set: The selection set.
        data: The result document.
        result: The result value.
        variables: The variables object.

    Returns:
        Whether every included field is in the result, deeply; an array
        matches when every item matches.

    Raises:
        Error: If `@skip` or `@include` is not valid.
    """
    var kind = data.kind(result)
    if kind == JsonKind.ARRAY:
        var item = data.first(result)
        while item != NO_NODE:
            if not selection_set_matches_result(
                cache, document, selection_set, data, item, variables
            ):
                return False
            item = data.next(item)
        return True
    if kind != JsonKind.OBJECT:
        return False
    var selection = document.first_child(selection_set)
    while selection != NO_AST_NODE:
        if document.kind(selection) == Kind.FIELD and should_include(
            document, selection, cache.values, variables
        ):
            var found = _member(
                data, result, result_key_name(document, selection)
            )
            if found == NO_NODE:
                return False
            var inner = document.child(selection, Role.SELECTION_SET)
            if inner != NO_AST_NODE and not selection_set_matches_result(
                cache, document, inner, data, found, variables
            ):
                return False
        selection = document.next_sibling(selection)
    return True


def flatten_fields(
    mut cache: InMemoryCache,
    mut context: WriteContext,
    document: Document,
    data: JsonDocument,
    selection_set: Int,
    result: Int,
    typename: String,
) raises -> Int:
    """Collect the fields of a selection set, as `flattenFields`.

    The fields of each matching fragment come in at the fragment's place.
    A field node is collected once. The result for one type is kept, so
    the next object of that type does not collect again, unless fuzzy
    subtypes make the match depend on the object.

    Args:
        cache: The cache.
        context: The write.
        document: The document.
        data: The result document.
        selection_set: The selection set.
        result: The result object.
        typename: The object's type, or empty.

    Returns:
        The entry of `context.field_lists` that holds the field nodes, in
        order. The entry does not change later.

    Raises:
        Error: If a spread names no fragment, or a directive is not valid.
    """
    var set = compile_set(context, document, selection_set)
    if (
        context.sets[set].memo_valid
        and not context.fuzzy
        and context.sets[set].memo_typename == typename
    ):
        return context.sets[set].memo_list
    var fields = List[Int]()
    var visited = List[Int]()
    _flatten(
        cache,
        context,
        document,
        data,
        selection_set,
        result,
        typename,
        fields,
        visited,
    )
    context.field_lists.append(fields^)
    context.sets[set].memo_list = len(context.field_lists) - 1
    context.sets[set].memo_typename = typename
    context.sets[set].memo_valid = True
    return context.sets[set].memo_list


def _flatten(
    mut cache: InMemoryCache,
    mut context: WriteContext,
    document: Document,
    data: JsonDocument,
    selection_set: Int,
    result: Int,
    typename: String,
    mut fields: List[Int],
    mut visited: List[Int],
) raises:
    """Add the fields of one selection set, after the visited check."""
    var index = 0
    while index < len(visited):
        if visited[index] == selection_set:
            return
        index += 1
    visited.append(selection_set)
    var set = compile_set(context, document, selection_set)
    var count = len(context.sets[set].selections)
    var position = 0
    while position < count:
        var node = context.sets[set].selections[position].node
        var kind = context.sets[set].selections[position].kind
        position += 1
        if context.sets[set].selections[
            position - 1
        ].has_directives and not should_include(
            document, node, cache.values, context.variables
        ):
            continue
        if kind == Kind.FIELD:
            # A selection set is flattened once, so a field node comes once.
            fields.append(node)
            continue
        var fragment = _fragment_node(context, document, node)
        if fragment_matches(
            cache, document, fragment, typename, data, result, context.variables
        ):
            _flatten(
                cache,
                context,
                document,
                data,
                document.child(fragment, Role.SELECTION_SET),
                result,
                typename,
                fields,
                visited,
            )


def ready_field(mut context: WriteContext, document: Document, field: Int):
    """Fill the texts of a field's memo, once per write.

    Args:
        context: The write.
        document: The document.
        field: The `Field` node.
    """
    if context.field_memo[field].ready:
        return
    ref memo = context.field_memo[field]
    memo.field_name = String(document.name(field))
    memo.key = result_key_name(document, field)
    memo.selection_set = document.child(field, Role.SELECTION_SET)
    memo.ready = True


def field_store_name(
    mut cache: InMemoryCache,
    mut context: WriteContext,
    document: Document,
    field: Int,
    typename: String,
) raises -> Int:
    """Return the interned store field name of a field in a type.

    The name is kept for the last type, since every object of a list
    usually has the same type.

    Args:
        cache: The cache.
        context: The write.
        document: The document.
        field: A `Field` node whose memo `ready_field` filled.
        typename: The parent type, or empty.

    Returns:
        The interned store field name.

    Raises:
        Error: If an argument is not a value literal or a key function
            raises.
    """
    if (
        context.field_memo[field].valid
        and context.field_memo[field].typename == typename
    ):
        return context.field_memo[field].name
    var text = cache.store_field_name(
        typename,
        context.field_memo[field].field_name,
        document,
        field,
        context.variables,
        NO_VALUE,
        False,
    )
    ref memo = context.field_memo[field]
    memo.name = cache.values.names.intern(text)
    memo.typename = typename
    memo.valid = True
    return memo.name


def get_merge_info(
    mut cache: InMemoryCache,
    field: Int,
    typename: String,
    field_name: String,
    child_typename: String,
) raises -> Optional[MergeInfo]:
    """Return the merge function of a field, as `getMergeFunction`.

    The field's policy comes first, then the type policy of the child.

    Args:
        cache: The cache.
        field: The `Field` node.
        typename: The parent type, or empty.
        field_name: The field name.
        child_typename: The child object's type, or empty.

    Returns:
        The merge info, or None.

    Raises:
        Error: If a type policy cannot apply.
    """
    var policy = cache.policies.get_field_policy(typename, field_name)
    if (
        policy >= 0
        and cache.policies.fields[policy].merge_mode != MergeMode.UNSET
    ):
        return MergeInfo(
            field,
            typename,
            cache.policies.fields[policy].merge_mode,
            cache.policies.fields[policy].merge_function,
        )
    if child_typename.byte_length() > 0:
        var type_policy = cache.policies.get_type_policy(child_typename)
        ref found = cache.policies.types[type_policy]
        if found.merge_mode != MergeMode.UNSET:
            return MergeInfo(
                field, typename, found.merge_mode, found.merge_function
            )
    return None


def process_selection_set(
    mut cache: InMemoryCache,
    mut context: WriteContext,
    document: Document,
    data: JsonDocument,
    data_id: String,
    result: Int,
    selection_set: Int,
    tree: Int,
) raises -> Int:
    """Write one result object, as `StoreWriter.processSelectionSet`.

    Args:
        cache: The cache.
        context: The write.
        document: The document.
        data: The result document.
        data_id: The object's entity id, or empty.
        result: The result object, or `NO_NODE` for `{}`.
        selection_set: The selection set.
        tree: The merge tree of this object.

    Returns:
        A `Reference` to the entity, or the object itself when it has no
        id.

    Raises:
        Error: For a missing fragment, a missing key field, or a policy
            function that raises.
    """
    var typename = String("")
    if data_id.byte_length() > 0:
        typename = cache.policies.root_typenames_by_id.get(data_id, String(""))
    if typename.byte_length() == 0:
        typename = typename_from_result(
            context, document, data, result, selection_set
        )
    if typename.byte_length() == 0 and data_id.byte_length() > 0:
        var slot = cache.values.ids.find(data_id)
        if slot >= 0:
            var stored = cache.get(slot, TYPENAME)
            if cache.values.kind(stored) == ValueKind.STRING:
                typename = String(cache.values.text(stored))
    var start = len(context.stack)
    if typename.byte_length() > 0:
        context.stack.append(
            Member(Int32(TYPENAME), Int32(cache.values.add_string(typename)))
        )
    var fields = flatten_fields(
        cache, context, document, data, selection_set, result, typename
    )
    var merges = cache.policies.has_merges
    var count = len(context.field_lists[fields])
    var position = 0
    while position < count:
        var field = context.field_lists[fields][position]
        position += 1
        ready_field(context, document, field)
        var value = _member(data, result, context.field_memo[field].key)
        if value == NO_NODE:
            continue
        var store_name = field_store_name(
            cache, context, document, field, typename
        )
        var subselection = context.field_memo[field].selection_set
        var child = -1
        if merges:
            child = context.child_tree(tree, store_name)
        var stored = process_field_value(
            cache, context, document, data, value, subselection, child
        )
        if merges:
            var child_typename = String("")
            if subselection != NO_AST_NODE and (
                cache.values.is_reference(stored)
                or cache.values.is_object(stored)
            ):
                var found = cache._pending_field(stored, TYPENAME)
                if cache.values.kind(found) == ValueKind.STRING:
                    child_typename = String(cache.values.text(found))
            var name = context.field_memo[field].field_name
            var info = get_merge_info(
                cache, field, typename, name, child_typename
            )
            if info:
                context.tree[child].info = info^
            else:
                context.recycle(tree, store_name)
        _merge_member(cache, context.stack, start, store_name, stored)
    var id = String("")
    var key_name = -1
    var key_value = NO_VALUE
    try:
        if typename == cache.policies.query_typename:
            id = "ROOT_QUERY"
        elif _uses_default_id(cache, context, typename):
            var found = _default_id(cache, data, result, context.stack, start)
            id = found.id
            key_name = found.key_name
            key_value = found.key_value
        else:
            var incoming = _slice(context.stack, start)
            var merged = _merged_object(cache, data, result, incoming)
            var store_object = cache.values.add_object(incoming)
            var identity = cache.identify_object(
                merged, store_object, typename, True
            )
            id = identity.id
            var size = cache.values.length(identity.key_object)
            var index = 0
            while index < size:
                _merge_member(
                    cache,
                    context.stack,
                    start,
                    cache.values.member_name(identity.key_object, index),
                    cache.values.member_value(identity.key_object, index),
                )
                index += 1
    except e:
        if data_id.byte_length() == 0:
            context.stack.resize(start, Member(0, 0))
            raise e^
    if key_name >= 0:
        _merge_member(cache, context.stack, start, key_name, key_value)
    var final_id = data_id if data_id.byte_length() > 0 else id
    if final_id.byte_length() == 0:
        var object = cache.values.add_members(Span(context.stack)[start:])
        context.stack.resize(start, Member(0, 0))
        return object
    var slot = cache.values.ids.intern(final_id)
    var entry = cache.pending_entry(slot)
    if entry < 0:
        var created = Incoming(slot)
        created.members = _slice(context.stack, start)
        context.stack.resize(start, Member(0, 0))
        created.written.append(selection_set)
        created.merge_tree = -1 if context.is_empty(tree) else tree
        cache.set_pending_entry(slot, len(cache.incoming))
        cache.incoming.append(created^)
        return cache.values.add_reference_to(slot)
    var seen = 0
    while seen < len(cache.incoming[entry].written):
        if cache.incoming[entry].written[seen] == selection_set:
            context.stack.resize(start, Member(0, 0))
            return cache.values.add_reference_to(slot)
        seen += 1
    cache.incoming[entry].written.append(selection_set)
    var merged = List[Member]()
    swap(merged, cache.incoming[entry].members)
    var index = start
    while index < len(context.stack):
        _merge_member(
            cache,
            merged,
            0,
            Int(context.stack[index].name),
            Int(context.stack[index].value),
        )
        index += 1
    swap(merged, cache.incoming[entry].members)
    context.stack.resize(start, Member(0, 0))
    cache.incoming[entry].merge_tree = context.merge_trees(
        cache.incoming[entry].merge_tree, -1 if context.is_empty(tree) else tree
    )
    return cache.values.add_reference_to(slot)


def _slice(members: List[Member], start: Int) -> List[Member]:
    """Return a copy of the members of a stack from a position."""
    var out = List[Member](capacity=len(members) - start)
    out.extend(Span(members)[start:])
    return out^


def _merge_member(
    mut cache: InMemoryCache,
    mut members: List[Member],
    start: Int,
    name: Int,
    value: Int,
):
    """Merge one field into incoming fields, as `context.merge` does.

    The fields are the entries of `members` from `start` on.
    """
    var position = start
    while position < len(members):
        if Int(members[position].name) == name:
            var existing = Int(members[position].value)
            if existing != value:
                members[position].value = Int32(
                    cache.values.merge(existing, value)
                )
            return
        position += 1
    members.append(Member(Int32(name), Int32(value)))


@fieldwise_init
struct DefaultId(Movable):
    """The id that `defaultDataIdFromObject` gives, and its key field."""

    var id: String
    """The id, or empty."""
    var key_name: Int
    """The interned key, `id` or `_id`, or -1."""
    var key_value: Int
    """The key's value."""


def _uses_default_id(
    mut cache: InMemoryCache, mut context: WriteContext, typename: String
) raises -> Bool:
    """Return True when a type is identified by the default
    `dataIdFromObject`, with the answer kept for the last type."""
    if context.key_valid and context.key_typename == typename:
        return context.key_default
    var mode = KeyMode.UNSET
    if typename.byte_length() > 0:
        var policy = cache.policies.get_type_policy(typename)
        mode = cache.policies.types[policy].key_mode
    context.key_default = (
        mode == KeyMode.UNSET and not cache.policies.data_id_from_object
    )
    context.key_typename = typename
    context.key_valid = True
    return context.key_default


def _object_field(
    mut cache: InMemoryCache,
    data: JsonDocument,
    result: Int,
    incoming: List[Member],
    start: Int,
    name: Int,
    key: StringSlice,
) -> Int:
    """Return a field of `{...result, ...incoming}`, by its interned name
    and its text."""
    var position = start
    while position < len(incoming):
        if Int(incoming[position].name) == name:
            return Int(incoming[position].value)
        position += 1
    return cache.values.from_json(data, _member(data, result, key))


def _default_id(
    mut cache: InMemoryCache,
    data: JsonDocument,
    result: Int,
    incoming: List[Member],
    start: Int,
) -> DefaultId:
    """Return the id of `defaultDataIdFromObject` without making the
    merged object."""
    var typename = _object_field(
        cache, data, result, incoming, start, TYPENAME, "__typename"
    )
    if cache.values.kind(typename) != ValueKind.STRING:
        return DefaultId("", -1, NO_VALUE)
    var key = ID_NAME
    var value = _object_field(
        cache, data, result, incoming, start, ID_NAME, "id"
    )
    if _nullish(cache, value):
        key = UNDERSCORE_ID_NAME
        value = _object_field(
            cache, data, result, incoming, start, UNDERSCORE_ID_NAME, "_id"
        )
    if _nullish(cache, value):
        return DefaultId("", -1, NO_VALUE)
    var kind = cache.values.kind(value)
    var id = String(cache.values.text(typename), ":")
    if kind == ValueKind.NUMBER or kind == ValueKind.STRING:
        id += cache.values.text(value)
    else:
        id += cache.values.stringify(value)
    return DefaultId(id^, key, value)


def _nullish(cache: InMemoryCache, value: Int) -> Bool:
    """Return True for `null` and `undefined`."""
    var kind = cache.values.kind(value)
    return kind == ValueKind.NULL or kind == ValueKind.UNDEFINED


def _merged_object(
    mut cache: InMemoryCache,
    data: JsonDocument,
    result: Int,
    incoming: List[Member],
) -> Int:
    """Return `{...result, ...incoming}` as an object of the arena."""
    var raw = NO_VALUE
    if result != NO_NODE and data.kind(result) == JsonKind.OBJECT:
        raw = cache.values.from_json(data, result)
    var members = cache.values.members(raw)
    for ref member in incoming:
        var position = member_index(members, Int(member.name))
        if position < 0:
            members.append(member)
        else:
            members[position].value = member.value
    return cache.values.add_object(members)


def process_field_value(
    mut cache: InMemoryCache,
    mut context: WriteContext,
    document: Document,
    data: JsonDocument,
    value: Int,
    selection_set: Int,
    tree: Int,
) raises -> Int:
    """Write the value of one field, as `StoreWriter.processFieldValue`.

    Args:
        cache: The cache.
        context: The write.
        document: The document.
        data: The result document.
        value: The field's value in the result.
        selection_set: The field's selection set, or `NO_NODE`.
        tree: The merge tree of the value.

    Returns:
        The value to store.

    Raises:
        Error: For the errors of `process_selection_set`.
    """
    var kind = data.kind(value)
    if selection_set == NO_AST_NODE or kind == JsonKind.NULL:
        return cache.values.from_json(data, value)
    if kind == JsonKind.ARRAY:
        var items = List[Int]()
        var item = data.first(value)
        var index = 0
        while item != NO_NODE:
            var key = -1 - index
            var child = -1
            if tree >= 0:
                child = context.child_tree(tree, key)
            items.append(
                process_field_value(
                    cache, context, document, data, item, selection_set, child
                )
            )
            if tree >= 0:
                context.recycle(tree, key)
            item = data.next(item)
            index += 1
        return cache.values.add_array(items)
    return process_selection_set(
        cache, context, document, data, "", value, selection_set, tree
    )


def _tree_value(mut cache: InMemoryCache, from_object: Int, key: Int) -> Int:
    """Return the value at a merge tree key, as the `getValue` of
    `applyMerges`.

    A position key (below 0) of an array is in range: the tree took its
    keys from that array. A position of any other value is `undefined`, as
    a store object has no field named by a number.
    """
    if key >= 0:
        return cache.get_field_value(from_object, key)
    if cache.values.is_array(from_object):
        return cache.values.item(from_object, -1 - key)
    return NO_VALUE


def apply_merges(
    mut cache: InMemoryCache,
    mut context: WriteContext,
    document: Document,
    tree: Int,
    existing: Int,
    incoming: Int,
) raises -> Int:
    """Run the merge functions of a merge tree, as `applyMerges`.

    Args:
        cache: The cache.
        context: The write.
        document: The document.
        tree: The merge tree.
        existing: The stored value, or `NO_VALUE`.
        incoming: The incoming value.

    Returns:
        The value to store.

    Raises:
        Error: If a merge function raises.
    """
    var result = incoming
    var keys = context.tree[tree].keys.copy()
    if len(keys) > 0 and not cache.values.is_reference(incoming):
        var base = NO_VALUE
        if not cache.values.is_array(incoming) and (
            cache.values.is_reference(existing)
            or cache.values.is_object(existing)
        ):
            base = existing
        var children = context.tree[tree].children.copy()
        var changed_keys = List[Int]()
        var changed_values = List[Int]()
        var index = 0
        while index < len(keys):
            # The tree took its keys from the incoming value, so each key
            # has a value there.
            var incoming_value = _tree_value(cache, incoming, keys[index])
            var applied = apply_merges(
                cache,
                context,
                document,
                children[index],
                _tree_value(cache, base, keys[index]),
                incoming_value,
            )
            if applied != incoming_value:
                changed_keys.append(keys[index])
                changed_values.append(applied)
            index += 1
        if len(changed_keys) > 0:
            result = _replace(cache, incoming, changed_keys, changed_values)
    if context.tree[tree].info:
        var info = context.tree[tree].info.value().copy()
        return run_merge_function(
            cache, context, document, existing, result, info
        )
    return result


def _replace(
    mut cache: InMemoryCache,
    value: Int,
    keys: List[Int],
    replacements: List[Int],
) -> Int:
    """Return a copy of an array or an object with some entries replaced."""
    if cache.values.is_array(value):
        var items = cache.values.array_items(value)
        var index = 0
        while index < len(keys):
            items[-1 - keys[index]] = replacements[index]
            index += 1
        return cache.values.add_array(items)
    var members = cache.values.members(value)
    var index = 0
    while index < len(keys):
        var name = keys[index]
        members[member_index(members, name)].value = Int32(replacements[index])
        index += 1
    return cache.values.add_object(members)


def run_merge_function(
    mut cache: InMemoryCache,
    context: WriteContext,
    document: Document,
    existing: Int,
    incoming: Int,
    info: MergeInfo,
) raises -> Int:
    """Run one merge function, as `Policies.runMergeFunction`.

    `merge: true` merges with `mergeObjects`, and `merge: false` keeps the
    incoming value. With `overwrite`, a function gets no existing value.

    Args:
        cache: The cache.
        context: The write.
        document: The document.
        existing: The stored value, or `NO_VALUE`.
        incoming: The incoming value.
        info: The field and its merge function.

    Returns:
        The value to store.

    Raises:
        Error: If the merge function raises.
    """
    if info.mode == MergeMode.TRUE:
        return cache.merge_objects(existing, incoming)
    if info.mode == MergeMode.FALSE:
        return incoming
    var current = NO_VALUE if context.overwrite else existing
    var store_name = cache.store_field_name(
        info.typename,
        document.name(info.field),
        document,
        info.field,
        context.variables,
        NO_VALUE,
        False,
    )
    var options = FieldFunctionOptions(
        cache._pointer(),
        cache.field_args(document, info.field, context.variables),
        field_name_from_store_name(store_name),
        store_name,
        context.variables,
        NO_VALUE,
    )
    var function = info.function.value()
    return function(current, incoming, options)
