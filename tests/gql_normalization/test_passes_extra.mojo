# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""More tests of the selection passes, beyond the upstream suite.

They reach each case of `replaceFragmentSpread`, `couldInline`, the merge,
the deduplication and the `@include` and `@skip` handling, with the
behavior of graphql-go-tools v2 at 9ef6e24.
"""

from _norm import *
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_normalization.normalize import NormalizerOptions, OperationNormalizer
from std.testing import TestSuite, assert_equal

comptime SCHEMA = """
interface Named { name: String }
interface Aged { age: Int }
interface Other { other: String }
type Person implements Named & Aged { name: String age: Int }
type Pet implements Named { name: String }
type Rock { weight: Int }
type Robot implements Other { other: String }
type Bad implements Named { x: Int }
union Thing = Person | Rock
union Machine = Robot
type Query {
  named: Named
  aged: Aged
  thing: Thing
  machine: Machine
  person: Person
  rock: Rock
  robot: Robot
  bad: Bad
  other: Other
  f(a: Int, b: [Int], c: String): String
  g: String
}
"""
"""A schema with each relation of interfaces, unions and objects."""


def _spread(
    enclosing: StringSlice, fragment: StringSlice, inlined: Bool
) raises:
    """Spread a fragment on `fragment` in a selection of `enclosing`."""
    var fields = "__typename"
    var operation = (
        "{ "
        + String(enclosing)
        + " { ...F @x } } fragment F on "
        + String(fragment)
        + " { "
        + fields
        + " }"
    )
    var expected = operation
    if inlined:
        expected = (
            "{ "
            + String(enclosing)
            + " { ... on "
            + String(fragment)
            + " @x { "
            + fields
            + " } } } fragment F on "
            + String(fragment)
            + " { "
            + fields
            + " }"
        )
    run(fragment_spread_inline_pass, SCHEMA, operation, expected)


def test_spread_on_same_type() raises:
    _spread("person", "Person", True)


def test_spread_of_interface_on_object() raises:
    _spread("person", "Named", True)
    _spread("rock", "Named", False)
    _spread("bad", "Named", False)


def test_spread_of_interface_on_interface() raises:
    _spread("named", "Aged", True)
    _spread("named", "Other", False)


def test_spread_of_interface_on_union() raises:
    _spread("thing", "Named", True)
    _spread("thing", "Other", False)


def test_spread_of_union_on_object() raises:
    _spread("person", "Thing", True)
    _spread("robot", "Thing", False)


def test_spread_of_object_on_interface() raises:
    _spread("named", "Person", True)
    _spread("named", "Rock", False)
    _spread("named", "Bad", False)


def test_spread_of_union_on_interface() raises:
    _spread("named", "Thing", True)
    _spread("named", "Machine", False)


def test_spread_of_object_on_union() raises:
    _spread("thing", "Person", True)
    _spread("thing", "Robot", False)


def test_spread_on_unknown_field() raises:
    run(
        fragment_spread_inline_pass,
        SCHEMA,
        "{ unknown { ...F } } fragment F on Person { name }",
        "{ unknown { ...F } } fragment F on Person { name }",
    )


def test_spread_of_undefined_fragment() raises:
    run_error(
        fragment_spread_inline_pass,
        SCHEMA,
        "{ person { ...Missing } }",
        "fragment: Missing undefined",
    )


def test_spread_of_fragment_on_unknown_type() raises:
    run_error(
        fragment_spread_inline_pass,
        SCHEMA,
        "{ person { ...F } } fragment F on Missing { name }",
        'Unknown type "Missing".',
    )


def test_spread_inside_inline_fragment() raises:
    run(
        fragment_spread_inline_pass,
        SCHEMA,
        "{ named { ... on Person { ...F } } } fragment F on Person { age }",
        (
            "{ named { ... on Person { ... on Person { age } } } } fragment F"
            " on Person { age }"
        ),
    )


def test_spread_in_introspection() raises:
    run(
        fragment_spread_inline_pass,
        SCHEMA,
        (
            '{ __schema { ...S } __type(name: "Query") { ...T } } fragment S'
            " on __Schema { description } fragment T on __Type { name }"
        ),
        (
            "{ __schema { ... on __Schema { description } } __type(name:"
            ' "Query") { ... on __Type { name } } } fragment S on __Schema {'
            " description } fragment T on __Type { name }"
        ),
    )


def _inline(operation: StringSlice, expected: StringSlice) raises:
    """Run `inlineSelectionsFromInlineFragments`."""
    run(inline_selections_pass, SCHEMA, operation, expected)


def test_could_inline() raises:
    _inline("{ person { ... @x { name } } }", "{ person { ... @x { name } } }")
    _inline("{ person { ... { name } } }", "{ person { name } }")
    _inline(
        "{ unknown { ... on Person { name } } }",
        "{ unknown { ... on Person { name } } }",
    )
    _inline("{ person { ... on Person { name } } }", "{ person { name } }")
    _inline("{ person { ... on Named { name } } }", "{ person { name } }")
    _inline(
        "{ person { ... on Named { ... on Person { age } } } }",
        "{ person { age } }",
    )
    _inline(
        "{ person { ... on Named { ... on Rock { weight } } } }",
        "{ person { ... on Named { ... on Rock { weight } } } }",
    )
    _inline(
        "{ named { ... on Person { name } } }",
        "{ named { ... on Person { name } } }",
    )
    _inline(
        "{ person { ... on Named { ... { age } } } }",
        "{ person { ... on Named { age } } }",
    )
    _inline(
        "{ rock { ... on Named { name } } }",
        "{ rock { ... on Named { name } } }",
    )


def _merge(operation: StringSlice, expected: StringSlice) raises:
    """Run `mergeInlineFragmentSelections`."""
    run(merge_pass, SCHEMA, operation, expected)


def test_merge_inline_fragments() raises:
    _merge(
        (
            "{ person { ... on Person { name } ... on Person @x { age } ... on"
            " Named { name } } }"
        ),
        (
            "{ person { ... on Person { name } ... on Person @x { age } ... on"
            " Named { name } } }"
        ),
    )
    _merge(
        "{ person { ... on Person { name } ... on Person { age } } }",
        "{ person { ... on Person { name age } } }",
    )


def test_merge_fields() raises:
    _merge("{ person { name } person { age } }", "{ person { name age } }")
    _merge(
        "{ a: person { name } person { age } }",
        "{ a: person { name } person { age } }",
    )
    _merge(
        "{ person @x { name } person { age } }",
        "{ person @x { name } person { age } }",
    )
    _merge(
        "{ g g person { name } rock { weight } }",
        "{ g g person { name } rock { weight } }",
    )
    _merge(
        "{ person { name } ... on Query { g } }",
        "{ person { name } ... on Query { g } }",
    )
    _merge("{ g person { name } }", "{ g person { name } }")


def test_merge_fields_defer() raises:
    _merge(
        (
            "{ person @__defer_internal(id: 2) { name } person"
            " @__defer_internal(id: 1) { age } }"
        ),
        "{ person @__defer_internal(id: 1) { name age } }",
    )
    _merge(
        "{ person @__defer_internal(id: 2) { name } person { age } }",
        "{ person { name age } }",
    )
    _merge(
        "{ person { name } person @__defer_internal(id: 1) { age } }",
        "{ person { name age } }",
    )
    _merge(
        (
            "{ person @__defer_internal(id: 3) { name } person"
            " @__defer_internal(id: 3, parentDeferId: 1) { age } }"
        ),
        "{ person @__defer_internal(id: 3) { name age } }",
    )
    _merge(
        (
            "{ person @__defer_internal(parentDeferId: 3, id: 5) { name }"
            ' person @__defer_internal(label: "x") { age } }'
        ),
        '{ person @__defer_internal(label: "x") { name age } }',
    )


def _dedupe(operation: StringSlice, expected: StringSlice) raises:
    """Run `deduplicateFields`."""
    run(deduplicate_pass, SCHEMA, operation, expected)


def test_deduplicate_arguments() raises:
    _dedupe(
        (
            "{ f(a: 1) f(a: 2) f(a: 1) f(b: [1]) f(b: [1]) f(b: [1, 2]) f(c:"
            ' "x") f(c: """x""") f(a: 1, b: [1]) f(a: 1) @x f(a: 1) @y f(b:'
            " 1) }"
        ),
        (
            '{ f(a: 1) f(a: 2) f(b: [1]) f(b: [1, 2]) f(c: "x") f(c: """x""")'
            " f(a: 1, b: [1]) f(a: 1) @x f(a: 1) @y f(b: 1) }"
        ),
    )


def test_deduplicate_values() raises:
    _dedupe(
        (
            "{ f(a: $v) f(a: $v) f(a: $w) f(a: true) f(a: true) f(a: false)"
            " f(a: null) f(a: null) f(a: E) f(a: E) f(a: {x: 1}) f(a: {x: 1})"
            " f(a: {y: 1}) f(a: {x: 2}) f(a: {x: 1, y: 2}) f(a: [1]) f(a: [2])"
            ' f(a: 1.5) f(a: 1.5) f(a: "1") f(a: """y""") f(a: """y""") }'
        ),
        (
            "{ f(a: $v) f(a: $w) f(a: true) f(a: false) f(a: null) f(a: E)"
            " f(a: {x: 1}) f(a: {y: 1}) f(a: {x: 2}) f(a: {x: 1, y: 2}) f(a:"
            ' [1]) f(a: [2]) f(a: 1.5) f(a: "1") f(a: """y""") }'
        ),
    )


def test_deduplicate_directives_and_aliases() raises:
    _dedupe("{ g @x @y g @y @x g @x @x }", "{ g @x @y g @x @x }")
    _dedupe("{ a: g g a: g }", "{ a: g g }")
    _dedupe(
        "{ person { name } person { name } }",
        "{ person { name } person { name } }",
    )
    _dedupe(
        "{ g(a: 1) @x(b: 1) g(a: 1) @x(b: 2) }",
        "{ g(a: 1) @x(b: 1) g(a: 1) @x(b: 2) }",
    )


def test_self_aliasing_in_fragments() raises:
    run(
        self_aliasing_pass,
        SCHEMA,
        "{ g: g person { name: name } } fragment F on Query { g: g h: g }",
        "{ g person { name } } fragment F on Query { g h: g }",
    )


def test_remove_fragment_definitions() raises:
    run(
        remove_fragments_pass,
        SCHEMA,
        (
            "{ person { ... on Person { ...A ...A } } } fragment A on Person"
            " { ...B } fragment B on Person { name } fragment C on Query { g }"
        ),
        (
            "{ person { ... on Person { ...A ...A } } } fragment A on Person {"
            " ...B }"
        ),
    )


def test_include_skip_variables() raises:
    run_with_variables(
        directive_include_skip_pass,
        SCHEMA,
        "{ g @skip(if: $s) f @include(if: $i) }",
        "{ f @include(if: $i) }",
        '{"s":true,"i":"no"}',
    )
    run_with_variables(
        directive_include_skip_pass,
        SCHEMA,
        "{ g @skip(if: $s) f @include(if: $i) }",
        "{ g f }",
        '{"s":false,"i":true}',
    )


def test_include_skip_default_values() raises:
    run(
        directive_include_skip_pass,
        SCHEMA,
        (
            "fragment X on Query { g } query ($s: Boolean = true, $t: Boolean ="
            " 1, $u: Boolean) { g @skip(if: $s) f @skip(if: $t) person"
            " @skip(if: $u) { name } }"
        ),
        (
            "fragment X on Query { g } query ($s: Boolean = true, $t: Boolean ="
            " 1, $u: Boolean) { f person @skip(if: $u) { name } }"
        ),
    )


def test_include_skip_unknown_conditions() raises:
    run(
        directive_include_skip_pass,
        SCHEMA,
        (
            "{ g @skip(if: true, extra: 1) f @skip(other: true) h @skip(if:"
            ' "s") i @skip j @x }'
        ),
        (
            "{ g @skip(if: true, extra: 1) f @skip(other: true) h @skip(if:"
            ' "s") i @skip j @x }'
        ),
    )


def test_include_skip_removes_once() raises:
    run(
        directive_include_skip_pass,
        SCHEMA,
        "{ person { name @skip(if: true) @include(if: false) } }",
        "{ person { __internal_typename: __typename } }",
    )


def test_include_skip_on_other_nodes() raises:
    run(
        directive_include_skip_pass,
        SCHEMA,
        (
            "query Q($a: Int @include(if: true)) @skip(if: true) @include(if:"
            " true) { g } fragment F on Query @skip(if: true) { g }"
        ),
        (
            "query Q($a: Int) @skip(if: true) { g } fragment F on Query"
            " @skip(if: true) { g }"
        ),
    )


def test_include_skip_selections() raises:
    run(
        directive_include_skip_pass,
        SCHEMA,
        (
            "{ ... on Query @include(if: false) { g } ...F @skip(if: true) f(a:"
            " $x, b: [$y, {z: $z}]) } fragment F on Query { g }"
        ),
        "{ f(a: $x, b: [$y, {z: $z}]) } fragment F on Query { g }",
    )


def test_keep_nodes() raises:
    run(
        keep_nodes_pass,
        SCHEMA,
        "{ g @skip(if: true) f @include(if: false) }",
        "{ g f }",
    )


def test_fragment_cycles() raises:
    run_error(
        directive_include_skip_pass,
        SCHEMA,
        "{ ...A } fragment A on Query { ...B } fragment B on Query { ...A }",
        "fragment spread: A forms fragment cycle",
    )
    run_error(
        directive_include_skip_pass,
        SCHEMA,
        "fragment A on Query { g ...A }",
        "fragment spread: A forms fragment cycle",
    )
    run_error(
        directive_include_skip_pass,
        SCHEMA,
        (
            "fragment A on Query { person { ... on Person { ...B } } } fragment"
            " B on Query { ...A @skip(if: true) }"
        ),
        "fragment spread: A forms fragment cycle",
    )


def test_fragments_without_cycles() raises:
    var chain = (
        "fragment A on Query { ...Z ...B ...C } fragment B on Query { ...D }"
        " fragment C on Query { ...D } fragment D on Query { ...E } fragment E"
        " on Query { g }"
    )
    run(directive_include_skip_pass, SCHEMA, chain, chain.copy())
    var lone = "fragment A on Query { ...B } fragment B on Query { g }"
    run(directive_include_skip_pass, SCHEMA, lone, lone.copy())


def test_unknown_types() raises:
    run_error(
        directive_include_skip_pass,
        SCHEMA,
        "fragment A on Missing { g }",
        'Unknown type "Missing".',
    )
    run_error(
        directive_include_skip_pass,
        SCHEMA,
        "{ ... on Missing { g } }",
        'Unknown type "Missing".',
    )
    run_error(
        directive_include_skip_pass,
        SCHEMA,
        "mutation { g }",
        (
            "operation type mutation is not defined; did you forget to merge"
            " the base schema?"
        ),
    )


def test_delete_unused_variables() raises:
    """Checked against `NewWithOpts(WithRemoveUnusedVariables())` of upstream:
    the deletion at the end of the operation has not seen the fragment yet."""
    run_vars(
        delete_unused_pass,
        SCHEMA,
        (
            "query Q($a: Int, $b: Int, $c: Int) { f(a: $a) ...F } fragment F"
            " on Query { f(b: $b) }"
        ),
        (
            "query Q($a: Int, $c: Int) { f(a: $a) ...F } fragment F on Query {"
            " f(b: $b) }"
        ),
        '{"a":1,"b":2,"c":3}',
        '{"a":1,"c":3}',
    )


def test_spread_on_scalar() raises:
    _spread("g", "Person", False)
    _spread("g", "Named", False)
    run(
        fragment_spread_inline_pass,
        SCHEMA,
        "{ unknown { x { ...F } } } fragment F on Person { name }",
        "{ unknown { x { ...F } } } fragment F on Person { name }",
    )


def test_fragment_with_nested_spread_target() raises:
    var text = (
        "fragment A on Query { ...B } fragment B on Query { person { ...C } }"
        " fragment C on Person { name }"
    )
    run(directive_include_skip_pass, SCHEMA, text, text.copy())


def test_type_definitions_in_the_operation_document() raises:
    var text = "type X { a: Int } { g }"
    run(directive_include_skip_pass, SCHEMA, text, text.copy())
    run(inline_selections_pass, SCHEMA, text, text.copy())
    run_vars(default_values_pass, SCHEMA, text, text.copy(), "", "")


def test_delete_unused_keeps_directive_variables() raises:
    run_vars(
        delete_unused_pass,
        SCHEMA,
        "query Q($a: Boolean) { g @include(if: $a) }",
        "query Q($a: Boolean) { g @include(if: $a) }",
        "",
        "",
    )


def test_deduplicate_lengths_and_defer() raises:
    _dedupe(
        "{ f(a: [1, 2]) f(a: [1]) f(a: {x: 1, y: 2}) f(a: {x: 1}) }",
        "{ f(a: [1, 2]) f(a: [1]) f(a: {x: 1, y: 2}) f(a: {x: 1}) }",
    )
    _dedupe(
        "{ g @__defer_internal(id: 2) g @__defer_internal(id: 1) }",
        "{ g @__defer_internal(id: 1) }",
    )


def test_normalizer_without_options() raises:
    var schema = schema_of(SCHEMA)
    var document = parse(
        "{ g g person { ...F } } fragment F on Person { name }"
    )
    var variables = String()
    OperationNormalizer(NormalizerOptions()).normalize_operation(
        document, schema, variables
    )
    assert_equal(
        print_ast(document),
        printed("{ g person { ...F } } fragment F on Person { name }"),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
