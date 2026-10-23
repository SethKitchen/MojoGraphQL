# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Organizations, graphs and variants in the Forge catalog.

A graph is a supergraph that a customer already hosts. A variant is one
environment of that graph, such as `prod` or `staging`. Forge records
where to look. It does not run the graph.

Differences from upstream: none; there is no upstream.
"""

from std.os import listdir, remove
from std.os.path import exists

from gql_forge.names import (
    endpoint_error,
    is_valid_endpoint_url,
    is_valid_slug,
    make_ingest_token,
    slug_error,
    sort_strings,
)
from gql_forge.store import (
    Store,
    parse_object,
    read_file,
    read_object_bool,
    read_object_int,
    read_object_string,
    read_object_string_or,
    unix_time,
)
from gql_json.writer import JsonWriter


@fieldwise_init
struct Organization(Copyable, Movable):
    """A company or team that owns graphs."""

    var slug: String
    """The stable id, such as `acme`."""
    var name: String
    """The display name."""
    var created_at: Int
    """When it was created, in seconds since the Unix epoch."""


@fieldwise_init
struct Graph(Copyable, Movable):
    """A supergraph that a customer hosts."""

    var org: String
    """The organization slug."""
    var key: String
    """The stable id, such as `shop`."""
    var name: String
    """The display name."""
    var description: String
    """A short description. Empty when none is set."""
    var created_at: Int
    """When it was created, in seconds since the Unix epoch."""


@fieldwise_init
struct Variant(Copyable, Movable):
    """One environment of a graph, and where Forge looks for it."""

    var org: String
    """The organization slug."""
    var graph: String
    """The graph ref."""
    var name: String
    """The environment name, such as `prod`."""
    var endpoint_url: String
    """The customer-hosted GraphQL HTTP URL."""
    var pull_token: String
    """An optional bearer token for schema pulls. Empty when none."""
    var ingest_token: String
    """The bearer token that telemetry requests must send."""
    var schema_revision: Int
    """The current schema snapshot number. 0 when none is stored."""
    var last_pull_at: Int
    """When the last pull or upload finished. 0 when never."""
    var last_pull_error: String
    """The last pull error. Empty after a successful pull."""
    var last_pull_ok: Bool
    """Whether the last pull or upload succeeded."""
    var created_at: Int
    """When it was created, in seconds since the Unix epoch."""


@fieldwise_init
struct CatalogResult(Copyable, Movable):
    """The result of a catalog write."""

    var accepted: Bool
    """Whether the write happened."""
    var created: Bool
    """Whether a new record was created."""
    var error: String
    """Why the write was refused. Empty when it was accepted."""


def organization_json(org: Organization) -> String:
    """Write an organization as the JSON of its catalog file.

    Args:
        org: The organization.

    Returns:
        The JSON object.
    """
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("slug")
    writer.string(org.slug)
    writer.key("name")
    writer.string(org.name)
    writer.key("createdAt")
    writer.int(Int64(org.created_at))
    writer.end_object()
    return writer^.take_string()


def parse_organization(text: String) raises -> Organization:
    """Read an organization catalog file.

    Args:
        text: The JSON.

    Returns:
        The organization.

    Raises:
        Error: When the JSON is not an object with a string `slug`.
    """
    var document = parse_object(text)
    var root = document.root
    var slug = read_object_string(document, root, "slug")
    var name = read_object_string_or(document, root, "name", slug)
    return Organization(
        slug^, name^, read_object_int(document, root, "createdAt", 0)
    )


def graph_json(graph: Graph) -> String:
    """Write a graph as the JSON of its catalog file.

    Args:
        graph: The graph.

    Returns:
        The JSON object.
    """
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("org")
    writer.string(graph.org)
    writer.key("ref")
    writer.string(graph.key)
    writer.key("name")
    writer.string(graph.name)
    writer.key("description")
    writer.string(graph.description)
    writer.key("createdAt")
    writer.int(Int64(graph.created_at))
    writer.end_object()
    return writer^.take_string()


def parse_graph(text: String) raises -> Graph:
    """Read a graph catalog file.

    Args:
        text: The JSON.

    Returns:
        The graph.

    Raises:
        Error: When the JSON is not an object with a string `org` and
            `ref`.
    """
    var document = parse_object(text)
    var root = document.root
    var org = read_object_string(document, root, "org")
    var graph_key = read_object_string(document, root, "ref")
    return Graph(
        org^,
        graph_key.copy(),
        read_object_string_or(document, root, "name", graph_key),
        read_object_string_or(document, root, "description", ""),
        read_object_int(document, root, "createdAt", 0),
    )


def variant_json(variant: Variant) -> String:
    """Write a variant as the JSON of its catalog file.

    Args:
        variant: The variant.

    Returns:
        The JSON object.
    """
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("org")
    writer.string(variant.org)
    writer.key("graph")
    writer.string(variant.graph)
    writer.key("name")
    writer.string(variant.name)
    writer.key("endpointUrl")
    writer.string(variant.endpoint_url)
    writer.key("pullToken")
    writer.string(variant.pull_token)
    writer.key("ingestToken")
    writer.string(variant.ingest_token)
    writer.key("schemaRevision")
    writer.int(Int64(variant.schema_revision))
    writer.key("lastPullAt")
    writer.int(Int64(variant.last_pull_at))
    writer.key("lastPullError")
    writer.string(variant.last_pull_error)
    writer.key("lastPullOk")
    writer.bool(variant.last_pull_ok)
    writer.key("createdAt")
    writer.int(Int64(variant.created_at))
    writer.end_object()
    return writer^.take_string()


def parse_variant(text: String) raises -> Variant:
    """Read a variant catalog file.

    Args:
        text: The JSON.

    Returns:
        The variant.

    Raises:
        Error: When the JSON is not an object with a string `org`,
            `graph` and `name`.
    """
    var document = parse_object(text)
    var root = document.root
    return Variant(
        read_object_string(document, root, "org"),
        read_object_string(document, root, "graph"),
        read_object_string(document, root, "name"),
        read_object_string_or(document, root, "endpointUrl", ""),
        read_object_string_or(document, root, "pullToken", ""),
        read_object_string_or(document, root, "ingestToken", ""),
        read_object_int(document, root, "schemaRevision", 0),
        read_object_int(document, root, "lastPullAt", 0),
        read_object_string_or(document, root, "lastPullError", ""),
        read_object_bool(document, root, "lastPullOk", False),
        read_object_int(document, root, "createdAt", 0),
    )


def list_json_files(directory: String) raises -> List[String]:
    """Return `.json` file names in a directory, sorted.

    Args:
        directory: The directory.

    Returns:
        The file names, including the `.json` suffix.

    Raises:
        Error: When the directory cannot be read.
    """
    var names = List[String]()
    if not exists(directory):
        return names^
    for entry in listdir(directory):
        if entry.endswith(".json"):
            names.append(String(entry))
    sort_strings(names)
    return names^


def file_stem(file_name: StringSlice) -> String:
    """Return a `.json` file name without the suffix.

    Args:
        file_name: The file name.

    Returns:
        The stem. The full name when it does not end with `.json`.
    """
    if file_name.endswith(".json") and file_name.byte_length() > 5:
        return String(file_name[byte = : file_name.byte_length() - 5])
    return String(file_name)


struct Catalog(Copyable, Movable):
    """The organizations, graphs and variants in a store."""

    var store: Store
    """The data directory."""

    def __init__(out self, directory: String):
        """Name the data directory.

        Args:
            directory: The Forge directory.
        """
        self.store = Store(directory)

    def open(self) raises:
        """Create the directory tree.

        Raises:
            Error: When a directory cannot be created.
        """
        self.store.open()

    def organizations(self) raises -> List[Organization]:
        """Read every organization, by slug.

        Returns:
            The organizations, sorted by slug.

        Raises:
            Error: When a catalog file cannot be read.
        """
        var out = List[Organization]()
        for ref name in list_json_files(self.store.directory + "/orgs"):
            out.append(
                parse_organization(
                    read_file(self.store.directory + "/orgs/" + name)
                )
            )
        return out^

    def get_organization(self, slug: StringSlice) raises -> Organization:
        """Read one organization.

        Args:
            slug: The organization slug.

        Returns:
            The organization.

        Raises:
            Error: When the file is missing or bad.
        """
        return parse_organization(read_file(self.store.org_path(slug)))

    def has_organization(self, slug: StringSlice) -> Bool:
        """Return True when an organization exists.

        Args:
            slug: The organization slug.

        Returns:
            Whether the catalog file exists.
        """
        return self.store.exists_file(self.store.org_path(slug))

    def create_organization(
        mut self, slug: StringSlice, name: StringSlice
    ) raises -> CatalogResult:
        """Create an organization.

        Args:
            slug: The organization slug.
            name: The display name. The slug is used when this is empty.

        Returns:
            Refused when the slug is not valid or already exists.

        Raises:
            Error: When a catalog file cannot be written.
        """
        if not is_valid_slug(slug):
            return CatalogResult(False, False, slug_error("organization", slug))
        if self.has_organization(slug):
            return CatalogResult(
                False,
                False,
                "Organization '" + String(slug) + "' already exists.",
            )
        self.open()
        var display = String(name)
        if display.byte_length() == 0:
            display = String(slug)
        var org = Organization(String(slug), display^, unix_time())
        self.store.write_json(self.store.org_path(slug), organization_json(org))
        _ = self.store.bump_revision()
        return CatalogResult(True, True, String(""))

    def graphs(self, org: StringSlice) raises -> List[Graph]:
        """Read every graph of an organization.

        Args:
            org: The organization slug.

        Returns:
            The graphs, sorted by key.

        Raises:
            Error: When a catalog file cannot be read.
        """
        var out = List[Graph]()
        var directory = self.store.directory + "/graphs/" + String(org)
        for ref name in list_json_files(directory):
            out.append(parse_graph(read_file(directory + "/" + name)))
        return out^

    def get_graph(
        self, org: StringSlice, graph_key: StringSlice
    ) raises -> Graph:
        """Read one graph.

        Args:
            org: The organization slug.
            graph_key: The graph key.

        Returns:
            The graph.

        Raises:
            Error: When the file is missing or bad.
        """
        return parse_graph(read_file(self.store.graph_path(org, graph_key)))

    def has_graph(self, org: StringSlice, graph_key: StringSlice) -> Bool:
        """Return True when a graph exists.

        Args:
            org: The organization slug.
            graph_key: The graph key.

        Returns:
            Whether the catalog file exists.
        """
        return self.store.exists_file(self.store.graph_path(org, graph_key))

    def create_graph(
        mut self,
        org: StringSlice,
        graph_key: StringSlice,
        name: StringSlice,
        description: StringSlice,
    ) raises -> CatalogResult:
        """Create a graph in an organization.

        Args:
            org: The organization slug.
            graph_key: The graph key.
            name: The display name. The key is used when this is empty.
            description: A short description.

        Returns:
            Refused when a slug is not valid, the organization is missing,
            or the graph already exists.

        Raises:
            Error: When a catalog file cannot be written.
        """
        if not is_valid_slug(org):
            return CatalogResult(False, False, slug_error("organization", org))
        if not is_valid_slug(graph_key):
            return CatalogResult(False, False, slug_error("graph", graph_key))
        if not self.has_organization(org):
            return CatalogResult(
                False,
                False,
                "Organization '" + String(org) + "' is not in Forge.",
            )
        if self.has_graph(org, graph_key):
            return CatalogResult(
                False,
                False,
                "Graph '" + String(graph_key) + "' already exists.",
            )
        var display = String(name)
        if display.byte_length() == 0:
            display = String(graph_key)
        var graph = Graph(
            String(org),
            String(graph_key),
            display^,
            String(description),
            unix_time(),
        )
        self.store.write_json(
            self.store.graph_path(org, graph_key), graph_json(graph)
        )
        _ = self.store.bump_revision()
        return CatalogResult(True, True, String(""))

    def variants(
        self, org: StringSlice, graph: StringSlice
    ) raises -> List[Variant]:
        """Read every variant of a graph.

        Args:
            org: The organization slug.
            graph: The graph ref.

        Returns:
            The variants, sorted by name.

        Raises:
            Error: When a catalog file cannot be read.
        """
        var out = List[Variant]()
        var directory = (
            self.store.directory
            + "/variants/"
            + String(org)
            + "/"
            + String(graph)
        )
        for ref name in list_json_files(directory):
            out.append(parse_variant(read_file(directory + "/" + name)))
        return out^

    def get_variant(
        self, org: StringSlice, graph: StringSlice, name: StringSlice
    ) raises -> Variant:
        """Read one variant.

        Args:
            org: The organization slug.
            graph: The graph ref.
            name: The variant name.

        Returns:
            The variant.

        Raises:
            Error: When the file is missing or bad.
        """
        return parse_variant(
            read_file(self.store.variant_path(org, graph, name))
        )

    def has_variant(
        self, org: StringSlice, graph: StringSlice, name: StringSlice
    ) -> Bool:
        """Return True when a variant exists.

        Args:
            org: The organization slug.
            graph: The graph ref.
            name: The variant name.

        Returns:
            Whether the catalog file exists.
        """
        return self.store.exists_file(self.store.variant_path(org, graph, name))

    def create_variant(
        mut self,
        org: StringSlice,
        graph: StringSlice,
        name: StringSlice,
        endpoint_url: StringSlice,
        pull_token: StringSlice,
    ) raises -> CatalogResult:
        """Create a variant that points at a customer-hosted graph.

        Args:
            org: The organization slug.
            graph: The graph ref.
            name: The variant name.
            endpoint_url: The GraphQL URL of the customer graph.
            pull_token: An optional bearer token for schema pulls.

        Returns:
            Refused when a name or URL is not valid, the graph is missing,
            or the variant already exists.

        Raises:
            Error: When a catalog file cannot be written.
        """
        if not is_valid_slug(name):
            return CatalogResult(False, False, slug_error("variant", name))
        if not is_valid_endpoint_url(endpoint_url):
            return CatalogResult(False, False, endpoint_error(endpoint_url))
        if not self.has_graph(org, graph):
            return CatalogResult(
                False,
                False,
                "Graph '"
                + String(org)
                + "/"
                + String(graph)
                + "' is not in Forge.",
            )
        if self.has_variant(org, graph, name):
            return CatalogResult(
                False, False, "Variant '" + String(name) + "' already exists."
            )
        var at = unix_time()
        var variant = Variant(
            String(org),
            String(graph),
            String(name),
            String(endpoint_url),
            String(pull_token),
            make_ingest_token(org, graph, name, at),
            0,
            0,
            String(""),
            False,
            at,
        )
        self.store.write_json(
            self.store.variant_path(org, graph, name), variant_json(variant)
        )
        _ = self.store.bump_revision()
        return CatalogResult(True, True, String(""))

    def save_variant(mut self, variant: Variant) raises:
        """Write a variant that already exists.

        Args:
            variant: The variant.

        Raises:
            Error: When the file cannot be written.
        """
        self.store.write_json(
            self.store.variant_path(variant.org, variant.graph, variant.name),
            variant_json(variant),
        )
        _ = self.store.bump_revision()

    def update_variant(
        mut self,
        org: StringSlice,
        graph: StringSlice,
        name: StringSlice,
        endpoint_url: Optional[String],
        pull_token: Optional[String],
    ) raises -> CatalogResult:
        """Change the endpoint or pull token of a variant.

        Args:
            org: The organization slug.
            graph: The graph ref.
            name: The variant name.
            endpoint_url: The new URL, or none to keep the current URL.
            pull_token: The new pull token, or none to keep the current
                token.

        Returns:
            Refused when the variant is missing or the new URL is not
            valid.

        Raises:
            Error: When a catalog file cannot be read or written.
        """
        if not self.has_variant(org, graph, name):
            return CatalogResult(
                False, False, "Variant '" + String(name) + "' is not in Forge."
            )
        var variant = self.get_variant(org, graph, name)
        if endpoint_url:
            if not is_valid_endpoint_url(endpoint_url.value()):
                return CatalogResult(
                    False, False, endpoint_error(endpoint_url.value())
                )
            variant.endpoint_url = endpoint_url.value().copy()
        if pull_token:
            variant.pull_token = pull_token.value().copy()
        self.save_variant(variant)
        return CatalogResult(True, False, String(""))

    def remove_variant(
        mut self, org: StringSlice, graph: StringSlice, name: StringSlice
    ) raises -> CatalogResult:
        """Remove a variant.

        Args:
            org: The organization slug.
            graph: The graph ref.
            name: The variant name.

        Returns:
            Refused when the variant is missing.

        Raises:
            Error: When the file cannot be removed.
        """
        var path = self.store.variant_path(org, graph, name)
        if not self.store.exists_file(path):
            return CatalogResult(
                False, False, "Variant '" + String(name) + "' is not in Forge."
            )
        remove(path)
        _ = self.store.bump_revision()
        return CatalogResult(True, False, String(""))
