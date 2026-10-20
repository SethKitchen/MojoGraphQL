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
2. The `prevalidation_rules`, and `find_inline_arguments` with
   `inline_arguments_validation`.
3. `directive_include_skip`, which also refuses fragment cycles and notes
   the variables in use.
4. `fragment_spread_inline`, with `inline_fragment_spreads`.
5. `defer_expand_into_internal`, when step 3 found a `@defer`. Without
   `enable_defer` it only removes `@defer`. Upstream runs it always; it
   changes nothing in a document without `@defer`.
6. `extract_variables`, with `extract_variables`.
7. `inline_selections_from_inline_fragments` and `remove_self_aliasing`, on
   one walk.
8. `merge_inline_fragment_selections` and `deduplicate_fields`, on one walk
   (`merge_and_deduplicate`). Upstream deduplicates after step 9; the
   result is the same.
9. `remove_fragment_definitions`, with `remove_fragment_definitions`.
10. `defer_ensure_typename`, with `enable_defer`, and
    `delete_unused_variables`, with `remove_unused_variables`.
11. `defer_align_typename_scope`, then `defer_populate_parent_ids`, with
    `enable_defer`, when step 5 expanded a defer.
12. `variables_processing`, with `extract_variables`.

The operation document and the variables JSON change in place. The
schema does not change.

Differences from upstream:

- The definition is a `gql_schema` `Schema`. It holds the built-in types and
  the merged type extensions, so `asttransform.MergeDefinitionWithBaseSchema`
  has no counterpart. `WithNormalizeDefinition` applies to the functions
  that take the SDL as a `Document`.
- An error raises `Error` with the message of the upstream external error,
  in place of an entry in an `operationreport.Report`.
- A prevalidation rule is a function that reads the operation, in place of
  visitors registered on the walker of the first stage.
"""

from gql_language.ast import Document
from gql_schema.build import BuildOptions, build_ast_schema
from gql_schema.definition import Schema

from gql_normalization.defer import (
    defer_align_typename_scope,
    defer_ensure_typename,
    defer_expand_into_internal,
    defer_populate_parent_ids,
)
from gql_normalization.definition import DefinitionNormalizer
from gql_normalization.inline_arguments import (
    InlineArgumentsValidationOptions,
    NormalizationResult,
    RunOptions,
    find_inline_arguments,
)

from gql_normalization.selections import (
    delete_unused_variables,
    detect_variable_usage,
    directive_include_skip_with_defer,
    fragment_spread_inline,
    inline_selections_and_remove_self_aliasing,
    merge_and_deduplicate,
    operations_have_spread,
    remove_fragment_definitions,
    remove_operation_definitions,
)
from gql_normalization.uploads import UploadPathMapping
from gql_normalization.variables import (
    extract_variables,
    extract_variables_default_value,
    extract_variables_with_uploads,
    input_coercion_for_list,
    variables_processing,
)


comptime PrevalidationRule = def(
    operation: Document, schema: Schema, variables: String
) raises thin -> None
"""A check that runs before the first stage edits the operation: an entry
of upstream `WithPrevalidationRules`. It raises to stop the normalization.
"""


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
    var normalize_definition: Bool
    """Normalize the SDL document before the operation:
    `WithNormalizeDefinition`. Only the functions that take the SDL as a
    `Document` read it."""
    var prevalidation_rules: List[PrevalidationRule]
    """The checks that read the document before the first stage edits it:
    `WithPrevalidationRules`."""
    var inline_arguments_validation: Optional[InlineArgumentsValidationOptions]
    """Find the arguments with a literal value, or refuse them:
    `WithInlineArgumentsValidation`."""
    var enable_defer: Bool
    """Expand `@defer` into `@__defer_internal` on the fields:
    `WithEnableDefer`. Without it, `@defer` is removed."""

    def __init__(out self):
        """Make the options of `NewWithOpts()` without an option: all off."""
        self.remove_fragment_definitions = False
        self.inline_fragment_spreads = False
        self.extract_variables = False
        self.remove_unused_variables = False
        self.remove_not_matching_operation_definitions = False
        self.ignore_skip_include = False
        self.normalize_definition = False
        self.prevalidation_rules = List[PrevalidationRule]()
        self.inline_arguments_validation = None
        self.enable_defer = False


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
        var result = NormalizationResult()
        self._run(operation, schema, name, variables, RunOptions(), result)

    def normalize_named_operation_with_result(
        self,
        mut operation: Document,
        schema: Schema,
        name: StringSlice,
        mut variables: String,
        run_options: RunOptions,
    ) raises -> Optional[NormalizationResult]:
        """Normalize the operation with a name, and return the findings:
        `NormalizeNamedOperationWithResult`.

        Args:
            operation: The operation document, changed in place.
            schema: The schema.
            name: The operation name.
            variables: The variables JSON, changed in place.
            run_options: The options of this run.

        Returns:
            The inline arguments, or `None` without
            `inline_arguments_validation`.

        Raises:
            Error: The first error of a stage; with `enforce`, the
                `error_message` at the first inline argument.
        """
        var result = NormalizationResult()
        self._run(operation, schema, name, variables, run_options, result)
        if self.options.inline_arguments_validation:
            return result^
        return None

    @no_inline
    def _prevalidate(
        self,
        operation: Document,
        schema: Schema,
        variables: String,
        run_options: RunOptions,
        mut result: NormalizationResult,
    ) raises:
        """Run the prevalidation rules, then find the inline arguments: the
        visitors that upstream registers on the walker of the first stage
        before its own."""
        ref options = self.options
        var index = 0
        while index < len(options.prevalidation_rules):
            var rule = options.prevalidation_rules[index]
            rule(operation, schema, variables)
            index += 1
        if (
            options.inline_arguments_validation
            and not run_options.skip_inline_arguments
        ):
            find_inline_arguments(
                operation,
                variables,
                options.ignore_skip_include,
                options.inline_arguments_validation.value(),
                result,
            )

    def _run(
        self,
        mut operation: Document,
        schema: Schema,
        name: StringSlice,
        mut variables: String,
        run_options: RunOptions,
        mut result: NormalizationResult,
    ) raises:
        """Run the stages."""
        ref options = self.options
        if options.remove_not_matching_operation_definitions:
            remove_operation_definitions(operation, name)
        if len(options.prevalidation_rules) > 0 or Bool(
            options.inline_arguments_validation
        ):
            self._prevalidate(operation, schema, variables, run_options, result)
        var first = directive_include_skip_with_defer(
            operation, schema, variables, options.ignore_skip_include
        )
        ref used = first[0]
        if options.inline_fragment_spreads and operations_have_spread(
            operation
        ):
            fragment_spread_inline(operation, schema)
        # Without a `@defer` in the document, the stage changes nothing.
        var has_defers = False
        if first[1]:
            has_defers = defer_expand_into_internal(
                operation, variables, not options.enable_defer
            )
        if options.extract_variables:
            extract_variables(operation, schema, variables)
        inline_selections_and_remove_self_aliasing(operation, schema)
        merge_and_deduplicate(operation, schema)
        if options.remove_fragment_definitions:
            remove_fragment_definitions(operation)
        if options.enable_defer:
            defer_ensure_typename(operation)
        if options.remove_unused_variables:
            delete_unused_variables(operation, variables, used)
        if has_defers:
            defer_align_typename_scope(operation)
            defer_populate_parent_ids(operation)
        if options.extract_variables:
            variables_processing(operation, schema, variables)

    def prepare_definition(self, mut definition: Document) raises -> Schema:
        """Normalize an SDL document when the options say so, and build
        its schema: upstream `prepareDefinition`.

        Args:
            definition: The SDL document; with `normalize_definition`, it
                changes in place, as `NormalizeDefinition` changes it.

        Returns:
            The schema of the document. As upstream, the SDL is not
            validated.

        Raises:
            Error: An error of `build_ast_schema`, such as an unknown type.
        """
        if self.options.normalize_definition:
            DefinitionNormalizer().normalize_definition(definition)
        var build = BuildOptions()
        build.assume_valid = True
        build.assume_valid_sdl = True
        var documents = List[Document]()
        documents.append(definition.copy())
        return build_ast_schema(documents^, build)

    def normalize_operation_with_definition(
        self,
        mut operation: Document,
        mut definition: Document,
        mut variables: String,
    ) raises:
        """Normalize an operation against an SDL document:
        `NormalizeOperation` with an `ast.Document` definition.

        Make the schema once with `prepare_definition`, and use
        `normalize_operation`, on a hot path.

        Args:
            operation: The operation document, changed in place.
            definition: The SDL document; see `prepare_definition`.
            variables: The variables JSON, changed in place.

        Raises:
            Error: The first error of the build or of a stage.
        """
        var schema = self.prepare_definition(definition)
        self.normalize_named_operation(operation, schema, "", variables)

    def normalize_named_operation_with_definition(
        self,
        mut operation: Document,
        mut definition: Document,
        name: StringSlice,
        mut variables: String,
    ) raises:
        """Normalize the operation with a name against an SDL document:
        `NormalizeNamedOperation` with an `ast.Document` definition.

        Args:
            operation: The operation document, changed in place.
            definition: The SDL document; see `prepare_definition`.
            name: The operation name.
            variables: The variables JSON, changed in place.

        Raises:
            Error: The first error of the build or of a stage.
        """
        var schema = self.prepare_definition(definition)
        self.normalize_named_operation(operation, schema, name, variables)


struct VariablesNormalizer(Copyable, Movable):
    """Normalizes only the variables of an operation: upstream
    `VariablesNormalizer`.

    It runs four stages: the variable usage detection, the extraction of
    the argument literals and of the default values, the deletion of the
    unused variables, and the list coercion.
    """

    def __init__(out self):
        """Make the normalizer of `NewVariablesNormalizer`."""
        pass

    def normalize_operation(
        self, mut operation: Document, schema: Schema, mut variables: String
    ) raises -> List[UploadPathMapping]:
        """Normalize the variables of an operation: `NormalizeOperation`.

        Args:
            operation: The operation document, changed in place.
            schema: The schema.
            variables: The variables JSON, changed in place.

        Returns:
            The file uploads of the arguments, with their paths after the
            extraction.

        Raises:
            Error: The first error of a stage.
        """
        var safe = detect_variable_usage(operation)
        # Upstream extracts the default values on the same walk. The walk
        # moves them before it reaches the arguments.
        extract_variables_default_value(operation, schema, variables)
        var uploads = extract_variables_with_uploads(
            operation, schema, variables
        )
        delete_unused_variables(operation, variables, safe)
        input_coercion_for_list(operation, schema, variables)
        return uploads^


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
