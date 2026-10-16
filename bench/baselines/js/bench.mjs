// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Noncommercial use is free; commercial use requires a paid license.
// See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

// The graphql-js 16.14.2 baseline: what Apollo Server, @apollo/subgraph and
// Apollo Client run on. It prints `BENCH <workload> <ns per op>` lines with
// the same method as bench/gql_language/_harness.mojo: warm up, then rounds
// of at least ROUND_NS each, and report the fastest round.
//
// It runs every workload that graphql-js can express: parse, print and lex
// all of them. Work that an upstream benchmark does outside its timer, such
// as parsing the document a print benchmark prints, happens in setup.

import { readFileSync } from 'node:fs';
import {
  Kind,
  Lexer,
  Source,
  TokenKind,
  buildASTSchema,
  buildClientSchema,
  buildSchema,
  executeSync,
  getIntrospectionQuery,
  parse,
  print,
  stripIgnoredCharacters,
  validate,
} from 'graphql';
import { validateSDL } from 'graphql/validation/validate.js';

const FIXTURES = new URL('../../fixtures/', import.meta.url);
const ROUND_NS = 1_000_000_000n;
const ROUNDS = 5;
const WARMUP_NS = 200_000_000n;

let sink = 0;

function run(work, iterations) {
  const start = process.hrtime.bigint();
  for (let i = 0; i < iterations; i++) {
    sink += work();
  }
  return process.hrtime.bigint() - start;
}

function measure(name, work) {
  let iterations = 1;
  let warm = 0n;
  for (;;) {
    const elapsed = run(work, iterations);
    warm += elapsed;
    if (elapsed * 4n >= WARMUP_NS || warm >= WARMUP_NS) {
      let perOp = elapsed / BigInt(iterations);
      if (perOp < 1n) perOp = 1n;
      iterations = Number(ROUND_NS / perOp) || 1;
      break;
    }
    iterations *= 2;
  }
  let best = Infinity;
  for (let round = 0; round < ROUNDS; round++) {
    const elapsed = Number(run(work, iterations));
    best = Math.min(best, elapsed / iterations);
  }
  console.log(`BENCH ${name} ${best.toFixed(1)}`);
}

const fixture = (name) => readFileSync(new URL(name, FIXTURES), 'utf8');

// One operation of each kind. Each returns a number so the work is used.
const parseOnce = (text) => () => parse(text).definitions.length;
const parseTwo = (schema, query) => () =>
  parse(schema).definitions.length + parse(query).definitions.length;
const parsePrint = (text) => () => print(parse(text)).length;
const printOnly = (text) => {
  const document = parse(text);
  return () => print(document).length;
};
const lex = (text) => () => {
  const lexer = new Lexer(new Source(text));
  let count = 0;
  while (lexer.advance().kind !== TokenKind.EOF) count++;
  return count;
};
// apollo-parser `parse_query`: visit the selection set of each top-level
// field of each operation.
const parseWalkQuery = (text) => () => {
  let found = 0;
  for (const definition of parse(text).definitions) {
    if (definition.kind === Kind.OPERATION_DEFINITION) {
      for (const selection of definition.selectionSet.selections) {
        if (selection.kind === Kind.FIELD && selection.selectionSet) found++;
      }
    }
  }
  return found;
};
// apollo-parser `parse_schema`: visit the type of each field of each object
// type definition.
const parseWalkSchema = (text) => () => {
  let found = 0;
  for (const definition of parse(text).definitions) {
    if (definition.kind === Kind.OBJECT_TYPE_DEFINITION) {
      for (const field of definition.fields ?? []) {
        if (field.type) found++;
      }
    }
  }
  return found;
};

const shared = ['kitchen-sink', 'github-schema', 'github-query'];
for (const name of shared) {
  measure(`shared/parse-${name}`, parseOnce(fixture(`${name}.graphql`)));
}
for (const name of shared) {
  measure(`shared/parse-print-${name}`, parsePrint(fixture(`${name}.graphql`)));
}
for (const name of shared) {
  measure(`shared/print-${name}`, printOnly(fixture(`${name}.graphql`)));
}

measure(
  'graphql-js/parse-introspection-query',
  parseOnce(fixture('graphql-js-introspection-query.graphql')),
);
measure(
  'graphql-js/print-kitchen-sink',
  printOnly(fixture('kitchen-sink.graphql')),
);

const query = fixture('apollo-parser-query.graphql');
const supergraph = fixture('apollo-parser-supergraph.graphql');
measure('apollo-parser/query_parser', parseWalkQuery(query));
measure('apollo-parser/query_lexer', lex(query));
measure(
  'apollo-parser/many_aliases',
  parseWalkQuery(fixture('apollo-parser-alias.graphql')),
);
measure('apollo-parser/supergraph_parser', parseWalkSchema(supergraph));
measure('apollo-parser/supergraph_lexer', lex(supergraph));
measure(
  'apollo-compiler/simple_query-parse_ast',
  parseTwo(
    fixture('apollo-compiler-simple-schema.graphql'),
    fixture('apollo-compiler-simple-query.graphql'),
  ),
);
measure(
  'apollo-compiler/supergraph-parse_ast',
  parseTwo(supergraph, fixture('apollo-compiler-supergraph-query.graphql')),
);

const introspection = fixture('go-tools-introspection-query.graphql');
measure(
  'go-tools/ParseStarwars',
  parseOnce(fixture('go-tools-starwars.schema.graphql')),
);
measure(
  'go-tools/ParseGithub',
  parseOnce(fixture('go-tools-github.schema.graphql')),
);
measure(
  'go-tools/SelectionSet',
  parseOnce(fixture('go-tools-selection-set.graphql')),
);
measure('go-tools/IntrospectionQuery', parseOnce(introspection));
measure(
  'go-tools/KitchenSink',
  parseOnce(fixture('go-tools-kitchen-sink.graphql')),
);
measure('go-tools/Parse', parseOnce(fixture('go-tools-parse-input.graphql')));
measure('go-tools/Print', printOnly(fixture('go-tools-print-operation.graphql')));
measure('go-tools/Lexer', lex(introspection));

// Schema building, with no SDL validation. benchmark/buildASTSchema-benchmark.js
// parses outside the timer and passes `assumeValid: true`.
const githubSchema = parse(fixture('github-schema.graphql'));
measure('graphql-js/build-ast-schema', () =>
  buildASTSchema(githubSchema, { assumeValid: true }).getTypeMap() ? 1 : 0,
);
for (const name of ['github-schema', 'go-tools-starwars.schema']) {
  const text = fixture(`${name}.graphql`);
  measure(`shared/parse-build-${name}`, () =>
    buildSchema(text, { assumeValid: true }).getTypeMap() ? 1 : 0,
  );
}

// benchmark/validateSDL-benchmark.js: the parsed GitHub schema SDL.
measure('graphql-js/validate-sdl', () => validateSDL(githubSchema).length + 1);

// Validation. benchmark/validateGQL-benchmark.js and
// validateInvalidGQL-benchmark.js build the GitHub schema with
// `assumeValid: true` and parse the document outside the timer.
const bigSchema = buildSchema(fixture('github-schema.graphql'), {
  assumeValid: true,
});
const introspectionAST = parse(getIntrospectionQuery());
measure('graphql-js/validate-introspection-query', () =>
  validate(bigSchema, introspectionAST).length + 1,
);
const invalidAST = parse(`
  {
    unknownField
    ... on unknownType {
      anotherUnknownField
      ...unknownFragment
    }
  }

  fragment TestFragment on anotherUnknownType {
    yetAnotherUnknownField
  }
`);
measure('graphql-js/validate-invalid-query', () =>
  validate(bigSchema, invalidAST).length + 1,
);

// The apollo-compiler benches/fields_validation.rs, fragments_validation.rs
// and directives_validation.rs workloads: the schema is built and checked
// outside the timer, and parse plus validate is timed, as
// `ExecutableDocument::parse_and_validate` does.
const checked = (sdl) => {
  const schema = buildSchema(sdl);
  validate(schema, parse('{ __typename }'));
  return schema;
};
const parseValidate = (schema, query) => () =>
  validate(schema, parse(query)).length + 1;
const hello = checked('type Query { hello: String! }');
measure(
  'apollo-compiler/many_same_field',
  parseValidate(hello, `{ ${'hello '.repeat(1000)} }`),
);
measure(
  'apollo-compiler/many_same_nested_field',
  parseValidate(
    checked(`
        type Nested { hello: String! }
        type Query { nested: Nested! }
    `),
    `{ ${'nested { hello } '.repeat(1000)} }`,
  ),
);
let args = '';
for (let i = 0; i < 2000; i++) args += `arg${i}: ${i}\n`;
const manyArgs = `hello(${args})`;
measure(
  'apollo-compiler/many_arguments',
  parseValidate(hello, `{ ${manyArgs} ${manyArgs} }`),
);
measure(
  'apollo-compiler/many_types',
  parseValidate(
    checked(`
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
    `),
    `
        fragment multiply on Abstract {
           field {
             ... on Abstract1 { field { leaf } }
             ... on Abstract2 { field { leaf } }
             ... on Concrete1 { field { leaf } }
             ... on Concrete2 { field { leaf } }
           }
        }

        query DeepAbstractConcrete {
            ${'field { ...multiply '.repeat(100)}${'}'.repeat(100)}
        }
    `,
  ),
);
let extensions = 'type Query { a: A }\n';
for (let i = 1; i <= 10000; i++) extensions += `interface I${i} { f${i}: String }\n`;
extensions += 'type A { f0: String }\n';
for (let i = 1; i <= 10000; i++) {
  extensions += `extend type A implements I${i} { f${i}: String }\n`;
}
let extensionQuery = '{ a { ';
for (let i = 1; i <= 10000; i++) extensionQuery += `f${i} `;
extensionQuery += '} }';
measure(
  'apollo-compiler/many_extensions',
  parseValidate(checked(extensions), extensionQuery),
);
let bigSdl = '';
for (let i = 0; i < 200; i++) bigSdl += `interface Intf${i} { field: Int! }\n`;
for (let o = 0; o < 10000; o++) {
  bigSdl += `type Ty${o} implements Intf${o % 200} { field: Int! }\n`;
}
bigSdl += 'type Query {\n';
for (let i = 0; i < 200; i++) bigSdl += `  intf${i}: Intf${i}\n`;
bigSdl += '}\n';
let selection = '';
let fragments = '';
for (let i = 0; i < 200; i++) {
  selection += `  intf${i} { ...frag${i} }\n`;
  fragments += `fragment frag${i} on Ty${i} { field }\n`;
}
measure(
  'apollo-compiler/big_schema_many_fragments',
  parseValidate(checked(bigSdl), `query {\n  ${selection}}\n${fragments}`),
);
const directiveQuery = `
        {
          hello ${'@nothing '.repeat(10000)}
        }
        `;
measure(
  'apollo-compiler/many_same_directive_query',
  parseValidate(
    checked(`
        directive @nothing repeatable on FIELD
        type Query { hello: String! }
        `),
    directiveQuery,
  ),
);
measure(
  'apollo-compiler/many_invalid_directive',
  parseValidate(
    checked(`
        type Query { hello: String! }
        `),
    directiveQuery,
  ),
);

// stripIgnoredCharacters, against bench/gql_language/strip.mojo.
const strip = (text) => () => stripIgnoredCharacters(text).length;
measure(
  'shared/strip-ignored-kitchen-sink',
  strip(fixture('kitchen-sink.graphql')),
);
measure(
  'shared/strip-ignored-github-schema',
  strip(fixture('github-schema.graphql')),
);

// Execution. benchmark/introspectionFromSchema-benchmark.js builds the GitHub
// schema with `assumeValid: true` and parses the document outside the
// timer, and times `executeSync`. benchmark/repeated-fields-benchmark.js
// times `graphqlSync`; the Mojo workload has no validation, so this one
// times `parse` and `executeSync`, as the Mojo one does.
{
  const introspectionDocument = parse(
    fixture('graphql-js-introspection-query.graphql'),
  );
  measure('graphql-js/execute-introspection-query', () =>
    executeSync({ schema: bigSchema, document: introspectionDocument }).data
      ? 1
      : 0,
  );
  const helloSchema = buildSchema('type Query { hello: String! }');
  const repeated = `{ ${'hello '.repeat(250)}}`;
  measure('graphql-js/repeated-fields-parse-execute', () =>
    executeSync({ schema: helloSchema, document: parse(repeated) }).errors
      .length,
  );
  // benchmark/buildClientSchema-benchmark.js reads the GitHub introspection
  // result outside the timer and times `buildClientSchema`.
  const introspectionResult = JSON.parse(fixture('github-schema.json'));
  measure('graphql-js/build-client-schema', () =>
    buildClientSchema(introspectionResult.data, { assumeValid: true })
      .getTypeMap()
      ? 1
      : 0,
  );
}

if (sink === 0) throw new Error('no work was done');
