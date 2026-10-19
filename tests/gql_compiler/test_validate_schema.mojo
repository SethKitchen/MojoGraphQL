# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for schema validation.

Port of the schema tests of apollo-compiler 1.33.0 (`b7eee5c`)
`tests/validation/object.rs`, `tests/validation/interface.rs` and
`tests/validation/ignore_builtin_redefinition.rs`, under the MIT arm of its
MIT OR Apache-2.0 license. The `tests/validation/types.rs` tests validate
executable documents, so they are not here. The other tests reach each
check of `gql_compiler/validate_schema.mojo`.
"""

from gql_compiler.from_ast import SchemaBuilder
from gql_compiler.validation import (
    parse_and_validate_schema,
    parse_mixed_validate,
    validate_schema,
)
from std.testing import TestSuite, assert_equal, assert_true


def _report(text: String) raises -> String:
    """Return the diagnostics of a schema, one `line:column message` line
    each."""
    var result = parse_and_validate_schema(text, "schema.graphql")
    var out = String()
    ref list = result[1]
    var index = 0
    while index < len(list.diagnostics):
        ref diagnostic = list.diagnostics[index]
        out += String(
            diagnostic.line, ":", diagnostic.column, " ", diagnostic.message()
        )
        out += "\n"
        index += 1
    return out


def _has(report: String, text: String) raises:
    """Assert that a report contains a text."""
    assert_true(text in report, report)


comptime _QUERY = "type Query { a: Int }\n"
"""A query root type, for schemas that test something else."""


# --- tests/validation/object.rs -----------------------------------------


def test_object_non_output_field_types() raises:
    """Upstream `it_generates_diagnostics_for_non_output_field_types`."""
    var input = """
query mainPage {
  width
}

type Query {
  width: Int
  img: Url
  relationship: Person
  entity: NamedEntity
  depth: Number
  result: SearchResult
  permissions: Auth
  coordinates: Point2D
  main: mainPage
}

type Person {
  name: String
  age: Int
}

type Photo {
  size: Int
  type: String
}

interface NamedEntity {
  name: String
}

enum Number {
  INT
  FLOAT
}

union SearchResult = Photo | Person

directive @Auth(username: String!) repeatable on OBJECT | INTERFACE

input Point2D {
  x: Float
  y: Float
}

scalar Url @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")
"""
    var result = parse_mixed_validate(input, "doc.graphql")
    var out = String()
    ref list = result[2]
    var index = 0
    while index < len(list.diagnostics):
        out += list.diagnostics[index].message() + "\n"
        index += 1
    _has(out, "`coordinates` field must return an output type")
    _has(out, "cannot find type `Auth` in this document")
    _has(out, "cannot find type `mainPage` in this document")


# --- tests/validation/interface.rs --------------------------------------


def test_interface_duplicate_fields() raises:
    """Upstream `it_fails_validation_with_duplicate_operation_fields`."""
    var report = _report(
        """
type Query implements NamedEntity {
  imgSize: Int
  name: String
  image: URL
  results: [Int]
}

interface NamedEntity {
  name: String
  image: URL
  results: [Int]
  name: String
}

scalar URL @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")
"""
    )
    _has(
        report,
        (
            "duplicate definitions for the `name` field of interface type"
            " `NamedEntity`"
        ),
    )


def test_interface_duplicate_definitions() raises:
    """Upstream `it_fails_validation_with_duplicate_interface_definitions`."""
    var report = _report(
        """
type Query implements NamedEntity {
  imgSize: Int
  name: String
  image: URL
  results: [Int]
}

interface NamedEntity {
  name: String
  image: URL
  results: [Int]
}

interface NamedEntity {
  name: String
  image: URL
  results: [Int]
}

scalar URL @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")
"""
    )
    _has(report, "the type `NamedEntity` is defined multiple times")


def test_interface_recursive_definition() raises:
    """Upstream `it_fails_validation_with_recursive_interface_definition`."""
    var report = _report(
        """
type Query implements NamedEntity {
  imgSize: Int
  name: String
  image: URL
  results: [Int]
}

interface NamedEntity implements NamedEntity {
  name: String
  image: URL
  results: [Int]
}

scalar URL @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")
"""
    )
    _has(report, "9:34 interface NamedEntity cannot implement itself")


def test_interface_undefined_definition() raises:
    """Upstream `it_fails_validation_with_undefined_interface_definition`."""
    var report = _report(
        """
interface NamedEntity implements NewEntity {
  name: String
  image: URL
  results: [Int]
}

scalar URL @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")
"""
    )
    _has(report, "2:34 cannot find type `NewEntity` in this document")


def test_interface_missing_transitive_interface() raises:
    """Upstream `it_fails_validation_with_missing_transitive_interface`."""
    var report = _report(
        """
type Query implements Node {
  id: ID!
}

interface Node {
  id: ID!
}

interface Resource implements Node {
  id: ID!
  width: Int
}

interface Image implements Resource & Node {
  id: ID!
  thumbnail: String
}
"""
    )
    _has(
        report,
        (
            "15:1 type `Image` does not satisfy interface `Resource`: missing"
            " field `width`"
        ),
    )


def test_interface_non_output_field_types() raises:
    """Upstream `it_generates_diagnostics_for_non_output_field_types` of
    `interface.rs`."""
    var input = """
query mainPage {
  name {
    width
  }
}

type Query {
  name: mainInterface
}

interface mainInterface {
  width: Int
  img: Url
  relationship: Person
  entity: NamedEntity
  depth: Number
  result: SearchResult
  permissions: Auth
  coordinates: Point2D
  main: mainPage
}

type Person {
  name: String
  age: Int
}

type Photo {
  size: Int
  type: String
}

interface NamedEntity {
  name: String
}

enum Number {
  INT
  FLOAT
}

union SearchResult = Photo | Person

directive @Auth(username: String!) repeatable on OBJECT | INTERFACE

input Point2D {
  x: Float
  y: Float
}

scalar Url @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")
"""
    var result = parse_mixed_validate(input, "doc.graphql")
    var out = String()
    ref list = result[2]
    var index = 0
    while index < len(list.diagnostics):
        out += list.diagnostics[index].message() + "\n"
        index += 1
    _has(out, "`coordinates` field must return an output type")


def test_interface_field_type_not_subtype() raises:
    """Upstream
    `it_fails_validation_when_object_field_type_is_not_subtype_of_interface_field`.
    """
    var report = _report(
        """
type Query implements Node {
  id: ID!
}

interface Node {
  id: ID!
}

interface Product {
  details: ProductDetails!
}

type ProductDetails {
  name: String
}

type DigitalProduct implements Product {
  details: ProductDetails
}
"""
    )
    assert_equal(
        report,
        (
            "19:3 interface field `Product.details` expects type"
            " `ProductDetails!` but `DigitalProduct.details` of type"
            " `ProductDetails` is not a proper subtype\n"
        ),
    )


def test_interface_covariant_field_types() raises:
    """Upstream `it_accepts_valid_covariant_interface_field_types`."""
    var report = _report(
        """
type Query implements Node {
  id: ID!
}

interface Node {
  id: ID!
}

interface Animal {
  name: String
}

type Dog implements Animal {
  name: String!
}
"""
    )
    assert_equal(report, "")


def test_interface_list_item_not_subtype() raises:
    """Upstream `it_fails_validation_when_list_item_type_is_not_subtype`."""
    var report = _report(
        """
type Query implements Node {
  id: ID!
}

interface Node {
  id: ID!
}

interface Collection {
  items: [Item!]!
}

type Item {
  name: String
}

type MyCollection implements Collection {
  items: [Item]!
}
"""
    )
    assert_equal(
        report,
        (
            "19:3 interface field `Collection.items` expects type `[Item!]!`"
            " but `MyCollection.items` of type `[Item]!` is not a proper"
            " subtype\n"
        ),
    )


def test_interface_union_member_subtype() raises:
    """Upstream `it_accepts_union_member_as_subtype_of_union_interface_field`.
    """
    var report = _report(
        """
type Query {
  search: SearchResult
}

union SearchResult = Photo | Person

type Photo {
  url: String
}

type Person {
  name: String
}

interface HasSearch {
  search: SearchResult
}

type SearchPage implements HasSearch {
  search: Photo
}
"""
    )
    assert_equal(report, "")


def test_interface_to_interface_covariance() raises:
    """Upstream `it_accepts_interface_to_interface_covariance`."""
    var report = _report(
        """
type Query {
  node: Node
}

interface Node {
  id: ID!
}

interface Resource implements Node {
  id: ID!
  url: String
}

interface HasNode {
  node: Node
}

type ResourcePage implements HasNode {
  node: Resource
}
"""
    )
    assert_equal(report, "")


def test_interface_non_covariant_interface_field() raises:
    """Upstream
    `it_fails_validation_when_interface_implementing_interface_has_non_covariant_field`.
    """
    var report = _report(
        """
type Query {
  node: Node
}

interface Node {
  id: ID!
}

interface Base {
  node: Node!
}

interface Child implements Base {
  node: Node
}
"""
    )
    assert_equal(
        report,
        (
            "15:3 interface field `Base.node` expects type `Node!` but"
            " `Child.node` of type `Node` is not a proper subtype\n"
        ),
    )


def test_interface_nested_list_mismatch() raises:
    """Upstream `it_fails_validation_with_nested_list_type_mismatch`."""
    var report = _report(
        """
type Query {
  grid: [[Item]]
}

type Item {
  name: String
}

interface HasGrid {
  grid: [[Item]!]!
}

type MyGrid implements HasGrid {
  grid: [[Item]]
}
"""
    )
    assert_equal(
        report,
        (
            "15:3 interface field `HasGrid.grid` expects type `[[Item]!]!` but"
            " `MyGrid.grid` of type `[[Item]]` is not a proper subtype\n"
        ),
    )


def test_interface_missing_argument() raises:
    """Upstream
    `it_fails_validation_when_object_field_missing_interface_argument`."""
    var report = _report(
        """
type Query {
  node: Node
}

interface Node {
  field(id: ID!): String
}

type MyNode implements Node {
  field: String
}
"""
    )
    assert_equal(
        report,
        (
            "11:3 interface field `Node.field` expects argument `id` but"
            " `MyNode.field` does not provide it\n"
        ),
    )


def test_interface_argument_type_differs() raises:
    """Upstream `it_fails_validation_when_implementation_argument_type_differs`.
    """
    var report = _report(
        """
type Query {
  node: Node
}

interface Node {
  field(id: ID!): String
}

type MyNode implements Node {
  field(id: String!): String
}
"""
    )
    assert_equal(
        report,
        (
            "11:9 interface field `Node.field` expects argument `id` of type"
            " `ID!` but `MyNode.field` provides type `String!`\n"
        ),
    )


def test_interface_extra_required_argument() raises:
    """Upstream
    `it_fails_validation_when_implementation_has_extra_required_argument`.
    """
    var report = _report(
        """
type Query {
  node: Node
}

interface Node {
  field(id: ID!): String
}

type MyNode implements Node {
  field(id: ID!, extra: String!): String
}
"""
    )
    assert_equal(
        report,
        (
            "11:18 `MyNode.field` has extra required argument `extra` not"
            " present in interface `Node.field`\n"
        ),
    )


def test_interface_extra_optional_argument() raises:
    """Upstream `it_accepts_implementation_with_extra_optional_argument`."""
    var report = _report(
        """
type Query {
  node: Node
}

interface Node {
  field(id: ID!): String
}

type MyNode implements Node {
  field(id: ID!, extra: String): String
}
"""
    )
    assert_equal(report, "")


def test_interface_extra_argument_with_default() raises:
    """Upstream `it_accepts_implementation_with_extra_argument_with_default`."""
    var report = _report(
        """
type Query {
  node: Node
}

interface Node {
  field(id: ID!): String
}

type MyNode implements Node {
  field(id: ID!, extra: String! = "default"): String
}
"""
    )
    assert_equal(report, "")


def test_interface_implementing_interface_mismatched_argument() raises:
    """Upstream
    `it_fails_validation_when_interface_implementing_interface_has_mismatched_argument`.
    """
    var report = _report(
        """
type Query {
  node: Node
}

interface Node {
  field(id: ID!): String
}

interface Child implements Node {
  field(id: String!): String
}
"""
    )
    assert_equal(
        report,
        (
            "11:9 interface field `Node.field` expects argument `id` of type"
            " `ID!` but `Child.field` provides type `String!`\n"
        ),
    )


def test_interface_matching_arguments() raises:
    """Upstream `it_accepts_matching_arguments_on_implementation`."""
    var report = _report(
        """
type Query {
  node: Node
}

interface Node {
  field(id: ID!, name: String): String
}

type MyNode implements Node {
  field(id: ID!, name: String): String
}
"""
    )
    assert_equal(report, "")


# --- tests/validation/ignore_builtin_redefinition.rs ---------------------


comptime _SCALARS = """
  scalar String
  scalar Int
  scalar Float
  scalar Boolean
  scalar ID
  type Query {
    foo: String
  }
  """
"""The schema of upstream `handles_built_in_scalar_redefinition`."""


def test_built_in_scalar_redefinition() raises:
    """Upstream `handles_built_in_scalar_redefinition`."""
    var report = _report(_SCALARS)
    assert_equal(
        report,
        (
            "2:3 built-in scalar definitions must be omitted\n"
            "3:3 built-in scalar definitions must be omitted\n"
            "4:3 built-in scalar definitions must be omitted\n"
            "5:3 built-in scalar definitions must be omitted\n"
            "6:3 built-in scalar definitions must be omitted\n"
        ),
    )
    var builder = SchemaBuilder().ignore_builtin_redefinitions_on()
    builder.parse(_SCALARS)
    var schema = builder^.build()
    assert_equal(len(validate_schema(schema)), 0)


comptime _INTROSPECTION = """
     type __Directive {
       name: String!
       description: String!
       isRepeatable: String!
       args: __InputValue
       locations: String!
     }
     type __Schema {
       description: String
       types: [__Type!]
       queryType: __Type!
       mutationType: __Type
       subscriptionType: __Type
       directives: [__Directive!]
     }
     type __Type {
       kind: __TypeKind!
       name: String
       description: String
       fields: [__Field!]
       interfaces: [__Type!]
       possibleTypes: [__Type!]
       enumValues: [__EnumValue!]
       inputFields: [__InputValue!]
       ofType: __Type
       specifiedByURL: String
     }

     enum __TypeKind {
       SCALAR
       OBJECT
       INTERFACE
       UNION
       ENUM
       INPUT_OBJECT
       LIST
     }

     type __Field {
       name: String!
       description: String
       args: [__InputValue!]!
       type: __Type!
       isDeprecated: Boolean!
       deprecationReason: String
     }

     type __InputValue {
       name: String!
       description: String
       type: __Type!
       defaultValue: String
       deprecationReason: String
     }

     type __EnumValue {
       name: String!
       description: String
       deprecationReason: String
     }

     type Query {
       foo: String
     }
     """
"""The schema of upstream `handles_built_in_type_redefinition`."""


def test_built_in_type_redefinition() raises:
    """Upstream `handles_built_in_type_redefinition`."""
    # The primary locations are in the built-in document, so only the
    # messages are compared. No reserved name is reported: the redefined
    # types are not in the schema.
    var report = _report(_INTROSPECTION)
    assert_equal(report.count("\n"), 7, report)
    var names: List[String] = [
        "__Directive",
        "__Schema",
        "__Type",
        "__TypeKind",
        "__Field",
        "__InputValue",
        "__EnumValue",
    ]
    var index = 0
    while index < len(names):
        _has(
            report,
            String(
                " the type `",
                names[index],
                "` is defined multiple times in the schema\n",
            ),
        )
        index += 1
    var builder = SchemaBuilder().ignore_builtin_redefinitions_on()
    builder.parse(_INTROSPECTION)
    var schema = builder^.build()
    assert_equal(len(validate_schema(schema)), 0)


# --- the other checks of validate_schema.mojo ----------------------------


def test_reserved_names() raises:
    """A name that starts with `__` is reserved: upstream
    `validate_type_system_name`."""
    var report = _report(
        """type Query { a: Int __f(__a: Int): Int }
type __T { a: Int }
enum E { __V A }
input I { __i: Int }
directive @__d(x: Int) on FIELD
"""
    )
    assert_equal(
        report,
        (
            "1:21 a field cannot be named `__f` as names starting with two"
            " underscores are reserved\n1:25 an argument cannot be named `__a`"
            " as names starting with two underscores are reserved\n2:6 an"
            " object type cannot be named `__T` as names starting with two"
            " underscores are reserved\n3:10 an enum value cannot be named"
            " `__V` as names starting with two underscores are reserved\n4:11"
            " an input object field cannot be named `__i` as names starting"
            " with two underscores are reserved\n5:12 a directive definition"
            " cannot be named `__d` as names starting with two underscores are"
            " reserved\n"
        ),
    )


def test_missing_query_root() raises:
    """A schema needs a query root operation."""
    assert_equal(
        _report("schema { mutation: M }\ntype M { a: Int }\n"),
        "1:1 missing query root operation type in schema definition\n",
    )
    _has(
        _report("type Foo { a: Int }\n"),
        "missing query root operation type in schema definition",
    )


def test_root_operations() raises:
    """A root operation type must be a defined object type, used once."""
    assert_equal(
        _report(
            "schema { query: Query mutation: Missing subscription: Query }\n"
            + _QUERY
        ),
        (
            "1:33 cannot find type `Missing` in this document\n"
            "1:55 the same type `Query` must not be used for multiple root"
            " operation types\n"
        ),
    )
    assert_equal(
        _report("schema { query: S }\nscalar S\n"),
        "1:17 `S` field must return an object type\n",
    )


def test_schema_and_type_directives() raises:
    """The directives of the schema and of each type are validated."""
    var report = _report(
        """directive @d on SCHEMA | SCALAR | ENUM_VALUE
schema @d { query: Query }
type Query { a: Int }
scalar S @d
enum E { A @d }
"""
    )
    assert_equal(report, "")


def test_empty_types() raises:
    """A type needs at least one member."""
    var report = _report(
        _QUERY + "type O\ninterface I\nunion U\nenum E\ninput In\n"
    )
    assert_equal(
        report,
        (
            "2:1 `O` has no fields\n"
            "3:1 `I` has no fields\n"
            "4:1 `U` has no member types\n"
            "5:1 `E` has no enum values\n"
            "6:1 `In` has no input values\n"
        ),
    )


def test_union_members() raises:
    """A union member must be a defined object type."""
    var report = _report(_QUERY + "union U = Query | Missing | S\nscalar S\n")
    assert_equal(
        report,
        (
            "2:19 cannot find type `Missing` in this document\n"
            "2:29 union member `S` must be an object type\n"
        ),
    )


def test_field_and_input_value_types() raises:
    """A field needs an output type, an input value an input type."""
    var report = _report(
        """type Query {
  a: Missing
  b: In
  c(x: Query, y: I, z: U, w: Nope, v: In): [Int!]
}
interface I { a: Int }
union U = Query
input In { o: Query, s: String }
"""
    )
    assert_equal(
        report,
        (
            "2:6 cannot find type `Missing` in this document\n"
            "3:3 `b` field must return an output type\n"
            "4:5 `x` field must be of an input type\n"
            "4:15 `y` field must be of an input type\n"
            "4:21 `z` field must be of an input type\n"
            "4:30 cannot find type `Nope` in this document\n"
            "8:12 `o` field must be of an input type\n"
        ),
    )


def test_unique_argument_definitions() raises:
    """An argument must be defined once."""
    var report = _report(
        "type Query { a(x: Int, y: Int, x: Int, x: Int): Int }\n"
        "directive @d(z: Int, z: Int) on FIELD\n"
    )
    assert_equal(
        report,
        (
            "1:16 the value `x` is defined multiple times\n"
            "1:16 the value `x` is defined multiple times\n"
            "2:14 the value `z` is defined multiple times\n"
        ),
    )


def test_implements_non_interface() raises:
    """A type can implement only an interface type."""
    var report = _report(
        _QUERY + "type T implements S & Missing { a: Int }\nscalar S\n"
    )
    assert_equal(
        report,
        (
            "2:19 cannot find type `S` in this document\n"
            "2:23 cannot find type `Missing` in this document\n"
        ),
    )


def test_missing_interface_field() raises:
    """An object type must define each field of its interfaces."""
    var report = _report(
        _QUERY
        + "interface I { a: Int b: Int }\ntype T implements I { a: Int }\n"
    )
    assert_equal(
        report,
        "3:1 type `T` does not satisfy interface `I`: missing field `b`\n",
    )


def test_transitive_interface_of_object() raises:
    """An object type must implement the interfaces of its interfaces."""
    var report = _report(
        _QUERY
        + "interface A { a: Int }\ninterface B implements A { a: Int }\n"
        + "type T implements B { a: Int }\n"
    )
    assert_equal(
        report,
        (
            "4:1 interface `T` declares that it implements `B`, but to do so it"
            " must also implement `A`\n"
        ),
    )


def test_implementation_field_subtypes() raises:
    """The subtype rule of `is_valid_implementation_field_type`."""
    var report = _report(
        """type Query { a: Int }
interface I {
  undefinedAbstract: Missing
  undefinedSubtype: I
  scalarSubtype: I
  objectAbstract: Query
  unionMember: U
  notMember: U
  listForNamed: Int
  namedForList: [Int]
}
union U = Query
type T implements I {
  undefinedAbstract: Other
  undefinedSubtype: Nope
  scalarSubtype: Int
  objectAbstract: T
  unionMember: Query
  notMember: T
  listForNamed: [Int]
  namedForList: Int
}
"""
    )
    assert_equal(
        report,
        (
            "3:22 cannot find type `Missing` in this document\n14:3 interface"
            " field `I.undefinedAbstract` expects type `Missing` but"
            " `T.undefinedAbstract` of type `Other` is not a proper"
            " subtype\n14:22 cannot find type `Other` in this document\n15:3"
            " interface field `I.undefinedSubtype` expects type `I` but"
            " `T.undefinedSubtype` of type `Nope` is not a proper"
            " subtype\n15:21 cannot find type `Nope` in this document\n16:3"
            " interface field `I.scalarSubtype` expects type `I` but"
            " `T.scalarSubtype` of type `Int` is not a proper subtype\n17:3"
            " interface field `I.objectAbstract` expects type `Query` but"
            " `T.objectAbstract` of type `T` is not a proper subtype\n19:3"
            " interface field `I.notMember` expects type `U` but `T.notMember`"
            " of type `T` is not a proper subtype\n20:3 interface field"
            " `I.listForNamed` expects type `Int` but `T.listForNamed` of type"
            " `[Int]` is not a proper subtype\n21:3 interface field"
            " `I.namedForList` expects type `[Int]` but `T.namedForList` of"
            " type `Int` is not a proper subtype\n"
        ),
    )


def test_recursive_input_objects() raises:
    """A non-null input field must not lead back to its input object."""
    var report = _report(
        _QUERY
        + """input A { b: B! list: [A]! nullable: A }
input B { b: B! s: String! m: Missing! q: Query! }
input C { a: A! }
"""
    )
    assert_equal(
        report,
        (
            "3:1 `B` input object cannot reference itself\n"
            "3:31 cannot find type `Missing` in this document\n"
            "3:40 `q` field must be of an input type\n"
        ),
    )


def _chain(prefix: String, count: Int, open: String, close: String) -> String:
    """Return `count` input objects where each one has a field of the next
    one."""
    var text = String()
    var index = 0
    while index < count:
        text += String(
            "input ",
            prefix,
            index,
            " { n: ",
            open,
            prefix,
            index + 1,
            close,
            " }\n",
        )
        index += 1
    return text + String("input ", prefix, count, " { s: String }\n")


def test_deeply_nested_input_object() raises:
    """An input object chain over the recursion limit is reported."""
    var report = _report(_QUERY + _chain("J", 32, "", "!"))
    assert_equal(report, "2:1 `J0` contains too much nesting\n")
    assert_equal(_report(_QUERY + _chain("J", 31, "", "!")), "")


def test_object_subtype_of_interface() raises:
    """An object type that implements an interface is its subtype."""
    var report = _report(
        _QUERY + "interface I { f: I }\ntype T implements I { f: T }\n"
    )
    assert_equal(report, "")


def test_recursive_directives() raises:
    """A directive definition must not apply itself: upstream
    `FindRecursiveDirective`."""
    var report = _report(
        """type Query { a: Int }
directive @a(x: Int @a) on ARGUMENT_DEFINITION
directive @b(x: Int @a @undefined) on ARGUMENT_DEFINITION
directive @e(x: Missing) on FIELD
directive @f(x: R) on FIELD
input R { r: R }
directive @g(x: E) on ENUM_VALUE
enum E { V @g W }
directive @h(x: In) on INPUT_FIELD_DEFINITION
input In { f: Int @h }
directive @k(x: Obj) on OBJECT
type Obj @k { a: Int }
directive @m(x: P) on FIELD
enum P @n { V }
directive @n on ENUM
"""
    )
    assert_equal(
        report,
        (
            "2:1 `a` directive definition cannot reference itself\n"
            "3:24 cannot find directive `@undefined` in this document\n"
            "4:17 cannot find type `Missing` in this document\n"
            "7:1 `g` directive definition cannot reference itself\n"
            "9:1 `h` directive definition cannot reference itself\n"
            "11:1 `k` directive definition cannot reference itself\n"
            "11:14 `x` field must be of an input type\n"
        ),
    )


def _directive_chain(count: Int) -> String:
    """Return `count` directives where each one applies the next one."""
    var text = String()
    var index = 0
    while index < count:
        text += String(
            "directive @d",
            index,
            "(x: Int @d",
            index + 1,
            ") on ARGUMENT_DEFINITION\n",
        )
        index += 1
    return text + String("directive @d", count, " on ARGUMENT_DEFINITION\n")


def test_deeply_nested_directive() raises:
    """A directive chain over the recursion limit is reported."""
    assert_equal(
        _report(_QUERY + _directive_chain(32)),
        "2:1 `d0` contains too much nesting\n",
    )
    assert_equal(_report(_QUERY + _directive_chain(31)), "")


def test_deeply_nested_directive_argument_type() raises:
    """An input type chain under a directive over the recursion limit is
    reported."""
    var head = _QUERY + "directive @deep(x: K0) on FIELD\n"
    assert_equal(
        _report(head + _chain("K", 32, "", "")),
        "2:1 `deep` contains too much nesting\n",
    )
    assert_equal(_report(head + _chain("K", 31, "", "")), "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
