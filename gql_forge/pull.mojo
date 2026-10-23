# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Pull a schema from a customer-hosted graph, or store uploaded SDL.

Forge does not host the graph. A live pull sends an introspection query
to the URL that the customer registered. The customer must allowlist the
Forge IP. A pull over `https://` is not available in the library; upload
SDL for those endpoints.

Differences from upstream: none; there is no upstream.
"""

from std.os import makedirs

from gql_forge.catalog import Catalog, Variant
from gql_forge.names import is_http_endpoint
from gql_forge.store import read_file, unix_time, write_file_atomic
from gql_http.client import Client, ClientConfig
from gql_http.headers import Headers
from gql_http.status import Method
from gql_json.parser import parse_bytes
from gql_json.value import JsonKind
from gql_json.writer import JsonWriter
from gql_schema.build import build_schema
from gql_schema.build_client_schema import build_client_schema
from gql_schema.introspection import get_introspection_query
from gql_schema.print import print_schema


def introspection_body() raises -> String:
    """Return the JSON body of an introspection request.

    Returns:
        `{"query":...}` with `getIntrospectionQuery`.

    Raises:
        Error: As `get_introspection_query` raises.
    """
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("query")
    writer.string(get_introspection_query())
    writer.end_object()
    return writer^.take_string()


def read_introspection_sdl(status: Int, var body: List[UInt8]) raises -> String:
    """Read SDL from an introspection HTTP response.

    Args:
        status: The HTTP status code.
        body: The response body.

    Returns:
        The printed client schema.

    Raises:
        Error: For a status that is not 2xx, a body that is not JSON, a
            GraphQL error, or a result that is not a full introspection.
    """
    if status < 200 or status > 299:
        raise Error("the graph answered HTTP " + String(status))
    var document = parse_bytes(body^)
    var root = document.root
    if document.kind(root) != JsonKind.OBJECT:
        raise Error("the graph response is not a JSON object")
    var errors = document.find(root, "errors")
    if errors >= 0 and document.kind(errors) == JsonKind.ARRAY:
        var first = document.first(errors)
        if first >= 0 and document.kind(first) == JsonKind.OBJECT:
            var message = document.find(first, "message")
            if message >= 0 and document.kind(message) == JsonKind.STRING:
                raise Error(
                    "the graph answered: " + document.string_value(message)
                )
        raise Error("the graph answered GraphQL errors")
    var data = document.find(root, "data")
    if data < 0 or document.kind(data) != JsonKind.OBJECT:
        raise Error("the graph response has no data object")
    return print_schema(build_client_schema(document, data))


def store_schema_sdl(
    mut catalog: Catalog, mut variant: Variant, sdl: StringSlice
) raises -> Int:
    """Validate SDL and write it as the next snapshot of a variant.

    Args:
        catalog: The catalog.
        variant: The variant. Its revision fields are updated.
        sdl: The SDL.

    Returns:
        The new schema revision.

    Raises:
        Error: When the SDL is not a schema, or a file cannot be written.
    """
    var printed = print_schema(build_schema(sdl))
    if variant.schema_revision > 0 and catalog.store.exists_file(
        catalog.store.schema_path(
            variant.org, variant.graph, variant.name, variant.schema_revision
        )
    ):
        var current = read_file(
            catalog.store.schema_path(
                variant.org,
                variant.graph,
                variant.name,
                variant.schema_revision,
            )
        )
        if current == printed:
            variant.last_pull_at = unix_time()
            variant.last_pull_error = String("")
            variant.last_pull_ok = True
            catalog.save_variant(variant)
            return variant.schema_revision
    var revision = variant.schema_revision + 1
    var directory = catalog.store.schema_dir(
        variant.org, variant.graph, variant.name
    )
    makedirs(directory, exist_ok=True)
    write_file_atomic(
        catalog.store.schema_path(
            variant.org, variant.graph, variant.name, revision
        ),
        printed,
    )
    write_file_atomic(
        catalog.store.current_schema_path(
            variant.org, variant.graph, variant.name
        ),
        String(revision) + "\n",
    )
    variant.schema_revision = revision
    variant.last_pull_at = unix_time()
    variant.last_pull_error = String("")
    variant.last_pull_ok = True
    catalog.save_variant(variant)
    return revision


def record_pull_error(
    mut catalog: Catalog, mut variant: Variant, message: String
) raises:
    """Record a failed pull on a variant.

    Args:
        catalog: The catalog.
        variant: The variant.
        message: The error.

    Raises:
        Error: When the catalog file cannot be written.
    """
    variant.last_pull_at = unix_time()
    variant.last_pull_error = message
    variant.last_pull_ok = False
    catalog.save_variant(variant)


def upload_schema(
    mut catalog: Catalog,
    org: StringSlice,
    graph: StringSlice,
    name: StringSlice,
    sdl: StringSlice,
) raises -> String:
    """Store uploaded SDL as the current snapshot of a variant.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.
        name: The variant name.
        sdl: The SDL.

    Returns:
        A JSON object with `revision`, or `error`.

    Raises:
        Error: When a catalog file cannot be read or written.
    """
    var writer = JsonWriter()
    writer.begin_object()
    if not catalog.has_variant(org, graph, name):
        writer.key("error")
        writer.string("Variant '" + String(name) + "' is not in Forge.")
        writer.end_object()
        return writer^.take_string()
    var variant = catalog.get_variant(org, graph, name)
    try:
        var revision = store_schema_sdl(catalog, variant, sdl)
        writer.key("revision")
        writer.int(Int64(revision))
        writer.key("changed")
        writer.bool(revision != variant.schema_revision or True)
        writer.end_object()
        return writer^.take_string()
    except error:
        record_pull_error(catalog, variant, String(error))
        writer.key("error")
        writer.string(String(error))
        writer.end_object()
        return writer^.take_string()


def pull_variant(
    mut catalog: Catalog,
    org: StringSlice,
    graph: StringSlice,
    name: StringSlice,
    timeout_ms: Int = 5000,
) raises -> String:
    """Pull the schema of a variant from its customer endpoint.

    Args:
        catalog: The catalog.
        org: The organization slug.
        graph: The graph ref.
        name: The variant name.
        timeout_ms: The HTTP deadline.

    Returns:
        A JSON object with `revision`, or `error`.

    Raises:
        Error: When a catalog file cannot be read or written.
    """
    var writer = JsonWriter()
    writer.begin_object()
    if not catalog.has_variant(org, graph, name):
        writer.key("error")
        writer.string("Variant '" + String(name) + "' is not in Forge.")
        writer.end_object()
        return writer^.take_string()
    var variant = catalog.get_variant(org, graph, name)
    if not is_http_endpoint(variant.endpoint_url):
        var message = (
            "Forge can pull only http:// endpoints. Upload SDL for '"
            + variant.endpoint_url
            + "'."
        )
        record_pull_error(catalog, variant, message)
        writer.key("error")
        writer.string(message)
        writer.end_object()
        return writer^.take_string()
    var config = ClientConfig()
    config.timeout_ms = timeout_ms
    config.connect_timeout_ms = timeout_ms
    var client = Client(config)
    try:
        var query = introspection_body()
        var endpoint = client.endpoint(variant.endpoint_url)
        var headers = Headers()
        headers.add("Content-Type", "application/json")
        if variant.pull_token.byte_length() > 0:
            headers.add("Authorization", "Bearer " + variant.pull_token)
        var target = endpoint.target.copy()
        var response = client.send(
            endpoint,
            Method.POST,
            target,
            headers,
            query.as_bytes(),
        )
        var sdl = read_introspection_sdl(
            response.status.code, List[UInt8](response.body())
        )
        var revision = store_schema_sdl(catalog, variant, sdl)
        writer.key("revision")
        writer.int(Int64(revision))
        writer.end_object()
        return writer^.take_string()
    except error:
        record_pull_error(catalog, variant, String(error))
        writer.key("error")
        writer.string(String(error))
        writer.end_object()
        return writer^.take_string()
