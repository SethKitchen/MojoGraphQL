# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Hive Router `1a29df9` `bin/router/src/query_planner/tests/fixtures/overlapping_requires_chains.graphql` (MIT)."""


def sdl() -> String:
    """Return the fixture text.

    Returns:
        The text.
    """
    return String(
        """query {
  product { requestedA: canAffordWithAndWithoutDiscount }
  ... on Query { product { canAffordWithAndWithoutDiscount } }
  ... on Query {
    product {
      ... { ... on Product { requestedB: canAffordWithAndWithoutDiscount } }
      canAfford
    }
  }
}
"""
    )
