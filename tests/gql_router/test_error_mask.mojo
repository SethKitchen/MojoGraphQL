# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for masking a subgraph error.

The cases follow `ErrorMaskingRuntime::apply` in Hive Router.
"""

from gql_router.error_mask import (
    ExtensionPlan,
    MaskPlanKind,
    MaskedError,
    MessageMask,
    mask_error,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _error(
    message: String,
    code: String,
    service: String,
    path: String,
    var names: List[String],
    var values: List[String],
) -> MaskedError:
    return MaskedError(message, code, service, path, names^, values^)


def _pair(
    name: String,
    value: String,
    mut names: List[String],
    mut values: List[String],
):
    names.append(name)
    values.append(value)


def test_an_error_with_no_service_is_unchanged() raises:
    var names = List[String]()
    var values = List[String]()
    _pair("trace", "1", names, values)
    var masked = mask_error(
        _error("secret", "BAD", "", "a", names^, values^),
        "redacted",
        True,
        List[MessageMask](),
        MaskPlanKind.DENY,
        List[String](),
        List[ExtensionPlan](),
    )
    assert_equal(masked.message, "secret")
    assert_equal(masked.code, "BAD")
    assert_equal(masked.extra_names[0], "trace")


def test_a_subgraph_rule_replaces_the_default_message() raises:
    var masks = List[MessageMask]()
    masks.append(MessageMask("books", False))
    var kept = mask_error(
        _error("secret", "", "books", "", List[String](), List[String]()),
        "redacted",
        True,
        masks,
        MaskPlanKind.NONE,
        List[String](),
        List[ExtensionPlan](),
    )
    assert_equal(kept.message, "secret")
    var masked = mask_error(
        _error("secret", "", "users", "", List[String](), List[String]()),
        "redacted",
        True,
        List[MessageMask](),
        MaskPlanKind.NONE,
        List[String](),
        List[ExtensionPlan](),
    )
    assert_equal(masked.message, "redacted")


def test_a_deny_list_removes_named_keys_and_keeps_the_rest() raises:
    var names = List[String]()
    var values = List[String]()
    _pair("trace", "1", names, values)
    _pair("debug", "2", names, values)
    var keys = List[String]()
    keys.append("code")
    keys.append("debug")
    var masked = mask_error(
        _error("secret", "BAD", "books", "a.b", names^, values^),
        "redacted",
        True,
        List[MessageMask](),
        MaskPlanKind.DENY,
        keys^,
        List[ExtensionPlan](),
    )
    assert_equal(masked.message, "redacted")
    assert_equal(masked.code, "")
    assert_equal(masked.service, "books")
    assert_equal(masked.affected_path, "a.b")
    assert_equal(len(masked.extra_names), 1)
    assert_equal(masked.extra_names[0], "trace")
    assert_equal(masked.extra_values[0], "1")


def test_an_allow_list_keeps_only_the_named_keys() raises:
    var names = List[String]()
    var values = List[String]()
    _pair("trace", "1", names, values)
    _pair("debug", "2", names, values)
    _pair("code", "nope", names, values)
    var keys = List[String]()
    keys.append("service")
    keys.append("trace")
    var masked = mask_error(
        _error("secret", "BAD", "books", "a.b", names^, values^),
        "redacted",
        False,
        List[MessageMask](),
        MaskPlanKind.ALLOW,
        keys^,
        List[ExtensionPlan](),
    )
    assert_equal(masked.message, "secret")
    assert_equal(masked.code, "")
    assert_equal(masked.service, "books")
    assert_equal(masked.affected_path, "")
    assert_equal(len(masked.extra_names), 1)
    assert_equal(masked.extra_names[0], "trace")
    assert_equal(masked.extra_values[0], "1")


def test_a_subgraph_extension_plan_overrides_the_default() raises:
    var plans = List[ExtensionPlan]()
    var keys = List[String]()
    keys.append("affectedPath")
    plans.append(ExtensionPlan("books", MaskPlanKind.ALLOW, keys^))
    var deny = List[String]()
    deny.append("code")
    deny.append("affectedPath")
    var masked = mask_error(
        _error("secret", "BAD", "books", "a.b", List[String](), List[String]()),
        "redacted",
        False,
        List[MessageMask](),
        MaskPlanKind.DENY,
        deny^,
        plans^,
    )
    assert_equal(masked.code, "")
    assert_equal(masked.service, "")
    assert_equal(masked.affected_path, "a.b")
    assert_true(MaskPlanKind.ALLOW.is_valid())
    assert_true(MaskPlanKind.DENY.is_valid())
    assert_true(MaskPlanKind.NONE.is_valid())
    assert_false(MaskPlanKind(3).is_valid())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
