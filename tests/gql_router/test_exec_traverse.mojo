# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the walk of a flatten path through the response data.

Port of the tests of Hive Router `1a29df9`
`bin/router/src/executor/utils/traverse.rs`. The tests after the ported
ones cover the other branches of `traverse`.

**Differences from upstream.** Upstream calls a closure for each value.
These tests read the values and the paths from `TraverseTargets` after
the walk. `traverse` always walks the data as upstream
`traverse_and_callback_mut`; `collect_paths=False` stands for upstream
`traverse_and_callback`, which tracks no error path.
"""

from gql_json.parser import parse
from gql_json.value import JsonDocument
from gql_router.ast import NONE
from gql_router.exec_traverse import TraverseTargets, traverse
from gql_router.exec_value import write_value
from gql_router.graphql_error import ErrorPath, ErrorSegmentKind
from gql_router.plan_nodes import FlattenNodePath, PathSegment, PathSegmentKind
from gql_router.schema_metadata import PossibleTypes
from gql_router.store import Store
from std.collections import Set
from std.testing import TestSuite, assert_equal, assert_true


def _path(mut store: Store, steps: List[String]) -> FlattenNodePath:
    """Build a flatten path, as the upstream `path` helper.

    `@` is a list step, `|A|B` is a type condition, and any other step is
    a field.
    """
    var segments = List[PathSegment]()
    for step in steps:
        if step == "@":
            segments.append(PathSegment(PathSegmentKind.LIST, NONE, NONE))
        elif step.startswith("|"):
            var names = List[Int]()
            for name in String(step[byte=1:]).split("|"):
                names.append(store.sym(name))
            segments.append(
                PathSegment(
                    PathSegmentKind.TYPE_CONDITION, NONE, store.type_set(names)
                )
            )
        else:
            segments.append(
                PathSegment(PathSegmentKind.FIELD, store.sym(step), NONE)
            )
    return FlattenNodePath(segments^)


def _path_text(path: ErrorPath) -> String:
    """Write an error path as `a.0.b`, for one comparison."""
    var out = String()
    for index in range(len(path.segments)):
        if index > 0:
            out += "."
        ref segment = path.segments[index]
        if segment.kind == ErrorSegmentKind.INDEX:
            out += String(segment.index)
        else:
            out += segment.field
    return out^


def _json(document: JsonDocument, node: Int) -> String:
    """Return the JSON text of a value."""
    var out = List[UInt8]()
    write_value(document, node, out)
    return String(unsafe_from_utf8=out)


def _walk(
    data: StringSlice,
    steps: List[String],
    collect_paths: Bool = True,
    possible_types: PossibleTypes = PossibleTypes(),
) raises -> List[String]:
    """Walk a path through a JSON text.

    Returns:
        One `<path> <value>` line per value, or only the value when the
        paths are not collected.
    """
    var document = parse(data)
    var store = Store()
    var path = _path(store, steps)
    var targets = TraverseTargets(collect_paths)
    traverse(document, document.root, path, store, possible_types, targets)
    var out = List[String]()
    for index in range(len(targets.nodes)):
        var value = _json(document, targets.nodes[index])
        if collect_paths:
            out.append(_path_text(targets.paths[index]) + " " + value)
        else:
            out.append(value)
    if not collect_paths:
        assert_equal(len(targets.paths), 0)
    return out^


def _lines(found: List[String]) -> String:
    """Join the lines of a walk with `;`."""
    var out = String()
    for index in range(len(found)):
        if index > 0:
            out += ";"
        out += found[index]
    return out^


# --- traverse.rs ----------------------------------------------------------


def test_collect_error_paths_one_level() raises:
    var found = _walk('{"items":[{"id":"1"},{"id":"2"}]}', ["items", "@"])
    assert_equal(len(found), 2)
    assert_equal(found[0], 'items.0 {"id":"1"}')
    assert_equal(found[1], 'items.1 {"id":"2"}')


def test_collect_error_paths_two_levels() raises:
    var found = _walk(
        '{"users":[{"id":"1","posts":[{"id":"a"},{"id":"b"}]},'
        + '{"id":"2","posts":[{"id":"c"}]}]}',
        ["users", "@", "posts", "@"],
    )
    assert_equal(len(found), 3)
    assert_equal(found[0], 'users.0.posts.0 {"id":"a"}')
    assert_equal(found[1], 'users.0.posts.1 {"id":"b"}')
    assert_equal(found[2], 'users.1.posts.0 {"id":"c"}')


def test_error_paths_survive_type_conditions_and_sibling_branches() raises:
    var found = _walk(
        '{"media":[{"__typename":"Book","pages":[{"id":"a"}]},'
        + '{"__typename":"Book","pages":[{"id":"b"}]}]}',
        ["media", "@", "|Book", "pages", "@"],
    )
    # The second entity's path must not inherit steps from the first.
    assert_equal(
        _lines(found), 'media.0.pages.0 {"id":"a"};media.1.pages.0 {"id":"b"}'
    )


def test_traverse_matches_multi_type_cast() raises:
    var found = _walk('{"__typename":"Book"}', ["|Book|User"], False)
    assert_equal(len(found), 1)


def test_traverse_rejects_non_matching_multi_type_cast() raises:
    var found = _walk('{"__typename":"Magazine"}', ["|Book|User"], False)
    assert_equal(len(found), 0)


# --- other branches -------------------------------------------------------


def test_a_type_condition_uses_the_possible_types() raises:
    var possible_types = PossibleTypes()
    var members = Set[String]()
    members.add("Book")
    possible_types.map["Media"] = members^
    assert_equal(
        len(_walk('{"__typename":"Book"}', ["|Media"], False, possible_types)),
        1,
    )
    assert_equal(
        len(_walk('{"__typename":"Movie"}', ["|Media"], False, possible_types)),
        0,
    )


def test_a_type_condition_keeps_an_object_without_a_typename() raises:
    assert_equal(_lines(_walk('{"id":1}', ["|Book"])), ' {"id":1}')
    # A `__typename` that is not a string counts as absent.
    assert_equal(len(_walk('{"__typename":1}', ["|Book"], False)), 1)


def test_a_type_condition_on_a_list_checks_each_item() raises:
    assert_equal(
        _lines(
            _walk(
                '{"a":[{"__typename":"Book","n":1},{"__typename":"Movie"},'
                + '{"__typename":"Book","n":2}]}',
                ["a", "|Book", "n"],
            )
        ),
        "a.0.n 1;a.2.n 2",
    )
    # A type condition on a scalar gives nothing.
    assert_equal(len(_walk('{"a":1}', ["a", "|Book"], False)), 0)


def test_the_end_of_a_path_gives_the_items_of_a_list() raises:
    assert_equal(
        _lines(_walk('{"a":[1,[2],null]}', ["a"])), "a.0 1;a.1 [2];a.2 null"
    )
    assert_equal(_lines(_walk('{"a":{"b":true}}', ["a"])), 'a {"b":true}')
    assert_equal(_lines(_walk("[]", List[String]())), "")


def test_missing_fields_and_wrong_kinds_give_nothing() raises:
    assert_equal(len(_walk('{"a":1}', ["b"])), 0)
    assert_equal(len(_walk('{"a":1}', ["a", "b"])), 0)
    assert_equal(len(_walk('{"a":{"b":1}}', ["a", "@"])), 0)
    assert_equal(
        _lines(_walk('{"a":[{"b":1},2,{"c":3},{"b":4}]}', ["a", "@", "b"])),
        "a.0.b 1;a.3.b 4",
    )


def test_targets_without_paths_keep_the_walk_order() raises:
    var document = parse('{"a":[{"b":1},{"b":2}]}')
    var store = Store()
    var path = _path(store, ["a", "@", "b"])
    var targets = TraverseTargets(False)
    traverse(document, document.root, path, store, PossibleTypes(), targets)
    var nodes = targets^.take_nodes()
    assert_equal(len(nodes), 2)
    assert_equal(_json(document, nodes[0]), "1")
    assert_equal(_json(document, nodes[1]), "2")
    assert_true(nodes[0] < nodes[1])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
