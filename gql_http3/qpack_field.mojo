# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""A list of header fields, as the QPACK coder reads and writes them.

`FieldList` keeps every name and value in one byte buffer, one after the
other, and the end offset of each. So adding a field copies its bytes once
and allocates nothing when the buffer has room, and `clear` keeps the
buffer for the next field section.

The size of a field is the length of its name, plus the length of its
value, plus 32 (RFC 9204 section 3.2.1). The field section size limit and
the dynamic table use it.

This module ports `h3/src/qpack/field.rs` of hyperium/h3 h3-v0.0.8
(22c1aa3), MIT.

Differences from upstream: upstream has one `HeaderField` value of two
`Cow` byte strings for each field. Here a list holds all of them in one
buffer, and `name` and `value` return spans into it.
"""

comptime ENTRY_OVERHEAD = 32
"""The bytes that RFC 9204 section 3.2.1 adds to the size of each field."""


@always_inline
def field_size(name_length: Int, value_length: Int) -> Int:
    """Return the size of a field: its name, its value and 32.

    Args:
        name_length: The length of the name in bytes.
        value_length: The length of the value in bytes.

    Returns:
        The size.
    """
    return name_length + value_length + ENTRY_OVERHEAD


struct FieldList(Copyable, Movable, Sized, Writable):
    """Header fields in order: names and values in one byte buffer."""

    var data: List[UInt8]
    """The name and the value of each field, one after the other."""
    var _ends: List[Int]
    """For each field, the end of its name, then the end of its value."""

    def __init__(out self, capacity: Int = 0):
        """Make an empty list.

        Args:
            capacity: The number of bytes to reserve for names and values.
        """
        self.data = List[UInt8](capacity=capacity)
        self._ends = List[Int]()

    def __len__(self) -> Int:
        """Return the number of fields.

        Returns:
            The count.
        """
        return len(self._ends) >> 1

    def count(self) -> Int:
        """Return the number of fields.

        Returns:
            The count.
        """
        return len(self._ends) >> 1

    def clear(mut self):
        """Remove every field, and keep the buffers."""
        self.data.clear()
        self._ends.clear()

    def add(mut self, name: Span[UInt8, _], value: Span[UInt8, _]):
        """Add a field at the end.

        Args:
            name: The name. HTTP/3 field names are lowercase; the list does
                not check it.
            value: The value.
        """
        self.data.extend(name)
        self._ends.append(len(self.data))
        self.data.extend(value)
        self._ends.append(len(self.data))

    def add_text(mut self, name: StringSlice, value: StringSlice):
        """Add a field from text.

        Args:
            name: The name, in lowercase.
            value: The value.
        """
        self.add(name.as_bytes(), value.as_bytes())

    @always_inline
    def _end_name(mut self):
        """Mark the end of a name that was appended to `data`."""
        self._ends.append(len(self.data))

    @always_inline
    def _end_value(mut self):
        """Mark the end of a value that was appended to `data`."""
        self._ends.append(len(self.data))

    @always_inline
    def _start(self, index: Int) -> Int:
        """Return the offset of the name of a field."""
        if index == 0:
            return 0
        return self._ends[index * 2 - 1]

    def name(self, index: Int) -> Span[UInt8, origin_of(self.data)]:
        """Return the name of a field.

        Args:
            index: The index, from 0 to `count() - 1`.

        Returns:
            The bytes of the name.
        """
        return Span(self.data)[self._start(index) : self._ends[index * 2]]

    def value(self, index: Int) -> Span[UInt8, origin_of(self.data)]:
        """Return the value of a field.

        Args:
            index: The index, from 0 to `count() - 1`.

        Returns:
            The bytes of the value.
        """
        return Span(self.data)[self._ends[index * 2] : self._ends[index * 2 + 1]]

    def name_text(self, index: Int) -> StringSlice[origin_of(self.data)]:
        """Return the name of a field as text.

        Args:
            index: The index, from 0 to `count() - 1`.

        Returns:
            The name. The bytes are not checked for UTF-8.
        """
        return StringSlice(unsafe_from_utf8=self.name(index))

    def value_text(self, index: Int) -> StringSlice[origin_of(self.data)]:
        """Return the value of a field as text.

        Args:
            index: The index, from 0 to `count() - 1`.

        Returns:
            The value. The bytes are not checked for UTF-8.
        """
        return StringSlice(unsafe_from_utf8=self.value(index))

    def size(self) -> Int:
        """Return the field section size: the sum of the field sizes.

        Returns:
            The bytes of all names and values, plus 32 for each field.
        """
        return len(self.data) + self.count() * ENTRY_OVERHEAD

    def find(self, name: StringSlice) -> Int:
        """Return the index of the first field with a name.

        Args:
            name: The name, compared byte for byte.

        Returns:
            The index, or -1.
        """
        var index = 0
        while index < self.count():
            if self.name_text(index) == name:
                return index
            index += 1
        return -1

    def write_to(self, mut writer: Some[Writer]):
        """Write each field as `name: value`, one per line.

        Args:
            writer: The destination.
        """
        var index = 0
        while index < self.count():
            writer.write(self.name_text(index), ": ", self.value_text(index))
            writer.write("\n")
            index += 1
