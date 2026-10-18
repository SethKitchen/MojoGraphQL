# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The federation version of a supergraph configuration.

Port of `FederationVersion` of `apollo-federation-types` 0.18.0-rc.1
`src/config/version.rs` (MIT), and of `parse_federation_version` and
`is_federation_one_exact_pin` of Rover `src/federation.rs`. An exact
version is a semantic version, as the `semver` crate reads it.
"""


@fieldwise_init
struct FederationVersionKind(Equatable, ImplicitlyCopyable, Writable):
    """The kind of a federation version: a latest release or an exact one."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime LATEST_FED_ONE = FederationVersionKind(0)
    """The latest federation 1 release: `0` or `1`."""
    comptime LATEST_FED_TWO = FederationVersionKind(1)
    """The latest federation 2 release: `2`."""
    comptime LATEST_FED_THREE = FederationVersionKind(2)
    """The latest federation 3 release: `3`."""
    comptime EXACT_FED_ONE = FederationVersionKind(3)
    """An exact federation 1 release, such as `=0.36.0`."""
    comptime EXACT_FED_TWO = FederationVersionKind(4)
    """An exact federation 2 release, such as `=2.3.0`."""
    comptime EXACT_FED_THREE = FederationVersionKind(5)
    """An exact federation 3 release, such as `=3.0.0`."""

    def is_valid(self) -> Bool:
        """Return True for one of the six kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 5

    def is_exact(self) -> Bool:
        """Return True for an exact release.

        Returns:
            Whether the kind names one release.
        """
        return self.value >= 3 and self.value <= 5

    def write_to(self, mut writer: Some[Writer]):
        """Write the upstream variant name, such as `LatestFedTwo`.

        Args:
            writer: The writer.
        """
        var names: List[String] = [
            "LatestFedOne",
            "LatestFedTwo",
            "LatestFedThree",
            "ExactFedOne",
            "ExactFedTwo",
            "ExactFedThree",
        ]
        writer.write(names[Int(self.value)] if self.is_valid() else "<invalid>")


def _numeric(text: StringSlice) -> Bool:
    """Return True for a run of ASCII digits."""
    var bytes = text.as_bytes()
    if len(bytes) == 0:
        return False
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        index += 1
        if byte < 48 or byte > 57:
            return False
    return True


def _identifier(text: StringSlice) -> Bool:
    """Return True for a non-empty run of ASCII letters, digits and `-`."""
    var bytes = text.as_bytes()
    if len(bytes) == 0:
        return False
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        index += 1
        var digit = byte >= 48 and byte <= 57
        var letter = (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)
        if not (digit or letter or byte == UInt8(ord("-"))):
            return False
    return True


def _number(text: StringSlice) -> Int:
    """Return the value of a semantic version number, or -1."""
    if not _numeric(text) or text.byte_length() > 18:
        return -1
    if text.byte_length() > 1 and text.startswith("0"):
        return -1
    var value = 0
    var bytes = text.as_bytes()
    var index = 0
    while index < len(bytes):
        value = value * 10 + Int(bytes[index]) - 48
        index += 1
    return value


@fieldwise_init
struct SemanticVersion(Copyable, Writable):
    """A semantic version: `major.minor.patch`, a pre-release and a build."""

    var major: Int
    """The major version."""
    var minor: Int
    """The minor version."""
    var patch: Int
    """The patch version."""
    var pre: List[String]
    """The pre-release identifiers, such as `preview` and `9`."""
    var text: String
    """The version as written, such as `2.0.0-preview.9`."""

    @staticmethod
    def parse(text: StringSlice) -> Optional[SemanticVersion]:
        """Read a semantic version, as the `semver` crate does.

        Args:
            text: Such as `2.3.0` or `2.0.0-preview.9+build`.

        Returns:
            The version, or None when the text is not one.
        """
        var core = String(text)
        var build = core.find("+")
        if build >= 0:
            var builds = String(core[byte = build + 1 :]).split(".")
            var index = 0
            while index < len(builds):
                if not _identifier(builds[index]):
                    return None
                index += 1
            var head = String(core[byte=:build])
            core = head^
        var pre = List[String]()
        var dash = core.find("-")
        if dash >= 0:
            var parts = String(core[byte = dash + 1 :]).split(".")
            var index = 0
            while index < len(parts):
                var part = parts[index]
                index += 1
                if not _identifier(part):
                    return None
                if _numeric(part) and _number(part) < 0:
                    return None
                pre.append(String(part))
            var head = String(core[byte=:dash])
            core = head^
        var numbers = core.split(".")
        if len(numbers) != 3:
            return None
        var values = List[Int]()
        var index = 0
        while index < len(numbers):
            var value = _number(numbers[index])
            if value < 0:
                return None
            values.append(value)
            index += 1
        return SemanticVersion(
            values[0], values[1], values[2], pre^, String(text)
        )

    def at_least(self, other: SemanticVersion) -> Bool:
        """Return True when this version has the precedence of `other` or more.

        Args:
            other: The version to compare with.

        Returns:
            Whether `self >= other` in semantic version precedence.
        """
        if self.major != other.major:
            return self.major > other.major
        if self.minor != other.minor:
            return self.minor > other.minor
        if self.patch != other.patch:
            return self.patch > other.patch
        if len(self.pre) == 0 or len(other.pre) == 0:
            return len(self.pre) == 0
        var shared = min(len(self.pre), len(other.pre))
        var index = 0
        while index < shared:
            ref mine = self.pre[index]
            ref theirs = other.pre[index]
            index += 1
            if mine == theirs:
                continue
            if _numeric(mine) and _numeric(theirs):
                return _number(mine) > _number(theirs)
            if _numeric(mine) != _numeric(theirs):
                return not _numeric(mine)
            return mine > theirs
        return len(self.pre) >= len(other.pre)

    def write_to(self, mut writer: Some[Writer]):
        """Write the version as written.

        Args:
            writer: The writer.
        """
        writer.write(self.text)


def _unsupported(input: StringSlice, detail: String) -> Error:
    """Return the `InvalidConfiguration` message of a version."""
    return Error(
        "Specified version `" + String(input) + "` is not supported. " + detail
    )


comptime _CHOICES = (
    "You can either specify '1', '2', '3', or a fully qualified version"
    " prefixed with an '=', like: =2.0.0"
)
"""The upstream list of the versions that a configuration can name."""


@fieldwise_init
struct FederationVersion(Copyable, Writable):
    """A federation version, as `apollo-federation-types` reads it."""

    var kind: FederationVersionKind
    """Latest or exact, and which major version."""
    var exact: String
    """The exact version, such as `2.3.0`; empty for a latest release."""

    @staticmethod
    def parse(input: StringSlice) raises -> FederationVersion:
        """Read a version, as upstream `FederationVersion::from_str`.

        Args:
            input: Such as `2`, `latest-2`, `=2.3.0` or `v2.3.0`.

        Returns:
            The version.

        Raises:
            Error: The upstream message, such as ``Specified version `4` is
                not supported. You can either specify '1', '2', '3', or a
                fully qualified version prefixed with an '=', like:
                =2.0.0``.
        """
        if input.byte_length() > 1 and (
            input.startswith("=") or input.startswith("v")
        ):
            var parsed = SemanticVersion.parse(input[byte=1:])
            if not parsed:
                raise _unsupported(input, _CHOICES)
            var version = parsed.take()
            var text = version.text.copy()
            if version.major == 0:
                if version.minor >= 36:
                    return FederationVersion(
                        FederationVersionKind.EXACT_FED_ONE, text^
                    )
                raise _unsupported(
                    input,
                    (
                        "The earliest version you can specify for federation 1"
                        " is '=0.36.0'"
                    ),
                )
            if version.major == 2:
                if version.at_least(
                    SemanticVersion(2, 0, 0, ["preview", "9"], "")
                ):
                    return FederationVersion(
                        FederationVersionKind.EXACT_FED_TWO, text^
                    )
                raise _unsupported(
                    input,
                    (
                        "The earliest version you can specify for federation 2"
                        " is '=2.0.0-preview.9'"
                    ),
                )
            if version.major == 3:
                if version.at_least(
                    SemanticVersion(3, 0, 0, ["preview", "0"], "")
                ):
                    return FederationVersion(
                        FederationVersionKind.EXACT_FED_THREE, text^
                    )
                raise _unsupported(
                    input,
                    (
                        "The earliest version you can specify for federation 3"
                        " is '=3.0.0-preview.0'"
                    ),
                )
            raise _unsupported(input, _CHOICES)
        if (
            input == "0"
            or input == "1"
            or input == "latest-0"
            or input == "latest-1"
        ):
            return FederationVersion(FederationVersionKind.LATEST_FED_ONE, "")
        if input == "2" or input == "latest-2":
            return FederationVersion(FederationVersionKind.LATEST_FED_TWO, "")
        if input == "3" or input == "latest-3":
            return FederationVersion(FederationVersionKind.LATEST_FED_THREE, "")
        raise _unsupported(input, _CHOICES)

    @staticmethod
    def from_number(number: Int) raises -> FederationVersion:
        """Read a version given as a YAML or JSON number, as upstream
        `visit_u64`.

        Args:
            number: Such as `2`.

        Returns:
            The latest release of that major version.

        Raises:
            Error: ``specified version `4` is not supported`` for a number
                other than 0, 1, 2 and 3.
        """
        if number == 0 or number == 1:
            return FederationVersion(FederationVersionKind.LATEST_FED_ONE, "")
        if number == 2:
            return FederationVersion(FederationVersionKind.LATEST_FED_TWO, "")
        if number == 3:
            return FederationVersion(FederationVersionKind.LATEST_FED_THREE, "")
        raise Error(
            "specified version `" + String(number) + "` is not supported"
        )

    def is_fed_one(self) -> Bool:
        """Return True for a federation 1 version, latest or exact.

        Returns:
            Whether Rover refuses the version.
        """
        return (
            self.kind == FederationVersionKind.LATEST_FED_ONE
            or self.kind == FederationVersionKind.EXACT_FED_ONE
        )

    def write_to(self, mut writer: Some[Writer]):
        """Write the version as upstream `Display`: `0`, `2`, `3` or
        `=<version>`.

        Args:
            writer: The writer.
        """
        if self.kind.is_exact():
            writer.write("=", self.exact)
        elif self.kind == FederationVersionKind.LATEST_FED_ONE:
            writer.write("0")
        elif self.kind == FederationVersionKind.LATEST_FED_TWO:
            writer.write("2")
        else:
            writer.write("3")


def is_federation_one_exact_pin(input: StringSlice) -> Bool:
    """Return True for an exact pin of a version below 2, as Rover
    `is_federation_one_exact_pin`.

    Args:
        input: Such as `=1.0.0` or `v0.36.0`.

    Returns:
        Whether the text pins a federation 1 version.
    """
    if not (input.startswith("=") or input.startswith("v")):
        return False
    var parsed = SemanticVersion.parse(input[byte=1:])
    return parsed.__bool__() and parsed.value().major < 2


comptime FEDERATION_2_MIGRATION_URL = "https://www.apollographql.com/docs/graphos/schema-design/federated-schemas/reference/moving-to-federation-2#opt-in-to-federation-2"
"""The page that Rover names when it refuses federation 1."""

comptime FEDERATION_ONE_UNSUPPORTED = (
    "Federation 1 is no longer supported by Rover. Migrate your subgraphs to"
    " Federation 2 by adding `@link` directives ("
    + FEDERATION_2_MIGRATION_URL
    + "), then remove any Federation 1 pin from your configuration."
)
"""The message of Rover `FederationOneUnsupported`."""


def parse_federation_version(input: StringSlice) raises -> FederationVersion:
    """Read a `--federation-version` value, as Rover
    `parse_federation_version`.

    Args:
        input: The value of the flag.

    Returns:
        The version.

    Raises:
        Error: `FEDERATION_ONE_UNSUPPORTED` for an exact pin below 2 that
            the version grammar refuses, or ``Specified version `x` is not
            supported. You can specify '2', '3', or a fully qualified
            version prefixed with an '=', like: =2.0.0``.
    """
    try:
        return FederationVersion.parse(input)
    except:
        if is_federation_one_exact_pin(input):
            raise Error(FEDERATION_ONE_UNSUPPORTED)
        raise Error(
            "Specified version `"
            + String(input)
            + "` is not supported. You can specify '2', '3', or a fully"
            " qualified version prefixed with an '=', like: =2.0.0"
        )
