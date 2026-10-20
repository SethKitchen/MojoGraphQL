<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Stream

`gql_stream` is the streaming core of subscriptions. It has pull-based event streams, wakers, an epoll event loop, an in-process `PubSub`, and the stream combinators. It needs only `gql_json`.

The streams follow the Rust `Stream` and `Waker` model. There is no thread for each stream. An owner polls a stream. A stream that has no value yet keeps the waker, and it wakes the owner later.

```mojo
from gql_stream.event_loop import EventLoop
from gql_stream.poll import Event
from gql_stream.pubsub import PubSub


def main() raises:
    var pubsub = PubSub()
    var loop = EventLoop()
    var id = loop.add(pubsub.subscribe("EMAIL"))
    _ = loop.poll(0)  # The stream is PENDING.
    pubsub.publish("EMAIL", Event.parse('{"subject":"Hello"}'))
    _ = loop.poll(1000)
    print(loop.stream_events[0].id == id)
    print(loop.stream_events[0].poll.value().to_json())  # {"subject":"Hello"}
```

`PubSub` and `with_filter` port graphql-subscriptions 3.0.0. `MapStream` ports graphql-js 16.14.2 `mapAsyncIterator`. The other parts port no code.

## Events and polls

| Type | Module | What it is |
| --- | --- | --- |
| `Event` | `gql_stream.poll` | One JSON value: an `ArcPointer` to a `JsonDocument`, read-only |
| `PollState` | `gql_stream.poll` | `READY`, `PENDING`, `DONE` or `ERROR` |
| `Poll` | `gql_stream.poll` | The result of one poll: a state, an `event` and a `message` |
| `EventStream` | `gql_stream.poll` | The trait of a stream: `poll_next(waker)` and `close()` |

An `Event` is the root of its document. A copy of an event shares the document, so a copy costs one reference count. `Event.parse(text)` parses a JSON text. `to_json()` writes the value, and `same(other)` tells if two events share one document.

A GraphQL payload and a GraphQL response are both JSON values. Thus one event type serves the source streams and the response streams of subscriptions.

`Poll.ready(event)`, `Poll.pending()`, `Poll.done()` and `Poll.error(message)` make a poll. `value()` returns the event of a `READY` poll, and it raises for the other states.

## The EventStream contract

```mojo
trait EventStream(Deinitable, Movable):
    def poll_next(mut self, mut waker: Waker) -> Poll: ...
    def close(mut self): ...
```

| Result | JavaScript async iterator |
| --- | --- |
| `READY` with an event | `{ value, done: false }` |
| `PENDING` | A `next()` promise that has not settled |
| `DONE` | `{ value: undefined, done: true }` |
| `ERROR` with a message | A `next()` promise that rejects |

- `poll_next` must not wait. It returns at once.
- On `PENDING`, the stream keeps the waker. It must call `wake()` when it can make progress.
- After `DONE` or `ERROR`, each poll returns `DONE`.
- `close()` is `return()`. It frees what the stream holds, such as its subscriptions. It is idempotent, and later polls return `DONE`.

Mojo has no trait objects. `AnyStream(stream^)` boxes a stream of any type, so one list can hold streams of many types. `ListStream(events, error)` yields known events, then ends or fails. It is the Mojo form of an `async function*` generator.

## Wakers

A `WakeSet` is the ready set of one loop. It holds the ids of the ready streams, and a Linux `eventfd`. Many streams share the one descriptor, and the id tells them apart.

A `Waker` holds a reference to a `WakeSet` and one stream id.

| Method | Use |
| --- | --- |
| `wake()` | Put the id in the ready set |
| `id()` | The stream id |
| `will_wake(other)` | True when both wakers wake the same stream of the same set |
| `woken()` | True when the id is in the ready set now |
| `Waker.noop()` | A waker with its own set and no `eventfd`, to poll outside a loop |

The first wake after the loop took the ready ids writes the `eventfd` one time. Thus a blocked `epoll_wait` returns. A spurious wake is harmless: the loop polls the stream, and the stream returns `PENDING` again.

A `WakeSet` has no lock. Call `wake()` only on the thread of the loop.

## EventLoop

`EventLoop(max_events, budget)` opens an epoll instance and a `WakeSet`. The loop owns streams, and each stream has an id.

| Method | Use |
| --- | --- |
| `add(stream)` | Add a stream, or an `AnyStream`, and return its id; the next turn polls it |
| `cancel(id)` | Close a stream and remove it, as an unsubscribe does |
| `has(id)`, `stream_count()` | Read the streams |
| `waker(id)` | The waker of a stream id |
| `watch(fd, events)`, `modify(fd, events)`, `unwatch(fd)` | Watch a descriptor, level-triggered |
| `poll(timeout_ms)` | Run one turn |
| `run_ready()` | Poll the woken streams, with no wait |
| `fd()` | The epoll descriptor, for an outer loop |

A turn clears `stream_events` and `fd_events`. Then it waits in `epoll_wait`, and it polls each woken stream until the stream is `PENDING`. A turn does not block when a stream is woken already.

Each `StreamEvent` has the stream `id` and its `poll`, which is never `PENDING`. A stream leaves the loop after its `DONE` or `ERROR` result. Each `FdEvent` has the descriptor and its `EPOLL*` flags.

A stream gives at most `budget` results in one turn. Then it waits for the next turn, so one busy stream cannot starve the others.

Stop watching a descriptor before you close it. Mojo destroys a value after its last use, so keep the owner of a descriptor alive while the loop watches it.

### Embed a loop

- A `gql_http` `Server` has `epoll_fd()`. Watch it for `EPOLLIN`. When it is in `fd_events`, call `server.poll(0)`.
- An outer loop can watch `fd()` of an `EventLoop`. When it is readable, call `poll(0)` of the inner loop.

## PubSub

`PubSub` is graphql-subscriptions `PubSub`. Its copies share one engine.

| Method | graphql-subscriptions | Use |
| --- | --- | --- |
| `publish(trigger, payload)` | `publish` | Give the payload to each listener of the trigger, and wake it |
| `subscribe(trigger)` | `subscribe` | An iterator that listens from now on |
| `async_iterable_iterator(trigger)` | `asyncIterableIterator` | An iterator that subscribes on its first poll |
| `async_iterable_iterator(triggers)` | `asyncIterableIterator` | The same, for a list of triggers |
| `unsubscribe(sub_id)` | `unsubscribe` | Remove one subscription |
| `listener_count(trigger)` | `EventEmitter.listenerCount` | The count of listeners |

A `PubSubAsyncIterableIterator` is an `EventStream`. Its push queue holds the payloads that its owner did not pull yet. `subscription_ids()` gives its ids, and `queued()` gives the length of its queue. An iterator that its owner drops unsubscribes.

These things differ from graphql-subscriptions:

- Mojo has no closures, so a listener is always an iterator. `subscribe(trigger)` returns the iterator, not a promise of an id.
- `publish` and `subscribe` are synchronous.
- `throw()` is not ported, and there is no `EventEmitter` option.
- `unsubscribe` returns False for an id that has no subscription. Upstream throws.

## Combinators

| Function or type | Upstream | Use |
| --- | --- | --- |
| `map_stream(stream, function)` | graphql-js `mapAsyncIterator` | Map each value with a `MapFn` |
| `MapStream(stream, mapper)` | `mapAsyncIterator` | Map each value with a `Mapper` struct |
| `with_filter(stream, function)` | graphql-subscriptions `withFilter` | Yield the values that a `FilterFn` accepts |
| `FilterStream(stream, predicate)` | `withFilter` | Yield the values that a `Predicate` struct accepts |

When a mapper raises, `MapStream` closes its source and fails with the message. An error of the source passes through.

A predicate that raises skips the value, as upstream ignores the errors of the filter. A `Mapper` or a `Predicate` can carry state, such as the arguments of a field.

These things differ from upstream:

- `with_filter` takes the stream, not a resolver that makes the stream. Mojo has no closures.
- A filter gets the payload only. Upstream also gives the arguments, the context and the info.
- A filter and a mapper cannot be asynchronous.

## Tests

The tests are in `tests/gql_stream/`. `test_pubsub.mojo` ports `src/test/tests.ts` of graphql-subscriptions. `test_with_filter.mojo` ports the `withFilter` cases of `src/test/asyncIteratorSubscription.ts`. `test_map_async_iterator.mojo` ports graphql-js `mapAsyncIterator-test.ts`.

`test_event_loop.mojo` uses real `eventfd` and epoll descriptors and 5000 streams. It reaches the error paths with real failures, such as a low `RLIMIT_NOFILE` and an `EINTR`.

## Benchmarks

`bench/gql_stream/pubsub.mojo` runs `stream/pubsub-fanout-1000`. It publishes one event to 1000 iterators of an `EventLoop`, and reads each event. The baseline in `bench/baselines/js-stream` runs graphql-subscriptions 3.0.0 in Node.js with the same workload.

The [Benchmarks](Benchmarks) page tells how the project measures and gives the numbers.
