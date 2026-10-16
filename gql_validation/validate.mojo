# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Validate an executable document against a schema.

Port of graphql-js 16.14.2 `validation/validate.ts` (`validate` and
`ValidationOptions`), with the parallel walk of `language/visitor.ts`
`visitInParallel` and `utilities/TypeInfo.ts` `visitWithTypeInfo`.

graphql-js makes one visitor per rule and walks the document once: at each
node, `TypeInfo` enters the node, then each rule in turn sees it. This
module does the same walk. Before the walk it makes a table, for each node
kind, of the rules that handle the kind, in the order of the rule list, so
each node calls only those rules. The errors come in the graphql-js order.

A rule that returns `false` in graphql-js skips the subtree of the node for
that rule. This walk does the same for the two rules where that changes
what the rule sees below the node: `ValuesOfCorrectTypeRule` and
`MaxIntrospectionDepthRule`. `KnownArgumentNamesRule` skips the arguments of
a directive by a check on the parent node.

The walk skips `description` nodes, as graphql-js
`QueryDocumentKeysToValidate`. It also passes `Name` nodes by: no rule and
no `TypeInfo` handles them, and they have no children.

**Differences from graphql-js.**

- graphql-js remembers that a schema is valid on the schema object, and a
  schema built with `assumeValid` is never checked. A Mojo schema is a
  value with no such cache, so `validate` checks the schema on each call.
  Set `ValidationOptions.assume_valid_schema` to skip that check, as
  graphql-js does for a schema it built with `assumeValid` or checked
  before.
- A rule that is in the list more than once runs once.
- `validate` takes no `TypeInfo`: the walk makes its own.
- When `SingleFieldSubscriptionsRule` meets an `@skip` or `@include` with
  a missing or invalid `if`, graphql-js throws a `GraphQLError`; here
  `validate` raises an `Error` with the same message.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.error import GraphQLError
from gql_schema.definition import Schema
from gql_schema.validate import assert_valid_schema
from gql_validation.rules import ValidationRule, specified_rules
from gql_validation.rules_arguments import (
    known_argument_names,
    known_directive_arguments,
    known_directives,
    list_value,
    null_value,
    object_field,
    object_value,
    provided_directive_arguments,
    provided_field_arguments,
    is_valid_value_node,
    unique_argument_names,
    unique_directives_per_location,
    unique_input_field_names,
)
from gql_validation.rules_fields import (
    fields_on_correct_type,
    known_type_names,
    max_introspection_depth,
    no_deprecated_argument,
    no_deprecated_enum_value,
    no_deprecated_field,
    no_deprecated_input_field,
    no_schema_introspection,
    scalar_leafs,
)
from gql_validation.rules_fragments import (
    fragments_on_composite_types,
    known_fragment_names,
    no_fragment_cycles,
    no_unused_fragments,
    possible_fragment_spread,
    possible_inline_fragment,
    unique_fragment_names,
)
from gql_validation.rules_operations import (
    add_variable_definition,
    count_operations,
    define_variable,
    executable_definitions,
    lone_anonymous_operation,
    no_undefined_variables,
    no_unused_variables,
    remember_variable_definition,
    single_field_subscriptions,
    start_operation_variables,
    unique_operation_names,
    unique_variable_names,
    variables_are_input_types,
    variables_in_allowed_position,
)
from gql_validation.state import Walk

comptime _KINDS = 49
"""How many node kinds there are: `Kind.is_valid` holds below this."""


@fieldwise_init
struct ValidationOptions(Copyable, ImplicitlyCopyable, Movable):
    """The options of `validate`: graphql-js `ValidationOptions`."""

    var max_errors: Int
    """How many errors to report before the validation stops, as graphql-js
    `maxErrors`; 100 by default."""
    var assume_valid_schema: Bool
    """Skip the check of the schema, as graphql-js does for a schema that it
    built with `assumeValid` or checked before."""

    def __init__(out self):
        """Return the graphql-js defaults: 100 errors, and a schema check."""
        self.max_errors = 100
        self.assume_valid_schema = False


def _has_directives(kind: Kind) -> Bool:
    """Return True for a node kind that can have directives."""
    var value = Int(kind.value)
    if value >= 24 and value <= 43:
        return kind != Kind.OPERATION_TYPE_DEFINITION
    return (
        kind == Kind.OPERATION_DEFINITION
        or kind == Kind.VARIABLE_DEFINITION
        or kind == Kind.FIELD
        or kind == Kind.FRAGMENT_SPREAD
        or kind == Kind.INLINE_FRAGMENT
        or kind == Kind.FRAGMENT_DEFINITION
    )


def _is_leaf_value(kind: Kind) -> Bool:
    """Return True for an `Enum`, `Int`, `Float`, `String` or `Boolean`
    value."""
    return (
        kind == Kind.ENUM
        or kind == Kind.INT
        or kind == Kind.FLOAT
        or kind == Kind.STRING
        or kind == Kind.BOOLEAN
    )


def _enters(rule: ValidationRule, kind: Kind) -> Bool:
    """Return True if a rule handles entry to a node kind."""
    if rule == ValidationRule.EXECUTABLE_DEFINITIONS:
        return kind == Kind.DOCUMENT
    if (
        rule == ValidationRule.UNIQUE_OPERATION_NAMES
        or rule == ValidationRule.SINGLE_FIELD_SUBSCRIPTIONS
        or rule == ValidationRule.UNIQUE_VARIABLE_NAMES
    ):
        return kind == Kind.OPERATION_DEFINITION
    if rule == ValidationRule.LONE_ANONYMOUS_OPERATION:
        return kind == Kind.DOCUMENT or kind == Kind.OPERATION_DEFINITION
    if rule == ValidationRule.KNOWN_TYPE_NAMES:
        return kind == Kind.NAMED_TYPE
    if rule == ValidationRule.FRAGMENTS_ON_COMPOSITE_TYPES:
        return kind == Kind.INLINE_FRAGMENT or kind == Kind.FRAGMENT_DEFINITION
    if (
        rule == ValidationRule.VARIABLES_ARE_INPUT_TYPES
        or rule == ValidationRule.NO_UNDEFINED_VARIABLES
        or rule == ValidationRule.VARIABLES_IN_ALLOWED_POSITION
    ):
        return kind == Kind.VARIABLE_DEFINITION
    if (
        rule == ValidationRule.SCALAR_LEAFS
        or rule == ValidationRule.FIELDS_ON_CORRECT_TYPE
        or rule == ValidationRule.MAX_INTROSPECTION_DEPTH
        or rule == ValidationRule.NO_SCHEMA_INTROSPECTION_CUSTOM
    ):
        return kind == Kind.FIELD
    if (
        rule == ValidationRule.UNIQUE_FRAGMENT_NAMES
        or rule == ValidationRule.NO_FRAGMENT_CYCLES
    ):
        return kind == Kind.FRAGMENT_DEFINITION
    if rule == ValidationRule.KNOWN_FRAGMENT_NAMES:
        return kind == Kind.FRAGMENT_SPREAD
    if rule == ValidationRule.NO_UNUSED_FRAGMENTS:
        return (
            kind == Kind.OPERATION_DEFINITION
            or kind == Kind.FRAGMENT_DEFINITION
        )
    if rule == ValidationRule.POSSIBLE_FRAGMENT_SPREADS:
        return kind == Kind.INLINE_FRAGMENT or kind == Kind.FRAGMENT_SPREAD
    if rule == ValidationRule.NO_UNUSED_VARIABLES:
        return (
            kind == Kind.OPERATION_DEFINITION
            or kind == Kind.VARIABLE_DEFINITION
        )
    if rule == ValidationRule.KNOWN_DIRECTIVES:
        return kind == Kind.DIRECTIVE
    if rule == ValidationRule.UNIQUE_DIRECTIVES_PER_LOCATION:
        return _has_directives(kind)
    if rule == ValidationRule.KNOWN_ARGUMENT_NAMES:
        return kind == Kind.DIRECTIVE or kind == Kind.ARGUMENT
    if rule == ValidationRule.UNIQUE_ARGUMENT_NAMES:
        return kind == Kind.FIELD or kind == Kind.DIRECTIVE
    if rule == ValidationRule.VALUES_OF_CORRECT_TYPE:
        return (
            kind == Kind.LIST
            or kind == Kind.OBJECT
            or kind == Kind.OBJECT_FIELD
            or kind == Kind.NULL
            or _is_leaf_value(kind)
        )
    if rule == ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED:
        return kind == Kind.SELECTION_SET
    if rule == ValidationRule.UNIQUE_INPUT_FIELD_NAMES:
        return kind == Kind.OBJECT_FIELD
    if rule == ValidationRule.NO_DEPRECATED_CUSTOM:
        return (
            kind == Kind.FIELD
            or kind == Kind.ARGUMENT
            or kind == Kind.OBJECT_FIELD
            or kind == Kind.ENUM
        )
    # PROVIDED_REQUIRED_ARGUMENTS handles only exits.
    return False


def _leaves(rule: ValidationRule, kind: Kind) -> Bool:
    """Return True if a rule handles exit from a node kind."""
    if rule == ValidationRule.NO_UNUSED_FRAGMENTS:
        return kind == Kind.DOCUMENT
    if (
        rule == ValidationRule.NO_UNDEFINED_VARIABLES
        or rule == ValidationRule.NO_UNUSED_VARIABLES
        or rule == ValidationRule.VARIABLES_IN_ALLOWED_POSITION
    ):
        return kind == Kind.OPERATION_DEFINITION
    if rule == ValidationRule.PROVIDED_REQUIRED_ARGUMENTS:
        return kind == Kind.FIELD or kind == Kind.DIRECTIVE
    return False


struct _Table(Movable):
    """For each node kind, the rules that handle it, in rule order."""

    var rules: List[UInt8]
    var starts: List[Int]

    def __init__(out self, active: List[ValidationRule], leave: Bool):
        self.rules = List[UInt8]()
        self.starts = List[Int](capacity=_KINDS + 1)
        var value = 0
        while value < _KINDS:
            self.starts.append(len(self.rules))
            var kind = Kind(UInt8(value))
            for rule in active:
                var handles = _leaves(rule, kind) if leave else _enters(
                    rule, kind
                )
                if handles:
                    self.rules.append(rule.value)
            value += 1
        self.starts.append(len(self.rules))


def _enter(
    mut walk: Walk,
    schema: Schema,
    document: Document,
    node: Int,
    kind: Kind,
    rule: ValidationRule,
) raises -> Bool:
    """Call one rule on entry to a node.

    Returns:
        True when the rule skips the node's subtree.
    """
    if rule == ValidationRule.VALUES_OF_CORRECT_TYPE:
        if kind == Kind.LIST:
            return list_value(walk, schema, document, node)
        if kind == Kind.OBJECT:
            return object_value(walk, schema, document, node)
        if kind == Kind.OBJECT_FIELD:
            object_field(walk, schema, document, node)
        elif kind == Kind.NULL:
            null_value(walk, schema, document, node)
        else:
            is_valid_value_node(walk, schema, document, node)
    elif rule == ValidationRule.UNIQUE_DIRECTIVES_PER_LOCATION:
        unique_directives_per_location(walk, schema, document, node)
    elif rule == ValidationRule.SCALAR_LEAFS:
        scalar_leafs(walk, schema, document, node)
    elif rule == ValidationRule.FIELDS_ON_CORRECT_TYPE:
        fields_on_correct_type(walk, schema, document, node)
    elif rule == ValidationRule.OVERLAPPING_FIELDS_CAN_BE_MERGED:
        walk.overlap.check(walk.ctx, schema, document, node)
    elif rule == ValidationRule.UNIQUE_ARGUMENT_NAMES:
        unique_argument_names(walk, document, node)
    elif rule == ValidationRule.KNOWN_ARGUMENT_NAMES:
        if kind == Kind.DIRECTIVE:
            known_directive_arguments(walk, schema, document, node)
        else:
            known_argument_names(walk, schema, document, node)
    elif rule == ValidationRule.MAX_INTROSPECTION_DEPTH:
        return max_introspection_depth(walk, document, node)
    elif rule == ValidationRule.KNOWN_DIRECTIVES:
        known_directives(walk, schema, document, node)
    elif rule == ValidationRule.UNIQUE_INPUT_FIELD_NAMES:
        unique_input_field_names(walk, document, node)
    elif rule == ValidationRule.KNOWN_TYPE_NAMES:
        known_type_names(walk, schema, document, node)
    elif rule == ValidationRule.KNOWN_FRAGMENT_NAMES:
        known_fragment_names(walk, document, node)
    elif rule == ValidationRule.POSSIBLE_FRAGMENT_SPREADS:
        if kind == Kind.INLINE_FRAGMENT:
            possible_inline_fragment(walk, schema, document, node)
        else:
            possible_fragment_spread(walk, schema, document, node)
    elif rule == ValidationRule.FRAGMENTS_ON_COMPOSITE_TYPES:
        fragments_on_composite_types(walk, schema, document, node)
    elif rule == ValidationRule.EXECUTABLE_DEFINITIONS:
        executable_definitions(walk, document)
    elif rule == ValidationRule.UNIQUE_OPERATION_NAMES:
        unique_operation_names(walk, document, node)
    elif rule == ValidationRule.LONE_ANONYMOUS_OPERATION:
        if kind == Kind.DOCUMENT:
            count_operations(walk, document)
        else:
            lone_anonymous_operation(walk, document, node)
    elif rule == ValidationRule.SINGLE_FIELD_SUBSCRIPTIONS:
        single_field_subscriptions(walk, schema, document, node)
    elif rule == ValidationRule.VARIABLES_ARE_INPUT_TYPES:
        variables_are_input_types(walk, schema, document, node)
    elif rule == ValidationRule.UNIQUE_FRAGMENT_NAMES:
        unique_fragment_names(walk, document, node)
    elif rule == ValidationRule.NO_UNUSED_FRAGMENTS:
        if kind == Kind.OPERATION_DEFINITION:
            walk.operation_defs.append(node)
        else:
            walk.fragment_defs.append(node)
    elif rule == ValidationRule.NO_FRAGMENT_CYCLES:
        no_fragment_cycles(walk, document, node)
    elif rule == ValidationRule.UNIQUE_VARIABLE_NAMES:
        unique_variable_names(walk, document, node)
    elif rule == ValidationRule.NO_UNDEFINED_VARIABLES:
        define_variable(walk, document, node)
    elif rule == ValidationRule.NO_UNUSED_VARIABLES:
        if kind == Kind.OPERATION_DEFINITION:
            start_operation_variables(walk)
        else:
            add_variable_definition(walk, node)
    elif rule == ValidationRule.VARIABLES_IN_ALLOWED_POSITION:
        remember_variable_definition(walk, document, node)
    elif rule == ValidationRule.NO_DEPRECATED_CUSTOM:
        if kind == Kind.FIELD:
            no_deprecated_field(walk, schema, document, node)
        elif kind == Kind.ARGUMENT:
            no_deprecated_argument(walk, schema, document, node)
        elif kind == Kind.OBJECT_FIELD:
            no_deprecated_input_field(walk, schema, document, node)
        else:
            no_deprecated_enum_value(walk, schema, document, node)
    else:
        no_schema_introspection(walk, schema, document, node)
    return False


def _leave(
    mut walk: Walk,
    schema: Schema,
    document: Document,
    node: Int,
    kind: Kind,
    rule: ValidationRule,
) raises:
    """Call one rule on exit from a node."""
    if rule == ValidationRule.PROVIDED_REQUIRED_ARGUMENTS:
        if kind == Kind.FIELD:
            provided_field_arguments(walk, schema, document, node)
        else:
            provided_directive_arguments(walk, schema, document, node)
    elif rule == ValidationRule.NO_UNUSED_FRAGMENTS:
        no_unused_fragments(walk, document)
    elif rule == ValidationRule.NO_UNDEFINED_VARIABLES:
        no_undefined_variables(walk, schema, document, node)
    elif rule == ValidationRule.NO_UNUSED_VARIABLES:
        no_unused_variables(walk, schema, document, node)
    else:
        variables_in_allowed_position(walk, schema, document, node)


struct _Runner(Movable):
    """The rule tables of one validation, and which rules skip a
    subtree."""

    var enters: _Table
    var leaves: _Table
    var skipping: List[Int]
    var skip_count: Int
    var records: Bool

    def __init__(out self, rules: List[ValidationRule]):
        var active = List[ValidationRule]()
        var seen = List[Bool](length=ValidationRule.COUNT, fill=False)
        for rule in rules:
            if rule.is_valid() and not seen[Int(rule.value)]:
                seen[Int(rule.value)] = True
                active.append(rule)
        self.enters = _Table(active, False)
        self.leaves = _Table(active, True)
        self.skipping = List[Int](length=ValidationRule.COUNT, fill=-1)
        self.skip_count = 0
        self.records = (
            seen[Int(ValidationRule.NO_UNDEFINED_VARIABLES.value)]
            or seen[Int(ValidationRule.NO_UNUSED_VARIABLES.value)]
            or seen[Int(ValidationRule.VARIABLES_IN_ALLOWED_POSITION.value)]
        )

    @always_inline
    def enter(
        mut self,
        mut walk: Walk,
        schema: Schema,
        document: Document,
        node: Int,
    ) raises:
        """Enter a node: `TypeInfo` first, then each rule."""
        var kind = document.kind(node)
        walk.ctx.type_info.enter(schema, document, node)
        if self.records:
            if kind == Kind.VARIABLE_DEFINITION:
                walk.in_variable_definition += 1
            elif kind == Kind.VARIABLE:
                if walk.in_variable_definition == 0:
                    walk.ctx.record_usage(node)
            elif (
                kind == Kind.OPERATION_DEFINITION
                or kind == Kind.FRAGMENT_DEFINITION
            ):
                walk.ctx.start_recording(document, node)
        var value = Int(kind.value)
        var starts = self.enters.starts.unsafe_ptr()
        var index = starts[unsafe_offset=value]
        var end = starts[unsafe_offset=value + 1]
        while index < end:
            var rule = Int(self.enters.rules.unsafe_ptr()[unsafe_offset=index])
            index += 1
            if self.skip_count > 0 and self.skipping[rule] >= 0:
                continue
            if _enter(
                walk, schema, document, node, kind, ValidationRule(UInt8(rule))
            ):
                self.skipping[rule] = node
                self.skip_count += 1
            if walk.ctx.aborted:
                return

    @always_inline
    def leave(
        mut self,
        mut walk: Walk,
        schema: Schema,
        document: Document,
        node: Int,
    ) raises:
        """Leave a node: the usage record, each rule, then `TypeInfo`."""
        var kind = document.kind(node)
        if self.skip_count > 0:
            var rule = 0
            while rule < ValidationRule.COUNT:
                if self.skipping[rule] == node:
                    self.skipping[rule] = -1
                    self.skip_count -= 1
                rule += 1
        # The usages of a definition are complete before its rules leave it.
        if self.records:
            if kind == Kind.VARIABLE_DEFINITION:
                walk.in_variable_definition -= 1
            elif (
                kind == Kind.OPERATION_DEFINITION
                or kind == Kind.FRAGMENT_DEFINITION
            ):
                walk.ctx.stop_recording()
        var value = Int(kind.value)
        var starts = self.leaves.starts.unsafe_ptr()
        var index = starts[unsafe_offset=value]
        var end = starts[unsafe_offset=value + 1]
        while index < end:
            var rule = Int(self.leaves.rules.unsafe_ptr()[unsafe_offset=index])
            index += 1
            # No rule that skips a subtree has an exit handler, so no exit
            # handler is ever skipped.
            _leave(
                walk, schema, document, node, kind, ValidationRule(UInt8(rule))
            )
            if walk.ctx.aborted:
                return
        walk.ctx.type_info.leave(document, node)


def validate(schema: Schema, document: Document) raises -> List[GraphQLError]:
    """Validate a document with every specified rule, as graphql-js
    `validate(schema, documentAST)`.

    Args:
        schema: The schema to check against.
        document: The executable document.

    Returns:
        The errors, in the graphql-js order; empty for a valid document.

    Raises:
        Error: When the schema is not valid, with the messages of
            `assert_valid_schema`.
    """
    return validate(schema, document, specified_rules(), ValidationOptions())


def validate(
    schema: Schema, document: Document, rules: List[ValidationRule]
) raises -> List[GraphQLError]:
    """Validate a document with some rules, as graphql-js
    `validate(schema, documentAST, rules)`.

    Args:
        schema: The schema to check against.
        document: The executable document.
        rules: The rules, such as `specified_rules()`.

    Returns:
        The errors, in the graphql-js order; empty for a valid document.

    Raises:
        Error: When the schema is not valid, with the messages of
            `assert_valid_schema`.
    """
    return validate(schema, document, rules, ValidationOptions())


def validate(
    schema: Schema,
    document: Document,
    rules: List[ValidationRule],
    options: ValidationOptions,
) raises -> List[GraphQLError]:
    """Validate a document, as graphql-js `validate(schema, documentAST,
    rules, options)`.

    At `options.max_errors` errors, the next error is replaced by `Too many
    validation errors, error limit reached. Validation aborted.`, and the
    walk stops.

    Args:
        schema: The schema to check against.
        document: The executable document.
        rules: The rules, such as `specified_rules()`.
        options: The error limit and the schema check.

    Returns:
        The errors, in the graphql-js order; empty for a valid document.

    Raises:
        Error: When the schema is not valid, with the messages of
            `assert_valid_schema`; or when `@skip` or `@include` on a
            subscription field has a missing or invalid `if`.
    """
    if not options.assume_valid_schema:
        assert_valid_schema(schema)
    var walk = Walk(schema, options.max_errors)
    var runner = _Runner(rules)
    walk.find_definitions(document)
    walk.ctx.path.append(document.root)
    runner.enter(walk, schema, document, document.root)
    var current = document.first_child(document.root)
    while len(walk.ctx.path) > 0 and not walk.ctx.aborted:
        if current != NO_NODE:
            # No rule and no `TypeInfo` handles a `Name`, which has no
            # children, so the walk passes it by.
            if (
                document.kind(current) == Kind.NAME
                or document.role(current) == Role.DESCRIPTION
            ):
                current = document.next_sibling(current)
                continue
            walk.ctx.path.append(current)
            runner.enter(walk, schema, document, current)
            current = document.first_child(current)
        else:
            var done = walk.ctx.path[len(walk.ctx.path) - 1]
            runner.leave(walk, schema, document, done)
            _ = walk.ctx.path.pop()
            current = document.next_sibling(done)
    return walk^.take_errors()
