# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/auth/authenticated.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_authenticated_forbidden_on_interface_type() raises:
    # @authenticated > forbidden on interface type
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\ninterface Node'
                    " @authenticated {\n  id: ID!\n}\n\ntype User implements"
                    ' Node @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n'
                    "  node(id: ID!): Node\n}"
                ),
            ),
        ],
        [
            (
                "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of"
                ' @authenticated on interface "Node": @authenticated cannot be'
                " applied on interfaces, interface fields and interface objects"
            ),
        ],
    )


def test_authenticated_forbidden_on_interface_field() raises:
    # @authenticated > forbidden on interface field
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\ninterface Node {\n  id:'
                    " ID! @authenticated\n}\n\ntype User implements Node"
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n '
                    " node(id: ID!): Node\n}"
                ),
            ),
        ],
        [
            (
                "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of"
                ' @authenticated on field "Node.id": @authenticated cannot be'
                " applied on interfaces, interface fields and interface objects"
            ),
        ],
    )


def test_authenticated_forbidden_on_interfaceobject() raises:
    # @authenticated > forbidden on interfaceObject
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key", "@interfaceObject"])\n\ntype'
                    ' User @key(fields: "id") @interfaceObject @authenticated'
                    " {\n  id: ID!\n  name: String!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\ninterface User'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Authenticated'
                    ' implements User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  User(id: ID!): User\n}"
                ),
            ),
        ],
        [
            (
                "[AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE] [a] Invalid use of"
                ' @authenticated on interface object "User": @authenticated'
                " cannot be applied on interfaces, interface fields and"
                " interface objects"
            ),
        ],
    )


def test_authenticated_allowed_on_interfaceobject_field() raises:
    # @authenticated > allowed on interfaceObject field
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key", "@interfaceObject",'
                    ' "@shareable"])\n\ntype User @key(fields: "id")'
                    " @interfaceObject {\n  id: ID!\n  name: String"
                    " @authenticated @shareable\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key", "@shareable"])\n\ninterface'
                    ' User @key(fields: "id") {\n  id: ID!\n}\n\ntype'
                    ' Authenticated implements User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Temorary implements User @key(fields:"
                    ' "id") {\n  id: ID!\n  name: String @authenticated'
                    " @shareable\n}\n\ntype Query {\n  user(id: ID!): User\n}"
                ),
            ),
        ],
        [],
    )


def test_authenticated_allowed_on_interfaceobject_field_that_belongs_to_interface() raises:
    # @authenticated > allowed on interfaceObject field that belongs to interface
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key", "@interfaceObject"])\n\ntype'
                    ' User @key(fields: "id") @interfaceObject {\n  id: ID!'
                    " @authenticated\n  name: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\ninterface User'
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
                    ' ["@authenticated", "@key", "@interfaceObject"])\n\ntype'
                    ' User @key(fields: "id") @interfaceObject {\n  id: ID!'
                    " @authenticated\n}"
                ),
            ),
        ],
        [],
    )


def test_authenticated_forbidden_on_input_object_type() raises:
    # @authenticated > forbidden on input object type
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\ninput UserInput'
                    " @authenticated {\n  id: ID!\n}\n\ntype Query {\n "
                    " user(input: UserInput): String\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@authenticated" may not be'
                " used on INPUT_OBJECT."
            ),
        ],
    )


def test_authenticated_forbidden_on_union_type() raises:
    # @authenticated > forbidden on union type
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\nunion Result'
                    " @authenticated = User | Error\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID!\n}\n\ntype Error {\n  message:'
                    " String\n}\n\ntype Query {\n  result: Result\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@authenticated" may not be'
                " used on UNION."
            ),
        ],
    )


def test_authenticated_allowed_on_scalar() raises:
    # @authenticated > allowed on scalar
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated"])\n\nscalar JSON @authenticated\n\ntype'
                    " Query {\n  json: JSON\n}"
                ),
            ),
        ],
        [],
    )


def test_authenticated_allowed_on_enum() raises:
    # @authenticated > allowed on enum
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated"])\n\nenum Role @authenticated {\n '
                    " ADMIN\n}\n\ntype Query {\n  role: Role\n}"
                ),
            ),
        ],
        [],
    )


def test_authenticated_passed_from_object_types_implementing_the_interface_to_interface_t() raises:
    # @authenticated > passed from object types implementing the interface to interface type
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\ninterface Node {\n  id:'
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " @authenticated {\n  id: ID!\n}\n\ntype Post implements"
                    ' Node @key(fields: "id") @authenticated {\n  id:'
                    " ID!\n}\n\ntype Query {\n  node: Node\n}"
                ),
            ),
        ],
        [],
    )


def test_authenticated_passed_from_object_fields_implementing_the_interface_to_interface() raises:
    # @authenticated > passed from object fields implementing the interface to interface field
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\ninterface Node {\n  id:'
                    " ID!\n  name: String\n}\n\ntype User implements Node"
                    ' @key(fields: "id") @authenticated {\n  id: ID!\n  name:'
                    " String @authenticated\n}\n\ntype Post implements Node"
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @authenticated\n}\n\ntype Query {\n  node: Node\n}"
                ),
            ),
        ],
        [],
    )


def test_authenticated_many_object_type_instances_of_the_same_name_across_subgraphs() raises:
    # @authenticated > many object type instances of the same name across subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\ntype User @key(fields:'
                    ' "id") @authenticated {\n  id: ID!\n}\n\ntype Query {\n '
                    " user: User\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\ntype User @key(fields:'
                    ' "id") @authenticated {\n  id: ID!\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_authenticated_many_object_fields_instances_of_the_same_name_across_subgraphs() raises:
    # @authenticated > many object fields instances of the same name across subgraphs
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key", "@shareable"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @authenticated @shareable\n}\n\ntype Query {\n  user:"
                    " User\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key", "@shareable"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String'
                    " @authenticated @shareable\n  age: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_authenticated_deduplicated_and_dropped_redundant_scopes() raises:
    # @authenticated > deduplicated and dropped redundant scopes
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\ntype User @key(fields:'
                    ' "id") @authenticated {\n  id: ID!\n}\n\ntype Query {\n '
                    " user: User\n}"
                ),
            ),
            sg(
                "billing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\ntype User @key(fields:'
                    ' "id") @authenticated {\n  id: ID!\n}'
                ),
            ),
        ],
        [],
    )


def test_authenticated_requires_missing_access_to_referenced_interface_field() raises:
    # @authenticated > @requires missing access to referenced interface field
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
                    ' ["@authenticated", "@key"])\n\ntype User @key(fields:'
                    ' "id") {\n  id: ID!\n  comment: Node\n}\n\ninterface Node'
                    " {\n  id: ID!\n}\n\ntype Comment implements Node {\n  id:"
                    " ID! @authenticated\n}"
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


def test_authenticated_requires_untyped_inline_fragment() raises:
    # Upstream `composeServices` throws in its satisfiability rule first
    # ("Inline fragment without type condition is not supported."), and
    # `validate_subgraphs` does not run that rule. `AuthOnRequiresRule` reads
    # an inline fragment without a type condition as the current type, so
    # the result is that of `comment { id }` above.
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
                    ' @requires(fields: "comment { ... { id } }")\n}\n\n'
                    "interface Node {\n  id: ID!\n}\n\ntype Comment implements"
                    " Node @external {\n  id: ID!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\ntype User @key(fields:'
                    ' "id") {\n  id: ID!\n  comment: Node\n}\n\ninterface Node'
                    " {\n  id: ID!\n}\n\ntype Comment implements Node {\n  id:"
                    " ID! @authenticated\n}"
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


def test_authenticated_requires_has_access_to_referenced_interface_field() raises:
    # @authenticated > @requires has access to referenced interface field
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires",'
                    ' "@authenticated"])\n\ntype Query {\n  user:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " comment: Node @external\n  hasComment: Boolean"
                    ' @requires(fields: "comment { id }")'
                    " @authenticated\n}\n\ninterface Node {\n  id:"
                    " ID!\n}\n\ntype Comment implements Node @external {\n  id:"
                    " ID!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\ntype User @key(fields:'
                    ' "id") {\n  id: ID!\n  comment: Node\n}\n\ninterface Node'
                    " {\n  id: ID!\n}\n\ntype Comment implements Node {\n  id:"
                    " ID! @authenticated\n}"
                ),
            ),
        ],
        [],
    )


def test_authenticated_requires_missing_access_to_referenced_interface_type() raises:
    # @authenticated > @requires missing access to referenced interface type
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
                    ' ["@authenticated", "@key"])\n\ntype Account @key(fields:'
                    ' "id") {\n  id: ID\n  details:'
                    " AccountDetail\n}\n\ninterface AccountDetail {\n  summary:"
                    " String\n}\n\ntype ScopedAccountDetail implements"
                    " AccountDetail @authenticated {\n  summary: String\n "
                    " sensitiveLevel: Int\n}\n\ntype PublicAccountDetail"
                    " implements AccountDetail {\n  summary: String\n "
                    " publicNote: String\n}\n\ntype AdminAccountDetail"
                    " implements AccountDetail @authenticated {\n  summary:"
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


def test_authenticated_requires_has_access_to_referenced_interface_type_auth_on_type() raises:
    # @authenticated > @requires has access to referenced interface type (auth on type)
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires",'
                    ' "@authenticated"])\n\ntype Query {\n  account:'
                    ' Account\n}\n\ntype Account @key(fields: "id")'
                    " @authenticated {\n  id: ID\n  details: AccountDetail"
                    " @external\n  detailsSummary: String @requires(fields:"
                    ' "details { summary ... on ScopedAccountDetail {'
                    " sensitiveLevel } ... on PublicAccountDetail { publicNote"
                    " } ... on AdminAccountDetail { adminLevel }"
                    ' }")\n}\n\ninterface AccountDetail {\n  summary:'
                    " String\n}\n\ntype ScopedAccountDetail implements"
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
                    ' ["@authenticated", "@key"])\n\ntype Account @key(fields:'
                    ' "id") {\n  id: ID\n  details: AccountDetail'
                    " @authenticated\n}\n\ninterface AccountDetail {\n "
                    " summary: String\n}\n\ntype ScopedAccountDetail implements"
                    " AccountDetail {\n  summary: String @authenticated\n "
                    " sensitiveLevel: Int @authenticated\n}\n\ntype"
                    " PublicAccountDetail implements AccountDetail {\n "
                    " summary: String\n  publicNote: String"
                    " @authenticated\n}\n\ntype AdminAccountDetail implements"
                    " AccountDetail {\n  summary: String @authenticated\n "
                    " adminLevel: Int @authenticated\n}"
                ),
            ),
        ],
        [],
    )


def test_authenticated_requires_has_access_to_referenced_interface_type() raises:
    # @authenticated > @requires has access to referenced interface type
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@external", "@requires",'
                    ' "@authenticated"])\n\ntype Query {\n  account:'
                    ' Account\n}\n\ntype Account @key(fields: "id") {\n  id:'
                    " ID\n  details: AccountDetail @external\n  detailsSummary:"
                    ' String @requires(fields: "details { summary ... on'
                    " ScopedAccountDetail { sensitiveLevel } ... on"
                    " PublicAccountDetail { publicNote } ... on"
                    ' AdminAccountDetail { adminLevel } }")'
                    " @authenticated\n}\n\ninterface AccountDetail {\n "
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
                    ' ["@authenticated", "@key"])\n\ntype Account @key(fields:'
                    ' "id") {\n  id: ID\n  details: AccountDetail'
                    " @authenticated\n}\n\ninterface AccountDetail {\n "
                    " summary: String\n}\n\ntype ScopedAccountDetail implements"
                    " AccountDetail {\n  summary: String @authenticated\n "
                    " sensitiveLevel: Int @authenticated\n}\n\ntype"
                    " PublicAccountDetail implements AccountDetail {\n "
                    " summary: String\n  publicNote: String"
                    " @authenticated\n}\n\ntype AdminAccountDetail implements"
                    " AccountDetail {\n  summary: String @authenticated\n "
                    " adminLevel: Int @authenticated\n}"
                ),
            ),
        ],
        [],
    )


def test_hive_case_ar1_nested() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { user: User'
                    ' }\ntype User @key(fields: "id") { id: ID comment: Node'
                    " @external hasComment: Boolean @requires(fields:"
                    ' "comment { ... on Comment { id } }") }\ninterface Node {'
                    " id: ID! }\ntype Comment implements Node @external { id:"
                    " ID! }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype User @key(fields:'
                    ' "id") { id: ID! comment: Node }\ninterface Node { id:'
                    " ID! }\ntype Comment implements Node { id: ID!"
                    " @authenticated }"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [a] Field"
                ' "User.hasComment" does not specify necessary'
                " @authenticated, @requiresScopes and/or @policy auth"
                " requirements to access the transitive field"
                ' "Comment.id" data from @requires selection set.'
            ),
        ],
    )


def test_hive_case_ar2_context() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { u: User'
                    ' }\ntype User @key(fields: "id") @context(name:'
                    ' "userCtx") @authenticated { id: ID! name: String!'
                    ' child: Child! }\ntype Child @key(fields: "id") { id: ID!'
                    ' greet(n: String @fromContext(field: "$userCtx { name'
                    ' }")): String }'
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [a] Field"
                ' "Child.greet" does not specify necessary'
                " @authenticated, @requiresScopes and/or @policy auth"
                " requirements to access the transitive data in context"
                " a__userCtx from @fromContext selection set."
            ),
        ],
    )


def test_hive_case_ar3_union_typename() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { user: User'
                    ' }\ntype User @key(fields: "id") { id: ID r: R @external'
                    ' hasR: Boolean @requires(fields: "r { __typename }")'
                    " }\nunion R = X | Y\ntype Y @shareable { y: Int }\ntype X"
                    " @shareable { x: Int }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype User @key(fields:'
                    ' "id") { id: ID! r: R }\nunion R = X | Y\ntype Y'
                    " @shareable { y: Int }\ntype X @shareable @authenticated"
                    " { x: Int }"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [a] Field"
                ' "User.hasR" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to"
                ' access the transitive type "X" data from @requires'
                " selection set."
            ),
        ],
    )


def test_hive_case_ar4_union_fragment() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { user: User'
                    ' }\ntype User @key(fields: "id") { id: ID r: R @external'
                    ' hasR: Boolean @requires(fields: "r { ... on X { x } }")'
                    " }\nunion R = X | Y\ntype Y @shareable { y: Int }\ntype X"
                    " @shareable { x: Int }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype User @key(fields:'
                    ' "id") { id: ID! r: R }\nunion R = X | Y\ntype Y'
                    " @shareable { y: Int }\ntype X @shareable @authenticated"
                    " { x: Int }"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [a] Field"
                ' "User.hasR" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to"
                ' access the transitive type "X" data from @requires'
                " selection set."
            ),
        ],
    )


def test_hive_case_ar4_union_fragment_field() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { user: User'
                    ' }\ntype User @key(fields: "id") { id: ID r: R @external'
                    ' hasR: Boolean @requires(fields: "r { ... on X { x } }")'
                    " }\nunion R = X | Y\ntype Y @shareable { y: Int }\ntype X"
                    " @shareable { x: Int }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype User @key(fields:'
                    ' "id") { id: ID! r: R }\nunion R = X | Y\ntype Y'
                    " @shareable { y: Int }\ntype X @shareable { x: Int"
                    " @authenticated }"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [a] Field"
                ' "User.hasR" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to"
                ' access the transitive field "X.x" data from @requires'
                " selection set."
            ),
        ],
    )


def test_hive_case_ar3b_union_typename_ok() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { user: User'
                    ' }\ntype User @key(fields: "id") { id: ID r: R @external'
                    ' hasR: Boolean @requires(fields: "__typename r {'
                    ' __typename ... on X { x } }") }\nunion R = X | Y\ntype Y'
                    " @shareable { y: Int }\ntype X @shareable { x: Int }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype User @key(fields:'
                    ' "id") { id: ID! r: R }\nunion R = X | Y\ntype Y'
                    " @shareable { y: Int }\ntype X @shareable { x: Int"
                    " @authenticated }"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { c: Int }'
                ),
            ),
        ],
        [],
    )


def test_hive_case_ar3c_union_typename_denied_3() raises:
    # The expected errors are Hive v0.27.0 `validate` on these subgraphs.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { user: User'
                    ' }\ntype User @key(fields: "id") { id: ID r: R @external'
                    ' hasR: Boolean @requires(fields: "r { __typename }")'
                    " }\nunion R = X | Y\ntype Y @shareable { y: Int }\ntype X"
                    " @shareable { x: Int }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype User @key(fields:'
                    ' "id") { id: ID! r: R }\nunion R = X | Y\ntype Y'
                    " @shareable { y: Int }\ntype X @shareable @authenticated"
                    " { x: Int }"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { c: Int }'
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [a] Field"
                ' "User.hasR" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to"
                ' access the transitive type "X" data from @requires'
                " selection set."
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
