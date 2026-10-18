# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the join specification of a supergraph.

Upstream has no separate test file. The definitions are those of Hive
Federation Composition v0.27.0 `src/specifications/join.ts`. `v2.10` to
`v2.15` use the `v2.8` definitions.
"""

from gql_composition.join_spec import join_sdl, join_spec_version
from gql_composition.version import FederationVersion
from gql_language.parser import parse
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _sdl(minor: Int) raises -> String:
    """Return the join SDL of federation 2 at a minor version."""
    return join_sdl(FederationVersion(UInt8(minor + 1)))


def test_join_versions() raises:
    assert_equal(join_spec_version(FederationVersion.V1_0), "v0.3")
    assert_equal(join_spec_version(FederationVersion.V2_0), "v0.3")
    assert_equal(_version_text(6), "v0.3")
    assert_equal(_version_text(7), "v0.4")
    assert_equal(_version_text(8), "v0.5")
    assert_equal(join_spec_version(FederationVersion.LATEST), "v0.5")


def _version_text(minor: Int) raises -> String:
    """Return the join URL version of federation 2 at a minor version."""
    return join_spec_version(FederationVersion(UInt8(minor + 1)))


def _has(text: String, needle: String) -> Bool:
    """Return True when `text` contains `needle`."""
    return text.find(needle) != -1


def test_field_arguments_follow_the_federation_version() raises:
    var before = _sdl(6)
    var at_label = _sdl(7)
    var at_context = _sdl(8)
    var latest = join_sdl(FederationVersion.LATEST)
    assert_false(_has(before, "overrideLabel"))
    assert_false(_has(before, "contextArguments"))
    assert_true(_has(at_label, "overrideLabel"))
    assert_false(_has(at_label, "contextArguments"))
    assert_true(_has(at_context, "overrideLabel"))
    assert_true(_has(at_context, "contextArguments"))
    assert_true(_has(at_context, "join__FieldValue"))
    assert_false(_has(at_label, "join__FieldValue"))
    assert_equal(latest, at_context)
    _ = parse(before)
    _ = parse(at_label)
    _ = parse(latest)


def test_an_invalid_version_is_rejected() raises:
    var failed = False
    try:
        _ = join_sdl(FederationVersion(UInt8(99)))
    except:
        failed = True
    assert_true(failed)
    failed = False
    try:
        _ = join_spec_version(FederationVersion(UInt8(99)))
    except:
        failed = True
    assert_true(failed)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
