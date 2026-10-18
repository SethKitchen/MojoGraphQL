#!/bin/sh
# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
#
# Fetch Hive Router at the pinned revision into upstream/, and build the
# query planner benchmark against it. Set HIVE_ROUTER_UPSTREAM_GIT to clone
# from a local mirror. Set CARGO_BUILD_JOBS to limit the build.
set -e
REV=1a29df93c911c20eadcbc8f56f831c8298fb10dc
REPO=${HIVE_ROUTER_UPSTREAM_GIT:-https://github.com/graphql-hive/router}
if [ ! -d upstream/.git ]; then
  git clone --quiet "$REPO" upstream
fi
if [ "$(git -C upstream rev-parse HEAD)" != "$REV" ]; then
  git -C upstream checkout --quiet --force "$REV"
fi
export CARGO_TARGET_DIR="$PWD/target"
cargo build --release --quiet
