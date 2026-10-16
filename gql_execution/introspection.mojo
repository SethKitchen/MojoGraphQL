# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The introspection query, and the introspection result of a schema.

Port of graphql-js 16.14.2 `utilities/getIntrospectionQuery.ts` and
`utilities/introspectionFromSchema.ts`. `get_introspection_query` gives
the same text as graphql-js for every option, and
`introspection_from_schema` gives the same data.

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
from gql_execution.execute import ExecutionArgs, execute


@fieldwise_init
struct IntrospectionOptions(Copyable, ImplicitlyCopyable, Movable):
    """The options of graphql-js `IntrospectionOptions`."""

    var descriptions: Bool
    """Ask for descriptions."""
    var specified_by_url: Bool
    """Ask for `specifiedByURL` on scalars."""
    var directive_is_repeatable: Bool
    """Ask for `isRepeatable` on directives."""
    var schema_description: Bool
    """Ask for the schema's description."""
    var input_value_deprecation: Bool
    """Ask for deprecated arguments and input fields."""
    var experimental_directive_deprecation: Bool
    """Ask for deprecated directives."""
    var one_of: Bool
    """Ask for `isOneOf` on input object types."""
    var type_depth: Int
    """How many `ofType` levels `TypeRef` asks for."""

    def __init__(out self):
        """Make the graphql-js defaults: descriptions, and a type depth of
        9."""
        self.descriptions = True
        self.specified_by_url = False
        self.directive_is_repeatable = False
        self.schema_description = False
        self.input_value_deprecation = False
        self.experimental_directive_deprecation = False
        self.one_of = False
        self.type_depth = 9

    @staticmethod
    def all() -> IntrospectionOptions:
        """Return the defaults of graphql-js `introspectionFromSchema`:
        every option on, and a type depth of 9.

        Returns:
            The options.
        """
        return IntrospectionOptions(True, True, True, True, True, True, True, 9)


def _of_type(level: Int, indent: String) raises -> String:
    """Return graphql-js `ofType(level, indent)`."""
    if level <= 0:
        return String("")
    if level > 100:
        raise Error(
            "Please set typeDepth to a reasonable value between 0 and 100;"
            " the default is 9."
        )
    return (
        "\n"
        + indent
        + "ofType {\n"
        + indent
        + "  name\n"
        + indent
        + "  kind"
        + _of_type_inner(level - 1, indent + "  ")
        + "\n"
        + indent
        + "}"
    )


def _of_type_inner(level: Int, indent: String) raises -> String:
    """Return the next `ofType` level; mutual recursion with `_of_type`."""
    return _of_type(level, indent)


def get_introspection_query(
    options: IntrospectionOptions = IntrospectionOptions(),
) raises -> String:
    """Return the introspection query, as graphql-js
    `getIntrospectionQuery`.

    Args:
        options: What to ask for.

    Returns:
        The query text, character for character as graphql-js writes it.

    Raises:
        Error: `Please set typeDepth to a reasonable value between 0 and
            100; the default is 9.` for a `type_depth` above 100.
    """
    var descriptions = "description" if options.descriptions else ""
    var specified_by_url = "specifiedByURL" if options.specified_by_url else ""
    var directive_is_repeatable = (
        "isRepeatable" if options.directive_is_repeatable else ""
    )
    var schema_description = descriptions if options.schema_description else ""
    var input = options.input_value_deprecation
    var directive = options.experimental_directive_deprecation
    var one_of = "isOneOf" if options.one_of else ""
    var include = "(includeDeprecated: true)"
    var out = String("\n    query IntrospectionQuery {\n      __schema {\n")
    out += "        " + schema_description + "\n"
    out += "        queryType { name kind }\n"
    out += "        mutationType { name kind }\n"
    out += "        subscriptionType { name kind }\n"
    out += "        types {\n          ...FullType\n        }\n"
    out += "        directives" + (include if directive else "") + " {\n"
    out += "          name\n"
    out += "          " + descriptions + "\n"
    out += "          " + directive_is_repeatable + "\n"
    out += "          " + ("isDeprecated" if directive else "") + "\n"
    out += "          " + ("deprecationReason" if directive else "") + "\n"
    out += "          locations\n"
    out += "          args" + (include if input else "") + " {\n"
    out += "            ...InputValue\n          }\n        }\n      }\n    }\n"
    out += "\n    fragment FullType on __Type {\n      kind\n      name\n"
    out += "      " + descriptions + "\n"
    out += "      " + specified_by_url + "\n"
    out += "      " + one_of + "\n"
    out += "      fields(includeDeprecated: true) {\n        name\n"
    out += "        " + descriptions + "\n"
    out += "        args" + (include if input else "") + " {\n"
    out += "          ...InputValue\n        }\n"
    out += "        type {\n          ...TypeRef\n        }\n"
    out += "        isDeprecated\n        deprecationReason\n      }\n"
    out += "      inputFields" + (include if input else "") + " {\n"
    out += "        ...InputValue\n      }\n"
    out += "      interfaces {\n        ...TypeRef\n      }\n"
    out += "      enumValues(includeDeprecated: true) {\n        name\n"
    out += "        " + descriptions + "\n"
    out += "        isDeprecated\n        deprecationReason\n      }\n"
    out += "      possibleTypes {\n        ...TypeRef\n      }\n    }\n"
    out += "\n    fragment InputValue on __InputValue {\n      name\n"
    out += "      " + descriptions + "\n"
    out += "      type { ...TypeRef }\n      defaultValue\n"
    out += "      " + ("isDeprecated" if input else "") + "\n"
    out += "      " + ("deprecationReason" if input else "") + "\n    }\n"
    out += "\n    fragment TypeRef on __Type {\n      kind\n      name"
    out += _of_type(options.type_depth, "      ")
    out += "\n    }\n  "
    return out^


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
