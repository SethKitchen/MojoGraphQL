# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Detect supergraph specification text in SDL.

Port of Hive Federation Composition v0.27.0
`src/graphql/contains-supergraph-spec.ts`. A spec name matches after
whitespace or `[`. `@core`, `@join__owner`, `@join__directive`, and
`@context` match as directives.

**Differences from upstream.** None. Upstream compares definition kinds
with `Kind.DIRECTIVE`, and the spec nodes are definitions, so `@join__field`
and `@link` do not match.
"""


def contains_supergraph_spec(sdl: String) -> Bool:
    """Return True when SDL contains a supergraph specification name.

    Args:
        sdl: A GraphQL document.

    Returns:
        Whether the text contains a supergraph spec name.
    """
    var names = _spec_names()
    var index = 0
    while index < len(names):
        if _preceded(sdl, names[index]):
            return True
        index += 1
    if sdl.find("@core") != -1:
        return True
    if sdl.find("@join__owner") != -1:
        return True
    if sdl.find("@join__directive") != -1:
        return True
    return sdl.find("@context") != -1


def _spec_names() -> List[String]:
    """Return the spec names Hive searches for, without `@`.

    Returns:
        The names from the latest supergraph specification SDL, plus
        `_FieldSet` and `join__DirectiveArguments`.
    """
    var names = List[String]()
    names.append("authenticated")
    names.append("context")
    names.append("context__fromContext")
    names.append("context__ContextFieldValue")
    names.append("cost")
    names.append("listSize")
    names.append("inaccessible")
    names.append("join__enumValue")
    names.append("join__graph")
    names.append("join__field")
    names.append("join__ContextArgument")
    names.append("join__implements")
    names.append("join__type")
    names.append("join__unionMember")
    names.append("join__FieldSet")
    names.append("join__FieldValue")
    names.append("link")
    names.append("link__Import")
    names.append("link__Purpose")
    names.append("policy")
    names.append("policy__Policy")
    names.append("requiresScopes")
    names.append("requiresScopes__Scope")
    names.append("tag")
    names.append("_FieldSet")
    names.append("join__DirectiveArguments")
    return names^


def _preceded(sdl: String, name: String) -> Bool:
    """Return True when `name` follows whitespace or `[`.

    Args:
        sdl: The document text.
        name: A specification name.

    Returns:
        Whether the name occurs in that position.
    """
    var bytes = sdl.as_bytes()
    var at = _find_from(sdl, name, 0)
    while at != -1:
        if at > 0:
            var prev = bytes[at - 1]
            if prev == 91 or _space(prev):
                return True
        at = _find_from(sdl, name, at + 1)
    return False


def _find_from(text: String, needle: String, start: Int) -> Int:
    """Return the next index of `needle` at or after `start`.

    Args:
        text: The text to search.
        needle: The text to find.
        start: The first byte index to search. It must be in
            `[0, text.byte_length()]`.

    Returns:
        The byte index, or -1.
    """
    var rest = String(text[byte=start:])
    var at = rest.find(needle)
    if at == -1:
        return -1
    return start + at


def _space(byte: UInt8) -> Bool:
    """Return True for JavaScript regex whitespace in ASCII.

    Args:
        byte: One byte.

    Returns:
        Whether `\\s` matches the byte.
    """
    return (
        byte == 9
        or byte == 10
        or byte == 11
        or byte == 12
        or byte == 13
        or byte == 32
    )
