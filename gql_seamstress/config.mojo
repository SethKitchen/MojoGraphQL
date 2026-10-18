# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The supergraph configuration: `supergraph.yaml`.

Port of `SupergraphConfig`, `SubgraphConfig` and `SchemaSource` of
`apollo-federation-types` 0.18.0-rc.1 `src/config` (MIT). The subgraphs
are sorted by name, as the upstream `BTreeMap` keeps them. A schema
source is the first variant that the mapping matches, in the upstream
order: `file`, `subgraph_url` with `introspection_headers`, `graphref`
with `subgraph`, and `sdl`. Fields that no variant names are ignored.

**Differences from upstream.** The messages name the path of the value,
as serde_yaml does, but not its line and column.
"""

from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_seamstress.federation_version import FEDERATION_ONE_UNSUPPORTED
from gql_seamstress.federation_version import (
    FederationVersion,
    is_federation_one_exact_pin,
)
from gql_seamstress.yaml import parse_yaml


@fieldwise_init
struct SchemaSourceKind(Equatable, ImplicitlyCopyable, Writable):
    """Where the SDL of a subgraph comes from."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime FILE = SchemaSourceKind(0)
    """A file, relative to the configuration: `file`."""
    comptime SUBGRAPH_INTROSPECTION = SchemaSourceKind(1)
    """The `_service { sdl }` query of a URL: `subgraph_url`."""
    comptime SUBGRAPH = SchemaSourceKind(2)
    """A subgraph in GraphOS: `graphref` and `subgraph`."""
    comptime SDL = SchemaSourceKind(3)
    """The SDL itself: `sdl`."""

    def is_valid(self) -> Bool:
        """Return True for one of the four kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the upstream variant name, such as `File`.

        Args:
            writer: The writer.
        """
        var names: List[String] = [
            "File",
            "SubgraphIntrospection",
            "Subgraph",
            "Sdl",
        ]
        writer.write(names[Int(self.value)] if self.is_valid() else "<invalid>")


@fieldwise_init
struct Header(Copyable, Movable):
    """One introspection header: a name and a value."""

    var name: String
    """The field name."""
    var value: String
    """The field value."""


@fieldwise_init
struct SchemaSource(Copyable, Movable):
    """The location of the SDL of a subgraph."""

    var kind: SchemaSourceKind
    """Which of the fields below are set."""
    var file: String
    """The file, for `FILE`."""
    var subgraph_url: String
    """The normalized URL, for `SUBGRAPH_INTROSPECTION`."""
    var introspection_headers: List[Header]
    """The headers of the introspection request, sorted by name."""
    var graphref: String
    """The graph ref, for `SUBGRAPH`."""
    var subgraph: String
    """The subgraph name in GraphOS, for `SUBGRAPH`."""
    var sdl: String
    """The SDL, for `SDL`."""


@fieldwise_init
struct SubgraphConfig(Copyable, Movable):
    """The configuration of one subgraph."""

    var name: String
    """The subgraph name: its key in `subgraphs`."""
    var routing_url: Optional[String]
    """The URL that the router sends requests to, if it is set."""
    var schema: SchemaSource
    """Where its SDL comes from."""


@fieldwise_init
struct SupergraphConfig(Copyable, Movable):
    """A supergraph configuration: its subgraphs and federation version."""

    var subgraphs: List[SubgraphConfig]
    """The subgraphs, sorted by name."""
    var federation_version: Optional[FederationVersion]
    """The `federation_version`, if it is set."""


def _describe(document: JsonDocument, node: Int) -> String:
    """Describe a value as serde does in an `invalid type` message."""
    var kind = document.kind(node)
    if kind == JsonKind.NULL:
        return "unit value"
    if kind == JsonKind.BOOLEAN:
        return "boolean `true`" if document.bool_value(
            node
        ) else "boolean `false`"
    if kind == JsonKind.NUMBER:
        return "integer `" + String(document.text(node)) + "`"
    if kind == JsonKind.STRING:
        return 'string "' + document.string_value(node) + '"'
    if kind == JsonKind.ARRAY:
        return "sequence"
    return "map"


def _invalid(
    path: String, document: JsonDocument, node: Int, expected: String
) -> Error:
    """Return a serde `invalid type` error at a path."""
    var prefix = path + ": " if path != "" else String("")
    return Error(
        prefix
        + "invalid type: "
        + _describe(document, node)
        + ", expected "
        + expected
    )


def _string(
    document: JsonDocument, object: Int, key: StringSlice
) -> Optional[String]:
    """Return a member that is a string, or None."""
    var node = document.find(object, key)
    if node == NO_NODE or document.kind(node) != JsonKind.STRING:
        return None
    return document.string_value(node)


def is_url(text: StringSlice) -> Bool:
    """Return True when a text starts with a URL scheme and `:`, as the
    `url` crate requires of an absolute URL.

    Args:
        text: The text.

    Returns:
        Whether the text has a scheme, such as `http:`, and more after it.
    """
    var bytes = text.as_bytes()
    if len(bytes) == 0:
        return False
    var first = bytes[0]
    if not ((first >= 65 and first <= 90) or (first >= 97 and first <= 122)):
        return False
    for index in range(1, len(bytes)):
        var byte = bytes[index]
        if byte == UInt8(ord(":")):
            return index + 1 < len(bytes)
        var ok = (
            (byte >= 65 and byte <= 90)
            or (byte >= 97 and byte <= 122)
            or (byte >= 48 and byte <= 57)
            or byte == UInt8(ord("+"))
            or byte == UInt8(ord("-"))
            or byte == UInt8(ord("."))
        )
        if not ok:
            return False
    return False


def normalize_url(text: StringSlice) -> String:
    """Normalize an absolute URL, as the `url` crate prints it.

    The scheme and the host are lowercase, and an `http` or `https` URL
    with no path gets the path `/`.

    Args:
        text: An absolute URL, such as `HTTP://Example.com:4001`.

    Returns:
        Such as `http://example.com:4001/`.
    """
    var colon = text.find(":")
    var scheme = String(text[byte=:colon]).lower()
    var rest = String(text[byte = colon + 1 :])
    if (scheme == "http" or scheme == "https") and rest.startswith("//"):
        var after = String(rest[byte=2:])
        var bytes = after.as_bytes()
        var end = 0
        while (
            end < len(bytes)
            and bytes[end] != UInt8(ord("/"))
            and bytes[end] != UInt8(ord("?"))
            and bytes[end] != UInt8(ord("#"))
        ):
            end += 1
        var authority = String(after[byte=:end]).lower()
        var tail = String(after[byte=end:])
        if not tail.startswith("/"):
            tail = "/" + tail
        return scheme + "://" + authority + tail
    return scheme + ":" + rest


def _headers(document: JsonDocument, object: Int) -> Optional[List[Header]]:
    """Return the `introspection_headers` of a source, or None when the
    member is neither absent, null nor a map of strings."""
    var out = List[Header]()
    var node = document.find(object, "introspection_headers")
    if node == NO_NODE or document.kind(node) == JsonKind.NULL:
        return out^
    if document.kind(node) != JsonKind.OBJECT:
        return None
    for member in document.children(node):
        if document.kind(member) != JsonKind.STRING:
            return None
        var header = Header(document.key(member), document.string_value(member))
        var at = len(out)
        for index in range(len(out)):
            if out[index].name == header.name:
                at = -1 - index
                break
        if at < 0:
            out[-1 - at] = header^
            continue
        while at > 0 and header.name < out[at - 1].name:
            at -= 1
        out.insert(at, header^)
    return out^


def _schema_source(
    document: JsonDocument, node: Int, path: String
) raises -> SchemaSource:
    """Read a schema source: the first upstream variant that matches."""
    var source = SchemaSource(
        SchemaSourceKind.FILE, "", "", List[Header](), "", "", ""
    )
    if document.kind(node) == JsonKind.OBJECT:
        var file = _string(document, node, "file")
        if file:
            source.file = file.take()
            return source^
        var url = _string(document, node, "subgraph_url")
        var headers = _headers(document, node)
        if url and is_url(url.value()) and headers:
            source.kind = SchemaSourceKind.SUBGRAPH_INTROSPECTION
            source.subgraph_url = normalize_url(url.value())
            source.introspection_headers = headers.take()
            return source^
        var graphref = _string(document, node, "graphref")
        var subgraph = _string(document, node, "subgraph")
        if graphref and subgraph:
            source.kind = SchemaSourceKind.SUBGRAPH
            source.graphref = graphref.take()
            source.subgraph = subgraph.take()
            return source^
        var sdl = _string(document, node, "sdl")
        if sdl:
            source.kind = SchemaSourceKind.SDL
            source.sdl = sdl.take()
            return source^
    raise Error(
        path + ": data did not match any variant of untagged enum SchemaSource"
    )


def _subgraph(
    document: JsonDocument, node: Int, name: String
) raises -> SubgraphConfig:
    """Read the configuration of one subgraph."""
    var path = "subgraphs." + name
    if document.kind(node) != JsonKind.OBJECT:
        raise _invalid(path, document, node, "struct SubgraphConfig")
    var routing_url = Optional[String](None)
    var url = document.find(node, "routing_url")
    if url != NO_NODE and document.kind(url) != JsonKind.NULL:
        if document.kind(url) != JsonKind.STRING:
            raise _invalid(path + ".routing_url", document, url, "a string")
        routing_url = document.string_value(url)
    var schema = document.find(node, "schema")
    if schema == NO_NODE:
        raise Error(path + ": missing field `schema`")
    return SubgraphConfig(
        name, routing_url^, _schema_source(document, schema, path + ".schema")
    )


def _federation_version(
    document: JsonDocument, root: Int
) raises -> Optional[FederationVersion]:
    """Read `federation_version`: null, a number or a string."""
    var node = document.find(root, "federation_version")
    if node == NO_NODE or document.kind(node) == JsonKind.NULL:
        return None
    var kind = document.kind(node)
    try:
        if kind == JsonKind.STRING:
            return FederationVersion.parse(document.string_value(node))
        if kind == JsonKind.NUMBER:
            var text = String(document.text(node))
            var value = 0
            var bytes = text.as_bytes()
            var index = 0
            while index < len(bytes):
                var byte = bytes[index]
                index += 1
                if byte < 48 or byte > 57 or value > 1000:
                    value = -1
                    break
                value = value * 10 + Int(byte) - 48
            if value >= 0:
                return FederationVersion.from_number(value)
    except e:
        if kind == JsonKind.STRING and is_federation_one_exact_pin(
            document.string_value(node)
        ):
            raise Error(FEDERATION_ONE_UNSUPPORTED)
        raise Error("federation_version: " + String(e))
    raise _invalid(
        "federation_version",
        document,
        node,
        (
            "literal '1', '2' or '3' (as a string or number), or a fully"
            " qualified version prefixed with an '=', like: =2.0.0"
        ),
    )


def supergraph_config_from_document(
    document: JsonDocument,
) raises -> SupergraphConfig:
    """Read a supergraph configuration from a parsed YAML or JSON value.

    Args:
        document: The value, as `parse_yaml` gives it.

    Returns:
        The configuration.

    Raises:
        Error: The serde message, such as ``missing field `subgraphs` `` or
            `subgraphs.films.schema: data did not match any variant of
            untagged enum SchemaSource`.
    """
    var root = document.root
    if document.kind(root) != JsonKind.OBJECT:
        if document.kind(root) == JsonKind.NULL:
            raise Error("missing field `subgraphs`")
        raise _invalid("", document, root, "struct SupergraphConfig")
    var version = _federation_version(document, root)
    var map = document.find(root, "subgraphs")
    if map == NO_NODE:
        raise Error("missing field `subgraphs`")
    if document.kind(map) != JsonKind.OBJECT:
        raise _invalid("subgraphs", document, map, "a map")
    var subgraphs = List[SubgraphConfig]()
    for member in document.children(map):
        var subgraph = _subgraph(document, member, document.key(member))
        var replaced = False
        for index in range(len(subgraphs)):
            if subgraphs[index].name == subgraph.name:
                subgraphs[index] = subgraph.copy()
                replaced = True
        if not replaced:
            var at = len(subgraphs)
            while at > 0 and subgraph.name < subgraphs[at - 1].name:
                at -= 1
            subgraphs.insert(at, subgraph^)
    return SupergraphConfig(subgraphs^, version^)


def parse_supergraph_config(text: StringSlice) raises -> SupergraphConfig:
    """Read a supergraph configuration from YAML or JSON text, as upstream
    `SupergraphConfig::new_from_yaml`.

    Args:
        text: The text of `supergraph.yaml`.

    Returns:
        The configuration.

    Raises:
        Error: A YAML syntax error from `parse_yaml`, or a structure error
            from `supergraph_config_from_document`.
    """
    return supergraph_config_from_document(parse_yaml(text))
