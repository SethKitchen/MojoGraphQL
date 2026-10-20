# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2 `v2/pkg/astnormalization`:
`object_type_extending_test.go`, `input_object_type_extending_test.go`,
`enum_type_extending_test.go`, `interface_type_extending_test.go`,
`scalar_type_extending_test.go` and `union_type_extending_test.go`.
"""

from _def_norm import *
from std.testing import TestSuite


def test_extend_object_type_by_field() raises:
    run_def(
        object_pass,
        """
					type Dog {
						name: String
					}
					extend type Dog {
						favoriteToy: String
					}
					 """,
        """
					type Dog {
						name: String
						favoriteToy: String
					}
					extend type Dog {
						favoriteToy: String
					}
					""",
    )


def test_extend_object_type_by_directive() raises:
    run_def(
        object_pass,
        """
					type Cat {
						name: String
					}
					extend type Cat @deprecated(reason: "not as cool as dogs")
					 """,
        """
					type Cat @deprecated(reason: "not as cool as dogs") {
						name: String
					}
					extend type Cat @deprecated(reason: "not as cool as dogs")
					""",
    )


def test_extend_object_type_by_multiple_field() raises:
    run_def(
        object_pass,
        """
					type Dog {
						name: String
					}
					extend type Dog {
						favoriteToy: String
						breed: String
					}
					 """,
        """
					type Dog {
						name: String
						favoriteToy: String
						breed: String
					}
					extend type Dog {
						favoriteToy: String
						breed: String
					}
					""",
    )


def test_extend_object_type_by_multiple_directives() raises:
    run_def(
        object_pass,
        """
					type Cat {
						name: String
					}
					extend type Cat @deprecated(reason: "not as cool as dogs") @skip(if: false)
					 """,
        """
					type Cat @deprecated(reason: "not as cool as dogs") @skip(if: false) {
						name: String
					}
					extend type Cat @deprecated(reason: "not as cool as dogs") @skip(if: false)
					""",
    )


def test_extend_object_type_by_complex_extends() raises:
    run_def(
        object_pass,
        """
					type Cat {
						name: String
					}
					extend type Cat @deprecated(reason: "not as cool as dogs") @skip(if: false) {
						age: Int
						breed: String
					}
					 """,
        """
					type Cat @deprecated(reason: "not as cool as dogs") @skip(if: false) {
						name: String
						age: Int
						breed: String
					}
					extend type Cat @deprecated(reason: "not as cool as dogs") @skip(if: false) {
						age: Int
						breed: String
					}
					""",
    )


def test_extend_missing_object_type_definition() raises:
    run_def(
        object_pass,
        """
			extend type Query {	me: String }
			extend type Cat @deprecated(reason: "not as cool as dogs") @skip(if: false) { age: Int breed: String }
			""",
        """
			extend type Query { me: String }
			extend type Cat @deprecated(reason: "not as cool as dogs") @skip(if: false) { age: Int breed: String }
			type Query { me: String	}
			type Cat @deprecated(reason: "not as cool as dogs") @skip(if: false) { age: Int breed: String }
			""",
    )


def test_extend_object_type_by_interface() raises:
    run_def(
        object_pass,
        """
					type Dog {
						name: String
					}
					extend type Dog implements ToyLover {
						favoriteToy: String
					}
					interface ToyLover {
						favoriteToy: String
					}
					 """,
        """
					type Dog implements ToyLover {
						name: String
						favoriteToy: String
					}
					extend type Dog implements ToyLover {
						favoriteToy: String
					}
					interface ToyLover {
						favoriteToy: String
					}
					""",
    )


def test_extend_object_type_which_implements_interface_by_interface() raises:
    run_def(
        object_pass,
        """
					type Dog implements ToyHater {
						name: String
						hatedToy: String
					}
					extend type Dog implements ToyLover {
						favoriteToy: String
					}
					interface ToyLover {
						favoriteToy: String
					}
					interface ToyHater {
						hatedToy: String
					}
					 """,
        """
					type Dog implements ToyHater & ToyLover {
						name: String
						hatedToy: String
						favoriteToy: String
					}
					extend type Dog implements ToyLover {
						favoriteToy: String
					}
					interface ToyLover {
						favoriteToy: String
					}
					interface ToyHater {
						hatedToy: String
					}
					""",
    )


def test_extend_input_object_type_by_directive() raises:
    run_def(
        input_object_pass,
        """
					input DogSize {width: Float height: Float}
					extend input DogSize @deprecated(reason: "some reason")
					 """,
        """
					input DogSize @deprecated(reason: "some reason") {width: Float height: Float}
					extend input DogSize @deprecated(reason: "some reason")
					""",
    )


def test_extend_input_object_type_by_input_fields_definition() raises:
    run_def(
        input_object_pass,
        """
					input DogSize {width: Float height: Float}
					extend input DogSize {breadth: Float}
					 """,
        """
					input DogSize {width: Float height: Float, breadth: Float}
					extend input DogSize {breadth: Float}
					""",
    )


def test_extend_input_object_type_by_multiple_input_fields_definition_and_directives() raises:
    run_def(
        input_object_pass,
        """
					input DogSize {width: Float height: Float}
					extend input DogSize @deprecated(reason: "some reason") @skip(if: false) {breadth: Float weight: Float}
					 """,
        """
					input DogSize @deprecated(reason: "some reason") @skip(if: false) {width: Float height: Float breadth: Float weight: Float}
					extend input DogSize @deprecated(reason: "some reason") @skip(if: false) {breadth: Float weight: Float}
					""",
    )


def test_extend_non_existent_input_object_type() raises:
    run_def(
        input_object_pass,
        """
					extend input Location { lat: Float lon: Float }
					extend input DogSize @deprecated(reason: "some reason") @skip(if: false) {breadth: Float weight: Float}
					 """,
        """
					extend input Location { lat: Float lon: Float }
					extend input DogSize @deprecated(reason: "some reason") @skip(if: false) {breadth: Float weight: Float}
					input Location { lat: Float lon: Float }
					input DogSize @deprecated(reason: "some reason") @skip(if: false) {breadth: Float weight: Float}
					""",
    )


def test_extend_enum_type_by_directive() raises:
    run_def(
        enum_pass,
        """
					enum Countries {DE ES NL}
					extend enum Countries @deprecated(reason: "some reason")
					 """,
        """
					enum Countries @deprecated(reason: "some reason") {DE ES NL} 
					extend enum Countries @deprecated(reason: "some reason")
					""",
    )


def test_extend_enum_type_by_enum_values() raises:
    run_def(
        enum_pass,
        """
					enum Countries {DE ES NL}
					extend enum Countries {EN}
					 """,
        """
					enum Countries {DE ES NL EN}
					extend enum Countries {EN}
					""",
    )


def test_extend_enum_type_by_multiple_enum_values_and_directives() raises:
    run_def(
        enum_pass,
        """
					enum Countries {DE ES NL}
					extend enum Countries @deprecated(reason: "some reason") @skip(if: false) {EN IT}
					 """,
        """
					enum Countries @deprecated(reason: "some reason") @skip(if: false) {DE ES NL EN IT}
					extend enum Countries @deprecated(reason: "some reason") @skip(if: false) {EN IT}
					""",
    )


def test_extend_non_existent_enum_type() raises:
    run_def(
        enum_pass,
        """
					extend enum Planet { EARTH MARS }
					extend enum Countries @deprecated(reason: "some reason") @skip(if: false) {EN IT}
					 """,
        """
					extend enum Planet { EARTH MARS }
					extend enum Countries @deprecated(reason: "some reason") @skip(if: false) {EN IT}
					enum Planet { EARTH MARS }
					enum Countries @deprecated(reason: "some reason") @skip(if: false) {EN IT}
					""",
    )


def test_extend_simple_interface_type_by_field() raises:
    run_def(
        interface_pass,
        """
					interface Mammal {
						name: String
					}
					extend interface Mammal {
						furType: String
					}
					 """,
        """
					interface Mammal {
						name: String
						furType: String
					}
					extend interface Mammal {
						furType: String
					}
					""",
    )


def test_extend_interface_by_implements_interface() raises:
    run_def(
        interface_pass,
        """
					interface A {
						name: String
					}
					extend interface A implements B {
						age: Int
					}
					interface B {
						age: Int
					}
					 """,
        """
					interface A implements B {
						name: String
						age: Int
					}
					extend interface A implements B {
						age: Int
					}
					interface B {
						age: Int
					}
					""",
    )


def test_extend_interface_by_implements_interface_and_field() raises:
    run_def(
        interface_pass,
        """
					interface A {
						name: String
					}
					extend interface A implements B {
						field: String
						age: Int
					}
					interface B {
						age: Int
					}
					 """,
        """
					interface A implements B {
						name: String
						field: String
						age: Int
					}
					extend interface A implements B {
						field: String
						age: Int
					}
					interface B {
						age: Int
					}
					""",
    )


def test_extend_simple_interface_type_by_directive() raises:
    run_def(
        interface_pass,
        """
					interface Mammal {
						name: String
					}
					extend interface Mammal @deprecated(reason: "some reason")
					 """,
        """
					interface Mammal @deprecated(reason: "some reason") {
						name: String
					}
					extend interface Mammal @deprecated(reason: "some reason")
					""",
    )


def test_extend_interface_type_by_complex_extends() raises:
    run_def(
        interface_pass,
        """
					interface Mammal {
						name: String
					}
					extend interface Mammal @deprecated(reason: "some reason") @skip(if: false) {
						furType: String
						age: Int
					}
					 """,
        """
					interface Mammal @deprecated(reason: "some reason") @skip(if: false) {
						name: String
						furType: String
						age: Int
					}
					extend interface Mammal @deprecated(reason: "some reason") @skip(if: false) {
						furType: String
						age: Int
					}
					""",
    )


def test_extend_non_existent_interface() raises:
    run_def(
        interface_pass,
        """
					extend interface Entity { id: ID }
					extend interface Mammal @deprecated(reason: "some reason") @skip(if: false) { name: String }
					 """,
        """
					extend interface Entity { id: ID }
					extend interface Mammal @deprecated(reason: "some reason") @skip(if: false) { name: String }
					interface Entity { id: ID }
					interface Mammal @deprecated(reason: "some reason") @skip(if: false) { name: String }
					""",
    )


def test_interface_extensions_implementing_other_interface_implemented_by_object_type() raises:
    run_def(
        interface_pass,
        """
			interface Entity {
			  name: String
			}
			
			interface Tall{  
			  height: String
			}
			
			extend interface Tall implements Entity{
			  name: String
			}
			
			type People implements Entity & Tall{
			  name: String
			  height: String
			  mass: String  
			  birth_year: String
			  gender: String
			  homeworld: String
			  homeplanet: Planet
			  url: String
			  skin_color: String
			  hair_color: String
			  eye_color: String
			}""",
        """
			interface Entity {
			  name: String
			}
			
			interface Tall implements Entity{  
			  height: String
			  name: String
			}
			
			extend interface Tall implements Entity{
			  name: String
			}
			
			type People implements Entity & Tall{
			  name: String
			  height: String
			  mass: String  
			  birth_year: String
			  gender: String
			  homeworld: String
			  homeplanet: Planet
			  url: String
			  skin_color: String
			  hair_color: String
			  eye_color: String
			}""",
    )


def test_extend_simple_scalar_type() raises:
    run_def(
        scalar_pass,
        """
					scalar Coordinates
					extend scalar Coordinates @deprecated(reason: "some reason")
					 """,
        """
					scalar Coordinates @deprecated(reason: "some reason")
					extend scalar Coordinates @deprecated(reason: "some reason")
					""",
    )


def test_extend_scalar_type_by_multiple_directives() raises:
    run_def(
        scalar_pass,
        """
					scalar Coordinates
					extend scalar Coordinates @deprecated(reason: "some reason") @skip(if: false)
					 """,
        """
					scalar Coordinates @deprecated(reason: "some reason") @skip(if: false)
					extend scalar Coordinates @deprecated(reason: "some reason") @skip(if: false)
					""",
    )


def test_extend_non_existent_scalar() raises:
    run_def(
        scalar_pass,
        """
					extend scalar Mood @__bare
					extend scalar Coordinates @deprecated(reason: "some reason") @skip(if: false)
					 """,
        """
					extend scalar Mood @__bare
					extend scalar Coordinates @deprecated(reason: "some reason") @skip(if: false)
					scalar Mood
					scalar Coordinates @deprecated(reason: "some reason") @skip(if: false)
					""",
    )


def test_extend_union_type_by_directive() raises:
    run_def(
        union_pass,
        """
					union Mammal
					extend union Mammal @deprecated(reason: "some reason")
					 """,
        """
					union Mammal @deprecated(reason: "some reason")
					extend union Mammal @deprecated(reason: "some reason")
					""",
    )


def test_extend_union_type_by_union_member_type() raises:
    run_def(
        union_pass,
        """
					union Mammal
					extend union Mammal = Cat
					 """,
        """
					union Mammal = Cat
					extend union Mammal = Cat
					""",
    )


def test_extend_union_type_by_multiple_union_member_types() raises:
    run_def(
        union_pass,
        """
					union Mammal
					extend union Mammal = Cat | Dog
					 """,
        """
					union Mammal = Cat | Dog
					extend union Mammal = Cat | Dog
					""",
    )


def test_extend_union_by_multiple_directives_and_union_members() raises:
    run_def(
        union_pass,
        """
					union Mammal
					extend union Mammal @deprecated(reason: "some reason") @skip(if: false) = Cat | Dog
					 """,
        """
					union Mammal @deprecated(reason: "some reason") @skip(if: false) = Cat | Dog
					extend union Mammal @deprecated(reason: "some reason") @skip(if: false) = Cat | Dog
					""",
    )


def test_extend_union_type_which_already_has_union_member() raises:
    run_def(
        union_pass,
        """
					union Mammal = Cat
					extend union Mammal @deprecated(reason: "some reason") = Dog
					 """,
        """
					union Mammal @deprecated(reason: "some reason") = Cat | Dog
					extend union Mammal @deprecated(reason: "some reason") = Dog
					""",
    )


def test_extend_non_existent_union() raises:
    run_def(
        union_pass,
        """
					extend union Response = SuccessResponse | ErrorResponse
					extend union Mammal @deprecated(reason: "some reason") = Dog
					 """,
        """
					extend union Response = SuccessResponse | ErrorResponse
					extend union Mammal @deprecated(reason: "some reason") = Dog
					union Response = SuccessResponse | ErrorResponse
					union Mammal @deprecated(reason: "some reason") = Dog
					""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
