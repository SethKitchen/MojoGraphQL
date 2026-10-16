// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// The Hive Federation Composition 0.27.0 baseline for gql_composition. It
// prints `BENCH <workload> <ns per op>` lines with the same method as
// bench/baselines/js/bench.mjs: warm up, then rounds of at least ROUND_NS
// each, and report the fastest round.
//
// Each workload is the subgraph phase of upstream `validate`, on the
// subgraphs of an upstream benchmark fixture: `buildGraphList`,
// `validateSubgraphCore`, `detectFederationVersion`,
// `createSubgraphStateBuilder` and `validateSubgraph`. Upstream does not
// export `buildGraphList`, so this file has a copy of it. The subgraphs are
// parsed in setup, as the upstream `benchmark.ts` parses them.

import { readFileSync, readdirSync } from 'node:fs';
import { parse } from 'graphql';
import { constantCase } from 'constant-case';

const esm = new URL(
  './node_modules/@theguild/federation-composition/esm/',
  import.meta.url,
);
const { moveSchemaAndDirectiveDefinitionsToTop } = await import(
  new URL('graphql/helpers.js', esm)
);
const { detectFederationVersion } = await import(
  new URL('specifications/federation.js', esm)
);
const { createSubgraphStateBuilder } = await import(
  new URL('subgraph/state.js', esm)
);
const { validateSubgraph, validateSubgraphCore } = await import(
  new URL('subgraph/validation/validate-subgraph.js', esm)
);

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

// A copy of the unexported `buildGraphList` of `src/validate.ts`.
function buildGraphList(subgraphs) {
  const graphs = [];
  const names = new Set();
  const idCounter = new Map();
  for (const subgraph of subgraphs) {
    const name = String(subgraph.name);
    if (names.has(name)) {
      throw new Error(`A subgraph named ${name} already exists`);
    }
    names.add(name);
    let id = constantCase(name.replace(/[^A-Z0-9]/gi, '_'), {
      stripRegexp: /[^A-Z0-9_]+/gi,
    });
    if (/^\d/.test(name)) {
      id = '_' + id + '_';
    }
    const typeDefs = moveSchemaAndDirectiveDefinitionsToTop(subgraph.typeDefs);
    const count = idCounter.get(id);
    if (typeof count === 'number') {
      if (count === 1) {
        graphs.find((g) => g.id === id).id += '_1';
      }
      graphs.push({ name, id: id + '_' + (count + 1), typeDefs });
      idCounter.set(id, count + 1);
    } else {
      idCounter.set(id, 1);
      graphs.push({ name, id, typeDefs });
    }
  }
  graphs.sort((a, b) => a.id.localeCompare(b.id));
  return graphs;
}

// The subgraph phase of upstream `validate`.
function validateSubgraphs(subgraphs) {
  const graphs = buildGraphList(subgraphs);
  const cores = graphs.map((graph) => validateSubgraphCore(graph));
  const coreErrors = cores.map((core) => core.errors ?? []).flat(1);
  if (coreErrors.length > 0) {
    return coreErrors;
  }
  const detected = graphs.map((graph) =>
    detectFederationVersion(graph.typeDefs),
  );
  const builders = graphs.map((graph, i) =>
    createSubgraphStateBuilder(
      graph,
      graph.typeDefs,
      detected[i].version,
      cores[i].links ?? [],
    ),
  );
  return graphs
    .map((graph, i) => validateSubgraph(graph, builders[i], detected[i]))
    .flat(1);
}

function subgraphsOf(directory) {
  const url = new URL(directory + '/', FIXTURES);
  return readdirSync(url)
    .filter((file) => file.endsWith('.graphql'))
    .sort()
    .map((file) => ({
      name: file.replace('.graphql', ''),
      typeDefs: parse(readFileSync(new URL(file, url), 'utf8'), {
        noLocation: true,
      }),
    }));
}

for (const name of ['basic', 'stars-stuff', 'dgs', 'huge-schema']) {
  const subgraphs = subgraphsOf('hive-' + name);
  if (validateSubgraphs(subgraphs).length !== 0) {
    throw new Error(`hive-${name} has subgraph errors`);
  }
  measure(`composition/validate-subgraphs-${name}`, () =>
    validateSubgraphs(subgraphs).length + 1,
  );
}
if (sink === 0) console.log('unreachable');
