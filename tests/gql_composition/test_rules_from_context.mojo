# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_composition.rules_from_context`.

Upstream has no test file for these cases. The expected errors are those of
the subgraph phase of Hive Federation Composition v0.27.0 `validate` in
Node.js on the same subgraphs.
"""

from _harness import check, sg
from gql_composition.validate import Subgraph
from std.testing import TestSuite


def test_ignored_tokens_before_reference() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: " ,\\t\\r\\n# comment\\n﻿$ #'
                    ' comment\\n c { s }")): Int }\n'
                ),
            ),
        ],
        [],
    )


def test_other_byte_order_like_character() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                "[NO_CONTEXT_IN_SELECTION] [a] @fromContext argument does not"
                ' reference a context "$c { s }".'
            ),
        ],
    )


def test_empty_reference() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "")): Int }\n'
                ),
            ),
        ],
        [
            (
                "[NO_CONTEXT_IN_SELECTION] [a] @fromContext argument does not"
                ' reference a context "".'
            ),
        ],
    )


def test_dollar_alone() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$")): Int }\n'
                ),
            ),
        ],
        [
            (
                "[NO_CONTEXT_IN_SELECTION] [a] @fromContext argument does not"
                ' reference a context "$".'
            ),
        ],
    )


def test_dollar_digit() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$1 { s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                "[NO_CONTEXT_IN_SELECTION] [a] @fromContext argument does not"
                ' reference a context "$1 { s }".'
            ),
        ],
    )


def test_underscore_context() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "_c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$_c { s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NAME_INVALID] [a] Context name "_c" is invalid. It'
                " should have only alphanumeric characters."
            ),
        ],
    )


def test_reference_without_selection() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c")): Int }\n'
                ),
            ),
        ],
        [
            (
                "[NO_CONTEXT_IN_SELECTION] [a] @fromContext argument does not"
                ' reference a context "$c".'
            ),
        ],
    )


def test_selection_does_not_parse() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { s ")): Int }\n'
                ),
            ),
        ],
        [
            "THROWS Syntax Error: Expected Name, found <EOF>.",
        ],
    )


def test_non_null_selection_for_nullable_argument() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String! }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [],
    )


def test_nullable_selection_for_non_null_argument() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String!'
                    ' @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: the type of the'
                ' selection "String" does not match the expected type "String!"'
            ),
        ],
    )


def test_list_argument() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String l: [String] }\ntype"
                    ' Target @key(fields: "id") { id: ID! f(x: [String]'
                    ' @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: the type of the'
                ' selection "String" does not match the expected type'
                ' "[String]"'
            ),
        ],
    )


def test_list_selection() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target l: [String] }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { l }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: the type of the'
                ' selection "[String]" does not match the expected type'
                ' "String"'
            ),
        ],
    )


def test_list_selection_for_list_argument() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target l: [String!]! }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: [String]'
                    ' @fromContext(field: "$c { l }")): Int }\n'
                ),
            ),
        ],
        [],
    )


def test_nested_list_selection() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target n: [N] }\ntype N { s: String!"
                    ' }\ntype Target @key(fields: "id") { id: ID! f(x: [String]'
                    ' @fromContext(field: "$c { n { s } }")): Int }\n'
                ),
            ),
        ],
        [],
    )


def test_fragment_spread() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { ...F }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: fragment spread'
                " is not allowed"
            ),
        ],
    )


def test_alias() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { x: s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: aliases are not'
                " allowed in the selection"
            ),
        ],
    )


def test_selection_directive() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { s @skip(if: true) }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: directives are'
                " not allowed in the selection"
            ),
        ],
    )


def test_nested_alias() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target n: N }\ntype N { s: String }\ntype"
                    ' Target @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { n { x: s } }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: aliases are not'
                " allowed in the selection"
            ),
        ],
    )


def test_multiple_selections() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String t: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { s t }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: multiple'
                " selections are made"
            ),
        ],
    )


def test_field_after_fragment() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { ... on Owner { s } s }")):'
                    " Int }\n"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: multiple fields'
                " could be selected"
            ),
        ],
    )


def test_fragment_without_condition() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { ... { s } }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: inline fragments'
                " must have type conditions"
            ),
        ],
    )


def test_duplicate_type_conditions() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { ... on Owner { s } ... on Owner'
                    ' { s } }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: type conditions'
                " have same name"
            ),
        ],
    )


def test_conditional_on_object() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { ... on Owner { s } }")):'
                    " Int }\n"
                ),
            ),
        ],
        [],
    )


def test_conditional_unused_condition() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Other { s: String"
                    ' }\ntype Target @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { ... on Owner { s } ... on Other'
                    ' { s } }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: type condition'
                ' "Other" is never used.'
            ),
        ],
    )


def test_conditional_no_match() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Other { s: String"
                    ' }\ntype Target @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { ... on Other { s } }")):'
                    " Int }\n"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: no type'
                ' condition matches the location "Owner"'
            ),
        ],
    )


def test_conditional_on_union() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype A @key(fields: "id") { id: ID! s: String child:'
                    " Target }\ntype B { s: String }\nunion U @context(name:"
                    ' "c") = A | B\nextend union U @context(name: "d")\ntype'
                    ' Target @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { ... on A { s } ... on B { s }'
                    ' }")): Int }\n'
                ),
            ),
        ],
        [],
    )


def test_conditional_on_union_bad_branch() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype A @key(fields: "id") { id: ID! s: Int child:'
                    " Target }\ntype B { s: String }\nunion U @context(name:"
                    ' "c") = A | B\ntype Target @key(fields: "id") { id: ID!'
                    ' f(x: String @fromContext(field: "$c { ... on A { s } ...'
                    ' on B { s } }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: the type of the'
                ' selection "Int" does not match the expected type "String"'
            ),
        ],
    )


def test_conditional_on_interface() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ninterface I @context(name: "c") { s: String }\ntype A'
                    ' implements I @key(fields: "id") { id: ID! s: String'
                    " child: Target }\ntype B implements I { s: String }\ntype"
                    ' C { s: String }\ntype Target @key(fields: "id") { id: ID!'
                    ' f(x: String @fromContext(field: "$c { ... on A { s } ...'
                    ' on B { s } }")): Int }\n'
                ),
            ),
        ],
        [],
    )


def test_conditional_interface_branch() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ninterface I @context(name: "c") { s: String'
                    " }\ninterface J { s: String }\ntype A implements I & J"
                    ' @key(fields: "id") { id: ID! s: String child: Target'
                    ' }\ntype Target @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { ... on J { s } }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: no type'
                ' condition matches the location "I"'
            ),
        ],
    )


def test_direct_on_union() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype A { s: String }\nunion U @context(name: "c") ='
                    ' A\ntype Target @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: the type of the'
                ' selection does not match the expected type "String"'
            ),
        ],
    )


def test_typename() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String!'
                    ' @fromContext(field: "$c { __typename }")): Int }\n'
                ),
            ),
        ],
        [],
    )


def test_unknown_field() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { missing }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid for type Owner.'
                ' Error: Cannot query field "missing" on type "Owner".'
            ),
        ],
    )


def test_field_of_interface() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    " }\ninterface I { b: String }\ninterface J { c: String"
                    " }\nscalar K\ntype Owner implements I & J & K @key(fields:"
                    ' "id") @context(name: "c") { id: ID! child: Target }\ntype'
                    ' Target @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { b }")): Int }\n'
                ),
            ),
        ],
        [
            "THROWS Expected K to be an interface type",
        ],
    )


def test_field_of_interface_missing() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    " }\ninterface I { b: String }\ntype Owner implements I"
                    ' @key(fields: "id") @context(name: "c") { id: ID! child:'
                    ' Target }\ntype Target @key(fields: "id") { id: ID! f(x:'
                    ' String @fromContext(field: "$c { z }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid for type Owner.'
                ' Error: Cannot query field "z" on type "Owner".'
            ),
            (
                "[INVALID_GRAPHQL] [a] Interface field I.b expected but Owner"
                " does not provide it."
            ),
        ],
    )


def test_interface_owner_direct() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ninterface I @context(name: "c") { s: String }\ntype A'
                    ' implements I @key(fields: "id") { id: ID! s: String'
                    ' child: Target }\ntype Target @key(fields: "id") { id: ID!'
                    ' f(x: String @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [],
    )


def test_interface_object_owner() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @interfaceObject'
                    ' @context(name: "c") { id: ID! s: String child: Target'
                    ' }\ntype Target @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: One of the types'
                ' in the selection is an interfaceObject: "Owner"'
            ),
        ],
    )


def test_nested_unknown_type() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target n: Missing }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { n { s } }")): Int }\n'
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown type Missing",
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: the type of the'
                ' selection does not match the expected type "String"'
            ),
        ],
    )


def test_nested_union_field() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target n: U }\nunion U = Owner\ntype"
                    ' Target @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { n { s } }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: the type of the'
                ' selection does not match the expected type "String"'
            ),
        ],
    )


def test_nested_fragment_without_condition() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target n: N }\ntype N { s: String }\ntype"
                    ' Target @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { n { ... { s } } }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: the type of the'
                ' selection does not match the expected type "String"'
            ),
        ],
    )


def test_nested_fragment_unknown_type() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target n: N }\ntype N { s: String }\ntype"
                    ' Target @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { n { ... on Missing { s } }'
                    ' }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: the type of the'
                ' selection does not match the expected type "String"'
            ),
        ],
    )


def test_nested_fragment() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target n: N }\ntype N { s: String }\ntype"
                    ' Target @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { n { ... on N { s } } }")):'
                    " Int }\n"
                ),
            ),
        ],
        [],
    )


def test_nested_two_fragments_mismatch() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target n: N }\ntype N { s: String t: Int"
                    ' }\ntype Target @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { n { ... on N { s } ... on N { t'
                    ' } } }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: the type of the'
                ' selection does not match the expected type "String"'
            ),
        ],
    )


def test_nested_two_fragments_match() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target n: N }\ntype N { s: String t:"
                    ' String }\ntype Target @key(fields: "id") { id: ID! f(x:'
                    ' String @fromContext(field: "$c { n { ... on N { s } ...'
                    ' on N { t } } }")): Int }\n'
                ),
            ),
        ],
        [],
    )


def test_two_owners_first_invalid() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: Int }\ntype Owner2"
                    ' @context(name: "c") { s: String }\ntype Target'
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: the type of the'
                ' selection "Int" does not match the expected type "String"'
            ),
        ],
    )


def test_context_name_not_string() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: 1) { id:'
                    " ID! child: Target s: String }\ntype Owner3 @context { s:"
                    ' String }\ntype Target @key(fields: "id") { id: ID! f(x:'
                    ' String @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NOT_SET] [a] Context "c" is used at location'
                ' "Target.f(x:)" but is never set.'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@context(name:)" of'
                ' type "String!" in application of "@context" to "Owner".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@context" argument "name" of'
                ' type "String!" is required, but it was not provided.'
            ),
        ],
    )


def test_never_set() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Target @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$zz { s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NOT_SET] [a] Context "zz" is used at location'
                ' "Target.f(x:)" but is never set.'
            ),
        ],
    )


def test_field_not_string() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Target @key(fields: "id") { id: ID! f(x: String'
                    " @fromContext(field: 1)): Int g(y: String @fromContext):"
                    " Int }\n"
                ),
            ),
        ],
        [],
    )


def test_not_on_argument() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Target @key(fields: "id") @fromContext(field: "$c'
                    ' { s }") { id: ID! f: Int @fromContext(field: "$c { s }")'
                    ' }\nschema @fromContext(field: "$c") { query: Query }\n'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@fromContext" may not be used'
                " on SCHEMA."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@fromContext" may not be used'
                " on OBJECT."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@fromContext" may not be used'
                " on FIELD_DEFINITION."
            ),
        ],
    )


def test_no_directives_on_object() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target  { id: ID!"
                    ' f(x: String @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NO_RESOLVABLE_KEY] [a] Object "Target" has no'
                " resolvable key but has a field with a contextual argument."
            ),
        ],
    )


def test_non_key_directive_on_object() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target @shareable"
                    ' { id: ID! f(x: String @fromContext(field: "$c { s }")):'
                    " Int }\n"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NO_RESOLVABLE_KEY] [a] Object "Target" has no'
                " resolvable key but has a field with a contextual argument."
            ),
        ],
    )


def test_unresolvable_key() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id", resolvable: false) { id: ID! f(x:'
                    ' String @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NO_RESOLVABLE_KEY] [a] Object "Target" has no'
                " resolvable key but has a field with a contextual argument."
            ),
        ],
    )


def test_resolvable_key_true() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id", resolvable: true) { id: ID! f(x:'
                    ' String @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [],
    )


def test_resolvable_key_string() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id", resolvable: "x") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@key(resolvable:)" of'
                ' type "Boolean" in application of "@key" to "Target".'
            ),
        ],
    )


def test_on_directive_definition() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ndirective @d(x: String @fromContext(field: "$c { s'
                    ' }")) on FIELD_DEFINITION\n'
                ),
            ),
        ],
        [
            (
                "[CONTEXT_NOT_SET] [a] @fromContext argument cannot be used on"
                ' a directive definition "@d(x:)".'
            ),
        ],
    )


def test_on_interface_field() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ninterface I { f(x: String @fromContext(field: "$c { s'
                    ' }")): Int }\n'
                ),
            ),
        ],
        [
            (
                "[CONTEXT_NOT_SET] [a] @fromContext argument cannot be used on"
                ' a field that exists on an abstract type "I.f(x:)".'
            ),
        ],
    )


def test_implementing_interface_field() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ninterface I { f(x:"
                    " String): Int }\ninterface J { g: Int }\ntype Target"
                    ' implements I & J & Missing @key(fields: "id") { id: ID!'
                    ' g: Int f(x: String @fromContext(field: "$c { s }")):'
                    " Int }\n"
                ),
            ),
        ],
        [
            "[INVALID_GRAPHQL] [a] Unknown type Missing",
            (
                "[CONTEXT_NOT_SET] [a] @fromContext argument cannot be used on"
                ' a field implementing an interface field "I.f".'
            ),
            (
                "[INVALID_GRAPHQL] [a] Type Missing must define one or more"
                " fields."
            ),
        ],
    )


def test_default_value() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! f(x: String = "d"'
                    ' @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [
            (
                "[CONTEXT_NOT_SET] [a] @fromContext arguments may not have a"
                ' default value: "Target.f(x:)".'
            ),
        ],
    )


def test_object_extension() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String'
                    ' }\ntype Owner @key(fields: "id") @context(name: "c") {'
                    " id: ID! child: Target s: String }\ntype Target"
                    ' @key(fields: "id") { id: ID! }\nextend type Target { f(x:'
                    ' String @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        [],
    )


def test_no_objects() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\nenum E { A }\n'
                ),
            ),
        ],
        [
            (
                "[NO_QUERIES] No queries found in any subgraph: a supergraph"
                " must have a query root type."
            ),
        ],
    )


def _target(
    field: String, rest: String, arg_type: String = "String"
) raises -> List[Subgraph]:
    """Return a subgraph with `rest` and a `Target.f(x:)` that takes its
    value from `field`. The field is GraphQL string source."""
    return [
        sg(
            "a",
            "extend schema @link(url:"
            ' "https://specs.apollo.dev/federation/v2.8", import: ["@key",'
            ' "@context", "@fromContext", "@interfaceObject", "@shareable",'
            ' "@external"])\ntype Query { a: String }\n'
            + rest
            + 'type Target @key(fields: "id") { id: ID! f(x: '
            + arg_type
            + ' @fromContext(field: "'
            + field
            + '")): Int }\n',
        )
    ]


comptime _OWNER = (
    'type Owner @key(fields: "id") @context(name: "c") { id: ID! child:'
    " Target s: String }\n"
)


def test_comment_to_end() raises:
    check(
        _target("# only", _OWNER),
        [
            (
                "[NO_CONTEXT_IN_SELECTION] [a] @fromContext argument does not"
                ' reference a context "# only".'
            ),
        ],
    )


def test_comment_to_carriage_return() raises:
    check(_target("#x\\r$c { s }", _OWNER), [])


def test_field_from_interface_of_owner() raises:
    check(
        _target(
            "$c { b }",
            (
                "interface I { b: String }\ntype Owner implements I"
                ' @key(fields: "id") @context(name: "c") { id: ID! child:'
                " Target }\n"
            ),
        ),
        [
            (
                "[INVALID_GRAPHQL] [a] Interface field I.b expects type String"
                " but Owner.b of type MISSING is not a proper subtype."
            ),
        ],
    )


def test_interface_owner_unknown_field() raises:
    check(
        _target(
            "$c { z }",
            (
                'interface I @context(name: "c") { s: String }\ntype A'
                ' implements I @key(fields: "id") { id: ID! s: String child:'
                " Target }\n"
            ),
        ),
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid for type I.'
                ' Error: Cannot query field "z" on type "I".'
            ),
        ],
    )


def test_non_null_nested_field() raises:
    check(
        _target(
            "$c { n { s } }",
            (
                'type N { s: String }\ntype Owner @key(fields: "id")'
                ' @context(name: "c") { id: ID! child: Target n: N! }\n'
            ),
        ),
        [],
    )


def test_two_fragments_list_shapes() raises:
    check(
        _target(
            "$c { n { ... on N { s } ... on N { t } } }",
            (
                "type N { s: [String!] t: [String] }\ntype Owner @key(fields:"
                ' "id") @context(name: "c") { id: ID! child: Target n: N }\n'
            ),
            "[String]",
        ),
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: the type of the'
                ' selection does not match the expected type "[String]"'
            ),
        ],
    )


comptime _UNION_A = (
    'type A @key(fields: "id") { id: ID! s: String child: Target }\n'
)


def test_union_member_unknown() raises:
    check(
        _target(
            "$c ... on Missing { s }",
            _UNION_A + 'union U @context(name: "c") = A | Missing\n',
        ),
        [
            "[INVALID_GRAPHQL] [a] Unknown type Missing",
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: type conditions'
                " must be an object type"
            ),
            (
                "[INVALID_GRAPHQL] [a] Union type U can only include Object"
                " types, it cannot include Missing."
            ),
        ],
    )


def test_union_member_interface() raises:
    check(
        _target(
            "$c ... on I { s }",
            "interface I { s: String }\n"
            + _UNION_A
            + 'union U @context(name: "c") = A | I\n',
        ),
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: type conditions'
                " must be an object type"
            ),
            (
                "[INVALID_GRAPHQL] [a] Union type U can only include Object"
                " types, it cannot include I."
            ),
        ],
    )


def test_union_no_branch_matches() raises:
    check(
        _target(
            "$c ... on B { s }",
            _UNION_A
            + 'type B { s: String }\nunion U @context(name: "c") = A\n',
        ),
        [
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid: no type'
                ' condition matches the location "U"'
            ),
        ],
    )


def test_owner_implements_unknown_type() raises:
    check(
        _target(
            "$c { z }",
            (
                'type Owner implements Missing @key(fields: "id")'
                ' @context(name: "c") { id: ID! child: Target }\n'
            ),
        ),
        [
            "[INVALID_GRAPHQL] [a] Unknown type Missing",
            (
                '[CONTEXT_INVALID_SELECTION] [a] Context "c" is used in'
                ' "Target.f(x:)" but the selection is invalid for type Owner.'
                ' Error: Cannot query field "z" on type "Owner".'
            ),
            (
                "[INVALID_GRAPHQL] [a] Type Missing must define one or more"
                " fields."
            ),
        ],
    )


def test_implements_object_type() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@context", "@fromContext", "@interfaceObject",'
                    ' "@shareable", "@external"])\ntype Query { a: String }\n'
                    + _OWNER
                    + "type O { f(x: String): Int }\ntype Target implements O"
                    ' @key(fields: "id") { id: ID! f(x: String'
                    ' @fromContext(field: "$c { s }")): Int }\n'
                ),
            ),
        ],
        ["THROWS Expected O to be an interface type"],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
