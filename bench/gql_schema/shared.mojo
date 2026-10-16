# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Schema workloads that every baseline can run.

`shared/parse-build-<fixture>` parses SDL text and builds a schema, with no
SDL validation: graphql-js `buildSchema(text, { assumeValid: true })` and
apollo-compiler `Schema::parse`.
"""

from _harness import BuildSchema, fixture, measure


def main() raises:
    """Run the shared workloads."""
    var names: List[String] = ["github-schema", "go-tools-starwars.schema"]
    for ref name in names:
        measure(
            "shared/parse-build-" + name,
            BuildSchema(fixture(name + ".graphql")),
        )
