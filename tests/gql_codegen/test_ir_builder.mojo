# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The IR builder: the upstream `check` and `error` messages, the variable
types and defaults, and the names of conditional inline fragments.

`build_ir` expects a validated document. These tests also pass it
documents that validation refuses, to reach the messages that upstream
`IrOperationsBuilder.kt` raises with `check` and `error`.
"""

from std.testing import TestSuite, assert_equal, assert_raises, assert_true

from gql_language.ast import Document
from gql_language.parser import parse
from gql_schema.definition import Schema

from gql_codegen.compiler import CodegenDocument, build_codegen_schema, compile
from gql_codegen.ir import IrOperations
from gql_codegen.ir_builder import build_ir, const_json
from gql_codegen.issues import serialize
from gql_codegen.options import AddTypename, CodegenOptions

comptime SDL = """
directive @defer(label: String, if: Boolean! = true) on INLINE_FRAGMENT | FRAGMENT_SPREAD
interface Character { name: String }
interface Unimplemented { name: String }
type Droid implements Character { name: String id: ID }
input Filter { first: Int tags: [String] nested: Filter }
type Query { hero: Character droid(filter: Filter, n: Float, s: String, e: Kind, b: Boolean): Droid ghost: Unimplemented }
enum Kind { A B }
"""


def schema() raises -> Schema:
    """Build the test schema."""
    return build_codegen_schema(SDL)


def ir_of(
    text: String, options: CodegenOptions = CodegenOptions()
) raises -> IrOperations:
    """Build the IR of a document, without validation."""
    return build_ir(parse(text), schema(), options)


def test_upstream_errors() raises:
    with assert_raises(
        contains="wrong number of arguments for 'include' directive: 0"
    ):
        _ = ir_of("query A { hero @include { name } }")
    with assert_raises(contains="cannot pass \"x\" to 'skip' directive"):
        _ = ir_of('query A { hero @skip(if: "x") { name } }')
    with assert_raises(contains="duplicate @skip/@include directives"):
        _ = ir_of("query A { hero @include(if: $a) @include(if: $a) { name } }")
    with assert_raises(contains="cannot pass 1 to 'label' argument"):
        _ = ir_of("query A { hero { ... on Droid @defer(label: 1) { id } } }")
    with assert_raises(contains="cannot pass \"no\" to 'if' argument"):
        _ = ir_of('query A { hero { ... on Droid @defer(if: "no") { id } } }')
    with assert_raises(contains="cannot pass $l to 'label' argument"):
        _ = ir_of("query A { hero { ... on Droid @defer(label: $l) { id } } }")
    # An unknown argument of `@defer` is not read.
    var other = ir_of(
        "query A { hero { ... on Droid @defer(other: 1) { id } } }"
    )
    assert_equal(len(other.operations), 1)
    with assert_raises(contains="duplicate @defer directives"):
        _ = ir_of("query A { hero { ... on Droid @defer @defer { id } } }")
    with assert_raises(
        contains="cannot find field definition for field 'n' of type 'Droid'"
    ):
        _ = ir_of("query A { droid { n: nope { x } } }")
    with assert_raises(contains="cannot find fragment F"):
        _ = ir_of("query A { hero { ...F } }")
    with assert_raises(contains="cannot find fragment Missing"):
        _ = ir_of("fragment G on Character { ...Missing }")
    with assert_raises(contains="unknown type of variable '$v'"):
        _ = ir_of("query A($v: Nope) { hero { name } }")
    with assert_raises(contains="cannot find root type for 'mutation'"):
        _ = ir_of("mutation A { hero { name } }")
    with assert_raises(contains="Apollo doesn't support anonymous operation."):
        _ = ir_of("{ hero { name } }")


def test_fragment_cycle_ends() raises:
    # Validation refuses a cycle; the builder still ends.
    with assert_raises(contains="cannot find field definition"):
        _ = ir_of(
            "query A { hero { ...F } } fragment F on Character { ...F nope }"
        )


def test_empty_document() raises:
    var ir = build_ir(Document(), schema(), CodegenOptions())
    assert_equal(len(ir.operations), 0)
    assert_equal(len(ir.fragments), 0)


def test_inline_fragment_without_type_condition() raises:
    var ir = ir_of("query A { hero { ... { name } } }")
    ref hero = ir.models[ir.models[ir.operations[0].data_model].models[0]]
    assert_equal(hero.properties[0].info.response_name, "onCharacter")


def test_condition_names() raises:
    var ir = ir_of(
        "query A($a: Boolean!) { hero { __typename ... on Droid @defer { id }"
        " ... on Droid @defer(if: $a) { name } ... on Droid @include(if:"
        " false) { id } ... on Unimplemented { name } } }"
    )
    ref data = ir.models[ir.operations[0].data_model]
    ref hero = ir.models[data.models[0]]
    assert_equal(hero.properties[1].info.response_name, "onDroidDefer")
    # Without labels, upstream gives both the same name.
    assert_equal(hero.properties[2].info.response_name, "onDroidDefer")
    assert_equal(hero.properties[3].info.response_name, "onDroidIfFalse")


def test_fields_without_typename() raises:
    # `ifPolymorphic` adds no `__typename` where the fragments match every
    # value, so a model can have no field.
    var options = CodegenOptions()
    options.add_typename = AddTypename.IF_POLYMORPHIC
    var documents = List[CodegenDocument]()
    documents.append(
        CodegenDocument(
            "a.graphql",
            "query A { hero { ...C } } fragment C on Character { name }",
        )
    )
    var result = compile(schema(), documents, options)
    assert_equal(serialize(result.errors), "")
    ref data = result.ir.models[result.ir.operations[0].data_model]
    ref hero = result.ir.models[data.models[0]]
    assert_equal(len(hero.properties), 1)
    assert_equal(hero.properties[0].info.response_name, "c")


def test_variables() raises:
    var ir = ir_of(
        'query A($f: Filter = {first: 1, tags: ["a"], nested: {}}, $n: Float'
        ' = 1.5, $s: String = "x", $e: Kind = A, $b: Boolean = null, $l:'
        " [Int] = [], $r: Int!, $o: Int) { droid(filter: $f, n: $n, s: $s, e:"
        " $e, b: $b) { id } }"
    )
    ref variables = ir.operations[0].variables
    assert_equal(
        variables[0].default_json, '{"first":1,"tags":["a"],"nested":{}}'
    )
    assert_equal(variables[1].default_json, "1.5")
    assert_equal(variables[2].default_json, '"x"')
    assert_equal(variables[3].default_json, '"A"')
    assert_equal(variables[4].default_json, "null")
    assert_equal(variables[5].default_json, "[]")
    assert_equal(variables[6].type.text(), "Int!")
    assert_equal(variables[7].type.text(), "Optional<Int>")
    var options = CodegenOptions()
    options.generate_optional_operation_variables = False
    var plain = ir_of("query A($o: Int) { hero { name } }", options)
    assert_equal(plain.operations[0].variables[0].type.text(), "Int")
    var document = parse("query A { droid(n: 2) { id } }")
    assert_true(const_json(document, 0) != "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
