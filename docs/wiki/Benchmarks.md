<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Benchmarks

Each MojoGraphQL port must be faster than the upstream library that it ports. The benchmarks measure each implementation with the same method on the same input. `make bench-check` fails when a baseline is faster than Mojo.

## Why the rule exists

A port to Mojo is useful only when it is faster than the library that it replaces. A benchmark that runs with every change keeps a slow change from going in unseen. So the rule is a check, like the tests and the coverage.

When a baseline is faster, make the Mojo code faster. Do not make the workload smaller, and do not change the fixture.

## Run the benchmarks

```bash
make bench                         # run all, write bench/RESULTS.md
make bench-check                   # also fail when a baseline is faster
make bench PKG=gql_language        # one package and its dependents
```

The baselines need Node.js and npm, Cargo, and Go. `tools/bench.mojo` looks for them on `PATH`, then in `~/node/bin`, `~/.cargo/bin` and `~/go-sdk/go/bin`.

## Baselines

| Baseline | Language | Directory |
| --- | --- | --- |
| graphql-js 16.14.2 | JavaScript, on Node.js | `bench/baselines/js` |
| apollo-parser 0.8.6, from apollo-rs | Rust, a concrete syntax tree | `bench/baselines/rust` |
| apollo-compiler 1.33.0, from apollo-rs | Rust, an AST | `bench/baselines/rust` |
| graphql-go-tools 2.28.0 | Go | `bench/baselines/go` |
| Apollo Client 4.3.3 `InMemoryCache`, for `gql_client` | JavaScript, on Node.js, the production build | `bench/baselines/js-client` |

A baseline runs only the workloads that its library has. For example, apollo-parser has no printer, so it has no `print` workloads.

## Method

Every program, Mojo or baseline, uses the same method for each workload:

1. It reads the fixture from `bench/fixtures/`.
2. It warms up for 200 ms.
3. It runs 5 timed rounds. Each round lasts at least one second.
4. It reports the fastest round, as nanoseconds for one operation.

The fastest round is the time with the least noise from the machine. Each program prints one line for each workload: `BENCH <workload> <nanoseconds per op>`.

`tools/bench.mojo` builds each `bench/<package>/*.mojo` in release mode, and runs it from the repository root. Then it builds and runs each baseline, one at a time, from its own directory. No two programs run at the same time.

## Fixtures

All implementations read the same bytes. The fixtures are in `bench/fixtures/`, and its `README.md` gives the origin of each file.

- `kitchen-sink.graphql` and `github-schema.graphql` come from graphql-js 16.14.2 `benchmark/`. Do not change them.
- `github-query.graphql` is a MojoGraphQL query that is valid against the GitHub schema.

## Workloads

- `parse/<fixture>` parses the text into a document.
- `print/<fixture>` parses the text and prints the document again, as graphql-js `print(parse(text))`.

## Like for like

A workload compares two libraries only when both do the same work. A schema build is the main case:

- `graphql-js/build-ast-schema` runs graphql-js `buildASTSchema`. It resolves every type reference and orders the type map. `gql_schema` does the same work, so it is compared with graphql-js.
- `apollo-compiler/schema-from-ast` runs apollo-compiler `Schema::builder().add_ast(&ast).build()`. It points into the AST and resolves no types. `gql_compiler` ports that model, so it is compared with apollo-compiler.
- `apollo-compiler/executable-from-ast` runs apollo-compiler `ExecutableDocument::builder` with `add_ast_document` and `build`, on the GitHub query against the GitHub schema. It resolves each field definition and does not validate. `gql_compiler.executable` ports that model, so it is compared with apollo-compiler.
- `apollo-compiler/schema-serialize` runs apollo-compiler `schema.to_string()` on the GitHub schema. The schema is built outside the timer. `gql_compiler.serialize` ports that printer, so it is compared with apollo-compiler.
- `apollo-compiler-validate/<name>` runs the same `ExecutableDocument::parse_and_validate` as `apollo-compiler/<name>`, for the eight executable validation benchmarks of apollo-compiler. The Rust baseline times each closure under both names. `gql_compiler` ports that validation, so it is compared with apollo-compiler under the `apollo-compiler-validate/` name. `gql_validation` is compared under the `apollo-compiler/` name.

Until `gql_compiler` existed, the apollo-compiler build was a baseline of `graphql-js/build-ast-schema`. That pairing compared different work, so it moved to its own workload.

## Results

`make bench` writes `bench/RESULTS.md`. It has one table for each workload, with the time of each implementation and its speedup. It also names the machine and the toolchains. The speedup is the baseline time divided by the Mojo time, so a speedup above 1.00 means that Mojo is faster.

Do not edit `bench/RESULTS.md` by hand. Numbers from different machines are not comparable.

## The check

`make bench-check` fails when a baseline is faster than Mojo on a workload that both run. It names each such workload. It also fails when a baseline does not build or prints no results, because a missing comparison is not a pass.

## Add a benchmark

1. Make `bench/<package>/<name>.mojo`. Use the method above, and print one `BENCH` line for each workload.
2. Add the same workload to each baseline whose library has the feature.
3. Use the existing fixtures where you can. Record the origin of a new fixture in `bench/fixtures/README.md`.
4. Run `make bench-check PKG=<package>`.
