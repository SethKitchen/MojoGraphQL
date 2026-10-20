// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

// The Node.js baselines of the gql_ws benchmarks.
//
//   node bench.mjs server   `ws/echo-roundtrip`: a `ws` 8 server that
//                           echoes each text message
//   node bench.mjs gql      `graphql-ws/subscribe-1000-next`: graphql-ws
//                           6.4.1 on `ws`, with graphql-js 16 and a
//                           graphql-subscriptions PubSub
//   node bench.mjs frames   `ws/frame-parse` and `ws/frame-write`: the
//                           Receiver and the Sender of `ws`
//
// A server prints `PORT <n>` and serves until it is killed;
// `bench/gql_ws/_wsload.mojo` drives it. The frame workloads use the bytes
// and the method of `bench/gql_ws/frames.mojo`: a warm-up, then the fastest
// of 5 rounds of at least one second each.

import { buildSchema } from 'graphql';
import { PubSub } from 'graphql-subscriptions';
import { useServer } from 'graphql-ws/use/ws';
import { Receiver, Sender, WebSocketServer } from 'ws';

const EVENTS = 1000;
const SIZE = 1024;

function listen(server) {
  server.on('listening', () => {
    console.log(`PORT ${server.address().port}`);
  });
}

function echo() {
  const server = new WebSocketServer({ host: '127.0.0.1', port: 0 });
  server.on('connection', (socket) => {
    socket._socket.setNoDelay(true);
    socket.on('message', (data, isBinary) => {
      if (!isBinary) socket.send(data, { binary: false });
    });
  });
  listen(server);
}

function gql() {
  const schema = buildSchema(
    'type Query { hello: String } type Subscription { greetings: String }',
  );
  const pubsub = new PubSub();
  const roots = {
    subscription: {
      greetings: () => {
        const iterator = pubsub.asyncIterableIterator('GREETINGS');
        // Subscribe now, as the gql_ws benchmark does, then publish.
        iterator.allSubscribed = iterator.subscribeAll();
        for (let i = 0; i < EVENTS; i++) {
          pubsub.publish('GREETINGS', { greetings: 'hi' });
        }
        return iterator;
      },
    },
  };
  const server = new WebSocketServer({ host: '127.0.0.1', port: 0 });
  server.on('connection', (socket) => socket._socket.setNoDelay(true));
  useServer({ schema, roots, isProd: true }, server);
  listen(server);
}

function payload() {
  let text = '{"id":"1","type":"next","payload":{"data":{"greetings":"';
  while (text.length < SIZE - 4) text += 'hello ';
  return text.slice(0, SIZE - 4) + '"}}}';
}

function maskedFrame(text) {
  const data = Buffer.from(text);
  const mask = Buffer.from([0xf0, 0xde, 0xbc, 0x9a]);
  const head = Buffer.from([0x81, 0x80 | 126, data.length >> 8, data.length & 255]);
  const body = Buffer.alloc(data.length);
  for (let i = 0; i < data.length; i++) body[i] = data[i] ^ mask[i & 3];
  return Buffer.concat([head, mask, body]);
}

function time(op) {
  let iterations = 1;
  for (;;) {
    const elapsed = op(iterations);
    if (elapsed >= 125e6) {
      iterations = Math.max(1, Math.floor(1e9 / Math.max(elapsed / iterations, 1)));
      break;
    }
    iterations *= 2;
  }
  let best = Infinity;
  for (let round = 0; round < 5; round++) {
    best = Math.min(best, op(iterations) / iterations);
  }
  return Math.trunc(best * 10) / 10;
}

function frames() {
  const text = payload();
  const frame = maskedFrame(text);
  const receiver = new Receiver({ isServer: true, maxPayload: 64 << 20 });
  let sink = 0;
  receiver.on('message', (data) => {
    sink += data.length;
  });
  const parse = time((iterations) => {
    const start = process.hrtime.bigint();
    for (let i = 0; i < iterations; i++) receiver.write(Buffer.from(frame));
    return Number(process.hrtime.bigint() - start);
  });
  console.log(`BENCH ws/frame-parse ${parse}`);
  const options = { fin: true, rsv1: false, opcode: 1, mask: false, readOnly: false };
  const write = time((iterations) => {
    const start = process.hrtime.bigint();
    for (let i = 0; i < iterations; i++) {
      const parts = Sender.frame(Buffer.from(text), options);
      sink += parts.length;
    }
    return Number(process.hrtime.bigint() - start);
  });
  console.log(`BENCH ws/frame-write ${write}`);
  if (sink < 0) console.log(sink);
}

const mode = process.argv[2];
if (mode === 'server') echo();
else if (mode === 'gql') gql();
else if (mode === 'frames') frames();
else throw new Error(`unknown mode ${mode}`);
