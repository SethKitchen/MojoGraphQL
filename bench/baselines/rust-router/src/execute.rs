// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

//! The `hive-router/execute` workload: one upstream `execute_query_plan`
//! call for `TestQuery`, with every subgraph answered in-process.
//!
//! Upstream has no public way to put a custom executor into
//! `SubgraphExecutorMap`. This module uses the plugin system instead. The
//! map is built with `SubgraphExecutorMap::from_http_endpoint_map` and dummy
//! URLs that are never contacted. A plugin, `CannedPlugin`, replaces the
//! `executor` of each `on_subgraph_execute` payload with a `CannedExecutor`
//! for that subgraph. The map then runs the replaced executor through its
//! normal path (timeout and circuit breaker lookup, end hooks).
//!
//! `CannedExecutor::execute` does what `HTTPSubgraphExecutor::execute` does
//! around the network call: it builds the request body with the upstream
//! `build_request_body`, and it turns the response bytes into a
//! `SubgraphResponse` with `SubgraphResponse::deserialize_from_bytes`, with
//! status 200 and a `content-type: application/json` header map. The
//! response bytes are looked up by the query string of the request. When a
//! subgraph has more than one recorded response for one query string, the
//! `variables` member of the built body selects the response.
//!
//! The canned responses are `bench/fixtures/hive-router-exec/responses.json`.
//! `--record` regenerates it from the real upstream bench subgraphs (see
//! `record` in this module).

use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use bytes::Bytes;
use futures::stream::BoxStream;
use hive_router::executor::execution::client_request_details::{
    ClientRequestDetails, JwtRequestDetails, OperationDetails,
};
use hive_router::executor::execution::error_masking::ErrorMaskingRuntime;
use hive_router::executor::execution::operation_name::{
    OperationNameFactory, OperationNameForwardConfig,
};
use hive_router::executor::execution::plan::{
    execute_query_plan, CoerceVariablesPayload, ExecutionResultExtensions, QueryPlanExecutionOpts,
    QueryPlanExecutionResult,
};
use hive_router::executor::executors::common::{
    SubgraphExecutionRequest, SubgraphExecutor, SubgraphExecutorBoxedArc,
};
use hive_router::executor::executors::error::SubgraphExecutorError;
use hive_router::executor::executors::http::build_request_body;
use hive_router::executor::executors::map::SubgraphExecutorMap;
use hive_router::executor::extensions::plan::ExtensionsPlan;
use hive_router::executor::headers::plan::HeaderRulesPlan;
use hive_router::executor::headers::response::ResponseHeaderSink;
use hive_router::executor::hooks::on_plugin_init::{OnPluginInitPayload, OnPluginInitResult};
use hive_router::executor::hooks::on_subgraph_execute::{
    OnSubgraphExecuteStartHookPayload, OnSubgraphExecuteStartHookResult,
};
use hive_router::executor::introspection::partition::partition_operation;
use hive_router::executor::introspection::resolve::IntrospectionContext;
use hive_router::executor::introspection::schema::SchemaWithMetadata;
use hive_router::executor::plugin_context::{PluginContext, PluginRequestState, RouterHttpRequest};
use hive_router::executor::plugin_trait::{RouterPlugin, RouterPluginBoxed, StartHookPayload};
use hive_router::executor::projection::plan::ProjectionPlan;
use hive_router::executor::request_context::SharedRequestContext;
use hive_router::executor::response::subgraph_response::SubgraphResponse;
use hive_router::http;
use hive_router::ntex;
use hive_router::query_planner::ast::normalization::normalize_operation;
use hive_router::query_planner::ast::operation::OperationDefinition;
use hive_router::query_planner::graph::PlannerOverrideContext;
use hive_router::query_planner::planner::plan_nodes::QueryPlan;
use hive_router::query_planner::planner::Planner;
use hive_router::query_planner::state::supergraph_state::OperationKind;
use hive_router::query_planner::utils::cancellation::CancellationToken;
use hive_router::query_planner::utils::parsing::{parse_operation, parse_schema};
use hive_router::sonic_rs::{self, JsonValueTrait};
use hive_router::telemetry::traces::spans::graphql::GraphQLOperationSpan;
use hive_router::telemetry::TelemetryContext;

use crate::fixture;

/// The operation name of upstream `bench/operation.graphql`.
const OPERATION_NAME: &str = "TestQuery";
/// The canned subgraph responses.
pub const RESPONSES: &str = "hive-router-exec/responses.json";
/// The response that the canned execution produces, byte for byte.
pub const EXPECTED: &str = "hive-router-exec/expected_response.json";

/// One canned response of one subgraph.
struct Canned {
    variables: sonic_rs::Value,
    bytes: Bytes,
}

/// A `SubgraphExecutor` that answers one subgraph from canned bytes.
struct CannedExecutor {
    endpoint: http::Uri,
    headers: Arc<http::HeaderMap>,
    by_query: HashMap<String, Vec<Canned>>,
}

impl CannedExecutor {
    fn lookup(&self, request: &SubgraphExecutionRequest<'_>, body: &[u8]) -> Bytes {
        let candidates = self
            .by_query
            .get(request.query)
            .unwrap_or_else(|| panic!("no canned response for query {}", request.query));
        if candidates.len() == 1 {
            return candidates[0].bytes.clone();
        }
        let sent: sonic_rs::Value = sonic_rs::from_slice(body).expect("request body is JSON");
        let variables = sent.get("variables").cloned().unwrap_or_default();
        candidates
            .iter()
            .find(|c| c.variables == variables)
            .unwrap_or_else(|| panic!("no canned response for variables of {}", request.query))
            .bytes
            .clone()
    }
}

#[hive_router::async_trait]
impl SubgraphExecutor for CannedExecutor {
    fn executor_name(&self) -> &str {
        "canned"
    }

    fn endpoint(&self) -> &http::Uri {
        &self.endpoint
    }

    async fn execute<'a>(
        &self,
        execution_request: SubgraphExecutionRequest<'a>,
        _timeout: Option<Duration>,
        _plugin_req_state: Option<&'a PluginRequestState<'a>>,
    ) -> Result<SubgraphResponse<'static>, SubgraphExecutorError> {
        let body = build_request_body(&execution_request)?;
        let bytes = self.lookup(&execution_request, &body);
        std::hint::black_box(&body);
        let mut response =
            SubgraphResponse::deserialize_from_bytes(bytes, execution_request.custom_scalar_paths)?;
        response.headers = Some(self.headers.clone());
        response.status = Some(http::StatusCode::OK);
        Ok(response)
    }

    async fn subscribe<'a>(
        &self,
        _execution_request: SubgraphExecutionRequest<'a>,
        _timeout: Option<Duration>,
    ) -> Result<
        BoxStream<'static, Result<SubgraphResponse<'static>, SubgraphExecutorError>>,
        SubgraphExecutorError,
    > {
        unreachable!("TestQuery has no subscription")
    }
}

/// One request that `--record` saw: the subgraph, the request body, and
/// the response bytes.
struct Recorded {
    subgraph: String,
    body: Vec<u8>,
    response: Option<Bytes>,
}

/// A `SubgraphExecutor` that records the request and the response of the
/// real HTTP executor that it wraps.
struct RecordingExecutor {
    subgraph: String,
    inner: SubgraphExecutorBoxedArc,
    log: Arc<Mutex<Vec<Recorded>>>,
}

#[hive_router::async_trait]
impl SubgraphExecutor for RecordingExecutor {
    fn executor_name(&self) -> &str {
        "recording"
    }

    fn endpoint(&self) -> &http::Uri {
        self.inner.endpoint()
    }

    async fn execute<'a>(
        &self,
        execution_request: SubgraphExecutionRequest<'a>,
        timeout: Option<Duration>,
        plugin_req_state: Option<&'a PluginRequestState<'a>>,
    ) -> Result<SubgraphResponse<'static>, SubgraphExecutorError> {
        // Record in the order the requests are issued.
        let index = {
            let mut log = self.log.lock().unwrap();
            log.push(Recorded {
                subgraph: self.subgraph.clone(),
                body: build_request_body(&execution_request)?,
                response: None,
            });
            log.len() - 1
        };
        let response = self
            .inner
            .execute(execution_request, timeout, plugin_req_state)
            .await?;
        self.log.lock().unwrap()[index].response = response.bytes.clone();
        Ok(response)
    }

    async fn subscribe<'a>(
        &self,
        execution_request: SubgraphExecutionRequest<'a>,
        timeout: Option<Duration>,
    ) -> Result<
        BoxStream<'static, Result<SubgraphResponse<'static>, SubgraphExecutorError>>,
        SubgraphExecutorError,
    > {
        self.inner.subscribe(execution_request, timeout).await
    }
}

/// What `CannedPlugin` does with each subgraph fetch.
enum Mode {
    /// Replace the executor with the canned executor of the subgraph.
    Canned(HashMap<String, SubgraphExecutorBoxedArc>),
    /// Wrap the real HTTP executor in a `RecordingExecutor`.
    Record(Arc<Mutex<Vec<Recorded>>>),
}

/// The plugin that injects the canned (or the recording) executors through
/// the `on_subgraph_execute` hook.
struct CannedPlugin {
    mode: Mode,
}

#[hive_router::async_trait]
impl RouterPlugin for CannedPlugin {
    fn plugin_name() -> &'static str {
        "mojographql_canned_subgraphs"
    }

    type Config = ();

    fn on_plugin_init(_payload: OnPluginInitPayload<Self>) -> OnPluginInitResult<Self> {
        // The benchmark builds the plugin directly, not from the router config.
        Ok(None)
    }

    async fn on_subgraph_execute<'exec>(
        &'exec self,
        mut payload: OnSubgraphExecuteStartHookPayload<'exec>,
    ) -> OnSubgraphExecuteStartHookResult<'exec> {
        match &self.mode {
            Mode::Canned(executors) => {
                payload.executor = executors
                    .get(payload.subgraph_name)
                    .unwrap_or_else(|| panic!("no canned executor for {}", payload.subgraph_name))
                    .clone();
            }
            Mode::Record(log) => {
                payload.executor = RecordingExecutor {
                    subgraph: payload.subgraph_name.to_string(),
                    inner: payload.executor.clone(),
                    log: log.clone(),
                }
                .to_boxed_arc();
            }
        }
        payload.proceed()
    }
}

/// Everything that one `execute_query_plan` call needs and that the router
/// builds once per supergraph or once per request. It is built once, outside
/// the timed loop.
pub struct Execution {
    query_plan: QueryPlan,
    operation_for_plan: Arc<OperationDefinition>,
    projection_plan: Arc<ProjectionPlan>,
    root_type_name: String,
    operation_kind: OperationKind,
    introspection_context: Arc<IntrospectionContext>,
    variables: Arc<CoerceVariablesPayload>,
    executors: Arc<SubgraphExecutorMap>,
    headers_plan: Arc<HeaderRulesPlan>,
    extensions_plan: Arc<ExtensionsPlan>,
    operation_name_config: Arc<OperationNameForwardConfig>,
    error_masking: Arc<Option<ErrorMaskingRuntime>>,
    plugins: Arc<Vec<RouterPluginBoxed>>,
    plugin_context: Arc<PluginContext>,
    request_context: SharedRequestContext,
    method: http::Method,
    url: http::Uri,
    client_headers: Arc<ntex::http::HeaderMap>,
    router_headers: ntex::http::HeaderMap,
    match_info: ntex::router::Path<http::Uri>,
    jwt: Arc<JwtRequestDetails>,
    query_text: String,
}

impl Execution {
    /// Build the planner, the normalized operation, the query plan, the
    /// projection plan, the schema metadata, the executor map and the plugin
    /// state, as the router does at supergraph load and at request start.
    /// `live` selects the supergraph URLs; otherwise the URLs are dummies.
    fn new(mode: Mode, live: bool) -> Execution {
        let parsed_schema = parse_schema(&fixture("hive-router-qp/supergraph.graphql"));
        let planner =
            Planner::new_from_supergraph(&parsed_schema, Default::default()).expect("planner");
        let query_text = fixture("hive-router-qp/operation.graphql");
        let document = parse_operation(&query_text);
        let operation = normalize_operation(&planner.supergraph, &document, Some(OPERATION_NAME))
            .expect("normalize")
            .operation;
        let operation_kind = operation.operation_kind.clone().unwrap_or(OperationKind::Query);
        let metadata = Arc::new(planner.consumer_schema.schema_metadata());
        let (root_type_name, projection_plan) = ProjectionPlan::from_operation(&operation, &metadata);
        let root_type_name = root_type_name.to_string();
        let partitioned = partition_operation(operation);
        let operation_for_plan = Arc::new(partitioned.downstream_operation);
        let query_plan = planner
            .plan_from_normalized_operation(
                &operation_for_plan,
                PlannerOverrideContext::default(),
                &CancellationToken::new(),
            )
            .expect("plan")
            .into_executable();
        let variables = Arc::new(CoerceVariablesPayload::default());
        let introspection_context = Arc::new(IntrospectionContext {
            query: partitioned.introspection_operation.map(Arc::new),
            schema: planner.consumer_schema.document.clone(),
            metadata,
            variables: variables.clone(),
        });
        let endpoints: HashMap<String, String> = planner
            .supergraph
            .subgraph_endpoint_map
            .iter()
            .map(|(name, url)| {
                let url = if live { url.clone() } else { dummy_url(name) };
                (name.clone(), url)
            })
            .collect();
        let executors = SubgraphExecutorMap::from_http_endpoint_map(
            &endpoints,
            Default::default(),
            Default::default(),
            Default::default(),
            None,
            Arc::new(TelemetryContext::from_propagation_config(
                &Default::default(),
                &Default::default(),
            )),
            Default::default(),
        )
        .expect("executor map");
        let operation_name_config = Arc::new(OperationNameForwardConfig::new(
            &Default::default(),
            endpoints.keys(),
        ));
        let url: http::Uri = "http://localhost:4000/graphql".parse().unwrap();
        let plugin: RouterPluginBoxed = Box::new(CannedPlugin { mode });
        Execution {
            query_plan,
            operation_for_plan,
            projection_plan: Arc::new(projection_plan),
            root_type_name,
            operation_kind,
            introspection_context,
            variables,
            executors: Arc::new(executors),
            headers_plan: Arc::new(HeaderRulesPlan::default()),
            extensions_plan: Arc::new(ExtensionsPlan::default()),
            operation_name_config,
            error_masking: Arc::new(None),
            plugins: Arc::new(vec![plugin]),
            plugin_context: Arc::new(PluginContext::default()),
            request_context: SharedRequestContext::default(),
            method: http::Method::POST,
            match_info: ntex::router::Path::new(url.clone()),
            url,
            client_headers: Arc::new(ntex::http::HeaderMap::new()),
            router_headers: ntex::http::HeaderMap::new(),
            jwt: Arc::new(JwtRequestDetails::Unauthenticated),
            query_text,
        }
    }

    /// The canned in-process execution of the benchmark.
    pub fn canned() -> Execution {
        Execution::new(Mode::Canned(load_canned()), false)
    }

    /// One upstream `execute_query_plan` call. It returns the response body.
    pub async fn run(&self) -> Vec<u8> {
        let client_request = Arc::new(ClientRequestDetails {
            method: &self.method,
            url: &self.url,
            headers: self.client_headers.clone(),
            operation: OperationDetails {
                name: Some(OPERATION_NAME),
                query: &self.query_text,
                kind: "query",
            },
            jwt: self.jwt.clone(),
            path_params: Default::default(),
        });
        let plugin_req_state = PluginRequestState {
            plugins: self.plugins.clone(),
            router_http_request: RouterHttpRequest {
                uri: &self.url,
                method: &self.method,
                version: http::Version::HTTP_11,
                headers: &self.router_headers,
                path: "/graphql",
                query_string: "",
                match_info: &self.match_info,
            },
            context: self.plugin_context.clone(),
            request_context: self.request_context.clone(),
        };
        let opts = QueryPlanExecutionOpts {
            query_plan: &self.query_plan,
            operation_for_plan: self.operation_for_plan.clone(),
            projection_plan: self.projection_plan.clone(),
            headers_plan: self.headers_plan.clone(),
            extensions_plan: self.extensions_plan.clone(),
            variable_values: self.variables.clone(),
            extensions: ExecutionResultExtensions::default(),
            client_request,
            introspection_context: self.introspection_context.clone(),
            operation_type_name: self.root_type_name.clone(),
            operation_kind: self.operation_kind.clone(),
            executors: self.executors.clone(),
            jwt_auth_forwarding: None,
            graphql_error_recorder: None,
            demand_control_context: None,
            initial_errors: Vec::new(),
            span: GraphQLOperationSpan::new(),
            plugin_req_state: Some(plugin_req_state),
            operation_name_factory: OperationNameFactory::new(
                self.operation_name_config.clone(),
                Some(OPERATION_NAME),
            ),
            response_header_sink: ResponseHeaderSink::default(),
            error_masking_runtime: self.error_masking.clone(),
            connection_fingerprint: None,
        };
        match execute_query_plan(opts).await.expect("execute_query_plan") {
            QueryPlanExecutionResult::Single(output) => output.body,
            QueryPlanExecutionResult::Stream(_) => unreachable!("TestQuery is a query"),
        }
    }
}

fn dummy_url(subgraph: &str) -> String {
    // Port 9 (discard) on loopback. The canned executors replace the HTTP
    // executors, so the router never connects to it.
    format!("http://127.0.0.1:9/{subgraph}")
}

/// Read `responses.json` into one `CannedExecutor` per subgraph. The
/// canned bytes are the raw text of each `response` member, which is the
/// body that the subgraph sent, byte for byte. They are copied once here,
/// outside the timed loop.
fn load_canned() -> HashMap<String, SubgraphExecutorBoxedArc> {
    let text = fixture(RESPONSES);
    let mut by_subgraph: HashMap<String, HashMap<String, Vec<Canned>>> = HashMap::new();
    for entry in sonic_rs::to_array_iter(&text) {
        let entry = entry.expect("responses.json is an array");
        let raw = entry.as_raw_str();
        let member = |key: &str| {
            sonic_rs::get(raw, [key])
                .unwrap_or_else(|e| panic!("responses.json: member {key}: {e}"))
                .as_raw_str()
                .to_string()
        };
        let subgraph: String = sonic_rs::from_str(&member("subgraph")).unwrap();
        let query: String = sonic_rs::from_str(&member("query")).unwrap();
        by_subgraph
            .entry(subgraph)
            .or_default()
            .entry(query)
            .or_default()
            .push(Canned {
                variables: sonic_rs::from_str(&member("variables")).unwrap(),
                bytes: Bytes::from(member("response")),
            });
    }
    let mut headers = http::HeaderMap::new();
    headers.insert(
        http::header::CONTENT_TYPE,
        http::HeaderValue::from_static("application/json"),
    );
    let headers = Arc::new(headers);
    by_subgraph
        .into_iter()
        .map(|(name, by_query)| {
            let executor = CannedExecutor {
                endpoint: dummy_url(&name).parse().unwrap(),
                headers: headers.clone(),
                by_query,
            };
            (name, executor.to_boxed_arc())
        })
        .collect()
}

/// `--record`: regenerate the fixtures from the real upstream bench
/// subgraphs.
///
/// Start the subgraphs first. From `upstream/`:
///
/// ```sh
/// cargo build --release -p subgraphs --features hive-router/graphiql
/// ./target/release/subgraphs   # serves http://0.0.0.0:4200/<subgraph>
/// ```
///
/// Then, from bench/baselines/rust-router/:
///
/// ```sh
/// ./target/release/mojographql-bench-router-rust --record
/// ```
///
/// It runs the plan once through real HTTP with the supergraph URLs, while
/// `RecordingExecutor` records each request and response, and writes
/// `responses.json`. Then it runs the canned execution from that file and
/// writes its body to `expected_response.json`.
pub fn record(rt: &hive_router::tokio::runtime::Runtime) {
    let log = Arc::new(Mutex::new(Vec::new()));
    let live = Execution::new(Mode::Record(log.clone()), true);
    let live_body = rt.block_on(live.run());
    let records = std::mem::take(&mut *log.lock().unwrap());
    // The file is written by hand, one request per line, so that `query`
    // and `variables` are the raw JSON text of the request body and
    // `response` is the raw body of the subgraph response, with the member
    // order that the router and the subgraph produced.
    let mut text = String::from("[\n");
    for (i, r) in records.into_iter().enumerate() {
        let body = std::str::from_utf8(&r.body).expect("request body is UTF-8");
        let bytes = r.response.expect("the subgraph answered");
        let response = std::str::from_utf8(&bytes).expect("response is UTF-8").trim();
        let query = sonic_rs::get(body, ["query"]).expect("request has a query");
        let variables = sonic_rs::get(body, ["variables"]);
        let variables = variables.as_ref().map_or("null", |v| v.as_raw_str());
        let query_text: String = sonic_rs::from_str(query.as_raw_str()).unwrap();
        println!("request {i}: {} {query_text} ({} response bytes)", r.subgraph, bytes.len());
        if i > 0 {
            text.push_str(",\n");
        }
        text.push_str(&format!(
            "{{\"subgraph\":{},\"query\":{},\"variables\":{variables},\"response\":{response}}}",
            sonic_rs::to_string(&r.subgraph).unwrap(),
            query.as_raw_str(),
        ));
    }
    text.push_str("\n]\n");
    let responses = crate::fixture_path(RESPONSES);
    std::fs::create_dir_all(responses.parent().unwrap()).unwrap();
    std::fs::write(&responses, text).unwrap();

    let canned = Execution::canned();
    let body = rt.block_on(canned.run());
    std::fs::write(crate::fixture_path(EXPECTED), &body).unwrap();
    println!(
        "wrote {} and {}; the canned body equals the live body: {}",
        responses.display(),
        crate::fixture_path(EXPECTED).display(),
        body == live_body
    );
}
