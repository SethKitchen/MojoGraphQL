# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The graphql-go-tools v2 `BenchmarkAstNormalization` workload.

    mojo build -I . -o .cache/bin/normalization bench/gql_normalization/normalization.mojo
    .cache/bin/normalization

- `go-tools/AstNormalization`: `astnormalization_test.go`
  `BenchmarkAstNormalization`. The schema is `testDefinition` and the
  operation `testOperation`, both parsed outside the timer. Each operation
  runs `NewNormalizer(false, false).NormalizeOperation` on the same
  document, as upstream does: the first run normalizes it, and the later
  runs walk a normalized document.

The baseline in `bench/baselines/go-normalization` runs the same workload.
"""

from _harness import Workload, measure
from gql_language.ast import Document
from gql_language.parser import parse
from gql_normalization.normalize import OperationNormalizer
from gql_schema.build import BuildOptions, build_schema
from gql_schema.definition import Schema

comptime TEST_OPERATION = """
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
}"""
"""Upstream `testOperation`."""

comptime TEST_DEFINITION = """
schema {
	query: Query
	subscription: Subscription
}
interface Body {
	body: String
}
type Message implements Body {
	body: String
	sender: String
}
type Subscription {
	newMessage: Message
	disallowedSecondRootField: Boolean
	frag2Field: String
}
input ComplexInput { name: String, owner: String }
input ComplexNonOptionalInput { name: String! }
type Field {
	subfieldA: String
	subfieldB: String
}
type Query {
	human: Human
	pet: Pet
	dog: Dog
	cat: Cat
	catOrDog: CatOrDog
	dogOrHuman: DogOrHuman
	humanOrAlien: HumanOrAlien
	arguments: ValidArguments
	findDog(complex: ComplexInput): Dog
	findDogNonOptional(complex: ComplexNonOptionalInput): Dog
	booleanList(booleanListArg: [Boolean!]): Boolean
	extra: Extra
	field: Field
	simple(input: String = "foo"): String
}
type ValidArguments {
	multipleReqs(x: Int!, y: Int!): Int!
	booleanArgField(booleanArg: Boolean): Boolean
	floatArgField(floatArg: Float): Float
	intArgField(intArg: Int): Int
	nonNullBooleanArgField(nonNullBooleanArg: Boolean!): Boolean!
	booleanListArgField(booleanListArg: [Boolean]!): [Boolean]
	optionalNonNullBooleanArgField(optionalBooleanArg: Boolean! = false): Boolean!
}
enum DogCommand { SIT, DOWN, HEEL }
type Dog implements Pet {
	name: String!
	nickname: String
	barkVolume: Int
	doesKnowCommand(dogCommand: DogCommand!): Boolean!
	isHousetrained(atOtherHomes: Boolean): Boolean!
	owner: Human
	extra: DogExtra
	extras: [DogExtra]
	mustExtra: DogExtra!
	mustExtras: [DogExtra]!
	mustMustExtras: [DogExtra!]!
	doubleNested: Boolean
	nestedDogName: String
}
type DogExtra {
	string: String
	string1: String
	strings: [String]
	mustStrings: [String]!
	bool: Int
	noString: Boolean
}
interface Sentient {
  name: String!
}
interface Pet {
  name: String!
}
type Alien implements Sentient {
  name: String!
  homePlanet: String
}
type Human implements Sentient {
  name: String!
}
enum CatCommand { JUMP }
type Cat implements Pet {
	name: String!
	nickname: String
	doesKnowCommand(catCommand: CatCommand!): Boolean!
	meowVolume: Int
	extra: CatExtra
}
type CatExtra {
	string: String
	string2: String
	strings: [String]
	mustStrings: [String]!
	bool: Boolean
}
union CatOrDog = Cat | Dog
union DogOrHuman = Dog | Human
union HumanOrAlien = Human | Alien
union Extra = CatExtra | DogExtra"""
"""Upstream `testDefinition`."""


struct Normalize(Movable, Workload):
    """Normalize one document again and again: `BenchmarkAstNormalization`."""

    var schema: Schema
    """The definition, built outside the timer."""
    var document: Document
    """The operation, parsed outside the timer."""
    var normalizer: OperationNormalizer
    """`NewNormalizer(false, false)`, made once."""
    var variables: String
    """The variables, empty as upstream."""

    def __init__(out self) raises:
        """Build the schema and parse the operation.

        Raises:
            Error: If a text does not parse.
        """
        var options = BuildOptions()
        options.assume_valid = True
        self.schema = build_schema(TEST_DEFINITION, options)
        self.document = parse(TEST_OPERATION)
        self.normalizer = OperationNormalizer.new(False, False)
        self.variables = String()

    def run(mut self) raises -> Int:
        """Normalize the operation.

        Returns:
            The node count of the document.

        Raises:
            Error: If the normalization fails.
        """
        self.normalizer.normalize_operation(
            self.document, self.schema, self.variables
        )
        return len(self.document.nodes)


def main() raises:
    measure("go-tools/AstNormalization", Normalize())
