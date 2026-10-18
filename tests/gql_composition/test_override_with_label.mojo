# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/override-with-label.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_override_label_guild_v2_0_not_available_raise_na_error() raises:
    # @override(label:) > guild > v2.0 > not available, raise na error
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "public")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [foo] Unknown argument "label" on directive'
                ' "@override".'
            ),
        ],
    )


def test_override_label_guild_v2_1_not_available_raise_na_error() raises:
    # @override(label:) > guild > v2.1 > not available, raise na error
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "public")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [foo] Unknown argument "label" on directive'
                ' "@override".'
            ),
        ],
    )


def test_override_label_guild_v2_2_not_available_raise_na_error() raises:
    # @override(label:) > guild > v2.2 > not available, raise na error
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "public")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [foo] Unknown argument "label" on directive'
                ' "@override".'
            ),
        ],
    )


def test_override_label_guild_v2_3_not_available_raise_na_error() raises:
    # @override(label:) > guild > v2.3 > not available, raise na error
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "public")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [foo] Unknown argument "label" on directive'
                ' "@override".'
            ),
        ],
    )


def test_override_label_guild_v2_4_not_available_raise_na_error() raises:
    # @override(label:) > guild > v2.4 > not available, raise na error
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "public")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [foo] Unknown argument "label" on directive'
                ' "@override".'
            ),
        ],
    )


def test_override_label_guild_v2_5_not_available_raise_na_error() raises:
    # @override(label:) > guild > v2.5 > not available, raise na error
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "public")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [foo] Unknown argument "label" on directive'
                ' "@override".'
            ),
        ],
    )


def test_override_label_guild_v2_6_not_available_raise_na_error() raises:
    # @override(label:) > guild > v2.6 > not available, raise na error
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "public")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[INVALID_GRAPHQL] [foo] Unknown argument "label" on directive'
                ' "@override".'
            ),
        ],
    )


def test_override_label_guild_v2_7_available_allow_to_use() raises:
    # @override(label:) > guild > v2.7 > available, allow to use
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "public")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override", "@shareable"])\n\ntype Query {\n '
                    ' foo: User\n}\n\ntype User @key(fields: "id") {\n  id:'
                    ' ID\n  name: String @override(from: "bar", label:'
                    ' "public") @shareable\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  bar:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " name: String @shareable\n}"
                ),
            ),
            sg(
                "baz",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\n\ntype User @key(fields: "id")'
                    " {\n  id: ID\n  name: String @shareable\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override", "@shareable"])\n\ntype Query {\n '
                    ' foo: User\n}\n\ntype User @key(fields: "id") {\n  id:'
                    ' ID\n  name: String @override(from: "bar", label:'
                    ' "public") @shareable\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  bar:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " name: String @shareable\n}"
                ),
            ),
            sg(
                "baz",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable"])\n\ntype User @key(fields: "id")'
                    " {\n  id: ID\n}"
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_7_label_percent_11_should_fail() raises:
    # @override(label:) > guild > v2.7 > label: "percent(-11)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-11)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-11)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_7_label_percent_1_1_should_fail() raises:
    # @override(label:) > guild > v2.7 > label: "percent(-1.1)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-1.1)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-1.1)" on field "User.name" on subgraph "foo":'
                " labels must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_7_label_percent_1_should_fail() raises:
    # @override(label:) > guild > v2.7 > label: "percent(-1)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-1)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-1)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_7_label_percent_0_should_fail() raises:
    # @override(label:) > guild > v2.7 > label: "percent(-0)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-0)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-0)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_7_label_percent_0_should_fail_2() raises:
    # @override(label:) > guild > v2.7 > label: "percent(+0)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(+0)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(+0)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_7_label_percent_0_00_should_fail() raises:
    # @override(label:) > guild > v2.7 > label: "percent(+0.00)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(+0.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(+0.00)" on field "User.name" on subgraph "foo":'
                " labels must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_7_label_percent_0_00_should_fail_2() raises:
    # @override(label:) > guild > v2.7 > label: "percent(-0.00)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-0.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-0.00)" on field "User.name" on subgraph "foo":'
                " labels must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_7_label_percent_1_123456789_should_fail() raises:
    # @override(label:) > guild > v2.7 > label: "percent(1.123456789)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(1.123456789)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(1.123456789)" on field "User.name" on subgraph'
                ' "foo": labels must start with a letter and after that may'
                " contain alphanumerics, underscores, minuses, colons, periods,"
                " or slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_7_label_percent_101_should_fail() raises:
    # @override(label:) > guild > v2.7 > label: "percent(101)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(101)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(101)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_7_label_0foo_should_fail() raises:
    # @override(label:) > guild > v2.7 > label: "0foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "0foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "0foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail() raises:
    # @override(label:) > guild > v2.7 > label: "_foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "_foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "_foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_2() raises:
    # @override(label:) > guild > v2.7 > label: "-foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "-foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "-foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_3() raises:
    # @override(label:) > guild > v2.7 > label: ":foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: ":foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label ":foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_4() raises:
    # @override(label:) > guild > v2.7 > label: ".foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: ".foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label ".foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_5() raises:
    # @override(label:) > guild > v2.7 > label: "/foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "/foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "/foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_6() raises:
    # @override(label:) > guild > v2.7 > label: "!foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "!foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "!foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_7() raises:
    # @override(label:) > guild > v2.7 > label: "foo%" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo%")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo%"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_8() raises:
    # @override(label:) > guild > v2.7 > label: "foo(" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo(")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo("'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_9() raises:
    # @override(label:) > guild > v2.7 > label: "foo)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo)"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_10() raises:
    # @override(label:) > guild > v2.7 > label: "foo[" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo[")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo["'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_11() raises:
    # @override(label:) > guild > v2.7 > label: "foo]" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo]")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo]"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_12() raises:
    # @override(label:) > guild > v2.7 > label: "foo{" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo{")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo{"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_13() raises:
    # @override(label:) > guild > v2.7 > label: "foo}" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo}")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo}"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_14() raises:
    # @override(label:) > guild > v2.7 > label: "foo<" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo<")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo<"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_15() raises:
    # @override(label:) > guild > v2.7 > label: "foo>" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo>")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo>"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_16() raises:
    # @override(label:) > guild > v2.7 > label: "foo=" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo=")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo="'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_17() raises:
    # @override(label:) > guild > v2.7 > label: "foo?" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo?")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo?"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_18() raises:
    # @override(label:) > guild > v2.7 > label: "foo!" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo!")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo!"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_19() raises:
    # @override(label:) > guild > v2.7 > label: "foo@" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo@")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo@"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_20() raises:
    # @override(label:) > guild > v2.7 > label: "foo#" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo#")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo#"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_21() raises:
    # @override(label:) > guild > v2.7 > label: "foo$" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo$")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo$"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_22() raises:
    # @override(label:) > guild > v2.7 > label: "foo^" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo^")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo^"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_23() raises:
    # @override(label:) > guild > v2.7 > label: "foo&" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo&")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo&"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_24() raises:
    # @override(label:) > guild > v2.7 > label: "foo*" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo*")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo*"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_25() raises:
    # @override(label:) > guild > v2.7 > label: "foo~" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo~")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo~"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_26() raises:
    # @override(label:) > guild > v2.7 > label: "foo`" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo`")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo`"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_27() raises:
    # @override(label:) > guild > v2.7 > label: "foo|" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo|")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo|"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_28() raises:
    # @override(label:) > guild > v2.7 > label: "foo;" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo;")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo;"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_29() raises:
    # @override(label:) > guild > v2.7 > label: "foo," should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo,")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo,"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_30() raises:
    # @override(label:) > guild > v2.7 > label: "foo " should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo ")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo "'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_foo_should_fail_31() raises:
    # @override(label:) > guild > v2.7 > label: " foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: " foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label " foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_0_should_fail() raises:
    # @override(label:) > guild > v2.7 > label: " 0" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: " 0")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label " 0" on'
                ' field "User.name" on subgraph "foo": labels must start with a'
                " letter and after that may contain alphanumerics, underscores,"
                " minuses, colons, periods, or slashes. Alternatively, labels"
                ' may be of the form "percent(x)" where x is a float between'
                " 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_7_label_percent_0_00_should_pass() raises:
    # @override(label:) > guild > v2.7 > label: "percent(0.00)" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(0.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_7_label_percent_1_00_should_pass() raises:
    # @override(label:) > guild > v2.7 > label: "percent(1.00)" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(1.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_7_label_percent_1_12345678_should_pass() raises:
    # @override(label:) > guild > v2.7 > label: "percent(1.12345678)" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(1.12345678)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_7_label_percent_100_00_should_pass() raises:
    # @override(label:) > guild > v2.7 > label: "percent(100.00)" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(100.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_7_label_foo_should_pass() raises:
    # @override(label:) > guild > v2.7 > label: "foo" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_7_label_foo_bar_should_pass() raises:
    # @override(label:) > guild > v2.7 > label: "foo_bar" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo_bar")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_7_label_percent1_should_pass() raises:
    # @override(label:) > guild > v2.7 > label: "percent1" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "percent1")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_7_label_f0_should_pass() raises:
    # @override(label:) > guild > v2.7 > label: "f0" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f0")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_7_label_f_should_pass() raises:
    # @override(label:) > guild > v2.7 > label: "f_" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f_")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_7_label_f_should_pass_2() raises:
    # @override(label:) > guild > v2.7 > label: "f-" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f-")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_7_label_f_should_pass_3() raises:
    # @override(label:) > guild > v2.7 > label: "f:" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f:")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_7_label_f_should_pass_4() raises:
    # @override(label:) > guild > v2.7 > label: "f." should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f.")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_7_label_f_should_pass_5() raises:
    # @override(label:) > guild > v2.7 > label: "f/" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f/")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_7_should_detect_unsatisfiable_paths() raises:
    # @override(label:) > guild > v2.7 > should detect unsatisfiable paths
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  user(id: ID!):'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' group: Group @override(from: "b")\n}\n\ntype Group'
                    ' @key(fields: "id") {\n  id: ID!\n  level: Int\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@requires", "@external", "@override"])\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  group: Group!\n '
                    ' groupLevel: ID! @requires(fields: "group { level'
                    ' }")\n}\n\ntype Group @key(fields: "id") {\n  id: ID\n '
                    " level: Int @external\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  user(id: ID!):'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' group: Group @override(from: "b", label:'
                    ' "public")\n}\n\ntype Group @key(fields: "id") {\n  id:'
                    " ID!\n  level: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@requires", "@external", "@override"])\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  group: Group!\n '
                    ' groupLevel: ID! @requires(fields: "group { level'
                    ' }")\n}\n\ntype Group @key(fields: "id") {\n  id: ID\n '
                    " level: Int @external\n}"
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_available_allow_to_use() raises:
    # @override(label:) > guild > v2.8 > available, allow to use
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "public")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override", "@shareable"])\n\ntype Query {\n '
                    ' foo: User\n}\n\ntype User @key(fields: "id") {\n  id:'
                    ' ID\n  name: String @override(from: "bar", label:'
                    ' "public") @shareable\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  bar:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " name: String @shareable\n}"
                ),
            ),
            sg(
                "baz",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable"])\n\ntype User @key(fields: "id")'
                    " {\n  id: ID\n  name: String @shareable\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override", "@shareable"])\n\ntype Query {\n '
                    ' foo: User\n}\n\ntype User @key(fields: "id") {\n  id:'
                    ' ID\n  name: String @override(from: "bar", label:'
                    ' "public") @shareable\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  bar:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " name: String @shareable\n}"
                ),
            ),
            sg(
                "baz",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable"])\n\ntype User @key(fields: "id")'
                    " {\n  id: ID\n}"
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_label_percent_11_should_fail() raises:
    # @override(label:) > guild > v2.8 > label: "percent(-11)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-11)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-11)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_8_label_percent_1_1_should_fail() raises:
    # @override(label:) > guild > v2.8 > label: "percent(-1.1)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-1.1)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-1.1)" on field "User.name" on subgraph "foo":'
                " labels must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_8_label_percent_1_should_fail() raises:
    # @override(label:) > guild > v2.8 > label: "percent(-1)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-1)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-1)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_8_label_percent_0_should_fail() raises:
    # @override(label:) > guild > v2.8 > label: "percent(-0)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-0)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-0)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_8_label_percent_0_should_fail_2() raises:
    # @override(label:) > guild > v2.8 > label: "percent(+0)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(+0)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(+0)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_8_label_percent_0_00_should_fail() raises:
    # @override(label:) > guild > v2.8 > label: "percent(+0.00)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(+0.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(+0.00)" on field "User.name" on subgraph "foo":'
                " labels must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_8_label_percent_0_00_should_fail_2() raises:
    # @override(label:) > guild > v2.8 > label: "percent(-0.00)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-0.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-0.00)" on field "User.name" on subgraph "foo":'
                " labels must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_8_label_percent_1_123456789_should_fail() raises:
    # @override(label:) > guild > v2.8 > label: "percent(1.123456789)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(1.123456789)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(1.123456789)" on field "User.name" on subgraph'
                ' "foo": labels must start with a letter and after that may'
                " contain alphanumerics, underscores, minuses, colons, periods,"
                " or slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_8_label_percent_101_should_fail() raises:
    # @override(label:) > guild > v2.8 > label: "percent(101)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(101)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(101)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_8_label_0foo_should_fail() raises:
    # @override(label:) > guild > v2.8 > label: "0foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "0foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "0foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail() raises:
    # @override(label:) > guild > v2.8 > label: "_foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "_foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "_foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_2() raises:
    # @override(label:) > guild > v2.8 > label: "-foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "-foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "-foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_3() raises:
    # @override(label:) > guild > v2.8 > label: ":foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: ":foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label ":foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_4() raises:
    # @override(label:) > guild > v2.8 > label: ".foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: ".foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label ".foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_5() raises:
    # @override(label:) > guild > v2.8 > label: "/foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "/foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "/foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_6() raises:
    # @override(label:) > guild > v2.8 > label: "!foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "!foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "!foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_7() raises:
    # @override(label:) > guild > v2.8 > label: "foo%" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo%")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo%"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_8() raises:
    # @override(label:) > guild > v2.8 > label: "foo(" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo(")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo("'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_9() raises:
    # @override(label:) > guild > v2.8 > label: "foo)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo)"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_10() raises:
    # @override(label:) > guild > v2.8 > label: "foo[" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo[")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo["'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_11() raises:
    # @override(label:) > guild > v2.8 > label: "foo]" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo]")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo]"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_12() raises:
    # @override(label:) > guild > v2.8 > label: "foo{" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo{")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo{"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_13() raises:
    # @override(label:) > guild > v2.8 > label: "foo}" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo}")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo}"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_14() raises:
    # @override(label:) > guild > v2.8 > label: "foo<" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo<")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo<"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_15() raises:
    # @override(label:) > guild > v2.8 > label: "foo>" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo>")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo>"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_16() raises:
    # @override(label:) > guild > v2.8 > label: "foo=" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo=")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo="'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_17() raises:
    # @override(label:) > guild > v2.8 > label: "foo?" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo?")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo?"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_18() raises:
    # @override(label:) > guild > v2.8 > label: "foo!" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo!")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo!"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_19() raises:
    # @override(label:) > guild > v2.8 > label: "foo@" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo@")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo@"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_20() raises:
    # @override(label:) > guild > v2.8 > label: "foo#" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo#")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo#"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_21() raises:
    # @override(label:) > guild > v2.8 > label: "foo$" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo$")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo$"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_22() raises:
    # @override(label:) > guild > v2.8 > label: "foo^" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo^")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo^"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_23() raises:
    # @override(label:) > guild > v2.8 > label: "foo&" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo&")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo&"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_24() raises:
    # @override(label:) > guild > v2.8 > label: "foo*" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo*")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo*"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_25() raises:
    # @override(label:) > guild > v2.8 > label: "foo~" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo~")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo~"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_26() raises:
    # @override(label:) > guild > v2.8 > label: "foo`" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo`")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo`"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_27() raises:
    # @override(label:) > guild > v2.8 > label: "foo|" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo|")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo|"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_28() raises:
    # @override(label:) > guild > v2.8 > label: "foo;" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo;")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo;"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_29() raises:
    # @override(label:) > guild > v2.8 > label: "foo," should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo,")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo,"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_30() raises:
    # @override(label:) > guild > v2.8 > label: "foo " should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo ")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo "'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_foo_should_fail_31() raises:
    # @override(label:) > guild > v2.8 > label: " foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: " foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label " foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_0_should_fail() raises:
    # @override(label:) > guild > v2.8 > label: " 0" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: " 0")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label " 0" on'
                ' field "User.name" on subgraph "foo": labels must start with a'
                " letter and after that may contain alphanumerics, underscores,"
                " minuses, colons, periods, or slashes. Alternatively, labels"
                ' may be of the form "percent(x)" where x is a float between'
                " 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_8_label_percent_0_00_should_pass() raises:
    # @override(label:) > guild > v2.8 > label: "percent(0.00)" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(0.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_label_percent_1_00_should_pass() raises:
    # @override(label:) > guild > v2.8 > label: "percent(1.00)" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(1.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_label_percent_1_12345678_should_pass() raises:
    # @override(label:) > guild > v2.8 > label: "percent(1.12345678)" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(1.12345678)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_label_percent_100_00_should_pass() raises:
    # @override(label:) > guild > v2.8 > label: "percent(100.00)" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(100.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_label_foo_should_pass() raises:
    # @override(label:) > guild > v2.8 > label: "foo" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_label_foo_bar_should_pass() raises:
    # @override(label:) > guild > v2.8 > label: "foo_bar" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo_bar")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_label_percent1_should_pass() raises:
    # @override(label:) > guild > v2.8 > label: "percent1" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "percent1")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_label_f0_should_pass() raises:
    # @override(label:) > guild > v2.8 > label: "f0" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f0")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_label_f_should_pass() raises:
    # @override(label:) > guild > v2.8 > label: "f_" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f_")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_label_f_should_pass_2() raises:
    # @override(label:) > guild > v2.8 > label: "f-" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f-")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_label_f_should_pass_3() raises:
    # @override(label:) > guild > v2.8 > label: "f:" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f:")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_label_f_should_pass_4() raises:
    # @override(label:) > guild > v2.8 > label: "f." should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f.")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_label_f_should_pass_5() raises:
    # @override(label:) > guild > v2.8 > label: "f/" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f/")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_8_should_detect_unsatisfiable_paths() raises:
    # @override(label:) > guild > v2.8 > should detect unsatisfiable paths
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  user(id: ID!):'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' group: Group @override(from: "b")\n}\n\ntype Group'
                    ' @key(fields: "id") {\n  id: ID!\n  level: Int\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@requires", "@external", "@override"])\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  group: Group!\n '
                    ' groupLevel: ID! @requires(fields: "group { level'
                    ' }")\n}\n\ntype Group @key(fields: "id") {\n  id: ID\n '
                    " level: Int @external\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  user(id: ID!):'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' group: Group @override(from: "b", label:'
                    ' "public")\n}\n\ntype Group @key(fields: "id") {\n  id:'
                    " ID!\n  level: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@requires", "@external", "@override"])\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  group: Group!\n '
                    ' groupLevel: ID! @requires(fields: "group { level'
                    ' }")\n}\n\ntype Group @key(fields: "id") {\n  id: ID\n '
                    " level: Int @external\n}"
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_available_allow_to_use() raises:
    # @override(label:) > guild > v2.9 > available, allow to use
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "public")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override", "@shareable"])\n\ntype Query {\n '
                    ' foo: User\n}\n\ntype User @key(fields: "id") {\n  id:'
                    ' ID\n  name: String @override(from: "bar", label:'
                    ' "public") @shareable\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  bar:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " name: String @shareable\n}"
                ),
            ),
            sg(
                "baz",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable"])\n\ntype User @key(fields: "id")'
                    " {\n  id: ID\n  name: String @shareable\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override", "@shareable"])\n\ntype Query {\n '
                    ' foo: User\n}\n\ntype User @key(fields: "id") {\n  id:'
                    ' ID\n  name: String @override(from: "bar", label:'
                    ' "public") @shareable\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable"])\n\ntype Query {\n  bar:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    " name: String @shareable\n}"
                ),
            ),
            sg(
                "baz",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable"])\n\ntype User @key(fields: "id")'
                    " {\n  id: ID\n}"
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_label_percent_11_should_fail() raises:
    # @override(label:) > guild > v2.9 > label: "percent(-11)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-11)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-11)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_9_label_percent_1_1_should_fail() raises:
    # @override(label:) > guild > v2.9 > label: "percent(-1.1)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-1.1)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-1.1)" on field "User.name" on subgraph "foo":'
                " labels must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_9_label_percent_1_should_fail() raises:
    # @override(label:) > guild > v2.9 > label: "percent(-1)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-1)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-1)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_9_label_percent_0_should_fail() raises:
    # @override(label:) > guild > v2.9 > label: "percent(-0)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-0)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-0)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_9_label_percent_0_should_fail_2() raises:
    # @override(label:) > guild > v2.9 > label: "percent(+0)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(+0)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(+0)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_9_label_percent_0_00_should_fail() raises:
    # @override(label:) > guild > v2.9 > label: "percent(+0.00)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(+0.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(+0.00)" on field "User.name" on subgraph "foo":'
                " labels must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_9_label_percent_0_00_should_fail_2() raises:
    # @override(label:) > guild > v2.9 > label: "percent(-0.00)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(-0.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(-0.00)" on field "User.name" on subgraph "foo":'
                " labels must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_9_label_percent_1_123456789_should_fail() raises:
    # @override(label:) > guild > v2.9 > label: "percent(1.123456789)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(1.123456789)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(1.123456789)" on field "User.name" on subgraph'
                ' "foo": labels must start with a letter and after that may'
                " contain alphanumerics, underscores, minuses, colons, periods,"
                " or slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_9_label_percent_101_should_fail() raises:
    # @override(label:) > guild > v2.9 > label: "percent(101)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(101)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                "[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label"
                ' "percent(101)" on field "User.name" on subgraph "foo": labels'
                " must start with a letter and after that may contain"
                " alphanumerics, underscores, minuses, colons, periods, or"
                " slashes. Alternatively, labels may be of the form"
                ' "percent(x)" where x is a float between 0-100 inclusive.'
            ),
        ],
    )


def test_override_label_guild_v2_9_label_0foo_should_fail() raises:
    # @override(label:) > guild > v2.9 > label: "0foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "0foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "0foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail() raises:
    # @override(label:) > guild > v2.9 > label: "_foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "_foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "_foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_2() raises:
    # @override(label:) > guild > v2.9 > label: "-foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "-foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "-foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_3() raises:
    # @override(label:) > guild > v2.9 > label: ":foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: ":foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label ":foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_4() raises:
    # @override(label:) > guild > v2.9 > label: ".foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: ".foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label ".foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_5() raises:
    # @override(label:) > guild > v2.9 > label: "/foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "/foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "/foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_6() raises:
    # @override(label:) > guild > v2.9 > label: "!foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "!foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "!foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_7() raises:
    # @override(label:) > guild > v2.9 > label: "foo%" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo%")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo%"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_8() raises:
    # @override(label:) > guild > v2.9 > label: "foo(" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo(")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo("'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_9() raises:
    # @override(label:) > guild > v2.9 > label: "foo)" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo)"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_10() raises:
    # @override(label:) > guild > v2.9 > label: "foo[" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo[")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo["'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_11() raises:
    # @override(label:) > guild > v2.9 > label: "foo]" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo]")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo]"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_12() raises:
    # @override(label:) > guild > v2.9 > label: "foo{" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo{")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo{"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_13() raises:
    # @override(label:) > guild > v2.9 > label: "foo}" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo}")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo}"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_14() raises:
    # @override(label:) > guild > v2.9 > label: "foo<" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo<")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo<"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_15() raises:
    # @override(label:) > guild > v2.9 > label: "foo>" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo>")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo>"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_16() raises:
    # @override(label:) > guild > v2.9 > label: "foo=" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo=")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo="'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_17() raises:
    # @override(label:) > guild > v2.9 > label: "foo?" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo?")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo?"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_18() raises:
    # @override(label:) > guild > v2.9 > label: "foo!" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo!")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo!"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_19() raises:
    # @override(label:) > guild > v2.9 > label: "foo@" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo@")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo@"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_20() raises:
    # @override(label:) > guild > v2.9 > label: "foo#" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo#")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo#"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_21() raises:
    # @override(label:) > guild > v2.9 > label: "foo$" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo$")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo$"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_22() raises:
    # @override(label:) > guild > v2.9 > label: "foo^" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo^")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo^"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_23() raises:
    # @override(label:) > guild > v2.9 > label: "foo&" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo&")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo&"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_24() raises:
    # @override(label:) > guild > v2.9 > label: "foo*" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo*")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo*"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_25() raises:
    # @override(label:) > guild > v2.9 > label: "foo~" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo~")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo~"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_26() raises:
    # @override(label:) > guild > v2.9 > label: "foo`" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo`")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo`"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_27() raises:
    # @override(label:) > guild > v2.9 > label: "foo|" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo|")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo|"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_28() raises:
    # @override(label:) > guild > v2.9 > label: "foo;" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo;")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo;"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_29() raises:
    # @override(label:) > guild > v2.9 > label: "foo," should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo,")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo,"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_30() raises:
    # @override(label:) > guild > v2.9 > label: "foo " should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo ")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label "foo "'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_foo_should_fail_31() raises:
    # @override(label:) > guild > v2.9 > label: " foo" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: " foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label " foo"'
                ' on field "User.name" on subgraph "foo": labels must start'
                " with a letter and after that may contain alphanumerics,"
                " underscores, minuses, colons, periods, or slashes."
                ' Alternatively, labels may be of the form "percent(x)" where x'
                " is a float between 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_0_should_fail() raises:
    # @override(label:) > guild > v2.9 > label: " 0" should fail
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: " 0")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [
            (
                '[OVERRIDE_LABEL_INVALID] [foo] Invalid @override label " 0" on'
                ' field "User.name" on subgraph "foo": labels must start with a'
                " letter and after that may contain alphanumerics, underscores,"
                " minuses, colons, periods, or slashes. Alternatively, labels"
                ' may be of the form "percent(x)" where x is a float between'
                " 0-100 inclusive."
            ),
        ],
    )


def test_override_label_guild_v2_9_label_percent_0_00_should_pass() raises:
    # @override(label:) > guild > v2.9 > label: "percent(0.00)" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(0.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_label_percent_1_00_should_pass() raises:
    # @override(label:) > guild > v2.9 > label: "percent(1.00)" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(1.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_label_percent_1_12345678_should_pass() raises:
    # @override(label:) > guild > v2.9 > label: "percent(1.12345678)" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(1.12345678)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_label_percent_100_00_should_pass() raises:
    # @override(label:) > guild > v2.9 > label: "percent(100.00)" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label:'
                    ' "percent(100.00)")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_label_foo_should_pass() raises:
    # @override(label:) > guild > v2.9 > label: "foo" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_label_foo_bar_should_pass() raises:
    # @override(label:) > guild > v2.9 > label: "foo_bar" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "foo_bar")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_label_percent1_should_pass() raises:
    # @override(label:) > guild > v2.9 > label: "percent1" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "percent1")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_label_f0_should_pass() raises:
    # @override(label:) > guild > v2.9 > label: "f0" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f0")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_label_f_should_pass() raises:
    # @override(label:) > guild > v2.9 > label: "f_" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f_")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_label_f_should_pass_2() raises:
    # @override(label:) > guild > v2.9 > label: "f-" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f-")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_label_f_should_pass_3() raises:
    # @override(label:) > guild > v2.9 > label: "f:" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f:")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_label_f_should_pass_4() raises:
    # @override(label:) > guild > v2.9 > label: "f." should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f.")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_label_f_should_pass_5() raises:
    # @override(label:) > guild > v2.9 > label: "f/" should pass
    check(
        [
            sg(
                "foo",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  foo:'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID\n '
                    ' name: String @override(from: "bar", label: "f/")\n}'
                ),
            ),
            sg(
                "bar",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key"])\n\ntype Query {\n  bar: User\n}\n\ntype User'
                    ' @key(fields: "id") {\n  id: ID\n  name: String\n}'
                ),
            ),
        ],
        [],
    )


def test_override_label_guild_v2_9_should_detect_unsatisfiable_paths() raises:
    # @override(label:) > guild > v2.9 > should detect unsatisfiable paths
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  user(id: ID!):'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' group: Group @override(from: "b")\n}\n\ntype Group'
                    ' @key(fields: "id") {\n  id: ID!\n  level: Int\n}'
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@requires", "@external", "@override"])\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  group: Group!\n '
                    ' groupLevel: ID! @requires(fields: "group { level'
                    ' }")\n}\n\ntype Group @key(fields: "id") {\n  id: ID\n '
                    " level: Int @external\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@override"])\n\ntype Query {\n  user(id: ID!):'
                    ' User\n}\n\ntype User @key(fields: "id") {\n  id: ID!\n '
                    ' group: Group @override(from: "b", label:'
                    ' "public")\n}\n\ntype Group @key(fields: "id") {\n  id:'
                    " ID!\n  level: Int\n}"
                ),
            ),
            sg(
                "b",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@requires", "@external", "@override"])\n\ntype'
                    ' User @key(fields: "id") {\n  id: ID!\n  group: Group!\n '
                    ' groupLevel: ID! @requires(fields: "group { level'
                    ' }")\n}\n\ntype Group @key(fields: "id") {\n  id: ID\n '
                    " level: Int @external\n}"
                ),
            ),
        ],
        [],
    )


comptime _V27 = (
    "extend schema @link(url:"
    ' "https://specs.apollo.dev/federation/v2.7", import: ["@key",'
    ' "@override", "@requires", "@external", "@shareable"])\n\n'
)


def test_label_from_unknown_subgraph() raises:
    # The source subgraph does not exist, so the rule has nothing to check.
    check(
        [
            sg(
                "a",
                String(_V27)
                + 'type Query {\n  t: T\n}\n\ntype T @key(fields: "id") {\n'
                + '  id: ID!\n  f: String @override(from: "nope", label:'
                + ' "percent(50)")\n}',
            ),
        ],
        [],
    )


def test_label_from_subgraph_without_the_field() raises:
    # Subgraph "b" has the type but not the field.
    check(
        [
            sg(
                "a",
                String(_V27)
                + 'type Query {\n  t: T\n}\n\ntype T @key(fields: "id") {\n'
                + '  id: ID!\n  f: String @override(from: "b", label:'
                + ' "percent(50)")\n}',
            ),
            sg(
                "b",
                String(_V27)
                + 'type T @key(fields: "id") {\n  id: ID!\n  g: String\n}',
            ),
            sg(
                "c",
                String(_V27)
                + 'type T @key(fields: "id") {\n  id: ID!\n'
                + "  f: String @shareable\n}",
            ),
        ],
        [
            (
                '[INVALID_FIELD_SHARING] Non-shareable field "T.f" is'
                " resolved from multiple subgraphs: it is resolved from"
                ' subgraphs "a" and "c" and defined as non-shareable in'
                ' subgraph "a"'
            ),
        ],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
