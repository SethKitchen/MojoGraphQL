// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// The Node.js HTTP baselines: the `node:http` module, which the standalone
// server of Apollo Server uses, and its llhttp parser.
//
// `node bench.mjs server` serves `http/keepalive-small-json`: it reads each
// request body and answers `{"data":{"hello":"world"}}`. It prints
// `PORT <n>` and serves until it is killed; bench/gql_http/_loadgen.mojo
// drives it. Node runs JavaScript on one thread.
//
// `node bench.mjs parse` times `http/parse-request`: the llhttp parser of
// Node (`HTTPParser` of `_http_common`) on a typical GraphQL POST, with
// the method of the Mojo benchmark: warm up, then the fastest of 5 rounds
// of at least a second.

import http from 'node:http';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

const REQUEST =
  'POST /graphql HTTP/1.1\r\n' +
  'Host: localhost:4000\r\n' +
  'Connection: keep-alive\r\n' +
  'Content-Length: 126\r\n' +
  'sec-ch-ua: "Chromium";v="128", "Not;A=Brand";v="24"\r\n' +
  'accept: application/graphql-response+json, application/json\r\n' +
  'content-type: application/json\r\n' +
  'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36\r\n' +
  'Origin: http://localhost:4000\r\n' +
  'Sec-Fetch-Site: same-origin\r\n' +
  'Sec-Fetch-Mode: cors\r\n' +
  'Referer: http://localhost:4000/\r\n' +
  'Accept-Encoding: gzip, deflate, br\r\n' +
  'Accept-Language: en-US,en;q=0.9\r\n' +
  '\r\n' +
  '{"query":"query Hero($episode: Episode) { hero(episode: $episode) { name friends { name } } }","variables":{"episode":"JEDI"}}';

const BODY = Buffer.from('{"data":{"hello":"world"}}');

function serve() {
  const server = http.createServer((req, res) => {
    req.on('data', () => {});
    req.on('end', () => {
      res.writeHead(200, {
        'Content-Type': 'application/json',
        'Content-Length': BODY.length,
      });
      res.end(BODY);
    });
  });
  server.keepAliveTimeout = 60_000;
  server.listen(0, '127.0.0.1', () => {
    process.stdout.write(`PORT ${server.address().port}\n`);
  });
}

function parse() {
  const { HTTPParser } = require('_http_common');
  const data = Buffer.from(REQUEST);
  const parser = new HTTPParser();
  let sink = 0;
  parser[HTTPParser.kOnHeadersComplete] = (major, minor, headers) => {
    sink += headers.length;
  };
  parser[HTTPParser.kOnBody] = (chunk) => {
    sink += chunk.length;
  };
  parser[HTTPParser.kOnMessageComplete] = () => {
    sink += 1;
  };
  parser.initialize(HTTPParser.REQUEST, {}, 0, 0);
  const run = (iterations) => {
    const start = process.hrtime.bigint();
    for (let i = 0; i < iterations; i++) {
      const result = parser.execute(data);
      if (typeof result !== 'number') throw result;
    }
    return Number(process.hrtime.bigint() - start);
  };
  let iterations = 1;
  for (;;) {
    const elapsed = run(iterations);
    if (elapsed >= 200_000_000) {
      iterations = Math.max(1, Math.floor(1e9 / Math.max(1, elapsed / iterations)));
      break;
    }
    iterations *= 2;
  }
  let best = Infinity;
  for (let round = 0; round < 5; round++) {
    best = Math.min(best, run(iterations) / iterations);
  }
  if (sink === 0) throw new Error('nothing parsed');
  console.log(`BENCH http/parse-request ${best.toFixed(1)}`);
}

if (process.argv[2] === 'server') {
  serve();
} else {
  parse();
}
