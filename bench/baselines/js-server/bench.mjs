// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// The Apollo Server 5.5.1 baseline of the gql_server benchmarks.
//
// `node bench.mjs` times `server/execute-operation-small` and
// `server/apq-hit` with the method of bench/baselines/js/bench.mjs: warm
// up, then rounds of at least ROUND_NS each, and report the fastest round.
// Each operation is one awaited `server.executeOperation`, which is what
// the Mojo workload times.
//
// `node bench.mjs server` serves `server/http-post-small` with
// `startStandaloneServer` on a free loopback port. It prints `PORT <n>` and
// serves until it is killed; bench/gql_http/_loadgen.mojo drives it.
//
// Both use `nodeEnv: 'production'`, the setting for a deployed server.

import { createHash } from 'node:crypto';
import { ApolloServer } from '@apollo/server';
import { startStandaloneServer } from '@apollo/server/standalone';

const ROUND_NS = 1_000_000_000n;
const ROUNDS = 5;
const WARMUP_NS = 200_000_000n;
const QUERY = '{ hello }';

function makeServer() {
  return new ApolloServer({
    typeDefs: 'type Query { hello: String }',
    resolvers: { Query: { hello: () => 'world' } },
    nodeEnv: 'production',
  });
}

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

async function operations() {
  const server = makeServer();
  await server.start();
  const check = await server.executeOperation({ query: QUERY });
  if (check.body.singleResult.data.hello !== 'world') throw new Error('bad');
  await measure('server/execute-operation-small', async () => {
    const response = await server.executeOperation({ query: QUERY });
    return response.body.singleResult.data.hello.length;
  });
  const sha256Hash = createHash('sha256').update(QUERY).digest('hex');
  const persistedQuery = { version: 1, sha256Hash };
  await server.executeOperation({ query: QUERY, extensions: { persistedQuery } });
  await measure('server/apq-hit', async () => {
    const response = await server.executeOperation({
      extensions: { persistedQuery },
    });
    return response.body.singleResult.data.hello.length;
  });
  await server.stop();
  if (sink === 0) throw new Error('nothing ran');
}

async function serve() {
  const { url } = await startStandaloneServer(makeServer(), {
    listen: { port: 0, host: '127.0.0.1' },
  });
  process.stdout.write(`PORT ${new URL(url).port}\n`);
}

if (process.argv[2] === 'server') {
  await serve();
} else {
  await operations();
}
