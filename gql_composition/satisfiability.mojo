# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Report queries the subgraphs cannot satisfy.

Port of the object, `@key`, `@external`, and `@requires` part of Hive
Federation Composition v0.27.0 `satisfiablity-rule.ts`. A query field is
checked against each field of the object it returns, and object fields are
followed, as in `users { edges { node { name } } }`. An `@external` field
that is not a key on an extension cannot be resolved in that subgraph. An
`@external` key on a type definition cannot be resolved either. An unlabeled
`@override` removes the field from the source subgraph. A
move to another subgraph needs a `@key` whose fields that subgraph can
resolve. A federation v1 subgraph, which has no `@link`, uses that same
check. A key with `resolvable: false` cannot be used to enter that
subgraph. `@requires` must be resolvable before the field is used. A nested
selection such as `address { id }` is checked on the returned type. A
`@fromContext` argument needs that subgraph's `@context` on an ancestor
type. The type's own `@context` does not satisfy its fields. A labeled
`@override` keeps the source field, and the overriding subgraph must
resolve that field on its own. A nested `@provides` selection such as
`address { city }` resolves those child fields. A query that returns an
interface checks each object that implements it. A union checks each
member the same way. The example query prints `... on` that object. An
`@interfaceObject` that has no resolvable interface `@key` cannot reach
its implementations.

**Differences from upstream.** An interface field is checked on each
implementation, not as its own path.
A labeled `@override` is checked once, with the source field hidden.
`@fromContext`
matches the context name. The selection is not checked again.
Errors are reported in subgraph id order. Hive groups the same errors by
field name. `compose_subgraphs` does not run this check.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.state import TypeKind
from gql_composition.validate import Subgraph, validate_with_facts


@fieldwise_init
struct _Selection(Copyable):
    """One field in a `@requires` or `@provides` selection."""

    var name: String
    """The field name."""
    var children: String
    """The nested selection, or empty."""


def satisfiability_errors(
    subgraphs: List[Subgraph],
) raises -> List[CompositionError]:
    """Return `SATISFIABILITY_ERROR` for object fields the subgraphs cannot
    resolve.

    Args:
        subgraphs: The subgraphs, in any order.

    Returns:
        Subgraph errors when validation fails. Otherwise the unsatisfiable
        queries, in Hive's order.

    Raises:
        Error: Subgraph validation raises, or `Inline fragment without
            type condition is not supported.` as upstream raises it for a
            `@requires` or `@provides` selection such as `... { name }`.
    """
    var facts = List[GraphFacts]()
    var errors = validate_with_facts(subgraphs, facts)
    if len(errors) > 0:
        return errors^
    _refuse_untyped_fragments(facts)
    var found = List[CompositionError]()
    _walk(facts, found)
    return found^


def _refuse_untyped_fragments(facts: List[GraphFacts]) raises:
    """Raise as upstream `SelectionResolver` does for an inline fragment
    without a type condition in a `@requires` or `@provides` selection.

    Args:
        facts: The subgraphs.

    Raises:
        Error: `Inline fragment without type condition is not supported.`
    """
    # Each subgraph has at least its query type.
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_index = 0
        while type_index < len(graph.types):
            ref type = graph.types[type_index]
            type_index += 1
            for field_index in range(len(type.fields)):
                ref field = type.fields[field_index]
                if _has_untyped_fragment(
                    field.requires
                ) or _has_untyped_fragment(field.provides):
                    raise Error(
                        "Inline fragment without type condition is not"
                        " supported."
                    )


def _has_untyped_fragment(text: String) -> Bool:
    """Return True when a field set has `...` and then `{`.

    Args:
        text: A valid field set. It never ends with `...`.

    Returns:
        Whether an inline fragment has no type condition.
    """
    var bytes = text.as_bytes()
    var at = text.find("...")
    while at >= 0:
        var index = at + 3
        while bytes[index] == 32:
            index += 1
        if bytes[index] == 123:
            return True
        at = text.find("...", index)
    return False


def _walk(facts: List[GraphFacts], mut found: List[CompositionError]):
    """Check each query field against the fields of its return type.

    Args:
        facts: The subgraphs, in id order.
        found: Receives one error per unsatisfiable query.
    """
    var seen_queries = List[String]()
    var reported = List[String]()
    var graph_index = -1
    while graph_index + 1 < len(facts):
        graph_index += 1
        var query = _type_named(
            facts[graph_index], facts[graph_index].query_name
        )
        if query < 0:
            continue
        # A query type has at least one field.
        var field_index = -1
        while field_index + 1 < len(facts[graph_index].types[query].fields):
            field_index += 1
            ref root = facts[graph_index].types[query].fields[field_index]
            if root.inaccessible or _seen(seen_queries, root.name):
                continue
            seen_queries.append(String(root.name))
            var returned = _named_type(root.type_text)
            var object_return = _is_object(facts, returned)
            var interface_return = _is_interface(facts, returned)
            var union_return = _is_union(facts, returned)
            if not object_return and not interface_return and not union_return:
                continue
            var owners = _owners(
                facts, facts[graph_index].query_name, root.name
            )
            var args = _arguments(
                facts, owners, facts[graph_index].query_name, root.name
            )
            var owner = -1
            while owner + 1 < len(owners):
                owner += 1
                var path = List[String]()
                path.append(String(root.name))
                var keys = List[String]()
                _push_contexts(facts, keys, facts[graph_index].query_name)
                if object_return:
                    var provided = List[_Selection]()
                    _descend(
                        facts,
                        owners[owner],
                        returned,
                        path,
                        args,
                        provided,
                        keys,
                        found,
                        reported,
                    )
                elif _is_interface_object(facts, owners[owner], returned):
                    _reach_implementations(
                        facts,
                        owners[owner],
                        returned,
                        path,
                        args,
                        keys,
                        found,
                        reported,
                    )
                else:
                    _enter_implementations(
                        facts,
                        owners[owner],
                        returned,
                        path,
                        args,
                        keys,
                        found,
                        reported,
                    )


def _descend(
    facts: List[GraphFacts],
    graph_index: Int,
    type_name: String,
    path: List[String],
    args: String,
    provided: List[_Selection],
    keys: List[String],
    mut found: List[CompositionError],
    mut reported: List[String],
):
    """Check the fields of an object, descending into object fields.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph that was entered.
        type_name: The object type.
        path: Field names from the query field to this type.
        args: Arguments of the query field, or empty.
        provided: Fields supplied by `@provides`, with any nested selection.
        keys: `@context` keys already in scope, each `graph__name`.
        found: Receives one error per unsatisfiable query.
        reported: Leaf coordinates already reported.
    """
    # `type_name` is an object, so it is not an `@interfaceObject` in
    # `graph_index`: Hive refuses a name that is both an object and an
    # interface.
    var seen_fields = List[String]()
    var type_graph = -1
    while type_graph + 1 < len(facts):
        type_graph += 1
        var object_at = _type_named(facts[type_graph], type_name)
        if object_at < 0:
            continue
        # An object type has at least one field.
        var inner = -1
        while inner + 1 < len(facts[type_graph].types[object_at].fields):
            inner += 1
            ref leaf = facts[type_graph].types[object_at].fields[inner]
            if leaf.inaccessible or _seen(seen_fields, leaf.name):
                continue
            seen_fields.append(String(leaf.name))
            var returned = _named_type(leaf.type_text)
            var graphs = List[String]()
            var reasons = List[String]()
            var given = _is_provided(provided, leaf.name)
            var local = _classify(
                facts, graph_index, type_name, leaf.name, False
            )
            var gap = String("")
            if local == 2 or local == 3:
                gap = _context_gap(
                    facts, graph_index, type_name, leaf.name, keys
                )
            var reached = False
            var landed = graph_index
            var active_graphs = List[String]()
            var active_reasons = List[String]()
            var active_failed = False
            if gap.byte_length() > 0:
                _add(
                    graphs,
                    reasons,
                    facts[graph_index].graph_name,
                    gap,
                )
            else:
                reached = given or _attempt(
                    facts,
                    graph_index,
                    type_name,
                    leaf.name,
                    graphs,
                    reasons,
                    False,
                    landed,
                )
                if (
                    reached
                    and not given
                    and _has_labeled_override(facts, type_name, leaf.name)
                ):
                    var hidden_landed = -1
                    if not _attempt(
                        facts,
                        graph_index,
                        type_name,
                        leaf.name,
                        active_graphs,
                        active_reasons,
                        True,
                        hidden_landed,
                    ):
                        reached = False
                        active_failed = True
            var next = path.copy()
            next.append(String(leaf.name) + _call(facts, type_name, leaf.name))
            # When `reached` is true, `landed` is the subgraph that resolves
            # the field.
            if reached and (
                _is_interface(facts, returned) or _is_union(facts, returned)
            ):
                if _is_interface_object(facts, landed, returned):
                    _reach_implementations(
                        facts,
                        landed,
                        returned,
                        next,
                        args,
                        keys,
                        found,
                        reported,
                    )
                else:
                    _enter_implementations(
                        facts,
                        landed,
                        returned,
                        next,
                        args,
                        keys,
                        found,
                        reported,
                    )
            elif reached and _is_object(facts, returned):
                var child_provided = _provides(
                    facts, landed, type_name, leaf.name
                )
                var nested = _nested_provided(provided, leaf.name)
                if nested.byte_length() > 0:
                    child_provided.extend(_selections(nested))
                var child_keys = keys.copy()
                _push_contexts(facts, child_keys, type_name)
                _descend(
                    facts,
                    landed,
                    returned,
                    next,
                    args,
                    child_provided,
                    child_keys,
                    found,
                    reported,
                )
            elif not reached:
                # A failed attempt always records at least one reason.
                var out_graphs = graphs.copy()
                var out_reasons = reasons.copy()
                if active_failed:
                    out_graphs = active_graphs.copy()
                    out_reasons = active_reasons.copy()
                var key = type_name + "." + leaf.name
                var reason_index = 0
                while reason_index < len(out_reasons):
                    key += "\n" + out_reasons[reason_index]
                    reason_index += 1
                if not _seen(reported, key):
                    reported.append(key)
                    found.append(
                        CompositionError(
                            _message(
                                _path_query(
                                    next, args, _is_object(facts, returned)
                                ),
                                out_graphs,
                                out_reasons,
                            ),
                            ErrorCode.SATISFIABILITY_ERROR,
                            None,
                        )
                    )


def _push_contexts(
    facts: List[GraphFacts], mut keys: List[String], type_name: String
):
    """Add one type's `@context` names to the keys in scope.

    Args:
        facts: The subgraphs.
        keys: Receives each `graph__name` that is not already present.
        type_name: The type whose contexts become available to descendants.
    """
    # A repeated key does no harm: the keys are only searched.
    var index = 0
    while index < len(facts):
        var at = _type_named(facts[index], type_name)
        if at >= 0:
            ref contexts = facts[index].types[at].contexts
            for name_index in range(len(contexts)):
                keys.append(
                    facts[index].graph_name + "__" + contexts[name_index]
                )
        index += 1


def _context_gap(
    facts: List[GraphFacts],
    graph_index: Int,
    type_name: String,
    field_name: String,
    keys: List[String],
) -> String:
    """Return the missing-context reason, or empty when the field is fine.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph that must resolve the field.
        type_name: The object type.
        field_name: The field.
        keys: `@context` keys already in scope.

    Returns:
        Hive's required-context sentence, or empty.
    """
    # The caller classified the field as present in this subgraph.
    var at = _field_at(facts, graph_index, type_name, field_name)
    var type_at = _type_named(facts[graph_index], type_name)
    ref args = facts[graph_index].types[type_at].fields[at].arg_facts
    for index in range(len(args)):
        if not args[index].from_context:
            continue
        var key = (
            facts[graph_index].graph_name + "__" + args[index].context_name
        )
        if not _seen(keys, key):
            return (
                'could not find a match for required context for field "'
                + type_name
                + "."
                + field_name
                + '".'
            )
    return String("")


def _provides(
    facts: List[GraphFacts],
    graph_index: Int,
    type_name: String,
    field_name: String,
) -> List[_Selection]:
    """Return the `@provides` selection of a field.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph that resolved the field.
        type_name: The parent type.
        field_name: The field.

    Returns:
        The provided fields. A nested selection stays in `children`.
    """
    # The subgraph resolved the field, so it has the field.
    var at = _field_at(facts, graph_index, type_name, field_name)
    var type_at = _type_named(facts[graph_index], type_name)
    return _selections(facts[graph_index].types[type_at].fields[at].provides)


def _is_provided(provided: List[_Selection], name: String) -> Bool:
    """Return True when `@provides` already resolved a field.

    Args:
        provided: The selections in scope.
        name: The field name.

    Returns:
        Whether `name` is one of the selections.
    """
    for index in range(len(provided)):
        if provided[index].name == name:
            return True
    return False


def _nested_provided(provided: List[_Selection], name: String) -> String:
    """Return the nested `@provides` selection of a field, or empty.

    Args:
        provided: The selections in scope.
        name: The field name.

    Returns:
        The nested text, or empty when the field is not provided.
    """
    var index = 0
    while index < len(provided):
        if provided[index].name == name:
            return String(provided[index].children)
        index += 1
    return String("")


def _landed(
    facts: List[GraphFacts],
    graph_index: Int,
    type_name: String,
    field_name: String,
) -> Int:
    """Return the subgraph that resolved a field, or -1.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph that was entered.
        type_name: The object type.
        field_name: The field.

    Returns:
        The subgraph index to continue from.
    """
    var graphs = List[String]()
    var reasons = List[String]()
    var landed = -1
    _ = _attempt(
        facts,
        graph_index,
        type_name,
        field_name,
        graphs,
        reasons,
        False,
        landed,
    )
    return landed


def _attempt(
    facts: List[GraphFacts],
    graph_index: Int,
    type_name: String,
    field_name: String,
    mut graphs: List[String],
    mut reasons: List[String],
    active: Bool,
    mut landed: Int,
) -> Bool:
    """Try to resolve one field in one subgraph, then by `@key`.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph that was entered.
        type_name: The object type.
        field_name: The field to resolve.
        graphs: Receives the subgraph of each failure.
        reasons: Receives the failure text.
        active: When true, a labeled `@override` hides the source field.
        landed: Receives the subgraph that resolves the field.

    Returns:
        Whether some attempt resolves the field.
    """
    var local = _classify(facts, graph_index, type_name, field_name, active)
    if local == 3:
        landed = graph_index
        return True
    if local == 1:
        _add(
            graphs,
            reasons,
            facts[graph_index].graph_name,
            'field "'
            + type_name
            + "."
            + field_name
            + '" is not resolvable because marked @external.',
        )
    elif local == 2:
        _add(
            graphs,
            reasons,
            facts[graph_index].graph_name,
            'cannot satisfy @require conditions on field "'
            + type_name
            + "."
            + field_name
            + '".',
        )
    else:
        _add(
            graphs,
            reasons,
            facts[graph_index].graph_name,
            'cannot find field "' + type_name + "." + field_name + '".',
        )
    var other = -1
    while other + 1 < len(facts):
        other += 1
        if other == graph_index or _type_named(facts[other], type_name) < 0:
            continue
        if _can_move(facts, graph_index, other, type_name):
            var there = _classify(facts, other, type_name, field_name, active)
            if there == 3:
                landed = other
                return True
            if there == 2:
                _add(
                    graphs,
                    reasons,
                    facts[other].graph_name,
                    'cannot satisfy @require conditions on field "'
                    + type_name
                    + "."
                    + field_name
                    + '".',
                )
            elif there == 1:
                _add(
                    graphs,
                    reasons,
                    facts[other].graph_name,
                    'field "'
                    + type_name
                    + "."
                    + field_name
                    + '" is not resolvable because marked @external.',
                )
            else:
                _add(
                    graphs,
                    reasons,
                    facts[other].graph_name,
                    'cannot find field "' + type_name + "." + field_name + '".',
                )
        else:
            var key = _first_key(facts, other, type_name)
            if key.byte_length() == 0:
                # Upstream reports `NO_KEY` only when the field is missing
                # in the subgraph that was entered, and only for a subgraph
                # whose field is not `@external`.
                if (
                    local == 0
                    and _classify(facts, other, type_name, field_name, active)
                    >= 2
                ):
                    _add(
                        graphs,
                        reasons,
                        facts[graph_index].graph_name,
                        'cannot move to subgraph "'
                        + facts[other].graph_name
                        + '", which has field "'
                        + type_name
                        + "."
                        + field_name
                        + '", because type "'
                        + type_name
                        + '" has no @key defined in subgraph "'
                        + facts[other].graph_name
                        + '".',
                    )
            else:
                _add(
                    graphs,
                    reasons,
                    facts[graph_index].graph_name,
                    'cannot move to subgraph "'
                    + facts[other].graph_name
                    + '" using @key(fields: "'
                    + " ".join(_words(key))
                    + '") of "'
                    + type_name
                    + '", the key field(s) cannot be resolved from subgraph "'
                    + facts[graph_index].graph_name
                    + '".',
                )
    return False


def _classify(
    facts: List[GraphFacts],
    graph_index: Int,
    type_name: String,
    field_name: String,
    active: Bool,
) -> Int:
    """Classify a field in one subgraph.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph.
        type_name: The object type.
        field_name: The field.
        active: When true, a labeled `@override` hides the source field.

    Returns:
        `0` when the field is missing, `1` when it is `@external`, `2`
        when `@requires` cannot be resolved, and `3` when it can.
    """
    if active and _label_hides(facts, graph_index, type_name, field_name):
        return 0
    var at = _field_at(facts, graph_index, type_name, field_name)
    if at < 0 or _overridden_away(facts, graph_index, type_name, field_name):
        return 0
    var type_at = _type_named(facts[graph_index], type_name)
    ref field = facts[graph_index].types[type_at].fields[at]
    if field.external and not (field.used_as_key and field.in_extension):
        return 1
    if field.requires.byte_length() > 0:
        if not _selection_ok(facts, graph_index, type_name, field.requires):
            return 2
        return 3
    return 3


def _selections(text: String) -> List[_Selection]:
    """Split a field set into fields, keeping a nested selection together.

    Args:
        text: A field set such as `address { id }` or `id name`.

    Returns:
        The fields. A nested selection stays in `children`.
    """
    var found = List[_Selection]()
    var bytes = text.as_bytes()
    var index = 0
    while index < len(bytes):
        while index < len(bytes) and bytes[index] == 32:
            index += 1
        var start = index
        while index < len(bytes) and _name_byte(bytes[index]):
            index += 1
        if index == start:
            break
        var name = String(text[byte=start:index])
        while index < len(bytes) and bytes[index] == 32:
            index += 1
        var children = String("")
        if index < len(bytes) and bytes[index] == 123:
            # A valid field set closes each brace.
            var depth = 0
            var inner = index + 1
            while True:
                if bytes[index] == 123:
                    depth += 1
                elif bytes[index] == 125:
                    depth -= 1
                    if depth == 0:
                        children = String(text[byte=inner:index])
                        index += 1
                        break
                index += 1
        found.append(_Selection(name^, children^))
    return found^


def _name_byte(byte: UInt8) -> Bool:
    """Return True when a byte can appear in a GraphQL name.

    Args:
        byte: One byte.

    Returns:
        Whether the byte is a letter, a digit, or `_`.
    """
    var lower = byte | 32
    if lower >= 97 and lower <= 122:
        return True
    return byte == 95 or (byte >= 48 and byte <= 57)


def _selection_ok(
    facts: List[GraphFacts], graph_index: Int, type_name: String, text: String
) -> Bool:
    """Return True when a `@requires` selection can be resolved.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph that must resolve the selection.
        type_name: The parent type.
        text: The field set.

    Returns:
        Whether every field in the selection is resolvable.
    """
    # An inline fragment such as `... on Book { title }` is not read, so it
    # adds no condition.
    var fields = _selections(text)
    var index = 0
    while index < len(fields):
        var name = fields[index].name
        var landed = _landed(facts, graph_index, type_name, name)
        if landed < 0:
            return False
        if fields[index].children.byte_length() > 0:
            var child_type = _field_type(facts, landed, type_name, name)
            if not _selection_ok(
                facts, landed, child_type, fields[index].children
            ):
                return False
        index += 1
    return True


def _field_type(
    facts: List[GraphFacts],
    graph_index: Int,
    type_name: String,
    field_name: String,
) -> String:
    """Return the named return type of a field.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph.
        type_name: The parent type.
        field_name: The field.

    Returns:
        The named type. The subgraph resolved the field, so it has it.
    """
    var at = _field_at(facts, graph_index, type_name, field_name)
    var type_at = _type_named(facts[graph_index], type_name)
    return _named_type(facts[graph_index].types[type_at].fields[at].type_text)


def _can_move(
    facts: List[GraphFacts], source: Int, target: Int, type_name: String
) -> Bool:
    """Return True when one `@key` of the target can be resolved at the source.

    Args:
        facts: The subgraphs.
        source: The subgraph that must provide the key.
        target: The subgraph to enter.
        type_name: The entity type.

    Returns:
        Whether the move is possible.
    """
    # The callers check that the target defines the type. `keys` and
    # `key_resolvable` have the same length, and a key is never empty.
    var type_at = _type_named(facts[target], type_name)
    ref keys = facts[target].types[type_at].keys
    ref resolvable = facts[target].types[type_at].key_resolvable
    var key_index = 0
    while key_index < len(keys):
        var usable = resolvable[key_index]
        var words = _words(keys[key_index])
        key_index += 1
        if not usable:
            continue
        var ready = True
        var word_index = 0
        while word_index < len(words):
            if (
                _classify(facts, source, type_name, words[word_index], False)
                != 3
            ):
                ready = False
            word_index += 1
        if ready:
            return True
    return False


def _first_key(
    facts: List[GraphFacts], graph_index: Int, type_name: String
) -> String:
    """Return the first `@key` of a type, or empty.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph.
        type_name: The type.

    Returns:
        The key field set.
    """
    # The caller checks that the subgraph defines the type.
    var type_at = _type_named(facts[graph_index], type_name)
    ref keys = facts[graph_index].types[type_at].keys
    ref resolvable = facts[graph_index].types[type_at].key_resolvable
    var index = 0
    while index < len(keys):
        if resolvable[index]:
            return String(keys[index])
        index += 1
    return String("")


def _overridden_away(
    facts: List[GraphFacts],
    graph_index: Int,
    type_name: String,
    field_name: String,
) -> Bool:
    """Return True when another subgraph overrides this field with no label.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph that declares the field.
        type_name: The object type.
        field_name: The field.

    Returns:
        Whether the field is removed from this subgraph.
    """
    # A subgraph cannot override a field from itself, so the loop can visit
    # `graph_index` too.
    var name = facts[graph_index].graph_name
    var other = 0
    while other < len(facts):
        var at = _field_at(facts, other, type_name, field_name)
        if at >= 0:
            var type_at = _type_named(facts[other], type_name)
            ref field = facts[other].types[type_at].fields[at]
            if (
                field.override_from == name
                and field.override_label.byte_length() == 0
            ):
                return True
        other += 1
    return False


def _label_hides(
    facts: List[GraphFacts],
    graph_index: Int,
    type_name: String,
    field_name: String,
) -> Bool:
    """Return True when a labeled `@override` hides this field.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph that declares the field.
        type_name: The object type.
        field_name: The field.

    Returns:
        Whether another subgraph overrides this field with a label.
    """
    # An override without a label also hides the field: `_classify` then
    # finds it overridden away. A subgraph cannot override from itself.
    var name = facts[graph_index].graph_name
    var other = 0
    while other < len(facts):
        var at = _field_at(facts, other, type_name, field_name)
        if at >= 0:
            var type_at = _type_named(facts[other], type_name)
            if facts[other].types[type_at].fields[at].override_from == name:
                return True
        other += 1
    return False


def _has_labeled_override(
    facts: List[GraphFacts], type_name: String, field_name: String
) -> Bool:
    """Return True when some subgraph overrides the field with a label.

    Args:
        facts: The subgraphs.
        type_name: The object type.
        field_name: The field.

    Returns:
        Whether a labeled `@override` applies to the field.
    """
    var index = 0
    while index < len(facts):
        var at = _field_at(facts, index, type_name, field_name)
        if at >= 0:
            var type_at = _type_named(facts[index], type_name)
            ref field = facts[index].types[type_at].fields[at]
            if field.override_label.byte_length() > 0:
                return True
        index += 1
    return False


def _field_at(
    facts: List[GraphFacts],
    graph_index: Int,
    type_name: String,
    field_name: String,
) -> Int:
    """Return the index of a field, or -1.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph.
        type_name: The type.
        field_name: The field.

    Returns:
        The field index, or -1.
    """
    var type_at = _type_named(facts[graph_index], type_name)
    if type_at < 0:
        return -1
    ref fields = facts[graph_index].types[type_at].fields
    var index = 0
    while index < len(fields):
        if fields[index].name == field_name:
            return index
        index += 1
    return -1


def _type_named(graph: GraphFacts, name: String) -> Int:
    """Return the index of a type, or -1.

    Args:
        graph: One subgraph.
        name: The type name.

    Returns:
        The type index, or -1.
    """
    if name.byte_length() == 0:
        return -1
    var index = 0
    while index < len(graph.types):
        if (
            graph.types[index].name == name
            and graph.types[index].kind == TypeKind.OBJECT
        ):
            return index
        index += 1
    return -1


def _is_object(facts: List[GraphFacts], name: String) -> Bool:
    """Return True when some subgraph defines the name as an object.

    Args:
        facts: The subgraphs.
        name: The type name.

    Returns:
        Whether the name is an object type.
    """
    var index = 0
    while index < len(facts):
        if _type_named(facts[index], name) >= 0:
            return True
        index += 1
    return False


def _is_interface_object(
    facts: List[GraphFacts], graph_index: Int, name: String
) -> Bool:
    """Return True when this subgraph's type is an `@interfaceObject`.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph.
        name: The type name.

    Returns:
        Whether the type is an `@interfaceObject` in that subgraph.
    """
    var at = _kind_at(facts[graph_index], name, TypeKind.INTERFACE)
    if at < 0:
        return False
    return facts[graph_index].types[at].is_interface_object


def _interface_key_ok(
    facts: List[GraphFacts], graph_index: Int, name: String
) -> Bool:
    """Return True when a resolvable interface `@key` can be resolved here.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph that has the `@interfaceObject`.
        name: The interface name.

    Returns:
        Whether some interface `@key` can be resolved on that object.
    """
    var index = 0
    while index < len(facts):
        var at = _kind_at(facts[index], name, TypeKind.INTERFACE)
        index += 1
        if at < 0 or facts[index - 1].types[at].is_interface_object:
            continue
        ref keys = facts[index - 1].types[at].keys
        ref resolvable = facts[index - 1].types[at].key_resolvable
        # `keys` and `key_resolvable` have the same length.
        var key_index = 0
        while key_index < len(keys):
            var usable = resolvable[key_index]
            var words = _words(keys[key_index])
            key_index += 1
            if not usable:
                continue
            var ready = True
            var word_index = 0
            while word_index < len(words):
                if not _named_field_ok(
                    facts, graph_index, name, words[word_index]
                ):
                    ready = False
                word_index += 1
            if ready:
                return True
    return False


def _named_field_ok(
    facts: List[GraphFacts],
    graph_index: Int,
    type_name: String,
    field_name: String,
) -> Bool:
    """Return True when an `@interfaceObject` has a key field.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph.
        type_name: The type name.
        field_name: The field.

    Returns:
        Whether the field is present. Hive also accepts an `@external` key
        field here.
    """
    # The caller checks that this subgraph has the `@interfaceObject`.
    ref type = facts[graph_index].types[
        _kind_at(facts[graph_index], type_name, TypeKind.INTERFACE)
    ]
    var field_index = 0
    while field_index < len(type.fields):
        ref field = type.fields[field_index]
        field_index += 1
        # Hive enters the interface with an `@external` key field too.
        if field.name == field_name:
            return True
    return False


def _concrete_graph(facts: List[GraphFacts], name: String) -> Int:
    """Return the first subgraph that defines an object.

    An `@interfaceObject` is an interface in the facts, so it is not an
    object here.

    Args:
        facts: The subgraphs, in id order.
        name: The object name. It implements an interface, so some
            subgraph defines it.

    Returns:
        The subgraph index.
    """
    var index = 0
    while _type_named(facts[index], name) < 0:
        index += 1
    return index


def _reach_implementations(
    facts: List[GraphFacts],
    graph_index: Int,
    type_name: String,
    path: List[String],
    args: String,
    keys: List[String],
    mut found: List[CompositionError],
    mut reported: List[String],
):
    """Enter each implementation of an `@interfaceObject`, or report it.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph that defines the `@interfaceObject`.
        type_name: The interface object name.
        path: Field names from the query field to this type.
        args: Arguments of the query field, or empty.
        keys: `@context` keys already in scope.
        found: Receives one error per unreachable implementation.
        reported: Leaf coordinates already reported.
    """
    var impls = _implementors(facts, type_name)
    var reached = _interface_key_ok(facts, graph_index, type_name)
    # An `@interfaceObject` needs an interface with an implementation.
    var impl_index = 0
    while impl_index < len(impls):
        var impl = impls[impl_index]
        impl_index += 1
        var next = path.copy()
        next.append("... on " + impl)
        if reached:
            var provided = List[_Selection]()
            _descend(
                facts,
                _concrete_graph(facts, impl),
                impl,
                next,
                args,
                provided,
                keys,
                found,
                reported,
            )
            continue
        var reason = (
            "no subgraph can be reached to resolve the implementation"
            ' type of @interfaceObject type "'
            + type_name
            + '".'
        )
        var key = type_name + "..." + impl
        if _seen(reported, key):
            continue
        reported.append(key)
        var graphs = List[String]()
        var reasons = List[String]()
        _add(graphs, reasons, facts[graph_index].graph_name, reason)
        found.append(
            CompositionError(
                _message(_path_query(next, args, True), graphs, reasons),
                ErrorCode.SATISFIABILITY_ERROR,
                None,
            )
        )


def _is_interface(facts: List[GraphFacts], name: String) -> Bool:
    """Return True when some subgraph defines the name as an interface.

    Args:
        facts: The subgraphs.
        name: The type name.

    Returns:
        Whether the name is an interface.
    """
    var index = 0
    while index < len(facts):
        if _kind_at(facts[index], name, TypeKind.INTERFACE) >= 0:
            return True
        index += 1
    return False


def _is_union(facts: List[GraphFacts], name: String) -> Bool:
    """Return True when some subgraph defines the name as a union.

    Args:
        facts: The subgraphs.
        name: The type name.

    Returns:
        Whether the name is a union.
    """
    var index = 0
    while index < len(facts):
        if _kind_at(facts[index], name, TypeKind.UNION) >= 0:
            return True
        index += 1
    return False


def _kind_at(graph: GraphFacts, name: String, kind: TypeKind) -> Int:
    """Return the index of a type with a kind, or -1.

    Args:
        graph: One subgraph.
        name: The type name.
        kind: The type kind.

    Returns:
        The type index, or -1.
    """
    var index = 0
    while index < len(graph.types):
        if graph.types[index].name == name and graph.types[index].kind == kind:
            return index
        index += 1
    return -1


def _implementors(facts: List[GraphFacts], name: String) -> List[String]:
    """Return the objects that implement an interface, in id order.

    Args:
        facts: The subgraphs, in id order.
        name: The interface name.

    Returns:
        The object names. Each name is listed once.
    """
    var names = List[String]()
    var index = 0
    while index < len(facts):
        var at = _kind_at(facts[index], name, TypeKind.INTERFACE)
        index += 1
        if at < 0:
            continue
        ref impls = facts[index - 1].types[at].implemented_by
        for item in range(len(impls)):
            if not _seen(names, impls[item]):
                names.append(String(impls[item]))
    return names^


def _union_members(facts: List[GraphFacts], name: String) -> List[String]:
    """Return the members of a union, in id order.

    Args:
        facts: The subgraphs, in id order.
        name: The union name.

    Returns:
        The member names. Each name is listed once.
    """
    var names = List[String]()
    var index = 0
    while index < len(facts):
        var at = _kind_at(facts[index], name, TypeKind.UNION)
        index += 1
        if at < 0:
            continue
        ref members = facts[index - 1].types[at].values
        # A union has at least one member.
        var item = 0
        while item < len(members):
            if not _seen(names, members[item]):
                names.append(String(members[item]))
            item += 1
    return names^


def _concrete_types(facts: List[GraphFacts], name: String) -> List[String]:
    """Return the objects selected by an interface or a union.

    Args:
        facts: The subgraphs, in id order.
        name: The interface or union name.

    Returns:
        The implementors of an interface, or the members of a union. A
        name is an interface or a union, never both.
    """
    var names = _implementors(facts, name)
    names.extend(_union_members(facts, name))
    return names^


def _enter_implementations(
    facts: List[GraphFacts],
    graph_index: Int,
    interface_name: String,
    path: List[String],
    args: String,
    keys: List[String],
    mut found: List[CompositionError],
    mut reported: List[String],
):
    """Check each object that an interface or a union selects.

    Args:
        facts: The subgraphs.
        graph_index: The subgraph that was entered.
        interface_name: The interface or union type.
        path: Field names from the query field to this type.
        args: Arguments of the query field, or empty.
        keys: `@context` keys already in scope.
        found: Receives one error per unsatisfiable query.
        reported: Leaf coordinates already reported.
    """
    var impls = _concrete_types(facts, interface_name)
    var impl_index = 0
    while impl_index < len(impls):
        var next = path.copy()
        next.append("... on " + impls[impl_index])
        var provided = List[_Selection]()
        _descend(
            facts,
            graph_index,
            impls[impl_index],
            next,
            args,
            provided,
            keys,
            found,
            reported,
        )
        impl_index += 1


def _owners(
    facts: List[GraphFacts], type_name: String, field_name: String
) -> List[Int]:
    """Return the subgraphs that define a field, in id order.

    Args:
        facts: The subgraphs.
        type_name: The type.
        field_name: The field.

    Returns:
        The subgraph indexes.
    """
    var owners = List[Int]()
    var index = 0
    while index < len(facts):
        if _field_at(facts, index, type_name, field_name) >= 0:
            owners.append(index)
        index += 1
    return owners^


def _call(
    facts: List[GraphFacts], type_name: String, field_name: String
) -> String:
    """Return the printed arguments of a field in the example query.

    Args:
        facts: The subgraphs.
        type_name: The object type.
        field_name: The field.

    Returns:
        Text such as `(first: 0)`, or empty when the field has no argument
        to print.
    """
    var args = _arguments(
        facts, _owners(facts, type_name, field_name), type_name, field_name
    )
    if args.byte_length() == 0:
        return String("")
    return "(" + args + ")"


def _arguments(
    facts: List[GraphFacts],
    owners: List[Int],
    type_name: String,
    field_name: String,
) -> String:
    """Return empty argument values for a query field.

    Args:
        facts: The subgraphs.
        owners: The subgraphs that define the field.
        type_name: The parent type.
        field_name: The field.

    Returns:
        Text such as `ids: []`, or empty.
    """
    # The query field comes from a subgraph, so `owners` is never empty.
    var at = _field_at(facts, owners[0], type_name, field_name)
    var type_at = _type_named(facts[owners[0]], type_name)
    ref args = facts[owners[0]].types[type_at].fields[at].arg_facts
    var out = String("")
    for index in range(len(args)):
        if args[index].from_context:
            continue
        if out.byte_length() > 0:
            out += ", "
        out += (
            args[index].name + ": " + _empty_value(facts, args[index].type_text)
        )
    return out


def _empty_value(facts: List[GraphFacts], type_text: String) -> String:
    """Return Hive's empty example value for a type, as upstream
    `createEmptyValueNode`.

    Args:
        facts: The subgraphs, in id order.
        type_text: The printed type.

    Returns:
        A GraphQL value. An enum gives its first value.
    """
    var bare = type_text
    while bare.endswith("!"):
        var trimmed = String(bare[byte = 0 : bare.byte_length() - 1])
        bare = trimmed
    if bare.startswith("["):
        return String("[]")
    var index = 0
    while index < len(facts):
        var at = _kind_at(facts[index], bare, TypeKind.ENUM)
        if at >= 0:
            return String(facts[index].types[at].values[0])
        index += 1
    if bare == "String":
        return String('"A string value"')
    if bare == "Int" or bare == "Float":
        return String("0")
    if bare == "Boolean":
        return String("true")
    if bare == "ID":
        return String('"<any id>"')
    return String('"A string value"')


def _named_type(type_text: String) -> String:
    """Return the named type inside a type string.

    Args:
        type_text: A printed type, such as `[User!]!`.

    Returns:
        The named type, such as `User`.
    """
    var text = type_text
    while True:
        if text.endswith("!"):
            var trimmed = String(text[byte = 0 : text.byte_length() - 1])
            text = trimmed
        elif text.startswith("["):
            # A list type without `!` at the end ends with `]`.
            var inner = String(text[byte = 1 : text.byte_length() - 1])
            text = inner
        else:
            return text


def _words(text: String) -> List[String]:
    """Split a flat field set on spaces.

    Args:
        text: A `@key` or `@requires` field set.

    Returns:
        The field names. A nested selection is left as one word.
    """
    var words = List[String]()
    var bytes = text.as_bytes()
    var start = 0
    var index = 0
    while index <= len(bytes):
        var boundary = index == len(bytes) or bytes[index] == 32
        if boundary and index > start:
            words.append(String(text[byte=start:index]))
        if boundary:
            start = index + 1
        index += 1
    return words^


def _seen(names: List[String], name: String) -> Bool:
    """Return True when a name was already recorded.

    Args:
        names: The names seen so far.
        name: The candidate.

    Returns:
        Whether `name` is in `names`.
    """
    for index in range(len(names)):
        if names[index] == name:
            return True
    return False


def _add(
    mut graphs: List[String],
    mut reasons: List[String],
    graph: String,
    reason: String,
):
    """Record one failure.

    Args:
        graphs: The subgraph of each failure.
        reasons: The failure text.
        graph: The subgraph name.
        reason: The failure.
    """
    graphs.append(graph)
    reasons.append(reason)


def _path_query(
    names: List[String], args: String, leaf_is_object: Bool
) -> String:
    """Return the example query for a field path.

    Args:
        names: Field names from the query field to the leaf.
        args: Arguments of the query field, or empty.
        leaf_is_object: Whether the leaf returns an object.

    Returns:
        The query text.
    """
    var out = String("{\n")
    var index = 0
    while index < len(names):
        var indent = _indent(index + 1)
        var call = names[index]
        if index == 0 and args.byte_length() > 0:
            call += "(" + args + ")"
        if index == len(names) - 1 and not leaf_is_object:
            out += indent + call + "\n"
        else:
            out += indent + call + " {\n"
        index += 1
    if leaf_is_object:
        out += _indent(len(names) + 1) + "...\n"
    var close = len(names)
    if not leaf_is_object:
        close -= 1
    var depth = close
    while depth > 0:
        depth -= 1
        out += _indent(depth + 1) + "}\n"
    out += "}"
    return out


def _indent(levels: Int) -> String:
    """Return `levels` pairs of spaces.

    Args:
        levels: How many indentation steps.

    Returns:
        The indentation.
    """
    var out = String("")
    var count = levels
    while count > 0:
        out += "  "
        count -= 1
    return out


def _message(
    query: String, graphs: List[String], reasons: List[String]
) -> String:
    """Return one `SATISFIABILITY_ERROR` message.

    Args:
        query: The example query.
        graphs: The subgraph of each reason, in order.
        reasons: The reasons.

    Returns:
        The message Hive prints.
    """
    var out = (
        "The following supergraph API query:\n"
        + query
        + "\ncannot be satisfied by the subgraphs because:"
    )
    var index = 0
    while index < len(reasons):
        var graph = graphs[index]
        var count = 0
        var cursor = index
        while cursor < len(reasons) and graphs[cursor] == graph:
            count += 1
            cursor += 1
        if count == 1:
            out += '\n- from subgraph "' + graph + '": ' + reasons[index]
            index += 1
        else:
            out += '\n- from subgraph "' + graph + '":'
            var at = index
            while at < index + count:
                out += "\n  - " + reasons[at]
                at += 1
            index += count
    return out
