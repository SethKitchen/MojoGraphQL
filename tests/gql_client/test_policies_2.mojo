# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Apollo Client 4.3.3 `src/cache/inmemory/__tests__/policies.ts`,
part 2: field policies, `keyArgs`, and read and merge functions.

`test_policies.mojo` lists the upstream cases that are not ported. In
"readField helper function calls custom read functions", the `ownTime`
values come from a fixed table: upstream keeps them in reactive variables
and changes them between reads, which this port cannot express. The reads
with the first values and the write of the independent task are ported.
"""

from std.collections import Dict

from gql_client.cache import (
    FieldFunctionOptions,
    InMemoryCache,
    InMemoryCacheConfig,
    KeyArgsContext,
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
from gql_client.values import NO_VALUE, NULL_VALUE, UNDEFINED_VALUE, ValueKind
from std.testing import TestSuite, assert_equal, assert_false, assert_true

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
from _policy_helpers import add_field, arg, number, text


def _key_args_cache(
    typename: String, field: String, spec: StringSlice
) raises -> InMemoryCacheConfig:
    """A config with one `keyArgs` specifier."""
    var config = InMemoryCacheConfig()
    var policy = FieldPolicy()
    policy.key_args = KeyArgs.parse(spec)
    add_field(config, typename, field, policy^)
    return config^


def test_can_filter_arguments_using_key_args() raises:
    var cache = InMemoryCache(_key_args_cache("Query", "book", '["isbn"]'))
    _ = write(
        cache,
        'query { book(junk: "ignored", isbn: "0465030793") { title } }',
        (
            '{"book": {"__typename": "Book", "isbn": "0465030793", "title": "I'
            ' Am a Strange Loop"}}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query",'
            ' "book:{\\"isbn\\":\\"0465030793\\"}": {"__typename": "Book",'
            ' "title": "I Am a Strange Loop"}}}'
        ),
    )


def test_can_filter_arguments_using_key_args_in_non_query_fields() raises:
    var config = _key_args_cache("Book", "author", '["firstName", "lastName"]')
    config.type_policies["Book"].key_fields = KeyFields.parse('["isbn"]')
    var author = TypePolicy()
    author.key_fields = KeyFields.parse('["name"]')
    config.type_policies["Author"] = author^
    var cache = InMemoryCache(config)
    var query = (
        'query { book { isbn title author(firstName: "Douglas" middleName:'
        ' "Richard" lastName: "Hofstadter") { name } } }'
    )
    var data = (
        '{"book": {"__typename": "Book", "isbn": "0465030793", "title": "I Am'
        ' a Strange Loop", "author": {"__typename": "Author", "name":'
        ' "Douglas Hofstadter"}}}'
    )
    _ = write(cache, query, data)
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "book": {"__ref":'
            ' "Book:{\\"isbn\\":\\"0465030793\\"}"}},'
            ' "Book:{\\"isbn\\":\\"0465030793\\"}": {"__typename": "Book",'
            ' "isbn": "0465030793", "title": "I Am a Strange Loop",'
            ' "author:{\\"firstName\\":\\"Douglas\\",\\"lastName\\":\\"Hofstadter\\"}":'
            ' {"__ref": "Author:{\\"name\\":\\"Douglas Hofstadter\\"}"}},'
            ' "Author:{\\"name\\":\\"Douglas Hofstadter\\"}": {"__typename":'
            ' "Author", "name": "Douglas Hofstadter"}}'
        ),
    )
    assert_read(cache, gql(query), data)


def read_a(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`a() { return "a" }`."""
    return options.cache[].values.add_string("a")


def read_b(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`read() { return "b" }`."""
    return options.cache[].values.add_string("b")


def merge_reverse(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`merge(existing, incoming) { return reverse(incoming) }`."""
    var source = text(options, incoming)
    var out = String("")
    var index = source.byte_length() - 1
    while index >= 0:
        out += String(source[byte = index : index + 1])
        index -= 1
    return options.cache[].values.add_string(out)


def key_d(args: Int, mut context: KeyArgsContext) raises -> String:
    """`keyArgs() { return "d" }`."""
    return "d"


def read_lower(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`read(existing) { return existing.toLowerCase() }`."""
    return options.cache[].values.add_string(text(options, existing).lower())


def merge_upper(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`merge(existing, incoming) { return incoming.toUpperCase() }`."""
    return options.cache[].values.add_string(text(options, incoming).upper())


def read_slice(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`read(existing) { return existing.slice(1) }`."""
    var source = text(options, existing)
    return options.cache[].values.add_string(String(source[byte=1:]))


def merge_star(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`merge(existing, incoming) { return "*" + incoming }`."""
    return options.cache[].values.add_string("*" + text(options, incoming))


def read_types(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """The `types` read function: each item's type follows the letters of
    the `from` and `to` arguments."""
    var start = ord(text(options, arg(options, "from")))
    var end = ord(text(options, arg(options, "to")))
    var index = 0
    var code = start
    while code <= end:
        var item = options.cache[].values.item(existing, index)
        var typename = options.read_field_from("__typename", item)
        assert_equal(text(options, typename), "Type" + chr(code).upper())
        index += 1
        code += 1
    return existing


def test_assumes_key_args_false_when_read_and_merge_are_present() raises:
    var config = InMemoryCacheConfig()
    add_field(config, "TypeA", "a", FieldPolicy(read_a))
    var b = FieldPolicy(read_b)
    b.key_args = KeyArgs.parse('["x"]')
    add_field(config, "TypeB", "b", b^)
    var c = FieldPolicy()
    c.key_args = KeyArgs.disabled()
    c.merge = Merge(merge_reverse)
    add_field(config, "TypeC", "c", c^)
    var d = FieldPolicy(read_lower)
    d.key_args = KeyArgs(key_d)
    d.merge = Merge(merge_upper)
    add_field(config, "TypeD", "d", d^)
    var e = FieldPolicy(read_slice)
    e.merge = Merge(merge_star)
    add_field(config, "TypeE", "e", e^)
    add_field(config, "TypeF", "f", FieldPolicy())
    add_field(config, "Query", "types", FieldPolicy(read_types))
    var cache = InMemoryCache(config)
    var query = (
        'query { types(from: "A", to: "F") { ... on TypeA { a } ... on TypeB'
        ' { b(x: 1, y: 2, z: 3) } ... on TypeC { c(see: "si") } ... on TypeD'
        ' { d } ... on TypeE { e(eee: "ee") } ... on TypeF { f(g: "h") } } }'
    )
    _ = write(
        cache,
        query,
        (
            '{"types": [{"__typename": "TypeA"}, {"__typename": "TypeB", "b":'
            ' "x1"}, {"__typename": "TypeC", "c": "naive"}, {"__typename":'
            ' "TypeD", "d": "quiet"}, {"__typename": "TypeE", "e": "asterisk"},'
            ' {"__typename": "TypeF", "f": "effigy"}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query",'
            ' "types({\\"from\\":\\"A\\",\\"to\\":\\"F\\"})": [{"__typename":'
            ' "TypeA"}, {"__typename": "TypeB", "b:{\\"x\\":1}": "x1"},'
            ' {"__typename": "TypeC", "c": "evian"}, {"__typename": "TypeD",'
            ' "d": "QUIET"}, {"__typename": "TypeE", "e": "*asterisk"},'
            ' {"__typename": "TypeF", "f({\\"g\\":\\"h\\"})": "effigy"}]}}'
        ),
    )
    assert_read(
        cache,
        gql(query),
        (
            '{"types": [{"__typename": "TypeA", "a": "a"}, {"__typename":'
            ' "TypeB", "b": "b"}, {"__typename": "TypeC", "c": "evian"},'
            ' {"__typename": "TypeD", "d": "quiet"}, {"__typename": "TypeE",'
            ' "e": "asterisk"}, {"__typename": "TypeF", "f": "effigy"}]}'
        ),
    )


comptime WRITINGS = (
    '{"author": {"__typename": "Author", "name": "Nadia Eghbal", "writings":'
    ' [{"__typename": "Book", "isbn": "0578675862", "title": "Working in'
    ' Public: The Making and Maintenance of Open Source Software"}]}}'
)
"""The data of "can include optional arguments in field keyArgs policy"."""


def _check_writings(
    mut cache: InMemoryCache, query: StringSlice, variables: StringSlice = "{}"
) raises:
    """Write the writings data with a query, and read it back."""
    _ = cache.write_query(gql(query), json(WRITINGS), json(variables))
    assert_read(cache, gql(query), WRITINGS, variables)


def same_writings(value: Int, mut details: ModifierDetails) raises -> Int:
    """The `writings` modifier: every stored value is the written array."""
    assert_equal(
        details.cache[].values.stringify(value),
        (
            '[{"__typename":"Book","title":"Working in Public: The Making and'
            ' Maintenance of Open Source Software","isbn":"0578675862"}]'
        ),
    )
    return value


def test_can_include_optional_arguments_in_a_key_args_policy() raises:
    var config = _key_args_cache("Author", "writings", '["a", "b", "type"]')
    config.type_policies["Author"].key_fields = KeyFields.parse('["name"]')
    var cache = InMemoryCache(config)
    var books = "{ ... on Book { title isbn } }"
    _check_writings(
        cache,
        'query { author { name writings(type: "Book") '
        + String(books)
        + " } }",
    )
    _check_writings(
        cache,
        'query { author { name writings(type: "Book", b: 2, a: 1) '
        + String(books)
        + " } }",
    )
    _check_writings(
        cache,
        "query { author { name writings(b: 2, a: 1) " + String(books) + " } }",
    )
    _check_writings(
        cache, "query { author { name writings(b: 2) " + String(books) + " } }"
    )
    _check_writings(
        cache, "query { author { name writings(a: 3) " + String(books) + " } }"
    )
    _check_writings(
        cache,
        'query { author { name writings(unrelated: "oyez") '
        + String(books)
        + " } }",
    )
    _check_writings(
        cache,
        "query AuthorWritings($type: String) { author { name writings(b: 4,"
        ' type: $type, unrelated: "oyez") '
        + String(books)
        + " } }",
    )
    _check_writings(
        cache, "query { author { name writings " + String(books) + " } }"
    )
    var book = (
        '[{"__typename":"Book","title":"Working in Public: The Making and'
        ' Maintenance of Open Source Software","isbn":"0578675862"}]'
    )
    assert_extract_exact(
        cache,
        '{"Author:{\\"name\\":\\"Nadia'
        ' Eghbal\\"}":{"__typename":"Author","name":"Nadia'
        ' Eghbal","writings:{\\"type\\":\\"Book\\"}":'
        + book
        + ',"writings:{\\"a\\":1,\\"b\\":2,\\"type\\":\\"Book\\"}":'
        + book
        + ',"writings:{\\"a\\":1,\\"b\\":2}":'
        + book
        + ',"writings:{\\"b\\":2}":'
        + book
        + ',"writings:{\\"a\\":3}":'
        + book
        + ',"writings:{}":'
        + book
        + ',"writings:{\\"b\\":4}":'
        + book
        + ',"writings":'
        + book
        + '},"ROOT_QUERY":{"__typename":"Query","author":{"__ref":"Author:{\\"name\\":\\"Nadia'
        ' Eghbal\\"}"}}}',
    )
    var fields = Dict[String, Modifier]()
    fields["writings"] = same_writings
    var id = cache.identify(
        json('{"__typename": "Author", "name": "Nadia Eghbal"}')
    )
    assert_false(cache.modify(fields, id))


def _directive_case(name: String) raises:
    """One case of "can refer to directive @name in field key shorthand
    array"."""
    var cache = InMemoryCache(
        _key_args_cache("Query", "feed", '["@' + name + '", ["key"], "arg"]')
    )
    var hello = (
        '[{"__typename": "Token", "text": "Hello"}, {"__typename": "Token",'
        ' "text": "World"}, {"__typename": "Token", "text": "!"}]'
    )
    _ = cache.write_query(
        gql(
            "query FeedQuery($num: Int) { feed(arg: $num) @"
            + name
            + '(key: "asdf", ignored: "boo") { text } }'
        ),
        json('{"feed": ' + hello + "}"),
        json('{"num": 1234}'),
    )
    var first = (
        '"feed:{\\"@' + name + '\\":{\\"key\\":\\"asdf\\"},\\"arg\\":1234}"'
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", ' + first + ": " + hello + "}}",
    )
    var farewell = (
        '[{"__typename": "Token", "text": "farewell"}, {"__typename":'
        ' "Token", "text": "cruel"}, {"__typename": "Token", "text":'
        ' "world"}]'
    )
    _ = cache.write_query(
        gql("query FeedQuery($num: Int) { feed(arg: $num) { text } }"),
        json('{"feed": ' + farewell + "}"),
        json('{"num": 2345}'),
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", '
        + first
        + ": "
        + hello
        + ', "feed:{\\"arg\\":2345}": '
        + farewell
        + "}}",
    )
    var directives = (
        '[{"__typename": "Token", "text": "directives"}, {"__typename":'
        ' "Token", "text": "consuming"}, {"__typename": "Token", "text":'
        ' "variables"}]'
    )
    _ = cache.write_query(
        gql(
            "query FeedQuery($num: Int) { feed @"
            + name
            + '(key: $num, ignored: "boo") { text } }'
        ),
        json('{"feed": ' + directives + "}"),
        json('{"num": 3456}'),
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", '
        + first
        + ": "
        + hello
        + ', "feed:{\\"arg\\":2345}": '
        + farewell
        + ', "feed:{\\"@'
        + name
        + '\\":{\\"key\\":3456}}": '
        + directives
        + "}}",
    )


def test_can_refer_to_directive_connection_in_a_key_array() raises:
    _directive_case("connection")


def test_can_refer_to_directive_directive_in_a_key_array() raises:
    _directive_case("directive")


def test_can_refer_to_directive_misdirective_in_a_key_array() raises:
    _directive_case("misdirective")


def read_default_num(
    existing: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`existing ?? args?.input ?? variables?.num`."""
    ref values = options.cache[].values
    if not _nullish(options, existing):
        return existing
    var input = values.get(options.args, "input")
    if not _nullish(options, input):
        return input
    return values.get(options.variables, "num")


def _nullish(mut options: FieldFunctionOptions, value: Int) -> Bool:
    """Return True for `null` and `undefined`."""
    var kind = options.cache[].values.kind(value)
    return kind == ValueKind.NULL or kind == ValueKind.UNDEFINED


def test_can_refer_to_variables_in_a_key_array() raises:
    var config = _key_args_cache(
        "Query", "defaultToNumVariable", '["input", "$num"]'
    )
    config.type_policies["Query"].fields[
        "defaultToNumVariable"
    ].read = read_default_num
    var cache = InMemoryCache(config)
    var with_input = (
        "query WithInputArg($num: Int) { defaultToNumVariable(input: 1234) }"
    )
    var no_args = "query WithInputArg($num: Int) { defaultToNumVariable }"
    _ = write(
        cache,
        with_input,
        '{"defaultToNumVariable": "forced with input and $num"}',
        '{"num": 1234}',
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query",'
            ' "defaultToNumVariable:{\\"input\\":1234,\\"$num\\":1234}":'
            ' "forced with input and $num"}}'
        ),
    )
    _ = write(
        cache,
        no_args,
        '{"defaultToNumVariable": "forced with only $num"}',
        '{"num": 2345}',
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query",'
            ' "defaultToNumVariable:{\\"input\\":1234,\\"$num\\":1234}":'
            ' "forced with input and $num",'
            ' "defaultToNumVariable:{\\"$num\\":2345}": "forced with only'
            ' $num"}}'
        ),
    )
    assert_read(
        cache,
        gql(with_input),
        '{"defaultToNumVariable": "forced with input and $num"}',
        '{"num": 1234}',
    )
    assert_read(
        cache,
        gql(no_args),
        '{"defaultToNumVariable": "forced with only $num"}',
        '{"num": 2345}',
    )
    assert_read(
        cache,
        gql(with_input),
        '{"defaultToNumVariable": 1234}',
        '{"num": 3456}',
    )
    assert_read(
        cache, gql(no_args), '{"defaultToNumVariable": 4567}', '{"num": 4567}'
    )


def read_full_name(
    existing: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`` `${readField("firstName")} ${readField("lastName")}` ``."""
    var first = text(options, options.read_field("firstName"))
    var last = text(options, options.read_field("lastName"))
    return options.cache[].values.add_string(first + " " + last)


def test_read_functions_can_implement_synthetic_keys() raises:
    var config = InMemoryCacheConfig()
    add_field(config, "Person", "fullName", FieldPolicy(read_full_name))
    config.type_policies["Person"].key_fields = KeyFields.parse(
        '["firstName", "lastName"]'
    )
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "query { me { firstName lastName } }",
        (
            '{"me": {"__typename": "Person", "firstName": "Ben", "lastName":'
            ' "Newman"}}'
        ),
    )
    var extraction = (
        '{"ROOT_QUERY": {"__typename": "Query", "me": {"__ref":'
        ' "Person:{\\"firstName\\":\\"Ben\\",\\"lastName\\":\\"Newman\\"}"}},'
        ' "Person:{\\"firstName\\":\\"Ben\\",\\"lastName\\":\\"Newman\\"}":'
        ' {"__typename": "Person", "firstName": "Ben", "lastName": "Newman"}}'
    )
    assert_extract(cache, extraction)
    var expected = '{"me": {"__typename": "Person", "fullName": "Ben Newman"}}'
    assert_read(cache, gql("query { me { fullName } }"), expected)
    assert_read(cache, gql("query { me { fullName @client } }"), expected)
    assert_extract(cache, extraction)


def read_is_canada(
    existing: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`readField("name") === "CA"`."""
    var name = options.read_field("name")
    return options.cache[].values.add_bool(
        options.cache[].values.text_equals(name, "CA")
    )


def read_code(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`read(_, { variables }) { return variables?.code }`."""
    return options.cache[].values.get(options.variables, "code")


def test_read_functions_get_the_correct_variables() raises:
    var config = InMemoryCacheConfig()
    add_field(config, "Country", "isCanada", FieldPolicy(read_is_canada))
    add_field(config, "Country", "name", FieldPolicy(read_code))
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "query Countries($code: ID!) { country(code: $code) { name } }",
        '{"country": {"__typename": "Country", "name": "CA"}}',
        '{"code": "CA"}',
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query",'
            ' "country({\\"code\\":\\"CA\\"})": {"__typename": "Country",'
            ' "name": "CA"}}}'
        ),
    )
    assert_read(
        cache,
        gql(
            "query Countries($code: ID!) { country(code: $code) { name"
            " isCanada @client } }"
        ),
        (
            '{"country": {"__typename": "Country", "name": "CA", "isCanada":'
            " true}}"
        ),
        '{"code": "CA"}',
    )


def merge_unique_books(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The `books` merge function: add the incoming books whose `isbn` is
    new."""
    ref values = options.cache[].values
    var merged = values.array_items(existing)
    var seen = List[String]()
    for book in merged:
        seen.append(text(options, options.read_field_from("isbn", book)))
    var index = 0
    while index < values.length(incoming):
        var book = values.item(incoming, index)
        var isbn = text(options, options.read_field_from("isbn", book))
        if isbn not in seen:
            seen.append(isbn)
            merged.append(book)
        index += 1
    return values.add_array(merged)


def read_sorted_books(
    existing: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The `books` read function: the books sorted by title."""
    ref values = options.cache[].values
    var books = values.array_items(existing)
    var position = 1
    while position < len(books):
        var current = books[position]
        var title = text(options, options.read_field_from("title", current))
        var back = position
        while back > 0 and title < text(
            options, options.read_field_from("title", books[back - 1])
        ):
            books[back] = books[back - 1]
            back -= 1
        books[back] = current
        position += 1
    return values.add_array(books)


comptime RUST = (
    '{"__typename": "Book", "isbn": "9781491927281", "title": "Programming'
    ' Rust: Fast, Safe Systems Development"}'
)
"""`programmingRustBook`."""
comptime OFFICIAL = (
    '{"__typename": "Book", "isbn": "1593278284", "title": "The Rust'
    ' Programming Language"}'
)
"""`officialRustBook`."""
comptime CONCURRENCY = (
    '{"__typename": "Book", "isbn": "1788399978", "title": "Hands-On'
    ' Concurrency with Rust"}'
)
"""`handsOnConcurrencyBook`."""
comptime WASM = (
    '{"__typename": "Book", "isbn": "1680506366", "title": "Programming'
    ' WebAssembly with Rust"}'
)
"""`wasmWithRustBook`."""


def _add_books(mut cache: InMemoryCache, books: StringSlice) raises:
    """`addBooks(...books)`."""
    _ = write(
        cache,
        "query { books { isbn title } }",
        '{"books": [' + String(books) + "]}",
    )


def test_merge_functions_can_deduplicate_items_using_read_field() raises:
    var config = InMemoryCacheConfig()
    var books = FieldPolicy(read_sorted_books)
    books.merge = Merge(merge_unique_books)
    add_field(config, "Query", "books", books^)
    var book = TypePolicy()
    book.key_fields = KeyFields.parse('["isbn"]')
    config.type_policies["Book"] = book^
    var cache = InMemoryCache(config)
    var official = '"Book:{\\"isbn\\":\\"1593278284\\"}"'
    var rust = '"Book:{\\"isbn\\":\\"9781491927281\\"}"'
    var wasm = '"Book:{\\"isbn\\":\\"1680506366\\"}"'
    var concurrency = '"Book:{\\"isbn\\":\\"1788399978\\"}"'
    _add_books(cache, OFFICIAL)
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "books": [{"__ref": '
        + official
        + "}]}, "
        + official
        + ": "
        + String(OFFICIAL)
        + "}",
    )
    _add_books(cache, String(RUST) + ", " + String(OFFICIAL))
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "books": [{"__ref": '
        + official
        + '}, {"__ref": '
        + rust
        + "}]}, "
        + official
        + ": "
        + String(OFFICIAL)
        + ", "
        + rust
        + ": "
        + String(RUST)
        + "}",
    )
    _add_books(
        cache,
        String(WASM)
        + ", "
        + String(WASM)
        + ", "
        + String(RUST)
        + ", "
        + String(WASM),
    )
    _add_books(
        cache,
        String(RUST)
        + ", "
        + String(OFFICIAL)
        + ", "
        + String(CONCURRENCY)
        + ", "
        + String(WASM),
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "books": [{"__ref": '
        + official
        + '}, {"__ref": '
        + rust
        + '}, {"__ref": '
        + wasm
        + '}, {"__ref": '
        + concurrency
        + "}]}, "
        + official
        + ": "
        + String(OFFICIAL)
        + ", "
        + rust
        + ": "
        + String(RUST)
        + ", "
        + wasm
        + ": "
        + String(WASM)
        + ", "
        + concurrency
        + ": "
        + String(CONCURRENCY)
        + "}",
    )
    assert_read(
        cache,
        gql("query { books { isbn title } }"),
        '{"books": ['
        + String(CONCURRENCY)
        + ", "
        + String(RUST)
        + ", "
        + String(WASM)
        + ", "
        + String(OFFICIAL)
        + "]}",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
