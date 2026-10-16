# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The versions of the Apollo Federation specification.

Port of the `FederationVersion` type and `isFederationVersion` of Hive
Federation Composition v0.27.0 `src/specifications/federation.ts`, and of
`src/utils/version.ts`.

The versions are one table, `VERSION_NAMES`. The source of each version:

- `v1.0` and `v2.0` to `v2.9`: Hive Federation Composition v0.27.0.
- `v2.10` to `v2.15`: the public Apollo GraphOS page "Federation versions"
  (apollographql.com/docs/graphos/schema-design/federated-schemas/reference/versions).
  `v2.10`, `v2.11` and `v2.13` to `v2.15` add no directives or types;
  `v2.12` adds `@cacheTag`.

**Differences from upstream.** Upstream compares versions with
`parseFloat`, which puts `v2.10` below `v2.9`. This port keeps a version as
`major * 100 + minor`: `v2.3` is 203 and `v2.10` is 210. Upstream v0.27.0
does not know `v2.10` to `v2.15`.
"""

comptime VERSION_COUNT = 17
"""How many versions `VERSION_NAMES` lists."""

comptime VERSION_NAMES: Array[StaticString, VERSION_COUNT] = [
    "v1.0",
    "v2.0",
    "v2.1",
    "v2.2",
    "v2.3",
    "v2.4",
    "v2.5",
    "v2.6",
    "v2.7",
    "v2.8",
    "v2.9",
    "v2.10",
    "v2.11",
    "v2.12",
    "v2.13",
    "v2.14",
    "v2.15",
]
"""The version strings, in order; the index is the version's value."""


@fieldwise_init
struct FederationVersion(Equatable, ImplicitlyCopyable, Writable):
    """A version of the federation specification: `v1.0` or `v2.0` to
    `v2.15`."""

    var value: UInt8
    """The index of the version in `VERSION_NAMES`; see `is_valid`."""

    comptime V1_0 = FederationVersion(0)
    """`v1.0`."""
    comptime V2_0 = FederationVersion(1)
    """`v2.0`."""
    comptime V2_9 = FederationVersion(10)
    """`v2.9`."""
    comptime V2_12 = FederationVersion(13)
    """`v2.12`."""
    comptime LATEST = FederationVersion(VERSION_COUNT - 1)
    """The highest version: `v2.15`."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the versions.

        Returns:
            Whether the value is in range.
        """
        return Int(self.value) < VERSION_COUNT

    def number(self) -> Int:
        """Return the version number as `major * 100 + minor`, such as 203
        for `v2.3`.

        Returns:
            The number; 100 for `v1.0`.
        """
        if self.value == 0:
            return 100
        return 199 + Int(self.value)

    def text(self) -> String:
        """Return the version string, such as `v2.3`.

        Returns:
            The string, or `<invalid>`.
        """
        if not self.is_valid():
            return String("<invalid>")
        return String(materialize[VERSION_NAMES]()[Int(self.value)])

    @staticmethod
    def from_text(text: StringSlice) -> Int:
        """Return the index of the version with a string, as upstream
        `isFederationVersion`.

        Args:
            text: A string such as `v2.3`.

        Returns:
            The version's index, or -1 when the string is not a version.
        """
        var index = 0
        while index < VERSION_COUNT:
            if text == materialize[VERSION_NAMES]()[index]:
                return index
            index += 1
        return -1

    def at_least(self, number: Int) -> Bool:
        """Return True for the range `>= v<number>`.

        Args:
            number: The version number, as `number` returns it.

        Returns:
            Whether this version is at least that version.
        """
        return self.number() >= number

    def above(self, number: Int) -> Bool:
        """Return True for the range `> v<number>`.

        Args:
            number: The version number, as `number` returns it.

        Returns:
            Whether this version is higher than that version.
        """
        return self.number() > number

    def below(self, number: Int) -> Bool:
        """Return True for the range `< v<number>`.

        Args:
            number: The version number, as `number` returns it.

        Returns:
            Whether this version is lower than that version.
        """
        return self.number() < number

    def write_to(self, mut writer: Some[Writer]):
        """Write the version string.

        Args:
            writer: The writer.
        """
        writer.write(self.text())
