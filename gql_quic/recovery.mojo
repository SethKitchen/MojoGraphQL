# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""RTT estimation and NewReno congestion control (RFC 9002).

`RttEstimator` keeps the latest, the smallest and the smoothed round-trip
time and its variation (RFC 9002 section 5). `pto_base` is the probe
timeout before the backoff and the `max_ack_delay` of section 6.2.1.

`NewReno` is the congestion controller of RFC 9002 section 7: slow start
until the first loss, then congestion avoidance that adds one datagram per
window of acknowledged bytes. A congestion event halves the window, and
packets sent before the recovery started do not count again.

Times are nanoseconds on a monotonic clock, as `Int`.

This module ports quinn-proto 0.11.19 (8192ed3)
quinn-proto/src/connection/paths.rs `RttEstimator` and
quinn-proto/src/congestion/new_reno.rs (MIT OR Apache-2.0, used under MIT).

Differences from upstream: quinn's default controller is Cubic; this
package has NewReno only. The loss reduction factor is the fixed 1/2 of
quinn's default, and the window grows by `datagram_size`, as quinn's
`current_mtu`, which this package does not change.
"""

comptime NS_PER_MS = 1_000_000
"""Nanoseconds in a millisecond."""
comptime TIMER_GRANULARITY = NS_PER_MS
"""The timer granularity of RFC 9002 section 6.1.2: 1 ms."""
comptime PACKET_THRESHOLD: UInt64 = 3
"""A packet is lost when a packet 3 numbers later is acknowledged."""
comptime INITIAL_RTT = 333 * NS_PER_MS
"""The RTT before a sample: 333 ms (RFC 9002 section 6.2.2)."""


struct RttEstimator(Copyable, Movable):
    """The round-trip time estimates of RFC 9002 section 5."""

    var latest: Int
    """The latest sample."""
    var smoothed: Int
    """The smoothed RTT; -1 before the first sample."""
    var variation: Int
    """The RTT variation."""
    var min: Int
    """The smallest sample."""

    def __init__(out self, initial_rtt: Int = INITIAL_RTT):
        """Start with an initial RTT.

        Args:
            initial_rtt: The RTT before a sample, in nanoseconds.
        """
        self.latest = initial_rtt
        self.smoothed = -1
        self.variation = initial_rtt // 2
        self.min = initial_rtt

    def get(self) -> Int:
        """Return the smoothed RTT, or the latest before a sample.

        Returns:
            Nanoseconds.
        """
        return self.latest if self.smoothed < 0 else self.smoothed

    def conservative(self) -> Int:
        """Return the larger of the smoothed and the latest RTT.

        Returns:
            Nanoseconds.
        """
        return max(self.get(), self.latest)

    def pto_base(self) -> Int:
        """Return the probe timeout before the backoff, without the
        `max_ack_delay` of the peer.

        Returns:
            `smoothed + max(4 * var, 1 ms)`, in nanoseconds.
        """
        return self.get() + max(4 * self.variation, TIMER_GRANULARITY)

    def update(mut self, ack_delay: Int, rtt: Int):
        """Take an RTT sample.

        Args:
            ack_delay: The delay that the peer reported, already limited to
                its `max_ack_delay`.
            rtt: The sample: the time from the send of the largest newly
                acknowledged packet to its acknowledgment.
        """
        self.latest = rtt
        self.min = min(self.min, rtt)
        if self.smoothed < 0:
            self.smoothed = rtt
            self.variation = rtt // 2
            self.min = rtt
            return
        var adjusted = rtt
        if self.min + ack_delay <= rtt:
            adjusted = rtt - ack_delay
        var sample = abs(self.smoothed - adjusted)
        self.variation = (3 * self.variation + sample) // 4
        self.smoothed = (7 * self.smoothed + adjusted) // 8


struct NewReno(Copyable, Movable):
    """The NewReno congestion controller of RFC 9002 section 7."""

    var datagram_size: Int
    """The size of a full datagram, in bytes."""
    var window: Int
    """The congestion window, in bytes."""
    var ssthresh: Int
    """The slow start threshold; `Int.MAX` before the first loss."""
    var recovery_start: Int
    """The time when the current recovery started; -1 for none."""
    var bytes_acked: Int
    """The bytes acknowledged in congestion avoidance since the window last
    grew."""

    def __init__(out self, datagram_size: Int = 1200):
        """Start in slow start with the initial window of RFC 9002.

        Args:
            datagram_size: The size of a full datagram.
        """
        self.datagram_size = datagram_size
        self.window = min(10 * datagram_size, max(2 * datagram_size, 14720))
        self.ssthresh = Int.MAX
        self.recovery_start = -1
        self.bytes_acked = 0

    def minimum_window(self) -> Int:
        """Return the smallest window: two datagrams.

        Returns:
            Bytes.
        """
        return 2 * self.datagram_size

    def on_ack(mut self, sent: Int, bytes: Int, app_limited: Bool):
        """Grow the window for an acknowledged packet.

        Args:
            sent: When the packet was sent.
            bytes: Its size.
            app_limited: Whether the sender had less to send than the
                window allowed; such acks do not grow the window.
        """
        if app_limited or sent <= self.recovery_start:
            return
        if self.window < self.ssthresh:
            self.window += bytes
            if self.window >= self.ssthresh:
                self.bytes_acked = self.window - self.ssthresh
            return
        self.bytes_acked += bytes
        if self.bytes_acked >= self.window:
            self.bytes_acked -= self.window
            self.window += self.datagram_size

    def on_congestion_event(mut self, now: Int, sent: Int, persistent: Bool):
        """Shrink the window after a loss.

        Args:
            now: The current time; the recovery starts now.
            sent: When the newest lost packet was sent. A loss of a packet
                sent before the recovery started does not shrink again.
            persistent: Whether the loss is persistent congestion (RFC 9002
                section 7.6); the window then falls to the minimum.
        """
        if sent <= self.recovery_start:
            return
        self.recovery_start = now
        self.window = max(self.window // 2, self.minimum_window())
        self.ssthresh = self.window
        if persistent:
            self.window = self.minimum_window()
