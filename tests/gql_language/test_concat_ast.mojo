# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_language.concat_ast`, ported from graphql-js 16.14.2
`src/utilities/__tests__/concatAST-test.ts`.

The upstream test is kept. One more test joins no documents and an empty
document.
"""

from _ast_dump import dedent
from gql_language.ast import Document
from gql_language.concat_ast import concat_ast
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_language.source import Source
from std.testing import TestSuite, assert_equal


def test_concatenates_two_asts() raises:
    var source_a = Source(
        """
      { a, b, ...Frag }
    """
    )
    var source_b = Source(
        """
      fragment Frag on T {
        c
      }
    """
    )
    var documents = List[Document]()
    documents.append(parse(source_a^))
    documents.append(parse(source_b^))
    var joined = concat_ast(documents)
    assert_equal(
        print_ast(joined),
        dedent(
            """
            {
              a
              b
              ...Frag
            }

            fragment Frag on T {
              c
            }
            """
        ),
    )


def test_concatenates_nothing() raises:
    assert_equal(print_ast(concat_ast(List[Document]())), "")
    var documents = List[Document]()
    documents.append(Document())
    documents.append(parse("{ a }"))
    assert_equal(print_ast(concat_ast(documents)), "{\n  a\n}")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
