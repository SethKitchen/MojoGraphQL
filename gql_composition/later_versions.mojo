# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Composition checks from federation `v2.14` and `v2.15`.

The public Apollo GraphOS page "Federation versions" states these rules.
Hive Federation Composition v0.27.0 does not implement them. The page names
`INTERFACE_OBJECT_USAGE_ERROR` for an interface that implements an
`@interfaceObject` type. It does not give the sentences. The sentences in
this module are from this port.

`v2.14` reports an error only when a Federation 1 subgraph puts `@key` on
an interface `T` and a Federation 2 subgraph puts `@interfaceObject` on
`T`. `v2.15` reports an error when an interface implements an
`@interfaceObject` type. The composition version is the highest version
of the subgraphs. The `v2.14` check runs only when that version is
`v2.14` or higher, and the `v2.15` check runs only when it is `v2.15` or higher.
At a lower version, the result is the result of Hive v0.27.0.

`check_version_2_14_and_2_15` also runs two Hive supergraph rules.
`TypesOfTheSameKindRule` (`types-of-the-same-kind-rule.ts`) reports
`TYPE_KIND_MISMATCH`. It skips a type when one subgraph marks it
`@interfaceObject`. `LinkImportNameMismatchRule`
(`link-import-name-mismatch-rule.ts`) requires `@cost` and `@listSize`
to use one local name in every subgraph that imports them. The message
matches Hive, including the space before each quoted name.
"""

from std.collections import Dict
from gql_language.ast import Document
from gql_composition.printer import print_node
from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.link import Link, LinkImport
from gql_composition.state import (
    Deprecated,
    Description,
    ExtensionType,
    FieldState,
    InputValueState,
    StringSet,
    SubgraphState,
    TypeKind,
    TypeState,
)


@fieldwise_init
struct ArgFact(Movable):
    """One argument of a field or a directive."""

    var name: String
    """The argument name."""
    var type_text: String
    """The printed type, such as `UserType!`."""
    var default_value: String
    """The printed default value, or empty when there is none."""
    var inaccessible: Bool
    """Whether the argument is `@inaccessible`."""
    var from_context: Bool
    """Whether the argument has `@fromContext`."""
    var context_name: String
    """The `@fromContext` context name, or empty."""
    var context_selection: String
    """The `@fromContext` selection, or empty."""
    var tags: List[String]
    """The `@tag` names, in source order."""
    var printed: String
    """The printed argument, without a leading comma."""
    var applied: String
    """The composed directives, each with a leading space."""


@fieldwise_init
struct DirectiveFact(Movable):
    """One directive definition in a subgraph."""

    var name: String
    """The directive name, without `@`."""
    var executable: Bool
    """Whether a location is an executable location."""
    var args: List[ArgFact]
    """The arguments, in source order."""
    var locations: List[String]
    """The directive locations, such as `FIELD_DEFINITION`."""
    var composed: Bool
    """Whether `@composeDirective` names this directive."""
    var repeatable: Bool
    """Whether the directive is repeatable."""


@fieldwise_init
struct FieldFact(Movable):
    """One field of an object type, for the supergraph printer."""

    var name: String
    """The field name."""
    var type_text: String
    """The printed type, such as `ID!` or `[String]`."""
    var arguments: String
    """The printed arguments, such as `by: ById`, or empty."""
    var external: Bool
    """Whether the subgraph marks the field `@external`."""
    var requires: String
    """The `@requires` field set, or empty."""
    var provides: String
    """The `@provides` field set, or empty."""
    var override_from: String
    """The `@override(from:)` subgraph, or empty."""
    var override_label: String
    """The `@override(label:)` value, or empty."""
    var used_as_key: Bool
    """Whether a `@key` selects this field."""
    var shareable: Bool
    """Whether the field is `@shareable`."""
    var in_extension: Bool
    """Whether the field is declared in a type extension."""
    var arg_facts: List[ArgFact]
    """The field arguments, in source order."""
    var used: Bool
    """Whether a federation directive selects this field."""
    var required: Bool
    """Whether `@requires` or `@provides` selects this field directly."""
    var default_value: String
    """The printed default value, or empty when there is none."""
    var inaccessible: Bool
    """Whether the field is `@inaccessible`."""
    var slicing_arguments: List[String]
    """The `@listSize(slicingArguments:)` names, or empty."""
    var authenticated: Bool
    """Whether the field is `@authenticated`."""
    var scopes: List[List[String]]
    """The `@requiresScopes` groups. Each group must all hold."""
    var policies: List[List[String]]
    """The `@policy` groups. Each group must all hold."""
    var tags: List[String]
    """The `@tag` names, in source order."""
    var description: String
    """The description text, or empty."""
    var deprecation: String
    """The printed `@deprecated`, or empty."""
    var has_cost: Bool
    """Whether the field has `@cost`."""
    var cost: Int
    """The `@cost` weight, or zero when `has_cost` is false."""
    var list_size: String
    """The printed `@listSize`, or empty."""
    var has_list_size: Bool
    """Whether the field has `@listSize`."""
    var list_assumed: Int
    """The `assumedSize`, or -1 when it is absent."""
    var list_require: Bool
    """The `requireOneSlicingArgument` value."""
    var list_print_require: Bool
    """Whether the supergraph must print `requireOneSlicingArgument`."""
    var list_sized: List[String]
    """The `sizedFields` names, or empty."""
    var list_directive: String
    """The local `@listSize` name, or empty."""
    var applied: String
    """The composed directives on the field, each with a leading space."""
    var has_slicing_arguments: Bool
    """Whether `@listSize` sets `slicingArguments`, even when that list is empty."""
    var has_sized_fields: Bool
    """Whether `@listSize` sets `sizedFields`, even when that list is empty."""


@fieldwise_init
struct TypeFacts(Movable):
    """The fields of one type that the `v2.14` and `v2.15` checks read."""

    var kind: TypeKind
    """The kind of the type."""
    var name: String
    """The name of the type."""
    var is_interface_object: Bool
    """Whether the type comes from `@interfaceObject`."""
    var key_count: Int
    """How many `@key` directives the type has."""
    var interfaces: List[String]
    """The interfaces the type implements, in source order."""
    var extension: Bool
    """Whether the object type is an extension in this subgraph."""
    var is_definition: Bool
    """Whether the subgraph has a type definition for this name."""
    var extension_type: ExtensionType
    """How the object is an extension: none, `@extends`, or `extend`."""
    var keys: List[String]
    """The `@key` field sets, in order."""
    var key_resolvable: List[Bool]
    """Whether each `@key` is resolvable. Parallel to `keys`."""
    var fields: List[FieldFact]
    """The object fields, in order."""
    var values: List[String]
    """The enum values, or the union members, in order."""
    var value_hidden: List[Bool]
    """Whether each enum value is `@inaccessible`. Parallel to `values`."""
    var input_refs: List[String]
    """The schema coordinates that use an enum as an input type."""
    var output_refs: List[String]
    """The schema coordinates that use an enum as an output type."""
    var type_external: Bool
    """Whether the object type is marked `@external`."""
    var inaccessible: Bool
    """Whether the type is `@inaccessible`."""
    var implemented_by: List[String]
    """The object types that implement this interface, in source order."""
    var authenticated: Bool
    """Whether the type is `@authenticated`."""
    var scopes: List[List[String]]
    """The `@requiresScopes` groups on the type."""
    var policies: List[List[String]]
    """The `@policy` groups on the type."""
    var contexts: List[String]
    """The `@context` names on the type."""
    var tags: List[String]
    """The `@tag` names on the type, in source order."""
    var value_tags: List[List[String]]
    """The `@tag` names of each enum value. Parallel to `values`."""
    var description: String
    """The description text, or empty."""
    var value_descriptions: List[String]
    """The description of each enum value. Parallel to `values`."""
    var value_deprecations: List[String]
    """The printed `@deprecated` of each enum value. Parallel to `values`."""
    var value_applied: List[String]
    """The composed directives of each enum value. Parallel to `values`."""
    var has_cost: Bool
    """Whether the type has `@cost`."""
    var cost: Int
    """The `@cost` weight, or zero when `has_cost` is false."""
    var applied: String
    """The composed directives on the type, each with a leading space."""
    var specified_by: String
    """The `@specifiedBy` URL, or empty."""
    var is_one_of: Bool
    """Whether an input object type has `@oneOf`."""
    var field_at: Dict[String, Int]
    """The index in `fields` of each field name."""

    def find_field(self, name: String) -> Int:
        """Return the index of a field, or -1.

        Args:
            name: The field name.

        Returns:
            The index in `fields`, or -1 when the type has no such field.
        """
        return self.field_at.get(name, -1)


@fieldwise_init
struct GraphFacts(Movable):
    """The fields of one subgraph that the `v2.14` and `v2.15` checks
    read."""

    var graph_name: String
    """The name of the subgraph."""
    var version_number: Int
    """The federation version as `major * 100 + minor`."""
    var types: List[TypeFacts]
    """The types, in the order the state created them."""
    var imports: List[LinkImport]
    """The federation `@link` imports, in source order."""
    var has_query: Bool
    """Whether the subgraph defines a query root type."""
    var graph_id: String
    """The subgraph id, such as `USERS`."""
    var query_name: String
    """The query root name, or empty when there is none."""
    var mutation_name: String
    """The mutation root name, or empty when there is none."""
    var subscription_name: String
    """The subscription root name, or empty when there is none."""
    var directives: List[DirectiveFact]
    """The directive definitions, in source order."""
    var links: List[Link]
    """The `@link` directives, federation first, then the others."""
    var cost_used: Bool
    """Whether `@cost` or `@listSize` is used."""
    var list_size_used: Bool
    """Whether `@listSize` is used."""
    var cost_name: String
    """The local name of `@cost`, or empty when it is not used."""
    var list_size_name: String
    """The local name of `@listSize`, or empty when it is not used."""
    var type_at: Dict[String, Int]
    """The index in `types` of each type and directive name."""

    def find(self, name: String) -> Int:
        """Return the index of a type or a directive, or -1.

        A subgraph state has one entry for each name, of any kind.

        Args:
            name: The type or directive name.

        Returns:
            The index in `types`, or -1 when the subgraph has no such name.
        """
        return self.type_at.get(name, -1)

    def find_kind(self, name: String, kind: TypeKind) -> Int:
        """Return the index of a type of one kind, or -1.

        Args:
            name: The type name.
            kind: The kind the type must have.

        Returns:
            The index in `types`, or -1 when the subgraph has no such type
            of that kind.
        """
        var at = self.find(name)
        if at != -1 and self.types[at].kind != kind:
            return -1
        return at


def graph_facts(state: SubgraphState, document: Document) -> GraphFacts:
    """Copy the fields the later checks read from a subgraph state.

    Args:
        state: The state after the subgraph walk.
        document: The subgraph document. Composed directives are printed
            from it.

    Returns:
        A copy of the name, the version and the type facts.
    """
    var types = List[TypeFacts]()
    var type_at = Dict[String, Int]()
    var directives = List[DirectiveFact]()
    var index = -1
    while index + 1 < len(state.types):
        index += 1
        ref type = state.types[index]
        var interfaces = List[String]()
        for ref name in type.interfaces.items:
            interfaces.append(String(name))
        var keys = List[String]()
        var key_resolvable = List[Bool]()
        var fields = List[FieldFact]()
        var values = List[String]()
        var value_hidden = List[Bool]()
        var input_refs = List[String]()
        var output_refs = List[String]()
        var value_tags = List[List[String]]()
        var value_descriptions = List[String]()
        var value_deprecations = List[String]()
        var value_applied = List[String]()
        if type.kind == TypeKind.OBJECT or type.kind == TypeKind.INTERFACE:
            for key_index in range(len(type.keys)):
                keys.append(String(type.keys[key_index].fields))
                key_resolvable.append(type.keys[key_index].resolvable)
            var field_index = -1
            while field_index + 1 < len(type.fields):
                field_index += 1
                ref field = type.fields[field_index]
                fields.append(
                    _field_fact(
                        field,
                        type.fields_used_as_keys.contains(field.name),
                        document,
                        _plain_name(state.specs.cost_name),
                        _plain_name(state.specs.list_size_name),
                    )
                )
        elif type.kind == TypeKind.INPUT_OBJECT:
            var field_index = -1
            while field_index + 1 < len(type.input_fields):
                field_index += 1
                ref field = type.input_fields[field_index]
                fields.append(
                    FieldFact(
                        String(field.name),
                        String(field.type),
                        String(""),
                        False,
                        String(""),
                        String(""),
                        String(""),
                        String(""),
                        False,
                        False,
                        False,
                        List[ArgFact](),
                        False,
                        False,
                        _text(field.default_value),
                        field.inaccessible,
                        List[String](),
                        False,
                        List[List[String]](),
                        List[List[String]](),
                        _copy_names(field.tags),
                        _description(field.description),
                        deprecation_suffix(field.deprecated),
                        _has_cost(field.cost),
                        _cost_value(field.cost),
                        String(""),
                        False,
                        -1,
                        True,
                        False,
                        List[String](),
                        String(""),
                        _applied_text(document, field.directives),
                        False,
                        False,
                    )
                )
        elif type.kind == TypeKind.ENUM:
            var value_index = -1
            while value_index + 1 < len(type.values):
                value_index += 1
                values.append(String(type.values[value_index].name))
                value_hidden.append(type.values[value_index].inaccessible)
                value_tags.append(_copy_names(type.values[value_index].tags))
                value_descriptions.append(
                    _description(type.values[value_index].description)
                )
                value_deprecations.append(
                    deprecation_suffix(type.values[value_index].deprecated)
                )
                value_applied.append(
                    _applied_text(document, type.values[value_index].directives)
                )
        elif type.kind == TypeKind.UNION:
            var member_index = -1
            while member_index + 1 < len(type.members.items):
                member_index += 1
                values.append(String(type.members.items[member_index]))
                value_tags.append(List[String]())
                value_descriptions.append(String(""))
                value_deprecations.append(String(""))
                value_applied.append(String(""))
        for ref item in type.input_type_references.items:
            input_refs.append(String(item))
        for ref item in type.output_type_references.items:
            output_refs.append(String(item))
        var implemented_by = List[String]()
        for ref item in type.implemented_by.items:
            implemented_by.append(String(item))
        var field_at = Dict[String, Int]()
        for field_index in range(len(fields)):
            field_at[fields[field_index].name] = field_index
        type_at[type.name] = len(types)
        types.append(
            TypeFacts(
                type.kind,
                String(type.name),
                type.is_interface_object,
                len(type.keys),
                interfaces^,
                type.extension,
                type.is_definition,
                type.extension_type,
                keys^,
                key_resolvable^,
                fields^,
                values^,
                value_hidden^,
                input_refs^,
                output_refs^,
                type.external,
                type.inaccessible,
                implemented_by^,
                type.authenticated,
                _copy_groups(type.scopes),
                _copy_groups(type.policies),
                _copy_names(type.contexts),
                _copy_names(type.tags),
                value_tags^,
                _description(type.description),
                value_descriptions^,
                value_deprecations^,
                value_applied^,
                _has_cost(type.cost),
                _cost_value(type.cost),
                _applied_text(document, type.directives),
                _specified_by(type.specified_by),
                type.is_one_of,
                field_at^,
            )
        )
        if type.kind == TypeKind.DIRECTIVE:
            directives.append(
                _directive_fact(
                    type, document, _plain_name(state.specs.cost_name)
                )
            )
    var imports = List[LinkImport]()
    for index in range(len(state.federation_imports)):
        ref item = state.federation_imports[index]
        var alias: Optional[String] = None
        if item.alias:
            alias = String(item.alias.value())
        imports.append(LinkImport(item.kind, String(item.name), alias^))
    var links = _links(state)
    return GraphFacts(
        String(state.graph_name),
        state.version.number(),
        types^,
        imports^,
        state.root_names[0].byte_length() > 0,
        String(state.graph_id),
        String(state.root_names[0]),
        String(state.root_names[1]),
        String(state.root_names[2]),
        directives^,
        links^,
        state.specs.cost,
        _has_text(state.specs.list_size_name),
        _plain_name(state.specs.cost_name),
        _plain_name(state.specs.list_size_name),
        type_at^,
    )


def _links(state: SubgraphState) -> List[Link]:
    """Copy the `@link` directives, with federation first.

    Args:
        state: The subgraph state.

    Returns:
        The federation link when it imported elements, then the other
        links that import directives.
    """
    var links = List[Link]()
    for index in range(len(state.core_links)):
        links.append(state.core_links[index].copy())
    return links^


def _copy_groups(groups: List[List[String]]) -> List[List[String]]:
    """Copy scope or policy groups.

    Args:
        groups: The groups to copy.

    Returns:
        A new list of groups.
    """
    var copied = List[List[String]]()
    for index in range(len(groups)):
        var group = List[String]()
        ref source = groups[index]
        for item in range(len(source)):
            group.append(String(source[item]))
        copied.append(group^)
    return copied^


def _field_fact(
    field: FieldState,
    used_as_key: Bool,
    document: Document,
    cost_name: String,
    list_size_name: String,
) -> FieldFact:
    """Copy one object or interface field.

    Args:
        field: The field.
        used_as_key: Whether a `@key` selects the field. The printer omits
            `@external` on a key field.
        document: The subgraph document.
        cost_name: The local name of `@cost`, or empty.
        list_size_name: The local name of `@listSize`, or empty.

    Returns:
        The fact the supergraph printer reads.
    """
    return FieldFact(
        String(field.name),
        String(field.type),
        _arguments(field, document, cost_name),
        field.external,
        _text(field.requires),
        _text(field.provides),
        _text(field.override),
        _text(field.override_label),
        used_as_key,
        field.shareable,
        field.extension,
        _arg_facts(field, document, cost_name),
        field.used,
        field.required or field.provided,
        String(""),
        field.inaccessible,
        _slicing_names(field),
        field.authenticated,
        _copy_groups(field.scopes),
        _copy_groups(field.policies),
        _copy_names(field.tags),
        _description(field.description),
        deprecation_suffix(field.deprecated),
        _has_cost(field.cost),
        _cost_value(field.cost),
        _list_size_suffix(field, list_size_name),
        _has_list_size(field),
        _list_assumed(field),
        _list_require(field),
        _list_print_require(field),
        _list_sized(field),
        _list_directive(list_size_name, field),
        _applied_text(document, field.directives),
        _has_list_argument(field, False),
        _has_list_argument(field, True),
    )


def _has_list_argument(field: FieldState, sized: Bool) -> Bool:
    """Return True when a `@listSize` list argument is present.

    Args:
        field: The field.
        sized: Whether to read `sizedFields` instead of `slicingArguments`.

    Returns:
        Whether the argument is set, including an empty list.
    """
    if not field.list_size:
        return False
    ref size = field.list_size.value()
    if sized:
        if size.sized_fields:
            return True
        return False
    if size.slicing_arguments:
        return True
    return False


def _slicing_names(field: FieldState) -> List[String]:
    """Copy `@listSize(slicingArguments:)` names.

    Args:
        field: The field.

    Returns:
        The argument names, or an empty list when there is no `@listSize`.
    """
    var names = List[String]()
    if not field.list_size:
        return names^
    ref size = field.list_size.value()
    if not size.slicing_arguments:
        return names^
    ref args = size.slicing_arguments.value()
    for index in range(len(args)):
        names.append(String(args[index]))
    return names^


def _text(value: Optional[String]) -> String:
    """Return an optional string, or empty."""
    if value:
        return String(value.value())
    return String("")


def _context_name(argument: InputValueState) -> String:
    """Return the `@fromContext` context name, or empty.

    Args:
        argument: One argument.

    Returns:
        The context name.
    """
    if argument.from_context:
        return String(argument.from_context.value().context)
    return String("")


def _context_selection(argument: InputValueState) -> String:
    """Return the `@fromContext` selection, or empty.

    Args:
        argument: One argument.

    Returns:
        The selection text.
    """
    if argument.from_context:
        return String(argument.from_context.value().selection)
    return String("")


def _copy_names(names: StringSet) -> List[String]:
    """Copy the items of a string set.

    Args:
        names: The set.

    Returns:
        The names, in insertion order.
    """
    var copied = List[String]()
    for ref item in names.items:
        copied.append(String(item))
    return copied^


def _has_from_context(argument: InputValueState) -> Bool:
    """Return True when an argument has `@fromContext`.

    Args:
        argument: One argument.

    Returns:
        Whether `from_context` is set.
    """
    if argument.from_context:
        return True
    return False


def _argument_text(
    argument: InputValueState, document: Document, cost_name: String
) -> String:
    """Return one printed argument.

    Args:
        argument: The argument.
        document: The subgraph document. Composed directives are printed
            from it.
        cost_name: The local name of `@cost`, or empty.

    Returns:
        Text such as `id: ID = "1"`.
    """
    var out = String("")
    if argument.description:
        # Hive prints an empty description as a block with an empty line.
        var text = argument.description.value().value
        out += '"""\n' + text.replace('"""', '\\"""') + '\n"""\n'
    out += argument.name + ": " + argument.type
    var printed = _text(argument.default_value)
    if printed.byte_length() > 0:
        out += " = " + printed
    out += _applied_text(document, argument.directives)
    for tag_index in range(len(argument.tags.items)):
        out += (
            " @tag(name: "
            + _graphql_string(argument.tags.items[tag_index])
            + ")"
        )
    if argument.inaccessible:
        out += " @inaccessible"
    out += _cost_print(argument.cost, cost_name)
    out += deprecation_suffix(argument.deprecated)
    return out


def _arg_facts(
    field: FieldState, document: Document, cost_name: String
) -> List[ArgFact]:
    """Copy the arguments of a field.

    Args:
        field: The field.
        document: The subgraph document.
        cost_name: The local name of the `@cost` directive.

    Returns:
        The arguments, in source order.
    """
    var args = List[ArgFact]()
    for index in range(len(field.args)):
        ref argument = field.args[index]
        args.append(
            ArgFact(
                String(argument.name),
                String(argument.type),
                _text(argument.default_value),
                argument.inaccessible,
                _has_from_context(argument),
                _context_name(argument),
                _context_selection(argument),
                _copy_names(argument.tags),
                _argument_text(argument, document, cost_name),
                _applied_text(document, argument.directives),
            )
        )
    return args^


def _directive_fact(
    type: TypeState, document: Document, cost_name: String
) -> DirectiveFact:
    """Copy one directive definition.

    Args:
        type: The directive in the subgraph state.
        document: The subgraph document.
        cost_name: The local name of `@cost`, or empty.

    Returns:
        The name, whether it can apply to an executable location, and
        its arguments.
    """
    var args = List[ArgFact]()
    for index in range(len(type.input_fields)):
        ref argument = type.input_fields[index]
        args.append(
            ArgFact(
                String(argument.name),
                String(argument.type),
                _text(argument.default_value),
                argument.inaccessible,
                _has_from_context(argument),
                _context_name(argument),
                _context_selection(argument),
                _copy_names(argument.tags),
                _argument_text(argument, document, cost_name),
                _applied_text(document, argument.directives),
            )
        )
    var locations = type.locations.items.copy()
    return DirectiveFact(
        String(type.name),
        _executable(type.locations),
        args^,
        locations^,
        type.composed,
        type.repeatable,
    )


def _executable(locations: StringSet) -> Bool:
    """Return True when a directive location is executable.

    Args:
        locations: The directive locations.

    Returns:
        Whether Hive's `isExecutable` is true.
    """
    comptime executable = (
        " FIELD FRAGMENT_DEFINITION INLINE_FRAGMENT FRAGMENT_SPREAD"
        " VARIABLE_DEFINITION QUERY MUTATION SUBSCRIPTION "
    )
    var index = 0
    while index < len(locations.items):
        if " " + locations.items[index] + " " in executable:
            return True
        index += 1
    return False


def description_block(text: String) -> String:
    """Return a GraphQL block string for a description.

    Hive prints every description as a block string.

    Args:
        text: The description text.

    Returns:
        The block string, or empty when `text` is empty.
    """
    if text.byte_length() == 0:
        return String("")
    var escaped = text.replace('"""', '\\"""')
    return '"""\n' + escaped + '\n"""'


def _description(text: Optional[Description]) -> String:
    """Return the description text, or empty.

    Args:
        text: The description, if any.

    Returns:
        The decoded text.
    """
    if text:
        return String(text.value().value)
    return String("")


def tag_suffix(tags: List[String]) -> String:
    """Return the printed `@tag` directives for a list of names.

    Args:
        tags: The tag names, in source order.

    Returns:
        ` @tag(name: "...")` for each name, or an empty string.
    """
    var out = String("")
    for index in range(len(tags)):
        out += " @tag(name: " + _graphql_string(tags[index]) + ")"
    return out


def deprecation_suffix(item: Optional[Deprecated]) -> String:
    """Return the printed `@deprecated` directive.

    Args:
        item: The deprecation, if any.

    Returns:
        ` @deprecated` or ` @deprecated(reason: "...")`, or empty.
    """
    if not item:
        return String("")
    var found = item.value().copy()
    if not found.reason:
        return String(" @deprecated")
    return " @deprecated(reason: " + _graphql_string(found.reason.value()) + ")"


def graphql_escape(text: String) -> String:
    """Escape a value the way Hive's JSON string printer does.

    Args:
        text: The raw text.

    Returns:
        The text for the inside of a GraphQL string. Backspace, form feed,
        and other control characters are escaped.
    """
    var out = String("")
    var bytes = text.as_bytes()
    for index in range(len(bytes)):
        var byte = Int(bytes[index])
        if byte == 34 or byte == 92:
            out += "\\"
            out += String(text[byte = index : index + 1])
        elif byte == 8:
            out += "\\b"
        elif byte == 9:
            out += "\\t"
        elif byte == 10:
            out += "\\n"
        elif byte == 12:
            out += "\\f"
        elif byte == 13:
            out += "\\r"
        elif byte < 32:
            out += "\\u00" + _hex_pair(byte)
        else:
            out += String(text[byte = index : index + 1])
    return out


def _hex_pair(byte: Int) -> String:
    """Return two lowercase hex digits.

    Args:
        byte: A value from 0 to 255.

    Returns:
        The digits, such as `0b`.
    """
    comptime digits = "0123456789abcdef"
    var hi = byte // 16
    var lo = byte - hi * 16
    return String(digits[byte = hi : hi + 1]) + String(
        digits[byte = lo : lo + 1]
    )


def _graphql_string(text: String) -> String:
    """Return a GraphQL string literal.

    Args:
        text: The string value.

    Returns:
        The value inside double quotes.
    """
    return '"' + graphql_escape(text) + '"'


def _specified_by(url: Optional[String]) -> String:
    """Return a `@specifiedBy` URL, or empty.

    Args:
        url: The URL, if any.

    Returns:
        The URL text.
    """
    if url:
        return String(url.value())
    return String("")


def _applied_text(document: Document, nodes: List[Int]) -> String:
    """Print composed directive applications.

    Args:
        document: The subgraph document.
        nodes: The directive nodes.

    Returns:
        Each directive with a leading space, or empty.
    """
    var out = String("")
    for index in range(len(nodes)):
        out += " " + print_node(document, nodes[index])
    return out


def _has_cost(cost: Optional[Int]) -> Bool:
    """Return True when a `@cost` weight is set.

    Args:
        cost: The weight, if any.

    Returns:
        Whether `cost` holds a value.
    """
    if cost:
        return True
    return False


def _cost_value(cost: Optional[Int]) -> Int:
    """Return a `@cost` weight, or zero.

    Args:
        cost: The weight, if any.

    Returns:
        The weight, or zero when it is absent.
    """
    if cost:
        return cost.value()
    return 0


def _has_text(text: Optional[String]) -> Bool:
    """Return True when an optional string is set.

    Args:
        text: The string, if any.

    Returns:
        Whether `text` holds a value.
    """
    if text:
        return True
    return False


def _plain_name(text: Optional[String]) -> String:
    """Return an optional directive name, or empty.

    Args:
        text: The local name, if any.

    Returns:
        The name, without `@`.
    """
    if text:
        return String(text.value())
    return String("")


def _cost_print(cost: Optional[Int], name: String) -> String:
    """Return the printed cost directive.

    Args:
        cost: The weight, if any.
        name: The local directive name.

    Returns:
        ` @cost(weight: N)`, or empty.
    """
    if not cost:
        return String("")
    # An argument with `@cost` always has the local name.
    return " @" + name + "(weight: " + String(cost.value()) + ")"


def _list_size_suffix(field: FieldState, name: String) -> String:
    """Return the printed list-size directive.

    Args:
        field: The field.
        name: The local directive name.

    Returns:
        ` @listSize(...)`, or empty when the field has no `@listSize`.
    """
    if not field.list_size:
        return String("")
    # A field with `@listSize` always has the local name. The state never
    # sets `print_require_one_slicing_argument`, so only `false` prints.
    var directive = name
    var size = field.list_size.value().copy()
    var args = String("")
    if not size.require_one_slicing_argument:
        args = "requireOneSlicingArgument: false"
    if size.assumed_size:
        if args.byte_length() > 0:
            args += ", "
        args += "assumedSize: " + String(size.assumed_size.value())
    if size.slicing_arguments:
        if args.byte_length() > 0:
            args += ", "
        args += "slicingArguments: " + _string_list(
            size.slicing_arguments.value()
        )
    if size.sized_fields:
        if args.byte_length() > 0:
            args += ", "
        args += "sizedFields: " + _string_list(size.sized_fields.value())
    if args.byte_length() == 0:
        return " @" + directive
    return " @" + directive + "(" + args + ")"


def _has_list_size(field: FieldState) -> Bool:
    """Return True when a field has `@listSize`.

    Args:
        field: The field.

    Returns:
        Whether `list_size` is set.
    """
    if field.list_size:
        return True
    return False


def _list_assumed(field: FieldState) -> Int:
    """Return `assumedSize`, or -1.

    Args:
        field: The field.

    Returns:
        The size, or -1 when it is absent.
    """
    if not field.list_size:
        return -1
    var size = field.list_size.value().copy()
    if size.assumed_size:
        return size.assumed_size.value()
    return -1


def _list_require(field: FieldState) -> Bool:
    """Return `requireOneSlicingArgument`.

    Args:
        field: The field.

    Returns:
        The flag, or true when the field has no `@listSize`.
    """
    if not field.list_size:
        return True
    var size = field.list_size.value().copy()
    return size.require_one_slicing_argument


def _list_print_require(field: FieldState) -> Bool:
    """Return whether `requireOneSlicingArgument` must be printed.

    Args:
        field: The field.

    Returns:
        The print flag, or false when the field has no `@listSize`.
    """
    if not field.list_size:
        return False
    var size = field.list_size.value().copy()
    return size.print_require_one_slicing_argument


def _list_sized(field: FieldState) -> List[String]:
    """Copy `@listSize(sizedFields:)` names.

    Args:
        field: The field.

    Returns:
        The names, or an empty list.
    """
    var names = List[String]()
    if not field.list_size:
        return names^
    var size = field.list_size.value().copy()
    if not size.sized_fields:
        return names^
    ref items = size.sized_fields.value()
    for index in range(len(items)):
        names.append(String(items[index]))
    return names^


def _list_directive(name: String, field: FieldState) -> String:
    """Return the local `@listSize` name.

    Args:
        name: The imported name, or empty.
        field: The field.

    Returns:
        The name, or empty when the field has no `@listSize`. A field with
        `@listSize` always has the name.
    """
    if not field.list_size:
        return String("")
    return name


def _string_list(names: List[String]) -> String:
    """Return a printed list of strings.

    Args:
        names: The strings.

    Returns:
        Text such as `["first"]`.
    """
    var out = String("[")
    for index in range(len(names)):
        if index > 0:
            out += ", "
        out += _graphql_string(names[index])
    out += "]"
    return out


def _arguments(
    field: FieldState, document: Document, cost_name: String
) -> String:
    """Return the printed arguments of a field, or empty.

    Args:
        field: The field.
        document: The subgraph document.
        cost_name: The local name of `@cost`, or empty.

    Returns:
        The arguments, such as `by: ById`, or empty.
    """
    var out = String("")
    for index in range(len(field.args)):
        ref argument = field.args[index]
        if argument.from_context:
            continue
        if out.byte_length() > 0:
            out += ", "
        out += _argument_text(argument, document, cost_name)
    return out


def check_version_2_14_and_2_15(
    facts: List[GraphFacts],
) -> List[CompositionError]:
    """Check the `v2.14` and `v2.15` rules across subgraphs.

    Args:
        facts: The subgraph facts, in id order, after a clean subgraph
            phase.

    Returns:
        The errors. A missing query root comes first, then type-kind
        mismatches, then import-name mismatches. Federation 1 `@key`
        conflicts come before interface implementation conflicts.
    """
    var errors = List[CompositionError]()
    _check_required_query(errors, facts)
    _check_type_kinds(errors, facts)
    _check_import_names(errors, facts)
    var highest = 0
    for index in range(len(facts)):
        highest = max(highest, facts[index].version_number)
    if highest < 214:
        return errors^
    var owners = Dict[String, String]()
    var index = 0
    while index < len(facts):
        _record_interface_objects(owners, facts[index])
        index += 1
    index = 0
    while index < len(facts):
        _check_federation_1_key(errors, owners, facts[index])
        index += 1
    if highest < 215:
        return errors^
    index = 0
    while index < len(facts):
        _check_interface_implements(errors, owners, facts[index])
        index += 1
    return errors^


def _record_interface_objects(
    mut owners: Dict[String, String], graph: GraphFacts
):
    """Record the first Federation 2 subgraph that puts
    `@interfaceObject` on each type.

    Args:
        owners: Type name to the subgraph that first defined it.
        graph: One subgraph.
    """
    if graph.version_number < 200:
        return
    var index = 0
    while index < len(graph.types):
        ref type = graph.types[index]
        index += 1
        if type.kind != TypeKind.INTERFACE:
            continue
        if not type.is_interface_object:
            continue
        if owners.get(type.name):
            continue
        owners[type.name] = String(graph.graph_name)


def _check_federation_1_key(
    mut errors: List[CompositionError],
    owners: Dict[String, String],
    graph: GraphFacts,
):
    """Report a Federation 1 `@key` on an `@interfaceObject` type name.

    Args:
        errors: The errors to append.
        owners: Type name to the subgraph that defines `@interfaceObject`.
        graph: One subgraph.
    """
    if graph.version_number != 100:
        return
    var index = 0
    while index < len(graph.types):
        ref type = graph.types[index]
        index += 1
        if type.kind != TypeKind.INTERFACE:
            continue
        if type.key_count == 0:
            continue
        var found = owners.get(type.name)
        if not found:
            continue
        errors.append(
            CompositionError(
                "["
                + graph.graph_name
                + '] Federation 1 subgraph "'
                + graph.graph_name
                + '" defines @key on interface "'
                + type.name
                + '", and subgraph "'
                + found.value()
                + '" defines @interfaceObject on "'
                + type.name
                + '".',
                ErrorCode.INTERFACE_OBJECT_USAGE_ERROR,
                graph.graph_name,
            )
        )


def _check_interface_implements(
    mut errors: List[CompositionError],
    owners: Dict[String, String],
    graph: GraphFacts,
):
    """Report an interface that implements an `@interfaceObject` type.

    Args:
        errors: The errors to append.
        owners: Type name to the subgraph that defines `@interfaceObject`.
        graph: One subgraph.
    """
    var index = 0
    while index < len(graph.types):
        ref type = graph.types[index]
        index += 1
        if type.kind != TypeKind.INTERFACE:
            continue
        if type.is_interface_object:
            continue
        for ref parent in type.interfaces:
            var found = owners.get(parent)
            if not found:
                continue
            errors.append(
                CompositionError(
                    "["
                    + graph.graph_name
                    + '] Interface "'
                    + type.name
                    + '" cannot implement @interfaceObject type "'
                    + parent
                    + '" from subgraph "'
                    + found.value()
                    + '".',
                    ErrorCode.INTERFACE_OBJECT_USAGE_ERROR,
                    graph.graph_name,
                )
            )


@fieldwise_init
struct _AliasUse(Movable):
    """One local name of `@cost` or `@listSize`, and the subgraphs that
    use it."""

    var alias: String
    """The local name, such as `@price`."""
    var names: List[String]
    """The subgraph names, in id order."""


@fieldwise_init
struct _ImportNames(Movable):
    """The local names of one federation import."""

    var original: String
    """The specification name, `@cost` or `@listSize`."""
    var aliases: List[_AliasUse]
    """The local names, in the order they are first seen."""


def _check_required_query(
    mut errors: List[CompositionError], facts: List[GraphFacts]
):
    """Report a missing query root, as upstream `RequiredQueryRule`.

    Args:
        errors: The errors to append.
        facts: The subgraphs, in id order.
    """
    # Hive reports `NO_QUERIES` for an empty list of subgraphs too.
    var index = 0
    while index < len(facts):
        if facts[index].has_query:
            return
        index += 1
    errors.append(
        CompositionError(
            (
                "No queries found in any subgraph: a supergraph must have a"
                " query root type."
            ),
            ErrorCode.NO_QUERIES,
            None,
        )
    )


@fieldwise_init
struct _KindSites(Movable):
    """The subgraphs that define one type as one kind."""

    var kind: TypeKind
    """The kind."""
    var names: List[String]
    """The subgraph names, in id order."""
    var interface_object: Bool
    """Whether any of those subgraphs uses `@interfaceObject`."""


@fieldwise_init
struct _NamedKinds(Movable):
    """The kinds of one type name across subgraphs."""

    var name: String
    """The type name."""
    var kinds: List[_KindSites]
    """The kinds, in first-seen order."""
    var conflict: Bool
    """Whether the type has more than one kind."""


def _kind_label(kind: TypeKind) -> StaticString:
    """Return Hive's printed kind, such as `InputObject`.

    Args:
        kind: The type kind.

    Returns:
        The label Hive uses in `TYPE_KIND_MISMATCH`.
    """
    comptime labels: Array[StaticString, 7] = [
        "Object",
        "Interface",
        "Enum",
        "Union",
        "Scalar",
        "InputObject",
        "Directive",
    ]
    return materialize[labels]()[Int(kind.value)]


def _note_kind(
    mut named: _NamedKinds,
    kind: TypeKind,
    graph_name: String,
    interface_object: Bool,
):
    """Record one subgraph's kind for a type that already has a row.

    Args:
        named: The type's kinds so far.
        kind: The kind in this subgraph.
        graph_name: The subgraph name.
        interface_object: Whether this subgraph uses `@interfaceObject`.
    """
    # A subgraph defines each type name once, so `graph_name` is new.
    var index = 0
    while index < len(named.kinds):
        if named.kinds[index].kind == kind:
            ref site = named.kinds[index]
            site.names.append(String(graph_name))
            if interface_object:
                site.interface_object = True
            return
        index += 1
    var names = List[String]()
    names.append(String(graph_name))
    named.kinds.append(_KindSites(kind, names^, interface_object))
    # The row already had a kind, so the type now has two kinds.
    named.conflict = True


def _note_type(
    mut types: List[_NamedKinds],
    name: String,
    kind: TypeKind,
    interface_object: Bool,
    graph_name: String,
):
    """Record one type from one subgraph.

    Args:
        types: The types seen so far.
        name: The type name.
        kind: The kind in this subgraph.
        interface_object: Whether this subgraph uses `@interfaceObject`.
        graph_name: The subgraph name.
    """
    var marked = kind == TypeKind.INTERFACE and interface_object
    for index in range(len(types)):
        if types[index].name != name:
            continue
        _note_kind(types[index], kind, String(graph_name), marked)
        return
    var names = List[String]()
    names.append(String(graph_name))
    var kinds = List[_KindSites]()
    kinds.append(_KindSites(kind, names^, marked))
    types.append(_NamedKinds(String(name), kinds^, False))


def _kind_group(site: _KindSites) -> String:
    """Return one kind group, as Hive prints it.

    Args:
        site: The subgraphs that use this kind.

    Returns:
        Such as `Object Type in subgraphs "a", "b"`.
    """
    var out = String(_kind_label(site.kind)) + " Type in subgraph"
    if len(site.names) > 1:
        out += "s"
    out += ' "' + site.names[0]
    var index = 1
    while index < len(site.names):
        out += '", "' + site.names[index]
        index += 1
    out += '"'
    return out


def _check_type_kinds(
    mut errors: List[CompositionError], facts: List[GraphFacts]
):
    """Report a type whose kind differs across subgraphs.

    Args:
        errors: The errors to append.
        facts: The subgraphs, in id order.
    """
    var types = List[_NamedKinds]()
    for graph_index in range(len(facts)):
        ref graph = facts[graph_index]
        var type_index = -1
        while type_index + 1 < len(graph.types):
            type_index += 1
            ref type = graph.types[type_index]
            _note_type(
                types,
                String(type.name),
                type.kind,
                type.is_interface_object,
                String(graph.graph_name),
            )
    for index in range(len(types)):
        ref named = types[index]
        if not named.conflict:
            continue
        var skip = False
        var kind_index = 0
        while kind_index < len(named.kinds):
            ref site = named.kinds[kind_index]
            if site.kind == TypeKind.INTERFACE and site.interface_object:
                skip = True
            kind_index += 1
        if skip:
            continue
        var message = (
            'Type "'
            + named.name
            + '" has mismatched kind: it is defined as '
            + _kind_group(named.kinds[0])
            + " but "
            + _kind_group(named.kinds[1])
        )
        var rest = 2
        while rest < len(named.kinds):
            message += " and " + _kind_group(named.kinds[rest])
            rest += 1
        errors.append(
            CompositionError(message^, ErrorCode.TYPE_KIND_MISMATCH, None)
        )


def _check_import_names(
    mut errors: List[CompositionError], facts: List[GraphFacts]
):
    """Report `@cost` and `@listSize` imports that use different local
    names, as upstream `LinkImportNameMismatchRule`.

    Args:
        errors: The errors to append.
        facts: The subgraphs, in id order.
    """
    var groups = List[_ImportNames]()
    for index in range(len(facts)):
        _record_import_names(groups, facts[index])
    for index in range(len(groups)):
        ref group = groups[index]
        if len(group.aliases) <= 1:
            continue
        var parts = List[String]()
        var alias_index = 0
        while alias_index < len(group.aliases):
            ref alias = group.aliases[alias_index]
            var word = String("subgraph")
            if len(alias.names) > 1:
                word = String("subgraphs")
            parts.append(
                ' "'
                + alias.alias
                + '" in '
                + word
                + " "
                + _and_list(alias.names, False, '"')
            )
            alias_index += 1
        errors.append(
            CompositionError(
                'The import name "'
                + group.original
                + '" is imported with mismatched name between subgraphs: it'
                " is imported as "
                + _and_list(parts, True, ""),
                ErrorCode.LINK_IMPORT_NAME_MISMATCH,
                None,
            )
        )


def _record_import_names(mut groups: List[_ImportNames], graph: GraphFacts):
    """Record the `@cost` and `@listSize` imports of one subgraph.

    Args:
        groups: The imports seen so far.
        graph: One subgraph.
    """
    for index in range(len(graph.imports)):
        ref item = graph.imports[index]
        if item.name != "@cost" and item.name != "@listSize":
            continue
        var local = String(item.name)
        if item.alias:
            local = String(item.alias.value())
        _add_import_name(groups, String(item.name), local, graph.graph_name)


def _add_import_name(
    mut groups: List[_ImportNames],
    original: String,
    alias: String,
    graph_name: String,
):
    """Add one local name of an import.

    Args:
        groups: The imports seen so far.
        original: `@cost` or `@listSize`.
        alias: The local name.
        graph_name: The subgraph that imports it.
    """
    var at = _index_of_original(groups, original)
    if at == -1:
        var names = List[String]()
        names.append(graph_name)
        var aliases = List[_AliasUse]()
        aliases.append(_AliasUse(alias, names^))
        groups.append(_ImportNames(original, aliases^))
        return
    ref group = groups[at]
    var alias_at = _index_of_alias(group.aliases, alias)
    if alias_at == -1:
        var names = List[String]()
        names.append(graph_name)
        group.aliases.append(_AliasUse(alias, names^))
        return
    group.aliases[alias_at].names.append(graph_name)


def _index_of_original(groups: List[_ImportNames], original: String) -> Int:
    """Return the index of an import name, or -1.

    Args:
        groups: The imports seen so far.
        original: `@cost` or `@listSize`.

    Returns:
        The index, or -1.
    """
    for index in range(len(groups)):
        if groups[index].original == original:
            return index
    return -1


def _index_of_alias(aliases: List[_AliasUse], alias: String) -> Int:
    """Return the index of a local name, or -1.

    Args:
        aliases: The local names of one import.
        alias: The local name.

    Returns:
        The index, or -1.
    """
    var index = 0
    while index < len(aliases):
        if aliases[index].alias == alias:
            return index
        index += 1
    return -1


def _and_list(items: List[String], comma: Bool, wrapper: String) -> String:
    """Join names as upstream `andList`.

    Args:
        items: The names. The list has at least one name.
        comma: Whether a comma precedes `and` when there are three or more
            names.
        wrapper: A character placed around each name, or empty.

    Returns:
        The joined names.
    """
    var first = _wrap(items[0], wrapper)
    if len(items) == 1:
        return first^
    var second = _wrap(items[1], wrapper)
    if len(items) == 2:
        return first + " and " + second
    var out = first
    var index = 1
    while index < len(items) - 1:
        out += ", " + _wrap(items[index], wrapper)
        index += 1
    var tail = String(" and ")
    if comma:
        tail = String(", and ")
    return out + tail + _wrap(items[len(items) - 1], wrapper)


def _wrap(text: String, wrapper: String) -> String:
    """Put a wrapper around a name when the wrapper is not empty.

    Args:
        text: The name.
        wrapper: The wrapper, or empty.

    Returns:
        The wrapped name.
    """
    if wrapper.byte_length() == 0:
        return text
    return wrapper + text + wrapper
