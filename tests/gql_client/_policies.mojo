# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Policy functions that the upstream tests define inline."""

from gql_client.cache import KeyFieldsContext
from gql_client.values import ValueKind


def typename_id(mut context: KeyFieldsContext) raises -> String:
    """The test-level `dataIdFromObject` of writeToStore.ts:
    `__typename + "__" + id` when both are truthy."""
    ref values = context.cache[].values
    var typename = context.field("__typename")
    var id = context.field("id")
    if values.truthy(typename) and values.truthy(id):
        return String(_text(context, typename), "__", _text(context, id))
    return ""


def get_id_field(mut context: KeyFieldsContext) raises -> String:
    """`getIdField` of writeToStore.ts: the `id`, which must be a string."""
    var id = context.field("id")
    ref values = context.cache[].values
    if values.kind(id) != ValueKind.STRING:
        raise Error("id is not a string")
    return String(values.text(id))


def _text(mut context: KeyFieldsContext, value: Int) -> String:
    """Return a value as a JavaScript template string shows a scalar."""
    ref values = context.cache[].values
    var kind = values.kind(value)
    if kind == ValueKind.STRING or kind == ValueKind.NUMBER:
        return String(values.text(value))
    return values.stringify(value)
