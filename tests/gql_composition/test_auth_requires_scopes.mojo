# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/auth/requires-scopes.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_requiresscopes_forbidden_on_interface_type() raises:
    # @requiresScopes > forbidden on interface type
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ninterface Node'
                    ' @requiresScopes(scopes: [["a"]]) {\n  id: ID!\n}\n\ntype'
                    ' User implements Node @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  node(id: ID!): Node\n}"
                ),
            ),
        ],
        [
            (
                "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of"
                ' @requiresScopes on interface "Node": @requiresScopes cannot'
                " be applied on interfaces, interface fields and interface"
                " objects"
            ),
        ],
    )


def test_requiresscopes_forbidden_on_interface_field() raises:
    # @requiresScopes > forbidden on interface field
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ninterface Node {\n  id:'
                    ' ID! @requiresScopes(scopes: [["a"]])\n}\n\ntype User'
                    ' implements Node @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  node(id: ID!): Node\n}"
                ),
            ),
        ],
        [
            (
                "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of"
                ' @requiresScopes on field "Node.id": @requiresScopes cannot be'
                " applied on interfaces, interface fields and interface objects"
            ),
        ],
    )


def test_requiresscopes_forbidden_on_interfaceobject() raises:
    # @requiresScopes > forbidden on interfaceObject
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key", "@interfaceObject"])\n\ntype'
                    ' User @key(fields: "id") @interfaceObject'
                    ' @requiresScopes(scopes: [["a"]]) {\n  id: ID!\n  name:'
                    " String!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ninterface User'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Authenticated'
                    ' implements User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  User(id: ID!): User\n}"
                ),
            ),
        ],
        [
            (
                "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of"
                ' @requiresScopes on interface object "User": @requiresScopes'
                " cannot be applied on interfaces, interface fields and"
                " interface objects"
            ),
        ],
    )


def test_requiresscopes_allowed_on_interfaceobject_field() raises:
    # @requiresScopes > allowed on interfaceObject field
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key", "@interfaceObject",'
                    ' "@shareable"])\n\ntype User @key(fields: "id")'
                    " @interfaceObject {\n  id: ID!\n  name: String"
                    ' @requiresScopes(scopes: [["a"]]) @shareable\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key", "@shareable"])\n\ninterface'
                    ' User @key(fields: "id") {\n  id: ID!\n}\n\ntype'
                    ' Authenticated implements User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Temorary implements User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String'
                    ' @requiresScopes(scopes: [["c"]]) @shareable\n}\n\ntype'
                    " Query {\n  user(id: ID!): User\n}"
                ),
            ),
        ],
        [],
    )


def test_requiresscopes_allowed_on_interfaceobject_field_that_belongs_to_interface() raises:
    # @requiresScopes > allowed on interfaceObject field that belongs to interface
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key", "@interfaceObject"])\n\ntype'
                    ' User @key(fields: "id") @interfaceObject {\n  id: ID!'
                    ' @requiresScopes(scopes: [["a"]])\n  name: String\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ninterface User'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Authenticated'
                    ' implements User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  user(id: ID!): User\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key", "@interfaceObject"])\n\ntype'
                    ' User @key(fields: "id") @interfaceObject {\n  id: ID!'
                    ' @requiresScopes(scopes: [["c"]])\n}'
                ),
            ),
        ],
        [],
    )


def test_requiresscopes_forbidden_on_input_object_type() raises:
    # @requiresScopes > forbidden on input object type
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ninput UserInput'
                    ' @requiresScopes(scopes: [["a"]]) {\n  id: ID!\n}\n\ntype'
                    " Query {\n  user(input: UserInput): String\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@requiresScopes" may not be'
                " used on INPUT_OBJECT."
            ),
        ],
    )


def test_requiresscopes_forbidden_on_union_type() raises:
    # @requiresScopes > forbidden on union type
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\nunion Result'
                    ' @requiresScopes(scopes: [["a"]]) = User | Error\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n}\n\ntype Error {\n'
                    "  message: String\n}\n\ntype Query {\n  result: Result\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@requiresScopes" may not be'
                " used on UNION."
            ),
        ],
    )


def test_requiresscopes_allowed_on_scalar() raises:
    # @requiresScopes > allowed on scalar
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes"])\n\nscalar JSON'
                    ' @requiresScopes(scopes: [["a"]])\n\ntype Query {\n  json:'
                    " JSON\n}"
                ),
            ),
        ],
        [],
    )


def test_requiresscopes_allowed_on_enum() raises:
    # @requiresScopes > allowed on enum
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes"])\n\nenum Role @requiresScopes(scopes:'
                    ' [["a"]]) {\n  ADMIN\n}\n\ntype Query {\n  role: Role\n}'
                ),
            ),
        ],
        [],
    )


def test_requiresscopes_passed_from_object_types_implementing_the_interface_to_interface() raises:
    # @requiresScopes > passed from object types implementing the interface to interface type
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ninterface Node {\n  id:'
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    ' @requiresScopes(scopes: [["a"]]) {\n  id: ID!\n}\n\ntype'
                    ' Post implements Node @key(fields: "id")'
                    ' @requiresScopes(scopes: [["b"]]) {\n  id: ID!\n}\n\ntype'
                    " Query {\n  node: Node\n}"
                ),
            ),
        ],
        [],
    )


def test_requiresscopes_passed_from_object_fields_implementing_the_interface_to_interface() raises:
    # @requiresScopes > passed from object fields implementing the interface to interface field
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ninterface Node {\n  id:'
                    " ID!\n  name: String\n}\n\ntype User implements Node"
                    ' @key(fields: "id") @requiresScopes(scopes: [["a"]]) {\n '
                    " id: ID!\n  name: String @requiresScopes(scopes:"
                    ' [["a"]])\n}\n\ntype Post implements Node @key(fields:'
                    ' "id") {\n  id: ID!\n  name: String'
                    ' @requiresScopes(scopes: [["b"]])\n}\n\ntype Query {\n '
                    " node: Node\n}"
                ),
            ),
        ],
        [],
    )


def test_requiresscopes_many_object_type_instances_of_the_same_name_across_subgraphs() raises:
    # @requiresScopes > many object type instances of the same name across subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ntype User @key(fields:'
                    ' "id") @requiresScopes(scopes: [["a"]]) {\n  id:'
                    " ID!\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ntype User @key(fields:'
                    ' "id") @requiresScopes(scopes: [["b"]]) {\n  id: ID!\n '
                    " name: String\n}"
                ),
            ),
        ],
        [],
    )


def test_requiresscopes_many_object_fields_instances_of_the_same_name_across_subgraphs() raises:
    # @requiresScopes > many object fields instances of the same name across subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key", "@shareable"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    ' @requiresScopes(scopes: [["a"]]) @shareable\n}\n\ntype'
                    " Query {\n  user: User\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key", "@shareable"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    ' @requiresScopes(scopes: [["b"]]) @shareable\n  age:'
                    " Int\n}"
                ),
            ),
        ],
        [],
    )


def test_requiresscopes_deduplicated_and_dropped_redundant_scopes() raises:
    # @requiresScopes > deduplicated and dropped redundant scopes
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ntype User @key(fields:'
                    ' "id") @requiresScopes(scopes: [["user:read",'
                    ' "user:email:read"], ["admin"]]) {\n  id: ID!\n}\n\ntype'
                    " Query {\n  user: User\n}"
                ),
            ),
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ntype User @key(fields:'
                    ' "id") @requiresScopes(scopes: [["user:read",'
                    ' "billing:read"], ["admin", "billing:invoice:read"],'
                    ' ["support:user:read"]]) {\n  id: ID!\n}'
                ),
            ),
        ],
        [],
    )


def test_requiresscopes_requires_missing_access_to_referenced_interface_field() raises:
    # @requiresScopes > @requires missing access to referenced interface field
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Query {\n '
                    ' user: User\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID\n  comment: Node @external\n  hasComment: Boolean"
                    ' @requires(fields: "comment { id }")\n}\n\ninterface Node'
                    " {\n  id: ID!\n}\n\ntype Comment implements Node @external"
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ntype User @key(fields:'
                    ' "id") {\n  id: ID!\n  comment: Node\n}\n\ninterface Node'
                    " {\n  id: ID!\n}\n\ntype Comment implements Node {\n  id:"
                    ' ID! @requiresScopes(scopes: [["comment"]])\n}'
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [a] Field"
                ' "User.hasComment" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to access"
                ' the transitive field "Node.id" data from @requires selection'
                " set."
            ),
        ],
    )


def test_requiresscopes_requires_has_access_to_referenced_interface_field() raises:
    # @requiresScopes > @requires has access to referenced interface field
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires",'
                    ' "@requiresScopes"])\n\ntype Query {\n  user:'
                    ' User\n}\n\ntype User @key(fields: "id")'
                    ' @requiresScopes(scopes: [["user"]]) {\n  id: ID\n '
                    " comment: Node @external\n  hasComment: Boolean"
                    ' @requires(fields: "comment { id }")'
                    ' @requiresScopes(scopes: [["comment"]])\n}\n\ninterface'
                    " Node {\n  id: ID!\n}\n\ntype Comment implements Node"
                    " @external {\n  id: ID!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ntype User @key(fields:'
                    ' "id") {\n  id: ID!\n  comment: Node\n}\n\ninterface Node'
                    " {\n  id: ID!\n}\n\ntype Comment implements Node {\n  id:"
                    ' ID! @requiresScopes(scopes: [["comment", "user"]])\n}'
                ),
            ),
        ],
        [],
    )


def test_requiresscopes_requires_missing_access_to_referenced_interface_type() raises:
    # @requiresScopes > @requires missing access to referenced interface type
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype Query {\n '
                    ' account: Account\n}\n\ntype Account @key(fields: "id")'
                    " {\n  id: ID\n  details: AccountDetail @external\n "
                    ' detailsSummary: String @requires(fields: "details { ...'
                    " on ScopedAccountDetail { sensitiveLevel } ... on"
                    " PublicAccountDetail { publicNote } ... on"
                    ' AdminAccountDetail { adminLevel } }")\n}\n\ninterface'
                    " AccountDetail {\n  summary: String\n}\n\ntype"
                    " ScopedAccountDetail implements AccountDetail @external"
                    " {\n  summary: String\n  sensitiveLevel: Int\n}\n\ntype"
                    " PublicAccountDetail implements AccountDetail @external"
                    " {\n  summary: String\n  publicNote: String\n}\n\ntype"
                    " AdminAccountDetail implements AccountDetail @external {\n"
                    "  summary: String\n  adminLevel: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ntype Account @key(fields:'
                    ' "id") {\n  id: ID\n  details:'
                    " AccountDetail\n}\n\ninterface AccountDetail {\n  summary:"
                    " String\n}\n\ntype ScopedAccountDetail implements"
                    ' AccountDetail @requiresScopes(scopes: [["missing"]]) {\n '
                    " summary: String\n  sensitiveLevel: Int\n}\n\ntype"
                    " PublicAccountDetail implements AccountDetail {\n "
                    " summary: String\n  publicNote: String\n}\n\ntype"
                    " AdminAccountDetail implements AccountDetail"
                    ' @requiresScopes(scopes: [["missing"]]) {\n  summary:'
                    " String\n  adminLevel: Int\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [a] Field"
                ' "Account.detailsSummary" does not specify necessary'
                " @authenticated, @requiresScopes and/or @policy auth"
                ' requirements to access the transitive field "Account.details"'
                " data from @requires selection set."
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires",'
                    ' "@requiresScopes"])\n\ntype Query {\n  account:'
                    ' Account\n}\n\ntype Account @key(fields: "id")'
                    ' @requiresScopes(scopes: [["account"]]) {\n  id: ID\n '
                    " details: AccountDetail @external\n  detailsSummary:"
                    ' String @requires(fields: "details { summary ... on'
                    " ScopedAccountDetail { sensitiveLevel } ... on"
                    " PublicAccountDetail { publicNote } ... on"
                    ' AdminAccountDetail { adminLevel } }")'
                    ' @requiresScopes(scopes: [["scoped:summary",'
                    ' "scoped:level"]])\n}\n\ninterface AccountDetail {\n '
                    " summary: String\n}\n\ntype ScopedAccountDetail implements"
                    " AccountDetail @external {\n  summary: String\n "
                    " sensitiveLevel: Int\n}\n\ntype PublicAccountDetail"
                    " implements AccountDetail @external {\n  summary: String\n"
                    "  publicNote: String\n}\n\ntype AdminAccountDetail"
                    " implements AccountDetail @external {\n  summary: String\n"
                    "  adminLevel: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ntype Account @key(fields:'
                    ' "id") {\n  id: ID\n  details: AccountDetail'
                    " @requiresScopes(scopes:"
                    ' [["account:details"]])\n}\n\ninterface AccountDetail {\n '
                    " summary: String\n}\n\ntype ScopedAccountDetail implements"
                    " AccountDetail {\n  summary: String"
                    ' @requiresScopes(scopes: [["scoped:summary"]])\n '
                    " sensitiveLevel: Int @requiresScopes(scopes:"
                    ' [["scoped:level"]])\n}\n\ntype PublicAccountDetail'
                    " implements AccountDetail {\n  summary: String\n "
                    " publicNote: String @requiresScopes(scopes:"
                    ' [["public:note"]])\n}\n\ntype AdminAccountDetail'
                    " implements AccountDetail {\n  summary: String"
                    ' @requiresScopes(scopes: [["admin:summary"]])\n '
                    " adminLevel: Int @requiresScopes(scopes:"
                    ' [["admin:level"]])\n}'
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [a] Field"
                ' "Account.detailsSummary" does not specify necessary'
                " @authenticated, @requiresScopes and/or @policy auth"
                ' requirements to access the transitive field "Account.details"'
                " data from @requires selection set."
            ),
        ],
    )


def test_requiresscopes_requires_has_access_to_referenced_interface_type() raises:
    # @requiresScopes > @requires has access to referenced interface type
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires",'
                    ' "@requiresScopes"])\n\ntype Query {\n  account:'
                    ' Account\n}\n\ntype Account @key(fields: "id")'
                    ' @requiresScopes(scopes: [["account:details"]]) {\n  id:'
                    " ID\n  details: AccountDetail @external\n  detailsSummary:"
                    ' String @requires(fields: "details { summary ... on'
                    " ScopedAccountDetail { sensitiveLevel } ... on"
                    " PublicAccountDetail { publicNote } ... on"
                    ' AdminAccountDetail { adminLevel } }")'
                    ' @requiresScopes(scopes: [["scoped:summary",'
                    ' "admin:summary", "scoped:level", "public:note",'
                    ' "admin:level"]])\n}\n\ninterface AccountDetail {\n '
                    " summary: String\n}\n\ntype ScopedAccountDetail implements"
                    " AccountDetail @external {\n  summary: String\n "
                    " sensitiveLevel: Int\n}\n\ntype PublicAccountDetail"
                    " implements AccountDetail @external {\n  summary: String\n"
                    "  publicNote: String\n}\n\ntype AdminAccountDetail"
                    " implements AccountDetail @external {\n  summary: String\n"
                    "  adminLevel: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@requiresScopes", "@key"])\n\ntype Account @key(fields:'
                    ' "id") {\n  id: ID\n  details: AccountDetail'
                    " @requiresScopes(scopes:"
                    ' [["account:details"]])\n}\n\ninterface AccountDetail {\n '
                    " summary: String\n}\n\ntype ScopedAccountDetail implements"
                    " AccountDetail {\n  summary: String"
                    ' @requiresScopes(scopes: [["scoped:summary"]])\n '
                    " sensitiveLevel: Int @requiresScopes(scopes:"
                    ' [["scoped:level"]])\n}\n\ntype PublicAccountDetail'
                    " implements AccountDetail {\n  summary: String\n "
                    " publicNote: String @requiresScopes(scopes:"
                    ' [["public:note"]])\n}\n\ntype AdminAccountDetail'
                    " implements AccountDetail {\n  summary: String"
                    ' @requiresScopes(scopes: [["admin:summary"]])\n '
                    " adminLevel: Int @requiresScopes(scopes:"
                    ' [["admin:level"]])\n}'
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
