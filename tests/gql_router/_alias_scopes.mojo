# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The helpers of `test_plan_requires_alias_scopes.mojo`, as the helper
functions of Hive Router `1a29df9`
`bin/router/src/query_planner/tests/requires_alias_scopes.rs`.

Upstream reads the `serde_json` form of a plan. This port has no JSON form,
so the helpers walk the plan arena and read the same fields: the service,
the operation text, the representations, the conditions and the paths.
Upstream parses the fetch operations with `graphql_tools`; here
`gql_language` parses them.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.parser import parse
from gql_router.ast import NONE, ItemKind
from gql_router.plan_nodes import (
    FlattenNodePath,
    PathSegmentKind,
    PlanNodeKind,
    QueryPlan,
)
from gql_router.planner import Planner
from gql_router.store import Store


@fieldwise_init
struct Read(Copyable, Movable):
    """A field that a representation reads, as upstream `read_keys`."""

    var type_name: String
    """The innermost type condition, or empty."""
    var key: String
    """The response key the field is read from: its name."""


@fieldwise_init
struct Fetch(Copyable, Movable):
    """One fetch, or one entity call of a batch, as upstream `Fetch`."""

    var service: String
    """The subgraph."""
    var operation: String
    """The operation text."""
    var price_reads: List[Read]
    """What the representations read for `price`, as upstream
    `read_keys(&requires, "price")`."""
    var conditions: List[String]
    """The variables of the `Condition` nodes around the fetch, `!x` for an
    else branch."""
    var paths: List[List[String]]
    """Where the fetched objects go, as response keys."""
    var entity_alias: String
    """In a batch, the alias of this entity call; empty otherwise."""


@fieldwise_init
struct Selected(Copyable, Movable):
    """A field of an operation with some response key, as upstream
    `Selected`."""

    var arguments: String
    """The arguments, as `name: value` joined by `, `."""
    var types: List[String]
    """The type conditions on the way to the field, outermost first."""
    var includes: List[String]
    """The `@include(if:)` variables on the way, the field's own too."""

    def applies_to(self, type_name: String) -> Bool:
        """Return True if objects of a type get this field. `Node` counts
        for every object.

        Args:
            type_name: The object type.

        Returns:
            Whether every type condition matches.
        """
        for t in self.types:
            if t != type_name and t != "Node":
                return False
        return True


@fieldwise_init
struct Write(Copyable, Movable):
    """A field that a fetch puts into the response, as upstream `Write`."""

    var service: String
    """The subgraph."""
    var location: List[String]
    """Where the object with the field is, as response keys."""
    var key: String
    """The response key."""
    var name: String
    """The field name."""
    var arguments: String
    """The arguments text."""


def contains(list: List[String], text: String) -> Bool:
    """Return True if a list has some text.

    Args:
        list: The list.
        text: The text.

    Returns:
        Whether the text is in the list.
    """
    for item in list:
        if item == text:
            return True
    return False


def joined(list: List[String], sep: String) -> String:
    """Join texts.

    Args:
        list: The texts.
        sep: The separator.

    Returns:
        The joined text.
    """
    var out = String()
    for index in range(len(list)):
        if index > 0:
            out += sep
        out += list[index]
    return out^


def _response_keys(store: Store, path: FlattenNodePath) -> List[String]:
    """Return the field steps of a path, as upstream `response_keys`."""
    var out = List[String]()
    for segment in path.segments:
        if segment.kind == PathSegmentKind.FIELD:
            out.append(String(store.name(segment.name)))
    return out^


def _read_keys(
    store: Store,
    set: Int,
    type_name: String,
    field: String,
    mut out: List[Read],
):
    """Collect the response keys that a representation reads a field from,
    as upstream `read_keys`."""
    if set == NONE:
        return
    for child in store.children(set):
        ref item = store.items[child]
        if item.kind == ItemKind.FRAGMENT:
            var inner = type_name
            if item.name != NONE:
                inner = String(store.name(item.name))
            _read_keys(store, child, inner, field, out)
            continue
        if item.kind != ItemKind.FIELD:
            continue
        var name = String(store.name(item.name))
        var key = name
        if item.alias != NONE:
            key = String(store.name(item.alias))
        if key == field:
            out.append(Read(type_name, name))


def _price_reads(store: Store, requires: Int) -> List[Read]:
    """Return what the representations read for `price`."""
    var out = List[Read]()
    _read_keys(store, requires, "", "price", out)
    return out^


def _walk(
    store: Store,
    plan: QueryPlan,
    node: Int,
    conditions: List[String],
    path: List[String],
    mut out: List[Fetch],
):
    """Collect the fetches under a node, as upstream `fetches`."""
    if node == NONE:
        return
    ref found = plan.nodes[node]
    if found.kind == PlanNodeKind.FETCH:
        ref fetch = plan.fetches[found.fetch]
        out.append(
            Fetch(
                String(store.name(fetch.service_name)),
                fetch.operation.document_str,
                _price_reads(store, fetch.requires),
                conditions.copy(),
                [path.copy()],
                String(),
            )
        )
    elif found.kind == PlanNodeKind.FLATTEN:
        _walk(
            store,
            plan,
            found.node,
            conditions,
            _response_keys(store, found.path),
            out,
        )
    elif found.kind == PlanNodeKind.BATCH_FETCH:
        # Each entity call in a batch has its own representations.
        ref batch = plan.batches[found.fetch]
        for ref alias in batch.aliases:
            var paths = List[List[String]]()
            for ref merge_path in alias.merge_paths:
                paths.append(_response_keys(store, merge_path))
            out.append(
                Fetch(
                    String(store.name(batch.service_name)),
                    batch.operation.document_str,
                    _price_reads(store, alias.requires),
                    conditions.copy(),
                    paths^,
                    String(store.name(alias.alias)),
                )
            )
    elif found.kind == PlanNodeKind.CONDITION:
        var variable = String(store.name(found.condition))
        if found.if_clause != NONE:
            var inner = conditions.copy()
            inner.append(variable)
            _walk(store, plan, found.if_clause, inner, path, out)
        if found.else_clause != NONE:
            var inner = conditions.copy()
            inner.append("!" + variable)
            _walk(store, plan, found.else_clause, inner, path, out)
    else:
        for child in found.nodes:
            _walk(store, plan, child, conditions, path, out)


def plan_fetches(sdl: String, query: String) raises -> List[Fetch]:
    """Plan an operation and return its fetches, as upstream `plan` and
    then `fetches`.

    Args:
        sdl: The supergraph SDL.
        query: The operation.

    Returns:
        The fetches, in plan order.

    Raises:
        Error: When planning fails.
    """
    var planner = Planner(sdl)
    var operation = planner.normalize(query)
    var plan = planner.plan(operation)
    var out = List[Fetch]()
    _walk(planner.store, plan, plan.node, List[String](), List[String](), out)
    return out^


def root_fetch(fetches: List[Fetch], service: String) raises -> Fetch:
    """Return the first fetch to a service that is not an entity call.

    Args:
        fetches: The fetches.
        service: The subgraph.

    Returns:
        The fetch.

    Raises:
        Error: When there is none.
    """
    for ref fetch in fetches:
        if fetch.service == service and "_entities" not in fetch.operation:
            return fetch.copy()
    raise Error("expected a root fetch to " + service)


def by_service(fetches: List[Fetch], service: String) -> List[Fetch]:
    """Return the fetches to a service.

    Args:
        fetches: The fetches.
        service: The subgraph.

    Returns:
        The fetches, in order.
    """
    var out = List[Fetch]()
    for ref fetch in fetches:
        if fetch.service == service:
            out.append(fetch.copy())
    return out^


# --- the fetch operations ------------------------------------------------


def arguments_of(document: Document, field: Int) -> String:
    """Return the arguments of a field, as upstream `arguments_of`.

    Args:
        document: The operation document.
        field: The field node.

    Returns:
        `name: value` per argument, joined by `, `.
    """
    var parts = List[String]()
    var argument = document.child(field, Role.ARGUMENT)
    while argument != NO_NODE:
        var value = document.child(argument, Role.VALUE)
        parts.append(
            String(document.name(argument))
            + ": "
            + String(document.text(value))
        )
        argument = document.next_with_role(argument)
    return joined(parts, ", ")


def _key_of(document: Document, field: Int) -> String:
    """Return the response key of a field node."""
    var alias = document.child(field, Role.ALIAS)
    if alias != NO_NODE:
        return String(document.text(alias))
    return String(document.name(field))


def _includes_of(document: Document, node: Int, mut out: List[String]):
    """Add the variables of the `@include(if:)` directives of a node."""
    var directive = document.child(node, Role.DIRECTIVE)
    while directive != NO_NODE:
        if document.name(directive) == "include":
            var argument = document.child(directive, Role.ARGUMENT)
            while argument != NO_NODE:
                var value = document.child(argument, Role.VALUE)
                if document.kind(value) == Kind.VARIABLE:
                    out.append(String(document.name(value)))
                argument = document.next_with_role(argument)
        directive = document.next_with_role(directive)


def _root_sets(document: Document) -> List[Int]:
    """Return the selection sets of the operations of a document.

    A fetch prints an operation without variables as a bare `{ ... }`.
    """
    var out = List[Int]()
    for definition in document.definitions():
        if document.kind(definition) == Kind.OPERATION_DEFINITION:
            out.append(document.child(definition, Role.SELECTION_SET))
    return out^


def _walk_key(
    document: Document,
    set: Int,
    key: String,
    types: List[String],
    includes: List[String],
    mut out: List[Selected],
):
    """Collect the fields with a response key, as upstream
    `selections_with_key`. Fragment spreads are not followed."""
    if set == NO_NODE:
        return
    var selection = document.child(set, Role.SELECTION)
    while selection != NO_NODE:
        var kind = document.kind(selection)
        if kind == Kind.FIELD:
            var inner = includes.copy()
            _includes_of(document, selection, inner)
            if _key_of(document, selection) == key:
                out.append(
                    Selected(
                        arguments_of(document, selection),
                        types.copy(),
                        inner.copy(),
                    )
                )
            _walk_key(
                document,
                document.child(selection, Role.SELECTION_SET),
                key,
                List[String](),
                inner,
                out,
            )
        elif kind == Kind.INLINE_FRAGMENT:
            var inner_types = types.copy()
            var condition = document.child(selection, Role.TYPE_CONDITION)
            if condition != NO_NODE:
                inner_types.append(String(document.name(condition)))
            var inner = includes.copy()
            _includes_of(document, selection, inner)
            _walk_key(
                document,
                document.child(selection, Role.SELECTION_SET),
                key,
                inner_types,
                inner,
                out,
            )
        selection = document.next_with_role(selection)


def selections_with_key(
    operation: String, key: String
) raises -> List[Selected]:
    """Return the fields of an operation with a response key.

    Args:
        operation: The operation text.
        key: The response key.

    Returns:
        The fields, in document order.

    Raises:
        Error: When the operation does not parse.
    """
    var document = parse(operation)
    var out = List[Selected]()
    for set in _root_sets(document):
        _walk_key(document, set, key, List[String](), List[String](), out)
    return out^


def _collect_writes(
    document: Document,
    set: Int,
    location: List[String],
    service: String,
    mut out: List[Write],
):
    """Collect the fields that a selection set writes, as upstream
    `writes`' `collect`."""
    if set == NO_NODE:
        return
    var selection = document.child(set, Role.SELECTION)
    while selection != NO_NODE:
        var kind = document.kind(selection)
        if kind == Kind.FIELD:
            var key = _key_of(document, selection)
            out.append(
                Write(
                    service,
                    location.copy(),
                    key,
                    String(document.name(selection)),
                    arguments_of(document, selection),
                )
            )
            var inner = location.copy()
            inner.append(key)
            _collect_writes(
                document,
                document.child(selection, Role.SELECTION_SET),
                inner,
                service,
                out,
            )
        elif kind == Kind.INLINE_FRAGMENT:
            _collect_writes(
                document,
                document.child(selection, Role.SELECTION_SET),
                location,
                service,
                out,
            )
        selection = document.next_with_role(selection)


def writes(fetch: Fetch, mut out: List[Write]) raises:
    """Add every field that a fetch puts into the response, and where.

    Args:
        fetch: The fetch.
        out: The destination.

    Raises:
        Error: When the operation does not parse.
    """
    var document = parse(fetch.operation)
    var entities_key = fetch.entity_alias
    if entities_key == "":
        entities_key = "_entities"
    for root in _root_sets(document):
        var entities = NO_NODE
        var selection = document.child(root, Role.SELECTION)
        while selection != NO_NODE:
            if (
                document.kind(selection) == Kind.FIELD
                and document.name(selection) == "_entities"
                and _key_of(document, selection) == entities_key
            ):
                entities = document.child(selection, Role.SELECTION_SET)
                break
            selection = document.next_with_role(selection)
        if entities != NO_NODE:
            for path in fetch.paths:
                _collect_writes(document, entities, path, fetch.service, out)
        else:
            _collect_writes(document, root, List[String](), fetch.service, out)


def key_clashes(fetches: List[Fetch]) raises -> List[String]:
    """Return the fetches that write the same key at the same place with
    different arguments, as upstream `key_clashes`.

    Args:
        fetches: The fetches of a plan.

    Returns:
        One message per clash.

    Raises:
        Error: When an operation does not parse.
    """
    var all = List[Write]()
    for ref fetch in fetches:
        writes(fetch, all)
    var clashes = List[String]()
    for i in range(len(all)):
        for j in range(i + 1, len(all)):
            ref a = all[i]
            ref b = all[j]
            if (
                a.location == b.location
                and a.key == b.key
                and a.arguments != b.arguments
            ):
                clashes.append(
                    "`"
                    + a.key
                    + "` at `"
                    + joined(a.location, ".")
                    + "` is `"
                    + a.name
                    + "("
                    + a.arguments
                    + ")` from "
                    + a.service
                    + " and `"
                    + b.name
                    + "("
                    + b.arguments
                    + ")` from "
                    + b.service
                )
    return clashes^


def wrong_price_reads(fetches: List[Fetch]) raises -> List[String]:
    """Return the readers of `price` that do not get the one they need, as
    upstream `wrong_price_reads`: `pricing` needs the EUR price and `tax`
    the GBP one. A `Node` reader reads for `Cat` and `Dog`.

    Args:
        fetches: The fetches of a plan.

    Returns:
        One message per wrong read.

    Raises:
        Error: When an operation does not parse.
    """
    var shops = by_service(fetches, "shop")
    var wrong = List[String]()
    for ref reader in fetches:
        var expected: String
        if reader.service == "pricing":
            expected = 'currency: "EUR"'
        elif reader.service == "tax":
            expected = 'currency: "GBP"'
        else:
            continue
        for ref entry in reader.price_reads:
            var objects = List[String]()
            if entry.type_name == "Node":
                objects = ["Cat", "Dog"]
            else:
                objects.append(entry.type_name)
            for type_name in objects:
                var values = List[String]()
                for ref shop in shops:
                    for s in selections_with_key(shop.operation, entry.key):
                        if s.applies_to(type_name):
                            values.append(s.arguments)
                var bad = len(values) == 0
                for value in values:
                    if value != expected:
                        bad = True
                if bad:
                    wrong.append(
                        "`"
                        + reader.service
                        + "` reads `"
                        + entry.key
                        + "` of `"
                        + type_name
                        + "`, which `shop` fetches as ["
                        + joined(values, "; ")
                        + "]"
                    )
    return wrong^


# --- overlapping fields ----------------------------------------------------


@fieldwise_init
struct _Field(Copyable, Movable):
    """A field of a selection set, with its parent type."""

    var key: String
    """The response key."""
    var name: String
    """The field name."""
    var arguments: String
    """The arguments text."""
    var parent: String
    """The type condition it is under, or empty for the set's own type."""
    var set: Int
    """Its selection set node, or `NO_NODE`."""


def _fragment_named(document: Document, name: StringSlice) -> Int:
    """Return the fragment definition with a name, or `NO_NODE`."""
    for definition in document.definitions():
        if (
            document.kind(definition) == Kind.FRAGMENT_DEFINITION
            and document.name(definition) == name
        ):
            return definition
    return NO_NODE


def _fields_of(
    document: Document, set: Int, parent: String, mut out: List[_Field]
):
    """Collect the fields of a set, through inline fragments and spreads."""
    if set == NO_NODE:
        return
    var selection = document.child(set, Role.SELECTION)
    while selection != NO_NODE:
        var kind = document.kind(selection)
        if kind == Kind.FIELD:
            out.append(
                _Field(
                    _key_of(document, selection),
                    String(document.name(selection)),
                    arguments_of(document, selection),
                    parent,
                    document.child(selection, Role.SELECTION_SET),
                )
            )
        else:
            var fragment = selection
            if kind == Kind.FRAGMENT_SPREAD:
                fragment = _fragment_named(document, document.name(selection))
            if fragment != NO_NODE:
                var inner = parent
                var condition = document.child(fragment, Role.TYPE_CONDITION)
                if condition != NO_NODE:
                    inner = String(document.name(condition))
                _fields_of(
                    document,
                    document.child(fragment, Role.SELECTION_SET),
                    inner,
                    out,
                )
        selection = document.next_with_role(selection)


def _exclusive(a: String, b: String) -> Bool:
    """Return True if two parent types never meet on one object: two
    different object types of `SHOP_SCHEMA`."""
    if a == "" or b == "" or a == "Node" or b == "Node":
        return False
    return a != b


def _check_sets(document: Document, sets: List[Int], mut errors: List[String]):
    """Check that the fields of some sets, merged, can be merged."""
    var fields = List[_Field]()
    for set in sets:
        _fields_of(document, set, "", fields)
    var keys = List[String]()
    for i in range(len(fields)):
        ref a = fields[i]
        if contains(keys, a.key):
            continue
        keys.append(a.key)
        var same = List[Int]()
        var children = List[Int]()
        for j in range(i, len(fields)):
            if fields[j].key == a.key:
                same.append(j)
                if fields[j].set != NO_NODE:
                    children.append(fields[j].set)
        for x in range(len(same)):
            for y in range(x + 1, len(same)):
                ref c = fields[same[x]]
                ref d = fields[same[y]]
                if _exclusive(c.parent, d.parent):
                    continue
                if c.name != d.name or c.arguments != d.arguments:
                    errors.append(
                        "Fields `"
                        + c.key
                        + "` conflict: `"
                        + c.name
                        + "("
                        + c.arguments
                        + ")` and `"
                        + d.name
                        + "("
                        + d.arguments
                        + ")`"
                    )
        if len(children) > 0:
            _check_sets(document, children, errors)


def overlapping_fields_errors(operation: String) raises -> List[String]:
    """Return the `OverlappingFieldsCanBeMerged` errors of a `shop`
    operation, as upstream `overlapping_fields_errors` with `SHOP_SCHEMA`.

    `SHOP_SCHEMA` has one interface, `Node`, and its objects `Cat` and
    `Dog`. Two fields under `Cat` and `Dog` never meet on one object; any
    other two fields with one response key must have the same name and
    arguments.

    Args:
        operation: The operation text.

    Returns:
        One message per conflict.

    Raises:
        Error: When the operation does not parse.
    """
    var document = parse(operation)
    var errors = List[String]()
    _check_sets(document, _root_sets(document), errors)
    return errors^
