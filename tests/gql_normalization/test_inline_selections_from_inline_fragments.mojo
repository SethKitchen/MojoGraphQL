# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/inline_selections_from_inline_fragments_test.go`."""

from _norm import *
from _norm_fixtures import *
from std.testing import TestSuite


def test_simple() raises:
    run(
        inline_selections_pass,
        TEST_DEFINITION,
        """
					query conflictingBecauseAlias {
						dog {
							... {
								name
							}
							... on Dog {
								nickname
							}
							... {
								... {
									doubleNested
									... on Dog {
										nestedDogName
									}
								}
							}
							extra { string }
							extra { string: noString }
						}
					}""",
        """
					query conflictingBecauseAlias {
						dog {
							name
							nickname
							doubleNested
							nestedDogName
							extra { string }
							extra { string: noString }
						}
					}""",
    )


def test_with_interface_type() raises:
    run(
        inline_selections_pass,
        TEST_DEFINITION,
        """
					query conflictingBecauseAlias {
						dog {
							... on Pet {
								name
							}
						}
					}""",
        """
					query conflictingBecauseAlias {
						dog {
							name
						}
					}""",
    )


def test_with_nested_non_compatible_fragments() raises:
    run(
        inline_selections_pass,
        TEST_DEFINITION,
        """
					{
						dog {
							... on Pet {
								... on Cat {
									meowVolume
								}
							}
						}
					}""",
        """
					{
						dog {
							... on Pet {
								... on Cat {
									meowVolume
								}
							}
						}
					}""",
    )


def test_with_nested_compatible_fragments() raises:
    run(
        inline_selections_pass,
        TEST_DEFINITION,
        """
					{
						dog {
							... on Pet {
								... on Dog {
									name
								}
							}
						}
					}""",
        """
					{
						dog {
							name
						}
					}""",
    )


def test_with_internal_defer() raises:
    run(
        inline_selections_pass,
        TEST_DEFINITION,
        """
					query pet {
						pet {
							... on Dog {
								name @__defer_internal(id: 1)
								nickname @__defer_internal(id: 1)
								... {
									barkVolume @__defer_internal(id: 2, parentDeferId: 1)
								}
							}
							... on Dog {
								... {
									extra @__defer_internal(id: 3) {	
										noString @__defer_internal(id: 3)
									}
								}
								... {
									extra @__defer_internal(id: 4) {	
										string @__defer_internal(id: 4)
										noString @__defer_internal(id: 4)
									}
								}
							}
							... on Cat {
								name @__defer_internal(id: 5)
								meowVolume @__defer_internal(id: 5)
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
							... on Dog {
								extra @__defer_internal(id: 3) {	
									noString @__defer_internal(id: 3)
								}
								extra @__defer_internal(id: 4) {	
									string @__defer_internal(id: 4)
									noString @__defer_internal(id: 4)
								}
							}
							... on Cat {
								name @__defer_internal(id: 5)
								meowVolume @__defer_internal(id: 5)
							}
						}
					}""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
