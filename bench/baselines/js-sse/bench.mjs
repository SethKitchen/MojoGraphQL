// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

// The Node.js baselines of the gql_sse and gql_http streaming benchmarks.
//
//   node bench.mjs sse         `sse/subscribe-1000-next`: the handler of
//                              graphql-sse 2.6.3, distinct connections mode,
//                              on graphql-js 16; one POST of a subscription
//                              whose root field yields 1000 events, and the
//                              text of every message is read
//                              `sse/parse-1000-next`: the `createParser` of
//                              graphql-sse reads a body of 1000 `next`
//                              messages and a `complete`
//   node bench.mjs multipart   `multipart/parse-100-parts`: meros 1.3.2 reads
//                              a `multipart/mixed` body of 100 JSON parts
//
// The bytes and the method are those of `bench/gql_sse/sse.mojo` and
// `bench/gql_http/multipart.mojo`: a warm-up, then the fastest of 5 rounds
// of at least one second each.

import { buildSchema } from 'graphql';
import { createHandler } from 'graphql-sse';
import { createParser } from './node_modules/graphql-sse/lib/parser.mjs';
import { meros } from 'meros';

const EVENTS = 1000;
const PARTS = 100;
const NEXT = '{"data":{"greetings":"hi"}}';
const PART =
  '{"incremental":[{"id":"0","data":{"name":"Luke"}}],"completed":[{"id":"0"}],"hasNext":true}';

async function time(op) {
  let iterations = 1;
  for (;;) {
    const elapsed = await op(iterations);
    if (elapsed >= 125e6) {
      iterations = Math.max(1, Math.floor(1e9 / Math.max(elapsed / iterations, 1)));
      break;
    }
    iterations *= 2;
  }
  let best = Infinity;
  for (let round = 0; round < 5; round++) {
    best = Math.min(best, (await op(iterations)) / iterations);
  }
  return Math.trunc(best * 10) / 10;
}

function headers(fields) {
  return { get: (key) => fields[key] ?? null };
}

async function sse() {
  const schema = buildSchema(
    'type Query { hello: String } type Subscription { greetings: String }',
  );
  schema.getSubscriptionType().getFields().greetings.subscribe = async function* () {
    for (let i = 0; i < EVENTS; i++) yield { greetings: 'hi' };
  };
  const handler = createHandler({ schema });
  const request = {
    method: 'POST',
    url: '/',
    headers: headers({
      accept: 'text/event-stream',
      'content-type': 'application/json',
    }),
    body: '{"query":"subscription { greetings }"}',
    raw: null,
    context: undefined,
  };
  let sink = 0;
  const subscribe = await time(async (iterations) => {
    const start = process.hrtime.bigint();
    for (let i = 0; i < iterations; i++) {
      const [body] = await handler(request);
      for await (const text of body) sink += text.length;
    }
    return Number(process.hrtime.bigint() - start);
  });
  console.log(`BENCH sse/subscribe-1000-next ${subscribe}`);

  let text = '';
  for (let i = 0; i < EVENTS; i++) text += `event: next\ndata: ${NEXT}\n\n`;
  text += 'event: complete\ndata:\n\n';
  const bytes = new TextEncoder().encode(text);
  const parse = await time(async (iterations) => {
    const start = process.hrtime.bigint();
    for (let i = 0; i < iterations; i++) {
      const messages = createParser()(bytes);
      sink += messages.length;
    }
    return Number(process.hrtime.bigint() - start);
  });
  console.log(`BENCH sse/parse-1000-next ${parse}`);
  if (sink < 0) console.log(sink);
}

async function multipart() {
  let text = '';
  for (let i = 0; i < PARTS; i++) {
    text += `\r\n---\r\ncontent-type: application/json; charset=utf-8\r\n\r\n${PART}`;
  }
  text += '\r\n-----\r\n';
  const body = Buffer.from(text);
  let sink = 0;
  const parse = await time(async (iterations) => {
    const start = process.hrtime.bigint();
    for (let i = 0; i < iterations; i++) {
      const response = {
        headers: { 'content-type': 'multipart/mixed; boundary="-"' },
        async *[Symbol.asyncIterator]() {
          yield body;
        },
      };
      for await (const part of await meros(response)) {
        if (part.json) sink += 1;
      }
    }
    return Number(process.hrtime.bigint() - start);
  });
  if (sink === 0) throw new Error('meros read no JSON part');
  console.log(`BENCH multipart/parse-100-parts ${parse}`);
}

const mode = process.argv[2];
if (mode === 'sse') await sse();
else if (mode === 'multipart') await multipart();
else throw new Error(`unknown mode ${mode}`);
