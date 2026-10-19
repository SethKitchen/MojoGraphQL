# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The apollo-compiler 1.33.0 executable validation benchmarks, against
gql_compiler validation.

Each workload is the workload of the same name in
`bench/gql_validation/apollo_compiler.mojo`, and the Rust baseline times
the same closure under both names. The schema is built and checked
outside the timer, as upstream `Schema::parse_and_validate`. The timer
covers `ExecutableDocument::parse_and_validate`: a parse, a build and a
validation with every check. `parse_and_validate_executable` is that
call here. Both sides report every error.

- `benches/fields_validation.rs`: `many_same_field`,
  `many_same_nested_field`, `many_arguments`, `many_types` and
  `many_extensions`.
- `benches/fragments_validation.rs`: `big_schema_many_fragments`.
- `benches/directives_validation.rs`: `many_same_directive_query` and
  `many_invalid_directive`.
"""

from gql_compiler.schema import Schema
from gql_compiler.validation import (
    parse_and_validate_executable,
    parse_and_validate_schema,
)
from _harness import Workload, measure


struct ParseAndValidate(Movable, Workload):
    """Parse, build and validate a query against a checked schema."""

    var schema: Schema
    """The schema, built and checked outside the timer."""
    var query: String
    """The query text."""

    def __init__(out self, sdl: String, query: String) raises:
        """Build and check the schema once.

        Args:
            sdl: The schema text.
            query: The query text.

        Raises:
            Error: If the schema is not valid.
        """
        var checked = parse_and_validate_schema(sdl, "schema.graphql")
        if not checked[1].is_empty():
            raise Error("invalid schema: ", checked[1])
        self.schema = Schema()
        swap(self.schema, checked[0])
        self.query = query

    def run(mut self) raises -> Int:
        """Parse, build and validate the query.

        Returns:
            1, plus the number of errors.

        Raises:
            Error: If the query does not parse.
        """
        var result = parse_and_validate_executable(
            self.schema, self.query, "query.graphql"
        )
        return len(result[1]) + 1


def _repeat(text: String, count: Int) -> String:
    """Return a text repeated, as Rust `str::repeat`."""
    var out = String("")
    for _ in range(count):
        out += text
    return out^


def _many_types_schema() -> String:
    """The schema of `bench_many_types`."""
    return String(
        """
        interface Abstract {
          field: Abstract
          leaf: Int
        }
        interface Abstract1 {
          field: Abstract
          leaf: Int
        }
        interface Abstract2 {
          field: Abstract
          leaf: Int
        }
        type Concrete1 implements Abstract & Abstract1 {
          field: Abstract
          leaf: Int
        }
        type Concrete2 implements Abstract & Abstract2 {
          field: Abstract
          leaf: Int
        }
        type Query {
            field: Abstract
        }
    """
    )


def _many_types_query() -> String:
    """The query of `bench_many_types`."""
    return (
        """
        fragment multiply on Abstract {
           field {
             ... on Abstract1 { field { leaf } }
             ... on Abstract2 { field { leaf } }
             ... on Concrete1 { field { leaf } }
             ... on Concrete2 { field { leaf } }
           }
        }

        query DeepAbstractConcrete {
            """
        + _repeat("field { ...multiply ", 100)
        + _repeat("}", 100)
        + """
        }
    """
    )


def main() raises:
    """Run the apollo-compiler validation workloads."""
    var hello = String("type Query { hello: String! }")
    measure(
        "apollo-compiler-validate/many_same_field",
        ParseAndValidate(String(hello), "{ " + _repeat("hello ", 1000) + " }"),
    )
    measure(
        "apollo-compiler-validate/many_same_nested_field",
        ParseAndValidate(
            String(
                """
        type Nested { hello: String! }
        type Query { nested: Nested! }
    """
            ),
            "{ " + _repeat("nested { hello } ", 1000) + " }",
        ),
    )
    var args = String("")
    for i in range(2000):
        args += "arg" + String(i) + ": " + String(i) + "\n"
    var field = "hello(" + args + ")"
    measure(
        "apollo-compiler-validate/many_arguments",
        ParseAndValidate(String(hello), "{ " + field + " " + field + " }"),
    )
    measure(
        "apollo-compiler-validate/many_types",
        ParseAndValidate(String(_many_types_schema()), _many_types_query()),
    )
    var extensions = String("type Query { a: A }\n")
    for i in range(1, 10_001):
        extensions += "interface I" + String(i) + " { f" + String(i)
        extensions += ": String }\n"
    extensions += "type A { f0: String }\n"
    for i in range(1, 10_001):
        extensions += "extend type A implements I" + String(i) + " { f"
        extensions += String(i) + ": String }\n"
    var fields = String("{ a { ")
    for i in range(1, 10_001):
        fields += "f" + String(i) + " "
    fields += "} }"
    measure(
        "apollo-compiler-validate/many_extensions",
        ParseAndValidate(String(extensions), fields),
    )
    var sdl = String("")
    for i in range(200):
        sdl += "interface Intf" + String(i) + " { field: Int! }\n"
    for o in range(10_000):
        sdl += "type Ty" + String(o) + " implements Intf" + String(o % 200)
        sdl += " { field: Int! }\n"
    sdl += "type Query {\n"
    for i in range(200):
        sdl += "  intf" + String(i) + ": Intf" + String(i) + "\n"
    sdl += "}\n"
    var selection = String("")
    var fragments = String("")
    for i in range(200):
        selection += "  intf" + String(i) + " { ...frag" + String(i) + " }\n"
        fragments += "fragment frag" + String(i) + " on Ty" + String(i)
        fragments += " { field }\n"
    measure(
        "apollo-compiler-validate/big_schema_many_fragments",
        ParseAndValidate(
            String(sdl),
            "query {\n  " + selection + "}\n" + fragments,
        ),
    )
    var directives = (
        "\n        {\n          hello "
        + _repeat("@nothing ", 10_000)
        + "\n        }\n        "
    )
    measure(
        "apollo-compiler-validate/many_same_directive_query",
        ParseAndValidate(
            String(
                "\n        directive @nothing repeatable on FIELD\n       "
                " type Query { hello: String! }\n        "
            ),
            directives,
        ),
    )
    measure(
        "apollo-compiler-validate/many_invalid_directive",
        ParseAndValidate(
            String("\n        type Query { hello: String! }\n        "),
            directives,
        ),
    )
