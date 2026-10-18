# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The command line of seamstress, the offline Rover commands.

Port of the clap definitions of Rover `src/cli.rs`, `src/options/output.rs`,
`src/options/introspect.rs`, `src/command/supergraph/compose/do_compose.rs`
and `src/command/graph/introspect.rs`, for these commands:

    seamstress supergraph compose --config <SUPERGRAPH_YAML> [--federation-version <V>]
    seamstress subgraph introspect <ENDPOINT> [--header <KEY:VALUE>]...
    seamstress graph introspect <ENDPOINT> [--header <KEY:VALUE>]...
                           [--legacy-introspection-query]

The global options `--format <plain|json>`, `--output <FILE>` (`-o`),
`--no-color`, `--log <LEVEL>` (`-l`), `--profile <NAME>`,
`--skip-update-check` and `--insecure-accept-invalid-certs` can come
anywhere. A usage error is written as clap writes it, with exit code 2.

**Differences from upstream.** Only the commands above exist. `--watch`,
`--graph-ref` and the other GraphOS options are refused, because they need
GraphOS. `--log` and `--profile` take a value and do nothing.
"""

from gql_seamstress.compose import absolute_path, supergraph_compose
from gql_seamstress.config import Header, is_url, normalize_url
from gql_seamstress.federation_version import FederationVersion
from gql_seamstress.federation_version import parse_federation_version
from gql_seamstress.introspect import graph_introspect, subgraph_introspect
from gql_seamstress.output import CommandOutput, CommandResult, OutputFormat

comptime VERSION = "seamstress 1.0.0"
"""What `--version` prints: the upstream version that this port follows."""

comptime HELP = """seamstress - the local commands of Apollo Rover

Usage: seamstress [OPTIONS] <COMMAND>

Commands:
  supergraph  Supergraph schema commands
  subgraph    Subgraph schema commands
  graph       Graph API schema commands

Options:
      --format <FORMAT_KIND>  [default: plain] [possible values: plain, json]
  -o, --output <OUTPUT_FILE>
      --no-color
  -h, --help                  Print help
  -V, --version               Print version
"""
"""The help text."""

comptime _HINT = "\nFor more information, try '--help'.\n"
"""The last line of a clap error."""


def usage_error(message: String, usage: String = "") -> CommandOutput:
    """Return a clap usage error.

    Args:
        message: The text after `error: `.
        usage: The usage line, such as `seamstress graph introspect <ENDPOINT>`;
            empty for none.

    Returns:
        The error on standard error, with exit code 2.
    """
    var text = "error: " + message + "\n"
    if usage != "":
        text += "\nUsage: " + usage + "\n"
    return CommandOutput("", text + _HINT, 2)


def _invalid(value: String, flag: String, reason: String) -> CommandOutput:
    """Return the clap error of a value that a parser refused."""
    return usage_error(
        "invalid value '" + value + "' for '" + flag + "': " + reason
    )


def parse_header(header: StringSlice) -> Optional[Header]:
    """Read a `--header` value, as Rover `parse_header`.

    Args:
        header: Such as `Authorization:Bearer x`.

    Returns:
        The name before the first `:`, and the value after it without the
        spaces around it; None when there is no `:`.
    """
    var colon = header.find(":")
    if colon < 0:
        return None
    var value = String(header[byte = colon + 1 :]).strip(" \t")
    return Header(String(header[byte=:colon]), String(value))


@fieldwise_init
struct _Globals(Copyable, Movable):
    """The global options."""

    var format: OutputFormat
    """The `--format`."""
    var output: Optional[String]
    """The absolute `--output` path."""


def _flag_value(
    args: List[String], mut index: Int, name: String
) -> Optional[String]:
    """Return the value of `--name value` or `--name=value` at `index`, and
    move `index` past it; None when the token is not that flag."""
    ref token = args[index]
    if token.startswith(name + "="):
        index += 1
        return String(token[byte = name.byte_length() + 1 :])
    if token == name and index + 1 < len(args):
        index += 2
        return args[index - 1].copy()
    return None


def _unexpected(token: String, usage: String) -> CommandOutput:
    """Return the clap error of an argument that a command does not take."""
    var message = "unexpected argument '" + token + "' found"
    if token.startswith("-"):
        message += (
            "\n\n  tip: to pass '"
            + token
            + "' as a value, use '-- "
            + token
            + "'"
        )
    return usage_error(message, usage)


def _missing(argument: String, usage: String) -> CommandOutput:
    """Return the clap error of a required argument that is missing."""
    return usage_error(
        "the following required arguments were not provided:\n  " + argument,
        usage,
    )


def _introspect(
    group: String, args: List[String], globals: _Globals
) raises -> CommandOutput:
    """Parse and run `seamstress subgraph introspect` or `seamstress graph
    introspect`."""
    var usage = "seamstress " + group + " introspect <ENDPOINT>"
    var endpoint = Optional[String](None)
    var headers = List[Header]()
    var legacy = False
    var index = 0
    while index < len(args):
        var token = args[index].copy()
        var value = _flag_value(args, index, "--header")
        if not value:
            value = _flag_value(args, index, "-H")
        if value:
            var header = parse_header(value.value())
            if not header:
                return _invalid(
                    value.value(),
                    "--header <KEY:VALUE>",
                    'Could not parse "key:value" pair for provided header: "'
                    + value.value()
                    + '". Headers must be provided in key:value pairs, with'
                    " quotes around the pair if there are any spaces in the"
                    " key or value.",
                )
            headers.append(header.take())
            continue
        index += 1
        if group == "graph" and token == "--legacy-introspection-query":
            legacy = True
        elif token.startswith("-") or endpoint:
            return _unexpected(token, usage)
        else:
            endpoint = token^
    if not endpoint:
        return _missing("<ENDPOINT>", usage)
    var url = endpoint.value()
    if not is_url(url):
        return _invalid(url, "<ENDPOINT>", "relative URL without a base")
    var normalized = normalize_url(url)
    var result: CommandResult
    if group == "graph":
        result = graph_introspect(normalized, headers, legacy, globals.format)
    else:
        result = subgraph_introspect(normalized, headers, globals.format)
    return result.render(globals.format, globals.output)


def _compose(
    args: List[String], globals: _Globals, stdin: Optional[String]
) raises -> CommandOutput:
    """Parse and run `seamstress supergraph compose`."""
    var usage = (
        "seamstress supergraph compose <--config <SUPERGRAPH_YAML>|--graph-ref"
        " <GRAPH_REF>>"
    )
    var config = Optional[String](None)
    var version = Optional[FederationVersion](None)
    var index = 0
    while index < len(args):
        var path = _flag_value(args, index, "--config")
        if path:
            config = path^
            continue
        var text = _flag_value(args, index, "--federation-version")
        if text:
            try:
                version = parse_federation_version(text.value())
            except e:
                return _invalid(
                    text.value(),
                    "--federation-version <FEDERATION_VERSION>",
                    String(e),
                )
            continue
        if _flag_value(args, index, "--elv2-license"):
            continue
        var token = args[index].copy()
        index += 1
        if token != "--skip-update":
            return _unexpected(token, usage)
    if not config:
        return _missing(
            "<--config <SUPERGRAPH_YAML>|--graph-ref <GRAPH_REF>>", usage
        )
    var result = supergraph_compose(config.value(), stdin, version)
    return result.render(globals.format, globals.output)


def run_seamstress(
    args: List[String], stdin: Optional[String] = None
) raises -> CommandOutput:
    """Run a Rover command line.

    Args:
        args: The arguments, without the program name, such as
            `["supergraph", "compose", "--config", "supergraph.yaml"]`.
        stdin: The text of standard input, for `--config -`.

    Returns:
        The standard output, the standard error and the exit code.

    Raises:
        Error: If the `--output` file cannot be written.
    """
    var globals = _Globals(OutputFormat.PLAIN, None)
    var rest = List[String]()
    var index = 0
    while index < len(args):
        var format = _flag_value(args, index, "--format")
        if format:
            if format.value() == "json":
                globals.format = OutputFormat.JSON
            elif format.value() == "plain":
                globals.format = OutputFormat.PLAIN
            else:
                return usage_error(
                    "invalid value '"
                    + format.value()
                    + "' for '--format <FORMAT_KIND>'\n  [possible values:"
                    " plain, json]"
                )
            continue
        var output = _flag_value(args, index, "--output")
        if not output:
            output = _flag_value(args, index, "-o")
        if output:
            globals.output = absolute_path(output.value())
            continue
        if (
            _flag_value(args, index, "--log")
            or _flag_value(args, index, "-l")
            or _flag_value(args, index, "--profile")
        ):
            continue
        var token = args[index].copy()
        index += 1
        var switches: List[String] = [
            "--no-color",
            "--skip-update-check",
            "--insecure-accept-invalid-certs",
        ]
        if not token in switches:
            rest.append(token^)
    if len(rest) == 0:
        return CommandOutput("", HELP, 2)
    if rest[0] == "--help" or rest[0] == "-h" or rest[0] == "help":
        return CommandOutput(HELP, "", 0)
    if rest[0] == "--version" or rest[0] == "-V":
        return CommandOutput(VERSION + "\n", "", 0)
    var tail = List[String]()
    for position in range(2, len(rest)):
        tail.append(rest[position])
    var sub = rest[1] if len(rest) > 1 else String("")
    if rest[0] == "supergraph" and sub == "compose":
        return _compose(tail, globals, stdin)
    if (rest[0] == "subgraph" or rest[0] == "graph") and sub == "introspect":
        return _introspect(rest[0], tail, globals)
    var unknown = (
        rest[1] if rest[0] in ["supergraph", "subgraph", "graph"]
        and len(rest) > 1 else rest[0]
    )
    return usage_error(
        "unrecognized subcommand '" + unknown + "'",
        "seamstress [OPTIONS] <COMMAND>",
    )
