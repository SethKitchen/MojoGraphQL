# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Format the errors of a response, and collect their HTTP status and
fields.

Port of Apollo Server 5.5.1 `errorNormalize.ts`:
`normalizeAndFormatErrors` and its `enrichError`. `ensureGraphQLError` is
`gql_server.errors.ensure_graphql_error`.

**Differences from upstream.**
- `formatError` is a Mojo function. It gets the formatted error and the
  `ServerError`, and it raises an `Error` to fail.
- With `includeStacktraceInErrorResponses`, `extensions.stacktrace` holds
  one line: the first line of the upstream stack, such as
  `Error: Secret error message`. Mojo has no stack frames.
"""

from gql_language.error import PathSegment, quote_json_string
from gql_language.source import SourceLocation
from gql_server.errors import (
    ApolloServerErrorCode,
    Extension,
    ServerError,
    code_json,
    ensure_graphql_error,
    find_extension,
    set_extension,
)
from gql_server.http_types import HTTPGraphQLHead, merge_http_graphql_head


struct FormattedError(Copyable, Movable):
    """An error as a response holds it: graphql-js
    `GraphQLFormattedError`."""

    var message: String
    """The description."""
    var locations: List[SourceLocation]
    """The positions; omitted from the JSON when empty."""
    var path: List[PathSegment]
    """The response path; omitted from the JSON when empty."""
    var extensions: List[Extension]
    """The members of `extensions`."""
    var has_extensions: Bool
    """Whether the JSON has an `extensions` key, even an empty one."""

    def __init__(out self, message: String):
        """Make an error with only a message.

        Args:
            message: The description.
        """
        self.message = message
        self.locations = List[SourceLocation]()
        self.path = List[PathSegment]()
        self.extensions = List[Extension]()
        self.has_extensions = False

    def set_extension(mut self, key: StringSlice, json: StringSlice):
        """Set a member of `extensions`, and give the error the key.

        Args:
            key: The key.
            json: The value, as JSON text.
        """
        set_extension(self.extensions, key, json)
        self.has_extensions = True

    def extension(self, key: StringSlice) -> Optional[String]:
        """Return a member of `extensions`.

        Args:
            key: The key.

        Returns:
            The JSON text of the value, or None.
        """
        var index = find_extension(self.extensions, key)
        if index < 0:
            return None
        return self.extensions[index].json.copy()

    def to_json(self) -> String:
        """Return the error as JSON, as `JSON.stringify` writes it.

        Returns:
            The keys `message`, `locations`, `path` and `extensions`.
        """
        var out = String('{"message":') + quote_json_string(self.message)
        var index = 0
        while index < len(self.locations):
            out += ',"locations":[' if index == 0 else ","
            out += '{"line":' + String(self.locations[index].line)
            out += ',"column":' + String(self.locations[index].column) + "}"
            index += 1
            out += "]" if index == len(self.locations) else ""
        index = 0
        while index < len(self.path):
            out += ',"path":[' if index == 0 else ","
            if self.path[index].is_index():
                out += String(self.path[index].index)
            else:
                out += quote_json_string(self.path[index].key)
            index += 1
            out += "]" if index == len(self.path) else ""
        if self.has_extensions:
            out += ',"extensions":{'
            index = 0
            while index < len(self.extensions):
                if index > 0:
                    out += ","
                out += quote_json_string(self.extensions[index].key) + ":"
                out += self.extensions[index].json
                index += 1
            out += "}"
        return out + "}"


comptime FormatErrorFunction = def(
    formatted: FormattedError, error: ServerError
) raises thin -> FormattedError
"""The `formatError` option: it gets the formatted error and the original
error, and returns the error for the response."""


struct NormalizedErrors(Movable):
    """The result of `normalize_and_format_errors`."""

    var formatted_errors: List[FormattedError]
    """The errors for the response, in order."""
    var http_from_errors: HTTPGraphQLHead
    """The status and the fields that the errors add to the response."""

    def __init__(out self):
        """Make an empty result."""
        self.formatted_errors = List[FormattedError]()
        self.http_from_errors = HTTPGraphQLHead()


def enrich_error(
    error: ServerError,
    mut http_from_errors: HTTPGraphQLHead,
    include_stacktrace: Bool,
) -> FormattedError:
    """Format one error: upstream `enrichError`.

    The `code` extension defaults to `INTERNAL_SERVER_ERROR`. The `http`
    extension goes into `http_from_errors` and not into the response.

    Args:
        error: The error.
        http_from_errors: The head that collects the `http` extensions.
        include_stacktrace: Whether to add `extensions.stacktrace`.

    Returns:
        The formatted error.
    """
    var out = FormattedError(error.message)
    out.locations = error.locations.copy()
    out.path = error.path.copy()
    out.extensions = error.extensions.copy()
    out.has_extensions = True
    if find_extension(out.extensions, "code") < 0:
        out.set_extension(
            "code", code_json(ApolloServerErrorCode.INTERNAL_SERVER_ERROR)
        )
    merge_http_graphql_head(http_from_errors, error.http)
    if include_stacktrace:
        out.set_extension(
            "stacktrace", "[" + quote_json_string(error.stack) + "]"
        )
    return out^


def normalize_and_format_errors(
    errors: List[ServerError],
    format_error: Optional[FormatErrorFunction] = None,
    include_stacktrace: Bool = False,
) -> NormalizedErrors:
    """Format the errors of a response: upstream
    `normalizeAndFormatErrors`.

    When `format_error` raises, the error becomes `Internal server error`
    with the code `INTERNAL_SERVER_ERROR`. With `include_stacktrace`, it
    becomes the error that `format_error` raised.

    Args:
        errors: The errors.
        format_error: The `formatError` option.
        include_stacktrace: The `includeStacktraceInErrorResponses`
            option.

    Returns:
        The formatted errors and the head that their `http` extensions
        make.
    """
    var out = NormalizedErrors()
    var index = 0
    while index < len(errors):
        ref error = errors[index]
        var formatted = enrich_error(
            error, out.http_from_errors, include_stacktrace
        )
        if format_error:
            try:
                formatted = format_error.value()(formatted, error)
            except e:
                if include_stacktrace:
                    formatted = enrich_error(
                        ensure_graphql_error(e),
                        out.http_from_errors,
                        include_stacktrace,
                    )
                else:
                    formatted = FormattedError("Internal server error")
                    formatted.set_extension(
                        "code",
                        code_json(ApolloServerErrorCode.INTERNAL_SERVER_ERROR),
                    )
        out.formatted_errors.append(formatted^)
        index += 1
    return out^
