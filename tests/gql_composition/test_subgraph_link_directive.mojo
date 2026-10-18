# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/link-directive.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_invalid_link_identifier() raises:
    # v2.0 > INVALID_LINK_IDENTIFIER
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev", import: [{name: "@key", as:'
                    ' "@renamed"}])\n\nextend type Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int! @external\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Invalid @link url"
                " 'https://specs.apollo.dev': expected '/<feature>/vX.Y' (for"
                " example '/federation/v2.9')"
            ),
        ],
    )
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/not-a-version",'
                    ' import: [{name: "@key", as: "@renamed"}])\n\nextend type'
                    ' Payment @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int!'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Expected a version string"
                " (of the form v1.2), got null"
            ),
        ],
    )


def test_v2_0_invalid_link_directive_usage_duplicate_inclusion_of_feature() raises:
    # v2.0 > INVALID_LINK_DIRECTIVE_USAGE: Duplicate inclusion of feature
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!'
                    ' @override(from: "payments") @external\n}\n\ntype Invoice'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [billing] Duplicate inclusion"
                " of feature https://specs.apollo.dev/federation"
            ),
        ],
    )


def test_v2_0_invalid_link_directive_usage_unknown_element() raises:
    # v2.0 > INVALID_LINK_DIRECTIVE_USAGE: unknown element
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@flexibility"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  users: [User!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown"
                ' element "@flexibility".'
            ),
        ],
    )


def test_v2_0_unknown_federation_link_version() raises:
    # v2.0 > UNKNOWN_FEDERATION_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v6.9", import:'
                    ' ["@key"])\n\ntype Query {\n  words: [String!]!\n}'
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_FEDERATION_LINK_VERSION] [users] Invalid version v6.9"
                " for the federation feature in @link directive on schema"
            ),
        ],
    )


def test_v2_0_unknown_link_version() raises:
    # v2.0 > UNKNOWN_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v6.9")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_LINK_VERSION] [users] Schema uses unknown version"
                " v6.9 of the link spec"
            ),
        ],
    )


def test_v2_0_remove_duplicated_link_spec_definitions() raises:
    # v2.0 > remove duplicated link spec definitions
    check(
        [
            sg(
                "users",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.0",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    " @link(url: String!, as: String, for: link__Purpose,"
                    " import: [link__Import]) repeatable on SCHEMA\n\nscalar"
                    " link__Import\n\nenum link__Purpose {\n  SECURITY\n "
                    " EXECUTION\n}\n\ntype Query {\n  foo: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_non_rfc_3986_url() raises:
    # v2.0 > Non-RFC 3986 url
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires", "@shareable"]) @link(url: "file:///foo/bar",'
                    ' import: ["Bar"])\n\nscalar Bar\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int! @external\n '
                    ' bar: Bar @shareable\n}\n\ntype Invoice @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' [{name: "@key", as: "@renamed"}, "@shareable"])'
                    ' @link(url: "file:///foo/bar", import: ["Bar"])\n\nscalar'
                    " Bar\n\ntype Query {\n  payments: [Payment]\n}\n\ntype"
                    ' Payment @renamed(fields: "id") {\n  id: ID!\n  amount:'
                    " Int!\n  bar: Bar @shareable\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_invalid_link_identifier() raises:
    # v2.1 > INVALID_LINK_IDENTIFIER
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev", import: [{name: "@key", as:'
                    ' "@renamed"}])\n\nextend type Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int! @external\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Invalid @link url"
                " 'https://specs.apollo.dev': expected '/<feature>/vX.Y' (for"
                " example '/federation/v2.9')"
            ),
        ],
    )
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/not-a-version",'
                    ' import: [{name: "@key", as: "@renamed"}])\n\nextend type'
                    ' Payment @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int!'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Expected a version string"
                " (of the form v1.2), got null"
            ),
        ],
    )


def test_v2_1_invalid_link_directive_usage_duplicate_inclusion_of_feature() raises:
    # v2.1 > INVALID_LINK_DIRECTIVE_USAGE: Duplicate inclusion of feature
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!'
                    ' @override(from: "payments") @external\n}\n\ntype Invoice'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [billing] Duplicate inclusion"
                " of feature https://specs.apollo.dev/federation"
            ),
        ],
    )


def test_v2_1_invalid_link_directive_usage_unknown_element() raises:
    # v2.1 > INVALID_LINK_DIRECTIVE_USAGE: unknown element
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@flexibility"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  users: [User!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown"
                ' element "@flexibility".'
            ),
        ],
    )


def test_v2_1_unknown_federation_link_version() raises:
    # v2.1 > UNKNOWN_FEDERATION_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v6.9", import:'
                    ' ["@key"])\n\ntype Query {\n  words: [String!]!\n}'
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_FEDERATION_LINK_VERSION] [users] Invalid version v6.9"
                " for the federation feature in @link directive on schema"
            ),
        ],
    )


def test_v2_1_unknown_link_version() raises:
    # v2.1 > UNKNOWN_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v6.9")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_LINK_VERSION] [users] Schema uses unknown version"
                " v6.9 of the link spec"
            ),
        ],
    )


def test_v2_1_remove_duplicated_link_spec_definitions() raises:
    # v2.1 > remove duplicated link spec definitions
    check(
        [
            sg(
                "users",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.1",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    " @link(url: String!, as: String, for: link__Purpose,"
                    " import: [link__Import]) repeatable on SCHEMA\n\nscalar"
                    " link__Import\n\nenum link__Purpose {\n  SECURITY\n "
                    " EXECUTION\n}\n\ntype Query {\n  foo: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_non_rfc_3986_url() raises:
    # v2.1 > Non-RFC 3986 url
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires", "@shareable"]) @link(url: "file:///foo/bar",'
                    ' import: ["Bar"])\n\nscalar Bar\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int! @external\n '
                    ' bar: Bar @shareable\n}\n\ntype Invoice @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' [{name: "@key", as: "@renamed"}, "@shareable"])'
                    ' @link(url: "file:///foo/bar", import: ["Bar"])\n\nscalar'
                    " Bar\n\ntype Query {\n  payments: [Payment]\n}\n\ntype"
                    ' Payment @renamed(fields: "id") {\n  id: ID!\n  amount:'
                    " Int!\n  bar: Bar @shareable\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_invalid_link_identifier() raises:
    # v2.2 > INVALID_LINK_IDENTIFIER
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev", import: [{name: "@key", as:'
                    ' "@renamed"}])\n\nextend type Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int! @external\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Invalid @link url"
                " 'https://specs.apollo.dev': expected '/<feature>/vX.Y' (for"
                " example '/federation/v2.9')"
            ),
        ],
    )
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/not-a-version",'
                    ' import: [{name: "@key", as: "@renamed"}])\n\nextend type'
                    ' Payment @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int!'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Expected a version string"
                " (of the form v1.2), got null"
            ),
        ],
    )


def test_v2_2_invalid_link_directive_usage_duplicate_inclusion_of_feature() raises:
    # v2.2 > INVALID_LINK_DIRECTIVE_USAGE: Duplicate inclusion of feature
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!'
                    ' @override(from: "payments") @external\n}\n\ntype Invoice'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [billing] Duplicate inclusion"
                " of feature https://specs.apollo.dev/federation"
            ),
        ],
    )


def test_v2_2_invalid_link_directive_usage_unknown_element() raises:
    # v2.2 > INVALID_LINK_DIRECTIVE_USAGE: unknown element
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@flexibility"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  users: [User!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown"
                ' element "@flexibility".'
            ),
        ],
    )


def test_v2_2_unknown_federation_link_version() raises:
    # v2.2 > UNKNOWN_FEDERATION_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v6.9", import:'
                    ' ["@key"])\n\ntype Query {\n  words: [String!]!\n}'
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_FEDERATION_LINK_VERSION] [users] Invalid version v6.9"
                " for the federation feature in @link directive on schema"
            ),
        ],
    )


def test_v2_2_unknown_link_version() raises:
    # v2.2 > UNKNOWN_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v6.9")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_LINK_VERSION] [users] Schema uses unknown version"
                " v6.9 of the link spec"
            ),
        ],
    )


def test_v2_2_remove_duplicated_link_spec_definitions() raises:
    # v2.2 > remove duplicated link spec definitions
    check(
        [
            sg(
                "users",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.2",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    " @link(url: String!, as: String, for: link__Purpose,"
                    " import: [link__Import]) repeatable on SCHEMA\n\nscalar"
                    " link__Import\n\nenum link__Purpose {\n  SECURITY\n "
                    " EXECUTION\n}\n\ntype Query {\n  foo: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_non_rfc_3986_url() raises:
    # v2.2 > Non-RFC 3986 url
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires", "@shareable"]) @link(url: "file:///foo/bar",'
                    ' import: ["Bar"])\n\nscalar Bar\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int! @external\n '
                    ' bar: Bar @shareable\n}\n\ntype Invoice @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' [{name: "@key", as: "@renamed"}, "@shareable"])'
                    ' @link(url: "file:///foo/bar", import: ["Bar"])\n\nscalar'
                    " Bar\n\ntype Query {\n  payments: [Payment]\n}\n\ntype"
                    ' Payment @renamed(fields: "id") {\n  id: ID!\n  amount:'
                    " Int!\n  bar: Bar @shareable\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_invalid_link_identifier() raises:
    # v2.3 > INVALID_LINK_IDENTIFIER
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev", import: [{name: "@key", as:'
                    ' "@renamed"}])\n\nextend type Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int! @external\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Invalid @link url"
                " 'https://specs.apollo.dev': expected '/<feature>/vX.Y' (for"
                " example '/federation/v2.9')"
            ),
        ],
    )
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/not-a-version",'
                    ' import: [{name: "@key", as: "@renamed"}])\n\nextend type'
                    ' Payment @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int!'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Expected a version string"
                " (of the form v1.2), got null"
            ),
        ],
    )


def test_v2_3_invalid_link_directive_usage_duplicate_inclusion_of_feature() raises:
    # v2.3 > INVALID_LINK_DIRECTIVE_USAGE: Duplicate inclusion of feature
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!'
                    ' @override(from: "payments") @external\n}\n\ntype Invoice'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [billing] Duplicate inclusion"
                " of feature https://specs.apollo.dev/federation"
            ),
        ],
    )


def test_v2_3_invalid_link_directive_usage_unknown_element() raises:
    # v2.3 > INVALID_LINK_DIRECTIVE_USAGE: unknown element
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@flexibility"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  users: [User!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown"
                ' element "@flexibility".'
            ),
        ],
    )


def test_v2_3_unknown_federation_link_version() raises:
    # v2.3 > UNKNOWN_FEDERATION_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v6.9", import:'
                    ' ["@key"])\n\ntype Query {\n  words: [String!]!\n}'
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_FEDERATION_LINK_VERSION] [users] Invalid version v6.9"
                " for the federation feature in @link directive on schema"
            ),
        ],
    )


def test_v2_3_unknown_link_version() raises:
    # v2.3 > UNKNOWN_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v6.9")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_LINK_VERSION] [users] Schema uses unknown version"
                " v6.9 of the link spec"
            ),
        ],
    )


def test_v2_3_remove_duplicated_link_spec_definitions() raises:
    # v2.3 > remove duplicated link spec definitions
    check(
        [
            sg(
                "users",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    " @link(url: String!, as: String, for: link__Purpose,"
                    " import: [link__Import]) repeatable on SCHEMA\n\nscalar"
                    " link__Import\n\nenum link__Purpose {\n  SECURITY\n "
                    " EXECUTION\n}\n\ntype Query {\n  foo: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_non_rfc_3986_url() raises:
    # v2.3 > Non-RFC 3986 url
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires", "@shareable"]) @link(url: "file:///foo/bar",'
                    ' import: ["Bar"])\n\nscalar Bar\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int! @external\n '
                    ' bar: Bar @shareable\n}\n\ntype Invoice @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' [{name: "@key", as: "@renamed"}, "@shareable"])'
                    ' @link(url: "file:///foo/bar", import: ["Bar"])\n\nscalar'
                    " Bar\n\ntype Query {\n  payments: [Payment]\n}\n\ntype"
                    ' Payment @renamed(fields: "id") {\n  id: ID!\n  amount:'
                    " Int!\n  bar: Bar @shareable\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_invalid_link_identifier() raises:
    # v2.4 > INVALID_LINK_IDENTIFIER
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev", import: [{name: "@key", as:'
                    ' "@renamed"}])\n\nextend type Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int! @external\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Invalid @link url"
                " 'https://specs.apollo.dev': expected '/<feature>/vX.Y' (for"
                " example '/federation/v2.9')"
            ),
        ],
    )
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/not-a-version",'
                    ' import: [{name: "@key", as: "@renamed"}])\n\nextend type'
                    ' Payment @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int!'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Expected a version string"
                " (of the form v1.2), got null"
            ),
        ],
    )


def test_v2_4_invalid_link_directive_usage_duplicate_inclusion_of_feature() raises:
    # v2.4 > INVALID_LINK_DIRECTIVE_USAGE: Duplicate inclusion of feature
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!'
                    ' @override(from: "payments") @external\n}\n\ntype Invoice'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [billing] Duplicate inclusion"
                " of feature https://specs.apollo.dev/federation"
            ),
        ],
    )


def test_v2_4_invalid_link_directive_usage_unknown_element() raises:
    # v2.4 > INVALID_LINK_DIRECTIVE_USAGE: unknown element
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@flexibility"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  users: [User!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown"
                ' element "@flexibility".'
            ),
        ],
    )


def test_v2_4_unknown_federation_link_version() raises:
    # v2.4 > UNKNOWN_FEDERATION_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v6.9", import:'
                    ' ["@key"])\n\ntype Query {\n  words: [String!]!\n}'
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_FEDERATION_LINK_VERSION] [users] Invalid version v6.9"
                " for the federation feature in @link directive on schema"
            ),
        ],
    )


def test_v2_4_unknown_link_version() raises:
    # v2.4 > UNKNOWN_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v6.9")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_LINK_VERSION] [users] Schema uses unknown version"
                " v6.9 of the link spec"
            ),
        ],
    )


def test_v2_4_remove_duplicated_link_spec_definitions() raises:
    # v2.4 > remove duplicated link spec definitions
    check(
        [
            sg(
                "users",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.4",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    " @link(url: String!, as: String, for: link__Purpose,"
                    " import: [link__Import]) repeatable on SCHEMA\n\nscalar"
                    " link__Import\n\nenum link__Purpose {\n  SECURITY\n "
                    " EXECUTION\n}\n\ntype Query {\n  foo: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_non_rfc_3986_url() raises:
    # v2.4 > Non-RFC 3986 url
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires", "@shareable"]) @link(url: "file:///foo/bar",'
                    ' import: ["Bar"])\n\nscalar Bar\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int! @external\n '
                    ' bar: Bar @shareable\n}\n\ntype Invoice @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' [{name: "@key", as: "@renamed"}, "@shareable"])'
                    ' @link(url: "file:///foo/bar", import: ["Bar"])\n\nscalar'
                    " Bar\n\ntype Query {\n  payments: [Payment]\n}\n\ntype"
                    ' Payment @renamed(fields: "id") {\n  id: ID!\n  amount:'
                    " Int!\n  bar: Bar @shareable\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_invalid_link_identifier() raises:
    # v2.5 > INVALID_LINK_IDENTIFIER
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev", import: [{name: "@key", as:'
                    ' "@renamed"}])\n\nextend type Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int! @external\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Invalid @link url"
                " 'https://specs.apollo.dev': expected '/<feature>/vX.Y' (for"
                " example '/federation/v2.9')"
            ),
        ],
    )
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/not-a-version",'
                    ' import: [{name: "@key", as: "@renamed"}])\n\nextend type'
                    ' Payment @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int!'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Expected a version string"
                " (of the form v1.2), got null"
            ),
        ],
    )


def test_v2_5_invalid_link_directive_usage_duplicate_inclusion_of_feature() raises:
    # v2.5 > INVALID_LINK_DIRECTIVE_USAGE: Duplicate inclusion of feature
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!'
                    ' @override(from: "payments") @external\n}\n\ntype Invoice'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [billing] Duplicate inclusion"
                " of feature https://specs.apollo.dev/federation"
            ),
        ],
    )


def test_v2_5_invalid_link_directive_usage_unknown_element() raises:
    # v2.5 > INVALID_LINK_DIRECTIVE_USAGE: unknown element
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@flexibility"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  users: [User!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown"
                ' element "@flexibility".'
            ),
        ],
    )


def test_v2_5_unknown_federation_link_version() raises:
    # v2.5 > UNKNOWN_FEDERATION_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v6.9", import:'
                    ' ["@key"])\n\ntype Query {\n  words: [String!]!\n}'
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_FEDERATION_LINK_VERSION] [users] Invalid version v6.9"
                " for the federation feature in @link directive on schema"
            ),
        ],
    )


def test_v2_5_unknown_link_version() raises:
    # v2.5 > UNKNOWN_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v6.9")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_LINK_VERSION] [users] Schema uses unknown version"
                " v6.9 of the link spec"
            ),
        ],
    )


def test_v2_5_remove_duplicated_link_spec_definitions() raises:
    # v2.5 > remove duplicated link spec definitions
    check(
        [
            sg(
                "users",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.5",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    " @link(url: String!, as: String, for: link__Purpose,"
                    " import: [link__Import]) repeatable on SCHEMA\n\nscalar"
                    " link__Import\n\nenum link__Purpose {\n  SECURITY\n "
                    " EXECUTION\n}\n\ntype Query {\n  foo: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_non_rfc_3986_url() raises:
    # v2.5 > Non-RFC 3986 url
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires", "@shareable"]) @link(url: "file:///foo/bar",'
                    ' import: ["Bar"])\n\nscalar Bar\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int! @external\n '
                    ' bar: Bar @shareable\n}\n\ntype Invoice @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' [{name: "@key", as: "@renamed"}, "@shareable"])'
                    ' @link(url: "file:///foo/bar", import: ["Bar"])\n\nscalar'
                    " Bar\n\ntype Query {\n  payments: [Payment]\n}\n\ntype"
                    ' Payment @renamed(fields: "id") {\n  id: ID!\n  amount:'
                    " Int!\n  bar: Bar @shareable\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_invalid_link_identifier() raises:
    # v2.6 > INVALID_LINK_IDENTIFIER
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev", import: [{name: "@key", as:'
                    ' "@renamed"}])\n\nextend type Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int! @external\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Invalid @link url"
                " 'https://specs.apollo.dev': expected '/<feature>/vX.Y' (for"
                " example '/federation/v2.9')"
            ),
        ],
    )
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/not-a-version",'
                    ' import: [{name: "@key", as: "@renamed"}])\n\nextend type'
                    ' Payment @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int!'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Expected a version string"
                " (of the form v1.2), got null"
            ),
        ],
    )


def test_v2_6_invalid_link_directive_usage_duplicate_inclusion_of_feature() raises:
    # v2.6 > INVALID_LINK_DIRECTIVE_USAGE: Duplicate inclusion of feature
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!'
                    ' @override(from: "payments") @external\n}\n\ntype Invoice'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [billing] Duplicate inclusion"
                " of feature https://specs.apollo.dev/federation"
            ),
        ],
    )


def test_v2_6_invalid_link_directive_usage_unknown_element() raises:
    # v2.6 > INVALID_LINK_DIRECTIVE_USAGE: unknown element
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@flexibility"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  users: [User!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown"
                ' element "@flexibility".'
            ),
        ],
    )


def test_v2_6_unknown_federation_link_version() raises:
    # v2.6 > UNKNOWN_FEDERATION_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v6.9", import:'
                    ' ["@key"])\n\ntype Query {\n  words: [String!]!\n}'
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_FEDERATION_LINK_VERSION] [users] Invalid version v6.9"
                " for the federation feature in @link directive on schema"
            ),
        ],
    )


def test_v2_6_unknown_link_version() raises:
    # v2.6 > UNKNOWN_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v6.9")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_LINK_VERSION] [users] Schema uses unknown version"
                " v6.9 of the link spec"
            ),
        ],
    )


def test_v2_6_remove_duplicated_link_spec_definitions() raises:
    # v2.6 > remove duplicated link spec definitions
    check(
        [
            sg(
                "users",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.6",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    " @link(url: String!, as: String, for: link__Purpose,"
                    " import: [link__Import]) repeatable on SCHEMA\n\nscalar"
                    " link__Import\n\nenum link__Purpose {\n  SECURITY\n "
                    " EXECUTION\n}\n\ntype Query {\n  foo: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_non_rfc_3986_url() raises:
    # v2.6 > Non-RFC 3986 url
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires", "@shareable"]) @link(url: "file:///foo/bar",'
                    ' import: ["Bar"])\n\nscalar Bar\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int! @external\n '
                    ' bar: Bar @shareable\n}\n\ntype Invoice @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' [{name: "@key", as: "@renamed"}, "@shareable"])'
                    ' @link(url: "file:///foo/bar", import: ["Bar"])\n\nscalar'
                    " Bar\n\ntype Query {\n  payments: [Payment]\n}\n\ntype"
                    ' Payment @renamed(fields: "id") {\n  id: ID!\n  amount:'
                    " Int!\n  bar: Bar @shareable\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_invalid_link_identifier() raises:
    # v2.7 > INVALID_LINK_IDENTIFIER
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev", import: [{name: "@key", as:'
                    ' "@renamed"}])\n\nextend type Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int! @external\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Invalid @link url"
                " 'https://specs.apollo.dev': expected '/<feature>/vX.Y' (for"
                " example '/federation/v2.9')"
            ),
        ],
    )
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/not-a-version",'
                    ' import: [{name: "@key", as: "@renamed"}])\n\nextend type'
                    ' Payment @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int!'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Expected a version string"
                " (of the form v1.2), got null"
            ),
        ],
    )


def test_v2_7_invalid_link_directive_usage_duplicate_inclusion_of_feature() raises:
    # v2.7 > INVALID_LINK_DIRECTIVE_USAGE: Duplicate inclusion of feature
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!'
                    ' @override(from: "payments") @external\n}\n\ntype Invoice'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [billing] Duplicate inclusion"
                " of feature https://specs.apollo.dev/federation"
            ),
        ],
    )


def test_v2_7_invalid_link_directive_usage_unknown_element() raises:
    # v2.7 > INVALID_LINK_DIRECTIVE_USAGE: unknown element
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@flexibility"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  users: [User!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown"
                ' element "@flexibility".'
            ),
        ],
    )


def test_v2_7_unknown_federation_link_version() raises:
    # v2.7 > UNKNOWN_FEDERATION_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v6.9", import:'
                    ' ["@key"])\n\ntype Query {\n  words: [String!]!\n}'
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_FEDERATION_LINK_VERSION] [users] Invalid version v6.9"
                " for the federation feature in @link directive on schema"
            ),
        ],
    )


def test_v2_7_unknown_link_version() raises:
    # v2.7 > UNKNOWN_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v6.9")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_LINK_VERSION] [users] Schema uses unknown version"
                " v6.9 of the link spec"
            ),
        ],
    )


def test_v2_7_remove_duplicated_link_spec_definitions() raises:
    # v2.7 > remove duplicated link spec definitions
    check(
        [
            sg(
                "users",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.7",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    " @link(url: String!, as: String, for: link__Purpose,"
                    " import: [link__Import]) repeatable on SCHEMA\n\nscalar"
                    " link__Import\n\nenum link__Purpose {\n  SECURITY\n "
                    " EXECUTION\n}\n\ntype Query {\n  foo: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_non_rfc_3986_url() raises:
    # v2.7 > Non-RFC 3986 url
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires", "@shareable"]) @link(url: "file:///foo/bar",'
                    ' import: ["Bar"])\n\nscalar Bar\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int! @external\n '
                    ' bar: Bar @shareable\n}\n\ntype Invoice @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' [{name: "@key", as: "@renamed"}, "@shareable"])'
                    ' @link(url: "file:///foo/bar", import: ["Bar"])\n\nscalar'
                    " Bar\n\ntype Query {\n  payments: [Payment]\n}\n\ntype"
                    ' Payment @renamed(fields: "id") {\n  id: ID!\n  amount:'
                    " Int!\n  bar: Bar @shareable\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_invalid_link_identifier() raises:
    # v2.8 > INVALID_LINK_IDENTIFIER
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev", import: [{name: "@key", as:'
                    ' "@renamed"}])\n\nextend type Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int! @external\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Invalid @link url"
                " 'https://specs.apollo.dev': expected '/<feature>/vX.Y' (for"
                " example '/federation/v2.9')"
            ),
        ],
    )
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/not-a-version",'
                    ' import: [{name: "@key", as: "@renamed"}])\n\nextend type'
                    ' Payment @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int!'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Expected a version string"
                " (of the form v1.2), got null"
            ),
        ],
    )


def test_v2_8_invalid_link_directive_usage_duplicate_inclusion_of_feature() raises:
    # v2.8 > INVALID_LINK_DIRECTIVE_USAGE: Duplicate inclusion of feature
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!'
                    ' @override(from: "payments") @external\n}\n\ntype Invoice'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [billing] Duplicate inclusion"
                " of feature https://specs.apollo.dev/federation"
            ),
        ],
    )


def test_v2_8_invalid_link_directive_usage_unknown_element() raises:
    # v2.8 > INVALID_LINK_DIRECTIVE_USAGE: unknown element
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@flexibility"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  users: [User!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown"
                ' element "@flexibility".'
            ),
        ],
    )


def test_v2_8_unknown_federation_link_version() raises:
    # v2.8 > UNKNOWN_FEDERATION_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v6.9", import:'
                    ' ["@key"])\n\ntype Query {\n  words: [String!]!\n}'
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_FEDERATION_LINK_VERSION] [users] Invalid version v6.9"
                " for the federation feature in @link directive on schema"
            ),
        ],
    )


def test_v2_8_unknown_link_version() raises:
    # v2.8 > UNKNOWN_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v6.9")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_LINK_VERSION] [users] Schema uses unknown version"
                " v6.9 of the link spec"
            ),
        ],
    )


def test_v2_8_remove_duplicated_link_spec_definitions() raises:
    # v2.8 > remove duplicated link spec definitions
    check(
        [
            sg(
                "users",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.8",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    " @link(url: String!, as: String, for: link__Purpose,"
                    " import: [link__Import]) repeatable on SCHEMA\n\nscalar"
                    " link__Import\n\nenum link__Purpose {\n  SECURITY\n "
                    " EXECUTION\n}\n\ntype Query {\n  foo: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_non_rfc_3986_url() raises:
    # v2.8 > Non-RFC 3986 url
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires", "@shareable"]) @link(url: "file:///foo/bar",'
                    ' import: ["Bar"])\n\nscalar Bar\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int! @external\n '
                    ' bar: Bar @shareable\n}\n\ntype Invoice @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' [{name: "@key", as: "@renamed"}, "@shareable"])'
                    ' @link(url: "file:///foo/bar", import: ["Bar"])\n\nscalar'
                    " Bar\n\ntype Query {\n  payments: [Payment]\n}\n\ntype"
                    ' Payment @renamed(fields: "id") {\n  id: ID!\n  amount:'
                    " Int!\n  bar: Bar @shareable\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_invalid_link_identifier() raises:
    # v2.9 > INVALID_LINK_IDENTIFIER
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev", import: [{name: "@key", as:'
                    ' "@renamed"}])\n\nextend type Payment @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int! @external\n}\n\ntype Invoice"
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Invalid @link url"
                " 'https://specs.apollo.dev': expected '/<feature>/vX.Y' (for"
                " example '/federation/v2.9')"
            ),
        ],
    )
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/not-a-version",'
                    ' import: [{name: "@key", as: "@renamed"}])\n\nextend type'
                    ' Payment @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int!'
                    ' @external\n}\n\ntype Invoice @key(fields: "id") {\n  id:'
                    " ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_IDENTIFIER] [billing] Expected a version string"
                " (of the form v1.2), got null"
            ),
        ],
    )


def test_v2_9_invalid_link_directive_usage_duplicate_inclusion_of_feature() raises:
    # v2.9 > INVALID_LINK_DIRECTIVE_USAGE: Duplicate inclusion of feature
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@override", "@external", "@provides"]) @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!'
                    ' @override(from: "payments") @external\n}\n\ntype Invoice'
                    ' @key(fields: "id") {\n  id: ID!\n  amount: Int!\n '
                    " payment: Payment @provides(fields: true)\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' [{name: "@key", as: "@renamed"}])\n\ntype Query {\n '
                    " payments: [Payment]\n}\n\ntype Payment @renamed(fields:"
                    ' "id") {\n  id: ID!\n  amount: Int!\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [billing] Duplicate inclusion"
                " of feature https://specs.apollo.dev/federation"
            ),
        ],
    )


def test_v2_9_invalid_link_directive_usage_unknown_element() raises:
    # v2.9 > INVALID_LINK_DIRECTIVE_USAGE: unknown element
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@flexibility"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  users: [User!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown"
                ' element "@flexibility".'
            ),
        ],
    )


def test_v2_9_unknown_federation_link_version() raises:
    # v2.9 > UNKNOWN_FEDERATION_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v6.9", import:'
                    ' ["@key"])\n\ntype Query {\n  words: [String!]!\n}'
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_FEDERATION_LINK_VERSION] [users] Invalid version v6.9"
                " for the federation feature in @link directive on schema"
            ),
        ],
    )


def test_v2_9_unknown_link_version() raises:
    # v2.9 > UNKNOWN_LINK_VERSION
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v6.9")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[UNKNOWN_LINK_VERSION] [users] Schema uses unknown version"
                " v6.9 of the link spec"
            ),
        ],
    )


def test_v2_9_remove_duplicated_link_spec_definitions() raises:
    # v2.9 > remove duplicated link spec definitions
    check(
        [
            sg(
                "users",
                (
                    'schema @link(url: "https://specs.apollo.dev/link/v1.0")'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.9",'
                    ' import: ["@shareable"]) {\n  query: Query\n}\n\ndirective'
                    " @link(url: String!, as: String, for: link__Purpose,"
                    " import: [link__Import]) repeatable on SCHEMA\n\nscalar"
                    " link__Import\n\nenum link__Purpose {\n  SECURITY\n "
                    " EXECUTION\n}\n\ntype Query {\n  foo: String\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_non_rfc_3986_url() raises:
    # v2.9 > Non-RFC 3986 url
    check(
        [
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@override", "@external", "@provides", "@key",'
                    ' "@requires", "@shareable"]) @link(url: "file:///foo/bar",'
                    ' import: ["Bar"])\n\nscalar Bar\n\nextend type Payment'
                    ' @key(fields: "id") {\n  id: ID!\n  tax: Int!'
                    ' @requires(fields: "amount")\n  amount: Int! @external\n '
                    ' bar: Bar @shareable\n}\n\ntype Invoice @key(fields: "id")'
                    " {\n  id: ID!\n  amount: Int!\n  payment: Payment\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' [{name: "@key", as: "@renamed"}, "@shareable"])'
                    ' @link(url: "file:///foo/bar", import: ["Bar"])\n\nscalar'
                    " Bar\n\ntype Query {\n  payments: [Payment]\n}\n\ntype"
                    ' Payment @renamed(fields: "id") {\n  id: ID!\n  amount:'
                    " Int!\n  bar: Bar @shareable\n}"
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
