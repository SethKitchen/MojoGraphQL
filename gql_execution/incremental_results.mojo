# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The payloads of incremental delivery: `pending`, `incremental`,
`completed` and `hasNext`.

Port of the result types of graphql-js v17.0.2
`execution/incremental/IncrementalExecutor.ts` (`PendingResult`,
`CompletedResult`, `IncrementalDeferResult`, `IncrementalStreamResult`,
`InitialIncrementalExecutionResult` and
`SubsequentIncrementalExecutionResult`), and of the payload assembly of
`IncrementalPublisher._handleBatch`.

`to_json` writes the text of graphql-js `JSON.stringify(result)`: the
keys and their order are the same.

- The initial result: `{"errors":[...],"data":{...},"pending":[...],
  "hasNext":true}`.
- A subsequent result: `{"hasNext":...,"pending":[...],
  "incremental":[...],"completed":[...]}`. An empty list is left out.
- A deferred fragment entry: `{"id":"0","data":{...},"errors":[...],
  "subPath":[...]}`. A stream entry: `{"id":"0","items":[...],
  "errors":[...]}`.

**Differences from upstream.** None in the JSON.
"""

from gql_json.value import JsonDocument
from gql_json.writer import stringify
from gql_language.error import GraphQLError, PathSegment, quote_json_string


def write_path(mut out: String, path: List[PathSegment]):
    """Write a response path as a JSON array.

    Args:
        out: The text to append to.
        path: The path: keys and indexes.
    """
    out += "["
    var index = 0
    while index < len(path):
        if index > 0:
            out += ","
        if path[index].is_index():
            out += String(path[index].index)
        else:
            out += quote_json_string(path[index].key)
        index += 1
    out += "]"


def write_errors(mut out: String, errors: List[GraphQLError]):
    """Write errors as a JSON array.

    Args:
        out: The text to append to.
        errors: The errors.
    """
    out += "["
    var index = 0
    while index < len(errors):
        if index > 0:
            out += ","
        out += errors[index].to_json()
        index += 1
    out += "]"


struct PendingResult(Copyable, Movable):
    """A deferred fragment or a stream that the client must wait for:
    graphql-js `PendingResult`."""

    var id: String
    """The id that later payloads use."""
    var path: List[PathSegment]
    """The response path of the fragment or of the list."""
    var label: Optional[String]
    """The `label` argument of `@defer` or `@stream`, if any."""

    def __init__(
        out self,
        id: String,
        var path: List[PathSegment],
        label: Optional[String],
    ):
        """Make a pending result.

        Args:
            id: The id.
            path: The response path.
            label: The label, or None.
        """
        self.id = id
        self.path = path^
        self.label = label

    def write_json(self, mut out: String):
        """Write `{"id":...,"path":[...],"label":...}`.

        Args:
            out: The text to append to.
        """
        out += '{"id":' + quote_json_string(self.id) + ',"path":'
        write_path(out, self.path)
        if self.label:
            out += ',"label":' + quote_json_string(self.label.value())
        out += "}"


struct CompletedResult(Copyable, Movable):
    """A deferred fragment or a stream that is complete: graphql-js
    `CompletedResult`."""

    var id: String
    """The id of the pending result."""
    var errors: List[GraphQLError]
    """The error that failed it, or empty for a success."""

    def __init__(out self, id: String, var errors: List[GraphQLError]):
        """Make a completed result.

        Args:
            id: The id.
            errors: The errors; empty for a success.
        """
        self.id = id
        self.errors = errors^

    def write_json(self, mut out: String):
        """Write `{"id":...,"errors":[...]}`.

        Args:
            out: The text to append to.
        """
        out += '{"id":' + quote_json_string(self.id)
        if self.errors:
            out += ',"errors":'
            write_errors(out, self.errors)
        out += "}"


struct IncrementalResult(Movable):
    """The data of a deferred fragment, or items of a stream: graphql-js
    `IncrementalDeferResult` or `IncrementalStreamResult`."""

    var id: String
    """The id of the pending result."""
    var is_stream: Bool
    """True for stream items; False for deferred data."""
    var document: JsonDocument
    """The document of `root`."""
    var root: Int
    """The data object, or the array of the items."""
    var errors: List[GraphQLError]
    """The field errors of the data or of the items."""
    var sub_path: List[PathSegment]
    """The path of the data under the pending path; empty when none."""

    def __init__(
        out self,
        id: String,
        is_stream: Bool,
        var document: JsonDocument,
        root: Int,
        var errors: List[GraphQLError],
        var sub_path: List[PathSegment],
    ):
        """Make an incremental entry.

        Args:
            id: The id.
            is_stream: True for stream items.
            document: The document of the data or the items.
            root: The data object or the items array in `document`.
            errors: The field errors.
            sub_path: The sub-path, or empty.
        """
        self.id = id
        self.is_stream = is_stream
        self.document = document^
        self.root = root
        self.errors = errors^
        self.sub_path = sub_path^

    def write_json(self, mut out: String):
        """Write the entry, with the keys in the graphql-js order.

        Args:
            out: The text to append to.
        """
        out += '{"id":' + quote_json_string(self.id)
        out += ',"items":' if self.is_stream else ',"data":'
        out += stringify(self.document, self.root)
        if self.errors:
            out += ',"errors":'
            write_errors(out, self.errors)
        if self.sub_path:
            out += ',"subPath":'
            write_path(out, self.sub_path)
        out += "}"


struct InitialIncrementalExecutionResult(Movable):
    """The first payload of an incremental execution: graphql-js
    `InitialIncrementalExecutionResult`."""

    var data: JsonDocument
    """The data; its root is the data object."""
    var errors: List[GraphQLError]
    """The errors of the initial data."""
    var pending: List[PendingResult]
    """The deferred fragments and the streams to wait for."""
    var has_next: Bool
    """Always True: a subsequent payload follows."""

    def __init__(
        out self,
        var data: JsonDocument,
        var errors: List[GraphQLError],
        var pending: List[PendingResult],
    ):
        """Make an initial result.

        Args:
            data: The data document.
            errors: The errors.
            pending: The pending results.
        """
        self.data = data^
        self.errors = errors^
        self.pending = pending^
        self.has_next = True

    def to_json(self) -> String:
        """Return the result as graphql-js `JSON.stringify(result)` writes
        it.

        Returns:
            `{"errors":[...],"data":{...},"pending":[...],"hasNext":true}`;
            no `errors` key when there is no error.
        """
        var out = String("{")
        if self.errors:
            out += '"errors":'
            write_errors(out, self.errors)
            out += ","
        out += '"data":' + stringify(self.data, self.data.root)
        out += ',"pending":['
        var index = 0
        while index < len(self.pending):
            if index > 0:
                out += ","
            self.pending[index].write_json(out)
            index += 1
        out += '],"hasNext":' + ("true" if self.has_next else "false")
        return out + "}"


struct SubsequentIncrementalExecutionResult(Movable):
    """A later payload of an incremental execution: graphql-js
    `SubsequentIncrementalExecutionResult`."""

    var pending: List[PendingResult]
    """The new deferred fragments and streams."""
    var incremental: List[IncrementalResult]
    """The deferred data and the stream items."""
    var completed: List[CompletedResult]
    """The fragments and streams that are complete."""
    var has_next: Bool
    """True when another payload follows."""

    def __init__(out self):
        """Make an empty payload, with `hasNext` True."""
        self.pending = List[PendingResult]()
        self.incremental = List[IncrementalResult]()
        self.completed = List[CompletedResult]()
        self.has_next = True

    def to_json(self) -> String:
        """Return the payload as graphql-js `JSON.stringify(result)` writes
        it.

        Returns:
            `{"hasNext":...,"pending":[...],"incremental":[...],
            "completed":[...]}`, with no key for an empty list.
        """
        var out = String('{"hasNext":')
        out += "true" if self.has_next else "false"
        var index = 0
        if self.pending:
            out += ',"pending":['
            while index < len(self.pending):
                if index > 0:
                    out += ","
                self.pending[index].write_json(out)
                index += 1
            out += "]"
        if self.incremental:
            out += ',"incremental":['
            index = 0
            while index < len(self.incremental):
                if index > 0:
                    out += ","
                self.incremental[index].write_json(out)
                index += 1
            out += "]"
        if self.completed:
            out += ',"completed":['
            index = 0
            while index < len(self.completed):
                if index > 0:
                    out += ","
                self.completed[index].write_json(out)
                index += 1
            out += "]"
        return out + "}"


def add_path(mut document: JsonDocument, path: List[PathSegment]) -> Int:
    """Add a response path to a document as an array.

    Args:
        document: The document.
        path: The path.

    Returns:
        The array node.
    """
    var array = document.add_array()
    var index = 0
    while index < len(path):
        if path[index].is_index():
            document.append(array, document.add_int(Int64(path[index].index)))
        else:
            document.append(array, document.add_string(path[index].key))
        index += 1
    return array


def add_errors(mut document: JsonDocument, errors: List[GraphQLError]) -> Int:
    """Add errors to a document as an array, with the keys of
    `GraphQLError.to_json`. An execution error has no extensions.

    Args:
        document: The document.
        errors: The errors.

    Returns:
        The array node.
    """
    var array = document.add_array()
    var index = 0
    while index < len(errors):
        ref error = errors[index]
        var object = document.add_object()
        document.add_member(
            object, "message", document.add_string(error.message)
        )
        if error.locations:
            var locations = document.add_array()
            var at = 0
            while at < len(error.locations):
                var location = document.add_object()
                document.add_member(
                    location,
                    "line",
                    document.add_int(Int64(error.locations[at].line)),
                )
                document.add_member(
                    location,
                    "column",
                    document.add_int(Int64(error.locations[at].column)),
                )
                document.append(locations, location)
                at += 1
            document.add_member(object, "locations", locations)
        if error.path:
            document.add_member(object, "path", add_path(document, error.path))
        document.append(array, object)
        index += 1
    return array


def add_pending(
    mut document: JsonDocument, pending: List[PendingResult]
) -> Int:
    """Add pending results to a document as an array.

    Args:
        document: The document.
        pending: The pending results.

    Returns:
        The array node.
    """
    var array = document.add_array()
    var index = 0
    while index < len(pending):
        ref entry = pending[index]
        var object = document.add_object()
        document.add_member(object, "id", document.add_string(entry.id))
        document.add_member(object, "path", add_path(document, entry.path))
        if entry.label:
            document.add_member(
                object, "label", document.add_string(entry.label.value())
            )
        document.append(array, object)
        index += 1
    return array


def subsequent_document(
    result: SubsequentIncrementalExecutionResult,
) -> JsonDocument:
    """Return a subsequent result as a JSON document, with the keys of
    `SubsequentIncrementalExecutionResult.to_json`.

    Args:
        result: The payload.

    Returns:
        The document; its root is the payload object.
    """
    var document = JsonDocument()
    var object = document.add_object()
    document.add_member(object, "hasNext", document.add_bool(result.has_next))
    if result.pending:
        document.add_member(
            object, "pending", add_pending(document, result.pending)
        )
    var index = 0
    if result.incremental:
        var array = document.add_array()
        while index < len(result.incremental):
            ref entry = result.incremental[index]
            var item = document.add_object()
            document.add_member(item, "id", document.add_string(entry.id))
            document.add_member(
                item,
                "items" if entry.is_stream else "data",
                document.add_copy(entry.document, entry.root),
            )
            if entry.errors:
                document.add_member(
                    item, "errors", add_errors(document, entry.errors)
                )
            if entry.sub_path:
                document.add_member(
                    item, "subPath", add_path(document, entry.sub_path)
                )
            document.append(array, item)
            index += 1
        document.add_member(object, "incremental", array)
    if result.completed:
        var array = document.add_array()
        index = 0
        while index < len(result.completed):
            ref entry = result.completed[index]
            var item = document.add_object()
            document.add_member(item, "id", document.add_string(entry.id))
            if entry.errors:
                document.add_member(
                    item, "errors", add_errors(document, entry.errors)
                )
            document.append(array, item)
            index += 1
        document.add_member(object, "completed", array)
    document.root = object
    return document^
