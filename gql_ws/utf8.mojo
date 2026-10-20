# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An incremental UTF-8 validator, for text messages that come in
fragments (RFC 6455 section 8.1).

The validator checks the bytes of each fragment as they arrive, so a
connection fails at the first invalid byte and not at the end of the
message. A sequence can span two fragments. ASCII runs are checked 32
bytes at a time.

This module ports the role of tungstenite 0.30.0 `src/utf8.rs`
(`decode`, `Incomplete::try_complete`) and of `StringCollector` in
`src/protocol/message.rs`. The byte ranges are those of the Unicode
Standard, table 3-7.

Differences from upstream: the validator keeps a state of two counters and
does not copy the bytes into a string; the caller keeps them.
"""

comptime _WIDTH = 32
"""The bytes of one ASCII check."""


struct Utf8Validator(ImplicitlyCopyable, Movable):
    """The state of a UTF-8 check across fragments."""

    var need: Int
    """The continuation bytes that the current sequence still needs."""
    var low: UInt8
    """The smallest value of the next continuation byte."""
    var high: UInt8
    """The largest value of the next continuation byte."""

    def __init__(out self):
        """Make a validator at the start of a text."""
        self.need = 0
        self.low = 0x80
        self.high = 0xBF

    def reset(mut self):
        """Start a new text."""
        self.need = 0
        self.low = 0x80
        self.high = 0xBF

    def is_complete(self) -> Bool:
        """Return True when no sequence is open.

        Returns:
            Whether the bytes so far are a whole UTF-8 text.
        """
        return self.need == 0

    def feed(mut self, data: Pointer[UInt8, _], start: Int, end: Int) -> Bool:
        """Check more bytes of the text.

        Args:
            data: The buffer.
            start: The offset of the first byte.
            end: The offset after the last byte.

        Returns:
            False at the first byte that cannot be UTF-8.
        """
        var index = start
        while index < end:
            if self.need == 0:
                if index + _WIDTH <= end:
                    var chunk = data.unsafe_offset(index).unsafe_load[
                        width=_WIDTH
                    ]()
                    if (chunk & 0x80).reduce_or() == 0:
                        index += _WIDTH
                        continue
                var lead = data[unsafe_offset=index]
                index += 1
                if lead < 0x80:
                    continue
                if not self._start(lead):
                    return False
                continue
            var byte = data[unsafe_offset=index]
            if byte < self.low or byte > self.high:
                return False
            self.need -= 1
            self.low = 0x80
            self.high = 0xBF
            index += 1
        return True

    def _start(mut self, lead: UInt8) -> Bool:
        """Open a sequence with a lead byte; False for an invalid lead."""
        if lead < 0xC2:
            return False
        if lead < 0xE0:
            self.need = 1
            return True
        if lead < 0xF0:
            self.need = 2
            if lead == 0xE0:
                self.low = 0xA0
            elif lead == 0xED:
                self.high = 0x9F
            return True
        if lead > 0xF4:
            return False
        self.need = 3
        if lead == 0xF0:
            self.low = 0x90
        elif lead == 0xF4:
            self.high = 0x8F
        return True


def is_utf8(data: Span[UInt8, _]) -> Bool:
    """Return True for bytes that are a whole UTF-8 text.

    Args:
        data: The bytes.

    Returns:
        Whether the bytes are valid and end no sequence early.
    """
    var validator = Utf8Validator()
    if not validator.feed(data.unsafe_ptr(), 0, len(data)):
        return False
    return validator.is_complete()
