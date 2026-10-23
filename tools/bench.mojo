# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Benchmark the Mojo packages against the upstream libraries.

    bench [--check] <mojo> <package>...

For each package, the tool builds every `bench/<package>/*.mojo` in release
mode and runs it from the repository root. Then it builds and runs every
baseline in `bench/baselines/` that measures one of the packages (see
`serves`), one at a time, each from its own directory.
Every program prints one line per workload:

    BENCH <workload> <nanoseconds per op>

The tool writes `bench/RESULTS.md`: a summary table per suite, the map from
each upstream-published benchmark to its workload, one table per workload
with the time of each implementation and its ratio to Mojo, and the machine
and the toolchains that made the numbers. A ratio above 1 means that Mojo is
faster.

With `--check`, the tool fails when a baseline is faster than Mojo on a
workload that both run, and names each one. A baseline that does not build
or prints no results also fails the run: a missing comparison is not a pass.

The baselines need Node.js and npm, Cargo, and Go. The tool looks for them
on `PATH`, then in `~/node/bin`, `~/.cargo/bin` and `~/go-sdk/go/bin`.
`bench/baselines/kotlin-codegen` needs a JDK 21 in `$JAVA_HOME` or
`~/jdk`, and Gradle in `$GRADLE` or `~/gradle/gradle-8.14.3`.
"""

from std.os import listdir
from std.os.path import isdir
from std.pathlib import Path
from std.subprocess import run
from std.sys import argv

comptime RESULTS = "bench/RESULTS.md"
"""The report the tool writes."""
comptime TOOL_PATH = (
    'PATH="$PATH:$HOME/node/bin:$HOME/.cargo/bin:$HOME/go-sdk/go/bin"; '
)
"""A shell prefix that adds the usual toolchain locations to `PATH`."""

comptime HTTP_LOADGEN_BUILD = (
    "(cd ../../.. && ([ -x .cache/bin/http_loadgen ] || (mkdir -p .cache/bin &&"
    " .venv/bin/mojo build -I . -o .cache/bin/http_loadgen"
    " bench/gql_http/_loadgen.mojo > /dev/null)))"
)
"""The shell command that builds the gql_http load generator, from a
baseline directory."""

comptime HTTP_LOADGEN = (
    "../../../.cache/bin/http_loadgen http/keepalive-small-json"
)
"""The load generator and its workload; the server command follows."""

comptime H2_LOADGEN_BUILD = (
    "(cd ../../.. && ([ -x .cache/bin/h2load ] || (mkdir -p .cache/bin &&"
    " .venv/bin/mojo build -I . -o .cache/bin/h2load"
    " bench/gql_http2/_h2load.mojo > /dev/null)))"
)
"""The shell command that builds the gql_http2 h2c load generator, from a
baseline directory."""

comptime H2_LOADGEN = "../../../.cache/bin/h2load http2/roundtrip-small-json"
"""The h2c load generator and its workload; the server command follows."""

comptime MCP_DRIVER_BUILD = (
    "(cd ../../.. && ([ -x .cache/bin/mcp_driver ] || (mkdir -p .cache/bin &&"
    " .venv/bin/mojo build -I . -o .cache/bin/mcp_driver"
    " bench/gql_mcp/_driver.mojo > /dev/null)))"
)
"""The shell command that builds the gql_mcp stdio driver, from a baseline
directory."""

comptime WS_LOAD_BUILD = (
    "(cd ../../.. && ([ -x .cache/bin/ws_load ] || (mkdir -p .cache/bin &&"
    " .venv/bin/mojo build -I . -o .cache/bin/ws_load"
    " bench/gql_ws/_wsload.mojo > /dev/null)))"
)
"""The shell command that builds the gql_ws load generator, from a baseline
directory."""

comptime WS_LOAD = "../../../.cache/bin/ws_load"
"""The gql_ws load generator; the workload and the server command follow."""

comptime H2WS_LOAD_BUILD = (
    "(cd ../../.. && ([ -x .cache/bin/h2ws_load ] || (mkdir -p .cache/bin &&"
    " .venv/bin/mojo build -I . -o .cache/bin/h2ws_load"
    " bench/gql_ws_http2/_h2wsload.mojo > /dev/null)))"
)
"""The shell command that builds the gql_ws_http2 load generator, from a
baseline directory."""

comptime H2WS_LOAD = "../../../.cache/bin/h2ws_load"
"""The gql_ws_http2 load generator; the server command follows."""

comptime MCP_DRIVER = "../../../.cache/bin/mcp_driver --root ../../.."
"""The stdio driver of the MCP servers; the server command follows."""


@fieldwise_init
struct Baseline(Copyable, Movable):
    """An upstream library, built and run from its own directory."""

    var name: String
    """The library and its version, as the report names it."""
    var directory: String
    """The directory of the program, from the repository root."""
    var build: String
    """The shell command that builds the program."""
    var command: String
    """The shell command that runs the program."""


@fieldwise_init
struct Measurement(Copyable, Movable):
    """One `BENCH` line: an implementation's time on one workload."""

    var implementation: String
    """The implementation, such as `Mojo` or a baseline name."""
    var workload: String
    """The workload, such as `parse/kitchen-sink`."""
    var nanoseconds: Float64
    """The time of one operation, in nanoseconds."""


def baselines() -> List[Baseline]:
    """Return the upstream libraries to compare against.

    Returns:
        The baselines, in report order.
    """
    var out = List[Baseline]()
    out.append(
        Baseline(
            "graphql-js 16.14.2 (Node.js)",
            "bench/baselines/js",
            "[ -d node_modules ] || npm ci --no-audit --no-fund",
            "node bench.mjs",
        )
    )
    out.append(
        Baseline(
            "apollo-parser 0.8.6 (Rust, CST)",
            "bench/baselines/rust",
            "cargo build --release --locked --quiet",
            "./target/release/apollo-parser",
        )
    )
    out.append(
        Baseline(
            "apollo-compiler 1.33.0 (Rust, AST)",
            "bench/baselines/rust",
            "cargo build --release --locked --quiet",
            "./target/release/apollo-compiler",
        )
    )
    out.append(
        Baseline(
            "graphql-go-tools 2.28.0 (Go)",
            "bench/baselines/go",
            "go build -o bench-go .",
            "./bench-go",
        )
    )
    out.append(
        Baseline(
            "graphql-go-tools 9ef6e24 (Go), astnormalization and astminify",
            "bench/baselines/go-normalization",
            "go build -o bench-normalization-go .",
            "./bench-normalization-go",
        )
    )
    out.append(
        Baseline(
            "JSON.parse and JSON.stringify (Node.js)",
            "bench/baselines/js-json",
            "true",
            "node bench.mjs",
        )
    )
    out.append(
        Baseline(
            (
                "graphql-js 16.14.2 subscribe, graphql-subscriptions 3.0.0"
                " (Node.js)"
            ),
            "bench/baselines/js-stream",
            "[ -d node_modules ] || npm ci --no-audit --no-fund",
            "node bench.mjs",
        )
    )
    out.append(
        Baseline(
            "graphql-js 17.0.2 experimentalExecuteIncrementally (Node.js)",
            "bench/baselines/js-incremental",
            "[ -d node_modules ] || npm ci --no-audit --no-fund",
            "node bench.mjs",
        )
    )
    out.append(
        Baseline(
            "Apollo Client 4.3.3 InMemoryCache (Node.js)",
            "bench/baselines/js-client",
            "[ -d node_modules ] || npm ci --no-audit --no-fund",
            "node --conditions=production bench.mjs",
        )
    )
    out.append(
        Baseline(
            "Hive Federation Composition 0.27.0 (Node.js)",
            "bench/baselines/js-composition",
            "[ -d node_modules ] || npm ci --no-audit --no-fund",
            "node bench.mjs",
        )
    )
    out.append(
        Baseline(
            "astjson 1.1.0 (Go)",
            "bench/baselines/go-json",
            "go build -o bench-json-go .",
            "./bench-json-go astjson",
        )
    )
    out.append(
        Baseline(
            "encoding/json (Go)",
            "bench/baselines/go-json",
            "go build -o bench-json-go .",
            "./bench-json-go encoding-json",
        )
    )
    out.append(
        Baseline(
            "serde_json 1.0.154 (Rust)",
            "bench/baselines/rust-json",
            "cargo build --release --locked --quiet",
            "./target/release/serde-json",
        )
    )
    # The HTTP servers run under the Mojo load generator of gql_http, so
    # that only the server differs from the Mojo benchmark.
    out.append(
        Baseline(
            "node:http and llhttp (Node.js)",
            "bench/baselines/js-http",
            HTTP_LOADGEN_BUILD,
            HTTP_LOADGEN + " node bench.mjs server && node bench.mjs parse",
        )
    )
    out.append(
        Baseline(
            "net/http (Go)",
            "bench/baselines/go-http",
            "go build -o bench-http-go . && " + HTTP_LOADGEN_BUILD,
            HTTP_LOADGEN + " ./bench-http-go server && ./bench-http-go parse",
        )
    )
    out.append(
        Baseline(
            "hyper 1.12.0 and httparse 1.10.1 (Rust)",
            "bench/baselines/rust-http",
            "cargo build --release --locked --quiet && " + HTTP_LOADGEN_BUILD,
            HTTP_LOADGEN
            + " ./target/release/hyper-server && ./target/release/httparse"
            + " && ../../../.cache/bin/http_loadgen http/chunked-16-parts"
            + " ./target/release/hyper-server",
        )
    )
    # The TLS baseline runs its own client and server, as the Mojo one does:
    # HTTPS/1.1 for gql_tls, and HTTP/2 after ALPN h2 for gql_https2.
    out.append(
        Baseline(
            "hyper 1.12.0, h2 0.4.20 and rustls 0.23.45 (Rust)",
            "bench/baselines/rust-tls",
            "cargo build --release --locked --quiet",
            "./target/release/hyper-rustls && ./target/release/hyper-rustls-h2",
        )
    )
    # The HTTP/2 servers run under the Mojo h2c load generator of
    # gql_http2. h2's HPACK coder is private, so the crate compiles its
    # sources from the cargo registry copy of h2 0.4.20.
    out.append(
        Baseline(
            "hyper 1.12.0 and h2 0.4.20 (Rust)",
            "bench/baselines/rust-http2",
            "cargo build --release --locked --quiet && " + H2_LOADGEN_BUILD,
            H2_LOADGEN
            + " ./target/release/hyper-h2-server && ./target/release/h2-hpack",
        )
    )
    # h3's QPACK coder is private: build.sh fetches h3 at the pinned
    # revision and the crate includes its sources. h3-roundtrip runs h3,
    # h3-quinn and quinn over localhost UDP.
    out.append(
        Baseline(
            "h3 0.0.8 and quinn 0.11 (Rust)",
            "bench/baselines/rust-http3",
            "sh build.sh",
            "./target/release/h3-qpack && ./target/release/h3-roundtrip",
        )
    )
    # quic-stream drives the public quinn-proto API in memory, with no
    # sockets. quic-echo runs quinn over localhost UDP.
    out.append(
        Baseline(
            "quinn 0.11 (Rust)",
            "bench/baselines/rust-quic",
            "cargo build --release --locked --quiet",
            "./target/release/quic-stream && ./target/release/quic-echo",
        )
    )
    # The HTTP workload of Apollo Server runs under the same Mojo load
    # generator as the gql_server one. `incremental/` has its own
    # node_modules: Apollo Server runs @defer only with graphql-js
    # 17.0.0-alpha.9.
    out.append(
        Baseline(
            "Apollo Server 5.5.1 (Node.js)",
            "bench/baselines/js-server",
            "([ -d node_modules ] || npm ci --no-audit --no-fund) && (cd"
            " incremental && ([ -d node_modules ] || npm ci --no-audit"
            " --no-fund)) && "
            + HTTP_LOADGEN_BUILD,
            (
                "node bench.mjs && node incremental/bench.mjs &&"
                " ../../../.cache/bin/http_loadgen server/http-post-small"
                " node bench.mjs server"
            ),
        )
    )
    out.append(
        Baseline(
            "@apollo/subgraph 2.14.4 (Node.js)",
            "bench/baselines/js-subgraph",
            "[ -d node_modules ] || npm ci --no-audit --no-fund",
            "node bench.mjs",
        )
    )
    # The MCP servers run under the Mojo stdio driver of gql_mcp, so that
    # only the server differs from the Mojo benchmark.
    out.append(
        Baseline(
            "Apollo MCP Server 2.0.0 (Rust)",
            "bench/baselines/rust-mcp",
            "./build.sh && " + MCP_DRIVER_BUILD,
            "./target/release/tool && "
            + MCP_DRIVER
            + " ./target/release/apollo-mcp-server config.yaml",
        )
    )
    out.append(
        Baseline(
            "Hive Router 1a29df9 query planner (Rust)",
            "bench/baselines/rust-router",
            "./build.sh",
            "./target/release/mojographql-bench-router-rust",
        )
    )
    # The JVM baseline runs on a portable JDK 21 in ~/jdk, with Gradle in
    # ~/gradle; its scripts cap the heap at 4 GiB.
    out.append(
        Baseline(
            "Apollo Kotlin 5.2.0 apollo-compiler (JVM)",
            "bench/baselines/kotlin-codegen",
            "./build.sh",
            "./run.sh",
        )
    )
    # Rover composes with an Elastic licensed plugin, so `supergraph
    # compose` is compared with Hive `composeServices`, which gql_seamstress
    # runs. The introspection commands run the Rover program itself, under
    # the same process driver as the seamstress program.
    out.append(
        Baseline(
            "Hive Federation Composition 0.27.0 composeServices (Node.js)",
            "bench/baselines/js-seamstress",
            "[ -d node_modules ] || npm ci --no-audit --no-fund",
            "node bench.mjs",
        )
    )
    out.append(
        Baseline(
            "Apollo Rover 1.0.0 (Rust)",
            "bench/baselines/rust-seamstress",
            "./build.sh",
            (
                "../../../.cache/bin/seamstress_driver ./target/release/rover"
                " ../../.."
            ),
        )
    )
    # The WebSocket servers run under the Mojo load generator of gql_ws, so
    # that only the server differs from the Mojo benchmark.
    out.append(
        Baseline(
            "tungstenite 0.30.0 and tokio-tungstenite 0.30.0 (Rust)",
            "bench/baselines/rust-ws",
            "cargo build --release --locked --quiet && " + WS_LOAD_BUILD,
            WS_LOAD
            + " ws/echo-roundtrip ./target/release/ws-echo-server"
            " && ./target/release/ws-frames",
        )
    )
    # The WebSockets over HTTP/2 run under the load generator of
    # gql_ws_http2.
    out.append(
        Baseline(
            "h2 0.4.20 and tungstenite 0.30.0 (Rust)",
            "bench/baselines/rust-ws_http2",
            "cargo build --release --locked --quiet && " + H2WS_LOAD_BUILD,
            H2WS_LOAD + " ./target/release/ws-h2-server",
        )
    )
    out.append(
        Baseline(
            "ws 8.18.3 and graphql-ws 6.4.1 (Node.js)",
            "bench/baselines/js-ws",
            "([ -d node_modules ] || npm ci --no-audit --no-fund) && "
            + WS_LOAD_BUILD,
            WS_LOAD
            + " ws/echo-roundtrip node bench.mjs server && "
            + WS_LOAD
            + " graphql-ws/subscribe-1000-next node bench.mjs gql"
            " && node bench.mjs frames",
        )
    )
    # graphql-sse for gql_sse, and meros for the multipart decoder of
    # gql_http.
    out.append(
        Baseline(
            "graphql-sse 2.6.3 and meros 1.3.2 (Node.js)",
            "bench/baselines/js-sse",
            "[ -d node_modules ] || npm ci --no-audit --no-fund",
            "node bench.mjs sse && node bench.mjs multipart",
        )
    )
    return out^


comptime CORE_PACKAGES: Array[StaticString, 5] = [
    "gql_language",
    "gql_schema",
    "gql_validation",
    "gql_execution",
    "gql_compiler",
]
"""The packages that the GraphQL libraries themselves measure: the baseline
directories without a dash run graphql-js, apollo-rs and graphql-go-tools,
which hold all five."""


comptime ALSO_SERVES: Array[StaticString, 8] = [
    "rust-tls",
    "gql_https2",
    "js-stream",
    "gql_execution",
    "js-incremental",
    "gql_execution",
    "js-sse",
    "gql_http",
]
"""Baseline directories that also measure another package, as pairs of the
directory name and the package. `rust-tls` runs HTTP/2 over TLS too,
`js-stream` runs graphql-js `subscribe` too, `js-incremental` runs
graphql-js 17 `experimentalExecuteIncrementally`, and `js-sse` runs the
meros multipart parser too."""


def serves(baseline: Baseline, packages: List[String]) -> Bool:
    """Return True when a baseline measures one of some packages.

    A baseline directory `bench/baselines/<language>-<name>` measures the
    package `gql_<name>`, and the package that `ALSO_SERVES` names for it.
    A directory without a dash runs a GraphQL library, and measures each of
    `CORE_PACKAGES`.

    Args:
        baseline: The baseline.
        packages: The packages that run.

    Returns:
        Whether the baseline has workloads of the packages.
    """
    var name = baseline.directory.removeprefix("bench/baselines/")
    var also = materialize[ALSO_SERVES]()
    for index in range(0, len(also), 2):
        if name == also[index] and String(also[index + 1]) in packages:
            return True
    var dash = name.find("-")
    if dash >= 0:
        return "gql_" + String(name[byte = dash + 1 :]) in packages
    var core = materialize[CORE_PACKAGES]()
    for index in range(len(core)):
        if String(core[index]) in packages:
            return True
    return False


def shell(command: String) raises -> Tuple[Int, String]:
    """Run a shell command; return its exit status and combined output.

    Args:
        command: The command, for `/bin/sh`.

    Returns:
        The exit status and the output without the Crashpad warning.

    Raises:
        Error: If the command cannot be started.
    """
    var out = run("(" + command + ") 2>&1; echo __rc=$?")
    var lines = out.splitlines()
    var status = 1
    var text = String("")
    for index in range(len(lines)):
        var line = lines[index]
        if index == len(lines) - 1 and line.startswith("__rc="):
            status = Int(String(line[byte=5:]))
            continue
        if "Crashpad" in line:
            continue
        text += line + "\n"
    return (status, text^)


def quote(text: String) -> String:
    """Quote text for the shell.

    Args:
        text: Any text.

    Returns:
        The text in single quotes.
    """
    return "'" + text.replace("'", "'\"'\"'") + "'"


def first_line(command: String) raises -> String:
    """Return the first line a shell command prints, or `unknown`.

    Args:
        command: The command, for `/bin/sh`.

    Returns:
        The first line of the output, stripped.

    Raises:
        Error: If the command cannot be started.
    """
    var result = shell(command)
    if result[0] != 0:
        return String("unknown")
    var text = result[1].copy()
    var lines = text.splitlines()
    if len(lines) == 0:
        return String("unknown")
    return String(lines[0].strip())


def parse_results(
    implementation: String, output: String
) raises -> List[Measurement]:
    """Read the `BENCH` lines of a program's output.

    Args:
        implementation: The name to record with each line.
        output: What the program printed.

    Returns:
        One measurement per `BENCH` line, in order.

    Raises:
        Error: If a `BENCH` line is malformed.
    """
    var out = List[Measurement]()
    for raw in output.splitlines():
        var line = String(raw.strip())
        if not line.startswith("BENCH "):
            continue
        var fields = line.split(" ")
        if len(fields) != 3:
            raise Error("malformed result line: " + line)
        out.append(
            Measurement(
                implementation,
                String(fields[1]),
                Float64(String(fields[2])),
            )
        )
    return out^


def mojo_benches(package: String) raises -> List[String]:
    """Return the benchmark programs of a package: `bench/<package>/*.mojo`.

    Args:
        package: The package.

    Returns:
        The paths, sorted, without `_` helpers.

    Raises:
        Error: If the directory cannot be listed.
    """
    var out = List[String]()
    var directory = "bench/" + package
    if not isdir(directory):
        return out^
    var entries = listdir(directory)
    sort(entries)
    for ref entry in entries:
        if not entry.startswith("_") and entry.endswith(".mojo"):
            out.append(directory + "/" + entry)
    return out^


def run_mojo(mojo: String, program: String) raises -> List[Measurement]:
    """Build one Mojo benchmark in release mode, run it and read its results.

    Args:
        mojo: The Mojo executable.
        program: The benchmark source, such as `bench/gql_language/parse.mojo`.

    Returns:
        Its measurements.

    Raises:
        Error: If the build fails, the program fails, or it prints no results.
    """
    var name = program.replace("/", "__").removesuffix(".mojo")
    var binary = ".cache/bin/" + name
    print("building", program)
    var built = shell(
        "([ -x "
        + quote(binary)
        + " ] && [ "
        + quote(binary)
        + " -nt "
        + quote(program)
        + " ]) || (mkdir -p .cache/bin && "
        + quote(mojo)
        + " build -I . -o "
        + quote(binary)
        + " "
        + quote(program)
        + ")"
    )
    if built[0] != 0:
        print(built[1], end="")
        raise Error("BUILD FAILED: " + program)
    print("running ", program)
    var ran = shell(
        "([ ! -x .cache/bin-mojo12/mcp_server ] || cp"
        " .cache/bin-mojo12/mcp_server .cache/bin/mcp_server) && ([ ! -x"
        " .cache/bin-mojo12/gql_seamstress ] || cp"
        " .cache/bin-mojo12/gql_seamstress .cache/bin/gql_seamstress) && "
        + quote(binary)
        + " < /dev/null"
    )
    if ran[0] != 0:
        print(ran[1], end="")
        raise Error("FAILED: " + program)
    var results = parse_results("Mojo", ran[1])
    if len(results) == 0:
        raise Error(program + " printed no BENCH lines")
    var binary11 = ".cache/bin-mojo11/" + name
    if isdir(".cache/bin-mojo11"):
        print("running  Mojo 1.1.0", program)
        var ran11 = shell(
            "([ ! -x .cache/bin-mojo11/mcp_server ] || cp"
            " .cache/bin-mojo11/mcp_server .cache/bin/mcp_server) && ([ ! -x"
            " .cache/bin-mojo11/gql_seamstress ] || cp"
            " .cache/bin-mojo11/gql_seamstress .cache/bin/gql_seamstress) && "
            + quote(binary11)
            + " < /dev/null"
        )
        if ran11[0] != 0:
            print(ran11[1], end="")
            raise Error("FAILED: " + binary11)
        results.extend(parse_results("Mojo 1.1.0", ran11[1]))
    return results^


def run_baseline(baseline: Baseline) raises -> List[Measurement]:
    """Build one baseline, run it and read its results.

    Args:
        baseline: The baseline.

    Returns:
        Its measurements.

    Raises:
        Error: If the build fails, the program fails, or it prints no results.
    """
    var prefix = TOOL_PATH + "cd " + quote(baseline.directory) + " && "
    print("building", baseline.name)
    var built = shell(prefix + baseline.build)
    if built[0] != 0:
        print(built[1], end="")
        raise Error(
            "BUILD FAILED: "
            + baseline.name
            + " in "
            + baseline.directory
            + ". Is its toolchain installed?"
        )
    print("running ", baseline.name)
    var ran = shell(prefix + baseline.command + " < /dev/null")
    if ran[0] != 0:
        print(ran[1], end="")
        raise Error("FAILED: " + baseline.name)
    var results = parse_results(baseline.name, ran[1])
    if len(results) == 0:
        raise Error(baseline.name + " printed no BENCH lines")
    return results^


def fixed(value: Float64, digits: Int) -> String:
    """Format a non-negative number with a fixed count of decimals.

    Args:
        value: The number.
        digits: How many digits follow the decimal point.

    Returns:
        The number, such as `1234.5`, with thousands separated by commas.
    """
    var scale = 1
    for _ in range(digits):
        scale *= 10
    var scaled = Int(value * Float64(scale) + 0.5)
    var whole = String(scaled // scale)
    var grouped = String("")
    var count = 0
    var bytes = whole.as_bytes()
    for index in range(len(bytes) - 1, -1, -1):
        if count > 0 and count % 3 == 0:
            grouped = "," + grouped
        grouped = chr(Int(bytes[index])) + grouped
        count += 1
    if digits == 0:
        return grouped^
    var fraction = String(scaled % scale)
    while fraction.byte_length() < digits:
        fraction = "0" + fraction
    return grouped + "." + fraction


def find(
    results: List[Measurement], implementation: String, workload: String
) -> Float64:
    """Return an implementation's time on a workload, or -1.

    Args:
        results: Every measurement.
        implementation: The implementation.
        workload: The workload.

    Returns:
        The nanoseconds per op, or -1 when it was not measured.
    """
    for ref result in results:
        if result.implementation == implementation and (
            result.workload == workload
        ):
            return result.nanoseconds
    return -1


def machine(mojo: String) raises -> String:
    """Describe the machine and the toolchains as Markdown list items.

    Args:
        mojo: The Mojo executable.

    Returns:
        The list.

    Raises:
        Error: If a command cannot be started.
    """
    var cpu = first_line("grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //'")
    if cpu == "unknown":
        cpu = first_line("sysctl -n machdep.cpu.brand_string")
    var out = String("")
    out += "- CPU: " + cpu + ", " + first_line("nproc") + " logical cores\n"
    out += "- OS: " + first_line("uname -sr") + "\n"
    out += "- Mojo: " + first_line(quote(mojo) + " --version") + "\n"
    if isdir(".cache/bin-mojo11"):
        out += (
            "- Mojo 1.1: "
            + first_line(
                "env -u PYTHONPATH -u VIRTUAL_ENV .venv-mojo11/bin/mojo"
                " --version"
            )
            + "\n"
        )
    out += "- Node.js: " + first_line(TOOL_PATH + "node --version") + "\n"
    out += "- Rust: " + first_line(TOOL_PATH + "rustc --version") + "\n"
    out += (
        "- Go: "
        + first_line(TOOL_PATH + "cd bench/baselines/go && go version")
        + "\n"
    )
    out += (
        "- JVM: "
        + first_line(
            '"${JAVA_HOME:-$HOME/jdk}/bin/java" -version 2>&1 | sed -n 2p'
        )
        + "\n"
    )
    return out^


@fieldwise_init
struct Upstream(Copyable, Movable):
    """A benchmark that an upstream project publishes, and our workload."""

    var project: String
    """The upstream project and its pinned version."""
    var file: String
    """The file of the benchmark in the upstream repository."""
    var benchmark: String
    """The upstream name of the benchmark."""
    var workload: String
    """Our workload id."""
    var fixture: String
    """The fixture in `bench/fixtures/`."""


def upstream() -> List[Upstream]:
    """Return every upstream-published benchmark that the tool replicates.

    Returns:
        One entry per upstream benchmark, in report order.
    """
    comptime JS = "graphql-js 16.14.2"
    comptime PARSER = "apollo-parser 0.8.6"
    comptime COMPILER = "apollo-compiler 1.33.0"
    comptime GO = "graphql-go-tools v2"
    comptime ASTPARSER = "v2/pkg/astparser/parser_test.go"
    var out = List[Upstream]()
    out.append(
        Upstream(
            JS,
            "benchmark/buildASTSchema-benchmark.js",
            "Build Schema from AST",
            "graphql-js/build-ast-schema",
            "github-schema.graphql",
        )
    )
    out.append(
        Upstream(
            JS,
            "benchmark/parser-benchmark.js",
            "Parse introspection query",
            "graphql-js/parse-introspection-query",
            "graphql-js-introspection-query.graphql",
        )
    )
    out.append(
        Upstream(
            JS,
            "benchmark/printer-benchmark.js",
            "Print kitchen sink document",
            "graphql-js/print-kitchen-sink",
            "kitchen-sink.graphql",
        )
    )
    out.append(
        Upstream(
            PARSER,
            "benches/query.rs",
            "query_parser",
            "apollo-parser/query_parser",
            "apollo-parser-query.graphql",
        )
    )
    out.append(
        Upstream(
            PARSER,
            "benches/query.rs",
            "query_lexer",
            "apollo-parser/query_lexer",
            "apollo-parser-query.graphql",
        )
    )
    out.append(
        Upstream(
            PARSER,
            "benches/query.rs",
            "many_aliases",
            "apollo-parser/many_aliases",
            "apollo-parser-alias.graphql",
        )
    )
    out.append(
        Upstream(
            PARSER,
            "benches/supergraph.rs",
            "supergraph_parser",
            "apollo-parser/supergraph_parser",
            "apollo-parser-supergraph.graphql",
        )
    )
    out.append(
        Upstream(
            PARSER,
            "benches/supergraph.rs",
            "supergraph_lexer",
            "apollo-parser/supergraph_lexer",
            "apollo-parser-supergraph.graphql",
        )
    )
    # The same parse benchmarks, against the recovering parser of
    # gql_compiler instead of the gql_language parser.
    out.append(
        Upstream(
            PARSER,
            "benches/query.rs",
            "query_parser",
            "apollo-parser-recovering/query_parser",
            "apollo-parser-query.graphql",
        )
    )
    out.append(
        Upstream(
            PARSER,
            "benches/query.rs",
            "many_aliases",
            "apollo-parser-recovering/many_aliases",
            "apollo-parser-alias.graphql",
        )
    )
    out.append(
        Upstream(
            PARSER,
            "benches/supergraph.rs",
            "supergraph_parser",
            "apollo-parser-recovering/supergraph_parser",
            "apollo-parser-supergraph.graphql",
        )
    )
    out.append(
        Upstream(
            COMPILER,
            "benches/multi_source.rs",
            "simple_query parse_ast",
            "apollo-compiler/simple_query-parse_ast",
            (
                "apollo-compiler-simple-schema.graphql,"
                " apollo-compiler-simple-query.graphql"
            ),
        )
    )
    out.append(
        Upstream(
            COMPILER,
            "benches/multi_source.rs",
            "supergraph parse_ast",
            "apollo-compiler/supergraph-parse_ast",
            (
                "apollo-parser-supergraph.graphql,"
                " apollo-compiler-supergraph-query.graphql"
            ),
        )
    )
    out.append(
        Upstream(
            GO,
            ASTPARSER,
            "BenchmarkParseStarwars",
            "go-tools/ParseStarwars",
            "go-tools-starwars.schema.graphql",
        )
    )
    out.append(
        Upstream(
            GO,
            ASTPARSER,
            "BenchmarkParseGithub",
            "go-tools/ParseGithub",
            "go-tools-github.schema.graphql",
        )
    )
    out.append(
        Upstream(
            GO,
            ASTPARSER,
            "BenchmarkSelectionSet",
            "go-tools/SelectionSet",
            "go-tools-selection-set.graphql",
        )
    )
    out.append(
        Upstream(
            GO,
            ASTPARSER,
            "BenchmarkIntrospectionQuery",
            "go-tools/IntrospectionQuery",
            "go-tools-introspection-query.graphql",
        )
    )
    out.append(
        Upstream(
            GO,
            ASTPARSER,
            "BenchmarkKitchenSink",
            "go-tools/KitchenSink",
            "go-tools-kitchen-sink.graphql",
        )
    )
    out.append(
        Upstream(
            GO,
            ASTPARSER,
            "BenchmarkParse",
            "go-tools/Parse",
            "go-tools-parse-input.graphql",
        )
    )
    out.append(
        Upstream(
            GO,
            "v2/pkg/astprinter/astprinter_test.go",
            "BenchmarkPrint",
            "go-tools/Print",
            "go-tools-print-operation.graphql",
        )
    )
    out.append(
        Upstream(
            GO,
            "v2/pkg/lexer/lexer_test.go",
            "BenchmarkLexer",
            "go-tools/Lexer",
            "go-tools-introspection-query.graphql",
        )
    )
    out.append(
        Upstream(
            GO,
            "v2/pkg/astnormalization/astnormalization_test.go",
            "BenchmarkAstNormalization",
            "go-tools/AstNormalization",
            "testDefinition and testOperation, in the benchmark source",
        )
    )
    out.append(
        Upstream(
            GO,
            "v2/pkg/astminify/minify_test.go",
            "BenchmarkMinify",
            "go-tools/Minify",
            "go-tools-minify-operation1.graphql",
        )
    )
    out.append(
        Upstream(
            GO,
            "v2/pkg/astnormalization/fragmentspread_depth_test.go",
            "BenchmarkFragmentSpreadDepthCalc_Get",
            "go-tools/FragmentSpreadDepth",
            "the nested operation, in the benchmark source",
        )
    )
    out.append(
        Upstream(
            JS,
            "benchmark/validateSDL-benchmark.js",
            "Validate SDL Document",
            "graphql-js/validate-sdl",
            "github-schema.graphql",
        )
    )
    out.append(
        Upstream(
            JS,
            "benchmark/validateGQL-benchmark.js",
            "Validate Introspection Query",
            "graphql-js/validate-introspection-query",
            "graphql-js-introspection-query.graphql",
        )
    )
    out.append(
        Upstream(
            JS,
            "benchmark/validateInvalidGQL-benchmark.js",
            "Validate Invalid Query",
            "graphql-js/validate-invalid-query",
            "github-schema.graphql",
        )
    )
    out.append(
        Upstream(
            COMPILER,
            "benches/fields_validation.rs",
            "many_same_field",
            "apollo-compiler/many_same_field",
            "built by the benchmark",
        )
    )
    out.append(
        Upstream(
            COMPILER,
            "benches/fields_validation.rs",
            "many_same_nested_field",
            "apollo-compiler/many_same_nested_field",
            "built by the benchmark",
        )
    )
    out.append(
        Upstream(
            COMPILER,
            "benches/fields_validation.rs",
            "many_arguments",
            "apollo-compiler/many_arguments",
            "built by the benchmark",
        )
    )
    out.append(
        Upstream(
            COMPILER,
            "benches/fields_validation.rs",
            "many_types",
            "apollo-compiler/many_types",
            "built by the benchmark",
        )
    )
    out.append(
        Upstream(
            COMPILER,
            "benches/fields_validation.rs",
            "many_extensions",
            "apollo-compiler/many_extensions",
            "built by the benchmark",
        )
    )
    out.append(
        Upstream(
            COMPILER,
            "benches/fragments_validation.rs",
            "big_schema_many_fragments",
            "apollo-compiler/big_schema_many_fragments",
            "built by the benchmark",
        )
    )
    out.append(
        Upstream(
            COMPILER,
            "benches/directives_validation.rs",
            "many_same_directive_query",
            "apollo-compiler/many_same_directive_query",
            "built by the benchmark",
        )
    )
    out.append(
        Upstream(
            COMPILER,
            "benches/directives_validation.rs",
            "many_invalid_directive",
            "apollo-compiler/many_invalid_directive",
            "built by the benchmark",
        )
    )
    out.append(
        Upstream(
            JS,
            "benchmark/introspectionFromSchema-benchmark.js",
            "Execute Introspection Query",
            "graphql-js/execute-introspection-query",
            "github-schema.graphql, graphql-js-introspection-query.graphql",
        )
    )
    out.append(
        Upstream(
            JS,
            "benchmark/repeated-fields-benchmark.js",
            "Many repeated fields (parse and execute; no validation)",
            "graphql-js/repeated-fields-parse-execute",
            "built by the benchmark",
        )
    )
    out.append(
        Upstream(
            JS,
            "benchmark/buildClientSchema-benchmark.js",
            "Build Schema from Introspection",
            "graphql-js/build-client-schema",
            "github-schema.json",
        )
    )
    return out^


def pending() -> List[String]:
    """Return the upstream benchmarks that need packages not yet ported.

    Returns:
        One Markdown table row per upstream benchmark file.
    """
    var out = List[String]()
    out.append(
        "| graphql-js | `visit-benchmark.js`, `visitInParallel-benchmark.js`"
        " | Visit all AST nodes; in parallel | a visitor in gql_language |"
    )
    out.append(
        "| apollo-compiler | `benches/multi_source.rs` | simple_query"
        " parse_and_validate; supergraph parse_and_validate | gql_schema and"
        " gql_validation |"
    )
    out.append(
        "| apollo-compiler | `benches/directives_validation.rs` |"
        " many_same_directive (a schema check, not a document check) |"
        " gql_schema schema validation |"
    )
    out.append(
        "| graphql-go-tools | `v2/pkg/astvisitor`, `v2/pkg/astvalidation`,"
        " `v2/pkg/introspection`, `v2/pkg/middleware/operation_complexity` |"
        " 8 benchmarks | a visitor, gql_validation and gql_schema |"
    )
    return out^


def suite_of(workload: String) -> String:
    """Return the suite of a workload id: the part before the slash.

    Args:
        workload: Such as `go-tools/Lexer`.

    Returns:
        Such as `go-tools`.
    """
    var slash = workload.find("/")
    if slash < 0:
        return workload
    return String(workload[byte=:slash])


def in_suite_order(workloads: List[String]) -> List[String]:
    """Order workloads by suite: shared first, then each upstream project.

    Workloads of the same suite keep their run order. A suite that is not
    listed comes last.

    Args:
        workloads: The workload ids, in run order.

    Returns:
        The same ids, grouped by suite.
    """
    var suites: List[String] = [
        "shared",
        "graphql-js",
        "apollo-parser",
        "apollo-compiler",
        "go-tools",
        "apollo-kotlin",
    ]
    var out = List[String]()
    for ref suite in suites:
        for ref workload in workloads:
            if suite_of(workload) == suite:
                out.append(workload)
    for ref workload in workloads:
        if not suite_of(workload) in suites:
            out.append(workload)
    return out^


def report(
    results: List[Measurement],
    workloads: List[String],
    names: List[String],
    packages: List[String],
    mojo: String,
) raises -> String:
    """Write the Markdown report.

    Args:
        results: Every measurement.
        workloads: The Mojo workloads, in run order.
        names: The baseline names, in report order.
        packages: The packages that were measured.
        mojo: The Mojo executable.

    Returns:
        The text of `bench/RESULTS.md`.

    Raises:
        Error: If a command for the machine description cannot be started.
    """
    var out = String("# Benchmark results\n\n")
    out += (
        "Generated by `make bench` on "
        + first_line("date -u +%Y-%m-%d")
        + " for "
        + ", ".join(packages)
        + ". Do not edit this file by hand.\n\n"
    )
    out += (
        "Each number is the time of one operation, in microseconds: the"
        " fastest of 5 rounds of at least one second each, after a warm-up."
        " The speedup is the baseline time divided by the Mojo time. A"
        " speedup above 1.00x means that Mojo is faster. Every implementation"
        " runs every workload that its library can express. `n/a` means that"
        " the library cannot do the operation.\n\n"
    )
    var losses = 0
    var tightest = Float64.MAX
    var tightest_text = String("")
    for ref workload in workloads:
        var mojo = find(results, "Mojo", workload)
        for ref name in names:
            var other = find(results, name, workload)
            if other < 0:
                continue
            if other < mojo:
                losses += 1
            if other / mojo < tightest:
                tightest = other / mojo
                tightest_text = "`" + workload + "` against " + name
    if losses == 0:
        out += "Mojo is the fastest on every workload."
    else:
        out += (
            "Mojo is slower than a baseline in "
            + String(losses)
            + " comparisons."
        )
    out += (
        " The smallest speedup is "
        + fixed(tightest, 2)
        + "x, on "
        + tightest_text
        + ".\n"
    )

    var has_11 = find(results, "Mojo 1.1.0", workloads[0]) >= 0
    out += "\n## Summary\n"
    var suite = String("")
    for ref workload in workloads:
        if suite_of(workload) != suite:
            suite = suite_of(workload)
            if has_11:
                out += (
                    "\n### "
                    + suite
                    + "\n\n| Workload | Mojo 1.2 (µs) | Mojo 1.1 (µs) | 1.2 vs"
                    " 1.1 |"
                )
            else:
                out += "\n### " + suite + "\n\n| Workload | Mojo (µs) |"
            for ref name in names:
                out += " " + name + " |"
            if has_11:
                out += "\n|---|---:|---:|---:|"
            else:
                out += "\n|---|---:|"
            for _ in range(len(names)):
                out += "---:|"
            out += "\n"
        var mojo = find(results, "Mojo", workload)
        out += "| `" + workload + "` | " + fixed(mojo / 1000.0, 2) + " |"
        if has_11:
            var mojo11 = find(results, "Mojo 1.1.0", workload)
            if mojo11 < 0:
                out += " n/a | n/a |"
            else:
                out += (
                    " "
                    + fixed(mojo11 / 1000.0, 2)
                    + " | "
                    + fixed(mojo11 / mojo, 2)
                    + "x |"
                )
        for ref name in names:
            var other = find(results, name, workload)
            if other < 0:
                out += " n/a |"
            else:
                out += " " + fixed(other / mojo, 2) + "x |"
        out += "\n"
    out += "\nThe baseline columns hold the speedup of Mojo.\n"

    out += (
        "\n## Upstream-published benchmarks\n\nThese workloads replicate the"
        " benchmarks that the upstream projects publish, with the same input"
        " and the same timed operation. Work that an upstream benchmark does"
        " outside its timer is also outside ours. The fixtures are"
        " byte-for-byte copies; `bench/fixtures/README.md` gives the revision"
        " of each.\n\n"
        "| Project | File | Upstream benchmark | Workload | Fixture |\n"
        "|---|---|---|---|---|\n"
    )
    for ref entry in upstream():
        out += (
            "| "
            + entry.project
            + " | `"
            + entry.file
            + "` | "
            + entry.benchmark
            + " | `"
            + entry.workload
            + "` | "
            + entry.fixture
            + " |\n"
        )
    out += (
        "\nThe `shared/*` workloads are MojoGraphQL's own: `parse-*` parses a"
        " text, `parse-print-*` parses it and prints it again, as graphql-js"
        " `print(parse(text))`, and `print-*` prints a document parsed"
        " outside the timer.\n"
    )
    out += (
        "\n### Pending\n\nThese upstream benchmarks need parts of MojoGraphQL"
        " that are not ported yet. They are not run.\n\n"
        "| Project | File | Upstream benchmarks | Needs |\n"
        "|---|---|---|---|\n"
    )
    for ref row in pending():
        out += row + "\n"
    out += (
        "\nThe graphql-go-tools `v2/pkg/engine` benchmarks measure its query"
        " planner and HTTP resolver, and `fastbuffer`, `internal/unsafebytes`"
        " and `netpoll` measure Go utilities. They have no counterpart in a"
        " GraphQL language library.\n"
    )

    out += "\n## Details\n"
    for ref workload in workloads:
        var mojo = find(results, "Mojo", workload)
        out += "\n### `" + workload + "`\n\n"
        out += "| Implementation | Time (µs) | Speedup of Mojo |\n"
        out += "|---|---:|---:|\n"
        if has_11:
            out += (
                "| MojoGraphQL (Mojo 1.2.0) | "
                + fixed(mojo / 1000.0, 2)
                + " | |\n"
            )
            var mojo11 = find(results, "Mojo 1.1.0", workload)
            if mojo11 >= 0:
                out += (
                    "| MojoGraphQL (Mojo 1.1.0) | "
                    + fixed(mojo11 / 1000.0, 2)
                    + " | "
                    + fixed(mojo11 / mojo, 2)
                    + "x |\n"
                )
        else:
            out += (
                "| MojoGraphQL (Mojo) | " + fixed(mojo / 1000.0, 2) + " | |\n"
            )
        for ref name in names:
            var other = find(results, name, workload)
            if other < 0:
                continue
            out += (
                "| "
                + name
                + " | "
                + fixed(other / 1000.0, 2)
                + " | "
                + fixed(other / mojo, 2)
                + "x |\n"
            )
    out += "\n## Machine\n\n" + machine(mojo)
    out += (
        "\nThe fixtures are in `bench/fixtures/`. The baselines are in"
        " `bench/baselines/`, pinned by their lockfiles and built in release"
        " mode.\n"
    )
    out += (
        "\n## Method\n\n"
        "- Every program reads the same fixture bytes and runs one operation"
        " at a time.\n"
        "- The lexer workloads read every token to the end of the file."
        " apollo-parser also returns whitespace and comment tokens, because"
        " its tree is lossless. gql_language, graphql-js and"
        " graphql-go-tools skip them.\n"
        "- The apollo-parser walks are the upstream `parse_query` and"
        " `parse_schema`. They visit the selection set of each top-level"
        " field, or the type of each object type field. The other"
        " implementations do the same visit over their own trees.\n"
        "- apollo-parser builds a lossless syntax tree (CST). It has no"
        " printer, so it has no print results. A plain parse is"
        " `Parser::new(text).parse()` and a check that there are no errors.\n"
        "- apollo-compiler parses with `ast::Document::parse`, which runs"
        " apollo-parser and converts the CST to an AST. It prints with the"
        " `Display` of the AST. It has no lexer of its own.\n"
        "- graphql-go-tools reuses one parser and one document for all"
        " operations, as its benchmarks do and its documentation tells hot"
        " paths to do. `go-tools/Print` uses `Printer{}` into a reused"
        " buffer, as `BenchmarkPrint` does: a compact form on one line. The"
        " other print workloads use `PrintStringIndent` with two spaces, the"
        " layout of graphql-js. gql_language, graphql-js and apollo-compiler"
        " always print the multi-line layout, which is more output.\n"
        "- gql_language and graphql-go-tools decode string values when a"
        " program reads them, not during the parse. graphql-js and"
        " apollo-compiler decode during the parse. The print workloads"
        " decode every string in all implementations.\n"
    )
    return out^


def main() raises:
    """Run the benchmarks, write the report, and check it with `--check`."""
    var args = argv()
    var index = 1
    var check = False
    if index < len(args) and String(args[index]) == "--check":
        check = True
        index += 1
    if index >= len(args):
        raise Error("usage: bench [--check] <mojo> <package>...")
    var mojo = String(args[index])
    index += 1
    var packages = List[String]()
    for position in range(index, len(args)):
        packages.append(String(args[position]))

    var results = List[Measurement]()
    var workloads = List[String]()
    for ref package in packages:
        for ref program in mojo_benches(package):
            for ref result in run_mojo(mojo, program):
                if result.implementation == "Mojo":
                    if result.workload in workloads:
                        raise Error("two programs measure " + result.workload)
                    workloads.append(result.workload)
                results.append(result.copy())
    workloads = in_suite_order(workloads)
    if len(workloads) == 0:
        print("No benchmarks in bench/ for:", " ".join(packages))
        return

    var names = List[String]()
    for ref baseline in baselines():
        if not serves(baseline, packages):
            continue
        names.append(baseline.name)
        results.extend(run_baseline(baseline))

    Path(RESULTS).write_text(report(results, workloads, names, packages, mojo))
    print("wrote", RESULTS)

    var losses = List[String]()
    for ref workload in workloads:
        var mojo = find(results, "Mojo", workload)
        print("BENCH", workload, "Mojo", fixed(mojo, 1), "ns")
        for ref name in names:
            var other = find(results, name, workload)
            if other < 0:
                continue
            var line = (
                "  "
                + name
                + " "
                + fixed(other, 1)
                + " ns ("
                + fixed(other / mojo, 2)
                + "x)"
            )
            if other < mojo:
                line += "  SLOWER"
                losses.append(
                    name
                    + " beats Mojo on "
                    + workload
                    + ": "
                    + fixed(other, 1)
                    + " ns against "
                    + fixed(mojo, 1)
                    + " ns"
                )
            print(line)
    if check and len(losses) > 0:
        for ref loss in losses:
            print(loss)
        raise Error(
            String(len(losses)) + " workloads where Mojo is not the fastest"
        )
    if check:
        print("Mojo is the fastest on every workload.")
