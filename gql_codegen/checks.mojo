# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The checks of an executable document that only Apollo makes.

Port of Apollo Kotlin `apollo-compiler`
`internal/checkCapitalizedFields.kt`,
`internal/checkApolloInlineFragmentsHaveTypeCondition.kt`, and of the
anonymous operation check of `apollo-ast`
`ExecutableValidationScope.validateOperations`.

Each check returns its issues with the line and column of the node, in the
document that the caller passes.

**Differences from upstream.** None.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role

from gql_codegen.issues import Issue, IssueKind
from gql_codegen.strings import (
    decapitalize_first_letter,
    is_first_letter_upper_case,
)


def _issue(
    document: Document, node: Int, kind: IssueKind, var message: String
) -> Issue:
    """Make an issue at the start of a node."""
    var location = document.location(node)
    return Issue(kind, message^, "", location.line, location.column)


def check_anonymous_operations(document: Document) -> List[Issue]:
    """Refuse an operation without a name, as upstream
    `AnonymousOperation`.

    Args:
        document: The executable document.

    Returns:
        One issue per anonymous operation.
    """
    var out = List[Issue]()
    for definition in document.definitions():
        if (
            document.kind(definition) == Kind.OPERATION_DEFINITION
            and document.child(definition, Role.NAME) == NO_NODE
        ):
            out.append(
                _issue(
                    document,
                    definition,
                    IssueKind.ANONYMOUS_OPERATION,
                    "Apollo does not support anonymous operations",
                )
            )
    return out^


def _walk_inline_fragments(
    document: Document, selection_set: Int, mut out: List[Issue]
):
    """Report inline fragments without a type condition, as upstream
    `GQLSelection.walk`. Upstream does not look into an inline fragment."""
    if selection_set == NO_NODE:
        return
    var current = document.first_child(selection_set)
    while current != NO_NODE:
        var kind = document.kind(current)
        if kind == Kind.FIELD:
            _walk_inline_fragments(
                document, document.child(current, Role.SELECTION_SET), out
            )
        elif kind == Kind.INLINE_FRAGMENT:
            if document.child(current, Role.TYPE_CONDITION) == NO_NODE:
                out.append(
                    _issue(
                        document,
                        current,
                        IssueKind.INLINE_FRAGMENT_WITHOUT_TYPE_CONDITION,
                        (
                            "Inline fragments without a type condition are not"
                            " supported. Add the parent type to inline"
                            " fragment."
                        ),
                    )
                )
        current = document.next_sibling(current)


def check_inline_fragments_have_type_condition(
    document: Document,
) -> List[Issue]:
    """Refuse an inline fragment without a type condition, as upstream
    `checkApolloInlineFragmentsHaveTypeCondition`.

    Args:
        document: The executable document.

    Returns:
        One issue per inline fragment without a type condition.
    """
    var out = List[Issue]()
    for definition in document.definitions():
        var kind = document.kind(definition)
        if (
            kind == Kind.OPERATION_DEFINITION
            or kind == Kind.FRAGMENT_DEFINITION
        ):
            _walk_inline_fragments(
                document, document.child(definition, Role.SELECTION_SET), out
            )
    return out^


def _check_capitalized(
    document: Document, selection_set: Int, mut out: List[Issue]
):
    """Report capitalized fields and aliases with a selection set, as
    upstream `ValidationScope.checkCapitalizedFields`."""
    var current = document.first_child(selection_set)
    while current != NO_NODE:
        var kind = document.kind(current)
        if kind == Kind.FIELD:
            var inner = document.child(current, Role.SELECTION_SET)
            if inner != NO_NODE:
                var alias = document.child(current, Role.ALIAS)
                if alias != NO_NODE:
                    var text = String(document.text(alias))
                    if is_first_letter_upper_case(text):
                        out.append(
                            _issue(
                                document,
                                current,
                                IssueKind.UPPER_CASE_FIELD,
                                "Capitalized alias '"
                                + text
                                + "' is not supported as it causes name"
                                " clashes with the generated models. Use '"
                                + decapitalize_first_letter(text)
                                + "' instead.",
                            )
                        )
                else:
                    var name = String(document.name(current))
                    if is_first_letter_upper_case(name):
                        out.append(
                            _issue(
                                document,
                                current,
                                IssueKind.UPPER_CASE_FIELD,
                                "Capitalized field '"
                                + name
                                + "' is not supported as it causes name"
                                " clashes with the generated models. Use an"
                                " alias instead or the 'flattenModels' or"
                                " 'decapitalizeFields' compiler option.",
                            )
                        )
                _check_capitalized(document, inner, out)
        elif kind == Kind.INLINE_FRAGMENT:
            _check_capitalized(
                document, document.child(current, Role.SELECTION_SET), out
            )
        current = document.next_sibling(current)


def check_capitalized_fields(
    document: Document, check_fragments_only: Bool
) -> List[Issue]:
    """Refuse capitalized fields that have a model, as upstream
    `checkCapitalizedFields`: their model would have the name of the
    field's property. A fragment spread is not followed: each fragment
    definition is checked on its own.

    Args:
        document: The executable document.
        check_fragments_only: Whether to skip the operations, as upstream
            does when the models are flat.

    Returns:
        One issue per capitalized field or alias.
    """
    var out = List[Issue]()
    for definition in document.definitions():
        var kind = document.kind(definition)
        if kind == Kind.FRAGMENT_DEFINITION or (
            kind == Kind.OPERATION_DEFINITION and not check_fragments_only
        ):
            _check_capitalized(
                document, document.child(definition, Role.SELECTION_SET), out
            )
    return out^
