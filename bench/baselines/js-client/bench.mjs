// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// The Apollo Client 4.3.3 baseline of the gql_client benchmarks: the
// InMemoryCache, run with `node --conditions=production`, so that the
// production build runs without development checks. It prints
// `BENCH <workload> <ns per op>` lines with the method of
// bench/baselines/js/bench.mjs: warm up, then rounds of at least ROUND_NS
// each, and report the fastest round. Work outside the measured operation,
// such as parsing the query and the fixture, happens in setup.
//
// A read workload uses `resultCaching: false`. With the result cache, a
// read of unchanged data returns the result of the last read, so it would
// not measure reading. The Mojo cache has no result cache.

import { readFileSync } from 'node:fs';
import { InMemoryCache, gql } from '@apollo/client';
import { GraphQL17Alpha9Handler } from '@apollo/client/incremental';

const FIXTURES = new URL('../../fixtures/', import.meta.url);
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

const data = JSON.parse(
  readFileSync(new URL('client-items-1000.json', FIXTURES), 'utf8'),
);
const query = gql`
  query Items {
    items {
      id
      title
      price
      inStock
      tags
      author {
        id
        name
      }
      stats {
        views
        likes
      }
    }
  }
`;
const partialQuery = gql`
  query Items {
    items {
      id
      title
      price
      inStock
      tags
      rating
      author {
        id
        name
      }
      stats {
        views
        likes
      }
    }
  }
`;
const fragment = gql`
  fragment ItemFields on Item {
    id
    title
    price
    author {
      name
    }
  }
`;

function filled(options) {
  const cache = new InMemoryCache(options);
  cache.writeQuery({ query, data });
  return cache;
}

// Write the 1000 items into a new cache.
measure('client/write-new-items-1000', () => {
  const cache = new InMemoryCache();
  cache.writeQuery({ query, data });
  return 1;
});

// Write the same 1000 items again into a cache that holds them.
{
  const cache = filled();
  measure('client/write-merge-items-1000', () => {
    cache.writeQuery({ query, data });
    return 1;
  });
}

// Read the 1000 items.
{
  const cache = filled({ resultCaching: false });
  measure('client/read-items-1000', () =>
    cache.readQuery({ query }).items.length,
  );
}

// Diff a query with a field that no item has.
{
  const cache = filled({ resultCaching: false });
  measure('client/diff-partial-items-1000', () => {
    const diff = cache.diff({ query: partialQuery, returnPartialData: true });
    return diff.complete ? 0 : diff.missing.message.length;
  });
}

// Serialize the normalized data.
{
  const cache = filled();
  measure('client/extract-items-1000', () =>
    JSON.stringify(cache.extract()).length,
  );
}

// Restore the normalized data from its JSON text.
{
  const text = JSON.stringify(filled().extract());
  const cache = new InMemoryCache();
  measure('client/restore-items-1000', () => {
    cache.restore(JSON.parse(text));
    return 1;
  });
}

// Read one entity with a fragment.
{
  const cache = filled({ resultCaching: false });
  measure('client/read-fragment', () =>
    cache.readFragment({ id: 'Item:500', fragment }).title.length,
  );
}

// Compute the id of an object.
{
  const cache = new InMemoryCache();
  const object = { __typename: 'Item', id: '500', title: 'Item number 500' };
  measure('client/identify', () => cache.identify(object).length);
}

// Merge 101 incremental payloads: 100 items with a pending @defer each,
// then one payload for each item. The payloads are parsed in setup, as
// the link parses them before the handler gets them.
{
  const COUNT = 100;
  const items = [];
  const pending = [];
  for (let i = 0; i < COUNT; i++) {
    items.push({ __typename: 'Item', id: String(i) });
    pending.push({ id: String(i), path: ['items', i] });
  }
  const chunks = [
    JSON.parse(JSON.stringify({ data: { items }, pending, hasNext: true })),
  ];
  for (let i = 0; i < COUNT; i++) {
    chunks.push(
      JSON.parse(
        JSON.stringify({
          incremental: [
            { id: String(i), data: { title: `Item number ${i}`, score: i } },
          ],
          completed: [{ id: String(i) }],
          hasNext: i + 1 < COUNT,
        }),
      ),
    );
  }
  const handler = new GraphQL17Alpha9Handler();
  const query = gql`
    {
      items {
        id
        ... @defer {
          title
          score
        }
      }
    }
  `;
  measure('client/merge-deferred-chunks-100', () => {
    const request = handler.startRequest({ query });
    let result;
    for (const chunk of chunks) {
      result = request.handle(undefined, chunk);
    }
    return result.data.items.length;
  });
}

if (sink === -1) console.log(sink);
