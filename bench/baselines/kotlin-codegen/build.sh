#!/bin/sh
# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
#
# Build the apollo-compiler baseline with a portable JDK 21 and Gradle.
# JAVA_HOME and GRADLE can point elsewhere. The build is skipped when the
# installed program is newer than its sources.
set -e
export JAVA_HOME="${JAVA_HOME:-$HOME/jdk}"
GRADLE="${GRADLE:-$HOME/gradle/gradle-8.14.3/bin/gradle}"
program=build/install/kotlin-codegen/bin/kotlin-codegen
if [ -x "$program" ] && [ "$program" -nt src/main/kotlin/bench.kt ] \
  && [ "$program" -nt build.gradle.kts ]; then
  exit 0
fi
"$GRADLE" --quiet --no-daemon installDist
touch "$program"
