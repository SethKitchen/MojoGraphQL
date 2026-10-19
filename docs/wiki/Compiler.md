<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Compiler

`gql_compiler` ports the schema model of apollo-compiler 1.33.0, the semantic layer of apollo-rs (`b7eee5c`). The port uses the MIT arm of the MIT OR Apache-2.0 license. It depends only on `gql_language`.

| Module | Contents |
| --- | --- |
| `gql_compiler.schema` | `Schema`, `ExtendedType`, `TypeKind`, `Component`, `Members`, `DirectiveDefinition`, `RootOperation`, `BuildError`, `BuildErrorKind` |
| `gql_compiler.from_ast` | `SchemaBuilder` |
| `gql_compiler.built_in` | `BUILT_IN_TYPES`, the upstream `built_in_types.graphql` |

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

## Differences from upstream

- A `Component` names an AST node by index. Upstream holds a reference counted pointer.
- `add_ast` takes the document by value. Upstream shares it through `Arc`.
- Upstream keeps the built-in types in a static `OnceLock`. Mojo has no globals. `SchemaBuilder.built_in()` returns a builder that a caller can keep and copy.
- A type with fewer than 8 members finds a member by a scan. A larger type uses a hash. Upstream always hashes.
- `parse` raises a `GraphQLError` on a syntax error. Upstream records the error in its diagnostics.
- The GraphQL directive extension is an error, with the description "a directive extension". apollo-parser does not parse it.
- Validation, `ExecutableDocument` and the schema printer are not ported yet.

## Tests

`tests/gql_compiler/test_extensions.mojo` ports `tests/extensions.rs`, without the calls to `validate`. `tests/gql_compiler/test_schema.mojo` ports two tests of `tests/schema.rs` and checks each `BuildError`.

## Benchmarks

`bench/gql_compiler/schema_from_ast.mojo` builds the GitHub schema from its parsed AST. The Rust baseline times `Schema::builder().add_ast(&github).build()` with apollo-compiler. Both sides copy a builder that holds the built-in types on each run. [Benchmarks](Benchmarks) explains how each workload pairs with its baseline.
