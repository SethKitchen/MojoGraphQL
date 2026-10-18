# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The federation directives and types of each federation version.

`@apollo/subgraph` 2.14.4 takes these definitions from
`@apollo/federation-internals`, which is Elastic licensed and is not read.
This module implements them from the public specifications instead:
https://specs.apollo.dev/federation/v2.0 to v2.15, the federation 1
subgraph specification, and https://specs.apollo.dev/link/v1.0. Hive
Federation Composition v0.27.0 `src/specifications/federation.ts` (MIT) is
the reference for the version history. The order of the definitions and
their exact text are what `@apollo/subgraph` 2.14.4 prints, observed as a
black box.

**Differences from upstream.** `@apollo/subgraph` 2.14.4 rejects federation
`v2.15`. The public specification for `v2.15` adds no directives or types,
so this port accepts `v2.15` and uses the `v2.14` definitions.
"""

comptime DIRECTIVE_COUNT = 19
"""How many federation 2 directives there are."""

comptime FED1_DIRECTIVE_COUNT = 6
"""How many federation 1 directives there are: the first six."""

comptime TYPE_COUNT = 4
"""How many federation 2 types there are."""

comptime LATEST_MINOR = 15
"""The latest supported federation 2 minor version."""

comptime LINK_URL = "https://specs.apollo.dev/link/v1.0"
"""The URL of the link specification."""

comptime FEDERATION_URL = "https://specs.apollo.dev/federation/"
"""The URL of the federation specification, before the version."""

comptime LINK_SDL = """directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA
"""
"""The `@link` definition of the link specification."""

comptime LINK_PURPOSE_SDL = '''enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}
'''
"""The `link__Purpose` enum of the link specification."""

comptime _NAMES: Array[StaticString, DIRECTIVE_COUNT] = [
    "key",
    "requires",
    "provides",
    "external",
    "tag",
    "extends",
    "shareable",
    "inaccessible",
    "override",
    "composeDirective",
    "interfaceObject",
    "authenticated",
    "requiresScopes",
    "policy",
    "context",
    "fromContext",
    "cost",
    "listSize",
    "cacheTag",
]

comptime _SINCE: Array[Int, DIRECTIVE_COUNT] = [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    3,
    5,
    5,
    6,
    8,
    8,
    9,
    9,
    12,
]

comptime _TAG_LOCATIONS = (
    "FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION |"
    " SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION"
)
comptime _AUTH_LOCATIONS = (
    "FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM"
)

comptime _BODIES: Array[StaticString, DIRECTIVE_COUNT] = [
    (
        "(fields: $F!, resolvable: Boolean = true) repeatable on OBJECT |"
        " INTERFACE"
    ),
    "(fields: $F!) on FIELD_DEFINITION",
    "(fields: $F!) on FIELD_DEFINITION",
    "(reason: String) on OBJECT | FIELD_DEFINITION",
    "(name: String!) repeatable on " + _TAG_LOCATIONS,
    " on OBJECT | INTERFACE",
    " on OBJECT | FIELD_DEFINITION",
    " on " + _TAG_LOCATIONS,
    "(from: String!) on FIELD_DEFINITION",
    "(name: String) repeatable on SCHEMA",
    " on OBJECT",
    " on " + _AUTH_LOCATIONS,
    "(scopes: [[$S!]!]!) on " + _AUTH_LOCATIONS,
    "(policies: [[$P!]!]!) on " + _AUTH_LOCATIONS,
    "(name: String!) repeatable on INTERFACE | OBJECT | UNION",
    "(field: $C) on ARGUMENT_DEFINITION",
    (
        "(weight: Int!) on ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION |"
        " INPUT_FIELD_DEFINITION | OBJECT | SCALAR"
    ),
    (
        "(assumedSize: Int, slicingArguments: [String!], sizedFields:"
        " [String!], requireOneSlicingArgument: Boolean = true) on"
        " FIELD_DEFINITION"
    ),
    "(format: String!) repeatable on OBJECT | FIELD_DEFINITION",
]

comptime _TYPE_NAMES: Array[StaticString, TYPE_COUNT] = [
    "FieldSet",
    "Scope",
    "Policy",
    "ContextFieldValue",
]

comptime _TYPE_SINCE: Array[Int, TYPE_COUNT] = [0, 5, 6, 8]


@fieldwise_init
struct FederationVersion(Equatable, ImplicitlyCopyable, Writable):
    """A federation version: federation 1, or federation 2.0 to 2.15."""

    var value: UInt8
    """Zero for federation 1, or one more than the federation 2 minor
    version; see `is_valid`."""

    comptime FED1 = FederationVersion(0)
    """Federation 1: a subgraph with no `@link` to the federation
    specification."""

    @staticmethod
    def v2(minor: Int) -> FederationVersion:
        """Return federation 2 of a minor version.

        Args:
            minor: The minor version, from 0 to `LATEST_MINOR`.

        Returns:
            The version.
        """
        return FederationVersion(UInt8(minor + 1))

    def is_valid(self) -> Bool:
        """Return True for federation 1 or a supported federation 2 version.

        Returns:
            Whether the value is in range.
        """
        return Int(self.value) <= LATEST_MINOR + 1

    def is_fed2(self) -> Bool:
        """Return True for a federation 2 version.

        Returns:
            Whether the version is not federation 1.
        """
        return self.value > 0

    def minor(self) -> Int:
        """Return the federation 2 minor version; federation 1 gives 0.

        Returns:
            The minor version.
        """
        return max(Int(self.value) - 1, 0)

    def write_to(self, mut writer: Some[Writer]):
        """Write `v1`, or `v2.` and the minor version.

        Args:
            writer: The destination.
        """
        if self.is_fed2():
            writer.write("v2.", self.minor())
        else:
            writer.write("v1")


def directive_name(index: Int) -> String:
    """Return the name of a federation directive, without `@`.

    Args:
        index: The directive, from 0 to `DIRECTIVE_COUNT - 1`.

    Returns:
        The name, such as `key`.
    """
    return String(materialize[_NAMES]()[index])


def directive_index(name: StringSlice) -> Int:
    """Return the index of a federation directive.

    Args:
        name: The name, without `@`.

    Returns:
        The index, or -1 when no federation directive has the name.
    """
    var index = 0
    while index < DIRECTIVE_COUNT:
        if materialize[_NAMES]()[index] == name:
            return index
        index += 1
    return -1


def has_directive(version: FederationVersion, index: Int) -> Bool:
    """Return True when a version defines a federation directive.

    Args:
        version: The version.
        index: The directive.

    Returns:
        Whether the directive exists in the version.
    """
    if version.is_fed2():
        return version.minor() >= materialize[_SINCE]()[index]
    return index < FED1_DIRECTIVE_COUNT


def directive_body(
    index: Int, version: FederationVersion, types: List[String]
) -> String:
    """Return a federation directive definition after its name.

    Args:
        index: The directive.
        version: The version, which changes `@tag`, `@shareable` and
            `@override`.
        types: The names of the four federation types in this schema.

    Returns:
        The arguments, `repeatable` and the locations, such as
        `(fields: _FieldSet!) on FIELD_DEFINITION`.
    """
    var body = String(materialize[_BODIES]()[index])
    var minor = version.minor()
    if index == 4 and version.is_fed2() and minor >= 3:
        body += " | SCHEMA"
    elif index == 6 and minor >= 2:
        body = " repeatable on OBJECT | FIELD_DEFINITION"
    elif index == 8 and minor >= 7:
        body = "(from: String!, label: String) on FIELD_DEFINITION"
    body = body.replace("$F", types[0]).replace("$S", types[1])
    return body.replace("$P", types[2]).replace("$C", types[3])


def type_name(index: Int) -> String:
    """Return the name of a federation type, without a prefix.

    Args:
        index: The type, from 0 to `TYPE_COUNT - 1`.

    Returns:
        The name, such as `FieldSet`.
    """
    return String(materialize[_TYPE_NAMES]()[index])


def type_index(name: StringSlice) -> Int:
    """Return the index of a federation type.

    Args:
        name: The name, without a prefix.

    Returns:
        The index, or -1 when no federation type has the name.
    """
    var index = 0
    while index < TYPE_COUNT:
        if materialize[_TYPE_NAMES]()[index] == name:
            return index
        index += 1
    return -1


def has_type(version: FederationVersion, index: Int) -> Bool:
    """Return True when a federation 2 version defines a federation type.

    Args:
        version: The version.
        index: The type.

    Returns:
        Whether the type exists in the version.
    """
    return version.minor() >= materialize[_TYPE_SINCE]()[index]


def _number(text: StringSlice, start: Int, end: Int) -> Int:
    """Return the decimal number of some bytes, or -1 for none or a byte
    that is not a digit; large numbers stop at 10000."""
    if start >= end:
        return -1
    var bytes = text.as_bytes()
    var value = 0
    var index = start
    while index < end:
        var byte = Int(bytes[index])
        if byte < 48 or byte > 57:
            return -1
        value = min(value * 10 + byte - 48, 10000)
        index += 1
    return value


def _version_numbers(version: String) -> List[Int]:
    """Return the major and minor numbers of `v1.2`; -1 for one that is
    not a number."""
    var dot = version.find(".")
    var numbers: List[Int] = [-1, -1]
    if version.startswith("v") and dot > 0:
        numbers[0] = _number(version, 1, dot)
        numbers[1] = _number(version, dot + 1, version.byte_length())
    return numbers^


def check_federation_url(url: StringSlice) raises:
    """Check the form of the version of a `@link` URL to the federation
    specification, before the version is checked against those supported.

    Args:
        url: The URL, which starts with `FEDERATION_URL`.

    Raises:
        Error: `Expected a version string (of the form v1.2), got X` when
            the version is not `v` and two numbers.
    """
    var version = String(
        url[byte = StaticString(FEDERATION_URL).byte_length() :]
    )
    var numbers = _version_numbers(version)
    if numbers[0] < 0 or numbers[1] < 0:
        raise Error(
            "Expected a version string (of the form v1.2), got " + version
        )


def parse_federation_url(url: StringSlice) raises -> FederationVersion:
    """Return the version of a `@link` URL to the federation specification.

    Args:
        url: The URL, which starts with `FEDERATION_URL`.

    Returns:
        The federation 2 version.

    Raises:
        Error: The error of `check_federation_url`; `Invalid version X for
            the federation feature in @link directive on schema` when the
            version is not supported.
    """
    check_federation_url(url)
    var version = String(
        url[byte = StaticString(FEDERATION_URL).byte_length() :]
    )
    var numbers = _version_numbers(version)
    var major = numbers[0]
    var minor = numbers[1]
    if major != 2 or minor > LATEST_MINOR:
        raise Error(
            "Invalid version "
            + version
            + " for the federation feature in @link directive on schema"
        )
    return FederationVersion.v2(minor)
