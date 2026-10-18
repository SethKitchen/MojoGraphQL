# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The join directives of a supergraph.

Port of Hive Router `1a29df9`
`bin/router/src/query_planner/federation_spec/`: `join_type.rs`,
`join_field.rs`, `join_graph.rs`, `join_implements.rs`, `join_union.rs`,
`join_enum_value.rs`, and the `TypeNode` of
`state/supergraph_state.rs`.

Names are symbols of the planner `Store`. A directive is read from a
`gql_language` document. An argument of the wrong value kind is ignored,
as upstream.

**Differences from upstream.** Upstream panics on a bad `percent(...)`
override label. This port raises `Error` with the same message.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_router.ast import NONE
from gql_router.store import Store

comptime PERCENTAGE_SCALE_FACTOR: UInt64 = 100000000
"""A percentage is stored times this factor, which keeps 8 fraction
digits: upstream `PERCENTAGE_SCALE_FACTOR`."""


@fieldwise_init
struct OperationKind(Equatable, ImplicitlyCopyable, Movable, Writable):
    """The kind of an operation, as upstream `OperationKind`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime QUERY = OperationKind(0)
    """A query."""
    comptime MUTATION = OperationKind(1)
    """A mutation."""
    comptime SUBSCRIPTION = OperationKind(2)
    """A subscription."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the three kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def as_str(self) -> StaticString:
        """Return the keyword of the kind.

        Returns:
            `query`, `mutation` or `subscription`.
        """
        if self == OperationKind.MUTATION:
            return "mutation"
        if self == OperationKind.SUBSCRIPTION:
            return "subscription"
        return "query"

    def write_to(self, mut writer: Some[Writer]):
        """Write the keyword.

        Args:
            writer: The destination.
        """
        writer.write(self.as_str())


@fieldwise_init
struct TypeNode(Copyable, Equatable, Movable):
    """A type reference, as upstream `TypeNode`.

    `shape` is the reference with `%` in place of the name: `[%!]!` for
    `[Name!]!`.
    """

    var name: Int
    """The named type at the bottom, as a symbol."""
    var shape: String
    """The list and non-null wrappers around `%`."""

    def inner_type(self) -> Int:
        """Return the named type under the wrappers.

        Returns:
            The type name, as a symbol.
        """
        return self.name

    def is_list(self) -> Bool:
        """Return True if the type is a list, under any non-null wrapper.

        Returns:
            Whether the type starts with `[`.
        """
        return self.shape.startswith("[")

    def text(self, store: Store) -> String:
        """Return the type as upstream `Display`, such as `[Name!]!`.

        Args:
            store: The store with the type name.

        Returns:
            The type text.
        """
        # The shape has one `%`, and type names have no `%`.
        return self.shape.replace("%", store.name(self.name))


def type_node_from_ast(
    mut store: Store, document: Document, node: Int
) -> TypeNode:
    """Read a type reference node of a document.

    Args:
        store: The store for the name.
        document: The document.
        node: A `NamedType`, `ListType` or `NonNullType` node.

    Returns:
        The type.
    """
    var prefix = String()
    var suffix = String()
    var current = node
    while document.kind(current) != Kind.NAMED_TYPE:
        if document.kind(current) == Kind.LIST_TYPE:
            prefix += "["
            suffix = "]" + suffix
        else:
            suffix = "!" + suffix
        current = document.first_child(current)
    return TypeNode(store.sym(document.name(current)), prefix + "%" + suffix)


def type_node_from_text(mut store: Store, text: String) raises -> TypeNode:
    """Read a type reference text, as upstream `TypeNode::try_from`.

    Args:
        store: The store for the name.
        text: Such as `[String!]`.

    Returns:
        The type.

    Raises:
        Error: When the text is empty or the brackets do not match.
    """
    if text.byte_length() == 0:
        raise Error("Input string for type parsing cannot be empty.")
    if text.endswith("!"):
        var inner = type_node_from_text(
            store, String(text[byte = : text.byte_length() - 1])
        )
        return TypeNode(inner.name, inner.shape + "!")
    if text.startswith("["):
        if not text.endswith("]"):
            raise Error("Mismatched brackets in list type")
        var inner = type_node_from_text(
            store, String(text[byte = 1 : text.byte_length() - 1])
        )
        return TypeNode(inner.name, "[" + inner.shape + "]")
    if "[" in text or "]" in text or "!" in text:
        raise Error("Invalid named type format")
    return TypeNode(store.sym(text), "%")


@fieldwise_init
struct OverrideLabel(Copyable, Equatable, Movable):
    """An `@override` label, as upstream `OverrideLabel`."""

    var is_percent: Bool
    """Whether the label is `percent(...)`."""
    var percent: UInt64
    """The percentage times `PERCENTAGE_SCALE_FACTOR`."""
    var custom: Int
    """The custom label, as a symbol, or `NONE`."""


def parse_override_label(
    mut store: Store, label: String
) raises -> OverrideLabel:
    """Read an `overrideLabel` value, as upstream `parse_override_label`.

    Args:
        store: The store for a custom label.
        label: Such as `percent(11.12)` or `canary`.

    Returns:
        A percentage, or the custom label.

    Raises:
        Error: When a percentage has more than 8 fraction digits, is not a
            number, or is outside 0 to 100.
    """
    if not (label.startswith("percent(") and label.endswith(")")):
        return OverrideLabel(False, 0, store.sym(label))
    var inner = String(label[byte = 8 : label.byte_length() - 1])
    var dot = inner.find(".")
    if dot >= 0 and inner.byte_length() - dot - 1 > 8:
        raise Error(
            "Invalid precision for percentage override. Must be no more"
            " than 8 fraction digits."
        )
    var value: Float64
    try:
        value = atof(inner)
    except:
        raise Error("Invalid percentage value. Must be between 0 and 100.")
    if not (value >= 0.0 and value <= 100.0):
        raise Error("Invalid percentage value. Must be between 0 and 100.")
    return OverrideLabel(
        True, UInt64(value * Float64(PERCENTAGE_SCALE_FACTOR)), NONE
    )


def directive_arg(document: Document, directive: Int, name: StringSlice) -> Int:
    """Return the value node of one argument of a directive.

    Args:
        document: The document.
        directive: A `Directive` node.
        name: The argument name.

    Returns:
        The value node, or `NO_NODE` when the argument is absent.
    """
    var argument = document.child(directive, Role.ARGUMENT)
    while argument != NO_NODE:
        if document.name(argument) == name:
            return document.child(argument, Role.VALUE)
        argument = document.next_with_role(argument)
    return NO_NODE


def _text_arg(
    document: Document, directive: Int, name: StringSlice, allow_enum: Bool
) -> Optional[String]:
    """Return a string argument, or an enum argument when allowed."""
    var value = directive_arg(document, directive, name)
    if value == NO_NODE:
        return None
    var kind = document.kind(value)
    if kind == Kind.STRING:
        return document.string_value(value)
    if allow_enum and kind == Kind.ENUM:
        return String(document.text(value))
    return None


def _bool_arg(
    document: Document, directive: Int, name: StringSlice, default: Bool
) -> Bool:
    """Return a boolean argument, or a default."""
    var value = directive_arg(document, directive, name)
    if value == NO_NODE or document.kind(value) != Kind.BOOLEAN:
        return default
    return document.boolean_value(value)


@fieldwise_init
struct JoinTypeDirective(Copyable, Movable):
    """One `@join__type`, as upstream `JoinTypeDirective`."""

    var graph_id: Int
    """The `graph` argument, as a symbol."""
    var key: Optional[String]
    """The `key` field set."""
    var extension: Bool
    """The `extension` argument."""
    var resolvable: Bool
    """The `resolvable` argument. True when it is omitted."""
    var is_interface_object: Bool
    """The `isInterfaceObject` argument."""


def parse_join_type(
    mut store: Store, document: Document, directive: Int
) -> JoinTypeDirective:
    """Read one `@join__type`.

    Args:
        store: The store for the graph id.
        document: The document.
        directive: The `Directive` node.

    Returns:
        The directive.
    """
    var graph = _text_arg(document, directive, "graph", True)
    return JoinTypeDirective(
        store.sym(graph.value()) if graph else store.sym(""),
        _text_arg(document, directive, "key", False),
        _bool_arg(document, directive, "extension", False),
        _bool_arg(document, directive, "resolvable", True),
        _bool_arg(document, directive, "isInterfaceObject", False),
    )


@fieldwise_init
struct JoinFieldDirective(Copyable, Movable):
    """One `@join__field`, as upstream `JoinFieldDirective`."""

    var graph_id: Int
    """The `graph` argument, as a symbol, or `NONE`."""
    var requires: Optional[String]
    """The `requires` field set."""
    var provides: Optional[String]
    """The `provides` field set."""
    var type_in_graph: Optional[TypeNode]
    """The `type` argument."""
    var external: Bool
    """The `external` argument."""
    var override_value: Optional[String]
    """The `override` argument: the subgraph the field moved from."""
    var override_label: Optional[OverrideLabel]
    """The `overrideLabel` argument."""
    var used_overridden: Bool
    """The `usedOverridden` argument."""


def parse_join_field(
    mut store: Store, document: Document, directive: Int
) raises -> JoinFieldDirective:
    """Read one `@join__field`.

    Args:
        store: The store for the names.
        document: The document.
        directive: The `Directive` node.

    Returns:
        The directive.

    Raises:
        Error: When `type` is not a type, or `overrideLabel` is a bad
            percentage.
    """
    var graph = _text_arg(document, directive, "graph", True)
    var type_text = _text_arg(document, directive, "type", False)
    var type_in_graph = Optional[TypeNode](None)
    if type_text:
        type_in_graph = type_node_from_text(store, type_text.value())
    var label_text = _text_arg(document, directive, "overrideLabel", False)
    var label = Optional[OverrideLabel](None)
    if label_text:
        label = parse_override_label(store, label_text.value())
    return JoinFieldDirective(
        store.sym(graph.value()) if graph else NONE,
        _text_arg(document, directive, "requires", False),
        _text_arg(document, directive, "provides", False),
        type_in_graph^,
        _bool_arg(document, directive, "external", False),
        _text_arg(document, directive, "override", False),
        label^,
        _bool_arg(document, directive, "usedOverridden", False),
    )


@fieldwise_init
struct JoinImplementsDirective(Copyable, Movable):
    """One `@join__implements`, as upstream `JoinImplementsDirective`."""

    var graph_id: Int
    """The `graph` argument, as a symbol."""
    var interface: Int
    """The `interface` argument, as a symbol."""


def parse_join_implements(
    mut store: Store, document: Document, directive: Int
) -> JoinImplementsDirective:
    """Read one `@join__implements`.

    Args:
        store: The store for the names.
        document: The document.
        directive: The `Directive` node.

    Returns:
        The directive.
    """
    var graph = _text_arg(document, directive, "graph", True)
    var interface = _text_arg(document, directive, "interface", False)
    return JoinImplementsDirective(
        store.sym(graph.value() if graph else String()),
        store.sym(interface.value() if interface else String()),
    )


@fieldwise_init
struct JoinUnionMemberDirective(Copyable, Movable):
    """One `@join__unionMember`, as upstream `JoinUnionMemberDirective`."""

    var graph: Int
    """The `graph` argument, as a symbol."""
    var member: Int
    """The `member` argument, as a symbol."""


def parse_join_union_member(
    mut store: Store, document: Document, directive: Int
) -> JoinUnionMemberDirective:
    """Read one `@join__unionMember`.

    Args:
        store: The store for the names.
        document: The document.
        directive: The `Directive` node.

    Returns:
        The directive.
    """
    var graph = _text_arg(document, directive, "graph", True)
    var member = _text_arg(document, directive, "member", False)
    return JoinUnionMemberDirective(
        store.sym(graph.value() if graph else String()),
        store.sym(member.value() if member else String()),
    )


def parse_join_graph(
    document: Document, directive: Int
) -> Tuple[String, String]:
    """Read one `@join__graph`.

    Args:
        document: The document.
        directive: The `Directive` node.

    Returns:
        The `name` and `url` arguments; empty when absent.
    """
    var name = _text_arg(document, directive, "name", False)
    var url = _text_arg(document, directive, "url", False)
    return (
        name.value() if name else String(),
        url.value() if url else String(),
    )


def parse_join_enum_value(
    mut store: Store, document: Document, directive: Int
) -> Int:
    """Read one `@join__enumValue`.

    Args:
        store: The store for the graph id.
        document: The document.
        directive: The `Directive` node.

    Returns:
        The `graph` argument, as a symbol.
    """
    var graph = _text_arg(document, directive, "graph", True)
    return store.sym(graph.value() if graph else String())
