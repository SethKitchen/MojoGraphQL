# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/subgraph/errors/DIRECTIVE_COMPOSITION_ERROR.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_directive_composition_error() raises:
    # v2.0 > DIRECTIVE_COMPOSITION_ERROR
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    ' @composeDirective(name: "@hello")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [users] Cannot import unknown"
                ' element "@composeDirective".'
            ),
        ],
    )
    check(
        [
            sg(
                "foo",
                (
                    "directive @composeDirective(name: String!) repeatable on"
                    " SCHEMA\n\ndirective @block on FIELD_DEFINITION\n\nextend"
                    " schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@composeDirective"]) @composeDirective(name:'
                    ' "@block")\n\ntype Query {\n  foo: String @block\n}'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [foo] Cannot import unknown"
                ' element "@composeDirective".'
            ),
        ],
    )


def test_v2_1_directive_composition_error() raises:
    # v2.1 > DIRECTIVE_COMPOSITION_ERROR
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    ' @composeDirective(name: "@hello")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching"
                " directive definition for argument to @composeDirective"
                ' "@hello" in subgraph "users".'
            ),
        ],
    )
    check(
        [
            sg(
                "foo",
                (
                    "directive @composeDirective(name: String!) repeatable on"
                    " SCHEMA\n\ndirective @block on FIELD_DEFINITION\n\nextend"
                    " schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"]) @composeDirective(name:'
                    ' "@block")\n\ntype Query {\n  foo: String @block\n}'
                ),
            ),
        ],
        [
            (
                '[DIRECTIVE_COMPOSITION_ERROR] Directive "@block" in subgraph'
                ' "foo" cannot be composed because it is not a member of a core'
                " feature"
            ),
        ],
    )


def test_v2_2_directive_composition_error() raises:
    # v2.2 > DIRECTIVE_COMPOSITION_ERROR
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    ' @composeDirective(name: "@hello")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching"
                " directive definition for argument to @composeDirective"
                ' "@hello" in subgraph "users".'
            ),
        ],
    )
    check(
        [
            sg(
                "foo",
                (
                    "directive @composeDirective(name: String!) repeatable on"
                    " SCHEMA\n\ndirective @block on FIELD_DEFINITION\n\nextend"
                    " schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@composeDirective"]) @composeDirective(name:'
                    ' "@block")\n\ntype Query {\n  foo: String @block\n}'
                ),
            ),
        ],
        [
            (
                '[DIRECTIVE_COMPOSITION_ERROR] Directive "@block" in subgraph'
                ' "foo" cannot be composed because it is not a member of a core'
                " feature"
            ),
        ],
    )


def test_v2_3_directive_composition_error() raises:
    # v2.3 > DIRECTIVE_COMPOSITION_ERROR
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    ' @composeDirective(name: "@hello")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching"
                " directive definition for argument to @composeDirective"
                ' "@hello" in subgraph "users".'
            ),
        ],
    )
    check(
        [
            sg(
                "foo",
                (
                    "directive @composeDirective(name: String!) repeatable on"
                    " SCHEMA\n\ndirective @block on FIELD_DEFINITION\n\nextend"
                    " schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@composeDirective"]) @composeDirective(name:'
                    ' "@block")\n\ntype Query {\n  foo: String @block\n}'
                ),
            ),
        ],
        [
            (
                '[DIRECTIVE_COMPOSITION_ERROR] Directive "@block" in subgraph'
                ' "foo" cannot be composed because it is not a member of a core'
                " feature"
            ),
        ],
    )


def test_v2_4_directive_composition_error() raises:
    # v2.4 > DIRECTIVE_COMPOSITION_ERROR
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    ' @composeDirective(name: "@hello")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching"
                " directive definition for argument to @composeDirective"
                ' "@hello" in subgraph "users".'
            ),
        ],
    )
    check(
        [
            sg(
                "foo",
                (
                    "directive @composeDirective(name: String!) repeatable on"
                    " SCHEMA\n\ndirective @block on FIELD_DEFINITION\n\nextend"
                    " schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@composeDirective"]) @composeDirective(name:'
                    ' "@block")\n\ntype Query {\n  foo: String @block\n}'
                ),
            ),
        ],
        [
            (
                '[DIRECTIVE_COMPOSITION_ERROR] Directive "@block" in subgraph'
                ' "foo" cannot be composed because it is not a member of a core'
                " feature"
            ),
        ],
    )


def test_v2_5_directive_composition_error() raises:
    # v2.5 > DIRECTIVE_COMPOSITION_ERROR
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    ' @composeDirective(name: "@hello")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching"
                " directive definition for argument to @composeDirective"
                ' "@hello" in subgraph "users".'
            ),
        ],
    )
    check(
        [
            sg(
                "foo",
                (
                    "directive @composeDirective(name: String!) repeatable on"
                    " SCHEMA\n\ndirective @block on FIELD_DEFINITION\n\nextend"
                    " schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@composeDirective"]) @composeDirective(name:'
                    ' "@block")\n\ntype Query {\n  foo: String @block\n}'
                ),
            ),
        ],
        [
            (
                '[DIRECTIVE_COMPOSITION_ERROR] Directive "@block" in subgraph'
                ' "foo" cannot be composed because it is not a member of a core'
                " feature"
            ),
        ],
    )


def test_v2_6_directive_composition_error() raises:
    # v2.6 > DIRECTIVE_COMPOSITION_ERROR
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    ' @composeDirective(name: "@hello")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching"
                " directive definition for argument to @composeDirective"
                ' "@hello" in subgraph "users".'
            ),
        ],
    )
    check(
        [
            sg(
                "foo",
                (
                    "directive @composeDirective(name: String!) repeatable on"
                    " SCHEMA\n\ndirective @block on FIELD_DEFINITION\n\nextend"
                    " schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@composeDirective"]) @composeDirective(name:'
                    ' "@block")\n\ntype Query {\n  foo: String @block\n}'
                ),
            ),
        ],
        [
            (
                '[DIRECTIVE_COMPOSITION_ERROR] Directive "@block" in subgraph'
                ' "foo" cannot be composed because it is not a member of a core'
                " feature"
            ),
        ],
    )


def test_v2_7_directive_composition_error() raises:
    # v2.7 > DIRECTIVE_COMPOSITION_ERROR
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    ' @composeDirective(name: "@hello")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching"
                " directive definition for argument to @composeDirective"
                ' "@hello" in subgraph "users".'
            ),
        ],
    )
    check(
        [
            sg(
                "foo",
                (
                    "directive @composeDirective(name: String!) repeatable on"
                    " SCHEMA\n\ndirective @block on FIELD_DEFINITION\n\nextend"
                    " schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@composeDirective"]) @composeDirective(name:'
                    ' "@block")\n\ntype Query {\n  foo: String @block\n}'
                ),
            ),
        ],
        [
            (
                '[DIRECTIVE_COMPOSITION_ERROR] Directive "@block" in subgraph'
                ' "foo" cannot be composed because it is not a member of a core'
                " feature"
            ),
        ],
    )


def test_v2_8_directive_composition_error() raises:
    # v2.8 > DIRECTIVE_COMPOSITION_ERROR
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    ' @composeDirective(name: "@hello")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching"
                " directive definition for argument to @composeDirective"
                ' "@hello" in subgraph "users".'
            ),
        ],
    )
    check(
        [
            sg(
                "foo",
                (
                    "directive @composeDirective(name: String!) repeatable on"
                    " SCHEMA\n\ndirective @block on FIELD_DEFINITION\n\nextend"
                    " schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@composeDirective"]) @composeDirective(name:'
                    ' "@block")\n\ntype Query {\n  foo: String @block\n}'
                ),
            ),
        ],
        [
            (
                '[DIRECTIVE_COMPOSITION_ERROR] Directive "@block" in subgraph'
                ' "foo" cannot be composed because it is not a member of a core'
                " feature"
            ),
        ],
    )


def test_v2_9_directive_composition_error() raises:
    # v2.9 > DIRECTIVE_COMPOSITION_ERROR
    check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello"])'
                    ' @composeDirective(name: "@hello")\n\ntype Query {\n '
                    " words: [String!]!\n}"
                ),
            ),
        ],
        [
            (
                "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching"
                " directive definition for argument to @composeDirective"
                ' "@hello" in subgraph "users".'
            ),
        ],
    )
    check(
        [
            sg(
                "foo",
                (
                    "directive @composeDirective(name: String!) repeatable on"
                    " SCHEMA\n\ndirective @block on FIELD_DEFINITION\n\nextend"
                    " schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@composeDirective"]) @composeDirective(name:'
                    ' "@block")\n\ntype Query {\n  foo: String @block\n}'
                ),
            ),
        ],
        [
            (
                '[DIRECTIVE_COMPOSITION_ERROR] Directive "@block" in subgraph'
                ' "foo" cannot be composed because it is not a member of a core'
                " feature"
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
