# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Hold subgraph response bodies until they are merged.

Port of `ResponsesStorage` in Hive Router `1a29df9`
`bin/router/src/executor/response/storage.rs`.

`estimate_size` is the total number of bytes plus 20 percent, for the
JSON syntax of the merged response.
"""


struct ResponseStorage(Movable):
    """The raw response bodies."""

    var responses: List[String]
    """The response texts, in the order they were added."""

    def __init__(out self):
        """Start an empty store."""
        self.responses = List[String]()

    def add(mut self, response: String):
        """Store one response body.

        Args:
            response: The response text.
        """
        self.responses.append(response)

    def estimate_size(self) -> Int:
        """Estimate the size of the merged response.

        Returns:
            The total byte length plus 20 percent, rounded down.
        """
        var total = 0
        for index in range(len(self.responses)):
            total += self.responses[index].byte_length()
        var scaled = Float64(total) * 1.2
        return Int(scaled)
