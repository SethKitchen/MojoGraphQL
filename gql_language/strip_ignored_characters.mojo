# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Remove the characters that do not change the meaning of a document.

Port of graphql-js 16.14.2 `utilities/stripIgnoredCharacters.ts`. The
output is the same text, byte for byte: white space, line terminators,
commas, comments and byte order marks go. A space stays between two tokens
that are not punctuators, and before a `...` that follows one. A block
string is printed again on one line where it can be, with
`printBlockString(value, { minimize: true })`.

**One buffer.** The tokens are copied into one byte list, with no string
for each token. A block string's value is decoded into one scratch list,
which every block string uses again.

**Differences from upstream.** None in the output. The text of a `Source`
is copied as the `Source` is made, as for every `Lexer`.
"""

from gql_language.block_string import append_block_string
from gql_language.error import GraphQLError
from gql_language.lexer import Lexer, block_string_value_into
from gql_language.scan import string_from_utf8
from gql_language.source import Source
from gql_language.token_kind import TokenKind


def strip_ignored_characters(var source: Source) raises GraphQLError -> String:
    """Return a source without its ignored characters, as graphql-js
    `stripIgnoredCharacters`.

    The source does not have to be a valid document: only its tokens are
    read.

    Args:
        source: The GraphQL source.

    Returns:
        The tokens, with a space only where two tokens need one.

    Raises:
        GraphQLError: If the source has a lexical error, such as
            `Syntax Error: Unterminated string.`
    """
    var out = List[UInt8](capacity=source.length)
    var scratch = List[UInt8]()
    var lexer = Lexer(source^)
    var was_non_punctuator = False
    var token = lexer.advance()
    while token.kind != TokenKind.EOF:
        var is_non_punctuator = not token.kind.is_punctuator()
        # Two names or numbers need a space between them, and so does a
        # number before `...`: `1...` is not a valid Float.
        if was_non_punctuator and (
            is_non_punctuator or token.kind == TokenKind.SPREAD
        ):
            out.append(0x20)
        var data = Span(lexer.source.bytes)
        if token.kind == TokenKind.BLOCK_STRING:
            scratch.clear()
            block_string_value_into(data, token.start, token.end, scratch)
            append_block_string(out, Span(scratch), True)
        else:
            out.extend(data[token.start : token.end])
        was_non_punctuator = is_non_punctuator
        token = lexer.advance()
    return string_from_utf8(out)


def strip_ignored_characters(text: StringSlice) raises GraphQLError -> String:
    """Return GraphQL text without its ignored characters.

    Args:
        text: The GraphQL text, read as a source named `GraphQL request`.

    Returns:
        The tokens, with a space only where two tokens need one.

    Raises:
        GraphQLError: If the text has a lexical error.
    """
    return strip_ignored_characters(Source(text))
