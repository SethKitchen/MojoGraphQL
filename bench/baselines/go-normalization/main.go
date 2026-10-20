// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// The graphql-go-tools v2 baseline of gql_normalization: astnormalization,
// astminify and variablesvalidation at the pinned revision 9ef6e24. It
// prints `BENCH <workload> <ns per op>` lines with the same method as
// bench/gql_normalization/_harness.mojo: warm up, then rounds of at least
// roundNS each, and report the fastest round.
//
// Each file of the package registers its workloads in init(), with the
// inputs of the upstream Go benchmark that it copies.
package main

import (
	"fmt"
	"math"
	"os"
	"runtime"
	"time"
)

const (
	roundNS  = int64(time.Second)
	rounds   = 5
	warmupNS = int64(200 * time.Millisecond)
)

var sink int

type workload func() int

type entry struct {
	name string
	work workload
}

var workloads []entry

// register adds a workload. The workloads run in the order of the file
// names, then in the order of the calls.
func register(name string, work workload) {
	workloads = append(workloads, entry{name, work})
}

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

func main() {
	only := ""
	if len(os.Args) > 1 {
		only = os.Args[1]
	}
	for _, w := range workloads {
		if only == "" || only == w.name {
			measure(w.name, w.work)
		}
	}
}
