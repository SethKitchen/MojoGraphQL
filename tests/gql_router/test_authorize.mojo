# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_router.authorize` and of authorization in the router
pipeline. Hive Router has no ported suite for the pipeline step; the cases
follow `apply_authorization_to_operation`."""

from _auth_supergraph import auth_sdl
from gql_json.value import NO_NODE, JsonDocument
from gql_language.parser import parse
from gql_router.authorization import UserAuth
from gql_router.authorize import (
    AuthRules,
    DeniedElements,
    anonymous,
    denied_elements,
)
from gql_router.exec_http import CannedTransport
from gql_router.pipeline import Router, RouterSchema
from std.testing import TestSuite, assert_equal, assert_false, assert_true

comptime DENIED = (
    '{"message":"Unauthorized field or type","extensions":'
    + '{"code":"UNAUTHORIZED_FIELD_OR_TYPE","affectedPath":"'
)
"""The start of the error of a denied field, before its path."""


def _router(var transport: CannedTransport) raises -> Router[CannedTransport]:
    return Router(RouterSchema(auth_sdl()), transport^)


def _run(
    mut router: Router[CannedTransport],
    query: String,
    user: UserAuth = anonymous(),
) -> String:
    var response = router.execute(
        query, None, JsonDocument(), NO_NODE, False, True, user
    )
    return String(unsafe_from_utf8=response^.take_body())


def _sent(router: Router[CannedTransport]) -> String:
    var out = String()
    for ref request in router.executor.transport.requests:
        out += request + "\n"
    return out^


def test_rules_are_read_from_the_supergraph() raises:
    var rules = AuthRules.from_supergraph(parse(auth_sdl()))
    assert_false(rules.is_empty())
    assert_true(rules.types["Card"].authenticated)
    assert_true(rules.fields["Query.secret"].authenticated)
    assert_true(rules.fields["User.email"].authenticated)
    ref admin = rules.fields["Query.admin"]
    assert_true(admin.has_scopes)
    assert_equal(len(admin.scope_groups), 2)
    assert_equal(admin.scope_groups[0][1], "write")
    assert_equal(admin.scope_groups[1][0], "root")
    assert_true(rules.fields["Query.audited"].has_policies)
    assert_true("Query.me" not in rules.fields)
    assert_true(
        AuthRules.from_supergraph(parse("type Q { a: Int }")).is_empty()
    )


def test_a_type_and_its_extension_join_their_rules() raises:
    var rules = AuthRules.from_supergraph(
        parse(
            'type T @requiresScopes(scopes: [["a"]]) { f: Int }'
            + ' extend type T @policy(policies: ["p", ["q", "r"]])'
            + ' @authenticated @requiresScopes(scopes: [["b"]])'
            + " @other @policy(policies: 3)"
            + " extend type T @authenticated"
            + " type U { f: Int @requiresScopes @policy(other: 1, policies:"
            " [[1], 2]) }"
        )
    )
    ref rule = rules.types["T"]
    assert_true(rule.authenticated)
    assert_equal(len(rule.scope_groups), 2)
    # A bare string is a group of one, as input coercion makes it.
    assert_equal(len(rule.policy_groups), 2)
    assert_equal(rule.policy_groups[0][0], "p")
    assert_equal(rule.policy_groups[1][1], "r")
    # A missing argument, another argument and items that are not
    # strings give empty groups.
    ref field = rules.fields["U.f"]
    assert_true(field.has_scopes)
    assert_equal(len(field.scope_groups), 0)
    assert_equal(len(field.policy_groups), 2)
    assert_equal(len(field.policy_groups[0]), 0)


def test_what_a_request_cannot_see() raises:
    var rules = AuthRules.from_supergraph(parse(auth_sdl()))
    var nobody = denied_elements(rules, anonymous(), True)
    assert_true("Card" in nobody.types)
    assert_true("Query.secret" in nobody.fields)
    assert_true("Query.audited" in nobody.fields)
    assert_equal(
        nobody.signature,
        "Mutation.wipe,Query.admin,Query.audited,Query.secret,User.email,type"
        + " Card",
    )
    assert_true(nobody.field_denied("Query", "secret", "String"))
    assert_true(nobody.field_denied("Card", "number", "String"))
    assert_true(nobody.field_denied("User", "card", "Card"))
    assert_false(nobody.field_denied("User", "name", "String"))
    var everyone = denied_elements(
        rules, UserAuth(True, ["root"], ["audit"]), True
    )
    assert_true(everyone.is_empty())
    assert_false(everyone.field_denied("Query", "secret", "String"))
    # Without JWT rules, only `@policy` applies.
    var policy_only = denied_elements(rules, anonymous(), False)
    assert_equal(policy_only.signature, "Query.audited")
    assert_true(DeniedElements().is_empty())


def test_an_anonymous_request_gets_null_and_an_error() raises:
    var transport = CannedTransport(record=True)
    transport.add(
        "accounts",
        "{me{name}}",
        '{"data":{"me":{"name":"ada"},"secret":"LEAK"}}',
    )
    var router = _router(transport^)
    assert_equal(
        _run(router, "{ me { name } secret }"),
        '{"data":{"me":{"name":"ada"},"secret":null},"errors":['
        + DENIED
        + 'secret"}}]}',
    )
    assert_equal(_sent(router), '{"query":"{me{name}}"}\n')
    # `__typename` has no rule, and a fragment keeps its allowed fields.
    assert_true(
        '"__typename":"Query"'
        in _run(router, "{ __typename ... on Query { me { name } secret } }")
    )


def test_a_denied_non_null_field_makes_its_parent_null() raises:
    var transport = CannedTransport(record=True)
    transport.add(
        "accounts",
        "{me{name}}",
        '{"data":{"me":{"name":"ada","email":"LEAK"}}}',
    )
    var router = _router(transport^)
    assert_equal(
        _run(router, "{ me { name email } }"),
        '{"data":{"me":null},"errors":[' + DENIED + 'me.email"}}]}',
    )


def test_a_denied_type_and_an_empty_selection_set() raises:
    var transport = CannedTransport(record=True)
    transport.add(
        "accounts", "{me{__typename}}", '{"data":{"me":{"__typename":"User"}}}'
    )
    var router = _router(transport^)
    # `card` has the denied type `Card`; `me` keeps `__typename` for the
    # subgraph, and the client does not see it.
    assert_equal(
        _run(router, "{ me { card { number } } }"),
        '{"data":{"me":{"card":null}},"errors":[' + DENIED + 'me.card"}}]}',
    )
    # A fragment on the denied type goes too.
    assert_true(
        DENIED + 'me.card"'
        in _run(router, "{ me { card { ... on Card { number } } } }")
    )


def test_a_request_with_only_denied_fields_sends_nothing() raises:
    var router = _router(CannedTransport(record=True))
    assert_equal(
        _run(router, "{ secret ... on Query { admin } }"),
        '{"data":{"secret":null,"admin":null},"errors":['
        + DENIED
        + 'secret"}},'
        + DENIED
        + 'admin"}}]}',
    )
    assert_equal(_sent(router), "")


def test_a_denied_mutation_field_does_not_run() raises:
    var transport = CannedTransport(record=True)
    transport.add("accounts", "mutation{ping}", '{"data":{"ping":true}}')
    var router = _router(transport^)
    assert_equal(
        _run(router, "mutation { wipe ping }"),
        '{"data":{"wipe":null,"ping":true},"errors":[' + DENIED + 'wipe"}}]}',
    )
    assert_equal(_sent(router), '{"query":"mutation{ping}"}\n')


def test_an_authorized_request_sees_everything() raises:
    var transport = CannedTransport(record=True)
    transport.add(
        "accounts",
        "{secret admin audited}",
        '{"data":{"secret":"s","admin":"a","audited":"u"}}',
    )
    var router = _router(transport^)
    var query = String("{ secret admin audited }")
    var user = UserAuth(True, ["admin", "write"], ["audit"])
    assert_equal(
        _run(router, query, user),
        '{"data":{"secret":"s","admin":"a","audited":"u"}}',
    )
    # The cached plan of the authorized request is not reused for an
    # anonymous one.
    assert_equal(
        _run(router, query),
        '{"data":{"secret":null,"admin":null,"audited":null},"errors":['
        + DENIED
        + 'secret"}},'
        + DENIED
        + 'admin"}},'
        + DENIED
        + 'audited"}}]}',
    )


def test_jwt_rules_can_be_turned_off() raises:
    var transport = CannedTransport(record=True)
    transport.add("accounts", "{secret}", '{"data":{"secret":"s"}}')
    var router = _router(transport^)
    router.enforce_jwt = False
    assert_equal(
        _run(router, "{ secret audited }"),
        '{"data":{"secret":"s","audited":null},"errors":['
        + DENIED
        + 'audited"}}]}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
