# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The apollo-compiler 1.33.0 executable validation benchmarks.

Each workload makes the schema and the query text as the upstream bench
does, outside the timer, and times `ExecutableDocument::parse_and_validate`:
a parse and a validation with every specified rule.

- `benches/fields_validation.rs`: `many_same_field`,
  `many_same_nested_field`, `many_arguments`, `many_types` and
  `many_extensions`.
- `benches/fragments_validation.rs`: `big_schema_many_fragments`.
- `benches/directives_validation.rs`: `many_same_directive_query` and
  `many_invalid_directive`. Its `many_same_directive` validates a schema,
  not a document, so it is not here.

graphql-js stops at 100 errors, and so does this port. apollo-compiler
reports every error, so `many_arguments` and `many_invalid_directive` give
it more errors to make.
"""

from _harness import ParseValidate, checked_schema, measure


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
    """Run the apollo-compiler workloads."""
    var hello = String("type Query { hello: String! }")
    measure(
        "apollo-compiler/many_same_field",
        ParseValidate(
            checked_schema(hello), "{ " + _repeat("hello ", 1000) + " }"
        ),
    )
    measure(
        "apollo-compiler/many_same_nested_field",
        ParseValidate(
            checked_schema(
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
        "apollo-compiler/many_arguments",
        ParseValidate(checked_schema(hello), "{ " + field + " " + field + " }"),
    )
    measure(
        "apollo-compiler/many_types",
        ParseValidate(
            checked_schema(_many_types_schema()), _many_types_query()
        ),
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
        "apollo-compiler/many_extensions",
        ParseValidate(checked_schema(extensions), fields),
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
        "apollo-compiler/big_schema_many_fragments",
        ParseValidate(
            checked_schema(sdl),
            "query {\n  " + selection + "}\n" + fragments,
        ),
    )
    var directives = (
        "\n        {\n          hello "
        + _repeat("@nothing ", 10_000)
        + "\n        }\n        "
    )
    measure(
        "apollo-compiler/many_same_directive_query",
        ParseValidate(
            checked_schema(
                "\n        directive @nothing repeatable on FIELD\n       "
                " type Query { hello: String! }\n        "
            ),
            directives,
        ),
    )
    measure(
        "apollo-compiler/many_invalid_directive",
        ParseValidate(
            checked_schema("\n        type Query { hello: String! }\n        "),
            directives,
        ),
    )
