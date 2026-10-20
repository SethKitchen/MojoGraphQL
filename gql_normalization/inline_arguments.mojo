# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Inline arguments validation: graphql-go-tools v2
`astnormalization/inline_arguments.go`, `WithInlineArgumentsValidation`.

An inline argument is an argument whose value is a literal, not a
variable. Upstream registers the visitor on the walker of the first stage,
with `directiveIncludeSkip`. `find_inline_arguments` makes the same visits
in the same order:

- The walker walks a selection that `@skip` or `@include` removes, to its
  end, so the arguments under it are found.
- When a walk changes the selections of a selection set, the walker
  starts the set again. A selection before the change is walked twice, and
  its arguments are found twice.
- The walker reads a directive list while the visitor removes a directive
  from it, so it skips the directive after a removed one, and reads the
  last directive again.

The function does not edit the document. It keeps the removals of the
first stage aside, and `directive_include_skip` makes them afterwards.

Differences from upstream:

- With `enforce`, the first inline argument raises an `Error` with
  `error_message`. The code and the status are in the options of the
  caller. Upstream adds an `ExternalError` with them to the report.
- The walk does not check the types. Upstream stops at an inline fragment
  with an unknown type condition.
- `Position` is a `SourceLocation`, with the column in UTF-16 code units.
"""

from std.collections import Dict

from gql_language.ast import Document, Kind, NO_NODE, OperationType, Role
from gql_language.source import SourceLocation

from gql_normalization.selections import directive_condition

comptime _PLACEHOLDER = -2
"""The `__typename` placeholder that the first stage adds to a selection
set that it empties. It has no arguments."""


@fieldwise_init
struct InlineArgument(Copyable, ImplicitlyCopyable, Movable):
    """One argument with a literal value: upstream `InlineArgument`."""

    var argument_name: String
    """The argument name: `ArgumentName`."""
    var ancestor_name: String
    """The name of the field or the directive: `AncestorName`."""
    var ancestor_kind: Kind
    """`Kind.FIELD` or `Kind.DIRECTIVE`: `AncestorKind`."""
    var path: String
    """The dotted path of the walker: `Path`."""
    var value_kind: Kind
    """The kind of the literal: `ValueKind`."""
    var position: SourceLocation
    """Where the argument starts: `Position`."""

    def qualified_name(self) -> String:
        """Return the argument with its path: `QualifiedName`.

        Returns:
            `path#argument` for a field, `path@directive#argument` for a
            directive.
        """
        if self.ancestor_kind == Kind.FIELD:
            return self.path + "#" + self.argument_name
        return self.path + "@" + self.ancestor_name + "#" + self.argument_name


@fieldwise_init
struct InlineArgumentsValidationOptions(Copyable, ImplicitlyCopyable, Movable):
    """The options of inline arguments validation: upstream
    `InlineArgumentsValidationOptions`."""

    var enforce: Bool
    """Raise at the first inline argument: `Enforce`."""
    var error_message: String
    """The message of the error: `ErrorMessage`."""
    var error_code: String
    """The extension code of the error: `ErrorCode`."""
    var status_code: Int
    """The HTTP status of the error: `StatusCode`."""


struct NormalizationResult(Copyable, Movable):
    """The findings of one normalization: upstream `NormalizationResult`."""

    var inline_arguments: List[InlineArgument]
    """The inline arguments, in walk order: `InlineArguments`."""

    def __init__(out self):
        """Make an empty result."""
        self.inline_arguments = List[InlineArgument]()


@fieldwise_init
struct RunOptions(Copyable, ImplicitlyCopyable, Movable):
    """The options of one normalization: upstream `RunOptions`."""

    var skip_inline_arguments: Bool
    """Find and enforce nothing for this operation:
    `SkipInlineArguments`."""

    def __init__(out self):
        """Make the options of `RunOptions{}`."""
        self.skip_inline_arguments = False


struct _Directives(Copyable, Movable):
    """A Go slice of directives and its backing array, which a removal
    shifts in place: `deleteRef`."""

    var backing: List[Int]
    var length: Int

    def __init__(out self, var backing: List[Int]):
        self.length = len(backing)
        self.backing = backing^

    def remove(mut self, directive: Int):
        """Remove a directive, as `indexOf` and `deleteRef` do."""
        var index = 0
        while index < self.length:
            if self.backing[index] == directive:
                var move = index
                while move < self.length - 1:
                    self.backing[move] = self.backing[move + 1]
                    move += 1
                self.length -= 1
                return
            index += 1


def _children(document: Document, node: Int, role: Role) -> List[Int]:
    """Return the children of a node with a role, in order."""
    var out = List[Int]()
    var child = document.child(node, role)
    while child != NO_NODE:
        out.append(child)
        child = document.next_with_role(child)
    return out^


def _number_inline_fragments(
    document: Document, node: Int, mut refs: Dict[Int, Int]
):
    """Number the inline fragments under a node after their selections, as
    the parser of upstream appends them to `InlineFragments`."""
    # A post-order walk: the reverse of a pre-order walk that visits the
    # last child first.
    var stack: List[Int] = [node]
    var order = List[Int]()
    while len(stack) > 0:
        var current = stack.pop()
        order.append(current)
        var child = document.first_child(current)
        while child != NO_NODE:
            stack.append(child)
            child = document.next_sibling(child)
    var index = len(order)
    while index > 0:
        index -= 1
        if document.kind(order[index]) == Kind.INLINE_FRAGMENT:
            refs[order[index]] = len(refs)


struct _Walk(Movable):
    """The state of the walk: the removals of the first stage, kept aside,
    and the path of the walker."""

    var keep_nodes: Bool
    var options: InlineArgumentsValidationOptions
    var directives: Dict[Int, _Directives]
    var selections: Dict[Int, List[Int]]
    var path: List[String]
    var inline_refs: Dict[Int, Int]
    var found: List[InlineArgument]

    def __init__(
        out self,
        document: Document,
        keep_nodes: Bool,
        options: InlineArgumentsValidationOptions,
    ):
        self.keep_nodes = keep_nodes
        self.options = options
        self.directives = Dict[Int, _Directives]()
        self.selections = Dict[Int, List[Int]]()
        self.path = List[String]()
        self.inline_refs = Dict[Int, Int]()
        _number_inline_fragments(document, document.root, self.inline_refs)
        self.found = List[InlineArgument]()

    def path_text(self) -> String:
        """Return the path as `DotDelimitedString` writes it."""
        var out = self.path[0]
        var index = 1
        while index < len(self.path):
            out += "."
            out += self.path[index]
            index += 1
        return out^

    def argument(
        mut self,
        document: Document,
        argument: Int,
        ancestor: Kind,
        ancestor_name: StringSlice,
    ) raises:
        """Visit an argument: `EnterArgument`."""
        var value_kind = document.kind(document.child(argument, Role.VALUE))
        if value_kind == Kind.VARIABLE:
            return
        if self.options.enforce:
            raise Error(self.options.error_message)
        self.found.append(
            InlineArgument(
                String(document.name(argument)),
                String(ancestor_name),
                ancestor,
                self.path_text(),
                value_kind,
                document.location(argument),
            )
        )

    def arguments(
        mut self, document: Document, node: Int, ancestor: Kind
    ) raises:
        """Visit the arguments of a field or a directive."""
        var name = document.name(node)
        var argument = document.child(node, Role.ARGUMENT)
        while argument != NO_NODE:
            self.argument(document, argument, ancestor, name)
            argument = document.next_with_role(argument)

    def remove_selection(mut self, selection_set: Int, node: Int) raises:
        """Remove a selection, and add the placeholder to an empty set:
        `removeParentNode`."""
        ref live = self.selections[selection_set]
        var index = 0
        while index < len(live):
            if live[index] == node:
                _ = live.pop(index)
                if len(live) == 0:
                    live.append(_PLACEHOLDER)
                return
            index += 1

    def directive(
        mut self,
        document: Document,
        variables: String,
        directive: Int,
        node: Int,
        selection_set: Int,
        removable: Bool,
    ) raises:
        """Visit a directive and its arguments: `EnterDirective` of
        `directiveIncludeSkipVisitor`, then the arguments."""
        var name = document.name(directive)
        var is_skip = name == "skip"
        if is_skip or name == "include":
            var condition = directive_condition(document, variables, directive)
            if condition[1]:
                var drop = condition[0] if is_skip else not condition[0]
                if self.keep_nodes or not drop:
                    if removable:
                        self.directives[node].remove(directive)
                elif selection_set != NO_NODE:
                    self.remove_selection(selection_set, node)
        self.arguments(document, directive, Kind.DIRECTIVE)

    def directive_list(
        mut self,
        document: Document,
        variables: String,
        node: Int,
        selection_set: Int,
        removable: Bool,
    ) raises:
        """Visit the directives of a node as the walker ranges over them."""
        if node not in self.directives:
            self.directives[node] = _Directives(
                _children(document, node, Role.DIRECTIVE)
            )
        var count = self.directives[node].length
        var index = 0
        while index < count:
            var directive = self.directives[node].backing[index]
            self.directive(
                document, variables, directive, node, selection_set, removable
            )
            index += 1

    def selection_set(
        mut self, document: Document, variables: String, node: Int
    ) raises:
        """Walk a selection set, and start it again when a walk changes its
        selections, as the walker does."""
        if node not in self.selections:
            self.selections[node] = _children(document, node, Role.SELECTION)
        while True:
            var refs = self.selections[node].copy()
            var changed = False
            var index = 0
            while index < len(refs):
                self.selection(document, variables, refs[index], node)
                if self.selections[node] != refs:
                    changed = True
                    break
                index += 1
            if not changed:
                return

    def selection(
        mut self,
        document: Document,
        variables: String,
        node: Int,
        selection_set: Int,
    ) raises:
        """Walk a field, a fragment spread or an inline fragment."""
        if node == _PLACEHOLDER:
            return
        var kind = document.kind(node)
        if kind == Kind.FIELD:
            var alias = document.child(node, Role.ALIAS)
            if alias == NO_NODE:
                self.path.append(String(document.name(node)))
            else:
                self.path.append(String(document.text(alias)))
            self.arguments(document, node, Kind.FIELD)
            self.directive_list(document, variables, node, selection_set, True)
            var inner = document.child(node, Role.SELECTION_SET)
            if inner != NO_NODE:
                self.selection_set(document, variables, inner)
            _ = self.path.pop()
        elif kind == Kind.FRAGMENT_SPREAD:
            self.directive_list(document, variables, node, selection_set, True)
        else:
            var condition = document.child(node, Role.TYPE_CONDITION)
            if condition != NO_NODE:
                var item = String("$")
                item += String(self.inline_refs[node])
                item += document.name(condition)
                self.path.append(item^)
            self.directive_list(document, variables, node, selection_set, True)
            self.selection_set(
                document, variables, document.child(node, Role.SELECTION_SET)
            )
            if condition != NO_NODE:
                _ = self.path.pop()

    def definition(
        mut self, document: Document, variables: String, node: Int
    ) raises:
        """Walk an operation or a fragment definition."""
        var kind = document.kind(node)
        if kind == Kind.OPERATION_DEFINITION:
            var operation = document.operation(node)
            if operation == OperationType.QUERY:
                self.path.append("query")
            elif operation == OperationType.MUTATION:
                self.path.append("mutation")
            else:
                self.path.append("subscription")
            for variable in _children(document, node, Role.VARIABLE_DEFINITION):
                self.directive_list(
                    document, variables, variable, NO_NODE, False
                )
        elif kind == Kind.FRAGMENT_DEFINITION:
            self.path.append(
                String(document.name(document.child(node, Role.TYPE_CONDITION)))
            )
        else:
            return
        self.directive_list(document, variables, node, NO_NODE, False)
        self.selection_set(
            document, variables, document.child(node, Role.SELECTION_SET)
        )
        _ = self.path.pop()


def find_inline_arguments(
    document: Document,
    variables: String,
    keep_nodes: Bool,
    options: InlineArgumentsValidationOptions,
    mut result: NormalizationResult,
) raises:
    """Find the inline arguments of a document, as the first stage of
    upstream visits them: `inlineArgumentsVisitor`.

    Args:
        document: The operation document; it does not change.
        variables: The variables JSON, which `@include` and `@skip` read.
        keep_nodes: The `ignore_skip_include` option of the first stage.
        options: The options.
        result: The result that gets the findings, after the ones it has.

    Raises:
        Error: The `error_message` of the options, at the first inline
            argument, when they enforce.
    """
    var walk = _Walk(document, keep_nodes, options)
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        walk.definition(document, variables, definition)
        definition = document.next_sibling(definition)
    result.inline_arguments.extend(walk.found.copy())
