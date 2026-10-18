// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// The Hive Federation Composition 0.27.0 baseline of `rover supergraph
// compose` for gql_seamstress. Rover composes with the Elastic licensed
// `supergraph` plugin, which this project never runs, so the baseline is
// the composition library that gql_seamstress ports: Hive `composeServices`.
//
// `seamstress/supergraph-compose-stars-stuff` reads the five subgraph files of
// `bench/fixtures/hive-stars-stuff`, parses them, and composes them, in each
// operation. The Mojo workload does that too, and reads the YAML
// configuration as well. Both read copies in /tmp/gql-seamstress-bench-js, off
// the repository's file system. The method is the one of
// bench/baselines/js/bench.mjs: warm up, then rounds of at least ROUND_NS
// each, and report the fastest round.

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { parse } from 'graphql';
import { composeServices } from '@theguild/federation-composition';

const FIXTURES = new URL('../../fixtures/hive-stars-stuff/', import.meta.url);
const SCRATCH = '/tmp/gql-seamstress-bench-js';
const NAMES = ['inventory', 'pandas', 'products', 'reviews', 'users'];
const ROUND_NS = 1_000_000_000n;
const ROUNDS = 5;
const WARMUP_NS = 200_000_000n;

let sink = 0;

function run(work, iterations) {
  const start = process.hrtime.bigint();
  for (let i = 0; i < iterations; i++) {
    sink += work();
  }
  return process.hrtime.bigint() - start;
}

function measure(name, work) {
  let iterations = 1;
  let warm = 0n;
  for (;;) {
    const elapsed = run(work, iterations);
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
    const elapsed = Number(run(work, iterations));
    best = Math.min(best, elapsed / iterations);
  }
  console.log(`BENCH ${name} ${best.toFixed(1)}`);
}

mkdirSync(SCRATCH, { recursive: true });
for (const name of NAMES) {
  writeFileSync(`${SCRATCH}/${name}.graphql`, readFileSync(new URL(`${name}.graphql`, FIXTURES)));
}

function compose() {
  const services = NAMES.map((name) => ({
    name,
    url: `http://${name}.example.com/graphql`,
    typeDefs: parse(readFileSync(`${SCRATCH}/${name}.graphql`, 'utf8')),
  }));
  const result = composeServices(services);
  if (result.errors) throw new Error(result.errors[0].message);
  return result.supergraphSdl.length;
}

measure('seamstress/supergraph-compose-stars-stuff', compose);
if (sink === 0) console.log('');
