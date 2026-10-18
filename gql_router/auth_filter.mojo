# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Which fields of an operation survive authorization.

Port of the field decision in `apply_authorization_to_operation` in Hive
Router `1a29df9` `bin/router/src/pipeline/authorization/mod.rs`.

A field stays when its parent type, the field, and its output type are
all allowed. A parent type marked as having no authorization rules keeps
its fields without a check. When a field is removed and reject mode is
on, the whole operation is rejected. An authenticated request is
unchanged when the schema has no scopes and no policies.

**Differences from upstream.** This module reports the field that
authorization denied. `gql_router.null_bubble` then removes each ancestor
up to the nearest nullable field.
"""


@fieldwise_init
struct AuthField(Copyable, Movable):
    """One field selection to authorize."""

    var parent_type: String
    """The parent type."""
    var field_name: String
    """The field name."""
    var output_type: String
    """The named output type."""


@fieldwise_init
struct AuthDecision(Copyable, Movable):
    """The result of authorizing one operation."""

    var kind: Int
    """`0` when nothing changes, `1` when fields are removed, and `2`
    when the operation is rejected."""
    var kept: List[String]
    """The field names that stay, in source order. Empty for no change
    and for a rejection."""


def authorize_fields(
    rules_empty: Bool,
    user_authenticated: Bool,
    schema_has_scopes: Bool,
    schema_has_policies: Bool,
    reject_mode: Bool,
    fields: List[AuthField],
    denied_types: List[String],
    denied_field_types: List[String],
    denied_field_names: List[String],
    parents_without_auth: List[String],
) -> AuthDecision:
    """Return how an operation changes after authorization.

    Args:
        rules_empty: Whether the schema has no authorization rules.
        user_authenticated: Whether the request has a validated identity.
        schema_has_scopes: Whether the schema uses `@requiresScopes`.
        schema_has_policies: Whether the schema uses `@policy`.
        reject_mode: Whether an unauthorized field rejects the operation.
        fields: The field selections, in source order.
        denied_types: Types the request is not allowed to see.
        denied_field_types: The parent type of each denied field. Parallel
            to `denied_field_names`.
        denied_field_names: The denied field names.
        parents_without_auth: Parent types whose fields are not checked.

    Returns:
        No change, a filtered field list, or a rejection.
    """
    var kept = List[String]()
    if rules_empty:
        return AuthDecision(0, kept^)
    if user_authenticated and not schema_has_scopes and not schema_has_policies:
        return AuthDecision(0, kept^)
    var removed = False
    for index in range(len(fields)):
        ref field = fields[index]
        if _listed(parents_without_auth, field.parent_type):
            kept.append(String(field.field_name))
            continue
        var denied = (
            _listed(denied_types, field.parent_type)
            or _listed(denied_types, field.output_type)
            or _pair(
                denied_field_types,
                denied_field_names,
                field.parent_type,
                field.field_name,
            )
        )
        if denied:
            removed = True
            continue
        kept.append(String(field.field_name))
    if not removed:
        var empty = List[String]()
        return AuthDecision(0, empty^)
    if reject_mode:
        var empty = List[String]()
        return AuthDecision(2, empty^)
    return AuthDecision(1, kept^)


def _listed(names: List[String], name: String) -> Bool:
    """Return True when a name is in a list.

    Args:
        names: The names.
        name: The candidate.

    Returns:
        Whether `name` is present.
    """
    for index in range(len(names)):
        if names[index] == name:
            return True
    return False


def _pair(
    types: List[String],
    fields: List[String],
    type_name: String,
    field_name: String,
) -> Bool:
    """Return True when a type and field pair is listed.

    Args:
        types: The parent types. Parallel to `fields`.
        fields: The field names.
        type_name: The parent type to find.
        field_name: The field to find.

    Returns:
        Whether the pair is present.
    """
    var limit = len(types)
    if len(fields) < limit:
        limit = len(fields)
    for index in range(limit):
        if types[index] == type_name and fields[index] == field_name:
            return True
    return False
