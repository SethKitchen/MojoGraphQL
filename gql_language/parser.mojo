# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The GraphQL parser: source text in, a `Document` out.

Port of graphql-js 16.14.2 `language/parser.ts`. The grammar, the options
and the error messages are the same. Each `_parse_*` method is the graphql-js
`parse*` method of the same name.

A method adds its node as the last child of `parent`, in the role it is
given, and returns the node's index. The node is added before its children,
so a parsed document is in preorder. Its end offset is set when the method
returns, from the last token read, as graphql-js `loc.end`.
"""

from gql_language.ast import (
    FLAG_BLOCK,
    FLAG_REPEATABLE,
    FLAG_TRUE,
    NO_NODE,
    Document,
    Kind,
    Node,
    OperationType,
    Role,
    role_bit,
)
from gql_language.directive_location import DirectiveLocation
from gql_language.error import GraphQLError, syntax_error
from gql_language.lexer import Lexer, Token, token_description, token_value
from gql_language.source import Source
from gql_language.token_kind import TokenKind


@fieldwise_init
struct ParseOptions(Copyable, ImplicitlyCopyable, Movable):
    """Options of the parser, as graphql-js `ParseOptions`."""

    var max_tokens: Int
    """The most tokens a document can have, or -1 for no limit."""
    var allow_legacy_fragment_variables: Bool
    """Accept variable definitions on fragment definitions."""
    var experimental_directives_on_directive_definitions: Bool
    """Accept directives on directive definitions, and `extend directive`."""

    def __init__(out self):
        """Return the graphql-js defaults: no limit and no extensions."""
        self.max_tokens = -1
        self.allow_legacy_fragment_variables = False
        self.experimental_directives_on_directive_definitions = False


struct Parser(Movable):
    """A recursive-descent parser over one source."""

    var lexer: Lexer
    """The lexer that supplies the tokens."""
    var nodes: List[Node]
    """The nodes parsed so far."""
    var options: ParseOptions
    """The options."""
    var token_count: Int
    """How many tokens were read, not counting the end of file."""

    def __init__(
        out self, var source: Source, options: ParseOptions = ParseOptions()
    ):
        """Start a parser at the start of a source.

        Args:
            source: The source to parse.
            options: The parser options.
        """
        var capacity = source.length // 6 + 8
        self.lexer = Lexer(source^)
        self.nodes = List[Node](capacity=capacity)
        self.options = options
        self.token_count = 0

    def finish(deinit self, root: Int) -> Document:
        """Return the parsed nodes as a document.

        Args:
            root: The root node's index.

        Returns:
            The document; it owns the source.
        """
        var document = Document(self.lexer^.take_source(), self.nodes^, root)
        document.token_count = self.token_count
        return document^

    # --- nodes ------------------------------------------------------------

    @always_inline
    def _open(mut self, parent: Int, kind: Kind, role: Role, start: Int) -> Int:
        """Add a node that starts at `start` as the last child of `parent`."""
        var index = len(self.nodes)
        self.nodes.append(
            Node(
                kind,
                role,
                0,
                Int32(start),
                Int32(start),
                NO_NODE,
                NO_NODE,
                NO_NODE,
                0,
            )
        )
        if parent != NO_NODE:
            self.nodes[parent].roles |= role_bit(role)
            var last = Int(self.nodes[parent].last)
            if last == NO_NODE:
                self.nodes[parent].first = Int32(index)
            else:
                self.nodes[last].next = Int32(index)
            self.nodes[parent].last = Int32(index)
        return index

    @always_inline
    def _close(mut self, node: Int) -> Int:
        """End a node at the last token read, and return it."""
        self.nodes[node].end = Int32(self.lexer.last_token.end)
        return node

    @always_inline
    def _token_node(
        mut self, parent: Int, kind: Kind, role: Role, token: Token
    ) -> Int:
        """Add a childless node that spans exactly one token."""
        var node = self._open(parent, kind, role, token.start)
        self.nodes[node].end = Int32(token.end)
        return node

    # --- tokens -----------------------------------------------------------

    @always_inline
    def peek(self, kind: TokenKind) -> Bool:
        """Return True if the current token has a kind.

        Args:
            kind: The kind to test.

        Returns:
            Whether the current token is of that kind.
        """
        return self.lexer.token.kind == kind

    def _advance(mut self) raises GraphQLError:
        """Read the next token, and count it, as `advanceLexer`."""
        var token = self.lexer.advance()
        if token.kind != TokenKind.EOF:
            self.token_count += 1
            if (
                self.options.max_tokens >= 0
                and self.token_count > self.options.max_tokens
            ):
                raise syntax_error(
                    self.lexer.source,
                    token.start,
                    "Document contains more that "
                    + String(self.options.max_tokens)
                    + " tokens. Parsing aborted.",
                )

    def _expect_token(mut self, kind: TokenKind) raises GraphQLError -> Token:
        """Consume a token of a kind, or raise."""
        var token = self.lexer.token
        if token.kind == kind:
            self._advance()
            return token
        raise syntax_error(
            self.lexer.source,
            token.start,
            "Expected "
            + kind.description()
            + ", found "
            + token_description(self.lexer.source, token)
            + ".",
        )

    @always_inline
    def _expect_optional_token(
        mut self, kind: TokenKind
    ) raises GraphQLError -> Bool:
        """Consume a token of a kind if it is next."""
        if self.lexer.token.kind == kind:
            self._advance()
            return True
        return False

    @always_inline
    def _is_keyword(self, token: Token, keyword: StringSlice) -> Bool:
        """Return True if a token is the name `keyword`."""
        return (
            token.kind == TokenKind.NAME
            and self.lexer.source.slice(token.start, token.end) == keyword
        )

    def _expect_keyword(mut self, keyword: StaticString) raises GraphQLError:
        """Consume the name `keyword`, or raise."""
        var token = self.lexer.token
        if self._is_keyword(token, keyword):
            self._advance()
            return
        raise syntax_error(
            self.lexer.source,
            token.start,
            'Expected "'
            + String(keyword)
            + '", found '
            + token_description(self.lexer.source, token)
            + ".",
        )

    def _expect_optional_keyword(
        mut self, keyword: StaticString
    ) raises GraphQLError -> Bool:
        """Consume the name `keyword` if it is next."""
        if self._is_keyword(self.lexer.token, keyword):
            self._advance()
            return True
        return False

    def _unexpected(self, token: Token) -> GraphQLError:
        """Return the error for a token the grammar does not allow."""
        return syntax_error(
            self.lexer.source,
            token.start,
            "Unexpected " + token_description(self.lexer.source, token) + ".",
        )

    # --- documents --------------------------------------------------------

    def parse_name(
        mut self, parent: Int, role: Role
    ) raises GraphQLError -> Int:
        """Parse a `Name`.

        Args:
            parent: The parent's index, or `NO_NODE`.
            role: The role of the new node.

        Returns:
            The new node's index.

        Raises:
            GraphQLError: If the next token is not a name.
        """
        var token = self._expect_token(TokenKind.NAME)
        return self._token_node(parent, Kind.NAME, role, token)

    def parse_document(mut self) raises GraphQLError -> Int:
        """Parse a whole `Document`.

        Returns:
            The `Document` node's index.

        Raises:
            GraphQLError: If the source is not a valid document.
        """
        var document = self._open(
            NO_NODE, Kind.DOCUMENT, Role.ROOT, self.lexer.token.start
        )
        _ = self._expect_token(TokenKind.SOF)
        while True:
            self._parse_definition(document)
            if self._expect_optional_token(TokenKind.EOF):
                break
        return self._close(document)

    def _parse_definition(mut self, parent: Int) raises GraphQLError:
        """Parse one definition, as graphql-js `parseDefinition`."""
        if self.peek(TokenKind.BRACE_L):
            _ = self._parse_operation_definition(parent)
            return
        var has_description = self._peek_description()
        var keyword = self.lexer.token
        if has_description:
            keyword = self.lexer.lookahead()
        if has_description and keyword.kind == TokenKind.BRACE_L:
            raise syntax_error(
                self.lexer.source,
                self.lexer.token.start,
                (
                    "Unexpected description, descriptions are not supported on"
                    " shorthand queries."
                ),
            )
        if keyword.kind == TokenKind.NAME:
            var word = self.lexer.source.slice(keyword.start, keyword.end)
            if word == "schema":
                _ = self._parse_schema_definition(parent)
                return
            if word == "scalar":
                _ = self._parse_scalar_type_definition(parent)
                return
            if word == "type":
                _ = self._parse_object_like_definition(
                    parent, Kind.OBJECT_TYPE_DEFINITION, "type"
                )
                return
            if word == "interface":
                _ = self._parse_object_like_definition(
                    parent, Kind.INTERFACE_TYPE_DEFINITION, "interface"
                )
                return
            if word == "union":
                _ = self._parse_union_type_definition(parent)
                return
            if word == "enum":
                _ = self._parse_enum_type_definition(parent)
                return
            if word == "input":
                _ = self._parse_input_object_type_definition(parent)
                return
            if word == "directive":
                _ = self._parse_directive_definition(parent)
                return
            if word == "query" or word == "mutation" or word == "subscription":
                _ = self._parse_operation_definition(parent)
                return
            if word == "fragment":
                _ = self._parse_fragment_definition(parent)
                return
            if has_description:
                raise syntax_error(
                    self.lexer.source,
                    self.lexer.token.start,
                    (
                        "Unexpected description, only GraphQL definitions"
                        " support descriptions."
                    ),
                )
            if word == "extend":
                self._parse_type_system_extension(parent)
                return
        raise self._unexpected(keyword)

    # --- operations -------------------------------------------------------

    def _parse_operation_definition(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse an operation, or a shorthand `{ ... }` query."""
        var node = self._open(
            parent,
            Kind.OPERATION_DEFINITION,
            Role.DEFINITION,
            self.lexer.token.start,
        )
        if self.peek(TokenKind.BRACE_L):
            self.nodes[node].flags = OperationType.QUERY.value
            _ = self._parse_selection_set(node, Role.SELECTION_SET)
            return self._close(node)
        self._parse_description(node)
        self.nodes[node].flags = self._parse_operation_type().value
        if self.peek(TokenKind.NAME):
            _ = self.parse_name(node, Role.NAME)
        self._parse_variable_definitions(node)
        self._parse_directives(node, False)
        _ = self._parse_selection_set(node, Role.SELECTION_SET)
        return self._close(node)

    def _parse_operation_type(mut self) raises GraphQLError -> OperationType:
        """Parse `query`, `mutation` or `subscription`."""
        var token = self._expect_token(TokenKind.NAME)
        var word = self.lexer.source.slice(token.start, token.end)
        if word == "query":
            return OperationType.QUERY
        if word == "mutation":
            return OperationType.MUTATION
        if word == "subscription":
            return OperationType.SUBSCRIPTION
        raise self._unexpected(token)

    def _parse_variable_definitions(mut self, parent: Int) raises GraphQLError:
        """Parse an optional `( ... )` of variable definitions."""
        if self._expect_optional_token(TokenKind.PAREN_L):
            while True:
                _ = self._parse_variable_definition(parent)
                if self._expect_optional_token(TokenKind.PAREN_R):
                    break

    def _parse_variable_definition(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse `$name: Type = default @directives`."""
        var node = self._open(
            parent,
            Kind.VARIABLE_DEFINITION,
            Role.VARIABLE_DEFINITION,
            self.lexer.token.start,
        )
        self._parse_description(node)
        _ = self._parse_variable(node, Role.VARIABLE)
        _ = self._expect_token(TokenKind.COLON)
        _ = self._parse_type_reference(node, Role.TYPE)
        if self._expect_optional_token(TokenKind.EQUALS):
            _ = self._parse_value_literal(node, Role.DEFAULT_VALUE, True)
        self._parse_directives(node, True)
        return self._close(node)

    def _parse_variable(
        mut self, parent: Int, role: Role
    ) raises GraphQLError -> Int:
        """Parse `$name`."""
        var node = self._open(
            parent, Kind.VARIABLE, role, self.lexer.token.start
        )
        _ = self._expect_token(TokenKind.DOLLAR)
        _ = self.parse_name(node, Role.NAME)
        return self._close(node)

    def _parse_selection_set(
        mut self, parent: Int, role: Role
    ) raises GraphQLError -> Int:
        """Parse `{ selection... }` with at least one selection."""
        var node = self._open(
            parent, Kind.SELECTION_SET, role, self.lexer.token.start
        )
        _ = self._expect_token(TokenKind.BRACE_L)
        while True:
            if self.peek(TokenKind.SPREAD):
                _ = self._parse_fragment(node)
            else:
                _ = self._parse_field(node)
            if self._expect_optional_token(TokenKind.BRACE_R):
                break
        return self._close(node)

    def _parse_field(mut self, parent: Int) raises GraphQLError -> Int:
        """Parse `alias: name(arguments) @directives { ... }`."""
        var node = self._open(
            parent, Kind.FIELD, Role.SELECTION, self.lexer.token.start
        )
        var name_or_alias = self.parse_name(node, Role.NAME)
        if self._expect_optional_token(TokenKind.COLON):
            self.nodes[name_or_alias].role = Role.ALIAS
            self.nodes[node].roles |= role_bit(Role.ALIAS)
            _ = self.parse_name(node, Role.NAME)
        self._parse_arguments(node, False)
        self._parse_directives(node, False)
        if self.peek(TokenKind.BRACE_L):
            _ = self._parse_selection_set(node, Role.SELECTION_SET)
        return self._close(node)

    def _parse_arguments(
        mut self, parent: Int, is_const: Bool
    ) raises GraphQLError:
        """Parse an optional `( name: value ... )`."""
        if self._expect_optional_token(TokenKind.PAREN_L):
            while True:
                _ = self._parse_argument(parent, is_const)
                if self._expect_optional_token(TokenKind.PAREN_R):
                    break

    def _parse_argument(
        mut self, parent: Int, is_const: Bool
    ) raises GraphQLError -> Int:
        """Parse `name: value`."""
        var node = self._open(
            parent, Kind.ARGUMENT, Role.ARGUMENT, self.lexer.token.start
        )
        _ = self.parse_name(node, Role.NAME)
        _ = self._expect_token(TokenKind.COLON)
        _ = self._parse_value_literal(node, Role.VALUE, is_const)
        return self._close(node)

    # --- fragments --------------------------------------------------------

    def _parse_fragment(mut self, parent: Int) raises GraphQLError -> Int:
        """Parse a fragment spread or an inline fragment."""
        var start = self.lexer.token.start
        _ = self._expect_token(TokenKind.SPREAD)
        var has_type_condition = self._expect_optional_keyword("on")
        if not has_type_condition and self.peek(TokenKind.NAME):
            var spread = self._open(
                parent, Kind.FRAGMENT_SPREAD, Role.SELECTION, start
            )
            _ = self._parse_fragment_name(spread)
            self._parse_directives(spread, False)
            return self._close(spread)
        var inline = self._open(
            parent, Kind.INLINE_FRAGMENT, Role.SELECTION, start
        )
        if has_type_condition:
            _ = self._parse_named_type(inline, Role.TYPE_CONDITION)
        self._parse_directives(inline, False)
        _ = self._parse_selection_set(inline, Role.SELECTION_SET)
        return self._close(inline)

    def _parse_fragment_definition(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse `fragment Name on Type @directives { ... }`."""
        var node = self._open(
            parent,
            Kind.FRAGMENT_DEFINITION,
            Role.DEFINITION,
            self.lexer.token.start,
        )
        self._parse_description(node)
        self._expect_keyword("fragment")
        _ = self._parse_fragment_name(node)
        if self.options.allow_legacy_fragment_variables:
            self._parse_variable_definitions(node)
        self._expect_keyword("on")
        _ = self._parse_named_type(node, Role.TYPE_CONDITION)
        self._parse_directives(node, False)
        _ = self._parse_selection_set(node, Role.SELECTION_SET)
        return self._close(node)

    def _parse_fragment_name(mut self, parent: Int) raises GraphQLError -> Int:
        """Parse a fragment name: any name but `on`."""
        if self._is_keyword(self.lexer.token, "on"):
            raise self._unexpected(self.lexer.token)
        return self.parse_name(parent, Role.NAME)

    # --- values -----------------------------------------------------------

    def _parse_value_literal(
        mut self, parent: Int, role: Role, is_const: Bool
    ) raises GraphQLError -> Int:
        """Parse a value, as graphql-js `parseValueLiteral`."""
        var token = self.lexer.token
        var kind = token.kind
        if kind == TokenKind.BRACKET_L:
            var node = self._open(parent, Kind.LIST, role, token.start)
            _ = self._expect_token(TokenKind.BRACKET_L)
            while not self._expect_optional_token(TokenKind.BRACKET_R):
                _ = self._parse_value_literal(node, Role.LIST_ITEM, is_const)
            return self._close(node)
        if kind == TokenKind.BRACE_L:
            var node = self._open(parent, Kind.OBJECT, role, token.start)
            _ = self._expect_token(TokenKind.BRACE_L)
            while not self._expect_optional_token(TokenKind.BRACE_R):
                var field = self._open(
                    node, Kind.OBJECT_FIELD, Role.FIELD, self.lexer.token.start
                )
                _ = self.parse_name(field, Role.NAME)
                _ = self._expect_token(TokenKind.COLON)
                _ = self._parse_value_literal(field, Role.VALUE, is_const)
                _ = self._close(field)
            return self._close(node)
        if kind == TokenKind.INT:
            self._advance()
            return self._token_node(parent, Kind.INT, role, token)
        if kind == TokenKind.FLOAT:
            self._advance()
            return self._token_node(parent, Kind.FLOAT, role, token)
        if kind == TokenKind.STRING or kind == TokenKind.BLOCK_STRING:
            return self._parse_string_literal(parent, role)
        if kind == TokenKind.NAME:
            self._advance()
            var word = self.lexer.source.slice(token.start, token.end)
            if word == "true":
                var node = self._token_node(parent, Kind.BOOLEAN, role, token)
                self.nodes[node].flags = FLAG_TRUE
                return node
            if word == "false":
                return self._token_node(parent, Kind.BOOLEAN, role, token)
            if word == "null":
                return self._token_node(parent, Kind.NULL, role, token)
            return self._token_node(parent, Kind.ENUM, role, token)
        if kind == TokenKind.DOLLAR:
            if is_const:
                _ = self._expect_token(TokenKind.DOLLAR)
                if self.lexer.token.kind == TokenKind.NAME:
                    var name = token_value(self.lexer.source, self.lexer.token)
                    raise syntax_error(
                        self.lexer.source,
                        token.start,
                        'Unexpected variable "$'
                        + name
                        + '" in constant value.',
                    )
                raise self._unexpected(token)
            return self._parse_variable(parent, role)
        raise self._unexpected(token)

    def _parse_string_literal(
        mut self, parent: Int, role: Role
    ) raises GraphQLError -> Int:
        """Parse a string or a block string."""
        var token = self.lexer.token
        self._advance()
        var node = self._token_node(parent, Kind.STRING, role, token)
        if token.kind == TokenKind.BLOCK_STRING:
            self.nodes[node].flags = FLAG_BLOCK
        return node

    # --- directives -------------------------------------------------------

    def _parse_directives(
        mut self, parent: Int, is_const: Bool
    ) raises GraphQLError:
        """Parse zero or more `@name(arguments)`."""
        while self.peek(TokenKind.AT):
            var node = self._open(
                parent, Kind.DIRECTIVE, Role.DIRECTIVE, self.lexer.token.start
            )
            _ = self._expect_token(TokenKind.AT)
            _ = self.parse_name(node, Role.NAME)
            self._parse_arguments(node, is_const)
            _ = self._close(node)

    # --- types ------------------------------------------------------------

    def _parse_type_reference(
        mut self, parent: Int, role: Role
    ) raises GraphQLError -> Int:
        """Parse `Name`, `[Type]`, and either with a trailing `!`.

        The non-null wrapper is only known after its inner type, so the
        inner node is added first and the wrapper is put in its place.
        """
        var start = self.lexer.token.start
        var inner: Int
        if self._expect_optional_token(TokenKind.BRACKET_L):
            inner = self._open(parent, Kind.LIST_TYPE, role, start)
            _ = self._parse_type_reference(inner, Role.TYPE)
            _ = self._expect_token(TokenKind.BRACKET_R)
            _ = self._close(inner)
        else:
            inner = self._parse_named_type(parent, role)
        if self._expect_optional_token(TokenKind.BANG):
            return self._wrap_non_null(parent, inner, start)
        return inner

    def _wrap_non_null(mut self, parent: Int, inner: Int, start: Int) -> Int:
        """Replace `inner`, the last child of `parent`, by a `NonNullType`
        that holds it."""
        var role = self.nodes[inner].role
        var wrapper = len(self.nodes)
        self.nodes.append(
            Node(
                Kind.NON_NULL_TYPE,
                role,
                0,
                Int32(start),
                Int32(self.lexer.last_token.end),
                Int32(inner),
                Int32(inner),
                NO_NODE,
                role_bit(Role.TYPE),
            )
        )
        self.nodes[inner].role = Role.TYPE
        if parent != NO_NODE:
            # Unlink `inner` from the parent and link the wrapper instead.
            var current = Int(self.nodes[parent].first)
            if current == inner:
                self.nodes[parent].first = Int32(wrapper)
            else:
                while Int(self.nodes[current].next) != inner:
                    current = Int(self.nodes[current].next)
                self.nodes[current].next = Int32(wrapper)
            self.nodes[parent].last = Int32(wrapper)
        return wrapper

    def _parse_named_type(
        mut self, parent: Int, role: Role
    ) raises GraphQLError -> Int:
        """Parse a `NamedType`."""
        var node = self._open(
            parent, Kind.NAMED_TYPE, role, self.lexer.token.start
        )
        _ = self.parse_name(node, Role.NAME)
        return self._close(node)

    # --- type system ------------------------------------------------------

    @always_inline
    def _peek_description(self) -> Bool:
        """Return True if a description string is next."""
        return self.peek(TokenKind.STRING) or self.peek(TokenKind.BLOCK_STRING)

    def _parse_description(mut self, parent: Int) raises GraphQLError:
        """Parse a description string if one is next."""
        if self._peek_description():
            _ = self._parse_string_literal(parent, Role.DESCRIPTION)

    def _parse_schema_definition(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse `schema @directives { query: Query ... }`."""
        var node = self._open(
            parent,
            Kind.SCHEMA_DEFINITION,
            Role.DEFINITION,
            self.lexer.token.start,
        )
        self._parse_description(node)
        self._expect_keyword("schema")
        self._parse_directives(node, True)
        _ = self._expect_token(TokenKind.BRACE_L)
        while True:
            _ = self._parse_operation_type_definition(node)
            if self._expect_optional_token(TokenKind.BRACE_R):
                break
        return self._close(node)

    def _parse_operation_type_definition(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse `query: Type`."""
        var node = self._open(
            parent,
            Kind.OPERATION_TYPE_DEFINITION,
            Role.OPERATION_TYPE,
            self.lexer.token.start,
        )
        self.nodes[node].flags = self._parse_operation_type().value
        _ = self._expect_token(TokenKind.COLON)
        _ = self._parse_named_type(node, Role.TYPE)
        return self._close(node)

    def _parse_scalar_type_definition(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse `scalar Name @directives`."""
        var node = self._open(
            parent,
            Kind.SCALAR_TYPE_DEFINITION,
            Role.DEFINITION,
            self.lexer.token.start,
        )
        self._parse_description(node)
        self._expect_keyword("scalar")
        _ = self.parse_name(node, Role.NAME)
        self._parse_directives(node, True)
        return self._close(node)

    def _parse_object_like_definition(
        mut self, parent: Int, kind: Kind, keyword: StaticString
    ) raises GraphQLError -> Int:
        """Parse a `type` or an `interface` definition."""
        var node = self._open(
            parent, kind, Role.DEFINITION, self.lexer.token.start
        )
        self._parse_description(node)
        self._expect_keyword(keyword)
        _ = self.parse_name(node, Role.NAME)
        _ = self._parse_implements_interfaces(node)
        self._parse_directives(node, True)
        _ = self._parse_fields_definition(node)
        return self._close(node)

    def _parse_implements_interfaces(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse an optional `implements A & B`; return how many."""
        if not self._expect_optional_keyword("implements"):
            return 0
        _ = self._expect_optional_token(TokenKind.AMP)
        var count = 0
        while True:
            _ = self._parse_named_type(parent, Role.INTERFACE)
            count += 1
            if not self._expect_optional_token(TokenKind.AMP):
                break
        return count

    def _parse_fields_definition(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse an optional `{ field... }`; return how many."""
        if not self._expect_optional_token(TokenKind.BRACE_L):
            return 0
        var count = 0
        while True:
            _ = self._parse_field_definition(parent)
            count += 1
            if self._expect_optional_token(TokenKind.BRACE_R):
                break
        return count

    def _parse_field_definition(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse `name(arguments): Type @directives`."""
        var node = self._open(
            parent, Kind.FIELD_DEFINITION, Role.FIELD, self.lexer.token.start
        )
        self._parse_description(node)
        _ = self.parse_name(node, Role.NAME)
        _ = self._parse_argument_defs(node)
        _ = self._expect_token(TokenKind.COLON)
        _ = self._parse_type_reference(node, Role.TYPE)
        self._parse_directives(node, True)
        return self._close(node)

    def _parse_argument_defs(mut self, parent: Int) raises GraphQLError -> Int:
        """Parse an optional `( input values... )`; return how many."""
        if not self._expect_optional_token(TokenKind.PAREN_L):
            return 0
        var count = 0
        while True:
            _ = self._parse_input_value_def(parent, Role.ARGUMENT)
            count += 1
            if self._expect_optional_token(TokenKind.PAREN_R):
                break
        return count

    def _parse_input_value_def(
        mut self, parent: Int, role: Role
    ) raises GraphQLError -> Int:
        """Parse `name: Type = default @directives`."""
        var node = self._open(
            parent, Kind.INPUT_VALUE_DEFINITION, role, self.lexer.token.start
        )
        self._parse_description(node)
        _ = self.parse_name(node, Role.NAME)
        _ = self._expect_token(TokenKind.COLON)
        _ = self._parse_type_reference(node, Role.TYPE)
        if self._expect_optional_token(TokenKind.EQUALS):
            _ = self._parse_value_literal(node, Role.DEFAULT_VALUE, True)
        self._parse_directives(node, True)
        return self._close(node)

    def _parse_union_type_definition(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse `union Name @directives = A | B`."""
        var node = self._open(
            parent,
            Kind.UNION_TYPE_DEFINITION,
            Role.DEFINITION,
            self.lexer.token.start,
        )
        self._parse_description(node)
        self._expect_keyword("union")
        _ = self.parse_name(node, Role.NAME)
        self._parse_directives(node, True)
        _ = self._parse_union_member_types(node)
        return self._close(node)

    def _parse_union_member_types(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse an optional `= A | B`; return how many."""
        if not self._expect_optional_token(TokenKind.EQUALS):
            return 0
        _ = self._expect_optional_token(TokenKind.PIPE)
        var count = 0
        while True:
            _ = self._parse_named_type(parent, Role.MEMBER_TYPE)
            count += 1
            if not self._expect_optional_token(TokenKind.PIPE):
                break
        return count

    def _parse_enum_type_definition(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse `enum Name @directives { VALUE... }`."""
        var node = self._open(
            parent,
            Kind.ENUM_TYPE_DEFINITION,
            Role.DEFINITION,
            self.lexer.token.start,
        )
        self._parse_description(node)
        self._expect_keyword("enum")
        _ = self.parse_name(node, Role.NAME)
        self._parse_directives(node, True)
        _ = self._parse_enum_values_definition(node)
        return self._close(node)

    def _parse_enum_values_definition(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse an optional `{ VALUE... }`; return how many."""
        if not self._expect_optional_token(TokenKind.BRACE_L):
            return 0
        var count = 0
        while True:
            var node = self._open(
                parent,
                Kind.ENUM_VALUE_DEFINITION,
                Role.ENUM_VALUE,
                self.lexer.token.start,
            )
            self._parse_description(node)
            var token = self.lexer.token
            if (
                self._is_keyword(token, "true")
                or self._is_keyword(token, "false")
                or self._is_keyword(token, "null")
            ):
                raise syntax_error(
                    self.lexer.source,
                    token.start,
                    token_description(self.lexer.source, token)
                    + " is reserved and cannot be used for an enum value.",
                )
            _ = self.parse_name(node, Role.NAME)
            self._parse_directives(node, True)
            _ = self._close(node)
            count += 1
            if self._expect_optional_token(TokenKind.BRACE_R):
                break
        return count

    def _parse_input_object_type_definition(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse `input Name @directives { field... }`."""
        var node = self._open(
            parent,
            Kind.INPUT_OBJECT_TYPE_DEFINITION,
            Role.DEFINITION,
            self.lexer.token.start,
        )
        self._parse_description(node)
        self._expect_keyword("input")
        _ = self.parse_name(node, Role.NAME)
        self._parse_directives(node, True)
        _ = self._parse_input_fields_definition(node)
        return self._close(node)

    def _parse_input_fields_definition(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse an optional `{ input values... }`; return how many."""
        if not self._expect_optional_token(TokenKind.BRACE_L):
            return 0
        var count = 0
        while True:
            _ = self._parse_input_value_def(parent, Role.FIELD)
            count += 1
            if self._expect_optional_token(TokenKind.BRACE_R):
                break
        return count

    def _count_directives(mut self, parent: Int) raises GraphQLError -> Int:
        """Parse const directives; return how many."""
        var before = self._last_child_count(parent)
        self._parse_directives(parent, True)
        return self._last_child_count(parent) - before

    def _last_child_count(self, parent: Int) -> Int:
        """Return how many children a node has."""
        var total = 0
        var current = Int(self.nodes[parent].first)
        while current != NO_NODE:
            total += 1
            current = Int(self.nodes[current].next)
        return total

    def _parse_type_system_extension(mut self, parent: Int) raises GraphQLError:
        """Parse `extend ...`, as graphql-js `parseTypeSystemExtension`."""
        var keyword = self.lexer.lookahead()
        if keyword.kind == TokenKind.NAME:
            var word = self.lexer.source.slice(keyword.start, keyword.end)
            if word == "schema":
                self._parse_schema_extension(parent)
                return
            if word == "scalar":
                self._parse_simple_extension(
                    parent, Kind.SCALAR_TYPE_EXTENSION, "scalar"
                )
                return
            if word == "type":
                self._parse_object_like_extension(
                    parent, Kind.OBJECT_TYPE_EXTENSION, "type"
                )
                return
            if word == "interface":
                self._parse_object_like_extension(
                    parent, Kind.INTERFACE_TYPE_EXTENSION, "interface"
                )
                return
            if word == "union":
                self._parse_simple_extension(
                    parent, Kind.UNION_TYPE_EXTENSION, "union"
                )
                return
            if word == "enum":
                self._parse_simple_extension(
                    parent, Kind.ENUM_TYPE_EXTENSION, "enum"
                )
                return
            if word == "input":
                self._parse_simple_extension(
                    parent, Kind.INPUT_OBJECT_TYPE_EXTENSION, "input"
                )
                return
            if (
                word == "directive"
                and self.options.experimental_directives_on_directive_definitions
            ):
                self._parse_simple_extension(
                    parent, Kind.DIRECTIVE_EXTENSION, "directive"
                )
                return
        raise self._unexpected(keyword)

    def _parse_schema_extension(mut self, parent: Int) raises GraphQLError:
        """Parse `extend schema @directives { ... }`."""
        var node = self._open(
            parent,
            Kind.SCHEMA_EXTENSION,
            Role.DEFINITION,
            self.lexer.token.start,
        )
        self._expect_keyword("extend")
        self._expect_keyword("schema")
        var count = self._count_directives(node)
        if self._expect_optional_token(TokenKind.BRACE_L):
            while True:
                _ = self._parse_operation_type_definition(node)
                count += 1
                if self._expect_optional_token(TokenKind.BRACE_R):
                    break
        if count == 0:
            raise self._unexpected(self.lexer.token)
        _ = self._close(node)

    def _parse_simple_extension(
        mut self, parent: Int, kind: Kind, keyword: StaticString
    ) raises GraphQLError:
        """Parse a scalar, union, enum, input or directive extension."""
        var node = self._open(
            parent, kind, Role.DEFINITION, self.lexer.token.start
        )
        self._expect_keyword("extend")
        self._expect_keyword(keyword)
        if kind == Kind.DIRECTIVE_EXTENSION:
            _ = self._expect_token(TokenKind.AT)
        _ = self.parse_name(node, Role.NAME)
        var count = self._count_directives(node)
        if kind == Kind.UNION_TYPE_EXTENSION:
            count += self._parse_union_member_types(node)
        elif kind == Kind.ENUM_TYPE_EXTENSION:
            count += self._parse_enum_values_definition(node)
        elif kind == Kind.INPUT_OBJECT_TYPE_EXTENSION:
            count += self._parse_input_fields_definition(node)
        if count == 0:
            raise self._unexpected(self.lexer.token)
        _ = self._close(node)

    def _parse_object_like_extension(
        mut self, parent: Int, kind: Kind, keyword: StaticString
    ) raises GraphQLError:
        """Parse an `extend type` or an `extend interface`."""
        var node = self._open(
            parent, kind, Role.DEFINITION, self.lexer.token.start
        )
        self._expect_keyword("extend")
        self._expect_keyword(keyword)
        _ = self.parse_name(node, Role.NAME)
        var count = self._parse_implements_interfaces(node)
        count += self._count_directives(node)
        count += self._parse_fields_definition(node)
        if count == 0:
            raise self._unexpected(self.lexer.token)
        _ = self._close(node)

    def _parse_directive_definition(
        mut self, parent: Int
    ) raises GraphQLError -> Int:
        """Parse `directive @name(arguments) repeatable on A | B`."""
        var node = self._open(
            parent,
            Kind.DIRECTIVE_DEFINITION,
            Role.DEFINITION,
            self.lexer.token.start,
        )
        self._parse_description(node)
        self._expect_keyword("directive")
        _ = self._expect_token(TokenKind.AT)
        _ = self.parse_name(node, Role.NAME)
        _ = self._parse_argument_defs(node)
        if self.options.experimental_directives_on_directive_definitions:
            self._parse_directives(node, True)
        if self._expect_optional_keyword("repeatable"):
            self.nodes[node].flags = FLAG_REPEATABLE
        self._expect_keyword("on")
        _ = self._expect_optional_token(TokenKind.PIPE)
        while True:
            var start = self.lexer.token
            var name = self.parse_name(node, Role.LOCATION)
            var text = self.lexer.source.slice(start.start, start.end)
            if DirectiveLocation.from_name(text) < 0:
                raise self._unexpected(start)
            _ = name
            if not self._expect_optional_token(TokenKind.PIPE):
                break
        return self._close(node)

    # --- schema coordinates -----------------------------------------------

    def parse_schema_coordinate(mut self) raises GraphQLError -> Int:
        """Parse a schema coordinate, as graphql-js `parseSchemaCoordinate`.

        Returns:
            The coordinate node's index.

        Raises:
            GraphQLError: If the source is not a schema coordinate.
        """
        var start = self.lexer.token.start
        var of_directive = self._expect_optional_token(TokenKind.AT)
        var node = self._open(NO_NODE, Kind.TYPE_COORDINATE, Role.ROOT, start)
        _ = self.parse_name(node, Role.NAME)
        var member = NO_NODE
        if not of_directive and self._expect_optional_token(TokenKind.DOT):
            member = self.parse_name(node, Role.MEMBER_NAME)
        var has_member = member != NO_NODE
        var has_argument = False
        if (of_directive or has_member) and self._expect_optional_token(
            TokenKind.PAREN_L
        ):
            _ = self.parse_name(node, Role.ARGUMENT_NAME)
            _ = self._expect_token(TokenKind.COLON)
            _ = self._expect_token(TokenKind.PAREN_R)
            has_argument = True
        if of_directive:
            if has_argument:
                self.nodes[node].kind = Kind.DIRECTIVE_ARGUMENT_COORDINATE
            else:
                self.nodes[node].kind = Kind.DIRECTIVE_COORDINATE
        elif has_member:
            if has_argument:
                self.nodes[node].kind = Kind.ARGUMENT_COORDINATE
                self.nodes[member].role = Role.FIELD_NAME
                self.nodes[node].roles = (
                    self.nodes[node].roles & ~role_bit(Role.MEMBER_NAME)
                ) | role_bit(Role.FIELD_NAME)
            else:
                self.nodes[node].kind = Kind.MEMBER_COORDINATE
        return self._close(node)


def parse(
    var source: Source, options: ParseOptions = ParseOptions()
) raises GraphQLError -> Document:
    """Parse a GraphQL document, as graphql-js `parse`.

    Args:
        source: The source to parse.
        options: The parser options.

    Returns:
        The document; its root is a `Document` node.

    Raises:
        GraphQLError: If the source is not a valid GraphQL document.
    """
    var parser = Parser(source^, options)
    var root = parser.parse_document()
    return parser^.finish(root)


def parse(
    text: StringSlice, options: ParseOptions = ParseOptions()
) raises GraphQLError -> Document:
    """Parse GraphQL text with the default source name.

    Args:
        text: The GraphQL text.
        options: The parser options.

    Returns:
        The document; its root is a `Document` node.

    Raises:
        GraphQLError: If the text is not a valid GraphQL document.
    """
    return parse(Source(text), options)


def parse_value(
    text: StringSlice, options: ParseOptions = ParseOptions()
) raises GraphQLError -> Document:
    """Parse one value, which can hold variables, as graphql-js
    `parseValue`.

    Args:
        text: The GraphQL text of a value.
        options: The parser options.

    Returns:
        A document whose root is the value node.

    Raises:
        GraphQLError: If the text is not exactly one value.
    """
    var parser = Parser(Source(text), options)
    _ = parser._expect_token(TokenKind.SOF)
    var root = parser._parse_value_literal(NO_NODE, Role.ROOT, False)
    _ = parser._expect_token(TokenKind.EOF)
    return parser^.finish(root)


def parse_const_value(
    text: StringSlice, options: ParseOptions = ParseOptions()
) raises GraphQLError -> Document:
    """Parse one constant value, as graphql-js `parseConstValue`.

    Args:
        text: The GraphQL text of a value with no variables.
        options: The parser options.

    Returns:
        A document whose root is the value node.

    Raises:
        GraphQLError: If the text is not exactly one constant value.
    """
    var parser = Parser(Source(text), options)
    _ = parser._expect_token(TokenKind.SOF)
    var root = parser._parse_value_literal(NO_NODE, Role.ROOT, True)
    _ = parser._expect_token(TokenKind.EOF)
    return parser^.finish(root)


def parse_type(
    text: StringSlice, options: ParseOptions = ParseOptions()
) raises GraphQLError -> Document:
    """Parse one type reference, as graphql-js `parseType`.

    Args:
        text: The GraphQL text of a type, such as `[String!]`.
        options: The parser options.

    Returns:
        A document whose root is the type node.

    Raises:
        GraphQLError: If the text is not exactly one type reference.
    """
    var parser = Parser(Source(text), options)
    _ = parser._expect_token(TokenKind.SOF)
    var root = parser._parse_type_reference(NO_NODE, Role.ROOT)
    _ = parser._expect_token(TokenKind.EOF)
    return parser^.finish(root)


def parse_schema_coordinate(
    text: StringSlice,
) raises GraphQLError -> Document:
    """Parse a schema coordinate, as graphql-js `parseSchemaCoordinate`.

    A coordinate has no white space: `Query.hero(episode:)`.

    Args:
        text: The coordinate text.

    Returns:
        A document whose root is the coordinate node.

    Raises:
        GraphQLError: If the text is not exactly one schema coordinate.
    """
    var parser = Parser(Source(text))
    parser.lexer.coordinates = True
    _ = parser._expect_token(TokenKind.SOF)
    var root = parser.parse_schema_coordinate()
    _ = parser._expect_token(TokenKind.EOF)
    return parser^.finish(root)
