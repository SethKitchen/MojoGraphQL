# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Print the model of a subgraph.

`@apollo/subgraph` 2.14.4 prints `_service.sdl` with `printSchema` of
`@apollo/federation-internals`, and `printSubgraphSchema` with the
`toString` of a subgraph there. Both are Elastic licensed and are not
read. This module implements the format that they give, observed as a
black box:

- The schema definition prints when it has a description or directives,
  or when a root type has a name other than `Query`, `Mutation` and
  `Subscription`. Then the schema extensions, the directive definitions,
  and the types.
- A type prints its definition and each extension apart, in source order.
  The directives of a type and of the schema print one per line.
- `printSubgraphSchema` leaves out what federation adds: the federation
  and link definitions, the `_entities` and `_service` fields, and the
  `@link` to the link specification. A type definition with nothing left
  to print is left out, unless the type has extensions.

`PrintMode.MERGED` prints each type as one definition, with the parts
joined, for `gql_schema` to build the executable schema.

**Differences from upstream.** None known.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_subgraph.link import string_argument
from gql_subgraph.model import GENERATED, Part, Ref, SubgraphModel
from gql_subgraph.sdl_printer import (
    print_description,
    print_directive,
    print_directive_definition,
    print_item,
)
from gql_subgraph.spec import LINK_URL


@fieldwise_init
struct PrintMode(Equatable, ImplicitlyCopyable, Writable):
    """What a print of a model is for."""

    var value: UInt8
    """The mode's index; see `is_valid`."""

    comptime SDL = PrintMode(0)
    """The `_service.sdl` text: everything."""
    comptime SUBGRAPH = PrintMode(1)
    """`printSubgraphSchema`: without what federation adds."""
    comptime MERGED = PrintMode(2)
    """One definition per type, to build the executable schema."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the three modes.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the mode's name.

        Args:
            writer: The destination.
        """
        if self == PrintMode.SDL:
            writer.write("SDL")
        elif self == PrintMode.SUBGRAPH:
            writer.write("SUBGRAPH")
        elif self == PrintMode.MERGED:
            writer.write("MERGED")
        else:
            writer.write("<invalid>")


def _keyword(kind: Kind) -> StaticString:
    """Return the keyword of a type definition kind."""
    if kind == Kind.SCALAR_TYPE_DEFINITION:
        return "scalar"
    if kind == Kind.INTERFACE_TYPE_DEFINITION:
        return "interface"
    if kind == Kind.UNION_TYPE_DEFINITION:
        return "union"
    if kind == Kind.ENUM_TYPE_DEFINITION:
        return "enum"
    if kind == Kind.INPUT_OBJECT_TYPE_DEFINITION:
        return "input"
    return "type"


def _item_role(kind: Kind) -> Role:
    """Return the role of the items of a type definition kind."""
    if kind == Kind.UNION_TYPE_DEFINITION:
        return Role.MEMBER_TYPE
    if kind == Kind.ENUM_TYPE_DEFINITION:
        return Role.ENUM_VALUE
    return Role.FIELD


def _is_link_spec(doc: Document, directive: Int) -> Bool:
    """Return True for a `@link` to the link specification."""
    return (
        String(doc.name(directive)) == "link"
        and string_argument(doc, directive, "url") == LINK_URL
    )


def _part_directives(
    model: SubgraphModel, part: Part, mode: PrintMode, mut out: List[String]
):
    """Append the directives of a part that the mode prints."""
    var index = 0
    while index < len(part.prefix) and mode != PrintMode.SUBGRAPH:
        ref at = part.prefix[index]
        out.append(print_directive(model.docs[at.doc], at.node))
        index += 1
    if part.node == NO_NODE:
        return
    ref doc = model.docs[part.doc]
    var directive = doc.child(part.node, Role.DIRECTIVE)
    while directive != NO_NODE:
        if mode != PrintMode.SUBGRAPH or not _is_link_spec(doc, directive):
            out.append(print_directive(doc, directive))
        directive = doc.next_with_role(directive)


def _part_items(
    model: SubgraphModel,
    part: Part,
    role: Role,
    mode: PrintMode,
    mut out: List[Ref],
):
    """Append the fields, values or members of a part that the mode
    prints."""
    if part.node != NO_NODE:
        ref doc = model.docs[part.doc]
        var item = doc.child(part.node, role)
        while item != NO_NODE:
            out.append(Ref(part.doc, item))
            item = doc.next_with_role(item)
    if mode != PrintMode.SUBGRAPH:
        out.extend(part.added.copy())


def _part_interfaces(model: SubgraphModel, part: Part, mut out: List[String]):
    """Append the interfaces of a part."""
    if part.node == NO_NODE:
        return
    ref doc = model.docs[part.doc]
    var item = doc.child(part.node, Role.INTERFACE)
    while item != NO_NODE:
        out.append(String(doc.name(item)))
        item = doc.next_with_role(item)


def _block(
    model: SubgraphModel,
    var header: String,
    interfaces: List[String],
    directives: List[String],
    items: List[Ref],
    kind: Kind,
    escaped: Bool,
) -> String:
    """Print a type definition or extension from its pieces."""
    var index = 0
    while index < len(interfaces):
        header += (" & " if index > 0 else " implements ") + interfaces[index]
        index += 1
    index = 0
    while index < len(directives):
        header += "\n  " + directives[index]
        index += 1
    if len(items) == 0:
        return header^
    var nested = len(directives) > 0
    if kind == Kind.UNION_TYPE_DEFINITION:
        header += "\n =" if nested else " ="
        index = 0
        while index < len(items):
            ref at = items[index]
            header += (" | " if index > 0 else " ") + String(
                model.docs[at.doc].name(at.node)
            )
            index += 1
        return header^
    header += "\n{\n" if nested else " {\n"
    index = 0
    while index < len(items):
        ref at = items[index]
        if index > 0:
            header += "\n"
        header += print_item(model.docs[at.doc], at.node, index == 0, escaped)
        index += 1
    return header + "\n}"


def _header(
    model: SubgraphModel, part: Part, kind: Kind, name: String, escaped: Bool
) -> String:
    """Print the description, `extend`, the keyword and the name."""
    var out = String("")
    if part.node != NO_NODE:
        out = print_description(
            model.docs[part.doc], part.node, "", True, escaped
        )
    if part.is_extension:
        out += "extend "
    return out + _keyword(kind) + " " + name


def _print_type(
    model: SubgraphModel, type: Int, mode: PrintMode, mut blocks: List[String]
):
    """Append the definition and the extensions of a type."""
    ref entry = model.types[type]
    var role = _item_role(entry.kind)
    if mode == PrintMode.MERGED:
        var interfaces = List[String]()
        var directives = List[String]()
        var items = List[Ref]()
        var description = String("")
        var index = 0
        while index < len(entry.parts):
            ref part = entry.parts[index]
            if not part.is_extension:
                description = _header(model, part, entry.kind, entry.name, True)
            _part_interfaces(model, part, interfaces)
            _part_directives(model, part, mode, directives)
            _part_items(model, part, role, mode, items)
            index += 1
        if description == "":
            description = String(_keyword(entry.kind)) + " " + entry.name
        blocks.append(
            _block(
                model,
                description^,
                interfaces,
                directives,
                items,
                entry.kind,
                True,
            )
        )
        return
    var extended = entry.has_definition() and len(entry.parts) > 1
    var index = 0
    while index < len(entry.parts):
        ref part = entry.parts[index]
        var interfaces = List[String]()
        var directives = List[String]()
        var items = List[Ref]()
        _part_interfaces(model, part, interfaces)
        _part_directives(model, part, mode, directives)
        _part_items(model, part, role, mode, items)
        var empty = (
            len(directives) == 0
            and len(items) == 0
            and (
                part.node == NO_NODE
                or not model.docs[part.doc].has_description(part.node)
            )
        )
        if (
            mode == PrintMode.SDL
            or not empty
            or extended
            or entry.kind == Kind.SCALAR_TYPE_DEFINITION
        ):
            blocks.append(
                _block(
                    model,
                    _header(model, part, entry.kind, entry.name, False),
                    interfaces,
                    directives,
                    items,
                    entry.kind,
                    False,
                )
            )
        index += 1


comptime _ROOT_NAMES: Array[StaticString, 3] = [
    "Query",
    "Mutation",
    "Subscription",
]
comptime _OPERATIONS: Array[StaticString, 3] = [
    "query",
    "mutation",
    "subscription",
]


def _schema_operations(model: SubgraphModel, part: Part) -> List[String]:
    """Return the `query: X` lines of a schema part."""
    var out = List[String]()
    if part.node != NO_NODE:
        ref doc = model.docs[part.doc]
        var operation = doc.child(part.node, Role.OPERATION_TYPE)
        while operation != NO_NODE:
            out.append(
                "  "
                + String(doc.operation(operation))
                + ": "
                + String(doc.named_type(doc.child(operation, Role.TYPE)))
            )
            operation = doc.next_with_role(operation)
        return out^
    var index = 0
    while index < 3:
        if model.roots[index] != "" and not model.declared[index]:
            out.append(
                "  "
                + String(materialize[_OPERATIONS]()[index])
                + ": "
                + model.roots[index]
            )
        index += 1
    return out^


def _print_schema(
    model: SubgraphModel, mode: PrintMode, mut blocks: List[String]
):
    """Append the schema definition, when it prints, and the extensions."""
    var custom = False
    var index = 0
    while index < 3:
        var root = model.roots[index]
        custom = custom or (
            root != "" and root != String(materialize[_ROOT_NAMES]()[index])
        )
        index += 1
    # A root type that an extension names makes the definition print too.
    index = 1
    while index < len(model.schema_parts):
        ref part = model.schema_parts[index]
        var operation = model.docs[part.doc].child(
            part.node, Role.OPERATION_TYPE
        )
        custom = custom or operation != NO_NODE
        index += 1
    index = 0
    while index < len(model.schema_parts):
        ref part = model.schema_parts[index]
        var directives = List[String]()
        _part_directives(model, part, mode, directives)
        var operations = _schema_operations(model, part)
        var out = String("")
        if part.node != NO_NODE:
            out = print_description(model.docs[part.doc], part.node, "", True)
        var printed = len(directives) > 0 or out != ""
        if part.is_extension:
            out += "extend "
            printed = printed or len(operations) > 0
        else:
            printed = printed or custom
        out += "schema"
        var at = 0
        while at < len(directives):
            out += "\n  " + directives[at]
            at += 1
        if len(operations) > 0:
            out += "\n{\n" if len(directives) > 0 else " {\n"
            at = 0
            while at < len(operations):
                out += operations[at] + "\n"
                at += 1
            out += "}"
        if printed:
            blocks.append(out^)
        index += 1


def _merged_order(model: SubgraphModel) -> List[Int]:
    """Return the types with a definition, then those with none."""
    var first = List[Int]()
    var last = List[Int]()
    var index = 0
    while index < len(model.types):
        if model.types[index].has_definition():
            first.append(index)
        else:
            last.append(index)
        index += 1
    first.extend(last^)
    return first^


def print_model(
    model: SubgraphModel, mode: PrintMode, order: List[Int]
) -> String:
    """Print a model.

    Args:
        model: The model.
        mode: What to print; see `PrintMode`.
        order: The indices of the types in the order to print them. The
            `MERGED` mode ignores it and prints each type with a definition
            first.

    Returns:
        The SDL, with no line break at the end.
    """
    var blocks = List[String]()
    if mode == PrintMode.MERGED:
        var out = String("schema {\n")
        var index = 0
        while index < 3:
            if model.roots[index] != "":
                out += String(materialize[_OPERATIONS]()[index]) + ": "
                out += model.roots[index] + "\n"
            index += 1
        blocks.append(out + "}")
    else:
        _print_schema(model, mode, blocks)
    var index = 0
    while index < len(model.directives):
        ref entry = model.directives[index]
        if mode != PrintMode.SUBGRAPH or not entry.hidden:
            blocks.append(
                print_directive_definition(
                    model.docs[entry.at.doc],
                    entry.at.node,
                    mode == PrintMode.MERGED,
                )
            )
        index += 1
    var types = (
        _merged_order(model) if mode == PrintMode.MERGED else order.copy()
    )
    index = 0
    while index < len(types):
        if mode != PrintMode.SUBGRAPH or not model.types[types[index]].hidden:
            _print_type(model, types[index], mode, blocks)
        index += 1
    var out = String("")
    index = 0
    while index < len(blocks):
        if index > 0:
            out += "\n\n"
        out += blocks[index]
        index += 1
    return out^


def print_model(model: SubgraphModel, mode: PrintMode) -> String:
    """Print a model with its types in model order.

    Args:
        model: The model.
        mode: What to print.

    Returns:
        The SDL, with no line break at the end.
    """
    var order = List[Int](capacity=len(model.types))
    var index = 0
    while index < len(model.types):
        order.append(index)
        index += 1
    return print_model(model, mode, order)
