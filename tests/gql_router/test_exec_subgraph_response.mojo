# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of the read of a subgraph response body.

Port of the tests of Hive Router `1a29df9`
`bin/router/src/executor/response/subgraph_response.rs`. The tests after
the ported ones cover the error cases of `read_subgraph_response` and the
read of the error objects.

**Differences from upstream.** Upstream reads the value at a custom scalar
path as `Value::RawJson`, so that its source text stays the same. This
port keeps the source text of every value, and has no custom scalar
paths. So the ported tests check that the value at the path writes its
source text again, and that the other values stay structured. The plan
part of `custom_and_builtin_scalar_sharing_response_path` is ported; the
custom scalar paths of its fetch are not, because the plan does not keep
them.
"""

from _plan_harness import _plan
from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_router.exec_subgraph_response import (
    SubgraphResponse,
    read_subgraph_response,
)
from gql_router.exec_value import (
    is_plain_string,
    object_get,
    string_text,
    write_value,
)
from gql_router.graphql_error import (
    ErrorSegmentKind,
    error_json,
    extension_value,
    graphql_error,
)
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def _body(text: StringSlice) -> List[UInt8]:
    """Return the bytes of a response body."""
    var out = List[UInt8]()
    out.extend(text.as_bytes())
    return out^


def _read(
    mut arena: JsonDocument, text: StringSlice
) raises -> SubgraphResponse:
    """Read a response body into an arena."""
    return read_subgraph_response(arena, _body(text))


def _json(document: JsonDocument, node: Int) -> String:
    """Return the JSON text of a value."""
    var out = List[UInt8]()
    write_value(document, node, out)
    return String(unsafe_from_utf8=out)


def _fails(text: StringSlice, message: StringSlice) raises:
    """Check that a body fails to read with a message."""
    var arena = JsonDocument()
    with assert_raises(contains=String(message)):
        _ = _read(arena, text)


# --- subgraph_response.rs -------------------------------------------------


def test_deserialize_response_without_data_with_errors_with_extensions() raises:
    var arena = JsonDocument()
    var response = _read(
        arena,
        """
        {
            "errors": [
                {
                    "message": "Random error from subgraph",
                    "extensions":{
                        "statusCode": 400
                    }
                }
            ]
        }""",
    )

    assert_equal(response.data, NO_NODE)
    assert_true(response.has_errors)
    assert_equal(len(response.errors), 1)
    assert_equal(
        error_json(response.errors[0]),
        '{"message":"Random error from subgraph","extensions":'
        + '{"statusCode":400}}',
    )


def test_deserializes_custom_scalar_data_field_as_raw_json() raises:
    var arena = JsonDocument()
    var response = _read(
        arena,
        '{"data":{"labels":{"generic.learnMore.button\\t":"Learn more"}},'
        + '"extensions":{"statusCode":200}}',
    )

    var labels = arena.first(response.data)
    assert_equal(arena.key(labels), "labels")
    assert_equal(
        _json(arena, labels), '{"generic.learnMore.button\\t":"Learn more"}'
    )
    assert_false(response.has_errors)


def test_deserializes_mixed_sibling_paths_with_only_marked_path_as_raw_json() raises:
    var arena = JsonDocument()
    var response = _read(
        arena,
        """{
            "data": {
                "custom": {
                    "generic.learnMore.button\\t": "Learn more"
                },
                "plain": {
                    "message": "hello",
                    "nested": {
                        "count": 1
                    }
                }
            }
        }""",
    )

    var custom = object_get(arena, response.data, "custom")
    var text = _json(arena, custom)
    assert_true('"generic.learnMore.button\\t"' in text)
    assert_true('"Learn more"' in text)

    var plain = object_get(arena, response.data, "plain")
    assert_true(arena.kind(plain) == JsonKind.OBJECT)
    var message = object_get(arena, plain, "message")
    assert_equal(string_text(arena, message), "hello")
    var nested = object_get(arena, plain, "nested")
    assert_true(arena.kind(nested) == JsonKind.OBJECT)
    var count = arena.first(nested)
    assert_true(arena.kind(count) == JsonKind.NUMBER)
    assert_equal(String(arena.text(count)), "1")


comptime SHARED_PATH_SDL = """
schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
  @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {
  query: Query
}

directive @join__enumValue(graph: join__Graph!) repeatable on ENUM_VALUE
directive @join__field(
  graph: join__Graph
  requires: join__FieldSet
  provides: join__FieldSet
  type: String
  external: Boolean
  override: String
  usedOverridden: Boolean
) repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION
directive @join__graph(name: String!, url: String!) on ENUM_VALUE
directive @join__implements(
  graph: join__Graph!
  interface: String!
) repeatable on OBJECT | INTERFACE
directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR
directive @join__unionMember(
  graph: join__Graph!
  member: String!
) repeatable on UNION
directive @link(
  url: String
  as: String
  for: link__Purpose
  import: [link__Import]
) repeatable on SCHEMA

scalar join__FieldSet
scalar link__Import

enum join__Graph {
  TEST @join__graph(name: "test", url: "http://example.com/graphql")
}

enum link__Purpose {
  SECURITY
  EXECUTION
}

scalar JSONBlob @join__type(graph: TEST)

interface InterfaceThing @join__type(graph: TEST) {
  id: ID! @join__field(graph: TEST)
}

type JsonInterfaceThing implements InterfaceThing
  @join__type(graph: TEST)
  @join__implements(graph: TEST, interface: "InterfaceThing") {
  id: ID! @join__field(graph: TEST)
  meta: JSONBlob @join__field(graph: TEST)
}

type StringInterfaceThing implements InterfaceThing
  @join__type(graph: TEST)
  @join__implements(graph: TEST, interface: "InterfaceThing") {
  id: ID! @join__field(graph: TEST)
  meta: String @join__field(graph: TEST)
}

type JsonUnionThing @join__type(graph: TEST) {
  meta: JSONBlob @join__field(graph: TEST)
}

type StringUnionThing @join__type(graph: TEST) {
  meta: String @join__field(graph: TEST)
}

union UnionThing
  @join__type(graph: TEST)
  @join__unionMember(graph: TEST, member: "JsonUnionThing")
  @join__unionMember(graph: TEST, member: "StringUnionThing") = JsonUnionThing | StringUnionThing

type Query @join__type(graph: TEST) {
  interfaceThing: InterfaceThing @join__field(graph: TEST)
  unionThing: UnionThing @join__field(graph: TEST)
}
"""
"""The supergraph of `custom_and_builtin_scalar_sharing_response_path`."""


def test_custom_and_builtin_scalar_sharing_response_path() raises:
    assert_equal(
        _plan(
            SHARED_PATH_SDL,
            """
            {
              interfaceThing {
                __typename
                ... on JsonInterfaceThing {
                  meta
                }
                ... on StringInterfaceThing {
                  meta
                }
              }
              unionThing {
                __typename
                ... on JsonUnionThing {
                  meta
                }
                ... on StringUnionThing {
                  meta
                }
              }
            }
            """,
        ),
        """QueryPlan {
  Fetch(service: "test") {
    {
      interfaceThing {
        __typename
        ... on JsonInterfaceThing {
          meta
        }
        ... on StringInterfaceThing {
          _internal_qp_alias_0: meta
        }
      }
      unionThing {
        __typename
        ... on JsonUnionThing {
          meta
        }
        ... on StringUnionThing {
          _internal_qp_alias_0: meta
        }
      }
    }
  },
},""",
    )

    var arena = JsonDocument()
    var response = _read(
        arena,
        """{
            "data": {
                "interfaceThing": {
                    "__typename": "StringInterfaceThing",
                    "_internal_qp_alias_0": "interface string"
                },
                "unionThing": {
                    "__typename": "JsonUnionThing",
                    "meta": {
                        "union.key\\t": "union value"
                    }
                }
            }
        }""",
    )
    var interface_thing = object_get(arena, response.data, "interfaceThing")
    assert_true(arena.kind(interface_thing) == JsonKind.OBJECT)
    var interface_meta = object_get(
        arena, interface_thing, "_internal_qp_alias_0"
    )
    assert_equal(string_text(arena, interface_meta), "interface string")
    var union_thing = object_get(arena, response.data, "unionThing")
    assert_true(arena.kind(union_thing) == JsonKind.OBJECT)
    var union_meta = object_get(arena, union_thing, "meta")
    assert_true("union.key\\t" in _json(arena, union_meta))


# --- error cases ----------------------------------------------------------


def test_data_is_appended_to_the_arena() raises:
    var arena = JsonDocument()
    var first = _read(arena, '{"data":{"a":1}}')
    var second = _read(arena, '{"extensions":{},"data":{"b":"\\u0041"},"x":[]}')
    assert_equal(_json(arena, first.data), '{"a":1}')
    assert_equal(_json(arena, second.data), '{"b":"\\u0041"}')
    assert_equal(arena.key(second.data), "data")
    assert_equal(string_text(arena, arena.first(second.data)), "A")
    assert_false(is_plain_string(arena, arena.first(second.data)))
    assert_false(second.has_errors)
    assert_equal(len(second.errors), 0)
    assert_equal(second.status, 0)


def test_data_with_errors() raises:
    var arena = JsonDocument()
    var response = _read(
        arena, '{"data":{"a":null},"errors":[{"message":"m"}]}'
    )
    assert_equal(_json(arena, response.data), '{"a":null}')
    assert_equal(len(response.errors), 1)
    assert_equal(response.errors[0].message, "m")
    assert_false(response.errors[0].has_path)


def test_null_data_with_errors_is_accepted() raises:
    var arena = JsonDocument()
    var response = _read(arena, '{"data":null,"errors":[]}')
    assert_equal(response.data, NO_NODE)
    assert_true(response.has_errors)
    assert_equal(len(response.errors), 0)
    # No data is appended for a null `data`.
    assert_equal(len(arena.nodes), 0)


def test_null_data_without_errors_is_malformed() raises:
    _fails('{"data":null}', "Subgraph returned malformed response")
    _fails("{}", "Subgraph returned malformed response")
    _fails('{"extensions":{"a":1}}', "Subgraph returned malformed response")
    # A `null` `errors` is no errors, as upstream `Option`.
    _fails('{"errors":null}', "Subgraph returned malformed response")


def test_a_body_that_is_not_an_object_fails() raises:
    _fails("[]", "expected a GraphQL response object")
    _fails('"data"', "expected a GraphQL response object")
    _fails("null", "expected a GraphQL response object")
    _fails("", "Failed to deserialize subgraph response: ")
    _fails('{"data":', "Failed to deserialize subgraph response: ")
    _fails('{"data":{}} x', "Failed to deserialize subgraph response: ")


def test_duplicate_members_fail() raises:
    _fails('{"data":{},"data":{}}', "duplicate field `data`")
    _fails('{"errors":[],"errors":[]}', "duplicate field `errors`")
    _fails(
        '{"data":{},"extensions":{},"extensions":{}}',
        "duplicate field `extensions`",
    )


def test_errors_must_be_an_array() raises:
    _fails('{"errors":{}}', "invalid type: `errors` must be an array")
    _fails('{"errors":"x"}', "invalid type: `errors` must be an array")


def test_bad_error_objects_fail() raises:
    _fails('{"errors":[1]}', "invalid type: an error must be an object")
    _fails('{"errors":[{}]}', "missing field `message`")
    _fails('{"errors":[{"message":1}]}', "missing field `message`")
    _fails(
        '{"errors":[{"message":"m","locations":[{"line":1}]}]}',
        "invalid location",
    )
    _fails(
        '{"errors":[{"message":"m","locations":[{"line":1,"column":1.5}]}]}',
        "invalid location",
    )
    _fails(
        '{"errors":[{"message":"m","path":["a",true]}]}',
        "invalid path segment",
    )
    _fails(
        '{"errors":[{"message":"m","path":["a",1.5]}]}',
        "invalid path segment",
    )


def test_an_error_reads_locations_path_and_extensions() raises:
    var arena = JsonDocument()
    var response = _read(
        arena,
        '{"errors":[{"message":"bad \\"x\\"","locations":[{"line":2,'
        + '"column":3},{"column":5,"line":4}],"path":["a",0,"b\\u0021"],'
        + '"extensions":{"code":"C","service":"s","affectedPath":"a.@",'
        + '"retry":true,"detail":{"n":[1]}}}]}',
    )
    assert_equal(len(response.errors), 1)
    ref error = response.errors[0]
    assert_equal(error.message, 'bad "x"')
    assert_equal(len(error.lines), 2)
    assert_equal(error.lines[0], 2)
    assert_equal(error.columns[0], 3)
    assert_equal(error.lines[1], 4)
    assert_equal(error.columns[1], 5)
    assert_true(error.has_path)
    assert_equal(len(error.path.segments), 3)
    assert_true(error.path.segments[0].kind == ErrorSegmentKind.FIELD)
    assert_equal(error.path.segments[0].field, "a")
    assert_true(error.path.segments[1].kind == ErrorSegmentKind.INDEX)
    assert_equal(error.path.segments[1].index, 0)
    assert_equal(error.path.segments[2].field, "b!")
    assert_equal(error.code, "C")
    assert_equal(error.service, "s")
    assert_equal(error.affected_path, "a.@")
    assert_equal(extension_value(error, "retry"), "true")
    assert_equal(extension_value(error, "detail"), '{"n":[1]}')


def test_an_error_reads_null_members_as_missing() raises:
    var arena = JsonDocument()
    var response = _read(
        arena,
        '{"errors":[{"message":"m","locations":null,"path":null,'
        + '"other":1},{"message":"n","locations":[{"line":1,"x":0,'
        + '"column":2}],"extensions":'
        + '{"affectedPath":null,"affectedPath":"a"}}]}',
    )
    assert_equal(len(response.errors), 2)
    ref first = response.errors[0]
    assert_equal(len(first.lines), 0)
    assert_false(first.has_path)
    assert_equal(error_json(first), '{"message":"m"}')
    # A `null` `affectedPath` is no path, so a second one is not a duplicate.
    ref second = response.errors[1]
    assert_equal(second.code, "")
    assert_equal(second.affected_path, "a")
    # Another member of a location is ignored.
    assert_equal(second.columns[0], 2)


def test_an_error_rejects_members_of_other_types() raises:
    _fails(
        '{"errors":[{"message":"m","extensions":null}]}',
        "invalid type: `extensions` must be an object",
    )
    _fails(
        '{"errors":[{"message":"m","locations":{}}]}',
        "invalid type: `locations` must be an array",
    )
    _fails(
        '{"errors":[{"message":"m","path":"a"}]}',
        "invalid type: `path` must be an array",
    )
    _fails('{"errors":[{"message":"m","locations":[1]}]}', "invalid location")
    _fails(
        '{"errors":[{"message":"m","locations":[{"column":1}]}]}',
        "invalid location",
    )
    _fails(
        '{"errors":[{"message":"m","locations":[{"line":-1,"column":1}]}]}',
        "invalid location",
    )
    _fails(
        '{"errors":[{"message":"m","path":["a",-1]}]}', "invalid path segment"
    )
    _fails(
        '{"errors":[{"message":"m","extensions":{"code":1}}]}',
        "invalid type: `code` must be a string",
    )
    _fails(
        '{"errors":[{"message":"m","extensions":{"service":null}}]}',
        "invalid type: `service` must be a string",
    )
    _fails(
        '{"errors":[{"message":"m","extensions":{"affectedPath":3}}]}',
        "invalid type: `affectedPath` must be a string",
    )


def test_an_error_rejects_duplicate_members() raises:
    _fails(
        '{"errors":[{"message":"m","message":"n"}]}',
        "duplicate field `message`",
    )
    _fails(
        '{"errors":[{"message":"m","locations":[],"locations":[]}]}',
        "duplicate field `locations`",
    )
    _fails(
        '{"errors":[{"message":"m","path":[],"path":[]}]}',
        "duplicate field `path`",
    )
    _fails(
        '{"errors":[{"message":"m","extensions":{},"extensions":{}}]}',
        "duplicate field `extensions`",
    )
    _fails(
        '{"errors":[{"message":"m","locations":[{"line":1,"line":1,'
        + '"column":1}]}]}',
        "duplicate field `line`",
    )
    _fails(
        '{"errors":[{"message":"m","locations":[{"line":1,"column":1,'
        + '"column":1}]}]}',
        "duplicate field `column`",
    )
    _fails(
        '{"errors":[{"message":"m","extensions":{"code":"a","code":"b"}}]}',
        "duplicate field `code`",
    )
    _fails(
        '{"errors":[{"message":"m","extensions":{"service":"a",'
        + '"service":"b"}}]}',
        "duplicate field `service`",
    )
    _fails(
        '{"errors":[{"message":"m","extensions":{"affectedPath":"a",'
        + '"affectedPath":"b"}}]}',
        "duplicate field `affectedPath`",
    )


def test_append_error() raises:
    var response = SubgraphResponse()
    assert_false(response.has_errors)
    response.append_error(graphql_error("x"))
    assert_true(response.has_errors)
    assert_equal(len(response.errors), 1)
    assert_equal(response.errors[0].message, "x")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
