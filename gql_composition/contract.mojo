# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Compose a schema contract by tag.

Port of Hive Federation Composition v0.27.0 `src/contracts/schema-contract.ts`,
`tag-extraction.ts`, and the unreachable-type half of
`add-inaccessible-to-unreachable-types.ts`. A tag in `exclude` marks that
coordinate `@inaccessible`. A coordinate is marked when `include` is not
empty and the coordinate lacks every included tag. A tag on a type is copied
onto its fields, arguments, and enum values, including a field that only
another subgraph defines. A field tag is the union across subgraphs, so a
tag in one subgraph hides that field in every subgraph. An `@external`
field keeps its `@tag`, but its arguments are filtered. A renamed `@tag`
import is honored. Include and exclude both apply: a field is hidden when
it lacks an included tag or has an excluded tag. A type whose fields are
all excluded in every subgraph, an excluded scalar, and an excluded union
become `@inaccessible`. `@tag` applications are removed. A type that the
public schema cannot reach is marked `@inaccessible`, except the federation
types that upstream lists. `policy__Policy` and `requiresScopes__Scope` are
not in that list, so they are marked too.

Differences from upstream: a `@tag` with no argument raises an `Error`.
Upstream throws a `TypeError` at the same place.
"""

from gql_composition.compose import CompositionResult, compose_subgraphs
from gql_composition.error_code import CompositionError
from gql_composition.link import (
    Link,
    links_from_document,
    resolve_imported_name,
)
from gql_composition.public_schema import public_schema
from gql_composition.validate import Subgraph
from gql_language.ast import NO_NODE, Document, Kind, OperationType, Role
from gql_language.parser import parse
from std.collections import Dict


def compose_contract(
    subgraphs: List[Subgraph], include: List[String], exclude: List[String]
) raises -> CompositionResult:
    """Compose a contract, as upstream `composeSchemaContract`.

    Args:
        subgraphs: The subgraphs, in any order.
        include: Tags a coordinate must have. Empty means no include filter.
        exclude: Tags that hide a coordinate.

    Returns:
        The supergraph and its public schema, or the composition errors.

    Raises:
        Error: A subgraph `@link` import is invalid, or a `@tag` has no
            argument.
        GraphQLError: The filtered supergraph does not parse.
    """
    var tags = Dict[String, String]()
    var subs = Dict[String, String]()
    var type_names = List[String]()
    var index = 0
    while index < len(subgraphs):
        _collect(subgraphs[index].type_defs, tags, subs, type_names)
        index += 1
    _propagate(tags, subs, type_names)
    var filtered = List[Subgraph]()
    var trackers = List[String]()
    var applied = List[String]()
    index = 0
    while index < len(subgraphs):
        var tracker = String("\n")
        var used = String("\n")
        var document = _filter_document(
            subgraphs[index].type_defs,
            tags,
            include,
            exclude,
            tracker,
            used,
        )
        tracker = _drop_name(tracker, _query_name(subgraphs[index].type_defs))
        trackers.append(tracker^)
        applied.append(used^)
        filtered.append(
            Subgraph(
                String(subgraphs[index].name),
                subgraphs[index].url.copy(),
                document^,
            )
        )
        index += 1
    var marked_subgraphs = _mark_empty_types(filtered^, trackers, applied)
    var result = compose_subgraphs(marked_subgraphs^)
    if len(result.errors) > 0:
        return result^
    var marked = _mark_unreachable(result.supergraph_sdl, result.public_sdl)
    if marked == result.supergraph_sdl:
        return result^
    return CompositionResult(
        List[CompositionError](), marked, public_schema(marked)
    )


def _collect(
    document: Document,
    mut tags: Dict[String, String],
    mut subs: Dict[String, String],
    mut type_names: List[String],
) raises:
    """Record `@tag` names by schema coordinate.

    Args:
        document: One subgraph.
        tags: Coordinate to newline-wrapped tag names.
        subs: Type name to newline-wrapped child coordinates.
        type_names: Types that gained a child coordinate, once each.

    Raises:
        Error: A `@link` import is invalid.
    """
    var tag_name = _import_name(
        document, "https://specs.apollo.dev/federation", "@tag"
    )
    var child = document.first_child(document.root)
    while child != NO_NODE:
        if _is_type(document.kind(child)):
            var type_name = String(document.name(child))
            _record_tags(document, child, tag_name, type_name, tags)
            var nested = document.first_child(child)
            while nested != NO_NODE:
                var kind = document.kind(nested)
                # A type holds an input value only as an input field.
                if (
                    kind == Kind.FIELD_DEFINITION
                    or kind == Kind.INPUT_VALUE_DEFINITION
                ):
                    var field = type_name + "." + String(document.name(nested))
                    _add_sub(subs, type_names, type_name, field)
                    _record_tags(document, nested, tag_name, field, tags)
                    if kind == Kind.FIELD_DEFINITION:
                        var argument = document.first_child(nested)
                        while argument != NO_NODE:
                            if document.role(argument) == Role.ARGUMENT:
                                var coord = (
                                    field
                                    + "("
                                    + String(document.name(argument))
                                    + ":)"
                                )
                                _add_sub(subs, type_names, type_name, coord)
                                _record_tags(
                                    document, argument, tag_name, coord, tags
                                )
                            argument = document.next_sibling(argument)
                elif kind == Kind.ENUM_VALUE_DEFINITION:
                    var coord = type_name + "." + String(document.name(nested))
                    _add_sub(subs, type_names, type_name, coord)
                    _record_tags(document, nested, tag_name, coord, tags)
                nested = document.next_sibling(nested)
        child = document.next_sibling(child)


def _record_tags(
    document: Document,
    node: Int,
    tag_name: String,
    coordinate: String,
    mut tags: Dict[String, String],
) raises:
    """Add the `@tag` values of one node.

    Args:
        document: The subgraph.
        node: The element.
        tag_name: The local `@tag` name.
        coordinate: The schema coordinate.
        tags: The register to fill.

    Raises:
        Error: A `@tag` has no argument.
    """
    var child = document.first_child(node)
    while child != NO_NODE:
        if (
            document.kind(child) == Kind.DIRECTIVE
            and document.name(child) == tag_name
        ):
            var value = _tag_value(document, child)
            if value:
                _add_tag(tags, coordinate, value.value())
        child = document.next_sibling(child)


def _tag_value(document: Document, directive: Int) raises -> Optional[String]:
    """Return the tag name of a `@tag`, as upstream
    `createTagDirectiveNameExtractionStrategy`.

    The first argument must be `name` and hold a string. Otherwise the
    directive adds no tag.

    Args:
        document: The subgraph.
        directive: The `@tag` directive.

    Returns:
        The tag name, or nothing.

    Raises:
        Error: The directive has no argument. Upstream throws a
            `TypeError` here.
    """
    var argument = document.child(directive, Role.ARGUMENT)
    if argument == NO_NODE:
        raise Error("@tag has no name argument")
    if String(document.name(argument)) != "name":
        return None
    var value = document.child(argument, Role.VALUE)
    if document.kind(value) != Kind.STRING:
        return None
    return document.string_value(value)


def _add_tag(mut tags: Dict[String, String], coordinate: String, tag: String):
    """Add one tag to a coordinate. A repeated tag is harmless to the
    filter, so the register does not remove it.

    Args:
        tags: The register.
        coordinate: The schema coordinate.
        tag: The tag name.
    """
    var found = tags.get(coordinate)
    if found:
        tags[coordinate] = String(found.value()) + tag + "\n"
    else:
        tags[coordinate] = "\n" + tag + "\n"


def _add_sub(
    mut subs: Dict[String, String],
    mut type_names: List[String],
    type_name: String,
    coordinate: String,
):
    """Record a child coordinate of a type.

    Args:
        subs: Type name to child coordinates.
        type_names: Types already present in `subs`.
        type_name: The parent type.
        coordinate: The child coordinate.
    """
    var needle = "\n" + coordinate + "\n"
    var found = subs.get(type_name)
    if found:
        var existing = String(found.value())
        if existing.find(needle) == -1:
            subs[type_name] = existing + coordinate + "\n"
        return
    subs[type_name] = needle
    type_names.append(type_name)


def _propagate(
    mut tags: Dict[String, String],
    subs: Dict[String, String],
    type_names: List[String],
):
    """Copy each type's tags onto its fields, arguments, and enum values.

    Args:
        tags: The register.
        subs: Child coordinates by type.
        type_names: The types in `subs`.
    """
    var index = 0
    while index < len(type_names):
        var type_name = type_names[index]
        index += 1
        var type_found = tags.get(type_name)
        if not type_found:
            continue
        var inherited = List[String]()
        _each_line(String(type_found.value()), inherited)
        # `_add_sub` puts every name of `type_names` in `subs`.
        var children = List[String]()
        _each_line(String(subs.get(type_name).value()), children)
        var child_index = 0
        while child_index < len(children):
            var tag_index = 0
            while tag_index < len(inherited):
                _add_tag(tags, children[child_index], inherited[tag_index])
                tag_index += 1
            child_index += 1


def _each_line(blob: String, mut lines: List[String]):
    """Split a newline-wrapped blob into its entries.

    Args:
        blob: Entries wrapped in newlines.
        lines: Receives each entry.
    """
    var bytes = blob.as_bytes()
    var start = 0
    var index = 0
    while index < len(bytes):
        if bytes[index] == 10:
            if index > start:
                lines.append(String(blob[byte=start:index]))
            start = index + 1
        index += 1


def _lookup(tags: Dict[String, String], coordinate: String) -> String:
    """Return the tag blob of a coordinate, or a lone newline.

    Args:
        tags: The register.
        coordinate: The schema coordinate.

    Returns:
        The newline-wrapped tags.
    """
    var found = tags.get(coordinate)
    if found:
        return String(found.value())
    return String("\n")


def _intersects(blob: String, names: List[String]) -> Bool:
    """Return True when a tag blob contains one of a list of names.

    Args:
        blob: Newline-wrapped tags.
        names: The names to look for.

    Returns:
        Whether any name is present.
    """
    var index = 0
    while index < len(names):
        if blob.find("\n" + names[index] + "\n") != -1:
            return True
        index += 1
    return False


def _excluded(
    blob: String, include: List[String], exclude: List[String]
) -> Bool:
    """Return True when the filter hides a coordinate.

    Args:
        blob: The coordinate's tags.
        include: Tags that must intersect the coordinate.
        exclude: Tags that hide the coordinate.

    Returns:
        Whether the coordinate is hidden.
    """
    if len(include) > 0 and not _intersects(blob, include):
        return True
    if len(exclude) > 0 and _intersects(blob, exclude):
        return True
    return False


def _filter_document(
    document: Document,
    tags: Dict[String, String],
    include: List[String],
    exclude: List[String],
    mut tracker: String,
    mut applied: String,
) raises -> Document:
    """Copy a subgraph with the tag filter applied.

    Args:
        document: The subgraph.
        tags: Tags by coordinate, including inherited type tags.
        include: The include filter.
        exclude: The exclude filter.
        tracker: Receives `name=1` when every field is inaccessible.
        applied: Receives types already marked `@inaccessible`.

    Returns:
        The filtered document.

    Raises:
        Error: A `@link` import is invalid.
    """
    var tag_name = _import_name(
        document, "https://specs.apollo.dev/federation", "@tag"
    )
    var inaccessible_name = _import_name(
        document, "https://specs.apollo.dev/federation", "@inaccessible"
    )
    var external_name = _import_name(
        document, "https://specs.apollo.dev/federation", "@external"
    )
    var out = Document()
    var child = document.first_child(document.root)
    while child != NO_NODE:
        var copied = _copy_definition(
            out,
            document,
            child,
            tags,
            include,
            exclude,
            tag_name,
            inaccessible_name,
            external_name,
            tracker,
            applied,
        )
        out.append_child(out.root, copied)
        child = document.next_sibling(child)
    return out^


def _copy_definition(
    mut dest: Document,
    src: Document,
    node: Int,
    tags: Dict[String, String],
    include: List[String],
    exclude: List[String],
    tag_name: String,
    inaccessible_name: String,
    external_name: String,
    mut tracker: String,
    mut applied: String,
) -> Int:
    """Copy one definition, filtering object, interface, input, and enum types.

    Args:
        dest: The filtered document.
        src: The subgraph.
        node: The definition.
        tags: Tags by coordinate.
        include: The include filter.
        exclude: The exclude filter.
        tag_name: The local `@tag` name.
        inaccessible_name: The local `@inaccessible` name.
        external_name: The local `@external` name.
        tracker: All-fields-inaccessible flags.
        applied: Types already marked from an excluded type tag.

    Returns:
        The copy.
    """
    var kind = src.kind(node)
    if (
        kind == Kind.OBJECT_TYPE_DEFINITION
        or kind == Kind.OBJECT_TYPE_EXTENSION
        or kind == Kind.INTERFACE_TYPE_DEFINITION
        or kind == Kind.INTERFACE_TYPE_EXTENSION
        or kind == Kind.INPUT_OBJECT_TYPE_DEFINITION
        or kind == Kind.INPUT_OBJECT_TYPE_EXTENSION
    ):
        return _copy_fields(
            dest,
            src,
            node,
            tags,
            include,
            exclude,
            tag_name,
            inaccessible_name,
            external_name,
            tracker,
            applied,
        )
    if kind == Kind.ENUM_TYPE_DEFINITION or kind == Kind.ENUM_TYPE_EXTENSION:
        return _copy_enum(
            dest,
            src,
            node,
            tags,
            include,
            exclude,
            tag_name,
            inaccessible_name,
            tracker,
        )
    if (
        kind == Kind.SCALAR_TYPE_DEFINITION
        or kind == Kind.UNION_TYPE_DEFINITION
    ):
        var type_name = String(src.name(node))
        return _copy_rewritten(
            dest,
            src,
            node,
            Role.DEFINITION,
            tag_name,
            inaccessible_name,
            _excluded(_lookup(tags, type_name), include, exclude),
        )
    return _copy_tree(dest, src, node, Role.DEFINITION)


def _copy_fields(
    mut dest: Document,
    src: Document,
    node: Int,
    tags: Dict[String, String],
    include: List[String],
    exclude: List[String],
    tag_name: String,
    inaccessible_name: String,
    external_name: String,
    mut tracker: String,
    mut applied: String,
) -> Int:
    """Copy an object, interface, or input, filtering its fields.

    Args:
        dest: The filtered document.
        src: The subgraph.
        node: The type.
        tags: Tags by coordinate.
        include: The include filter.
        exclude: The exclude filter.
        tag_name: The local `@tag` name.
        inaccessible_name: The local `@inaccessible` name.
        external_name: The local `@external` name.
        tracker: All-fields-inaccessible flags.
        applied: Types marked from an excluded type tag.

    Returns:
        The copy.
    """
    var type_name = String(src.name(node))
    var type_hit = len(exclude) > 0 and _intersects(
        _lookup(tags, type_name), exclude
    )
    var external_type = _has_directive(src, node, external_name)
    var some = False
    var copy = _copy_one(dest, src, node, Role.DEFINITION)
    # Upstream applies `@inaccessible` once per type name in a subgraph.
    var pending = False
    if type_hit and applied.find("\n" + type_name + "\n") == -1:
        applied = applied + type_name + "\n"
        pending = not _has_directive(src, node, inaccessible_name)
    var child = src.first_child(node)
    while child != NO_NODE:
        var kind = src.kind(child)
        # A type holds an input value only as an input field.
        if kind == Kind.FIELD_DEFINITION or kind == Kind.INPUT_VALUE_DEFINITION:
            if pending:
                _add_directive(dest, copy, inaccessible_name)
                pending = False
            var accessible = False
            var field_copy = _copy_member(
                dest,
                src,
                child,
                type_name,
                tags,
                include,
                exclude,
                tag_name,
                inaccessible_name,
                external_name,
                external_type,
                accessible,
            )
            if accessible:
                some = True
            dest.append_child(copy, field_copy)
        elif kind == Kind.DIRECTIVE and src.name(child) == tag_name:
            pass
        else:
            # Only fields start the body of these types.
            dest.append_child(
                copy, _copy_tree(dest, src, child, src.role(child))
            )
        child = src.next_sibling(child)
    if pending:
        # The type has no field, such as `extend type T @tag(name: "x")`.
        _add_directive(dest, copy, inaccessible_name)
    if some:
        tracker = _set_flag(tracker, type_name, "0")
    elif _flag(tracker, type_name) != "0":
        tracker = _set_flag(tracker, type_name, "1")
    return copy


def _copy_member(
    mut dest: Document,
    src: Document,
    node: Int,
    type_name: String,
    tags: Dict[String, String],
    include: List[String],
    exclude: List[String],
    tag_name: String,
    inaccessible_name: String,
    external_name: String,
    external_type: Bool,
    mut accessible: Bool,
) -> Int:
    """Copy a field. An `@external` field keeps its directives.

    Args:
        dest: The filtered document.
        src: The subgraph.
        node: The field.
        type_name: The parent type.
        tags: Tags by coordinate.
        include: The include filter.
        exclude: The exclude filter.
        tag_name: The local `@tag` name.
        inaccessible_name: The local `@inaccessible` name.
        external_name: The local `@external` name.
        external_type: Whether the parent type is `@external`.
        accessible: Set when the field stays in the contract.

    Returns:
        The copy.
    """
    # Upstream filters the arguments of an `@external` field too. An
    # `@external` argument is not valid, so this port does not check for it.
    var external = external_type or _has_directive(src, node, external_name)
    var coord = type_name + "." + String(src.name(node))
    var copy = _copy_one(dest, src, node, src.role(node))
    var child = src.first_child(node)
    while child != NO_NODE:
        if src.role(child) == Role.ARGUMENT:
            var argument_coord = coord + "(" + String(src.name(child)) + ":)"
            dest.append_child(
                copy,
                _copy_rewritten(
                    dest,
                    src,
                    child,
                    src.role(child),
                    tag_name,
                    inaccessible_name,
                    _excluded(_lookup(tags, argument_coord), include, exclude),
                ),
            )
        elif (
            not external
            and src.kind(child) == Kind.DIRECTIVE
            and src.name(child) == tag_name
        ):
            pass
        else:
            dest.append_child(
                copy, _copy_tree(dest, src, child, src.role(child))
            )
        child = src.next_sibling(child)
    if external:
        return copy
    if _excluded(_lookup(tags, coord), include, exclude):
        if not _has_directive(src, node, inaccessible_name):
            _add_directive(dest, copy, inaccessible_name)
    else:
        accessible = True
    return copy


def _copy_enum(
    mut dest: Document,
    src: Document,
    node: Int,
    tags: Dict[String, String],
    include: List[String],
    exclude: List[String],
    tag_name: String,
    inaccessible_name: String,
    mut tracker: String,
) -> Int:
    """Copy an enum, filtering its values.

    Args:
        dest: The filtered document.
        src: The subgraph.
        node: The enum.
        tags: Tags by coordinate.
        include: The include filter.
        exclude: The exclude filter.
        tag_name: The local `@tag` name.
        inaccessible_name: The local `@inaccessible` name.
        tracker: All-values-inaccessible flags.

    Returns:
        The copy.
    """
    var type_name = String(src.name(node))
    var type_hit = len(exclude) > 0 and _intersects(
        _lookup(tags, type_name), exclude
    )
    var all_hidden = True
    var copy = _copy_one(dest, src, node, Role.DEFINITION)
    var child = src.first_child(node)
    while child != NO_NODE:
        if src.kind(child) == Kind.ENUM_VALUE_DEFINITION:
            var coord = type_name + "." + String(src.name(child))
            var hidden = _excluded(_lookup(tags, coord), include, exclude)
            if not hidden:
                all_hidden = False
            dest.append_child(
                copy,
                _copy_rewritten(
                    dest,
                    src,
                    child,
                    src.role(child),
                    tag_name,
                    inaccessible_name,
                    hidden,
                ),
            )
        elif src.kind(child) == Kind.DIRECTIVE and src.name(child) == tag_name:
            pass
        else:
            dest.append_child(
                copy, _copy_tree(dest, src, child, src.role(child))
            )
        child = src.next_sibling(child)
    # Upstream adds `@inaccessible` to every node of an excluded enum, and
    # does not record the enum as marked.
    if type_hit:
        if not _has_directive(src, node, inaccessible_name):
            _add_directive(dest, copy, inaccessible_name)
        return copy
    if not all_hidden:
        tracker = _set_flag(tracker, type_name, "0")
    elif _flag(tracker, type_name) != "0":
        tracker = _set_flag(tracker, type_name, "1")
    return copy


def _copy_rewritten(
    mut dest: Document,
    src: Document,
    node: Int,
    role: Role,
    tag_name: String,
    inaccessible_name: String,
    hidden: Bool,
) -> Int:
    """Copy a node, drop `@tag`, and add `@inaccessible` when it is hidden.

    Args:
        dest: The filtered document.
        src: The subgraph.
        node: The node.
        role: The role of the copy.
        tag_name: The local `@tag` name.
        inaccessible_name: The local `@inaccessible` name.
        hidden: Whether the filter hides the node.

    Returns:
        The copy.
    """
    var copy = _copy_one(dest, src, node, role)
    var pending = hidden and not _has_directive(src, node, inaccessible_name)
    var child = src.first_child(node)
    while child != NO_NODE:
        if src.kind(child) == Kind.DIRECTIVE and src.name(child) == tag_name:
            pass
        else:
            if pending and _starts_body(src, child):
                _add_directive(dest, copy, inaccessible_name)
                pending = False
            dest.append_child(
                copy, _copy_tree(dest, src, child, src.role(child))
            )
        child = src.next_sibling(child)
    if pending:
        _add_directive(dest, copy, inaccessible_name)
    return copy


def _starts_body(document: Document, node: Int) -> Bool:
    """Return True when a child starts the body of a type.

    Args:
        document: The document.
        node: The child.

    Returns:
        Whether directives should be inserted before this child.
    """
    # A field, an input field, an enum value, or a union member.
    var role = document.role(node)
    return (
        role == Role.FIELD
        or role == Role.ENUM_VALUE
        or role == Role.MEMBER_TYPE
    )


def _mark_empty_types(
    subgraphs: List[Subgraph],
    mut trackers: List[String],
    applied: List[String],
) raises -> List[Subgraph]:
    """Mark a type whose fields are inaccessible in every subgraph.

    Args:
        subgraphs: The filtered subgraphs.
        trackers: `name=1` when every field of that type is inaccessible.
        applied: Types already marked `@inaccessible`.

    Returns:
        The subgraphs, with those types marked.

    Raises:
        Error: A `@link` import is invalid.
    """
    # As upstream, the marked types form one set for every subgraph.
    var marks = String("\n")
    var index = 0
    while index < len(trackers):
        var lines = List[String]()
        _each_line(trackers[index], lines)
        var line_index = 0
        while line_index < len(lines):
            # Each tracker line is `name=1` or `name=0`.
            var line = lines[line_index]
            line_index += 1
            var eq = line.find("=")
            var name = String(line[byte=0:eq])
            if String(line[byte = eq + 1 :]) == "1":
                var every = True
                var other = 0
                while other < len(trackers):
                    if other != index and _flag(trackers[other], name) == "0":
                        every = False
                    other += 1
                if every:
                    marks = marks + name + "\n"
            var other = 0
            while other < len(trackers):
                if other != index:
                    trackers[other] = _drop_name(trackers[other], name)
                other += 1
        index += 1
    var out = List[Subgraph]()
    index = 0
    while index < len(subgraphs):
        var inaccessible_name = _import_name(
            subgraphs[index].type_defs,
            "https://specs.apollo.dev/federation",
            "@inaccessible",
        )
        var document = _mark_type_names(
            subgraphs[index].type_defs,
            marks,
            applied[index],
            inaccessible_name,
        )
        out.append(
            Subgraph(
                String(subgraphs[index].name),
                subgraphs[index].url.copy(),
                document^,
            )
        )
        index += 1
    return out^


def _mark_type_names(
    document: Document,
    marks: String,
    applied: String,
    inaccessible_name: String,
) -> Document:
    """Add `@inaccessible` to types named in `marks`, as upstream
    `makeTypesFromSetInaccessible`.

    Only the first definition of a type is marked, and a type in `applied`
    is not marked again.

    Args:
        document: The filtered subgraph.
        marks: Newline-wrapped type names.
        applied: Types that already have the directive.
        inaccessible_name: The local directive name.

    Returns:
        The document, with those types marked.
    """
    var done = applied
    var out = Document()
    var child = document.first_child(document.root)
    while child != NO_NODE:
        var hidden = False
        if _is_type(document.kind(child)):
            var wrapped = "\n" + String(document.name(child)) + "\n"
            if marks.find(wrapped) != -1 and done.find(wrapped) == -1:
                done = done + String(document.name(child)) + "\n"
                hidden = True
        if hidden:
            out.append_child(
                out.root,
                _copy_rewritten(
                    out,
                    document,
                    child,
                    Role.DEFINITION,
                    String(""),
                    inaccessible_name,
                    True,
                ),
            )
        else:
            out.append_child(
                out.root, _copy_tree(out, document, child, Role.DEFINITION)
            )
        child = document.next_sibling(child)
    return out^


def _mark_unreachable(supergraph: String, public: String) raises -> String:
    """Mark the types the public schema cannot reach, as upstream
    `addInaccessibleToUnreachableTypes`.

    The federation types that upstream lists stay unmarked. Upstream adds
    the directive after the other directives of the type and prints the
    supergraph again. That print keeps the line of a type definition, so
    this port inserts the directive text at the same place.

    Args:
        supergraph: The composed supergraph SDL.
        public: The public schema SDL.

    Returns:
        The supergraph, with each unreachable type marked `@inaccessible`.

    Raises:
        Error: A supergraph `@link` import is invalid.
        GraphQLError: Either SDL does not parse.
    """
    var reachable = _reachable(parse(public))
    var document = parse(supergraph)
    var links = links_from_document(document)
    var kept = _federation_types(links)
    var index = 0
    while index < len(kept):
        reachable[kept[index]] = True
        index += 1
    var directive = resolve_imported_name(
        links, "https://specs.apollo.dev/inaccessible", "@inaccessible"
    )
    var sdl = String("")
    var copied = 0
    var child = document.first_child(document.root)
    while child != NO_NODE:
        if _is_type(document.kind(child)):
            if String(document.name(child)) not in reachable:
                if not _has_directive(document, child, directive):
                    var at = _directives_end(document, child)
                    sdl += String(supergraph[byte=copied:at]) + " @" + directive
                    copied = at
        child = document.next_sibling(child)
    return sdl + String(supergraph[byte=copied:])


def _directives_end(document: Document, node: Int) -> Int:
    """Return the byte offset after the last directive of a type.

    Args:
        document: The supergraph.
        node: A type definition.

    Returns:
        The end of the last directive, or of the name when the type has no
        directive.
    """
    var end = document.end(document.child(node, Role.NAME))
    var child = document.first_child(node)
    while child != NO_NODE:
        if document.role(child) == Role.DIRECTIVE:
            end = document.end(child)
        child = document.next_sibling(child)
    return end


def _federation_types(links: List[Link]) -> List[String]:
    """Return the federation type names that are never marked.

    Args:
        links: The links of the supergraph.

    Returns:
        The local names, resolved as upstream does.
    """
    comptime join = "https://specs.apollo.dev/join"
    comptime link = "https://specs.apollo.dev/link"
    comptime federation = "https://specs.apollo.dev/federation"
    var names = List[String]()
    names.append(resolve_imported_name(links, join, "FieldSet"))
    names.append(resolve_imported_name(links, join, "Graph"))
    names.append(resolve_imported_name(links, link, "Import"))
    names.append(resolve_imported_name(links, link, "Purpose"))
    names.append(resolve_imported_name(links, federation, "Policy"))
    names.append(resolve_imported_name(links, federation, "Scope"))
    names.append(resolve_imported_name(links, join, "DirectiveArguments"))
    names.append(resolve_imported_name(links, join, "ContextArgument"))
    names.append(resolve_imported_name(links, join, "FieldValue"))
    names.append(
        resolve_imported_name(
            links, "https://specs.apollo.dev/context", "ContextFieldValue"
        )
    )
    return names^


def _reachable(document: Document) -> Dict[String, Bool]:
    """Return the type names reachable from the public roots, as upstream
    `getReachableTypes`.

    Args:
        document: The public schema.

    Returns:
        The reachable type names.
    """
    var definitions = Dict[String, Int]()
    var queue: List[String] = ["Query", "Mutation", "Subscription"]
    var child = document.first_child(document.root)
    while child != NO_NODE:
        if document.kind(child) == Kind.DIRECTIVE_DEFINITION:
            var argument = document.first_child(child)
            while argument != NO_NODE:
                if document.role(argument) == Role.ARGUMENT:
                    queue.append(_type_name(document, argument))
                argument = document.next_sibling(argument)
        else:
            # The public schema holds only types and directive definitions,
            # and it defines each type once.
            definitions[String(document.name(child))] = child
        child = document.next_sibling(child)
    var found = Dict[String, Bool]()
    var at = 0
    while at < len(queue):
        var name = queue[at]
        at += 1
        if name in found:
            continue
        found[name] = True
        var defined = definitions.get(name)
        if defined:
            _enqueue(document, defined.value(), queue)
    return found^


def _type_name(document: Document, node: Int) -> String:
    """Return the named type of a field or an argument.

    Args:
        document: The document.
        node: A field, an input field, or an argument.

    Returns:
        The type name, under any list and non-null wrappers.
    """
    return String(document.named_type(document.child(node, Role.TYPE)))


def _enqueue(document: Document, node: Int, mut queue: List[String]):
    """Queue the types a definition references.

    Args:
        document: The public schema.
        node: A type definition.
        queue: The walk queue.
    """
    var child = document.first_child(node)
    while child != NO_NODE:
        var role = document.role(child)
        if role == Role.INTERFACE or role == Role.MEMBER_TYPE:
            queue.append(String(document.name(child)))
        elif role == Role.FIELD:
            queue.append(_type_name(document, child))
            var argument = document.first_child(child)
            while argument != NO_NODE:
                if document.role(argument) == Role.ARGUMENT:
                    queue.append(_type_name(document, argument))
                argument = document.next_sibling(argument)
        child = document.next_sibling(child)
    if document.kind(node) == Kind.INTERFACE_TYPE_DEFINITION:
        var candidate = document.first_child(document.root)
        while candidate != NO_NODE:
            if document.kind(candidate) == Kind.OBJECT_TYPE_DEFINITION:
                var implemented = document.children(candidate, Role.INTERFACE)
                var index = 0
                while index < len(implemented):
                    if document.name(implemented[index]) == document.name(node):
                        queue.append(String(document.name(candidate)))
                    index += 1
            candidate = document.next_sibling(candidate)


def _is_type(kind: Kind) -> Bool:
    """Return True for a type definition or extension.

    Args:
        kind: The node kind.

    Returns:
        Whether the node introduces a type.
    """
    return (
        kind == Kind.SCALAR_TYPE_DEFINITION
        or kind == Kind.OBJECT_TYPE_DEFINITION
        or kind == Kind.INTERFACE_TYPE_DEFINITION
        or kind == Kind.UNION_TYPE_DEFINITION
        or kind == Kind.ENUM_TYPE_DEFINITION
        or kind == Kind.INPUT_OBJECT_TYPE_DEFINITION
        or kind == Kind.SCALAR_TYPE_EXTENSION
        or kind == Kind.OBJECT_TYPE_EXTENSION
        or kind == Kind.INTERFACE_TYPE_EXTENSION
        or kind == Kind.UNION_TYPE_EXTENSION
        or kind == Kind.ENUM_TYPE_EXTENSION
        or kind == Kind.INPUT_OBJECT_TYPE_EXTENSION
    )


def _has_directive(document: Document, node: Int, name: String) -> Bool:
    """Return True when a node applies a directive.

    Args:
        document: The document.
        node: The node.
        name: The directive name, without `@`.

    Returns:
        Whether the directive is present.
    """
    var child = document.first_child(node)
    while child != NO_NODE:
        if (
            document.kind(child) == Kind.DIRECTIVE
            and document.name(child) == name
        ):
            return True
        child = document.next_sibling(child)
    return False


def _add_directive(mut dest: Document, parent: Int, name: String):
    """Append a directive with no arguments.

    Args:
        dest: The document.
        parent: The parent node.
        name: The directive name, without `@`.
    """
    var directive = dest.add(Kind.DIRECTIVE, Role.DIRECTIVE, 0)
    _ = dest.add_name(directive, Role.NAME, name)
    dest.append_child(parent, directive)


def _import_name(
    document: Document, identity: String, element: String
) raises -> String:
    """Return the local name of a linked element, as upstream
    `extractLinkImplementations(...).resolveImportName`.

    Args:
        document: The subgraph.
        identity: The specification identity.
        element: The element, such as `@tag`.

    Returns:
        The local name, without `@`.

    Raises:
        Error: A `@link` import is invalid.
    """
    return resolve_imported_name(
        links_from_document(document), identity, element
    )


def _query_name(document: Document) -> String:
    """Return the query root name, as upstream
    `getRootQueryTypeNameFromDocumentNode`.

    Args:
        document: The subgraph.

    Returns:
        The query type, or `Query`.
    """
    var name = String("Query")
    var child = document.first_child(document.root)
    while child != NO_NODE:
        var kind = document.kind(child)
        if kind == Kind.SCHEMA_DEFINITION or kind == Kind.SCHEMA_EXTENSION:
            var operation = document.first_child(child)
            while operation != NO_NODE:
                if (
                    document.kind(operation) == Kind.OPERATION_TYPE_DEFINITION
                    and document.operation(operation) == OperationType.QUERY
                ):
                    name = String(
                        document.name(document.child(operation, Role.TYPE))
                    )
                operation = document.next_sibling(operation)
        child = document.next_sibling(child)
    return name


def _set_flag(blob: String, name: String, value: String) -> String:
    """Set `name=value` in a tracker blob.

    Args:
        blob: The tracker.
        name: The type name.
        value: `1` or `0`.

    Returns:
        The updated blob.
    """
    return _drop_name(blob, name) + name + "=" + value + "\n"


def _drop_name(blob: String, name: String) -> String:
    """Remove a type from a tracker blob.

    Args:
        blob: The blob.
        name: The type name.

    Returns:
        The blob without that type.
    """
    var out = _remove(blob, "\n" + name + "=1\n")
    return _remove(out, "\n" + name + "=0\n")


def _remove(blob: String, needle: String) -> String:
    """Remove one wrapped entry, keeping the surrounding newlines.

    Args:
        blob: The blob.
        needle: The wrapped entry, including both newlines.

    Returns:
        The blob without that entry.
    """
    var at = blob.find(needle)
    if at == -1:
        return blob
    var head = String(blob[byte=0:at])
    var tail = String(blob[byte = at + needle.byte_length() - 1 :])
    return head + "\n" + tail


def _flag(blob: String, name: String) -> String:
    """Return `1`, `0`, or empty for a tracked type.

    Args:
        blob: The tracker.
        name: The type name.

    Returns:
        The flag, or empty when the type is absent.
    """
    if blob.find("\n" + name + "=1\n") != -1:
        return String("1")
    if blob.find("\n" + name + "=0\n") != -1:
        return String("0")
    return String("")


def _copy_tree(mut dest: Document, src: Document, node: Int, role: Role) -> Int:
    """Copy a node and its children.

    Args:
        dest: The destination.
        src: The source.
        node: The node.
        role: The role of the copy.

    Returns:
        The copy.
    """
    return dest.copy_subtree(src, node, role)


def _copy_one(mut dest: Document, src: Document, node: Int, role: Role) -> Int:
    """Copy one node without its children.

    The port copies only definitions, fields, arguments, and enum values
    this way. These nodes have no text and no flags.

    Args:
        dest: The destination.
        src: The source.
        node: The node.
        role: The role of the copy.

    Returns:
        The copy.
    """
    return dest.add(src.kind(node), role, 0)
