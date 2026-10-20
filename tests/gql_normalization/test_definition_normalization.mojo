# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2 `v2/pkg/astnormalization`:
`remove_type_extensions_test.go`, `implicit_schema_definition_test.go`,
`extends_directive_test.go`, `implicit_extend_root_operation_test.go`,
`subgraph_sdl_normalization_test.go` and `definition_normalization_test.go`.

The parser of `gql_language` refuses an empty `{}`, as graphql-js does,
so the empty braces of upstream are left out. A type without braces has the
same nodes.
"""

from _def_norm import *
from _norm_fixtures import (
    EXTENDED_ROOT_OPERATION_TYPE_DEFINITION,
    TYPE_EXTENSIONS_DEFINITION,
)
from gql_language.ast import Role
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_normalization.definition import (
    DefinitionNormalizer,
    SubgraphSDLNormalizer,
    normalize_definition,
    normalize_subgraph_sdl,
)
from gql_normalization.edit import remove_child
from std.testing import TestSuite, assert_equal


def test_remove_single_type_extension_of_field_definition() raises:
    run_many_def(
        [object_pass, remove_merged_pass],
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
					""",
    )


def test_remove_single_type_extension_of_directive() raises:
    run_many_def(
        [object_pass, remove_merged_pass],
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
					""",
    )


def test_remove_multiple_type_extensions_at_once() raises:
    run_many_def(
        [object_pass, remove_merged_pass],
        """
					type Cat {
						name: String
					}
					extend type Cat @deprecated(reason: "not as cool as dogs")
					extend type Cat {
						age: Int
					}
					 """,
        """
					type Cat @deprecated(reason: "not as cool as dogs") {
						name: String
						age: Int
					}
					""",
    )


def test_remove_scalar_type_extensions() raises:
    run_many_def(
        [scalar_pass, remove_merged_pass],
        """
					scalar Coordinates
					extend scalar Coordinates @deprecated(reason: "some reason") @skip(if: false)
					 """,
        """
					scalar Coordinates @deprecated(reason: "some reason") @skip(if: false)
					""",
    )


def test_remove_enum_type_extensions() raises:
    run_many_def(
        [enum_pass, remove_merged_pass],
        """
					enum Countries {DE ES NL}
					extend enum Countries @deprecated(reason: "some reason") @skip(if: false) {EN IT}
					 """,
        """
					enum Countries @deprecated(reason: "some reason") @skip(if: false) {DE ES NL EN IT}
					""",
    )


def test_remove_union_type_extensions() raises:
    run_many_def(
        [union_pass, remove_merged_pass],
        """
					union Mammal
					extend union Mammal @deprecated(reason: "some reason") @skip(if: false) = Cat | Dog
					 """,
        """
					union Mammal @deprecated(reason: "some reason") @skip(if: false) = Cat | Dog
					""",
    )


def test_remove_input_object_type_extensions() raises:
    run_many_def(
        [input_object_pass, remove_merged_pass],
        """
					input DogSize {width: Float height: Float}
					extend input DogSize @deprecated(reason: "some reason") @skip(if: false) {breadth: Float weight: Float}
					 """,
        """
					input DogSize @deprecated(reason: "some reason") @skip(if: false) {width: Float height: Float breadth: Float weight: Float}
					""",
    )


def test_remove_interface_type_extensions() raises:
    run_many_def(
        [interface_pass, remove_merged_pass],
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
					""",
    )


def test_remove_object_type_extensions_when_object_type_definition_does_not_exist() raises:
    run_many_def(
        [object_pass, remove_merged_pass],
        """
					extend type Query {
  						_entities(representations: [_Any!]!): [_Entity]!
  						_service: _Service!
					}

					extend type Query {
						me: User
					}
					""",
        """
					type Query {
  						_entities(representations: [_Any!]!): [_Entity]!
  						_service: _Service!
						me: User
					}
					""",
    )


def test_remove_input_object_type_extensions_when_input_object_type_definition_does_not_exist() raises:
    run_many_def(
        [input_object_pass, remove_merged_pass],
        """
					extend input Location {
  						lat: Float
					}

					extend input Location {
						lon: Float
					}
					""",
        """
					input Location {
  						lat: Float
						lon: Float
					}
					""",
    )


def test_remove_enum_type_extensions_when_enum_type_does_not_exist() raises:
    run_many_def(
        [enum_pass, remove_merged_pass],
        """
					extend enum Planet {
  						EARTH
					}

					extend enum Planet {
						MARS
					}
					""",
        """
					enum Planet {
  						EARTH
						MARS
					}
					""",
    )


def test_remove_interface_type_extensions_when_interface_type_does_not_exist() raises:
    run_many_def(
        [interface_pass, remove_merged_pass],
        """
					extend interface Entity {
  						id: ID
					}

					extend interface Entity {
						createdAt: String
					}
					""",
        """
					interface Entity {
  						id: ID
						createdAt: String
					}
					""",
    )


def test_remove_scalar_type_extensions_when_scalar_type_does_not_exist() raises:
    run_many_def(
        [scalar_pass, remove_merged_pass],
        """
					extend scalar IPv4 @__bare
					extend scalar IPv4 @deprecated(reason: "use IPv6")
					""",
        """
					scalar IPv4 @deprecated(reason: "use IPv6")
					""",
    )


def test_remove_union_type_extensions_when_union_type_does_not_exist() raises:
    run_many_def(
        [union_pass, remove_merged_pass],
        """
					extend union Response = SuccessResponse
					extend union Response = ErrorResponse
					""",
        """
					union Response = SuccessResponse | ErrorResponse
					""",
    )


def test_should_create_schema_definition_implicitly() raises:
    run_def(
        implicit_schema_pass,
        """
					extend type Query { me: String }
					extend type Mutation { increaseTextCounter: String }
					extend type Subscription { textCounter: String }
					type Query { me: String }
					type Mutation { increaseTextCounter: String }
					type Subscription { textCounter: String }
					 """,
        """
					schema { query: Query mutation: Mutation subscription: Subscription }
					extend type Query { me: String }
					extend type Mutation { increaseTextCounter: String }
					extend type Subscription { textCounter: String }
					type Query { me: String }
					type Mutation { increaseTextCounter: String }
					type Subscription { textCounter: String }
					""",
    )


def test_should_replace_empty_schema_definition_with_implicit_one() raises:
    # `schema {}` does not parse, so the test removes the operation type.
    var document = parse(
        """
					schema { query: Query }
					extend type Query { me: String }
					extend type Mutation { increaseTextCounter: String }
					extend type Subscription { textCounter: String }
					type Query { me: String }
					type Mutation { increaseTextCounter: String }
					type Subscription { textCounter: String }
					 """
    )
    var schema = document.first_child(document.root)
    remove_child(document, schema, document.child(schema, Role.OPERATION_TYPE))
    implicit_schema_pass(document)
    assert_equal(
        print_ast(document),
        print_ast(
            parse(
                """
					schema { query: Query mutation: Mutation subscription: Subscription }
					extend type Query { me: String }
					extend type Mutation { increaseTextCounter: String }
					extend type Subscription { textCounter: String }
					type Query { me: String }
					type Mutation { increaseTextCounter: String }
					type Subscription { textCounter: String }
					"""
            )
        ),
    )


def test_should_ignore_schema_definition_if_there_is_already_one_explicitly_defined() raises:
    run_def(
        implicit_schema_pass,
        """
					schema { query: Query }
					extend type Query { me: String }
					extend type Mutation { increaseTextCounter: String }
					extend type Subscription { textCounter: String }
					type Query { me: String }
					type Mutation { increaseTextCounter: String }
					type Subscription { textCounter: String }
					 """,
        """
					schema { query: Query }
					extend type Query { me: String }
					extend type Mutation { increaseTextCounter: String }
					extend type Subscription { textCounter: String }
					type Query { me: String }
					type Mutation { increaseTextCounter: String }
					type Subscription { textCounter: String }
					""",
    )


def test_extends_on_object_type_definition_support_extends_directive() raises:
    run_many_def(
        [extends_pass],
        """
				type User @extends {
					field: String!
				}
				""",
        """
					extend type User { field: String! }
				""",
    )


def test_extends_on_object_type_definition_delete_extends_directive() raises:
    run_many_def(
        [extends_pass],
        """
				type User @extends @otherDirective {
					field: String!
				}
				""",
        """
					extend type User @otherDirective { field: String! }
				""",
    )


def test_extends_on_interface_type_definition_support_extends_directive() raises:
    run_many_def(
        [extends_pass],
        """
				interface Vehicle @extends {
					speed: Int!
				}
				""",
        """
					extend interface Vehicle { speed: Int! }
				""",
    )


def test_extends_on_interface_type_definition_delete_extends_directive() raises:
    run_many_def(
        [extends_pass],
        """
				interface Vehicle @extends @otherDirective {
					speed: Int!
				}
				""",
        """
					extend interface Vehicle @otherDirective { speed: Int! }
				""",
    )


def test_implicit_extend_root_operation_from_schema() raises:
    run_many_def(
        [implicit_extend_pass],
        """
		schema {
			query: QueryName
			mutation: MutationName
		}
		type QueryName @hello
		type MutationName {
			field: String!
		}
		scalar String
		""",
        """
		schema { query: QueryName mutation: MutationName }
		extend type QueryName @hello
		extend type MutationName { field: String! }
		scalar String
	""",
    )


def test_don_t_implicitly_extend_empty_schema_root_operation() raises:
    run_many_def(
        [implicit_extend_pass],
        """
		schema {
			query: QueryName
		}
		type QueryName
		""",
        """
		schema { query: QueryName }
		type QueryName
	""",
    )


def test_don_t_implicitly_extend_empty_object_root_operation() raises:
    run_many_def(
        [implicit_extend_pass],
        """
			type Query
			type Mutation {
				field: String!
			}
			type Subscription @directive
			""",
        """
			type Query
			extend type Mutation { field: String! }
			extend type Subscription @directive
		""",
    )


def test_implicitly_extend_object_root_operation_with_definitions_and_directives() raises:
    run_many_def(
        [implicit_extend_pass],
        """
		type Query
		type Mutation {
			field: String!
		}
		type Subscription @directive {
			newUser: ID!
		}
		""",
        """
		type Query
		extend type Mutation { field: String! }
		extend type Subscription @directive { newUser: ID! }
	""",
    )


def test_support_both_extends_directive_and_implicit_extend_keyword() raises:
    run_many_def(
        [implicit_extend_pass, extends_pass],
        """
		type User @extends {
			field: String!
		}
		type Query @extends
		""",
        """
		extend type User { field: String! } extend type Query @extends
	""",
    )


def test_support_both_extends_directive_and_implicit_extend_keyword_in_schema() raises:
    run_many_def(
        [implicit_extend_pass, extends_pass],
        """
		schema {
			query: AQuery
		}
		type User @extends @directiv2 {
			field: String!
		}
		type AQuery @key {
			field: String
		}
		""",
        """
		schema {
			query: AQuery
		}
		extend type User @directiv2 { field: String! }
		extend type AQuery @key {
			field: String
		}
	""",
    )


def run_definition(sdl: StringSlice, expected: StringSlice) raises:
    """Run `NewDefinitionNormalizer`: `run` of `TestNormalizeDefinition`.

    Args:
        sdl: The SDL document.
        expected: The expected SDL.

    Raises:
        Error: If the outputs differ.
    """
    var document = parse_sdl(sdl)
    DefinitionNormalizer().normalize_definition(document)
    assert_equal(print_ast(document), print_ast(parse_sdl(expected)))


def run_subgraph_definition(sdl: StringSlice, expected: StringSlice) raises:
    """Run `NewSubgraphDefinitionNormalizer`: `run` of
    `TestNormalizeSubgraphDefinition`.

    Args:
        sdl: The SDL document.
        expected: The expected SDL.

    Raises:
        Error: If the outputs differ.
    """
    var document = parse_sdl(sdl)
    DefinitionNormalizer.new_subgraph().normalize_definition(document)
    assert_equal(print_ast(document), print_ast(parse_sdl(expected)))


def test_removes_extensions_and_creates_missing_types() raises:
    run_definition(
        TYPE_EXTENSIONS_DEFINITION,
        """
			schema { query: Query }

			type User implements Entity {
				name: String
				id: ID
				age: Int
				type: UserType
				metadata: JSONPayload
			}

			type TrialUser {
				enabled: Boolean
			}

			type SubscribedUser {
				subscription: SubscriptionType
			}

			enum SubscriptionType {
				BASIC
				PRO
				ULTIMATE
			}

			scalar JSONPayload

			union UserType = TrialUser | SubscribedUser

			type Query {
				findUserByLocation(loc: Location): [User]
			}

			interface Entity {
				id: ID
			}

			enum Planet {
				EARTH
				MARS
			}

			input Location {
				lat: Float
				lon: Float
				planet: Planet
			}
		""",
    )


def test_removes_type_extension_and_includes_interfaces() raises:
    run_definition(
        """
			schema { query: Query }
			type User implements Named {
				name: String
			}
			interface Named {
				name: String
			}
			extend type User implements Entity {
				id: ID
			}
			interface Entity {
				id: ID
			}
		""",
        """
			schema { query: Query }
			type User implements Named & Entity {
				name: String
				id: ID
			}
			interface Named {
				name: String
			}
			interface Entity {
				id: ID
			}
		""",
    )


def test_removes_extensions_and_creates_missing_schema_and_root_types() raises:
    run_definition(
        EXTENDED_ROOT_OPERATION_TYPE_DEFINITION,
        """
			schema {
				query: Query
				mutation: Mutation
				subscription: Subscription
			}
			type Query {
				me: String
			}
			type Mutation {
				increaseTextCounter: String
			}
			type Subscription {
				textCounter: String
			}
		""",
    )


def test_normalize_definition_function() raises:
    var document = parse(EXTENDED_ROOT_OPERATION_TYPE_DEFINITION)
    normalize_definition(document)
    var want = parse(
        "schema { query: Query mutation: Mutation subscription: Subscription }"
        " type Query { me: String } type Mutation { increaseTextCounter:"
        " String } type Subscription { textCounter: String }"
    )
    assert_equal(print_ast(document), print_ast(want))


def test_extension_orphans_are_not_deleted() raises:
    run_subgraph_definition(
        """
			extend type Rival {
				version: Version!
			}
			enum Badge {
				BOULDER
				SOUL
			}
			extend enum Version {
				SILVER
			}
			extend input Deposit {
				quantity: Int!
			}
			extend interface GymLeader {
				badge: Badge!
			}
			type Pokemon {
				name: String!
			}
			extend interface Trainer {
				age: Int!
			}
			union Types = Water | Fire
			extend input Move {
				name: String
			}
			input Deposit {
				item: String!
			}
			extend enum Badge {
				EARTH
			}
			extend union Berry = Oran
			extend type Pokemon {
				types: Types!
			}
			extend union Types = Grass
			interface Trainer {
				name: String!
			}
		""",
        """
			extend type Rival {
				version: Version!
			}
			enum Badge {
				BOULDER
				SOUL
				EARTH
			}
			extend enum Version {
				SILVER
			}
			extend interface GymLeader {
				badge: Badge!
			}
			type Pokemon {
				name: String!
				types: Types!
			}
			union Types = Water | Fire | Grass
			extend input Move {
				name: String
			}
			input Deposit {
				item: String!
				quantity: Int!
			}
			extend union Berry = Oran
			interface Trainer {
				name: String!
				age: Int!
			}
		""",
    )


def test_normalize_subgraph_sdl() raises:
    # Not from upstream: `NormalizeSubgraphSDL` and its normalizer.
    var sdl = "type User @extends { field: String! } type Query @extends"
    var want = print_ast(
        parse("extend type User { field: String! } extend type Query @extends")
    )
    var document = parse_sdl(sdl)
    normalize_subgraph_sdl(document)
    assert_equal(print_ast(document), want)
    var again = parse_sdl(sdl)
    SubgraphSDLNormalizer().normalize_subgraph_sdl(again)
    assert_equal(print_ast(again), want)


def test_extra_extends_directive_cases() raises:
    # Not from upstream; the output is the output of upstream.
    run_many_def(
        [extends_pass],
        """
			type A @key(fields: "id") @extends { id: ID }
			type B { b: Int }
			type C @key(fields: "id") { id: ID }
			interface I @extends { i: Int }
			scalar S""",
        """
			extend type A @key(fields: "id") { id: ID }
			type B { b: Int }
			type C @key(fields: "id") { id: ID }
			extend interface I { i: Int }
			scalar S""",
    )


def test_extra_implicit_extend_with_schema_extension() raises:
    # Not from upstream; the output is the output of upstream.
    run_many_def(
        [implicit_extend_pass],
        """
			schema { query: Q }
			extend schema { subscription: S }
			type Q { a: Int }
			type S { s: Int }
			type Other { o: Int }""",
        """
			schema { query: Q }
			extend schema { subscription: S }
			extend type Q { a: Int }
			extend type S { s: Int }
			type Other { o: Int }""",
    )


def test_extra_implicit_schema_with_query_only() raises:
    # Not from upstream; the output is the output of upstream.
    run_many_def(
        [implicit_schema_pass],
        "type Query { a: Int }",
        "schema { query: Query } type Query { a: Int }",
    )


def test_extra_merge_into_the_first_definition() raises:
    # Not from upstream; the output is the output of upstream.
    run_many_def(
        [object_pass, remove_merged_pass],
        "type A { a: Int }",
        "type A { a: Int }",
    )
    run_many_def(
        [object_pass, remove_merged_pass],
        """
			"desc" type A { a: Int }
			type A { b: Int }
			extend type A { c: Int }""",
        """
			"desc" type A { a: Int c: Int }
			type A { b: Int }""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
