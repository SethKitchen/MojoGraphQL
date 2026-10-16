# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for MaxIntrospectionDepthRule, ported from graphql-js 16.14.2
`src/validation/__tests__/MaxIntrospectionDepthRule-test.ts`.

The port has no `getIntrospectionQuery`. The two introspection query tests
use the text that graphql-js 16.14.2 `getIntrospectionQuery()` returns, with
the default options and with all the options. The trailing spaces on its
blank lines are removed.
"""

from _harness import expect_errors, expect_valid
from gql_validation.rules import ValidationRule
from std.testing import TestSuite

comptime RULE = ValidationRule.MAX_INTROSPECTION_DEPTH
"""The rule under test."""

comptime INTROSPECTION_QUERY = """
    query IntrospectionQuery {
      __schema {

        queryType { name kind }
        mutationType { name kind }
        subscriptionType { name kind }
        types {
          ...FullType
        }
        directives {
          name
          description



          locations
          args {
            ...InputValue
          }
        }
      }
    }

    fragment FullType on __Type {
      kind
      name
      description


      fields(includeDeprecated: true) {
        name
        description
        args {
          ...InputValue
        }
        type {
          ...TypeRef
        }
        isDeprecated
        deprecationReason
      }
      inputFields {
        ...InputValue
      }
      interfaces {
        ...TypeRef
      }
      enumValues(includeDeprecated: true) {
        name
        description
        isDeprecated
        deprecationReason
      }
      possibleTypes {
        ...TypeRef
      }
    }

    fragment InputValue on __InputValue {
      name
      description
      type { ...TypeRef }
      defaultValue


    }

    fragment TypeRef on __Type {
      kind
      name
      ofType {
        name
        kind
        ofType {
          name
          kind
          ofType {
            name
            kind
            ofType {
              name
              kind
              ofType {
                name
                kind
                ofType {
                  name
                  kind
                  ofType {
                    name
                    kind
                    ofType {
                      name
                      kind
                      ofType {
                        name
                        kind
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  """
"""The text of graphql-js `getIntrospectionQuery()`."""

comptime ALL_OPTIONS_INTROSPECTION_QUERY = """
    query IntrospectionQuery {
      __schema {
        description
        queryType { name kind }
        mutationType { name kind }
        subscriptionType { name kind }
        types {
          ...FullType
        }
        directives {
          name
          description
          isRepeatable


          locations
          args(includeDeprecated: true) {
            ...InputValue
          }
        }
      }
    }

    fragment FullType on __Type {
      kind
      name
      description
      specifiedByURL

      fields(includeDeprecated: true) {
        name
        description
        args(includeDeprecated: true) {
          ...InputValue
        }
        type {
          ...TypeRef
        }
        isDeprecated
        deprecationReason
      }
      inputFields(includeDeprecated: true) {
        ...InputValue
      }
      interfaces {
        ...TypeRef
      }
      enumValues(includeDeprecated: true) {
        name
        description
        isDeprecated
        deprecationReason
      }
      possibleTypes {
        ...TypeRef
      }
    }

    fragment InputValue on __InputValue {
      name
      description
      type { ...TypeRef }
      defaultValue
      isDeprecated
      deprecationReason
    }

    fragment TypeRef on __Type {
      kind
      name
      ofType {
        name
        kind
        ofType {
          name
          kind
          ofType {
            name
            kind
            ofType {
              name
              kind
              ofType {
                name
                kind
                ofType {
                  name
                  kind
                  ofType {
                    name
                    kind
                    ofType {
                      name
                      kind
                      ofType {
                        name
                        kind
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  """
"""The text of graphql-js `getIntrospectionQuery()` with every option on."""

comptime MESSAGE = "Maximum introspection depth exceeded"
"""The error message of the rule."""


def test_default_introspection_query() raises:
    expect_valid(RULE, INTROSPECTION_QUERY)


def test_all_options_introspection_query() raises:
    expect_valid(RULE, ALL_OPTIONS_INTROSPECTION_QUERY)


def test_3_flat_fields_introspection_query() raises:
    expect_valid(
        RULE,
        """
    {
      __type(name: "Query") {
        trueFields: fields(includeDeprecated: true) {
          name
        }
        falseFields: fields(includeDeprecated: false) {
          name
        }
        omittedFields: fields {
          name
        }
      }
    }
    """,
    )


def test_3_fields_deep_introspection_query_from_schema() raises:
    expect_errors(
        RULE,
        """
    {
      __schema {
        types {
          fields {
            type {
              fields {
                type {
                  fields {
                    name
                  }
                }
              }
            }
          }
        }
      }
    }
    """,
        [String(MESSAGE) + " (3:7)"],
    )


def test_3_interfaces_deep_introspection_query_from_schema() raises:
    expect_errors(
        RULE,
        """
    {
      __schema {
        types {
          interfaces {
            interfaces {
              interfaces {
                name
              }
            }
          }
        }
      }
    }
    """,
        [String(MESSAGE) + " (3:7)"],
    )


def test_3_possible_types_deep_introspection_query_from_schema() raises:
    expect_errors(
        RULE,
        """
    {
      __schema {
        types {
          possibleTypes {
            possibleTypes {
              possibleTypes {
                name
              }
            }
          }
        }
      }
    }
    """,
        [String(MESSAGE) + " (3:7)"],
    )


def test_3_input_fields_deep_introspection_query_from_schema() raises:
    expect_errors(
        RULE,
        """
    {
      __schema {
        types {
          inputFields {
            type {
              inputFields {
                type {
                  inputFields {
                    type {
                      name
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    """,
        [String(MESSAGE) + " (3:7)"],
    )


def test_3_fields_deep_introspection_query_from_multiple_schema() raises:
    expect_errors(
        RULE,
        """
    {
      one: __schema {
        types {
          fields {
            type {
              fields {
                type {
                  fields {
                    name
                  }
                }
              }
            }
          }
        }
      }
      two: __schema {
        types {
          fields {
            type {
              fields {
                type {
                  fields {
                    name
                  }
                }
              }
            }
          }
        }
      }
      three: __schema {
        types {
          fields {
            type {
              fields {
                type {
                  fields {
                    name
                  }
                }
              }
            }
          }
        }
      }
    }
    """,
        [
            String(MESSAGE) + " (3:7)",
            String(MESSAGE) + " (18:7)",
            String(MESSAGE) + " (33:7)",
        ],
    )


def test_3_fields_deep_introspection_query_from_type() raises:
    expect_errors(
        RULE,
        """
    {
      __type(name: "Query") {
        types {
          fields {
            type {
              fields {
                type {
                  fields {
                    name
                  }
                }
              }
            }
          }
        }
      }
    }
    """,
        [String(MESSAGE) + " (3:7)"],
    )


def test_3_fields_deep_introspection_query_from_multiple_type() raises:
    expect_errors(
        RULE,
        """
    {
      one: __type(name: "Query") {
        types {
          fields {
            type {
              fields {
                type {
                  fields {
                    name
                  }
                }
              }
            }
          }
        }
      }
      two: __type(name: "Query") {
        types {
          fields {
            type {
              fields {
                type {
                  fields {
                    name
                  }
                }
              }
            }
          }
        }
      }
      three: __type(name: "Query") {
        types {
          fields {
            type {
              fields {
                type {
                  fields {
                    name
                  }
                }
              }
            }
          }
        }
      }
    }
    """,
        [
            String(MESSAGE) + " (3:7)",
            String(MESSAGE) + " (18:7)",
            String(MESSAGE) + " (33:7)",
        ],
    )


def test_1_fields_deep_with_3_fields_introspection_query() raises:
    expect_valid(
        RULE,
        """
    {
      __schema {
        types {
          fields {
            type {
              oneFields: fields {
                name
              }
              twoFields: fields {
                name
              }
              threeFields: fields {
                name
              }
            }
          }
        }
      }
    }
    """,
    )


def test_3_fields_deep_from_varying_parents_introspection_query() raises:
    expect_errors(
        RULE,
        """
    {
      __schema {
        types {
          fields {
            type {
              fields {
                type {
                  ofType {
                    fields {
                      name
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    """,
        [String(MESSAGE) + " (3:7)"],
    )


def test_3_fields_deep_introspection_query_with_inline_fragments() raises:
    expect_errors(
        RULE,
        """
    query test {
      __schema {
        types {
          ... on __Type {
            fields {
              type {
                ... on __Type {
                  ofType {
                    fields {
                      type {
                        ... on __Type {
                          fields {
                            name
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    """,
        [String(MESSAGE) + " (3:7)"],
    )


def test_3_fields_deep_introspection_query_with_fragments() raises:
    expect_errors(
        RULE,
        """
    query test {
      __schema {
        types {
          ...One
        }
      }
    }

    fragment One on __Type {
      fields {
        type {
          ...Two
        }
      }
    }

    fragment Two on __Type {
      fields {
        type {
          ...Three
        }
      }
    }

    fragment Three on __Type {
      fields {
        name
      }
    }
    """,
        [String(MESSAGE) + " (3:7)"],
    )


def test_3_fields_deep_inside_inline_fragment_on_query() raises:
    expect_errors(
        RULE,
        """
    {
      ... {
        __schema { types { fields { type { fields { type { fields { name } } } } } } }
      }
    }
    """,
        [String(MESSAGE) + " (4:9)"],
    )


def test_opts_out_if_fragment_is_missing() raises:
    expect_valid(
        RULE,
        """
    query test {
      __schema {
        types {
          ...Missing
        }
      }
    }
    """,
    )


def test_doesnt_infinitely_recurse_on_fragment_cycle() raises:
    expect_valid(
        RULE,
        """
    query test {
      __schema {
        types {
          ...Cycle
        }
      }
    }
    fragment Cycle on __Type {
      ...Cycle
    }
    """,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
