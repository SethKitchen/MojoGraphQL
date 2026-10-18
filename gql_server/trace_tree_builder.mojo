# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The tree of a trace: one node for each resolved field and each error.

Port of Apollo Server 5.5.1 `plugin/traceTreeBuilder.ts`
(`TraceTreeBuilder`, `dateToProtoTimestamp`) and the `SendErrorsOptions`
type of `plugin/usageReporting/options.ts`.

`TraceTreeBuilder.start_timing` and `stop_timing` set the times of the
trace. `will_resolve_field` adds the node of a field, and
`did_encounter_errors` adds the errors to the nodes of their paths.

**Differences from upstream.**
- `will_resolve_field` gets a `FieldTiming` of `gql_execution`, which
  has the start and the end of the resolver. Upstream gets the
  `GraphQLResolveInfo` and returns a function that sets the end. The
  inline trace plugin gives the timings to the builder after execution,
  in the order that the resolvers started.
- The wall clock comes from `clock_gettime` with `CLOCK_REALTIME`. The
  duration and the node times come from `perf_counter_ns`, as upstream
  uses `process.hrtime`.
- A `transform` function returns a `ServerError` or None. Upstream can
  also return another value, which keeps the original error.
- An error with a `serviceName` extension is skipped, whatever the value
  of the extension. Upstream skips it when the value is truthy.
- `addProtobufError called with invalid path!` is not ported: an error
  with no path goes on the root, and every other path has a node.
"""

from std.collections import Dict
from std.ffi import external_call
from std.memory import stack_allocation
from std.time import perf_counter_ns

from gql_execution.execute import FieldTiming
from gql_language.error import PathSegment, quote_json_string
from gql_schema.definition import Schema
from gql_server.error_normalize import FormattedError
from gql_server.errors import ServerError, find_extension, set_extension
from gql_server.usage_reporting_protobuf import (
    Timestamp,
    Trace,
    TraceError,
    TraceLocation,
    TraceNode,
)

comptime TransformErrorFunction = def(
    var error: ServerError
) raises thin -> Optional[ServerError]
"""The `transform` of `SendErrorsOptions`: it gets a copy of an error
and returns the error for the trace, or None to leave it out."""


@fieldwise_init
struct SendErrorsKind(Equatable, ImplicitlyCopyable, Writable):
    """The form of `SendErrorsOptions`."""

    var value: UInt8
    """The code: 0 masked, 1 unmodified, 2 transform."""

    comptime MASKED = SendErrorsKind(0)
    """`{ masked: true }`: the message is `<masked>`, with no extensions
    of the error."""
    comptime UNMODIFIED = SendErrorsKind(1)
    """`{ unmodified: true }`: the error as it is."""
    comptime TRANSFORM = SendErrorsKind(2)
    """`{ transform }`: the error that a function returns."""

    def is_valid(self) -> Bool:
        """Return True for a defined kind.

        Returns:
            Whether the code is 0, 1 or 2.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the upstream key, such as `masked`.

        Args:
            writer: The writer.
        """
        if self == SendErrorsKind.MASKED:
            writer.write("masked")
        elif self == SendErrorsKind.UNMODIFIED:
            writer.write("unmodified")
        elif self == SendErrorsKind.TRANSFORM:
            writer.write("transform")
        else:
            writer.write("<invalid>")


struct SendErrorsOptions(Copyable, Movable):
    """How the errors go into a trace: upstream `SendErrorsOptions`."""

    var kind: SendErrorsKind
    """The form."""
    var transform: Optional[TransformErrorFunction]
    """The function of the `transform` form."""

    def __init__(out self):
        """Use `{ masked: true }`, the upstream default."""
        self.kind = SendErrorsKind.MASKED
        self.transform = None

    @staticmethod
    def unmodified() -> SendErrorsOptions:
        """Return `{ unmodified: true }`.

        Returns:
            The options.
        """
        var options = SendErrorsOptions()
        options.kind = SendErrorsKind.UNMODIFIED
        return options^

    @staticmethod
    def with_transform(transform: TransformErrorFunction) -> SendErrorsOptions:
        """Return `{ transform }`.

        Args:
            transform: The function.

        Returns:
            The options.
        """
        var options = SendErrorsOptions()
        options.kind = SendErrorsKind.TRANSFORM
        options.transform = transform
        return options^


def _internal_error(message: StringSlice) -> Error:
    """Upstream `internalError`."""
    return Error("[internal apollo-server error] " + String(message))


def wall_clock_ns() -> Int:
    """Return the wall clock time, as `clock_gettime(CLOCK_REALTIME)`.

    Returns:
        The nanoseconds since the Unix epoch.
    """
    var spec = stack_allocation[2, Int]()
    _ = external_call["clock_gettime", Int32](
        Int32(0), spec.unsafe_bitcast[NoneType]()
    )
    return spec[unsafe_offset=0] * 1_000_000_000 + spec[unsafe_offset=1]


def date_to_proto_timestamp(nanos: Int) -> Timestamp:
    """Return a timestamp of the milliseconds of a time: upstream
    `dateToProtoTimestamp` of a JavaScript `Date`.

    Args:
        nanos: The nanoseconds since the Unix epoch.

    Returns:
        The seconds and the nanoseconds of the milliseconds.
    """
    var total_millis = nanos // 1_000_000
    var millis = total_millis % 1000
    return Timestamp((total_millis - millis) // 1000, millis * 1_000_000)


def _path_string(path: List[PathSegment], length: Int) -> String:
    """Upstream `responsePathAsString`: the keys and indexes of the first
    `length` segments, joined with `.`."""
    var out = String("")
    for index in range(length):
        if index > 0:
            out += "."
        if path[index].is_index():
            out += String(path[index].index)
        else:
            out += path[index].key
    return out^


def error_to_protobuf_error(error: ServerError) -> TraceError:
    """Return the trace error of an error: upstream
    `errorToProtobufError`.

    Args:
        error: The error.

    Returns:
        The message, the locations, and the JSON of `JSON.stringify` of
        the error.
    """
    var out = TraceError(error.message)
    var formatted = FormattedError(error.message)
    for ref location in error.locations:
        out.location.append(TraceLocation(location.line, location.column))
        formatted.locations.append(location)
    formatted.path = error.path.copy()
    formatted.extensions = error.extensions.copy()
    formatted.has_extensions = len(error.extensions) > 0
    out.json = formatted.to_json()
    return out^


struct TraceTreeBuilder(Movable):
    """The trace of one request: upstream `TraceTreeBuilder`."""

    var trace: Trace
    """The trace. Its field execution weight is 1, as upstream."""
    var start_hr_time: Optional[Int]
    """The `perf_counter_ns` of `start_timing`."""
    var stopped: Bool
    """Whether `stop_timing` ran."""
    var nodes: Dict[String, Int]
    """The node of each response path, as `responsePathAsString`."""
    var masked_by: String
    """The `maskedBy` extension of a masked error."""
    var send_errors: SendErrorsOptions
    """How the errors go into the trace."""

    def __init__(
        out self,
        masked_by: String,
        var send_errors: SendErrorsOptions = SendErrorsOptions(),
    ):
        """Make a builder: `new TraceTreeBuilder({maskedBy, sendErrors})`.

        Args:
            masked_by: The `maskedBy` extension of a masked error.
            send_errors: How the errors go into the trace.
        """
        self.trace = Trace()
        self.trace.field_execution_weight = 1
        self.start_hr_time = None
        self.stopped = False
        self.nodes = Dict[String, Int]()
        self.nodes[String("")] = 0
        self.masked_by = masked_by
        self.send_errors = send_errors^

    def start_timing(mut self) raises:
        """Set the start time of the trace: upstream `startTiming`.

        Raises:
            Error: When the timing started before, or stopped.
        """
        if self.start_hr_time:
            raise _internal_error("startTiming called twice!")
        if self.stopped:
            raise _internal_error("startTiming called after stopTiming!")
        self.trace.start_time = date_to_proto_timestamp(wall_clock_ns())
        self.start_hr_time = Int(perf_counter_ns())

    def stop_timing(mut self) raises:
        """Set the end time and the duration: upstream `stopTiming`.

        Raises:
            Error: When the timing did not start, or stopped before.
        """
        if not self.start_hr_time:
            raise _internal_error("stopTiming called before startTiming!")
        if self.stopped:
            raise _internal_error("stopTiming called twice!")
        self.trace.duration_ns = (
            Int(perf_counter_ns()) - self.start_hr_time.value()
        )
        self.trace.end_time = date_to_proto_timestamp(wall_clock_ns())
        self.stopped = True

    def will_resolve_field(
        mut self, timing: FieldTiming, schema: Schema
    ) raises:
        """Add the node of a resolved field: upstream `willResolveField`
        and the function that it returns.

        Args:
            timing: The field, its path and the times of its resolver.
            schema: The schema of the execution.

        Raises:
            Error: When the timing did not start. After `stop_timing`
                the field is ignored, as upstream.
        """
        if not self.start_hr_time:
            raise _internal_error("willResolveField called before startTiming!")
        if self.stopped:
            return
        var start = self.start_hr_time.value()
        var node = self._new_node(timing.path, len(timing.path))
        ref found = self.trace.nodes[node]
        found.type = schema.type_name(timing.return_type)
        found.parent_type = schema.types[timing.parent_type].name
        found.start_time = timing.start_ns - start
        ref last = timing.path[len(timing.path) - 1]
        if last.key != timing.field_name:
            found.original_field_name = timing.field_name
        found.end_time = timing.end_ns - start

    def did_encounter_errors(mut self, errors: List[ServerError]) raises:
        """Add errors to the nodes of their paths: upstream
        `didEncounterErrors`.

        Args:
            errors: The errors.

        Raises:
            Error: When the timing did not start or stopped, or a
                `transform` function raises.
        """
        for ref error in errors:
            if find_extension(error.extensions, "serviceName") >= 0:
                continue
            var reported = self._transform_and_normalize_error(error)
            if not reported:
                continue
            ref found = reported.value()
            self._add_protobuf_error(found.path, error_to_protobuf_error(found))

    def _add_protobuf_error(
        mut self, path: List[PathSegment], var error: TraceError
    ) raises:
        """Upstream `addProtobufError`."""
        if not self.start_hr_time:
            raise _internal_error("addProtobufError called before startTiming!")
        if self.stopped:
            raise _internal_error("addProtobufError called after stopTiming!")
        var key = _path_string(path, len(path))
        var node = self.nodes.get(key, -1)
        if node < 0:
            node = self._new_node(path, len(path))
        self.trace.nodes[node].error.append(error^)

    def _new_node(mut self, path: List[PathSegment], length: Int) -> Int:
        """Upstream `newNode`: the node of the first `length` segments of
        a path, under its parent."""
        var node = TraceNode()
        ref last = path[length - 1]
        if last.is_index():
            node.index = last.index
        else:
            node.response_name = last.key
        var index = len(self.trace.nodes)
        self.trace.nodes.append(node^)
        self.nodes[_path_string(path, length)] = index
        var parent = self._ensure_parent_node(path, length)
        self.trace.nodes[parent].child.append(index)
        return index

    def _ensure_parent_node(
        mut self, path: List[PathSegment], length: Int
    ) -> Int:
        """Upstream `ensureParentNode`."""
        var parent = self.nodes.get(_path_string(path, length - 1), -1)
        if parent >= 0:
            return parent
        return self._new_node(path, length - 1)

    def _transform_and_normalize_error(
        self, error: ServerError
    ) raises -> Optional[ServerError]:
        """Upstream `transformAndNormalizeError`: the error for the trace,
        with the locations and the path of the original."""
        if self.send_errors.kind == SendErrorsKind.UNMODIFIED:
            return error.copy()
        var rewritten: Optional[ServerError]
        if self.send_errors.kind == SendErrorsKind.MASKED:
            var masked = ServerError("<masked>")
            set_extension(
                masked.extensions, "maskedBy", quote_json_string(self.masked_by)
            )
            rewritten = masked^
        else:
            rewritten = self.send_errors.transform.value()(error.copy())
        if not rewritten:
            return None
        var out = ServerError(rewritten.value().message)
        out.locations = error.locations.copy()
        out.path = error.path.copy()
        out.extensions = rewritten.value().extensions.copy()
        return out^
