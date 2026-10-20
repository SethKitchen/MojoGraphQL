# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/fragment_spread_inlining_test.go`."""

from _norm import *
from _norm_fixtures import *
from std.testing import TestSuite


def test_simple_with_inline_selections() raises:
    run_many(
        [fragment_spread_inline_pass, inline_selections_pass],
        TEST_DEFINITION,
        """	
				subscription sub {
					...multipleSubscriptions
				}
				fragment multipleSubscriptions on Subscription {
					newMessage {
						body
						sender
					}
					disallowedSecondRootField
				}""",
        """
				subscription sub {
					newMessage {
						body
						sender
					}
					disallowedSecondRootField
				}
				fragment multipleSubscriptions on Subscription {
					newMessage {
						body
						sender
					}
					disallowedSecondRootField
				}""",
    )


def test_simple_without_inlining_selections() raises:
    run(
        fragment_spread_inline_pass,
        TEST_DEFINITION,
        """	
				subscription sub {
					...multipleSubscriptions
				}
				fragment multipleSubscriptions on Subscription {
					newMessage {
						body
						sender
					}
					disallowedSecondRootField
				}""",
        """
				subscription sub {
					... on Subscription {
						newMessage {
							body
							sender
						}
						disallowedSecondRootField
					}
				}
				fragment multipleSubscriptions on Subscription {
					newMessage {
						body
						sender
					}
					disallowedSecondRootField
				}""",
    )


def test_simple_with_directive() raises:
    run(
        fragment_spread_inline_pass,
        TEST_DEFINITION,
        """	
				subscription sub {
					...multipleSubscriptions @include(if: true)
				}
				fragment multipleSubscriptions on Subscription {
					newMessage {
						body
						sender
					}
					disallowedSecondRootField
				}""",
        """
				subscription sub {
					... on Subscription @include(if: true) {
						newMessage {
							body
							sender
						}
						disallowedSecondRootField
					}
				}
				fragment multipleSubscriptions on Subscription {
					newMessage {
						body
						sender
					}
					disallowedSecondRootField
				}""",
    )


def test_simple_2x() raises:
    run(
        fragment_spread_inline_pass,
        TEST_DEFINITION,
        """	
				subscription sub {
					...multipleSubscriptions
					...multipleSubscriptions
				}
				fragment multipleSubscriptions on Subscription {
					newMessage {
						body
						sender
					}
					disallowedSecondRootField
				}""",
        """
				subscription sub {
					... on Subscription {
						newMessage {
							body
							sender
						}
						disallowedSecondRootField
					}
					... on Subscription {
						newMessage {
							body
							sender
						}
						disallowedSecondRootField
					}
				}
				fragment multipleSubscriptions on Subscription {
					newMessage {
						body
						sender
					}
					disallowedSecondRootField
				}""",
    )


def test_nested() raises:
    run(
        fragment_spread_inline_pass,
        TEST_DEFINITION,
        """	
				subscription sub {
					...frag1
				}
				fragment frag1 on Subscription {
					newMessage {
						body
						sender
					}
					disallowedSecondRootField
					...frag2
				}
				fragment frag2 on Subscription {
					frag2Field
				}""",
        """
				subscription sub {
					... on Subscription {
						newMessage {
							body
							sender
						}
						disallowedSecondRootField
						... on Subscription {
							frag2Field
						}
					}
				}
				fragment frag1 on Subscription {
					newMessage {
						body
						sender
					}
					disallowedSecondRootField
					...frag2
				}
				fragment frag2 on Subscription {
					frag2Field
				}""",
    )


def test_2x_nested() raises:
    run(
        fragment_spread_inline_pass,
        TEST_DEFINITION,
        """	
				subscription sub {
					...frag1
				}
				fragment frag1 on Subscription {
					newMessage {
						body
						sender
						...messageFrag
						sender
						sender
						...nestedMessageFrag
					}
					disallowedSecondRootField
					...frag2
				}
				fragment messageFrag on Message {
					body
					sender
				}
				fragment nestedMessageFrag on Message {
					body
					sender
				}
				fragment frag2 on Subscription {
					frag2Field
				}""",
        """
				subscription sub {
					... on Subscription {
						newMessage {
							body
							sender
							... on Message {
								body
								sender
							}
							sender
							sender
							... on Message {
								body
								sender
							}
						}
						disallowedSecondRootField
						... on Subscription {
							frag2Field
						}
					}
				}
				fragment frag1 on Subscription {
					newMessage {
						body
						sender
						...messageFrag
						sender
						sender
						...nestedMessageFrag
					}
					disallowedSecondRootField
					...frag2
				}
				fragment messageFrag on Message {
					body
					sender
				}
				fragment nestedMessageFrag on Message {
					body
					sender
				}
				fragment frag2 on Subscription {
					frag2Field
				}""",
    )


def test_5x_nested() raises:
    run(
        fragment_spread_inline_pass,
        """
				schema {
					query: Query
				}

				type Query {
					foo: Foo
				}

				type Foo {
					fooName: String
					some: Some
					bar: Bar
				}

				type Bar {
					barName: String
					baz: Baz
				}

				type Baz {
					bazName: String
					some: Some
				}

				type Some {
					something: String
				}
				""",
        """	
				query q {
					...QueryFragment
				}

				fragment QueryFragment on Query {
					foo {
						...FooFragment
					}
				}

				fragment SomeFragment on Some {
					something
				}

				fragment FooFragment on Foo {
					fooName
					some {
						...SomeFragment
					}
					bar {
						...BarFragment
					}
				}
				
				fragment BarFragment on Bar {
					barName
					baz {
						...BazFragment
					}
				}
				
				fragment BazFragment on Baz {
					bazName
					some {
						...SomeFragment
					}
				}""",
        """	
				query q {
					... on Query {
						foo {
							... on Foo {	
								fooName
								some {
									... on Some {
										something
									}
								}
								bar {
									... on Bar {
										barName
										baz {
											... on Baz {
												bazName
												some {
													... on Some {
														something
													}
												}
											}
										}
									}
								}
							}
						}
					}
				}

				fragment QueryFragment on Query {
					foo {
						...FooFragment
					}
				}

				fragment SomeFragment on Some {
					something
				}

				fragment FooFragment on Foo {
					fooName
					some {
						...SomeFragment
					}
					bar {
						...BarFragment
					}
				}
				
				fragment BarFragment on Bar {
					barName
					baz {
						...BazFragment
					}
				}
				
				fragment BazFragment on Baz {
					bazName
					some {
						...SomeFragment
					}
				}""",
    )


def test_merge_fields_interface_fields_into_selection_if_type_implements_interface() raises:
    run(
        fragment_spread_inline_pass,
        TEST_DEFINITION,
        """
				{
					dog {
						...definedOnImplementorsButNotInterface
					}
				}
				fragment definedOnImplementorsButNotInterface on Pet {
					name
				}""",
        """
				{
					dog {
						... on Pet {
							name
						}
					}
				}
				fragment definedOnImplementorsButNotInterface on Pet {
					name
				}""",
    )


def test_inline_fragments_if_fragment_type_definition_implements_enclosing_type_definition() raises:
    run(
        fragment_spread_inline_pass,
        TEST_DEFINITION,
        """
				query conflictingDifferingResponses {
					pet {
						...conflictingDifferingResponses
					}
				}
				fragment conflictingDifferingResponses on Pet {
					...dogFrag
					...catFrag
				}
				fragment dogFrag on Dog {
					someValue: nickname
				}
				fragment catFrag on Cat {
					someValue: meowVolume
				}""",
        """
				query conflictingDifferingResponses {
					pet {
						... on Pet {
							... on Dog {
								someValue: nickname	
							}
							... on Cat {
								someValue: meowVolume
							}
						}
					}
				}
				fragment conflictingDifferingResponses on Pet {
					...dogFrag
					...catFrag
				}
				fragment dogFrag on Dog {
					someValue: nickname
				}
				fragment catFrag on Cat {
					someValue: meowVolume
				}""",
    )


def test_inline_fragment_if_fragment_type_is_member_of_enclosing_union_type() raises:
    run(
        fragment_spread_inline_pass,
        TEST_DEFINITION,
        """
				query conflictingDifferingResponses {
					catOrDog {
						...catDogFrag
					}
				}
				fragment catDogFrag on CatOrDog {
					...catFrag
					...dogFrag
				}
				fragment catFrag on Cat {
					someValue: meowVolume
				}
				fragment dogFrag on Dog {
					someValue: name
				}""",
        """
				query conflictingDifferingResponses {
					catOrDog {
						... on CatOrDog {
							... on Cat {
								someValue: meowVolume							
							}
							... on Dog {
								someValue: name
							}
						}
					}
				}
				fragment catDogFrag on CatOrDog {
					...catFrag
					...dogFrag
				}
				fragment catFrag on Cat {
					someValue: meowVolume
				}
				fragment dogFrag on Dog {
					someValue: name
				}""",
    )


def test_inline_fragment_of_outer_enclosing_type_inside_union_fragment_could_be_inlined_if_enclosing_type_is_member_of_union_fragment() raises:
    run(
        fragment_spread_inline_pass,
        TEST_DEFINITION,
        """
				{
					dog {
						...fragOnObject
						...fragOnInterface
						...fragOnUnion
					}
				}
				fragment fragOnObject on Dog {
					name
				}
				fragment fragOnInterface on Pet {
					name
				}
				fragment fragOnUnion on CatOrDog {
					... on Dog {
						name
					}
				}""",
        """
				{
				dog {
						... on Dog {
							name
						}
						... on Pet  {
							name
						}
						... on CatOrDog {
							... on Dog {
								name
							}
						}
					}
				}
				fragment fragOnObject on Dog {
					name
				}
				fragment fragOnInterface on Pet {
					name
				}
				fragment fragOnUnion on CatOrDog {
					... on Dog {
						name
					}
				}""",
    )


def test_type_inside_union_inside_type() raises:
    run(
        fragment_spread_inline_pass,
        TEST_DEFINITION,
        """
				{
					dog {
						...unionWithObjectFragment
					}
				}
				fragment catOrDogNameFragment on CatOrDog {
					... on Cat {
						meowVolume
					}
				}
				fragment unionWithObjectFragment on Dog {
					...catOrDogNameFragment
				}""",
        """
				{
					dog {
						... on Dog {
							... on CatOrDog {
								... on Cat {
									meowVolume
								}
							}
						}
					}
				}
				fragment catOrDogNameFragment on CatOrDog {
					... on Cat {
						meowVolume
					}
				}
				fragment unionWithObjectFragment on Dog {
					...catOrDogNameFragment
				}""",
    )


def test_inline_fragment_inside_union_inside_interface_inside_type() raises:
    run(
        fragment_spread_inline_pass,
        TEST_DEFINITION,
        """
				{
					dog {
						...unionWithInterface
					}
				}
				fragment unionWithInterface on Pet {
					...dogOrHumanFragment
				}
				fragment dogOrHumanFragment on DogOrHuman {
					... on Dog {
						barkVolume
					}
				}""",
        """
				{
					dog {
						... on Pet {
							... on DogOrHuman {
								... on Dog {
									barkVolume
								}
							}
						}
					}
				}
				fragment unionWithInterface on Pet {
					...dogOrHumanFragment
				}
				fragment dogOrHumanFragment on DogOrHuman {
					... on Dog {
						barkVolume
					}
				}""",
    )


def test_inline_fragment_inside_interface_inside_union_inside_type() raises:
    run(
        fragment_spread_inline_pass,
        TEST_DEFINITION,
        """
				{
					dog {
						...interfaceWithUnion
					}
				}
				fragment interfaceWithUnion on DogOrHuman {
					...petFragment
				}
				fragment petFragment on Pet {
					... on Dog {
						barkVolume
					}
				}""",
        """
				{
					dog {
						... on DogOrHuman {
							... on Pet {
								... on Dog {
									barkVolume
								}
							}
						}
					}
				}
				fragment interfaceWithUnion on DogOrHuman {
					...petFragment
				}
				fragment petFragment on Pet {
					... on Dog {
						barkVolume
					}
				}""",
    )


def test_non_intersecting_interfaces_shouldn_t_merge() raises:
    run(
        fragment_spread_inline_pass,
        TEST_DEFINITION,
        """
				{
					dog {
						...nonIntersectingInterfaces
					}
				}
				fragment nonIntersectingInterfaces on Pet {
					...sentientFragment # invalid fragment spread, but doesn't matter for test
				}
				fragment sentientFragment on Sentient {
					name
				}""",
        """
				{
					dog {
						... on Pet {
							...sentientFragment # invalid fragment spread, but doesn't matter for test
						}
					}
				}
				fragment nonIntersectingInterfaces on Pet {
					...sentientFragment
				}
				fragment sentientFragment on Sentient {
					name
				}""",
    )


def test_implicitly_intersecting_interfaces_should_merge() raises:
    run(
        fragment_spread_inline_pass,
        """
				schema {
					query: Query
				}

				type Query {
					root: FaceA
				}

				interface FaceA {
					fieldA: String
				}

				interface FaceB {
					fieldB: String
				}

				type SomeType implements FaceA & FaceB {
					fieldA: String
					fieldB: String
				}
		""",
        """
				{
					root {
						...faceAFragment
					}
				}

				fragment faceAFragment on FaceA {
					__typename
					fieldA
					...faceBFragment
				}

				fragment faceBFragment on FaceB {
					fieldB
				}

				""",
        """

				{
					root {
						... on FaceA {
							__typename
							fieldA
							... on FaceB {
								fieldB
							}
						}
					}
				}

				fragment faceAFragment on FaceA {
					__typename
					fieldA
					...faceBFragment
				}

				fragment faceBFragment on FaceB {
					fieldB
				}
		""",
    )


def test_with_nested_compatible_fragments_with_include() raises:
    run(
        inline_selections_pass,
        TEST_DEFINITION,
        """
					query Q($includeName: Boolean!) {
						pet {
							... on Dog {
								... on Dog {
									owner {
										name
									}
								}
								... on Dog @include(if: $includeName){
									nickname
								}
							}
						}
					}""",
        """
					query Q($includeName: Boolean!) {
						pet {
							... on Dog {
								owner {
									name
								}
								... on Dog @include(if: $includeName){
									nickname
								}
							}
						}
					}""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
