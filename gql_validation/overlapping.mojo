# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""OverlappingFieldsCanBeMergedRule: fields with one response name must be
able to merge.

Port of graphql-js 16.14.2
`validation/rules/OverlappingFieldsCanBeMergedRule.ts` and
`utilities/sortValueNode.ts`.

The algorithm is the graphql-js one, with its three caches: the fields and
fragment names of each selection set, the compared pairs of a field map
and a fragment, and the compared pairs of fragments. A field map is an
index into `OverlapState.maps`, so two maps are the same map exactly when
graphql-js has the same object.

**Speed.** graphql-js compares each pair of fields with one response name,
so `n` equal fields cost `n * n / 2` comparisons. Here the fields of a
group are first sorted into classes of equal fields: the same parent type,
field, arguments and sub-selections, with no fragment spread and no meta
field below them. Whether two fields conflict depends only on their
classes, so each pair of classes is compared once. When no pair of classes
conflicts, the group has no conflict. Otherwise the pairs are compared in
the graphql-js order, and the errors are the same.

**Differences from graphql-js.**

- `sameArguments` compares two values with the printed form of graphql-js
  `stringifyValue`, without printing them: the same kind, the same text, a
  string's value and block flag, and the fields of an object in
  `naturalCompare` order.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_schema.definition import NO_TYPE, Schema, TypeKind, TypeRef
from gql_schema.names import NOT_FOUND, NameTable
from gql_schema.suggestions import natural_compare
from gql_validation.context import ValidationContext
from gql_validation.type_info import NO_FIELD, NO_TYPE_REF, type_from_ast


comptime _CLASS_PAIRS = 32
"""From this many pairs of fields, `_pairs` sorts the fields into classes."""
comptime _SCAN_ARGUMENTS = 16
"""Up to this many arguments, `same_arguments` finds a name by a scan."""


@fieldwise_init
struct _Entry(ImplicitlyCopyable, Movable):
    """graphql-js `NodeAndDef`: a field node with its parent type and its
    definition."""

    var parent: Int32
    var node: Int32
    var field: Int32


@fieldwise_init
struct _Group(ImplicitlyCopyable, Movable):
    """The fields of a field map with one response name: a run of
    `OverlapState.entries`."""

    var name: Int32
    var start: Int32
    var count: Int32


@fieldwise_init
struct _FieldMap(ImplicitlyCopyable, Movable):
    """graphql-js `FieldsAndFragmentNames`: runs of `OverlapState.groups`
    and of `OverlapState.fragments`."""

    var group_start: Int32
    var group_count: Int32
    var fragment_start: Int32
    var fragment_count: Int32


struct _Conflict(Copyable, Movable):
    """graphql-js `Conflict`: the response name, the reason as
    `reasonMessage` prints it, and the fields on each side."""

    var name: String
    var reason: String
    var fields1: List[Int]
    var fields2: List[Int]

    def __init__(
        out self,
        var name: String,
        var reason: String,
        var fields1: List[Int],
        var fields2: List[Int],
    ):
        self.name = name^
        self.reason = reason^
        self.fields1 = fields1^
        self.fields2 = fields2^


struct OverlapState(Movable):
    """The caches of `OverlappingFieldsCanBeMergedRule` for one
    validation."""

    var maps: List[_FieldMap]
    """Every field map, in the order it was made."""
    var groups: List[_Group]
    """The response-name groups of every field map."""
    var entries: List[_Entry]
    """The fields of every group."""
    var fragments: List[Int32]
    """The fragment name ids of every field map."""
    var _map_of_set: List[Int32]
    var _group_names: NameTable
    var _shape_ids: NameTable
    var _fragment_map_of: List[Int32]
    var _node_shape: List[Int32]
    var _node_parent: List[Int32]
    var _field_fragment_pairs: Dict[Int, Bool]
    var _fragment_pairs: Dict[Int, Bool]

    def __init__(out self):
        """Start with empty caches."""
        self.maps = List[_FieldMap]()
        self.groups = List[_Group]()
        self.entries = List[_Entry]()
        self.fragments = List[Int32]()
        self._map_of_set = List[Int32]()
        self._group_names = NameTable()
        self._shape_ids = NameTable()
        self._fragment_map_of = List[Int32]()
        self._node_shape = List[Int32]()
        self._node_parent = List[Int32]()
        self._field_fragment_pairs = Dict[Int, Bool]()
        self._fragment_pairs = Dict[Int, Bool]()

    # --- field maps ---------------------------------------------------------

    def field_map(
        mut self,
        mut ctx: ValidationContext,
        schema: Schema,
        document: Document,
        parent: Int,
        selection_set: Int,
    ) -> Int:
        """Return the field map of a selection set, as graphql-js
        `getFieldsAndFragmentNames`: the first parent type it is made with
        stays in the cache.

        Args:
            ctx: The validation context.
            schema: The schema.
            document: The document.
            parent: The parent type, or `NO_TYPE`.
            selection_set: The `SelectionSet` node.

        Returns:
            The index of the map in `maps`.
        """
        if len(self._map_of_set) == 0:
            self._map_of_set = List[Int32](length=len(document.nodes), fill=-1)
        var cached = Int(self._map_of_set[selection_set])
        if cached >= 0:
            return cached
        var map = len(self.maps)
        # Collect the fields in order, with their response-name nodes.
        var names = List[Int32]()
        var found = List[_Entry]()
        var fragment_start = len(self.fragments)
        var cursors: List[Int] = [document.child(selection_set, Role.SELECTION)]
        var parents: List[Int] = [parent]
        while len(cursors) > 0:
            var top = len(cursors) - 1
            var selection = cursors[top]
            if selection == NO_NODE:
                _ = cursors.pop()
                _ = parents.pop()
                continue
            cursors[top] = document.next_with_role(selection)
            var here = parents[top]
            var kind = document.kind(selection)
            if kind == Kind.FIELD:
                var name = document.child(selection, Role.NAME)
                # `field_named` is `NO_FIELD` for a type with no fields.
                var field = NO_FIELD
                if here >= 0:
                    field = schema.field_named(here, document.text(name))
                var alias = document.child(selection, Role.ALIAS)
                names.append(Int32(name if alias == NO_NODE else alias))
                found.append(
                    _Entry(Int32(here), Int32(selection), Int32(field))
                )
            elif kind == Kind.FRAGMENT_SPREAD:
                var id = ctx.fragment_id(document.name(selection))
                while len(self._fragment_map_of) <= id:
                    self._fragment_map_of.append(-1)
                if Int(self._fragment_map_of[id]) != map:
                    self._fragment_map_of[id] = Int32(map)
                    self.fragments.append(Int32(id))
            else:
                var condition = document.child(selection, Role.TYPE_CONDITION)
                var inner = here
                if condition != NO_NODE:
                    inner = Int(
                        type_from_ast(schema, document, condition).named
                    )
                cursors.append(
                    document.child(
                        document.child(selection, Role.SELECTION_SET),
                        Role.SELECTION,
                    )
                )
                parents.append(inner)
        # Group the fields by response name, the first name first.
        var group_start = len(self.groups)
        var group_of = List[Int]()
        var counts = List[Int]()
        for index in range(len(found)):
            var group = self._group_names.find_or_insert(
                map, document.text(Int(names[index])), len(counts)
            )
            if group == NOT_FOUND:
                group = len(counts)
                counts.append(0)
                self.groups.append(_Group(names[index], 0, 0))
            group_of.append(group)
            counts[group] += 1
        var start = len(self.entries)
        for group in range(len(counts)):
            self.groups[group_start + group].start = Int32(start)
            start += counts[group]
        self.entries.resize(start, _Entry(0, 0, 0))
        for index in range(len(found)):
            var group = group_start + group_of[index]
            var at = Int(self.groups[group].start) + Int(
                self.groups[group].count
            )
            self.entries[at] = found[index]
            self.groups[group].count += 1
        self.maps.append(
            _FieldMap(
                Int32(group_start),
                Int32(len(counts)),
                Int32(fragment_start),
                Int32(len(self.fragments) - fragment_start),
            )
        )
        self._map_of_set[selection_set] = Int32(map)
        return map

    def _fragment_map(
        mut self,
        mut ctx: ValidationContext,
        schema: Schema,
        document: Document,
        fragment: Int,
    ) -> Int:
        """graphql-js `getReferencedFieldsAndFragmentNames`."""
        var selection_set = document.child(fragment, Role.SELECTION_SET)
        var type = Int(
            type_from_ast(
                schema, document, document.child(fragment, Role.TYPE_CONDITION)
            ).named
        )
        return self.field_map(ctx, schema, document, type, selection_set)

    def _group_in(self, document: Document, map: Int, name: Int) -> Int:
        """Return the group of a map with the response name of a node, or
        -1."""
        var found = self._group_names.find(map, document.text(name))
        if found == NOT_FOUND:
            return -1
        return Int(self.maps[map].group_start) + found

    # --- the rule -----------------------------------------------------------

    def check(
        mut self,
        mut ctx: ValidationContext,
        schema: Schema,
        document: Document,
        selection_set: Int,
    ) raises:
        """OverlappingFieldsCanBeMergedRule, on a `SelectionSet`.

        Args:
            ctx: The validation context.
            schema: The schema.
            document: The document.
            selection_set: The selection set.

        Raises:
            Error: Never in practice; the comparisons share a raising
                signature.
        """
        var conflicts = List[_Conflict]()
        var map = self.field_map(
            ctx,
            schema,
            document,
            ctx.type_info.get_parent_type(),
            selection_set,
        )
        self._within(ctx, schema, document, conflicts, map)
        var start = Int(self.maps[map].fragment_start)
        var count = Int(self.maps[map].fragment_count)
        for i in range(count):
            var name = Int(self.fragments[start + i])
            self._fields_and_fragment(
                ctx, schema, document, conflicts, False, map, name
            )
            for j in range(i + 1, count):
                self._fragments(
                    ctx,
                    schema,
                    document,
                    conflicts,
                    False,
                    name,
                    Int(self.fragments[start + j]),
                )
        for ref conflict in conflicts:
            var nodes = conflict.fields1.copy()
            nodes.extend(Span(conflict.fields2))
            ctx.report_error_nodes(
                document,
                'Fields "'
                + conflict.name
                + '" conflict because '
                + conflict.reason
                + ". Use different aliases on the fields to fetch both if"
                " this was intentional.",
                nodes,
            )

    def _fields_and_fragment(
        mut self,
        mut ctx: ValidationContext,
        schema: Schema,
        document: Document,
        mut conflicts: List[_Conflict],
        exclusive: Bool,
        map: Int,
        fragment_id: Int,
    ) raises:
        """graphql-js `collectConflictsBetweenFieldsAndFragment`."""
        var key = (map << 32) | fragment_id
        var known = self._field_fragment_pairs.get(key)
        if Bool(known) and (exclusive or known.value() == exclusive):
            return
        self._field_fragment_pairs[key] = exclusive
        var fragment = ctx.fragment_by_id(document, fragment_id)
        if fragment == NO_NODE:
            return
        var map2 = self._fragment_map(ctx, schema, document, fragment)
        if map == map2:
            return
        self._between(ctx, schema, document, conflicts, exclusive, map, map2)
        var start = Int(self.maps[map2].fragment_start)
        var count = Int(self.maps[map2].fragment_count)
        for index in range(count):
            self._fields_and_fragment(
                ctx,
                schema,
                document,
                conflicts,
                exclusive,
                map,
                Int(self.fragments[start + index]),
            )

    def _fragments(
        mut self,
        mut ctx: ValidationContext,
        schema: Schema,
        document: Document,
        mut conflicts: List[_Conflict],
        exclusive: Bool,
        fragment1: Int,
        fragment2: Int,
    ) raises:
        """graphql-js `collectConflictsBetweenFragments`."""
        if fragment1 == fragment2:
            return
        var key = (min(fragment1, fragment2) << 32) | max(fragment1, fragment2)
        var known = self._fragment_pairs.get(key)
        if Bool(known) and (exclusive or known.value() == exclusive):
            return
        self._fragment_pairs[key] = exclusive
        var node1 = ctx.fragment_by_id(document, fragment1)
        var node2 = ctx.fragment_by_id(document, fragment2)
        if node1 == NO_NODE or node2 == NO_NODE:
            return
        var map1 = self._fragment_map(ctx, schema, document, node1)
        var map2 = self._fragment_map(ctx, schema, document, node2)
        self._between(ctx, schema, document, conflicts, exclusive, map1, map2)
        var start2 = Int(self.maps[map2].fragment_start)
        for index in range(Int(self.maps[map2].fragment_count)):
            self._fragments(
                ctx,
                schema,
                document,
                conflicts,
                exclusive,
                fragment1,
                Int(self.fragments[start2 + index]),
            )
        var start1 = Int(self.maps[map1].fragment_start)
        for index in range(Int(self.maps[map1].fragment_count)):
            self._fragments(
                ctx,
                schema,
                document,
                conflicts,
                exclusive,
                Int(self.fragments[start1 + index]),
                fragment2,
            )

    def _sub_selections(
        mut self,
        mut ctx: ValidationContext,
        schema: Schema,
        document: Document,
        exclusive: Bool,
        parent1: Int,
        set1: Int,
        parent2: Int,
        set2: Int,
    ) raises -> List[_Conflict]:
        """graphql-js `findConflictsBetweenSubSelectionSets`."""
        var conflicts = List[_Conflict]()
        var map1 = self.field_map(ctx, schema, document, parent1, set1)
        var map2 = self.field_map(ctx, schema, document, parent2, set2)
        self._between(ctx, schema, document, conflicts, exclusive, map1, map2)
        var start1 = Int(self.maps[map1].fragment_start)
        var count1 = Int(self.maps[map1].fragment_count)
        var start2 = Int(self.maps[map2].fragment_start)
        var count2 = Int(self.maps[map2].fragment_count)
        for index in range(count2):
            self._fields_and_fragment(
                ctx,
                schema,
                document,
                conflicts,
                exclusive,
                map1,
                Int(self.fragments[start2 + index]),
            )
        for index in range(count1):
            self._fields_and_fragment(
                ctx,
                schema,
                document,
                conflicts,
                exclusive,
                map2,
                Int(self.fragments[start1 + index]),
            )
        for i in range(count1):
            for j in range(count2):
                self._fragments(
                    ctx,
                    schema,
                    document,
                    conflicts,
                    exclusive,
                    Int(self.fragments[start1 + i]),
                    Int(self.fragments[start2 + j]),
                )
        return conflicts^

    def _within(
        mut self,
        mut ctx: ValidationContext,
        schema: Schema,
        document: Document,
        mut conflicts: List[_Conflict],
        map: Int,
    ) raises:
        """graphql-js `collectConflictsWithin`."""
        var first = Int(self.maps[map].group_start)
        var end = first + Int(self.maps[map].group_count)
        for group in range(first, end):
            var count = Int(self.groups[group].count)
            if count < 2:
                continue
            var start = Int(self.groups[group].start)
            self._pairs(
                ctx,
                schema,
                document,
                conflicts,
                False,
                Int(self.groups[group].name),
                True,
                start,
                count,
                start,
                count,
            )

    def _between(
        mut self,
        mut ctx: ValidationContext,
        schema: Schema,
        document: Document,
        mut conflicts: List[_Conflict],
        exclusive: Bool,
        map1: Int,
        map2: Int,
    ) raises:
        """graphql-js `collectConflictsBetween`."""
        var first = Int(self.maps[map1].group_start)
        var end = first + Int(self.maps[map1].group_count)
        for group1 in range(first, end):
            var name = Int(self.groups[group1].name)
            var group2 = self._group_in(document, map2, name)
            if group2 < 0:
                continue
            self._pairs(
                ctx,
                schema,
                document,
                conflicts,
                exclusive,
                name,
                False,
                Int(self.groups[group1].start),
                Int(self.groups[group1].count),
                Int(self.groups[group2].start),
                Int(self.groups[group2].count),
            )

    def _pairs(
        mut self,
        mut ctx: ValidationContext,
        schema: Schema,
        document: Document,
        mut conflicts: List[_Conflict],
        exclusive: Bool,
        name: Int,
        within: Bool,
        start1: Int,
        count1: Int,
        start2: Int,
        count2: Int,
    ) raises:
        """Find the conflicts of each pair of fields of one response name, in
        the graphql-js order: each pair of one group, or each field of one
        group with each field of another.

        Equal fields are sorted into classes first, and each pair of classes
        is compared once. A pair of fields whose classes do not conflict is
        then skipped.
        """
        var total = count1 * (count1 - 1) // 2 if within else count1 * count2
        var shapes1 = List[Int]()
        var shapes2 = List[Int]()
        var known = Dict[Int, Bool]()
        if total >= _CLASS_PAIRS:
            if within and self._same_leaves(document, start1, count1):
                return
            shapes1 = self._shapes(schema, document, start1, count1)
            if within:
                shapes2 = shapes1.copy()
            else:
                shapes2 = self._shapes(schema, document, start2, count2)
            if not self._compare_classes(
                ctx,
                schema,
                document,
                known,
                exclusive,
                name,
                within,
                start1,
                start2,
                total,
                shapes1,
                shapes2,
            ):
                return
        # `known` has each pair of classes, or is empty.
        var classified = len(known) > 0
        var i = 0
        while i < count1:
            var j = i + 1 if within else 0
            var stop = count1 if within else count2
            while j < stop:
                if classified and shapes1[i] >= 0 and shapes2[j] >= 0:
                    if not known.get(_pair_key(shapes1[i], shapes2[j]), True):
                        j += 1
                        continue
                var entry1 = self.entries[start1 + i]
                var entry2 = self.entries[start2 + j]
                self._find(
                    ctx,
                    schema,
                    document,
                    conflicts,
                    exclusive,
                    name,
                    entry1,
                    entry2,
                )
                j += 1
            i += 1

    def _same_leaves(self, document: Document, start: Int, count: Int) -> Bool:
        """Return True when the fields of a group are one leaf field written
        again and again: the same parent type and name, no sub-selection, and
        the same arguments, each name once. No pair of them conflicts."""
        var first = self.entries[start]
        var node = Int(first.node)
        if document.child(node, Role.SELECTION_SET) != NO_NODE:
            return False
        var argument = document.child(node, Role.ARGUMENT)
        while argument != NO_NODE:
            var other = document.next_with_role(argument)
            while other != NO_NODE:
                if document.name(other) == document.name(argument):
                    return False
                other = document.next_with_role(other)
            argument = document.next_with_role(argument)
        var name = document.name(node)
        var index = 1
        while index < count:
            var entry = self.entries[start + index]
            var field = Int(entry.node)
            if (
                entry.parent != first.parent
                or document.name(field) != name
                or document.child(field, Role.SELECTION_SET) != NO_NODE
                or not _same_text_arguments(document, node, field)
            ):
                return False
            index += 1
        return True

    def _compare_classes(
        mut self,
        mut ctx: ValidationContext,
        schema: Schema,
        document: Document,
        mut known: Dict[Int, Bool],
        exclusive: Bool,
        name: Int,
        within: Bool,
        start1: Int,
        start2: Int,
        total: Int,
        shapes1: List[Int],
        shapes2: List[Int],
    ) raises -> Bool:
        """Compare one pair of fields for each pair of classes, and record in
        `known` whether the classes conflict.

        A pure field has no fragment spread, so its comparison changes no
        cache that the graphql-js order depends on. Nothing is recorded when
        there are too many classes to gain.

        Returns:
            False when no pair can conflict, so the caller can stop.
        """
        var first1 = Dict[Int, Int]()
        var second1 = Dict[Int, Int]()
        var first2 = Dict[Int, Int]()
        var distinct1 = List[Int]()
        var distinct2 = List[Int]()
        var impure = False
        var index = 0
        while index < len(shapes1):
            var shape = shapes1[index]
            if shape < 0:
                impure = True
            elif shape not in first1:
                first1[shape] = start1 + index
                distinct1.append(shape)
            elif shape not in second1:
                second1[shape] = start1 + index
            index += 1
        if within:
            distinct2 = distinct1.copy()
        else:
            index = 0
            while index < len(shapes2):
                var shape = shapes2[index]
                if shape < 0:
                    impure = True
                elif shape not in first2:
                    first2[shape] = start2 + index
                    distinct2.append(shape)
                index += 1
        if len(distinct1) * len(distinct2) * 4 > total:
            return True
        var any_conflict = False
        for i in range(len(distinct1)):
            var a = distinct1[i]
            if within:
                if a in second1:
                    any_conflict |= self._class_pair(
                        ctx,
                        schema,
                        document,
                        known,
                        exclusive,
                        name,
                        a,
                        a,
                        first1[a],
                        second1[a],
                    )
                for j in range(i + 1, len(distinct1)):
                    var b = distinct1[j]
                    any_conflict |= self._class_pair(
                        ctx,
                        schema,
                        document,
                        known,
                        exclusive,
                        name,
                        a,
                        b,
                        first1[a],
                        first1[b],
                    )
            else:
                for b in distinct2:
                    any_conflict |= self._class_pair(
                        ctx,
                        schema,
                        document,
                        known,
                        exclusive,
                        name,
                        a,
                        b,
                        first1[a],
                        first2[b],
                    )
        return any_conflict or impure

    def _class_pair(
        mut self,
        mut ctx: ValidationContext,
        schema: Schema,
        document: Document,
        mut known: Dict[Int, Bool],
        exclusive: Bool,
        name: Int,
        a: Int,
        b: Int,
        entry1: Int,
        entry2: Int,
    ) raises -> Bool:
        """Compare one field of class `a` with one of class `b`, and record
        whether the two classes conflict."""
        var scratch = List[_Conflict]()
        var first = self.entries[entry1]
        var second = self.entries[entry2]
        self._find(
            ctx, schema, document, scratch, exclusive, name, first, second
        )
        var conflict = len(scratch) > 0
        known[_pair_key(a, b)] = conflict
        return conflict

    # --- classes of equal fields --------------------------------------------

    def _shapes(
        mut self, schema: Schema, document: Document, start: Int, count: Int
    ) -> List[Int]:
        """Return the class of each field of a group, or -1 for a field that
        is not pure."""
        var out = List[Int](capacity=count)
        var index = 0
        while index < count:
            var entry = self.entries[start + index]
            out.append(
                self._shape(
                    schema, document, Int(entry.node), Int(entry.parent)
                )
            )
            index += 1
        return out^

    def _shape(
        mut self, schema: Schema, document: Document, node: Int, parent: Int
    ) -> Int:
        """Return the class of a field: the same number for fields with the
        same parent type, name, arguments and sub-selections, or -1 for a
        field with a fragment spread or a `__schema` or `__type` field in
        it."""
        if len(self._node_shape) == 0:
            self._node_shape = List[Int32](length=len(document.nodes), fill=-2)
            self._node_parent = List[Int32](length=len(document.nodes), fill=-2)
        if (
            self._node_shape[node] != -2
            and Int(self._node_parent[node]) == parent
        ):
            return Int(self._node_shape[node])
        var key = List[UInt8](capacity=64)
        var shape = -1
        if self._field_key(schema, document, node, parent, key):
            var id = self._shape_ids.__len__()
            var found = self._shape_ids.find_or_insert(
                -1, StringSlice(unsafe_from_utf8=Span(key)), id
            )
            shape = id if found == NOT_FOUND else found
        self._node_shape[node] = Int32(shape)
        self._node_parent[node] = Int32(parent)
        return shape

    def _field_key(
        mut self,
        schema: Schema,
        document: Document,
        node: Int,
        parent: Int,
        mut key: List[UInt8],
    ) -> Bool:
        """Write the class key of a field; False when the field is not
        pure."""
        var name = document.name(node)
        if name == "__schema" or name == "__type":
            return False
        _append(key, "P")
        _append_number(key, parent)
        _append(key, "N")
        key.extend(name.as_bytes())
        # The arguments in name order: `sameArguments` does not depend on
        # their order when each name is used once.
        var arguments = List[Int]()
        var argument = document.child(node, Role.ARGUMENT)
        while argument != NO_NODE:
            var at = len(arguments)
            while at > 0 and document.name(argument) < document.name(
                arguments[at - 1]
            ):
                at -= 1
            arguments.insert(at, argument)
            argument = document.next_with_role(argument)
        for index in range(len(arguments)):
            var argument_name = document.name(arguments[index])
            if index > 0 and argument_name == document.name(
                arguments[index - 1]
            ):
                return False
            var value = document.child(arguments[index], Role.VALUE)
            _append(key, "A")
            key.extend(argument_name.as_bytes())
            _append(key, "=")
            _append_number(key, Int(document.kind(value).value))
            _append(key, ":")
            key.extend(
                document.source.slice(
                    document.start(value), document.end(value)
                ).as_bytes()
            )
        var selection_set = document.child(node, Role.SELECTION_SET)
        if selection_set == NO_NODE:
            _append(key, "L")
            return True
        var child_parent = NO_TYPE
        if parent >= 0:
            var field = schema.field_named(parent, name)
            if field >= 0:
                child_parent = Int(schema.fields[field].type.named)
        _append(key, "S")
        return self._selections_key(
            schema, document, selection_set, child_parent, key
        )

    def _selections_key(
        mut self,
        schema: Schema,
        document: Document,
        selection_set: Int,
        parent: Int,
        mut key: List[UInt8],
    ) -> Bool:
        """Write the class key of a selection set; False when it is not
        pure."""
        var selection = document.child(selection_set, Role.SELECTION)
        while selection != NO_NODE:
            var kind = document.kind(selection)
            if kind == Kind.FIELD:
                var shape = self._shape(schema, document, selection, parent)
                if shape < 0:
                    return False
                var response = document.child(selection, Role.ALIAS)
                if response == NO_NODE:
                    response = document.child(selection, Role.NAME)
                _append(key, "F")
                key.extend(document.text(response).as_bytes())
                _append(key, "#")
                _append_number(key, shape)
            elif kind == Kind.INLINE_FRAGMENT:
                var condition = document.child(selection, Role.TYPE_CONDITION)
                var inner = parent
                _append(key, "I")
                if condition != NO_NODE:
                    inner = Int(
                        type_from_ast(schema, document, condition).named
                    )
                    key.extend(document.name(condition).as_bytes())
                _append(key, "{")
                if not self._selections_key(
                    schema,
                    document,
                    document.child(selection, Role.SELECTION_SET),
                    inner,
                    key,
                ):
                    return False
                _append(key, "}")
            else:
                return False
            selection = document.next_with_role(selection)
        _append(key, "E")
        return True

    def _find(
        mut self,
        mut ctx: ValidationContext,
        schema: Schema,
        document: Document,
        mut conflicts: List[_Conflict],
        parents_exclusive: Bool,
        response_name: Int,
        entry1: _Entry,
        entry2: _Entry,
    ) raises:
        """graphql-js `findConflict`: append the conflict of two fields, if
        they have one."""
        var parent1 = Int(entry1.parent)
        var parent2 = Int(entry2.parent)
        var node1 = Int(entry1.node)
        var node2 = Int(entry2.node)
        var exclusive = parents_exclusive or (
            parent1 != parent2
            and _is_object(schema, parent1)
            and _is_object(schema, parent2)
        )
        if not exclusive:
            var name1 = document.name(node1)
            var name2 = document.name(node2)
            if name1 != name2:
                conflicts.append(
                    _Conflict(
                        String(document.text(response_name)),
                        '"'
                        + String(name1)
                        + '" and "'
                        + String(name2)
                        + '" are different fields',
                        [node1],
                        [node2],
                    )
                )
                return
            if not same_arguments(document, node1, node2):
                conflicts.append(
                    _Conflict(
                        String(document.text(response_name)),
                        String("they have differing arguments"),
                        [node1],
                        [node2],
                    )
                )
                return
        var type1 = NO_TYPE_REF
        var type2 = NO_TYPE_REF
        if entry1.field >= 0:
            type1 = schema.fields[Int(entry1.field)].type
        if entry2.field >= 0:
            type2 = schema.fields[Int(entry2.field)].type
        if (
            type1.named >= 0
            and type2.named >= 0
            and _types_conflict(schema, type1, type2)
        ):
            conflicts.append(
                _Conflict(
                    String(document.text(response_name)),
                    'they return conflicting types "'
                    + schema.type_name(type1)
                    + '" and "'
                    + schema.type_name(type2)
                    + '"',
                    [node1],
                    [node2],
                )
            )
            return
        var set1 = document.child(node1, Role.SELECTION_SET)
        var set2 = document.child(node2, Role.SELECTION_SET)
        if set1 == NO_NODE or set2 == NO_NODE:
            return
        var inner = self._sub_selections(
            ctx,
            schema,
            document,
            exclusive,
            Int(type1.named),
            set1,
            Int(type2.named),
            set2,
        )
        if len(inner) == 0:
            return
        var reason = String("")
        var fields1: List[Int] = [node1]
        var fields2: List[Int] = [node2]
        var index = 0
        while index < len(inner):
            if index > 0:
                reason += " and "
            reason += (
                'subfields "'
                + inner[index].name
                + '" conflict because '
                + inner[index].reason
            )
            fields1.extend(Span(inner[index].fields1))
            fields2.extend(Span(inner[index].fields2))
            index += 1
        conflicts.append(
            _Conflict(
                String(document.text(response_name)),
                reason^,
                fields1^,
                fields2^,
            )
        )


def _same_text_arguments(document: Document, node1: Int, node2: Int) -> Bool:
    """Return True if two fields have the same arguments, written the same
    way in the same order."""
    var argument1 = document.child(node1, Role.ARGUMENT)
    var argument2 = document.child(node2, Role.ARGUMENT)
    while argument1 != NO_NODE and argument2 != NO_NODE:
        if document.name(argument1) != document.name(argument2):
            return False
        var value1 = document.child(argument1, Role.VALUE)
        var value2 = document.child(argument2, Role.VALUE)
        if document.source.slice(
            document.start(value1), document.end(value1)
        ) != document.source.slice(
            document.start(value2), document.end(value2)
        ):
            return False
        argument1 = document.next_with_role(argument1)
        argument2 = document.next_with_role(argument2)
    return argument1 == argument2


def _append(mut key: List[UInt8], text: StringSlice):
    """Append text to a class key."""
    key.extend(text.as_bytes())


def _append_number(mut key: List[UInt8], value: Int):
    """Append a number to a class key, in decimal, with no allocation."""
    if value < 0:
        key.append(45)
    var rest = value if value >= 0 else -value
    var start = len(key)
    while True:
        key.append(UInt8(48 + rest % 10))
        rest //= 10
        if rest == 0:
            break
    var low = start
    var high = len(key) - 1
    while low < high:
        var byte = key[low]
        key[low] = key[high]
        key[high] = byte
        low += 1
        high -= 1


def _pair_key(a: Int, b: Int) -> Int:
    """Return the key of an unordered pair of classes."""
    return (min(a, b) << 32) | max(a, b)


def _is_object(schema: Schema, type: Int) -> Bool:
    """Return True for an object type; False for `NO_TYPE`."""
    return type >= 0 and schema.types[type].kind == TypeKind.OBJECT


def _types_conflict(schema: Schema, type1: TypeRef, type2: TypeRef) -> Bool:
    """graphql-js `doTypesConflict`."""
    var a = type1
    var b = type2
    while True:
        if a.is_list():
            if not b.is_list():
                return True
            a = a.of_type()
            b = b.of_type()
            continue
        if b.is_list():
            return True
        if a.is_non_null():
            if not b.is_non_null():
                return True
            a = a.of_type()
            b = b.of_type()
            continue
        if b.is_non_null():
            return True
        if (
            schema.types[Int(a.named)].kind.is_leaf()
            or schema.types[Int(b.named)].kind.is_leaf()
        ):
            return a.named != b.named
        return False


# --- sameArguments ------------------------------------------------------------


def same_arguments(document: Document, node1: Int, node2: Int) -> Bool:
    """Return graphql-js `sameArguments`: True if two fields have the same
    arguments with the same printed values.

    Args:
        document: The document of both fields.
        node1: The first field.
        node2: The second field.

    Returns:
        Whether each argument of the first field has an argument of the
        same name in the second, with the same value.
    """
    var count1 = document.count(node1, Role.ARGUMENT)
    var count2 = document.count(node2, Role.ARGUMENT)
    if count1 != count2:
        return False
    # graphql-js puts the second field's arguments in a `Map`: the last one
    # with a name wins.
    var table = NameTable()
    var hashed = count2 > _SCAN_ARGUMENTS
    if hashed:
        table = NameTable(capacity=count2)
        var candidate = document.child(node2, Role.ARGUMENT)
        while candidate != NO_NODE:
            table.assign(-1, document.name(candidate), candidate)
            candidate = document.next_with_role(candidate)
    var argument = document.child(node1, Role.ARGUMENT)
    while argument != NO_NODE:
        var name = document.name(argument)
        var other = NO_NODE
        if hashed:
            var found = table.find(-1, name)
            if found != NOT_FOUND:
                other = found
        else:
            var candidate = document.child(node2, Role.ARGUMENT)
            while candidate != NO_NODE:
                if document.name(candidate) == name:
                    other = candidate
                candidate = document.next_with_role(candidate)
        if other == NO_NODE:
            return False
        if not same_value(
            document,
            document.child(argument, Role.VALUE),
            document.child(other, Role.VALUE),
        ):
            return False
        argument = document.next_with_role(argument)
    return True


def same_value(document: Document, value1: Int, value2: Int) -> Bool:
    """Return True if two values print the same after graphql-js
    `sortValueNode`.

    Args:
        document: The document of both values.
        value1: The first value node.
        value2: The second value node.

    Returns:
        Whether `print(sortValueNode(value1)) === print(sortValueNode(value2))`.
    """
    var kind = document.kind(value1)
    if kind != document.kind(value2):
        return False
    if kind == Kind.LIST:
        return _same_items(document, value1, value2)
    if kind == Kind.OBJECT:
        return _same_fields(document, value1, value2)
    if kind == Kind.STRING:
        if document.is_block(value1) != document.is_block(value2):
            return False
        return document.text(value1) == document.text(
            value2
        ) or document.string_value(value1) == document.string_value(value2)
    if kind == Kind.BOOLEAN:
        return document.boolean_value(value1) == document.boolean_value(value2)
    if kind == Kind.VARIABLE:
        return document.name(value1) == document.name(value2)
    if kind == Kind.NULL:
        return True
    return document.text(value1) == document.text(value2)


def _same_items(document: Document, list1: Int, list2: Int) -> Bool:
    """Return True if two lists have the same items."""
    var item1 = document.child(list1, Role.LIST_ITEM)
    var item2 = document.child(list2, Role.LIST_ITEM)
    while item1 != NO_NODE and item2 != NO_NODE:
        if not same_value(document, item1, item2):
            return False
        item1 = document.next_with_role(item1)
        item2 = document.next_with_role(item2)
    return item1 == item2


def _sorted_fields(document: Document, object: Int) -> List[Int]:
    """Return the fields of an object value in `naturalCompare` order; the
    sort is stable, as graphql-js `sortFields`."""
    var out = List[Int]()
    var field = document.child(object, Role.FIELD)
    while field != NO_NODE:
        var at = len(out)
        while (
            at > 0
            and natural_compare(
                document.name(out[at - 1]), document.name(field)
            )
            > 0
        ):
            at -= 1
        out.insert(at, field)
        field = document.next_with_role(field)
    return out^


def _same_fields(document: Document, object1: Int, object2: Int) -> Bool:
    """Return True if two objects have the same fields, after sorting."""
    var fields1 = _sorted_fields(document, object1)
    var fields2 = _sorted_fields(document, object2)
    if len(fields1) != len(fields2):
        return False
    for index in range(len(fields1)):
        if document.name(fields1[index]) != document.name(fields2[index]):
            return False
        if not same_value(
            document,
            document.child(fields1[index], Role.VALUE),
            document.child(fields2[index], Role.VALUE),
        ):
            return False
    return True
