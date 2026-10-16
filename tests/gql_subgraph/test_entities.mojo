# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `Query._entities`, ported from `@apollo/subgraph` 2.14.4
`src/__tests__/buildSubgraphSchema.test.ts` (`_entities root field`).

The upstream resolvers that return promises are synchronous here. The
other cases check each path of upstream `src/types.ts`; their expected
results come from `@apollo/subgraph` 2.14.4 itself, run in Node.js with
the same SDL, resolvers and representations. One message differs: upstream
writes the value of a `__resolveType` that is not a string with Node.js
`util.inspect` (`{ id: '1' }`), and this port with graphql-js `inspect`
(`{ id: "1" }`).
"""

from std.testing import TestSuite, assert_equal
from _helpers import run, sdl_document
from gql_execution.execute import ExecutionArgs, ResolveInfo, execute
from gql_execution.value import Values
from gql_subgraph.build_subgraph_schema import (
    SchemaModule,
    SubgraphResolvers,
    SubgraphSchema,
    build_subgraph_schema,
)


def _build(sdl: String, var resolvers: SubgraphResolvers) raises -> SubgraphSchema:
    var modules = List[SchemaModule]()
    modules.append(SchemaModule(sdl_document(sdl), resolvers^))
    return build_subgraph_schema(modules^)


def _object(mut values: Values, key: String, value: String) -> Int:
    var object = values.add_object()
    values.add_member(object, key, values.add_string(value))
    return object


def _product_reference(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    if values.number(values.get(reference, "upc")) != 1:
        raise Error("expected upc 1")
    return _object(values, "name", "Apollo Gateway")


def _user_reference(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    if values.number(values.get(reference, "id")) != 1:
        raise Error("expected id 1")
    return _object(values, "firstName", "James")


def test_executes_resolve_reference_for_a_type_if_found() raises:
    var resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Product", _product_reference)
    resolvers.resolve_reference("User", _user_reference)
    var schema = _build(
        'type Product @key(fields: "upc") { upc: Int name: String } type User'
        ' @key(fields: "id") { firstName: String }',
        resolvers^,
    )
    assert_equal(
        run(
            schema,
            "query GetEntities($representations: [_Any!]!) {"
            " _entities(representations: $representations) { ... on Product {"
            " name } ... on User { firstName } } }",
            '{"representations": [{"__typename": "Product", "upc": 1},'
            ' {"__typename": "User", "id": 1}]}',
        ),
        '{"data":{"_entities":[{"name":"Apollo Gateway"},{"firstName":"James"}]}}',
    )


def test_executes_resolve_reference_with_default_representation_values() raises:
    var schema = _build(
        'type Product @key(fields: "upc") { upc: Int name: String }',
        SubgraphResolvers(),
    )
    assert_equal(
        run(
            schema,
            "query GetEntities($representations: [_Any!]!) {"
            " _entities(representations: $representations) { ... on Product {"
            " upc name } } }",
            '{"representations": [{"__typename": "Product", "upc": 1, "name":'
            ' "Apollo Gateway"}]}',
        ),
        '{"data":{"_entities":[{"upc":1,"name":"Apollo Gateway"}]}}',
    )


def _book_reference(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    var book = _object(values, "id", "1")
    values.add_member(book, "name", values.add_string("My book"))
    values.add_member(book, "author", values.add_string("Author"))
    return book


def _book_if_author(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises -> Int:
    if values.member(value, "author") != -1:
        return values.add_string("Book")
    raise Error("Could not resolve type")


def test_resolves_values_from_resolve_reference_for_resolve_type() raises:
    var resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Product", _book_reference)
    resolvers.resolve_type("Product", _book_if_author)
    var schema = _build(
        """extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.4", import: ["@key"])
interface Product @key(fields: "id") { id: ID! name: String }
type Book implements Product @key(fields: "id") {
  id: ID!
  name: String
  author: String!
}""",
        resolvers^,
    )
    assert_equal(
        run(
            schema,
            "query ($representations: [_Any!]!) { _entities(representations:"
            " $representations) { ... on Product { name } } }",
            '{"representations": [{"__typename": "Product", "id": 1}]}',
        ),
        '{"data":{"_entities":[{"name":"My book"}]}}',
    )


def _keyed_product(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    var key = String(values.string(values.get(reference, "key")))
    if key == "a" or key == "b":
        var product = _object(values, "type", "A" if key == "a" else "B")
        values.add_member(product, "key", values.add_string(key))
        return product
    return values.add_null()


def _product_by_type(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises -> Int:
    var type = String(values.string(values.get(value, "type")))
    if type == "A":
        return values.add_string("ProductA")
    if type == "B":
        return values.add_string("ProductB")
    raise Error("Unknown type")


def test_skips_resolve_type_if_resolve_reference_returns_null() raises:
    var resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Product", _keyed_product)
    resolvers.resolve_type("Product", _product_by_type)
    var schema = _build(
        """extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.8", import: ["@key"])
enum ProductType { A B }
interface Product @key(fields: "key") { type: ProductType! key: String! }
type ProductA implements Product @key(fields: "key") {
  type: ProductType!
  key: String!
}
type ProductB implements Product @key(fields: "key") {
  type: ProductType!
  key: String!
}""",
        resolvers^,
    )
    assert_equal(
        run(
            schema,
            'query Product { _entities(representations: [{ __typename:'
            ' "Product", key: "unknown" }]) { __typename ... on Product { type'
            " key } } }",
        ),
        '{"data":{"_entities":[null]}}',
    )


# --- each path of src/types.ts, against @apollo/subgraph in Node.js -----

comptime ENTITY_SDL = """extend schema @link(url: "https://specs.apollo.dev/federation/v2.3", import: ["@key"])
type Query { x: Int }
interface Product @key(fields: "id") { id: ID! name: String }
type Book implements Product @key(fields: "id") { id: ID! name: String author: String }
type Other @key(fields: "id") { id: ID! name: String }"""

comptime ENTITY_QUERY = (
    "query($r: [_Any!]!) { _entities(representations: $r) { __typename ... on"
    " Book { id name } ... on Other { id name } } }"
)


def _entities(var resolvers: SubgraphResolvers, representations: String) raises -> String:
    var schema = _build(ENTITY_SDL, resolvers^)
    return run(schema, ENTITY_QUERY, '{"r": ' + representations + "}")


def _field_error(message: String) -> String:
    return (
        '{"errors":[{"message":"'
        + message
        + '","locations":[{"line":1,"column":23}],"path":["_entities"]}],"data":null}'
    )


def _item_error(message: String) -> String:
    return (
        '{"errors":[{"message":"'
        + message
        + '","locations":[{"line":1,"column":23}],"path":["_entities",0]}],'
        '"data":{"_entities":[null]}}'
    )


def _no_type(name: String) -> String:
    return _field_error(
        'The _entities resolver tried to load an entity for type \\"'
        + name
        + '\\", but no object or interface type of that name was found in the'
        " schema"
    )


def test_a_typename_that_names_no_object_or_interface_type() raises:
    var none = SubgraphResolvers()
    assert_equal(_entities(none.copy(), '[{"__typename": "Nope"}]'), _no_type("Nope"))
    assert_equal(_entities(none.copy(), '[{"__typename": "String"}]'), _no_type("String"))
    assert_equal(_entities(none.copy(), '[{"id": 1}]'), _no_type("undefined"))
    assert_equal(_entities(none.copy(), '[{"__typename": 1}]'), _no_type("1"))
    assert_equal(
        _entities(none.copy(), '[{"__typename": {"a": 1}}]'),
        _no_type("[object Object]"),
    )
    assert_equal(_entities(none^, "[]"), '{"data":{"_entities":[]}}')


def _id_only(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    return _object(values, "id", "1")


def _type_five(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises -> Int:
    return values.add_number(5)


def _type_nope(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises -> Int:
    return values.add_string("Nope")


def _type_other(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises -> Int:
    return values.add_string("Other")


def _type_book(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises -> Int:
    return values.add_string("Book")


def _type_raises(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises -> Int:
    raise Error("nope")


def _always(mut values: Values, value: Int, info: ResolveInfo) raises -> Bool:
    return True


def _never(mut values: Values, value: Int, info: ResolveInfo) raises -> Bool:
    return False


def _book_nine(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    return _object(values, "id", "9")


def _book_from_reference(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    var id = String(values.string(values.get(reference, "id")))
    var book = _object(values, "id", id + "2")
    values.add_member(book, "name", values.add_string("from book"))
    return book


comptime PRODUCT = '[{"__typename": "Product", "id": "1"}]'
comptime MUST_RESOLVE = (
    'Abstract type \\"Product\\" `__resolveReference` method must resolve to'
    " an Object type at runtime. Either the object returned by"
    ' \\"Product.__resolveReference\\" must include a valid `__typename`'
    ' field, or the \\"Product\\" type should provide a \\"resolveType\\"'
    ' function or each possible type should provide an \\"isTypeOf\\"'
    " function."
)


def test_an_interface_entity_without_a_type_resolver() raises:
    assert_equal(
        _entities(SubgraphResolvers(), PRODUCT),
        _item_error(
            'Abstract type \\"Product\\" `__resolveReference` method resolved'
            ' to a non-object type \\"Product\\".'
        ),
    )
    var resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Product", _id_only)
    resolvers.is_type_of("Book", _never)
    assert_equal(_entities(resolvers^, PRODUCT), _item_error(MUST_RESOLVE))


def test_an_interface_entity_with_a_bad_runtime_type() raises:
    var resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Product", _id_only)
    resolvers.resolve_type("Product", _type_five)
    assert_equal(
        _entities(resolvers^, PRODUCT),
        _item_error(
            'Abstract type \\"Product\\" `__resolveReference` method must'
            ' resolve to an Object type at runtime with value { id: \\"1\\" },'
            ' received \\"5\\".'
        ),
    )
    resolvers = SubgraphResolvers()
    resolvers.resolve_type("Product", _type_nope)
    assert_equal(
        _entities(resolvers^, PRODUCT),
        _item_error(
            'Abstract type \\"Product\\" `__resolveReference` method resolved'
            ' to a type \\"Nope\\" that does not exist inside the schema.'
        ),
    )
    resolvers = SubgraphResolvers()
    resolvers.resolve_type("Product", _type_other)
    assert_equal(
        _entities(resolvers^, PRODUCT),
        _item_error(
            'Runtime Object type \\"Other\\" `__resolveReference` method is not'
            ' a possible type for \\"Product\\".'
        ),
    )
    resolvers = SubgraphResolvers()
    resolvers.resolve_type("Product", _type_raises)
    assert_equal(_entities(resolvers^, PRODUCT), _item_error("nope"))


def test_an_interface_entity_found_by_is_type_of() raises:
    var resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Product", _id_only)
    resolvers.is_type_of("Book", _always)
    resolvers.resolve_reference("Book", _book_nine)
    assert_equal(
        _entities(resolvers^, PRODUCT),
        '{"data":{"_entities":[{"__typename":"Book","id":"1","name":null}]}}',
    )


def test_an_interface_entity_uses_the_reference_resolver_of_its_type() raises:
    var resolvers = SubgraphResolvers()
    resolvers.resolve_type("Product", _type_book)
    resolvers.resolve_reference("Book", _book_from_reference)
    assert_equal(
        _entities(resolvers^, PRODUCT),
        '{"data":{"_entities":[{"__typename":"Book","id":"12","name":"from'
        ' book"}]}}',
    )


def _bad(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    return values.add_error("bad")


def _boom(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    raise Error("boom")


def _retyped(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    var other = _object(values, "__typename", "Other")
    values.add_member(other, "id", values.add_string("3"))
    values.add_member(other, "name", values.add_string("x"))
    return other


def _null(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    return values.add_null()


def _text(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string("text")


def test_an_interface_entity_without_typename_or_is_type_of() raises:
    var resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Product", _id_only)
    assert_equal(_entities(resolvers^, PRODUCT), _item_error(MUST_RESOLVE))
    resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Product", _bad)
    assert_equal(_entities(resolvers^, PRODUCT), _item_error(MUST_RESOLVE))


def test_an_interface_entity_that_is_null_or_raises() raises:
    var resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Product", _null)
    assert_equal(
        _entities(resolvers^, PRODUCT), '{"data":{"_entities":[null]}}'
    )
    resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Product", _boom)
    assert_equal(_entities(resolvers^, PRODUCT), _field_error("boom"))


def test_an_object_entity_that_fails() raises:
    var resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Book", _bad)
    assert_equal(
        _entities(
            resolvers^,
            '[{"__typename": "Book", "id": "1"}, {"__typename": "Book", "id":'
            ' "2"}]',
        ),
        '{"errors":[{"message":"bad","locations":[{"line":1,"column":23}],'
        '"path":["_entities",0]},{"message":"bad","locations":[{"line":1,'
        '"column":23}],"path":["_entities",1]}],"data":{"_entities":[null,null]}}',
    )
    resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Book", _boom)
    assert_equal(
        _entities(resolvers^, '[{"__typename": "Book", "id": "1"}]'),
        _field_error("boom"),
    )
    resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Book", _text)
    assert_equal(
        _entities(resolvers^, '[{"__typename": "Book", "id": "1"}]'),
        _item_error(
            'Abstract type \\"_Entity\\" must resolve to an Object type at'
            ' runtime for field \\"Query._entities\\". Either the \\"_Entity\\"'
            ' type should provide a \\"resolveType\\" function or each possible'
            ' type should provide an \\"isTypeOf\\" function.'
        ),
    )


def test_an_object_entity_gets_the_typename_of_its_type() raises:
    var resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Book", _retyped)
    assert_equal(
        _entities(resolvers^, '[{"__typename": "Book", "id": "1"}]'),
        '{"data":{"_entities":[{"__typename":"Book","id":"3","name":"x"}]}}',
    )


def test_federation_fields_need_subgraph_execute() raises:
    var schema = _build(ENTITY_SDL, SubgraphResolvers())
    var args = ExecutionArgs()
    args.resolvers = schema.resolvers.resolvers.copy()
    var result = execute(
        schema.schema, sdl_document("{ _service { sdl } }"), args
    )
    assert_equal(
        result.to_json(),
        '{"errors":[{"message":"A subgraph field must execute with'
        ' SubgraphSchema.execute","locations":[{"line":1,"column":3}],'
        '"path":["_service"]}],"data":null}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
