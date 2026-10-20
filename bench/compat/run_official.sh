#!/usr/bin/env bash
# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
#
# Run the official Apollo Federation subgraph compatibility suite
# (apollographql/apollo-federation-subgraph-compatibility f9520a4, MIT)
# against a MojoGraphQL stack. There is no Docker, no Rover and no Apollo
# Router:
#
#   products   bench/compat/products.mojo    http://localhost:4001/
#   users      bench/compat/users.mojo       http://localhost:4002/
#   inventory  bench/compat/inventory.mojo   http://localhost:4003/
#   router     bench/compat/router.mojo      http://localhost:4000/
#
# router.mojo composes the supergraph with gql_seamstress from the
# supergraph.yaml that this script writes. That file is the suite's
# supergraph-dev-config.yaml.template: products by introspection, users and
# inventory by the SDL files of packages/subgraphs.
#
# The script installs the suite's npm packages with --ignore-scripts, so
# that the @apollo/rover package does not download Rover. Then it runs the
# jest tests of packages/compatibility/src/tests, as testRunner.ts does,
# and prints one row for each check of TESTS in testRunner.ts.
#
# Usage, from any directory, in Linux or WSL:
#
#   bench/compat/run_official.sh
#
# Environment:
#   SUITE  the suite clone (~/mgql-upstream/apollographql_apollo-federation-subgraph-compatibility)
#   WORK   the build, log and result directory (~/compat_official)
#   PATH   must give node and npm (Node 24 or later)
#
# The exit code is 0 when every check passes, and 1 otherwise.

set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SUITE="${SUITE:-$HOME/mgql-upstream/apollographql_apollo-federation-subgraph-compatibility}"
WORK="${WORK:-$HOME/compat_official}"
COMPAT="$SUITE/packages/compatibility"
MOJO="$REPO/.venv/bin/mojo"
mkdir -p "$WORK/bin"
PIDS=()

stop_all() {
  for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null; done
  wait 2>/dev/null
}
trap stop_all EXIT

# Build the four programs. A program is built again only when a Mojo file
# of the repository is newer than it.
build() {
  local name="$1"
  shift
  if [ -x "$WORK/bin/$name" ] && [ -z "$(find "$REPO" -name '*.mojo' \
    -not -path '*/.venv/*' -newer "$WORK/bin/$name" -print -quit)" ]; then
    return 0
  fi
  echo "building $name"
  (cd "$REPO" && "$MOJO" build -I . "$@" -o "$WORK/bin/$name" \
    "bench/compat/$name.mojo") > "$WORK/build_$name.log" 2>&1 \
    || { cat "$WORK/build_$name.log"; exit 1; }
}
build products -I tests/gql_subgraph
build users
build inventory
build router

# Wait until a GraphQL endpoint answers `query { __typename }`, as the
# healthcheck of utils/client.ts does.
wait_for() {
  local name="$1" url="$2" tries=60
  while [ "$tries" -gt 0 ]; do
    if curl -s -H 'content-type: application/json' \
      -d '{"query":"query { __typename }"}' "$url" | grep -q '__typename'; then
      echo "$name is up at $url"
      return 0
    fi
    tries=$((tries - 1))
    sleep 1
  done
  echo "$name did not start; see $WORK/$name.log"
  exit 1
}

# Wait until a probe of the router answers 200: /health, as the
# healthcheckRouter of utils/client.ts does, and /readiness, which answers
# 200 when the router has its supergraph. Both are the Hive Router probes.
wait_for_probes() {
  local name="$1" url="$2" tries=60
  while [ "$tries" -gt 0 ]; do
    if curl -sf -o /dev/null "${url}health" \
      && curl -sf -o /dev/null "${url}readiness"; then
      echo "$name is up and ready at $url"
      return 0
    fi
    tries=$((tries - 1))
    sleep 1
  done
  echo "$name did not start; see $WORK/$name.log"
  exit 1
}

start() {
  local name="$1" url="$2" wait="${3:-wait_for}"
  "$WORK/bin/$name" > "$WORK/$name.log" 2>&1 &
  PIDS+=("$!")
  "$wait" "$name" "$url"
}
start products http://localhost:4001/
start users http://localhost:4002/
start inventory http://localhost:4003/

cat > "$WORK/supergraph.yaml" <<EOF
federation_version: =2.15.1
subgraphs:
  products:
    routing_url: http://localhost:4001/
    schema:
      subgraph_url: http://localhost:4001/
  users:
    routing_url: http://localhost:4002/
    schema:
      file: $SUITE/packages/subgraphs/users/users.graphql
  inventory:
    routing_url: http://localhost:4003/
    schema:
      file: $SUITE/packages/subgraphs/inventory/inventory.graphql
EOF
SUPERGRAPH_CONFIG="$WORK/supergraph.yaml" \
  SUPERGRAPH_OUT="$WORK/supergraph.graphql" \
  start router http://localhost:4000/ wait_for_probes

# Install the jest dependencies once, without the install scripts.
if [ ! -d "$SUITE/node_modules/jest" ]; then
  echo "installing the suite's npm packages"
  (cd "$SUITE" && npm install --ignore-scripts --no-audit --no-fund) \
    > "$WORK/npm.log" 2>&1 || { tail -n 20 "$WORK/npm.log"; exit 1; }
fi
# The `package` script of the suite copies the reference SDL that
# utils/schemaComparison.ts reads. --ignore-scripts skips it.
cp "$SUITE/implementations/_template_library_/products.graphql" "$COMPAT/"

echo "running the jest tests"
(cd "$COMPAT" && PRODUCTS_URL=http://localhost:4001/ node \
  "$SUITE/node_modules/jest/bin/jest.js" src/tests --ci --json \
  --outputFile="$WORK/jest.json" --config federation-jest.config.js) \
  > "$WORK/jest.log" 2>&1

# Print the result of each check, as assertionPassed of testRunner.ts.
node - "$WORK/jest.json" "$COMPAT/src/testRunner.ts" <<'EOF'
const fs = require('fs');
const results = JSON.parse(fs.readFileSync(process.argv[2], 'utf-8'));
const source = fs.readFileSync(process.argv[3], 'utf-8');
const tests = [...source.matchAll(/assertion: '([^']+)',\s*column: '([^']+)'/g)];
const assertions = results.testResults.flatMap((x) => x.assertionResults);
for (const suite of results.testResults) {
  if (suite.assertionResults.length === 0) console.error(`${suite.name}: ${suite.message}`);
}
let failed = 0;
console.log('| Check | Jest test | Result |\n| --- | --- | --- |');
for (const [, assertion, column] of tests) {
  const mine = assertions.filter((a) =>
    (a.ancestorTitles.length === 0 ? a.fullName : a.ancestorTitles[0]) === assertion);
  const bad = mine.filter((a) => a.status !== 'passed');
  // A check with no test result did not run, so it does not pass.
  const pass = mine.length > 0 && bad.length === 0;
  if (!pass) failed++;
  console.log(`| ${column} | ${assertion} | ${pass ? 'Pass' : 'Fail'} |`);
  for (const a of bad) console.error(`${a.fullName}:\n${a.failureMessages.join('\n')}\n`);
}
console.log(`\n${results.numPassedTests} of ${results.numTotalTests} jest tests pass`);
process.exit(failed === 0 && results.numRuntimeErrorTestSuites === 0 ? 0 : 1);
EOF
