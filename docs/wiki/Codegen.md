<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Codegen

`gql_codegen` writes Mojo models for GraphQL operations. It is a port of the Apollo Kotlin compiler, `libraries/apollo-compiler` at `afe947c` (5.2.1-SNAPSHOT), with the `operationBased` models. The benchmark runs the published `apollo-compiler` 5.2.0. The package needs `gql_language`, `gql_schema`, `gql_validation` and `gql_json`.

The compiler validates the operations against a schema, builds the IR and writes one Mojo module. For each operation, the module has the document, the operation id, the variables and the data models.

| Module | Contents | Upstream source |
| --- | --- | --- |
| `gql_codegen.compiler` | `compile`, `build_codegen_schema`, `CodegenDocument`, `CodegenResult` | `ApolloCompiler.kt` |
| `gql_codegen.options` | `CodegenOptions`, `AddTypename`, `CodegenModels` | `Options.kt` |
| `gql_codegen.transform` | `add_required_fields` | `internal/ApolloExecutableDocumentTransform.kt` |
| `gql_codegen.checks` | The Apollo checks of a document | `internal/checkCapitalizedFields.kt`, `internal/checkApolloInlineFragmentsHaveTypeCondition.kt` |
| `gql_codegen.ir`, `ir_builder` | The IR, its conditions and its used coordinates | `ir/IrOperations.kt`, `ir/IrOperationsBuilder.kt`, `ir/OperationBasedModelGroupBuilder.kt`, `ir/BooleanExpression.kt`, `UsedCoordinates.kt` |
| `gql_codegen.printer` | `print_executable` | `apollo-ast` `SDLWriter.kt` and `gql.kt` |
| `gql_codegen.strings` | Names, `singularize`, `minify` and the string escapes | `Strings.kt`, `internal/Inflector.kt`, `apollo-ast` `QueryDocumentMinifier.kt`, `gqlstrings.kt` |
| `gql_codegen.mojo_codegen` | `generate_mojo`, `operation_id` | The shape of `codegen/kotlin/` |
| `gql_codegen.issues` | `Issue`, `IssueKind`, `Severity`, `serialize` | `apollo-ast` `Issue.kt` |
| `gql_codegen.sha256` | `sha256_hex` | FIPS 180-4 |

```mojo
from gql_codegen.compiler import CodegenDocument, build_codegen_schema, compile
from gql_codegen.issues import serialize

var schema = build_codegen_schema(
    "type Query { hero: Character } type Character { name: String! }"
)
var documents = List[CodegenDocument]()
documents.append(CodegenDocument("hero.graphql", "query Hero { hero { name } }"))
var result = compile(schema, documents)
if not result.succeeded():
    print(serialize(result.errors))
print(result.operation_ids()[0])
print(result.source)
```

## Compile operations

`compile(schema, documents, options)` makes these steps, as upstream `buildIrOperations` does:

1. It sorts the documents by name and parses them. A syntax error stops the compilation.
2. It adds `__typename` with `add_required_fields`.
3. It validates the document with every specified rule of `gql_validation`.
4. It makes the Apollo checks: anonymous operations, inline fragments without a type condition, and capitalized fields.
5. It stops on an error, or on a warning when `fail_on_warnings` is set.
6. It builds the IR and writes the module.

An unused variable, an unused fragment and a deprecated usage are warnings, as upstream. Each issue has a kind, a message, a document name, a line and a column. `serialize` writes the issues as the upstream compiler tests do.

`build_codegen_schema(sdl)` builds the schema and checks it with the graphql-js rules. Pass `check=False` to accept a schema that `apollo-ast` accepts but the specification refuses.

## Options

| Option | Default | Upstream option |
| --- | --- | --- |
| `add_typename` | `AddTypename.IF_FRAGMENTS` | `addTypename` |
| `codegen_models` | `CodegenModels.OPERATION_BASED` | `codegenModels` |
| `generate_optional_operation_variables` | `True` | `generateOptionalOperationVariables` |
| `flatten_models` | `True` | `flattenModels` |
| `decapitalize_fields` | `False` | `decapitalizeFields` |
| `fail_on_warnings` | `False` | `failOnWarnings` |

`AddTypename` has the four upstream modes: `ifFragments`, `ifPolymorphic`, `ifAbstract` and `always`. `AddTypename.parse` and `CodegenModels.parse` read the upstream names, and refuse other names with the upstream message.

## Operation ids

The operation id is the SHA-256 of the minified document, in lowercase hexadecimal. The document is the operation, printed as `apollo-ast` prints it, followed by the fragments that it uses. A fragment comes after the fragments that it uses. The minifier replaces each whitespace character and the spaces after it by one space.

The tests compare the ids of 95 operations of the upstream compiler tests with the upstream output. The four operations of `bench/fixtures/github-query.graphql` also have the ids and the class names of the `apollo-compiler` 5.2.0 output. The section [Benchmark](#benchmark) tells how to make that output.

## The generated module

The module imports only `gql_json`. Every line is at most 80 columns, and `mojo format` keeps the module as it is.

| Element | Mojo |
| --- | --- |
| Operation `Hero` | `struct HeroQuery` with `OPERATION_ID`, `OPERATION_NAME`, `OPERATION_DOCUMENT` and `parse_data` |
| Its variables | `struct HeroQuery_Variables` with `__init__`, `write_json` and `false_variables` |
| Its data | `struct HeroQuery_Data`, and one struct per nested model, such as `HeroQuery_Data_Hero_OnDroid` |
| Fragment `HeroDetails` | `struct HeroDetails`, and its nested models |
| Enum `Episode` | `struct Episode` with one `comptime` value per enum value, `UNKNOWN__`, `raw_value`, `safe_value_of` and `is_valid` |
| Input object `ReviewInput` | `struct ReviewInput` with `__init__` and `write_json` |

Each model struct has a `from_json(document, node, false_variables)` method. It reads a `gql_json` value. An inline fragment and a fragment spread are synthetic fields, such as `onDroid` and `heroDetails`. A synthetic field is read when its type condition and its `@include` and `@skip` conditions are true.

The types map as follows:

- `String` and `ID` map to `String`, `Int` to `Int`, `Float` to `Float64` and `Boolean` to `Bool`.
- A custom scalar is the `String` of its JSON text.
- A nullable type is an `Optional`, and a list is a `List`.
- A variable or an input field that can be absent has one more `Optional`. `None` is absent.

`write_json(writer, with_default_values)` writes the variables as upstream `serializeVariables` does. `false_variables` returns the Boolean variables that are false, with the default values. `parse_data` passes them to the data model, as upstream `falseVariables`.

## Differences from upstream

- The output is one Mojo module, not one Kotlin file per class. A nested Kotlin class is a flat struct named after its path.
- `CodegenModels` supports `operationBased`, `responseBased` and `experimental_operationBasedWithInterfaces`.
- The validation messages are the graphql-js messages of `gql_validation`. In 8 of 20 upstream validation fixtures, the first location of a graphql-js error is another place than the upstream issue.
- The schema check is the graphql-js check, which is stricter than the `apollo-ast` check.
- `@link` to the Apollo foreign schemas is not ported. So `@nonnull`, `@optional`, `@catch`, `@semanticNonNull`, `@typePolicy`, `@targetName` and `@requiresOptIn` are not read.
- Compiled selections, data builders, key fields and documentation comments are not generated.
- The variables that a fragment uses are not inferred, because a fragment struct has no variables.
- A missing nullable field reads as null. An unknown enum value reads as `UNKNOWN__`, without its raw value.
- A `@defer` fragment that does not read, because its data has not arrived, reads as `None`.
- A Mojo keyword gets a `_` suffix: the field `from` is the property `from_`.
- Correction: a string with a character from U+0080 to U+009F prints as `\u0080` to `\u009f`. Upstream 5.2.0 throws `StringIndexOutOfBoundsException` there, in `Byte.hexString`.

## Tests

The suites are in `tests/gql_codegen/`. They port the language-independent expectations of the upstream tests:

- `test_operation_ids.mojo`: the operation ids and documents of `CodegenTest.kt`.
- `test_ir.mojo`: the used coordinates of each fixture, and the model trees of six fixtures.
- `test_errors.mojo`: the issues of `CheckCapitalizedFieldsTest.kt`, and the places of the `ExecutableValidationTest.kt` fixtures.
- `test_generated.mojo`: it compiles `_generated_starwars.mojo`, the output for `fixtures/golden/`, and runs it.

`make coverage` copies only the Mojo files, so the suites read the fixtures from `_fixture_data.mojo`. After a change in `fixtures/`, run `.venv/bin/mojo run -I . tests/gql_codegen/_embed.mojo` from the repository root. `test_fixture_data.mojo` checks that the module holds the files.

## Benchmark

`bench/gql_codegen/codegen.mojo` generates the models of `bench/fixtures/github-query.graphql` against `bench/fixtures/github-schema.graphql`. The baseline in `bench/baselines/kotlin-codegen/` runs `apollo-compiler` 5.2.0 on a JDK 21, with a heap of 4 GiB. Both build the schema outside the timer. Each operation reads the document, compiles it and writes the source.

| Workload | Mojo | apollo-compiler 5.2.0 (JVM) |
| --- | --- | --- |
| `apollo-kotlin/codegen-github-query` | 9.31 ms | 138.62 ms |

The baseline needs a JDK 21 in `$JAVA_HOME` or `~/jdk`, and Gradle in `$GRADLE` or `~/gradle/gradle-8.14.3`. `./run.sh --emit <directory>` in the baseline directory writes the upstream Kotlin output, to compare the ids.
