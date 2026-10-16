# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_mcp.json_tree` and `gql_mcp.tool`.

There is no upstream test file: the tree stands in for `serde_json` with
`preserve_order`, and the keyword order is the one of `schemars` 1.2
`src/schema.rs` (`ORDERED_KEYWORDS_START`).
"""

from gql_json.parser import parse
from gql_json.value import JsonKind, NO_NODE
from gql_mcp.json_tree import JsonTree
from gql_mcp.tool import (
    AnnotationOverrides,
    MutationMode,
    Tool,
    ToolAnnotations,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _sample() -> JsonTree:
    var tree = JsonTree()
    tree.root = tree.add_object()
    tree.set(tree.root, "b", tree.add_int(1))
    tree.set(tree.root, "a", tree.add_string('q"'))
    var list = tree.add_array()
    tree.push(list, tree.add_null())
    tree.push(list, tree.add_bool(True))
    tree.push(list, tree.add_bool(False))
    tree.push(list, tree.add_number("1.5"))
    tree.set(tree.root, "list", list)
    tree.set(tree.root, "empty", tree.add_object())
    return tree^


def test_build_and_write() raises:
    var tree = _sample()
    assert_equal(
        tree.to_string(tree.root),
        '{"b":1,"a":"q\\"","list":[null,true,false,1.5],"empty":{}}',
    )
    tree.set(tree.root, "b", tree.add_string("x"))
    assert_equal(tree.key(tree.root, 0), "b")
    assert_equal(tree.text(tree.item(tree.root, 0)), "x")
    assert_equal(tree.length(tree.root), 4)
    assert_true(tree.kind(tree.find(tree.root, "list")) == JsonKind.ARRAY)
    assert_equal(tree.find(tree.root, "zz"), NO_NODE)
    var made = tree.add_int(7)
    assert_equal(tree.entry(tree.root, "b", made), tree.find(tree.root, "b"))
    assert_equal(tree.entry(tree.root, "c", made), made)
    assert_equal(tree.to_string(tree.find(tree.root, "empty"), 2), "{}")
    assert_equal(tree.to_string(tree.find(tree.root, "list"), 2).count("\n"), 5)


def test_copy_and_equals() raises:
    var tree = _sample()
    var other = JsonTree()
    other.root = other.copy_from(tree, tree.root)
    assert_equal(other.to_string(other.root), tree.to_string(tree.root))
    assert_true(tree.equals(tree.root, other, other.root))
    var swapped = JsonTree()
    swapped.root = swapped.add_object()
    swapped.set(swapped.root, "a", swapped.add_string('q"'))
    swapped.set(swapped.root, "b", swapped.add_int(1))
    var list = swapped.add_array()
    swapped.set(swapped.root, "list", list)
    swapped.set(swapped.root, "empty", swapped.add_object())
    assert_false(tree.equals(tree.root, swapped, swapped.root))
    swapped.push(list, swapped.add_null())
    swapped.push(list, swapped.add_bool(True))
    swapped.push(list, swapped.add_bool(False))
    swapped.push(list, swapped.add_number("1.5"))
    assert_true(tree.equals(tree.root, swapped, swapped.root))
    swapped.set(swapped.root, "b", swapped.add_int(2))
    assert_false(tree.equals(tree.root, swapped, swapped.root))
    var renamed = JsonTree()
    renamed.root = renamed.copy_from(tree, tree.root)
    renamed.nodes[renamed.root].keys[0] = "z"
    assert_false(tree.equals(tree.root, renamed, renamed.root))
    var kinds = JsonTree()
    var one = kinds.add_string("1")
    var number = kinds.add_number("1")
    assert_false(kinds.equals(one, kinds.copy(), number))


def test_add_document() raises:
    var document = parse('{"a":[1,"\\u0041",true,null,{}],"a":false}')
    var tree = JsonTree()
    tree.root = tree.add_document(document, document.root)
    assert_equal(tree.to_string(tree.root), '{"a":false}')
    var array = parse('[{"k":"v"},2.50]')
    tree.root = tree.add_document(array, array.root)
    assert_equal(tree.to_string(tree.root), '[{"k":"v"},2.50]')


def test_order_schema() raises:
    var document = parse(
        '{"definitions":{"B":{"type":"string","description":"d"}},'
        + '"required":["x"],"properties":{"z":{"x-k":{"b":1,"$id":2},'
        + '"anyOf":[{"type":"null","$schema":"s"}],"title":"t"},'
        + '"a":{"title":"x","default":{"type":1,"description":2}}},"$defs":{},'
        + '"format":"f","type":"object","$id":"i","enum":[["x"]]}'
    )
    var tree = JsonTree()
    tree.root = tree.add_document(document, document.root)
    tree.order_schema(tree.root)
    assert_equal(
        tree.to_string(tree.root),
        '{"$id":"i","type":"object","format":"f","properties":{"z":{"title":'
        + '"t","x-k":{"b":1,"$id":2},"anyOf":[{"$schema":"s","type":"null"}]},'
        + '"a":{"title":"x","default":{"type":1,"description":2}}},"required":["x"],'
        + '"enum":[["x"]],"$defs":{},"definitions":{"B":{"description":"d",'
        + '"type":"string"}}}',
    )


def test_tool_json() raises:
    var schema = JsonTree()
    schema.root = schema.add_object()
    schema.set(schema.root, "type", schema.add_string("object"))
    var tool = Tool("t", None, schema.copy())
    assert_equal(tool.to_json(), '{"name":"t","inputSchema":{"type":"object"}}')
    var annotations = ToolAnnotations(None, True, False, None, None)
    var overrides = AnnotationOverrides("T", None, True, False, True)
    overrides.apply_to(annotations)
    AnnotationOverrides(None, False, None, None, None).apply_to(annotations)
    tool.description = String("d")
    tool.output_schema = schema.copy()
    tool.annotations = annotations^
    assert_equal(
        tool.to_json(),
        '{"name":"t","description":"d","inputSchema":{"type":"object"},'
        + '"outputSchema":{"type":"object"},"annotations":{"title":"T",'
        + '"readOnlyHint":false,"destructiveHint":true,"idempotentHint":'
        + 'false,"openWorldHint":true}}',
    )
    assert_true(tool.to_json(2).startswith('{\n  "name": "t"'))
    tool.annotations = ToolAnnotations(None, None, None, None, None)
    assert_true(tool.to_json().endswith('"annotations":{}}'))
    assert_true(MutationMode.ALL.is_valid())
    assert_false(MutationMode(3).is_valid())
    assert_true(MutationMode.NONE != MutationMode.EXPLICIT)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
