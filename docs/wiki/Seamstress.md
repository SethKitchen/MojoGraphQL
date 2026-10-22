<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Seamstress

`gql_seamstress` runs the local commands of Apollo Rover that need no GraphOS. It is a port of the MIT parts of Rover 1.0.0 (`39a041a`). It needs `gql_language`, `gql_json`, `gql_schema`, `gql_execution`, `gql_http` and `gql_composition`.

| Command | What it does |
| --- | --- |
| `seamstress supergraph compose --config <FILE>` | Reads `supergraph.yaml`, resolves each subgraph, composes them, and prints the supergraph SDL |
| `seamstress subgraph introspect <ENDPOINT>` | Sends the `_service { sdl }` query, and prints the SDL |
| `seamstress graph introspect <ENDPOINT>` | Sends the introspection query, and prints the schema as SDL |
| `seamstress subgraph publish <GATEWAY> --name <NAME>` | Publishes a subgraph to a ScorchQL gateway |
| `seamstress subgraph delete <GATEWAY> --name <NAME> --confirm` | Removes a subgraph from a ScorchQL gateway |
| `seamstress subgraph list <GATEWAY>` | Lists the subgraphs of a ScorchQL gateway |

Each command takes `--format plain` or `--format json`, and `--output <FILE>`. As in Rover 1.0.0, `--format json` selects the JSON output, and `--output` names the file that receives the output. The text and the JSON are the Rover text and JSON. An error has the Rover message and code, such as `error[E029]`, and exit code 1. A usage error has the clap message and exit code 2.

| Module | Contents | Rover source |
| --- | --- | --- |
| `gql_seamstress.cli` | `run_seamstress`: the command line | `src/cli.rs`, the clap options of each command |
| `gql_seamstress.compose` | `supergraph_compose` | `src/command/supergraph/compose`, `src/composition` |
| `gql_seamstress.config` | `SupergraphConfig`, `parse_supergraph_config` | `apollo-federation-types` `src/config` |
| `gql_seamstress.federation_version` | `FederationVersion`, `SemanticVersion` | `apollo-federation-types` `src/config/version.rs`, `src/federation.rs` |
| `gql_seamstress.yaml`, `yaml_scalar` | A minimal YAML reader | serde_yaml, for the subset that a configuration uses |
| `gql_seamstress.introspect` | `subgraph_introspect`, `graph_introspect` | `src/command/*/introspect.rs`, `crates/rover-client` |
| `gql_seamstress.publish` | `subgraph_publish`, `subgraph_delete`, `subgraph_list` | `src/command/subgraph/publish`, `delete.rs`, `list.rs`, `src/utils/parsers.rs` |
| `gql_seamstress.graphql_client` | One GraphQL request over HTTP | `crates/rover-graphql` |
| `gql_seamstress.encode`, `serialize` | The SDL of an introspection result | `graph/introspect/schema.rs`, apollo-compiler `ast/serialize.rs` |
| `gql_seamstress.introspection_json` | `graph introspect --format json` | `graph/introspect/introspection_json.rs` |
| `gql_seamstress.output` | `CommandResult`, `RoverError`, the JSON envelope | `src/command/output.rs`, `src/options/output.rs`, `src/error` |

## Use the program

Build the program, then run a command:

```bash
.venv/bin/mojo build -I . -o seamstress bench/gql_seamstress/_seamstress.mojo
./seamstress supergraph compose --config supergraph.yaml > supergraph.graphql
```

From Mojo, call `run_seamstress` with the arguments. It returns the standard output, the standard error and the exit code:

```mojo
from gql_seamstress.cli import run_seamstress


def main() raises:
    var result = run_seamstress(["supergraph", "compose", "--config", "supergraph.yaml"])
    print(result.stdout, end="")
```

## Publish to a ScorchQL gateway

Rover publishes a subgraph to GraphOS. seamstress publishes it to the registry of a [ScorchQL](ScorchQL) gateway. The graph ref is the URL of the gateway:

```bash
./seamstress subgraph publish http://my-vm:4000 --name products \\
    --schema products.graphql --routing-url http://10.0.0.5:4001/graphql
./seamstress subgraph list http://my-vm:4000
./seamstress subgraph delete http://my-vm:4000 --name products --confirm
```

The gateway composes the subgraphs again. When they do not compose, the gateway refuses the publish, and seamstress prints the errors with exit code 1. Use `--schema -` to read the SDL from standard input. Without `--schema`, the gateway reads the SDL from the routing URL. Without `--routing-url`, seamstress uses the URL that the gateway already has.

When the gateway has a token, set `APOLLO_KEY` or `SCORCHQL_TOKEN` to it. The messages and the JSON are the Rover ones.

## Supergraph configuration

The configuration is the Rover format. A subgraph source is `file`, `subgraph_url` with `introspection_headers`, or `sdl`. A file path is relative to the directory of the configuration. A JSON configuration is read too.

```yaml
federation_version: =2.3.0
subgraphs:
  products:
    routing_url: http://localhost:4001/graphql
    schema:
      file: ./products.graphql
  reviews:
    schema:
      subgraph_url: http://localhost:4002/graphql
      introspection_headers:
        Authorization: Bearer x
```

## Differences from Rover

- **Program name.** The program is `seamstress`. The usage errors and the suggestions say `seamstress` where Rover says `rover`.
- **Composition.** Rover composes with the `supergraph` plugin, which is Elastic licensed. `gql_seamstress` composes with `gql_composition`, the Hive Federation Composition port. The supergraph SDL and the error messages are the Hive ones, and there are no hints. The JSON output lists no plugins.
- **GraphOS.** A `graphref` source, `--graph-ref`, `--watch` and the commands that need GraphOS are not supported. `subgraph publish`, `delete` and `list` send to a ScorchQL gateway. The graph ref is the gateway URL, and a publish that does not compose is an error. `delete` needs `--confirm`.
- **Environment variables.** `${env.NAME}` in a configuration is not expanded. The Rover expansion code is Elastic licensed.
- **Configuration errors.** A configuration that cannot be read, or that does not match the format, is an error. Rover warns and continues with an empty configuration.
- **YAML.** Anchors, aliases, tags, flow collections with content and more than one document are refused. The messages are not the serde_yaml messages.
- **HTTP.** Requests use `gql_http`, so only `http` URLs work. A failed request is not retried. A response with the wrong shape is read leniently, where Rover reports a deserialization error.
- **Legacy introspection.** Rover 1.0.0 fails to convert every legacy introspection response, with ``missing field `isDeprecated` ``. `gql_seamstress` reads the legacy response, as the conversion intends.

Each module docstring lists its differences in full.

## Tests

The tests are in `tests/gql_seamstress/`. They port the tests of `apollo-federation-types` `src/config`, of the Rover compose output, of the federation version selection, of `rover-graphql` and of the introspection runner. `test_introspection_fixtures.mojo` ports the encoder and introspection JSON tests of `crates/rover-client/src/operations/graph/introspect/`, with the upstream SWAPI fixtures.

The fixtures are in `tests/gql_seamstress/fixtures/`, and `_fixture_data.mojo` holds them as Mojo code, because `make coverage` copies only Mojo files. After a change in `fixtures/`, run `.venv/bin/mojo run -I . tests/gql_seamstress/_embed.mojo`. The introspection suites run against a stub endpoint, and the output must equal what the Rover 1.0.0 program prints for the same endpoint. The compose suite composes the Hive fixtures from files, and the result must equal the Hive `composeServices` result.

## Benchmarks

`bench/gql_seamstress/` runs against Hive `composeServices` in `bench/baselines/js-seamstress/` and against the Rover 1.0.0 program in `bench/baselines/rust-seamstress/`. The Rover program cannot compose without the Elastic licensed plugin, so `supergraph compose` is compared with the composition library that `gql_seamstress` ports.

| Workload | What it times |
| --- | --- |
| `seamstress/supergraph-compose-stars-stuff` | `supergraph compose` of the five subgraph files of the Hive `stars-stuff` fixture, in process |
| `seamstress/graph-introspect-github` | One run of `seamstress graph introspect` of the GitHub schema, under the process driver |
| `seamstress/subgraph-introspect-catalog` | One run of `seamstress subgraph introspect` of a subgraph, under the process driver |
