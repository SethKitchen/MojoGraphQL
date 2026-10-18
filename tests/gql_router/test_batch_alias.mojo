# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for splitting a batch response by alias.

The cases follow `partition_batch_errors_by_alias` and
`collect_batched_entities_by_alias` in Hive Router.
"""

from gql_json.parser import parse
from gql_json.writer import stringify
from gql_router.ast import NONE
from gql_router.batch_alias import (
    collect_batch_entities,
    merge_alias_entities,
    partition_batch_errors,
)
from gql_router.graphql_error import (
    ErrorPath,
    ErrorSegment,
    GraphQLError,
    field_segment,
    graphql_error,
    index_segment,
)
from gql_router.plan_nodes import FlattenNodePath, PathSegment, PathSegmentKind
from gql_router.rewrite import PossibleTypes
from gql_router.store import Store
from std.testing import TestSuite, assert_equal


def _aliases() -> List[String]:
    var names = List[String]()
    names.append("_e0")
    names.append("_e1")
    return names^


def _error(alias: String, index: Int, field: String) -> GraphQLError:
    var error = graphql_error("down")
    var segments = List[ErrorSegment]()
    if alias.byte_length() > 0:
        segments.append(field_segment(alias))
        segments.append(index_segment(index))
        segments.append(field_segment(field))
        error.has_path = True
        error.path = ErrorPath(segments^)
    return error^


def test_errors_are_grouped_by_alias_and_renamed() raises:
    var errors = List[GraphQLError]()
    errors.append(_error("_e0", 2, "price"))
    errors.append(_error("_e1", 0, "name"))
    errors.append(_error("", 0, ""))
    errors.append(_error("_e9", 1, "sku"))
    var split = partition_batch_errors(_aliases(), errors^)
    assert_equal(len(split.groups[0]), 1)
    assert_equal(split.groups[0][0].path.segments[0].field, "_entities")
    assert_equal(split.groups[0][0].path.segments[2].field, "price")
    assert_equal(len(split.groups[1]), 1)
    assert_equal(split.groups[1][0].path.segments[0].field, "_entities")
    assert_equal(len(split.unmatched), 2)
    assert_equal(split.unmatched[1].path.segments[0].field, "_e9")


def test_alias_arrays_are_taken_off_the_response() raises:
    var data = parse('{"_e0":[{"id":"1"}],"_e1":{"no":1},"other":2}')
    var texts = collect_batch_entities(data, _aliases())
    assert_equal(texts[0], '[{"id":"1"}]')
    assert_equal(texts[1], "")
    assert_equal(stringify(data, data.root), '{"other":2}')


def test_entities_merge_back_onto_their_paths() raises:
    var store = Store()
    var data = parse('{"products":[{"id":"1"},{"id":"2"},{"id":"3"}]}')
    var entities = parse('[{"price":10},{"price":20}]')
    var segments = List[PathSegment]()
    segments.append(
        PathSegment(PathSegmentKind.FIELD, store.sym("products"), NONE)
    )
    segments.append(PathSegment(PathSegmentKind.LIST, NONE, NONE))
    var indexes = List[Int]()
    indexes.append(0)
    indexes.append(-1)
    indexes.append(0)
    var recorded = merge_alias_entities(
        data,
        entities,
        FlattenNodePath(segments^),
        store,
        PossibleTypes(List[String](), List[List[String]]()),
        indexes^,
        True,
    )
    assert_equal(recorded, "0:products.0 products.2")
    assert_equal(
        stringify(data, data.root),
        '{"products":[{"id":"1","price":10},{"id":"2"},{"id":"3","price":10}]}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
