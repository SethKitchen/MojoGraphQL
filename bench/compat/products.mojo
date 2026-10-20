# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `products` subgraph of the Apollo Federation subgraph compatibility
suite (f9520a4, MIT), served over HTTP: the Mojo counterpart of
`implementations/apollo-server/index.js`.

`gql_subgraph` builds the subgraph from `tests/gql_subgraph/_products.mojo`,
and the `gql_server` standalone server serves it. The port is 4001, or the
value of `PRODUCTS_PORT`. Run it from the repository root:

    .venv/bin/mojo run -I . -I tests/gql_subgraph bench/compat/products.mojo

This program is not a benchmark. It is in `bench/` because it uses two
packages, and neither one depends on the other.
"""

from _products import build_products
from _serve import serve_subgraph


def main() raises:
    """Serve the `products` subgraph until the process is stopped."""
    serve_subgraph(build_products(), "Products", "PRODUCTS_PORT", 4001)
