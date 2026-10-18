<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Threat model

The scanner reads this file before it starts. It is for Anthropic's OSS Scanner.

## What this project does and where untrusted input enters

- MojoGraphQL is a GraphQL library written in Mojo. It ports MIT licensed projects: graphql-js, Apollo Server, Apollo Client, Apollo MCP Server and others. Each top-level `gql_*` directory is a package.
- Untrusted input enters in five places. An attacker is a client on the network, or a remote server that the library talks to.
- First, bytes on a socket. The HTTP/1.1 server in `gql_http` parses the request line, the headers and the body. The `gql_server` pipeline then reads the body, the content type and the CSRF headers.
- Second, GraphQL documents. `gql_language` lexes and parses them. `gql_validation` and `gql_execution` then check and run them.
- Third, JSON. `gql_json` parses request bodies and variables.
- Fourth, Model Context Protocol messages. `gql_mcp` reads JSON-RPC over standard input and over HTTP.
- Fifth, responses from remote servers. The client in `gql_http` and the cache in `gql_client` parse them.
- A schema in SDL is untrusted only when an application loads it from an untrusted source.
- The developer who writes the schema and the resolvers is trusted. The network client is not.

## Components that matter most / least

- Most important: `gql_http` (the server parser), `gql_server`, `gql_json`, `gql_language` and `gql_mcp`. They read bytes from an attacker.
- Important: `gql_validation` and `gql_execution`. They handle documents that an attacker shapes.
- Less important: `gql_client`, `gql_schema`, `gql_subgraph`, `gql_codegen`, `gql_composition` and `gql_router`. Their inputs come from the developer or from servers that the developer chose. `gql_composition` and `gql_router` are still in progress.
- Out of scope: `tests/`, `bench/` (including `bench/baselines/`, which run the upstream libraries in other languages), `docs/`, `tools/` and `coverage/`.
- `gql_http` has no TLS and speaks IPv4 only. This is by design. Do not report plaintext HTTP.
- The project supports Linux, macOS on Apple Silicon, and Windows through WSL 2. WSL 2 runs the Linux code. The scan runs on Linux (x86-64 or aarch64). `gql_http/socket.mojo` uses `epoll` on Linux and `kqueue` on macOS. The scan runs the `epoll` path. The `kqueue` path cannot run in a scan. Read it by hand if you can.

## How to exercise it

- The toolchain is `/src/.venv/bin/mojo`. It is Mojo 1.1.0. The pin is exact. Do not install another version.
- Run one suite from `/src` with `.venv/bin/mojo run -I . tests/gql_json/test_parser.mojo`. The `-I .` flag is required. The suites are in `tests/<package>/`. Read them to see how to call each package.
- `make test PKG=<package>` runs the suites of a package and of every package that depends on it. Each single test must finish in 5 seconds or less.
- To test the server, start it from a small program in one process and send raw bytes to it from another. `tests/gql_http/` and `tests/gql_server/` show how to build a server and a request. Build a program with `.venv/bin/mojo build -I . --sanitize address`.
- The scan has no Internet. All the toolchain files are in the image.

## How you rate severity

- Critical: memory corruption, or remote code execution, from a request that an unauthenticated client sends to the HTTP server.
- High: any other memory-safety violation in `gql_http`, `gql_json`, `gql_language` or `gql_mcp`. This includes an out-of-bounds read, a use after free, and an integer overflow that leads to one of them.
- High: HTTP request smuggling or desynchronization in the server. A bypass of the CSRF prevention in `gql_server`. A bypass of an authorization rule in `gql_router`.
- Medium: a remote denial of service from a small request. This includes a crash or abort, a hang, unbounded memory use, and time that grows faster than linearly with the size of a document or a body.
- Medium: a request that exceeds a configured limit (`Limits` in `gql_http`, `max_connections`) and the server does not refuse it.
- Low: a wrong error message or a wrong status code that has no security effect.

## Anything to leave alone

- Do not report a valid query that is deep or expensive. As in graphql-js, the application limits depth and cost. Report it only when this project documents a limit and the limit does not hold.
- Do not report behavior that matches the upstream library on purpose. The project keeps the upstream API and behavior. Report it only when the behavior is exploitable here.
- Do not report a bug that exists only in the Mojo compiler or standard library. Report the MojoGraphQL input that triggers it.
- Do not report code style, missing docstrings or formatting. The project's own checks cover them.
- A patch must follow `CLAUDE.md`. Write American English. Give each public symbol a docstring with `Args`, `Returns` and `Raises`. Keep the upstream API. Add a regression test in `tests/<package>/` that runs in 5 seconds or less. Do not add Python or any other language to the project.
