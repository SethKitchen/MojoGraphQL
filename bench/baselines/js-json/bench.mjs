// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// The Node.js JSON.parse and JSON.stringify baseline: what Apollo Server and
// graphql-js responses go through. It prints `BENCH <workload> <ns per op>`
// lines with the same method as bench/gql_json/json.mojo: warm up, then
// rounds of at least ROUND_NS each, and report the fastest round.
//
// It needs no package: JSON is built into V8.

import { readFileSync } from 'node:fs';

const FIXTURES = new URL('../../fixtures/', import.meta.url);
const ROUND_NS = 1_000_000_000n;
const ROUNDS = 5;
const WARMUP_NS = 200_000_000n;

let sink = 0;

function run(work, input, iterations) {
  const start = process.hrtime.bigint();
  for (let i = 0; i < iterations; i++) {
    sink += work(input);
  }
  return process.hrtime.bigint() - start;
}

function measure(name, work, input) {
  let iterations = 1;
  let warm = 0n;
  for (;;) {
    const elapsed = run(work, input, iterations);
    warm += elapsed;
    if (elapsed * 4n >= WARMUP_NS || warm >= WARMUP_NS) {
      let perOp = elapsed / BigInt(iterations);
      if (perOp < 1n) perOp = 1n;
      iterations = Number(ROUND_NS / perOp) || 1;
      break;
    }
    iterations *= 2;
  }
  let best = Infinity;
  for (let round = 0; round < ROUNDS; round++) {
    const elapsed = Number(run(work, input, iterations));
    best = Math.min(best, elapsed / iterations);
  }
  console.log(`BENCH ${name} ${best.toFixed(1)}`);
}

const fixture = (name) => readFileSync(new URL(name, FIXTURES), 'utf8');
const introspection = fixture('github-schema.json');
const smallResponse = fixture('small-response.json');
const variables = fixture('variables.json');

// A parse returns the number of top level keys, so the work is used.
const parseOnce = (text) => Object.keys(JSON.parse(text)).length;
const stringifyOnce = (value) => JSON.stringify(value).length;

measure('json/parse-introspection', parseOnce, introspection);
measure('json/stringify-introspection', stringifyOnce, JSON.parse(introspection));
measure('json/parse-small-response', parseOnce, smallResponse);
measure('json/stringify-small-response', stringifyOnce, JSON.parse(smallResponse));
measure('json/parse-variables', parseOnce, variables);
if (sink === 0) throw new Error('no work was done');
