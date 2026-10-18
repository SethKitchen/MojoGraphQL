# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/FIELD_TYPE_MISMATCH.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are Hive `FIELD_TYPE_MISMATCH` from `composeServices`
on the same subgraphs. A case whose only upstream failure is another
supergraph rule still expects an empty list.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_field_type_mismatch() raises:
    # v2.0 > FIELD_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ninput'
                    " Filter {\n  ids: [ID!]!\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID\n  name: String!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID\n  name: UserName!\n}\n\ninput Filter {\n  ids:"
                    " [Int!]\n}\n\ntype UserName {\n  first: String!\n  last:"
                    " String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "UserName!" in'
                ' subgraph "feed" but type "String!" in subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.name" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Filter.ids" is'
                ' incompatible across subgraphs: it has type "[Int!]" in'
                ' subgraph "feed" but type "[ID!]!" in subgraph "users"'
            ),
        ],
    )
    check(
        [
            sg(
                "auth",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String\n}\n\ntype Query {\n  me: User\n}"
                ),
            ),
            sg(
                "images",
                (
                    'type Image @key(fields: "url") {\n  url: Url\n  type:'
                    " MimeType\n}\n\ntype Query {\n  images:"
                    " [Image]\n}\n\nextend type User {\n  favorite:"
                    " Image\n}\n\nscalar Url\n\nscalar MimeType"
                ),
            ),
            sg(
                "albums",
                (
                    'type Album @key(fields: "id") {\n  id: ID!\n  user: User\n'
                    "  photos: [Image!]\n}\n\nextend type Image {\n  albums:"
                    " [Album!]\n}\n\nextend type User {\n  albums: [Album!]\n "
                    " favorite: Album\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.favorite" is'
                ' incompatible across subgraphs: it has type "Album" in'
                ' subgraph "albums" but type "Image" in subgraph "images"'
            ),
        ],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag!] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " tags: [Tag!]! @shareable\n}\n\ntype Tag @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag]! @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_field_type_mismatch_unions() raises:
    # v2.0 > FIELD_TYPE_MISMATCH (unions)
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo: A'
                    " @shareable\n}\n\ntype A {\n  id: ID! @shareable\n  name:"
                    " String @shareable\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo:'
                    " AnotherItem @shareable\n}\n\nunion AnotherItem = A |"
                    " C\n\ntype A {\n  id: ID! @shareable\n  name: String"
                    " @shareable\n}\n\ntype C {\n  id: ID! @shareable\n  name:"
                    " String! @shareable\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Query.foo" is'
                ' incompatible across subgraphs: it has type "AnotherItem" in'
                ' subgraph "bar" but type "Item" in subgraph "foo"'
            ),
        ],
    )


def test_v2_1_field_type_mismatch() raises:
    # v2.1 > FIELD_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ninput'
                    " Filter {\n  ids: [ID!]!\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID\n  name: String!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID\n  name: UserName!\n}\n\ninput Filter {\n  ids:"
                    " [Int!]\n}\n\ntype UserName {\n  first: String!\n  last:"
                    " String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "UserName!" in'
                ' subgraph "feed" but type "String!" in subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.name" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Filter.ids" is'
                ' incompatible across subgraphs: it has type "[Int!]" in'
                ' subgraph "feed" but type "[ID!]!" in subgraph "users"'
            ),
        ],
    )
    check(
        [
            sg(
                "auth",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String\n}\n\ntype Query {\n  me: User\n}"
                ),
            ),
            sg(
                "images",
                (
                    'type Image @key(fields: "url") {\n  url: Url\n  type:'
                    " MimeType\n}\n\ntype Query {\n  images:"
                    " [Image]\n}\n\nextend type User {\n  favorite:"
                    " Image\n}\n\nscalar Url\n\nscalar MimeType"
                ),
            ),
            sg(
                "albums",
                (
                    'type Album @key(fields: "id") {\n  id: ID!\n  user: User\n'
                    "  photos: [Image!]\n}\n\nextend type Image {\n  albums:"
                    " [Album!]\n}\n\nextend type User {\n  albums: [Album!]\n "
                    " favorite: Album\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.favorite" is'
                ' incompatible across subgraphs: it has type "Album" in'
                ' subgraph "albums" but type "Image" in subgraph "images"'
            ),
        ],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag!] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " tags: [Tag!]! @shareable\n}\n\ntype Tag @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag]! @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_field_type_mismatch_unions() raises:
    # v2.1 > FIELD_TYPE_MISMATCH (unions)
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo: A'
                    " @shareable\n}\n\ntype A {\n  id: ID! @shareable\n  name:"
                    " String @shareable\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo:'
                    " AnotherItem @shareable\n}\n\nunion AnotherItem = A |"
                    " C\n\ntype A {\n  id: ID! @shareable\n  name: String"
                    " @shareable\n}\n\ntype C {\n  id: ID! @shareable\n  name:"
                    " String! @shareable\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Query.foo" is'
                ' incompatible across subgraphs: it has type "AnotherItem" in'
                ' subgraph "bar" but type "Item" in subgraph "foo"'
            ),
        ],
    )


def test_v2_2_field_type_mismatch() raises:
    # v2.2 > FIELD_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ninput'
                    " Filter {\n  ids: [ID!]!\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID\n  name: String!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID\n  name: UserName!\n}\n\ninput Filter {\n  ids:"
                    " [Int!]\n}\n\ntype UserName {\n  first: String!\n  last:"
                    " String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "UserName!" in'
                ' subgraph "feed" but type "String!" in subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.name" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Filter.ids" is'
                ' incompatible across subgraphs: it has type "[Int!]" in'
                ' subgraph "feed" but type "[ID!]!" in subgraph "users"'
            ),
        ],
    )
    check(
        [
            sg(
                "auth",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String\n}\n\ntype Query {\n  me: User\n}"
                ),
            ),
            sg(
                "images",
                (
                    'type Image @key(fields: "url") {\n  url: Url\n  type:'
                    " MimeType\n}\n\ntype Query {\n  images:"
                    " [Image]\n}\n\nextend type User {\n  favorite:"
                    " Image\n}\n\nscalar Url\n\nscalar MimeType"
                ),
            ),
            sg(
                "albums",
                (
                    'type Album @key(fields: "id") {\n  id: ID!\n  user: User\n'
                    "  photos: [Image!]\n}\n\nextend type Image {\n  albums:"
                    " [Album!]\n}\n\nextend type User {\n  albums: [Album!]\n "
                    " favorite: Album\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.favorite" is'
                ' incompatible across subgraphs: it has type "Album" in'
                ' subgraph "albums" but type "Image" in subgraph "images"'
            ),
        ],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag!] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " tags: [Tag!]! @shareable\n}\n\ntype Tag @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag]! @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_field_type_mismatch_unions() raises:
    # v2.2 > FIELD_TYPE_MISMATCH (unions)
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo: A'
                    " @shareable\n}\n\ntype A {\n  id: ID! @shareable\n  name:"
                    " String @shareable\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo:'
                    " AnotherItem @shareable\n}\n\nunion AnotherItem = A |"
                    " C\n\ntype A {\n  id: ID! @shareable\n  name: String"
                    " @shareable\n}\n\ntype C {\n  id: ID! @shareable\n  name:"
                    " String! @shareable\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Query.foo" is'
                ' incompatible across subgraphs: it has type "AnotherItem" in'
                ' subgraph "bar" but type "Item" in subgraph "foo"'
            ),
        ],
    )


def test_v2_3_field_type_mismatch() raises:
    # v2.3 > FIELD_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ninput'
                    " Filter {\n  ids: [ID!]!\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID\n  name: String!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID\n  name: UserName!\n}\n\ninput Filter {\n  ids:"
                    " [Int!]\n}\n\ntype UserName {\n  first: String!\n  last:"
                    " String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "UserName!" in'
                ' subgraph "feed" but type "String!" in subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.name" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Filter.ids" is'
                ' incompatible across subgraphs: it has type "[Int!]" in'
                ' subgraph "feed" but type "[ID!]!" in subgraph "users"'
            ),
        ],
    )
    check(
        [
            sg(
                "auth",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String\n}\n\ntype Query {\n  me: User\n}"
                ),
            ),
            sg(
                "images",
                (
                    'type Image @key(fields: "url") {\n  url: Url\n  type:'
                    " MimeType\n}\n\ntype Query {\n  images:"
                    " [Image]\n}\n\nextend type User {\n  favorite:"
                    " Image\n}\n\nscalar Url\n\nscalar MimeType"
                ),
            ),
            sg(
                "albums",
                (
                    'type Album @key(fields: "id") {\n  id: ID!\n  user: User\n'
                    "  photos: [Image!]\n}\n\nextend type Image {\n  albums:"
                    " [Album!]\n}\n\nextend type User {\n  albums: [Album!]\n "
                    " favorite: Album\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.favorite" is'
                ' incompatible across subgraphs: it has type "Album" in'
                ' subgraph "albums" but type "Image" in subgraph "images"'
            ),
        ],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag!] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " tags: [Tag!]! @shareable\n}\n\ntype Tag @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag]! @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_field_type_mismatch_unions() raises:
    # v2.3 > FIELD_TYPE_MISMATCH (unions)
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo: A'
                    " @shareable\n}\n\ntype A {\n  id: ID! @shareable\n  name:"
                    " String @shareable\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo:'
                    " AnotherItem @shareable\n}\n\nunion AnotherItem = A |"
                    " C\n\ntype A {\n  id: ID! @shareable\n  name: String"
                    " @shareable\n}\n\ntype C {\n  id: ID! @shareable\n  name:"
                    " String! @shareable\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Query.foo" is'
                ' incompatible across subgraphs: it has type "AnotherItem" in'
                ' subgraph "bar" but type "Item" in subgraph "foo"'
            ),
        ],
    )


def test_v2_4_field_type_mismatch() raises:
    # v2.4 > FIELD_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ninput'
                    " Filter {\n  ids: [ID!]!\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID\n  name: String!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID\n  name: UserName!\n}\n\ninput Filter {\n  ids:"
                    " [Int!]\n}\n\ntype UserName {\n  first: String!\n  last:"
                    " String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "UserName!" in'
                ' subgraph "feed" but type "String!" in subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.name" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Filter.ids" is'
                ' incompatible across subgraphs: it has type "[Int!]" in'
                ' subgraph "feed" but type "[ID!]!" in subgraph "users"'
            ),
        ],
    )
    check(
        [
            sg(
                "auth",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String\n}\n\ntype Query {\n  me: User\n}"
                ),
            ),
            sg(
                "images",
                (
                    'type Image @key(fields: "url") {\n  url: Url\n  type:'
                    " MimeType\n}\n\ntype Query {\n  images:"
                    " [Image]\n}\n\nextend type User {\n  favorite:"
                    " Image\n}\n\nscalar Url\n\nscalar MimeType"
                ),
            ),
            sg(
                "albums",
                (
                    'type Album @key(fields: "id") {\n  id: ID!\n  user: User\n'
                    "  photos: [Image!]\n}\n\nextend type Image {\n  albums:"
                    " [Album!]\n}\n\nextend type User {\n  albums: [Album!]\n "
                    " favorite: Album\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.favorite" is'
                ' incompatible across subgraphs: it has type "Album" in'
                ' subgraph "albums" but type "Image" in subgraph "images"'
            ),
        ],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag!] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " tags: [Tag!]! @shareable\n}\n\ntype Tag @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag]! @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_field_type_mismatch_unions() raises:
    # v2.4 > FIELD_TYPE_MISMATCH (unions)
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo: A'
                    " @shareable\n}\n\ntype A {\n  id: ID! @shareable\n  name:"
                    " String @shareable\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo:'
                    " AnotherItem @shareable\n}\n\nunion AnotherItem = A |"
                    " C\n\ntype A {\n  id: ID! @shareable\n  name: String"
                    " @shareable\n}\n\ntype C {\n  id: ID! @shareable\n  name:"
                    " String! @shareable\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Query.foo" is'
                ' incompatible across subgraphs: it has type "AnotherItem" in'
                ' subgraph "bar" but type "Item" in subgraph "foo"'
            ),
        ],
    )


def test_v2_5_field_type_mismatch() raises:
    # v2.5 > FIELD_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ninput'
                    " Filter {\n  ids: [ID!]!\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID\n  name: String!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID\n  name: UserName!\n}\n\ninput Filter {\n  ids:"
                    " [Int!]\n}\n\ntype UserName {\n  first: String!\n  last:"
                    " String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "UserName!" in'
                ' subgraph "feed" but type "String!" in subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.name" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Filter.ids" is'
                ' incompatible across subgraphs: it has type "[Int!]" in'
                ' subgraph "feed" but type "[ID!]!" in subgraph "users"'
            ),
        ],
    )
    check(
        [
            sg(
                "auth",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String\n}\n\ntype Query {\n  me: User\n}"
                ),
            ),
            sg(
                "images",
                (
                    'type Image @key(fields: "url") {\n  url: Url\n  type:'
                    " MimeType\n}\n\ntype Query {\n  images:"
                    " [Image]\n}\n\nextend type User {\n  favorite:"
                    " Image\n}\n\nscalar Url\n\nscalar MimeType"
                ),
            ),
            sg(
                "albums",
                (
                    'type Album @key(fields: "id") {\n  id: ID!\n  user: User\n'
                    "  photos: [Image!]\n}\n\nextend type Image {\n  albums:"
                    " [Album!]\n}\n\nextend type User {\n  albums: [Album!]\n "
                    " favorite: Album\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.favorite" is'
                ' incompatible across subgraphs: it has type "Album" in'
                ' subgraph "albums" but type "Image" in subgraph "images"'
            ),
        ],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag!] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " tags: [Tag!]! @shareable\n}\n\ntype Tag @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag]! @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_field_type_mismatch_unions() raises:
    # v2.5 > FIELD_TYPE_MISMATCH (unions)
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo: A'
                    " @shareable\n}\n\ntype A {\n  id: ID! @shareable\n  name:"
                    " String @shareable\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo:'
                    " AnotherItem @shareable\n}\n\nunion AnotherItem = A |"
                    " C\n\ntype A {\n  id: ID! @shareable\n  name: String"
                    " @shareable\n}\n\ntype C {\n  id: ID! @shareable\n  name:"
                    " String! @shareable\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Query.foo" is'
                ' incompatible across subgraphs: it has type "AnotherItem" in'
                ' subgraph "bar" but type "Item" in subgraph "foo"'
            ),
        ],
    )


def test_v2_6_field_type_mismatch() raises:
    # v2.6 > FIELD_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ninput'
                    " Filter {\n  ids: [ID!]!\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID\n  name: String!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID\n  name: UserName!\n}\n\ninput Filter {\n  ids:"
                    " [Int!]\n}\n\ntype UserName {\n  first: String!\n  last:"
                    " String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "UserName!" in'
                ' subgraph "feed" but type "String!" in subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.name" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Filter.ids" is'
                ' incompatible across subgraphs: it has type "[Int!]" in'
                ' subgraph "feed" but type "[ID!]!" in subgraph "users"'
            ),
        ],
    )
    check(
        [
            sg(
                "auth",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String\n}\n\ntype Query {\n  me: User\n}"
                ),
            ),
            sg(
                "images",
                (
                    'type Image @key(fields: "url") {\n  url: Url\n  type:'
                    " MimeType\n}\n\ntype Query {\n  images:"
                    " [Image]\n}\n\nextend type User {\n  favorite:"
                    " Image\n}\n\nscalar Url\n\nscalar MimeType"
                ),
            ),
            sg(
                "albums",
                (
                    'type Album @key(fields: "id") {\n  id: ID!\n  user: User\n'
                    "  photos: [Image!]\n}\n\nextend type Image {\n  albums:"
                    " [Album!]\n}\n\nextend type User {\n  albums: [Album!]\n "
                    " favorite: Album\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.favorite" is'
                ' incompatible across subgraphs: it has type "Album" in'
                ' subgraph "albums" but type "Image" in subgraph "images"'
            ),
        ],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag!] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " tags: [Tag!]! @shareable\n}\n\ntype Tag @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag]! @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_field_type_mismatch_unions() raises:
    # v2.6 > FIELD_TYPE_MISMATCH (unions)
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo: A'
                    " @shareable\n}\n\ntype A {\n  id: ID! @shareable\n  name:"
                    " String @shareable\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo:'
                    " AnotherItem @shareable\n}\n\nunion AnotherItem = A |"
                    " C\n\ntype A {\n  id: ID! @shareable\n  name: String"
                    " @shareable\n}\n\ntype C {\n  id: ID! @shareable\n  name:"
                    " String! @shareable\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Query.foo" is'
                ' incompatible across subgraphs: it has type "AnotherItem" in'
                ' subgraph "bar" but type "Item" in subgraph "foo"'
            ),
        ],
    )


def test_v2_7_field_type_mismatch() raises:
    # v2.7 > FIELD_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ninput'
                    " Filter {\n  ids: [ID!]!\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID\n  name: String!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID\n  name: UserName!\n}\n\ninput Filter {\n  ids:"
                    " [Int!]\n}\n\ntype UserName {\n  first: String!\n  last:"
                    " String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "UserName!" in'
                ' subgraph "feed" but type "String!" in subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.name" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Filter.ids" is'
                ' incompatible across subgraphs: it has type "[Int!]" in'
                ' subgraph "feed" but type "[ID!]!" in subgraph "users"'
            ),
        ],
    )
    check(
        [
            sg(
                "auth",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String\n}\n\ntype Query {\n  me: User\n}"
                ),
            ),
            sg(
                "images",
                (
                    'type Image @key(fields: "url") {\n  url: Url\n  type:'
                    " MimeType\n}\n\ntype Query {\n  images:"
                    " [Image]\n}\n\nextend type User {\n  favorite:"
                    " Image\n}\n\nscalar Url\n\nscalar MimeType"
                ),
            ),
            sg(
                "albums",
                (
                    'type Album @key(fields: "id") {\n  id: ID!\n  user: User\n'
                    "  photos: [Image!]\n}\n\nextend type Image {\n  albums:"
                    " [Album!]\n}\n\nextend type User {\n  albums: [Album!]\n "
                    " favorite: Album\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.favorite" is'
                ' incompatible across subgraphs: it has type "Album" in'
                ' subgraph "albums" but type "Image" in subgraph "images"'
            ),
        ],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag!] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " tags: [Tag!]! @shareable\n}\n\ntype Tag @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag]! @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_field_type_mismatch_unions() raises:
    # v2.7 > FIELD_TYPE_MISMATCH (unions)
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo: A'
                    " @shareable\n}\n\ntype A {\n  id: ID! @shareable\n  name:"
                    " String @shareable\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo:'
                    " AnotherItem @shareable\n}\n\nunion AnotherItem = A |"
                    " C\n\ntype A {\n  id: ID! @shareable\n  name: String"
                    " @shareable\n}\n\ntype C {\n  id: ID! @shareable\n  name:"
                    " String! @shareable\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Query.foo" is'
                ' incompatible across subgraphs: it has type "AnotherItem" in'
                ' subgraph "bar" but type "Item" in subgraph "foo"'
            ),
        ],
    )


def test_v2_8_field_type_mismatch() raises:
    # v2.8 > FIELD_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ninput'
                    " Filter {\n  ids: [ID!]!\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID\n  name: String!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID\n  name: UserName!\n}\n\ninput Filter {\n  ids:"
                    " [Int!]\n}\n\ntype UserName {\n  first: String!\n  last:"
                    " String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "UserName!" in'
                ' subgraph "feed" but type "String!" in subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.name" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Filter.ids" is'
                ' incompatible across subgraphs: it has type "[Int!]" in'
                ' subgraph "feed" but type "[ID!]!" in subgraph "users"'
            ),
        ],
    )
    check(
        [
            sg(
                "auth",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String\n}\n\ntype Query {\n  me: User\n}"
                ),
            ),
            sg(
                "images",
                (
                    'type Image @key(fields: "url") {\n  url: Url\n  type:'
                    " MimeType\n}\n\ntype Query {\n  images:"
                    " [Image]\n}\n\nextend type User {\n  favorite:"
                    " Image\n}\n\nscalar Url\n\nscalar MimeType"
                ),
            ),
            sg(
                "albums",
                (
                    'type Album @key(fields: "id") {\n  id: ID!\n  user: User\n'
                    "  photos: [Image!]\n}\n\nextend type Image {\n  albums:"
                    " [Album!]\n}\n\nextend type User {\n  albums: [Album!]\n "
                    " favorite: Album\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.favorite" is'
                ' incompatible across subgraphs: it has type "Album" in'
                ' subgraph "albums" but type "Image" in subgraph "images"'
            ),
        ],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag!] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " tags: [Tag!]! @shareable\n}\n\ntype Tag @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag]! @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_field_type_mismatch_unions() raises:
    # v2.8 > FIELD_TYPE_MISMATCH (unions)
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo: A'
                    " @shareable\n}\n\ntype A {\n  id: ID! @shareable\n  name:"
                    " String @shareable\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo:'
                    " AnotherItem @shareable\n}\n\nunion AnotherItem = A |"
                    " C\n\ntype A {\n  id: ID! @shareable\n  name: String"
                    " @shareable\n}\n\ntype C {\n  id: ID! @shareable\n  name:"
                    " String! @shareable\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Query.foo" is'
                ' incompatible across subgraphs: it has type "AnotherItem" in'
                ' subgraph "bar" but type "Item" in subgraph "foo"'
            ),
        ],
    )


def test_v2_9_field_type_mismatch() raises:
    # v2.9 > FIELD_TYPE_MISMATCH
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  users: [User!]!\n}\n\ninput'
                    " Filter {\n  ids: [ID!]!\n}\n\ntype User @key(fields:"
                    ' "id") {\n  id: ID\n  name: String!\n}'
                ),
            ),
            sg(
                "feed",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\nextend type User @key(fields: "id") {\n  id:'
                    " ID\n  name: UserName!\n}\n\ninput Filter {\n  ids:"
                    " [Int!]\n}\n\ntype UserName {\n  first: String!\n  last:"
                    " String!\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.name" is'
                ' incompatible across subgraphs: it has type "UserName!" in'
                ' subgraph "feed" but type "String!" in subgraph "users"'
            ),
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "User.name" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "feed" and "users" and defined as non-shareable in'
                " all of them"
            ),
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Filter.ids" is'
                ' incompatible across subgraphs: it has type "[Int!]" in'
                ' subgraph "feed" but type "[ID!]!" in subgraph "users"'
            ),
        ],
    )
    check(
        [
            sg(
                "auth",
                (
                    'type User @key(fields: "id") {\n  id: ID!\n  name:'
                    " String\n}\n\ntype Query {\n  me: User\n}"
                ),
            ),
            sg(
                "images",
                (
                    'type Image @key(fields: "url") {\n  url: Url\n  type:'
                    " MimeType\n}\n\ntype Query {\n  images:"
                    " [Image]\n}\n\nextend type User {\n  favorite:"
                    " Image\n}\n\nscalar Url\n\nscalar MimeType"
                ),
            ),
            sg(
                "albums",
                (
                    'type Album @key(fields: "id") {\n  id: ID!\n  user: User\n'
                    "  photos: [Image!]\n}\n\nextend type Image {\n  albums:"
                    " [Album!]\n}\n\nextend type User {\n  albums: [Album!]\n "
                    " favorite: Album\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "User.favorite" is'
                ' incompatible across subgraphs: it has type "Album" in'
                ' subgraph "albums" but type "Image" in subgraph "images"'
            ),
        ],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag!] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag] @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "me",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  me:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " tags: [Tag!]! @shareable\n}\n\ntype Tag @key(fields:"
                    ' "id") {\n  id: ID!\n}'
                ),
            ),
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' tags: [Tag]! @shareable\n}\n\ntype Tag @key(fields: "id")'
                    " {\n  id: ID!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_field_type_mismatch_unions() raises:
    # v2.9 > FIELD_TYPE_MISMATCH (unions)
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo: A'
                    " @shareable\n}\n\ntype A {\n  id: ID! @shareable\n  name:"
                    " String @shareable\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@shareable"])\n\ntype Query {\n  foo: Item'
                    " @shareable\n}\n\nunion Item = A | B\n\ntype A {\n  id:"
                    " ID! @shareable\n  name: String @shareable\n}\n\ntype B"
                    " {\n  id: ID!\n  name: String!\n}\n\ntype C {\n  id: ID!"
                    " @shareable\n  name: String! @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  foo:'
                    " AnotherItem @shareable\n}\n\nunion AnotherItem = A |"
                    " C\n\ntype A {\n  id: ID! @shareable\n  name: String"
                    " @shareable\n}\n\ntype C {\n  id: ID! @shareable\n  name:"
                    " String! @shareable\n}"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Query.foo" is'
                ' incompatible across subgraphs: it has type "AnotherItem" in'
                ' subgraph "bar" but type "Item" in subgraph "foo"'
            ),
        ],
    )


def test_hive_case_ft1() raises:
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
                    '","@context","@fromContext"])\ntype Query { f: String'
                    " @shareable }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { f: Int'
                    " @shareable }"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { f: Boolean'
                    " @shareable }"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Query.f" is'
                ' incompatible across subgraphs: it has type "String" in'
                ' subgraph "a" but type "Int" in subgraph "b" and type'
                ' "Boolean" in subgraph "c"'
            ),
        ],
    )


def test_hive_case_ft2() raises:
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
                    '","@context","@fromContext"])\ntype Query { f: [String]'
                    " @shareable }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Query { f: String'
                    " @shareable }"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Query.f" is'
                ' incompatible across subgraphs: it has type "[String]"'
                ' in subgraph "a" but type "String" in subgraph "b"'
            ),
        ],
    )


def test_hive_case_ft3() raises:
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
                    '","@context","@fromContext"])\nunion R = X | Y\ntype X {'
                    " x: Int }\ntype Y { y: Int }\ntype Query { f: R @shareable"
                    " }"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key","@external","@requires","@shareable","@provides'
                    '","@interfaceObject","@composeDirective","@authenticated'
                    '","@context","@fromContext"])\ntype Z { z: Int }\ntype'
                    " Query { f: Z @shareable }"
                ),
            ),
        ],
        [
            (
                '[FIELD_TYPE_MISMATCH] Type of field "Query.f" is'
                ' incompatible across subgraphs: it has type "R" in'
                ' subgraph "a" but type "Z" in subgraph "b"'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
