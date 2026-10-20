// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// The astminify workload: BenchmarkMinify of v2/pkg/astminify/minify_test.go.
// It minifies operation1.graphql against simpleschema.graphql with the base
// schema merged in, with SortAST, and reuses one Minifier and one buffer.
package main

import (
	"bytes"
	"os"
	"path/filepath"

	"github.com/wundergraph/graphql-go-tools/v2/pkg/astminify"
	"github.com/wundergraph/graphql-go-tools/v2/pkg/astparser"
	"github.com/wundergraph/graphql-go-tools/v2/pkg/asttransform"
)

// readMinifyFixture reads a fixture from bench/fixtures/. The program runs
// from bench/baselines/go-normalization.
func readMinifyFixture(name string) []byte {
	data, err := os.ReadFile(filepath.Join("..", "..", "fixtures", name))
	if err != nil {
		panic(err)
	}
	return data
}

func init() {
	operation := readMinifyFixture("go-tools-minify-operation1.graphql")
	schema := readMinifyFixture("go-tools-minify-simpleschema.graphql")
	// unsafeparser.ParseGraphqlDocumentStringWithBaseSchema of the upstream
	// benchmark: parse, then merge the base schema.
	definition, report := astparser.ParseGraphqlDocumentBytes(schema)
	if report.HasErrors() {
		panic(report.Error())
	}
	if err := asttransform.MergeDefinitionWithBaseSchema(&definition); err != nil {
		panic(err)
	}
	opts := astminify.MinifyOptions{SortAST: true}
	buf := &bytes.Buffer{}
	m := astminify.NewMinifier()
	register("go-tools/Minify", func() int {
		buf.Reset()
		if _, err := m.Minify(operation, &definition, opts, buf); err != nil {
			panic(err)
		}
		return buf.Len()
	})
}
