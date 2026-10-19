# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The diagnostics of apollo-compiler validation.

Port of apollo-compiler 1.33.0 (`b7eee5c`) `src/validation/diagnostics.rs`
and the `DiagnosticList` and `Details` parts of `src/validation/mod.rs`,
under the MIT arm of its MIT OR Apache-2.0 license.

A `Diagnostic` is one upstream `DiagnosticData`: a `DiagnosticKind`, the
text fields of the variant and a primary location. `message` returns the
text of the upstream `#[error(...)]` attribute. A `DiagnosticList` holds
the diagnostics of one validation, and `sort` orders them as upstream
`DiagnosticList::sort` does: by file, then by offset.

**Differences from upstream.**

- A variant keeps its fields as text, in `a` to `f`. Upstream keeps names,
  types and source spans. Only the primary location is kept.
- The schema `BuildError` and the executable `BuildError` are kept as
  their message, under `SCHEMA_BUILD_ERROR` and `EXECUTABLE_BUILD_ERROR`.
- The executable build errors that upstream reports from validation
  (`SubscriptionUsesMultipleFields`, the `@defer` errors and the field
  merging conflicts) are variants of `DiagnosticKind`.
- `write_to` writes `Error: <message>` and the
  `╭─[ file:line:column ]` line of the upstream report. It does not draw
  the labels and the source lines of ariadne.
- A column counts characters, as ariadne does. A file is ranked by the
  order of `DiagnosticList.file`, as upstream ranks a `FileId`.
"""

from gql_language.ast import Document, NO_NODE
from gql_language.source import SourceLocation


struct DiagnosticKind(Equatable, ImplicitlyCopyable, Writable):
    """The variant of a `Diagnostic`: upstream `DiagnosticData` and
    `Details`."""

    var value: UInt8
    """The variant's index; see `is_valid`."""

    comptime UNIQUE_VARIABLE = DiagnosticKind(0)
    """`UniqueVariable`: `a` is the name."""
    comptime UNIQUE_ARGUMENT = DiagnosticKind(1)
    """`UniqueArgument`: `a` is the name."""
    comptime UNIQUE_INPUT_VALUE = DiagnosticKind(2)
    """`UniqueInputValue`: `a` is the name."""
    comptime UNDEFINED_ARGUMENT = DiagnosticKind(3)
    """`UndefinedArgument`: `a` is the name, `b` the coordinate."""
    comptime UNDEFINED_DEFINITION = DiagnosticKind(4)
    """`UndefinedDefinition`: `a` is the name."""
    comptime UNDEFINED_DIRECTIVE = DiagnosticKind(5)
    """`UndefinedDirective`: `a` is the name."""
    comptime UNDEFINED_VARIABLE = DiagnosticKind(6)
    """`UndefinedVariable`: `a` is the name."""
    comptime UNDEFINED_FRAGMENT = DiagnosticKind(7)
    """`UndefinedFragment`: `a` is the name."""
    comptime UNDEFINED_ENUM_VALUE = DiagnosticKind(8)
    """`UndefinedEnumValue`: `a` is the value, `b` the definition."""
    comptime UNDEFINED_INPUT_VALUE = DiagnosticKind(9)
    """`UndefinedInputValue`: `a` is the value, `b` the definition."""
    comptime MISSING_INTERFACE_FIELD = DiagnosticKind(10)
    """`MissingInterfaceField`: `a` name, `b` interface, `c` field."""
    comptime INVALID_IMPLEMENTATION_FIELD_TYPE = DiagnosticKind(11)
    """`InvalidImplementationFieldType`: `a` name, `b` interface, `c`
    field, `d` interface type, `e` actual type."""
    comptime MISSING_INTERFACE_FIELD_ARGUMENT = DiagnosticKind(12)
    """`MissingInterfaceFieldArgument`: `a` name, `b` interface, `c`
    field, `d` argument."""
    comptime INVALID_IMPLEMENTATION_FIELD_ARGUMENT_TYPE = DiagnosticKind(13)
    """`InvalidImplementationFieldArgumentType`: `a` name, `b` interface,
    `c` field, `d` argument, `e` interface type, `f` actual type."""
    comptime EXTRA_REQUIRED_IMPLEMENTATION_FIELD_ARGUMENT = DiagnosticKind(14)
    """`ExtraRequiredImplementationFieldArgument`: `a` name, `b`
    interface, `c` field, `d` argument."""
    comptime REQUIRED_ARGUMENT = DiagnosticKind(15)
    """`RequiredArgument`: `a` is the coordinate."""
    comptime REQUIRED_FIELD = DiagnosticKind(16)
    """`RequiredField`: `a` is the coordinate."""
    comptime TRANSITIVE_IMPLEMENTED_INTERFACES = DiagnosticKind(17)
    """`TransitiveImplementedInterfaces`: `a` interface, `b` via
    interface, `c` missing interface."""
    comptime OUTPUT_TYPE = DiagnosticKind(18)
    """`OutputType`: `a` is the name."""
    comptime INPUT_TYPE = DiagnosticKind(19)
    """`InputType`: `a` is the name."""
    comptime VARIABLE_INPUT_TYPE = DiagnosticKind(20)
    """`VariableInputType`: `a` is the name."""
    comptime QUERY_ROOT_OPERATION_TYPE = DiagnosticKind(21)
    """`QueryRootOperationType`."""
    comptime UNUSED_VARIABLE = DiagnosticKind(22)
    """`UnusedVariable`: `a` is the name."""
    comptime ROOT_OPERATION_OBJECT_TYPE = DiagnosticKind(23)
    """`RootOperationObjectType`: `a` is the name."""
    comptime DUPLICATE_ROOT_OPERATION_TYPE = DiagnosticKind(24)
    """`DuplicateRootOperationType`: `a` is the name."""
    comptime UNION_MEMBER_OBJECT_TYPE = DiagnosticKind(25)
    """`UnionMemberObjectType`: `a` is the name."""
    comptime UNSUPPORTED_LOCATION = DiagnosticKind(26)
    """`UnsupportedLocation`: `a` name, `b` location."""
    comptime UNSUPPORTED_VALUE_TYPE = DiagnosticKind(27)
    """`UnsupportedValueType`: `a` type, `b` the value's description."""
    comptime INT_COERCION_ERROR = DiagnosticKind(28)
    """`IntCoercionError`: `a` is the value."""
    comptime FLOAT_COERCION_ERROR = DiagnosticKind(29)
    """`FloatCoercionError`: `a` is the value."""
    comptime UNIQUE_DIRECTIVE = DiagnosticKind(30)
    """`UniqueDirective`: `a` is the name."""
    comptime MISSING_SUBSELECTION = DiagnosticKind(31)
    """`MissingSubselection`: `a` coordinate, `b` describe type."""
    comptime INVALID_FRAGMENT_TARGET = DiagnosticKind(32)
    """`InvalidFragmentTarget`: `a` the fragment, empty for an inline
    fragment, `b` the type."""
    comptime INVALID_FRAGMENT_SPREAD = DiagnosticKind(33)
    """`InvalidFragmentSpread`: `a` the fragment, empty for an inline
    fragment, `b` the type name, `c` the type condition."""
    comptime UNUSED_FRAGMENT = DiagnosticKind(34)
    """`UnusedFragment`: `a` is the name."""
    comptime DISALLOWED_VARIABLE_USAGE = DiagnosticKind(35)
    """`DisallowedVariableUsage`: `a` variable, `b` variable type, `c`
    argument, `d` argument type."""
    comptime RECURSIVE_DIRECTIVE_DEFINITION = DiagnosticKind(36)
    """`RecursiveDirectiveDefinition`: `a` is the name."""
    comptime RECURSIVE_INTERFACE_DEFINITION = DiagnosticKind(37)
    """`RecursiveInterfaceDefinition`: `a` is the name."""
    comptime RECURSIVE_INPUT_OBJECT_DEFINITION = DiagnosticKind(38)
    """`RecursiveInputObjectDefinition`: `a` is the name."""
    comptime RECURSIVE_FRAGMENT_DEFINITION = DiagnosticKind(39)
    """`RecursiveFragmentDefinition`: `a` is the name."""
    comptime DEEPLY_NESTED_TYPE = DiagnosticKind(40)
    """`DeeplyNestedType`: `a` is the name."""
    comptime RECURSION_ERROR = DiagnosticKind(41)
    """`RecursionError`."""
    comptime EMPTY_FIELD_SET = DiagnosticKind(42)
    """`EmptyFieldSet`: `a` is the type name."""
    comptime EMPTY_VALUE_SET = DiagnosticKind(43)
    """`EmptyValueSet`: `a` is the type name."""
    comptime EMPTY_MEMBER_SET = DiagnosticKind(44)
    """`EmptyMemberSet`: `a` is the type name."""
    comptime EMPTY_INPUT_VALUE_SET = DiagnosticKind(45)
    """`EmptyInputValueSet`: `a` is the type name."""
    comptime RESERVED_NAME = DiagnosticKind(46)
    """`ReservedName`: `a` name, `b` describe."""
    comptime SUBSCRIPTION_USES_MULTIPLE_FIELDS = DiagnosticKind(47)
    """Executable `SubscriptionUsesMultipleFields`: `a` the operation
    name, empty when anonymous."""
    comptime SUBSCRIPTION_USES_INTROSPECTION = DiagnosticKind(48)
    """Executable `SubscriptionUsesIntrospection`: `a` as above."""
    comptime SUBSCRIPTION_USES_CONDITIONAL_SELECTION = DiagnosticKind(49)
    """Executable `SubscriptionUsesConditionalSelection`: `a` as above."""
    comptime DUPLICATE_DEFER_LABEL = DiagnosticKind(50)
    """Executable `DuplicateDeferLabel`: `a` is the label."""
    comptime DEFER_LABEL_MUST_NOT_BE_VARIABLE = DiagnosticKind(51)
    """Executable `DeferLabelMustNotBeVariable`."""
    comptime DEFER_ON_ROOT_SELECTION = DiagnosticKind(52)
    """Executable `DeferOnRootSelection`: `a` the operation type."""
    comptime DEFER_IN_SUBSCRIPTION_MUST_BE_CONDITIONAL = DiagnosticKind(53)
    """Executable `DeferInSubscriptionMustBeConditional`."""
    comptime CONFLICTING_FIELD_TYPE = DiagnosticKind(54)
    """Executable `ConflictingFieldType`: `a` is the alias."""
    comptime CONFLICTING_FIELD_ARGUMENT = DiagnosticKind(55)
    """Executable `ConflictingFieldArgument`: `a` is the alias."""
    comptime CONFLICTING_FIELD_NAME = DiagnosticKind(56)
    """Executable `ConflictingFieldName`: `a` is the alias."""
    comptime SCHEMA_BUILD_ERROR = DiagnosticKind(57)
    """`Details::SchemaBuildError`: `a` is the message."""
    comptime EXECUTABLE_BUILD_ERROR = DiagnosticKind(58)
    """`Details::ExecutableBuildError`: `a` is the message."""
    comptime SYNTAX_ERROR = DiagnosticKind(59)
    """`Details::SyntaxError`: `a` is the message."""
    comptime RECURSION_LIMIT_ERROR = DiagnosticKind(60)
    """`Details::RecursionLimitError`."""
    comptime PARSER_LIMIT = DiagnosticKind(61)
    """`Details::ParserLimit`: `a` is the message."""

    @always_inline
    def __init__(out self, value: UInt8):
        """Make a diagnostic kind from its index.

        Args:
            value: The index.
        """
        self.value = value

    def is_valid(self) -> Bool:
        """Return True for one of the 62 variants.

        Returns:
            Whether the index names a variant.
        """
        return self.value <= 61

    def write_to(self, mut writer: Some[Writer]):
        """Write the index of the variant.

        Args:
            writer: The writer.
        """
        writer.write("DiagnosticKind(", self.value, ")")


def _name_or_anon(
    name: String, prefix: StaticString, if_none: StaticString
) -> String:
    """Return upstream `NameOrAnon`: the prefix and the quoted name, or the
    text for no name."""
    if name.byte_length() == 0:
        return String(if_none)
    return String(prefix, " `", name, "`")


struct Diagnostic(Copyable, Movable, Writable):
    """One diagnostic: upstream `DiagnosticData`, its `Details` and its
    primary location."""

    var kind: DiagnosticKind
    """The variant."""
    var file: Int
    """The rank of the file in `DiagnosticList.files`, or -1 when the
    diagnostic has no location."""
    var offset: Int
    """The byte offset of the primary location in the file."""
    var line: Int
    """The one-based line, or 0 before `DiagnosticList.locate`."""
    var column: Int
    """The one-based column in characters, or 0 before `locate`."""
    var a: String
    """The first text field; see `DiagnosticKind`."""
    var b: String
    """The second text field."""
    var c: String
    """The third text field."""
    var d: String
    """The fourth text field."""
    var e: String
    """The fifth text field."""
    var f: String
    """The sixth text field."""

    def __init__(
        out self,
        kind: DiagnosticKind,
        file: Int,
        offset: Int,
        a: String = String(),
        b: String = String(),
        c: String = String(),
        d: String = String(),
        e: String = String(),
        f: String = String(),
    ):
        """Make a diagnostic with no line and column yet.

        Args:
            kind: The variant.
            file: The rank of the file, or -1 for no location.
            offset: The byte offset of the primary location.
            a: The first text field.
            b: The second text field.
            c: The third text field.
            d: The fourth text field.
            e: The fifth text field.
            f: The sixth text field.
        """
        self.kind = kind
        self.file = file
        self.offset = offset
        self.line = 0
        self.column = 0
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.e = e
        self.f = f

    def message(self) -> String:
        """Return the upstream message.

        Returns:
            The text of the upstream `#[error(...)]` attribute.
        """
        var k = Int(self.kind.value)
        if k < 16:
            return self._message_0(k)
        if k < 32:
            return self._message_16(k)
        if k < 47:
            return self._message_32(k)
        return self._message_47(k)

    def _message_0(self, k: Int) -> String:
        """Return the message of the variants 0 to 15."""
        if k == 0:
            return String(
                "the variable `$", self.a, "` is declared multiple times"
            )
        if k == 1:
            return String(
                "the argument `", self.a, "` is provided multiple times"
            )
        if k == 2:
            return String("the value `", self.a, "` is defined multiple times")
        if k == 3:
            return String(
                "the argument `", self.a, "` is not supported by `", self.b, "`"
            )
        if k == 4:
            return String("cannot find type `", self.a, "` in this document")
        if k == 5:
            return String(
                "cannot find directive `@", self.a, "` in this document"
            )
        if k == 6:
            return String("variable `$", self.a, "` is not defined")
        if k == 7:
            return String(
                "cannot find fragment `", self.a, "` in this document"
            )
        if k == 8:
            return String(
                "value `", self.a, "` does not exist on `", self.b, "`"
            )
        if k == 9:
            return String(
                "field `", self.a, "` does not exist on `", self.b, "`"
            )
        if k == 10:
            return String(
                "type `",
                self.a,
                "` does not satisfy interface `",
                self.b,
                "`: missing field `",
                self.c,
                "`",
            )
        if k == 11:
            return String(
                "interface field `",
                self.b,
                ".",
                self.c,
                "` expects type `",
                self.d,
                "` but `",
                self.a,
                ".",
                self.c,
                "` of type `",
                self.e,
                "` is not a proper subtype",
            )
        if k == 12:
            return String(
                "interface field `",
                self.b,
                ".",
                self.c,
                "` expects argument `",
                self.d,
                "` but `",
                self.a,
                ".",
                self.c,
                "` does not provide it",
            )
        if k == 13:
            return String(
                "interface field `",
                self.b,
                ".",
                self.c,
                "` expects argument `",
                self.d,
                "` of type `",
                self.e,
                "` but `",
                self.a,
                ".",
                self.c,
                "` provides type `",
                self.f,
                "`",
            )
        if k == 14:
            return String(
                "`",
                self.a,
                ".",
                self.c,
                "` has extra required argument `",
                self.d,
                "` not present in interface `",
                self.b,
                ".",
                self.c,
                "`",
            )
        return String("the required argument `", self.a, "` is not provided")

    def _message_16(self, k: Int) -> String:
        """Return the message of the variants 16 to 31."""
        if k == 16:
            return String("the required field `", self.a, "` is not provided")
        if k == 17:
            return String(
                "interface `",
                self.a,
                "` declares that it implements `",
                self.b,
                "`, but to do so it must also implement `",
                self.c,
                "`",
            )
        if k == 18:
            return String("`", self.a, "` field must return an output type")
        if k == 19:
            return String("`", self.a, "` field must be of an input type")
        if k == 20:
            return String("`$", self.a, "` variable must be of an input type")
        if k == 21:
            return String(
                "missing query root operation type in schema definition"
            )
        if k == 22:
            return String("unused variable: `$", self.a, "`")
        if k == 23:
            return String("`", self.a, "` field must return an object type")
        if k == 24:
            return String(
                "the same type `",
                self.a,
                "` must not be used for multiple root operation types",
            )
        if k == 25:
            return String("union member `", self.a, "` must be an object type")
        if k == 26:
            return String(
                self.a, " directive is not supported for ", self.b, " location"
            )
        if k == 27:
            return String("expected value of type ", self.a, ", found ", self.b)
        if k == 28:
            return String(
                "int cannot represent non 32-bit signed integer value"
            )
        if k == 29:
            return String(
                "float cannot represent non-finite 64-bit floating point value"
            )
        if k == 30:
            return String(
                "non-repeatable directive ",
                self.a,
                " can only be used once per location",
            )
        return String(
            "interface, union and object types must have a subselection set"
        )

    def _message_32(self, k: Int) -> String:
        """Return the message of the variants 32 to 46."""
        if k == 32:
            return String(
                _name_or_anon(self.a, "fragment", "inline fragment"),
                " must have a composite type in its type condition",
            )
        if k == 33:
            return String(
                _name_or_anon(self.a, "fragment", "inline fragment"),
                " with type condition `",
                self.c,
                "` cannot be applied to `",
                self.b,
                "`",
            )
        if k == 34:
            return String(
                "fragment `", self.a, "` must be used in an operation"
            )
        if k == 35:
            return String(
                "variable `$",
                self.a,
                "` of type `",
                self.b,
                "` cannot be used for argument `",
                self.c,
                "` of type `",
                self.d,
                "`",
            )
        if k == 36:
            return String(
                "`", self.a, "` directive definition cannot reference itself"
            )
        if k == 37:
            return String("interface ", self.a, " cannot implement itself")
        if k == 38:
            return String("`", self.a, "` input object cannot reference itself")
        if k == 39:
            return String("`", self.a, "` fragment cannot reference itself")
        if k == 40:
            return String("`", self.a, "` contains too much nesting")
        if k == 41:
            return String("too much recursion")
        if k == 42:
            return String("`", self.a, "` has no fields")
        if k == 43:
            return String("`", self.a, "` has no enum values")
        if k == 44:
            return String("`", self.a, "` has no member types")
        if k == 45:
            return String("`", self.a, "` has no input values")
        return String(
            self.b,
            " cannot be named `",
            self.a,
            "` as names starting with two underscores are reserved",
        )

    def _message_47(self, k: Int) -> String:
        """Return the message of the variants 47 to 61."""
        if k == 47:
            return String(
                _name_or_anon(self.a, "subscription", "anonymous subscription"),
                " can only have one root field",
            )
        if k == 48:
            return String(
                _name_or_anon(self.a, "subscription", "anonymous subscription"),
                " can not have an introspection field as a root field",
            )
        if k == 49:
            return String(
                _name_or_anon(self.a, "subscription", "anonymous subscription"),
                " can not specify @skip or @include on root fields",
            )
        if k == 50:
            return String(
                "`@defer` label `",
                self.a,
                "` is not unique within the document",
            )
        if k == 51:
            return String(
                "`@defer` label argument must be a static String, not a"
                " variable"
            )
        if k == 52:
            return String(
                "`@defer` is not allowed on root selections of ",
                self.a,
                " operations",
            )
        if k == 53:
            return String(
                "`@defer` in a subscription operation must be disabled with an"
                " `if` argument"
            )
        if k == 54:
            return String(
                (
                    "operation must not select different types using the same"
                    " name `"
                ),
                self.a,
                "`",
            )
        if k == 55:
            return String(
                (
                    "operation must not provide conflicting field arguments for"
                    " the same name `"
                ),
                self.a,
                "`",
            )
        if k == 56:
            return String(
                "cannot select different fields into the same alias `",
                self.a,
                "`",
            )
        if k == 59:
            return String("syntax error: ", self.a)
        if k == 60:
            return String("too much recursion")
        return self.a.copy()

    def write_to(self, mut writer: Some[Writer]):
        """Write `Error: ` and the message, as the first line of the upstream
        report.

        Args:
            writer: The writer.
        """
        writer.write("Error: ", self.message())


struct DiagnosticList(Copyable, Movable, Sized, Writable):
    """The diagnostics of a validation: upstream `DiagnosticList`."""

    var diagnostics: List[Diagnostic]
    """The diagnostics, in the order they were found until `sort`."""
    var files: List[String]
    """The file names. A diagnostic's `file` is an index into this list."""

    def __init__(out self):
        """Make an empty list."""
        self.diagnostics = List[Diagnostic]()
        self.files = List[String]()

    def file(mut self, name: StringSlice) -> Int:
        """Return the rank of a file, and add it when it is new.

        Upstream ranks a file by its `FileId`, in the order the files were
        parsed. Two documents with the same name are one file, as the
        schema and the executable document of `parse_mixed_validate` are.

        Args:
            name: The file name.

        Returns:
            The index of the name in `files`.
        """
        var i = 0
        while i < len(self.files):
            if self.files[i] == name:
                return i
            i += 1
        self.files.append(String(name))
        return len(self.files) - 1

    def push(mut self, var diagnostic: Diagnostic):
        """Add a diagnostic.

        Args:
            diagnostic: The diagnostic.
        """
        self.diagnostics.append(diagnostic^)

    def __len__(self) -> Int:
        """Return the number of diagnostics.

        Returns:
            The count.
        """
        return len(self.diagnostics)

    def is_empty(self) -> Bool:
        """Return True when the list has no diagnostic.

        Returns:
            Whether the validation found nothing.
        """
        return len(self.diagnostics) == 0

    def sort(mut self):
        """Order the diagnostics by file, then by offset: upstream
        `DiagnosticList::sort`.

        A diagnostic with no location comes first. The sort is stable, as
        upstream `sort_by_key` is.
        """
        var n = len(self.diagnostics)
        if n < 2:
            return
        var order = List[Int](capacity=n)
        var i = 0
        while i < n:
            order.append(i)
            i += 1
        var scratch = order.copy()
        _merge_sort(self.diagnostics, order, scratch, 0, n)
        var sorted = List[Diagnostic](capacity=n)
        i = 0
        while i < n:
            sorted.append(self.diagnostics[order[i]].copy())
            i += 1
        self.diagnostics = sorted^

    def locate(mut self, file: Int, document: Document):
        """Set the line and the column of the diagnostics in one file.

        Call it after `sort`. It reads the source once, from the first
        offset to the last.

        Args:
            file: The rank of the file.
            document: The document of the file.
        """
        var line = 1
        var column = 1
        var at = 0
        var length = document.source.length
        var i = 0
        while i < len(self.diagnostics):
            if self.diagnostics[i].file == file:
                var target = min(self.diagnostics[i].offset, length)
                while at < target:
                    var byte = document.source.bytes[at]
                    if byte == 10:
                        line += 1
                        column = 1
                    elif byte == 13:
                        if (
                            at + 1 < length
                            and document.source.bytes[at + 1] == 10
                        ):
                            pass
                        else:
                            line += 1
                            column = 1
                    elif (byte & 0xC0) != 0x80:
                        column += 1
                    at += 1
                self.diagnostics[i].line = line
                self.diagnostics[i].column = column
            i += 1

    def write_to(self, mut writer: Some[Writer]):
        """Write each diagnostic as `Error: <message>`, and the
        `╭─[ file:line:column ]` line of its location.

        Args:
            writer: The writer.
        """
        for ref diagnostic in self.diagnostics:
            writer.write(diagnostic, "\n")
            if diagnostic.file >= 0:
                writer.write(
                    "╭─[ ",
                    self.files[diagnostic.file],
                    ":",
                    diagnostic.line,
                    ":",
                    diagnostic.column,
                    " ]\n",
                )


def _before(a: Diagnostic, b: Diagnostic) -> Bool:
    """Return True when `a` sorts strictly before `b`."""
    if a.file != b.file:
        return a.file < b.file
    return a.offset < b.offset


def _merge_sort(
    diagnostics: List[Diagnostic],
    mut order: List[Int],
    mut scratch: List[Int],
    start: Int,
    end: Int,
):
    """Sort `order[start:end]` by the diagnostics it names, stably."""
    if end - start < 2:
        return
    var middle = (start + end) // 2
    _merge_sort(diagnostics, order, scratch, start, middle)
    _merge_sort(diagnostics, order, scratch, middle, end)
    var left = start
    var right = middle
    var out = start
    while out < end:
        if right >= end or (
            left < middle
            and not _before(diagnostics[order[right]], diagnostics[order[left]])
        ):
            scratch[out] = order[left]
            left += 1
        else:
            scratch[out] = order[right]
            right += 1
        out += 1
    var i = start
    while i < end:
        order[i] = scratch[i]
        i += 1
