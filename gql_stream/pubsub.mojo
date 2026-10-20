# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""An in-process publish and subscribe engine.

Port of graphql-subscriptions 3.0.0 `src/pubsub.ts`, `src/pubsub-engine.ts`
and `src/pubsub-async-iterable-iterator.ts`. `publish(trigger, payload)`
gives the payload to each listener of the trigger, in the order of their
subscriptions, and wakes each iterator that waits. A
`PubSubAsyncIterableIterator` is an `EventStream`: its push queue holds
the payloads that its owner has not pulled yet.

A `PubSub` is a handle: its copies share one engine. An iterator also
shares it, so the engine lives while an iterator does.

Differences from upstream:

- Mojo has no closures, so a listener is always an iterator.
  `subscribe(trigger)` returns an iterator that is subscribed already,
  not a promise of a subscription id. The ids are in
  `subscription_ids()`, and `unsubscribe(id)` takes them, as upstream.
- `publish` and `subscribe` are synchronous, so nothing waits for a
  promise. `async_iterable_iterator` subscribes on the first poll, as the
  upstream iterator subscribes on the first `next()`.
- The pull queue of upstream is the waker of the last `PENDING` poll.
- An iterator that its owner drops unsubscribes, as if `return()` ran.
- `throw()` is not ported: an `EventStream` has no `throw`.
- There is no `EventEmitter` option; the engine is its own emitter.
"""

from std.memory import ArcPointer

from gql_stream.poll import Event, EventStream, Poll
from gql_stream.waker import Waker


@fieldwise_init
struct _Target(Copyable, Movable):
    """One listener of a trigger: its subscription id and its iterator."""

    var sub_id: Int
    var iterator: Int


struct _Iterator(Movable):
    """The state of one iterator: its push queue and its subscriptions."""

    var queue: List[Event]
    var head: Int
    var waker: Optional[Waker]
    var running: Bool
    var subscribed: Bool
    var triggers: List[String]
    var sub_ids: List[Int]

    def __init__(out self, var triggers: List[String]):
        self.queue = List[Event]()
        self.head = 0
        self.waker = None
        self.running = True
        self.subscribed = False
        self.triggers = triggers^
        self.sub_ids = List[Int]()


struct _Engine(Movable):
    """The shared state of a `PubSub`: graphql-subscriptions `PubSub`."""

    var index: Dict[String, Int]
    var names: List[String]
    var tables: List[List[_Target]]
    var free_tables: List[Int]
    var table_of: Dict[Int, Int]
    var iterators: List[_Iterator]
    var free: List[Int]
    var sub_id_counter: Int

    def __init__(out self):
        self.index = Dict[String, Int]()
        self.names = List[String]()
        self.tables = List[List[_Target]]()
        self.free_tables = List[Int]()
        self.table_of = Dict[Int, Int]()
        self.iterators = List[_Iterator]()
        self.free = List[Int]()
        self.sub_id_counter = 0

    def new_iterator(mut self, var triggers: List[String]) -> Int:
        """Make the state of an iterator; return its slot."""
        if self.free:
            var slot = self.free.pop()
            self.iterators[slot] = _Iterator(triggers^)
            return slot
        self.iterators.append(_Iterator(triggers^))
        return len(self.iterators) - 1

    def listener_count(self, trigger: String) -> Int:
        """Return the count of listeners of a trigger."""
        var table = self.index.find(trigger)
        if not table:
            return 0
        return len(self.tables[table.value()])

    def subscribe(mut self, trigger: String, iterator: Int) -> Int:
        """Add a listener; return its subscription id."""
        self.sub_id_counter += 1
        var sub_id = self.sub_id_counter
        var found = self.index.find(trigger)
        var table: Int
        if found:
            table = found.value()
        elif self.free_tables:
            table = self.free_tables.pop()
            self.names[table] = trigger
            self.index[trigger] = table
        else:
            table = len(self.tables)
            self.tables.append(List[_Target]())
            self.names.append(trigger)
            self.index[trigger] = table
        self.tables[table].append(_Target(sub_id, iterator))
        self.table_of[sub_id] = table
        return sub_id

    def subscribe_all(mut self, slot: Int):
        """Subscribe an iterator to each of its triggers, once."""
        if self.iterators[slot].subscribed:
            return
        self.iterators[slot].subscribed = True
        var index = 0
        while index < len(self.iterators[slot].triggers):
            var trigger = self.iterators[slot].triggers[index]
            var sub_id = self.subscribe(trigger, slot)
            self.iterators[slot].sub_ids.append(sub_id)
            index += 1

    def unsubscribe(mut self, sub_id: Int) -> Bool:
        """Remove a listener; return False when there is none."""
        var table = self.table_of.pop(sub_id, -1)
        if table < 0:
            return False
        ref targets = self.tables[table]
        var index = 0
        while targets[index].sub_id != sub_id:
            index += 1
        _ = targets.pop(index)
        if not targets:
            _ = self.index.pop(self.names[table], -1)
            self.free_tables.append(table)
        return True

    def publish(mut self, trigger: String, payload: Event):
        """Push a payload to each listener of a trigger, and wake it."""
        var found = self.index.find(trigger)
        if not found:
            return
        ref targets = self.tables[found.value()]
        var index = 0
        while index < len(targets):
            ref state = self.iterators[targets[index].iterator]
            index += 1
            state.queue.append(payload.copy())
            if len(state.queue) - state.head == 1 and state.waker:
                state.waker.value().wake()

    def empty_queue(mut self, slot: Int):
        """Stop an iterator, drop its queue, and unsubscribe it."""
        ref state = self.iterators[slot]
        if not state.running:
            return
        state.running = False
        state.queue.clear()
        state.head = 0
        if state.waker:
            state.waker.value().wake()
            state.waker = None
        var index = 0
        while index < len(self.iterators[slot].sub_ids):
            _ = self.unsubscribe(self.iterators[slot].sub_ids[index])
            index += 1
        self.iterators[slot].sub_ids.clear()

    def release(mut self, slot: Int):
        """Stop an iterator and make its slot free."""
        self.empty_queue(slot)
        self.iterators[slot].triggers.clear()
        self.free.append(slot)

    def poll(mut self, slot: Int, mut waker: Waker) -> Poll:
        """Pull the next payload of an iterator."""
        self.subscribe_all(slot)
        ref state = self.iterators[slot]
        if not state.running:
            return Poll.done()
        if state.head < len(state.queue):
            var event = state.queue[state.head].copy()
            state.head += 1
            if state.head == len(state.queue):
                state.queue.clear()
                state.head = 0
            return Poll.ready(event^)
        if not state.waker or not state.waker.value().will_wake(waker):
            state.waker = waker.copy()
        return Poll.pending()


struct PubSub(Copyable, Movable):
    """An in-process engine: graphql-subscriptions `PubSub`. Copies share
    the engine."""

    var _engine: ArcPointer[_Engine]

    def __init__(out self):
        """Make an engine with no listeners."""
        self._engine = ArcPointer(_Engine())

    def publish(mut self, trigger: StringSlice, payload: Event):
        """Give a payload to each listener of a trigger, and wake them.

        Each listener gets a copy of the event, which shares the document.

        Args:
            trigger: The trigger name.
            payload: The payload.
        """
        self._engine[].publish(String(trigger), payload)

    def subscribe(
        mut self, trigger: StringSlice
    ) -> PubSubAsyncIterableIterator:
        """Listen to a trigger from now on.

        Args:
            trigger: The trigger name.

        Returns:
            An iterator that is subscribed already.
        """
        var triggers = List[String]()
        triggers.append(String(trigger))
        var iterator = self.async_iterable_iterator(triggers^)
        self._engine[].subscribe_all(iterator._slot)
        return iterator^

    def async_iterable_iterator(
        mut self, trigger: StringSlice
    ) -> PubSubAsyncIterableIterator:
        """Make an iterator of one trigger: `asyncIterableIterator`.

        The iterator subscribes on its first poll.

        Args:
            trigger: The trigger name.

        Returns:
            The iterator.
        """
        var triggers = List[String]()
        triggers.append(String(trigger))
        return self.async_iterable_iterator(triggers^)

    def async_iterable_iterator(
        mut self, var triggers: List[String]
    ) -> PubSubAsyncIterableIterator:
        """Make an iterator of several triggers: `asyncIterableIterator`.

        The iterator subscribes on its first poll, to each trigger in turn.

        Args:
            triggers: The trigger names.

        Returns:
            The iterator.
        """
        var slot = self._engine[].new_iterator(triggers^)
        return PubSubAsyncIterableIterator(self._engine, slot)

    def unsubscribe(mut self, sub_id: Int) -> Bool:
        """Remove one subscription of an iterator.

        Args:
            sub_id: The id, from `subscription_ids()`.

        Returns:
            False when no subscription has the id. Upstream throws then.
        """
        return self._engine[].unsubscribe(sub_id)

    def listener_count(self, trigger: StringSlice) -> Int:
        """Return the count of listeners of a trigger, as the
        `EventEmitter` `listenerCount` of upstream tests.

        Args:
            trigger: The trigger name.

        Returns:
            The count.
        """
        return self._engine[].listener_count(String(trigger))


struct PubSubAsyncIterableIterator(EventStream):
    """The payloads of some triggers, in order: graphql-subscriptions
    `PubSubAsyncIterableIterator`."""

    var _engine: ArcPointer[_Engine]
    var _slot: Int

    def __init__(out self, engine: ArcPointer[_Engine], slot: Int):
        """Wrap the state of an iterator; `PubSub` makes iterators.

        Args:
            engine: The engine.
            slot: The slot of the iterator state.
        """
        self._engine = engine
        self._slot = slot

    def __deinit__(deinit self):
        """Unsubscribe, as `return()` does, and free the state."""
        self._engine[].release(self._slot)

    def poll_next(mut self, mut waker: Waker) -> Poll:
        """Pull the next payload: `next()`.

        The first poll subscribes to the triggers.

        Args:
            waker: Kept on `PENDING`; a publish wakes it.

        Returns:
            The next payload, `PENDING`, or `DONE` after `close()`.
        """
        return self._engine[].poll(self._slot, waker)

    def close(mut self):
        """Unsubscribe and drop the queue: `return()`.

        A waker that waits gets a wake, and its poll returns `DONE`.
        """
        self._engine[].empty_queue(self._slot)

    def subscription_ids(self) -> List[Int]:
        """Return the subscription ids, one for each trigger.

        Returns:
            The ids; empty before the first poll and after `close()`.
        """
        return self._engine[].iterators[self._slot].sub_ids.copy()

    def queued(self) -> Int:
        """Return the count of payloads that wait in the push queue.

        Returns:
            The count.
        """
        ref state = self._engine[].iterators[self._slot]
        return len(state.queue) - state.head
