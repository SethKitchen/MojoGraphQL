# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Policy functions that the upstream cache.ts tests define inline."""

from gql_client.cache import KeyFieldsContext
from gql_client.values import ValueKind


def object_id(mut context: KeyFieldsContext) raises -> String:
    """`dataIdFromObject: (o) => o.id`, as `String(id)` of identify."""
    ref values = context.cache[].values
    var id = context.field("id")
    var kind = values.kind(id)
    if kind == ValueKind.STRING or kind == ValueKind.NUMBER:
        return String(values.text(id))
    if kind == ValueKind.NULL or kind == ValueKind.UNDEFINED:
        return ""
    return values.stringify(id)
