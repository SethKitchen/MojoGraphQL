// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

plugins {
    kotlin("jvm") version "2.2.20"
    application
}

dependencies {
    // The published artifact of the upstream that gql_codegen ports.
    implementation("com.apollographql.apollo:apollo-compiler:5.2.0")
}

kotlin {
    jvmToolchain(21)
}

application {
    mainClass.set("BenchKt")
    // The heap is capped, so that the JVM does not take the machine.
    applicationDefaultJvmArgs = listOf("-Xmx4g")
}
