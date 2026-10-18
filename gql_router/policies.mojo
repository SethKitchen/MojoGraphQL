# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `@policy` names an operation depends on.

Port of `collect_required_policies` in Hive Router `1a29df9`
`bin/router/src/pipeline/authorization/mod.rs`.

A field contributes the policies of its parent type, of the field, and of
its output type. A fragment contributes the policies of its type
condition. The result is empty when authorization directives are off or
the schema has no `@policy`.

**Differences from upstream.** Upstream returns a hash set, so the order
is unspecified. This port keeps the first time each policy is seen.
"""


@fieldwise_init
struct AuthVisit(Copyable, Movable):
    """One selection the policy walk observes."""

    var is_fragment: Bool
    """Whether this selection is a fragment rather than a field."""
    var parent_type: String
    """The parent type of a field. Empty for a fragment."""
    var field_name: String
    """The field name. Empty for a fragment."""
    var output_type: String
    """The named output type of a field. Empty for a fragment."""
    var type_condition: String
    """The type condition of a fragment. Empty for a field."""


@fieldwise_init
struct PolicyBinding(Copyable, Movable):
    """One policy required by a type or a field."""

    var type_name: String
    """The type that carries the policy, or the parent of a field."""
    var field_name: String
    """The field name. Empty when the policy is on the type."""
    var policy: String
    """The policy name."""


def collect_required_policies(
    enabled: Bool,
    schema_has_policies: Bool,
    visits: List[AuthVisit],
    bindings: List[PolicyBinding],
) -> List[String]:
    """Return the policy names the operation depends on.

    Args:
        enabled: Whether authorization directives are turned on.
        schema_has_policies: Whether the schema uses `@policy`.
        visits: The selections in the operation, in walk order.
        bindings: The policies on types and fields.

    Returns:
        The policy names, in first-seen order. Empty when directives are
        off or the schema has no `@policy`.
    """
    var required = List[String]()
    if not enabled or not schema_has_policies:
        return required^
    for index in range(len(visits)):
        ref visit = visits[index]
        if visit.is_fragment:
            _collect_type(bindings, visit.type_condition, required)
            continue
        _collect_type(bindings, visit.parent_type, required)
        _collect_field(bindings, visit.parent_type, visit.field_name, required)
        _collect_type(bindings, visit.output_type, required)
    return required^


def _collect_type(
    bindings: List[PolicyBinding], type_name: String, mut required: List[String]
):
    """Add the policies attached directly to a type.

    Args:
        bindings: The policies on types and fields.
        type_name: The type.
        required: Receives each new policy name.
    """
    for index in range(len(bindings)):
        ref binding = bindings[index]
        if (
            binding.field_name.byte_length() > 0
            or binding.type_name != type_name
        ):
            continue
        _add(required, binding.policy)


def _collect_field(
    bindings: List[PolicyBinding],
    type_name: String,
    field_name: String,
    mut required: List[String],
):
    """Add the policies attached to one field.

    Args:
        bindings: The policies on types and fields.
        type_name: The parent type.
        field_name: The field.
        required: Receives each new policy name.
    """
    for index in range(len(bindings)):
        ref binding = bindings[index]
        if binding.type_name != type_name or binding.field_name != field_name:
            continue
        _add(required, binding.policy)


def _add(mut required: List[String], policy: String):
    """Append a policy the first time it is seen.

    Args:
        required: The names already collected.
        policy: The candidate.
    """
    for index in range(len(required)):
        if required[index] == policy:
            return
    required.append(policy)
