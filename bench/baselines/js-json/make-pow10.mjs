// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// Write gql_json/pow10.mojo, the table of 128-bit powers of ten, once:
//
//     node bench/baselines/js-json/make-pow10.mjs > gql_json/pow10.mojo
//
// For each q from -348 to 347 the entry is floor(10^q * 2^-e), for the e
// that puts the result in [2^127, 2^128): the 128 leading bits of 10^q,
// rounded down. The table holds the high 64 bits, then the low 64 bits.

const MIN = -348;
const MAX = 347;
const bitLength = (x) => x.toString(2).length;
const hex = (x) => '0x' + x.toString(16).toUpperCase().padStart(16, '0');
const mask = (1n << 64n) - 1n;

const lines = [];
for (let q = MIN; q <= MAX; q++) {
  let value;
  if (q >= 0) {
    const x = 10n ** BigInt(q);
    const shift = bitLength(x) - 128;
    value = shift >= 0 ? x >> BigInt(shift) : x << BigInt(-shift);
  } else {
    const d = 10n ** BigInt(-q);
    value = (1n << BigInt(bitLength(d) + 127)) / d;
  }
  if (bitLength(value) !== 128) throw new Error('not normalized: ' + q);
  lines.push(`    ${hex(value >> 64n)},\n    ${hex(value & mask)},  # 1e${q}`);
}

process.stdout.write(`# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The 128 leading bits of each power of ten from 1e${MIN} to 1e${MAX}.

Entry q is floor(10^q * 2^-e), for the e that puts it in [2^127, 2^128):
the leading bits of 10^q, rounded down. \`gql_json.number\` reads numbers
with it (the Eisel-Lemire method) and writes them with it (the Schubfach
method). \`bench/baselines/js-json/make-pow10.mjs\` wrote this file.

This module has no upstream counterpart: the values are facts of
arithmetic. Go \`strconv\` and fast_float hold the same table.

Differences from upstream: none.
"""

comptime POW10_MIN = ${MIN}
"""The power of ten of the first entry."""
comptime POW10_MAX = ${MAX}
"""The power of ten of the last entry."""
comptime POW10_TABLE: Array[UInt64, ${2 * (MAX - MIN + 1)}] = [
${lines.join('\n')}
]
"""For each power from \`POW10_MIN\`, its high 64 bits, then its low 64 bits."""
`);
