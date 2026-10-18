# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The state of a subgraph: its types, fields and directives.

The validation walk finds them.

Port of the data types and the type factories of Hive Federation
Composition v0.27.0 `src/subgraph/state.ts`, and of `src/utils/auth.ts`.

The walk of a subgraph builds the state, and the validation rules add to
it: `@key` adds a key, `@shareable` marks a field, and so on. The
supergraph phase merges the states of all subgraphs.

Upstream keeps a different object type for each kind of type. This port
keeps one `TypeState` with the members of every kind, and a `kind`; a
member that the kind does not have stays empty. The types are in the order
of their creation, as in the upstream `Map`.

**Differences from upstream.**

- A cost weight is an `Int`. Upstream keeps a JavaScript number, which
  loses precision above 2^53.
- An AST directive is a node index into the subgraph's document.
- `merge_scope_policies` sorts with byte order where upstream sorts with
  `localeCompare`. The two orders agree for scope and policy names of
  ASCII letters, digits, `:` and `_` that have the same case.
"""

from std.collections import Dict
from gql_composition.link import Link, LinkImport
from gql_composition.version import FederationVersion


comptime MISSING = "MISSING"
"""The type of a field or argument before the walk sees its type."""


@fieldwise_init
struct TypeKind(Equatable, ImplicitlyCopyable, Writable):
    """The kind of a subgraph type, as upstream `TypeKind`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime OBJECT = TypeKind(0)
    """An object type."""
    comptime INTERFACE = TypeKind(1)
    """An interface type."""
    comptime ENUM = TypeKind(2)
    """An enum type."""
    comptime UNION = TypeKind(3)
    """A union type."""
    comptime SCALAR = TypeKind(4)
    """A scalar type."""
    comptime INPUT_OBJECT = TypeKind(5)
    """An input object type."""
    comptime DIRECTIVE = TypeKind(6)
    """A directive definition."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the seven kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 6

    def text(self) -> StaticString:
        """Return the upstream string, such as `OBJECT`.

        Returns:
            The kind's name, or `<invalid>`.
        """
        comptime names: Array[StaticString, 7] = [
            "OBJECT",
            "INTERFACE",
            "ENUM",
            "UNION",
            "SCALAR",
            "INPUT_OBJECT",
            "DIRECTIVE",
        ]
        if not self.is_valid():
            return "<invalid>"
        return materialize[names]()[Int(self.value)]

    def write_to(self, mut writer: Some[Writer]):
        """Write the upstream string.

        Args:
            writer: The writer.
        """
        writer.write(self.text())


@fieldwise_init
struct ArgumentKind(Equatable, ImplicitlyCopyable, Writable):
    """What the named type of an argument or input field is, as upstream
    `ArgumentKind`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime SCALAR = ArgumentKind(0)
    """A scalar, or a type that the subgraph does not define."""
    comptime OBJECT = ArgumentKind(1)
    """An input object type."""
    comptime ENUM = ArgumentKind(2)
    """An enum type."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the three kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def text(self) -> StaticString:
        """Return the upstream string, such as `SCALAR`.

        Returns:
            The kind's name, or `<invalid>`.
        """
        if self.value == 0:
            return "SCALAR"
        if self.value == 1:
            return "OBJECT"
        if self.value == 2:
            return "ENUM"
        return "<invalid>"

    def write_to(self, mut writer: Some[Writer]):
        """Write the upstream string.

        Args:
            writer: The writer.
        """
        writer.write(self.text())


@fieldwise_init
struct ExtensionType(Equatable, ImplicitlyCopyable, Writable):
    """How an object type is an extension, as upstream `extensionType`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime NONE = ExtensionType(0)
    """Not an extension: upstream `undefined`."""
    comptime EXTENDS = ExtensionType(1)
    """The `@extends` directive."""
    comptime EXTEND = ExtensionType(2)
    """The `extend type` syntax."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the three kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def text(self) -> StaticString:
        """Return the upstream string: empty, `@extends` or `extend`.

        Returns:
            The string, or `<invalid>`.
        """
        if self.value == 0:
            return ""
        if self.value == 1:
            return "@extends"
        if self.value == 2:
            return "extend"
        return "<invalid>"

    def write_to(self, mut writer: Some[Writer]):
        """Write the upstream string.

        Args:
            writer: The writer.
        """
        writer.write(self.text())


@fieldwise_init
struct Description(Copyable):
    """A description of a type, field, argument or enum value."""

    var value: String
    """The decoded text."""
    var block: Bool
    """Whether the source was a block string."""


@fieldwise_init
struct Deprecated(Copyable):
    """The `@deprecated` of a field, argument or enum value."""

    var reason: Optional[String]
    """The `reason` argument, if it is a string."""


@fieldwise_init
struct Key(Copyable):
    """One `@key` of an entity."""

    var fields: String
    """The `fields` argument."""
    var resolvable: Bool
    """The `resolvable` argument; true by default."""


@fieldwise_init
struct FromContext(Copyable):
    """The `@fromContext` of an argument, split as upstream
    `parseContextReference`."""

    var context: String
    """The context name."""
    var selection: String
    """The selection after the context name."""


@fieldwise_init
struct ListSize(Copyable):
    """The `@listSize` of a field."""

    var print_require_one_slicing_argument: Bool
    """Whether the supergraph prints `requireOneSlicingArgument`."""
    var assumed_size: Optional[Int]
    """The `assumedSize` argument, if any."""
    var slicing_arguments: Optional[List[String]]
    """The `slicingArguments` argument, if any."""
    var sized_fields: Optional[List[String]]
    """The `sizedFields` argument, if any."""
    var require_one_slicing_argument: Bool
    """The `requireOneSlicingArgument` argument; true by default."""


struct StringSet(Copyable, Sized):
    """A set of strings in insertion order, as a JavaScript `Set`, for the
    small sets of the state."""

    var items: List[String]
    """The strings, in insertion order."""

    def __init__(out self):
        """Start an empty set."""
        self.items = List[String]()

    def contains(self, item: StringSlice) -> Bool:
        """Return True if the set holds a string.

        Args:
            item: The string.

        Returns:
            Whether it is in the set.
        """
        for ref existing in self.items:
            if existing == item:
                return True
        return False

    def add(mut self, item: String):
        """Add a string unless the set holds it.

        Args:
            item: The string.
        """
        if not self.contains(item):
            self.items.append(item)

    def __len__(self) -> Int:
        """Return the number of strings.

        Returns:
            The size of the set.
        """
        return len(self.items)


struct InputValueState(Copyable):
    """An argument of a field or directive, or a field of an input object,
    as upstream `Argument` and `InputField`."""

    var name: String
    """The name."""
    var type: String
    """The printed type, such as `[ID!]!`, or `MISSING`."""
    var kind: ArgumentKind
    """What the named type is."""
    var inaccessible: Bool
    """Whether it has `@inaccessible`."""
    var tags: StringSet
    """The `@tag` names."""
    var cost: Optional[Int]
    """The `@cost` weight, if any."""
    var default_value: Optional[String]
    """The printed default value, if any."""
    var from_context: Optional[FromContext]
    """The `@fromContext` of an argument, if any."""
    var description: Optional[Description]
    """The description, if any."""
    var deprecated: Optional[Deprecated]
    """The `@deprecated`, if any."""
    var directives: List[Int]
    """The composed directives applied to it, as nodes."""

    def __init__(out self, name: String):
        """Start an input value without a type.

        Args:
            name: The name.
        """
        self.name = name
        self.type = String(MISSING)
        self.kind = ArgumentKind.SCALAR
        self.inaccessible = False
        self.tags = StringSet()
        self.cost = None
        self.default_value = None
        self.from_context = None
        self.description = None
        self.deprecated = None
        self.directives = List[Int]()


struct EnumValueState(Copyable):
    """A value of an enum type, as upstream `EnumValue`."""

    var name: String
    """The name."""
    var inaccessible: Bool
    """Whether it has `@inaccessible`."""
    var tags: StringSet
    """The `@tag` names."""
    var description: Optional[Description]
    """The description, if any."""
    var deprecated: Optional[Deprecated]
    """The `@deprecated`, if any."""
    var directives: List[Int]
    """The composed directives applied to it, as nodes."""

    def __init__(out self, name: String):
        """Start an enum value.

        Args:
            name: The name.
        """
        self.name = name
        self.inaccessible = False
        self.tags = StringSet()
        self.description = None
        self.deprecated = None
        self.directives = List[Int]()


struct FieldState(Copyable):
    """A field of an object or interface type, as upstream `Field`."""

    var name: String
    """The name."""
    var type: String
    """The printed type, or `MISSING`."""
    var is_leaf: Bool
    """Whether the named type is a scalar or an enum."""
    var args: List[InputValueState]
    """The arguments, in order of creation."""
    var external: Bool
    """Whether it has `@external`."""
    var inaccessible: Bool
    """Whether it has `@inaccessible`."""
    var authenticated: Bool
    """Whether it has `@authenticated`."""
    var policies: List[List[String]]
    """The merged `@policy` groups."""
    var scopes: List[List[String]]
    """The merged `@requiresScopes` groups."""
    var cost: Optional[Int]
    """The `@cost` weight, if any."""
    var list_size: Optional[ListSize]
    """The `@listSize`, if any."""
    var override: Optional[String]
    """The `from` of `@override`, if any."""
    var override_label: Optional[String]
    """The `label` of `@override`, if any."""
    var provides: Optional[String]
    """The `fields` of `@provides`, if any."""
    var requires: Optional[String]
    """The `fields` of `@requires`, if any."""
    var extension: Bool
    """Whether it is in a type extension."""
    var required: Bool
    """Whether a `@requires` selects it."""
    var provided: Bool
    """Whether a `@provides` selects it."""
    var shareable: Bool
    """Whether it is shareable."""
    var used_as_key: Bool
    """Whether a key uses it."""
    var used: Bool
    """Whether a federation directive or an interface uses it."""
    var tags: StringSet
    """The `@tag` names."""
    var description: Optional[Description]
    """The description, if any."""
    var deprecated: Optional[Deprecated]
    """The `@deprecated`, if any."""
    var directives: List[Int]
    """The composed directives applied to it, as nodes."""

    def __init__(out self, name: String):
        """Start a field without a type.

        Args:
            name: The name.
        """
        self.name = name
        self.type = String(MISSING)
        self.is_leaf = False
        self.args = List[InputValueState]()
        self.external = False
        self.inaccessible = False
        self.authenticated = False
        self.policies = List[List[String]]()
        self.scopes = List[List[String]]()
        self.cost = None
        self.list_size = None
        self.override = None
        self.override_label = None
        self.provides = None
        self.requires = None
        self.extension = False
        self.required = False
        self.provided = False
        self.shareable = False
        self.used_as_key = False
        self.used = False
        self.tags = StringSet()
        self.description = None
        self.deprecated = None
        self.directives = List[Int]()

    def find_arg(self, name: StringSlice) -> Int:
        """Return the index of the argument with a name.

        Args:
            name: The argument's name.

        Returns:
            The index in `args`, or -1.
        """
        for index in range(len(self.args)):
            if self.args[index].name == name:
                return index
        return -1

    def arg(mut self, name: String) -> Int:
        """Return the index of the argument with a name, and add it when
        it is missing, as upstream `getOrCreate...FieldArgument`.

        Args:
            name: The argument's name.

        Returns:
            The index in `args`.
        """
        var found = self.find_arg(name)
        if found != -1:
            return found
        self.args.append(InputValueState(name))
        return len(self.args) - 1


struct TypeState(Copyable):
    """A type or directive of a subgraph, as upstream `SubgraphType`.

    `kind` says which members the type has; the others stay empty.
    """

    var kind: TypeKind
    """What the type is."""
    var name: String
    """The name; a root type has its default name, such as `Query`."""
    var fields: List[FieldState]
    """The fields of an object or interface type."""
    var field_index: Dict[String, Int]
    """The index in `fields` of each field name."""
    var input_fields: List[InputValueState]
    """The fields of an input object type, or the arguments of a
    directive."""
    var values: List[EnumValueState]
    """The values of an enum type."""
    var members: StringSet
    """The member types of a union type."""
    var contexts: StringSet
    """The `@context` names of an object, interface or union type."""
    var extension: Bool
    """Whether the type is an extension."""
    var extension_type: ExtensionType
    """How an object type is an extension."""
    var external: Bool
    """Whether an object type has `@external`."""
    var keys: List[Key]
    """The keys of an object or interface type."""
    var fields_used_as_keys: StringSet
    """The fields that the keys use."""
    var inaccessible: Bool
    """Whether it has `@inaccessible`."""
    var authenticated: Bool
    """Whether it has `@authenticated`."""
    var policies: List[List[String]]
    """The merged `@policy` groups."""
    var scopes: List[List[String]]
    """The merged `@requiresScopes` groups."""
    var cost: Optional[Int]
    """The `@cost` weight, if any."""
    var shareable: Bool
    """Whether an object type has `@shareable`."""
    var tags: StringSet
    """The `@tag` names."""
    var interfaces: StringSet
    """The interfaces that an object or interface type implements."""
    var is_definition: Bool
    """Whether the subgraph has a definition and not only extensions."""
    var is_interface_object: Bool
    """Whether an interface type comes from an `@interfaceObject`."""
    var implemented_by: StringSet
    """The object types that implement an interface type."""
    var description: Optional[Description]
    """The description, if any."""
    var deprecated: Optional[Deprecated]
    """The `@deprecated`, if any."""
    var specified_by: Optional[String]
    """The `@specifiedBy` URL of a scalar type, if any."""
    var is_one_of: Bool
    """Whether an input object type has `@oneOf`."""
    var referenced_by_input_type: Bool
    """Whether an input position uses an enum type."""
    var referenced_by_output_type: Bool
    """Whether an output position uses an enum type."""
    var input_type_references: StringSet
    """The schema coordinates of the input positions of an enum type."""
    var output_type_references: StringSet
    """The schema coordinates of the output positions of an enum type."""
    var directives: List[Int]
    """The composed directives applied to the type, as nodes."""
    var composed: Bool
    """Whether `@composeDirective` names a directive."""
    var repeatable: Bool
    """Whether a directive is repeatable."""
    var locations: StringSet
    """The locations of a directive."""

    def __init__(out self, kind: TypeKind, name: String):
        """Start an empty type.

        Args:
            kind: The kind.
            name: The name.
        """
        self.kind = kind
        self.name = name
        self.fields = List[FieldState]()
        self.field_index = Dict[String, Int]()
        self.input_fields = List[InputValueState]()
        self.values = List[EnumValueState]()
        self.members = StringSet()
        self.contexts = StringSet()
        self.extension = False
        self.extension_type = ExtensionType.NONE
        self.external = False
        self.keys = List[Key]()
        self.fields_used_as_keys = StringSet()
        self.inaccessible = False
        self.authenticated = False
        self.policies = List[List[String]]()
        self.scopes = List[List[String]]()
        self.cost = None
        self.shareable = False
        self.tags = StringSet()
        self.interfaces = StringSet()
        self.is_definition = False
        self.is_interface_object = False
        self.implemented_by = StringSet()
        self.description = None
        self.deprecated = None
        self.specified_by = None
        self.is_one_of = False
        self.referenced_by_input_type = False
        self.referenced_by_output_type = False
        self.input_type_references = StringSet()
        self.output_type_references = StringSet()
        self.directives = List[Int]()
        self.composed = False
        self.repeatable = False
        self.locations = StringSet()

    def find_field(self, name: String) -> Int:
        """Return the index of the field with a name.

        Args:
            name: The name of the field.

        Returns:
            The index in `fields`, or -1.
        """
        var found = self.field_index.get(name)
        if found:
            return found.value()
        return -1

    def field(mut self, name: String) -> Int:
        """Return the index of the field with a name, and add it when it is
        missing, as upstream `getOrCreate...Field`.

        Args:
            name: The name of the field.

        Returns:
            The index in `fields`.
        """
        var found = self.find_field(name)
        if found != -1:
            return found
        self.field_index[name] = len(self.fields)
        self.fields.append(FieldState(name))
        return len(self.fields) - 1

    def find_input_field(self, name: StringSlice) -> Int:
        """Return the index of the input field or directive argument with a
        name.

        Args:
            name: The name.

        Returns:
            The index in `input_fields`, or -1.
        """
        for index in range(len(self.input_fields)):
            if self.input_fields[index].name == name:
                return index
        return -1

    def input_field(mut self, name: String) -> Int:
        """Return the index of the input field or directive argument with a
        name, and add it when it is missing.

        Args:
            name: The name.

        Returns:
            The index in `input_fields`.
        """
        var found = self.find_input_field(name)
        if found != -1:
            return found
        self.input_fields.append(InputValueState(name))
        return len(self.input_fields) - 1

    def find_value(self, name: StringSlice) -> Int:
        """Return the index of the enum value with a name.

        Args:
            name: The name of the value.

        Returns:
            The index in `values`, or -1.
        """
        for index in range(len(self.values)):
            if self.values[index].name == name:
                return index
        return -1

    def value(mut self, name: String) -> Int:
        """Return the index of the enum value with a name, and add it when
        it is missing.

        Args:
            name: The name of the value.

        Returns:
            The index in `values`.
        """
        var found = self.find_value(name)
        if found != -1:
            return found
        self.values.append(EnumValueState(name))
        return len(self.values) - 1


@fieldwise_init
struct FieldAt(ImplicitlyCopyable):
    """Where a field is in the state: the type index and the field index."""

    var type: Int
    """The index of the type in `SubgraphState.types`."""
    var field: Int
    """The index of the field in the type's `fields`."""


@fieldwise_init
struct RootKind(Equatable, ImplicitlyCopyable, Writable):
    """A root operation type of the schema."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime QUERY = RootKind(0)
    """The query root type: upstream `queryType`."""
    comptime MUTATION = RootKind(1)
    """The mutation root type: upstream `mutationType`."""
    comptime SUBSCRIPTION = RootKind(2)
    """The subscription root type: upstream `subscriptionType`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the three kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def text(self) -> StaticString:
        """Return the capitalized operation name, such as `Query`.

        Returns:
            The name, or `<invalid>`.
        """
        if self.value == 0:
            return "Query"
        if self.value == 1:
            return "Mutation"
        if self.value == 2:
            return "Subscription"
        return "<invalid>"

    def write_to(self, mut writer: Some[Writer]):
        """Write the capitalized operation name.

        Args:
            writer: The writer.
        """
        writer.write(self.text())


struct SpecsUsed(Copyable):
    """Which linked specifications the subgraph uses, as upstream
    `SubgraphState.specs`."""

    var tag: Bool
    """Whether `@tag` is used."""
    var context: Bool
    """Whether `@context` or `@fromContext` is used."""
    var inaccessible: Bool
    """Whether `@inaccessible` is used."""
    var link: Bool
    """Whether the subgraph defines `@link` itself."""
    var policy: Bool
    """Whether `@policy` is used."""
    var requires_scopes: Bool
    """Whether `@requiresScopes` is used."""
    var authenticated: Bool
    """Whether `@authenticated` is used."""
    var cost: Bool
    """Whether `@cost` or `@listSize` is used."""
    var cost_name: Optional[String]
    """The local name of `@cost`, if it is used."""
    var list_size_name: Optional[String]
    """The local name of `@listSize`, if it is used."""

    def __init__(out self):
        """Start with nothing used."""
        self.tag = False
        self.context = False
        self.inaccessible = False
        self.link = False
        self.policy = False
        self.requires_scopes = False
        self.authenticated = False
        self.cost = False
        self.cost_name = None
        self.list_size_name = None


def _is_subset(subset: List[String], superset: List[String]) -> Bool:
    """Return True if every string of one list is in another."""
    var index = 0
    while index < len(subset):
        if subset[index] not in superset:
            return False
        index += 1
    return True


def _add_unique(mut union: List[String], group: List[String]):
    """Append the strings of a group that a list does not hold yet."""
    for ref item in group:
        var seen = False
        for ref existing in union:
            if existing == item:
                seen = True
        if not seen:
            union.append(item)


def _joined(group: List[String]) -> String:
    """Return a group joined by commas."""
    return String(",").join(group)


def _sort_strings(mut items: List[String]):
    """Sort strings in byte order, stably."""
    for index in range(1, len(items)):
        var current = items[index]
        var position = index
        while position > 0 and items[position - 1] > current:
            items[position] = items[position - 1]
            position -= 1
        items[position] = current^


def _sort_groups(mut groups: List[List[String]], by_text: Bool):
    """Sort groups by length, and by their joined text when `by_text`,
    stably."""
    for index in range(1, len(groups)):
        var current = groups[index].copy()
        var position = index
        while position > 0:
            ref before = groups[position - 1]
            var later = len(before) > len(current) or (
                by_text
                and len(before) == len(current)
                and _joined(before) > _joined(current)
            )
            if not later:
                break
            groups[position] = before.copy()
            position -= 1
        groups[position] = current^


def merge_scope_policies(
    left: List[List[String]], right: List[List[String]]
) -> List[List[String]]:
    """Merge two sets of `@policy` or `@requiresScopes` groups, as upstream
    `mergeScopePolicies`.

    Each group is a list of names that must all hold; the groups are
    alternatives. The merge requires both: each pair of groups becomes their
    union. A group that holds another group is dropped.

    Args:
        left: The groups so far.
        right: The new groups.

    Returns:
        The merged groups, sorted by length and then by text.
    """
    if len(left) == 0:
        return right.copy()
    if len(right) == 0:
        return left.copy()
    var keys = List[String]()
    var merged = List[List[String]]()
    var index_a = 0
    while index_a < len(left):
        var index_b = 0
        while index_b < len(right):
            var union = List[String]()
            _add_unique(union, left[index_a])
            _add_unique(union, right[index_b])
            index_b += 1
            _sort_strings(union)
            var key = _joined(union)
            if key not in keys:
                keys.append(key)
                merged.append(union^)
        index_a += 1
    _sort_groups(merged, False)
    var final_groups = List[List[String]]()
    var index_c = 0
    while index_c < len(merged):
        ref candidate = merged[index_c]
        index_c += 1
        var redundant = False
        for ref existing in final_groups:
            if _is_subset(existing, candidate):
                redundant = True
        if not redundant:
            final_groups.append(candidate.copy())
    _sort_groups(final_groups, True)
    return final_groups^


struct SubgraphState(Movable):
    """The state of one subgraph, as upstream `SubgraphState` with the
    lookups of `createSubgraphStateBuilder`."""

    var graph_id: String
    """The id of the subgraph, such as `USERS`."""
    var graph_name: String
    """The name of the subgraph."""
    var version: FederationVersion
    """The federation version of the subgraph."""
    var types: List[TypeState]
    """The types and directives, in order of creation."""
    var type_index: Dict[String, Int]
    """The index in `types` of each name."""
    var root_order: List[RootKind]
    """The root kinds in the order the walk set them."""
    var root_names: List[String]
    """The name of each root kind, empty when it is not set."""
    var expected_roots: List[String]
    """The name that the schema definition gives each root kind."""
    var links: List[Link]
    """The links, other than federation, that import directives."""
    var core_links: List[Link]
    """Every `@link`, in source order, including federation."""
    var specs: SpecsUsed
    """The linked specifications that the subgraph uses."""
    var federation_imports: List[LinkImport]
    """The imports of the federation link."""
    var composed_directives: StringSet
    """The directives that `@composeDirective` names."""
    var enum_names: Dict[String, Bool]
    """The enum types that the subgraph defines or extends."""
    var input_object_names: Dict[String, Bool]
    """The input object types that the subgraph defines or extends."""
    var scalar_names: Dict[String, Bool]
    """The scalar types that the subgraph defines or extends."""

    def __init__(
        out self,
        graph_id: String,
        graph_name: String,
        version: FederationVersion,
    ):
        """Start the state of a subgraph.

        Args:
            graph_id: The id of the subgraph.
            graph_name: The name of the subgraph.
            version: Its federation version.
        """
        self.graph_id = graph_id
        self.graph_name = graph_name
        self.version = version
        self.types = List[TypeState]()
        self.type_index = Dict[String, Int]()
        self.root_order = List[RootKind]()
        self.root_names = [String(""), String(""), String("")]
        self.expected_roots = [
            String("Query"),
            String("Mutation"),
            String("Subscription"),
        ]
        self.links = List[Link]()
        self.core_links = List[Link]()
        self.specs = SpecsUsed()
        self.federation_imports = List[LinkImport]()
        self.composed_directives = StringSet()
        self.enum_names = Dict[String, Bool]()
        self.input_object_names = Dict[String, Bool]()
        self.scalar_names = Dict[String, Bool]()

    def find_type(self, name: String) -> Int:
        """Return the index of the type or directive with a name.

        Args:
            name: The name.

        Returns:
            The index in `types`, or -1.
        """
        var found = self.type_index.get(name)
        if found:
            return found.value()
        return -1

    def set_root(mut self, kind: RootKind, name: String):
        """Set a root type, as upstream `state.schema.queryType = name`.

        Args:
            kind: The root kind.
            name: The name of the type.
        """
        if self.root_names[Int(kind.value)].byte_length() == 0:
            self.root_order.append(kind)
        self.root_names[Int(kind.value)] = name

    def argument_kind(self, type_name: String) -> ArgumentKind:
        """Return the kind of a named input type, as upstream
        `resolveArgumentKind`.

        Args:
            type_name: The named type.

        Returns:
            `ENUM`, `OBJECT` for an input object type, else `SCALAR`.
        """
        if type_name in self.enum_names:
            return ArgumentKind.ENUM
        if type_name in self.input_object_names:
            return ArgumentKind.OBJECT
        return ArgumentKind.SCALAR

    def rename_object_type(self, name: String) -> String:
        """Return the default name of a root type, as upstream
        `renameObjectType`.

        Args:
            name: A type name.

        Returns:
            `Query`, `Mutation` or `Subscription` for a root type of the
            schema definition, else the name.
        """
        if name == self.expected_roots[0]:
            return String("Query")
        if name == self.expected_roots[1]:
            return String("Mutation")
        if name == self.expected_roots[2]:
            return String("Subscription")
        return name

    def is_interface_object(self, name: String) -> Bool:
        """Return True if a name is an interface from `@interfaceObject`.

        Args:
            name: A type name.

        Returns:
            Whether the state has an interface type with the name and
            `is_interface_object`.
        """
        var found = self.find_type(name)
        if found == -1:
            return False
        ref type = self.types[found]
        return type.kind == TypeKind.INTERFACE and type.is_interface_object

    def get_or_create(
        mut self, kind: TypeKind, name: String, what: StaticString
    ) raises -> Int:
        """Return the index of a type, and add it when it is missing, as
        upstream `getOrCreate...Type`.

        Args:
            kind: The kind the type must have.
            name: The name.
            what: The kind in the message, such as `an object type`.

        Returns:
            The index in `types`.

        Raises:
            Error: `Expected <name> to be <what>` when a type of another
                kind has the name.
        """
        var found = self.find_type(name)
        if found != -1:
            if self.types[found].kind != kind:
                raise Error("Expected " + name + " to be " + what)
            return found
        self.type_index[name] = len(self.types)
        self.types.append(TypeState(kind, name))
        return len(self.types) - 1

    # --- the type factories -------------------------------------------

    def object_type(mut self, name: String) raises -> Int:
        """Return the object type with a name, renamed when it is a root
        type, as upstream `getOrCreateObjectType`.

        Args:
            name: The name in the subgraph.

        Returns:
            The index in `types`.

        Raises:
            Error: When another kind of type has the name.
        """
        return self.get_or_create(
            TypeKind.OBJECT, self.rename_object_type(name), "an object type"
        )

    def interface_type(mut self, name: String) raises -> Int:
        """Return the interface type with a name.

        Args:
            name: The name.

        Returns:
            The index in `types`.

        Raises:
            Error: When another kind of type has the name.
        """
        return self.get_or_create(TypeKind.INTERFACE, name, "an interface type")

    def object_field(mut self, type: String, field: String) raises -> FieldAt:
        """Return a field of an object type, as upstream
        `getOrCreateObjectField`.

        Args:
            type: The name of the type.
            field: The name of the field.

        Returns:
            Where the field is.

        Raises:
            Error: When another kind of type has the name.
        """
        var index = self.object_type(type)
        return FieldAt(index, self.types[index].field(field))

    def interface_field(
        mut self, type: String, field: String
    ) raises -> FieldAt:
        """Return a field of an interface type, as upstream
        `getOrCreateInterfaceField`.

        Args:
            type: The name of the type.
            field: The name of the field.

        Returns:
            Where the field is.

        Raises:
            Error: When another kind of type has the name.
        """
        var index = self.interface_type(type)
        return FieldAt(index, self.types[index].field(field))

    def entity_field(mut self, type: String, field: String) raises -> FieldAt:
        """Return a field of an object type, or of the interface when the
        type is an `@interfaceObject`, as the upstream object field setters
        that call the interface builder.

        Args:
            type: The name of the type.
            field: The name of the field.

        Returns:
            Where the field is.

        Raises:
            Error: When another kind of type has the name.
        """
        if self.is_interface_object(type):
            return self.interface_field(type, field)
        return self.object_field(type, field)

    def owner_field(
        mut self, type: String, field: String, interface: Bool
    ) raises -> FieldAt:
        """Return a field of an interface type when `interface`, else as
        `entity_field`.

        Args:
            type: The name of the type.
            field: The name of the field.
            interface: Whether the walk is in an interface type.

        Returns:
            Where the field is.

        Raises:
            Error: When another kind of type has the name.
        """
        if interface:
            return self.interface_field(type, field)
        return self.entity_field(type, field)

    def arg_index(mut self, at: FieldAt, name: String) -> Int:
        """Return the index of an argument of a field, added when it is
        missing, as upstream `getOrCreate...FieldArgument`.

        Args:
            at: Where the field is.
            name: The name of the argument.

        Returns:
            The index in the field's `args`.
        """
        return self.types[at.type].fields[at.field].arg(name)

    def input_value_at(
        mut self, kind: TypeKind, type: String, name: String
    ) raises -> FieldAt:
        """Return where a field of an input object type is, or an argument
        of a directive when `kind` is `DIRECTIVE`, added when it is missing.

        Args:
            kind: `INPUT_OBJECT` or `DIRECTIVE`.
            type: The name of the type or directive.
            name: The name of the field or argument.

        Returns:
            The type index and the index in its `input_fields`.

        Raises:
            Error: When another kind of type has the name.
        """
        var what: StaticString = "a directive"
        if kind == TypeKind.INPUT_OBJECT:
            what = "an input object type"
        var index = self.get_or_create(kind, type, what)
        return FieldAt(index, self.types[index].input_field(name))

    def enum_value_at(mut self, type: String, name: String) raises -> FieldAt:
        """Return where a value of an enum type is, added when it is
        missing.

        Args:
            type: The name of the enum type.
            name: The name of the value.

        Returns:
            The type index and the index in its `values`.

        Raises:
            Error: When another kind of type has the name.
        """
        var index = self.get_or_create(TypeKind.ENUM, type, "an enum type")
        return FieldAt(index, self.types[index].value(name))
