# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The subgraph registry: the published subgraphs and their supergraph.

A subgraph is published with its name, its routing URL and its SDL. The
registry composes the new set of subgraphs with `gql_composition`. When
composition fails, the publish is refused and nothing changes. When it
succeeds, the registry writes the subgraph and the new supergraph, and
adds one to its revision.

The registry is a directory, so every worker process of a gateway sees
the same state:

    <directory>/subgraphs/<name>.json   one published subgraph
    <directory>/supergraph.graphql      the composed supergraph SDL
    <directory>/revision                the revision, a decimal integer

Each file is written to a temporary name and then renamed, so a reader
never sees part of a file. A gateway worker reads `revision` to know when
the supergraph has changed.

Two processes that publish at the same moment can lose one of the two
publishes. A gateway publishes one request at a time in each worker.

Differences from upstream: none; there is no upstream. The publish
behavior follows the public GraphOS documentation of
`rover subgraph publish`: a subgraph name, a routing URL and a schema, and
a publish that does not compose is refused.
"""

from std.ffi import external_call
from std.os import listdir, makedirs, remove, stat
from std.os.path import exists, isfile

from gql_composition.compose import compose_subgraphs
from gql_composition.validate import Subgraph
from gql_json.parser import parse as parse_json
from gql_json.value import JsonKind
from gql_json.writer import JsonWriter
from gql_language.parser import parse


@fieldwise_init
struct PublishedSubgraph(Copyable, Movable):
    """One subgraph in the registry."""

    var name: String
    """The subgraph name, such as `products`."""
    var url: String
    """The routing URL that the gateway sends operations to."""
    var sdl: String
    """The subgraph SDL, with its federation directives."""
    var published_at: Int
    """When it was last published, in seconds since the Unix epoch."""


@fieldwise_init
struct PublishResult(Copyable, Movable):
    """The result of a publish or a removal."""

    var accepted: Bool
    """Whether the registry changed or already had the same subgraph."""
    var changed: Bool
    """Whether the registry changed."""
    var revision: Int
    """The revision after the call."""
    var errors: List[String]
    """Why the call was refused; empty when it was accepted."""


def is_valid_subgraph_name(name: StringSlice) -> Bool:
    """Return True for a subgraph name that the registry accepts.

    A name starts with an ASCII letter, and has only ASCII letters, digits,
    `_` and `-`, as a Rover subgraph name. It has at most 64 bytes.

    Args:
        name: The name.

    Returns:
        Whether the name is valid.
    """
    var bytes = name.as_bytes()
    if len(bytes) == 0 or len(bytes) > 64:
        return False
    for index in range(len(bytes)):
        var byte = bytes[index]
        var letter = (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)
        if index == 0 and not letter:
            return False
        var digit = byte >= 48 and byte <= 57
        if not (letter or digit or byte == 95 or byte == 45):
            return False
    return True


def is_valid_routing_url(url: StringSlice) -> Bool:
    """Return True for a routing URL that the gateway can call.

    Args:
        url: The URL.

    Returns:
        Whether it starts with `http://` and has a host.
    """
    return url.startswith("http://") and url.byte_length() > 7


def publish_errors(name: StringSlice, url: StringSlice) -> List[String]:
    """Check the name and the routing URL of a publish.

    Args:
        name: The subgraph name.
        url: The routing URL.

    Returns:
        One message for each value that is not valid; empty when both are.
    """
    var errors = List[String]()
    if not is_valid_subgraph_name(name):
        errors.append(
            "Invalid subgraph name '"
            + String(name)
            + "': it must start with a letter and have only letters,"
            " digits, '_' and '-'."
        )
    if not is_valid_routing_url(url):
        errors.append(
            "Invalid routing URL '"
            + String(url)
            + "': it must start with http://."
        )
    return errors^


def unix_time() -> Int:
    """Return the wall-clock time.

    Returns:
        Seconds since the Unix epoch.
    """
    return Int(external_call["time", Int64](Int64(0)))


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
    var rc = external_call["rename", Int32](
        temporary.as_c_string_span().ptr(), target.as_c_string_span().ptr()
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


def subgraph_json(subgraph: PublishedSubgraph) -> String:
    """Write a subgraph as the JSON of its registry file.

    Args:
        subgraph: The subgraph.

    Returns:
        `{"name":...,"url":...,"sdl":...,"publishedAt":...}`.
    """
    var writer = JsonWriter()
    writer.begin_object()
    writer.key("name")
    writer.string(subgraph.name)
    writer.key("url")
    writer.string(subgraph.url)
    writer.key("sdl")
    writer.string(subgraph.sdl)
    writer.key("publishedAt")
    writer.int(Int64(subgraph.published_at))
    writer.end_object()
    return writer^.take_string()


def parse_subgraph_json(text: String) raises -> PublishedSubgraph:
    """Read the JSON of a registry file.

    Args:
        text: The JSON.

    Returns:
        The subgraph.

    Raises:
        Error: When the JSON is not an object with a string `name`, `url`
            and `sdl`.
    """
    var document = parse_json(text)
    var root = document.root
    if document.kind(root) != JsonKind.OBJECT:
        raise Error("a registry file is not a JSON object")
    var fields = List[String]()
    for key in ["name", "url", "sdl"]:
        var node = document.find(root, key)
        if node < 0 or document.kind(node) != JsonKind.STRING:
            raise Error("a registry file has no string " + key)
        fields.append(document.string_value(node))
    var published_at = 0
    var at = document.find(root, "publishedAt")
    if at >= 0 and document.kind(at) == JsonKind.NUMBER:
        published_at = Int(atol(document.text(at)))
    return PublishedSubgraph(
        fields[0].copy(), fields[1].copy(), fields[2].copy(), published_at
    )


def compose_published(
    subgraphs: List[PublishedSubgraph],
) -> Tuple[String, List[String]]:
    """Compose subgraphs into a supergraph.

    Args:
        subgraphs: The subgraphs; at least one.

    Returns:
        The supergraph SDL and no errors, or an empty SDL and the errors.
    """
    var errors = List[String]()
    var parsed = List[Subgraph]()
    for ref subgraph in subgraphs:
        try:
            parsed.append(
                Subgraph(
                    subgraph.name,
                    Optional[String](subgraph.url),
                    parse(subgraph.sdl),
                )
            )
        except e:
            errors.append("[" + subgraph.name + "] " + String(e))
    if len(errors) > 0:
        return (String(""), errors^)
    try:
        var result = compose_subgraphs(parsed)
        for ref error in result.errors:
            errors.append(error.message)
        if len(errors) > 0:
            return (String(""), errors^)
        return (result.supergraph_sdl, errors^)
    except e:
        errors.append(String(e))
        return (String(""), errors^)


struct Registry(Copyable, Movable):
    """A registry directory."""

    var directory: String
    """The directory that holds the registry files."""

    def __init__(out self, directory: String):
        """Name a registry directory; `open` creates it.

        Args:
            directory: The directory.
        """
        self.directory = directory

    def open(self) raises:
        """Create the registry directory and its `subgraphs` directory.

        Raises:
            Error: When a directory cannot be created.
        """
        makedirs(self.directory + "/subgraphs", exist_ok=True)

    def subgraph_path(self, name: StringSlice) -> String:
        """Return the file of a subgraph.

        Args:
            name: A valid subgraph name.

        Returns:
            `<directory>/subgraphs/<name>.json`.
        """
        return self.directory + "/subgraphs/" + String(name) + ".json"

    def supergraph_path(self) -> String:
        """Return the file of the supergraph SDL.

        Returns:
            `<directory>/supergraph.graphql`.
        """
        return self.directory + "/supergraph.graphql"

    def revision_path(self) -> String:
        """Return the file of the revision.

        Returns:
            `<directory>/revision`.
        """
        return self.directory + "/revision"

    def revision(self) -> Int:
        """Return the revision: 0 before the first publish.

        Returns:
            The revision, or 0 when the file is missing or bad.
        """
        try:
            return atol(read_file(self.revision_path()).strip())
        except:
            return 0

    def supergraph(self) -> Optional[String]:
        """Return the supergraph SDL, when a subgraph is published.

        Returns:
            The SDL, or None.
        """
        try:
            return read_file(self.supergraph_path())
        except:
            return None

    def subgraphs(self) raises -> List[PublishedSubgraph]:
        """Read every published subgraph, by name.

        Returns:
            The subgraphs, sorted by name.

        Raises:
            Error: When a registry file cannot be read.
        """
        var directory = self.directory + "/subgraphs"
        var out = List[PublishedSubgraph]()
        if not exists(directory):
            return out^
        var names = List[String]()
        for entry in listdir(directory):
            if entry.endswith(".json"):
                names.append(String(entry))
        sort(names)
        for ref entry in names:
            out.append(parse_subgraph_json(read_file(directory + "/" + entry)))
        return out^

    def _commit(
        mut self, subgraphs: List[PublishedSubgraph], supergraph: String
    ) raises -> Int:
        """Write the supergraph and the next revision."""
        if len(subgraphs) == 0:
            if exists(self.supergraph_path()):
                remove(self.supergraph_path())
        else:
            write_file_atomic(self.supergraph_path(), supergraph)
        var revision = self.revision() + 1
        write_file_atomic(self.revision_path(), String(revision) + "\n")
        return revision

    def publish(
        mut self, name: String, url: String, sdl: String
    ) raises -> PublishResult:
        """Publish a subgraph: add it, or replace the one of that name.

        Args:
            name: The subgraph name.
            url: The routing URL.
            sdl: The subgraph SDL.

        Returns:
            Accepted and unchanged when the subgraph is already published
            with this URL and SDL. Accepted and changed when the new set
            composes. Refused, with the errors, when it does not.

        Raises:
            Error: When a registry file cannot be read or written.
        """
        var errors = publish_errors(name, url)
        if len(errors) > 0:
            return PublishResult(False, False, self.revision(), errors^)
        self.open()
        var subgraphs = self.subgraphs()
        var position = -1
        for index in range(len(subgraphs)):
            if subgraphs[index].name == name:
                position = index
        if (
            position >= 0
            and subgraphs[position].url == url
            and subgraphs[position].sdl == sdl
        ):
            return PublishResult(True, False, self.revision(), errors^)
        var entry = PublishedSubgraph(name, url, sdl, unix_time())
        if position >= 0:
            subgraphs[position] = entry.copy()
        else:
            subgraphs.append(entry.copy())
        var composed = compose_published(subgraphs)
        if len(composed[1]) > 0:
            return PublishResult(
                False, False, self.revision(), composed[1].copy()
            )
        write_file_atomic(self.subgraph_path(name), subgraph_json(entry))
        var revision = self._commit(subgraphs, composed[0])
        return PublishResult(True, True, revision, errors^)

    def remove(mut self, name: String) raises -> PublishResult:
        """Remove a subgraph, and compose the others.

        Args:
            name: The subgraph name.

        Returns:
            Refused when no subgraph has the name, or when the others do
            not compose; otherwise accepted and changed.

        Raises:
            Error: When a registry file cannot be read or written.
        """
        var errors = List[String]()
        if not is_valid_subgraph_name(name) or not isfile(
            self.subgraph_path(name)
        ):
            errors.append("No subgraph named '" + name + "' is published.")
            return PublishResult(False, False, self.revision(), errors^)
        var others = List[PublishedSubgraph]()
        for ref subgraph in self.subgraphs():
            if subgraph.name != name:
                others.append(subgraph.copy())
        var supergraph = String("")
        if len(others) > 0:
            var composed = compose_published(others)
            if len(composed[1]) > 0:
                return PublishResult(
                    False, False, self.revision(), composed[1].copy()
                )
            supergraph = composed[0]
        remove(self.subgraph_path(name))
        var revision = self._commit(others, supergraph)
        return PublishResult(True, True, revision, errors^)


def file_changed_at(path: String) -> Int:
    """Return when a file last changed, or -1 when it is missing.

    Args:
        path: The file.

    Returns:
        The modification time in nanoseconds since the Unix epoch.
    """
    try:
        var info = stat(path)
        return Int(info.st_mtimespec.tv_sec) * 1_000_000_000 + Int(
            info.st_mtimespec.tv_nsec
        )
    except:
        return -1
