# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_language.separate_operations`, ported from graphql-js
16.14.2 `src/utilities/__tests__/separateOperations-test.ts`.

graphql-js compares an object of printed documents; these tests compare
the list of names and printed documents, in key order. Two more tests
cover a document with no operation, and two operations with one name.
"""

from _ast_dump import dedent
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_language.separate_operations import separate_operations
from std.testing import TestSuite, assert_equal


def separated(text: String) raises -> List[String]:
    """Return each operation name and its printed document, in order."""
    var out = List[String]()
    for entry in separate_operations(parse(text)):
        out.append(entry.name)
        out.append(print_ast(entry.document))
    return out^


def test_separates_keeping_document_order() raises:
    var result = separated(
        """
      {
        ...Y
        ...X
      }

      query One {
        foo
        bar
        ...A
        ...X
      }

      fragment A on T {
        field
        ...B
      }

      fragment X on T {
        fieldX
      }

      query Two {
        ...A
        ...Y
        baz
      }

      fragment Y on T {
        fieldY
      }

      fragment B on T {
        something
      }
    """
    )
    assert_equal(len(result), 6)
    assert_equal(result[0], "")
    assert_equal(
        result[1],
        dedent(
            """
            {
              ...Y
              ...X
            }

            fragment X on T {
              fieldX
            }

            fragment Y on T {
              fieldY
            }
            """
        ),
    )
    assert_equal(result[2], "One")
    assert_equal(
        result[3],
        dedent(
            """
            query One {
              foo
              bar
              ...A
              ...X
            }

            fragment A on T {
              field
              ...B
            }

            fragment X on T {
              fieldX
            }

            fragment B on T {
              something
            }
            """
        ),
    )
    assert_equal(result[4], "Two")
    assert_equal(
        result[5],
        dedent(
            """
            fragment A on T {
              field
              ...B
            }

            query Two {
              ...A
              ...Y
              baz
            }

            fragment Y on T {
              fieldY
            }

            fragment B on T {
              something
            }
            """
        ),
    )


def test_survives_circular_dependencies() raises:
    var result = separated(
        """
      query One {
        ...A
      }

      fragment A on T {
        ...B
      }

      fragment B on T {
        ...A
      }

      query Two {
        ...B
      }
    """
    )
    assert_equal(len(result), 4)
    assert_equal(result[0], "One")
    assert_equal(
        result[1],
        dedent(
            """
            query One {
              ...A
            }

            fragment A on T {
              ...B
            }

            fragment B on T {
              ...A
            }
            """
        ),
    )
    assert_equal(result[2], "Two")
    assert_equal(
        result[3],
        dedent(
            """
            fragment A on T {
              ...B
            }

            fragment B on T {
              ...A
            }

            query Two {
              ...B
            }
            """
        ),
    )


def test_distinguishes_query_and_fragment_names() raises:
    var result = separated(
        """
      {
        ...NameClash
      }

      fragment NameClash on T {
        oneField
      }

      query NameClash {
        ...ShouldBeSkippedInFirstQuery
      }

      fragment ShouldBeSkippedInFirstQuery on T {
        twoField
      }
    """
    )
    assert_equal(len(result), 4)
    assert_equal(result[0], "")
    assert_equal(
        result[1],
        dedent(
            """
            {
              ...NameClash
            }

            fragment NameClash on T {
              oneField
            }
            """
        ),
    )
    assert_equal(result[2], "NameClash")
    assert_equal(
        result[3],
        dedent(
            """
            query NameClash {
              ...ShouldBeSkippedInFirstQuery
            }

            fragment ShouldBeSkippedInFirstQuery on T {
              twoField
            }
            """
        ),
    )


def test_ignores_type_definitions() raises:
    var result = separated(
        """
      query Foo {
        ...Bar
      }

      fragment Bar on T {
        baz
      }

      scalar Foo
      type Bar
    """
    )
    assert_equal(len(result), 2)
    assert_equal(result[0], "Foo")
    assert_equal(
        result[1],
        dedent(
            """
            query Foo {
              ...Bar
            }

            fragment Bar on T {
              baz
            }
            """
        ),
    )


def test_handles_unknown_fragments() raises:
    var result = separated(
        """
      {
        ...Unknown
        ...Known
      }

      fragment Known on T {
        someField
      }
    """
    )
    assert_equal(len(result), 2)
    assert_equal(result[0], "")
    assert_equal(
        result[1],
        dedent(
            """
            {
              ...Unknown
              ...Known
            }

            fragment Known on T {
              someField
            }
            """
        ),
    )


def test_document_without_operations() raises:
    assert_equal(len(separated("fragment F on T { a }")), 0)


def test_later_operation_with_same_name_replaces_earlier() raises:
    var result = separated(
        """
      query A { a }
      { b }
      query A { c }
    """
    )
    assert_equal(len(result), 4)
    assert_equal(result[0], "A")
    assert_equal(result[1], "query A {\n  c\n}")
    assert_equal(result[2], "")
    assert_equal(result[3], "{\n  b\n}")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
