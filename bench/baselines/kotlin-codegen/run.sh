#!/bin/sh
# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
#
# Run the apollo-compiler baseline on the portable JDK, with a 4 GiB heap.
set -e
export JAVA_HOME="${JAVA_HOME:-$HOME/jdk}"
export JAVA_OPTS="-Xmx4g"
exec build/install/kotlin-codegen/bin/kotlin-codegen "$@"
