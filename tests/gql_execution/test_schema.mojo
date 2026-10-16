# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for execution with a complex schema, ported from graphql-js
16.14.2 `src/execution/__tests__/schema-test.ts`.

The schema comes from SDL. The `pic` and `recentArticle` methods of the
author become field resolvers. The case is ported in full.
"""

from std.testing import TestSuite, assert_equal
from _helpers import json_value, run_query
from gql_execution.execute import ExecutionArgs, ResolveInfo
from gql_execution.value import ValueKind, Values
from gql_schema.build import build_schema
from gql_schema.values import js_number_to_string

comptime SDL = """
type Image { url: String width: Int height: Int }
type Author {
  id: String
  name: String
  pic(width: Int, height: Int): Image
  recentArticle: Article
}
type Article {
  id: String!
  isPublished: Boolean
  author: Author
  title: String
  body: String
  keywords: [String]
}
type Query { article(id: ID): Article feed: [Article] }
"""


def _text(values: Values, value: Int) -> String:
    """Return JavaScript `'' + value` for a number or a string."""
    if values.kind(value) == ValueKind.NUMBER:
        return js_number_to_string(values.number(value))
    return String(values.string(value))


def article(mut values: Values, id: Int) raises -> Int:
    var out = values.add_object()
    values.add_member(out, "id", id)
    values.add_member(out, "isPublished", values.add_bool(True))
    var author = json_value(values, '{"id": 123, "name": "John Smith"}')
    values.add_member(out, "author", author)
    values.add_member(
        out, "title", values.add_string("My Article " + _text(values, id))
    )
    values.add_member(out, "body", values.add_string("This is a post"))
    values.add_member(
        out,
        "hidden",
        values.add_string("This data is not exposed in the schema"),
    )
    var keywords = json_value(values, '["foo", "bar", 1, true, null]')
    values.add_member(out, "keywords", keywords)
    return out


def article_by_id(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return article(values, values.copy(values.get(args, "id")))


def feed(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var out = values.add_list()
    var id = 1
    while id <= 10:
        var item = article(values, values.add_number(Float64(id)))
        values.append(out, item)
        id += 1
    return out


def pic(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    var out = values.add_object()
    values.add_member(out, "url", values.add_string("cdn://123"))
    values.add_member(
        out,
        "width",
        values.add_string(_text(values, values.get(args, "width"))),
    )
    values.add_member(
        out,
        "height",
        values.add_string(_text(values, values.get(args, "height"))),
    )
    return out


def recent_article(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return article(values, values.add_number(1))


def test_executes_using_a_schema() raises:
    var schema = build_schema(SDL)
    var args = ExecutionArgs()
    args.resolvers.field("Query", "article", article_by_id)
    args.resolvers.field("Query", "feed", feed)
    args.resolvers.field("Author", "pic", pic)
    args.resolvers.field("Author", "recentArticle", recent_article)
    var query = """
      {
        feed {
          id,
          title
        },
        article(id: "1") {
          ...articleFields,
          author {
            id,
            name,
            pic(width: 640, height: 480) {
              url,
              width,
              height
            },
            recentArticle {
              ...articleFields,
              keywords
            }
          }
        }
      }

      fragment articleFields on Article {
        id,
        isPublished,
        title,
        body,
        hidden,
        notDefined
      }
    """
    var feed_items = String("")
    var id = 1
    while id <= 10:
        if id > 1:
            feed_items += ","
        feed_items += (
            '{"id":"'
            + String(id)
            + '","title":"My Article '
            + String(id)
            + '"}'
        )
        id += 1
    assert_equal(
        run_query(schema, query, args),
        '{"data":{"feed":['
        + feed_items
        + '],"article":{"id":"1","isPublished":true,"title":"My Article 1",'
        '"body":"This is a post","author":{"id":"123","name":"John Smith",'
        '"pic":{"url":"cdn://123","width":640,"height":480},"recentArticle":'
        '{"id":"1","isPublished":true,"title":"My Article 1","body":"This is'
        ' a post","keywords":["foo","bar","1","true",null]}}}}}',
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
