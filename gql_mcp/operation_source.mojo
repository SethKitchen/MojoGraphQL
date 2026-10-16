# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Operations from local `.graphql` files and directories.

Port of the `OperationSource::Files` part of Apollo MCP Server 2.0.0
(04e4e6e) `crates/apollo-mcp-server/src/operations/operation_source.rs`.

A path can be a file or a directory. Of a directory, each entry whose
extension is `graphql` is read; the directory is not read recursively. A
file that is empty or only white space gives no operation. An operation
that two paths reach, such as a directory and a file in it, is loaded once:
the canonical paths are compared.

Differences from upstream:

- The files are read once. Upstream watches each path and sends the
  operations again when a file changes; that is phase 2, as are the
  persisted-query manifest and the operation collection sources.
- The order is fixed: the paths in their order, and the entries of a
  directory sorted by name. Upstream collects them in a `HashMap` and a
  `read_dir`, whose orders are not specified.
- A file that cannot be read gives the message of the Mojo standard
  library, not of Rust `std::io::Error`.
"""

from std.os import listdir
from std.os.path import isdir, realpath
from gql_mcp.operation import OperationError, OperationErrorKind, RawOperation


comptime OPERATION_DOCUMENT_EXTENSION = "graphql"
"""The extension of the operation files of a directory."""


def _add(
    mut operations: List[RawOperation],
    mut seen: List[String],
    path: String,
) raises OperationError:
    """Read a file, and add its operation unless it is blank or loaded
    already; raise a `FILE` error when the file cannot be read."""
    var content: String
    var canonical: String
    try:
        with open(path, "r") as file:
            content = file.read()
        canonical = realpath(path)
    except e:
        raise OperationError(OperationErrorKind.FILE, String(e), path.copy(), 0)
    if content.strip().byte_length() == 0:
        return
    if canonical in seen:
        return
    seen.append(canonical)
    operations.append(RawOperation(content.copy(), path.copy()))


def load_operations(
    paths: List[String],
) raises OperationError -> List[RawOperation]:
    """Read the operations of files and directories.

    Args:
        paths: The files and directories.

    Returns:
        One raw operation for each file that is not blank, with its path.

    Raises:
        OperationError: `FILE` when a file cannot be read.
    """
    var operations = List[RawOperation]()
    var seen = List[String]()
    var index = 0
    while index < len(paths):
        ref path = paths[index]
        index += 1
        if not isdir(path):
            _add(operations, seen, path)
            continue
        var names = List[String]()
        try:
            names = listdir(path)
        except:
            pass
        sort(names)
        var at = 0
        while at < len(names):
            ref name = names[at]
            at += 1
            if name.endswith("." + OPERATION_DOCUMENT_EXTENSION):
                var file = path + "/" + name
                _add(operations, seen, file)
    return operations^
