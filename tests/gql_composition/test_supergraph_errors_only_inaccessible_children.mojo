# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/ONLY_INACCESSIBLE_CHILDREN.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are Hive `ONLY_INACCESSIBLE_CHILDREN` from
`composeServices` on the same subgraphs. A type that is itself
`@inaccessible` expects an empty list.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_only_inaccessible_children() raises:
    # v2.0 > ONLY_INACCESSIBLE_CHILDREN
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile {\n  name: String"
                    " @inaccessible\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Profile" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    ' Details @inaccessible {\n  age: Int\n}\n\n"""\nAddress'
                    " has all its fields inaccessible, but it's also"
                    " referenced by a field that is not inaccessible as"
                    " well.\nIt is never in the API schema, except as part of"
                    " introspection, but it's still reported as"
                    ' ONLY_INACCESSIBLE_CHILDREN error...\n"""\ntype Address'
                    " {\n  street: String @inaccessible\n  postalCode: String"
                    " @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Address" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile @inaccessible {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    " Details @inaccessible {\n  age: Int\n}\n\ntype Address"
                    " @inaccessible {\n  street: String @inaccessible\n "
                    " postalCode: String @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface Node @key(fields: "id") {\n  id:'
                    " ID @inaccessible\n}\n\ntype User implements Node"
                    ' @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id: ID\n}'
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Node" is in the API schema'
                " but all of its fields are @inaccessible."
            ),
        ],
    )


def test_v2_1_only_inaccessible_children() raises:
    # v2.1 > ONLY_INACCESSIBLE_CHILDREN
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile {\n  name: String"
                    " @inaccessible\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Profile" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    ' Details @inaccessible {\n  age: Int\n}\n\n"""\nAddress'
                    " has all its fields inaccessible, but it's also"
                    " referenced by a field that is not inaccessible as"
                    " well.\nIt is never in the API schema, except as part of"
                    " introspection, but it's still reported as"
                    ' ONLY_INACCESSIBLE_CHILDREN error...\n"""\ntype Address'
                    " {\n  street: String @inaccessible\n  postalCode: String"
                    " @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Address" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile @inaccessible {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    " Details @inaccessible {\n  age: Int\n}\n\ntype Address"
                    " @inaccessible {\n  street: String @inaccessible\n "
                    " postalCode: String @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface Node @key(fields: "id") {\n  id:'
                    " ID @inaccessible\n}\n\ntype User implements Node"
                    ' @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id: ID\n}'
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Node" is in the API schema'
                " but all of its fields are @inaccessible."
            ),
        ],
    )


def test_v2_2_only_inaccessible_children() raises:
    # v2.2 > ONLY_INACCESSIBLE_CHILDREN
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile {\n  name: String"
                    " @inaccessible\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Profile" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    ' Details @inaccessible {\n  age: Int\n}\n\n"""\nAddress'
                    " has all its fields inaccessible, but it's also"
                    " referenced by a field that is not inaccessible as"
                    " well.\nIt is never in the API schema, except as part of"
                    " introspection, but it's still reported as"
                    ' ONLY_INACCESSIBLE_CHILDREN error...\n"""\ntype Address'
                    " {\n  street: String @inaccessible\n  postalCode: String"
                    " @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Address" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile @inaccessible {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    " Details @inaccessible {\n  age: Int\n}\n\ntype Address"
                    " @inaccessible {\n  street: String @inaccessible\n "
                    " postalCode: String @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface Node @key(fields: "id") {\n  id:'
                    " ID @inaccessible\n}\n\ntype User implements Node"
                    ' @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id: ID\n}'
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Node" is in the API schema'
                " but all of its fields are @inaccessible."
            ),
        ],
    )


def test_v2_3_only_inaccessible_children() raises:
    # v2.3 > ONLY_INACCESSIBLE_CHILDREN
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile {\n  name: String"
                    " @inaccessible\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Profile" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    ' Details @inaccessible {\n  age: Int\n}\n\n"""\nAddress'
                    " has all its fields inaccessible, but it's also"
                    " referenced by a field that is not inaccessible as"
                    " well.\nIt is never in the API schema, except as part of"
                    " introspection, but it's still reported as"
                    ' ONLY_INACCESSIBLE_CHILDREN error...\n"""\ntype Address'
                    " {\n  street: String @inaccessible\n  postalCode: String"
                    " @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Address" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile @inaccessible {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    " Details @inaccessible {\n  age: Int\n}\n\ntype Address"
                    " @inaccessible {\n  street: String @inaccessible\n "
                    " postalCode: String @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface Node @key(fields: "id") {\n  id:'
                    " ID @inaccessible\n}\n\ntype User implements Node"
                    ' @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id: ID\n}'
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Node" is in the API schema'
                " but all of its fields are @inaccessible."
            ),
        ],
    )


def test_v2_4_only_inaccessible_children() raises:
    # v2.4 > ONLY_INACCESSIBLE_CHILDREN
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile {\n  name: String"
                    " @inaccessible\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Profile" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    ' Details @inaccessible {\n  age: Int\n}\n\n"""\nAddress'
                    " has all its fields inaccessible, but it's also"
                    " referenced by a field that is not inaccessible as"
                    " well.\nIt is never in the API schema, except as part of"
                    " introspection, but it's still reported as"
                    ' ONLY_INACCESSIBLE_CHILDREN error...\n"""\ntype Address'
                    " {\n  street: String @inaccessible\n  postalCode: String"
                    " @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Address" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile @inaccessible {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    " Details @inaccessible {\n  age: Int\n}\n\ntype Address"
                    " @inaccessible {\n  street: String @inaccessible\n "
                    " postalCode: String @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface Node @key(fields: "id") {\n  id:'
                    " ID @inaccessible\n}\n\ntype User implements Node"
                    ' @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id: ID\n}'
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Node" is in the API schema'
                " but all of its fields are @inaccessible."
            ),
        ],
    )


def test_v2_5_only_inaccessible_children() raises:
    # v2.5 > ONLY_INACCESSIBLE_CHILDREN
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile {\n  name: String"
                    " @inaccessible\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Profile" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    ' Details @inaccessible {\n  age: Int\n}\n\n"""\nAddress'
                    " has all its fields inaccessible, but it's also"
                    " referenced by a field that is not inaccessible as"
                    " well.\nIt is never in the API schema, except as part of"
                    " introspection, but it's still reported as"
                    ' ONLY_INACCESSIBLE_CHILDREN error...\n"""\ntype Address'
                    " {\n  street: String @inaccessible\n  postalCode: String"
                    " @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Address" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile @inaccessible {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    " Details @inaccessible {\n  age: Int\n}\n\ntype Address"
                    " @inaccessible {\n  street: String @inaccessible\n "
                    " postalCode: String @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface Node @key(fields: "id") {\n  id:'
                    " ID @inaccessible\n}\n\ntype User implements Node"
                    ' @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id: ID\n}'
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Node" is in the API schema'
                " but all of its fields are @inaccessible."
            ),
        ],
    )


def test_v2_6_only_inaccessible_children() raises:
    # v2.6 > ONLY_INACCESSIBLE_CHILDREN
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile {\n  name: String"
                    " @inaccessible\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Profile" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    ' Details @inaccessible {\n  age: Int\n}\n\n"""\nAddress'
                    " has all its fields inaccessible, but it's also"
                    " referenced by a field that is not inaccessible as"
                    " well.\nIt is never in the API schema, except as part of"
                    " introspection, but it's still reported as"
                    ' ONLY_INACCESSIBLE_CHILDREN error...\n"""\ntype Address'
                    " {\n  street: String @inaccessible\n  postalCode: String"
                    " @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Address" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile @inaccessible {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    " Details @inaccessible {\n  age: Int\n}\n\ntype Address"
                    " @inaccessible {\n  street: String @inaccessible\n "
                    " postalCode: String @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface Node @key(fields: "id") {\n  id:'
                    " ID @inaccessible\n}\n\ntype User implements Node"
                    ' @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id: ID\n}'
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Node" is in the API schema'
                " but all of its fields are @inaccessible."
            ),
        ],
    )


def test_v2_7_only_inaccessible_children() raises:
    # v2.7 > ONLY_INACCESSIBLE_CHILDREN
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile {\n  name: String"
                    " @inaccessible\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Profile" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    ' Details @inaccessible {\n  age: Int\n}\n\n"""\nAddress'
                    " has all its fields inaccessible, but it's also"
                    " referenced by a field that is not inaccessible as"
                    " well.\nIt is never in the API schema, except as part of"
                    " introspection, but it's still reported as"
                    ' ONLY_INACCESSIBLE_CHILDREN error...\n"""\ntype Address'
                    " {\n  street: String @inaccessible\n  postalCode: String"
                    " @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Address" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile @inaccessible {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    " Details @inaccessible {\n  age: Int\n}\n\ntype Address"
                    " @inaccessible {\n  street: String @inaccessible\n "
                    " postalCode: String @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface Node @key(fields: "id") {\n  id:'
                    " ID @inaccessible\n}\n\ntype User implements Node"
                    ' @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id: ID\n}'
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Node" is in the API schema'
                " but all of its fields are @inaccessible."
            ),
        ],
    )


def test_v2_8_only_inaccessible_children() raises:
    # v2.8 > ONLY_INACCESSIBLE_CHILDREN
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile {\n  name: String"
                    " @inaccessible\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Profile" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    ' Details @inaccessible {\n  age: Int\n}\n\n"""\nAddress'
                    " has all its fields inaccessible, but it's also"
                    " referenced by a field that is not inaccessible as"
                    " well.\nIt is never in the API schema, except as part of"
                    " introspection, but it's still reported as"
                    ' ONLY_INACCESSIBLE_CHILDREN error...\n"""\ntype Address'
                    " {\n  street: String @inaccessible\n  postalCode: String"
                    " @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Address" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile @inaccessible {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    " Details @inaccessible {\n  age: Int\n}\n\ntype Address"
                    " @inaccessible {\n  street: String @inaccessible\n "
                    " postalCode: String @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface Node @key(fields: "id") {\n  id:'
                    " ID @inaccessible\n}\n\ntype User implements Node"
                    ' @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id: ID\n}'
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Node" is in the API schema'
                " but all of its fields are @inaccessible."
            ),
        ],
    )


def test_v2_9_only_inaccessible_children() raises:
    # v2.9 > ONLY_INACCESSIBLE_CHILDREN
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile {\n  name: String"
                    " @inaccessible\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Profile" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    ' Details @inaccessible {\n  age: Int\n}\n\n"""\nAddress'
                    " has all its fields inaccessible, but it's also"
                    " referenced by a field that is not inaccessible as"
                    " well.\nIt is never in the API schema, except as part of"
                    " introspection, but it's still reported as"
                    ' ONLY_INACCESSIBLE_CHILDREN error...\n"""\ntype Address'
                    " {\n  street: String @inaccessible\n  postalCode: String"
                    " @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Address" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@inaccessible", "@requires"])\n\ntype Query {\n'
                    '  users: [User]\n}\n\ntype User @key(fields: "id'
                    ' internalId") {\n  id: ID!\n  internalId: ID!'
                    " @inaccessible\n}\n\ntype Profile @inaccessible {\n  name:"
                    " String\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " profile: Profile! @inaccessible\n}\n\ntype Profile"
                    " @inaccessible {\n  name: String @inaccessible\n  details:"
                    " Details\n  address: Address @inaccessible\n}\n\ntype"
                    " Details @inaccessible {\n  age: Int\n}\n\ntype Address"
                    " @inaccessible {\n  street: String @inaccessible\n "
                    " postalCode: String @inaccessible\n}"
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]\n}\n\ntype Product @key(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ninterface Node @key(fields: "id") {\n  id:'
                    " ID @inaccessible\n}\n\ntype User implements Node"
                    ' @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "products",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id", resolvable: false) @interfaceObject {\n  id: ID\n}'
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Node" is in the API schema'
                " but all of its fields are @inaccessible."
            ),
        ],
    )


def test_enum_with_only_inaccessible_values() raises:
    # Every value of a public enum is @inaccessible.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  e: E\n}\n\nenum E'
                    " {\n  A @inaccessible\n  B @inaccessible\n}"
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "E" is in the API schema'
                " but all of its values are @inaccessible."
            ),
        ],
    )


def test_object_type_without_fields() raises:
    # A subgraph `Query` adds `_service`, so an empty `Mutation` type is
    # valid in the subgraph, and every one of its zero fields is hidden.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  t: T\n}\n\ntype Mutation\n\n'
                    'type T @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [
            (
                '[ONLY_INACCESSIBLE_CHILDREN] Type "Mutation" is in the API'
                " schema but all of its fields are @inaccessible."
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
