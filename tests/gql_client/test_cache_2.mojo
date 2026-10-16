# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Apollo Client 4.3.3 `src/cache/inmemory/__tests__/cache.ts`,
the `InMemoryCache#modify` part.

A modifier is a module-level function. Upstream modifiers that keep state
in a closure, such as a counter, keep it in the store here: the count is
read back from `extract`.

Upstream cases that are not ported:

- "should not revisit deleted fields": it modifies an optimistic layer,
  and optimistic layers are not ported.
- "should broadcast watches for queries with changed fields": there are no
  watches.
- "warns if `modify` returns a mixed array of objects and references",
  "warns if `modify` returns a Reference that is not part of the store as
  part of an array", "warns if `modify` returns a Reference that is not
  part of the store": the cache prints no warnings.
- "should modify ROOT_QUERY only when options.id absent" is ported for the
  ids `""` and `"bogus:id"`. The ids `undefined`, `false` and `null` of
  upstream are not Mojo strings.
- "should allow invalidation using details.INVALIDATE" checks the results
  with `toEqual` only: the `not.toBe` and `toBe` checks of result identity
  need the result cache.
"""

from std.collections import Dict

from gql_client.cache import (
    DELETE,
    INVALIDATE,
    InMemoryCache,
    InMemoryCacheConfig,
    Modifier,
    ModifierDetails,
    FieldFunctionOptions,
)
from gql_client.policies import (
    FieldPolicy,
    KeyArgs,
    KeyFields,
    Merge,
    TypePolicy,
)
from gql_client.values import ValueKind
from gql_json.parser import parse as parse_json
from gql_json.value import JsonDocument, JsonKind
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_true,
)

from _helpers import (
    assert_extract,
    assert_extract_exact,
    assert_json,
    assert_read,
    assert_read_exact,
    gql,
    json,
    text_of,
    write,
)


def _number(mut details: ModifierDetails, value: Int) raises -> Float64:
    """Return the number of a value."""
    return atof(details.cache[].values.text(value))


def _text(mut details: ModifierDetails, value: Int) -> String:
    """Return the text of a string or a number."""
    return String(details.cache[].values.text(value))


def bump_a_drop_b(value: Int, mut details: ModifierDetails) raises -> Int:
    """`a` becomes `value + 1` and `b` becomes `value - 1`."""
    if details.field_name == "a":
        return details.cache[].values.add_float(_number(details, value) + 1)
    if details.field_name == "b":
        return details.cache[].values.add_float(_number(details, value) - 1)
    return value


def test_modify_with_a_single_modifier_function() raises:
    var cache = InMemoryCache()
    var query = gql("query { a b c }")
    _ = write(cache, "query { a b c }", '{"a": 0, "b": 0, "c": 0}')
    assert_read(cache, query, '{"a": 0, "b": 0, "c": 0}')
    _ = cache.modify(
        Dict[String, Modifier](), all=Optional[Modifier](bump_a_drop_b)
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "a": 1, "b": -1, "c": 0}}',
    )
    assert_read(cache, query, '{"a": 1, "b": -1, "c": 0}')


def plus_one(value: Int, mut details: ModifierDetails) raises -> Int:
    """`a(value) { return value + 1 }`."""
    return details.cache[].values.add_float(_number(details, value) + 1)


def minus_one(value: Int, mut details: ModifierDetails) raises -> Int:
    """`b(value) { return value - 1 }`."""
    return details.cache[].values.add_float(_number(details, value) - 1)


def check_typename(value: Int, mut details: ModifierDetails) raises -> Int:
    """The `__typename` modifier: it checks `t` and `readField("c")`."""
    assert_equal(_text(details, value), "Query")
    assert_equal(_text(details, details.read_field("c")), "0")
    return value


def test_modify_with_multiple_modifier_functions() raises:
    var cache = InMemoryCache()
    var query = gql("query { a b c }")
    _ = write(cache, "query { a b c }", '{"a": 0, "b": 0, "c": 0}')
    assert_read(cache, query, '{"a": 0, "b": 0, "c": 0}')
    var fields = Dict[String, Modifier]()
    fields["a"] = plus_one
    fields["b"] = minus_one
    fields["__typename"] = check_typename
    assert_true(cache.modify(fields))
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "a": 1, "b": -1, "c": 0}}',
    )
    assert_read(cache, query, '{"a": 1, "b": -1, "c": 0}')


def invalidate(value: Int, mut details: ModifierDetails) raises -> Int:
    """`(_, { INVALIDATE }) => INVALIDATE`."""
    return INVALIDATE


def _book_and_author_cache() raises -> InMemoryCache:
    """A cache whose books are keyed by `isbn` and authors by `name`."""
    var config = InMemoryCacheConfig()
    var book = TypePolicy()
    book.key_fields = KeyFields.parse('["isbn"]')
    config.type_policies["Book"] = book^
    var author = TypePolicy()
    author.key_fields = KeyFields.parse('["name"]')
    config.type_policies["Author"] = author^
    return InMemoryCache(config)


def test_modify_allows_invalidation() raises:
    var cache = _book_and_author_cache()
    var text = "query { currentlyReading { title isbn author { name } } }"
    var query = gql(text)
    _ = write(
        cache,
        text,
        (
            '{"currentlyReading": {"__typename": "Book", "isbn": "0374110034",'
            ' "title": "Beowulf: A New Translation", "author": {"__typename":'
            ' "Author", "name": "Maria Dahvana Headley"}}}'
        ),
    )
    var initial = String(
        '{"currentlyReading":{"__typename":"Book","title":"Beowulf: A New'
        ' Translation","isbn":"0374110034","author":{"__typename":"Author","name":"Maria'
        ' Dahvana Headley"}}}'
    )
    assert_read_exact(cache, query, initial)
    # The Node.js output of Apollo Client 4.3.3; upstream uses a snapshot.
    assert_extract_exact(
        cache,
        (
            '{"Author:{\\"name\\":\\"Maria Dahvana'
            ' Headley\\"}":{"__typename":"Author","name":"Maria'
            " Dahvana"
            ' Headley"},"Book:{\\"isbn\\":\\"0374110034\\"}":{"__typename":"Book","title":"Beowulf:'
            " A New"
            ' Translation","isbn":"0374110034","author":{"__ref":"Author:{\\"name\\":\\"Maria'
            " Dahvana"
            ' Headley\\"}"}},"ROOT_QUERY":{"__typename":"Query","currentlyReading":{"__ref":"Book:{\\"isbn\\":\\"0374110034\\"}"}}}'
        ),
    )
    var fields = Dict[String, Modifier]()
    fields["name"] = invalidate
    var author = cache.identify(
        json('{"__typename": "Author", "name": "Maria Dahvana Headley"}')
    )
    assert_false(cache.modify(fields, author))
    assert_read_exact(cache, query, initial)
    var book = cache.identify(
        json('{"__typename": "Book", "isbn": "0374110034"}')
    )
    assert_false(
        cache.modify(
            Dict[String, Modifier](), book, Optional[Modifier](invalidate)
        )
    )
    assert_read_exact(cache, query, initial)


def year_plus_one(value: Int, mut details: ModifierDetails) raises -> Int:
    """`yearOfBirth(yob) { return yob + 1 }`."""
    return details.cache[].values.add_float(_number(details, value) + 1)


def delete_year(value: Int, mut details: ModifierDetails) raises -> Int:
    """`yearOfBirth(yob, { DELETE }) { expect(yob).toBe(1984); return
    DELETE }`."""
    assert_equal(_text(details, value), "1984")
    return DELETE


def modify_author(value: Int, mut details: ModifierDetails) raises -> Int:
    """The `author` modifier: it reads fields, then modifies the author."""
    assert_equal(
        _text(details, details.read_field("title")), "Why We're Polarized"
    )
    var name = _text(details, details.read_field_from("name", value))
    assert_equal(name, "Ezra Klein")
    var typename = _text(details, details.read_field_from("__typename", value))
    var object = JsonDocument()
    object.root = object.add_object()
    object.add_member(object.root, "__typename", object.add_string(typename))
    object.add_member(object.root, "name", object.add_string(name))
    var fields = Dict[String, Modifier]()
    fields["yearOfBirth"] = delete_year
    _ = details.cache[].modify(fields, details.cache[].identify(object))
    return value


def delete_all(value: Int, mut details: ModifierDetails) raises -> Int:
    """`(_, { DELETE }) => DELETE`."""
    return DELETE


def test_modify_allows_deletion() raises:
    var cache = _book_and_author_cache()
    _ = write(
        cache,
        "query { currentlyReading { title isbn author { name yearOfBirth } } }",
        (
            '{"currentlyReading": {"__typename": "Book", "isbn": "147670032X",'
            ' "title": "Why We\'re Polarized", "author": {"__typename":'
            ' "Author", "name": "Ezra Klein", "yearOfBirth": 1983}}}'
        ),
    )
    var root = String(
        '"ROOT_QUERY": {"__typename": "Query", "currentlyReading": {"__ref":'
        ' "Book:{\\"isbn\\":\\"147670032X\\"}"}}'
    )
    var book_entity = String(
        '"Book:{\\"isbn\\":\\"147670032X\\"}": {"__typename": "Book", "isbn":'
        ' "147670032X", "author": {"__ref": "Author:{\\"name\\":\\"Ezra'
        ' Klein\\"}"}, "title": "Why We\'re Polarized"}'
    )
    assert_extract(
        cache,
        "{"
        + root
        + ", "
        + book_entity
        + ', "Author:{\\"name\\":\\"Ezra Klein\\"}": {"__typename": "Author",'
        ' "name": "Ezra Klein", "yearOfBirth": 1983}}',
    )
    var author = cache.identify(
        json(
            '{"__typename": "Author", "name": "Ezra Klein", "yearOfBirth":'
            " 1983}"
        )
    )
    assert_equal(author.value(), 'Author:{"name":"Ezra Klein"}')
    var fields = Dict[String, Modifier]()
    fields["yearOfBirth"] = year_plus_one
    _ = cache.modify(fields, author)
    var yob = cache.read_fragment(
        gql("fragment YOB on Author { yearOfBirth }"), author.value()
    )
    assert_json(yob.value(), '{"__typename": "Author", "yearOfBirth": 1984}')
    var book = cache.identify(
        json(
            '{"__typename": "Book", "isbn": "147670032X", "title": "Why We\'re'
            ' Polarized"}'
        )
    )
    fields = Dict[String, Modifier]()
    fields["author"] = modify_author
    _ = cache.modify(fields, book)
    assert_extract(
        cache,
        "{"
        + root
        + ", "
        + book_entity
        + ', "Author:{\\"name\\":\\"Ezra Klein\\"}": {"__typename": "Author",'
        ' "name": "Ezra Klein"}}',
    )
    _ = cache.modify(
        Dict[String, Modifier](), book, Optional[Modifier](delete_all)
    )
    assert_extract(
        cache,
        "{"
        + root
        + ', "Author:{\\"name\\":\\"Ezra Klein\\"}": {"__typename": "Author",'
        ' "name": "Ezra Klein"}}',
    )
    fields = Dict[String, Modifier]()
    fields["__typename"] = delete_all
    fields["name"] = delete_all
    _ = cache.modify(fields, author)
    assert_extract(cache, "{" + root + "}")
    _ = cache.modify(
        Dict[String, Modifier](), all=Optional[Modifier](delete_all)
    )
    assert_extract(cache, "{}")


def merge_pages(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The `comments` merge function: it puts a page at `args.offset`."""
    ref values = options.cache[].values
    var merged = values.array_items(existing)
    var offset = Int(atol(values.text(values.get(options.args, "offset"))))
    var limit = Int(atol(values.text(values.get(options.args, "limit"))))
    var end = offset + min(limit, values.length(incoming))
    var index = offset
    while index < end:
        while len(merged) <= index:
            merged.append(-1)
        var item = values.item(incoming, index - offset)
        merged[index] = options.merge_objects(merged[index], item)
        index += 1
    return options.cache[].values.add_array(merged)


def read_page(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """The `comments` read function: the page at `args.offset`."""
    ref values = options.cache[].values
    if values.length(existing) == 0:
        return -1
    var offset = Int(atol(values.text(values.get(options.args, "offset"))))
    var limit = Int(atol(values.text(values.get(options.args, "limit"))))
    var page = List[Int]()
    var index = offset
    while index < min(offset + limit, values.length(existing)):
        page.append(values.item(existing, index))
        index += 1
    if len(page) == 0:
        return -1
    return options.cache[].values.add_array(page)


def drop_c1(value: Int, mut details: ModifierDetails) raises -> Int:
    """The `comments` modifier: it drops the comment `c1`."""
    var values = List[Int]()
    var count = details.cache[].values.length(value)
    assert_equal(count, 3)
    var index = 0
    while index < count:
        var comment = details.cache[].values.item(value, index)
        var id = details.read_field_from("id", comment)
        if _text(details, id) != "c1":
            values.append(comment)
        index += 1
    assert_equal(len(values), 2)
    return details.cache[].values.add_array(values)


def test_modify_removes_items_from_paginated_lists() raises:
    var config = InMemoryCacheConfig()
    var thread = TypePolicy()
    thread.key_fields = KeyFields.parse('["tid"]')
    var comments = FieldPolicy()
    comments.merge = Merge(merge_pages)
    comments.read = read_page
    thread.fields["comments"] = comments^
    config.type_policies["Thread"] = thread^
    var comment = TypePolicy()
    comment.key_fields = KeyFields.parse('["id"]')
    config.type_policies["Comment"] = comment^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        (
            "query GetThread($offset: Int, $limit: Int) { thread { tid"
            " comments(offset: $offset, limit: $limit) { id text } } }"
        ),
        (
            '{"thread": {"__typename": "Thread", "tid": 123, "comments":'
            ' [{"__typename": "Comment", "id": "c1", "text": "first post"},'
            ' {"__typename": "Comment", "id": "c2", "text": "I have thoughts"},'
            ' {"__typename": "Comment", "id": "c3", "text": "friendly ping"}]}}'
        ),
        '{"offset": 0, "limit": 3}',
    )
    var root = String(
        '"ROOT_QUERY": {"__typename": "Query", "thread": {"__ref":'
        ' "Thread:{\\"tid\\":123}"}}'
    )
    var c2 = String(
        '"Comment:{\\"id\\":\\"c2\\"}": {"__typename": "Comment", "id": "c2",'
        ' "text": "I have thoughts"}'
    )
    var c3 = String(
        '"Comment:{\\"id\\":\\"c3\\"}": {"__typename": "Comment", "id": "c3",'
        ' "text": "friendly ping"}'
    )
    assert_extract(
        cache,
        "{"
        + root
        + ', "Thread:{\\"tid\\":123}": {"__typename": "Thread", "tid": 123,'
        ' "comments": [{"__ref": "Comment:{\\"id\\":\\"c1\\"}"}, {"__ref":'
        ' "Comment:{\\"id\\":\\"c2\\"}"}, {"__ref":'
        ' "Comment:{\\"id\\":\\"c3\\"}"}]}, "Comment:{\\"id\\":\\"c1\\"}":'
        ' {"__typename": "Comment", "id": "c1", "text": "first post"}, '
        + c2
        + ", "
        + c3
        + "}",
    )
    var fields = Dict[String, Modifier]()
    fields["comments"] = drop_c1
    _ = cache.modify(
        fields, cache.identify(json('{"__typename": "Thread", "tid": 123}'))
    )
    var removed = cache.gc()
    assert_equal(len(removed), 1)
    assert_equal(removed[0], 'Comment:{"id":"c1"}')
    assert_extract(
        cache,
        "{"
        + root
        + ', "Thread:{\\"tid\\":123}": {"__typename": "Thread", "tid": 123,'
        ' "comments": [{"__ref": "Comment:{\\"id\\":\\"c2\\"}"}, {"__ref":'
        ' "Comment:{\\"id\\":\\"c3\\"}"}]}, '
        + c2
        + ", "
        + c3
        + "}",
    )


def _check_book(
    book: Int, mut details: ModifierDetails, isbn_to_delete: StringSlice
) raises -> Int:
    """The `book` modifier of "should handle argument-determined field
    identities", with the ISBN that it deletes."""
    assert_equal(details.field_name, "book")
    assert_true(details.is_reference(book))
    var title = details.read_field_from("title", book)
    assert_true(details.cache[].values.kind(title) == ValueKind.STRING)
    assert_equal(
        _text(details, details.read_field_from("__typename", book)), "Book"
    )
    var parts = details.store_field_name.split(":")
    assert_equal(String(parts[0]), "book")
    var key_args = parse_json(
        String(details.store_field_name[byte = parts[0].byte_length() + 1 :])
    )
    assert_equal(key_args.length(key_args.root), 1)
    var isbn = key_args.get(key_args.root, "isbn")
    assert_true(key_args.kind(isbn) == JsonKind.STRING)
    var keyed = key_args.string_value(isbn)
    assert_equal(_text(details, details.read_field_from("isbn", book)), keyed)
    if keyed == isbn_to_delete:
        return DELETE
    return book


def keep_books(book: Int, mut details: ModifierDetails) raises -> Int:
    """`check()`: delete no book."""
    return _check_book(book, details, "")


def delete_0735211280(book: Int, mut details: ModifierDetails) raises -> Int:
    """`check("0735211280")`."""
    return _check_book(book, details, "0735211280")


def delete_147670032x(book: Int, mut details: ModifierDetails) raises -> Int:
    """`check("147670032X")`."""
    return _check_book(book, details, "147670032X")


def delete_1760641790(book: Int, mut details: ModifierDetails) raises -> Int:
    """`check("1760641790")`."""
    return _check_book(book, details, "1760641790")


def _check(mut cache: InMemoryCache, modifier: Modifier) raises -> Int:
    """Run a `book` modifier; return how many books ROOT_QUERY keeps."""
    var fields = Dict[String, Modifier]()
    fields["book"] = modifier
    _ = cache.modify(fields)
    var count = 0
    var extract = parse_json(cache.extract())
    var root = extract.find(extract.root, "ROOT_QUERY")
    var member = extract.first(root)
    while member != -1:
        if extract.key(member).startswith("book:"):
            count += 1
        member = extract.next(member)
    return count


def test_modify_handles_argument_determined_field_identities() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    var book_field = FieldPolicy()
    book_field.key_args = KeyArgs.parse('["isbn"]')
    query_policy.fields["book"] = book_field^
    config.type_policies["Query"] = query_policy^
    var book = TypePolicy()
    book.key_fields = KeyFields.parse('["isbn"]')
    config.type_policies["Book"] = book^
    var cache = InMemoryCache(config)
    var query = "query { book(isbn: $isbn) { isbn title } }"
    var isbns: List[String] = ["147670032X", "1760641790", "0735211280"]
    var titles: List[String] = [
        "Why We're Polarized",
        "How To Do Nothing",
        "Spineless",
    ]
    var index = 0
    while index < 3:
        var data = JsonDocument()
        data.root = data.add_object()
        var entry = data.add_object()
        data.add_member(entry, "__typename", data.add_string("Book"))
        data.add_member(entry, "isbn", data.add_string(isbns[index]))
        data.add_member(entry, "title", data.add_string(titles[index]))
        data.add_member(data.root, "book", entry)
        var variables = JsonDocument()
        variables.root = variables.add_object()
        variables.add_member(
            variables.root, "isbn", variables.add_string(isbns[index])
        )
        _ = cache.write_query(gql(query), data, variables)
        index += 1
    var books = String(
        '"Book:{\\"isbn\\":\\"147670032X\\"}": {"__typename": "Book", "isbn":'
        ' "147670032X", "title": "Why We\'re Polarized"},'
        ' "Book:{\\"isbn\\":\\"1760641790\\"}": {"__typename": "Book", "isbn":'
        ' "1760641790", "title": "How To Do Nothing"},'
        ' "Book:{\\"isbn\\":\\"0735211280\\"}": {"__typename": "Book", "isbn":'
        ' "0735211280", "title": "Spineless"}'
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query",'
        ' "book:{\\"isbn\\":\\"0735211280\\"}": {"__ref":'
        ' "Book:{\\"isbn\\":\\"0735211280\\"}"},'
        ' "book:{\\"isbn\\":\\"147670032X\\"}": {"__ref":'
        ' "Book:{\\"isbn\\":\\"147670032X\\"}"},'
        ' "book:{\\"isbn\\":\\"1760641790\\"}": {"__ref":'
        ' "Book:{\\"isbn\\":\\"1760641790\\"}"}}, '
        + books
        + "}",
    )
    assert_equal(_check(cache, keep_books), 3)
    assert_equal(_check(cache, keep_books), 3)
    assert_equal(_check(cache, delete_0735211280), 2)
    assert_equal(_check(cache, delete_147670032x), 1)
    assert_equal(_check(cache, delete_0735211280), 1)
    assert_equal(_check(cache, delete_147670032x), 1)
    var last_root = String(
        '"ROOT_QUERY": {"__typename": "Query",'
        ' "book:{\\"isbn\\":\\"1760641790\\"}": {"__ref":'
        ' "Book:{\\"isbn\\":\\"1760641790\\"}"}}'
    )
    assert_extract(cache, "{" + last_root + ", " + books + "}")
    var removed = cache.gc()
    sort(removed)
    assert_equal(len(removed), 2)
    assert_equal(removed[0], 'Book:{"isbn":"0735211280"}')
    assert_equal(removed[1], 'Book:{"isbn":"147670032X"}')
    var last_book = String(
        '"Book:{\\"isbn\\":\\"1760641790\\"}": {"__typename": "Book", "isbn":'
        ' "1760641790", "title": "How To Do Nothing"}'
    )
    assert_extract(cache, "{" + last_root + ", " + last_book + "}")
    assert_equal(_check(cache, delete_1760641790), 0)
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query"}, ' + last_book + "}",
    )
    removed = cache.gc()
    assert_equal(len(removed), 1)
    assert_equal(removed[0], 'Book:{"isbn":"1760641790"}')
    assert_extract(cache, '{"ROOT_QUERY": {"__typename": "Query"}}')


def unexpected(value: Int, mut details: ModifierDetails) raises -> Int:
    """`fields(value) { throw new Error(...) }`."""
    raise Error("unexpected value")


def test_modify_changes_root_query_only_without_an_id() raises:
    var cache = InMemoryCache()
    _ = write(cache, "query { field }", '{"field": "oyez"}')
    var snapshot = '{"ROOT_QUERY": {"__typename": "Query", "field": "oyez"}}'
    assert_extract(cache, snapshot)
    var ids: List[String] = ["", "bogus:id"]
    for ref id in ids:
        assert_false(
            cache.modify(
                Dict[String, Modifier](),
                Optional[String](id),
                Optional[Modifier](unexpected),
            )
        )
    assert_extract(cache, snapshot)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
