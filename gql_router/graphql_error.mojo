# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A GraphQL error returned by a subgraph.

Port of `GraphQLError` in Hive Router `1a29df9`
`bin/router/src/executor/response/graphql_error.rs`.

`error_json` writes the error as JSON. Empty locations and empty
extensions are left out. `service` is the subgraph name. Extra extension
keys are written in alphabetical order. A path that starts with
`_entities` and an index can be expanded onto the paths of that entity.

**Differences from upstream.** An HTTP status uses the canonical reason
when this module knows it, and the number alone otherwise. An extra key
named `code`, `service`, or `affectedPath` is not written a second time.
"""

from gql_json.value import JsonDocument
from gql_json.writer import stringify


@fieldwise_init
struct ErrorSegmentKind(Equatable, ImplicitlyCopyable, Movable):
    """One step of a GraphQL error path."""

    var value: UInt8
    """The kind's index. See `is_valid`."""

    comptime FIELD = ErrorSegmentKind(0)
    """A field name."""
    comptime INDEX = ErrorSegmentKind(1)
    """An index into a list."""

    def is_valid(self) -> Bool:
        """Return True when the value names a field or an index.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 1


@fieldwise_init
struct ErrorSegment(Copyable, Movable):
    """One step of a GraphQL error path."""

    var kind: ErrorSegmentKind
    """A field or an index."""
    var field: String
    """The field name. Empty for an index."""
    var index: Int
    """The list index. Unused for a field."""


@fieldwise_init
struct ErrorPath(Copyable, Movable):
    """The path of a GraphQL error."""

    var segments: List[ErrorSegment]
    """The steps, from the operation root."""


@fieldwise_init
struct GraphQLError(Copyable, Movable):
    """One GraphQL error."""

    var message: String
    """The error message."""
    var lines: List[Int]
    """The line of each location, parallel to `columns`."""
    var columns: List[Int]
    """The column of each location."""
    var has_path: Bool
    """True when `path` is present, including an empty path."""
    var path: ErrorPath
    """The error path."""
    var code: String
    """The `code` extension. Empty when it is absent."""
    var service: String
    """The `service` extension. Empty when it is absent."""
    var affected_path: String
    """The `affectedPath` extension. Empty when it is absent."""
    var extra_names: List[String]
    """Other extension names."""
    var extra_values: List[String]
    """Other extension values, as JSON text."""


def graphql_error(message: String) -> GraphQLError:
    """Return an error with a message and no extensions.

    Args:
        message: The error message.

    Returns:
        The error.
    """
    return GraphQLError(
        message,
        List[Int](),
        List[Int](),
        False,
        ErrorPath(List[ErrorSegment]()),
        String(""),
        String(""),
        String(""),
        List[String](),
        List[String](),
    )


def error_with_code(message: String, code: String) -> GraphQLError:
    """Return an error whose extensions hold a code.

    Args:
        message: The error message.
        code: The `code` extension.

    Returns:
        The error.
    """
    var error = graphql_error(message)
    error.code = code
    return error^


def error_with_extensions(
    message: String,
    code: String,
    service: String,
    affected_path: String,
    var extra_names: List[String],
    var extra_values: List[String],
) -> GraphQLError:
    """Return an error with extensions.

    Args:
        message: The error message.
        code: The `code` extension. Empty when it is absent.
        service: The `service` extension. Empty when it is absent.
        affected_path: The `affectedPath` extension. Empty when it is absent.
        extra_names: Other extension names.
        extra_values: Other extension values, as JSON text.

    Returns:
        The error.
    """
    var error = graphql_error(message)
    error.code = code
    error.service = service
    error.affected_path = affected_path
    error.extra_names = extra_names^
    error.extra_values = extra_values^
    return error^


def http_status_error(status: Int, service: String) -> GraphQLError:
    """Return the error for a subgraph HTTP status that is not successful.

    Args:
        status: The HTTP status code.
        service: The subgraph name.

    Returns:
        An error whose code is `SUBREQUEST_HTTP_ERROR` and whose `http`
        extension holds the status.
    """
    var error = graphql_error(
        "Subgraph '"
        + service
        + "' responded with an invalid HTTP status code '"
        + status_text(status)
        + "'"
    )
    error.code = String("SUBREQUEST_HTTP_ERROR")
    error.service = service
    error.extra_names.append(String("http"))
    error.extra_values.append(String('{"status":') + String(status) + "}")
    return error^


def status_text(status: Int) -> String:
    """Return the HTTP status as upstream `StatusCode` displays it.

    Args:
        status: The HTTP status code.

    Returns:
        The code and its canonical reason, or the code alone.
    """
    var reason = _reason(status)
    if reason.byte_length() == 0:
        return String(status)
    return String(status) + " " + reason


def add_subgraph_name(mut error: GraphQLError, service: String):
    """Record the subgraph when the error does not name one yet.

    Args:
        error: The error to update.
        service: The subgraph name.
    """
    if error.service.byte_length() == 0:
        error.service = service
    if error.code.byte_length() == 0:
        error.code = String("DOWNSTREAM_SERVICE_ERROR")


def add_affected_path(mut error: GraphQLError, path: String):
    """Record the flatten path that caused the error.

    Args:
        error: The error to update.
        path: The affected path.
    """
    error.affected_path = path


def set_extension(mut error: GraphQLError, name: String, value: String):
    """Set one extra extension value.

    Args:
        error: The error to update.
        name: The extension name.
        value: The value, as JSON text.
    """
    for index in range(len(error.extra_names)):
        if error.extra_names[index] == name:
            if index < len(error.extra_values):
                error.extra_values[index] = value
            return
    error.extra_names.append(name)
    error.extra_values.append(value)


def extension_value(error: GraphQLError, name: String) -> String:
    """Return one extra extension value.

    Args:
        error: The error.
        name: The extension name.

    Returns:
        The JSON text. Empty when the name is absent.
    """
    var limit = len(error.extra_names)
    if len(error.extra_values) < limit:
        limit = len(error.extra_values)
    for index in range(limit):
        if error.extra_names[index] == name:
            return String(error.extra_values[index])
    return String("")


def extensions_empty(error: GraphQLError) -> Bool:
    """Return True when the error has no extensions.

    Args:
        error: The error.

    Returns:
        Whether `code`, `service`, `affectedPath`, and the extra keys are
        all absent.
    """
    return (
        error.code.byte_length() == 0
        and error.service.byte_length() == 0
        and error.affected_path.byte_length() == 0
        and len(error.extra_names) == 0
    )


def field_segment(name: String) -> ErrorSegment:
    """Return a field step.

    Args:
        name: The field name.

    Returns:
        The step.
    """
    return ErrorSegment(ErrorSegmentKind.FIELD, name, 0)


def index_segment(index: Int) -> ErrorSegment:
    """Return a list-index step.

    Args:
        index: The list index.

    Returns:
        The step.
    """
    return ErrorSegment(ErrorSegmentKind.INDEX, String(""), index)


def entity_index(path: ErrorPath) -> Int:
    """Return the `_entities` index at the start of a path.

    Args:
        path: The error path.

    Returns:
        The index. `-1` when the path does not start with `_entities` and
        an index.
    """
    if len(path.segments) < 2:
        return -1
    if path.segments[0].kind != ErrorSegmentKind.FIELD:
        return -1
    if path.segments[0].field != "_entities":
        return -1
    if path.segments[1].kind != ErrorSegmentKind.INDEX:
        return -1
    return path.segments[1].index


def normalize_entity_error(
    error: GraphQLError,
    indexes: List[Int],
    paths: List[ErrorPath],
) -> List[GraphQLError]:
    """Expand an `_entities` error onto the paths of that entity.

    Args:
        error: The error from the entity fetch.
        indexes: The entity indexes, parallel to `paths`.
        paths: The response path of each entity.

    Returns:
        One error per matching path. The original error when none match.
    """
    var found = entity_index(error.path)
    var matched = List[GraphQLError]()
    if found < 0:
        matched.append(error.copy())
        return matched^
    var rest = _rest(error.path)
    var any = False
    var limit = len(indexes)
    if len(paths) < limit:
        limit = len(paths)
    for index in range(limit):
        if indexes[index] != found:
            continue
        any = True
        var copy = error.copy()
        copy.has_path = True
        copy.path = _join(paths[index], rest)
        matched.append(copy^)
    if not any:
        matched.append(error.copy())
    return matched^


def handle_subgraph_errors(
    mut errors: List[GraphQLError],
    subgraph: String,
    has_affected_path: Bool,
    affected_path: String,
    var incoming: List[GraphQLError],
    has_entities: Bool,
    indexes: List[Int],
    paths: List[ErrorPath],
):
    """Attach subgraph errors to the response.

    Args:
        errors: The errors already recorded. New errors are appended.
        subgraph: The subgraph name.
        has_affected_path: True when the fetch writes at a response path.
        affected_path: That path, such as `me.reviews.@.product`.
        incoming: The errors from the subgraph. An empty list adds nothing.
        has_entities: True when `_entities` errors expand onto entity paths.
        indexes: The entity indexes, parallel to `paths`.
        paths: The response path of each entity.
    """
    for index in range(len(incoming)):
        var error = incoming[index].copy()
        add_subgraph_name(error, subgraph)
        if has_affected_path:
            add_affected_path(error, affected_path)
        if not has_entities:
            errors.append(error^)
            continue
        var expanded = normalize_entity_error(error, indexes, paths)
        for place in range(len(expanded)):
            errors.append(expanded[place].copy())


def error_json(error: GraphQLError) -> String:
    """Write an error as JSON.

    Args:
        error: The error.

    Returns:
        The JSON object.
    """
    var out = String('{"message":')
    out += _json_string(error.message)
    var locations = len(error.lines)
    if len(error.columns) < locations:
        locations = len(error.columns)
    if locations > 0:
        out += ',"locations":['
        for index in range(locations):
            if index > 0:
                out += ","
            out += '{"line":'
            out += String(error.lines[index])
            out += ',"column":'
            out += String(error.columns[index])
            out += "}"
        out += "]"
    if error.has_path:
        out += ',"path":'
        out += _path_json(error.path)
    if not extensions_empty(error):
        out += ',"extensions":'
        out += _extensions_json(error)
    out += "}"
    return out^


def _extensions_json(error: GraphQLError) -> String:
    """Write the extensions object.

    Args:
        error: The error.

    Returns:
        The JSON object.
    """
    var out = String("{")
    var wrote = False
    if error.code.byte_length() > 0:
        out += '"code":'
        out += _json_string(error.code)
        wrote = True
    if error.service.byte_length() > 0:
        if wrote:
            out += ","
        out += '"service":'
        out += _json_string(error.service)
        wrote = True
    if error.affected_path.byte_length() > 0:
        if wrote:
            out += ","
        out += '"affectedPath":'
        out += _json_string(error.affected_path)
        wrote = True
    var order = _sorted_extras(error.extra_names)
    for place in range(len(order)):
        var index = order[place]
        if _reserved(error.extra_names[index]):
            continue
        if index >= len(error.extra_values):
            continue
        if wrote:
            out += ","
        wrote = True
        out += _json_string(error.extra_names[index])
        out += ":"
        out += error.extra_values[index]
    out += "}"
    return out^


def _path_json(path: ErrorPath) -> String:
    """Write a path as a JSON array.

    Args:
        path: The path.

    Returns:
        The JSON array.
    """
    var out = String("[")
    for index in range(len(path.segments)):
        if index > 0:
            out += ","
        ref segment = path.segments[index]
        if segment.kind == ErrorSegmentKind.INDEX:
            out += String(segment.index)
        else:
            out += _json_string(segment.field)
    out += "]"
    return out^


def _json_string(text: String) -> String:
    """Write a JSON string, including the quotes.

    Args:
        text: The text.

    Returns:
        The quoted JSON string.
    """
    var document = JsonDocument()
    var node = document.add_string(text)
    return stringify(document, node)


def _rest(path: ErrorPath) -> ErrorPath:
    """Return the path after `_entities` and its index.

    Args:
        path: The error path.

    Returns:
        The remaining steps. Empty when the path is shorter than two steps.
    """
    var segments = List[ErrorSegment]()
    var index = 2
    while index < len(path.segments):
        segments.append(path.segments[index].copy())
        index += 1
    return ErrorPath(segments^)


def _join(base: ErrorPath, rest: ErrorPath) -> ErrorPath:
    """Append one path to another.

    Args:
        base: The path that stays first.
        rest: The path to append.

    Returns:
        The combined path.
    """
    var segments = List[ErrorSegment]()
    for index in range(len(base.segments)):
        segments.append(base.segments[index].copy())
    for index in range(len(rest.segments)):
        segments.append(rest.segments[index].copy())
    return ErrorPath(segments^)


def _sorted_extras(names: List[String]) -> List[Int]:
    """Return extra-key indexes in alphabetical order.

    Args:
        names: The extra extension names.

    Returns:
        The indexes.
    """
    var order = List[Int]()
    for index in range(len(names)):
        var at = len(order)
        while at > 0 and names[index] < names[order[at - 1]]:
            at -= 1
        order.insert(at, index)
    return order^


def _reserved(name: String) -> Bool:
    """Return True when a name is a dedicated extension field.

    Args:
        name: The extension name.

    Returns:
        Whether the name is `code`, `service`, or `affectedPath`.
    """
    return name == "code" or name == "service" or name == "affectedPath"


def _reason(status: Int) -> String:
    """Return the canonical reason for a common HTTP status.

    Args:
        status: The HTTP status code.

    Returns:
        The reason. Empty when this module does not know the status.
    """
    if status == 400:
        return String("Bad Request")
    if status == 401:
        return String("Unauthorized")
    if status == 403:
        return String("Forbidden")
    if status == 404:
        return String("Not Found")
    if status == 500:
        return String("Internal Server Error")
    if status == 502:
        return String("Bad Gateway")
    if status == 503:
        return String("Service Unavailable")
    if status == 504:
        return String("Gateway Timeout")
    return String("")
