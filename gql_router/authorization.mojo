# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Whether a request satisfies `@authenticated`, `@requiresScopes`, and
`@policy`.

Port of `is_rule_satisfied` in Hive Router `1a29df9`
`bin/router/src/pipeline/authorization/mod.rs`.

Scopes and policies are an OR of AND groups. One group matches when the
request holds every name in that group. An empty group matches. JWT rules
(`@authenticated` and `@requiresScopes`) apply only when enforcement is
on. `@policy` always applies. A field or type with no rule is allowed.
"""


@fieldwise_init
struct AuthRule(Copyable, Movable):
    """The authorization directives on one type or field."""

    var authenticated: Bool
    """Whether `@authenticated` is present."""
    var has_scopes: Bool
    """Whether `@requiresScopes` is present."""
    var scope_groups: List[List[String]]
    """The scope groups. Each inner list must all hold."""
    var has_policies: Bool
    """Whether `@policy` is present."""
    var policy_groups: List[List[String]]
    """The policy groups. Each inner list must all hold."""


@fieldwise_init
struct UserAuth(Copyable, Movable):
    """What the request has been granted."""

    var authenticated: Bool
    """Whether the request has a validated identity."""
    var scopes: List[String]
    """The granted scope names."""
    var policies: List[String]
    """The granted policy names."""


def authorization_allows(
    rule: AuthRule, user: UserAuth, enforce_jwt: Bool
) -> Bool:
    """Return True when the request satisfies one authorization rule.

    Args:
        rule: The directives on the schema element.
        user: The identity, scopes, and policies of the request.
        enforce_jwt: Whether `@authenticated` and `@requiresScopes` apply.

    Returns:
        Whether the element may be planned for this request.
    """
    if enforce_jwt:
        if rule.authenticated and not user.authenticated:
            return False
        if rule.has_scopes and not _any_group(rule.scope_groups, user.scopes):
            return False
    if rule.has_policies and not _any_group(rule.policy_groups, user.policies):
        return False
    return True


def element_authorized(
    has_rule: Bool, rule: AuthRule, user: UserAuth, enforce_jwt: Bool
) -> Bool:
    """Return True when a type or field may be planned.

    Args:
        has_rule: Whether the element has an authorization directive.
        rule: The directives. Ignored when `has_rule` is false.
        user: The identity, scopes, and policies of the request.
        enforce_jwt: Whether `@authenticated` and `@requiresScopes` apply.

    Returns:
        Whether the element is authorized. An element with no rule is
        authorized.
    """
    if not has_rule:
        return True
    return authorization_allows(rule, user, enforce_jwt)


def _any_group(groups: List[List[String]], owned: List[String]) -> Bool:
    """Return True when one group is fully granted.

    Args:
        groups: The AND groups.
        owned: The names the request holds.

    Returns:
        Whether any group matches. No groups do not match. An empty group
        matches.
    """
    var matched = False
    for index in range(len(groups)):
        if _all_present(groups[index], owned):
            matched = True
    return matched


def _all_present(required: List[String], owned: List[String]) -> Bool:
    """Return True when every required name is granted.

    Args:
        required: The names in one group.
        owned: The names the request holds.

    Returns:
        Whether the group is fully granted.
    """
    for index in range(len(required)):
        var found = False
        for owned_index in range(len(owned)):
            if required[index] == owned[owned_index]:
                found = True
        if not found:
            return False
    return True
