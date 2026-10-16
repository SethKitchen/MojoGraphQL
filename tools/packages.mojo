# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Read the package graph in packages.toml, and enforce it.

    packages list                  every package, in build order
    packages closure PKG...        PKG and what it needs
    packages dependents PKG...     PKG and what needs it
    packages sources PKG...        library modules of PKG
    packages files PKG...          every Mojo file of PKG, __init__ included
    packages tests PKG...          test suites of PKG
    packages benches PKG...        benchmark programs of PKG
    packages check                 the graph rules

A package is a top-level directory with an `__init__.mojo`. Its tests are
`tests/<package>/test_*.mojo` and its benchmarks `bench/<package>/*.mojo`.

A test or a benchmark can also import a `_` helper module beside it.

`check` fails when a package directory is not listed, an entry has no
directory, a dependency names no package, the dependencies form a cycle, a
library module imports a package its package does not list, or a test or a
benchmark imports a package outside its package's closure. These rules let
a user build one package with only its closure.

packages.toml uses a subset of TOML: `[packages.<name>]` tables whose keys
hold a string or a one-line list of strings.
"""

from std.os import listdir
from std.os.path import isdir, isfile
from std.pathlib import Path
from std.sys import argv


# Top-level directories that hold Mojo but are not packages.
def _is_tool_directory(name: StringSlice) -> Bool:
    """Return True for the top-level directories that are not packages."""
    return (
        name == "coverage"
        or name == "tests"
        or name == "tools"
        or name == "bench"
    )


struct Graph(Movable):
    """The packages and the packages each one depends on."""

    var names: List[String]
    """Every package, in file order."""
    var depends: List[List[String]]
    """The dependencies of each package, by index into `names`."""

    def __init__(out self):
        """Start with no packages."""
        self.names = List[String]()
        self.depends = List[List[String]]()

    def index(self, name: StringSlice) -> Int:
        """Return a package's index, or -1.

        Args:
            name: The package name.

        Returns:
            Its position in `names`, or -1 when it is not listed.
        """
        for position in range(len(self.names)):
            if self.names[position] == name:
                return position
        return -1


def _strings(value: StringSlice) raises -> List[String]:
    """Parse `"a"` or `["a", "b"]` into strings."""
    var out = List[String]()
    var text = String(value.strip())
    var inside = False
    var current = String("")
    for codepoint in text.codepoint_slices():
        if codepoint == '"':
            if inside:
                out.append(current)
                current = String("")
            inside = not inside
        elif inside:
            current += codepoint
    if inside:
        raise Error("packages.toml: unterminated string: " + text)
    return out^


def load(path: String) raises -> Graph:
    """Read packages.toml.

    Args:
        path: The manifest's path.

    Returns:
        The package graph.

    Raises:
        Error: If the file cannot be read or is not the supported subset.
    """
    var graph = Graph()
    var current = -1
    for raw in Path(path).read_text().splitlines():
        var line = String(raw.strip())
        if line == "" or line.startswith("#"):
            continue
        if line.startswith("[packages.") and line.endswith("]"):
            var name = String(line[byte = 10 : line.byte_length() - 1])
            if graph.index(name) >= 0:
                raise Error("packages.toml: " + name + " is listed twice")
            graph.names.append(name)
            graph.depends.append(List[String]())
            current = len(graph.names) - 1
            continue
        var equals = line.find("=")
        if equals < 0 or current < 0:
            raise Error("packages.toml: cannot read: " + line)
        var key = String(line[byte=0:equals].strip())
        if key == "depends":
            graph.depends[current] = _strings(line[byte = equals + 1 :])
    return graph^


def order(graph: Graph) raises -> List[String]:
    """Return the packages with each dependency before its dependents.

    Args:
        graph: The package graph.

    Returns:
        The names in build order.

    Raises:
        Error: If a dependency is unknown or the graph has a cycle.
    """
    var state = List[Int](length=len(graph.names), fill=0)
    var out = List[String]()
    for start in range(len(graph.names)):
        _visit(graph, start, state, out, List[String]())
    return out^


def _visit(
    graph: Graph,
    node: Int,
    mut state: List[Int],
    mut out: List[String],
    var trail: List[String],
) raises:
    """Depth-first visit: 0 new, 1 active, 2 done."""
    if state[node] == 2:
        return
    trail.append(graph.names[node])
    if state[node] == 1:
        var text = String("")
        for index in range(len(trail)):
            if index > 0:
                text += " -> "
            text += trail[index]
        raise Error("dependency cycle: " + text)
    state[node] = 1
    for ref dep in graph.depends[node]:
        var next = graph.index(dep)
        if next < 0:
            raise Error(graph.names[node] + " depends on unknown " + dep)
        _visit(graph, next, state, out, trail.copy())
    state[node] = 2
    out.append(graph.names[node])


def closure(graph: Graph, names: List[String]) raises -> List[String]:
    """Return the names and everything they need, in build order.

    Args:
        graph: The package graph.
        names: The packages wanted.

    Returns:
        The closure in build order.

    Raises:
        Error: If a name is not a package.
    """
    var need = List[Bool](length=len(graph.names), fill=False)
    var stack = names.copy()
    while len(stack) > 0:
        var name = stack.pop()
        var index = graph.index(name)
        if index < 0:
            raise Error("unknown package: " + name)
        if not need[index]:
            need[index] = True
            for ref dep in graph.depends[index]:
                stack.append(dep)
    var out = List[String]()
    for ref name in order(graph):
        if need[graph.index(name)]:
            out.append(name)
    return out^


def dependents(graph: Graph, names: List[String]) raises -> List[String]:
    """Return the names and every package that needs one of them.

    Args:
        graph: The package graph.
        names: The packages changed.

    Returns:
        The affected packages in build order.

    Raises:
        Error: If a name is not a package.
    """
    for ref name in names:
        if graph.index(name) < 0:
            raise Error("unknown package: " + name)
    var out = List[String]()
    for ref name in order(graph):
        for ref needed in closure(graph, [name]):
            if needed in names:
                out.append(name)
                break
    return out^


def walk(directory: String, mut out: List[String]) raises:
    """Append every `.mojo` file under a directory, sorted.

    Args:
        directory: The directory, relative to the working directory.
        out: The destination.

    Raises:
        Error: If the directory cannot be listed.
    """
    var entries = listdir(directory)
    sort(entries)
    for ref entry in entries:
        var path = directory + "/" + entry
        if isdir(path):
            walk(path, out)
        elif entry.endswith(".mojo"):
            out.append(path)


def files(name: String, with_init: Bool) raises -> List[String]:
    """Return the Mojo files of a package.

    Args:
        name: The package.
        with_init: Include the `__init__.mojo` files.

    Returns:
        The paths, sorted.

    Raises:
        Error: If the directory cannot be listed.
    """
    var all = List[String]()
    walk(name, all)
    if with_init:
        return all^
    var out = List[String]()
    for ref path in all:
        if not path.endswith("/__init__.mojo"):
            out.append(path)
    return out^


def tests(name: String) raises -> List[String]:
    """Return the test suites of a package: `tests/<name>/test_*.mojo`.

    Args:
        name: The package.

    Returns:
        The paths, sorted.

    Raises:
        Error: If the directory cannot be listed.
    """
    var out = List[String]()
    var directory = "tests/" + name
    if not isdir(directory):
        return out^
    var entries = listdir(directory)
    sort(entries)
    for ref entry in entries:
        if entry.startswith("test_") and entry.endswith(".mojo"):
            out.append(directory + "/" + entry)
    return out^


def benches(name: String) raises -> List[String]:
    """Return the benchmark programs of a package: `bench/<name>/*.mojo`.

    Args:
        name: The package.

    Returns:
        The paths, sorted, without `_` helpers.

    Raises:
        Error: If the directory cannot be listed.
    """
    var out = List[String]()
    var directory = "bench/" + name
    if not isdir(directory):
        return out^
    var entries = listdir(directory)
    sort(entries)
    for ref entry in entries:
        if not entry.startswith("_") and entry.endswith(".mojo"):
            out.append(directory + "/" + entry)
    return out^


def imports(path: String) raises -> List[String]:
    """Return the top-level modules a Mojo file imports.

    Lines inside triple-quoted strings are examples and are skipped.

    Args:
        path: The file.

    Returns:
        The module names, in order, each once.

    Raises:
        Error: If the file cannot be read.
    """
    var out = List[String]()
    var in_string = False
    for raw in Path(path).read_text().splitlines():
        var line = String(raw.strip())
        var quotes = line.count('"""')
        if in_string:
            if quotes % 2 == 1:
                in_string = False
            continue
        if quotes % 2 == 1:
            in_string = True
            continue
        var rest: String
        if line.startswith("from "):
            rest = String(line[byte=5:])
        elif line.startswith("import "):
            rest = String(line[byte=7:])
        else:
            continue
        var module = String("")
        for codepoint in rest.codepoint_slices():
            if codepoint == "." or codepoint == " " or codepoint == ",":
                break
            module += codepoint
        if module != "" and not module in out:
            out.append(module)
    return out^


def check(graph: Graph) raises -> List[String]:
    """Return every violation of the graph rules.

    Args:
        graph: The package graph.

    Returns:
        One message per violation; empty when the graph holds.

    Raises:
        Error: If a file cannot be read.
    """
    var problems = List[String]()
    var found = List[String]()
    var entries = listdir(".")
    sort(entries)
    for ref entry in entries:
        if isfile(entry + "/__init__.mojo") and not _is_tool_directory(entry):
            found.append(entry)
    for ref name in found:
        if graph.index(name) < 0:
            problems.append(name + "/ is a package missing from packages.toml")
    for ref name in graph.names:
        if not name in found:
            problems.append(
                "packages.toml lists " + name + ", which has no directory"
            )
    if len(problems) > 0:
        return problems^
    try:
        _ = order(graph)
    except e:
        problems.append(String(e))
        return problems^
    for index in range(len(graph.names)):
        var name = graph.names[index]
        var allowed: List[String] = ["std", name]
        for ref dep in graph.depends[index]:
            allowed.append(dep)
        for ref path in files(name, True):
            for ref module in imports(path):
                if not module in allowed:
                    problems.append(
                        path
                        + " imports "
                        + module
                        + ", which "
                        + name
                        + " does not depend on"
                    )
        var wide: List[String] = ["std"]
        for ref needed in closure(graph, [name]):
            wide.append(needed)
        var programs = tests(name)
        programs.extend(benches(name))
        for ref path in programs:
            for ref module in imports(path):
                # A `_` module beside a suite is that suite's own helper.
                if not module in wide and not module.startswith("_"):
                    problems.append(
                        path
                        + " imports "
                        + module
                        + ", outside the closure of "
                        + name
                    )
    return problems^


def _print_lines(lines: List[String]):
    """Print one entry per line."""
    for ref line in lines:
        print(line)


def main() raises:
    """Run one command."""
    var args = argv()
    if len(args) < 2:
        raise Error(
            "usage: packages <command> [PKG...]; see tools/packages.mojo"
        )
    var graph = load("packages.toml")
    var command = String(args[1])
    var names = List[String]()
    for index in range(2, len(args)):
        names.append(String(args[index]))
    if command == "list":
        _print_lines(order(graph))
    elif command == "closure":
        _print_lines(closure(graph, names))
    elif command == "dependents":
        _print_lines(dependents(graph, names))
    elif (
        command == "sources"
        or command == "files"
        or command == "tests"
        or command == "benches"
    ):
        if len(names) == 0:
            names = order(graph)
        for ref name in names:
            if graph.index(name) < 0:
                raise Error("unknown package: " + name)
            if command == "sources":
                _print_lines(files(name, False))
            elif command == "files":
                _print_lines(files(name, True))
            elif command == "tests":
                _print_lines(tests(name))
            else:
                _print_lines(benches(name))
    elif command == "check":
        var problems = check(graph)
        _print_lines(problems)
        if len(problems) > 0:
            raise Error(String(len(problems)) + " package graph violations")
        print("Package graph holds:", len(graph.names), "packages.")
    else:
        raise Error("unknown command: " + command)
