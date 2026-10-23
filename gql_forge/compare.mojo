# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Compare two Forge variants of the same graph.

The comparison uses `findBreakingChanges` and `findDangerousChanges` from
`gql_schema`. It also lists types and fields that exist only in the newer
schema.

Differences from upstream: none; there is no upstream.
"""

from gql_forge.catalog import Catalog
from gql_forge.schema_view import user_type_names
from gql_forge.store import read_file
from gql_json.writer import JsonWriter
from gql_schema.build import build_schema
from gql_schema.definition import Schema
from gql_schema.find_breaking_changes import (
    find_breaking_changes,
    find_dangerous_changes,
)


@fieldwise_init
struct SchemaChange(Copyable, Movable):
    """One change between two schemas."""

    var severity: String
    """`breaking`, `dangerous` or `additive`."""
    var code: String
    """The graphql-js change type, or `TYPE_ADDED` / `FIELD_ADDED`."""
    var description: String
    """What changed, in words."""


@fieldwise_init
struct VariantDiff(Copyable, Movable):
    """The comparison of two variants."""

    var from_variant: String
    """The older variant name."""
    var to_variant: String
    """The newer variant name."""
    var from_revision: Int
    """The schema revision of the older variant."""
    var to_revision: Int
    """The schema revision of the newer variant."""
    var error: String
    """Why the comparison failed. Empty when it succeeded."""
    var changes: List[SchemaChange]
    """The changes, breaking first, then dangerous, then additive."""


def field_names(schema: Schema, type_index: Int) -> List[String]:
    """Return the field names of an object or interface.

    Args:
        schema: The schema.
        type_index: The type.

    Returns:
        The field names. Empty when the type has no fields.
    """
    var names = List[String]()
    if type_index < 0 or type_index >= len(schema.types):
        return names^
    var typ = schema.types[type_index].copy()
    if not typ.kind.has_fields():
        return names^
    var start = Int(typ.fields.start)
    var count = Int(typ.fields.count)
    var index = 0
    while index < count:
        names.append(schema.fields[start + index].name.copy())
        index += 1
    return names^


def _has_name(names: List[String], name: StringSlice) -> Bool:
    """Return True when a name is in a list.

    Args:
        names: The names.
        name: The name to find.

    Returns:
        Whether it occurs.
    """
    for ref item in names:
        if item == name:
            return True
    return False


def additive_changes(old: Schema, new: Schema) -> List[SchemaChange]:
    """Return types and fields that exist only in the newer schema.

    Args:
        old: The older schema.
        new: The newer schema.

    Returns:
        Additive changes. A new type is listed once. Its fields are not
        listed again.
    """
    var changes = List[SchemaChange]()
    var old_names = user_type_names(old)
    for ref name in user_type_names(new):
        if not _has_name(old_names, name):
            changes.append(
                SchemaChange(
                    String("additive"),
                    String("TYPE_ADDED"),
                    name + " was added.",
                )
            )
            continue
        var old_type = old.type_named(name)
        var new_type = new.type_named(name)
        if old_type < 0 or new_type < 0:
            continue
        if not new.types[new_type].kind.has_fields():
            continue
        if old.types[old_type].kind != new.types[new_type].kind:
            continue
        var before = field_names(old, old_type)
        for ref field in field_names(new, new_type):
            if not _has_name(before, field):
                changes.append(
                    SchemaChange(
                        String("additive"),
                        String("FIELD_ADDED"),
                        name + "." + field + " was added.",
                    )
                )
    return changes^


def compare_schemas(
    old_sdl: StringSlice, new_sdl: StringSlice
) raises -> List[SchemaChange]:
    """Compare two SDL documents.

    Args:
        old_sdl: The older schema.
        new_sdl: The newer schema.

    Returns:
        Breaking, dangerous and additive changes.

    Raises:
        Error: When either document is not a schema, or as
            `find_breaking_changes` raises.
    """
    var old = build_schema(old_sdl)
    var new = build_schema(new_sdl)
    var changes = List[SchemaChange]()
    for ref change in find_breaking_changes(old, new):
        changes.append(
            SchemaChange(
                String("breaking"),
                String(change.type.text()),
                change.description.copy(),
            )
        )
    for ref change in find_dangerous_changes(old, new):
        changes.append(
            SchemaChange(
                String("dangerous"),
                String(change.type.text()),
                change.description.copy(),
            )
        )
    for ref change in additive_changes(old, new):
        changes.append(change.copy())
    return changes^


def compare_json(diff: VariantDiff) -> String:
    """Write a variant comparison as JSON.

    Args:
        diff: The comparison.

    Returns:
        The JSON object.
    """
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("from")
    writer.string(diff.from_variant)
    writer.key("to")
    writer.string(diff.to_variant)
    writer.key("fromRevision")
    writer.int(Int64(diff.from_revision))
    writer.key("toRevision")
    writer.int(Int64(diff.to_revision))
    writer.key("error")
    writer.string(diff.error)
    writer.key("breaking")
    var breaking = 0
    var dangerous = 0
    var additive = 0
    for ref change in diff.changes:
        if change.severity == "breaking":
            breaking += 1
        elif change.severity == "dangerous":
            dangerous += 1
        else:
            additive += 1
    writer.int(Int64(breaking))
    writer.key("dangerous")
    writer.int(Int64(dangerous))
    writer.key("additive")
    writer.int(Int64(additive))
    writer.key("changes")
    writer.begin_array()
    for ref change in diff.changes:
        writer.begin_object()
        writer.key("severity")
        writer.string(change.severity)
        writer.key("code")
        writer.string(change.code)
        writer.key("description")
        writer.string(change.description)
        writer.end_object()
    writer.end_array()
    writer.end_object()
    return writer^.take_string()


def current_schema_sdl(
    catalog: Catalog, org: StringSlice, graph: StringSlice, variant: StringSlice
) -> Optional[String]:
    """Read the current schema snapshot of a variant.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.
        variant: The variant name.

    Returns:
        The SDL, or none when no snapshot is stored.
    """
    var path = catalog.store.current_schema_path(org, graph, variant)
    try:
        var revision = atol(String(read_file(path).strip()))
        if revision <= 0:
            return None
        return read_file(
            catalog.store.schema_path(org, graph, variant, revision)
        )
    except:
        return None


def compare_variants(
    catalog: Catalog,
    org: StringSlice,
    graph: StringSlice,
    from_variant: StringSlice,
    to_variant: StringSlice,
) raises -> VariantDiff:
    """Compare the current schemas of two variants.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.
        from_variant: The older variant.
        to_variant: The newer variant.

    Returns:
        The comparison. `error` is set when a variant or schema is
        missing.

    Raises:
        Error: When a catalog file cannot be read, or as
            `compare_schemas` raises.
    """
    var diff = VariantDiff(
        String(from_variant),
        String(to_variant),
        0,
        0,
        String(""),
        List[SchemaChange](),
    )
    if not catalog.has_variant(org, graph, from_variant):
        diff.error = "Variant '" + String(from_variant) + "' is not in Forge."
        return diff^
    if not catalog.has_variant(org, graph, to_variant):
        diff.error = "Variant '" + String(to_variant) + "' is not in Forge."
        return diff^
    var older = catalog.get_variant(org, graph, from_variant)
    var newer = catalog.get_variant(org, graph, to_variant)
    diff.from_revision = older.schema_revision
    diff.to_revision = newer.schema_revision
    var old_sdl = current_schema_sdl(catalog, org, graph, from_variant)
    var new_sdl = current_schema_sdl(catalog, org, graph, to_variant)
    if not old_sdl:
        diff.error = (
            "Variant '" + String(from_variant) + "' has no schema snapshot."
        )
        return diff^
    if not new_sdl:
        diff.error = (
            "Variant '" + String(to_variant) + "' has no schema snapshot."
        )
        return diff^
    diff.changes = compare_schemas(old_sdl.value(), new_sdl.value())
    return diff^
