// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// The Go JSON baselines: wundergraph/astjson, the JSON layer of
// graphql-go-tools and the Cosmo Router, and the standard encoding/json. It
// prints `BENCH <workload> <ns per op>` lines with the same method as
// bench/gql_json/json.mojo: warm up, then rounds of at least roundNS each,
// and report the fastest round.
//
// `./bench-json-go astjson` runs astjson; `./bench-json-go encoding-json`
// runs encoding/json. astjson reuses one Parser and one output buffer across
// operations, as its documentation says to do on a hot path. encoding/json
// decodes into `any` and encodes that value.
package main

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"github.com/wundergraph/astjson"
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
// bench/baselines/go-json/.
func fixture(name string) []byte {
	data, err := os.ReadFile(filepath.Join("..", "..", "fixtures", name))
	if err != nil {
		panic(err)
	}
	return data
}

func astjsonWorkloads(introspection, small, variables []byte) {
	var parser astjson.Parser
	var buffer []byte
	parse := func(text []byte) workload {
		return func() int {
			value, err := parser.ParseBytes(text)
			if err != nil {
				panic(err)
			}
			return int(value.Type())
		}
	}
	stringify := func(text []byte) workload {
		var own astjson.Parser
		value, err := own.ParseBytes(text)
		if err != nil {
			panic(err)
		}
		return func() int {
			buffer = value.MarshalTo(buffer[:0])
			return len(buffer)
		}
	}
	measure("json/parse-introspection", parse(introspection))
	measure("json/stringify-introspection", stringify(introspection))
	measure("json/parse-small-response", parse(small))
	measure("json/stringify-small-response", stringify(small))
	measure("json/parse-variables", parse(variables))
}

func encodingJSONWorkloads(introspection, small, variables []byte) {
	parse := func(text []byte) workload {
		return func() int {
			var value any
			if err := json.Unmarshal(text, &value); err != nil {
				panic(err)
			}
			return len(value.(map[string]any))
		}
	}
	stringify := func(text []byte) workload {
		var value any
		if err := json.Unmarshal(text, &value); err != nil {
			panic(err)
		}
		return func() int {
			out, err := json.Marshal(value)
			if err != nil {
				panic(err)
			}
			return len(out)
		}
	}
	measure("json/parse-introspection", parse(introspection))
	measure("json/stringify-introspection", stringify(introspection))
	measure("json/parse-small-response", parse(small))
	measure("json/stringify-small-response", stringify(small))
	measure("json/parse-variables", parse(variables))
}

func main() {
	introspection := fixture("github-schema.json")
	small := fixture("small-response.json")
	variables := fixture("variables.json")
	library := "astjson"
	if len(os.Args) > 1 {
		library = os.Args[1]
	}
	switch library {
	case "astjson":
		astjsonWorkloads(introspection, small, variables)
	case "encoding-json":
		encodingJSONWorkloads(introspection, small, variables)
	default:
		panic("usage: bench-json-go [astjson|encoding-json]")
	}
	if sink == 0 {
		panic("no work was done")
	}
}
