# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Input values as graphql-js holds them: coerced from literals, and
printed back.

Port of graphql-js 16.14.2 `utilities/valueFromAST.ts`,
`utilities/valueFromASTUntyped.ts`, `utilities/astFromValue.ts`,
`jsutils/inspect.ts`, the `parseLiteral` and `serialize` functions of
`type/scalars.ts` and of `GraphQLEnumType` in `type/definition.ts`, and the
number conversions of ECMAScript `Number.prototype.toString` and
`Number(string)`.

graphql-js keeps a default value as a JavaScript value, and prints it back
with `astFromValue`, so `Float = 1.23e4` prints as `12300` and an
out-of-range `Int` default prints as no default at all. `print_default`
gives the same text: it coerces the literal to a `JsValues` tree, as
`valueFromAST` does, then prints the tree as `astFromValue` and `print` do.

**Differences from graphql-js.**

- A custom scalar's `parseLiteral` and `serialize` are JavaScript
  functions there; here a custom scalar always behaves as one built from
  SDL, which uses `valueFromASTUntyped` and the identity. An enum value's
  internal value is always its name, as in a schema built from SDL.
- There are no variables: `value_from_ast` and `value_from_ast_untyped`
  behave as graphql-js does with no variable values, so every variable is
  missing.
- A `JsValues` tree has no functions, classes, `valueOf` or `toJSON`, and
  its objects have no prototype. An array given to `print_ast_from_value`
  for an input object type prints as `{}`; graphql-js also reads array
  properties such as `length` as input fields there.
"""

from std.math import isfinite, isnan, ldexp, nan, trunc
from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.block_string import print_string
from gql_language.error import GraphQLError, quote_json_string
from gql_language.printer import print_node
from gql_json.number import read_float64
from gql_schema.definition import NO_TYPE, Schema, TypeKind, TypeRef
from gql_schema.suggestions import did_you_mean, suggestion_list


@fieldwise_init
struct JsKind(Equatable, ImplicitlyCopyable, Writable):
    """The kind of a JavaScript value."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime UNDEFINED = JsKind(0)
    """`undefined`: no value, or an invalid one."""
    comptime NULL = JsKind(1)
    """`null`."""
    comptime BOOLEAN = JsKind(2)
    """A boolean."""
    comptime NUMBER = JsKind(3)
    """A number."""
    comptime STRING = JsKind(4)
    """A string."""
    comptime LIST = JsKind(5)
    """An array."""
    comptime OBJECT = JsKind(6)
    """An object with string keys, in insertion order."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the seven kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 6

    def write_to(self, mut writer: Some[Writer]):
        """Write the kind's name.

        Args:
            writer: The destination.
        """
        comptime names: Array[StaticString, 7] = [
            "undefined",
            "null",
            "boolean",
            "number",
            "string",
            "array",
            "object",
        ]
        if self.is_valid():
            writer.write(materialize[names]()[Int(self.value)])
        else:
            writer.write("<invalid>")


struct JsNode(Copyable, Movable):
    """One JavaScript value of a `JsValues` tree."""

    var kind: JsKind
    """What it is."""
    var number: Float64
    """A number's value."""
    var flag: Bool
    """A boolean's value."""
    var text: String
    """A string's value."""
    var items: List[Int]
    """An array's items, or an object's values, as node indices."""
    var keys: List[String]
    """An object's keys, one per item."""

    def __init__(out self, kind: JsKind):
        """Start an empty value of a kind.

        Args:
            kind: What it is.
        """
        self.kind = kind
        self.number = 0
        self.flag = False
        self.text = String("")
        self.items = List[Int]()
        self.keys = List[String]()


struct JsValues(Movable):
    """A tree of JavaScript values, kept in one list."""

    var nodes: List[JsNode]
    """Every value; a value names its children by index."""

    def __init__(out self):
        """Start with no values."""
        self.nodes = List[JsNode]()

    def add(mut self, var node: JsNode) -> Int:
        """Add a value.

        Args:
            node: The value.

        Returns:
            Its index.
        """
        self.nodes.append(node^)
        return len(self.nodes) - 1

    def kind(self, value: Int) -> JsKind:
        """Return a value's kind; `UNDEFINED` for index -1.

        Args:
            value: The value's index, or -1.

        Returns:
            Its kind.
        """
        if value < 0:
            return JsKind.UNDEFINED
        return self.nodes[value].kind


comptime UNDEFINED = -1
"""The index that stands for `undefined`."""

comptime _MAX_INT: Float64 = 2147483647
comptime _MIN_INT: Float64 = -2147483648
comptime _INT = 0
comptime _FLOAT = 1
comptime _STRING = 2
comptime _BOOLEAN = 3
comptime _ID = 4
comptime _CUSTOM = -1
# ECMAScript StrWhiteSpaceChar: WhiteSpace and LineTerminator.
comptime _JS_SPACES = "\t\n\x0b\x0c\r                  　﻿"


def js_number_to_string(value: Float64) -> String:
    """Format a number as ECMAScript `Number.prototype.toString` does.

    The shortest digits that read back as the same number, in fixed
    notation from 1e-7 up to 1e21 and in exponent notation outside.

    Args:
        value: A number.

    Returns:
        The text, such as `12300`, `0.1`, `1e+21`, `1.5e-7`, `NaN` or
        `-Infinity`. Negative zero is `0`.
    """
    if value == 0:
        return String("0")
    if isnan(value):
        return String("NaN")
    if not isfinite(value):
        if value > 0:
            return String("Infinity")
        return String("-Infinity")
    var text = String(value)
    var out = String("")
    var start = 0
    var bytes = text.as_bytes()
    if bytes[0] == 0x2D:
        out = String("-")
        start = 1
    # Read Mojo's shortest round-trip form: digits, a point, an exponent.
    var digits = String("")
    var point = -1
    var exponent = 0
    var index = start
    while index < len(bytes):
        var byte = bytes[index]
        if byte == 0x2E:
            point = digits.byte_length()
        elif byte == 0x65:
            exponent = _parse_exponent(bytes, index + 1)
            break
        else:
            digits += chr(Int(byte))
        index += 1
    if point < 0:
        point = digits.byte_length()
    # value = 0.DIGITS * 10^n, with no leading or trailing zero digit.
    var lead = 0
    var digit_bytes = digits.as_bytes()
    while digit_bytes[lead] == 0x30:
        lead += 1
    var trail = len(digit_bytes)
    while digit_bytes[trail - 1] == 0x30:
        trail -= 1
    var significant = String(digits[byte=lead:trail])
    var n = point - lead + exponent
    var k = significant.byte_length()
    if k <= n and n <= 21:
        out += significant + String("0") * (n - k)
    elif 0 < n and n <= 21:
        out += (
            String(significant[byte=0:n]) + "." + String(significant[byte=n:])
        )
    elif -6 < n and n <= 0:
        out += "0." + String("0") * (-n) + significant
    else:
        var e = n - 1
        out += String(significant[byte=0:1])
        if k > 1:
            out += "." + String(significant[byte=1:])
        out += "e"
        if e > 0:
            out += "+"
        out += String(e)
    return out^


def _parse_exponent(bytes: Span[UInt8, _], start: Int) -> Int:
    """Read `+21` or `-7` from Mojo's float text, which always signs it."""
    var sign = 1
    if bytes[start] == 0x2D:
        sign = -1
    var index = start + 1
    var value = 0
    while index < len(bytes):
        value = value * 10 + Int(bytes[index]) - 0x30
        index += 1
    return sign * value


def _is_digit(byte: UInt8) -> Bool:
    """Return True for an ASCII decimal digit."""
    return byte >= 0x30 and byte <= 0x39


def _char_width(lead: UInt8) -> Int:
    """Return the byte length of the UTF-8 character that starts with a
    lead byte."""
    if lead >= 0xF0:
        return 4
    if lead >= 0xE0:
        return 3
    if lead >= 0xC0:
        return 2
    return 1


def _is_js_space(char: Span[UInt8, _]) -> Bool:
    """Return True for the bytes of one JavaScript white space or line
    terminator character.

    UTF-8 is self-synchronizing, so the bytes of a whole character occur in
    `_JS_SPACES` only where that character is.
    """
    return StringSlice(_JS_SPACES).find(StringSlice(unsafe_from_utf8=char)) >= 0


def _radix_to_number(digits: Span[UInt8, _], shift: Int) -> Float64:
    """Return the value of `0x`, `0o` or `0b` digits, rounded to nearest.

    Up to 60 bits are kept exactly; a later nonzero digit sets the lowest
    bit, so the conversion to a double rounds as one exact conversion.
    """
    if len(digits) == 0:
        return nan[DType.float64]()
    var mantissa: UInt64 = 0
    var exponent = 0
    var sticky: UInt64 = 0
    var index = 0
    while index < len(digits):
        var byte = digits[index]
        var digit = 99
        if _is_digit(byte):
            digit = Int(byte) - 0x30
        elif (byte | 0x20) >= 0x61 and (byte | 0x20) <= 0x66:
            digit = Int(byte | 0x20) - 0x61 + 10
        if digit >= 1 << shift:
            return nan[DType.float64]()
        if mantissa < 1 << 56:
            mantissa = (mantissa << UInt64(shift)) | UInt64(digit)
        else:
            exponent += shift
            if digit != 0:
                sticky = 1
        index += 1
    # Scale by exact powers of two; a product past the range is Infinity.
    # `ldexp` alone does not overflow to Infinity.
    var value = Float64(mantissa | sticky)
    while exponent > 0:
        var step = min(exponent, 512)
        value *= ldexp(Float64(1), Int32(step))
        exponent -= step
    return value


def _decimal_to_number(text: Span[UInt8, _]) -> Float64:
    """Return the value of a `StrDecimalLiteral` with no `Infinity`.

    The text, which is not empty, must be `[+-]` digits, a point and
    digits, with at least one digit, then an optional exponent; anything
    else is NaN.
    """
    # The text is rewritten as a JSON number, which `read_float64` reads
    # exactly at any length: no `+`, no leading zeros, and no point without
    # digits after it.
    var json = List[UInt8](capacity=len(text) + 2)
    var index = 0
    if text[0] == 0x2D:
        json.append(0x2D)
    if text[0] == 0x2B or text[0] == 0x2D:
        index = 1
    var whole = index
    while index < len(text) and _is_digit(text[index]):
        index += 1
    var whole_end = index
    var fraction = index
    var fraction_end = index
    if index < len(text) and text[index] == 0x2E:
        index += 1
        fraction = index
        while index < len(text) and _is_digit(text[index]):
            index += 1
        fraction_end = index
    if whole == whole_end and fraction == fraction_end:
        return nan[DType.float64]()
    while whole + 1 < whole_end and text[whole] == 0x30:
        whole += 1
    if whole == whole_end:
        json.append(0x30)
    json.extend(text[whole:whole_end])
    if fraction < fraction_end:
        json.append(0x2E)
        json.extend(text[fraction:fraction_end])
    if index < len(text) and (text[index] | 0x20) == 0x65:
        json.append(0x65)
        index += 1
        if index < len(text) and (text[index] == 0x2B or text[index] == 0x2D):
            json.append(text[index])
            index += 1
        var exponent = index
        while index < len(text) and _is_digit(text[index]):
            index += 1
        # ECMAScript refuses an exponent with no digits, as in `1e+`.
        if exponent == index:
            return nan[DType.float64]()
        json.extend(text[exponent:index])
    if index != len(text):
        return nan[DType.float64]()
    return read_float64(json)


def _string_to_number(text: StringSlice) -> Float64:
    """Return ECMAScript `Number(text)` for a string.

    Leading and trailing white space is ignored; the rest must be empty
    (0), `0x`, `0o` or `0b` digits, or a decimal literal. `[+-]Infinity`
    gives NaN here, not an infinity: the only callers, `Int` and `Float`
    `serialize`, refuse both with the same message.
    """
    var bytes = text.as_bytes()
    # The first and the end of the last character that is not white space.
    var start = -1
    var stop = 0
    var index = 0
    while index < len(bytes):
        var width = _char_width(bytes[index])
        if not _is_js_space(bytes[index : index + width]):
            if start < 0:
                start = index
            stop = index + width
        index += width
    if start < 0:
        return 0
    var body = bytes[start:stop]
    if len(body) >= 2 and body[0] == 0x30:
        var prefix = body[1] | 0x20
        if prefix == 0x78:
            return _radix_to_number(body[2:], 4)
        if prefix == 0x6F:
            return _radix_to_number(body[2:], 3)
        if prefix == 0x62:
            return _radix_to_number(body[2:], 1)
    return _decimal_to_number(body)


def _is_integer(value: Float64) -> Bool:
    """Return ECMAScript `Number.isInteger(value)`."""
    return isfinite(value) and trunc(value) == value


def _is_integer_string(text: StringSlice) -> Bool:
    """Return True for text that matches `/^-?(?:0|[1-9][0-9]*)$/`."""
    var bytes = text.as_bytes()
    var index = 0
    if index < len(bytes) and bytes[index] == 0x2D:
        index += 1
    if index >= len(bytes):
        return False
    if bytes[index] == 0x30:
        return index + 1 == len(bytes)
    while index < len(bytes):
        if not _is_digit(bytes[index]):
            return False
        index += 1
    return True


def _scalar_index(schema: Schema, type: Int) -> Int:
    """Return `_INT` to `_ID` for a built-in scalar; `_CUSTOM` otherwise."""
    ref named = schema.types[type]
    if not named.is_builtin:
        return _CUSTOM
    if named.name == "Int":
        return _INT
    if named.name == "Float":
        return _FLOAT
    if named.name == "String":
        return _STRING
    if named.name == "Boolean":
        return _BOOLEAN
    return _ID


def _number(value: Float64) -> JsNode:
    """Return a number value."""
    var node = JsNode(JsKind.NUMBER)
    node.number = value
    return node^


def _string(var value: String) -> JsNode:
    """Return a string value."""
    var node = JsNode(JsKind.STRING)
    node.text = value^
    return node^


def _boolean(value: Bool) -> JsNode:
    """Return a boolean value."""
    var node = JsNode(JsKind.BOOLEAN)
    node.flag = value
    return node^


def _parse_float(text: StringSlice) -> Float64:
    """Return the number a GraphQL Int or Float literal names, as
    `parseInt` and `parseFloat` read it."""
    return _decimal_to_number(text.as_bytes())


def value_from_ast_untyped(
    document: Document, node: Int, mut values: JsValues
) -> Int:
    """Coerce a literal with no type, as graphql-js `valueFromASTUntyped`
    does with no variables.

    An object literal that repeats a field keeps the field's first
    position and its last value, as a JavaScript object does.

    Args:
        document: The document that holds the literal.
        node: The literal's node.
        values: Where to add the value.

    Returns:
        The value's index, or `UNDEFINED` for a variable.
    """
    var kind = document.kind(node)
    if kind == Kind.NULL:
        return values.add(JsNode(JsKind.NULL))
    if kind == Kind.INT or kind == Kind.FLOAT:
        return values.add(_number(_parse_float(document.text(node))))
    if kind == Kind.STRING:
        return values.add(_string(document.string_value(node)))
    if kind == Kind.ENUM:
        return values.add(_string(String(document.text(node))))
    if kind == Kind.BOOLEAN:
        return values.add(_boolean(document.boolean_value(node)))
    if kind == Kind.LIST:
        var list = JsNode(JsKind.LIST)
        for item in document.children(node, Role.LIST_ITEM):
            list.items.append(value_from_ast_untyped(document, item, values))
        return values.add(list^)
    if kind == Kind.OBJECT:
        var object = JsNode(JsKind.OBJECT)
        for field in document.children(node, Role.FIELD):
            var item = value_from_ast_untyped(
                document, document.child(field, Role.VALUE), values
            )
            var key = document.name(field)
            var at = _key_index(object.keys, key)
            if at < 0:
                object.keys.append(String(key))
                object.items.append(item)
            else:
                object.items[at] = item
        return values.add(object^)
    return UNDEFINED


def _key_index(keys: List[String], key: StringSlice) -> Int:
    """Return the position of a key, or -1."""
    var index = 0
    while index < len(keys):
        if keys[index] == key:
            return index
        index += 1
    return -1


def _literal_error(
    document: Document, node: Int, message: String
) -> GraphQLError:
    """Return an error located at a literal, as `{ nodes: valueNode }`."""
    return GraphQLError(message, document.source, [document.start(node)])


def parse_literal(
    schema: Schema,
    document: Document,
    node: Int,
    type: Int,
    mut values: JsValues,
) raises GraphQLError -> Int:
    """Coerce a literal to a scalar or an enum type, as graphql-js
    `parseLiteral` does with no variables.

    Args:
        schema: The schema the type is in.
        document: The document that holds the literal.
        node: The literal's node.
        type: The scalar or enum type's index.
        values: Where to add the value.

    Returns:
        The value's index; a custom scalar gives `UNDEFINED` for a
        variable.

    Raises:
        GraphQLError: The graphql-js message, such as `Int cannot represent
            non-integer value: 1.0`, located at the literal; or
            `Unexpected input type: X` for a type that is not a scalar or
            an enum.
    """
    ref named = schema.types[type]
    var kind = document.kind(node)
    if named.kind == TypeKind.ENUM:
        if kind != Kind.ENUM:
            var text = print_node(document, node)
            raise _literal_error(
                document,
                node,
                'Enum "'
                + named.name
                + '" cannot represent non-enum value: '
                + text
                + "."
                + _did_you_mean_enum_value(schema, type, text),
            )
        var name = document.text(node)
        if schema.enum_value_named(type, name) == NO_TYPE:
            var text = print_node(document, node)
            raise _literal_error(
                document,
                node,
                'Value "'
                + text
                + '" does not exist in "'
                + named.name
                + '" enum.'
                + _did_you_mean_enum_value(schema, type, text),
            )
        return values.add(_string(String(name)))
    if named.kind != TypeKind.SCALAR:
        raise GraphQLError("Unexpected input type: " + named.name)
    var scalar = _scalar_index(schema, type)
    if scalar == _CUSTOM:
        return value_from_ast_untyped(document, node, values)
    if scalar == _INT:
        if kind != Kind.INT:
            raise _literal_error(
                document,
                node,
                "Int cannot represent non-integer value: "
                + print_node(document, node),
            )
        var number = _parse_float(document.text(node))
        if number > _MAX_INT or number < _MIN_INT:
            raise _literal_error(
                document,
                node,
                "Int cannot represent non 32-bit signed integer value: "
                + String(document.text(node)),
            )
        return values.add(_number(number))
    if scalar == _FLOAT:
        if kind != Kind.INT and kind != Kind.FLOAT:
            raise _literal_error(
                document,
                node,
                "Float cannot represent non numeric value: "
                + print_node(document, node),
            )
        return values.add(_number(_parse_float(document.text(node))))
    if scalar == _STRING:
        if kind != Kind.STRING:
            raise _literal_error(
                document,
                node,
                "String cannot represent a non string value: "
                + print_node(document, node),
            )
        return values.add(_string(document.string_value(node)))
    if scalar == _BOOLEAN:
        if kind != Kind.BOOLEAN:
            raise _literal_error(
                document,
                node,
                "Boolean cannot represent a non boolean value: "
                + print_node(document, node),
            )
        return values.add(_boolean(document.boolean_value(node)))
    if kind == Kind.STRING:
        return values.add(_string(document.string_value(node)))
    if kind == Kind.INT:
        return values.add(_string(String(document.text(node))))
    raise _literal_error(
        document,
        node,
        "ID cannot represent a non-string and non-integer value: "
        + print_node(document, node),
    )


def _did_you_mean_enum_value(schema: Schema, type: Int, text: String) -> String:
    """Return graphql-js `didYouMeanEnumValue` for an enum type."""
    ref named = schema.types[type]
    var names = List[String]()
    for index in range(Int(named.enum_values.start), named.enum_values.end()):
        names.append(schema.enum_values[index].name)
    return did_you_mean("the enum value", suggestion_list(text, names))


def value_from_ast(
    schema: Schema,
    document: Document,
    node: Int,
    type: TypeRef,
    mut values: JsValues,
) raises -> Int:
    """Coerce a literal to a type, as graphql-js `valueFromAST` does with
    no variables.

    Args:
        schema: The schema the type is in.
        document: The document that holds the literal.
        node: The literal's node.
        type: The input type.
        values: Where to add the value.

    Returns:
        The value's index, or `UNDEFINED` when the literal is invalid for
        the type.

    Raises:
        Error: `Unexpected input type: X` when the literal reaches an
            output type, as graphql-js raises it.
    """
    var kind = document.kind(node)
    if kind == Kind.VARIABLE:
        return UNDEFINED
    if type.is_non_null():
        if kind == Kind.NULL:
            return UNDEFINED
        return value_from_ast(schema, document, node, type.of_type(), values)
    if kind == Kind.NULL:
        return values.add(JsNode(JsKind.NULL))
    if type.is_list():
        var item_type = type.of_type()
        var list = JsNode(JsKind.LIST)
        if kind == Kind.LIST:
            for item in document.children(node, Role.LIST_ITEM):
                if document.kind(item) == Kind.VARIABLE:
                    if item_type.is_non_null():
                        return UNDEFINED
                    list.items.append(values.add(JsNode(JsKind.NULL)))
                    continue
                var coerced = value_from_ast(
                    schema, document, item, item_type, values
                )
                if coerced == UNDEFINED:
                    return UNDEFINED
                list.items.append(coerced)
            return values.add(list^)
        var single = value_from_ast(schema, document, node, item_type, values)
        if single == UNDEFINED:
            return UNDEFINED
        list.items.append(single)
        return values.add(list^)
    var named = Int(type.named)
    ref named_type = schema.types[named]
    if named_type.kind == TypeKind.INPUT_OBJECT:
        return _input_object_from_ast(schema, document, node, named, values)
    if not named_type.kind.is_leaf():
        raise Error("Unexpected input type: " + named_type.name)
    try:
        return parse_literal(schema, document, node, named, values)
    except:
        return UNDEFINED


def _input_object_from_ast(
    schema: Schema,
    document: Document,
    node: Int,
    type: Int,
    mut values: JsValues,
) raises -> Int:
    """Coerce an object literal to an input object type."""
    if document.kind(node) != Kind.OBJECT:
        return UNDEFINED
    var object = JsNode(JsKind.OBJECT)
    ref named = schema.types[type]
    for index in range(Int(named.input_fields.start), named.input_fields.end()):
        ref field = schema.input_values[index]
        var field_node = NO_NODE
        for candidate in document.children(node, Role.FIELD):
            if document.name(candidate) == field.name:
                field_node = candidate
        var value_node = NO_NODE
        if field_node != NO_NODE:
            value_node = document.child(field_node, Role.VALUE)
        if value_node == NO_NODE or document.kind(value_node) == Kind.VARIABLE:
            # graphql-js keeps an invalid default as `undefined`, which is
            # the same as no default.
            var default = default_value(schema, index, values)
            if default != UNDEFINED:
                object.keys.append(field.name)
                object.items.append(default)
            elif field.type.is_non_null():
                return UNDEFINED
            continue
        var coerced = value_from_ast(
            schema, document, value_node, field.type, values
        )
        if coerced == UNDEFINED:
            return UNDEFINED
        object.keys.append(field.name)
        object.items.append(coerced)
    if named.is_one_of:
        if len(object.keys) != 1:
            return UNDEFINED
        if values.kind(object.items[0]) == JsKind.NULL:
            return UNDEFINED
    return values.add(object^)


def default_value(
    schema: Schema, input_value: Int, mut values: JsValues
) raises -> Int:
    """Return an argument's or input field's coerced default value.

    Args:
        schema: The schema.
        input_value: The input value's index.
        values: Where to add the value.

    Returns:
        The value's index, or `UNDEFINED` when there is no default or it
        is invalid for the type.

    Raises:
        Error: As `value_from_ast` raises.
    """
    ref value = schema.input_values[input_value]
    if not value.has_default():
        return UNDEFINED
    var at = value.default_value
    return value_from_ast(
        schema,
        schema.documents[Int(at.document)],
        Int(at.node),
        value.type,
        values,
    )


def inspect(values: JsValues, value: Int) -> String:
    """Return a value as graphql-js `inspect` writes it.

    Strings are in JSON quotes. An array shows at most ten items, and an
    array or an object nested three deep shows as `[Array]` or `[Object]`.

    Args:
        values: The tree.
        value: The value's index.

    Returns:
        Such as `{ a: 1, b: "x" }` or `[1, 2]`.
    """
    return _format_value(values, value, 0)


def _format_value(values: JsValues, value: Int, depth: Int) -> String:
    """Return graphql-js `formatValue`; `depth` counts the enclosing
    arrays and objects."""
    var kind = values.kind(value)
    if kind == JsKind.UNDEFINED:
        return String("undefined")
    ref node = values.nodes[value]
    if kind == JsKind.NULL:
        return String("null")
    if kind == JsKind.BOOLEAN:
        if node.flag:
            return String("true")
        return String("false")
    if kind == JsKind.NUMBER:
        return js_number_to_string(node.number)
    if kind == JsKind.STRING:
        return quote_json_string(node.text)
    var count = len(node.items)
    if kind == JsKind.LIST:
        if count == 0:
            return String("[]")
        if depth >= 2:
            return String("[Array]")
        var shown = min(count, 10)
        var out = String("[")
        var index = 0
        while index < shown:
            if index > 0:
                out += ", "
            out += _format_value(values, node.items[index], depth + 1)
            index += 1
        var remaining = count - shown
        if remaining == 1:
            out += ", ... 1 more item"
        elif remaining > 1:
            out += ", ... " + String(remaining) + " more items"
        return out + "]"
    if count == 0:
        return String("{}")
    if depth >= 2:
        return String("[Object]")
    var out = String("{ ")
    var index = 0
    while index < count:
        if index > 0:
            out += ", "
        out += (
            node.keys[index]
            + ": "
            + _format_value(values, node.items[index], depth + 1)
        )
        index += 1
    return out + " }"


def print_ast_from_value(
    schema: Schema, values: JsValues, value: Int, type: TypeRef
) raises -> Optional[String]:
    """Print a value as a literal of a type, as graphql-js
    `print(astFromValue(value, type))`.

    Args:
        schema: The schema the type is in.
        values: The tree.
        value: The value's index.
        type: The input type.

    Returns:
        The literal, or none where `astFromValue` returns null.

    Raises:
        Error: The `serialize` error of a scalar or an enum, such as
            `Int cannot represent non-integer value: 1.5`;
            `Cannot convert value to AST: ...` for a custom scalar value
            that is not a finite number, a string or a boolean; and
            `Unexpected input type: X` for an output type.
    """
    if type.is_non_null():
        var inner = print_ast_from_value(schema, values, value, type.of_type())
        if inner and inner.value() == "null":
            return None
        return inner
    var kind = values.kind(value)
    if kind == JsKind.NULL:
        return String("null")
    if kind == JsKind.UNDEFINED:
        return None
    ref node = values.nodes[value]
    if type.is_list():
        var item_type = type.of_type()
        if kind == JsKind.LIST:
            var out = String("[")
            var first = True
            for item in node.items:
                var printed = print_ast_from_value(
                    schema, values, item, item_type
                )
                if printed:
                    if not first:
                        out += ", "
                    first = False
                    out += printed.value()
            return out + "]"
        return print_ast_from_value(schema, values, value, item_type)
    var named = Int(type.named)
    ref named_type = schema.types[named]
    if named_type.kind == TypeKind.INPUT_OBJECT:
        if kind != JsKind.OBJECT and kind != JsKind.LIST:
            return None
        var out = String("{")
        var first = True
        for index in range(
            Int(named_type.input_fields.start), named_type.input_fields.end()
        ):
            ref field = schema.input_values[index]
            var at = _key_index(node.keys, field.name)
            var field_value = UNDEFINED
            if at >= 0:
                field_value = node.items[at]
            var printed = print_ast_from_value(
                schema, values, field_value, field.type
            )
            if printed:
                if not first:
                    out += ", "
                first = False
                out += field.name + ": " + printed.value()
        return out + "}"
    if named_type.kind == TypeKind.ENUM:
        if (
            kind == JsKind.STRING
            and schema.enum_value_named(named, node.text) != NO_TYPE
        ):
            return node.text
        raise Error(
            'Enum "'
            + named_type.name
            + '" cannot represent value: '
            + inspect(values, value)
        )
    if named_type.kind != TypeKind.SCALAR:
        raise Error("Unexpected input type: " + named_type.name)
    return _serialize_scalar(schema, values, value, named)


def _to_number(node: JsNode) -> Float64:
    """Return the number `Int` and `Float` serialize: a boolean is 1 or 0,
    a nonempty string is `Number(string)`, and anything else is NaN."""
    if node.kind == JsKind.BOOLEAN:
        if node.flag:
            return 1
        return 0
    if node.kind == JsKind.NUMBER:
        return node.number
    if node.kind == JsKind.STRING and node.text != "":
        return _string_to_number(node.text)
    return nan[DType.float64]()


def _serialize_scalar(
    schema: Schema, values: JsValues, value: Int, type: Int
) raises -> String:
    """Return the literal of a scalar's serialized value, as graphql-js
    `serialize` then `astFromValue` give it."""
    ref node = values.nodes[value]
    var kind = node.kind
    var scalar = _scalar_index(schema, type)
    if scalar == _INT:
        var number = _to_number(node)
        if not _is_integer(number):
            raise Error(
                "Int cannot represent non-integer value: "
                + inspect(values, value)
            )
        if number > _MAX_INT or number < _MIN_INT:
            raise Error(
                "Int cannot represent non 32-bit signed integer value: "
                + inspect(values, value)
            )
        return js_number_to_string(number)
    if scalar == _FLOAT:
        var number = _to_number(node)
        if not isfinite(number):
            raise Error(
                "Float cannot represent non numeric value: "
                + inspect(values, value)
            )
        return js_number_to_string(number)
    if scalar == _BOOLEAN:
        if kind == JsKind.BOOLEAN:
            return inspect(values, value)
        if kind == JsKind.NUMBER and isfinite(node.number):
            if node.number != 0:
                return String("true")
            return String("false")
        raise Error(
            "Boolean cannot represent a non boolean value: "
            + inspect(values, value)
        )
    if kind == JsKind.STRING:
        if scalar == _ID and _is_integer_string(node.text):
            return node.text
        return print_string(node.text)
    if scalar == _STRING:
        if kind == JsKind.BOOLEAN:
            return print_string(inspect(values, value))
        if kind == JsKind.NUMBER and isfinite(node.number):
            return print_string(js_number_to_string(node.number))
        raise Error("String cannot represent value: " + inspect(values, value))
    if scalar == _ID:
        if kind == JsKind.NUMBER and _is_integer(node.number):
            var text = js_number_to_string(node.number)
            if _is_integer_string(text):
                return text
            return print_string(text)
        raise Error("ID cannot represent value: " + inspect(values, value))
    # A custom scalar serializes as the identity.
    if kind == JsKind.BOOLEAN:
        return inspect(values, value)
    if kind == JsKind.NUMBER and isfinite(node.number):
        return js_number_to_string(node.number)
    raise Error("Cannot convert value to AST: " + inspect(values, value) + ".")


def print_default(schema: Schema, input_value: Int) raises -> Optional[String]:
    """Print an argument's or input field's default value as graphql-js
    `printSchema` and `__InputValue.defaultValue` do.

    Args:
        schema: The schema.
        input_value: The input value's index.

    Returns:
        The default literal, or none when there is none or it is invalid.

    Raises:
        Error: As `print_ast_from_value` raises, such as `Float cannot
            represent non numeric value: Infinity` for `Float = 1e400`.
    """
    var values = JsValues()
    var value = default_value(schema, input_value, values)
    return print_ast_from_value(
        schema, values, value, schema.input_values[input_value].type
    )
