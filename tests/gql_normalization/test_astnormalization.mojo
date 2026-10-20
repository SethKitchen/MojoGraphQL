# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/astnormalization_test.go`.

`TestVariablesNormalizer` is in `test_variables_normalizer.mojo`. The
benchmark is in `bench/gql_normalization/`.
"""

from _def_norm import parse_sdl
from _norm import *
from _norm_fixtures import *
from gql_language.ast import Document
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_schema.definition import Schema
from gql_normalization.normalize import (
    NormalizerOptions,
    OperationNormalizer,
    normalize_operation,
)
from std.testing import TestSuite, assert_equal, assert_true


def test_complex() raises:
    run_normalize(
        TEST_DEFINITION,
        """	
				subscription sub {
					... multipleSubscriptions
					... on Subscription {
						newMessage {
							body
							sender
						}	
					}
				}
				fragment newMessageFields on Message {
					body: body
					sender
					... on Body {
						body
					}
				}
				fragment multipleSubscriptions on Subscription {
					newMessage {
						body
						sender
					}
					newMessage {
						... newMessageFields
					}
					newMessage {
						body
						body
						sender
					}
					... on Subscription {
						newMessage {
							body
							sender
						}	
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
				}""",
        "",
        "",
    )


def test_defer_parent_ids_preserved_across_merged_and_discarded_scopes() raises:
    run_normalize(
        """
			type Query { user: User }
			type User { info: Info }
			type Info { address: String email: String phone: String nestedInfo: NestedInfo }
			type NestedInfo { a: String b: String c: String d: String }""",
        """
			query DeferUserTitle {
				user {
					info {
						address
					}
				}
				... @defer {
					user {
						info {
							nestedInfo {
								a
							}
						}
						... @defer {
							info {
								nestedInfo {
									b
								}
								... @defer {
									nestedInfo {
										c
									}
									phone
								}
							}
						}
						... @defer {
							info {
								email
								... @defer {
									nestedInfo {
										d
									}
								}
							}
						}
					}
				}
			}""",
        """
			query DeferUserTitle {
				user {
					info {
						address
						nestedInfo @__defer_internal(id: 1) {
							a @__defer_internal(id: 1)
							b @__defer_internal(id: 2, parentDeferId: 1)
							c @__defer_internal(id: 3, parentDeferId: 2)
							d @__defer_internal(id: 5, parentDeferId: 4)
						}
						phone @__defer_internal(id: 3, parentDeferId: 2)
						email @__defer_internal(id: 4, parentDeferId: 1)
					}
				}
			}""",
        "",
        "",
    )


def test_deferred_typename_on_initial_entity_becomes_non_deferred() raises:
    run_normalize(
        """
			type Query { article: Article }
			type Article { id: ID! title: String! reviews: [Review!]! }
			type Review { id: ID! }""",
        """
			query Q {
				article {
					id
					... @defer { __typename title }
					reviews { id }
				}
			}""",
        """
			query Q {
				article {
					id
					__typename
					title @__defer_internal(id: 1)
					reviews {
						id
					}
				}
			}""",
        "",
        "",
    )


def test_inject_default() raises:
    run_normalize(
        INJECT_DEFAULT_VALUE_DEFINITION,
        """
			query{elQuery(input:{fieldB: "dupa"})}""",
        """query($a: elInput){elQuery(input: $a)}""",
        "",
        """{"a":{"fieldB":"dupa","fieldA":"VALUE_A"}}""",
    )


def test_inject_default_string_into_list() raises:
    run_normalize(
        """type Query { field(arg: [String!]!): String }""",
        """query Q($arg: [String!]! = "foo"){ field(arg: $arg) }""",
        """query Q($arg: [String!]!){ field(arg: $arg) }""",
        """{}""",
        """{"arg":["foo"]}""",
    )


def test_inject_default_string_into_nested_list() raises:
    run_normalize(
        """type Query { field(arg: [[String!]!]!): String }""",
        """query Q($arg: [[String!]!]! = "foo"){ field(arg: $arg) }""",
        """query Q($arg: [[String!]!]!){ field(arg: $arg) }""",
        """{}""",
        """{"arg":[["foo"]]}""",
    )


def test_inject_default_string_into_nullable_nested_list() raises:
    run_normalize(
        """type Query { field(arg: [[String]]): String }""",
        """query Q($arg: [[String]] = "foo"){ field(arg: $arg) }""",
        """query Q($arg: [[String]]){ field(arg: $arg) }""",
        """{}""",
        """{"arg":[["foo"]]}""",
    )


def test_inject_default_string_with_brackets_into_list() raises:
    run_normalize(
        """type Query { field(arg: [String!]!): String }""",
        """query Q($arg: [String!]! = "[foo]"){ field(arg: $arg) }""",
        """query Q($arg: [String!]!){ field(arg: $arg) }""",
        """{}""",
        """{"arg":["[foo]"]}""",
    )


def test_inject_default_input_object_into_list() raises:
    run_normalize(
        """type Query { field(arg: [Input!]!): String } input Input { foo: String }""",
        """query Q($arg: [Input!]! = {foo: "bar"}){ field(arg: $arg) }""",
        """query Q($arg: [Input!]!){ field(arg: $arg) }""",
        """{}""",
        """{"arg":[{"foo":"bar"}]}""",
    )


def test_inject_default_input_object_into_nested_list() raises:
    run_normalize(
        """type Query { field(arg: [[Input!]!]!): String } input Input { foo: String }""",
        """query Q($arg: [[Input!]!]! = {foo: "bar"}){ field(arg: $arg) }""",
        """query Q($arg: [[Input!]!]!){ field(arg: $arg) }""",
        """{}""",
        """{"arg":[[{"foo":"bar"}]]}""",
    )


def test_fragments() raises:
    run_normalize(
        TEST_DEFINITION,
        """
				query conflictingBecauseAlias ($unused: String) {
					dog {
						extras { ...frag }
						extras { ...frag2 }
					}
				}
				fragment frag on DogExtra { string1 }
				fragment frag2 on DogExtra { string1: string }""",
        """
				query conflictingBecauseAlias ($unused: String) {
					dog {
						extras {
							string1
							string1: string
						}
					}
				}""",
        """{"unused":"foo"}""",
        """{"unused":"foo"}""",
    )


def test_inline_fragment_spreads_and_merge_fragments() raises:
    run_normalize(
        TEST_DEFINITION,
        """
				query q {
					pet {
						...DogName
						...DogBarkVolume
					}
				}
				fragment DogName on Pet { ... on Dog { name } }
				fragment DogBarkVolume on Pet { ... on Dog { barkVolume } }""",
        """
				query q {
					pet {
						... on Dog {
							name
							barkVolume
						}
					}
				}""",
        """""",
        """""",
    )


def test_combined_inline_fragment_fields_merging_1() raises:
    run_normalize(
        TEST_DEFINITION,
        """
				query q {
					pet {
						... on Dog {
								... on Pet {
									...DogName
									...DogExtraString
								}
						}
					}
					pet {
						... on Dog {
								...DogBarkVolume
								...DogExtraString
						}
					}
				}
				fragment DogName on Pet { ... on Dog { name } }
				fragment DogBarkVolume on Pet { ... on Dog { barkVolume } }
				fragment DogExtraString on Dog {
					...DogName
					extras { 
						... on DogExtra {
							string 
						}
					}
				} """,
        """
				query q {
					pet {
						... on Dog {
							name
							extras { 
								string 
							}
							barkVolume
						}
					}
				}""",
        """""",
        """""",
    )


def test_combined_inline_fragment_fields_merging_2() raises:
    run_normalize(
        TEST_DEFINITION,
        """
				query q {
					pet {
						...DogExtraString
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
				}
				fragment DogExtraString on Dog {
					extras { 
						... on DogExtra {
							string
						}
						... on Pet {
							__typename
						}
					}
				} """,
        """
				query q {
					pet {
						... on Dog {
							extras {
								string
								... on Pet {
									__typename
								}
								string1
							}
						}
					}
				}""",
        """""",
        """""",
    )


def test_combined_inline_fragment_fields_merging_3() raises:
    run_normalize(
        """ schema { query: Query }
				scalar ID
				scalar String

				type Query {
					requestForQuote(id: ID!): Request
				}
				type Request { draftQuotePackage: QuotePackage }
				type QuotePackage { requestedParts: Parts }
				type Parts { edges: [PartEdge] }
				type PartEdge { quote: Quote }
				type Quote { quoteRevision: QuoteRevisionUnion }
				union QuoteRevisionUnion = QuoteRevision | Node
				type QuoteRevision { partBreakdown: PartBreakdown }
				type Node { name: String! }
				type PartBreakdown {
					breakdownType: String!
					cost: String!
				} """,
        """
				query SimplePartQuoteEditorQuery($requestForQuoteId: ID!) {
				  requestForQuote(id: $requestForQuoteId) {
					draftQuotePackage {
					  ...useBreakdownTypeFilter_quotePackage
					  requestedParts {
						edges {
						  quote {
							quoteRevision {
							  ... on QuoteRevision {
								partBreakdown {
								  cost
								}
							  }
							}
						  }
						}
					  }
					}
				  }
				}

				fragment useBreakdownTypeFilter_quotePackage on QuotePackage {
				  requestedParts {
					edges {
					  quote {
						quoteRevision {
						  ... on QuoteRevision {
							partBreakdown {
							  breakdownType
							}
						  }
						  ... on Node {
							__isNode: __typename
						  }
						}
					  }
					}
				  }
				}
""",
        """
				query SimplePartQuoteEditorQuery($requestForQuoteId: ID!) {
				  requestForQuote(id: $requestForQuoteId) {
					draftQuotePackage {
					  requestedParts {
						edges {
						  quote {
							quoteRevision {
							  ... on QuoteRevision {
								partBreakdown {
								  breakdownType
								  cost
								}
							  }
							  ... on Node {
								__isNode: __typename
							  }
							}
						  }
						}
					  }
					}
				  }
				}""",
        """123""",
        """123""",
    )


def test_fragments_2() raises:
    run_normalize(
        VARIABLES_EXTRACTION_DEFINITION,
        """
			mutation HttpBinPost{
			  httpBinPost(input: {foo: "bar"}){
				headers {
				  userAgent
				}
				data {
				  foo
				}
			  }
			}""",
        """
			mutation HttpBinPost($a: HttpBinPostInput){
			  httpBinPost(input: $a){
				headers {
				  userAgent
				}
				data {
				  foo
				}
			  }
			}""",
        """""",
        """{"a":{"foo":"bar"}}""",
    )


def test_default_values() raises:
    run_normalize(
        TEST_DEFINITION,
        """
			query {
				simple
			}""",
        """query {
			  simple
			}""",
        """""",
        """""",
    )


def test_input_list_coercion_inline() raises:
    run_normalize(
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query Foo {
			  inputWithList(input: {list:{foo:"bar",list:{foo:"bar2",list:{nested:{foo:"bar3",list:{foo:"bar4"}}}}}}) {
				id
				name
			  }
			}""",
        """query Foo($a: InputWithList) {
			  inputWithList(input: $a) {
				id
				name
			  }
			}""",
        """{}""",
        """{"a":{"list":[{"foo":"bar","list":[{"foo":"bar2","list":[{"nested":{"foo":"bar3","list":[{"foo":"bar4"}]}}]}]}]}}""",
    )


def test_input_list_coercion_with_extracted_variables() raises:
    run_normalize(
        INPUT_COERCION_FOR_LIST_DEFINITION,
        """
			query ($input: InputWithListNestedList) {
			  inputWithListNestedList(input: $input) {
				id
				name
			  }
			}""",
        """query ($input: InputWithListNestedList) {
			  inputWithListNestedList(input: $input) {
				id
				name
			  }
			}""",
        """{"input":{"doubleList":{"foo":"bar","list":{"foo":"bar2","list":{"nested":{"foo":"bar3","list":{"foo":"bar4"}}}}}}}""",
        """{"input":{"doubleList":[[{"foo":"bar","list":[{"foo":"bar2","list":[{"nested":{"foo":"bar3","list":[{"foo":"bar4"}]}}]}]}]]}}""",
    )


def test_preserve_still_used_fragments() raises:
    run_normalize(
        TEST_DEFINITION,
        """
			fragment D on Dog {
				name
			}
			query  {
			  simple
			  ...D
			}""",
        """
			fragment D on Dog {
				name
			}
			query {
				simple
				...D
			}""",
        """""",
        """""",
    )


def test_defer_no_conditions_typename_placeholder_needed() raises:
    run_normalize(
        TEST_DEFINITION,
        """
			query pet {
				pet {
					... on Dog @defer {
						name
						nickname
						... @defer {
							barkVolume
						}
					}
					... on Dog {
						... @defer {
							extra {
								noString
							}
						}
						... @defer {
							extra {
								string
								noString
							}
						}
					}
					... on Cat {
						name
						extra {
							bool
						}
					}
					... on Cat @defer {
						name
						meowVolume
						extra {
							bool
						}
					}
					... on Cat @defer {
						name
						nickname
						meowVolume
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
						extra @__defer_internal(id: 3) {
							noString @__defer_internal(id: 3)
							string @__defer_internal(id: 4, parentDeferId: 3)
						}
						__internal_typename: __typename
					}
					... on Cat {
						name
						extra {
							bool
						}
						meowVolume @__defer_internal(id: 5)
						nickname @__defer_internal(id: 6)
					}
				}
			}""",
        "",
        "",
    )


def test_defer_with_conditions() raises:
    run_normalize(
        TEST_DEFINITION,
        """
			query pet($dogExtraString: Boolean!, $catExtra: Boolean!, $catNoExtra: Boolean!) {
				pet {
					... on Dog @defer(if: true) {
						name
						nickname
						... @defer {
							barkVolume
						}
					}
					... on Dog {
						... @defer(if: false) {
							extra {
								noString
							}
						}
						... @defer(if: $dogExtraString) {
							extra {
								string
								noString
							}
						}
					}
					... on Cat {
						name
						extra {
							bool
						}
					}
					... on Cat @defer(if: $catExtra) {
						name
						meowVolume
						extra {
							bool
						}
					}
					... on Cat @defer(if: $catNoExtra) {
						name
						nickname
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
						extra {
							noString
							string
						}
					}
					... on Cat {
						name
						extra {
							bool
						}
						meowVolume @__defer_internal(id: 3)
						nickname
					}
				}
			}""",
        '{"dogExtraString": false, "catExtra": true, "catNoExtra": false}',
        "{}",
    )


def test_should_return_an_error_once_on_normalization_with_missing_field() raises:
    """Upstream `TestOperationNormalizer_NormalizeOperation`: an unknown
    field is for validation to report."""
    var schema = schema_of(
        """
type Query {
	country: Country!
}

type Country {
	name: String!
}

schema {
    query: Query
}
"""
    )
    var document = parse("{ country { nam } }")
    var variables = String()
    OperationNormalizer.new(True, True).normalize_operation(
        document, schema, variables
    )
    assert_equal(print_ast(document), printed("{ country { nam } }"))


comptime HERO_SCHEMA = """
			type Query {
				hero(ids: [ID!]!): Hero
			}
			type Hero {
				name(length: Int!): String
				age: Int
			}
"""
"""The schema of the last named operation tests."""

comptime HERO_QUERY = """
			query Game($id: ID! $withAge: Boolean! $withName: Boolean! $nameLength: Int!) {
				hero(ids: [$id]) {
					... NameFragment @include(if: $withName)
					... AgeFragment @include(if: $withAge)
				}
			}
			fragment NameFragment on Hero {
				name(length: $nameLength)
			}
			fragment AgeFragment on Hero {
				age
			}
			"""
"""The operation of the last named operation tests."""

comptime FRAGMENTS = """
			fragment NameFragment on Hero {
				name
			}
			fragment AgeFragment on Hero {
				age
			}
			"""
"""The fragments of the named operation tests."""


def test_should_properly_remove_fragments_and_unmatched_query() raises:
    run_named(
        """
			type Query {
				items: Attributes
			}
			type Attribute {
				name: String
				childAttributes: [Attribute]
			}
			type Attributes {
				name: String
				childAttributes: [Attribute]
			}""",
        """
			query Items {
				items {
					...AttributesFragment
				}
			}
			query OtherItems {
				items {
					...AttributesFragment
				}
			}
			fragment AttributesFragment on Attributes {
				name
				childAttributes {
					...AttributeFragment
					childAttributes {
						...AttributeFragment
					}
				}
			}
			fragment AttributeFragment on Attribute {
				name
				childAttributes {
					name
				}
			}""",
        "Items",
        """query Items {
  items {
    name
    childAttributes {
      name
      childAttributes {
        name
        childAttributes {
          name
        }
      }
    }
  }
}""",
        "",
        "",
    )


def test_should_remove_obsolete_variables() raises:
    run_named(
        "type Query { hero: Hero } type Hero { name: String age: Int }",
        """
			query Game($withAge: Boolean! $withName: Boolean!) {
				hero {
					... NameFragment @include(if: $withName)
					... AgeFragment @include(if: $withAge)
				}
			}"""
        + FRAGMENTS,
        "Game",
        "query Game { hero { age } }",
        '{"withAge":true,"withName":false}',
        "{}",
        True,
    )


def test_should_remove_obsolete_variables_but_keep_used_ones() raises:
    run_named(
        (
            "type Query { hero(id: ID!): Hero } type Hero { name: String age:"
            " Int }"
        ),
        """
			query Game($id: ID! $withAge: Boolean! $withName: Boolean!) {
				hero(id: $id) {
					... NameFragment @include(if: $withName)
					... AgeFragment @include(if: $withAge)
				}
			}"""
        + FRAGMENTS,
        "Game",
        "query Game($id: ID!) { hero(id: $id) { age } }",
        '{"id":"1","withAge":true,"withName":false}',
        '{"id":"1"}',
        True,
    )


def test_should_remove_nested_obsolete_variables_but_keep_used_ones() raises:
    run_named(
        (
            "type Query { hero(ids: [ID!]!): Hero } type Hero { name: String"
            " age: Int }"
        ),
        """
			query Game($id: ID! $withAge: Boolean! $withName: Boolean!) {
				hero(ids: [$id]) {
					... NameFragment @include(if: $withName)
					... AgeFragment @include(if: $withAge)
				}
			}"""
        + FRAGMENTS,
        "Game",
        "query Game($a: [ID!]!) { hero(ids: $a) { age } }",
        '{"id":"1","withAge":true,"withName":false}',
        '{"a":["1"]}',
        True,
    )


def test_should_not_remove_variables_that_were_not_used_by_skip_or_include() raises:
    run_named(
        (
            "type Query { hero(ids: [ID!]!): Hero } type Hero { name: String"
            " age: Int }"
        ),
        """
			query Game($id: ID! $withAge: Boolean! $withName: Boolean! $unused: String) {
				hero(ids: [$id]) {
					... NameFragment @include(if: $withName)
					... AgeFragment @include(if: $withAge)
				}
			}"""
        + FRAGMENTS,
        "Game",
        "query Game($unused: String, $a: [ID!]!){hero(ids: $a){age}}",
        '{"id":"1","withAge":true,"withName":false}',
        '{"a":["1"]}',
    )


def test_should_safely_remove_obsolete_variables() raises:
    run_named(
        HERO_SCHEMA,
        HERO_QUERY,
        "Game",
        "query Game($a: [ID!]!){hero(ids: $a){age}}",
        '{"id":"1","withAge":true,"withName":false}',
        '{"a":["1"]}',
    )


def test_should_keep_variable_if_included() raises:
    run_named(
        HERO_SCHEMA,
        HERO_QUERY,
        "Game",
        (
            "query Game($nameLength: Int!, $a: [ID!]!){hero(ids:"
            " $a){name(length: $nameLength) age}}"
        ),
        '{"id":"1","withAge":true,"withName":true}',
        '{"a":["1"]}',
    )


def test_should_not_extract_default_values_from_query_body_and_remove_unmatched_query() raises:
    run_named(
        """
			type Query {
				operationA(input: String = "foo"): String
				operationB(input: String = "bar"): String
			}""",
        """
			query A {
				operationA(input: "bazz")
			}
			query B {
				operationB
			}""",
        "B",
        "query B {\n  operationB\n}",
        "",
        "",
    )


comptime COUNTRY_SCHEMA = """
scalar String
type Query {
	country: Country!
}
type Country {
	name: String!
}
schema {
    query: Query
}
"""
"""The schema of `TestNewNormalizer`."""

comptime COUNTRY_QUERY = (
    "fragment Fields on Country {name} query Q {country {...Fields}}"
)
"""The operation of `TestNewNormalizer`."""


def _run_normalization(remove_fragments: Bool, expected: StringSlice) raises:
    """Upstream `runNormalization` of `TestNewNormalizer`."""
    var schema = schema_of(COUNTRY_SCHEMA)
    var document = parse(COUNTRY_QUERY)
    var variables = String()
    OperationNormalizer.new(remove_fragments, True).normalize_operation(
        document, schema, variables
    )
    assert_true(print_ast(document) != printed(COUNTRY_QUERY))
    assert_equal(print_ast(document), printed(expected))


def test_when_remove_fragments_true() raises:
    _run_normalization(True, "query Q {country {name}}")


def test_when_remove_fragments_false() raises:
    _run_normalization(
        False, "fragment Fields on Country {name} query Q {country {name}}"
    )


def test_parse_missing_base_schema() raises:
    """Upstream `TestParseMissingBaseSchema`. A `gql_schema` schema always
    has its built-in types, so here the schema has no `Query` type."""
    var schema = schema_of("type Foo { hello: String! }")
    var document = parse("query { hello }")
    var variables = String()
    try:
        normalize_operation(document, schema, variables)
    except error:
        assert_equal(
            String(error),
            (
                "operation type query is not defined; did you forget to merge"
                " the base schema?"
            ),
        )
        return
    assert_true(False, "normalization should report an error")


def run_with_definition(
    definition: StringSlice,
    operation: StringSlice,
    expected: StringSlice,
    variables: StringSlice,
    expected_variables: StringSlice,
) raises:
    """Normalize with the options of `TestNormalizeOperation`, and with
    `WithNormalizeDefinition`, against the SDL as a document.

    Args:
        definition: The SDL.
        operation: The operation.
        expected: The expected operation.
        variables: The variables JSON.
        expected_variables: The expected variables JSON.

    Raises:
        Error: If the outputs differ or the normalization fails.
    """
    var options = NormalizerOptions()
    options.inline_fragment_spreads = True
    options.extract_variables = True
    options.remove_fragment_definitions = True
    options.remove_unused_variables = True
    options.normalize_definition = True
    var sdl = parse_sdl(definition)
    var document = parse(operation)
    var values = String(variables)
    OperationNormalizer(options).normalize_operation_with_definition(
        document, sdl, values
    )
    assert_equal(print_ast(document), printed(expected))
    assert_equal(values, String(expected_variables))


def test_type_extensions() raises:
    run_with_definition(
        TYPE_EXTENSIONS_DEFINITION,
        """
			{
				findUserByLocation(loc: {lat: 1.000, lon: 2.000, planet: "EARTH"}) {
					id
					name
					age
					type {
						... on TrialUser {
							__typename
							enabled
						}
						... on SubscribedUser {
							__typename
							subscription
						}
					}
					metadata
				}
			}""",
        """query($a: Location){
				findUserByLocation(loc: $a) {
					id
					name
					age
					type {
						... on TrialUser {
							__typename
							enabled
						}
						... on SubscribedUser {
							__typename
							subscription
						}
					}
					metadata
				}
			}""",
        """{"a": {"lat": 1.000, "lon": 2.000, "planet": "EARTH"}}""",
        """{"a": {"lat":1.000,"lon":2.000,"planet":"EARTH"}}""",
    )


def test_use_extended_query_without_explicit_schema_definition() raises:
    run_with_definition(
        EXTENDED_ROOT_OPERATION_TYPE_DEFINITION,
        "{ me }",
        "{ me }",
        "",
        "",
    )


def test_use_extended_mutation_without_explicit_schema_definition() raises:
    run_with_definition(
        EXTENDED_ROOT_OPERATION_TYPE_DEFINITION,
        "mutation { increaseTextCounter }",
        "mutation { increaseTextCounter }",
        "",
        "",
    )


def test_use_extended_subscription_without_explicit_schema_definition() raises:
    run_with_definition(
        EXTENDED_ROOT_OPERATION_TYPE_DEFINITION,
        "subscription { textCounter }",
        "subscription { textCounter }",
        "",
        "",
    )


def test_named_operation_with_definition() raises:
    # Not from upstream: `NormalizeNamedOperation` on an SDL document.
    var options = NormalizerOptions()
    options.remove_not_matching_operation_definitions = True
    options.normalize_definition = True
    var sdl = parse_sdl(EXTENDED_ROOT_OPERATION_TYPE_DEFINITION)
    var document = parse("query A { me } query B { me }")
    var values = String()
    OperationNormalizer(options).normalize_named_operation_with_definition(
        document, sdl, "B", values
    )
    assert_equal(print_ast(document), printed("query B { me }"))
    # Without the option, the SDL is built as it is.
    var plain = parse("type Query { me: String }")
    var again = parse("{ me }")
    OperationNormalizer(
        NormalizerOptions()
    ).normalize_operation_with_definition(again, plain, values)
    assert_equal(print_ast(again), printed("{ me }"))


def _refuse_forbidden(
    operation: Document, schema: Schema, variables: String
) raises:
    """A prevalidation rule: refuse an operation with a `forbidden` field."""
    var text = print_ast(operation)
    if "forbidden" in text:
        raise Error("forbidden field")


def test_prevalidation_rules() raises:
    # Not from upstream: a rule reads the operation before the first stage.
    var options = NormalizerOptions()
    options.prevalidation_rules.append(_refuse_forbidden)
    var normalizer = OperationNormalizer(options)
    var schema = schema_of("type Query { allowed: String forbidden: String }")
    var values = String()
    var good = parse("{ allowed allowed }")
    normalizer.normalize_operation(good, schema, values)
    assert_equal(print_ast(good), printed("{ allowed }"))
    var bad = parse("{ forbidden }")
    try:
        normalizer.normalize_operation(bad, schema, values)
    except error:
        assert_equal(String(error), "forbidden field")
        return
    assert_true(False, "expected the error: forbidden field")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
