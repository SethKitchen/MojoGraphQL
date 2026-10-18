# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

# Build image for Anthropic's OSS Scanner (https://github.com/anthropics/oss-scanner).
# The scanner builds this file with the repository as the build context. The
# network is open during this build and closed after it, so everything the
# scan needs must be fetched here. The checkout lives at /src.
#
# The project needs only the Mojo toolchain. The benchmark baselines in
# bench/baselines/ run the upstream libraries in other languages. They are
# measurements, not part of the library, and this image does not install them.
#
# The scanner takes one Dockerfile per project, and it runs Linux. Ubuntu
# 24.04 is the default distribution of WSL 2, so this one image covers Linux
# and Windows through WSL 2. It builds on x86-64 and aarch64. macOS cannot run
# in a scan.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive \
    MODULAR_TELEMETRY_ENABLED=false \
    UV_LINK_MODE=copy
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates build-essential clang git make curl python3 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=ghcr.io/astral-sh/uv:0.9.0 /uv /usr/local/bin/uv

COPY . /src
WORKDIR /src

# The pinned toolchain, as README.md installs it: a uv venv and Mojo 1.1.0.
# The Makefile expects .venv/bin/mojo.
RUN uv venv --python 3.12 \
    && uv pip install "mojo==1.1.0" \
    && .venv/bin/mojo --version

# Run the cheap checks so the image is known to work. A failure here must not
# fail the build, but it prints a WARNING. `make packages-check` builds the
# packages tool into .cache/bin/, so the scan does not pay for it. The suite
# shows that a test compiles and runs with no network.
RUN (make packages-check > /dev/null 2>&1 || echo "WARNING: make packages-check failed"); \
    if .venv/bin/mojo run -I . tests/gql_json/test_parser.mojo > /tmp/smoke.log 2>&1; then \
        tail -n 3 /tmp/smoke.log; \
    else \
        echo "WARNING: the smoke suite failed"; tail -n 30 /tmp/smoke.log; \
    fi
