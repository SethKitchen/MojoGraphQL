// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

//! apollo-compiler 1.x: the AST used by the Apollo Router. It runs every
//! workload it can express: it parses and prints all of them, and has no
//! lexer of its own.
//!
//! Parse is `ast::Document::parse`, which runs apollo-parser and converts the
//! CST to an AST. Print is the `Display` of the AST. `parse_ast` is copied
//! from crates/apollo-compiler/benches/multi_source.rs. The apollo-parser
//! walks visit the AST the way the upstream walks visit the CST.

use apollo_compiler::ast::{Definition, Document, Selection};
use apollo_compiler::validation::Valid;
use apollo_compiler::{ExecutableDocument, Schema};
use mojographql_bench_apollo_rs::{fixture, measure, GO_TOOLS_PARSE, SHARED};
use std::hint::black_box;

fn parse(text: &str) -> Document {
    Document::parse(text, "bench.graphql").expect("valid document")
}

/// benches/multi_source.rs `parse_ast`.
fn parse_ast(schema: &str, query: &str) -> usize {
    let schema = Document::parse(schema, "schema.graphql").unwrap();
    let doc = Document::parse(query, "query.graphql").unwrap();
    std::hint::black_box((schema, doc));
    1
}

/// apollo-parser `parse_query`, over the AST.
fn parse_query(query: &str) -> usize {
    let document = parse(query);
    for definition in &document.definitions {
        if let Definition::OperationDefinition(operation) = definition {
            for selection in &operation.selection_set {
                if let Selection::Field(field) = selection {
                    black_box(&field.selection_set);
                }
            }
        }
    }
    document.definitions.len()
}

/// apollo-parser `parse_schema`, over the AST.
fn parse_schema(schema: &str) -> usize {
    let document = parse(schema);
    for definition in &document.definitions {
        if let Definition::ObjectTypeDefinition(object) = definition {
            for field in &object.fields {
                black_box(&field.ty);
            }
        }
    }
    document.definitions.len()
}

/// A schema built and checked, outside the timer, as the upstream benches
/// call `Schema::parse_and_validate`.
fn checked(sdl: &str) -> Valid<Schema> {
    Schema::parse_and_validate(sdl, "schema.graphql").expect("valid schema")
}

/// `ExecutableDocument::parse_and_validate`; an invalid document counts its
/// errors.
fn parse_and_validate(schema: &Valid<Schema>, query: &str) -> usize {
    match ExecutableDocument::parse_and_validate(schema, query, "query.graphql") {
        Ok(document) => {
            black_box(&document);
            1
        }
        Err(errors) => errors.errors.len() + 1,
    }
}

/// Measure a validation workload under two names: `apollo-compiler/<name>`,
/// which gql_validation is compared with, and
/// `apollo-compiler-validate/<name>`, which gql_compiler validation is
/// compared with. Both time the same `parse_and_validate`.
fn measure_validate(name: &str, mut work: impl FnMut() -> usize) {
    measure(&format!("apollo-compiler/{name}"), &mut work);
    measure(&format!("apollo-compiler-validate/{name}"), &mut work);
}

fn main() {
    for name in SHARED {
        let text = fixture(&format!("{name}.graphql"));
        measure(&format!("shared/parse-{name}"), || {
            parse(&text).definitions.len()
        });
    }
    for name in SHARED {
        let text = fixture(&format!("{name}.graphql"));
        measure(&format!("shared/parse-print-{name}"), || {
            parse(&text).to_string().len()
        });
    }
    for name in SHARED {
        let document = parse(&fixture(&format!("{name}.graphql")));
        measure(&format!("shared/print-{name}"), || {
            document.to_string().len()
        });
    }

    let text = fixture("graphql-js-introspection-query.graphql");
    measure("graphql-js/parse-introspection-query", || {
        parse(&text).definitions.len()
    });
    let document = parse(&fixture("kitchen-sink.graphql"));
    measure("graphql-js/print-kitchen-sink", || document.to_string().len());

    let query = fixture("apollo-parser-query.graphql");
    let supergraph = fixture("apollo-parser-supergraph.graphql");
    let aliases = fixture("apollo-parser-alias.graphql");
    measure("apollo-parser/query_parser", || parse_query(&query));
    measure("apollo-parser/many_aliases", || parse_query(&aliases));
    measure("apollo-parser/supergraph_parser", || parse_schema(&supergraph));
    let schema = fixture("apollo-compiler-simple-schema.graphql");
    let simple = fixture("apollo-compiler-simple-query.graphql");
    measure("apollo-compiler/simple_query-parse_ast", || {
        parse_ast(&schema, &simple)
    });
    let supergraph_query = fixture("apollo-compiler-supergraph-query.graphql");
    measure("apollo-compiler/supergraph-parse_ast", || {
        parse_ast(&supergraph, &supergraph_query)
    });

    for (workload, file) in GO_TOOLS_PARSE {
        let text = fixture(file);
        measure(workload, || parse(&text).definitions.len());
    }
    let document = parse(&fixture("go-tools-print-operation.graphql"));
    measure("go-tools/Print", || document.to_string().len());

    // apollo-compiler schema building, with no validation: the AST is
    // parsed outside the timer. gql_compiler, the Mojo port of
    // apollo-compiler, runs the same workload.
    let github = parse(&fixture("github-schema.graphql"));
    measure("apollo-compiler/schema-from-ast", || {
        match Schema::builder().add_ast(&github).build() {
            Ok(schema) => schema.types.len(),
            Err(errors) => errors.partial.types.len(),
        }
    });
    // apollo-compiler schema printing: the schema is built outside the
    // timer. gql_compiler.serialize runs the same workload.
    {
        let schema = Schema::builder()
            .add_ast(&github)
            .build()
            .unwrap_or_else(|errors| errors.partial);
        measure("apollo-compiler/schema-serialize", || schema.to_string().len());
    }
    // apollo-compiler executable document building, with no validation:
    // the schema is built and the query parsed outside the timer.
    // gql_compiler.executable runs the same workload.
    {
        use apollo_compiler::validation::DiagnosticList;
        // The builder takes a `Valid` schema. As the Mojo side does, this
        // does not validate it.
        let schema = Valid::assume_valid(
            Schema::builder()
                .add_ast(&github)
                .build()
                .unwrap_or_else(|errors| errors.partial),
        );
        let query = parse(&fixture("github-query.graphql"));
        measure("apollo-compiler/executable-from-ast", || {
            let mut errors = DiagnosticList::new(Default::default());
            let mut builder = ExecutableDocument::builder(Some(&schema), &mut errors);
            builder.add_ast_document(&query, true);
            let document = builder.build();
            let count = document.operations.named.len() + document.fragments.len();
            black_box(document);
            count + errors.len()
        });
    }
    for name in ["github-schema", "go-tools-starwars.schema"] {
        let text = fixture(&format!("{name}.graphql"));
        measure(&format!("shared/parse-build-{name}"), || {
            match Schema::parse(&text, "schema.graphql") {
                Ok(schema) => schema.types.len(),
                Err(errors) => errors.partial.types.len(),
            }
        });
    }

    // Executable validation: benches/fields_validation.rs,
    // fragments_validation.rs and directives_validation.rs. The schema is
    // built and checked outside the timer, and parse_and_validate is timed.
    let hello = checked("type Query { hello: String! }");
    let query = format!("{{ {} }}", "hello ".repeat(1_000));
    measure_validate("many_same_field", || {
        parse_and_validate(&hello, &query)
    });
    let nested = checked(
        "
        type Nested { hello: String! }
        type Query { nested: Nested! }
    ",
    );
    let query = format!("{{ {} }}", "nested { hello } ".repeat(1_000));
    measure_validate("many_same_nested_field", || {
        parse_and_validate(&nested, &query)
    });
    let args = (0..2_000).fold(String::new(), |mut acc, i| {
        use std::fmt::Write;
        _ = writeln!(&mut acc, "arg{i}: {i}");
        acc
    });
    let field = format!("hello({args})");
    let query = format!("{{ {field} {field} }}");
    measure_validate("many_arguments", || {
        parse_and_validate(&hello, &query)
    });
    let types = checked(
        "
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
    ",
    );
    let query = format!(
        "
        fragment multiply on Abstract {{
           field {{
             ... on Abstract1 {{ field {{ leaf }} }}
             ... on Abstract2 {{ field {{ leaf }} }}
             ... on Concrete1 {{ field {{ leaf }} }}
             ... on Concrete2 {{ field {{ leaf }} }}
           }}
        }}

        query DeepAbstractConcrete {{
            {open}{close}
        }}
    ",
        open = "field { ...multiply ".repeat(100),
        close = "}".repeat(100)
    );
    measure_validate("many_types", || {
        parse_and_validate(&types, &query)
    });
    let mut sdl = String::new();
    sdl.push_str("type Query { a: A }\n");
    for i in 1..=10_000 {
        sdl.push_str(&format!("interface I{i} {{ f{i}: String }}\n"));
    }
    sdl.push_str("type A { f0: String }\n");
    for i in 1..=10_000 {
        sdl.push_str(&format!("extend type A implements I{i} {{ f{i}: String }}\n"));
    }
    let extensions = checked(&sdl);
    let mut query = String::new();
    query.push_str("{ a { ");
    for i in 1..=10_000 {
        query.push_str(&format!("f{i} "));
    }
    query.push_str("} }");
    measure_validate("many_extensions", || {
        parse_and_validate(&extensions, &query)
    });
    {
        use std::fmt::Write;
        let mut sdl = String::new();
        for i in 0..200 {
            _ = writeln!(&mut sdl, r#"interface Intf{i} {{ field: Int! }}"#);
        }
        for o in 0..10_000 {
            let i = o % 200;
            _ = writeln!(&mut sdl, r#"type Ty{o} implements Intf{i} {{ field: Int! }}"#);
        }
        _ = writeln!(&mut sdl, "type Query {{");
        for i in 0..200 {
            _ = writeln!(&mut sdl, "  intf{i}: Intf{i}");
        }
        _ = writeln!(&mut sdl, "}}");
        let big = checked(&sdl);
        let mut selection = String::new();
        let mut fragments = String::new();
        for i in 0..200 {
            _ = writeln!(&mut selection, "  intf{i} {{ ...frag{i} }}");
            _ = writeln!(&mut fragments, "fragment frag{i} on Ty{i} {{ field }}");
        }
        let query = format!(
            "query {{
  {selection}}}
{fragments}"
        );
        measure_validate("big_schema_many_fragments", || {
            parse_and_validate(&big, &query)
        });
    }
    let query = format!(
        r#"
        {{
          hello {}
        }}
        "#,
        "@nothing ".repeat(10_000),
    );
    let repeatable = checked(
        r#"
        directive @nothing repeatable on FIELD
        type Query { hello: String! }
        "#,
    );
    measure_validate("many_same_directive_query", || {
        parse_and_validate(&repeatable, &query)
    });
    let plain = checked(
        r#"
        type Query { hello: String! }
        "#,
    );
    measure_validate("many_invalid_directive", || {
        parse_and_validate(&plain, &query)
    });
    // graphql-js benchmark/introspectionFromSchema-benchmark.js, "Execute
    // Introspection Query": the GitHub schema is built with no validation,
    // as `assumeValid: true` builds it, and the document, the implementers
    // map and the variables are ready outside the timer. Only
    // `introspection::partial_execute` is timed.
    {
        use apollo_compiler::introspection::partial_execute;
        use apollo_compiler::request::coerce_variable_values;
        use apollo_compiler::response::JsonMap;
        let schema = Valid::assume_valid(
            Schema::parse(fixture("github-schema.graphql"), "schema.graphql")
                .expect("valid schema"),
        );
        let query = fixture("graphql-js-introspection-query.graphql");
        let document = ExecutableDocument::parse_and_validate(&schema, query, "query.graphql")
            .expect("valid query");
        let operation = document.operations.get(None).expect("one operation");
        let implementers = schema.implementers_map();
        let variables =
            coerce_variable_values(&schema, operation, &JsonMap::new()).expect("no variables");
        measure("graphql-js/execute-introspection-query", || {
            let response =
                partial_execute(&schema, &implementers, &document, operation, &variables)
                    .expect("introspection");
            let ok = response.errors.is_empty() as usize;
            black_box(response);
            ok
        });
    }
}
