# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The subgraph phase of composition on the Hive benchmark fixtures.

`composition/validate-subgraphs-<fixture>` validates the subgraphs of an
upstream Hive Federation Composition v0.27.0 fixture: the `basicServices`
of `benchmark.ts`, `__tests__/fixtures/stars-stuff.ts`,
`__tests__/fixtures/dgs` and `__tests__/fixtures/huge-schema`. The
subgraphs are parsed in setup, as `benchmark.ts` parses them. The baseline
is `bench/baselines/js-composition/bench.mjs`.
"""

from _harness import ValidateSubgraphs, measure


def main() raises:
    """Run the composition workloads."""
    var names: List[String] = ["basic", "stars-stuff", "dgs", "huge-schema"]
    for ref name in names:
        measure(
            "composition/validate-subgraphs-" + name,
            ValidateSubgraphs("hive-" + name),
        )
