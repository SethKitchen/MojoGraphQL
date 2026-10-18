# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The Mojo writer: literals, layout, conditions, and the code of unusual
schemas and operations.

The generated module has no upstream counterpart, so these tests check
the rules that keep it valid Mojo that `mojo format` keeps as it is.
`test_generated.mojo` compiles and runs a whole generated module.
"""

from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from gql_language.ast import NO_NODE, Role
from gql_language.parser import parse

from gql_codegen.compiler import CodegenDocument, build_codegen_schema, compile
from gql_codegen.ir import ConditionKind, ConditionNode, Conditions, IrType
from gql_codegen.ir_builder import build_ir
from gql_codegen.issues import serialize
from gql_codegen.mojo_codegen import (
    _Generator,
    _Out,
    _escaped,
    _mojo_string,
    _moved,
    _pieces,
    generate_mojo,
)
from gql_codegen.options import CodegenOptions
from gql_schema.definition import TypeKind


def test_literals() raises:
    assert_equal(_mojo_string(""), '""')
    assert_equal(_mojo_string('a"b'), "'a\"b'")
    assert_equal(_mojo_string("it's"), '"it\'s"')
    assert_equal(_mojo_string("\"'"), '"\\"\'"')
    assert_equal(
        _mojo_string("a\\b\n\t\r\x01\x7f"), '"a\\\\b\\n\\t\\r\\x01\\x7f"'
    )
    assert_equal(_escaped(UInt8(ord("'")), UInt8(ord("'"))), "\\'")
    assert_equal(_escaped(UInt8(ord("x")), UInt8(ord('"'))), "x")


def test_pieces() raises:
    # A piece fits its line, and breaks before a space when the rest fits.
    var pieces = _pieces("aaaa bbbb cccc", 0, 9)
    assert_equal(len(pieces), 3)
    assert_equal(pieces[0], "aaaa")
    assert_equal(pieces[1], " bbbb")
    assert_equal(pieces[2], " cccc")
    # Without a space, a piece breaks where it is full.
    var long = _pieces("abcdefgh", 2, 6)
    assert_equal(long[0], "abcd")
    assert_equal(long[1], "ef")
    # A UTF-8 sequence stays whole.
    var wide = _pieces("ééé", 0, 3)
    assert_equal(wide[0], "é")
    assert_equal(len(wide), 3)
    assert_equal(len(_pieces("", 0, 80)), 1)
    # A character wider than the room is a piece of its own.
    assert_equal(_pieces("é", 0, 1)[0], "é")
    # A space too early to carry the rest is not a break.
    var early = _pieces("a bcdefg", 0, 7)
    assert_equal(early[0], "a bcdef")
    assert_equal(early[1], "g")


def test_layout() raises:
    var out = _Out()
    out.line(4, "")
    out.blank()
    out.call(0, "f(", ["a", "b"])
    out.call(
        0,
        "a_very_long_function_name_that_takes_much_room(",
        ["x" * 30, "y" * 30],
    )
    var many = List[String]()
    for index in range(8):
        many.append("argument_number_" + String(index))
    out.call(4, "g(", many)
    out.docstring(4, "short")
    out.docstring(4, "w" * 90 + " tail")
    out.docstring(0, "x" * 76 + " " + "y" * 76)
    out.docstring(0, "z" * 79)
    out.string(4, "comptime A = ", "short")
    out.string(4, "comptime B = ", "word " * 30)
    var text = out^.take()
    assert_true(text.startswith("\n\nf(a, b)\n"))
    assert_true(
        "a_very_long_function_name_that_takes_much_room(\n    " + "x" * 30
        in text
    )
    assert_true("    g(\n        argument_number_0,\n" in text)
    assert_true('    """short"""\n' in text)
    assert_true('    """' + "w" * 90 + "\n    tail" + '"""' in text)
    assert_true("\n" + "y" * 76 + '"""\n' in text)
    assert_true('"""' + "z" * 79 + '\n"""\n' in text)
    assert_true('    comptime A = "short"\n' in text)
    assert_true("    comptime B = (\n" in text)
    assert_true('\n        + "' in text)
    for line in text.split("\n"):
        if not "w" * 90 in line and not "z" * 79 in line:
            assert_true(line.byte_length() <= 80, String(line))


def test_moved() raises:
    var int = IrType("Int", TypeKind.SCALAR, "", 0, 0, False)
    assert_equal(_moved("x", int, 0, True), "x")
    assert_equal(_moved("x", int.with_nullable(True), 0, True), "x^")
    assert_equal(_moved("x", int.with_nullable(True), 0, False), "x")
    var enum = IrType("E", TypeKind.ENUM, "", 0, 0, False)
    assert_equal(_moved("x", enum, 0, True), "x")
    var text = IrType("String", TypeKind.SCALAR, "", 0, 0, False)
    assert_equal(_moved("x", text, 0, True), "x^")
    var model = IrType("Hero", TypeKind.OBJECT, "m", 0, 0, False)
    assert_equal(_moved("x", model, 0, True), "x^")
    var floats = IrType("Float", TypeKind.SCALAR, "", 1, 0, False)
    assert_equal(_moved("x", floats, 0, True), "x^")
    assert_equal(_moved("x", floats, 1, True), "x")
    var flag = IrType("Boolean", TypeKind.SCALAR, "", 0, 0, False)
    assert_equal(_moved("x", flag, 0, True), "x")


def test_conditions() raises:
    var generator = _Generator(CodegenOptions())
    var conditions = Conditions()
    assert_equal(generator.condition(0, conditions, Conditions.TRUE), "True")
    assert_equal(generator.condition(0, conditions, Conditions.FALSE), "False")
    assert_equal(
        generator.condition(0, conditions, conditions.label(None)), "True"
    )
    var a = conditions.variable("a")
    var single = conditions.and_([a])
    var either = conditions.or_([a, conditions.not_(conditions.variable("b"))])
    var types = conditions.possible_types(List[String]())
    _ = generator.condition(4, conditions, single)
    _ = generator.condition(4, conditions, either)
    _ = generator.condition(4, conditions, types)
    conditions.nodes.append(ConditionNode(ConditionKind(9), [], "", False, []))
    with assert_raises(contains="invalid condition kind"):
        _ = generator.condition(0, conditions, len(conditions.nodes) - 1)
    with assert_raises(contains="no struct for the model nope"):
        _ = generator.named_type(
            IrType("Hero", TypeKind.OBJECT, "nope", 0, 0, False)
        )
    var text = generator^.take()
    assert_true("    var c" in text)
    assert_true(" or " in text)
    assert_true("_is_one_of(typename)" in text)


comptime ODD = """
enum Empty
input Nothing
interface Lonely { name: String }
type Item { name: String Count: Int flag: Boolean }
type Query {
  item(flags: [Boolean], flag: Boolean, empty: Empty, nothing: Nothing): Item
  lonely: Lonely
}
"""


def odd(
    text: String, options: CodegenOptions = CodegenOptions()
) raises -> String:
    """Compile a document against `ODD`, built without the schema check."""
    var schema = build_codegen_schema(ODD, check=False)
    var documents = List[CodegenDocument]()
    documents.append(CodegenDocument("odd.graphql", text))
    var result = compile(schema, documents, options)
    assert_equal(serialize(result.errors), "")
    return result.source.copy()


def test_unusual_schemas() raises:
    var source = odd(
        "query A($flags: [Boolean], $e: Empty, $n: Nothing) { item(flags:"
        " $flags, empty: $e, nothing: $n) { name } }"
    )
    assert_true("comptime UNKNOWN__ = Empty(0)" in source)
    assert_true("struct Nothing(Copyable, Movable):" in source)
    var options = CodegenOptions()
    options.generate_optional_operation_variables = False
    var plain = odd(
        "query B($flag: Boolean) { item(flag: $flag) { name } }", options
    )
    assert_true("if not self.flag.or_else(True):" in plain)


def test_unusual_operations() raises:
    var options = CodegenOptions()
    options.decapitalize_fields = True
    var source = odd(
        "query C { item { Count ... on Item @include(if: false) { name } } }",
        options,
    )
    assert_true("var count: Optional[Int]" in source)
    assert_true("if False:" in source)
    var introspection = odd("query D { __schema { types { name } } }")
    assert_false("struct __Schema" in introspection)
    var fragments_only = odd("fragment F on Item { name }")
    assert_true("struct F(Copyable, Movable):" in fragments_only)
    assert_false("_Variables" in fragments_only)


def test_empty_model() raises:
    var schema = build_codegen_schema(ODD, check=False)
    var document = parse("query E { item { name } }")
    var operation = document.definitions()[0]
    var root = document.child(operation, Role.SELECTION_SET)
    var item = document.first_child(root)
    var selection_set = document.child(item, Role.SELECTION_SET)
    document.nodes[selection_set].first = NO_NODE
    document.nodes[selection_set].last = NO_NODE
    var ir = build_ir(document, schema, CodegenOptions())
    var source = generate_mojo(ir, schema, CodegenOptions())
    assert_true("        return Self()\n" in source)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
