# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/defer_populate_parent_ids_test.go`.

The tests that start with `test_extra` are extra. Their outputs are the
outputs of the upstream visitor.
"""

from _norm import *
from _norm_fixtures import *
from gql_language.ast import Document
from gql_normalization.defer import defer_populate_parent_ids
from gql_schema.definition import Schema
from std.testing import TestSuite


def populate_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `deferPopulateParentIds`."""
    defer_populate_parent_ids(document)


def test_no_deferred_fields_no_change() raises:
    run(
        populate_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog {
					name
				}
			}""",
        """
			query dog {
				dog {
					name
				}
			}""",
    )


def test_single_top_level_defer_no_parent_to_assign() raises:
    run(
        populate_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog @__defer_internal(id: 1) {
					name @__defer_internal(id: 1)
				}
			}""",
        """
			query dog {
				dog @__defer_internal(id: 1) {
					name @__defer_internal(id: 1)
				}
			}""",
    )


def test_genuinely_nested_defers_inner_gets_parent_defer_id_from_outer() raises:
    run(
        populate_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog @__defer_internal(id: 1) {
					name @__defer_internal(id: 2)
				}
			}""",
        """
			query dog {
				dog @__defer_internal(id: 1) {
					name @__defer_internal(id: 2, parentDeferId: 1)
				}
			}""",
    )


def test_parallel_defers_merged_into_one_tree_sibling_gets_parent_defer_id_from_winning_group() raises:
    run(
        populate_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog @__defer_internal(id: 1) {
					name @__defer_internal(id: 1)
					nickname @__defer_internal(id: 2)
				}
			}""",
        """
			query dog {
				dog @__defer_internal(id: 1) {
					name @__defer_internal(id: 1)
					nickname @__defer_internal(id: 2, parentDeferId: 1)
				}
			}""",
    )


def test_parallel_defers_at_depth_nested_sibling_gets_correct_parent_defer_id() raises:
    run(
        populate_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog @__defer_internal(id: 1) {
					extra @__defer_internal(id: 1) {
						noString @__defer_internal(id: 1)
						string @__defer_internal(id: 2)
					}
				}
			}""",
        """
			query dog {
				dog @__defer_internal(id: 1) {
					extra @__defer_internal(id: 1) {
						noString @__defer_internal(id: 1)
						string @__defer_internal(id: 2, parentDeferId: 1)
					}
				}
			}""",
    )


def test_stale_parent_defer_id_discarded_into_non_deferred_path_parent_removed() raises:
    run(
        populate_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog {
					extra {
						string @__defer_internal(id: 2, parentDeferId: 1)
					}
				}
			}""",
        """
			query dog {
				dog {
					extra {
						string @__defer_internal(id: 2)
					}
				}
			}""",
    )


def test_stale_parent_defer_id_merged_into_enclosing_defer_parent_repaired() raises:
    run(
        populate_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog @__defer_internal(id: 1) {
					extra @__defer_internal(id: 1) {
						string @__defer_internal(id: 3, parentDeferId: 2)
					}
				}
			}""",
        """
			query dog {
				dog @__defer_internal(id: 1) {
					extra @__defer_internal(id: 1) {
						string @__defer_internal(id: 3, parentDeferId: 1)
					}
				}
			}""",
    )


def test_valid_sibling_parent_defer_id_still_present_preserved() raises:
    run(
        populate_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog {
					name @__defer_internal(id: 1)
					nickname @__defer_internal(id: 2, parentDeferId: 1)
				}
			}""",
        """
			query dog {
				dog {
					name @__defer_internal(id: 1)
					nickname @__defer_internal(id: 2, parentDeferId: 1)
				}
			}""",
    )


def test_extra_stale_parent_with_only_the_same_id_above() raises:
    run(
        populate_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog @__defer_internal(id: 2) {
					name
					... on Dog {
						nickname @__defer_internal(id: 2, parentDeferId: 9)
						barkVolume @__defer_internal(id: 3, parentDeferId: "x")
					}
				}
			}""",
        """
			query dog {
				dog @__defer_internal(id: 2) {
					name
					... on Dog {
						nickname @__defer_internal(id: 2)
						barkVolume @__defer_internal(id: 3, parentDeferId: "x")
					}
				}
			}""",
    )


def test_extra_fragment_definition_ids_are_not_live() raises:
    run(
        populate_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog {
					...DogFields
				}
			}
			fragment DogFields on Dog {
				name @__defer_internal(id: 1)
				nickname @__defer_internal(id: 2, parentDeferId: 1)
			}
			scalar Extra""",
        """
			query dog {
				dog {
					...DogFields
				}
			}
			fragment DogFields on Dog {
				name @__defer_internal(id: 1)
				nickname @__defer_internal(id: 2)
			}
			scalar Extra""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
