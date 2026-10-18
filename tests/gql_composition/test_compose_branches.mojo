# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Composition of subgraphs that reach the less common printer paths.

The cases follow the style of upstream `__tests__/composition.spec.ts` and
`__tests__/supergraph/*.spec.ts` of Hive Federation Composition v0.27.0:
feature links, executable directives, `@cost` and `@listSize` merges,
argument directives from more than one subgraph, `@requires` and
`@provides` field sets, and `@interfaceObject` fields. Each expected
supergraph SDL is what Hive `composeServices` prints for the same
subgraphs.
"""

from _harness import sg
from gql_composition.compose import compose_subgraphs
from gql_composition.validate import Subgraph
from std.testing import TestSuite, assert_equal


def _check(subgraphs: List[Subgraph], sdl: String) raises:
    """Compose subgraphs and compare the supergraph SDL.

    Args:
        subgraphs: The subgraphs.
        sdl: The expected supergraph SDL.

    Raises:
        Error: If composition fails or the SDL differs.
    """
    var result = compose_subgraphs(subgraphs)
    assert_equal(len(result.errors), 0)
    assert_equal(result.supergraph_sdl, sdl)


def test_directives_mixed() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @foo on'
                    " FIELD_DEFINITION\n\ndirective @ex2 on FIELD\n\ndirective"
                    ' @ex(a: String @deprecated(reason: "r")) on FIELD |'
                    " FRAGMENT_DEFINITION | FRAGMENT_SPREAD | INLINE_FRAGMENT |"
                    " VARIABLE_DEFINITION | QUERY | MUTATION |"
                    " SUBSCRIPTION\n\ntype Query {\n  a: String @foo\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @ex(a: String @deprecated(reason:'
                    ' "s")) on FIELD | FRAGMENT_DEFINITION | FRAGMENT_SPREAD |'
                    " INLINE_FRAGMENT | VARIABLE_DEFINITION | QUERY | MUTATION"
                    " | SUBSCRIPTION | FIELD_DEFINITION\n\ntype Query {\n  b:"
                    " String\n}"
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
            ' @join__graph(name: "b", url: "")\n}\n\ndirective @ex2 on'
            " FIELD\n\ndirective @ex(a: String) on FIELD | FRAGMENT_DEFINITION"
            " | FRAGMENT_SPREAD | INLINE_FRAGMENT | VARIABLE_DEFINITION | QUERY"
            " | MUTATION | SUBSCRIPTION\n\ntype Query @join__type(graph: A)"
            " @join__type(graph: B) {\n  a: String @join__field(graph: A)\n  b:"
            " String @join__field(graph: B)\n}"
        ),
    )


def test_enum_value_tag_only() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@tag"])\n\nenum E {\n  A @tag(name: "t")\n '
                    " B\n}\n\ntype Query {\n  e: E\n}"
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
            ' @join__graph(name: "a", url: "")\n}\n\ntype Query'
            " @join__type(graph: A) {\n  e: E\n}\n\nenum E @join__type(graph:"
            ' A) {\n  A @join__enumValue(graph: A) @tag(name: "t")\n  B'
            " @join__enumValue(graph: A)\n}"
        ),
    )


def test_first_no_query() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " name: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  users: [User]\n}"
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
            ' @join__graph(name: "b", url: "")\n}\n\ntype User'
            ' @join__type(graph: A, key: "id") @join__type(graph: B, key: "id")'
            " {\n  id: ID!\n  name: String @join__field(graph: A)\n}\n\ntype"
            " Query @join__type(graph: A) @join__type(graph: B) {\n  users:"
            " [User] @join__field(graph: B)\n}"
        ),
    )


def test_iface_v1() raises:
    _check(
        [
            sg(
                "a",
                (
                    'interface Node @key(fields: "id") {\n'
                    "  id: ID!\n"
                    "}\n"
                    "\n"
                    'type User implements Node @key(fields: "id") {\n'
                    "  id: ID!\n"
                    "}\n"
                    "\n"
                    "type Query {\n"
                    "  node: Node\n"
                    "}"
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
            ' join__Graph {\n  A @join__graph(name: "a", url: "")\n}\n\ntype'
            ' User implements Node @join__type(graph: A, key: "id")'
            ' @join__implements(graph: A, interface: "Node") {\n  id:'
            " ID!\n}\n\ntype Query @join__type(graph: A) {\n  node:"
            " Node\n}\n\ninterface Node @join__type(graph: A) {\n  id: ID!\n}"
        ),
    )


def test_io_cost() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@interfaceObject", "@cost"])\n\ntype Node'
                    ' @key(fields: "id") @interfaceObject {\n  id: ID!\n '
                    " score: Int @cost(weight: 5)\n}\n\ntype Query {\n  a:"
                    " String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ninterface Node @key(fields: "id") {\n  id:'
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " {\n  id: ID!\n}\n\ntype Query {\n  node: Node\n}"
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
            " true\n) on FIELD_DEFINITION\n\nenum join__Graph {\n  A"
            ' @join__graph(name: "a", url: "")\n  B @join__graph(name: "b",'
            ' url: "")\n}\n\ntype Query @join__type(graph: A)'
            " @join__type(graph: B) {\n  a: String @join__field(graph: A)\n "
            " node: Node @join__field(graph: B)\n}\n\ntype User implements Node"
            ' @join__type(graph: B, key: "id") @join__implements(graph: B,'
            ' interface: "Node") {\n  id: ID!\n  score: Int @join__field'
            " @cost(weight: 5)\n}\n\ninterface Node @join__type(graph: A, key:"
            ' "id", isInterfaceObject: true) @join__type(graph: B, key: "id")'
            " {\n  id: ID!\n  score: Int @join__field(graph: A) @cost(weight:"
            " 5)\n}"
        ),
    )


def test_links_noversion_two_features() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/bar", import: ["@bar"]) @link(url:'
                    ' "https://myspecs.dev/foo/v1.5", import: ["@foo"])'
                    ' @composeDirective(name: "@bar") @composeDirective(name:'
                    ' "@foo")\n\ndirective @bar on'
                    " FIELD_DEFINITION\n\ndirective @foo on"
                    " FIELD_DEFINITION\n\ntype Query {\n  a: String @bar"
                    " @foo\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/foo/v1.7", import: ["@foo", "@baz"])'
                    ' @link(url: "https://myspecs.dev/bar", import: ["@bar"])'
                    ' @composeDirective(name: "@foo") @composeDirective(name:'
                    ' "@baz") @composeDirective(name: "@bar")\n\ndirective @foo'
                    " on FIELD_DEFINITION\n\ndirective @baz on"
                    " FIELD_DEFINITION\n\ndirective @bar on"
                    " FIELD_DEFINITION\n\ntype Query {\n  b: String @foo @baz"
                    " @bar\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url:'
            ' "https://myspecs.dev/bar", import: ["@bar"]) @link(url:'
            ' "https://myspecs.dev/foo/v1.7", import: ["@foo", "@baz"]) {\n '
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
            ' url: "")\n  B @join__graph(name: "b", url: "")\n}\n\ndirective'
            " @bar on FIELD_DEFINITION\n\ndirective @foo on"
            " FIELD_DEFINITION\n\ndirective @baz on FIELD_DEFINITION\n\ntype"
            " Query @join__type(graph: A) @join__type(graph: B) {\n  a: String"
            " @bar @foo @join__field(graph: A)\n  b: String @foo @baz @bar"
            " @join__field(graph: B)\n}"
        ),
    )


def test_spec_links_unused() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/link/v1.0", import: ["@link"])'
                    ' @link(url: "https://specs.apollo.dev/federation/v2.3",'
                    ' import: ["@key"]) @link(url:'
                    ' "https://specs.apollo.dev/tag/v0.2", import: ["@tag"])'
                    ' @link(url: "https://specs.apollo.dev/inaccessible/v0.2",'
                    ' import: ["@inaccessible"]) @link(url:'
                    ' "https://specs.apollo.dev/join/v0.3", import:'
                    ' ["@join__type"])\n\ntype Query {\n  a: String\n}'
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url:'
            ' "https://specs.apollo.dev/link/v1.0", import: ["@link"])'
            ' @link(url: "https://specs.apollo.dev/tag/v0.2", import: ["@tag"])'
            ' @link(url: "https://specs.apollo.dev/inaccessible/v0.2", import:'
            ' ["@inaccessible"]) @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", import: ["@join__type"])'
            " {\n  query: Query\n}\n\ndirective @join__enumValue(graph:"
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
            ' url: "")\n}\n\ntype Query @join__type(graph: A) {\n  a: String\n}'
        ),
    )


def test_spec_links_unused2() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"]) @link(url:'
                    ' "https://specs.apollo.dev/context/v0.1", import:'
                    ' ["@context"]) @link(url:'
                    ' "https://specs.apollo.dev/cost/v0.1", import: ["@cost"])'
                    ' @link(url: "https://specs.apollo.dev/policy/v0.1",'
                    ' import: ["@policy"]) @link(url:'
                    ' "https://specs.apollo.dev/requiresScopes/v0.1", import:'
                    ' ["@requiresScopes"]) @link(url:'
                    ' "https://specs.apollo.dev/authenticated/v0.1", import:'
                    ' ["@authenticated"])\n\ntype Query {\n  a: String\n}'
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url:'
            ' "https://specs.apollo.dev/context/v0.1", import: ["@context"])'
            ' @link(url: "https://specs.apollo.dev/cost/v0.1", import:'
            ' ["@cost"]) @link(url: "https://specs.apollo.dev/policy/v0.1",'
            ' import: ["@policy"]) @link(\n  url:'
            ' "https://specs.apollo.dev/requiresScopes/v0.1"\n  import:'
            ' ["@requiresScopes"]\n) @link(url:'
            ' "https://specs.apollo.dev/authenticated/v0.1", import:'
            ' ["@authenticated"]) {\n  query: Query\n}\n\ndirective'
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
            ' url: "")\n}\n\ntype Query @join__type(graph: A) {\n  a: String\n}'
        ),
    )


def test_dir_composed_vs_exec() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @ex2 on FIELD |'
                    " FIELD_DEFINITION\n\ntype Query {\n  a: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/ex/v1.0", import: ["@ex2"])'
                    ' @composeDirective(name: "@ex2")\n\ndirective @ex2 on'
                    " FIELD_DEFINITION\n\ntype Query {\n  b: String @ex2\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url:'
            ' "https://myspecs.dev/ex/v1.0", import: ["@ex2"]) {\n  query:'
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
            ' @join__graph(name: "b", url: "")\n}\n\ndirective @ex2 on'
            " FIELD_DEFINITION\n\ntype Query @join__type(graph: A)"
            " @join__type(graph: B) {\n  a: String @join__field(graph: A)\n  b:"
            " String @ex2 @join__field(graph: B)\n}"
        ),
    )


def test_dir_plain_vs_exec() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @ex2 on FIELD | QUERY\n\ntype'
                    " Query {\n  a: String\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ndirective @ex2 on'
                    " FIELD_DEFINITION\n\ndirective @other on FIELD\n\ntype"
                    " Query {\n  c: String @ex2\n}"
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
            ' join__Graph {\n  A @join__graph(name: "a", url: "")\n  C'
            ' @join__graph(name: "c", url: "")\n}\n\ndirective @ex2 on FIELD |'
            " QUERY\n\ndirective @other on FIELD\n\ntype Query"
            " @join__type(graph: A) @join__type(graph: C) {\n  a: String"
            " @join__field(graph: A)\n  c: String @join__field(graph: C)\n}"
        ),
    )


def test_type_cost_max() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@cost", "@shareable"])\n\ntype User'
                    ' @key(fields: "id") @cost(weight: 2) {\n  id: ID!\n  name:'
                    " String @shareable @cost(weight: 3)\n  age: Int"
                    " @shareable\n}\n\ntype Query {\n  a: User\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@cost", "@shareable"])\n\ntype User'
                    ' @key(fields: "id") @cost(weight: 5) {\n  id: ID!\n  name:'
                    " String @shareable @cost(weight: 1)\n  age: Int @shareable"
                    " @cost(weight: 4)\n}\n\ntype Query {\n  b: User\n}"
                ),
            ),
            sg(
                "c",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@cost", "@shareable"])\n\ntype User'
                    ' @key(fields: "id") @cost(weight: 1) {\n  id: ID!\n  name:'
                    " String @shareable @cost(weight: 7)\n}\n\ntype Query {\n "
                    " c: User\n}"
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
            " true\n) on FIELD_DEFINITION\n\nenum join__Graph {\n  A"
            ' @join__graph(name: "a", url: "")\n  B @join__graph(name: "b",'
            ' url: "")\n  C @join__graph(name: "c", url: "")\n}\n\ntype User'
            ' @join__type(graph: A, key: "id") @join__type(graph: B, key: "id")'
            ' @join__type(graph: C, key: "id") @cost(weight: 5) {\n  id: ID!\n '
            " name: String @cost(weight: 7)\n  age: Int @join__field(graph: A)"
            " @join__field(graph: B) @cost(weight: 4)\n}\n\ntype Query"
            " @join__type(graph: A) @join__type(graph: B) @join__type(graph: C)"
            " {\n  a: User @join__field(graph: A)\n  b: User"
            " @join__field(graph: B)\n  c: User @join__field(graph: C)\n}"
        ),
    )


def test_field_merge_second() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@shareable", "@inaccessible",'
                    ' "@authenticated"])\n\nenum Color {\n  RED\n '
                    " BLUE\n}\n\ntype Query {\n  name: String @shareable\n "
                    " color: Color @shareable\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@shareable", "@inaccessible",'
                    ' "@authenticated"])\n\nenum Color {\n  "the red"\n  RED\n '
                    ' BLUE\n}\n\ntype Query {\n  "the name"\n  name: String'
                    ' @shareable @inaccessible @deprecated(reason: "old")'
                    " @authenticated\n  color: Color @shareable\n  other:"
                    " String\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url:'
            ' "https://specs.apollo.dev/inaccessible/v0.2", for: SECURITY)'
            ' @link(url: "https://specs.apollo.dev/authenticated/v0.1", for:'
            " SECURITY) {\n  query: Query\n}\n\ndirective"
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
            " EXECUTION\n}\n\ndirective @inaccessible on FIELD_DEFINITION |"
            " OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR |"
            " INPUT_OBJECT | INPUT_FIELD_DEFINITION |"
            " ARGUMENT_DEFINITION\n\ndirective @authenticated on"
            " FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM\n\nenum"
            ' join__Graph {\n  A @join__graph(name: "a", url: "")\n  B'
            ' @join__graph(name: "b", url: "")\n}\n\ntype Query'
            ' @join__type(graph: A) @join__type(graph: B) {\n  """\n  the'
            ' name\n  """\n  name: String @inaccessible @authenticated'
            ' @deprecated(reason: "old")\n  color: Color\n  other: String'
            " @join__field(graph: B)\n}\n\nenum Color @join__type(graph: A)"
            ' @join__type(graph: B) {\n  """\n  the red\n  """\n  RED'
            " @join__enumValue(graph: A) @join__enumValue(graph: B)\n  BLUE"
            " @join__enumValue(graph: A) @join__enumValue(graph: B)\n}"
        ),
    )


def test_listsize() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@listSize"])\n\ntype Conn {\n '
                    " items: [Int] @shareable\n}\n\ntype Query {\n  f1: [Int]"
                    " @shareable\n  f2: [Int] @shareable @listSize(assumedSize:"
                    " 5)\n  f3(first: Int): [Int] @shareable"
                    ' @listSize(slicingArguments: ["first"])\n  f4: [Int]'
                    " @listSize\n  f5: Conn @shareable @listSize(sizedFields:"
                    ' ["items"])\n  f6: [Int] @shareable @listSize(assumedSize:'
                    " 9)\n  f7(first: Int, last: Int): [Int] @shareable"
                    ' @listSize(slicingArguments: ["first", "last"])\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@listSize"])\n\ntype Conn {\n '
                    " items: [Int] @shareable\n}\n\ntype Query {\n  f1: [Int]"
                    " @shareable @listSize(assumedSize: 5)\n  f2: [Int]"
                    " @shareable @listSize(assumedSize: 10)\n  f3(first: Int):"
                    " [Int] @shareable @listSize(assumedSize: 1)\n  f7(first:"
                    " Int): [Int] @shareable\n  f5: Conn @shareable"
                    ' @listSize(assumedSize: 2, sizedFields: ["items"])\n  f6:'
                    " [Int] @shareable @listSize(assumedSize: 3)\n}"
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
            " true\n) on FIELD_DEFINITION\n\nenum join__Graph {\n  A"
            ' @join__graph(name: "a", url: "")\n  B @join__graph(name: "b",'
            ' url: "")\n}\n\ntype Conn @join__type(graph: A) @join__type(graph:'
            " B) {\n  items: [Int]\n}\n\ntype Query @join__type(graph: A)"
            " @join__type(graph: B) {\n  f1: [Int] @listSize(assumedSize: 5)\n "
            " f2: [Int] @listSize(assumedSize: 10)\n  f3(first: Int): [Int]"
            ' @listSize(assumedSize: 1, slicingArguments: ["first"])\n  f4:'
            " [Int] @join__field(graph: A) @listSize\n  f5: Conn"
            ' @listSize(assumedSize: 2, sizedFields: ["items"])\n  f6: [Int]'
            " @listSize(assumedSize: 9)\n  f7(first: Int): [Int]"
            ' @listSize(slicingArguments: ["first"])\n}'
        ),
    )


def test_args_merge() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@tag", "@inaccessible",'
                    ' "@cost"])\n\ntype Query {\n  f(x: Int @deprecated(reason:'
                    ' "old"), y: Int, z: Int @tag(name: "t1"), w: Int'
                    " @cost(weight: 2), v: Int = 1, u: Int @cost(weight: 4)"
                    ' @deprecated(reason: "u")): String @shareable\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@tag", "@inaccessible",'
                    ' "@cost"])\n\ntype Query {\n  f(x: Int @tag(name: "t2")'
                    ' @inaccessible, y: Int @cost(weight: 3) @tag(name: "t3"),'
                    ' z: Int @tag(name: "t1") @cost(weight: 1), w: Int'
                    " @cost(weight: 5) @inaccessible, v: Int = 1 @inaccessible,"
                    ' u: Int @inaccessible @tag(name: "t4")): String'
                    " @shareable\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.5", for: EXECUTION) @link(url:'
            ' "https://specs.apollo.dev/tag/v0.3") @link(url:'
            ' "https://specs.apollo.dev/cost/v0.1") @link(url:'
            ' "https://specs.apollo.dev/inaccessible/v0.2", for: SECURITY) {\n '
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
            " EXECUTION\n}\n\ndirective @tag(name: String!) repeatable on"
            " FIELD_DEFINITION | OBJECT | INTERFACE | UNION |"
            " ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT |"
            " INPUT_FIELD_DEFINITION | SCHEMA\n\ndirective @cost(weight: Int!)"
            " on ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION |"
            " INPUT_FIELD_DEFINITION | OBJECT | SCALAR\n\ndirective"
            " @listSize(\n  assumedSize: Int\n  slicingArguments: [String!]\n "
            " sizedFields: [String!]\n  requireOneSlicingArgument: Boolean ="
            " true\n) on FIELD_DEFINITION\n\ndirective @inaccessible on"
            " FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE"
            " | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION |"
            " ARGUMENT_DEFINITION\n\nenum join__Graph {\n  A @join__graph(name:"
            ' "a", url: "")\n  B @join__graph(name: "b", url: "")\n}\n\ntype'
            " Query @join__type(graph: A) @join__type(graph: B) {\n  f(\n    x:"
            ' Int @tag(name: "t2") @inaccessible @deprecated(reason: "old")\n  '
            '  y: Int @tag(name: "t3") @cost(weight: 3)\n    z: Int @tag(name:'
            ' "t1") @cost(weight: 1)\n    w: Int @inaccessible @cost(weight:'
            ' 5)\n    v: Int = 1 @inaccessible\n    u: Int @tag(name: "t4")'
            ' @inaccessible @cost(weight: 4) @deprecated(reason: "u")\n  ):'
            " String\n}"
        ),
    )


def test_args_composed() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@tag", "@inaccessible", "@cost",'
                    ' "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/my/v1.0", import: ["@my"])'
                    ' @composeDirective(name: "@my")\n\ndirective @my(s:'
                    " String) repeatable on ARGUMENT_DEFINITION |"
                    ' OBJECT\n\ntype Thing @my(s: "a\\"b") {\n  id: ID!'
                    " @shareable\n}\n\ntype Query {\n  g(p: Int @tag(name:"
                    ' "t"), q: Int @inaccessible, r: Int @cost(weight: 2), s:'
                    ' Int @deprecated(reason: "s"), t: Int): Thing'
                    " @shareable\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@tag", "@inaccessible", "@cost",'
                    ' "@composeDirective"]) @link(url:'
                    ' "https://myspecs.dev/my/v1.0", import: ["@my"])'
                    ' @composeDirective(name: "@my")\n\ndirective @my(s:'
                    " String) repeatable on ARGUMENT_DEFINITION |"
                    ' OBJECT\n\ntype Thing @my(s: "a\\"b") @my(s: "c d") {\n '
                    " id: ID! @shareable\n}\n\ntype Query {\n  g(p: Int @my(s:"
                    ' "x"), q: Int @my(s: "y"), r: Int @my(s: "z"), s: Int'
                    ' @my(s: "w"), t: Int @my(s: "v") @my(s: "u")): Thing'
                    " @shareable\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.5", for: EXECUTION) @link(url:'
            ' "https://specs.apollo.dev/tag/v0.3") @link(url:'
            ' "https://specs.apollo.dev/cost/v0.1") @link(url:'
            ' "https://specs.apollo.dev/inaccessible/v0.2", for: SECURITY)'
            ' @link(url: "https://myspecs.dev/my/v1.0", import: ["@my"]) {\n '
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
            " EXECUTION\n}\n\ndirective @tag(name: String!) repeatable on"
            " FIELD_DEFINITION | OBJECT | INTERFACE | UNION |"
            " ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT |"
            " INPUT_FIELD_DEFINITION | SCHEMA\n\ndirective @cost(weight: Int!)"
            " on ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION |"
            " INPUT_FIELD_DEFINITION | OBJECT | SCALAR\n\ndirective"
            " @listSize(\n  assumedSize: Int\n  slicingArguments: [String!]\n "
            " sizedFields: [String!]\n  requireOneSlicingArgument: Boolean ="
            " true\n) on FIELD_DEFINITION\n\ndirective @inaccessible on"
            " FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE"
            " | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION |"
            " ARGUMENT_DEFINITION\n\nenum join__Graph {\n  A @join__graph(name:"
            ' "a", url: "")\n  B @join__graph(name: "b", url:'
            ' "")\n}\n\ndirective @my(s: String) repeatable on'
            ' ARGUMENT_DEFINITION | OBJECT\n\ntype Thing @my(s: "a\\"b") @my(s:'
            ' "c d") @join__type(graph: A) @join__type(graph: B) {\n  id:'
            " ID!\n}\n\ntype Query @join__type(graph: A) @join__type(graph: B)"
            ' {\n  g(\n    p: Int @my(s: "x") @tag(name: "t")\n    q: Int'
            ' @my(s: "y") @inaccessible\n    r: Int @my(s: "z") @cost(weight:'
            ' 2)\n    s: Int @my(s: "w") @deprecated(reason: "s")\n    t: Int'
            ' @my(s: "v") @my(s: "u")\n  ): Thing\n}'
        ),
    )


def test_requires_nested() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires", "@provides",'
                    ' "@shareable"])\n\ntype Org {\n  id: ID! @shareable\n '
                    " name: String @shareable\n}\n\nextend type User"
                    ' @key(fields: "id org { id }") {\n  id: ID! @external\n '
                    " org: Org @external\n  first: Int @external\n  total(n:"
                    ' Int): Int @requires(fields: "org { id name }'
                    ' first")\n}\n\ntype Query {\n  me: User\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Org {\n  id: ID!'
                    " @shareable\n  name: String @shareable\n}\n\ntype User"
                    ' @key(fields: "id org { id }") {\n  id: ID!\n  org: Org\n '
                    " first: Int\n}"
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
            ' @join__graph(name: "b", url: "")\n}\n\ntype Org'
            " @join__type(graph: A) @join__type(graph: B) {\n  id: ID!\n  name:"
            ' String\n}\n\ntype User @join__type(graph: A, key: "id org { id'
            ' }", extension: true) @join__type(graph: B, key: "id org { id }")'
            " {\n  id: ID!\n  org: Org\n  first: Int @join__field(graph: A,"
            " external: true) @join__field(graph: B)\n  total(n: Int): Int"
            ' @join__field(graph: A, requires: "org{id name}first")\n}\n\ntype'
            " Query @join__type(graph: A) @join__type(graph: B) {\n  me: User"
            " @join__field(graph: A)\n}"
        ),
    )


def test_requires_args() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@requires"])\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID!\n  score(x: Float, s:'
                    " String, l: [Int], o: In): Int @external\n  total: Int"
                    ' @requires(fields: "score(x: -1.5e+3, s: \\"a\\\\\\"b\\",'
                    ' l: [1, 2], o: {k: 1}) # note\\n")\n}\n\ninput In {\n  k:'
                    " Int\n}\n\ntype Query {\n  me: User\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    " score(x: Float, s: String, l: [Int], o: In):"
                    " Int\n}\n\ninput In {\n  k: Int\n}"
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
            ' @join__graph(name: "b", url: "")\n}\n\ntype User'
            ' @join__type(graph: A, key: "id") @join__type(graph: B, key: "id")'
            " {\n  id: ID!\n  score(x: Float, s: String, l: [Int], o: In): Int"
            " @join__field(graph: A, external: true) @join__field(graph: B)\n "
            ' total: Int @join__field(graph: A, requires: "score(x:-1.5e+3'
            ' s:\\"a\\\\\\"b\\" l:[1 2]o:{k:1})")\n}\n\ntype Query'
            " @join__type(graph: A) @join__type(graph: B) {\n  me: User"
            " @join__field(graph: A)\n}\n\ninput In @join__type(graph: A)"
            " @join__type(graph: B) {\n  k: Int\n}"
        ),
    )


def test_provides_fragment() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@provides",'
                    ' "@shareable"])\n\ninterface Node {\n  id: ID!\n}\n\ntype'
                    ' User implements Node @key(fields: "id") {\n  id: ID!\n '
                    " name: String @external\n}\n\ntype Query {\n  node: Node"
                    ' @provides(fields: "... on User { name }")\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ninterface Node {\n  id:'
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " {\n  id: ID!\n  name: String @shareable\n}"
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
            ' @join__graph(name: "b", url: "")\n}\n\ntype User implements Node'
            ' @join__type(graph: A, key: "id") @join__type(graph: B, key: "id")'
            ' @join__implements(graph: A, interface: "Node")'
            ' @join__implements(graph: B, interface: "Node") {\n  id: ID!\n '
            " name: String @join__field(graph: A, external: true)"
            " @join__field(graph: B)\n}\n\ntype Query @join__type(graph: A)"
            " @join__type(graph: B) {\n  node: Node @join__field(graph: A,"
            ' provides: "...on User{name}")\n}\n\ninterface Node'
            " @join__type(graph: A) @join__type(graph: B) {\n  id: ID!\n}"
        ),
    )


def test_key_escape() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype User @key(fields: "id\\tupc\\nsku") {\n'
                    "  id: ID!\n  upc: ID!\n  sku: ID!\n}\n\ntype Query {\n "
                    " me: User\n}"
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
            ' join__Graph {\n  A @join__graph(name: "a", url: "")\n}\n\ntype'
            ' User @join__type(graph: A, key: "id\\tupc\\nsku") {\n  id: ID!\n '
            " upc: ID!\n  sku: ID!\n}\n\ntype Query @join__type(graph: A) {\n "
            " me: User\n}"
        ),
    )


def test_extend_nokey() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype Foo {\n  b:'
                    " String\n}\n\ntype Query {\n  foo: Foo @shareable\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\nextend type Foo {\n  c:'
                    " String\n}\n\ntype Query {\n  foo: Foo @shareable\n}"
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
            ' @join__graph(name: "b", url: "")\n}\n\ntype Foo'
            " @join__type(graph: A) @join__type(graph: B) {\n  b: String"
            " @join__field(graph: A)\n  c: String @join__field(graph:"
            " B)\n}\n\ntype Query @join__type(graph: A) @join__type(graph: B)"
            " {\n  foo: Foo\n}"
        ),
    )


def test_ext_external_provides() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@external", "@provides"])\n\nextend type User'
                    ' @key(fields: "id") {\n  id: ID! @external\n  name: String'
                    " @external\n}\n\ntype Query {\n  me: User"
                    ' @provides(fields: "name")\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ntype User @key(fields: "id")'
                    " {\n  id: ID!\n  name: String @shareable\n  age:"
                    " Int\n}\n\ntype Query {\n  users: [User]\n}"
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
            ' @join__graph(name: "b", url: "")\n}\n\ntype User'
            ' @join__type(graph: A, key: "id", extension: true)'
            ' @join__type(graph: B, key: "id") {\n  id: ID!\n  name: String'
            " @join__field(graph: A, external: true) @join__field(graph: B)\n "
            " age: Int @join__field(graph: B)\n}\n\ntype Query"
            " @join__type(graph: A) @join__type(graph: B) {\n  me: User"
            ' @join__field(graph: A, provides: "name")\n  users: [User]'
            " @join__field(graph: B)\n}"
        ),
    )


def test_io_two_args() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject"])\n\ntype Node @key(fields:'
                    ' "id") @interfaceObject {\n  id: ID!\n  posts(first: Int,'
                    " after: String): [String]\n}\n\ntype Query {\n  a:"
                    " String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ninterface Node @key(fields: "id") {\n  id:'
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " {\n  id: ID!\n}\n\ntype Query {\n  node: Node\n}"
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
            " @join__type(graph: A) @join__type(graph: B) {\n  a: String"
            " @join__field(graph: A)\n  node: Node @join__field(graph:"
            " B)\n}\n\ntype User implements Node @join__type(graph: B, key:"
            ' "id") @join__implements(graph: B, interface: "Node") {\n  id:'
            " ID!\n  posts(first: Int, after: String): [String]"
            " @join__field\n}\n\ninterface Node @join__type(graph: A, key:"
            ' "id", isInterfaceObject: true) @join__type(graph: B, key: "id")'
            " {\n  id: ID!\n  posts(first: Int, after: String): [String]"
            " @join__field(graph: A)\n}"
        ),
    )


def test_iface_listsize() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@listSize"])\n\ninterface Node {\n  id: ID!\n '
                    " items(first: Int): [Int] @listSize(slicingArguments:"
                    ' ["first"])\n}\n\ntype User implements Node {\n  name:'
                    " String\n  id: ID!\n  items(first: Int): [Int]"
                    ' @listSize(slicingArguments: ["first"])\n}\n\ntype Post'
                    " implements Node {\n  id: ID!\n  items(first: Int):"
                    " [Int]\n}\n\ntype Query {\n  node: Node\n}"
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
            " true\n) on FIELD_DEFINITION\n\nenum join__Graph {\n  A"
            ' @join__graph(name: "a", url: "")\n}\n\ntype User implements Node'
            " @join__type(graph: A) @join__implements(graph: A, interface:"
            ' "Node") {\n  name: String\n  id: ID!\n  items(first: Int): [Int]'
            ' @listSize(slicingArguments: ["first"])\n}\n\ntype Post implements'
            " Node @join__type(graph: A) @join__implements(graph: A, interface:"
            ' "Node") {\n  id: ID!\n  items(first: Int): [Int]\n}\n\ntype Query'
            " @join__type(graph: A) {\n  node: Node\n}\n\ninterface Node"
            " @join__type(graph: A) {\n  id: ID!\n  items(first: Int): [Int]"
            " @listSize(requireOneSlicingArgument: true, slicingArguments:"
            ' ["first"])\n}'
        ),
    )


def test_io_listsize() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@interfaceObject", "@listSize"])\n\ntype Node'
                    ' @key(fields: "id") @interfaceObject {\n  id: ID!\n '
                    " items(first: Int): [Int] @listSize(slicingArguments:"
                    ' ["first"])\n}\n\ntype Query {\n  a: String\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ninterface Node @key(fields: "id") {\n  id:'
                    ' ID!\n}\n\ntype User implements Node @key(fields: "id")'
                    " {\n  id: ID!\n}\n\ntype Query {\n  node: Node\n}"
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
            " true\n) on FIELD_DEFINITION\n\nenum join__Graph {\n  A"
            ' @join__graph(name: "a", url: "")\n  B @join__graph(name: "b",'
            ' url: "")\n}\n\ntype Query @join__type(graph: A)'
            " @join__type(graph: B) {\n  a: String @join__field(graph: A)\n "
            " node: Node @join__field(graph: B)\n}\n\ntype User implements Node"
            ' @join__type(graph: B, key: "id") @join__implements(graph: B,'
            ' interface: "Node") {\n  id: ID!\n  items(first: Int): [Int]'
            " @join__field @listSize(slicingArguments:"
            ' ["first"])\n}\n\ninterface Node @join__type(graph: A, key: "id",'
            ' isInterfaceObject: true) @join__type(graph: B, key: "id") {\n '
            " id: ID!\n  items(first: Int): [Int] @join__field(graph: A)"
            ' @listSize(slicingArguments: ["first"])\n}'
        ),
    )


def test_arg_inaccessible_both() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable", "@inaccessible",'
                    ' "@tag"])\n\ninterface Named {\n  name(lang: String'
                    " @inaccessible): String\n}\n\ntype Pet implements Named"
                    ' @key(fields: "id") {\n  id: ID!\n  name(lang: String'
                    " @inaccessible): String @shareable\n}\n\ntype Query {\n "
                    " f(x: Int @inaccessible, y: Int @inaccessible"
                    ' @deprecated(reason: "d")): String @shareable\n  pet: Pet'
                    " @shareable\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable", "@inaccessible",'
                    ' "@tag"])\n\ninterface Named {\n  name(lang: String'
                    " @inaccessible): String\n}\n\ntype Pet implements Named"
                    ' @key(fields: "id") {\n  id: ID!\n  name(lang: String'
                    " @inaccessible): String @shareable\n}\n\ntype Query {\n "
                    ' f(x: Int @inaccessible, y: Int @tag(name: "t")): String'
                    " @shareable\n  pet: Pet @shareable\n}"
                ),
            ),
        ],
        (
            'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
            ' "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(url:'
            ' "https://specs.apollo.dev/tag/v0.3") @link(url:'
            ' "https://specs.apollo.dev/inaccessible/v0.2", for: SECURITY) {\n '
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
            " EXECUTION\n}\n\ndirective @tag(name: String!) repeatable on"
            " FIELD_DEFINITION | OBJECT | INTERFACE | UNION |"
            " ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT |"
            " INPUT_FIELD_DEFINITION | SCHEMA\n\ndirective @inaccessible on"
            " FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE"
            " | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION |"
            " ARGUMENT_DEFINITION\n\nenum join__Graph {\n  A @join__graph(name:"
            ' "a", url: "")\n  B @join__graph(name: "b", url: "")\n}\n\ntype'
            ' Pet implements Named @join__type(graph: A, key: "id")'
            ' @join__type(graph: B, key: "id") @join__implements(graph: A,'
            ' interface: "Named") @join__implements(graph: B, interface:'
            ' "Named") {\n  id: ID!\n  name(lang: String @inaccessible):'
            " String\n}\n\ntype Query @join__type(graph: A) @join__type(graph:"
            ' B) {\n  f(\n    x: Int @inaccessible\n    y: Int @tag(name: "t")'
            ' @inaccessible @deprecated(reason: "d")\n  ): String\n  pet:'
            " Pet\n}\n\ninterface Named @join__type(graph: A)"
            " @join__type(graph: B) {\n  name(lang: String): String\n}"
        ),
    )


def test_enum_desc_both() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\nenum Color {\n  "red one"\n  RED\n '
                    " BLUE\n}\n\ntype Query {\n  a: Color\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\nenum Color {\n  "red two"\n  RED\n '
                    " BLUE\n}\n\ntype Query {\n  b: Color\n}"
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
            " @join__type(graph: A) @join__type(graph: B) {\n  a: Color"
            " @join__field(graph: A)\n  b: Color @join__field(graph:"
            " B)\n}\n\nenum Color @join__type(graph: A) @join__type(graph: B)"
            ' {\n  """\n  red one\n  """\n  RED @join__enumValue(graph: A)'
            " @join__enumValue(graph: B)\n  BLUE @join__enumValue(graph: A)"
            " @join__enumValue(graph: B)\n}"
        ),
    )


def test_v1_provides() raises:
    _check(
        [
            sg(
                "a",
                (
                    'extend type User @key(fields: "id") {\n'
                    "  id: ID! @external\n"
                    "  name: String @external\n"
                    "}\n"
                    "\n"
                    "type Query {\n"
                    '  me: User @provides(fields: "name")\n'
                    "}"
                ),
            ),
            sg(
                "b",
                (
                    'type User @key(fields: "id") {\n'
                    "  id: ID!\n"
                    "  name: String\n"
                    "}\n"
                    "\n"
                    "type Query {\n"
                    "  users: [User]\n"
                    "}"
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
            ' @join__graph(name: "b", url: "")\n}\n\ntype User'
            ' @join__type(graph: A, key: "id") @join__type(graph: B, key: "id")'
            " {\n  id: ID!\n  name: String @join__field(graph: A, external:"
            " true) @join__field(graph: B)\n}\n\ntype Query @join__type(graph:"
            " A) @join__type(graph: B) {\n  me: User @join__field(graph: A,"
            ' provides: "name")\n  users: [User] @join__field(graph: B)\n}'
        ),
    )


def test_io_missing_arg() raises:
    _check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@interfaceObject", "@shareable"])\n\ntype Node'
                    ' @key(fields: "id") @interfaceObject {\n  id: ID!\n '
                    " posts(first: Int, after: String): [String]"
                    " @shareable\n}\n\ntype Query {\n  a: String\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable"])\n\ninterface Node @key(fields:'
                    ' "id") {\n  id: ID!\n  posts(first: Int):'
                    " [String]\n}\n\ntype User implements Node @key(fields:"
                    ' "id") {\n  id: ID!\n  posts(first: Int): [String]'
                    " @shareable\n}\n\ntype Query {\n  node: Node\n}"
                ),
            ),
            sg(
                "d",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ninterface Node @key(fields: "id") {\n  id:'
                    ' ID!\n}\n\ntype Book implements Node @key(fields: "id")'
                    " {\n  id: ID!\n}\n\ntype Query {\n  book: Book\n}"
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
            ' @join__graph(name: "b", url: "")\n  D @join__graph(name: "d",'
            ' url: "")\n}\n\ntype Query @join__type(graph: A)'
            " @join__type(graph: B) @join__type(graph: D) {\n  a: String"
            " @join__field(graph: A)\n  node: Node @join__field(graph: B)\n "
            " book: Book @join__field(graph: D)\n}\n\ntype User implements Node"
            ' @join__type(graph: B, key: "id") @join__implements(graph: B,'
            ' interface: "Node") {\n  id: ID!\n  posts(first: Int):'
            " [String]\n}\n\ntype Book implements Node @join__type(graph: D,"
            ' key: "id") @join__implements(graph: D, interface: "Node") {\n '
            " id: ID!\n  posts(first: Int): [String]"
            " @join__field\n}\n\ninterface Node @join__type(graph: A, key:"
            ' "id", isInterfaceObject: true) @join__type(graph: B, key: "id")'
            ' @join__type(graph: D, key: "id") {\n  id: ID!\n  posts(first:'
            " Int): [String] @join__field(graph: A) @join__field(graph: B)\n}"
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
