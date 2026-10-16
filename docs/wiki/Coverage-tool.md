<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Coverage tool

`make coverage` measures line, branch, condition and MC/DC coverage of the library modules. It fails when one item is not covered. The tool is the Mojo package in `coverage/`.

## Run it

```bash
make coverage                    # every package
make coverage PKG=gql_language   # the package and its dependents
make coverage PKG=gql_language ONLY=1                       # the package alone
make coverage PKG=gql_schema COV_DIR=$HOME/cov/gql_schema   # build outside the checkout
```

With `PKG`, the tool instruments the library modules of the package and of every package that depends on it. It runs the test suites of the same packages.

With `ONLY=1`, the tool instruments and tests the package alone. Use it when a dependent package is not finished. Before a commit, run the target without `ONLY`.

`COV_DIR` sets the directory for the instrumented copies and the probe records. The default is `coverage/build/<package>`. Each test writes one record for each line that it runs. Thus a directory on the WSL file system is much faster than one on `/mnt/c` or `/mnt/d`.

## Pipeline

The `coverage` target of the Makefile does these steps:

1. It deletes `coverage/build/` and makes it again, with a `hits/` folder.
2. It copies every package file, the `coverage/` sources and every test file into `coverage/build/`, at the same paths.
3. It runs `coverage/build_cli.mojo`. That program writes an instrumented copy of each selected library module over its copy in `coverage/build/`. It also writes `coverage/build/manifest.txt`.
4. It runs each test suite from inside `coverage/build/`, in parallel. Each suite writes its probe records to standard error, into `hits/<suite>.txt`.
5. It runs `coverage/report_cli.mojo` on the manifest and the hits files. That program prints the report, and fails when coverage is not complete.

A test failure under instrumentation stops the run, and the target prints "Coverage not measured."

## Why the suites run inside the build folder

Mojo 1.1 finds a module beside the file that it compiles before it searches any `-I` path. A test that runs from the repository root imports the original modules. The Makefile runs each suite from inside `coverage/build/`, so the imports resolve to the instrumented copies.

## What the instrumenter measures

`coverage/scanner.mojo` decides which lines are executable statements. It skips blank lines, comments, docstrings, decorators, imports, field declarations, `def`, `struct` and `trait` headers, and the continuation lines of a statement.

`coverage/instrument.mojo` adds probes to the copies:

- **Lines.** It puts a `_cov_hit` call above each executable statement. The probe id holds the module and the original line number.
- **Branches.** It wraps the condition of each `if`, `elif` and `while`, and records each True and each False outcome. A `for` loop has two outcomes: the body ran, and the sequence was empty.
- **Conditions.** When a decision has `and` or `or` operands, it wraps each operand too. It keeps the operator precedence and the short-circuit evaluation.
- **MC/DC.** It records the complete vector of operand values for each evaluation of a compound decision.

## What the report counts

`coverage/report.mojo` divides the observed probe ids by the items in the manifest. Each decision and each condition counts two outcomes. It prints one line for each module with lines, branches and MC/DC, and then a total.

- A line that never ran is listed under "never executed".
- A decision or condition with one outcome only is listed as "never evaluated True" or "never evaluated False".
- An operand without an independence pair is listed as "no MC-DC independence pair".

## MC/DC

MC/DC asks that each operand change the decision alone. For operand `i`, two evaluations must have different outcomes, where `i` differs and no other operand differs.

Short-circuit evaluation makes this strict form impossible for most compound decisions. So `coverage/mcdc.mojo` uses the masking form. An operand that was not evaluated in one of the two evaluations does not count as a change. An evaluation that does not complete, such as one that raises, gives condition hits but no MC/DC evidence.

## Probe records

Each function with compound decisions has a private operand buffer, so recursion and concurrent calls do not mix their records. `coverage/runtime.mojo` writes each record with one write of 512 bytes or fewer. That is the POSIX minimum of `PIPE_BUF`, so records from parallel writers do not mix. A failed or short write stops the suite, so missing data cannot pass.

## Get to 100%

Read the report lines under each module. Add a test that runs the line, or that gives the missing outcome. Do not exclude code from the measurement, and do not weaken the check.
