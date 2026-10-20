// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

//! apollo-parser 0.8: the lossless CST parser under apollo-compiler, the
//! Apollo Router and Rover. It runs every workload it can express: it
//! parses and lexes all of them, and has no printer.
//!
//! `parse_query`, `parse_schema` and the lexer loop are copied from
//! crates/apollo-parser/benches/query.rs and supergraph.rs.

use apollo_parser::cst;
use apollo_parser::{Lexer, Parser};
use mojographql_bench_apollo_rs::{fixture, measure, GO_TOOLS_PARSE, SHARED};

/// Parse, and check that there are no errors.
fn parse(text: &str) -> usize {
    let tree = Parser::new(text).parse();
    assert_eq!(tree.errors().len(), 0);
    tree.token_limit().high as usize
}

/// benches/query.rs `parse_query`.
fn parse_query(query: &str) -> usize {
    let parser = apollo_parser::Parser::new(query);
    let tree = parser.parse();

    if tree.errors().len() != 0 {
        panic!("error parsing query: {:?}", tree.errors());
    }
    let document = tree.document();

    // Simulate a basic selection set traversal operation.
    for definition in document.definitions() {
        if let cst::Definition::OperationDefinition(operation) = definition {
            let selection_set = operation
                .selection_set()
                .expect("the node SelectionSet is not optional in the spec; qed");
            for selection in selection_set.selections() {
                if let cst::Selection::Field(field) = selection {
                    std::hint::black_box(field.selection_set());
                }
            }
        }
    }
    1
}

/// benches/supergraph.rs `parse_schema`.
fn parse_schema(schema: &str) -> usize {
    let parser = apollo_parser::Parser::new(schema);
    let tree = parser.parse();
    let errors = tree.errors().collect::<Vec<_>>();

    if !errors.is_empty() {
        panic!("error parsing query: {errors:?}");
    }

    let document = tree.document();

    // Simulate a basic field traversal operation.
    for definition in document.definitions() {
        if let cst::Definition::ObjectTypeDefinition(operation) = definition {
            let fields = operation
                .fields_definition()
                .expect("the node FieldsDefinition is not optional in the spec; qed");
            for field in fields.field_definitions() {
                std::hint::black_box(field.ty());
            }
        }
    }
    1
}

/// The lexer loop of benches/query.rs and supergraph.rs.
fn lex(text: &str) -> usize {
    let lexer = Lexer::new(text);
    let mut count = 0;
    for token_res in lexer {
        std::hint::black_box(token_res.unwrap());
        count += 1;
    }
    count
}

fn main() {
    for name in SHARED {
        let text = fixture(&format!("{name}.graphql"));
        measure(&format!("shared/parse-{name}"), || parse(&text));
    }

    let text = fixture("graphql-js-introspection-query.graphql");
    measure("graphql-js/parse-introspection-query", || parse(&text));

    let query = fixture("apollo-parser-query.graphql");
    let supergraph = fixture("apollo-parser-supergraph.graphql");
    let aliases = fixture("apollo-parser-alias.graphql");
    measure("apollo-parser/query_parser", || parse_query(&query));
    measure("apollo-parser/query_lexer", || lex(&query));
    measure("apollo-parser/many_aliases", || parse_query(&aliases));
    measure("apollo-parser/supergraph_parser", || parse_schema(&supergraph));
    measure("apollo-parser/supergraph_lexer", || lex(&supergraph));
    // The same closures, against the recovering parser of gql_compiler.
    measure("apollo-parser-recovering/query_parser", || parse_query(&query));
    measure("apollo-parser-recovering/many_aliases", || {
        parse_query(&aliases)
    });
    measure("apollo-parser-recovering/supergraph_parser", || {
        parse_schema(&supergraph)
    });
    let schema = fixture("apollo-compiler-simple-schema.graphql");
    let simple = fixture("apollo-compiler-simple-query.graphql");
    measure("apollo-compiler/simple_query-parse_ast", || {
        parse(&schema) + parse(&simple)
    });
    let supergraph_query = fixture("apollo-compiler-supergraph-query.graphql");
    measure("apollo-compiler/supergraph-parse_ast", || {
        parse(&supergraph) + parse(&supergraph_query)
    });

    for (workload, file) in GO_TOOLS_PARSE {
        let text = fixture(file);
        measure(workload, || parse(&text));
    }
    let introspection = fixture("go-tools-introspection-query.graphql");
    measure("go-tools/Lexer", || lex(&introspection));
}
