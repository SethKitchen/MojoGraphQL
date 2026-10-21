# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Incremental delivery: the results of `@defer` and `@stream`, and their
`multipart/mixed` body.

Port of Apollo Server 5.5.1 `incrementalDeliveryPolyfill.ts`
(`executeIncrementally`), the `formatErrorsInSubsequentResultsAlpha9` part
of `requestPipeline.ts`, `writeMultipartBody` of `runHttpQuery.ts`, and the
`__testing_incrementalExecutionResults` option of `ApolloServer.ts`.

The execution is `gql_execution.incremental`, a port of graphql-js
17.0.0-alpha.14. Its payloads have the format of graphql-js
17.0.0-alpha.9, which Apollo Server calls the current format:
`multipart/mixed; incrementalSpec=v0.2`.

**Differences from upstream.**
- Upstream runs every operation with `experimentalExecuteIncrementally`
  when graphql-js 17.0.0-alpha.9 is installed. Here an operation runs
  incrementally only when its document has a `@defer` or a `@stream`
  directive. Another document gives the same single result either way.
- The keys of a deferred entry are in the graphql-js 17.0.0-alpha.14
  order, `{"id":...,"data":...}`. graphql-js 17.0.0-alpha.9 writes
  `{"data":...,"id":...}`.
- `legacyExperimentalExecuteIncrementally` is not ported: no executor of
  the graphql-js 17.0.0-alpha.2 format exists here. A request that asks
  for `deferSpec=20220824` gets the upstream 406 error for a server
  without that executor.
- A `SubsequentPayload` is the JSON text of the payload. A plugin can read
  or replace the text. Upstream gives the payload object.
"""

from gql_execution.incremental import SubsequentResultStream
from gql_execution.incremental_results import IncrementalResult, write_path
from gql_json.writer import stringify
from gql_language.ast import Document, Kind
from gql_language.error import quote_json_string
from gql_stream.stream import AnyStream

comptime MULTIPART_MIXED_NO_DEFER_SPEC = "multipart/mixed"
"""`MEDIA_TYPES.MULTIPART_MIXED_NO_DEFER_SPEC`."""
comptime MULTIPART_MIXED_EXPERIMENTAL_ALPHA_2 = (
    "multipart/mixed; deferSpec=20220824"
)
"""`MEDIA_TYPES.MULTIPART_MIXED_EXPERIMENTAL_ALPHA_2`: the legacy format."""
comptime MULTIPART_MIXED_EXPERIMENTAL_ALPHA_9 = (
    "multipart/mixed; incrementalSpec=v0.2"
)
"""`MEDIA_TYPES.MULTIPART_MIXED_EXPERIMENTAL_ALPHA_9`: the current
format."""

comptime LEGACY_NOT_SUPPORTED_MESSAGE = (
    "Apollo Server received an operation that uses incremental delivery"
    " (@defer or @stream) with the legacy incremental format, but the server"
    " does not support the legacy incremental delivery format. Add the HTTP"
    " header: 'Accept: "
    + MULTIPART_MIXED_EXPERIMENTAL_ALPHA_9
    + "' to use the current incremental delivery format"
)
"""The 406 error of `executeIncrementally` for the legacy format."""

comptime NOT_ACCEPTED_MESSAGE = (
    "Apollo server received an operation that uses incremental delivery"
    " (@defer or @stream), but the client does not accept multipart/mixed"
    " HTTP responses. To enable incremental delivery support, add the HTTP"
    " header 'Accept: "
    + MULTIPART_MIXED_EXPERIMENTAL_ALPHA_9
    + "' if your client supports the current incremental format or 'Accept: "
    + MULTIPART_MIXED_EXPERIMENTAL_ALPHA_2
    + "' if your client supports the legacy incremental format"
)
"""The 406 error of `runHttpQuery` for a client that takes no multipart."""

comptime BATCH_NOT_SUPPORTED_MESSAGE = (
    "Incremental delivery is not implemented for batch requests"
)
"""The error of `runBatchedHttpQuery` for an incremental response."""

comptime PART_HEAD = "content-type: application/json; charset=utf-8\r\n\r\n"
"""The field of each part, and the empty line after it."""

comptime SubsequentFactory = def() raises thin -> AnyStream
"""A function that makes the stream of the subsequent payloads of the
`testing_incremental_execution_results` option."""


def uses_incremental_delivery(document: Document) -> Bool:
    """Tell if a document has a `@defer` or a `@stream` directive.

    Args:
        document: The document.

    Returns:
        True when a directive of the document is `defer` or `stream`.
    """
    var index = 0
    while index < len(document.nodes):
        if document.kind(index) == Kind.DIRECTIVE:
            var name = document.name(index)
            if name == "defer" or name == "stream":
                return True
        index += 1
    return False


struct TestingIncrementalResults(Copyable, Movable):
    """The results that execution gives for each operation: upstream
    `__testing_incrementalExecutionResults`. The tests use it to check the
    transport without execution."""

    var initial_result: String
    """The JSON text of the initial result, sent as it is."""
    var subsequent_results: SubsequentFactory
    """Makes the stream of the subsequent payloads. Each event is the
    JSON of one payload, sent as it is."""

    def __init__(
        out self, initial_result: String, subsequent_results: SubsequentFactory
    ):
        """Make the results.

        Args:
            initial_result: The JSON text of the initial result.
            subsequent_results: The function that makes the payloads.
        """
        self.initial_result = initial_result
        self.subsequent_results = subsequent_results


struct SubsequentPayload(Movable):
    """One subsequent payload, formatted: upstream
    `GraphQLExperimentalFormattedSubsequentIncrementalExecutionResultAlpha9`.
    """

    var json: String
    """The JSON text of the payload. A plugin can replace it."""
    var has_next: Bool
    """The `hasNext` of the payload: whether another payload follows."""

    def __init__(out self, var json: String, has_next: Bool):
        """Make a payload.

        Args:
            json: Its JSON text.
            has_next: Its `hasNext`.
        """
        self.json = json^
        self.has_next = has_next


struct IncrementalResults(Movable):
    """The subsequent results of a response: the stream of an incremental
    execution, or the stream of the testing option."""

    var stream: Optional[SubsequentResultStream]
    """The subsequent results of `experimental_execute_incrementally`."""
    var testing: Optional[AnyStream]
    """The payloads of `testing_incremental_execution_results`."""
    var finished: Bool
    """Whether the last payload is out, or the results are closed."""

    def __init__(out self, var stream: SubsequentResultStream):
        """Hold the results of an execution.

        Args:
            stream: The stream of the subsequent results.
        """
        self.stream = stream^
        self.testing = None
        self.finished = False

    def __init__(out self, var testing: AnyStream):
        """Hold the payloads of the testing option.

        Args:
            testing: The stream of the JSON of each payload.
        """
        self.stream = None
        self.testing = testing^
        self.finished = False

    def close(mut self):
        """Stop the results, as upstream `return()` of the generator."""
        if self.stream:
            self.stream.value().close()
        if self.testing:
            self.testing.value().close()
        self.finished = True


def write_entry(
    mut out: String, entry: IncrementalResult, errors: Optional[String]
):
    """Write one entry of `incremental`, with its errors formatted.

    Args:
        out: The text to append to.
        entry: The entry.
        errors: The JSON array of its formatted errors, if it has errors.
    """
    out += '{"id":' + quote_json_string(entry.id)
    out += ',"items":' if entry.is_stream else ',"data":'
    out += stringify(entry.document, entry.root)
    if errors:
        out += ',"errors":' + errors.value()
    if entry.sub_path:
        out += ',"subPath":'
        write_path(out, entry.sub_path)
    out += "}"


def first_part(initial_json: StringSlice, has_next: Bool) -> String:
    """Write the first part of the body: upstream `writeMultipartBody`.

    Args:
        initial_json: The JSON text of the initial result.
        has_next: Its `hasNext`.

    Returns:
        The bytes of the first part and the delimiter after it.
    """
    var out = String("\r\n---\r\n")
    out += PART_HEAD
    out += initial_json
    out += "\r\n---\r\n" if has_next else "\r\n-----\r\n"
    return out^


def next_part(payload: SubsequentPayload) -> String:
    """Write the part of one subsequent payload: upstream
    `writeMultipartBody`.

    Args:
        payload: The payload.

    Returns:
        The bytes of the part and the delimiter after it.
    """
    var out = String(PART_HEAD)
    out += payload.json
    out += "\r\n---\r\n" if payload.has_next else "\r\n-----\r\n"
    return out^
