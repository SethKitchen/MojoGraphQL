# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""More tests for object satisfiability.

Port of cases in the style of Hive Federation Composition v0.27.0
`__tests__/supergraph/errors/SATISFIABILITY_ERROR.spec.ts`. The expected
messages are the `SATISFIABILITY_ERROR` messages of Hive `composeServices`
in Node.js for the same subgraphs. The order of the messages is not
compared, because Hive groups them by field name.
"""

from gql_composition.error_code import ErrorCode
from gql_composition.satisfiability import satisfiability_errors
from gql_composition.validate import Subgraph
from gql_language.parser import parse
from std.testing import TestSuite, assert_equal, assert_true


def _sg(name: String, sdl: String) raises -> Subgraph:
    """Parse a subgraph with no URL."""
    return Subgraph(name, None, parse(sdl))


def _expect(subgraphs: List[Subgraph], expected: List[String]) raises:
    """Check the satisfiability messages, in any order."""
    var result = satisfiability_errors(subgraphs)
    var messages = List[String]()
    for ref error in result:
        assert_equal(error.code, ErrorCode.SATISFIABILITY_ERROR)
        messages.append(error.message)
    for ref message in expected:
        var found = False
        for ref item in messages:
            if item == message:
                found = True
        assert_true(found, message)
    assert_equal(len(messages), len(expected))


def test_provides_or_requires_alone_imports_the_field_set() raises:
    # Hive composes these subgraphs without errors.
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@provides"])\ntype Query { a: Int }\n'
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@requires"])\ntype Query { b: Int }\n'
                ),
            ),
        ],
        [],
    )


def _raised(subgraphs: List[Subgraph]) -> String:
    """Return the message that `satisfiability_errors` raises, or empty."""
    try:
        _ = satisfiability_errors(subgraphs)
    except error:
        return String(error)
    return String("")


comptime _UNTYPED = "Inline fragment without type condition is not supported."


def test_an_untyped_fragment_in_requires_raises() raises:
    # Hive `composeServices` throws the same error for these subgraphs.
    var link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.3", import: ["@key",'
        ' "@external", "@requires", "@provides"])\n'
    )
    assert_equal(
        _raised(
            [
                _sg(
                    "a",
                    link
                    + "type Query { users: [User] }\n"
                    + 'type User @key(fields: "id") { id: ID! name: String'
                    + ' @external tag: String @requires(fields: "name ... {'
                    + ' name }") }\n',
                ),
                _sg(
                    "b",
                    link
                    + 'type User @key(fields: "id") { id: ID! name: String }\n',
                ),
            ]
        ),
        _UNTYPED,
    )
    assert_equal(
        _raised(
            [
                _sg(
                    "a",
                    link
                    + 'type Query { users: [User] @provides(fields: "name ... {'
                    + ' name }") }\n'
                    + 'type User @key(fields: "id") { id: ID! name: String'
                    + " @external }\n",
                ),
                _sg(
                    "b",
                    link
                    + 'type User @key(fields: "id") { id: ID! name: String }\n',
                ),
            ]
        ),
        _UNTYPED,
    )


def test_a_subgraph_error_comes_first() raises:
    var result = satisfiability_errors(
        [_sg("a", "type Query { a: Missing }\n")]
    )
    assert_true(len(result) > 0)
    assert_true(result[0].code != ErrorCode.SATISFIABILITY_ERROR)


def test_shared_roots_scalars_unions_and_interfaces() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable", "@inaccessible"])\ntype Query {\n '
                    " hello: String\n  users: [User] @shareable\n  secret: User"
                    " @inaccessible\n  search: [Result]\n  node:"
                    " Node\n}\ninterface Node { id: ID! }\nunion Result = User"
                    ' | Post\ntype User implements Node @key(fields: "id") {'
                    ' id: ID! name: String }\ntype Post @key(fields: "id") {'
                    " id: ID! title: String }\n"
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ntype Query {\n  users: [User]'
                    " @shareable\n  feed: Feed\n}\ninterface Node { id: ID!"
                    " }\nunion Result = User | Post\ntype Feed { items:"
                    " [Result] nodes: [Node] }\ntype User implements Node"
                    ' @key(fields: "id") { id: ID! age: Int }\ntype Post'
                    ' @key(fields: "id") { id: ID! }\n'
                ),
            ),
        ],
        [],
    )


def test_moves_to_external_and_missing_fields() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { products: [Product] }\ntype'
                    ' Product @key(fields: "id") { id: ID! }\n'
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    ' @external\n  label: String @requires(fields: "name")\n}\n'
                ),
            ),
            _sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { other: Int }\ntype Product'
                    ' @key(fields: "id") { id: ID! price: Int }\n'
                ),
            ),
            _sg(
                "d",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Product @key(fields: "id") { id: ID!'
                    " name: String }\n"
                ),
            ),
            _sg(
                "e",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { e: Int }\n'
                ),
            ),
        ],
        [],
    )


def test_root_arguments() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external"])\ntype Query {\n  search(a: String,'
                    " b: Int!, c: Float, d: Boolean, e: ID, f: Color, g:"
                    " [ID!]!): [Product]\n}\nenum Color { RED GREEN }\ntype"
                    ' Product @key(fields: "id") { id: ID! }\n'
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Product @key(fields: "id  sku") { id: ID!'
                    " sku: ID! name: String }\n"
                ),
            ),
        ],
        [
            (
                'The following supergraph API query:\n{\n  search(a: "A string'
                ' value", b: 0, c: 0, d: true, e: "<any id>", f: RED, g: [])'
                " {\n    sku\n  }\n}\ncannot be satisfied by the subgraphs"
                ' because:\n- from subgraph "a":\n  - cannot find field'
                ' "Product.sku".\n  - cannot move to subgraph "b" using'
                ' @key(fields: "id sku") of "Product", the key field(s) cannot'
                ' be resolved from subgraph "a".'
            ),
            (
                'The following supergraph API query:\n{\n  search(a: "A string'
                ' value", b: 0, c: 0, d: true, e: "<any id>", f: RED, g: [])'
                " {\n    name\n  }\n}\ncannot be satisfied by the subgraphs"
                ' because:\n- from subgraph "a":\n  - cannot find field'
                ' "Product.name".\n  - cannot move to subgraph "b" using'
                ' @key(fields: "id sku") of "Product", the key field(s) cannot'
                ' be resolved from subgraph "a".'
            ),
        ],
    )


def test_provides_selections() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@provides"])\ntype Query {\n '
                    ' users: [User] @provides(fields: "full_name2 Address{ city'
                    ' } ")\n  deep: [User] @provides(fields: "Address { geo {'
                    ' lat } }")\n}\ntype User @key(fields: "id") {\n  id: ID!\n'
                    "  full_name2: String @external\n  Address: Address"
                    ' @external\n}\ntype Address @key(fields: "id") { id: ID!'
                    " city: String @external geo: Geo @external }\ntype Geo {"
                    " lat: Float @external }\n"
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ntype User @key(fields: "id") {'
                    " id: ID! full_name2: String Address: Address }\ntype"
                    ' Address @key(fields: "id") { id: ID! city: String street:'
                    " String geo: Geo }\ntype Geo @shareable { lat: Float lng:"
                    " Float }\n"
                ),
            ),
        ],
        [],
    )


def test_nested_requires_and_field_arguments() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { users:'
                    ' [User] }\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " address: Address @external\n  zip: String"
                    ' @requires(fields: "address { code }")\n  posts(first:'
                    " Int): [String]\n}\ntype Address { code: String"
                    " @external }\n"
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ntype User @key(fields: "id",'
                    " resolvable: false) { id: ID! address: Address }\ntype"
                    " Address @shareable { code: String }\n"
                ),
            ),
        ],
        [
            (
                "The following supergraph API query:\n{\n  users {\n    address"
                " {\n      ...\n    }\n  }\n}\ncannot be satisfied by the"
                ' subgraphs because:\n- from subgraph "a": field "User.address"'
                " is not resolvable because marked @external."
            ),
            (
                "The following supergraph API query:\n{\n  users {\n    zip\n "
                " }\n}\ncannot be satisfied by the subgraphs because:\n- from"
                ' subgraph "a": cannot satisfy @require conditions on field'
                ' "User.zip".'
            ),
        ],
    )


def test_interface_object_second_key() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\ntype Query { media:'
                    ' [Media] }\ntype Media @key(fields: "id") @interfaceObject'
                    " { extra: String id: ID! }\n"
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\ninterface Media'
                    ' @key(fields: "sku") @key(fields: "id") { id: ID! sku: ID!'
                    ' }\ntype Book implements Media @key(fields: "id")'
                    ' @key(fields: "sku") { id: ID! sku: ID! title: String }\n'
                ),
            ),
        ],
        [],
    )


def test_no_key_needs_the_field() raises:
    _expect(
        [
            _sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\ntype Query { featured: Publisher }\ntype'
                    ' Publisher @key(fields: "id") { id: ID! books:'
                    " [String] }\n"
                ),
            ),
            _sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\ntype Query { publisher: Publisher }\ntype'
                    ' Publisher @key(fields: "id", resolvable: false) { id: ID!'
                    " name: String }\n"
                ),
            ),
            _sg(
                "stock",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\ntype Query { stock: Int }\ntype Publisher'
                    ' @key(fields: "id", resolvable: false) { id: ID! }\n'
                ),
            ),
        ],
        [
            (
                "The following supergraph API query:\n{\n  featured {\n   "
                " name\n  }\n}\ncannot be satisfied by the subgraphs"
                ' because:\n- from subgraph "books":\n  - cannot find field'
                ' "Publisher.name".\n  - cannot move to subgraph "catalog",'
                ' which has field "Publisher.name", because type "Publisher"'
                ' has no @key defined in subgraph "catalog".'
            ),
        ],
    )


def test_nested_inaccessible_and_interface_object_fields() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject", "@inaccessible"])\ntype'
                    ' Query { users: [User] }\ntype User @key(fields: "id") {'
                    " id: ID! secret: String @inaccessible media: [Media]"
                    ' }\ntype Media @key(fields: "id") @interfaceObject { id:'
                    " ID! }\n"
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ninterface Media @key(fields: "id") { id: ID!'
                    ' }\ntype Book implements Media @key(fields: "id") { id:'
                    " ID! title: String }\n"
                ),
            ),
            _sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { c: Int }\n'
                ),
            ),
        ],
        [],
    )


def test_nested_provides_selections() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@provides"])\ntype Query { users:'
                    ' [User] }\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' profile: Profile @provides(fields: "full_name2 nick'
                    ' Address{ city } ")\n  deep: Profile @provides(fields:'
                    ' "nick Address { geo { lat } }")\n}\ntype Profile'
                    ' @key(fields: "id") {\n  id: ID!\n  full_name2: String'
                    " @external\n  nick: String @external\n  Address: Address"
                    ' @external\n}\ntype Address @key(fields: "id") { id: ID!'
                    " city: String @external geo: Geo @external }\ntype Geo {"
                    " lat: Float @external }\n"
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ntype Profile @key(fields: "id")'
                    " { id: ID! full_name2: String nick: String Address:"
                    ' Address }\ntype Address @key(fields: "id") { id: ID!'
                    " city: String street: String geo: Geo }\ntype Geo"
                    " @shareable { lat: Float }\n"
                ),
            ),
        ],
        [],
    )


def test_requires_with_a_fragment() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { users:'
                    " [User] }\ninterface Media { id: ID! }\ntype Book"
                    ' implements Media @key(fields: "id") { id: ID! title:'
                    ' String @external }\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  media: Media @external\n  tag: String"
                    ' @requires(fields: "media { ... on Book { title } }")\n}\n'
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ninterface Media { id: ID! }\ntype Book'
                    ' implements Media @key(fields: "id") { id: ID! title:'
                    ' String }\ntype User @key(fields: "id") { id: ID! media:'
                    " Media }\n"
                ),
            ),
        ],
        [],
    )


def test_labeled_override_with_a_third_graph() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\ntype Query { products: [Product]'
                    ' }\ntype Product @key(fields: "id") { id: ID! price: Int'
                    ' @override(from: "b", label: "percent(50)") }\n'
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\ntype Product @key(fields: "id") { id: ID!'
                    " price: Int }\n"
                ),
            ),
            _sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\ntype Query { c: Int }\n'
                ),
            ),
        ],
        [],
    )


def test_interface_object_external_key() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject", "@external"])\ntype Query {'
                    ' media: [Media] }\ntype Media @key(fields: "id")'
                    " @interfaceObject { id: ID! @external extra: String }\n"
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ninterface Media @key(fields: "id") { id: ID!'
                    ' }\ntype Book implements Media @key(fields: "id") { id:'
                    " ID! title: String }\n"
                ),
            ),
        ],
        [],
    )


def test_interface_object_unreachable_from_two_roots() raises:
    _expect(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject", "@shareable"])\ntype Query {'
                    " user: User other: User }\ntype User @interfaceObject"
                    ' @key(fields: "id") { id: ID! name: String @shareable }\n'
                ),
            ),
            _sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\ninterface User @key(fields:'
                    ' "id", resolvable: false) { id: ID! name: String }\ntype'
                    ' Admin implements User @key(fields: "id", resolvable:'
                    " false) { id: ID! name: String @shareable reviews:"
                    " [String] }\n"
                ),
            ),
        ],
        [
            (
                "The following supergraph API query:\n{\n  user {\n    ... on"
                " Admin {\n      ...\n    }\n  }\n}\ncannot be satisfied by the"
                ' subgraphs because:\n- from subgraph "users": no subgraph can'
                " be reached to resolve the implementation type of"
                ' @interfaceObject type "User".'
            ),
        ],
    )


def test_root_custom_scalar_argument() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\nscalar DateTime\ntype Query { at(when:'
                    ' DateTime): [Product] }\ntype Product @key(fields: "id") {'
                    " id: ID! }\n"
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Product @key(fields: "sku") { sku: ID!'
                    " name: String }\n"
                ),
            ),
        ],
        [
            (
                'The following supergraph API query:\n{\n  at(when: "A string'
                ' value") {\n    sku\n  }\n}\ncannot be satisfied by the'
                ' subgraphs because:\n- from subgraph "a":\n  - cannot find'
                ' field "Product.sku".\n  - cannot move to subgraph "b" using'
                ' @key(fields: "sku") of "Product", the key field(s) cannot be'
                ' resolved from subgraph "a".'
            ),
            (
                'The following supergraph API query:\n{\n  at(when: "A string'
                ' value") {\n    name\n  }\n}\ncannot be satisfied by the'
                ' subgraphs because:\n- from subgraph "a":\n  - cannot find'
                ' field "Product.name".\n  - cannot move to subgraph "b" using'
                ' @key(fields: "sku") of "Product", the key field(s) cannot be'
                ' resolved from subgraph "a".'
            ),
        ],
    )


def test_nested_requires_child_unreachable() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { users:'
                    ' [User] }\ntype User @key(fields: "id") { id: ID! address:'
                    ' Address @external zip: String @requires(fields: "address'
                    ' { code }") }\ntype Address { code: String @external }\n'
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype User'
                    ' @key(fields: "id") { id: ID! address: Address }\ntype'
                    ' Address @key(fields: "id") { id: ID! }\n'
                ),
            ),
            _sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Address'
                    ' @key(fields: "sku") { sku: ID! code: String }\n'
                ),
            ),
        ],
        [
            (
                "The following supergraph API query:\n{\n  users {\n    zip\n "
                " }\n}\ncannot be satisfied by the subgraphs because:\n- from"
                ' subgraph "a": cannot satisfy @require conditions on field'
                ' "User.zip".\n- from subgraph "b": cannot find field'
                ' "User.zip".'
            ),
            (
                "The following supergraph API query:\n{\n  users {\n    address"
                " {\n      code\n    }\n  }\n}\ncannot be satisfied by the"
                ' subgraphs because:\n- from subgraph "b":\n  - cannot find'
                ' field "Address.code".\n  - cannot move to subgraph "c" using'
                ' @key(fields: "sku") of "Address", the key field(s) cannot be'
                ' resolved from subgraph "b".'
            ),
            (
                "The following supergraph API query:\n{\n  users {\n    address"
                " {\n      sku\n    }\n  }\n}\ncannot be satisfied by the"
                ' subgraphs because:\n- from subgraph "b":\n  - cannot find'
                ' field "Address.sku".\n  - cannot move to subgraph "c" using'
                ' @key(fields: "sku") of "Address", the key field(s) cannot be'
                ' resolved from subgraph "b".'
            ),
        ],
    )


def test_moves_with_a_graph_without_the_type() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query {'
                    ' products: [Product] }\ntype Product @key(fields: "id") {'
                    " id: ID! }\n"
                ),
            ),
            _sg(
                "a0",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Query { e:'
                    " Int }\n"
                ),
            ),
            _sg(
                "d",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\ntype Product'
                    ' @key(fields: "id") { id: ID! name: String }\n'
                ),
            ),
        ],
        [],
    )


def test_interface_object_key_skips_a_graph_without_it() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\ntype Query { media:'
                    ' [Media] }\ntype Media @key(fields: "id") @interfaceObject'
                    " { id: ID! }\n"
                ),
            ),
            _sg(
                "a0",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ntype Query { c: Int }\n'
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\ninterface Media @key(fields: "id") { id: ID!'
                    ' }\ntype Book implements Media @key(fields: "id") { id:'
                    " ID! title: String }\n"
                ),
            ),
        ],
        [],
    )


def test_nested_field_arguments_print() raises:
    _expect(
        [
            _sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires", "@shareable"])\ntype'
                    ' Query { users: [User] }\ntype User @key(fields: "id") {\n'
                    "  id: ID!\n  address: Address @external\n  zip(format:"
                    ' String, digits: Int): String @requires(fields: "address {'
                    ' code }")\n}\ntype Address { code: String @external }\n'
                ),
            ),
            _sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires", "@shareable"])\ntype'
                    ' User @key(fields: "id", resolvable: false) { id: ID!'
                    " address: Address }\ntype Address @shareable { code:"
                    " String }\n"
                ),
            ),
        ],
        [
            (
                "The following supergraph API query:\n{\n  users {\n    address"
                " {\n      ...\n    }\n  }\n}\ncannot be satisfied by the"
                ' subgraphs because:\n- from subgraph "a": field "User.address"'
                " is not resolvable because marked @external."
            ),
            (
                "The following supergraph API query:\n{\n  users {\n   "
                ' zip(format: "A string value", digits: 0)\n  }\n}\ncannot be'
                ' satisfied by the subgraphs because:\n- from subgraph "a":'
                ' cannot satisfy @require conditions on field "User.zip".'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
