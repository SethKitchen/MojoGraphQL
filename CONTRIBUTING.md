<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Contributing

Open an issue before you start a large change. The project ports MIT licensed GraphQL libraries to Mojo, one feature at a time.

Every feature has one GitHub issue. The [README checklist](README.md#features) lists the features. Pick an open one, or open a new issue.

## Rules

- `make check` must pass before you commit.
- `make coverage` must stay at 100% for lines, branches, conditions and MC/DC.
- Each test must run in 5 seconds or less. `make test` fails a slower test. Make the code under test faster. Do not change the test.
- Every public symbol must have a docstring with `Args`, `Returns` and `Raises` sections.
- Every id, mode and kind must be a type with an `is_valid` method, not a bare integer. Examples are `TokenKind`, `Kind`, `Role`, `OperationType` and `DirectiveLocation`.
- Code must refuse a value that a type can hold but the code does not accept. Add a test that gives the wrong value.
- Documentation must follow the [writing rules](https://github.com/SethKitchen/MojoGraphQL/wiki/How-to-write-documentation). `make docs-check` enforces the rules that a tool can check.
- Write everything in American English: `color`, `center`, `gray`, `behavior`. That includes identifiers, docstrings and comments.

## Licenses of upstream code

Port only code that is MIT licensed. For a dual license, use the MIT arm. Never port code that is only Apache-2.0 licensed. Never port code under the Elastic License 2.0.

- Read the license of each upstream file before you port it. Some repositories mix licenses by directory or by file header.
- Record the upstream project and its revision in the `upstream` key of the package in `packages.toml`.
- Add a new upstream project to [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md), with its copyright line and revision.
- `@apollo/subgraph` imports `@apollo/federation-internals`, which is Elastic licensed. Implement that logic from the public federation specification and from Hive Federation Composition.

The excluded upstream files are listed in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md#exclusions).

## Mojo only

All the project tooling is Mojo. Do not add Python, shell scripts or another language to the tools. The tools are `tools/packages.mojo`, `tools/run_suite.mojo`, `tools/doc_lint.mojo`, `tools/bench.mojo` and the `coverage/` package.

The benchmark baselines in `bench/baselines/` are the exception. They run the upstream libraries in their own languages, because they measure those libraries.

## Packages

Each package is a top-level directory with an `__init__.mojo`. `packages.toml` lists each package with its `depends` and its `upstream`. A user can build one package and its closure, so a package must not import more than it needs.

- Add each new package to `packages.toml`.
- List every package that a package imports in its `depends` key.
- `make packages-check` fails for an import that is not listed, a cycle, or a directory that is not listed.
- Put tests in `tests/<package>/test_*.mojo` and benchmarks in `bench/<package>/`.

See [How to pick packages](https://github.com/SethKitchen/MojoGraphQL/wiki/How-to-pick-packages).

## Benchmarks

Each package with a hot path must have a benchmark against its upstream library. `make bench-check` must pass: Mojo must be faster than every baseline. When a baseline is faster, make the Mojo code faster. Do not make the workload smaller. See [Benchmarks](https://github.com/SethKitchen/MojoGraphQL/wiki/Benchmarks).

## Focused changes and checks

Keep each pull request focused on one feature or one correction. Use `PKG=<name>` to check the package that you change and the packages that depend on it. Do not drop selected tests or weaken coverage checks to make a run smaller.

Avoid changes to the Makefile and to the shared tools in a feature pull request. When a shared change is necessary, put it in a separate infrastructure pull request. Explain why it is necessary and what it changes.

## Upstream behavior and correctness

Keep the upstream API and behavior where they meet the documented contract. You can correct a proven upstream defect, even when the result differs from upstream. Correctness has priority over a copy of the defect. A speed gain alone does not prove an upstream defect.

For each correction:

1. Name the pinned upstream version and give a reproducible counterexample.
2. Check the corrected result against the GraphQL specification or another independent reference. Keep the original tests and workloads.
3. List the changed behavior in the "Differences" section of the module docstring and of its wiki page. State how it affects existing callers.
4. Keep tests for the corrected case and for the ordinary upstream behavior.

Do not claim exact upstream output when a documented correction changes it. A compatibility mode is a separate feature. It needs an explicit contract and tests for both modes. Do not add one only to keep a known defect.

## Add a feature

1. Open an issue, or take an open one from the checklist.
2. Write the module. Keep the upstream names where Mojo allows them.
3. Port the upstream tests. Cover every branch and every condition.
4. Add a benchmark when the feature has a hot path.
5. Run `make check`, `make coverage` and `make bench-check`.
6. Write or update the wiki page in `docs/wiki/`. Follow [How to add a feature](https://github.com/SethKitchen/MojoGraphQL/wiki/How-to-add-a-feature).
7. Tick the box in the README checklist and link it to the wiki page.
8. Commit. Close the issue in the commit message.

## Agent skills

`skills-lock.json` pins Modular skills that teach an AI agent to write Mojo. The lockfile is committed, and the skills are not. They are fetched with [`skills`](https://skills.sh), which any agent can use.

Restore the pinned skills after a clone:

```bash
npx skills experimental_install
```

Update them to the latest upstream, which writes a new lockfile:

```bash
npx skills update -p -y
```

The skills go into `.agents/skills/` or `.claude/skills/`, and git ignores both. Commit the lockfile when the hashes change, so everyone fetches the same revision. `computedHash` is a SHA-256 over every file in the skill folder. Do not edit it by hand.

## Commit messages

Write the first line as a statement of what the commit does, in fewer than 72 characters. Explain why in the body. Reference the issue.

## License

Your contribution is licensed on the same terms as the project. That includes the commercial licensing in [LICENSE-COMMERCIAL.md](LICENSE-COMMERCIAL.md).
