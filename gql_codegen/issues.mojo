# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The issues that a compilation reports: errors and warnings.

Port of Apollo Kotlin `apollo-ast` `Issue.kt` (the issue classes that the
compiler can raise for an executable document), of the default severities
of `apollo-compiler` `Options.kt` `defaultIssueSeverities`, and of the
serialization of the upstream compiler tests, `TestUtils.serialize`:

    UpperCaseField (2:3)
    Capitalized field 'Horse' is not supported ...

**Differences from upstream.** The GraphQL validation errors come from
`gql_validation`, so their messages are the graphql-js messages, not the
`apollo-ast` messages. Their kind is `OtherValidationIssue`, or the
upstream kind for a parse error, an unused variable, an unused fragment, a
deprecated usage and a fragment cycle.
"""


@fieldwise_init
struct IssueKind(Equatable, ImplicitlyCopyable, Writable):
    """The class of an issue, as the upstream `Issue` subclasses."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime PARSING_ERROR = IssueKind(0)
    """`ParsingError`: the document does not parse."""
    comptime OTHER_VALIDATION_ISSUE = IssueKind(1)
    """`OtherValidationIssue`: a GraphQL validation error."""
    comptime UNUSED_VARIABLE = IssueKind(2)
    """`UnusedVariable`: a warning by default."""
    comptime UNUSED_FRAGMENT = IssueKind(3)
    """`UnusedFragment`: a warning by default."""
    comptime DEPRECATED_USAGE = IssueKind(4)
    """`DeprecatedUsage`: a warning by default."""
    comptime ANONYMOUS_OPERATION = IssueKind(5)
    """`AnonymousOperation`: the generator needs a name."""
    comptime UPPER_CASE_FIELD = IssueKind(6)
    """`UpperCaseField`: a capitalized field clashes with its model."""
    comptime INLINE_FRAGMENT_WITHOUT_TYPE_CONDITION = IssueKind(7)
    """`InlineFragmentWithoutTypeCondition`."""
    comptime FRAGMENT_CYCLE = IssueKind(8)
    """`FragmentCycle`: a fragment spreads itself."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the nine kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 8

    def text(self) -> StaticString:
        """Return the upstream class name, such as `UpperCaseField`.

        Returns:
            The name, or `<invalid>`.
        """
        if self == IssueKind.PARSING_ERROR:
            return "ParsingError"
        if self == IssueKind.OTHER_VALIDATION_ISSUE:
            return "OtherValidationIssue"
        if self == IssueKind.UNUSED_VARIABLE:
            return "UnusedVariable"
        if self == IssueKind.UNUSED_FRAGMENT:
            return "UnusedFragment"
        if self == IssueKind.DEPRECATED_USAGE:
            return "DeprecatedUsage"
        if self == IssueKind.ANONYMOUS_OPERATION:
            return "AnonymousOperation"
        if self == IssueKind.UPPER_CASE_FIELD:
            return "UpperCaseField"
        if self == IssueKind.INLINE_FRAGMENT_WITHOUT_TYPE_CONDITION:
            return "InlineFragmentWithoutTypeCondition"
        if self == IssueKind.FRAGMENT_CYCLE:
            return "FragmentCycle"
        return "<invalid>"

    def default_severity(self) -> Severity:
        """Return the upstream default severity of the kind.

        Returns:
            `WARNING` for an unused variable, an unused fragment and a
            deprecated usage; `ERROR` for the others.
        """
        if (
            self == IssueKind.UNUSED_VARIABLE
            or self == IssueKind.UNUSED_FRAGMENT
            or self == IssueKind.DEPRECATED_USAGE
        ):
            return Severity.WARNING
        return Severity.ERROR

    def write_to(self, mut writer: Some[Writer]):
        """Write the upstream class name.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct Severity(Equatable, ImplicitlyCopyable, Writable):
    """How an issue affects a compilation, as upstream `IssueSeverity`."""

    var value: UInt8
    """The severity's index; see `is_valid`."""

    comptime ERROR = Severity(0)
    """The compilation fails."""
    comptime WARNING = Severity(1)
    """The compilation goes on, unless `fail_on_warnings` is set."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the two severities.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 1

    def write_to(self, mut writer: Some[Writer]):
        """Write `error` or `warning`.

        Args:
            writer: The destination.
        """
        if self == Severity.ERROR:
            writer.write("error")
        elif self == Severity.WARNING:
            writer.write("warning")
        else:
            writer.write("<invalid>")


@fieldwise_init
struct Issue(Copyable, Movable, Writable):
    """One error or warning, at a place in a document."""

    var kind: IssueKind
    """The class of the issue."""
    var message: String
    """The message."""
    var file: String
    """The name of the document, as the caller gave it."""
    var line: Int
    """The line, from 1; 0 when there is no place."""
    var column: Int
    """The column, from 1; 0 when there is no place."""

    def severity(self) -> Severity:
        """Return the severity of the issue.

        Returns:
            The default severity of its kind.
        """
        return self.kind.default_severity()

    def write_to(self, mut writer: Some[Writer]):
        """Write the issue as the upstream compiler tests serialize it:
        `Kind (line:column)`, a line feed, and the message.

        Args:
            writer: The destination.
        """
        writer.write(
            self.kind, " (", self.line, ":", self.column, ")\n", self.message
        )


def serialize(issues: List[Issue]) -> String:
    """Join issues as the upstream compiler tests do, with a line of
    twelve dashes between two issues.

    Args:
        issues: The issues.

    Returns:
        The text; empty for no issue.
    """
    var out = String("")
    for index in range(len(issues)):
        if index > 0:
            out += "\n------------\n"
        out += String(issues[index])
    return out^
