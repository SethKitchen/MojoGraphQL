<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Validation

`gql_validation` checks an executable document against a schema. It is a port of graphql-js 16.14.2 `src/validation` and `src/utilities/TypeInfo.ts`, and it needs `gql_language` and `gql_schema`.

## Validate

`gql_validation.validate` runs the validation rules over a document. The error messages, the locations and the order of the errors are the same as in graphql-js.

| Function | graphql-js | Result |
| --- | --- | --- |
| `validate(schema, document)` | `validate(schema, documentAST)` | `List[GraphQLError]` |
| `validate(schema, document, rules)` | `validate(schema, documentAST, rules)` | `List[GraphQLError]` |
| `validate(schema, document, rules, options)` | `validate(schema, documentAST, rules, options)` | `List[GraphQLError]` |
| `specified_rules()` | `specifiedRules` | `List[ValidationRule]` |
| `recommended_rules()` | `recommendedRules` | `List[ValidationRule]` |

The result is empty for a valid document. `validate` raises an `Error` when the schema is not valid. The message of the `Error` is the message of each schema error, joined by a blank line (`"\n\n"`).

```mojo
from gql_language.parser import parse
from gql_schema.build import build_schema
from gql_validation.validate import validate

var schema = build_schema("type Query { greeting: String }")
for error in validate(schema, parse("{ greting }")):
    print(error.message)  # Cannot query field "greting" on type "Query". Did you mean "greeting"?
```

### Options

`ValidationOptions` holds the options of `validate`.

| Field | graphql-js | Default | Effect |
| --- | --- | --- | --- |
| `max_errors` | `maxErrors` | 100 | The number of errors to keep. The next error becomes `Too many validation errors, error limit reached. Validation aborted.`, and the walk stops. |
| `assume_valid_schema` | none | `False` | Skip the check of the schema. |

graphql-js keeps the result of the schema check on the schema object. graphql-js also does not check a schema that it built with `assumeValid`. A Mojo schema has no such cache. Set `assume_valid_schema` when you checked the schema before, or when you built it with `assume_valid`.

### Rules

A `ValidationRule` is a value, not a function. `ValidationRule.text()` gives the graphql-js name of the rule. `specified_rules()` gives the first 27 rules, in this order:

| `ValidationRule` | graphql-js rule |
| --- | --- |
| `EXECUTABLE_DEFINITIONS` | `ExecutableDefinitionsRule` |
| `UNIQUE_OPERATION_NAMES` | `UniqueOperationNamesRule` |
| `LONE_ANONYMOUS_OPERATION` | `LoneAnonymousOperationRule` |
| `SINGLE_FIELD_SUBSCRIPTIONS` | `SingleFieldSubscriptionsRule` |
| `KNOWN_TYPE_NAMES` | `KnownTypeNamesRule` |
| `FRAGMENTS_ON_COMPOSITE_TYPES` | `FragmentsOnCompositeTypesRule` |
| `VARIABLES_ARE_INPUT_TYPES` | `VariablesAreInputTypesRule` |
| `SCALAR_LEAFS` | `ScalarLeafsRule` |
| `FIELDS_ON_CORRECT_TYPE` | `FieldsOnCorrectTypeRule` |
| `UNIQUE_FRAGMENT_NAMES` | `UniqueFragmentNamesRule` |
| `KNOWN_FRAGMENT_NAMES` | `KnownFragmentNamesRule` |
| `NO_UNUSED_FRAGMENTS` | `NoUnusedFragmentsRule` |
| `POSSIBLE_FRAGMENT_SPREADS` | `PossibleFragmentSpreadsRule` |
| `NO_FRAGMENT_CYCLES` | `NoFragmentCyclesRule` |
| `UNIQUE_VARIABLE_NAMES` | `UniqueVariableNamesRule` |
| `NO_UNDEFINED_VARIABLES` | `NoUndefinedVariablesRule` |
| `NO_UNUSED_VARIABLES` | `NoUnusedVariablesRule` |
| `KNOWN_DIRECTIVES` | `KnownDirectivesRule` |
| `UNIQUE_DIRECTIVES_PER_LOCATION` | `UniqueDirectivesPerLocationRule` |
| `KNOWN_ARGUMENT_NAMES` | `KnownArgumentNamesRule` |
| `UNIQUE_ARGUMENT_NAMES` | `UniqueArgumentNamesRule` |
| `VALUES_OF_CORRECT_TYPE` | `ValuesOfCorrectTypeRule` |
| `PROVIDED_REQUIRED_ARGUMENTS` | `ProvidedRequiredArgumentsRule` |
| `VARIABLES_IN_ALLOWED_POSITION` | `VariablesInAllowedPositionRule` |
| `OVERLAPPING_FIELDS_CAN_BE_MERGED` | `OverlappingFieldsCanBeMergedRule` |
| `UNIQUE_INPUT_FIELD_NAMES` | `UniqueInputFieldNamesRule` |
| `MAX_INTROSPECTION_DEPTH` | `MaxIntrospectionDepthRule`, the one rule of `recommendedRules` |

Two custom rules of graphql-js are not in `specified_rules()`. Give them in the rule list to use them.

| `ValidationRule` | graphql-js rule |
| --- | --- |
| `NO_DEPRECATED_CUSTOM` | `NoDeprecatedCustomRule` |
| `NO_SCHEMA_INTROSPECTION_CUSTOM` | `NoSchemaIntrospectionCustomRule` |

graphql-js runs all rules in one walk of the document. At each node, `TypeInfo` enters the node, and then each rule sees it in the order of the list. This port does the same walk, so the errors come in the same order. Before the walk, `validate` makes a table of the rules that handle each node kind. A node calls only those rules.

## TypeInfo

`gql_validation.type_info.TypeInfo` tracks the schema types at each node of a walk. Call `enter` on entry to each node and `leave` on exit, as graphql-js `visitWithTypeInfo` does.

| Method | graphql-js | Result |
| --- | --- | --- |
| `TypeInfo(schema)` | `new TypeInfo(schema)` | A walk from a document |
| `TypeInfo(schema, initial_type)` | `new TypeInfo(schema, initialType)` | A walk from a node of a type |
| `enter(schema, document, node)` | `enter(node)` | Updates the stacks |
| `leave(document, node)` | `leave(node)` | Updates the stacks |
| `get_type()` | `getType()` | `TypeRef` |
| `get_parent_type()` | `getParentType()` | A type index |
| `get_input_type()` | `getInputType()` | `TypeRef` |
| `get_parent_input_type()` | `getParentInputType()` | `TypeRef` |
| `get_field_def()` | `getFieldDef()` | A field index, or a meta field |
| `get_default_value()` | `getDefaultValue()` | The input value that holds the default value, or -1 |
| `get_directive()` | `getDirective()` | A directive index |
| `get_argument()` | `getArgument()` | An input value index, or `TYPE_NAME_META_ARGUMENT` |
| `get_enum_value()` | `getEnumValue()` | An enum value index |

`NO_TYPE_REF`, `NO_TYPE`, `NO_FIELD` and `NO_ARGUMENT` are the graphql-js `undefined`. `is_defined(type)` tells if a `TypeRef` names a type. The meta fields are `TYPENAME_META_FIELD`, `SCHEMA_META_FIELD` and `TYPE_META_FIELD`. `field_type` and `argument_type` give their types.

The module also has `type_from_ast(schema, document, node)`, the port of graphql-js `typeFromAST`. `has_default_value(schema, holder)` tells if the coerced default value of an input value is defined.

## ValidationContext

`gql_validation.context.ValidationContext` holds what the rules share during one validation. It is a port of graphql-js `ValidationContext`.

| Method | graphql-js | Result |
| --- | --- | --- |
| `report_error(document, message, node)` | `reportError` | Adds an error at a node |
| `report_error_nodes(document, message, nodes)` | `reportError` | Adds an error at each node |
| `keep_error(error)` | `reportError(error)` | Adds an error that is already made |
| `get_fragment(document, name)` | `getFragment(name)` | The last fragment definition with the name |
| `get_fragment_spreads(document, selection_set)` | `getFragmentSpreads(node)` | `List[Int]` of spread nodes |
| `get_recursively_referenced_fragments(document, operation)` | `getRecursivelyReferencedFragments(operation)` | `List[Int]` of fragment definitions |
| `get_variable_usages(schema, document, definition)` | `getVariableUsages(node)` | `List[VariableUsage]` |
| `get_recursive_variable_usages(schema, document, operation)` | `getRecursiveVariableUsages(operation)` | `List[VariableUsage]` |

## Differences from graphql-js

- `validate` checks the schema on each call, unless `assume_valid_schema` is set. graphql-js keeps the result on the schema.
- A rule that is in the list more than once runs once.
- `validate` takes no `TypeInfo`, and `TypeInfo` has no `getFieldDefFn`. A rule is a value, so there are no custom rule functions.
- When `@skip` or `@include` on a subscription field has a missing or invalid `if`, graphql-js throws a `GraphQLError`. `validate` raises an `Error` with the same message, but with no location.
- `ValuesOfCorrectTypeRule` reads an `Int` literal of 20 or more digits as out of range, as graphql-js does. It does not use `gql_schema.values.parse_literal` for such a literal, because that function cannot read it.
- `FieldsOnCorrectTypeRule` sorts its suggestions as the V8 `Array.prototype.sort` does for up to 64 items. The comparison of graphql-js is not transitive, so the order depends on the sort. For more than 64 items, the order is the same only when the comparison is consistent.
- `OverlappingFieldsCanBeMergedRule` sorts equal fields into classes and compares each pair of classes once. The errors are the same as in graphql-js, but the rule does less work for many equal fields.
- `TypeInfo.get_default_value` gives the input value that holds the default value, not the coerced value.
