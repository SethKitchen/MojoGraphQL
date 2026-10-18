# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The options of the code generator.

Port of the options of Apollo Kotlin `apollo-compiler` `Options.kt` that
change the IR or the operation ids: `addTypename`, `codegenModels`,
`generateOptionalOperationVariables`, `flattenModels`,
`decapitalizeFields` and `failOnWarnings`, with the upstream defaults.

**Differences from upstream.**

- `codegenModels` has one value, `operationBased`, the upstream default.
  `responseBased` and `experimental_operationBasedWithInterfaces` are not
  ported, and `CodegenModels.parse` refuses them.
- The options of the Kotlin and Java output (package names, nullability
  styles, builders, generated methods) do not exist: the output is Mojo.
"""


@fieldwise_init
struct AddTypename(Equatable, ImplicitlyCopyable, Writable):
    """When the generator adds `__typename` to a selection set, as Apollo
    `addTypename`."""

    var value: UInt8
    """The mode's index; see `is_valid`."""

    comptime IF_FRAGMENTS = AddTypename(0)
    """`ifFragments`, the default: in each selection set with a fragment."""
    comptime IF_POLYMORPHIC = AddTypename(1)
    """`ifPolymorphic`: in each field selection set whose fragments can
    match another type than the field's type."""
    comptime IF_ABSTRACT = AddTypename(2)
    """`ifAbstract`: in each field selection set of an interface or a
    union."""
    comptime ALWAYS = AddTypename(3)
    """`always`: in each field selection set and each fragment."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the four modes.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 3

    def text(self) -> StaticString:
        """Return the upstream name of the mode, such as `ifFragments`.

        Returns:
            The name, or `<invalid>`.
        """
        if self == AddTypename.IF_FRAGMENTS:
            return "ifFragments"
        if self == AddTypename.IF_POLYMORPHIC:
            return "ifPolymorphic"
        if self == AddTypename.IF_ABSTRACT:
            return "ifAbstract"
        if self == AddTypename.ALWAYS:
            return "always"
        return "<invalid>"

    @staticmethod
    def parse(text: StringSlice) raises -> AddTypename:
        """Read an upstream mode name.

        Args:
            text: Such as `ifFragments`.

        Returns:
            The mode.

        Raises:
            Error: `Unknown addTypename option: <text>`, as upstream.
        """
        var index = 0
        while index < 4:
            var mode = AddTypename(UInt8(index))
            if text == mode.text():
                return mode
            index += 1
        raise Error("Unknown addTypename option: " + String(text))

    def write_to(self, mut writer: Some[Writer]):
        """Write the upstream name of the mode.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct CodegenModels(Equatable, ImplicitlyCopyable, Writable):
    """The shape of the generated models, as Apollo `codegenModels`."""

    var value: UInt8
    """The shape's index; see `is_valid`."""

    comptime OPERATION_BASED = CodegenModels(0)
    """`operationBased`: the models follow the operation, and each
    fragment becomes a synthetic field."""

    def is_valid(self) -> Bool:
        """Return True if the value names a ported shape.

        Returns:
            Whether the value is `OPERATION_BASED`.
        """
        return self.value == 0

    def text(self) -> StaticString:
        """Return the upstream name of the shape.

        Returns:
            `operationBased`, or `<invalid>`.
        """
        if self.is_valid():
            return "operationBased"
        return "<invalid>"

    @staticmethod
    def parse(text: StringSlice) raises -> CodegenModels:
        """Read an upstream shape name.

        Args:
            text: Such as `operationBased`.

        Returns:
            The shape.

        Raises:
            Error: `codegenModels='<text>' is not supported`, as upstream.
        """
        if text == "operationBased":
            return CodegenModels.OPERATION_BASED
        raise Error("codegenModels='" + String(text) + "' is not supported")

    def write_to(self, mut writer: Some[Writer]):
        """Write the upstream name of the shape.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct CodegenOptions(Copyable, ImplicitlyCopyable, Movable):
    """The options of one compilation, as Apollo `IrOptions`."""

    var add_typename: AddTypename
    """When to add `__typename`; `ifFragments` by default."""
    var codegen_models: CodegenModels
    """The shape of the models; `operationBased`."""
    var generate_optional_operation_variables: Bool
    """Whether a nullable variable without a default value can be absent;
    True by default, as upstream."""
    var flatten_models: Bool
    """Whether the models are flat; True by default for `operationBased`.
    When True, only fragments are checked for capitalized fields."""
    var decapitalize_fields: Bool
    """Whether capitalized fields are allowed because their properties are
    decapitalized; False by default. The check of capitalized fields is
    skipped when it is True."""
    var fail_on_warnings: Bool
    """Whether a warning fails the compilation; False by default."""

    def __init__(out self):
        """Make the upstream defaults."""
        self.add_typename = AddTypename.IF_FRAGMENTS
        self.codegen_models = CodegenModels.OPERATION_BASED
        self.generate_optional_operation_variables = True
        self.flatten_models = True
        self.decapitalize_fields = False
        self.fail_on_warnings = False
