// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// go-tools/FragmentSpreadDepth copies BenchmarkFragmentSpreadDepthCalc_Get
// of v2/pkg/astnormalization/fragmentspread_depth_test.go: one
// FragmentSpreadDepth gets the depths of the nested operation of that file
// again and again, into one Depths slice that is cut to zero length first.
// As upstream, the definition is testDefinition, not merged with the base
// schema.
package main

import (
	"github.com/wundergraph/graphql-go-tools/v2/pkg/astnormalization"
	"github.com/wundergraph/graphql-go-tools/v2/pkg/astparser"
	"github.com/wundergraph/graphql-go-tools/v2/pkg/operationreport"
)

const fragmentSpreadDepthOperation = `
				subscription sub {
					...frag1
				}
				fragment frag1 on Subscription {
					newMessage {
						body
						sender
					}
					disallowedSecondRootField
					...frag2
				}
				fragment frag2 on Subscription {
					frag2Field
				}`

func init() {
	operation, report := astparser.ParseGraphqlDocumentString(fragmentSpreadDepthOperation)
	if report.HasErrors() {
		panic(report.Error())
	}
	definition, report := astparser.ParseGraphqlDocumentString(normalizationDefinition)
	if report.HasErrors() {
		panic(report.Error())
	}
	calc := &astnormalization.FragmentSpreadDepth{}
	depths := make(astnormalization.Depths, 0, 8)
	report = operationreport.Report{}
	register("go-tools/FragmentSpreadDepth", func() int {
		depths = depths[:0]
		calc.Get(&operation, &definition, &report, &depths)
		return depths[len(depths)-1].Depth
	})
}
