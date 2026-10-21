# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The projection plan: the shape of the client response.

Port of `ProjectionPlan` of Hive Router `1a29df9`
`bin/router/src/executor/projection/plan.rs` and `plan/`: `ir.rs` (type
sets and conditions), `collect.rs` (`Collector`), `merge.rs` (`Merger`)
and `display.rs`.

`ProjectionPlan.from_operation` walks the normalized client operation once.
It collects each field with the conditions under which the response shows
it: `@include` and `@skip` variables, the parent type, the field type of
an abstract field, and the values of an enum field. Then it merges the
fields that share a response key and, where two variants can match one
object, makes one exact variant per object type. `gql_router.exec_projection`
walks the plan against the response data.

**Differences from upstream.** Upstream encodes the merged fields into flat
tables (`encode.rs`, `tables.rs`). This port keeps the merged fields in
one arena, and the projection walks the arena. Type sets and conditions are
interned, so equal sets and equal conditions have equal ids, where
upstream compares them by value. The authorization rewrite of `rewrite.rs`
is not ported. The plan is built only from a normalized operation, so some
upstream fallbacks are not ported: `child_parent_type` never meets an empty
scope or mixed outputs without a declaration on the parent, and
`specialize_variants` always finds a variant for each object type.
"""

from std.collections import Set

from gql_router.ast import NONE, ItemKind
from gql_router.federation_spec import OperationKind
from gql_router.operation import OperationDefinition
from gql_router.schema_metadata import (
    FieldNullability,
    SchemaMetadata,
)
from gql_router.store import Store

comptime NO_SET = -1
"""The id that names no type set."""
comptime ALWAYS = 0
"""The id of the condition that always holds."""
comptime FIELD_NON_NULL: UInt8 = 1
"""The field bit of a non-null field: a `null` bubbles to the parent."""
comptime FIELD_TYPENAME: UInt8 = 2
"""The field bit of `__typename`."""
comptime FIELD_CHILDREN: UInt8 = 4
"""The field bit of a field with child fields."""
comptime FIELD_CHECKED: UInt8 = 8
"""The field bit of a field with a parent scope or a condition."""


@fieldwise_init
struct CondKind(Equatable, ImplicitlyCopyable, Movable):
    """The kind of a projection condition, as upstream `ir::Condition`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime ALWAYS = CondKind(0)
    """The condition always holds."""
    comptime INCLUDE_IF = CondKind(1)
    """`@include(if: $var)`."""
    comptime SKIP_IF = CondKind(2)
    """`@skip(if: $var)`."""
    comptime PARENT_TYPE = CondKind(3)
    """The parent object is one of a set of types."""
    comptime FIELD_TYPE = CondKind(4)
    """The field value is one of a set of types."""
    comptime ENUM_VALUES = CondKind(5)
    """The field value is one of a set of enum values."""
    comptime OR = CondKind(6)
    """Either of two conditions."""
    comptime AND = CondKind(7)
    """Both of two conditions."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the eight kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 7


@fieldwise_init
struct Cond(Copyable, Movable):
    """One interned condition."""

    var kind: CondKind
    """What the condition checks."""
    var variable: String
    """The variable of `INCLUDE_IF` and `SKIP_IF`."""
    var set: Int
    """The type or value set of `PARENT_TYPE`, `FIELD_TYPE` and
    `ENUM_VALUES`."""
    var left: Int
    """The left condition of `OR` and `AND`."""
    var right: Int
    """The right condition of `OR` and `AND`."""


struct ProjectionTables(Copyable, Movable):
    """The interned type sets and conditions of a plan."""

    var sets: List[List[String]]
    """Every set, sorted, each name once."""
    var set_ids: Dict[String, Int]
    """The id of each set, by its names joined with `|`."""
    var conds: List[Cond]
    """Every condition; id 0 is `ALWAYS`."""
    var cond_ids: Dict[String, Int]
    """The id of each condition, by its canonical text."""

    def __init__(out self):
        """Start with the `ALWAYS` condition only."""
        self.sets = List[List[String]]()
        self.set_ids = Dict[String, Int]()
        self.conds = List[Cond]()
        self.cond_ids = Dict[String, Int]()
        _ = self._intern_cond("A", Cond(CondKind.ALWAYS, "", NO_SET, 0, 0))

    # --- type sets ------------------------------------------------------

    def intern_sorted(mut self, var names: List[String]) -> Int:
        """Intern a set of names, as upstream `TypeSet::sorted`.

        Args:
            names: The names, in any order, maybe repeated.

        Returns:
            The set's id.
        """
        sort(names)
        var unique = List[String]()
        var key = String()
        for name in names:
            if len(unique) > 0 and unique[len(unique) - 1] == name:
                continue
            if len(unique) > 0:
                key += "|"
            key += name
            unique.append(name)
        var found = self.set_ids.get(key)
        if found:
            return found.value()
        self.sets.append(unique^)
        self.set_ids[key^] = len(self.sets) - 1
        return len(self.sets) - 1

    def exact(mut self, name: String) -> Int:
        """Intern the set of one name, as upstream `TypeSet::exact`.

        Args:
            name: The name.

        Returns:
            The set's id.
        """
        return self.intern_sorted([name])

    def matches(self, set: Int, name: StringSlice) -> Bool:
        """Return True if a set holds a name.

        Args:
            set: The set's id.
            name: The name.

        Returns:
            Whether the name is a member.
        """
        ref members = self.sets[set]
        var low = 0
        var high = len(members)
        while low < high:
            var middle = (low + high) // 2
            var member = StringSlice(members[middle])
            if member == name:
                return True
            if member < name:
                low = middle + 1
            else:
                high = middle
        return False

    def is_subset_of(self, set: Int, other: Int) -> Bool:
        """Return True if every member of a set is in another.

        Args:
            set: The smaller set.
            other: The larger set.

        Returns:
            Whether `set` is a subset of `other`.
        """
        for name in self.sets[set]:
            if not self.matches(other, name):
                return False
        return True

    def union(mut self, set: Int, other: Int) -> Int:
        """Intern the union of two sets.

        Args:
            set: One set.
            other: The other set.

        Returns:
            The id of the union.
        """
        if set == other:
            return set
        var names = self.sets[set].copy()
        names.extend(self.sets[other].copy())
        return self.intern_sorted(names^)

    def intersect(mut self, set: Int, other: Int) -> Int:
        """Intern the intersection of two sets.

        Args:
            set: One set.
            other: The other set.

        Returns:
            The id of the intersection.
        """
        if set == other:
            return set
        var names = List[String]()
        for name in self.sets[set]:
            if self.matches(other, name):
                names.append(name)
        return self.intern_sorted(names^)

    # --- conditions -----------------------------------------------------

    def _intern_cond(mut self, var key: String, var cond: Cond) -> Int:
        """Intern a condition by its canonical text."""
        var found = self.cond_ids.get(key)
        if found:
            return found.value()
        self.conds.append(cond^)
        self.cond_ids[key^] = len(self.conds) - 1
        return len(self.conds) - 1

    def variable_cond(mut self, kind: CondKind, variable: String) -> Int:
        """Intern an `INCLUDE_IF` or `SKIP_IF` condition.

        Args:
            kind: `INCLUDE_IF` or `SKIP_IF`.
            variable: The variable name.

        Returns:
            The condition's id.
        """
        return self._intern_cond(
            String(kind.value) + ":" + variable,
            Cond(kind, variable, NO_SET, 0, 0),
        )

    def set_cond(mut self, kind: CondKind, set: Int) -> Int:
        """Intern a `PARENT_TYPE`, `FIELD_TYPE` or `ENUM_VALUES` condition.

        Args:
            kind: The kind.
            set: The set's id.

        Returns:
            The condition's id.
        """
        return self._intern_cond(
            String(kind.value) + ":" + String(set),
            Cond(kind, "", set, 0, 0),
        )

    def _pair(mut self, kind: CondKind, left: Int, right: Int) -> Int:
        """Intern an `AND` or `OR` condition."""
        return self._intern_cond(
            String(kind.value) + ":" + String(left) + "," + String(right),
            Cond(kind, "", NO_SET, left, right),
        )

    def _same_set_kind(self, left: Int, right: Int) -> Bool:
        """Return True if two conditions are set conditions of one kind."""
        var kind = self.conds[left].kind
        if kind != self.conds[right].kind:
            return False
        return (
            kind == CondKind.PARENT_TYPE
            or kind == CondKind.FIELD_TYPE
            or kind == CondKind.ENUM_VALUES
        )

    def and_(mut self, left: Int, right: Int) -> Int:
        """Intern both of two conditions, as upstream `Condition::and`.

        Args:
            left: One condition.
            right: The other condition.

        Returns:
            The id of the combined condition.
        """
        if left == ALWAYS:
            return right
        if right == ALWAYS:
            return left
        if self._same_set_kind(left, right):
            var kind = self.conds[left].kind
            var set = self.intersect(
                self.conds[left].set, self.conds[right].set
            )
            return self.set_cond(kind, set)
        return self._pair(CondKind.AND, left, right)

    def or_(mut self, left: Int, right: Int) -> Int:
        """Intern either of two conditions, as upstream `Condition::or`.

        Args:
            left: One condition.
            right: The other condition.

        Returns:
            The id of the combined condition.
        """
        if left == right:
            return left
        if left == ALWAYS or right == ALWAYS:
            return ALWAYS
        if self._same_set_kind(left, right):
            var kind = self.conds[left].kind
            var set = self.union(self.conds[left].set, self.conds[right].set)
            return self.set_cond(kind, set)
        return self._pair(CondKind.OR, left, right)

    def with_directives(
        mut self, cond: Int, include: String, skip: String
    ) -> Int:
        """Add the `@include` and `@skip` of a selection, as upstream
        `with_directives`.

        Args:
            cond: The condition so far.
            include: The `@include` variable, or empty.
            skip: The `@skip` variable, or empty.

        Returns:
            The combined condition.
        """
        var out = cond
        if include.byte_length() > 0:
            out = self.and_(
                out, self.variable_cond(CondKind.INCLUDE_IF, include)
            )
        if skip.byte_length() > 0:
            out = self.and_(out, self.variable_cond(CondKind.SKIP_IF, skip))
        return out

    def inherited_by_child(mut self, cond: Int) -> Int:
        """Keep only the variable checks of a condition, as upstream
        `inherited_by_child`.

        Args:
            cond: The condition.

        Returns:
            The condition with every other leaf made `ALWAYS`.
        """
        var kind = self.conds[cond].kind
        if kind == CondKind.AND or kind == CondKind.OR:
            var left = self.inherited_by_child(self.conds[cond].left)
            var right = self.inherited_by_child(self.conds[cond].right)
            if kind == CondKind.AND:
                return self.and_(left, right)
            return self.or_(left, right)
        if kind == CondKind.INCLUDE_IF or kind == CondKind.SKIP_IF:
            return cond
        return ALWAYS

    def without_redundant_parent_scope(mut self, cond: Int, scope: Int) -> Int:
        """Drop the parent type checks that a scope already implies, as
        upstream `without_redundant_parent_scope`.

        Args:
            cond: The condition.
            scope: The parent scope, or `NO_SET`.

        Returns:
            The simpler condition.
        """
        if scope == NO_SET:
            return cond
        var kind = self.conds[cond].kind
        if kind == CondKind.AND or kind == CondKind.OR:
            var left = self.without_redundant_parent_scope(
                self.conds[cond].left, scope
            )
            var right = self.without_redundant_parent_scope(
                self.conds[cond].right, scope
            )
            if kind == CondKind.AND:
                return self.and_(left, right)
            return self.or_(left, right)
        if kind == CondKind.PARENT_TYPE and self.is_subset_of(
            scope, self.conds[cond].set
        ):
            return ALWAYS
        return cond

    def parent_type_set(mut self, cond: Int) -> Int:
        """Return the parent types that a condition allows, as upstream
        `Collector::parent_type_set`.

        Args:
            cond: The condition.

        Returns:
            The set, or `NO_SET` when the condition does not limit them.
        """
        var kind = self.conds[cond].kind
        if kind == CondKind.PARENT_TYPE:
            return self.conds[cond].set
        if kind != CondKind.AND and kind != CondKind.OR:
            return NO_SET
        var left = self.parent_type_set(self.conds[cond].left)
        var right = self.parent_type_set(self.conds[cond].right)
        if left == NO_SET:
            return right
        if right == NO_SET:
            return left
        if kind == CondKind.AND:
            return self.intersect(left, right)
        return self.union(left, right)


@fieldwise_init
struct ProjField(Copyable, Movable):
    """One field of the plan, as upstream `ir::Field` and `FieldRecord`."""

    var field_name: String
    """The schema field name."""
    var response_key: String
    """The name written to the response."""
    var is_typename: Bool
    """Whether the field is `__typename`."""
    var nullability: FieldNullability
    """The list and non-null levels of the field type."""
    var parent_scope: Int
    """The parent types the field is for, or `NO_SET` for every type."""
    var condition: Int
    """When the response shows the field."""
    var has_children: Bool
    """True for upstream `Value::Children`, False for `Passthrough`."""
    var children: List[Int]
    """The child fields, by index in the arena."""

    def is_non_null(self) -> Bool:
        """Return True if a `null` of this field bubbles to the parent.

        Returns:
            Whether the outer level of the type is non-null.
        """
        return self.nullability.is_non_null()


struct KeyTable(Copyable, Movable):
    """The `"key":` text and the bits of each field of a plan, which the
    projection writes and tests for each value."""

    var keys: List[UInt8]
    """For each plan field, `"key":`, one after the other, and 16 bytes of
    padding, so that a key copy can load 16 bytes at once."""
    var key_starts: List[Int]
    """Where the `"key":` of each plan field starts in `keys`, and the end
    of the last one."""
    var bits: List[UInt8]
    """The `FIELD_*` bits of each plan field."""

    def __init__(out self):
        """Start the table of no field."""
        self.keys = List[UInt8]()
        self.key_starts = List[Int]()
        self.bits = List[UInt8]()

    def __init__(out self, fields: List[ProjField]):
        """Make the table of the fields of a plan.

        Args:
            fields: The plan fields.
        """
        var count = len(fields)
        self.keys = List[UInt8](capacity=count * 12 + 16)
        self.key_starts = List[Int](capacity=count + 1)
        self.bits = List[UInt8](capacity=count)
        for ref field in fields:
            self.key_starts.append(len(self.keys))
            self.keys.append(UInt8(ord('"')))
            self.keys.extend(field.response_key.as_bytes())
            self.keys.append(UInt8(ord('"')))
            self.keys.append(UInt8(ord(":")))
            var bits: UInt8 = 0
            if field.is_non_null():
                bits |= FIELD_NON_NULL
            if field.is_typename:
                bits |= FIELD_TYPENAME
            if field.has_children:
                bits |= FIELD_CHILDREN
            if field.parent_scope != NO_SET or field.condition != ALWAYS:
                bits |= FIELD_CHECKED
            self.bits.append(bits)
        self.key_starts.append(len(self.keys))
        self.keys.resize(len(self.keys) + 16, 0)


struct ProjectionPlan(Copyable, Movable):
    """The merged fields of a client operation, as upstream
    `ProjectionPlan`."""

    var tables: ProjectionTables
    """The interned sets and conditions."""
    var fields: List[ProjField]
    """Every field, merged or not."""
    var roots: List[Int]
    """The root fields of the plan."""
    var key_table: KeyTable
    """The key table of `fields`, made once by `from_operation`; empty for
    a plan made another way."""

    def __init__(out self):
        """Start an empty plan."""
        self.tables = ProjectionTables()
        self.fields = List[ProjField]()
        self.roots = List[Int]()
        self.key_table = KeyTable()

    def is_empty(self) -> Bool:
        """Return True if the plan has no root field.

        Returns:
            Whether there is nothing to project.
        """
        return len(self.roots) == 0

    @staticmethod
    def from_operation(
        store: Store, operation: OperationDefinition, schema: SchemaMetadata
    ) -> Tuple[String, ProjectionPlan]:
        """Build the plan of a normalized operation, as upstream
        `ProjectionPlan::from_operation`.

        Args:
            store: The store with the selections.
            operation: The normalized operation.
            schema: The metadata of the consumer schema.

        Returns:
            The root type name and the plan.
        """
        var root = schema.query_type_name
        if operation.kind == OperationKind.MUTATION:
            root = schema.mutation_type_name
        elif operation.kind == OperationKind.SUBSCRIPTION:
            root = schema.subscription_type_name
        var plan = ProjectionPlan()
        var collected = plan._collect_set(
            store, schema, operation.selection_set, root, ALWAYS
        )
        plan.roots = plan._merge_set(schema, collected^, root)
        plan._prune(schema, plan.roots.copy(), root)
        plan.key_table = KeyTable(plan.fields)
        return (root^, plan^)

    # --- collect --------------------------------------------------------

    def _add(mut self, var field: ProjField) -> Int:
        """Add a field to the arena."""
        self.fields.append(field^)
        return len(self.fields) - 1

    def _type_set(mut self, schema: SchemaMetadata, type_name: String) -> Int:
        """Return the types a value of a type can be, as upstream
        `Collector::type_set`. Only composite types reach it, so the scalar
        check of upstream is left out: it gives the same set."""
        if schema.is_object_type(type_name):
            return self.tables.exact(type_name)
        var names = List[String]()
        var possible = schema.possible_types.map.get(type_name)
        if possible:
            for name in possible.value():
                names.append(name)
        names.append(type_name)
        return self.tables.intern_sorted(names^)

    def _collect_set(
        mut self,
        store: Store,
        schema: SchemaMetadata,
        set: Int,
        parent_type: String,
        parent_cond: Int,
    ) -> List[Int]:
        """Collect the fields of a selection set, as upstream
        `collect_selection_set`."""
        var collected = List[Int]()
        var child = store.items[set].first
        if child == NONE:
            # Mojo 1.1 reports a recursion inside a loop as infinite unless
            # the empty case returns first.
            return collected^
        while child != NONE:
            var current = child
            ref item = store.items[current]
            child = item.next
            if item.kind == ItemKind.FIELD:
                self._collect_field(
                    store, schema, current, parent_type, parent_cond, collected
                )
                continue
            var type_condition = String(store.name(item.name))
            var scope = self._type_set(schema, type_condition)
            var frag_cond = self.tables.with_directives(
                self.tables.and_(
                    parent_cond,
                    self.tables.set_cond(CondKind.PARENT_TYPE, scope),
                ),
                _variable(store, item.include),
                _variable(store, item.skip),
            )
            var inner = self._collect_set(
                store, schema, current, type_condition, frag_cond
            )
            for index in inner:
                # `frag_cond` holds `ParentType(scope)`, so each field of the
                # fragment has a parent scope already.
                self.fields[index].parent_scope = self.tables.intersect(
                    self.fields[index].parent_scope, scope
                )
                collected.append(index)
        return collected^

    def _collect_field(
        mut self,
        store: Store,
        schema: SchemaMetadata,
        item_index: Int,
        parent_type: String,
        parent_cond: Int,
        mut collected: List[Int],
    ):
        """Collect one field, as upstream `collect_field`."""
        ref item = store.items[item_index]
        var name = String(store.name(item.name))
        var is_typename = name == "__typename"
        var output_type = String("String")
        var nullability = FieldNullability.type_name()
        if not is_typename:
            # One lookup for both upstream skips: a parent type or a field
            # that the metadata does not have, as `__schema` on the root.
            var info = schema.field_types.get(parent_type + "." + name)
            if not info:
                return
            output_type = info.value().output_type_name
            nullability = info.value().nullability.copy()
        var parent_scope = self.tables.parent_type_set(parent_cond)
        var output_types = NO_SET
        var condition = parent_cond
        if schema.is_union_type(output_type) or schema.is_interface_type(
            output_type
        ):
            output_types = self._type_set(schema, output_type)
            condition = self.tables.and_(
                condition,
                self.tables.set_cond(CondKind.FIELD_TYPE, output_types),
            )
        var include = _variable(store, item.include)
        var skip = _variable(store, item.skip)
        condition = self.tables.with_directives(condition, include, skip)
        var allowed = schema.enum_values.get(output_type)
        if allowed:
            var values = List[String]()
            for value in allowed.value():
                values.append(value)
            condition = self.tables.and_(
                condition,
                self.tables.set_cond(
                    CondKind.ENUM_VALUES, self.tables.intern_sorted(values^)
                ),
            )
        condition = self.tables.without_redundant_parent_scope(
            condition, parent_scope
        )
        var has_children = item.first != NONE
        var children = List[Int]()
        var first_child = item.first
        var only_omitted = (
            has_children
            and store.items[first_child].next == NONE
            and store.items[first_child].kind == ItemKind.FIELD
            and store.items[first_child].omit
        )
        if has_children and not only_omitted:
            var inherited = ALWAYS
            if parent_scope != NO_SET:
                if output_types == NO_SET:
                    output_types = self._type_set(schema, output_type)
                inherited = self.tables.set_cond(
                    CondKind.PARENT_TYPE, output_types
                )
            var children_cond = self.tables.with_directives(
                self.tables.and_(
                    self.tables.inherited_by_child(parent_cond), inherited
                ),
                include,
                skip,
            )
            children = self._collect_set(
                store, schema, item_index, output_type, children_cond
            )
        var response_key = name
        if item.alias != NONE:
            response_key = String(store.name(item.alias))
        collected.append(
            self._add(
                ProjField(
                    name,
                    response_key,
                    is_typename,
                    nullability^,
                    parent_scope,
                    condition,
                    has_children,
                    children^,
                )
            )
        )

    # --- merge ----------------------------------------------------------

    def _output_on(
        self, schema: SchemaMetadata, on_type: String, field_name: String
    ) -> String:
        """Return the output type of a field on a type, or empty, as
        upstream `Merger::output_on`. Only fields with children reach it,
        so the `__typename` check of upstream is left out."""
        return schema.field_type(on_type, field_name)

    def _child_parent_type(
        self,
        schema: SchemaMetadata,
        parent_type: String,
        scope: Int,
        field_name: String,
    ) -> String:
        """Return the output type of a field under a scope, as upstream
        `child_parent_type`.

        A scope is never empty, because normalization drops a fragment
        that no object can match, and each member of a scope declares the
        field. A scope with mixed outputs comes only from a fragment on the
        parent type itself, so `parent_type` declares the field too. Thus
        the `None` results and the `min_output` fallback of upstream are
        left out."""
        if scope == NO_SET:
            return self._output_on(schema, parent_type, field_name)
        ref members = self.tables.sets[scope]
        var first = self._output_on(schema, members[0], field_name)
        var index = 1
        while index < len(members):
            if self._output_on(schema, members[index], field_name) != first:
                return self._output_on(schema, parent_type, field_name)
            index += 1
        return first^

    def _child_scope(
        self,
        schema: SchemaMetadata,
        parent_type: String,
        scope: Int,
        field_name: String,
    ) -> String:
        """Return the parent type of the children of a field, as upstream
        `child_scope`. `_child_parent_type` always finds a type, so the
        `parent_type` fallback of upstream is left out."""
        return self._child_parent_type(schema, parent_type, scope, field_name)

    def _merge_set(
        mut self,
        schema: SchemaMetadata,
        var siblings: List[Int],
        parent_type: String,
    ) -> List[Int]:
        """Merge sibling fields, as upstream `merge_selection_set`."""
        if len(siblings) == 0:
            return siblings^
        # `siblings` is not empty here, so these loops are `while` loops.
        var position = 0
        while position < len(siblings):
            var index = siblings[position]
            position += 1
            if not self.fields[index].has_children:
                continue
            var child_type = self._child_scope(
                schema,
                parent_type,
                self.fields[index].parent_scope,
                self.fields[index].field_name,
            )
            var children = self.fields[index].children.copy()
            var merged_children = self._merge_set(schema, children^, child_type)
            self.fields[index].children = merged_children^
        var keys = List[String]()
        var groups = List[List[Int]]()
        var key_index = Dict[String, Int]()
        position = 0
        while position < len(siblings):
            var next = siblings[position]
            position += 1
            var key = self.fields[next].response_key
            var slot = key_index.get(key)
            var group: Int
            if slot:
                group = slot.value()
            else:
                group = len(groups)
                key_index[key] = group
                keys.append(key)
                groups.append(List[Int]())
            var kept = -1
            for variant in groups[group]:
                if (
                    self.fields[variant].parent_scope
                    == self.fields[next].parent_scope
                ):
                    kept = variant
                    break
            if kept < 0:
                groups[group].append(next)
            else:
                self._merge_into(schema, kept, next, parent_type)
        return self._merge_groups(schema, groups^, parent_type)

    def _merge_into(
        mut self,
        schema: SchemaMetadata,
        kept: Int,
        next: Int,
        parent_type: String,
    ):
        """Merge one field into another with the same key and scope, as
        upstream `Merger::merge`."""
        self.fields[kept].condition = self.tables.or_(
            self.fields[kept].condition, self.fields[next].condition
        )
        if (
            not self.fields[kept].has_children
            or not self.fields[next].has_children
        ):
            return
        var child_type = self._child_scope(
            schema,
            parent_type,
            self.fields[kept].parent_scope,
            self.fields[kept].field_name,
        )
        var joined = self.fields[kept].children.copy()
        joined.extend(self.fields[next].children.copy())
        var merged_children = self._merge_set(schema, joined^, child_type)
        self.fields[kept].children = merged_children^

    def _object_types(
        self, schema: SchemaMetadata, parent_type: String
    ) -> List[String]:
        """Return the object types a parent can be, sorted. The possible
        types are a set and an object type has none, so no name repeats
        and the `dedup` of upstream is left out."""
        var names = List[String]()
        var possible = schema.possible_types.map.get(parent_type)
        if possible:
            for name in possible.value():
                if schema.is_object_type(name):
                    names.append(name)
        if schema.is_object_type(parent_type):
            names.append(parent_type)
        sort(names)
        return names^

    def _merge_groups(
        mut self,
        schema: SchemaMetadata,
        var groups: List[List[Int]],
        parent_type: String,
    ) -> List[Int]:
        """Collapse the variants of each response key, as upstream
        `merge_groups`.

        Each group has one variant or more, and `_merge_set` passes one
        group or more, so the loops over them are `while` loops. A group
        with a variant for every type or with a multi-type scope can match
        each object type: normalization keeps an abstract fragment only on
        the parent type itself. So each object type finds a variant."""
        var merged = List[Int]()
        var object_types = List[String]()
        var have_object_types = False
        var group = 0
        while group < len(groups):
            ref variants = groups[group]
            group += 1
            var exclusive = len(variants) == 1
            if not exclusive:
                exclusive = True
                var position = 0
                while position < len(variants):
                    var scope = self.fields[variants[position]].parent_scope
                    position += 1
                    if scope == NO_SET or len(self.tables.sets[scope]) != 1:
                        exclusive = False
                        break
            if exclusive:
                merged.extend(variants.copy())
                continue
            if not have_object_types:
                object_types = self._object_types(schema, parent_type)
                have_object_types = True
            for object_type in object_types:
                var kept = -1
                var position = 0
                while position < len(variants):
                    var variant = variants[position]
                    position += 1
                    var scope = self.fields[variant].parent_scope
                    if scope != NO_SET and not self.tables.matches(
                        scope, object_type
                    ):
                        continue
                    var exact = self._clone(variant)
                    self.fields[exact].parent_scope = self.tables.exact(
                        object_type
                    )
                    if kept < 0:
                        kept = exact
                    else:
                        self._merge_into(schema, kept, exact, parent_type)
                merged.append(kept)
        return merged^

    def _clone(mut self, field: Int) -> Int:
        """Copy a field and its children, as upstream `Field::clone`."""
        var copy = self.fields[field].copy()
        if len(copy.children) == 0:
            return self._add(copy^)
        var children = List[Int]()
        var originals = copy.children.copy()
        # `originals` is not empty here.
        var position = 0
        while position < len(originals):
            children.append(self._clone(originals[position]))
            position += 1
        copy.children = children^
        return self._add(copy^)

    def _possible_output_types(
        mut self, schema: SchemaMetadata, scope: Int, field_name: String
    ) -> Int:
        """Return every output type of a field under a scope, as upstream
        `possible_output_types`, or `NO_SET` for no scope. As in
        `_child_parent_type`, a scope is never empty and each member
        declares the field."""
        if scope == NO_SET:
            return NO_SET
        ref members = self.tables.sets[scope]
        var outputs = List[String]()
        var position = 0
        while position < len(members):
            outputs.append(
                self._output_on(schema, members[position], field_name)
            )
            position += 1
        return self.tables.intern_sorted(outputs^)

    def _prune(
        mut self,
        schema: SchemaMetadata,
        siblings: List[Int],
        parent_type: String,
    ):
        """Drop child scopes that match every output of their field, as
        upstream `prune_redundant_scopes`."""
        if len(siblings) == 0:
            return
        # `siblings` is not empty here.
        var position = 0
        while position < len(siblings):
            var index = siblings[position]
            position += 1
            if not self.fields[index].has_children:
                continue
            var scope = self.fields[index].parent_scope
            var field_name = self.fields[index].field_name
            var child_type = self._child_scope(
                schema, parent_type, scope, field_name
            )
            var possible = self._possible_output_types(
                schema, scope, field_name
            )
            var children = self.fields[index].children.copy()
            if possible != NO_SET:
                for child in children:
                    if self.fields[child].parent_scope == possible:
                        self.fields[child].parent_scope = NO_SET
                        continue
                    self.fields[
                        child
                    ].condition = self.tables.without_redundant_parent_scope(
                        self.fields[child].condition,
                        self.fields[child].parent_scope,
                    )
            self._prune(schema, children, child_type)

    # --- display --------------------------------------------------------

    def text(self) -> String:
        """Return the plan as upstream `Display`.

        Returns:
            One block per root field, with its guard, conditions and
            selections.
        """
        var out = String()
        for index in self.roots:
            self._write_field(index, out, 0)
        return out^

    def _write_field(self, index: Int, mut out: String, depth: Int):
        """Write one field, as upstream `pretty_fmt_field`."""
        ref field = self.fields[index]
        var indent = String("  ") * depth
        out += indent
        out += field.response_key
        if field.response_key == field.field_name:
            out += ": {\n"
        else:
            out += " (alias for " + field.field_name + ") {\n"
        if field.parent_scope != NO_SET:
            out += indent + "  type guard: "
            self._write_guard(field.parent_scope, out)
            out += "\n"
        if field.condition != ALWAYS:
            out += indent + "  conditions: "
            self._write_condition(field.condition, out)
            out += "\n"
        if field.has_children:
            out += indent + "  selections:\n"
            for child in field.children:
                self._write_field(child, out, depth + 2)
        out += indent + "}\n"

    def _write_set(self, set: Int, mut out: String):
        """Write the members of a set, joined by `, `."""
        var first = True
        for name in self.tables.sets[set]:
            if not first:
                out += ", "
            first = False
            out += name

    def _write_guard(self, set: Int, mut out: String):
        """Write a type guard: `Exact(A)` or `OneOf(A, B)`."""
        if len(self.tables.sets[set]) == 1:
            out += "Exact(" + self.tables.sets[set][0] + ")"
            return
        out += "OneOf("
        self._write_set(set, out)
        out += ")"

    def _write_condition(self, cond: Int, mut out: String):
        """Write a condition, as upstream `fmt_condition`."""
        ref node = self.tables.conds[cond]
        var kind = node.kind
        if kind == CondKind.INCLUDE_IF:
            out += "Include(if: $" + node.variable + ")"
        elif kind == CondKind.SKIP_IF:
            out += "Skip(if: $" + node.variable + ")"
        elif kind == CondKind.PARENT_TYPE:
            out += "ParentType("
            self._write_guard(node.set, out)
            out += ")"
        elif kind == CondKind.FIELD_TYPE:
            out += "FieldType("
            self._write_guard(node.set, out)
            out += ")"
        elif kind == CondKind.ENUM_VALUES:
            out += "EnumValues("
            self._write_set(node.set, out)
            out += ")"
        else:
            out += "("
            self._write_condition(node.left, out)
            out += " AND " if kind == CondKind.AND else " OR "
            self._write_condition(node.right, out)
            out += ")"


def _variable(store: Store, symbol: Int) -> String:
    """Return the name of a variable symbol, or empty for `NONE`."""
    if symbol == NONE:
        return String()
    return String(store.name(symbol))
