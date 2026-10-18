# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Mask a subgraph error before it reaches the client.

Port of `ErrorMaskingRuntime::apply` in Hive Router `1a29df9`
`bin/router/src/executor/execution/error_masking.rs`.

Masking runs only when the error names a service. The message uses the
subgraph rule, or the default when that subgraph is not listed. An allow
list keeps `code`, `service`, `affectedPath`, and the other named
extension keys. A deny list removes those names.

**Differences from upstream.** Extension values are strings. The config
compiler is not in this module. The caller passes the resolved rules.
"""


@fieldwise_init
struct MaskPlanKind(Equatable, ImplicitlyCopyable, Movable):
    """How extension keys are masked."""

    var value: UInt8
    """The kind's index. See `is_valid`."""

    comptime NONE = MaskPlanKind(0)
    """Do not change extension keys."""
    comptime ALLOW = MaskPlanKind(1)
    """Keep only the named keys."""
    comptime DENY = MaskPlanKind(2)
    """Remove the named keys."""

    def is_valid(self) -> Bool:
        """Return True when the value names one of the three plans.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2


@fieldwise_init
struct MessageMask(Copyable, Movable):
    """One subgraph's message rule."""

    var service: String
    """The subgraph name."""
    var enabled: Bool
    """True when that subgraph's message is replaced."""


@fieldwise_init
struct ExtensionPlan(Copyable, Movable):
    """One subgraph's extension rule."""

    var service: String
    """The subgraph name."""
    var kind: MaskPlanKind
    """Allow or deny."""
    var keys: List[String]
    """The extension names. `code`, `service`, and `affectedPath` are special."""


@fieldwise_init
struct MaskedError(Copyable, Movable):
    """One GraphQL error after masking."""

    var message: String
    """The error message."""
    var code: String
    """The `code` extension. Empty when it is absent."""
    var service: String
    """The `service` extension. Empty when it is absent."""
    var affected_path: String
    """The `affectedPath` extension. Empty when it is absent."""
    var extra_names: List[String]
    """Other extension names, in order."""
    var extra_values: List[String]
    """Other extension values, parallel to `extra_names`."""


def mask_error(
    error: MaskedError,
    redacted: String,
    default_mask: Bool,
    message_masks: List[MessageMask],
    default_plan: MaskPlanKind,
    default_keys: List[String],
    extension_plans: List[ExtensionPlan],
) -> MaskedError:
    """Apply the masking rules to one error.

    Args:
        error: The error from a subgraph.
        redacted: The message that replaces a masked message.
        default_mask: True when a subgraph with no message rule is masked.
        message_masks: The subgraph message rules.
        default_plan: The extension plan for a subgraph with no plan.
        default_keys: The keys of `default_plan`.
        extension_plans: The subgraph extension plans.

    Returns:
        The error the client can see. An error with no service is unchanged.
    """
    if error.service.byte_length() == 0:
        return error.copy()
    var message = String(error.message)
    if _message_masked(error.service, default_mask, message_masks):
        message = String(redacted)
    var code = String(error.code)
    var service = String(error.service)
    var affected_path = String(error.affected_path)
    var names = List[String]()
    var values = List[String]()
    _copy_extras(error.extra_names, error.extra_values, names, values)
    var plan_index = _plan_index(error.service, extension_plans)
    if plan_index >= 0:
        _apply_plan(
            extension_plans[plan_index].kind,
            extension_plans[plan_index].keys,
            code,
            service,
            affected_path,
            names,
            values,
        )
    else:
        _apply_plan(
            default_plan,
            default_keys,
            code,
            service,
            affected_path,
            names,
            values,
        )
    return MaskedError(
        message^, code^, service^, affected_path^, names^, values^
    )


def _message_masked(
    service: String, default_mask: Bool, message_masks: List[MessageMask]
) -> Bool:
    """Return True when this service's message is replaced.

    Args:
        service: The subgraph name.
        default_mask: The rule for a subgraph that is not listed.
        message_masks: The subgraph message rules.

    Returns:
        Whether the message is replaced.
    """
    for index in range(len(message_masks)):
        if message_masks[index].service == service:
            return message_masks[index].enabled
    return default_mask


def _plan_index(service: String, plans: List[ExtensionPlan]) -> Int:
    """Return the extension plan of one service.

    Args:
        service: The subgraph name.
        plans: The subgraph extension plans.

    Returns:
        The plan index. `-1` when the service is not listed.
    """
    for index in range(len(plans)):
        if plans[index].service == service:
            return index
    return -1


def _apply_plan(
    kind: MaskPlanKind,
    keys: List[String],
    mut code: String,
    mut service: String,
    mut affected_path: String,
    mut names: List[String],
    mut values: List[String],
):
    """Apply one allow list or deny list.

    Args:
        kind: Allow, deny, or none.
        keys: The extension names.
        code: The `code` extension.
        service: The `service` extension.
        affected_path: The `affectedPath` extension.
        names: The other extension names.
        values: The other extension values.
    """
    if kind == MaskPlanKind.ALLOW:
        _allow(keys, code, service, affected_path, names, values)
    elif kind == MaskPlanKind.DENY:
        _deny(keys, code, service, affected_path, names, values)


def _allow(
    keys: List[String],
    mut code: String,
    mut service: String,
    mut affected_path: String,
    mut names: List[String],
    mut values: List[String],
):
    """Keep only the named extension keys.

    Args:
        keys: The names to keep.
        code: The `code` extension.
        service: The `service` extension.
        affected_path: The `affectedPath` extension.
        names: The other extension names.
        values: The other extension values.
    """
    if not _listed(keys, "code"):
        code = String("")
    if not _listed(keys, "service"):
        service = String("")
    if not _listed(keys, "affectedPath"):
        affected_path = String("")
    var kept_names = List[String]()
    var kept_values = List[String]()
    var limit = len(names)
    if len(values) < limit:
        limit = len(values)
    for index in range(limit):
        if not _other_key(keys, names[index]):
            continue
        kept_names.append(String(names[index]))
        kept_values.append(String(values[index]))
    names = kept_names^
    values = kept_values^


def _deny(
    keys: List[String],
    mut code: String,
    mut service: String,
    mut affected_path: String,
    mut names: List[String],
    mut values: List[String],
):
    """Remove the named extension keys.

    Args:
        keys: The names to remove.
        code: The `code` extension.
        service: The `service` extension.
        affected_path: The `affectedPath` extension.
        names: The other extension names.
        values: The other extension values.
    """
    for index in range(len(keys)):
        var key = String(keys[index])
        if key == "code":
            code = String("")
        elif key == "service":
            service = String("")
        elif key == "affectedPath":
            affected_path = String("")
        else:
            _remove_extra(names, values, key)


def _other_key(keys: List[String], name: String) -> Bool:
    """Return True when `name` is an allowed extra key.

    Args:
        keys: The allow list.
        name: The extra extension name.

    Returns:
        Whether `name` is listed and is not `code`, `service`, or
        `affectedPath`.
    """
    if name == "code" or name == "service" or name == "affectedPath":
        return False
    return _listed(keys, name)


def _remove_extra(
    mut names: List[String], mut values: List[String], key: String
):
    """Remove every extra entry named `key`.

    Args:
        names: The extra extension names.
        values: The extra extension values.
        key: The name to remove.
    """
    var kept_names = List[String]()
    var kept_values = List[String]()
    var limit = len(names)
    if len(values) < limit:
        limit = len(values)
    for index in range(limit):
        if names[index] == key:
            continue
        kept_names.append(String(names[index]))
        kept_values.append(String(values[index]))
    names = kept_names^
    values = kept_values^


def _copy_extras(
    names: List[String],
    values: List[String],
    mut copied_names: List[String],
    mut copied_values: List[String],
):
    """Copy extra extension pairs.

    Args:
        names: The extra extension names.
        values: The extra extension values.
        copied_names: The destination names.
        copied_values: The destination values.
    """
    var limit = len(names)
    if len(values) < limit:
        limit = len(values)
    for index in range(limit):
        copied_names.append(String(names[index]))
        copied_values.append(String(values[index]))


def _listed(keys: List[String], name: String) -> Bool:
    """Return True when a name is in the list.

    Args:
        keys: The names.
        name: The candidate.

    Returns:
        Whether `name` is present.
    """
    for index in range(len(keys)):
        if keys[index] == name:
            return True
    return False
