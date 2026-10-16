# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A schema with each form of SDL that apollo-compiler serializes in its
own way, for `test_serialize` and `test_minify`.

The expected texts of the tests are the output of the Apollo MCP Server
2.0.0 `introspect` tool for this schema, with `depth: 1`.
"""


def feature_sdl() -> String:
    """Return the SDL of the feature schema.

    Returns:
        The SDL text.
    """
    var lines: List[String] = [
        '"""',
        "The schema description",
        '"""',
        'schema @link(url: "x") { query: Root mutation: Mutation }',
        "",
        "directive @link(url: String) on SCHEMA",
        (
            'directive @tag("""The tag name""" name: String!, extra: [Int] ='
            " [1, 2]) repeatable on FIELD_DEFINITION | OBJECT |"
            " ARGUMENT_DEFINITION | INPUT_FIELD_DEFINITION | ENUM_VALUE |"
            " SCALAR | INTERFACE | UNION | ENUM | INPUT_OBJECT"
        ),
        "",
        '"""A short one"""',
        'type Root implements Node & Named @tag(name: "root", extra: [3, 4]) {',
        (
            '  """This is a description that is definitely longer than'
            ' seventy characters in total length."""'
        ),
        "  id: ID!",
        "  name: String",
        '  "Ends with a quote \\"x\\""',
        "  quoted: String",
        '  """Has a triple \\""" quote inside"""',
        "  triple: String",
        '  "  leading space line"',
        "  spaced: String",
        '  "has\\rcarriage"',
        "  cr: String",
        '  "ends with backslash \\\\"',
        "  slash: String",
        '  """',
        "  Line one",
        "    Line two indented",
        "",
        "  Line four",
        '  """',
        "  multi: String",
        '  "\\n  starts blank"',
        "  blank: String",
        '  "  a\\n  b"',
        "  indented: String",
        (
            '  plain(a: Int, b: [String!]! = ["x", "y"], c: Point = {x: 1, y:'
            " 2.5}): Int"
        ),
        (
            '  described("""arg desc""" a: Int = 1, b: Color = RED @tag(name:'
            ' "b")): [Root!]'
        ),
        '  noDesc(a: Int @deprecated(reason: "old")): Boolean @deprecated',
        (
            '  defaults(s: String = "a\\nb", e: [Int] = [], o: Point = {}, n:'
            " Int = null, f: Boolean = false, t: Boolean = true, nested:"
            ' [[Int]] = [[1], [2, 3]]): String @tag(name: "x\\ty\\u0001z")'
        ),
        "  shape: Shape",
        "  search: Result",
        "}",
        "",
        "type Mutation { doIt(input: Point): Int }",
        "",
        "interface Node { id: ID! }",
        (
            'interface Named implements Node @tag(name: "i") { id: ID! name:'
            " String }"
        ),
        "",
        'union Result @tag(name: "u") = Root | Mutation',
        "",
        'enum Color @tag(name: "e") {',
        '  """red one"""',
        "  RED",
        '  GREEN @deprecated(reason: "no\\nmore")',
        '  BLUE @tag(name: "b")',
        "}",
        "",
        'input Point @tag(name: "p") {',
        '  """x coord"""',
        '  x: Int = 0 @tag(name: "px")',
        "  y: Float",
        "  list: [Int] = [1, 2]",
        '  obj: Inner = {a: [1, 2], b: {c: "d\\ne"}}',
        "}",
        "",
        "input Inner { a: [Int] b: Deep }",
        "input Deep { c: String }",
        "",
        'scalar Shape @specifiedBy(url: "https://example.com/shape")',
    ]
    return "\n".join(lines)
