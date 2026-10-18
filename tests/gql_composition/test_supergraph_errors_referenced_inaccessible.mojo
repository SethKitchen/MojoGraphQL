# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/REFERENCED_INACCESSIBLE.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are Hive `REFERENCED_INACCESSIBLE` from
`composeServices` on the same subgraphs. A reference from an
`@inaccessible` field expects an empty list.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_referenced_inaccessible() raises:
    # v2.0 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n '
                    " users(filter: Filter, access: Access): [User]\n}\n\nenum"
                    " Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype"
                    " User @inaccessible {\n  id: ID!\n}\n\ninput Filter"
                    " @inaccessible {\n  limit: Int\n}"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "User" is @inaccessible but is'
                ' referenced by "Query.users", which is in the API schema.'
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Filter" is @inaccessible but'
                ' is referenced by "Query.users(filter:)", which is in the API'
                " schema."
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Access" is @inaccessible but'
                ' is referenced by "Query.users(access:)", which is in the API'
                " schema."
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
                    " profile: Profile! @inaccessible\n}\n\ntype Profile {\n "
                    " name: String\n  address: Address\n}\n\ntype Address"
                    " @inaccessible {\n  street: String\n  postalCode:"
                    " String\n}"
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
                '[REFERENCED_INACCESSIBLE] Type "Address" is @inaccessible but'
                ' is referenced by "Profile.address", which is in the API'
                " schema."
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  a:'
                    " Foo\n}\n\nscalar Foo"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  b:'
                    " String\n}\n\nscalar Foo @inaccessible"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "Foo" is @inaccessible but is'
                ' referenced by "Query.a", which is in the API schema.'
            ),
        ],
    )


def test_v2_1_referenced_inaccessible() raises:
    # v2.1 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n '
                    " users(filter: Filter, access: Access): [User]\n}\n\nenum"
                    " Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype"
                    " User @inaccessible {\n  id: ID!\n}\n\ninput Filter"
                    " @inaccessible {\n  limit: Int\n}"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "User" is @inaccessible but is'
                ' referenced by "Query.users", which is in the API schema.'
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Filter" is @inaccessible but'
                ' is referenced by "Query.users(filter:)", which is in the API'
                " schema."
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Access" is @inaccessible but'
                ' is referenced by "Query.users(access:)", which is in the API'
                " schema."
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
                    " profile: Profile! @inaccessible\n}\n\ntype Profile {\n "
                    " name: String\n  address: Address\n}\n\ntype Address"
                    " @inaccessible {\n  street: String\n  postalCode:"
                    " String\n}"
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
                '[REFERENCED_INACCESSIBLE] Type "Address" is @inaccessible but'
                ' is referenced by "Profile.address", which is in the API'
                " schema."
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  a:'
                    " Foo\n}\n\nscalar Foo"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  b:'
                    " String\n}\n\nscalar Foo @inaccessible"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "Foo" is @inaccessible but is'
                ' referenced by "Query.a", which is in the API schema.'
            ),
        ],
    )


def test_v2_2_referenced_inaccessible() raises:
    # v2.2 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n '
                    " users(filter: Filter, access: Access): [User]\n}\n\nenum"
                    " Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype"
                    " User @inaccessible {\n  id: ID!\n}\n\ninput Filter"
                    " @inaccessible {\n  limit: Int\n}"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "User" is @inaccessible but is'
                ' referenced by "Query.users", which is in the API schema.'
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Filter" is @inaccessible but'
                ' is referenced by "Query.users(filter:)", which is in the API'
                " schema."
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Access" is @inaccessible but'
                ' is referenced by "Query.users(access:)", which is in the API'
                " schema."
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
                    " profile: Profile! @inaccessible\n}\n\ntype Profile {\n "
                    " name: String\n  address: Address\n}\n\ntype Address"
                    " @inaccessible {\n  street: String\n  postalCode:"
                    " String\n}"
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
                '[REFERENCED_INACCESSIBLE] Type "Address" is @inaccessible but'
                ' is referenced by "Profile.address", which is in the API'
                " schema."
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  a:'
                    " Foo\n}\n\nscalar Foo"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  b:'
                    " String\n}\n\nscalar Foo @inaccessible"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "Foo" is @inaccessible but is'
                ' referenced by "Query.a", which is in the API schema.'
            ),
        ],
    )


def test_v2_3_referenced_inaccessible() raises:
    # v2.3 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n '
                    " users(filter: Filter, access: Access): [User]\n}\n\nenum"
                    " Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype"
                    " User @inaccessible {\n  id: ID!\n}\n\ninput Filter"
                    " @inaccessible {\n  limit: Int\n}"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "User" is @inaccessible but is'
                ' referenced by "Query.users", which is in the API schema.'
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Filter" is @inaccessible but'
                ' is referenced by "Query.users(filter:)", which is in the API'
                " schema."
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Access" is @inaccessible but'
                ' is referenced by "Query.users(access:)", which is in the API'
                " schema."
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
                    " profile: Profile! @inaccessible\n}\n\ntype Profile {\n "
                    " name: String\n  address: Address\n}\n\ntype Address"
                    " @inaccessible {\n  street: String\n  postalCode:"
                    " String\n}"
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
                '[REFERENCED_INACCESSIBLE] Type "Address" is @inaccessible but'
                ' is referenced by "Profile.address", which is in the API'
                " schema."
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  a:'
                    " Foo\n}\n\nscalar Foo"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  b:'
                    " String\n}\n\nscalar Foo @inaccessible"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "Foo" is @inaccessible but is'
                ' referenced by "Query.a", which is in the API schema.'
            ),
        ],
    )


def test_v2_4_referenced_inaccessible() raises:
    # v2.4 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n '
                    " users(filter: Filter, access: Access): [User]\n}\n\nenum"
                    " Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype"
                    " User @inaccessible {\n  id: ID!\n}\n\ninput Filter"
                    " @inaccessible {\n  limit: Int\n}"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "User" is @inaccessible but is'
                ' referenced by "Query.users", which is in the API schema.'
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Filter" is @inaccessible but'
                ' is referenced by "Query.users(filter:)", which is in the API'
                " schema."
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Access" is @inaccessible but'
                ' is referenced by "Query.users(access:)", which is in the API'
                " schema."
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
                    " profile: Profile! @inaccessible\n}\n\ntype Profile {\n "
                    " name: String\n  address: Address\n}\n\ntype Address"
                    " @inaccessible {\n  street: String\n  postalCode:"
                    " String\n}"
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
                '[REFERENCED_INACCESSIBLE] Type "Address" is @inaccessible but'
                ' is referenced by "Profile.address", which is in the API'
                " schema."
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  a:'
                    " Foo\n}\n\nscalar Foo"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  b:'
                    " String\n}\n\nscalar Foo @inaccessible"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "Foo" is @inaccessible but is'
                ' referenced by "Query.a", which is in the API schema.'
            ),
        ],
    )


def test_v2_5_referenced_inaccessible() raises:
    # v2.5 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n '
                    " users(filter: Filter, access: Access): [User]\n}\n\nenum"
                    " Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype"
                    " User @inaccessible {\n  id: ID!\n}\n\ninput Filter"
                    " @inaccessible {\n  limit: Int\n}"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "User" is @inaccessible but is'
                ' referenced by "Query.users", which is in the API schema.'
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Filter" is @inaccessible but'
                ' is referenced by "Query.users(filter:)", which is in the API'
                " schema."
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Access" is @inaccessible but'
                ' is referenced by "Query.users(access:)", which is in the API'
                " schema."
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
                    " profile: Profile! @inaccessible\n}\n\ntype Profile {\n "
                    " name: String\n  address: Address\n}\n\ntype Address"
                    " @inaccessible {\n  street: String\n  postalCode:"
                    " String\n}"
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
                '[REFERENCED_INACCESSIBLE] Type "Address" is @inaccessible but'
                ' is referenced by "Profile.address", which is in the API'
                " schema."
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  a:'
                    " Foo\n}\n\nscalar Foo"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  b:'
                    " String\n}\n\nscalar Foo @inaccessible"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "Foo" is @inaccessible but is'
                ' referenced by "Query.a", which is in the API schema.'
            ),
        ],
    )


def test_v2_6_referenced_inaccessible() raises:
    # v2.6 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n '
                    " users(filter: Filter, access: Access): [User]\n}\n\nenum"
                    " Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype"
                    " User @inaccessible {\n  id: ID!\n}\n\ninput Filter"
                    " @inaccessible {\n  limit: Int\n}"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "User" is @inaccessible but is'
                ' referenced by "Query.users", which is in the API schema.'
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Filter" is @inaccessible but'
                ' is referenced by "Query.users(filter:)", which is in the API'
                " schema."
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Access" is @inaccessible but'
                ' is referenced by "Query.users(access:)", which is in the API'
                " schema."
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
                    " profile: Profile! @inaccessible\n}\n\ntype Profile {\n "
                    " name: String\n  address: Address\n}\n\ntype Address"
                    " @inaccessible {\n  street: String\n  postalCode:"
                    " String\n}"
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
                '[REFERENCED_INACCESSIBLE] Type "Address" is @inaccessible but'
                ' is referenced by "Profile.address", which is in the API'
                " schema."
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  a:'
                    " Foo\n}\n\nscalar Foo"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  b:'
                    " String\n}\n\nscalar Foo @inaccessible"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "Foo" is @inaccessible but is'
                ' referenced by "Query.a", which is in the API schema.'
            ),
        ],
    )


def test_v2_7_referenced_inaccessible() raises:
    # v2.7 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n '
                    " users(filter: Filter, access: Access): [User]\n}\n\nenum"
                    " Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype"
                    " User @inaccessible {\n  id: ID!\n}\n\ninput Filter"
                    " @inaccessible {\n  limit: Int\n}"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "User" is @inaccessible but is'
                ' referenced by "Query.users", which is in the API schema.'
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Filter" is @inaccessible but'
                ' is referenced by "Query.users(filter:)", which is in the API'
                " schema."
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Access" is @inaccessible but'
                ' is referenced by "Query.users(access:)", which is in the API'
                " schema."
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
                    " profile: Profile! @inaccessible\n}\n\ntype Profile {\n "
                    " name: String\n  address: Address\n}\n\ntype Address"
                    " @inaccessible {\n  street: String\n  postalCode:"
                    " String\n}"
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
                '[REFERENCED_INACCESSIBLE] Type "Address" is @inaccessible but'
                ' is referenced by "Profile.address", which is in the API'
                " schema."
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  a:'
                    " Foo\n}\n\nscalar Foo"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  b:'
                    " String\n}\n\nscalar Foo @inaccessible"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "Foo" is @inaccessible but is'
                ' referenced by "Query.a", which is in the API schema.'
            ),
        ],
    )


def test_v2_8_referenced_inaccessible() raises:
    # v2.8 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n '
                    " users(filter: Filter, access: Access): [User]\n}\n\nenum"
                    " Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype"
                    " User @inaccessible {\n  id: ID!\n}\n\ninput Filter"
                    " @inaccessible {\n  limit: Int\n}"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "User" is @inaccessible but is'
                ' referenced by "Query.users", which is in the API schema.'
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Filter" is @inaccessible but'
                ' is referenced by "Query.users(filter:)", which is in the API'
                " schema."
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Access" is @inaccessible but'
                ' is referenced by "Query.users(access:)", which is in the API'
                " schema."
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
                    " profile: Profile! @inaccessible\n}\n\ntype Profile {\n "
                    " name: String\n  address: Address\n}\n\ntype Address"
                    " @inaccessible {\n  street: String\n  postalCode:"
                    " String\n}"
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
                '[REFERENCED_INACCESSIBLE] Type "Address" is @inaccessible but'
                ' is referenced by "Profile.address", which is in the API'
                " schema."
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  a:'
                    " Foo\n}\n\nscalar Foo"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  b:'
                    " String\n}\n\nscalar Foo @inaccessible"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "Foo" is @inaccessible but is'
                ' referenced by "Query.a", which is in the API schema.'
            ),
        ],
    )


def test_v2_9_referenced_inaccessible() raises:
    # v2.9 > REFERENCED_INACCESSIBLE
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@inaccessible"])\n\ntype Query {\n '
                    " users(filter: Filter, access: Access): [User]\n}\n\nenum"
                    " Access @inaccessible {\n  PUBLIC\n  PRIVATE\n}\n\ntype"
                    " User @inaccessible {\n  id: ID!\n}\n\ninput Filter"
                    " @inaccessible {\n  limit: Int\n}"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "User" is @inaccessible but is'
                ' referenced by "Query.users", which is in the API schema.'
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Filter" is @inaccessible but'
                ' is referenced by "Query.users(filter:)", which is in the API'
                " schema."
            ),
            (
                '[REFERENCED_INACCESSIBLE] Type "Access" is @inaccessible but'
                ' is referenced by "Query.users(access:)", which is in the API'
                " schema."
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
                    " profile: Profile! @inaccessible\n}\n\ntype Profile {\n "
                    " name: String\n  address: Address\n}\n\ntype Address"
                    " @inaccessible {\n  street: String\n  postalCode:"
                    " String\n}"
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
                '[REFERENCED_INACCESSIBLE] Type "Address" is @inaccessible but'
                ' is referenced by "Profile.address", which is in the API'
                " schema."
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
                    ' ["@inaccessible"])\n\ntype Query {\n  a:'
                    " Foo\n}\n\nscalar Foo"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  b:'
                    " String\n}\n\nscalar Foo @inaccessible"
                ),
            ),
        ],
        [
            (
                '[REFERENCED_INACCESSIBLE] Type "Foo" is @inaccessible but is'
                ' referenced by "Query.a", which is in the API schema.'
            ),
        ],
    )


def test_argument_of_inaccessible_type() raises:
    # The parent type is @inaccessible, so its arguments can use a hidden
    # input type.
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@inaccessible"])\n\ntype Query {\n  t: T'
                    " @inaccessible\n  x: Int\n}\n\ntype T @inaccessible {\n"
                    "  f(a: In): Int\n}\n\ninput In @inaccessible {\n"
                    "  x: Int\n}"
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
