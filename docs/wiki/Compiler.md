<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Compiler

`gql_compiler` ports the schema model, the executable document model and the validation of apollo-compiler 1.33.0, the semantic layer of apollo-rs (`b7eee5c`). The port uses the MIT arm of the MIT OR Apache-2.0 license. It depends only on `gql_language`.

| Module | Contents |
| --- | --- |
| `gql_compiler.schema` | `Schema`, `ExtendedType`, `TypeKind`, `Component`, `Members`, `DirectiveDefinition`, `RootOperation`, `BuildError`, `BuildErrorKind` |
| `gql_compiler.from_ast` | `SchemaBuilder` |
| `gql_compiler.executable` | `ExecutableDocument`, `ExecutableDocumentBuilder`, `Operation`, `Fragment`, `SelectionSet`, `Selection`, `SelectionKind`, `MetaField`, `BuildError`, `BuildErrorKind` |
| `gql_compiler.serialize` | `serialize_schema`, `serialize_document`, `serialize_value`, `State` |
| `gql_compiler.built_in` | `BUILT_IN_TYPES`, the upstream `built_in_types.graphql` |
| `gql_compiler.validation` | `validate_schema`, `validate_executable`, `parse_and_validate_schema`, `parse_and_validate_executable`, `parse_mixed_validate`, `validate_standalone_executable` |
| `gql_compiler.diagnostics` | `Diagnostic`, `DiagnosticKind`, `DiagnosticList` |
| `gql_compiler.validate_schema` | `validate_schema_into`, the schema checks |
| `gql_compiler.validate_executable` | `validate_executable_into`, the executable document checks and field merging |
| `gql_compiler.validate_common` | The checks of directives, arguments, values and variable usage, which both passes use |

## Build a schema

`SchemaBuilder()` holds the built-in types. `parse` adds the text of a document, and `add_ast` adds a parsed `Document`. `build` returns the `Schema`, or raises an `Error` with every message. `build_inner` returns the schema and the list of `BuildError` values.

```mojo
from gql_compiler.from_ast import SchemaBuilder

def main() raises:
    var builder = SchemaBuilder()
    builder.parse("type Query { hello: String }")
    var schema = builder^.build()
    print(schema.member_count(schema.get_type("Query")))
```

`adopt_orphan_extensions` accepts an extension of a type that has no definition. `ignore_builtin_redefinitions_on` ignores a redefinition of a built-in type.

## The model

A `Schema` keeps the documents that it was built from in `sources`. The first document holds the built-in types. A type, a member, a directive and a root operation are each a `Component`. A component is a document index, a node index and an origin. The origin is the definition, or an index into `extensions`.

`types` keeps the definition order. `get_type` finds a type by name. `find_member` finds a field, an enum value, a union member or an input field. `count_directives` counts the directives with a name.

## Errors

Each `BuildError` has the message of the upstream `BuildError` variant. The first definition of a type, a directive or a member wins. A later one is an error. A built-in directive can be redefined once.

## Serialize a schema

`schema.to_string()` prints a `Schema` as upstream `Display for Schema` prints it. `schema.serialize()` and `serialize_schema` take the upstream options as arguments: `indent_prefix`, `newlines=False` for upstream `no_indent`, and `initial_indent_level`.

```mojo
from gql_compiler.from_ast import SchemaBuilder

def main() raises:
    var builder = SchemaBuilder()
    builder.parse("type Query { a: Int } extend type Query { b: Int }")
    print(builder^.build().to_string())
```

The printer obeys the upstream rules:

- The built-in types and directives are not printed. An extension of a built-in type is printed.
- The `schema` definition is printed only when it is necessary. It is not printed when each root operation is the object type with the default name, and the definition has no description and no directives.
- The types come in definition order. A redefined built-in directive keeps the place of the built-in.
- Each extension that adds a component to a type is printed as an `extend` block after the type. The extensions come in the order in which their components first appear: directives, then interfaces, then members.
- An indentation level is two spaces. A blank line separates two definitions.
- A description is a block string when it can be one. The arguments of a field go on separate lines when one of them has a description or a directive.

`serialize_document` prints the type system definitions of a parsed `Document`, as upstream `Display for ast::Document` does. `serialize_value` prints one value node.

## Build an executable document

`ExecutableDocument.parse(schema, text)` parses a query document and builds it against a `Schema`. `ExecutableDocument.from_ast(schema, document)` builds a parsed `Document`. Each returns the document and the list of `BuildError` values. Upstream collects the errors in the same way, and does not stop at the first one.

```mojo
from gql_compiler.executable import ExecutableDocument
from gql_compiler.from_ast import SchemaBuilder

def main() raises:
    var builder = SchemaBuilder()
    builder.parse("type Query { hello: String }")
    var schema = builder^.build()
    var result = ExecutableDocument.parse(schema, "query Q { hello }")
    var operation = result[0].get_operation(String("Q"))
    print(result[0].selection_count(Int(operation.selection_set)))
```

`ExecutableDocumentBuilder` adds documents from more than one source. Call `parse` or `add_ast` for each source, then call `build`. Each call takes the schema.

## The executable model

An `ExecutableDocument` owns the documents that it was built from, in `sources`. The documents are moved in, and nothing is copied. An `Operation`, a `Fragment` and a `Selection` each hold a document index and a node index.

`operations` holds the anonymous operation and the named operations, in definition order. `anonymous` is the index of the anonymous operation, or `NOT_FOUND`. `get_operation(name)` returns the operation to run, as upstream `operations.get` does. `fragments` holds the named fragments, and `get_fragment(name)` finds one.

`selection_sets` holds every selection set. Each set has a type, which is an index into `Schema.types`, and a run of `selections`. A `Selection` is a field, a fragment spread or an inline fragment. A field holds its field definition as a `Component` of the schema. A meta field (`__typename`, `__schema` or `__type`) has a `MetaField` kind instead.

`root_fields` and `all_fields` walk the fields of a set through its fragments. `is_introspection` returns True for a query that selects only meta fields.

The executable `BuildError` has the message of the upstream variant. The variants are `TypeSystemDefinition`, `AmbiguousAnonymousOperation`, `OperationNameCollision`, `FragmentNameCollision`, `UndefinedRootOperation`, `UndefinedTypeInNamedFragmentTypeCondition`, `UndefinedTypeInInlineFragmentTypeCondition`, `SubselectionOnScalarType`, `SubselectionOnEnumType` and `UndefinedField`. The other upstream variants come from validation.

## Validate

Call `validate_schema(schema)` to validate a schema. Call `validate_executable(schema, document)` to validate an executable document against a valid schema. Each function returns a `DiagnosticList`. An empty list means that the input is valid.

```mojo
from gql_compiler.validation import (
    parse_and_validate_executable,
    parse_and_validate_schema,
)

def main() raises:
    var checked = parse_and_validate_schema(
        "type Query { hello: String }", "schema.graphql"
    )
    print(checked[1].is_empty())
    var result = parse_and_validate_executable(
        checked[0], "{ hello(a: 1) }", "query.graphql"
    )
    print(result[1])
```

The second `print` writes this text:

```text
Error: the argument `a` is not supported by `Query.hello`
╭─[ query.graphql:1:9 ]
```

`parse_and_validate_schema` and `parse_and_validate_executable` parse, build and validate in one call. They also report the build errors. `parse_mixed_validate` reads a document with type system definitions and executable definitions, as upstream `Parser::parse_mixed_validate` does. `validate_standalone_executable` validates an executable document with no schema.

## Diagnostics

A `Diagnostic` is one upstream `DiagnosticData`. `kind` is a `DiagnosticKind`. `message()` returns the text of the upstream `#[error(...)]` attribute. The text fields `a` to `f` hold the values of the variant. Each `DiagnosticKind` constant tells which field holds which value.

A diagnostic has one location: a file, a byte offset, a line and a column. The column counts characters, as ariadne does. A diagnostic with no location has the file -1.

A `DiagnosticList` is sorted by file, then by offset, as upstream sorts it. A diagnostic with no location comes first. Writing a list gives the `Error:` line and the `╭─[ file:line:column ]` line of each diagnostic. That is the head of the upstream report.

## Differences from upstream

- A `Component` names an AST node by index. Upstream holds a reference counted pointer.
- `add_ast` takes the document by value. Upstream shares it through `Arc`.
- Upstream keeps the built-in types in a static `OnceLock`. Mojo has no globals. `SchemaBuilder.built_in()` returns a builder that a caller can keep and copy.
- A type with fewer than 8 members finds a member by a scan. A larger type uses a hash. Upstream always hashes.
- `parse` raises a `GraphQLError` on a syntax error. Upstream records the error in its diagnostics.
- The GraphQL directive extension is an error, with the description "a directive extension". apollo-parser does not parse it.
- `ExecutableDocumentBuilder` takes the schema in each `parse` and `add_ast` call. Upstream keeps a reference to it in the builder.
- An executable document always has a schema. For `validate_standalone_executable`, a standalone `ExecutableDocumentBuilder` builds against an empty schema. It keeps an operation and a fragment whose type is not defined. Upstream builds with no schema.
- The type of a selection set is a type index, or `NOT_FOUND` when an invalid schema names an undefined type. Upstream keeps the type's name.
- A meta field has a `MetaField` kind and no `Component`. Upstream keeps a static field definition.
- An executable `BuildError` has no `SelectionPath`. The message is the same.
- `root_fields` and `all_fields` return a `List`. Upstream returns a lazy iterator.
- Upstream `serialize()` returns a builder with `indent_prefix`, `no_indent` and `initial_indent_level`. `serialize_schema` and `serialize_document` take these as arguments and return a `String`.
- `serialize_document` prints only type system definitions. It raises an `Error` on an executable definition.
- Upstream makes temporary AST nodes for a schema and prints them. `serialize_schema` prints the components where they are. It copies a string from the source when the source is already the output, and it decodes other strings into one buffer. The output is the same.
- `validate_schema` and `validate_executable` are functions that return a `DiagnosticList`. Upstream `Schema::validate` returns `Result<Valid<Schema>, WithErrors<Schema>>`. `Valid` is not a type here.
- A diagnostic keeps the values of its variant as text, and only its primary location. Upstream keeps names, types and source spans, and draws labels with ariadne. A list is written as the `Error:` line and the `╭─[ file:line:column ]` line of each report.
- The executable build errors that upstream reports from validation (`SubscriptionUsesMultipleFields`, the `@defer` errors and the field merging conflicts) are kinds of `DiagnosticKind`. The schema and executable `BuildError` values are kept as their message.
- A `Valid<Schema>` upstream drops the built-in scalars that no field uses. Validation does not change the schema here.
- A syntax error raises a `GraphQLError`. apollo-parser recovers, reports each syntax error with its own message, and validates the rest. Six fixtures of `test_data/diagnostics/` fail for this reason: `0011`, `0017`, `0018`, `0020`, `0062` and `0111`.
- `parse_mixed_validate` copies the parsed document, once for the schema and once for the executable document. Upstream shares it.
- The checks that upstream runs with or without a schema walk the AST here. Each selection set gets its type as the builder finds it. Upstream walks the executable document. Some nodes are dropped by the builder: an undefined field, a subselection of a leaf type and an undefined type condition. The checks skip these nodes, because upstream does not have them. Subscription checks and field merging walk the executable document, as upstream does.
- The meta fields `__typename`, `__schema` and `__type` take their definitions from a small document that validation builds. Upstream uses static definitions.
- Field merging compares the list and non-null wrappers of two types as a code of 2 bits for each level. Two types with more than 31 levels of wrappers can compare as the same shape.
- Duplicate arguments are found by a scan for 8 arguments or fewer, and by a hash above that. Field merging compares argument lists by a scan for 20 arguments or fewer, and by a hash above that. Upstream always hashes.

## Tests

`tests/gql_compiler/test_extensions.mojo` ports `tests/extensions.rs`, without the calls to `validate`. `tests/gql_compiler/test_schema.mojo` ports two tests of `tests/schema.rs` and checks each `BuildError`. `tests/gql_compiler/test_executable.mojo` ports `tests/executable.rs`, without the calls to `validate`, and checks each executable `BuildError`.

`tests/gql_compiler/test_serialize.mojo` ports `test_schema_reserialize` of `tests/schema.rs`. It also ports `serialize_and_reparse_ast` of `tests/snapshot_tests.rs` for the 74 fixtures that hold only type system definitions. The fixtures are in `tests/gql_compiler/serializer_fixtures/`. `make coverage` copies only Mojo files, so the suite reads the fixtures from `_serializer_fixtures.mojo`. A test makes sure that this module is current. After you change a fixture, run `.venv/bin/mojo run -I . tests/gql_compiler/_embed_serializer.mojo` from the repository root.

`tests/gql_compiler/test_validation.mojo` ports `validation` of `tests/snapshot_tests.rs`. It reads the 48 fixtures of `test_data/ok/` and the 128 fixtures of `test_data/diagnostics/`. A case of `ok/` must have no diagnostic. For a case of `diagnostics/`, the `Error:` lines and the `╭─[ file:line:column ]` lines must be the lines of the upstream `.txt` file, in order. 170 of the 176 cases pass. The 6 other cases need the syntax error recovery of apollo-parser, and the suite lists them.

The fixtures are in `tests/gql_compiler/validation_fixtures/`, and the suite reads them from `_validation_fixtures.mojo`. After you change a fixture, run `.venv/bin/mojo run -I . tests/gql_compiler/_embed_validation.mojo` from the repository root.

`tests/gql_compiler/test_validation_mod.mojo` ports `tests/validation/mod.rs` and tests the diagnostics. `tests/gql_compiler/test_validate_schema.mojo` ports the schema tests of `tests/validation/object.rs`, `interface.rs` and `ignore_builtin_redefinition.rs`. `tests/gql_compiler/test_validate_executable.mojo` ports the executable tests of `tests/validation/`.

## Benchmarks

`bench/gql_compiler/schema_from_ast.mojo` builds the GitHub schema from its parsed AST. The Rust baseline times `Schema::builder().add_ast(&github).build()` with apollo-compiler. Both sides copy a builder that holds the built-in types on each run.

`bench/gql_compiler/executable_from_ast.mojo` builds the GitHub query against the GitHub schema. The Rust baseline times `ExecutableDocument::builder` with `add_ast_document` and `build`. The schema is built and the query is parsed outside the timer.

`bench/gql_compiler/schema_serialize.mojo` prints the GitHub schema. The Rust baseline times `schema.to_string()` with apollo-compiler. The schema is built outside the timer. [Benchmarks](Benchmarks) explains how each workload pairs with its baseline.

`bench/gql_compiler/validate.mojo` runs the eight executable validation benchmarks of apollo-compiler, as `apollo-compiler-validate/<name>`. `benches/fields_validation.rs` gives `many_same_field`, `many_same_nested_field`, `many_arguments`, `many_types` and `many_extensions`. `benches/fragments_validation.rs` gives `big_schema_many_fragments`. `benches/directives_validation.rs` gives `many_same_directive_query` and `many_invalid_directive`.

The schema is built and validated outside the timer. The timer covers `parse_and_validate_executable`, and the Rust baseline times `ExecutableDocument::parse_and_validate` under the same name. The same Rust workloads, as `apollo-compiler/<name>`, are compared with `gql_validation`.
