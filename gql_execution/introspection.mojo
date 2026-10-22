# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The introspection query, and the introspection result of a schema.

Port of graphql-js 16.14.2 `utilities/getIntrospectionQuery.ts` and
`utilities/introspectionFromSchema.ts`. `get_introspection_query` is
re-exported from `gql_schema.introspection`, and
`introspection_from_schema` executes the query with `gql_execution.execute`.

The resolvers of the introspection types (`type/introspection.ts`) are in
`gql_execution.execute`, because execution calls them on its own handles
to the schema.

**Differences from upstream.**

- `introspection_from_schema` returns a `JsonDocument`, not a JavaScript
  object, and it raises an `Error` where graphql-js fails an invariant.
"""

from gql_json.value import JsonDocument
from gql_language.parser import parse
from gql_schema.definition import Schema
from gql_schema.introspection import (
    IntrospectionOptions,
    get_introspection_query,
)
from gql_execution.execute import ExecutionArgs, execute


def introspection_from_schema(
    schema: Schema,
    options: IntrospectionOptions = IntrospectionOptions.all(),
    assume_valid: Bool = False,
) raises -> JsonDocument:
    """Return the introspection result of a schema, as graphql-js
    `introspectionFromSchema`.

    Args:
        schema: The schema; it must be valid.
        options: What to ask for. The default has every option on, as the
            graphql-js defaults of this function are. Start from
            `IntrospectionOptions.all()` to turn one option off.
        assume_valid: Skip `assertValidSchema`, for a schema that is known
            to be valid, or that graphql-js built with `assumeValid`.

    Returns:
        The `data` of the introspection query: its root is the object
        with `__schema`.

    Raises:
        Error: The `assertValidSchema` error for an invalid schema, or
            `Unexpected error: the introspection query failed.` when the
            result has errors, as the graphql-js invariant fails.
    """
    var document = parse(get_introspection_query(options))
    var args = ExecutionArgs()
    args.assume_valid_schema = assume_valid
    var result = execute(schema, document, args)
    if len(result.errors) > 0:
        raise Error("Unexpected error: the introspection query failed.")
    return result^.take_data()
