# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A field resolved in more than one subgraph must be shareable.

Port of `InvalidFieldSharingRule` of Hive Federation Composition v0.27.0
`src/supergraph/validation/rules/invalid-field-sharing-rule.ts`. An
`@interfaceObject` field counts only when the object field is already
non-shareable.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import FieldFact, GraphFacts, TypeFacts
from gql_composition.merged import and_list, append_new
from gql_composition.state import TypeKind


@fieldwise_init
struct _Site(Movable):
    """One subgraph's contribution to a field."""

    var graph_name: String
    """The subgraph name."""
    var external: Bool
    """Whether the field is `@external`."""
    var shareable: Bool
    """Whether the field is `@shareable`."""
    var used_as_key: Bool
    """Whether a `@key` selects the field."""
    var override_from: String
    """The `@override(from:)` subgraph, or empty."""
    var in_extension: Bool
    """Whether the field is in a type extension."""
    var version_number: Int
    """The subgraph's federation version number."""
    var through: String
    """The `@interfaceObject` type and field, or empty."""
    var interface_object: Bool
    """Whether this subgraph defines the parent with `@interfaceObject`."""


@fieldwise_init
struct _Field(Movable):
    """One field and the subgraphs that define it."""

    var name: String
    """The field name."""
    var sites: List[_Site]
    """The subgraphs, in id order."""


@fieldwise_init
struct _Type(Movable):
    """One object or interface, in first-seen order."""

    var name: String
    """The type name."""
    var interface_object: Bool
    """Whether any subgraph uses `@interfaceObject`."""
    var entity: Bool
    """Whether any subgraph gives the type a `@key`."""
    var subscription: Bool
    """Whether any subgraph uses the type as its subscription root."""
    var interfaces: List[String]
    """The implemented interfaces, in first-seen order."""
    var fields: List[_Field]
    """The fields, in first-seen order."""


def check_field_sharing(
    facts: List[GraphFacts], mut coordinates: List[String]
) -> List[CompositionError]:
    """Report a non-shareable field resolved from more than one subgraph.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        coordinates: Receives `Type.field` for each error, in the same order.

    Returns:
        The `INVALID_FIELD_SHARING` errors. Object fields come first.
    """
    var objects = List[_Type]()
    var interfaces = List[_Type]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        var type_index = 0
        while type_index < len(graph.types):
            ref type = graph.types[type_index]
            if type.kind == TypeKind.OBJECT:
                _merge(objects, graph, type, False)
            elif type.kind == TypeKind.INTERFACE:
                _merge(interfaces, graph, type, True)
            type_index += 1
        graph_index += 1
    var errors = List[CompositionError]()
    _report_objects(errors, coordinates, objects, interfaces)
    _report_interfaces(errors, coordinates, interfaces)
    return errors^


def _merge(
    mut merged: List[_Type],
    graph: GraphFacts,
    type: TypeFacts,
    interface: Bool,
):
    """Merge one type into the shareable view.

    Args:
        merged: The types seen so far.
        graph: The subgraph.
        type: The type in that subgraph.
        interface: Whether the type is an interface.
    """
    var at = _ensure_type(merged, type.name)
    if type.key_count > 0:
        merged[at].entity = True
    if interface and type.is_interface_object:
        merged[at].interface_object = True
    if graph.subscription_name == type.name:
        merged[at].subscription = True
    for name_index in range(len(type.interfaces)):
        append_new(merged[at].interfaces, type.interfaces[name_index])
    var field_index = 0
    while field_index < len(type.fields):
        _add_field(
            merged[at],
            type.fields[field_index],
            graph,
            String(""),
            interface and type.is_interface_object,
        )
        field_index += 1


def _ensure_type(mut merged: List[_Type], name: String) -> Int:
    """Return the row for a type, creating it when it is new.

    Args:
        merged: The types seen so far.
        name: The type name.

    Returns:
        The index of the type.
    """
    var index = 0
    while index < len(merged):
        if merged[index].name == name:
            return index
        index += 1
    var interfaces = List[String]()
    var fields = List[_Field]()
    merged.append(
        _Type(String(name), False, False, False, interfaces^, fields^)
    )
    return len(merged) - 1


def _add_field(
    mut merged: _Type,
    field: FieldFact,
    graph: GraphFacts,
    through: String,
    interface_object: Bool,
):
    """Record one field from one subgraph.

    Args:
        merged: The type.
        field: The field.
        graph: The subgraph.
        through: The `@interfaceObject` coordinate, or empty.
        interface_object: Whether this subgraph uses `@interfaceObject`.
    """
    var site = _Site(
        String(graph.graph_name),
        field.external,
        field.shareable,
        field.used_as_key,
        String(field.override_from),
        field.in_extension,
        graph.version_number,
        String(through),
        interface_object,
    )
    for index in range(len(merged.fields)):
        if merged.fields[index].name != field.name:
            continue
        merged.fields[index].sites.append(site^)
        return
    var sites = List[_Site]()
    sites.append(site^)
    merged.fields.append(_Field(String(field.name), sites^))


def _report_objects(
    mut errors: List[CompositionError],
    mut coordinates: List[String],
    objects: List[_Type],
    interfaces: List[_Type],
):
    """Append object field sharing errors.

    Args:
        errors: The errors to append.
        coordinates: Receives `Type.field` for each error.
        objects: The object types.
        interfaces: The interface types, including `@interfaceObject`.
    """
    var type_index = 0
    while type_index < len(objects):
        ref type = objects[type_index]
        type_index += 1
        var field_index = 0
        while field_index < len(type.fields):
            ref field = type.fields[field_index]
            field_index += 1
            if type.subscription and len(field.sites) > 1:
                coordinates.append(type.name + "." + field.name)
                errors.append(
                    CompositionError(
                        (
                            "Fields on root level subscription object cannot be"
                            " marked as shareable"
                        ),
                        ErrorCode.INVALID_FIELD_SHARING,
                        None,
                    )
                )
                continue
            if _keys_everywhere(field.sites):
                continue
            var direct = List[_Site]()
            var site_index = 0
            while site_index < len(field.sites):
                direct.append(_copy_site(field.sites[site_index]))
                site_index += 1
            if _has_nonshareable_site(direct, type.entity):
                for name_index in range(len(type.interfaces)):
                    _add_interface_object(
                        direct,
                        interfaces,
                        type.interfaces[name_index],
                        field.name,
                    )
            _report(
                errors, coordinates, type.name, field.name, direct, type.entity
            )


def _report_interfaces(
    mut errors: List[CompositionError],
    mut coordinates: List[String],
    interfaces: List[_Type],
):
    """Append `@interfaceObject` field sharing errors.

    Args:
        errors: The errors to append.
        coordinates: Receives `Type.field` for each error.
        interfaces: The interface types.
    """
    for type_index in range(len(interfaces)):
        ref type = interfaces[type_index]
        if not type.interface_object:
            continue
        var field_index = 0
        while field_index < len(type.fields):
            var sites = List[_Site]()
            ref field = type.fields[field_index]
            field_index += 1
            var site_index = 0
            while site_index < len(field.sites):
                ref site = field.sites[site_index]
                site_index += 1
                if not site.interface_object:
                    continue
                sites.append(_copy_site(site))
            _report(errors, coordinates, type.name, field.name, sites, False)


def _has_nonshareable_site(sites: List[_Site], entity: Bool) -> Bool:
    """Return True when a resolvable site is not shareable.

    Args:
        sites: The object field's own sites.
        entity: Whether the object type has a `@key`.

    Returns:
        Whether Hive consults `@interfaceObject` fields for this field.
    """
    var index = 0
    while index < len(sites):
        ref site = sites[index]
        index += 1
        if not _resolvable(site, sites):
            continue
        if not _shareable(site, entity):
            return True
    return False


def _resolvable(site: _Site, sites: List[_Site]) -> Bool:
    """Return True when Hive counts a site as resolving the field.

    Args:
        site: One site.
        sites: Every site of the field.

    Returns:
        False for an `@external` site and for an effective `@override`.
    """
    if site.external:
        return False
    return not _override_keeps_source(site, sites)


def _shareable(site: _Site, entity: Bool) -> Bool:
    """Return True when a resolvable site may share the field.

    Args:
        site: One resolvable site.
        entity: Whether the object type has a `@key`.

    Returns:
        Whether the site is `@shareable`, a key field, or a Federation 1
        field on an entity extension.
    """
    var fed_v1 = entity and site.version_number < 200 and site.in_extension
    if site.shareable or site.used_as_key or fed_v1:
        return True
    return False


def _add_interface_object(
    mut sites: List[_Site],
    interfaces: List[_Type],
    interface_name: String,
    field_name: String,
):
    """Add an `@interfaceObject` field that resolves the same object field.

    Args:
        sites: The sites already collected.
        interfaces: The interface types.
        interface_name: An interface the object implements.
        field_name: The object field.
    """
    # Subgraph validation requires each implemented interface to exist, so
    # the interface is always found.
    var found = 0
    var index = 0
    while index < len(interfaces):
        if interfaces[index].name == interface_name:
            found = index
        index += 1
    if not interfaces[found].interface_object:
        return
    ref interface = interfaces[found]
    var field_at = -1
    index = 0
    while index < len(interface.fields):
        if interface.fields[index].name == field_name:
            field_at = index
        index += 1
    if field_at < 0 or _any_key(interface.fields[field_at].sites):
        return
    ref field = interface.fields[field_at]
    var site_index = 0
    while site_index < len(field.sites):
        ref site = field.sites[site_index]
        site_index += 1
        if not site.interface_object:
            continue
        var copy = _copy_site(site)
        copy.through = interface_name + "." + field_name
        sites.append(copy^)


def _report(
    mut errors: List[CompositionError],
    mut coordinates: List[String],
    type_name: String,
    field_name: String,
    sites: List[_Site],
    entity: Bool,
):
    """Append one error when a field is resolved more than once and is not shareable.

    Args:
        errors: The errors to append.
        coordinates: Receives `Type.field` when an error is appended.
        type_name: The parent type.
        field_name: The field.
        sites: The subgraphs that resolve it.
        entity: Whether the object type has a `@key`.
    """
    var labels = List[String]()
    var nonshareable = List[String]()
    var all = True
    for index in range(len(sites)):
        ref site = sites[index]
        if not _resolvable(site, sites):
            continue
        labels.append(_label(site))
        if _shareable(site, entity):
            all = False
            continue
        nonshareable.append(String(site.graph_name))
    if len(nonshareable) < 1 or len(labels) < 2:
        return
    var place = String("all of them")
    if not all:
        place = "subgraph"
        if len(nonshareable) > 1:
            place += "s"
        place += " " + and_list(nonshareable)
    coordinates.append(type_name + "." + field_name)
    errors.append(
        CompositionError(
            'Non-shareable field "'
            + type_name
            + "."
            + field_name
            + '" is resolved from multiple subgraphs: it is resolved from'
            " subgraphs "
            + _join_and(labels)
            + " and defined as non-shareable in "
            + place,
            ErrorCode.INVALID_FIELD_SHARING,
            None,
        )
    )


def _override_keeps_source(site: _Site, sites: List[_Site]) -> Bool:
    """Return True when `@override` replaces a field that still exists.

    Args:
        site: The overriding field.
        sites: Every site of the field.

    Returns:
        Whether Hive ignores this site.
    """
    if site.override_from.byte_length() == 0:
        return False
    var found = False
    var index = 0
    while index < len(sites):
        if sites[index].graph_name == site.override_from:
            found = True
        index += 1
    return found


def _any_key(sites: List[_Site]) -> Bool:
    """Return True when any site uses the field in a `@key`.

    Args:
        sites: The sites.

    Returns:
        Whether the merged field is used as a key.
    """
    var found = False
    var index = 0
    while index < len(sites):
        if sites[index].used_as_key:
            found = True
        index += 1
    return found


def _keys_everywhere(sites: List[_Site]) -> Bool:
    """Return True when every site uses the field in a `@key`.

    Args:
        sites: The sites.

    Returns:
        Whether Hive skips the field. The field comes from a subgraph,
        so `sites` is not empty.
    """
    var index = 0
    while index < len(sites):
        if not sites[index].used_as_key:
            return False
        index += 1
    return True


def _label(site: _Site) -> String:
    """Return the quoted subgraph, plus an `@interfaceObject` note.

    Args:
        site: One site.

    Returns:
        Such as `"users"` or `"users" (through @interfaceObject field "Node.id")`.
    """
    var out = String('"') + site.graph_name + '"'
    if site.through.byte_length() > 0:
        out += ' (through @interfaceObject field "' + site.through + '")'
    return out


def _join_and(parts: List[String]) -> String:
    """Join parts with `and` and no Oxford comma, as Hive `andList(parts,
    false)`.

    Args:
        parts: The parts, already quoted. A field sharing error has at
            least two.

    Returns:
        Such as `"a" and "b"` or `"a", "b" and "c"`.
    """
    var last = len(parts) - 1
    var out = String(parts[0])
    var index = 1
    while index < last:
        out += ", " + parts[index]
        index += 1
    return out + " and " + parts[last]


def _copy_site(site: _Site) -> _Site:
    """Copy a site.

    Args:
        site: The site.

    Returns:
        A new site with the same fields.
    """
    return _Site(
        String(site.graph_name),
        site.external,
        site.shareable,
        site.used_as_key,
        String(site.override_from),
        site.in_extension,
        site.version_number,
        String(site.through),
        site.interface_object,
    )
