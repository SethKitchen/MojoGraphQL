# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""GraphQL operations as MCP tools.

Port of Apollo MCP Server 2.0.0 (04e4e6e)
`crates/apollo-mcp-server/src/operations/operation.rs`, the
`RawOperation` of `operations/raw_operation.rs` and the `OperationError`
of `errors.rs`.

`Operation.from_raw` parses exactly one named operation, and makes its
tool: the description from the operation's description, its leading
comments or the schema; the JSON Schema of its variables; the JSON Schema
of its result, when `enable_output_schema` is set; and the annotations.
The operation is not validated against the schema: the GraphQL endpoint
does that when it executes the operation.

Differences from upstream:

- A syntax error has the message of `gql_language` (graphql-js), not of
  apollo-parser, after `Could not parse GraphQL document: `.
- The server writes no log lines. Upstream logs a skipped unnamed,
  mutation or subscription operation, and the character count of each
  tool; `tool_character_length` returns that count.
- `@private` is detected and removed from the text that the server sends,
  as upstream does. The response filter and the output schema without the
  private fields are phase 2, so the output schema still lists them.
- The two regular expressions of upstream (`(?m)^\\s*\\(` and
  `(\\n|^)(\\s*,*)*#`) are hand-written matchers. Their `\\s` is ASCII white
  space; Rust `regex` also matches Unicode white space there.
- `RawOperation` has no collection or manifest constructor (phase 2).
- The generated description reads a root field from the root type of any
  kind. Upstream reads it only from an object type; the root types of a
  valid schema are object types.
- `ensure_properties_exists` has no port: the input schema always has its
  `properties` member here.
"""

from gql_json.value import JsonKind
from gql_language.ast import Document, Kind, NO_NODE, OperationType, Role
from gql_language.parser import parse
from gql_language.source import Source
from gql_mcp.executable_descriptions import node_description
from gql_mcp.executable_descriptions import non_blank_description
from gql_mcp.executable_descriptions import strip_executable_descriptions
from gql_mcp.custom_scalar_map import CustomScalarMap
from gql_mcp.executable_print import (
    PrintOptions,
    print_definition,
    print_document,
)
from gql_mcp.json_tree import JsonTree
from gql_mcp.output_schema import selection_set_to_schema
from gql_mcp.schema_walker import ast_type_ref, type_to_schema
from gql_mcp.tool import (
    AnnotationOverrides,
    MutationMode,
    Tool,
    ToolAnnotations,
)
from gql_mcp.tree_shake import DepthLimit, SchemaTreeShaker
from gql_schema.definition import NO_TYPE, Schema, TypeKind, TypeRef


struct OperationErrorKind(Equatable, ImplicitlyCopyable):
    """The kind of an `OperationError`, as the upstream enum variants."""

    var value: UInt8
    """The kind's number."""

    comptime GRAPHQL_DOCUMENT = OperationErrorKind(0)
    """The text is not a GraphQL document."""
    comptime INTERNAL = OperationErrorKind(1)
    """An internal error."""
    comptime MISSING_NAME = OperationErrorKind(2)
    """The operation has no name."""
    comptime NO_OPERATIONS = OperationErrorKind(3)
    """The document has no operation."""
    comptime JSON = OperationErrorKind(4)
    """A JSON value is not valid."""
    comptime TOO_MANY_OPERATIONS = OperationErrorKind(5)
    """The document has more than one operation."""
    comptime FILE = OperationErrorKind(6)
    """A file could not be read."""
    comptime MANIFEST = OperationErrorKind(7)
    """A persisted-query manifest could not be fetched."""

    def __init__(out self, value: UInt8):
        """Make a kind from its number.

        Args:
            value: The number.
        """
        self.value = value

    def is_valid(self) -> Bool:
        """Return whether the kind is one of the eight kinds.

        Returns:
            True for a known kind.
        """
        return self.value <= 7


@fieldwise_init
struct OperationError(Copyable, Movable, Writable):
    """An error in operation parsing, as upstream `OperationError`."""

    var kind: OperationErrorKind
    """The kind."""
    var message: String
    """The detail: the parse error, the operation text, or the cause."""
    var source_path: Optional[String]
    """The file of the operation, if any."""
    var count: Int
    """The number of operations, for `TOO_MANY_OPERATIONS`."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the message that upstream `Display` writes.

        Args:
            writer: The writer.
        """
        if self.kind == OperationErrorKind.GRAPHQL_DOCUMENT:
            writer.write("Could not parse GraphQL document: ", self.message)
        elif self.kind == OperationErrorKind.INTERNAL:
            writer.write("Internal error: ", self.message)
        elif self.kind == OperationErrorKind.JSON:
            writer.write("Invalid JSON: ", self.message)
        elif self.kind == OperationErrorKind.MANIFEST:
            writer.write(
                "Error fetching persisted-query manifest: ", self.message
            )
        elif self.kind == OperationErrorKind.FILE:
            writer.write(self.message)
        else:
            if self.source_path:
                writer.write(self.source_path.value(), ": ")
            if self.kind == OperationErrorKind.MISSING_NAME:
                writer.write(
                    "Operation is missing its required name: ", self.message
                )
            elif self.kind == OperationErrorKind.NO_OPERATIONS:
                writer.write("No operations defined")
            else:
                writer.write(
                    "Too many operations. Expected 1 but got ", self.count
                )


def _error(
    kind: OperationErrorKind,
    var message: String,
    source_path: Optional[String] = None,
    count: Int = 0,
) -> OperationError:
    """Make an `OperationError`."""
    return OperationError(kind, message^, source_path.copy(), count)


@fieldwise_init
struct RawOperation(Copyable, Movable):
    """The text of one operation before it becomes a tool."""

    var source_text: String
    """The GraphQL text."""
    var source_path: Optional[String]
    """The file it comes from, if any."""
    var variables: Optional[JsonTree]
    """Variables that the operation fixes; the tool does not ask for them."""
    var headers: List[Tuple[String, String]]
    """Headers that the operation adds to each request."""

    def __init__(
        out self, var source_text: String, var source_path: Optional[String]
    ):
        """Make an operation from text, as upstream `From<(String,
        Option<String>)>`.

        Args:
            source_text: The GraphQL text.
            source_path: The file it comes from, if any.
        """
        self.source_text = source_text^
        self.source_path = source_path^
        self.variables = None
        self.headers = List[Tuple[String, String]]()


@fieldwise_init
struct OperationDefs(Copyable, Movable):
    """The one operation of a document, as upstream `operation_defs`
    returns it."""

    var document: Document
    """The parsed document, fragments included."""
    var operation: Int
    """The operation definition's node."""
    var comments: Optional[String]
    """The source text between the previous definition and the operation."""


def _is_space(byte: UInt8) -> Bool:
    """Whether a byte is ASCII white space, as regex `\\s`."""
    return byte == 32 or (byte >= 9 and byte <= 13)


def extract_and_format_comments(comments: Optional[String]) -> Optional[String]:
    """Turn the `#` comments before an operation into a description.

    Each run of white space and commas that starts the text or follows a
    line break, and that ends with `#`, is removed, as the upstream
    replacement of `(\\n|^)(\\s*,*)*#` with `$1`. The result is trimmed.

    Args:
        comments: The text before the operation, if any.

    Returns:
        The description, or `None` when nothing is left.
    """
    if not comments:
        return None
    var bytes = comments.value().as_bytes()
    var out = List[UInt8](capacity=len(bytes))
    var index = 0
    while index <= len(bytes):
        if index == 0 or bytes[index - 1] == 10:
            var scan = index
            while scan < len(bytes) and (
                _is_space(bytes[scan]) or bytes[scan] == 44
            ):
                scan += 1
            if scan < len(bytes) and bytes[scan] == 35:
                index = scan + 1
                continue
        if index < len(bytes):
            out.append(bytes[index])
        index += 1
    var text = String(unsafe_from_utf8=out)
    var trimmed = String(text.strip())
    if trimmed.byte_length() == 0:
        return None
    return trimmed^


def operation_defs(
    source_text: String, allow_mutations: Bool, source_path: Optional[String]
) raises OperationError -> Optional[OperationDefs]:
    """Parse exactly one operation and leave out the refused types.

    Fragments can sit beside the operation. A subscription, and a mutation
    when `allow_mutations` is not set, give `None`. The document is only
    parsed; it is not validated against a schema.

    Args:
        source_text: The GraphQL text.
        allow_mutations: Whether a mutation can become a tool.
        source_path: The file of the text, for the messages.

    Returns:
        The document, the operation and the comments before it, or `None`.

    Raises:
        OperationError: `GRAPHQL_DOCUMENT` for a syntax error,
            `NO_OPERATIONS` and `TOO_MANY_OPERATIONS`.
    """
    var name = String("operation.graphql")
    if source_path:
        name = source_path.value().copy()
    var document: Document
    try:
        document = parse(Source(source_text, name))
    except e:
        raise _error(OperationErrorKind.GRAPHQL_DOCUMENT, String(e))
    var definitions = document.definitions()
    var last_offset = 0
    var found = NO_NODE
    var comments = String()
    var count = 0
    var index = 0
    while index < len(definitions):
        var definition = definitions[index]
        index += 1
        var start = document.start(definition)
        var before = String(document.source.slice(last_offset, start))
        last_offset = document.end(definition)
        if document.kind(definition) == Kind.OPERATION_DEFINITION:
            count += 1
            if count == 1:
                found = definition
                comments = before^
    if count == 0:
        raise _error(OperationErrorKind.NO_OPERATIONS, String(), source_path)
    if count > 1:
        raise _error(
            OperationErrorKind.TOO_MANY_OPERATIONS, String(), source_path, count
        )
    var operation_type = document.operation(found)
    if operation_type == OperationType.SUBSCRIPTION:
        return None
    if operation_type == OperationType.MUTATION and not allow_mutations:
        return None
    return OperationDefs(document^, found, comments^)


def operation_name(
    document: Document, operation: Int, source_path: Optional[String]
) raises OperationError -> String:
    """Return the name of an operation.

    Args:
        document: The document.
        operation: The operation definition's node.
        source_path: The file of the text, for the message.

    Returns:
        The name.

    Raises:
        OperationError: `MISSING_NAME`, with the operation on one line.
    """
    var name = document.child(operation, Role.NAME)
    if name == NO_NODE:
        raise _error(
            OperationErrorKind.MISSING_NAME,
            print_definition(document, operation),
            source_path,
        )
    return String(document.text(name))


def find_opening_parens_offset(
    source_text: String, document: Document, operation: Int
) -> Optional[Int]:
    """Return the offset after the `(` of the variable list.

    This is the first match of `(?m)^\\s*\\(` after the operation's name:
    a `(` with only white space before it on its line, or right after the
    name.

    Args:
        source_text: The GraphQL text.
        document: The parsed document.
        operation: The operation definition's node.

    Returns:
        The offset after the match, 0 when nothing matches, or `None` when
        the operation has no name.
    """
    var name = document.child(operation, Role.NAME)
    if name == NO_NODE:
        return None
    var bytes = source_text.as_bytes()
    var begin = document.end(name)
    var at = begin
    while at < len(bytes):
        if at == begin or bytes[at - 1] == 10:
            var scan = at
            while scan < len(bytes) and _is_space(bytes[scan]):
                scan += 1
            if scan < len(bytes) and bytes[scan] == 40:
                return scan + 1
        at += 1
    return 0


def variable_description_overrides(
    source_text: String, document: Document, operation: Int
) -> Dict[String, String]:
    """Return the description of each variable that has one in the
    operation: its own description, or else the `#` comments before it.

    Args:
        source_text: The GraphQL text.
        document: The parsed document.
        operation: The operation definition's node.

    Returns:
        The descriptions, by variable name.
    """
    var overrides = Dict[String, String]()
    var last_offset = find_opening_parens_offset(
        source_text, document, operation
    )
    var variable = document.child(operation, Role.VARIABLE_DEFINITION)
    while variable != NO_NODE:
        var name = String(
            document.name(document.child(variable, Role.VARIABLE))
        )
        var description = non_blank_description(
            node_description(document, variable)
        )
        if not description and last_offset:
            var comment = String(
                document.source.slice(
                    last_offset.value(), document.start(variable)
                )
            )
            if comment.byte_length() > 0 and "#" in comment:
                description = extract_and_format_comments(comment)
        if description:
            overrides[name] = description.value()
        last_offset = document.end(variable)
        variable = document.next_with_role(variable)
    return overrides^


def _type_description(schema: Schema, type: TypeRef) -> String:
    """Describe the type a root field returns, as upstream
    `type_description`."""
    var optional = "" if type.is_non_null() else "is optional and "
    var outer = type.of_type() if type.is_non_null() else type
    var array = "is an array of type" if outer.is_list() else "has type"
    var named = String(schema.types[Int(type.named)].name)
    return "The returned value " + optional + array + " `" + named + "`"


def _root_field_lines(
    schema: Schema, document: Document, operation: Int
) -> String:
    """Describe each root field the operation selects: its description and
    its type, separated by `---` lines."""
    var root = schema.root_type(document.operation(operation).value)
    var out = String()
    var first = True
    var selection = document.first_child(
        document.child(operation, Role.SELECTION_SET)
    )
    while selection != NO_NODE:
        var is_field = document.kind(selection) == Kind.FIELD
        if is_field and root != NO_TYPE:
            if not first:
                out += "\n---\n"
            first = False
            var field = schema.field_named(root, document.name(selection))
            if field != NO_TYPE:
                ref definition = schema.fields[field]
                if definition.description.exists():
                    out += schema.description_text(definition.description)
                    out += "\n"
                out += _type_description(schema, definition.type)
        selection = document.next_sibling(selection)
    return out^


def tool_description(
    comments: Optional[String],
    shaker: SchemaTreeShaker,
    schema: Schema,
    document: Document,
    operation: Int,
    disable_type_description: Bool,
    disable_schema_description: Bool,
) -> String:
    """Make a tool description from the operation's description, its
    leading comments, or the schema, in that order.

    Args:
        comments: The text before the operation.
        shaker: The tree shaking that kept what the operation selects.
        schema: The schema.
        document: The document.
        operation: The operation definition's node.
        disable_type_description: Leave out the root fields' descriptions.
        disable_schema_description: Leave out the types the operation uses.

    Returns:
        The description.
    """
    var own = non_blank_description(node_description(document, operation))
    if own:
        return own.value()
    var extracted = extract_and_format_comments(comments)
    if extracted:
        return extracted.value()
    var lines = List[String]()
    if not disable_type_description:
        lines.append(_root_field_lines(schema, document, operation))
    if not disable_schema_description:
        var shaken = shaker.shaken(schema)
        var root = schema.root_type(document.operation(operation).value)
        var query = schema.root_type(OperationType.QUERY.value)
        var index = 0
        var any = False
        while index < shaken.type_count():
            var type = shaken.type_index(index)
            var kind = schema.types[type].kind
            if kind != TypeKind.INPUT_OBJECT and type != root and type != query:
                if not any:
                    lines.append("---")
                    any = True
                lines.append(shaken.serialize_type(schema, index))
            index += 1
    return String("\n").join(lines)


def get_json_schema(
    document: Document,
    operation: Int,
    argument_descriptions: Dict[String, List[String]],
    description_overrides: Dict[String, String],
    schema: Schema,
    custom_scalars: CustomScalarMap,
    variable_overrides: Optional[JsonTree],
) -> JsonTree:
    """Make the JSON Schema of an operation's variables, as upstream
    `get_json_schema`, with the keyword order of `serde_json::to_value`.

    A variable that `variable_overrides` sets is not in the schema. A
    non-null variable without a default is required.

    Args:
        document: The document.
        operation: The operation definition's node.
        argument_descriptions: The descriptions of the arguments that each
            variable fills, from the tree shaker.
        description_overrides: The descriptions from the operation text.
        schema: The schema.
        custom_scalars: The schemas of custom scalars.
        variable_overrides: Variables the operation fixes, if any.

    Returns:
        The schema; its root is an object.
    """
    var tree = JsonTree()
    tree.root = tree.add_object()
    tree.set(tree.root, "type", tree.add_string("object"))
    var properties = tree.add_object()
    tree.set(tree.root, "properties", properties)
    var definitions = tree.add_object()
    var variable = document.child(operation, Role.VARIABLE_DEFINITION)
    while variable != NO_NODE:
        var name = String(
            document.name(document.child(variable, Role.VARIABLE))
        )
        var fixed = False
        if variable_overrides:
            ref overrides = variable_overrides.value()
            fixed = overrides.find(overrides.root, name) != NO_NODE
        if not fixed:
            var description: Optional[String] = None
            if name in description_overrides:
                description = description_overrides.get(name).value()
            else:
                var joined = argument_descriptions.get(name, List[String]())
                if len(joined) > 0:
                    description = String("#").join(joined)
            var type_node = document.child(variable, Role.TYPE)
            var default = document.child(variable, Role.DEFAULT_VALUE)
            var nested = type_to_schema(
                tree,
                definitions,
                schema,
                ast_type_ref(schema, document, type_node),
                custom_scalars,
                description,
                document,
                default,
            )
            tree.set(properties, name, nested)
            if document.kind(type_node) == Kind.NON_NULL_TYPE and (
                default == NO_NODE
            ):
                var required = tree.entry(
                    tree.root, "required", tree.add_array()
                )
                tree.push(required, tree.add_string(name))
        variable = document.next_with_role(variable)
    if tree.length(definitions) > 0:
        tree.set(tree.root, "definitions", definitions)
    tree.order_schema(tree.root)
    return tree^


def tool_character_length(tool: Tool) -> Int:
    """Return the characters a tool costs a model: its name, description and
    pretty-printed schemas, as upstream `tool_character_length`.

    Args:
        tool: The tool.

    Returns:
        The count of bytes.
    """
    var length = tool.name.byte_length()
    if tool.description:
        length += tool.description.value().byte_length()
    length += tool.input_schema.to_string(
        tool.input_schema.root, 2
    ).byte_length()
    if tool.output_schema:
        ref output = tool.output_schema.value()
        length += output.to_string(output.root, 2).byte_length()
    return length


def _has_private(document: Document, selection_set: Int) -> Bool:
    """Whether a field reachable from a selection set has `@private`, as
    upstream `collect_private_fields(...).has_private_fields()`."""
    var visited = List[String]()
    var stack = List[Int]()
    stack.append(selection_set)
    while len(stack) > 0:
        var selection = document.first_child(stack.pop())
        while selection != NO_NODE:
            var kind = document.kind(selection)
            if kind == Kind.FRAGMENT_SPREAD:
                var name = String(document.name(selection))
                var fragment = _fragment(document, name)
                if fragment != NO_NODE and not (name in visited):
                    visited.append(name)
                    stack.append(document.child(fragment, Role.SELECTION_SET))
            else:
                if kind == Kind.FIELD and _is_private(document, selection):
                    return True
                var inner = document.child(selection, Role.SELECTION_SET)
                if inner != NO_NODE:
                    stack.append(inner)
            selection = document.next_sibling(selection)
    return False


def _is_private(document: Document, field: Int) -> Bool:
    """Whether a field has the `@private` directive."""
    var directive = document.child(field, Role.DIRECTIVE)
    while directive != NO_NODE:
        if document.name(directive) == "private":
            return True
        directive = document.next_with_role(directive)
    return False


def _fragment(document: Document, name: StringSlice) -> Int:
    """Return the last fragment definition with a name, or `NO_NODE`."""
    var found = NO_NODE
    var definitions = document.definitions()
    var index = 0
    while index < len(definitions):
        var definition = definitions[index]
        if document.kind(definition) == Kind.FRAGMENT_DEFINITION and (
            document.name(definition) == name
        ):
            found = definition
        index += 1
    return found


struct Operation(Copyable, Movable):
    """A named GraphQL operation, exposed as an MCP tool."""

    var tool: Tool
    """The tool of the operation."""
    var name: String
    """The operation's name, which is the tool's name."""
    var raw: RawOperation
    """The operation as it was loaded."""
    var stripped_source_text: Optional[String]
    """The text without descriptions and `@private`, when it had some."""
    var has_private_fields: Bool
    """Whether a selected field has `@private`."""

    def __init__(
        out self,
        var tool: Tool,
        var name: String,
        var raw: RawOperation,
        var stripped_source_text: Optional[String],
        has_private_fields: Bool,
    ):
        """Make an operation from its parts.

        Args:
            tool: The tool.
            name: The operation's name.
            raw: The operation as it was loaded.
            stripped_source_text: The text to send, when it differs.
            has_private_fields: Whether a selected field has `@private`.
        """
        self.tool = tool^
        self.name = name^
        self.raw = raw^
        self.stripped_source_text = stripped_source_text^
        self.has_private_fields = has_private_fields

    @staticmethod
    def from_raw(
        var raw: RawOperation,
        schema: Schema,
        custom_scalars: CustomScalarMap,
        mutation_mode: MutationMode,
        disable_type_description: Bool,
        disable_schema_description: Bool,
        enable_output_schema: Bool,
        annotation_overrides: Dict[String, AnnotationOverrides],
        description_overrides: Dict[String, String],
    ) raises OperationError -> Optional[Operation]:
        """Make the tool of an operation, as upstream `Operation::from_raw`.

        Args:
            raw: The operation text.
            schema: The schema.
            custom_scalars: The schemas of custom scalars; empty for none.
            mutation_mode: Which mutations can become tools.
            disable_type_description: Leave the root fields out of the
                generated description.
            disable_schema_description: Leave the types out of the
                generated description.
            enable_output_schema: Add the JSON Schema of the result.
            annotation_overrides: Configured annotations, by operation name.
            description_overrides: Configured descriptions, by operation
                name.

        Returns:
            The operation, or `None` for a subscription, a refused mutation
            and an operation without a name.

        Raises:
            OperationError: When the text is not exactly one operation.
        """
        var found = operation_defs(
            raw.source_text,
            mutation_mode != MutationMode.NONE,
            raw.source_path,
        )
        if not found:
            return None
        ref defs = found.value()
        ref document = defs.document
        var operation = defs.operation
        if document.child(operation, Role.NAME) == NO_NODE:
            return None
        var name = String(document.name(operation))
        var variable_overrides = variable_description_overrides(
            raw.source_text, document, operation
        )
        var shaker = SchemaTreeShaker(schema)
        shaker.retain_operation(
            schema, document, operation, DepthLimit.UNLIMITED
        )
        var description: String
        if name in description_overrides:
            description = description_overrides.get(name).value()
        else:
            description = tool_description(
                defs.comments,
                shaker,
                schema,
                document,
                operation,
                disable_type_description,
                disable_schema_description,
            )
        var input = get_json_schema(
            document,
            operation,
            shaker.argument_descriptions(),
            variable_overrides,
            schema,
            custom_scalars,
            raw.variables,
        )
        var selections = document.child(operation, Role.SELECTION_SET)
        var has_private = _has_private(document, selections)
        var tool = Tool(name.copy(), description^, input^)
        var root = schema.root_type(document.operation(operation).value)
        if enable_output_schema and root != NO_TYPE:
            var output = JsonTree()
            output.root = selection_set_to_schema(
                output, schema, document, selections, root, custom_scalars
            )
            output.order_schema(output.root)
            tool.output_schema = output^
        var stripped_descriptions = strip_executable_descriptions(document)
        var stripped: Optional[String] = None
        if has_private or stripped_descriptions:
            stripped = print_document(document, PrintOptions(True, has_private))
        var is_query = document.operation(operation) != OperationType.MUTATION
        var idempotent: Optional[Bool] = None
        if is_query:
            idempotent = True
        var annotations = ToolAnnotations(
            None, is_query, not is_query, idempotent, True
        )
        if name in annotation_overrides:
            annotation_overrides.get(name).value().apply_to(annotations)
        tool.annotations = annotations^
        return Operation(tool^, name^, raw^, stripped^, has_private)

    def query(self) -> String:
        """Return the text to send to the endpoint, as the `query` of
        upstream `Executable::operation`.

        Returns:
            The text without descriptions and `@private`, or the source text.
        """
        if self.stripped_source_text:
            return self.stripped_source_text.value()
        return self.raw.source_text.copy()

    def variables(self, input: JsonTree, node: Int) raises -> JsonTree:
        """Return the variables to send: the tool's arguments and the
        variables that the operation fixes, as upstream
        `Executable::variables`.

        Args:
            input: The tree that holds the arguments.
            node: The arguments' value: an object or `null`.

        Returns:
            The variables; its root is the value to send.

        Raises:
            Error: When the arguments are not an object or `null`, or set a
                variable that the operation fixes.
        """
        var out = JsonTree()
        if not self.raw.variables:
            out.root = out.copy_from(input, node)
            return out^
        ref fixed = self.raw.variables.value()
        var kind = input.kind(node)
        if kind == JsonKind.OBJECT:
            out.root = out.copy_from(input, node)
        elif kind == JsonKind.NULL:
            out.root = out.add_object()
        else:
            raise Error("Variables must be a JSON object or null")
        var index = 0
        while index < fixed.length(fixed.root):
            var key = fixed.key(fixed.root, index)
            if out.find(out.root, key) != NO_NODE:
                raise Error(
                    "Parameter '"
                    + key
                    + "' conflicts with operation-defined variable"
                )
            out.set(
                out.root,
                key,
                out.copy_from(fixed, fixed.item(fixed.root, index)),
            )
            index += 1
        return out^

    def headers(
        self, defaults: List[Tuple[String, String]]
    ) -> List[Tuple[String, String]]:
        """Return the headers to send: the defaults, with the operation's
        headers in place of those of the same name, as upstream
        `Executable::headers`.

        Args:
            defaults: The headers of the server.

        Returns:
            The headers.
        """
        var out = defaults.copy()
        var index = 0
        while index < len(self.raw.headers):
            ref header = self.raw.headers[index]
            var name = header[0].lower()
            var at = 0
            while at < len(out) and out[at][0].lower() != name:
                at += 1
            if at < len(out):
                out[at] = header.copy()
            else:
                out.append(header.copy())
            index += 1
        return out^
