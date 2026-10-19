# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests of `gql_http2.hpack` on the hpack-test-entry corpus.

Ports `src/hpack/test/fixture.rs` of hyperium/h2 v0.4.20. The corpus has
no license, so the repository does not hold a copy. These tests read it
from `$HOME/mgql-upstream/hyperium_h2/fixtures/hpack`, the h2 checkout of
the upstream directory, and pass with no checks when it is not there, or
under `make coverage`, where the probes would make them take minutes. The
unit tests cover every line.

For each story of each encoder, the decoder decodes each block and must
give its fields. Then the encoder encodes the fields of each block, and a
second decoder must give them back. The `raw-data` stories have fields
and no blocks: they take the second step only.

The deterministic part of `src/hpack/test/fuzz.rs`, random fields that
round-trip through an encoder and a decoder with table size changes, is
`test_random_round_trip`.
"""

from std.os import getenv, listdir
from std.os.path import exists
from std.pathlib import Path
from std.testing import TestSuite, assert_equal, assert_true

from gql_http2.hpack import Decoder, Encoder, HeaderList
from gql_json.parser import parse_bytes
from gql_json.value import NO_NODE, JsonDocument

from _hpack_util import fields_text


def _root() -> String:
    return getenv("HOME") + "/mgql-upstream/hyperium_h2/fixtures/hpack/"


def _hex_digit(byte: UInt8) -> Int:
    if byte <= 57:
        return Int(byte) - 48
    return (Int(byte) | 32) - 87


def _wire(text: StringSlice) -> List[UInt8]:
    var data = text.as_bytes()
    var out = List[UInt8](capacity=len(data) // 2)
    var index = 0
    while index + 1 < len(data):
        out.append(
            UInt8(_hex_digit(data[index]) * 16 + _hex_digit(data[index + 1]))
        )
        index += 2
    return out^


def _fields(document: JsonDocument, entry: Int) raises -> HeaderList:
    var fields = HeaderList()
    var headers = document.get(entry, "headers")
    var item = document.first(headers)
    while item != NO_NODE:
        var member = document.first(item)
        var name = document.key(member)
        var value = document.string_value(member)
        fields.add_text(name, value)
        item = document.next(item)
    return fields^


def _table_size(document: JsonDocument, entry: Int) raises -> Int:
    var node = document.find(entry, "header_table_size")
    if node == NO_NODE:
        return -1
    return Int(document.as_int64(node))


def _story(path: String) raises -> Int:
    """Check one story; return the number of blocks it checked."""
    var document = parse_bytes(Path(path).read_bytes())
    var cases_node = document.find(document.root, "cases")
    if cases_node == NO_NODE:
        return 0
    var cases = document.children(cases_node)
    var checked = 0
    var decoder = Decoder()
    for entry in cases:
        var wire = document.find(entry, "wire")
        if wire == NO_NODE:
            break
        var size = _table_size(document, entry)
        if size >= 0:
            decoder.queue_size_update(size)
        var block = _wire(document.text(wire))
        var out = HeaderList()
        decoder.decode(Span(block), 1 << 30, out)
        assert_equal(
            fields_text(out),
            fields_text(_fields(document, entry)),
            path,
        )
        checked += 1
    var encoder = Encoder()
    var mirror = Decoder()
    for entry in cases:
        var size = _table_size(document, entry)
        if size >= 0:
            encoder.update_max_size(size)
            mirror.queue_size_update(size)
        var fields = _fields(document, entry)
        var block = List[UInt8]()
        encoder.encode(fields, block)
        var out = HeaderList()
        mirror.decode(Span(block), 1 << 30, out)
        assert_equal(fields_text(out), fields_text(fields), path)
        checked += 1
    return checked


def _directory(name: StringSlice) raises:
    var directory = _root() + name
    # `make coverage` runs a suite inside its build folder, beside
    # `manifest.txt`. There each line of the library writes a record, and
    # the corpus would take minutes and gigabytes: it is skipped.
    if not exists(directory) or exists("manifest.txt"):
        return
    var names = listdir(directory)
    sort(names)
    var checked = 0
    for file in names:
        if file.startswith("story_") and file.endswith(".json"):
            checked += _story(directory + "/" + file)
    assert_true(checked > 0, String(name))


def test_go_hpack() raises:
    _directory("go-hpack")


def test_haskell_http2_linear() raises:
    _directory("haskell-http2-linear")


def test_haskell_http2_linear_huffman() raises:
    _directory("haskell-http2-linear-huffman")


def test_haskell_http2_naive() raises:
    _directory("haskell-http2-naive")


def test_haskell_http2_naive_huffman() raises:
    _directory("haskell-http2-naive-huffman")


def test_haskell_http2_static() raises:
    _directory("haskell-http2-static")


def test_haskell_http2_static_huffman() raises:
    _directory("haskell-http2-static-huffman")


def test_nghttp2() raises:
    _directory("nghttp2")


def test_nghttp2_16384_4096() raises:
    _directory("nghttp2-16384-4096")


def test_nghttp2_change_table_size() raises:
    _directory("nghttp2-change-table-size")


def test_node_http2_hpack() raises:
    _directory("node-http2-hpack")


def test_python_hpack() raises:
    _directory("python-hpack")


def test_raw_data() raises:
    _directory("raw-data")


struct _Random(Movable):
    """A xorshift64* generator, so each run sees the same inputs."""

    var state: UInt64

    def __init__(out self, seed: UInt64):
        self.state = seed

    def next(mut self) -> UInt64:
        self.state ^= self.state >> 12
        self.state ^= self.state << 25
        self.state ^= self.state >> 27
        return self.state * 0x2545F4914F6CDD1D

    def below(mut self, bound: Int) -> Int:
        return Int(self.next() >> 33) % bound


def _random_text(mut random: _Random, length: Int) -> String:
    var out = String()
    for _ in range(length):
        out += chr(97 + random.below(26))
    return out^


def test_random_round_trip() raises:
    # As fuzz.rs: random fields from a small pool of names and values, a
    # few sensitive, and table size changes between blocks. A sensitive
    # field that is in a table is indexed, as in h2, so the decoded list
    # can lose its flag.
    var random = _Random(0x5EED)
    var names: List[String] = [
        ":method",
        ":path",
        ":authority",
        "content-type",
        "cookie",
        "authorization",
        "x-custom",
        "user-agent",
        "accept-encoding",
    ]
    var values: List[String] = ["GET", "/", "gzip, deflate", ""]
    for _ in range(20):
        values.append(_random_text(random, random.below(40)))
    var encoder = Encoder()
    var decoder = Decoder()
    for _ in range(300):
        if random.below(10) == 0:
            var size = random.below(4097)
            encoder.update_max_size(size)
            decoder.queue_size_update(size)
        var fields = HeaderList()
        for _ in range(random.below(12)):
            var name = names[random.below(len(names))]
            var value = values[random.below(len(values))]
            fields.add_text(name, value, random.below(8) == 0)
        var block = List[UInt8]()
        encoder.encode(fields, block)
        var out = HeaderList()
        decoder.decode(Span(block), 1 << 30, out)
        assert_equal(fields_text(out), fields_text(fields))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
