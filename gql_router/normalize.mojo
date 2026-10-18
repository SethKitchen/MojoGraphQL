# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Operation normalization for the query planner.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/ast/normalization/`: `mod.rs`,
`context.rs`, `error.rs` and the eleven passes of `pipeline/`, in the
upstream order: `drop_unused_operations`, `drop_skipped_fields`,
`normalize_fields`, `inline_fragment_spreads`,
`drop_fragment_definitions`, `flatten_fragments`, `type_expand`,
`merge_inline_fragments`, `flatten_matching_object_fragments`,
`merge_fields` and `drop_duplicated_fields`.

`normalize_operation` normalizes an executable document.
`normalize_field_set` normalizes a `@key`, `@requires` or `@provides`
field set for one type and one subgraph, as upstream
`normalize_fields_argument_value_mut`.

**Differences from upstream.** Upstream rewrites the `graphql-parser`
AST and converts the result into the planner AST. This port converts the
parsed document into the planner `Store` first, and runs every pass on
the store. Each item keeps its directives as an interned list while it
is normalized; `skip` and `include` are read from that list at the end.
Argument maps are compared in name order at every depth; upstream sorts
them only at the top of each selection set. An unused fragment
definition is not normalized, so an error inside it is not reported.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.parser import parse
from gql_router.ast import NONE, ItemKind
from gql_router.federation_spec import OperationKind, type_node_from_ast
from gql_router.operation import (
    OperationDefinition,
    VariableDefinition,
    value_from_ast,
)
from gql_router.store import Store
from gql_router.supergraph_state import DefinitionKind, SupergraphState


@fieldwise_init
struct RootTypes(Copyable, Movable):
    """The root types of a normalization, as upstream `RootTypes`."""

    var query: Int
    """The query type, as a symbol, or `NONE`."""
    var mutation: Int
    """The mutation type, as a symbol, or `NONE`."""
    var subscription: Int
    """The subscription type, as a symbol, or `NONE`."""

    def type_for(self, kind: OperationKind) raises -> Int:
        """Return the root type of an operation kind.

        Args:
            kind: The operation kind.

        Returns:
            The type, as a symbol.

        Raises:
            Error: When there is no root type for the kind.
        """
        var found = self.query
        if kind == OperationKind.MUTATION:
            found = self.mutation
        elif kind == OperationKind.SUBSCRIPTION:
            found = self.subscription
        if found == NONE:
            raise Error(
                "Type for operation kind '"
                + String(kind.as_str())
                + "' not found."
            )
        return found


struct _Fragments(Movable):
    """The fragment definitions of a document."""

    var names: List[Int]
    """The fragment names, as symbols."""
    var types: List[Int]
    """The type condition of each fragment."""
    var sets: List[Int]
    """The selection set of each fragment, a `ROOT` item."""

    def __init__(out self):
        """Start with no fragments."""
        self.names = List[Int]()
        self.types = List[Int]()
        self.sets = List[Int]()

    def find(self, name: Int) -> Int:
        """Return the index of a fragment, or `NONE`."""
        for index in range(len(self.names)):
            if self.names[index] == name:
                return index
        return NONE


# --- conversion ----------------------------------------------------------


def _directives_of(
    mut store: Store, document: Document, node: Int
) raises -> Int:
    """Intern the directives of a node, in source order."""
    var ids = List[Int]()
    var directive = document.child(node, Role.DIRECTIVE)
    while directive != NO_NODE:
        var args = _args_of(store, document, directive)
        ids.append(store.directive(store.sym(document.name(directive)), args))
        directive = document.next_with_role(directive)
    return store.directive_list(ids)


def _args_of(mut store: Store, document: Document, node: Int) raises -> Int:
    """Intern the arguments of a field or a directive."""
    var names = List[Int]()
    var values = List[Int]()
    var argument = document.child(node, Role.ARGUMENT)
    while argument != NO_NODE:
        names.append(store.sym(document.name(argument)))
        values.append(
            value_from_ast(
                store, document, document.child(argument, Role.VALUE)
            )
        )
        argument = document.next_with_role(argument)
    return store.intern_args(names, values)


def _literal_condition(store: Store, directives: Int, name: StringSlice) -> Int:
    """Return the first boolean `if` of a named directive: 1, 0 or `NONE`."""
    for id in store.directive_items(directives):
        var directive = store.directives[id].copy()
        if store.name(directive.name) == name and directive.if_boolean != NONE:
            return directive.if_boolean
    return NONE


def _should_keep(store: Store, directives: Int) -> Bool:
    """Return False for `@skip(if: true)` or `@include(if: false)`."""
    if _literal_condition(store, directives, "skip") == 1:
        return False
    if _literal_condition(store, directives, "include") == 0:
        return False
    return True


def _convert_set(
    mut store: Store, document: Document, node: Int, parent: Int
) raises:
    """Add the selections of a `SelectionSet` node to a set, and drop the
    skipped ones, as upstream `drop_skipped_fields`."""
    var selection = document.child(node, Role.SELECTION)
    while selection != NO_NODE:
        var directives = _directives_of(store, document, selection)
        if not _should_keep(store, directives):
            selection = document.next_with_role(selection)
            continue
        var kind = document.kind(selection)
        var item: Int
        if kind == Kind.FIELD:
            var alias_node = document.child(selection, Role.ALIAS)
            item = store.add_item(
                ItemKind.FIELD,
                store.sym(document.name(selection)),
                store.sym(document.text(alias_node)) if alias_node
                != NO_NODE else NONE,
                _args_of(store, document, selection),
            )
        elif kind == Kind.INLINE_FRAGMENT:
            var condition = document.child(selection, Role.TYPE_CONDITION)
            item = store.add_item(
                ItemKind.FRAGMENT,
                store.sym(document.name(condition)) if condition
                != NO_NODE else NONE,
            )
        else:
            item = store.add_item(
                ItemKind.SPREAD, store.sym(document.name(selection))
            )
        store.items[item].directives = directives
        var children = document.child(selection, Role.SELECTION_SET)
        if children != NO_NODE:
            _convert_set(store, document, children, item)
        store.append(parent, item)
        selection = document.next_with_role(selection)


# --- normalize_fields ----------------------------------------------------


def _sort_directives(mut store: Store, item: Int):
    """Sort the directives of an item by name, keeping equal names in order."""
    var ids = store.directive_items(store.items[item].directives)
    if len(ids) < 2:
        return
    var sorted = List[Int]()
    var index = 0
    while index < len(ids):
        var id = ids[index]
        index += 1
        var at = len(sorted)
        while at > 0 and store.less(
            store.directives[id].name, store.directives[sorted[at - 1]].name
        ):
            at -= 1
        sorted.insert(at, id)
    store.items[item].directives = store.directive_list(sorted)


def _normalize_fields(mut store: Store, set: Int):
    """Drop an alias equal to the name, and sort directives, as upstream
    `normalize_fields`. Like upstream, it does not go below a field."""
    var child = store.items[set].first
    while child != NONE:
        var kind = store.items[child].kind
        if kind == ItemKind.FIELD:
            if store.items[child].alias == store.items[child].name:
                store.items[child].alias = NONE
            _sort_directives(store, child)
        elif kind == ItemKind.FRAGMENT:
            _normalize_fields(store, child)
            _sort_directives(store, child)
        child = store.items[child].next


# --- inline_fragment_spreads ---------------------------------------------


def _inline_spreads(
    mut store: Store,
    fragments: _Fragments,
    set: Int,
    parent_type: Int,
    mut active: List[Int],
) raises:
    """Replace each fragment spread, as upstream `inline_fragment_spreads`."""
    var new_items = List[Int]()
    for selection in store.children(set):
        var kind = store.items[selection].kind
        if kind == ItemKind.FIELD:
            _inline_spreads(store, fragments, selection, NONE, active)
            new_items.append(selection)
        elif kind == ItemKind.FRAGMENT:
            _inline_spreads(
                store, fragments, selection, store.items[selection].name, active
            )
            new_items.append(selection)
        else:
            var spread_name = store.items[selection].name
            var spread_directives = store.items[selection].directives
            var chain_len = 0
            var found: Int
            while True:
                found = fragments.find(spread_name)
                if found == NONE:
                    raise Error(
                        "Fragment definition for '"
                        + store.name(spread_name)
                        + "' not found."
                    )
                var inlineable = (
                    parent_type != NONE
                    and parent_type == fragments.types[found]
                    and spread_directives == NONE
                )
                var only = store.items[fragments.sets[found]].first
                if (
                    inlineable
                    and only != NONE
                    and store.items[only].next == NONE
                    and store.items[only].kind == ItemKind.SPREAD
                ):
                    chain_len += 1
                    if chain_len > len(fragments.names):
                        raise Error(
                            "Cyclic fragment spread detected for '"
                            + store.name(spread_name)
                            + "'."
                        )
                    spread_name = store.items[only].name
                    spread_directives = store.items[only].directives
                    continue
                break
            var fragment_name = fragments.names[found]
            for name in active:
                if name == fragment_name:
                    raise Error(
                        "Cyclic fragment spread detected for '"
                        + store.name(spread_name)
                        + "'."
                    )
            active.append(fragment_name)
            var type_condition = fragments.types[found]
            if (
                parent_type != NONE
                and parent_type == type_condition
                and (spread_directives == NONE)
            ):
                var inlined = store.copy_set(fragments.sets[found])
                _inline_spreads(store, fragments, inlined, parent_type, active)
                for child in store.children(inlined):
                    new_items.append(child)
            else:
                var fragment = store.copy_set(fragments.sets[found])
                store.items[fragment].kind = ItemKind.FRAGMENT
                store.items[fragment].name = type_condition
                store.items[fragment].directives = spread_directives
                _inline_spreads(
                    store, fragments, fragment, type_condition, active
                )
                new_items.append(fragment)
            _ = active.pop()
    store.set_children(set, new_items)


# --- shared helpers -------------------------------------------------------


struct _PossibleTypes(Movable):
    """The object types of each abstract type, as upstream
    `PossibleTypesMap`."""

    var types: Dict[Int, List[Int]]
    """The object types, as symbols, by abstract type."""

    def __init__(out self):
        """Start an empty map."""
        self.types = Dict[Int, List[Int]]()

    def get(self, store: Store, type_name: Int) raises -> List[Int]:
        """Return the object types of a type, or raise."""
        var found = self.types.get(type_name)
        if not found:
            raise Error(
                "Possible types for '" + store.name(type_name) + "' not found."
            )
        return found.value().copy()

    def contains(self, type_name: Int, object_name: Int) -> Bool:
        """Return True if an object type is a possible type of a type."""
        var found = self.types.get(type_name)
        if not found:
            return False
        for name in found.value():
            if name == object_name:
                return True
        return False


def _add_unique(mut out: List[Int], name: Int):
    """Add a symbol to a list once."""
    for known in out:
        if known == name:
            return
    out.append(name)


def _sorted_by_name(store: Store, names: List[Int]) -> List[Int]:
    """Return symbols sorted by their text."""
    var out = List[Int]()
    for name in names:
        var at = len(out)
        while at > 0 and store.less(name, out[at - 1]):
            at -= 1
        out.insert(at, name)
    return out^


def _definition(store: Store, state: SupergraphState, name: Int) raises -> Int:
    """Return the index of a definition, or raise `SchemaTypeNotFound`."""
    var found = state.definition(name)
    if found == NONE:
        raise Error("Schema type '" + store.name(name) + "' not found.")
    return found


def _field_index(
    store: Store, state: SupergraphState, parent: Int, field: Int
) raises -> Int:
    """Return the index of a field in its parent, or raise
    `FieldNotFoundInType`."""
    ref definition = state.definitions[parent]
    var index = definition.field_index(store.items[field].name)
    if index == NONE:
        raise Error(
            "Field '"
            + store.name(store.items[field].name)
            + "' not found in type '"
            + store.name(definition.name)
            + "'."
        )
    return index


def _field_type(
    store: Store, state: SupergraphState, parent: Int, field: Int
) raises -> Int:
    """Return the definition of the named type a field returns, or raise."""
    var index = _field_index(store, state, parent, field)
    return _definition(
        store,
        state,
        state.definitions[parent].fields[index].field_type.inner_type(),
    )


def _is_meta(store: Store, item: Int) -> Bool:
    """Return True for a field whose name starts with `__`."""
    return store.name(store.items[item].name).startswith("__")


def _is_abstract(state: SupergraphState, definition: Int) -> Bool:
    """Return True for an interface or a union."""
    var kind = state.definitions[definition].kind
    return kind == DefinitionKind.INTERFACE or kind == DefinitionKind.UNION


def _is_object(state: SupergraphState, definition: Int) -> Bool:
    """Return True for an object type."""
    return state.definitions[definition].kind == DefinitionKind.OBJECT


def _in_subgraph(
    state: SupergraphState, definition: Int, graph_id: Int
) -> Bool:
    """Return True when there is no subgraph, or the type is in it."""
    return graph_id == NONE or state.definitions[
        definition
    ].is_defined_in_subgraph(graph_id)


def _new_fragment(
    mut store: Store, type_name: Int, directives: Int, children: List[Int]
) -> Int:
    """Add an inline fragment that holds copies of items."""
    var fragment = store.add_item(ItemKind.FRAGMENT, type_name)
    store.items[fragment].directives = directives
    for child in children:
        store.append(fragment, store.copy_item(child))
    return fragment


# --- flatten_fragments ---------------------------------------------------


def _flatten_possible_types(
    store: Store, state: SupergraphState, graph_id: Int
) -> _PossibleTypes:
    """Build the possible types of `flatten_fragments`: only the types and
    the members of one subgraph, when there is one."""
    var out = _PossibleTypes()
    var index = 0
    while index < len(state.definitions):
        ref definition = state.definitions[index]
        index += 1
        if not _in_subgraph(state, index - 1, graph_id):
            continue
        if definition.kind == DefinitionKind.UNION:
            var members = List[Int]()
            var at = 0
            while at < len(definition.union_members):
                ref member = definition.union_members[at]
                if graph_id == NONE or member.graph == graph_id:
                    _add_unique(members, member.member)
                at += 1
            out.types[definition.name] = members^
        elif definition.kind == DefinitionKind.INTERFACE:
            var objects = List[Int]()
            var other = 0
            while other < len(state.definitions):
                ref object = state.definitions[other]
                other += 1
                if object.kind != DefinitionKind.OBJECT:
                    continue
                if not _in_subgraph(state, other - 1, graph_id):
                    continue
                for implements in object.join_implements:
                    if (
                        graph_id == NONE or implements.graph_id == graph_id
                    ) and implements.interface == definition.name:
                        _add_unique(objects, object.name)
                        break
            out.types[definition.name] = objects^
    return out^


def _flatten_set(
    mut store: Store,
    state: SupergraphState,
    possible: _PossibleTypes,
    parent: Int,
    set: Int,
) raises:
    """Flatten the fragments of one selection set, as upstream
    `flatten_fragments`."""
    var new_items = List[Int]()
    for selection in store.children(set):
        var kind = store.items[selection].kind
        if kind == ItemKind.FIELD:
            if not _is_meta(store, selection) and not store.is_empty(selection):
                var inner = _field_type(store, state, parent, selection)
                _flatten_set(store, state, possible, inner, selection)
            new_items.append(selection)
        else:
            for item in _flatten_fragment(
                store, state, possible, parent, selection
            ):
                new_items.append(item)
    store.set_children(set, new_items)


def _flatten_fragment(
    mut store: Store,
    state: SupergraphState,
    possible: _PossibleTypes,
    parent: Int,
    fragment: Int,
) raises -> List[Int]:
    """Flatten one inline fragment, as upstream `process_inline_fragment`."""
    var parent_name = state.definitions[parent].name
    var condition = store.items[fragment].name
    if condition == NONE or condition == parent_name:
        _flatten_set(store, state, possible, parent, fragment)
        if store.items[fragment].directives == NONE:
            return store.children(fragment)
        if condition == NONE:
            store.items[fragment].name = parent_name
            if _is_abstract(state, parent):
                return _expand_abstract(
                    store, state, possible, parent, fragment
                )
        return [fragment]
    var condition_definition = _definition(store, state, condition)
    if _is_abstract(state, condition_definition):
        return _expand_abstract(store, state, possible, parent, fragment)
    if not _is_object(state, condition_definition):
        return List[Int]()
    if _is_object(state, parent):
        return List[Int]()
    _flatten_set(store, state, possible, condition_definition, fragment)
    return [fragment]


def _applies_to(
    store: Store, possible: _PossibleTypes, fragment: Int, object_name: Int
) -> Bool:
    """Return True if a fragment applies to an object type."""
    var condition = store.items[fragment].name
    if condition == NONE or condition == object_name:
        return True
    return possible.contains(condition, object_name)


def _expand_abstract(
    mut store: Store,
    state: SupergraphState,
    possible: _PossibleTypes,
    parent: Int,
    fragment: Int,
) raises -> List[Int]:
    """Split a fragment on an abstract type into one fragment per object
    type, as upstream `expand_abstract_fragment`."""
    var new_items = List[Int]()
    var condition = store.items[fragment].name
    var condition_objects = possible.get(store, condition)
    var parent_name = state.definitions[parent].name
    var parent_objects: List[Int]
    if _is_abstract(state, parent):
        parent_objects = possible.get(store, parent_name)
    else:
        parent_objects = [parent_name]
    var intersecting = List[Int]()
    for name in condition_objects:
        for other in parent_objects:
            if name == other:
                intersecting.append(name)
                break
    var fragment_directives = store.items[fragment].directives
    var inherited = List[Int]()
    for child in store.children(fragment):
        if store.items[child].kind == ItemKind.FIELD:
            inherited.append(child)
    for object_name in _sorted_by_name(store, intersecting):
        var object_definition = _definition(store, state, object_name)
        var specific = List[Int]()
        var any_directives = False
        for child in store.children(fragment):
            if store.items[child].kind == ItemKind.FRAGMENT and _applies_to(
                store, possible, child, object_name
            ):
                specific.append(child)
                if store.items[child].directives != NONE:
                    any_directives = True
        if any_directives:
            var inherited_fragment = _new_fragment(
                store, object_name, fragment_directives, inherited
            )
            _flatten_set(
                store, state, possible, object_definition, inherited_fragment
            )
            if not store.is_empty(inherited_fragment):
                new_items.append(inherited_fragment)
            # `specific` holds the fragment that has directives.
            var at = 0
            while at < len(specific):
                var copy = store.copy_item(specific[at])
                at += 1
                store.items[copy].name = object_name
                var needs_wrapping = False
                var own = store.directive_items(store.items[copy].directives)
                var to_merge = List[Int]()
                for parent_directive in store.directive_items(
                    fragment_directives
                ):
                    var same_named = NONE
                    for directive in own:
                        if (
                            store.directives[directive].name
                            == store.directives[parent_directive].name
                        ):
                            same_named = directive
                            break
                    if same_named == NONE:
                        to_merge.append(parent_directive)
                    elif same_named != parent_directive:
                        needs_wrapping = True
                        break
                _flatten_set(store, state, possible, object_definition, copy)
                if store.is_empty(copy):
                    continue
                if needs_wrapping:
                    var wrapper = store.add_item(ItemKind.FRAGMENT, object_name)
                    store.items[wrapper].directives = fragment_directives
                    store.append(wrapper, copy)
                    new_items.append(wrapper)
                else:
                    for directive in to_merge:
                        own.append(directive)
                    store.items[copy].directives = store.directive_list(own)
                    new_items.append(copy)
            continue
        var new_fragment = _new_fragment(
            store, object_name, fragment_directives, inherited
        )
        # No fragment of `specific` has directives here, so the new fragment
        # keeps the directives of `fragment` alone.
        for sub in specific:
            for child in store.children(sub):
                store.append(new_fragment, store.copy_item(child))
        _flatten_set(store, state, possible, object_definition, new_fragment)
        if not store.is_empty(new_fragment):
            new_items.append(new_fragment)
    return new_items^


# --- type_expand ---------------------------------------------------------


def _expand_possible_types(
    store: Store, state: SupergraphState, graph_id: Int
) -> _PossibleTypes:
    """Build the possible types of `type_expand`: the abstract types of one
    subgraph, when there is one, with every member and implementation."""
    var out = _PossibleTypes()
    var index = 0
    while index < len(state.definitions):
        ref definition = state.definitions[index]
        index += 1
        if not _in_subgraph(state, index - 1, graph_id):
            continue
        if definition.kind == DefinitionKind.UNION:
            var members = List[Int]()
            var at = 0
            while at < len(definition.union_members):
                _add_unique(members, definition.union_members[at].member)
                at += 1
            out.types[definition.name] = members^
        elif definition.kind == DefinitionKind.INTERFACE:
            var objects = List[Int]()
            var other = 0
            while other < len(state.definitions):
                ref object = state.definitions[other]
                other += 1
                if object.kind != DefinitionKind.OBJECT:
                    continue
                for implements in object.join_implements:
                    if implements.interface == definition.name:
                        _add_unique(objects, object.name)
                        break
            out.types[definition.name] = objects^
    return out^


def _expand_set(
    mut store: Store,
    state: SupergraphState,
    possible: _PossibleTypes,
    type_definition: Int,
    set: Int,
) raises:
    """Expand the fields of an interface into its object types, as upstream
    `type_expand`."""
    var objects = List[Int]()
    var is_interface = (
        state.definitions[type_definition].kind == DefinitionKind.INTERFACE
    )
    if is_interface:
        # The possible types of an interface are defined object types.
        for name in possible.get(
            store, state.definitions[type_definition].name
        ):
            objects.append(state.definition(name))
    var new_items = List[Int]()
    for selection in store.children(set):
        var kind = store.items[selection].kind
        if kind == ItemKind.FIELD:
            if _is_meta(store, selection):
                new_items.append(selection)
                continue
            _ = _field_index(store, state, type_definition, selection)
            if is_interface and _expand_field(
                store,
                state,
                possible,
                objects,
                type_definition,
                selection,
                new_items,
            ):
                continue
            if not store.is_empty(selection):
                var inner = _field_type(
                    store, state, type_definition, selection
                )
                _expand_set(store, state, possible, inner, selection)
            new_items.append(selection)
        else:
            # `flatten_fragments` gave every fragment a known type.
            _expand_set(
                store,
                state,
                possible,
                state.definition(store.items[selection].name),
                selection,
            )
            new_items.append(selection)
    store.set_children(set, new_items)


def _expand_field(
    mut store: Store,
    state: SupergraphState,
    possible: _PossibleTypes,
    objects: List[Int],
    interface: Int,
    field: Int,
    mut new_items: List[Int],
) raises -> Bool:
    """Replace an interface field with one fragment per object type, when
    an object type resolves it differently, as upstream
    `handle_type_expansion_candidate`."""
    var field_name = store.items[field].name
    var should_expand = False
    for object in objects:
        ref definition = state.definitions[object]
        var index = definition.field_index(field_name)
        if index == NONE:
            should_expand = True
            break
        for join_field in definition.fields[index].join_field:
            if join_field.external or join_field.used_overridden:
                should_expand = True
            elif join_field.override_value and state.subgraph_exists_by_name(
                store, join_field.override_value.value()
            ):
                should_expand = True
        if should_expand:
            break
    if not should_expand:
        ref interface_definition = state.definitions[interface]
        var with_interface = 0
        var object_graphs = List[Int]()
        for join_type in interface_definition.join_types:
            if join_type.is_interface_object:
                object_graphs.append(join_type.graph_id)
            else:
                with_interface += 1
        if with_interface <= 1:
            return False
        var index = interface_definition.field_index(field_name)
        ref join_fields = interface_definition.fields[index].join_field
        if len(join_fields) == 0:
            return False
        var all_without_graph = True
        var resolving = 0
        var on_interface_object = False
        var at = 0
        while at < len(join_fields):
            ref join_field = join_fields[at]
            at += 1
            if join_field.graph_id != NONE:
                all_without_graph = False
                if not join_field.external:
                    resolving += 1
                    for graph in object_graphs:
                        if graph == join_field.graph_id:
                            on_interface_object = True
        if all_without_graph or on_interface_object:
            return False
        if resolving >= with_interface:
            return False
    var names = List[Int]()
    var pos = 0
    while pos < len(objects):
        names.append(state.definitions[objects[pos]].name)
        pos += 1
    var directives = store.items[field].directives
    var sorted = _sorted_by_name(store, names)
    pos = 0
    while pos < len(sorted):
        var name = sorted[pos]
        pos += 1
        var object = state.definition(name)
        var copy = store.copy_item(field)
        if not store.is_empty(copy):
            ref definition = state.definitions[object]
            var index = definition.field_index(field_name)
            if index != NONE:
                var inner = _definition(
                    store,
                    state,
                    definition.fields[index].field_type.inner_type(),
                )
                _expand_set(store, state, possible, inner, copy)
        var fragment = store.add_item(ItemKind.FRAGMENT, name)
        store.items[fragment].directives = directives
        store.append(fragment, copy)
        new_items.append(fragment)
    return True


# --- merge_inline_fragments ----------------------------------------------


def _append_children(mut store: Store, target: Int, source: Int):
    """Move the children of one item to the end of another."""
    for child in store.children(source):
        store.items[child].next = NONE
        store.append(target, child)
    store.clear(source)


def _merge_fragments_set(
    mut store: Store, state: SupergraphState, set: Int, parent: Int
) raises:
    """Merge equal inline fragments, as upstream `merge_inline_fragments`."""
    var new_items = List[Int]()
    for selection in store.children(set):
        var kind = store.items[selection].kind
        if kind == ItemKind.FIELD:
            if not _is_meta(store, selection) and not store.is_empty(selection):
                var inner = _field_type(store, state, parent, selection)
                _merge_fragments_set(store, state, selection, inner)
            new_items.append(selection)
        else:
            # Every fragment has a known type by now.
            var condition = store.items[selection].name
            var child_parent = state.definition(condition)
            _merge_fragments_set(store, state, selection, child_parent)
            _flatten_redundant(store, selection)
            var merged = False
            for existing in new_items:
                if (
                    store.items[existing].kind == ItemKind.FRAGMENT
                    and store.items[existing].name == condition
                    and store.items[existing].directives
                    == store.items[selection].directives
                ):
                    _append_children(store, existing, selection)
                    _merge_fragments_set(store, state, existing, child_parent)
                    merged = True
                    break
            if not merged:
                new_items.append(selection)
    store.set_children(set, new_items)


def _flatten_redundant(mut store: Store, parent: Int):
    """Splice a nested fragment with the same type condition into its
    parent, as upstream `flatten_redundant_nested_inline_fragments`."""
    var new_items = List[Int]()
    var name = store.items[parent].name
    var directives = store.items[parent].directives
    for child in store.children(parent):
        if (
            store.items[child].kind == ItemKind.FRAGMENT
            and store.items[child].name == name
            and (
                store.items[child].directives == NONE
                or store.items[child].directives == directives
            )
        ):
            for grandchild in store.children(child):
                new_items.append(grandchild)
        else:
            new_items.append(child)
    store.set_children(parent, new_items)


# --- flatten_matching_object_fragments -----------------------------------


def _matching_set(
    mut store: Store, state: SupergraphState, set: Int, parent: Int
) raises:
    """Walk a set for `flatten_matching_object_fragments`."""
    var child = store.items[set].first
    while child != NONE:
        var kind = store.items[child].kind
        if kind == ItemKind.FIELD:
            if not _is_meta(store, child) and not store.is_empty(child):
                var inner = _field_type(store, state, parent, child)
                _matching_set(store, state, child, inner)
                if _is_object(state, inner):
                    _flatten_matching(
                        store, child, state.definitions[inner].name
                    )
        else:
            _matching_set(
                store, state, child, state.definition(store.items[child].name)
            )
        child = store.items[child].next


def _flatten_matching(mut store: Store, field: Int, object_name: Int):
    """Splice `... on T` into a field of object type `T`, unless the
    fragment has directives or selects `__typename`."""
    var new_items = List[Int]()
    # The caller passes a field with children.
    var children = store.children(field)
    var index = 0
    while index < len(children):
        var child = children[index]
        index += 1
        # `flatten_fragments` dropped every fragment on another object type,
        # so a fragment here is on `object_name`, and it is not empty.
        if (
            store.items[child].kind == ItemKind.FRAGMENT
            and store.items[child].directives == NONE
            and not _selects_typename(store, child)
        ):
            var grandchildren = store.children(child)
            var at = 0
            while at < len(grandchildren):
                new_items.append(grandchildren[at])
                at += 1
        else:
            new_items.append(child)
    store.set_children(field, new_items)


def _selects_typename(store: Store, set: Int) -> Bool:
    """Return True if a set has a `__typename` field at its top."""
    var child = store.items[set].first
    while child != NONE:
        # Only a field can have this name: a fragment's name is a type,
        # and no type name starts with `__`.
        if store.name(store.items[child].name) == "__typename":
            return True
        child = store.items[child].next
    return False


# --- merge_fields and drop_duplicated_fields -----------------------------


def _same_field(store: Store, a: Int, b: Int) -> Bool:
    """Return True for equal alias, name, arguments and directives."""
    ref left = store.items[a]
    ref right = store.items[b]
    return (
        left.alias == right.alias
        and left.name == right.name
        and left.args == right.args
        and left.directives == right.directives
    )


def _merge_fields_set(mut store: Store, set: Int):
    """Merge equal fields, as upstream `merge_fields`."""
    var new_items = List[Int]()
    for selection in store.children(set):
        var kind = store.items[selection].kind
        if kind == ItemKind.FIELD:
            _merge_fields_set(store, selection)
            var merged = False
            for existing in new_items:
                if store.items[existing].kind == ItemKind.FIELD and _same_field(
                    store, selection, existing
                ):
                    _append_children(store, existing, selection)
                    _merge_fields_set(store, existing)
                    merged = True
                    break
            if not merged:
                new_items.append(selection)
        else:
            _merge_fields_set(store, selection)
            new_items.append(selection)
    store.set_children(set, new_items)


def _drop_duplicates_set(mut store: Store, set: Int):
    """Drop a repeated leaf field, as upstream `drop_duplicated_fields`.
    Like upstream, it goes below fragments only."""
    if store.count(set) < 2:
        return
    var new_items = List[Int]()
    var children = store.children(set)
    var index = 0
    while index < len(children):
        var selection = children[index]
        index += 1
        var kind = store.items[selection].kind
        if kind == ItemKind.FIELD:
            var duplicate = False
            for kept in new_items:
                if (
                    store.items[kept].kind == ItemKind.FIELD
                    and _same_field(store, selection, kept)
                    and store.is_empty(selection)
                    and store.is_empty(kept)
                ):
                    duplicate = True
                    break
            if duplicate:
                continue
        else:
            _drop_duplicates_set(store, selection)
        new_items.append(selection)
    store.set_children(set, new_items)


# --- conversion into the planner AST -------------------------------------


def _apply_conditions(mut store: Store, set: Int):
    """Read `skip` and `include` from the directives, as upstream
    `ConditionsPair`: a later variable condition replaces an earlier one.
    """
    var skip_name = store.sym("skip")
    var include_name = store.sym("include")
    var stack: List[Int] = [set]
    while len(stack) > 0:
        var child = store.items[stack.pop()].first
        while child != NONE:
            var skip = NONE
            var include = NONE
            for id in store.directive_items(store.items[child].directives):
                var directive = store.directives[id].copy()
                if directive.if_variable == NONE:
                    continue
                if directive.name == skip_name:
                    skip = directive.if_variable
                elif directive.name == include_name:
                    include = directive.if_variable
            store.items[child].skip = skip
            store.items[child].include = include
            stack.append(child)
            child = store.items[child].next


def _inject_skipped_typename(
    mut store: Store, state: SupergraphState, set: Int, parent_type: Int
):
    """Add a skipped `__typename` to an empty composite field, as upstream
    `inject_skipped_typename_for_empty_composites`."""
    var child = store.items[set].first
    while child != NONE:
        var kind = store.items[child].kind
        if kind == ItemKind.FIELD:
            var field_type = NONE
            # The root type, a fragment type and a composite field type are
            # all defined.
            var parent = state.definition(parent_type)
            var index = state.definitions[parent].field_index(
                store.items[child].name
            )
            if index != NONE:
                field_type = (
                    state.definitions[parent]
                    .fields[index]
                    .field_type.inner_type()
                )
            if field_type != NONE:
                var found = state.definition(field_type)
                if (
                    found != NONE
                    and state.definitions[found].is_composite_type()
                ):
                    _inject_skipped_typename(store, state, child, field_type)
                    if store.is_empty(child):
                        store.append(
                            child,
                            store.add_item(
                                ItemKind.FIELD,
                                store.sym("__typename"),
                                omit=True,
                            ),
                        )
        else:
            _inject_skipped_typename(
                store, state, child, store.items[child].name
            )
        child = store.items[child].next


# --- the pipeline --------------------------------------------------------


def _run_passes(
    mut store: Store,
    state: SupergraphState,
    set: Int,
    root_type: Int,
    graph_id: Int,
    fragments: _Fragments,
) raises:
    """Run the passes after `drop_skipped_fields` on a root set."""
    _normalize_fields(store, set)
    for fragment in fragments.sets:
        _normalize_fields(store, fragment)
    var active = List[Int]()
    _inline_spreads(store, fragments, set, NONE, active)
    var root = _definition(store, state, root_type)
    var flatten_types = _flatten_possible_types(store, state, graph_id)
    _flatten_set(store, state, flatten_types, root, set)
    var expand_types = _expand_possible_types(store, state, graph_id)
    _expand_set(store, state, expand_types, root, set)
    _merge_fragments_set(store, state, set, root)
    _matching_set(store, state, set, root)
    _merge_fields_set(store, set)
    _drop_duplicates_set(store, set)
    _apply_conditions(store, set)


def normalize_operation(
    mut store: Store,
    state: SupergraphState,
    document: Document,
    operation_name: Optional[String] = None,
) raises -> OperationDefinition:
    """Normalize the operation of an executable document, as upstream
    `normalize_operation`.

    Args:
        store: The store for the selections.
        state: The supergraph.
        document: The parsed operation document.
        operation_name: The operation to plan; the first one when absent.

    Returns:
        The normalized operation.

    Raises:
        Error: When the operation is not found, or a type, a field or a
            fragment is unknown, as upstream `NormalizationError`.
    """
    var operation = NO_NODE
    var fragments = _Fragments()
    var definition = document.child(document.root, Role.DEFINITION)
    while definition != NO_NODE:
        var kind = document.kind(definition)
        if kind == Kind.FRAGMENT_DEFINITION:
            var set = store.new_set()
            var children = document.child(definition, Role.SELECTION_SET)
            _convert_set(store, document, children, set)
            fragments.names.append(store.sym(document.name(definition)))
            fragments.types.append(
                store.sym(
                    document.name(
                        document.child(definition, Role.TYPE_CONDITION)
                    )
                )
            )
            fragments.sets.append(set)
        elif kind == Kind.OPERATION_DEFINITION and operation == NO_NODE:
            if not operation_name:
                operation = definition
            elif document.name(definition) == operation_name.value():
                operation = definition
        definition = document.next_with_role(definition)
    if operation == NO_NODE:
        if operation_name:
            raise Error(
                "Specified operation '"
                + operation_name.value()
                + "' not found."
            )
        raise Error("An operation was expected, but none were present.")
    var kind = OperationKind(document.operation(operation).value)
    var set = store.new_set()
    _convert_set(
        store, document, document.child(operation, Role.SELECTION_SET), set
    )
    var roots = RootTypes(
        state.query_type, state.mutation_type, state.subscription_type
    )
    var root_type = roots.type_for(kind)
    _run_passes(store, state, set, root_type, NONE, fragments)
    _inject_skipped_typename(store, state, set, root_type)
    var out = OperationDefinition(kind, set)
    if document.child(operation, Role.NAME) != NO_NODE:
        out.name = store.sym(document.name(operation))
    var variable = document.child(operation, Role.VARIABLE_DEFINITION)
    while variable != NO_NODE:
        var default_node = document.child(variable, Role.DEFAULT_VALUE)
        out.variables.append(
            VariableDefinition(
                store.sym(
                    document.name(document.child(variable, Role.VARIABLE))
                ),
                type_node_from_ast(
                    store, document, document.child(variable, Role.TYPE)
                ),
                value_from_ast(store, document, default_node) if default_node
                != NO_NODE else NONE,
            )
        )
        variable = document.next_with_role(variable)
    out.has_variables = len(out.variables) > 0
    return out^


def selection_set_from_text(mut store: Store, text: String) raises -> Int:
    """Read the selection set of a `{ ... }` document as it is, with no
    normalization, as upstream `SelectionSet::from` a parsed set.

    Args:
        store: The store for the selections.
        text: A document with one shorthand query.

    Returns:
        The selection set, a `ROOT` item.

    Raises:
        Error: When the text does not parse.
    """
    var document = parse(text)
    var operation = document.child(document.root, Role.DEFINITION)
    var set = store.new_set()
    _convert_set(
        store, document, document.child(operation, Role.SELECTION_SET), set
    )
    _apply_conditions(store, set)
    return set


def normalize_field_set(
    mut store: Store,
    state: SupergraphState,
    type_name: Int,
    graph_id: Int,
    fields: String,
) raises -> Int:
    """Normalize a `@key`, `@requires` or `@provides` field set, as
    upstream `normalize_fields_argument_value_mut`.

    Args:
        store: The store for the selections.
        state: The supergraph.
        type_name: The type the field set selects from, as a symbol.
        graph_id: The subgraph, as a graph id symbol.
        fields: The field set text, without braces.

    Returns:
        The normalized selection set, a `ROOT` item.

    Raises:
        Error: When the field set does not parse or does not normalize.
    """
    var document = parse("{" + fields + "}")
    var operation = document.child(document.root, Role.DEFINITION)
    var set = store.new_set()
    _convert_set(
        store, document, document.child(operation, Role.SELECTION_SET), set
    )
    _run_passes(store, state, set, type_name, graph_id, _Fragments())
    return set
