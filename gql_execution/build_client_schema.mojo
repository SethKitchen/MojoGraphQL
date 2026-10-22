# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Build a client schema from the result of an introspection query.

Re-export of `gql_schema.build_client_schema.build_client_schema`.
"""

from gql_json.value import JsonDocument
from gql_schema.build_client_schema import (
    build_client_schema as _build_client_schema,
)
from gql_schema.definition import Schema


def build_client_schema(
    document: JsonDocument, introspection: Int, assume_valid: Bool = False
) raises -> Schema:
    """Build a schema from the result of an introspection query, as
    graphql-js `buildClientSchema`.

    Args:
        document: The JSON document of the result.
        introspection: The `data` value: an object with `__schema`.
        assume_valid: The graphql-js `assumeValid` option; it is kept as
            the `assume_valid` option of the build.

    Returns:
        The schema.

    Raises:
        Error: As `gql_schema.build_client_schema.build_client_schema`
            raises.
    """
    return _build_client_schema(document, introspection, assume_valid)
