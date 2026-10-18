# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The parts of the IR: conditions, types, used coordinates, the schema
relations and the printer.

Ports the rules of Apollo Kotlin `ir/BooleanExpression.kt` `simplify` and
`toName`, of `UsedCoordinates.kt` and of `apollo-ast` `SDLWriter.kt` for
the cases that the compiler tests do not reach.
"""

from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from gql_language.parser import parse
from gql_schema.definition import NO_TYPE, TypeKind

from gql_codegen.compiler import build_codegen_schema
from gql_codegen.ir import (
    ConditionKind,
    Conditions,
    IrType,
    UsedCoordinates,
)
from gql_codegen.printer import _Writer, print_executable
from gql_codegen.schema_util import (
    field_type,
    is_abstract,
    is_object,
    is_sub_type_of,
    possible_types,
)


def test_condition_kinds() raises:
    assert_true(ConditionKind.POSSIBLE_TYPES.is_valid())
    assert_false(ConditionKind(8).is_valid())
    assert_equal(String(ConditionKind.OR), "ConditionKind(3)")


def test_simplify() raises:
    var c = Conditions()
    var a = c.variable("a")
    var b = c.variable("b")
    assert_equal(c.simplify(c.not_(Conditions.TRUE)), Conditions.FALSE)
    assert_equal(c.simplify(c.not_(Conditions.FALSE)), Conditions.TRUE)
    var not_a = c.not_(a)
    assert_equal(c.simplify(not_a), not_a)
    assert_equal(c.simplify(a), a)
    assert_equal(c.simplify(c.or_([a, Conditions.TRUE])), Conditions.TRUE)
    assert_equal(c.simplify(c.or_([Conditions.FALSE])), Conditions.FALSE)
    assert_equal(c.simplify(c.or_([a, Conditions.FALSE])), a)
    assert_equal(c.simplify(c.and_([a, Conditions.FALSE])), Conditions.FALSE)
    assert_equal(c.simplify(c.and_([Conditions.TRUE])), Conditions.TRUE)
    var both = c.simplify(c.and_([a, b, Conditions.TRUE]))
    assert_equal(both, c.and_([b, a]))
    assert_equal(c.key(both), "&(v:a,v:b)")
    # Upstream drops `False` before it simplifies, so a `Not(True)` stays
    # in an `Or` and simplifies to `False`.
    assert_equal(c.simplify(c.or_([c.not_(Conditions.TRUE)])), Conditions.FALSE)
    with assert_raises(contains="cannot create a 'Or' condition"):
        _ = c.or_(List[Int]())
    with assert_raises(contains="cannot create a 'And' condition"):
        _ = c.and_(List[Int]())


def test_keys_and_names() raises:
    var c = Conditions()
    var a = c.variable("a")
    var types = c.possible_types(["Human", "Droid"])
    assert_equal(c.key(types), "p:Droid,Human")
    assert_equal(c.possible_types(["Droid", "Human"]), types)
    assert_equal(c.key(c.label("first")), "l:first")
    assert_equal(c.key(c.label(None)), "l")
    assert_equal(c.label(None), c.label(None))
    assert_equal(c.key(Conditions.TRUE), "T")
    assert_equal(c.key(Conditions.FALSE), "F")
    assert_equal(c.key(c.or_([a, c.not_(a)])), "|(!(v:a),v:a)")
    assert_equal(c.to_name(Conditions.TRUE), "True")
    assert_equal(c.to_name(Conditions.FALSE), "False")
    assert_equal(c.to_name(c.and_([a, c.not_(c.variable("b"))])), "AAndNotB")
    assert_equal(c.to_name(c.or_([a, c.variable("c")])), "AOrC")
    var deferred = c.or_([c.not_(a), c.label("x")])
    assert_equal(c.first_label(deferred), c.label("x"))
    assert_equal(c.first_label(a), -1)


def test_ir_types() raises:
    var type = IrType("Episode", TypeKind.ENUM, "", 1, 0b11, False)
    assert_true(type.is_list())
    assert_true(type.is_nullable(1))
    assert_equal(type.text(), "[Episode]")
    assert_equal(type.with_nullable(False).text(), "[Episode]!")
    assert_equal(
        type.with_nullable(False).with_nullable(True).text(), "[Episode]"
    )
    assert_equal(type.with_optional(True).text(), "Optional<[Episode]>")
    var model = IrType("Hero", TypeKind.OBJECT, "", 0, 0, False)
    assert_equal(model.with_model("data.hero").text(), "data.hero!")
    assert_false(model.is_list())


def test_used_coordinates() raises:
    var empty = UsedCoordinates()
    assert_equal(empty.to_json(), '{\n    "typeToFieldsToArguments": {}\n}')
    assert_equal(len(empty.types()), 0)
    var used = UsedCoordinates()
    used.put_type("Query")
    used.put_argument("Query", "hero", "episode")
    used.put_argument("Query", "hero", "episode")
    used.put_argument("Query", "hero", "first")
    used.put_argument("Query", "search", "text")
    used.put_type("Hero")
    assert_true(used.has_type("Hero"))
    assert_false(used.has_type("Droid"))
    assert_equal(
        used.to_json(),
        (
            '{\n    "typeToFieldsToArguments": {\n        "Query": {\n'
            '            "hero": [\n                "episode",\n'
            '                "first"\n            ],\n            "search": [\n'
            '                "text"\n            ]\n        },\n'
            '        "Hero": {}\n    }\n}'
        ),
    )


def test_schema_relations() raises:
    var schema = build_codegen_schema(
        "interface A { x: Int } interface Unused { x: Int } type B implements"
        " A { x: Int } union U = B type Query { a: A b: B }"
    )
    var a = schema.type_named("A")
    var b = schema.type_named("B")
    var u = schema.type_named("U")
    var unused = schema.type_named("Unused")
    assert_true(is_sub_type_of(schema, b, a))
    assert_true(is_sub_type_of(schema, b, b))
    assert_true(is_sub_type_of(schema, b, u))
    assert_false(is_sub_type_of(schema, a, b))
    assert_equal(len(possible_types(schema, unused)), 0)
    assert_equal(possible_types(schema, b)[0], b)
    assert_true(is_abstract(schema, u))
    assert_false(is_abstract(schema, b))
    assert_true(is_object(schema, b))
    assert_false(is_object(schema, a))
    var query = Int(schema.query_type)
    assert_equal(Int(field_type(schema, NO_TYPE, "x").named), NO_TYPE)
    assert_equal(Int(field_type(schema, b, "nope").named), NO_TYPE)
    assert_equal(
        Int(field_type(schema, schema.type_named("Int"), "x").named), NO_TYPE
    )
    assert_true(field_type(schema, b, "__typename").is_non_null())
    assert_true(field_type(schema, query, "__schema").is_non_null())
    assert_false(field_type(schema, query, "__type").is_non_null())
    assert_equal(Int(field_type(schema, b, "__schema").named), NO_TYPE)
    assert_equal(Int(field_type(schema, query, "a").named), a)


def printed(text: String) raises -> String:
    """Print the first definition of a document."""
    var document = parse(text)
    return print_executable(document, document.definitions()[0])


def test_printer_values() raises:
    assert_equal(
        printed(
            'query Q($a: [ID!]! = ["x"], $b: In = {}, $c: Float = 1.5) @d(x:'
            ' {a: 1, b: [1, null]}) { f(s: "q\\"\\n", t: true, u: false, e:'
            " RED, v: $a, l: []) }"
        ),
        (
            'query Q($a: [ID!]! = ["x"] , $b: In = {\n\n}\n , $c: Float = 1.5 )'
            ' @d(x: {\n  a: 1\n  b: [1,null]\n}\n) {\n  f(s: "q\\"\\n", t:'
            " true, u: false, e: RED, v: $a, l: [])\n}\n"
        ),
    )
    assert_equal(
        printed("{ ... @include(if: true) { a } }"),
        "query {\n  ... @include(if: true) {\n    a\n  }\n}\n",
    )
    assert_equal(
        printed("fragment F on T @a @b { x: y @c ...G @d }"),
        "fragment F on T @a @b {\n  x: y @c\n  ...G @d\n}\n",
    )
    var writer = _Writer()
    writer.write("")
    assert_equal(writer^.take(), "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
