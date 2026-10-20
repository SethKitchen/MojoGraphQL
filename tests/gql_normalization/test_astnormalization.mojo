# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/astnormalization_test.go`.

The `@defer` cases are not ported, because `WithEnableDefer` is not. The
type extension cases ("type extensions" and the three "use extended ...
without explicit schema definition") are not ported, because they need
`WithNormalizeDefinition`, which normalizes the SDL and is not ported.
`TestVariablesNormalizer` is not ported, because `VariablesNormalizer` is
not. The benchmark is in `bench/gql_normalization/`.
"""

from _norm import *
from _norm_fixtures import *
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_normalization.normalize import OperationNormalizer, normalize_operation
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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
