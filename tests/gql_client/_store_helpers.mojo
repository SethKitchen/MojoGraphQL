# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the entity store tests."""

from gql_client.cache import InMemoryCache, KeyFieldsContext
from gql_client.values import ValueKind

from _helpers import gql, json, text_of


def js_text(mut context: KeyFieldsContext, value: Int) -> String:
    """Return a value as JavaScript `"" + value` gives it."""
    ref values = context.cache[].values
    var kind = values.kind(value)
    if kind == ValueKind.STRING or kind == ValueKind.NUMBER:
        return String(values.text(value))
    if kind == ValueKind.UNDEFINED:
        return "undefined"
    if kind == ValueKind.NULL:
        return "null"
    if kind == ValueKind.TRUE:
        return "true"
    if kind == ValueKind.FALSE:
        return "false"
    return "[object Object]"


def book_author_id(mut context: KeyFieldsContext) raises -> String:
    """The `dataIdFromObject` of `newBookAuthorCache` in entityStore.ts:
    `Book:` + isbn for a Book, `Author:` + name for an Author."""
    ref values = context.cache[].values
    var typename = context.field("__typename")
    if values.kind(typename) != ValueKind.STRING:
        return ""
    var name = String(values.text(typename))
    if name == "Book":
        return "Book:" + js_text(context, context.field("isbn"))
    if name == "Author":
        return "Author:" + js_text(context, context.field("name"))
    return ""


def ids_text(ids: List[String]) -> String:
    """Return a list of ids as a JSON array text."""
    var out = String("[")
    var index = 0
    while index < len(ids):
        if index > 0:
            out += ","
        out += '"' + ids[index].replace("\\", "\\\\").replace('"', '\\"') + '"'
        index += 1
    return out + "]"


def sorted_ids_text(var ids: List[String]) -> String:
    """Return a list of ids, sorted, as a JSON array text."""
    var position = 1
    while position < len(ids):
        var back = position
        while back > 0 and ids[back] < ids[back - 1]:
            ids.swap_elements(back, back - 1)
            back -= 1
        position += 1
    return ids_text(ids)


def gc_text(mut cache: InMemoryCache) raises -> String:
    """Run `gc` and return the removed ids as JSON text."""
    return ids_text(cache.gc())


def diff_text(
    mut cache: InMemoryCache,
    query: StringSlice,
    variables: StringSlice = "{}",
    return_partial_data: Bool = True,
) raises -> String:
    """Return a diff as `complete result | message | tree` text."""
    var diff = cache.diff(
        gql(query), json(variables), "ROOT_QUERY", return_partial_data
    )
    var text = String(diff.complete) + " "
    if diff.result:
        text += text_of(diff.result.value())
    else:
        text += "null"
    if diff.missing:
        text += (
            " | "
            + diff.missing.value().message
            + " | "
            + text_of(diff.missing.value().missing)
        )
    return text^
