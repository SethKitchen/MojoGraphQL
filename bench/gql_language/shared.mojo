# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The MojoGraphQL workloads that every implementation runs.

`parse` parses a text. `parse-print` parses it and prints it again, as
graphql-js `print(parse(text))`. `print` prints a document parsed once,
outside the timer.
"""

from _harness import Parse, ParsePrint, Print, fixture, measure


def main() raises:
    """Run the shared workloads."""
    var names: List[String] = ["kitchen-sink", "github-schema", "github-query"]
    for ref name in names:
        measure("shared/parse-" + name, Parse(fixture(name + ".graphql")))
    for ref name in names:
        measure(
            "shared/parse-print-" + name, ParsePrint(fixture(name + ".graphql"))
        )
    for ref name in names:
        measure("shared/print-" + name, Print(fixture(name + ".graphql")))
