# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The helpers of the definition normalization tests: `run` and
`runManyOnDefinition` of graphql-go-tools v2
`astnormalization/astnormalization_test.go`, for the SDL passes.

Upstream walks the SDL as the operation, and ignores the definition. These
helpers do the same, so they take no definition.
"""

from gql_language.ast import Document, NO_NODE, Role
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_normalization.definition import (
    extend_enum_type_definition,
    extend_input_object_type_definition,
    extend_interface_type_definition,
    extend_object_type_definition,
    extend_scalar_type_definition,
    extend_union_type_definition,
    extends_directive,
    implicit_extend_root_operation,
    implicit_schema_definition,
    remove_merged_type_extensions,
)
from gql_normalization.edit import remove_child
from std.testing import assert_equal

comptime DefPass = def(mut document: Document) thin -> None
"""One upstream SDL visitor, registered on its own walker."""


def object_pass(mut document: Document):
    """Upstream `extendObjectTypeDefinition`.

    Args:
        document: The SDL document.
    """
    extend_object_type_definition(document)


def input_object_pass(mut document: Document):
    """Upstream `extendInputObjectTypeDefinition`.

    Args:
        document: The SDL document.
    """
    extend_input_object_type_definition(document)


def enum_pass(mut document: Document):
    """Upstream `extendEnumTypeDefinition`.

    Args:
        document: The SDL document.
    """
    extend_enum_type_definition(document)


def interface_pass(mut document: Document):
    """Upstream `extendInterfaceTypeDefinition`.

    Args:
        document: The SDL document.
    """
    extend_interface_type_definition(document)


def scalar_pass(mut document: Document):
    """Upstream `extendScalarTypeDefinition`.

    Args:
        document: The SDL document.
    """
    extend_scalar_type_definition(document)


def union_pass(mut document: Document):
    """Upstream `extendUnionTypeDefinition`.

    Args:
        document: The SDL document.
    """
    extend_union_type_definition(document)


def remove_merged_pass(mut document: Document):
    """Upstream `removeMergedTypeExtensions`.

    Args:
        document: The SDL document.
    """
    remove_merged_type_extensions(document)


def implicit_schema_pass(mut document: Document):
    """Upstream `implicitSchemaDefinition`.

    Args:
        document: The SDL document.
    """
    implicit_schema_definition(document)


def implicit_extend_pass(mut document: Document):
    """Upstream `implicitExtendRootOperation`.

    Args:
        document: The SDL document.
    """
    implicit_extend_root_operation(document)


def extends_pass(mut document: Document):
    """Upstream `extendsDirective`.

    Args:
        document: The SDL document.
    """
    extends_directive(document)


def parse_sdl(text: StringSlice) raises -> Document:
    """Parse SDL, and remove each `@__bare` directive of a definition.

    graphql-js, and so `gql_language`, refuses an extension without
    members, such as `extend scalar Mood`. The parser of upstream accepts
    it. A test writes it as `extend scalar Mood @__bare`.

    Args:
        text: The SDL.

    Returns:
        The document.

    Raises:
        Error: If the text does not parse.
    """
    var document = parse(text)
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        var directive = document.child(definition, Role.DIRECTIVE)
        while directive != NO_NODE:
            var after = document.next_with_role(directive)
            if document.name(directive) == "__bare":
                remove_child(document, definition, directive)
            directive = after
        definition = document.next_sibling(definition)
    return document^


def run_def(normalize: DefPass, sdl: StringSlice, expected: StringSlice) raises:
    """Run one SDL pass and compare the printed result: upstream `run`.

    Args:
        normalize: The pass.
        sdl: The SDL document.
        expected: The expected SDL.

    Raises:
        Error: If the outputs differ.
    """
    var document = parse_sdl(sdl)
    normalize(document)
    assert_equal(print_ast(document), print_ast(parse_sdl(expected)))


def run_many_def(
    passes: List[DefPass], sdl: StringSlice, expected: StringSlice
) raises:
    """Run SDL passes in order and compare the printed result: upstream
    `runManyOnDefinition`, which registers them on one walker.

    Args:
        passes: The passes.
        sdl: The SDL document.
        expected: The expected SDL.

    Raises:
        Error: If the outputs differ.
    """
    var document = parse_sdl(sdl)
    var index = 0
    while index < len(passes):
        var normalize = passes[index]
        normalize(document)
        index += 1
    assert_equal(print_ast(document), print_ast(parse_sdl(expected)))
