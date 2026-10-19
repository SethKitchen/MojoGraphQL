# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the response values of the executor.

Port of the tests of Hive Router `1a29df9`
`bin/router/src/executor/response/merge.rs` and
`bin/router/src/executor/response/value.rs`. The tests after the ported
ones cover the arena operations that this port adds: `copy_value`,
`take_member`, `import_document`, `set_key`, `set_string` and
`hash_value`.

**Differences from upstream.** Upstream `object_position_from` gives a
position and moves an integer cursor. `object_get_from` gives a member
node, and its cursor is the next member node, or `NO_NODE` past the end.
Upstream keeps a string with escapes as `Cow::Owned` and a plain string as
`Cow::Borrowed`. This port keeps the source text of both, and sets
`FLAG_ESCAPED` on a string with escapes; `is_plain_string` reads it.
"""

from gql_json.parser import parse
from gql_json.value import FLAG_ESCAPED, NO_NODE, JsonDocument, JsonKind
from gql_router.schema_metadata import PossibleTypes
from gql_router.exec_value import (
    copy_value,
    deep_merge,
    finish_hash,
    FNV_OFFSET,
    hash_value,
    import_document,
    is_plain_string,
    key_is,
    node_at,
    object_get,
    object_get_from,
    raw_string,
    set_key,
    set_string,
    string_is,
    string_text,
    take_member,
    type_satisfies,
    typename_node,
    write_value,
)
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_not_equal,
    assert_true,
)


def _json(document: JsonDocument, node: Int) -> String:
    """Return the JSON text of a value."""
    var out = List[UInt8]()
    write_value(document, node, out)
    return String(unsafe_from_utf8=out)


def _keys(document: JsonDocument, object: Int) -> List[String]:
    """Return the keys of an object, in order."""
    var keys = List[String]()
    var current = document.first(object)
    while current != NO_NODE:
        keys.append(document.key(current))
        current = document.next(current)
    return keys^


def _join(keys: List[String]) -> String:
    """Join keys with commas, for one comparison."""
    var out = String()
    for index in range(len(keys)):
        if index > 0:
            out += ","
        out += keys[index]
    return out^


def _merge(target: StringSlice, source: StringSlice) raises -> String:
    """Merge a source text into a target text and return the result."""
    var document = parse(target)
    var source_root = import_document(document, parse(source))
    deep_merge(document, document.root, source_root)
    return _json(document, document.root)


# --- merge.rs -------------------------------------------------------------


def test_merges_shared_keys_and_appends_new_ones_in_source_order() raises:
    var document = parse('{"id": "1", "name": "a", "nested": {"x": 1}}')
    var source = import_document(
        document,
        parse('{"price": 10, "nested": {"y": 2}, "id": "1", "stock": 3}'),
    )

    deep_merge(document, document.root, source)

    assert_equal(
        _join(_keys(document, document.root)), "id,name,nested,price,stock"
    )
    var nested = object_get(document, document.root, "nested")
    assert_equal(_join(_keys(document, nested)), "x,y")


def test_source_scalars_replace_target_values() raises:
    var document = parse('{"b": 1, "a": 2}')
    var source = import_document(document, parse('{"a": 3, "b": null}'))

    deep_merge(document, document.root, source)

    var a = object_get(document, document.root, "a")
    assert_true(document.kind(a) == JsonKind.NUMBER)
    assert_equal(String(document.text(a)), "3")
    # A null source value leaves the target untouched.
    var b = object_get(document, document.root, "b")
    assert_equal(String(document.text(b)), "1")
    assert_equal(_json(document, document.root), '{"b":1,"a":3}')


def test_merge_arrays_item_by_item() raises:
    assert_equal(
        _merge('[{"a":1},{"a":2},3]', '[{"b":1},{"b":2}]'),
        '[{"a":1,"b":1},{"a":2,"b":2},3]',
    )
    # Extra source items are dropped, as upstream `zip`.
    assert_equal(_merge("[1]", "[2,3]"), "[2]")


def test_merge_replaces_mismatched_kinds() raises:
    assert_equal(_merge('{"a":[1]}', '{"a":{"b":1}}'), '{"a":{"b":1}}')
    assert_equal(_merge('{"a":{"b":1}}', '{"a":"x"}'), '{"a":"x"}')
    assert_equal(_merge("1", "[true,false]"), "[true,false]")
    assert_equal(_merge('{"a":1}', "null"), '{"a":1}')


def test_merge_empty_objects() raises:
    assert_equal(_merge('{"a":1}', "{}"), '{"a":1}')
    assert_equal(_merge("{}", '{"a":1,"b":2}'), '{"a":1,"b":2}')
    # A member of a target keeps its key when the value comes from a source.
    assert_equal(_merge('{"o":{}}', '{"o":{"a":1}}'), '{"o":{"a":1}}')


def test_merge_finds_keys_before_the_cursor() raises:
    assert_equal(
        _merge('{"a":1,"b":2,"c":3}', '{"c":30,"a":10,"d":4,"b":20}'),
        '{"a":10,"b":20,"c":30,"d":4}',
    )


def test_merge_compares_escaped_keys_by_value() raises:
    assert_equal(_merge('{"\\u0061":1}', '{"a":2}'), '{"\\u0061":2}')


# --- value.rs -------------------------------------------------------------


def test_keeps_keys_in_input_order() raises:
    var document = parse('{"b": 1, "a": 2, "c": 3}')
    assert_equal(_join(_keys(document, document.root)), "b,a,c")


def test_object_position_from_advances_the_cursor_past_each_match() raises:
    var document = parse('{"id": null, "name": null, "price": null}')
    var root = document.root
    var id = document.at(root, 0)
    var name = document.at(root, 1)
    var price = document.at(root, 2)
    var cursor = id

    assert_equal(object_get_from(document, root, "id", cursor), id)
    assert_equal(object_get_from(document, root, "name", cursor), name)
    assert_equal(object_get_from(document, root, "price", cursor), price)
    # Upstream moves the cursor to 3, past the end.
    assert_equal(cursor, NO_NODE)


def test_object_position_from_wraps_around_for_keys_before_the_cursor() raises:
    var document = parse('{"id": null, "name": null, "price": null}')
    var root = document.root
    var cursor = document.at(root, 2)

    assert_equal(
        object_get_from(document, root, "id", cursor), document.at(root, 0)
    )
    assert_equal(cursor, document.at(root, 1))


def test_object_position_from_leaves_the_cursor_on_a_miss() raises:
    var document = parse('{"id": null, "name": null}')
    var root = document.root
    var cursor = document.at(root, 1)

    assert_equal(object_get_from(document, root, "missing", cursor), NO_NODE)
    assert_equal(cursor, document.at(root, 1))

    var past_the_end = NO_NODE
    assert_equal(
        object_get_from(document, root, "name", past_the_end),
        document.at(root, 1),
    )


def test_deserializes_escaped_string_as_owned() raises:
    var document = parse('{"message": "hello\\nworld"}')
    var message = object_get(document, document.root, "message")

    assert_true(document.kind(message) == JsonKind.STRING)
    assert_equal(string_text(document, message), "hello\nworld")
    assert_false(is_plain_string(document, message))
    assert_true(node_at(document, message).flags & FLAG_ESCAPED != 0)
    assert_true(string_is(document, message, "hello\nworld"))
    assert_false(string_is(document, message, "hello\\nworld"))


def test_deserializes_simple_string_as_borrowed() raises:
    var document = parse('{"message": "hello world"}')
    var message = object_get(document, document.root, "message")

    assert_true(document.kind(message) == JsonKind.STRING)
    assert_equal(string_text(document, message), "hello world")
    assert_true(is_plain_string(document, message))
    assert_equal(String(raw_string(document, message)), "hello world")
    assert_true(string_is(document, message, "hello world"))
    assert_false(string_is(document, message, "hello"))


# --- arena operations -----------------------------------------------------


def test_key_is_and_object_get() raises:
    var document = parse('{"a":1,"\\u0062":2,"ab":3}')
    var root = document.root
    assert_true(key_is(document, document.at(root, 0), "a"))
    assert_false(key_is(document, document.at(root, 0), "b"))
    assert_true(key_is(document, document.at(root, 1), "b"))
    assert_false(key_is(document, document.at(root, 2), "a"))
    assert_equal(object_get(document, root, "b"), document.at(root, 1))
    assert_equal(object_get(document, root, "c"), NO_NODE)


def test_string_is_rejects_other_kinds() raises:
    var document = parse('{"n":1}')
    assert_false(string_is(document, document.at(document.root, 0), "1"))


def test_typename_node() raises:
    var document = parse(
        '[{"id":1,"__typename":"Product"},{"__typename":1},{},"x"]'
    )
    var root = document.root
    var found = typename_node(document, document.at(root, 0))
    assert_equal(string_text(document, found), "Product")
    assert_equal(typename_node(document, document.at(root, 1)), NO_NODE)
    assert_equal(typename_node(document, document.at(root, 2)), NO_NODE)
    assert_equal(typename_node(document, document.at(root, 3)), NO_NODE)


def test_copy_value_is_independent() raises:
    var document = parse('{"a":{"b":[1,{"c":"x"}],"d":{}},"e":[]}')
    var copy = copy_value(document, document.root)
    assert_equal(_json(document, copy), _json(document, document.root))

    var a = object_get(document, copy, "a")
    var other = import_document(document, parse('{"b":null,"z":true}'))
    deep_merge(document, a, other)
    assert_equal(
        _json(document, copy),
        '{"a":{"b":[1,{"c":"x"}],"d":{},"z":true},"e":[]}',
    )
    assert_equal(
        _json(document, document.root),
        '{"a":{"b":[1,{"c":"x"}],"d":{}},"e":[]}',
    )


def test_copy_value_of_a_member_keeps_its_key() raises:
    var document = parse('{"k":"v","m":2}')
    var copy = copy_value(document, document.at(document.root, 0))
    assert_equal(document.key(copy), "k")
    assert_equal(document.next(copy), NO_NODE)
    assert_equal(_json(document, copy), '"v"')


def test_take_member() raises:
    var document = parse('{"a":1,"b":2,"c":3}')
    var root = document.root

    var b = take_member(document, root, "b")
    assert_equal(String(document.text(b)), "2")
    assert_equal(document.next(b), NO_NODE)
    assert_equal(_json(document, root), '{"a":1,"c":3}')
    assert_equal(document.length(root), 2)

    assert_equal(take_member(document, root, "missing"), NO_NODE)

    var c = take_member(document, root, "c")
    assert_equal(String(document.text(c)), "3")
    assert_equal(_json(document, root), '{"a":1}')

    # The last member is now `a`, so a new member goes after it.
    var d = import_document(document, parse('{"d":4}'))
    deep_merge(document, root, d)
    assert_equal(_json(document, root), '{"a":1,"d":4}')

    var a = take_member(document, root, "a")
    assert_equal(String(document.text(a)), "1")
    assert_equal(_json(document, root), '{"d":4}')
    _ = take_member(document, root, "d")
    assert_equal(document.length(root), 0)
    assert_equal(_json(document, root), "{}")


def test_take_member_from_a_non_object() raises:
    var document = parse('[{"a":1}]')
    assert_equal(take_member(document, document.root, "a"), NO_NODE)


def test_import_document() raises:
    var document = parse('{"x":"\\u0041"}')
    var first = import_document(document, parse('{"a":[1,"t\\"q",{"b":null}]}'))
    var second = import_document(document, parse('"s"'))
    assert_equal(_json(document, document.root), '{"x":"\\u0041"}')
    assert_equal(_json(document, first), '{"a":[1,"t\\"q",{"b":null}]}')
    assert_equal(_json(document, second), '"s"')
    var a = object_get(document, first, "a")
    assert_true(key_is(document, a, "a"))
    assert_equal(string_text(document, document.at(a, 1)), 't"q')

    var empty = JsonDocument()
    assert_equal(import_document(document, empty), NO_NODE)


def test_set_key() raises:
    var document = parse('{"\\u0061":1,"b":2}')
    var root = document.root
    set_key(document, document.at(root, 0), 'q"t')
    set_key(document, document.at(root, 1), "plain")
    assert_true(key_is(document, document.at(root, 0), 'q"t'))
    assert_equal(_json(document, root), '{"q\\"t":1,"plain":2}')


def test_set_string() raises:
    var document = parse('{"a":{"b":1},"c":"\\n"}')
    var root = document.root
    set_string(document, document.at(root, 0), 'line\n"x"')
    set_string(document, document.at(root, 1), "plain")
    var a = object_get(document, root, "a")
    assert_true(document.kind(a) == JsonKind.STRING)
    assert_equal(document.length(a), 0)
    assert_equal(string_text(document, a), 'line\n"x"')
    assert_equal(_json(document, root), '{"a":"line\\n\\"x\\"","c":"plain"}')


def _hash(text: StringSlice) raises -> UInt64:
    """Return the hash of the root value of a JSON text."""
    var document = parse(text)
    return finish_hash(hash_value(document, document.root, FNV_OFFSET))


def test_hash_value_is_equal_for_equal_values() raises:
    var value = '{"a":"x","b":[1,true,false,null],"c":{}}'
    assert_equal(_hash(value), _hash(value))
    # Escapes decode before the hash.
    assert_equal(
        _hash(value),
        _hash('{"\\u0061":"\\u0078","b":[1,true,false,null],"c":{}}'),
    )
    assert_equal(
        _hash('"a long string with more than eight bytes"'),
        _hash('"a long string with more than eight b\\u0079tes"'),
    )


def test_hash_value_differs_for_different_values() raises:
    var value = _hash('{"a":"x","b":[1,true]}')
    assert_not_equal(value, _hash('{"a":"y","b":[1,true]}'))
    assert_not_equal(value, _hash('{"a":"x","b":[1,false]}'))
    assert_not_equal(value, _hash('{"b":"x","a":[1,true]}'))
    assert_not_equal(value, _hash('["x",[1,true]]'))
    assert_not_equal(_hash("1"), _hash('"1"'))
    assert_not_equal(_hash("null"), _hash("false"))
    assert_not_equal(_hash('"a"'), _hash('"a\\u0000"'))


def test_type_satisfies_decodes_an_escaped_typename() raises:
    var document = parse('{"a":"Bo\\u006fk","b":"Book"}')
    var possible = PossibleTypes()
    possible.map["Media"] = {"Book"}
    var a = document.find(document.root, "a")
    var b = document.find(document.root, "b")
    assert_true(type_satisfies(possible, document, a, "Media"))
    assert_true(type_satisfies(possible, document, b, "Book"))
    assert_false(type_satisfies(possible, document, b, "Movie"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
