<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Security policy

## Report a vulnerability

Send a private email to `seth.kitchen+anthropicoss@seth.kitchen`. Do not open a public issue or pull request for a vulnerability.

Put these items in the report:

- The package and module that are affected, for example `gql_http` or `gql_json`.
- The smallest request, document or message that shows the problem.
- The output of `mojo --version`.

Keep the report private until a fix is on `main`.

## Supported versions

MojoGraphQL has no releases. Fixes go to the `main` branch only.

## What counts as a vulnerability

The HTTP server in `gql_http`, the request pipeline in `gql_server`, and the parsers in `gql_json`, `gql_language` and `gql_mcp` read bytes from a client that an attacker can control. A crash, a hang, unbounded memory use, a read or write outside a buffer, request smuggling or a CSRF bypass on such an input is a vulnerability.

The file [`.oss-scanner/threat_model.md`](.oss-scanner/threat_model.md) states what is in scope and how severity is rated.

## Reports from Anthropic's OSS Scanner

[Anthropic's OSS Scanner](https://github.com/anthropics/oss-scanner) sends its reports to the same address. A model writes those reports. A human has not reviewed them.
