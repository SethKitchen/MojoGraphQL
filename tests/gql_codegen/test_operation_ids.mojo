# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The operation ids and documents of the Apollo Kotlin compiler tests.

Port of the language-independent part of Apollo Kotlin
`libraries/apollo-compiler/src/test/kotlin/com/apollographql/apollo/
compiler/CodegenTest.kt`: for each fixture of `src/test/graphql/com/
example/`, the `OPERATION_ID` and the `OPERATION_DOCUMENT` of its expected
output. The id is the SHA-256 of the minified document, so an equal id
means an equal document: the printer, the `__typename` transform and the
order of the fragments all agree with upstream.

The fixtures of `_fixtures.UNSUPPORTED` are skipped.
"""

from std.testing import TestSuite, assert_equal, assert_true

from gql_codegen.issues import serialize
from gql_codegen.strings import minify

from _fixtures import compile_fixture, fixture_schema, is_unsupported, rows


def check_part(part: Int, parts: Int) raises:
    """Check the operations of one part of the fixtures.

    Args:
        part: Which part, from 0.
        parts: How many parts there are.

    Raises:
        Error: When an id or a document differs from upstream.
    """
    var all = rows()
    var checked = 0
    var start = len(all) * part // parts
    var end = len(all) * (part + 1) // parts
    for index in range(start, end):
        ref row = all[index]
        if is_unsupported(row.fixture):
            continue
        var schema = fixture_schema(row.fixture)
        var result = compile_fixture(row.fixture, schema)
        assert_equal(serialize(result.errors), "", row.fixture)
        var found = False
        var ids = result.operation_ids()
        for operation in range(len(result.ir.operations)):
            ref ir = result.ir.operations[operation]
            if ir.name != row.name:
                continue
            found = True
            assert_equal(
                minify(ir.source_with_fragments),
                row.document,
                row.fixture + " " + row.name,
            )
            assert_equal(ids[operation], row.id, row.fixture + " " + row.name)
            checked += 1
        assert_true(found, row.fixture + " " + row.name)
    assert_true(checked > 0)


def test_operation_ids_part_1() raises:
    check_part(0, 4)


def test_operation_ids_part_2() raises:
    check_part(1, 4)


def test_operation_ids_part_3() raises:
    check_part(2, 4)


def test_operation_ids_part_4() raises:
    check_part(3, 4)


def test_operation_id_count() raises:
    # 108 upstream operations; 13 of them are in unsupported fixtures.
    var supported = 0
    for ref row in rows():
        if not is_unsupported(row.fixture):
            supported += 1
    assert_equal(len(rows()), 108)
    assert_equal(supported, 95)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
