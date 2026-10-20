# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/field_deduplication_test.go`."""

from _norm import *
from _norm_fixtures import *
from std.testing import TestSuite


def test_simple() raises:
    run(
        deduplicate_pass,
        TEST_DEFINITION,
        """
					query conflictingBecauseAlias {
						dog {
							extra { 
								string
								string: noString
								string
								string: noString
							}
						}
					}""",
        """
					query conflictingBecauseAlias {
						dog {
							extra { 
								string
								string: noString
							}
						}
					}""",
    )


def test_with_different_args() raises:
    run(
        deduplicate_pass,
        TEST_DEFINITION,
        """
					fragment mergeIdenticalFieldsWithIdenticalValues on Dog {
						doesKnowCommand(dogCommand: 1)
						doesKnowCommand(dogCommand: 0)
					}""",
        """
					fragment mergeIdenticalFieldsWithIdenticalValues on Dog {
						doesKnowCommand(dogCommand: 1)
						doesKnowCommand(dogCommand: 0)
					}""",
    )


def test_with_internal_defer() raises:
    run(
        deduplicate_pass,
        TEST_DEFINITION,
        """
					query pet {
						pet {
							... on Dog {
								name @__defer_internal(id: 1)
								nickname @__defer_internal(id: 2, parentDeferId: 1)
								nickname @__defer_internal(id: 1)
								barkVolume @__defer_internal(id: 2, parentDeferId: 1)
							}
							... on Cat {
								name @__defer_internal(id: 4)
								name @__defer_internal(id: 3)
								name
								extra {
									bool
									bool @__defer_internal(id: 3)
								}
								meowVolume @__defer_internal(id: 4)
								meowVolume @__defer_internal(id: 3)
								nickname @__defer_internal(id: 4)
							}
						}
					}""",
        """
					query pet {
						pet {
							... on Dog {
								name @__defer_internal(id: 1)
								nickname @__defer_internal(id: 1)
								barkVolume @__defer_internal(id: 2, parentDeferId: 1)
							}
							... on Cat {
								name
								extra {
									bool
								}
								meowVolume @__defer_internal(id: 3)
								nickname @__defer_internal(id: 4)
							}
						}
					}""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
