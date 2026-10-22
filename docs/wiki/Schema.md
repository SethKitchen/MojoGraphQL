<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Schema

`gql_schema` holds the GraphQL type system. It is a port of graphql-js 16.14.2 `src/type` and `src/utilities`, and it needs only `gql_language`.

## Build, extend and print

`gql_schema.build` makes a `Schema` from SDL, and `gql_schema.print` prints a `Schema` back as SDL. The type map order, the field order and the printed text are the same as in graphql-js.

| Function | graphql-js | Result |
| --- | --- | --- |
| `build_schema(sdl, options)` | `buildSchema(source, options)` | `Schema` |
| `build_ast_schema(documents, options)` | `buildASTSchema(documentAST, options)` | `Schema` |
| `extend_schema(schema, document, options)` | `extendSchema(schema, documentAST, options)` | `Schema` |
| `print_schema(schema)` | `printSchema(schema)` | `String` |
| `print_introspection_schema(schema)` | `printIntrospectionSchema(schema)` | `String` |
| `print_type(schema, type)` | `printType(type)` | `String` |

`BuildOptions` holds `parse_options`, `assume_valid_sdl` and `assume_valid`. When both flags are false, the functions check the SDL first with `assert_valid_sdl` or `assert_valid_sdl_extension`. A check that fails raises an `Error` with the graphql-js message.

```mojo
from gql_language.parser import parse
from gql_schema.build import build_schema, extend_schema
from gql_schema.print import print_schema

var schema = build_schema("type Query { greeting: String }")
var extended = extend_schema(schema, parse("extend type Query { farewell: String }"))
print(print_schema(extended))
```

A `Schema` keeps its documents. The built-in SDL is document 0. An `AstRef` names a node in one of the documents. A description is an `AstRef` to its `StringValue` node. `schema.description_text(at)` decodes it. The schema does not decode a description until you ask for it.

### Differences from graphql-js

- `extend_schema` returns a copy when the document changes nothing. graphql-js returns the same object. A Mojo schema is a value.
- A default value is kept as its literal. `print_schema` coerces it when it prints it, so the text is the same as in graphql-js.
- A description is decoded when you read it, not when the schema is built.
- A custom scalar always behaves as a scalar built from SDL: its literals use `valueFromASTUntyped`, and it prints a value without change. In graphql-js, `parseLiteral` and `serialize` can be JavaScript functions. An enum value's internal value is always its name.
- `gql_schema.values` has no variables. It behaves as graphql-js does when no variable has a value.
- A `JsValues` tree holds only JSON-like values: no functions, classes, `valueOf` or `toJSON`. An array given for an input object type prints as `{}`.

## SDL validation

`gql_schema.sdl_validation` checks SDL before a schema is built from it. It is a port of graphql-js `validateSDL`, `assertValidSDL`, `assertValidSDLExtension` and the 15 rules of `specifiedSDLRules`. The error messages, the locations and the order of the errors are the same as in graphql-js.

| Function | graphql-js | Result |
| --- | --- | --- |
| `validate_sdl(documents)` | `validateSDL(documentAST)` | `List[GraphQLError]` |
| `validate_sdl(documents, schema_to_extend)` | `validateSDL(documentAST, schemaToExtend)` | `List[GraphQLError]` |
| `validate_sdl_with_rules(documents, rules)` | `validateSDL(documentAST, undefined, rules)` | `List[GraphQLError]` |
| `validate_sdl_with_rules(documents, schema_to_extend, rules)` | `validateSDL(documentAST, schemaToExtend, rules)` | `List[GraphQLError]` |
| `assert_valid_sdl(documents)` | `assertValidSDL` | Raises an `Error` |
| `assert_valid_sdl_extension(documents, schema)` | `assertValidSDLExtension` | Raises an `Error` |
| `specified_sdl_rules()` | `specifiedSDLRules` | `List[SDLRule]` |

`documents` is a `List[Document]`. The functions check the documents as one document, as graphql-js `concatAST` does. Each location of an error is in its own document.

The `assert_` functions raise an `Error` when there is an error. The message of the `Error` is the message of each error, joined by a blank line (`"\n\n"`).

```mojo
from gql_language.ast import Document
from gql_language.parser import parse
from gql_schema.sdl_validation import validate_sdl

var documents = List[Document]()
documents.append(parse("type A type A"))
for error in validate_sdl(documents):
    print(error.message)  # There can be only one type named "A".
```

### Rules

An `SDLRule` is a value, not a function. `SDLRule.text()` gives the graphql-js name of the rule. The rules run in this order:

| `SDLRule` | graphql-js rule |
| --- | --- |
| `LONE_SCHEMA_DEFINITION` | `LoneSchemaDefinitionRule` |
| `UNIQUE_OPERATION_TYPES` | `UniqueOperationTypesRule` |
| `UNIQUE_TYPE_NAMES` | `UniqueTypeNamesRule` |
| `UNIQUE_ENUM_VALUE_NAMES` | `UniqueEnumValueNamesRule` |
| `UNIQUE_FIELD_DEFINITION_NAMES` | `UniqueFieldDefinitionNamesRule` |
| `UNIQUE_ARGUMENT_DEFINITION_NAMES` | `UniqueArgumentDefinitionNamesRule` |
| `UNIQUE_DIRECTIVE_NAMES` | `UniqueDirectiveNamesRule` |
| `KNOWN_TYPE_NAMES` | `KnownTypeNamesRule` |
| `KNOWN_DIRECTIVES` | `KnownDirectivesRule` |
| `UNIQUE_DIRECTIVES_PER_LOCATION` | `UniqueDirectivesPerLocationRule` |
| `POSSIBLE_TYPE_EXTENSIONS` | `PossibleTypeExtensionsRule` |
| `KNOWN_ARGUMENT_NAMES_ON_DIRECTIVES` | `KnownArgumentNamesOnDirectivesRule` |
| `UNIQUE_ARGUMENT_NAMES` | `UniqueArgumentNamesRule` |
| `UNIQUE_INPUT_FIELD_NAMES` | `UniqueInputFieldNamesRule` |
| `PROVIDED_REQUIRED_ARGUMENTS_ON_DIRECTIVES` | `ProvidedRequiredArgumentsOnDirectivesRule` |

graphql-js runs all rules in one walk of the document. At each node, each rule sees the node in the order of the list. This port does the same walk, so the errors come in the same order.

When you give a schema to extend, the rules also use that schema. For example, a type definition with the name of a type in the schema gives the error `Type "X" already exists in the schema. It cannot also be defined in this type definition.`

### Suggestions

`gql_schema.suggestions` gives the "Did you mean" text of some messages. It is a port of graphql-js `suggestionList`, `didYouMean` and `naturalCompare`.

| Function | graphql-js | Result |
| --- | --- | --- |
| `suggestion_list(input, options)` | `suggestionList` | The options near the input, the nearest first |
| `did_you_mean(suggestions)` | `didYouMean` | Such as ` Did you mean "A" or "B"?` |
| `did_you_mean(sub_message, suggestions)` | `didYouMean` | Such as ` Did you mean the letter "A"?` |
| `lexical_distance(input, option, threshold)` | `LexicalDistance.measure` | The edit distance, or `-1` |
| `natural_compare(a, b)` | `naturalCompare` | A negative, zero or positive `Int` |

The functions compare bytes, and change the case of ASCII letters only. graphql-js compares UTF-16 code units. A GraphQL name is ASCII, so a name gives the same result.

### Differences from graphql-js

- graphql-js gives the location `ARGUMENT_DEFINITION` to a directive on a field of an `extend input`. This port does the same.

## Schema validation

`gql_schema.validate` checks a built schema against the type validation rules of the GraphQL specification. It is a port of graphql-js `validateSchema` and `assertValidSchema`. The error messages, the locations and the order of the errors are the same as in graphql-js.

| Function | graphql-js | Result |
| --- | --- | --- |
| `validate_schema(schema)` | `validateSchema(schema)` | `List[GraphQLError]`, empty for a valid schema |
| `assert_valid_schema(schema)` | `assertValidSchema(schema)` | Raises an `Error` |

`assert_valid_schema` raises an `Error` when there is an error. The message of the `Error` is the message of each error, joined by a blank line (`"\n\n"`).

```mojo
from gql_schema.build import build_schema
from gql_schema.validate import validate_schema

var schema = build_schema("type Query type Query2 { a: String }")
for error in validate_schema(schema):
    print(error.message)  # Type Query must define one or more fields.
```

The rules run in the graphql-js order:

1. The root types. A query type must exist. Each root type must be an object type.
2. The directives. Each directive must have a location. Each argument must have an input type.
3. Each type of the type map, in type map order. The check depends on the kind of the type.

| Kind | What the rules check |
| --- | --- |
| Object, interface | One or more fields, output field types, input argument types, and the fields and arguments of each implemented interface |
| Union | One or more members, object members only, each member once |
| Enum | One or more values |
| Input object | One or more fields, input field types, no cycle of non-null input object fields, and the `@oneOf` rules |

A name that starts with `__` is an error, except in the introspection types. A required argument or input field must not be deprecated.

An error location is the location of an AST node. When a type, field or argument has no AST node, its errors have no location.

### Type comparators

`gql_schema.type_comparators` compares types. It is a port of graphql-js `utilities/typeComparators.ts`.

| Function | graphql-js | Result |
| --- | --- | --- |
| `is_equal_type(type_a, type_b)` | `isEqualType` | True if the two `TypeRef` values are equal |
| `is_type_sub_type_of(schema, maybe_sub_type, super_type)` | `isTypeSubTypeOf` | True if the first type is equal to the second type, or is a subtype of it |
| `do_types_overlap(schema, type_a, type_b)` | `doTypesOverlap` | True if the two composite types have a common possible object type |

### Differences from graphql-js

- graphql-js keeps the errors on the schema and gives them again on the next call. A Mojo schema is a value that you can change, so `validate_schema` runs the rules on each call. Keep the result to validate one time.
- A type index out of range is the graphql-js `undefined`. A message shows it as `undefined`.
- graphql-js reports a value that is not a GraphQL type or directive. A Mojo schema holds only types and directives. Thus `Expected GraphQL named type` comes only from a type index out of range, or from a type with an invalid `TypeKind`.

## Schema utilities

These functions are ports of the graphql-js schema utilities. Each one is in its own module.

| Function | Module | graphql-js | Result |
| --- | --- | --- | --- |
| `find_breaking_changes(old_schema, new_schema)` | `gql_schema.find_breaking_changes` | `findBreakingChanges` | `List[BreakingChange]` |
| `find_dangerous_changes(old_schema, new_schema)` | `gql_schema.find_breaking_changes` | `findDangerousChanges` | `List[DangerousChange]` |
| `lexicographic_sort_schema(schema)` | `gql_schema.lexicographic_sort_schema` | `lexicographicSortSchema` | `Schema` |
| `type_from_ast(schema, document, node)` | `gql_schema.type_from_ast` | `typeFromAST` | `Optional[TypeRef]`, empty when the schema does not have the named type |
| `get_introspection_query(options)` | `gql_schema.introspection` | `getIntrospectionQuery` | `String` |
| `introspection_from_schema(schema, options, assume_valid)` | `gql_schema.introspection` | `introspectionFromSchema` | `JsonDocument` |
| `build_client_schema(document, introspection, assume_valid)` | `gql_schema.build_client_schema` | `buildClientSchema` | `Schema` |

### Breaking and dangerous changes

`find_breaking_changes` and `find_dangerous_changes` compare two schemas. They give the changes in the graphql-js order: first the type changes, in the type map order of the old schema, then the directive changes. The descriptions are the same text as in graphql-js.

A `BreakingChange` and a `DangerousChange` have a `type` and a `description`. The type is a `BreakingChangeType` or a `DangerousChangeType`. `text()` gives the graphql-js name, such as `FIELD_REMOVED`.

| `BreakingChangeType` | `DangerousChangeType` |
| --- | --- |
| `TYPE_REMOVED`, `TYPE_CHANGED_KIND`, `TYPE_REMOVED_FROM_UNION`, `VALUE_REMOVED_FROM_ENUM`, `REQUIRED_INPUT_FIELD_ADDED`, `IMPLEMENTED_INTERFACE_REMOVED`, `FIELD_REMOVED`, `FIELD_CHANGED_KIND`, `REQUIRED_ARG_ADDED`, `ARG_REMOVED`, `ARG_CHANGED_KIND`, `DIRECTIVE_REMOVED`, `DIRECTIVE_ARG_REMOVED`, `REQUIRED_DIRECTIVE_ARG_ADDED`, `DIRECTIVE_REPEATABLE_REMOVED`, `DIRECTIVE_LOCATION_REMOVED` | `VALUE_ADDED_TO_ENUM`, `TYPE_ADDED_TO_UNION`, `OPTIONAL_INPUT_FIELD_ADDED`, `OPTIONAL_ARG_ADDED`, `IMPLEMENTED_INTERFACE_ADDED`, `ARG_DEFAULT_VALUE_CHANGE` |

The functions compare default values in the form that introspection shows. They print each coerced value as `astFromValue` does, sort its object fields with `sort_value_node`, and print it again. A default that is not valid for its type counts as no default, as in graphql-js. The functions raise an `Error` when a default value cannot be printed, as graphql-js does.

```mojo
from gql_schema.build import build_schema
from gql_schema.find_breaking_changes import find_breaking_changes

var old_schema = build_schema("type Query { a: String b: Int }")
var new_schema = build_schema("type Query { a: String }")
for change in find_breaking_changes(old_schema, new_schema):
    print(change.type, change.description)  # FIELD_REMOVED Query.b was removed.
```

### Sort a schema

`lexicographic_sort_schema` returns a copy of a schema with everything sorted by name in natural order. That is the type map, the directives, and the fields, arguments, input fields, enum values, interfaces and union members of each type. The specified scalars and the introspection types keep their order, as in graphql-js. `print_schema` of the result is the same text as graphql-js.

A type keeps its index in `types`, so a `TypeRef` of the old schema names the same type in the new schema. The indices of fields, input values, enum values and directives change.

### Introspection and client schemas

`gql_schema.introspection` gives `get_introspection_query` and `introspection_from_schema`. `gql_schema.build_client_schema` builds a `Schema` from the `data` of an introspection result with `build_client_schema`.

### Differences from graphql-js in the schema utilities

- The change types are types with `is_valid`, not strings. `text()` gives the graphql-js string.
- graphql-js finds a change of kind from the JavaScript classes. This port uses the `TypeKind`. The result is the same for a schema built from SDL.
- `print_schema` and introspection read the locations of a directive from its definition node. So `lexicographic_sort_schema` puts the location names of each definition node in sorted order, in the copy of the document that the new schema holds. In graphql-js the `astNode` keeps its order, and only `locations` is sorted.
- `type_from_ast` returns an empty `Optional` in place of `undefined`.

### Tests of the schema utilities

The tests are ported from graphql-js 16.14.2 `findBreakingChanges-test.ts` and `lexicographicSortSchema-test.ts`. graphql-js 16.14.2 has no test file for `typeFromAST`, so `test_type_from_ast.mojo` tests each case of the function. The test "a directive was implicitly removed" removes `@deprecated` from a built schema, because a schema built from SDL always has the specified directives.
