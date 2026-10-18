# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the router's introspection resolver.

Upstream Hive Router `1a29df9`
`bin/router/src/executor/introspection/resolve.rs` has no unit tests. These
tests check the rules of upstream `resolve_introspection` on the consumer
schema of a small supergraph: the operation is normalized against the
supergraph, partitioned, and resolved.
"""

from gql_json.parser import parse as parse_json
from gql_json.value import JsonDocument
from gql_json.writer import stringify
from gql_language.ast import Document
from gql_language.parser import parse
from gql_router.ast import ItemKind, ValueKind
from gql_router.consumer_schema import ConsumerSchema
from gql_router.exec_introspection import resolve_introspection
from gql_router.exec_partition import partition_operation
from gql_router.exec_variables import CoerceVariablesPayload
from gql_router.federation_spec import OperationKind
from gql_router.operation import OperationDefinition
from gql_router.planner import Planner
from gql_router.schema_metadata import schema_metadata
from gql_router.store import Store
from std.testing import TestSuite, assert_equal, assert_true


def _sdl() -> String:
    """Return a supergraph with every kind of type."""
    return String(
        """
schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
  @link(url: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {
  query: Query
}

directive @join__enumValue(graph: join__Graph!) repeatable on ENUM_VALUE

directive @join__field(
  graph: join__Graph
  requires: join__FieldSet
  provides: join__FieldSet
  type: String
  external: Boolean
  override: String
  usedOverridden: Boolean
) repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION

directive @join__graph(name: String!, url: String!) on ENUM_VALUE

directive @join__implements(
  graph: join__Graph!
  interface: String!
) repeatable on OBJECT | INTERFACE

directive @join__type(
  graph: join__Graph!
  key: join__FieldSet
  extension: Boolean! = false
  resolvable: Boolean! = true
  isInterfaceObject: Boolean! = false
) repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT | SCALAR

directive @join__unionMember(
  graph: join__Graph!
  member: String!
) repeatable on UNION

directive @link(
  url: String
  as: String
  for: link__Purpose
  import: [link__Import]
) repeatable on SCHEMA

directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION

"Marks a field."
directive @custom(level: Int = 1) repeatable on FIELD_DEFINITION | OBJECT

scalar join__FieldSet

enum join__Graph {
  A @join__graph(name: "a", url: "http://a")
}

scalar link__Import

enum link__Purpose {
  SECURITY
  EXECUTION
}

"A calendar date."
scalar Date @join__type(graph: A) @specifiedBy(url: "https://example.com/date")

scalar Plain @join__type(graph: A)

"Something with an id."
interface Node @join__type(graph: A) {
  id: ID!
}

interface Secret @join__type(graph: A) @inaccessible {
  code: String
}

type User implements Node & Secret
  @join__type(graph: A)
  @join__implements(graph: A, interface: "Node") {
  id: ID!
  "The name."
  name(
    upper: Boolean = false
    "A prefix."
    prefix: String @deprecated(reason: "No prefix.")
  ): String
  old: String @deprecated(reason: "Use name.")
  older: String @deprecated
  role: Role @custom(level: 2)
  tags: [String!]!
  code: String @inaccessible
}

type Admin implements Node
  @join__type(graph: A)
  @join__implements(graph: A, interface: "Node") {
  id: ID!
}

union Account
  @join__type(graph: A)
  @join__unionMember(graph: A, member: "User")
  @join__unionMember(graph: A, member: "Admin") = User | Admin

enum Role @join__type(graph: A) {
  "Can read."
  READER
  WRITER @deprecated(reason: "Gone.")
}

input Filter @join__type(graph: A) @oneOf {
  id: ID
  name: String = "x"
}

input Range @join__type(graph: A) {
  from: Int = 1
  to: [Int!] = [1, 2]
}

type Query @join__type(graph: A) {
  user(id: ID!, filter: Filter, range: Range): User
  account: Account
  node: Node
  date: Date
  plain: Plain
}
"""
    )


def _variables(text: String) raises -> CoerceVariablesPayload:
    """Read a JSON object as coerced variables; empty for none."""
    var payload = CoerceVariablesPayload()
    if text.byte_length() == 0:
        return payload^
    payload.document = parse_json(text)
    var child = payload.document.first(payload.document.root)
    while child != -1:
        payload.insert(payload.document.key(child), child)
        child = payload.document.next(child)
    return payload^


struct _Fixture(Movable):
    """The planner and the consumer schema of the test supergraph."""

    var planner: Planner
    """Normalizes the queries against the supergraph."""
    var consumer: ConsumerSchema
    """The consumer schema."""

    def __init__(out self) raises:
        """Read the test supergraph."""
        self.planner = Planner(_sdl())
        self.consumer = ConsumerSchema.new_from_supergraph(parse(_sdl()))

    def run(mut self, query: String, variables: String = "") raises -> String:
        """Normalize, partition and resolve a query; return the data JSON."""
        var metadata = schema_metadata(self.consumer.document)
        var operation = self.planner.normalize(query)
        var parts = partition_operation(self.planner.store, operation)
        var out = JsonDocument()
        var data = resolve_introspection(
            self.planner.store,
            parts.introspection_operation,
            self.consumer.document,
            metadata,
            _variables(variables),
            out,
        )
        return stringify(out, data)


def test_schema_query_type_and_types() raises:
    var fixture = _Fixture()
    assert_equal(
        fixture.run("{ __schema { queryType { name } types { name kind } } }"),
        (
            '{"__schema":{"queryType":{"name":"Query"},"types":['
            '{"name":"Date","kind":"SCALAR"},{"name":"Plain","kind":"SCALAR"},'
            '{"name":"Node","kind":"INTERFACE"},{"name":"User","kind":"OBJECT"},'
            '{"name":"Admin","kind":"OBJECT"},{"name":"Account","kind":"UNION"},'
            '{"name":"Role","kind":"ENUM"},'
            '{"name":"Filter","kind":"INPUT_OBJECT"},'
            '{"name":"Range","kind":"INPUT_OBJECT"},'
            '{"name":"Query","kind":"OBJECT"},'
            '{"name":"Boolean","kind":"SCALAR"},{"name":"Float","kind":"SCALAR"},'
            '{"name":"Int","kind":"SCALAR"},{"name":"ID","kind":"SCALAR"},'
            '{"name":"String","kind":"SCALAR"},'
            '{"name":"__Schema","kind":"OBJECT"},'
            '{"name":"__Type","kind":"OBJECT"},'
            '{"name":"__Field","kind":"OBJECT"},'
            '{"name":"__InputValue","kind":"OBJECT"},'
            '{"name":"__EnumValue","kind":"OBJECT"},'
            '{"name":"__TypeKind","kind":"ENUM"},'
            '{"name":"__Directive","kind":"OBJECT"},'
            '{"name":"__DirectiveLocation","kind":"ENUM"}]}}'
        ),
    )
    assert_equal(
        fixture.run(
            "{ __schema { description mutationType { name } subscriptionType"
            " { name } __typename bogus } }"
        ),
        (
            '{"__schema":{"description":null,"mutationType":null,'
            '"subscriptionType":null,"__typename":"__Schema","bogus":null}}'
        ),
    )


def test_type_with_field_type_chains() raises:
    var fixture = _Fixture()
    assert_equal(
        fixture.run(
            '{ __type(name: "User") { name fields { name type { kind name'
            " __typename bogus ofType { kind name ofType { kind name ofType {"
            " name } } } } } } }"
        ),
        (
            '{"__type":{"name":"User","fields":['
            '{"name":"id","type":{"kind":"NON_NULL","name":null,'
            '"__typename":"__Type","bogus":null,'
            '"ofType":{"kind":"SCALAR","name":"ID","ofType":null}}},'
            '{"name":"name","type":{"kind":"SCALAR","name":"String",'
            '"__typename":"__Type","bogus":null,"ofType":null}},'
            '{"name":"role","type":{"kind":"ENUM","name":"Role",'
            '"__typename":"__Type","bogus":null,"ofType":null}},'
            '{"name":"tags","type":{"kind":"NON_NULL","name":null,'
            '"__typename":"__Type","bogus":null,'
            '"ofType":{"kind":"LIST","name":null,'
            '"ofType":{"kind":"NON_NULL","name":null,'
            '"ofType":{"name":"String"}}}}}]}}'
        ),
    )


def test_fields_args_and_deprecation() raises:
    var fixture = _Fixture()
    assert_equal(
        fixture.run(
            '{ __type(name: "User") { fields(includeDeprecated: true) { name'
            " description isDeprecated deprecationReason __typename bogus"
            " args { name description defaultValue type { name } isDeprecated"
            " deprecationReason __typename bogus } } interfaces { name } } }"
        ),
        (
            '{"__type":{"fields":['
            '{"name":"id","description":null,"isDeprecated":false,'
            '"deprecationReason":null,"__typename":"__Field","bogus":null,'
            '"args":[]},'
            '{"name":"name","description":"The name.","isDeprecated":false,'
            '"deprecationReason":null,"__typename":"__Field","bogus":null,'
            '"args":[{"name":"upper","description":null,'
            '"defaultValue":"false","type":{"name":"Boolean"},'
            '"isDeprecated":false,"deprecationReason":null,'
            '"__typename":"__InputValue","bogus":null},'
            '{"name":"prefix","description":"A prefix.","defaultValue":null,'
            '"type":{"name":"String"},"isDeprecated":true,'
            '"deprecationReason":"No prefix.","__typename":"__InputValue",'
            '"bogus":null}]},'
            '{"name":"old","description":null,"isDeprecated":true,'
            '"deprecationReason":"Use name.","__typename":"__Field",'
            '"bogus":null,"args":[]},'
            '{"name":"older","description":null,"isDeprecated":true,'
            '"deprecationReason":null,"__typename":"__Field","bogus":null,'
            '"args":[]},'
            '{"name":"role","description":null,"isDeprecated":false,'
            '"deprecationReason":null,"__typename":"__Field","bogus":null,'
            '"args":[]},'
            '{"name":"tags","description":null,"isDeprecated":false,'
            '"deprecationReason":null,"__typename":"__Field","bogus":null,'
            '"args":[]}],'
            # `Secret` is inaccessible, so the consumer schema lacks it.
            '"interfaces":[{"name":"Node"}]}}'
        ),
    )


def test_include_deprecated_from_literals_and_variables() raises:
    var fixture = _Fixture()
    comptime all = (
        '{"__type":{"fields":[{"name":"id"},{"name":"name"},{"name":"old"},'
        '{"name":"older"},{"name":"role"},{"name":"tags"}]}}'
    )
    comptime current = (
        '{"__type":{"fields":[{"name":"id"},{"name":"name"},{"name":"role"},'
        '{"name":"tags"}]}}'
    )
    comptime by_variable = (
        'query Q($d: Boolean) { __type(name: "User") {'
        " fields(includeDeprecated: $d) { name } } }"
    )
    assert_equal(fixture.run(by_variable, '{"d": true}'), all)
    assert_equal(fixture.run(by_variable, '{"d": false}'), current)
    assert_equal(fixture.run(by_variable), current)
    assert_equal(
        fixture.run(
            '{ __type(name: "User") { fields(includeDeprecated: false) {'
            " name } } }"
        ),
        current,
    )
    assert_equal(
        fixture.run('{ __type(name: "User") { fields { name } } }'), current
    )


def test_interface_and_query_fields() raises:
    var fixture = _Fixture()
    assert_equal(
        fixture.run(
            '{ __type(name: "Node") { kind description fields { name }'
            " interfaces { name } } }"
        ),
        (
            '{"__type":{"kind":"INTERFACE","description":"Something with an'
            ' id.","fields":[{"name":"id"}],"interfaces":null}}'
        ),
    )
    # The fields that start with `__` are not listed.
    assert_equal(
        fixture.run('{ __type(name: "Query") { fields { name } } }'),
        (
            '{"__type":{"fields":[{"name":"user"},{"name":"account"},'
            '{"name":"node"},{"name":"date"},{"name":"plain"}]}}'
        ),
    )
    assert_equal(
        fixture.run(
            '{ __type(name: "Query") { fields { args { name type { kind'
            " ofType { name } } } } } }"
        ),
        (
            '{"__type":{"fields":[{"args":['
            '{"name":"id","type":{"kind":"NON_NULL","ofType":{"name":"ID"}}},'
            '{"name":"filter","type":{"kind":"INPUT_OBJECT","ofType":null}},'
            '{"name":"range","type":{"kind":"INPUT_OBJECT","ofType":null}}]},'
            '{"args":[]},{"args":[]},{"args":[]},{"args":[]}]}}'
        ),
    )


def test_possible_types() raises:
    var fixture = _Fixture()
    assert_equal(
        fixture.run('{ __type(name: "Node") { kind possibleTypes { name } } }'),
        (
            '{"__type":{"kind":"INTERFACE","possibleTypes":[{"name":"User"},'
            '{"name":"Admin"}]}}'
        ),
    )
    assert_equal(
        fixture.run(
            '{ __type(name: "Account") { kind possibleTypes { name } } }'
        ),
        (
            '{"__type":{"kind":"UNION","possibleTypes":[{"name":"User"},'
            '{"name":"Admin"}]}}'
        ),
    )
    assert_equal(
        fixture.run('{ __type(name: "User") { possibleTypes { name } } }'),
        '{"__type":{"possibleTypes":null}}',
    )


def test_enum_values() raises:
    var fixture = _Fixture()
    assert_equal(
        fixture.run(
            '{ __type(name: "Role") { kind enumValues { name description'
            " isDeprecated deprecationReason __typename bogus } } }"
        ),
        (
            '{"__type":{"kind":"ENUM","enumValues":[{"name":"READER",'
            '"description":"Can read.","isDeprecated":false,'
            '"deprecationReason":null,"__typename":"__EnumValue",'
            '"bogus":null}]}}'
        ),
    )
    assert_equal(
        fixture.run(
            '{ __type(name: "Role") { enumValues(includeDeprecated: true) {'
            " name isDeprecated deprecationReason } } }"
        ),
        (
            '{"__type":{"enumValues":[{"name":"READER","isDeprecated":false,'
            '"deprecationReason":null},{"name":"WRITER","isDeprecated":true,'
            '"deprecationReason":"Gone."}]}}'
        ),
    )
    # A value that is not a boolean is False, as upstream.
    assert_equal(
        fixture.run(
            '{ __type(name: "Role") { enumValues(includeDeprecated: "yes") {'
            " name } } }"
        ),
        '{"__type":{"enumValues":[{"name":"READER"}]}}',
    )


def test_input_objects() raises:
    var fixture = _Fixture()
    assert_equal(
        fixture.run(
            '{ __type(name: "Filter") { kind isOneOf inputFields { name'
            " defaultValue type { name } } } }"
        ),
        (
            '{"__type":{"kind":"INPUT_OBJECT","isOneOf":true,"inputFields":['
            '{"name":"id","defaultValue":null,"type":{"name":"ID"}},'
            '{"name":"name","defaultValue":"\\"x\\"","type":{"name":"String"}}'
            "]}}"
        ),
    )
    assert_equal(
        fixture.run(
            '{ __type(name: "Range") { isOneOf inputFields { name'
            " defaultValue type { kind } } } }"
        ),
        (
            '{"__type":{"isOneOf":false,"inputFields":['
            '{"name":"from","defaultValue":"1","type":{"kind":"SCALAR"}},'
            '{"name":"to","defaultValue":"[1, 2]","type":{"kind":"LIST"}}]}}'
        ),
    )


def test_scalars_and_other_kinds() raises:
    var fixture = _Fixture()
    comptime every = (
        " kind name description specifiedByURL isOneOf fields { name }"
        " interfaces { name } possibleTypes { name } enumValues { name }"
        " inputFields { name } ofType { name } __typename"
    )
    assert_equal(
        fixture.run('{ __type(name: "Date") {' + every + " } }"),
        (
            '{"__type":{"kind":"SCALAR","name":"Date","description":"A'
            ' calendar date.","specifiedByURL":"https://example.com/date",'
            '"isOneOf":null,"fields":null,"interfaces":null,'
            '"possibleTypes":null,"enumValues":null,"inputFields":null,'
            '"ofType":null,"__typename":"__Type"}}'
        ),
    )
    assert_equal(
        fixture.run('{ __type(name: "Plain") { description specifiedByURL } }'),
        '{"__type":{"description":null,"specifiedByURL":null}}',
    )
    assert_equal(
        fixture.run(
            '{ __type(name: "Account") { specifiedByURL fields { name } } }'
        ),
        '{"__type":{"specifiedByURL":null,"fields":null}}',
    )


def test_directives() raises:
    var fixture = _Fixture()
    assert_equal(
        fixture.run("{ __schema { directives { name isRepeatable } } }"),
        (
            '{"__schema":{"directives":[{"name":"custom","isRepeatable":true},'
            '{"name":"skip","isRepeatable":false},'
            '{"name":"include","isRepeatable":false},'
            '{"name":"deprecated","isRepeatable":false},'
            '{"name":"specifiedBy","isRepeatable":false},'
            '{"name":"oneOf","isRepeatable":false}]}}'
        ),
    )
    var text = fixture.run(
        "{ __schema { directives { name description locations args { name"
        " defaultValue } __typename bogus } } }"
    )
    assert_true(
        String(
            '{"name":"custom","description":"Marks a field.","locations":'
            '["FIELD_DEFINITION","OBJECT"],"args":[{"name":"level",'
            '"defaultValue":"1"}],"__typename":"__Directive","bogus":null}'
        )
        in text
    )
    assert_true(
        String(
            '{"name":"skip","description":"Directs the executor to skip this'
            " field or fragment when the `if` argument is"
            ' true.","locations":["FIELD","FRAGMENT_SPREAD","INLINE_FRAGMENT"],'
            '"args":[{"name":"if","defaultValue":null}]'
        )
        in text
    )


def test_type_name_from_literals_and_variables() raises:
    var fixture = _Fixture()
    comptime by_variable = "query Q($n: String) { __type(name: $n) { name } }"
    assert_equal(
        fixture.run(by_variable, '{"n": "Role"}'), '{"__type":{"name":"Role"}}'
    )
    assert_equal(fixture.run(by_variable, '{"n": 5}'), '{"__type":null}')
    assert_equal(fixture.run(by_variable), '{"__type":null}')
    assert_equal(
        fixture.run('{ __type(name: "Nope") { name } }'), '{"__type":null}'
    )
    assert_equal(fixture.run("{ __type(name: 5) { name } }"), '{"__type":null}')
    assert_equal(fixture.run("{ __type { name } }"), '{"__type":null}')


def test_aliases_fragments_and_unknown_root_fields() raises:
    var fixture = _Fixture()
    assert_equal(
        fixture.run(
            '{ a: __type(name: "Plain") { n: name k: kind } s: __schema { q:'
            " queryType { name } } __foo }"
        ),
        '{"a":{"n":"Plain","k":"SCALAR"},"s":{"q":{"name":"Query"}},"__foo":null}',
    )
    assert_equal(
        fixture.run('{ __type(name: "Node") { ... on __Type { name } kind } }'),
        '{"__type":{"name":"Node","kind":"INTERFACE"}}',
    )
    # An inline fragment directly in `__schema` adds nothing, as upstream.
    assert_equal(
        fixture.run(
            "{ __schema { ... on __Schema { description } __typename } }"
        ),
        '{"__schema":{"__typename":"__Schema"}}',
    )


def _string_args(mut store: Store, name: StringSlice, text: StringSlice) -> Int:
    """Intern the argument map `{name: "text"}`."""
    var value = store.add_value(ValueKind.STRING)
    store.values[value].text = store.sym(text)
    return store.intern_args([store.sym(name)], [value])


def _field(
    mut store: Store, parent: Int, name: StringSlice, alias: StringSlice = ""
) -> Int:
    """Add a field as the last child of a set."""
    var field = store.add_item(ItemKind.FIELD, store.sym(name))
    if alias.byte_length() > 0:
        store.items[field].alias = store.sym(alias)
    store.append(parent, field)
    return field


def _resolve(
    store: Store, schema: Document, kind: OperationKind, root: Int
) -> String:
    """Resolve a hand-built operation."""
    var out = JsonDocument()
    var data = resolve_introspection(
        store,
        OperationDefinition(kind, root),
        schema,
        schema_metadata(schema),
        CoerceVariablesPayload(),
        out,
    )
    return stringify(out, data)


def test_hand_built_operations() raises:
    # A schema that the consumer schema never is: a duplicate type, a type
    # reference to a type it lacks, and directives with odd arguments.
    var schema = parse(
        """
        schema { query: Q mutation: M subscription: S }
        type Q { a: Missing b: Int c: Int @deprecated(reason: null) }
        type M { x: Int }
        type S { y: Int }
        type Q { dup: Int }
        scalar Odd @specifiedBy(foo: "x")
        scalar Odd2 @specifiedBy(url: 5)
        scalar Int
        """
    )
    var store = Store()
    var root = store.new_set()
    # A fragment spread adds nothing.
    store.append(root, store.add_item(ItemKind.SPREAD, store.sym("F")))
    _ = _field(store, root, "__typename")
    var schema_field = _field(store, root, "__schema")
    var types = _field(store, schema_field, "types")
    _ = _field(store, types, "name")
    store.append(schema_field, store.add_item(ItemKind.SPREAD, store.sym("G")))
    var type_field = _field(store, root, "__type")
    store.items[type_field].args = _string_args(store, "name", "Q")
    var fields = _field(store, type_field, "fields")
    var include = store.add_value(ValueKind.BOOLEAN)
    store.values[include].number = 1
    store.items[fields].args = store.intern_args(
        [store.sym("includeDeprecated")], [include]
    )
    _ = _field(store, fields, "name")
    var field_type = _field(store, fields, "type")
    _ = _field(store, field_type, "name")
    _ = _field(store, fields, "deprecationReason")
    var odd = _field(store, root, "__type", "t2")
    store.items[odd].args = _string_args(store, "name", "Odd")
    _ = _field(store, odd, "specifiedByURL")
    var odd2 = _field(store, root, "__type", "t3")
    store.items[odd2].args = _string_args(store, "name", "Odd2")
    _ = _field(store, odd2, "specifiedByURL")
    assert_equal(
        _resolve(store, schema, OperationKind.QUERY, root),
        (
            '{"__typename":"Q","__schema":{"types":[{"name":"Q"},{"name":"M"},'
            '{"name":"S"},{"name":"Odd"},{"name":"Odd2"},{"name":"Int"}]},'
            '"__type":{"fields":[{"name":"a","type":null,'
            '"deprecationReason":null},{"name":"b","type":{"name":"Int"},'
            '"deprecationReason":null},{"name":"c","type":{"name":"Int"},'
            '"deprecationReason":null}]},"t2":{"specifiedByURL":null},'
            '"t3":{"specifiedByURL":null}}'
        ),
    )
    var typename_only = store.new_set()
    _ = _field(store, typename_only, "__typename")
    assert_equal(
        _resolve(store, schema, OperationKind.MUTATION, typename_only),
        '{"__typename":"M"}',
    )
    assert_equal(
        _resolve(store, schema, OperationKind.SUBSCRIPTION, typename_only),
        '{"__typename":"S"}',
    )


def test_missing_query_type_is_null() raises:
    var schema = parse("type M { x: Int }")
    var store = Store()
    var root = store.new_set()
    var schema_field = _field(store, root, "__schema")
    var query_type = _field(store, schema_field, "queryType")
    _ = _field(store, query_type, "name")
    assert_equal(
        _resolve(store, schema, OperationKind.QUERY, root),
        '{"__schema":{"queryType":null}}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
