// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// The @apollo/subgraph 2.14.4 baseline of the gql_subgraph benchmarks.
//
// `node bench.mjs` times the workloads of bench/gql_subgraph/subgraph.mojo
// with the method of bench/baselines/js/bench.mjs: warm up, then rounds of
// at least ROUND_NS each, and report the fastest round. Every workload
// uses bench/fixtures/subgraph-catalog.graphql:
//
// - subgraph/build-catalog: buildSubgraphSchema(parse(sdl)).
// - subgraph/print-catalog: printSubgraphSchema of the built schema.
// - subgraph/service-sdl: execute `{ _service { sdl } }`.
// - subgraph/entities-100: execute `_entities` with 100 Product
//   representations and a __resolveReference.
//
// The operations are parsed once. They run with graphql-js 16.14.2
// `execute`, which returns a plain value here: no resolver is async.

import { readFileSync } from 'node:fs';
import { buildSubgraphSchema, printSubgraphSchema } from '@apollo/subgraph';
import { execute, parse } from 'graphql';

const ROUND_NS = 1_000_000_000n;
const ROUNDS = 5;
const WARMUP_NS = 200_000_000n;
const COUNT = 100;
const SDL = readFileSync('../../fixtures/subgraph-catalog.graphql', 'utf8');
const ENTITIES =
  'query($representations: [_Any!]!) { _entities(representations:' +
  ' $representations) { ... on Product { upc name price { amount currency }' +
  ' } } }';

const resolvers = {
  Product: {
    __resolveReference(reference) {
      return {
        upc: reference.upc,
        name: 'Product ' + reference.upc,
        price: { amount: 100, currency: 'USD' },
      };
    },
  },
};

function build() {
  return buildSubgraphSchema([{ typeDefs: parse(SDL), resolvers }]);
}

let sink = 0;

// A workload returns a number, or a promise of one: `_entities` resolves
// its representations with Promise.all, so its `execute` is async. A
// number is not awaited, so the synchronous workloads stay synchronous.
async function run(work, iterations) {
  const start = process.hrtime.bigint();
  for (let i = 0; i < iterations; i++) {
    const value = work();
    sink += typeof value === 'number' ? value : await value;
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

function check(result) {
  if (result.errors) throw new Error(result.errors[0].message);
  return Object.keys(result.data).length;
}

function executor(schema, query, variableValues) {
  const document = parse(query);
  return () => {
    const result = execute({ schema, document, variableValues });
    return result instanceof Promise ? result.then(check) : check(result);
  };
}

const representations = [];
for (let i = 0; i < COUNT; i++) {
  representations.push({ __typename: 'Product', upc: String(i) });
}

await measure('subgraph/build-catalog', () => (build().getTypeMap() ? 1 : 0));
const schema = build();
await measure('subgraph/print-catalog', () => printSubgraphSchema(schema).length);
await measure('subgraph/service-sdl', executor(schema, '{ _service { sdl } }'));
await measure(
  'subgraph/entities-100',
  executor(schema, ENTITIES, { representations }),
);
if (sink === 0) throw new Error('nothing ran');
