# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_composition.rules_basic`.

Upstream has no test file for these cases. The expected errors are those of
Hive Federation Composition v0.27.0 `validate` in Node.js on the same
subgraphs.
"""

from _harness import check, sg
from gql_composition.validate import Subgraph
from std.testing import TestSuite


def _field_set(definition: String) raises -> List[Subgraph]:
    return [
        sg(
            "a",
            "extend schema @link(url:"
            ' "https://specs.apollo.dev/federation/v2.0", import: ["@key",'
            ' "FieldSet"])\n\n'
            + definition
            + "\n\ntype Query { a: String }\n",
        )
    ]


def _field_set_error(received: String) -> String:
    return (
        "[TYPE_DEFINITION_INVALID] [a] Invalid definition for type FieldSet:"
        " FieldSet should be a ScalarType but is defined as a "
        + received
    )


def test_field_set_of_each_kind() raises:
    check(
        _field_set("type FieldSet { a: String }"),
        [_field_set_error("ObjectType")],
    )
    check(
        _field_set("interface FieldSet { a: String }"),
        [_field_set_error("InterfaceType")],
    )
    check(
        _field_set("union FieldSet = Query"),
        [_field_set_error("UnionType")],
    )
    check(
        _field_set("enum FieldSet { A }"),
        [_field_set_error("EnumType")],
    )


def test_schema_extension_root_types() raises:
    # A schema extension does not check that its root types exist; the
    # unknown type is reported once, as an unknown type.
    check(
        [
            sg(
                "a",
                (
                    "schema { query: MyQuery }\nextend schema { mutation:"
                    " Missing }\n\ntype MyQuery { a: String }\n"
                ),
            ),
        ],
        ["[INVALID_GRAPHQL] [a] Unknown type Missing"],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\nextend schema { query: MyQuery }\n\ntype'
                    " MyQuery { a: String }\n"
                ),
            ),
        ],
        [
            "[NO_QUERIES] No queries found in any subgraph: a supergraph"
            " must have a query root type."
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
