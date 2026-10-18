# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of `test_compatibility.mojo`: the regular expressions of the
jest tests as ordered searches, and a port of `compareSchemas` of
`packages/compatibility/src/utils/schemaComparison.ts` of the Apollo
Federation subgraph compatibility suite (f9520a4, MIT)."""

from gql_language.ast import Document, Kind, Role
from gql_language.parser import parse
from _products import PRODUCTS_SDL


def _alternatives(pattern: String) -> List[String]:
    """Expand a pattern of literal text with `<a|b>` groups into every
    text it can match."""
    var out: List[String] = [""]
    var bytes = pattern.as_bytes()
    var index = 0
    while index < len(bytes):
        if bytes[index] == UInt8(ord("<")):
            var end = index + 1
            while bytes[end] != UInt8(ord(">")):
                end += 1
            var group = String(pattern[byte = index + 1 : end])
            var choices = List[String]()
            for ref part in group.split("|"):
                choices.append(String(part))
            var next = List[String]()
            for ref prefix in out:
                for ref choice in choices:
                    next.append(prefix + choice)
            out = next^
            index = end + 1
        else:
            var end = index
            while end < len(bytes) and bytes[end] != UInt8(ord("<")):
                end += 1
            var literal = String(pattern[byte=index:end])
            for ref prefix in out:
                prefix += literal
            index = end
    return out^


def matches(text: String, patterns: List[String]) -> Bool:
    """Return True when the text holds each pattern in order, with any
    text between them, as a regular expression `p1.*p2.*p3` on one line.

    Each pattern is literal text with `<a|b>` for `(a|b)`, and `<x|>`
    for `(x)?`. At each step the match that ends first is taken, which finds a
    match when one exists.

    Args:
        text: The text, with no line break.
        patterns: The patterns, in order.

    Returns:
        Whether the text matches.
    """
    var position = 0
    for ref pattern in patterns:
        var best = -1
        for ref choice in _alternatives(pattern):
            var found = text.find(choice, position)
            if found >= 0 and (best < 0 or found + choice.byte_length() < best):
                best = found + choice.byte_length()
        if best < 0:
            return False
        position = best
    return True


def links(sdl: String) -> List[String]:
    """Return the text of each `@link(...)` up to its first `)`, as the
    jest regular expression `/@link\\(([\\s\\S]+?)\\)/g`.

    Args:
        sdl: The SDL, with the ignored characters stripped.

    Returns:
        Each match, from `@link(` to `)`.
    """
    var out = List[String]()
    var position = 0
    while True:
        var start = sdl.find("@link(", position)
        if start < 0:
            return out^
        var end = sdl.find(")", start + 7)
        if end < 0:
            return out^
        out.append(String(sdl[byte = start : end + 1]))
        position = end + 1


def between(text: String, open: String, close: String) -> String:
    """Return the text after the first `open` up to the next `close`, as
    the jest regular expressions `url:(".+?")` and `import:\\[(.+?)\\]`.

    Args:
        text: The text.
        open: The text before the group.
        close: The text after the group.

    Returns:
        The group, or an empty string when there is none.
    """
    var start = text.find(open)
    if start < 0:
        return ""
    start += open.byte_length()
    var end = text.find(close, start + 1)
    if end < 0:
        return ""
    return String(text[byte=start:end])


def _find(document: Document, kind: Kind, name: String) -> List[Int]:
    """Return the definitions of a kind with a name."""
    var out = List[Int]()
    for definition in document.definitions():
        if (
            document.kind(definition) == kind
            and document.name(definition) == name
        ):
            out.append(definition)
    return out^


def _object(document: Document, name: String, extension: Bool) -> Int:
    """Return the first object type extension of a name when `extension`
    is set and there is one, or else the first definition; -1 for none."""
    if extension:
        var found = _find(document, Kind.OBJECT_TYPE_EXTENSION, name)
        if len(found) > 0:
            return found[0]
    var found = _find(document, Kind.OBJECT_TYPE_DEFINITION, name)
    return found[0] if len(found) > 0 else -1


def _unwrap(document: Document, type: Int) -> String:
    """Return the named type inside list and non-null types."""
    var kind = document.kind(type)
    if kind == Kind.NON_NULL_TYPE or kind == Kind.LIST_TYPE:
        return _unwrap(document, document.child(type, Role.TYPE))
    return String(document.name(type))


def _compare_node(
    parent: String,
    field: String,
    document: Document,
    actual: Int,
    reference: Document,
    expected: Int,
) -> String:
    """Port of `compareNode`: the nullability, the list and the name."""
    var errors = String()
    var expected_non_null = reference.kind(expected) == Kind.NON_NULL_TYPE
    var actual_non_null = document.kind(actual) == Kind.NON_NULL_TYPE
    if actual_non_null == expected_non_null:
        if expected_non_null:
            return _compare_node(
                parent,
                field,
                document,
                document.child(actual, Role.TYPE),
                reference,
                reference.child(expected, Role.TYPE),
            )
    elif expected_non_null:
        errors += "\n * " + parent + " defines different nullability for "
        errors += field + " field, expected non-nullable but was nullable"
        return errors + _compare_node(
            parent,
            field,
            document,
            actual,
            reference,
            reference.child(expected, Role.TYPE),
        )
    else:
        errors += "\n * " + parent + " defines different nullability for "
        errors += field + " field, expected nullable but was non-nullable"
        return errors + _compare_node(
            parent,
            field,
            document,
            document.child(actual, Role.TYPE),
            reference,
            expected,
        )
    var expected_list = reference.kind(expected) == Kind.LIST_TYPE
    var actual_list = document.kind(actual) == Kind.LIST_TYPE
    if actual_list == expected_list:
        if expected_list:
            return _compare_node(
                parent,
                field,
                document,
                document.child(actual, Role.TYPE),
                reference,
                reference.child(expected, Role.TYPE),
            )
    elif expected_list:
        errors += "\n * " + parent + " defines different return type for "
        errors += field + " field, was expecting a list return type"
        return errors + _compare_node(
            parent,
            field,
            document,
            actual,
            reference,
            reference.child(expected, Role.TYPE),
        )
    else:
        errors += "\n * " + parent + " defines different return type for "
        errors += field + " field, did not expect a list return type"
        return errors + _compare_node(
            parent,
            field,
            document,
            document.child(actual, Role.TYPE),
            reference,
            expected,
        )
    var expected_name = _unwrap(reference, expected)
    var actual_name = _unwrap(document, actual)
    if actual_name != expected_name:
        errors += "\n * " + parent + " defines different return type for "
        errors += field + " field, expected " + expected_name + " but was "
        errors += actual_name
    return errors


def _compare_arguments(
    field: String,
    document: Document,
    actual: Int,
    reference: Document,
    expected: Int,
) -> String:
    """Port of `compareArguments`."""
    var errors = String()
    for argument in reference.children(expected, Role.ARGUMENT):
        var name = String(reference.name(argument))
        var matched = -1
        for candidate in document.children(actual, Role.ARGUMENT):
            if matched < 0 and document.name(candidate) == name:
                matched = candidate
        if matched < 0:
            errors += "\n * " + field + " type does not declare " + name
            errors += " argument"
        else:
            errors += _compare_node(
                field,
                name,
                document,
                document.child(matched, Role.TYPE),
                reference,
                reference.child(argument, Role.TYPE),
            )
    return errors


def _compare_type_fields(
    type_name: String,
    document: Document,
    fields: List[Int],
    reference: Document,
    expected_fields: List[Int],
) -> String:
    """Port of `compareTypeFields`."""
    var errors = String()
    for expected in expected_fields:
        var name = String(reference.name(expected))
        var matched = -1
        for candidate in fields:
            if matched < 0 and document.name(candidate) == name:
                matched = candidate
        if matched < 0:
            errors += "\n * " + type_name + " type does not declare " + name
            errors += " field"
        else:
            errors += _compare_node(
                type_name,
                name,
                document,
                document.child(matched, Role.TYPE),
                reference,
                reference.child(expected, Role.TYPE),
            )
            errors += _compare_arguments(
                name, document, matched, reference, expected
            )
    return errors


def _compare_type(
    type_name: String,
    document: Document,
    actual: Int,
    reference: Document,
    expected: Int,
) -> String:
    """Port of `compareType`."""
    if actual < 0:
        return "\n * target schema does not define " + type_name + " type"
    return _compare_type_fields(
        type_name,
        document,
        document.children(actual, Role.FIELD),
        reference,
        reference.children(expected, Role.FIELD),
    )


def compare_schemas(sdl: String) raises -> String:
    """Compare SDL with the `products` schema of the suite, as upstream
    `compareSchemas`: the fields, arguments and types of `CaseStudy`,
    `DeprecatedProduct`, `Product`, `ProductDimension`,
    `ProductResearch`, `ProductVariation`, `User` and two `Query` fields.

    Args:
        sdl: The SDL to check.

    Returns:
        The errors of upstream, each on its own line; empty when the SDL
        matches.

    Raises:
        Error: A syntax error in the SDL.
    """
    var document = parse(sdl)
    var reference = parse(PRODUCTS_SDL)
    var errors = String()
    var names: List[String] = [
        "CaseStudy",
        "DeprecatedProduct",
        "Product",
        "ProductDimension",
        "ProductResearch",
        "ProductVariation",
    ]
    for ref name in names:
        errors += _compare_type(
            name,
            document,
            _object(document, name, False),
            reference,
            _object(reference, name, False),
        )
    errors += _compare_type(
        "User",
        document,
        _object(document, "User", True),
        reference,
        _object(reference, "User", True),
    )
    var fields = List[Int]()
    for extension in _find(document, Kind.OBJECT_TYPE_EXTENSION, "Query"):
        fields.extend(document.children(extension, Role.FIELD))
    var query = _object(document, "Query", False)
    if query >= 0:
        fields.extend(document.children(query, Role.FIELD))
    var query_fields = List[Int]()
    for field in fields:
        var name = document.name(field)
        if name == "product" or name == "deprecatedProduct":
            query_fields.append(field)
    errors += _compare_type_fields(
        "Query",
        document,
        query_fields,
        reference,
        reference.children(_object(reference, "Query", True), Role.FIELD),
    )
    return errors
