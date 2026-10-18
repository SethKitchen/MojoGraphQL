# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the federation version of a supergraph configuration.

Ported from `apollo-federation-types` 0.18.0-rc.1 `src/config/version.rs`
(`test_deserialization`, `rejects_unsupported_versions`,
`test_fed_three_plugin_version`) and Rover `src/federation.rs`.
"""

from gql_seamstress.federation_version import FEDERATION_ONE_UNSUPPORTED
from gql_seamstress.federation_version import (
    FederationVersion,
    FederationVersionKind,
)
from gql_seamstress.federation_version import SemanticVersion
from gql_seamstress.federation_version import is_federation_one_exact_pin
from gql_seamstress.federation_version import parse_federation_version
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _check(input: String, kind: FederationVersionKind, display: String) raises:
    var version = FederationVersion.parse(input)
    assert_true(version.kind == kind, input)
    assert_equal(String(version), display)


def _error(input: String) raises -> String:
    try:
        _ = FederationVersion.parse(input)
    except e:
        return String(e)
    raise Error("no error for " + input)


def test_deserialization() raises:
    _check("2", FederationVersionKind.LATEST_FED_TWO, "2")
    _check("latest-2", FederationVersionKind.LATEST_FED_TWO, "2")
    _check("1", FederationVersionKind.LATEST_FED_ONE, "0")
    _check("0", FederationVersionKind.LATEST_FED_ONE, "0")
    _check("latest-1", FederationVersionKind.LATEST_FED_ONE, "0")
    _check("latest-0", FederationVersionKind.LATEST_FED_ONE, "0")
    _check("=2.3.4", FederationVersionKind.EXACT_FED_TWO, "=2.3.4")
    _check("v2.3.4", FederationVersionKind.EXACT_FED_TWO, "=2.3.4")
    _check("=0.37.8", FederationVersionKind.EXACT_FED_ONE, "=0.37.8")
    _check("v0.37.8", FederationVersionKind.EXACT_FED_ONE, "=0.37.8")
    _check("3", FederationVersionKind.LATEST_FED_THREE, "3")
    _check("latest-3", FederationVersionKind.LATEST_FED_THREE, "3")
    _check(
        "=3.0.0-preview.0",
        FederationVersionKind.EXACT_FED_THREE,
        "=3.0.0-preview.0",
    )
    _check("v3.1.2", FederationVersionKind.EXACT_FED_THREE, "=3.1.2")
    _check(
        "=2.0.0-preview.9",
        FederationVersionKind.EXACT_FED_TWO,
        "=2.0.0-preview.9",
    )
    _check(
        "=2.0.0-preview.10",
        FederationVersionKind.EXACT_FED_TWO,
        "=2.0.0-preview.10",
    )
    _check(
        "=2.4.0+build.7", FederationVersionKind.EXACT_FED_TWO, "=2.4.0+build.7"
    )


def test_numbers() raises:
    assert_true(
        FederationVersion.from_number(0).kind
        == FederationVersionKind.LATEST_FED_ONE
    )
    assert_true(
        FederationVersion.from_number(1).kind
        == FederationVersionKind.LATEST_FED_ONE
    )
    assert_true(
        FederationVersion.from_number(2).kind
        == FederationVersionKind.LATEST_FED_TWO
    )
    assert_true(
        FederationVersion.from_number(3).kind
        == FederationVersionKind.LATEST_FED_THREE
    )
    try:
        _ = FederationVersion.from_number(4)
        raise Error("4 was accepted")
    except e:
        assert_equal(String(e), "specified version `4` is not supported")


comptime _CHOICES = (
    "You can either specify '1', '2', '3', or a fully qualified version"
    " prefixed with an '=', like: =2.0.0"
)


def test_rejects_unsupported_versions() raises:
    for input in [
        "=4.0.0",
        "4",
        "",
        "=",
        "x2.0.0",
        "=2.0",
        "=02.0.0",
        "=a.b.c",
        "latest",
    ]:
        assert_equal(
            _error(input),
            "Specified version `" + input + "` is not supported. " + _CHOICES,
        )
    assert_equal(
        _error("=3.0.0-alpha.0"),
        (
            "Specified version `=3.0.0-alpha.0` is not supported. The earliest"
            " version you can specify for federation 3 is '=3.0.0-preview.0'"
        ),
    )
    assert_equal(
        _error("=2.0.0-preview.8"),
        (
            "Specified version `=2.0.0-preview.8` is not supported. The"
            " earliest version you can specify for federation 2 is"
            " '=2.0.0-preview.9'"
        ),
    )
    assert_equal(
        _error("=2.0.0-alpha"),
        (
            "Specified version `=2.0.0-alpha` is not supported. The earliest"
            " version you can specify for federation 2 is '=2.0.0-preview.9'"
        ),
    )
    assert_equal(
        _error("=0.35.9"),
        (
            "Specified version `=0.35.9` is not supported. The earliest version"
            " you can specify for federation 1 is '=0.36.0'"
        ),
    )


def test_semantic_versions() raises:
    assert_equal(len(SemanticVersion.parse("1.2.3-a-b").value().pre), 1)
    assert_equal(len(SemanticVersion.parse("1.2.3--a").value().pre), 1)
    for bad in [
        "1..3",
        "1.2",
        "1.2.3.4",
        "1.2.x",
        "1.2.3-",
        "1.2.3-a..b",
        "1.2.3-01",
        "1.2.3+",
        "1.2.3+a_b",
        "1.2.3-a_b",
        "1234567890123456789.0.0",
        "-1.2.3",
    ]:
        assert_false(SemanticVersion.parse(bad).__bool__(), bad)
    var version = SemanticVersion.parse("1.2.3-rc.1+007").value().copy()
    assert_equal(version.major, 1)
    assert_equal(version.minor, 2)
    assert_equal(version.patch, 3)
    assert_equal(len(version.pre), 2)
    assert_equal(String(version), "1.2.3-rc.1+007")


def _at_least(a: String, b: String) raises -> Bool:
    return (
        SemanticVersion.parse(a)
        .value()
        .at_least(SemanticVersion.parse(b).value())
    )


def test_precedence() raises:
    assert_true(_at_least("2.0.0", "1.9.9"))
    assert_false(_at_least("1.0.0", "2.0.0"))
    assert_true(_at_least("1.2.0", "1.1.9"))
    assert_false(_at_least("1.1.0", "1.2.0"))
    assert_true(_at_least("1.1.2", "1.1.1"))
    assert_false(_at_least("1.1.1", "1.1.2"))
    assert_true(_at_least("1.0.0", "1.0.0-rc.1"))
    assert_false(_at_least("1.0.0-rc.1", "1.0.0"))
    assert_true(_at_least("1.0.0", "1.0.0"))
    assert_true(_at_least("1.0.0-rc.2", "1.0.0-rc.1"))
    assert_false(_at_least("1.0.0-rc.1", "1.0.0-rc.2"))
    assert_true(_at_least("1.0.0-rc", "1.0.0-1"))
    assert_false(_at_least("1.0.0-1", "1.0.0-rc"))
    assert_true(_at_least("1.0.0-beta", "1.0.0-alpha"))
    assert_false(_at_least("1.0.0-alpha", "1.0.0-beta"))
    assert_true(_at_least("1.0.0-alpha.1", "1.0.0-alpha"))
    assert_false(_at_least("1.0.0-alpha", "1.0.0-alpha.1"))
    assert_true(_at_least("1.0.0-alpha", "1.0.0-alpha"))


def test_kinds() raises:
    assert_true(FederationVersionKind.EXACT_FED_THREE.is_valid())
    assert_false(FederationVersionKind(6).is_valid())
    assert_true(FederationVersionKind.EXACT_FED_ONE.is_exact())
    assert_false(FederationVersionKind.LATEST_FED_THREE.is_exact())
    assert_false(FederationVersionKind(6).is_exact())
    assert_equal(String(FederationVersionKind.LATEST_FED_TWO), "LatestFedTwo")
    assert_equal(String(FederationVersionKind.EXACT_FED_THREE), "ExactFedThree")
    assert_equal(String(FederationVersionKind(9)), "<invalid>")


def test_is_fed_one() raises:
    assert_true(FederationVersion.parse("1").is_fed_one())
    assert_true(FederationVersion.parse("=0.36.0").is_fed_one())
    assert_false(FederationVersion.parse("2").is_fed_one())


def test_federation_one_exact_pin() raises:
    assert_true(is_federation_one_exact_pin("=1.0.0"))
    assert_true(is_federation_one_exact_pin("v0.36.0"))
    assert_false(is_federation_one_exact_pin("=2.0.0"))
    assert_false(is_federation_one_exact_pin("1.0.0"))
    assert_false(is_federation_one_exact_pin("=x"))


def test_parse_federation_version() raises:
    assert_equal(String(parse_federation_version("=2.9.3")), "=2.9.3")
    try:
        _ = parse_federation_version("=1.5.0")
        raise Error("=1.5.0 was accepted")
    except e:
        assert_equal(String(e), FEDERATION_ONE_UNSUPPORTED)
    try:
        _ = parse_federation_version("9")
        raise Error("9 was accepted")
    except e:
        assert_equal(
            String(e),
            (
                "Specified version `9` is not supported. You can specify '2',"
                " '3', or a fully qualified version prefixed with an '=', like:"
                " =2.0.0"
            ),
        )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
