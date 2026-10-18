# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/federation-directives.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_federation_v1_directives_should_be_available_when_schema_link_federation_is() raises:
    # v2.0 > federation v1 directives should be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_federation_v1_directives_prefixed_with_federation_should_not_be_available_w() raises:
    # v2.0 > federation v1 directives prefixed with federation__ should NOT be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @federation__key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Unknown directive "@federation__key".',
        ],
    )


def test_v2_0_federation_directives_should_not_be_available_when_not_imported_but_schema() raises:
    # v2.0 > federation directives should not be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Unknown directive "@key". If you meant'
                ' the "@key" federation directive, you should use'
                ' fully-qualified name "@federation__key" or add "@key" to the'
                " `import` argument of the @link to the federation"
                " specification."
            ),
            '[INVALID_GRAPHQL] [a] Unknown directive "@key".',
        ],
    )


def test_v2_0_federation_directives_prefixed_with_federation_should_be_available_when_not() raises:
    # v2.0 > federation directives prefixed with federation__ should be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n\ntype User @federation__key(fields:'
                    ' "name") {\n  name: String\n}\n\ntype Query {\n  user:'
                    " User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_0_support_basic_aliasing() raises:
    # v2.0 > support basic aliasing
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' [{name: "@key", as: "@myKey"}])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @myKey(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  age: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", {name: "@external", as: "@myExternal"}])\n\ntype'
                    " Query {\n  reviews: [Review]\n}\n\ntype Review"
                    ' @key(fields: "id") {\n  id: ID!\n  title:'
                    ' String!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @myExternal\n  reviews: [Review!]!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_federation_v1_directives_should_be_available_when_schema_link_federation_is() raises:
    # v2.1 > federation v1 directives should be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_federation_v1_directives_prefixed_with_federation_should_not_be_available_w() raises:
    # v2.1 > federation v1 directives prefixed with federation__ should NOT be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @federation__key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Unknown directive "@federation__key".',
        ],
    )


def test_v2_1_federation_directives_should_not_be_available_when_not_imported_but_schema() raises:
    # v2.1 > federation directives should not be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@shareable"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Unknown directive "@key". If you meant'
                ' the "@key" federation directive, you should use'
                ' fully-qualified name "@federation__key" or add "@key" to the'
                " `import` argument of the @link to the federation"
                " specification."
            ),
            '[INVALID_GRAPHQL] [a] Unknown directive "@key".',
        ],
    )


def test_v2_1_federation_directives_prefixed_with_federation_should_be_available_when_not() raises:
    # v2.1 > federation directives prefixed with federation__ should be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@shareable"])\n\ntype User @federation__key(fields:'
                    ' "name") {\n  name: String\n}\n\ntype Query {\n  user:'
                    " User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_1_support_basic_aliasing() raises:
    # v2.1 > support basic aliasing
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' [{name: "@key", as: "@myKey"}])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @myKey(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  age: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", {name: "@external", as: "@myExternal"}])\n\ntype'
                    " Query {\n  reviews: [Review]\n}\n\ntype Review"
                    ' @key(fields: "id") {\n  id: ID!\n  title:'
                    ' String!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @myExternal\n  reviews: [Review!]!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_federation_v1_directives_should_be_available_when_schema_link_federation_is() raises:
    # v2.2 > federation v1 directives should be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_federation_v1_directives_prefixed_with_federation_should_not_be_available_w() raises:
    # v2.2 > federation v1 directives prefixed with federation__ should NOT be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @federation__key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Unknown directive "@federation__key".',
        ],
    )


def test_v2_2_federation_directives_should_not_be_available_when_not_imported_but_schema() raises:
    # v2.2 > federation directives should not be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@shareable"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Unknown directive "@key". If you meant'
                ' the "@key" federation directive, you should use'
                ' fully-qualified name "@federation__key" or add "@key" to the'
                " `import` argument of the @link to the federation"
                " specification."
            ),
            '[INVALID_GRAPHQL] [a] Unknown directive "@key".',
        ],
    )


def test_v2_2_federation_directives_prefixed_with_federation_should_be_available_when_not() raises:
    # v2.2 > federation directives prefixed with federation__ should be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@shareable"])\n\ntype User @federation__key(fields:'
                    ' "name") {\n  name: String\n}\n\ntype Query {\n  user:'
                    " User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_2_support_basic_aliasing() raises:
    # v2.2 > support basic aliasing
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' [{name: "@key", as: "@myKey"}])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @myKey(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  age: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", {name: "@external", as: "@myExternal"}])\n\ntype'
                    " Query {\n  reviews: [Review]\n}\n\ntype Review"
                    ' @key(fields: "id") {\n  id: ID!\n  title:'
                    ' String!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @myExternal\n  reviews: [Review!]!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_federation_v1_directives_should_be_available_when_schema_link_federation_is() raises:
    # v2.3 > federation v1 directives should be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_federation_v1_directives_prefixed_with_federation_should_not_be_available_w() raises:
    # v2.3 > federation v1 directives prefixed with federation__ should NOT be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @federation__key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Unknown directive "@federation__key".',
        ],
    )


def test_v2_3_federation_directives_should_not_be_available_when_not_imported_but_schema() raises:
    # v2.3 > federation directives should not be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Unknown directive "@key". If you meant'
                ' the "@key" federation directive, you should use'
                ' fully-qualified name "@federation__key" or add "@key" to the'
                " `import` argument of the @link to the federation"
                " specification."
            ),
            '[INVALID_GRAPHQL] [a] Unknown directive "@key".',
        ],
    )


def test_v2_3_federation_directives_prefixed_with_federation_should_be_available_when_not() raises:
    # v2.3 > federation directives prefixed with federation__ should be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@shareable"])\n\ntype User @federation__key(fields:'
                    ' "name") {\n  name: String\n}\n\ntype Query {\n  user:'
                    " User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_3_support_basic_aliasing() raises:
    # v2.3 > support basic aliasing
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' [{name: "@key", as: "@myKey"}])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @myKey(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  age: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", {name: "@external", as: "@myExternal"}])\n\ntype'
                    " Query {\n  reviews: [Review]\n}\n\ntype Review"
                    ' @key(fields: "id") {\n  id: ID!\n  title:'
                    ' String!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @myExternal\n  reviews: [Review!]!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_federation_v1_directives_should_be_available_when_schema_link_federation_is() raises:
    # v2.4 > federation v1 directives should be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_federation_v1_directives_prefixed_with_federation_should_not_be_available_w() raises:
    # v2.4 > federation v1 directives prefixed with federation__ should NOT be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @federation__key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Unknown directive "@federation__key".',
        ],
    )


def test_v2_4_federation_directives_should_not_be_available_when_not_imported_but_schema() raises:
    # v2.4 > federation directives should not be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@shareable"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Unknown directive "@key". If you meant'
                ' the "@key" federation directive, you should use'
                ' fully-qualified name "@federation__key" or add "@key" to the'
                " `import` argument of the @link to the federation"
                " specification."
            ),
            '[INVALID_GRAPHQL] [a] Unknown directive "@key".',
        ],
    )


def test_v2_4_federation_directives_prefixed_with_federation_should_be_available_when_not() raises:
    # v2.4 > federation directives prefixed with federation__ should be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@shareable"])\n\ntype User @federation__key(fields:'
                    ' "name") {\n  name: String\n}\n\ntype Query {\n  user:'
                    " User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_4_support_basic_aliasing() raises:
    # v2.4 > support basic aliasing
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' [{name: "@key", as: "@myKey"}])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @myKey(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  age: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", {name: "@external", as: "@myExternal"}])\n\ntype'
                    " Query {\n  reviews: [Review]\n}\n\ntype Review"
                    ' @key(fields: "id") {\n  id: ID!\n  title:'
                    ' String!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @myExternal\n  reviews: [Review!]!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_federation_v1_directives_should_be_available_when_schema_link_federation_is() raises:
    # v2.5 > federation v1 directives should be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_federation_v1_directives_prefixed_with_federation_should_not_be_available_w() raises:
    # v2.5 > federation v1 directives prefixed with federation__ should NOT be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @federation__key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Unknown directive "@federation__key".',
        ],
    )


def test_v2_5_federation_directives_should_not_be_available_when_not_imported_but_schema() raises:
    # v2.5 > federation directives should not be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@shareable"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Unknown directive "@key". If you meant'
                ' the "@key" federation directive, you should use'
                ' fully-qualified name "@federation__key" or add "@key" to the'
                " `import` argument of the @link to the federation"
                " specification."
            ),
            '[INVALID_GRAPHQL] [a] Unknown directive "@key".',
        ],
    )


def test_v2_5_federation_directives_prefixed_with_federation_should_be_available_when_not() raises:
    # v2.5 > federation directives prefixed with federation__ should be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@shareable"])\n\ntype User @federation__key(fields:'
                    ' "name") {\n  name: String\n}\n\ntype Query {\n  user:'
                    " User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_5_support_basic_aliasing() raises:
    # v2.5 > support basic aliasing
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' [{name: "@key", as: "@myKey"}])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @myKey(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  age: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", {name: "@external", as: "@myExternal"}])\n\ntype'
                    " Query {\n  reviews: [Review]\n}\n\ntype Review"
                    ' @key(fields: "id") {\n  id: ID!\n  title:'
                    ' String!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @myExternal\n  reviews: [Review!]!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_federation_v1_directives_should_be_available_when_schema_link_federation_is() raises:
    # v2.6 > federation v1 directives should be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_federation_v1_directives_prefixed_with_federation_should_not_be_available_w() raises:
    # v2.6 > federation v1 directives prefixed with federation__ should NOT be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @federation__key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Unknown directive "@federation__key".',
        ],
    )


def test_v2_6_federation_directives_should_not_be_available_when_not_imported_but_schema() raises:
    # v2.6 > federation directives should not be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@shareable"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Unknown directive "@key". If you meant'
                ' the "@key" federation directive, you should use'
                ' fully-qualified name "@federation__key" or add "@key" to the'
                " `import` argument of the @link to the federation"
                " specification."
            ),
            '[INVALID_GRAPHQL] [a] Unknown directive "@key".',
        ],
    )


def test_v2_6_federation_directives_prefixed_with_federation_should_be_available_when_not() raises:
    # v2.6 > federation directives prefixed with federation__ should be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@shareable"])\n\ntype User @federation__key(fields:'
                    ' "name") {\n  name: String\n}\n\ntype Query {\n  user:'
                    " User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_6_support_basic_aliasing() raises:
    # v2.6 > support basic aliasing
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' [{name: "@key", as: "@myKey"}])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @myKey(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  age: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", {name: "@external", as: "@myExternal"}])\n\ntype'
                    " Query {\n  reviews: [Review]\n}\n\ntype Review"
                    ' @key(fields: "id") {\n  id: ID!\n  title:'
                    ' String!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @myExternal\n  reviews: [Review!]!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_federation_v1_directives_should_be_available_when_schema_link_federation_is() raises:
    # v2.7 > federation v1 directives should be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_federation_v1_directives_prefixed_with_federation_should_not_be_available_w() raises:
    # v2.7 > federation v1 directives prefixed with federation__ should NOT be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @federation__key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Unknown directive "@federation__key".',
        ],
    )


def test_v2_7_federation_directives_should_not_be_available_when_not_imported_but_schema() raises:
    # v2.7 > federation directives should not be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@shareable"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Unknown directive "@key". If you meant'
                ' the "@key" federation directive, you should use'
                ' fully-qualified name "@federation__key" or add "@key" to the'
                " `import` argument of the @link to the federation"
                " specification."
            ),
            '[INVALID_GRAPHQL] [a] Unknown directive "@key".',
        ],
    )


def test_v2_7_federation_directives_prefixed_with_federation_should_be_available_when_not() raises:
    # v2.7 > federation directives prefixed with federation__ should be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@shareable"])\n\ntype User @federation__key(fields:'
                    ' "name") {\n  name: String\n}\n\ntype Query {\n  user:'
                    " User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_7_support_basic_aliasing() raises:
    # v2.7 > support basic aliasing
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' [{name: "@key", as: "@myKey"}])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @myKey(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  age: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", {name: "@external", as: "@myExternal"}])\n\ntype'
                    " Query {\n  reviews: [Review]\n}\n\ntype Review"
                    ' @key(fields: "id") {\n  id: ID!\n  title:'
                    ' String!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @myExternal\n  reviews: [Review!]!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_federation_v1_directives_should_be_available_when_schema_link_federation_is() raises:
    # v2.8 > federation v1 directives should be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_federation_v1_directives_prefixed_with_federation_should_not_be_available_w() raises:
    # v2.8 > federation v1 directives prefixed with federation__ should NOT be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @federation__key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Unknown directive "@federation__key".',
        ],
    )


def test_v2_8_federation_directives_should_not_be_available_when_not_imported_but_schema() raises:
    # v2.8 > federation directives should not be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@shareable"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Unknown directive "@key". If you meant'
                ' the "@key" federation directive, you should use'
                ' fully-qualified name "@federation__key" or add "@key" to the'
                " `import` argument of the @link to the federation"
                " specification."
            ),
            '[INVALID_GRAPHQL] [a] Unknown directive "@key".',
        ],
    )


def test_v2_8_federation_directives_prefixed_with_federation_should_be_available_when_not() raises:
    # v2.8 > federation directives prefixed with federation__ should be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@shareable"])\n\ntype User @federation__key(fields:'
                    ' "name") {\n  name: String\n}\n\ntype Query {\n  user:'
                    " User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_support_basic_aliasing() raises:
    # v2.8 > support basic aliasing
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' [{name: "@key", as: "@myKey"}])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @myKey(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  age: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", {name: "@external", as: "@myExternal"}])\n\ntype'
                    " Query {\n  reviews: [Review]\n}\n\ntype Review"
                    ' @key(fields: "id") {\n  id: ID!\n  title:'
                    ' String!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @myExternal\n  reviews: [Review!]!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_federation_v1_directives_should_be_available_when_schema_link_federation_is() raises:
    # v2.9 > federation v1 directives should be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_federation_v1_directives_prefixed_with_federation_should_not_be_available_w() raises:
    # v2.9 > federation v1 directives prefixed with federation__ should NOT be available when schema @link(federation) is NOT provided
    check(
        [
            sg(
                "a",
                (
                    'type User @federation__key(fields: "name") {\n  name:'
                    " String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Unknown directive "@federation__key".',
        ],
    )


def test_v2_9_federation_directives_should_not_be_available_when_not_imported_but_schema() raises:
    # v2.9 > federation directives should not be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@shareable"])\n\ntype User @key(fields: "name") {\n '
                    " name: String\n}\n\ntype Query {\n  user: User\n}"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Unknown directive "@key". If you meant'
                ' the "@key" federation directive, you should use'
                ' fully-qualified name "@federation__key" or add "@key" to the'
                " `import` argument of the @link to the federation"
                " specification."
            ),
            '[INVALID_GRAPHQL] [a] Unknown directive "@key".',
        ],
    )


def test_v2_9_federation_directives_prefixed_with_federation_should_be_available_when_not() raises:
    # v2.9 > federation directives prefixed with federation__ should be available when not imported but schema @link(federation) is provided
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@shareable"])\n\ntype User @federation__key(fields:'
                    ' "name") {\n  name: String\n}\n\ntype Query {\n  user:'
                    " User\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_support_basic_aliasing() raises:
    # v2.9 > support basic aliasing
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' [{name: "@key", as: "@myKey"}])\n\ntype Query {\n  users:'
                    ' [User]\n}\n\ntype User @myKey(fields: "id") {\n  id:'
                    " ID!\n  name: String!\n  age: String!\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", {name: "@external", as: "@myExternal"}])\n\ntype'
                    " Query {\n  reviews: [Review]\n}\n\ntype Review"
                    ' @key(fields: "id") {\n  id: ID!\n  title:'
                    ' String!\n}\n\nextend type User @key(fields: "id") {\n '
                    " id: ID! @myExternal\n  reviews: [Review!]!\n}"
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
