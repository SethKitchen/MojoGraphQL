// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// The Apollo Server 5.5.1 baseline of `server/defer-multipart`.
//
// Apollo Server runs incremental delivery only with graphql-js
// 17.0.0-alpha.9, so this baseline has its own node_modules. Each
// operation is one `server.executeHTTPGraphQLRequest` of a POST of
// `{ books { title ... @defer { author } } }` with 10 books and
// `accept: multipart/mixed; incrementalSpec=v0.2`, then every chunk of the
// `multipart/mixed` body. The method is that of ../bench.mjs.

import { ApolloServer, HeaderMap } from '@apollo/server';

const ROUND_NS = 1_000_000_000n;
const ROUNDS = 5;
const WARMUP_NS = 200_000_000n;

const typeDefs = `
directive @defer(if: Boolean! = true, label: String) on FRAGMENT_SPREAD | INLINE_FRAGMENT
type Query { books: [Book] }
type Book { title: String author: String }
`;

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

const server = new ApolloServer({
  typeDefs,
  resolvers: {
    Query: {
      books: () => {
        const out = [];
        for (let i = 0; i < 10; i++) out.push({ title: 'Title', author: 'Author' });
        return out;
      },
    },
  },
  nodeEnv: 'production',
});
await server.start();

async function deferMultipart() {
  const response = await server.executeHTTPGraphQLRequest({
    httpGraphQLRequest: {
      method: 'POST',
      headers: new HeaderMap([
        ['content-type', 'application/json'],
        ['accept', 'multipart/mixed; incrementalSpec=v0.2'],
      ]),
      search: '',
      body: { query: '{ books { title ... @defer { author } } }' },
    },
    context: async () => ({}),
  });
  if (response.body.kind !== 'chunked') throw new Error('not incremental');
  let length = 0;
  for await (const chunk of response.body.asyncIterator) length += chunk.length;
  return length;
}

const check = await deferMultipart();
if (check < 100) throw new Error('bad body');
await measure('server/defer-multipart', deferMultipart);
await server.stop();
if (sink === 0) throw new Error('nothing ran');
