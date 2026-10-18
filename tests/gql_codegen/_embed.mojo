# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Write `_fixture_data.mojo`: every file of `fixtures/`, as Mojo code.

`make coverage` copies only the Mojo files of `tests/`, so a suite cannot
read `fixtures/` there. The suites read the fixtures from
`_fixture_data.mojo` instead, and `test_fixture_data.mojo` checks that it
holds the files of `fixtures/` as they are. After a change in
`fixtures/`, run from the repository root:

    .venv/bin/mojo run -I . tests/gql_codegen/_embed.mojo

The module is laid out as `mojo format` lays it out, so `make fmt` keeps
it as it is.
"""

from std.os import listdir
from std.os.path import isdir
from std.pathlib import Path

comptime ROOT = "tests/gql_codegen/fixtures/"
"""The fixtures, from the repository root."""
comptime OUTPUT = "tests/gql_codegen/_fixture_data.mojo"
"""The module to write."""
comptime CHUNK = 60
"""The longest escaped text of one literal."""


def files(directory: String) raises -> List[String]:
    """Return the files below a directory, sorted, as relative paths.

    Args:
        directory: A directory below `ROOT`, empty or with a trailing
            slash.

    Returns:
        The paths from `ROOT`.

    Raises:
        Error: If a directory cannot be listed.
    """
    var out = List[String]()
    var entries = listdir(ROOT + directory)
    sort(entries)
    for ref entry in entries:
        var path = directory + entry
        if isdir(ROOT + path):
            out.extend(files(path + "/"))
        else:
            out.append(path)
    return out^


def escaped(byte: UInt8, quote: UInt8) -> String:
    """Return the literal text of one byte."""
    if byte == quote:
        return "\\" + chr(Int(byte))
    if byte == UInt8(ord("\\")):
        return "\\\\"
    if byte == UInt8(ord("\n")):
        return "\\n"
    if byte == UInt8(ord("\t")):
        return "\\t"
    if byte == UInt8(ord("\r")):
        return "\\r"
    return String(unsafe_from_utf8=[byte])


def literal(text: StringSlice) -> String:
    """Quote text as `mojo format` quotes it: double quotes, unless single
    quotes need fewer escapes."""
    var doubles = 0
    var singles = 0
    for byte in text.as_bytes():
        if byte == UInt8(ord('"')):
            doubles += 1
        elif byte == UInt8(ord("'")):
            singles += 1
    var quote = UInt8(ord("'")) if singles < doubles else UInt8(ord('"'))
    var out = String(chr(Int(quote)))
    for byte in text.as_bytes():
        out += escaped(byte, quote)
    out += chr(Int(quote))
    return out^


def chunks(text: StringSlice) -> List[String]:
    """Split text into pieces whose escaped text is at most `CHUNK` bytes,
    never inside a UTF-8 sequence."""
    var bytes = text.as_bytes()
    var out = List[String]()
    var start = 0
    var size = 0
    var index = 0
    while index < len(bytes):
        var end = index + 1
        while end < len(bytes) and bytes[end] & 0xC0 == 0x80:
            end += 1
        var width = 0
        for position in range(index, end):
            width += escaped(bytes[position], UInt8(ord('"'))).byte_length()
        if size + width > CHUNK and index > start:
            out.append(String(unsafe_from_utf8=Span(bytes)[start:index]))
            start = index
            size = 0
        size += width
        index = end
    out.append(String(unsafe_from_utf8=Span(bytes)[start:]))
    return out^


def function(name: String, text: StringSlice) -> String:
    """Return a function that builds a text from short literals."""
    var out = "\n\ndef " + name + "() -> String:\n"
    out += "    var out = String()\n"
    if text.byte_length() > 0:
        for ref piece in chunks(text):
            out += "    out += " + literal(piece) + "\n"
    out += "    return out^\n"
    return out^


def main() raises:
    var paths = files("")
    var out = String(
        "# Copyright (c) 2026 Seth Kitchen, PE\n"
        "# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0\n"
        "# Noncommercial use is free; commercial use requires a paid"
        " license.\n"
        "# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.\n"
        "\n"
        '"""The files of `fixtures/`, written by `_embed.mojo`. Do not'
        ' edit."""\n'
    )
    for index in range(len(paths)):
        out += function("_path_" + String(index), paths[index])
        out += function(
            "_file_" + String(index), Path(ROOT + paths[index]).read_text()
        )
    out += "\n\ndef fixture_paths() -> List[String]:\n"
    out += '    """Return the path of each file, from `fixtures/`."""\n'
    out += "    var out = List[String]()\n"
    for index in range(len(paths)):
        out += "    out.append(_path_" + String(index) + "())\n"
    out += "    return out^\n"
    out += "\n\ndef fixture_text(path: StringSlice) raises -> String:\n"
    out += '    """Return the text of a file of `fixtures/`."""\n'
    for index in range(len(paths)):
        out += "    if path == _path_" + String(index) + "():\n"
        out += "        return _file_" + String(index) + "()\n"
    out += '    raise Error("no fixture " + String(path))\n'
    Path(OUTPUT).write_text(out)
    print("wrote", OUTPUT, len(paths), "files")
