# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Test helpers for `gql_schema.validate`: graphql-js test `expectJSON`
for validation errors, schemas from several documents, and schemas
without AST nodes."""

from gql_language.ast import Document
from gql_language.error import GraphQLError, quote_json_string
from gql_language.parser import parse
from gql_schema.build import build_ast_schema
from gql_schema.definition import AstRef, Range, Schema
from gql_schema.validate import validate_schema
from std.testing import assert_equal


def error(message: String, locations: String = "") -> String:
    """Return an expected error as `GraphQLError.to_json` writes it.

    Args:
        message: The message.
        locations: The locations as `line:column`, separated by spaces;
            empty for none.

    Returns:
        The JSON object.
    """
    var out = String('{"message":') + quote_json_string(message)
    if locations != "":
        out += ',"locations":['
        var parts = locations.split(" ")
        for index in range(len(parts)):
            if index > 0:
                out += ","
            var pair = parts[index].split(":")
            out += '{"line":' + String(pair[0]) + ',"column":'
            out += String(pair[1]) + "}"
        out += "]"
    return out + "}"


def errors_json(errors: List[GraphQLError]) -> String:
    """Return errors as a JSON array.

    Args:
        errors: The errors.

    Returns:
        The array.
    """
    var out = String("[")
    for index in range(len(errors)):
        if index > 0:
            out += ","
        out += errors[index].to_json()
    return out + "]"


def expect_errors(schema: Schema, expected: List[String]) raises:
    """Assert the validation errors of a schema, as `expectJSON(
    validateSchema(schema)).toDeepEqual(expected)`.

    Args:
        schema: The schema.
        expected: The errors, each made with `error`.

    Raises:
        Error: When the errors differ.
    """
    var text = String("[")
    for index in range(len(expected)):
        if index > 0:
            text += ","
        text += expected[index]
    assert_equal(errors_json(validate_schema(schema)), text + "]")


def expect_valid(schema: Schema) raises:
    """Assert that a schema has no validation errors.

    Args:
        schema: The schema.

    Raises:
        Error: When it has one.
    """
    assert_equal(errors_json(validate_schema(schema)), "[]")


def build_documents(texts: List[String]) raises -> Schema:
    """Build a schema from several SDL documents, as `buildSchema` of the
    first and `extendSchema` with each of the others.

    Each document keeps its own source, so error locations are relative to
    the document, as in graphql-js.

    Args:
        texts: The SDL of each document.

    Returns:
        The schema.

    Raises:
        Error: A syntax error or a build error.
    """
    var documents = List[Document]()
    for ref text in texts:
        documents.append(parse(text))
    return build_ast_schema(documents^)


def strip_ast(mut schema: Schema):
    """Remove every AST node reference, as a schema made with the graphql-js
    constructors has no `astNode`.

    Default values stay: they are values, not locations.

    Args:
        schema: The schema to change.
    """
    for index in range(len(schema.types)):
        schema.types[index].definition = AstRef.NONE
        schema.types[index].extensions = Range.EMPTY
    for index in range(len(schema.fields)):
        schema.fields[index].definition = AstRef.NONE
    for index in range(len(schema.input_values)):
        schema.input_values[index].definition = AstRef.NONE
    for index in range(len(schema.enum_values)):
        schema.enum_values[index].definition = AstRef.NONE
    for index in range(len(schema.directives)):
        schema.directives[index].definition = AstRef.NONE
    schema.schema_definition = AstRef.NONE
    schema.schema_extensions = Range.EMPTY
