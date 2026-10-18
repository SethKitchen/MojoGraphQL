# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The error codes of composition.

They are the `extensions.code` strings of Hive Federation Composition
v0.27.0.

Upstream puts a code string into the `extensions` of each `GraphQLError`.
This port keeps the code as an `ErrorCode` value; `text()` gives the
upstream string.

**Differences from upstream.** `NONE` stands for an error without a code.
Upstream gives such an error no `extensions.code`.
"""

from gql_language.error import quote_json_string


@fieldwise_init
struct ErrorCode(Equatable, ImplicitlyCopyable, Writable):
    """The `extensions.code` of a composition error."""

    var value: UInt8
    """The code's index; see `is_valid`."""

    comptime NONE = ErrorCode(0)
    """No code."""
    comptime INVALID_GRAPHQL = ErrorCode(1)
    """`INVALID_GRAPHQL`."""
    comptime INVALID_LINK_DIRECTIVE_USAGE = ErrorCode(2)
    """`INVALID_LINK_DIRECTIVE_USAGE`."""
    comptime INVALID_LINK_IDENTIFIER = ErrorCode(3)
    """`INVALID_LINK_IDENTIFIER`."""
    comptime UNKNOWN_LINK_VERSION = ErrorCode(4)
    """`UNKNOWN_LINK_VERSION`."""
    comptime UNKNOWN_FEDERATION_LINK_VERSION = ErrorCode(5)
    """`UNKNOWN_FEDERATION_LINK_VERSION`."""
    comptime EXTERNAL_UNUSED = ErrorCode(6)
    """`EXTERNAL_UNUSED`."""
    comptime INVALID_SUBGRAPH_NAME = ErrorCode(7)
    """`INVALID_SUBGRAPH_NAME`."""
    comptime TYPE_DEFINITION_INVALID = ErrorCode(8)
    """`TYPE_DEFINITION_INVALID`."""
    comptime DIRECTIVE_DEFINITION_INVALID = ErrorCode(9)
    """`DIRECTIVE_DEFINITION_INVALID`."""
    comptime KEY_UNSUPPORTED_ON_INTERFACE = ErrorCode(10)
    """`KEY_UNSUPPORTED_ON_INTERFACE`."""
    comptime KEY_INVALID_FIELDS_TYPE = ErrorCode(11)
    """`KEY_INVALID_FIELDS_TYPE`."""
    comptime KEY_INVALID_FIELDS = ErrorCode(12)
    """`KEY_INVALID_FIELDS`."""
    comptime KEY_DIRECTIVE_IN_FIELDS_ARG = ErrorCode(13)
    """`KEY_DIRECTIVE_IN_FIELDS_ARG`."""
    comptime KEY_FIELDS_HAS_ARGS = ErrorCode(14)
    """`KEY_FIELDS_HAS_ARGS`."""
    comptime KEY_FIELDS_SELECT_INVALID_TYPE = ErrorCode(15)
    """`KEY_FIELDS_SELECT_INVALID_TYPE`."""
    comptime INTERFACE_KEY_NOT_ON_IMPLEMENTATION = ErrorCode(16)
    """`INTERFACE_KEY_NOT_ON_IMPLEMENTATION`."""
    comptime PROVIDES_ON_NON_OBJECT_FIELD = ErrorCode(17)
    """`PROVIDES_ON_NON_OBJECT_FIELD`."""
    comptime PROVIDES_UNSUPPORTED_ON_INTERFACE = ErrorCode(18)
    """`PROVIDES_UNSUPPORTED_ON_INTERFACE`."""
    comptime PROVIDES_INVALID_FIELDS_TYPE = ErrorCode(19)
    """`PROVIDES_INVALID_FIELDS_TYPE`."""
    comptime PROVIDES_INVALID_FIELDS = ErrorCode(20)
    """`PROVIDES_INVALID_FIELDS`."""
    comptime PROVIDES_DIRECTIVE_IN_FIELDS_ARG = ErrorCode(21)
    """`PROVIDES_DIRECTIVE_IN_FIELDS_ARG`."""
    comptime PROVIDES_FIELDS_HAS_ARGS = ErrorCode(22)
    """`PROVIDES_FIELDS_HAS_ARGS`."""
    comptime PROVIDES_FIELDS_MISSING_EXTERNAL = ErrorCode(23)
    """`PROVIDES_FIELDS_MISSING_EXTERNAL`."""
    comptime REQUIRES_UNSUPPORTED_ON_INTERFACE = ErrorCode(24)
    """`REQUIRES_UNSUPPORTED_ON_INTERFACE`."""
    comptime REQUIRES_INVALID_FIELDS_TYPE = ErrorCode(25)
    """`REQUIRES_INVALID_FIELDS_TYPE`."""
    comptime REQUIRES_INVALID_FIELDS = ErrorCode(26)
    """`REQUIRES_INVALID_FIELDS`."""
    comptime REQUIRES_DIRECTIVE_IN_FIELDS_ARG = ErrorCode(27)
    """`REQUIRES_DIRECTIVE_IN_FIELDS_ARG`."""
    comptime REQUIRES_FIELDS_MISSING_EXTERNAL = ErrorCode(28)
    """`REQUIRES_FIELDS_MISSING_EXTERNAL`."""
    comptime MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL = ErrorCode(29)
    """`MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL`."""
    comptime INVALID_SHAREABLE_USAGE = ErrorCode(30)
    """`INVALID_SHAREABLE_USAGE`."""
    comptime UNSUPPORTED_FEATURE = ErrorCode(31)
    """`UNSUPPORTED_FEATURE`."""
    comptime INTERFACE_OBJECT_USAGE_ERROR = ErrorCode(32)
    """`INTERFACE_OBJECT_USAGE_ERROR`."""
    comptime OVERRIDE_ON_INTERFACE = ErrorCode(33)
    """`OVERRIDE_ON_INTERFACE`."""
    comptime OVERRIDE_LABEL_INVALID = ErrorCode(34)
    """`OVERRIDE_LABEL_INVALID`."""
    comptime OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE = ErrorCode(35)
    """`OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE`."""
    comptime OVERRIDE_FROM_SELF_ERROR = ErrorCode(36)
    """`OVERRIDE_FROM_SELF_ERROR`."""
    comptime QUERY_ROOT_TYPE_INACCESSIBLE = ErrorCode(37)
    """`QUERY_ROOT_TYPE_INACCESSIBLE`."""
    comptime ROOT_QUERY_USED = ErrorCode(38)
    """`ROOT_QUERY_USED`."""
    comptime ROOT_MUTATION_USED = ErrorCode(39)
    """`ROOT_MUTATION_USED`."""
    comptime ROOT_SUBSCRIPTION_USED = ErrorCode(40)
    """`ROOT_SUBSCRIPTION_USED`."""
    comptime DIRECTIVE_COMPOSITION_ERROR = ErrorCode(41)
    """`DIRECTIVE_COMPOSITION_ERROR`."""
    comptime CONTEXT_NAME_INVALID = ErrorCode(42)
    """`CONTEXT_NAME_INVALID`."""
    comptime CONTEXT_NOT_SET = ErrorCode(43)
    """`CONTEXT_NOT_SET`."""
    comptime NO_CONTEXT_IN_SELECTION = ErrorCode(44)
    """`NO_CONTEXT_IN_SELECTION`."""
    comptime CONTEXT_INVALID_SELECTION = ErrorCode(45)
    """`CONTEXT_INVALID_SELECTION`."""
    comptime CONTEXT_NO_RESOLVABLE_KEY = ErrorCode(46)
    """`CONTEXT_NO_RESOLVABLE_KEY`."""
    comptime AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE = ErrorCode(47)
    """`AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE`."""
    comptime DIRECTIVE_COST_INVALID_WEIGHT = ErrorCode(48)
    """`DIRECTIVE_COST_INVALID_WEIGHT`."""
    comptime COST_APPLIED_TO_INTERFACE_FIELD = ErrorCode(49)
    """`COST_APPLIED_TO_INTERFACE_FIELD`."""
    comptime LIST_SIZE_INVALID_ASSUMED_SIZE = ErrorCode(50)
    """`LIST_SIZE_INVALID_ASSUMED_SIZE`."""
    comptime LIST_SIZE_INVALID_SLICING_ARGUMENT = ErrorCode(51)
    """`LIST_SIZE_INVALID_SLICING_ARGUMENT`."""
    comptime LIST_SIZE_INVALID_SIZED_FIELD = ErrorCode(52)
    """`LIST_SIZE_INVALID_SIZED_FIELD`."""
    comptime LIST_SIZE_APPLIED_TO_NON_LIST = ErrorCode(53)
    """`LIST_SIZE_APPLIED_TO_NON_LIST`."""
    comptime LIST_SIZE_INVALID_REQUIRE_ONE_SLICING_ARGUMENT = ErrorCode(54)
    """`LIST_SIZE_INVALID_REQUIRE_ONE_SLICING_ARGUMENT`."""
    comptime LINK_IMPORT_NAME_MISMATCH = ErrorCode(55)
    """`LINK_IMPORT_NAME_MISMATCH`."""
    comptime NO_QUERIES = ErrorCode(56)
    """`NO_QUERIES`."""
    comptime TYPE_KIND_MISMATCH = ErrorCode(57)
    """`TYPE_KIND_MISMATCH`."""
    comptime FIELD_TYPE_MISMATCH = ErrorCode(58)
    """`FIELD_TYPE_MISMATCH`."""
    comptime INVALID_FIELD_SHARING = ErrorCode(59)
    """`INVALID_FIELD_SHARING`."""
    comptime EXTENSION_WITH_NO_BASE = ErrorCode(60)
    """`EXTENSION_WITH_NO_BASE`."""
    comptime FIELD_ARGUMENT_TYPE_MISMATCH = ErrorCode(61)
    """`FIELD_ARGUMENT_TYPE_MISMATCH`."""
    comptime ENUM_VALUE_MISMATCH = ErrorCode(62)
    """`ENUM_VALUE_MISMATCH`."""
    comptime EMPTY_MERGED_ENUM_TYPE = ErrorCode(63)
    """`EMPTY_MERGED_ENUM_TYPE`."""
    comptime OVERRIDE_SOURCE_HAS_OVERRIDE = ErrorCode(64)
    """`OVERRIDE_SOURCE_HAS_OVERRIDE`."""
    comptime EXTERNAL_MISSING_ON_BASE = ErrorCode(65)
    """`EXTERNAL_MISSING_ON_BASE`."""
    comptime EMPTY_MERGED_INPUT_TYPE = ErrorCode(66)
    """`EMPTY_MERGED_INPUT_TYPE`."""
    comptime REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH = ErrorCode(67)
    """`REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH`."""
    comptime REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH = ErrorCode(68)
    """`REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH`."""
    comptime EXTERNAL_ARGUMENT_MISSING = ErrorCode(69)
    """`EXTERNAL_ARGUMENT_MISSING`."""
    comptime INPUT_FIELD_DEFAULT_MISMATCH = ErrorCode(70)
    """`INPUT_FIELD_DEFAULT_MISMATCH`."""
    comptime FIELD_ARGUMENT_DEFAULT_MISMATCH = ErrorCode(71)
    """`FIELD_ARGUMENT_DEFAULT_MISMATCH`."""
    comptime DEFAULT_VALUE_USES_INACCESSIBLE = ErrorCode(72)
    """`DEFAULT_VALUE_USES_INACCESSIBLE`."""
    comptime ONLY_INACCESSIBLE_CHILDREN = ErrorCode(73)
    """`ONLY_INACCESSIBLE_CHILDREN`."""
    comptime REFERENCED_INACCESSIBLE = ErrorCode(74)
    """`REFERENCED_INACCESSIBLE`."""
    comptime EXTERNAL_TYPE_MISMATCH = ErrorCode(75)
    """`EXTERNAL_TYPE_MISMATCH`."""
    comptime INTERFACE_FIELD_NO_IMPLEM = ErrorCode(76)
    """`INTERFACE_FIELD_NO_IMPLEM`."""
    comptime INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE = ErrorCode(77)
    """`INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE`."""
    comptime REQUIRED_INACCESSIBLE = ErrorCode(78)
    """`REQUIRED_INACCESSIBLE`."""
    comptime IMPLEMENTED_BY_INACCESSIBLE = ErrorCode(79)
    """`IMPLEMENTED_BY_INACCESSIBLE`."""
    comptime CONTEXTUAL_ARGUMENT_NOT_CONTEXTUAL_IN_ALL_SUBGRAPHS = ErrorCode(80)
    """`CONTEXTUAL_ARGUMENT_NOT_CONTEXTUAL_IN_ALL_SUBGRAPHS`."""
    comptime MISSING_TRANSITIVE_AUTH_REQUIREMENTS = ErrorCode(81)
    """`MISSING_TRANSITIVE_AUTH_REQUIREMENTS`."""
    comptime SATISFIABILITY_ERROR = ErrorCode(82)
    """`SATISFIABILITY_ERROR`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the codes.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 82

    def text(self) -> StaticString:
        """Return the upstream code string, such as `INVALID_GRAPHQL`.

        Returns:
            The code, empty for `NONE`, or `<invalid>`.
        """
        comptime names: Array[StaticString, 83] = [
            "",
            "INVALID_GRAPHQL",
            "INVALID_LINK_DIRECTIVE_USAGE",
            "INVALID_LINK_IDENTIFIER",
            "UNKNOWN_LINK_VERSION",
            "UNKNOWN_FEDERATION_LINK_VERSION",
            "EXTERNAL_UNUSED",
            "INVALID_SUBGRAPH_NAME",
            "TYPE_DEFINITION_INVALID",
            "DIRECTIVE_DEFINITION_INVALID",
            "KEY_UNSUPPORTED_ON_INTERFACE",
            "KEY_INVALID_FIELDS_TYPE",
            "KEY_INVALID_FIELDS",
            "KEY_DIRECTIVE_IN_FIELDS_ARG",
            "KEY_FIELDS_HAS_ARGS",
            "KEY_FIELDS_SELECT_INVALID_TYPE",
            "INTERFACE_KEY_NOT_ON_IMPLEMENTATION",
            "PROVIDES_ON_NON_OBJECT_FIELD",
            "PROVIDES_UNSUPPORTED_ON_INTERFACE",
            "PROVIDES_INVALID_FIELDS_TYPE",
            "PROVIDES_INVALID_FIELDS",
            "PROVIDES_DIRECTIVE_IN_FIELDS_ARG",
            "PROVIDES_FIELDS_HAS_ARGS",
            "PROVIDES_FIELDS_MISSING_EXTERNAL",
            "REQUIRES_UNSUPPORTED_ON_INTERFACE",
            "REQUIRES_INVALID_FIELDS_TYPE",
            "REQUIRES_INVALID_FIELDS",
            "REQUIRES_DIRECTIVE_IN_FIELDS_ARG",
            "REQUIRES_FIELDS_MISSING_EXTERNAL",
            "MERGED_DIRECTIVE_APPLICATION_ON_EXTERNAL",
            "INVALID_SHAREABLE_USAGE",
            "UNSUPPORTED_FEATURE",
            "INTERFACE_OBJECT_USAGE_ERROR",
            "OVERRIDE_ON_INTERFACE",
            "OVERRIDE_LABEL_INVALID",
            "OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE",
            "OVERRIDE_FROM_SELF_ERROR",
            "QUERY_ROOT_TYPE_INACCESSIBLE",
            "ROOT_QUERY_USED",
            "ROOT_MUTATION_USED",
            "ROOT_SUBSCRIPTION_USED",
            "DIRECTIVE_COMPOSITION_ERROR",
            "CONTEXT_NAME_INVALID",
            "CONTEXT_NOT_SET",
            "NO_CONTEXT_IN_SELECTION",
            "CONTEXT_INVALID_SELECTION",
            "CONTEXT_NO_RESOLVABLE_KEY",
            "AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE",
            "DIRECTIVE_COST_INVALID_WEIGHT",
            "COST_APPLIED_TO_INTERFACE_FIELD",
            "LIST_SIZE_INVALID_ASSUMED_SIZE",
            "LIST_SIZE_INVALID_SLICING_ARGUMENT",
            "LIST_SIZE_INVALID_SIZED_FIELD",
            "LIST_SIZE_APPLIED_TO_NON_LIST",
            "LIST_SIZE_INVALID_REQUIRE_ONE_SLICING_ARGUMENT",
            "LINK_IMPORT_NAME_MISMATCH",
            "NO_QUERIES",
            "TYPE_KIND_MISMATCH",
            "FIELD_TYPE_MISMATCH",
            "INVALID_FIELD_SHARING",
            "EXTENSION_WITH_NO_BASE",
            "FIELD_ARGUMENT_TYPE_MISMATCH",
            "ENUM_VALUE_MISMATCH",
            "EMPTY_MERGED_ENUM_TYPE",
            "OVERRIDE_SOURCE_HAS_OVERRIDE",
            "EXTERNAL_MISSING_ON_BASE",
            "EMPTY_MERGED_INPUT_TYPE",
            "REQUIRED_ARGUMENT_MISSING_IN_SOME_SUBGRAPH",
            "REQUIRED_INPUT_FIELD_MISSING_IN_SOME_SUBGRAPH",
            "EXTERNAL_ARGUMENT_MISSING",
            "INPUT_FIELD_DEFAULT_MISMATCH",
            "FIELD_ARGUMENT_DEFAULT_MISMATCH",
            "DEFAULT_VALUE_USES_INACCESSIBLE",
            "ONLY_INACCESSIBLE_CHILDREN",
            "REFERENCED_INACCESSIBLE",
            "EXTERNAL_TYPE_MISMATCH",
            "INTERFACE_FIELD_NO_IMPLEM",
            "INTERFACE_KEY_MISSING_IMPLEMENTATION_TYPE",
            "REQUIRED_INACCESSIBLE",
            "IMPLEMENTED_BY_INACCESSIBLE",
            "CONTEXTUAL_ARGUMENT_NOT_CONTEXTUAL_IN_ALL_SUBGRAPHS",
            "MISSING_TRANSITIVE_AUTH_REQUIREMENTS",
            "SATISFIABILITY_ERROR",
        ]
        if not self.is_valid():
            return "<invalid>"
        return materialize[names]()[Int(self.value)]

    def write_to(self, mut writer: Some[Writer]):
        """Write the code string.

        Args:
            writer: The writer.
        """
        writer.write(self.text())


@fieldwise_init
struct CompositionError(Copyable, Writable):
    """An error of composition: a message, a code and the subgraph."""

    var message: String
    """The message; the subgraph phase prefixes `[<subgraph>] `."""
    var code: ErrorCode
    """The `extensions.code`, or `NONE`."""
    var subgraph_name: Optional[String]
    """The `extensions.subgraphName`, if it is set."""

    def to_json_extensions(self) -> String:
        """Return the `extensions` object as JSON, as upstream sets it.

        Returns:
            Such as `{"code":"INVALID_GRAPHQL","subgraphName":"a"}`; empty
            when there is neither a code nor a subgraph.
        """
        var parts = List[String]()
        if self.code != ErrorCode.NONE:
            parts.append('"code":"' + String(self.code.text()) + '"')
        if self.subgraph_name:
            parts.append(
                '"subgraphName":'
                + quote_json_string(self.subgraph_name.value())
            )
        if len(parts) == 0:
            return String("")
        return "{" + String(",").join(parts) + "}"

    def write_to(self, mut writer: Some[Writer]):
        """Write the code and the message, as `[CODE] message`.

        Args:
            writer: The writer.
        """
        writer.write("[", self.code.text(), "] ", self.message)
