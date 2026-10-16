# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The MCP `Tool` definition, its annotations, and the mutation mode.

Port of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/operations/mutation_mode.rs` and
`operations/annotation_overrides.rs`. The JSON form of `Tool` and
`ToolAnnotations` is the one of the MCP specification (2025-06-18,
`Tool` and `ToolAnnotations`): the members are in the order that the
upstream server sends, and an absent value has no member.

Differences from upstream: a tool has no `icons` and no `_meta` in
phase 1, because apps are not ported.
"""

from gql_json.writer import JsonWriter
from gql_mcp.json_tree import JsonTree


struct MutationMode(Equatable, ImplicitlyCopyable):
    """Which mutations the server exposes, as upstream `MutationMode`."""

    var value: UInt8
    """The mode's number."""

    comptime NONE = MutationMode(0)
    """No mutation: operations and `execute` refuse them."""
    comptime EXPLICIT = MutationMode(1)
    """Only the mutations of the configured operations."""
    comptime ALL = MutationMode(2)
    """Every mutation, ad hoc ones of `execute` too."""

    def __init__(out self, value: UInt8):
        """Make a mode from its number.

        Args:
            value: The number.
        """
        self.value = value

    def is_valid(self) -> Bool:
        """Return whether the mode is one of the three modes.

        Returns:
            True for `NONE`, `EXPLICIT` and `ALL`.
        """
        return self.value <= 2


@fieldwise_init
struct ToolAnnotations(Copyable, Movable):
    """The hints of a tool. An empty `Optional` has no JSON member."""

    var title: Optional[String]
    """A title for people."""
    var read_only_hint: Optional[Bool]
    """Whether the tool changes nothing."""
    var destructive_hint: Optional[Bool]
    """Whether the tool can destroy data."""
    var idempotent_hint: Optional[Bool]
    """Whether a second call with the same arguments does nothing more."""
    var open_world_hint: Optional[Bool]
    """Whether the tool talks to the world outside the server."""

    def write(self, mut writer: JsonWriter):
        """Write the JSON object of the annotations.

        Args:
            writer: The writer.
        """
        writer.begin_object()
        if self.title:
            writer.key("title")
            writer.string(self.title.value())
        _hint(writer, "readOnlyHint", self.read_only_hint)
        _hint(writer, "destructiveHint", self.destructive_hint)
        _hint(writer, "idempotentHint", self.idempotent_hint)
        _hint(writer, "openWorldHint", self.open_world_hint)
        writer.end_object()


def _hint(mut writer: JsonWriter, name: StaticString, value: Optional[Bool]):
    """Write one hint when it has a value."""
    if value:
        writer.key(name)
        writer.bool(value.value())


@fieldwise_init
struct AnnotationOverrides(Copyable, Movable):
    """Configured annotations of one operation, as upstream
    `AnnotationOverrides`."""

    var title: Optional[String]
    """The title to set."""
    var read_only_hint: Optional[Bool]
    """The read-only hint to set."""
    var destructive_hint: Optional[Bool]
    """The destructive hint to set."""
    var idempotent_hint: Optional[Bool]
    """The idempotent hint to set."""
    var open_world_hint: Optional[Bool]
    """The open-world hint to set."""

    def apply_to(self, mut base: ToolAnnotations):
        """Replace each annotation that the override sets.

        Args:
            base: The annotations to change.
        """
        if self.title:
            base.title = self.title.copy()
        if self.read_only_hint:
            base.read_only_hint = self.read_only_hint
        if self.destructive_hint:
            base.destructive_hint = self.destructive_hint
        if self.idempotent_hint:
            base.idempotent_hint = self.idempotent_hint
        if self.open_world_hint:
            base.open_world_hint = self.open_world_hint


struct Tool(Copyable, Movable):
    """One MCP tool: its name, description, schemas and annotations."""

    var name: String
    """The name that `tools/call` uses."""
    var description: Optional[String]
    """The description for the model."""
    var input_schema: JsonTree
    """The JSON Schema of the arguments; its `root` is an object."""
    var output_schema: Optional[JsonTree]
    """The JSON Schema of the structured result, when there is one."""
    var annotations: Optional[ToolAnnotations]
    """The hints, when there are some."""

    def __init__(
        out self,
        var name: String,
        var description: Optional[String],
        var input_schema: JsonTree,
    ):
        """Make a tool without an output schema and without annotations.

        Args:
            name: The name.
            description: The description.
            input_schema: The JSON Schema of the arguments.
        """
        self.name = name^
        self.description = description^
        self.input_schema = input_schema^
        self.output_schema = None
        self.annotations = None

    def write(self, mut writer: JsonWriter):
        """Write the JSON object of the tool, as `tools/list` sends it.

        Args:
            writer: The writer.
        """
        writer.begin_object()
        writer.key("name")
        writer.string(self.name)
        if self.description:
            writer.key("description")
            writer.string(self.description.value())
        writer.key("inputSchema")
        self.input_schema.write(writer, self.input_schema.root)
        if self.output_schema:
            ref schema = self.output_schema.value()
            writer.key("outputSchema")
            schema.write(writer, schema.root)
        if self.annotations:
            writer.key("annotations")
            self.annotations.value().write(writer)
        writer.end_object()

    def to_json(self, indent: Int = 0) -> String:
        """Return the JSON text of the tool.

        Args:
            indent: The spaces for each level.

        Returns:
            The text.
        """
        var writer = JsonWriter(indent)
        self.write(writer)
        return writer^.take_string()
