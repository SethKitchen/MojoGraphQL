// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// The Go net/http baselines, the HTTP stack of graphql-go-tools users and
// the Cosmo Router.
//
// `./bench-http-go server` serves `http/keepalive-small-json` with
// GOMAXPROCS=1: it reads each request body and answers
// `{"data":{"hello":"world"}}`. It prints `PORT <n>` and serves until it
// is killed; bench/gql_http/_loadgen.mojo drives it.
//
// `./bench-http-go parse` times `http/parse-request`: http.ReadRequest on
// the head of a typical GraphQL POST, with the method of the Mojo
// benchmark: warm up, then the fastest of 5 rounds of at least a second.
package main

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"math"
	"net"
	"net/http"
	"os"
	"runtime"
	"time"
)

const request = "POST /graphql HTTP/1.1\r\n" +
	"Host: localhost:4000\r\n" +
	"Connection: keep-alive\r\n" +
	"Content-Length: 126\r\n" +
	"sec-ch-ua: \"Chromium\";v=\"128\", \"Not;A=Brand\";v=\"24\"\r\n" +
	"accept: application/graphql-response+json, application/json\r\n" +
	"content-type: application/json\r\n" +
	"User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36\r\n" +
	"Origin: http://localhost:4000\r\n" +
	"Sec-Fetch-Site: same-origin\r\n" +
	"Sec-Fetch-Mode: cors\r\n" +
	"Referer: http://localhost:4000/\r\n" +
	"Accept-Encoding: gzip, deflate, br\r\n" +
	"Accept-Language: en-US,en;q=0.9\r\n" +
	"\r\n" +
	"{\"query\":\"query Hero($episode: Episode) { hero(episode: $episode) { name friends { name } } }\",\"variables\":{\"episode\":\"JEDI\"}}"

var body = []byte(`{"data":{"hello":"world"}}`)

func serve() {
	runtime.GOMAXPROCS(1)
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	fmt.Printf("PORT %d\n", listener.Addr().(*net.TCPAddr).Port)
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.Copy(io.Discard, r.Body)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write(body)
	})
	panic(http.Serve(listener, handler))
}

var sink int

func run(iterations int) time.Duration {
	data := []byte(request)
	start := time.Now()
	for i := 0; i < iterations; i++ {
		req, err := http.ReadRequest(bufio.NewReader(bytes.NewReader(data)))
		if err != nil {
			panic(err)
		}
		sink += len(req.Header)
	}
	return time.Since(start)
}

func parse() {
	iterations := 1
	for {
		elapsed := run(iterations)
		if elapsed >= 50*time.Millisecond {
			perOp := elapsed.Nanoseconds() / int64(iterations)
			if perOp < 1 {
				perOp = 1
			}
			iterations = int(1_000_000_000 / perOp)
			break
		}
		iterations *= 2
	}
	best := math.MaxFloat64
	for round := 0; round < 5; round++ {
		elapsed := run(iterations)
		best = math.Min(best, float64(elapsed.Nanoseconds())/float64(iterations))
	}
	fmt.Printf("BENCH http/parse-request %.1f\n", best)
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "server" {
		serve()
		return
	}
	parse()
}
