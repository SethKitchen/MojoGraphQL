# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The fixtures of graphql-go-tools v2 `v2/pkg/astminify` at 9ef6e24.

`simpleschema.graphql`, `operation1.graphql` to `operation10.graphql`,
`simpleoperation.graphql` and `fixtures/operation<N>.min.graphql.golden`,
byte for byte. They are Mojo strings because `make coverage` copies only
`.mojo` files.
"""

comptime SIMPLE_SCHEMA = """type Query {
    query: [Interface!]!
}

interface Interface {
    name: String!
    age: Int!
}

type ObjectA implements Interface {
    name: String!
    age: Int!
    aField(a: String b: String c: String): ObjectA
    bField(a: String b: String c: String): ObjectB
    cField(a: String b: String c: String): ObjectC
}

type ObjectB implements Interface {
    name: String!
    age: Int!
    aField(a: String b: String c: String): ObjectA
    bField(a: String b: String c: String): ObjectB
    cField(a: String b: String c: String): ObjectC
}

type ObjectC implements Interface {
    name: String!
    age: Int!
    aField(a: String b: String c: String): ObjectA
    bField(a: String b: String c: String): ObjectB
    cField(a: String b: String c: String): ObjectC
}

directive @abc(a: String b: String c: String) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT"""
"""Upstream `simpleschema.graphql`."""

comptime SIMPLE_OPERATION = """{
    query {
        ... on ObjectA {
            __typename
            age
            name
        }
        ... on ObjectB {
            aField {
                __typename
                age
                name
            }
        }
        ... on ObjectC {
            aField {
                __typename
                age
                name
            }
        }
    }
}"""
"""Upstream `simpleoperation.graphql`."""

comptime OPERATION_1 = """query MyQuery {
  query {
    ... on ObjectA {
      __typename
      age
      aField {
        __typename
        age
        name
      }
      bField {
        __typename
        age
        name
      }
      cField {
        __typename
        age
        name
      }
      name
    }
    ... on ObjectB {
      __typename
      age
      aField {
        __typename
        age
        name
      }
      bField {
        __typename
        age
        name
      }
      cField {
        __typename
        age
        name
      }
      name
    }
    ... on ObjectC {
      __typename
      age
      aField {
        __typename
        age
        name
      }
      bField {
        __typename
        age
        name
      }
      cField {
        __typename
        age
        name
      }
      name
    }
  }
}"""
"""Upstream `operation1.graphql`."""

comptime MINIFIED_1 = """query MyQuery {
    query {
        ... on ObjectA {
            __typename
            aField {
                ...C
            }
            age
            bField {
                ...B
            }
            cField {
                ...A
            }
            name
        }
        ... on ObjectB {
            __typename
            aField {
                ...C
            }
            age
            bField {
                ...B
            }
            cField {
                ...A
            }
            name
        }
        ... on ObjectC {
            __typename
            aField {
                ...C
            }
            age
            bField {
                ...B
            }
            cField {
                ...A
            }
            name
        }
    }
}

fragment A on ObjectC {
    __typename
    age
    name
}

fragment B on ObjectB {
    __typename
    age
    name
}

fragment C on ObjectA {
    __typename
    age
    name
}"""
"""Upstream `fixtures/operation1.min.graphql.golden`."""

comptime OPERATION_2 = """query MyQuery {
  query {
    ... on ObjectA {
      __typename
      age
      name
    }
    ... on ObjectB {
      __typename
      age
      aField {
        __typename
        age
        name
      }
      name
    }
    ... on ObjectC {
      __typename
      age
      aField {
        __typename
        age
        name
      }
      name
    }
  }
}"""
"""Upstream `operation2.graphql`."""

comptime MINIFIED_2 = """query MyQuery {
    query {
        ...A
        ... on ObjectB {
            __typename
            aField {
                ...A
            }
            age
            name
        }
        ... on ObjectC {
            __typename
            aField {
                ...A
            }
            age
            name
        }
    }
}

fragment A on ObjectA {
    __typename
    age
    name
}"""
"""Upstream `fixtures/operation2.min.graphql.golden`."""

comptime OPERATION_3 = """query MyQuery {
  query {
    ... on ObjectA {
      __typename
      age
      name
    }
    ... on ObjectB {
      aField {
        __typename
        age
        name
      }
    }
    ... on ObjectC {
      aField {
        __typename
        age
        name
      }
    }
  }
}"""
"""Upstream `operation3.graphql`."""

comptime MINIFIED_3 = """query MyQuery {
    query {
        ...A
        ... on ObjectB {
            aField {
                ...A
            }
        }
        ... on ObjectC {
            aField {
                ...A
            }
        }
    }
}

fragment A on ObjectA {
    __typename
    age
    name
}"""
"""Upstream `fixtures/operation3.min.graphql.golden`."""

comptime OPERATION_4 = """query MyQuery {
  query {
    ... on ObjectA {
      __typename
      age
      name
    }
    ... on ObjectB {
      aField {
        age
        __typename
        name
      }
    }
    ... on ObjectC {
      aField {
        __typename
        name
        age
      }
    }
  }
}"""
"""Upstream `operation4.graphql`."""

comptime MINIFIED_4 = """query MyQuery {
    query {
        ...A
        ... on ObjectB {
            aField {
                ...A
            }
        }
        ... on ObjectC {
            aField {
                ...A
            }
        }
    }
}

fragment A on ObjectA {
    __typename
    age
    name
}"""
"""Upstream `fixtures/operation4.min.graphql.golden`."""

comptime OPERATION_5 = """query MyQuery {
  query {
    ... on ObjectB {
      aField(a: "a", b: "b") {
        age
        __typename
        name
      }
    }
    ... on ObjectC {
      aField(b: "b" a: "a") {
        __typename
        name
        age
      }
    }
  }
}"""
"""Upstream `operation5.graphql`."""

comptime MINIFIED_5 = """query MyQuery {
    query {
        ... on ObjectB {
            aField(a: "a", b: "b"){
                ...A
            }
        }
        ... on ObjectC {
            aField(a: "a", b: "b"){
                ...A
            }
        }
    }
}

fragment A on ObjectA {
    __typename
    age
    name
}"""
"""Upstream `fixtures/operation5.min.graphql.golden`."""

comptime OPERATION_6 = """query MyQuery {
  query {
    ... on ObjectB {
      ... on Interface {
        ... on ObjectC {
          aField(a: "a", b: "b") {
            age
            __typename
            name
          }
        }
      }
    }
    ... on ObjectC {
      aField(b: "b" a: "a") {
        __typename
        name
        age
      }
    }
  }
}"""
"""Upstream `operation6.graphql`."""

comptime MINIFIED_6 = """query MyQuery {
    query {
        ... on ObjectB {
            ... on Interface {
                ...B
            }
        }
        ...B
    }
}

fragment A on ObjectA {
    __typename
    age
    name
}

fragment B on ObjectC {
    aField(a: "a", b: "b"){
        ...A
    }
}"""
"""Upstream `fixtures/operation6.min.graphql.golden`."""

comptime OPERATION_7 = """query MyQuery ($skip: Boolean! $include: Boolean!) {
    query {
        ... on ObjectB {
            ... on Interface {
                ... on ObjectC {
                    aField @skip(if: $skip) @include(if: $include) {
                        age
                        __typename
                        name
                    }
                }
            }
        }
        ... on ObjectC {
            aField @include(if: $include) @skip(if: $skip) {
                __typename
                name
                age
            }
        }
    }
}"""
"""Upstream `operation7.graphql`."""

comptime MINIFIED_7 = """query MyQuery($skip: Boolean!, $include: Boolean!){
    query {
        ... on ObjectB {
            ... on Interface {
                ...B
            }
        }
        ...B
    }
}

fragment A on ObjectA @include(if: $include) @skip(if: $skip) {
    __typename
    age
    name
}

fragment B on ObjectC {
    aField @include(if: $include) @skip(if: $skip) {
        ...A
    }
}"""
"""Upstream `fixtures/operation7.min.graphql.golden`."""

comptime OPERATION_8 = """query MyQuery ($skip: Boolean! $include: Boolean!) {
    query {
        ... on ObjectB {
            ... on Interface {
                ... on ObjectC @skip(if: $skip) @include(if: $include) {
                    aField {
                        age
                        __typename
                        name
                    }
                }
            }
        }
        ... on ObjectC @include(if: $include) @skip(if: $skip) {
            aField {
                __typename
                name
                age
            }
        }
    }
}"""
"""Upstream `operation8.graphql`."""

comptime MINIFIED_8 = """query MyQuery($skip: Boolean!, $include: Boolean!){
    query {
        ... on ObjectB {
            ... on Interface {
                ...B
            }
        }
        ...B
    }
}

fragment A on ObjectA {
    __typename
    age
    name
}

fragment B on ObjectC @include(if: $include) @skip(if: $skip) {
    aField {
        ...A
    }
}"""
"""Upstream `fixtures/operation8.min.graphql.golden`."""

comptime OPERATION_9 = """query MyQuery {
  query {
    ... on ObjectA {
      __typename
      a: age
      b: age
      c: name
      d: name
    }
    ... on ObjectB {
      aField {
        b: age
        a: age
        __typename
        d: name
        c: name
      }
    }
    ... on ObjectC {
      aField {
        __typename
        c: name
        d: name
        a: age
        b: age
      }
    }
  }
}"""
"""Upstream `operation9.graphql`."""

comptime MINIFIED_9 = """query MyQuery {
    query {
        ...A
        ... on ObjectB {
            aField {
                ...A
            }
        }
        ... on ObjectC {
            aField {
                ...A
            }
        }
    }
}

fragment A on ObjectA {
    __typename
    a: age
    b: age
    c: name
    d: name
}"""
"""Upstream `fixtures/operation9.min.graphql.golden`."""

comptime OPERATION_10 = """query MyQuery ($skip: Boolean! $include: Boolean!) {
    query {
        ... on ObjectB {
            ... on Interface {
                ... on ObjectC @abc(a: "a" b: "b") {
                    aField {
                        age
                        __typename
                        name
                    }
                }
            }
        }
        ... on ObjectC @abc(b: "b" a: "a") {
            aField {
                __typename
                name
                age
            }
        }
    }
}"""
"""Upstream `operation10.graphql`."""

comptime MINIFIED_10 = """query MyQuery($skip: Boolean!, $include: Boolean!){
    query {
        ... on ObjectB {
            ... on Interface {
                ...B
            }
        }
        ...B
    }
}

fragment A on ObjectA {
    __typename
    age
    name
}

fragment B on ObjectC @abc(a: "a", b: "b") {
    aField {
        ...A
    }
}"""
"""Upstream `fixtures/operation10.min.graphql.golden`."""
