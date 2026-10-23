# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Telemetry ingest and roll-ups for a Forge variant.

A customer router sends one event per operation. Forge stores per-operation
counts, a short recent log, and one-minute windows. Forge does not run the
operation. It only records what the customer reports.

Differences from upstream: none; there is no upstream.
"""

from gql_forge.catalog import Catalog
from gql_forge.store import (
    parse_object,
    read_file,
    read_object_bool,
    read_object_int,
    read_object_string,
    read_object_string_or,
    unix_time,
)
from gql_json.value import JsonKind
from gql_json.writer import JsonWriter

comptime MAX_SAMPLES = 64
"""How many recent durations one operation keeps."""
comptime MAX_RECENT = 50
"""How many recent events the log keeps."""
comptime MAX_WINDOWS = 60
"""How many one-minute windows the roll-up keeps."""
comptime WINDOW_SECONDS = 60
"""The width of one insights window."""


@fieldwise_init
struct OperationStats(Copyable, Movable):
    """Roll-up of one operation name."""

    var name: String
    """The operation name, or `(anonymous)`."""
    var signature: String
    """An optional query signature. Empty when the client sent none."""
    var count: Int
    """How many events."""
    var errors: Int
    """How many events that were not ok."""
    var total_ms: Int
    """The sum of durations."""
    var min_ms: Int
    """The shortest duration."""
    var max_ms: Int
    """The longest duration."""
    var samples: List[Int]
    """Recent durations, oldest first, at most `MAX_SAMPLES`."""


@fieldwise_init
struct RecentEvent(Copyable, Movable):
    """One ingested event, for the operations log."""

    var at: Int
    """Seconds since the Unix epoch."""
    var name: String
    """The operation name."""
    var duration_ms: Int
    """The duration."""
    var ok: Bool
    """Whether the operation succeeded."""
    var errors: Int
    """How many GraphQL errors the client reported."""
    var client_name: String
    """An optional client name."""


@fieldwise_init
struct MinuteWindow(Copyable, Movable):
    """One minute of traffic."""

    var at: Int
    """The start of the minute, Unix seconds."""
    var requests: Int
    """How many events in the minute."""
    var errors: Int
    """How many events that were not ok."""
    var total_ms: Int
    """The sum of durations."""


@fieldwise_init
struct TelemetryEvent(Copyable, Movable):
    """One event that a customer router sends."""

    var org: String
    """The organization slug."""
    var graph: String
    """The graph ref."""
    var variant: String
    """The variant name."""
    var name: String
    """The operation name."""
    var signature: String
    """An optional query signature."""
    var duration_ms: Int
    """The duration. Negative values are stored as 0."""
    var ok: Bool
    """Whether the operation succeeded."""
    var errors: Int
    """How many GraphQL errors the client reported."""
    var client_name: String
    """An optional client name."""
    var at: Int
    """Seconds since the Unix epoch. 0 means now."""


@fieldwise_init
struct TelemetryLog(Copyable, Movable):
    """The stored roll-up of one variant."""

    var operations: List[OperationStats]
    """Per-operation stats."""
    var recent: List[RecentEvent]
    """Recent events, newest last."""
    var windows: List[MinuteWindow]
    """One-minute windows, oldest first."""


def percentile(samples: List[Int], n: Int) -> Int:
    """Return an approximate percentile of integer samples.

    Args:
        samples: The values.
        n: The percentile, from 0 to 100.

    Returns:
        0 when there are no samples. Otherwise the value at index
        `n * (len-1) / 100` of the sorted samples. `n` below 0 uses 0.
        `n` above 100 uses 100.
    """
    var count = len(samples)
    if count == 0:
        return 0
    var rank = n
    if rank < 0:
        rank = 0
    if rank > 100:
        rank = 100
    var ordered = List[Int]()
    for sample in samples:
        ordered.append(sample)
    var i = 1
    while i < len(ordered):
        var j = i
        while j > 0 and ordered[j] < ordered[j - 1]:
            var tmp = ordered[j]
            ordered[j] = ordered[j - 1]
            ordered[j - 1] = tmp
            j -= 1
        i += 1
    var index = (rank * (count - 1)) // 100
    return ordered[index]


def empty_log() -> TelemetryLog:
    """Return an empty roll-up.

    Returns:
        No operations, recent events or windows.
    """
    return TelemetryLog(
        List[OperationStats](), List[RecentEvent](), List[MinuteWindow]()
    )


def parse_telemetry_event(text: StringSlice) raises -> TelemetryEvent:
    """Read one ingest payload.

    Args:
        text: The JSON object.

    Returns:
        The event. `durationMs` below 0 becomes 0. `operationName` is
        used when `name` is missing.

    Raises:
        Error: When the JSON is not an object with string `org`, `graph`
            and `variant`.
    """
    var document = parse_object(text)
    var root = document.root
    var name = read_object_string_or(document, root, "name", "")
    if name.byte_length() == 0:
        name = read_object_string_or(document, root, "operationName", "")
    if name.byte_length() == 0:
        name = String("(anonymous)")
    var duration = read_object_int(document, root, "durationMs", 0)
    if duration < 0:
        duration = 0
    var errors = read_object_int(document, root, "errors", 0)
    if errors < 0:
        errors = 0
    var ok = read_object_bool(document, root, "ok", errors == 0)
    if errors > 0:
        ok = False
    var at = read_object_int(document, root, "at", 0)
    return TelemetryEvent(
        read_object_string(document, root, "org"),
        read_object_string(document, root, "graph"),
        read_object_string(document, root, "variant"),
        name^,
        read_object_string_or(document, root, "signature", ""),
        duration,
        ok,
        errors,
        read_object_string_or(document, root, "clientName", ""),
        at,
    )


def _push_sample(mut samples: List[Int], value: Int):
    """Append a duration, and drop the oldest when the list is full.

    Args:
        samples: The samples.
        value: The new duration.
    """
    samples.append(value)
    if len(samples) > MAX_SAMPLES:
        _ = samples.pop(0)


def apply_event(mut log: TelemetryLog, event: TelemetryEvent, at: Int):
    """Add one event to a roll-up.

    Args:
        log: The roll-up.
        event: The event.
        at: The event time.
    """
    var found = -1
    for index in range(len(log.operations)):
        if log.operations[index].name == event.name:
            found = index
    if found < 0:
        var stats = OperationStats(
            event.name.copy(),
            event.signature.copy(),
            1,
            0 if event.ok else 1,
            event.duration_ms,
            event.duration_ms,
            event.duration_ms,
            List[Int](),
        )
        stats.samples.append(event.duration_ms)
        log.operations.append(stats^)
    else:
        log.operations[found].count += 1
        if not event.ok:
            log.operations[found].errors += 1
        log.operations[found].total_ms += event.duration_ms
        if event.duration_ms < log.operations[found].min_ms:
            log.operations[found].min_ms = event.duration_ms
        if event.duration_ms > log.operations[found].max_ms:
            log.operations[found].max_ms = event.duration_ms
        if (
            event.signature.byte_length() > 0
            and log.operations[found].signature.byte_length() == 0
        ):
            log.operations[found].signature = event.signature.copy()
        _push_sample(log.operations[found].samples, event.duration_ms)
    log.recent.append(
        RecentEvent(
            at,
            event.name.copy(),
            event.duration_ms,
            event.ok,
            event.errors,
            event.client_name.copy(),
        )
    )
    if len(log.recent) > MAX_RECENT:
        _ = log.recent.pop(0)
    var start = (at // WINDOW_SECONDS) * WINDOW_SECONDS
    if len(log.windows) == 0 or log.windows[len(log.windows) - 1].at != start:
        log.windows.append(
            MinuteWindow(start, 1, 0 if event.ok else 1, event.duration_ms)
        )
    else:
        var last = len(log.windows) - 1
        log.windows[last].requests += 1
        if not event.ok:
            log.windows[last].errors += 1
        log.windows[last].total_ms += event.duration_ms
    if len(log.windows) > MAX_WINDOWS:
        _ = log.windows.pop(0)


def telemetry_json(log: TelemetryLog) -> String:
    """Write a roll-up as JSON.

    Args:
        log: The roll-up.

    Returns:
        The JSON object.
    """
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("operations")
    writer.begin_array()
    for ref op in log.operations:
        writer.begin_object()
        writer.key("name")
        writer.string(op.name)
        writer.key("signature")
        writer.string(op.signature)
        writer.key("count")
        writer.int(Int64(op.count))
        writer.key("errors")
        writer.int(Int64(op.errors))
        writer.key("totalMs")
        writer.int(Int64(op.total_ms))
        writer.key("minMs")
        writer.int(Int64(op.min_ms))
        writer.key("maxMs")
        writer.int(Int64(op.max_ms))
        writer.key("p50")
        writer.int(Int64(percentile(op.samples, 50)))
        writer.key("p95")
        writer.int(Int64(percentile(op.samples, 95)))
        writer.key("p99")
        writer.int(Int64(percentile(op.samples, 99)))
        writer.key("samples")
        writer.begin_array()
        for sample in op.samples:
            writer.int(Int64(sample))
        writer.end_array()
        writer.end_object()
    writer.end_array()
    writer.key("recent")
    writer.begin_array()
    for ref event in log.recent:
        writer.begin_object()
        writer.key("at")
        writer.int(Int64(event.at))
        writer.key("name")
        writer.string(event.name)
        writer.key("durationMs")
        writer.int(Int64(event.duration_ms))
        writer.key("ok")
        writer.bool(event.ok)
        writer.key("errors")
        writer.int(Int64(event.errors))
        writer.key("clientName")
        writer.string(event.client_name)
        writer.end_object()
    writer.end_array()
    writer.key("windows")
    writer.begin_array()
    for ref window in log.windows:
        writer.begin_object()
        writer.key("at")
        writer.int(Int64(window.at))
        writer.key("requests")
        writer.int(Int64(window.requests))
        writer.key("errors")
        writer.int(Int64(window.errors))
        writer.key("totalMs")
        writer.int(Int64(window.total_ms))
        writer.end_object()
    writer.end_array()
    writer.end_object()
    return writer^.take_string()


def parse_telemetry_log(text: String) raises -> TelemetryLog:
    """Read a stored roll-up.

    Args:
        text: The JSON.

    Returns:
        The roll-up.

    Raises:
        Error: When the JSON is not an object.
    """
    var document = parse_object(text)
    var root = document.root
    var log = empty_log()
    var operations = document.find(root, "operations")
    if operations >= 0 and document.kind(operations) == JsonKind.ARRAY:
        var node = document.first(operations)
        while node >= 0:
            if document.kind(node) == JsonKind.OBJECT:
                var samples = List[Int]()
                var sample_node = document.find(node, "samples")
                if (
                    sample_node >= 0
                    and document.kind(sample_node) == JsonKind.ARRAY
                ):
                    var item = document.first(sample_node)
                    while item >= 0:
                        if document.kind(item) == JsonKind.NUMBER:
                            try:
                                samples.append(Int(atol(document.text(item))))
                            except:
                                samples.append(0)
                        item = document.next(item)
                log.operations.append(
                    OperationStats(
                        read_object_string_or(
                            document, node, "name", "(anonymous)"
                        ),
                        read_object_string_or(document, node, "signature", ""),
                        read_object_int(document, node, "count", 0),
                        read_object_int(document, node, "errors", 0),
                        read_object_int(document, node, "totalMs", 0),
                        read_object_int(document, node, "minMs", 0),
                        read_object_int(document, node, "maxMs", 0),
                        samples^,
                    )
                )
            node = document.next(node)
    var recent = document.find(root, "recent")
    if recent >= 0 and document.kind(recent) == JsonKind.ARRAY:
        var node = document.first(recent)
        while node >= 0:
            if document.kind(node) == JsonKind.OBJECT:
                log.recent.append(
                    RecentEvent(
                        read_object_int(document, node, "at", 0),
                        read_object_string_or(
                            document, node, "name", "(anonymous)"
                        ),
                        read_object_int(document, node, "durationMs", 0),
                        read_object_bool(document, node, "ok", True),
                        read_object_int(document, node, "errors", 0),
                        read_object_string_or(document, node, "clientName", ""),
                    )
                )
            node = document.next(node)
    var windows = document.find(root, "windows")
    if windows >= 0 and document.kind(windows) == JsonKind.ARRAY:
        var node = document.first(windows)
        while node >= 0:
            if document.kind(node) == JsonKind.OBJECT:
                log.windows.append(
                    MinuteWindow(
                        read_object_int(document, node, "at", 0),
                        read_object_int(document, node, "requests", 0),
                        read_object_int(document, node, "errors", 0),
                        read_object_int(document, node, "totalMs", 0),
                    )
                )
            node = document.next(node)
    return log^


def load_log(
    catalog: Catalog, org: StringSlice, graph: StringSlice, variant: StringSlice
) -> TelemetryLog:
    """Read the roll-up of a variant, or an empty log.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.
        variant: The variant name.

    Returns:
        The stored roll-up, or empty when the file is missing or bad.
    """
    try:
        return parse_telemetry_log(
            read_file(catalog.store.telemetry_path(org, graph, variant))
        )
    except:
        return empty_log()


def save_log(
    catalog: Catalog,
    org: StringSlice,
    graph: StringSlice,
    variant: StringSlice,
    log: TelemetryLog,
) raises:
    """Write the roll-up of a variant.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.
        variant: The variant name.
        log: The roll-up.

    Raises:
        Error: When the file cannot be written.
    """
    catalog.store.write_json(
        catalog.store.telemetry_path(org, graph, variant), telemetry_json(log)
    )


def ingest_event(mut catalog: Catalog, event: TelemetryEvent) raises -> String:
    """Ingest one event into the roll-up of its variant.

    Args:
        catalog: The catalog.
        event: The event.

    Returns:
        A JSON object with `accepted`, or `error`.

    Raises:
        Error: When a catalog or telemetry file cannot be written.
    """
    var writer = JsonWriter()
    writer.begin_object()
    if not catalog.has_variant(event.org, event.graph, event.variant):
        writer.key("error")
        writer.string("Variant '" + event.variant + "' is not in Forge.")
        writer.end_object()
        return writer^.take_string()
    var log = load_log(catalog, event.org, event.graph, event.variant)
    var at = event.at
    if at <= 0:
        at = unix_time()
    apply_event(log, event, at)
    save_log(catalog, event.org, event.graph, event.variant, log)
    writer.key("accepted")
    writer.bool(True)
    writer.end_object()
    return writer^.take_string()


def insights_json(log: TelemetryLog) -> String:
    """Write dashboard numbers for a roll-up.

    Args:
        log: The roll-up.

    Returns:
        Totals, percentiles and per-operation rows.
    """
    var requests = 0
    var errors = 0
    var total_ms = 0
    var samples = List[Int]()
    for ref op in log.operations:
        requests += op.count
        errors += op.errors
        total_ms += op.total_ms
        for sample in op.samples:
            samples.append(sample)
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("requests")
    writer.int(Int64(requests))
    writer.key("errors")
    writer.int(Int64(errors))
    writer.key("errorRate")
    if requests == 0:
        writer.int(Int64(0))
    else:
        writer.int(Int64((errors * 10000) // requests))
    writer.key("avgMs")
    if requests == 0:
        writer.int(Int64(0))
    else:
        writer.int(Int64(total_ms // requests))
    writer.key("p50")
    writer.int(Int64(percentile(samples, 50)))
    writer.key("p95")
    writer.int(Int64(percentile(samples, 95)))
    writer.key("p99")
    writer.int(Int64(percentile(samples, 99)))
    writer.key("operations")
    writer.begin_array()
    for ref op in log.operations:
        writer.begin_object()
        writer.key("name")
        writer.string(op.name)
        writer.key("count")
        writer.int(Int64(op.count))
        writer.key("errors")
        writer.int(Int64(op.errors))
        writer.key("p50")
        writer.int(Int64(percentile(op.samples, 50)))
        writer.key("p95")
        writer.int(Int64(percentile(op.samples, 95)))
        writer.key("p99")
        writer.int(Int64(percentile(op.samples, 99)))
        writer.key("maxMs")
        writer.int(Int64(op.max_ms))
        writer.end_object()
    writer.end_array()
    writer.key("windows")
    writer.begin_array()
    for ref window in log.windows:
        writer.begin_object()
        writer.key("at")
        writer.int(Int64(window.at))
        writer.key("requests")
        writer.int(Int64(window.requests))
        writer.key("errors")
        writer.int(Int64(window.errors))
        writer.end_object()
    writer.end_array()
    writer.key("recent")
    writer.begin_array()
    for ref event in log.recent:
        writer.begin_object()
        writer.key("at")
        writer.int(Int64(event.at))
        writer.key("name")
        writer.string(event.name)
        writer.key("durationMs")
        writer.int(Int64(event.duration_ms))
        writer.key("ok")
        writer.bool(event.ok)
        writer.key("errors")
        writer.int(Int64(event.errors))
        writer.key("clientName")
        writer.string(event.client_name)
        writer.end_object()
    writer.end_array()
    writer.end_object()
    return writer^.take_string()
