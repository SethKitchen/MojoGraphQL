# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The graphql-go-tools v2 `BenchmarkFragmentSpreadDepthCalc_Get` workload.

    mojo build -I . -o .cache/bin/fragment_spread_depth bench/gql_normalization/fragment_spread_depth.mojo
    .cache/bin/fragment_spread_depth

- `go-tools/FragmentSpreadDepth`: `fragmentspread_depth_test.go`
  `BenchmarkFragmentSpreadDepthCalc_Get`. The operation is the nested
  operation of that file, parsed outside the timer. Each operation clears
  one `Depths` and gets the depths into it, as upstream cuts its slice to
  zero length. `get` reads no definition, so none is parsed.

The baseline in `bench/baselines/go-normalization` runs the same workload.
"""

from _harness import Workload, measure
from gql_language.ast import Document
from gql_language.parser import parse
from gql_normalization.fragment_spread_depth import (
    Depths,
    FragmentSpreadDepth,
)

comptime NESTED = """
				subscription sub {
					...frag1
				}
				fragment frag1 on Subscription {
					newMessage {
						body
						sender
					}
					disallowedSecondRootField
					...frag2
				}
				fragment frag2 on Subscription {
					frag2Field
				}"""
"""The operation of upstream `BenchmarkFragmentSpreadDepthCalc_Get`."""


struct Depth(Movable, Workload):
    """Get the depths again and again: `BenchmarkFragmentSpreadDepthCalc_Get`.
    """

    var document: Document
    """The operation, parsed outside the timer."""
    var calculator: FragmentSpreadDepth
    """`FragmentSpreadDepth{}`, made once."""
    var depths: Depths
    """The depths, reused as upstream reuses its slice."""

    def __init__(out self) raises:
        """Parse the operation.

        Raises:
            Error: If the text does not parse.
        """
        self.document = parse(NESTED)
        self.calculator = FragmentSpreadDepth()
        self.depths = Depths()

    def run(mut self) raises -> Int:
        """Get the depths.

        Returns:
            The depth of the last spread.

        Raises:
            Error: If a fragment spreads itself.
        """
        self.depths.clear()
        self.calculator.get(self.document, self.depths)
        return self.depths.items[len(self.depths) - 1].depth


def main() raises:
    measure("go-tools/FragmentSpreadDepth", Depth())
