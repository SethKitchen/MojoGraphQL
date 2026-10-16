# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The federation rules of the authorization directives.

Port of `elements/authenticated.ts`, `elements/policy.ts` and
`elements/requires-scopes.ts` of Hive Federation Composition v0.27.0
`src/subgraph/validation/rules/`. The three rules are one function here,
with the directive as a parameter.
"""

from gql_language.ast import NO_NODE, Kind, Role
from gql_composition.context import SubgraphContext
from gql_composition.error_code import ErrorCode
from gql_composition.helpers import argument_value
from gql_composition.printer import print_node
from gql_composition.state import TypeKind, merge_scope_policies

comptime AUTHENTICATED = 0
"""`@authenticated`."""
comptime POLICY = 1
"""`@policy`."""
comptime REQUIRES_SCOPES = 2
"""`@requiresScopes`."""


def _read_groups(
    mut context: SubgraphContext, node: Int, which: Int
) raises -> List[List[String]]:
    """Read the `policies` or `scopes` argument, or raise the upstream
    error."""
    var argument: StaticString = "policies"
    var directive: StaticString = "@policy"
    var type_name: StaticString = "policy__Policy"
    if which == REQUIRES_SCOPES:
        argument = "scopes"
        directive = "@requiresScopes"
        type_name = "requiresScopes__Scope"
    ref document = context.document
    var value = argument_value(document, node, argument)
    if value == NO_NODE:
        raise Error(
            "Expected " + directive + ' to have a "' + argument + '" argument'
        )
    var at_text = '"' + directive + "(" + argument + ':)"'
    if document.kind(value) != Kind.LIST:
        raise Error("Expected " + at_text + " to be a list")
    var groups = List[List[String]]()
    var item = document.first_child(value)
    while item != NO_NODE:
        if document.kind(item) != Kind.LIST:
            raise Error(
                "Expected "
                + at_text
                + " to be in [["
                + type_name
                + "!]!]! format"
            )
        var group = List[String]()
        var entry = document.first_child(item)
        while entry != NO_NODE:
            if document.kind(entry) != Kind.STRING:
                raise Error(
                    "Expected "
                    + at_text
                    + " to be in [["
                    + type_name
                    + "!]!]! format, received [["
                    + print_node(document, value)
                    + "]!]!"
                )
            group.append(document.string_value(entry))
            entry = document.next_sibling(entry)
        groups.append(group^)
        item = document.next_sibling(item)
    return groups^


def _interface_error(mut context: SubgraphContext, which: Int, what: String):
    """Report an authorization directive on an interface."""
    var directive = String("@authenticated")
    if which == POLICY:
        directive = "@policy"
    elif which == REQUIRES_SCOPES:
        directive = "@requiresScopes"
    context.report(
        "Invalid use of "
        + directive
        + " on "
        + what
        + ": "
        + directive
        + " cannot be applied on interfaces, interface fields and interface"
        " objects",
        ErrorCode.AUTH_REQUIREMENTS_APPLIED_ON_INTERFACE,
    )


def _apply(
    mut target_authenticated: Bool,
    mut target_policies: List[List[String]],
    mut target_scopes: List[List[String]],
    which: Int,
    groups: List[List[String]],
):
    """Record an authorization directive on a type or field."""
    if which == AUTHENTICATED:
        target_authenticated = True
    elif which == POLICY:
        target_policies = merge_scope_policies(target_policies, groups)
    else:
        target_scopes = merge_scope_policies(target_scopes, groups)


def enter_auth(
    mut context: SubgraphContext, node: Int, parent: Int, which: Int
) raises:
    """Record `@authenticated`, `@policy` or `@requiresScopes`, as upstream
    `AuthenticatedRule`, `PolicyRule` and `RequiresScopesRule`.

    Args:
        context: The context.
        node: The directive.
        parent: The annotated node.
        which: `AUTHENTICATED`, `POLICY` or `REQUIRES_SCOPES`.

    Raises:
        Error: The upstream error for a `policies` or `scopes` argument
            that is missing or not in the `[[String!]!]!` form.
    """
    var groups = List[List[String]]()
    if which == AUTHENTICATED:
        context.state.specs.authenticated = True
    else:
        groups = _read_groups(context, node, which)
        if which == POLICY:
            context.state.specs.policy = True
        else:
            context.state.specs.requires_scopes = True
    var kind = context.document.kind(parent)
    var name = String(context.document.name(parent))
    if kind == Kind.FIELD_DEFINITION:
        var type_def = context.info.type_def
        var type_kind = context.document.kind(type_def)
        var type_name = String(context.document.name(type_def))
        if (
            type_kind == Kind.INTERFACE_TYPE_DEFINITION
            or type_kind == Kind.INTERFACE_TYPE_EXTENSION
        ):
            _interface_error(
                context, which, 'field "' + type_name + "." + name + '"'
            )
            return
        var at = context.state.entity_field(type_name, name)
        ref field = context.state.types[at.type].fields[at.field]
        _apply(field.authenticated, field.policies, field.scopes, which, groups)
        return
    var index = -1
    if (
        kind == Kind.OBJECT_TYPE_DEFINITION
        or kind == Kind.OBJECT_TYPE_EXTENSION
    ):
        if context.state.is_interface_object(name):
            _interface_error(context, which, 'interface object "' + name + '"')
            return
        index = context.state.object_type(name)
    elif kind == Kind.INTERFACE_TYPE_DEFINITION:
        _interface_error(context, which, 'interface "' + name + '"')
        return
    elif (
        kind == Kind.SCALAR_TYPE_DEFINITION
        or kind == Kind.SCALAR_TYPE_EXTENSION
    ):
        index = context.state.get_or_create(
            TypeKind.SCALAR, name, "a scalar type"
        )
    elif kind == Kind.ENUM_TYPE_DEFINITION or kind == Kind.ENUM_TYPE_EXTENSION:
        index = context.state.get_or_create(TypeKind.ENUM, name, "an enum type")
    if index == -1:
        return
    ref type = context.state.types[index]
    _apply(type.authenticated, type.policies, type.scopes, which, groups)
