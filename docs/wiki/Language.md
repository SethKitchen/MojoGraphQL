<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Language

`gql_language` reads, holds and prints GraphQL text. It is a port of graphql-js 16.14.2 `src/language`, and it needs only the Mojo standard library. The visitor is not ported yet.

| Module | Contents | graphql-js source |
| --- | --- | --- |
| `gql_language.source` | `Source`, `SourceLocation` | `source.ts`, `location.ts` |
| `gql_language.token_kind` | `TokenKind` | `tokenKind.ts` |
| `gql_language.lexer` | `Lexer`, `Token`, `read_comments` | `lexer.ts`, `characterClasses.ts` |
| `gql_language.parser` | `parse`, `parse_value`, `parse_const_value`, `parse_type`, `parse_schema_coordinate`, `ParseOptions` | `parser.ts` |
| `gql_language.ast` | `Document`, `Node`, `Kind`, `Role`, `OperationType` | `ast.ts`, `kinds.ts` |
| `gql_language.directive_location` | `DirectiveLocation` | `directiveLocation.ts` |
| `gql_language.printer` | `print_ast`, `print_node` | `printer.ts` |
| `gql_language.block_string` | `print_string`, `print_block_string` | `blockString.ts`, `printString.ts` |
| `gql_language.error` | `GraphQLError`, `PathSegment` | `GraphQLError.ts`, `syntaxError.ts`, `printLocation.ts` |
| `gql_language.strip_ignored_characters` | `strip_ignored_characters` | `utilities/stripIgnoredCharacters.ts` |
| `gql_language.concat_ast` | `concat_ast` | `utilities/concatAST.ts` |
| `gql_language.separate_operations` | `separate_operations`, `OperationDocument` | `utilities/separateOperations.ts` |
| `gql_language.get_operation_ast` | `get_operation_ast` | `utilities/getOperationAST.ts` |
| `gql_language.sort_value_node` | `sort_value_node` | `utilities/sortValueNode.ts`, `jsutils/naturalCompare.ts` |

## Parse functions

Each function returns a `Document`, and raises a `GraphQLError` for a syntax error. The grammar, the options and the error messages are the same as in graphql-js.

| Function | graphql-js | Root of the result |
| --- | --- | --- |
| `parse(source: Source, options)` | `parse` | A `Document` node |
| `parse(text: StringSlice, options)` | `parse` | A `Document` node |
| `parse_value(text, options)` | `parseValue` | A value node, which can hold variables |
| `parse_const_value(text, options)` | `parseConstValue` | A value node without variables |
| `parse_type(text, options)` | `parseType` | A `NamedType`, `ListType` or `NonNullType` node |
| `parse_schema_coordinate(text)` | `parseSchemaCoordinate` | A schema coordinate node |

The `text` overloads use the source name `GraphQL request`. To set another name or a location offset, make a `Source` and give it to `parse`. A schema coordinate has no white space, such as `Query.hero(episode:)`.

```mojo
from gql_language.parser import parse, parse_value, ParseOptions

var document = parse("{ hero { name } }")
var value = parse_value('{a: [1, "x", $v]}')
```

## ParseOptions

`ParseOptions()` gives the graphql-js defaults. Set a field to change one option.

| Field | Default | graphql-js option |
| --- | --- | --- |
| `max_tokens: Int` | `-1`, which is no limit | `maxTokens` |
| `allow_legacy_fragment_variables: Bool` | `False` | `allowLegacyFragmentVariables` |
| `experimental_directives_on_directive_definitions: Bool` | `False` | `experimentalDirectivesOnDirectiveDefinitions` |

When a document has more tokens than `max_tokens`, `parse` raises the graphql-js error: `Document contains more that N tokens. Parsing aborted.` The spelling of that message is the graphql-js spelling.

## Document

A `Document` holds a `Source` and all of its nodes in one `List[Node]`. A node is an `Int` index into that list. `NO_NODE`, which is `-1`, names no node.

| Field | Contents |
| --- | --- |
| `source: Source` | The source that the nodes come from |
| `nodes: List[Node]` | Every node; a parsed document is in preorder |
| `root: Int` | The root node: the `Document`, or the parsed value, type or coordinate |
| `token_count: Int` | How many tokens the parser read, as graphql-js `tokenCount` |

Each `Node` is 24 bytes: `kind`, `role`, `flags`, the byte range `start` and `end`, and the links `first`, `last` and `next`. The children of a node are in source order. That is also the order of graphql-js `QueryDocumentKeys`.

Each child has a `Role`, which is the graphql-js property of its parent that it fills. A list property, such as `arguments`, is the run of children with that role. For example, a `Field` node has children with the roles `ALIAS`, `NAME`, `ARGUMENT`, `DIRECTIVE` and `SELECTION_SET`.

### Read nodes

| Method | Returns |
| --- | --- |
| `kind(node)` | The `Kind` of the node |
| `role(node)` | The `Role` of the node |
| `first_child(node)`, `next_sibling(node)` | A child or a sibling, or `NO_NODE` |
| `child(node, role)` | The first child with the role, or `NO_NODE` |
| `children(node, role)` | All the children with the role, in order |
| `next_with_role(node)` | The next sibling with the same role, or `NO_NODE` |
| `count(node, role)` | How many children have the role |
| `start(node)`, `end(node)` | The byte offsets of graphql-js `loc.start` and `loc.end` |
| `location(node)` | The `SourceLocation` where the node starts |
| `text(node)` | The text of a `Name`, `IntValue`, `FloatValue` or `EnumValue`; the source text of a `StringValue` |
| `name(node)` | The text of the `NAME` child, or empty |
| `has_text(node, text)` | Whether the text of the node is equal to `text` |
| `string_value(node)` | The decoded value of a `StringValue`: escapes decoded, a block string dedented |
| `is_block(node)` | Whether a `StringValue` is a block string |
| `boolean_value(node)` | The value of a `BooleanValue` |
| `operation(node)` | The `OperationType` of an `OperationDefinition` or `OperationTypeDefinition` |
| `is_repeatable(node)` | Whether a `DirectiveDefinition` is `repeatable` |
| `description(node)`, `has_description(node)` | The decoded description of a definition, and whether it has one |
| `definitions()` | The definitions of the root `Document` node |
| `named_type(node)` | The name under the list and non-null wrappers of a type reference |

`text` and `name` return a `StringSlice` into the source, without a copy. `string_value` and `description` decode on each call, and return a new `String`.

```mojo
from gql_language.ast import Role

for definition in document.definitions():
    var selections = document.child(definition, Role.SELECTION_SET)
    for field in document.children(selections, Role.SELECTION):
        print(document.name(field), document.location(field))
```

### Build nodes

`Document()` makes an empty document whose root is a `Document` node. Use these methods to add nodes to it, or to a parsed document.

| Method | What it does |
| --- | --- |
| `add(kind, role, flags=0)` | Adds a node without a parent, and returns its index |
| `add_text(kind, role, text, flags=0)` | Adds a node with text: a name, a number, an enum value, or the decoded value of a string |
| `append_child(parent, child)` | Makes a node without a parent the last child of `parent` |
| `add_child(parent, kind, role, flags=0)` | Adds a node as the last child of `parent` |
| `add_name(parent, role, text)` | Adds a `Name` node as the last child of `parent` |
| `copy_subtree(other, node, role)` | Copies a node and its descendants from another document, and returns the copy without a parent |

The flags are `FLAG_BLOCK` for a block string, `FLAG_TRUE` for a true `BooleanValue` and `FLAG_REPEATABLE` for a repeatable directive. For an operation, the low two bits of `flags` hold the `OperationType` value. Added text goes after the source bytes, and the node gets `FLAG_EXTRA`.

## Kind

`Kind` is the kind of a node, as graphql-js `Kind`. It has 49 values, from `Kind.NAME` to `Kind.DIRECTIVE_ARGUMENT_COORDINATE`. `text()` gives the graphql-js string, such as `Field`.

| Method | True for |
| --- | --- |
| `is_valid()` | One of the 49 kinds |
| `is_executable_definition()` | `OperationDefinition` and `FragmentDefinition` |
| `is_type_definition()`, `is_type_extension()` | The six type definitions, or the six type extensions |
| `is_type_system_definition()`, `is_type_system_extension()` | A schema, type or directive definition, or extension |
| `is_value()` | A value literal or a `Variable`, as graphql-js `ValueNode` |
| `is_type()` | `NamedType`, `ListType` and `NonNullType` |
| `is_selection()` | `Field`, `FragmentSpread` and `InlineFragment` |
| `is_schema_coordinate()` | The five schema coordinate kinds |

## Role

`Role` is the property of its parent that a node fills. `text()` gives the graphql-js property name.

| Role | Property | Role | Property |
| --- | --- | --- | --- |
| `ROOT` | the root | `FIELD` | `fields` |
| `DEFINITION` | `definitions` | `SELECTION_SET` | `selectionSet` |
| `DESCRIPTION` | `description` | `SELECTION` | `selections` |
| `NAME` | `name` | `TYPE_CONDITION` | `typeCondition` |
| `ALIAS` | `alias` | `INTERFACE` | `interfaces` |
| `VARIABLE_DEFINITION` | `variableDefinitions` | `MEMBER_TYPE` | `types` |
| `VARIABLE` | `variable` | `ENUM_VALUE` | `values` of an enum |
| `TYPE` | `type` | `OPERATION_TYPE` | `operationTypes` |
| `DEFAULT_VALUE` | `defaultValue` | `LOCATION` | `locations` |
| `DIRECTIVE` | `directives` | `MEMBER_NAME` | `memberName` |
| `ARGUMENT` | `arguments` | `ARGUMENT_NAME` | `argumentName` |
| `VALUE` | `value` | `FIELD_NAME` | `fieldName` |
| `LIST_ITEM` | `values` of a `ListValue` | | |

The items of a `ListValue` have the role `LIST_ITEM`, and not `VALUE`. `VALUE` is the single `value` of an argument or an object field.

## OperationType

`OperationType` has the values `QUERY`, `MUTATION` and `SUBSCRIPTION`. `text()` gives the keyword, such as `query`. `is_valid()` is true for the three values.

## TokenKind

`TokenKind` is the kind of a lexical token, with 23 values from `SOF` to `COMMENT`. `text()` gives the graphql-js string, such as `<EOF>`, `!` or `Name`.

- `is_valid()` is true for the 23 values.
- `is_punctuator()` is true for the 15 punctuators, as graphql-js `isPunctuatorTokenKind`.
- `description()` gives the kind as parser errors name it: a punctuator in double quotes, or the name.

## DirectiveLocation

`DirectiveLocation` is a place where a directive can be used. It has 20 values, from `QUERY` to `DIRECTIVE_DEFINITION`. `text()` gives the name, such as `FIELD_DEFINITION`.

- `is_valid()` is true for the 20 values.
- `is_executable()` is true for `QUERY` through `VARIABLE_DEFINITION`.
- `DirectiveLocation.from_name(name)` returns the index of the location with that name, or `-1`.

## Lexer

`Lexer(source)` reads tokens from a `Source`. `token` is the current token, and `last_token` is the token before it. `advance()` moves to the next token. `lookahead()` reads the next token and does not move.

A `Token` is a `kind` and a byte range, `start` and `end`. It has no value. These functions decode a token on request:

- `token_value(source, token)` returns the value, as graphql-js `Token.value`. A string is decoded, and a punctuator gives an empty string.
- `token_description(source, token)` returns the token as parser errors name it, as graphql-js `getTokenDesc`.
- `read_comments(source)` returns every comment token in order. Each range starts at its `#`.

The lexer raises a `GraphQLError` for a lexical error, with the graphql-js message.

## Printer

`print_ast(document)` prints the root node of a document, as graphql-js `print`. `print_node(document, node)` prints one node and its descendants. The output is the same text as graphql-js, byte for byte.

```mojo
from gql_language.printer import print_ast

print(print_ast(parse("query Q { a(x: 1) }")))
```

## Block strings and quoted strings

These functions are in `gql_language.block_string`. Lengths are UTF-16 code units, as in graphql-js.

- `print_string(value)` returns the value as a quoted string literal, as graphql-js `printString`.
- `print_block_string(value, minimize=False)` returns the value as a block string literal, as graphql-js `printBlockString`.
- `is_printable_as_block_string(value)` returns whether a block string can hold the value exactly.

The module also has `append_*` functions that write the same output into a `List[UInt8]`, for the printer. `dedent_block_string_lines` is in `gql_language.lexer`.

## GraphQLError

`GraphQLError` is the error that every GraphQL stage reports. It holds what a GraphQL response error shows.

| Field | Contents |
| --- | --- |
| `message: String` | The description of the error |
| `locations: List[SourceLocation]` | The positions in the request that the error refers to |
| `path: List[PathSegment]` | The response path of the field that failed, or empty |
| `extensions: String` | A JSON object of extra data, or empty |
| `excerpt: String` | The source excerpts that the written error appends |

- `GraphQLError(message)` makes an error with only a message.
- `GraphQLError(message, source, positions)` makes an error at byte offsets of a source. It computes the locations and the excerpts.
- Write the error, such as with `print(error)`, to get graphql-js `toString()`. That is the message, then an excerpt of the source with a `^` under each location.
- `to_json()` returns graphql-js `toJSON()`: a JSON object with `message`, and with `locations`, `path` and `extensions` when they are not empty.

A `PathSegment` is a response key or a list index. Make one with `PathSegment.of_key(key)` or `PathSegment.of_index(index)`.

```mojo
try:
    _ = parse("{ hero(")
except error:
    print(error)            # Syntax Error: Expected Name, found <EOF>. and the excerpt
    print(error.to_json())  # {"message":"...","locations":[{"line":1,"column":8}]}
```

## Source and SourceLocation

`Source(body, name="GraphQL request", location_offset=SourceLocation(1, 1))` copies a body of GraphQL text. The name appears in error messages. The location offset moves the first line and column, for a source in a larger file. The constructor raises an error when the line or the column of the offset is not positive.

| Member | Contents |
| --- | --- |
| `bytes: List[UInt8]` | The body as UTF-8, then `PADDING` zero bytes |
| `length: Int` | The body length in bytes, without the padding |
| `name: String` | The name in error messages |
| `location_offset: SourceLocation` | The line and column of the first character |
| `body()` | A view of the body |
| `slice(start, end)` | A view of the body between two byte offsets |
| `get_location(position)` | The line and column of a byte offset |

A `SourceLocation` has a one-based `line` and `column`. It writes as `line:column`. A line ends at `\r\n`, `\n` or `\r`.

## AST utilities

These functions are ports of the graphql-js utilities that need only the language. Each one is in its own module. A function that makes a document copies the nodes into a new `Document`. The copies have no source locations.

| Function | graphql-js | Result |
| --- | --- | --- |
| `strip_ignored_characters(source)` | `stripIgnoredCharacters` | `String`: the tokens, with a space only where two tokens need one |
| `concat_ast(documents)` | `concatAST` | `Document` with the definitions of all the documents, in order |
| `separate_operations(document)` | `separateOperations` | `List[OperationDocument]`: one document for each operation name |
| `get_operation_ast(document, operation_name=None)` | `getOperationAST` | The `OperationDefinition` node, or `NO_NODE` |
| `sort_value_node(document, node)` | `sortValueNode` | `Document` whose root is a copy of the value, with the fields of each object sorted |

`strip_ignored_characters` accepts a `Source` or a text. The output is the same text as graphql-js, byte for byte. A block string is printed on one line where that is possible. The function raises a `GraphQLError` for a lexical error. The document does not have to be valid: the function reads only the tokens.

```mojo
from gql_language.strip_ignored_characters import strip_ignored_characters

print(strip_ignored_characters("query Q { a, b }"))  # query Q{a b}
```

An `OperationDocument` has a `name` and a `document`. The name is empty for an anonymous operation. The document holds the operation and the fragment definitions that it uses, also through other fragments, in the order of the original document. The list is in the order of the graphql-js object keys. When two operations have the same name, the second one replaces the document of the first one, as in graphql-js.

`get_operation_ast` without a name returns the operation only when the document has exactly one operation. With a name, it returns the first operation with that name. An empty name does not select an anonymous operation.

`sort_value_node` sorts in natural order, as graphql-js `naturalCompare`: a run of digits compares as a number. The sort is stable.

### Differences from graphql-js in the AST utilities

- graphql-js puts the same node objects in the new documents. A `Document` is one arena, so these functions copy the nodes.
- `separate_operations` returns a list in key order, not an object.
- `get_operation_ast` returns a node index. `NO_NODE` takes the place of `null`.

## Differences from graphql-js

- **Byte offsets.** `start`, `end` and every position are byte offsets into the UTF-8 body. graphql-js counts UTF-16 code units. The two differ only after a character that is not ASCII.
- **Columns.** `get_location` counts the column in UTF-16 code units. So a line and a column are the same numbers that graphql-js reports.
- **Lazy strings.** A token has no value, and a string node holds its source range. The lexer checks the escapes of a string when it reads it. It decodes the string only when a caller asks, with `token_value` or `string_value`.
- **Tokens without lines.** A token has no line and column. `Source.get_location` computes them for an error that needs them.
- **Comments.** The lexer skips comments and does not return them, as graphql-js `lookahead` does. Use `read_comments` in a tool that needs them.
- **No lone surrogates.** A Mojo string is valid UTF-8, so it cannot hold a lone surrogate. The graphql-js `Invalid character:` errors for a lone surrogate cannot occur.
- **Error excerpts.** The excerpt cuts a line of more than 120 UTF-16 units into pieces of 80 units. graphql-js can cut a surrogate pair in two. This port keeps the pair whole, in the earlier piece.
- **One arena.** The AST is a list of nodes with roles, not a tree of objects. Each graphql-js property is a role, so the content is the same.

## Tests

The tests are ported from graphql-js 16.14.2 `src/language/__tests__`. They are in `tests/gql_language/`. The tests of the AST utilities are ported from `src/utilities/__tests__`. `stripIgnoredCharacters-fuzz.ts` is not ported, because it runs for minutes. A test that has a character that is not ASCII says so, because its offsets are bytes.
