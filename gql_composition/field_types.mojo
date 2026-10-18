# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Field types must agree across subgraphs.

Port of `FieldsOfTheSameTypeRule` of Hive Federation Composition v0.27.0
`src/supergraph/validation/rules/fields-of-the-same-type-rule.ts`, and of
the output-type choice in `src/supergraph/composition/object-type.ts` and
`input-object-type.ts`.

A nullable output type is compatible with the same non-null type. An
input type is compatible when one subgraph adds `!`. A field may return
a union or an interface in one subgraph and a member of that type in
another.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import FieldFact, GraphFacts, TypeFacts
from gql_composition.merged import append_new, contains, subgraph_place
from gql_composition.state import TypeKind


@fieldwise_init
struct _Site(Movable):
    """One subgraph's type for a field."""

    var graph_name: String
    """The subgraph name."""
    var type_text: String
    """The printed type in that subgraph."""
    var graph_index: Int
    """The index of the subgraph in the facts."""


@fieldwise_init
struct _MergedField(Movable):
    """One field and the type the supergraph keeps."""

    var name: String
    """The field name."""
    var super_type: String
    """The type Hive keeps on the merged field."""
    var seen_non_external: Bool
    """Whether a non-external field has been seen."""
    var sites: List[_Site]
    """The subgraphs that define the field, in id order."""


@fieldwise_init
struct _MergedType(Movable):
    """One object or input type, in first-seen order."""

    var name: String
    """The type name."""
    var fields: List[_MergedField]
    """The fields, in first-seen order."""


@fieldwise_init
struct _TypeGroup(Movable):
    """The subgraphs that print one field type."""

    var type_text: String
    """The printed type."""
    var names: List[String]
    """The subgraph names, in id order."""


@fieldwise_init
struct _Possible(Movable):
    """A union or an interface and the types it allows."""

    var name: String
    """The union or interface name."""
    var members: List[String]
    """Its members or implementers."""


def check_field_types(
    facts: List[GraphFacts], mut coordinates: List[String]
) -> List[CompositionError]:
    """Report fields whose types are incompatible across subgraphs.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        coordinates: Receives `Type.field` for each error, in the same order.

    Returns:
        The `FIELD_TYPE_MISMATCH` errors, object fields first.
    """
    var objects = List[_MergedType]()
    var inputs = List[_MergedType]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        var type_index = 0
        while type_index < len(graph.types):
            ref type = graph.types[type_index]
            if type.kind == TypeKind.OBJECT:
                _merge_output(
                    objects,
                    graph.version_number,
                    graph.graph_name,
                    graph_index,
                    type,
                )
            elif type.kind == TypeKind.INPUT_OBJECT:
                _merge_input(inputs, graph.graph_name, graph_index, type)
            type_index += 1
        graph_index += 1
    var errors = List[CompositionError]()
    _report_output(errors, coordinates, facts, objects)
    _report_input(errors, coordinates, inputs)
    return errors^


def _merge_output(
    mut merged: List[_MergedType],
    version_number: Int,
    graph_name: String,
    graph_index: Int,
    type: TypeFacts,
):
    """Merge one object type into the supergraph field types.

    Args:
        merged: The object types seen so far.
        version_number: The subgraph's federation version number.
        graph_name: The subgraph name.
        graph_index: The index of the subgraph in the facts.
        type: The object type.
    """
    var at = _ensure_type(merged, type.name)
    var field_index = 0
    while field_index < len(type.fields):
        ref field = type.fields[field_index]
        field_index += 1
        var external = field.external
        if version_number < 200 and type.extension:
            external = False
        _ensure_output_field(
            merged[at],
            field,
            _Site(graph_name, field.type_text, graph_index),
            external,
        )


def _merge_input(
    mut merged: List[_MergedType],
    graph_name: String,
    graph_index: Int,
    type: TypeFacts,
):
    """Merge one input type into the supergraph field types.

    Args:
        merged: The input types seen so far.
        graph_name: The subgraph name.
        graph_index: The index of the subgraph in the facts.
        type: The input type.
    """
    var at = _ensure_type(merged, type.name)
    var field_index = 0
    while field_index < len(type.fields):
        ref field = type.fields[field_index]
        field_index += 1
        _ensure_input_field(
            merged[at], field, _Site(graph_name, field.type_text, graph_index)
        )


def _ensure_type(mut merged: List[_MergedType], name: String) -> Int:
    """Return the row for a type, creating it when it is new.

    Args:
        merged: The types seen so far.
        name: The type name.

    Returns:
        The index of the type.
    """
    for index in range(len(merged)):
        if merged[index].name == name:
            return index
    var fields = List[_MergedField]()
    merged.append(_MergedType(String(name), fields^))
    return len(merged) - 1


def _ensure_output_field(
    mut merged: _MergedType,
    field: FieldFact,
    var site: _Site,
    external: Bool,
):
    """Record one object field and update the supergraph type.

    Args:
        merged: The object type.
        field: The field in this subgraph.
        site: The subgraph and the field type in it.
        external: Whether Hive treats the field as `@external`.
    """
    for index in range(len(merged.fields)):
        if merged.fields[index].name != field.name:
            continue
        ref found = merged.fields[index]
        var should_force = (
            not field.used_as_key
            and not external
            and not found.seen_non_external
        )
        var should_change = should_force or (
            not external
            and _last_bang(found.super_type) > _last_bang(field.type_text)
        )
        if should_change:
            found.super_type = String(field.type_text)
        if not found.seen_non_external and not external:
            found.seen_non_external = True
        found.sites.append(site^)
        return
    var sites = List[_Site]()
    sites.append(site^)
    var seen = not external
    merged.fields.append(
        _MergedField(
            String(field.name),
            String(field.type_text),
            seen,
            sites^,
        )
    )


def _ensure_input_field(
    mut merged: _MergedType, field: FieldFact, var site: _Site
):
    """Record one input field and keep the non-null type when one exists.

    Args:
        merged: The input type.
        field: The field in this subgraph.
        site: The subgraph and the field type in it.
    """
    for index in range(len(merged.fields)):
        if merged.fields[index].name != field.name:
            continue
        ref found = merged.fields[index]
        if field.type_text.endswith("!") and not found.super_type.endswith("!"):
            found.super_type = String(field.type_text)
        found.sites.append(site^)
        return
    var sites = List[_Site]()
    sites.append(site^)
    merged.fields.append(
        _MergedField(
            String(field.name),
            String(field.type_text),
            True,
            sites^,
        )
    )


def _report_output(
    mut errors: List[CompositionError],
    mut coordinates: List[String],
    facts: List[GraphFacts],
    merged: List[_MergedType],
):
    """Append object field type errors.

    Args:
        errors: The errors to append.
        coordinates: Receives `Type.field` for each error.
        facts: The subgraphs, in id order.
        merged: The object types, in first-seen order.
    """
    var type_index = 0
    while type_index < len(merged):
        ref type = merged[type_index]
        type_index += 1
        var field_index = 0
        while field_index < len(type.fields):
            ref field = type.fields[field_index]
            field_index += 1
            var groups = List[_TypeGroup]()
            var possible = List[_Possible]()
            var site_index = 0
            while site_index < len(field.sites):
                ref site = field.sites[site_index]
                site_index += 1
                var key = _output_key(field.super_type, site.type_text)
                _add_group(groups, key, site.graph_name)
                _note_possible(
                    possible, facts[site.graph_index], site.type_text
                )
            _report_groups(
                errors, coordinates, type.name, field.name, groups, possible
            )


def _report_input(
    mut errors: List[CompositionError],
    mut coordinates: List[String],
    merged: List[_MergedType],
):
    """Append input field type errors.

    Args:
        errors: The errors to append.
        coordinates: Receives `Type.field` for each error.
        merged: The input types, in first-seen order.
    """
    var possible = List[_Possible]()
    for type_index in range(len(merged)):
        ref type = merged[type_index]
        var field_index = 0
        while field_index < len(type.fields):
            ref field = type.fields[field_index]
            field_index += 1
            var groups = List[_TypeGroup]()
            var site_index = 0
            while site_index < len(field.sites):
                ref site = field.sites[site_index]
                site_index += 1
                var key = _input_key(field.super_type, site.type_text)
                _add_group(groups, key, site.graph_name)
            _report_groups(
                errors, coordinates, type.name, field.name, groups, possible
            )


def _report_groups(
    mut errors: List[CompositionError],
    mut coordinates: List[String],
    type_name: String,
    field_name: String,
    groups: List[_TypeGroup],
    possible: List[_Possible],
):
    """Append one error when the grouped types are incompatible.

    Args:
        errors: The errors to append.
        coordinates: Receives `Type.field` for each error.
        type_name: The parent type.
        field_name: The field.
        groups: The printed types and their subgraphs.
        possible: The unions and interfaces the field returned.
    """
    if len(groups) < 2:
        return
    if _covered(groups, possible):
        return
    var message = (
        'Type of field "'
        + type_name
        + "."
        + field_name
        + '" is incompatible across subgraphs: it has '
        + _group_text(groups[0])
        + " but "
        + _group_text(groups[1])
    )
    for index in range(2, len(groups)):
        message += " and " + _group_text(groups[index])
    coordinates.append(type_name + "." + field_name)
    errors.append(
        CompositionError(message^, ErrorCode.FIELD_TYPE_MISMATCH, None)
    )


def _covered(groups: List[_TypeGroup], possible: List[_Possible]) -> Bool:
    """Return True when every type is one union or interface, or its member.

    Args:
        groups: The printed types.
        possible: The unions and interfaces. Empty skips nothing.

    Returns:
        Whether Hive ignores this mismatch.
    """
    if len(possible) != 1:
        return False
    var group_index = 0
    while group_index < len(groups):
        var named = _named_type(groups[group_index].type_text)
        group_index += 1
        if named == possible[0].name:
            continue
        if not contains(possible[0].members, named):
            return False
    return True


def _note_possible(
    mut possible: List[_Possible],
    graph: GraphFacts,
    type_text: String,
):
    """Record a union or an interface used as a field type.

    Args:
        possible: The unions and interfaces seen for this field.
        graph: The subgraph that prints `type_text`.
        type_text: The printed field type.
    """
    var named = _named_type(type_text)
    var type_index = graph.find(named)
    if type_index < 0:
        return
    ref type = graph.types[type_index]
    if type.kind != TypeKind.UNION and type.kind != TypeKind.INTERFACE:
        return
    var members: List[String]
    if type.kind == TypeKind.UNION:
        members = type.values.copy()
    else:
        members = _implementors(graph, named)
    for index in range(len(possible)):
        if possible[index].name != named:
            continue
        var member_index = 0
        while member_index < len(members):
            append_new(possible[index].members, String(members[member_index]))
            member_index += 1
        return
    possible.append(_Possible(named^, members^))


def _implementors(graph: GraphFacts, interface_name: String) -> List[String]:
    """Return the object types that implement an interface in one subgraph.

    Args:
        graph: The subgraph.
        interface_name: The interface name.

    Returns:
        The object names, in creation order.
    """
    var names = List[String]()
    var type_index = 0
    while type_index < len(graph.types):
        ref type = graph.types[type_index]
        type_index += 1
        if type.kind != TypeKind.OBJECT:
            continue
        for name_index in range(len(type.interfaces)):
            if type.interfaces[name_index] == interface_name:
                names.append(String(type.name))
    return names^


def _add_group(
    mut groups: List[_TypeGroup], type_text: String, graph_name: String
):
    """Add a subgraph to the group for its printed type.

    Args:
        groups: The groups, in first-seen order.
        type_text: The printed type.
        graph_name: The subgraph name.
    """
    for index in range(len(groups)):
        if groups[index].type_text != type_text:
            continue
        groups[index].names.append(String(graph_name))
        return
    var names = List[String]()
    names.append(String(graph_name))
    groups.append(_TypeGroup(String(type_text), names^))


def _group_text(group: _TypeGroup) -> String:
    """Return one type group, as Hive prints it.

    Args:
        group: The subgraphs that use this type.

    Returns:
        Such as `type "String!" in subgraphs "a", "b"`.
    """
    return 'type "' + group.type_text + '" in ' + subgraph_place(group.names)


def _output_key(super_type: String, local_type: String) -> String:
    """Return the output type Hive groups by.

    Args:
        super_type: The merged field type.
        local_type: The type in one subgraph.

    Returns:
        The normalized type when it matches, otherwise `local_type`.
    """
    var super_norm = String(super_type)
    var local_norm = String(local_type)
    if not super_norm.endswith("!"):
        local_norm = _strip_non_null(local_norm)
    if _starts_with_list(super_norm) and _starts_with_list(local_norm):
        var inner_super = _strip_list(super_norm)
        var inner_local = _strip_list(local_norm)
        if not inner_super.endswith("!"):
            inner_local = _strip_non_null(inner_local)
        var super_sign = String("")
        if super_norm.endswith("!"):
            super_sign = "!"
        var local_sign = String("")
        if local_norm.endswith("!"):
            local_sign = "!"
        super_norm = "[" + inner_super + "]" + super_sign
        local_norm = "[" + inner_local + "]" + local_sign
    if super_norm == local_norm:
        return local_norm^
    return String(local_type)


def _input_key(super_type: String, local_type: String) -> String:
    """Return the input type Hive groups by.

    Args:
        super_type: The merged field type.
        local_type: The type in one subgraph.

    Returns:
        The non-null type when only `!` differs, otherwise `local_type`.
    """
    if _strip_non_null(super_type) != _strip_non_null(local_type):
        return String(local_type)
    if super_type.endswith("!"):
        if local_type.endswith("!"):
            return String(local_type)
        return local_type + "!"
    return String(local_type)


def _strip_non_null(text: String) -> String:
    """Drop one trailing `!`.

    Args:
        text: A printed type.

    Returns:
        The type without one trailing `!`.
    """
    if not text.endswith("!"):
        return String(text)
    return String(text[byte = : text.byte_length() - 1])


def _strip_list(text: String) -> String:
    """Drop the outer brackets, as Hive `stripList`.

    Args:
        text: A printed type that starts with `[`. A printed list type
            always ends its list with `]`.

    Returns:
        The text between the first `[` and the last `]`.
    """
    return String(text[byte = 1 : text.rfind("]")])


def _starts_with_list(text: String) -> Bool:
    """Return True when the printed type starts with `[`.

    Args:
        text: A printed type.

    Returns:
        Whether the first byte is `[`.
    """
    return text.startswith("[")


def _last_bang(text: String) -> Int:
    """Return the index of the last `!`, or -1.

    Args:
        text: A printed type.

    Returns:
        The byte index, or -1 when there is no `!`.
    """
    return text.rfind("!")


def _named_type(text: String) -> String:
    """Drop `!`, `[` and `]` from a printed type.

    Args:
        text: A printed type.

    Returns:
        The named type, such as `String` for `[String!]!`.
    """
    return text.replace("!", "").replace("[", "").replace("]", "")
