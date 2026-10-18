# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Composition of the subgraphs of upstream test cases.

Each test composes the subgraphs of one case of another suite of this
directory. The cases come from the upstream files that those suites port,
such as `__tests__/composition.spec.ts`. The expected supergraph SDL and
public SDL are what Hive Federation Composition v0.27.0 `composeServices`
prints for the same subgraphs.
"""

from _harness import sg
from gql_composition.compose import compose_subgraphs
from gql_composition.validate import Subgraph
from std.testing import TestSuite, assert_equal


def _check(subgraphs: List[Subgraph], sdl: String, public: String) raises:
    """Compose subgraphs and compare both printed schemas.

    Args:
        subgraphs: The subgraphs.
        sdl: The expected supergraph SDL.
        public: The expected public SDL.

    Raises:
        Error: If composition fails or a schema differs.
    """
    var result = compose_subgraphs(subgraphs)
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, sdl)
    assert_equal(result.public_sdl, public)


def test_v2_1_preserve_directive_from_one_subgraph_if_defined_differently_across_subgraph() raises:
    # test_composition.mojo
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/lowercase/v1.0", import:'
                    ' ["@lowercase"]) @composeDirective(name:'
                    ' "@lowercase")\n\ndirective @lowercase on'
                    ' FIELD_DEFINITION\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n  name: String! @lowercase\n}\n\ntype Query {\n "
                    " users: [User]\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ndirective @lowercase on OBJECT\n\nextend'
                    ' type User @key(fields: "id") @lowercase {\n  id: ID!\n '
                    " comments: [Comment]\n}\n\ntype Comment @lowercase {\n "
                    " id: ID!\n  text: String!\n}\n\ntype Query {\n  comments:"
                    " [Comment]\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url:'
            ' "https://myspecs.dev/lowercase/v1.0", import: ["@lowercase"]) {\n'
            "  query: Query\n}\n\ndirective @join__enumValue(graph:"
            " join__Graph!) repeatable on ENUM_VALUE\n\ndirective"
            " @join__graph(name: String!, url: String!) on"
            " ENUM_VALUE\n\ndirective @join__field(\n  graph: join__Graph\n "
            " requires: join__FieldSet\n  provides: join__FieldSet\n  type:"
            " String\n  external: Boolean\n  override: String\n "
            " usedOverridden: Boolean\n) repeatable on FIELD_DEFINITION |"
            " INPUT_FIELD_DEFINITION\n\ndirective @join__implements(graph:"
            " join__Graph!, interface: String!) repeatable on OBJECT |"
            " INTERFACE\n\ndirective @join__type(\n  graph: join__Graph!\n "
            " key: join__FieldSet\n  extension: Boolean! = false\n  resolvable:"
            " Boolean! = true\n  isInterfaceObject: Boolean! = false\n)"
            " repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT |"
            " SCALAR\n\ndirective @join__unionMember(graph: join__Graph!,"
            " member: String!) repeatable on UNION\n\nscalar"
            " join__FieldSet\n\ndirective @link(url: String, as: String, for:"
            " link__Purpose, import: [link__Import]) repeatable on"
            ' SCHEMA\n\nscalar link__Import\n\nenum link__Purpose {\n  """\n '
            " `SECURITY` features provide metadata necessary to securely"
            ' resolve fields.\n  """\n  SECURITY\n  """\n  `EXECUTION` features'
            ' provide metadata necessary for operation execution.\n  """\n '
            ' EXECUTION\n}\n\nenum join__Graph {\n  A @join__graph(name: "a",'
            ' url: "")\n  B @join__graph(name: "b", url: "")\n}\n\ndirective'
            " @lowercase on FIELD_DEFINITION\n\ntype User @join__type(graph: A,"
            ' key: "id") @join__type(graph: B, key: "id", extension: true) {\n '
            " id: ID!\n  name: String! @lowercase @join__field(graph: A)\n "
            " comments: [Comment] @join__field(graph: B)\n}\n\ntype Query"
            " @join__type(graph: A) @join__type(graph: B) {\n  users: [User]"
            " @join__field(graph: A)\n  comments: [Comment] @join__field(graph:"
            " B)\n}\n\ntype Comment @join__type(graph: B) {\n  id: ID!\n  text:"
            " String!\n}"
        ),
        (
            "directive @lowercase on FIELD_DEFINITION\n\ntype User {\n  id:"
            " ID!\n  name: String! @lowercase\n  comments: [Comment]\n}\n\ntype"
            " Query {\n  users: [User]\n  comments: [Comment]\n}\n\ntype"
            " Comment {\n  id: ID!\n  text: String!\n}"
        ),
    )


def test_v2_0_deeply_nested_interfaces_with_requires_fields_fragment() raises:
    # test_supergraph_errors_satisfiability_error.mojo
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\n\ninterface Product'
                    " {\n  id: ID!\n}\n\ninterface Location {\n  id:"
                    " ID!\n}\n\ntype Warsaw implements Location @key(fields:"
                    ' "id") {\n  id: ID!\n  products: [Product!]!'
                    ' @external\n}\n\ntype Lidl @key(fields: "id") {\n  id:'
                    " ID!\n  locations: [Location!] @external\n "
                    " products(location: ID): [Product]! @requires(fields:"
                    ' """\n  locations {\n    ... on Warsaw {\n      products'
                    ' {\n        id\n      }\n    }\n  }\n  """)\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  products:'
                    ' [Product]!\n}\n\ninterface Shop @key(fields: "id") {\n '
                    ' id: ID!\n}\n\ninterface Location @key(fields: "id") {\n '
                    " id: ID!\n}\n\ntype Lidl implements Shop @key(fields:"
                    ' "id") {\n  id: ID!\n  locations: [Location!]\n}\n\ntype'
                    ' Warsaw implements Location @key(fields: "id") {\n  id:'
                    " ID!\n  products: [Product!]!\n}\n\ninterface Product"
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Bread'
                    ' implements Product @key(fields: "id") {\n  id: ID!\n '
                    " shops: [Shop!]!\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {\n  query:'
            " Query\n}\n\ndirective @join__enumValue(graph: join__Graph!)"
            " repeatable on ENUM_VALUE\n\ndirective @join__graph(name: String!,"
            " url: String!) on ENUM_VALUE\n\ndirective @join__field(\n  graph:"
            " join__Graph\n  requires: join__FieldSet\n  provides:"
            " join__FieldSet\n  type: String\n  external: Boolean\n  override:"
            " String\n  usedOverridden: Boolean\n) repeatable on"
            " FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\ndirective"
            " @join__implements(graph: join__Graph!, interface: String!)"
            " repeatable on OBJECT | INTERFACE\n\ndirective @join__type(\n "
            " graph: join__Graph!\n  key: join__FieldSet\n  extension: Boolean!"
            " = false\n  resolvable: Boolean! = true\n  isInterfaceObject:"
            " Boolean! = false\n) repeatable on OBJECT | INTERFACE | UNION |"
            " ENUM | INPUT_OBJECT | SCALAR\n\ndirective"
            " @join__unionMember(graph: join__Graph!, member: String!)"
            " repeatable on UNION\n\nscalar join__FieldSet\n\ndirective"
            " @link(url: String, as: String, for: link__Purpose, import:"
            " [link__Import]) repeatable on SCHEMA\n\nscalar"
            ' link__Import\n\nenum link__Purpose {\n  """\n  `SECURITY`'
            " features provide metadata necessary to securely resolve fields.\n"
            '  """\n  SECURITY\n  """\n  `EXECUTION` features provide metadata'
            ' necessary for operation execution.\n  """\n  EXECUTION\n}\n\nenum'
            ' join__Graph {\n  A @join__graph(name: "a", url: "")\n  B'
            ' @join__graph(name: "b", url: "")\n}\n\ntype Warsaw implements'
            ' Location @join__type(graph: A, key: "id") @join__type(graph: B,'
            ' key: "id") @join__implements(graph: A, interface: "Location")'
            ' @join__implements(graph: B, interface: "Location") {\n  id: ID!\n'
            "  products: [Product!]! @join__field(graph: A, external: true)"
            " @join__field(graph: B)\n}\n\ntype Lidl implements Shop"
            ' @join__type(graph: A, key: "id") @join__type(graph: B, key: "id")'
            ' @join__implements(graph: B, interface: "Shop") {\n  id: ID!\n '
            " locations: [Location!] @join__field(graph: A, external: true)"
            " @join__field(graph: B)\n  products(location: ID): [Product]!"
            ' @join__field(graph: A, requires: "locations{...on'
            ' Warsaw{products{id}}}")\n}\n\ntype Query @join__type(graph: A)'
            " @join__type(graph: B) {\n  products: [Product]!"
            " @join__field(graph: B)\n}\n\ntype Bread implements Product"
            ' @join__type(graph: B, key: "id") @join__implements(graph: B,'
            ' interface: "Product") {\n  id: ID!\n  shops:'
            " [Shop!]!\n}\n\ninterface Product @join__type(graph: A)"
            ' @join__type(graph: B, key: "id") {\n  id: ID!\n}\n\ninterface'
            ' Location @join__type(graph: A) @join__type(graph: B, key: "id")'
            " {\n  id: ID!\n}\n\ninterface Shop @join__type(graph: B, key:"
            ' "id") {\n  id: ID!\n}'
        ),
        (
            "type Warsaw implements Location {\n  id: ID!\n  products:"
            " [Product!]!\n}\n\ntype Lidl implements Shop {\n  id: ID!\n "
            " locations: [Location!]\n  products(location: ID):"
            " [Product]!\n}\n\ntype Query {\n  products: [Product]!\n}\n\ntype"
            " Bread implements Product {\n  id: ID!\n  shops:"
            " [Shop!]!\n}\n\ninterface Product {\n  id: ID!\n}\n\ninterface"
            " Location {\n  id: ID!\n}\n\ninterface Shop {\n  id: ID!\n}"
        ),
    )


def test_v2_9_cost_cost_on_shareables_be_math_max() raises:
    # test_cost.mojo
    _check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@cost", "@shareable"])\n\nenum UserType'
                    " @cost(weight: 15) {\n  ADMIN\n  REGULAR\n}\n\ninput"
                    " UsersFilterInput {\n  limit: Int @cost(weight:"
                    ' 20)\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  userCount: Int @cost(weight: 5)"
                    " @shareable\n  user(id: ID! @cost(weight: 10)): User"
                    " @shareable\n  userType(id: ID!): UserType @shareable\n "
                    " users(filter: UsersFilterInput): [User] @shareable\n}"
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@cost", "@shareable"])\n\nenum UserType'
                    " @cost(weight: 30) {\n  ADMIN\n  REGULAR\n}\n\ninput"
                    " UsersFilterInput {\n  limit: Int @cost(weight:"
                    ' 40)\n}\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  userCount: Int @cost(weight:"
                    " 10) @shareable\n  user(id: ID! @cost(weight: 20)): User"
                    " @shareable\n  userType(id: ID!): UserType @shareable\n "
                    " users(filter: UsersFilterInput): [User] @shareable\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.5", for: EXECUTION) @link(url:'
            ' "https://specs.apollo.dev/cost/v0.1") {\n  query:'
            " Query\n}\n\ndirective @join__enumValue(graph: join__Graph!)"
            " repeatable on ENUM_VALUE\n\ndirective @join__graph(name: String!,"
            " url: String!) on ENUM_VALUE\n\ndirective @join__field(\n  graph:"
            " join__Graph\n  requires: join__FieldSet\n  provides:"
            " join__FieldSet\n  type: String\n  external: Boolean\n  override:"
            " String\n  usedOverridden: Boolean\n  overrideLabel: String\n "
            " contextArguments: [join__ContextArgument!]\n) repeatable on"
            " FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\ninput"
            " join__ContextArgument {\n  name: String!\n  type: String!\n "
            " context: String!\n  selection: join__FieldValue!\n}\n\ndirective"
            " @join__implements(graph: join__Graph!, interface: String!)"
            " repeatable on OBJECT | INTERFACE\n\ndirective @join__type(\n "
            " graph: join__Graph!\n  key: join__FieldSet\n  extension: Boolean!"
            " = false\n  resolvable: Boolean! = true\n  isInterfaceObject:"
            " Boolean! = false\n) repeatable on OBJECT | INTERFACE | UNION |"
            " ENUM | INPUT_OBJECT | SCALAR\n\ndirective"
            " @join__unionMember(graph: join__Graph!, member: String!)"
            " repeatable on UNION\n\nscalar join__FieldSet\n\nscalar"
            " join__FieldValue\n\ndirective @link(url: String, as: String, for:"
            " link__Purpose, import: [link__Import]) repeatable on"
            ' SCHEMA\n\nscalar link__Import\n\nenum link__Purpose {\n  """\n '
            " `SECURITY` features provide metadata necessary to securely"
            ' resolve fields.\n  """\n  SECURITY\n  """\n  `EXECUTION` features'
            ' provide metadata necessary for operation execution.\n  """\n '
            " EXECUTION\n}\n\ndirective @cost(weight: Int!) on"
            " ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION |"
            " INPUT_FIELD_DEFINITION | OBJECT | SCALAR\n\ndirective"
            " @listSize(\n  assumedSize: Int\n  slicingArguments: [String!]\n "
            " sizedFields: [String!]\n  requireOneSlicingArgument: Boolean ="
            " true\n) on FIELD_DEFINITION\n\nenum join__Graph {\n  BAR"
            ' @join__graph(name: "bar", url: "")\n  FOO @join__graph(name:'
            ' "foo", url: "")\n}\n\ntype User @join__type(graph: BAR, key:'
            ' "id") @join__type(graph: FOO, key: "id") {\n  id: ID!\n}\n\ntype'
            " Query @join__type(graph: BAR) @join__type(graph: FOO) {\n "
            " userCount: Int @cost(weight: 10)\n  user(id: ID! @cost(weight:"
            " 20)): User\n  userType(id: ID!): UserType\n  users(filter:"
            " UsersFilterInput): [User]\n}\n\nenum UserType @join__type(graph:"
            " BAR) @join__type(graph: FOO) @cost(weight: 30) {\n  ADMIN"
            " @join__enumValue(graph: BAR) @join__enumValue(graph: FOO)\n "
            " REGULAR @join__enumValue(graph: BAR) @join__enumValue(graph:"
            " FOO)\n}\n\ninput UsersFilterInput @join__type(graph: BAR)"
            " @join__type(graph: FOO) {\n  limit: Int @cost(weight: 40)\n}"
        ),
        (
            "type User {\n  id: ID!\n}\n\ntype Query {\n  userCount: Int\n "
            " user(id: ID!): User\n  userType(id: ID!): UserType\n "
            " users(filter: UsersFilterInput): [User]\n}\n\nenum UserType {\n "
            " ADMIN\n  REGULAR\n}\n\ninput UsersFilterInput {\n  limit: Int\n}"
        ),
    )


def test_v2_0_external_provides() raises:
    # test_composition.mojo
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@shareable"])\n\ntype Product @key(fields:'
                    ' "id") {\n  id: ID!\n  name: String! @shareable\n '
                    " inStock: Int!\n}\n\ntype Query {\n  products:"
                    " [Product]\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@provides"])\n\ntype Product'
                    ' @key(fields: "id") {\n  id: ID!\n  name: String!'
                    " @external\n}\n\ntype Query {\n  outOfStockProducts:"
                    ' [Product!]! @provides(fields: "name")\n}'
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {\n  query:'
            " Query\n}\n\ndirective @join__enumValue(graph: join__Graph!)"
            " repeatable on ENUM_VALUE\n\ndirective @join__graph(name: String!,"
            " url: String!) on ENUM_VALUE\n\ndirective @join__field(\n  graph:"
            " join__Graph\n  requires: join__FieldSet\n  provides:"
            " join__FieldSet\n  type: String\n  external: Boolean\n  override:"
            " String\n  usedOverridden: Boolean\n) repeatable on"
            " FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\ndirective"
            " @join__implements(graph: join__Graph!, interface: String!)"
            " repeatable on OBJECT | INTERFACE\n\ndirective @join__type(\n "
            " graph: join__Graph!\n  key: join__FieldSet\n  extension: Boolean!"
            " = false\n  resolvable: Boolean! = true\n  isInterfaceObject:"
            " Boolean! = false\n) repeatable on OBJECT | INTERFACE | UNION |"
            " ENUM | INPUT_OBJECT | SCALAR\n\ndirective"
            " @join__unionMember(graph: join__Graph!, member: String!)"
            " repeatable on UNION\n\nscalar join__FieldSet\n\ndirective"
            " @link(url: String, as: String, for: link__Purpose, import:"
            " [link__Import]) repeatable on SCHEMA\n\nscalar"
            ' link__Import\n\nenum link__Purpose {\n  """\n  `SECURITY`'
            " features provide metadata necessary to securely resolve fields.\n"
            '  """\n  SECURITY\n  """\n  `EXECUTION` features provide metadata'
            ' necessary for operation execution.\n  """\n  EXECUTION\n}\n\nenum'
            ' join__Graph {\n  A @join__graph(name: "a", url: "")\n  B'
            ' @join__graph(name: "b", url: "")\n}\n\ntype Product'
            ' @join__type(graph: A, key: "id") @join__type(graph: B, key: "id")'
            " {\n  id: ID!\n  name: String! @join__field(graph: A)"
            " @join__field(graph: B, external: true)\n  inStock: Int!"
            " @join__field(graph: A)\n}\n\ntype Query @join__type(graph: A)"
            " @join__type(graph: B) {\n  products: [Product]"
            " @join__field(graph: A)\n  outOfStockProducts: [Product!]!"
            ' @join__field(graph: B, provides: "name")\n}'
        ),
        (
            "type Product {\n  id: ID!\n  name: String!\n  inStock:"
            " Int!\n}\n\ntype Query {\n  products: [Product]\n "
            " outOfStockProducts: [Product!]!\n}"
        ),
    )


def test_v2_0_external_unused_on_requires_with_union_selection_set_does_not_raise_an_erro() raises:
    # test_subgraph_errors_external_unused.mojo
    _check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA {\n "
                    " status: Status! @external\n}\n\nunion UnionType ="
                    ' EntityA\n\nextend type FederatedEntity @key(fields: "id")'
                    " {\n  id: ID!\n  requiredField: UnionType @external\n "
                    ' providedField: String! @requires(fields: "requiredField {'
                    ' ...on EntityA { status } } ")\n}'
                ),
            ),
            sg(
                "entities",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@external", "@requires"])\n\nenum Status {\n '
                    " ACTIVE\n  CANCELLED\n  EXPIRED\n}\n\ntype EntityA"
                    ' @key(fields: "id") {\n  id: ID!\n  status:'
                    " Status!\n}\n\nunion UnionType = EntityA\n\ntype"
                    ' FederatedEntity @key(fields: "id") {\n  id: ID!\n '
                    " requiredField: UnionType\n}\n\ntype Query {\n  a(id: ID):"
                    " FederatedEntity\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {\n  query:'
            " Query\n}\n\ndirective @join__enumValue(graph: join__Graph!)"
            " repeatable on ENUM_VALUE\n\ndirective @join__graph(name: String!,"
            " url: String!) on ENUM_VALUE\n\ndirective @join__field(\n  graph:"
            " join__Graph\n  requires: join__FieldSet\n  provides:"
            " join__FieldSet\n  type: String\n  external: Boolean\n  override:"
            " String\n  usedOverridden: Boolean\n) repeatable on"
            " FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\ndirective"
            " @join__implements(graph: join__Graph!, interface: String!)"
            " repeatable on OBJECT | INTERFACE\n\ndirective @join__type(\n "
            " graph: join__Graph!\n  key: join__FieldSet\n  extension: Boolean!"
            " = false\n  resolvable: Boolean! = true\n  isInterfaceObject:"
            " Boolean! = false\n) repeatable on OBJECT | INTERFACE | UNION |"
            " ENUM | INPUT_OBJECT | SCALAR\n\ndirective"
            " @join__unionMember(graph: join__Graph!, member: String!)"
            " repeatable on UNION\n\nscalar join__FieldSet\n\ndirective"
            " @link(url: String, as: String, for: link__Purpose, import:"
            " [link__Import]) repeatable on SCHEMA\n\nscalar"
            ' link__Import\n\nenum link__Purpose {\n  """\n  `SECURITY`'
            " features provide metadata necessary to securely resolve fields.\n"
            '  """\n  SECURITY\n  """\n  `EXECUTION` features provide metadata'
            ' necessary for operation execution.\n  """\n  EXECUTION\n}\n\nenum'
            ' join__Graph {\n  ENTITIES @join__graph(name: "entities", url:'
            ' "")\n  USERS @join__graph(name: "users", url: "")\n}\n\ntype'
            ' EntityA @join__type(graph: ENTITIES, key: "id")'
            " @join__type(graph: USERS) {\n  id: ID! @join__field(graph:"
            " ENTITIES)\n  status: Status! @join__field(graph: ENTITIES)"
            " @join__field(graph: USERS, external: true)\n}\n\ntype"
            ' FederatedEntity @join__type(graph: ENTITIES, key: "id")'
            ' @join__type(graph: USERS, key: "id", extension: true) {\n  id:'
            " ID!\n  requiredField: UnionType @join__field(graph: ENTITIES)"
            " @join__field(graph: USERS, external: true)\n  providedField:"
            ' String! @join__field(graph: USERS, requires: "requiredField{...on'
            ' EntityA{status}}")\n}\n\ntype Query @join__type(graph: ENTITIES)'
            " @join__type(graph: USERS) {\n  a(id: ID): FederatedEntity"
            " @join__field(graph: ENTITIES)\n}\n\nunion UnionType"
            " @join__type(graph: ENTITIES) @join__type(graph: USERS)"
            ' @join__unionMember(graph: ENTITIES, member: "EntityA")'
            ' @join__unionMember(graph: USERS, member: "EntityA") ='
            " EntityA\n\nenum Status @join__type(graph: ENTITIES)"
            " @join__type(graph: USERS) {\n  ACTIVE @join__enumValue(graph:"
            " ENTITIES) @join__enumValue(graph: USERS)\n  CANCELLED"
            " @join__enumValue(graph: ENTITIES) @join__enumValue(graph:"
            " USERS)\n  EXPIRED @join__enumValue(graph: ENTITIES)"
            " @join__enumValue(graph: USERS)\n}"
        ),
        (
            "type EntityA {\n  id: ID!\n  status: Status!\n}\n\ntype"
            " FederatedEntity {\n  id: ID!\n  requiredField: UnionType\n "
            " providedField: String!\n}\n\ntype Query {\n  a(id: ID):"
            " FederatedEntity\n}\n\nunion UnionType = EntityA\n\nenum Status"
            " {\n  ACTIVE\n  CANCELLED\n  EXPIRED\n}"
        ),
    )


def test_v2_0_requires_with_interface_field() raises:
    # test_supergraph_errors_satisfiability_error.mojo
    _check(
        [
            sg(
                "a",
                (
                    "type Query {\n  userFromA(id: ID): User\n}\n\ninterface"
                    " Address {\n  id: ID!\n}\n\ntype HomeAddress implements"
                    ' Address @key(fields: "id") {\n  id: ID!\n  city:'
                    " String\n}\n\ntype WorkAddress implements Address"
                    ' @key(fields: "id") {\n  id: ID!\n  city:'
                    ' String\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n  address: Address @external\n  city:"
                    ' String @requires(fields: "address { id }")\n}'
                ),
            ),
            sg(
                "b",
                (
                    "type Query {\n  userFromB(id: ID): User\n}\n\ninterface"
                    " Address {\n  id: ID!\n}\n\ntype HomeAddress implements"
                    ' Address @key(fields: "id") {\n  id: ID!\n  city:'
                    " String\n}\n\ntype WorkAddress implements Address"
                    ' @key(fields: "id") {\n  id: ID!\n  city:'
                    ' String\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String!\n  address: Address\n  city: String"
                    ' @requires(fields: "address { id }")\n}'
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {\n  query:'
            " Query\n}\n\ndirective @join__enumValue(graph: join__Graph!)"
            " repeatable on ENUM_VALUE\n\ndirective @join__graph(name: String!,"
            " url: String!) on ENUM_VALUE\n\ndirective @join__field(\n  graph:"
            " join__Graph\n  requires: join__FieldSet\n  provides:"
            " join__FieldSet\n  type: String\n  external: Boolean\n  override:"
            " String\n  usedOverridden: Boolean\n) repeatable on"
            " FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\ndirective"
            " @join__implements(graph: join__Graph!, interface: String!)"
            " repeatable on OBJECT | INTERFACE\n\ndirective @join__type(\n "
            " graph: join__Graph!\n  key: join__FieldSet\n  extension: Boolean!"
            " = false\n  resolvable: Boolean! = true\n  isInterfaceObject:"
            " Boolean! = false\n) repeatable on OBJECT | INTERFACE | UNION |"
            " ENUM | INPUT_OBJECT | SCALAR\n\ndirective"
            " @join__unionMember(graph: join__Graph!, member: String!)"
            " repeatable on UNION\n\nscalar join__FieldSet\n\ndirective"
            " @link(url: String, as: String, for: link__Purpose, import:"
            " [link__Import]) repeatable on SCHEMA\n\nscalar"
            ' link__Import\n\nenum link__Purpose {\n  """\n  `SECURITY`'
            " features provide metadata necessary to securely resolve fields.\n"
            '  """\n  SECURITY\n  """\n  `EXECUTION` features provide metadata'
            ' necessary for operation execution.\n  """\n  EXECUTION\n}\n\nenum'
            ' join__Graph {\n  A @join__graph(name: "a", url: "")\n  B'
            ' @join__graph(name: "b", url: "")\n}\n\ntype Query'
            " @join__type(graph: A) @join__type(graph: B) {\n  userFromA(id:"
            " ID): User @join__field(graph: A)\n  userFromB(id: ID): User"
            " @join__field(graph: B)\n}\n\ntype HomeAddress implements Address"
            ' @join__type(graph: A, key: "id") @join__type(graph: B, key: "id")'
            ' @join__implements(graph: A, interface: "Address")'
            ' @join__implements(graph: B, interface: "Address") {\n  id: ID!\n '
            " city: String\n}\n\ntype WorkAddress implements Address"
            ' @join__type(graph: A, key: "id") @join__type(graph: B, key: "id")'
            ' @join__implements(graph: A, interface: "Address")'
            ' @join__implements(graph: B, interface: "Address") {\n  id: ID!\n '
            ' city: String\n}\n\ntype User @join__type(graph: A, key: "id")'
            ' @join__type(graph: B, key: "id") {\n  id: ID!\n  name: String!\n '
            " address: Address @join__field(graph: A, external: true)"
            " @join__field(graph: B)\n  city: String @join__field(graph: A,"
            ' requires: "address{id}") @join__field(graph: B, requires:'
            ' "address{id}")\n}\n\ninterface Address @join__type(graph: A)'
            " @join__type(graph: B) {\n  id: ID!\n}"
        ),
        (
            "type Query {\n  userFromA(id: ID): User\n  userFromB(id: ID):"
            " User\n}\n\ntype HomeAddress implements Address {\n  id: ID!\n "
            " city: String\n}\n\ntype WorkAddress implements Address {\n  id:"
            " ID!\n  city: String\n}\n\ntype User {\n  id: ID!\n  name:"
            " String!\n  address: Address\n  city: String\n}\n\ninterface"
            " Address {\n  id: ID!\n}"
        ),
    )


def test_v2_0_default_values_print() raises:
    # test_composition.mojo
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n\ninput LibraryFilter {\n  limit: Int ='
                    " 5\n}\n\nenum LibraryAccess {\n  PUBLIC\n "
                    " PRIVATE\n}\n\ntype Query {\n  books(filter:"
                    " LibraryFilter, access: LibraryAccess = PUBLIC):"
                    " [String!]!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n\ninput UserFilter {\n  limit: Int ='
                    " 10\n}\n\nenum UserAccess {\n  PUBLIC\n "
                    " PRIVATE\n}\n\ntype Query {\n  users(filter: UserFilter,"
                    " access: UserAccess = PRIVATE): [String!]!\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n\ninput MediaFilter {\n  limit: Int ='
                    " 15\n}\n\nenum MediaAccess {\n  PUBLIC\n "
                    " PRIVATE\n}\n\ninterface Media {\n  records(filter:"
                    " MediaFilter, access: MediaAccess = PRIVATE):"
                    " [String!]!\n}\n\ntype Movie implements Media {\n "
                    " records(filter: MediaFilter, access: MediaAccess ="
                    " PUBLIC): [String!]!\n}\n\ntype Query {\n  media(filter:"
                    " MediaFilter, access: MediaAccess = PRIVATE): [Media!]!\n}"
                ),
            ),
            sg(
                "d",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/access/v1.0", import: ["@access"])'
                    ' @composeDirective(name: "@access")\n\ndirective'
                    " @access(scope: Scope! = PUBLIC) on"
                    " FIELD_DEFINITION\n\nenum Scope {\n  PUBLIC\n "
                    " PRIVATE\n}\n\ntype Query {\n  hello: String @access\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url:'
            ' "https://myspecs.dev/access/v1.0", import: ["@access"]) {\n '
            " query: Query\n}\n\ndirective @join__enumValue(graph:"
            " join__Graph!) repeatable on ENUM_VALUE\n\ndirective"
            " @join__graph(name: String!, url: String!) on"
            " ENUM_VALUE\n\ndirective @join__field(\n  graph: join__Graph\n "
            " requires: join__FieldSet\n  provides: join__FieldSet\n  type:"
            " String\n  external: Boolean\n  override: String\n "
            " usedOverridden: Boolean\n) repeatable on FIELD_DEFINITION |"
            " INPUT_FIELD_DEFINITION\n\ndirective @join__implements(graph:"
            " join__Graph!, interface: String!) repeatable on OBJECT |"
            " INTERFACE\n\ndirective @join__type(\n  graph: join__Graph!\n "
            " key: join__FieldSet\n  extension: Boolean! = false\n  resolvable:"
            " Boolean! = true\n  isInterfaceObject: Boolean! = false\n)"
            " repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT |"
            " SCALAR\n\ndirective @join__unionMember(graph: join__Graph!,"
            " member: String!) repeatable on UNION\n\nscalar"
            " join__FieldSet\n\ndirective @link(url: String, as: String, for:"
            " link__Purpose, import: [link__Import]) repeatable on"
            ' SCHEMA\n\nscalar link__Import\n\nenum link__Purpose {\n  """\n '
            " `SECURITY` features provide metadata necessary to securely"
            ' resolve fields.\n  """\n  SECURITY\n  """\n  `EXECUTION` features'
            ' provide metadata necessary for operation execution.\n  """\n '
            ' EXECUTION\n}\n\nenum join__Graph {\n  A @join__graph(name: "a",'
            ' url: "")\n  B @join__graph(name: "b", url: "")\n  C'
            ' @join__graph(name: "c", url: "")\n  D @join__graph(name: "d",'
            ' url: "")\n}\n\ndirective @access(scope: Scope! = PUBLIC) on'
            " FIELD_DEFINITION\n\ntype Query @join__type(graph: A)"
            " @join__type(graph: B) @join__type(graph: C) @join__type(graph: D)"
            " {\n  books(filter: LibraryFilter, access: LibraryAccess ="
            " PUBLIC): [String!]! @join__field(graph: A)\n  users(filter:"
            " UserFilter, access: UserAccess = PRIVATE): [String!]!"
            " @join__field(graph: B)\n  media(filter: MediaFilter, access:"
            " MediaAccess = PRIVATE): [Media!]! @join__field(graph: C)\n "
            " hello: String @access @join__field(graph: D)\n}\n\ntype Movie"
            " implements Media @join__type(graph: C) @join__implements(graph:"
            ' C, interface: "Media") {\n  records(filter: MediaFilter, access:'
            " MediaAccess = PUBLIC): [String!]!\n}\n\ninterface Media"
            " @join__type(graph: C) {\n  records(filter: MediaFilter, access:"
            " MediaAccess = PRIVATE): [String!]!\n}\n\nenum LibraryAccess"
            " @join__type(graph: A) {\n  PUBLIC @join__enumValue(graph: A)\n "
            " PRIVATE @join__enumValue(graph: A)\n}\n\nenum UserAccess"
            " @join__type(graph: B) {\n  PUBLIC @join__enumValue(graph: B)\n "
            " PRIVATE @join__enumValue(graph: B)\n}\n\nenum MediaAccess"
            " @join__type(graph: C) {\n  PUBLIC @join__enumValue(graph: C)\n "
            " PRIVATE @join__enumValue(graph: C)\n}\n\nenum Scope"
            " @join__type(graph: D) {\n  PUBLIC @join__enumValue(graph: D)\n "
            " PRIVATE @join__enumValue(graph: D)\n}\n\ninput LibraryFilter"
            " @join__type(graph: A) {\n  limit: Int = 5\n}\n\ninput UserFilter"
            " @join__type(graph: B) {\n  limit: Int = 10\n}\n\ninput"
            " MediaFilter @join__type(graph: C) {\n  limit: Int = 15\n}"
        ),
        (
            "directive @access(scope: Scope! = PUBLIC) on"
            " FIELD_DEFINITION\n\ntype Query {\n  books(filter: LibraryFilter,"
            " access: LibraryAccess = PUBLIC): [String!]!\n  users(filter:"
            " UserFilter, access: UserAccess = PRIVATE): [String!]!\n "
            " media(filter: MediaFilter, access: MediaAccess = PRIVATE):"
            " [Media!]!\n  hello: String @access\n}\n\ntype Movie implements"
            " Media {\n  records(filter: MediaFilter, access: MediaAccess ="
            " PUBLIC): [String!]!\n}\n\ninterface Media {\n  records(filter:"
            " MediaFilter, access: MediaAccess = PRIVATE):"
            " [String!]!\n}\n\nenum LibraryAccess {\n  PUBLIC\n "
            " PRIVATE\n}\n\nenum UserAccess {\n  PUBLIC\n  PRIVATE\n}\n\nenum"
            " MediaAccess {\n  PUBLIC\n  PRIVATE\n}\n\nenum Scope {\n  PUBLIC\n"
            "  PRIVATE\n}\n\ninput LibraryFilter {\n  limit: Int ="
            " 5\n}\n\ninput UserFilter {\n  limit: Int = 10\n}\n\ninput"
            " MediaFilter {\n  limit: Int = 15\n}"
        ),
    )


def test_v2_0_deprecated_on_input_object_types() raises:
    # test_composition.mojo
    _check(
        [
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n\ninput UserInput {\n  name: String'
                    ' @deprecated(reason: "b")\n  email: String'
                    ' @deprecated(reason: "b")\n}\n\ntype Library @shareable'
                    " {\n  book(title: String, section: String):"
                    " String\n}\n\ntype Query {\n  library: Library\n}"
                ),
            ),
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@shareable"])\n\ninput UserInput {\n  name: String\n '
                    ' email: String @deprecated(reason: "a")\n  age: Int'
                    ' @deprecated(reason: "a")\n}\n\ntype Library @shareable'
                    " {\n  book(title: String, author: String): String\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {\n  query:'
            " Query\n}\n\ndirective @join__enumValue(graph: join__Graph!)"
            " repeatable on ENUM_VALUE\n\ndirective @join__graph(name: String!,"
            " url: String!) on ENUM_VALUE\n\ndirective @join__field(\n  graph:"
            " join__Graph\n  requires: join__FieldSet\n  provides:"
            " join__FieldSet\n  type: String\n  external: Boolean\n  override:"
            " String\n  usedOverridden: Boolean\n) repeatable on"
            " FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\ndirective"
            " @join__implements(graph: join__Graph!, interface: String!)"
            " repeatable on OBJECT | INTERFACE\n\ndirective @join__type(\n "
            " graph: join__Graph!\n  key: join__FieldSet\n  extension: Boolean!"
            " = false\n  resolvable: Boolean! = true\n  isInterfaceObject:"
            " Boolean! = false\n) repeatable on OBJECT | INTERFACE | UNION |"
            " ENUM | INPUT_OBJECT | SCALAR\n\ndirective"
            " @join__unionMember(graph: join__Graph!, member: String!)"
            " repeatable on UNION\n\nscalar join__FieldSet\n\ndirective"
            " @link(url: String, as: String, for: link__Purpose, import:"
            " [link__Import]) repeatable on SCHEMA\n\nscalar"
            ' link__Import\n\nenum link__Purpose {\n  """\n  `SECURITY`'
            " features provide metadata necessary to securely resolve fields.\n"
            '  """\n  SECURITY\n  """\n  `EXECUTION` features provide metadata'
            ' necessary for operation execution.\n  """\n  EXECUTION\n}\n\nenum'
            ' join__Graph {\n  A @join__graph(name: "a", url: "")\n  B'
            ' @join__graph(name: "b", url: "")\n}\n\ntype Library'
            " @join__type(graph: A) @join__type(graph: B) {\n  book(title:"
            " String): String\n}\n\ntype Query @join__type(graph: A)"
            " @join__type(graph: B) {\n  library: Library @join__field(graph:"
            " B)\n}\n\ninput UserInput @join__type(graph: A) @join__type(graph:"
            ' B) {\n  name: String @deprecated(reason: "b")\n  email: String'
            ' @deprecated(reason: "a")\n}'
        ),
        (
            "type Library {\n  book(title: String): String\n}\n\ntype Query {\n"
            "  library: Library\n}\n\ninput UserInput {\n  name: String"
            ' @deprecated(reason: "b")\n  email: String @deprecated(reason:'
            ' "a")\n}'
        ),
    )


def test_v2_9_listsize_listsize_on_interface_field() raises:
    # test_cost.mojo
    _check(
        [
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@listSize", "@shareable"])\n\ninterface Node'
                    " {\n  id: ID!\n  nodes(limit: Int!): [Node]"
                    ' @listSize(slicingArguments: ["limit"], sizedFields:'
                    ' ["nodes"], assumedSize: 21)\n}\n\ntype User implements'
                    ' Node @key(fields: "id") {\n  id: ID!\n  nodes(limit:'
                    ' Int!): [Node] @listSize(slicingArguments: ["limit"],'
                    ' sizedFields: ["nodes"], assumedSize: 11)'
                    " @shareable\n}\n\ntype Query {\n  node(id: ID): Node"
                    " @shareable\n}"
                ),
            ),
            sg(
                "baz",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@listSize", "@shareable"])\n\ninterface Node'
                    " {\n  id: ID!\n  nodes(limit: Int!): [Node]"
                    ' @listSize(slicingArguments: ["limit"], sizedFields:'
                    ' ["nodes"], assumedSize: 20)\n}\n\ntype User implements'
                    ' Node @key(fields: "id") {\n  id: ID!\n  nodes(limit:'
                    ' Int!): [Node] @listSize(slicingArguments: ["limit"],'
                    ' sizedFields: ["nodes"], assumedSize: 10)'
                    " @shareable\n}\n\ntype Query {\n  node(id: ID): Node"
                    " @shareable\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.5", for: EXECUTION) @link(url:'
            ' "https://specs.apollo.dev/cost/v0.1", import: ["@listSize"]) {\n '
            " query: Query\n}\n\ndirective @join__enumValue(graph:"
            " join__Graph!) repeatable on ENUM_VALUE\n\ndirective"
            " @join__graph(name: String!, url: String!) on"
            " ENUM_VALUE\n\ndirective @join__field(\n  graph: join__Graph\n "
            " requires: join__FieldSet\n  provides: join__FieldSet\n  type:"
            " String\n  external: Boolean\n  override: String\n "
            " usedOverridden: Boolean\n  overrideLabel: String\n "
            " contextArguments: [join__ContextArgument!]\n) repeatable on"
            " FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\ninput"
            " join__ContextArgument {\n  name: String!\n  type: String!\n "
            " context: String!\n  selection: join__FieldValue!\n}\n\ndirective"
            " @join__implements(graph: join__Graph!, interface: String!)"
            " repeatable on OBJECT | INTERFACE\n\ndirective @join__type(\n "
            " graph: join__Graph!\n  key: join__FieldSet\n  extension: Boolean!"
            " = false\n  resolvable: Boolean! = true\n  isInterfaceObject:"
            " Boolean! = false\n) repeatable on OBJECT | INTERFACE | UNION |"
            " ENUM | INPUT_OBJECT | SCALAR\n\ndirective"
            " @join__unionMember(graph: join__Graph!, member: String!)"
            " repeatable on UNION\n\nscalar join__FieldSet\n\nscalar"
            " join__FieldValue\n\ndirective @link(url: String, as: String, for:"
            " link__Purpose, import: [link__Import]) repeatable on"
            ' SCHEMA\n\nscalar link__Import\n\nenum link__Purpose {\n  """\n '
            " `SECURITY` features provide metadata necessary to securely"
            ' resolve fields.\n  """\n  SECURITY\n  """\n  `EXECUTION` features'
            ' provide metadata necessary for operation execution.\n  """\n '
            " EXECUTION\n}\n\ndirective @cost(weight: Int!) on"
            " ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION |"
            " INPUT_FIELD_DEFINITION | OBJECT | SCALAR\n\ndirective"
            " @listSize(\n  assumedSize: Int\n  slicingArguments: [String!]\n "
            " sizedFields: [String!]\n  requireOneSlicingArgument: Boolean ="
            " true\n) on FIELD_DEFINITION\n\nenum join__Graph {\n  BAR"
            ' @join__graph(name: "bar", url: "")\n  BAZ @join__graph(name:'
            ' "baz", url: "")\n}\n\ntype User implements Node'
            ' @join__type(graph: BAR, key: "id") @join__type(graph: BAZ, key:'
            ' "id") @join__implements(graph: BAR, interface: "Node")'
            ' @join__implements(graph: BAZ, interface: "Node") {\n  id: ID!\n '
            " nodes(limit: Int!): [Node] @listSize(assumedSize: 11,"
            ' slicingArguments: ["limit"], sizedFields: ["nodes"])\n}\n\ntype'
            " Query @join__type(graph: BAR) @join__type(graph: BAZ) {\n "
            " node(id: ID): Node\n}\n\ninterface Node @join__type(graph: BAR)"
            " @join__type(graph: BAZ) {\n  id: ID!\n  nodes(limit: Int!):"
            " [Node] @listSize(\n    requireOneSlicingArgument: true\n   "
            ' assumedSize: 21\n    slicingArguments: ["limit"]\n   '
            ' sizedFields: ["nodes"]\n  )\n}'
        ),
        (
            "type User implements Node {\n  id: ID!\n  nodes(limit: Int!):"
            " [Node]\n}\n\ntype Query {\n  node(id: ID): Node\n}\n\ninterface"
            " Node {\n  id: ID!\n  nodes(limit: Int!): [Node]\n}"
        ),
    )


def test_authenticated_allowed_on_interfaceobject_field_that_belongs_to_interface() raises:
    # test_auth_authenticated.mojo
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key", "@interfaceObject"])\n\ntype'
                    ' User @key(fields: "id") @interfaceObject {\n  id: ID!'
                    " @authenticated\n  name: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key"])\n\ninterface User'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Authenticated'
                    ' implements User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  user(id: ID!): User\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@authenticated", "@key", "@interfaceObject"])\n\ntype'
                    ' User @key(fields: "id") @interfaceObject {\n  id: ID!'
                    " @authenticated\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.5", for: EXECUTION) @link(url:'
            ' "https://specs.apollo.dev/authenticated/v0.1", for: SECURITY) {\n'
            "  query: Query\n}\n\ndirective @join__enumValue(graph:"
            " join__Graph!) repeatable on ENUM_VALUE\n\ndirective"
            " @join__graph(name: String!, url: String!) on"
            " ENUM_VALUE\n\ndirective @join__field(\n  graph: join__Graph\n "
            " requires: join__FieldSet\n  provides: join__FieldSet\n  type:"
            " String\n  external: Boolean\n  override: String\n "
            " usedOverridden: Boolean\n  overrideLabel: String\n "
            " contextArguments: [join__ContextArgument!]\n) repeatable on"
            " FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\ninput"
            " join__ContextArgument {\n  name: String!\n  type: String!\n "
            " context: String!\n  selection: join__FieldValue!\n}\n\ndirective"
            " @join__implements(graph: join__Graph!, interface: String!)"
            " repeatable on OBJECT | INTERFACE\n\ndirective @join__type(\n "
            " graph: join__Graph!\n  key: join__FieldSet\n  extension: Boolean!"
            " = false\n  resolvable: Boolean! = true\n  isInterfaceObject:"
            " Boolean! = false\n) repeatable on OBJECT | INTERFACE | UNION |"
            " ENUM | INPUT_OBJECT | SCALAR\n\ndirective"
            " @join__unionMember(graph: join__Graph!, member: String!)"
            " repeatable on UNION\n\nscalar join__FieldSet\n\nscalar"
            " join__FieldValue\n\ndirective @link(url: String, as: String, for:"
            " link__Purpose, import: [link__Import]) repeatable on"
            ' SCHEMA\n\nscalar link__Import\n\nenum link__Purpose {\n  """\n '
            " `SECURITY` features provide metadata necessary to securely"
            ' resolve fields.\n  """\n  SECURITY\n  """\n  `EXECUTION` features'
            ' provide metadata necessary for operation execution.\n  """\n '
            " EXECUTION\n}\n\ndirective @authenticated on FIELD_DEFINITION |"
            " OBJECT | INTERFACE | SCALAR | ENUM\n\nenum join__Graph {\n  A"
            ' @join__graph(name: "a", url: "")\n  B @join__graph(name: "b",'
            ' url: "")\n  C @join__graph(name: "c", url: "")\n}\n\ntype'
            ' Authenticated implements User @join__type(graph: B, key: "id")'
            ' @join__implements(graph: B, interface: "User") {\n  id: ID!'
            " @authenticated\n  name: String @join__field\n}\n\ntype Query"
            " @join__type(graph: A) @join__type(graph: B) @join__type(graph: C)"
            " {\n  user(id: ID!): User @join__field(graph: B)\n}\n\ninterface"
            ' User @join__type(graph: A, key: "id", isInterfaceObject: true)'
            ' @join__type(graph: B, key: "id") @join__type(graph: C, key: "id",'
            " isInterfaceObject: true) {\n  id: ID! @authenticated\n  name:"
            " String @join__field(graph: A)\n}"
        ),
        (
            "type Authenticated implements User {\n  id: ID!\n  name:"
            " String\n}\n\ntype Query {\n  user(id: ID!): User\n}\n\ninterface"
            " User {\n  id: ID!\n  name: String\n}"
        ),
    )


def test_v2_0_tag() raises:
    # test_composition.mojo
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@tag"])\n\ntype Query {\n  customer(id: String!):'
                    ' Customer @tag(name: "team-customers")\n  employee(id:'
                    ' String! @tag(name: "team-admin")): Employee @tag(name:'
                    ' "team-admin")\n  employees(filter: EmployeesFilter!):'
                    ' [Employee!] @tag(name: "team-admin")\n}\n\nscalar'
                    ' DateTime @tag(name: "team-admin")\n\ninterface User'
                    ' @tag(name: "team-accounts") {\n  id: String!\n '
                    ' name(lowercase: Boolean @tag(name: "team-accounts")):'
                    " String!\n}\n\ntype Customer implements User @tag(name:"
                    ' "team-customers") {\n  id: String!\n  name(lowercase:'
                    ' Boolean @tag(name: "team-accounts")): String!\n}\n\ntype'
                    ' Employee implements User @tag(name: "team-admin") {\n '
                    " id: String!\n  name(lowercase: Boolean @tag(name:"
                    ' "team-accounts")): String!\n  ssn: String!\n  createdAt:'
                    " DateTime!\n}\n\ninput EmployeesFilter {\n  id: String"
                    ' @tag(name: "team-admin")\n  name: String\n}'
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url:'
            ' "https://specs.apollo.dev/tag/v0.3") {\n  query:'
            " Query\n}\n\ndirective @join__enumValue(graph: join__Graph!)"
            " repeatable on ENUM_VALUE\n\ndirective @join__graph(name: String!,"
            " url: String!) on ENUM_VALUE\n\ndirective @join__field(\n  graph:"
            " join__Graph\n  requires: join__FieldSet\n  provides:"
            " join__FieldSet\n  type: String\n  external: Boolean\n  override:"
            " String\n  usedOverridden: Boolean\n) repeatable on"
            " FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\ndirective"
            " @join__implements(graph: join__Graph!, interface: String!)"
            " repeatable on OBJECT | INTERFACE\n\ndirective @join__type(\n "
            " graph: join__Graph!\n  key: join__FieldSet\n  extension: Boolean!"
            " = false\n  resolvable: Boolean! = true\n  isInterfaceObject:"
            " Boolean! = false\n) repeatable on OBJECT | INTERFACE | UNION |"
            " ENUM | INPUT_OBJECT | SCALAR\n\ndirective"
            " @join__unionMember(graph: join__Graph!, member: String!)"
            " repeatable on UNION\n\nscalar join__FieldSet\n\ndirective"
            " @link(url: String, as: String, for: link__Purpose, import:"
            " [link__Import]) repeatable on SCHEMA\n\nscalar"
            ' link__Import\n\nenum link__Purpose {\n  """\n  `SECURITY`'
            " features provide metadata necessary to securely resolve fields.\n"
            '  """\n  SECURITY\n  """\n  `EXECUTION` features provide metadata'
            ' necessary for operation execution.\n  """\n '
            " EXECUTION\n}\n\ndirective @tag(name: String!) repeatable on"
            " FIELD_DEFINITION | OBJECT | INTERFACE | UNION |"
            " ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT |"
            " INPUT_FIELD_DEFINITION | SCHEMA\n\nenum join__Graph {\n  A"
            ' @join__graph(name: "a", url: "")\n}\n\nscalar DateTime'
            ' @join__type(graph: A) @tag(name: "team-admin")\n\ntype Query'
            " @join__type(graph: A) {\n  customer(id: String!): Customer"
            ' @tag(name: "team-customers")\n  employee(id: String! @tag(name:'
            ' "team-admin")): Employee @tag(name: "team-admin")\n '
            " employees(filter: EmployeesFilter!): [Employee!] @tag(name:"
            ' "team-admin")\n}\n\ntype Customer implements User'
            " @join__type(graph: A) @join__implements(graph: A, interface:"
            ' "User") @tag(name: "team-customers") {\n  id: String!\n '
            ' name(lowercase: Boolean @tag(name: "team-accounts")):'
            " String!\n}\n\ntype Employee implements User @join__type(graph: A)"
            ' @join__implements(graph: A, interface: "User") @tag(name:'
            ' "team-admin") {\n  id: String!\n  name(lowercase: Boolean'
            ' @tag(name: "team-accounts")): String!\n  ssn: String!\n '
            " createdAt: DateTime!\n}\n\ninterface User @join__type(graph: A)"
            ' @tag(name: "team-accounts") {\n  id: String!\n  name(lowercase:'
            ' Boolean @tag(name: "team-accounts")): String!\n}\n\ninput'
            " EmployeesFilter @join__type(graph: A) {\n  id: String @tag(name:"
            ' "team-admin")\n  name: String\n}'
        ),
        (
            "scalar DateTime\n\ntype Query {\n  customer(id: String!):"
            " Customer\n  employee(id: String!): Employee\n  employees(filter:"
            " EmployeesFilter!): [Employee!]\n}\n\ntype Customer implements"
            " User {\n  id: String!\n  name(lowercase: Boolean):"
            " String!\n}\n\ntype Employee implements User {\n  id: String!\n "
            " name(lowercase: Boolean): String!\n  ssn: String!\n  createdAt:"
            " DateTime!\n}\n\ninterface User {\n  id: String!\n "
            " name(lowercase: Boolean): String!\n}\n\ninput EmployeesFilter {\n"
            "  id: String\n  name: String\n}"
        ),
    )


def test_v2_1_preserve_directive_on_directive_argument_if_included_in_composedirective() raises:
    # test_composition.mojo
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/whatever/v1.0", import:'
                    ' ["@whatever", "@whenever"]) @composeDirective(name:'
                    ' "@whatever") @composeDirective(name:'
                    ' "@whenever")\n\ndirective @whatever(when: String'
                    " @whenever) on FIELD_DEFINITION\n\ndirective @whenever on"
                    " ARGUMENT_DEFINITION\n\ntype User {\n  id: ID!"
                    ' @whatever(when: "now")\n}\n\ntype Query {\n  users:'
                    " [User]\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url:'
            ' "https://myspecs.dev/whatever/v1.0", import: ["@whatever",'
            ' "@whenever"]) {\n  query: Query\n}\n\ndirective'
            " @join__enumValue(graph: join__Graph!) repeatable on"
            " ENUM_VALUE\n\ndirective @join__graph(name: String!, url: String!)"
            " on ENUM_VALUE\n\ndirective @join__field(\n  graph: join__Graph\n "
            " requires: join__FieldSet\n  provides: join__FieldSet\n  type:"
            " String\n  external: Boolean\n  override: String\n "
            " usedOverridden: Boolean\n) repeatable on FIELD_DEFINITION |"
            " INPUT_FIELD_DEFINITION\n\ndirective @join__implements(graph:"
            " join__Graph!, interface: String!) repeatable on OBJECT |"
            " INTERFACE\n\ndirective @join__type(\n  graph: join__Graph!\n "
            " key: join__FieldSet\n  extension: Boolean! = false\n  resolvable:"
            " Boolean! = true\n  isInterfaceObject: Boolean! = false\n)"
            " repeatable on OBJECT | INTERFACE | UNION | ENUM | INPUT_OBJECT |"
            " SCALAR\n\ndirective @join__unionMember(graph: join__Graph!,"
            " member: String!) repeatable on UNION\n\nscalar"
            " join__FieldSet\n\ndirective @link(url: String, as: String, for:"
            " link__Purpose, import: [link__Import]) repeatable on"
            ' SCHEMA\n\nscalar link__Import\n\nenum link__Purpose {\n  """\n '
            " `SECURITY` features provide metadata necessary to securely"
            ' resolve fields.\n  """\n  SECURITY\n  """\n  `EXECUTION` features'
            ' provide metadata necessary for operation execution.\n  """\n '
            ' EXECUTION\n}\n\nenum join__Graph {\n  A @join__graph(name: "a",'
            ' url: "")\n}\n\ndirective @whatever(when: String @whenever) on'
            " FIELD_DEFINITION\n\ndirective @whenever on"
            " ARGUMENT_DEFINITION\n\ntype User @join__type(graph: A) {\n  id:"
            ' ID! @whatever(when: "now")\n}\n\ntype Query @join__type(graph: A)'
            " {\n  users: [User]\n}"
        ),
        (
            "directive @whatever(when: String @whenever) on"
            " FIELD_DEFINITION\n\ndirective @whenever on"
            " ARGUMENT_DEFINITION\n\ntype User {\n  id: ID! @whatever(when:"
            ' "now")\n}\n\ntype Query {\n  users: [User]\n}'
        ),
    )


def test_v2_1_valid_composed_directive_gets_an_empty_object_instead_of_name() raises:
    # test_subgraph_to_categorize.mojo
    _check(
        [
            sg(
                "users",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0") @link(url:'
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/hello/v1.0", import: ["@hello",'
                    ' "Person"]) @composeDirective(name: "@hello")\n\ndirective'
                    " @hello(person: Person) on FIELD_DEFINITION\n\ninput"
                    " Person {\n  name: String!\n}\n\ntype Query {\n  words:"
                    " [String!]! @hello(person: {})\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url:'
            ' "https://myspecs.dev/hello/v1.0", import: ["@hello"]) {\n  query:'
            " Query\n}\n\ndirective @join__enumValue(graph: join__Graph!)"
            " repeatable on ENUM_VALUE\n\ndirective @join__graph(name: String!,"
            " url: String!) on ENUM_VALUE\n\ndirective @join__field(\n  graph:"
            " join__Graph\n  requires: join__FieldSet\n  provides:"
            " join__FieldSet\n  type: String\n  external: Boolean\n  override:"
            " String\n  usedOverridden: Boolean\n) repeatable on"
            " FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\ndirective"
            " @join__implements(graph: join__Graph!, interface: String!)"
            " repeatable on OBJECT | INTERFACE\n\ndirective @join__type(\n "
            " graph: join__Graph!\n  key: join__FieldSet\n  extension: Boolean!"
            " = false\n  resolvable: Boolean! = true\n  isInterfaceObject:"
            " Boolean! = false\n) repeatable on OBJECT | INTERFACE | UNION |"
            " ENUM | INPUT_OBJECT | SCALAR\n\ndirective"
            " @join__unionMember(graph: join__Graph!, member: String!)"
            " repeatable on UNION\n\nscalar join__FieldSet\n\ndirective"
            " @link(url: String, as: String, for: link__Purpose, import:"
            " [link__Import]) repeatable on SCHEMA\n\nscalar"
            ' link__Import\n\nenum link__Purpose {\n  """\n  `SECURITY`'
            " features provide metadata necessary to securely resolve fields.\n"
            '  """\n  SECURITY\n  """\n  `EXECUTION` features provide metadata'
            ' necessary for operation execution.\n  """\n  EXECUTION\n}\n\nenum'
            ' join__Graph {\n  USERS @join__graph(name: "users", url:'
            ' "")\n}\n\ndirective @hello(person: Person) on'
            " FIELD_DEFINITION\n\ntype Query @join__type(graph: USERS) {\n "
            " words: [String!]! @hello(person: {})\n}\n\ninput Person"
            " @join__type(graph: USERS) {\n  name: String!\n}"
        ),
        (
            "directive @hello(person: Person) on FIELD_DEFINITION\n\ntype Query"
            " {\n  words: [String!]! @hello(person: {})\n}\n\ninput Person {\n "
            " name: String!\n}"
        ),
    )


def test_v2_0_executable_directive_only_contains_locations_shared_between_all_subgraphs() raises:
    # test_supergraph_base.mojo
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD\n\ntype Query'
                    " {\n  a: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ndirective @a(n: Int) on FIELD |'
                    " FRAGMENT_SPREAD\n\ntype Query {\n  b: Int\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {\n  query:'
            " Query\n}\n\ndirective @join__enumValue(graph: join__Graph!)"
            " repeatable on ENUM_VALUE\n\ndirective @join__graph(name: String!,"
            " url: String!) on ENUM_VALUE\n\ndirective @join__field(\n  graph:"
            " join__Graph\n  requires: join__FieldSet\n  provides:"
            " join__FieldSet\n  type: String\n  external: Boolean\n  override:"
            " String\n  usedOverridden: Boolean\n) repeatable on"
            " FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\ndirective"
            " @join__implements(graph: join__Graph!, interface: String!)"
            " repeatable on OBJECT | INTERFACE\n\ndirective @join__type(\n "
            " graph: join__Graph!\n  key: join__FieldSet\n  extension: Boolean!"
            " = false\n  resolvable: Boolean! = true\n  isInterfaceObject:"
            " Boolean! = false\n) repeatable on OBJECT | INTERFACE | UNION |"
            " ENUM | INPUT_OBJECT | SCALAR\n\ndirective"
            " @join__unionMember(graph: join__Graph!, member: String!)"
            " repeatable on UNION\n\nscalar join__FieldSet\n\ndirective"
            " @link(url: String, as: String, for: link__Purpose, import:"
            " [link__Import]) repeatable on SCHEMA\n\nscalar"
            ' link__Import\n\nenum link__Purpose {\n  """\n  `SECURITY`'
            " features provide metadata necessary to securely resolve fields.\n"
            '  """\n  SECURITY\n  """\n  `EXECUTION` features provide metadata'
            ' necessary for operation execution.\n  """\n  EXECUTION\n}\n\nenum'
            ' join__Graph {\n  A @join__graph(name: "a", url: "")\n  B'
            ' @join__graph(name: "b", url: "")\n}\n\ndirective @a(n: Int) on'
            " FIELD\n\ntype Query @join__type(graph: A) @join__type(graph: B)"
            " {\n  a: Int @join__field(graph: A)\n  b: Int @join__field(graph:"
            " B)\n}"
        ),
        "directive @a(n: Int) on FIELD\n\ntype Query {\n  a: Int\n  b: Int\n}",
    )


def test_external_object_type_field_implementing_interface_field() raises:
    # test_composition.mojo
    _check(
        [
            sg(
                "github_core",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  checks:'
                    " QueuedCheckRunInfo\n}\n\ninterface CheckRunInfo {\n  id:"
                    " ID!\n  status: String!\n}\n\ntype QueuedCheckRunInfo"
                    ' implements CheckRunInfo @key(fields: "id") {\n  id: ID!\n'
                    "  status: String!\n  commitOid: String!\n}"
                ),
            ),
            sg(
                "github_action",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\n\nextend type'
                    " QueuedCheckRunInfo implements CheckRunInfo @key(fields:"
                    ' "id") {\n  id: ID! @external\n  status: String!'
                    " @external\n  commitOid: String! @external\n "
                    " workflowRunId: ID! @requires(fields:"
                    ' "commitOid")\n}\n\ninterface CheckRunInfo {\n  id: ID!\n '
                    " status: String!\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {\n  query:'
            " Query\n}\n\ndirective @join__enumValue(graph: join__Graph!)"
            " repeatable on ENUM_VALUE\n\ndirective @join__graph(name: String!,"
            " url: String!) on ENUM_VALUE\n\ndirective @join__field(\n  graph:"
            " join__Graph\n  requires: join__FieldSet\n  provides:"
            " join__FieldSet\n  type: String\n  external: Boolean\n  override:"
            " String\n  usedOverridden: Boolean\n) repeatable on"
            " FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\ndirective"
            " @join__implements(graph: join__Graph!, interface: String!)"
            " repeatable on OBJECT | INTERFACE\n\ndirective @join__type(\n "
            " graph: join__Graph!\n  key: join__FieldSet\n  extension: Boolean!"
            " = false\n  resolvable: Boolean! = true\n  isInterfaceObject:"
            " Boolean! = false\n) repeatable on OBJECT | INTERFACE | UNION |"
            " ENUM | INPUT_OBJECT | SCALAR\n\ndirective"
            " @join__unionMember(graph: join__Graph!, member: String!)"
            " repeatable on UNION\n\nscalar join__FieldSet\n\ndirective"
            " @link(url: String, as: String, for: link__Purpose, import:"
            " [link__Import]) repeatable on SCHEMA\n\nscalar"
            ' link__Import\n\nenum link__Purpose {\n  """\n  `SECURITY`'
            " features provide metadata necessary to securely resolve fields.\n"
            '  """\n  SECURITY\n  """\n  `EXECUTION` features provide metadata'
            ' necessary for operation execution.\n  """\n  EXECUTION\n}\n\nenum'
            " join__Graph {\n  GITHUB_ACTION @join__graph(name:"
            ' "github_action", url: "")\n  GITHUB_CORE @join__graph(name:'
            ' "github_core", url: "")\n}\n\ntype QueuedCheckRunInfo implements'
            ' CheckRunInfo @join__type(graph: GITHUB_ACTION, key: "id",'
            ' extension: true) @join__type(graph: GITHUB_CORE, key: "id")'
            " @join__implements(graph: GITHUB_ACTION, interface:"
            ' "CheckRunInfo") @join__implements(graph: GITHUB_CORE, interface:'
            ' "CheckRunInfo") {\n  id: ID!\n  status: String!'
            " @join__field(graph: GITHUB_ACTION, external: true)"
            " @join__field(graph: GITHUB_CORE)\n  commitOid: String!"
            " @join__field(graph: GITHUB_ACTION, external: true)"
            " @join__field(graph: GITHUB_CORE)\n  workflowRunId: ID!"
            " @join__field(graph: GITHUB_ACTION, requires:"
            ' "commitOid")\n}\n\ntype Query @join__type(graph: GITHUB_ACTION)'
            " @join__type(graph: GITHUB_CORE) {\n  checks: QueuedCheckRunInfo"
            " @join__field(graph: GITHUB_CORE)\n}\n\ninterface CheckRunInfo"
            " @join__type(graph: GITHUB_ACTION) @join__type(graph: GITHUB_CORE)"
            " {\n  id: ID!\n  status: String!\n}"
        ),
        (
            "type QueuedCheckRunInfo implements CheckRunInfo {\n  id: ID!\n "
            " status: String!\n  commitOid: String!\n  workflowRunId:"
            " ID!\n}\n\ntype Query {\n  checks:"
            " QueuedCheckRunInfo\n}\n\ninterface CheckRunInfo {\n  id: ID!\n "
            " status: String!\n}"
        ),
    )


def test_v2_0_invalid_field_sharing_nested_key_fields() raises:
    # test_supergraph_errors_invalid_field_sharing.mojo
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype A @key(fields: "id", resolvable: true)'
                    ' @key(fields: "pId", resolvable: false) @key(fields:'
                    ' "compositeId { one two }", resolvable: false)'
                    ' @key(fields: "id compositeId { two three }", resolvable:'
                    " false) {\n  id: ID!\n  pId: ID!\n  compositeId:"
                    " CompositeID!\n  name: String!\n}\n\ntype CompositeID {\n "
                    " one: ID!\n  two: ID!\n  three: ID!\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@requires", "@external"])\n\ntype Query {\n  b:'
                    ' B\n}\n\ntype B @key(fields: "id") {\n  id: ID!\n  a:'
                    ' [A!]!\n}\n\ntype A @key(fields: "compositeId { one two'
                    ' }", resolvable: false) @key(fields: "id compositeId { two'
                    ' three }", resolvable: true) @key(fields: "pId",'
                    ' resolvable: false) @key(fields: "id", resolvable: false)'
                    " {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n "
                    " name: String! @external\n  nameInB: String!"
                    ' @requires(fields: "name")\n}\n\ntype CompositeID {\n '
                    " one: ID!\n  two: ID!\n  three: ID!\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {\n  query:'
            " Query\n}\n\ndirective @join__enumValue(graph: join__Graph!)"
            " repeatable on ENUM_VALUE\n\ndirective @join__graph(name: String!,"
            " url: String!) on ENUM_VALUE\n\ndirective @join__field(\n  graph:"
            " join__Graph\n  requires: join__FieldSet\n  provides:"
            " join__FieldSet\n  type: String\n  external: Boolean\n  override:"
            " String\n  usedOverridden: Boolean\n) repeatable on"
            " FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\ndirective"
            " @join__implements(graph: join__Graph!, interface: String!)"
            " repeatable on OBJECT | INTERFACE\n\ndirective @join__type(\n "
            " graph: join__Graph!\n  key: join__FieldSet\n  extension: Boolean!"
            " = false\n  resolvable: Boolean! = true\n  isInterfaceObject:"
            " Boolean! = false\n) repeatable on OBJECT | INTERFACE | UNION |"
            " ENUM | INPUT_OBJECT | SCALAR\n\ndirective"
            " @join__unionMember(graph: join__Graph!, member: String!)"
            " repeatable on UNION\n\nscalar join__FieldSet\n\ndirective"
            " @link(url: String, as: String, for: link__Purpose, import:"
            " [link__Import]) repeatable on SCHEMA\n\nscalar"
            ' link__Import\n\nenum link__Purpose {\n  """\n  `SECURITY`'
            " features provide metadata necessary to securely resolve fields.\n"
            '  """\n  SECURITY\n  """\n  `EXECUTION` features provide metadata'
            ' necessary for operation execution.\n  """\n  EXECUTION\n}\n\nenum'
            ' join__Graph {\n  A @join__graph(name: "a", url: "")\n  B'
            ' @join__graph(name: "b", url: "")\n}\n\ntype A @join__type(graph:'
            ' A, key: "id") @join__type(graph: A, key: "pId", resolvable:'
            ' false) @join__type(graph: A, key: "compositeId { one two }",'
            ' resolvable: false) @join__type(graph: A, key: "id compositeId {'
            ' two three }", resolvable: false) @join__type(graph: B, key:'
            ' "compositeId { one two }", resolvable: false) @join__type(graph:'
            ' B, key: "id compositeId { two three }") @join__type(graph: B,'
            ' key: "pId", resolvable: false) @join__type(graph: B, key: "id",'
            " resolvable: false) {\n  id: ID!\n  pId: ID!\n  compositeId:"
            " CompositeID!\n  name: String! @join__field(graph: A)"
            " @join__field(graph: B, external: true)\n  nameInB: String!"
            ' @join__field(graph: B, requires: "name")\n}\n\ntype CompositeID'
            " @join__type(graph: A) @join__type(graph: B) {\n  one: ID!\n  two:"
            " ID!\n  three: ID!\n}\n\ntype Query @join__type(graph: A)"
            " @join__type(graph: B) {\n  b: B @join__field(graph: B)\n}\n\ntype"
            ' B @join__type(graph: B, key: "id") {\n  id: ID!\n  a: [A!]!\n}'
        ),
        (
            "type A {\n  id: ID!\n  pId: ID!\n  compositeId: CompositeID!\n "
            " name: String!\n  nameInB: String!\n}\n\ntype CompositeID {\n "
            " one: ID!\n  two: ID!\n  three: ID!\n}\n\ntype Query {\n  b:"
            " B\n}\n\ntype B {\n  id: ID!\n  a: [A!]!\n}"
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
