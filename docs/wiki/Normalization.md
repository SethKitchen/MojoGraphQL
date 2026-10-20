<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Normalization

`gql_normalization` normalizes, minifies and checks GraphQL operations. It is a port of the operation tooling of graphql-go-tools v2 at `9ef6e24`: `v2/pkg/astnormalization`, `v2/pkg/astminify` and `v2/pkg/variablesvalidation`. It needs `gql_language`, `gql_schema` and `gql_json`.

| Module | Contents | graphql-go-tools source |
| --- | --- | --- |
| `gql_normalization.normalize` | `OperationNormalizer`, `NormalizerOptions`, `normalize_operation`, `normalize_named_operation` | `astnormalization/astnormalization.go` |
| `gql_normalization.selections` | The selection passes | `directive_include_skip.go`, `fragment_spread_inlining.go` and the others |
| `gql_normalization.variables` | The variable passes | `variables_extraction.go`, `input_coercion_for_list.go` and the others |
| `gql_normalization.minify` | `Minifier`, `MinifyOptions`, `minify` | `astminify/minify.go` |
| `gql_normalization.go_printer` | `print_compact`, `print_indent`, `GoPrinter` | `astprinter/astprinter.go` |
| `gql_normalization.variables_validation` | `VariablesValidator`, `VariablesValidatorOptions`, `InvalidVariableError` | `variablesvalidation/variablesvalidation.go` |
| `gql_normalization.edit` | Edits of a `Document` in place, and node comparisons | `ast` |
| `gql_normalization.variables_json` | The edits of the variables JSON of `sjson` and `jsonparser` | `sjson` v1.0.4, `jsonparser` |

## Normalize an operation

A normalizer edits an operation `Document` in place, against a `gql_schema` `Schema`. The variables of the request are JSON text, and the normalizer edits them in place too. The output is the same as the output of upstream for the same input.

| Function | graphql-go-tools | Options |
| --- | --- | --- |
| `normalize_operation(operation, schema, variables)` | `NormalizeOperation` | `OperationNormalizer.new(False, False)` |
| `normalize_named_operation(operation, schema, name, variables)` | `NormalizeNamedOperation` | Keep one operation, extract the variables, inline and remove the fragments, remove the unused variables |
| `OperationNormalizer.new(remove_fragment_definitions, extract_variables)` | `NewNormalizer` | Inline the fragment spreads, and the two options |
| `OperationNormalizer(options)` | `NewWithOpts` | The fields of `NormalizerOptions` |

Make one `OperationNormalizer` and use it again on a hot path. Each function raises an `Error` with the message of the first upstream error, such as `fragment: Missing undefined`.

```mojo
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_normalization.normalize import normalize_named_operation
from gql_schema.build import build_schema

var schema = build_schema("type Query { hero(id: ID!): String }")
var operation = parse('query Q { hero(id: "1") }')
var variables = String()
normalize_named_operation(operation, schema, "Q", variables)
print(print_ast(operation))  # query Q($a: ID!) {\n  hero(id: $a)\n}
print(variables)             # {"a":"1"}
```

### NormalizerOptions

`NormalizerOptions()` sets each option to `False`, as `NewWithOpts()` without an option does.

| Field | graphql-go-tools option |
| --- | --- |
| `remove_fragment_definitions` | `WithRemoveFragmentDefinitions` |
| `inline_fragment_spreads` | `WithInlineFragmentSpreads` |
| `extract_variables` | `WithExtractVariables` |
| `remove_unused_variables` | `WithRemoveUnusedVariables` |
| `remove_not_matching_operation_definitions` | `WithRemoveNotMatchingOperationDefinitions` |
| `ignore_skip_include` | `WithIgnoreSkipInclude` |

### Stages

The stages run in the order of upstream `setupOperationWalkers`. A stage that has an option runs only when the option is set.

1. `remove_operation_definitions` keeps only the operation with the given name.
2. `directive_include_skip` removes the selections that `@include` and `@skip` exclude. The same walk refuses a fragment cycle.
3. `fragment_spread_inline` replaces each fragment spread with an inline fragment.
4. `extract_variables` moves each argument literal into a new variable `$a`, `$b`, and so on.
5. `inline_selections_and_remove_self_aliasing` inlines the inline fragments that apply to each object, and removes the aliases that equal their field names.
6. `merge_and_deduplicate` merges the inline fragments and the fields with selections, and removes the duplicate leaf fields.
7. `remove_fragment_definitions` removes the fragments that no operation spreads.
8. `delete_unused_variables` removes the variables that no argument uses after stage 2.
9. `variables_processing` wraps list values, moves the default values into the variables, and adds the defaults of input object fields.

Each pass is also a public function, so a program can run one pass alone. The tests of upstream do the same with one visitor on one walker.

### The variables JSON

The passes edit the JSON as the libraries of upstream do, so the bytes are the same.

- A new variable goes at the start of the object, as `sjson` v1.0.4 writes it. The `go.work` of graphql-go-tools pins that version.
- A default of an input object field goes at the end of its object, as `jsonparser.Set` writes it.
- A deleted variable goes with the comma before it. The first variable goes with the comma after it.

## Minify an operation

`Minifier().minify(operation, schema, options, out)` replaces each repeated selection set with a fragment spread. It appends the minified operation to `out`, and returns whether it made a replacement. The free function `minify(operation, schema, options)` returns the text.

| `MinifyOptions` field | graphql-go-tools | Default |
| --- | --- | --- |
| `pretty` | `Pretty` | `False`: one line, as `astprinter.Print` |
| `sort_ast` | `SortAST` | `False` |

`print_compact(document)` and `print_indent(document, indent)` print an operation as `astprinter.Print` and `astprinter.PrintIndent` do.

## Validate the variables

`VariablesValidator(options).validate(operation, schema, variables)` checks the variables JSON of a request against the variable definitions of the operation. It returns `None` for valid variables, or an `InvalidVariableError` with the upstream message and extension code. It raises a `JsonError` for text that is not JSON.

| `VariablesValidatorOptions` field | graphql-go-tools option |
| --- | --- |
| `apollo_compatibility_flags` | `ApolloCompatibilityFlags`, with `replace_invalid_var_error` |
| `apollo_router_compatibility_flags` | `ApolloRouterCompatibilityFlags`, with `replace_invalid_var_error` and `skip_null_variables_error` |
| `disable_exposing_variables_content` | `DisableExposingVariablesContent` |

`validate_with_remap(operation, schema, variables, variables_map)` is upstream `ValidateWithRemap`. As upstream, the validator keeps the map for the next calls.

## Differences from upstream

### Normalization

- **The definition.** The definition is a `gql_schema` `Schema`, not an `ast.Document`. It holds the built-in types and the merged type extensions. So `MergeDefinitionWithBaseSchema` and `WithNormalizeDefinition` have no counterpart.
- **Default root types.** When the schema definition leaves out a root, the type with the default name is the root, as `MergeDefinitionWithBaseSchema` makes it.
- **Errors.** A stage raises an `Error` with the message of the upstream external error. Upstream adds the error to an `operationreport.Report`.
- **Not ported.** `WithEnableDefer` and the `@defer` stages, `WithPrevalidationRules`, `WithInlineArgumentsValidation`, `VariablesNormalizer`, the fragment spread depth calculator and the file uploads are not ported. `@__defer_internal` directives are compared and merged as upstream does.
- **Fewer walks.** Stage 5 and stage 6 each walk the document once. Upstream merges and deduplicates in two stages, with stage 7 between them. The result is the same.
- **The first walk.** Stage 2 checks the fragment cycles before it removes a selection. Upstream walks the removed selections too, so it sees the same spreads.
- **Directive lists.** The walker of upstream can skip the directive after a removed directive. Here each directive is read once.
- **Upstream defects kept.** A list of input objects counts only the elements that it changes, as `jsonWalker` does. `input_coercion_for_list` reads the variable definitions of the current operation; upstream reads those of the first operation.

### Minification

- The output goes to a `String`, not an `io.Writer`.
- A repeated selection set is matched by its printed text, its type name and its directives. Upstream uses an xxhash of the text.
- Repeated sets with the same depth and type name are handled in the order that the walk finds them. Upstream reads them from a Go map, so its fragment names can change between runs.
- The sort is an insertion sort. Go `slices.SortFunc` gives the same order for 12 items or fewer.
- The 677th fragment raises `astminify: more than 676 fragments`. Upstream panics.
- `print_compact` and `print_indent` print only operations and fragments.

### Variables validation

- `validate` returns `Optional[InvalidVariableError]`, and raises a `JsonError` for text that is not JSON. Upstream returns one `error` for both.
- Only the variable definitions are visited. The selection sets are not walked, so no `operationreport.Report` comes back.
- A changed value is written with `gql_json` `stringify`, not `astjson`.

## Tests

The tests are in `tests/gql_normalization/`. They port `astnormalization_test.go` and the test file of each ported pass, `minify_test.go` and `variablesvalidation_test.go`. `_norm_fixtures.mojo` and `_minify_fixtures.mojo` embed the upstream schemas, operations and goldens, because `make coverage` copies only `.mojo` files.

- The `@defer` cases, the type extension cases of `TestNormalizeOperation` and `TestVariablesNormalizer` are not ported, because their features are not.
- `build_schema` refuses an unknown type, and keeps the last of two types with one name. So two test schemas change: see `THIRD-PARTY-NOTICES.md`.
- `test_passes_extra.mojo`, `test_variables_extra.mojo` and `test_values_json.mojo` are not from upstream. They reach each branch, and their tricky cases were run against upstream.

## Benchmarks

`bench/gql_normalization/` runs the upstream Go benchmarks with the same inputs. `bench/baselines/go-normalization` runs them with graphql-go-tools v2 at `9ef6e24`.

| Workload | Upstream benchmark |
| --- | --- |
| `go-tools/AstNormalization` | `BenchmarkAstNormalization`: `NewNormalizer(false, false)` on `testOperation` again and again |
| `go-tools/Minify` | `BenchmarkMinify`: `operation1.graphql` on `simpleschema.graphql`, with `SortAST` |

`variablesvalidation_test.go` has no benchmark. Run `make bench-check PKG=gql_normalization` to compare the two.
