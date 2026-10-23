# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for filtering unauthorized fields.

The cases follow `apply_authorization_to_operation` in Hive Router
`pipeline/authorization/mod.rs`.
"""

from gql_router.auth_filter import AuthField, authorize_fields
from std.testing import TestSuite, assert_equal


def _field(parent: String, name: String, output: String) -> AuthField:
    return AuthField(parent, name, output)


def _joined(names: List[String]) -> String:
    var text = String("")
    for index in range(len(names)):
        if index > 0:
            text += " "
        text += names[index]
    return text


def test_an_authenticated_request_skips_authenticated_only_rules() raises:
    var fields = List[AuthField]()
    fields.append(_field("Query", "secret", "String"))
    var denied_types = List[String]()
    denied_types.append("Secret")
    var decision = authorize_fields(
        False,
        True,
        False,
        False,
        True,
        fields,
        denied_types,
        List[String](),
        List[String](),
        List[String](),
    )
    assert_equal(decision.kind, 0)


def test_a_denied_field_is_removed_or_rejects_the_operation() raises:
    var fields = List[AuthField]()
    fields.append(_field("Query", "viewer", "User"))
    fields.append(_field("Query", "secret", "String"))
    var denied_types = List[String]()
    var denied_parents = List[String]()
    denied_parents.append("Query")
    var denied_names = List[String]()
    denied_names.append("secret")
    var filtered = authorize_fields(
        False,
        False,
        True,
        False,
        False,
        fields,
        denied_types,
        denied_parents,
        denied_names,
        List[String](),
    )
    assert_equal(filtered.kind, 1)
    assert_equal(_joined(filtered.kept), "viewer")
    var again = List[AuthField]()
    again.append(_field("Query", "viewer", "User"))
    again.append(_field("Query", "secret", "String"))
    var parents = List[String]()
    parents.append("Query")
    var names = List[String]()
    names.append("secret")
    var rejected = authorize_fields(
        False,
        False,
        True,
        False,
        True,
        again,
        List[String](),
        parents,
        names,
        List[String](),
    )
    assert_equal(rejected.kind, 2)
    assert_equal(len(rejected.kept), 0)


def test_a_parent_without_auth_keeps_its_fields() raises:
    var fields = List[AuthField]()
    fields.append(_field("Query", "secret", "Secret"))
    var denied_types = List[String]()
    denied_types.append("Secret")
    var parents = List[String]()
    parents.append("Query")
    var decision = authorize_fields(
        False,
        False,
        True,
        True,
        False,
        fields,
        denied_types,
        List[String](),
        List[String](),
        parents,
    )
    assert_equal(decision.kind, 0)


def test_a_schema_without_rules_changes_nothing() raises:
    var fields = List[AuthField]()
    fields.append(_field("Query", "secret", "Secret"))
    var denied_types = List[String]()
    denied_types.append("Secret")
    var decision = authorize_fields(
        True,
        False,
        True,
        True,
        True,
        fields,
        denied_types,
        List[String](),
        List[String](),
        List[String](),
    )
    assert_equal(decision.kind, 0)
    assert_equal(len(decision.kept), 0)


def test_scopes_or_policies_check_an_authenticated_request() raises:
    # Scopes are on: the fields are checked. The denied pair lists are of
    # different lengths, and only `User.b` is denied.
    var fields = List[AuthField]()
    fields.append(_field("Query", "a", "String"))
    var others = List[String]()
    others.append("Other")
    var pair_types = List[String]()
    pair_types.append("User")
    pair_types.append("Query")
    var pair_names = List[String]()
    pair_names.append("b")
    var scoped = authorize_fields(
        False,
        True,
        True,
        False,
        False,
        fields,
        List[String](),
        pair_types,
        pair_names,
        others,
    )
    assert_equal(scoped.kind, 0)
    # Policies are on: an operation with no fields changes nothing.
    var empty = authorize_fields(
        False,
        True,
        False,
        True,
        False,
        List[AuthField](),
        List[String](),
        List[String](),
        List[String](),
        List[String](),
    )
    assert_equal(empty.kind, 0)
    # No denied pairs: the field stays.
    var one = List[AuthField]()
    one.append(_field("Query", "a", "String"))
    var unpaired = authorize_fields(
        False,
        False,
        True,
        False,
        False,
        one,
        List[String](),
        List[String](),
        List[String](),
        List[String](),
    )
    assert_equal(unpaired.kind, 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
