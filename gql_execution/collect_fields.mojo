# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The fields of a selection set, grouped by response key.

Port of graphql-js 16.14.2 `execution/collectFields.ts`: `collectFields`
and `collectSubfields`, with `@skip` and `@include`, fragment spreads and
inline fragments, and the type conditions.

graphql-js returns a `Map` from each response key to its field nodes.
Here a `FieldCollector` keeps every collected selection set of one
execution in three lists: a `FieldPlan` is a run of `FieldGroup`s, and a
group is a run of field nodes. A group's index is unique in the
collector, so the executor can memoize `collectSubfields` on a type and a
group, as graphql-js memoizes it on a type and a field node array.

**Differences from upstream.** None in behavior.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.error import GraphQLError
from gql_schema.definition import NO_TYPE, Schema, TypeKind
from gql_execution.value import UNDEFINED, ValueKind, Values
from gql_execution.values import get_directive_values


@fieldwise_init
struct FieldGroup(ImplicitlyCopyable, Movable):
    """The field nodes of one response key."""

    var key: Int32
    """The node whose text is the response key: the alias, or the name."""
    var start: Int32
    """The first node in `FieldCollector.nodes`."""
    var count: Int32
    """How many field nodes the group has."""


@fieldwise_init
struct FieldPlan(ImplicitlyCopyable, Movable):
    """The groups of one collected selection set, in response order."""

    var start: Int32
    """The first group in `FieldCollector.groups`."""
    var count: Int32
    """How many groups."""


struct FieldCollector(Movable):
    """Every collected selection set of one execution."""

    var plans: List[FieldPlan]
    """Each collected selection set."""
    var groups: List[FieldGroup]
    """The groups of every plan."""
    var nodes: List[Int32]
    """The field nodes of every group."""
    var fragments: Dict[String, Int]
    """Each fragment definition node, by name; the last one wins."""
    var skip: Int
    """The index of `@skip` in the schema, or `NO_TYPE`."""
    var include: Int
    """The index of `@include` in the schema, or `NO_TYPE`."""
    var _pending: List[Int32]
    var _links: List[Int32]
    var _visited: List[String]

    def __init__(out self, schema: Schema, document: Document):
        """Start a collector for a document.

        Args:
            schema: The schema.
            document: The document; its fragment definitions are indexed.
        """
        self.plans = List[FieldPlan]()
        self.groups = List[FieldGroup]()
        self.nodes = List[Int32]()
        self.fragments = Dict[String, Int]()
        self.skip = schema.directive_named("skip")
        self.include = schema.directive_named("include")
        self._pending = List[Int32]()
        self._links = List[Int32]()
        self._visited = List[String]()
        var definition = document.child(document.root, Role.DEFINITION)
        while definition != NO_NODE:
            if document.kind(definition) == Kind.FRAGMENT_DEFINITION:
                self.fragments[String(document.name(definition))] = definition
            definition = document.next_with_role(definition)

    def group(self, index: Int) -> FieldGroup:
        """Return a group.

        Args:
            index: The group's index.

        Returns:
            The group.
        """
        return self.groups.unsafe_ptr()[unsafe_offset=index]

    def plan(self, index: Int) -> FieldPlan:
        """Return a plan.

        Args:
            index: The plan's index.

        Returns:
            The plan.
        """
        return self.plans.unsafe_ptr()[unsafe_offset=index]

    def node(self, index: Int) -> Int:
        """Return a field node of a group.

        Args:
            index: The index in `nodes`.

        Returns:
            The field node.
        """
        return Int(self.nodes.unsafe_ptr()[unsafe_offset=index])

    def collect_fields(
        mut self,
        schema: Schema,
        document: Document,
        mut values: Values,
        variables: Int,
        runtime_type: Int,
        selection_set: Int,
    ) raises GraphQLError -> Int:
        """Collect the fields of a selection set, as graphql-js
        `collectFields`.

        Args:
            schema: The schema.
            document: The document.
            values: The arena of the variable values; directive arguments
                go there too.
            variables: The coerced variable values, or `UNDEFINED`.
            runtime_type: The object type's index.
            selection_set: The `SelectionSet` node.

        Returns:
            The new plan's index.

        Raises:
            GraphQLError: As `get_directive_values` raises for `@skip` or
                `@include`.
        """
        self._start()
        self._collect(
            schema, document, values, variables, runtime_type, selection_set
        )
        return self._finish()

    def collect_subfields(
        mut self,
        schema: Schema,
        document: Document,
        mut values: Values,
        variables: Int,
        return_type: Int,
        group: Int,
    ) raises GraphQLError -> Int:
        """Collect the fields of the selection sets of a group's field
        nodes, as graphql-js `collectSubfields`.

        Args:
            schema: The schema.
            document: The document.
            values: The arena of the variable values; directive arguments
                go there too.
            variables: The coerced variable values, or `UNDEFINED`.
            return_type: The object type's index.
            group: The group's index.

        Returns:
            The new plan's index.

        Raises:
            GraphQLError: As `get_directive_values` raises for `@skip` or
                `@include`.
        """
        self._start()
        var found = self.group(group)
        var index = Int(found.start) - 1
        while index + 1 < Int(found.start + found.count):
            index += 1
            var selection_set = document.child(
                self.node(index), Role.SELECTION_SET
            )
            if selection_set != NO_NODE:
                self._collect(
                    schema,
                    document,
                    values,
                    variables,
                    return_type,
                    selection_set,
                )
        return self._finish()

    def _start(mut self):
        """Start a plan: no pending groups, no visited fragments."""
        self._pending.clear()
        self._links.clear()
        self._visited.clear()

    def _finish(mut self) -> Int:
        """Move the pending groups into a plan; return its index.

        `_pending` holds, per group, its key node, its first link and its
        last link; `_links` holds pairs of a field node and the next link.
        """
        var first_group = len(self.groups)
        var count = len(self._pending) // 3
        var index = 0
        while index < count:
            var start = len(self.nodes)
            var link = Int(self._pending[3 * index + 1])
            while link >= 0:
                self.nodes.append(self._links[2 * link])
                link = Int(self._links[2 * link + 1])
            self.groups.append(
                FieldGroup(
                    self._pending[3 * index],
                    Int32(start),
                    Int32(len(self.nodes) - start),
                )
            )
            index += 1
        self.plans.append(FieldPlan(Int32(first_group), Int32(count)))
        return len(self.plans) - 1

    def _add_field(mut self, document: Document, field: Int):
        """Add a field node to the pending group of its response key."""
        var key = document.child(field, Role.ALIAS)
        if key == NO_NODE:
            key = document.child(field, Role.NAME)
        var text = document.text(key)
        var link = len(self._links) // 2
        self._links.append(Int32(field))
        self._links.append(-1)
        var count = len(self._pending) // 3
        var index = 0
        while index < count:
            if document.text(Int(self._pending[3 * index])) == text:
                var last = Int(self._pending[3 * index + 2])
                self._links[2 * last + 1] = Int32(link)
                self._pending[3 * index + 2] = Int32(link)
                return
            index += 1
        self._pending.append(Int32(key))
        self._pending.append(Int32(link))
        self._pending.append(Int32(link))

    def _collect(
        mut self,
        schema: Schema,
        document: Document,
        mut values: Values,
        variables: Int,
        runtime_type: Int,
        selection_set: Int,
    ) raises GraphQLError:
        """Return graphql-js `collectFieldsImpl`."""
        var selection = document.child(selection_set, Role.SELECTION)
        while selection != NO_NODE:
            var kind = document.kind(selection)
            if not self._should_include(
                schema, document, values, variables, selection
            ):
                pass
            elif kind == Kind.FIELD:
                self._add_field(document, selection)
            elif kind == Kind.INLINE_FRAGMENT:
                if _condition_matches(
                    schema, document, selection, runtime_type
                ):
                    self._collect_more(
                        schema,
                        document,
                        values,
                        variables,
                        runtime_type,
                        document.child(selection, Role.SELECTION_SET),
                    )
            else:
                self._spread(
                    schema, document, values, variables, runtime_type, selection
                )
            selection = document.next_with_role(selection)

    def _spread(
        mut self,
        schema: Schema,
        document: Document,
        mut values: Values,
        variables: Int,
        runtime_type: Int,
        spread: Int,
    ) raises GraphQLError:
        """Collect the fields of a fragment spread, once per plan."""
        var name = String(document.name(spread))
        for ref seen in self._visited:
            if seen == name:
                return
        self._visited.append(name)
        var fragment = self.fragments.get(name, NO_NODE)
        if fragment == NO_NODE or not _condition_matches(
            schema, document, fragment, runtime_type
        ):
            return
        self._collect_more(
            schema,
            document,
            values,
            variables,
            runtime_type,
            document.child(fragment, Role.SELECTION_SET),
        )

    def _collect_more(
        mut self,
        schema: Schema,
        document: Document,
        mut values: Values,
        variables: Int,
        runtime_type: Int,
        selection_set: Int,
    ) raises GraphQLError:
        """Collect a nested selection set; mutual recursion with
        `_collect`."""
        self._collect(
            schema, document, values, variables, runtime_type, selection_set
        )

    def _should_include(
        self,
        schema: Schema,
        document: Document,
        mut values: Values,
        variables: Int,
        node: Int,
    ) raises GraphQLError -> Bool:
        """Return graphql-js `shouldIncludeNode`."""
        if document.child(node, Role.DIRECTIVE) == NO_NODE:
            return True
        if _flag(schema, document, values, variables, node, self.skip, True):
            return False
        return not _flag(
            schema, document, values, variables, node, self.include, False
        )


def _flag(
    schema: Schema,
    document: Document,
    mut values: Values,
    variables: Int,
    node: Int,
    directive: Int,
    wanted: Bool,
) raises GraphQLError -> Bool:
    """Return True if a node has `@skip(if: true)` or `@include(if:
    false)`: the directive's `if` argument is the boolean `wanted`. Every
    schema has both directives."""
    var arguments = get_directive_values(
        schema, directive, document, node, values, variables
    )
    var flag = values.get(arguments, "if")
    return (
        values.kind(flag) == ValueKind.BOOLEAN
        and values.bool_value(flag) == wanted
    )


def _condition_matches(
    schema: Schema, document: Document, fragment: Int, type: Int
) -> Bool:
    """Return graphql-js `doesFragmentConditionMatch`."""
    var condition = document.child(fragment, Role.TYPE_CONDITION)
    if condition == NO_NODE:
        return True
    var conditional = schema.type_named(document.name(condition))
    if conditional == type:
        return True
    if (
        conditional == NO_TYPE
        or not schema.types[conditional].kind.is_abstract()
    ):
        return False
    return schema.is_sub_type(conditional, type)
