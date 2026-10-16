# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Apollo Client 4.3.3 `src/cache/inmemory/__tests__/policies.ts`,
part 1: type policies, keyFields and inheritance.

The cases continue in `test_policies_2.mojo` and `test_policies_3.mojo`.
`extract(true)` of upstream is `extract()` here: there are no optimistic
layers. The expected texts that upstream keeps in snapshots are the
Node.js output of Apollo Client 4.3.3.

Upstream cases that are not ported, for the three files:

- Functions that return a key specifier array: "accepts keyFields
  functions" and "can return KeySpecifier arrays from keyArgs functions".
  A `KeyFieldsFunction` and a `KeyArgsFunction` return a `String`.
- `options.storage`: "can use options.storage in read functions", "read
  and merge can cooperate through options.storage", "read, merge, and
  modify functions can access options.storage". The storage object is not
  ported.
- ApolloClient and `relayStylePagination`: "can handle Relay-style
  pagination without args" and "can handle Relay-style pagination" run
  `ApolloClient` with a link, `watchQuery` and the `relayStylePagination`
  helper of `@apollo/client/utilities`, which are not ported.
- Console warnings: "readField warns if explicitly passed undefined `from`
  option".

Parts of ported cases that are left out:

- Result identity (`toBe` between reads) in "support inheritance" and
  "can read from foreign references using read helper": a read builds a
  new result each time.
- The reactive variables of "readField helper function calls custom read
  functions": the `ownTime` values come from a fixed table.
- The counters of merge calls in "runs nested merge functions as well as
  ancestors" and the inherited merge function cases, and the list of
  `storeFieldName`s that the modifier of "can include optional arguments
  in field keyArgs policy" collects: a thin Mojo function holds no state.
  The extracted store field names cover the same names.
- The console checks of "complains about missing key fields".
"""

from std.collections import Dict

from gql_client.cache import (
    FieldFunctionOptions,
    InMemoryCache,
    InMemoryCacheConfig,
    KeyFieldsContext,
)
from gql_client.policies import FieldPolicy, KeyFields, Merge, TypePolicy
from gql_client.values import NO_VALUE
from std.testing import TestSuite, assert_equal, assert_raises, assert_true

from _helpers import (
    assert_extract,
    assert_extract_exact,
    assert_read,
    assert_read_exact,
    gql,
    json,
    write,
)
from _policy_helpers import add_field, possible, text

comptime BOOK_QUERY = "query { book { title author { name } } }"
"""The `bookQuery` of upstream."""
comptime BOOK = (
    '{"__typename": "Book", "isbn": "1400096235", "title": "The'
    ' Information", "subtitle": "A History, a Theory, a Flood", "author":'
    ' {"name": "James Gleick"}}'
)
"""The `theInformationBookData` of upstream."""


def _key_cache(spec: StringSlice) raises -> InMemoryCache:
    """A cache whose `Book` policy has `keyFields` from JSON text."""
    var config = InMemoryCacheConfig()
    var book = TypePolicy()
    book.key_fields = KeyFields.parse(spec)
    config.type_policies["Book"] = book^
    return InMemoryCache(config)


def _check_author_name(mut cache: InMemoryCache) raises:
    """`checkAuthorName` of upstream."""
    assert_read(
        cache,
        gql("query { book { author { name } } }"),
        '{"book": {"__typename": "Book", "author": {"name": "James Gleick"}}}',
    )


def test_can_specify_basic_key_fields() raises:
    var cache = _key_cache('["isbn"]')
    _ = write(cache, BOOK_QUERY, '{"book": ' + String(BOOK) + "}")
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "book": {"__ref":'
            ' "Book:{\\"isbn\\":\\"1400096235\\"}"}},'
            ' "Book:{\\"isbn\\":\\"1400096235\\"}": {"__typename": "Book",'
            ' "isbn": "1400096235", "title": "The Information", "author":'
            ' {"name": "James Gleick"}}}'
        ),
    )
    _check_author_name(cache)


def test_can_specify_composite_key_fields() raises:
    var cache = _key_cache('["title", "author", ["name"]]')
    _ = write(cache, BOOK_QUERY, '{"book": ' + String(BOOK) + "}")
    var id = (
        'Book:{\\"title\\":\\"The'
        ' Information\\",\\"author\\":{\\"name\\":\\"James Gleick\\"}}'
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "book": {"__ref": "'
        + id
        + '"}}, "'
        + id
        + '": {"__typename": "Book", "title": "The Information", "author":'
        ' {"name": "James Gleick"}}}',
    )
    _check_author_name(cache)


def test_can_specify_nested_key_fields_with_alias() raises:
    var cache = _key_cache('["title", "author", ["name"]]')
    _ = write(
        cache,
        "query { book { title writer: author { alias: name } } }",
        (
            '{"book": {"__typename": "Book", "isbn": "1400096235", "title":'
            ' "The Information", "subtitle": "A History, a Theory, a Flood",'
            ' "writer": {"alias": "James Gleick"}}}'
        ),
    )
    var id = (
        'Book:{\\"title\\":\\"The'
        ' Information\\",\\"author\\":{\\"name\\":\\"James Gleick\\"}}'
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "book": {"__ref": "'
        + id
        + '"}}, "'
        + id
        + '": {"__typename": "Book", "title": "The Information", "author":'
        ' {"name": "James Gleick"}}}',
    )
    _check_author_name(cache)


def test_keeps_key_fields_in_specified_order() raises:
    var cache = _key_cache('["author", ["name"], "title"]')
    _ = write(cache, BOOK_QUERY, '{"book": ' + String(BOOK) + "}")
    var id = (
        'Book:{\\"author\\":{\\"name\\":\\"James'
        ' Gleick\\"},\\"title\\":\\"The Information\\"}'
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "book": {"__ref": "'
        + id
        + '"}}, "'
        + id
        + '": {"__typename": "Book", "title": "The Information", "author":'
        ' {"name": "James Gleick"}}}',
    )
    _check_author_name(cache)


def test_serializes_nested_key_fields_objects_in_stable_order() raises:
    var cache = _key_cache('["title", "author"]')
    var query = (
        "query { book { title writer: author { first: firstName lastName } } }"
    )
    _ = write(
        cache,
        query,
        (
            '{"book": {"__typename": "Book", "writer": {"first": "Rebecca",'
            ' "lastName": "Schwarzlose", "__typename": "Person"}, "title":'
            ' "Brainscapes"}}'
        ),
    )
    _ = write(
        cache,
        query,
        (
            '{"book": {"__typename": "Book", "title": "The Science of Can and'
            ' Can\'t", "writer": {"lastName": "Marletto", "__typename":'
            ' "Person", "first": "Chiarra"}}}'
        ),
    )
    var first = 'Book:{\\"title\\":\\"Brainscapes\\",\\"author\\":{\\"__typename\\":\\"Person\\",\\"firstName\\":\\"Rebecca\\",\\"lastName\\":\\"Schwarzlose\\"}}'
    var second = (
        'Book:{\\"title\\":\\"The Science of Can and'
        ' Can\'t\\",\\"author\\":{\\"__typename\\":\\"Person\\",\\"firstName\\":\\"Chiarra\\",\\"lastName\\":\\"Marletto\\"}}'
    )
    assert_extract(
        cache,
        '{"'
        + first
        + '": {"__typename": "Book", "title": "Brainscapes", "author":'
        ' {"__typename": "Person", "firstName": "Rebecca", "lastName":'
        ' "Schwarzlose"}}, "'
        + second
        + '": {"__typename": "Book", "title": "The Science of Can and'
        ' Can\'t", "author": {"__typename": "Person", "firstName": "Chiarra",'
        ' "lastName": "Marletto"}}, "ROOT_QUERY": {"__typename": "Query",'
        ' "book": {"__ref": "'
        + second
        + '"}}}',
    )


def test_works_with_fragments_that_contain_aliased_key_fields() raises:
    var cache = _key_cache('["ISBN", "title"]')
    _ = write(
        cache,
        (
            "query { book { ...BookFragment author { name } } } fragment"
            " BookFragment on Book { isbn: ISBN title }"
        ),
        '{"book": ' + String(BOOK) + "}",
    )
    var id = (
        'Book:{\\"ISBN\\":\\"1400096235\\",\\"title\\":\\"The Information\\"}'
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "book": {"__ref": "'
        + id
        + '"}}, "'
        + id
        + '": {"__typename": "Book", "ISBN": "1400096235", "title": "The'
        ' Information", "author": {"name": "James Gleick"}}}',
    )
    _check_author_name(cache)


def test_complains_about_missing_key_fields() raises:
    var cache = _key_cache('["title", "year"]')
    var query = "query { book { title year } }"
    _ = write(
        cache,
        query,
        '{"book": {"year": 2011, "theInformationBookData": '
        + String(BOOK)
        + "}}",
    )
    assert_extract_exact(
        cache, '{"ROOT_QUERY":{"__typename":"Query","book":{"year":2011}}}'
    )
    with assert_raises(
        contains=(
            "Missing field 'year' while extracting keyFields from {\n "
            ' "__typename": "Book",\n  "isbn": "1400096235",\n  "title": "The'
            ' Information",\n  "subtitle": "A History, a Theory, a Flood",\n '
            ' "author": {\n    "name": "James Gleick"\n  }\n}'
        )
    ):
        _ = write(cache, query, '{"book": ' + String(BOOK) + "}")


def motion_picture(mut context: KeyFieldsContext) raises -> String:
    """`keyFields(incoming) { return `MotionPicture::${incoming.id}` }`."""
    var id = context.field("id")
    return "MotionPicture::" + String(context.cache[].values.text(id))


def read_false(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`isPurchased() { return false }`."""
    return options.cache[].values.add_bool(False)


def test_does_not_clobber_previous_key_fields_with_undefined() raises:
    var config = InMemoryCacheConfig()
    var movie = TypePolicy()
    movie.key_fields = KeyFields(motion_picture)
    config.type_policies["Movie"] = movie^
    var cache = InMemoryCache(config)
    var more = Dict[String, TypePolicy]()
    var added = TypePolicy()
    added.fields["isPurchased"] = FieldPolicy(read_false)
    more["Movie"] = added^
    cache.policies.add_type_policies(more)
    var id = cache.identify(
        json('{"__typename": "Movie", "id": "3993d4118143"}')
    )
    assert_equal(id.value(), "MotionPicture::3993d4118143")


def read_foo(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`foo: () => "foo"`."""
    return options.cache[].values.add_string("foo")


def read_bar(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`bar: () => "bar"`."""
    return options.cache[].values.add_string("bar")


def test_does_not_remove_previous_type_policies() raises:
    var config = InMemoryCacheConfig()
    add_field(config, "Query", "foo", FieldPolicy(read_foo))
    var cache = InMemoryCache(config)
    var more = Dict[String, TypePolicy]()
    var added = TypePolicy()
    added.fields["bar"] = FieldPolicy(read_bar)
    more["Query"] = added^
    cache.policies.add_type_policies(more)
    assert_read(cache, gql("{ foo }"), '{"foo": "foo"}')
    assert_read(cache, gql("{ bar }"), '{"bar": "bar"}')


def lower_case(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`merge(_, incoming) { return incoming.toLowerCase() }`."""
    var lowered = text(options, incoming).lower()
    return options.cache[].values.add_string(lowered)


def venomous(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`venomous(status = "unknown") { return status }`."""
    if existing == NO_VALUE:
        return options.cache[].values.add_string("unknown")
    return existing


def test_supports_inheritance() raises:
    var config = InMemoryCacheConfig()
    possible(config, "Reptile", ["Snake", "Turtle"])
    possible(config, "Snake", ["Python", "Viper", "Cobra"])
    possible(config, "Viper", ["Cottonmouth"])
    var reptile = TypePolicy()
    reptile.key_fields = KeyFields.parse('["tagId"]')
    var scientific = FieldPolicy()
    scientific.merge = Merge(lower_case)
    reptile.fields["scientificName"] = scientific^
    config.type_policies["Reptile"] = reptile^
    add_field(config, "Snake", "venomous", FieldPolicy(venomous))
    var cache = InMemoryCache(config)
    var query = gql(
        "query { reptiles { tagId scientificName ... on Snake { venomous } } }"
    )
    _ = cache.write_query(
        query,
        json(
            '{"reptiles": [{"__typename": "Turtle", "tagId":'
            ' "RedEaredSlider42", "scientificName": "Trachemys scripta'
            ' elegans"}, {"__typename": "Python", "tagId": "BigHug4U",'
            ' "scientificName": "Malayopython reticulatus", "venomous":'
            ' false}, {"__typename": "Cobra", "tagId": "Egypt30BC",'
            ' "scientificName": "Naja haje", "venomous": true},'
            ' {"__typename": "Cottonmouth", "tagId": "CM420",'
            ' "scientificName": "Agkistrodon piscivorus", "venomous":'
            " true}]}"
        ),
    )
    assert_extract_exact(
        cache,
        (
            '{"Turtle:{\\"tagId\\":\\"RedEaredSlider42\\"}":{"__typename":"Turtle","tagId":"RedEaredSlider42","scientificName":"trachemys'
            " scripta"
            ' elegans"},"Python:{\\"tagId\\":\\"BigHug4U\\"}":{"__typename":"Python","tagId":"BigHug4U","scientificName":"malayopython'
            ' reticulatus","venomous":false},"Cobra:{\\"tagId\\":\\"Egypt30BC\\"}":{"__typename":"Cobra","tagId":"Egypt30BC","scientificName":"naja'
            ' haje","venomous":true},"Cottonmouth:{\\"tagId\\":\\"CM420\\"}":{"__typename":"Cottonmouth","tagId":"CM420","scientificName":"agkistrodon'
            ' piscivorus","venomous":true},"ROOT_QUERY":{"__typename":"Query","reptiles":[{"__ref":"Turtle:{\\"tagId\\":\\"RedEaredSlider42\\"}"},{"__ref":"Python:{\\"tagId\\":\\"BigHug4U\\"}"},{"__ref":"Cobra:{\\"tagId\\":\\"Egypt30BC\\"}"},{"__ref":"Cottonmouth:{\\"tagId\\":\\"CM420\\"}"}]}}'
        ),
    )
    assert_read_exact(
        cache,
        query,
        (
            '{"reptiles":[{"__typename":"Turtle","tagId":"RedEaredSlider42","scientificName":"trachemys'
            " scripta"
            ' elegans"},{"__typename":"Python","tagId":"BigHug4U","scientificName":"malayopython'
            ' reticulatus","venomous":false},{"__typename":"Cobra","tagId":"Egypt30BC","scientificName":"naja'
            ' haje","venomous":true},{"__typename":"Cottonmouth","tagId":"CM420","scientificName":"agkistrodon'
            ' piscivorus","venomous":true}]}'
        ),
    )
    var id = cache.identify(
        json('{"__typename": "Cottonmouth", "tagId": "CM420"}')
    )
    assert_equal(id.value(), 'Cottonmouth:{"tagId":"CM420"}')
    assert_true(cache.evict(id, "venomous"))
    assert_read_exact(
        cache,
        query,
        (
            '{"reptiles":[{"__typename":"Turtle","tagId":"RedEaredSlider42","scientificName":"trachemys'
            " scripta"
            ' elegans"},{"__typename":"Python","tagId":"BigHug4U","scientificName":"malayopython'
            ' reticulatus","venomous":false},{"__typename":"Cobra","tagId":"Egypt30BC","scientificName":"naja'
            ' haje","venomous":true},{"__typename":"Cottonmouth","tagId":"CM420","scientificName":"agkistrodon'
            ' piscivorus","venomous":"unknown"}]}'
        ),
    )
    var more = Dict[String, List[String]]()
    more["Viper"] = ["DeathAdder"]
    cache.policies.add_possible_types(more)
    var adder = cache.identify(
        json('{"__typename": "DeathAdder", "tagId": "LethalAbacus666"}')
    )
    assert_equal(adder.value(), 'DeathAdder:{"tagId":"LethalAbacus666"}')


def named_name(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`read(existing) { return existing + " (Named)" }`."""
    return options.cache[].values.add_string(
        text(options, existing) + " (Named)"
    )


def person_name(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`read(existing) { return existing + " (Person)" }`."""
    return options.cache[].values.add_string(
        text(options, existing) + " (Person)"
    )


def test_specific_field_policies_do_not_override_supertype_policies() raises:
    var config = InMemoryCacheConfig()
    add_field(config, "Named", "name", FieldPolicy(named_name))
    add_field(config, "Person", "name", FieldPolicy(person_name))
    possible(config, "Named", ["Person", "Pet"])
    var cache = InMemoryCache(config)
    var query = "{ me { __typename id name pets { __typename id name } } }"
    _ = write(
        cache,
        query,
        (
            '{"me": {"__typename": "Person", "id": 23, "name": "John Doe",'
            ' "pets": [{"__typename": "Pet", "id": 1, "name": "Fido"},'
            ' {"__typename": "Pet", "id": 2, "name": "Whiskers"}]}}'
        ),
    )
    assert_read(
        cache,
        gql(query),
        (
            '{"me": {"__typename": "Person", "id": 23, "name": "John Doe'
            ' (Person)", "pets": [{"__typename": "Pet", "id": 1, "name": "Fido'
            ' (Named)"}, {"__typename": "Pet", "id": 2, "name": "Whiskers'
            ' (Named)"}]}}'
        ),
    )


def concat(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`existing ? existing.concat(incoming) : incoming`."""
    if existing == NO_VALUE:
        return incoming
    ref values = options.cache[].values
    var items = values.array_items(existing)
    items.extend(Span(values.array_items(incoming)))
    return values.add_array(items)


def test_inherits_type_policies_with_fuzzy_possible_types() raises:
    var config = InMemoryCacheConfig()
    possible(config, "EntitySupertype", [".*Entity"])
    var coworkers = FieldPolicy()
    coworkers.merge = Merge(concat)
    add_field(config, "Query", "coworkers", coworkers^)
    var entity = TypePolicy()
    entity.key_fields = KeyFields.parse('["uid"]')
    config.type_policies["EntitySupertype"] = entity^
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "query { coworkers { uid name } }",
        (
            '{"coworkers": [{"__typename": "CoworkerEntity", "uid": "qwer",'
            ' "name": "Alessia"}, {"__typename": "CoworkerEntity", "uid":'
            ' "asdf", "name": "Jerel"}, {"__typename": "CoworkerEntity", "uid":'
            ' "zxcv", "name": "Lenz"}, {"__typename": "ManagerEntity", "uid":'
            ' "uiop", "name": "Jeff"}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "coworkers": [{"__ref":'
            ' "CoworkerEntity:{\\"uid\\":\\"qwer\\"}"}, {"__ref":'
            ' "CoworkerEntity:{\\"uid\\":\\"asdf\\"}"}, {"__ref":'
            ' "CoworkerEntity:{\\"uid\\":\\"zxcv\\"}"}, {"__ref":'
            ' "ManagerEntity:{\\"uid\\":\\"uiop\\"}"}]},'
            ' "CoworkerEntity:{\\"uid\\":\\"qwer\\"}": {"__typename":'
            ' "CoworkerEntity", "uid": "qwer", "name": "Alessia"},'
            ' "CoworkerEntity:{\\"uid\\":\\"asdf\\"}": {"__typename":'
            ' "CoworkerEntity", "uid": "asdf", "name": "Jerel"},'
            ' "CoworkerEntity:{\\"uid\\":\\"zxcv\\"}": {"__typename":'
            ' "CoworkerEntity", "uid": "zxcv", "name": "Lenz"},'
            ' "ManagerEntity:{\\"uid\\":\\"uiop\\"}": {"__typename":'
            ' "ManagerEntity", "uid": "uiop", "name": "Jeff"}}'
        ),
    )
    var alias = "query { coworkers { idAlias: uid name } }"
    assert_read(
        cache,
        gql(alias),
        (
            '{"coworkers": [{"__typename": "CoworkerEntity", "idAlias": "qwer",'
            ' "name": "Alessia"}, {"__typename": "CoworkerEntity", "idAlias":'
            ' "asdf", "name": "Jerel"}, {"__typename": "CoworkerEntity",'
            ' "idAlias": "zxcv", "name": "Lenz"}, {"__typename":'
            ' "ManagerEntity", "idAlias": "uiop", "name": "Jeff"}]}'
        ),
    )
    _ = write(
        cache,
        alias,
        (
            '{"coworkers": [{"__typename": "CoworkerEntity", "idAlias": "hjkl",'
            ' "name": "Martijn"}, {"__typename": "ManagerEntity", "idAlias":'
            ' "vbnm", "name": "Hugh"}]}'
        ),
    )
    assert_read(
        cache,
        gql("query { coworkers { uid name } }"),
        (
            '{"coworkers": [{"__typename": "CoworkerEntity", "uid": "qwer",'
            ' "name": "Alessia"}, {"__typename": "CoworkerEntity", "uid":'
            ' "asdf", "name": "Jerel"}, {"__typename": "CoworkerEntity", "uid":'
            ' "zxcv", "name": "Lenz"}, {"__typename": "ManagerEntity", "uid":'
            ' "uiop", "name": "Jeff"}, {"__typename": "CoworkerEntity", "uid":'
            ' "hjkl", "name": "Martijn"}, {"__typename": "ManagerEntity",'
            ' "uid": "vbnm", "name": "Hugh"}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "coworkers": [{"__ref":'
            ' "CoworkerEntity:{\\"uid\\":\\"qwer\\"}"}, {"__ref":'
            ' "CoworkerEntity:{\\"uid\\":\\"asdf\\"}"}, {"__ref":'
            ' "CoworkerEntity:{\\"uid\\":\\"zxcv\\"}"}, {"__ref":'
            ' "ManagerEntity:{\\"uid\\":\\"uiop\\"}"}, {"__ref":'
            ' "CoworkerEntity:{\\"uid\\":\\"hjkl\\"}"}, {"__ref":'
            ' "ManagerEntity:{\\"uid\\":\\"vbnm\\"}"}]},'
            ' "CoworkerEntity:{\\"uid\\":\\"qwer\\"}": {"__typename":'
            ' "CoworkerEntity", "uid": "qwer", "name": "Alessia"},'
            ' "CoworkerEntity:{\\"uid\\":\\"asdf\\"}": {"__typename":'
            ' "CoworkerEntity", "uid": "asdf", "name": "Jerel"},'
            ' "CoworkerEntity:{\\"uid\\":\\"zxcv\\"}": {"__typename":'
            ' "CoworkerEntity", "uid": "zxcv", "name": "Lenz"},'
            ' "ManagerEntity:{\\"uid\\":\\"uiop\\"}": {"__typename":'
            ' "ManagerEntity", "uid": "uiop", "name": "Jeff"},'
            ' "CoworkerEntity:{\\"uid\\":\\"hjkl\\"}": {"__typename":'
            ' "CoworkerEntity", "uid": "hjkl", "name": "Martijn"},'
            ' "ManagerEntity:{\\"uid\\":\\"vbnm\\"}": {"__typename":'
            ' "ManagerEntity", "uid": "vbnm", "name": "Hugh"}}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
