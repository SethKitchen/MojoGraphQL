# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The GraphQL serializer of apollo-compiler.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `src/schema/serialize.rs` and
the type system part of `src/ast/serialize.rs`, under the MIT arm of its
MIT OR Apache-2.0 license.

`serialize_schema` prints a `Schema` as upstream `Display for Schema`
does. The built-in types and directives are left out. The `schema`
definition is printed only when the root operations are not the default
ones. A type is printed in definition order, with each extension that
gives it a component printed as an `extend` block after it.
`serialize_document` prints the type system definitions of a parsed
document as upstream `Display for ast::Document` does.

**Differences from upstream.**

- Upstream `serialize()` returns a builder with `indent_prefix`,
  `no_indent` and `initial_indent_level`. Here these are the arguments
  of `serialize_schema` and `serialize_document`, and both return a
  `String`.
- `serialize_document` prints only type system definitions and
  extensions. It raises on an executable definition, which the
  executable serializer prints.
- Upstream builds temporary AST nodes for a schema and prints them. This
  port prints the components where they are, and decodes each string
  into one reused buffer.
"""

from gql_language.ast import (
    Document,
    FLAG_EXTRA,
    Kind,
    NO_NODE,
    OperationType,
    Role,
)
from gql_language.lexer import block_string_value_into, string_value_into
from gql_language.names import NOT_FOUND
from gql_language.scan import find_byte, find_byte4, find_string_escape
from gql_language.scan import string_from_utf8
from std.memory import unsafe_memcpy
from gql_compiler.schema import (
    Component,
    DEFINITION_ORIGIN,
    Members,
    Schema,
    TypeKind,
    definition_kind,
)

comptime BLOCK_STRING_WIDTH = 70
"""A block string longer than this many bytes is printed on many lines."""

comptime NEWLINE = UInt8(ord("\n"))
"""A line feed."""
comptime QUOTE = UInt8(ord('"'))
"""A double quote."""
comptime BACKSLASH = UInt8(ord("\\"))
"""A backslash."""


@always_inline
def _put(mut out: List[UInt8], bytes: Span[UInt8, _]):
    """Append bytes, as the gql_language printer does: a byte loop for short
    text, `memcpy` for long text."""
    var count = len(bytes)
    var length = len(out)
    if length + count > out.capacity():
        out.reserve(max(out.capacity() * 2, length + count))
    var target = out.unsafe_ptr().unsafe_offset(length)
    var source = bytes.unsafe_ptr()
    if count > 16:
        unsafe_memcpy(dest=target, src=source, count=count)
    else:
        var index = 0
        while index < count:
            target[unsafe_offset=index] = source[unsafe_offset=index]
            index += 1
    out._len = length + count


struct State(Movable):
    """The output and the indentation of a serialization: upstream
    `State`."""

    var output: List[UInt8]
    """The bytes written so far."""
    var scratch: List[UInt8]
    """The decoded value of the string being printed."""
    var prefix: String
    """The text repeated once for each indentation level."""
    var newlines: Bool
    """Whether line breaks and indentation are enabled."""
    var indent_level: Int
    """The current indentation level."""

    def __init__(
        out self,
        prefix: String,
        newlines: Bool,
        initial_indent_level: Int,
        capacity: Int = 256,
    ):
        """Make an empty state.

        Args:
            prefix: The indentation of one level.
            newlines: Whether line breaks are enabled.
            initial_indent_level: The indentation level to start at.
            capacity: The bytes to reserve for the output.
        """
        self.output = List[UInt8](capacity=capacity)
        self.scratch = List[UInt8](capacity=256)
        self.prefix = prefix
        self.newlines = newlines
        self.indent_level = initial_indent_level

    def finish(deinit self) -> String:
        """Return the output.

        Returns:
            The text written.
        """
        return string_from_utf8(Span(self.output))

    @always_inline
    def write(mut self, text: StringSlice):
        """Append text.

        Args:
            text: The text.
        """
        self.write_bytes(text.as_bytes())

    @always_inline
    def write_bytes(mut self, bytes: Span[UInt8, _]):
        """Append bytes of UTF-8 text, as the gql_language printer does:
        a byte loop for short text, `memcpy` for long text.

        Args:
            bytes: The bytes.
        """
        _put(self.output, bytes)

    def indent(mut self):
        """Go one level deeper and break the line."""
        self.indent_level += 1
        self._new_line(False)

    def indent_or_space(mut self):
        """Go one level deeper and break the line, or write a space."""
        self.indent_level += 1
        self._new_line(True)

    def dedent(mut self):
        """Go one level up and break the line."""
        self.indent_level -= 1
        self._new_line(False)

    def dedent_or_space(mut self):
        """Go one level up and break the line, or write a space."""
        self.indent_level -= 1
        self._new_line(True)

    def new_line_or_space(mut self):
        """Break the line, or write a space when line breaks are off."""
        self._new_line(True)

    def _new_line(mut self, space: Bool):
        """Break the line and indent: upstream `new_line_common`."""
        if self.newlines:
            self.require_new_line()
        elif space:
            self.output.append(UInt8(ord(" ")))

    def require_new_line(mut self):
        """Break the line and indent, whether or not line breaks are on.

        Upstream panics when line breaks are off. It calls this only when
        they are on, and so does this port.
        """
        self.output.append(NEWLINE)
        var level = 0
        while level < self.indent_level:
            _put(self.output, self.prefix.as_bytes())
            level += 1


@always_inline
def _is_graphql_whitespace(byte: UInt8) -> Bool:
    """Return True for a space or a tab."""
    return byte == UInt8(ord(" ")) or byte == UInt8(ord("\t"))


def _can_be_block(bytes: Span[UInt8, _]) -> Bool:
    """Return the upstream `can_be_block_string` of decoded bytes."""
    var data = bytes.unsafe_ptr()
    var size = len(bytes)
    var line_start = 0
    var zero_indent = False
    var blank = True
    var position = 0
    while position < size:
        var byte = data[unsafe_offset=position]
        if byte == NEWLINE:
            if line_start == 0 and blank:
                return False
            blank = True
            line_start = position + 1
        elif byte == UInt8(ord("\r")):
            return False
        elif not _is_graphql_whitespace(byte):
            if blank and position == line_start:
                zero_indent = True
            blank = False
        position += 1
    return not blank and zero_indent


def can_be_block_string(value: StringSlice) -> Bool:
    """Return True if a block string prints a value as it is.

    A value with a carriage return, a blank first or last line, or an
    indentation common to all its lines is printed as a quoted string.

    Args:
        value: The decoded string.

    Returns:
        The upstream `can_be_block_string`.
    """
    return _can_be_block(value.as_bytes())


def _hex_digit(value: Int) -> UInt8:
    """Return one uppercase hexadecimal digit."""
    if value < 10:
        return UInt8(ord("0") + value)
    return UInt8(ord("A") + value - 10)


def _write_quoted(mut state: State, bytes: Span[UInt8, _]):
    """Write a quoted string with upstream's escapes."""
    var data = bytes.unsafe_ptr()
    state.output.append(QUOTE)
    var start = 0
    var position = 0
    while position < len(bytes):
        var byte = data[unsafe_offset=position]
        if (
            (byte >= UInt8(ord(" ")) or byte == UInt8(ord("\t")))
            and byte != QUOTE
            and byte != BACKSLASH
        ):
            position += 1
            continue
        state.write_bytes(bytes[start:position])
        position += 1
        start = position
        if byte == 0x08:
            state.write("\\b")
        elif byte == NEWLINE:
            state.write("\\n")
        elif byte == 0x0C:
            state.write("\\f")
        elif byte == UInt8(ord("\r")):
            state.write("\\r")
        elif byte == QUOTE:
            state.write('\\"')
        elif byte == BACKSLASH:
            state.write("\\\\")
        else:
            state.write("\\u00")
            state.output.append(_hex_digit(Int(byte) >> 4))
            state.output.append(_hex_digit(Int(byte) & 15))
    state.write_bytes(bytes[start:])
    state.output.append(QUOTE)


def _write_block_line(mut state: State, line: Span[UInt8, _]):
    """Write one line of a block string, with `\"\"\"` escaped."""
    var data = line.unsafe_ptr()
    var size = len(line)
    var start = 0
    var position = find_byte(line, 0, size, QUOTE)
    while position + 2 < size:
        if (
            data[unsafe_offset=position + 1] == QUOTE
            and data[unsafe_offset=position + 2] == QUOTE
        ):
            state.write_bytes(line[start:position])
            state.write('\\"""')
            start = position + 3
            position = find_byte(line, start, size, QUOTE)
        else:
            position = find_byte(line, position + 1, size, QUOTE)
    state.write_bytes(line[start:])


def _write_string_bytes(
    mut state: State, is_description: Bool, bytes: Span[UInt8, _]
):
    """Write a decoded string as a block string or a quoted string:
    upstream `serialize_string_value` and `serialize_block_string`."""
    var size = len(bytes)
    var contains_newline = find_byte(bytes, 0, size, NEWLINE) < size
    var prefer_block = is_description or contains_newline
    if not (state.newlines and prefer_block and _can_be_block(bytes)):
        _write_quoted(state, bytes)
        return
    var last = bytes[size - 1]
    var multi_line = (
        contains_newline
        or size > BLOCK_STRING_WIDTH
        or last == QUOTE
        or last == BACKSLASH
    )
    state.write('"""')
    if not multi_line:
        _write_block_line(state, bytes)
    else:
        var start = 0
        while start <= size:
            var end = find_byte(bytes, start, size, NEWLINE)
            if end == start:
                state.output.append(NEWLINE)
            else:
                state.require_new_line()
                _write_block_line(state, bytes[start:end])
            start = end + 1
        state.require_new_line()
    state.write('"""')


def serialize_string_value(
    mut state: State, is_description: Bool, value: StringSlice
):
    """Write a string as a block string or a quoted string.

    Args:
        state: The output.
        is_description: Whether the string is a description, which
            prefers a block string.
        value: The decoded string.
    """
    _write_string_bytes(state, is_description, value.as_bytes())


@always_inline
def _after_break(data: Span[UInt8, _], line_end: Int, stop: Int) -> Int:
    """Return the offset after the line break at `line_end`, or past `stop`
    for the last line."""
    if line_end >= stop:
        return stop + 1
    if data[line_end] == 0x0D and data[line_end + 1] == 0x0A:
        return line_end + 2
    return line_end + 1


def _block_from_source(
    mut state: State, data: Span[UInt8, _], start: Int, end: Int
) -> Bool:
    """Write a block string token with no backslash from its source lines.

    Without a backslash the value is the source lines, dedented, without
    the blank first and last lines: there is nothing to decode, and no
    `\"\"\"` to escape. The value can be a block string unless it is one
    indented line.

    Returns:
        False, writing nothing, when the token has a backslash or must be
        printed as a quoted string.
    """
    var bytes = data.unsafe_ptr()
    var stop = end - 3
    var common_indent = Int.MAX
    var first_line = -1
    var last_line = -1
    var first_start = 0
    var first_end = 0
    var first_indent = 0
    var last_end = 0
    var line = 0
    var position = start + 3
    while position <= stop:
        var line_end = find_byte4(data, position, stop, 0x0A, 0x0D, 0x5C, 0x0A)
        if line_end < stop and bytes[unsafe_offset=line_end] == BACKSLASH:
            return False
        var indent = 0
        while position + indent < line_end and _is_graphql_whitespace(
            bytes[unsafe_offset=position + indent]
        ):
            indent += 1
        if position + indent < line_end:
            if first_line < 0:
                first_line = line
                first_start = position
                first_end = line_end
                first_indent = indent
            last_line = line
            last_end = line_end
            if line != 0 and indent < common_indent:
                common_indent = indent
        position = _after_break(data, line_end, stop)
        line += 1
    if first_line < 0:
        state.write('""')
        return True
    var single = first_line == last_line
    if single and first_line == 0 and first_indent > 0:
        return False
    if common_indent == Int.MAX:
        common_indent = 0
    var first_begin = first_start
    if first_line != 0:
        first_begin = first_start + common_indent
    var multi_line = (
        not single
        or first_end - first_begin > BLOCK_STRING_WIDTH
        or bytes[unsafe_offset=last_end - 1] == QUOTE
    )
    state.write('"""')
    if not multi_line:
        state.write_bytes(data[first_begin:first_end])
        state.write('"""')
        return True
    line = first_line
    position = first_start
    while line <= last_line:
        var line_end = find_byte4(data, position, stop, 0x0A, 0x0D, 0x0A, 0x0A)
        var begin = position
        if line != 0:
            begin = min(position + common_indent, line_end)
        if begin == line_end:
            state.output.append(NEWLINE)
        else:
            state.require_new_line()
            state.write_bytes(data[begin:line_end])
        position = _after_break(data, line_end, stop)
        line += 1
    state.require_new_line()
    state.write('"""')
    return True


def _quoted_from_source(
    mut state: State,
    is_description: Bool,
    data: Span[UInt8, _],
    start: Int,
    end: Int,
):
    """Write a quoted string token that has nothing to escape or decode.

    Its value is one line with no quote and no backslash, so a block
    string prints it as it is unless it is blank or indented.
    """
    var size = end - start - 2
    if (
        not is_description
        or not state.newlines
        or size == 0
        or _is_graphql_whitespace(data[start + 1])
    ):
        state.write_bytes(data[start:end])
        return
    state.write('"""')
    if size > BLOCK_STRING_WIDTH:
        state.require_new_line()
        state.write_bytes(data[start + 1 : end - 1])
        state.require_new_line()
    else:
        state.write_bytes(data[start + 1 : end - 1])
    state.write('"""')


def _write_string_node(
    mut state: State, document: Document, node: Int, is_description: Bool
):
    """Write a `StringValue` node: from its source when the source is
    already what upstream prints, or else from its decoded value."""
    ref found = document.nodes[node]
    var start = Int(found.start)
    var end = Int(found.end)
    var data = Span(document.source.bytes)
    var extra = found.flags & FLAG_EXTRA != 0
    var block = document.is_block(node)
    if not extra:
        if block:
            if state.newlines and _block_from_source(state, data, start, end):
                return
        elif find_string_escape(data, start + 1, end - 1) == end - 1:
            _quoted_from_source(state, is_description, data, start, end)
            return
    var scratch = List[UInt8]()
    swap(scratch, state.scratch)
    scratch.clear()
    if extra:
        scratch.extend(data[start:end])
    elif block:
        block_string_value_into(data, start, end, scratch)
    else:
        string_value_into(data, start, end, scratch)
    _write_string_bytes(state, is_description, Span(scratch))
    swap(scratch, state.scratch)


def _write_type(mut state: State, document: Document, node: Int):
    """Write a type reference: upstream `Display for Type`."""
    var kind = document.kind(node)
    if kind == Kind.NAMED_TYPE:
        state.write(document.name(node))
    elif kind == Kind.LIST_TYPE:
        state.write("[")
        _write_type(state, document, document.child(node, Role.TYPE))
        state.write("]")
    else:
        _write_type(state, document, document.child(node, Role.TYPE))
        state.write("!")


def _comma_separated(
    mut state: State,
    document: Document,
    open: StaticString,
    close: StaticString,
    parent: Int,
    role: Role,
):
    """Write the children of a node with one role between brackets,
    separated by commas: upstream `comma_separated`. A child is printed by
    `_write_item`."""
    state.write(open)
    var child = document.child(parent, role)
    if child != NO_NODE:
        state.indent()
        _write_item(state, document, child)
        child = document.next_with_role(child)
        while child != NO_NODE:
            state.output.append(UInt8(ord(",")))
            state.new_line_or_space()
            _write_item(state, document, child)
            child = document.next_with_role(child)
        if state.newlines:
            state.output.append(UInt8(ord(",")))
        state.dedent()
    state.write(close)


def _write_item(mut state: State, document: Document, node: Int):
    """Write an argument, an object field, an argument definition or a
    value."""
    var kind = document.kind(node)
    if kind == Kind.ARGUMENT or kind == Kind.OBJECT_FIELD:
        state.write(document.name(node))
        state.write(": ")
        _write_value(state, document, document.child(node, Role.VALUE))
    elif kind == Kind.INPUT_VALUE_DEFINITION:
        _write_input_value(state, document, node)
    else:
        _write_value(state, document, node)


def _write_value(mut state: State, document: Document, node: Int):
    """Write a value: upstream `Value::serialize_impl`."""
    var kind = document.kind(node)
    if kind == Kind.NULL:
        state.write("null")
    elif kind == Kind.BOOLEAN:
        state.write("true" if document.boolean_value(node) else "false")
    elif kind == Kind.STRING:
        _write_string_node(state, document, node, False)
    elif kind == Kind.VARIABLE:
        state.write("$")
        state.write(document.name(node))
    elif kind == Kind.LIST:
        _comma_separated(state, document, "[", "]", node, Role.LIST_ITEM)
    elif kind == Kind.OBJECT:
        _comma_separated(state, document, "{", "}", node, Role.FIELD)
    else:
        state.write(document.text(node))


def _write_directive(mut state: State, document: Document, node: Int):
    """Write a space and a directive, with its arguments on one line:
    upstream `DirectiveList`, `Directive` and `serialize_arguments`."""
    state.write(" @")
    state.write(document.name(node))
    if document.child(node, Role.ARGUMENT) == NO_NODE:
        return
    var newlines = state.newlines
    state.newlines = False
    _comma_separated(state, document, "(", ")", node, Role.ARGUMENT)
    state.newlines = newlines


def _write_directives(mut state: State, document: Document, node: Int):
    """Write all the directives of a node."""
    var child = document.child(node, Role.DIRECTIVE)
    while child != NO_NODE:
        _write_directive(state, document, child)
        child = document.next_with_role(child)


def _write_description(mut state: State, document: Document, node: Int):
    """Write the description of a definition and a line break: upstream
    `serialize_description`."""
    var found = document.child(node, Role.DESCRIPTION)
    if found == NO_NODE:
        return
    _write_string_node(state, document, found, True)
    state.new_line_or_space()


def _write_input_value(mut state: State, document: Document, node: Int):
    """Write an argument or input field definition: upstream
    `InputValueDefinition::serialize_impl`."""
    _write_description(state, document, node)
    state.write(document.name(node))
    state.write(": ")
    _write_type(state, document, document.child(node, Role.TYPE))
    var default = document.child(node, Role.DEFAULT_VALUE)
    if default != NO_NODE:
        state.write(" = ")
        _write_value(state, document, default)
    _write_directives(state, document, node)


def _write_arguments_definition(
    mut state: State, document: Document, node: Int
):
    """Write argument definitions, on one line unless one has a
    description or a directive: upstream
    `serialize_arguments_definition`."""
    var argument = document.child(node, Role.ARGUMENT)
    if argument == NO_NODE:
        return
    var multi_line = False
    while argument != NO_NODE:
        if document.has_description(argument) or (
            document.child(argument, Role.DIRECTIVE) != NO_NODE
        ):
            multi_line = True
        argument = document.next_with_role(argument)
    var newlines = state.newlines
    if not multi_line:
        state.newlines = False
    _comma_separated(state, document, "(", ")", node, Role.ARGUMENT)
    state.newlines = newlines


def _write_member(mut state: State, document: Document, node: Int):
    """Write a field, an input field or an enum value definition."""
    var kind = document.kind(node)
    if kind == Kind.INPUT_VALUE_DEFINITION:
        _write_input_value(state, document, node)
        return
    _write_description(state, document, node)
    state.write(document.name(node))
    if kind == Kind.FIELD_DEFINITION:
        _write_arguments_definition(state, document, node)
        state.write(": ")
        _write_type(state, document, document.child(node, Role.TYPE))
    _write_directives(state, document, node)


def _write_directive_definition(
    mut state: State, document: Document, node: Int
):
    """Write a directive definition: upstream
    `DirectiveDefinition::serialize_impl`."""
    _write_description(state, document, node)
    state.write("directive @")
    state.write(document.name(node))
    _write_arguments_definition(state, document, node)
    if document.is_repeatable(node):
        state.write(" repeatable")
    var location = document.child(node, Role.LOCATION)
    state.write(" on ")
    state.write(document.text(location))
    location = document.next_with_role(location)
    while location != NO_NODE:
        state.write(" | ")
        state.write(document.text(location))
        location = document.next_with_role(location)


def _begin(mut state: State, mut count: Int):
    """Separate a top-level definition from the one before it: upstream
    `top_level`."""
    if count > 0:
        if state.newlines:
            state.output.append(NEWLINE)
        state.new_line_or_space()
    count += 1


def _end(mut state: State, count: Int):
    """Write the trailing line break of a document: upstream
    `top_level`."""
    if count > 0 and state.newlines:
        state.output.append(NEWLINE)


def _keyword(kind: TypeKind) -> StaticString:
    """Return the keyword of a type definition, and a space."""
    if kind == TypeKind.SCALAR:
        return "scalar "
    if kind == TypeKind.OBJECT:
        return "type "
    if kind == TypeKind.INTERFACE:
        return "interface "
    if kind == TypeKind.UNION:
        return "union "
    if kind == TypeKind.ENUM:
        return "enum "
    return "input "


struct _Parts(Movable):
    """The components of a definition or an extension, and the origin that
    picks them: upstream `components` and `names`."""

    var interfaces: Members
    """The `implements` names."""
    var directives: Members
    """The directives."""
    var members: Members
    """The fields, the enum values, the union members or the input
    fields."""
    var origin: Int32
    """The origin of the components to print."""

    def __init__(
        out self,
        interfaces: Members,
        directives: Members,
        members: Members,
        origin: Int32,
    ):
        """Gather the runs of components.

        Args:
            interfaces: The `implements` names.
            directives: The directives.
            members: The members.
            origin: The origin of the components to print.
        """
        self.interfaces = interfaces
        self.directives = directives
        self.members = members
        self.origin = origin


def _write_names(
    mut state: State,
    sources: List[Document],
    components: List[Component],
    names: Members,
    origin: Int32,
    first: StaticString,
    separator: StaticString,
):
    """Write the names of `NamedType` components of one origin, as in
    `implements A & B` and `= A | B`."""
    var written = False
    var position = Int(names.start)
    var stop = position + Int(names.count)
    while position < stop:
        var name = components[position]
        if name.origin == origin:
            state.write(separator if written else first)
            state.write(sources[Int(name.source)].name(Int(name.node)))
            written = True
        position += 1


def _write_directive_run(
    mut state: State,
    sources: List[Document],
    components: List[Component],
    directives: Members,
    origin: Int32,
):
    """Write the directives of one origin."""
    var position = Int(directives.start)
    var stop = position + Int(directives.count)
    while position < stop:
        var directive = components[position]
        if directive.origin == origin:
            _write_directive(
                state, sources[Int(directive.source)], Int(directive.node)
            )
        position += 1


def _write_type_like(
    mut state: State,
    sources: List[Document],
    components: List[Component],
    kind: TypeKind,
    definition: Optional[Component],
    name: StringSlice,
    parts: _Parts,
):
    """Write a type definition, or an extension when `definition` is
    None: upstream `serialize_object_type_like`, `serialize_union` and the
    definitions and extensions that call them."""
    if definition:
        var found = definition.value()
        _write_description(state, sources[Int(found.source)], Int(found.node))
    else:
        state.write("extend ")
    state.write(_keyword(kind))
    state.write(name)
    var origin = parts.origin
    _write_names(
        state,
        sources,
        components,
        parts.interfaces,
        origin,
        " implements ",
        " & ",
    )
    _write_directive_run(state, sources, components, parts.directives, origin)
    if kind == TypeKind.UNION:
        _write_names(
            state, sources, components, parts.members, origin, " = ", " | "
        )
        return
    var written = False
    var position = Int(parts.members.start)
    var stop = position + Int(parts.members.count)
    while position < stop:
        var member = components[position]
        if member.origin == origin:
            if written:
                state.new_line_or_space()
            else:
                state.write(" {")
                state.indent_or_space()
                written = True
            _write_member(state, sources[Int(member.source)], Int(member.node))
        position += 1
    if written:
        state.dedent_or_space()
        state.write("}")


def _write_schema_like(
    mut state: State,
    sources: List[Document],
    components: List[Component],
    definition: Optional[Component],
    directives: Members,
    origin: Int32,
    operations: List[OperationType],
    types: List[String],
):
    """Write a `schema` definition, or an extension when `definition` is
    None: upstream `SchemaDefinition` and `SchemaExtension`. The node of
    an implicit definition is `NO_NODE`."""
    if definition:
        var found = definition.value()
        if found.node != NO_NODE:
            _write_description(
                state, sources[Int(found.source)], Int(found.node)
            )
        state.write("schema")
    else:
        state.write("extend schema")
    _write_directive_run(state, sources, components, directives, origin)
    # A `schema` definition always has a root operation: the parser
    # requires one, and the schema prints the definition only with one.
    if len(operations) == 0:
        return
    state.write(" {")
    state.indent_or_space()
    var index = 0
    while index < len(operations):
        if index > 0:
            state.new_line_or_space()
        state.write(operations[index].text())
        state.write(": ")
        state.write(types[index])
        index += 1
    state.dedent_or_space()
    state.write("}")


def _collect_origins(
    schema: Schema, members: Members, mut origins: List[Int32]
):
    """Append the extensions that give a run of components, each once, in
    the order they first appear: upstream `extensions`."""
    var position = Int(members.start)
    var stop = position + Int(members.count)
    while position < stop:
        var origin = schema.components[position].origin
        if origin != DEFINITION_ORIGIN and origin not in origins:
            origins.append(origin)
        position += 1


def _write_schema_definition(mut state: State, schema: Schema, mut count: Int):
    """Write the `schema` definition when the root operations need it, and
    the schema extensions: upstream `SchemaDefinition::to_ast`."""
    var origins = List[Int32]()
    _collect_origins(schema, schema.schema_directives, origins)
    var has_definition_roots = False
    var slot = 0
    while slot < 3:
        if schema.roots[slot]:
            var origin = schema.roots[slot].value().component.origin
            if origin == DEFINITION_ORIGIN:
                has_definition_roots = True
            elif origin not in origins:
                origins.append(origin)
        slot += 1
    var definition = schema.schema_definition
    var described = definition.node != NO_NODE and (
        schema.sources[Int(definition.source)].has_description(
            Int(definition.node)
        )
    )
    var implicit = True
    if has_definition_roots:
        implicit = (
            not described
            and schema.schema_directives.count == 0
            and len(origins) == 0
        )
        var defaults: List[StaticString] = ["Query", "Mutation", "Subscription"]
        slot = 0
        while slot < 3:
            var index = schema.get_type(defaults[slot])
            var has_object = (
                index != NOT_FOUND
                and schema.types[index].kind == TypeKind.OBJECT
            )
            if schema.roots[slot]:
                var actual = schema.roots[slot].value().type_name
                if not has_object or actual != defaults[slot]:
                    implicit = False
            elif has_object:
                implicit = False
            slot += 1
    if not implicit:
        _begin(state, count)
        _write_schema_roots(state, schema, definition, DEFINITION_ORIGIN)
    var index = 0
    while index < len(origins):
        _begin(state, count)
        _write_schema_roots(state, schema, None, origins[index])
        index += 1


def _write_schema_roots(
    mut state: State,
    schema: Schema,
    definition: Optional[Component],
    origin: Int32,
):
    """Write the `schema` definition or one extension, with the root
    operations of one origin."""
    var operations = List[OperationType]()
    var types = List[String]()
    var slot = 0
    while slot < 3:
        if schema.roots[slot]:
            ref root = schema.roots[slot].value()
            if root.component.origin == origin:
                operations.append(OperationType(UInt8(slot)))
                types.append(root.type_name)
        slot += 1
    _write_schema_like(
        state,
        schema.sources,
        schema.components,
        definition,
        schema.schema_directives,
        origin,
        operations,
        types,
    )


def _write_extended_type(
    mut state: State, schema: Schema, index: Int, mut count: Int
):
    """Write a type and its extensions: upstream `ExtendedType::to_ast`. A
    built-in type is left out, but not its extensions."""
    ref extended = schema.types[index]
    var name = schema.type_name(index)
    if not schema.is_built_in(index):
        _begin(state, count)
        _write_type_like(
            state,
            schema.sources,
            schema.components,
            extended.kind,
            extended.definition,
            name,
            _Parts(
                extended.interfaces,
                extended.directives,
                extended.members,
                DEFINITION_ORIGIN,
            ),
        )
    if len(schema.extensions) == 0:
        return
    var origins = List[Int32]()
    _collect_origins(schema, extended.directives, origins)
    _collect_origins(schema, extended.interfaces, origins)
    _collect_origins(schema, extended.members, origins)
    var position = 0
    while position < len(origins):
        _begin(state, count)
        _write_type_like(
            state,
            schema.sources,
            schema.components,
            extended.kind,
            None,
            name,
            _Parts(
                extended.interfaces,
                extended.directives,
                extended.members,
                origins[position],
            ),
        )
        position += 1


def serialize_schema(
    schema: Schema,
    indent_prefix: String = "  ",
    newlines: Bool = True,
    initial_indent_level: Int = 0,
) -> String:
    """Print a schema: upstream `Schema::serialize` and `Display for
    Schema`.

    Args:
        schema: The schema.
        indent_prefix: The indentation of one level: upstream
            `indent_prefix`.
        newlines: False to print everything on one line: upstream
            `no_indent`.
        initial_indent_level: The indentation level to start at.

    Returns:
        The schema as GraphQL text, without the built-in definitions.
    """
    var capacity = 256
    var source = 1
    while source < len(schema.sources):
        capacity += len(schema.sources[source].source.bytes)
        source += 1
    var state = State(indent_prefix, newlines, initial_indent_level, capacity)
    var count = 0
    _write_schema_definition(state, schema, count)
    var index = 0
    while index < len(schema.directive_definitions):
        var directive = schema.directive_definitions[index]
        if directive.source != 0:
            _begin(state, count)
            _write_directive_definition(
                state,
                schema.sources[Int(directive.source)],
                Int(directive.node),
            )
        index += 1
    index = 0
    while index < len(schema.types):
        _write_extended_type(state, schema, index, count)
        index += 1
    _end(state, count)
    return state^.finish()


def _gather(
    document: Document, node: Int, role: Role, mut components: List[Component]
) -> Members:
    """Append the children of a node with one role, as components of the
    first source, and return their run. `Role.FIELD` also takes enum
    values and union members."""
    var start = len(components)
    var child = document.first_child(node)
    while child != NO_NODE:
        var found = document.role(child)
        if found == role or (
            role == Role.FIELD
            and (found == Role.ENUM_VALUE or found == Role.MEMBER_TYPE)
        ):
            components.append(Component(0, Int32(child), DEFINITION_ORIGIN))
        child = document.next_sibling(child)
    return Members(Int32(start), Int32(len(components) - start))


def _write_document_schema(
    mut state: State, sources: List[Document], node: Int
):
    """Write a `schema` definition or extension node."""
    ref document = sources[0]
    var operations = List[OperationType]()
    var types = List[String]()
    var child = document.child(node, Role.OPERATION_TYPE)
    while child != NO_NODE:
        operations.append(document.operation(child))
        types.append(String(document.name(document.child(child, Role.TYPE))))
        child = document.next_with_role(child)
    var definition = Optional[Component](None)
    if document.kind(node) == Kind.SCHEMA_DEFINITION:
        definition = Component(0, Int32(node), DEFINITION_ORIGIN)
    var components = List[Component]()
    var directives = _gather(document, node, Role.DIRECTIVE, components)
    _write_schema_like(
        state,
        sources,
        components,
        definition,
        directives,
        DEFINITION_ORIGIN,
        operations,
        types,
    )


def serialize_document(
    document: Document,
    indent_prefix: String = "  ",
    newlines: Bool = True,
    initial_indent_level: Int = 0,
) raises -> String:
    """Print the type system definitions of a document: upstream
    `Display for ast::Document`.

    Args:
        document: A parsed document.
        indent_prefix: The indentation of one level: upstream
            `indent_prefix`.
        newlines: False to print everything on one line: upstream
            `no_indent`.
        initial_indent_level: The indentation level to start at.

    Returns:
        The document as GraphQL text.

    Raises:
        Error: If the document has an executable definition or a directive
            extension.
    """
    var sources = List[Document]()
    sources.append(document.copy())
    var state = State(
        indent_prefix,
        newlines,
        initial_indent_level,
        len(document.source.bytes) + 256,
    )
    var count = 0
    var definitions = document.definitions()
    var index = 0
    while index < len(definitions):
        var node = definitions[index]
        index += 1
        var kind = document.kind(node)
        var type_kind = definition_kind(kind)
        if kind == Kind.DIRECTIVE_DEFINITION:
            _begin(state, count)
            _write_directive_definition(state, document, node)
        elif kind == Kind.SCHEMA_DEFINITION or kind == Kind.SCHEMA_EXTENSION:
            _begin(state, count)
            _write_document_schema(state, sources, node)
        elif type_kind >= 0:
            _begin(state, count)
            var definition = Optional[Component](None)
            if not kind.is_type_extension():
                definition = Component(0, Int32(node), DEFINITION_ORIGIN)
            var components = List[Component]()
            var interfaces = _gather(document, node, Role.INTERFACE, components)
            var directives = _gather(document, node, Role.DIRECTIVE, components)
            var members = _gather(document, node, Role.FIELD, components)
            _write_type_like(
                state,
                sources,
                components,
                TypeKind(UInt8(type_kind)),
                definition,
                document.name(node),
                _Parts(interfaces, directives, members, DEFINITION_ORIGIN),
            )
        else:
            raise Error(
                "serialize_document prints only type system definitions, not ",
                kind,
            )
    _end(state, count)
    return state^.finish()


def serialize_value(
    document: Document,
    node: Int,
    indent_prefix: String = "  ",
    newlines: Bool = True,
    initial_indent_level: Int = 0,
) -> String:
    """Print a value: upstream `Value::serialize` and `Display for Value`.

    Args:
        document: The document that holds the value.
        node: The value node.
        indent_prefix: The indentation of one level.
        newlines: False to print everything on one line: upstream
            `no_indent`.
        initial_indent_level: The indentation level to start at.

    Returns:
        The value as GraphQL text.
    """
    var state = State(indent_prefix, newlines, initial_indent_level)
    _write_value(state, document, node)
    return state^.finish()
