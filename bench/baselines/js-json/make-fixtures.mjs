// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// Write the Node.js reference outputs of the gql_json tests, once:
//
//     node bench/baselines/js-json/make-fixtures.mjs tests/gql_json/fixtures
//
// 1. roundtrip/strings.json and roundtrip/nesting.json: the escape-heavy
//    inputs. B is a backslash, so this source holds no escape that a tool
//    could rewrite.
// 2. expected/<name> and expected-pretty/<name>: JSON.stringify(JSON.parse(x))
//    and JSON.stringify(JSON.parse(x), null, 2) for every y_ file of the
//    JSONTestSuite and every roundtrip/ file.
// 3. numbers.txt: "<hex bits> <JSON.stringify(x)>" for edge cases and a
//    seeded random sample of Float64 values.
//
// The outputs are committed; the tests do not run Node.js.

import { mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';

const root = process.argv[2];
if (!root) throw new Error('usage: node make-fixtures.mjs <fixture dir>');

// 1. The escape-heavy inputs.
const B = String.fromCharCode(92);
const u = (hex) => B + 'u' + hex;
const strings = '["' + u('0041') + B + '/' + B + 'b' + B + 'f' + B + 'n' + B + 'r' + B + 't' + B + '"' + B + B + '", "'
  + u('001f') + u('0000') + u('007f') + u('2028') + u('2029') + u('0008') + u('000c') + u('000a') + u('000d') + u('0009') + '", "'
  + u('D83D') + u('DE00') + ' ' + u('d834') + u('dd1e') + '", "caf' + u('00e9') + ' caf' + u('00C9') + ' ' + u('0800') + ' ' + u('FFFF') + '", '
  + '"plain", "", "' + u('0022') + u('005c') + u('002F') + '", "tab' + B + 'there", "'
  + String.fromCodePoint(0xfc, 0x6e, 0xef, 0x63, 0xf6, 0x64, 0xe9, 0x20, 0x2713, 0x20, 0x65e5, 0x672c, 0x8a9e, 0x20, 0x1f389) + '", "'
  + String.fromCodePoint(0x7f, 0x2028, 0x2029, 0x10ffff) + '"]\n';
writeFileSync(root + '/roundtrip/strings.json', strings);
const nesting = '{"a":{},"b":[],"c":[{}],"d":[[]],"e":{"f":{"g":[1,[2,[3]]]}},"":"empty key","h' + u('0069')
  + '":"escaped key","' + B + 'n":1,"' + B + '"q' + B + '"":{"' + u('00e9') + '":[null]}}\n';
writeFileSync(root + '/roundtrip/nesting.json', nesting);

// 2. The round-trip outputs.
mkdirSync(root + '/expected', { recursive: true });
mkdirSync(root + '/expected-pretty', { recursive: true });
const sources = [
  ...readdirSync(root + '/test_parsing').filter((n) => n.startsWith('y_')).map((n) => 'test_parsing/' + n),
  ...readdirSync(root + '/roundtrip').map((n) => 'roundtrip/' + n),
];
for (const path of sources) {
  const name = path.split('/')[1];
  const text = new TextDecoder('utf-8', { fatal: true }).decode(readFileSync(root + '/' + path));
  const value = JSON.parse(text);
  writeFileSync(root + '/expected/' + name, JSON.stringify(value));
  writeFileSync(root + '/expected-pretty/' + name, JSON.stringify(value, null, 2));
}

// 3. The number sample.
let seed = 0x12345678n;
function next() {
  seed = (seed * 6364136223846793005n + 1442695040888963407n) & ((1n << 64n) - 1n);
  return seed;
}
const buffer = new DataView(new ArrayBuffer(8));
const lines = [];
function add(x) {
  buffer.setFloat64(0, x);
  const hex = buffer.getBigUint64(0).toString(16).padStart(16, '0');
  lines.push(`${hex} ${JSON.stringify(x)}`);
}
const edge = [0, -0, 1, -1, 0.1, 0.2, 0.3, 1 / 3, 2 / 3, 1e21, 1e20, 999999999999999900000, 1e-6, 1e-7, 1.5e-7, 0.000001,
  0.0000012345, 123456789012345680000, 5e-324, -5e-324, 1.7976931348623157e308, 2.2250738585072014e-308,
  2.225073858507201e-308, 9007199254740991, 9007199254740992, 9007199254740993, -9007199254740992, 1e15, 1e16, 1e17,
  123.456, 100, 1e300, 1.5, 2.5e-5, 4.35, 0.5, 1e-5, 1e-323, 4.9406564584124654e-324, 2 ** 63, 2 ** 64, -(2 ** 63),
  1234567890123456789, NaN, Infinity, -Infinity, 1e22, 1e23, 5e-7, 12e-7];
for (const x of edge) add(x);
for (let i = 0; i < 1000; i++) {
  buffer.setBigUint64(0, next());
  add(buffer.getFloat64(0));
}
for (let i = 0; i < 500; i++) {
  const r = Number(next() >> 11n) / 2 ** 53;
  const e = Number(next() % 60n) - 30;
  add(r * 10 ** e);
  add(Math.round(r * 10 ** Number(next() % 22n)));
}
writeFileSync(root + '/numbers.txt', lines.join('\n') + '\n');
console.log(sources.length, 'round trips,', lines.length, 'numbers');
