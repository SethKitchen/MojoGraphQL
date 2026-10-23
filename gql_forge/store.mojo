# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The Forge data directory that every worker process shares.

    <directory>/revision
    <directory>/advertise_ip
    <directory>/orgs/<slug>.json
    <directory>/graphs/<org>/<ref>.json
    <directory>/variants/<org>/<graph>/<name>.json
    <directory>/schemas/<org>/<graph>/<variant>/<rev>.graphql
    <directory>/schemas/<org>/<graph>/<variant>/current
    <directory>/telemetry/<org>/<graph>/<variant>.json

Each file is written to a temporary name and then renamed, so a reader
never sees part of a file.

Differences from upstream: none; there is no upstream.
"""

from std.ffi import external_call
from std.os import makedirs, remove
from std.os.path import exists

from gql_json.parser import parse as parse_json
from gql_json.value import JsonDocument, JsonKind


def unix_time() -> Int:
    """Return the wall-clock time.

    Returns:
        Seconds since the Unix epoch.
    """
    return Int(external_call["time", Int64](Int64(0)))


def _c_path(path: String) -> List[UInt8]:
    """Return a path as a NUL-terminated byte list.

    Args:
        path: The path.

    Returns:
        The bytes, with a trailing 0.
    """
    var out = List[UInt8]()
    out.extend(path.as_bytes())
    out.append(0)
    return out^


def write_file_atomic(path: String, text: StringSlice) raises:
    """Write a file through a temporary file and a rename.

    Args:
        path: The file.
        text: The content.

    Raises:
        Error: When the file cannot be written or renamed.
    """
    var temporary = path + ".tmp"
    var target = path.copy()
    with open(temporary, "w") as file:
        file.write(text)
    var from_path = _c_path(temporary)
    var to_path = _c_path(target)
    var rc = external_call["rename", Int32](
        from_path.unsafe_ptr(), to_path.unsafe_ptr()
    )
    if rc != 0:
        remove(temporary)
        raise Error("cannot rename " + temporary + " to " + path)


def read_file(path: String) raises -> String:
    """Read a whole file.

    Args:
        path: The file.

    Returns:
        Its content.

    Raises:
        Error: When the file cannot be read.
    """
    with open(path, "r") as file:
        return file.read()


def read_object_string(
    document: JsonDocument, root: Int, key: StringSlice
) raises -> String:
    """Read a required string member of a JSON object.

    Args:
        document: The parsed JSON.
        root: The object node.
        key: The member name.

    Returns:
        The decoded string.

    Raises:
        Error: When the member is missing or is not a string.
    """
    var node = document.find(root, key)
    if node < 0 or document.kind(node) != JsonKind.STRING:
        raise Error("JSON object has no string " + String(key))
    return document.string_value(node)


def read_object_string_or(
    document: JsonDocument, root: Int, key: StringSlice, fallback: StringSlice
) -> String:
    """Read an optional string member of a JSON object.

    Args:
        document: The parsed JSON.
        root: The object node.
        key: The member name.
        fallback: The value when the member is missing or is not a string.

    Returns:
        The decoded string, or `fallback`.
    """
    var node = document.find(root, key)
    if node < 0 or document.kind(node) != JsonKind.STRING:
        return String(fallback)
    return document.string_value(node)


def read_object_int(
    document: JsonDocument, root: Int, key: StringSlice, fallback: Int
) -> Int:
    """Read an optional number member of a JSON object.

    Args:
        document: The parsed JSON.
        root: The object node.
        key: The member name.
        fallback: The value when the member is missing or is not a number.

    Returns:
        The integer, or `fallback`.
    """
    var node = document.find(root, key)
    if node < 0 or document.kind(node) != JsonKind.NUMBER:
        return fallback
    try:
        return Int(atol(document.text(node)))
    except:
        return fallback


def read_object_bool(
    document: JsonDocument, root: Int, key: StringSlice, fallback: Bool
) -> Bool:
    """Read an optional boolean member of a JSON object.

    Args:
        document: The parsed JSON.
        root: The object node.
        key: The member name.
        fallback: The value when the member is missing or is not a boolean.

    Returns:
        The boolean, or `fallback`.
    """
    var node = document.find(root, key)
    if node < 0 or document.kind(node) != JsonKind.BOOLEAN:
        return fallback
    return document.bool_value(node)


def parse_object(text: StringSlice) raises -> JsonDocument:
    """Parse JSON text that must be an object.

    Args:
        text: The JSON.

    Returns:
        The document. Its root is the object.

    Raises:
        Error: When the text is not a JSON object.
    """
    var document = parse_json(text)
    if document.kind(document.root) != JsonKind.OBJECT:
        raise Error("JSON value is not an object")
    return document^


struct Store(Copyable, Movable):
    """A Forge data directory."""

    var directory: String
    """The directory that holds the Forge files."""

    def __init__(out self, directory: String):
        """Name a data directory. `open` creates it.

        Args:
            directory: The directory.
        """
        self.directory = directory

    def open(self) raises:
        """Create the directory tree that Forge writes.

        Raises:
            Error: When a directory cannot be created.
        """
        makedirs(self.directory + "/orgs", exist_ok=True)
        makedirs(self.directory + "/graphs", exist_ok=True)
        makedirs(self.directory + "/variants", exist_ok=True)
        makedirs(self.directory + "/schemas", exist_ok=True)
        makedirs(self.directory + "/telemetry", exist_ok=True)

    def revision_path(self) -> String:
        """Return the file of the catalog revision.

        Returns:
            `<directory>/revision`.
        """
        return self.directory + "/revision"

    def advertise_ip_path(self) -> String:
        """Return the file of the IP that customers allowlist.

        Returns:
            `<directory>/advertise_ip`.
        """
        return self.directory + "/advertise_ip"

    def org_path(self, slug: StringSlice) -> String:
        """Return the file of an organization.

        Args:
            slug: The organization slug.

        Returns:
            `<directory>/orgs/<slug>.json`.
        """
        return self.directory + "/orgs/" + String(slug) + ".json"

    def graph_path(self, org: StringSlice, graph_key: StringSlice) -> String:
        """Return the file of a graph.

        Args:
            org: The organization slug.
            graph_key: The graph key.

        Returns:
            `<directory>/graphs/<org>/<key>.json`.
        """
        return (
            self.directory
            + "/graphs/"
            + String(org)
            + "/"
            + String(graph_key)
            + ".json"
        )

    def variant_path(
        self, org: StringSlice, graph: StringSlice, name: StringSlice
    ) -> String:
        """Return the file of a variant.

        Args:
            org: The organization slug.
            graph: The graph ref.
            name: The variant name.

        Returns:
            `<directory>/variants/<org>/<graph>/<name>.json`.
        """
        return (
            self.directory
            + "/variants/"
            + String(org)
            + "/"
            + String(graph)
            + "/"
            + String(name)
            + ".json"
        )

    def schema_dir(
        self, org: StringSlice, graph: StringSlice, variant: StringSlice
    ) -> String:
        """Return the directory of schema snapshots for a variant.

        Args:
            org: The organization slug.
            graph: The graph ref.
            variant: The variant name.

        Returns:
            `<directory>/schemas/<org>/<graph>/<variant>`.
        """
        return (
            self.directory
            + "/schemas/"
            + String(org)
            + "/"
            + String(graph)
            + "/"
            + String(variant)
        )

    def schema_path(
        self,
        org: StringSlice,
        graph: StringSlice,
        variant: StringSlice,
        revision: Int,
    ) -> String:
        """Return the file of one schema snapshot.

        Args:
            org: The organization slug.
            graph: The graph ref.
            variant: The variant name.
            revision: The snapshot number.

        Returns:
            `<directory>/schemas/<org>/<graph>/<variant>/<revision>.graphql`.
        """
        return (
            self.schema_dir(org, graph, variant)
            + "/"
            + String(revision)
            + ".graphql"
        )

    def current_schema_path(
        self, org: StringSlice, graph: StringSlice, variant: StringSlice
    ) -> String:
        """Return the file that names the current schema revision.

        Args:
            org: The organization slug.
            graph: The graph ref.
            variant: The variant name.

        Returns:
            `<directory>/schemas/<org>/<graph>/<variant>/current`.
        """
        return self.schema_dir(org, graph, variant) + "/current"

    def telemetry_path(
        self, org: StringSlice, graph: StringSlice, variant: StringSlice
    ) -> String:
        """Return the file of rolled-up telemetry for a variant.

        Args:
            org: The organization slug.
            graph: The graph ref.
            variant: The variant name.

        Returns:
            `<directory>/telemetry/<org>/<graph>/<variant>.json`.
        """
        return (
            self.directory
            + "/telemetry/"
            + String(org)
            + "/"
            + String(graph)
            + "/"
            + String(variant)
            + ".json"
        )

    def revision(self) -> Int:
        """Return the catalog revision: 0 before the first write.

        Returns:
            The revision, or 0 when the file is missing or bad.
        """
        try:
            return atol(String(read_file(self.revision_path()).strip()))
        except:
            return 0

    def bump_revision(mut self) raises -> Int:
        """Add one to the catalog revision and write it.

        Returns:
            The new revision.

        Raises:
            Error: When the file cannot be written.
        """
        var next = self.revision() + 1
        write_file_atomic(self.revision_path(), String(next) + "\n")
        return next

    def advertise_ip(self) -> String:
        """Return the IP that customers must allowlist.

        Returns:
            The IP text, or empty when none is set.
        """
        try:
            return String(read_file(self.advertise_ip_path()).strip())
        except:
            return String("")

    def set_advertise_ip(self, ip: StringSlice) raises:
        """Write the IP that customers must allowlist.

        Args:
            ip: The IP or host that Forge uses to pull schemas.

        Raises:
            Error: When the file cannot be written.
        """
        self.open()
        write_file_atomic(self.advertise_ip_path(), String(ip) + "\n")

    def write_json(self, path: String, text: StringSlice) raises:
        """Create parent directories and write a JSON file.

        Args:
            path: The file.
            text: The JSON.

        Raises:
            Error: When the file cannot be written.
        """
        var slash = path.rfind("/")
        if slash > 0:
            makedirs(String(path[byte=:slash]), exist_ok=True)
        write_file_atomic(path, text)

    def exists_file(self, path: String) -> Bool:
        """Return True when a path exists.

        Args:
            path: The file.

        Returns:
            Whether the path exists.
        """
        return exists(path)
