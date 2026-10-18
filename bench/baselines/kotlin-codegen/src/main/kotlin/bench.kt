// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

// The Apollo Kotlin codegen baseline: apollo-compiler 5.2.0 on the JVM.
//
// The workload is the one of bench/gql_codegen/codegen.mojo. The schema is
// read and checked once, outside the timer, with
// ApolloCompiler.buildCodegenSchema. Each operation reads the executable
// document, then parses it, validates it, builds the operationBased IR and
// generates the Kotlin models with ApolloCompiler.buildSchemaAndOperationsSources.
// Each generated file is then rendered to bytes in memory, because the
// Mojo port returns the source text.
//
// The timing method is the one of tools/bench.mojo and of each
// bench/<package>/_harness.mojo: warm up, then run ROUNDS rounds of at least
// ROUND_NS nanoseconds each, and print the fastest round as
// `BENCH <workload> <ns per op>`.

import com.apollographql.apollo.compiler.ApolloCompiler
import com.apollographql.apollo.compiler.CodegenSchemaOptions
import com.apollographql.apollo.compiler.InputFile
import com.apollographql.apollo.compiler.MODELS_OPERATION_BASED
import com.apollographql.apollo.compiler.TargetLanguage
import com.apollographql.apollo.compiler.buildCodegenOptions
import com.apollographql.apollo.compiler.buildIrOptions
import com.apollographql.apollo.compiler.codegen.writeTo
import java.io.ByteArrayOutputStream
import java.io.File

const val ROUND_NS = 1_000_000_000L
const val ROUNDS = 5
const val WARMUP_NS = 200_000_000L

var sink = 0L

fun round(iterations: Long, work: () -> Int): Long {
  var total = 0L
  val start = System.nanoTime()
  for (i in 0 until iterations) {
    total += work()
  }
  val elapsed = System.nanoTime() - start
  sink += total
  return elapsed
}

fun measure(name: String, work: () -> Int) {
  var iterations = 1L
  var warm = 0L
  while (true) {
    val elapsed = round(iterations, work)
    warm += elapsed
    if (elapsed * 4 >= WARMUP_NS || warm >= WARMUP_NS) {
      val perOp = maxOf(elapsed / iterations, 1L)
      iterations = maxOf(ROUND_NS / perOp, 1L)
      break
    }
    iterations *= 2
  }
  var best = Double.MAX_VALUE
  repeat(ROUNDS) {
    val elapsed = round(iterations, work)
    best = minOf(best, elapsed.toDouble() / iterations.toDouble())
  }
  val tenths = Math.floor(best * 10.0) / 10.0
  println("BENCH $name ${String.format(java.util.Locale.ROOT, "%.1f", tenths)}")
}

fun main(args: Array<String>) {
  val fixtures = File("../../fixtures")
  val schema = ApolloCompiler.buildCodegenSchema(
      schemaFiles = listOf(InputFile(File(fixtures, "github-schema.graphql"), "github-schema.graphql")),
      logger = null,
      codegenSchemaOptions = CodegenSchemaOptions(),
      foreignSchemas = emptyList(),
      schemaTransform = null,
  )
  val irOptions = buildIrOptions(codegenModels = MODELS_OPERATION_BASED)
  val codegenOptions = buildCodegenOptions(
      targetLanguage = TargetLanguage.KOTLIN_1_9,
      packageName = "bench",
  )
  val executable = listOf(InputFile(File(fixtures, "github-query.graphql"), "github-query.graphql"))

  // `--emit <directory>` writes the generated Kotlin once, to compare the
  // operation ids and documents with the Mojo port, and does not time.
  if (args.size == 2 && args[0] == "--emit") {
    ApolloCompiler.buildSchemaAndOperationsSources(
        schema, executable, irOptions, codegenOptions,
        null, null, null, null, null, null, null, null,
    ).writeTo(File(args[1]), true, null)
    return
  }

  measure("apollo-kotlin/codegen-github-query") {
    val output = ApolloCompiler.buildSchemaAndOperationsSources(
        codegenSchema = schema,
        executableFiles = executable,
        irOptions = irOptions,
        codegenOptions = codegenOptions,
        layoutFactory = null,
        operationIdsGenerator = null,
        irOperationsTransform = null,
        javaOutputTransform = null,
        kotlinOutputTransform = null,
        documentTransform = null,
        logger = null,
        operationManifestFile = null,
    )
    var bytes = 0
    for (file in output.files) {
      val buffer = ByteArrayOutputStream(4096)
      file.writeTo(buffer)
      bytes += buffer.size()
    }
    bytes
  }
  if (sink == 42L) {
    println(sink)
  }
}
