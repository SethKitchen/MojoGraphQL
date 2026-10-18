# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Query plan tests whose upstream assertions are not snapshots.

Ports `issue_1308_requires_through_entity_interface_after_entity_hop`,
`issue_1310_nested_requires_with_multiple_providers`,
`issue_1311_different_arguments_under_type_conditions`,
`recursion_bomb_test` and `requires_circular_keys_test` of Hive Router
`1a29df9` `bin/router/src/query_planner/tests/issues.rs`. Upstream runs
the last two on a thread with a two-second limit; here the test time limit
of the suite plays that part.
"""

from _fixtures import (
    issue_1308,
    issue_1310,
    issue_1311,
    issue_recursion_bomb,
    issue_requires_circular_keys,
)
from _plan_harness import _plan
from std.testing import TestSuite, assert_true


def test_issue_1308_requires_through_entity_interface_after_entity_hop() raises:
    var plan = _plan(issue_1308.sdl(), "query { cage { listings { rank } } }")
    assert_true("tricks" in plan)
    assert_true("whiskers" in plan)
    assert_true("rank" in plan)


def test_issue_1310_nested_requires_with_multiple_providers() raises:
    var plan = _plan(issue_1310.sdl(), "query { pet { checkup { grade } } }")
    for expected in ["age", "weight", "fee", "grade"]:
        assert_true(String(expected) in plan, "missing " + String(expected))


def test_issue_1311_different_arguments_under_type_conditions() raises:
    var plan = _plan(
        issue_1311.sdl(),
        """
        query {
          storefront {
            departments {
              ... on Aquatics { photo { thumbnail(width: 100) } }
              ... on Reptiles { photo { thumbnail(width: 200) } }
            }
          }
        }
        """,
    )
    assert_true("thumbnail(width: 100)" in plan)
    assert_true("thumbnail(width: 200)" in plan)


def test_recursion_bomb_test() raises:
    _ = _plan(issue_recursion_bomb.sdl(), "{ list { items { value } } }")


def test_requires_circular_keys_test() raises:
    _ = _plan(
        issue_requires_circular_keys.sdl(),
        """
        {
          list {
            items {
              value
              valueRequiresObjectFragment
              valueRequiresInterfaceFragment
              valueRequiresInlineFragment
              valueNestedField
            }
          }
        }
        """,
    )
    _ = _plan(
        issue_requires_circular_keys.sdl(),
        "{ list { taggedItems { ... on Item { valueInterfaceKey } } } }",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
