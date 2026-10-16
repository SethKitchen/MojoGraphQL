# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_language.get_operation_ast`, ported from graphql-js
16.14.2 `src/utilities/__tests__/getOperationAST-test.ts`.

A node index takes the place of the operation object, and `NO_NODE` the
place of `null`. One more test checks that an empty name does not select
an anonymous operation, as in graphql-js.
"""

from gql_language.ast import NO_NODE
from gql_language.get_operation_ast import get_operation_ast
from gql_language.parser import parse
from std.testing import TestSuite, assert_equal


def test_gets_operation_from_simple_document() raises:
    var document = parse("{ field }")
    assert_equal(get_operation_ast(document), document.definitions()[0])


def test_gets_named_mutation() raises:
    var document = parse("mutation Test { field }")
    assert_equal(get_operation_ast(document), document.definitions()[0])


def test_gets_named_subscription() raises:
    var document = parse("subscription Test { field }")
    assert_equal(get_operation_ast(document), document.definitions()[0])


def test_does_not_get_missing_operation() raises:
    var document = parse("type Foo { field: String }")
    assert_equal(get_operation_ast(document), NO_NODE)


def test_does_not_get_ambiguous_unnamed_operation() raises:
    var document = parse(
        """
      { field }
      mutation Test { field }
      subscription TestSub { field }
    """
    )
    assert_equal(get_operation_ast(document), NO_NODE)


def test_does_not_get_ambiguous_named_operation() raises:
    var document = parse(
        """
      query TestQ { field }
      mutation TestM { field }
      subscription TestS { field }
    """
    )
    assert_equal(get_operation_ast(document), NO_NODE)


def test_does_not_get_misnamed_operation() raises:
    var document = parse(
        """
      { field }

      query TestQ { field }
      mutation TestM { field }
      subscription TestS { field }
    """
    )
    assert_equal(get_operation_ast(document, String("Unknown")), NO_NODE)


def test_gets_named_operation() raises:
    var document = parse(
        """
      query TestQ { field }
      mutation TestM { field }
      subscription TestS { field }
    """
    )
    var definitions = document.definitions()
    assert_equal(get_operation_ast(document, String("TestQ")), definitions[0])
    assert_equal(get_operation_ast(document, String("TestM")), definitions[1])
    assert_equal(get_operation_ast(document, String("TestS")), definitions[2])


def test_empty_name_does_not_select_anonymous_operation() raises:
    var document = parse("{ field } fragment F on T { a }")
    assert_equal(get_operation_ast(document, String("")), NO_NODE)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
