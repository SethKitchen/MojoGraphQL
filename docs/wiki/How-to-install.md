<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# How to install

Install Mojo `1.1.0` into a virtual environment in the repository, then run `make check`. The project needs no other toolchain.

## Requirements

- Linux on x86-64 or aarch64, macOS on Apple Silicon, or Windows with WSL 2.
- [uv](https://docs.astral.sh/uv/), to install Mojo.
- `git` and `make`.

The project does not need a GPU, MAX or Python code of its own. `uv` installs Mojo from the Python package index, but the project has no Python.

## Install on Linux or macOS

1. Clone the repository:

   ```bash
   git clone https://github.com/SethKitchen/MojoGraphQL.git
   cd MojoGraphQL
   ```

2. Install the pinned toolchain:

   ```bash
   uv venv && uv pip install "mojo==1.1.0"
   ```

3. Check the installation:

   ```bash
   .venv/bin/mojo --version
   make check
   ```

The version must be `1.1.0` (`8189361e`). The pin is exact. Mojo `1.0` does not compile the project, and the project does not support other versions.

## Install on Windows

Use WSL 2. Clone the repository on the Windows drive or in the Linux file system, and run every command in WSL.

From a Windows terminal, run one command in WSL like this:

```bash
wsl -e bash -lc 'cd /mnt/d/git/MojoGraphQL && make check'
```

Use `wsl -e` and not `wsl --`. Change the path to the location of your clone.

## Run the checks

`make check` runs the format check, the package graph check, the lint, the tests and the documentation check. It must pass before you commit.

```bash
make check
make coverage
make bench-check
```

Add `PKG=<name>` to check one package and the packages that depend on it. The first run builds the tools in `tools/` into `.cache/bin/`.

## Install the agent skills

The project pins Modular skills that teach an AI agent to write Mojo. Restore them after a clone:

```bash
npx skills experimental_install
```

This step is optional. It needs Node.js.
