# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The graphql-go-tools printer for executable documents.

A port of `v2/pkg/astprinter` (`astprinter.go`) of graphql-go-tools v2 at
9ef6e24, for operations and fragments. `print_compact` gives the bytes of
`astprinter.Print`, and `print_indent` gives the bytes of
`astprinter.PrintIndent`. The two forms are not the forms of the
graphql-js printer in `gql_language.printer`: the compact form writes
`query Q($a: Int){a b}`, and the indented form puts one selection on each
line.

Differences from upstream:

- Only executable definitions print. A type system definition raises an
  error. The minifier and the normalizer print operations only.
- A description of an operation or a variable is not printed.
  `gql_language` does not parse those descriptions.
- `InlineFragmentIsOfTheSameType` is always false, because only the
  normalizer of upstream sets it. A type condition always prints.
"""

from gql_language.ast import (
    Document,
    FLAG_BLOCK,
    FLAG_EXTRA,
    Kind,
    NO_NODE,
    OperationType,
    Role,
    role_bit,
)


def print_compact(document: Document) raises -> String:
    """Print a document as graphql-go-tools `astprinter.Print`.

    Args:
        document: An executable document.

    Returns:
        The compact text, such as `query Q {a b {c}}`.

    Raises:
        Error: If the document has a type system definition.
    """
    var printer = GoPrinter(String(""))
    printer.document(document)
    return printer^.take()


def print_indent(document: Document, indent: StringSlice) raises -> String:
    """Print a document as graphql-go-tools `astprinter.PrintIndent`.

    Args:
        document: An executable document.
        indent: The text of one level of indentation, such as four spaces.

    Returns:
        The text with one selection on each line.

    Raises:
        Error: If the document has a type system definition.
    """
    var printer = GoPrinter(String(indent))
    printer.document(document)
    return printer^.take()


struct GoPrinter(Movable):
    """The state of one graphql-go-tools print: the output and the indent.

    The minifier uses the parts directly: `selection_set` prints one
    selection set, and `spans` records where each selection set starts and
    ends in the output.
    """

    var out: String
    """The text printed so far."""
    var indent: String
    """One level of indentation; empty for the compact form."""
    var pretty: Bool
    """True when `indent` is not empty, as upstream `indent != nil`."""
    var record: Bool
    """True to record the span of each selection set in `spans`."""
    var spans: List[Int]
    """Triples of a selection set node, its start and its end in `out`, in
    the order that the sets start."""

    def __init__(out self, var indent: String):
        """Start a print.

        Args:
            indent: One level of indentation; empty for the compact form.
        """
        self.pretty = indent.byte_length() > 0
        self.indent = indent^
        self.out = String("")
        self.record = False
        self.spans = List[Int]()

    def take(deinit self) -> String:
        """End the print and return its text.

        Returns:
            The text printed.
        """
        return self.out^

    def _indented(mut self, depth: Int, text: StringSlice):
        """Write the indentation of a depth, then some text."""
        if self.pretty:
            for _ in range(depth):
                self.out += self.indent
        self.out += text

    def _newline_or_space(mut self):
        """Write a line break in the indented form, else a space."""
        if self.pretty:
            self.out += "\n"
        else:
            self.out += " "

    def document(mut self, doc: Document) raises:
        """Print every definition of a document.

        Args:
            doc: An executable document.

        Raises:
            Error: If the document has a type system definition.
        """
        var current = doc.first_child(doc.root)
        while current != NO_NODE:
            var kind = doc.kind(current)
            if kind == Kind.OPERATION_DEFINITION:
                self.operation(doc, current)
            elif kind == Kind.FRAGMENT_DEFINITION:
                self.fragment_definition(doc, current)
            else:
                raise Error(
                    "go_printer: only executable definitions print, not ",
                    kind,
                )
            current = doc.next_sibling(current)
            if current != NO_NODE:
                if self.pretty:
                    self.out += "\n\n"
                else:
                    self.out += " "

    def operation(mut self, doc: Document, node: Int):
        """Print an operation definition.

        Args:
            doc: The document.
            node: The `OperationDefinition` node.
        """
        var name = doc.child(node, Role.NAME)
        var has_variables = doc.child(node, Role.VARIABLE_DEFINITION) != NO_NODE
        var operation = doc.operation(node)
        if operation == OperationType.QUERY:
            if name != NO_NODE or has_variables:
                self.out += "query"
        elif operation == OperationType.MUTATION:
            self.out += "mutation"
        else:
            self.out += "subscription"
        if name != NO_NODE:
            self.out += " "
            self.out += doc.text(name)
            if not has_variables:
                self.out += " "
        var selection_set = NO_NODE
        var first_variable = True
        var current = doc.first_child(node)
        while current != NO_NODE:
            var role = doc.role(current)
            if role == Role.VARIABLE_DEFINITION:
                self.variable_definition(doc, current, first_variable)
                first_variable = False
            elif role == Role.DIRECTIVE:
                self.directive(doc, current)
                # LeaveDirective of an operation writes a space after each.
                self.out += " "
            elif role == Role.SELECTION_SET:
                selection_set = current
            current = doc.next_sibling(current)
        self.selection_set(doc, selection_set, 0)

    def variable_definition(mut self, doc: Document, node: Int, first: Bool):
        """Print a variable definition, with its parenthesis or comma.

        Args:
            doc: The document.
            node: The `VariableDefinition` node.
            first: True for the first definition of the operation.
        """
        var last = doc.next_with_role(node) == NO_NODE
        if first:
            self.out += "("
        var has_directives = False
        var current = doc.first_child(node)
        while current != NO_NODE:
            var role = doc.role(current)
            var following = doc.next_sibling(current)
            if role == Role.VARIABLE:
                self.value(doc, current)
                self.out += ": "
            elif role == Role.TYPE:
                self.type(doc, current)
            elif role == Role.DEFAULT_VALUE:
                self.out += " = "
                self.value(doc, current)
            else:
                if not has_directives:
                    self.out += " "
                    has_directives = True
                self.directive(doc, current)
                if _not_role(doc, following, Role.DIRECTIVE):
                    if last:
                        self.out += " "
                else:
                    self.out += " "
            current = following
        if last:
            self.out += ")"
        else:
            self.out += ", "

    def directive(mut self, doc: Document, node: Int):
        """Print a directive: `@name` and its arguments.

        Args:
            doc: The document.
            node: The `Directive` node.
        """
        self.out += "@"
        self.out += doc.name(node)
        self.arguments(doc, node)

    def arguments(mut self, doc: Document, node: Int):
        """Print the arguments of a field or a directive, if it has some.

        Args:
            doc: The document.
            node: The `Field` or `Directive` node.
        """
        var first = True
        var current = doc.first_child(node)
        while current != NO_NODE:
            if doc.role(current) == Role.ARGUMENT:
                if first:
                    self.out += "("
                    first = False
                else:
                    self.out += ", "
                self.out += doc.name(current)
                self.out += ": "
                self.value(doc, doc.child(current, Role.VALUE))
            current = doc.next_sibling(current)
        if not first:
            self.out += ")"

    def selection_set(mut self, doc: Document, node: Int, depth: Int):
        """Print a selection set.

        Args:
            doc: The document.
            node: The `SelectionSet` node.
            depth: The number of selection sets around it.
        """
        var slot = len(self.spans)
        if self.record:
            self.spans.append(node)
            self.spans.append(self.out.byte_length())
            self.spans.append(0)
        self.out += "{"
        if self.pretty:
            self.out += "\n"
        var current = doc.first_child(node)
        while current != NO_NODE:
            var following = doc.next_sibling(current)
            var after = following != NO_NODE
            var kind = doc.kind(current)
            if kind == Kind.FIELD:
                self.field(doc, current, depth + 1, after)
            elif kind == Kind.FRAGMENT_SPREAD:
                self.fragment_spread(doc, current, depth + 1, after)
            else:
                self.inline_fragment(doc, current, depth + 1, after)
            current = following
        if self.pretty:
            self.out += "\n"
        self._indented(depth, "}")
        if self.record:
            self.spans[slot + 2] = self.out.byte_length()

    def field(mut self, doc: Document, node: Int, depth: Int, after: Bool):
        """Print a field.

        Args:
            doc: The document.
            node: The `Field` node.
            depth: The number of selection sets around it.
            after: True when a selection follows it.
        """
        var bits = doc.nodes[node].roles
        var has_alias = bits & role_bit(Role.ALIAS) != 0
        var has_arguments = bits & role_bit(Role.ARGUMENT) != 0
        var has_directives = bits & role_bit(Role.DIRECTIVE) != 0
        var has_selections = bits & role_bit(Role.SELECTION_SET) != 0
        var current = doc.first_child(node)
        while current != NO_NODE:
            var role = doc.role(current)
            var following = doc.next_sibling(current)
            if role == Role.ALIAS:
                self._indented(depth, doc.text(current))
                self.out += ": "
            elif role == Role.NAME:
                if has_alias:
                    self.out += doc.text(current)
                else:
                    self._indented(depth, doc.text(current))
                if not has_arguments and (has_selections or has_directives):
                    self.out += " "
                self.arguments(doc, node)
            elif role == Role.DIRECTIVE:
                self.directive(doc, current)
                if _not_role(doc, following, Role.DIRECTIVE):
                    if has_selections:
                        self.out += " "
                    elif after:
                        self._newline_or_space()
                else:
                    self.out += " "
            elif role == Role.SELECTION_SET:
                self.selection_set(doc, current, depth)
            current = following
        if after and (has_selections or not has_directives):
            self._newline_or_space()

    def fragment_spread(
        mut self, doc: Document, node: Int, depth: Int, after: Bool
    ):
        """Print a fragment spread.

        Args:
            doc: The document.
            node: The `FragmentSpread` node.
            depth: The number of selection sets around it.
            after: True when a selection follows it.
        """
        self._indented(depth, "...")
        self.out += doc.name(node)
        var directive = doc.child(node, Role.DIRECTIVE)
        if directive != NO_NODE:
            self.out += " "
        while directive != NO_NODE:
            self.directive(doc, directive)
            var following = doc.next_with_role(directive)
            if following != NO_NODE or (after and not self.pretty):
                self.out += " "
            directive = following
        if after:
            self._newline_or_space()

    def inline_fragment(
        mut self, doc: Document, node: Int, depth: Int, after: Bool
    ):
        """Print an inline fragment.

        Args:
            doc: The document.
            node: The `InlineFragment` node.
            depth: The number of selection sets around it.
            after: True when a selection follows it.
        """
        self._indented(depth, "...")
        var bits = doc.nodes[node].roles
        var has_directives = bits & role_bit(Role.DIRECTIVE) != 0
        var current = doc.first_child(node)
        if bits & role_bit(Role.TYPE_CONDITION) == 0 and has_directives:
            self.out += " "
        while current != NO_NODE:
            var role = doc.role(current)
            var following = doc.next_sibling(current)
            if role == Role.TYPE_CONDITION:
                self.out += " on "
                self.out += doc.name(current)
                self.out += " "
            elif role == Role.DIRECTIVE:
                self.directive(doc, current)
                if (
                    not _not_role(doc, following, Role.DIRECTIVE)
                    or after
                    or self.pretty
                ):
                    self.out += " "
            else:
                self.selection_set(doc, current, depth)
            current = following
        if after:
            self._newline_or_space()

    def fragment_definition(mut self, doc: Document, node: Int):
        """Print a fragment definition.

        Args:
            doc: The document.
            node: The `FragmentDefinition` node.
        """
        self.out += "fragment "
        self.out += doc.name(node)
        var current = doc.first_child(node)
        while current != NO_NODE:
            var role = doc.role(current)
            if role == Role.TYPE_CONDITION:
                self.out += " on "
                self.out += doc.name(current)
                self.out += " "
            elif role == Role.DIRECTIVE:
                self.directive(doc, current)
                self.out += " "
            elif role == Role.SELECTION_SET:
                self.selection_set(doc, current, 0)
            current = doc.next_sibling(current)

    def value(mut self, doc: Document, node: Int):
        """Print a value as upstream `Document.PrintValue`.

        Args:
            doc: The document.
            node: The value node.
        """
        var kind = doc.kind(node)
        if kind == Kind.VARIABLE:
            self.out += "$"
            self.out += doc.name(node)
        elif kind == Kind.STRING:
            var flags = doc.nodes[node].flags
            if flags & FLAG_EXTRA == 0:
                # The source text: the quotes and the raw content.
                self.out += doc.text(node)
            else:
                var quote = '"""' if flags & FLAG_BLOCK != 0 else '"'
                self.out += quote
                self.out += doc.text(node)
                self.out += quote
        elif kind == Kind.BOOLEAN:
            if doc.boolean_value(node):
                self.out += "true"
            else:
                self.out += "false"
        elif kind == Kind.NULL:
            self.out += "null"
        elif kind == Kind.LIST:
            self.out += "["
            var item = doc.first_child(node)
            while item != NO_NODE:
                self.value(doc, item)
                item = doc.next_sibling(item)
                if item != NO_NODE:
                    self.out += ","
            self.out += "]"
        elif kind == Kind.OBJECT:
            self.out += "{"
            var field = doc.first_child(node)
            while field != NO_NODE:
                self.out += doc.name(field)
                self.out += ": "
                self.value(doc, doc.child(field, Role.VALUE))
                field = doc.next_sibling(field)
                if field != NO_NODE:
                    self.out += ","
            self.out += "}"
        else:
            # An Int, a Float or an Enum value: its source text.
            self.out += doc.text(node)

    def type(mut self, doc: Document, node: Int):
        """Print a type reference as upstream `Document.PrintType`.

        Args:
            doc: The document.
            node: A `NamedType`, `ListType` or `NonNullType` node.
        """
        var kind = doc.kind(node)
        if kind == Kind.NAMED_TYPE:
            self.out += doc.name(node)
        elif kind == Kind.LIST_TYPE:
            self.out += "["
            self.type(doc, doc.child(node, Role.TYPE))
            self.out += "]"
        else:
            self.type(doc, doc.child(node, Role.TYPE))
            self.out += "!"


@always_inline
def _not_role(doc: Document, node: Int, role: Role) -> Bool:
    """Return True if a node is absent or does not fill a role."""
    return node == NO_NODE or doc.role(node) != role
