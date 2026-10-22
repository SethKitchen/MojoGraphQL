# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A stub ScorchQL gateway for the `subgraph publish`, `delete` and `list`
suite, in one worker process.

It keeps a registry in memory, and answers as `gql_scorchql` does:

- `GET /scorchql/state`: the subgraphs, each published at `PUBLISHED_AT`;
- `POST /scorchql/publish`: `422` for the name `clash` and for an empty
  URL, else `{ok, changed, revision}`;
- `POST /scorchql/remove`: `{ok, changed, revision}`;
- the publish and remove of the name `locked` need `Bearer s3cret`.

`/broken/scorchql/state` answers `500`, and `/other/scorchql/state`
answers a JSON object that is not a gateway state.
"""

from gql_http.parser import Request
from gql_http.server import Handler, ResponseWriter, ServerConfig, WorkerPool
from gql_http.server import start_workers
from gql_http.socket import IPv4Address
from gql_http.status import Status
from gql_json.parser import parse_bytes
from gql_json.value import JsonKind, NO_NODE
from gql_json.writer import JsonWriter

comptime PUBLISHED_AT = 1760000000
"""The `publishedAt` of every subgraph: 2025-10-09 08:53:20 UTC."""


struct Gateway(Handler):
    """Answers the registry endpoints of a ScorchQL gateway."""

    var names: List[String]
    """The published names."""
    var urls: List[String]
    """The routing URL of each name."""
    var sdls: List[String]
    """The SDL of each name; `<introspected>` when none was sent."""
    var revision: Int
    """The registry revision."""

    def __init__(out self):
        """Start with an empty registry."""
        self.names = List[String]()
        self.urls = List[String]()
        self.sdls = List[String]()
        self.revision = 0

    def _state(self) -> String:
        """Return the `/scorchql/state` body."""
        var writer = JsonWriter()
        writer.begin_object()
        writer.key("revision")
        writer.int(Int64(self.revision))
        writer.key("subgraphs")
        writer.begin_array()
        for index in range(len(self.names)):
            writer.begin_object()
            writer.key("name")
            writer.string(self.names[index])
            writer.key("url")
            writer.string(self.urls[index])
            writer.key("publishedAt")
            writer.int(Int64(PUBLISHED_AT))
            writer.end_object()
        writer.end_array()
        writer.end_object()
        return writer^.take_string()

    def _ok(self, changed: Bool) -> String:
        """Return the answer of an accepted publish or removal."""
        return (
            '{"ok":true,"changed":'
            + ("true" if changed else "false")
            + ',"revision":'
            + String(self.revision)
            + "}"
        )

    def handle(mut self, request: Request, mut response: ResponseWriter) raises:
        """Answer one request."""
        var path = String(request.path())
        if path == "/broken/scorchql/state":
            response.send(Status(500), "text/plain", "boom")
            return
        if path == "/other/scorchql/state":
            response.send(Status.OK, "application/json", '{"data":{}}')
            return
        if path == "/scorchql/state":
            response.send(Status.OK, "application/json", self._state())
            return
        var document = parse_bytes(List[UInt8](request.body()))
        var name = String("")
        var node = document.find(document.root, "name")
        if node != NO_NODE and document.kind(node) == JsonKind.STRING:
            name = document.string_value(node)
        var authorization = request.header("Authorization")
        if name == "locked" and (
            not authorization
            or String(authorization.value()) != "Bearer s3cret"
        ):
            response.send(
                Status(401),
                "application/json",
                (
                    '{"errors":[{"message":"This gateway needs \'Authorization:'
                    " Bearer <token>'.\"}]}"
                ),
            )
            return
        var index = -1
        for position in range(len(self.names)):
            if self.names[position] == name:
                index = position
        if path == "/scorchql/remove":
            var changed = index >= 0
            if changed:
                _ = self.names.pop(index)
                _ = self.urls.pop(index)
                _ = self.sdls.pop(index)
                self.revision += 1
            response.send(Status.OK, "application/json", self._ok(changed))
            return
        var url = String("")
        node = document.find(document.root, "url")
        if node != NO_NODE and document.kind(node) == JsonKind.STRING:
            url = document.string_value(node)
        var sdl = String("<introspected>")
        node = document.find(document.root, "sdl")
        if node != NO_NODE and document.kind(node) == JsonKind.STRING:
            sdl = document.string_value(node)
        if name == "clash" or url == "":
            response.send(
                Status(422),
                "application/json",
                (
                    '{"errors":[{"message":"first problem"},'
                    '{"message":"second problem"}]}'
                ),
            )
            return
        if index >= 0 and self.urls[index] == url and self.sdls[index] == sdl:
            response.send(Status.OK, "application/json", self._ok(False))
            return
        self.revision += 1
        if index >= 0:
            self.urls[index] = url
            self.sdls[index] = sdl
        else:
            self.names.append(name)
            self.urls.append(url)
            self.sdls.append(sdl)
        response.send(Status.OK, "application/json", self._ok(True))


def start_gateway() raises -> WorkerPool:
    """Start the stub in one worker process on a free loopback port.

    Returns:
        The pool; its `port` is the gateway's port.
    """
    var config = ServerConfig()
    config.host = IPv4Address.LOOPBACK
    config.port = 0
    config.workers = 1
    return start_workers(Gateway(), config)
