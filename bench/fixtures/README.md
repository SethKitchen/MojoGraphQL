# Benchmark fixtures

The benchmarks in `bench/` read these GraphQL documents and JSON texts. Every implementation reads the same bytes. Do not change a file that comes from an upstream project: the comparison with that project depends on the same input.

## Files from upstream projects

Each file is a byte-for-byte copy of an upstream file or of a string literal in an upstream benchmark. The revision is the commit of the upstream clone that the file came from. Each file is also the same as in the release that the baselines pin.

| File | Project | Upstream path | Revision | License |
|---|---|---|---|---|
| `kitchen-sink.graphql` | graphql-js 16.14.2 | `benchmark/kitchen-sink.graphql` | `dca5b4d` (tag `v16.14.2`) | MIT |
| `github-schema.graphql` | graphql-js 16.14.2 | `benchmark/github-schema.graphql` | `dca5b4d` (tag `v16.14.2`) | MIT |
| `graphql-js-introspection-query.graphql` | graphql-js 16.14.2 | `getIntrospectionQuery()` of `src/utilities/getIntrospectionQuery.ts`, as `benchmark/parser-benchmark.js` calls it | `dca5b4d` (tag `v16.14.2`) | MIT |
| `apollo-parser-query.graphql` | apollo-parser 0.8.6 | the `query` string literal in `crates/apollo-parser/benches/query.rs` | `b7eee5c` | MIT OR Apache-2.0, used under MIT |
| `apollo-parser-alias.graphql` | apollo-parser 0.8.6 | `crates/apollo-parser/benches/testdata/alias.graphql` | `b7eee5c` | MIT OR Apache-2.0, used under MIT |
| `apollo-parser-supergraph.graphql` | apollo-parser 0.8.6 | `crates/apollo-parser/test_data/parser/ok/0032_supergraph.graphql` | `b7eee5c` | MIT OR Apache-2.0, used under MIT |
| `apollo-compiler-simple-schema.graphql` | apollo-compiler 1.33.0 | `crates/apollo-compiler/benches/testdata/simple_schema.graphql` | `b7eee5c` | MIT OR Apache-2.0, used under MIT |
| `apollo-compiler-simple-query.graphql` | apollo-compiler 1.33.0 | `crates/apollo-compiler/benches/testdata/simple_query.graphql` | `b7eee5c` | MIT OR Apache-2.0, used under MIT |
| `apollo-compiler-supergraph-query.graphql` | apollo-compiler 1.33.0 | `crates/apollo-compiler/benches/testdata/supergraph_query.graphql` | `b7eee5c` | MIT OR Apache-2.0, used under MIT |
| `go-tools-starwars.schema.graphql` | graphql-go-tools v2.28.0 | `v2/pkg/astparser/testdata/starwars.schema.graphql` | `9ef6e24` | MIT |
| `go-tools-github.schema.graphql` | graphql-go-tools v2.28.0 | `v2/pkg/astparser/testdata/github.schema.graphql` | `9ef6e24` | MIT |
| `go-tools-selection-set.graphql` | graphql-go-tools v2.28.0 | the `selectionSet` literal in `v2/pkg/astparser/parser_test.go` | `9ef6e24` | MIT |
| `go-tools-introspection-query.graphql` | graphql-go-tools v2.28.0 | the `introspectionQuery` literal in `v2/pkg/astparser/parser_test.go`; the literal of the same name in `v2/pkg/lexer/lexer_test.go` is the same text | `9ef6e24` | MIT |
| `go-tools-kitchen-sink.graphql` | graphql-go-tools v2.28.0 | the `kitchenSinkData` literal in `v2/pkg/astparser/parser_test.go` | `9ef6e24` | MIT |
| `go-tools-parse-input.graphql` | graphql-go-tools v2.28.0 | the `inputBytes` literal in `v2/pkg/astparser/parser_test.go` | `9ef6e24` | MIT |
| `go-tools-print-operation.graphql` | graphql-go-tools v2.28.0 | the `benchmarkTestOperation` literal in `v2/pkg/astprinter/astprinter_test.go` | `9ef6e24` | MIT |
| `github-schema.json` | graphql-js 16.14.2 | `benchmark/github-schema.json`, the introspection result of the GitHub schema | `dca5b4d` (tag `v16.14.2`) | MIT |
| `hive-huge-schema/*.graphql` | Hive Federation Composition v0.27.0 | `__tests__/fixtures/huge-schema/*.graphql` (191 files, one subgraph each) | `6272ad8` (tag `v0.27.0`) | MIT |
| `hive-dgs/*.graphql` | Hive Federation Composition v0.27.0 | `__tests__/fixtures/dgs/*.graphql` (11 files, one subgraph each) | `6272ad8` (tag `v0.27.0`) | MIT |
| `hive-stars-stuff/*.graphql` | Hive Federation Composition v0.27.0 | the `typeDefs` template literals of `__tests__/fixtures/stars-stuff.ts`, one file per subgraph name | `6272ad8` (tag `v0.27.0`) | MIT |
| `hive-basic/*.graphql` | Hive Federation Composition v0.27.0 | the `typeDefs` template literals of `basicServices` in `benchmark.ts`, one file per subgraph name | `6272ad8` (tag `v0.27.0`) | MIT |

Notes:

- The apollo-rs clone is at `main`. The copied files are the same as in the published crates `apollo-parser` 0.8.6 and `apollo-compiler` 1.33.0.
- The graphql-go-tools clone is at `master`. The copied files are the same as in the module `github.com/wundergraph/graphql-go-tools/v2` v2.28.0.
- apollo-compiler `benches/testdata/supergraph.graphql` is the same file as `apollo-parser-supergraph.graphql`, so there is one copy.
- `graphql-js-introspection-query.graphql` is the output of `getIntrospectionQuery()` with no options, from the `graphql` package 16.14.2.
- `apollo-parser-query.graphql` is the Rust string literal with its `\n` escapes decoded. `query_parser` and `query_lexer` use the same literal.
- Go raw string literals hold the bytes between the backquotes, so the Go fixtures are those bytes.
- The Hive template literals have no substitutions and no escapes, so the Hive fixtures are the bytes between the backquotes. The file name is the subgraph name.

## Licenses

The MIT License of each project gives these copyright notices:

- graphql-js: Copyright (c) GraphQL Contributors
- apollo-rs: Copyright 2021 Apollo Graph, Inc.
- graphql-go-tools: Copyright (c) 2022 WunderGraph UG (haftungsbeschränkt)
- Hive Federation Composition: Copyright (c) 2023 The Guild

`go-tools-kitchen-sink.graphql` also starts with its own comment, "Copyright (c) 2015-present, Facebook, Inc.", because it is an early copy of the graphql-js kitchen sink.

The permission notice of the MIT License is the same for the four projects:

```text
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## The MojoGraphQL file

`github-query.graphql` is a MojoGraphQL file under the license of this repository. It is a repository dashboard for `github-schema.graphql`. It has four operations, 12 fragments, variables with default values, aliases, directives, inline fragments, and nesting of up to six levels. It is valid against `github-schema.graphql`: graphql-js `validate` reports no errors.

If you change it, validate it again against the schema. Then run `make bench` again, because the old results are then not comparable.

## The MojoGraphQL MCP files

`mcp-operations.graphql` and `mcp-large-operation.graphql` are MojoGraphQL files under the license of this repository. The gql_mcp benchmarks use them with `github-schema.graphql`.

- `mcp-operations.graphql` has 200 named queries: 20 copies of 10 query shapes, with the numbers `01` to `20` in their names. A blank line separates two operations. The benchmark driver writes each operation to its own file, because Apollo MCP Server reads one operation from each file.
- `mcp-large-operation.graphql` is one query with 38 variables, input objects, enums, lists, default values, a fragment, aliases, inline fragments on a union and on interfaces, and nesting of up to five levels.

Both files are valid against `github-schema.graphql`: the `validate` tool of Apollo MCP Server 2.0.0 reports `Operation is valid` for each operation.

## The MojoGraphQL JSON files

`small-response.json` and `variables.json` are MojoGraphQL files under the license of this repository. The `gql_json` benchmarks read them.

- `small-response.json` is a typical GraphQL response of 2 KB: one repository of `github-schema.graphql`, with nested objects, lists, numbers, booleans and `null`.
- `variables.json` is a typical `variables` object of a request: strings, numbers, a list, `null` and a nested input object.

If you change one of them, run `make bench` again, because the old results are then not comparable.

## The MojoGraphQL client cache file

`client-items-1000.json` is a MojoGraphQL file under the license of this repository. The `gql_client` benchmarks and the Apollo Client baseline in `bench/baselines/js-client/` read it.

- It is the `data` of the query `{ items { id title price inStock tags author { id name } stats { views likes } } }`: 1000 `Item` objects with an `id`, each with an `Author` entity (50 different ids) and an embedded `Stats` object.
- Every object has a `__typename`, as a query that `transformDocument` changed gives it.
