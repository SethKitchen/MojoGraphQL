# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The Forge HTTP API and site.

`Forge.answer` handles one request on plain values, so a test can call it
without a socket. `serve_forge` serves the same handler on `gql_http`.

| Method and path | Answer |
| --- | --- |
| `GET /` | The Forge page |
| `GET /favicon.svg` | The mark |
| `GET /health` | `{"status":"pass"}` |
| `GET /forge/state` | Organizations, graphs and variants |
| `POST /forge/orgs` | Create `{slug, name}` |
| `POST /forge/graphs` | Create `{org, ref, name, description}` |
| `POST /forge/variants` | Create `{org, graph, name, endpointUrl, pullToken}` |
| `PATCH /forge/variants` | Update `{org, graph, name, endpointUrl, pullToken}` |
| `DELETE /forge/variants` | Remove `{org, graph, name}` |
| `POST /forge/schema` | Store `{org, graph, name, sdl}` |
| `POST /forge/pull` | Pull `{org, graph, name}` |
| `GET /forge/schema` | SDL for `org`, `graph`, `variant` |
| `GET /forge/schema-index` | Explorer JSON for that variant |
| `GET /forge/compare` | Diff `from` and `to` |
| `POST /forge/telemetry` | Ingest one operation event |
| `GET /forge/insights` | Dashboard numbers |
| `GET /forge/operations` | Recent events |
| `POST /forge/analyze` | Analyst answer |

When `ForgeConfig.admin_token` is set, every `/forge` path except
`POST /forge/telemetry` needs `Authorization: Bearer <token>`. Telemetry
accepts the variant ingest token or the admin token.

Differences from upstream: none; there is no upstream.
"""

from gql_forge.analyze import analysis_json, analyze
from gql_forge.catalog import Catalog, CatalogResult
from gql_forge.compare import compare_json, compare_variants, current_schema_sdl
from gql_forge.page import FAVICON_SVG, forge_page
from gql_forge.pull import pull_variant, upload_schema
from gql_forge.schema_view import schema_index_from_sdl
from gql_forge.store import (
    parse_object,
    read_object_string,
    read_object_string_or,
)
from gql_forge.telemetry import (
    ingest_event,
    insights_json,
    load_log,
    parse_telemetry_event,
    telemetry_json,
)
from gql_http.body import BodyPoll
from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig, serve
from gql_http.socket import Sys
from gql_http.status import Method, Status
from gql_http.url import parse_query, query_value
from gql_json.value import JsonDocument
from gql_json.writer import JsonWriter

comptime JSON_TYPE = "application/json; charset=utf-8"
"""The type of a JSON answer."""
comptime HTML_TYPE = "text/html; charset=utf-8"
"""The type of the Forge page."""
comptime SVG_TYPE = "image/svg+xml"
"""The type of the favicon."""
comptime TEXT_TYPE = "text/plain; charset=utf-8"
"""The type of SDL."""


@fieldwise_init
struct HttpAnswer(Copyable, Movable):
    """One HTTP response."""

    var status: Int
    """The status code."""
    var content_type: String
    """The Content-Type value."""
    var body: String
    """The content."""


struct ForgeConfig(Copyable, Movable):
    """What Forge serves, and where."""

    var title: String
    """The name in the header and the browser tab."""
    var data_directory: String
    """The catalog directory."""
    var advertise_ip: String
    """The IP that customers allowlist. Empty when none is set."""
    var admin_token: Optional[String]
    """The bearer token for catalog writes, when set."""
    var pull_timeout_ms: Int
    """The deadline of one schema pull."""
    var http_port: Int
    """The port, for the page. 0 when unknown."""

    def __init__(out self):
        """Make the default configuration."""
        self.title = "Forge"
        self.data_directory = String(".forge")
        self.advertise_ip = String("")
        self.admin_token = None
        self.pull_timeout_ms = 5000
        self.http_port = 0


def bearer_token(header: Optional[String]) -> String:
    """Read a bearer token from an Authorization header.

    Args:
        header: The header value, when there is one.

    Returns:
        The token, or empty.
    """
    if not header:
        return String("")
    var text = header.value()
    if text.startswith("Bearer "):
        return String(text[byte=7:])
    return String("")


def is_authorized(expected: Optional[String], header: Optional[String]) -> Bool:
    """Return True when a request may use the catalog API.

    Args:
        expected: The configured admin token, if any.
        header: The Authorization header, if any.

    Returns:
        True when no token is configured, or when the header matches.
    """
    if not expected:
        return True
    return bearer_token(header) == expected.value()


def json_error(status: Int, message: StringSlice) -> HttpAnswer:
    """Return a JSON error object.

    Args:
        status: The HTTP status.
        message: The error.

    Returns:
        The answer.
    """
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("error")
    writer.string(message)
    writer.end_object()
    return HttpAnswer(status, String(JSON_TYPE), writer^.take_string())


def json_ok(text: StringSlice) -> HttpAnswer:
    """Return a JSON success.

    Args:
        text: The JSON body.

    Returns:
        Status 200.
    """
    return HttpAnswer(200, String(JSON_TYPE), String(text))


def result_answer(result: CatalogResult) -> HttpAnswer:
    """Return 200 or 400 for a catalog write.

    Args:
        result: The write result.

    Returns:
        JSON with `accepted` or `error`.
    """
    if not result.accepted:
        return json_error(400, result.error)
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("accepted")
    writer.bool(True)
    writer.key("created")
    writer.bool(result.created)
    writer.end_object()
    return json_ok(writer^.take_string())


def _query(query_string: StringSlice, name: StringSlice) raises -> String:
    """Return a query parameter, or empty.

    Args:
        query_string: The text after `?`.
        name: The parameter name.

    Returns:
        The value, or empty.

    Raises:
        Error: When the query string is not valid.
    """
    if query_string.byte_length() == 0:
        return String("")
    var params = parse_query(query_string)
    var value = query_value(params, name)
    if not value:
        return String("")
    return value.value().copy()


def _body_object(body: StringSlice) raises -> JsonDocument:
    """Parse a JSON object body.

    Args:
        body: The request content.

    Returns:
        The document.

    Raises:
        Error: When the body is not a JSON object.
    """
    if body.byte_length() == 0:
        raise Error("request body is empty")
    return parse_object(body)


struct Forge(Copyable, Handler, Movable):
    """The Forge site and API."""

    var config: ForgeConfig
    """The configuration."""
    var catalog: Catalog
    """The catalog."""

    def __init__(out self, var config: ForgeConfig):
        """Open the catalog of a configuration.

        Args:
            config: The configuration.
        """
        self.catalog = Catalog(config.data_directory.copy())
        self.config = config^

    def open(mut self) raises:
        """Create the data directory and store the advertise IP.

        Raises:
            Error: When a directory cannot be created.
        """
        self.catalog.open()
        if self.config.advertise_ip.byte_length() > 0:
            self.catalog.store.set_advertise_ip(self.config.advertise_ip)

    def _need_admin(self, header: Optional[String]) -> Optional[HttpAnswer]:
        """Return 401 when the admin token is missing.

        Args:
            header: The Authorization header.

        Returns:
            The error, or none when the request is allowed.
        """
        if is_authorized(self.config.admin_token, header):
            return None
        return json_error(401, "Authorization bearer token is required.")

    def _state(self) raises -> String:
        """Write the catalog snapshot.

        Returns:
            The JSON object.

        Raises:
            Error: When a catalog file cannot be read.
        """
        var writer = JsonWriter()
        writer.begin_object()
        writer.key("title")
        writer.string(self.config.title)
        writer.key("revision")
        writer.int(Int64(self.catalog.store.revision()))
        writer.key("advertiseIp")
        var ip = self.catalog.store.advertise_ip()
        if ip.byte_length() == 0:
            ip = self.config.advertise_ip.copy()
        writer.string(ip)
        writer.key("authRequired")
        writer.bool(Bool(self.config.admin_token))
        writer.key("organizations")
        writer.begin_array()
        for ref org in self.catalog.organizations():
            writer.begin_object()
            writer.key("slug")
            writer.string(org.slug)
            writer.key("name")
            writer.string(org.name)
            writer.key("graphs")
            writer.begin_array()
            for ref graph in self.catalog.graphs(org.slug):
                writer.begin_object()
                writer.key("ref")
                writer.string(graph.key)
                writer.key("name")
                writer.string(graph.name)
                writer.key("description")
                writer.string(graph.description)
                writer.key("variants")
                writer.begin_array()
                for ref variant in self.catalog.variants(org.slug, graph.key):
                    writer.begin_object()
                    writer.key("name")
                    writer.string(variant.name)
                    writer.key("endpointUrl")
                    writer.string(variant.endpoint_url)
                    writer.key("ingestToken")
                    writer.string(variant.ingest_token)
                    writer.key("schemaRevision")
                    writer.int(Int64(variant.schema_revision))
                    writer.key("lastPullAt")
                    writer.int(Int64(variant.last_pull_at))
                    writer.key("lastPullOk")
                    writer.bool(variant.last_pull_ok)
                    writer.key("lastPullError")
                    writer.string(variant.last_pull_error)
                    writer.end_object()
                writer.end_array()
                writer.end_object()
            writer.end_array()
            writer.end_object()
        writer.end_array()
        writer.end_object()
        return writer^.take_string()

    def answer(
        mut self,
        method: Method,
        path: StringSlice,
        query_string: StringSlice,
        authorization: Optional[String],
        body: StringSlice,
    ) raises -> HttpAnswer:
        """Answer one request as a single HTTP response.

        Args:
            method: The request method.
            path: The path of the target.
            query_string: The text after `?`.
            authorization: The Authorization value, when there is one.
            body: The request content.

        Returns:
            The answer.

        Raises:
            Error: When a catalog file cannot be read or written.
        """
        if path == "/" and method == Method.GET:
            return HttpAnswer(
                200, String(HTML_TYPE), forge_page(self.config.title)
            )
        if path == "/favicon.svg" and method == Method.GET:
            return HttpAnswer(200, String(SVG_TYPE), String(FAVICON_SVG))
        if path == "/health" and method == Method.GET:
            return json_ok('{"status":"pass"}')
        if not path.startswith("/forge"):
            return json_error(404, "not found")
        if path == "/forge/telemetry" and method == Method.POST:
            return self._telemetry(authorization, body)
        var denied = self._need_admin(authorization)
        if denied:
            return denied.value().copy()
        if path == "/forge/state" and method == Method.GET:
            return json_ok(self._state())
        if path == "/forge/orgs" and method == Method.POST:
            return self._create_org(body)
        if path == "/forge/graphs" and method == Method.POST:
            return self._create_graph(body)
        if path == "/forge/variants" and method == Method.POST:
            return self._create_variant(body)
        if path == "/forge/variants" and method == Method.PATCH:
            return self._update_variant(body)
        if path == "/forge/variants" and method == Method.DELETE:
            return self._remove_variant(body)
        if path == "/forge/schema" and method == Method.POST:
            return self._upload(body)
        if path == "/forge/pull" and method == Method.POST:
            return self._pull(body)
        if path == "/forge/schema" and method == Method.GET:
            return self._schema(query_string)
        if path == "/forge/schema-index" and method == Method.GET:
            return self._schema_index(query_string)
        if path == "/forge/compare" and method == Method.GET:
            return self._compare(query_string)
        if path == "/forge/insights" and method == Method.GET:
            return self._insights(query_string)
        if path == "/forge/operations" and method == Method.GET:
            return self._operations(query_string)
        if path == "/forge/analyze" and method == Method.POST:
            return self._analyze(body)
        return json_error(405, "method not allowed")

    def _create_org(mut self, body: StringSlice) raises -> HttpAnswer:
        """Create an organization.

        Args:
            body: The JSON.

        Returns:
            The answer.

        Raises:
            Error: When a catalog file cannot be written, or the body is
                not JSON.
        """
        try:
            var document = _body_object(body)
            var slug = read_object_string(document, document.root, "slug")
            var name = read_object_string_or(
                document, document.root, "name", ""
            )
            return result_answer(self.catalog.create_organization(slug, name))
        except error:
            return json_error(400, String(error))

    def _create_graph(mut self, body: StringSlice) raises -> HttpAnswer:
        """Create a graph.

        Args:
            body: The JSON.

        Returns:
            The answer.

        Raises:
            Error: When a catalog file cannot be written.
        """
        try:
            var document = _body_object(body)
            var root = document.root
            return result_answer(
                self.catalog.create_graph(
                    read_object_string(document, root, "org"),
                    read_object_string(document, root, "ref"),
                    read_object_string_or(document, root, "name", ""),
                    read_object_string_or(document, root, "description", ""),
                )
            )
        except error:
            return json_error(400, String(error))

    def _create_variant(mut self, body: StringSlice) raises -> HttpAnswer:
        """Create a variant.

        Args:
            body: The JSON.

        Returns:
            The answer.

        Raises:
            Error: When a catalog file cannot be written.
        """
        try:
            var document = _body_object(body)
            var root = document.root
            return result_answer(
                self.catalog.create_variant(
                    read_object_string(document, root, "org"),
                    read_object_string(document, root, "graph"),
                    read_object_string(document, root, "name"),
                    read_object_string(document, root, "endpointUrl"),
                    read_object_string_or(document, root, "pullToken", ""),
                )
            )
        except error:
            return json_error(400, String(error))

    def _update_variant(mut self, body: StringSlice) raises -> HttpAnswer:
        """Update a variant.

        Args:
            body: The JSON.

        Returns:
            The answer.

        Raises:
            Error: When a catalog file cannot be written.
        """
        try:
            var document = _body_object(body)
            var root = document.root
            var endpoint = Optional[String]()
            var token = Optional[String]()
            var endpoint_node = document.find(root, "endpointUrl")
            if endpoint_node >= 0:
                endpoint = read_object_string_or(
                    document, root, "endpointUrl", ""
                )
            var token_node = document.find(root, "pullToken")
            if token_node >= 0:
                token = read_object_string_or(document, root, "pullToken", "")
            return result_answer(
                self.catalog.update_variant(
                    read_object_string(document, root, "org"),
                    read_object_string(document, root, "graph"),
                    read_object_string(document, root, "name"),
                    endpoint,
                    token,
                )
            )
        except error:
            return json_error(400, String(error))

    def _remove_variant(mut self, body: StringSlice) raises -> HttpAnswer:
        """Remove a variant.

        Args:
            body: The JSON.

        Returns:
            The answer.

        Raises:
            Error: When a catalog file cannot be removed.
        """
        try:
            var document = _body_object(body)
            var root = document.root
            return result_answer(
                self.catalog.remove_variant(
                    read_object_string(document, root, "org"),
                    read_object_string(document, root, "graph"),
                    read_object_string(document, root, "name"),
                )
            )
        except error:
            return json_error(400, String(error))

    def _upload(mut self, body: StringSlice) raises -> HttpAnswer:
        """Store uploaded SDL.

        Args:
            body: The JSON.

        Returns:
            The answer.

        Raises:
            Error: When a file cannot be written.
        """
        try:
            var document = _body_object(body)
            var root = document.root
            var text = upload_schema(
                self.catalog,
                read_object_string(document, root, "org"),
                read_object_string(document, root, "graph"),
                read_object_string(document, root, "name"),
                read_object_string(document, root, "sdl"),
            )
            if '"error"' in text:
                return HttpAnswer(400, String(JSON_TYPE), text)
            return json_ok(text)
        except error:
            return json_error(400, String(error))

    def _pull(mut self, body: StringSlice) raises -> HttpAnswer:
        """Pull a variant schema.

        Args:
            body: The JSON.

        Returns:
            The answer.

        Raises:
            Error: When a file cannot be written.
        """
        try:
            var document = _body_object(body)
            var root = document.root
            var text = pull_variant(
                self.catalog,
                read_object_string(document, root, "org"),
                read_object_string(document, root, "graph"),
                read_object_string(document, root, "name"),
                self.config.pull_timeout_ms,
            )
            if '"error"' in text:
                return HttpAnswer(400, String(JSON_TYPE), text)
            return json_ok(text)
        except error:
            return json_error(400, String(error))

    def _coords(
        self, query_string: StringSlice
    ) raises -> Tuple[String, String, String]:
        """Read org, graph and variant query parameters.

        Args:
            query_string: The text after `?`.

        Returns:
            The three values. Missing values are empty.

        Raises:
            Error: When the query string is not valid.
        """
        var variant = _query(query_string, "variant")
        if variant.byte_length() == 0:
            variant = _query(query_string, "name")
        return (
            _query(query_string, "org"),
            _query(query_string, "graph"),
            variant^,
        )

    def _schema(self, query_string: StringSlice) raises -> HttpAnswer:
        """Return stored SDL.

        Args:
            query_string: The query.

        Returns:
            The SDL or an error.

        Raises:
            Error: When the query string is not valid.
        """
        var coords = self._coords(query_string)
        var sdl = current_schema_sdl(
            self.catalog, coords[0], coords[1], coords[2]
        )
        if not sdl:
            return json_error(404, "no schema snapshot")
        return HttpAnswer(200, String(TEXT_TYPE), sdl.value().copy())

    def _schema_index(self, query_string: StringSlice) raises -> HttpAnswer:
        """Return the explorer index.

        Args:
            query_string: The query.

        Returns:
            The JSON or an error.

        Raises:
            Error: When the query string is not valid.
        """
        var coords = self._coords(query_string)
        var sdl = current_schema_sdl(
            self.catalog, coords[0], coords[1], coords[2]
        )
        if not sdl:
            return json_error(404, "no schema snapshot")
        try:
            return json_ok(schema_index_from_sdl(sdl.value()))
        except error:
            return json_error(400, String(error))

    def _compare(self, query_string: StringSlice) raises -> HttpAnswer:
        """Compare two variants.

        Args:
            query_string: The query.

        Returns:
            The JSON.

        Raises:
            Error: When comparison cannot run.
        """
        var org = _query(query_string, "org")
        var graph = _query(query_string, "graph")
        var source = _query(query_string, "from")
        var target = _query(query_string, "to")
        var diff = compare_variants(self.catalog, org, graph, source, target)
        var text = compare_json(diff)
        if diff.error.byte_length() > 0:
            return HttpAnswer(400, String(JSON_TYPE), text)
        return json_ok(text)

    def _insights(self, query_string: StringSlice) raises -> HttpAnswer:
        """Return dashboard numbers.

        Args:
            query_string: The query.

        Returns:
            The JSON.

        Raises:
            Error: When the query string is not valid.
        """
        var coords = self._coords(query_string)
        return json_ok(
            insights_json(
                load_log(self.catalog, coords[0], coords[1], coords[2])
            )
        )

    def _operations(self, query_string: StringSlice) raises -> HttpAnswer:
        """Return the telemetry log.

        Args:
            query_string: The query.

        Returns:
            The JSON.

        Raises:
            Error: When the query string is not valid.
        """
        var coords = self._coords(query_string)
        return json_ok(
            telemetry_json(
                load_log(self.catalog, coords[0], coords[1], coords[2])
            )
        )

    def _analyze(self, body: StringSlice) raises -> HttpAnswer:
        """Answer an analyst question.

        Args:
            body: The JSON.

        Returns:
            The JSON.

        Raises:
            Error: When analysis cannot run.
        """
        try:
            var document = _body_object(body)
            var root = document.root
            var analysis = analyze(
                self.catalog,
                read_object_string(document, root, "org"),
                read_object_string(document, root, "graph"),
                read_object_string_or(document, root, "question", ""),
                read_object_string_or(document, root, "from", ""),
                read_object_string_or(document, root, "to", ""),
            )
            return json_ok(analysis_json(analysis))
        except error:
            return json_error(400, String(error))

    def _telemetry(
        mut self, authorization: Optional[String], body: StringSlice
    ) raises -> HttpAnswer:
        """Ingest one operation event.

        Args:
            authorization: The Authorization header.
            body: The JSON.

        Returns:
            The answer.

        Raises:
            Error: When a file cannot be written.
        """
        try:
            var event = parse_telemetry_event(body)
            if not self.catalog.has_variant(
                event.org, event.graph, event.variant
            ):
                return json_error(404, "variant is not in Forge")
            var variant = self.catalog.get_variant(
                event.org, event.graph, event.variant
            )
            var token = bearer_token(authorization)
            var admin_ok = False
            if self.config.admin_token:
                admin_ok = token == self.config.admin_token.value()
            if token != variant.ingest_token and not admin_ok:
                if (
                    self.config.admin_token
                    or variant.ingest_token.byte_length() > 0
                ):
                    return json_error(401, "ingest token is required")
            return json_ok(ingest_event(self.catalog, event))
        except error:
            return json_error(400, String(error))

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer one HTTP request.

        Args:
            request: The request.
            response: The response.

        Raises:
            Error: When a catalog file cannot be read or written, or the
                response cannot be written.
        """
        var header = Optional[String]()
        var found = request.header("authorization")
        if found:
            header = String(found.value())
        var answer = self.answer(
            request.method,
            request.path(),
            request.query(),
            header,
            String(unsafe_from_utf8=request.body()),
        )
        response.set_status(Status(answer.status))
        response.add_header("Content-Type", answer.content_type)
        response.add_header("Cache-Control", "no-store")
        response.write(answer.body.as_bytes())

    def poll_body(mut self, id: Int, mut out: List[UInt8]) raises -> BodyPoll:
        """Forge has no held responses.

        Args:
            id: The connection.
            out: The destination.

        Returns:
            `DONE`.

        Raises:
            Error: Never.
        """
        _ = id
        _ = out
        return BodyPoll.DONE

    def body_closed(mut self, id: Int):
        """Forge has no held responses.

        Args:
            id: The connection.
        """
        _ = id


def serve_forge(
    var forge: Forge, config: ServerConfig, var sys: Sys = Sys()
) raises:
    """Serve Forge until the process ends.

    Args:
        forge: The handler.
        config: The HTTP server configuration.
        sys: The system calls. Tests pass a `Sys` that fails.

    Raises:
        Error: When the server cannot start.
    """
    forge.open()
    serve(forge^, config, sys^)
