# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The bytes of a streamed response to a client.

Port of Hive Router `1a29df9` `bin/router/src/pipeline/sse.rs`
(`create_stream`) and `pipeline/multipart_subscribe.rs`
(`create_incremental_delivery_stream`,
`create_apollo_multipart_http_stream`), and the content types of
`shared_state.rs`.

- **SSE:** each result is `event: next`, `data:` and the JSON. The end is
  `event: complete`. A heartbeat is the comment `:`.
- **Incremental delivery:** each result is one part of
  `multipart/mixed;boundary="-"` with `Content-Type: application/json`.
  The end is the close delimiter `-----`.
- **Apollo multipart HTTP:** each result is one part of
  `multipart/mixed;boundary="graphql";subscriptionSpec=1.0`, in the
  form `{"payload":...}`. A heartbeat is the part `{}`. The end is
  `--graphql--`.

Upstream sends a heartbeat after 10 seconds without a result, for SSE and
for Apollo multipart HTTP. `HEARTBEAT_MS` is that time.
"""

from gql_router_stream.negotiate import StreamContentType


comptime HEARTBEAT_MS = 10000
"""The quiet time before a heartbeat, as upstream: 10 seconds."""
comptime SSE_CONTENT_TYPE = "text/event-stream"
"""The content type of an SSE stream, as upstream `SSE_HEADER`."""
comptime INCREMENTAL_DELIVERY_CONTENT_TYPE = 'multipart/mixed;boundary="-"'
"""The content type of an incremental delivery stream."""
comptime APOLLO_MULTIPART_HTTP_CONTENT_TYPE = (
    'multipart/mixed;boundary="graphql";subscriptionSpec=1.0'
)
"""The content type of an Apollo multipart HTTP stream."""


def _append(mut out: List[UInt8], text: StringSlice):
    """Append the bytes of a text."""
    out.extend(text.as_bytes())


@fieldwise_init
struct StreamFormat(ImplicitlyCopyable, Movable):
    """The framing of one stream content type."""

    var type: StreamContentType
    """The content type."""

    def content_type(self) -> StaticString:
        """Return the `Content-Type` of the stream.

        Returns:
            The content type, as upstream sends it.
        """
        if self.type == StreamContentType.SSE:
            return SSE_CONTENT_TYPE
        if self.type == StreamContentType.APOLLO_MULTIPART_HTTP:
            return APOLLO_MULTIPART_HTTP_CONTENT_TYPE
        return INCREMENTAL_DELIVERY_CONTENT_TYPE

    def has_heartbeat(self) -> Bool:
        """Tell if the stream sends heartbeats.

        Returns:
            True for SSE and Apollo multipart HTTP.
        """
        return self.type != StreamContentType.INCREMENTAL_DELIVERY

    def result(self, mut out: List[UInt8], json: Span[UInt8, _]):
        """Append one result.

        Args:
            out: The destination.
            json: The JSON of the result.
        """
        if self.type == StreamContentType.SSE:
            _append(out, "event: next\ndata: ")
            out.extend(json)
            _append(out, "\n\n")
        elif self.type == StreamContentType.APOLLO_MULTIPART_HTTP:
            _append(
                out,
                "--graphql\r\nContent-Type: application/json\r\n\r\n",
            )
            _append(out, '{"payload":')
            out.extend(json)
            _append(out, "}\r\n")
        else:
            _append(out, "---\r\nContent-Type: application/json\r\n\r\n")
            out.extend(json)
            _append(out, "\r\n")

    def heartbeat(self, mut out: List[UInt8]):
        """Append one heartbeat; nothing for incremental delivery.

        Args:
            out: The destination.
        """
        if self.type == StreamContentType.SSE:
            _append(out, ":\n\n")
        elif self.type == StreamContentType.APOLLO_MULTIPART_HTTP:
            _append(
                out,
                "--graphql\r\nContent-Type: application/json\r\n\r\n{}\r\n",
            )

    def end(self, mut out: List[UInt8]):
        """Append the end of the stream.

        Args:
            out: The destination.
        """
        if self.type == StreamContentType.SSE:
            _append(out, "event: complete\n\n")
        elif self.type == StreamContentType.APOLLO_MULTIPART_HTTP:
            _append(out, "--graphql--")
        else:
            _append(out, "-----")
