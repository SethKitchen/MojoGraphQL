# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/inline_fragment_selection_merging_test.go`."""

from _norm import *
from _norm_fixtures import *
from std.testing import TestSuite


def test_just_fragments_fragments_with_the_same_field() raises:
    run(
        merge_pass,
        TEST_DEFINITION,
        """
					query a {
						pet {
							... on Dog {
								name
							}
							... on Dog {
								name
							}
							... on Dog {
								name
							}
						}
					}""",
        """
					query a {
						pet {
							... on Dog {
								name
								name
								name
							}
						}
					}""",
    )


def test_just_fragments_fragments_with_different_fields() raises:
    run(
        merge_pass,
        TEST_DEFINITION,
        """
					query a {
						pet {
							... on Dog {
								name
							}
							... on Dog {
								nickname
							}
							... on Dog {
								barkVolume
							}
						}
					}""",
        """
					query a {
						pet {
							... on Dog {
								name
								nickname
								barkVolume
							}
						}
					}""",
    )


def test_just_fragments_fragments_with_different_types() raises:
    run(
        merge_pass,
        TEST_DEFINITION,
        """
					query a {
						pet {
							... on Dog {
								name
							}
							... on Cat {
								name
							}
						}
					}""",
        """
					query a {
						pet {
							... on Dog {
								name
							}
							... on Cat {
								name
							}
						}
					}""",
    )


def test_just_fragments_fragments_with_different_directives() raises:
    run(
        merge_pass,
        TEST_DEFINITION,
        """
					query a {
						pet {
							... on Dog @skip(if: $foo) {
								name
							}
							... on Dog @skip(if: $bar) {
								nickname
							}
						}
					}""",
        """
					query a {
						pet {
							... on Dog @skip(if: $foo) {
								name
							}
							... on Dog @skip(if: $bar) {
								nickname
							}
						}
					}""",
    )


def test_just_fragments_fragments_with_the_same_directives() raises:
    run(
        merge_pass,
        TEST_DEFINITION,
        """
					query a {
						pet {
							... on Dog @skip(if: $foo) {
								name
							}
							... on Dog @skip(if: $foo) {
								nickname
							}
						}
					}""",
        """
					query a {
						pet {
							... on Dog @skip(if: $foo) {
								name
								nickname
							}
						}
					}""",
    )


def test_just_fields_depth_1() raises:
    run(
        merge_pass,
        TEST_DEFINITION,
        """
					query conflictingBecauseAlias {
						dog {
							extra { string }
							extra { noString: string }
						}
					}""",
        """
					query conflictingBecauseAlias {
						dog {
							extra { 
								string
								noString: string
							}
						}
					}""",
    )


def test_just_fields_depth_2() raises:
    run(
        merge_pass,
        TEST_DEFINITION,
        """
					query conflictingBecauseAlias {
						dog {
							extra { string }
							extra { string: noString }
						}
						dog {
							extra { string }
							extra { string: noString }
						}
					}""",
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
    )


def test_just_fields_aliased() raises:
    run(
        merge_pass,
        TEST_DEFINITION,
        """
					query conflictingBecauseAlias {
						dog {
							x: extras { string }
							x: mustExtras { string }
						}
					}""",
        """
					query conflictingBecauseAlias {
						dog {
							x: extras { string }
							x: mustExtras { string }
						}
					}""",
    )


def test_just_fields_fields_with_directives() raises:
    run(
        merge_pass,
        TEST_DEFINITION,
        """
					{
						field @skip(if: $foo) {
							subfieldA
						}
						field @skip(if: $bar) {
							subfieldB
						}
					}""",
        """
					{
						field @skip(if: $foo) {
							subfieldA
						}
						field @skip(if: $bar) {
							subfieldB
						}
					}""",
    )


def test_just_fields_fields_with_the_same_directives() raises:
    run(
        merge_pass,
        TEST_DEFINITION,
        """
					{
						field @skip(if: $foo) {
							subfieldA
						}
						field @skip(if: $foo) {
							subfieldB
						}
					}""",
        """
					{
						field @skip(if: $foo) {
							subfieldA
							subfieldB
						}
					}""",
    )


def test_just_fields_fields_with_the_same_directives_but_in_different_order() raises:
    run(
        merge_pass,
        TEST_DEFINITION,
        """
					{
						field @skip(if: $foo) @include(if: $foo) {
							subfieldA
						}
						field  @include(if: $foo) @skip(if: $foo) {
							subfieldB
						}
					}""",
        """
					{
						field @skip(if: $foo) @include(if: $foo) {
							subfieldA
							subfieldB
						}
					}""",
    )


def test_fragments_and_fields_field_field_fragment() raises:
    run(
        merge_pass,
        TEST_DEFINITION,
        """
					query fragmentsWithFields {
						dog {
							extras { 
								... on DogExtra {
									string 
								}
							}
							extras { 
								... on DogExtra {
									string 
									string1
								}
							}
						}
					}""",
        """
					query fragmentsWithFields {
						dog {
							extras { 
								... on DogExtra {
									string 
									string
									string1
								}
							}
						}
					}""",
    )


def test_fragments_and_fields_mixed_heavily_fields_with_deep_inline_fragments() raises:
    run(
        merge_pass,
        TEST_DEFINITION,
        """
					query mixedFragmentTypes {
						pet {
							... on Dog {
								name
							}
						}
						pet {
							... on Dog {
								extras { 
									... on DogExtra {
										string 
									}
								}
							}
						}
						pet {
							... on Dog {
								name
								barkVolume
							}
						}
						pet {
							... on Dog {
								extras { 
									... on DogExtra {
										string1
									}
								}
							}
						}
						pet {
							... on Cat {
								name
							}
						}
						pet {
							... on Dog {
								name
								barkVolume
								owner {
									name
								}
							}
						}
						pet {
							... on Cat {
								meowVolume
							}
						}
						pet {
							... on Cat {
								meowVolume
							}
						}
					}""",
        """
					query mixedFragmentTypes {
						pet {
							... on Dog {
								name
								extras {
									... on DogExtra {
										string
										string1
									}
								}
								name
								barkVolume
								name
								barkVolume
								owner {
									name
								}
							}
							... on Cat {
								name
								meowVolume
								meowVolume
							}
						}
					}""",
    )


def test_fragments_and_fields_with_internal_defer() raises:
    run(
        merge_pass,
        TEST_DEFINITION,
        """
					query pet {
						pet {
							... on Dog {
								name @__defer_internal(id: 1)
								nickname @__defer_internal(id: 1)
								nickname @__defer_internal(id: 2, parentDeferId: 1)
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
								name
								extra {
									bool
								}
							}
							... on Cat {
								name @__defer_internal(id: 5)
								meowVolume @__defer_internal(id: 5)
								extra @__defer_internal(id: 5) {
									bool @__defer_internal(id: 5)
								}
							}
							... on Cat {
								name @__defer_internal(id: 6)
								nickname @__defer_internal(id: 6)
								meowVolume @__defer_internal(id: 6)
							}
						}
					}""",
        """
					query pet {
						pet {
							... on Dog {
								name @__defer_internal(id: 1)
								nickname @__defer_internal(id: 1)
								nickname @__defer_internal(id: 2, parentDeferId: 1)
								barkVolume @__defer_internal(id: 2, parentDeferId: 1)
								extra @__defer_internal(id: 3) {	
									noString @__defer_internal(id: 3)
									string @__defer_internal(id: 4)
									noString @__defer_internal(id: 4)
								}
							}
							... on Cat {
								name
								extra {
									bool
									bool @__defer_internal(id: 5)
								}
								name @__defer_internal(id: 5)
								meowVolume @__defer_internal(id: 5)
								name @__defer_internal(id: 6)
								nickname @__defer_internal(id: 6)
								meowVolume @__defer_internal(id: 6)
							}
						}
					}""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
