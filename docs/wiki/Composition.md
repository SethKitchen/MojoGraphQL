<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Composition

`gql_composition` validates Apollo Federation subgraphs and prints a supergraph. It is a port of Hive Federation Composition v0.27.0 (`6272ad8`, MIT, The Guild), and it needs only `gql_language`. Validation is the subgraph phase of upstream `validate`. Composition is the printed part of upstream `composeServices`.

## Validate subgraphs

`gql_composition.validate.validate_subgraphs` runs the subgraph phase on a list of subgraphs. The messages, the codes and the order of the errors are the same as in upstream.

| Function | Upstream | Result |
| --- | --- | --- |
| `validate_subgraphs(subgraphs)` | the subgraph phase of `validate(subgraphs)` in `src/validate.ts` | `List[CompositionError]` |
| `Subgraph(name, url, type_defs)` | `ServiceDefinition` | A subgraph with a parsed `Document` |

The result is empty when every subgraph is valid. The first four steps are the upstream steps. Step 5 comes from the public federation page.

1. Give each subgraph an id, and sort the subgraphs by id (`buildGraphList`).
2. Check the `@link` directives of each subgraph (`validateSubgraphCore`). When a subgraph has a `@link` error, the result is the `@link` errors of all subgraphs, and the next steps do not run.
3. Find the federation version of each subgraph (`detectFederationVersion`).
4. Walk each subgraph with the state builder and the federation rules, check the state (`validateSubgraphState`), and walk the full document with the GraphQL rules (`validateSubgraph`).
5. When step 4 reports no errors, run the later checks. The later checks cover required query, type kind, and import names. They cover an interface field with no implementation and an extension with no base. They cover field types, field sharing, field arguments, and enum values. They cover an `@override` chain that revisits a subgraph. They cover a labeled `@override` of a field that uses `@requires`. They cover an `@external` field with no base, and one whose type differs from the merged type. They cover a public field or argument that references an `@inaccessible` type. They cover an interface `@key` whose subgraph misses an implementation type.

`validate_subgraphs` raises an `Error` where upstream throws. That is the case for two subgraphs with the same name, a `@link` without `url`, or a `@fromContext` selection that does not parse.

```mojo
from gql_language.parser import parse
from gql_composition.validate import Subgraph, validate_subgraphs

var sdl = String("type Query { a: String }\ntype Query { b: String }")
for error in validate_subgraphs([Subgraph("users", None, parse(sdl))]):
    print(error)  # [INVALID_GRAPHQL] [users] There can be only one type named "Query".
```

`CompositionError` has three fields:

| Field | Upstream | Value |
| --- | --- | --- |
| `message` | `message` | The message, with the `[<subgraph>] ` prefix |
| `code` | `extensions.code` | An `ErrorCode`, such as `ErrorCode.INVALID_GRAPHQL` |
| `subgraph_name` | `extensions.subgraphName` | The name of the subgraph |

`String(error)` gives `[<code>] <message>`.

## Compose a supergraph

`gql_composition.compose.compose_subgraphs` validates the subgraphs and then prints the supergraph. When validation reports an error, `supergraph_sdl` is empty.

The printer covers scalars, objects, interfaces, unions, enums, and input objects. It prints `@join__type`, `@join__field`, `@join__implements`, `@join__enumValue`, and `@join__unionMember`.

- A field that exists in every subgraph of its type, and that has no extra metadata, has no `@join__field`.
- `@external` on a key field is omitted.
- `@override` with no label removes the source field. A label keeps both fields and copies `overrideLabel` onto the source field.
- An enum value and a union member always list each graph.
- Two `@key` directives print two `@join__type` directives.

## Federation versions

The version table is `VERSION_NAMES` in `gql_composition.version`. A subgraph without a federation `@link` is `v1.0`. The table is data, so a new version is one new row.

| Version | New definitions | Source |
| --- | --- | --- |
| `v1.0` | `@key`, `@requires`, `@provides`, `@external`, `@extends`, `@override`, `_FieldSet`, and `@tag` and `@inaccessible` | Hive v0.27.0 |
| `v2.0` | `@shareable`, `@inaccessible`, `@tag`, `FieldSet` | Hive v0.27.0 |
| `v2.1` | `@composeDirective` | Hive v0.27.0 |
| `v2.2` | none | Hive v0.27.0 |
| `v2.3` | `@interfaceObject` | Hive v0.27.0 |
| `v2.4` | none | Hive v0.27.0 |
| `v2.5` | `@authenticated`, `@requiresScopes` | Hive v0.27.0 |
| `v2.6` | `@policy` | Hive v0.27.0 |
| `v2.7` | `@override(label:)` | Hive v0.27.0 |
| `v2.8` | `@context`, `@fromContext`, `@cost`, `@listSize` | Hive v0.27.0 |
| `v2.9` | none | Hive v0.27.0 |
| `v2.10`, `v2.11` | none | Apollo GraphOS page "Federation versions" |
| `v2.12` | `@cacheTag(format: String!) repeatable on FIELD_DEFINITION \| OBJECT`. Composition prints each application and the definition. A repeated format is printed once. A renamed import keeps its local name. `public_schema` removes them. | Apollo GraphOS page "Federation versions" |
| `v2.13`, `v2.14`, `v2.15` | none | Apollo GraphOS page "Federation versions" |

The page is apollographql.com/docs/graphos/schema-design/federated-schemas/reference/versions. The pages specs.apollo.dev/federation/v2.10 and later do not exist. A version above `v2.15` gives `UNKNOWN_FEDERATION_LINK_VERSION`.

## Rules

The federation rules run in the upstream order of `federationRules`. The GraphQL rules run after them, in the upstream order of `graphqlRules`.

| Module | Upstream files |
| --- | --- |
| `rules_basic` | `reserved-subgraph-name-rule.ts`, `known-federation-directive-rule.ts`, `elements/field-set.ts`, `query-root-type-inaccessible-rule.ts`, `known-type-names-rule.ts`, `known-root-type-rule.ts`, `root-type-used-rule.ts` |
| `rules_marks` | `elements/inaccessible.ts`, `elements/tag.ts` |
| `rules_auth` | `elements/authenticated.ts`, `elements/policy.ts`, `elements/requires-scopes.ts` |
| `rules_elements` | `elements/cost.ts`, `interface-object.ts`, `extends.ts`, `shareable.ts`, `external.ts`, `override.ts`, `context.ts`, `compose-directive.ts` |
| `rules_from_context` | `elements/from-context.ts` |
| `rules_list_size` | `elements/list-size.ts` |
| `rules_field_sets` | `elements/key.ts`, `elements/provides.ts`, `elements/requires.ts` |
| `rules_graphql` | the 15 GraphQL rules, such as `known-directives-rule.ts` and `unique-type-names-rule.ts` |
| `validate_state` | `validate-state.ts` |
| `later_versions` | `required-query-rule.ts`, `types-of-the-same-kind-rule.ts`, `link-import-name-mismatch-rule.ts`, and the public `v2.14` and `v2.15` checks |
| `extension_base` | `extension-with-base.ts` |
| `field_types` | `fields-of-the-same-type-rule.ts` |
| `field_arguments` | `field-arguments-of-the-same-type-rule.ts` |
| `enum_values` | `enum-values-rule.ts` |
| `override_source` | `override-source-has-override.ts` |
| `override_label` | `override-label-with-requires.ts` |
| `external_missing` | `external-missing-on-base-rule.ts` |
| `contextual_argument` | `contextual-argument-rule.ts` |
| `list_size_slicing` | `list-size-slicing-arguments-rule.ts` |
| `interface_subtype` | `interface-subtype-rule.ts` |
| `implemented_inaccessible` | `no-inaccessible-on-implemented-interface-fields-rule.ts` |
| `required_inaccessible` | `required-argument-or-field-is-not-inaccessible-rule.ts` |
| `auth_requires` | `auth-on-requires-rule.ts` and `auth-on-context-rule.ts` |
| `directive_composition` | `directive-composition-rule.ts` |
| `subgraph_name` | `subgraph-name-rule.ts` |
| `interface_object_usage` | `interface-object-usage-error.ts` |
| `interface_key` | `interface-key-missing-implementation-type.ts` |
| `interface_field` | `interface-field-no-implementation-rule.ts` |
| `external_type` | `external-type-mismatch-rule.ts` |
| `input_values` | `input-object-values-rule.ts` |
| `required_argument` | `required-argument-missing-in-some-subgraph-rule.ts` |
| `required_input` | `required-input-field-missing-in-some-subgraph-rule.ts` |
| `external_argument` | `external-argument-missing-rule.ts` |
| `input_default` | `input-field-default-mismatch-rule.ts` |
| `argument_default` | `field-argument-default-mismatch-rule.ts` |
| `inaccessible_default` | `default-value-uses-inaccessible-rule.ts` |
| `only_inaccessible` | `only-inaccessible-children-rule.ts` |
| `referenced_inaccessible` | `referenced-inaccessible-rule.ts` |
| `field_sharing` | `invalid-field-sharing-rule.ts` |
| `join_spec` | `specifications/join.ts` and the join URL table of `compose.ts` |

## Differences from upstream

- Upstream compares versions with `parseFloat`. This port keeps a version as `major * 100 + minor`, so `v2.10` is above `v2.9`. The same comparison applies to a feature `@link`, so `v1.10` stays above `v1.9`. Upstream `mergeLinks` keeps `v1.9`. Upstream v0.27.0 does not know `v2.10` to `v2.15`.
- `satisfies_version_range` reads a bound such as `>= v2.9`. It compares only the versions in `VERSION_NAMES`. For other text, it returns False. Upstream types both arguments as federation versions.
- The subgraphs are sorted by id with a comparison that agrees with `localeCompare` for the ids that `constantCase` makes.
- The specified directives of the GraphQL rules are those of graphql-js 16.14.2.
- Some upstream branches cannot run, and this port does not have them. The module docstrings list them.
- From `v2.15`, a custom specification cannot use `https://specs.apollo.dev`. The check reads the federation `@link` of the subgraph. An Apollo specification, such as `cost`, can use that domain.
- From `v2.14`, a Federation 1 `@key` on an interface `T` conflicts with `@interfaceObject` on `T`. From `v2.15`, an interface cannot implement an `@interfaceObject` type. These checks read the highest version of the subgraphs.
- Hive v0.27.0 does not know `v2.14` and `v2.15`, and it does not have these checks. Below these versions, the result is the result of Hive v0.27.0.

## Tests

The tests are in `tests/gql_composition/`. Each `test_*.mojo` file is a port of one upstream file of `__tests__`, for the Guild implementation. The subgraph files (`__tests__/subgraph/**`) are ported in full. The expected errors come from upstream `composeServices` in Node.js on the same subgraphs.

Some test cases need a check that this port does not have yet, such as most of the satisfiability check. These cases expect the errors of the checks that this port has. `test_versions.mojo` tests the version table.

## Benchmarks

`bench/gql_composition/hive.mojo` validates the subgraphs of the upstream benchmark fixtures: the `basicServices` of `benchmark.ts`, `stars-stuff`, `dgs` and `huge-schema`. The baseline is `bench/baselines/js-composition/bench.mjs`, which runs the same subgraph phase of Hive Federation Composition 0.27.0 in Node.js.

## Not yet ported

Phase 2 must port these upstream files:

- The rest of `src/compose.ts`, `src/supergraph/state.ts`, and `src/supergraph/composition/*.ts`. The printer covers the kinds above. It prints `@tag`, `@inaccessible`, `@context`, and `@join__type(isInterfaceObject: true)`. An object that implements an `@interfaceObject` interface gains each interface field it does not define, with a bare `@join__field`. An implementor that already defines the field keeps `@authenticated`, `@policy`, and `@requiresScopes` from that interface object. An interface field argument does not print `@inaccessible`, and a field copied from that interface omits it too. An explicit `@deprecated` reason is printed, including `No longer supported`, an empty reason, and escaped control characters. The first subgraph in id order keeps that reason. Types, fields, and enum values follow that same subgraph. A later subgraph appends a name it introduces. An interface keeps those directives from each object that implements it, including on a field. An interface prints `extension: true` only when it has a key and the subgraph extends it. An object that is defined and extended in one subgraph does not print it. `@extends` does. A federation v1 `extend type` does not print it. A federation v1 interface does not print a key. A federation v2 interface key can print `resolvable: false`. `@fromContext` is printed as `contextArguments` on `@join__field`, in source order, with quotes in the selection escaped. An overridden source that is a key or an interface field prints `usedOverridden: true`. Descriptions are printed as block strings. The first subgraph to set a description wins, including an argument description. A field description keeps its line breaks. On an entity, a non-shareable `@override` replaces that field description, and an override with no description removes it. The subgraph URL is printed on `@join__graph`, with quotes and backslashes escaped. The subgraph name is escaped the same way, including in a `@context` prefix and in `@override(from:)`. `@tag` names are escaped the same way. A string escapes backspace, form feed, and other control characters. A field set inside `@join__field` escapes quotes the same way. Enum values stay in the order of the first subgraph that defines them. A custom query, mutation, or subscription root is printed as `Query`, `Mutation`, or `Subscription`. A custom query root merges with a subgraph that uses `Query`. A custom mutation root merges with `Mutation`. A custom subscription root merges with `Subscription`. A `@specifiedBy` URL escapes quotes. The first subgraph to set `@specifiedBy` wins. A default string escapes quotes and newlines. A block-string default is printed on multiple lines. A null default is printed as `null`. A delete character in a default or a `@tag` stays in the text. A field argument list longer than 80 characters is printed on multiple lines, with no commas. A directive definition uses that same wrapping. A directive argument does not print its description, `@deprecated`, or `@cost`. A field argument description is a block string on that argument. A type description is a block string before the type. An enum value and an input field keep their descriptions. A description on the schema definition is omitted. `@oneOf` from one subgraph is printed after `@tag`. A `@deprecated` reason on a field argument escapes quotes. Boolean, null, number, empty list, and empty object defaults keep their spelling. A float keeps its source spelling, including an exponent. A repeatable composed directive keeps each application and its arguments. The same application from another subgraph is printed once. The same rule applies to a directive on an argument, an enum value, or an input field. On a field, that directive is printed before `@join__field`, and `@tag` follows `@join__field`. Directive definitions and applications keep the first subgraph's order. A directive that only a later subgraph defines is appended. A later subgraph can add an argument and a location. The argument becomes non-null when any subgraph declares it non-null, and `repeatable` is set when any subgraph sets it. A later directive-argument default replaces an earlier one. A composed directive keeps a schema location from any subgraph. An executable location stays only when every definition lists it. `@tag` names on a directive argument are combined, and `@inaccessible` is kept when any subgraph sets it. `@deprecated` is printed on fields, arguments, enum values, and input fields. `@authenticated`, `@policy`, and `@requiresScopes` are printed on types and fields. `@cost` and `@listSize` are printed when a subgraph uses them, including a weight or `assumedSize` of zero, on a scalar and an enum too. A renamed import keeps that local name. A renamed `@tag`, `@inaccessible`, `@authenticated`, `@policy`, or `@requiresScopes` import is printed under its specification name. `@requires` and `@provides` print one space between top-level fields. A nested selection is printed as `name{child1 child2}`. An inline fragment in `@requires` is printed as `...on Type{child}`. `@provides` on a union keeps its source text. A field argument is kept, and spaces around its punctuation are removed. The next field follows `)` with no space. A list value keeps one space between items, and an object value has no spaces inside its braces. `@requires` drops a leaf that is in every `@key` of that type. A nested key such as `address { id }` stays in the nested selection. The `@join__type` key keeps its source spacing. Each `@key` is its own `@join__type`, and `resolvable: false` stays on that key. `@join__field` is printed before `@tag`, `@inaccessible`, `@authenticated`, `@cost`, `@listSize`, and `@deprecated`. A field argument prints its description, then `@tag`, `@inaccessible`, `@cost`, and `@deprecated`. A union prints `@join__unionMember` before `@tag` and `@inaccessible`. Its description stays in front. `@listSize` keeps the highest `assumedSize`, combines slicing arguments and sized fields, and prints `requireOneSlicingArgument: false` when any subgraph sets it false. A slicing argument that is missing from one subgraph is omitted. An empty `slicingArguments` or `sizedFields` list is printed. A negative `@cost` weight is printed, and the highest weight wins, including on an argument. An empty `@policy` or `@requiresScopes` group is printed. Merged with a named group, it becomes that named group. A group that contains another group is dropped. Groups of equal length are sorted by their text. An interface field prints `requireOneSlicingArgument: true` when an implementor also has `@listSize` slicing arguments. A directive named by `@composeDirective` is printed on the element that uses it. That element can be an argument, an input field, an enum value, or the type. Its definition is printed in the supergraph. Locations, arguments, and `repeatable` are merged across subgraphs. An argument keeps `@tag` and `@inaccessible`. `@specifiedBy` is printed on a scalar. `@oneOf` is printed on an input object. A field type that is less non-null in one subgraph prints `type` on each `@join__field`. The schema lists a mutation root and a subscription root when a subgraph defines them. An argument or an input field that is missing from one subgraph is omitted. An input field becomes non-null when any subgraph declares it non-null, and each `@join__field` prints `type`. An argument becomes non-null when any subgraph declares it non-null. A default value on any subgraph is kept. An input-field default is printed only when every subgraph that defines the field sets one. `@deprecated` and `@inaccessible` on an argument are kept when any subgraph sets them. `@tag` names on an argument are combined, and `@cost` keeps the highest weight. An interface field or a query field keeps the less non-null type and does not print `type` on `@join__field`. An interface field that every subgraph defines does not print `@join__field`. A query field in every subgraph does not print `@join__field` unless it uses `@override`. The overridden source is omitted, and another `@shareable` query field stays. A labeled query `@override` keeps the source without `overrideLabel`. An object field copies `overrideLabel` onto its source, and another `@shareable` field stays without that label. `@join__implements` lists only the interfaces that subgraph defines. An object then prints `@tag`, authorization, and `@cost`. An interface does the same when it implements another interface. It then prints `@tag`. An implementor lists interfaces in its source order. Each graph lists its union members in that graph's source order. A union with one member prints that member. An unused scalar is printed. Its directives follow `@join__type`, `@tag`, `@inaccessible`, authorization, `@cost`, and `@specifiedBy`. An input object prints `@oneOf` after `@tag` and `@inaccessible`. An input field prints `@cost` before `@deprecated`. An enum value prints `@join__enumValue`, then `@tag`, `@inaccessible`, and `@deprecated`. An interface field that is missing from one subgraph still prints `@join__field`. It prints `type` only on a subgraph whose type differs from the merged type. Query prints `@join__type` for every subgraph, with no key. Mutation and Subscription print `@join__type` only for a subgraph that defines them. A mutation field does print `type` when the subgraphs disagree. `@deprecated` and `@inaccessible` on an enum value are kept when any subgraph sets them. An enum used only as an input keeps the values that every subgraph defines. An enum used as both an input and an output keeps an `@inaccessible` value that another subgraph omits. A federation v1 `@external` field that no `@key`, `@requires`, or `@provides` uses is omitted from `@join__field`. When that was its only subgraph, the field is omitted. A default value is printed on an argument and on an input field. These rules do run: `TypesOfTheSameKindRule`, `ExtensionWithBaseRule`, `FieldsOfTheSameTypeRule`, and `InvalidFieldSharingRule`. These rules do run: `FieldArgumentsOfTheSameTypeRule`, `EnumValuesRule`, `OverrideSourceHasOverrideRule`, and `OverrideLabelWithRequiresRule`. These rules do run: `ExternalMissingOnBaseRule`, `InputObjectValuesRule`, `RequiredArgumentMissingInSomeSubgraph`, and `RequiredInputFieldMissingInSomeSubgraphRule`. These rules do run: `ExternalArgumentMissingRule`, `InputFieldDefaultMismatchRule`, `FieldArgumentDefaultMismatchRule`, and `DefaultValueUsesInaccessibleRule`. These rules do run: `OnlyInaccessibleChildrenRule`, `ReferencedInaccessibleRule`, `ExternalTypeMismatchRule`, and `InterfaceFieldNoImplementationRule`. These rules do run: `InterfaceKeyMissingImplementationTypeRule`, `RequiredArgumentOrFieldIsNotInaccessibleRule`, and `NoInaccessibleOnImplementedInterfaceFieldsRule`. These rules do run: `InterfaceSubtypeRule`, `ListSizeSlicingArgumentsRule`, `ContextualArgumentRule`, and `InterfaceObjectUsageErrorRule`. These rules do run: `SubgraphNameRule` and `DirectiveCompositionRule`. The `@authenticated`, `@requiresScopes`, and `@policy` parts of `AuthOnRequiresRule` do run.
- Supergraph validation: `src/supergraph/validation/validate-supergraph.ts` and `validation-context.ts`. The rules named above run. The rest of `src/supergraph/validation/rules/` is not ported.
- Satisfiability: `satisfiability` checks object fields, `@key`, `@external`, and `@requires`, including a nested path such as `users { edges { node { name } } }`, and a federation v1 subgraph with no `@link`. An unlabeled `@override` removes the field from the source subgraph. A `@provides` selection resolves those fields without a `@key` move, including a nested selection such as `address { city }`. A nested `@requires` selection such as `address { id }` is checked on the returned type. A key with `resolvable: false` cannot be used to enter that subgraph. A `@fromContext` argument needs that subgraph's `@context` on an ancestor. The type's own `@context` does not satisfy its fields. A labeled `@override` keeps the source field, and the overriding subgraph must resolve that field on its own. It reports `SATISFIABILITY_ERROR`. The first path to a leaf is the one reported. `compose_subgraphs` does not run it yet. A query that returns an interface checks each object that implements it, and a union checks each member. The example query prints `... on` that object. An `@interfaceObject` whose interface `@key` is not resolvable cannot reach an implementation. The rest of `satisfiablity/*.ts` is not ported.
- Satisfiability messages: for an input-object argument, Hive prints the non-null fields as `{field: value}` in the example query. This port prints `"A string value"`. In some cases, Hive lists the reasons of more than one subgraph, and this port does not. Hive reports a missing context on a root query field, and this port does not check root fields.
- Cost: the supergraph part of `@cost` and `@listSize`, in `supergraph/composition` and `list-size-slicing-arguments-rule.ts`.
- Contracts: `compose_contract` ports tag filtering and unreachable `@inaccessible` marking from `src/contracts/`. A tag on a type is copied onto its fields, arguments, and enum values, including a field that only another subgraph defines. A field tag is the union across subgraphs, so a tag in one subgraph hides that field in every subgraph. An unreachable type name must end at the match, so `Item` does not mark `ItemExtra`. An `@external` field keeps its `@tag`. A renamed `@tag` import is honored. Include and exclude both apply. An excluded enum value or argument is `@inaccessible`. A type whose fields are all excluded, an excluded scalar, and an excluded union become `@inaccessible`. The reachable-type walk is the public schema. `schema-contract.ts` still removes unreachable types inside the supergraph document with graphql-js `buildASTSchema`; this port marks the same types on the printed SDL.
- Public schema: `public_schema` ports `src/graphql/transform-supergraph-to-public-schema.ts`. `sort_sdl` ports `sort-sdl.ts`. `contains_supergraph_spec` ports `contains-supergraph-spec.ts`. `LinkUrl.supports` ports `FederatedLinkUrl.supports`. `links_from_document` and `resolve_imported_name` port `extractLinkImplementations`. The pinned Hive package has no `src/utils/dependency-graph.ts`.
- The other `v2.14` and `v2.15` composition changes on the Apollo GraphOS page. They need the supergraph phase. They include `@override` label removal, `@composeDirective` merging, `@link` name conflicts, `@tag` checks, root type inference, hints and default value normalization.
