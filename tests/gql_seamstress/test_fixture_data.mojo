# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Check that `_fixture_data.mojo` holds the files of `fixtures/`.

`make test` runs from the repository root, where `fixtures/` is. `make
coverage` copies only the Mojo files, so there the check has nothing to
compare and passes. Run `_embed.mojo` after a change in `fixtures/`.
"""

from std.os import listdir
from std.os.path import exists, isdir
from std.pathlib import Path
from std.testing import TestSuite, assert_equal

from _fixture_data import fixture_paths, fixture_text

comptime ROOT = "tests/gql_seamstress/fixtures/"
"""The fixtures, from the repository root."""


def files(directory: String) raises -> List[String]:
    """Return the files below a directory, sorted, as relative paths."""
    var out = List[String]()
    var entries = listdir(ROOT + directory)
    sort(entries)
    for ref entry in entries:
        var path = directory + entry
        if isdir(ROOT + path):
            out.extend(files(path + "/"))
        else:
            out.append(path)
    return out^


def test_fixture_data_is_current() raises:
    if not exists(ROOT):
        return
    var paths = files("")
    var embedded = fixture_paths()
    assert_equal(len(embedded), len(paths))
    for index in range(len(paths)):
        assert_equal(embedded[index], paths[index])
        assert_equal(
            fixture_text(paths[index]),
            Path(ROOT + paths[index]).read_text(),
            paths[index],
        )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
