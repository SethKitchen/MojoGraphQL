# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Pull-based event streams for subscriptions: `Poll`, `EventStream`,
`Waker`, an epoll `EventLoop`, an in-process `PubSub` and the stream
combinators.

The streams follow the Rust `Stream` and `Waker` model: an owner polls a
stream, and a stream that has no value yet wakes its owner later. There is
no thread per stream. `PubSub` and `with_filter` port graphql-subscriptions
3.0.0. See the Stream page of the wiki.
"""
