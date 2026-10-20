// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
//
// The graphql-js 16.14.2 `subscribe` and graphql-subscriptions 3.0.0
// `PubSub` baseline of bench/gql_execution/subscribe.mojo and
// bench/gql_stream/pubsub.mojo. The timing method is that of
// bench/baselines/js-json/bench.mjs, with an `await` for each operation.
//
// stream/subscribe-publish-100: subscribe to an operation, then publish
// 100 events and consume the 100 responses.
// stream/pubsub-fanout-1000: one publish to 1000 subscribed iterators, and
// one `next()` of each.

import { buildSchema, parse, subscribe } from 'graphql';
import { EventEmitter } from 'node:events';
import { PubSub } from 'graphql-subscriptions';

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
  type Query { dummy: String }
  type Message { id: Int text: String channel: String }
  type Subscription { messageAdded(channel: String!): Message }
`);
const document = parse(
  'subscription { messageAdded(channel: "general") { id text channel } }',
);
const EVENTS = 100;

async function subscribePublish() {
  const pubsub = new PubSub();
  const rootValue = {
    messageAdded: () => pubsub.asyncIterableIterator('MESSAGE'),
  };
  const responses = await subscribe({ schema, document, rootValue });
  let total = 0;
  let pending = responses.next();
  for (let i = 0; i < EVENTS; i++) {
    await pubsub.publish('MESSAGE', {
      messageAdded: { id: i, text: 'hello', channel: 'general' },
    });
    const result = await pending;
    total += result.value.data.messageAdded.id;
    pending = responses.next();
  }
  await responses.return();
  return total + 1;
}

const SUBSCRIBERS = 1000;
const emitter = new EventEmitter();
emitter.setMaxListeners(0);
const fanout = new PubSub({ eventEmitter: emitter });
const iterators = [];
const pendings = [];
for (let i = 0; i < SUBSCRIBERS; i++) {
  const iterator = fanout.asyncIterableIterator('FAN');
  iterators.push(iterator);
  pendings.push(iterator.next());
}
let counter = 0;

async function fanoutOnce() {
  counter += 1;
  await fanout.publish('FAN', { n: counter });
  let total = 0;
  for (let i = 0; i < SUBSCRIBERS; i++) {
    const result = await pendings[i];
    total += result.value.n;
    pendings[i] = iterators[i].next();
  }
  return total;
}

await measure('stream/subscribe-publish-100', subscribePublish);
await measure('stream/pubsub-fanout-1000', fanoutOnce);
if (sink === 0) throw new Error('no work was done');
