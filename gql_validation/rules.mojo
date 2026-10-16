# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The validation rules, as values.

Port of graphql-js 16.14.2 `validation/specifiedRules.ts` (`specifiedRules`
and `recommendedRules`) and the rule names of `validation/rules/` and
`validation/rules/custom/`.

A graphql-js rule is a function that returns a visitor. Here a rule is a
`ValidationRule` value, and `gql_validation.validate` calls the code of
each rule in one walk of the document.
"""


@fieldwise_init
struct ValidationRule(Equatable, ImplicitlyCopyable, Writable):
    """One validation rule of graphql-js `validation/rules/`."""

    var value: UInt8
    """The rule's index: its place in `specifiedRules`, then the custom
    rules; see `is_valid`."""

    comptime EXECUTABLE_DEFINITIONS = ValidationRule(0)
    """`ExecutableDefinitionsRule`: only operations and fragments."""
    comptime UNIQUE_OPERATION_NAMES = ValidationRule(1)
    """`UniqueOperationNamesRule`: one operation per name."""
    comptime LONE_ANONYMOUS_OPERATION = ValidationRule(2)
    """`LoneAnonymousOperationRule`: an anonymous operation is alone."""
    comptime SINGLE_FIELD_SUBSCRIPTIONS = ValidationRule(3)
    """`SingleFieldSubscriptionsRule`: a subscription selects one root
    field."""
    comptime KNOWN_TYPE_NAMES = ValidationRule(4)
    """`KnownTypeNamesRule`: every named type exists."""
    comptime FRAGMENTS_ON_COMPOSITE_TYPES = ValidationRule(5)
    """`FragmentsOnCompositeTypesRule`: a fragment is on a composite
    type."""
    comptime VARIABLES_ARE_INPUT_TYPES = ValidationRule(6)
    """`VariablesAreInputTypesRule`: a variable has an input type."""
    comptime SCALAR_LEAFS = ValidationRule(7)
    """`ScalarLeafsRule`: leaf fields have no selection, others have
    one."""
    comptime FIELDS_ON_CORRECT_TYPE = ValidationRule(8)
    """`FieldsOnCorrectTypeRule`: every field exists on its type."""
    comptime UNIQUE_FRAGMENT_NAMES = ValidationRule(9)
    """`UniqueFragmentNamesRule`: one fragment per name."""
    comptime KNOWN_FRAGMENT_NAMES = ValidationRule(10)
    """`KnownFragmentNamesRule`: every spread fragment exists."""
    comptime NO_UNUSED_FRAGMENTS = ValidationRule(11)
    """`NoUnusedFragmentsRule`: every fragment is used."""
    comptime POSSIBLE_FRAGMENT_SPREADS = ValidationRule(12)
    """`PossibleFragmentSpreadsRule`: a spread can match its parent
    type."""
    comptime NO_FRAGMENT_CYCLES = ValidationRule(13)
    """`NoFragmentCyclesRule`: no fragment spreads itself."""
    comptime UNIQUE_VARIABLE_NAMES = ValidationRule(14)
    """`UniqueVariableNamesRule`: one variable per name."""
    comptime NO_UNDEFINED_VARIABLES = ValidationRule(15)
    """`NoUndefinedVariablesRule`: every used variable is defined."""
    comptime NO_UNUSED_VARIABLES = ValidationRule(16)
    """`NoUnusedVariablesRule`: every defined variable is used."""
    comptime KNOWN_DIRECTIVES = ValidationRule(17)
    """`KnownDirectivesRule`: every directive exists and is in place."""
    comptime UNIQUE_DIRECTIVES_PER_LOCATION = ValidationRule(18)
    """`UniqueDirectivesPerLocationRule`: a non-repeatable directive once
    per location."""
    comptime KNOWN_ARGUMENT_NAMES = ValidationRule(19)
    """`KnownArgumentNamesRule`: every argument exists."""
    comptime UNIQUE_ARGUMENT_NAMES = ValidationRule(20)
    """`UniqueArgumentNamesRule`: one argument per name."""
    comptime VALUES_OF_CORRECT_TYPE = ValidationRule(21)
    """`ValuesOfCorrectTypeRule`: every literal fits its type."""
    comptime PROVIDED_REQUIRED_ARGUMENTS = ValidationRule(22)
    """`ProvidedRequiredArgumentsRule`: every required argument is
    given."""
    comptime VARIABLES_IN_ALLOWED_POSITION = ValidationRule(23)
    """`VariablesInAllowedPositionRule`: a variable fits where it is
    used."""
    comptime OVERLAPPING_FIELDS_CAN_BE_MERGED = ValidationRule(24)
    """`OverlappingFieldsCanBeMergedRule`: fields with one response name
    can merge."""
    comptime UNIQUE_INPUT_FIELD_NAMES = ValidationRule(25)
    """`UniqueInputFieldNamesRule`: one input object field per name."""
    comptime MAX_INTROSPECTION_DEPTH = ValidationRule(26)
    """`MaxIntrospectionDepthRule`: introspection lists nest at most two
    deep; the one rule of `recommendedRules`."""
    comptime NO_DEPRECATED_CUSTOM = ValidationRule(27)
    """`NoDeprecatedCustomRule`: no deprecated field, argument, input
    field or enum value; not in `specifiedRules`."""
    comptime NO_SCHEMA_INTROSPECTION_CUSTOM = ValidationRule(28)
    """`NoSchemaIntrospectionCustomRule`: no `__schema` or `__type`; not
    in `specifiedRules`."""
    comptime COUNT = 29
    """How many rules there are."""
    comptime SPECIFIED_COUNT = 27
    """How many rules `specifiedRules` holds."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the rules.

        Returns:
            Whether the value is in range.
        """
        return self.value < UInt8(ValidationRule.COUNT)

    def text(self) -> StaticString:
        """Return the graphql-js name of the rule, such as
        `ScalarLeafsRule`.

        Returns:
            The name, or `<invalid>`.
        """
        comptime names: Array[StaticString, 29] = [
            "ExecutableDefinitionsRule",
            "UniqueOperationNamesRule",
            "LoneAnonymousOperationRule",
            "SingleFieldSubscriptionsRule",
            "KnownTypeNamesRule",
            "FragmentsOnCompositeTypesRule",
            "VariablesAreInputTypesRule",
            "ScalarLeafsRule",
            "FieldsOnCorrectTypeRule",
            "UniqueFragmentNamesRule",
            "KnownFragmentNamesRule",
            "NoUnusedFragmentsRule",
            "PossibleFragmentSpreadsRule",
            "NoFragmentCyclesRule",
            "UniqueVariableNamesRule",
            "NoUndefinedVariablesRule",
            "NoUnusedVariablesRule",
            "KnownDirectivesRule",
            "UniqueDirectivesPerLocationRule",
            "KnownArgumentNamesRule",
            "UniqueArgumentNamesRule",
            "ValuesOfCorrectTypeRule",
            "ProvidedRequiredArgumentsRule",
            "VariablesInAllowedPositionRule",
            "OverlappingFieldsCanBeMergedRule",
            "UniqueInputFieldNamesRule",
            "MaxIntrospectionDepthRule",
            "NoDeprecatedCustomRule",
            "NoSchemaIntrospectionCustomRule",
        ]
        if not self.is_valid():
            return "<invalid>"
        return materialize[names]()[Int(self.value)]

    def write_to(self, mut writer: Some[Writer]):
        """Write the graphql-js name of the rule.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


def specified_rules() -> List[ValidationRule]:
    """Return the rules of graphql-js `specifiedRules`, in order.

    Returns:
        The 26 rules of the specification, then `MAX_INTROSPECTION_DEPTH`.
    """
    var rules = List[ValidationRule](capacity=ValidationRule.SPECIFIED_COUNT)
    var index = 0
    while index < ValidationRule.SPECIFIED_COUNT:
        rules.append(ValidationRule(UInt8(index)))
        index += 1
    return rules^


def recommended_rules() -> List[ValidationRule]:
    """Return the rules of graphql-js `recommendedRules`.

    Returns:
        `MAX_INTROSPECTION_DEPTH`.
    """
    return [ValidationRule.MAX_INTROSPECTION_DEPTH]
