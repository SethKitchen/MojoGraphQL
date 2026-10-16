# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The definitions of the built-in tools: `introspect`, `search`,
`execute` and `validate`.

Port of the tool definitions of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/introspection/tools/introspect.rs`,
`search.rs`, `execute.rs`, `validate.rs`, `description.rs` and
`introspection/tools.rs` (`schema_lookup_annotations`). The names, the
descriptions and the annotations are the upstream ones. The input schemas
are the JSON that `schemars` generates for each `Input` struct, as the
upstream binary sends it.

Differences from upstream: none known.
"""

from gql_json.parser import parse
from gql_mcp.json_tree import JsonTree
from gql_mcp.tool import MutationMode, Tool, ToolAnnotations

comptime INTROSPECT_TOOL_NAME = "introspect"
"""The name of the tool that returns type definitions."""
comptime SEARCH_TOOL_NAME = "search"
"""The name of the tool that searches the schema."""
comptime EXECUTE_TOOL_NAME = "execute"
"""The name of the tool that runs an ad hoc operation."""
comptime VALIDATE_TOOL_NAME = "validate"
"""The name of the tool that validates an operation."""

comptime MINIFY_LEGEND = "T=type,I=input,E=enum,U=union,F=interface;s=String,i=Int,f=Float,b=Boolean,d=ID;@D=deprecated;!=required,[]=list,<>=implements"
"""The legend of the minified type notation."""

comptime _SCHEMA_PREFIX = (
    '{"$schema":"http://json-schema.org/draft-07/schema#","title":"Input","description":"Input'
    " for the "
)

comptime _INTROSPECT_INPUT = _SCHEMA_PREFIX + 'introspect tool.","type":"object","properties":{"type_name":{"description":"The name of the type to get information about.","type":"string"},"depth":{"description":"How far to recurse the type hierarchy. Use 0 for no limit. Defaults to 1.","type":"integer","format":"uint","minimum":0,"default":1}},"required":["type_name"]}'
"""The input schema of `introspect`."""
comptime _SEARCH_INPUT = _SCHEMA_PREFIX + 'search tool.","type":"object","properties":{"terms":{"description":"The search terms","type":"array","items":{"type":"string"}}},"required":["terms"]}'
"""The input schema of `search`."""
comptime _EXECUTE_INPUT = _SCHEMA_PREFIX + 'execute tool.","type":"object","properties":{"query":{"description":"The GraphQL operation","type":"string"},"variables":{"description":"The variable values represented as JSON","type":"string","default":null}},"required":["query"]}'
"""The input schema of `execute`."""
comptime _VALIDATE_INPUT = _SCHEMA_PREFIX + 'validate tool","type":"object","properties":{"operation":{"description":"The GraphQL operation","type":"string"}},"required":["operation"]}'
"""The input schema of `validate`."""


def append_description_hint(
    default: StringSlice, hint: Optional[String]
) -> String:
    """Append a configured hint to a tool description, as upstream
    `append_description_hint`.

    Args:
        default: The description.
        hint: The hint; a blank hint adds nothing.

    Returns:
        The description, then `\\nHint: ` and the trimmed hint.
    """
    if hint:
        var trimmed = hint.value().strip()
        if trimmed.byte_length() > 0:
            return String(default) + "\nHint: " + String(trimmed)
    return String(default)


def _schema(text: StringSlice) raises -> JsonTree:
    """Make a tree from the JSON text of an input schema."""
    var tree = JsonTree()
    var document = parse(text)
    tree.root = tree.add_document(document, document.root)
    return tree^


def schema_lookup_annotations() -> ToolAnnotations:
    """Return the annotations of the tools that only read the schema.

    Returns:
        Read-only, not destructive, idempotent, and closed-world.
    """
    return ToolAnnotations(None, True, False, True, False)


def introspect_tool(
    root_query_type: Optional[String],
    root_mutation_type: Optional[String],
    minify: Bool,
    hint: Optional[String],
) raises -> Tool:
    """Return the `introspect` tool.

    Args:
        root_query_type: The query root type's name, for the description.
        root_mutation_type: The mutation root type's name, when the server
            exposes mutations.
        minify: Whether results use the minified notation.
        hint: The configured description hint.

    Returns:
        The tool.

    Raises:
        Error: Never; the input schema is a constant.
    """
    var description: String
    if minify:
        description = "Get GraphQL type information - " + MINIFY_LEGEND + ";"
    else:
        description = (
            "Get information about a given GraphQL type defined in the"
            " schema. Instructions: Use this tool to explore the schema by"
            " providing specific type names. Start with the root query ("
            + root_query_type.or_else(String("Query"))
            + ") or mutation ("
            + root_mutation_type.or_else(String("Mutation"))
            + ") types to discover available fields. If the search tool is"
            " also available, use this tool first to get the fields, then use"
            " the search tool with relevant field return types and argument"
            " input types (ignore default GraphQL scalars) as search terms."
        )
    var tool = Tool(
        INTROSPECT_TOOL_NAME,
        append_description_hint(description, hint),
        _schema(_INTROSPECT_INPUT),
    )
    tool.annotations = schema_lookup_annotations()
    return tool^


def search_tool(minify: Bool, hint: Optional[String]) raises -> Tool:
    """Return the `search` tool.

    Args:
        minify: Whether results use the minified notation.
        hint: The configured description hint.

    Returns:
        The tool.

    Raises:
        Error: Never; the input schema is a constant.
    """
    var description = String(
        "Search a GraphQL schema for types matching the provided search"
        " terms. Returns complete type definitions including all related"
        " types needed to construct GraphQL operations. Instructions: If the"
        " introspect tool is also available, you can discover type names by"
        " using the introspect tool starting from the root Query or Mutation"
        " types. Avoid reusing previously searched terms for more efficient"
        " exploration."
    )
    if minify:
        description += " - " + MINIFY_LEGEND
    var tool = Tool(
        SEARCH_TOOL_NAME,
        append_description_hint(description, hint),
        _schema(_SEARCH_INPUT),
    )
    tool.annotations = schema_lookup_annotations()
    return tool^


def execute_tool(
    mutation_mode: MutationMode, hint: Optional[String]
) raises -> Tool:
    """Return the `execute` tool.

    Args:
        mutation_mode: The mutation mode; only `ALL` permits ad hoc
            mutations, and that changes the annotations.
        hint: The configured description hint.

    Returns:
        The tool.

    Raises:
        Error: Never; the input schema is a constant.
    """
    var permits_mutation = mutation_mode == MutationMode.ALL
    var tool = Tool(
        EXECUTE_TOOL_NAME,
        append_description_hint(
            (
                "Execute a GraphQL operation. Use the `introspect` tool to get"
                " information about the GraphQL schema. Always use the schema"
                " to create operations - do not try arbitrary operations. If"
                " available, first use the `validate` tool to validate"
                " operations. DO NOT try to execute introspection queries."
            ),
            hint,
        ),
        _schema(_EXECUTE_INPUT),
    )
    tool.annotations = ToolAnnotations(
        None, not permits_mutation, permits_mutation, not permits_mutation, True
    )
    return tool^


def validate_tool(hint: Optional[String]) raises -> Tool:
    """Return the `validate` tool.

    Args:
        hint: The configured description hint.

    Returns:
        The tool.

    Raises:
        Error: Never; the input schema is a constant.
    """
    var tool = Tool(
        VALIDATE_TOOL_NAME,
        append_description_hint(
            (
                "Validates a GraphQL operation against the schema. Use the"
                " `introspect` tool first to get information about the GraphQL"
                " schema. Operations should be validated prior to calling the"
                " `execute` tool."
            ),
            hint,
        ),
        _schema(_VALIDATE_INPUT),
    )
    tool.annotations = schema_lookup_annotations()
    return tool^
