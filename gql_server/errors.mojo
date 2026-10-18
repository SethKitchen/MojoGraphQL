# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The error codes and the error classes of the server.

Port of Apollo Server 5.5.1 `errors/index.ts` (`ApolloServerErrorCode`,
`ApolloServerValidationErrorCode`) and `internalErrorClasses.ts`
(`SyntaxError`, `ValidationError`, `PersistedQueryNotFoundError`,
`PersistedQueryNotSupportedError`, `UserInputError`,
`OperationResolutionError` and `BadRequestError`).

A `ServerError` is a GraphQL error with its extensions as a list of
members. The `http` extension of upstream is the `http` field, so it is
never part of the response.

**Differences from upstream.**
- Mojo has no stack traces. `ServerError.stack` holds only the first line
  of the JavaScript stack: the class name and the message, such as
  `BadRequestError: No operations found in request.`.
- `unwrapResolverError` is not ported: a Mojo resolver raises an `Error`
  with a message only, so there is nothing to unwrap.
"""

from gql_json.parser import parse as parse_json
from gql_json.value import NO_NODE as NO_JSON
from gql_json.writer import stringify
from gql_language.error import GraphQLError, PathSegment, quote_json_string
from gql_language.source import SourceLocation
from gql_server.http_types import HTTPGraphQLHead


@fieldwise_init
struct ApolloServerErrorCode(Equatable, ImplicitlyCopyable, Writable):
    """An error code of the server: upstream `ApolloServerErrorCode`."""

    var value: UInt8
    """The index of the code; see `is_valid`."""

    comptime INTERNAL_SERVER_ERROR = ApolloServerErrorCode(0)
    """`INTERNAL_SERVER_ERROR`: an error without a code."""
    comptime GRAPHQL_PARSE_FAILED = ApolloServerErrorCode(1)
    """`GRAPHQL_PARSE_FAILED`: the operation is not valid GraphQL."""
    comptime GRAPHQL_VALIDATION_FAILED = ApolloServerErrorCode(2)
    """`GRAPHQL_VALIDATION_FAILED`: the operation is not valid for the
    schema."""
    comptime PERSISTED_QUERY_NOT_FOUND = ApolloServerErrorCode(3)
    """`PERSISTED_QUERY_NOT_FOUND`: the hash is not in the cache."""
    comptime PERSISTED_QUERY_NOT_SUPPORTED = ApolloServerErrorCode(4)
    """`PERSISTED_QUERY_NOT_SUPPORTED`: persisted queries are off."""
    comptime BAD_USER_INPUT = ApolloServerErrorCode(5)
    """`BAD_USER_INPUT`: a variable value is not valid."""
    comptime OPERATION_RESOLUTION_FAILURE = ApolloServerErrorCode(6)
    """`OPERATION_RESOLUTION_FAILURE`: no operation to run."""
    comptime BAD_REQUEST = ApolloServerErrorCode(7)
    """`BAD_REQUEST`: the HTTP request is not valid."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the eight codes.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 7

    def text(self) -> StaticString:
        """Return the code, such as `BAD_REQUEST`.

        Returns:
            The code, or `<invalid>`.
        """
        comptime names: Array[StaticString, 8] = [
            "INTERNAL_SERVER_ERROR",
            "GRAPHQL_PARSE_FAILED",
            "GRAPHQL_VALIDATION_FAILED",
            "PERSISTED_QUERY_NOT_FOUND",
            "PERSISTED_QUERY_NOT_SUPPORTED",
            "BAD_USER_INPUT",
            "OPERATION_RESOLUTION_FAILURE",
            "BAD_REQUEST",
        ]
        if self.is_valid():
            return materialize[names]()[Int(self.value)]
        return "<invalid>"

    def write_to(self, mut writer: Some[Writer]):
        """Write the code.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct ApolloServerValidationErrorCode(Equatable, ImplicitlyCopyable, Writable):
    """A validation error code: upstream
    `ApolloServerValidationErrorCode`."""

    var value: UInt8
    """The index of the code; see `is_valid`."""

    comptime INTROSPECTION_DISABLED = ApolloServerValidationErrorCode(0)
    """`INTROSPECTION_DISABLED`: the operation uses `__schema` or
    `__type`, and introspection is off."""
    comptime MAX_RECURSIVE_SELECTIONS_EXCEEDED = (
        ApolloServerValidationErrorCode(1)
    )
    """`MAX_RECURSIVE_SELECTIONS_EXCEEDED`: the operation selects too many
    fields. The rule is not ported; the code is kept for the API."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the two codes.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 1

    def text(self) -> StaticString:
        """Return the code, such as `INTROSPECTION_DISABLED`.

        Returns:
            The code, or `<invalid>`.
        """
        if self.value == 0:
            return "INTROSPECTION_DISABLED"
        if self.value == 1:
            return "MAX_RECURSIVE_SELECTIONS_EXCEEDED"
        return "<invalid>"

    def write_to(self, mut writer: Some[Writer]):
        """Write the code.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct Extension(Copyable, Movable):
    """One member of the `extensions` of an error."""

    var key: String
    """The key."""
    var json: String
    """The value, as JSON text."""


def set_extension(
    mut extensions: List[Extension], key: StringSlice, json: StringSlice
):
    """Set a member: a key that exists keeps its position, as in a
    JavaScript object.

    Args:
        extensions: The members.
        key: The key.
        json: The value, as JSON text.
    """
    var index = 0
    while index < len(extensions):
        if extensions[index].key == key:
            extensions[index].json = String(json)
            return
        index += 1
    extensions.append(Extension(String(key), String(json)))


def find_extension(extensions: List[Extension], key: StringSlice) -> Int:
    """Return the position of a member.

    Args:
        extensions: The members.
        key: The key.

    Returns:
        The position, or -1 when no member has the key.
    """
    var index = 0
    while index < len(extensions):
        if extensions[index].key == key:
            return index
        index += 1
    return -1


def code_json(code: ApolloServerErrorCode) -> String:
    """Return a code as a JSON string.

    Args:
        code: The code.

    Returns:
        Such as `"BAD_REQUEST"`.
    """
    return '"' + String(code.text()) + '"'


struct ServerError(Copyable, Movable, Writable):
    """A GraphQL error as the server handles it: upstream `GraphQLError`
    with its `extensions`, and the `http` extension apart."""

    var message: String
    """The description of the error."""
    var locations: List[SourceLocation]
    """The positions in the operation that the error refers to."""
    var path: List[PathSegment]
    """The response path of the field that failed, or empty."""
    var extensions: List[Extension]
    """The members of `extensions`, in order, without `http`."""
    var http: HTTPGraphQLHead
    """The `extensions.http` of upstream: the status and the fields that
    the error adds to the response."""
    var stack: String
    """The first line of the upstream stack, such as `Error: boom`."""

    def __init__(out self, message: String, stack_name: StringSlice = "Error"):
        """Make an error with only a message.

        Args:
            message: The description.
            stack_name: The class name of the upstream error, for `stack`.
        """
        self.message = message
        self.locations = List[SourceLocation]()
        self.path = List[PathSegment]()
        self.extensions = List[Extension]()
        self.http = HTTPGraphQLHead()
        self.stack = String(stack_name) + ": " + message

    @staticmethod
    def from_graphql_error(
        error: GraphQLError, stack_name: StringSlice = "GraphQLError"
    ) raises -> ServerError:
        """Make an error from a GraphQL error of the other packages.

        Args:
            error: The error, with its `extensions` as JSON text.
            stack_name: The class name of the upstream error, for `stack`.

        Returns:
            The error, with the members of its extensions.

        Raises:
            Error: When `error.extensions` is not a JSON object.
        """
        var out = ServerError(error.message, stack_name)
        out.locations = error.locations.copy()
        out.path = error.path.copy()
        if error.extensions.byte_length() > 0:
            var document = parse_json(error.extensions)
            var member = document.first(document.root)
            while member != NO_JSON:
                set_extension(
                    out.extensions,
                    document.key(member),
                    stringify(document, member),
                )
                member = document.next(member)
        return out^

    def write_to(self, mut writer: Some[Writer]):
        """Write the message.

        Args:
            writer: The destination.
        """
        writer.write(self.message)


def _with_code(
    var error: ServerError, code: ApolloServerErrorCode
) -> ServerError:
    """Add the `code` extension: upstream `GraphQLErrorWithCode`."""
    set_extension(error.extensions, "code", code_json(code))
    return error^


def bad_request_error(
    message: String, var http: HTTPGraphQLHead = HTTPGraphQLHead(400)
) -> ServerError:
    """Make a `BadRequestError`: the code `BAD_REQUEST`, and status 400
    unless `http` says otherwise.

    Args:
        message: The description.
        http: The status and the fields of the response.

    Returns:
        The error.
    """
    var error = ServerError(message, "BadRequestError")
    error.http = http^
    return _with_code(error^, ApolloServerErrorCode.BAD_REQUEST)


def syntax_error(var error: ServerError) -> ServerError:
    """Make a `SyntaxError` from a parse error: the code
    `GRAPHQL_PARSE_FAILED` and status 400.

    Args:
        error: The parse error.

    Returns:
        The error.
    """
    var out = error^
    out.http = HTTPGraphQLHead(400)
    return _with_code(out^, ApolloServerErrorCode.GRAPHQL_PARSE_FAILED)


def validation_error(var error: ServerError) -> ServerError:
    """Make a `ValidationError` from a validation error: the code
    `GRAPHQL_VALIDATION_FAILED` and status 400.

    Args:
        error: The validation error.

    Returns:
        The error.
    """
    var out = error^
    out.http = HTTPGraphQLHead(400)
    return _with_code(out^, ApolloServerErrorCode.GRAPHQL_VALIDATION_FAILED)


def user_input_error(var error: ServerError) -> ServerError:
    """Make a `UserInputError` from a variable coercion error: the code
    `BAD_USER_INPUT`.

    Args:
        error: The coercion error.

    Returns:
        The error.
    """
    return _with_code(error^, ApolloServerErrorCode.BAD_USER_INPUT)


def operation_resolution_error(var error: ServerError) -> ServerError:
    """Make an `OperationResolutionError`: the code
    `OPERATION_RESOLUTION_FAILURE` and status 400.

    Args:
        error: The error of execution that names no operation.

    Returns:
        The error.
    """
    error.http = HTTPGraphQLHead(400)
    return _with_code(
        error^, ApolloServerErrorCode.OPERATION_RESOLUTION_FAILURE
    )


def _persisted_query_error(
    message: String, stack_name: StringSlice, code: ApolloServerErrorCode
) -> ServerError:
    var error = ServerError(message, stack_name)
    error.http = HTTPGraphQLHead(200)
    error.http.headers.set(
        "cache-control", "private, no-cache, must-revalidate"
    )
    return _with_code(error^, code)


def persisted_query_not_found_error() -> ServerError:
    """Make a `PersistedQueryNotFoundError`: status 200, and a
    `cache-control` field that stops caches from keeping it.

    Returns:
        The error.
    """
    return _persisted_query_error(
        "PersistedQueryNotFound",
        "PersistedQueryNotFoundError",
        ApolloServerErrorCode.PERSISTED_QUERY_NOT_FOUND,
    )


def persisted_query_not_supported_error() -> ServerError:
    """Make a `PersistedQueryNotSupportedError`, as
    `persisted_query_not_found_error` does.

    Returns:
        The error.
    """
    return _persisted_query_error(
        "PersistedQueryNotSupported",
        "PersistedQueryNotSupportedError",
        ApolloServerErrorCode.PERSISTED_QUERY_NOT_SUPPORTED,
    )


def ensure_graphql_error(error: Error, prefix: StringSlice = "") -> ServerError:
    """Make a GraphQL error from a Mojo `Error`: upstream
    `ensureGraphQLError` of a JavaScript `Error`.

    Args:
        error: The error.
        prefix: The text before the message, such as `Context creation
            failed: `.

    Returns:
        The error. Its `stack` is the stack of the original `Error`.
    """
    var message = String(error)
    var out = ServerError(String(prefix) + message)
    out.stack = "Error: " + message
    return out^


def has_code(error: ServerError, code: ApolloServerErrorCode) -> Bool:
    """Return True if the `code` extension of an error is a code.

    Args:
        error: The error.
        code: The code.

    Returns:
        Whether `extensions.code` is that code.
    """
    var at = find_extension(error.extensions, "code")
    return at >= 0 and error.extensions[at].json == code_json(code)
