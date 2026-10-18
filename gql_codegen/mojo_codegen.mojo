# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Write the IR as one Mojo module.

The output follows the shape of the Apollo Kotlin `apollo-compiler`
Kotlin output (`codegen/kotlin/operations/OperationBuilder.kt`,
`ModelBuilder.kt`, `VariablesAdapter.kt`, `schema/EnumAsEnumBuilder.kt`
and `schema/InputObjectBuilder.kt`), in Mojo:

- For each operation, a struct named after the operation and its type,
  such as `HeroQuery`, with `OPERATION_ID`, `OPERATION_NAME` and
  `OPERATION_DOCUMENT`, the minified document, and `parse_data`.
- A `<Operation>_Variables` struct with `write_json`, as upstream
  `serializeVariables`, and `false_variables`, the variables that a
  condition reads as false.
- For each model, a struct with a field per property and `from_json`, as
  upstream `ResponseAdapter.fromJson`. A nested model is named after the
  path of its parents, such as `HeroQuery_Data_Hero_OnDroid`, because a
  Mojo struct cannot be nested.
- For each fragment, its model structs, named after the fragment.
- For each used enum, a struct with one `comptime` value per enum value and
  `UNKNOWN__`; for each used input object, a struct with `write_json`.

A field type maps to `String` (`String`, `ID`), `Int`, `Float64`, `Bool`,
an enum struct, an input struct or a model struct. A custom scalar is the
`String` of its JSON text. A nullable type is an `Optional`, and a variable
or input field that can be absent is one more `Optional`: `None` is absent.

Every line is at most 80 columns, and long literals and calls are split as
`mojo format` splits them, so `mojo format` keeps the output as it is.

**Differences from upstream.**

- The output is one Mojo module, not one Kotlin file per class, and the
  nested classes are flat structs with path names.
- There are no compiled selections, no data builders, no `@typePolicy`
  key fields, and no documentation comments.
- A missing nullable field reads as null.
- An unknown enum value reads as `UNKNOWN__`, without its raw value, so it
  cannot be written back: `raw_value` raises.
- A `@defer` fragment is read when it is in the data: a fragment that
  fails to read, because its data has not arrived, reads as `None`.
"""

from gql_language.ast import OperationType
from gql_schema.definition import TypeKind

from gql_codegen.ir import (
    ConditionKind,
    Conditions,
    IrModel,
    IrOperations,
    IrType,
    IrVariable,
)
from gql_codegen.ir_builder import ir_type
from gql_codegen.options import CodegenOptions
from gql_codegen.sha256 import sha256_hex
from gql_codegen.strings import (
    capitalize_first_letter,
    decapitalize_first_letter,
    escape_mojo_keyword,
    minify,
)
from gql_schema.definition import Schema

comptime WIDTH = 80
"""The longest line of the output, as `mojo format` allows."""

comptime HELPERS = '''

def _member(document: JsonDocument, node: Int, name: StringSlice) raises -> Int:
    """Return the value of a member of an object, or -1 when it is missing."""
    if document.kind(node) != JsonKind.OBJECT:
        raise Error("expected an object with the field " + String(name))
    return document.find(node, name)


def _required(
    document: JsonDocument, node: Int, name: StringSlice
) raises -> Int:
    """Return the value of a member that must be there and not be null."""
    var value = _member(document, node, name)
    if value < 0:
        raise Error("missing field " + String(name))
    if document.kind(value) == JsonKind.NULL:
        raise Error("null for the non-null field " + String(name))
    return value


def _is_null(document: JsonDocument, value: Int) -> Bool:
    """Return True for a missing member or null."""
    return value < 0 or document.kind(value) == JsonKind.NULL


def _read_string(document: JsonDocument, value: Int) raises -> String:
    """Read a string."""
    if document.kind(value) != JsonKind.STRING:
        raise Error("expected a string")
    return document.string_value(value)


def _read_id(document: JsonDocument, value: Int) raises -> String:
    """Read an ID: a string, or the text of a number."""
    if document.kind(value) == JsonKind.NUMBER:
        return String(document.text(value))
    return _read_string(document, value)


def _read_int(document: JsonDocument, value: Int) raises -> Int:
    """Read an Int."""
    if not document.is_integer(value):
        raise Error("expected an integer")
    return Int(document.as_int64(value))


def _read_float(document: JsonDocument, value: Int) raises -> Float64:
    """Read a Float."""
    if document.kind(value) != JsonKind.NUMBER:
        raise Error("expected a number")
    return document.as_float64(value)


def _read_boolean(document: JsonDocument, value: Int) raises -> Bool:
    """Read a Boolean."""
    if document.kind(value) != JsonKind.BOOLEAN:
        raise Error("expected a boolean")
    return document.bool_value(value)


def _read_json(document: JsonDocument, value: Int) -> String:
    """Read a custom scalar: its JSON text."""
    var writer = JsonWriter()
    writer.value(document, value)
    return writer^.take_string()


def _items(document: JsonDocument, value: Int) raises -> List[Int]:
    """Return the items of a list."""
    if document.kind(value) != JsonKind.ARRAY:
        raise Error("expected a list")
    return document.children(value)


def _typename(document: JsonDocument, node: Int) raises -> String:
    """Return the `__typename` of an object."""
    return _read_string(document, _required(document, node, "__typename"))


def _is_one_of(value: String, *names: StaticString) -> Bool:
    """Return True when a `__typename` is one of the possible types."""
    for name in names:
        if value == name:
            return True
    return False


def _is_true(false_variables: List[String], name: StaticString) -> Bool:
    """Return True unless the variable of a condition is false."""
    for ref variable in false_variables:
        if variable == name:
            return False
    return True
'''
"""The helpers that the generated readers call."""


def _mojo_string(text: StringSlice) -> String:
    """Quote text as a Mojo string literal, with the quotes that
    `mojo format` prefers: double quotes, unless single quotes need fewer
    escapes."""
    var doubles = 0
    var singles = 0
    for byte in text.as_bytes():
        if byte == UInt8(ord('"')):
            doubles += 1
        elif byte == UInt8(ord("'")):
            singles += 1
    var quote = UInt8(ord("'")) if singles < doubles else UInt8(ord('"'))
    var out = List[UInt8]()
    out.append(quote)
    for byte in text.as_bytes():
        out.extend(_escaped(byte, quote).as_bytes())
    out.append(quote)
    return String(unsafe_from_utf8=out)


def _escaped(byte: UInt8, quote: UInt8) -> String:
    """Return the Mojo literal text of one byte."""
    if byte == quote:
        return "\\" + chr(Int(byte))
    if byte == UInt8(ord("\\")):
        return "\\\\"
    if byte == UInt8(ord("\n")):
        return "\\n"
    if byte == UInt8(ord("\t")):
        return "\\t"
    if byte == UInt8(ord("\r")):
        return "\\r"
    if byte < 0x20 or byte == 0x7F:
        var digits = StaticString("0123456789abcdef").as_bytes()
        var out = String("\\x")
        out += chr(Int(digits[Int(byte >> 4)]))
        out += chr(Int(digits[Int(byte & 15)]))
        return out^
    return String(unsafe_from_utf8=[byte])


def _pieces(text: StringSlice, quote_width: Int, width: Int) -> List[String]:
    """Split text into the longest literals whose lines fit in a width.

    A byte is never split from its escape, and a UTF-8 sequence is never
    split. `quote_width` is the room the line needs besides the text: the
    quotes, the indent, and `+ ` after the first piece."""
    var bytes = text.as_bytes()
    var out = List[String]()
    var start = 0
    var used = 0
    # The last space of the current piece, where a break reads best, and
    # the width of the piece before it.
    var space = -1
    var before_space = 0
    var index = 0
    while index < len(bytes):
        var end = index + 1
        while end < len(bytes) and bytes[end] & 0xC0 == 0x80:
            end += 1
        var size = 0
        var position = index
        while position < end:
            size += _escaped(bytes[position], UInt8(ord('"'))).byte_length()
            position += 1
        var room = width - quote_width - (0 if len(out) == 0 else 2)
        if used + size > room and index > start:
            var cut = index
            var next_room = width - quote_width - 2
            if space > start and used - before_space + size <= next_room:
                cut = space
                used -= before_space
            else:
                used = 0
            out.append(String(unsafe_from_utf8=Span(bytes)[start:cut]))
            start = cut
            space = -1
        if bytes[index] == UInt8(ord(" ")):
            space = index
            before_space = used
        used += size
        index = end
    out.append(String(unsafe_from_utf8=Span(bytes)[start:]))
    return out^


def _spaces(count: Int) -> String:
    """Return `count` spaces."""
    var out = String("")
    for _ in range(count):
        out += " "
    return out^


struct _Out(Movable):
    """The text of the module."""

    var text: String
    """The lines so far."""

    def __init__(out self):
        """Start with no text."""
        self.text = String("")

    def take(deinit self) -> String:
        """Return the text.

        Returns:
            Every line written.
        """
        return self.text^

    def line(mut self, indent: Int, text: StringSlice):
        """Write one line.

        Args:
            indent: The indent, in spaces.
            text: The line, without the indent.
        """
        if text.byte_length() > 0:
            self.text += _spaces(indent)
            self.text += text
        self.text += "\n"

    def blank(mut self):
        """Write an empty line."""
        self.text += "\n"

    def docstring(mut self, indent: Int, text: StringSlice):
        """Write a docstring, wrapped at the spaces of the text.

        Args:
            indent: The indent, in spaces.
            text: The text, without quotes.
        """
        var lines = List[String]()
        var current = String('"""')
        var words = text.split(" ")
        var word_index = 0
        while word_index < len(words):
            var word = words[word_index]
            word_index += 1
            var candidate = current + ("" if current == '"""' else " ") + word
            if indent + candidate.byte_length() > WIDTH and current != '"""':
                lines.append(current^)
                current = String(word)
            else:
                current = candidate^
        if indent + current.byte_length() + 3 > WIDTH:
            lines.append(current^)
            current = String("")
        current += '"""'
        lines.append(current^)
        var line_index = 0
        while line_index < len(lines):
            self.line(indent, lines[line_index])
            line_index += 1

    def string(mut self, indent: Int, head: StringSlice, text: StringSlice):
        """Write `head` and a string literal, split as `mojo format` would
        split it: on one line, in parentheses, or as pieces joined by `+`.

        Args:
            indent: The indent, in spaces.
            head: The text before the literal, such as `comptime A = `.
            text: The value of the string.
        """
        var literal = _mojo_string(text)
        if indent + head.byte_length() + literal.byte_length() <= WIDTH:
            self.line(indent, String(head) + literal)
            return
        self.line(indent, String(head) + "(")
        var inner = indent + 4
        var pieces = _pieces(text, inner + 2, WIDTH)
        var index = 0
        while index < len(pieces):
            var prefix = "" if index == 0 else "+ "
            self.line(inner, prefix + _mojo_string(pieces[index]))
            index += 1
        self.line(indent, ")")

    def call(
        mut self,
        indent: Int,
        head: StringSlice,
        arguments: List[String],
        tail: StringSlice = ")",
    ):
        """Write a call, laid out as `mojo format` lays it out: on one line,
        with the arguments on one line of their own, or one argument per
        line with a trailing comma.

        Args:
            indent: The indent, in spaces.
            head: The text up to the opening bracket, included.
            arguments: The arguments.
            tail: The closing bracket and what follows it.
        """
        var joined = ", ".join(arguments)
        if (
            indent
            + head.byte_length()
            + joined.byte_length()
            + tail.byte_length()
            <= WIDTH
        ):
            self.line(indent, String(head) + joined + tail)
            return
        self.line(indent, head)
        if indent + 4 + joined.byte_length() <= WIDTH:
            self.line(indent + 4, joined)
        else:
            # Only arguments that do not fit get here.
            for ref argument in arguments:  # pragma: no branch
                self.line(indent + 4, argument + ",")
        self.line(indent, tail)


struct _Generator(Movable):
    """The state of one generation."""

    var out: _Out
    """The module so far."""
    var names: Dict[String, String]
    """The struct name of each model id."""
    var counter: Int
    """The next number of a temporary name."""
    var decapitalize: Bool
    """Whether property names start with a small letter."""
    var possible_types: Dict[String, String]
    """The helper name of each condition of possible types."""

    def __init__(out self, options: CodegenOptions):
        """Start a generation.

        Args:
            options: The options.
        """
        self.out = _Out()
        self.names = Dict[String, String]()
        self.counter = 0
        self.decapitalize = options.decapitalize_fields
        self.possible_types = Dict[String, String]()

    def take(deinit self) -> String:
        """Return the module.

        Returns:
            The source text.
        """
        return self.out^.take()

    def temporary(mut self, prefix: StringSlice) -> String:
        """Return a new local name.

        Args:
            prefix: Such as `t`.

        Returns:
            Such as `t3`.
        """
        self.counter += 1
        return String(prefix) + String(self.counter)

    def property_name(self, name: StringSlice) -> String:
        """Return the Mojo name of a property.

        Args:
            name: The response name.

        Returns:
            The name, decapitalized when asked, with `_` after a keyword.
        """
        if self.decapitalize:
            return escape_mojo_keyword(decapitalize_first_letter(name))
        return escape_mojo_keyword(name)

    # --- types -----------------------------------------------------------

    def named_type(self, type: IrType) raises -> String:
        """Return the Mojo type of the named type of an IR type.

        Args:
            type: The IR type.

        Returns:
            Such as `String` or `HeroQuery_Data_Hero`.

        Raises:
            Error: When the model of the type was not generated.
        """
        if type.model != "":
            var found = self.names.get(type.model)
            if not found:
                raise Error("no struct for the model " + type.model)
            return found.value()
        if type.kind == TypeKind.ENUM or type.kind == TypeKind.INPUT_OBJECT:
            return type.name
        if type.name == "Int":
            return "Int"
        if type.name == "Float":
            return "Float64"
        if type.name == "Boolean":
            return "Bool"
        return "String"

    def mojo_type(self, type: IrType, level: Int = 0) raises -> String:
        """Return the Mojo type of a level of an IR type.

        Args:
            type: The IR type.
            level: 0 for the outermost level.

        Returns:
            Such as `Optional[List[String]]`.

        Raises:
            Error: When the model of the type was not generated.
        """
        var out = self.named_type(type)
        if type.is_nullable(type.lists):
            out = "Optional[" + out + "]"
        var current = type.lists - 1
        while current >= level:
            out = "List[" + out + "]"
            if type.is_nullable(current):
                out = "Optional[" + out + "]"
            current -= 1
        return out^

    def input_type(self, type: IrType) raises -> String:
        """Return the Mojo type of a variable or an input field.

        Args:
            type: The IR type.

        Returns:
            The type; one more `Optional` when it can be absent.

        Raises:
            Error: When the model of the type was not generated.
        """
        if type.optional:
            return "Optional[" + self.mojo_type(type) + "]"
        return self.mojo_type(type)

    # --- reading ---------------------------------------------------------

    def read_named(
        mut self,
        indent: Int,
        target: String,
        value: String,
        type: IrType,
    ) raises:
        """Write `var target = ...` that reads a named type from a value.

        Args:
            indent: The indent.
            target: The local to declare.
            value: The local that holds the JSON value.
            type: The IR type.

        Raises:
            Error: When the model of the type was not generated.
        """
        var head = "var " + target + " = "
        if type.model != "":
            self.out.call(
                indent,
                head + self.named_type(type) + ".from_json(",
                ["document", value, "false_variables"],
            )
            return
        if type.kind == TypeKind.ENUM:
            self.out.call(
                indent,
                head + type.name + ".safe_value_of(",
                ["_read_string(document, " + value + ")"],
            )
            return
        var reader = "_read_json"
        if type.name == "String":
            reader = "_read_string"
        elif type.name == "ID":
            reader = "_read_id"
        elif type.name == "Int":
            reader = "_read_int"
        elif type.name == "Float":
            reader = "_read_float"
        elif type.name == "Boolean":
            reader = "_read_boolean"
        self.out.call(indent, head + reader + "(", ["document", value])

    def read(
        mut self,
        indent: Int,
        target: String,
        value: String,
        type: IrType,
        level: Int,
    ) raises:
        """Write the statements that declare `target` and read a level of a
        type from a JSON value into it.

        Args:
            indent: The indent.
            target: The local to declare.
            value: The local that holds the JSON value.
            type: The IR type.
            level: The level to read.

        Raises:
            Error: When the model of the type was not generated.
        """
        if type.is_nullable(level):
            self.out.call(
                indent,
                "var " + target + " = " + self.mojo_type(type, level) + "(",
                ["None"],
            )
            self.out.line(indent, "if not _is_null(document, " + value + "):")
            var inner = self.temporary("t")
            self.read_present(indent + 4, inner, value, type, level)
            self.out.line(
                indent + 4, target + " = " + _moved(inner, type, level, False)
            )
            return
        self.read_present(indent, target, value, type, level)

    def read_present(
        mut self,
        indent: Int,
        target: String,
        value: String,
        type: IrType,
        level: Int,
    ) raises:
        """Write the statements that read a level that is not null.

        Args:
            indent: The indent.
            target: The local to declare.
            value: The local that holds the JSON value.
            type: The IR type.
            level: The level to read.

        Raises:
            Error: When the model of the type was not generated.
        """
        if level == type.lists:
            self.read_named(indent, target, value, type)
            return
        var item_type = self.mojo_type(type, level + 1)
        self.out.line(indent, "var " + target + " = List[" + item_type + "]()")
        var item = self.temporary("v")
        self.out.line(
            indent, "for " + item + " in _items(document, " + value + "):"
        )
        var element = self.temporary("t")
        self.read(indent + 4, element, item, type, level + 1)
        self.out.line(
            indent + 4,
            target + ".append(" + _moved(element, type, level + 1, True) + ")",
        )

    def condition(
        mut self, indent: Int, conditions: Conditions, condition: Int
    ) raises -> String:
        """Write the statements that compute a condition, and return the
        expression of its value.

        Args:
            indent: The indent.
            conditions: The conditions.
            condition: The condition.

        Returns:
            A local or a constant.

        Raises:
            Error: For a condition kind that is not valid.
        """
        ref node = conditions.nodes[condition]
        var kind = node.kind
        if kind == ConditionKind.TRUE or kind == ConditionKind.LABEL:
            return "True"
        if kind == ConditionKind.FALSE:
            return "False"
        var target = self.temporary("c")
        if kind == ConditionKind.VARIABLE:
            self.out.call(
                indent,
                "var " + target + " = _is_true(",
                ["false_variables", _mojo_string(node.name)],
            )
            return target
        if kind == ConditionKind.POSSIBLE_TYPES:
            var arguments: List[String] = ["typename"]
            for ref name in node.types:
                arguments.append(_mojo_string(name))
            self.out.call(indent, "var " + target + " = _is_one_of(", arguments)
            return target
        if kind == ConditionKind.NOT:
            var operand = self.condition(indent, conditions, node.operands[0])
            self.out.line(indent, "var " + target + " = not " + operand)
            return target
        if kind != ConditionKind.AND and kind != ConditionKind.OR:
            raise Error("invalid condition kind")
        var operator = " and " if kind == ConditionKind.AND else " or "
        var operands = node.operands.copy()
        var value = self.condition(indent, conditions, operands[0])
        for index in range(1, len(operands)):
            var other = self.condition(indent, conditions, operands[index])
            var next = self.temporary("c")
            self.out.line(
                indent, "var " + next + " = " + value + operator + other
            )
            value = next
        self.out.line(indent, "var " + target + " = " + value)
        return target

    # --- models ----------------------------------------------------------

    def name_models(mut self, ir: IrOperations, model: Int, var name: String):
        """Give a model and the models in it their struct names.

        Args:
            ir: The IR.
            model: The model.
            name: The struct name of the model.
        """
        var models: List[Int] = [model]
        var names: List[String] = [name^]
        while len(models) > 0:
            var current = models.pop()
            var current_name = names.pop()
            for child in ir.models[current].models:
                models.append(child)
                names.append(current_name + "_" + ir.models[child].model_name)
            self.names[ir.models[current].id] = current_name^

    def model(mut self, ir: IrOperations, model: Int) raises:
        """Write the struct of a model, then the structs of its models.

        Args:
            ir: The IR.
            model: The model.

        Raises:
            Error: When the model of a property was not generated.
        """
        ref found = ir.models[model]
        var name = self.names[found.id]
        self.out.blank()
        self.out.blank()
        self.out.line(0, "@fieldwise_init")
        self.out.line(0, "struct " + name + "(Copyable, Movable):")
        self.out.docstring(4, "The model " + found.id + ".")
        self.out.blank()
        for ref property in found.properties:
            self.out.line(
                4,
                "var "
                + self.property_name(property.info.response_name)
                + ": "
                + self.mojo_type(property.info.type),
            )
        if len(found.properties) > 0:
            self.out.blank()
        self.out.line(4, "@staticmethod")
        self.out.line(4, "def from_json(")
        self.out.line(
            8,
            "document: JsonDocument, node: Int, false_variables: List[String]",
        )
        self.out.line(4, ") raises -> Self:")
        self.out.docstring(8, "Read the model from a JSON object.")
        var needs_typename = False
        for ref property in found.properties:
            if _has_possible_types(ir.conditions, property.condition):
                needs_typename = True
        if needs_typename:
            self.out.line(8, "var typename = _typename(document, node)")
        var locals = List[String]()
        for ref property in found.properties:
            var local = "f_" + property.info.response_name
            locals.append(_moved(local, property.info.type, 0, True))
            if not property.info.is_synthetic:
                var value = self.temporary("j")
                var getter = "_member(" if property.info.type.is_nullable(
                    0
                ) else "_required("
                self.out.call(
                    8,
                    "var " + value + " = " + getter,
                    [
                        "document",
                        "node",
                        _mojo_string(property.info.response_name),
                    ],
                )
                self.read(8, local, value, property.info.type, 0)
                continue
            var type = property.info.type.copy()
            if property.condition == Conditions.TRUE:
                self.read_named(8, local, "node", type)
                continue
            self.out.call(
                8, "var " + local + " = " + self.mojo_type(type) + "(", ["None"]
            )
            var test = self.condition(8, ir.conditions, property.condition)
            self.out.line(8, "if " + test + ":")
            var inner = self.temporary("t")
            if ir.conditions.first_label(property.condition) >= 0:
                self.out.line(12, "try:")
                self.read_named(16, inner, "node", type)
                self.out.line(16, local + " = " + inner + "^")
                self.out.line(12, "except:")
                self.out.line(16, "pass")
            else:
                self.read_named(12, inner, "node", type)
                self.out.line(12, local + " = " + inner + "^")
        self.out.call(8, "return Self(", locals)
        for child in found.models:
            self.model(ir, child)

    # --- schema types ----------------------------------------------------

    def enum(mut self, schema: Schema, type: Int):
        """Write the struct of an enum, as upstream `EnumAsEnumBuilder`.

        Args:
            schema: The schema.
            type: The enum type.
        """
        ref named = schema.types[type]
        var name = named.name
        var span = named.enum_values
        var count = Int(span.count)
        self.out.blank()
        self.out.blank()
        self.out.line(0, "@fieldwise_init")
        self.out.line(
            0,
            "struct "
            + name
            + "(Equatable, ImplicitlyCopyable, Movable, Writable):",
        )
        self.out.docstring(4, "The enum " + name + ".")
        self.out.blank()
        self.out.line(4, "var value: UInt8")
        self.out.docstring(4, "The index of the value; see `is_valid`.")
        self.out.blank()
        for index in range(count):
            var value = schema.enum_values[Int(span.start) + index].name
            self.out.line(
                4,
                "comptime "
                + escape_mojo_keyword(value)
                + " = "
                + name
                + "("
                + String(index)
                + ")",
            )
        self.out.line(
            4, "comptime UNKNOWN__ = " + name + "(" + String(count) + ")"
        )
        self.out.blank()
        self.out.line(4, "def is_valid(self) -> Bool:")
        self.out.docstring(8, "Return True for a value of the schema.")
        self.out.line(8, "return self.value < " + String(count))
        self.out.blank()
        self.out.line(4, "def raw_value(self) raises -> String:")
        self.out.docstring(8, "Return the name of the value in GraphQL.")
        for index in range(count):
            var value = schema.enum_values[Int(span.start) + index].name
            self.out.line(
                8,
                "if self == " + name + "." + escape_mojo_keyword(value) + ":",
            )
            self.out.line(12, "return " + _mojo_string(value))
        self.out.call(
            8,
            "raise Error(",
            [_mojo_string("the value of " + name + " is not known")],
        )
        self.out.blank()
        self.out.line(4, "@staticmethod")
        self.out.line(4, "def safe_value_of(raw: StringSlice) -> " + name + ":")
        self.out.docstring(8, "Read a value; `UNKNOWN__` for another name.")
        for index in range(count):
            var value = schema.enum_values[Int(span.start) + index].name
            self.out.line(8, "if raw == " + _mojo_string(value) + ":")
            self.out.line(
                12, "return " + name + "." + escape_mojo_keyword(value)
            )
        self.out.line(8, "return " + name + ".UNKNOWN__")
        self.out.blank()
        self.out.line(4, "def write_to(self, mut writer: Some[Writer]):")
        self.out.docstring(8, "Write the name of the value.")
        self.out.line(8, "try:")
        self.out.line(12, "writer.write(self.raw_value())")
        self.out.line(8, "except:")
        self.out.line(12, 'writer.write("UNKNOWN__")')

    def write_value(
        mut self, indent: Int, expression: String, type: IrType, level: Int
    ) raises:
        """Write the statements that write a level of a value as JSON.

        Args:
            indent: The indent.
            expression: The Mojo expression of the value.
            type: The IR type.
            level: The level to write.

        Raises:
            Error: When the model of the type was not generated.
        """
        if type.is_nullable(level):
            self.out.line(indent, "if " + expression + ":")
            self.write_present(indent + 4, expression + ".value()", type, level)
            self.out.line(indent, "else:")
            self.out.line(indent + 4, "writer.null()")
            return
        self.write_present(indent, expression, type, level)

    def write_present(
        mut self, indent: Int, expression: String, type: IrType, level: Int
    ) raises:
        """Write the statements that write a level that is not null.

        Args:
            indent: The indent.
            expression: The Mojo expression of the value.
            type: The IR type.
            level: The level to write.

        Raises:
            Error: When the model of the type was not generated.
        """
        if level < type.lists:
            self.out.line(indent, "writer.begin_array()")
            var item = self.temporary("v")
            self.out.line(indent, "for ref " + item + " in " + expression + ":")
            self.write_value(indent + 4, item, type, level + 1)
            self.out.line(indent, "writer.end_array()")
            return
        if type.kind == TypeKind.ENUM:
            self.out.call(
                indent, "writer.string(", [expression + ".raw_value()"]
            )
        elif type.kind == TypeKind.INPUT_OBJECT:
            self.out.call(indent, expression + ".write_json(", ["writer"])
        elif type.name == "String" or type.name == "ID":
            self.out.call(indent, "writer.string(", [expression])
        elif type.name == "Int":
            self.out.call(indent, "writer.int(", ["Int64(" + expression + ")"])
        elif type.name == "Float":
            self.out.call(indent, "writer.float(", [expression])
        elif type.name == "Boolean":
            self.out.call(indent, "writer.bool(", [expression])
        else:
            self.out.call(indent, "writer.raw(", [expression])

    def input_fields(
        mut self,
        names: List[String],
        types: List[IrType],
        defaults: List[String],
        with_defaults: Bool,
    ) raises:
        """Write the body of a `write_json` method.

        Args:
            names: The GraphQL names of the fields.
            types: Their types.
            defaults: Their default values as JSON, or empty.
            with_defaults: Whether an absent field writes its default.

        Raises:
            Error: When the model of a type was not generated.
        """
        self.out.line(8, "writer.begin_object()")
        for index in range(len(names)):
            var field = "self." + escape_mojo_keyword(names[index])
            ref type = types[index]
            if not type.optional:
                self.out.call(8, "writer.key(", [_mojo_string(names[index])])
                self.write_value(8, field, type, 0)
                continue
            self.out.line(8, "if " + field + ":")
            self.out.call(12, "writer.key(", [_mojo_string(names[index])])
            self.write_value(12, field + ".value()", type, 0)
            if with_defaults and defaults[index] != "":
                self.out.line(8, "elif with_default_values:")
                self.out.call(12, "writer.key(", [_mojo_string(names[index])])
                self.out.call(
                    12, "writer.raw(", [_mojo_string(defaults[index])]
                )
        self.out.line(8, "writer.end_object()")

    def constructor(mut self, names: List[String], types: List[IrType]) raises:
        """Write an `__init__` whose fields that can be absent default to
        absent, after the fields that cannot.

        Args:
            names: The GraphQL names of the fields.
            types: Their types.

        Raises:
            Error: When the model of a type was not generated.
        """
        var parameters: List[String] = ["out self"]
        # The fields that cannot be absent come first, then the others.
        var pass_index = 0
        while pass_index < 2:
            for index in range(len(names)):
                ref type = types[index]
                if type.optional != (pass_index == 1):
                    continue
                var parameter = (
                    escape_mojo_keyword(names[index])
                    + ": "
                    + self.input_type(type)
                )
                if type.optional:
                    parameter += " = None"
                parameters.append(parameter^)
            pass_index += 1
        self.out.call(4, "def __init__(", parameters, "):")
        self.out.docstring(8, "Set every field.")
        if len(names) == 0:
            self.out.line(8, "pass")
        for index in range(len(names)):
            var field = escape_mojo_keyword(names[index])
            self.out.line(8, "self." + field + " = " + field + ".copy()")

    def input_object(mut self, schema: Schema, type: Int) raises:
        """Write the struct of an input object, as upstream
        `InputObjectBuilder`.

        Args:
            schema: The schema.
            type: The input object type.

        Raises:
            Error: When the model of a type was not generated.
        """
        ref named = schema.types[type]
        var names = List[String]()
        var types = List[IrType]()
        var defaults = List[String]()
        var span = named.input_fields
        for index in range(Int(span.start), span.end()):
            ref field = schema.input_values[index]
            var field_type = ir_type(schema, field.type)
            if field_type.is_nullable() or field.has_default():
                field_type = field_type.with_optional(True)
            names.append(field.name)
            types.append(field_type^)
            defaults.append("")
        self.out.blank()
        self.out.blank()
        self.out.line(0, "struct " + named.name + "(Copyable, Movable):")
        self.out.docstring(4, "The input object " + named.name + ".")
        self.out.blank()
        for index in range(len(names)):
            self.out.line(
                4,
                "var "
                + escape_mojo_keyword(names[index])
                + ": "
                + self.input_type(types[index]),
            )
        if len(names) > 0:
            self.out.blank()
        self.constructor(names, types)
        self.out.blank()
        self.out.line(4, "def write_json(self, mut writer: JsonWriter) raises:")
        self.out.docstring(8, "Write the input object as JSON.")
        self.input_fields(names, types, defaults, False)

    # --- operations ------------------------------------------------------

    def variables(mut self, name: String, variables: List[IrVariable]) raises:
        """Write the `Variables` struct of an operation, as upstream
        `VariablesAdapter`.

        Args:
            name: The struct name of the operation.
            variables: The variables.

        Raises:
            Error: When the model of a type was not generated.
        """
        var names = List[String]()
        var types = List[IrType]()
        var defaults = List[String]()
        for ref variable in variables:
            names.append(variable.name)
            types.append(variable.type.copy())
            defaults.append(variable.default_json)
        var struct_name = name + "_Variables"
        self.out.blank()
        self.out.blank()
        self.out.line(0, "struct " + struct_name + "(Copyable, Movable):")
        self.out.docstring(4, "The variables of " + name + ".")
        self.out.blank()
        for index in range(len(names)):
            self.out.line(
                4,
                "var "
                + escape_mojo_keyword(names[index])
                + ": "
                + self.input_type(types[index]),
            )
        if len(names) > 0:
            self.out.blank()
        self.constructor(names, types)
        self.out.blank()
        self.out.line(4, "def write_json(")
        self.out.line(
            8, "self, mut writer: JsonWriter, with_default_values: Bool = False"
        )
        self.out.line(4, ") raises:")
        self.out.docstring(
            8, "Write the variables as JSON, as upstream serializeVariables."
        )
        self.input_fields(names, types, defaults, True)
        self.out.blank()
        self.out.line(4, "def false_variables(self) -> List[String]:")
        self.out.docstring(
            8, "Return the Boolean variables that are false, defaults too."
        )
        self.out.line(8, "var out = List[String]()")
        for index in range(len(names)):
            ref type = types[index]
            if type.name != "Boolean" or type.lists > 0:
                continue
            var field = "self." + escape_mojo_keyword(names[index])
            var literal = _mojo_string(names[index])
            var value = field
            if type.optional:
                self.out.line(8, "if " + field + ":")
                value = field + ".value()"
                if type.is_nullable():
                    self.out.line(
                        12,
                        "if not " + value + ".or_else(True):",
                    )
                else:
                    self.out.line(12, "if not " + value + ":")
                self.out.line(16, "out.append(" + literal + ")")
                if defaults[index] == "false":
                    self.out.line(8, "else:")
                    self.out.line(12, "out.append(" + literal + ")")
            elif type.is_nullable():
                self.out.line(8, "if not " + value + ".or_else(True):")
                self.out.line(12, "out.append(" + literal + ")")
            else:
                self.out.line(8, "if not " + value + ":")
                self.out.line(12, "out.append(" + literal + ")")
        self.out.line(8, "return out^")


def _moved(
    name: String, type: IrType, level: Int, with_nullable: Bool
) -> String:
    """Return `name^`, or `name` when the Mojo type of a level is a trivial
    register type, which a transfer cannot move.

    Args:
        name: The local.
        type: The IR type.
        level: The level that the local holds.
        with_nullable: Whether the local holds the nullable level, an
            `Optional`, rather than the value in it.

    Returns:
        The expression that gives the local away.
    """
    if (
        level == type.lists
        and type.model == ""
        and not (with_nullable and type.is_nullable(level))
        and (
            type.kind == TypeKind.ENUM
            or type.name == "Int"
            or type.name == "Float"
            or type.name == "Boolean"
        )
    ):
        return name
    return name + "^"


def _has_possible_types(conditions: Conditions, condition: Int) -> Bool:
    """Return True when a condition reads `__typename`."""
    ref node = conditions.nodes[condition]
    if node.kind == ConditionKind.POSSIBLE_TYPES:
        return True
    for operand in node.operands:
        if _has_possible_types(conditions, operand):
            return True
    return False


def operation_struct_name(name: StringSlice, type: OperationType) -> String:
    """Return the struct name of an operation, as upstream semantic naming:
    the name with its operation type appended, unless it ends with it.

    Args:
        name: The operation's name, such as `Hero`.
        type: The operation type.

    Returns:
        Such as `HeroQuery`.
    """
    var suffix = capitalize_first_letter(type.text())
    var out = capitalize_first_letter(name)
    if not out.endswith(suffix):
        out += suffix
    return out^


def operation_id(ir: IrOperations, operation: Int) -> String:
    """Return the id of an operation, as upstream: the SHA-256 of its
    minified document, in lowercase hexadecimal.

    Args:
        ir: The IR.
        operation: The operation's index.

    Returns:
        The 64 hexadecimal digits.
    """
    return sha256_hex(minify(ir.operations[operation].source_with_fragments))


def generate_mojo(
    ir: IrOperations, schema: Schema, options: CodegenOptions
) raises -> String:
    """Write the Mojo module of an IR.

    Args:
        ir: The IR of the documents.
        schema: The schema.
        options: The options.

    Returns:
        The source of the module.

    Raises:
        Error: When a model was not built, which the IR builder prevents.
    """
    var generator = _Generator(options)
    for ref fragment in ir.fragments:
        generator.name_models(
            ir, fragment.data_model, ir.models[fragment.data_model].model_name
        )
    var operation_names = List[String]()
    for ref operation in ir.operations:
        var name = operation_struct_name(
            operation.name, operation.operation_type
        )
        generator.name_models(ir, operation.data_model, name + "_Data")
        operation_names.append(name^)

    var out = _Out()
    out.line(0, "# AUTO-GENERATED FILE. DO NOT MODIFY.")
    out.line(0, "#")
    out.line(0, "# gql_codegen wrote this module, as the Apollo Kotlin code")
    out.line(0, "# generator writes Kotlin models.")
    out.blank()
    out.line(0, '"""The operations, their variables and their models."""')
    out.blank()
    out.line(0, "from gql_json.value import JsonDocument, JsonKind")
    out.line(0, "from gql_json.writer import JsonWriter")
    out.text += String(HELPERS)
    generator.out = out^

    for name in ir.used_coordinates.types():
        var type = schema.type_named(name)
        if name.startswith("__"):
            continue
        var kind = schema.types[type].kind
        if kind == TypeKind.ENUM:
            generator.enum(schema, type)
        elif kind == TypeKind.INPUT_OBJECT:
            generator.input_object(schema, type)

    for ref fragment in ir.fragments:
        generator.model(ir, fragment.data_model)

    for index in range(len(ir.operations)):
        ref operation = ir.operations[index]
        var name = operation_names[index]
        generator.out.blank()
        generator.out.blank()
        generator.out.line(0, "struct " + name + ":")
        generator.out.docstring(
            4,
            "The "
            + String(operation.operation_type.text())
            + " "
            + operation.name
            + ".",
        )
        generator.out.blank()
        generator.out.string(
            4, "comptime OPERATION_ID = ", operation_id(ir, index)
        )
        generator.out.string(4, "comptime OPERATION_NAME = ", operation.name)
        generator.out.string(
            4,
            "comptime OPERATION_DOCUMENT = ",
            minify(operation.source_with_fragments),
        )
        generator.out.blank()
        generator.out.line(4, "@staticmethod")
        generator.out.line(4, "def parse_data(")
        generator.out.line(8, "document: JsonDocument,")
        generator.out.line(8, "node: Int,")
        generator.out.line(8, "variables: " + name + "_Variables,")
        generator.out.line(4, ") raises -> " + name + "_Data:")
        generator.out.docstring(8, "Read the data of a response.")
        generator.out.call(
            8,
            "return " + name + "_Data.from_json(",
            ["document", "node", "variables.false_variables()"],
        )
        generator.variables(name, operation.variables)
        generator.model(ir, operation.data_model)
    return generator^.take()
