# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The rules about `@defer` and `@stream`.

Port of graphql-js v17.0.2 (commit 71606d73)
`validation/rules/DeferStreamDirectiveOnRootFieldRule.ts`,
`DeferStreamDirectiveOnValidOperationsRule.ts`,
`DeferStreamDirectiveLabelRule.ts` and `StreamDirectiveOnListFieldRule.ts`.

Each function is the handler of one rule for one node kind, and the walk of
`gql_validation.validate` calls it. The rules find the directives by the
names `defer` and `stream`, as graphql-js does. They do not need the schema
to define the directives.

`DeferStreamDirectiveOnRootFieldRule` and
`DeferStreamDirectiveOnValidOperationsRule` start at each operation and
walk its selections and the fragments that it spreads, as graphql-js
v17.0.2 does. An error of `DeferStreamDirectiveOnValidOperationsRule` has
the location of the directive, then the locations of the fragment spreads
that lead to it, the nearest first.

**Differences from upstream.**

- graphql-js v17.0.2 puts these rules in `specifiedRules`. Here they are
  not in `specified_rules()`, because `gql_validation` is a port of the
  graphql-js 16 rules, and graphql-js 16 accepts a document that uses
  `@defer` or `@stream` when the schema defines them. Add
  `incremental_rules()` to the rule list to use them.
- `DeferStreamDirectiveOnRootFieldRule` marks a fragment as visited before
  it walks the fragment. graphql-js v17.0.2 marks it after, so a fragment
  that spreads itself, such as `mutation { ...A } fragment A on Mutation {
  ...A }`, recurses until graphql-js raises `RangeError: Maximum call stack
  size exceeded`. Here the rule finds no error in that cycle, and
  `NoFragmentCyclesRule` reports it. A document without a cycle gets the
  upstream errors.
"""

from gql_language.ast import NO_NODE, Document, Kind, OperationType, Role
from gql_language.names import NOT_FOUND, NameTable
from gql_schema.definition import NO_TYPE, Schema
from gql_validation.rules_arguments import field_name
from gql_validation.state import Walk
from gql_validation.type_info import NO_FIELD


def _title(document: Document, directive: Int) -> StaticString:
    """Return `Defer` for `@defer`, `Stream` for `@stream`, and an empty
    string for any other directive."""
    var name = document.name(directive)
    if name == "defer":
        return "Defer"
    if name == "stream":
        return "Stream"
    return ""


def _argument_value(
    document: Document, directive: Int, name: StringSlice
) -> Int:
    """Return the value of the first argument with a name, or `NO_NODE`, as
    graphql-js `node.arguments?.find(...)?.value`."""
    var argument = document.child(directive, Role.ARGUMENT)
    while argument != NO_NODE:
        if document.name(argument) == name:
            return document.child(argument, Role.VALUE)
        argument = document.next_with_role(argument)
    return NO_NODE


def _find_directive(document: Document, node: Int, name: StringSlice) -> Int:
    """Return the first directive of a node with a name, or `NO_NODE`, as
    graphql-js `node.directives?.find(...)`."""
    var directive = document.child(node, Role.DIRECTIVE)
    while directive != NO_NODE:
        if document.name(directive) == name:
            return directive
        directive = document.next_with_role(directive)
    return NO_NODE


def _if_argument_can_be_false(document: Document, directive: Int) -> Bool:
    """Return True when the `if` argument is `false` or a variable, as
    graphql-js `ifArgumentCanBeFalse`."""
    var value = _argument_value(document, directive, "if")
    if value == NO_NODE:
        return False
    var kind = document.kind(value)
    if kind == Kind.BOOLEAN:
        return not document.boolean_value(value)
    return kind == Kind.VARIABLE


def _can_be_skipped(document: Document, directive: Int, skip: Bool) -> Bool:
    """Return graphql-js `canBeSkippedViaSkipDirective` for `@skip`, and
    `canBeSkippedViaIncludeDirective` for `@include`.

    A missing `if` argument can skip with `@skip` and cannot with
    `@include`; a variable can skip with both; a boolean skips when it is
    the value that skips."""
    var value = _argument_value(document, directive, "if")
    if value == NO_NODE:
        return skip
    if document.kind(value) == Kind.BOOLEAN:
        return document.boolean_value(value) == skip
    return True


def defer_stream_directive_on_root_field(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """DeferStreamDirectiveOnRootFieldRule, on an `OperationDefinition`.

    In a mutation or a subscription, a `@defer` on a fragment of the root
    selection set, or a `@stream` on a root field, is an error. The rule
    walks the inline fragments and the fragment spreads of the root
    selection set, not the selection sets of the fields.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The operation.
    """
    var operation = document.operation(node)
    var root = NO_TYPE
    var operation_name: StaticString = "mutation"
    if operation == OperationType.MUTATION:
        root = Int(schema.mutation_type)
    elif operation == OperationType.SUBSCRIPTION:
        root = Int(schema.subscription_type)
        operation_name = "subscription"
    if root == NO_TYPE:
        return
    var visited = NameTable()
    _forbid_defer_stream(
        walk,
        document,
        String(operation_name) + ' type "' + schema.types[root].name + '".',
        document.child(node, Role.SELECTION_SET),
        visited,
    )


def _forbid_defer_stream(
    mut walk: Walk,
    document: Document,
    suffix: String,
    selection_set: Int,
    mut visited: NameTable,
):
    """Report each `@defer` and `@stream` of a root selection set: the
    graphql-js `forbidDeferStream`. `suffix` ends each message."""
    var selection = document.child(selection_set, Role.SELECTION)
    while selection != NO_NODE:
        var kind = document.kind(selection)
        if kind == Kind.FIELD:
            var stream = _find_directive(document, selection, "stream")
            if stream != NO_NODE:
                walk.ctx.report_error(
                    document,
                    "Stream directive cannot be used on root " + suffix,
                    stream,
                )
        elif kind == Kind.FRAGMENT_SPREAD:
            var name = document.name(selection)
            # The visited mark comes before the walk; see the module
            # docstring.
            if visited.insert(-1, name, 0):
                var fragment = walk.ctx.get_fragment(document, name)
                if fragment != NO_NODE:
                    _report_defer(walk, document, suffix, selection)
                    _forbid_defer_stream(
                        walk,
                        document,
                        suffix,
                        document.child(fragment, Role.SELECTION_SET),
                        visited,
                    )
        else:
            _report_defer(walk, document, suffix, selection)
            _forbid_defer_stream(
                walk,
                document,
                suffix,
                document.child(selection, Role.SELECTION_SET),
                visited,
            )
        selection = document.next_with_role(selection)


def _report_defer(
    mut walk: Walk, document: Document, suffix: String, fragment: Int
):
    """Report the `@defer` of a fragment of a root selection set."""
    var defer = _find_directive(document, fragment, "defer")
    if defer != NO_NODE:
        walk.ctx.report_error(
            document, "Defer directive cannot be used on root " + suffix, defer
        )


def defer_stream_directive_on_valid_operations(
    mut walk: Walk, document: Document, node: Int
):
    """DeferStreamDirectiveOnValidOperationsRule, on an
    `OperationDefinition`.

    In a subscription, a `@defer` or a `@stream` is an error unless its `if`
    argument can be `false`. The rule walks the selections of the
    subscription and the fragments that it spreads. It does not walk a
    selection that `@skip` or `@include` can skip.

    Args:
        walk: The walk.
        document: The document.
        node: The operation.
    """
    if document.operation(node) != OperationType.SUBSCRIPTION:
        return
    var visited = NameTable()
    var parents = List[Int]()
    _forbid_unconditional_defer_stream(
        walk,
        document,
        document.child(node, Role.SELECTION_SET),
        parents,
        visited,
    )


def _forbid_unconditional_defer_stream(
    mut walk: Walk,
    document: Document,
    selection_set: Int,
    mut parents: List[Int],
    mut visited: NameTable,
):
    """Report each `@defer` and `@stream` that cannot be disabled: the
    graphql-js `forbidUnconditionalDeferStream`. `parents` holds the
    fragment spreads that lead to the selection set, the nearest last."""
    var selection = document.child(selection_set, Role.SELECTION)
    while selection != NO_NODE:
        if _skippable(document, selection):
            selection = document.next_with_role(selection)
            continue
        var directive = document.child(selection, Role.DIRECTIVE)
        while directive != NO_NODE:
            var title = _title(document, directive)
            if title.byte_length() > 0 and not _if_argument_can_be_false(
                document, directive
            ):
                var nodes = List[Int](capacity=len(parents) + 1)
                nodes.append(directive)
                var index = len(parents) - 1
                while index >= 0:
                    nodes.append(parents[index])
                    index -= 1
                walk.ctx.report_error_nodes(
                    document,
                    String(title)
                    + " directive not supported on subscription operations."
                    + " Disable `@"
                    + String(document.name(directive))
                    + "` by setting the `if` argument to `false`.",
                    nodes,
                )
            directive = document.next_with_role(directive)
        var kind = document.kind(selection)
        if kind == Kind.FRAGMENT_SPREAD:
            var name = document.name(selection)
            if visited.insert(-1, name, 0):
                var fragment = walk.ctx.get_fragment(document, name)
                if fragment != NO_NODE:
                    parents.append(selection)
                    _forbid_unconditional_defer_stream(
                        walk,
                        document,
                        document.child(fragment, Role.SELECTION_SET),
                        parents,
                        visited,
                    )
                    _ = parents.pop()
        else:
            var child = document.child(selection, Role.SELECTION_SET)
            if child != NO_NODE:
                _forbid_unconditional_defer_stream(
                    walk, document, child, parents, visited
                )
        selection = document.next_with_role(selection)


def _skippable(document: Document, selection: Int) -> Bool:
    """Return True when the first `@skip` or the first `@include` of a
    selection can skip it."""
    var skip = _find_directive(document, selection, "skip")
    if skip != NO_NODE and _can_be_skipped(document, skip, True):
        return True
    var include = _find_directive(document, selection, "include")
    return include != NO_NODE and _can_be_skipped(document, include, False)


def defer_stream_directive_label(mut walk: Walk, document: Document, node: Int):
    """DeferStreamDirectiveLabelRule, on a `Directive`.

    The `label` argument of `@defer` and `@stream` must be a static string,
    and no two of these directives can have the same label. A `null` label
    is the same as no label.

    Args:
        walk: The walk.
        document: The document.
        node: The directive.
    """
    if _title(document, node).byte_length() == 0:
        return
    var value = _argument_value(document, node, "label")
    if value == NO_NODE or document.kind(value) == Kind.NULL:
        return
    if document.kind(value) != Kind.STRING:
        walk.ctx.report_error(
            document,
            'Argument "@'
            + String(document.name(node))
            + '(label:)" must be a static string.',
            node,
        )
        return
    var known = walk.defer_stream_labels.find_or_insert(
        -1, document.string_value(value), node
    )
    if known == NOT_FOUND:
        return
    var nodes = List[Int](capacity=2)
    nodes.append(known)
    nodes.append(node)
    walk.ctx.report_error_nodes(
        document,
        (
            'Value for arguments "defer(label:)" and "stream(label:)" must be'
            " unique across all Defer/Stream directive usages."
        ),
        nodes,
    )


def stream_directive_on_list_field(
    mut walk: Walk, schema: Schema, document: Document, node: Int
):
    """StreamDirectiveOnListFieldRule, on a `Directive`.

    A `@stream` on a field whose type is not a list, or a non-null list, is
    an error.

    Args:
        walk: The walk.
        schema: The schema.
        document: The document.
        node: The directive.
    """
    if not (document.name(node) == "stream"):
        return
    var field = walk.ctx.type_info.get_field_def()
    if field == NO_FIELD:
        return
    var parent = walk.ctx.type_info.get_parent_type()
    if parent == NO_TYPE:
        return
    var type = walk.ctx.type_info.field_type(schema, field)
    if type.is_list():
        return
    # `of_type()` of a named type is the named type, which is not a list,
    # so this is the graphql-js `isWrappingType(type) &&
    # isListType(type.ofType)`.
    if type.of_type().is_list():
        return
    walk.ctx.report_error(
        document,
        'Directive "@stream" cannot be used on non-list field "'
        + schema.types[parent].name
        + "."
        + field_name(schema, field)
        + '".',
        node,
    )
