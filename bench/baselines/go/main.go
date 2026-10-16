// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// The graphql-go-tools v2 baseline: the parser, printer and lexer of the
// WunderGraph Cosmo Router. It prints `BENCH <workload> <ns per op>` lines
// with the same method as bench/gql_language/_harness.mojo: warm up, then
// rounds of at least roundNS each, and report the fastest round.
//
// It runs every workload the library can express: it parses, prints and
// lexes all of them. It reuses one parser and one document across
// operations, as the library's own benchmarks and its documentation for hot
// paths do.
//
// The go-tools/* workloads copy the upstream benchmarks: pkg/astparser,
// pkg/astprinter and pkg/lexer. go-tools/Print uses `Printer{}` into a reused
// buffer, as BenchmarkPrint does: that is the compact one-line form. The
// other print workloads use PrintIndent with two spaces, the layout of
// graphql-js `print`.
package main

import (
	"bytes"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"github.com/wundergraph/graphql-go-tools/v2/pkg/ast"
	"github.com/wundergraph/graphql-go-tools/v2/pkg/astparser"
	"github.com/wundergraph/graphql-go-tools/v2/pkg/astprinter"
	"github.com/wundergraph/graphql-go-tools/v2/pkg/lexer"
	"github.com/wundergraph/graphql-go-tools/v2/pkg/lexer/keyword"
	"github.com/wundergraph/graphql-go-tools/v2/pkg/operationreport"
)

const (
	roundNS  = int64(time.Second)
	rounds   = 5
	warmupNS = int64(200 * time.Millisecond)
)

var sink int

type workload func() int

func run(work workload, iterations int64) int64 {
	start := time.Now()
	for i := int64(0); i < iterations; i++ {
		sink += work()
	}
	return time.Since(start).Nanoseconds()
}

func measure(name string, work workload) {
	iterations := int64(1)
	warm := int64(0)
	for {
		elapsed := run(work, iterations)
		warm += elapsed
		if elapsed*4 >= warmupNS || warm >= warmupNS {
			perOp := max(elapsed/iterations, 1)
			iterations = max(roundNS/perOp, 1)
			break
		}
		iterations *= 2
	}
	best := math.MaxFloat64
	for r := 0; r < rounds; r++ {
		runtime.GC()
		elapsed := run(work, iterations)
		best = math.Min(best, float64(elapsed)/float64(iterations))
	}
	fmt.Printf("BENCH %s %.1f\n", name, best)
}

// fixture reads a fixture from bench/fixtures/. The program runs from
// bench/baselines/go/, as tools/bench.mojo runs it.
func fixture(name string) []byte {
	data, err := os.ReadFile(filepath.Join("..", "..", "fixtures", name))
	if err != nil {
		panic(err)
	}
	return data
}

// A parser with its own reused document and report.
type reusedParser struct {
	parser   *astparser.Parser
	document *ast.Document
	report   operationreport.Report
}

func newParser() *reusedParser {
	return &reusedParser{parser: astparser.NewParser(), document: ast.NewDocument()}
}

// parse is the loop body of the astparser benchmarks.
func (p *reusedParser) parse(text []byte) *ast.Document {
	p.document.Reset()
	p.document.Input.ResetInputBytes(text)
	p.report.Reset()
	p.parser.Parse(p.document, &p.report)
	if p.report.HasErrors() {
		panic(p.report.Error())
	}
	return p.document
}

var first, second = newParser(), newParser()

func parseOnce(text []byte) workload {
	return func() int { return len(first.parse(text).RootNodes) }
}

func parseTwo(schema, query []byte) workload {
	return func() int {
		return len(first.parse(schema).RootNodes) + len(second.parse(query).RootNodes)
	}
}

func printIndent(document *ast.Document) int {
	printed, err := astprinter.PrintStringIndent(document, "  ")
	if err != nil {
		panic(err)
	}
	return len(printed)
}

func parsePrint(text []byte) workload {
	return func() int { return printIndent(first.parse(text)) }
}

// parseOnly parses a document once, outside the timer, into its own
// document.
func parseOnly(text []byte) *ast.Document {
	document, report := astparser.ParseGraphqlDocumentBytes(text)
	if report.HasErrors() {
		panic(report.Error())
	}
	return &document
}

func printOnly(text []byte) workload {
	document := parseOnly(text)
	return func() int { return printIndent(document) }
}

// lex is the loop body of pkg/lexer BenchmarkLexer.
func lex(text []byte) workload {
	in := &ast.Input{}
	lex := &lexer.Lexer{}
	lex.SetInput(in)
	return func() int {
		in.ResetInputBytes(text)
		count := 0
		var key keyword.Keyword
		for key != keyword.EOF {
			key = lex.Read().Keyword
			count++
		}
		return count
	}
}

// parseWalkQuery is apollo-parser parse_query over this AST: visit the
// selection set of each top-level field of each operation.
func parseWalkQuery(text []byte) workload {
	return func() int {
		document := first.parse(text)
		found := 0
		for _, node := range document.RootNodes {
			if node.Kind != ast.NodeKindOperationDefinition {
				continue
			}
			set := document.OperationDefinitions[node.Ref].SelectionSet
			for _, ref := range document.SelectionSets[set].SelectionRefs {
				selection := document.Selections[ref]
				if selection.Kind == ast.SelectionKindField {
					found += document.Fields[selection.Ref].SelectionSet
				}
			}
		}
		return found
	}
}

// parseWalkSchema is apollo-parser parse_schema over this AST: visit the
// type of each field of each object type definition.
func parseWalkSchema(text []byte) workload {
	return func() int {
		document := first.parse(text)
		found := 0
		for _, node := range document.RootNodes {
			if node.Kind != ast.NodeKindObjectTypeDefinition {
				continue
			}
			fields := document.ObjectTypeDefinitions[node.Ref].FieldsDefinition.Refs
			for _, ref := range fields {
				found += document.FieldDefinitions[ref].Type
			}
		}
		return found
	}
}

// printCompact is the loop body of pkg/astprinter BenchmarkPrint.
func printCompact(text []byte) workload {
	document := parseOnly(text)
	buff := &bytes.Buffer{}
	printer := astprinter.Printer{}
	return func() int {
		buff.Reset()
		if err := printer.Print(document, buff); err != nil {
			panic(err)
		}
		return buff.Len()
	}
}

func main() {
	shared := []string{"kitchen-sink", "github-schema", "github-query"}
	for _, name := range shared {
		measure("shared/parse-"+name, parseOnce(fixture(name+".graphql")))
	}
	for _, name := range shared {
		measure("shared/parse-print-"+name, parsePrint(fixture(name+".graphql")))
	}
	for _, name := range shared {
		measure("shared/print-"+name, printOnly(fixture(name+".graphql")))
	}

	measure("graphql-js/parse-introspection-query",
		parseOnce(fixture("graphql-js-introspection-query.graphql")))
	measure("graphql-js/print-kitchen-sink", printOnly(fixture("kitchen-sink.graphql")))

	query := fixture("apollo-parser-query.graphql")
	supergraph := fixture("apollo-parser-supergraph.graphql")
	measure("apollo-parser/query_parser", parseWalkQuery(query))
	measure("apollo-parser/query_lexer", lex(query))
	measure("apollo-parser/many_aliases", parseWalkQuery(fixture("apollo-parser-alias.graphql")))
	measure("apollo-parser/supergraph_parser", parseWalkSchema(supergraph))
	measure("apollo-parser/supergraph_lexer", lex(supergraph))
	measure("apollo-compiler/simple_query-parse_ast", parseTwo(
		fixture("apollo-compiler-simple-schema.graphql"),
		fixture("apollo-compiler-simple-query.graphql")))
	measure("apollo-compiler/supergraph-parse_ast", parseTwo(
		supergraph, fixture("apollo-compiler-supergraph-query.graphql")))

	introspection := fixture("go-tools-introspection-query.graphql")
	measure("go-tools/ParseStarwars", parseOnce(fixture("go-tools-starwars.schema.graphql")))
	measure("go-tools/ParseGithub", parseOnce(fixture("go-tools-github.schema.graphql")))
	measure("go-tools/SelectionSet", parseOnce(fixture("go-tools-selection-set.graphql")))
	measure("go-tools/IntrospectionQuery", parseOnce(introspection))
	measure("go-tools/KitchenSink", parseOnce(fixture("go-tools-kitchen-sink.graphql")))
	measure("go-tools/Parse", parseOnce(fixture("go-tools-parse-input.graphql")))
	measure("go-tools/Print", printCompact(fixture("go-tools-print-operation.graphql")))
	measure("go-tools/Lexer", lex(introspection))

	if sink == 0 {
		panic("no work was done")
	}
}
