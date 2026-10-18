# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for schema contracts.

The expected SDL is what Hive Federation Composition v0.27.0
`composeSchemaContract` prints for the same subgraphs.
"""

from gql_composition.contract import compose_contract
from gql_composition.error_code import ErrorCode
from gql_composition.validate import Subgraph
from gql_language.parser import parse
from std.testing import TestSuite, assert_equal, assert_true


def _sg(name: String, sdl: String) raises -> Subgraph:
    """Parse a subgraph with no URL."""
    return Subgraph(name, None, parse(sdl))


def _from_graphs(sdl: String) -> String:
    """Return the supergraph from `enum join__Graph` onward."""
    var at = sdl.find("enum join__Graph")
    return String(sdl[byte=at:])


def test_exclude_hides_a_tagged_field() raises:
    var include = List[String]()
    var exclude = List[String]()
    exclude.append("internal")
    var result = compose_contract(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@tag", "@inaccessible"])\ntype Query {\n  user:'
                    ' User\n  secret: String @tag(name: "internal")\n}\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String'
                    ' @tag(name: "public")\n  note: String @tag(name:'
                    ' "internal")\n}\n'
                ),
            )
        ],
        include,
        exclude,
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _EXCLUDE_SUPERGRAPH)
    assert_equal(result.public_sdl, _EXCLUDE_PUBLIC)


comptime _EXCLUDE_SUPERGRAPH = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user: User
  secret: String @inaccessible
}

type User @join__type(graph: USERS, key: "id") {
  id: ID!
  name: String
  note: String @inaccessible
}"""


comptime _EXCLUDE_PUBLIC = """type Query {
  user: User
}

type User {
  id: ID!
  name: String
}"""


def test_exclude_marks_an_unreachable_type() raises:
    var include = List[String]()
    var exclude = List[String]()
    exclude.append("internal")
    var result = compose_contract(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@tag", "@inaccessible"])\ntype Query {\n  user: User\n '
                    ' secret: Secret @tag(name: "internal")\n}\ntype User { id:'
                    " ID! }\ntype Secret { id: ID! }\n"
                ),
            )
        ],
        include,
        exclude,
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _UNREACHABLE_SUPERGRAPH)
    assert_equal(result.public_sdl, _UNREACHABLE_PUBLIC)


comptime _UNREACHABLE_SUPERGRAPH = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user: User
  secret: Secret @inaccessible
}

type User @join__type(graph: USERS) {
  id: ID!
}

type Secret @join__type(graph: USERS) @inaccessible {
  id: ID!
}"""


comptime _UNREACHABLE_PUBLIC = """type Query {
  user: User
}

type User {
  id: ID!
}"""


def test_include_hides_a_query_with_no_tagged_field() raises:
    var include = List[String]()
    include.append("public")
    var exclude = List[String]()
    var result = compose_contract(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@tag", "@inaccessible"])\ntype Query {\n  user:'
                    ' User\n  secret: String @tag(name: "internal")\n}\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  name: String'
                    ' @tag(name: "public")\n  note: String @tag(name:'
                    ' "internal")\n}\n'
                ),
            )
        ],
        include,
        exclude,
    )
    assert_true(len(result.errors) > 0)
    assert_equal(result.errors[0].code, ErrorCode.ONLY_INACCESSIBLE_CHILDREN)


def test_a_type_tag_is_inherited_by_its_fields() raises:
    var include = List[String]()
    include.append("public")
    var exclude = List[String]()
    var result = compose_contract(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@tag", "@inaccessible"])\ntype Query {\n  user: User'
                    ' @tag(name: "public")\n  secret: String @tag(name:'
                    ' "internal")\n}\ntype User @tag(name: "public") {\n  id:'
                    ' ID!\n  note: String @tag(name: "internal")\n}\n'
                ),
            )
        ],
        include,
        exclude,
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _INHERIT_INCLUDE)
    assert_equal(result.public_sdl, _INHERIT_INCLUDE_PUBLIC)
    var hidden = List[String]()
    var drop = List[String]()
    drop.append("public")
    var excluded = compose_contract(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@tag", "@inaccessible"])\ntype Query {\n  user: User'
                    ' @tag(name: "public")\n  secret: String @tag(name:'
                    ' "internal")\n}\ntype User @tag(name: "public") {\n  id:'
                    ' ID!\n  note: String @tag(name: "internal")\n}\n'
                ),
            )
        ],
        hidden,
        drop,
    )
    assert_equal(len(excluded.errors), 0)
    assert_equal(_from_graphs(excluded.supergraph_sdl), _INHERIT_EXCLUDE)
    assert_equal(excluded.public_sdl, _INHERIT_EXCLUDE_PUBLIC)


comptime _INHERIT_INCLUDE = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user: User
  secret: String @inaccessible
}

type User @join__type(graph: USERS) {
  id: ID!
  note: String
}"""


comptime _INHERIT_INCLUDE_PUBLIC = """type Query {
  user: User
}

type User {
  id: ID!
  note: String
}"""


comptime _INHERIT_EXCLUDE = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user: User @inaccessible
  secret: String
}

type User @join__type(graph: USERS) @inaccessible {
  id: ID! @inaccessible
  note: String @inaccessible
}"""


comptime _INHERIT_EXCLUDE_PUBLIC = """type Query {
  secret: String
}"""


def test_a_type_tag_in_one_subgraph_covers_another_subgraphs_field() raises:
    var include = List[String]()
    include.append("public")
    var exclude = List[String]()
    var link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.9", import: ["@key",'
        ' "@shareable", "@tag", "@inaccessible"])\n'
    )
    var result = compose_contract(
        [
            _sg(
                "books",
                link
                + 'type Query { book: User @shareable @tag(name: "public") }\n'
                + 'type User @key(fields: "id") @tag(name: "public") {\n'
                + "  id: ID!\n  title: String @shareable\n}\n",
            ),
            _sg(
                "reviews",
                link
                + "type Query { review: User @shareable @tag(name:"
                ' "public") }\n'
                + 'type User @key(fields: "id") {\n'
                + "  id: ID!\n  email: String\n}\n",
            ),
        ],
        include,
        exclude,
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _CROSS_SUPERGRAPH)
    assert_equal(result.public_sdl, _CROSS_PUBLIC)


comptime _CROSS_SUPERGRAPH = """enum join__Graph {
  BOOKS @join__graph(name: "books", url: "")
  REVIEWS @join__graph(name: "reviews", url: "")
}

type Query @join__type(graph: BOOKS) @join__type(graph: REVIEWS) {
  book: User @join__field(graph: BOOKS)
  review: User @join__field(graph: REVIEWS)
}

type User @join__type(graph: BOOKS, key: "id") @join__type(graph: REVIEWS, key: "id") {
  id: ID!
  title: String @join__field(graph: BOOKS)
  email: String @join__field(graph: REVIEWS)
}"""


comptime _CROSS_PUBLIC = """type Query {
  book: User
  review: User
}

type User {
  id: ID!
  title: String
  email: String
}"""


def test_exclude_hides_an_enum_value() raises:
    var include = List[String]()
    var exclude = List[String]()
    exclude.append("hidden")
    var result = compose_contract(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@tag", "@inaccessible"])\nenum Color @tag(name:'
                    ' "shown") {\n  RED\n  BLUE @tag(name: "hidden")\n}\ntype'
                    ' Query { color: Color @tag(name: "shown") }\n'
                ),
            )
        ],
        include,
        exclude,
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ENUM_SUPERGRAPH)
    assert_equal(result.public_sdl, _ENUM_PUBLIC)


comptime _ENUM_SUPERGRAPH = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  color: Color
}

enum Color @join__type(graph: USERS) {
  RED @join__enumValue(graph: USERS)
  BLUE @join__enumValue(graph: USERS) @inaccessible
}"""


comptime _ENUM_PUBLIC = """type Query {
  color: Color
}

enum Color {
  RED
}"""


def test_exclude_hides_an_argument() raises:
    var include = List[String]()
    var exclude = List[String]()
    exclude.append("hidden")
    var result = compose_contract(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@tag", "@inaccessible"])\ntype Query {\n '
                    ' user(id: ID @tag(name: "hidden"), kind: String): User'
                    ' @tag(name: "shown")\n}\ntype User @key(fields: "id") {'
                    " id: ID! }\n"
                ),
            )
        ],
        include,
        exclude,
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ARGUMENT_SUPERGRAPH)
    assert_equal(result.public_sdl, _ARGUMENT_PUBLIC)


comptime _ARGUMENT_SUPERGRAPH = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  user(id: ID @inaccessible, kind: String): User
}

type User @join__type(graph: USERS, key: "id") {
  id: ID!
}"""


comptime _ARGUMENT_PUBLIC = """type Query {
  user(kind: String): User
}

type User {
  id: ID!
}"""


def test_an_external_field_keeps_its_tag() raises:
    var include = List[String]()
    var exclude = List[String]()
    exclude.append("hidden")
    var link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.9", import: ["@key", "@tag",'
        ' "@inaccessible", "@external", "@requires"])\n'
    )
    var result = compose_contract(
        [
            _sg(
                "users",
                link
                + "type Query { user: User }\n"
                + 'type User @key(fields: "id") { id: ID! name: String }\n',
            ),
            _sg(
                "feed",
                link
                + "type Query { feed: User }\n"
                + 'extend type User @key(fields: "id") {\n'
                + "  id: ID @external\n"
                + '  name: String @external @tag(name: "hidden")\n'
                + '  comments: [String] @requires(fields: "name")\n'
                + "}\n",
            ),
        ],
        include,
        exclude,
    )
    assert_true(len(result.errors) > 0)
    assert_equal(
        result.errors[0].code,
        ErrorCode.MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL,
    )


def _expect_referenced(sdl: String) raises:
    var include = List[String]()
    var exclude = List[String]()
    exclude.append("hidden")
    var result = compose_contract([_sg("users", sdl)], include, exclude)
    assert_true(len(result.errors) > 0)
    assert_equal(result.errors[0].code, ErrorCode.REFERENCED_INACCESSIBLE)


def test_a_type_with_only_excluded_fields_is_inaccessible() raises:
    _expect_referenced(
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.9", import: ["@tag",'
        ' "@inaccessible"])\n'
        'type Query { widget: Widget @tag(name: "shown") }\n'
        "type Widget {\n"
        '  a: String @tag(name: "hidden")\n'
        '  b: String @tag(name: "hidden")\n'
        "}\n"
    )


def test_an_excluded_scalar_is_inaccessible() raises:
    _expect_referenced(
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.9", import: ["@tag",'
        ' "@inaccessible"])\n'
        'scalar Date @tag(name: "hidden")\n'
        'type Query { today: Date @tag(name: "shown") }\n'
    )


def test_an_excluded_union_is_inaccessible() raises:
    _expect_referenced(
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.9", import: ["@tag",'
        ' "@inaccessible"])\n'
        'type Query { item: Search @tag(name: "shown") }\n'
        'union Search @tag(name: "hidden") = Book\n'
        "type Book { title: String }\n"
    )


def test_a_field_tag_in_one_subgraph_hides_it_in_every_subgraph() raises:
    var include = List[String]()
    var exclude = List[String]()
    exclude.append("hidden")
    var link = (
        "extend schema @link(url:"
        ' "https://specs.apollo.dev/federation/v2.9", import: ["@key",'
        ' "@shareable", "@tag", "@inaccessible"])\n'
    )
    var result = compose_contract(
        [
            _sg(
                "books",
                link
                + 'type Query { book: Widget @shareable @tag(name: "shown") }\n'
                + 'type Widget @key(fields: "id") {\n'
                + "  id: ID! @shareable\n"
                + '  title: String @shareable @tag(name: "hidden")\n'
                + "}\n",
            ),
            _sg(
                "reviews",
                link
                + "type Query { review: Widget @shareable @tag(name:"
                ' "shown") }\n'
                + 'type Widget @key(fields: "id") {\n'
                + '  id: ID! @shareable @tag(name: "hidden")\n'
                + '  note: String @tag(name: "hidden")\n'
                + "}\n",
            ),
        ],
        include,
        exclude,
    )
    assert_true(len(result.errors) > 0)
    assert_equal(result.errors[0].code, ErrorCode.REFERENCED_INACCESSIBLE)


def test_a_renamed_tag_import_still_filters() raises:
    var include = List[String]()
    var exclude = List[String]()
    exclude.append("hidden")
    var result = compose_contract(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", {name: "@tag", as: "@label"},'
                    ' "@inaccessible"])\ntype Query {\n  shown: String'
                    ' @label(name: "shown")\n  secret: String @label(name:'
                    ' "hidden")\n}\n'
                ),
            )
        ],
        include,
        exclude,
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _ALIAS_SUPERGRAPH)
    assert_equal(result.public_sdl, _ALIAS_PUBLIC)


comptime _ALIAS_SUPERGRAPH = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  shown: String
  secret: String @inaccessible
}"""


comptime _ALIAS_PUBLIC = """type Query {
  shown: String
}"""


def test_include_and_exclude_both_apply() raises:
    var include = List[String]()
    include.append("public")
    var exclude = List[String]()
    exclude.append("hidden")
    var result = compose_contract(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@tag", "@inaccessible"])\ntype Query {\n  both: String'
                    ' @tag(name: "public") @tag(name: "hidden")\n  onlyPublic:'
                    ' String @tag(name: "public")\n  plain: String\n}\n'
                ),
            )
        ],
        include,
        exclude,
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _BOTH_SUPERGRAPH)
    assert_equal(result.public_sdl, _BOTH_PUBLIC)


comptime _BOTH_SUPERGRAPH = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  both: String @inaccessible
  onlyPublic: String
  plain: String @inaccessible
}"""


comptime _BOTH_PUBLIC = """type Query {
  onlyPublic: String
}"""


def test_an_unreachable_type_does_not_mark_a_longer_name() raises:
    var include = List[String]()
    var exclude = List[String]()
    exclude.append("hidden")
    var result = compose_contract(
        [
            _sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@tag", "@inaccessible"])\ntype Query {\n  extra:'
                    ' ItemExtra @tag(name: "shown")\n  secret: Item @tag(name:'
                    ' "hidden")\n}\ntype ItemExtra { id: ID! }\ntype Item { id:'
                    " ID! }\n"
                ),
            )
        ],
        include,
        exclude,
    )
    assert_equal(len(result.errors), 0)
    assert_equal(_from_graphs(result.supergraph_sdl), _PREFIX_SUPERGRAPH)
    assert_equal(result.public_sdl, _PREFIX_PUBLIC)


comptime _PREFIX_SUPERGRAPH = """enum join__Graph {
  USERS @join__graph(name: "users", url: "")
}

type Query @join__type(graph: USERS) {
  extra: ItemExtra
  secret: Item @inaccessible
}

type ItemExtra @join__type(graph: USERS) {
  id: ID!
}

type Item @join__type(graph: USERS) @inaccessible {
  id: ID!
}"""


comptime _PREFIX_PUBLIC = """type Query {
  extra: ItemExtra
}

type ItemExtra {
  id: ID!
}"""


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
