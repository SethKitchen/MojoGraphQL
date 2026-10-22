# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The normalized cache: `InMemoryCache`.

Port of Apollo Client 4.3.3 `src/cache/inmemory/inMemoryCache.ts`, of the
`ApolloCache` methods of `src/cache/core/cache.ts` that it uses, and of the
parts of `policies.ts` and `entityStore.ts` that read the store:
`identify`, `readField`, `getStoreFieldName`, `runMergeFunction`,
`modify`, `evict`, `gc` and `extract`.

A query is a `gql_language` `Document`. Data and variables are `gql_json`
`JsonDocument`s. A value that a policy function gets or gives is an index
into `InMemoryCache.values`.

Differences from upstream:

- There is no result cache and there are no watches: `watch`,
  `broadcastWatches`, `batch` and the `optimism` dependencies are not
  ported. `resultCaching` has no effect. A read builds a new result.
- The methods take their options as arguments, not as one options object.
- `extract` returns the JSON text of `JSON.stringify(cache.extract())`.
- Custom scalars (`scalars`, `Scalar`) and the incremental reads of `diff`
  (`handleIncrementalSymbol`) are not ported.
- `write_query` takes the stream information of an incremental request as
  the argument `stream_info`, not as the `streamInfoSymbol` key of
  `extensions`. The memo of the last stream merge (`previous`) is not
  ported, so a merge function runs for each write.
- Warnings that upstream prints in development, such as the data loss
  warning of `writeToStore`, are not printed.
- The arena of values is compacted when it holds many values that nothing
  uses, at the end of a write, a `modify`, an `evict`, a `gc` or a
  `restore`.
"""

from std.collections import Dict

from gql_json.parser import parse as parse_json
from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_json.writer import JsonWriter
from gql_language.ast import Document, Kind, NO_NODE as NO_AST_NODE, Role
from gql_client.helpers import (
    add_typename_to_document,
    arguments_object_from_field,
    field_name_from_store_name,
    get_fragment_query_document,
    get_store_key_name,
    store_key_name_from_field,
)
from gql_client.key_extractor import (
    KeySpecifier,
    collect_specifier_paths,
    extract_key_path,
    normalize,
)
from gql_client.policies import (
    FieldMergeFunction,
    FieldPolicy,
    FieldReadFunction,
    KeyArgsFunction,
    KeyFieldsFunction,
    KeyMode,
    MergeMode,
    Policies,
    TypePolicy,
)
from gql_client.read import DiffResult, diff_query_against_store
from gql_client.store import (
    EntityStore,
    Entry,
    Layer,
    member_index,
    member_value,
    merge_members,
)
from gql_client.values import (
    Member,
    NO_VALUE,
    NULL_VALUE,
    TYPENAME,
    UNDEFINED_VALUE,
    ValueKind,
    Values,
    utf16_less,
)
from gql_client.incremental import StreamFieldInfo, StreamInfo
from gql_client.write import write_to_store

comptime DELETE = -2
"""The value a modifier returns to delete a field: upstream `DELETE`."""
comptime INVALIDATE = -3
"""The value a modifier returns to keep a field and only invalidate it:
upstream `INVALIDATE`. Without a result cache it changes nothing."""
comptime COMPACT_SLACK = 4096
"""How many values the arena can grow past twice its live size before a
compaction."""

comptime Modifier = def(
    value: Int, mut details: ModifierDetails
) raises thin -> Int
"""A `cache.modify` function: return the new value, `DELETE` or
`INVALIDATE`."""
comptime Transaction = def(mut cache: InMemoryCache) raises thin -> None
"""A `perform_transaction` or `record_optimistic_transaction` callback."""
comptime CachePointer = Pointer[InMemoryCache, MutUntrackedOrigin]
"""A pointer to the cache that a policy function works on."""


struct InMemoryCacheConfig(Copyable, Movable):
    """The options of an `InMemoryCache`: upstream `InMemoryCacheConfig`."""

    var type_policies: Dict[String, TypePolicy]
    """The `typePolicies` option, by type name."""
    var possible_types: Dict[String, List[String]]
    """The `possibleTypes` option: each supertype and its subtypes."""
    var data_id_from_object: Optional[KeyFieldsFunction]
    """The `dataIdFromObject` option, or None for
    `default_data_id_from_object`."""

    def __init__(out self):
        """Make the default options."""
        self.type_policies = Dict[String, TypePolicy]()
        self.possible_types = Dict[String, List[String]]()
        self.data_id_from_object = None


struct KeyFieldsContext(Movable):
    """What a `KeyFieldsFunction` gets: upstream `KeyFieldsContext`."""

    var cache: CachePointer
    """The cache, for its `values`."""
    var typename: String
    """The `__typename` of the object, or empty."""
    var object: Int
    """The object to identify, with the fields that the write has stored."""
    var store_object: Int
    """The fields that the write has stored, as an object."""
    var key_object: Int
    """The key fields that the function used, or `NO_VALUE`. A write stores
    them even when the query does not select them."""

    def __init__(out self, cache: CachePointer, typename: String, object: Int):
        """Make a context for an object.

        Args:
            cache: The cache.
            typename: The object's type, or empty.
            object: The object.
        """
        self.cache = cache
        self.typename = typename
        self.object = object
        self.store_object = object
        self.key_object = NO_VALUE

    def field(self, name: StringSlice) -> Int:
        """Return a member of the object.

        Args:
            name: The key.

        Returns:
            The member's value, or `NO_VALUE`.
        """
        return self.cache[].values.get(self.object, name)

    def read_field(mut self, name: StringSlice) raises -> Int:
        """Read a field of the stored fields, with its read function.

        Args:
            name: The field name.

        Returns:
            The value, or `NO_VALUE`.

        Raises:
            Error: If a read function raises.
        """
        return self.cache[].read_field_by_name(
            name, self.store_object, NO_VALUE
        )


struct KeyArgsContext(Movable):
    """What a `KeyArgsFunction` gets."""

    var cache: CachePointer
    """The cache, for its `values`."""
    var typename: String
    """The type of the parent object."""
    var field_name: String
    """The field name."""
    var variables: Int
    """The variables object, or `NO_VALUE`."""

    def __init__(
        out self,
        cache: CachePointer,
        typename: String,
        field_name: String,
        variables: Int,
    ):
        """Make a context.

        Args:
            cache: The cache.
            typename: The parent type.
            field_name: The field.
            variables: The variables, or `NO_VALUE`.
        """
        self.cache = cache
        self.typename = typename
        self.field_name = field_name
        self.variables = variables


struct FieldFunctionOptions(Movable):
    """What a read or merge function gets: upstream `FieldFunctionOptions`."""

    var cache: CachePointer
    """The cache. Build new values with `cache[].values`."""
    var args: Int
    """The field's arguments object, or `NO_VALUE` (upstream `null`)."""
    var field_name: String
    """The field name."""
    var store_field_name: String
    """The store field name, with the key arguments."""
    var variables: Int
    """The variables object, or `NO_VALUE`."""
    var from_object: Int
    """The object that `read_field` reads by default: the parent object of
    a read function, `NO_VALUE` for a merge function."""
    var extensions: Int
    """The `extensions` of the write, or `NO_VALUE` (upstream
    `undefined`). Only a merge function gets them."""
    var stream_field_info: Optional[StreamFieldInfo]
    """For a merge function of a `@stream` field during a stream, where
    the stream is; None otherwise."""
    var existing_data: Int
    """The existing value of a merge function, also with `overwrite`
    (upstream `existingData`); `NO_VALUE` for a read function."""

    def __init__(
        out self,
        cache: CachePointer,
        args: Int,
        field_name: String,
        store_field_name: String,
        variables: Int,
        from_object: Int,
        extensions: Int = NO_VALUE,
        stream_field_info: Optional[StreamFieldInfo] = None,
        existing_data: Int = NO_VALUE,
    ):
        """Make the options of one call.

        Args:
            cache: The cache.
            args: The arguments object, or `NO_VALUE`.
            field_name: The field name.
            store_field_name: The store field name.
            variables: The variables object, or `NO_VALUE`.
            from_object: The parent object, or `NO_VALUE`.
            extensions: The extensions of the write, or `NO_VALUE`.
            stream_field_info: The stream information, or None.
            existing_data: The existing value, or `NO_VALUE`.
        """
        self.cache = cache
        self.args = args
        self.field_name = field_name
        self.store_field_name = store_field_name
        self.variables = variables
        self.from_object = from_object
        self.extensions = extensions
        self.stream_field_info = stream_field_info
        self.existing_data = existing_data

    def read_field(mut self, name: StringSlice) raises -> Int:
        """Read a field of the parent object, as `options.readField(name)`.

        Args:
            name: The field name.

        Returns:
            The value, or `NO_VALUE`.

        Raises:
            Error: If a read function raises.
        """
        return self.cache[].read_field_by_name(
            name, self.from_object, self.variables
        )

    def read_field_from(
        mut self, name: StringSlice, from_object: Int
    ) raises -> Int:
        """Read a field of an object or a `Reference`.

        Args:
            name: The field name.
            from_object: The object or `Reference`.

        Returns:
            The value, or `NO_VALUE`.

        Raises:
            Error: If a read function raises.
        """
        return self.cache[].read_field_by_name(
            name, from_object, self.variables
        )

    def to_reference(mut self, id: StringSlice) -> Int:
        """Return a `Reference` to an id, as `options.toReference(id)`.

        Args:
            id: The entity id.

        Returns:
            The new `Reference`.
        """
        return self.cache[].values.add_reference(id)

    def is_reference(self, value: Int) -> Bool:
        """Return True for a `Reference`.

        Args:
            value: A value.

        Returns:
            Whether it is a `Reference`.
        """
        return self.cache[].values.is_reference(value)

    def can_read(self, value: Int) -> Bool:
        """Return True when a value can be read, as `options.canRead`.

        Args:
            value: A value.

        Returns:
            For a `Reference`, whether its entity exists; otherwise whether
            the value is an object, an array or `null`.
        """
        return self.cache[].can_read(value)

    def merge_objects(mut self, existing: Int, incoming: Int) raises -> Int:
        """Merge two objects, as `options.mergeObjects`.

        Args:
            existing: The existing value.
            incoming: The incoming value.

        Returns:
            The merged value.

        Raises:
            Error: If a value is an array.
        """
        return self.cache[].merge_objects(existing, incoming)


struct ModifierDetails(Movable):
    """What a `Modifier` gets: upstream `ModifierDetails`."""

    var cache: CachePointer
    """The cache. Build new values with `cache[].values`."""
    var id: String
    """The entity id."""
    var field_name: String
    """The field name."""
    var store_field_name: String
    """The store field name."""

    def __init__(
        out self,
        cache: CachePointer,
        id: String,
        field_name: String,
        store_field_name: String,
    ):
        """Make the details of one field.

        Args:
            cache: The cache.
            id: The entity id.
            field_name: The field name.
            store_field_name: The store field name.
        """
        self.cache = cache
        self.id = id
        self.field_name = field_name
        self.store_field_name = store_field_name

    def read_field(mut self, name: StringSlice) raises -> Int:
        """Read a field of the entity, as `details.readField(name)`.

        Args:
            name: The field name.

        Returns:
            The value, or `NO_VALUE`.

        Raises:
            Error: If a read function raises.
        """
        var entity = self.cache[].values.add_reference(self.id)
        return self.cache[].read_field_by_name(name, entity, NO_VALUE)

    def read_field_from(
        mut self, name: StringSlice, from_object: Int
    ) raises -> Int:
        """Read a field of an object or a `Reference`.

        Args:
            name: The field name.
            from_object: The object or `Reference`.

        Returns:
            The value, or `NO_VALUE`.

        Raises:
            Error: If a read function raises.
        """
        return self.cache[].read_field_by_name(name, from_object, NO_VALUE)

    def to_reference(mut self, id: StringSlice) -> Int:
        """Return a `Reference` to an id.

        Args:
            id: The entity id.

        Returns:
            The new `Reference`.
        """
        return self.cache[].values.add_reference(id)

    def to_reference_object(
        mut self, object: JsonDocument, merge_into_store: Bool
    ) raises -> Int:
        """Return a `Reference` to an object, as `toReference(object, true)`.

        Args:
            object: The object; its root is identified.
            merge_into_store: Whether to write the object's fields into the
                store too.

        Returns:
            The `Reference`, or `NO_VALUE` when the object has no id.

        Raises:
            Error: If the id cannot be computed.
        """
        return self.cache[].to_reference_object(object, merge_into_store)

    def is_reference(self, value: Int) -> Bool:
        """Return True for a `Reference`.

        Args:
            value: A value.

        Returns:
            Whether it is a `Reference`.
        """
        return self.cache[].values.is_reference(value)

    def can_read(self, value: Int) -> Bool:
        """Return True when a value can be read, as `details.canRead`.

        Args:
            value: A value.

        Returns:
            For a `Reference`, whether its entity exists; otherwise whether
            the value is an object, an array or `null`.
        """
        return self.cache[].can_read(value)


def default_data_id_from_object(mut context: KeyFieldsContext) raises -> String:
    """Return the default id of an object: `__typename:id` or `__typename:_id`.

    Port of `defaultDataIdFromObject`. The id is the `id` member, or else
    the `_id` member. A number or a string goes in as its text, and any
    other value as its JSON. The function also sets `context.key_object`
    to `{ id }` or `{ _id }`.

    Args:
        context: The object and its type.

    Returns:
        The id, or `""` when the object has no string `__typename` or no
        id.

    Raises:
        Error: Never; the signature is the one of a `KeyFieldsFunction`.
    """
    ref values = context.cache[].values
    var typename = values.get(context.object, "__typename")
    if values.kind(typename) != ValueKind.STRING:
        return ""
    var id = values.get(context.object, "id")
    var key = "id"
    if _is_nullish(values, id):
        id = values.get(context.object, "_id")
        key = "_id"
    if _is_nullish(values, id):
        context.key_object = NO_VALUE
        return ""
    var members = List[Member]()
    members.append(Member(Int32(values.names.intern(key)), Int32(id)))
    context.key_object = values.add_object(members)
    return String(values.text(typename), ":", id_text(values, id))


def id_text(values: Values, id: Int) -> String:
    """Return the text of an id value in a template string.

    Args:
        values: The arena.
        id: The id value.

    Returns:
        The text of a number or a string, or the JSON of another value.
    """
    var kind = values.kind(id)
    if kind == ValueKind.NUMBER or kind == ValueKind.STRING:
        return String(values.text(id))
    return values.stringify(id)


def _is_nullish(values: Values, value: Int) -> Bool:
    """Return True for `null` and `undefined`: `value == null`."""
    var kind = values.kind(value)
    return kind == ValueKind.NULL or kind == ValueKind.UNDEFINED


@fieldwise_init
struct Identity(Copyable, Movable):
    """What `identify_object` gives: an id and the key object."""

    var id: String
    """The id, or empty for none."""
    var key_object: Int
    """The key fields that the key function used, or `NO_VALUE`."""


struct Incoming(Copyable, Movable):
    """The fields that one write has for one entity: an entry of upstream
    `context.incomingById`."""

    var id: Int
    """The interned entity id."""
    var members: List[Member]
    """The incoming fields."""
    var written: List[Int]
    """The selection sets that wrote the entity, as `context.written`."""
    var merge_tree: Int
    """The root of the entity's merge tree, or -1 for an empty tree."""

    def __init__(out self, id: Int):
        """Make an empty entry.

        Args:
            id: The interned entity id.
        """
        self.id = id
        self.members = List[Member]()
        self.written = List[Int]()
        self.merge_tree = -1


struct InMemoryCache(Movable):
    """The normalized cache: upstream `InMemoryCache`."""

    var values: Values
    """The arena of every stored value."""
    var policies: Policies
    """The type policies, the possible types and the root types."""
    var store: EntityStore
    """The entities."""
    var live: Int
    """The size of the arena after the last compaction."""
    var incoming: List[Incoming]
    """During a write: the fields of each entity that it writes."""
    var incoming_index: List[Int32]
    """During a write: each entity id and its entry in `incoming`."""

    def __init__(
        out self, config: InMemoryCacheConfig = InMemoryCacheConfig()
    ) raises:
        """Make an empty cache.

        Args:
            config: The options.

        Raises:
            Error: If a type policy changes a root type twice, or a
                `possibleTypes` pattern is not supported.
        """
        self.values = Values()
        self.policies = Policies()
        self.store = EntityStore()
        self.live = 0
        self.incoming = List[Incoming]()
        self.incoming_index = List[Int32]()
        self.policies.data_id_from_object = config.data_id_from_object
        self.policies.add_possible_types(config.possible_types)
        self.policies.add_type_policies(config.type_policies)

    def _pointer(mut self) -> CachePointer:
        """Return a pointer to this cache, for a policy function."""
        return Pointer(to=self).unsafe_origin_cast[MutUntrackedOrigin]()

    # --- the store ------------------------------------------------------

    def is_root_id(self, id: StringSlice) -> Bool:
        """Return True for the id of a root type, such as `ROOT_QUERY`.

        Args:
            id: The entity id.

        Returns:
            Whether it is in `rootTypenamesById`.
        """
        return String(id) in self.policies.root_typenames_by_id

    def has(self, id: Int) -> Bool:
        """Return True when an entity exists, as `EntityStore.has`.

        A root id always exists.

        Args:
            id: The interned id.

        Returns:
            Whether the entity can be read.
        """
        return self.store.present(id) or self.is_root_id(
            self.values.ids.text(id)
        )

    def get(mut self, id: Int, name: Int) -> Int:
        """Return a field of an entity, as `EntityStore.get`.

        The `__typename` of a root id that has no `__typename` field is the
        root type name.

        Args:
            id: The interned id.
            name: The interned store field name.

        Returns:
            The value, or `NO_VALUE`.
        """
        if self.store.present(id):
            var found = self.store.get_field(id, name)
            if found != NO_VALUE:
                return found
        if name == TYPENAME:
            var typename = self.policies.root_typenames_by_id.get(
                String(self.values.ids.text(id)), String("")
            )
            if typename.byte_length() > 0:
                return self.values.add_string(typename)
        return NO_VALUE

    def get_field_value(mut self, from_object: Int, name: Int) -> Int:
        """Return a field of an object or a `Reference`.

        Port of `EntityStore.getFieldValue`.

        Args:
            from_object: An object, a `Reference`, or another value.
            name: The interned store field name.

        Returns:
            The value, or `NO_VALUE`.
        """
        if self.values.is_reference(from_object):
            return self.get(self.values.ref_id(from_object), name)
        return self.values.find(from_object, name)

    @always_inline
    def pending_entry(self, id: Int) -> Int:
        """Return the entry of `incoming` that a write has for an entity.

        Args:
            id: The interned entity id.

        Returns:
            The entry's position, or -1.
        """
        if id >= len(self.incoming_index):
            return -1
        return Int(self.incoming_index.unsafe_ptr()[unsafe_offset=id])

    def set_pending_entry(mut self, id: Int, entry: Int):
        """Record the entry of `incoming` of an entity.

        Args:
            id: The interned entity id.
            entry: The entry's position.
        """
        if id >= len(self.incoming_index):
            self.incoming_index.resize(self.values.ids.__len__() + 16, -1)
        self.incoming_index[id] = Int32(entry)

    def take_pending(mut self) -> List[Incoming]:
        """End a write: return its entities and clear `incoming`.

        Returns:
            The entries, in the order the write made them.
        """
        for ref entry in self.incoming:
            self.incoming_index[entry.id] = -1
        var out = List[Incoming]()
        swap(out, self.incoming)
        return out^

    def _pending_field(mut self, from_object: Int, name: Int) -> Int:
        """Return a field as the `readField` of `processSelectionSet` reads
        it: an entity that the write has pending comes first."""
        if self.values.is_reference(from_object):
            var entry = self.pending_entry(self.values.ref_id(from_object))
            if entry >= 0:
                var found = member_value(self.incoming[entry].members, name)
                if found != NO_VALUE:
                    return found
        return self.get_field_value(from_object, name)

    def typename_of(mut self, from_object: Int) -> String:
        """Return the `__typename` of an object or a `Reference`.

        Args:
            from_object: The object or `Reference`.

        Returns:
            The type name, or empty when it is not a string.
        """
        var found = self.get_field_value(from_object, TYPENAME)
        if self.values.kind(found) == ValueKind.STRING:
            return String(self.values.text(found))
        return ""

    def can_read(self, value: Int) -> Bool:
        """Return True when a value can be read, as `EntityStore.canRead`.

        Args:
            value: A value.

        Returns:
            For a `Reference`, whether its entity exists; otherwise whether
            the value is an object, an array or `null`.
        """
        if self.values.is_reference(value):
            return self.has(self.values.ref_id(value))
        var kind = self.values.kind(value)
        return kind == ValueKind.NULL or kind.value >= ValueKind.ARRAY.value

    def merge_entity(mut self, id: Int, var incoming: List[Member]):
        """Merge fields into an entity, as `EntityStore.merge(id, object)`.

        Args:
            id: The interned id.
            incoming: The fields.
        """
        self.store.merge_into(self.values, id, incoming^)

    def merge_objects(mut self, existing: Int, incoming: Int) raises -> Int:
        """Merge two objects, as the upstream `mergeObjects` function.

        Two objects of different types do not merge: the incoming object
        wins. An object merges into the entity of a `Reference`.

        Args:
            existing: The existing value.
            incoming: The incoming value.

        Returns:
            The merged value.

        Raises:
            Error: If a value is an array.
        """
        if self.values.is_array(existing) or self.values.is_array(incoming):
            raise Error("Cannot automatically merge arrays")
        if not (
            self.values.is_non_null_object(existing)
            and self.values.is_non_null_object(incoming)
        ):
            return incoming
        var existing_type = self.typename_of(existing)
        var incoming_type = self.typename_of(incoming)
        if (
            existing_type.byte_length() > 0
            and incoming_type.byte_length() > 0
            and existing_type != incoming_type
        ):
            return incoming
        if self.values.is_reference(existing) and self.values.is_object(
            incoming
        ):
            self.merge_entity(
                self.values.ref_id(existing), self.values.members(incoming)
            )
            return existing
        if not self.values.is_object(existing):
            return incoming
        if self.values.is_reference(incoming):
            var id = self.values.ref_id(incoming)
            if self.has(id):
                var members = self.values.members(existing)
                if self.store.present(id):
                    _ = merge_members(
                        self.values, members, self.store.members_of(id)
                    )
                self.store.add(id, members^)
            return incoming
        var members = self.values.members(existing)
        var count = self.values.length(incoming)
        var index = 0
        while index < count:
            var name = self.values.member_name(incoming, index)
            var value = self.values.member_value(incoming, index)
            var position = member_index(members, name)
            if position < 0:
                members.append(Member(Int32(name), Int32(value)))
            else:
                members[position].value = Int32(value)
            index += 1
        return self.values.add_object(members)

    # --- policies that read the store -------------------------------------

    def store_field_name(
        mut self,
        typename: String,
        field_name: StringSlice,
        document: Document,
        field: Int,
        variables: Int,
        args: Int,
        has_args: Bool,
    ) raises -> String:
        """Return the store field name of a field, as `getStoreFieldName`.

        A `keyArgs` option of the field's policy gives the name. Without
        one, the name has all the arguments and the directives.

        Args:
            typename: The parent type, or empty.
            field_name: The field name.
            document: The document of `field`.
            field: The `Field` node, or `NO_NODE`.
            variables: The variables object, or `NO_VALUE`.
            args: The arguments object, when `has_args` is True.
            has_args: Whether `args` is given; otherwise the arguments come
                from `field`.

        Returns:
            The store field name.

        Raises:
            Error: If an argument is not a value literal, or a policy
                function raises.
        """
        var name = String(field_name)
        var policy = self.policies.get_field_policy(typename, name)
        var arguments = args if has_args else NO_VALUE
        var store_name = String("")
        var found = False
        if policy >= 0:
            var mode = self.policies.fields[policy].key_mode
            if mode != KeyMode.UNSET and not has_args:
                arguments = self.field_args(document, field, variables)
            if mode == KeyMode.FALSE:
                store_name = name
                found = True
            elif mode == KeyMode.SPECIFIER:
                var specifier = self.policies.fields[
                    policy
                ].key_specifier.copy()
                store_name = self._key_args_name(
                    specifier, arguments, document, field, variables, name
                )
                found = True
            elif mode == KeyMode.FUNCTION:
                var function = self.policies.fields[policy].key_function.value()
                var context = KeyArgsContext(
                    self._pointer(), typename, name, variables
                )
                store_name = function(arguments, context)
                if store_name.byte_length() == 0:
                    store_name = name
                found = True
        if not found:
            if field != NO_AST_NODE:
                store_name = store_key_name_from_field(
                    document, field, self.values, variables
                )
            else:
                store_name = get_store_key_name(
                    name, self.values, arguments, NO_VALUE
                )
        if field_name_from_store_name(store_name) == name:
            return store_name^
        return name + ":" + store_name

    def _key_args_name(
        mut self,
        specifier: KeySpecifier,
        args: Int,
        document: Document,
        field: Int,
        variables: Int,
        field_name: String,
    ) raises -> String:
        """Return the store field name of a `keyArgs` specifier, as the
        function of `keyArgsFnFromSpecifier`."""
        var extracted = List[Int]()
        for ref path in specifier.paths:
            extracted.append(
                self._key_arg(path, args, document, field, variables)
            )
        var collected = collect_specifier_paths(
            self.values, specifier.paths, extracted
        )
        var suffix = self.values.stringify(collected)
        if args != NO_VALUE or suffix != "{}":
            return field_name + ":" + suffix
        return field_name

    def _key_arg(
        mut self,
        path: List[String],
        args: Int,
        document: Document,
        field: Int,
        variables: Int,
    ) raises -> Int:
        """Return the value of one `keyArgs` path: an argument, a directive
        argument (`@name`) or a variable (`$name`)."""
        var first = path[0]
        var rest = List[String]()
        var index = 1
        while index < len(path):
            rest.append(path[index])
            index += 1
        if first.startswith("@"):
            if field == NO_AST_NODE:
                return NO_VALUE
            var name = String(first[byte=1:])
            var directive = document.child(field, Role.DIRECTIVE)
            while directive != NO_AST_NODE and document.name(directive) != name:
                directive = document.next_with_role(directive)
            if directive == NO_AST_NODE:
                return NO_VALUE
            var arguments = arguments_object_from_field(
                document, directive, self.values, variables
            )
            if arguments == NO_VALUE:
                return NULL_VALUE
            return extract_key_path(self.values, arguments, rest)
        if first.startswith("$"):
            var name = String(first[byte=1:])
            var value = self.values.get(variables, name)
            if value == NO_VALUE:
                return NO_VALUE
            return extract_key_path(self.values, value, rest)
        if args == NO_VALUE:
            return NO_VALUE
        return extract_key_path(self.values, args, path)

    def read_field(
        mut self,
        field_name: StringSlice,
        document: Document,
        field: Int,
        variables: Int,
        from_object: Int,
        args: Int,
        has_args: Bool,
    ) raises -> Int:
        """Read a field of an object or a `Reference`, as
        `Policies.readField`.

        The field's `read` function, when it has one, gets the stored value
        and gives the value to read.

        Args:
            field_name: The field name.
            document: The document of `field`.
            field: The `Field` node, or `NO_NODE`.
            variables: The variables object, or `NO_VALUE`.
            from_object: The object or `Reference`; `NO_VALUE` reads
                nothing.
            args: The arguments object, when `has_args` is True.
            has_args: Whether `args` is given.

        Returns:
            The value, or `NO_VALUE`.

        Raises:
            Error: If a policy function raises.
        """
        if from_object == NO_VALUE:
            return NO_VALUE
        var type_name = self.typename_of(from_object)
        var store_name = self.store_field_name(
            type_name, field_name, document, field, variables, args, has_args
        )
        var existing = self.get_field_value(
            from_object, self.values.names.intern(store_name)
        )
        return self.apply_read(
            type_name,
            store_name,
            document,
            field,
            variables,
            from_object,
            args,
            has_args,
            existing,
        )

    def apply_read(
        mut self,
        typename: String,
        store_name: String,
        document: Document,
        field: Int,
        variables: Int,
        from_object: Int,
        args: Int,
        has_args: Bool,
        existing: Int,
    ) raises -> Int:
        """Run the `read` function of a field, if it has one.

        Args:
            typename: The parent type, or empty.
            store_name: The store field name.
            document: The document of `field`.
            field: The `Field` node, or `NO_NODE`.
            variables: The variables object, or `NO_VALUE`.
            from_object: The parent object or `Reference`.
            args: The arguments object, when `has_args` is True.
            has_args: Whether `args` is given.
            existing: The stored value, or `NO_VALUE`.

        Returns:
            What the read function gives, or `existing` when there is none.

        Raises:
            Error: If the read function raises.
        """
        var name = field_name_from_store_name(store_name)
        var policy = self.policies.get_field_policy(typename, name)
        if policy < 0 or not self.policies.fields[policy].read:
            return existing
        var read = self.policies.fields[policy].read.value()
        var arguments = args
        if not has_args:
            arguments = self.field_args(document, field, variables)
        var options = FieldFunctionOptions(
            self._pointer(), arguments, name, store_name, variables, from_object
        )
        return read(existing, options)

    def read_field_by_name(
        mut self, field_name: StringSlice, from_object: Int, variables: Int
    ) raises -> Int:
        """Read a field by name, as `readField(fieldName, from)`.

        Args:
            field_name: The field name.
            from_object: The object or `Reference`, or `NO_VALUE`.
            variables: The variables object, or `NO_VALUE`.

        Returns:
            The value, or `NO_VALUE`.

        Raises:
            Error: If a policy function raises.
        """
        var empty = Document()
        return self.read_field(
            field_name,
            empty,
            NO_AST_NODE,
            variables,
            from_object,
            NO_VALUE,
            False,
        )

    def field_args(
        mut self, document: Document, field: Int, variables: Int
    ) raises -> Int:
        """Return the arguments of a field, as `argsFromFieldSpecifier`.

        Args:
            document: The document of `field`.
            field: The `Field` node, or `NO_NODE`.
            variables: The variables object, or `NO_VALUE`.

        Returns:
            The arguments object, or `NO_VALUE` (upstream `null`).

        Raises:
            Error: If an argument is not a value literal.
        """
        if field == NO_AST_NODE:
            return NO_VALUE
        return arguments_object_from_field(
            document, field, self.values, variables
        )

    def identify_object(
        mut self,
        object: Int,
        store_object: Int,
        typename: String,
        pending: Bool,
    ) raises -> Identity:
        """Return the id of an object, as `Policies.identify`.

        Args:
            object: The object, with the stored fields over its own.
            store_object: The stored fields; `object` when they are the same.
            typename: The object's type, or empty to read `__typename`.
            pending: Whether a write is running, so that a `Reference` in
                a key path reads the entity that the write has pending.

        Returns:
            The id, empty for none, and the key object.

        Raises:
            Error: If a key field is missing, or a key function raises.
        """
        var type_name = typename
        if type_name.byte_length() == 0:
            var found = self.values.get(object, "__typename")
            if self.values.kind(found) == ValueKind.STRING:
                type_name = String(self.values.text(found))
        if type_name == self.policies.root_typenames_by_id["ROOT_QUERY"]:
            return Identity("ROOT_QUERY", NO_VALUE)
        var mode = KeyMode.UNSET
        var policy = -1
        if type_name.byte_length() > 0:
            policy = self.policies.get_type_policy(type_name)
            mode = self.policies.types[policy].key_mode
        var context = KeyFieldsContext(self._pointer(), type_name, object)
        context.store_object = store_object
        var id = String("")
        if mode == KeyMode.UNSET:
            if self.policies.data_id_from_object:
                var function = self.policies.data_id_from_object.value()
                id = function(context)
            else:
                id = default_data_id_from_object(context)
        elif mode == KeyMode.SPECIFIER:
            var specifier = self.policies.types[policy].key_specifier.copy()
            id = self._key_fields_id(specifier, context, pending)
        elif mode == KeyMode.FUNCTION:
            var function = self.policies.types[policy].key_function.value()
            id = function(context)
        return Identity(id^, context.key_object)

    def _key_fields_id(
        mut self,
        specifier: KeySpecifier,
        mut context: KeyFieldsContext,
        pending: Bool,
    ) raises -> String:
        """Return the id of a `keyFields` specifier, as the function of
        `keyFieldsFnFromSpecifier`, and set the key object."""
        var extracted = List[Int]()
        for ref path in specifier.paths:
            var value = normalize(
                self.values,
                self._read_key_path(context.store_object, path, 0, pending),
            )
            if (
                value == NO_VALUE
                and context.object != context.store_object
                and self.values.get(context.object, path[0]) != NO_VALUE
            ):
                value = extract_key_path(self.values, context.object, path)
            if value == NO_VALUE:
                raise Error(
                    String(
                        "Missing field '",
                        ".".join(path),
                        "' while extracting keyFields from ",
                        self.values.display(context.object),
                    )
                )
            extracted.append(value)
        context.key_object = collect_specifier_paths(
            self.values, specifier.paths, extracted
        )
        return String(
            context.typename, ":", self.values.stringify(context.key_object)
        )

    def _read_key_path(
        mut self,
        from_object: Int,
        path: List[String],
        start: Int,
        pending: Bool,
    ) raises -> Int:
        """Follow a key path with `readField`; map an array item by item."""
        var current = from_object
        var position = start
        while position < len(path):
            if self.values.is_array(current):
                var items = List[Int]()
                var index = 0
                while index < self.values.length(current):
                    items.append(
                        self._read_key_path(
                            self.values.item(current, index),
                            path,
                            position,
                            pending,
                        )
                    )
                    index += 1
                return self.values.add_array(items)
            if not self.values.truthy(current):
                return current
            current = self._read_key(path[position], current, pending)
            position += 1
        return current

    def _read_key(
        mut self, name: String, from_object: Int, pending: Bool
    ) raises -> Int:
        """Read one key field, as the `readField` of a key function."""
        var empty = Document()
        var typename = self.typename_of(from_object)
        var store_name = self.store_field_name(
            typename, name, empty, NO_AST_NODE, NO_VALUE, NO_VALUE, False
        )
        var interned = self.values.names.intern(store_name)
        var existing: Int
        if pending:
            existing = self._pending_field(from_object, interned)
        else:
            existing = self.get_field_value(from_object, interned)
        return self.apply_read(
            typename,
            store_name,
            empty,
            NO_AST_NODE,
            NO_VALUE,
            from_object,
            NO_VALUE,
            False,
            existing,
        )

    # --- reading and writing ------------------------------------------------

    def write_query(
        mut self,
        query: Document,
        data: JsonDocument,
        variables: JsonDocument = JsonDocument(),
        id: StringSlice = "ROOT_QUERY",
        overwrite: Bool = False,
        extensions: JsonDocument = JsonDocument(),
        stream_info: StreamInfo = StreamInfo(),
        optimistic: Bool = False,
    ) raises -> String:
        """Write the result of a query, as `cache.writeQuery`.

        Merge functions get `extensions`. With the stream information of
        an incremental request, a `@stream` array that has no merge
        function merges with `default_stream_field_merge`, and a merge
        function of a `@stream` field gets `stream_field_info`.

        Args:
            query: The query.
            data: The result data; its root is the object of `id`.
            variables: The variables object, or an empty document.
            id: The entity that the query starts at.
            overwrite: Whether merge functions get no existing value.
            extensions: The extensions of the result, or an empty
                document for `undefined`.
            stream_info: The `stream_info` of the incremental request, or
                an empty trie.
            optimistic: When False (the default outside an optimistic
                transaction), writes go to the root store unless inside
                `record_optimistic_transaction`. When True, writes go to
                the top optimistic layer if one exists.

        Returns:
            The id that the data was written to.

        Raises:
            Error: For the upstream invariant errors, such as a missing
                fragment or a missing key field.
        """
        var saved = self.store.write_to_root
        if not optimistic and self.store._in_optimistic == 0:
            self.store.write_to_root = True
        try:
            var result = write_to_store(
                self,
                query,
                data,
                String(id),
                variables,
                overwrite,
                extensions,
                stream_info,
            )
            self.store.write_to_root = saved
            self._maybe_compact()
            return result^
        except e:
            self.store.write_to_root = saved
            raise e^

    def write_fragment(
        mut self,
        fragment: Document,
        data: JsonDocument,
        id: StringSlice = "",
        fragment_name: StringSlice = "",
        variables: JsonDocument = JsonDocument(),
        overwrite: Bool = False,
        optimistic: Bool = False,
    ) raises -> String:
        """Write the data of a fragment, as `cache.writeFragment`.

        Args:
            fragment: A document of fragment definitions.
            data: The data; its root is the entity's object.
            id: The entity id, or empty to identify `data`.
            fragment_name: The fragment, or empty for the only fragment.
            variables: The variables object, or an empty document.
            overwrite: Whether merge functions get no existing value.
            optimistic: When True, writes to the top optimistic layer if
                one exists.

        Returns:
            The id that the data was written to.

        Raises:
            Error: If the fragment document is not valid for the fragment
                name, or for the upstream write errors.
        """
        var query = get_fragment_query_document(fragment, fragment_name)
        var saved = self.store.write_to_root
        if not optimistic and self.store._in_optimistic == 0:
            self.store.write_to_root = True
        try:
            var result = write_to_store(
                self, query, data, String(id), variables, overwrite
            )
            self.store.write_to_root = saved
            self._maybe_compact()
            return result^
        except e:
            self.store.write_to_root = saved
            raise e^

    def diff(
        mut self,
        query: Document,
        variables: JsonDocument = JsonDocument(),
        id: StringSlice = "ROOT_QUERY",
        return_partial_data: Bool = True,
        optimistic: Bool = True,
    ) raises -> DiffResult:
        """Read a query and tell what is missing, as `cache.diff`.

        Args:
            query: The query.
            variables: The variables object, or an empty document.
            id: The entity that the query starts at.
            return_partial_data: Whether an incomplete result is kept.
            optimistic: Whether to read from the optimistic layers first.

        Returns:
            The result, whether it is complete, and the missing fields.

        Raises:
            Error: For the upstream read errors, such as a missing
                fragment.
        """
        var saved = self.store.write_to_root
        if not optimistic:
            self.store.write_to_root = True
        try:
            var out = diff_query_against_store(
                self, query, variables, String(id), return_partial_data
            )
            self.store.write_to_root = saved
            return out^
        except e:
            self.store.write_to_root = saved
            raise e^

    def read_query(
        mut self,
        query: Document,
        variables: JsonDocument = JsonDocument(),
        id: StringSlice = "ROOT_QUERY",
        return_partial_data: Bool = False,
        optimistic: Bool = True,
    ) raises -> Optional[JsonDocument]:
        """Read a query, as `cache.readQuery`.

        Args:
            query: The query.
            variables: The variables object, or an empty document.
            id: The entity that the query starts at.
            return_partial_data: Whether an incomplete result is kept.
            optimistic: Whether to read from the optimistic layers first.

        Returns:
            The result, or None (upstream `null`) when data is missing.

        Raises:
            Error: For the upstream read errors.
        """
        var result = self.diff(
            query, variables, id, return_partial_data, optimistic
        )
        return result^.take_result()

    def read_fragment(
        mut self,
        fragment: Document,
        id: StringSlice = "",
        fragment_name: StringSlice = "",
        variables: JsonDocument = JsonDocument(),
        return_partial_data: Bool = False,
        optimistic: Bool = True,
    ) raises -> Optional[JsonDocument]:
        """Read a fragment of an entity, as `cache.readFragment`.

        Args:
            fragment: A document of fragment definitions.
            id: The entity id; empty reads from `ROOT_QUERY`.
            fragment_name: The fragment, or empty for the only fragment.
            variables: The variables object, or an empty document.
            return_partial_data: Whether an incomplete result is kept.
            optimistic: Whether to read from the optimistic layers first.

        Returns:
            The result, or None when data is missing.

        Raises:
            Error: If the fragment document is not valid for the fragment
                name, or for the upstream read errors.
        """
        var query = get_fragment_query_document(fragment, fragment_name)
        var root = String(id) if id.byte_length() > 0 else "ROOT_QUERY"
        return self.read_query(
            query, variables, root, return_partial_data, optimistic
        )

    def transform_document(self, document: Document) -> Document:
        """Add `__typename` to a document, as `cache.transformDocument`.

        Args:
            document: The document.

        Returns:
            The document with `__typename` in each selection set but the
            operations'.
        """
        return add_typename_to_document(document)

    def identify(mut self, object: JsonDocument) -> Optional[String]:
        """Return the id of an object, as `cache.identify`.

        Args:
            object: The object, as its root; a `{"__ref": id}` object gives
                its id.

        Returns:
            The id, or None when the object has none or the key function
            fails.
        """
        try:
            var fast = String("")
            if self._json_default_id(object, fast):
                if fast.byte_length() == 0:
                    return None
                return fast^
            var value = self.values.from_json(object, object.root)
            if self.values.is_reference(value):
                return String(self.values.ref_text(value))
            var found = self.identify_object(value, value, "", False)
            if found.id.byte_length() == 0:
                return None
            return String(found.id)
        except:
            return None

    def _json_default_id(
        mut self, object: JsonDocument, mut id: String
    ) raises -> Bool:
        """Compute the default id of a JSON object without copying it.

        This is the common case of `identify`: an object with a string
        `__typename` whose type uses `defaultDataIdFromObject`.

        Args:
            object: The object, as its root.
            id: The id; empty for none.

        Returns:
            False when the general path must decide.

        Raises:
            Error: If a type policy cannot apply.
        """
        var root = object.root
        if object.kind(root) != JsonKind.OBJECT:
            return False
        var typename = object.find(root, "__typename")
        if typename == NO_NODE or object.kind(typename) != JsonKind.STRING:
            return False
        if object.find(root, "__ref") != NO_NODE:
            return False
        var name = object.string_value(typename)
        if name == self.policies.query_typename:
            id = "ROOT_QUERY"
            return True
        if self.policies.data_id_from_object:
            return False
        var policy = self.policies.get_type_policy(name)
        if self.policies.types[policy].key_mode != KeyMode.UNSET:
            return False
        var key = object.find(root, "id")
        if _json_nullish(object, key):
            key = object.find(root, "_id")
        if _json_nullish(object, key):
            id = ""
            return True
        var kind = object.kind(key)
        if kind == JsonKind.STRING:
            id = name + ":" + object.string_value(key)
            return True
        if kind != JsonKind.NUMBER:
            return False
        var number = self.values.from_json(object, key)
        id = name + ":" + String(self.values.text(number))
        return True

    def to_reference_object(
        mut self, object: JsonDocument, merge_into_store: Bool
    ) raises -> Int:
        """Return a `Reference` to an object, as `toReference(object)`.

        Args:
            object: The object, as its root.
            merge_into_store: Whether to merge the object into its entity.

        Returns:
            The `Reference`, or `NO_VALUE` when the object has no id.

        Raises:
            Error: If the key function raises.
        """
        var value = self.values.from_json(object, object.root)
        if self.values.is_reference(value):
            return value
        var found = self.identify_object(value, value, "", False)
        if found.id.byte_length() == 0:
            return NO_VALUE
        var reference = self.values.add_reference(found.id)
        if merge_into_store:
            self.merge_entity(
                self.values.ref_id(reference), self.values.members(value)
            )
        return reference

    # --- changing the store ---------------------------------------------------

    def modify(
        mut self,
        fields: Dict[String, Modifier],
        id: Optional[String] = None,
        all: Optional[Modifier] = None,
        optimistic: Bool = True,
    ) raises -> Bool:
        """Change the fields of an entity, as `cache.modify`.

        Each field whose store field name, or else whose field name, is a
        key of `fields` gets the value that its modifier returns. `all`,
        when it is given, is the modifier of every field.

        Args:
            fields: The modifiers, by store field name or field name.
            id: The entity id; None is `ROOT_QUERY`, and the empty string
                modifies nothing.
            all: One modifier for every field, in place of `fields`.
            optimistic: Whether to modify the top optimistic layer when
                one is active; False modifies the root store.

        Returns:
            Whether a modifier changed a field.

        Raises:
            Error: If a modifier raises.
        """
        var target = String("ROOT_QUERY")
        if id:
            target = id.value()
            if target.byte_length() == 0:
                return False
        var saved = self.store.write_to_root
        if not optimistic:
            self.store.write_to_root = True
        var changed: Bool
        try:
            changed = self._modify(target, fields, all, False, "", False)
        except e:
            self.store.write_to_root = saved
            raise e^
        self.store.write_to_root = saved
        self._maybe_compact()
        return changed

    def _modify(
        mut self,
        id: String,
        fields: Dict[String, Modifier],
        all: Optional[Modifier],
        exact: Bool,
        delete_name: String,
        delete_all: Bool,
    ) raises -> Bool:
        """Apply modifiers or deletions to an entity, as
        `EntityStore.modify`."""
        var slot = self.values.ids.find(id)
        if slot < 0 or not self.store.present(slot):
            return False
        var members = self.store.members_of(slot)
        var changes = List[Member]()
        var all_deleted = True
        for ref member in members:
            var store_name = String(self.values.names.text(Int(member.name)))
            var field_name = field_name_from_store_name(store_name)
            var value = Int(member.value)
            var result = value
            if delete_all or (
                delete_name.byte_length() > 0
                and (
                    store_name == delete_name
                    or (not exact and field_name == delete_name)
                )
            ):
                result = DELETE
            elif all:
                var details = ModifierDetails(
                    self._pointer(), id, field_name, store_name
                )
                result = all.value()(value, details)
            else:
                var modifier = fields.get(store_name)
                if not modifier and not exact:
                    modifier = fields.get(field_name)
                if modifier:
                    var details = ModifierDetails(
                        self._pointer(), id, field_name, store_name
                    )
                    result = modifier.value()(value, details)
            if result == INVALIDATE:
                result = value
            if result == DELETE:
                result = NO_VALUE
            if result != value:
                changes.append(Member(member.name, Int32(result)))
            if result != NO_VALUE:
                all_deleted = False
        if len(changes) == 0:
            return False
        self.merge_entity(slot, changes^)
        if all_deleted:
            self.store.remove(slot)
        return True

    def evict(
        mut self,
        id: Optional[String] = None,
        field_name: String = "",
        args: Optional[JsonDocument] = None,
        optimistic: Bool = True,
    ) raises -> Bool:
        """Remove an entity or some of its fields, as `cache.evict`.

        Args:
            id: The entity id; None is `ROOT_QUERY`, and the empty string
                evicts nothing.
            field_name: The field to remove, or empty for the entity.
            args: The arguments of the one field value to remove; without
                them, every value of the field goes.
            optimistic: Whether to evict from the top optimistic layer
                when one is active; False evicts from the root store.

        Returns:
            Whether something was removed.

        Raises:
            Error: If a key function raises.
        """
        var target = String("ROOT_QUERY")
        if id:
            target = id.value()
            if target.byte_length() == 0:
                return False
        var saved = self.store.write_to_root
        if not optimistic:
            self.store.write_to_root = True
        var slot = self.values.ids.find(target)
        if slot < 0 or not self.store.present(slot):
            self.store.write_to_root = saved
            return False
        var store_name = field_name
        var exact = False
        if field_name.byte_length() > 0 and args:
            exact = True
            ref arguments = args.value()
            var value = self.values.from_json(arguments, arguments.root)
            var empty = Document()
            var reference = self.values.add_reference_to(slot)
            try:
                store_name = self.store_field_name(
                    self.typename_of(reference),
                    field_name,
                    empty,
                    NO_AST_NODE,
                    NO_VALUE,
                    value,
                    True,
                )
            except e:
                self.store.write_to_root = saved
                raise e^
        var evicted: Bool
        try:
            evicted = self._modify(
                target,
                Dict[String, Modifier](),
                None,
                exact,
                store_name,
                store_name.byte_length() == 0,
            )
        except e:
            self.store.write_to_root = saved
            raise e^
        self.store.write_to_root = saved
        self._maybe_compact()
        return evicted

    def retain(mut self, id: String, optimistic: Bool = False) -> Int:
        """Keep an entity from `gc`, as `cache.retain`.

        Args:
            id: The entity id.
            optimistic: Whether to retain in the top optimistic layer
                when one is active.

        Returns:
            The number of holds on the id.
        """
        var saved = self.store.write_to_root
        if not optimistic:
            self.store.write_to_root = True
        var count = self.store.retain(id)
        self.store.write_to_root = saved
        return count

    def release(mut self, id: String, optimistic: Bool = False) -> Int:
        """Remove one hold of `retain`, as `cache.release`.

        Args:
            id: The entity id.
            optimistic: Whether to release from the optimistic layers
                first.

        Returns:
            The number of holds that are left.
        """
        var saved = self.store.write_to_root
        if not optimistic:
            self.store.write_to_root = True
        var count = self.store.release(id)
        self.store.write_to_root = saved
        return count

    def perform_transaction(
        mut self,
        transaction: Transaction,
        optimistic_id: Optional[String] = None,
    ) raises:
        """Run a transaction against the root store or an optimistic
        layer, as `cache.performTransaction`.

        Args:
            transaction: The callback that reads and writes the cache.
            optimistic_id: When set, pushes a new optimistic layer with
                this id while the callback runs; None writes to the root
                store.

        Raises:
            Error: Any error raised by `transaction`.
        """
        var saved = self.store.write_to_root
        if optimistic_id:
            self.store.write_to_root = False
            self.store.push_layer(optimistic_id.value())
            self.store._in_optimistic += 1
        else:
            self.store.write_to_root = True
        try:
            transaction(self)
            if optimistic_id:
                self.store._in_optimistic -= 1
            self.store.write_to_root = saved
        except e:
            if optimistic_id:
                self.store._in_optimistic -= 1
            self.store.write_to_root = saved
            raise e^

    def record_optimistic_transaction(
        mut self, transaction: Transaction, id: String
    ) raises:
        """Record an optimistic transaction in a new layer, as
        `cache.recordOptimisticTransaction`.

        Args:
            transaction: The callback that writes optimistic data.
            id: The transaction id, used later with `remove_optimistic`.

        Raises:
            Error: Any error raised by `transaction`.
        """
        self.perform_transaction(transaction, id)

    def remove_optimistic(mut self, id: String):
        """Remove an optimistic layer by id, as `cache.removeOptimistic`.

        Args:
            id: The transaction id to remove.
        """
        _ = self.store.remove_layer(id)
        self._maybe_compact()

    def root_id_set(self, optimistic: Bool = True) -> List[String]:
        """Return the ids that `gc` keeps, as `EntityStore.getRootIdSet`.

        Args:
            optimistic: Whether to include retained ids from optimistic
                layers.

        Returns:
            The retained ids, then the root ids such as `ROOT_QUERY`.
        """
        var out = self.store.retained_root_ids(optimistic)
        var roots: List[String] = [
            "ROOT_QUERY",
            "ROOT_MUTATION",
            "ROOT_SUBSCRIPTION",
        ]
        var index = 0
        while index < len(roots):
            if self.store.retain_count(roots[index], optimistic) == 0:
                out.append(roots[index])
            index += 1
        return out^

    def gc(mut self) raises -> List[String]:
        """Remove the entities that no root reaches, as `cache.gc`.

        Returns:
            The ids that were removed, in store order.

        Raises:
            Error: Never in practice; the id table can raise.
        """
        var ids = self.root_id_set(True)
        var seen = Dict[String, Bool]()
        var index = 0
        while index < len(ids):
            seen[ids[index]] = True
            index += 1
        # Each id is in `ids` once, so each entity is visited once.
        var kept = Dict[Int, Bool]()
        var position = 0
        while position < len(ids):
            var slot = self.values.ids.find(ids[position])
            if slot >= 0 and (
                self.store.present(slot, True)
                or self.store.present(slot, False)
            ):
                kept[slot] = True
                var children = self._child_ref_ids(slot)
                for ref child in children:
                    var text = String(self.values.ids.text(child))
                    if text not in seen:
                        seen[text] = True
                        ids.append(text)
            position += 1
        var removed = List[String]()
        for slot in self.store.ids_in_order(False):
            if slot not in kept:
                removed.append(String(self.values.ids.text(slot)))
                self.store.entries[slot].present = False
                self.store.entries[slot].members = List[Member]()
        self._compact()
        return removed^

    def _child_ref_ids(self, slot: Int) -> List[Int]:
        """Return the ids that the values of an entity name, as
        `findChildRefIds`."""
        var out = List[Int]()
        var work = List[Int]()
        if slot < len(self.store.entries) and self.store.entries[slot].present:
            for ref member in self.store.entries[slot].members:
                work.append(Int(member.value))
        for ref layer in self.store.layers:
            if slot < len(layer.entries) and layer.entries[slot].present:
                for ref member in layer.entries[slot].members:
                    if Int(member.value) != NO_VALUE:
                        work.append(Int(member.value))
        while len(work) > 0:
            var value = work.pop()
            var kind = self.values.kind(value)
            if kind == ValueKind.REFERENCE:
                out.append(self.values.ref_id(value))
                work.append(self.values.ref_extras(value))
            elif kind == ValueKind.ARRAY:
                var index = 0
                while index < self.values.length(value):
                    work.append(self.values.item(value, index))
                    index += 1
            elif kind == ValueKind.OBJECT:
                var index = 0
                while index < self.values.length(value):
                    work.append(self.values.member_value(value, index))
                    index += 1
        return out^

    # --- extract and restore ----------------------------------------------

    def extract(mut self, optimistic: Bool = False) -> String:
        """Return the normalized data, as
        `JSON.stringify(cache.extract(optimistic))`.

        The entities are in the order they were added; ids that are array
        indices come first, as ECMAScript orders them. `__META` lists the
        retained ids that are not root ids.

        Args:
            optimistic: Whether to extract optimistic data; False by
                default, as upstream `cache.extract(optimistic = false)`.

        Returns:
            The JSON text.
        """
        var writer = JsonWriter(0, 4096)
        self.write_extract(writer, optimistic)
        return writer^.take_string()

    def write_extract(
        mut self, mut writer: JsonWriter, optimistic: Bool = False
    ):
        """Write the normalized data, as `extract` gives it.

        Args:
            writer: The destination.
            optimistic: Whether to extract optimistic data.
        """
        writer.begin_object()
        var order = self.store.ids_in_order(optimistic)
        var indexed = List[Int]()
        for slot in order:
            if self.values.ids.indexes[slot] >= 0:
                indexed.append(slot)
        _sort_by_index(indexed, self.values.ids.indexes)
        for slot in indexed:
            self._write_entity(writer, slot, optimistic)
        for slot in order:
            if self.values.ids.indexes[slot] < 0:
                self._write_entity(writer, slot, optimistic)
        var extra = List[String]()
        for ref key in self.store.retained_root_ids(optimistic):
            if key not in self.policies.root_typenames_by_id:
                extra.append(key)
        if len(extra) > 0:
            _sort_texts(extra)
            writer.key("__META")
            writer.begin_object()
            writer.key("extraRootIds")
            writer.begin_array()
            var position = 0
            while position < len(extra):
                writer.string(extra[position])
                position += 1
            writer.end_array()
            writer.end_object()
        writer.end_object()

    def _write_entity(
        self, mut writer: JsonWriter, slot: Int, optimistic: Bool = False
    ):
        """Write one entity as a member of the extract object."""
        writer.key(self.values.ids.text(slot))
        var members = self.store.members_of(slot, optimistic)
        writer.begin_object()
        # Store field names that are array indices come first, as
        # ECMAScript orders the keys of an object.
        var names = List[Int]()
        var others = List[Int]()
        for ref member in members:
            if self.values.names.indexes[Int(member.name)] >= 0:
                names.append(Int(member.name))
        if len(names) == 0:
            for ref member in members:
                writer.key(self.values.names.text(Int(member.name)))
                self.values.write(writer, Int(member.value))
            writer.end_object()
            return
        _sort_by_index(names, self.values.names.indexes)
        var index = 0
        while index < len(members):
            if self.values.names.indexes[Int(members[index].name)] < 0:
                others.append(Int(members[index].name))
            index += 1
        names.extend(Span(others))
        index = 0
        while index < len(names):
            writer.key(self.values.names.text(names[index]))
            self.values.write(writer, member_value(members, names[index]))
            index += 1
        writer.end_object()

    def restore(mut self, data: JsonDocument) raises:
        """Replace the data with extracted data, as `cache.restore`.

        Args:
            data: The object that `extract` gives.

        Raises:
            Error: If `data` is not an object, or `__META` is not valid.
        """
        if data.kind(data.root) != JsonKind.OBJECT:
            raise Error("The data to restore must be an object")
        self.reset()
        var member = data.first(data.root)
        while member != NO_NODE:
            var key = data.key(member)
            if key == "__META":
                var extra = data.find(member, "extraRootIds")
                var item = (
                    data.first(extra) if data.kind(extra)
                    == JsonKind.ARRAY else NO_NODE
                )
                while item != NO_NODE:
                    _ = self.store.retain(data.string_value(item))
                    item = data.next(item)
            elif data.kind(member) == JsonKind.OBJECT:
                var value = self.values.from_json(data, member)
                var slot = self.values.ids.intern(key)
                # Upstream `merge(id, ref)` writes the merge of the entity
                # that `id` names, which a restore has not made yet, and
                # the entity that the reference names, to the latter: the
                # store does not change.
                if not self.values.is_reference(value):
                    self.merge_entity(slot, self.values.members(value))
            member = data.next(member)
        self._compact()

    def restore_text(mut self, text: StringSlice) raises:
        """Replace the data with the JSON text of extracted data.

        Args:
            text: The text that `extract` gives.

        Raises:
            Error: If the text is not JSON, or not an object.
        """
        var document = parse_json(text)
        self.restore(document)

    def reset(mut self):
        """Remove all the data, as `cache.reset`. The policies stay."""
        self.values = Values()
        self.store = EntityStore()
        self.live = 0

    # --- compaction -------------------------------------------------------

    def _maybe_compact(mut self):
        """Compact the arena when it is more than twice its live size."""
        if len(self.values.nodes) > 2 * self.live + COMPACT_SLACK:
            self._compact()

    def _compact(mut self):
        """Copy the values that the entities use into a new arena."""
        var target = Values()
        swap(target.names, self.values.names)
        swap(target.ids, self.values.ids)
        var moved = List[Int32](length=len(self.values.nodes), fill=-1)
        for ref entry in self.store.entries:
            if entry.present:
                for ref member in entry.members:
                    member.value = Int32(
                        self.values.copy_into(target, Int(member.value), moved)
                    )
        for ref layer in self.store.layers:
            for ref entry in layer.entries:
                if entry.present:
                    for ref member in entry.members:
                        if Int(member.value) != NO_VALUE:
                            member.value = Int32(
                                self.values.copy_into(
                                    target, Int(member.value), moved
                                )
                            )
        swap(self.values, target)
        self.live = len(self.values.nodes)


def _sort_by_index(mut slots: List[Int], indexes: List[Int64]):
    """Sort ids by the array index that their text is."""
    var position = 1
    while position < len(slots):
        var current = slots[position]
        var back = position
        while back > 0 and indexes[slots[back - 1]] > indexes[current]:
            slots[back] = slots[back - 1]
            back -= 1
        slots[back] = current
        position += 1


def _sort_texts(mut texts: List[String]):
    """Sort texts as `Array.prototype.sort` sorts strings."""
    var position = 1
    while position < len(texts):
        var current = texts[position]
        var back = position
        while back > 0:
            var previous = texts[back - 1]
            if not utf16_less(current, previous):
                break
            texts[back] = previous^
            back -= 1
        texts[back] = current^
        position += 1


def _json_nullish(object: JsonDocument, node: Int) -> Bool:
    """Return True for a missing member or `null`: `value == null`."""
    return node == NO_NODE or object.kind(node) == JsonKind.NULL
