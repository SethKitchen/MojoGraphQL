#!/bin/sh
# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
#
# Fetch Apollo Rover 1.0.0 at the pinned revision into upstream/, build its
# release `rover` program, and build the Mojo process driver of
# bench/gql_seamstress/_driver.mojo, which times the seamstress program too. Rover
# is a measurement here, not a port: nothing of it is copied. Set
# ROVER_UPSTREAM_GIT to clone from a local mirror.
set -e
REV=39a041a
REPO=${ROVER_UPSTREAM_GIT:-https://github.com/apollographql/rover}
if [ ! -d upstream/.git ]; then
  git clone --quiet "$REPO" upstream
fi
if [ "$(git -C upstream rev-parse --short=7 HEAD)" != "$REV" ]; then
  git -C upstream checkout --quiet --force "$REV"
fi
export CARGO_TARGET_DIR="$PWD/target"
if [ ! -x target/release/rover ]; then
  (cd upstream && cargo build --release --locked --quiet -j 6 --bin rover)
fi
(cd ../../.. && mkdir -p .cache/bin && .venv/bin/mojo build -I . -o \
  .cache/bin/seamstress_driver bench/gql_seamstress/_driver.mojo > /dev/null)
