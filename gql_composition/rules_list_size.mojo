# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The `@listSize` rule of a subgraph.

Port of Hive Federation Composition v0.27.0
`src/subgraph/validation/rules/elements/list-size.ts`.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_composition.context import SubgraphContext
from gql_composition.error_code import ErrorCode
from gql_composition.helpers import named_type_node
from gql_composition.rules_elements import parse_int
from gql_composition.state import ListSize


def _is_list_type(document: Document, node: Int) -> Bool:
    """Return True for a list type, also under a non-null type."""
    var current = node
    while document.kind(current) == Kind.NON_NULL_TYPE:
        current = document.first_child(current)
    return document.kind(current) == Kind.LIST_TYPE


def _is_int_type(document: Document, var node: Int) -> Bool:
    """Return True for `Int` or `Int!`."""
    var kind = document.kind(node)
    if kind == Kind.NON_NULL_TYPE:
        node = document.first_child(node)
        kind = document.kind(node)
    return kind == Kind.NAMED_TYPE and document.name(node) == "Int"


def _strings(document: Document, value: Int) -> Optional[List[String]]:
    """Return the strings of a list value, or nothing when the value is not
    a list of strings."""
    if document.kind(value) != Kind.LIST:
        return None
    var out = List[String]()
    var item = document.first_child(value)
    while item != NO_NODE:
        if document.kind(item) != Kind.STRING:
            return None
        out.append(document.string_value(item))
        item = document.next_sibling(item)
    return out^


struct _ListSizeArguments(Movable):
    """The arguments of a `@listSize`, as upstream reads them."""

    var assumed_size: Optional[Int]
    var slicing: Optional[List[String]]
    var sized: Optional[List[String]]
    var require_one: Bool

    def __init__(out self):
        self.assumed_size = None
        self.slicing = None
        self.sized = None
        self.require_one = True


def _read_arguments(
    mut context: SubgraphContext, node: Int, mut out: _ListSizeArguments
) -> Bool:
    """Read the arguments, or report the first invalid one and return
    False."""
    var assumed = NO_NODE
    var slicing = NO_NODE
    var sized = NO_NODE
    var require_one = NO_NODE
    var argument = context.document.first_child(node)
    while argument != NO_NODE:
        if context.document.role(argument) == Role.ARGUMENT:
            var name = context.document.name(argument)
            var value = context.document.child(argument, Role.VALUE)
            if name == "assumedSize":
                assumed = value
            elif name == "slicingArguments":
                slicing = value
            elif name == "sizedFields":
                sized = value
            else:
                # The definition of `@listSize` has no other argument.
                require_one = value
        argument = context.document.next_sibling(argument)
    if assumed != NO_NODE:
        if context.document.kind(assumed) != Kind.INT:
            context.report(
                "The value of @listSize(assumedSize:) must be an integer",
                ErrorCode.LIST_SIZE_INVALID_ASSUMED_SIZE,
            )
            return False
        out.assumed_size = parse_int(context.document.text(assumed))
    if slicing != NO_NODE:
        out.slicing = _strings(context.document, slicing)
        if not out.slicing:
            context.report(
                (
                    "The value of @listSize(slicingArguments:) must be a list"
                    " of strings"
                ),
                ErrorCode.LIST_SIZE_INVALID_SLICING_ARGUMENT,
            )
            return False
    if sized != NO_NODE:
        out.sized = _strings(context.document, sized)
        if not out.sized:
            context.report(
                (
                    "The value of @listSize(sizedFields:) must be a list of"
                    " strings"
                ),
                ErrorCode.LIST_SIZE_INVALID_SIZED_FIELD,
            )
            return False
    if require_one != NO_NODE:
        if context.document.kind(require_one) != Kind.BOOLEAN:
            context.report(
                (
                    "The value of @listSize(requireOneSlicingArgument:) must be"
                    " a boolean when defined"
                ),
                ErrorCode.LIST_SIZE_INVALID_REQUIRE_ONE_SLICING_ARGUMENT,
            )
            return False
        out.require_one = context.document.boolean_value(require_one)
    return True


def enter_list_size(
    mut context: SubgraphContext, node: Int, parent: Int
) raises:
    """Check and record a `@listSize`, as upstream `ListSizeRule`.

    Args:
        context: The context.
        node: The directive.
        parent: The annotated node.

    Raises:
        Error: When the state has a conflict of kinds.
    """
    var arguments = _ListSizeArguments()
    if not _read_arguments(context, node, arguments):
        return
    context.state.specs.cost = True
    context.state.specs.list_size_name = String(context.document.name(node))
    if context.document.kind(parent) != Kind.FIELD_DEFINITION:
        return
    var type_def = context.info.type_def
    var type_name = String(context.document.name(type_def))
    var field_name = String(context.document.name(parent))
    var coordinate = '"' + type_name + "." + field_name + '"'
    var type_node = context.document.child(parent, Role.TYPE)
    if arguments.assumed_size and arguments.assumed_size.value() < 0:
        context.report(
            coordinate + " has negative @listSize(assumedSize:) value",
            ErrorCode.LIST_SIZE_INVALID_ASSUMED_SIZE,
        )
        return
    var sized_count = 0
    if arguments.sized:
        sized_count = len(arguments.sized.value())
    if sized_count == 0 and not _is_list_type(context.document, type_node):
        context.report(
            coordinate
            + " is not a list. Try to add @listSize(sizedFields:) argument.",
            ErrorCode.LIST_SIZE_INVALID_SIZED_FIELD,
        )
        return
    if sized_count > 0 and not _check_sized_fields(
        context, coordinate, type_node, arguments.sized.value()
    ):
        return
    if arguments.slicing and len(arguments.slicing.value()) > 0:
        if not _check_slicing(
            context, coordinate, parent, arguments.slicing.value()
        ):
            return
    var kind = context.document.kind(type_def)
    var interface = (
        kind == Kind.INTERFACE_TYPE_DEFINITION
        or kind == Kind.INTERFACE_TYPE_EXTENSION
    )
    # A field definition is on an object type or on an interface type.
    var at = context.state.owner_field(type_name, field_name, interface)
    context.state.types[at.type].fields[at.field].list_size = ListSize(
        False,
        arguments.assumed_size,
        arguments.slicing.copy(),
        arguments.sized.copy(),
        arguments.require_one,
    )


def _check_sized_fields(
    mut context: SubgraphContext,
    coordinate: String,
    type_node: Int,
    sized: List[String],
) -> Bool:
    """Check that each sized field is a list field of the output type."""
    var output = context.merged_type(
        context.document.name(named_type_node(context.document, type_node))
    )
    if output == -1:
        context.report(
            coordinate
            + " has @listSize(sizedFields:) applied, but the output type is"
            " not a composite type",
            ErrorCode.LIST_SIZE_INVALID_SIZED_FIELD,
        )
        return False
    var not_lists = List[String]()
    var missing = List[String]()
    # The caller passes at least one name.
    var index = 0
    while index < len(sized):
        ref name = sized[index]
        index += 1
        var field = context.merged[output].find_field(context.document, name)
        if field == NO_NODE:
            missing.append(name)
        elif not _is_list_type(
            context.document, context.document.child(field, Role.TYPE)
        ):
            not_lists.append(name)
    for ref name in not_lists:
        context.report(
            coordinate
            + ' references "'
            + name
            + '" field in @listSize(sizedFields:) argument that is not a list.',
            ErrorCode.LIST_SIZE_APPLIED_TO_NON_LIST,
        )
    for ref name in missing:
        context.report(
            coordinate
            + ' references "'
            + name
            + '" field in @listSize(sizedFields:) argument that does not'
            " exist.",
            ErrorCode.LIST_SIZE_INVALID_SIZED_FIELD,
        )
    return len(not_lists) + len(missing) == 0


def _check_slicing(
    mut context: SubgraphContext,
    coordinate: String,
    field: Int,
    slicing: List[String],
) -> Bool:
    """Check that each slicing argument is an `Int` argument of the
    field."""
    var not_ints = List[String]()
    var missing = List[String]()
    # The caller passes at least one name.
    var index = 0
    while index < len(slicing):
        ref name = slicing[index]
        index += 1
        var found = NO_NODE
        var argument = context.document.first_child(field)
        while argument != NO_NODE and found == NO_NODE:
            if (
                context.document.role(argument) == Role.ARGUMENT
                and context.document.name(argument) == name
            ):
                found = argument
            argument = context.document.next_sibling(argument)
        if found == NO_NODE:
            missing.append(name)
        elif not _is_int_type(
            context.document, context.document.child(found, Role.TYPE)
        ):
            not_ints.append(name)
    for ref name in not_ints:
        context.report(
            coordinate
            + ' references "'
            + name
            + '" argument in @listSize(slicingArguments:) that is not an'
            " integer.",
            ErrorCode.LIST_SIZE_INVALID_SLICING_ARGUMENT,
        )
    for ref name in missing:
        context.report(
            coordinate
            + ' references "'
            + name
            + '" argument in @listSize(slicingArguments:) that does not exist.',
            ErrorCode.LIST_SIZE_INVALID_SLICING_ARGUMENT,
        )
    return len(not_ints) + len(missing) == 0
