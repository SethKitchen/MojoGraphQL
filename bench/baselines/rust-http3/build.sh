# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
#
# Fetch hyperium/h3 at the pinned revision into upstream/, then build the
# baselines. Set H3_UPSTREAM_GIT to clone from a local mirror.
set -e
REV=22c1aa3f44d1463cd7644c8f654fffc9a6da305c
REPO=${H3_UPSTREAM_GIT:-https://github.com/hyperium/h3}
if [ ! -d upstream/.git ]; then
  git clone --quiet "$REPO" upstream
fi
if [ "$(git -C upstream rev-parse HEAD)" != "$REV" ]; then
  git -C upstream fetch --quiet origin "$REV" 2> /dev/null || true
  git -C upstream checkout --quiet --force "$REV"
fi
cargo build --release --locked --quiet
