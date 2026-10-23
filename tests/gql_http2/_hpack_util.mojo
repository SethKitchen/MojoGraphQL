# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers for the HPACK tests: hex blocks, and fields as text."""

from gql_http2.hpack import Decoder, HeaderList, HpackError
from gql_http2.hpack_table import DynamicTable
from gql_http2.huffman import huffman_decode


def hex_bytes(text: StringSlice) raises -> List[UInt8]:
    """Return the bytes of a hex string; spaces are skipped.

    Args:
        text: Pairs of hex digits.

    Returns:
        The bytes.

    Raises:
        Error: On a character that is not a hex digit or a space.
    """
    var out = List[UInt8]()
    var high = -1
    for byte in text.as_bytes():
        var digit: Int
        if byte >= 48 and byte <= 57:
            digit = Int(byte) - 48
        elif byte >= 97 and byte <= 102:
            digit = Int(byte) - 87
        elif byte >= 65 and byte <= 70:
            digit = Int(byte) - 55
        elif byte == 32:
            continue
        else:
            raise Error("not a hex digit")
        if high < 0:
            high = digit
        else:
            out.append(UInt8(high * 16 + digit))
            high = -1
    return out^


def fields_text(fields: HeaderList) -> String:
    """Return the fields as `name: value` lines.

    Args:
        fields: The list.

    Returns:
        One line for each field.
    """
    var out = String()
    for index in range(fields.count()):
        out += String(fields.name_text(index), ": ", fields.value_text(index))
        out += "\n"
    return out^


def table_text(table: DynamicTable) -> String:
    """Return the entries of a table as `name: value` lines, newest first,
    then the size.

    Args:
        table: The table.

    Returns:
        The lines.
    """
    var out = String()
    for index in range(table.count()):
        out += String(
            StringSlice(unsafe_from_utf8=table.name(index)),
            ": ",
            StringSlice(unsafe_from_utf8=table.value(index)),
            "\n",
        )
    out += String("size ", table.size())
    return out^


def decode_block(
    mut decoder: Decoder, block: List[UInt8], max_list_size: Int = 1 << 20
) raises -> HeaderList:
    """Decode a block into a new list.

    Args:
        decoder: The decoder.
        block: The block.
        max_list_size: The list size limit.

    Returns:
        The fields.

    Raises:
        HpackError: If the block is not valid.
    """
    var out = HeaderList()
    decoder.decode(Span(block), max_list_size, out)
    return out^


def decode_error(mut decoder: Decoder, block: List[UInt8]) raises -> HpackError:
    """Decode a block that must fail, and return the error.

    Args:
        decoder: The decoder.
        block: The block.

    Returns:
        The error.

    Raises:
        Error: If the block decodes.
    """
    var out = HeaderList()
    try:
        decoder.decode(Span(block), 1 << 20, out)
    except e:
        return e^
    raise Error("expected an HPACK error")


def huff_text(data: Span[UInt8, _]) raises -> String:
    """Return the text of a Huffman string.

    Args:
        data: The code.

    Returns:
        The text.

    Raises:
        Error: If the code is not valid.
    """
    var out = List[UInt8]()
    if not huffman_decode(data, out):
        raise Error("invalid Huffman code")
    return String(unsafe_from_utf8=out)
