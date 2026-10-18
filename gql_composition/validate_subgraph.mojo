# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The validation of one subgraph.

Port of `validateSubgraph` of Hive Federation Composition v0.27.0
`src/subgraph/validation/validate-subgraph.ts`.

The subgraph is walked twice. The first walk builds the state and runs the
federation rules, in the upstream order of `federationRules`. The second
walk runs the GraphQL rules over the federation definitions, the link
definitions and the subgraph.
"""

from gql_language.ast import NO_NODE, Document, Kind, OperationType, Role
from gql_composition.context import SubgraphContext
from gql_composition.helpers import validate_directive_against_original
from gql_composition.rules_auth import (
    AUTHENTICATED,
    POLICY,
    REQUIRES_SCOPES,
    enter_auth,
)
from std.collections import Dict
from gql_composition.rules_basic import BasicRules
from gql_composition.rules_from_context import (
    enter_from_context,
    index_context_owners,
)
from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts, graph_facts
from gql_composition.federation_spec import (
    FederationSpec,
    SpecCache,
    SpecSchema,
    copy_spec_definition,
    create_spec_schema,
    link_spec_schema,
    strip_at,
)
from gql_composition.link import LinkImport
from gql_composition.rules_graphql import GraphQLRules
from gql_composition.state import SubgraphState
from gql_composition.validate_state import validate_subgraph_state
from gql_composition.rules_elements import (
    enter_compose_directive,
    enter_context,
    enter_cost,
    enter_extends,
    enter_external,
    enter_interface_object,
    enter_override,
    enter_shareable,
)
from gql_composition.rules_field_sets import (
    enter_key,
    enter_provides,
    enter_requires,
)
from gql_composition.rules_list_size import enter_list_size
from gql_composition.rules_marks import enter_inaccessible, enter_tag
from gql_composition.state_visitor import (
    enter_description,
    enter_directive,
    enter_directive_definition,
    enter_enum_value_definition,
    enter_field_definition,
    enter_input_value_definition,
    enter_type_definition,
)
from gql_composition.walk import Walker


def _enter_federation_directive(
    mut context: SubgraphContext,
    rules: BasicRules,
    owners: Dict[String, List[String]],
    node: Int,
    parent: Int,
) raises:
    """Run the federation rules on a directive, in upstream order."""
    enter_directive(context, node)
    rules.enter_directive(context, node)
    var mask = context.directive_mask(context.document.name(node))
    if mask == 0:
        return
    if mask & 1 != 0:
        enter_inaccessible(context, parent)
    if mask & 2 != 0:
        enter_interface_object(context)
    if mask & 4 != 0:
        enter_auth(context, node, parent, AUTHENTICATED)
    if mask & 8 != 0:
        enter_auth(context, node, parent, POLICY)
    if mask & 16 != 0:
        enter_auth(context, node, parent, REQUIRES_SCOPES)
    if mask & 32 != 0:
        enter_cost(context, node, parent)
    if mask & 64 != 0:
        enter_list_size(context, node, parent)
    if mask & 128 != 0:
        enter_override(context, node)
    if mask & 256 != 0:
        enter_context(context, node)
    if mask & 512 != 0:
        enter_from_context(context, node, owners)
    if mask & 1024 != 0:
        enter_extends(context)
    if mask & 2048 != 0:
        enter_shareable(context, node)
    if mask & 4096 != 0:
        enter_key(context, node)
    if mask & 8192 != 0:
        enter_provides(context, node)
    if mask & 16384 != 0:
        enter_requires(context, node)
    if mask & 32768 != 0:
        enter_external(context)
    if mask & 65536 != 0:
        enter_tag(context, node, parent)
    if mask & 131072 != 0:
        enter_compose_directive(context, node)


comptime _DEFINITION_RULES: Array[StaticString, 18] = [
    "inaccessible",
    "interfaceObject",
    "authenticated",
    "policy",
    "requiresScopes",
    "cost",
    "listSize",
    "override",
    "context",
    "fromContext",
    "extends",
    "shareable",
    "key",
    "provides",
    "requires",
    "external",
    "tag",
    "composeDirective",
]


def _enter_node(
    mut context: SubgraphContext,
    mut rules: BasicRules,
    owners: Dict[String, List[String]],
    node: Int,
    parent: Int,
    path: List[Int],
) raises:
    """Run the state visitor and the federation rules on entry to a
    node."""
    var kind = context.document.kind(node)
    if kind == Kind.DIRECTIVE:
        _enter_federation_directive(context, rules, owners, node, parent)
    elif kind == Kind.FIELD_DEFINITION:
        enter_field_definition(context, node)
    elif kind == Kind.INPUT_VALUE_DEFINITION:
        enter_input_value_definition(context, node)
    elif kind == Kind.NAMED_TYPE:
        rules.enter_named_type(context, node, path[0])
    elif kind == Kind.STRING:
        if context.document.role(node) == Role.DESCRIPTION:
            enter_description(context, node, parent)
    elif kind == Kind.ENUM_VALUE_DEFINITION:
        enter_enum_value_definition(context, node)
    elif kind == Kind.DIRECTIVE_DEFINITION:
        enter_directive_definition(context, node)
        var mask = context.directive_mask(context.document.name(node))
        var names = materialize[_DEFINITION_RULES]()
        var index = 0
        while mask != 0:
            if mask & 1 != 0:
                validate_directive_against_original(
                    context, node, String(names[index])
                )
            mask >>= 1
            index += 1
    elif kind == Kind.SCHEMA_DEFINITION or kind == Kind.SCHEMA_EXTENSION:
        rules.enter_schema(context, node)
    elif kind.is_type_definition():
        enter_type_definition(context, node)
        rules.enter_type(context, node)
    elif kind.is_type_extension():
        enter_type_definition(context, node)


def _unlink(mut document: Document, parent: Int, child: Int):
    """Remove a child from the children of its parent. The child is a
    field, so it is never the first child: the name comes before it."""
    var previous = NO_NODE
    var current = document.first_child(parent)
    while current != child:
        previous = current
        current = document.next_sibling(current)
    document.nodes[previous].next = document.nodes[child].next
    if document.nodes[parent].last == Int32(child):
        document.nodes[parent].last = Int32(previous)


def _query_type_name(document: Document, definitions: List[Int]) -> String:
    """Return the query root type name of the first schema definition or
    extension that sets one, or `Query`."""
    var index = 0
    while index < len(definitions):
        var definition = definitions[index]
        index += 1
        var kind = document.kind(definition)
        if kind != Kind.SCHEMA_DEFINITION and kind != Kind.SCHEMA_EXTENSION:
            continue
        var child = document.first_child(definition)
        while child != NO_NODE:
            if (
                document.role(child) == Role.OPERATION_TYPE
                and document.operation(child) == OperationType.QUERY
            ):
                return String(document.name(document.child(child, Role.TYPE)))
            child = document.next_sibling(child)
    return String("Query")


def clean_subgraph_spec(
    mut document: Document, definitions: List[Int]
) -> List[Int]:
    """Drop the definitions of the subgraph specification, as upstream
    `cleanSubgraphTypeDefsFromSubgraphSpec`: `_Any`, `_Entity`, `_Service`,
    and the `_service` and `_entities` fields of the query type.

    Args:
        document: The subgraph's document; the fields are unlinked.
        definitions: The definitions, in order.

    Returns:
        The definitions that remain, in order.
    """
    var query = _query_type_name(document, definitions)
    var kept = List[Int]()
    var index = 0
    while index < len(definitions):
        var definition = definitions[index]
        index += 1
        var kind = document.kind(definition)
        var name = document.name(definition)
        if (
            kind == Kind.SCALAR_TYPE_DEFINITION
            or kind == Kind.INPUT_OBJECT_TYPE_DEFINITION
        ) and name == "_Any":
            continue
        if kind == Kind.UNION_TYPE_DEFINITION and name == "_Entity":
            continue
        if kind == Kind.OBJECT_TYPE_DEFINITION and name == "_Service":
            continue
        kept.append(definition)
        if (
            kind == Kind.OBJECT_TYPE_DEFINITION
            or kind == Kind.OBJECT_TYPE_EXTENSION
        ) and name == query:
            var field = document.first_child(definition)
            while field != NO_NODE:
                var next = document.next_sibling(field)
                if document.role(field) == Role.FIELD and (
                    document.name(field) == "_service"
                    or document.name(field) == "_entities"
                ):
                    _unlink(document, definition, field)
                field = next
    return kept^


def _alias_of(imports: List[LinkImport], name: String) -> String:
    """Return the alias that the imports give a definition, or its name."""
    for ref item in imports:
        if strip_at(item.name) == name and item.alias:
            return strip_at(item.alias.value())
    return name


def _copy_available(
    mut context: SubgraphContext, mut full: List[Int], directives: Bool
):
    """Copy the available federation directives or types that the
    subgraph does not replace."""
    var count = len(context.available.directives) if directives else len(
        context.available.types
    )
    var index = 0
    while index < count:
        var definition = (
            context.available.directives[index]
            .copy() if directives else context.available.types[index]
            .copy()
        )
        index += 1
        var name = _alias_of(context.imports, definition.name)
        if context.replacements.contains(name):
            continue
        full.append(
            copy_spec_definition(
                context.document, context.available, definition, name
            )
        )


def _full_definitions(
    mut context: SubgraphContext, link_spec: SpecSchema
) -> List[Int]:
    """Copy the available federation definitions and the link definitions
    into the subgraph's document, and return them before the subgraph's
    definitions, as upstream `fullTypeDefs`."""
    var full = List[Int]()
    _copy_available(context, full, True)
    _copy_available(context, full, False)
    if context.version.above(100) and not context.state.specs.link:
        var position = 0
        while position < len(link_spec.types):
            ref definition = link_spec.types[position]
            position += 1
            if context.state.find_type(definition.name) == -1:
                full.append(
                    copy_spec_definition(
                        context.document, link_spec, definition, definition.name
                    )
                )
    full.extend(Span(context.definitions))
    return full^


def _walk_federation(mut context: SubgraphContext) raises:
    """Walk the subgraph with the state visitor and the federation
    rules."""
    var rules = BasicRules(context)
    var owners = index_context_owners(context)
    var walker = Walker(context.definitions.copy())
    while walker.next(context.document):
        var node = walker.node
        if walker.entering:
            context.info.enter(context.document, node)
            _enter_node(
                context, rules, owners, node, walker.parent(), walker.path
            )
        else:
            context.info.leave(context.document, node)


def _walk_graphql(
    document: Document, definitions: List[Int]
) -> List[CompositionError]:
    """Walk the full document with the GraphQL rules."""
    var rules = GraphQLRules(document, definitions)
    var walker = Walker(definitions.copy())
    while walker.next(document):
        if walker.entering:
            rules.enter(document, walker.node, walker.path)
        else:
            rules.leave(document, walker.node, walker.path)
    return rules.errors.copy()


def _mark_shareable(mut context: SubgraphContext) raises:
    """Mark the key fields of object types as shareable, as upstream does
    after the walks."""
    for ref coordinate in context.fields_to_mark_as_shareable():
        var dot = coordinate.find(".")
        var type_name = String(coordinate[byte=:dot])
        if context.state.is_interface_object(type_name):
            continue
        var at = context.state.object_field(
            type_name, String(coordinate[byte = dot + 1 :])
        )
        context.state.types[at.type].fields[at.field].shareable = True


def validate_subgraph(
    mut cache: SpecCache,
    var document: Document,
    definitions: List[Int],
    name: String,
    id: String,
    federation: FederationSpec,
    var state: SubgraphState,
    mut facts: List[GraphFacts],
) raises -> List[CompositionError]:
    """Validate one subgraph, as upstream `validateSubgraph`.

    Args:
        cache: The parsed SDL of each federation version.
        document: The subgraph's document.
        definitions: Its definitions, schema and directive definitions
            first.
        name: The name of the subgraph.
        id: The id of the subgraph.
        federation: The federation version and imports.
        state: The state that `create_state` started.
        facts: Receives the facts the `v2.14` and `v2.15` checks read.

    Returns:
        The errors, each with the `[<name>] ` prefix and the subgraph
        name.

    Raises:
        Error: Only if the SDL of the federation specification does not
            parse.
    """
    var kept = clean_subgraph_spec(document, definitions)
    var available = create_spec_schema(
        cache, federation.version, federation.imports, True
    )
    var known = create_spec_schema(
        cache, federation.version, List[LinkImport](), False
    )
    var context = SubgraphContext(
        document^,
        kept^,
        name,
        id,
        federation.version,
        federation.imports.copy(),
        available^,
        known^,
        state^,
    )
    _walk_federation(context)
    var full = _full_definitions(context, link_spec_schema())
    var state_errors = validate_subgraph_state(context.state)
    var graphql_errors = _walk_graphql(context.document, full)
    _mark_shareable(context)
    var errors = context.errors.copy()
    for ref coordinate in context.collect_unused_external():
        errors.append(
            CompositionError(
                'Field "'
                + coordinate
                + '" is marked @external but is not used in any federation'
                " directive (@key, @provides, @requires) or to satisfy an"
                " interface; the field declaration has no use and should be"
                " removed (or the field should not be @external).",
                ErrorCode.EXTERNAL_UNUSED,
                None,
            )
        )
    errors.extend(graphql_errors^)
    errors.extend(state_errors^)
    for ref error in errors:
        if not error.subgraph_name:
            error.message = "[" + name + "] " + error.message
            error.subgraph_name = name
    facts.append(graph_facts(context.state, context.document))
    return errors^
