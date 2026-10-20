# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The recovering parser of apollo-compiler.

Port of apollo-parser 0.8.6 (apollo-rs `b7eee5c`) `src/parser/mod.rs` and
`src/parser/grammar/*.rs`, and of the apollo-compiler 1.33.0
`src/ast/from_cst.rs` rules that turn the syntax tree into an AST, under
the MIT arm of their MIT OR Apache-2.0 license.

`Parser(text).parse()` does not stop at the first error. Each rule reports
an error with the upstream message, skips or inserts as upstream does, and
goes on. The result is a gql_language `Document` and the list of errors.
A node that apollo-compiler cannot convert, such as a field definition
without a type, is not in the document, as `from_cst` drops it.

The recursion limit is 500 by default, as upstream. The token limit is off
by default. When a limit is reached, the parser reports it and then no
more parser errors, as upstream.

**Differences from upstream.**

- There is no concrete syntax tree. The rules build the AST directly, and
  a node starts at its first token and ends after its last token.
  Whitespace, comments and error tokens are not in the ranges.
- `parse_selection_set` and `parse_type` are not ported: gql_compiler
  does not use them.
- A few upstream checks cannot fail, and are not ported: the keyword of a
  definition, which `_select_definition` already matched, the `{` of a
  selection set, the name of a fragment spread, the operation type of an operation
  definition, `Name` validation of a lexed name, and the "expected a type"
  of `ty`. Each place says why.
"""

from gql_language.ast import (
    FLAG_BLOCK,
    FLAG_REPEATABLE,
    FLAG_TRUE,
    NO_NODE,
    Node,
    Document,
    Kind,
    OperationType,
    Role,
)
from gql_language.directive_location import DirectiveLocation
from gql_language.source import Source
from std.memory import ArcPointer
from gql_compiler.parser_lexer import (
    ErrorData,
    LexOutput,
    SyntaxError,
    Token,
    TokenKind,
    lex,
)

comptime DEFAULT_RECURSION_LIMIT = 500
"""The upstream `DEFAULT_RECURSION_LIMIT`."""

comptime _NONE = TokenKind.ERROR
"""What `peek` returns when there is no token: upstream `None`."""

comptime _RECURSION = "parser recursion limit reached"
"""The message of the recursion limit."""


struct SyntaxTree(Movable):
    """The result of a parse: upstream `SyntaxTree`, with an AST in place of
    the concrete syntax tree."""

    var document: Document
    """The document. Its root is a `Document` node."""
    var errors: List[SyntaxError]
    """The lexer and parser errors, in the upstream order."""
    var recursion_high: Int
    """The deepest nesting reached: upstream `recursion_limit().high`."""
    var token_high: Int
    """The tokens read: upstream `token_limit().high`."""

    def __init__(
        out self,
        var document: Document,
        var errors: List[SyntaxError],
        recursion_high: Int,
        token_high: Int,
    ):
        """Wrap the parts of a result.

        Args:
            document: The document.
            errors: The errors.
            recursion_high: The deepest nesting reached.
            token_high: The tokens read.
        """
        self.document = document^
        self.errors = errors^
        self.recursion_high = recursion_high
        self.token_high = token_high

    def take_document(mut self) -> Document:
        """Move the document out, and leave an empty one.

        Returns:
            The parsed document.
        """
        var document = Document()
        swap(document, self.document)
        return document^


@fieldwise_init
struct SourceSyntaxError(Copyable, Movable):
    """A syntax error of one of the documents of a builder."""

    var source: Int
    """The index of the document in the builder's `sources`."""
    var error: SyntaxError
    """The error."""


struct _TypeResult(ImplicitlyCopyable):
    """The result of the upstream `ty::parse`."""

    var node: Int
    """The type node, or `NO_NODE` when the AST has no type."""
    var status: Int
    """0 for `Ok`, 1 for `Err(None)`, 2 for `Err(Some(token))`."""
    var token: Int
    """The popped token of `Err(Some(token))`."""

    def __init__(out self, node: Int, status: Int, token: Int = -1):
        """Make a result.

        Args:
            node: The type node.
            status: The status.
            token: The popped token.
        """
        self.node = node
        self.status = status
        self.token = token


struct _State(Movable):
    """The state of a parse. `Parser` holds it behind a pointer, so that a
    rule call passes one pointer and not every field."""

    var doc: Document
    """The document being built; its source is the input."""
    var lexed: LexOutput
    """Every token of the input, with `ERROR` tokens for lexer errors,
    and the lexer errors that they index."""
    var errors: List[SyntaxError]
    """The errors reported so far."""
    var pos: Int
    """The index of the current token in `tokens`."""
    var last_end: Int
    """The end of the last token taken into the tree."""
    var accept_errors: Bool
    """False after a limit: upstream `accept_errors`."""
    var depth: Int
    """The upstream recursion `LimitTracker.current`."""
    var depth_high: Int
    """The upstream recursion `LimitTracker.high`."""
    var depth_limit: Int
    """The upstream recursion `LimitTracker.limit`."""

    def __init__(
        out self,
        text: StringSlice,
        name: String,
        recursion_limit: Int,
        token_limit: Int,
    ):
        """Lex an input and start an empty document.

        Args:
            text: The GraphQL text.
            name: The source name, for locations.
            recursion_limit: The upstream `recursion_limit`.
            token_limit: The upstream `token_limit`.
        """
        self.lexed = lex(text, token_limit)
        self.doc = Document()
        self.doc.source = Source(text, name)
        # About one node for each token that is not whitespace.
        self.doc.nodes.reserve(len(self.lexed.tokens) // 2 + 16)
        self.errors = List[SyntaxError]()
        self.pos = 0
        self.last_end = 0
        self.accept_errors = True
        self.depth = 0
        self.depth_high = 0
        self.depth_limit = recursion_limit


struct Parser(Movable):
    """The recovering parser: upstream `apollo_parser::Parser`."""

    var s: ArcPointer[_State]
    """The state of the parse."""

    def __init__(
        out self,
        text: StringSlice,
        name: String = "GraphQL request",
        recursion_limit: Int = DEFAULT_RECURSION_LIMIT,
        token_limit: Int = Int.MAX,
    ):
        """Lex an input and make a parser for it.

        Args:
            text: The GraphQL text.
            name: The source name, for locations.
            recursion_limit: The upstream `recursion_limit`.
            token_limit: The upstream `token_limit`.
        """
        self.s = ArcPointer(_State(text, name, recursion_limit, token_limit))

    def parse(mut self) -> SyntaxTree:
        """Parse the input as a document: upstream `Parser::parse`.

        Returns:
            The document, the errors and the limits reached. The parser is
            empty after it.
        """
        self._document()
        var tokens = self.s[].lexed.token_high
        self.s[].doc.token_count = tokens
        var document = Document()
        swap(document, self.s[].doc)
        var errors = List[SyntaxError]()
        swap(errors, self.s[].errors)
        return SyntaxTree(document^, errors^, self.s[].depth_high, tokens)

    # --- tokens -----------------------------------------------------------

    @always_inline
    def _current(mut self) -> Bool:
        """Read past lexer errors to the current token: upstream
        `peek_token`. Return False when there is none."""
        if (
            self.s[].pos < len(self.s[].lexed.tokens)
            and self.s[]
            .lexed.tokens.unsafe_ptr()[unsafe_offset=self.s[].pos]
            .kind
            != TokenKind.ERROR
        ):
            return True
        return self._read_errors()

    @no_inline
    def _read_errors(mut self) -> Bool:
        """Keep the lexer errors at the current position, then return
        whether a token follows them."""
        while self.s[].pos < len(self.s[].lexed.tokens):
            var token = self.s[].lexed.tokens.unsafe_ptr()[
                unsafe_offset=self.s[].pos
            ]
            if token.kind != TokenKind.ERROR:
                return True
            ref error = self.s[].lexed.errors[Int(token.start)]
            if error.is_limit():
                self.s[].accept_errors = False
            self.s[].errors.append(error.copy())
            self.s[].pos += 1
        return False

    @always_inline
    def _peek(mut self) -> TokenKind:
        """Return the kind of the current token, or `_NONE`."""
        if self._current():
            return (
                self.s[]
                .lexed.tokens.unsafe_ptr()[unsafe_offset=self.s[].pos]
                .kind
            )
        return _NONE

    @always_inline
    def _at(mut self, kind: TokenKind) -> Bool:
        """Return True if the current token has a kind."""
        return self._peek() == kind

    def _data(
        self, token: Int
    ) -> StringSlice[origin_of(self.s[].doc.source.bytes)]:
        """Return the text of a token."""
        var found = self.s[].lexed.tokens.unsafe_ptr()[unsafe_offset=token]
        return StringSlice(
            unsafe_from_utf8=Span(self.s[].doc.source.bytes)[
                Int(found.start) : Int(found.end)
            ]
        )

    def _is_data(mut self, word: StringSlice) -> Bool:
        """Return True if the current token's text is `word`: upstream
        `peek_data() == Some(word)`."""
        if not self._current():
            return False
        return self._data(self.s[].pos) == word

    def _is_name(mut self, word: StringSlice) -> Bool:
        """Return True if the current token is the name `word`."""
        return self._at(TokenKind.NAME) and self._data(self.s[].pos) == word

    def _peek_n(self, n: Int) -> Int:
        """Return the index of the n-th token from the current one, without
        whitespace, comments and errors: upstream `peek_token_n`. Return -1
        when there is none."""
        var index = self.s[].pos
        var seen = 0
        while index < len(self.s[].lexed.tokens):
            var kind = (
                self.s[].lexed.tokens.unsafe_ptr()[unsafe_offset=index].kind
            )
            if (
                kind != TokenKind.WHITESPACE
                and kind != TokenKind.COMMENT
                and kind != TokenKind.ERROR
            ):
                seen += 1
                if seen == n:
                    return index
            index += 1
        return -1

    def _peek_n_kind(self, n: Int) -> TokenKind:
        """Return the kind of the n-th token, or `_NONE`: upstream
        `peek_n`."""
        var index = self._peek_n(n)
        if index < 0:
            return _NONE
        return self.s[].lexed.tokens.unsafe_ptr()[unsafe_offset=index].kind

    @always_inline
    def _pop(mut self) -> Int:
        """Take the current token; it must exist. Return its index."""
        var index = self.s[].pos
        self.s[].pos += 1
        return index

    @always_inline
    def _skip_ignored(mut self):
        """Skip whitespace, comments and commas: upstream `skip_ignored`."""
        while True:
            var kind = self._peek()
            if (
                kind != TokenKind.WHITESPACE
                and kind != TokenKind.COMMENT
                and kind != TokenKind.COMMA
            ):
                return
            self.s[].pos += 1

    @always_inline
    def _eat(mut self):
        """Take the current token into the tree: upstream `eat`."""
        if not self._current():
            return
        self.s[].last_end = Int(
            self.s[].lexed.tokens.unsafe_ptr()[unsafe_offset=self._pop()].end
        )

    @always_inline
    def _bump(mut self):
        """Take the current token and skip what follows: upstream `bump`."""
        self._eat()
        self._skip_ignored()

    # --- errors -----------------------------------------------------------

    @no_inline
    def _push_err(mut self, var error: SyntaxError):
        """Keep an error unless a limit was reached: upstream `push_err`."""
        if self.s[].accept_errors:
            self.s[].errors.append(error^)

    @no_inline
    def _err_at(mut self, token: Int, message: String):
        """Report an error at a token: upstream `err_at_token`."""
        var found = self.s[].lexed.tokens.unsafe_ptr()[unsafe_offset=token]
        if found.kind == TokenKind.EOF:
            self._push_err(
                SyntaxError(
                    message, String(""), ErrorData.EOF, Int(found.start)
                )
            )
        else:
            self._push_err(
                SyntaxError(
                    message,
                    String(self._data(token)),
                    ErrorData.TEXT,
                    Int(found.start),
                )
            )

    @no_inline
    def _err(mut self, message: StaticString):
        """Report an error at the current token: upstream `err`."""
        if self._current():
            self._err_at(self.s[].pos, String(message))

    @no_inline
    def _err_and_pop(mut self, message: StaticString):
        """Report an error at the current token and skip it: upstream
        `err_and_pop`."""
        if not self._current():
            return
        var token = self._pop()
        self._err_at(token, String(message))
        self.s[].last_end = Int(
            self.s[].lexed.tokens.unsafe_ptr()[unsafe_offset=token].end
        )
        self._skip_ignored()

    def _expect(mut self, kind: TokenKind, name: StaticString):
        """Take a token of a kind, or report `expected X, got Y`: upstream
        `expect`."""
        if not self._current():
            return
        if (
            self.s[].lexed.tokens.unsafe_ptr()[unsafe_offset=self.s[].pos].kind
            == kind
        ):
            self._bump()
            return
        self._expected(name)

    @no_inline
    def _expected(mut self, name: StaticString):
        """Report `expected X, got Y` at the current token."""
        if (
            self.s[].lexed.tokens.unsafe_ptr()[unsafe_offset=self.s[].pos].kind
            == TokenKind.EOF
        ):
            self._err_at(self.s[].pos, String("expected ", name, ", got EOF"))
        else:
            self._err_at(
                self.s[].pos,
                String("expected ", name, ", got ", self._data(self.s[].pos)),
            )

    @no_inline
    def _limit_err(mut self):
        """Report the recursion limit and stop reporting: upstream
        `limit_err`."""
        if not self._current():
            return
        self._push_err(
            SyntaxError(
                _RECURSION,
                String(""),
                ErrorData.LIMIT,
                Int(
                    self.s[]
                    .lexed.tokens.unsafe_ptr()[unsafe_offset=self.s[].pos]
                    .start
                ),
            )
        )
        self.s[].accept_errors = False

    @always_inline
    def _deeper(mut self) -> Bool:
        """Go one level deeper; return True at the limit: upstream
        `check_and_increment`."""
        self.s[].depth += 1
        if self.s[].depth > self.s[].depth_high:
            self.s[].depth_high = self.s[].depth
        if self.s[].depth > self.s[].depth_limit:
            self.s[].depth -= 1
            return True
        return False

    # --- nodes ------------------------------------------------------------

    @always_inline
    def _start(mut self) -> Int:
        """Return where a node that starts now begins."""
        if self._current():
            return Int(
                self.s[]
                .lexed.tokens.unsafe_ptr()[unsafe_offset=self.s[].pos]
                .start
            )
        return self.s[].last_end

    def _new(mut self, kind: Kind, role: Role, flags: UInt8 = 0) -> Int:
        """Add a node that starts at the current token, with no parent."""
        var start = Int32(self._start())
        self.s[].doc.nodes.append(
            Node(kind, role, flags, start, start, NO_NODE, NO_NODE, NO_NODE, 0)
        )
        return len(self.s[].doc.nodes) - 1

    @always_inline
    def _finish(mut self, node: Int) -> Int:
        """End a node after the last token taken, and return it."""
        if (
            Int32(self.s[].last_end)
            > self.s[].doc.nodes.unsafe_ptr()[unsafe_offset=node].start
        ):
            self.s[].doc.nodes.unsafe_ptr()[unsafe_offset=node].end = Int32(
                self.s[].last_end
            )
        return node

    @always_inline
    def _attach(mut self, parent: Int, child: Int):
        """Make a node the last child of another, unless it is `NO_NODE`."""
        if child != NO_NODE:
            self.s[].doc.append_child(parent, child)

    @always_inline
    def _token_node(mut self, kind: Kind, role: Role, flags: UInt8 = 0) -> Int:
        """Add a node for the current token and take the token."""
        var node = self._new(kind, role, flags)
        var token = self.s[].pos
        self._bump()
        self.s[].doc.nodes.unsafe_ptr()[unsafe_offset=node].end = (
            self.s[].lexed.tokens.unsafe_ptr()[unsafe_offset=token].end
        )
        return node

    # --- grammar/document.rs ----------------------------------------------

    def _document(mut self):
        """Parse the definitions: upstream `document`."""
        self._skip_ignored()
        var first = self._peek()
        if first == _NONE or first == TokenKind.EOF:
            self._err("Unexpected <EOF>.")
        while True:
            var kind = self._peek()
            if kind == _NONE or kind == TokenKind.EOF:
                return
            if kind == TokenKind.STRING_VALUE:
                var word = self._peek_n(2)
                if word < 0:
                    self._err_and_pop(
                        "expected a definition after this StringValue"
                    )
                else:
                    self._select_definition(word)
            elif kind == TokenKind.NAME or kind == TokenKind.L_CURLY:
                self._select_definition(self.s[].pos)
            else:
                self._err_and_pop(
                    "expected a StringValue, Name or OperationDefinition"
                )

    def _select_definition(mut self, word: Int):
        """Parse the definition that a keyword starts: upstream
        `select_definition`."""
        var data = self._data(word)
        var node = NO_NODE
        if data == "directive":
            node = self._directive_definition()
        elif data == "enum":
            node = self._enum_type_definition()
        elif data == "extend":
            node = self._extensions()
        elif data == "fragment":
            node = self._fragment_definition()
        elif data == "input":
            node = self._input_object_type_definition()
        elif data == "interface":
            node = self._object_like_definition(Kind.INTERFACE_TYPE_DEFINITION)
        elif data == "type":
            node = self._object_like_definition(Kind.OBJECT_TYPE_DEFINITION)
        elif (
            data == "query"
            or data == "mutation"
            or data == "subscription"
            or data == "{"
        ):
            node = self._operation_definition()
        elif data == "scalar":
            node = self._scalar_type_definition()
        elif data == "schema":
            node = self._schema_definition()
        elif data == "union":
            node = self._union_type_definition()
        else:
            self._err_and_pop("expected definition")
        self._attach(self.s[].doc.root, node)

    # --- grammar/operation.rs ---------------------------------------------

    def _operation_definition(mut self) -> Int:
        """Parse an operation: upstream `operation_definition`."""
        var kind = self._peek()
        if kind == TokenKind.L_CURLY:
            var node = self._new(Kind.OPERATION_DEFINITION, Role.DEFINITION)
            var set = self._selection_set()
            self._attach(node, set)
            return self._finish(node)
        if kind != TokenKind.NAME:
            self._err_and_pop("expected an Operation Type or a Selection Set")
            return NO_NODE
        var node = self._new(Kind.OPERATION_DEFINITION, Role.DEFINITION)
        # `_select_definition` sends only `query`, `mutation` and
        # `subscription` here, so the operation type is valid.
        self.s[].doc.nodes.unsafe_ptr()[unsafe_offset=node].flags = UInt8(
            self._operation_type()
        )
        var ok = True
        if self._at(TokenKind.NAME):
            self._attach(node, self._name(Role.NAME))
        if self._at(TokenKind.L_PAREN):
            self._variable_definitions(node)
        if self._at(TokenKind.AT):
            self._directives(node, False)
        if self._at(TokenKind.L_CURLY):
            self._attach(node, self._selection_set())
        else:
            self._err_and_pop("expected a Selection Set")
            ok = False
        _ = self._finish(node)
        return node if ok else NO_NODE

    def _operation_type(mut self) -> Int:
        """Parse `query`, `mutation` or `subscription`: upstream
        `operation_type`. Return the `OperationType` value, or -1. The
        current token is a name."""
        var data = self._data(self.s[].pos)
        var operation = -1
        if data == "query":
            operation = Int(OperationType.QUERY.value)
        elif data == "subscription":
            operation = Int(OperationType.SUBSCRIPTION.value)
        elif data == "mutation":
            operation = Int(OperationType.MUTATION.value)
        if operation < 0:
            self._err_and_pop(
                "expected either a 'mutation', a 'query', or a 'subscription'"
            )
        else:
            self._bump()
        return operation

    # --- grammar/name.rs --------------------------------------------------

    def _name(mut self, role: Role) -> Int:
        """Parse a name: upstream `name`."""
        if self._at(TokenKind.NAME):
            return self._token_node(Kind.NAME, role)
        self._err("expected a Name")
        return NO_NODE

    # --- grammar/selection.rs ---------------------------------------------

    def _selection_set(mut self) -> Int:
        """Parse `{ selections }`: upstream `selection_set`. The current
        token is `{`: each caller checks it, as upstream does twice."""
        var node = self._new(Kind.SELECTION_SET, Role.SELECTION_SET)
        self._bump()
        if self._deeper():
            self._limit_err()
            return self._finish(node)
        self._selection(node)
        self.s[].depth -= 1
        self._expect(TokenKind.R_CURLY, "R_CURLY")
        return self._finish(node)

    def _selection(mut self, parent: Int):
        """Parse the selections of a set: upstream `selection`."""
        var has_selection = False
        while True:
            var kind = self._peek()
            if kind == TokenKind.SPREAD:
                var next = self._peek_n(2)
                if next < 0:
                    self._err_and_pop(
                        "expected an Inline Fragment or a Fragment Spread"
                    )
                    break
                var next_kind = (
                    self.s[].lexed.tokens.unsafe_ptr()[unsafe_offset=next].kind
                )
                if next_kind == TokenKind.NAME and not (
                    self._data(next) == "on"
                ):
                    self._attach(parent, self._fragment_spread())
                elif (
                    next_kind == TokenKind.AT
                    or next_kind == TokenKind.NAME
                    or next_kind == TokenKind.L_CURLY
                ):
                    self._attach(parent, self._inline_fragment())
                else:
                    self._err(
                        "expected an Inline Fragment or a Fragment Spread"
                    )
                    self._bump()
                has_selection = True
            elif kind == TokenKind.NAME:
                self._attach(parent, self._field())
                has_selection = True
            else:
                break
        if not has_selection:
            self._err("expected at least one Selection in Selection Set")

    # --- grammar/field.rs -------------------------------------------------

    def _field(mut self) -> Int:
        """Parse a field: upstream `field`. The current token is a name."""
        var node = self._new(Kind.FIELD, Role.SELECTION)
        if self._peek_n_kind(2) == TokenKind.COLON:
            self._attach(node, self._name(Role.ALIAS))
            self._bump()
        var name = self._name(Role.NAME)
        self._attach(node, name)
        if self._at(TokenKind.L_PAREN):
            self._arguments(node, False)
        if self._at(TokenKind.AT):
            self._directives(node, False)
        if self._at(TokenKind.L_CURLY):
            self._attach(node, self._selection_set())
        _ = self._finish(node)
        return node if name != NO_NODE else NO_NODE

    # --- grammar/argument.rs ----------------------------------------------

    def _arguments(mut self, parent: Int, is_const: Bool):
        """Parse `( arguments )`: upstream `arguments`."""
        self._bump()
        if self._at(TokenKind.NAME):
            self._attach(parent, self._argument(is_const))
        else:
            self._err("expected an Argument")
        while self._at(TokenKind.NAME):
            self._attach(parent, self._argument(is_const))
        self._expect(TokenKind.R_PAREN, "R_PAREN")

    def _argument(mut self, is_const: Bool) -> Int:
        """Parse `name: value`: upstream `argument`."""
        var node = self._new(Kind.ARGUMENT, Role.ARGUMENT)
        self._attach(node, self._name(Role.NAME))
        var value = NO_NODE
        if self._at(TokenKind.COLON):
            self._bump()
            value = self._value(is_const, False, Role.VALUE)
            self._attach(node, value)
        _ = self._finish(node)
        return node if value != NO_NODE else NO_NODE

    # --- grammar/fragment.rs ----------------------------------------------

    def _fragment_definition(mut self) -> Int:
        """Parse a fragment definition: upstream `fragment_definition`."""
        var node = self._new(Kind.FRAGMENT_DEFINITION, Role.DEFINITION)
        self._bump()
        var name = self._fragment_name()
        self._attach(node, name)
        var condition = self._type_condition()
        self._attach(node, condition)
        if self._at(TokenKind.AT):
            self._directives(node, False)
        var set = NO_NODE
        if self._at(TokenKind.L_CURLY):
            set = self._selection_set()
            self._attach(node, set)
        else:
            self._err("expected a Selection Set")
        _ = self._finish(node)
        if name == NO_NODE or condition == NO_NODE or set == NO_NODE:
            return NO_NODE
        return node

    def _fragment_name(mut self) -> Int:
        """Parse a fragment name: upstream `fragment_name`."""
        if self._is_name("on"):
            self._err("Fragment Name cannot be 'on'")
            return NO_NODE
        if self._at(TokenKind.NAME):
            return self._name(Role.NAME)
        self._err("expected Fragment Name")
        return NO_NODE

    def _type_condition(mut self) -> Int:
        """Parse `on Type`: upstream `type_condition`. Return the named
        type, or `NO_NODE`."""
        if not self._current():
            self._err("expected Type Condition")
            return NO_NODE
        if self._is_name("on"):
            self._bump()
        else:
            self._err("expected 'on'")
        if self._at(TokenKind.NAME):
            return self._named_type(Role.TYPE_CONDITION)
        self._err("expected a Name in Type Condition")
        return NO_NODE

    def _inline_fragment(mut self) -> Int:
        """Parse `... on Type @directives { }`: upstream
        `inline_fragment`."""
        var node = self._new(Kind.INLINE_FRAGMENT, Role.SELECTION)
        self._bump()
        var ok = True
        if self._at(TokenKind.NAME):
            var condition = self._type_condition()
            self._attach(node, condition)
            ok = condition != NO_NODE
        if self._at(TokenKind.AT):
            self._directives(node, False)
        if self._at(TokenKind.L_CURLY):
            self._attach(node, self._selection_set())
        else:
            self._err("expected Selection Set")
            ok = False
        _ = self._finish(node)
        return node if ok else NO_NODE

    def _fragment_spread(mut self) -> Int:
        """Parse `...name @directives`: upstream `fragment_spread`."""
        var node = self._new(Kind.FRAGMENT_SPREAD, Role.SELECTION)
        self._bump()
        # `_selection` comes here only when a name other than `on` follows
        # the `...`, so upstream's "expected a Name" cannot happen.
        self._attach(node, self._name(Role.NAME))
        if self._at(TokenKind.AT):
            self._directives(node, False)
        return self._finish(node)

    # --- grammar/variable.rs ----------------------------------------------

    def _variable_definitions(mut self, parent: Int):
        """Parse `( $name: Type ... )`: upstream `variable_definitions`."""
        self._bump()
        if self._at(TokenKind.DOLLAR):
            self._attach(parent, self._variable_definition())
        else:
            self._err("expected a Variable Definition")
        while self._at(TokenKind.DOLLAR):
            self._attach(parent, self._variable_definition())
        self._expect(TokenKind.R_PAREN, "R_PAREN")

    def _variable_definition(mut self) -> Int:
        """Parse `$name: Type = default @directives`: upstream
        `variable_definition`."""
        var node = self._new(Kind.VARIABLE_DEFINITION, Role.VARIABLE_DEFINITION)
        var variable = self._variable(Role.VARIABLE)
        self._attach(node, variable)
        var ok = variable != NO_NODE
        if self._at(TokenKind.COLON):
            self._bump()
            var kind = self._peek()
            if kind == TokenKind.NAME or kind == TokenKind.L_BRACKET:
                var type = self._ty(Role.TYPE)
                self._attach(node, type)
                ok = ok and type != NO_NODE
                if self._at(TokenKind.EQ):
                    ok = self._default_value(node) and ok
                if self._at(TokenKind.AT):
                    self._directives(node, True)
            else:
                self._err("expected a Type")
                ok = False
        else:
            self._err("expected a Name")
            ok = False
        _ = self._finish(node)
        return node if ok else NO_NODE

    def _variable(mut self, role: Role) -> Int:
        """Parse `$name`: upstream `variable`."""
        var node = self._new(Kind.VARIABLE, role)
        self._bump()
        var name = self._name(Role.NAME)
        self._attach(node, name)
        _ = self._finish(node)
        return node if name != NO_NODE else NO_NODE

    # --- grammar/directive.rs (use) ---------------------------------------

    def _directives(mut self, parent: Int, is_const: Bool):
        """Parse `@name(arguments) ...`: upstream `directives`."""
        while self._at(TokenKind.AT):
            var node = self._new(Kind.DIRECTIVE, Role.DIRECTIVE)
            self._expect(TokenKind.AT, "AT")
            var name = self._name(Role.NAME)
            self._attach(node, name)
            if self._at(TokenKind.L_PAREN):
                self._arguments(node, is_const)
            _ = self._finish(node)
            if name != NO_NODE:
                self._attach(parent, node)

    # --- grammar/value.rs -------------------------------------------------

    def _value(mut self, is_const: Bool, pop_on_error: Bool, role: Role) -> Int:
        """Parse a value: upstream `value`."""
        var kind = self._peek()
        if kind == TokenKind.DOLLAR:
            if is_const:
                if pop_on_error:
                    self._err_and_pop(
                        "unexpected variable value in a Const context"
                    )
                else:
                    self._err("unexpected variable value in a Const context")
            return self._variable(role)
        if kind == TokenKind.INT:
            return self._token_node(Kind.INT, role)
        if kind == TokenKind.FLOAT:
            return self._token_node(Kind.FLOAT, role)
        if kind == TokenKind.STRING_VALUE:
            return self._string_value(role)
        if kind == TokenKind.NAME:
            var data = self._data(self.s[].pos)
            if data == "true":
                return self._token_node(Kind.BOOLEAN, role, FLAG_TRUE)
            if data == "false":
                return self._token_node(Kind.BOOLEAN, role)
            if data == "null":
                return self._token_node(Kind.NULL, role)
            return self._token_node(Kind.ENUM, role)
        if kind == TokenKind.L_BRACKET:
            return self._list_value(is_const, role)
        if kind == TokenKind.L_CURLY:
            return self._object_value(is_const, role)
        if pop_on_error:
            self._err_and_pop("expected a valid Value")
        else:
            self._err("expected a valid Value")
        return NO_NODE

    def _string_value(mut self, role: Role) -> Int:
        """Parse a string or a block string; the current token is one."""
        var token = self.s[].lexed.tokens.unsafe_ptr()[
            unsafe_offset=self.s[].pos
        ]
        var flags: UInt8 = 0
        # Only a block string starts with two quotes and is longer than `""`.
        if (
            token.end - token.start > 2
            and self.s[].doc.source.bytes[Int(token.start) + 1] == 34
        ):
            flags = FLAG_BLOCK
        return self._token_node(Kind.STRING, role, flags)

    def _list_value(mut self, is_const: Bool, role: Role) -> Int:
        """Parse `[ values ]`: upstream `list_value`."""
        var node = self._new(Kind.LIST, role)
        self._bump()
        while True:
            var kind = self._peek()
            if kind == _NONE or kind == TokenKind.EOF:
                break
            if kind == TokenKind.R_BRACKET:
                self._bump()
                break
            if self._deeper():
                self._limit_err()
                break
            self._attach(node, self._value(is_const, True, Role.LIST_ITEM))
            self.s[].depth -= 1
        return self._finish(node)

    def _object_value(mut self, is_const: Bool, role: Role) -> Int:
        """Parse `{ name: value ... }`: upstream `object_value`."""
        var node = self._new(Kind.OBJECT, role)
        self._bump()
        while self._at(TokenKind.NAME):
            var field = self._new(Kind.OBJECT_FIELD, Role.FIELD)
            self._attach(field, self._name(Role.NAME))
            var value = NO_NODE
            if self._at(TokenKind.COLON):
                self._bump()
                if self._deeper():
                    self._limit_err()
                else:
                    value = self._value(is_const, True, Role.VALUE)
                    self._attach(field, value)
                    self.s[].depth -= 1
            _ = self._finish(field)
            if value != NO_NODE:
                self._attach(node, field)
        self._expect(TokenKind.R_CURLY, "R_CURLY")
        return self._finish(node)

    def _default_value(mut self, parent: Int) -> Bool:
        """Parse `= value`: upstream `default_value`. Return False when the
        value cannot be converted, which drops the parent."""
        self._bump()
        var value = self._value(True, False, Role.DEFAULT_VALUE)
        self._attach(parent, value)
        return value != NO_NODE

    # --- grammar/ty.rs ----------------------------------------------------

    def _ty(mut self, role: Role) -> Int:
        """Parse a type: upstream `ty`. The current token is a name or `[`,
        as each caller checks, so `ty::parse` returns `Ok` and upstream's
        "expected a type" cannot happen here."""
        return self._parse_type(role).node

    def _parse_type(mut self, role: Role) -> _TypeResult:
        """Parse a named, list or non-null type: upstream `ty::parse`."""
        var kind = self._peek()
        var start = self._start()
        var node = NO_NODE
        if kind == TokenKind.L_BRACKET:
            var list = self._new(Kind.LIST_TYPE, role)
            self._bump()
            if self._deeper():
                self._limit_err()
                return _TypeResult(NO_NODE, 0)
            var inner = self._parse_type(Role.TYPE)
            self.s[].depth -= 1
            if inner.status == 2:
                self._err_at(inner.token, "expected item type")
            self._expect(TokenKind.R_BRACKET, "R_BRACK")
            _ = self._finish(list)
            if inner.node != NO_NODE:
                self._attach(list, inner.node)
                node = list
        elif kind == TokenKind.NAME:
            node = self._new(Kind.NAMED_TYPE, role)
            var name = self._new(Kind.NAME, Role.NAME)
            var token = self._pop()
            self.s[].last_end = Int(
                self.s[].lexed.tokens.unsafe_ptr()[unsafe_offset=token].end
            )
            self.s[].doc.nodes.unsafe_ptr()[unsafe_offset=name].end = (
                self.s[].lexed.tokens.unsafe_ptr()[unsafe_offset=token].end
            )
            self.s[].doc.append_child(node, name)
            _ = self._finish(node)
        elif kind == _NONE:
            return _TypeResult(NO_NODE, 1)
        else:
            return _TypeResult(NO_NODE, 2, self._pop())
        self._skip_ignored()
        if self._at(TokenKind.BANG):
            var wrapper = self._new(Kind.NON_NULL_TYPE, role)
            self.s[].doc.nodes.unsafe_ptr()[
                unsafe_offset=wrapper
            ].start = Int32(start)
            self._eat()
            _ = self._finish(wrapper)
            if node != NO_NODE:
                self.s[].doc.nodes.unsafe_ptr()[
                    unsafe_offset=node
                ].role = Role.TYPE
                self.s[].doc.append_child(wrapper, node)
                node = wrapper
        self._skip_ignored()
        return _TypeResult(node, 0)

    def _named_type(mut self, role: Role) -> Int:
        """Parse a named type: upstream `named_type`."""
        if not self._at(TokenKind.NAME):
            return NO_NODE
        var node = self._new(Kind.NAMED_TYPE, role)
        self.s[].doc.append_child(node, self._name(Role.NAME))
        return self._finish(node)

    # --- grammar/description.rs -------------------------------------------

    def _description(mut self, parent: Int):
        """Parse a description, if the current token is a string: upstream
        `description`."""
        if self._at(TokenKind.STRING_VALUE):
            self._attach(parent, self._string_value(Role.DESCRIPTION))

    # --- grammar/directive.rs ---------------------------------------------

    def _directive_definition(mut self) -> Int:
        """Parse a directive definition: upstream `directive_definition`."""
        var node = self._new(Kind.DIRECTIVE_DEFINITION, Role.DEFINITION)
        self._description(node)
        # The keyword is there: `_select_definition` chose this rule by it.
        self._bump()
        if self._at(TokenKind.AT):
            self._bump()
        else:
            self._err("expected @ symbol")
        var name = self._name(Role.NAME)
        self._attach(node, name)
        if self._at(TokenKind.L_PAREN):
            self._arguments_definition(node)
        if self._is_data("repeatable"):
            self._bump()
            self.s[].doc.nodes.unsafe_ptr()[
                unsafe_offset=node
            ].flags = FLAG_REPEATABLE
        if self._current():
            if self._is_data("on"):
                self._bump()
            else:
                self._err("expected Directive Locations")
        var kind = self._peek()
        if kind == TokenKind.NAME or kind == TokenKind.PIPE:
            if self._at(TokenKind.PIPE):
                self._bump()
            self._directive_location(node)
            while self._at(TokenKind.PIPE):
                self._bump()
                self._directive_location(node)
        else:
            self._err("expected valid Directive Location")
        _ = self._finish(node)
        return node if name != NO_NODE else NO_NODE

    def _directive_location(mut self, parent: Int):
        """Parse one directive location: upstream `directive_location`."""
        if not self._current():
            return
        if not self._at(TokenKind.NAME):
            self._err("expected Directive Location")
            return
        if DirectiveLocation.from_name(self._data(self.s[].pos)) >= 0:
            self._attach(parent, self._token_node(Kind.NAME, Role.LOCATION))
        else:
            self._err("expected valid Directive Location")

    # --- grammar/schema.rs ------------------------------------------------

    def _schema_definition(mut self) -> Int:
        """Parse a schema definition: upstream `schema_definition`."""
        var node = self._new(Kind.SCHEMA_DEFINITION, Role.DEFINITION)
        self._description(node)
        # The keyword is there: `_select_definition` chose this rule by it.
        self._bump()
        if self._at(TokenKind.AT):
            self._directives(node, True)
        if self._at(TokenKind.L_CURLY):
            self._bump()
            if not self._at(TokenKind.NAME):
                self._err("expected Root Operation Type Definition")
            self._root_operations(node)
        return self._finish(node)

    def _root_operations(mut self, parent: Int):
        """Parse the root operations and the `}` of a schema."""
        while self._at(TokenKind.NAME):
            var node = self._new(
                Kind.OPERATION_TYPE_DEFINITION, Role.OPERATION_TYPE
            )
            var operation = self._operation_type()
            var type = NO_NODE
            if self._at(TokenKind.COLON):
                self._bump()
                type = self._named_type(Role.TYPE)
                self._attach(node, type)
            else:
                self._err("expected a Name Type")
            _ = self._finish(node)
            if operation >= 0 and type != NO_NODE:
                self.s[].doc.nodes.unsafe_ptr()[
                    unsafe_offset=node
                ].flags = UInt8(operation)
                self._attach(parent, node)
        self._expect(TokenKind.R_CURLY, "R_CURLY")

    def _schema_extension(mut self) -> Int:
        """Parse a schema extension: upstream `schema_extension`."""
        var node = self._new(Kind.SCHEMA_EXTENSION, Role.DEFINITION)
        self._bump()
        self._bump()
        var meets_requirements = False
        if self._at(TokenKind.AT):
            meets_requirements = True
            self._directives(node, True)
        if self._at(TokenKind.L_CURLY):
            self._bump()
            if self._at(TokenKind.NAME):
                meets_requirements = True
            self._root_operations(node)
        if not meets_requirements:
            self._err("expected directives or Root Operation Type Definition")
        return self._finish(node)

    # --- grammar/scalar.rs ------------------------------------------------

    def _scalar_type_definition(mut self) -> Int:
        """Parse a scalar definition: upstream `scalar_type_definition`."""
        var node = self._new(Kind.SCALAR_TYPE_DEFINITION, Role.DEFINITION)
        self._description(node)
        # The keyword is there: `_select_definition` chose this rule by it.
        self._bump()
        var name = self._definition_name(node, "expected a Name")
        if self._at(TokenKind.AT):
            self._directives(node, True)
        _ = self._finish(node)
        return node if name != NO_NODE else NO_NODE

    def _definition_name(mut self, parent: Int, message: StaticString) -> Int:
        """Parse the name of a definition, or report `message`."""
        if self._at(TokenKind.NAME):
            var name = self._name(Role.NAME)
            self._attach(parent, name)
            return name
        self._err(message)
        return NO_NODE

    def _scalar_type_extension(mut self) -> Int:
        """Parse a scalar extension: upstream `scalar_type_extension`."""
        var node = self._new(Kind.SCALAR_TYPE_EXTENSION, Role.DEFINITION)
        self._bump()
        self._bump()
        var name = self._definition_name(node, "expected a Name")
        if self._at(TokenKind.AT):
            self._directives(node, True)
        else:
            self._err("expected Directives")
        _ = self._finish(node)
        return node if name != NO_NODE else NO_NODE

    # --- grammar/object.rs and grammar/interface.rs -----------------------

    def _object_like_definition(mut self, kind: Kind) -> Int:
        """Parse an object or interface definition: upstream
        `object_type_definition` and `interface_type_definition`."""
        var node = self._new(kind, Role.DEFINITION)
        self._description(node)
        # The keyword is there: `_select_definition` chose this rule by it.
        self._bump()
        var object = kind == Kind.OBJECT_TYPE_DEFINITION
        var message: StaticString = "expected a Name"
        if object:
            message = "expected a name"
        var name = self._definition_name(node, message)
        if self._is_name("implements") if object else self._is_data(
            "implements"
        ):
            self._implements_interfaces(node)
        if self._at(TokenKind.AT):
            self._directives(node, True)
        if self._at(TokenKind.L_CURLY):
            self._fields_definition(node)
        _ = self._finish(node)
        return node if name != NO_NODE else NO_NODE

    def _object_like_extension(
        mut self, kind: Kind, message: StaticString
    ) -> Int:
        """Parse an object or interface extension: upstream
        `object_type_extension` and `interface_type_extension`."""
        var node = self._new(kind, Role.DEFINITION)
        self._bump()
        self._bump()
        var meets_requirements = False
        var name = self._definition_name(node, "expected a Name")
        if self._is_data("implements"):
            meets_requirements = True
            self._implements_interfaces(node)
        if self._at(TokenKind.AT):
            meets_requirements = True
            self._directives(node, True)
        if self._at(TokenKind.L_CURLY):
            meets_requirements = True
            self._fields_definition(node)
        if not meets_requirements:
            self._err(message)
        _ = self._finish(node)
        return node if name != NO_NODE else NO_NODE

    def _implements_interfaces(mut self, parent: Int):
        """Parse `implements A & B`: upstream `implements_interfaces`."""
        self._bump()
        if self._at(TokenKind.AMP):
            self._bump()
        self._implemented_interface(parent)
        while self._at(TokenKind.AMP):
            self._bump()
            self._implemented_interface(parent)

    def _implemented_interface(mut self, parent: Int):
        """Parse one interface name of `implements`."""
        if self._at(TokenKind.NAME):
            self._attach(parent, self._named_type(Role.INTERFACE))
        else:
            self._err("expected an Interface name")

    # --- grammar/field.rs (definitions) -----------------------------------

    @always_inline
    def _at_definition(mut self) -> Bool:
        """Return True if the current token is a name or a string."""
        var kind = self._peek()
        return kind == TokenKind.NAME or kind == TokenKind.STRING_VALUE

    def _fields_definition(mut self, parent: Int):
        """Parse `{ fields }`: upstream `fields_definition`."""
        self._bump()
        if not self._at_definition():
            self._err("expected Field Definition")
        while self._at_definition():
            self._attach(parent, self._field_definition())
        self._expect(TokenKind.R_CURLY, "R_CURLY")

    def _field_definition(mut self) -> Int:
        """Parse a field definition: upstream `field_definition`."""
        var node = self._new(Kind.FIELD_DEFINITION, Role.FIELD)
        self._description(node)
        var name = self._name(Role.NAME)
        self._attach(node, name)
        if self._at(TokenKind.L_PAREN):
            self._arguments_definition(node)
        var type = NO_NODE
        if self._at(TokenKind.COLON):
            self._bump()
            var kind = self._peek()
            if kind == TokenKind.NAME or kind == TokenKind.L_BRACKET:
                type = self._ty(Role.TYPE)
                self._attach(node, type)
                if self._at(TokenKind.AT):
                    self._directives(node, True)
            else:
                self._err("expected a Type")
        else:
            self._err("expected a type")
        _ = self._finish(node)
        return node if name != NO_NODE and type != NO_NODE else NO_NODE

    def _arguments_definition(mut self, parent: Int):
        """Parse `( input values )`: upstream `arguments_definition`."""
        self._bump()
        if not self._at_definition():
            self._err("expected an Argument Definition")
        while self._at_definition():
            self._attach(parent, self._input_value_definition(Role.ARGUMENT))
        self._expect(TokenKind.R_PAREN, "R_PAREN")

    # --- grammar/input.rs -------------------------------------------------

    def _input_value_definition(mut self, role: Role) -> Int:
        """Parse `name: Type = default @directives`: upstream
        `input_value_definition`."""
        var node = self._new(Kind.INPUT_VALUE_DEFINITION, role)
        self._description(node)
        var name = self._name(Role.NAME)
        self._attach(node, name)
        var ok = name != NO_NODE
        if self._at(TokenKind.COLON):
            self._bump()
            var kind = self._peek()
            if kind == TokenKind.NAME or kind == TokenKind.L_BRACKET:
                var type = self._ty(Role.TYPE)
                self._attach(node, type)
                ok = ok and type != NO_NODE
                if self._at(TokenKind.EQ):
                    ok = self._default_value(node) and ok
                if self._at(TokenKind.AT):
                    self._directives(node, True)
            else:
                self._err("expected a Type")
                ok = False
        else:
            self._err("expected a Name")
            ok = False
        _ = self._finish(node)
        return node if ok else NO_NODE

    def _input_object_type_definition(mut self) -> Int:
        """Parse an input object definition: upstream
        `input_object_type_definition`."""
        var node = self._new(Kind.INPUT_OBJECT_TYPE_DEFINITION, Role.DEFINITION)
        self._description(node)
        # The keyword is there: `_select_definition` chose this rule by it.
        self._bump()
        var name = self._definition_name(node, "expected a Name")
        if self._at(TokenKind.AT):
            self._directives(node, True)
        if self._at(TokenKind.L_CURLY):
            self._input_fields_definition(node)
        _ = self._finish(node)
        return node if name != NO_NODE else NO_NODE

    def _input_fields_definition(mut self, parent: Int):
        """Parse `{ input values }`: upstream `input_fields_definition`."""
        self._bump()
        if not self._at_definition():
            self._err("expected an Input Value Definition")
        while self._at_definition():
            self._attach(parent, self._input_value_definition(Role.FIELD))
        self._expect(TokenKind.R_CURLY, "R_CURLY")

    # --- grammar/union_.rs ------------------------------------------------

    def _union_type_definition(mut self) -> Int:
        """Parse a union definition: upstream `union_type_definition`."""
        var node = self._new(Kind.UNION_TYPE_DEFINITION, Role.DEFINITION)
        self._description(node)
        # The keyword is there: `_select_definition` chose this rule by it.
        self._bump()
        var name = self._definition_name(node, "expected a Name")
        if self._at(TokenKind.AT):
            self._directives(node, True)
        if self._at(TokenKind.EQ):
            self._union_member_types(node)
        _ = self._finish(node)
        return node if name != NO_NODE else NO_NODE

    def _union_type_extension(mut self) -> Int:
        """Parse a union extension: upstream `union_type_extension`."""
        var node = self._new(Kind.UNION_TYPE_EXTENSION, Role.DEFINITION)
        self._bump()
        self._bump()
        var meets_requirements = False
        var name = self._definition_name(node, "expected a Name")
        if self._at(TokenKind.AT):
            meets_requirements = True
            self._directives(node, True)
        if self._at(TokenKind.EQ):
            meets_requirements = True
            self._union_member_types(node)
        if not meets_requirements:
            self._err("expected Directives or Union Member Types")
        _ = self._finish(node)
        return node if name != NO_NODE else NO_NODE

    def _union_member_types(mut self, parent: Int):
        """Parse `= A | B`: upstream `union_member_types`."""
        self._bump()
        if self._at(TokenKind.PIPE):
            self._bump()
        self._union_member(parent)
        while self._at(TokenKind.PIPE):
            self._bump()
            self._union_member(parent)

    def _union_member(mut self, parent: Int):
        """Parse one member of a union."""
        if self._at(TokenKind.NAME):
            self._attach(parent, self._named_type(Role.MEMBER_TYPE))
        else:
            self._err("expected Union Member Type")

    # --- grammar/enum_.rs -------------------------------------------------

    def _enum_type_definition(mut self) -> Int:
        """Parse an enum definition: upstream `enum_type_definition`."""
        var node = self._new(Kind.ENUM_TYPE_DEFINITION, Role.DEFINITION)
        self._description(node)
        # The keyword is there: `_select_definition` chose this rule by it.
        self._bump()
        var name = self._definition_name(node, "expected a Name")
        if self._at(TokenKind.AT):
            self._directives(node, True)
        if self._at(TokenKind.L_CURLY):
            self._enum_values_definition(node)
        _ = self._finish(node)
        return node if name != NO_NODE else NO_NODE

    def _enum_values_definition(mut self, parent: Int):
        """Parse `{ values }`: upstream `enum_values_definition`."""
        self._bump()
        if not self._at_definition():
            self._err("expected Enum Value Definition")
        while self._at_definition():
            var node = self._new(Kind.ENUM_VALUE_DEFINITION, Role.ENUM_VALUE)
            self._description(node)
            var name = NO_NODE
            if self._at(TokenKind.NAME):
                var data = self._data(self.s[].pos)
                if data == "true" or data == "false" or data == "null":
                    self._err("invalid Enum Value")
                name = self._name(Role.NAME)
                self._attach(node, name)
            else:
                self._err("expected Enum Value")
            if self._at(TokenKind.AT):
                self._directives(node, True)
            _ = self._finish(node)
            if name != NO_NODE:
                self._attach(parent, node)
        self._expect(TokenKind.R_CURLY, "R_CURLY")

    # --- grammar/input.rs (extension) and grammar/extensions.rs ------------

    def _simple_extension(mut self, kind: Kind, message: StaticString) -> Int:
        """Parse an enum or input object extension: upstream
        `enum_type_extension` and `input_object_type_extension`."""
        var node = self._new(kind, Role.DEFINITION)
        self._bump()
        self._bump()
        var meets_requirements = False
        var name = self._definition_name(node, "expected a Name")
        if self._at(TokenKind.AT):
            meets_requirements = True
            self._directives(node, True)
        if self._at(TokenKind.L_CURLY):
            meets_requirements = True
            if kind == Kind.ENUM_TYPE_EXTENSION:
                self._enum_values_definition(node)
            else:
                self._input_fields_definition(node)
        if not meets_requirements:
            self._err(message)
        _ = self._finish(node)
        return node if name != NO_NODE else NO_NODE

    def _extensions(mut self) -> Int:
        """Parse a type system extension: upstream `extensions`."""
        var word = self._peek_n(2)
        if word >= 0:
            var data = self._data(word)
            if data == "schema":
                return self._schema_extension()
            if data == "scalar":
                return self._scalar_type_extension()
            if data == "type":
                return self._object_like_extension(
                    Kind.OBJECT_TYPE_EXTENSION,
                    (
                        "expected an Implements Interface, Directives or a"
                        " Fields Definition"
                    ),
                )
            if data == "interface":
                return self._object_like_extension(
                    Kind.INTERFACE_TYPE_EXTENSION,
                    (
                        "exptected an Implements Interfaces, Directives, or a"
                        " Fields Definition"
                    ),
                )
            if data == "union":
                return self._union_type_extension()
            if data == "enum":
                return self._simple_extension(
                    Kind.ENUM_TYPE_EXTENSION,
                    "expected Directive or Enum Values Definition",
                )
            if data == "input":
                return self._simple_extension(
                    Kind.INPUT_OBJECT_TYPE_EXTENSION,
                    "expected Directives or an Input Fields Definition",
                )
        self._err_and_pop(
            "Invalid Type System Extension. This extension cannot be applied."
        )
        return NO_NODE


def parse_recovering(
    text: StringSlice,
    name: String = "GraphQL request",
    recursion_limit: Int = DEFAULT_RECURSION_LIMIT,
    token_limit: Int = Int.MAX,
) -> SyntaxTree:
    """Parse a document as apollo-parser does, and go on after errors.

    Args:
        text: The GraphQL text.
        name: The source name, for locations.
        recursion_limit: The upstream `recursion_limit`.
        token_limit: The upstream `token_limit`; no limit by default.

    Returns:
        The document, the errors, and the limits reached.
    """
    var parser = Parser(text, name, recursion_limit, token_limit)
    return parser.parse()
