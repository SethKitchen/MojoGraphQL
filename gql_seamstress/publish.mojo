# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Publish, delete and list the subgraphs of a ScorchQL gateway.

Port of the output of `rover subgraph publish`, `rover subgraph delete
--confirm` and `rover subgraph list` in Rover `src/command/output.rs`, and
of the schema reading of `src/utils/parsers.rs`. Rover sends these
commands to the GraphOS registry. seamstress sends them to the registry of
a ScorchQL gateway (`gql_scorchql`):

| Command | Request |
| --- | --- |
| `subgraph publish` | `POST <gateway>/scorchql/publish` with `{name, url, sdl}` |
| `subgraph delete` | `POST <gateway>/scorchql/remove` with `{name}` |
| `subgraph list` | `GET <gateway>/scorchql/state` |

`publish` and `delete` send `Authorization: Bearer <token>` when a token
is set. The gateway composes the subgraphs, and refuses a subgraph that
does not compose.

**Differences from upstream.** The graph ref is the URL of the gateway,
not `<graph>@<variant>`. The token is `APOLLO_KEY` or `SCORCHQL_TOKEN`,
not a profile. Without `--schema`, the gateway reads the SDL from the
routing URL, where Rover needs a schema. A publish that does not compose
is an error, and the registry does not change; GraphOS keeps the subgraph
and reports build errors. `api_schema_hash` is the registry revision. No
launch is reported. `delete` needs `--confirm`, because seamstress does
not ask questions. `list` writes times in UTC, and has no Studio link.
"""

from std.os import getenv

from gql_http.client import Client
from gql_http.error import ErrorKind, HttpError
from gql_http.headers import Headers
from gql_http.status import Method
from gql_json.parser import parse as parse_json
from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_seamstress.graphql_client import service_error
from gql_seamstress.output import CommandResult, RoverError, json_string


@fieldwise_init
struct PublishedEntry(Copyable, Movable):
    """One subgraph in the registry of a gateway."""

    var name: String
    """The subgraph name."""
    var url: String
    """The routing URL."""
    var published_at: Int
    """When it was published, in seconds since 1970-01-01 UTC."""


def gateway_base(gateway: StringSlice) -> String:
    """Return the gateway URL without a final `/` or `/graphql`.

    Args:
        gateway: Such as `http://host:4000/graphql`.

    Returns:
        Such as `http://host:4000`.
    """
    var base = String(gateway)
    while base.endswith("/"):
        var shorter = String(base[byte = : base.byte_length() - 1])
        base = shorter^
    if base.endswith("/graphql"):
        var shorter = String(base[byte = : base.byte_length() - 8])
        base = shorter^
    while base.endswith("/"):
        var shorter = String(base[byte = : base.byte_length() - 1])
        base = shorter^
    return base^


def registry_token() -> Optional[String]:
    """Return the token of the gateway registry.

    Returns:
        `APOLLO_KEY`, else `SCORCHQL_TOKEN`; None when neither is set.
    """
    for name in ["APOLLO_KEY", "SCORCHQL_TOKEN"]:
        var value = getenv(name)
        if value != "":
            return value^
    return None


def read_schema(
    path: StringSlice, stdin: Optional[String]
) raises -> Tuple[String, Optional[RoverError]]:
    """Read the `--schema` value, as Rover `read_file_descriptor`.

    Args:
        path: A file path, or `-` for standard input.
        stdin: Standard input, when the program read it.

    Returns:
        The SDL and no error, or an empty SDL and the error.

    Raises:
        Error: Never; the file errors are returned.
    """
    var buffer: String
    if path == "-":
        if not stdin:
            return (String(""), RoverError.of("Failed to read SDL from stdin"))
        buffer = stdin.value()
    else:
        try:
            with open(path, "r") as file:
                buffer = file.read()
        except:
            return (
                String(""),
                RoverError.of("Invalid path. No file found at " + String(path)),
            )
    if buffer == "" or buffer == "\n" or buffer == "\r\n":
        var error = RoverError.of("The SDL you passed was empty")
        if path == "-":
            error.suggestions.append(
                "Make sure the command you are piping to seamstress contains"
                " output."
            )
        else:
            error.suggestions.append(
                "Make sure " + String(path) + " contains a schema."
            )
        return (String(""), error^)
    return (buffer^, None)


def _connect_error(e: HttpError) -> RoverError:
    """Return the error of a request that got no response."""
    var error = service_error("Upstream service error")
    error.causes.append(
        String("Connect error") if e.kind
        == ErrorKind.CONNECT else e.message.copy()
    )
    return error^


def _messages(text: StringSlice) -> List[String]:
    """Return the `errors[].message` values of a gateway answer."""
    var messages = List[String]()
    try:
        var document = parse_json(text)
        var errors = document.find(document.root, "errors")
        if errors != NO_NODE and document.kind(errors) == JsonKind.ARRAY:
            for item in document.children(errors):
                if document.kind(item) == JsonKind.STRING:
                    messages.append(document.string_value(item))
                    continue
                var message = document.find(item, "message")
                if (
                    message != NO_NODE
                    and document.kind(message) == JsonKind.STRING
                ):
                    messages.append(document.string_value(message))
    except:
        pass
    return messages^


def _refused(
    status: Int, text: StringSlice, gateway: StringSlice, subgraph: StringSlice
) -> RoverError:
    """Return the error of a gateway answer that is not a success."""
    var messages = _messages(text)
    if status == 401:
        var error = RoverError.of(
            "Invalid credentials provided. Set APOLLO_KEY or SCORCHQL_TOKEN"
            " to the token of the gateway."
        )
        error.causes = messages^
        return error^
    var error: RoverError
    if status == 422:
        error = RoverError.of(
            "The gateway '"
            + String(gateway)
            + "' refused the subgraph '"
            + String(subgraph)
            + "'."
        )
    else:
        error = RoverError.of(
            "The gateway '"
            + String(gateway)
            + "' answered HTTP "
            + String(status)
            + "."
        )
    if len(messages) == 0 and text.byte_length() > 0:
        messages.append(String(text))
    error.causes = messages^
    return error^


def _post(
    mut client: Client, url: StringSlice, body: StringSlice
) raises HttpError -> Tuple[Int, String]:
    """Send a JSON `POST`, with the token when one is set."""
    var endpoint = client.endpoint(url)
    var headers = Headers()
    headers.add("Content-Type", "application/json")
    var token = registry_token()
    if token:
        headers.add("Authorization", "Bearer " + token.value())
    var target = endpoint.target.copy()
    var response = client.send(
        endpoint, Method.POST, target, headers, body.as_bytes()
    )
    return (Int(response.status.code), response.text())


def _get(
    mut client: Client, url: StringSlice
) raises HttpError -> Tuple[Int, String]:
    """Send a `GET`."""
    var response = client.get(url)
    return (Int(response.status.code), response.text())


def read_state(text: StringSlice) raises -> List[PublishedEntry]:
    """Read the subgraphs of a `/scorchql/state` answer.

    Args:
        text: The answer body.

    Returns:
        The subgraphs, in the order of the answer.

    Raises:
        Error: When the body is not JSON or has no `subgraphs` list.
    """
    var document = parse_json(text)
    var list = document.find(document.root, "subgraphs")
    if list == NO_NODE or document.kind(list) != JsonKind.ARRAY:
        raise Error("the gateway state has no 'subgraphs' list")
    var entries = List[PublishedEntry]()
    for item in document.children(list):
        var name = document.find(item, "name")
        if name == NO_NODE or document.kind(name) != JsonKind.STRING:
            continue
        var url = document.find(item, "url")
        var at = document.find(item, "publishedAt")
        entries.append(
            PublishedEntry(
                document.string_value(name),
                document.string_value(url) if url != NO_NODE
                and document.kind(url) == JsonKind.STRING else String(""),
                Int(document.as_int64(at)) if at != NO_NODE
                and document.kind(at) == JsonKind.NUMBER else 0,
            )
        )
    return entries^


def _fetch_state(
    mut client: Client, base: StringSlice
) -> Tuple[List[PublishedEntry], Optional[RoverError]]:
    """Read the published subgraphs of a gateway."""
    var answer: Tuple[Int, String]
    try:
        answer = _get(client, String(base) + "/scorchql/state")
    except e:
        return (List[PublishedEntry](), _connect_error(e))
    if answer[0] != 200:
        return (
            List[PublishedEntry](),
            _refused(answer[0], answer[1], base, ""),
        )
    try:
        return (read_state(answer[1]), None)
    except e:
        var error = RoverError.of(
            "The gateway '" + String(base) + "' is not a ScorchQL gateway."
        )
        error.causes.append(String(e))
        return (List[PublishedEntry](), error^)


def _ok_answer(text: StringSlice) -> Tuple[Bool, Int]:
    """Read `changed` and `revision` of a publish or removal answer."""
    try:
        var document = parse_json(text)
        var changed = document.find(document.root, "changed")
        var revision = document.find(document.root, "revision")
        return (
            changed != NO_NODE
            and document.kind(changed) == JsonKind.BOOLEAN
            and document.bool_value(changed),
            Int(document.as_int64(revision)) if revision != NO_NODE
            and document.kind(revision) == JsonKind.NUMBER else 0,
        )
    except:
        return (False, 0)


def _null_or(text: Optional[String]) -> String:
    """Return a JSON string, or `null`."""
    return json_string(text.value()) if text else String("null")


def subgraph_publish(
    gateway: StringSlice,
    name: StringSlice,
    sdl: Optional[String],
    routing_url: Optional[String],
) -> CommandResult:
    """Publish a subgraph, as `rover subgraph publish`.

    Without a routing URL, the URL that the gateway has for the subgraph
    is used again. Without an SDL, the gateway reads it from the routing
    URL.

    Args:
        gateway: The URL of the gateway.
        name: The subgraph name.
        sdl: The subgraph SDL, or None.
        routing_url: The routing URL, or None.

    Returns:
        The Rover messages on standard error, and the publish JSON.
    """
    var base = gateway_base(gateway)
    var client = Client()
    var state = _fetch_state(client, base)
    if state[1]:
        return CommandResult.failure(state[1].value().copy())
    var known = Optional[String](None)
    for ref entry in state[0]:
        if entry.name == name:
            known = entry.url.copy()
    var url = routing_url.copy()
    if not url:
        if not known:
            var error = RoverError.of(
                "No routing URL is known for the new subgraph '"
                + String(name)
                + "'."
            )
            error.suggestions.append(
                "Pass the URL of the subgraph with --routing-url."
            )
            return CommandResult.failure(error^)
        url = known.copy()
    var token = registry_token()
    var stderr = (
        "Publishing SDL to "
        + base
        + " (subgraph: "
        + String(name)
        + ")"
        + (" using a registry token.\n" if token else ".\n")
    )
    var body = (
        '{"name":' + json_string(name) + ',"url":' + json_string(url.value())
    )
    if sdl:
        body += ',"sdl":' + json_string(sdl.value())
    body += "}"
    var answer: Tuple[Int, String]
    try:
        answer = _post(client, base + "/scorchql/publish", body)
    except e:
        return CommandResult.failure(_connect_error(e), stderr)
    if answer[0] != 200:
        return CommandResult.failure(
            _refused(answer[0], answer[1], base, name), stderr
        )
    var outcome = _ok_answer(answer[1])
    var changed = outcome[0]
    var created = changed and not known
    var hash = String(outcome[1])
    var text: String
    if created:
        text = (
            "A new subgraph called '"
            + String(name)
            + "' was created in '"
            + base
            + "' (#"
            + hash
            + ")"
        )
    elif changed:
        text = (
            "The '"
            + String(name)
            + "' subgraph in '"
            + base
            + "' was updated (#"
            + hash
            + ")"
        )
    else:
        text = (
            "The '"
            + String(name)
            + "' subgraph was NOT updated because no changes were detected"
        )
    if changed:
        text += (
            "\nThe supergraph schema for '"
            + base
            + "' was updated, composed from the updated '"
            + String(name)
            + "' subgraph"
        )
    else:
        text += (
            "\nThe supergraph schema for '"
            + base
            + "' was NOT updated with a new schema"
        )
    var flag = "true" if changed else "false"
    var members = (
        '"api_schema_hash":'
        + json_string(hash)
        + ',"supergraph_was_updated":'
        + flag
        + ',"subgraph_was_created":'
        + ("true" if created else "false")
        + ',"subgraph_was_updated":'
        + flag
        + ',"launch_url":null,"launch_cli_copy":null,"launch_status":null'
        + ',"launch_superseded":false,"downstream_launches":[]'
    )
    return CommandResult(None, text^, members^, "", stderr^)


def subgraph_delete(gateway: StringSlice, name: StringSlice) -> CommandResult:
    """Delete a subgraph, as `rover subgraph delete --confirm`.

    Args:
        gateway: The URL of the gateway.
        name: The subgraph name.

    Returns:
        The Rover message on standard error, and the delete JSON.
    """
    var base = gateway_base(gateway)
    var client = Client()
    var answer: Tuple[Int, String]
    try:
        answer = _post(
            client,
            base + "/scorchql/remove",
            '{"name":' + json_string(name) + "}",
        )
    except e:
        return CommandResult.failure(_connect_error(e))
    if answer[0] != 200:
        return CommandResult.failure(_refused(answer[0], answer[1], base, name))
    var changed = _ok_answer(answer[1])[0]
    var text: String
    if changed:
        text = (
            "The '"
            + String(name)
            + "' subgraph was removed from '"
            + base
            + "'. The remaining subgraphs were composed."
        )
    else:
        text = (
            "WARN: The supergraph schema for '"
            + base
            + "' was not updated. The '"
            + String(name)
            + "' subgraph is not published."
        )
    return CommandResult(
        None,
        text^,
        '"supergraph_was_updated":' + ("true" if changed else "false"),
        "",
        "",
    )


def _two(value: Int) -> String:
    """Format 0 to 99 with two digits."""
    return ("0" if value < 10 else "") + String(value)


def utc_time(seconds: Int) -> Tuple[String, String]:
    """Format a time, as Rover formats `updated_at`.

    Args:
        seconds: Seconds since 1970-01-01 UTC; not negative.

    Returns:
        `YYYY-MM-DD HH:MM:SS UTC` for the table, and the RFC 3339 text
        `YYYY-MM-DDTHH:MM:SSZ` for the JSON.
    """
    var days = seconds // 86400
    var rest = seconds % 86400
    # Howard Hinnant's civil_from_days, for days on or after 1970-01-01.
    var z = days + 719468
    var era = z // 146097
    var doe = z - era * 146097
    var yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    var doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    var mp = (5 * doy + 2) // 153
    var day = doy - (153 * mp + 2) // 5 + 1
    var month = mp + 3 if mp < 10 else mp - 9
    var year = yoe + era * 400 + (1 if month <= 2 else 0)
    var date = String(year) + "-" + _two(month) + "-" + _two(day)
    var clock = (
        _two(rest // 3600)
        + ":"
        + _two(rest % 3600 // 60)
        + ":"
        + _two(rest % 60)
    )
    return (date + " " + clock + " UTC", date + "T" + clock + "Z")


def _pad_center(text: String, width: Int) -> String:
    """Center a text in a width, as comfy-table centers a header."""
    var space = width - text.byte_length()
    var left = space // 2
    return String(" ") * left + text + String(" ") * (space - left)


def _rule(
    widths: List[Int], left: String, line: String, cross: String, right: String
) -> String:
    """Return one horizontal line of a table."""
    var out = String(left)
    for index in range(len(widths)):
        if index > 0:
            out += cross
        out += line * (widths[index] + 2)
    return out + right


def subgraph_table(entries: List[PublishedEntry]) -> String:
    """Return the table of `rover subgraph list`, in the comfy-table
    `UTF8_FULL` style.

    Args:
        entries: The subgraphs.

    Returns:
        The table, without a final line break.
    """
    var header: List[String] = ["Name", "Routing Url", "Last Updated"]
    var rows = List[List[String]]()
    for ref entry in entries:
        var url = entry.url.copy() if entry.url != "" else String("unspecified")
        var updated = utc_time(entry.published_at)[
            0
        ] if entry.published_at > 0 else String("N/A")
        rows.append([entry.name.copy(), url^, updated^])
    var widths = List[Int]()
    for column in range(3):
        var width = header[column].byte_length()
        for ref row in rows:
            width = max(width, row[column].byte_length())
        widths.append(width)
    var out = _rule(widths, "┌", "─", "┬", "┐") + "\n│"
    for column in range(3):
        if column > 0:
            out += "┆"
        out += " " + _pad_center(header[column], widths[column]) + " "
    out += "│\n" + _rule(widths, "╞", "═", "╪", "╡")
    for index in range(len(rows)):
        if index > 0:
            out += "\n" + _rule(widths, "├", "╌", "┼", "┤")
        out += "\n│"
        for column in range(3):
            if column > 0:
                out += "┆"
            ref cell = rows[index][column]
            out += (
                " "
                + cell
                + String(" ") * (widths[column] - cell.byte_length())
                + " "
            )
        out += "│"
    return out + "\n" + _rule(widths, "└", "─", "┴", "┘")


def subgraph_list(gateway: StringSlice) -> CommandResult:
    """List the subgraphs of a gateway, as `rover subgraph list`.

    Args:
        gateway: The URL of the gateway.

    Returns:
        The table, or the JSON of the subgraphs.
    """
    var base = gateway_base(gateway)
    var client = Client()
    var stderr = "Listing subgraphs for " + base + ".\n"
    var state = _fetch_state(client, base)
    if state[1]:
        return CommandResult.failure(state[1].value().copy(), stderr)
    var items = List[String]()
    for ref entry in state[0]:
        var updated = String("null")
        if entry.published_at > 0:
            var time = json_string(utc_time(entry.published_at)[1])
            updated = '{"local":' + time + ',"utc":' + time + "}"
        items.append(
            '{"name":'
            + json_string(entry.name)
            + ',"url":'
            + _null_or(
                entry.url.copy() if entry.url != "" else Optional[String](None)
            )
            + ',"updated_at":'
            + updated
            + "}"
        )
    return CommandResult(
        None,
        subgraph_table(state[0]),
        '"subgraphs":[' + String(",").join(items) + "]",
        "",
        stderr^,
    )
