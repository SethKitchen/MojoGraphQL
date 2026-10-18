# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for fetch variables and condition branches.

The cases follow `select_fetch_variables` and
`condition_node_by_variables` in Hive Router.
"""

from gql_router.ast import NONE
from gql_router.fetch_variables import (
    BatchAliasPayload,
    batch_variable_payloads,
    condition_target,
    select_fetch_variables,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _two(first: String, second: String) -> List[String]:
    var names = List[String]()
    names.append(first)
    names.append(second)
    return names^


def test_only_used_variables_are_sent() raises:
    var selected = select_fetch_variables(
        True,
        _two("used", "unused"),
        _two("1", "2"),
        True,
        _two("used", "missing"),
    )
    assert_true(selected.present)
    assert_equal(len(selected.names), 1)
    assert_equal(selected.names[0], "used")
    assert_equal(selected.values[0], "1")
    var ordered = select_fetch_variables(
        True, _two("a", "b"), _two("1", "2"), True, _two("b", "a")
    )
    assert_equal(ordered.names[0], "a")
    assert_equal(ordered.names[1], "b")
    assert_equal(ordered.values[0], "1")
    assert_equal(ordered.values[1], "2")


def test_no_usage_list_selects_nothing() raises:
    var selected = select_fetch_variables(
        True,
        _two("unused_1", "unused_2"),
        _two("1", "2"),
        False,
        List[String](),
    )
    assert_false(selected.present)
    var absent = select_fetch_variables(
        False, List[String](), List[String](), True, _two("used", "other")
    )
    assert_false(absent.present)


def test_a_condition_runs_if_only_for_boolean_true() raises:
    var names = List[String]()
    names.append("show")
    var yes = List[String]()
    yes.append("true")
    assert_equal(condition_target(True, names, yes^, "show", 4, 5), 4)
    var no = List[String]()
    no.append("false")
    assert_equal(condition_target(True, names, no^, "show", 4, 5), 5)
    var number = List[String]()
    number.append("1")
    assert_equal(condition_target(True, names, number^, "show", 4, 5), 5)
    assert_equal(
        condition_target(True, names, List[String](), "show", 4, 5), NONE
    )
    assert_equal(
        condition_target(False, List[String](), List[String](), "show", 4, 5),
        NONE,
    )
    var again = List[String]()
    again.append("true")
    assert_equal(condition_target(True, names, again^, "show", NONE, 5), NONE)


def test_a_shared_representations_variable_is_sent_once() raises:
    var aliases = List[BatchAliasPayload]()
    aliases.append(BatchAliasPayload("_e0", "__batch_reps_0", ""))
    aliases.append(BatchAliasPayload("_e1", "__batch_reps_0", '[{"upc":"2"}]'))
    aliases.append(BatchAliasPayload("_e2", "__batch_reps_1", '[{"upc":"3"}]'))
    var payloads = batch_variable_payloads(aliases^)
    assert_equal(len(payloads.names), 2)
    assert_equal(payloads.names[0], "__batch_reps_0")
    assert_equal(payloads.values[0], "[]")
    assert_equal(payloads.names[1], "__batch_reps_1")
    assert_equal(payloads.values[1], '[{"upc":"3"}]')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
