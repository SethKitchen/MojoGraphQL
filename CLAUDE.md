<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# MojoGraphQL: rules for AI assistants and contributors

MojoGraphQL ports MIT licensed GraphQL libraries to Mojo. Read the [README](README.md) first and [CONTRIBUTING.md](CONTRIBUTING.md) second. The wiki source is `docs/wiki/`.

## Language

- Write American English everywhere: `color`, `center`, `gray`, `behavior`, `-ize`. `make docs-check` flags British spellings in the documentation.
- Write documentation in Simplified Technical English (ASD-STE100). Short sentences, one instruction per sentence, active voice, "must" and "can". See [How to write documentation](https://github.com/SethKitchen/MojoGraphQL/wiki/How-to-write-documentation).
- Put the main point first, in every page and every section.
- Keep the Diátaxis types apart: a tutorial teaches, a how-to solves a task, a reference states, an explanation says why.

## Code

- `make check` must pass before a commit. `make coverage` must stay at 100% for lines, branches, conditions and MC/DC.
- Each test must run in 5 seconds or less (`TEST_TIMEOUT`). When a test is slower, make the library faster. Do not change the test.
- Every public symbol has a docstring with `Args`, `Returns` and `Raises`.
- Every id, mode and kind is a type with `is_valid`, not a bare integer: `TokenKind`, `Kind`, `Role`, `OperationType`, `DirectiveLocation`.
- Keep the upstream API, names and behavior. A change from upstream needs the correction process in CONTRIBUTING.md, and a "Differences from upstream" entry in the module docstring and the wiki page.
- Tests are `tests/<package>/test_*.mojo`. Port them from the upstream test suite where one exists, and name the upstream file in the module docstring.

## Packages

- Each package is a top-level directory with an `__init__.mojo`, listed in `packages.toml` with its `depends` and `upstream`.
- A package imports only the packages that it lists. `make packages-check` enforces this, and refuses a cycle.
- A user builds one package and its closure with `make package PKG=<name>`. Do not add an import that pulls in a package the user did not ask for.
- A package with a hot path has a benchmark in `bench/<package>/` against its upstream. `make bench-check` must pass: Mojo must be faster than every baseline.

## Licensing

- Port only MIT code, or the MIT arm of a dual license. Never port code that is only Apache-2.0, and never port Elastic License 2.0 code.
- `@apollo/subgraph` imports `@apollo/federation-internals`, which is Elastic licensed. Implement federation logic from the public specification and from Hive Federation Composition (MIT), never from `internals-js`.
- Record the upstream revision of each port in `packages.toml` and in `THIRD-PARTY-NOTICES.md`. The excluded files are listed there.

## Tooling

- All the tooling is Mojo: `tools/packages.mojo`, `tools/run_suite.mojo`, `tools/doc_lint.mojo`, `tools/bench.mojo` and `coverage/`. Do not add Python, or any other language, to the project.
- The benchmark baselines in `bench/baselines/` run the upstream libraries in their own languages. They are measurements, not tooling.

## Toolchain

The pin is exact: Mojo `1.2.0` (`2016d0cd`), installed with
`uv venv && uv pip install "mojo==1.2.0"`. It is a pin and not a floor,
because one source cannot serve two minor versions. These things moved in 1.1
and 1.2, and they are easy to write back the old way by habit:

- `TaskGroup` is `from std.runtime._asyncrt import TaskGroup`. The public
  `std.runtime` keeps only `parallelism_level` and `initialize_runtime`, and
  nothing public in `std` runs work on a thread pool. This is one of two places
  the project reaches past a leading underscore. 1.0 has no `_asyncrt`; 1.1 and
  1.2 have no `asyncrt`.
- `Hasher` is `from std.hash import Hasher`. In 1.1 it was in `std.hashlib`.
- A transfer sigil (`^`) on a value passed to a borrowed (`imm`) argument is a
  compile error in 1.2, including `String(unsafe_from_utf8=bytes)`.
- A module beside the file being compiled is found before any `-I` path.
  That is why `make coverage` runs the suites from inside `coverage/build/`,
  beside the instrumented copies.
- `mojo package` is deprecated. `mojo precompile <dir> -o <name>.mojoc`
  builds a package, and the output must end in `.mojoc`. A precompiled
  package loads only in the compiler version that built it.
