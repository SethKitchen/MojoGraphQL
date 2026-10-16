<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# How to add a feature

Port one feature from one MIT licensed upstream file at a time. Port its tests, cover every condition, prove that it is faster, and document it.

## 1. Choose the feature and check the license

1. Take an open box in the [README checklist](https://github.com/SethKitchen/MojoGraphQL#features), or open an issue for a new feature.
2. Find the upstream file. Read its license header and the license file of its directory.
3. Continue only if the file is MIT licensed, or MIT under a dual license. Stop for code that is only Apache-2.0, or Elastic License 2.0.
4. Write down the upstream revision, such as `v16.14.2` or a commit hash.

The excluded upstream files are listed in `THIRD-PARTY-NOTICES.md`. For `@apollo/subgraph`, never read `@apollo/federation-internals`. Use the public federation specification and Hive Federation Composition.

## 2. Find or make the package

Put the feature in the package that ports its upstream. When the package does not exist, make it:

1. Make a top-level directory with an `__init__.mojo`. Give the directory a `gql_` name, such as `gql_schema`.
2. Add a `[packages.<name>]` entry to `packages.toml` with `summary`, `depends` and `upstream`.
3. List only the packages that the code imports in `depends`.
4. Add the upstream project to `THIRD-PARTY-NOTICES.md` when it is new.

Run `make packages-check`. It fails when the graph and the imports do not agree.

## 3. Write the module

- Keep the upstream names, in Mojo style: `parseValue` becomes `parse_value`.
- Keep the upstream behavior and the error messages, byte for byte.
- Make each id, mode and kind a type with an `is_valid` method.
- Give every public symbol a docstring with `Args`, `Returns` and `Raises`.
- Name the upstream file and version in the module docstring.
- List each difference from upstream in a "Differences" paragraph of the module docstring.

A difference must have a reason. A proven upstream defect is one reason. The correction process is in [CONTRIBUTING.md](https://github.com/SethKitchen/MojoGraphQL/blob/main/CONTRIBUTING.md#upstream-behavior-and-correctness).

## 4. Port the tests

1. Make `tests/<package>/test_<module>.mojo`.
2. Port each upstream test case. Keep the upstream inputs and the expected outputs.
3. When an upstream case cannot apply to Mojo, say why in the module docstring.
4. Add tests until `make coverage PKG=<package>` reports 100%.

Each test must run in 5 seconds or less. When a test is slower, make the library faster. Do not change the test.

## 5. Add a benchmark

A feature on a hot path needs a benchmark, such as a parser, a validator or an executor.

1. Make `bench/<package>/<name>.mojo`.
2. Use the same fixtures as the upstream baselines, from `bench/fixtures/`.
3. Add the baseline for each upstream that has the feature, in `bench/baselines/`.
4. Run `make bench-check PKG=<package>`. Mojo must be faster than each baseline.

See [Benchmarks](Benchmarks) for the method.

## 6. Check everything

```bash
make check PKG=<package>
make coverage PKG=<package>
make bench-check PKG=<package>
```

All three must pass. Then run `make check` without `PKG` once.

## 7. Document the feature

1. Add the feature to the reference page of the package in `docs/wiki/`. Make the page when it does not exist.
2. Copy each difference from upstream into the "Differences" section of the page.
3. Follow [How to write documentation](How-to-write-documentation), and run `make docs-check`.
4. Tick the box in the README checklist, and link it to the section of the wiki page.

## 8. Commit

Write the first line as a statement of what the commit does. Close the issue in the commit message.
