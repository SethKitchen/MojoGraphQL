# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Apollo Client 4.3.3 `src/cache/inmemory/__tests__/entityStore.ts`.

The exact texts are the Node.js output of Apollo Client 4.3.3. A case
that upstream runs with an optimistic layer in the middle is ported
without the layer, as marked below; its expectations are the Node.js
output of the same steps without the layer.

Upstream cases that are not ported:

- "should support result caching if so configured", "should not
  over-invalidate fields with keyArgs": they test the result cache and its
  dependencies, which this port does not have.
- "should respect optimistic updates, when active", "gracefully handles
  eviction amid optimistic updates": optimistic layers
  (`recordOptimisticTransaction`, `removeOptimistic`) are not ported.
  "should respect retain/release methods" and "allows cache eviction" are
  ported without their optimistic steps.
- "cache.gc is not confused by StoreObjects with stray __ref fields" and
  "Refuses to merge { __ref } objects as StoreObjects": they write into
  the private `store.data` and call `store.merge` with a `Reference`, an
  API that the Mojo store does not have.
- "supports cache.identify(object)": the console warning check, since the
  cache prints no warnings; the rest is ported. The `toBe` checks of
  result identity are left out.
"""

from std.collections import Dict

from gql_client.cache import (
    FieldFunctionOptions,
    InMemoryCache,
    InMemoryCacheConfig,
    Modifier,
    ModifierDetails,
)
from gql_client.policies import (
    FieldPolicy,
    KeyArgs,
    KeyFields,
    Merge,
    TypePolicy,
)
from gql_client.values import FALSE_VALUE, NO_VALUE, TRUE_VALUE, ValueKind
from gql_json.value import JsonDocument
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
    gql,
    json,
    text_of,
    write,
)
from _store_helpers import (
    book_author_id,
    diff_text,
    gc_text,
    sorted_ids_text,
)


def _book_author_cache() raises -> InMemoryCache:
    """`newBookAuthorCache()` of upstream."""
    var config = InMemoryCacheConfig()
    config.data_id_from_object = book_author_id
    return InMemoryCache(config)


comptime BOOK_QUERY = "query { book { title author { name } } }"
"""The query of `newBookAuthorCache()`."""


def test_respects_retain_and_release_without_the_optimistic_layer() raises:
    var cache = _book_author_cache()
    _ = write(
        cache,
        BOOK_QUERY,
        (
            '{"book": {"__typename": "Book", "isbn": "0735211280", "title":'
            ' "Spineless", "subtitle": "The Science of Jellyfish and the Art of'
            ' Growing a Backbone", "author": {"__typename": "Author", "name":'
            ' "Juli Berwald"}}}'
        ),
    )
    assert_extract_exact(
        cache,
        (
            '{"Author:Juli Berwald":{"__typename":"Author","name":"Juli'
            ' Berwald"},"Book:0735211280":{"__typename":"Book","title":"Spineless","author":{"__ref":"Author:Juli'
            ' Berwald"}},"ROOT_QUERY":{"__typename":"Query","book":{"__ref":"Book:0735211280"}}}'
        ),
    )
    _ = write(
        cache,
        BOOK_QUERY,
        (
            '{"book": {"__typename": "Book", "isbn": "1603589082", "title":'
            ' "Eager", "subtitle": "The Surprising, Secret Life of Beavers and'
            ' Why They Matter", "author": {"__typename": "Author", "name": "Ben'
            ' Goldfarb"}}}'
        ),
    )
    var both = (
        '{"Author:Juli Berwald":{"__typename":"Author","name":"Juli'
        ' Berwald"},"Book:0735211280":{"__typename":"Book","title":"Spineless","author":{"__ref":"Author:Juli'
        ' Berwald"}},"ROOT_QUERY":{"__typename":"Query","book":{"__ref":"Book:1603589082"}},"Author:Ben'
        ' Goldfarb":{"__typename":"Author","name":"Ben'
        ' Goldfarb"},"Book:1603589082":{"__typename":"Book","title":"Eager","author":{"__ref":"Author:Ben'
        ' Goldfarb"}}'
    )
    assert_extract_exact(cache, both + "}")
    assert_equal(cache.retain("Book:0735211280"), 1)
    assert_equal(gc_text(cache), "[]")
    assert_equal(cache.retain("Author:Juli Berwald"), 1)
    assert_equal(cache.release("Book:0735211280"), 0)
    assert_extract_exact(
        cache, both + ',"__META":{"extraRootIds":["Author:Juli Berwald"]}}'
    )
    assert_equal(gc_text(cache), '["Book:0735211280"]')
    assert_equal(cache.release("Author:Juli Berwald"), 0)
    assert_equal(gc_text(cache), '["Author:Juli Berwald"]')
    assert_equal(gc_text(cache), "[]")


def test_allows_cache_eviction_without_the_optimistic_layer() raises:
    var cache = _book_author_cache()
    var book = (
        '{"__typename": "Book", "isbn": "031648637X", "title": "The'
        ' Cuckoo\'s Calling", "author": {"__typename": "Author", "name":'
        ' "Robert Galbraith"}}'
    )
    var id = cache.identify(json(book)).value()
    assert_equal(id, "Book:031648637X")
    _ = write(cache, BOOK_QUERY, '{"book": ' + book + "}")
    assert_false(cache.evict(String("Author:J.K. Rowling")))
    var fragment = gql("fragment BookAuthor on Book { author { name } }")
    var result = cache.read_fragment(fragment, id)
    assert_equal(
        text_of(result.value()),
        (
            '{"__typename":"Book","author":{"__typename":"Author","name":"Robert'
            ' Galbraith"}}'
        ),
    )
    assert_equal(cache.retain("Author:Robert Galbraith"), 1)
    assert_equal(gc_text(cache), "[]")
    assert_true(cache.evict(String("Author:Robert Galbraith")))
    assert_equal(gc_text(cache), "[]")
    assert_extract_exact(
        cache,
        (
            '{"Book:031648637X":{"__typename":"Book","title":"The Cuckoo\'s'
            ' Calling","author":{"__ref":"Author:Robert'
            ' Galbraith"}},"ROOT_QUERY":{"__typename":"Query","book":{"__ref":"Book:031648637X"}},"__META":{"extraRootIds":["Author:Robert'
            ' Galbraith"]}}'
        ),
    )
    _ = cache.write_fragment(
        fragment,
        json(
            '{"__typename": "Book", "author": {"__typename": "Author", "name":'
            ' "J.K. Rowling"}}'
        ),
        id,
    )
    assert_extract_exact(
        cache,
        (
            '{"Book:031648637X":{"__typename":"Book","title":"The Cuckoo\'s'
            ' Calling","author":{"__ref":"Author:J.K.'
            ' Rowling"}},"ROOT_QUERY":{"__typename":"Query","book":{"__ref":"Book:031648637X"}},"Author:J.K.'
            ' Rowling":{"__typename":"Author","name":"J.K.'
            ' Rowling"},"__META":{"extraRootIds":["Author:Robert'
            ' Galbraith","Book:031648637X"]}}'
        ),
    )
    assert_equal(cache.retain("Author:Robert Galbraith"), 2)
    assert_equal(gc_text(cache), "[]")
    assert_equal(cache.release("Author:Robert Galbraith"), 1)
    assert_equal(cache.release("Author:Robert Galbraith"), 0)
    assert_equal(gc_text(cache), "[]")
    # Upstream also passes `undefined`, `null`, `false` and `0`; an
    # `Optional[String]` id can only be the empty string.
    assert_false(cache.evict(String("")))
    assert_true(cache.evict())
    assert_extract_exact(
        cache,
        (
            '{"Book:031648637X":{"__typename":"Book","title":"The Cuckoo\'s'
            ' Calling","author":{"__ref":"Author:J.K. Rowling"}},"Author:J.K.'
            ' Rowling":{"__typename":"Author","name":"J.K.'
            ' Rowling"},"__META":{"extraRootIds":["Book:031648637X"]}}'
        ),
    )
    assert_equal(cache.retain(id), 2)
    assert_equal(cache.release(id), 1)
    assert_equal(cache.release(id), 0)
    assert_equal(
        sorted_ids_text(cache.gc()), '["Author:J.K. Rowling","Book:031648637X"]'
    )


def test_ignores_the_retainment_count_of_root_query() raises:
    var cache = _book_author_cache()
    _ = write(
        cache,
        BOOK_QUERY,
        (
            '{"book": {"__typename": "Book", "isbn": "1982156945", "title":'
            ' "Solutions and Other Problems", "author": {"__typename":'
            ' "Author", "name": "Allie Brosh"}}}'
        ),
    )
    var allie = cache.identify(
        json('{"__typename": "Author", "name": "Allie Brosh"}')
    ).value()
    assert_equal(allie, "Author:Allie Brosh")
    assert_equal(cache.retain(allie), 1)
    var snapshot = cache.extract()
    assert_equal(
        snapshot,
        (
            '{"Author:Allie Brosh":{"__typename":"Author","name":"Allie'
            ' Brosh"},"Book:1982156945":{"__typename":"Book","title":"Solutions'
            ' and Other Problems","author":{"__ref":"Author:Allie'
            ' Brosh"}},"ROOT_QUERY":{"__typename":"Query","book":{"__ref":"Book:1982156945"}},"__META":{"extraRootIds":["Author:Allie'
            ' Brosh"]}}'
        ),
    )
    assert_equal(gc_text(cache), "[]")
    var cache2 = _book_author_cache()
    cache2.restore_text(snapshot)
    assert_extract_exact(cache2, snapshot)
    assert_equal(gc_text(cache2), "[]")
    assert_true(cache2.evict(String("ROOT_QUERY")))
    assert_equal(sorted_ids_text(cache2.gc()), '["Book:1982156945"]')
    assert_extract_exact(
        cache2,
        (
            '{"Author:Allie Brosh":{"__typename":"Author","name":"Allie'
            ' Brosh"},"__META":{"extraRootIds":["Author:Allie Brosh"]}}'
        ),
    )
    assert_equal(cache2.release(allie), 0)
    assert_equal(sorted_ids_text(cache2.gc()), '["Author:Allie Brosh"]')
    assert_extract_exact(cache2, "{}")


def _evicting_cache() raises -> InMemoryCache:
    """The cache of "allows evicting specific fields"."""
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    var author_of_book = FieldPolicy()
    author_of_book.key_args = KeyArgs.parse('["isbn"]')
    query_policy.fields["authorOfBook"] = author_of_book^
    config.type_policies["Query"] = query_policy^
    var author = TypePolicy()
    author.key_fields = KeyFields.parse('["name"]')
    config.type_policies["Author"] = author^
    var publisher = TypePolicy()
    publisher.key_fields = KeyFields.parse('["name"]')
    config.type_policies["Publisher"] = publisher^
    return InMemoryCache(config)


def test_allows_evicting_specific_fields() raises:
    var cache = _evicting_cache()
    var query = (
        "query { authorOfBook(isbn: $isbn) { name hobby }"
        " publisherOfBook(isbn: $isbn) { name yearOfFounding } }"
    )
    var ted = (
        '{"__typename": "Author", "name": "Ted Chiang", "hobby": "video games"}'
    )
    var knopf = (
        '{"__typename": "Publisher", "name": "Alfred A. Knopf",'
        ' "yearOfFounding": 1915}'
    )
    _ = write(
        cache,
        query,
        '{"authorOfBook": ' + ted + ', "publisherOfBook": ' + knopf + "}",
        '{"isbn": "1529014514"}',
    )
    var ted_root = (
        '"authorOfBook:{\\"isbn\\":\\"1529014514\\"}": {"__ref":'
        ' "Author:{\\"name\\":\\"Ted Chiang\\"}"},'
        ' "publisherOfBook({\\"isbn\\":\\"1529014514\\"})": {"__ref":'
        ' "Publisher:{\\"name\\":\\"Alfred A. Knopf\\"}"}'
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", '
        + ted_root
        + '}, "Author:{\\"name\\":\\"Ted Chiang\\"}": '
        + ted
        + ', "Publisher:{\\"name\\":\\"Alfred A. Knopf\\"}": '
        + knopf
        + "}",
    )
    var jenny = (
        '{"__typename": "Author", "name": "Jenny Odell", "hobby": "birding"}'
    )
    var melville = (
        '{"__typename": "Publisher", "name": "Melville House",'
        ' "yearOfFounding": 2001}'
    )
    _ = write(
        cache,
        query,
        '{"authorOfBook": ' + jenny + ', "publisherOfBook": ' + melville + "}",
        '{"isbn": "1760641790"}',
    )
    var jenny_root = (
        '"authorOfBook:{\\"isbn\\":\\"1760641790\\"}": {"__ref":'
        ' "Author:{\\"name\\":\\"Jenny Odell\\"}"},'
        ' "publisherOfBook({\\"isbn\\":\\"1760641790\\"})": {"__ref":'
        ' "Publisher:{\\"name\\":\\"Melville House\\"}"}'
    )
    var ted_entity = '"Author:{\\"name\\":\\"Ted Chiang\\"}": ' + ted
    var jenny_entity = '"Author:{\\"name\\":\\"Jenny Odell\\"}": ' + jenny
    var knopf_key = '"Publisher:{\\"name\\":\\"Alfred A. Knopf\\"}": '
    var melville_entity = (
        '"Publisher:{\\"name\\":\\"Melville House\\"}": ' + melville
    )
    var root = (
        '"ROOT_QUERY": {"__typename": "Query", '
        + ted_root
        + ", "
        + jenny_root
        + "}"
    )
    assert_extract(
        cache,
        "{"
        + root
        + ", "
        + ted_entity
        + ", "
        + knopf_key
        + knopf
        + ", "
        + jenny_entity
        + ", "
        + melville_entity
        + "}",
    )
    assert_read(
        cache,
        gql(query),
        '{"authorOfBook": ' + ted + ', "publisherOfBook": ' + knopf + "}",
        '{"isbn": "1529014514"}',
    )
    assert_read(
        cache,
        gql(query),
        '{"authorOfBook": ' + jenny + ', "publisherOfBook": ' + melville + "}",
        '{"isbn": "1760641790"}',
    )
    _ = cache.evict(
        cache.identify(
            json('{"__typename": "Publisher", "name": "Alfred A. Knopf"}')
        ),
        "yearOfFounding",
    )
    var knopf_short = (
        knopf_key + '{"__typename": "Publisher", "name": "Alfred A. Knopf"}'
    )
    assert_extract(
        cache,
        "{"
        + root
        + ", "
        + ted_entity
        + ", "
        + knopf_short
        + ", "
        + jenny_entity
        + ", "
        + melville_entity
        + "}",
    )
    assert_equal(gc_text(cache), "[]")
    _ = cache.evict(
        cache.identify(
            json('{"__typename": "Publisher", "name": "Melville House"}')
        )
    )
    assert_extract(
        cache,
        "{"
        + root
        + ", "
        + ted_entity
        + ", "
        + knopf_short
        + ", "
        + jenny_entity
        + "}",
    )
    _ = cache.evict(String("ROOT_QUERY"), "publisherOfBook")
    var root_without = (
        '"ROOT_QUERY": {"__typename": "Query",'
        ' "authorOfBook:{\\"isbn\\":\\"1529014514\\"}": {"__ref":'
        ' "Author:{\\"name\\":\\"Ted Chiang\\"}"},'
        ' "authorOfBook:{\\"isbn\\":\\"1760641790\\"}": {"__ref":'
        ' "Author:{\\"name\\":\\"Jenny Odell\\"}"}}'
    )
    assert_extract(
        cache,
        "{"
        + root_without
        + ", "
        + ted_entity
        + ", "
        + knopf_short
        + ", "
        + jenny_entity
        + "}",
    )
    assert_equal(
        gc_text(cache), '["Publisher:{\\"name\\":\\"Alfred A. Knopf\\"}"]'
    )
    assert_extract(
        cache,
        "{" + root_without + ", " + ted_entity + ", " + jenny_entity + "}",
    )
    var partial = cache.diff(gql(query), json('{"isbn": "1529014514"}'))
    assert_false(partial.complete)
    assert_json(partial.result.value(), '{"authorOfBook": ' + ted + "}")
    partial = cache.diff(gql(query), json('{"isbn": "1760641790"}'))
    assert_false(partial.complete)
    assert_json(partial.result.value(), '{"authorOfBook": ' + jenny + "}")
    _ = cache.evict(
        cache.identify(json('{"__typename": "Author", "name": "Ted Chiang"}')),
        "hobby",
    )
    var diff = cache.diff(gql(query), json('{"isbn": "1529014514"}'))
    assert_false(diff.complete)
    assert_json(
        diff.result.value(),
        '{"authorOfBook": {"__typename": "Author", "name": "Ted Chiang"}}',
    )
    var hobby = String(
        'Can\'t find field \'hobby\' on Author:{"name":"Ted Chiang"} object'
    )
    assert_equal(diff.missing.value().message, hobby)
    assert_json(
        diff.missing.value().missing,
        (
            "{\"publisherOfBook\": \"Can't find field 'publisherOfBook' on"
            ' ROOT_QUERY object", "authorOfBook": {"hobby": "Can\'t find'
            ' field \'hobby\' on Author:{\\"name\\":\\"Ted Chiang\\"}'
            ' object"}}'
        ),
    )
    _ = cache.evict(String("ROOT_QUERY"), "authorOfBook")
    assert_equal(
        sorted_ids_text(cache.gc()),
        (
            '["Author:{\\"name\\":\\"Jenny'
            ' Odell\\"}","Author:{\\"name\\":\\"Ted Chiang\\"}"]'
        ),
    )
    assert_extract(cache, '{"ROOT_QUERY": {"__typename": "Query"}}')


def _three_authors(mut cache: InMemoryCache) raises:
    """Write the three authors of the eviction-with-arguments cases."""
    var query = "query { authorOfBook(isbn: $isbn) { name hobby } }"
    _ = write(
        cache,
        query,
        (
            '{"authorOfBook": {"__typename": "Author", "name": "Ted Chiang",'
            ' "hobby": "video games"}}'
        ),
        '{"isbn": "1"}',
    )
    _ = write(
        cache,
        query,
        (
            '{"authorOfBook": {"__typename": "Author", "name": "Isaac Asimov",'
            ' "hobby": "chemistry"}}'
        ),
        '{"isbn": "2"}',
    )
    _ = write(
        cache,
        query,
        (
            '{"authorOfBook": {"__typename": "Author", "name": "James S.A.'
            ' Corey", "hobby": "tabletop games"}}'
        ),
        "{}",
    )


comptime ASIMOV = (
    '"authorOfBook({\\"isbn\\":\\"2\\"})": {"__typename": "Author", "name":'
    ' "Isaac Asimov", "hobby": "chemistry"}'
)
"""The stored Isaac Asimov field."""
comptime COREY = (
    '"authorOfBook": {"__typename": "Author", "name": "James S.A. Corey",'
    ' "hobby": "tabletop games"}'
)
"""The stored James S.A. Corey field."""


def _check_eviction_with_arguments(
    mut cache: InMemoryCache, id: Optional[String]
) raises:
    """The steps of the eviction-with-arguments cases."""
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query",'
        ' "authorOfBook({\\"isbn\\":\\"1\\"})": {"__typename": "Author",'
        ' "name": "Ted Chiang", "hobby": "video games"}, '
        + ASIMOV
        + ", "
        + COREY
        + "}}",
    )
    _ = cache.evict(id, "authorOfBook", json('{"isbn": "1"}'))
    var two = (
        '{"ROOT_QUERY": {"__typename": "Query", ' + ASIMOV + ", " + COREY + "}}"
    )
    assert_extract(cache, two)
    _ = cache.evict(id, "authorOfBook", json('{"isbn": "3"}'))
    assert_extract(cache, two)
    _ = cache.evict(id, "authorOfBook", json("{}"))
    assert_extract(
        cache, '{"ROOT_QUERY": {"__typename": "Query", ' + ASIMOV + "}}"
    )
    _ = cache.evict(id, "authorOfBook")
    assert_extract(cache, '{"ROOT_QUERY": {"__typename": "Query"}}')


def test_allows_evicting_specific_fields_with_specific_arguments() raises:
    var cache = InMemoryCache()
    _three_authors(cache)
    _check_eviction_with_arguments(cache, None)


def test_evicts_fields_with_arguments_using_an_id() raises:
    var cache = InMemoryCache()
    _three_authors(cache)
    _check_eviction_with_arguments(cache, String("ROOT_QUERY"))


def test_supports_identify_of_a_reference() raises:
    var config = InMemoryCacheConfig()
    var task = TypePolicy()
    task.key_fields = KeyFields.parse('["uuid"]')
    config.type_policies["Task"] = task^
    var cache = InMemoryCache(config)
    assert_equal(cache.identify(json('{"__ref": "oyez"}')).value(), "oyez")
    var todo = cache.write_fragment(
        gql("fragment TodoId on Todo { id }"),
        json('{"__typename": "Todo", "id": 123}'),
    )
    assert_equal(todo, "Todo:123")
    assert_equal(
        cache.identify(json('{"__ref": "' + todo + '"}')).value(), "Todo:123"
    )
    var task_id = cache.write_fragment(
        gql("fragment TaskId on Task { uuid }"),
        json(
            '{"__typename": "Task", "uuid":'
            ' "eb8cffcc-7a9e-4d8b-a517-7d987bf42138"}'
        ),
    )
    assert_equal(
        task_id, 'Task:{"uuid":"eb8cffcc-7a9e-4d8b-a517-7d987bf42138"}'
    )


def test_supports_identify_of_an_object() raises:
    var config = InMemoryCacheConfig()
    var abcs = TypePolicy()
    abcs.key_fields = KeyFields.parse('["b", "a", "c"]')
    config.type_policies["ABCs"] = abcs^
    var cache = InMemoryCache(config)
    var with_aliases = gql(
        "query { abcs { first: a second: b ...Rest } } fragment Rest on ABCs"
        " { third: c }"
    )
    var without_aliases = gql(
        "query { abcs { a b ...Rest } } fragment Rest on ABCs { c }"
    )
    var aliased = (
        '{"__typename": "ABCs", "first": "ay", "second": "bee", "third": "see"}'
    )
    _ = cache.write_query(with_aliases, json('{"abcs": ' + aliased + "}"))
    var key = 'ABCs:{\\"b\\":\\"bee\\",\\"a\\":\\"ay\\",\\"c\\":\\"see\\"}'
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "abcs": {"__ref": "'
        + key
        + '"}}, "'
        + key
        + '": {"__typename": "ABCs", "a": "ay", "b": "bee", "c": "see"}}',
    )
    assert_read(cache, with_aliases, '{"abcs": ' + aliased + "}")
    assert_read(
        cache,
        without_aliases,
        '{"abcs": {"__typename": "ABCs", "a": "ay", "b": "bee", "c": "see"}}',
    )
    assert_equal(
        cache.identify(
            json('{"__typename": "ABCs", "a": 1, "b": 2, "c": 3}')
        ).value(),
        'ABCs:{"b":2,"a":1,"c":3}',
    )
    assert_false(Bool(cache.identify(json(aliased))))
    var plain = '{"__typename": "ABCs", "a": "ay", "b": "bee", "c": "see"}'
    var b = cache.read_fragment(
        gql("fragment JustB on ABCs { b }"), cache.identify(json(plain)).value()
    )
    assert_json(b.value(), '{"__typename": "ABCs", "b": "bee"}')
    _ = cache.evict(cache.identify(json(plain)))
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "abcs": {"__ref": "'
        + key
        + '"}}}',
    )
    var dangling = String(
        'Dangling reference to missing ABCs:{"b":"bee","a":"ay","c":"see"}'
        " object"
    )
    var tree = (
        '{"abcs":"Dangling reference to missing'
        ' ABCs:{\\"b\\":\\"bee\\",\\"a\\":\\"ay\\",\\"c\\":\\"see\\"} object"}'
    )
    var queries = List[String]()
    queries.append(
        "query { abcs { first: a second: b ...Rest } } fragment Rest on ABCs"
        " { third: c }"
    )
    queries.append("query { abcs { a b ...Rest } } fragment Rest on ABCs { c }")
    for ref text in queries:
        assert_false(Bool(cache.read_query(gql(text))))
        assert_equal(
            diff_text(cache, text, "{}", False),
            "False null | " + dangling + " | " + tree,
        )


def _title(isbn: StringSlice) -> String:
    """`titlesByISBN.get(isbn)` of the toReference cases, or empty."""
    if isbn == "9781451673319":
        return "Fahrenheit 451"
    if isbn == "1603589082":
        return "Eager"
    if isbn == "1760641790":
        return "How To Do Nothing"
    if isbn == "9780062569714":
        return "Hunger"
    if isbn == "9781784295547":
        return "Shrill"
    if isbn == "9780807083109":
        return "Kindred"
    return ""


def _book_document(isbn: StringSlice, with_title: Bool) -> JsonDocument:
    """`{ __typename: "Book", title?, isbn }` as a JSON document."""
    var document = JsonDocument()
    document.root = document.add_object()
    document.add_member(
        document.root, "__typename", document.add_string("Book")
    )
    var title = _title(isbn)
    if with_title and title.byte_length() > 0:
        document.add_member(document.root, "title", document.add_string(title))
    document.add_member(document.root, "isbn", document.add_string(isbn))
    return document^


def _text_or_empty(mut options: FieldFunctionOptions, value: Int) -> String:
    """Return the text of a string value, or empty."""
    ref values = options.cache[].values
    if values.kind(value) == ValueKind.STRING:
        return String(values.text(value))
    return ""


def read_book_persisting(
    existing: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The `book` read function of "supports toReference(obj, true)"."""
    var isbn = _text_or_empty(
        options, options.cache[].values.get(options.args, "isbn")
    )
    var reference = options.cache[].to_reference_object(
        _book_document(isbn, False), True
    )
    assert_equal(
        _text_or_empty(
            options, options.read_field_from("__typename", reference)
        ),
        "Book",
    )
    var stored = _text_or_empty(
        options, options.read_field_from("isbn", reference)
    )
    assert_equal(stored, isbn)
    assert_equal(
        _text_or_empty(options, options.read_field_from("title", reference)),
        _title(stored),
    )
    return reference


def merge_books_persisting(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The `books` merge function of "supports toReference(obj, true)"."""
    var items = options.cache[].values.array_items(existing)
    var count = options.cache[].values.length(incoming)
    var index = 0
    while index < count:
        var book = options.cache[].values.item(incoming, index)
        assert_false(options.is_reference(book))
        assert_equal(options.cache[].values.get(book, "__typename"), NO_VALUE)
        var isbn = _text_or_empty(
            options, options.cache[].values.get(book, "isbn")
        )
        var reference = options.cache[].to_reference_object(
            _book_document(isbn, True), True
        )
        assert_true(options.is_reference(reference))
        assert_equal(
            _text_or_empty(
                options, options.read_field_from("__typename", reference)
            ),
            "Book",
        )
        assert_equal(
            _text_or_empty(options, options.read_field_from("isbn", reference)),
            _text_or_empty(options, options.read_field_from("isbn", book)),
        )
        items.append(reference)
        index += 1
    return options.cache[].values.add_array(items)


def modify_title(value: Int, mut details: ModifierDetails) raises -> Int:
    """The `title` modifier of "supports toReference(obj, true)"."""
    ref values = details.cache[].values
    var isbn = String(values.text(details.read_field("isbn")))
    var book = JsonDocument()
    book.root = book.add_object()
    book.add_member(book.root, "__typename", book.add_string("Book"))
    book.add_member(book.root, "isbn", book.add_string(isbn))
    book.add_member(book.root, "author", book.add_string("J.K. Rowling"))
    var without_author = details.to_reference_object(book, False)
    assert_true(details.is_reference(without_author))
    assert_equal(details.read_field_from("author", without_author), NO_VALUE)
    var reference = details.to_reference_object(book, True)
    assert_true(details.is_reference(reference))
    assert_equal(
        String(values.text(details.read_field_from("author", reference))),
        "J.K. Rowling",
    )
    assert_equal(
        String(values.text(details.read_field("author"))), "J.K. Rowling"
    )
    var title = String(values.text(value))
    return values.add_string(title.replace("'", "’"))


def test_supports_to_reference_of_an_object_to_persist_it() raises:
    var config = InMemoryCacheConfig()
    var query_policy = TypePolicy()
    query_policy.fields["book"] = FieldPolicy(read_book_persisting)
    var books = FieldPolicy()
    books.merge = Merge(merge_books_persisting)
    query_policy.fields["books"] = books^
    config.type_policies["Query"] = query_policy^
    var book_policy = TypePolicy()
    book_policy.key_fields = KeyFields.parse('["isbn"]')
    config.type_policies["Book"] = book_policy^
    var cache = InMemoryCache(config)
    var books_query = "query { books { isbn } }"
    var book_query = gql("query { book(isbn: $isbn) { isbn title } }")
    _ = write(
        cache,
        books_query,
        '{"books": [{"isbn": "9781451673319"}, {"isbn": "1603589082"}]}',
    )
    var f451 = (
        '"Book:{\\"isbn\\":\\"9781451673319\\"}": {"__typename": "Book",'
        ' "isbn": "9781451673319", "title": "Fahrenheit 451"}'
    )
    var eager = (
        '"Book:{\\"isbn\\":\\"1603589082\\"}": {"__typename": "Book", "isbn":'
        ' "1603589082", "title": "Eager"}'
    )
    var two_refs = (
        '{"__ref": "Book:{\\"isbn\\":\\"9781451673319\\"}"}, {"__ref":'
        ' "Book:{\\"isbn\\":\\"1603589082\\"}"}'
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "books": ['
        + two_refs
        + "]}, "
        + f451
        + ", "
        + eager
        + "}",
    )
    _ = write(cache, books_query, '{"books": [{"isbn": "1760641790"}]}')
    var nothing = (
        '"Book:{\\"isbn\\":\\"1760641790\\"}": {"__typename": "Book", "isbn":'
        ' "1760641790", "title": "How To Do Nothing"}'
    )
    var three = (
        '"ROOT_QUERY": {"__typename": "Query", "books": ['
        + two_refs
        + ', {"__ref": "Book:{\\"isbn\\":\\"1760641790\\"}"}]}, '
        + f451
        + ", "
        + eager
        + ", "
        + nothing
    )
    assert_extract(cache, "{" + three + "}")
    assert_read(
        cache,
        book_query,
        (
            '{"book": {"__typename": "Book", "isbn": "1760641790", "title":'
            ' "How To Do Nothing"}}'
        ),
        '{"isbn": "1760641790"}',
    )
    assert_extract(cache, "{" + three + "}")
    assert_read(
        cache,
        book_query,
        (
            '{"book": {"__typename": "Book", "isbn": "9781451673319", "title":'
            ' "Fahrenheit 451"}}'
        ),
        '{"isbn": "9781451673319"}',
    )
    var diff = cache.diff(book_query, json('{"isbn": "031648637X"}'))
    assert_false(diff.complete)
    assert_json(
        diff.result.value(),
        '{"book": {"__typename": "Book", "isbn": "031648637X"}}',
    )
    var message = String(
        'Can\'t find field \'title\' on Book:{"isbn":"031648637X"} object'
    )
    assert_equal(diff.missing.value().message, message)
    var cuckoo_key = '"Book:{\\"isbn\\":\\"031648637X\\"}"'
    assert_extract(
        cache,
        "{"
        + three
        + ", "
        + cuckoo_key
        + ': {"__typename": "Book", "isbn": "031648637X"}}',
    )
    var cuckoo = cache.identify(
        json('{"__typename": "Book", "isbn": "031648637X"}')
    ).value()
    assert_equal(cuckoo, 'Book:{"isbn":"031648637X"}')
    _ = cache.write_query(
        gql("{ title }"),
        json('{"title": "The Cuckoo\'s Calling"}'),
        json("{}"),
        cuckoo,
    )
    var meta = '"__META": {"extraRootIds": [' + cuckoo_key + "]}"
    assert_extract(
        cache,
        "{"
        + three
        + ", "
        + meta
        + ", "
        + cuckoo_key
        + ': {"__typename": "Book", "isbn": "031648637X", "title": "The'
        " Cuckoo's Calling\"}}",
    )
    var fields = Dict[String, Modifier]()
    fields["title"] = modify_title
    assert_true(cache.modify(fields, cuckoo))
    assert_extract(
        cache,
        "{"
        + three
        + ", "
        + meta
        + ", "
        + cuckoo_key
        + ': {"__typename": "Book", "isbn": "031648637X", "title": "The'
        ' Cuckoo’s Calling", "author": "J.K. Rowling"}}',
    )


def read_favorited(
    existing: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The `favorited` read function of "supports toReference(id)"."""
    var root = options.to_reference("ROOT_QUERY")
    assert_equal(
        options.cache[].values.stringify(root), '{"__ref":"ROOT_QUERY"}'
    )
    var favorites = options.read_field_from("favoritedBooks", root)
    var isbn = options.read_field("isbn")
    var count = options.cache[].values.length(favorites)
    var index = 0
    while index < count:
        var other = options.read_field_from(
            "isbn", options.cache[].values.item(favorites, index)
        )
        if options.cache[].values.equal(isbn, other):
            return TRUE_VALUE
        index += 1
    return FALSE_VALUE


def read_book_with_title(
    existing: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The `book` read function of "supports toReference(id)"."""
    var isbn = _text_or_empty(
        options, options.cache[].values.get(options.args, "isbn")
    )
    return options.cache[].to_reference_object(_book_document(isbn, True), True)


def test_supports_to_reference_of_an_id() raises:
    var config = InMemoryCacheConfig()
    var book_policy = TypePolicy()
    book_policy.fields["favorited"] = FieldPolicy(read_favorited)
    book_policy.key_fields = KeyFields.parse('["isbn"]')
    config.type_policies["Book"] = book_policy^
    var query_policy = TypePolicy()
    query_policy.fields["book"] = FieldPolicy(read_book_with_title)
    config.type_policies["Query"] = query_policy^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "{ favoritedBooks { isbn title } }",
        (
            '{"favoritedBooks": [{"__typename": "Book", "isbn":'
            ' "9781784295547", "title": "Shrill", "author": "Lindy West"}]}'
        ),
    )
    var book_query = gql(
        "query { book(isbn: $isbn) { isbn title favorited @client } }"
    )
    assert_read(
        cache,
        book_query,
        (
            '{"book": {"__typename": "Book", "isbn": "9781784295547", "title":'
            ' "Shrill", "favorited": true}}'
        ),
        '{"isbn": "9781784295547"}',
    )
    assert_read(
        cache,
        book_query,
        (
            '{"book": {"__typename": "Book", "isbn": "9780807083109", "title":'
            ' "Kindred", "favorited": false}}'
        ),
        '{"isbn": "9780807083109"}',
    )


def test_restore_merges_the_entity_that_a_reference_names() raises:
    # Upstream `replace` calls `merge(id, object)`. An object with a
    # string `__ref` is a Reference, so the entity it names merges in, and
    # nothing does when it names none. Expected output: Node.js.
    var cache = InMemoryCache()
    cache.restore(json('{"A": {"__typename": "T", "__ref": "A", "x": 1}}'))
    assert_extract_exact(cache, "{}")
    cache.restore(
        json('{"B": {"__typename": "T", "x": 1}, "C": {"__ref": "B"}}')
    )
    assert_extract_exact(cache, '{"B":{"__typename":"T","x":1}}')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
