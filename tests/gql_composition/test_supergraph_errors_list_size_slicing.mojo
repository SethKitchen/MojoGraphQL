# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Checks for `ListSizeSlicingArgumentsRule`.

A slicing argument counts only when every subgraph that defines the field
also defines that argument. Hive's `composeServices` is the source of the
expected errors.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_every_slicing_argument_is_disregarded() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@listSize"])\n\ntype Query {\n  users(first: Int):'
                    ' [String] @listSize(slicingArguments: ["first"])\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@listSize"])\n\ntype Query {\n  users(last: Int):'
                    ' [String] @listSize(slicingArguments: ["last"])\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.users" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a" and "b" and defined as non-shareable in all of'
                " them"
            ),
            (
                "[LIST_SIZE_INVALID_SLICING_ARGUMENT] All arguments for"
                ' @listSize(slicingArguments:) on field "Query.users" were'
                " disregarded. For an argument to be valid, it must be defined"
                " in every subgraph where the field exists."
            ),
        ],
    )


def test_one_shared_slicing_argument_is_enough() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@listSize"])\n\ntype Query {\n  users(first: Int, last:'
                    ' Int): [String] @listSize(slicingArguments: ["first",'
                    ' "last"])\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@listSize"])\n\ntype Query {\n  users(first: Int):'
                    ' [String] @listSize(slicingArguments: ["first"])\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "Query.users" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a" and "b" and defined as non-shareable in all of'
                " them"
            ),
        ],
    )


def test_interface_field_slicing_arguments() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@listSize"])\n\ninterface Node {\n  items(first: Int):'
                    " [String] @listSize(slicingArguments:"
                    ' ["first"])\n}\n\ntype Query {\n  node: Node\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@listSize"])\n\ninterface Node {\n  items(last: Int):'
                    ' [String] @listSize(slicingArguments: ["last"])\n}'
                ),
            ),
        ],
        [
            (
                "[LIST_SIZE_INVALID_SLICING_ARGUMENT] All arguments for"
                ' @listSize(slicingArguments:) on field "Node.items" were'
                " disregarded. For an argument to be valid, it must be defined"
                " in every subgraph where the field exists."
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
