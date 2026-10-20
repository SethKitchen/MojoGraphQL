# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/defer_align_typename_scope_test.go`.

The tests that start with `test_extra` are extra. Their outputs are the
outputs of the upstream visitor.
"""

from _norm import *
from _norm_fixtures import *
from gql_language.ast import Document
from gql_normalization.defer import defer_align_typename_scope
from gql_schema.definition import Schema
from std.testing import TestSuite


def align_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `deferAlignTypenameScope`."""
    defer_align_typename_scope(document)


def test_deferred_typename_on_non_deferred_object_defer_stripped() raises:
    run(
        align_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog {
					__typename @__defer_internal(id: 1)
					name @__defer_internal(id: 1)
				}
			}""",
        """
			query dog {
				dog {
					__typename
					name @__defer_internal(id: 1)
				}
			}""",
    )


def test_deferred_typename_on_object_in_same_defer_unchanged() raises:
    run(
        align_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog @__defer_internal(id: 1) {
					__typename @__defer_internal(id: 1)
					name @__defer_internal(id: 1)
				}
			}""",
        """
			query dog {
				dog @__defer_internal(id: 1) {
					__typename @__defer_internal(id: 1)
					name @__defer_internal(id: 1)
				}
			}""",
    )


def test_typename_deferred_deeper_than_its_object_realigned_to_object_scope() raises:
    run(
        align_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog @__defer_internal(id: 1) {
					extra @__defer_internal(id: 1) {
						__typename @__defer_internal(id: 2, parentDeferId: 1)
						string @__defer_internal(id: 2, parentDeferId: 1)
					}
				}
			}""",
        """
			query dog {
				dog @__defer_internal(id: 1) {
					extra @__defer_internal(id: 1) {
						__typename @__defer_internal(id: 1)
						string @__defer_internal(id: 2, parentDeferId: 1)
					}
				}
			}""",
    )


def test_root_level_deferred_typename_defer_stripped() raises:
    run(
        align_pass,
        TEST_DEFINITION,
        """
			query dog {
				__typename @__defer_internal(id: 1)
				dog {
					name
				}
			}""",
        """
			query dog {
				__typename
				dog {
					name
				}
			}""",
    )


def test_no_deferred_fields_no_change() raises:
    run(
        align_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog {
					__typename
					name
				}
			}""",
        """
			query dog {
				dog {
					__typename
					name
				}
			}""",
    )


def test_extra_label_and_parent_copied_from_the_object() raises:
    run(
        align_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog @__defer_internal(id: 3, label: "l", parentDeferId: 1) {
					... on Dog {
						__typename @include(if: true) @__defer_internal(id: 4)
					}
				}
				pet @__defer_internal(id: 5, label: 7, parentDeferId: "p") {
					__typename @__defer_internal(id: 6)
				}
			}""",
        """
			query dog {
				dog @__defer_internal(id: 3, label: "l", parentDeferId: 1) {
					... on Dog {
						__typename @include(if: true) @__defer_internal(id: 3, label: "l", parentDeferId: 1)
					}
				}
				pet @__defer_internal(id: 5, label: 7, parentDeferId: "p") {
					__typename @__defer_internal(id: 5)
				}
			}""",
    )


def test_extra_zero_ids() raises:
    run(
        align_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog @__defer_internal(id: 0) {
					__typename @__defer_internal(id: 0)
				}
				pet @__defer_internal(id: 2) {
					__typename @__defer_internal(id: 0)
				}
			}""",
        """
			query dog {
				dog @__defer_internal(id: 0) {
					__typename
				}
				pet @__defer_internal(id: 2) {
					__typename @__defer_internal(id: 2)
				}
			}""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
