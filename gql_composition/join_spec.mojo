# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `@join__` definitions of a supergraph.

Port of Hive Federation Composition v0.27.0 `src/specifications/join.ts`
(`sdl`) and the `federationVersionToJoinVersion` table of `src/compose.ts`.

`@join__field` gains `overrideLabel` in federation `v2.7` and
`contextArguments` in `v2.8`. The join specification URL is `v0.3` below
`v2.7`, `v0.4` in `v2.7`, and `v0.5` from `v2.8`.

**Differences from upstream.** Upstream compares versions with
`parseFloat`, which puts `v2.10` below `v2.9`. This port treats `v2.10`
to `v2.15` as later than `v2.8`, so they use join `v0.5` and the `v2.8`
arguments. Hive v0.27.0 has no row for those versions. An invalid
`FederationVersion` raises an `Error`.
"""

from gql_composition.version import FederationVersion


def join_spec_version(version: FederationVersion) raises -> String:
    """Return the join specification version for a federation version.

    Args:
        version: The federation version of the supergraph.

    Returns:
        `v0.3`, `v0.4`, or `v0.5`.

    Raises:
        Error: When `version` is not a supported federation version.
    """
    _require_version(version)
    if version.at_least(208):
        return String("v0.5")
    if version.at_least(207):
        return String("v0.4")
    return String("v0.3")


def join_sdl(version: FederationVersion) raises -> String:
    """Return the `@join__` definitions for a federation version.

    Args:
        version: The federation version of the supergraph.

    Returns:
        The directive and type definitions, as GraphQL SDL.

    Raises:
        Error: When `version` is not a supported federation version.
    """
    _require_version(version)
    var field = String(
        "directive @join__field(\n"
        "graph: join__Graph\n"
        "requires: join__FieldSet\n"
        "provides: join__FieldSet\n"
        "type: String\n"
        "external: Boolean\n"
        "override: String\n"
        "usedOverridden: Boolean\n"
    )
    if version.at_least(207):
        field += "overrideLabel: String\n"
    if version.at_least(208):
        field += "contextArguments: [join__ContextArgument!]\n"
    field += ") repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n"
    var context = String("")
    var field_value = String("")
    if version.at_least(208):
        context = String(
            "input join__ContextArgument {\n"
            "name: String!\n"
            "type: String!\n"
            "context: String!\n"
            "selection: join__FieldValue!\n"
            "}\n"
        )
        field_value = String("scalar join__FieldValue\n")
    return (
        "directive @join__enumValue(graph: join__Graph!) repeatable on"
        " ENUM_VALUE\n"
        "directive @join__graph(name: String!, url: String!) on ENUM_VALUE\n"
        + field
        + context
        + "directive @join__implements(\n"
        "graph: join__Graph!\n"
        "interface: String!\n"
        ") repeatable on OBJECT | INTERFACE\n"
        "directive @join__type(\n"
        "graph: join__Graph!\n"
        "key: join__FieldSet\n"
        "extension: Boolean! = false\n"
        "resolvable: Boolean! = true\n"
        "isInterfaceObject: Boolean! = false\n"
        ") repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT |"
        " SCALAR\n"
        "directive @join__unionMember(\n"
        "graph: join__Graph!\n"
        "member: String!\n"
        ") repeatable on UNION\n"
        "scalar join__FieldSet\n"
        + field_value
    )


def join_printed(version: FederationVersion) raises -> String:
    """Return the `@join__` definitions as Hive prints them.

    Args:
        version: The federation version of the supergraph.

    Returns:
        The definitions with Hive's indentation and blank lines.

    Raises:
        Error: When `version` is not a supported federation version.
    """
    _require_version(version)
    var field = String(
        "directive @join__field(\n"
        "  graph: join__Graph\n"
        "  requires: join__FieldSet\n"
        "  provides: join__FieldSet\n"
        "  type: String\n"
        "  external: Boolean\n"
        "  override: String\n"
        "  usedOverridden: Boolean\n"
    )
    if version.at_least(207):
        field += "  overrideLabel: String\n"
    if version.at_least(208):
        field += "  contextArguments: [join__ContextArgument!]\n"
    field += ") repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\n"
    var context = String("")
    var field_value = String("")
    if version.at_least(208):
        context = String(
            "input join__ContextArgument {\n"
            "  name: String!\n"
            "  type: String!\n"
            "  context: String!\n"
            "  selection: join__FieldValue!\n"
            "}\n\n"
        )
        field_value = String("\n\nscalar join__FieldValue")
    return (
        "directive @join__enumValue(graph: join__Graph!) repeatable on"
        " ENUM_VALUE\n\n"
        "directive @join__graph(name: String!, url: String!) on ENUM_VALUE\n\n"
        + field
        + context
        + "directive @join__implements(graph: join__Graph!, interface: String!)"
        " repeatable on OBJECT | INTERFACE\n\n"
        "directive @join__type(\n"
        "  graph: join__Graph!\n"
        "  key: join__FieldSet\n"
        "  extension: Boolean! = false\n"
        "  resolvable: Boolean! = true\n"
        "  isInterfaceObject: Boolean! = false\n"
        ") repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT |"
        " SCALAR\n\n"
        "directive @join__unionMember(graph: join__Graph!, member: String!)"
        " repeatable on UNION\n\n"
        "scalar join__FieldSet"
        + field_value
    )


def _require_version(version: FederationVersion) raises:
    """Raise when a federation version is not supported.

    Args:
        version: The version to check.

    Raises:
        Error: When the version is outside the supported table.
    """
    if not version.is_valid():
        raise Error("Unsupported federation version")
