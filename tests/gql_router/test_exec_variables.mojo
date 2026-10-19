# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the runtime variable coercion: `validate_runtime_value`,
`collect_variables`, the error texts and `CoerceVariablesPayload`.

Port of Hive Router `1a29df9`
`bin/router/src/executor/variables/tests/mod.rs`. Upstream marks no test
`#[ignore]`.

The tests after the `mod.rs` tests are not upstream. They cover the paths
that the upstream suites do not reach: no variable map, a default value of
each kind, the kind types, and the number classes at their bounds.
"""

from _variables_harness import Harness
from gql_json.parser import parse as parse_json
from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_router.ast import NONE, Value, ValueKind
from gql_router.exec_variables import (
    CoerceVariablesPayload,
    InvalidValueReason,
    InvalidValueReasonKind,
    PathSegment,
    PathSegmentKind,
    ValuePath,
    VariableCoercionError,
    VariableCoercionErrorKind,
    collect_variables,
    validate_runtime_value,
)
from gql_router.operation import VariableDefinition
from gql_router.schema_metadata import SchemaMetadata
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _passes(json: String, type_name: String, shape: String) raises -> Bool:
    """Return True if a value passes `validate_runtime_value` with empty
    metadata, as upstream `SchemaMetadata::default()`."""
    var document = parse_json(json)
    try:
        validate_runtime_value(document, 0, type_name, shape, SchemaMetadata())
        return True
    except:
        return False


def test_allow_null_values_for_nullable_scalar_types() raises:
    var scalars = ["String", "Int", "Float", "Boolean", "ID"]
    for index in range(len(scalars)):
        assert_true(_passes("null", String(scalars[index]), "%"))


def test_allow_null_values_for_nullable_list_types() raises:
    assert_true(_passes("null", "String", "[%]"))


def test_allow_matching_non_list_values_for_list_types() raises:
    assert_true(_passes('"not a list"', "String", "[%]"))


def test_disallow_non_matching_non_list_values_for_list_types() raises:
    assert_false(_passes("123", "String", "[%]"))


# --- not upstream: the payload ----------------------------------------


def test_payload_insert_replaces_and_reads_booleans() raises:
    var payload = CoerceVariablesPayload()
    assert_false(payload.is_some)
    payload.document = parse_json('{"t":true,"f":false,"n":1}')
    payload.insert("t", payload.document.first(0))
    payload.insert("n", payload.document.at(0, 2))
    payload.insert("f", payload.document.at(0, 1))
    payload.insert("t", payload.document.at(0, 1))
    assert_true(payload.is_some)
    assert_equal(len(payload.names), 3)
    assert_equal(payload.bool_value("t"), 0)
    assert_equal(payload.bool_value("f"), 0)
    assert_equal(payload.bool_value("n"), -1)
    assert_equal(payload.bool_value("absent"), -1)
    payload.insert("t", payload.document.first(0))
    assert_true(payload.variable_equals_true("t"))
    assert_false(payload.variable_equals_true("f"))
    assert_equal(payload.variable("absent"), NO_NODE)


# --- not upstream: the kinds and the texts ----------------------------


def test_kinds_are_valid_in_range() raises:
    assert_true(VariableCoercionErrorKind.INVALID_DEFAULT_VALUE.is_valid())
    assert_false(VariableCoercionErrorKind(2).is_valid())
    assert_true(InvalidValueReasonKind.UNKNOWN_FIELD.is_valid())
    assert_false(InvalidValueReasonKind(14).is_valid())
    assert_true(PathSegmentKind.FIELD.is_valid())
    assert_false(PathSegmentKind(2).is_valid())


def test_error_texts() raises:
    var segments = List[PathSegment]()
    segments.append(PathSegment.field("a"))
    segments.append(PathSegment.at_index(0))
    segments.append(PathSegment.field("b"))
    assert_equal(String(ValuePath(segments^)), " at .a[0].b")
    assert_equal(String(ValuePath()), "")
    var reason = InvalidValueReason(
        InvalidValueReasonKind.EXPECTED_STRING, "", "1", ""
    )
    var error = VariableCoercionError(
        VariableCoercionErrorKind.INVALID_DEFAULT_VALUE,
        "v",
        ValuePath(),
        reason.copy(),
    )
    assert_equal(
        String(error),
        (
            'Variable "$v" has invalid default value: String cannot represent'
            " a non string value: 1"
        ),
    )
    var document = parse_json("[1]")
    var text = String()
    var same_reason = False
    try:
        validate_runtime_value(document, 0, "String", "[%]", SchemaMetadata())
    except invalid:
        text = String(invalid)
        same_reason = invalid.reason == reason
    assert_equal(text, "String cannot represent a non string value: 1 at [0]")
    assert_true(same_reason)


# --- not upstream: collect_variables ----------------------------------


def test_no_variable_definitions_is_none() raises:
    var h = Harness()
    var outcome = h.coerce("{ int }", '{"v":1}')
    assert_false(outcome.rejected)
    assert_false(outcome.is_some)
    outcome = h.coerce("query ($v: Int) { int(input: $v) }", "{}")
    assert_false(outcome.is_some)
    outcome = h.coerce("query ($v: Int) { int(input: $v) }", '{"v":1}')
    assert_true(outcome.is_some)


def test_no_variable_map_uses_the_defaults() raises:
    var h = Harness()
    var operation = h.planner.normalize(
        "query ($v: Int = 5, $w: Int) { int(input: $v) b: int(input: $w) }"
    )
    var payload = collect_variables(
        h.planner.store, operation, JsonDocument(), NO_NODE, h.metadata
    )
    assert_true(payload.is_some)
    assert_equal(len(payload.names), 1)
    assert_equal(String(payload.document.text(payload.variable("v"))), "5")
    operation = h.planner.normalize("query ($v: Int!) { int(input: $v) }")
    var name = String()
    var is_value_error = False
    try:
        _ = collect_variables(
            h.planner.store, operation, JsonDocument(), NO_NODE, h.metadata
        )
    except error:
        is_value_error = error.kind == VariableCoercionErrorKind.INVALID_VALUE
        name = error.name
    assert_true(is_value_error)
    assert_equal(name, "v")


def test_a_second_definition_of_a_name_does_not_see_the_value() raises:
    # Upstream removes the value from the map, so a second definition of
    # the same name finds no value and takes its default.
    var h = Harness()
    var operation = h.planner.normalize("query ($v: Int) { int(input: $v) }")
    ref store = h.planner.store
    store.values.append(Value(ValueKind.INT, 5, 0.0, NONE, NONE, NONE, NONE))
    var five = len(store.values) - 1
    var first = operation.variables[0].copy()
    operation.variables.append(
        VariableDefinition(first.name, first.variable_type.copy(), five)
    )
    store.values.append(
        Value(ValueKind.VARIABLE, 0, 0.0, first.name, NONE, NONE, NONE)
    )
    var variable = len(store.values) - 1
    operation.variables.append(
        VariableDefinition(store.sym("w"), first.variable_type.copy(), variable)
    )
    var payload = collect_variables(
        store, operation, parse_json('{"v":1}'), 0, h.metadata
    )
    assert_equal(len(payload.names), 2)
    assert_equal(String(payload.document.text(payload.variable("v"))), "5")
    var w = payload.variable("w")
    assert_true(payload.document.kind(w) == JsonKind.NULL)


def test_default_values_of_each_kind() raises:
    var h = Harness()
    h.assert_forwarded(
        "query ($v: Float = 1.5) { float(input: $v) }", "{}", '{"v":1.5}'
    )
    h.assert_forwarded(
        "query ($v: Float = 1e3) { float(input: $v) }", "{}", '{"v":1000.0}'
    )
    h.assert_forwarded(
        "query ($v: Float = 1e400) { float(input: $v) }", "{}", '{"v":null}'
    )
    h.assert_forwarded(
        "query ($v: Boolean = true) { boolean(input: $v) }", "{}", '{"v":true}'
    )
    h.assert_forwarded(
        "query ($v: Boolean = false) { boolean(input: $v) }",
        "{}",
        '{"v":false}',
    )
    h.assert_rejected(
        "query ($v: Int = 1.0) { int(input: $v) }",
        "{}",
        (
            'Variable "$v" has invalid default value: Int cannot represent'
            " non-integer value: 1.0"
        ),
    )


# --- not upstream: numbers and inspect --------------------------------


def test_integers_at_the_bounds() raises:
    var h = Harness()
    var op = "query ($v: Int) { int(input: $v) }"
    h.assert_rejected(
        op,
        '{"v":-9223372036854775808}',
        (
            'Variable "$v" has invalid value: Int cannot represent non 32-bit'
            " signed integer value: -9223372036854775808"
        ),
    )
    h.assert_rejected(
        op,
        '{"v":-9223372036854775809}',
        (
            'Variable "$v" has invalid value: Int cannot represent non-integer'
            " value: -9223372036854776000.0"
        ),
    )
    h.assert_rejected(
        op,
        '{"v":1E3}',
        (
            'Variable "$v" has invalid value: Int cannot represent non-integer'
            " value: 1000.0"
        ),
    )
    var id = "query ($v: ID) { id(input: $v) }"
    h.assert_forwarded(
        id, '{"v":18446744073709551615}', '{"v":18446744073709551615}'
    )
    h.assert_rejected(
        id,
        '{"v":-9223372036854775809}',
        (
            'Variable "$v" has invalid value: ID cannot represent value:'
            " -9223372036854776000.0"
        ),
    )


def test_inspect_limits() raises:
    var h = Harness()
    var op = "query ($v: String) { fieldWithNullableStringInput(input: $v) }"
    h.assert_rejected(
        op,
        '{"v":[[[1]],{"a":{}},[[]],null,true,false]}',
        (
            'Variable "$v" has invalid value: String cannot represent a non'
            " string value: [[[Array]], { a: {} }, [[]], null, true, false]"
        ),
    )
    h.assert_rejected(
        op,
        '{"v":[1,2,3,4,5,6,7,8,9,10,11]}',
        (
            'Variable "$v" has invalid value: String cannot represent a non'
            " string value: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, ... 1 more item]"
        ),
    )
    h.assert_rejected(
        op,
        '{"v":{"a\\n":"\\u0001"}}',
        (
            'Variable "$v" has invalid value: String cannot represent a non'
            ' string value: { a\n: "\\u0001" }'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
