# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for executable document validation.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `tests/validation/field_merging.rs`,
`tests/validation/operation.rs`, `tests/validation/variable.rs` and
`tests/validation/recursion.rs`, under the MIT arm of its MIT OR Apache-2.0
license. The executable tests of `tests/validation/mod.rs` are in
`test_validation_mod.mojo`.

A test checks the `Error:` line and the `╭─[ file:line:column ]` line of
each diagnostic. Upstream checks the whole report, with the source lines.
`variables_in_const_contexts` of `variable.rs` is not ported: it changes
the AST in place, which the Mojo AST does not support. The last tests
check the branches that the upstream tests do not reach.
"""

from gql_compiler.diagnostics import DiagnosticList
from gql_compiler.executable import ExecutableDocument
from gql_compiler.schema import Schema
from gql_compiler.validation import (
    parse_and_validate_executable,
    parse_and_validate_schema,
    parse_mixed_validate,
    validate_executable,
    validate_standalone_executable,
)
from std.testing import TestSuite, assert_equal, assert_true

comptime GRAPHQL_JS_TEST_SCHEMA = """
interface Mammal {
  mother: Mammal
  father: Mammal
}
interface Pet {
  name(surname: Boolean): String
}
interface Canine implements Mammal {
  name(surname: Boolean): String
  mother: Canine
  father: Canine
}
enum DogCommand {
  SIT
  HEEL
  DOWN
}
type Dog implements Pet & Mammal & Canine {
  name(surname: Boolean): String
  nickname: String
  barkVolume: Int
  barks: Boolean
  doesKnowCommand(dogCommand: DogCommand): Boolean
  isHouseTrained(atOtherHomes: Boolean = true): Boolean
  isAtLocation(x: Int, y: Int): Boolean
  mother: Dog
  father: Dog
}
type Cat implements Pet {
  name(surname: Boolean): String
  nickname: String
  meows: Boolean
  meowsVolume: Int
  furColor: FurColor
}
union CatOrDog = Cat | Dog
type Human {
  name(surname: Boolean): String
  pets: [Pet]
  relatives: [Human]!
}
enum FurColor {
  BROWN
  BLACK
  TAN
  SPOTTED
  NO_FUR
  UNKNOWN
}
input ComplexInput {
  requiredField: Boolean!
  nonNullField: Boolean! = false
  intField: Int
  stringField: String
  booleanField: Boolean
  stringListField: [String]
}
input OneOfInput {
  stringField: String
  intField: Int
}
type ComplicatedArgs {
  intArgField(intArg: Int): String
  nonNullIntArgField(nonNullIntArg: Int!): String
  stringArgField(stringArg: String): String
  booleanArgField(booleanArg: Boolean): String
  enumArgField(enumArg: FurColor): String
  floatArgField(floatArg: Float): String
  idArgField(idArg: ID): String
  stringListArgField(stringListArg: [String]): String
  stringListNonNullArgField(stringListNonNullArg: [String!]): String
  complexArgField(complexArg: ComplexInput): String
  oneOfArgField(oneOfArg: OneOfInput): String
  multipleReqs(req1: Int!, req2: Int!): String
  nonNullFieldWithDefault(arg: Int! = 0): String
  multipleOpts(opt1: Int = 0, opt2: Int = 0): String
  multipleOptAndReq(req1: Int!, req2: Int!, opt1: Int = 0, opt2: Int = 0): String
}
type QueryRoot {
  human(id: ID): Human
  dog: Dog
  cat: Cat
  pet: Pet
  catOrDog: CatOrDog
  complicatedArgs: ComplicatedArgs
}
schema {
  query: QueryRoot
}
directive @onField on FIELD
"""
"""The schema of the graphql-js tests of `field_merging.rs`."""


def _schema(sdl: StringSlice) raises -> Schema:
    """Parse and validate a schema that must be valid."""
    var result = parse_and_validate_schema(sdl, "schema.graphql")
    assert_true(result[1].is_empty(), String(result[1]))
    return result[0].copy()


def _errors(schema: Schema, query: StringSlice) raises -> String:
    """Return the diagnostics of a query against a schema."""
    return String(
        parse_and_validate_executable(schema, query, "query.graphql")[1]
    )


def _expect_valid(query: StringSlice) raises:
    """Check that a query is valid against the graphql-js schema."""
    assert_equal(_errors(_schema(GRAPHQL_JS_TEST_SCHEMA), query), "")


def _expect_errors(query: StringSlice, expected: StringSlice) raises:
    """Check the diagnostics of a query against the graphql-js schema."""
    assert_equal(_errors(_schema(GRAPHQL_JS_TEST_SCHEMA), query), expected)


def _mixed(text: StringSlice) raises -> String:
    """Return the diagnostics of a mixed document."""
    return String(parse_mixed_validate(text, "schema.graphql")[2])


def _standalone(text: StringSlice) raises -> String:
    """Return the diagnostics of a document with no schema."""
    return String(validate_standalone_executable(text, "query.graphql"))


# --- field_merging.rs ------------------------------------------------------


def test_unique_fields() raises:
    _expect_valid(
        "fragment uniqueFields on Dog {\n  name\n  nickname\n}\n"
        "{ dog { ...uniqueFields } }\n"
    )


def test_identical_fields() raises:
    _expect_valid(
        "fragment mergeIdenticalFields on Dog {\n  name\n  name\n}\n"
        "{ dog { ...mergeIdenticalFields } }\n"
    )


def test_identical_fields_with_identical_args() raises:
    _expect_valid(
        "fragment f on Dog {\n  doesKnowCommand(dogCommand: SIT)\n"
        "  doesKnowCommand(dogCommand: SIT)\n}\n{ dog { ...f } }\n"
    )


def test_identical_fields_with_identical_directives() raises:
    _expect_valid(
        "fragment f on Dog {\n  name @include(if: true)\n"
        "  name @include(if: true)\n}\n{ dog { ...f } }\n"
    )


def test_different_args_with_different_aliases() raises:
    _expect_valid(
        "fragment f on Dog {\n  knowsSit: doesKnowCommand(dogCommand: SIT)\n"
        "  knowsDown: doesKnowCommand(dogCommand: DOWN)\n}\n{ dog { ...f } }\n"
    )


def test_different_directives_with_different_aliases() raises:
    _expect_valid(
        "fragment f on Dog {\n  nameIfTrue: name @include(if: true)\n"
        "  nameIfFalse: name @include(if: false)\n}\n{ dog { ...f } }\n"
    )


def test_different_skip_include_directives() raises:
    _expect_valid(
        "fragment f on Dog {\n  name @include(if: true)\n"
        "  name @include(if: false)\n}\n{ dog { ...f } }\n"
    )


def test_same_aliases_with_different_field_targets() raises:
    _expect_errors(
        (
            "fragment f on Dog {\n  fido: name\n  fido: nickname\n}\n"
            "{ dog { ...f } }\n"
        ),
        (
            "Error: cannot select different fields into the same alias `fido`\n"
            "╭─[ query.graphql:3:3 ]\n"
        ),
    )


def test_same_aliases_on_non_overlapping_fields() raises:
    _expect_valid(
        "fragment f on Pet {\n  ... on Dog {\n    name\n  }\n"
        "  ... on Cat {\n    name: nickname\n  }\n}\n{ pet { ...f } }\n"
    )


def test_alias_masking_direct_field_access() raises:
    _expect_errors(
        "fragment f on Dog {\n  name: nickname\n  name\n}\n{ dog { ...f } }\n",
        (
            "Error: cannot select different fields into the same alias `name`\n"
            "╭─[ query.graphql:3:3 ]\n"
        ),
    )


def test_different_args_second_adds_argument() raises:
    _expect_errors(
        (
            "fragment f on Dog {\n  doesKnowCommand\n"
            "  doesKnowCommand(dogCommand: HEEL)\n}\n{ dog { ...f } }\n"
        ),
        (
            "Error: operation must not provide conflicting field arguments for"
            " the same name `doesKnowCommand`\n╭─[ query.graphql:3:3 ]\n"
        ),
    )


def test_different_args_second_missess_argument() raises:
    _expect_errors(
        (
            "fragment f on Dog {\n  doesKnowCommand(dogCommand: SIT)\n"
            "  doesKnowCommand\n}\n{ dog { ...f } }\n"
        ),
        (
            "Error: operation must not provide conflicting field arguments for"
            " the same name `doesKnowCommand`\n╭─[ query.graphql:3:3 ]\n"
        ),
    )


def test_conflicting_arg_values() raises:
    _expect_errors(
        (
            "fragment f on Dog {\n  doesKnowCommand(dogCommand: SIT)\n"
            "  doesKnowCommand(dogCommand: HEEL)\n}\n{ dog { ...f } }\n"
        ),
        (
            "Error: operation must not provide conflicting field arguments for"
            " the same name `doesKnowCommand`\n╭─[ query.graphql:3:3 ]\n"
        ),
    )


def test_conflicting_arg_names() raises:
    _expect_errors(
        (
            "fragment f on Dog {\n  isAtLocation(x: 0)\n  isAtLocation(y:"
            " 0)\n}\n{ dog { ...f } }\n"
        ),
        (
            "Error: operation must not provide conflicting field arguments for"
            " the same name `isAtLocation`\n╭─[ query.graphql:3:3 ]\n"
        ),
    )


def test_different_non_conflicting_args() raises:
    _expect_valid(
        "fragment f on Pet {\n  ... on Dog {\n    name(surname: true)\n  }\n"
        "  ... on Cat {\n    name\n  }\n}\n{ pet { ...f } }\n"
    )


def test_different_order_args() raises:
    _expect_valid(
        "{\n  dog {\n    isAtLocation(x: 0, y: 1)\n"
        "    isAtLocation(y: 1, x: 0)\n  }\n}\n"
    )


def test_different_order_input_args() raises:
    _expect_valid(
        "{\n  complicatedArgs {\n    complexArgField(complexArg: { intField: 1,"
        " requiredField: true })\n    complexArgField(complexArg: {"
        " requiredField: true, intField: 1 })\n  }\n}\n"
    )


comptime CONFLICT_TEST_SCHEMA = """
type Type {
  a: Int
  b: Int
  c: Int
  d: Int
}
type T {
  a: Boolean
  b: Boolean
  c: Boolean
  d: Boolean
  deepField: Type
}
type Query {
  f1: Type
  f2: Type
  f3: Type
  field: T
}
"""
"""The schema of the `field_conflicts` tests."""


def _conflicts(query: StringSlice, expected: StringSlice) raises:
    """Check the diagnostics of a query against the conflict schema."""
    assert_equal(_errors(_schema(CONFLICT_TEST_SCHEMA), query), expected)


comptime _ALIAS_X = (
    "Error: cannot select different fields into the same alias `x`\n"
)
"""The message of a conflict on `x`."""


def test_conflicts_in_fragments() raises:
    _conflicts(
        (
            "{\n  f1 {\n    ...A\n    ...B\n  }\n}\nfragment A on Type {\n  x:"
            " a\n}\nfragment B on Type {\n  x: b\n}\n"
        ),
        _ALIAS_X + "╭─[ query.graphql:11:3 ]\n",
    )


def test_dedupe_conflicts() raises:
    _conflicts(
        (
            "{\n  f1 {\n    ...A\n    ...B\n  }\n  f2 {\n    ...B\n    ...A\n "
            " }\n  f3 {\n    ...A\n    ...B\n    x: c\n  }\n}\nfragment A on"
            " Type {\n  x: a\n}\nfragment B on Type {\n  x: b\n}\n"
        ),
        _ALIAS_X
        + "╭─[ query.graphql:17:3 ]\n"
        + _ALIAS_X
        + "╭─[ query.graphql:17:3 ]\n"
        + _ALIAS_X
        + "╭─[ query.graphql:20:3 ]\n"
        + _ALIAS_X
        + "╭─[ query.graphql:20:3 ]\n",
    )


def test_deep_conflict() raises:
    _conflicts(
        "{\n  f1 {\n    x: a\n  },\n  f1 {\n    x: b\n  }\n}\n",
        _ALIAS_X + "╭─[ query.graphql:6:5 ]\n",
    )


def test_deep_conflict_multiple_issues() raises:
    _conflicts(
        (
            "{\n  f1 {\n    x: a\n    y: c\n  },\n  f1 {\n    x: b\n    y: d\n "
            " }\n}\n"
        ),
        _ALIAS_X
        + "╭─[ query.graphql:7:5 ]\n"
        + "Error: cannot select different fields into the same alias `y`\n"
        + "╭─[ query.graphql:8:5 ]\n",
    )


def test_very_deep_conflict() raises:
    _conflicts(
        (
            "{\n  field {\n    deepField {\n      x: a\n    }\n  },\n"
            "  field {\n    deepField {\n      x: b\n    }\n  }\n}\n"
        ),
        _ALIAS_X + "╭─[ query.graphql:9:7 ]\n",
    )


def test_deep_conflict_in_fragments() raises:
    _conflicts(
        (
            "{\n  field {\n    ...F\n  }\n  field {\n    ...I\n  }\n}\nfragment"
            " F on T {\n  x: a\n  ...G\n}\nfragment G on T {\n  y:"
            " c\n}\nfragment I on T {\n  y: d\n  ...J\n}\nfragment J on T {\n "
            " x: b\n}\n"
        ),
        "Error: cannot select different fields into the same alias `y`\n"
        + "╭─[ query.graphql:14:3 ]\n"
        + _ALIAS_X
        + "╭─[ query.graphql:21:3 ]\n",
    )


comptime RETURN_TYPES_TEST_SCHEMA = """
interface SomeBox {
  deepBox: SomeBox
  unrelatedField: String
}
type StringBox implements SomeBox {
  scalar: String
  deepBox: StringBox
  unrelatedField: String
  listStringBox: [StringBox]
  stringBox: StringBox
  intBox: IntBox
}
type IntBox implements SomeBox {
  scalar: Int
  deepBox: IntBox
  unrelatedField: String
  listStringBox: [StringBox]
  stringBox: StringBox
  intBox: IntBox
}
interface NonNullStringBox1 {
  scalar: String!
}
type NonNullStringBox1Impl implements SomeBox & NonNullStringBox1 {
  scalar: String!
  unrelatedField: String
  deepBox: SomeBox
}
interface NonNullStringBox2 {
  scalar: String!
}
type NonNullStringBox2Impl implements SomeBox & NonNullStringBox2 {
  scalar: String!
  unrelatedField: String
  deepBox: SomeBox
}
type Connection {
  edges: [Edge]
}
type Edge {
  node: Node
}
type Node {
  id: ID
  name: String
}
type Query {
  someBox: SomeBox
  connection: Connection
}
"""
"""The schema of the `return_types` tests."""


def _returns(query: StringSlice, expected: StringSlice) raises:
    """Check the diagnostics of a query against the return types schema."""
    assert_equal(_errors(_schema(RETURN_TYPES_TEST_SCHEMA), query), expected)


comptime _TYPES_SCALAR = (
    "Error: operation must not select different types using the same name"
    " `scalar`\n"
)
"""The message of a type conflict on `scalar`."""


def test_conflicting_return_types_with_potential_overlap() raises:
    _returns(
        (
            "{\n  someBox {\n    ...on IntBox {\n      scalar\n    }\n"
            "    ...on NonNullStringBox1 {\n      scalar\n    }\n  }\n}\n"
        ),
        _TYPES_SCALAR + "╭─[ query.graphql:7:7 ]\n",
    )


def test_compatible_return_shapes_on_different_return_types() raises:
    _returns(
        (
            "{\n  someBox {\n    ... on SomeBox {\n      deepBox {\n"
            "        unrelatedField\n      }\n    }\n    ... on StringBox {\n"
            "      deepBox {\n        unrelatedField\n      }\n    }\n  }\n}\n"
        ),
        "",
    )


def test_no_differing_return_types_despite_no_overlap() raises:
    _returns(
        (
            "{\n  someBox {\n    ... on IntBox {\n      scalar\n    }\n"
            "    ... on StringBox {\n      scalar\n    }\n  }\n}\n"
        ),
        _TYPES_SCALAR + "╭─[ query.graphql:7:7 ]\n",
    )


def test_non_exclusive_follows_exclusive() raises:
    _returns(
        (
            "{\n  someBox {\n    ... on IntBox {\n      deepBox {\n       "
            " ...X\n      }\n    }\n  }\n  someBox {\n    ... on StringBox {\n "
            "     deepBox {\n        ...Y\n      }\n    }\n  }\n  memoed:"
            " someBox {\n    ... on IntBox {\n      deepBox {\n        ...X\n  "
            "    }\n    }\n  }\n  memoed: someBox {\n    ... on StringBox {\n  "
            "    deepBox {\n        ...Y\n      }\n    }\n  }\n  other: someBox"
            " {\n    ...X\n  }\n  other: someBox {\n    ...Y\n  }\n}\nfragment"
            " X on SomeBox {\n  scalar\n}\nfragment Y on SomeBox {\n  scalar:"
            " unrelatedField\n}\n"
        ),
        (
            "Error: type `SomeBox` does not have a field `scalar`\n"
            "╭─[ query.graphql:38:3 ]\n"
        ),
    )


def test_no_differing_nullability_despite_no_overlap() raises:
    _returns(
        (
            "{\n  someBox {\n    ... on NonNullStringBox1 {\n      scalar\n   "
            " }\n    ... on StringBox {\n      scalar\n    }\n  }\n}\n"
        ),
        _TYPES_SCALAR + "╭─[ query.graphql:7:7 ]\n",
    )


comptime _TYPES_BOX = (
    "Error: operation must not select different types using the same name"
    " `box`\n╭─[ query.graphql:9:7 ]\n"
)
"""The type conflict on `box`."""


def test_no_differing_list_despite_no_overlap() raises:
    _returns(
        (
            "{\n  someBox {\n    ... on IntBox {\n      box: listStringBox {\n"
            "        scalar\n      }\n    }\n    ... on StringBox {\n"
            "      box: stringBox {\n        scalar\n      }\n    }\n  }\n}\n"
        ),
        _TYPES_BOX,
    )
    _returns(
        (
            "{\n  someBox {\n    ... on IntBox {\n      box: stringBox {\n     "
            "   scalar\n      }\n    }\n    ... on StringBox {\n      box:"
            " listStringBox {\n        scalar\n      }\n    }\n  }\n}\n"
        ),
        _TYPES_BOX,
    )


def test_differing_sub_fields() raises:
    _returns(
        (
            "{\n  someBox {\n    ... on IntBox {\n      box: stringBox {\n     "
            "   val: scalar\n        val: unrelatedField\n      }\n    }\n   "
            " ... on StringBox {\n      box: stringBox {\n        val: scalar\n"
            "      }\n    }\n  }\n}\n"
        ),
        (
            "Error: cannot select different fields into the same alias `val`\n"
            "╭─[ query.graphql:6:9 ]\n"
        ),
    )


def test_differing_deep_return_types() raises:
    _returns(
        (
            "{\n  someBox {\n    ... on IntBox {\n      box: stringBox {\n"
            "        scalar\n      }\n    }\n    ... on StringBox {\n"
            "      box: intBox {\n        scalar\n      }\n    }\n  }\n}\n"
        ),
        _TYPES_SCALAR + "╭─[ query.graphql:10:9 ]\n",
    )


def test_non_conflicting_overlapping_types() raises:
    _returns(
        (
            "{\n  someBox {\n    ... on IntBox {\n      scalar:"
            " unrelatedField\n    }\n    ... on StringBox {\n      scalar\n   "
            " }\n  }\n}\n"
        ),
        "",
    )


def test_same_scalars() raises:
    _returns(
        (
            "{\n  someBox {\n    ...on NonNullStringBox1 {\n      scalar\n   "
            " }\n    ...on NonNullStringBox2 {\n      scalar\n    }\n  }\n}\n"
        ),
        "",
    )


def test_deep_types_including_list() raises:
    _returns(
        (
            "{\n  connection {\n    ...edgeID\n    edges {\n      node {\n"
            "        id: name\n      }\n    }\n  }\n}\n\n"
            "fragment edgeID on Connection {\n  edges {\n    node {\n      id\n"
            "    }\n  }\n}\n"
        ),
        (
            "Error: operation must not select different types using the same"
            " name `id`\n╭─[ query.graphql:15:7 ]\nError: cannot select"
            " different fields into the same alias `id`\n╭─["
            " query.graphql:15:7 ]\n"
        ),
    )


# --- operation.rs ----------------------------------------------------------

comptime _PET_SCHEMA = """
type Query {
  cat: Pet
}
union CatOrDog = Cat | Dog
interface Pet {
  name: String
  nickname: String
}
type Dog implements Pet {
  name: String
  nickname: String
  barkVolume: Int
}
type Cat implements Pet {
  name: String
  nickname: String
  meowVolume: Int
}
"""
"""The schema of the operation tests."""


def test_it_fails_validation_with_missing_ident() raises:
    var errors = _mixed(
        "query {\n  cat {\n    name\n  }\n}\nquery getPet {\n  cat {\n"
        "    name\n  }\n}\nquery getOtherPet {\n  cat {\n    nickname\n  }\n}\n"
        "type Query {\n  cat: Cat\n}\ntype Cat {\n  name: String\n"
        "  nickname: String\n  meowVolume: Int\n}\n"
    )
    assert_true(
        "anonymous operation cannot be selected when the document contains"
        " other operations"
        in errors,
        errors,
    )


def test_it_fails_validation_with_duplicate_operation_names() raises:
    var errors = _mixed(
        "query getName {\n  cat {\n    name\n  }\n}\nquery getName {\n"
        "  cat {\n    name\n    nickname\n  }\n}\n"
        + _PET_SCHEMA
    )
    assert_true(
        "the operation `getName` is defined multiple times in the document"
        in errors,
        errors,
    )


def test_it_validates_unique_operation_names() raises:
    assert_equal(
        _mixed(
            "query getCatName {\n  cat {\n    name\n  }\n}\n"
            "query getPetNickname {\n  cat {\n    nickname\n  }\n}\n"
            + _PET_SCHEMA
        ),
        "",
    )


def test_it_raises_an_error_for_illegal_operations() raises:
    var errors = _mixed(
        "subscription sub {\n  newMessage {\n    body\n    sender\n  }\n}\n"
        + _PET_SCHEMA
    )
    # Upstream finds the text of the report label; the message is this.
    assert_true(
        "`subscription` root operation type is not defined" in errors, errors
    )


def test_it_validates_fields_in_operations() raises:
    var errors = _mixed(
        "query getProduct {\n  name\n  noName\n  topProducts {\n    inStock\n"
        "    price\n  }\n}\ntype Query {\n  name: String\n"
        "  topProducts: Product\n}\ntype Product {\n  inStock: Boolean\n"
        "  name: String\n}\n"
    )
    assert_true("`Query` does not have a field `noName`" in errors, errors)
    assert_true(
        "type `Product` does not have a field `price`" in errors, errors
    )


# --- variable.rs -----------------------------------------------------------


def test_it_raises_undefined_variable_in_query_error() raises:
    var errors = _mixed(
        "query ExampleQuery {\n  topProducts(first: $undefinedVariable) {\n   "
        " name\n  }\n  me {\n    ... on User {\n      id\n      name\n     "
        " profilePic(size: $dimensions)\n      status\n    }\n  }\n}\ntype"
        " Query {\n  topProducts(first: Int): Products\n  me: User\n}\ntype"
        " User {\n  id: ID\n  name: String\n  profilePic(size: Int): String\n "
        " status(membership: String): String\n}\ntype Products {\n  weight:"
        " Float\n  size: Int\n  name: String\n}\n"
    )
    assert_true(
        "variable `$undefinedVariable` is not defined" in errors, errors
    )
    assert_true("variable `$dimensions` is not defined" in errors, errors)


def test_it_raises_unused_variable_in_query_error() raises:
    var errors = _mixed(
        "query ExampleQuery($unusedVariable: Int) {\n  topProducts {\n"
        "    name\n  }\n  ... multipleSubscriptions\n}\n"
        "type Query {\n  topProducts(first: Int): Product,\n}\n"
        "type Product {\n  name: String\n  price(setPrice: Int): Int\n}\n"
    )
    assert_true("unused variable: `$unusedVariable`" in errors, errors)


def test_it_raises_undefined_variable_in_query_in_fragments_error() raises:
    var errors = _mixed(
        "query ExampleQuery {\n  topProducts {\n    name\n  }\n  me {\n    ..."
        " on User {\n      id\n      name\n      status(membership:"
        " $goldStatus)\n    }\n  }\n  ... fragmentOne\n}\nfragment fragmentOne"
        " on Query {\n    profilePic(size: $dimensions)\n}\ntype Query {\n "
        " topProducts: Product\n  profilePic(size: Int): String\n  me:"
        " User\n}\ntype User {\n    id: ID\n    name: String\n   "
        " status(membership: String): String\n}\ntype Product {\n  name:"
        " String\n  price(setPrice: Int): Int\n}\n"
    )
    assert_true("variable `$goldStatus` is not defined" in errors, errors)
    assert_true("variable `$dimensions` is not defined" in errors, errors)


# --- recursion.rs ----------------------------------------------------------


def _fragment_chain(size: Int) -> String:
    """Return `size` fragments that each go into a field and spread the
    next: upstream `build_fragment_chain`."""
    var query = String(
        "\n      query Introspection{\n        __schema {\n           types {\n"
        "            ...typeFragment1\n          }\n        }\n      }\n    "
    )
    for i in range(1, size):
        query += String(
            "\n          fragment typeFragment",
            i,
            " on __Type {\n            ofType {\n              ...typeFragment",
            i + 1,
            "\n            }\n          }",
        )
    query += String(
        "\n          fragment typeFragment",
        size,
        (
            " on __Type {\n            ofType {\n              name\n          "
            "  }\n          }"
        ),
    )
    return query^


def _flat_fragment_chain(size: Int) -> String:
    """Return `size` fragments that each spread the next: upstream
    `build_flat_fragment_chain`."""
    var query = String(
        "\n      query Introspection{\n        __schema {\n          types {\n"
        "            ...typeFragment1\n          }\n        }\n      }\n    "
    )
    for i in range(1, size):
        query += String(
            "\n          fragment typeFragment",
            i,
            " on __Type {\n            ...typeFragment",
            i + 1,
            "\n          }",
        )
    query += String(
        "\n          fragment typeFragment",
        size,
        " on __Type {\n            name\n          }",
    )
    return query^


def _count(text: String, part: StringSlice) -> Int:
    """Return how many times `part` is in `text`."""
    return text.count(part)


def test_long_nested_fragment_chains_do_not_overflow_stack() raises:
    var errors = String(
        parse_mixed_validate(
            "type Query { a: Int }\n            " + _fragment_chain(1000),
            "overflow.graphql",
        )[2]
    )
    assert_equal(_count(errors, "Error: too much recursion\n"), 3, errors)
    assert_true(
        "Error: `typeFragment1` contains too much nesting\n"
        "╭─[ overflow.graphql:11:11 ]\n"
        in errors,
        errors,
    )
    assert_equal(_count(errors, "Error: "), 4, errors)


def test_long_flat_fragment_chains_do_not_overflow_stack() raises:
    var errors = String(
        parse_mixed_validate(
            "type Query { a: Int }\n            " + _flat_fragment_chain(10000),
            "overflow.graphql",
        )[2]
    )
    assert_equal(_count(errors, "Error: too much recursion\n"), 2, errors)
    assert_true(
        "Error: `typeFragment1` contains too much nesting\n"
        "╭─[ overflow.graphql:11:11 ]\n"
        in errors,
        errors,
    )
    assert_equal(_count(errors, "Error: "), 3, errors)


def test_long_flat_fragment_chains_do_not_overflow_stack_in_subscriptions() raises:
    var size = 10000
    var query = String(
        "\n      subscription {\n        ...subscriptionFragment1\n     "
        " }\n    "
    )
    for i in range(1, size):
        query += String(
            "\n          fragment subscriptionFragment",
            i,
            " on Subscription {\n            ...subscriptionFragment",
            i + 1,
            "\n          }",
        )
    query += String(
        "\n          fragment subscriptionFragment",
        size,
        " on Subscription {\n            a\n          }",
    )
    var errors = String(
        parse_mixed_validate(
            "\n            type Query { notUsed: Int }\n"
            "            type Subscription { a: Int }\n            "
            + query,
            "overflow.graphql",
        )[2]
    )
    assert_equal(_count(errors, "Error: too much recursion\n"), 3, errors)
    assert_true(
        "Error: `subscriptionFragment1` contains too much nesting\n"
        "╭─[ overflow.graphql:9:11 ]\n"
        in errors,
        errors,
    )
    assert_equal(_count(errors, "Error: "), 4, errors)


def test_not_long_enough_fragment_chain_applies_correctly() raises:
    assert_equal(
        String(
            parse_mixed_validate(
                "type Query { a: Int }\n            " + _fragment_chain(99),
                "no_overflow.graphql",
            )[2]
        ),
        "",
    )


def test_deeply_nested_selection_bails_out() raises:
    var query = String("query ")
    for _ in range(400):
        query += "{ recur\n"
    query += "{ leaf(arg: true) leaf(arg: false) }"
    for _ in range(400):
        query += "\n}"
    var errors = String(
        parse_mixed_validate(
            "\ntype Recur {\n  recur: Recur\n  leaf(arg: Boolean): Int\n}\n"
            "type Query {\n  recur: Recur\n}\n    \n"
            + query,
            "selection.graphql",
        )[2]
    )
    assert_true(errors.startswith("Error: too much recursion\n"), errors)
    assert_equal(_count(errors, "Error: "), 1, errors)


def test_handles_directive_with_nested_input_types() raises:
    var schema = _schema(
        "directive @custom(input: NestedInput) on OBJECT | INTERFACE\n"
        "input NestedInput {\n    name: String\n    nested: NestedInput\n}\n"
        "type Query {\n  foo: String\n}\n"
    )
    assert_equal(_errors(schema, "query {\n    foo\n}\n"), "")


# --- branches that the upstream tests do not reach -------------------------

comptime _DEFER = (
    "directive @defer(if: Boolean! = true, label: String) on FRAGMENT_SPREAD"
    " | INLINE_FRAGMENT directive @d on FIELD | FRAGMENT_SPREAD |"
    " INLINE_FRAGMENT "
)
"""The `@defer` directive and a directive with no effect."""


def _single(text: StringSlice) raises -> String:
    """Return the diagnostics of a one-line mixed document."""
    return String(parse_mixed_validate(text, "q.graphql")[2])


def test_standalone_operations_and_inline_fragments() raises:
    var errors = _standalone("query A { a } query A { b } { c }")
    assert_true("the operation `A` is defined multiple times" in errors, errors)
    errors = _standalone("{ a } { b }")
    assert_equal(_count(errors, "anonymous operation cannot be selected"), 2)
    assert_equal(
        _standalone("{ ... on T { a @skip(if: true, if: false) } ... { b } }"),
        (
            "Error: the argument `if` is provided multiple times\n"
            "╭─[ query.graphql:1:32 ]\n"
        ),
    )


def test_subscription_introspection_fields() raises:
    var errors = _single(
        "schema { query: Q subscription: Q } type Q { a: Int }"
        " subscription S { __schema { description } } subscription T {"
        ' __type(name: "Q") { name } }'
    )
    assert_true(
        "Error: subscription `S` can not have an introspection field as a root"
        " field\n╭─[ q.graphql:1:72 ]\n"
        in errors,
        errors,
    )
    assert_true(
        "Error: subscription `T` can not have an introspection field as a root"
        " field\n╭─[ q.graphql:1:116 ]\n"
        in errors,
        errors,
    )
    assert_equal(
        _single(
            _DEFER
            + "type Query { a: Int } type Subscription { a: Int }"
            " subscription { a @d }"
        ),
        "",
    )


def test_defer_label_of_another_kind() raises:
    assert_equal(
        _single(
            _DEFER
            + "type Query { a: T } type T { b: Int }"
            " { a { ... @defer(label: 1) { b } } }"
        ),
        (
            "Error: expected value of type String, found an integer\n"
            "╭─[ q.graphql:1:211 ]\n"
        ),
    )


def test_defer_through_fragments() raises:
    assert_equal(
        _single(
            _DEFER
            + "type Query { a: Int } type Mutation { a: Int }"
            " mutation { ...F ...F ...G ... @defer { a } }"
            " fragment F on Mutation { a }"
        ),
        (
            "Error: cannot find fragment `G` in this document\n"
            "╭─[ q.graphql:1:217 ]\n"
            "Error: `@defer` is not allowed on root selections of mutation"
            " operations\n╭─[ q.graphql:1:226 ]\n"
        ),
    )
    var errors = _single(
        _DEFER
        + "type Query { a: Int } type Subscription { a: Int }"
        " subscription { ... @defer { a } ...F ...F ...G }"
        " fragment F on Subscription { a }"
    )
    assert_true(
        "`@defer` is not allowed on root selections of subscription operations"
        in errors,
        errors,
    )
    assert_equal(
        _count(errors, "`@defer` in a subscription operation must be disabled"),
        1,
        errors,
    )


def test_defer_conditions_in_subscriptions() raises:
    var errors = _single(
        _DEFER
        + "type Query { a: Int } type Subscription { a: Int b: Int }"
        " subscription { ... @d @defer(if: false) { a }"
        " ... @defer(if: $v) { b }"
        " ... @skip(if: false) @include(if: true) @defer { a }"
        " ... @skip(if: true) { a } ... @include(if: false) { a } }"
    )
    assert_equal(
        _count(errors, "`@defer` in a subscription operation must be disabled"),
        1,
        errors,
    )
    assert_true(
        "Error: `@defer` in a subscription operation must be disabled with an"
        " `if` argument\n╭─[ q.graphql:1:318 ]\n"
        in errors,
        errors,
    )
    assert_equal(_count(errors, "can not specify @skip or @include"), 3)


def test_undefined_field_types() raises:
    assert_equal(
        _single(
            "type Query { a: Missing b: Missing c: Int }"
            " { a x: a x: b y: c y: b }"
        ),
        (
            "Error: cannot find type `Missing` in this document\n"
            "╭─[ q.graphql:1:17 ]\n"
            "Error: cannot find type `Missing` in this document\n"
            "╭─[ q.graphql:1:28 ]\n"
            "Error: cannot select different fields into the same alias `x`\n"
            "╭─[ q.graphql:1:54 ]\n"
            "Error: cannot select different fields into the same alias `y`\n"
            "╭─[ q.graphql:1:64 ]\n"
        ),
    )
    assert_equal(
        _single(
            "type Query { a: Missing } { a { ...F } } fragment F on Query { a }"
        ),
        (
            "Error: cannot find type `Missing` in this document\n"
            "╭─[ q.graphql:1:17 ]\n"
        ),
    )


def test_fragment_on_a_scalar() raises:
    assert_equal(
        _single(
            "type Query { dog: Dog } type Dog { name: String }"
            " { dog { ...F } } fragment F on Int { a }"
        ),
        (
            "Error: fragment `F` with type condition `Int` cannot be applied to"
            " `Dog`\n╭─[ q.graphql:1:59 ]\nError: fragment `F` must have a"
            " composite type in its type condition\n╭─[ q.graphql:1:68"
            " ]\nError: type `Int` does not have a field `a`\n╭─["
            " q.graphql:1:88 ]\n"
        ),
    )


def test_undefined_interface() raises:
    assert_equal(
        _single(
            "type Query { dog: Dog } type Dog implements Missing { name: String"
            " } interface Pet { name: String } { dog { ... on Pet { name } } }"
        ),
        (
            "Error: cannot find type `Missing` in this document\n╭─["
            " q.graphql:1:45 ]\nError: inline fragment with type condition"
            " `Pet` cannot be applied to `Dog`\n╭─[ q.graphql:1:109 ]\n"
        ),
    )


def test_fragment_cycle_away_from_the_root() raises:
    assert_equal(
        _single(
            "type Query { a: Int } { ...A } fragment A on Query { ...Missing"
            " ...B } fragment B on Query { ...C } fragment C on Query { ...B }"
        ),
        (
            "Error: cannot find fragment `Missing` in this document\n╭─["
            " q.graphql:1:54 ]\nError: `B` fragment cannot reference"
            " itself\n╭─[ q.graphql:1:72 ]\n"
        ),
    )


def test_merged_sets_are_shared() raises:
    assert_equal(
        _single(
            "type Query { a: Int dog: Dog } type Dog { name: String }"
            " fragment F on Query { dog { name } } query O1 { ...F }"
            " query O2 { ...F dog { name } }"
        ),
        "",
    )
    assert_equal(
        _single(
            "type Query { a: Int dog: Dog } type Dog { name: String }"
            " { x: a x: dog { name } }"
        ),
        (
            "Error: operation must not select different types using the same"
            " name `x`\n╭─[ q.graphql:1:65 ]\nError: cannot select different"
            " fields into the same alias `x`\n╭─[ q.graphql:1:65 ]\n"
        ),
    )


comptime _VALUES = (
    "input I { a: Int b: [Int] } type Query { f(x: I, y: [Int], z: String,"
    " w: Int, e: E): Int } enum E { A B } "
)
"""A schema for argument values."""

comptime _CONFLICT_F = (
    "Error: operation must not provide conflicting field arguments for the"
    " same name `f`\n"
)
"""The argument conflict on `f`."""


def test_same_argument_values() raises:
    assert_equal(
        _single(
            _VALUES
            + "query($v: Int) { a: f(w: null) a: f(w: null)"
            ' b: f(z: "s") b: f(z: """s""") c: f(y: [1, 2]) c: f(y: [1])'
            " d: f(x: {a: 1, b: [1]}) d: f(x: {b: [1], a: 1})"
            " e: f(w: $v) e: f(w: $v) g: f(e: A) g: f(e: A) }"
        ),
        "",
    )
    assert_equal(
        _single(_VALUES + "{ a: f(w: 1) a: f(w: null) }"),
        _CONFLICT_F + "╭─[ q.graphql:1:120 ]\n",
    )
    assert_equal(
        _single(_VALUES + "{ a: f(y: [1]) a: f(y: [2]) }"),
        _CONFLICT_F + "╭─[ q.graphql:1:122 ]\n",
    )
    assert_equal(
        _single(_VALUES + "{ a: f(x: {a: 1}) a: f(x: {a: 1, b: [1]}) }"),
        _CONFLICT_F + "╭─[ q.graphql:1:125 ]\n",
    )
    assert_equal(
        _single(_VALUES + "{ a: f(x: {a: 1}) a: f(x: {b: [1]}) }"),
        _CONFLICT_F + "╭─[ q.graphql:1:125 ]\n",
    )
    assert_equal(
        _single(_VALUES + "{ a: f(x: {a: 1}) a: f(x: {a: 2}) }"),
        _CONFLICT_F + "╭─[ q.graphql:1:125 ]\n",
    )
    assert_equal(
        _single(_VALUES + '{ a: f(z: "s") a: f(z: "t") }'),
        _CONFLICT_F + "╭─[ q.graphql:1:122 ]\n",
    )


def test_many_arguments() raises:
    var args = String()
    for i in range(21):
        args += String("a", i, ": 1 ")
    var schema = String("type Query { f: Int } ")
    var errors = _single(schema + "{ f(" + args + ") f(" + args + ") }")
    assert_equal(_count(errors, "conflicting field arguments"), 0, errors)
    errors = _single(schema + "{ f(" + args + ") f(" + args + "b: 1) }")
    assert_equal(_count(errors, "conflicting field arguments"), 1, errors)
    errors = _single(schema + "{ f(" + args + "b: 1) f(" + args + ") }")
    assert_equal(_count(errors, "conflicting field arguments"), 1, errors)


def test_deep_selections_stop_the_walks() raises:
    var deep = String("{ ")
    for _ in range(502):
        deep += "r { "
    deep += "l"
    for _ in range(502):
        deep += " }"
    deep += " }"
    var errors = _single("type Query { r: R } type R { r: R l: Int } " + deep)
    assert_equal(_count(errors, "Error: too much recursion\n"), 3, errors)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
