# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The entry points of apollo-compiler validation.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `src/schema/validation.rs`
(`validate_schema`), `src/executable/validation.rs`
(`validate_executable_document`), `Schema::parse_and_validate`,
`ExecutableDocument::parse_and_validate` and
`Parser::parse_mixed_validate`, under the MIT arm of its MIT OR Apache-2.0
license.

Each function returns a `DiagnosticList`. The list is sorted, and each
diagnostic has its line and column. An empty list means the input is
valid: upstream returns `Valid<T>`.

**Differences from upstream.**

- Upstream `Schema::validate` returns `Result<Valid<Schema>, WithErrors>`.
  `validate_schema` returns the `DiagnosticList`, which is empty for a
  valid schema. `Valid` is not a type.
- A `Valid<Schema>` upstream drops the built-in scalars that no field
  uses, and adds the ones that are used but not defined. The schema is
  not changed here.
- `parse_mixed_validate` copies the parsed document: one copy for the
  schema and one for the executable document. Upstream shares it.
"""

from gql_language.ast import Document, Role
from gql_compiler.diagnostics import Diagnostic, DiagnosticKind, DiagnosticList
from gql_compiler.parser import SourceSyntaxError, parse_recovering
from gql_compiler.parser_lexer import SyntaxError
from gql_compiler.executable import BuildError as ExecutableBuildError
from gql_compiler.executable import BuildErrorKind as ExecutableBuildErrorKind
from gql_compiler.executable import (
    ExecutableDocument,
    ExecutableDocumentBuilder,
)
from gql_compiler.from_ast import SchemaBuilder
from gql_compiler.schema import BuildError as SchemaBuildError
from gql_compiler.schema import BuildErrorKind as SchemaBuildErrorKind
from gql_compiler.schema import Schema
from gql_compiler.validate_executable import validate_executable_into
from gql_compiler.validate_schema import validate_schema_into


def schema_files(schema: Schema, mut list: DiagnosticList) -> List[Int]:
    """Rank the files of a schema in a list.

    Args:
        schema: The schema.
        list: The list that ranks the files.

    Returns:
        The rank of each document of `schema.sources`.
    """
    var ranks = List[Int](capacity=len(schema.sources))
    var i = 0
    while i < len(schema.sources):
        ranks.append(list.file(schema.sources[i].source.name))
        i += 1
    return ranks^


def executable_files(
    document: ExecutableDocument, mut list: DiagnosticList
) -> List[Int]:
    """Rank the files of an executable document in a list.

    Args:
        document: The executable document.
        list: The list that ranks the files.

    Returns:
        The rank of each document of `document.sources`.
    """
    var ranks = List[Int](capacity=len(document.sources))
    var i = 0
    while i < len(document.sources):
        ranks.append(list.file(document.sources[i].source.name))
        i += 1
    return ranks^


def add_syntax_errors(
    errors: List[SyntaxError], file: Int, mut list: DiagnosticList
):
    """Add the errors of a parse: upstream `Details::SyntaxError` and
    `Details::ParserLimit`.

    Args:
        errors: The lexer and parser errors, in order.
        file: The rank of the parsed file in the list.
        list: The list to add to.
    """
    for ref error in errors:
        var kind = DiagnosticKind.SYNTAX_ERROR
        if error.is_limit():
            kind = DiagnosticKind.PARSER_LIMIT
        list.push(Diagnostic(kind, file, error.index, error.message))


def add_source_syntax_errors(
    sources: List[Document],
    errors: List[SourceSyntaxError],
    mut list: DiagnosticList,
):
    """Add the syntax errors that a builder kept for its documents.

    Args:
        sources: The documents of the schema or the executable document.
        errors: The errors, each with the index of its document.
        list: The list to add to.
    """
    for ref error in errors:
        var file = list.file(sources[error.source].source.name)
        add_syntax_errors([error.error.copy()], file, list)


def add_schema_build_errors(
    schema: Schema, errors: List[SchemaBuildError], mut list: DiagnosticList
):
    """Add the errors of a schema build: upstream `Details::SchemaBuildError`.

    Args:
        schema: The schema that was built.
        errors: The errors of the build.
        list: The list to add to.
    """
    var ranks = schema_files(schema, list)
    for ref error in errors:
        var source = Int(error.location.source)
        var node = Int(error.location.node)
        ref document = schema.sources[source]
        # Upstream points a collision, an orphan extension and a kind
        # mismatch at the name, and the other errors at the node. Every
        # build error has a node.
        var kind = error.kind
        if (
            kind == SchemaBuildErrorKind.DIRECTIVE_DEFINITION_COLLISION
            or kind == SchemaBuildErrorKind.TYPE_DEFINITION_COLLISION
            or kind == SchemaBuildErrorKind.ORPHAN_TYPE_EXTENSION
            or kind == SchemaBuildErrorKind.TYPE_EXTENSION_KIND_MISMATCH
        ):
            node = document.child(node, Role.NAME)
        list.push(
            Diagnostic(
                DiagnosticKind.SCHEMA_BUILD_ERROR,
                ranks[source],
                document.start(node),
                error.message(),
            )
        )


def add_executable_build_errors(
    document: ExecutableDocument,
    errors: List[ExecutableBuildError],
    mut list: DiagnosticList,
):
    """Add the errors of an executable build: upstream
    `Details::ExecutableBuildError`.

    Args:
        document: The document that was built.
        errors: The errors of the build.
        list: The list to add to.
    """
    var ranks = executable_files(document, list)
    for ref error in errors:
        var source = Int(error.source)
        list.push(
            Diagnostic(
                DiagnosticKind.EXECUTABLE_BUILD_ERROR,
                ranks[source],
                document.sources[source].start(Int(error.node)),
                error.message(),
            )
        )


def finish(
    mut list: DiagnosticList,
    schema: Schema,
    schema_ranks: List[Int],
    document: ExecutableDocument,
):
    """Sort a list, and set the line and the column of each diagnostic.

    Args:
        list: The list.
        schema: The schema whose files the list ranks.
        schema_ranks: The rank of each document of `schema.sources`.
        document: An executable document whose files the list also ranks.
            It is empty for a schema validation.
    """
    list.sort()
    var done = List[Bool](length=len(list.files), fill=False)
    var i = 0
    while i < len(schema.sources):
        if not done[schema_ranks[i]]:
            done[schema_ranks[i]] = True
            list.locate(schema_ranks[i], schema.sources[i])
        i += 1
    if len(document.sources) > 0:
        ref executable = document
        var ranks = executable_files(executable, list)
        i = 0
        while i < len(executable.sources):
            if not done[ranks[i]]:
                done[ranks[i]] = True
                list.locate(ranks[i], executable.sources[i])
            i += 1


def validate_schema(schema: Schema) -> DiagnosticList:
    """Validate a schema: upstream `Schema::validate`.

    Args:
        schema: The schema.

    Returns:
        The diagnostics, sorted. The list is empty for a valid schema.
    """
    var list = DiagnosticList()
    var ranks = schema_files(schema, list)
    validate_schema_into(schema, ranks, list)
    finish(list, schema, ranks, ExecutableDocument())
    return list^


def validate_executable(
    schema: Schema, document: ExecutableDocument
) -> DiagnosticList:
    """Validate an executable document against a schema: upstream
    `ExecutableDocument::validate`.

    Args:
        schema: A valid schema.
        document: The executable document.

    Returns:
        The diagnostics, sorted. The list is empty for a valid document.
    """
    var list = DiagnosticList()
    var ranks = schema_files(schema, list)
    var executable_ranks = executable_files(document, list)
    validate_executable_into(schema, document, executable_ranks, list)
    finish(list, schema, ranks, document)
    return list^


def parse_and_validate_schema(
    text: StringSlice, name: String
) raises -> Tuple[Schema, DiagnosticList]:
    """Parse, build and validate a schema: upstream
    `Schema::parse_and_validate`.

    Args:
        text: The schema text.
        name: The file name of the diagnostics.

    Returns:
        The schema, and the syntax errors, the build errors and the
        validation diagnostics, sorted.

    Raises:
        GraphQLError: Never in practice; see `SchemaBuilder`. A syntax
            error is a diagnostic.
    """
    var builder = SchemaBuilder()
    builder.parse(text, name)
    var syntax = builder.syntax_errors.copy()
    var built = builder^.build_inner()
    var list = DiagnosticList()
    var ranks = schema_files(built[0], list)
    add_source_syntax_errors(built[0].sources, syntax, list)
    add_schema_build_errors(built[0], built[1], list)
    validate_schema_into(built[0], ranks, list)
    finish(list, built[0], ranks, ExecutableDocument())
    var schema = Schema()
    swap(schema, built[0])
    return (schema^, list^)


def parse_mixed_validate(
    text: StringSlice, name: String
) raises -> Tuple[Schema, ExecutableDocument, DiagnosticList]:
    """Parse a document with type system and executable definitions,
    build both and validate both: upstream `Parser::parse_mixed_validate`.

    Args:
        text: The document text.
        name: The file name of the diagnostics.

    Returns:
        The schema, the executable document, and every diagnostic, sorted.

    Raises:
        GraphQLError: Never in practice; see `SchemaBuilder`. A syntax
            error is a diagnostic.
    """
    var tree = parse_recovering(text, name)
    var builder = SchemaBuilder()
    builder.add_ast(
        tree.document.copy(), executable_definitions_are_errors=False
    )
    var built = builder^.build_inner()
    var list = DiagnosticList()
    var ranks = schema_files(built[0], list)
    add_syntax_errors(tree.errors, list.file(name), list)
    add_schema_build_errors(built[0], built[1], list)
    var executable_builder = ExecutableDocumentBuilder()
    executable_builder.add_ast(
        built[0], tree.take_document(), type_system_definitions_are_errors=False
    )
    var executable = executable_builder^.build()
    add_executable_build_errors(executable[0], executable[1], list)
    validate_schema_into(built[0], ranks, list)
    var executable_ranks = executable_files(executable[0], list)
    validate_executable_into(built[0], executable[0], executable_ranks, list)
    finish(list, built[0], ranks, executable[0])
    var schema = Schema()
    swap(schema, built[0])
    var document = ExecutableDocument()
    swap(document, executable[0])
    return (schema^, document^, list^)


def validate_standalone_executable(
    text: StringSlice, name: String
) -> DiagnosticList:
    """Parse, build and validate an executable document with no schema:
    upstream `ast::Document::validate_standalone_executable`.

    The document is built against an empty schema, by a standalone
    `ExecutableDocumentBuilder`. The build errors that need a schema
    (`UNDEFINED_ROOT_OPERATION` and the higher kinds) are dropped, as
    upstream does not report them without a schema.

    Args:
        text: The executable document text.
        name: The file name of the diagnostics.

    Returns:
        The syntax errors and the other diagnostics, sorted.
    """
    var schema = Schema()
    var builder = ExecutableDocumentBuilder(standalone=True)
    builder.parse(schema, text, name)
    var syntax = builder.syntax_errors.copy()
    var built = builder^.build()
    var kept = List[ExecutableBuildError]()
    for ref error in built[1]:
        if (
            error.kind.value
            < ExecutableBuildErrorKind.UNDEFINED_ROOT_OPERATION.value
        ):
            kept.append(error.copy())
    var list = DiagnosticList()
    var ranks = executable_files(built[0], list)
    add_source_syntax_errors(built[0].sources, syntax, list)
    add_executable_build_errors(built[0], kept, list)
    validate_executable_into(schema, built[0], ranks, list, standalone=True)
    finish(list, schema, List[Int](), built[0])
    return list^


def parse_and_validate_executable(
    schema: Schema, text: StringSlice, name: String
) -> Tuple[ExecutableDocument, DiagnosticList]:
    """Parse, build and validate an executable document: upstream
    `ExecutableDocument::parse_and_validate`.

    Args:
        schema: A valid schema.
        text: The executable document text.
        name: The file name of the diagnostics.

    Returns:
        The document, and the syntax errors, the build errors and the
        validation diagnostics, sorted.
    """
    var builder = ExecutableDocumentBuilder(standalone=True)
    builder.parse(schema, text, name)
    var syntax = builder.syntax_errors.copy()
    var built = builder^.build()
    var list = DiagnosticList()
    var ranks = schema_files(schema, list)
    var executable_ranks = executable_files(built[0], list)
    add_source_syntax_errors(built[0].sources, syntax, list)
    add_executable_build_errors(built[0], built[1], list)
    validate_executable_into(schema, built[0], executable_ranks, list)
    finish(list, schema, ranks, built[0])
    var document = ExecutableDocument()
    swap(document, built[0])
    return (document^, list^)
