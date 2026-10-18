# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Read a subgraph response body into the response arena.

Port of `SubgraphResponse::deserialize_from_bytes` of Hive Router
`1a29df9` `bin/router/src/executor/response/subgraph_response.rs`.

The body must be a JSON object. `data`, `errors` and `extensions` may each
appear once; other members are ignored. Missing `data` is `null`. A `null`
`data` without `errors` is a malformed response.

**Differences from upstream.** The body is parsed with
`gql_json.parser.parse_bytes` and appended to the executor arena with
`import_document`, so the data is never copied again. The text of a JSON
syntax error is the `gql_json` text, not the `sonic_rs` text.
`extensions` and custom scalar paths are not read: every value keeps its
source text anyway.
"""

from gql_json.parser import parse_bytes
from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_json.writer import stringify
from gql_router.exec_value import import_document, key_is, string_text
from gql_router.graphql_error import (
    ErrorPath,
    ErrorSegment,
    GraphQLError,
    field_segment,
    graphql_error,
    index_segment,
)


struct SubgraphResponse(Movable):
    """The parts of one subgraph response, as upstream
    `SubgraphResponse`."""

    var data: Int
    """The data value in the arena, or `NO_NODE` for `null`."""
    var errors: List[GraphQLError]
    """The errors."""
    var has_errors: Bool
    """Whether the response has an `errors` member."""
    var status: Int
    """The HTTP status, or 0 when it is unknown."""

    def __init__(out self):
        """Start a response with `null` data and no errors."""
        self.data = NO_NODE
        self.errors = List[GraphQLError]()
        self.has_errors = False
        self.status = 0

    def append_error(mut self, var error: GraphQLError):
        """Add one error, as upstream `append_error`.

        Args:
            error: The error.
        """
        self.has_errors = True
        self.errors.append(error^)


def _fail(message: String) -> Error:
    """Return the error of a body that is not a GraphQL response."""
    return Error("Failed to deserialize subgraph response: " + message)


def read_subgraph_response(
    mut arena: JsonDocument, var body: List[UInt8]
) raises -> SubgraphResponse:
    """Read a response body, as upstream `deserialize_from_bytes`.

    Args:
        arena: The response arena; the data is appended to it.
        body: The response body.

    Returns:
        The response; `data` is a node of `arena`.

    Raises:
        Error: When the body is not a JSON object, a member repeats, a
            member has the wrong type, or `data` is `null` without
            `errors`.
    """
    var parsed: JsonDocument
    try:
        parsed = parse_bytes(body^)
    except e:
        raise _fail(String(e))
    var root = parsed.root
    if parsed.kind(root) != JsonKind.OBJECT:
        raise _fail("expected a GraphQL response object")
    var data = NO_NODE
    var errors = NO_NODE
    var extensions = NO_NODE
    var member = parsed.first(root)
    while member != NO_NODE:
        if key_is(parsed, member, "data"):
            if data != NO_NODE:
                raise _fail("duplicate field `data`")
            data = member
        elif key_is(parsed, member, "errors"):
            if errors != NO_NODE:
                raise _fail("duplicate field `errors`")
            errors = member
        elif key_is(parsed, member, "extensions"):
            if extensions != NO_NODE:
                raise _fail("duplicate field `extensions`")
            extensions = member
        member = parsed.next(member)
    var response = SubgraphResponse()
    if errors != NO_NODE and parsed.kind(errors) != JsonKind.NULL:
        if parsed.kind(errors) != JsonKind.ARRAY:
            raise _fail("invalid type: `errors` must be an array")
        response.has_errors = True
        var item = parsed.first(errors)
        while item != NO_NODE:
            response.errors.append(_read_error(parsed, item))
            item = parsed.next(item)
    var has_data = data != NO_NODE and parsed.kind(data) != JsonKind.NULL
    if not has_data and not response.has_errors:
        raise Error("Subgraph returned malformed response")
    if has_data:
        var offset = import_document(arena, parsed)
        response.data = offset - root + data
    return response^


def _read_error(parsed: JsonDocument, node: Int) raises -> GraphQLError:
    """Read one error object, as upstream `Deserialize for GraphQLError`."""
    if parsed.kind(node) != JsonKind.OBJECT:
        raise _fail("invalid type: an error must be an object")
    var message = NO_NODE
    var error = graphql_error("")
    var member = parsed.first(node)
    while member != NO_NODE:
        var kind = parsed.kind(member)
        if key_is(parsed, member, "message"):
            message = member
        elif key_is(parsed, member, "locations") and kind == JsonKind.ARRAY:
            var location = parsed.first(member)
            while location != NO_NODE:
                error.lines.append(_number(parsed, location, "line"))
                error.columns.append(_number(parsed, location, "column"))
                location = parsed.next(location)
        elif key_is(parsed, member, "path") and kind == JsonKind.ARRAY:
            error.has_path = True
            error.path = _read_path(parsed, member)
        elif key_is(parsed, member, "extensions") and kind == JsonKind.OBJECT:
            _read_extensions(parsed, member, error)
        member = parsed.next(member)
    if message == NO_NODE or parsed.kind(message) != JsonKind.STRING:
        raise _fail("missing field `message`")
    error.message = string_text(parsed, message)
    return error^


def _number(parsed: JsonDocument, location: Int, name: StringSlice) raises -> Int:
    """Read the line or column of a location."""
    var found = parsed.find(location, name)
    if found == NO_NODE or not parsed.is_integer(found):
        raise _fail("invalid location")
    return Int(parsed.as_int64(found))


def _read_path(parsed: JsonDocument, node: Int) raises -> ErrorPath:
    """Read an error path of field names and list indices."""
    var segments = List[ErrorSegment]()
    var item = parsed.first(node)
    while item != NO_NODE:
        if parsed.kind(item) == JsonKind.STRING:
            segments.append(field_segment(string_text(parsed, item)))
        elif parsed.is_integer(item):
            segments.append(index_segment(Int(parsed.as_int64(item))))
        else:
            raise _fail("invalid path segment")
        item = parsed.next(item)
    return ErrorPath(segments^)


def _read_extensions(parsed: JsonDocument, node: Int, mut error: GraphQLError):
    """Read the extensions of an error: `code`, `service`, `affectedPath`,
    and the other members as JSON text."""
    var member = parsed.first(node)
    while member != NO_NODE:
        var is_string = parsed.kind(member) == JsonKind.STRING
        if key_is(parsed, member, "code") and is_string:
            error.code = string_text(parsed, member)
        elif key_is(parsed, member, "service") and is_string:
            error.service = string_text(parsed, member)
        elif key_is(parsed, member, "affectedPath") and is_string:
            error.affected_path = string_text(parsed, member)
        else:
            error.extra_names.append(parsed.key(member))
            error.extra_values.append(stringify(parsed, member))
        member = parsed.next(member)
