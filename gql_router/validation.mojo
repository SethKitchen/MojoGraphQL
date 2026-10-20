# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Validate an operation against the consumer schema.

Port of Hive Router `1a29df9` `bin/router/src/pipeline/validation/mod.rs`
(`validate_operation_with_cache`), with the rule list of
`lib/graphql-tools/src/validation/rules/defaults.rs`
(`default_rules_validation_plan`) and the error shape of
`lib/graphql-tools/src/validation/utils.rs` and
`bin/router/src/executor/response/graphql_error.rs`.

`validation_schema` builds a `gql_schema` schema once per supergraph, from
the consumer schema: the supergraph without its `@inaccessible` elements
and without the federation internals. `validate_operation` checks a
document with `gql_validation`, and skips the check of the schema. Each
error gets the code of its `graphql_tools` rule, such as
`FieldsOnCorrectType`, in `extensions.code`, and the `graphql_tools`
message and locations. `Router` caches the result of each document text,
as upstream `validate_cache`.

**Differences from upstream.** Upstream checks the document with the
`graphql_tools` rules. This port checks it with the graphql-js rules of
`gql_validation`, and rewrites each error into the `graphql_tools` form:

- The "Did you mean" suggestions are removed, except the one of
  `LeafFieldSelections`, which `graphql_tools` also writes.
- `FieldsOnCorrectType` does not report a field whose name starts with
  `__`, as upstream.
- `KnownDirectives` writes `may not be used on FIELD` with no period.
  `UniqueDirectivesPerLocation` writes `Duplicate directive "name"` at the
  repeated directive. `UniqueVariableNames` writes `There can only be one
  variable`.
- `ValuesOfCorrectType` writes `Expected value of type "T", found V.` for
  a literal that a built-in scalar refuses, and the named type for a
  literal of an input object or a list. The `null` message and the
  non-enum message have no period. The errors have no locations.
- `KnownArgumentNames`, `NoUndefinedVariables`, `NoUnusedFragments`,
  `NoUnusedVariables`, `PossibleFragmentSpreads`, `UniqueFragmentNames`,
  `UniqueInputFieldNames` and `UniqueOperationNames` errors have no
  locations, as upstream. `VariablesInAllowedPosition` keeps only the
  location of the variable definition.
- The other locations and the order of the errors are those of
  graphql-js. Upstream reports some errors at a different node: for
  example `KnownTypeNames` reports a variable definition at its `$`, where
  graphql-js reports the type name.
- The rules `max_depth`, `max_directives` and `max_aliases` of
  `bin/router/src/pipeline/validation/` are not ported. Upstream adds them
  only when the `limits` configuration sets them, and it sets none by
  default.
- There are no plugin hooks. The cache key is the document text. Upstream
  hashes the schema, the rule list and the document text.
"""

from gql_language.ast import Document
from gql_language.error import GraphQLError as ValidationError
from gql_router.consumer_schema import PruneInaccessible, StripSchemaInternals
from gql_router.graphql_error import GraphQLError, error_json, error_with_code
from gql_schema.build import BuildOptions, build_ast_schema
from gql_schema.definition import Schema
from gql_validation.rules import ValidationRule
from gql_validation.validate import ValidationOptions, validate


@fieldwise_init
struct LocationPolicy(Equatable, ImplicitlyCopyable, Movable):
    """Which locations of a graphql-js error a `graphql_tools` rule keeps."""

    var value: UInt8
    """The policy's index; see `is_valid`."""

    comptime ALL = LocationPolicy(0)
    """Keep every location."""
    comptime NONE = LocationPolicy(1)
    """Keep no location: `graphql_tools` reports none."""
    comptime FIRST = LocationPolicy(2)
    """Keep the first location."""
    comptime LAST = LocationPolicy(3)
    """Keep the last location."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the four policies.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 3


def default_rules_validation_plan() -> List[ValidationRule]:
    """Return the rules of upstream `default_rules_validation_plan`, in
    its order.

    Returns:
        The 25 rules: the graphql-js specified rules without
        `ExecutableDefinitions` and `MaxIntrospectionDepth`.
    """
    return [
        ValidationRule.UNIQUE_OPERATION_NAMES,
        ValidationRule.LONE_ANONYMOUS_OPERATION,
        ValidationRule.SINGLE_FIELD_SUBSCRIPTIONS,
        ValidationRule.KNOWN_TYPE_NAMES,
        ValidationRule.FRAGMENTS_ON_COMPOSITE_TYPES,
        ValidationRule.VARIABLES_ARE_INPUT_TYPES,
        ValidationRule.SCALAR_LEAFS,
        ValidationRule.FIELDS_ON_CORRECT_TYPE,
        ValidationRule.UNIQUE_FRAGMENT_NAMES,
        ValidationRule.KNOWN_FRAGMENT_NAMES,
        ValidationRule.NO_UNUSED_FRAGMENTS,
        ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED,
        ValidationRule.NO_FRAGMENT_CYCLES,
        ValidationRule.POSSIBLE_FRAGMENT_SPREADS,
        ValidationRule.NO_UNUSED_VARIABLES,
        ValidationRule.NO_UNDEFINED_VARIABLES,
        ValidationRule.KNOWN_ARGUMENT_NAMES,
        ValidationRule.UNIQUE_ARGUMENT_NAMES,
        ValidationRule.UNIQUE_VARIABLE_NAMES,
        ValidationRule.PROVIDED_REQUIRED_ARGUMENTS,
        ValidationRule.KNOWN_DIRECTIVES,
        ValidationRule.VARIABLES_IN_ALLOWED_POSITION,
        ValidationRule.VALUES_OF_CORRECT_TYPE,
        ValidationRule.UNIQUE_INPUT_FIELD_NAMES,
        ValidationRule.UNIQUE_DIRECTIVES_PER_LOCATION,
    ]


def rule_error_code(rule: ValidationRule) -> String:
    """Return the `graphql_tools` `error_code` of a rule.

    Args:
        rule: A graphql-js rule.

    Returns:
        The graphql-js name without `Rule`, such as `FieldsOnCorrectType`.
        `ScalarLeafs` is `LeafFieldSelections` and `NoFragmentCycles` is
        `NoFragmentsCycle`, as upstream.
    """
    if rule == ValidationRule.SCALAR_LEAFS:
        return String("LeafFieldSelections")
    if rule == ValidationRule.NO_FRAGMENT_CYCLES:
        return String("NoFragmentsCycle")
    var name = String(rule.text())
    return String(name[byte = : name.byte_length() - 4])


def location_policy(rule: ValidationRule) -> LocationPolicy:
    """Return the locations that the `graphql_tools` form of a rule keeps.

    Args:
        rule: A graphql-js rule.

    Returns:
        The policy of the rule.
    """
    if (
        rule == ValidationRule.KNOWN_ARGUMENT_NAMES
        or rule == ValidationRule.NO_UNDEFINED_VARIABLES
        or rule == ValidationRule.NO_UNUSED_FRAGMENTS
        or rule == ValidationRule.NO_UNUSED_VARIABLES
        or rule == ValidationRule.POSSIBLE_FRAGMENT_SPREADS
        or rule == ValidationRule.UNIQUE_FRAGMENT_NAMES
        or rule == ValidationRule.UNIQUE_INPUT_FIELD_NAMES
        or rule == ValidationRule.UNIQUE_OPERATION_NAMES
        or rule == ValidationRule.VALUES_OF_CORRECT_TYPE
    ):
        return LocationPolicy.NONE
    if rule == ValidationRule.VARIABLES_IN_ALLOWED_POSITION:
        return LocationPolicy.FIRST
    if rule == ValidationRule.UNIQUE_DIRECTIVES_PER_LOCATION:
        return LocationPolicy.LAST
    return LocationPolicy.ALL


def _strip_suggestion(message: String) -> String:
    """Return a message without its graphql-js " Did you mean" part."""
    var at = message.find(" Did you mean")
    if at < 0:
        return message
    return String(message[byte=:at])


def _drop_period(message: String) -> String:
    """Return a message without its final period: every caller passes a
    message that ends with one."""
    return String(message[byte = : message.byte_length() - 1])


def _quoted(message: String, start: Int) -> String:
    """Return the text between the quote at `start` and the next quote."""
    var end = message.find('"', start + 1)
    return String(message[byte = start + 1 : end])


def _named(type: String) -> String:
    """Return the named type of a type reference, as `[In!]!` to `In`."""
    return type.replace("[", "").replace("]", "").replace("!", "")


def _values_message(message: String) -> String:
    """Rewrite a graphql-js `ValuesOfCorrectTypeRule` message into the
    `graphql_tools` form."""
    comptime EXPECTED = 'Expected value of type "'
    if message.startswith(EXPECTED):
        if message.endswith("found null."):
            return _drop_period(message)
        var type = _quoted(message, EXPECTED.byte_length() - 1)
        var rest = message.find('", found ')
        return EXPECTED + _named(type) + String(message[byte=rest:])
    var stripped = _strip_suggestion(message)
    if stripped.startswith('Enum "'):
        return _drop_period(stripped)
    comptime scalars: List[StaticString] = [
        "Int",
        "Float",
        "String",
        "Boolean",
        "ID",
    ]
    var names = materialize[scalars]()
    var index = 0
    while index < len(names):
        var scalar = names[index]
        index += 1
        if stripped.startswith(String(scalar) + " cannot represent ") and not (
            stripped.startswith("Int cannot represent non 32-bit")
        ):
            var value = stripped.find("value: ") + 7
            return (
                EXPECTED
                + scalar
                + '", found '
                + String(stripped[byte=value:])
                + "."
            )
    return stripped^


def hive_message(rule: ValidationRule, message: String) -> Optional[String]:
    """Rewrite a graphql-js message into the `graphql_tools` message of
    the rule.

    Args:
        rule: The rule that reported the error.
        message: The graphql-js message.

    Returns:
        The `graphql_tools` message, or None when `graphql_tools` does not
        report the error: a field whose name starts with `__`.
    """
    if rule == ValidationRule.FIELDS_ON_CORRECT_TYPE:
        if message.startswith('Cannot query field "__'):
            return None
        return _strip_suggestion(message)
    if rule == ValidationRule.KNOWN_DIRECTIVES:
        if message.startswith("Unknown directive"):
            return message
        return _drop_period(message)
    if rule == ValidationRule.UNIQUE_DIRECTIVES_PER_LOCATION:
        var name = _quoted(message, 14)
        return 'Duplicate directive "' + String(name[byte=1:]) + '"'
    if rule == ValidationRule.UNIQUE_VARIABLE_NAMES:
        return message.replace("There can be only one", "There can only be one")
    if rule == ValidationRule.VALUES_OF_CORRECT_TYPE:
        return _values_message(message)
    if rule == ValidationRule.SCALAR_LEAFS:
        return message
    return _strip_suggestion(message)


def validation_schema(supergraph: Document) raises -> Schema:
    """Build the schema that operations are validated against, once per
    supergraph, as upstream `planner.consumer_schema`.

    The schema is the supergraph without its `@inaccessible` elements and
    without the federation internals. `gql_schema` adds the introspection
    types itself. The SDL is not checked, because composition checked it.

    Args:
        supergraph: The supergraph.

    Returns:
        The consumer schema, built with `assume_valid`.

    Raises:
        Error: When the supergraph has a type extension, or refers to a
            type that it does not define.
    """
    var documents = List[Document]()
    documents.append(
        StripSchemaInternals.strip_schema_internals(
            PruneInaccessible.prune(supergraph)
        )
    )
    var options = BuildOptions()
    options.assume_valid = True
    return build_ast_schema(documents^, options)


def _options() -> ValidationOptions:
    """Return the options of each check: no error limit, as upstream, and
    no check of the schema, which was built once."""
    var options = ValidationOptions()
    options.max_errors = Int.MAX
    options.assume_valid_schema = True
    return options


def _tagged(
    rule: ValidationRule, error: ValidationError
) -> Optional[GraphQLError]:
    """Return the `graphql_tools` form of an error of a rule, or None when
    `graphql_tools` does not report it."""
    var message = hive_message(rule, error.message)
    if not message:
        return None
    var out = error_with_code(message.value(), rule_error_code(rule))
    var policy = location_policy(rule)
    var first = 0
    var last = len(error.locations)
    if policy == LocationPolicy.NONE:
        last = 0
    elif policy == LocationPolicy.FIRST:
        last = 1
    elif policy == LocationPolicy.LAST:
        first = last - 1
    for index in range(first, last):
        out.lines.append(error.locations[index].line)
        out.columns.append(error.locations[index].column)
    return out^


def validate_operation(
    schema: Schema, document: Document, rules: List[ValidationRule]
) raises -> List[GraphQLError]:
    """Validate a document, as upstream `validate` with a validation plan.

    One walk checks every rule. When it finds errors, each rule runs once
    more by itself, to find the rule of each error. Each error then gets
    the `graphql_tools` message, locations and code of its rule.

    Args:
        schema: The schema of `validation_schema`.
        document: The parsed operation document.
        rules: The rules, such as `default_rules_validation_plan()`.

    Returns:
        The errors in the order of the walk; empty for a valid document.

    Raises:
        Error: When `@skip` or `@include` on a subscription field has a
            missing or invalid `if`, as `gql_validation.validate`.
    """
    var options = _options()
    var found = validate(schema, document, rules, options)
    var out = List[GraphQLError]()
    if len(found) == 0:
        return out^
    var per_rule = List[List[String]]()
    var index = 0
    while index < len(rules):
        var keys = List[String]()
        var errors = validate(schema, document, [rules[index]], options)
        for item in range(len(errors)):
            keys.append(errors[item].to_json())
        per_rule.append(keys^)
        index += 1
    var cursors = List[Int](length=len(rules), fill=0)
    index = 0
    while index < len(found):
        ref error = found[index]
        index += 1
        var key = error.to_json()
        var owner = 0
        # Each error belongs to one rule: when no other rule matches, it is
        # the error of the last rule.
        while owner < len(rules) - 1 and not (
            cursors[owner] < len(per_rule[owner])
            and per_rule[owner][cursors[owner]] == key
        ):
            owner += 1
        cursors[owner] += 1
        var tagged = _tagged(rules[owner], error)
        if tagged:
            out.append(tagged.value().copy())
    return out^


def errors_json(errors: List[GraphQLError]) -> String:
    """Write the body of a failed validation, as upstream
    `FailedExecutionResult`.

    Args:
        errors: The validation errors.

    Returns:
        `{"errors":[...]}`.
    """
    var out = String('{"errors":[')
    for index in range(len(errors)):
        if index > 0:
            out += ","
        out += error_json(errors[index])
    out += "]}"
    return out^
