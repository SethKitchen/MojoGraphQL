# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A `@requires` or `@fromContext` selection must satisfy the auth of the
field that reads it.

Port of `AuthOnRequiresRule` and `AuthOnContextRule` of Hive Federation
Composition v0.27.0
`src/supergraph/validation/rules/auth-on-requires-rule.ts` and
`src/supergraph/validation/rules/auth-on-context-rule.ts`.

An interface field is `@authenticated` when an implementation field is.
`@requiresScopes` and `@policy` are checked the same way. An interface
field inherits the requirements of its implementation fields.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.helpers import parse_fields, selection_set_of
from gql_composition.later_versions import GraphFacts, TypeFacts
from gql_composition.merged import append_new, contains, field_names, type_names
from gql_composition.state import TypeKind, merge_scope_policies


@fieldwise_init
struct _Access(Movable):
    """The auth a `@requires` field already satisfies."""

    var authenticated: Bool
    """Whether `@authenticated` is satisfied."""
    var scopes: List[List[String]]
    """The `@requiresScopes` groups the field provides."""
    var policies: List[List[String]]
    """The `@policy` groups the field provides."""


def check_auth_requires(
    facts: List[GraphFacts],
) raises -> List[CompositionError]:
    """Report a `@requires` field that cannot access authenticated data.

    Args:
        facts: The subgraphs, in id order, after the other supergraph
            rules reported nothing.

    Returns:
        The `MISSING_TRANSITIVE_AUTH_REQUIREMENTS` errors.

    Raises:
        GraphQLError: A `@requires` selection does not parse. The subgraph
            phase rejects such a selection first.
    """
    var errors = List[CompositionError]()
    var types = type_names(facts, TypeKind.OBJECT)
    var type_index = 0
    while type_index < len(types):
        var fields = field_names(facts, types[type_index], TypeKind.OBJECT)
        var field_index = 0
        while field_index < len(fields):
            _check_field(facts, types[type_index], fields[field_index], errors)
            field_index += 1
        type_index += 1
    return errors^


def check_auth_context(
    facts: List[GraphFacts],
) raises -> List[CompositionError]:
    """Report a `@fromContext` field that cannot access its context.

    Args:
        facts: The subgraphs, in id order, after the other supergraph
            rules reported nothing.

    Returns:
        The `MISSING_TRANSITIVE_AUTH_REQUIREMENTS` errors for context.

    Raises:
        GraphQLError: A `@fromContext` selection does not parse. The
            subgraph phase rejects such a selection first.
    """
    var errors = List[CompositionError]()
    var types = type_names(facts, TypeKind.OBJECT)
    var type_index = 0
    while type_index < len(types):
        var fields = field_names(facts, types[type_index], TypeKind.OBJECT)
        var field_index = 0
        while field_index < len(fields):
            _check_context(
                facts, types[type_index], fields[field_index], errors
            )
            field_index += 1
        type_index += 1
    return errors^


def _check_context(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    mut errors: List[CompositionError],
) raises:
    """Append at most one context error for one object field.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.
        errors: The errors to append.

    Raises:
        GraphQLError: The context selection does not parse.
    """
    var access: Optional[_Access] = None
    var graph_index = -1
    while graph_index + 1 < len(facts):
        graph_index += 1
        ref graph = facts[graph_index]
        var at = graph.find_kind(type_name, TypeKind.OBJECT)
        if at == -1:
            continue
        var field = graph.types[at].find_field(field_name)
        if field == -1:
            continue
        ref args = graph.types[at].fields[field].arg_facts
        for arg_index in range(len(args)):
            if args[arg_index].context_name.byte_length() == 0:
                continue
            if not access:
                access = _provisioned(facts, type_name, field_name)
            if _context_denied(
                facts,
                graph_index,
                args[arg_index].context_name,
                args[arg_index].context_selection,
                access.value(),
            ):
                errors.append(
                    CompositionError(
                        "["
                        + graph.graph_name
                        + '] Field "'
                        + type_name
                        + "."
                        + field_name
                        + '" does not specify necessary @authenticated,'
                        " @requiresScopes and/or @policy auth requirements"
                        " to access the transitive data in context "
                        + graph.graph_name
                        + "__"
                        + args[arg_index].context_name
                        + " from @fromContext selection set.",
                        ErrorCode.MISSING_TRANSITIVE_AUTH_REQUIREMENTS,
                        None,
                    )
                )
                return


def _context_denied(
    facts: List[GraphFacts],
    graph_index: Int,
    context_name: String,
    selection: String,
    access: _Access,
) raises -> Bool:
    """Return True when a context selection needs auth the field lacks.

    Args:
        facts: The subgraphs, in id order.
        graph_index: The subgraph that declares `@fromContext`.
        context_name: The context name.
        selection: The selection text.
        access: The auth the field provides.

    Returns:
        Whether Hive reports the field for this context.

    Raises:
        GraphQLError: The selection does not parse.
    """
    ref graph = facts[graph_index]
    var type_index = -1
    while type_index + 1 < len(graph.types):
        type_index += 1
        ref type = graph.types[type_index]
        if not contains(type.contexts, context_name):
            continue
        # The subgraph phase rejects a selection that does not parse.
        var document = parse_fields(selection)
        var missing = _walk(
            facts,
            document,
            selection_set_of(document),
            type.name,
            access,
        )
        if missing.byte_length() > 0:
            return True
    return False


def _check_field(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    mut errors: List[CompositionError],
) raises:
    """Append at most one error for one object field.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.
        errors: The errors to append.

    Raises:
        GraphQLError: The `@requires` selection does not parse.
    """
    var access: Optional[_Access] = None
    var graph_index = -1
    while graph_index + 1 < len(facts):
        graph_index += 1
        var requires = _requires(facts[graph_index], type_name, field_name)
        if requires.byte_length() == 0:
            continue
        if not access:
            access = _provisioned(facts, type_name, field_name)
        # The subgraph phase rejects a selection that does not parse.
        var document = parse_fields(requires)
        var missing = _walk(
            facts,
            document,
            selection_set_of(document),
            type_name,
            access.value(),
        )
        if missing.byte_length() == 0:
            continue
        var place = String('field "') + missing + '"'
        if missing.find(".") == -1:
            place = String('type "') + missing + '"'
        errors.append(
            CompositionError(
                "["
                + facts[graph_index].graph_name
                + '] Field "'
                + type_name
                + "."
                + field_name
                + '" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to"
                " access the transitive "
                + place
                + " data from @requires selection set.",
                ErrorCode.MISSING_TRANSITIVE_AUTH_REQUIREMENTS,
                None,
            )
        )
        return


def _walk(
    facts: List[GraphFacts],
    document: Document,
    selection_set: Int,
    type_name: String,
    access: _Access,
) -> String:
    """Return the first coordinate the selection cannot access.

    Args:
        facts: The subgraphs, in id order.
        document: The parsed field set.
        selection_set: The selection set to walk.
        type_name: The type the selection starts from.
        access: The auth the requiring field provides.

    Returns:
        A type name or `Type.field`, or empty when access is allowed.
    """
    var is_union = _kind_is(facts, type_name, TypeKind.UNION)
    if not is_union and not _allows_type(facts, type_name, access):
        return String(type_name)
    var selection = document.first_child(selection_set)
    while selection != NO_NODE:
        var kind = document.kind(selection)
        if kind == Kind.INLINE_FRAGMENT:
            var condition = document.child(selection, Role.TYPE_CONDITION)
            var next_type = String(type_name)
            if condition != NO_NODE:
                next_type = String(document.name(condition))
            if not _allows_type(facts, next_type, access):
                return next_type
            var nested = _walk(
                facts,
                document,
                document.child(selection, Role.SELECTION_SET),
                next_type,
                access,
            )
            if nested.byte_length() > 0:
                return nested
        else:
            # A field set has no fragment spreads, so this is a field.
            var field_name = String(document.name(selection))
            if field_name == "__typename":
                # Upstream checks every member of a union for `__typename`
                # and then stops walking this selection set.
                if is_union:
                    return _union_denied(facts, type_name, access)
            else:
                var missing = _walk_field(
                    facts, document, selection, type_name, field_name, access
                )
                if missing.byte_length() > 0:
                    return missing
        selection = document.next_sibling(selection)
    return String("")


def _union_denied(
    facts: List[GraphFacts], union_name: String, access: _Access
) -> String:
    """Return the first union member that `access` does not cover.

    Args:
        facts: The subgraphs, in id order.
        union_name: The union.
        access: The auth the requiring field provides.

    Returns:
        The member name, or empty when access covers every member.
    """
    var graph_index = 0
    while graph_index < len(facts):
        var at = facts[graph_index].find_kind(union_name, TypeKind.UNION)
        graph_index += 1
        if at == -1:
            continue
        # A union has at least one member.
        ref members = facts[graph_index - 1].types[at].values
        var index = 0
        while index < len(members):
            if not _allows_type(facts, members[index], access):
                return String(members[index])
            index += 1
    return String("")


def _walk_field(
    facts: List[GraphFacts],
    document: Document,
    selection: Int,
    type_name: String,
    field_name: String,
    access: _Access,
) -> String:
    """Return the first coordinate one field selection cannot access.

    Args:
        facts: The subgraphs, in id order.
        document: The parsed field set.
        selection: The field node.
        type_name: The parent type.
        field_name: The selected field.
        access: The auth the requiring field provides.

    Returns:
        A coordinate, or empty when access is allowed.
    """
    # Subgraph validation requires each selected field to exist on its
    # parent type, so `type_name` defines the field.
    if not _allows_field(facts, type_name, field_name, access):
        return type_name + "." + field_name
    var output = _named(_field_type(facts, type_name, field_name))
    if _is_leaf(facts, output):
        return String("")
    if not _kind_is(facts, output, TypeKind.UNION) and not _allows_type(
        facts, output, access
    ):
        return type_name + "." + field_name
    return _walk(
        facts,
        document,
        document.child(selection, Role.SELECTION_SET),
        output,
        access,
    )


def _provisioned(
    facts: List[GraphFacts], type_name: String, field_name: String
) -> _Access:
    """Return the auth a requiring field provides.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field with `@requires`.

    Returns:
        The merged `@authenticated`, scopes and policies.
    """
    var scopes = _type_groups(facts, type_name, True)
    var field_scopes = _field_groups(facts, type_name, field_name, True)
    if len(field_scopes) > 0:
        scopes = merge_scope_policies(scopes, field_scopes)
    var policies = _type_groups(facts, type_name, False)
    var field_policies = _field_groups(facts, type_name, field_name, False)
    if len(field_policies) > 0:
        policies = merge_scope_policies(policies, field_policies)
    return _Access(
        _type_authenticated(facts, type_name)
        or _field_authenticated(facts, type_name, field_name),
        scopes^,
        policies^,
    )


def _allows_type(
    facts: List[GraphFacts], type_name: String, access: _Access
) -> Bool:
    """Return True when a type's auth is covered by `access`.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type.
        access: The auth the requiring field provides.

    Returns:
        Whether `canAccess` accepts the type.
    """
    return _satisfies(
        _type_authenticated(facts, type_name),
        _type_groups(facts, type_name, True),
        _type_groups(facts, type_name, False),
        access,
    )


def _allows_field(
    facts: List[GraphFacts],
    type_name: String,
    field_name: String,
    access: _Access,
) -> Bool:
    """Return True when a field's auth is covered by `access`.

    Args:
        facts: The subgraphs, in id order.
        type_name: The parent type.
        field_name: The field.
        access: The auth the requiring field provides.

    Returns:
        Whether `canAccess` accepts the field.
    """
    return _satisfies(
        _field_authenticated(facts, type_name, field_name),
        _field_groups(facts, type_name, field_name, True),
        _field_groups(facts, type_name, field_name, False),
        access,
    )


def _satisfies(
    authenticated: Bool,
    scopes: List[List[String]],
    policies: List[List[String]],
    access: _Access,
) -> Bool:
    """Return True when provided auth covers a requirement.

    Args:
        authenticated: Whether the target is `@authenticated`.
        scopes: The target's scope groups.
        policies: The target's policy groups.
        access: The auth the requiring field provides.

    Returns:
        Whether every requirement is satisfied.
    """
    if authenticated and not access.authenticated:
        return False
    if not _groups_ok(scopes, access.scopes):
        return False
    return _groups_ok(policies, access.policies)


def _groups_ok(
    required: List[List[String]], provided: List[List[String]]
) -> Bool:
    """Return True when every required group is in some provided group.

    Args:
        required: The groups the target demands.
        provided: The groups the field provides.

    Returns:
        Whether `canAccess` accepts the groups.
    """
    for ref need in required:
        var satisfied = False
        for ref group in provided:
            if _covers(group, need):
                satisfied = True
        if not satisfied:
            return False
    return True


def _covers(provided: List[String], required: List[String]) -> Bool:
    """Return True when `provided` contains every name in `required`.

    Args:
        provided: One provided group.
        required: One required group.

    Returns:
        Whether the provided group is enough.
    """
    # A scope or policy group is not empty.
    var index = 0
    while index < len(required):
        if not contains(provided, required[index]):
            return False
        index += 1
    return True


def _groups(type: TypeFacts, scopes: Bool) -> List[List[String]]:
    """Return the scope or policy groups of one type.

    Args:
        type: One subgraph's type.
        scopes: True for `@requiresScopes`, false for `@policy`.

    Returns:
        A copy of the groups.
    """
    if scopes:
        return type.scopes.copy()
    return type.policies.copy()


def _one_field_groups(
    type: TypeFacts, field_name: String, scopes: Bool
) -> List[List[String]]:
    """Return one field's groups, or an empty list.

    Args:
        type: One subgraph's type.
        field_name: The field.
        scopes: True for `@requiresScopes`, false for `@policy`.

    Returns:
        A copy of the groups. Empty when the field is absent.
    """
    var field = type.find_field(field_name)
    if field == -1:
        return List[List[String]]()
    if scopes:
        return type.fields[field].scopes.copy()
    return type.fields[field].policies.copy()


def _merge(mut merged: List[List[String]], groups: List[List[String]]):
    """Merge groups into a list when there are any.

    Args:
        merged: The groups so far.
        groups: The groups to add.
    """
    if len(groups) > 0:
        merged = merge_scope_policies(merged, groups)


@fieldwise_init
struct _Source(Copyable, Movable):
    """One subgraph's copy of a type whose auth counts."""

    var graph: Int
    """The subgraph index."""
    var at: Int
    """The type index in that subgraph."""


def _sources(facts: List[GraphFacts], type_name: String) -> List[_Source]:
    """Return the copies of a type and of its implementors.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type. A type that is not an interface has no
            implementors.

    Returns:
        The type in each subgraph that has it, then each implementor
        object in each subgraph that has it. The type comes from a
        subgraph, so the list is not empty.
    """
    var sources = List[_Source]()
    _add_sources(sources, facts, type_name, False)
    for ref name in _implementors(facts, type_name):
        _add_sources(sources, facts, name, True)
    return sources^


def _add_sources(
    mut sources: List[_Source],
    facts: List[GraphFacts],
    name: String,
    object_only: Bool,
):
    """Append each subgraph's copy of one type.

    Args:
        sources: The copies so far.
        facts: The subgraphs, in id order.
        name: The type name.
        object_only: Whether only an object type counts.
    """
    var graph_index = 0
    while graph_index < len(facts):
        var at = facts[graph_index].find(name)
        if object_only:
            at = facts[graph_index].find_kind(name, TypeKind.OBJECT)
        if at != -1:
            sources.append(_Source(graph_index, at))
        graph_index += 1


def _type_groups(
    facts: List[GraphFacts], type_name: String, scopes: Bool
) -> List[List[String]]:
    """Return the merged scope or policy groups of a type.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type.
        scopes: True for `@requiresScopes`, false for `@policy`.

    Returns:
        The groups, including those of interface implementors.
    """
    var merged = List[List[String]]()
    var sources = _sources(facts, type_name)
    var index = 0
    while index < len(sources):
        ref source = sources[index]
        _merge(merged, _groups(facts[source.graph].types[source.at], scopes))
        index += 1
    return merged^


def _field_groups(
    facts: List[GraphFacts], type_name: String, field_name: String, scopes: Bool
) -> List[List[String]]:
    """Return the merged scope or policy groups of a field.

    Args:
        facts: The subgraphs, in id order.
        type_name: The parent type.
        field_name: The field.
        scopes: True for `@requiresScopes`, false for `@policy`.

    Returns:
        The groups, including those of interface implementation fields.
    """
    var merged = List[List[String]]()
    var sources = _sources(facts, type_name)
    var index = 0
    while index < len(sources):
        ref source = sources[index]
        _merge(
            merged,
            _one_field_groups(
                facts[source.graph].types[source.at], field_name, scopes
            ),
        )
        index += 1
    return merged^


def _implementors(facts: List[GraphFacts], type_name: String) -> List[String]:
    """Return the object types that implement an interface.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type. A type that is not an interface has none.

    Returns:
        The implementors, in first-seen order.
    """
    var names = List[String]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var at = graph.find_kind(type_name, TypeKind.INTERFACE)
        if at == -1:
            continue
        for ref name in graph.types[at].implemented_by:
            append_new(names, name)
    return names^


def _type_authenticated(facts: List[GraphFacts], type_name: String) -> Bool:
    """Return True when a type or one of its implementors is authenticated.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type name.

    Returns:
        Whether the merged type is `@authenticated`.
    """
    var sources = _sources(facts, type_name)
    var index = 0
    while index < len(sources):
        ref source = sources[index]
        if facts[source.graph].types[source.at].authenticated:
            return True
        index += 1
    return False


def _flag(type: TypeFacts, field_name: String) -> Bool:
    """Return True when a type marks a field `@authenticated`.

    Args:
        type: One subgraph's type.
        field_name: The field.

    Returns:
        Whether that field is `@authenticated`.
    """
    var field = type.find_field(field_name)
    return field != -1 and type.fields[field].authenticated


def _field_authenticated(
    facts: List[GraphFacts], type_name: String, field_name: String
) -> Bool:
    """Return True when a field or an implementation field is authenticated.

    Args:
        facts: The subgraphs, in id order.
        type_name: The parent type.
        field_name: The field.

    Returns:
        Whether the merged field is `@authenticated`.
    """
    var sources = _sources(facts, type_name)
    var index = 0
    while index < len(sources):
        ref source = sources[index]
        if _flag(facts[source.graph].types[source.at], field_name):
            return True
        index += 1
    return False


def _field_type(
    facts: List[GraphFacts], type_name: String, field_name: String
) -> String:
    """Return one printed type of a field.

    Args:
        facts: The subgraphs, in id order.
        type_name: The parent type. Some subgraph defines the field on it.
        field_name: The field.

    Returns:
        The printed type in the first subgraph that has the field.
    """
    # Walk backward so that the first subgraph is the last to assign.
    var text = String("")
    var graph_index = len(facts)
    while graph_index > 0:
        graph_index -= 1
        ref graph = facts[graph_index]
        var at = graph.find(type_name)
        if at == -1:
            continue
        var field = graph.types[at].find_field(field_name)
        if field != -1:
            text = graph.types[at].fields[field].type_text
    return text^


def _requires(
    graph: GraphFacts, type_name: String, field_name: String
) -> String:
    """Return one subgraph's `@requires` field set.

    Args:
        graph: One subgraph.
        type_name: The object type.
        field_name: The field.

    Returns:
        The field set, or empty.
    """
    var at = graph.find_kind(type_name, TypeKind.OBJECT)
    if at == -1:
        return String("")
    var field = graph.types[at].find_field(field_name)
    if field == -1:
        return String("")
    return graph.types[at].fields[field].requires


def _is_leaf(facts: List[GraphFacts], type_name: String) -> Bool:
    """Return True for a scalar or an enum.

    Args:
        facts: The subgraphs, in id order.
        type_name: The named type.

    Returns:
        Whether the type has no fields.
    """
    if (
        type_name == "ID"
        or type_name == "String"
        or type_name == "Int"
        or type_name == "Float"
        or type_name == "Boolean"
    ):
        return True
    return _kind_is(facts, type_name, TypeKind.SCALAR) or _kind_is(
        facts, type_name, TypeKind.ENUM
    )


def _kind_is(
    facts: List[GraphFacts], type_name: String, kind: TypeKind
) -> Bool:
    """Return True when a subgraph defines the name as a kind.

    Args:
        facts: The subgraphs, in id order.
        type_name: The type name.
        kind: The kind.

    Returns:
        Whether the name has that kind.
    """
    var graph_index = 0
    while graph_index < len(facts):
        if facts[graph_index].find_kind(type_name, kind) != -1:
            return True
        graph_index += 1
    return False


def _named(text: String) -> String:
    """Drop list and non-null markers from a printed type.

    Args:
        text: A printed type.

    Returns:
        The named type.
    """
    return text.replace("[", "").replace("]", "").replace("!", "")
