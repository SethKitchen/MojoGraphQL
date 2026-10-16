# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Print an AST back to GraphQL text.

Port of graphql-js 16.14.2 `language/printer.ts`. Each kind's case is the
`leave` function of the same kind in graphql-js `printDocASTReducer`, so the
output is the same text, byte for byte.

**One buffer.** graphql-js builds a string for every node, joins them, and
copies each block again to indent it. This port writes once, into one byte
list:

- `join` writes the separator and then the part. When the part comes out
  empty, both are cut off again, which is what graphql-js `join` does when
  it drops an empty part.
- `indent` is applied as the text is written: every line feed is followed
  by two spaces per open block.
- The two layout tests that graphql-js does on finished strings, "has a
  multi-line item" and "longer than 80 characters", print the one-line form
  first, test it, and print the other form in its place when needed. The
  80-character test prints at indent 0, so it measures the same unindented
  text as graphql-js.

**Small calls.** The printer reads nodes and text through two raw pointers
that it takes from the document once, so each recursive call carries only
the printer and a node index. A node's children are read once into a
`_Kids` table of the first child of each role, and every property is looked
up there. The large, rare cases are kept out of line.
"""

from gql_language.ast import FLAG_BLOCK, FLAG_EXTRA, FLAG_REPEATABLE, FLAG_TRUE
from gql_language.ast import NO_NODE, Document, Kind, Node, OperationType, Role
from gql_language.ast import role_bit
from gql_language.block_string import (
    append_string_literal,
    block_string_layout,
    utf16_count,
)
from gql_language.lexer import block_string_value_into, string_value_into
from gql_language.scan import (
    count_utf16,
    find_byte2,
    find_byte4,
    find_string_escape,
)
from std.memory import unsafe_memcpy

comptime MAX_LINE_LENGTH = 80
"""The longest field line that keeps its arguments on one line."""

comptime _Nodes = Pointer[Node, UntrackedOrigin[mut=False]]
comptime _Bytes = Pointer[UInt8, UntrackedOrigin[mut=False]]
comptime _Text = Span[UInt8, UntrackedOrigin[mut=False]]


@always_inline
def _span(bytes: _Bytes, length: Int) -> _Text:
    """Return a view of `length` bytes at a pointer."""
    return _Text(unsafe_ptr=bytes, length=length)


@always_inline
def _after_break(data: _Text, line_end: Int, stop: Int) -> Int:
    """Return the offset after the line break at `line_end`, or past `stop`
    for the last line."""
    if line_end >= stop:
        return stop + 1
    if data[line_end] == 0x0D and data[line_end + 1] == 0x0A:
        return line_end + 2
    return line_end + 1


@always_inline
def _newline(mut out: List[UInt8], level: Int):
    """Write a line feed and two spaces per open block."""
    comptime spaces: StaticString = "                                "
    out.append(0x0A)
    var count = level * 2
    while count > 0:
        var run = min(count, spaces.byte_length())
        out.extend(spaces.as_bytes()[0:run])
        count -= run


def _write_lines(mut out: List[UInt8], level: Int, text: Span[UInt8, _]):
    """Write bytes, indenting after each line feed."""
    var chunk = 0
    var index = 0
    while index < len(text):
        if text[index] == 0x0A:
            out.extend(text[chunk:index])
            _newline(out, level)
            chunk = index + 1
        index += 1
    out.extend(text[chunk : len(text)])


def _write_block_value(mut out: List[UInt8], level: Int, value: Span[UInt8, _]):
    """Write a block string's value in one pass: each `\"\"\"` escaped, as
    graphql-js `printBlockString`, and each line feed indented, as
    graphql-js `indent`."""
    var size = len(value)
    var chunk = 0
    var index = find_byte2(value, 0, size, 0x0A, 0x22)
    while index < size:
        if value[index] == 0x0A:
            out.extend(value[chunk:index])
            _newline(out, level)
            index += 1
            chunk = index
        elif (
            index + 2 < size
            and value[index + 1] == 0x22
            and value[index + 2] == 0x22
        ):
            out.extend(value[chunk:index])
            out.append(0x5C)
            # The quotes start the next run.
            chunk = index
            index += 3
        else:
            index += 1
        index = find_byte2(value, index, size, 0x0A, 0x22)
    out.extend(value[chunk:size])


@fieldwise_init
struct _Kids(ImplicitlyCopyable, Movable):
    """A node's children, looked up by role.

    A node has few children, so a lookup scans them; a table of all roles
    costs more to fill than the scans it saves.
    """

    var nodes: _Nodes
    var first: Int
    var roles: UInt32

    @always_inline
    def __getitem__(self, role: Role) -> Int:
        """Return the first child with a role, or `NO_NODE`."""
        if self.roles & role_bit(role) == 0:
            return NO_NODE
        # A set bit means a child has the role: the parser and the builder
        # set a bit only when they add a child with it.
        var current = self.first
        while self.nodes[unsafe_offset=current].role != role:
            current = Int(self.nodes[unsafe_offset=current].next)
        return current

    @always_inline
    def has(self, role: Role) -> Bool:
        """Return True if a child has the role."""
        return self.roles & role_bit(role) != 0


struct _State(Movable):
    """What printing changes: the output, the indent and a scratch buffer."""

    var out: List[UInt8]
    var level: Int
    var value: List[UInt8]

    def __init__(out self, capacity: Int):
        """Start with an empty buffer."""
        self.out = List[UInt8](capacity=capacity)
        self.level = 0
        self.value = List[UInt8]()


@fieldwise_init
struct _Printer(ImplicitlyCopyable, Movable):
    """Read-only views of the document, and a pointer to the state.

    Every method takes `self` by value: four words, with nothing to copy
    back. Mojo passes a `mut` struct of this size as its fields and copies
    them back on return, which cost more than the printing itself.
    """

    var nodes: _Nodes
    var bytes: _Bytes
    var size: Int
    var s: Pointer[_State, UntrackedOrigin[mut=True]]

    # --- nodes ------------------------------------------------------------

    @always_inline
    def kind(self, node: Int) -> Kind:
        """Return a node's kind."""
        return self.nodes[unsafe_offset=node].kind

    @always_inline
    def role(self, node: Int) -> Role:
        """Return a node's role."""
        return self.nodes[unsafe_offset=node].role

    @always_inline
    def flags(self, node: Int) -> UInt8:
        """Return a node's flags."""
        return self.nodes[unsafe_offset=node].flags

    @always_inline
    def next(self, node: Int) -> Int:
        """Return a node's next sibling."""
        return Int(self.nodes[unsafe_offset=node].next)

    @always_inline
    def data(self) -> _Text:
        """Return all of the document's text bytes."""
        return _span(self.bytes, self.size)

    @always_inline
    def kids(self, node: Int) -> _Kids:
        """Return a view of a node's children."""
        ref found = self.nodes[unsafe_offset=node]
        return _Kids(self.nodes, Int(found.first), found.roles)

    # --- writing ----------------------------------------------------------

    @always_inline
    def write(self, text: StaticString):
        """Write text that has no line feed."""
        self.put(
            text.unsafe_ptr().unsafe_origin_cast[UntrackedOrigin[mut=False]](),
            text.byte_length(),
        )

    @always_inline
    def put(self, source: _Bytes, count: Int):
        """Copy bytes to the end of the buffer.

        The text written is short, so a byte loop beats a call to `memcpy`.
        """
        var length = len(self.s[].out)
        if length + count > self.s[].out.capacity():
            self.s[].out.reserve(
                max(self.s[].out.capacity() * 2, length + count)
            )
        var target = self.s[].out.unsafe_ptr().unsafe_offset(length)
        if count > 16:
            unsafe_memcpy(dest=target, src=source, count=count)
        else:
            var index = 0
            while index < count:
                target[unsafe_offset=index] = source[unsafe_offset=index]
                index += 1
        self.s[].out._len = length + count

    @always_inline
    def write_text(self, node: Int):
        """Write a node's own text: a name, a number or an enum value."""
        ref found = self.nodes[unsafe_offset=node]
        var start = Int(found.start)
        self.put(self.bytes.unsafe_offset(start), Int(found.end) - start)

    @always_inline
    def newline(self):
        """Write a line feed and the indent of the open blocks."""
        _newline(self.s[].out, self.s[].level)

    @always_inline
    def cut(self, size: Int):
        """Remove everything written after `size` bytes."""
        self.s[].out.resize(size, 0)

    @always_inline
    def drop_if_empty(self, mark: Int, body: Int):
        """Cut back to `mark` when nothing was written after `body`."""
        if len(self.s[].out) == body:
            self.cut(mark)

    def has_line_feed(self, start: Int) -> Bool:
        """Return True if a line feed was written after `start` bytes."""
        var size = len(self.s[].out)
        return find_byte2(Span(self.s[].out), start, size, 0x0A, 0x0A) < size

    # --- children ---------------------------------------------------------

    @always_inline
    def print_child(self, child: Int):
        """Print a child; a name without a dispatch."""
        if self.kind(child) == Kind.NAME:
            self.write_text(child)
        else:
            self.node(child)

    @always_inline
    def one(self, kids: _Kids, role: Role):
        """Print the first child with a role, if there is one."""
        var found = kids[role]
        if found != NO_NODE:
            self.print_child(found)

    def join(self, kids: _Kids, role: Role, separator: StaticString):
        """Print the children with a role, separated, as graphql-js `join`."""
        var first = True
        var current = kids[role]
        while current != NO_NODE:
            if self.role(current) == role:
                var mark = len(self.s[].out)
                if not first:
                    _write_lines(
                        self.s[].out, self.s[].level, separator.as_bytes()
                    )
                var body = len(self.s[].out)
                self.print_child(current)
                if len(self.s[].out) == body:
                    self.cut(mark)
                else:
                    first = False
            current = self.next(current)

    def join_lines(self, kids: _Kids, role: Role):
        """Print the children with a role, one per line."""
        var first = True
        var current = kids[role]
        while current != NO_NODE:
            if self.role(current) == role:
                var mark = len(self.s[].out)
                if not first:
                    self.newline()
                var body = len(self.s[].out)
                self.node(current)
                if len(self.s[].out) == body:
                    self.cut(mark)
                else:
                    first = False
            current = self.next(current)

    def wrapped(
        self,
        kids: _Kids,
        role: Role,
        open: StaticString,
        separator: StaticString,
        close: StaticString,
    ):
        """Print `open`, the joined children and `close`; or nothing."""
        if not kids.has(role):
            return
        var mark = len(self.s[].out)
        self.write(open)
        var body = len(self.s[].out)
        self.join(kids, role, separator)
        if len(self.s[].out) == body:
            self.cut(mark)
        else:
            self.write(close)

    def lines_in_parentheses(self, kids: _Kids, role: Role, indent: Bool):
        """Print the children one per line between parentheses."""
        self.write("(")
        if indent:
            self.s[].level += 1
        self.newline()
        self.join_lines(kids, role)
        if indent:
            self.s[].level -= 1
        self.newline()
        self.write(")")

    def block(self, kids: _Kids, role: Role):
        """Print the children one per line in braces, as graphql-js `block`."""
        if not kids.has(role):
            return
        var mark = len(self.s[].out)
        self.write("{")
        self.s[].level += 1
        self.newline()
        var body = len(self.s[].out)
        self.join_lines(kids, role)
        self.s[].level -= 1
        if len(self.s[].out) == body:
            self.cut(mark)
        else:
            self.newline()
            self.write("}")

    def spaced_block(self, kids: _Kids, role: Role):
        """Print a space and a block, or nothing for an empty block."""
        if not kids.has(role):
            return
        var mark = len(self.s[].out)
        self.write(" ")
        var body = len(self.s[].out)
        self.block(kids, role)
        self.drop_if_empty(mark, body)

    def spaced_join(
        self,
        kids: _Kids,
        role: Role,
        open: StaticString,
        separator: StaticString,
    ):
        """Print `open` and the joined children, or nothing."""
        if not kids.has(role):
            return
        var mark = len(self.s[].out)
        self.write(open)
        var body = len(self.s[].out)
        self.join(kids, role, separator)
        self.drop_if_empty(mark, body)

    @always_inline
    def spaced_one(self, kids: _Kids, role: Role, open: StaticString):
        """Print `open` and the first child with a role, or nothing."""
        var found = kids[role]
        if found == NO_NODE:
            return
        var mark = len(self.s[].out)
        self.write(open)
        var body = len(self.s[].out)
        self.print_child(found)
        self.drop_if_empty(mark, body)

    @always_inline
    def spaced_directives(self, kids: _Kids):
        """Print a space and the directives, or nothing."""
        self.spaced_join(kids, Role.DIRECTIVE, " ", " ")

    @always_inline
    def description(self, kids: _Kids):
        """Print a description and a line feed, if there is one."""
        var found = kids[Role.DESCRIPTION]
        if found != NO_NODE:
            self.node(found)
            self.newline()

    def argument_definitions(self, kids: _Kids):
        """Print argument definitions, one per line if any spans lines."""
        if not kids.has(Role.ARGUMENT):
            return
        var start = len(self.s[].out)
        self.wrapped(kids, Role.ARGUMENT, "(", ", ", ")")
        if self.has_line_feed(start):
            self.cut(start)
            self.lines_in_parentheses(kids, Role.ARGUMENT, True)

    def keyword(self, kind: Kind, word: StaticString):
        """Print a keyword, with `extend ` before it for an extension."""
        if kind.is_type_extension():
            self.write("extend ")
        self.write(word)

    # --- nodes ------------------------------------------------------------

    def node(self, node: Int):
        """Print one node and its descendants."""
        var kind = self.kind(node)
        if kind == Kind.FIELD:
            self.field(node)
        elif kind == Kind.NAMED_TYPE:
            var kids = self.kids(node)
            self.one(kids, Role.NAME)
        elif (
            kind == Kind.NAME
            or kind == Kind.INT
            or kind == Kind.FLOAT
            or kind == Kind.ENUM
        ):
            self.write_text(node)
        elif kind == Kind.SELECTION_SET:
            var kids = self.kids(node)
            self.block(kids, Role.SELECTION)
        elif kind == Kind.ARGUMENT or kind == Kind.OBJECT_FIELD:
            var kids = self.kids(node)
            self.one(kids, Role.NAME)
            self.write(": ")
            self.one(kids, Role.VALUE)
        elif kind == Kind.NON_NULL_TYPE:
            var kids = self.kids(node)
            self.one(kids, Role.TYPE)
            self.write("!")
        elif kind == Kind.FIELD_DEFINITION:
            self.field_definition(node)
        elif kind == Kind.INPUT_VALUE_DEFINITION:
            self.input_value_definition(node)
        elif kind == Kind.STRING:
            self.string(node)
        else:
            self.other(node, kind)

    @inline(.never)
    def other(self, node: Int, kind: Kind):
        """Print any node but the most common kinds."""
        if kind == Kind.LIST_TYPE:
            var kids = self.kids(node)
            self.write("[")
            self.one(kids, Role.TYPE)
            self.write("]")
        elif kind.is_value():
            self.value_literal(node, kind)
        elif kind.is_executable_definition() or kind == Kind.DOCUMENT:
            self.executable(node, kind)
        elif (
            kind == Kind.FRAGMENT_SPREAD
            or kind == Kind.INLINE_FRAGMENT
            or kind == Kind.VARIABLE_DEFINITION
            or kind == Kind.DIRECTIVE
        ):
            self.selection_part(node, kind)
        elif kind.is_schema_coordinate():
            self.coordinate(node, kind)
        else:
            self.type_system(node, kind)

    def field(self, node: Int):
        """Print a field: alias, name, arguments, directives, selections."""
        var kids = self.kids(node)
        var line_start = len(self.s[].out)
        var alias = kids[Role.ALIAS]
        if alias != NO_NODE:
            self.print_child(alias)
            self.write(": ")
        self.one(kids, Role.NAME)
        if kids.has(Role.ARGUMENT):
            self.field_arguments(kids, line_start)
        self.spaced_directives(kids)
        self.spaced_one(kids, Role.SELECTION_SET, " ")

    @inline(.never)
    def field_arguments(self, kids: _Kids, line_start: Int):
        """Print a field's arguments, on one line when it fits."""
        var arguments_start = len(self.s[].out)
        # graphql-js measures the line before an enclosing block indents it.
        var level = self.s[].level
        self.s[].level = 0
        self.wrapped(kids, Role.ARGUMENT, "(", ", ", ")")
        self.s[].level = level
        var line = Span(self.s[].out)[line_start : len(self.s[].out)]
        if utf16_count(line) > MAX_LINE_LENGTH:
            self.cut(arguments_start)
            self.lines_in_parentheses(kids, Role.ARGUMENT, True)
        elif level > 0 and self.has_line_feed(arguments_start):
            self.cut(arguments_start)
            self.wrapped(kids, Role.ARGUMENT, "(", ", ", ")")

    def field_definition(self, node: Int):
        """Print a field definition."""
        var kids = self.kids(node)
        self.description(kids)
        self.one(kids, Role.NAME)
        self.argument_definitions(kids)
        self.write(": ")
        self.one(kids, Role.TYPE)
        self.spaced_directives(kids)

    def input_value_definition(self, node: Int):
        """Print an argument or input field definition."""
        var kids = self.kids(node)
        self.description(kids)
        self.one(kids, Role.NAME)
        self.write(": ")
        self.one(kids, Role.TYPE)
        self.spaced_one(kids, Role.DEFAULT_VALUE, " = ")
        self.spaced_directives(kids)

    @inline(.never)
    def string(self, node: Int):
        """Print a string or a block string from its decoded value."""
        ref found = self.nodes[unsafe_offset=node]
        var start = Int(found.start)
        var end = Int(found.end)
        var block = found.flags & FLAG_BLOCK != 0
        if found.flags & FLAG_EXTRA == 0:
            if block:
                if self.block_from_source(start, end):
                    return
            elif find_string_escape(self.data(), start + 1, end - 1) == end - 1:
                # No escape in the source and none to add: graphql-js
                # prints the same characters between the same quotes.
                self.put(self.bytes.unsafe_offset(start), end - start)
                return
        self.s[].value.clear()
        if found.flags & FLAG_EXTRA != 0:
            self.s[].value.extend(
                _span(self.bytes.unsafe_offset(start), end - start)
            )
        elif block:
            block_string_value_into(self.data(), start, end, self.s[].value)
        else:
            string_value_into(self.data(), start, end, self.s[].value)
        if not block:
            append_string_literal(self.s[].out, Span(self.s[].value))
            return
        var layout = block_string_layout(Span(self.s[].value))
        self.write('"""')
        if layout.leading_newline:
            self.newline()
        _write_block_value(self.s[].out, self.s[].level, Span(self.s[].value))
        if layout.trailing_newline:
            self.newline()
        self.write('"""')

    def block_from_source(self, start: Int, end: Int) -> Bool:
        """Print a block string that has no backslash straight from its
        source lines, as graphql-js `printBlockString(value)` would.

        Without a backslash the value is the source's lines, dedented and
        joined, with nothing to unescape or escape: no `\"\"\"` can be in
        it. One pass reads the lines and decides the layout; a second
        writes them.

        Returns:
            False, printing nothing, when the source has a backslash.
        """
        var data = self.data()
        var bytes = data.unsafe_ptr()
        var first = start + 3
        var stop = end - 3
        var common_indent = Int.MAX
        # The least indent of a non-blank line after the first kept line.
        var later_indent = Int.MAX
        var first_line = -1
        var last_line = -1
        var first_start = 0
        var first_end = 0
        var first_indent = 0
        var last_end = 0
        var line = 0
        var position = first
        while position <= stop:
            var line_end = find_byte4(
                data, position, stop, 0x0A, 0x0D, 0x5C, 0x0A
            )
            if line_end < stop and bytes[unsafe_offset=line_end] == 0x5C:
                return False
            var indent = 0
            while position + indent < line_end and (
                bytes[unsafe_offset=position + indent] == 0x20
                or bytes[unsafe_offset=position + indent] == 0x09
            ):
                indent += 1
            if position + indent < line_end:
                if first_line < 0:
                    first_line = line
                    first_start = position
                    first_end = line_end
                    first_indent = indent
                elif indent < later_indent:
                    # Line 0 is never a later line: it is the first kept
                    # line when it is not blank.
                    later_indent = indent
                last_line = line
                last_end = line_end
                if line != 0 and indent < common_indent:
                    common_indent = indent
            position = _after_break(data, line_end, stop)
            line += 1
        if first_line < 0:
            self.write('""""""')
            return True
        if common_indent == Int.MAX:
            common_indent = 0
        # The layout of graphql-js `printBlockString`, from the kept lines.
        var single = first_line == last_line
        var from_ = first_start
        if first_line != 0:
            from_ = first_start + min(common_indent, first_indent)
        var first_byte = bytes[unsafe_offset=from_]
        var units = 0
        if single:
            units = count_utf16(data, from_, first_end)
        # A later line starts with white space after the dedent exactly
        # when its indent is more than the common one.
        var later_indented = (
            later_indent == Int.MAX or later_indent > common_indent
        )
        var force_leading = not single and later_indented
        var trailing_quote = bytes[unsafe_offset=last_end - 1] == 0x22
        var multiple = (
            not single or units > 70 or trailing_quote or force_leading
        )
        var skip_leading = single and (first_byte == 0x20 or first_byte == 0x09)
        self.write('"""')
        # A forced leading line break needs more than one line, so it is
        # one of the multiple-line cases.
        if multiple and not skip_leading:
            self.newline()
        line = first_line
        position = first_start
        while line <= last_line:
            var line_end = find_byte2(data, position, stop, 0x0A, 0x0D)
            if line > first_line:
                self.newline()
            var begin = position
            if line != 0:
                begin = min(position + common_indent, line_end)
            self.put(bytes.unsafe_offset(begin), line_end - begin)
            position = _after_break(data, line_end, stop)
            line += 1
        # A trailing quote forces the multiple-line layout.
        if multiple:
            self.newline()
        self.write('"""')
        return True

    def value_literal(self, node: Int, kind: Kind):
        """Print a variable, a boolean, null, a list or an object."""
        if kind == Kind.BOOLEAN:
            if self.flags(node) & FLAG_TRUE != 0:
                self.write("true")
            else:
                self.write("false")
            return
        if kind == Kind.NULL:
            self.write("null")
            return
        var kids = self.kids(node)
        if kind == Kind.VARIABLE:
            self.write("$")
            self.one(kids, Role.NAME)
        elif kind == Kind.LIST:
            self.write("[")
            self.join(kids, Role.LIST_ITEM, ", ")
            self.write("]")
        else:
            self.write("{")
            self.join(kids, Role.FIELD, ", ")
            self.write("}")

    @inline(.never)
    def executable(self, node: Int, kind: Kind):
        """Print a document, an operation or a fragment definition."""
        var kids = self.kids(node)
        if kind == Kind.DOCUMENT:
            self.join(kids, Role.DEFINITION, "\n\n")
        elif kind == Kind.OPERATION_DEFINITION:
            var start = len(self.s[].out)
            self.description(kids)
            self.write(OperationType(self.flags(node) & 3).text())
            var mark = len(self.s[].out)
            self.write(" ")
            var body = len(self.s[].out)
            self.one(kids, Role.NAME)
            self.variable_definitions(kids)
            self.drop_if_empty(mark, body)
            self.spaced_directives(kids)
            if (
                Span(self.s[].out)[start : len(self.s[].out)]
                == "query".as_bytes()
            ):
                self.cut(start)
            else:
                self.write(" ")
            self.one(kids, Role.SELECTION_SET)
        else:
            self.description(kids)
            self.write("fragment ")
            self.one(kids, Role.NAME)
            self.wrapped(kids, Role.VARIABLE_DEFINITION, "(", ", ", ")")
            self.write(" on ")
            self.one(kids, Role.TYPE_CONDITION)
            self.write(" ")
            var mark = len(self.s[].out)
            self.join(kids, Role.DIRECTIVE, " ")
            if len(self.s[].out) != mark:
                self.write(" ")
            self.one(kids, Role.SELECTION_SET)

    def variable_definitions(self, kids: _Kids):
        """Print an operation's variables, one per line if any spans lines."""
        if not kids.has(Role.VARIABLE_DEFINITION):
            return
        var start = len(self.s[].out)
        self.wrapped(kids, Role.VARIABLE_DEFINITION, "(", ", ", ")")
        if self.has_line_feed(start):
            self.cut(start)
            self.lines_in_parentheses(kids, Role.VARIABLE_DEFINITION, False)

    def selection_part(self, node: Int, kind: Kind):
        """Print a fragment spread, an inline fragment, a variable
        definition or a directive."""
        var kids = self.kids(node)
        if kind == Kind.FRAGMENT_SPREAD:
            self.write("...")
            self.one(kids, Role.NAME)
            self.spaced_directives(kids)
        elif kind == Kind.INLINE_FRAGMENT:
            self.write("...")
            self.spaced_one(kids, Role.TYPE_CONDITION, " on ")
            self.spaced_directives(kids)
            self.spaced_one(kids, Role.SELECTION_SET, " ")
        elif kind == Kind.VARIABLE_DEFINITION:
            self.description(kids)
            self.one(kids, Role.VARIABLE)
            self.write(": ")
            self.one(kids, Role.TYPE)
            self.spaced_one(kids, Role.DEFAULT_VALUE, " = ")
            self.spaced_directives(kids)
        else:
            self.write("@")
            self.one(kids, Role.NAME)
            self.wrapped(kids, Role.ARGUMENT, "(", ", ", ")")

    @inline(.never)
    def coordinate(self, node: Int, kind: Kind):
        """Print a schema coordinate."""
        var kids = self.kids(node)
        if (
            kind == Kind.DIRECTIVE_COORDINATE
            or kind == Kind.DIRECTIVE_ARGUMENT_COORDINATE
        ):
            self.write("@")
        self.one(kids, Role.NAME)
        self.spaced_one(kids, Role.MEMBER_NAME, ".")
        self.spaced_one(kids, Role.FIELD_NAME, ".")
        var argument = kids[Role.ARGUMENT_NAME]
        if argument != NO_NODE:
            self.write("(")
            self.print_child(argument)
            self.write(":)")

    @inline(.never)
    def type_system(self, node: Int, kind: Kind):
        """Print a schema, type or directive definition or extension."""
        var kids = self.kids(node)
        if kind == Kind.ENUM_VALUE_DEFINITION:
            self.description(kids)
            self.one(kids, Role.NAME)
            self.spaced_directives(kids)
        elif kind == Kind.OPERATION_TYPE_DEFINITION:
            self.write(OperationType(self.flags(node) & 3).text())
            self.write(": ")
            self.one(kids, Role.TYPE)
        elif kind == Kind.SCHEMA_DEFINITION:
            self.description(kids)
            self.write("schema")
            self.spaced_directives(kids)
            self.spaced_block(kids, Role.OPERATION_TYPE)
        elif kind == Kind.SCHEMA_EXTENSION:
            self.write("extend schema")
            self.spaced_directives(kids)
            self.spaced_block(kids, Role.OPERATION_TYPE)
        elif kind == Kind.DIRECTIVE_DEFINITION:
            self.description(kids)
            self.write("directive @")
            self.one(kids, Role.NAME)
            self.argument_definitions(kids)
            self.spaced_directives(kids)
            if self.flags(node) & FLAG_REPEATABLE != 0:
                self.write(" repeatable")
            self.write(" on ")
            self.join(kids, Role.LOCATION, " | ")
        elif kind == Kind.DIRECTIVE_EXTENSION:
            self.write("extend directive @")
            self.one(kids, Role.NAME)
            self.spaced_directives(kids)
        elif kind.is_type_definition() or kind.is_type_extension():
            self.named_type_definition(kids, kind)
        # A node of an invalid kind prints as nothing.

    def named_type_definition(self, kids: _Kids, kind: Kind):
        """Print a scalar, object, interface, union, enum or input type,
        or an extension of one."""
        self.description(kids)
        if (
            kind == Kind.SCALAR_TYPE_DEFINITION
            or kind == Kind.SCALAR_TYPE_EXTENSION
        ):
            self.keyword(kind, "scalar")
        elif (
            kind == Kind.OBJECT_TYPE_DEFINITION
            or kind == Kind.OBJECT_TYPE_EXTENSION
        ):
            self.keyword(kind, "type")
        elif (
            kind == Kind.INTERFACE_TYPE_DEFINITION
            or kind == Kind.INTERFACE_TYPE_EXTENSION
        ):
            self.keyword(kind, "interface")
        elif (
            kind == Kind.UNION_TYPE_DEFINITION
            or kind == Kind.UNION_TYPE_EXTENSION
        ):
            self.keyword(kind, "union")
        elif (
            kind == Kind.ENUM_TYPE_DEFINITION
            or kind == Kind.ENUM_TYPE_EXTENSION
        ):
            self.keyword(kind, "enum")
        else:
            self.keyword(kind, "input")
        self.spaced_one(kids, Role.NAME, " ")
        self.spaced_join(kids, Role.INTERFACE, " implements ", " & ")
        self.spaced_directives(kids)
        self.spaced_join(kids, Role.MEMBER_TYPE, " = ", " | ")
        self.spaced_block(kids, Role.FIELD)
        self.spaced_block(kids, Role.ENUM_VALUE)


def print_ast(document: Document) -> String:
    """Print a document's root node, as graphql-js `print`.

    Args:
        document: The document.

    Returns:
        The GraphQL text.
    """
    return print_node(document, document.root)


def print_node(document: Document, node: Int) -> String:
    """Print one node and its descendants, as graphql-js `print`.

    Args:
        document: The document that holds the node.
        node: The node's index.

    Returns:
        The GraphQL text of the node, or empty for an invalid kind.
    """
    var state = _State(document.source.length * 2 + 64)
    var printer = _Printer(
        document.nodes.unsafe_ptr().unsafe_origin_cast[
            UntrackedOrigin[mut=False]
        ](),
        document.source.bytes.unsafe_ptr().unsafe_origin_cast[
            UntrackedOrigin[mut=False]
        ](),
        len(document.source.bytes),
        Pointer(to=state).unsafe_origin_cast[UntrackedOrigin[mut=True]](),
    )
    printer.node(node)
    # The bytes are UTF-8 by construction; this copy skips the check that
    # `String(unsafe_from_utf8=...)` makes.
    var size = len(state.out)
    var text = String(unsafe_uninit_length=size)
    unsafe_memcpy(
        dest=text.unsafe_ptr_mut(), src=state.out.unsafe_ptr(), count=size
    )
    return text^
