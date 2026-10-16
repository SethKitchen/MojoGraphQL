# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Where a directive can appear. Port of graphql-js 16.14.2
`language/directiveLocation.ts`."""

comptime _NAMES: Array[StaticString, 20] = [
    "QUERY",
    "MUTATION",
    "SUBSCRIPTION",
    "FIELD",
    "FRAGMENT_DEFINITION",
    "FRAGMENT_SPREAD",
    "INLINE_FRAGMENT",
    "VARIABLE_DEFINITION",
    "SCHEMA",
    "SCALAR",
    "OBJECT",
    "FIELD_DEFINITION",
    "ARGUMENT_DEFINITION",
    "INTERFACE",
    "UNION",
    "ENUM",
    "ENUM_VALUE",
    "INPUT_OBJECT",
    "INPUT_FIELD_DEFINITION",
    "DIRECTIVE_DEFINITION",
]


@fieldwise_init
struct DirectiveLocation(Equatable, ImplicitlyCopyable, Writable):
    """A place in a document where a directive can be used."""

    var value: UInt8
    """The location's index; see `is_valid`."""

    comptime QUERY = DirectiveLocation(0)
    """The `QUERY` location."""
    comptime MUTATION = DirectiveLocation(1)
    """The `MUTATION` location."""
    comptime SUBSCRIPTION = DirectiveLocation(2)
    """The `SUBSCRIPTION` location."""
    comptime FIELD = DirectiveLocation(3)
    """The `FIELD` location."""
    comptime FRAGMENT_DEFINITION = DirectiveLocation(4)
    """The `FRAGMENT_DEFINITION` location."""
    comptime FRAGMENT_SPREAD = DirectiveLocation(5)
    """The `FRAGMENT_SPREAD` location."""
    comptime INLINE_FRAGMENT = DirectiveLocation(6)
    """The `INLINE_FRAGMENT` location."""
    comptime VARIABLE_DEFINITION = DirectiveLocation(7)
    """The `VARIABLE_DEFINITION` location."""
    comptime SCHEMA = DirectiveLocation(8)
    """The `SCHEMA` location."""
    comptime SCALAR = DirectiveLocation(9)
    """The `SCALAR` location."""
    comptime OBJECT = DirectiveLocation(10)
    """The `OBJECT` location."""
    comptime FIELD_DEFINITION = DirectiveLocation(11)
    """The `FIELD_DEFINITION` location."""
    comptime ARGUMENT_DEFINITION = DirectiveLocation(12)
    """The `ARGUMENT_DEFINITION` location."""
    comptime INTERFACE = DirectiveLocation(13)
    """The `INTERFACE` location."""
    comptime UNION = DirectiveLocation(14)
    """The `UNION` location."""
    comptime ENUM = DirectiveLocation(15)
    """The `ENUM` location."""
    comptime ENUM_VALUE = DirectiveLocation(16)
    """The `ENUM_VALUE` location."""
    comptime INPUT_OBJECT = DirectiveLocation(17)
    """The `INPUT_OBJECT` location."""
    comptime INPUT_FIELD_DEFINITION = DirectiveLocation(18)
    """The `INPUT_FIELD_DEFINITION` location."""
    comptime DIRECTIVE_DEFINITION = DirectiveLocation(19)
    """The `DIRECTIVE_DEFINITION` location."""
    comptime COUNT = 20
    """How many directive locations there are."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the 20 locations.

        Returns:
            Whether the value is in range.
        """
        return Int(self.value) < DirectiveLocation.COUNT

    def is_executable(self) -> Bool:
        """Return True for a location in an executable document.

        Returns:
            Whether the location is `QUERY` through `VARIABLE_DEFINITION`.
        """
        return self.value <= 7

    def text(self) -> StaticString:
        """Return the location's name, such as `FIELD_DEFINITION`.

        Returns:
            The name, or `<invalid>`.
        """
        if not self.is_valid():
            return "<invalid>"
        return materialize[_NAMES]()[Int(self.value)]

    @staticmethod
    def from_name(name: StringSlice) -> Int:
        """Return the index of the location with a name.

        Args:
            name: A location name, such as `FIELD`.

        Returns:
            The location's index, or -1 when no location has the name.
        """
        var index = 0
        while index < DirectiveLocation.COUNT:
            if name == materialize[_NAMES]()[index]:
                return index
            index += 1
        return -1

    def write_to(self, mut writer: Some[Writer]):
        """Write the location's name.

        Args:
            writer: The destination.
        """
        writer.write(self.text())
