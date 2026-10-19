// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! The two files of `h3/src/proto` that `h3/src/qpack` imports, as
//! `crate::proto::coding` and `crate::proto::varint`.

#[path = "../upstream/h3/src/proto/coding.rs"]
pub mod coding;
#[path = "../upstream/h3/src/proto/varint.rs"]
pub mod varint;
