// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//
// The graphql-js v17.0.2 `experimentalExecuteIncrementally`
// baseline of bench/gql_execution/incremental.mojo. The timing method is
// that of bench/baselines/js-stream/bench.mjs, with an `await` for each
// operation.
//
// incremental/defer-100: a list of 100 objects, each with a deferred
// fragment; execute and read every payload.
// incremental/stream-1000: a list of 1000 objects with
// `@stream(initialCount: 10)`; execute and read every payload.

import { buildSchema, parse, experimentalExecuteIncrementally } from 'graphql';

const ROUND_NS = 1_000_000_000n;
const ROUNDS = 5;
const WARMUP_NS = 200_000_000n;

let sink = 0;

async function run(work, iterations) {
  const start = process.hrtime.bigint();
  for (let i = 0; i < iterations; i++) {
    sink += await work();
  }
  return process.hrtime.bigint() - start;
}

async function measure(name, work) {
  let iterations = 1;
  let warm = 0n;
  for (;;) {
    const elapsed = await run(work, iterations);
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
    const elapsed = Number(await run(work, iterations));
    best = Math.min(best, elapsed / iterations);
  }
  console.log(`BENCH ${name} ${best.toFixed(1)}`);
}

const schema = buildSchema(`
  type Friend { id: ID name: String }
  type Query { friends: [Friend] }
`);

function friends(count) {
  const out = [];
  for (let i = 0; i < count; i++) out.push({ id: String(i), name: 'friend' });
  return out;
}

async function complete(document, rootValue) {
  const result = await experimentalExecuteIncrementally({
    schema,
    document,
    rootValue,
  });
  let total = result.initialResult.pending.length;
  for await (const payload of result.subsequentResults) {
    total += (payload.incremental ?? []).length;
  }
  return total;
}

const deferDocument = parse('{ friends { id ... @defer { name } } }');
const deferRoot = { friends: friends(100) };
const streamDocument = parse(
  '{ friends @stream(initialCount: 10) { id name } }',
);
const streamRoot = { friends: friends(1000) };

await measure('incremental/defer-100', () => complete(deferDocument, deferRoot));
await measure('incremental/stream-1000', () =>
  complete(streamDocument, streamRoot),
);
if (sink === 0) throw new Error('no work was done');
