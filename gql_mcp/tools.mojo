# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The calls of the built-in tools.

The tools are `introspect`, `validate`, `execute` and `search`.

Port of the `execute` methods of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/introspection/tools/introspect.rs`,
`validate.rs`, `execute.rs` (`Executable::operation` and `variables`) and
`search.rs`. Arguments that do not fit the tool's `Input` struct give the
tool error `Invalid input: <message>`.

Differences from upstream:

- `validate` checks with `gql_validation`, so its error texts are the
  graphql-js messages, each as graphql-js `toString()` writes it, one per
  line group; the upstream writes apollo-compiler diagnostics. A syntax
  error is `Could not parse GraphQL document: ` and the `gql_language`
  message.
- `execute` reads a `variables` string with `gql_json`, so the text after
  `Invalid variables: ` is a `gql_json` message, not a `serde_json` one.
- `@private` fields are not stripped (phase 2).
"""

from gql_json.parser import parse
from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_language.ast import OperationType
from gql_schema.definition import NO_TYPE, Schema
from gql_validation.validate import validate
from gql_mcp.call_result import CallToolResult
from gql_mcp.graphql import normalized_json
from gql_language.error import GraphQLError
from gql_mcp.operation import OperationDefs, operation_defs, operation_name
from gql_mcp.tool import MutationMode
from gql_mcp.tool_input import FieldKind, InputField, check_input
from gql_mcp.schema_index import SchemaIndex, SearchOptions
from gql_mcp.tree_shake import DepthLimit, SchemaTreeShaker, ShakenSchema


def _invalid(message: String) -> CallToolResult:
    """Return the `Invalid input` error result."""
    return CallToolResult.error("Invalid input: " + message)


def _shaken_texts(
    schema: Schema,
    shaken: ShakenSchema,
    minify: Bool,
    skip_mutation: Bool,
    skip_subscription: Bool,
) -> List[String]:
    """Return the definitions of the shaken types that a tool shows."""
    var texts = List[String]()
    var mutation = schema.root_type(OperationType.MUTATION.value)
    var subscription = schema.root_type(OperationType.SUBSCRIPTION.value)
    var index = 0
    while index < shaken.type_count():
        var type = shaken.type_index(index)
        var shown = not schema.types[type].is_builtin
        if skip_mutation and type == mutation:
            shown = False
        if skip_subscription and type == subscription:
            shown = False
        if shown:
            if minify:
                texts.append(shaken.minify_type(schema, index))
            else:
                texts.append(shaken.serialize_type(schema, index))
        index += 1
    return texts^


def run_introspect(
    schema: Schema,
    document: JsonDocument,
    arguments: Int,
    allow_mutations: Bool,
    minify: Bool,
) -> CallToolResult:
    """Call `introspect`: the definition of a type and of the types it
    references, to a depth.

    Args:
        schema: The schema.
        document: The request document.
        arguments: The `arguments` object, or `NO_NODE`.
        allow_mutations: Whether the server exposes mutations; otherwise
            the mutation root type shows only when it is the asked type.
        minify: Whether to use the minified notation.

    Returns:
        One text block per type; none when the schema has no such type.
    """
    var fields = List[InputField]()
    fields.append(InputField("type_name", FieldKind.STRING, True))
    fields.append(InputField("depth", FieldKind.USIZE, False))
    try:
        check_input(document, arguments, fields)
    except e:
        return _invalid(String(e))
    var type_name = document.string_value(document.find(arguments, "type_name"))
    var depth = 1
    var depth_node = document.find(arguments, "depth")
    if depth_node != NO_NODE:
        depth = _count(document.text(depth_node))
    var type = schema.type_named(type_name)
    if type == NO_TYPE:
        return CallToolResult.success(List[String]())
    var shaker = SchemaTreeShaker(schema)
    var limit = DepthLimit.limited(depth) if depth > 0 else DepthLimit.UNLIMITED
    shaker.retain_type(schema, type, None, limit)
    var mutation = schema.root_type(OperationType.MUTATION.value)
    var skip_mutation = not allow_mutations and type != mutation
    return CallToolResult.success(
        _shaken_texts(
            schema, shaker.shaken(schema), minify, skip_mutation, True
        )
    )


def run_validate(
    schema: Schema, document: JsonDocument, arguments: Int
) -> CallToolResult:
    """Call `validate`: check one operation against the schema.

    Args:
        schema: The schema; it must be valid.
        document: The request document.
        arguments: The `arguments` object, or `NO_NODE`.

    Returns:
        `Operation is valid`, or an error result with the problems.
    """
    var fields = List[InputField]()
    fields.append(InputField("operation", FieldKind.STRING, True))
    try:
        check_input(document, arguments, fields)
    except e:
        return _invalid(String(e))
    var text = document.string_value(document.find(arguments, "operation"))
    var defs: Optional[OperationDefs]
    try:
        defs = operation_defs(text, True, None)
    except e:
        return CallToolResult.error(String(e))
    if not defs:
        return CallToolResult.error("Invalid operation type")
    var errors: List[GraphQLError]
    try:
        errors = validate(schema, defs.value().document)
    except e:
        return CallToolResult.error(String(e))
    if len(errors) == 0:
        var content = List[String]()
        content.append(String("Operation is valid"))
        return CallToolResult.success(content^)
    var message = String()
    var index = 0
    while index < len(errors):
        message += String(errors[index]) + "\n"
        index += 1
    return CallToolResult.error(message)


@fieldwise_init
struct ExecuteRequest(Copyable, Movable):
    """What `execute` sends: the operation, its name and its variables."""

    var query: String
    """The operation text, as the client gave it."""
    var operation_name: Optional[String]
    """The operation's name, when it has one."""
    var variables: String
    """The JSON text of the variables."""


def prepare_execute(
    document: JsonDocument, arguments: Int, mutation_mode: MutationMode
) raises -> ExecuteRequest:
    """Read the arguments of `execute`, as upstream `Executable::variables`
    and `Executable::operation`.

    Args:
        document: The request document.
        arguments: The `arguments` object, or `NO_NODE`.
        mutation_mode: The mode; only `ALL` permits a mutation.

    Returns:
        The request to send.

    Raises:
        Error: With the text of the tool error.
    """
    var fields = List[InputField]()
    fields.append(InputField("query", FieldKind.STRING, True))
    fields.append(InputField("variables", FieldKind.ANY, False))
    try:
        check_input(document, arguments, fields)
    except e:
        raise Error("Invalid input: " + String(e))
    var variables = String("null")
    var node = document.find(arguments, "variables")
    if node != NO_NODE:
        var kind = document.kind(node)
        if kind == JsonKind.STRING:
            var parsed: JsonDocument
            try:
                parsed = parse(document.string_value(node))
            except e:
                raise Error("Invalid variables: " + e.message)
            variables = _json_text(parsed, parsed.root)
        elif kind == JsonKind.OBJECT:
            variables = _json_text(document, node)
        elif kind != JsonKind.NULL:
            raise Error("Variables must be a JSON object or string")
    var query = document.string_value(document.find(arguments, "query"))
    var defs: Optional[OperationDefs]
    try:
        defs = operation_defs(query, mutation_mode == MutationMode.ALL, None)
    except e:
        raise Error(String(e))
    if not defs:
        raise Error("Invalid operation type")
    ref found = defs.value()
    var name: Optional[String] = None
    try:
        name = operation_name(found.document, found.operation, None)
    except:
        pass
    return ExecuteRequest(query^, name^, variables^)


def _json_text(document: JsonDocument, node: Int) raises -> String:
    """Return a value as `serde_json` writes it again."""
    var tree = normalized_json(document, node)
    return tree.to_string(tree.root)


def _count(text: StringSlice) -> Int:
    """Read a `usize` that `check_input` accepted; a count above the `Int`
    range is the largest `Int`, which means no practical limit."""
    var bytes = text.as_bytes()
    var value = 0
    var index = 0
    while index < len(bytes):
        var digit = Int(bytes[index]) - ord("0")
        if value > (Int.MAX - digit) // 10:
            return Int.MAX
        value = value * 10 + digit
        index += 1
    return value


comptime MAX_SEARCH_RESULTS = 5
"""The most paths that `search` keeps."""


def run_search(
    schema: Schema,
    index: SchemaIndex,
    document: JsonDocument,
    arguments: Int,
    allow_mutations: Bool,
    leaf_depth: Int,
    minify: Bool,
) -> CallToolResult:
    """Call `search`: the types that match the terms, with the types on
    their paths from a root type.

    Args:
        schema: The schema.
        index: The search index of the schema.
        document: The request document.
        arguments: The `arguments` object, or `NO_NODE`.
        allow_mutations: Whether the mutation root type can show.
        leaf_depth: How deep to follow the type at the end of each path.
        minify: Whether to use the minified notation.

    Returns:
        One text block per type.
    """
    var fields = List[InputField]()
    fields.append(InputField("terms", FieldKind.STRINGS, True))
    try:
        check_input(document, arguments, fields)
    except e:
        return _invalid(String(e))
    var terms = List[String]()
    var list = document.find(arguments, "terms")
    var item = document.first(list)
    while item != NO_NODE:
        terms.append(document.string_value(item))
        item = document.next(item)
    var paths = index.search(terms, SearchOptions())
    var shaker = SchemaTreeShaker(schema)
    var path = 0
    while path < len(paths) and path < MAX_SEARCH_RESULTS:
        ref segments = paths[path].inner.segments
        var at = 0
        while at < len(segments):
            ref segment = segments[at]
            # The index comes from this schema, so each name is a type of it.
            var type = schema.type_named(segment.node_type)
            if at == len(segments) - 1:
                shaker.retain_type(
                    schema, type, None, DepthLimit.limited(leaf_depth)
                )
            else:
                shaker.retain_type(
                    schema, type, segment.field_name, DepthLimit.limited(1)
                )
            for argument in segment.field_args:
                shaker.retain_type(
                    schema,
                    schema.type_named(argument),
                    None,
                    DepthLimit.UNLIMITED,
                )
            at += 1
        path += 1
    return CallToolResult.success(
        _shaken_texts(
            schema, shaker.shaken(schema), minify, not allow_mutations, False
        )
    )
