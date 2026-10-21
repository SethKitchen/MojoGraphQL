# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the index of the representations of one `_entities` list.

Upstream `prepare_job_future` of Hive Router `1a29df9`
`bin/router/src/executor/execution/plan.rs` keeps the entity index of
each representation hash, so that equal entities share one
representation. The port finds a hash by a scan for a short list, and by
a dictionary for a long one; both give the same index.
"""

from gql_router.exec_plan import _Representations
from std.testing import TestSuite, assert_equal


def test_short_and_long_lists_give_the_same_index() raises:
    var reps = _Representations()
    assert_equal(reps.find(UInt64(5)), -1)
    var hash = 0
    while hash < 40:
        reps.add(UInt64(hash * 7 + 1))
        hash += 1
    assert_equal(reps.count, 40)
    hash = 0
    while hash < 40:
        assert_equal(reps.find(UInt64(hash * 7 + 1)), hash)
        hash += 1
    assert_equal(reps.find(UInt64(2)), -1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
