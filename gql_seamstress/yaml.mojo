# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A minimal YAML reader, for the supergraph configuration of Rover.

Rover reads `supergraph.yaml` with serde_yaml. This reader accepts the
subset that a supergraph configuration uses, and gives the value as a
`gql_json` document:

- block mappings and block sequences, nested by indentation;
- plain, single-quoted and double-quoted scalars, as `yaml_scalar` reads
  them;
- literal (`|`) and folded (`>`) block scalars, with the `-` and `+`
  chomping indicators and an indentation indicator;
- comments, a `---` document start and a `...` document end;
- the empty flow collections `{}` and `[]`;
- a JSON text, which is a YAML text too: it is read with `gql_json`.

**Differences from upstream.** serde_yaml reads all of YAML 1.2. This
reader refuses anchors, aliases, tags, non-empty flow collections and more
than one document, with an error that names the line. Its error messages
are not the serde_yaml messages.
"""

from gql_json.parser import parse as parse_json
from gql_json.value import JsonDocument
from gql_seamstress.yaml_scalar import add_plain, read_quoted, strip_comment
from gql_seamstress.yaml_scalar import yaml_error

comptime _SPACE = UInt8(ord(" "))
comptime _DASH = UInt8(ord("-"))


@fieldwise_init
struct _Line(Copyable, Movable):
    """One line of the text."""

    var raw: String
    """The line, without its line break."""
    var indent: Int
    """The spaces before the content, or -1 for a blank line."""
    var text: String
    """The content, without the indent and the comment."""
    var number: Int
    """The 1-based line number."""
    var has_break: Bool
    """Whether a line break ends the line."""


def _is_item(text: StringSlice) -> Bool:
    """Return True for a block sequence entry: `-` alone or `- x`."""
    return text == "-" or text.startswith("- ")


def _entry_colon(text: StringSlice, number: Int) raises -> Int:
    """Return the index of the `:` of a mapping entry, or -1; the text is
    not empty."""
    var bytes = text.as_bytes()
    if _is_item(text):
        return -1
    var index = 0
    if bytes[0] == UInt8(ord('"')) or bytes[0] == UInt8(ord("'")):
        index = read_quoted(text, 0, number)[1]
        while index < len(bytes) and bytes[index] == _SPACE:
            index += 1
        if index < len(bytes) and bytes[index] == UInt8(ord(":")):
            return index
        return -1
    while index < len(bytes):
        if bytes[index] == UInt8(ord(":")) and (
            index + 1 == len(bytes) or bytes[index + 1] == _SPACE
        ):
            return index
        index += 1
    return -1


def _key(text: StringSlice, colon: Int, number: Int) raises -> String:
    """Return the key of a mapping entry whose `:` is at `colon`."""
    var bytes = text.as_bytes()
    if bytes[0] == UInt8(ord('"')) or bytes[0] == UInt8(ord("'")):
        return read_quoted(text, 0, number)[0]
    var key = String(text[byte=:colon]).rstrip()
    if key == "":
        raise yaml_error(number, "a mapping entry has no key")
    return String(key)


struct _Reader(Movable):
    """Reads the lines of a YAML text into a document."""

    var lines: List[_Line]
    """The lines."""
    var at: Int
    """The next line to read."""
    var document: JsonDocument
    """The document that receives the values."""

    def __init__(out self, var lines: List[_Line]):
        """Start reading lines."""
        self.lines = lines^
        self.at = 0
        self.document = JsonDocument()

    def take(deinit self) -> JsonDocument:
        """Return the document."""
        return self.document^

    def skip_blank(mut self):
        """Move past blank and comment lines."""
        while self.at < len(self.lines) and self.lines[self.at].indent < 0:
            self.at += 1

    def node(mut self, parent: Int) raises -> Int:
        """Read the block node at the next line, below `parent`."""
        var indent = self.lines[self.at].indent
        var text = self.lines[self.at].text.copy()
        var number = self.lines[self.at].number
        if _is_item(text):
            return self.sequence(indent)
        if _entry_colon(text, number) >= 0:
            return self.mapping(indent)
        return self.scalar(parent)

    def nested(mut self, indent: Int, sequence_ok: Bool) raises -> Int:
        """Read the value below an entry that has no inline value."""
        self.skip_blank()
        if self.at < len(self.lines):
            var next = self.lines[self.at].indent
            if next > indent or (
                sequence_ok
                and next == indent
                and _is_item(self.lines[self.at].text)
            ):
                return self.node(indent)
        return self.document.add_null()

    def mapping(mut self, indent: Int) raises -> Int:
        """Read a block mapping whose keys are at `indent`."""
        var object = self.document.add_object()
        var seen = List[String]()
        while True:
            self.skip_blank()
            if self.at >= len(self.lines):
                break
            var line = self.lines[self.at].copy()
            if line.indent < indent:
                break
            if line.indent > indent:
                raise yaml_error(
                    line.number, "a mapping entry is indented too far"
                )
            var colon = _entry_colon(line.text, line.number)
            if colon < 0:
                raise yaml_error(line.number, "a mapping entry was expected")
            var key = _key(line.text, colon, line.number)
            if key in seen:
                raise yaml_error(
                    line.number, "the key `" + key + "` is repeated"
                )
            seen.append(key)
            var rest = String(String(line.text[byte = colon + 1 :]).lstrip())
            self.at += 1
            var value: Int
            if rest == "":
                value = self.nested(indent, True)
            else:
                value = self.inline(rest, line.number, indent)
            self.document.add_member(object, key, value)
        return object

    def sequence(mut self, indent: Int) raises -> Int:
        """Read a block sequence whose `-` entries are at `indent`."""
        var array = self.document.add_array()
        while True:
            self.skip_blank()
            if self.at >= len(self.lines):
                break
            var line = self.lines[self.at].copy()
            if line.indent < indent or not _is_item(line.text):
                if line.indent > indent:
                    raise yaml_error(
                        line.number, "a sequence entry was expected"
                    )
                break
            if line.indent > indent:
                raise yaml_error(
                    line.number, "a sequence entry is indented too far"
                )
            var rest = String(String(line.text[byte=1:]).lstrip())
            var value: Int
            if rest == "":
                self.at += 1
                value = self.nested(indent, False)
            elif _is_item(rest) or _entry_colon(rest, line.number) >= 0:
                var offset = line.text.byte_length() - rest.byte_length()
                self.lines[self.at].indent = indent + offset
                self.lines[self.at].text = rest
                value = self.node(indent)
            else:
                self.at += 1
                value = self.inline(rest, line.number, indent)
            self.document.append(array, value)
        return array

    def scalar(mut self, parent: Int) raises -> Int:
        """Read a scalar node that starts at the next line."""
        var line = self.lines[self.at].copy()
        self.at += 1
        var first = line.text.as_bytes()[0]
        if first == UInt8(ord('"')) or first == UInt8(ord("'")):
            return self.inline(line.text, line.number, parent)
        var words = List[String]()
        words.append(line.text)
        while self.at < len(self.lines) and self.lines[self.at].indent > parent:
            words.append(self.lines[self.at].text)
            self.at += 1
        return self.inline(String(" ").join(words), line.number, parent)

    def inline(mut self, text: String, number: Int, parent: Int) raises -> Int:
        """Read the value that follows `key:` or `- ` on its line."""
        var first = text.as_bytes()[0]
        if first == UInt8(ord('"')) or first == UInt8(ord("'")):
            var quoted = read_quoted(text, 0, number)
            if quoted[1] != text.byte_length():
                raise yaml_error(number, "text follows a quoted scalar")
            return self.document.add_string(quoted[0])
        if first == UInt8(ord("|")) or first == UInt8(ord(">")):
            return self.block(text, number, parent)
        if text == "{}":
            return self.document.add_object()
        if text == "[]":
            return self.document.add_array()
        var refused = "{[&*!%@`"
        if refused.find(String(text[byte=:1])) >= 0:
            raise yaml_error(
                number,
                "flow collections, anchors, aliases and tags are not supported",
            )
        if text.find(": ") >= 0:
            raise yaml_error(number, "a mapping value is not allowed here")
        return add_plain(self.document, text)

    def block(mut self, header: String, number: Int, parent: Int) raises -> Int:
        """Read a literal or folded block scalar after its header line."""
        var literal = header.startswith("|")
        var chomp = 0
        var explicit = 0
        var bytes = header.as_bytes()
        for index in range(1, len(bytes)):
            var byte = bytes[index]
            if byte == _DASH and chomp == 0:
                chomp = -1
            elif byte == UInt8(ord("+")) and chomp == 0:
                chomp = 1
            elif byte >= 49 and byte <= 57 and explicit == 0:
                explicit = Int(byte) - 48
            else:
                raise yaml_error(number, "an invalid block scalar header")
        var indent = parent + explicit if explicit > 0 else -1
        var body = List[String]()
        var trailing = 0
        var ends_with_break = True
        while self.at < len(self.lines):
            ref line = self.lines[self.at]
            if line.indent < 0 and String(line.raw).strip() == "":
                trailing += 1
                ends_with_break = line.has_break
                self.at += 1
                continue
            var lead = (
                line.raw.byte_length()
                - String(line.raw).lstrip(" ").byte_length()
            )
            if lead <= parent:
                break
            if indent < 0:
                indent = lead
            if lead < indent:
                raise yaml_error(
                    line.number, "a block scalar line is indented too little"
                )
            for _ in range(trailing):
                body.append(String(""))
            trailing = 0
            body.append(String(line.raw[byte=indent:]))
            ends_with_break = line.has_break
            self.at += 1
        var text = String("\n").join(body) if literal else _fold(body)
        if len(body) > 0 and (ends_with_break or trailing > 0):
            if chomp >= 0:
                text += "\n"
        if chomp == 1:
            for _ in range(trailing):
                text += "\n"
        return self.document.add_string(text)


def _fold(lines: List[String]) -> String:
    """Fold the lines of a `>` block scalar, as YAML folds them."""
    var out = String()
    for index in range(len(lines)):
        ref line = lines[index]
        if index == 0:
            out += line
        elif line == "" or lines[index - 1] == "":
            out += "\n" + line if line == "" else line
        elif line.startswith(" ") or lines[index - 1].startswith(" "):
            out += "\n" + line
        else:
            out += " " + line
    return out^


def _split(text: StringSlice) raises -> List[_Line]:
    """Split a text into lines, and find the indent of each."""
    var out = List[_Line]()
    var started = False
    var number = 0
    var raws = text.split("\n")
    var index = 0
    while index < len(raws):
        number += 1
        var raw = String(String(raws[index]).removesuffix("\r"))
        var has_break = index + 1 < len(raws)
        if not has_break and raw == "":
            break
        var body = String(raw.lstrip(" "))
        var indent = raw.byte_length() - body.byte_length()
        var content = strip_comment(body)
        if body.startswith("\t") and content != "":
            raise yaml_error(number, "a tab character is not valid indentation")
        if indent == 0 and (content == "---" or content.startswith("--- ")):
            if started or content != "---":
                raise yaml_error(number, "only one YAML document is supported")
            started = True
            content = String("")
        if indent == 0 and content == "...":
            break
        if content != "":
            started = True
        var line_indent = indent if content != "" else -1
        out.append(_Line(raw^, line_indent, content^, number, has_break))
        index += 1
    return out^


def parse_yaml(text: StringSlice) raises -> JsonDocument:
    """Read a YAML text into a `gql_json` document.

    Args:
        text: The YAML text, or a JSON text.

    Returns:
        The document. Its root is null for an empty text.

    Raises:
        Error: For a text outside the supported subset, such as
            `line 3: a mapping entry is indented too far`, or for a JSON
            text that `gql_json` does not accept.
    """
    var trimmed = String(text).lstrip()
    if trimmed.startswith("{") or trimmed.startswith("["):
        try:
            return parse_json(text)
        except e:
            raise Error(String(e))
    var reader = _Reader(_split(text))
    reader.skip_blank()
    if reader.at >= len(reader.lines):
        reader.document.root = reader.document.add_null()
    else:
        reader.document.root = reader.node(-1)
        reader.skip_blank()
        if reader.at < len(reader.lines):
            raise yaml_error(
                reader.lines[reader.at].number,
                "unexpected text after the value",
            )
    return reader^.take()
