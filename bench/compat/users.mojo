# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `users` subgraph of the Apollo Federation subgraph compatibility
suite (f9520a4, MIT), served over HTTP: the Mojo counterpart of
`packages/subgraphs/users/index.js`, with the SDL of `users.graphql`.

The port is 4002, or the value of `USERS_PORT`. Run it from the
repository root:

    .venv/bin/mojo run -I . bench/compat/users.mojo
"""

from _serve import serve_subgraph
from gql_execution.execute import ResolveInfo
from gql_execution.value import ValueKind, Values
from gql_language.parser import parse
from gql_subgraph.build_subgraph_schema import (
    SchemaModule,
    SubgraphResolvers,
    SubgraphSchema,
    build_subgraph_schema,
)

comptime USERS_SDL = """extend schema
  @link(
    url: "https://specs.apollo.dev/federation/v2.3"
    import: ["@key", "@shareable"]
  )

type User @key(fields: "email") {
  email: ID!
  name: String
  totalProductsCreated: Int @shareable
  yearsOfEmployment: Int!
}
"""
"""The SDL of `users.graphql`."""

comptime EMAIL = "support@apollographql.com"
"""The email of the one user."""


def _user_reference(
    mut values: Values, reference: Int, context: Int, info: ResolveInfo
) raises -> Int:
    """`User.__resolveReference`: the user whose email is the email of the
    representation, as `users.find`."""
    var email = values.get(reference, "email")
    if values.kind(email) != ValueKind.STRING or values.string(
        email
    ) != StringSlice(EMAIL):
        return values.add_null()
    var user = values.add_object()
    values.add_member(user, "email", values.add_string(EMAIL))
    values.add_member(user, "name", values.add_string("Apollo Studio Support"))
    values.add_member(user, "totalProductsCreated", values.add_number(10))
    values.add_member(user, "yearsOfEmployment", values.add_number(10))
    return user


def build_users() raises -> SubgraphSchema:
    """Build the `users` subgraph, as `buildSubgraphSchema` in index.js.

    Returns:
        The subgraph schema.

    Raises:
        Error: As `build_subgraph_schema` raises.
    """
    var resolvers = SubgraphResolvers()
    resolvers.resolve_reference("User", _user_reference)
    var modules = List[SchemaModule]()
    modules.append(SchemaModule(parse(USERS_SDL), resolvers^))
    return build_subgraph_schema(modules^)


def main() raises:
    """Serve the `users` subgraph until the process is stopped."""
    serve_subgraph(build_users(), "Users", "USERS_PORT", 4002)
