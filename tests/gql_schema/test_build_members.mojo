# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for how `gql_schema.build` places members, beyond the upstream
suites.

graphql-js keeps a type's fields, a field's arguments, an input object's
fields and an enum's values in JavaScript objects: a repeated name keeps
its first place and takes the last value. SDL validation refuses repeated
names, so these cases build with `assume_valid_sdl`. Each expected text is
the output of graphql-js 16.14.2 `printSchema(buildSchema(sdl,
{ assumeValidSDL: true }))`.

The cases also cover owners with at least `HASHED_MEMBERS` members, whose
names are in a name table, and extensions that move members.
"""

from _helpers import dedent
from gql_language.parser import parse
from gql_schema.build import BuildOptions, build_schema, extend_schema
from gql_schema.definition import NO_TYPE
from gql_schema.print import print_schema
from std.testing import TestSuite, assert_equal, assert_true


def many(prefix: String, suffix: String, count: Int) -> String:
    """Return `count` lines `  <prefix><i><suffix>`, joined by line feeds."""
    var out = String("")
    for index in range(count):
        if index > 0:
            out += "\n"
        out += "  " + prefix + String(index) + suffix
    return out^


def build_unchecked(sdl: String) raises -> String:
    """Build with `assume_valid_sdl` and print the schema."""
    var options = BuildOptions()
    options.assume_valid_sdl = True
    return print_schema(build_schema(sdl, options))


def test_repeated_scan_field() raises:
    assert_equal(
        build_unchecked("type Query {\n  a: String\n  b: String\n  a: Int\n}"),
        """type Query {
  a: Int
  b: String
}""",
    )


def test_repeated_hash_field() raises:
    assert_equal(
        build_unchecked(
            "type Query {\n" + many("f", ": String", 20) + "\n  f3: Int\n}"
        ),
        """type Query {
  f0: String
  f1: String
  f2: String
  f3: Int
  f4: String
  f5: String
  f6: String
  f7: String
  f8: String
  f9: String
  f10: String
  f11: String
  f12: String
  f13: String
  f14: String
  f15: String
  f16: String
  f17: String
  f18: String
  f19: String
}""",
    )


def test_repeated_scan_arg() raises:
    assert_equal(
        build_unchecked(
            "type Query {\n  a(x: Int, y: Int, x: String): String\n}"
        ),
        """type Query {
  a(x: String, y: Int): String
}""",
    )


def test_repeated_hash_arg() raises:
    assert_equal(
        build_unchecked(
            "type Query {\n  a(\n"
            + many("x", ": Int", 20)
            + "\n  x4: String): String\n}"
        ),
        """type Query {
  a(x0: Int, x1: Int, x2: Int, x3: Int, x4: String, x5: Int, x6: Int, x7: Int, x8: Int, x9: Int, x10: Int, x11: Int, x12: Int, x13: Int, x14: Int, x15: Int, x16: Int, x17: Int, x18: Int, x19: Int): String
}""",
    )


def test_repeated_replaced_field() raises:
    assert_equal(
        build_unchecked(
            "type Query {\n  a(\n"
            + many("x", ": Int", 20)
            + "\n  ): String\n  a(x5: String): Int\n}"
        ),
        """type Query {
  a(x5: String): Int
}""",
    )


def test_repeated_scan_input() raises:
    assert_equal(
        build_unchecked(
            "input I {\n  a: Int\n  b: Int\n  a: String\n}\ntype Query { f(i:"
            " I): Int }"
        ),
        """input I {
  a: String
  b: Int
}

type Query {
  f(i: I): Int
}""",
    )


def test_repeated_hash_input() raises:
    assert_equal(
        build_unchecked(
            "input I {\n"
            + many("i", ": Int", 20)
            + "\n  i7: String\n}\ntype Query { f(i: I): Int }"
        ),
        """input I {
  i0: Int
  i1: Int
  i2: Int
  i3: Int
  i4: Int
  i5: Int
  i6: Int
  i7: String
  i8: Int
  i9: Int
  i10: Int
  i11: Int
  i12: Int
  i13: Int
  i14: Int
  i15: Int
  i16: Int
  i17: Int
  i18: Int
  i19: Int
}

type Query {
  f(i: I): Int
}""",
    )


def test_repeated_scan_enum() raises:
    assert_equal(
        build_unchecked("enum E {\n  A\n  B\n  A\n}\ntype Query { e: E }"),
        """enum E {
  A
  B
}

type Query {
  e: E
}""",
    )


def test_repeated_hash_enum() raises:
    assert_equal(
        build_unchecked(
            "enum E {\n" + many("V", "", 20) + "\n  V2\n}\ntype Query { e: E }"
        ),
        """enum E {
  V0
  V1
  V2
  V3
  V4
  V5
  V6
  V7
  V8
  V9
  V10
  V11
  V12
  V13
  V14
  V15
  V16
  V17
  V18
  V19
}

type Query {
  e: E
}""",
    )


def test_repeated_redefined() raises:
    assert_equal(
        build_unchecked(
            "type Foo {\n  a: Int\n}\ntype Query {\n  foo: Foo\n}\ntype Foo {\n"
            "  b: Int\n}"
        ),
        """type Foo {
  b: Int
}

type Query {
  foo: Foo
}""",
    )


def test_extension_crosses_into_a_name_table() raises:
    # 15 fields, then 3 more: the 16th puts every name in the table.
    var schema = build_schema(
        "type Query {\n" + many("f", ": String", 15) + "\n}"
    )
    var extended = extend_schema(
        schema, parse("extend type Query {\n" + many("g", ": Int", 3) + "\n}")
    )
    var query = extended.type_named("Query")
    assert_equal(extended.fields[extended.field_named(query, "f0")].name, "f0")
    assert_equal(extended.fields[extended.field_named(query, "g2")].name, "g2")
    assert_equal(extended.field_named(query, "nope"), NO_TYPE)


def test_extension_moves_hashed_members() raises:
    var schema = build_schema(
        "type Query {\n"
        + many("f", ": String", 20)
        + "\n  wide(\n"
        + many("a", ": Int", 20)
        + "\n  ): String\n}\nenum E {\n"
        + many("V", "", 20)
        + "\n}\ninput I {\n"
        + many("i", ": Int", 20)
        + "\n}"
    )
    var extended = extend_schema(
        schema,
        parse(
            "extend type Query {\n  extra: Int\n}\nextend enum E {\n "
            " EXTRA\n}\nextend input I {\n  extra: Int\n}"
        ),
    )
    var query = extended.type_named("Query")
    var wide = extended.field_named(query, "wide")
    assert_equal(extended.fields[wide].name, "wide")
    assert_equal(
        extended.input_values[extended.argument_named(wide, "a19")].name, "a19"
    )
    assert_equal(
        extended.fields[extended.field_named(query, "extra")].name, "extra"
    )
    var enum_type = extended.type_named("E")
    assert_equal(
        extended.enum_values[extended.enum_value_named(enum_type, "V0")].name,
        "V0",
    )
    assert_true(extended.enum_value_named(enum_type, "EXTRA") != NO_TYPE)
    var input = extended.type_named("I")
    assert_equal(
        extended.input_values[extended.input_field_named(input, "i5")].name,
        "i5",
    )
    assert_true(extended.input_field_named(input, "extra") != NO_TYPE)


def test_enum_value_with_another_directive() raises:
    var schema = build_schema(
        "directive @tag on ENUM_VALUE\nenum E {\n  A @tag\n}\ntype Query {\n "
        " e: E\n}"
    )
    var enum_type = schema.type_named("E")
    ref value = schema.enum_values[schema.enum_value_named(enum_type, "A")]
    assert_equal(value.directives.count, 1)
    assert_true(not value.is_deprecated)


def test_schema_extension_without_operations() raises:
    var schema = build_schema(
        "schema {\n  query: Q\n}\nextend schema @foo\ndirective @foo on"
        " SCHEMA\ntype Q"
    )
    assert_equal(schema.types[Int(schema.query_type)].name, "Q")
    assert_equal(schema.schema_extensions.count, 1)
    assert_equal(schema.schema_directives.count, 1)


def test_directive_reason_from_the_first_deprecating_extension() raises:
    var options = BuildOptions()
    options.parse_options.experimental_directives_on_directive_definitions = (
        True
    )
    options.assume_valid_sdl = True
    var schema = build_schema(
        dedent(
            """
      directive @tag on DIRECTIVE_DEFINITION
      directive @kept @deprecated(reason: "own") on FIELD
      directive @later on FIELD
      extend directive @kept @deprecated(reason: "ignored")
      extend directive @later @tag
      extend directive @later @deprecated(reason: "second")
      extend directive @later @deprecated(reason: "third")
    """
        ),
        options,
    )
    ref kept = schema.directives[schema.directive_named("kept")]
    assert_equal(kept.deprecation_reason, "own")
    assert_equal(kept.extensions.count, 1)
    ref later = schema.directives[schema.directive_named("later")]
    assert_equal(later.deprecation_reason, "second")
    assert_equal(later.extensions.count, 3)


def test_extension_deprecates_a_directive_once() raises:
    var options = BuildOptions()
    options.parse_options.experimental_directives_on_directive_definitions = (
        True
    )
    options.assume_valid_sdl = True
    var schema = build_schema("directive @foo on FIELD")
    var extended = extend_schema(
        schema,
        parse(
            (
                "directive @tag on DIRECTIVE_DEFINITION\nextend directive @foo"
                ' @tag\nextend directive @foo @deprecated(reason: "a")\nextend'
                ' directive @foo @deprecated(reason: "b")'
            ),
            options.parse_options,
        ),
        options,
    )
    ref foo = extended.directives[extended.directive_named("foo")]
    assert_equal(foo.deprecation_reason, "a")
    assert_equal(foo.extensions.count, 3)


def expect_build_error(sdl: String, message: String) raises:
    """Assert that building SDL with `assume_valid_sdl` raises a message."""
    try:
        _ = build_unchecked(sdl)
    except error:
        assert_equal(String(error), message)
        return
    raise Error("expected an error")


def test_directive_values_as_get_argument_values() raises:
    # The messages of graphql-js `getArgumentValues`, which runs when the
    # SDL validation is off.
    expect_build_error(
        "scalar S @specifiedBy\ntype Query {\n  s: S\n}",
        'Argument "url" of required type "String!" was not provided.',
    )
    expect_build_error(
        "scalar S @specifiedBy(url: 1)\ntype Query {\n  s: S\n}",
        'Argument "url" has invalid value 1.',
    )
    expect_build_error(
        "scalar S @specifiedBy(url: null)\ntype Query {\n  s: S\n}",
        'Argument "url" of non-null type "String!" must not be null.',
    )
    expect_build_error(
        "type Query {\n  a: Int @deprecated(reason: 1)\n}",
        'Argument "reason" has invalid value 1.',
    )
    expect_build_error(
        "type Query {\n  a: Int @deprecated(reason: ENUM)\n}",
        'Argument "reason" has invalid value ENUM.',
    )
    var options = BuildOptions()
    options.assume_valid_sdl = True
    var schema = build_schema(
        'scalar S @specifiedBy(foo: "x", url: "u")\ntype Query {\n  s: S\n}',
        options,
    )
    assert_equal(schema.types[schema.type_named("S")].specified_by_url, "u")


def test_null_deprecation_reason() raises:
    # graphql-js: `reason: null` gives no deprecation reason.
    var options = BuildOptions()
    options.assume_valid_sdl = True
    var schema = build_schema(
        "type Query {\n  a: Int @deprecated(reason: null)\n}", options
    )
    var query = schema.type_named("Query")
    assert_true(not schema.fields[schema.field_named(query, "a")].is_deprecated)


def test_syntax_error() raises:
    try:
        _ = build_schema("type")
    except error:
        # The text is graphql-js `String(error)`: the message, then where.
        assert_true(
            String(error).startswith(
                "Syntax Error: Expected Name, found <EOF>.\n\nGraphQL"
                " request:1:5"
            )
        )
        return
    raise Error("expected an error")


def test_input_object_with_another_directive() raises:
    var schema = build_schema(
        "directive @foo on INPUT_OBJECT | ARGUMENT_DEFINITION\ninput I @foo {\n"
        "  a: Int\n}\ntype Query {\n  f(i: I @foo): Int\n}"
    )
    ref input = schema.types[schema.type_named("I")]
    assert_true(not input.is_one_of)
    var query = schema.type_named("Query")
    var field = schema.field_named(query, "f")
    ref argument = schema.input_values[schema.argument_named(field, "i")]
    assert_equal(argument.directives.count, 1)
    assert_true(not argument.is_deprecated)


def test_extension_redefines_and_adds_types() raises:
    # graphql-js 16.14.2, with `assumeValidSDL`: the second `New` replaces
    # the first, and the new types point at each other.
    var options = BuildOptions()
    options.assume_valid_sdl = True
    var schema = build_schema(
        "type Foo {\n  a: Int\n}\ntype Query {\n  foo: Foo\n}"
    )
    var extended = extend_schema(
        schema,
        parse(
            "type Foo {\n  b: Bar\n}\ntype Bar {\n  baz(i: In): Baz\n}\ninput"
            " In {\n  x: Int\n}\ntype Baz {\n "
            " x: Int\n}\nunion U = Bar\ntype New {\n  a: Int\n}\ntype New {\n "
            " b: Int\n}"
        ),
        options,
    )
    assert_equal(
        print_schema(extended),
        dedent(
            """
      type Foo {
        b: Bar
      }

      type Query {
        foo: Foo
      }

      type Bar {
        baz(i: In): Baz
      }

      input In {
        x: Int
      }

      type Baz {
        x: Int
      }

      union U = Bar

      type New {
        b: Int
      }
    """
        ),
    )


def test_directive_extended_twice() raises:
    var options = BuildOptions()
    options.parse_options.experimental_directives_on_directive_definitions = (
        True
    )
    var schema = build_schema(
        (
            "directive @tag on DIRECTIVE_DEFINITION\ndirective @foo on FIELD\n"
            "extend directive @foo @tag"
        ),
        options,
    )
    var extended = extend_schema(
        schema,
        parse(
            'extend directive @foo @deprecated(reason: "now")',
            options.parse_options,
        ),
    )
    ref foo = extended.directives[extended.directive_named("foo")]
    assert_equal(foo.extensions.count, 2)
    assert_equal(foo.deprecation_reason, "now")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
