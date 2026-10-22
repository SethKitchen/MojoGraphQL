<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Third-party notices

MojoGraphQL ports code from the open source projects below. Each project is
used under the MIT License, or under the MIT arm of a dual license. The
MojoGraphQL code is licensed under the terms in [LICENSE](LICENSE). Those
terms do not change your rights in the upstream projects. You can always use
the upstream projects directly, under their own licenses.

MojoGraphQL ports no code that is only Apache-2.0 licensed, and no code under
the Elastic License 2.0. The exclusions are listed with each project.

## Projects and pinned revisions

| Project | Repository | Pinned revision | License used | Copyright notice |
| --- | --- | --- | --- | --- |
| graphql-js | [graphql/graphql-js](https://github.com/graphql/graphql-js) | `v16.14.2` (`dca5b4d`) | MIT | Copyright (c) GraphQL Contributors |
| graphql-js 17 (incremental delivery) | [graphql/graphql-js](https://github.com/graphql/graphql-js), the files that the "graphql-js 17" section lists | `v17.0.2` (`71606d7`) | MIT | Copyright (c) GraphQL Contributors |
| graphql-subscriptions | [apollographql/graphql-subscriptions](https://github.com/apollographql/graphql-subscriptions) | `v3.0.0` (`d74107c`) | MIT | Copyright (c) 2015 - 2016 Meteor Development Group, Inc. |
| apollo-rs | [apollographql/apollo-rs](https://github.com/apollographql/apollo-rs) | `b7eee5c` | MIT (dual MIT OR Apache-2.0) | Copyright 2021 Apollo Graph, Inc. |
| @apollo/subgraph | [apollographql/federation](https://github.com/apollographql/federation), `subgraph-js/` only | `2.14.4` (`b95c124`) | MIT | Copyright (c) 2020- Apollo Graph, Inc.; Copyright (c) 2019-2020 Meteor Development Group, Inc. |
| Apollo Server | [apollographql/apollo-server](https://github.com/apollographql/apollo-server) | `5.5.1` (`0c22029`) | MIT | Copyright (c) 2016-2020 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.) |
| Apollo Client | [apollographql/apollo-client](https://github.com/apollographql/apollo-client) | `4.3.3` (`ae0dfce`) | MIT | Copyright (c) 2022 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.) |
| Apollo Kotlin | [apollographql/apollo-kotlin](https://github.com/apollographql/apollo-kotlin) | `afe947c` | MIT | Copyright (c) 2016-2024 Apollo Graph, Inc. (Formerly Meteor Development Group, Inc.) |
| Apollo MCP Server | [apollographql/apollo-mcp-server](https://github.com/apollographql/apollo-mcp-server) | `2.0.0` (`04e4e6e`) | MIT | Copyright (c) 2025 Apollo Graph, Inc. |
| apollo-federation-types | [apollographql/federation-rs](https://github.com/apollographql/federation-rs) | crate `0.18.0-rc.1` | MIT | Copyright (c) 2021 Apollo Graph, Inc. |
| Rover | [apollographql/rover](https://github.com/apollographql/rover) | `1.0.0` (`39a041a`) | MIT (the repository default) | Copyright (c) 2021 Apollo Graph, Inc. |
| Hive Federation Composition | [the-guild-org/federation](https://github.com/the-guild-org/federation) | `v0.27.0` (`6272ad8`) | MIT | Copyright (c) 2023 The Guild |
| Hive Router | [graphql-hive/router](https://github.com/graphql-hive/router) | `1a29df9` | MIT | Copyright (c) 2018 Dotan Simha <dotan@the-guild.dev> |
| graphql-go-tools | [wundergraph/graphql-go-tools](https://github.com/wundergraph/graphql-go-tools) | `9ef6e24` | MIT | Copyright (c) 2022 WunderGraph UG (haftungsbeschränkt) |
| Apollo Federation subgraph compatibility | [apollographql/apollo-federation-subgraph-compatibility](https://github.com/apollographql/apollo-federation-subgraph-compatibility) | `f9520a4` | MIT | Copyright (c) 2022 Apollo Graph |
| hyperium/h3 | [hyperium/h3](https://github.com/hyperium/h3), `h3/src/qpack`, `h3/src/proto` and `enable_extended_connect` of `h3/src/config.rs` only | `h3-v0.0.8` (`22c1aa3`) | MIT | Copyright (c) 2020 h3 authors |
| hyperium/h2 | [hyperium/h2](https://github.com/hyperium/h2), `src/hpack`, `src/frame`, `src/proto`, `src/server.rs`, `src/client.rs`, and the tests of `tests/h2-tests` and `src/hpack/test` | `v0.4.20` (`b0e8908`) | MIT | Copyright (c) 2017 h2 authors |
| quinn | [quinn-rs/quinn](https://github.com/quinn-rs/quinn), `quinn-proto/` (crate `0.11.19`) and the drivers of `quinn/` (crate `0.11.12`) only | `quinn-proto-0.11.19` (`8192ed3`) | MIT (dual MIT OR Apache-2.0) | Copyright (c) 2018 The quinn Developers |
| quinn-udp | [quinn-rs/quinn](https://github.com/quinn-rs/quinn), `quinn-udp/` (crate `0.5.16`) only | `quinn-proto-0.11.19` (`8192ed3`) | MIT (dual MIT OR Apache-2.0) | Copyright (c) 2018 The quinn Developers |
| tungstenite | [snapview/tungstenite-rs](https://github.com/snapview/tungstenite-rs), `src/protocol`, `src/handshake`, `src/utf8.rs`, `src/error.rs`, `src/client.rs`, `src/server.rs` and `tests/` | `v0.30.0` (`7f4aeaf`) | MIT (dual MIT OR Apache-2.0) | Copyright (c) 2017 Alexey Galakhov; Copyright (c) 2016 Jason Housley |
| graphql-ws | [enisdenjo/graphql-ws](https://github.com/enisdenjo/graphql-ws), `src/common.ts`, `src/utils.ts`, `src/server.ts`, `src/use/ws.ts`, `src/client.ts` and `tests/` | `v6.4.1` (`7281f1b`) | MIT | Copyright (c) 2020 Denis Badurina |
| graphql-sse | [enisdenjo/graphql-sse](https://github.com/enisdenjo/graphql-sse), `src/common.ts`, `src/parser.ts`, `src/handler.ts`, `tests/parser.test.ts` and `tests/handler.test.ts` | `v2.6.3` (`4cced455cb7a23beda9e9bf7a403aab270bd4e66`) | MIT | Copyright (c) 2021 Denis Badurina |

## Libraries loaded at run time

`gql_tls`, `gql_quic` and `gql_http3` load the OpenSSL 3 libraries of the
system, `libssl.so.3` and `libcrypto.so.3`, with `dlopen` at run time. They
call the public C API of OpenSSL: TLS, ALPN, the AEAD, header protection
and HKDF functions of libcrypto, the third-party QUIC TLS API of OpenSSL 3.5
(`SSL_set_quic_tls_cbs`), and the QUIC API of OpenSSL 3.5.
OpenSSL is Apache-2.0 licensed. MojoGraphQL ports no OpenSSL code, copies
none of its headers, and does not ship OpenSSL; the constants it uses are
the values of the public OpenSSL headers. A program that does not import
`gql_tls`, or a package that depends on it, such as `gql_https2` or
`gql_http3`, never loads OpenSSL.

## Exclusions

- **apollographql/federation.** Only `subgraph-js/` is MIT. The rest of the
  repository is Elastic License 2.0: `internals-js`, `composition-js`,
  `query-planner-js`, `query-graphs-js`, `gateway-js` and the others.
  MojoGraphQL ports none of it. `subgraph-js` imports
  `@apollo/federation-internals`. The port implements that logic from the
  public Apollo Federation specification and from Hive Federation
  Composition, never from `internals-js`.
- **apollo-rs.** The project is dual licensed MIT OR Apache-2.0. MojoGraphQL
  uses it under the MIT License only. `gql_compiler` ports these files of
  `crates/apollo-compiler` at `b7eee5c` (apollo-compiler 1.33.0):
  `src/schema/mod.rs`, `src/schema/component.rs`, `src/schema/from_ast.rs`,
  `src/executable/mod.rs`, `src/executable/from_ast.rs`,
  `src/schema/serialize.rs`, the type system part of `src/ast/serialize.rs`
  and `src/built_in_types.graphql`, and the tests of `tests/extensions.rs`,
  `tests/schema.rs` and `tests/executable.rs`. `tests/gql_compiler/serializer_fixtures/`
  copies the type system documents of `test_data/ok/` and
  `test_data/diagnostics/`, and their outputs in `test_data/serializer/`.
  The validation ports `src/schema/validation.rs`,
  `src/executable/validation.rs`, `src/validation/mod.rs`,
  `src/validation/diagnostics.rs` and the other files of
  `src/validation/`, and the tests of `tests/validation/` and of
  `validation` in `tests/snapshot_tests.rs`.
  `tests/gql_compiler/validation_fixtures/` copies the `.graphql` files of
  `test_data/ok/`, and the `.graphql` and `.txt` files of
  `test_data/diagnostics/`. The recovering parser of `gql_compiler` ports
  these files of `crates/apollo-parser` at `b7eee5c` (apollo-parser
  0.8.6): `src/lexer/mod.rs`, `src/lexer/cursor.rs`, `src/lexer/lookup.rs`,
  `src/lexer/token_kind.rs`, `src/error.rs`, `src/limit.rs`,
  `src/parser/mod.rs` and every file of `src/parser/grammar/`, with the
  rules of apollo-compiler `src/ast/from_cst.rs`. It ports the tests of
  `src/tests.rs`, `src/lexer/mod.rs` and `src/parser/mod.rs`.
  `tests/gql_compiler/parser_fixtures/` copies the `.graphql` and `.txt`
  files of `test_data/lexer/err/` and `test_data/parser/err/`. The concrete
  syntax tree files (`src/cst/`, `src/parser/generated/`,
  `src/parser/syntax_tree.rs`, `src/parser/language.rs` and
  `src/parser/token_text.rs`) are not ported.
- **Apollo Kotlin.** These files are Apache-2.0 licensed and are not ported:
  - `libraries/apollo-api/src/commonMain/kotlin/com/apollographql/apollo/api/json/JsonReader.kt`
  - `libraries/apollo-api/src/commonMain/kotlin/com/apollographql/apollo/api/json/JsonWriter.kt`
  - `libraries/apollo-api/src/commonMain/kotlin/com/apollographql/apollo/api/json/BufferedSinkJsonWriter.kt`
  - `libraries/apollo-api/src/commonMain/kotlin/com/apollographql/apollo/api/json/BufferedSourceJsonReader.kt`
  - `libraries/apollo-api/src/commonMain/kotlin/com/apollographql/apollo/api/json/internal/JsonScope.kt`
  - `libraries/apollo-http-cache/src/main/kotlin/com/apollographql/apollo/cache/http/internal/DiskLruCache.kt`
  - `libraries/apollo-http-cache/src/main/kotlin/com/apollographql/apollo/cache/http/internal/FaultHidingSink.kt`
  - `libraries/apollo-runtime/src/commonMain/kotlin/com/apollographql/apollo/internal/MultipartReader.kt`
- **Rover.** The repository default is MIT, and some parts are Elastic
  License 2.0 by a file header or a subdirectory license. MojoGraphQL ports
  only the MIT parts. `gql_seamstress` ports these parts of `39a041a`:
  `src/cli.rs`, `src/command/supergraph/compose/`,
  `src/composition/supergraph/config/` (the subgraph resolution),
  `src/command/subgraph/introspect.rs`, `src/command/graph/introspect.rs`,
  `src/command/output.rs`, `src/options/output.rs`, `src/error/`,
  `src/federation.rs`, `src/utils/parsers.rs`, the
  `crates/rover-client/src/operations/subgraph/introspect/` and
  `graph/introspect/` operations, and `crates/rover-graphql/src/lib.rs`.
  The tests of `tests/gql_seamstress/` port the tests of those files.
  `tests/gql_seamstress/fixtures/` copies the MIT test data of
  `crates/rover-client/src/operations/graph/introspect/fixtures/`.
  These parts are excluded:
  - `src/utils/expansion.rs`, which is Elastic License 2.0 by its file
    header. `gql_seamstress` does not expand environment variables in a
    supergraph configuration.
  - The `supergraph` and `router` plugin binaries that Rover downloads,
    which are Elastic License 2.0. `gql_seamstress` composes with
    `gql_composition`, and never runs the `supergraph` binary.
  - The commands that need GraphOS, and `rover dev`.
- **apollo-federation-types and apollo-compiler.** `gql_seamstress` also
  ports `src/config/` and `src/rover/` of apollo-federation-types `0.18.0-rc.1`
  (MIT), and `src/ast/serialize.rs` and the built-in introspection types of
  apollo-compiler `1.33.0` (the MIT arm of MIT OR Apache-2.0). The default
  license of the federation-rs repository is Elastic License 2.0. A
  subdirectory can set another license, and `apollo-federation-types/Cargo.toml`
  sets `license = "MIT"`. The crate is published as MIT. MojoGraphQL ports no
  other part of federation-rs.
- **Hive Router.** `apollo-router-workspace/` is a plugin for Apollo Router,
  which is Elastic License 2.0. MojoGraphQL does not port it. `gql_router`
  ports these MIT parts of `1a29df9`: the query planner of
  `bin/router/src/query_planner/` (`ast/`, `federation_spec/`, `graph/`,
  `planner/`, `state/` and `utils/`), and its tests in `tests/` with the
  supergraph fixtures of `bin/router/fixture/` and `bench/`; `cache_state.rs`
  and `config/cache.rs`; `http_utils/headers.rs`; `pipeline/authorization/`;
  and `executor/operation_filter.rs`. It also ports the executor of
  `bin/router/src/executor/` (`execution/`, `projection/`, `variables/`,
  `response/`, `utils/traverse.rs`, `introspection/` and
  `executors/http.rs`) with the tests of `variables/tests/`,
  `projection/`, `response/`, `utils/traverse.rs` and `execution/plan.rs`,
  `query_planner/consumer_schema/`, and these files of
  `bin/router/src/pipeline/`: `mod.rs`, `parser.rs`, `normalize.rs`,
  `coerce_variables.rs`, `query_plan.rs`, `execution.rs`, `error.rs`,
  `execution_request.rs`, `header.rs` and `validation/mod.rs`; and
  `http_utils/probes.rs`. From the MIT crate `lib/graphql-tools/` it
  ports the rule list of `src/validation/rules/defaults.rs`, and the
  error codes, messages and locations of the rules in
  `src/validation/rules/`; the checks are those of `gql_validation`. The
  rules `max_depth`, `max_directives` and `max_aliases` of
  `pipeline/validation/` are not ported. The executor plugins,
  extensions, header propagation, error masking and operation name
  forwarding are not ported. `gql_router_stream` ports the streaming parts
  of `1a29df9`: `config/subscriptions.rs`, `config/websocket.rs`, the
  WebSocket fields of `config/traffic_shaping.rs`, the response modes of
  `pipeline/header.rs`, `pipeline/sse.rs`, `pipeline/multipart_subscribe.rs`,
  `pipeline/websocket_server.rs`, `executor/executors/sse.rs`,
  `multipart_subscribe.rs`, `websocket_pool.rs`, `websocket_client.rs` and
  the subscribe part of `http.rs`, the subscription part of
  `executor/execution/plan.rs`, and the cases of `e2e/src/subscriptions.rs`,
  `websocket.rs` and `websocket_pool.rs`, with `e2e/supergraph.graphql`. It
  also ports the `Accept` parser of headers-accept `0.3.0` (MIT), which
  upstream calls. The HTTP callback protocol of subscriptions is not
  ported. The benchmark baseline makes the upstream
  `execute_query_plan_with_data` public, and changes nothing else. Of the
  planner tests, `generated.rs`
  is excluded, because it needs the generator of `bin/differential`, and
  `preparing_a_plan_preserves_its_wire_form` of `tests/mod.rs` is excluded,
  because the port has no JSON form of a plan.
- **Apollo Server.** `gql_server` ports these MIT files of `5.5.1`
  (`0c22029`) for inline traces: `packages/server/src/plugin/inlineTrace/index.ts`,
  `plugin/traceTreeBuilder.ts`, `plugin/schemaIsSubgraph.ts`, the inline
  trace part of `plugin/disabled/index.ts`, and the `Trace` message of
  `packages/usage-reporting-protobuf/src/reports.proto`. Its tests port
  `src/__tests__/plugin/inlineTrace/inlineTracePlugin.test.ts` and the
  `Federated tracing` cases of
  `packages/integration-testsuite/src/apolloServerTests.ts`. The usage
  reporting plugin and the rest of `reports.proto` are not ported.
  For incremental delivery, `gql_server` ports
  `src/incrementalDeliveryPolyfill.ts`, the subsequent results part of
  `requestPipeline.ts` and `writeMultipartBody` of `runHttpQuery.ts`; its
  tests port `describe('tests that require graphql@17')` of
  `packages/integration-testsuite/src/httpServerTests.ts`. It does not port
  `legacyExperimentalExecuteIncrementally`. `gql_server_ws` ports the
  setup of `docs/source/data/subscriptions.mdx` and
  `src/plugin/drainHttpServer/index.ts`. It does not port
  `src/plugin/subscriptionCallback/`.
- **Apollo Client.** `src/react/internal/compiler-runtime/` is a separate MIT
  notice from Meta Platforms, Inc. MojoGraphQL ports no React code, so it
  does not port that directory. `gql_client` ports these MIT files of
  `4.3.3` (`ae0dfce`): `src/cache/inmemory/inMemoryCache.ts`,
  `entityStore.ts`, `writeToStore.ts`, `readFromStore.ts`, `policies.ts`,
  `helpers.ts` and `key-extractor.ts`; the cache methods of
  `src/cache/core/cache.ts` and `MissingFieldError` of
  `src/cache/core/types/common.ts`; and of `src/utilities`:
  `canonicalStringify.ts`, `DeepMerger.ts`, `getStoreKeyName.ts`,
  `storeKeyNameFromField.ts`, `valueToObjectRepresentation.ts`,
  `argumentsObjectFromField.ts`, `shouldInclude.ts`, `checkDocument.ts`,
  `getFragmentQueryDocument.ts`, `getOperationDefinition.ts` and
  `addTypenameToDocument` of `graphql/transform.ts`. It does not port
  `fragmentRegistry.ts`, `reactiveVars.ts`, `src/cache/core/Scalar.ts`, the
  watch and broadcast parts of `inMemoryCache.ts`, or anything outside
  `src/cache` and those utilities. For incremental delivery and
  subscriptions, `gql_client` also ports `src/incremental/handlers/`
  (`graphql17Alpha9.ts`, `defer20220824.ts`), and of
  `src/utilities/internal`: `makeStreamInfoTrie.ts`, `StreamArrayState.ts`,
  `addDeferFragmentLabels.ts`, `hasDirectives.ts`, `isStreamField.ts`, the
  `truncate` and `atPath` options of `DeepMerger.ts`, and the stream parts
  of `policies.ts` and `writeToStore.ts` (`defaultStreamFieldMergeFn`,
  `streamFieldInfo`, `existingData`, `extensions`). It ports
  `markQueryResult`, `markSubscriptionResult` and `shouldWriteResult` of
  `src/core/QueryInfo.ts`, and the result mapping of
  `startGraphQLSubscription` of `src/core/QueryManager.ts`. It does not
  port the rest of `src/core`, `src/masking`, `notImplemented.ts`, or the
  incremental reads of `readFromStore.ts` (`deferInfo`,
  `prunePartialBoundaries`). `gql_client_http` ports
  `src/link/http/parseAndCheckHttpResponse.ts`, and no other file of
  `src/link`. The tests of both packages port the upstream tests named in
  their module docstrings; the payloads and results of the handler tests
  were recorded by running those upstream tests with the npm packages
  `graphql` `17.0.0-alpha.2` and `17.0.0-alpha.9` (MIT), which are not part
  of any MojoGraphQL package.
- **Hive Federation Composition.** `gql_composition` ports these MIT files
  of `v0.27.0` (`6272ad8`): `src/validate.ts` (the subgraph phase),
  `src/specifications/` (`federation.ts`, `link.ts`, `tag.ts`,
  `inaccessible.ts`, `authenticated.ts`, `policy.ts`, `requires-scopes.ts`,
  `cost.ts`, `context.ts`), `src/subgraph/` (`state.ts`, `helpers.ts`,
  `context.ts`, `validation/validate-subgraph.ts`,
  `validation/validate-state.ts`, `validation/validation-context.ts`, and
  every file of `validation/rules/` and `validation/rules/elements/`),
  `src/graphql/printer.ts`, `src/graphql/type-node-info.ts`,
  `moveSchemaAndDirectiveDefinitionsToTop` of `src/graphql/helpers.ts`,
  `src/utils/auth.ts`, `src/utils/format.ts`, `src/utils/state.ts` and
  `src/utils/version.ts`, and `constantCase` of the `constant-case` package
  (MIT). It does not yet port `src/compose.ts`, `src/supergraph/`,
  `src/contracts/`, `src/specifications/join.ts`, or the other files of
  `src/graphql/` and `src/utils/`. The federation versions `v2.10` to
  `v2.15` come from the public Apollo GraphOS documentation, not from code.

- **quinn and quinn-udp.** The repository is dual licensed MIT OR
  Apache-2.0 (`LICENSE-MIT` and `LICENSE-APACHE`). MojoGraphQL uses it under
  the MIT License only. `gql_quic` ports these files of quinn-proto `0.11.19`
  (`8192ed3`): `src/packet.rs`, `src/frame.rs`, `src/varint.rs`,
  `src/coding.rs`, `src/transport_parameters.rs`, `src/transport_error.rs`,
  `src/shared.rs`, `src/lib.rs` (`Side`, `Dir`, `StreamId`),
  `src/cid_generator.rs`, `src/token.rs` (`ResetToken`),
  `src/range_set/array_range_set.rs`, `src/crypto.rs`,
  `src/crypto/rustls.rs` (`initial_keys` and the role of `TlsSession`),
  `src/connection/mod.rs`, `src/connection/spaces.rs`,
  `src/connection/assembler.rs`, `src/connection/send_buffer.rs`,
  `src/connection/streams/` (`state.rs`, `send.rs`, `recv.rs`),
  `src/connection/paths.rs` (`RttEstimator`),
  `src/congestion/new_reno.rs`, `src/endpoint.rs`, and the tests of
  `src/tests/` and `src/range_set/tests.rs`. It ports the role of
  `quinn/src/endpoint.rs` and `quinn/src/connection.rs` of quinn `0.11.12`,
  with the tests of `quinn/src/tests.rs`. It ports the batched receive and
  the GSO send of `quinn-udp/src/unix.rs` of quinn-udp `0.5.16`, with the
  tests of `quinn-udp/tests/tests.rs`. It does not port Cubic, BBR (whose
  `min_max.rs` is based on BSD licensed Google code), the rustls and ring
  providers, the hashed connection ID generator, Retry tokens, path
  migration, MTU discovery, or the Windows and Apple code of quinn-udp.
- **graphql-go-tools (gql_normalization).** `gql_normalization` ports files
  of `v2/pkg` at `9ef6e24` (2026-10-14), with their tests. It ports
  the operation stages of `astnormalization/astnormalization.go` and these
  passes: `directive_include_skip.go`,
  `fragment_spread_inlining.go`, `inline_selections_from_inline_fragments.go`,
  `inline_fragment_selection_merging.go`, `field_deduplication.go`,
  `remove_self_aliasing.go`, `fragment_definition_removal.go`,
  `operation_definition_removal.go`, `variables_extraction.go`,
  `variables_default_value_extraction.go`, `variables_unused_deletion.go`,
  `inject_input_default_values.go` and `input_coercion_for_list.go`.
  It ports `astminify/minify.go` with its fixtures and goldens, and the
  executable document part of `astprinter/astprinter.go`. It ports
  `variablesvalidation/variablesvalidation.go`. It also ports
  `MergeFieldsDefer`, `ValueToJSON` and the type relations of `ast`. It
  ports the definition normalization (`definition_normalization.go`, the
  `*_type_extending.go` files, `extends_directive.go`, `implicit_*.go`,
  `remove_type_extensions.go`, `subgraph_sdl_normalization.go`), the
  `@defer` stages (`defer_*.go`), the prevalidation rules,
  `inline_arguments.go`, `fragmentspread_depth.go`, `uploads/`,
  `abstract_field_normalizer.go`, `variables_mapper.go` and
  `variables_mapping.go`.
  The parser, the printer for SDL, the validation (`astvalidation`) and
  the `engine` of graphql-go-tools are not ported: `gql_language`,
  `gql_validation` and `gql_router` do that work.
- **tungstenite (gql_ws).** The project is dual licensed MIT OR
  Apache-2.0. MojoGraphQL uses it under the MIT License only. `src/tls.rs`,
  `src/stream.rs`, `src/buffer.rs`, the `url` feature, `autobahn/`,
  `benches/`, `examples/` and `fuzz/` are not ported. The Autobahn
  testsuite needs Docker or Python 2; its cases of sections 1 to 7 are tests
  in `tests/gql_ws/`.
- **WebSockets over HTTP/2 and HTTP/3 (gql_ws_http2, gql_ws_http3).** No
  code is ported except the extended `CONNECT` of h2 v0.4.20 (in
  `gql_http2`), and `enable_extended_connect` of `h3/src/config.rs` and
  the `:protocol` rules of `h3/src/proto/headers.rs` of hyperium/h3
  h3-v0.0.8 (in `gql_ws_http3`). The rest follows RFC 8441 and RFC 9220:
  the tunnel events of `gql_http3`, the QUIC server, client and fallback
  of `gql_ws_http3`, and the idle sweep of `gql_ws_http2` port no code.
  The WebTransport and datagram crates of hyperium/h3 are not ported.
  `gql_ws_http3` has no benchmark baseline: h3 `0.0.8` refuses
  `:protocol websocket` (`h3/src/ext.rs`).
- **graphql-ws (gql_ws, gql_ws_execution).** The adapters of `src/use/`
  other than `ws.ts` (`bun`, `deno`, `fastify-websocket`, `uWebSockets`,
  `crossws`), the deprecated `subscriptions-transport-ws` protocol, the
  JSON reviver and replacer, and the lazy and retrying parts of
  `src/client.ts` are not ported.
- **graphql-sse (gql_sse, gql_sse_execution).** `src/client.ts`, the
  adapters of `src/use/` (`http`, `http2`, `express`, `fastify`, `koa`)
  and the `onConnect`, `onSubscribe`, `onOperation`, `onNext` and
  `onComplete` hooks as separate functions are not ported. `prepare` is
  one `SseExecutor.prepare`.

## graphql-js 17

`gql_execution` and `gql_validation` port these files of graphql-js
`v17.0.2` (`71606d736c79b77588a15b32b9c9497e397adae0`), under the
MIT License. Everything else of graphql-js comes from `v16.14.2`.

- `gql_execution`: `experimentalExecuteIncrementally` of
  `src/execution/execute.ts`; the `@defer` part of
  `src/execution/collectFields.ts`; `src/execution/getStreamUsage.ts`;
  `src/execution/incremental/IncrementalExecutor.ts`,
  `IncrementalPublisher.ts`, `WorkQueue.ts` and `buildExecutionPlan.ts`;
  the `CollectedErrors.hasNulledPosition` and the stream path of
  `completeListValue` of `src/execution/Executor.ts`; the `@defer` and
  `@stream` definitions of `src/type/directives.ts`; the `abortSignal` and
  `enableEarlyExecution` of `ExecutionArgs`; and the tests of
  `src/execution/incremental/__tests__/defer-test.ts` and `stream-test.ts`.
- `gql_validation`: `src/validation/rules/DeferStreamDirectiveLabelRule.ts`,
  `DeferStreamDirectiveOnRootFieldRule.ts`,
  `DeferStreamDirectiveOnValidOperationsRule.ts` and
  `StreamDirectiveOnListFieldRule.ts`, their tests in
  `src/validation/__tests__/`, and the `testSchema` of
  `src/validation/__tests__/harness.ts`.
- Not ported: `src/execution/incremental/Queue.ts` and `Computation.ts`,
  which hold promises; `src/execution/legacyIncremental/` and its tests;
  and the tests of `Queue-test.ts`, `WorkQueue-test.ts` and
  `Computation-test.ts`.

## Benchmark baselines and fixtures

- `bench/fixtures/kitchen-sink.graphql` and
  `bench/fixtures/github-schema.graphql` are copied from the graphql-js
  `v16.14.2` `benchmark/` directory. They are MIT licensed, Copyright (c)
  GraphQL Contributors.
- `bench/fixtures/github-query.graphql` is MojoGraphQL's own file, under the
  license of this repository.
- `bench/baselines/js/` installs the `graphql` npm package, version
  `16.14.2`, which is graphql-js. It runs only as a benchmark baseline and is
  not part of any MojoGraphQL package.
- `bench/baselines/js-stream/` installs the npm packages `graphql`
  `16.14.2` (MIT) and `graphql-subscriptions` `3.0.0` (MIT). They run only
  as the benchmark baseline of `gql_stream` and of the subscriptions of
  `gql_execution`, and are not part of any MojoGraphQL package.
- `bench/baselines/js-incremental/` installs the npm package `graphql`
  `17.0.2` (MIT). It runs only as the benchmark baseline of
  `@defer` and `@stream` in `gql_execution`, and is not part of any
  MojoGraphQL package.
- `bench/baselines/js-ws/` installs the npm packages `ws` `8.18.3` (MIT),
  `graphql-ws` `6.4.1` (MIT), `graphql` `16.14.2` (MIT) and
  `graphql-subscriptions` `3.0.0` (MIT). They run only as the benchmark
  baseline of `gql_ws`, and are not part of any MojoGraphQL package.
- `bench/baselines/js-sse/` installs the npm packages `graphql-sse`
  `2.6.3` (MIT), `graphql` `16.14.2` (MIT) and `meros` `1.3.2` (MIT,
  Copyright (c) Marais Rossouw). They run only as the benchmark baseline
  of `gql_sse` and of the multipart decoder of `gql_http`, and are not part
  of any MojoGraphQL package. No meros code is ported.
- `bench/baselines/rust-ws/` builds the crates `tungstenite` `0.30.0` and
  `tokio-tungstenite` `0.30.0` (MIT OR Apache-2.0, used under MIT), `tokio`
  and `futures-util` (MIT). They run only as the benchmark baseline of
  `gql_ws`, and are not part of any MojoGraphQL package.
- `bench/baselines/rust-ws_http2/` builds the crates `h2` `0.4.20` (MIT),
  `tungstenite` `0.30.0` (MIT OR Apache-2.0, used under MIT), `tokio`,
  `http` and `bytes` (MIT). They run only as the benchmark baseline of
  `gql_ws_http2`, and are not part of any MojoGraphQL package.
- `bench/baselines/js-client/` installs the npm packages `@apollo/client`
  `4.3.3` (MIT), `graphql` `16.14.2` (MIT) and its peer dependency `rxjs`
  `7.8.2` (Apache-2.0). They run only as the benchmark baseline of
  `gql_client` and are not part of any MojoGraphQL package; no `rxjs` code
  is ported. `bench/fixtures/client-items-1000.json` is MojoGraphQL's own
  file.
- `bench/gql_validation/apollo_compiler.mojo` and the baselines build the
  documents of the apollo-compiler 1.33.0 benchmarks
  `benches/fields_validation.rs`, `benches/fragments_validation.rs` and
  `benches/directives_validation.rs` with the same steps. apollo-rs is used
  under the MIT License. `gql_validation` ports graphql-js `v16.14.2`
  `src/validation` and `src/utilities/TypeInfo.ts`.
- `bench/fixtures/hive-huge-schema/` and `bench/fixtures/hive-dgs/` are
  byte-for-byte copies of `__tests__/fixtures/huge-schema/*.graphql` and
  `__tests__/fixtures/dgs/*.graphql` of Hive Federation Composition
  `v0.27.0` (`6272ad8`). `bench/fixtures/hive-stars-stuff/` holds the
  string literals of `__tests__/fixtures/stars-stuff.ts`, and
  `bench/fixtures/hive-basic/` the string literals of `basicServices` in
  `benchmark.ts`, one file per subgraph. They are MIT licensed, Copyright
  (c) 2023 The Guild.
- `bench/baselines/js-composition/` installs the npm packages
  `@theguild/federation-composition` `0.27.0` (MIT) and `graphql` `16.14.2`
  (MIT). They run only as the benchmark baseline of `gql_composition` and
  are not part of any MojoGraphQL package.
- `bench/baselines/kotlin-codegen/` resolves the Maven artifact
  `com.apollographql.apollo:apollo-compiler` `5.2.0` (MIT, Apollo Kotlin)
  and its dependencies with Gradle. It runs only as the benchmark baseline
  of `gql_codegen` and is not part of any MojoGraphQL package.
  `gql_codegen` ports `libraries/apollo-compiler` and parts of
  `libraries/apollo-ast` of Apollo Kotlin at `afe947c`; it ports none of the
  Apache-2.0 files listed in [Exclusions](#exclusions).
- `bench/baselines/rust-tls/` runs hyper `1` (MIT) with tokio-rustls `0.26`
  and rustls `0.23` (the MIT arm of MIT OR Apache-2.0) over TLS, with the
  test certificate of `bench/fixtures/tls/`. Its `hyper-rustls-h2` program
  also runs h2 `0.4.20` (MIT) after ALPN `h2`. It runs only as the benchmark
  baseline of `gql_tls` and `gql_https2`.
- `bench/baselines/rust-http3/` runs the QPACK coder of hyperium/h3
  `h3-v0.0.8` (MIT), which `build.sh` fetches at the pinned revision, and an
  HTTP/3 round trip with the published crates h3 `0.0.8` and h3-quinn
  `0.0.10` (MIT), quinn `0.11` and rustls `0.23` with ring (the MIT arm of
  MIT OR Apache-2.0), and rcgen `0.13` (the MIT arm of MIT OR Apache-2.0).
  It runs only as a benchmark baseline.
- `bench/baselines/rust-quic/` runs the published crates quinn-proto
  `0.11.19` and quinn `0.11.12` (the MIT arm of MIT OR Apache-2.0) on tokio
  (MIT), with rustls `0.23` and ring and rcgen `0.13` (the MIT arm of MIT OR
  Apache-2.0). `quic-stream` drives quinn-proto in memory, and `quic-echo`
  runs quinn over localhost UDP. Its `h3-interop-server` and
  `h3-interop-client` programs use h3 `0.0.8` and h3-quinn `0.0.10` (MIT),
  and are test peers. It runs only as the benchmark baseline of `gql_quic`.
- `bench/baselines/rust-http2/` runs hyper `1.12.0` (MIT) with h2 `0.4.20`
  (MIT) on tokio (MIT). h2 keeps its HPACK coder private, so `build.rs`
  compiles the `src/hpack` and `src/ext.rs` files of the h2 `0.4.20` crate
  from the cargo registry into the program. No h2 file is copied into the
  repository. It runs only as the benchmark baseline of `gql_http2`.
- `bench/baselines/go-normalization/` runs graphql-go-tools v2 at `9ef6e24`
  (MIT), with sjson pinned to `v1.0.4` (MIT) as the `go.work` of
  graphql-go-tools pins it. It runs only as the benchmark baseline of
  `gql_normalization`. `bench/gql_normalization/normalization.mojo` and
  its `fixtures.go` copy `testDefinition` and `testOperation` of
  `v2/pkg/astnormalization/astnormalization_test.go`.
  `bench/fixtures/go-tools-minify-operation1.graphql` and
  `bench/fixtures/go-tools-minify-simpleschema.graphql` are copies of
  `v2/pkg/astminify/operation1.graphql` and `simpleschema.graphql`. They
  are MIT licensed, Copyright (c) 2022 WunderGraph UG
  (haftungsbeschränkt).

## Test fixtures

- The hpack-test-case corpus that h2 `v0.4.20` bundles in
  `fixtures/hpack` has no license file, so it is excluded: no file of it is
  in the repository. `tests/gql_http2/test_hpack_corpus.mojo` reads it at run
  time from a local clone of h2, `~/mgql-upstream/hyperium_h2`, and passes
  at once when the clone is absent.
- `tests/gql_json/fixtures/test_parsing/` is a byte-for-byte copy of the
  `y_`, `n_` and `i_` files of the JSONTestSuite
  ([nst/JSONTestSuite](https://github.com/nst/JSONTestSuite)), revision
  `1ef36fa` (2024-11-22). It is MIT licensed, Copyright (c) 2016 Nicolas
  Seriot. The license text is in `tests/gql_json/fixtures/test_parsing/LICENSE`.
  The files are test data only, and no MojoGraphQL package contains them.
- `tests/gql_codegen/fixtures/` holds copies of Apollo Kotlin (`afe947c`)
  test files: `TestOperation.graphql`, `schema.graphqls` and
  `used-coordinates.json.expected` of
  `libraries/apollo-compiler/src/test/graphql/com/example/`, the shared
  `src/test/graphql/schema.graphqls`, the fixtures of
  `src/test/validation/operation/capitalized_fields/`, and the top-level
  fixtures of `libraries/apollo-ast/test-fixtures/validation/executable/`.
  `operation_ids.tsv` holds the `OPERATION_ID` and `OPERATION_DOCUMENT` of
  the expected `operationBased` outputs. They are MIT licensed, Copyright
  (c) 2016-2024 Apollo Graph, Inc. `fixtures/golden/` is MojoGraphQL's own.
  `_fixture_data.mojo` holds the same files as Mojo code. The files are test
  data only, and no MojoGraphQL package contains them.
- `tests/gql_subgraph/_products.mojo` holds the `products` schema of the
  Apollo Federation subgraph compatibility suite
  ([apollographql/apollo-federation-subgraph-compatibility](https://github.com/apollographql/apollo-federation-subgraph-compatibility)),
  revision `f9520a4`: `implementations/apollo-server/products.graphql`, with
  the data and the resolvers of `implementations/apollo-server/index.js`.
  `tests/gql_subgraph/test_compatibility.mojo` and `_compat.mojo` port the
  jest tests of `packages/compatibility/src/tests/` and `compareSchemas` of
  `packages/compatibility/src/utils/schemaComparison.ts`.
  `bench/compat/products.mojo` serves the schema. The suite is MIT licensed,
  Copyright (c) 2022 Apollo Graph. The files are test data and an example
  program only, and no MojoGraphQL package contains them. `ftv1.test.ts`,
  the router, the `users` and `inventory` subgraphs and the Docker and
  `rover` tooling are not ported.
- `tests/gql_normalization/` ports the tests of graphql-go-tools v2 at
  `9ef6e24`: the `*_test.go` files of `v2/pkg/astnormalization` that the
  ported passes have, `v2/pkg/astminify/minify_test.go` and
  `v2/pkg/variablesvalidation/variablesvalidation_test.go`.
  `_norm_fixtures.mojo` and `_minify_fixtures.mojo` embed their schemas,
  operations and `.min.graphql.golden` files. Three schemas change: the
  duplicate `ComplexInput` of `variablesDefaultValueExtractionDefinition` is
  left out, and `sameVariableExtraction` gets the `FooInput` that it uses.
  The definition of `TestVariablesMapper` gets `scalar Upload`.
  They are MIT licensed, Copyright (c) 2022 WunderGraph UG
  (haftungsbeschränkt). The files are test data only.

## MIT License

Each project above is distributed under this license text, with its own
copyright notice from the table in place of the copyright line.

```text
MIT License

Copyright (c) <the copyright notice of the project, from the table above>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Updating a pin

When a port moves to a new upstream revision, update the revision in this
file and in the `upstream` key of the package in `packages.toml`. Read the
upstream license files again at the new revision. A license can change
between revisions.
