# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Apollo Client 4.3.3 `src/cache/inmemory/__tests__/policies.ts`,
part 3: `readField`, merges of nested and unidentified data, dangling
references, and the root types.

`test_policies.mojo` lists the upstream cases that are not ported. The
upstream counters of merge calls (`eventMergeCount` and the others) are
not kept: a thin Mojo function cannot hold state. The merge functions
check their arguments instead. In "readField helper function calls custom
read functions" the `ownTime` values come from a fixed table, because
upstream keeps them in reactive variables.
"""

from std.collections import Dict

from gql_client.cache import (
    FieldFunctionOptions,
    InMemoryCache,
    InMemoryCacheConfig,
    KeyArgsContext,
    KeyFieldsContext,
)
from gql_client.policies import (
    FieldPolicy,
    KeyArgs,
    KeyFields,
    Merge,
    TypePolicy,
)
from gql_client.values import (
    Member,
    NO_VALUE,
    NULL_VALUE,
    UNDEFINED_VALUE,
    ValueKind,
)
from gql_json.value import JsonDocument
from gql_language.ast import Document, NO_NODE
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
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
from _policy_helpers import add_field, arg, number, possible, text


# --- readField helper function calls custom read functions --------------


def task_count(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`readField("tasks").length`."""
    var tasks = options.read_field("tasks")
    return options.cache[].values.add_int(options.cache[].values.length(tasks))


def read_tasks(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`read(existing = []) { return existing }`."""
    if existing == NO_VALUE:
        return options.cache[].values.add_array(List[Int]())
    return existing


def append_items(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`[...(existing || []), ...incoming]`."""
    ref values = options.cache[].values
    var items = values.array_items(existing)
    items.extend(Span(values.array_items(incoming)))
    return values.add_array(items)


def _own_time(description: String) -> Int:
    """The first values of the `ownTimes` reactive variables."""
    if description == "parent task":
        return 2
    if description == "child task 1":
        return 3
    if description == "child task 2":
        return 4
    if description == "grandchild task":
        return 5
    return 11


def own_time(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`ownTimes[readField("description")]()`."""
    var description = text(options, options.read_field("description"))
    return options.cache[].values.add_int(_own_time(description))


def total_time(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """The `totalTime` read function: the own times of the task and of all
    the tasks that block it, each once."""
    var id = text(options, options.read_field("id"))
    var work = List[Int]()
    work.append(options.to_reference("Task:" + id))
    var seen = List[String]()
    var time = 0
    while len(work) > 0:
        var blocker = work.pop()
        var name = String(options.cache[].values.ref_text(blocker))
        if name in seen:
            continue
        seen.append(name)
        time += number(options, options.read_field_from("ownTime", blocker))
        var blockers = options.read_field_from("blockers", blocker)
        var index = options.cache[].values.length(blockers) - 1
        while index >= 0:
            work.append(options.cache[].values.item(blockers, index))
            index -= 1
    return options.cache[].values.add_int(time)


def merge_blockers(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The `blockers` merge function: add the incoming references that are
    new."""
    ref values = options.cache[].values
    var merged = values.array_items(existing)
    var seen = List[String]()
    for ref_value in merged:
        seen.append(String(values.ref_text(ref_value)))
    var index = 0
    while index < values.length(incoming):
        var item = values.item(incoming, index)
        var name = String(values.ref_text(item))
        if name not in seen:
            seen.append(name)
            merged.append(item)
        index += 1
    return values.add_array(merged)


def test_read_field_calls_custom_read_functions() raises:
    var config = InMemoryCacheConfig()
    add_field(config, "Agenda", "taskCount", FieldPolicy(task_count))
    var tasks = FieldPolicy(read_tasks)
    tasks.merge = Merge(append_items)
    add_field(config, "Agenda", "tasks", tasks^)
    add_field(config, "Task", "ownTime", FieldPolicy(own_time))
    add_field(config, "Task", "totalTime", FieldPolicy(total_time))
    var blockers = FieldPolicy()
    blockers.merge = Merge(merge_blockers)
    add_field(config, "Task", "blockers", blockers^)
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "query { agenda { id tasks { id description blockers { id } } } }",
        (
            '{"agenda": {"__typename": "Agenda", "id": 1, "tasks":'
            ' [{"__typename": "Task", "id": 1, "description": "parent task",'
            ' "blockers": [{"__typename": "Task", "id": 2}, {"__typename":'
            ' "Task", "id": 3}]}, {"__typename": "Task", "id": 2,'
            ' "description": "child task 1", "blockers": [{"__typename":'
            ' "Task", "id": 4}]}, {"__typename": "Task", "id": 3,'
            ' "description": "child task 2", "blockers": [{"__typename":'
            ' "Task", "id": 4}]}, {"__typename": "Task", "id": 4,'
            ' "description": "grandchild task"}]}}'
        ),
    )
    var tasks_part = (
        '"Task:1": {"__typename": "Task", "blockers": [{"__ref": "Task:2"},'
        ' {"__ref": "Task:3"}], "description": "parent task", "id": 1},'
        ' "Task:2": {"__typename": "Task", "blockers": [{"__ref": "Task:4"}],'
        ' "description": "child task 1", "id": 2}, "Task:3": {"__typename":'
        ' "Task", "blockers": [{"__ref": "Task:4"}], "description": "child'
        ' task 2", "id": 3}, "Task:4": {"__typename": "Task", "description":'
        ' "grandchild task", "id": 4}'
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "agenda": {"__ref":'
        ' "Agenda:1"}}, "Agenda:1": {"__typename": "Agenda", "id": 1,'
        ' "tasks": [{"__ref": "Task:1"}, {"__ref": "Task:2"}, {"__ref":'
        ' "Task:3"}, {"__ref": "Task:4"}]}, '
        + tasks_part
        + "}",
    )
    var query = gql(
        "query { agenda { taskCount tasks { description ownTime totalTime } } }"
    )
    var first_four = (
        '{"__typename": "Task", "description": "parent task", "ownTime": 2,'
        ' "totalTime": 14}, {"__typename": "Task", "description": "child task'
        ' 1", "ownTime": 3, "totalTime": 8}, {"__typename": "Task",'
        ' "description": "child task 2", "ownTime": 4, "totalTime": 9},'
        ' {"__typename": "Task", "description": "grandchild task", "ownTime":'
        ' 5, "totalTime": 5}'
    )
    assert_read(
        cache,
        query,
        '{"agenda": {"__typename": "Agenda", "taskCount": 4, "tasks": ['
        + first_four
        + "]}}",
    )
    _ = write(
        cache,
        "query { agenda { id tasks { id description } } }",
        (
            '{"agenda": {"__typename": "Agenda", "id": 1, "tasks":'
            ' [{"__typename": "Task", "id": 5, "description": "independent'
            ' task"}]}}'
        ),
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "agenda": {"__ref":'
        ' "Agenda:1"}}, "Agenda:1": {"__typename": "Agenda", "id": 1,'
        ' "tasks": [{"__ref": "Task:1"}, {"__ref": "Task:2"}, {"__ref":'
        ' "Task:3"}, {"__ref": "Task:4"}, {"__ref": "Task:5"}]}, '
        + tasks_part
        + ', "Task:5": {"__typename": "Task", "description": "independent'
        ' task", "id": 5}}',
    )
    assert_read(
        cache,
        query,
        '{"agenda": {"__typename": "Agenda", "taskCount": 5, "tasks": ['
        + first_four
        + ', {"__typename": "Task", "description": "independent task",'
        ' "ownTime": 11, "totalTime": 11}]}}',
    )


# --- can return void to indicate missing field ----------------------------


def read_nothing(
    existing: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`secret() {}`: return nothing."""
    return NO_VALUE


def test_can_return_void_to_indicate_a_missing_field() raises:
    var config = InMemoryCacheConfig()
    add_field(config, "Person", "secret", FieldPolicy(read_nothing))
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "query { me { name } }",
        '{"me": {"__typename": "Person", "name": "Ben Newman"}}',
    )
    var secret = gql("query { me { secret } }")
    assert_read(cache, secret, "null")
    var diff = cache.diff(secret, json("{}"), "ROOT_QUERY", False)
    var message = String(
        "Can't find field 'secret' on object {\n  \"__typename\":"
        ' "Person",\n  "name": "Ben Newman"\n}'
    )
    assert_false(diff.complete)
    assert_false(Bool(diff.result))
    assert_equal(diff.missing.value().message, message)
    var tree = JsonDocument()
    tree.root = tree.add_object()
    var me = tree.add_object()
    tree.add_member(me, "secret", tree.add_string(message))
    tree.add_member(tree.root, "me", me)
    assert_equal(text_of(diff.missing.value().missing), text_of(tree))


# --- can define custom merge functions and keyArgs simultaneously --------


def read_todos(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`existing.slice(args.offset, args.offset + args.limit)`; every item
    is a `Reference`."""
    var offset = number(options, arg(options, "offset"))
    var limit = number(options, arg(options, "limit"))
    ref values = options.cache[].values
    var items = List[Int]()
    var index = offset
    while index < offset + limit and index < values.length(existing):
        var item = values.item(existing, index)
        assert_true(options.is_reference(item))
        items.append(item)
        index += 1
    return values.add_array(items)


def merge_todos(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """Put the incoming todos at `args.offset`; every item is a
    `Reference`."""
    var offset = number(options, arg(options, "offset"))
    var limit = number(options, arg(options, "limit"))
    ref values = options.cache[].values
    var copy = values.array_items(existing)
    var index = offset
    while index < offset + limit:
        while len(copy) <= index:
            copy.append(UNDEFINED_VALUE)
        copy[index] = values.item(incoming, index - offset)
        index += 1
    for item in copy:
        if item != UNDEFINED_VALUE:
            assert_true(options.is_reference(item))
    return values.add_array(copy)


def test_custom_merge_functions_and_key_args_together() raises:
    var config = InMemoryCacheConfig()
    var todos = FieldPolicy(read_todos)
    todos.key_args = KeyArgs.parse("[]")
    todos.merge = Merge(merge_todos)
    add_field(config, "Person", "todos", todos^)
    config.type_policies["Person"].key_fields = KeyFields.disabled()
    var todo = TypePolicy()
    todo.key_fields = KeyFields.parse('["id"]')
    config.type_policies["Todo"] = todo^
    var cache = InMemoryCache(config)
    var query = (
        "query { me { todos(offset: $offset, limit: $limit) { text } } }"
    )
    _ = write(
        cache,
        query,
        (
            '{"me": {"__typename": "Person", "id": "ignored", "todos":'
            ' [{"__typename": "Todo", "id": 1, "text": "Write more merge'
            ' tests"}, {"__typename": "Todo", "id": 2, "text": "Write'
            ' pagination tests"}]}}'
        ),
        '{"offset": 0, "limit": 2}',
    )
    var one = (
        '"Todo:{\\"id\\":1}": {"__typename": "Todo", "id": 1, "text": "Write'
        ' more merge tests"}, "Todo:{\\"id\\":2}": {"__typename": "Todo",'
        ' "id": 2, "text": "Write pagination tests"}'
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "me": {"__typename":'
        ' "Person", "todos:{}": [{"__ref": "Todo:{\\"id\\":1}"}, {"__ref":'
        ' "Todo:{\\"id\\":2}"}]}}, '
        + one
        + "}",
    )
    _ = write(
        cache,
        query,
        (
            '{"me": {"__typename": "Person", "todos": [{"__typename": "Todo",'
            ' "id": 5, "text": "Submit pull request"}, {"__typename": "Todo",'
            ' "id": 6, "text": "Merge pull request"}]}}'
        ),
        '{"offset": 4, "limit": 2}',
    )
    var five = (
        '"Todo:{\\"id\\":5}": {"__typename": "Todo", "id": 5, "text": "Submit'
        ' pull request"}, "Todo:{\\"id\\":6}": {"__typename": "Todo", "id":'
        ' 6, "text": "Merge pull request"}'
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "me": {"__typename":'
        ' "Person", "todos:{}": [{"__ref": "Todo:{\\"id\\":1}"}, {"__ref":'
        ' "Todo:{\\"id\\":2}"}, null, null, {"__ref": "Todo:{\\"id\\":5}"},'
        ' {"__ref": "Todo:{\\"id\\":6}"}]}}, '
        + one
        + ", "
        + five
        + "}",
    )
    _ = write(
        cache,
        query,
        (
            '{"me": {"__typename": "Person", "todos": [{"__typename": "Todo",'
            ' "id": 3, "text": "Iron out merge API"}, {"__typename": "Todo",'
            ' "id": 4, "text": "Take a nap"}]}}'
        ),
        '{"offset": 2, "limit": 2}',
    )
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", "me": {"__typename":'
        ' "Person", "todos:{}": [{"__ref": "Todo:{\\"id\\":1}"}, {"__ref":'
        ' "Todo:{\\"id\\":2}"}, {"__ref": "Todo:{\\"id\\":3}"}, {"__ref":'
        ' "Todo:{\\"id\\":4}"}, {"__ref": "Todo:{\\"id\\":5}"}, {"__ref":'
        ' "Todo:{\\"id\\":6}"}]}}, '
        + one
        + ', "Todo:{\\"id\\":3}": {"__typename": "Todo", "id": 3, "text":'
        ' "Iron out merge API"}, "Todo:{\\"id\\":4}": {"__typename": "Todo",'
        ' "id": 4, "text": "Take a nap"}, '
        + five
        + "}",
    )
    assert_equal(len(cache.gc()), 0)
    assert_read(
        cache,
        gql(query),
        (
            '{"me": {"__typename": "Person", "todos": [{"__typename": "Todo",'
            ' "text": "Write pagination tests"}, {"__typename": "Todo", "text":'
            ' "Iron out merge API"}, {"__typename": "Todo", "text": "Take a'
            ' nap"}, {"__typename": "Todo", "text": "Submit pull request"}]}}'
        ),
        '{"offset": 1, "limit": 4}',
    )


# --- runs nested merge functions as well as ancestors ----------------------


def concat_arrays(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`existing ? existing.concat(incoming) : incoming`, with the check
    that `incoming` is an array."""
    assert_true(options.cache[].values.is_array(incoming))
    if existing == NO_VALUE:
        return incoming
    return append_items(existing, incoming, options)


def test_runs_nested_merge_functions_as_well_as_ancestors() raises:
    var config = InMemoryCacheConfig()
    var attendees = FieldPolicy()
    attendees.merge = Merge(concat_arrays)
    add_field(config, "Event", "attendees", attendees^)
    var events = FieldPolicy()
    events.merge = Merge(concat_arrays)
    add_field(config, "Attendee", "events", events^)
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "query { eventsToday { name attendees { name events { time } } } }",
        (
            '{"eventsToday": [{"__typename": "Event", "id": 123, "name":'
            ' "One-person party", "time": "noonish", "attendees":'
            ' [{"__typename": "Attendee", "id": 234, "name": "Ben Newman",'
            ' "events": [{"__typename": "Event", "id": 123}]}]}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "eventsToday": [{"__ref":'
            ' "Event:123"}]}, "Event:123": {"__typename": "Event", "id": 123,'
            ' "name": "One-person party", "attendees": [{"__ref":'
            ' "Attendee:234"}]}, "Attendee:234": {"__typename": "Attendee",'
            ' "id": 234, "name": "Ben Newman", "events": [{"__ref":'
            ' "Event:123"}]}}'
        ),
    )
    _ = write(
        cache,
        "query { people { name events { time attendees { name } } } }",
        (
            '{"people": [{"__typename": "Attendee", "id": 234, "name": "Ben'
            ' Newman", "events": [{"__typename": "Event", "id": 345, "name":'
            ' "Rooftop dog party", "attendees": [{"__typename": "Attendee",'
            ' "id": 456, "name": "Inspector Beckett"}, {"__typename":'
            ' "Attendee", "id": 234}]}]}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "eventsToday": [{"__ref":'
            ' "Event:123"}], "people": [{"__ref": "Attendee:234"}]},'
            ' "Event:123": {"__typename": "Event", "id": 123, "name":'
            ' "One-person party", "attendees": [{"__ref": "Attendee:234"}]},'
            ' "Event:345": {"__typename": "Event", "id": 345, "attendees":'
            ' [{"__ref": "Attendee:456"}, {"__ref": "Attendee:234"}]},'
            ' "Attendee:234": {"__typename": "Attendee", "id": 234, "name":'
            ' "Ben Newman", "events": [{"__ref": "Event:123"}, {"__ref":'
            ' "Event:345"}]}, "Attendee:456": {"__typename": "Attendee", "id":'
            ' 456, "name": "Inspector Beckett"}}'
        ),
    )
    assert_equal(len(cache.gc()), 0)


# --- should report dangling references returned by read functions ---------


def read_book_or_reference(
    existing: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`existing || toReference({ __typename: "Book", isbn: args.isbn })`."""
    if options.cache[].values.truthy(existing):
        return existing
    var isbn = options.cache[].values.stringify(arg(options, "isbn"))
    var object = json('{"__typename": "Book", "isbn": ' + isbn + "}")
    return options.to_reference(options.cache[].identify(object).value())


def _book_read(mut cache: InMemoryCache, isbn: String) raises -> String:
    """`read(isbn)`: the `readQuery` text."""
    var result = cache.read_query(
        gql("query { book(isbn: $isbn) { title author } }"),
        json('{"isbn": "' + isbn + '"}'),
    )
    if not result:
        return "null"
    return text_of(result.value())


def _assert_dangling(mut cache: InMemoryCache, isbn: String) raises:
    """`diff(isbn)` gives the dangling reference error."""
    var diff = cache.diff(
        gql("query { book(isbn: $isbn) { title author } }"),
        json('{"isbn": "' + isbn + '"}'),
        "ROOT_QUERY",
        False,
    )
    assert_false(diff.complete)
    assert_false(Bool(diff.result))
    var message = String(
        'Dangling reference to missing Book:{"isbn":"', isbn, '"} object'
    )
    assert_equal(diff.missing.value().message, message)
    var tree = JsonDocument()
    tree.root = tree.add_object()
    tree.add_member(tree.root, "book", tree.add_string(message))
    assert_equal(text_of(diff.missing.value().missing), text_of(tree))


def test_reports_dangling_references_returned_by_read_functions() raises:
    var config = InMemoryCacheConfig()
    var book_field = FieldPolicy(read_book_or_reference)
    book_field.key_args = KeyArgs.parse('["isbn"]')
    add_field(config, "Query", "book", book_field^)
    var book = TypePolicy()
    book.key_fields = KeyFields.parse('["isbn"]')
    config.type_policies["Book"] = book^
    var cache = InMemoryCache(config)
    var query = "query { book(isbn: $isbn) { title author } }"
    assert_equal(_book_read(cache, "156858217X"), "null")
    _ = write(
        cache,
        query,
        (
            '{"book": {"__typename": "Book", "isbn": "0393354326", "title":'
            ' "Guns, Germs, and Steel", "author": "Jared Diamond"}}'
        ),
        '{"isbn": "0393354326"}',
    )
    assert_equal(_book_read(cache, "156858217X"), "null")
    _assert_dangling(cache, "156858217X")
    var steal = (
        '{"__typename": "Book", "isbn": "156858217X", "title": "Steal This'
        ' Book", "author": "Abbie Hoffman"}'
    )
    var steal_id = cache.identify(json(steal)).value()
    _ = cache.write_fragment(
        gql("fragment BookTitleAuthor on Book { title author }"),
        json(steal),
        steal_id,
    )
    assert_equal(
        _book_read(cache, "156858217X"),
        (
            '{"book":{"__typename":"Book","title":"Steal This'
            ' Book","author":"Abbie Hoffman"}}'
        ),
    )
    assert_equal(
        _book_read(cache, "0393354326"),
        (
            '{"book":{"__typename":"Book","title":"Guns, Germs, and'
            ' Steel","author":"Jared Diamond"}}'
        ),
    )
    var guns = (
        '"Book:{\\"isbn\\":\\"0393354326\\"}": {"__typename": "Book", "isbn":'
        ' "0393354326", "author": "Jared Diamond", "title": "Guns, Germs, and'
        ' Steel"}'
    )
    var steal_entity = (
        '"Book:{\\"isbn\\":\\"156858217X\\"}": {"__typename": "Book", "isbn":'
        ' "156858217X", "author": "Abbie Hoffman", "title": "Steal This'
        ' Book"}'
    )
    var guns_root = (
        '"book:{\\"isbn\\":\\"0393354326\\"}": {"__ref":'
        ' "Book:{\\"isbn\\":\\"0393354326\\"}"}'
    )
    assert_extract(
        cache,
        '{"__META": {"extraRootIds": ["Book:{\\"isbn\\":\\"156858217X\\"}"]},'
        ' "ROOT_QUERY": {"__typename": "Query", '
        + guns_root
        + "}, "
        + guns
        + ", "
        + steal_entity
        + "}",
    )
    assert_equal(len(cache.gc()), 0)
    assert_equal(cache.release(steal_id), 0)
    var removed = cache.gc()
    assert_equal(len(removed), 1)
    assert_equal(removed[0], steal_id)
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", '
        + guns_root
        + "}, "
        + guns
        + "}",
    )
    _ = write(cache, query, '{"book": ' + steal + "}", '{"isbn": "156858217X"}')
    assert_extract(
        cache,
        '{"ROOT_QUERY": {"__typename": "Query", '
        + guns_root
        + ', "book:{\\"isbn\\":\\"156858217X\\"}": {"__ref":'
        ' "Book:{\\"isbn\\":\\"156858217X\\"}"}}, '
        + guns
        + ", "
        + steal_entity
        + "}",
    )
    assert_equal(len(cache.gc()), 0)
    assert_true(cache.evict(None, "book"))
    var collected = cache.gc()
    assert_equal(len(collected), 2)
    assert_true('Book:{"isbn":"0393354326"}' in collected)
    assert_true('Book:{"isbn":"156858217X"}' in collected)
    assert_extract(cache, '{"ROOT_QUERY": {"__typename": "Query"}}')
    assert_equal(_book_read(cache, "0393354326"), "null")
    _assert_dangling(cache, "0393354326")
    assert_equal(_book_read(cache, "156858217X"), "null")
    _assert_dangling(cache, "156858217X")


# --- can force merging of unidentified non-normalized data ----------------


def merge_books(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`booksMergePolicy()`: add the incoming references that are new, and
    every incoming object."""
    ref values = options.cache[].values
    var merged = values.array_items(existing)
    var seen = List[String]()
    for book in merged:
        if options.is_reference(book):
            seen.append(String(values.ref_text(book)))
    var index = 0
    while index < values.length(incoming):
        var book = values.item(incoming, index)
        if options.is_reference(book):
            var name = String(values.ref_text(book))
            if name not in seen:
                merged.append(book)
                seen.append(name)
        else:
            merged.append(book)
        index += 1
    return values.add_array(merged)


def merge_author_checked(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """The `Book.author` merge function, with its checks of
    `mergeObjects`."""
    assert_equal(options.merge_objects(NO_VALUE, NULL_VALUE), NULL_VALUE)
    ref values = options.cache[].values
    var first = values.add_array([values.add_int(1), values.add_int(2)])
    var second = values.add_array([values.add_int(4)])
    with assert_raises(contains="Cannot automatically merge arrays"):
        _ = options.merge_objects(first, second)
    var a = values.from_json(json('{"__typename": "A", "a": "ay"}'), 0)
    var b = values.from_json(json('{"__typename": "B", "a": "bee"}'), 0)
    assert_equal(options.merge_objects(a, b), b)
    assert_equal(options.merge_objects(b, a), a)
    return options.merge_objects(existing, incoming)


def _check_author(mut options: FieldFunctionOptions, value: Int) raises:
    """`checkAuthor`: an object whose `__typename` is `Author`."""
    ref values = options.cache[].values
    assert_true(values.is_object(value))
    assert_equal(text(options, values.get(value, "__typename")), "Author")


def spread_authors(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`{ ...existing, ...incoming }`, with `checkAuthor`."""
    if existing != NO_VALUE:
        _check_author(options, existing)
    _check_author(options, incoming)
    ref values = options.cache[].values
    var members = values.members(existing)
    var index = 0
    while index < values.length(incoming):
        var name = Int32(values.member_name(incoming, index))
        var value = Int32(values.member_value(incoming, index))
        var found = False
        for ref member in members:
            if member.name == name:
                member.value = value
                found = True
        if not found:
            members.append(Member(name, value))
        index += 1
    return values.add_object(members)


def _book_isbn_policy(mut config: InMemoryCacheConfig):
    """`Book: { keyFields: ["isbn"] }`."""
    if "Book" not in config.type_policies:
        config.type_policies["Book"] = TypePolicy()
    try:
        config.type_policies["Book"].key_fields = KeyFields.parse('["isbn"]')
    except:
        pass


def _author_books(mut config: InMemoryCacheConfig, normalized: Bool):
    """`Author: { keyFields: false?, fields: { books: booksMergePolicy() } }`.
    """
    var books = FieldPolicy()
    books.merge = Merge(merge_books)
    add_field(config, "Author", "books", books^)
    if not normalized:
        try:
            config.type_policies["Author"].key_fields = KeyFields.disabled()
        except:
            pass


def _test_force_merges(mut cache: InMemoryCache) raises:
    """`testForceMerges(cache)`."""
    var with_name = "query { currentlyReading { isbn title author { name } } }"
    var with_books = (
        "query { currentlyReading { isbn author { books { isbn title } } } }"
    )
    _ = write(
        cache,
        with_name,
        (
            '{"currentlyReading": {"__typename": "Book", "isbn": "1250758009",'
            ' "title": "The Topeka School", "author": {"__typename": "Author",'
            ' "name": "Ben Lerner"}}}'
        ),
    )
    var root = (
        '"ROOT_QUERY": {"__typename": "Query", "currentlyReading": {"__ref":'
        ' "Book:{\\"isbn\\":\\"1250758009\\"}"}}'
    )
    assert_extract(
        cache,
        "{"
        + root
        + ', "Book:{\\"isbn\\":\\"1250758009\\"}": {"__typename": "Book",'
        ' "author": {"__typename": "Author", "name": "Ben Lerner"}, "isbn":'
        ' "1250758009", "title": "The Topeka School"}}',
    )
    _ = write(
        cache,
        with_books,
        (
            '{"currentlyReading": {"__typename": "Book", "isbn": "1250758009",'
            ' "author": {"__typename": "Author", "books": [{"__typename":'
            ' "Book", "isbn": "1250758009", "title": "The Topeka School"}]}}}'
        ),
    )
    assert_extract(
        cache,
        "{"
        + root
        + ', "Book:{\\"isbn\\":\\"1250758009\\"}": {"__typename": "Book",'
        ' "author": {"__typename": "Author", "name": "Ben Lerner", "books":'
        ' [{"__ref": "Book:{\\"isbn\\":\\"1250758009\\"}"}]}, "isbn":'
        ' "1250758009", "title": "The Topeka School"}}',
    )
    _ = write(
        cache,
        with_books,
        (
            '{"currentlyReading": {"__typename": "Book", "isbn": "1250758009",'
            ' "author": {"__typename": "Author", "books": [{"__typename":'
            ' "Book", "isbn": "1566892740", "title": "Leaving the Atocha'
            ' Station"}]}}}'
        ),
    )
    assert_extract(
        cache,
        "{"
        + root
        + ', "Book:{\\"isbn\\":\\"1250758009\\"}": {"__typename": "Book",'
        ' "author": {"__typename": "Author", "name": "Ben Lerner", "books":'
        ' [{"__ref": "Book:{\\"isbn\\":\\"1250758009\\"}"}, {"__ref":'
        ' "Book:{\\"isbn\\":\\"1566892740\\"}"}]}, "isbn": "1250758009",'
        ' "title": "The Topeka School"}, "Book:{\\"isbn\\":\\"1566892740\\"}":'
        ' {"__typename": "Book", "isbn": "1566892740", "title": "Leaving the'
        ' Atocha Station"}}',
    )
    assert_read(
        cache,
        gql(with_books),
        (
            '{"currentlyReading": {"__typename": "Book", "isbn": "1250758009",'
            ' "author": {"__typename": "Author", "books": [{"__typename":'
            ' "Book", "isbn": "1250758009", "title": "The Topeka School"},'
            ' {"__typename": "Book", "isbn": "1566892740", "title": "Leaving'
            ' the Atocha Station"}]}}}'
        ),
    )
    assert_read(
        cache,
        gql(with_name),
        (
            '{"currentlyReading": {"__typename": "Book", "isbn": "1250758009",'
            ' "title": "The Topeka School", "author": {"__typename": "Author",'
            ' "name": "Ben Lerner"}}}'
        ),
    )


def test_can_force_merging_of_unidentified_data() raises:
    var config = InMemoryCacheConfig()
    var author = FieldPolicy()
    author.merge = Merge(merge_author_checked)
    add_field(config, "Book", "author", author^)
    _book_isbn_policy(config)
    _author_books(config, False)
    var cache = InMemoryCache(config)
    _test_force_merges(cache)


def test_can_force_merging_with_a_merge_true_field_policy() raises:
    var config = InMemoryCacheConfig()
    var author = FieldPolicy()
    author.merge = Merge(True)
    add_field(config, "Book", "author", author^)
    _book_isbn_policy(config)
    _author_books(config, False)
    var cache = InMemoryCache(config)
    _test_force_merges(cache)


def test_can_force_merging_with_a_merge_true_type_policy() raises:
    var config = InMemoryCacheConfig()
    _book_isbn_policy(config)
    _author_books(config, False)
    config.type_policies["Author"].merge = Merge(True)
    var cache = InMemoryCache(config)
    _test_force_merges(cache)


def test_can_force_merging_with_an_inherited_merge_true_field_policy() raises:
    var config = InMemoryCacheConfig()
    var author = FieldPolicy()
    author.merge = Merge(True)
    add_field(config, "Authored", "author", author^)
    _book_isbn_policy(config)
    _author_books(config, False)
    possible(config, "Authored", ["Book", "Destruction"])
    var cache = InMemoryCache(config)
    _test_force_merges(cache)


def test_can_force_merging_with_an_inherited_merge_true_type_policy() raises:
    var config = InMemoryCacheConfig()
    _book_isbn_policy(config)
    _author_books(config, True)
    var person = TypePolicy()
    person.key_fields = KeyFields.disabled()
    person.merge = Merge(True)
    config.type_policies["Person"] = person^
    possible(config, "Person", ["Author"])
    var cache = InMemoryCache(config)
    _test_force_merges(cache)


def test_can_force_merging_with_an_inherited_type_merge_function() raises:
    var config = InMemoryCacheConfig()
    _book_isbn_policy(config)
    _author_books(config, True)
    var person = TypePolicy()
    person.key_fields = KeyFields.disabled()
    person.merge = Merge(spread_authors)
    config.type_policies["Person"] = person^
    possible(config, "Person", ["Author"])
    var cache = InMemoryCache(config)
    _test_force_merges(cache)


def test_can_force_merging_with_an_inherited_field_merge_function() raises:
    var config = InMemoryCacheConfig()
    _book_isbn_policy(config)
    var author = FieldPolicy()
    author.merge = Merge(spread_authors)
    add_field(config, "Authored", "author", author^)
    _author_books(config, True)
    var person = TypePolicy()
    person.key_fields = KeyFields.disabled()
    config.type_policies["Person"] = person^
    possible(config, "Authored", ["Destiny", "Book"])
    possible(config, "Person", ["Author"])
    var cache = InMemoryCache(config)
    _test_force_merges(cache)


def _check_viewer(mut cache: InMemoryCache) raises:
    """The `check(cache)` of "can force merging references with
    non-normalized objects"."""
    var name_query = "query GetName { viewer { name } }"
    var email_query = "query GetEmail { viewer { id email } }"
    var alice = '{"viewer": {"__typename": "User", "name": "Alice"}}'
    var email = (
        '{"viewer": {"__typename": "User", "id": 12345, "email":'
        ' "alice@example.com"}}'
    )
    _ = write(cache, name_query, alice)
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "viewer": {"__typename":'
            ' "User", "name": "Alice"}}}'
        ),
    )
    _ = write(cache, email_query, email)
    var merged = (
        '{"ROOT_QUERY": {"__typename": "Query", "viewer": {"__ref":'
        ' "User:12345"}}, "User:12345": {"__typename": "User", "name":'
        ' "Alice", "id": 12345, "email": "alice@example.com"}}'
    )
    assert_extract(cache, merged)
    assert_read(cache, gql(name_query), alice)
    assert_read(cache, gql(email_query), email)
    cache.reset()
    assert_extract(cache, "{}")
    _ = write(cache, email_query, email)
    assert_extract(
        cache,
        (
            '{"User:12345": {"id": 12345, "__typename": "User", "email":'
            ' "alice@example.com"}, "ROOT_QUERY": {"__typename": "Query",'
            ' "viewer": {"__ref": "User:12345"}}}'
        ),
    )
    _ = write(cache, name_query, alice)
    assert_extract(cache, merged)
    assert_read(cache, gql(name_query), alice)
    assert_read(cache, gql(email_query), email)


def test_can_force_merging_references_with_non_normalized_objects() raises:
    var config = InMemoryCacheConfig()
    var viewer = FieldPolicy()
    viewer.merge = Merge(True)
    add_field(config, "Query", "viewer", viewer^)
    var first = InMemoryCache(config)
    _check_viewer(first)
    var by_type = InMemoryCacheConfig()
    var user = TypePolicy()
    user.merge = Merge(True)
    by_type.type_policies["User"] = user^
    var second = InMemoryCache(by_type)
    _check_viewer(second)


# --- runs read and merge functions for unidentified data -------------------


def _reverse(source: String) -> String:
    """Reverse a string, byte by byte (the names are ASCII)."""
    var out = String("")
    var index = source.byte_length() - 1
    while index >= 0:
        out += String(source[byte = index : index + 1])
        index -= 1
    return out^


def read_reversed_upper(
    existing: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`reverse(name).toUpperCase()`."""
    return options.cache[].values.add_string(
        _reverse(text(options, existing)).upper()
    )


def merge_reversed(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`reverse(newName)`, with the check that there is no old name."""
    assert_equal(existing, NO_VALUE)
    assert_equal(options.cache[].values.kind(incoming), ValueKind.STRING)
    return options.cache[].values.add_string(_reverse(text(options, incoming)))


def test_runs_read_and_merge_functions_for_unidentified_data() raises:
    var config = InMemoryCacheConfig()
    _book_isbn_policy(config)
    var name = FieldPolicy(read_reversed_upper)
    name.merge = Merge(merge_reversed)
    add_field(config, "Author", "name", name^)
    config.type_policies["Author"].key_fields = KeyFields.disabled()
    var cache = InMemoryCache(config)
    var query = "query { currentlyReading { title authors { name } } }"
    _ = write(
        cache,
        query,
        (
            '{"currentlyReading": [{"__typename": "Book", "isbn": "0525558616",'
            ' "title": "Human Compatible: Artificial Intelligence and the'
            ' Problem of Control", "authors": [{"__typename": "Author", "name":'
            ' "Stuart Russell"}]}, {"__typename": "Book", "isbn": "1541698967",'
            ' "title": "The Book of Why: The New Science of Cause and Effect",'
            ' "authors": [{"__typename": "Author", "name": "Judea Pearl"},'
            ' {"__typename": "Author", "name": "Dana Mackenzie"}]}]}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "currentlyReading":'
            ' [{"__ref": "Book:{\\"isbn\\":\\"0525558616\\"}"}, {"__ref":'
            ' "Book:{\\"isbn\\":\\"1541698967\\"}"}]},'
            ' "Book:{\\"isbn\\":\\"0525558616\\"}": {"__typename": "Book",'
            ' "isbn": "0525558616", "authors": [{"__typename": "Author",'
            ' "name": "llessuR trautS"}], "title": "Human Compatible:'
            ' Artificial Intelligence and the Problem of Control"},'
            ' "Book:{\\"isbn\\":\\"1541698967\\"}": {"__typename": "Book",'
            ' "isbn": "1541698967", "authors": [{"__typename": "Author",'
            ' "name": "lraeP aeduJ"}, {"__typename": "Author", "name":'
            ' "eiznekcaM anaD"}], "title": "The Book of Why: The New Science of'
            ' Cause and Effect"}}'
        ),
    )
    assert_read(
        cache,
        gql(query),
        (
            '{"currentlyReading": [{"__typename": "Book", "title": "Human'
            ' Compatible: Artificial Intelligence and the Problem of Control",'
            ' "authors": [{"__typename": "Author", "name": "STUART RUSSELL"}]},'
            ' {"__typename": "Book", "title": "The Book of Why: The New Science'
            ' of Cause and Effect", "authors": [{"__typename": "Author",'
            ' "name": "JUDEA PEARL"}, {"__typename": "Author", "name": "DANA'
            ' MACKENZIE"}]}]}'
        ),
    )


# --- allows keyFields and keyArgs functions to return false --------------


def no_key(mut context: KeyFieldsContext) raises -> String:
    """`keyFields() { return false }`; the empty string is no id."""
    return ""


def no_key_args(args: Int, mut context: KeyArgsContext) raises -> String:
    """`keyArgs() { return false }`; the empty string is the field name."""
    return ""


def merge_height(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """Keep feet; convert meters to feet."""
    var units = text(options, arg(options, "units"))
    if units == "feet":
        return incoming
    if units == "meters":
        var meters = atof(text(options, incoming))
        return options.cache[].values.add_float(meters * 3.28084)
    raise Error("unexpected units: " + units)


def test_key_fields_and_key_args_functions_can_return_false() raises:
    var config = InMemoryCacheConfig()
    var height = FieldPolicy()
    height.key_args = KeyArgs(no_key_args)
    height.merge = Merge(merge_height)
    add_field(config, "Person", "height", height^)
    config.type_policies["Person"].key_fields = KeyFields(no_key)
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "query GetUser($units: string) { people { id height(units: $units) } }",
        (
            '{"people": [{"__typename": "Person", "id": 12345, "height": 1.75},'
            ' {"__typename": "Person", "id": 23456, "height": 2}]}'
        ),
        '{"units": "meters"}',
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "people": [{"__typename":'
            ' "Person", "height": 5.74147, "id": 12345}, {"__typename":'
            ' "Person", "height": 6.56168, "id": 23456}]}}'
        ),
    )


# --- can read from foreign references using read helper ------------------


def first_book(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """The book with the earliest year, as a `Reference`."""
    var books = options.read_field("books")
    var found = NULL_VALUE
    var first_year = 0
    var index = 0
    while index < options.cache[].values.length(books):
        var book = options.cache[].values.item(books, index)
        assert_true(options.is_reference(book))
        var year = number(options, options.read_field_from("year", book))
        if found == NULL_VALUE or year < first_year:
            found = book
            first_year = year
        index += 1
    return found


def _add_book(mut cache: InMemoryCache, book: StringSlice) raises:
    """`addBook(bookData)`."""
    _ = write(
        cache,
        "query { author { name books { isbn title year } } }",
        '{"author": {"__typename": "Author", "name": "Virginia Woolf",'
        ' "books": ['
        + String(book)
        + "]}}",
    )


def test_can_read_from_foreign_references_using_read_field() raises:
    var config = InMemoryCacheConfig()
    var books = FieldPolicy()
    books.merge = Merge(append_items)
    add_field(config, "Author", "books", books^)
    add_field(config, "Author", "firstBook", FieldPolicy(first_book))
    config.type_policies["Author"].key_fields = KeyFields.parse('["name"]')
    _book_isbn_policy(config)
    var cache = InMemoryCache(config)
    _add_book(
        cache,
        (
            '{"__typename": "Book", "isbn": "1853262390", "title": "Orlando",'
            ' "year": 1928}'
        ),
    )
    _add_book(
        cache,
        (
            '{"__typename": "Book", "isbn": "9353420717", "title": "A Room of'
            ' One\'s Own", "year": 1929}'
        ),
    )
    _add_book(
        cache,
        (
            '{"__typename": "Book", "isbn": "0156907399", "title": "To the'
            ' Lighthouse", "year": 1927}'
        ),
    )
    assert_extract(
        cache,
        (
            '{"ROOT_QUERY": {"__typename": "Query", "author": {"__ref":'
            ' "Author:{\\"name\\":\\"Virginia Woolf\\"}"}},'
            ' "Author:{\\"name\\":\\"Virginia Woolf\\"}": {"__typename":'
            ' "Author", "name": "Virginia Woolf", "books": [{"__ref":'
            ' "Book:{\\"isbn\\":\\"1853262390\\"}"}, {"__ref":'
            ' "Book:{\\"isbn\\":\\"9353420717\\"}"}, {"__ref":'
            ' "Book:{\\"isbn\\":\\"0156907399\\"}"}]},'
            ' "Book:{\\"isbn\\":\\"1853262390\\"}": {"__typename": "Book",'
            ' "isbn": "1853262390", "title": "Orlando", "year": 1928},'
            ' "Book:{\\"isbn\\":\\"9353420717\\"}": {"__typename": "Book",'
            ' "isbn": "9353420717", "title": "A Room of One\'s Own", "year":'
            ' 1929}, "Book:{\\"isbn\\":\\"0156907399\\"}": {"__typename":'
            ' "Book", "isbn": "0156907399", "title": "To the Lighthouse",'
            ' "year": 1927}}'
        ),
    )
    var query = gql("query { author { name firstBook { title year } } }")
    assert_read(
        cache,
        query,
        (
            '{"author": {"__typename": "Author", "name": "Virginia Woolf",'
            ' "firstBook": {"__typename": "Book", "title": "To the Lighthouse",'
            ' "year": 1927}}}'
        ),
    )
    _add_book(
        cache,
        (
            '{"__typename": "Book", "isbn": "1420959719", "title": "The Voyage'
            ' Out", "year": 1915}'
        ),
    )
    var voyage = (
        '{"author": {"__typename": "Author", "name": "Virginia Woolf",'
        ' "firstBook": {"__typename": "Book", "title": "The Voyage Out",'
        ' "year": 1915}}}'
    )
    assert_read(cache, query, voyage)
    _ = write(
        cache,
        "query { author { afraidCount } }",
        (
            '{"author": {"__typename": "Author", "name": "Virginia Woolf",'
            ' "afraidCount": 2}}'
        ),
    )
    var id = cache.identify(
        json('{"__typename": "Author", "name": "Virginia Woolf"}')
    )
    var afraid = cache.read_fragment(
        gql("fragment AfraidFragment on Author { name afraidCount }"),
        id.value(),
    )
    assert_json(
        afraid.value(),
        '{"__typename": "Author", "name": "Virginia Woolf", "afraidCount": 2}',
    )
    assert_read(cache, query, voyage)
    _add_book(
        cache,
        (
            '{"__typename": "Book", "isbn": "9780156949606", "title": "The'
            ' Waves", "year": 1931}'
        ),
    )
    assert_read(cache, query, voyage)


# --- readField can read fields with arguments -----------------------------


def read_style(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """The `style` read function: the text in the style of `args.style`."""
    var word = text(options, options.read_field("text"))
    var style = number(options, arg(options, "style"))
    if style == 0:
        return options.cache[].values.add_string(word.upper())
    if style == 1:
        return options.cache[].values.add_string(word.lower())
    var title = String(word[byte=:1]).upper() + String(word[byte=1:]).lower()
    return options.cache[].values.add_string(title)


def _styled(mut options: FieldFunctionOptions, style: Int) raises -> Int:
    """`readField({ fieldName: "style", args: { style } })`."""
    var empty = Document()
    var members = List[Member]()
    ref values = options.cache[].values
    members.append(
        Member(
            Int32(values.names.intern("style")), Int32(values.add_int(style))
        )
    )
    var args = values.add_object(members)
    return options.cache[].read_field(
        "style",
        empty,
        NO_NODE,
        options.variables,
        options.from_object,
        args,
        True,
    )


def read_upper(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`upperCase`: the `style` field with `style: UPPER`."""
    return _styled(options, 0)


def read_lower(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`lowerCase`: the `style` field with `style: LOWER`."""
    return _styled(options, 1)


def read_title(existing: Int, mut options: FieldFunctionOptions) raises -> Int:
    """`titleCase`: the `style` field with `style: TITLE`."""
    return _styled(options, 2)


def test_read_field_can_read_fields_with_arguments() raises:
    var config = InMemoryCacheConfig()
    add_field(config, "Word", "style", FieldPolicy(read_style))
    add_field(config, "Word", "upperCase", FieldPolicy(read_upper))
    add_field(config, "Word", "lowerCase", FieldPolicy(read_lower))
    add_field(config, "Word", "titleCase", FieldPolicy(read_title))
    config.type_policies["Word"].key_fields = KeyFields.parse('["text"]')
    var cache = InMemoryCache(config)
    _ = write(
        cache,
        "query { wordOfTheDay { text } }",
        '{"wordOfTheDay": {"__typename": "Word", "text": "inveigle"}}',
    )
    assert_read(
        cache,
        gql("query { wordOfTheDay { upperCase lowerCase titleCase } }"),
        (
            '{"wordOfTheDay": {"__typename": "Word", "upperCase": "INVEIGLE",'
            ' "lowerCase": "inveigle", "titleCase": "Inveigle"}}'
        ),
    )


# --- can return existing object from merge function (issue #6245) --------


def prefer_existing(
    existing: Int, incoming: Int, mut options: FieldFunctionOptions
) raises -> Int:
    """`existing || incoming`."""
    if options.cache[].values.truthy(existing):
        return existing
    return incoming


def test_can_return_the_existing_object_from_a_merge_function() raises:
    var config = InMemoryCacheConfig()
    var task = FieldPolicy()
    task.merge = Merge(prefer_existing)
    add_field(config, "Person", "currentTask", task^)
    var task_type = TypePolicy()
    task_type.key_fields = KeyFields.disabled()
    config.type_policies["Task"] = task_type^
    var cache = InMemoryCache(config)
    var query = "query { person { currentTask { __typename description } } }"
    _ = write(
        cache,
        query,
        (
            '{"person": {"__typename": "Person", "id": 1234, "currentTask":'
            ' {"__typename": "Task", "description": "writing tests"}}}'
        ),
    )
    var snapshot = cache.extract()
    assert_extract(
        cache,
        (
            '{"Person:1234": {"__typename": "Person", "id": 1234,'
            ' "currentTask": {"__typename": "Task", "description": "writing'
            ' tests"}}, "ROOT_QUERY": {"__typename": "Query", "person":'
            ' {"__ref": "Person:1234"}}}'
        ),
    )
    _ = write(
        cache,
        query,
        (
            '{"person": {"__typename": "Person", "id": 1234, "currentTask":'
            ' {"__typename": "Task", "description": "polishing knives"}}}'
        ),
    )
    assert_equal(cache.extract(), snapshot)


# --- root types ---------------------------------------------------------


def test_can_alter_the_root_query_typename() raises:
    var config = InMemoryCacheConfig()
    var root = TypePolicy()
    root.query_type = True
    config.type_policies["RootQuery"] = root^
    var cache = InMemoryCache(config)
    assert_read_exact(
        cache, gql("query { __typename }"), '{"__typename":"RootQuery"}'
    )
    var all_items = gql("query Items { __typename items { id query { id } } }")
    _ = cache.write_query(
        all_items,
        json(
            '{"__typename": "RootQuery", "items": [{"id": 0, "query":'
            ' {"__typename": "Query", "id": 0}}, {"id": 1, "query":'
            ' {"__typename": "Query", "id": 1}}, {"id": 2, "query":'
            ' {"__typename": "Query", "id": 2}}, {"id": 3, "query":'
            ' {"__typename": "Query", "id": 3}}]}'
        ),
    )
    # The expected texts are the Node.js output of Apollo Client 4.3.3.
    assert_extract_exact(
        cache,
        '{"Query:0":{"__typename":"Query","id":0},"Query:1":{"__typename":"Query","id":1},"Query:2":{"__typename":"Query","id":2},"Query:3":{"__typename":"Query","id":3},"ROOT_QUERY":{"__typename":"RootQuery","items":[{"id":0,"query":{"__ref":"Query:0"}},{"id":1,"query":{"__ref":"Query:1"}},{"id":2,"query":{"__ref":"Query:2"}},{"id":3,"query":{"__ref":"Query:3"}}]}}',
    )
    assert_read_exact(
        cache,
        all_items,
        '{"__typename":"RootQuery","items":[{"id":0,"query":{"__typename":"Query","id":0}},{"id":1,"query":{"__typename":"Query","id":1}},{"id":2,"query":{"__typename":"Query","id":2}},{"id":3,"query":{"__typename":"Query","id":3}}]}',
    )


def test_can_configure_query_mutation_and_subscription_types() raises:
    var config = InMemoryCacheConfig()
    var query = TypePolicy()
    query.query_type = True
    config.type_policies["RootQuery"] = query^
    var mutation = TypePolicy()
    mutation.mutation_type = True
    config.type_policies["RootMutation"] = mutation^
    var subscription = TypePolicy()
    subscription.subscription_type = True
    config.type_policies["RootSubscription"] = subscription^
    var cache = InMemoryCache(config)
    assert_read(
        cache, gql("query { __typename }"), '{"__typename": "RootQuery"}'
    )
    var mutation_result = cache.read_fragment(
        gql("fragment MutationTypename on RootMutation { __typename }"),
        "ROOT_MUTATION",
    )
    assert_json(mutation_result.value(), '{"__typename": "RootMutation"}')
    var subscription_result = cache.read_fragment(
        gql("fragment SubscriptionTypename on RootSubscription { __typename }"),
        "ROOT_SUBSCRIPTION",
    )
    assert_json(
        subscription_result.value(), '{"__typename": "RootSubscription"}'
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
