# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Compile a schema and operation documents into Mojo.

Port of Apollo Kotlin `apollo-compiler` `ApolloCompiler.kt`
`buildCodegenSchema`, `buildIrOperations` and
`buildSchemaAndOperationsSources`, for Mojo output:

1. Sort the documents by name and parse them. A syntax error stops the
   compilation, as upstream.
2. Add `__typename` with `add_required_fields`.
3. Validate the document with every specified rule of `gql_validation`,
   and make the Apollo checks: anonymous operations, inline fragments
   without a type condition, and capitalized fields.
4. Stop on an error, or on a warning with `fail_on_warnings`.
5. Build the `operationBased` IR and write the Mojo module.

**Differences from upstream.**

- The GraphQL validation messages are the graphql-js messages of
  `gql_validation`, not the `apollo-ast` messages. An unused variable, an
  unused fragment and a deprecated usage are warnings, as upstream.
- The schema is SDL. An introspection result (`schema.json`), a `@link`
  to an Apollo foreign schema, schema extensions in other files and the
  `ApolloCompilerPlugin` hooks are not ported.
- `checkApolloReservedEnumValueNames` and `checkApolloTargetNameClashes`
  check `@targetName`, which is not ported, so they are not made.
"""

from gql_language.ast import Document
from gql_language.error import GraphQLError
from gql_language.parser import parse
from gql_schema.build import build_schema
from gql_schema.definition import Schema
from gql_schema.validate import assert_valid_schema
from gql_validation.rules import ValidationRule, specified_rules
from gql_validation.validate import ValidationOptions, validate

from gql_codegen.checks import (
    check_anonymous_operations,
    check_capitalized_fields,
    check_inline_fragments_have_type_condition,
)
from gql_codegen.ir import IrOperations
from gql_codegen.ir_builder import build_ir
from gql_codegen.issues import Issue, IssueKind, Severity
from gql_codegen.mojo_codegen import (
    generate_mojo,
    operation_id,
    operation_struct_name,
)
from gql_codegen.options import CodegenOptions
from gql_codegen.transform import add_required_fields


@fieldwise_init
struct CodegenDocument(Copyable, Movable):
    """One executable document, as upstream `InputFile`."""

    var name: String
    """The name of the document, such as its path; documents compile in
    the order of their names, as upstream sorts its files."""
    var text: String
    """The GraphQL text."""


struct CodegenResult(Movable):
    """What a compilation makes: issues, the IR and the Mojo module."""

    var errors: List[Issue]
    """The errors; when there is one, there is no IR and no source."""
    var warnings: List[Issue]
    """The warnings."""
    var ir: IrOperations
    """The IR; empty when there are errors."""
    var source: String
    """The Mojo module; empty when there are errors."""

    def __init__(out self):
        """Make an empty result."""
        self.errors = List[Issue]()
        self.warnings = List[Issue]()
        self.ir = IrOperations()
        self.source = String("")

    def succeeded(self) -> Bool:
        """Return True when the compilation made the module.

        Returns:
            Whether there is no error.
        """
        return len(self.errors) == 0

    def operation_ids(self) -> List[String]:
        """Return the id of each operation, in order.

        Returns:
            The SHA-256 of each minified document.
        """
        var out = List[String]()
        for index in range(len(self.ir.operations)):
            out.append(operation_id(self.ir, index))
        return out^

    def operation_names(self) -> List[String]:
        """Return the struct name of each operation, in order.

        Returns:
            Such as `HeroQuery`.
        """
        var out = List[String]()
        for ref operation in self.ir.operations:
            out.append(
                operation_struct_name(operation.name, operation.operation_type)
            )
        return out^


def build_codegen_schema(sdl: StringSlice, check: Bool = True) raises -> Schema:
    """Build and check a schema from SDL, as upstream `buildCodegenSchema`.

    The check is the graphql-js schema validation, which is stricter than
    the `apollo-ast` check: it refuses, for example, an interface that an
    object implements without the interfaces of that interface. Pass
    `check=False` to take the schema as upstream would.

    Args:
        sdl: The schema's SDL.
        check: Whether to validate the schema.

    Returns:
        The schema.

    Raises:
        Error: A syntax error, or the schema validation errors.
    """
    var schema = build_schema(sdl)
    if check:
        assert_valid_schema(schema)
    return schema^


@fieldwise_init
struct _Place(ImplicitlyCopyable, Movable):
    """The file and the line of a line of the joined text."""

    var file: String
    """The document's name."""
    var line: Int
    """The line in the document."""


struct _Lines(Movable):
    """Where each document starts in the joined text."""

    var names: List[String]
    """The documents' names, in order."""
    var starts: List[Int]
    """The line of the joined text where each document starts, from 1."""

    def __init__(out self):
        """Start with no document."""
        self.names = List[String]()
        self.starts = List[Int]()

    def place(self, line: Int) -> _Place:
        """Return the document and the line of a line of the joined text.

        Args:
            line: The line of the joined text, from 1.

        Returns:
            The place.
        """
        var at = len(self.starts) - 1
        while at > 0 and self.starts[at] > line:
            at -= 1
        return _Place(self.names[at], line - self.starts[at] + 1)


def _count_lines(text: StringSlice) -> Int:
    """Return how many line feeds a text has."""
    var count = 0
    for byte in text.as_bytes():
        if byte == UInt8(ord("\n")):
            count += 1
    return count


def _issue_of(error: GraphQLError, kind: IssueKind) -> Issue:
    """Make an issue of a GraphQL error, at its first location."""
    var line = 0
    var column = 0
    if len(error.locations) > 0:
        line = error.locations[0].line
        column = error.locations[0].column
    return Issue(kind, error.message, "", line, column)


def _kind_of(message: StringSlice) -> IssueKind:
    """Return the upstream kind of a graphql-js validation message."""
    # `NoUnusedVariablesRule` and `NoUnusedFragmentsRule`.
    if " is never used" in message:
        if message.startswith("Fragment "):
            return IssueKind.UNUSED_FRAGMENT
        return IssueKind.UNUSED_VARIABLE
    # `NoFragmentCyclesRule`.
    if " within itself" in message:
        return IssueKind.FRAGMENT_CYCLE
    if " is deprecated." in message:
        return IssueKind.DEPRECATED_USAGE
    return IssueKind.OTHER_VALIDATION_ISSUE


def _relocate(var issue: Issue, lines: _Lines) -> Issue:
    """Map the line of an issue in the joined text to its document. An
    issue without a place goes to the first document."""
    if issue.line > 0:
        var place = lines.place(issue.line)
        issue.file = place.file
        issue.line = place.line
    else:
        issue.file = lines.names[0]
    return issue^


def _add(mut result: CodegenResult, var issue: Issue):
    """Add an issue to the errors or to the warnings."""
    if issue.severity() == Severity.ERROR:
        result.errors.append(issue^)
    else:
        result.warnings.append(issue^)


def compile(
    schema: Schema,
    documents: List[CodegenDocument],
    options: CodegenOptions = CodegenOptions(),
) raises -> CodegenResult:
    """Compile operation documents against a schema into a Mojo module, as
    upstream `ApolloCompiler.buildSchemaAndOperationsSources`.

    Args:
        schema: The schema, from `build_codegen_schema`.
        documents: The executable documents.
        options: The options.

    Returns:
        The issues, and when there is no error, the IR and the module.

    Raises:
        Error: For an option value that is not valid, and with the
            upstream message for what validation lets through but the IR
            builder refuses.
    """
    if not options.add_typename.is_valid():
        raise Error(
            "Unknown addTypename option: " + String(options.add_typename)
        )
    if not options.codegen_models.is_valid():
        raise Error("codegenModels is not supported")
    var result = CodegenResult()
    if len(documents) == 0:
        # Upstream compiles no executable file into no operation.
        result.source = generate_mojo(result.ir, schema, options)
        return result^

    var order = List[Int]()
    # `documents` is not empty here.
    for index in range(len(documents)):  # pragma: no branch
        var at = len(order)
        while at > 0 and documents[order[at - 1]].name > documents[index].name:
            at -= 1
        order.insert(at, index)
    var lines = _Lines()
    var text = String("")
    var line = 1
    for index in order:  # pragma: no branch
        ref document = documents[index]
        if len(order) > 1:
            try:
                _ = parse(document.text)
            except error:
                var issue = _issue_of(error, IssueKind.PARSING_ERROR)
                issue.file = document.name
                result.errors.append(issue^)
        lines.names.append(document.name)
        lines.starts.append(line)
        if text.byte_length() > 0:
            text += "\n"
        text += document.text
        line += _count_lines(document.text) + 1
    if len(result.errors) > 0:
        return result^

    var parsed: Document
    try:
        parsed = parse(text)
    except error:
        result.errors.append(
            _relocate(_issue_of(error, IssueKind.PARSING_ERROR), lines)
        )
        return result^

    add_required_fields(parsed, schema, options.add_typename)

    var rules = specified_rules()
    rules.append(ValidationRule.NO_DEPRECATED_CUSTOM)
    # The schema was checked once, by `build_codegen_schema`. Upstream has
    # no error limit.
    var validation = ValidationOptions()
    validation.assume_valid_schema = True
    validation.max_errors = 1 << 30
    for ref error in validate(schema, parsed, rules, validation):
        _add(
            result,
            _relocate(_issue_of(error, _kind_of(error.message)), lines),
        )
    for issue in check_anonymous_operations(parsed):
        _add(result, _relocate(issue.copy(), lines))
    for issue in check_inline_fragments_have_type_condition(parsed):
        _add(result, _relocate(issue.copy(), lines))
    if not options.decapitalize_fields:
        for issue in check_capitalized_fields(parsed, options.flatten_models):
            _add(result, _relocate(issue.copy(), lines))
    if options.fail_on_warnings:
        for ref warning in result.warnings:
            result.errors.append(warning.copy())
    if len(result.errors) > 0:
        return result^

    result.ir = build_ir(parsed, schema, options)
    result.source = generate_mojo(result.ir, schema, options)
    return result^
