# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of streamed `@defer` through the router.

Hive Router `1a29df9` has no `@defer` execution and no test of it. The
payloads follow the incremental delivery RFC and graphql-js
17.0.0-alpha.14 `defer-test.ts`. The subgraphs answer in the same process,
in the order of their requests.
"""

from _abstract_types import sdl as abstract_sdl
from _supergraph import sdl
from gql_http.body import BodyPoll
from gql_json.parser import parse
from gql_json.value import NO_NODE, JsonDocument
from gql_router.exec_http import SubgraphHttpResponse, SubgraphTransport
from gql_router.pipeline import Router, RouterSchema
from gql_router.schema_metadata import PossibleTypes
from std.collections import Set
from gql_router_stream.defer import (
    DeferPlan,
    DeferredResponse,
    has_defer,
    plan_defer,
)
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


struct Queue(SubgraphTransport):
    """Answer each subgraph request with the next body of a list; the last
    body answers every request after it."""

    var bodies: List[String]
    var queries: List[String]
    var at: Int

    def __init__(out self, var bodies: List[String]):
        self.bodies = bodies^
        self.queries = List[String]()
        self.at = 0

    def start(mut self, subgraph: String, query: String, body: List[UInt8]):
        self.queries.append(subgraph + " " + query)

    def finish(mut self) -> SubgraphHttpResponse:
        var index = min(self.at, len(self.bodies) - 1)
        self.at += 1
        return SubgraphHttpResponse(
            200, "application/json", List[UInt8](self.bodies[index].as_bytes())
        )


def _router(var bodies: List[String]) raises -> Router[Queue]:
    return Router(RouterSchema(sdl("http://x")), Queue(bodies^))


def _text(bytes: List[UInt8]) -> String:
    return String(unsafe_from_utf8=Span(bytes))


def _plan(query: String) raises -> DeferPlan:
    return plan_defer(query, None, JsonDocument(), NO_NODE)


def _plan_with(query: String, variables: String) raises -> DeferPlan:
    var document = parse(variables)
    var root = document.root
    return plan_defer(query, None, document, root)


def test_has_defer() raises:
    assert_true(has_defer("{ a ... @defer { b } }"))
    assert_false(has_defer("{ a }"))


def test_plan_without_defer() raises:
    var plan = _plan("{ a { b } }")
    assert_equal(len(plan.sites), 0)
    assert_equal(plan.primary, "{ a { b } }")
    assert_equal(plan.full, "{ a { b } }")
    # Without an operation, nothing is deferred; the directive goes.
    var fragment = _plan("fragment F on T { ... @defer { a } }")
    assert_equal(len(fragment.sites), 0)
    assert_equal(fragment.full, "fragment F on T { ...  { a } }")
    var missing = plan_defer(
        "query A { a ... @defer { b } }", String("B"), JsonDocument(), NO_NODE
    )
    assert_equal(len(missing.sites), 0)


def test_plan_inline_fragment() raises:
    var plan = _plan('{ x: a { b ... @defer(label: "l") { n: c d } } }')
    assert_equal(plan.primary, "{ x: a { b __typename } }")
    assert_equal(plan.full, "{ x: a { b ...  { n: c d } } }")
    assert_equal(len(plan.sites), 1)
    assert_equal(len(plan.sites[0].path), 1)
    assert_equal(plan.sites[0].path[0], "x")
    assert_true(plan.sites[0].has_label)
    assert_equal(plan.sites[0].label, "l")
    assert_equal(len(plan.sites[0].keys), 2)
    assert_equal(plan.sites[0].keys[0], "n")
    assert_equal(plan.sites[0].condition, "")
    assert_false(plan.sites[0].keep_typename)


def test_plan_named_operation() raises:
    var plan = plan_defer(
        (
            "fragment F on T { a } query A { a } query B { b ... on Q @defer {"
            " c } }"
        ),
        String("B"),
        JsonDocument(),
        NO_NODE,
    )
    assert_equal(len(plan.sites), 1)
    assert_equal(plan.sites[0].condition, "Q")
    assert_equal(len(plan.sites[0].path), 0)


def test_plan_if_argument() raises:
    assert_equal(len(_plan("{ ... @defer(if: false) { a } }").sites), 0)
    assert_equal(len(_plan("{ ... @defer(if: true) { a } }").sites), 1)
    assert_equal(len(_plan("{ ... @defer(if: 1) { a } }").sites), 1)
    var query = "query($v: Boolean) { ... @defer(if: $v) { a } }"
    assert_equal(len(_plan(query).sites), 1)
    assert_equal(len(_plan_with(query, '{"v": false}').sites), 0)
    assert_equal(len(_plan_with(query, '{"v": true}').sites), 1)
    assert_equal(len(_plan_with(query, '{"v": "x"}').sites), 1)
    assert_equal(len(_plan_with(query, "{}").sites), 1)
    # A label that is not a string is no label.
    var plan = _plan("query($l: String) { ... @defer(label: $l) { a } }")
    assert_false(plan.sites[0].has_label)


def test_plan_fragment_spreads() raises:
    var plan = _plan(
        "{ a { __typename ...F @defer ...Missing ...G } }"
        " fragment F on T { b b ... { c } ...H ...Missing }"
        " fragment H on T { d } fragment G on T { e }"
    )
    assert_equal(len(plan.sites), 1)
    ref site = plan.sites[0]
    assert_equal(site.condition, "T")
    assert_true(site.keep_typename)
    assert_equal(len(site.keys), 3)
    assert_equal(site.keys[0], "b")
    assert_equal(site.keys[1], "c")
    assert_equal(site.keys[2], "d")
    assert_true(plan.primary.startswith("{ a { __typename __typename "))


def test_plan_shared_fragment_and_order() raises:
    # One fragment under two fields: two sites, one replacement.
    var shared = _plan(
        "{ a { ...G } b { ...G } } fragment G on T { ... @defer { c } }"
    )
    assert_equal(len(shared.sites), 2)
    assert_equal(
        shared.primary,
        "{ a { ...G } b { ...G } } fragment G on T { __typename }",
    )
    # The edits come out of document order, and are sorted.
    var order = _plan(
        "{ a { ...G } ... @defer { y } z ... @defer { w } }"
        " fragment G on T { ... @defer { c } }"
    )
    assert_equal(len(order.sites), 3)
    assert_equal(
        order.primary,
        "{ a { ...G } __typename z __typename } fragment G on T { __typename }",
    )


def test_plan_recursive_fragments_stop() raises:
    var plan = _plan(
        "{ a { ...R ...S @defer } } fragment R on T { ...R }"
        " fragment S on T { ...S }"
    )
    assert_equal(len(plan.sites), 1)
    assert_equal(len(plan.sites[0].keys), 0)


def test_plan_parse_error() raises:
    with assert_raises():
        _ = _plan("{ a ... @defer {")


def _response(
    query: String, first: String, full: String
) raises -> DeferredResponse:
    """Make a response as a mutation does: the full document ran first."""
    var response = DeferredResponse()
    response.sites = _plan(query).sites.copy()
    response.first = List[UInt8](first.as_bytes())
    response.full_body = List[UInt8](full.as_bytes())
    response.done = False
    return response^


def _next(mut response: DeferredResponse) raises -> String:
    var router = _router(List[String]())
    var out = List[UInt8]()
    var poll = response.next(router, out)
    if poll == BodyPoll.DONE:
        return "DONE"
    return _text(out)


def test_payloads_with_errors() raises:
    var response = _response(
        "{ a { b ... @defer { c d } } }",
        '{"data":{"a":{"b":1,"__typename":"T"}}}',
        '{"data":{"a":{"b":1,"c":2,"d":3}},"errors":['
        + '{"message":"x","path":["a","c"]},'
        + '{"message":"x2","path":["a","d",0]},'
        + '{"message":"y","path":["a","b"]},'
        + '{"message":"z"},{"message":"w","path":"a"},'
        + '{"message":"v","path":["a"]},'
        + '{"message":"u","path":["q","c"]}]}',
    )
    response.write_initial(PossibleTypes())
    assert_equal(
        _text(response.initial),
        '{"data":{"a":{"b":1}},"pending":[{"id":"0","path":["a"]}],'
        + '"hasNext":true}',
    )
    assert_equal(
        _next(response),
        '{"hasNext":false,"incremental":[{"id":"0","data":{"c":2,"d":3},'
        + '"errors":[{"message":"x","path":["a","c"]},'
        + '{"message":"x2","path":["a","d",0]}]}],"completed":[{"id":"0"}]}',
    )
    assert_equal(_next(response), "DONE")


def test_payloads_through_lists_and_conditions() raises:
    var possible = PossibleTypes()
    var set = Set[String]()
    set.add("C")
    possible.map["I"] = set^
    var response = _response(
        "{ list { ... on A @defer { x } } other { ... on I @defer { y } } }",
        '{"data":{"list":[{"__typename":"A"},{"__typename":"B"},'
        + '[{"__typename":"A"}],5,{"x":0},{"__typename":3}],'
        + '"other":{"__typename":"C"}}}',
        '{"data":{"list":[{"x":1},{"x":2},[{"x":3}],5,{"z":4},7],'
        + '"other":{"y":9}},"errors":[]}',
    )
    response.write_initial(possible)
    assert_equal(
        _text(response.initial),
        '{"data":{"list":[{},{"__typename":"B"},[{}],5,{},{}],'
        + '"other":{}},"pending":['
        + '{"id":"0","path":["list",0]},'
        + '{"id":"1","path":["list",2,0]},'
        + '{"id":"2","path":["list",4]},'
        + '{"id":"3","path":["list",5]},'
        + '{"id":"4","path":["other"]}],"hasNext":true}',
    )
    assert_equal(
        _next(response),
        '{"hasNext":false,"incremental":['
        + '{"id":"0","data":{"x":1}},'
        + '{"id":"1","data":{"x":3}},'
        + '{"id":"4","data":{"y":9}}],"completed":['
        + '{"id":"0"},{"id":"1"},{"id":"2"},{"id":"3"},{"id":"4"}]}',
    )


def test_payloads_when_the_objects_are_gone() raises:
    var response = _response(
        "{ list { ... @defer { x } } gone { ... @defer { y } } }",
        '{"data":{"list":[[{"a":1}],[]]}}',
        '{"data":{}}',
    )
    response.write_initial(PossibleTypes())
    assert_equal(
        _text(response.initial),
        '{"data":{"list":[[{"a":1}],[]]},"pending":['
        + '{"id":"0","path":["list",0,0]}],"hasNext":true}',
    )
    assert_equal(
        _next(response),
        '{"hasNext":false,"completed":[{"id":"0"}]}',
    )


def test_payloads_at_the_root_and_empty_values() raises:
    var plan = _plan("{ ... @skip(if: false) @defer { a b } }")
    assert_equal(len(plan.sites), 1)
    var response = _response(
        "{ __typename ... @defer { a b } }",
        '{"data":{"__typename":"Query","e":[],"o":{}},"errors":[]}',
        '{"data":{"a":1},"errors":[{"message":"m","path":["a"]},'
        + '{"message":"n","path":["c"]}]}',
    )
    response.write_initial(PossibleTypes())
    assert_equal(
        _text(response.initial),
        '{"data":{"__typename":"Query","e":[],"o":{}},"errors":[],'
        + '"pending":[{"id":"0","path":[]}],"hasNext":true}',
    )
    assert_equal(
        _next(response),
        '{"hasNext":false,"incremental":[{"id":"0","data":{"a":1},'
        + '"errors":[{"message":"m","path":["a"]}]}],'
        + '"completed":[{"id":"0"}]}',
    )
    var empty = _response(
        "{ o { ... @defer { a } } p { ...S @defer } } fragment S on T { ...S }",
        '{"data":{"o":{"x":1},"p":{"y":2}}}',
        '{"data":{"o":{},"p":{"y":2}},"errors":[]}',
    )
    empty.write_initial(PossibleTypes())
    assert_equal(
        _next(empty),
        '{"hasNext":false,"completed":[{"id":"0"},{"id":"1"}]}',
    )


def test_payloads_without_data() raises:
    var response = _response(
        "{ a { ... @defer { x } } }", '{"errors":[{"message":"e"}]}', "{}"
    )
    response.write_initial(PossibleTypes())
    assert_equal(
        _text(response.initial),
        '{"errors":[{"message":"e"}],"pending":[],"hasNext":false}',
    )
    assert_true(response.done)
    assert_equal(_next(response), "DONE")
    var empty = _response("{ a { ... @defer { x } } }", "{}", "{}")
    empty.write_initial(PossibleTypes())
    assert_equal(_text(empty.initial), '{"pending":[],"hasNext":false}')
    var broken = _response("{ a { ... @defer { x } } }", "{", "{}")
    with assert_raises():
        broken.write_initial(PossibleTypes())


def test_query_through_the_router() raises:
    var bodies = List[String]()
    bodies.append(
        '{"data":{"topProducts":[{"upc":"1","__typename":"Product"},'
        + '{"upc":"2","__typename":"Product"}]}}'
    )
    bodies.append(
        '{"data":{"topProducts":[{"upc":"1","name":"A"},'
        + '{"upc":"2","name":"B"}]}}'
    )
    var router = _router(bodies^)
    var response = DeferredResponse.start(
        router,
        '{ topProducts { upc ... @defer(label: "l") { upc name } } }',
        None,
        JsonDocument(),
        NO_NODE,
        False,
    )
    response.write_initial(router.schema.metadata.possible_types)
    assert_equal(
        _text(response.initial),
        '{"data":{"topProducts":[{"upc":"1"},{"upc":"2"}]},"pending":['
        + '{"id":"0","path":["topProducts",0],"label":"l"},'
        + '{"id":"1","path":["topProducts",1],"label":"l"}],'
        + '"hasNext":true}',
    )
    var out = List[UInt8]()
    assert_true(response.next(router, out) == BodyPoll.READY)
    assert_equal(
        _text(out),
        '{"hasNext":false,"incremental":['
        + '{"id":"0","data":{"name":"A"}},{"id":"1","data":{"name":"B"}}],'
        + '"completed":[{"id":"0"},{"id":"1"}]}',
    )


def test_one_response_and_inactive_defer() raises:
    var bodies = List[String]()
    bodies.append('{"data":{"topProducts":[{"upc":"1","name":"A"}]}}')
    var router = _router(bodies^)
    var single = DeferredResponse.start(
        router,
        "{ topProducts { upc ... @defer { name } } }",
        None,
        JsonDocument(),
        NO_NODE,
        False,
        stream=False,
    )
    assert_equal(
        _text(single.initial),
        '{"data":{"topProducts":[{"upc":"1","name":"A"}]}}',
    )
    var inactive = DeferredResponse.start(
        router,
        "{ topProducts { upc ... @defer(if: false) { name } } }",
        None,
        JsonDocument(),
        NO_NODE,
        True,
    )
    assert_true(inactive.done)
    inactive.write_initial(router.schema.metadata.possible_types)
    assert_equal(
        _text(inactive.initial),
        '{"data":{"topProducts":[{"upc":"1","name":"A"}]}}',
    )


def test_mutation_runs_once() raises:
    var bodies = List[String]()
    bodies.append('{"data":{"upload":"a","u":"b"}}')
    var router = _router(bodies^)
    var response = DeferredResponse.start(
        router,
        "mutation { upload ... @defer { u: upload } }",
        None,
        JsonDocument(),
        NO_NODE,
        False,
    )
    response.write_initial(router.schema.metadata.possible_types)
    assert_equal(
        _text(response.initial),
        '{"data":{"upload":"a"},"pending":[{"id":"0","path":[]}],'
        + '"hasNext":true}',
    )
    var out = List[UInt8]()
    _ = response.next(router, out)
    assert_equal(
        _text(out),
        '{"hasNext":false,"incremental":[{"id":"0","data":{"u":"b"}}],'
        + '"completed":[{"id":"0"}]}',
    )
    assert_equal(len(router.executor.transport.queries), 1)


def test_a_parse_error_is_a_client_error() raises:
    var router = _router(List[String]())
    var body = String()
    try:
        _ = DeferredResponse.start(
            router, "{ a @defer {", None, JsonDocument(), NO_NODE, False
        )
    except error:
        body = error.body()
    assert_true("GRAPHQL_PARSE_FAILED" in body)


def test_a_failed_full_document_completes_with_errors() raises:
    var bodies = List[String]()
    bodies.append('{"data":{"review":{"product":{"__typename":"Book"}}}}')
    bodies.append(
        '{"data":{"review":{"__typename":"Ghost","product":{"id":"1"}}}}'
    )
    var router = Router(RouterSchema(abstract_sdl()), Queue(bodies^))
    var response = DeferredResponse.start(
        router,
        "{ review(id: 1) { product { ... on Book @defer { sku } } } }",
        None,
        JsonDocument(),
        NO_NODE,
        False,
    )
    response.write_initial(router.schema.metadata.possible_types)
    assert_equal(
        _text(response.initial),
        '{"data":{"review":{"product":{}}},"pending":['
        + '{"id":"0","path":["review","product"]}],"hasNext":true}',
    )
    var out = List[UInt8]()
    _ = response.next(router, out)
    assert_equal(
        _text(out),
        '{"hasNext":false,"completed":[{"id":"0","errors":[{"message":'
        + '"Internal server error","extensions":{"code":'
        + '"PLAN_EXECUTION_FAILED"}}]}]}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
