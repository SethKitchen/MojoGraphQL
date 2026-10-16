# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for leaf serialization in `gql_execution.execute`: the
`serialize` functions of graphql-js 16.14.2 `type/scalars.ts` and of
`GraphQLEnumType`, which `src/type/__tests__/scalars-test.ts` and
`enumType-test.ts` test.

Each case executes `{ f }` with a JSON root value `{ f: value }`, for
each built-in scalar, an enum and a custom scalar. The expected results
are those of graphql-js 16.14.2 with the same values. The values cover
the `Number(string)` conversion of `Int` and `Float`: white space, signs,
`0x`, `0o` and `0b`, exponents, and the text that is not a number.

The upstream cases with objects that have `valueOf` or `toJSON`, with
`BigInt` and with symbols are not ported: an arena holds none of them.
"""

from std.testing import TestSuite, assert_equal
from _helpers import json_value, run_query
from gql_execution.execute import ExecutionArgs
from gql_schema.build import build_schema
from gql_schema.validate import assert_valid_schema


def check(type: String, cases: List[String]) raises:
    var schema = build_schema(
        "enum Color { RED GREEN } scalar Custom type Query { f: " + type + " }"
    )
    assert_valid_schema(schema)
    var index = 0
    while index < len(cases):
        var args = ExecutionArgs()
        args.assume_valid_schema = True
        args.root_value = json_value(args.values, '{"f": ' + cases[index] + "}")
        assert_equal(run_query(schema, "{ f }", args), cases[index + 1])
        index += 2


def test_serialize_int() raises:
    var cases: List[String] = [
        "null",
        '{"data":{"f":null}}',
        "true",
        '{"data":{"f":1}}',
        "false",
        '{"data":{"f":0}}',
        "0",
        '{"data":{"f":0}}',
        "-0",
        '{"data":{"f":0}}',
        "1",
        '{"data":{"f":1}}',
        "-1",
        '{"data":{"f":-1}}',
        "0.1",
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: 0.1'
            '","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":n'
            "ull}}"
        ),
        "1.5",
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: 1.5'
            '","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":n'
            "ull}}"
        ),
        "1e3",
        '{"data":{"f":1000}}',
        "1e100",
        (
            '{"errors":[{"message":"Int cannot represent non 32-bit signed inte'
            'ger value: 1e+100","locations":[{"line":1,"column":3}],"path":["f"'
            ']}],"data":{"f":null}}'
        ),
        "-1e100",
        (
            '{"errors":[{"message":"Int cannot represent non 32-bit signed inte'
            'ger value: -1e+100","locations":[{"line":1,"column":3}],"path":["f'
            '"]}],"data":{"f":null}}'
        ),
        "2147483647",
        '{"data":{"f":2147483647}}',
        "2147483648",
        (
            '{"errors":[{"message":"Int cannot represent non 32-bit signed inte'
            'ger value: 2147483648","locations":[{"line":1,"column":3}],"path":'
            '["f"]}],"data":{"f":null}}'
        ),
        "-2147483648",
        '{"data":{"f":-2147483648}}',
        "-2147483649",
        (
            '{"errors":[{"message":"Int cannot represent non 32-bit signed inte'
            'ger value: -2147483649","locations":[{"line":1,"column":3}],"path"'
            ':["f"]}],"data":{"f":null}}'
        ),
        "9007199254740993",
        (
            '{"errors":[{"message":"Int cannot represent non 32-bit signed inte'
            'ger value: 9007199254740992","locations":[{"line":1,"column":3}],"'
            'path":["f"]}],"data":{"f":null}}'
        ),
        '""',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f'
            '":null}}'
        ),
        '" "',
        '{"data":{"f":0}}',
        '"1"',
        '{"data":{"f":1}}',
        '"-1.5"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '-1.5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '" 12 "',
        '{"data":{"f":12}}',
        '"\\t7\\n"',
        '{"data":{"f":7}}',
        '"0x1F"',
        '{"data":{"f":31}}',
        '"0o17"',
        '{"data":{"f":15}}',
        '"0b101"',
        '{"data":{"f":5}}',
        '"0xZ"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '0xZ\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"1e3"',
        '{"data":{"f":1000}}',
        '"1E-2"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '1E-2\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"+5"',
        '{"data":{"f":5}}',
        '".5"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '.5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"5."',
        '{"data":{"f":5}}',
        '"."',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '.\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"'
            'f":null}}'
        ),
        '"1_000"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '1_000\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
        '"abc"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            'abc\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"Infinity"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            'Infinity\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        '"-Infinity"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '-Infinity\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"+Infinity"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '+Infinity\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"1e400"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '1e400\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
        '"\\u00a0 3 \\u3000"',
        '{"data":{"f":3}}',
        '"1e"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '1e\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"1e+"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '1e+\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"--1"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '--1\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"RED"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            'RED\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"red"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            'red\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        "[1, 2]",
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: [1,'
            ' 2]","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f'
            '":null}}'
        ),
        '{"a": 1}',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: { a'
            ': 1 }","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        "{}",
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: {}"'
            ',"locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":nu'
            "ll}}"
        ),
        "[]",
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: []"'
            ',"locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":nu'
            "ll}}"
        ),
        '[[1], {"b": null}]',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: [[1'
            '], { b: null }]","locations":[{"line":1,"column":3}],"path":["f"]}'
            '],"data":{"f":null}}'
        ),
        '"\\ufeff8"',
        '{"data":{"f":8}}',
        '"0x"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '0x\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"00012"',
        '{"data":{"f":12}}',
        '"-"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '-\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"'
            'f":null}}'
        ),
        '"e5"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            'e5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"\\u000b5"',
        '{"data":{"f":5}}',
        '"\\u16805"',
        '{"data":{"f":5}}',
        '"\\u20005"',
        '{"data":{"f":5}}',
        '"\\u200a5\\u2028"',
        '{"data":{"f":5}}',
        '"\\u2029 5"',
        '{"data":{"f":5}}',
        '"\\u202f5\\u205f"',
        '{"data":{"f":5}}',
        '"0x!"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '0x!\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"0x:"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '0x:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"0xg"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '0xg\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"0x`"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '0x`\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"0xF"',
        '{"data":{"f":15}}',
        '"0o8"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '0o8\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"0b2"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '0b2\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"1/"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '1/\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"1:"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '1:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"1./"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '1./\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"1e5/"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '1e5/\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"1e5:"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '1e5:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"\\u00e9"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            'é\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"'
            'f":null}}'
        ),
        '"5\\u00e9"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '5é\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"\\u00e95"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            'é5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"\\ud83d\\ude005"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '😀5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"\\u0001 5"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '\\\\u0001 5\\"","locations":[{"line":1,"column":3}],"path":["f"]}]'
            ',"data":{"f":null}}'
        ),
        '"\\u00a9 5"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '© 5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"1.5:"',
        (
            '{"errors":[{"message":"Int cannot represent non-integer value: \\"'
            '1.5:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
    ]
    check("Int", cases)


def test_serialize_float() raises:
    var cases: List[String] = [
        "null",
        '{"data":{"f":null}}',
        "true",
        '{"data":{"f":1}}',
        "false",
        '{"data":{"f":0}}',
        "0",
        '{"data":{"f":0}}',
        "-0",
        '{"data":{"f":0}}',
        "1",
        '{"data":{"f":1}}',
        "-1",
        '{"data":{"f":-1}}',
        "0.1",
        '{"data":{"f":0.1}}',
        "1.5",
        '{"data":{"f":1.5}}',
        "1e3",
        '{"data":{"f":1000}}',
        "1e100",
        '{"data":{"f":1e+100}}',
        "-1e100",
        '{"data":{"f":-1e+100}}',
        "2147483647",
        '{"data":{"f":2147483647}}',
        "2147483648",
        '{"data":{"f":2147483648}}',
        "-2147483648",
        '{"data":{"f":-2147483648}}',
        "-2147483649",
        '{"data":{"f":-2147483649}}',
        "9007199254740993",
        '{"data":{"f":9007199254740992}}',
        '""',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"'
            'f":null}}'
        ),
        '" "',
        '{"data":{"f":0}}',
        '"1"',
        '{"data":{"f":1}}',
        '"-1.5"',
        '{"data":{"f":-1.5}}',
        '" 12 "',
        '{"data":{"f":12}}',
        '"\\t7\\n"',
        '{"data":{"f":7}}',
        '"0x1F"',
        '{"data":{"f":31}}',
        '"0o17"',
        '{"data":{"f":15}}',
        '"0b101"',
        '{"data":{"f":5}}',
        '"0xZ"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"0xZ\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"1e3"',
        '{"data":{"f":1000}}',
        '"1E-2"',
        '{"data":{"f":0.01}}',
        '"+5"',
        '{"data":{"f":5}}',
        '".5"',
        '{"data":{"f":0.5}}',
        '"5."',
        '{"data":{"f":5}}',
        '"."',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '".\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"1_000"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"1_000\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"dat'
            'a":{"f":null}}'
        ),
        '"abc"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"abc\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"Infinity"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"Infinity\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"-Infinity"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"-Infinity\\"","locations":[{"line":1,"column":3}],"path":["f"]}],'
            '"data":{"f":null}}'
        ),
        '"+Infinity"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"+Infinity\\"","locations":[{"line":1,"column":3}],"path":["f"]}],'
            '"data":{"f":null}}'
        ),
        '"1e400"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"1e400\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"dat'
            'a":{"f":null}}'
        ),
        '"\\u00a0 3 \\u3000"',
        '{"data":{"f":3}}',
        '"1e"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"1e\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"1e+"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"1e+\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"--1"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"--1\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"RED"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"RED\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"red"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"red\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        "[1, 2]",
        (
            '{"errors":[{"message":"Float cannot represent non numeric value: ['
            '1, 2]","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '{"a": 1}',
        (
            '{"errors":[{"message":"Float cannot represent non numeric value: {'
            ' a: 1 }","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        "{}",
        (
            '{"errors":[{"message":"Float cannot represent non numeric value: {'
            '}","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":'
            "null}}"
        ),
        "[]",
        (
            '{"errors":[{"message":"Float cannot represent non numeric value: ['
            ']","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":'
            "null}}"
        ),
        '[[1], {"b": null}]',
        (
            '{"errors":[{"message":"Float cannot represent non numeric value: ['
            '[1], { b: null }]","locations":[{"line":1,"column":3}],"path":["f"'
            ']}],"data":{"f":null}}'
        ),
        '"\\ufeff8"',
        '{"data":{"f":8}}',
        '"0x"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"0x\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"00012"',
        '{"data":{"f":12}}',
        '"-"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"-\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"e5"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"e5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"\\u000b5"',
        '{"data":{"f":5}}',
        '"\\u16805"',
        '{"data":{"f":5}}',
        '"\\u20005"',
        '{"data":{"f":5}}',
        '"\\u200a5\\u2028"',
        '{"data":{"f":5}}',
        '"\\u2029 5"',
        '{"data":{"f":5}}',
        '"\\u202f5\\u205f"',
        '{"data":{"f":5}}',
        '"0x!"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"0x!\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"0x:"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"0x:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"0xg"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"0xg\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"0x`"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"0x`\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"0xF"',
        '{"data":{"f":15}}',
        '"0o8"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"0o8\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"0b2"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"0b2\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"1/"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"1/\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"1:"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"1:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"1./"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"1./\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"1e5/"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"1e5/\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
        '"1e5:"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"1e5:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
        '"\\u00e9"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"é\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"5\\u00e9"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"5é\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"\\u00e95"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"é5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"\\ud83d\\ude005"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"😀5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"\\u0001 5"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"\\\\u0001 5\\"","locations":[{"line":1,"column":3}],"path":["f"]}'
            '],"data":{"f":null}}'
        ),
        '"\\u00a9 5"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"© 5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"1.5:"',
        (
            '{"errors":[{"message":"Float cannot represent non numeric'
            " value: \\"
            '"1.5:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
    ]
    check("Float", cases)


def test_serialize_string() raises:
    var cases: List[String] = [
        "null",
        '{"data":{"f":null}}',
        "true",
        '{"data":{"f":"true"}}',
        "false",
        '{"data":{"f":"false"}}',
        "0",
        '{"data":{"f":"0"}}',
        "-0",
        '{"data":{"f":"0"}}',
        "1",
        '{"data":{"f":"1"}}',
        "-1",
        '{"data":{"f":"-1"}}',
        "0.1",
        '{"data":{"f":"0.1"}}',
        "1.5",
        '{"data":{"f":"1.5"}}',
        "1e3",
        '{"data":{"f":"1000"}}',
        "1e100",
        '{"data":{"f":"1e+100"}}',
        "-1e100",
        '{"data":{"f":"-1e+100"}}',
        "2147483647",
        '{"data":{"f":"2147483647"}}',
        "2147483648",
        '{"data":{"f":"2147483648"}}',
        "-2147483648",
        '{"data":{"f":"-2147483648"}}',
        "-2147483649",
        '{"data":{"f":"-2147483649"}}',
        "9007199254740993",
        '{"data":{"f":"9007199254740992"}}',
        '""',
        '{"data":{"f":""}}',
        '" "',
        '{"data":{"f":" "}}',
        '"1"',
        '{"data":{"f":"1"}}',
        '"-1.5"',
        '{"data":{"f":"-1.5"}}',
        '" 12 "',
        '{"data":{"f":" 12 "}}',
        '"\\t7\\n"',
        '{"data":{"f":"\\t7\\n"}}',
        '"0x1F"',
        '{"data":{"f":"0x1F"}}',
        '"0o17"',
        '{"data":{"f":"0o17"}}',
        '"0b101"',
        '{"data":{"f":"0b101"}}',
        '"0xZ"',
        '{"data":{"f":"0xZ"}}',
        '"1e3"',
        '{"data":{"f":"1e3"}}',
        '"1E-2"',
        '{"data":{"f":"1E-2"}}',
        '"+5"',
        '{"data":{"f":"+5"}}',
        '".5"',
        '{"data":{"f":".5"}}',
        '"5."',
        '{"data":{"f":"5."}}',
        '"."',
        '{"data":{"f":"."}}',
        '"1_000"',
        '{"data":{"f":"1_000"}}',
        '"abc"',
        '{"data":{"f":"abc"}}',
        '"Infinity"',
        '{"data":{"f":"Infinity"}}',
        '"-Infinity"',
        '{"data":{"f":"-Infinity"}}',
        '"+Infinity"',
        '{"data":{"f":"+Infinity"}}',
        '"1e400"',
        '{"data":{"f":"1e400"}}',
        '"\\u00a0 3 \\u3000"',
        '{"data":{"f":"  3 　"}}',
        '"1e"',
        '{"data":{"f":"1e"}}',
        '"1e+"',
        '{"data":{"f":"1e+"}}',
        '"--1"',
        '{"data":{"f":"--1"}}',
        '"RED"',
        '{"data":{"f":"RED"}}',
        '"red"',
        '{"data":{"f":"red"}}',
        "[1, 2]",
        (
            '{"errors":[{"message":"String cannot represent value: [1, 2]","loc'
            'ations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":null}}'
        ),
        '{"a": 1}',
        (
            '{"errors":[{"message":"String cannot represent value: { a: 1 }","l'
            'ocations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":null}'
            "}"
        ),
        "{}",
        (
            '{"errors":[{"message":"String cannot represent value: {}","locatio'
            'ns":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":null}}'
        ),
        "[]",
        (
            '{"errors":[{"message":"String cannot represent value: []","locatio'
            'ns":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":null}}'
        ),
        '[[1], {"b": null}]',
        (
            '{"errors":[{"message":"String cannot represent value: [[1], { b: n'
            'ull }]","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"\\ufeff8"',
        '{"data":{"f":"﻿8"}}',
        '"0x"',
        '{"data":{"f":"0x"}}',
        '"00012"',
        '{"data":{"f":"00012"}}',
        '"-"',
        '{"data":{"f":"-"}}',
        '"e5"',
        '{"data":{"f":"e5"}}',
        '"\\u000b5"',
        '{"data":{"f":"\\u000b5"}}',
        '"\\u16805"',
        '{"data":{"f":" 5"}}',
        '"\\u20005"',
        '{"data":{"f":" 5"}}',
        '"\\u200a5\\u2028"',
        '{"data":{"f":" 5 "}}',
        '"\\u2029 5"',
        '{"data":{"f":"  5"}}',
        '"\\u202f5\\u205f"',
        '{"data":{"f":" 5 "}}',
        '"0x!"',
        '{"data":{"f":"0x!"}}',
        '"0x:"',
        '{"data":{"f":"0x:"}}',
        '"0xg"',
        '{"data":{"f":"0xg"}}',
        '"0x`"',
        '{"data":{"f":"0x`"}}',
        '"0xF"',
        '{"data":{"f":"0xF"}}',
        '"0o8"',
        '{"data":{"f":"0o8"}}',
        '"0b2"',
        '{"data":{"f":"0b2"}}',
        '"1/"',
        '{"data":{"f":"1/"}}',
        '"1:"',
        '{"data":{"f":"1:"}}',
        '"1./"',
        '{"data":{"f":"1./"}}',
        '"1e5/"',
        '{"data":{"f":"1e5/"}}',
        '"1e5:"',
        '{"data":{"f":"1e5:"}}',
        '"\\u00e9"',
        '{"data":{"f":"é"}}',
        '"5\\u00e9"',
        '{"data":{"f":"5é"}}',
        '"\\u00e95"',
        '{"data":{"f":"é5"}}',
        '"\\ud83d\\ude005"',
        '{"data":{"f":"😀5"}}',
        '"\\u0001 5"',
        '{"data":{"f":"\\u0001 5"}}',
        '"\\u00a9 5"',
        '{"data":{"f":"© 5"}}',
        '"1.5:"',
        '{"data":{"f":"1.5:"}}',
    ]
    check("String", cases)


def test_serialize_boolean() raises:
    var cases: List[String] = [
        "null",
        '{"data":{"f":null}}',
        "true",
        '{"data":{"f":true}}',
        "false",
        '{"data":{"f":false}}',
        "0",
        '{"data":{"f":false}}',
        "-0",
        '{"data":{"f":false}}',
        "1",
        '{"data":{"f":true}}',
        "-1",
        '{"data":{"f":true}}',
        "0.1",
        '{"data":{"f":true}}',
        "1.5",
        '{"data":{"f":true}}',
        "1e3",
        '{"data":{"f":true}}',
        "1e100",
        '{"data":{"f":true}}',
        "-1e100",
        '{"data":{"f":true}}',
        "2147483647",
        '{"data":{"f":true}}',
        "2147483648",
        '{"data":{"f":true}}',
        "-2147483648",
        '{"data":{"f":true}}',
        "-2147483649",
        '{"data":{"f":true}}',
        "9007199254740993",
        '{"data":{"f":true}}',
        '""',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"dat'
            'a":{"f":null}}'
        ),
        '" "',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\" \\"","locations":[{"line":1,"column":3}],"path":["f"]}],"da'
            'ta":{"f":null}}'
        ),
        '"1"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"1\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"da'
            'ta":{"f":null}}'
        ),
        '"-1.5"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"-1.5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],'
            '"data":{"f":null}}'
        ),
        '" 12 "',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\" 12 \\"","locations":[{"line":1,"column":3}],"path":["f"]}],'
            '"data":{"f":null}}'
        ),
        '"\\t7\\n"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"\\\\t7\\\\n\\"","locations":[{"line":1,"column":3}],"path":['
            '"f"]}],"data":{"f":null}}'
        ),
        '"0x1F"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"0x1F\\"","locations":[{"line":1,"column":3}],"path":["f"]}],'
            '"data":{"f":null}}'
        ),
        '"0o17"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"0o17\\"","locations":[{"line":1,"column":3}],"path":["f"]}],'
            '"data":{"f":null}}'
        ),
        '"0b101"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"0b101\\"","locations":[{"line":1,"column":3}],"path":["f"]}]'
            ',"data":{"f":null}}'
        ),
        '"0xZ"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"0xZ\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"1e3"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"1e3\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"1E-2"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"1E-2\\"","locations":[{"line":1,"column":3}],"path":["f"]}],'
            '"data":{"f":null}}'
        ),
        '"+5"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"+5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        '".5"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\".5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        '"5."',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"5.\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        '"."',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\".\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"da'
            'ta":{"f":null}}'
        ),
        '"1_000"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"1_000\\"","locations":[{"line":1,"column":3}],"path":["f"]}]'
            ',"data":{"f":null}}'
        ),
        '"abc"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"abc\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"Infinity"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"Infinity\\"","locations":[{"line":1,"column":3}],"path":["f"'
            ']}],"data":{"f":null}}'
        ),
        '"-Infinity"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"-Infinity\\"","locations":[{"line":1,"column":3}],"path":["f'
            '"]}],"data":{"f":null}}'
        ),
        '"+Infinity"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"+Infinity\\"","locations":[{"line":1,"column":3}],"path":["f'
            '"]}],"data":{"f":null}}'
        ),
        '"1e400"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"1e400\\"","locations":[{"line":1,"column":3}],"path":["f"]}]'
            ',"data":{"f":null}}'
        ),
        '"\\u00a0 3 \\u3000"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"  3 　\\"","locations":[{"line":1,"column":3}],"path":["f"]}]'
            ',"data":{"f":null}}'
        ),
        '"1e"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"1e\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        '"1e+"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"1e+\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"--1"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"--1\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"RED"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"RED\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"red"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"red\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        "[1, 2]",
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: [1, 2]","locations":[{"line":1,"column":3}],"path":["f"]}],"dat'
            'a":{"f":null}}'
        ),
        '{"a": 1}',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: { a: 1 }","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        "{}",
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: {}","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        "[]",
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: []","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '[[1], {"b": null}]',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: [[1], { b: null }]","locations":[{"line":1,"column":3}],"path":'
            '["f"]}],"data":{"f":null}}'
        ),
        '"\\ufeff8"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"﻿8\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        '"0x"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"0x\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        '"00012"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"00012\\"","locations":[{"line":1,"column":3}],"path":["f"]}]'
            ',"data":{"f":null}}'
        ),
        '"-"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"-\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"da'
            'ta":{"f":null}}'
        ),
        '"e5"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"e5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        '"\\u000b5"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"\\\\u000b5\\"","locations":[{"line":1,"column":3}],"path":["'
            'f"]}],"data":{"f":null}}'
        ),
        '"\\u16805"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\" 5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        '"\\u20005"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\" 5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        '"\\u200a5\\u2028"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\" 5 \\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"\\u2029 5"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"  5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"\\u202f5\\u205f"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\" 5 \\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"0x!"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"0x!\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"0x:"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"0x:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"0xg"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"0xg\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"0x`"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"0x`\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"0xF"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"0xF\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"0o8"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"0o8\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"0b2"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"0b2\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"1/"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"1/\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        '"1:"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"1:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        '"1./"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"1./\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"1e5/"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"1e5/\\"","locations":[{"line":1,"column":3}],"path":["f"]}],'
            '"data":{"f":null}}'
        ),
        '"1e5:"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"1e5:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],'
            '"data":{"f":null}}'
        ),
        '"\\u00e9"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"é\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"da'
            'ta":{"f":null}}'
        ),
        '"5\\u00e9"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"5é\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        '"\\u00e95"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"é5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"d'
            'ata":{"f":null}}'
        ),
        '"\\ud83d\\ude005"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"😀5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"\\u0001 5"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"\\\\u0001 5\\"","locations":[{"line":1,"column":3}],"path":['
            '"f"]}],"data":{"f":null}}'
        ),
        '"\\u00a9 5"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"© 5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"1.5:"',
        (
            '{"errors":[{"message":"Boolean cannot represent a non boolean valu'
            'e: \\"1.5:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],'
            '"data":{"f":null}}'
        ),
    ]
    check("Boolean", cases)


def test_serialize_id() raises:
    var cases: List[String] = [
        "null",
        '{"data":{"f":null}}',
        "true",
        (
            '{"errors":[{"message":"ID cannot represent value: true","locations'
            '":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":null}}'
        ),
        "false",
        (
            '{"errors":[{"message":"ID cannot represent value: false","location'
            's":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":null}}'
        ),
        "0",
        '{"data":{"f":"0"}}',
        "-0",
        '{"data":{"f":"0"}}',
        "1",
        '{"data":{"f":"1"}}',
        "-1",
        '{"data":{"f":"-1"}}',
        "0.1",
        (
            '{"errors":[{"message":"ID cannot represent value: 0.1","locations"'
            ':[{"line":1,"column":3}],"path":["f"]}],"data":{"f":null}}'
        ),
        "1.5",
        (
            '{"errors":[{"message":"ID cannot represent value: 1.5","locations"'
            ':[{"line":1,"column":3}],"path":["f"]}],"data":{"f":null}}'
        ),
        "1e3",
        '{"data":{"f":"1000"}}',
        "1e100",
        '{"data":{"f":"1e+100"}}',
        "-1e100",
        '{"data":{"f":"-1e+100"}}',
        "2147483647",
        '{"data":{"f":"2147483647"}}',
        "2147483648",
        '{"data":{"f":"2147483648"}}',
        "-2147483648",
        '{"data":{"f":"-2147483648"}}',
        "-2147483649",
        '{"data":{"f":"-2147483649"}}',
        "9007199254740993",
        '{"data":{"f":"9007199254740992"}}',
        '""',
        '{"data":{"f":""}}',
        '" "',
        '{"data":{"f":" "}}',
        '"1"',
        '{"data":{"f":"1"}}',
        '"-1.5"',
        '{"data":{"f":"-1.5"}}',
        '" 12 "',
        '{"data":{"f":" 12 "}}',
        '"\\t7\\n"',
        '{"data":{"f":"\\t7\\n"}}',
        '"0x1F"',
        '{"data":{"f":"0x1F"}}',
        '"0o17"',
        '{"data":{"f":"0o17"}}',
        '"0b101"',
        '{"data":{"f":"0b101"}}',
        '"0xZ"',
        '{"data":{"f":"0xZ"}}',
        '"1e3"',
        '{"data":{"f":"1e3"}}',
        '"1E-2"',
        '{"data":{"f":"1E-2"}}',
        '"+5"',
        '{"data":{"f":"+5"}}',
        '".5"',
        '{"data":{"f":".5"}}',
        '"5."',
        '{"data":{"f":"5."}}',
        '"."',
        '{"data":{"f":"."}}',
        '"1_000"',
        '{"data":{"f":"1_000"}}',
        '"abc"',
        '{"data":{"f":"abc"}}',
        '"Infinity"',
        '{"data":{"f":"Infinity"}}',
        '"-Infinity"',
        '{"data":{"f":"-Infinity"}}',
        '"+Infinity"',
        '{"data":{"f":"+Infinity"}}',
        '"1e400"',
        '{"data":{"f":"1e400"}}',
        '"\\u00a0 3 \\u3000"',
        '{"data":{"f":"  3 　"}}',
        '"1e"',
        '{"data":{"f":"1e"}}',
        '"1e+"',
        '{"data":{"f":"1e+"}}',
        '"--1"',
        '{"data":{"f":"--1"}}',
        '"RED"',
        '{"data":{"f":"RED"}}',
        '"red"',
        '{"data":{"f":"red"}}',
        "[1, 2]",
        (
            '{"errors":[{"message":"ID cannot represent value: [1, 2]","locatio'
            'ns":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":null}}'
        ),
        '{"a": 1}',
        (
            '{"errors":[{"message":"ID cannot represent value: { a: 1 }","locat'
            'ions":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":null}}'
        ),
        "{}",
        (
            '{"errors":[{"message":"ID cannot represent value: {}","locations":'
            '[{"line":1,"column":3}],"path":["f"]}],"data":{"f":null}}'
        ),
        "[]",
        (
            '{"errors":[{"message":"ID cannot represent value: []","locations":'
            '[{"line":1,"column":3}],"path":["f"]}],"data":{"f":null}}'
        ),
        '[[1], {"b": null}]',
        (
            '{"errors":[{"message":"ID cannot represent value: [[1], { b: null '
            '}]","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f"'
            ":null}}"
        ),
        '"\\ufeff8"',
        '{"data":{"f":"﻿8"}}',
        '"0x"',
        '{"data":{"f":"0x"}}',
        '"00012"',
        '{"data":{"f":"00012"}}',
        '"-"',
        '{"data":{"f":"-"}}',
        '"e5"',
        '{"data":{"f":"e5"}}',
        '"\\u000b5"',
        '{"data":{"f":"\\u000b5"}}',
        '"\\u16805"',
        '{"data":{"f":" 5"}}',
        '"\\u20005"',
        '{"data":{"f":" 5"}}',
        '"\\u200a5\\u2028"',
        '{"data":{"f":" 5 "}}',
        '"\\u2029 5"',
        '{"data":{"f":"  5"}}',
        '"\\u202f5\\u205f"',
        '{"data":{"f":" 5 "}}',
        '"0x!"',
        '{"data":{"f":"0x!"}}',
        '"0x:"',
        '{"data":{"f":"0x:"}}',
        '"0xg"',
        '{"data":{"f":"0xg"}}',
        '"0x`"',
        '{"data":{"f":"0x`"}}',
        '"0xF"',
        '{"data":{"f":"0xF"}}',
        '"0o8"',
        '{"data":{"f":"0o8"}}',
        '"0b2"',
        '{"data":{"f":"0b2"}}',
        '"1/"',
        '{"data":{"f":"1/"}}',
        '"1:"',
        '{"data":{"f":"1:"}}',
        '"1./"',
        '{"data":{"f":"1./"}}',
        '"1e5/"',
        '{"data":{"f":"1e5/"}}',
        '"1e5:"',
        '{"data":{"f":"1e5:"}}',
        '"\\u00e9"',
        '{"data":{"f":"é"}}',
        '"5\\u00e9"',
        '{"data":{"f":"5é"}}',
        '"\\u00e95"',
        '{"data":{"f":"é5"}}',
        '"\\ud83d\\ude005"',
        '{"data":{"f":"😀5"}}',
        '"\\u0001 5"',
        '{"data":{"f":"\\u0001 5"}}',
        '"\\u00a9 5"',
        '{"data":{"f":"© 5"}}',
        '"1.5:"',
        '{"data":{"f":"1.5:"}}',
    ]
    check("ID", cases)


def test_serialize_color() raises:
    var cases: List[String] = [
        "null",
        '{"data":{"f":null}}',
        "true",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: tr'
            'ue","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f"'
            ":null}}"
        ),
        "false",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: fa'
            'lse","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f'
            '":null}}'
        ),
        "0",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: 0"'
            ',"locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":nu'
            "ll}}"
        ),
        "-0",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: 0"'
            ',"locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":nu'
            "ll}}"
        ),
        "1",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: 1"'
            ',"locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":nu'
            "ll}}"
        ),
        "-1",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: -1'
            '","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":n'
            "ull}}"
        ),
        "0.1",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: 0.'
            '1","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":'
            "null}}"
        ),
        "1.5",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: 1.'
            '5","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":'
            "null}}"
        ),
        "1e3",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: 10'
            '00","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f"'
            ":null}}"
        ),
        "1e100",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: 1e'
            '+100","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"'
            'f":null}}'
        ),
        "-1e100",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: -1'
            'e+100","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        "2147483647",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: 21'
            '47483647","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
        "2147483648",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: 21'
            '47483648","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
        "-2147483648",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: -2'
            '147483648","locations":[{"line":1,"column":3}],"path":["f"]}],"dat'
            'a":{"f":null}}'
        ),
        "-2147483649",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: -2'
            '147483649","locations":[{"line":1,"column":3}],"path":["f"]}],"dat'
            'a":{"f":null}}'
        ),
        "9007199254740993",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: 90'
            '07199254740992","locations":[{"line":1,"column":3}],"path":["f"]}]'
            ',"data":{"f":null}}'
        ),
        '""',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"'
            'f":null}}'
        ),
        '" "',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '" \\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"1"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"1\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"-1.5"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"-1.5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
        '" 12 "',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '" 12 \\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
        '"\\t7\\n"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"\\\\t7\\\\n\\"","locations":[{"line":1,"column":3}],"path":["f"]}'
            '],"data":{"f":null}}'
        ),
        '"0x1F"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"0x1F\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
        '"0o17"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"0o17\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
        '"0b101"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"0b101\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"dat'
            'a":{"f":null}}'
        ),
        '"0xZ"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"0xZ\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"1e3"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"1e3\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"1E-2"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"1E-2\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
        '"+5"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"+5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '".5"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '".5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"5."',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"5.\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"."',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '".\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"1_000"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"1_000\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"dat'
            'a":{"f":null}}'
        ),
        '"abc"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"abc\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"Infinity"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"Infinity\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"'
            'data":{"f":null}}'
        ),
        '"-Infinity"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"-Infinity\\"","locations":[{"line":1,"column":3}],"path":["f"]}],'
            '"data":{"f":null}}'
        ),
        '"+Infinity"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"+Infinity\\"","locations":[{"line":1,"column":3}],"path":["f"]}],'
            '"data":{"f":null}}'
        ),
        '"1e400"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"1e400\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"dat'
            'a":{"f":null}}'
        ),
        '"\\u00a0 3 \\u3000"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"  3 　\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"dat'
            'a":{"f":null}}'
        ),
        '"1e"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"1e\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"1e+"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"1e+\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"--1"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"--1\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"RED"',
        '{"data":{"f":"RED"}}',
        '"red"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"red\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        "[1, 2]",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: [1'
            ', 2]","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"'
            'f":null}}'
        ),
        '{"a": 1}',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: { '
            'a: 1 }","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        "{}",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: {}'
            '","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":n'
            "ull}}"
        ),
        "[]",
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: []'
            '","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{"f":n'
            "ull}}"
        ),
        '[[1], {"b": null}]',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: [['
            '1], { b: null }]","locations":[{"line":1,"column":3}],"path":["f"]'
            '}],"data":{"f":null}}'
        ),
        '"\\ufeff8"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"﻿8\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"0x"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"0x\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"00012"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"00012\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"dat'
            'a":{"f":null}}'
        ),
        '"-"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"-\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"e5"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"e5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"\\u000b5"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"\\\\u000b5\\"","locations":[{"line":1,"column":3}],"path":["f"]}]'
            ',"data":{"f":null}}'
        ),
        '"\\u16805"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '" 5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"\\u20005"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '" 5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"\\u200a5\\u2028"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '" 5 \\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"\\u2029 5"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"  5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"\\u202f5\\u205f"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '" 5 \\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"0x!"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"0x!\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"0x:"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"0x:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"0xg"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"0xg\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"0x`"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"0x`\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"0xF"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"0xF\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"0o8"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"0o8\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"0b2"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"0b2\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"1/"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"1/\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"1:"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"1:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"1./"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"1./\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"1e5/"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"1e5/\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
        '"1e5:"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"1e5:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
        '"\\u00e9"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"é\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":{'
            '"f":null}}'
        ),
        '"5\\u00e9"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"5é\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"\\u00e95"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"é5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data":'
            '{"f":null}}'
        ),
        '"\\ud83d\\ude005"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"😀5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"\\u0001 5"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"\\\\u0001 5\\"","locations":[{"line":1,"column":3}],"path":["f"]}'
            '],"data":{"f":null}}'
        ),
        '"\\u00a9 5"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"© 5\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data"'
            ':{"f":null}}'
        ),
        '"1.5:"',
        (
            '{"errors":[{"message":"Enum \\"Color\\" cannot represent value: \\'
            '"1.5:\\"","locations":[{"line":1,"column":3}],"path":["f"]}],"data'
            '":{"f":null}}'
        ),
    ]
    check("Color", cases)


def test_serialize_custom() raises:
    var cases: List[String] = [
        "null",
        '{"data":{"f":null}}',
        "true",
        '{"data":{"f":true}}',
        "false",
        '{"data":{"f":false}}',
        "0",
        '{"data":{"f":0}}',
        "-0",
        '{"data":{"f":0}}',
        "1",
        '{"data":{"f":1}}',
        "-1",
        '{"data":{"f":-1}}',
        "0.1",
        '{"data":{"f":0.1}}',
        "1.5",
        '{"data":{"f":1.5}}',
        "1e3",
        '{"data":{"f":1000}}',
        "1e100",
        '{"data":{"f":1e+100}}',
        "-1e100",
        '{"data":{"f":-1e+100}}',
        "2147483647",
        '{"data":{"f":2147483647}}',
        "2147483648",
        '{"data":{"f":2147483648}}',
        "-2147483648",
        '{"data":{"f":-2147483648}}',
        "-2147483649",
        '{"data":{"f":-2147483649}}',
        "9007199254740993",
        '{"data":{"f":9007199254740992}}',
        '""',
        '{"data":{"f":""}}',
        '" "',
        '{"data":{"f":" "}}',
        '"1"',
        '{"data":{"f":"1"}}',
        '"-1.5"',
        '{"data":{"f":"-1.5"}}',
        '" 12 "',
        '{"data":{"f":" 12 "}}',
        '"\\t7\\n"',
        '{"data":{"f":"\\t7\\n"}}',
        '"0x1F"',
        '{"data":{"f":"0x1F"}}',
        '"0o17"',
        '{"data":{"f":"0o17"}}',
        '"0b101"',
        '{"data":{"f":"0b101"}}',
        '"0xZ"',
        '{"data":{"f":"0xZ"}}',
        '"1e3"',
        '{"data":{"f":"1e3"}}',
        '"1E-2"',
        '{"data":{"f":"1E-2"}}',
        '"+5"',
        '{"data":{"f":"+5"}}',
        '".5"',
        '{"data":{"f":".5"}}',
        '"5."',
        '{"data":{"f":"5."}}',
        '"."',
        '{"data":{"f":"."}}',
        '"1_000"',
        '{"data":{"f":"1_000"}}',
        '"abc"',
        '{"data":{"f":"abc"}}',
        '"Infinity"',
        '{"data":{"f":"Infinity"}}',
        '"-Infinity"',
        '{"data":{"f":"-Infinity"}}',
        '"+Infinity"',
        '{"data":{"f":"+Infinity"}}',
        '"1e400"',
        '{"data":{"f":"1e400"}}',
        '"\\u00a0 3 \\u3000"',
        '{"data":{"f":"  3 　"}}',
        '"1e"',
        '{"data":{"f":"1e"}}',
        '"1e+"',
        '{"data":{"f":"1e+"}}',
        '"--1"',
        '{"data":{"f":"--1"}}',
        '"RED"',
        '{"data":{"f":"RED"}}',
        '"red"',
        '{"data":{"f":"red"}}',
        "[1, 2]",
        '{"data":{"f":[1,2]}}',
        '{"a": 1}',
        '{"data":{"f":{"a":1}}}',
        "{}",
        '{"data":{"f":{}}}',
        "[]",
        '{"data":{"f":[]}}',
        '[[1], {"b": null}]',
        '{"data":{"f":[[1],{"b":null}]}}',
        '"\\ufeff8"',
        '{"data":{"f":"﻿8"}}',
        '"0x"',
        '{"data":{"f":"0x"}}',
        '"00012"',
        '{"data":{"f":"00012"}}',
        '"-"',
        '{"data":{"f":"-"}}',
        '"e5"',
        '{"data":{"f":"e5"}}',
        '"\\u000b5"',
        '{"data":{"f":"\\u000b5"}}',
        '"\\u16805"',
        '{"data":{"f":" 5"}}',
        '"\\u20005"',
        '{"data":{"f":" 5"}}',
        '"\\u200a5\\u2028"',
        '{"data":{"f":" 5 "}}',
        '"\\u2029 5"',
        '{"data":{"f":"  5"}}',
        '"\\u202f5\\u205f"',
        '{"data":{"f":" 5 "}}',
        '"0x!"',
        '{"data":{"f":"0x!"}}',
        '"0x:"',
        '{"data":{"f":"0x:"}}',
        '"0xg"',
        '{"data":{"f":"0xg"}}',
        '"0x`"',
        '{"data":{"f":"0x`"}}',
        '"0xF"',
        '{"data":{"f":"0xF"}}',
        '"0o8"',
        '{"data":{"f":"0o8"}}',
        '"0b2"',
        '{"data":{"f":"0b2"}}',
        '"1/"',
        '{"data":{"f":"1/"}}',
        '"1:"',
        '{"data":{"f":"1:"}}',
        '"1./"',
        '{"data":{"f":"1./"}}',
        '"1e5/"',
        '{"data":{"f":"1e5/"}}',
        '"1e5:"',
        '{"data":{"f":"1e5:"}}',
        '"\\u00e9"',
        '{"data":{"f":"é"}}',
        '"5\\u00e9"',
        '{"data":{"f":"5é"}}',
        '"\\u00e95"',
        '{"data":{"f":"é5"}}',
        '"\\ud83d\\ude005"',
        '{"data":{"f":"😀5"}}',
        '"\\u0001 5"',
        '{"data":{"f":"\\u0001 5"}}',
        '"\\u00a9 5"',
        '{"data":{"f":"© 5"}}',
        '"1.5:"',
        '{"data":{"f":"1.5:"}}',
    ]
    check("Custom", cases)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
