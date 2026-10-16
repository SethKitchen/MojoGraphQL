#!/bin/sh
# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
#
# Fetch Apollo MCP Server 2.0.0 at the pinned revision into upstream/, make
# `Operation` and `RawOperation` public for the in-process benchmark, and
# build the release server and the `tool` benchmark. The patch changes two
# `pub(crate) use` lines to `pub use`, and nothing else. Set
# MCP_UPSTREAM_GIT to clone from a local mirror.
set -e
REV=04e4e6e406a7747e97238dbbea352007c253738e
REPO=${MCP_UPSTREAM_GIT:-https://github.com/apollographql/apollo-mcp-server}
if [ ! -d upstream/.git ]; then
  git clone --quiet "$REPO" upstream
fi
if [ "$(git -C upstream rev-parse HEAD)" != "$REV" ]; then
  git -C upstream checkout --quiet --force "$REV"
fi
FILE=upstream/crates/apollo-mcp-server/src/operations.rs
if grep -q '^pub(crate) use raw_operation::RawOperation;' "$FILE"; then
  sed -i 's/^pub(crate) use operation::{Operation, /pub use operation::{Operation, /; s/^pub(crate) use raw_operation::RawOperation;/pub use raw_operation::RawOperation;/' "$FILE"
fi
grep -q '^pub use operation::{Operation, ' "$FILE"
grep -q '^pub use raw_operation::RawOperation;' "$FILE"
export CARGO_TARGET_DIR="$PWD/target"
(cd upstream && cargo build --release --locked --quiet -p apollo-mcp-server --bin apollo-mcp-server)
cargo build --release --locked --quiet
