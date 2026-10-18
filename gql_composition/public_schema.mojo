# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Print the public API schema of a supergraph.

Port of Hive Federation Composition v0.27.0
`src/graphql/transform-supergraph-to-public-schema.ts`. The schema
definition, join and link definitions, and imported federation directives
are removed. An element marked `@inaccessible` is removed. An inaccessible
interface is removed from `implements`.
"""

from gql_composition.link import parse_link_directive
from gql_language.ast import (
    NO_NODE,
    Document,
    FLAG_BLOCK,
    FLAG_REPEATABLE,
    FLAG_TRUE,
    Kind,
    Role,
)
from gql_language.parser import parse
from gql_language.printer import print_ast
from std.collections import Dict


def public_schema(sdl: String) raises -> String:
    """Return the public schema of a supergraph, as upstream
    `publicSdl`.

    Args:
        sdl: The supergraph SDL.

    Returns:
        The schema a client can query. Federation machinery is omitted.

    Raises:
        GraphQLError: The SDL does not parse.
        Error: A `@link` import is invalid.
    """
    var document = parse(sdl)
    var spec = _prepare(document)
    _collect_interfaces(document, spec)
    var out = Document()
    var child = document.first_child(document.root)
    while child != NO_NODE:
        var copied = _copy_kept(out, document, child, Role.DEFINITION, spec)
        if copied != NO_NODE:
            out.append_child(out.root, copied)
        child = document.next_sibling(child)
    return print_ast(out)


struct _Strip:
    """The names `transformSupergraphToPublicSchema` removes."""

    var directives: Dict[String, Bool]
    """Directive names to remove, without `@`."""
    var definitions: Dict[String, Bool]
    """Imported type names to remove from scalars, enums, and inputs."""
    var prefixes: List[String]
    """Name prefixes of linked Apollo specifications, such as `join__`."""
    var extra: String
    """The `@link` `as` names, separated by spaces."""
    var inaccessible: String
    """The local name of `@inaccessible`."""
    var interfaces: Dict[String, Bool]
    """Interface names marked `@inaccessible`."""

    def __init__(out self):
        """Start with the built-in supergraph directive names."""
        self.directives = Dict[String, Bool]()
        self.definitions = Dict[String, Bool]()
        self.prefixes = List[String]()
        self.extra = String("")
        self.inaccessible = String("inaccessible")
        self.interfaces = Dict[String, Bool]()
        var names = List[String]()
        names.append("join__enumValue")
        names.append("join__graph")
        names.append("join__field")
        names.append("join__implements")
        names.append("join__type")
        names.append("join__unionMember")
        names.append("link")
        names.append("tag")
        names.append("inaccessible")
        names.append("cost")
        names.append("cacheTag")
        names.append("listSize")
        names.append("policy")
        names.append("requiresScopes")
        names.append("authenticated")
        names.append("context")
        names.append("context__fromContext")
        names.append("core")
        names.append("join__owner")
        names.append("join__directive")
        var index = 0
        while index < len(names):
            self.directives[names[index]] = True
            index += 1
        self.definitions["_FieldSet"] = True
        self.definitions["join__DirectiveArguments"] = True


def _prepare(document: Document) raises -> _Strip:
    """Read schema `@link` directives into a strip set.

    Args:
        document: The parsed supergraph.

    Returns:
        The names to remove.

    Raises:
        Error: A `@link` import is invalid.
    """
    var spec = _Strip()
    var child = document.first_child(document.root)
    while child != NO_NODE:
        if document.kind(child) == Kind.SCHEMA_DEFINITION:
            _read_schema(document, child, spec)
        child = document.next_sibling(child)
    return spec^


def _read_schema(document: Document, schema: Int, mut spec: _Strip) raises:
    """Record one schema definition's links.

    Args:
        document: The parsed supergraph.
        schema: The schema definition.
        spec: The strip set to fill.

    Raises:
        Error: A `@link` import is invalid.
    """
    var child = document.first_child(schema)
    while child != NO_NODE:
        if (
            document.kind(child) == Kind.DIRECTIVE
            and document.name(child) == "link"
        ):
            _read_link(document, child, spec)
        child = document.next_sibling(child)


def _read_link(document: Document, directive: Int, mut spec: _Strip) raises:
    """Record one `@link` on the schema.

    Args:
        document: The parsed supergraph.
        directive: The `@link` directive.
        spec: The strip set to fill.

    Raises:
        Error: The import list is invalid.
    """
    var renamed = _argument_string(document, directive, "as")
    if renamed.byte_length() > 0:
        spec.extra += " " + renamed + " "
    var url = _argument_string(document, directive, "url")
    if url.startswith("https://specs.apollo.dev/inaccessible"):
        if renamed.byte_length() > 0:
            spec.inaccessible = renamed
    var parsed = parse_link_directive(document, directive)
    if not parsed:
        return
    var link = parsed.value().copy()
    if link.identity.find("//specs.apollo.dev/") == -1:
        return
    spec.prefixes.append(_last_segment(link.identity) + "__")
    for index in range(len(link.imports)):
        var piece = String(link.imports[index].name)
        if link.imports[index].alias:
            piece = String(link.imports[index].alias.value())
        var bare = String(piece)
        if piece.startswith("@"):
            bare = String(piece[byte=1:])
            spec.directives[bare] = True
        spec.definitions[bare] = True


def _argument_string(
    document: Document, directive: Int, name: String
) -> String:
    """Return a string argument of a directive, or empty.

    Args:
        document: The parsed supergraph.
        directive: The directive.
        name: The argument name.

    Returns:
        The string value, or empty when the argument is absent.
    """
    var argument = document.first_child(directive)
    while argument != NO_NODE:
        if (
            document.role(argument) == Role.ARGUMENT
            and document.name(argument) == name
        ):
            var value = document.child(argument, Role.VALUE)
            if document.kind(value) == Kind.STRING:
                return document.string_value(value)
        argument = document.next_sibling(argument)
    return String("")


def _last_segment(identity: String) -> String:
    """Return the text after the last slash.

    Args:
        identity: A link identity, such as `https://specs.apollo.dev/join`.

    Returns:
        The feature name, such as `join`.
    """
    var bytes = identity.as_bytes()
    var start = 0
    var index = 0
    while index < len(bytes):
        if bytes[index] == 47:
            start = index + 1
        index += 1
    return String(identity[byte=start:])


def _collect_interfaces(document: Document, mut spec: _Strip):
    """Record inaccessible interface names.

    Args:
        document: The parsed supergraph.
        spec: The strip set. `interfaces` receives the names.
    """
    var child = document.first_child(document.root)
    while child != NO_NODE:
        if document.kind(child) == Kind.INTERFACE_TYPE_DEFINITION:
            if _has_directive(document, child, spec.inaccessible):
                spec.interfaces[String(document.name(child))] = True
        child = document.next_sibling(child)


def _has_directive(document: Document, node: Int, name: String) -> Bool:
    """Return True when a node applies a directive.

    Args:
        document: The parsed supergraph.
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


def _prefixed(name: String, prefixes: List[String]) -> Bool:
    """Return True when a name starts with a specification prefix.

    Args:
        name: A GraphQL name.
        prefixes: Prefixes such as `join__`.

    Returns:
        Whether the name belongs to a linked specification.
    """
    var index = 0
    while index < len(prefixes):
        if name.startswith(prefixes[index]):
            return True
        index += 1
    return False


def _marked_extra(name: String, extra: String) -> Bool:
    """Return True when a directive was renamed with `@link(as:)`.

    Args:
        name: The directive name.
        extra: The renamed names, each wrapped in spaces.

    Returns:
        Whether `name` is one of those names.
    """
    return extra.find(" " + name + " ") != -1


def _is_specified(name: String) -> Bool:
    """Return True for a built-in directive definition other than `@oneOf`.

    Args:
        name: The directive name.

    Returns:
        Whether the definition is removed.
    """
    return (
        name == "skip"
        or name == "include"
        or name == "deprecated"
        or name == "specifiedBy"
    )


def _is_type_definition(kind: Kind) -> Bool:
    """Return True for a type definition.

    Upstream visits definitions only, so a type extension is kept. Its
    members and directives are still filtered.

    Args:
        kind: The node's kind.

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
    )


def _is_member(kind: Kind) -> Bool:
    """Return True for a field, an input field, or an enum value.

    Args:
        kind: The node's kind.

    Returns:
        Whether the node can be removed on its own.
    """
    return (
        kind == Kind.FIELD_DEFINITION
        or kind == Kind.INPUT_VALUE_DEFINITION
        or kind == Kind.ENUM_VALUE_DEFINITION
    )


def _omit(document: Document, node: Int, spec: _Strip) -> Bool:
    """Return True when the public schema omits a node.

    Args:
        document: The parsed supergraph.
        node: The node.
        spec: The names to remove.

    Returns:
        Whether the node is omitted.
    """
    if document.role(node) == Role.INTERFACE:
        return String(document.name(node)) in spec.interfaces
    var kind = document.kind(node)
    if kind == Kind.SCHEMA_DEFINITION or kind == Kind.SCHEMA_EXTENSION:
        return True
    if kind == Kind.DIRECTIVE or kind == Kind.DIRECTIVE_DEFINITION:
        var name = String(document.name(node))
        if name in spec.directives or _prefixed(name, spec.prefixes):
            return True
        if _marked_extra(name, spec.extra):
            return True
        return kind == Kind.DIRECTIVE_DEFINITION and _is_specified(name)
    if _is_member(kind):
        var name = String(document.name(node))
        if _prefixed(name, spec.prefixes):
            return True
        return _has_directive(document, node, spec.inaccessible)
    if not _is_type_definition(kind):
        return False
    var name = String(document.name(node))
    if _prefixed(name, spec.prefixes):
        return True
    if (
        kind == Kind.SCALAR_TYPE_DEFINITION
        or kind == Kind.ENUM_TYPE_DEFINITION
        or kind == Kind.INPUT_OBJECT_TYPE_DEFINITION
    ):
        if name in spec.definitions:
            return True
    return _has_directive(document, node, spec.inaccessible)


def _copy_one(mut dest: Document, src: Document, node: Int, role: Role) -> Int:
    """Copy one node without its children.

    Args:
        dest: The public document.
        src: The supergraph document.
        node: The node to copy.
        role: The role of the copy.

    Returns:
        The copy's index.
    """
    var kind = src.kind(node)
    if (
        kind == Kind.NAME
        or kind == Kind.INT
        or kind == Kind.FLOAT
        or kind == Kind.ENUM
    ):
        return dest.add_text(kind, role, src.text(node))
    if kind == Kind.STRING:
        var flags = UInt8(0)
        if src.is_block(node):
            flags = FLAG_BLOCK
        return dest.add_text(kind, role, src.string_value(node), flags)
    if kind == Kind.BOOLEAN:
        var flags = UInt8(0)
        if src.boolean_value(node):
            flags = FLAG_TRUE
        return dest.add(kind, role, flags)
    if kind == Kind.DIRECTIVE_DEFINITION and src.is_repeatable(node):
        return dest.add(kind, role, FLAG_REPEATABLE)
    return dest.add(kind, role, 0)


def _copy_kept(
    mut dest: Document, src: Document, node: Int, role: Role, spec: _Strip
) -> Int:
    """Copy a node, omitting children the public schema removes.

    Args:
        dest: The public document.
        src: The supergraph document.
        node: The node to copy.
        role: The role of the copy.
        spec: The names to remove.

    Returns:
        The copy's index, or `NO_NODE` when the node is omitted.
    """
    if _omit(src, node, spec):
        return NO_NODE
    var copy = _copy_one(dest, src, node, role)
    var child = src.first_child(node)
    while child != NO_NODE:
        var child_copy = _copy_kept(dest, src, child, src.role(child), spec)
        if child_copy != NO_NODE:
            dest.append_child(copy, child_copy)
        child = src.next_sibling(child)
    return copy
