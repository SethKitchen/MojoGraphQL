# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An object field must be a subtype of each interface field it implements.

Port of `InterfaceSubtypeRule` of Hive Federation Composition v0.27.0
`src/supergraph/validation/rules/interface-subtype-rule.ts`.

The merged output type is compared. A non-null type is a subtype of its
nullable form. A list is a subtype only of a list. An object is a subtype
of an interface it implements, and of a union that lists it.

An object field merges as in Hive's `object-type.ts`: the first
non-`@external` copy sets the type, and then the least non-null copy
wins. An interface field merges as in Hive's `interface-type.ts`: a
nullable copy replaces a non-null type.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts, TypeFacts
from gql_composition.merged import (
    has_field,
    append_new,
    contains,
    field_names,
    type_names,
)
from gql_composition.state import ExtensionType, TypeKind


def check_interface_subtype(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report an object field that is not a subtype of its interface field.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives `Type.field` for each error, in the same order.

    Returns:
        The `INVALID_GRAPHQL` errors for this rule.
    """
    var errors = List[CompositionError]()
    var interfaces = List[String]()
    var implementers = List[List[String]]()
    _implementations(facts, interfaces, implementers)
    var names = type_names(facts, TypeKind.OBJECT)
    for index in range(len(names)):
        _check_object(
            facts, String(names[index]), interfaces, implementers, errors, found
        )
    return errors^


def _check_object(
    facts: List[GraphFacts],
    type_name: String,
    interfaces: List[String],
    implementers: List[List[String]],
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append errors for one object type.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        interfaces: Interface names that have implementers.
        implementers: The implementer names, parallel to `interfaces`.
        errors: The errors to append.
        found: Receives `Type.field` for each error.
    """
    var implemented = _direct_interfaces(facts, type_name)
    if len(implemented) == 0:
        return
    # An object type has fields, and `implemented` is not empty.
    var fields = field_names(facts, type_name, TypeKind.OBJECT)
    var field_index = 0
    while field_index < len(fields):
        var field_name = String(fields[field_index])
        field_index += 1
        var object_type = _merged_object_type(facts, type_name, field_name)
        var interface_index = 0
        while interface_index < len(implemented):
            var interface_name = String(implemented[interface_index])
            interface_index += 1
            if _lookup(facts, interface_name) != 2:
                continue
            if not has_field(
                facts, interface_name, TypeKind.INTERFACE, field_name
            ):
                continue
            var interface_type = _merged_interface_type(
                facts, interface_name, field_name
            )
            if _is_subtype(
                facts, interfaces, implementers, object_type, interface_type
            ):
                continue
            var coordinate = type_name + "." + field_name
            found.append(coordinate)
            errors.append(
                CompositionError(
                    "Interface field "
                    + interface_name
                    + "."
                    + field_name
                    + " expects type "
                    + interface_type
                    + " but "
                    + coordinate
                    + " of type "
                    + object_type
                    + " is not a proper subtype.",
                    ErrorCode.INVALID_GRAPHQL,
                    None,
                )
            )


def _is_subtype(
    facts: List[GraphFacts],
    interfaces: List[String],
    implementers: List[List[String]],
    sub_type: String,
    super_type: String,
) -> Bool:
    """Return True when `sub_type` is a subtype of `super_type`.

    Args:
        facts: The subgraphs, in id order.
        interfaces: Interface names that have implementers.
        implementers: The implementer names, parallel to `interfaces`.
        sub_type: The object field's merged type.
        super_type: The interface field's merged type.

    Returns:
        Whether Hive's `isTypeSubTypeOf` accepts the pair. Only an object
        or an interface can be a union member or an implementer, so the
        kind of `sub_type` needs no separate check.
    """
    if sub_type == super_type:
        return True
    if super_type.endswith("!"):
        if sub_type.endswith("!"):
            return _is_subtype(
                facts,
                interfaces,
                implementers,
                _strip_bang(sub_type),
                _strip_bang(super_type),
            )
        return False
    if sub_type.endswith("!"):
        return _is_subtype(
            facts, interfaces, implementers, _strip_bang(sub_type), super_type
        )
    if super_type.endswith("]"):
        if sub_type.endswith("]"):
            return _is_subtype(
                facts,
                interfaces,
                implementers,
                _strip_list(sub_type),
                _strip_list(super_type),
            )
        return False
    if sub_type.endswith("]"):
        return False
    var super_kind = _lookup(facts, super_type)
    if super_kind == 3:
        return _union_member(facts, super_type, sub_type)
    if super_kind == 2:
        return _contains_implementer(
            interfaces, implementers, super_type, sub_type
        )
    return False


def _merged_object_type(
    facts: List[GraphFacts], type_name: String, field_name: String
) -> String:
    """Return the merged output type of one object field.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.
        field_name: The field.

    Returns:
        The type Hive's `object-type.ts` keeps for the field.
    """
    var merged = String("")
    var seen = False
    var started = False
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, TypeKind.OBJECT)
        if type_at == -1:
            continue
        ref type = graph.types[type_at]
        var field_at = type.find_field(field_name)
        if field_at == -1:
            continue
        ref field = type.fields[field_at]
        var external = _is_external(field.external, type, graph.version_number)
        var text = String(field.type_text)
        if not started:
            merged = text
            started = True
        else:
            var should_force = (
                not field.used_as_key and not external and not seen
            )
            var should_change = should_force or (
                not external and _last_bang(merged) > _last_bang(text)
            )
            if should_change:
                merged = text
        if not seen and not external:
            seen = True
    return merged


def _merged_interface_type(
    facts: List[GraphFacts], type_name: String, field_name: String
) -> String:
    """Return the merged output type of one interface field.

    Args:
        facts: The subgraphs, in id order.
        type_name: The interface type.
        field_name: The field. Some subgraph defines it.

    Returns:
        The type Hive's `interface-type.ts` keeps for the field: the
        first type, replaced by a later nullable type while it is
        non-null.
    """
    var merged = String("")
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, TypeKind.INTERFACE)
        if type_at == -1:
            continue
        ref type = graph.types[type_at]
        var field_at = type.find_field(field_name)
        if field_at == -1:
            continue
        ref text = type.fields[field_at].type_text
        if merged.byte_length() == 0:
            merged = String(text)
        elif merged.endswith("!") and not text.endswith("!"):
            merged = String(text)
    return merged


def _is_external(external: Bool, type: TypeFacts, version: Int) -> Bool:
    """Return True when Hive treats the field as `@external`.

    Args:
        external: Whether the field is marked `@external`.
        type: The parent object type in that subgraph.
        version: The federation version number.

    Returns:
        The `isExternal` flag used while merging the field type. In
        `v1.0`, `isFederationExtension` is true only for `@extends`,
        and `@extends` always marks the type as an extension.
    """
    if version != 100:
        return external
    return external and type.extension_type == ExtensionType.EXTENDS


def _implementations(
    facts: List[GraphFacts],
    mut interfaces: List[String],
    mut implementers: List[List[String]],
):
    """Collect objects and interfaces that implement each interface.

    Args:
        facts: The subgraphs, in id order.
        interfaces: Receives each interface name once.
        implementers: Receives the implementer names for that interface.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        for type_index in range(len(graph.types)):
            ref type = graph.types[type_index]
            if type.kind != TypeKind.OBJECT and type.kind != TypeKind.INTERFACE:
                continue
            for index in range(len(type.interfaces)):
                var interface_name = String(type.interfaces[index])
                if _lookup(facts, interface_name) != 2:
                    continue
                _add_implementer(
                    interfaces, implementers, interface_name, type.name
                )


def _add_implementer(
    mut interfaces: List[String],
    mut implementers: List[List[String]],
    interface_name: String,
    type_name: String,
):
    """Record one implementer of an interface.

    Args:
        interfaces: The interface names so far.
        implementers: The implementer names, parallel to `interfaces`.
        interface_name: The interface.
        type_name: The object or interface that implements it.
    """
    for index in range(len(interfaces)):
        if interfaces[index] != interface_name:
            continue
        ref members = implementers[index]
        append_new(members, type_name)
        return
    var members = List[String]()
    members.append(String(type_name))
    interfaces.append(String(interface_name))
    implementers.append(members^)


def _contains_implementer(
    interfaces: List[String],
    implementers: List[List[String]],
    interface_name: String,
    type_name: String,
) -> Bool:
    """Return True when a type implements an interface.

    Args:
        interfaces: The interface names. The checked object implements
            one of them, so the list is not empty.
        implementers: The implementer names, parallel to `interfaces`.
        interface_name: The interface.
        type_name: The candidate subtype.

    Returns:
        Whether the implementations map contains the type.
    """
    var index = 0
    while index < len(interfaces):
        if interfaces[index] == interface_name:
            return contains(implementers[index], type_name)
        index += 1
    return False


def _union_member(
    facts: List[GraphFacts], union_name: String, type_name: String
) -> Bool:
    """Return True when an object is a member of a union.

    Args:
        facts: The subgraphs, in id order.
        union_name: The union.
        type_name: The object type.

    Returns:
        Whether any subgraph lists the object.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(union_name, TypeKind.UNION)
        if type_at == -1:
            continue
        if contains(graph.types[type_at].values, type_name):
            return True
    return False


def _lookup(facts: List[GraphFacts], name: String) -> Int:
    """Return 1 for an object, 2 for an interface, 3 for a union, or 0.

    Args:
        facts: The subgraphs, in id order.
        name: The type name.

    Returns:
        The kind Hive's `getTypeFromSupergraph` would select. A subgraph
        state has one type for each name.
    """
    var found = 0
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find(name)
        if type_at == -1:
            continue
        var kind = graph.types[type_at].kind
        if kind == TypeKind.OBJECT:
            return 1
        if kind == TypeKind.INTERFACE and found == 0:
            found = 2
        if kind == TypeKind.UNION and found == 0:
            found = 3
    return found


def _direct_interfaces(
    facts: List[GraphFacts], type_name: String
) -> List[String]:
    """Return the interfaces an object implements, in first-seen order.

    Args:
        facts: The subgraphs, in id order.
        type_name: The object type.

    Returns:
        The interface names, once each.
    """
    var names = List[String]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_at = graph.find_kind(type_name, TypeKind.OBJECT)
        if type_at == -1:
            continue
        ref interfaces = graph.types[type_at].interfaces
        for index in range(len(interfaces)):
            append_new(names, interfaces[index])
    return names^


def _strip_bang(text: String) -> String:
    """Drop one trailing `!`.

    Args:
        text: A printed type.

    Returns:
        The type without one trailing bang.
    """
    return String(text[byte = 0 : text.byte_length() - 1])


def _strip_list(text: String) -> String:
    """Drop one pair of wrapping brackets.

    Args:
        text: A printed list type, such as `[A!]`.

    Returns:
        The inner type.
    """
    return String(text[byte = 1 : text.byte_length() - 1])


def _last_bang(text: String) -> Int:
    """Return the byte index of the last `!`, or -1.

    Args:
        text: A printed type.

    Returns:
        The index Hive's `lastIndexOf` returns.
    """
    return text.rfind("!")
