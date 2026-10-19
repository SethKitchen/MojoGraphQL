# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""JSON numbers: exact reads, and ECMAScript number text.

A JSON number keeps its source text. This module reads that text as an
exact `Int64`, or as the nearest `Float64`, and writes a `Float64` as
ECMAScript `Number.prototype.toString` does, with the `JSON.stringify`
rule for a value that is not finite.
**How a number is read.** `read_float64` rounds the exact decimal value to
the nearest `Float64`, ties to even, as ECMAScript `JSON.parse` does. It
takes the first of three paths that applies:

1. At most 15 significant digits and a power of ten from -22 to 22: the
   fast path of Clinger, one exact `Float64` multiply or divide.
2. At most 19 significant digits: the method of Eisel and Lemire. The
   digits, as a 64-bit integer, multiply the 128 leading bits of the power
   of ten (`gql_json.pow10`). The method gives up when the truncated bits
   could change the result, at an exact halfway point, and for a subnormal
   or an infinite result.
3. Every other number: the digits and the power of ten become big
   integers, and a long division gives 57 bits of the quotient and a
   sticky bit for the rest.

**How a number is written.** `write_number` writes an integer below 2^53
digit by digit. For every other finite value it finds the shortest digits
with the Schubfach method of Giulietti, and the same table of powers of
ten. Of the shortest digit strings that read back as the value, it takes
the one closest to the value, and on a tie the even one, as step 5 of
ECMAScript `Number::toString` requires. Then it lays the digits out by the
ECMAScript rules: plain digits from 1e-6 up to but not including 1e21,
else an exponent, such as `1e+21` or `1.5e-7`.

The tests compare both directions with Node.js for more than 2000 values.

This module has no upstream counterpart. It implements ECMAScript 2025
`Number::toString` (section 6.1.6.1.20), the number step of
`SerializeJSONProperty` (section 25.5.2.3), and RFC 8259 section 6, with
the methods of D. Lemire, "Number Parsing at a Gigabyte per Second"
(2021), and R. Giulietti, "The Schubfach way to render doubles" (2021).

Differences from upstream: none for `Float64` values. `write_int` writes
every `Int64` exactly; ECMAScript has no 64-bit integer type. The
Schubfach method of the paper gives at least two digits; this module
gives the shortest digits, as ECMAScript does (`5e-324`, not `4.9e-324`).
"""

from std.bit import count_leading_zeros
from std.builtin.globals import global_constant
from std.memory import bitcast

from gql_json.pow10 import POW10_MAX, POW10_MIN, POW10_TABLE

comptime MAX_SAFE_INTEGER: Float64 = 9007199254740992.0
"""2^53: below it, every integer is a `Float64` exactly."""
comptime _MAX_DIGITS = 800
"""The significant digits the exact path keeps. A tie between two `Float64`
values needs at most 767, so a sticky digit after 800 rounds correctly."""
comptime _EXACT_POWERS: Array[Float64, 23] = [
    1e0,
    1e1,
    1e2,
    1e3,
    1e4,
    1e5,
    1e6,
    1e7,
    1e8,
    1e9,
    1e10,
    1e11,
    1e12,
    1e13,
    1e14,
    1e15,
    1e16,
    1e17,
    1e18,
    1e19,
    1e20,
    1e21,
    1e22,
]
"""The powers of ten that a `Float64` holds exactly."""
comptime _MASK_63 = (UInt64(1) << 63) - 1
"""The low 63 bits."""


@fieldwise_init
struct IntStatus(Equatable, ImplicitlyCopyable, Writable):
    """The result of reading a JSON number as an exact `Int64`."""

    var value: UInt8
    """The status's index; see `is_valid`."""

    comptime OK = IntStatus(0)
    """The number is an integer that an `Int64` holds."""
    comptime FRACTION = IntStatus(1)
    """The number has a nonzero fraction."""
    comptime OVERFLOW = IntStatus(2)
    """The number is an integer outside the `Int64` range."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the three statuses.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the status name.

        Args:
            writer: The destination.
        """
        if self == IntStatus.OK:
            writer.write("ok")
        elif self == IntStatus.FRACTION:
            writer.write("fraction")
        elif self == IntStatus.OVERFLOW:
            writer.write("overflow")
        else:
            writer.write("<invalid>")


struct _Decimal(Movable):
    """A JSON number split into its digits and its power of ten."""

    var negative: Bool
    """Whether the number has a minus sign."""
    var digits: List[UInt8]
    """The significant digits, 0 to 9, without leading or trailing zeros;
    empty for zero."""
    var exponent: Int
    """The power of ten of the last kept digit."""
    var sticky: Bool
    """Whether nonzero digits after the first `_MAX_DIGITS` were dropped."""
    var lowest: Int
    """The power of ten of the last nonzero digit; 0 for zero."""

    def __init__(out self, text: Span[UInt8, _]):
        """Split valid JSON number text.

        Args:
            text: The number text; it must match the RFC 8259 grammar.
        """
        self.negative = False
        self.digits = List[UInt8]()
        self.sticky = False
        self.exponent = 0
        self.lowest = 0
        var bytes = text.unsafe_ptr()
        var length = len(text)
        var position = 0
        if bytes[unsafe_offset=0] == UInt8(ord("-")):
            self.negative = True
            position = 1
        var in_fraction = False
        var fraction = 0
        # Zeros after the last nonzero digit, kept back until a nonzero
        # digit follows them.
        var pending = 0
        var dropped = 0
        # Digits after the last nonzero one, of all the mantissa digits.
        var after_nonzero = 0
        while position < length:
            var byte = bytes[unsafe_offset=position]
            if byte == UInt8(ord("e")) or byte == UInt8(ord("E")):
                break
            position += 1
            if byte == UInt8(ord(".")):
                in_fraction = True
                continue
            if in_fraction:
                fraction += 1
            after_nonzero += 1
            if byte == UInt8(ord("0")):
                if len(self.digits) > 0:
                    pending += 1
                continue
            after_nonzero = 0
            while pending > 0:
                dropped += self._push(0)
                pending -= 1
            dropped += self._push(byte - UInt8(ord("0")))
        var exponent = 0
        if position < length:
            exponent = _read_exponent(text, position + 1)
        self.exponent = pending + dropped - fraction + exponent
        self.lowest = after_nonzero - fraction + exponent
        if len(self.digits) == 0:
            self.exponent = 0
            self.lowest = 0

    def _push(mut self, digit: UInt8) -> Int:
        """Keep one significant digit, or drop it and note it as sticky.

        Returns:
            1 when the digit was dropped, else 0.
        """
        if len(self.digits) < _MAX_DIGITS:
            self.digits.append(digit)
            return 0
        if digit != 0:
            self.sticky = True
        return 1


def _read_exponent(text: Span[UInt8, _], start: Int) -> Int:
    """Read the signed exponent after an `e`, clamped to +-1e9."""
    var bytes = text.unsafe_ptr()
    var position = start
    var negative = False
    var sign = bytes[unsafe_offset=position]
    if sign == UInt8(ord("-")) or sign == UInt8(ord("+")):
        negative = sign == UInt8(ord("-"))
        position += 1
    var value = 0
    while position < len(text):
        if value < 1_000_000_000:
            value = value * 10 + Int(bytes[unsafe_offset=position] - 48)
        position += 1
    return -value if negative else value


def is_integer_text(text: Span[UInt8, _]) -> Bool:
    """Return True if JSON number text has an integer value.

    `1.0`, `1e2` and `-0` are integers; `1.5` and `1e-1` are not.

    Args:
        text: Valid JSON number text.

    Returns:
        Whether the exact value has no fraction.
    """
    var decimal = _Decimal(text)
    return decimal.lowest >= 0


def read_int64(text: Span[UInt8, _]) -> Tuple[Int64, IntStatus]:
    """Read JSON number text as an exact `Int64`.

    Args:
        text: Valid JSON number text.

    Returns:
        The value and `IntStatus.OK`, or 0 and the reason it has no exact
        `Int64` value.
    """
    var decimal = _Decimal(text)
    if decimal.lowest < 0:
        return (Int64(0), IntStatus.FRACTION)
    if decimal.sticky or len(decimal.digits) + decimal.exponent > 19:
        return (Int64(0), IntStatus.OVERFLOW)
    # At most 19 digits: the magnitude fits a UInt64.
    var magnitude = UInt64(0)
    for digit in decimal.digits:
        magnitude = magnitude * 10 + UInt64(digit)
    var index = 0
    while index < decimal.exponent:
        magnitude *= 10
        index += 1
    var limit = UInt64(9223372036854775807)
    if decimal.negative:
        limit += 1
    if magnitude > limit:
        return (Int64(0), IntStatus.OVERFLOW)
    if decimal.negative:
        return (Int64(0) - Int64(magnitude - 1) - 1, IntStatus.OK)
    return (Int64(magnitude), IntStatus.OK)


def read_float64(text: Span[UInt8, _]) -> Float64:
    """Read JSON number text as the nearest `Float64`, ties to even.

    Args:
        text: Valid JSON number text.

    Returns:
        The value; infinity when it is too large, and a zero with the sign
        of the text when it is too small.
    """
    var bytes = text.unsafe_ptr()
    var length = len(text)
    var negative = bytes[unsafe_offset=0] == UInt8(ord("-"))
    var position = Int(negative)
    # The digits as an integer, the count of significant digits, and the
    # power of ten of the last digit. With more than 19 digits `value`
    # wraps, and the exact path reads the text again.
    var value = UInt64(0)
    var digits = 0
    var power = 0
    var in_fraction = False
    while position < length:
        var byte = bytes[unsafe_offset=position]
        var digit = byte - UInt8(ord("0"))
        if digit < 10:
            value = value * 10 + UInt64(digit)
            # A zero before the first nonzero digit is not significant.
            # `value` can wrap to zero, so the test reads the digits.
            digits += Int(digits > 0 or digit != 0)
            power -= Int(in_fraction)
        elif byte == UInt8(ord(".")):
            in_fraction = True
        else:
            power += _read_exponent(text, position + 1)
            break
        position += 1
    var result: Float64
    if digits > 19:
        var decimal = _Decimal(text)
        result = _exact(decimal)
    elif value == 0:
        result = 0.0
    elif digits <= 15 and power >= -22 and power <= 22:
        ref powers = global_constant[_EXACT_POWERS]()
        var exact = Float64(value)
        if power >= 0:
            result = exact * powers.unsafe_ptr()[unsafe_offset=power]
        else:
            result = exact / powers.unsafe_ptr()[unsafe_offset=-power]
    else:
        var fast = _eisel_lemire(value, power)
        if fast[0]:
            result = fast[1]
        else:
            var decimal = _Decimal(text)
            result = _exact(decimal)
    return -result if negative else result


def _eisel_lemire(value: UInt64, power: Int) -> Tuple[Bool, Float64]:
    """Round `value * 10^power` to a `Float64` with one or two 128-bit
    multiplies.

    `value` is not zero. The result is exact when the first item is True.
    The method gives up (False) when the power is outside the table, when
    the truncated bits of the product could change the result, at an
    exact halfway point, and for a subnormal or an infinite result.
    """
    if power < POW10_MIN or power > POW10_MAX:
        return (False, 0.0)
    ref table = global_constant[POW10_TABLE]()
    var entry = (power - POW10_MIN) * 2
    var high = table.unsafe_ptr()[unsafe_offset=entry]
    var low = table.unsafe_ptr()[unsafe_offset=entry + 1]
    var zeros = count_leading_zeros(value)
    var normal = value << zeros
    # The biased exponent of the result, before the shift to 53 bits.
    var exponent = ((217706 * power) >> 16) + 64 + 1023 - Int(zeros)
    # The product of `normal` and the 128-bit power, to 192 bits; the lowest
    # 64 bits are `below`.
    var product = UInt128(normal) * UInt128(high)
    var lower = UInt128(normal) * UInt128(low)
    product += lower >> 64
    var below = UInt64(lower & UInt128(UInt64.MAX))
    var top = UInt64(product >> 64)
    var middle = UInt64(product & UInt128(UInt64.MAX))
    # The power is rounded down, so the true product can be up to `normal`
    # more in the lowest 64 bits; that can carry into the result bits only
    # when every bit between them is one.
    var unsure = (
        (top & 0x1FF == 0x1FF)
        & (middle == UInt64.MAX)
        & (below > UInt64.MAX - normal)
    )
    var msb = top >> 63
    var mantissa = top >> (msb + 9)
    exponent -= 1 - Int(msb)
    # An exact halfway point needs the rule "ties to even" of the slow path.
    var halfway = (middle == 0) & (top & 0x1FF == 0) & (mantissa & 3 == 1)
    mantissa += mantissa & 1
    mantissa >>= 1
    var carry = mantissa >> 53
    mantissa >>= carry
    exponent += Int(carry)
    var normal_range = (exponent > 0) & (exponent < 0x7FF)
    var bits = (UInt64(exponent) << 52) | (mantissa & ((UInt64(1) << 52) - 1))
    return (
        normal_range & ~unsure & ~halfway,
        bitcast[DType.float64](bits),
    )


def _exact(decimal: _Decimal) -> Float64:
    """Round a decimal to a `Float64` with big integer arithmetic."""
    var count = len(decimal.digits)
    var exponent = decimal.exponent
    if count + exponent < -330:
        return 0.0
    if count + exponent > 310:
        return Float64.MAX * 2.0
    var numerator = _BigInt.from_digits(decimal.digits, decimal.sticky)
    if decimal.sticky:
        exponent -= 1
    var denominator = _BigInt.of(1)
    if exponent >= 0:
        numerator.mul_pow10(exponent)
    else:
        denominator.mul_pow10(-exponent)
    # Scale so that the quotient has 56 or 57 bits.
    var shift = 56 - (numerator.bit_length() - denominator.bit_length())
    if shift >= 0:
        numerator.shift_left(shift)
    else:
        denominator.shift_left(-shift)
    # Scale both so that the top limb of the denominator is full. Then its
    # top 64 bits divide the top bits of the numerator, and the estimate
    # is the quotient or up to two more.
    var align = (32 - denominator.bit_length() % 32) % 32
    numerator.shift_left(align)
    denominator.shift_left(align)
    var start = max(len(denominator.limbs) - 2, 0)
    var estimate = numerator.top(start) // denominator.top(start)
    var quotient = UInt64(estimate) + 1
    # The remainder, in two's complement over one more limb than the
    # numerator: the product is below three times the numerator.
    var size = len(numerator.limbs) + 1
    var remainder = numerator.limbs.copy()
    remainder.resize(size, 0)
    var product = denominator.times(quotient).limbs.copy()
    product.resize(size, 0)
    var divisor = denominator.limbs.copy()
    divisor.resize(size, 0)
    var negative = _subtract_into(remainder, product)
    while negative:
        quotient -= 1
        # A carry out of the top limb means the remainder is not negative.
        negative = not _add_into(remainder, divisor)
    return _round(quotient, shift, _any_nonzero(remainder))


def _round(quotient: UInt64, scale: Int, sticky: Bool) -> Float64:
    """Round `quotient * 2^-scale` (plus a sticky bit) to a `Float64`."""
    var bits = 64 - Int(count_leading_zeros(quotient))
    # The unbiased exponent of the leading bit.
    var exponent = bits - 1 - scale
    var drop = bits - 53
    if exponent < -1022:
        drop += -1022 - exponent
        exponent = -1022
    if drop > bits:
        # Below half of the smallest subnormal.
        return 0.0
    var mantissa = quotient >> UInt64(drop)
    var rest = quotient - (mantissa << UInt64(drop))
    var half = (UInt64(1) << UInt64(drop)) >> 1
    if rest > half or (rest == half and (sticky or mantissa & 1 == 1)):
        mantissa += 1
    # Rounding can carry into a new leading bit.
    if mantissa == UInt64(1) << 53:
        mantissa >>= 1
        exponent += 1
    if exponent > 1023:
        return Float64.MAX * 2.0
    if mantissa < UInt64(1) << 52:
        return bitcast[DType.float64](mantissa)
    var field = UInt64(exponent + 1023) << 52
    return bitcast[DType.float64](field | (mantissa - (UInt64(1) << 52)))


struct _BigInt(Copyable, Movable):
    """A nonnegative big integer: 32-bit limbs, least significant first."""

    var limbs: List[UInt32]
    """The limbs; no zero limb at the top."""

    def __init__(out self, var limbs: List[UInt32]):
        """Wrap limbs.

        Args:
            limbs: The limbs, least significant first.
        """
        self.limbs = limbs^

    @staticmethod
    def of(value: UInt32) -> _BigInt:
        """Return a one-limb number.

        Args:
            value: A nonzero value.

        Returns:
            The number.
        """
        return _BigInt([value])

    @staticmethod
    def from_digits(digits: List[UInt8], sticky: Bool) -> _BigInt:
        """Return the integer that decimal digits spell.

        Args:
            digits: Digits 0 to 9, most significant first.
            sticky: Whether to append one more digit, a 1.

        Returns:
            The number.
        """
        var out = _BigInt(List[UInt32]())
        var chunk = UInt32(0)
        var scale = UInt32(1)
        var index = 0
        while index < len(digits):
            chunk = chunk * 10 + UInt32(digits[index])
            scale *= 10
            index += 1
            if scale == 1_000_000_000:
                out.mul_add(scale, chunk)
                chunk = 0
                scale = 1
        if sticky:
            chunk = chunk * 10 + 1
            scale *= 10
        if scale > 1:
            out.mul_add(scale, chunk)
        return out^

    def mul_add(mut self, factor: UInt32, addend: UInt32):
        """Set the number to `self * factor + addend`.

        Args:
            factor: The multiplier, at most 1e9.
            addend: The value to add.
        """
        var carry = UInt64(addend)
        var index = 0
        while index < len(self.limbs):
            var product = UInt64(self.limbs[index]) * UInt64(factor) + carry
            self.limbs[index] = UInt32(product & 0xFFFFFFFF)
            carry = product >> 32
            index += 1
        if carry > 0:
            self.limbs.append(UInt32(carry))

    def mul_pow10(mut self, power: Int):
        """Multiply by a power of ten.

        Args:
            power: The power, zero or more.
        """
        var rest = power
        while rest >= 9:
            self.mul_add(1_000_000_000, 0)
            rest -= 9
        if rest > 0:
            var factor = UInt32(1)
            while rest > 0:
                factor *= 10
                rest -= 1
            self.mul_add(factor, 0)

    def bit_length(self) -> Int:
        """Return the number of bits, without leading zeros.

        Returns:
            The bit length; the number is not zero.
        """
        var top = UInt64(self.limbs[len(self.limbs) - 1]) << 32
        return len(self.limbs) * 32 - Int(count_leading_zeros(top))

    def shift_left(mut self, bits: Int):
        """Multiply by a power of two.

        Args:
            bits: The power, zero or more.
        """
        var whole = bits // 32
        var part = UInt64(bits % 32)
        var out = List[UInt32](capacity=len(self.limbs) + whole + 1)
        out.resize(whole, 0)
        var carry = UInt64(0)
        var index = 0
        while index < len(self.limbs):
            var wide = (UInt64(self.limbs[index]) << part) | carry
            out.append(UInt32(wide & 0xFFFFFFFF))
            carry = wide >> 32
            index += 1
        if carry > 0:
            out.append(UInt32(carry))
        self.limbs = out^

    def top(self, start: Int) -> UInt128:
        """Return the number without its limbs below a position.

        Args:
            start: The first limb to keep; at most four limbs are above it.

        Returns:
            The number divided by 2^(32 * start), rounded down.
        """
        var result = UInt128(0)
        var index = len(self.limbs) - 1
        while index >= start:
            result = (result << 32) | UInt128(self.limbs[index])
            index -= 1
        return result

    def times(self, factor: UInt64) -> _BigInt:
        """Return the product with a 64-bit number.

        Args:
            factor: A nonzero multiplier.

        Returns:
            The product.
        """
        var out = List[UInt32](capacity=len(self.limbs) + 2)
        var carry = UInt128(0)
        var index = 0
        while index < len(self.limbs):
            var product = UInt128(self.limbs[index]) * UInt128(factor) + carry
            out.append(UInt32(product & 0xFFFFFFFF))
            carry = product >> 32
            index += 1
        while carry > 0:
            out.append(UInt32(carry & 0xFFFFFFFF))
            carry >>= 32
        return _BigInt(out^)


def _subtract_into(mut limbs: List[UInt32], other: List[UInt32]) -> Bool:
    """Subtract a number of the same length, modulo 2^(32 * length).

    Returns:
        True when `other` was larger: the result is negative, in two's
        complement.
    """
    var borrow = Int64(0)
    var index = 0
    while index < len(limbs):
        var difference = Int64(limbs[index]) - Int64(other[index]) - borrow
        borrow = Int64(difference < 0)
        limbs[index] = UInt32(difference + (borrow << 32))
        index += 1
    return borrow != 0


def _add_into(mut limbs: List[UInt32], other: List[UInt32]) -> Bool:
    """Add a number of the same length, modulo 2^(32 * length).

    Returns:
        True when the sum carried out of the top limb.
    """
    var carry = UInt64(0)
    var index = 0
    while index < len(limbs):
        var sum = UInt64(limbs[index]) + UInt64(other[index]) + carry
        limbs[index] = UInt32(sum & 0xFFFFFFFF)
        carry = sum >> 32
        index += 1
    return carry != 0


def _any_nonzero(limbs: List[UInt32]) -> Bool:
    """Return True if a limb is not zero."""
    var found = UInt32(0)
    var index = 0
    while index < len(limbs):
        found |= limbs[index]
        index += 1
    return found != 0


def write_int(mut out: List[UInt8], value: Int64):
    """Append the decimal text of an integer.

    Args:
        out: The destination.
        value: The integer.
    """
    var magnitude = UInt64(value)
    if value < 0:
        out.append(UInt8(ord("-")))
        magnitude = UInt64(0) - magnitude
    _write_unsigned(out, magnitude)


def _write_unsigned(mut out: List[UInt8], value: UInt64):
    """Append the decimal digits of an unsigned integer."""
    var buffer = Array[UInt8, 20](fill=0)
    var position = 20
    var rest = value
    while True:
        position -= 1
        buffer[position] = UInt8(rest % 10) + UInt8(ord("0"))
        rest //= 10
        if rest == 0:
            break
    while position < 20:
        out.append(buffer[position])
        position += 1


def write_number(mut out: List[UInt8], value: Float64):
    """Append a number as ECMAScript `JSON.stringify` writes it.

    NaN and the infinities give `null`, and -0 gives `0`.

    Args:
        out: The destination.
        value: The number.
    """
    if value - value != 0.0:
        # NaN, or an infinity: inf - inf is NaN, and NaN is not 0.
        out.extend("null".as_bytes())
        return
    if value > -MAX_SAFE_INTEGER and value < MAX_SAFE_INTEGER:
        var whole = Int64(value)
        if Float64(whole) == value:
            write_int(out, whole)
            return
    var magnitude = value
    if value < 0.0:
        out.append(UInt8(ord("-")))
        magnitude = -value
    var digits = _shortest(magnitude)
    _layout(out, digits)


struct _Shortest(Movable):
    """The shortest digits of a `Float64`: `0.d1d2... * 10^point`."""

    var digits: Array[UInt8, 24]
    """The ASCII digits; the last one is not `0`."""
    var count: Int
    """How many digits are used."""
    var point: Int
    """The power of ten after the first digit's position."""

    def __init__(out self):
        """Start with no digits."""
        self.digits = Array[UInt8, 24](fill=0)
        self.count = 0
        self.point = 0


def _shortest(value: Float64) -> _Shortest:
    """Return the shortest, closest digits that read back as a positive
    finite `Float64`, with the Schubfach method.

    The value is c * 2^q. Its rounding interval R is the set of reals that
    round to it: half a gap on each side, or a quarter gap below a power of
    two, with the ends in R when c is even. k is the power of ten with
    10^k at most the gap. In units of 10^k and with two more bits, `vb`,
    `vbl` and `vbr` are the value and the ends of R, rounded to odd: that
    keeps a sticky bit, so every comparison below is exact. A multiple of
    10^(k+1) in R is the shortest form when there is one; else one of s
    and s + 1, the units of 10^k on each side of the value, is in R, and
    when both are, the closer one wins, ties to the even one.
    """
    var bits = bitcast[DType.uint64](value)
    var field = Int(bits >> 52)
    var c = bits & ((UInt64(1) << 52) - 1)
    var q = -1074
    if field > 0:
        c |= UInt64(1) << 52
        q = field - 1075
    var odd = c & 1
    var cb = c << 2
    var cbr = cb + 2
    var cbl: UInt64
    var k: Int
    if c != UInt64(1) << 52 or q == -1074:
        cbl = cb - 2
        # floor(q * log10(2))
        k = (q * 661_971_961_083) >> 41
    else:
        cbl = cb - 1
        # floor(q * log10(2) + log10(3/4))
        k = (q * 661_971_961_083 - 274_743_187_321) >> 41
    # floor(-k * log2(10)), plus the two scale bits.
    var h = q + ((-k * 913_124_641_741) >> 38) + 2
    # 10^-k, rounded up, in 126 bits: two 63-bit halves.
    ref table = global_constant[POW10_TABLE]()
    var entry = (-k - POW10_MIN) * 2
    var power = (UInt128(table.unsafe_ptr()[unsafe_offset=entry]) << 64) | (
        UInt128(table.unsafe_ptr()[unsafe_offset=entry + 1])
    )
    power = (power >> 2) + 1
    var g1 = UInt64(power >> 63)
    var g0 = UInt64(power & UInt128(_MASK_63))
    var vb = _round_odd(g1, g0, cb << UInt64(h))
    var vbl = _round_odd(g1, g0, cbl << UInt64(h))
    var vbr = _round_odd(g1, g0, cbr << UInt64(h))
    var s = vb >> 2
    if s >= 10:
        var sp10 = (s // 10) * 10
        var tp10 = sp10 + 10
        var upin = vbl + odd <= sp10 << 2
        var wpin = (tp10 << 2) + odd <= vbr
        if upin != wpin:
            return _decimal(sp10 if upin else tp10, k)
    var t = s + 1
    var uin = vbl + odd <= s << 2
    var win = (t << 2) + odd <= vbr
    if uin != win:
        return _decimal(s if uin else t, k)
    var middle = (s + t) << 1
    if vb < middle or (vb == middle and s & 1 == 0):
        return _decimal(s, k)
    return _decimal(t, k)


@always_inline
def _round_odd(g1: UInt64, g0: UInt64, scaled: UInt64) -> UInt64:
    """Return `(g1 * 2^63 + g0) * scaled / 2^128`, rounded to odd."""
    var x1 = UInt64((UInt128(g0) * UInt128(scaled)) >> 64)
    var y = UInt128(g1) * UInt128(scaled)
    var z = (UInt64(y & UInt128(UInt64.MAX)) >> 1) + x1
    var result = UInt64(y >> 64) + (z >> 63)
    return result | (((z & _MASK_63) + _MASK_63) >> 63)


def _decimal(significand: UInt64, exponent: Int) -> _Shortest:
    """Return the digits of `significand * 10^exponent`, trailing zeros
    removed; the significand is not zero."""
    var rest = significand
    var power = exponent
    while rest % 10 == 0:
        rest //= 10
        power += 1
    var out = _Shortest()
    var buffer = Array[UInt8, 24](fill=0)
    var position = 24
    while rest > 0:
        position -= 1
        buffer[position] = UInt8(rest % 10) + 48
        rest //= 10
    out.count = 24 - position
    var index = 0
    while index < out.count:
        out.digits[index] = buffer[position + index]
        index += 1
    out.point = out.count + power
    return out^


def _layout(mut out: List[UInt8], number: _Shortest):
    """Lay out digits by the rules of ECMAScript `Number::toString`."""
    var count = number.count
    var point = number.point
    if count <= point and point <= 21:
        _put(out, number.digits, 0, count)
        _zeros(out, point - count)
    elif 0 < point and point <= 21:
        _put(out, number.digits, 0, point)
        out.append(UInt8(ord(".")))
        _put(out, number.digits, point, count)
    elif -6 < point and point <= 0:
        out.append(UInt8(ord("0")))
        out.append(UInt8(ord(".")))
        _zeros(out, -point)
        _put(out, number.digits, 0, count)
    else:
        out.append(number.digits[0])
        if count > 1:
            out.append(UInt8(ord(".")))
            _put(out, number.digits, 1, count)
        out.append(UInt8(ord("e")))
        var exponent = point - 1
        if exponent < 0:
            out.append(UInt8(ord("-")))
            exponent = -exponent
        else:
            out.append(UInt8(ord("+")))
        _write_unsigned(out, UInt64(exponent))


def _put(mut out: List[UInt8], digits: Array[UInt8, 24], start: Int, end: Int):
    """Append a range of digits."""
    var index = start
    while index < end:
        out.append(digits[index])
        index += 1


def _zeros(mut out: List[UInt8], count: Int):
    """Append zeros."""
    var index = 0
    while index < count:
        out.append(UInt8(ord("0")))
        index += 1
