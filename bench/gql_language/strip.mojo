# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `stripIgnoredCharacters` workloads, against graphql-js 16.14.2.

Each operation is graphql-js `stripIgnoredCharacters(text)` on a fixture:
the kitchen sink document, and the GitHub schema, which has many block
string descriptions.
"""

from _harness import Workload, fixture, measure
from gql_language.strip_ignored_characters import strip_ignored_characters


struct Strip(Movable, Workload):
    """Strip a text: graphql-js `stripIgnoredCharacters(text)`."""

    var text: String
    """The GraphQL text."""

    def __init__(out self, var text: String):
        """Hold the text to strip.

        Args:
            text: The GraphQL text.
        """
        self.text = text^

    def run(mut self) raises -> Int:
        """Strip the text once.

        Returns:
            The length of the stripped text.

        Raises:
            Error: If the text has a lexical error.
        """
        try:
            return strip_ignored_characters(self.text).byte_length()
        except e:
            raise Error(String(e))


def main() raises:
    """Run the strip workloads."""
    measure(
        "shared/strip-ignored-kitchen-sink",
        Strip(fixture("kitchen-sink.graphql")),
    )
    measure(
        "shared/strip-ignored-github-schema",
        Strip(fixture("github-schema.graphql")),
    )
