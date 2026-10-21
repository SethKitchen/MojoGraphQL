# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""gql_client_http: the response parsing of the Apollo Client 4.3.3 HTTP
link.

`gql_client_http.response` reads a `multipart/mixed` response into its
results, as `readMultipartBody`, and checks a JSON response, as
`parseAndCheckHttpResponse`. It is a package of its own, so that a user of
the cache alone does not build `gql_http`. See the Client page of the
wiki.
"""
