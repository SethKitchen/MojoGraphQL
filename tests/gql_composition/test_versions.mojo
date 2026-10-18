# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the federation versions `v1.0` and `v2.0` to `v2.15`.

Upstream has no test file for this. For `v2.0` to `v2.9` the expected
errors come from Hive Federation Composition v0.27.0 in Node.js. For
`v2.10` to `v2.15` they follow the Apollo GraphOS page "Federation
versions": `v2.12` adds `@cacheTag`, and the other versions add nothing.
"""

from gql_composition.version import (
    VERSION_COUNT,
    VERSION_NAMES,
    FederationVersion,
    satisfies_version_range,
)
from gql_composition.compose import compose_subgraphs
from _harness import check, errors_of, sg
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _link(version: String, imports: String) -> String:
    """Return a schema extension that links a federation version."""
    return (
        'extend schema @link(url: "https://specs.apollo.dev/federation/'
        + version
        + '", import: ['
        + imports
        + "])\n"
    )


def test_version_table() raises:
    assert_equal(VERSION_COUNT, 17)
    assert_equal(FederationVersion.LATEST.text(), "v2.15")
    assert_equal(FederationVersion(13).text(), "v2.12")
    assert_equal(FederationVersion(VERSION_COUNT).text(), "<invalid>")
    assert_false(FederationVersion(VERSION_COUNT).is_valid())
    assert_equal(FederationVersion.from_text("v2.16"), -1)
    assert_equal(FederationVersion.from_text("v2.1"), 2)
    assert_equal(FederationVersion.from_text("v2.10"), 11)
    assert_true(FederationVersion(11).above(209))
    assert_true(FederationVersion(10).below(210))
    assert_equal(FederationVersion.V1_0.number(), 100)
    assert_equal(String(FederationVersion.V2_12), "v2.12")
    assert_true(satisfies_version_range("v2.10", ">= v2.9"))
    assert_false(satisfies_version_range("v2.9", ">= v2.10"))
    assert_true(satisfies_version_range("v2.3", "> v1.0"))
    assert_false(satisfies_version_range("v1.0", "> v1.0"))
    assert_true(satisfies_version_range("v2.0", "< v2.3"))
    assert_false(satisfies_version_range("v2.3", "< v2.3"))
    assert_true(satisfies_version_range("v2.8", ">= v2.8"))
    assert_false(satisfies_version_range("v2.3", "nope"))
    assert_false(satisfies_version_range("v2.3", " v2.3"))
    assert_false(satisfies_version_range("v9.9", ">= v2.3"))
    assert_false(satisfies_version_range("v2.3", ">= v9.9"))


def test_cache_tag_is_printed_on_the_supergraph() raises:
    var result = compose_subgraphs(
        [
            sg(
                "a",
                _link("v2.12", '"@cacheTag"')
                + 'type Query @cacheTag(format: "q") {\n'
                + '  a: String @cacheTag(format: "a")\n'
                + "}\n",
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_true(
        result.supergraph_sdl.find(
            "directive @cacheTag(format: String!) repeatable on"
            " FIELD_DEFINITION | OBJECT"
        )
        >= 0
    )
    assert_true(result.supergraph_sdl.find('@cacheTag(format: "q")') >= 0)
    assert_true(result.supergraph_sdl.find('@cacheTag(format: "a")') >= 0)
    assert_true(result.public_sdl.find("cacheTag") < 0)


def test_cache_tags_from_two_subgraphs_are_combined() raises:
    var link = _link("v2.12", '"@cacheTag", "@shareable"')
    var result = compose_subgraphs(
        [
            sg(
                "a",
                link
                + 'type Query @cacheTag(format: "q") {\n'
                + '  a: String @shareable @cacheTag(format: "a")\n'
                + "}\n",
            ),
            sg(
                "b",
                link
                + 'type Query @cacheTag(format: "r") {\n'
                + '  a: String @shareable @cacheTag(format: "a")'
                + ' @cacheTag(format: "b")\n'
                + "}\n",
            ),
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_true(
        result.supergraph_sdl.find(
            '@cacheTag(format: "q") @cacheTag(format: "r")'
        )
        >= 0
    )
    assert_true(
        result.supergraph_sdl.find(
            '@cacheTag(format: "a") @cacheTag(format: "b")'
        )
        >= 0
    )
    assert_true(
        result.supergraph_sdl.find(
            '@cacheTag(format: "a") @cacheTag(format: "a")'
        )
        < 0
    )


def test_a_renamed_cache_tag_keeps_its_local_name() raises:
    var result = compose_subgraphs(
        [
            sg(
                "a",
                "extend schema @link(url:"
                ' "https://specs.apollo.dev/federation/v2.12", import:'
                ' [{name: "@cacheTag", as: "@ctag"}])\n'
                + 'type Query { a: String @ctag(format: "a") }\n',
            )
        ]
    )
    assert_equal(len(result.errors), 0)
    assert_true(
        result.supergraph_sdl.find(
            "directive @ctag(format: String!) repeatable on"
            " FIELD_DEFINITION | OBJECT"
        )
        >= 0
    )
    assert_true(result.supergraph_sdl.find('@ctag(format: "a")') >= 0)
    assert_true(result.supergraph_sdl.find("cacheTag") < 0)


def test_every_version_links() raises:
    var index = 1
    while index < VERSION_COUNT:
        var version = String(materialize[VERSION_NAMES]()[index])
        check(
            [
                sg(
                    "a",
                    _link(version, '"@key", "@shareable"')
                    + "type Query { a: String @shareable }\ntype User"
                    ' @key(fields: "id") { id: ID! }',
                )
            ],
            [],
        )
        index += 1


def test_an_unknown_version_does_not_link() raises:
    check(
        [sg("a", _link("v2.16", '"@key"') + "type Query { a: String }")],
        [
            "[UNKNOWN_FEDERATION_LINK_VERSION] [a] Invalid version v2.16 for"
            " the federation feature in @link directive on schema"
        ],
    )


comptime _NEW_DIRECTIVES: Array[StaticString, 7] = [
    "composeDirective",
    "interfaceObject",
    "authenticated",
    "policy",
    "context",
    "cost",
    "cacheTag",
]
comptime _FIRST_VERSION: Array[Int, 7] = [201, 203, 205, 206, 208, 208, 212]


def test_new_directives_exist_only_from_their_version() raises:
    var index = 1
    while index < VERSION_COUNT:
        var version = FederationVersion(UInt8(index))
        var item = 0
        while item < 7:
            var name = String(materialize[_NEW_DIRECTIVES]()[item])
            var got = errors_of(
                [
                    sg(
                        "a",
                        _link(version.text(), '"@' + name + '"')
                        + "type Query { a: String }",
                    )
                ]
            )
            if version.at_least(materialize[_FIRST_VERSION]()[item]):
                assert_equal(len(got), 0, version.text() + " @" + name)
            else:
                assert_equal(len(got), 1, version.text() + " @" + name)
                assert_equal(
                    got[0],
                    "[INVALID_LINK_DIRECTIVE_USAGE] [a] Cannot import unknown"
                    ' element "@'
                    + name
                    + '".',
                )
            item += 1
        index += 1


def test_cache_tag_definition() raises:
    var head = _link("v2.12", '"@key", "@cacheTag"')
    check(
        [
            sg(
                "a",
                head
                + 'type Query @cacheTag(format: "q") @cacheTag(format: "r") {'
                ' a: String @cacheTag(format: "a") }',
            )
        ],
        [],
    )
    check(
        [sg("a", head + "type Query { a: String @cacheTag }")],
        [
            '[INVALID_GRAPHQL] [a] Directive "@cacheTag" argument "format" of'
            ' type "String!" is required, but it was not provided.'
        ],
    )
    check(
        [
            sg(
                "a",
                head
                + 'type Query { a: E }\nenum E @cacheTag(format: "e") { A }',
            )
        ],
        [
            '[INVALID_GRAPHQL] [a] Directive "@cacheTag" may not be used on'
            " ENUM."
        ],
    )


def test_cache_tag_with_the_namespace() raises:
    check(
        [
            sg(
                "a",
                _link("v2.15", '"@key"')
                + 'type Query { a: String @federation__cacheTag(format: "a") }',
            )
        ],
        [],
    )
    check(
        [
            sg(
                "a",
                _link("v2.11", '"@key"')
                + 'type Query { a: String @federation__cacheTag(format: "a") }',
            )
        ],
        ['[INVALID_GRAPHQL] [a] Unknown directive "@federation__cacheTag".'],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
