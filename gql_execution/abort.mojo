# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The abort signal of an incremental execution: the Mojo form of the DOM
`AbortController` and `AbortSignal` that graphql-js v17.0.2
`ExecutionArgs.abortSignal` takes.

An `AbortController` makes an `AbortSignal`. The controller and its
signals share one state, so `abort()` on the controller is seen through
each signal.

```mojo
from gql_execution.abort import AbortController

def main():
    var controller = AbortController()
    var signal = controller.signal()
    controller.abort()
    print(signal.aborted(), signal.reason())
    # True This operation was aborted
```

**Differences from upstream.** The reason is a message, not any value. The
signal has no event listeners: the subsequent results read it at each
poll.
"""

from std.memory import ArcPointer

comptime ABORT_REASON = "This operation was aborted"
"""The message of the DOM `AbortError` that `abort()` with no reason
gives."""


struct _AbortState(Movable):
    """The state that a controller and its signals share."""

    var aborted: Bool
    var reason: String

    def __init__(out self):
        self.aborted = False
        self.reason = String("")


struct AbortSignal(Copyable, Movable):
    """A signal that tells whether its controller aborted: the DOM
    `AbortSignal`."""

    var _state: ArcPointer[_AbortState]

    def __init__(out self, state: ArcPointer[_AbortState]):
        """Share the state of a controller.

        Args:
            state: The state.
        """
        self._state = state

    def aborted(self) -> Bool:
        """Return True after `abort()`: the DOM `signal.aborted`.

        Returns:
            Whether the controller aborted.
        """
        return self._state[].aborted

    def reason(self) -> String:
        """Return the reason of the abort: the DOM `signal.reason`.

        Returns:
            The message, or an empty string before `abort()`.
        """
        return self._state[].reason


struct AbortController(Movable):
    """The owner of an abort signal: the DOM `AbortController`."""

    var _state: ArcPointer[_AbortState]

    def __init__(out self):
        """Make a controller that has not aborted."""
        self._state = ArcPointer(_AbortState())

    def signal(self) -> AbortSignal:
        """Return a signal of this controller: the DOM
        `controller.signal`.

        Returns:
            A signal that shares the state of the controller.
        """
        return AbortSignal(self._state)

    def abort(mut self, reason: String = ABORT_REASON):
        """Abort, as the DOM `controller.abort(reason)`. A second call
        changes nothing.

        Args:
            reason: The message of the abort.
        """
        if self._state[].aborted:
            return
        self._state[].aborted = True
        self._state[].reason = reason
