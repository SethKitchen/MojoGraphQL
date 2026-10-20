# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The helpers of the normalization tests: the `run` functions of
graphql-go-tools v2 `astnormalization/astnormalization_test.go`.

Upstream prints the result and the parsed expected output with one
printer, and compares the two texts. These helpers do the same with
`print_ast`. Each upstream visitor is a `Pass` here.
"""

from gql_language.ast import Document, Kind, NO_NODE, Role
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_normalization.normalize import (
    NormalizerOptions,
    OperationNormalizer,
    normalize_named_operation,
)
from gql_normalization.selections import (
    deduplicate_fields,
    delete_unused_variables,
    directive_include_skip,
    fragment_spread_inline,
    inline_selections_from_inline_fragments,
    merge_inline_fragment_selections,
    remove_fragment_definitions,
    remove_operation_definitions,
    remove_self_aliasing,
)
from gql_normalization.variables import (
    extract_variables,
    extract_variables_default_value,
    inject_input_field_defaults,
    input_coercion_for_list,
)
from gql_schema.build import BuildOptions, build_schema
from gql_schema.definition import Schema
from std.testing import assert_equal, assert_true

comptime Pass = def(
    mut document: Document, schema: Schema, mut variables: String
) raises thin -> None
"""One upstream visitor, registered on its own walker."""


def schema_of(sdl: StringSlice) raises -> Schema:
    """Build a test definition, as `MergeDefinitionWithBaseSchema` does.

    Args:
        sdl: The definition.

    Returns:
        The schema.

    Raises:
        Error: If the SDL does not parse.
    """
    var options = BuildOptions()
    options.assume_valid = True
    options.assume_valid_sdl = True
    return build_schema(sdl, options)


def printed(text: StringSlice) raises -> String:
    """Return a document as the printer writes it.

    Args:
        text: The document.

    Returns:
        The printed document.

    Raises:
        Error: If the text does not parse.
    """
    return print_ast(parse(text))


def directive_include_skip_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `directiveIncludeSkip`."""
    _ = directive_include_skip(document, schema, variables, False)


def keep_nodes_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `directiveIncludeSkipKeepNodes(walker, true)`."""
    _ = directive_include_skip(document, schema, variables, True)


def remove_register_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `removeOperationDefinitions` with the name `Register`."""
    remove_operation_definitions(document, "Register")


def fragment_spread_inline_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `fragmentSpreadInline`."""
    fragment_spread_inline(document, schema)


def inline_selections_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `inlineSelectionsFromInlineFragments`."""
    inline_selections_from_inline_fragments(document, schema)


def merge_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `mergeInlineFragmentSelections`."""
    merge_inline_fragment_selections(document, schema)


def self_aliasing_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `removeSelfAliasing`."""
    remove_self_aliasing(document, schema)


def deduplicate_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `deduplicateFields`."""
    deduplicate_fields(document, schema)


def remove_fragments_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `removeFragmentDefinitions`."""
    remove_fragment_definitions(document)


def extract_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `extractVariables`."""
    extract_variables(document, schema, variables)


def default_values_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `extractVariablesDefaultValue`."""
    extract_variables_default_value(document, schema, variables)


def inject_defaults_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `injectInputFieldDefaults`."""
    inject_input_field_defaults(document, schema, variables)


def coercion_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `inputCoercionForList`."""
    input_coercion_for_list(document, schema, variables)


def delete_unused_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `detectVariableUsage` and `deleteUnusedVariables` as the
    normalizer runs them: the detection in the first stage, the deletion in
    the cleanup stage."""
    var used = directive_include_skip(document, schema, variables, True)
    delete_unused_variables(document, variables, used)


def run(
    normalize: Pass,
    definition: StringSlice,
    operation: StringSlice,
    expected: StringSlice,
) raises:
    """Run one pass and compare the printed result: upstream `run`.

    Args:
        normalize: The pass.
        definition: The schema.
        operation: The operation.
        expected: The expected operation.

    Raises:
        Error: If the outputs differ or a pass fails.
    """
    run_with_variables(normalize, definition, operation, expected, "")


def run_with_variables(
    normalize: Pass,
    definition: StringSlice,
    operation: StringSlice,
    expected: StringSlice,
    variables: StringSlice,
) raises:
    """Run one pass with variables: upstream `runWithVariables`.

    Args:
        normalize: The pass.
        definition: The schema.
        operation: The operation.
        expected: The expected operation.
        variables: The variables JSON.

    Raises:
        Error: If the outputs differ or a pass fails.
    """
    var schema = schema_of(definition)
    var document = parse(operation)
    var values = String(variables)
    normalize(document, schema, values)
    assert_equal(print_ast(document), printed(expected))


def run_many(
    passes: List[Pass],
    definition: StringSlice,
    operation: StringSlice,
    expected: StringSlice,
) raises:
    """Run passes in order and compare the printed result: upstream
    `runMany`, which registers them on one walker.

    Args:
        passes: The passes.
        definition: The schema.
        operation: The operation.
        expected: The expected operation.

    Raises:
        Error: If the outputs differ or a pass fails.
    """
    var schema = schema_of(definition)
    var document = parse(operation)
    var values = String()
    var index = 0
    while index < len(passes):
        var normalize = passes[index]
        normalize(document, schema, values)
        index += 1
    assert_equal(print_ast(document), printed(expected))


def run_vars(
    normalize: Pass,
    definition: StringSlice,
    operation: StringSlice,
    expected: StringSlice,
    variables: StringSlice,
    expected_variables: StringSlice,
    additional: List[Pass] = [],
) raises:
    """Run a pass, then more passes, and compare the document and the
    variables: upstream `runWithVariablesAssert`.

    Args:
        normalize: The pass under test.
        definition: The schema.
        operation: The operation.
        expected: The expected operation.
        variables: The variables JSON.
        expected_variables: The expected variables JSON.
        additional: The passes that run after it.

    Raises:
        Error: If the outputs differ or a pass fails.
    """
    var schema = schema_of(definition)
    var document = parse(operation)
    var values = String(variables)
    normalize(document, schema, values)
    var index = 0
    while index < len(additional):
        var other = additional[index]
        other(document, schema, values)
        index += 1
    assert_equal(print_ast(document), printed(expected))
    assert_equal(values, String(expected_variables))


def run_vars_pre(
    normalize: Pass,
    definition: StringSlice,
    operation: StringSlice,
    expected: StringSlice,
    variables: StringSlice,
    expected_variables: StringSlice,
    prerequisites: List[Pass],
) raises:
    """Run passes, then the pass under test, and compare the document and
    the variables: upstream `runWithVariablesAssertAndPreNormalize`.

    Args:
        normalize: The pass under test.
        definition: The schema.
        operation: The operation.
        expected: The expected operation.
        variables: The variables JSON.
        expected_variables: The expected variables JSON.
        prerequisites: The passes that run first.

    Raises:
        Error: If the outputs differ or a pass fails.
    """
    var schema = schema_of(definition)
    var document = parse(operation)
    var values = String(variables)
    var index = 0
    while index < len(prerequisites):
        var other = prerequisites[index]
        other(document, schema, values)
        index += 1
    normalize(document, schema, values)
    assert_equal(print_ast(document), printed(expected))
    assert_equal(values, String(expected_variables))


def run_error(
    normalize: Pass,
    definition: StringSlice,
    operation: StringSlice,
    message: StringSlice,
) raises:
    """Run a pass that must fail: upstream `runWithExpectedErrors`.

    Args:
        normalize: The pass.
        definition: The schema.
        operation: The operation.
        message: The expected error message.

    Raises:
        Error: If the pass does not fail with the message.
    """
    var schema = schema_of(definition)
    var document = parse(operation)
    var values = String()
    try:
        normalize(document, schema, values)
    except error:
        assert_equal(String(error), String(message))
        return
    assert_true(False, "expected the error: " + String(message))


def run_normalize(
    definition: StringSlice,
    operation: StringSlice,
    expected: StringSlice,
    variables: StringSlice,
    expected_variables: StringSlice,
) raises:
    """Normalize with the options of `TestNormalizeOperation`: upstream
    `NewWithOpts(WithInlineFragmentSpreads(), WithExtractVariables(),
    WithRemoveFragmentDefinitions(), WithRemoveUnusedVariables(),
    WithEnableDefer())`.

    Args:
        definition: The schema.
        operation: The operation.
        expected: The expected operation.
        variables: The variables JSON.
        expected_variables: The expected variables JSON.

    Raises:
        Error: If the outputs differ or the normalization fails.
    """
    var options = NormalizerOptions()
    options.inline_fragment_spreads = True
    options.extract_variables = True
    options.remove_fragment_definitions = True
    options.remove_unused_variables = True
    options.enable_defer = True
    var schema = schema_of(definition)
    var document = parse(operation)
    var values = String(variables)
    OperationNormalizer(options).normalize_operation(document, schema, values)
    assert_equal(print_ast(document), printed(expected))
    assert_equal(values, String(expected_variables))


def run_named(
    definition: StringSlice,
    operation: StringSlice,
    name: StringSlice,
    expected: StringSlice,
    variables: StringSlice,
    expected_variables: StringSlice,
    normalize_expected: Bool = False,
) raises:
    """Run `normalize_named_operation`, as the tests of
    `TestOperationNormalizer_NormalizeNamedOperation` do.

    Args:
        definition: The schema.
        operation: The operation.
        name: The operation name.
        expected: The expected operation.
        variables: The variables JSON.
        expected_variables: The expected variables JSON.
        normalize_expected: Normalize the expected operation too, as some
            upstream tests do.

    Raises:
        Error: If the outputs differ or the normalization fails.
    """
    var schema = schema_of(definition)
    var document = parse(operation)
    var values = String(variables)
    normalize_named_operation(document, schema, name, values)
    var want = parse(expected)
    if normalize_expected:
        var none = String()
        normalize_named_operation(want, schema, name, none)
    assert_equal(print_ast(document), print_ast(want))
    assert_equal(values, String(expected_variables))
