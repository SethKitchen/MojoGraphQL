# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Operation normalization: graphql-go-tools v2 `astnormalization`
`OperationNormalizer`, `NormalizeOperation` and `NormalizeNamedOperation`.

A normalizer runs its stages in the order of `setupOperationWalkers`, and
stops at the first error:

1. `remove_operation_definitions`, with
   `remove_not_matching_operation_definitions`.
2. `directive_include_skip`, which also refuses fragment cycles and notes
   the variables in use.
3. `fragment_spread_inline`, with `inline_fragment_spreads`.
4. `extract_variables`, with `extract_variables`.
5. `inline_selections_from_inline_fragments` and `remove_self_aliasing`, on
   one walk.
6. `merge_inline_fragment_selections` and `deduplicate_fields`, on one walk
   (`merge_and_deduplicate`). Upstream deduplicates after step 7; the
   result is the same.
7. `remove_fragment_definitions`, with `remove_fragment_definitions`.
8. `delete_unused_variables`, with `remove_unused_variables`.
9. `variables_processing`, with `extract_variables`.

The operation document and the variables JSON change in place. The
schema does not change.

Differences from upstream:

- The definition is a `gql_schema` `Schema`. It holds the built-in types and
  the merged type extensions, so `asttransform.MergeDefinitionWithBaseSchema`
  and `WithNormalizeDefinition` have no counterpart.
- An error raises `Error` with the message of the upstream external error,
  in place of an entry in an `operationreport.Report`.
- `WithEnableDefer` (the `@defer` stages), `WithPrevalidationRules`,
  `WithInlineArgumentsValidation`, `VariablesNormalizer` and the upload
  path mapping are not ported.
"""

from gql_language.ast import Document
from gql_schema.definition import Schema

from gql_normalization.selections import (
    delete_unused_variables,
    directive_include_skip,
    fragment_spread_inline,
    inline_selections_and_remove_self_aliasing,
    merge_and_deduplicate,
    remove_fragment_definitions,
    remove_operation_definitions,
)
from gql_normalization.variables import extract_variables, variables_processing


@fieldwise_init
struct NormalizerOptions(Copyable, Movable):
    """The options of an `OperationNormalizer`: upstream `options`, set with
    `WithExtractVariables()` and the other `Option` functions."""

    var remove_fragment_definitions: Bool
    """Remove the fragment definitions that no operation spreads:
    `WithRemoveFragmentDefinitions`."""
    var inline_fragment_spreads: Bool
    """Replace each spread with an inline fragment:
    `WithInlineFragmentSpreads`."""
    var extract_variables: Bool
    """Move argument literals and default values into the variables:
    `WithExtractVariables`."""
    var remove_unused_variables: Bool
    """Remove the variables that no argument uses after the removals:
    `WithRemoveUnusedVariables`."""
    var remove_not_matching_operation_definitions: Bool
    """Keep only the operation with the given name:
    `WithRemoveNotMatchingOperationDefinitions`."""
    var ignore_skip_include: Bool
    """Remove `@include` and `@skip`, and keep their selections:
    `WithIgnoreSkipInclude`."""

    def __init__(out self):
        """Make the options of `NewWithOpts()` without an option: all off."""
        self.remove_fragment_definitions = False
        self.inline_fragment_spreads = False
        self.extract_variables = False
        self.remove_unused_variables = False
        self.remove_not_matching_operation_definitions = False
        self.ignore_skip_include = False


struct OperationNormalizer(Copyable, Movable):
    """Normalizes operations against a schema: upstream
    `OperationNormalizer`. One normalizer can serve many operations."""

    var options: NormalizerOptions
    """The stages to run."""

    def __init__(out self, options: NormalizerOptions):
        """Make a normalizer: `NewWithOpts`.

        Args:
            options: The options.
        """
        self.options = options.copy()

    @staticmethod
    def new(
        remove_fragment_definitions: Bool, extract_variables: Bool
    ) -> OperationNormalizer:
        """Make a normalizer that inlines fragment spreads: `NewNormalizer`.

        Args:
            remove_fragment_definitions: Remove the unused fragments.
            extract_variables: Extract the argument literals into variables.

        Returns:
            The normalizer.
        """
        var options = NormalizerOptions()
        options.remove_fragment_definitions = remove_fragment_definitions
        options.inline_fragment_spreads = True
        options.extract_variables = extract_variables
        return OperationNormalizer(options)

    def normalize_operation(
        self, mut operation: Document, schema: Schema, mut variables: String
    ) raises:
        """Normalize an operation document: `NormalizeOperation`.

        Args:
            operation: The operation document, changed in place.
            schema: The schema.
            variables: The variables JSON of the request, changed in place;
                empty for none.

        Raises:
            Error: The first error of a stage, such as `fragment: <name>
                undefined`.
        """
        self.normalize_named_operation(operation, schema, "", variables)

    def normalize_named_operation(
        self,
        mut operation: Document,
        schema: Schema,
        name: StringSlice,
        mut variables: String,
    ) raises:
        """Normalize the operation with a name: `NormalizeNamedOperation`.

        Args:
            operation: The operation document, changed in place.
            schema: The schema.
            name: The operation name; with
                `remove_not_matching_operation_definitions`, the other
                operations go.
            variables: The variables JSON of the request, changed in place;
                empty for none.

        Raises:
            Error: The first error of a stage.
        """
        ref options = self.options
        if options.remove_not_matching_operation_definitions:
            remove_operation_definitions(operation, name)
        var used = directive_include_skip(
            operation, schema, variables, options.ignore_skip_include
        )
        if options.inline_fragment_spreads:
            fragment_spread_inline(operation, schema)
        if options.extract_variables:
            extract_variables(operation, schema, variables)
        inline_selections_and_remove_self_aliasing(operation, schema)
        merge_and_deduplicate(operation, schema)
        if options.remove_fragment_definitions:
            remove_fragment_definitions(operation)
        if options.remove_unused_variables:
            delete_unused_variables(operation, variables, used)
        if options.extract_variables:
            variables_processing(operation, schema, variables)


def normalize_operation(
    mut operation: Document, schema: Schema, mut variables: String
) raises:
    """Normalize an operation with the default normalizer:
    `NormalizeOperation`, which is `NewNormalizer(false, false)`.

    Make one `OperationNormalizer` and reuse it on a hot path.

    Args:
        operation: The operation document, changed in place.
        schema: The schema.
        variables: The variables JSON, changed in place.

    Raises:
        Error: The first error of a stage.
    """
    OperationNormalizer.new(False, False).normalize_operation(
        operation, schema, variables
    )


def normalize_named_operation(
    mut operation: Document,
    schema: Schema,
    name: StringSlice,
    mut variables: String,
) raises:
    """Normalize the operation with a name, and remove the rest:
    `NormalizeNamedOperation`.

    The options are `remove_not_matching_operation_definitions`,
    `extract_variables`, `remove_fragment_definitions`,
    `inline_fragment_spreads` and `remove_unused_variables`.

    Args:
        operation: The operation document, changed in place.
        schema: The schema.
        name: The operation name.
        variables: The variables JSON, changed in place.

    Raises:
        Error: The first error of a stage.
    """
    var options = NormalizerOptions()
    options.remove_not_matching_operation_definitions = True
    options.extract_variables = True
    options.remove_fragment_definitions = True
    options.inline_fragment_spreads = True
    options.remove_unused_variables = True
    OperationNormalizer(options).normalize_named_operation(
        operation, schema, name, variables
    )
