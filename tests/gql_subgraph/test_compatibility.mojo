# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The Apollo Federation subgraph compatibility suite, against the
`products` subgraph of `_products.mojo`.

Ported from apollo-federation-subgraph-compatibility f9520a4 (MIT)
`packages/compatibility/src/tests/`: `introspection.test.ts`,
`key.test.ts`, `requires.test.ts`, `provides.test.ts`, `link.test.ts`,
`shareable.test.ts`, `tag.test.ts`, `override.test.ts`,
`inaccessible.test.ts`, `composeDirective.test.ts`,
`interfaceObject.test.ts` and `ftv1.test.ts`. The query documents and the
expected data are those of the jest tests. Each jest regular expression is
an ordered search of `_compat.matches`.

The jest tests send their requests over HTTP; these execute them with
`SubgraphSchema.execute`. Upstream checks a subset with `toMatchObject`;
these check the whole result, which has no other fields.

Four jest tests query a router: `@requires`, `@shareable`, `@override`
and `@interfaceObject`. Here each sends the request that the router sends
to `products`.

`ftv1.test.ts` needs a server: the `ftv1` tests serve `products` with
`gql_server.ApolloServer`, a `test_depends` of `gql_subgraph`, and send
the HTTP request of the jest test with the header
`apollo-federation-include-trace: ftv1`. Upstream checks that
`extensions.ftv1` is a string; these also decode the trace and check its
tree.
"""

from std.testing import TestSuite, assert_equal, assert_false, assert_true
from _compat import between, compare_schemas, links, matches
from _helpers import assert_service_sdl, run
from _products import build_products
from gql_json.parser import parse as parse_json
from gql_json.value import JsonKind
from gql_language.error import quote_json_string
from gql_language.strip_ignored_characters import strip_ignored_characters
from gql_server.base64 import base64_decode
from gql_server.http_types import HTTPGraphQLRequest
from gql_server.plugin import ServerPlugin
from gql_server.server import ApolloServer, ApolloServerOptions
from gql_server.server import default_context
from gql_server.types import GraphQLRequestContext
from gql_server.usage_reporting_protobuf import Trace
from gql_subgraph.build_subgraph_schema import SubgraphSchema

comptime ENTITIES = (
    "query ($representations: [_Any!]!) { _entities(representations:"
    " $representations) { "
)
"""The start of the `_entities` query of the jest tests."""


def _normalized_sdl() raises -> String:
    """Return `_service.sdl` with the ignored characters stripped, as
    `stripIgnoredCharacters(sdl)` of the jest tests."""
    var subgraph = build_products()
    assert_service_sdl(subgraph, subgraph.sdl)
    var normalized = strip_ignored_characters(subgraph.sdl)
    assert_equal(normalized.find("\n"), -1)
    return normalized^


def _query(query: String, variables: String = "") raises -> String:
    """Execute an operation against `products`."""
    return run(build_products(), query, variables)


# introspection.test.ts


def test_introspection() raises:
    var subgraph = build_products()
    var result = run(subgraph, "query { _service { sdl } }")
    assert_true(result.startswith('{"data":{"_service":{"sdl":"'))
    assert_true("type Query" in subgraph.sdl)
    assert_equal(compare_schemas(subgraph.sdl), "")


def test_compare_schemas_reports_differences() raises:
    var errors = compare_schemas(
        "type Product { id: ID sku: [String] } type CaseStudy {"
        " caseNumber: [ID!]! description: String! } type ProductVariation"
        " { id: [ID] } type User { name: String } extend type Query {"
        " product: [Product] }"
    )
    assert_true(
        "\n * target schema does not define DeprecatedProduct type" in errors
    )
    assert_true(
        "\n * Product defines different nullability for id field, expected"
        " non-nullable but was nullable"
        in errors
    )
    assert_true(
        "\n * Product defines different return type for sku field, did not"
        " expect a list return type"
        in errors
    )
    assert_true(
        "\n * CaseStudy defines different return type for caseNumber field,"
        " did not expect a list return type"
        in errors
    )
    assert_true(
        "\n * CaseStudy defines different nullability for description"
        " field, expected nullable but was non-nullable"
        in errors
    )
    assert_true(
        "\n * ProductVariation defines different nullability for id field,"
        " expected non-nullable but was nullable"
        in errors
    )
    assert_true("\n * Product type does not declare variation field" in errors)
    assert_true("\n * User type does not declare email field" in errors)
    assert_true("\n * product type does not declare id argument" in errors)
    assert_true(
        "\n * Query defines different return type for product field, did"
        " not expect a list return type"
        in errors
    )
    assert_true(
        "\n * Query type does not declare deprecatedProduct field" in errors
    )
    assert_true(
        "\n * Product defines different return type for research field, was"
        " expecting a list return type"
        in errors
        or "\n * Product type does not declare research field" in errors
    )
    assert_true(
        "expected ProductVariation but was Int"
        in compare_schemas(
            "type Product { variation: Int } extend type User { email: ID! }"
        )
    )
    assert_true(
        "was expecting a list return type"
        in compare_schemas("type Product { research: ProductResearch! }")
    )
    assert_true(
        "\n * Query type does not declare product field"
        in compare_schemas("type Product { id: ID! }")
    )


# key.test.ts


def test_key_single_applies_on_user() raises:
    assert_true(
        matches(
            _normalized_sdl(),
            [
                'type User<@extends|@federation__extends|><@key|@federation__key>(fields:"email"<'
                " resolvable:true|>)"
            ],
        )
    )


def test_key_single_resolves_user() raises:
    assert_equal(
        _query(
            ENTITIES + "...on User { email name } } }",
            (
                '{"representations": [{"__typename": "User", "email":'
                ' "support@apollographql.com"}]}'
            ),
        ),
        (
            '{"data":{"_entities":[{"email":"support@apollographql.com",'
            '"name":"Jane Smith"}]}}'
        ),
    )


def test_key_multiple_applies_on_deprecated_product() raises:
    assert_true(
        matches(
            _normalized_sdl(),
            [
                'type DeprecatedProduct<@key|@federation__key>(fields:"sku'
                ' package"'
            ],
        )
    )


def test_key_multiple_resolves_deprecated_product() raises:
    assert_equal(
        _query(
            ENTITIES + "...on DeprecatedProduct { sku package reason } } }",
            (
                '{"representations": [{"__typename": "DeprecatedProduct",'
                ' "sku": "apollo-federation-v1", "package":'
                ' "@apollo/federation-v1"}]}'
            ),
        ),
        (
            '{"data":{"_entities":[{"sku":"apollo-federation-v1",'
            '"package":"@apollo/federation-v1",'
            '"reason":"Migrate to Federation V2"}]}}'
        ),
    )


def test_key_composite_applies_on_product_research() raises:
    assert_true(
        matches(
            _normalized_sdl(),
            [
                'type ProductResearch<@key|@federation__key>(fields:"study {'
                ' caseNumber }"'
            ],
        )
    )


def test_key_composite_resolves_product_research() raises:
    assert_equal(
        _query(
            ENTITIES
            + "...on ProductResearch { study { caseNumber description } } } }",
            (
                '{"representations": [{"__typename": "ProductResearch",'
                ' "study": {"caseNumber": "1234"}}]}'
            ),
        ),
        (
            '{"data":{"_entities":[{"study":{"caseNumber":"1234",'
            '"description":"Federation Study"}}]}}'
        ),
    )


def test_repeatable_key_applies_on_product() raises:
    var sdl = _normalized_sdl()
    assert_true(
        matches(
            sdl,
            [
                "type Product",
                '<@key|@federation__key>(fields:"id"< resolvable:true|>)',
                "{",
            ],
        )
    )
    assert_true(
        matches(
            sdl,
            [
                "type Product",
                (
                    '<@key|@federation__key>(fields:"sku package"<'
                    " resolvable:true|>)"
                ),
                "variation",
            ],
        )
    )
    assert_true(
        matches(
            sdl,
            [
                "type Product",
                (
                    '<@key|@federation__key>(fields:"sku variation { id }"<'
                    " resolvable:true|>)"
                ),
                "{",
            ],
        )
    )


def test_repeatable_key_resolves_product() raises:
    assert_equal(
        _query(
            ENTITIES + "...on Product { id sku } } }",
            (
                '{"representations": [{"__typename": "Product", "id":'
                ' "apollo-federation"}, {"__typename": "Product", "sku":'
                ' "federation", "package": "@apollo/federation"},'
                ' {"__typename": "Product", "sku": "studio", "variation":'
                ' {"id": "platform"}}]}'
            ),
        ),
        (
            '{"data":{"_entities":[{"id":"apollo-federation",'
            '"sku":"federation"},{"id":"apollo-federation",'
            '"sku":"federation"},{"id":"apollo-studio","sku":"studio"}]}}'
        ),
    )


# requires.test.ts


def test_requires_in_service_sdl() raises:
    assert_true(
        matches(
            _normalized_sdl(),
            [
                "averageProductsCreatedPerYear:Int<@requires|"
                '@federation__requires>(fields:"totalProductsCreated'
                ' yearsOfEmployment")'
            ],
        )
    )


def test_requires_computes_from_field_set() raises:
    # The router query `product(id) { createdBy {
    # averageProductsCreatedPerYear email } }` ends with this fetch: the
    # router gets `yearsOfEmployment` from `users` and sends it back.
    assert_equal(
        _query(
            ENTITIES + "...on User { averageProductsCreatedPerYear email } } }",
            (
                '{"representations": [{"__typename": "User", "email":'
                ' "support@apollographql.com", "totalProductsCreated": 1337,'
                ' "yearsOfEmployment": 10}]}'
            ),
        ),
        (
            '{"data":{"_entities":[{"averageProductsCreatedPerYear":134,'
            '"email":"support@apollographql.com"}]}}'
        ),
    )


def test_requires_checks_the_email() raises:
    var result = _query(
        ENTITIES + "...on User { averageProductsCreatedPerYear } } }",
        (
            '{"representations": [{"__typename": "User", "email":'
            ' "other@example.com", "yearsOfEmployment": 10}]}'
        ),
    )
    assert_true("user.email was not 'support@apollographql.com'" in result)


# provides.test.ts


def test_provides_in_service_sdl() raises:
    assert_true(
        matches(
            _normalized_sdl(),
            [
                "createdBy:User<@provides|@federation__provides>"
                '(fields:"totalProductsCreated")'
            ],
        )
    )


def test_provides_returns_locally_computed_field() raises:
    var result = _query(
        (
            "query ($id: ID!) { product(id: $id) { createdBy { email"
            " totalProductsCreated } } }"
        ),
        '{"id": "apollo-federation"}',
    )
    assert_equal(
        result,
        (
            '{"data":{"product":{"createdBy":{"email":'
            '"support@apollographql.com","totalProductsCreated":1337}}}}'
        ),
    )
    assert_false('"totalProductsCreated":4}' in result)


# link.test.ts


def test_link() raises:
    var sdl = _normalized_sdl()
    assert_true("@link" in sdl)
    var expected: List[String] = [
        "@authenticated",
        "@composeDirective",
        "@extends",
        "@external",
        "@inaccessible",
        "@interfaceObject",
        "@key",
        "@override",
        "@policy",
        "@provides",
        "@requires",
        "@requiresScopes",
        "@shareable",
        "@tag",
        "FieldSet",
        "Scope",
        "Policy",
    ]
    var found = links(sdl)
    assert_true(len(found) > 0)
    var prefix = String("https://specs.apollo.dev/federation/v")
    var federation_links = 0
    for ref element in found:
        var url = between(element, 'url:"', '"')
        if not url.startswith(prefix):
            continue
        federation_links += 1
        var version = String(url[byte = prefix.byte_length() :])
        var supported = False
        for minor in range(8):
            if "2." + String(minor) in version:
                supported = True
        assert_true(supported, version)
        var imports = between(element, "import:[", "]")
        for item in imports.split(" "):
            var name = String(item).replace('"', "")
            assert_true(name in expected, name)
    assert_equal(federation_links, 1)


# shareable.test.ts


def test_shareable_in_service_sdl() raises:
    assert_true(
        matches(
            _normalized_sdl(),
            ["type ProductDimension<@shareable|@federation__shareable>"],
        )
    )


def test_shareable_resolves_product_dimension() raises:
    assert_equal(
        _query(
            (
                "query GetProduct($id: ID!) { product(id: $id) { dimensions {"
                " size weight } } }"
            ),
            '{"id": "apollo-federation"}',
        ),
        '{"data":{"product":{"dimensions":{"size":"small","weight":1}}}}',
    )


# tag.test.ts


def test_tag() raises:
    var sdl = _normalized_sdl()
    assert_false("@federation__tag" in sdl)
    assert_true('@tag(name:"internal")' in sdl)


# override.test.ts


def test_override_in_service_sdl() raises:
    assert_true(
        matches(
            _normalized_sdl(),
            ['<@override|@federation__override>(from:"users")'],
        )
    )


def test_override_returns_overridden_user_name() raises:
    assert_equal(
        _query(
            (
                "query GetProduct($id: ID!) { product(id: $id) { createdBy {"
                " name } } }"
            ),
            '{"id": "apollo-federation"}',
        ),
        '{"data":{"product":{"createdBy":{"name":"Jane Smith"}}}}',
    )


# inaccessible.test.ts


def test_inaccessible_in_service_sdl() raises:
    var sdl = _normalized_sdl()
    assert_false("@federation__inaccessible" in sdl)
    assert_true("unit:String@inaccessible" in sdl)


def test_inaccessible_field_queried_directly() raises:
    assert_equal(
        _query(
            (
                "query GetProduct($id: ID!) { product(id: $id) { dimensions {"
                " unit } } }"
            ),
            '{"id": "apollo-federation"}',
        ),
        '{"data":{"product":{"dimensions":{"unit":"kg"}}}}',
    )


# composeDirective.test.ts


def test_compose_directive() raises:
    var sdl = _normalized_sdl()
    var found = links(sdl)
    assert_true(len(found) > 0)
    var custom_links = 0
    for ref element in found:
        var url = between(element, 'url:"', '"')
        if not url.startswith("https://myspecs.dev/myCustomDirective/v"):
            continue
        custom_links += 1
        var imports = between(element, "import:[", "]")
        for item in imports.split(" "):
            assert_equal(String(item).replace('"', ""), "@custom")
    assert_equal(custom_links, 1)
    assert_true(
        matches(
            sdl,
            [
                "schema",
                "<@composeDirective|@federation__composeDirective>(name:",
                '"@custom")',
            ],
        )
    )
    assert_true(matches(sdl, ["directive", "@custom on OBJECT"]))
    assert_true(matches(sdl, ["type Product", "@custom", "{"]))


# interfaceObject.test.ts


def test_interface_object_in_service_sdl() raises:
    var sdl = _normalized_sdl()
    assert_true(
        matches(
            sdl,
            [
                "type Inventory",
                "<@interfaceObject|@federation__interfaceObject>",
            ],
        )
    )
    assert_true(
        matches(
            sdl,
            [
                "type Inventory",
                '<@key|@federation__key>(fields:"id"< resolvable:true|>)',
            ],
        )
    )


def test_interface_object_returns_new_fields() raises:
    # The router query `inventory(id: "apollo-oss") { deprecatedProducts {
    # sku reason } }` gets the inventory from `inventory`, then sends this
    # fetch to `products`.
    assert_equal(
        _query(
            ENTITIES
            + "...on Inventory { deprecatedProducts { sku reason } } } }",
            (
                '{"representations": [{"__typename": "Inventory", "id":'
                ' "apollo-oss"}]}'
            ),
        ),
        (
            '{"data":{"_entities":[{"deprecatedProducts":[{"sku":'
            '"apollo-federation-v1","reason":"Migrate to Federation V2"}]}]}}'
        ),
    )


# The other data and resolvers of the apollo-server implementation.


def test_queries_of_the_products_schema() raises:
    assert_equal(
        _query(
            '{ a: product(id: "apollo-studio") { id sku package variation {'
            " id } research { study { caseNumber } outcome } notes } b:"
            ' product(id: "none") { id } }'
        ),
        (
            '{"data":{"a":{"id":"apollo-studio","sku":"studio","package":"",'
            '"variation":{"id":"platform"},"research":[{"study":'
            '{"caseNumber":"1235"},"outcome":null}],"notes":null},'
            '"b":null}}'
        ),
    )
    assert_equal(
        _query(
            '{ a: deprecatedProduct(sku: "apollo-federation-v1", package:'
            ' "@apollo/federation-v1") { reason createdBy { email } } b:'
            ' deprecatedProduct(sku: "x", package: "y") { reason } }'
        ),
        (
            '{"data":{"a":{"reason":"Migrate to Federation V2","createdBy":'
            '{"email":"support@apollographql.com"}},"b":null}}'
        ),
    )


def test_references_that_match_nothing() raises:
    assert_equal(
        _query(
            ENTITIES
            + "...on Product { id variation { id } research { outcome } }"
            " ...on DeprecatedProduct { sku } ...on ProductResearch {"
            " outcome } ...on User { email } ...on Inventory { id } } }",
            (
                '{"representations": [{"__typename": "Product", "id":'
                ' "none"}, {"__typename": "Product", "sku": "studio",'
                ' "package": "", "variation": {"id": "platform"}},'
                ' {"__typename": "DeprecatedProduct", "sku": "x", "package":'
                ' "y"}, {"__typename": "ProductResearch", "study":'
                ' {"caseNumber": "1235"}}, {"__typename": "ProductResearch",'
                ' "study": {"caseNumber": "9"}}, {"__typename": "User",'
                ' "email": ""}, {"__typename": "Inventory", "id": "x"}]}'
            ),
        ),
        (
            '{"data":{"_entities":[null,{"id":"apollo-studio","variation":'
            '{"id":"platform"},"research":[{"outcome":null}]},null,'
            '{"outcome":null},null,null,null]}}'
        ),
    )


def test_average_without_years_is_not_an_int() raises:
    # Upstream divides by `undefined`: `Math.round(NaN)` is not an Int.
    var result = _query(
        (
            "query ($id: ID!) { product(id: $id) { createdBy {"
            " averageProductsCreatedPerYear } } }"
        ),
        '{"id": "apollo-federation"}',
    )
    assert_true("Int cannot represent non-integer value: NaN" in result)


# ftv1.test.ts


struct ServeSubgraph(ServerPlugin):
    """Run each operation of `gql_server` with the subgraph handle, as
    `SubgraphSchema.attach` says."""

    var subgraph: SubgraphSchema

    def __init__(out self, var subgraph: SubgraphSchema):
        self.subgraph = subgraph^

    def execution_did_start(mut self, mut ctx: GraphQLRequestContext) raises:
        self.subgraph.attach(ctx.values)


def _products_server() raises -> ApolloServer[ServeSubgraph]:
    """Serve `products` with Apollo Server and its default plugins, as
    the `products` implementation of the suite does."""
    var subgraph = build_products()
    var schema = subgraph.schema.copy()
    var resolvers = subgraph.resolvers.resolvers.copy()
    var options = ApolloServerOptions()
    options.node_env = String("test")
    var server = ApolloServer(
        schema^, resolvers^, options^, ServeSubgraph(subgraph^)
    )
    server.start()
    return server^


def _products_request(
    mut server: ApolloServer[ServeSubgraph], query: String
) raises -> String:
    """`productsRequest` with the header `apollo-federation-include-trace:
    ftv1`; return the content of the response."""
    var request = HTTPGraphQLRequest("POST")
    request.headers.set("content-type", "application/json")
    request.headers.set("apollo-federation-include-trace", "ftv1")
    request.body = parse_json('{"query":' + quote_json_string(query) + "}")
    var response = server.execute_http_graphql_request(
        request^, default_context
    )
    return response.body.copy()


def _ftv1(body: String) raises -> Trace:
    """Decode `extensions.ftv1`, which must be a string."""
    var json = parse_json(body)
    var extensions = json.find(json.root, "extensions")
    assert_equal(json.length(extensions), 1)
    var ftv1 = json.find(extensions, "ftv1")
    assert_true(json.kind(ftv1) == JsonKind.STRING)
    return Trace.decode(base64_decode(json.string_value(ftv1)))


def test_ftv1() raises:
    var server = _products_server()
    var body = _products_request(server, "query { __typename }")
    assert_true(
        body.startswith('{"data":{"__typename":"Query"},"extensions":{"ftv1":"')
    )
    var trace = _ftv1(body)
    # `__typename` is a meta field, which Apollo Server does not trace.
    assert_equal(len(trace.nodes), 1)
    assert_equal(len(trace.nodes[0].error), 0)
    assert_true(trace.duration_ns > 0)
    assert_true(trace.start_time.seconds > 0)
    assert_true(trace.end_time.seconds >= trace.start_time.seconds)


def test_ftv1_tree_of_the_products_schema() raises:
    var server = _products_server()
    var body = _products_request(
        server, '{ product(id: "apollo-federation") { id sku } }'
    )
    assert_true(
        body.startswith(
            '{"data":{"product":{"id":"apollo-federation","sku":"federation"'
        )
    )
    var trace = _ftv1(body)
    ref root = trace.nodes[0]
    assert_equal(len(root.child), 1)
    ref product = trace.nodes[root.child[0]]
    assert_equal(product.response_name.value(), "product")
    assert_equal(product.type, "Product")
    assert_equal(product.parent_type, "Query")
    assert_true(product.end_time >= product.start_time)
    assert_equal(len(product.child), 2)
    ref id = trace.nodes[product.child[0]]
    assert_equal(id.response_name.value(), "id")
    assert_equal(id.type, "ID!")
    assert_equal(id.parent_type, "Product")
    ref sku = trace.nodes[product.child[1]]
    assert_equal(sku.response_name.value(), "sku")
    assert_equal(sku.type, "String")
    assert_true(sku.start_time >= product.start_time)
    assert_true(trace.duration_ns >= sku.end_time)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
