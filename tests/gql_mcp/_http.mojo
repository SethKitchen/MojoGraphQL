# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A raw HTTP exchange with a server that runs in this process, for the
Streamable HTTP suite."""

from gql_http.server import Handler, Server
from gql_http.socket import EAGAIN, IPv4Address, Sys


def exchange[
    H: Handler
](mut server: Server[H], request: StringSlice) raises -> String:
    """Send one request on a new connection and return the response text.

    The request must ask the server to close the connection, so that the
    response ends when the connection does.
    """
    var sys = Sys()
    var fd = sys.socket()
    var rc = sys.connect(fd, IPv4Address.LOOPBACK, server.port)
    if rc < 0 and rc != -115:
        raise Error("connect failed")
    var bytes = request.as_bytes()
    var sent = 0
    var turns = 0
    while sent < len(bytes) and turns < 1000:
        _ = server.poll(1)
        var n = sys.send(
            fd, bytes.unsafe_ptr().unsafe_offset(sent), len(bytes) - sent
        )
        if n > 0:
            sent += n
        turns += 1
    var out = List[UInt8]()
    var buffer = List[UInt8](length=65536, fill=0)
    var quiet = 0
    while quiet < 200:
        _ = server.poll(2)
        var n = sys.recv(fd, buffer.unsafe_ptr(), len(buffer))
        if n > 0:
            out.extend(Span(buffer)[:n])
            quiet = 0
        elif n == 0:
            break
        else:
            quiet += 1
    sys.close(fd)
    return String(unsafe_from_utf8=out)


def post(
    body: StringSlice,
    session: StringSlice = "",
    accept: StringSlice = "application/json, text/event-stream",
    content_type: StringSlice = "application/json",
    extra: StringSlice = "",
) -> String:
    """Return the text of a `POST /mcp` request that closes its
    connection."""
    var text = String("POST /mcp HTTP/1.1\r\nHost: x\r\nConnection: close\r\n")
    if accept.byte_length() > 0:
        text += "Accept: " + String(accept) + "\r\n"
    if content_type.byte_length() > 0:
        text += "Content-Type: " + String(content_type) + "\r\n"
    if session.byte_length() > 0:
        text += "Mcp-Session-Id: " + String(session) + "\r\n"
    text += String(extra)
    text += "Content-Length: " + String(body.byte_length()) + "\r\n\r\n"
    text += String(body)
    return text^


def other(
    method: StringSlice, path: StringSlice = "/mcp", headers: StringSlice = ""
) -> String:
    """Return the text of a request without content that closes its
    connection."""
    return (
        String(method)
        + " "
        + String(path)
        + " HTTP/1.1\r\nHost: x\r\n"
        + "Connection: close\r\n"
        + String(headers)
        + "\r\n"
    )


def body_of(response: String) -> String:
    """Return the content of a response."""
    var at = response.find("\r\n\r\n")
    return String(response[byte = at + 4 :])


def header_of(response: String, name: StringSlice) -> String:
    """Return the value of a response field, or empty."""
    var key = "\r\n" + String(name) + ": "
    var at = response.find(key)
    if at < 0:
        return String()
    var start = at + key.byte_length()
    var end = response.find("\r\n", start)
    return String(response[byte=start:end])
