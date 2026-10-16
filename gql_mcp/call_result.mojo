# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The result of a `tools/call` request.

The JSON form is the MCP `CallToolResult` (specification 2025-06-18):
`content`, then `structuredContent` when there is one, then `isError`.
Apollo MCP Server 2.0.0 sends only text content. This is the form that it
sends to a client of protocol version 2025-11-25 or earlier; such a result
has no `resultType` member.

This module ports no code: the result type belongs to the SDK (`rmcp`),
which is Apache-2.0 only. The shapes come from the MCP specification and
from the upstream binary.

Differences from upstream: no `_meta`, because `@private` fields are not
ported in phase 1.
"""

from gql_json.writer import JsonWriter


struct CallToolResult(Copyable, Movable):
    """The content of a tool result, and whether it is an error."""

    var content: List[String]
    """The text blocks."""
    var structured_content: Optional[String]
    """The JSON text of the structured result, when there is one."""
    var is_error: Bool
    """Whether the tool failed."""

    def __init__(
        out self,
        var content: List[String],
        var structured_content: Optional[String],
        is_error: Bool,
    ):
        """Make a result.

        Args:
            content: The text blocks.
            structured_content: The JSON text of the structured result.
            is_error: Whether the tool failed.
        """
        self.content = content^
        self.structured_content = structured_content^
        self.is_error = is_error

    @staticmethod
    def success(var content: List[String]) -> CallToolResult:
        """Make a successful result of text blocks, as `rmcp` `success`.

        Args:
            content: The text blocks.

        Returns:
            The result.
        """
        return CallToolResult(content^, None, False)

    @staticmethod
    def error(text: StringSlice) -> CallToolResult:
        """Make a failed result of one text block, as `rmcp` `error`.

        Args:
            text: The text.

        Returns:
            The result.
        """
        var content = List[String]()
        content.append(String(text))
        return CallToolResult(content^, None, True)

    @staticmethod
    def structured(json: String, is_error: Bool) -> CallToolResult:
        """Make a result with structured content, and the same JSON as its
        one text block, as `rmcp` `structured` and `structured_error`.

        Args:
            json: The compact JSON text of the value.
            is_error: Whether the tool failed.

        Returns:
            The result.
        """
        var content = List[String]()
        content.append(json)
        return CallToolResult(content^, json, is_error)

    def write(self, mut writer: JsonWriter, with_structured: Bool = True):
        """Write the JSON object of the result.

        Args:
            writer: The writer.
            with_structured: Whether to write `structuredContent`; the
                server leaves it out for a client that cannot read it.
        """
        writer.begin_object()
        writer.key("content")
        writer.begin_array()
        for text in self.content:
            writer.begin_object()
            writer.key("type")
            writer.string("text")
            writer.key("text")
            writer.string(text)
            writer.end_object()
        writer.end_array()
        if with_structured and self.structured_content:
            writer.key("structuredContent")
            writer.raw(self.structured_content.value())
        writer.key("isError")
        writer.bool(self.is_error)
        writer.end_object()

    def to_json(self, with_structured: Bool = True) -> String:
        """Return the JSON text of the result.

        Args:
            with_structured: Whether to write `structuredContent`.

        Returns:
            The text.
        """
        var writer = JsonWriter()
        self.write(writer, with_structured)
        return writer^.take_string()
