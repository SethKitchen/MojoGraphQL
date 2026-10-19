# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Write `_validation_fixtures.mojo`: the validation fixtures, as Mojo code.

`validation_fixtures/ok/` holds the `.graphql` files of apollo-compiler
`test_data/ok/`, and `validation_fixtures/diagnostics/` holds the
`.graphql` and `.txt` files of `test_data/diagnostics/`. `make coverage`
copies only the Mojo files of `tests/`, so `test_validation.mojo` reads
the fixtures from `_validation_fixtures.mojo`. The expected text of a case
keeps only the `Error:` lines and the `╭─[ file:line:column ]` lines of
the upstream `.txt` file. After a change in `validation_fixtures/`, run
from the repository root:

    .venv/bin/mojo run -I . tests/gql_compiler/_embed_validation.mojo

The module is laid out as `mojo format` lays it out.
"""

from std.os import listdir
from std.pathlib import Path

comptime ROOT = "tests/gql_compiler/validation_fixtures/"
"""The fixtures, from the repository root."""
comptime OUTPUT = "tests/gql_compiler/_validation_fixtures.mojo"
"""The module to write."""
comptime CHUNK = 60
"""The longest escaped text of one literal."""


def cases() raises -> List[String]:
    """Return the cases, sorted, as `<directory>/<name>.graphql`.

    Returns:
        The paths from `ROOT`.

    Raises:
        Error: If a directory cannot be listed.
    """
    var out = List[String]()
    for directory in ["diagnostics", "ok"]:
        var entries = listdir(ROOT + directory)
        sort(entries)
        for ref entry in entries:
            if entry.endswith(".graphql"):
                out.append(String(directory, "/", entry))
    return out^


def expected(path: String) raises -> String:
    """Return the `Error:` and `╭─[` lines of the `.txt` file of a case.

    Args:
        path: The case, from `ROOT`.

    Returns:
        The lines, each with a newline, with the leading spaces of a `╭─[`
        line removed. Empty for a case of `ok/`.

    Raises:
        Error: If the file cannot be read.
    """
    if path.startswith("ok/"):
        return String()
    var text = Path(
        ROOT + path[byte = : path.byte_length() - 8] + ".txt"
    ).read_text()
    var out = String()
    for line in text.splitlines():
        if line.startswith("Error: "):
            out += String(line) + "\n"
        else:
            var trimmed = line.lstrip()
            if trimmed.startswith("╭─["):
                out += String(trimmed) + "\n"
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
    var paths = cases()
    var out = String(
        "# Copyright (c) 2026 Seth Kitchen, PE\n"
        "# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0\n"
        "# Noncommercial use is free; commercial use requires a paid"
        " license.\n"
        "# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.\n"
        "\n"
        '"""The files of `validation_fixtures/`, written by'
        ' `_embed_validation.mojo`.\nDo not edit."""\n'
    )
    for index in range(len(paths)):
        out += function("_path_" + String(index), paths[index])
        out += function(
            "_input_" + String(index), Path(ROOT + paths[index]).read_text()
        )
        out += function("_expected_" + String(index), expected(paths[index]))
    out += "\n\ndef validation_cases() -> List[String]:\n"
    out += '    """Return the path of each case."""\n'
    out += "    var out = List[String]()\n"
    for index in range(len(paths)):
        out += "    out.append(_path_" + String(index) + "())\n"
    out += "    return out^\n"
    out += "\n\ndef validation_input(index: Int) -> String:\n"
    out += '    """Return the input document of a case."""\n'
    for index in range(len(paths)):
        out += "    if index == " + String(index) + ":\n"
        out += "        return _input_" + String(index) + "()\n"
    out += '    return ""\n'
    out += "\n\ndef validation_expected(index: Int) -> String:\n"
    out += '    """Return the expected lines of a case."""\n'
    for index in range(len(paths)):
        out += "    if index == " + String(index) + ":\n"
        out += "        return _expected_" + String(index) + "()\n"
    out += '    return ""\n'
    Path(OUTPUT).write_text(out)
    print("wrote", OUTPUT, len(paths), "cases")
