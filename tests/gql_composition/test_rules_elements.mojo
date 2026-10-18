# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_composition.rules_elements`.

Upstream has no test file for these cases. The expected errors are those of
the subgraph phase of Hive Federation Composition v0.27.0 `validate` in
Node.js on the same subgraphs.
"""

from _harness import check, sg
from gql_composition.validate import Subgraph
from std.testing import TestSuite


def _v2(
    version: String, imports: String, rest: String
) raises -> List[Subgraph]:
    """Return a subgraph that links a federation version with imports."""
    return [
        sg(
            "a",
            'extend schema @link(url: "https://specs.apollo.dev/federation/v'
            + version
            + '", import: ['
            + imports
            + "])"
            + rest,
        )
    ]


def test_override_labels() raises:
    var labels: List[String] = [
        '"percent(5a)"',
        '"percent(abc)"',
        '"percent(1234)"',
        '"percent(5.)"',
        '"percent(5.!)"',
        '"percent(5.a)"',
        '"percent(100.5)"',
        '"percent(100.0)"',
        '"percent(5.5)"',
        '"percent(5"',
        '""',
        '"Label"',
        '"~abc"',
        '"1abc"',
        '"a"',
        '"a!"',
        '"percent(200)"',
        '"percent(+5)"',
        '"percent(5.123456789)"',
        '"percent()"',
        "1",
        '"percent(100)"',
    ]
    var valid: List[Int] = [7, 8, 11, 14, 21]
    var fields = String("")
    var expected = List[String]()
    for index in range(len(labels)):
        var name = "f" + String(index)
        fields += (
            "  "
            + name
            + ': String @override(from: "b", label: '
            + labels[index]
            + ")\n"
        )
        if index not in valid:
            expected.append(
                "[OVERRIDE_LABEL_INVALID] [a] Invalid @override label "
                + labels[index]
                + ' on field "Query.'
                + name
                + '" on subgraph "a": labels must start with a letter and'
                " after that may contain alphanumerics, underscores, minuses,"
                " colons, periods, or slashes. Alternatively, labels may be"
                ' of the form "percent(x)" where x is a float between 0-100'
                " inclusive."
            )
    expected.append(
        '[INVALID_GRAPHQL] [a] Invalid value for "@override(label:)" of type'
        ' "String" in application of "@override" to "Query.f20".'
    )
    check(
        _v2("2.7", '"@override"', "\n\ntype Query {\n" + fields + "}\n"),
        expected,
    )


def test_override_odd_arguments() raises:
    # Below v2.7 a label is an unknown argument; a value that is not a
    # string stops the rule.
    check(
        _v2(
            "2.6",
            '"@override"',
            '\n\ntype Query {\n  f: String @override(from: "b", label: 1)\n}\n',
        ),
        [
            (
                '[INVALID_GRAPHQL] [a] Unknown argument "label" on directive'
                ' "@override".'
            ),
        ],
    )
    check(
        _v2(
            "2.7",
            '"@override"',
            (
                "\n\ntype Query {\n  f: String @override\n  g: String"
                " @override(from: 1)\n}\n"
            ),
        ),
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@override" argument "from"'
                ' of type "String!" is required, but it was not provided.'
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@override(from:)" of'
                ' type "String!" in application of "@override" to "Query.g".'
            ),
        ],
    )
    check(
        _v2(
            "2.7",
            '"@override"',
            '\n\ntype Query @override(from: "b") {\n  f: String\n}\n',
        ),
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@override" may not be used'
                " on OBJECT."
            ),
        ],
    )


def test_directives_off_their_locations() raises:
    var imports = '"@key", "@interfaceObject"'
    check(
        _v2(
            "2.3",
            imports,
            "\n\nenum E @interfaceObject { A }\n\ntype Query { a: E }\n",
        ),
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@interfaceObject" may not be'
                " used on ENUM."
            ),
        ],
    )
    check(
        _v2("2.3", imports, " @interfaceObject\n\ntype Query { a: Int }\n"),
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@interfaceObject" may not be'
                " used on SCHEMA."
            ),
        ],
    )
    check(
        _v2(
            "2.3",
            imports,
            "\n\ntype T { id: ID @interfaceObject }\n\ntype Query { a: T }\n",
        ),
        [
            (
                "[INTERFACE_OBJECT_USAGE_ERROR] [a] The @interfaceObject"
                " directive can only be applied to entity types but type"
                ' "T" has no @key in this subgraph.'
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@interfaceObject" may not be'
                " used on FIELD_DEFINITION."
            ),
        ],
    )
    check(
        _v2(
            "2.3",
            '"@key", "@extends", "@shareable"',
            (
                " @extends @shareable\n\nenum E @extends @shareable { A"
                " }\n\ntype Query { a: E }\n"
            ),
        ),
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@extends" may not be used on'
                " SCHEMA."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@shareable" may not be used'
                " on SCHEMA."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@extends" may not be used on'
                " ENUM."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@shareable" may not be used'
                " on ENUM."
            ),
        ],
    )


def test_types_without_fields() raises:
    check(
        _v2(
            "2.3",
            '"@key", "@extends", "@shareable", "@external"',
            (
                " @external\n\ntype T @extends\ntype U @shareable\ninterface I"
                " @extends\n\ntype Query { a: Int }\n"
            ),
        ),
        [
            (
                '[INVALID_GRAPHQL] [a] Directive "@external" may not be used'
                " on SCHEMA."
            ),
            "[INVALID_GRAPHQL] [a] Type T must define one or more fields.",
            "[INVALID_GRAPHQL] [a] Type U must define one or more fields.",
            "[INVALID_GRAPHQL] [a] Type I must define one or more fields.",
        ],
    )


def test_external_on_interface_field() raises:
    check(
        _v2(
            "2.3",
            '"@key", "@external"',
            "\n\ninterface I { a: String @external }\n\ntype Query { i: I }\n",
        ),
        [],
    )


def test_cost_on_input_extension() raises:
    check(
        _v2(
            "2.9",
            '"@cost"',
            (
                "\n\ninput I { a: Int }\nextend input I { b: Int @cost(weight:"
                " 2) }\n\ntype Query { a(i: I): Int }\n"
            ),
        ),
        [],
    )


def test_compose_directive_links() raises:
    # A federation link without imports, a link without imports beside an
    # imported `@composeDirective`, then an import with an alias.
    check(
        _v2(
            "2.1",
            '"@composeDirective"',
            (
                ' @link(url: "https://myspecs.dev/foo/v1.0")'
                ' @composeDirective(name: "@foo")\n\ndirective @foo on'
                " FIELD_DEFINITION\n\ntype Query { a: Int }\n"
            ),
        ),
        [
            (
                '[DIRECTIVE_COMPOSITION_ERROR] Directive "@foo" in subgraph'
                ' "a" cannot be composed because it is not a member of a core'
                " feature"
            ),
        ],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1")'
                    ' @federation__composeDirective(name: "@foo")\n\ndirective'
                    " @foo on FIELD_DEFINITION\n\ntype Query { a: Int }\n"
                ),
            ),
        ],
        [
            (
                '[DIRECTIVE_COMPOSITION_ERROR] Directive "@foo" in subgraph'
                ' "a" cannot be composed because it is not a member of a core'
                " feature"
            ),
        ],
    )
    check(
        _v2(
            "2.1",
            '"@composeDirective"',
            (
                ' @link(url: "https://myspecs.dev/foo/v1.0", import: [{name:'
                ' "@foo", as: "@bar"}]) @composeDirective(name:'
                ' "@bar")\n\ndirective @bar on FIELD_DEFINITION\n\ntype Query'
                " { a: Int @bar }\n"
            ),
        ),
        [],
    )


def test_cost_weights() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    " Query { a: Int }\ntype T @cost(weight: 1) { a(x: Int"
                    " @cost(weight: 2)): Int @cost(weight: 3) }\ninterface I"
                    " @cost(weight: 1) { a: Int @cost(weight: 1) }\ntype IO"
                    ' @key(fields: "id") @interfaceObject @cost(weight: 4) {'
                    " id: ID! }\nscalar S @cost(weight: 5)\nextend scalar S"
                    " @cost(weight: 6)\nenum E @cost(weight: 7) { A }\nextend"
                    " enum E @cost(weight: 8)\ninput In { a: Int @cost(weight:"
                    " 9) }\ndirective @d(x: Int @cost(weight: 10)) on"
                    " OBJECT\nextend schema @cost(weight: 1)\nunion U"
                    " @cost(weight: 1) = T\n"
                ),
            ),
        ],
        [
            (
                "[COST_APPLIED_TO_INTERFACE_FIELD] [a] @cost cannot be applied"
                ' to interface "I.a"'
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@cost" may not be used on'
                " SCHEMA."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@cost" may not be used on'
                " INTERFACE."
            ),
            (
                '[INVALID_GRAPHQL] [a] The directive "@cost" can only be used'
                " once at this location."
            ),
            (
                '[INVALID_GRAPHQL] [a] The directive "@cost" can only be used'
                " once at this location."
            ),
            '[INVALID_GRAPHQL] [a] Directive "@cost" may not be used on UNION.',
        ],
    )


def test_cost_weight_missing() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    " Query { a: Int }\ntype T @cost { a: Int }\n"
                ),
            ),
        ],
        [
            'THROWS Expected @cost to have a "weight" argument',
        ],
    )


def test_cost_weight_string() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int }\ntype T @cost(weight: "1") { a: Int }\n'
                ),
            ),
        ],
        [
            'THROWS Expected "@cost(weight:)" to be of type Int',
        ],
    )


def test_cost_weight_huge() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    " Query { a: Int }\ntype T @cost(weight:"
                    " 99999999999999999999999) { a: Int @cost(weight:"
                    " -99999999999999999999999) }\n"
                ),
            ),
        ],
        [],
    )


def test_interface_object_old_version() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@interfaceObject"])\ntype Query { a: Int'
                    ' }\ntype T @key(fields: "id") @interfaceObject { id:'
                    " ID! }\n"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@interfaceObject".'
            ),
        ],
    )


def test_interface_object_places() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    " Query { a: Int }\ninterface I @interfaceObject { a: Int"
                    ' }\ntype T @key(fields: "id") { id: ID! a: Int'
                    " @interfaceObject }\nextend schema"
                    " @interfaceObject\nextend type T @interfaceObject\n"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_extends_places() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int }\ninterface I @extends @key(fields: "a")'
                    ' { a: Int }\ntype T @extends @key(fields: "id") { id: ID!'
                    ' b: Int }\nextend type U @extends @key(fields: "id") { id:'
                    " ID! }\nextend schema @extends\nscalar S @extends\n"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_extends_v1() raises:
    check(
        [
            sg(
                "a",
                (
                    'type Query { a: Int }\ntype T @extends @key(fields: "id")'
                    " { id: ID! @external b: Int }\ninterface I @extends { a:"
                    " Int }\n"
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [a] Type "T" is an extension type,'
                ' but there is no type definition for "T" in any subgraph.'
            ),
        ],
    )


def test_shareable_places() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    " Query { a: Int }\ntype T @shareable { a: Int @shareable"
                    " }\nextend type T @shareable { b: Int }\ninterface I"
                    " @shareable { a: Int @shareable }\nextend schema"
                    ' @shareable\ntype IO @key(fields: "id") @interfaceObject'
                    " @shareable { id: ID! a: Int @shareable }\ninput In { a:"
                    " Int @shareable }\n"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_shareable_old() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@shareable"])\ntype Query { a: Int }\ntype T @shareable'
                    " @shareable { a: Int @shareable @shareable }\n"
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [a] The directive "@shareable" can only be'
                " used once at this location."
            ),
            (
                '[INVALID_GRAPHQL] [a] The directive "@shareable" can only be'
                " used once at this location."
            ),
        ],
    )


def test_external_places() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int }\ntype T @key(fields: "id") @external {'
                    " id: ID! a: Int @external }\nextend type T @external { b:"
                    " Int @external }\ninterface I { a: Int @external }\nextend"
                    ' schema @external\ntype IO @key(fields: "id")'
                    " @interfaceObject { id: ID! a: Int @external }\n"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_external_v1() raises:
    check(
        [
            sg(
                "a",
                (
                    'type Query { a: Int }\ntype T @key(fields: "id") @external'
                    " { id: ID! a: Int @external }\nextend type U @key(fields:"
                    ' "id") { id: ID! @external b: Int @external'
                    ' @requires(fields: "id") }\n'
                ),
            ),
        ],
        [
            (
                '[EXTENSION_WITH_NO_BASE] [a] Type "U" is an extension type,'
                ' but there is no type definition for "U" in any subgraph.'
            ),
        ],
    )


def test_external_with_other_directives() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires", "@tag",'
                    ' "@inaccessible"])\ntype Query { a: Int }\ntype T'
                    ' @key(fields: "id") { id: ID! a: Int @external @tag(name:'
                    ' "x") @inaccessible @shareable @deprecated b: Int'
                    ' @external @provides(fields: "x") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_0() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(50)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_1() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(0.5)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_2() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(100)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_3() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(100.0)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_4() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(101)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_5() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(0)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_6() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(1234)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_7() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(50.12345678)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_8() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(50.123456789)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_9() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent()") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_10() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(5") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_11() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(a)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_12() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(.5)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_13() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(5.)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_14() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(05)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_15() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(100.1)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_16() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(100.00)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_17() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(1.x)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_18() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label: "x") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_19() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label: "") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_20() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label: "x:y") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_21() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label: "1abc") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_22() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "a-b_c:d.e/f") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_23() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label: "a b") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_24() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label: "_a") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_25() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label: "é") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_int() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label: 1) }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_label_old_version() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int @override(from: "b", label:'
                    ' "percent(5)") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_from_missing() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    " Query { a: Int @override b: Int @override(from: 1) c: Int"
                    ' @override(from: "a") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_override_places() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    " Query { a: Int }\ninterface I { a: Int @override(from:"
                    ' "b") }\ntype T @override(from: "b") @key(fields: "id") {'
                    ' id: ID! }\nextend schema @override(from: "b")\ntype IO'
                    ' @key(fields: "id") @interfaceObject { id: ID! a: Int'
                    ' @override(from: "b") }\n'
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@cost".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                ' element "@context".'
            ),
        ],
    )


def test_context_names() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@cost", "@interfaceObject", "@extends",'
                    ' "@shareable", "@external", "@override", "@context",'
                    ' "@composeDirective", "@provides", "@requires"])\ntype'
                    ' Query { a: Int }\ntype A @context(name: "a1") { a: Int'
                    ' }\ntype B @context(name: "1a") { a: Int }\ntype C'
                    ' @context(name: "") { a: Int }\ntype D @context(name:'
                    ' "a_b") { a: Int }\ntype E @context(name: 1) { a: Int'
                    " }\ntype F @context { a: Int }\nscalar S @context(name:"
                    ' "s")\nextend schema @context(name: "x")\ninterface I'
                    ' @context(name: "i") { a: Int }\nunion U @context(name:'
                    ' "u") = A\nextend union U @context(name: "v")\ntype IO'
                    ' @key(fields: "id") @interfaceObject @context(name: "io")'
                    ' { id: ID! }\nextend type A @context(name: "ext")\n'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NAME_INVALID] [a] Context name "1a" is invalid. It'
                " should have only alphanumeric characters."
            ),
            (
                '[CONTEXT_NAME_INVALID] [a] Context name "" is invalid. It'
                " should have only alphanumeric characters."
            ),
            (
                '[CONTEXT_NAME_INVALID] [a] Context name "a_b" is invalid. It'
                " should have only alphanumeric characters."
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@context" may not be used on'
                " SCHEMA."
            ),
            (
                '[INVALID_GRAPHQL] [a] Invalid value for "@context(name:)" of'
                ' type "String!" in application of "@context" to "E".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@context" argument "name" of'
                ' type "String!" is required, but it was not provided.'
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@context" may not be used on'
                " SCALAR."
            ),
        ],
    )


def test_compose_directive_old_version() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\nextend schema @composeDirective(name:'
                    ' "@x")\ntype Query { a: Int }\n'
                ),
            ),
        ],
        [
            '[INVALID_GRAPHQL] [a] Unknown directive "@composeDirective".',
        ],
    )


def test_compose_directive_names() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://example.com/my/v1.0", import: ["@my", { name:'
                    ' "@other", as: "@renamed" }, "Type"])\nextend schema'
                    ' @composeDirective(name: "@my") @composeDirective(name:'
                    ' "my") @composeDirective(name: 1) @composeDirective'
                    ' @composeDirective(name: "@renamed")'
                    ' @composeDirective(name: "@other") @composeDirective(name:'
                    ' "@missing") @composeDirective(name: "@key")'
                    ' @composeDirective(name: "@local")\ndirective @my on'
                    " OBJECT\ndirective @renamed on OBJECT\ndirective @local on"
                    " OBJECT\ntype Query { a: Int }\n"
                ),
            ),
        ],
        [
            (
                "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching"
                " directive definition for argument to @composeDirective"
                ' "@other" in subgraph "a".'
            ),
            (
                "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching"
                " directive definition for argument to @composeDirective"
                ' "@missing" in subgraph "a".'
            ),
            (
                "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching"
                ' directive definition for argument to @composeDirective "@key"'
                ' in subgraph "a".'
            ),
            (
                '[DIRECTIVE_COMPOSITION_ERROR] Directive "@local" in subgraph'
                ' "a" cannot be composed because it is not a member of a core'
                " feature"
            ),
            (
                "[INVALID_GRAPHQL] [a] Invalid value for"
                ' "@composeDirective(name:)" of type "String!" in application'
                ' of "@composeDirective" to "schema".'
            ),
            (
                '[INVALID_GRAPHQL] [a] Directive "@composeDirective" argument'
                ' "name" of type "String!" is required, but it was not'
                " provided."
            ),
        ],
    )


def test_compose_directive_no_definitions() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@composeDirective"]) @link(url:'
                    ' "https://example.com/my/v1.0")\nextend schema'
                    ' @composeDirective(name: "@my")\ntype Query { a: Int }\n'
                ),
            ),
        ],
        [
            (
                "[DIRECTIVE_COMPOSITION_ERROR] Could not find matching"
                ' directive definition for argument to @composeDirective "@my"'
                ' in subgraph "a".'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
