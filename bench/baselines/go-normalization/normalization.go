// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// go-tools/AstNormalization copies BenchmarkAstNormalization of
// v2/pkg/astnormalization/astnormalization_test.go: NewNormalizer(false,
// false) normalizes one parsed operation again and again, with the
// testDefinition and testOperation of that file. As upstream, the definition
// is not merged with the base schema.
package main

import (
	"github.com/wundergraph/graphql-go-tools/v2/pkg/astnormalization"
	"github.com/wundergraph/graphql-go-tools/v2/pkg/astparser"
	"github.com/wundergraph/graphql-go-tools/v2/pkg/operationreport"
)

func init() {
	definition, report := astparser.ParseGraphqlDocumentString(normalizationDefinition)
	if report.HasErrors() {
		panic(report.Error())
	}
	operation, report := astparser.ParseGraphqlDocumentString(normalizationOperation)
	if report.HasErrors() {
		panic(report.Error())
	}
	normalizer := astnormalization.NewNormalizer(false, false)
	report = operationreport.Report{}
	register("go-tools/AstNormalization", func() int {
		report.Reset()
		normalizer.NormalizeOperation(&operation, &definition, &report)
		return len(operation.Fields)
	})
}
