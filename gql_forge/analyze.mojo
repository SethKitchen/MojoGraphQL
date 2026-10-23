# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Answer a question about a graph from schema, diffs and telemetry.

The analyst is local and deterministic. It classifies the question, then
reads the evidence that Forge already stores. It does not call a remote
model. A later model can use the same findings as context.

Differences from upstream: none; there is no upstream.
"""

from gql_forge.catalog import Catalog
from gql_forge.compare import compare_variants
from gql_forge.names import contains_folded
from gql_forge.schema_view import user_type_names
from gql_forge.store import read_file
from gql_forge.telemetry import load_log, percentile
from gql_json.writer import JsonWriter
from gql_schema.build import build_schema


@fieldwise_init
struct AnalyzeIntent(Equatable, ImplicitlyCopyable, Writable):
    """What a question is about."""

    var value: UInt8
    """The intent index; see `is_valid`."""

    comptime HEALTH = AnalyzeIntent(0)
    """A summary of the graph and its variants."""
    comptime COMPARE = AnalyzeIntent(1)
    """A comparison of two environments."""
    comptime LATENCY = AnalyzeIntent(2)
    """Slow operations."""
    comptime ERRORS = AnalyzeIntent(3)
    """Failed operations."""
    comptime TYPE = AnalyzeIntent(4)
    """One type in the schema."""
    comptime OPERATIONS = AnalyzeIntent(5)
    """The operation list."""
    comptime CONNECT = AnalyzeIntent(6)
    """How to register an endpoint or allowlist Forge."""

    def is_valid(self) -> Bool:
        """Return True if the value names an intent.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 6

    def text(self) -> StaticString:
        """Return the intent name.

        Returns:
            Such as `HEALTH`, or `<invalid>`.
        """
        if self == AnalyzeIntent.HEALTH:
            return "HEALTH"
        if self == AnalyzeIntent.COMPARE:
            return "COMPARE"
        if self == AnalyzeIntent.LATENCY:
            return "LATENCY"
        if self == AnalyzeIntent.ERRORS:
            return "ERRORS"
        if self == AnalyzeIntent.TYPE:
            return "TYPE"
        if self == AnalyzeIntent.OPERATIONS:
            return "OPERATIONS"
        if self == AnalyzeIntent.CONNECT:
            return "CONNECT"
        return "<invalid>"

    def write_to(self, mut writer: Some[Writer]):
        """Write the intent name.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


@fieldwise_init
struct Analysis(Copyable, Movable):
    """The answer to one question."""

    var intent: AnalyzeIntent
    """The classified intent."""
    var title: String
    """A short heading."""
    var summary: String
    """The main answer."""
    var type_name: String
    """The type that a TYPE question named. Empty otherwise."""
    var findings: List[String]
    """Concrete findings."""
    var next_steps: List[String]
    """What the user can do next."""


def strings(a: String, b: String = "", c: String = "") -> List[String]:
    """Return a list of one to three strings. Empty extras are left out.

    Args:
        a: The first string.
        b: An optional second string.
        c: An optional third string.

    Returns:
        The list.
    """
    var out = List[String]()
    out.append(a)
    if b.byte_length() > 0:
        out.append(b)
    if c.byte_length() > 0:
        out.append(c)
    return out^


def _first_variant(names: List[String], preferred: StringSlice) -> String:
    """Return a preferred variant name, or the first name.

    Args:
        names: Variant names.
        preferred: A name to pick when it exists.

    Returns:
        The preferred name, the first name, or empty.
    """
    for ref name in names:
        if name == preferred:
            return name.copy()
    if len(names) > 0:
        return names[0].copy()
    return String("")


def classify_question(
    question: StringSlice, type_names: List[String]
) -> AnalyzeIntent:
    """Classify a question.

    Args:
        question: The user text.
        type_names: Schema type names that can select TYPE.

    Returns:
        The intent. An empty question is HEALTH.
    """
    if question.byte_length() == 0:
        return AnalyzeIntent.HEALTH
    if (
        contains_folded(question, "allowlist")
        or contains_folded(question, "register")
        or contains_folded(question, "connect")
        or contains_folded(question, "endpoint")
        or contains_folded(question, "ingest")
    ):
        return AnalyzeIntent.CONNECT
    if (
        contains_folded(question, "compar")
        or contains_folded(question, "breaking")
        or contains_folded(question, "diff")
        or contains_folded(question, "between")
        or contains_folded(question, "environment")
    ):
        return AnalyzeIntent.COMPARE
    if (
        contains_folded(question, "error")
        or contains_folded(question, "fail")
        or contains_folded(question, "exception")
    ):
        return AnalyzeIntent.ERRORS
    if (
        contains_folded(question, "slow")
        or contains_folded(question, "latency")
        or contains_folded(question, "p50")
        or contains_folded(question, "p95")
        or contains_folded(question, "p99")
        or contains_folded(question, "duration")
    ):
        return AnalyzeIntent.LATENCY
    if (
        contains_folded(question, "operation")
        or contains_folded(question, "query")
        or contains_folded(question, "mutation")
    ):
        return AnalyzeIntent.OPERATIONS
    var found_type = matched_type_name(question, type_names)
    if found_type.byte_length() > 0:
        return AnalyzeIntent.TYPE
    return AnalyzeIntent.HEALTH


def matched_type_name(
    question: StringSlice, type_names: List[String]
) -> String:
    """Return the longest type name that occurs in the question.

    Args:
        question: The user text.
        type_names: Schema type names.

    Returns:
        The type name, or empty. Names shorter than 2 bytes are ignored.
    """
    var best = String("")
    for ref name in type_names:
        if name.byte_length() < 2:
            continue
        if (
            contains_folded(question, name)
            and name.byte_length() > best.byte_length()
        ):
            best = name.copy()
    return best^


def _variant_names(
    catalog: Catalog, org: StringSlice, graph: StringSlice
) raises -> List[String]:
    """Return the variant names of a graph.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.

    Returns:
        The names.

    Raises:
        Error: When a catalog file cannot be read.
    """
    var names = List[String]()
    for ref variant in catalog.variants(org, graph):
        names.append(variant.name.copy())
    return names^


def _type_names_for(
    catalog: Catalog, org: StringSlice, graph: StringSlice, variant: StringSlice
) -> List[String]:
    """Return user type names of a variant schema.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.
        variant: The variant name.

    Returns:
        Type names, or empty when no schema is stored.
    """
    var path = catalog.store.current_schema_path(org, graph, variant)
    try:
        var revision = atol(String(read_file(path).strip()))
        var sdl = read_file(
            catalog.store.schema_path(org, graph, variant, revision)
        )
        return user_type_names(build_schema(sdl))
    except:
        return List[String]()


def analyze(
    catalog: Catalog,
    org: StringSlice,
    graph: StringSlice,
    question: StringSlice,
    from_variant: StringSlice,
    to_variant: StringSlice,
) raises -> Analysis:
    """Answer a question about one graph.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.
        question: The user text.
        from_variant: A variant for compare-from, schema and telemetry.
        to_variant: A variant for compare-to.

    Returns:
        The analysis.

    Raises:
        Error: When a catalog file cannot be read, or as comparison
            raises.
    """
    if not catalog.has_graph(org, graph):
        return Analysis(
            AnalyzeIntent.HEALTH,
            String("Graph not in Forge"),
            "Graph '"
            + String(org)
            + "/"
            + String(graph)
            + "' is not in Forge. Register it on the Connect page.",
            String(""),
            List[String](),
            strings(
                String("Create the organization and graph."),
                String(
                    "Add a variant with the URL of the graph you already run."
                ),
            ),
        )
    var names = _variant_names(catalog, org, graph)
    var source = String(from_variant)
    if source.byte_length() == 0:
        source = _first_variant(names, "prod")
    var target = String(to_variant)
    if target.byte_length() == 0:
        target = _first_variant(names, "staging")
        if target == source and len(names) > 1:
            if names[0] == source:
                target = names[1].copy()
            else:
                target = names[0].copy()
    var types = _type_names_for(catalog, org, graph, source)
    var intent = classify_question(question, types)
    if intent == AnalyzeIntent.CONNECT:
        return _analyze_connect(catalog)
    if intent == AnalyzeIntent.COMPARE:
        return _analyze_compare(catalog, org, graph, source, target)
    if intent == AnalyzeIntent.LATENCY:
        return _analyze_latency(catalog, org, graph, source)
    if intent == AnalyzeIntent.ERRORS:
        return _analyze_errors(catalog, org, graph, source)
    if intent == AnalyzeIntent.OPERATIONS:
        return _analyze_operations(catalog, org, graph, source)
    if intent == AnalyzeIntent.TYPE:
        return analyze_type(
            catalog, org, graph, source, matched_type_name(question, types)
        )
    return _analyze_health(catalog, org, graph, names, source)


def _analyze_connect(catalog: Catalog) -> Analysis:
    """Explain how to point Forge at a customer graph.

    Args:
        catalog: The catalog.

    Returns:
        The analysis.
    """
    var ip = catalog.store.advertise_ip()
    var findings = List[String]()
    var next_steps = List[String]()
    if ip.byte_length() == 0:
        findings.append(
            "Forge has no advertise IP yet. Start it with --advertise-ip."
        )
    else:
        findings.append("Customers must allowlist " + ip + " for schema pulls.")
    next_steps.append(
        "Register the GraphQL URL of the ScorchQL or router you already run."
    )
    next_steps.append(
        "Upload SDL when the endpoint is https://, or when Forge cannot"
        " reach it."
    )
    next_steps.append(
        "Send operation events to POST /forge/telemetry with the variant ingest"
        " token."
    )
    return Analysis(
        AnalyzeIntent.CONNECT,
        String("Connect a graph you already run"),
        (
            "Forge does not host supergraphs. You keep the infrastructure."
            " Forge watches it."
        ),
        String(""),
        findings^,
        next_steps^,
    )


def _analyze_health(
    catalog: Catalog,
    org: StringSlice,
    graph: StringSlice,
    names: List[String],
    source: String,
) raises -> Analysis:
    """Summarize a graph.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.
        names: Variant names.
        source: The variant used for telemetry.

    Returns:
        The analysis.

    Raises:
        Error: When a catalog file cannot be read.
    """
    var findings = List[String]()
    findings.append("This graph has " + String(len(names)) + " environment(s).")
    for ref name in names:
        var variant = catalog.get_variant(org, graph, name)
        if variant.schema_revision <= 0:
            findings.append(name + " has no schema snapshot yet.")
        elif variant.last_pull_ok:
            findings.append(
                name
                + " schema revision "
                + String(variant.schema_revision)
                + " is current."
            )
        else:
            findings.append(
                name + " last pull failed: " + variant.last_pull_error
            )
    if source.byte_length() > 0:
        var log = load_log(catalog, org, graph, source)
        var requests = 0
        var errors = 0
        for ref op in log.operations:
            requests += op.count
            errors += op.errors
        findings.append(
            source
            + " has "
            + String(requests)
            + " recorded operation(s) and "
            + String(errors)
            + " error(s)."
        )
    return Analysis(
        AnalyzeIntent.HEALTH,
        String(org) + "/" + String(graph),
        "Forge is watching this graph. It does not serve it.",
        String(""),
        findings^,
        strings(
            String("Pull or upload a schema for each environment."),
            String("Compare environments after both have a snapshot."),
            String("Send telemetry from the customer router."),
        ),
    )


def _analyze_compare(
    catalog: Catalog,
    org: StringSlice,
    graph: StringSlice,
    source: String,
    target: String,
) raises -> Analysis:
    """Summarize a variant comparison.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.
        source: The older variant.
        target: The newer variant.

    Returns:
        The analysis.

    Raises:
        Error: When comparison cannot run.
    """
    if source.byte_length() == 0 or target.byte_length() == 0:
        return Analysis(
            AnalyzeIntent.COMPARE,
            String("No environments to compare"),
            "Add at least two variants, then pull a schema for each.",
            String(""),
            List[String](),
            strings(String("Create prod and staging variants.")),
        )
    if source == target:
        return Analysis(
            AnalyzeIntent.COMPARE,
            String("Same environment"),
            "Choose two different variants to compare.",
            String(""),
            strings("Both sides are " + source + "."),
            strings(String("Add another environment of this graph.")),
        )
    var diff = compare_variants(catalog, org, graph, source, target)
    if diff.error.byte_length() > 0:
        return Analysis(
            AnalyzeIntent.COMPARE,
            source + " to " + target,
            diff.error,
            String(""),
            List[String](),
            strings(String("Pull or upload SDL for each variant.")),
        )
    var breaking = 0
    var dangerous = 0
    var additive = 0
    var findings = List[String]()
    for ref change in diff.changes:
        if change.severity == "breaking":
            breaking += 1
        elif change.severity == "dangerous":
            dangerous += 1
        else:
            additive += 1
        if len(findings) < 8:
            findings.append(change.severity + ": " + change.description)
    var summary = (
        String(breaking)
        + " breaking, "
        + String(dangerous)
        + " dangerous, "
        + String(additive)
        + " additive change(s) from "
        + source
        + " to "
        + target
        + "."
    )
    return Analysis(
        AnalyzeIntent.COMPARE,
        source + " to " + target,
        summary,
        String(""),
        findings^,
        strings(
            String(
                "Fix breaking changes before you promote the newer environment."
            )
        ),
    )


def _analyze_latency(
    catalog: Catalog, org: StringSlice, graph: StringSlice, source: String
) -> Analysis:
    """Name the slowest operations.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.
        source: The variant.

    Returns:
        The analysis.
    """
    if source.byte_length() == 0:
        return Analysis(
            AnalyzeIntent.LATENCY,
            String("No telemetry"),
            "Add a variant and send operation events.",
            String(""),
            List[String](),
            strings(String("POST /forge/telemetry with the ingest token.")),
        )
    var log = load_log(catalog, org, graph, source)
    if len(log.operations) == 0:
        return Analysis(
            AnalyzeIntent.LATENCY,
            source + " latency",
            "No operation events are stored for " + source + ".",
            String(""),
            List[String](),
            strings(String("Send events from the customer router.")),
        )
    var findings = List[String]()
    var slowest = String("")
    var slow_p95 = -1
    for ref op in log.operations:
        var p95 = percentile(op.samples, 95)
        findings.append(op.name + " p95 " + String(p95) + " ms.")
        if p95 > slow_p95:
            slow_p95 = p95
            slowest = op.name.copy()
    return Analysis(
        AnalyzeIntent.LATENCY,
        source + " latency",
        slowest
        + " is the slowest operation by p95 ("
        + String(slow_p95)
        + " ms).",
        String(""),
        findings^,
        strings(String("Inspect that operation in the Insights page.")),
    )


def _analyze_errors(
    catalog: Catalog, org: StringSlice, graph: StringSlice, source: String
) -> Analysis:
    """Name operations that fail.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.
        source: The variant.

    Returns:
        The analysis.
    """
    var log = load_log(catalog, org, graph, source)
    var findings = List[String]()
    var worst = String("")
    var worst_errors = 0
    var total = 0
    for ref op in log.operations:
        total += op.errors
        if op.errors > 0:
            findings.append(
                op.name + " has " + String(op.errors) + " error(s)."
            )
        if op.errors > worst_errors:
            worst_errors = op.errors
            worst = op.name.copy()
    if total == 0:
        return Analysis(
            AnalyzeIntent.ERRORS,
            source + " errors",
            "No failed operations are stored for " + source + ".",
            String(""),
            findings^,
            strings(String("Keep sending events as traffic arrives.")),
        )
    return Analysis(
        AnalyzeIntent.ERRORS,
        source + " errors",
        worst + " has the most errors (" + String(worst_errors) + ").",
        String(""),
        findings^,
        strings(String("Compare this environment to a healthy one.")),
    )


def _analyze_operations(
    catalog: Catalog, org: StringSlice, graph: StringSlice, source: String
) -> Analysis:
    """List recorded operations.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.
        source: The variant.

    Returns:
        The analysis.
    """
    var log = load_log(catalog, org, graph, source)
    var findings = List[String]()
    for ref op in log.operations:
        findings.append(op.name + " ran " + String(op.count) + " time(s).")
    var summary = (
        String(len(log.operations))
        + " operation name(s) recorded on "
        + source
        + "."
    )
    if len(log.operations) == 0:
        summary = "No operations are stored for " + source + "."
    return Analysis(
        AnalyzeIntent.OPERATIONS,
        source + " operations",
        summary,
        String(""),
        findings^,
        strings(String("Open the Operations page for the recent log.")),
    )


def analyze_type(
    catalog: Catalog,
    org: StringSlice,
    graph: StringSlice,
    source: String,
    type_name: String,
) -> Analysis:
    """Describe one type.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.
        source: The variant.
        type_name: The type.

    Returns:
        The analysis.
    """
    if type_name.byte_length() == 0:
        return Analysis(
            AnalyzeIntent.TYPE,
            String("No matching type"),
            "The question does not name a type in " + source + ".",
            String(""),
            List[String](),
            strings(String("Open the Schema page and search for the type.")),
        )
    var types = _type_names_for(catalog, org, graph, source)
    var found = False
    for ref name in types:
        if name == type_name:
            found = True
    if not found:
        return Analysis(
            AnalyzeIntent.TYPE,
            type_name,
            type_name + " is not in the " + source + " schema.",
            type_name.copy(),
            List[String](),
            strings(String("Pull the schema again, or compare environments.")),
        )
    return Analysis(
        AnalyzeIntent.TYPE,
        type_name,
        type_name + " is in the " + source + " schema.",
        type_name.copy(),
        strings("Open Schema and select " + type_name + "."),
        strings(String("Compare environments to see if this type changed.")),
    )


def analysis_json(analysis: Analysis) -> String:
    """Write an analysis as JSON.

    Args:
        analysis: The analysis.

    Returns:
        The JSON object.
    """
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("intent")
    writer.string(analysis.intent.text())
    writer.key("title")
    writer.string(analysis.title)
    writer.key("summary")
    writer.string(analysis.summary)
    writer.key("typeName")
    writer.string(analysis.type_name)
    writer.key("findings")
    writer.begin_array()
    for ref finding in analysis.findings:
        writer.string(finding)
    writer.end_array()
    writer.key("nextSteps")
    writer.begin_array()
    for ref step in analysis.next_steps:
        writer.string(step)
    writer.end_array()
    writer.end_object()
    return writer^.take_string()
