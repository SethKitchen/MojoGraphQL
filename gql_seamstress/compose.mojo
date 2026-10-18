# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""`seamstress supergraph compose`, the port of `rover supergraph compose`.

Port of Rover `src/command/supergraph/compose/do_compose.rs` and
`output.rs`, of the subgraph resolution of `src/composition/supergraph/
config`, and of the composition errors of `src/composition/mod.rs`. The
steps and their messages are the upstream ones:

1. read the configuration, and write `merging supergraph schema files`;
2. refuse federation 1, with `E064`;
3. warn when the federation version is not an exact version;
4. resolve each subgraph: read its file relative to the configuration,
   introspect its `subgraph_url`, or take its `sdl`;
5. compose, and print the supergraph SDL, or the build errors with `E029`.

**Differences from upstream.** Rover runs the Elastic licensed
`supergraph` plugin to compose. This port runs `gql_composition`, the
Hive Federation Composition port, so the supergraph SDL and the error
messages are the Hive ones, and there are no hints. The JSON output lists
no plugins, and its `federation_version` is the requested version, such
as `2` or `=2.3.0`. A `graphref` source needs GraphOS, so it fails. A
configuration that cannot be read or does not match the format is an
error; Rover warns and continues with an empty configuration. Environment
variables in the configuration are not expanded, because the upstream
expansion code is Elastic licensed.
"""

from std.pathlib import cwd
from std.os.path import exists
from gql_composition.compose import compose_subgraphs
from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.validate import Subgraph
from gql_http.client import Client
from gql_language.parser import parse
from gql_seamstress.config import (
    SchemaSourceKind,
    SubgraphConfig,
    SupergraphConfig,
)
from gql_seamstress.config import parse_supergraph_config
from gql_seamstress.federation_version import FEDERATION_ONE_UNSUPPORTED
from gql_seamstress.federation_version import (
    FederationVersion,
    FederationVersionKind,
)
from gql_seamstress.introspect import fetch_subgraph_sdl
from gql_seamstress.output import CommandResult, RoverError, json_string

comptime MERGING = "merging supergraph schema files\n"
"""The notice that Rover writes when it reads the configuration."""

comptime FLOATING_VERSION_WARNING = (
    "warning: federation_version isn't pinned to an exact version, so each run"
    " composes with the latest release available at the time. A new federation"
    " release can change your supergraph schema, or need a newer router than"
    " you're running. Pin an exact version (e.g. federation_version: =2.x.y)"
    " and update your router before raising it. See"
    " https://www.apollographql.com/docs/rover/commands/supergraphs#setting-a-composition-version"
    " for more information.\n"
)
"""The warning for a federation version that is not exact."""

comptime ERRORS_PAGE = "https://www.apollographql.com/docs/federation/errors/"
"""The page that the `E029` suggestion names."""


def absolute_path(path: StringSlice) raises -> String:
    """Return a path as an absolute path, without `.` and `..` parts.

    Args:
        path: A path, relative to the working directory or absolute.

    Returns:
        The absolute path.

    Raises:
        Error: If the working directory cannot be read.
    """
    var full = (
        String(path) if path.startswith("/") else String(cwd()) + "/" + path
    )
    var parts = List[String]()
    var pieces = full.split("/")
    var next = 0
    while next < len(pieces):
        var part = pieces[next]
        next += 1
        if part == "" or part == ".":
            continue
        if part == "..":
            if len(parts) > 0:
                _ = parts.pop()
            continue
        parts.append(String(part))
    return "/" + String("/").join(parts)


def _parent(path: String) -> String:
    """Return the directory of an absolute path."""
    var slash = path.rfind("/")
    return String(path[byte=:slash]) if slash > 0 else String("/")


def _load_error(cause: String) -> RoverError:
    """Return the error of a configuration that cannot be read."""
    var error = RoverError.of("Failed to load the supergraph config")
    error.causes.append("Failed to deserialise the supergraph config")
    error.causes.append(cause)
    error.data = '"plugins":[]'
    return error^


@fieldwise_init
struct Resolved(Movable):
    """The SDL of one subgraph, or the reason it could not be read."""

    var sdl: String
    """The SDL."""
    var routing_url: Optional[String]
    """The routing URL."""
    var failure: String
    """The upstream error chain, joined by `: `; empty for success."""


def _resolve(
    subgraph: SubgraphConfig, root: String, mut client: Client
) raises -> Resolved:
    """Resolve the SDL of one subgraph, as upstream `FullyResolvedSubgraph`."""
    ref schema = subgraph.schema
    var url = subgraph.routing_url.copy()
    if schema.kind == SchemaSourceKind.SDL:
        return Resolved(schema.sdl, url^, "")
    if schema.kind == SchemaSourceKind.FILE:
        var path = (
            schema.file if schema.file.startswith("/") else root
            + "/"
            + schema.file
        )
        var failure = (
            "Could not find schema file ("
            + schema.file
            + ") relative to ("
            + root
            + ") for subgraph `"
            + subgraph.name
            + "`: "
        )
        if not exists(path):
            return Resolved(
                "", url^, failure + "No such file or directory (os error 2)"
            )
        try:
            with open(path, "r") as file:
                return Resolved(file.read(), url^, "")
        except e:
            return Resolved("", url^, failure + String(e))
    if schema.kind == SchemaSourceKind.SUBGRAPH_INTROSPECTION:
        var fetched = fetch_subgraph_sdl(
            client, schema.subgraph_url, schema.introspection_headers
        )
        if fetched.error:
            ref error = fetched.error.value()
            var chain = List[String]()
            chain.append(error.message)
            for ref cause in error.causes:
                chain.append(cause)
            return Resolved(
                "",
                url^,
                'Failed to introspect the subgraph "'
                + subgraph.name
                + '": '
                + String(": ").join(chain),
            )
        return Resolved(fetched.sdl, url.or_else(schema.subgraph_url), "")
    return Resolved(
        "",
        url^,
        "Failed to fetch the sdl for subgraph `"
        + subgraph.name
        + "` from remote: GraphOS is not available offline",
    )


def build_errors_json(errors: List[CompositionError]) -> String:
    """Return the JSON of upstream `BuildErrors` for composition errors.

    Args:
        errors: The errors.

    Returns:
        `{"build_errors":[...]}`, each error with its `message`, `code`,
        `type`, `nodes` and `omittedNodesCount`.
    """
    var items = List[String]()
    var index = 0
    while index < len(errors):
        ref error = errors[index]
        index += 1
        var code = json_string(
            error.code.text()
        ) if error.code != ErrorCode.NONE else String("null")
        items.append(
            '{"message":'
            + json_string(error.message)
            + ',"code":'
            + code
            + ',"type":"composition","nodes":[],"omittedNodesCount":null}'
        )
    return '{"build_errors":[' + String(",").join(items) + "]}"


def composition_error(errors: List[CompositionError]) -> RoverError:
    """Return upstream `CompositionError::Build` for composition errors.

    Args:
        errors: The errors; at least one.

    Returns:
        The `E029` error, with each error as `CODE: message`.
    """
    var count = len(errors)
    var noun = (
        "1 build error" if count == 1 else String(count) + " build errors"
    )
    var error = RoverError.of(
        "Encountered " + noun + " while trying to build a supergraph."
    )
    var lines = String()
    var index = 0
    while index < len(errors):
        ref item = errors[index]
        index += 1
        var code = String(
            item.code.text()
        ) if item.code != ErrorCode.NONE else String("UNKNOWN")
        lines += code + ": " + item.message + "\n"
    error.causes.append(lines^)
    error.code = "E029"
    var prefix = (
        "The subgraph schema you provided is invalid." if count
        == 1 else "The subgraph schemas you provided are incompatible with each other."
    )
    error.suggestions.append(
        prefix
        + " See "
        + ERRORS_PAGE
        + " for more information on resolving build errors."
    )
    error.details = build_errors_json(errors)
    error.data = '"plugins":[]'
    return error^


def supergraph_compose(
    config_path: StringSlice,
    config_text: Optional[String],
    federation_version: Optional[FederationVersion],
) raises -> CommandResult:
    """Run `seamstress supergraph compose`.

    Args:
        config_path: The `--config` path; `-` for standard input.
        config_text: The text of standard input, for `-`.
        federation_version: The `--federation-version`, if it is set.

    Returns:
        The supergraph SDL, or the error.

    Raises:
        Error: An error that `gql_composition` raises.
    """
    var stderr = String(MERGING)
    var text: String
    var root: String
    try:
        if config_path == "-":
            text = config_text.or_else("")
            root = absolute_path(".")
        else:
            var path = absolute_path(config_path)
            root = _parent(path)
            if not exists(path):
                var missing = RoverError.of(
                    "Failed to load the supergraph config"
                )
                missing.causes.append(
                    "Could not read the supergraph config at "
                    + path
                    + ": No such file or directory (os error 2)"
                )
                missing.data = '"plugins":[]'
                return CommandResult.failure(missing^, stderr)
            with open(path, "r") as file:
                text = file.read()
    except e:
        return CommandResult.failure(_load_error(String(e)), stderr)
    var config: SupergraphConfig
    try:
        config = parse_supergraph_config(text)
    except e:
        var message = String(e)
        if message == FEDERATION_ONE_UNSUPPORTED:
            return CommandResult.failure(_federation_one(), stderr)
        return CommandResult.failure(_load_error(message), stderr)
    var version = federation_version.copy()
    if not version:
        version = config.federation_version.copy()
    var resolved_version = (
        version.value().copy() if version else FederationVersion(
            FederationVersionKind.LATEST_FED_TWO, ""
        )
    )
    if resolved_version.is_fed_one():
        return CommandResult.failure(_federation_one(), stderr)
    if not resolved_version.kind.is_exact():
        stderr += FLOATING_VERSION_WARNING
    return _compose(config, root, String(resolved_version), stderr)


def _federation_one() -> RoverError:
    """Return the error of a federation 1 version."""
    var error = RoverError.of(FEDERATION_ONE_UNSUPPORTED)
    error.code = "E064"
    error.data = '"plugins":[]'
    return error^


def _compose(
    config: SupergraphConfig, root: String, version: String, stderr: String
) raises -> CommandResult:
    """Resolve the subgraphs and compose them."""
    var client = Client()
    var failures = List[String]()
    var subgraphs = List[Subgraph]()
    var syntax = List[CompositionError]()
    for ref subgraph in config.subgraphs:
        var resolved = _resolve(subgraph, root, client)
        if resolved.failure != "":
            failures.append(subgraph.name + ": " + resolved.failure)
            continue
        try:
            subgraphs.append(
                Subgraph(
                    subgraph.name, resolved.routing_url, parse(resolved.sdl)
                )
            )
        except e:
            syntax.append(
                CompositionError(
                    "[" + subgraph.name + "] " + e.message,
                    ErrorCode.INVALID_GRAPHQL,
                    subgraph.name,
                )
            )
    if len(failures) > 0:
        var error = RoverError.of("Error resolving subgraphs")
        error.causes.append(
            "Unable to resolve subgraphs.\n" + String("\n").join(failures)
        )
        error.data = '"plugins":[]'
        return CommandResult.failure(error^, stderr)
    if len(syntax) > 0:
        return CommandResult.failure(composition_error(syntax), stderr)
    if len(subgraphs) == 0:
        # Hive `composeServices([])` reports `NO_QUERIES`; gql_composition
        # does not accept an empty list, so the error is made here.
        syntax.append(
            CompositionError(
                (
                    "No queries found in any subgraph: a supergraph must have a"
                    " query root type."
                ),
                ErrorCode.NO_QUERIES,
                None,
            )
        )
        return CommandResult.failure(composition_error(syntax), stderr)
    var result = compose_subgraphs(subgraphs)
    if len(result.errors) > 0:
        return CommandResult.failure(composition_error(result.errors), stderr)
    var members = (
        '"core_schema":'
        + json_string(result.supergraph_sdl)
        + ',"hints":[],"federation_version":'
        + json_string(version)
        + ',"plugins":[]'
    )
    return CommandResult(
        None, result.supergraph_sdl, members, "Supergraph Schema", stderr
    )
