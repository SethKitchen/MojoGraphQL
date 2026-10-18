# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Test helpers: read the upstream fixtures and compile them.

The fixtures come from Apollo Kotlin (afe947c, MIT):

- `fixtures/<name>/TestOperation.graphql`, `schema.graphqls` and
  `used-coordinates.json.expected`: `libraries/apollo-compiler/src/test/
  graphql/com/example/<name>/`. A fixture without its own schema uses
  `fixtures/schema.graphqls`, the upstream `src/test/graphql/
  schema.graphqls`.
- `fixtures/operation_ids.tsv`: one row per operation of those fixtures,
  with the operation id and the minified document of the expected
  `kotlin/operationBased` output, or of `java/operationBased` when there is
  no Kotlin output or the fixture is a Java one (`java_*`).
- `fixtures/validation/`: `libraries/apollo-ast/test-fixtures/validation/
  executable/`.
- `fixtures/capitalized_fields_validation/`: `libraries/apollo-compiler/
  src/test/validation/operation/capitalized_fields/`.

The suites read the files from `_fixture_data.mojo`, which `_embed.mojo`
writes, because `make coverage` copies only the Mojo files of `tests/`.
"""

from _fixture_data import fixture_paths, fixture_text

from gql_schema.definition import Schema

from gql_codegen.compiler import (
    CodegenDocument,
    CodegenResult,
    build_codegen_schema,
    compile,
)
from gql_codegen.options import CodegenOptions

comptime FIXTURES = "tests/gql_codegen/fixtures/"
"""The fixtures, from the repository root."""

comptime UNSUPPORTED: Array[StaticString, 8] = [
    # `@link` to the Apollo foreign schemas: `@map`, `@mapTo`, `@optional`,
    # `@requiresOptIn`, `@targetName` and `@typePolicy` are not ported.
    "custom_scalar_type",
    "optional",
    "suppressed_warnings",
    "target_name",
    "typepolicy",
    # The schema is not valid by the GraphQL specification: an object
    # implements an interface without the interfaces of that interface.
    # `apollo-ast` accepts it; `gql_schema` and `gql_validation` do not.
    "data_builders",
    "interface_on_interface",
    "monomorphic",
]
"""The fixtures that use what `gql_codegen` does not port."""

comptime DATA_BUILDERS: Array[StaticString, 2] = [
    "mutation_create_review",
    "simple_fragment",
]
"""The fixtures that upstream compiles with data builders, which record
fields in the used coordinates. Data builders are not ported."""


def is_unsupported(fixture: StringSlice) -> Bool:
    """Return True for a fixture of `UNSUPPORTED`.

    Args:
        fixture: The fixture's name.

    Returns:
        Whether the fixture is skipped.
    """
    var names = materialize[UNSUPPORTED]()
    for index in range(len(names)):
        if fixture == names[index]:
            return True
    return False


def uses_data_builders(fixture: StringSlice) -> Bool:
    """Return True for a fixture of `DATA_BUILDERS`.

    Args:
        fixture: The fixture's name.

    Returns:
        Whether upstream compiles it with data builders.
    """
    var names = materialize[DATA_BUILDERS]()
    for index in range(len(names)):
        if fixture == names[index]:
            return True
    return False


def has(path: String) -> Bool:
    """Return True when there is a fixture file at a path.

    Args:
        path: The path from `FIXTURES`.

    Returns:
        Whether `_fixture_data.mojo` holds the file.
    """
    return path in fixture_paths()


def read(path: String) raises -> String:
    """Read a fixture file.

    Args:
        path: The path from `FIXTURES`.

    Returns:
        The text.

    Raises:
        Error: If the file cannot be read.
    """
    return fixture_text(path)


def schema_text(fixture: String) raises -> String:
    """Return the SDL of a fixture: its own, or the shared one.

    Args:
        fixture: The fixture's name.

    Returns:
        The SDL.

    Raises:
        Error: If the file cannot be read.
    """
    if has(fixture + "/schema.graphqls"):
        return read(fixture + "/schema.graphqls")
    return read("schema.graphqls")


def fixture_schema(fixture: String) raises -> Schema:
    """Build the schema of a fixture. A schema that the specification
    refuses but `apollo-ast` accepts, such as the one of `test_inline`, is
    built without the check, as upstream takes it.

    Args:
        fixture: The fixture's name.

    Returns:
        The schema.

    Raises:
        Error: If the SDL does not parse.
    """
    var sdl = schema_text(fixture)
    try:
        return build_codegen_schema(sdl)
    except:
        return build_codegen_schema(sdl, check=False)


def options_for(fixture: StringSlice) -> CodegenOptions:
    """Return the options that the upstream `CodegenTest` gives a fixture.

    Args:
        fixture: The fixture's name.

    Returns:
        The options.
    """
    var options = CodegenOptions()
    if fixture == "decapitalized_fields":
        options.decapitalize_fields = True
    return options


def compile_fixture(fixture: String, schema: Schema) raises -> CodegenResult:
    """Compile the `TestOperation.graphql` of a fixture.

    Args:
        fixture: The fixture's name.
        schema: The schema.

    Returns:
        The result.

    Raises:
        Error: If the file cannot be read or the IR builder refuses it.
    """
    var documents = List[CodegenDocument]()
    documents.append(
        CodegenDocument(
            "TestOperation.graphql", read(fixture + "/TestOperation.graphql")
        )
    )
    return compile(schema, documents, options_for(fixture))


@fieldwise_init
struct Row(Copyable, Movable):
    """One row of `operation_ids.tsv`."""

    var fixture: String
    """The fixture."""
    var name: String
    """The operation's name."""
    var id: String
    """The upstream operation id."""
    var document: String
    """The upstream minified document."""


def rows() raises -> List[Row]:
    """Read `operation_ids.tsv`.

    Returns:
        Every row, in file order.

    Raises:
        Error: If the file cannot be read.
    """
    var out = List[Row]()
    for line in read("operation_ids.tsv").split("\n"):
        if line.byte_length() == 0:
            continue
        var fields = line.split("\t")
        out.append(
            Row(
                String(fields[0]),
                String(fields[1]),
                String(fields[2]),
                String(fields[3]),
            )
        )
    return out^


def fixtures() raises -> List[String]:
    """Return the fixtures of `operation_ids.tsv`, each once, in order.

    Returns:
        The fixture names.

    Raises:
        Error: If the file cannot be read.
    """
    var out = List[String]()
    for ref row in rows():
        if len(out) == 0 or out[len(out) - 1] != row.fixture:
            out.append(row.fixture)
    return out^
