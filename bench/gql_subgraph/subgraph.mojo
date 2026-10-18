# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Time `build_subgraph_schema`, `print_subgraph_schema` and entity
resolution against `@apollo/subgraph` 2.14.4.

    mojo build -I . -o .cache/bin/subgraph bench/gql_subgraph/subgraph.mojo
    .cache/bin/subgraph

Each workload uses `bench/fixtures/subgraph-catalog.graphql`, a federation
2.3 subgraph of 24 types:

- `subgraph/build-catalog`: parse the SDL and build the executable
  subgraph schema, as upstream `buildSubgraphSchema(parse(sdl))`.
- `subgraph/print-catalog`: `print_subgraph_schema` of the built schema, as
  upstream `printSubgraphSchema(schema)`.
- `subgraph/service-sdl`: execute `{ _service { sdl } }`.
- `subgraph/entities-100`: execute `Query._entities` with 100 `Product`
  representations, each resolved by a `__resolveReference` that returns
  the UPC, a name and a price.

The operations are parsed once, as a server parses each operation once.
The baseline is `bench/baselines/js-subgraph/bench.mjs`, with graphql-js
16.14.2 `execute`.
"""

from std.pathlib import Path
from _harness import Workload, measure
from gql_execution.execute import ExecutionArgs, ResolveInfo
from gql_execution.value import Values
from gql_json.parser import parse as parse_json
from gql_json.value import JsonDocument
from gql_language.ast import Document
from gql_language.parser import parse
from gql_subgraph.build_subgraph_schema import (
    SchemaModule,
    SubgraphResolvers,
    SubgraphSchema,
    build_subgraph_schema,
)
from gql_subgraph.print_subgraph_schema import print_subgraph_schema

comptime FIXTURE = "bench/fixtures/subgraph-catalog.graphql"
"""The SDL of the subgraph."""
comptime ENTITIES = (
    "query($representations: [_Any!]!) { _entities(representations:"
    " $representations) { ... on Product { upc name price { amount currency }"
    " } } }"
)
"""The entity operation."""
comptime COUNT = 100
"""How many representations the entity operation resolves."""


def product_reference(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    """Resolve a `Product` from its representation."""
    var upc = values.get(reference, "upc")
    var product = values.add_object()
    values.add_member(product, "upc", upc)
    values.add_member(
        product, "name", values.add_string("Product " + values.string(upc))
    )
    var price = values.add_object()
    values.add_member(price, "amount", values.add_number(100))
    values.add_member(price, "currency", values.add_string("USD"))
    values.add_member(product, "price", price)
    return product


def build(sdl: String) raises -> SubgraphSchema:
    """Build the subgraph of the benchmark, with its resolvers."""
    var resolvers = SubgraphResolvers()
    resolvers.resolve_reference("Product", product_reference)
    var modules = List[SchemaModule]()
    modules.append(SchemaModule(parse(sdl), resolvers^))
    return build_subgraph_schema(modules^)


struct Build(Workload):
    """`subgraph/build-catalog`."""

    var sdl: String

    def __init__(out self, sdl: String):
        self.sdl = sdl

    def run(mut self) raises -> Int:
        return len(build(self.sdl).schema.types)


struct Print(Workload):
    """`subgraph/print-catalog`."""

    var schema: SubgraphSchema

    def __init__(out self, sdl: String) raises:
        self.schema = build(sdl)

    def run(mut self) raises -> Int:
        return print_subgraph_schema(self.schema).byte_length()


struct Execute(Workload):
    """`subgraph/service-sdl` and `subgraph/entities-100`: one operation,
    with variables that are parsed once."""

    var schema: SubgraphSchema
    var document: Document
    var variables: JsonDocument
    var has_variables: Bool

    def __init__(
        out self, sdl: String, query: String, variables: String
    ) raises:
        self.schema = build(sdl)
        self.document = parse(query)
        self.has_variables = variables != ""
        self.variables = parse_json(
            variables if self.has_variables else String("{}")
        )

    def run(mut self) raises -> Int:
        var args = ExecutionArgs()
        if self.has_variables:
            args.variable_values = args.values.add_json(
                self.variables, self.variables.root
            )
        var result = self.schema.execute(self.document, args)
        if len(result.errors) > 0:
            raise Error(result.errors[0].message)
        return len(result.data.bytes)


def representations() -> String:
    """The variables of the entity operation."""
    var out = String('{"representations":[')
    for index in range(COUNT):
        if index > 0:
            out += ","
        out += '{"__typename":"Product","upc":"' + String(index) + '"}'
    return out + "]}"


def main() raises:
    """Run the workloads."""
    var sdl = Path(FIXTURE).read_text()
    measure("subgraph/build-catalog", Build(sdl))
    measure("subgraph/print-catalog", Print(sdl))
    measure(
        "subgraph/service-sdl", Execute(sdl, "{ _service { sdl } }", String(""))
    )
    measure("subgraph/entities-100", Execute(sdl, ENTITIES, representations()))
