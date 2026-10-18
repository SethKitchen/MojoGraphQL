# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `@link` directive: its URL and its imports.

Port of `parseLinkUrl`, `parseLinkImport`, `parseLink` and
`parseLinkDirective` of Hive Federation Composition v0.27.0
`src/specifications/link.ts`.

A link URL such as `https://specs.apollo.dev/federation/v2.3` has an
identity (`https://specs.apollo.dev/federation`), a name (`federation`) and
a version (`v2.3`). A URL that does not parse is an opaque identity.
`LinkUrl.supports` is `FederatedLinkUrl.supports` from
`src/utils/link/link-url.ts`. A major version above zero accepts an equal
or lower minor version. Major version zero accepts only the same minor
version. `links_from_document` and `resolve_imported_name` are
`extractLinkImplementations` from `src/utils/link/index.ts`.

**Differences from upstream.**

- Upstream parses the URL with the WHATWG `URL` class. This port reads the
  scheme, the host, the port and the path itself. It lowercases the scheme
  and the host, drops the user information and a default port, resolves
  `.` and `..` path segments, and percent-encodes a space, `"`, `<`, `>`,
  a backtick, `{`, `}` and each byte that is not ASCII in the path. It
  percent-decodes the host and refuses the forbidden domain code points.
  It does not convert an international domain name, an IPv6 address or an
  IPv4 address in a short or hexadecimal form.
- Upstream prints the `import` argument and parses the text with JSON5.
  This port reads the value from the AST. The result and the messages are
  the same. The column in a JSON5 syntax error is exact for an enum value
  and a block string, which are the only literals that JSON5 refuses.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_composition.printer import print_node


@fieldwise_init
struct ImportKind(Equatable, ImplicitlyCopyable, Writable):
    """What a link import names: a directive or a type."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime DIRECTIVE = ImportKind(0)
    """A directive: the name starts with `@`."""
    comptime TYPE = ImportKind(1)
    """A type."""

    def is_valid(self) -> Bool:
        """Return True for `DIRECTIVE` and `TYPE`.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 1

    def text(self) -> StaticString:
        """Return the upstream string: `directive` or `type`.

        Returns:
            The string, or `<invalid>`.
        """
        if self.value == 0:
            return "directive"
        if self.value == 1:
            return "type"
        return "<invalid>"

    @staticmethod
    def of(name: StringSlice) -> ImportKind:
        """Return the kind of an imported name.

        Args:
            name: The name, such as `@key` or `FieldSet`.

        Returns:
            `DIRECTIVE` when the name starts with `@`, else `TYPE`.
        """
        if name.startswith("@"):
            return ImportKind.DIRECTIVE
        return ImportKind.TYPE

    def write_to(self, mut writer: Some[Writer]):
        """Write the upstream string.

        Args:
            writer: The writer.
        """
        writer.write(self.text())


@fieldwise_init
struct LinkImport(Copyable, Writable):
    """One element of the `import` argument of `@link`."""

    var kind: ImportKind
    """Whether it imports a directive or a type."""
    var name: String
    """The imported name, such as `@key`."""
    var alias: Optional[String]
    """The local name from `as`, such as `@primaryKey`, if any."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the import as `kind name` or `kind name as alias`.

        Args:
            writer: The writer.
        """
        writer.write(self.kind, " ", self.name)
        if self.alias:
            writer.write(" as ", self.alias.value())


@fieldwise_init
struct LinkUrl(Copyable, Writable):
    """The parts of a link URL, as upstream `parseLinkUrl` returns them."""

    var name: Optional[String]
    """The feature name, such as `federation`, if any."""
    var version: Optional[String]
    """The version, such as `v2.3`, if any."""
    var identity: String
    """The URL without the version, the query and the fragment."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the identity, the name and the version.

        Args:
            writer: The writer.
        """
        writer.write(self.identity, " name=")
        writer.write(self.name.value() if self.name else String("null"))
        writer.write(" version=")
        writer.write(self.version.value() if self.version else String("null"))

    def supports(self, major: Int, minor: Int) -> Bool:
        """Return True when this URL's version accepts another version, as
        upstream `isCompatibleVersion`.

        Args:
            major: The required major version.
            minor: The required minor version.

        Returns:
            Whether the versions are compatible.
        """
        var own = _match_version(
            self.version.value() if self.version else String("")
        )
        if own.major != major:
            return False
        if own.major == 0:
            return own.minor == minor
        return own.minor >= minor

    def supports_version(self, version: String) -> Bool:
        """Return True when this URL accepts a version string, as upstream
        `supports`.

        Args:
            version: A string such as `v2.0`.

        Returns:
            Whether `supports` accepts the parsed major and minor.
        """
        var asked = _match_version(version)
        return self.supports(asked.major, asked.minor)

    def supports_link(self, other: LinkUrl) -> Bool:
        """Return True when another link URL is the same feature at a
        compatible version.

        Args:
            other: The required link URL.

        Returns:
            Whether the identities match and the version is compatible.
        """
        if other.identity != self.identity:
            return False
        var asked = _match_version(
            other.version.value() if other.version else String("")
        )
        return self.supports(asked.major, asked.minor)

    def supports_missing(self) -> Bool:
        """Return True when this URL has no version, as upstream
        `supports(null)`.

        Returns:
            Whether the version is absent.
        """
        if self.version:
            return False
        return True


@fieldwise_init
struct Link(Copyable):
    """A parsed `@link` directive."""

    var name: Optional[String]
    """The feature name, if any."""
    var version: Optional[String]
    """The version, if any."""
    var identity: String
    """The identity of the feature."""
    var imports: List[LinkImport]
    """The imported directives and types."""
    var alias: Optional[String]
    """The `@link(as:)` name, if any."""

    def is_federation(self) -> Bool:
        """Return True for a link to the federation specification, as
        upstream `isFederationLink`.

        Returns:
            Whether the identity is `https://specs.apollo.dev/federation`.
        """
        return self.identity == "https://specs.apollo.dev/federation"

    def resolve_import_name(self, element: String) -> String:
        """Return the local name of an imported element, as upstream
        `FederatedLink.resolveImportName`.

        Args:
            element: The specification name, such as `@key` or `FieldSet`.

        Returns:
            The local name without a leading `@`.
        """
        # A link URL never has an empty feature name.
        if self.name and element == "@" + self.name.value():
            if self.alias:
                return String(self.alias.value())
            return String(self.name.value())
        var resolved = String("")
        var found = False
        for index in range(len(self.imports)):
            if self.imports[index].name == element:
                found = True
                if self.imports[index].alias:
                    resolved = self.imports[index].alias.value()
                else:
                    resolved = String(self.imports[index].name)
                break
        if not found:
            var namespace = String("")
            if self.alias:
                namespace = self.alias.value()
            elif self.name:
                namespace = self.name.value()
            resolved = _namespaced(namespace, element)
        return _drop_at(resolved)


@fieldwise_init
struct _ParsedUrl(Copyable):
    """What this port reads from a URL: the WHATWG `origin`, `pathname`
    and `protocol`."""

    var origin: String
    var parts: List[String]
    var is_file: Bool


def _default_port(scheme: String) -> String:
    """Return the default port of a special scheme other than `file`."""
    if scheme == "http" or scheme == "ws":
        return String("80")
    if scheme == "https" or scheme == "wss":
        return String("443")
    return String("21")


def _is_special(scheme: String) -> Bool:
    """Return True for the WHATWG special schemes."""
    return (
        scheme == "http"
        or scheme == "https"
        or scheme == "ws"
        or scheme == "wss"
        or scheme == "ftp"
        or scheme == "file"
    )


def _is_alpha(byte: UInt8) -> Bool:
    """Return True for an ASCII letter."""
    return (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)


def _is_digit(byte: UInt8) -> Bool:
    """Return True for an ASCII digit."""
    return byte >= 48 and byte <= 57


def _text(bytes: Span[UInt8, _], start: Int, end: Int) -> String:
    """Return the bytes between two offsets as a string."""
    return String(unsafe_from_utf8=bytes[start:end])


def _is_path_end(byte: UInt8) -> Bool:
    """Return True for `?` and `#`, which end a path."""
    return byte == 63 or byte == 35


def _is_host_end(byte: UInt8) -> Bool:
    """Return True for `/`, a backslash, `?` and `#`, which end a host."""
    return byte == 47 or byte == 92 or _is_path_end(byte)


def _needs_escape(byte: UInt8) -> Bool:
    """Return True for a byte that the WHATWG path percent-encode set
    holds: a control, a space, `"`, `<`, `>`, a backtick, `{`, `}`, and
    each byte that is not ASCII."""
    return (
        byte <= 32
        or byte >= 127
        or byte == 34
        or byte == 60
        or byte == 62
        or byte == 96
        or byte == 123
        or byte == 125
    )


comptime _FORBIDDEN_HOST = " #%/:<>?@[\\]^|"
"""The WHATWG forbidden domain code points other than the controls."""


def _is_forbidden_host_byte(byte: UInt8) -> Bool:
    """Return True for a byte that a WHATWG domain cannot hold."""
    if byte < 32 or byte == 127:
        return True
    var forbidden = _FORBIDDEN_HOST.as_bytes()
    var index = 0
    while index < len(forbidden):
        if byte == forbidden[index]:
            return True
        index += 1
    return False


def _hex_value(byte: UInt8) -> Int:
    """Return the value of a hex digit, or -1."""
    if _is_digit(byte):
        return Int(byte) - 48
    var lower = byte | 32
    if lower >= 97 and lower <= 102:
        return Int(lower) - 87
    return -1


def _decoded_host(bytes: Span[UInt8, _], start: Int, end: Int) -> List[UInt8]:
    """Percent-decode a host, as WHATWG `percentDecode`; an invalid `%`
    stays."""
    var out = List[UInt8](capacity=end - start)
    var index = start
    while index < end:
        var byte = bytes[index]
        if byte == 37 and index + 2 < end:
            var high = _hex_value(bytes[index + 1])
            var low = _hex_value(bytes[index + 2])
            if high != -1 and low != -1:
                out.append(UInt8(high * 16 + low))
                index += 3
                continue
        out.append(byte)
        index += 1
    return out^


def _upper_hex(value: UInt8) -> UInt8:
    """Return the uppercase hex digit of a value below 16."""
    if value < 10:
        return 48 + value
    return 55 + value


def _dot_segment(segment: String) -> Int:
    """Return 1 for a WHATWG single-dot segment (`.` or `%2e`), 2 for a
    double-dot segment (such as `..` or `.%2E`), else 0."""
    var lowered = segment.lower().replace("%2e", ".")
    if lowered == ".":
        return 1
    if lowered == "..":
        return 2
    return 0


def _path_parts(bytes: Span[UInt8, _], start: Int, end: Int) -> List[String]:
    """Return the non-empty segments of a path, with `.` and `..`
    resolved and the WHATWG path characters percent-encoded."""
    var parts = List[String]()
    var segment = List[UInt8]()
    var index = start
    while index <= end:
        var at_end = index == end
        var byte = UInt8(47) if at_end else bytes[index]
        if byte == 47 or byte == 92:
            if len(segment) > 0:
                var text = String(unsafe_from_utf8=segment)
                var dots = _dot_segment(text)
                if dots == 2:
                    if len(parts) > 0:
                        _ = parts.pop()
                elif dots == 0:
                    parts.append(text^)
                segment.clear()
        elif _needs_escape(byte):
            segment.append(37)
            segment.append(_upper_hex(byte >> 4))
            segment.append(_upper_hex(byte & 15))
        else:
            segment.append(byte)
        index += 1
    return parts^


def _parse_url(url: String) -> Optional[_ParsedUrl]:
    """Parse an absolute URL as the WHATWG `URL` class does, or return
    nothing when it would throw."""
    var raw = url.as_bytes()
    var start = 0
    var end = len(raw)
    while start < end and raw[start] <= 32:
        start += 1
    while end > start and raw[end - 1] <= 32:
        end -= 1
    var clean = List[UInt8](capacity=end - start)
    for index in range(start, end):
        var byte = raw[index]
        if byte != 9 and byte != 10 and byte != 13:
            clean.append(byte)
    var bytes = Span(clean)
    var size = len(bytes)
    if size == 0 or not _is_alpha(bytes[0]):
        return None
    var colon = 1
    while colon < size and (
        _is_alpha(bytes[colon])
        or _is_digit(bytes[colon])
        or bytes[colon] == 43
        or bytes[colon] == 45
        or bytes[colon] == 46
    ):
        colon += 1
    if colon == size or bytes[colon] != 58:
        return None
    var scheme = _text(bytes, 0, colon).lower()
    var position = colon + 1
    if not _is_special(scheme):
        if (
            position + 1 < size
            and bytes[position] == 47
            and bytes[position + 1] == 47
        ):
            position += 2
            while position < size and not _is_host_end(bytes[position]):
                position += 1
        var path_end = position
        while path_end < size and not _is_path_end(bytes[path_end]):
            path_end += 1
        return _ParsedUrl(
            String("null"), _path_parts(bytes, position, path_end), False
        )
    if scheme == "file":
        if (
            position + 1 < size
            and (bytes[position] == 47 or bytes[position] == 92)
            and (bytes[position + 1] == 47 or bytes[position + 1] == 92)
        ):
            position += 2
            while position < size and not _is_host_end(bytes[position]):
                position += 1
        var file_end = position
        while file_end < size and not _is_path_end(bytes[file_end]):
            file_end += 1
        return _ParsedUrl(
            String("null"), _path_parts(bytes, position, file_end), True
        )
    while position < size and (bytes[position] == 47 or bytes[position] == 92):
        position += 1
    var host_start = position
    while position < size and not _is_host_end(bytes[position]):
        position += 1
    var host_end = position
    var at = host_end - 1
    while at >= host_start and bytes[at] != 64:
        at -= 1
    if at >= host_start:
        host_start = at + 1
    var port_colon = host_end - 1
    while port_colon >= host_start and _is_digit(bytes[port_colon]):
        port_colon -= 1
    var port = String("")
    var name_end = host_end
    if port_colon >= host_start and bytes[port_colon] == 58:
        port = _text(bytes, port_colon + 1, host_end)
        name_end = port_colon
    if name_end == host_start:
        return None
    var host = _decoded_host(bytes, host_start, name_end)
    var host_index = 0
    while host_index < len(host):
        if _is_forbidden_host_byte(host[host_index]):
            return None
        host_index += 1
    if port.byte_length() > 0:
        var number = 0
        var digits = port.as_bytes()
        var digit_index = 0
        while digit_index < len(digits):
            number = number * 10 + Int(digits[digit_index]) - 48
            if number > 65535:
                return None
            digit_index += 1
        port = String(number)
        if port == _default_port(scheme):
            port = String("")
    var origin = scheme + "://" + String(unsafe_from_utf8=host).lower()
    if port.byte_length() > 0:
        origin += ":" + port
    var path_end = position
    while path_end < size and not _is_path_end(bytes[path_end]):
        path_end += 1
    return _ParsedUrl(origin^, _path_parts(bytes, position, path_end), False)


@fieldwise_init
struct _Version(Copyable):
    """A major and minor version read from a link URL."""

    var major: Int
    """The major version, or `-1` when the text has no version."""
    var minor: Int
    """The minor version, or `-1` when the text has no version."""


def _read_digits(bytes: Span[UInt8, _], start: Int, limit: Int) -> Int:
    """Return how many digits, at most `limit`, start at `start`."""
    var count = 0
    var index = start
    while count < limit and index < len(bytes) and _is_digit(bytes[index]):
        count += 1
        index += 1
    return count


def _digits_value(bytes: Span[UInt8, _], start: Int, count: Int) -> Int:
    """Return the integer stored in `count` digits."""
    var value = 0
    var index = 0
    while index < count:
        value = value * 10 + Int(bytes[start + index] - 48)
        index += 1
    return value


def _match_version(text: String) -> _Version:
    """Find `vMAJOR.MINOR` in text, as upstream `parseVersion`.

    Args:
        text: A version such as `v2.3`, or empty.

    Returns:
        The first match. Major has one to three digits and minor has one
        to four. No match is major `-1` and minor `-1`.
    """
    var bytes = text.as_bytes()
    var index = 0
    while index < len(bytes):
        var mark = bytes[index]
        if mark == 118 or mark == 86:
            var major_count = _read_digits(bytes, index + 1, 3)
            var dot = index + 1 + major_count
            if major_count > 0 and dot < len(bytes) and bytes[dot] == 46:
                var minor_count = _read_digits(bytes, dot + 1, 4)
                if minor_count > 0:
                    return _Version(
                        _digits_value(bytes, index + 1, major_count),
                        _digits_value(bytes, dot + 1, minor_count),
                    )
        index += 1
    return _Version(-1, -1)


def _is_version(part: String) -> Bool:
    """Return True for a segment that upstream reads as a version: `v` or
    `V` and then a digit."""
    var bytes = part.as_bytes()
    return (
        len(bytes) >= 2
        and (bytes[0] == 118 or bytes[0] == 86)
        and _is_digit(bytes[1])
    )


def parse_link_url(url: String) -> LinkUrl:
    """Split a link URL into its name, version and identity, as upstream
    `parseLinkUrl`.

    Args:
        url: The `url` argument of `@link`.

    Returns:
        The parts. A URL that does not parse is an identity without a name
        and a version.
    """
    var parsed = _parse_url(url)
    if not parsed:
        return LinkUrl(None, None, url)
    ref found = parsed.value()
    var count = len(found.parts)
    if count == 0:
        return LinkUrl(None, None, found.origin)
    var last = found.parts[count - 1]
    if _is_version(last):
        if count >= 2:
            var identity = found.origin
            var index = 0
            while index < count - 1:
                identity += "/" + found.parts[index]
                index += 1
            return LinkUrl(found.parts[count - 2], last, identity^)
        return LinkUrl(None, last, found.origin)
    # Node gives a `file:` URL the origin `null`; upstream writes `file://`.
    var identity = String("file://") if found.is_file else found.origin
    var index = 0
    while index < count:
        identity += "/" + found.parts[index]
        index += 1
    return LinkUrl(last, None, identity^)


def _code_points(text: StringSlice) -> Int:
    """Return the number of code points of a string, as JSON5 counts
    columns."""
    var count = 0
    var bytes = text.as_bytes()
    var index = 0
    while index < len(bytes):
        if bytes[index] & 0xC0 != 0x80:
            count += 1
        index += 1
    return count


def _literal_error(text: String, literal: String, column: Int) -> Int:
    """Return the column where JSON5 stops reading an enum value as a
    literal such as `Infinity`, or -1 when the value is the literal."""
    var bytes = text.as_bytes()
    var expected = literal.as_bytes()
    var index = 0
    while index < len(bytes) and index < len(expected):
        if bytes[index] != expected[index]:
            return column + index
        index += 1
    if len(bytes) == len(expected):
        return -1
    return column + index


def _json5_error_column(document: Document, node: Int, column: Int) -> Int:
    """Return the column of the first character that JSON5 refuses in the
    printed value, or -1 when JSON5 reads all of it."""
    var kind = document.kind(node)
    if kind == Kind.STRING:
        if document.is_block(node):
            return column + 2
        return -1
    if kind == Kind.ENUM:
        var text = String(document.text(node))
        if text.startswith("I"):
            return _literal_error(text, "Infinity", column)
        if text.startswith("N"):
            return _literal_error(text, "NaN", column)
        if text.startswith("t"):
            return _literal_error(text, "true", column)
        if text.startswith("f"):
            return _literal_error(text, "false", column)
        if text.startswith("n"):
            return _literal_error(text, "null", column)
        return column
    if kind != Kind.LIST and kind != Kind.OBJECT:
        return -1
    var position = column + 1
    var first = True
    var child = document.first_child(node)
    while child != NO_NODE:
        if not first:
            position += 2
        first = False
        var value = child
        if kind == Kind.OBJECT:
            position += _code_points(document.name(child)) + 2
            value = document.child(child, Role.VALUE)
        var found = _json5_error_column(document, value, position)
        if found != -1:
            return found
        position += _code_points(print_node(document, value))
        child = document.next_sibling(child)
    return -1


def _format_char(text: String, column: Int) -> String:
    """Return the JSON5 message part for the character at a column:
    `invalid character 'c'`, or `invalid end of input`."""
    var index = 0
    var current = 1
    var bytes = text.as_bytes()
    while index < len(bytes) and current < column:
        index += 1
        while index < len(bytes) and bytes[index] & 0xC0 == 0x80:
            index += 1
        current += 1
    if index >= len(bytes):
        return String("invalid end of input")
    # The refused character is ASCII: the start of an enum value, a letter
    # of a literal, or the third quote of a block string.
    var char = String(unsafe_from_utf8=bytes[index : index + 1])
    if char == '"':
        char = '\\"'
    return "invalid character '" + char + "'"


def _is_falsy_number(text: StringSlice) -> Bool:
    """Return True when a number literal is zero, which JavaScript reads
    as false."""
    var bytes = text.as_bytes()
    var index = 0
    while index < len(bytes):
        var byte = bytes[index]
        if byte == 101 or byte == 69:
            return True
        # Past `e` and `E`, a number holds no byte above `9`.
        if byte >= 49:
            return False
        index += 1
    return True


def _truthiness(document: Document, node: Int) -> Int:
    """Return 0 for a value that JavaScript reads as false, 1 for a
    non-empty string, and 2 for another value that it reads as true."""
    var kind = document.kind(node)
    if kind == Kind.STRING:
        return 1 if document.string_value(node).byte_length() > 0 else 0
    if kind == Kind.NULL:
        return 0
    if kind == Kind.BOOLEAN:
        return 2 if document.boolean_value(node) else 0
    if kind == Kind.INT or kind == Kind.FLOAT:
        return 0 if _is_falsy_number(document.text(node)) else 2
    if kind == Kind.ENUM:
        return 0 if document.text(node) == "NaN" else 2
    return 2


def _last_field(document: Document, node: Int, name: StringSlice) -> Int:
    """Return the value of the last field with a name of an object value,
    as JSON5 keeps the last key, or `NO_NODE`."""
    var found = NO_NODE
    var field = document.first_child(node)
    while field != NO_NODE:
        if document.name(field) == name:
            found = document.child(field, Role.VALUE)
        field = document.next_sibling(field)
    return found


def _binding(document: Document, node: Int) raises -> LinkImport:
    """Read one import binding, or raise the inner message of the upstream
    error."""
    var kind = document.kind(node)
    if kind == Kind.STRING:
        var name = document.string_value(node)
        return LinkImport(ImportKind.of(name), name, None)
    if kind == Kind.NULL:
        raise Error(
            "TypeError: Cannot read properties of null (reading 'name')"
        )
    if kind != Kind.OBJECT:
        raise Error("Error: Syntax")
    var name_node = _last_field(document, node, "name")
    var name_truth = 0 if name_node == NO_NODE else _truthiness(
        document, name_node
    )
    if name_truth == 0:
        raise Error("Error: Syntax")
    if name_truth == 2:
        raise Error("TypeError: binding.name.startsWith is not a function")
    var name = document.string_value(name_node)
    var name_kind = ImportKind.of(name)
    var as_node = _last_field(document, node, "as")
    var as_truth = 0 if as_node == NO_NODE else _truthiness(document, as_node)
    if as_truth == 0:
        return LinkImport(name_kind, name, None)
    if as_truth == 2:
        raise Error("TypeError: binding.as.startsWith is not a function")
    var alias = document.string_value(as_node)
    if ImportKind.of(alias) != name_kind:
        raise Error(
            "Error: " + name + " and " + alias + " must be of the same kind"
        )
    return LinkImport(name_kind, name, alias)


def parse_link_import(document: Document, node: Int) raises -> List[LinkImport]:
    """Read the `import` argument of `@link`, as upstream `parseLinkImport`
    reads its printed value.

    Args:
        document: The document that holds the value.
        node: The value of the `import` argument, or `NO_NODE` for `[]`.

    Returns:
        The imports, in order.

    Raises:
        Error: `Invalid import binding: <value>: <reason>`, with the reason
            of upstream, when the value is not a list of bindings.
    """
    var imports = List[LinkImport]()
    if node == NO_NODE:
        return imports^
    var printed = print_node(document, node)
    var column = _json5_error_column(document, node, 1)
    if column != -1:
        raise Error(
            "Invalid import binding: "
            + printed
            + ": SyntaxError: JSON5: "
            + _format_char(printed, column)
            + " at 1:"
            + String(column)
        )
    if document.kind(node) != Kind.LIST:
        raise Error(
            "Invalid import binding: " + printed + ": Error: Expected an array"
        )
    var item = document.first_child(node)
    while item != NO_NODE:
        try:
            imports.append(_binding(document, item))
        except error:
            raise Error(
                "Invalid import binding: " + printed + ": " + String(error)
            )
        item = document.next_sibling(item)
    return imports^


def parse_link_directive(
    document: Document, directive: Int
) raises -> Optional[Link]:
    """Read a `@link` directive, as upstream `parseLinkDirective`.

    Args:
        document: The document that holds the directive.
        directive: The `Directive` node.

    Returns:
        The link, or nothing when no `url` argument holds a string.

    Raises:
        Error: When the `import` argument is a list that does not hold
            bindings.
    """
    var url = NO_NODE
    var import_value = NO_NODE
    var alias = String("")
    var has_alias = False
    var argument = document.first_child(directive)
    while argument != NO_NODE:
        if document.role(argument) == Role.ARGUMENT:
            var value = document.child(argument, Role.VALUE)
            if (
                url == NO_NODE
                and document.name(argument) == "url"
                and document.kind(value) == Kind.STRING
            ):
                url = value
            if (
                import_value == NO_NODE
                and document.name(argument) == "import"
                and document.kind(value) == Kind.LIST
            ):
                import_value = value
            if (
                not has_alias
                and document.name(argument) == "as"
                and document.kind(value) == Kind.STRING
            ):
                alias = document.string_value(value)
                has_alias = True
        argument = document.next_sibling(argument)
    if url == NO_NODE:
        return None
    var spec = parse_link_url(document.string_value(url))
    var imports = parse_link_import(document, import_value)
    var local: Optional[String] = None
    if has_alias:
        local = Optional[String](alias)
    return Link(spec.name, spec.version, spec.identity, imports^, local)


def _drop_at(name: String) -> String:
    """Return a name without one leading `@`."""
    if name.startswith("@"):
        var rest = String(name[byte=1:])
        return rest^
    return name


def _namespaced(namespace: String, name: String) -> String:
    """Return a name under a link namespace, as upstream `namespaced`.

    Args:
        namespace: The `@link(as:)` name, or the feature name.
        name: The element name.

    Returns:
        The namespaced name. An empty namespace leaves the name unchanged.
    """
    if namespace.byte_length() == 0:
        return name
    if name.startswith("@"):
        var rest = String(name[byte=1:])
        return "@" + namespace + "__" + rest
    return namespace + "__" + name


def _core_link(document: Document, directive: Int) -> Optional[Link]:
    """Read a `@core(feature:)` directive as a link with no imports.

    Args:
        document: The document that holds the directive.
        directive: The `Directive` node.

    Returns:
        The link, or nothing when `feature` is not a string.
    """
    var argument = document.first_child(directive)
    while argument != NO_NODE:
        if (
            document.role(argument) == Role.ARGUMENT
            and document.name(argument) == "feature"
        ):
            var value = document.child(argument, Role.VALUE)
            if document.kind(value) == Kind.STRING:
                var spec = parse_link_url(document.string_value(value))
                return Link(
                    spec.name,
                    spec.version,
                    spec.identity,
                    List[LinkImport](),
                    None,
                )
            return None
        argument = document.next_sibling(argument)
    return None


def links_from_document(document: Document) raises -> List[Link]:
    """Return the `@link` and `@core` directives on schema definitions, as
    upstream `FederatedLink.fromTypedefs`.

    Args:
        document: A subgraph document.

    Returns:
        The links. Each schema definition lists `@link`, then `@core`.

    Raises:
        Error: When an `import` list does not hold bindings.
    """
    var found = List[Link]()
    var definitions = document.children(document.root, Role.DEFINITION)
    var index = 0
    while index < len(definitions):
        var definition = definitions[index]
        index += 1
        var kind = document.kind(definition)
        if kind != Kind.SCHEMA_DEFINITION and kind != Kind.SCHEMA_EXTENSION:
            continue
        var directives = document.children(definition, Role.DIRECTIVE)
        for directive_index in range(len(directives)):
            var directive = directives[directive_index]
            if document.name(directive) == "link":
                var parsed = parse_link_directive(document, directive)
                if parsed:
                    found.append(parsed.value().copy())
        for directive_index in range(len(directives)):
            var directive = directives[directive_index]
            if document.name(directive) == "core":
                var parsed = _core_link(document, directive)
                if parsed:
                    found.append(parsed.value().copy())
    return found^


def _matching_link(links: List[Link], identity: String) -> Int:
    """Return the last link with an identity, or -1.

    Args:
        links: The links from one document.
        identity: The feature identity.

    Returns:
        The index, or -1.
    """
    var found = -1
    for index in range(len(links)):
        if links[index].identity == identity:
            found = index
    return found


def resolve_imported_name(
    links: List[Link], identity: String, name: String
) -> String:
    """Return the local name for a feature element, as upstream
    `resolveImportName`.

    Args:
        links: The links from one document.
        identity: The feature identity.
        name: The specification name, such as `@key`.

    Returns:
        The local name. A feature that is not linked drops one leading `@`.
    """
    var at = _matching_link(links, identity)
    if at < 0:
        return _drop_at(name)
    return links[at].resolve_import_name(name)


def is_federation_v1(links: List[Link]) -> Bool:
    """Return True when the document has no `@link`, as upstream
    `FEDERATION_V1`.

    Args:
        links: The links from one document.

    Returns:
        Whether the document is treated as federation v1.
    """
    return len(links) == 0


def link_supports_version(
    links: List[Link], identity: String, version: String
) -> Bool:
    """Return True when a linked feature accepts a version string.

    Args:
        links: The links from one document.
        identity: The feature identity.
        version: A version such as `v2.0`.

    Returns:
        Whether the last link with that identity accepts the version.
    """
    var at = _matching_link(links, identity)
    if at < 0:
        return False
    var spec = LinkUrl(
        links[at].name, links[at].version, String(links[at].identity)
    )
    return spec.supports_version(version)


def link_supports_missing(links: List[Link], identity: String) -> Bool:
    """Return True when a linked feature has no version.

    Args:
        links: The links from one document.
        identity: The feature identity.

    Returns:
        Whether the last link with that identity has no version.
    """
    var at = _matching_link(links, identity)
    if at < 0:
        return False
    var spec = LinkUrl(
        links[at].name, links[at].version, String(links[at].identity)
    )
    return spec.supports_missing()
