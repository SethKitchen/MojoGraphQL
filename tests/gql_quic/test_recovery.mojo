# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.recovery`. The upstream files are quinn-proto
0.11.19 quinn-proto/src/connection/paths.rs (`RttEstimator`) and
quinn-proto/src/congestion/new_reno.rs. Neither has a unit test of these
types: the one test of paths.rs, `reset_refreshes_pacer_budget`, tests the
pacer that this port does not have. So the cases check the rules of
RFC 9002 sections 5 and 7 that the upstream code follows."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_quic.recovery import (
    INITIAL_RTT,
    NS_PER_MS,
    TIMER_GRANULARITY,
    NewReno,
    RttEstimator,
)


def test_rtt_initial() raises:
    var rtt = RttEstimator()
    assert_equal(rtt.get(), INITIAL_RTT)
    assert_equal(rtt.conservative(), INITIAL_RTT)
    assert_equal(rtt.pto_base(), INITIAL_RTT + 4 * (INITIAL_RTT // 2))
    var tiny = RttEstimator(0)
    # The variation term is at least the timer granularity.
    assert_equal(tiny.pto_base(), TIMER_GRANULARITY)


def test_rtt_first_sample() raises:
    var rtt = RttEstimator()
    rtt.update(5 * NS_PER_MS, 100 * NS_PER_MS)
    # The first sample sets every estimate, and ignores the ack delay.
    assert_equal(rtt.smoothed, 100 * NS_PER_MS)
    assert_equal(rtt.variation, 50 * NS_PER_MS)
    assert_equal(rtt.min, 100 * NS_PER_MS)
    assert_equal(rtt.latest, 100 * NS_PER_MS)
    assert_equal(rtt.get(), 100 * NS_PER_MS)


def test_rtt_ack_delay() raises:
    var rtt = RttEstimator()
    rtt.update(0, 100 * NS_PER_MS)
    # The ack delay comes off when the sample stays at the minimum or above.
    rtt.update(20 * NS_PER_MS, 140 * NS_PER_MS)
    assert_equal(rtt.latest, 140 * NS_PER_MS)
    assert_equal(rtt.smoothed, (7 * 100 + 120) * NS_PER_MS // 8)
    assert_equal(rtt.variation, (3 * 50 + 20) * NS_PER_MS // 4)
    assert_equal(rtt.min, 100 * NS_PER_MS)
    # The latest sample is above the smoothed RTT.
    assert_equal(rtt.conservative(), 140 * NS_PER_MS)


def test_rtt_ack_delay_too_large() raises:
    var rtt = RttEstimator()
    rtt.update(0, 100 * NS_PER_MS)
    # A delay that would take the sample below the minimum is ignored.
    rtt.update(30 * NS_PER_MS, 110 * NS_PER_MS)
    assert_equal(rtt.smoothed, (7 * 100 + 110) * NS_PER_MS // 8)
    assert_equal(rtt.variation, (3 * 50 + 10) * NS_PER_MS // 4)
    # A smaller sample lowers the minimum.
    rtt.update(0, 60 * NS_PER_MS)
    assert_equal(rtt.min, 60 * NS_PER_MS)
    assert_equal(rtt.conservative(), rtt.smoothed)


def test_new_reno_initial() raises:
    var cc = NewReno()
    assert_equal(cc.window, 12000)
    assert_equal(cc.minimum_window(), 2400)
    assert_equal(cc.ssthresh, Int.MAX)
    assert_equal(NewReno(1000).window, 10000)
    assert_equal(NewReno(2000).window, 14720)
    assert_equal(NewReno(8000).window, 16000)


def test_new_reno_slow_start() raises:
    var cc = NewReno()
    cc.on_ack(10, 1200, False)
    assert_equal(cc.window, 13200)
    # An application-limited ack does not grow the window.
    cc.on_ack(20, 1200, True)
    assert_equal(cc.window, 13200)


def test_new_reno_congestion_event() raises:
    var cc = NewReno()
    cc.on_congestion_event(100, 50, False)
    assert_equal(cc.window, 6000)
    assert_equal(cc.ssthresh, 6000)
    assert_equal(cc.recovery_start, 100)
    # A loss of a packet sent before the recovery does not shrink again.
    cc.on_congestion_event(200, 100, False)
    assert_equal(cc.window, 6000)
    # An ack of a packet sent before the recovery does not grow.
    cc.on_ack(90, 1200, False)
    assert_equal(cc.window, 6000)
    assert_equal(cc.bytes_acked, 0)
    # A later loss shrinks again, to the minimum at most.
    cc.on_congestion_event(300, 250, False)
    assert_equal(cc.window, 3000)
    cc.on_congestion_event(400, 350, False)
    assert_equal(cc.window, 2400)


def test_new_reno_congestion_avoidance() raises:
    var cc = NewReno()
    cc.on_congestion_event(100, 50, False)
    # One datagram per window of acknowledged bytes.
    cc.on_ack(150, 3000, False)
    assert_equal(cc.window, 6000)
    assert_equal(cc.bytes_acked, 3000)
    cc.on_ack(150, 3600, False)
    assert_equal(cc.window, 7200)
    assert_equal(cc.bytes_acked, 600)


def test_new_reno_persistent_congestion() raises:
    var cc = NewReno()
    cc.on_congestion_event(100, 50, True)
    assert_equal(cc.window, 2400)
    assert_equal(cc.ssthresh, 6000)
    # Slow start again, up to the threshold; the rest counts for the
    # congestion avoidance.
    cc.on_ack(150, 2400, False)
    assert_equal(cc.window, 4800)
    assert_equal(cc.bytes_acked, 0)
    cc.on_ack(150, 2400, False)
    assert_equal(cc.window, 7200)
    assert_equal(cc.bytes_acked, 1200)
    assert_false(cc.window < cc.ssthresh)
    assert_true(cc.recovery_start == 100)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
