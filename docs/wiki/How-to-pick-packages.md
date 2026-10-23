<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# How to pick packages

Build only the package that you need with `make package PKG=<name>`. The command also builds the packages that it depends on, and nothing else.

## Find the package

`packages.toml` lists every package. Each entry has a `summary`, the packages that it imports in `depends`, and the upstream sources that it ports in `upstream`.

```toml
[packages.gql_language]
summary = "Source, lexer, parser, AST, printer and visitor"
depends = []
upstream = ["graphql-js 16.14.2 src/language (MIT)"]
```

The [README](https://github.com/SethKitchen/MojoGraphQL#pick-the-parts-you-need) has a table of the packages and their status. Today only `gql_language` exists.

The package tool can list the graph for you. `make` builds it into `.cache/bin/packages` on the first run.

```bash
.cache/bin/packages list                  # every package, in build order
.cache/bin/packages closure gql_language  # the package and what it needs
.cache/bin/packages dependents gql_language
```

## Build the package

Run this command from the repository root:

```bash
make package PKG=gql_language
```

The command runs `mojo precompile` once for each package in the closure. It writes one file for each package, such as `dist/gql_language.mojoc`. Without `PKG`, it builds every package.

## Use the package

Put the `dist/` folder on the import path of your program with `-I`:

```bash
mojo run -I /path/to/MojoGraphQL/dist my_program.mojo
```

Then import the modules as usual:

```mojo
from gql_language.parser import parse
```

A precompiled package loads only in the Mojo version that built it. Build it with the pinned Mojo `1.2.0`, and use the same version in your project.

## Use the sources instead

On another Mojo version, a `.mojoc` file does not load. Copy the source directories of the closure instead.

1. Get the closure: `.cache/bin/packages closure gql_language`.
2. Copy each directory in the closure into your project, such as `gql_language/`.
3. Put the folder that holds those directories on the import path with `-I`.

The project supports only Mojo `1.2.0`. The sources can need changes for another version.

## Why the closure is enough

`make packages-check` fails when a module imports a package that its entry in `packages.toml` does not list. It also fails for a dependency cycle. So the closure in `packages.toml` holds every package that the code imports.
