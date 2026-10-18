# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/supergraph/errors/INTERFACE_OBJECT_USAGE_ERROR.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_interface_object_usage_error() raises:
    # v2.0 > INTERFACE_OBJECT_USAGE_ERROR
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ninterface Media @key(fields: "id") {\n  id:'
                    " ID!\n  title: String!\n}\n\ntype Book implements Media"
                    ' @key(fields: "id") {\n  id: ID!\n  title: String!\n}'
                ),
            ),
            sg(
                "review",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Media'
                    " @interfaceObject {\n  id: ID!\n  reviews:"
                    " [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype"
                    " Query {\n  topRatedMedia: [Media!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [review] Cannot import unknown"
                ' element "@interfaceObject".'
            ),
        ],
    )


def test_v2_1_interface_object_usage_error() raises:
    # v2.1 > INTERFACE_OBJECT_USAGE_ERROR
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ninterface Media @key(fields: "id") {\n  id:'
                    " ID!\n  title: String!\n}\n\ntype Book implements Media"
                    ' @key(fields: "id") {\n  id: ID!\n  title: String!\n}'
                ),
            ),
            sg(
                "review",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Media'
                    " @interfaceObject {\n  id: ID!\n  reviews:"
                    " [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype"
                    " Query {\n  topRatedMedia: [Media!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [review] Cannot import unknown"
                ' element "@interfaceObject".'
            ),
        ],
    )


def test_v2_2_interface_object_usage_error() raises:
    # v2.2 > INTERFACE_OBJECT_USAGE_ERROR
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ninterface Media @key(fields: "id") {\n  id:'
                    " ID!\n  title: String!\n}\n\ntype Book implements Media"
                    ' @key(fields: "id") {\n  id: ID!\n  title: String!\n}'
                ),
            ),
            sg(
                "review",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Media'
                    " @interfaceObject {\n  id: ID!\n  reviews:"
                    " [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype"
                    " Query {\n  topRatedMedia: [Media!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [review] Cannot import unknown"
                ' element "@interfaceObject".'
            ),
        ],
    )


def test_v2_3_interface_object_usage_error() raises:
    # v2.3 > INTERFACE_OBJECT_USAGE_ERROR
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ninterface Media @key(fields: "id") {\n  id:'
                    " ID!\n  title: String!\n}\n\ntype Book implements Media"
                    ' @key(fields: "id") {\n  id: ID!\n  title: String!\n}'
                ),
            ),
            sg(
                "review",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Media'
                    " @interfaceObject {\n  id: ID!\n  reviews:"
                    " [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype"
                    " Query {\n  topRatedMedia: [Media!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INTERFACE_OBJECT_USAGE_ERROR] [review] The @interfaceObject"
                " directive can only be applied to entity types but type"
                ' "Media" has no @key in this subgraph.'
            ),
        ],
    )


def test_v2_4_interface_object_usage_error() raises:
    # v2.4 > INTERFACE_OBJECT_USAGE_ERROR
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ninterface Media @key(fields: "id") {\n  id:'
                    " ID!\n  title: String!\n}\n\ntype Book implements Media"
                    ' @key(fields: "id") {\n  id: ID!\n  title: String!\n}'
                ),
            ),
            sg(
                "review",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Media'
                    " @interfaceObject {\n  id: ID!\n  reviews:"
                    " [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype"
                    " Query {\n  topRatedMedia: [Media!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INTERFACE_OBJECT_USAGE_ERROR] [review] The @interfaceObject"
                " directive can only be applied to entity types but type"
                ' "Media" has no @key in this subgraph.'
            ),
        ],
    )


def test_v2_5_interface_object_usage_error() raises:
    # v2.5 > INTERFACE_OBJECT_USAGE_ERROR
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ninterface Media @key(fields: "id") {\n  id:'
                    " ID!\n  title: String!\n}\n\ntype Book implements Media"
                    ' @key(fields: "id") {\n  id: ID!\n  title: String!\n}'
                ),
            ),
            sg(
                "review",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Media'
                    " @interfaceObject {\n  id: ID!\n  reviews:"
                    " [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype"
                    " Query {\n  topRatedMedia: [Media!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INTERFACE_OBJECT_USAGE_ERROR] [review] The @interfaceObject"
                " directive can only be applied to entity types but type"
                ' "Media" has no @key in this subgraph.'
            ),
        ],
    )


def test_v2_6_interface_object_usage_error() raises:
    # v2.6 > INTERFACE_OBJECT_USAGE_ERROR
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ninterface Media @key(fields: "id") {\n  id:'
                    " ID!\n  title: String!\n}\n\ntype Book implements Media"
                    ' @key(fields: "id") {\n  id: ID!\n  title: String!\n}'
                ),
            ),
            sg(
                "review",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Media'
                    " @interfaceObject {\n  id: ID!\n  reviews:"
                    " [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype"
                    " Query {\n  topRatedMedia: [Media!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INTERFACE_OBJECT_USAGE_ERROR] [review] The @interfaceObject"
                " directive can only be applied to entity types but type"
                ' "Media" has no @key in this subgraph.'
            ),
        ],
    )


def test_v2_7_interface_object_usage_error() raises:
    # v2.7 > INTERFACE_OBJECT_USAGE_ERROR
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ninterface Media @key(fields: "id") {\n  id:'
                    " ID!\n  title: String!\n}\n\ntype Book implements Media"
                    ' @key(fields: "id") {\n  id: ID!\n  title: String!\n}'
                ),
            ),
            sg(
                "review",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Media'
                    " @interfaceObject {\n  id: ID!\n  reviews:"
                    " [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype"
                    " Query {\n  topRatedMedia: [Media!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INTERFACE_OBJECT_USAGE_ERROR] [review] The @interfaceObject"
                " directive can only be applied to entity types but type"
                ' "Media" has no @key in this subgraph.'
            ),
        ],
    )


def test_v2_8_interface_object_usage_error() raises:
    # v2.8 > INTERFACE_OBJECT_USAGE_ERROR
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ninterface Media @key(fields: "id") {\n  id:'
                    " ID!\n  title: String!\n}\n\ntype Book implements Media"
                    ' @key(fields: "id") {\n  id: ID!\n  title: String!\n}'
                ),
            ),
            sg(
                "review",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Media'
                    " @interfaceObject {\n  id: ID!\n  reviews:"
                    " [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype"
                    " Query {\n  topRatedMedia: [Media!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INTERFACE_OBJECT_USAGE_ERROR] [review] The @interfaceObject"
                " directive can only be applied to entity types but type"
                ' "Media" has no @key in this subgraph.'
            ),
        ],
    )


def test_v2_9_interface_object_usage_error() raises:
    # v2.9 > INTERFACE_OBJECT_USAGE_ERROR
    check(
        [
            sg(
                "book",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ninterface Media @key(fields: "id") {\n  id:'
                    " ID!\n  title: String!\n}\n\ntype Book implements Media"
                    ' @key(fields: "id") {\n  id: ID!\n  title: String!\n}'
                ),
            ),
            sg(
                "review",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Media'
                    " @interfaceObject {\n  id: ID!\n  reviews:"
                    " [Review!]!\n}\n\ntype Review {\n  score: Int!\n}\n\ntype"
                    " Query {\n  topRatedMedia: [Media!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INTERFACE_OBJECT_USAGE_ERROR] [review] The @interfaceObject"
                " directive can only be applied to entity types but type"
                ' "Media" has no @key in this subgraph.'
            ),
        ],
    )


def test_interface_object_in_every_subgraph() raises:
    # extra: the supergraph rule, including upstream's "is is" wording
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Query {\n  a:'
                    " Media\n}\n\ntype Media @interfaceObject @key(fields:"
                    ' "id") {\n  id: ID!\n  title: String\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Media'
                    ' @interfaceObject @key(fields: "id") {\n  id: ID!\n '
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [
            (
                '[INTERFACE_OBJECT_USAGE_ERROR] Type "Media" is declared with'
                " @interfaceObject in all the subgraphs in which is is defined"
            ),
        ],
    )


def test_one_real_interface_is_allowed() raises:
    check(
        [
            sg(
                "books",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Query {\n  a:'
                    ' Media\n}\n\ninterface Media @key(fields: "id") {\n  id:'
                    ' ID!\n}\n\ntype Book implements Media @key(fields: "id")'
                    " {\n  id: ID!\n  title: String\n}"
                ),
            ),
            sg(
                "reviews",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Media'
                    ' @interfaceObject @key(fields: "id") {\n  id: ID!\n '
                    " reviews: [String]\n}"
                ),
            ),
        ],
        [],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
