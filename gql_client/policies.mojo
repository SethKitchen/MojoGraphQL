# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Type policies and field policies of the normalized cache.

Port of Apollo Client 4.3.3 `src/cache/inmemory/policies.ts`: the
`TypePolicy` and `FieldPolicy` options, `possibleTypes`, the root type
names, the inheritance of policies from supertypes, and `fragmentMatches`.
The parts that read the store, such as `identify`, `readField` and
`getStoreFieldName`, are in `gql_client.cache`.

A function option of upstream is a Mojo function pointer here:

| Upstream | Mojo |
| --- | --- |
| `KeyFieldsFunction` | `KeyFieldsFunction` |
| `KeyArgsFunction` | `KeyArgsFunction` |
| `FieldReadFunction` | `FieldReadFunction` |
| `FieldMergeFunction` | `FieldMergeFunction` |

A value that a function gets or gives is an index into the cache's
`Values` arena; `NO_VALUE` is `undefined`.

Differences from upstream:

- A key specifier is a `KeySpecifier`, from JSON text or dotted paths.
- A `KeyFieldsFunction` or `KeyArgsFunction` returns a `String`. The empty
  string is `undefined`. It cannot return a new specifier.
- A `KeyArgsFunction` gets the type name, the field name and the
  variables, but not the field node.
- The `scalar` option of a field policy, and custom scalars, are not
  ported.
"""

from std.collections import Dict

from gql_client.cache import (
    FieldFunctionOptions,
    KeyArgsContext,
    KeyFieldsContext,
)
from gql_client.fuzzy import Pattern, compile_pattern, is_plain_name
from gql_client.key_extractor import KeySpecifier

comptime KeyFieldsFunction = def(
    mut context: KeyFieldsContext
) raises thin -> String
"""A `keyFields` function: return the entity id, or `""` for none."""
comptime KeyArgsFunction = def(
    args: Int, mut context: KeyArgsContext
) raises thin -> String
"""A `keyArgs` function: return the store field name, or `""` for the
field name."""
comptime FieldReadFunction = def(
    existing: Int, mut options: FieldFunctionOptions
) raises thin -> Int
"""A field `read` function: return the value to read, or `NO_VALUE`."""
comptime FieldMergeFunction = def(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises thin -> Int
"""A field `merge` function: return the value to store."""


@fieldwise_init
struct KeyMode(Equatable, ImplicitlyCopyable, Writable):
    """How a policy names its key: `keyFields` or `keyArgs`."""

    var value: UInt8
    """The mode's index; see `is_valid`."""

    comptime UNSET = KeyMode(0)
    """No option: the default applies."""
    comptime FALSE = KeyMode(1)
    """`false`: no id for `keyFields`, the field name for `keyArgs`."""
    comptime SPECIFIER = KeyMode(2)
    """An array of names, a `KeySpecifier`."""
    comptime FUNCTION = KeyMode(3)
    """A function."""

    def is_valid(self) -> Bool:
        """Return True for one of the four modes.

        Returns:
            Whether the index names a mode.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the mode's index.

        Args:
            writer: The destination.
        """
        writer.write("KeyMode(", self.value, ")")


@fieldwise_init
struct MergeMode(Equatable, ImplicitlyCopyable, Writable):
    """What a `merge` option is."""

    var value: UInt8
    """The mode's index; see `is_valid`."""

    comptime UNSET = MergeMode(0)
    """No option."""
    comptime TRUE = MergeMode(1)
    """`true`: merge the objects with `mergeObjects`."""
    comptime FALSE = MergeMode(2)
    """`false`: the incoming value replaces the existing value."""
    comptime FUNCTION = MergeMode(3)
    """A function."""

    def is_valid(self) -> Bool:
        """Return True for one of the four modes.

        Returns:
            Whether the index names a mode.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the mode's index.

        Args:
            writer: The destination.
        """
        writer.write("MergeMode(", self.value, ")")


struct KeyFields(Copyable, Movable):
    """The `keyFields` option of a type policy."""

    var mode: KeyMode
    """Which kind of option it is."""
    var specifier: KeySpecifier
    """The specifier, for `KeyMode.SPECIFIER`."""
    var function: Optional[KeyFieldsFunction]
    """The function, for `KeyMode.FUNCTION`."""

    def __init__(out self):
        """Make the unset option."""
        self.mode = KeyMode.UNSET
        self.specifier = KeySpecifier()
        self.function = None

    def __init__(out self, var specifier: KeySpecifier):
        """Make a specifier option.

        Args:
            specifier: The key fields.
        """
        self.mode = KeyMode.SPECIFIER
        self.specifier = specifier^
        self.function = None

    def __init__(out self, function: KeyFieldsFunction):
        """Make a function option.

        Args:
            function: The function that gives the id.
        """
        self.mode = KeyMode.FUNCTION
        self.specifier = KeySpecifier()
        self.function = function

    @staticmethod
    def parse(text: StringSlice) raises -> KeyFields:
        """Make a specifier option from its JSON text.

        Args:
            text: Such as `["isbn"]`.

        Returns:
            The option.

        Raises:
            Error: If the text is not a key specifier.
        """
        return KeyFields(KeySpecifier.parse(text))

    @staticmethod
    def disabled() -> KeyFields:
        """Make the option `keyFields: false`: never normalize the type.

        Returns:
            The option.
        """
        var out = KeyFields()
        out.mode = KeyMode.FALSE
        return out^


struct KeyArgs(Copyable, Movable):
    """The `keyArgs` option of a field policy."""

    var mode: KeyMode
    """Which kind of option it is."""
    var specifier: KeySpecifier
    """The specifier, for `KeyMode.SPECIFIER`."""
    var function: Optional[KeyArgsFunction]
    """The function, for `KeyMode.FUNCTION`."""

    def __init__(out self):
        """Make the unset option."""
        self.mode = KeyMode.UNSET
        self.specifier = KeySpecifier()
        self.function = None

    def __init__(out self, var specifier: KeySpecifier):
        """Make a specifier option.

        Args:
            specifier: The arguments that go in the store field name.
        """
        self.mode = KeyMode.SPECIFIER
        self.specifier = specifier^
        self.function = None

    def __init__(out self, function: KeyArgsFunction):
        """Make a function option.

        Args:
            function: The function that gives the store field name.
        """
        self.mode = KeyMode.FUNCTION
        self.specifier = KeySpecifier()
        self.function = function

    @staticmethod
    def parse(text: StringSlice) raises -> KeyArgs:
        """Make a specifier option from its JSON text.

        Args:
            text: Such as `["type", "@connection", ["key"]]`.

        Returns:
            The option.

        Raises:
            Error: If the text is not a key specifier.
        """
        return KeyArgs(KeySpecifier.parse(text))

    @staticmethod
    def disabled() -> KeyArgs:
        """Make the option `keyArgs: false`: the store name is the field name.

        Returns:
            The option.
        """
        var out = KeyArgs()
        out.mode = KeyMode.FALSE
        return out^


struct Merge(Copyable, Movable):
    """The `merge` option of a type policy or a field policy."""

    var mode: MergeMode
    """Which kind of option it is."""
    var function: Optional[FieldMergeFunction]
    """The function, for `MergeMode.FUNCTION`."""

    def __init__(out self):
        """Make the unset option."""
        self.mode = MergeMode.UNSET
        self.function = None

    def __init__(out self, flag: Bool):
        """Make the option `merge: true` or `merge: false`.

        Args:
            flag: True to merge objects, False to replace them.
        """
        self.mode = MergeMode.TRUE if flag else MergeMode.FALSE
        self.function = None

    def __init__(out self, function: FieldMergeFunction):
        """Make a function option.

        Args:
            function: The merge function.
        """
        self.mode = MergeMode.FUNCTION
        self.function = function


struct FieldPolicy(Copyable, Movable):
    """The policy of one field: upstream `FieldPolicy`."""

    var key_args: KeyArgs
    """The `keyArgs` option."""
    var read: Optional[FieldReadFunction]
    """The `read` function, or None."""
    var merge: Merge
    """The `merge` option."""

    def __init__(out self):
        """Make a policy with no options."""
        self.key_args = KeyArgs()
        self.read = None
        self.merge = Merge()

    def __init__(out self, read_function: FieldReadFunction):
        """Make a policy with only a `read` function, as upstream allows a
        function in place of a policy object.

        Args:
            read_function: The read function.
        """
        self.key_args = KeyArgs()
        self.read = read_function
        self.merge = Merge()


struct TypePolicy(Copyable, Movable):
    """The policy of one type: upstream `TypePolicy`."""

    var key_fields: KeyFields
    """The `keyFields` option."""
    var query_type: Bool
    """The `queryType` option: this type is the root query type."""
    var mutation_type: Bool
    """The `mutationType` option."""
    var subscription_type: Bool
    """The `subscriptionType` option."""
    var merge: Merge
    """The `merge` option of the type's objects."""
    var fields: Dict[String, FieldPolicy]
    """The field policies, by field name."""

    def __init__(out self):
        """Make a policy with no options."""
        self.key_fields = KeyFields()
        self.query_type = False
        self.mutation_type = False
        self.subscription_type = False
        self.merge = Merge()
        self.fields = Dict[String, FieldPolicy]()


struct InternalFieldPolicy(Copyable, Movable):
    """A field policy after the options of all its type policies apply."""

    var typename: String
    """The type that the policy was made for."""
    var key_mode: KeyMode
    """`UNSET`, `FALSE` (the simple key function), `SPECIFIER` or
    `FUNCTION`."""
    var key_specifier: KeySpecifier
    """The `keyArgs` specifier."""
    var key_function: Optional[KeyArgsFunction]
    """The `keyArgs` function."""
    var read: Optional[FieldReadFunction]
    """The `read` function."""
    var merge_mode: MergeMode
    """The `merge` option."""
    var merge_function: Optional[FieldMergeFunction]
    """The `merge` function."""

    def __init__(out self, typename: String):
        """Make an empty policy for a type.

        Args:
            typename: The type.
        """
        self.typename = typename
        self.key_mode = KeyMode.UNSET
        self.key_specifier = KeySpecifier()
        self.key_function = None
        self.read = None
        self.merge_mode = MergeMode.UNSET
        self.merge_function = None


struct InternalTypePolicy(Copyable, Movable):
    """A type policy after its options and its supertypes apply."""

    var updated: Bool
    """Whether `updateTypePolicy` ran, so the `keyFn` and `merge`
    properties exist and `Object.assign` copies them to a subtype."""
    var key_mode: KeyMode
    """`UNSET`, `FALSE` (the null key function), `SPECIFIER` or
    `FUNCTION`."""
    var key_specifier: KeySpecifier
    """The `keyFields` specifier."""
    var key_function: Optional[KeyFieldsFunction]
    """The `keyFields` function."""
    var merge_mode: MergeMode
    """The `merge` option."""
    var merge_function: Optional[FieldMergeFunction]
    """The `merge` function."""
    var fields: Dict[String, Int]
    """Each field name and its policy in `Policies.fields`."""

    def __init__(out self):
        """Make an empty policy."""
        self.updated = False
        self.key_mode = KeyMode.UNSET
        self.key_specifier = KeySpecifier()
        self.key_function = None
        self.merge_mode = MergeMode.UNSET
        self.merge_function = None
        self.fields = Dict[String, Int]()


struct Policies(Movable):
    """The policies of a cache: upstream `Policies`, without the store."""

    var types: List[InternalTypePolicy]
    """Each type policy that was looked up."""
    var type_index: Dict[String, Int]
    """Each type name and its policy in `types`."""
    var fields: List[InternalFieldPolicy]
    """Each field policy."""
    var to_be_added: Dict[String, List[TypePolicy]]
    """The type policies that apply at the next lookup of their type."""
    var supertype_map: Dict[String, List[String]]
    """Each type and its supertypes, in the order they were added."""
    var fuzzy_names: List[String]
    """The subtypes that are patterns, in the order they were added."""
    var fuzzy_patterns: List[Pattern]
    """The compiled pattern of each of `fuzzy_names`."""
    var root_ids_by_typename: Dict[String, String]
    """Each root type name and its id, such as `Query` and `ROOT_QUERY`."""
    var root_typenames_by_id: Dict[String, String]
    """Each root id and its type name."""
    var root_names: List[String]
    """The root type names, such as `Query`: the keys of
    `root_ids_by_typename`, for a lookup without hashing."""
    var query_typename: String
    """The type name of `ROOT_QUERY`, usually `Query`."""
    var has_merges: Bool
    """Whether some type or field policy has a `merge` option, so a write
    must keep merge trees."""
    var data_id_from_object: Optional[KeyFieldsFunction]
    """The `dataIdFromObject` option, or None for the default."""

    def __init__(out self):
        """Make the policies with no options.

        The root types are `Query`, `Mutation` and `Subscription`.
        """
        self.types = List[InternalTypePolicy]()
        self.type_index = Dict[String, Int]()
        self.fields = List[InternalFieldPolicy]()
        self.to_be_added = Dict[String, List[TypePolicy]]()
        self.supertype_map = Dict[String, List[String]]()
        self.fuzzy_names = List[String]()
        self.fuzzy_patterns = List[Pattern]()
        self.root_ids_by_typename = Dict[String, String]()
        self.root_typenames_by_id = Dict[String, String]()
        self.query_typename = "Query"
        self.root_names = ["Query", "Mutation", "Subscription"]
        self.has_merges = False
        self.data_id_from_object = None
        var index = 0
        while index < 3:
            var root = self.root_names[index]
            var id = "ROOT_" + root.upper()
            self.root_ids_by_typename[root] = id
            self.root_typenames_by_id[id] = root
            index += 1

    def set_root_typename(
        mut self, which: StringSlice, typename: StringSlice
    ) raises:
        """Make a type the root type of an operation.

        Args:
            which: `Query`, `Mutation` or `Subscription`.
            typename: The new root type name.

        Raises:
            Error: If the root type name changed before.
        """
        var root_id = "ROOT_" + String(which).upper()
        var old = self.root_typenames_by_id[root_id]
        if old == typename:
            return
        if old != which:
            raise Error(
                String(
                    "Cannot change root ", which, " __typename more than once"
                )
            )
        _ = self.root_ids_by_typename.pop(old)
        self.root_ids_by_typename[String(typename)] = root_id
        self.root_typenames_by_id[root_id] = String(typename)
        if root_id == "ROOT_QUERY":
            self.query_typename = String(typename)
        var position = 0
        while position < len(self.root_names):
            if self.root_names[position] == old:
                self.root_names[position] = String(typename)
            position += 1

    def is_root_typename(self, typename: StringSlice) -> Bool:
        """Return True for a root type name, as `rootIdsByTypename[name]`.

        Args:
            typename: The type name.

        Returns:
            Whether it is the type of `ROOT_QUERY`, `ROOT_MUTATION` or
            `ROOT_SUBSCRIPTION`.
        """
        var index = 0
        while index < len(self.root_names):
            if self.root_names[index] == typename:
                return True
            index += 1
        return False

    def add_type_policies(mut self, policies: Dict[String, TypePolicy]) raises:
        """Add type policies, as `Policies.addTypePolicies`.

        Args:
            policies: Each type name and its policy.

        Raises:
            Error: If a policy changes a root type name a second time.
        """
        for entry in policies.items():
            if entry.value.query_type:
                self.set_root_typename("Query", entry.key)
            if entry.value.mutation_type:
                self.set_root_typename("Mutation", entry.key)
            if entry.value.subscription_type:
                self.set_root_typename("Subscription", entry.key)
            if entry.value.merge.mode != MergeMode.UNSET:
                self.has_merges = True
            for field in entry.value.fields.values():
                if field.merge.mode != MergeMode.UNSET:
                    self.has_merges = True
            if entry.key not in self.to_be_added:
                self.to_be_added[entry.key] = List[TypePolicy]()
            self.to_be_added[entry.key].append(entry.value.copy())

    def add_possible_types(
        mut self, possible_types: Dict[String, List[String]]
    ) raises:
        """Add supertypes, as `Policies.addPossibleTypes`.

        Args:
            possible_types: Each supertype and its subtypes. A subtype that
                is not a plain name is a pattern.

        Raises:
            Error: If a pattern uses syntax that is not supported.
        """
        for entry in possible_types.items():
            self._supertype_set(entry.key)
            for ref subtype in entry.value:
                self._supertype_set(subtype)
                _add_unique(self.supertype_map[subtype], entry.key)
                if not is_plain_name(subtype) and (
                    _position(self.fuzzy_names, subtype) < 0
                ):
                    self.fuzzy_names.append(subtype)
                    self.fuzzy_patterns.append(compile_pattern(subtype))

    def _supertype_set(mut self, subtype: String):
        """Make the supertype set of a type if it has none."""
        if subtype not in self.supertype_map:
            self.supertype_map[subtype] = List[String]()

    def get_type_policy(mut self, typename: String) raises -> Int:
        """Return a type's policy, as `Policies.getTypePolicy`.

        The first lookup makes the policy, with the options of its
        supertypes. Each lookup applies the type policies that were added
        since the last one.

        Args:
            typename: The type.

        Returns:
            The policy's index in `types`.

        Raises:
            Error: If a supertype's policy cannot apply.
        """
        var found = self.type_index.find(typename)
        var index: Int
        if found:
            index = found.value()
        else:
            index = len(self.types)
            self.types.append(InternalTypePolicy())
            self.type_index[typename] = index
            self._inherit(typename, index)
        if typename in self.to_be_added:
            var inbox = self.to_be_added.pop(typename)
            var position = 0
            while position < len(inbox):
                self._update_type_policy(typename, index, inbox[position])
                position += 1
        return index

    def _inherit(mut self, typename: String, index: Int) raises:
        """Copy the options of a new policy's supertypes into it."""
        if typename not in self.supertype_map and len(self.fuzzy_names) > 0:
            self._supertype_set(typename)
            var fuzzy = 0
            while fuzzy < len(self.fuzzy_names):
                if self.fuzzy_patterns[fuzzy].test(typename):
                    var supers = self.supertype_map[
                        self.fuzzy_names[fuzzy]
                    ].copy()
                    var position = 0
                    while position < len(supers):
                        _add_unique(
                            self.supertype_map[typename], supers[position]
                        )
                        position += 1
                fuzzy += 1
        var supertypes = self.supertype_map.get(typename, List[String]())
        for ref supertype in supertypes:
            var parent = self.get_type_policy(supertype)
            if self.types[parent].updated:
                var copy = self.types[parent].copy()
                ref policy = self.types[index]
                policy.updated = True
                policy.key_mode = copy.key_mode
                policy.key_specifier = copy.key_specifier.copy()
                policy.key_function = copy.key_function
                policy.merge_mode = copy.merge_mode
                policy.merge_function = copy.merge_function
            var fields = self.types[parent].fields.copy()
            for field in fields.items():
                self.types[index].fields[field.key] = field.value

    def _update_type_policy(
        mut self, typename: String, index: Int, incoming: TypePolicy
    ):
        """Apply one added type policy, as `updateTypePolicy`."""
        ref policy = self.types[index]
        policy.updated = True
        _set_merge(policy.merge_mode, policy.merge_function, incoming.merge)
        if incoming.key_fields.mode != KeyMode.UNSET:
            policy.key_mode = incoming.key_fields.mode
            policy.key_specifier = incoming.key_fields.specifier.copy()
            policy.key_function = incoming.key_fields.function
        for entry in incoming.fields.items():
            var field = self.types[index].fields.get(entry.key, -1)
            if field < 0 or self.fields[field].typename != typename:
                field = len(self.fields)
                self.fields.append(InternalFieldPolicy(typename))
                self.types[index].fields[entry.key] = field
            ref existing = self.fields[field]
            if entry.value.key_args.mode != KeyMode.UNSET:
                existing.key_mode = entry.value.key_args.mode
                existing.key_specifier = entry.value.key_args.specifier.copy()
                existing.key_function = entry.value.key_args.function
            if entry.value.read:
                existing.read = entry.value.read
            _set_merge(
                existing.merge_mode, existing.merge_function, entry.value.merge
            )
            if (
                existing.read
                and existing.merge_mode != MergeMode.UNSET
                and existing.key_mode == KeyMode.UNSET
            ):
                existing.key_mode = KeyMode.FALSE

    def get_field_policy(
        mut self, typename: StringSlice, field_name: StringSlice
    ) raises -> Int:
        """Return the policy of a field of a type.

        Args:
            typename: The type, or empty for `undefined`.
            field_name: The field.

        Returns:
            The policy's index in `fields`, or -1 for none.

        Raises:
            Error: If a type policy cannot apply.
        """
        if typename.byte_length() == 0:
            return -1
        var index = self.get_type_policy(String(typename))
        return self.types[index].fields.get(String(field_name), -1)

    def fragment_matches(
        mut self,
        supertype: StringSlice,
        typename: StringSlice,
        result_matches: Bool,
    ) raises -> Bool:
        """Return True when a type matches a type condition.

        Port of `Policies.fragmentMatches`, after its checks of a missing
        type condition and a missing type name.

        Args:
            supertype: The type condition.
            typename: The type of the object, not empty.
            result_matches: Whether a result object has all the fields of
                the fragment, so that a fuzzy subtype can match.

        Returns:
            Whether the fragment applies.

        Raises:
            Error: If a type policy cannot apply.
        """
        if typename == supertype:
            return True
        var target = String(supertype)
        if target not in self.supertype_map:
            return False
        var name = String(typename)
        self._supertype_set(name)
        var queue: List[String] = [name]
        var check_fuzzy = result_matches and len(self.fuzzy_names) > 0
        var position = 0
        while position < len(queue):
            var set = self.supertype_map[queue[position]].copy()
            if _position(set, target) >= 0:
                _add_unique(self.supertype_map[name], target)
                return True
            for ref subtype in set:
                self._enqueue(queue, subtype)
            if check_fuzzy and position == len(queue) - 1:
                check_fuzzy = False
                var fuzzy = 0
                while fuzzy < len(self.fuzzy_names):
                    if self.fuzzy_patterns[fuzzy].first_match_is_whole(name):
                        var fuzzy_name = self.fuzzy_names[fuzzy]
                        self._enqueue(queue, fuzzy_name)
                    fuzzy += 1
            position += 1
        return False

    def _enqueue(mut self, mut queue: List[String], subtype: String):
        """Queue a type whose supertype set is not empty and not queued."""
        var size = len(self.supertype_map.get(subtype, List[String]()))
        if size > 0 and _position(queue, subtype) < 0:
            queue.append(subtype)


def _set_merge(
    mut mode: MergeMode,
    mut function: Optional[FieldMergeFunction],
    incoming: Merge,
):
    """Apply a `merge` option, as upstream `setMerge`."""
    if incoming.mode != MergeMode.UNSET:
        mode = incoming.mode
        function = incoming.function


def _position(list: List[String], text: String) -> Int:
    """Return the position of a text in a list, or -1."""
    var index = 0
    while index < len(list):
        if list[index] == text:
            return index
        index += 1
    return -1


def _add_unique(mut list: List[String], text: String):
    """Add a text to a list that holds each text once."""
    if _position(list, text) < 0:
        list.append(text)
