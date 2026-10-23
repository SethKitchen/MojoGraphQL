# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/inline_arguments_test.go`.

`TestInlineArgumentsRule_FindingOwnsItsBytes` is not ported: a Mojo
`String` owns its bytes. The tests after `test_option_off_returns_none`
are not from upstream; their expectations were checked against the
walker of upstream.
"""

from _norm import schema_of
from gql_language.ast import Kind
from gql_language.parser import parse
from gql_normalization.inline_arguments import (
    InlineArgumentsValidationOptions,
    NormalizationResult,
    RunOptions,
    find_inline_arguments,
)
from gql_normalization.normalize import NormalizerOptions, OperationNormalizer
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime SCHEMA = """
	schema { query: Query }
	type Query {
		userById(userId: ID!): User
		user: User
		field(order: Sort, flag: Boolean, by: [Int], obj: Filter): String
	}
	type User {
		loginName: String
		posts(first: Int): String
	}
	enum Sort { ASC DESC }
	input Filter { a: Int }
"""
"""Upstream `inlineArgumentsTestSchema`."""


def log_only() -> InlineArgumentsValidationOptions:
    """Return `InlineArgumentsValidationOptions{Enforce: false}`.

    Returns:
        The options.
    """
    return InlineArgumentsValidationOptions(False, "", "", 0)


def run_rule(
    operation: StringSlice,
    options: InlineArgumentsValidationOptions,
    run_options: RunOptions = RunOptions(),
    variables: StringSlice = "",
) raises -> NormalizationResult:
    """Normalize with `WithInlineArgumentsValidation`: upstream
    `runInlineArgumentsRuleWithRunOpts`.

    Args:
        operation: The operation.
        options: The validation options.
        run_options: The options of the run.
        variables: The variables JSON.

    Returns:
        The result.

    Raises:
        Error: The error of the normalization.
    """
    var schema = schema_of(SCHEMA)
    var document = parse(operation)
    var normalizer_options = NormalizerOptions()
    normalizer_options.inline_arguments_validation = options
    var values = String(variables)
    var result = OperationNormalizer(
        normalizer_options
    ).normalize_named_operation_with_result(
        document, schema, "", values, run_options
    )
    assert_true(Bool(result))
    return result.take()


def found(operation: StringSlice) raises -> String:
    """Return each finding as `argument ancestor kind value`, one per line.

    Args:
        operation: The operation.

    Returns:
        The findings.

    Raises:
        Error: The error of the normalization.
    """
    var result = run_rule(operation, log_only())
    var out = String()
    for ref item in result.inline_arguments:
        out += item.argument_name + " " + item.ancestor_name + " "
        out += String(item.ancestor_kind) + " " + String(item.value_kind) + "\n"
    return out^


def qualified(
    operation: StringSlice, variables: StringSlice = ""
) raises -> String:
    """Return the qualified names of the findings, one per line.

    Args:
        operation: The operation.
        variables: The variables JSON.

    Returns:
        The names.

    Raises:
        Error: The error of the normalization.
    """
    var result = run_rule(operation, log_only(), RunOptions(), variables)
    var out = String()
    for ref item in result.inline_arguments:
        out += item.qualified_name() + "\n"
    return out^


def test_detection_inline_string_field_argument() raises:
    assert_equal(
        found('query GetUserById { userById(userId: "12345") { loginName } }'),
        "userId userById Field StringValue\n",
    )


def test_detection_variable_field_argument_is_compliant() raises:
    assert_equal(
        found(
            "query GetUserById($userId: ID!) { userById(userId: $userId) {"
            " loginName } }"
        ),
        "",
    )


def test_detection_inline_enum_argument() raises:
    assert_equal(
        found("query { field(order: ASC) }"), "order field Field EnumValue\n"
    )


def test_detection_inline_null_argument() raises:
    assert_equal(
        found("query { field(flag: null) }"), "flag field Field NullValue\n"
    )


def test_detection_inline_list_argument_recorded_once() raises:
    assert_equal(
        found("query { field(by: [1, 2, 3]) }"), "by field Field ListValue\n"
    )


def test_detection_inline_object_argument_recorded_once() raises:
    assert_equal(
        found("query { field(obj: { a: 1 }) }"), "obj field Field ObjectValue\n"
    )


def test_detection_mixed_variable_and_literal_flags_only_the_literal() raises:
    assert_equal(
        found("query q($flag: Boolean) { field(flag: $flag, order: DESC) }"),
        "order field Field EnumValue\n",
    )


def test_detection_inline_directive_argument_include() raises:
    assert_equal(
        found(
            "query q($userId: ID!) { userById(userId: $userId) @include(if:"
            " true) { loginName } }"
        ),
        "if include Directive BooleanValue\n",
    )


def test_detection_variable_directive_argument_is_compliant() raises:
    assert_equal(
        found(
            "query q($userId: ID!, $show: Boolean!) { userById(userId: $userId)"
            " @include(if: $show) { loginName } }"
        ),
        "",
    )


def test_detection_introspection_field_argument() raises:
    assert_equal(
        found('query { __type(name: "User") { name } }'),
        "name __type Field StringValue\n",
    )


def test_detection_argument_under_a_skip_removed_node_still_flagged() raises:
    assert_equal(
        found(
            "query q($userId: ID!) { user @skip(if: true) { posts(first: 10) }"
            " userById(userId: $userId) { loginName } }"
        ),
        "if skip Directive BooleanValue\nfirst posts Field IntValue\n",
    )


def test_detection_no_inline_arguments() raises:
    assert_equal(
        found(
            "query q($userId: ID!) { userById(userId: $userId) { loginName } }"
        ),
        "",
    )


def test_qualified_name_top_level_field_argument() raises:
    assert_equal(
        qualified('query { userById(userId: "12345") { loginName } }'),
        "query.userById#userId\n",
    )


def test_qualified_name_nested_field_argument_carries_the_query_path() raises:
    assert_equal(
        qualified('query { userById(userId: "12345") { posts(first: 10) } }'),
        "query.userById#userId\nquery.userById.posts#first\n",
    )


def test_qualified_name_field_alias_is_used_in_the_path() raises:
    assert_equal(
        qualified(
            'query { u: userById(userId: "12345") { p: posts(first: 10) } }'
        ),
        "query.u#userId\nquery.u.p#first\n",
    )


def test_qualified_name_directive_argument_names_field_and_directive() raises:
    assert_equal(
        qualified(
            'query { userById(userId: "x") @include(if: true) { loginName } }'
        ),
        "query.userById#userId\nquery.userById@include#if\n",
    )


def test_position() raises:
    var result = run_rule(
        'query GetUserById { userById(userId: "12345") { loginName } }',
        log_only(),
    )
    assert_equal(len(result.inline_arguments), 1)
    assert_equal(result.inline_arguments[0].position.line, 1)
    assert_equal(result.inline_arguments[0].position.column, 30)


def test_enforce_stops_at_the_first_inline_argument() raises:
    var options = InlineArgumentsValidationOptions(
        True,
        "Inline argument values are not allowed. Use variables instead.",
        "INLINE_ARGUMENT_VALUES_NOT_ALLOWED",
        400,
    )
    try:
        _ = run_rule(
            (
                'query { userById(userId: "12345") { loginName } field(order:'
                " ASC) }"
            ),
            options,
        )
    except error:
        assert_equal(
            String(error),
            "Inline argument values are not allowed. Use variables instead.",
        )
        return
    assert_true(False, "enforce should raise")


def test_enforce_compliant_operation_passes() raises:
    var result = run_rule(
        "query q($userId: ID!) { userById(userId: $userId) { loginName } }",
        InlineArgumentsValidationOptions(True, "nope", "CODE", 400),
    )
    assert_equal(len(result.inline_arguments), 0)


def test_enforce_skip_inline_arguments_records_nothing() raises:
    var result = run_rule(
        'query { userById(userId: "12345") { loginName } }',
        InlineArgumentsValidationOptions(True, "x", "C", 400),
        RunOptions(True),
    )
    assert_equal(len(result.inline_arguments), 0)


def test_option_off_returns_none() raises:
    var schema = schema_of(SCHEMA)
    var document = parse('query { userById(userId: "12345") { loginName } }')
    var values = String()
    var result = OperationNormalizer(
        NormalizerOptions()
    ).normalize_named_operation_with_result(
        document, schema, "", values, RunOptions()
    )
    assert_false(Bool(result))


def test_walk_restarts_a_changed_selection_set() raises:
    # The walker starts the set again after it removes `user`, so `field`
    # is walked twice.
    assert_equal(
        qualified("{ field(order: ASC) user @skip(if: true) { loginName } }"),
        "query.field#order\nquery.user@skip#if\nquery.field#order\n",
    )


def test_walk_skips_the_directive_after_a_removed_one() raises:
    # `@include(if: true)` goes, so the range reads `@c` twice and not `@b`.
    assert_equal(
        qualified(
            (
                "query ($v: Boolean) { field @include(if: true) @b(x: 1) @c(y:"
                " 2) user @include(if: $v) { loginName } }"
            ),
            '{"v":true}',
        ),
        "query.field@include#if\nquery.field@c#y\nquery.field@c#y\n",
    )


def test_walk_paths_of_definitions() raises:
    var document = parse(
        "query Q($v: Int @d(b: 1)) @d(a: 2) { ... on Query { ... on Query {"
        " field(flag: true) } } } fragment F on User { posts(first: 1) }"
        ' mutation M @d(a: "x") { field } subscription S { f(a: 1) }'
    )
    var result = NormalizationResult()
    find_inline_arguments(document, "", False, log_only(), result)
    var names = String()
    for ref item in result.inline_arguments:
        names += item.qualified_name() + "\n"
    assert_equal(
        names,
        "query@d#b\nquery@d#a\nquery.$1Query.$0Query.field#flag\n"
        + "User.posts#first\nmutation@d#a\nsubscription.f#a\n",
    )


def test_walk_spreads_and_untyped_inline_fragments() raises:
    # A spread and an inline fragment without a type condition add nothing
    # to the path. A type system definition is not walked.
    assert_equal(
        qualified(
            "{ ...F @d(a: 1) ... @d(b: 2) { field(flag: true) } } fragment F on"
            " Query { field } scalar S"
        ),
        "query@d#a\nquery@d#b\nquery.field#flag\n",
    )


def test_walk_removes_a_node_or_directive_that_is_gone() raises:
    # The second directive removes `user` again; it is gone already.
    assert_equal(
        qualified(
            "{ field user @skip(if: true) @include(if: false) { loginName } }"
        ),
        "query.user@skip#if\nquery.user@include#if\n",
    )
    # The range reads the second `@include` twice; the second read removes
    # nothing.
    assert_equal(
        qualified("{ field @include(if: true) @b(x: 1) @include(if: true) }"),
        "query.field@include#if\nquery.field@include#if\n"
        + "query.field@include#if\n",
    )
    assert_equal(
        qualified("{ field @e(z: 1) @include(if: true) }"),
        "query.field@e#z\nquery.field@include#if\n",
    )


def test_walk_include_and_skip_on_definitions() raises:
    # Upstream removes neither a directive nor a node of a definition.
    assert_equal(
        qualified(
            "query Q($v: Int @skip(if: true) @include(if: true)) @include(if:"
            " false) @skip(if: false) { field(flag: true) }"
        ),
        "query@skip#if\nquery@include#if\nquery@include#if\nquery@skip#if\n"
        + "query.field#flag\n",
    )


def test_walk_restarts_a_set_with_a_walked_child_set() raises:
    assert_equal(
        qualified("{ user { posts(first: 1) } field @skip(if: true) }"),
        "query.user.posts#first\nquery.field@skip#if\n"
        + "query.user.posts#first\n",
    )


def test_walk_keeps_nodes_and_adds_placeholders() raises:
    var schema = schema_of(SCHEMA)
    var document = parse(
        "{ user { loginName @skip(if: true) } field @skip(if: false) @e(z: 3) }"
    )
    var options = NormalizerOptions()
    options.inline_arguments_validation = log_only()
    var values = String()
    var result = OperationNormalizer(
        options.copy()
    ).normalize_named_operation_with_result(
        document, schema, "", values, RunOptions()
    )
    var names = String()
    for ref item in result.value().inline_arguments:
        names += item.qualified_name() + "\n"
    assert_equal(
        names,
        "query.user.loginName@skip#if\nquery.field@skip#if\nquery.field@e#z\n",
    )
    options.ignore_skip_include = True
    var kept = parse("{ user @skip(if: true) { loginName } }")
    result = OperationNormalizer(options).normalize_named_operation_with_result(
        kept, schema, "", values, RunOptions()
    )
    assert_equal(len(result.value().inline_arguments), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
