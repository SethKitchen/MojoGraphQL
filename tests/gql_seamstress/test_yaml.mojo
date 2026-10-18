# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the minimal YAML reader of the supergraph configuration.

The expected values are what serde_yaml reads for the same text, written
as JSON. The block scalar case of `test_sdl` is from
`apollo-federation-types` 0.18.0-rc.1 `src/config/subgraph.rs`.
"""

from gql_json.writer import stringify
from gql_seamstress.yaml import parse_yaml
from gql_seamstress.yaml_scalar import strip_comment
from std.testing import TestSuite, assert_equal, assert_true


def _json(text: String) raises -> String:
    var document = parse_yaml(text)
    return stringify(document, document.root)


def _error(text: String) raises -> String:
    try:
        _ = parse_yaml(text)
    except e:
        return String(e)
    raise Error("no error for: " + text)


def test_mappings() raises:
    assert_equal(
        _json(
            "---\nsubgraphs:\n  films:\n    routing_url:"
            " https://films.example.com\n    schema:\n      file:"
            " ./good-films.graphql\n"
        ),
        '{"subgraphs":{"films":{"routing_url":"https://films.example.com","schema":{"file":"./good-films.graphql"}}}}',
    )
    assert_equal(_json("a:\nb: 1\n"), '{"a":null,"b":1}')
    assert_equal(
        _json("\"quoted key\": 1\n'single'  : 2\n"),
        '{"quoted key":1,"single":2}',
    )
    assert_equal(_json("a: 1\r\nb: 2\r\n"), '{"a":1,"b":2}')
    assert_equal(_json("a: 1\n...\nignored: [\n"), '{"a":1}')


def test_sequences() raises:
    assert_equal(_json("- a\n- b\n"), '["a","b"]')
    assert_equal(_json("k:\n- a\n- b\n"), '{"k":["a","b"]}')
    assert_equal(_json("- x: 1\n  y: 2\n- z\n"), '[{"x":1,"y":2},"z"]')
    assert_equal(_json("- - a\n  - b\n- c\n"), '[["a","b"],"c"]')
    assert_equal(_json("-\n  a: 1\n-\n"), '[{"a":1},null]')


def test_comments_and_documents() raises:
    assert_equal(_json("# only a comment\n\n"), "null")
    assert_equal(_json(""), "null")
    assert_equal(
        _json("a: b # note\nc: 'd # not a note'\ne: f#g\n"),
        '{"a":"b","c":"d # not a note","e":"f#g"}',
    )
    assert_equal(strip_comment('"a\\"#" # c'), '"a\\"#"')
    assert_equal(strip_comment("  \t"), "")
    assert_equal(
        _error("a: 1\n---\nb: 2\n"),
        "line 2: only one YAML document is supported",
    )
    assert_equal(
        _error("--- a\n"), "line 1: only one YAML document is supported"
    )


def test_quoted() raises:
    assert_equal(_json("a: 'it''s'\n"), '{"a":"it\'s"}')
    assert_equal(
        _json('a: "t\\tn\\n\\"q\\" \\\\ \\/ \\  \\0\\r"\n'),
        '{"a":"t\\tn\\n\\"q\\" \\\\ /   \\u0000\\r"}',
    )
    assert_equal(_json('a: "\\u00e9\\x41\\U0001F600"\n'), '{"a":"éA😀"}')
    assert_equal(
        _error('a: "\\q"\n'),
        "line 1: an unknown escape in a double-quoted scalar",
    )
    assert_equal(
        _error('a: "\\u12"\n'), "line 1: an invalid hexadecimal escape"
    )
    assert_equal(
        _error('a: "\\uZZZZ"\n'), "line 1: an invalid hexadecimal escape"
    )
    assert_equal(
        _error('a: "\\uD800"\n'),
        "line 1: an escape is not a Unicode scalar value",
    )
    assert_equal(
        _error('a: "\\U00110000"\n'),
        "line 1: an escape is not a Unicode scalar value",
    )
    assert_equal(
        _error('a: "x\\'), "line 1: a double-quoted scalar is not closed"
    )
    assert_equal(_error("a: 'open\n"), "line 1: a quoted scalar is not closed")
    assert_equal(_error("a: 'x' y\n"), "line 1: text follows a quoted scalar")
    assert_equal(_json('"just a string"\n'), '"just a string"')
    assert_equal(_error('"a" b\n'), "line 1: text follows a quoted scalar")


def test_block_scalars() raises:
    assert_equal(
        _json("sdl: |\n    type Query {\n        hello: String\n    }"),
        '{"sdl":"type Query {\\n    hello: String\\n}"}',
    )
    assert_equal(
        _json("a: |\n  x\n  # kept\n\n  y\n\nb: 1\n"),
        '{"a":"x\\n# kept\\n\\ny\\n","b":1}',
    )
    assert_equal(_json("a: |-\n  x\n\n"), '{"a":"x"}')
    assert_equal(_json("a: |+\n  x\n\n\n"), '{"a":"x\\n\\n\\n"}')
    assert_equal(
        _json("a: >\n  one\n  two\n\n  three\n    more\n  four\n"),
        '{"a":"one two\\nthree\\n  more\\nfour\\n"}',
    )
    assert_equal(_json("a: >-\n  one\n  two\n"), '{"a":"one two"}')
    assert_equal(_json("a: |2\n    x\n   y\n"), '{"a":"  x\\n y\\n"}')
    assert_equal(_json("a: |+2\n   x\n"), '{"a":" x\\n"}')
    assert_equal(_json("a: |\nb: 1\n"), '{"a":"","b":1}')
    assert_equal(_json("a: |+\n\n\nb: 1\n"), '{"a":"\\n\\n","b":1}')
    assert_equal(
        _error("a: |x\n  y\n"), "line 1: an invalid block scalar header"
    )
    assert_equal(
        _error("a: |--\n  y\n"), "line 1: an invalid block scalar header"
    )
    assert_equal(
        _error("a: |22\n  y\n"), "line 1: an invalid block scalar header"
    )
    assert_equal(
        _error("a: |\n    x\n   y\n"),
        "line 3: a block scalar line is indented too little",
    )


def test_plain_scalars() raises:
    assert_equal(
        _json(
            "a: ~\nb: null\nc: NULL\nd: true\ne: False\nf: TRUE\ng: false\nh:"
            " Null\ni: True\nj: FALSE\n"
        ),
        '{"a":null,"b":null,"c":null,"d":true,"e":false,"f":true,"g":false,"h":null,"i":true,"j":false}',
    )
    assert_equal(
        _json(
            "a: 42\nb: -7\nc: +3\nd: 2.5\ne: 1234567890123456789\nf: -\ng: 1x\n"
        ),
        '{"a":42,"b":-7,"c":3,"d":"2.5","e":"1234567890123456789","f":"-","g":"1x"}',
    )
    assert_equal(_json("a:\n  one\n  two\n"), '{"a":"one two"}')
    assert_equal(_json("a: http://x:1/y\n"), '{"a":"http://x:1/y"}')
    assert_equal(
        _error("a: b: c\n"), "line 1: a mapping value is not allowed here"
    )


def test_flow_and_json() raises:
    assert_equal(_json("a: {}\nb: []\n"), '{"a":{},"b":[]}')
    for text in [
        "a: {b: 1}\n",
        "a: [1]\n",
        "a: &x 1\n",
        "a: *x\n",
        "a: !t x\n",
        "a: %x\n",
        "a: @x\n",
        "a: `x\n",
    ]:
        assert_equal(
            _error(text),
            (
                "line 1: flow collections, anchors, aliases and tags are not"
                " supported"
            ),
        )
    assert_equal(_json('  {"a": [1, {"b": null}]}'), '{"a":[1,{"b":null}]}')
    assert_equal(_json("[true]"), "[true]")
    assert_true(_error('{"a": }').find("line 1") >= 0)


def test_structure_errors() raises:
    assert_equal(
        _error("a:\n\tb: 1\n"),
        "line 2: a tab character is not valid indentation",
    )
    assert_equal(
        _error("a: 1\n  b: 2\n"), "line 2: a mapping entry is indented too far"
    )
    assert_equal(_error("a: 1\nfoo\n"), "line 2: a mapping entry was expected")
    assert_equal(_error("a: 1\na: 2\n"), "line 2: the key `a` is repeated")
    assert_equal(_error(": 1\n"), "line 1: a mapping entry has no key")
    assert_equal(
        _error("- a\n  - b\n"), "line 2: a sequence entry is indented too far"
    )
    assert_equal(_error("- a\n  b\n"), "line 2: a sequence entry was expected")
    assert_equal(
        _error("  a: 1\nb: 2\n"), "line 2: unexpected text after the value"
    )
    assert_equal(_error("a: 1\n- b\n"), "line 2: a mapping entry was expected")
    assert_equal(_error("a: |++\n"), "line 1: an invalid block scalar header")
    assert_equal(
        _error('a: "\\x4g"\n'), "line 1: an invalid hexadecimal escape"
    )


def test_nesting_edges() raises:
    assert_equal(_json("-\n- b\n"), '[null,"b"]')
    assert_equal(_json("x:\n  a:\nb: 1\n"), '{"x":{"a":null},"b":1}')
    assert_equal(_json("a:\n  'x'\n"), '{"a":"x"}')
    assert_equal(_json("a:\n  x\nb: 1\n"), '{"a":"x","b":1}')
    assert_equal(_json("a: |\n  x\n  "), '{"a":"x\\n"}')
    assert_equal(_json("a: >\nb: 1\n"), '{"a":"","b":1}')
    assert_equal(_json("a: 1\n\t\n"), '{"a":1}')
    assert_equal(strip_comment("a\t# c"), "a")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
