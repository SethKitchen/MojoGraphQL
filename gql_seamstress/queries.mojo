# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The introspection queries that Rover sends, byte for byte.

Copies of Rover `crates/rover-client/src/operations/subgraph/introspect/
introspect_query.graphql` and `graph/introspect/introspect_query.graphql`
and `introspect_query_legacy.graphql`. graphql_client sends the text of
the query file as it is.
"""

comptime SUBGRAPH_INTROSPECT_QUERY = """query SubgraphIntrospectQuery {
    _service {
        sdl
    }
}
"""
"""The `_service { sdl }` query of `rover subgraph introspect`."""

comptime SUBGRAPH_INTROSPECT_QUERY_NAME = "SubgraphIntrospectQuery"
"""The operation name of `SUBGRAPH_INTROSPECT_QUERY`."""

comptime GRAPH_INTROSPECT_QUERY = """query GraphIntrospectQuery {
  __schema {
    queryType {
      name
    }
    mutationType {
      name
    }
    subscriptionType {
      name
    }
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
    args(includeDeprecated:true) {
      ...InputValue
    }
    type {
      ...TypeRef
    }
    isDeprecated
    deprecationReason
  }
  inputFields(includeDeprecated:true) {
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
  type {
    ...TypeRef
  }
  defaultValue
  isDeprecated
  deprecationReason
}

fragment TypeRef on __Type {
  kind
  name
  ofType {
    kind
    name
    ofType {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
              }
            }
          }
        }
      }
    }
  }
}"""
"""The introspection query of `rover graph introspect`."""

comptime GRAPH_INTROSPECT_QUERY_NAME = "GraphIntrospectQuery"
"""The operation name of `GRAPH_INTROSPECT_QUERY`."""

comptime GRAPH_INTROSPECT_LEGACY_QUERY = """query GraphIntrospectLegacyQuery {
  __schema {
    queryType {
      name
    }
    mutationType {
      name
    }
    subscriptionType {
      name
    }
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
  type {
    ...TypeRef
  }
  defaultValue
}

fragment TypeRef on __Type {
  kind
  name
  ofType {
    kind
    name
    ofType {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
              }
            }
          }
        }
      }
    }
  }
}
"""
"""The pre-October-2021 introspection query, for an older server."""

comptime GRAPH_INTROSPECT_LEGACY_QUERY_NAME = "GraphIntrospectLegacyQuery"
"""The operation name of `GRAPH_INTROSPECT_LEGACY_QUERY`."""
