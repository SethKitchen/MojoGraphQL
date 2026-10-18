# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for merging JSON response values.

The cases follow `deep_merge` in Hive Router.
"""

from gql_json.parser import parse
from gql_json.writer import stringify
from gql_router.response_merge import deep_merge
from std.testing import TestSuite, assert_equal


def _merge(target_text: String, source_text: String) raises -> String:
    var target = parse(target_text)
    var source = parse(source_text)
    var copied = target.add_copy(source, source.root)
    deep_merge(target, target.root, copied)
    return stringify(target, target.root)


def test_shared_keys_merge_and_new_keys_follow_the_source() raises:
    assert_equal(
        _merge(
            '{"id":"1","name":"a","nested":{"x":1}}',
            '{"price":10,"nested":{"y":2},"id":"1","stock":3}',
        ),
        '{"id":"1","name":"a","nested":{"x":1,"y":2},"price":10,"stock":3}',
    )


def test_a_scalar_replaces_and_null_stays() raises:
    assert_equal(_merge('{"b":1,"a":2}', '{"a":3,"b":null}'), '{"b":1,"a":3}')


def test_arrays_merge_item_by_item() raises:
    assert_equal(
        _merge('[1,{"a":1},3]', '[4,{"b":2}]'),
        '[4,{"a":1,"b":2},3]',
    )
    assert_equal(_merge('{"a":1}', "{}"), '{"a":1}')
    assert_equal(_merge("{}", '{"a":1}'), '{"a":1}')
    assert_equal(_merge('{"a":1}', '"x"'), '"x"')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
