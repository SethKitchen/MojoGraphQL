<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Tls

`gql_tls` is TLS 1.3 and ALPN for the other packages, through the OpenSSL 3 library of the system. It loads `libssl.so.3` and `libcrypto.so.3` at run time with `dlopen`. A program that does not use `gql_tls` does not need OpenSSL. The package depends only on `gql_http`, and it runs on Linux only.

| Module | Contents |
| --- | --- |
| `gql_tls.openssl` | `OpenSsl`, `TlsCall`, `TlsFaults`, `select_protocol`, `c_string`, and the OpenSSL constants |
| `gql_tls.context` | `TlsContext`, `TlsVersion`, `alpn_wire`, `default_protocols` |
| `gql_tls.stream` | `TlsStream`, `IoWant`, `wait_for` |
| `gql_tls.server` | `TlsServer`, `TlsProtocol`, `NoProtocol`, `ConnectionMode`, `listen_tls`, `listen_https` |
| `gql_tls.client` | `HttpsClient`, `HttpsEndpoint`, `open_tls` |
| `gql_tls.error` | `TlsError`, `TlsErrorKind` |

```mojo
from gql_http.server import ServerConfig
from gql_tls.context import TlsContext
from gql_tls.openssl import OpenSsl
from gql_tls.server import listen_https


def main() raises:
    var protocols = List[String]()
    protocols.append("http/1.1")
    var context = TlsContext.server(OpenSsl(), "cert.pem", "key.pem", protocols^)
    var config = ServerConfig()
    config.port = 4443
    var server = listen_https(Hello(), context^, config)
    server.run()
```

## OpenSSL

`OpenSsl()` opens the two libraries and looks up each function once. The copies of an `OpenSsl` share the libraries.

| Argument | Default | Contents |
| --- | --- | --- |
| `ssl_path` | `libssl.so.3` | The file name or the path of libssl |
| `crypto_path` | `libcrypto.so.3` | The file name or the path of libcrypto |
| `min_version` | `0x30000000` | The oldest `OpenSSL_version_num()` that the package accepts |

- **Missing library:** when a library does not load, `OpenSsl()` raises a `LIBRARY` error. The message names the file and tells what to install.
- **Old library:** a library that is older than `min_version`, or that lacks a function, also gives a `LIBRARY` error.
- **Other functions:** `function[R](name)` looks up another function of libssl, such as the QUIC API of `gql_http3`. `has_function(name)` tells if libssl has it.
- **SIGPIPE:** `OpenSsl()` makes the process ignore `SIGPIPE`. OpenSSL writes to its socket without `MSG_NOSIGNAL`, so a write to a socket that the peer closed would end the process. Now the write fails with `EPIPE`, and only that connection closes.
- **Faults:** `faults` is a `TlsFaults` plan. It makes one kind of call fail, so that tests reach the error paths.

## Contexts

A `TlsContext` holds an OpenSSL `SSL_CTX`: the settings of many connections.

| Function | Result |
| --- | --- |
| `TlsContext.server(openssl, cert_file, key_file, protocols, min_version)` | A server context with a PEM certificate chain and a PEM private key |
| `TlsContext.client(openssl, protocols, ca_file, verify, min_version)` | A client context that verifies servers |

- **Versions:** the oldest version is `TlsVersion.TLS_1_2` by default. `TlsVersion.TLS_1_3` allows only TLS 1.3. OpenSSL uses TLS 1.3 when both peers can.
- **Trust:** a client trusts the system CA store when `ca_file` is empty. Otherwise it trusts the CA certificates of `ca_file`.
- **Verification:** a client verifies the certificate chain and the host name of the server. `verify=False` turns both checks off. Use it only in tests.
- **ALPN:** `protocols` lists the ALPN protocols in order of preference. The default is `h2`, then `http/1.1`. An empty list turns ALPN off.

The server chooses the first of its protocols that the client offers (RFC 7301 section 3.2). When they have no protocol in common, the handshake continues without ALPN. The connection then uses HTTP/1.1.

## Streams

A `TlsStream` is one TLS connection on a non-blocking socket. `TlsStream.accept(context, fd)` makes the server end. `TlsStream.connect(context, fd, host)` makes the client end, with SNI and the name to verify. The stream does not close the socket.

| Method | Result |
| --- | --- |
| `handshake()` | `IoWant.NOTHING` when the handshake is done, or what it waits for |
| `read(data, size)` | The count of bytes, 0 at the end of the stream, or the negative code of an `IoWant` |
| `write(data, size)` | The count of bytes taken, or the negative code of an `IoWant` |
| `pending()`, `has_pending()` | The decrypted bytes that wait in OpenSSL |
| `shutdown()` | Sends `close_notify` |

`protocol` is the protocol that ALPN chose, or an empty string. `wait_for(sys, fd, want, timeout_ms)` waits on the socket for an `IoWant`. A TLS 1.3 read can need a write, so a caller must wait for the event that the code names.

## Server

`TlsServer[H, P]` is one epoll event loop that serves a `gql_http` `Handler` over TLS. It parses each request with the `RequestReader` of `gql_http`, and it writes each response with its `ResponseWriter`. Thus one handler serves HTTP and HTTPS.

| Function | Result |
| --- | --- |
| `listen_https(handler, context, config)` | A server that speaks HTTP/1.1 only |
| `listen_tls(handler, context, config, other)` | A server that also gives the connections of one more ALPN protocol to `other` |

After the handshake, ALPN decides what runs on a connection:

- `http/1.1`, or no ALPN: the server serves HTTP/1.1.
- The protocol that `other.protocol()` names, such as `h2`: the server gives the decrypted bytes to `other`.

`TlsProtocol` is a protocol without I/O. The server calls `open(conn, out)` after the handshake, `receive(conn, data, out)` for the bytes that arrive, and `close(conn)` at the end. The server encrypts and sends what the protocol appends to `out`. `gql_tls` does not import HTTP/2. The `H2Protocol` of [Https2](Https2) implements `TlsProtocol` for `h2`.

The server uses the fields of `gql_http.server.ServerConfig`, except `workers`: `TlsServer` is one event loop. A closing connection sends `close_notify` before the socket closes. The writer has no plain socket, so `ResponseWriter.flush` keeps the bytes. Streamed content goes out after the handler returns.

## Client

`HttpsClient` sends one request and returns the whole `gql_http.client.Response`. It reads the response with `gql_http.client.read_response`, so it has the framing rules of the HTTP client. It keeps a pool of keep-alive TLS connections.

| Method | Result |
| --- | --- |
| `HttpsClient(context, config)` | A client with a client context; its ALPN protocols must be `http/1.1` alone, or none |
| `HttpsClient.system(config)` | A client that trusts the system CA store |
| `get(url)`, `post(url, content_type, body)` | Send a request to an `https` URL |
| `endpoint(url)`, `send(endpoint, method, target, headers, body)` | Resolve a URL once, for many requests |
| `idle_connections()`, `close_idle()` | The pool |
| `adopt(endpoint, stream)` | Puts a connection that is open already into the pool, for the next request to the endpoint |

`open_tls(sys, context, endpoint, deadline, connect_timeout_ms)` connects a socket and runs the handshake. It returns the `TlsStream`, and its `protocol` is the protocol that ALPN chose. The HTTP/2 client of [Https2](Https2) uses it, and gives a connection without `h2` to `adopt`.

- **Deadline:** each request has the deadline `ClientConfig.timeout_ms`, for the connect, the handshake, the send and the whole response.
- **Stale connections:** a TLS 1.3 server sends session tickets after the handshake. Thus the client checks a pooled connection with a TLS read that does not wait, and not with a plain `peek`.
- **Retry:** the client sends a request again on a new connection only when a reused connection fails before any byte of the response. This occurs only for an idempotent method, or when the send failed.

## TlsError

| `TlsErrorKind` | Meaning |
| --- | --- |
| `OS`, `RESOLVE`, `CONNECT`, `TIMEOUT`, `CLOSED`, `PROTOCOL`, `LIMIT`, `USAGE` | The kinds of `gql_http.error.ErrorKind`, with the same meaning |
| `LIBRARY` | OpenSSL 3 is not installed, or it lacks a function |
| `CONFIG` | A certificate, a key or a trust store did not load |
| `HANDSHAKE` | The TLS handshake failed |
| `VERIFY` | The certificate of the peer did not verify, or its name is wrong; `errno` is the X.509 result |

`TlsError.from_http(error)` keeps the kind of an `HttpError`.

## License

OpenSSL is Apache-2.0 licensed. `gql_tls` loads it at run time and calls its public API. The project ports no OpenSSL code, and it does not ship OpenSSL.
