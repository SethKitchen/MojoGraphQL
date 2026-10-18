# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Compose subgraphs into a supergraph.

Port of `composeServices` of Hive Federation Composition v0.27.0
`src/compose.ts` for object, interface, enum, union, and input types.

A field gets `@join__field` when it is missing from at least one subgraph
that defines its type. An `@inaccessible` field keeps that directive.
An `@tag` keeps its name, in source order. `@interfaceObject`
prints `isInterfaceObject: true` on that graph's `@join__type`, and each
implementation gains the interface-object fields it does not define, with
a bare `@join__field`. An implementor that already defines the field keeps `@authenticated`, `@policy`, and `@requiresScopes` from that interface object. An interface field argument does not print `@inaccessible`, and a field copied from that interface omits it too. An interface keeps those directives from each object that implements it, including on a field. `@fromContext` is omitted from the field arguments
and printed as `contextArguments` on `@join__field`, in source order, with quotes in the selection escaped. The type that sets
the context prints `@context`. An overridden key or interface field stays and prints `usedOverridden: true`.
A description is printed as a block string. The first subgraph to set it wins, including an argument description. A field description keeps its line breaks. On an entity, a non-shareable `@override` replaces that field description, and an override with no description removes it. The subgraph URL is printed on `@join__graph`, with quotes and backslashes escaped. The subgraph name is escaped the same way, including in a `@context` prefix and in `@override(from:)`. `@tag` names are escaped the same way. A string escapes backspace, form feed, and other control characters. A field set inside `@join__field` escapes quotes the same way. Types, fields, and enum values follow the subgraph that sorts first by id. A later subgraph appends a name it introduces. A custom query, mutation, or subscription root is printed as `Query`, `Mutation`, or `Subscription`. A custom query root merges with a subgraph that uses `Query`. A custom mutation root merges with `Mutation`. A custom subscription root merges with `Subscription`. A `@specifiedBy` URL escapes quotes. The first subgraph to set `@specifiedBy` wins. A default string escapes quotes and newlines. A block-string default is printed on multiple lines. A null default is printed as `null`. A delete character in a default or a `@tag` stays in the text. A field argument list longer than 80 characters is printed on multiple lines, with no commas. A directive definition uses that same wrapping. A directive argument does not print its description, `@deprecated`, or `@cost`. A field argument description is a block string on that argument. A type description is a block string before the type. An enum value and an input field keep their descriptions. A description on the schema definition is omitted. `@oneOf` from one subgraph is printed after `@tag`. A `@deprecated` reason on a field argument escapes quotes. Boolean, null, number, empty list, and empty object defaults keep their spelling. A float keeps its source spelling, including an exponent. A repeatable composed directive keeps each application and its arguments. The same application from another subgraph is printed once. The same rule applies to a directive on an argument, an enum value, or an input field. On a field, that directive is printed before `@join__field`, and `@tag` follows `@join__field`. Directive definitions and applications keep the first subgraph's order. A directive that only a later subgraph defines is appended. A later subgraph can add an argument and a location. The argument becomes non-null when any subgraph declares it non-null, and `repeatable` is set when any subgraph sets it. A later directive-argument default replaces an earlier one. A composed directive keeps a schema location from any subgraph. An executable location stays only when every definition lists it. `@tag` names on a directive argument are combined, and `@inaccessible` is kept when any subgraph sets it.
`@deprecated` is printed on a field, an argument, an enum value, or an input field. An explicit reason is printed, including `No longer supported`, an empty reason, and escaped control characters. The first subgraph in id order keeps that reason.
`@authenticated`, `@policy`, and `@requiresScopes` are printed on a type or a field. An empty policy or scope group is printed. Merged with a named group, it becomes that named group. A group that contains another group is dropped. Groups of equal length are sorted by their text.
`@cost` and `@listSize` are printed when a subgraph uses them, including a weight or `assumedSize` of zero, on a scalar and an enum too. A renamed import keeps that local name. `@listSize` keeps the highest `assumedSize`, combines slicing arguments and sized fields, and prints `requireOneSlicingArgument: false` when any subgraph sets it false. A slicing argument that is missing from one subgraph is omitted. An empty `slicingArguments` or `sizedFields` list is printed. An interface field prints `requireOneSlicingArgument: true` when an implementor also has `@listSize` slicing arguments.
A directive named by `@composeDirective` is printed on the element that uses it, including an argument, an input field, an enum value, and the type. Its definition is printed in the supergraph. Locations, arguments, and `repeatable` are merged across subgraphs. An argument keeps `@tag` and `@inaccessible`. A renamed import on that feature link keeps `name` and `as`. A feature link with no directive import is omitted. A type import is omitted. The same feature keeps the highest version.
`@specifiedBy` is printed on a scalar. `@oneOf` is printed on an input object after `@tag` and `@inaccessible`, and its definition is printed. An input field prints `@cost` before `@deprecated`.
When one subgraph's field type is less non-null than another's, each `@join__field` prints `type`.
The schema lists a mutation root and a subscription root when a subgraph defines them.
An argument or an input field that is missing from one subgraph is omitted.
An input field becomes non-null when any subgraph declares it non-null, and each `@join__field` prints `type`.
An argument becomes non-null when any subgraph declares it non-null. A default value on any subgraph is kept.
An input-field default is printed only when every subgraph that defines the field sets one.
`@deprecated` and `@inaccessible` on an argument are kept when any subgraph sets them.
`@tag` names are combined, and `@cost` keeps the highest weight, including a negative weight on a field or an argument.
An `@tag`, `@inaccessible`, `@authenticated`, `@policy`, or `@requiresScopes` import that uses another name is printed under its specification name.
`@join__field` is printed before `@tag`, `@inaccessible`, `@authenticated`, `@cost`, `@listSize`, and `@deprecated`. A field argument prints its description, then `@tag`, `@inaccessible`, `@cost`, and `@deprecated`. A union prints `@join__unionMember` before `@tag` and `@inaccessible`. Its description stays in front.
`@join__field` prints `provides` before `requires`. A `@requires` selection omits a leaf that is in every `@key` of that type. The remaining fields are separated by one space. A `@provides` selection uses that same spacing. A nested selection is printed as `name{child}`. An inline fragment in `@requires` is printed as `...on Type{child}`. `@provides` on a union keeps its source text. A field argument is kept, and spaces around its punctuation are removed. The next field follows `)` with no space. A list value keeps one space between items, and an object value has no spaces inside its braces. A nested key such as `address { id }` stays in the selection, and the `@join__type` key keeps its source spacing. Each `@key` is its own `@join__type`, and `resolvable: false` stays on that key. Fields that are not in every key stay. A selection that is only those key fields omits `@requires`.
An executable directive keeps the locations shared by every subgraph that defines it. A directive with arguments is omitted when a subgraph does not define it.
An interface field that every subgraph defines does not print `@join__field`. A query field in every subgraph does not print `@join__field` unless it uses `@override`. The overridden source is omitted, and another `@shareable` query field stays. A labeled query `@override` keeps the source without `overrideLabel`. An object field copies `overrideLabel` onto its source, and another `@shareable` field stays without that label. `@join__implements` lists only the interfaces that subgraph defines. An object then prints `@tag`, authorization, and `@cost`. An interface does the same when it implements another interface. It then prints `@tag`. An implementor lists interfaces in its source order. Each graph lists its union members in that graph's source order. A union with one member prints that member. An unused scalar is printed. Its directives follow `@join__type`, `@tag`, `@inaccessible`, authorization, `@cost`, and `@specifiedBy`. An interface field that is missing from one subgraph prints `@join__field`. It prints `type` only on a subgraph whose type differs from the merged type. Query prints `@join__type` for every subgraph, with no key. Mutation and Subscription print `@join__type` only for a subgraph that defines them.
A mutation field does print `type` when the subgraphs disagree.
`@deprecated` and `@inaccessible` on an enum value are kept when any subgraph sets them. An enum value prints `@join__enumValue`, then `@tag`, `@inaccessible`, and `@deprecated`.
An enum used only as an input keeps the values that every subgraph defines. An enum used as both an input and an output keeps an `@inaccessible` value that another subgraph omits.
A federation v1 `@external` field that no `@key`, `@requires`, or `@provides` uses is omitted from `@join__field`. When that was its only subgraph, the field is omitted.
A default value is printed on an argument and on an input field.
`@join__type(extension: true)` marks an `extend
type`. An interface prints it only when that interface has a key and the subgraph extends it. An object that is defined and extended in one subgraph does not print it. `@extends` does. A federation v1 `extend type` does not print it. A federation v1 interface does not print a key. A federation v2 interface key can print `resolvable: false`. The join definitions are `join_printed`.
`public_schema` removes the schema definition, join and link definitions, imported federation directives, and every `@inaccessible` element. An inaccessible interface is removed from `implements`.

**Differences from upstream.** A feature `@link` version is
`major * 100 + minor`. `v1.10` stays above `v1.9`. Upstream
`mergeLinks` uses `parseFloat`, which keeps `v1.9`.
"""

from std.collections import Dict
from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.printer import print_node as print_ast_node
from gql_language.strip_ignored_characters import strip_ignored_characters
from gql_composition.error_code import CompositionError
from gql_composition.helpers import parse_fields, selection_set_of
from gql_composition.join_spec import join_printed, join_spec_version
from gql_composition.public_schema import public_schema
from gql_composition.later_versions import (
    ArgFact,
    DirectiveFact,
    FieldFact,
    GraphFacts,
    TypeFacts,
    description_block,
    graphql_escape,
    tag_suffix,
)
from gql_composition.link import ImportKind, Link, LinkImport
from gql_composition.state import ExtensionType, TypeKind, merge_scope_policies
from gql_composition.validate import Subgraph, validate_with_facts
from gql_composition.version import FederationVersion


@fieldwise_init
struct CompositionResult(Movable):
    """The errors of composition, or the printed supergraph."""

    var errors: List[CompositionError]
    """The errors. Empty when `supergraph_sdl` is set."""
    var supergraph_sdl: String
    """The supergraph SDL, or empty when `errors` is not empty."""
    var public_sdl: String
    """The public API schema, or empty when `errors` is not empty."""


def compose_subgraphs(subgraphs: List[Subgraph]) raises -> CompositionResult:
    """Compose subgraphs, as upstream `composeServices`, for printed types.

    Args:
        subgraphs: The subgraphs, in any order.

    Returns:
        The supergraph SDL when composition succeeds. The errors when it
        does not.

    Raises:
        Error: The errors of `validate_with_facts`.
    """
    var facts = List[GraphFacts]()
    var errors = validate_with_facts(subgraphs, facts)
    if len(errors) > 0:
        return CompositionResult(errors^, String(""), String(""))
    var sdl = _print(facts, subgraphs)
    return CompositionResult(List[CompositionError](), sdl, public_schema(sdl))


def _print(facts: List[GraphFacts], subgraphs: List[Subgraph]) raises -> String:
    """Print the supergraph of object types."""
    var version = _highest_version(facts)
    var query = _query_name(facts)
    var out = String(
        'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(url:'
        ' "https://specs.apollo.dev/join/'
        + join_spec_version(version)
        + '", for: EXECUTION)'
    )
    var tagged = _any_tag(facts)
    var hidden = _any_inaccessible(facts)
    var contextual = _any_context(facts)
    if contextual:
        out += (
            ' @link(url: "https://specs.apollo.dev/context/v0.1", for:'
            " SECURITY)"
        )
    if tagged:
        out += ' @link(url: "https://specs.apollo.dev/tag/v0.3")'
    var cost_link = _cost_link(facts)
    if cost_link.byte_length() > 0:
        out += cost_link
    if hidden:
        out += (
            ' @link(url: "https://specs.apollo.dev/inaccessible/v0.2", for:'
            " SECURITY)"
        )
    var policy = _any_policies(facts)
    var scopes = _any_scopes(facts)
    var authenticated = _any_authenticated(facts)
    if policy:
        out += (
            ' @link(url: "https://specs.apollo.dev/policy/v0.1", for: SECURITY)'
        )
    if scopes:
        out += (
            ' @link(url: "https://specs.apollo.dev/requiresScopes/v0.1", for:'
            " SECURITY)"
        )
    if authenticated:
        out += (
            ' @link(url: "https://specs.apollo.dev/authenticated/v0.1", for:'
            " SECURITY)"
        )
    out += _extra_links(facts)
    out += " {\n  query: " + query
    var mutation = _named_root(facts, 1)
    if mutation.byte_length() > 0:
        out += "\n  mutation: " + mutation
    var subscription = _named_root(facts, 2)
    if subscription.byte_length() > 0:
        out += "\n  subscription: " + subscription
    out += "\n}\n\n" + join_printed(version)
    if contextual:
        out += "\n\n" + _CONTEXT
    out += "\n\n" + _LINK
    if tagged:
        out += "\n\n" + _TAG
    if cost_link.byte_length() > 0:
        out += "\n\n" + _cost_definitions(facts)
    if hidden:
        out += "\n\n" + _INACCESSIBLE
    if policy:
        out += "\n\n" + _POLICY
    if scopes:
        out += "\n\n" + _SCOPES
    if authenticated:
        out += "\n\n" + _AUTHENTICATED
    var graphs = _graphs(facts, subgraphs)
    var composed = _print_composed(facts)
    out += "\n\n" + graphs
    if composed.byte_length() > 0:
        out += "\n\n" + composed
    out += "\n\n" + _types(facts)
    return out


comptime _CONTEXT = """directive @context(name: String!) repeatable on OBJECT | INTERFACE | UNION

directive @context__fromContext(field: context__ContextFieldValue) on ARGUMENT_DEFINITION

scalar context__ContextFieldValue"""
"""The context definitions Hive prints when a subgraph uses `@context`."""

comptime _LINK = """directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

scalar link__Import

enum link__Purpose {
  \"\"\"
  `SECURITY` features provide metadata necessary to securely resolve fields.
  \"\"\"
  SECURITY
  \"\"\"
  `EXECUTION` features provide metadata necessary for operation execution.
  \"\"\"
  EXECUTION
}"""
"""The link definitions Hive prints in a supergraph."""


comptime _TAG = """directive @tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA"""
"""The `@tag` definition Hive prints when a subgraph uses it."""

comptime _INACCESSIBLE = """directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION"""
"""The `@inaccessible` definition Hive prints when a subgraph uses it."""

comptime _POLICY = """directive @policy(policies: [[policy__Policy!]!]!) on ENUM | FIELD_DEFINITION | INTERFACE | OBJECT | SCALAR

scalar policy__Policy"""
"""The `@policy` definition Hive prints when a subgraph uses it."""

comptime _SCOPES = """directive @requiresScopes(scopes: [[requiresScopes__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

scalar requiresScopes__Scope"""
"""The `@requiresScopes` definition Hive prints when a subgraph uses it."""

comptime _AUTHENTICATED = """directive @authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM"""
"""The `@authenticated` definition Hive prints when a subgraph uses it."""


def _auth_suffix(
    authenticated: Bool,
    policies: List[List[String]],
    scopes: List[List[String]],
) -> String:
    """Return `@authenticated`, `@policy`, and `@requiresScopes`.

    Args:
        authenticated: Whether the element requires authentication.
        policies: The `@policy` groups.
        scopes: The `@requiresScopes` groups.

    Returns:
        The directives, or empty.
    """
    var out = String("")
    if authenticated:
        out += " @authenticated"
    if len(policies) > 0:
        out += " @policy(policies: " + _group_list(policies) + ")"
    if len(scopes) > 0:
        out += " @requiresScopes(scopes: " + _group_list(scopes) + ")"
    return out


def _group_list(groups: List[List[String]]) -> String:
    """Return a printed list of string groups.

    Args:
        groups: The groups.

    Returns:
        Text such as `[["read", "pii"], ["admin"]]`.
    """
    var out = String("[")
    var group_index = 0
    while group_index < len(groups):
        if group_index > 0:
            out += ", "
        out += "["
        for name_index in range(len(groups[group_index])):
            if name_index > 0:
                out += ", "
            out += _quoted(groups[group_index][name_index])
        out += "]"
        group_index += 1
    out += "]"
    return out


def _extra_links(facts: List[GraphFacts]) -> String:
    """Return composed-feature `@link` directives.

    A link with no directive import is omitted. Type imports are omitted.
    The same feature keeps the highest version and the union of its
    directive imports. A renamed import keeps `name` and `as`.

    Args:
        facts: The subgraphs, in id order.

    Returns:
        The links, each with a leading space, or empty.
    """
    var identities = List[String]()
    var versions = List[String]()
    var numbers = List[Int]()
    var imports = List[List[LinkImport]]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        for link_index in range(len(graph.links)):
            ref link = graph.links[link_index]
            if link.identity == "https://specs.apollo.dev/federation":
                continue
            var directives = _directive_imports(link)
            if len(directives) == 0:
                continue
            var version = String("")
            if link.version:
                version = String(link.version.value())
            var at = -1
            for seen_index in range(len(identities)):
                if identities[seen_index] == link.identity:
                    at = seen_index
            if at == -1:
                identities.append(String(link.identity))
                versions.append(version)
                numbers.append(_feature_version(version))
                imports.append(directives^)
                continue
            if _feature_version(version) > numbers[at]:
                numbers[at] = _feature_version(version)
                versions[at] = version
            var item_index = 0
            while item_index < len(directives):
                var seen = False
                var earlier = 0
                while earlier < len(imports[at]):
                    if imports[at][earlier].name == directives[item_index].name:
                        seen = True
                    earlier += 1
                if not seen:
                    imports[at].append(directives[item_index].copy())
                item_index += 1
        graph_index += 1
    var out = String("")
    for index in range(len(identities)):
        var url = String(identities[index])
        if versions[index].byte_length() > 0:
            url += "/" + versions[index]
        out += _print_feature_link(url, imports[index])
    return out


def _directive_imports(link: Link) -> List[LinkImport]:
    """Return the directive imports of a link.

    Args:
        link: A parsed `@link`.

    Returns:
        The imports whose names start with `@`.
    """
    var directives = List[LinkImport]()
    for index in range(len(link.imports)):
        if link.imports[index].kind == ImportKind.DIRECTIVE:
            directives.append(link.imports[index].copy())
    return directives^


def _feature_version(text: String) -> Int:
    """Return a feature version as `major * 100 + minor`.

    Args:
        text: A version such as `v1.10`, or empty.

    Returns:
        The number, or zero when `text` is empty. Validation accepts only
        a version of the form `v1.2`.
    """
    var dot = text.find(".")
    if dot == -1:
        return 0
    return _decimal(String(text[byte=1:dot])) * 100 + _decimal(
        String(text[byte = dot + 1 :])
    )


def _decimal(text: String) -> Int:
    """Return the integer in a string of digits.

    Args:
        text: The digits.

    Returns:
        The integer.
    """
    var bytes = text.as_bytes()
    var value = 0
    var index = 0
    while index < len(bytes):
        value = value * 10 + Int(bytes[index] - 48)
        index += 1
    return value


def _print_feature_link(url: String, imports: List[LinkImport]) -> String:
    """Print one feature `@link`.

    Args:
        url: The identity and version.
        imports: The directive imports.

    Returns:
        The directive, with a leading space. A long argument list wraps.
    """
    var url_arg = 'url: "' + url + '"'
    var import_arg = String("import: [")
    var index = 0
    while index < len(imports):
        if index > 0:
            import_arg += ", "
        ref item = imports[index]
        if item.alias:
            import_arg += (
                '{name: "'
                + _escape_string(item.name)
                + '", as: "'
                + _escape_string(String(item.alias.value()))
                + '"}'
            )
        else:
            import_arg += '"' + _escape_string(item.name) + '"'
        index += 1
    import_arg += "]"
    var args = url_arg + ", " + import_arg
    if args.byte_length() + 2 > 80:
        return " @link(\n  " + url_arg + "\n  " + import_arg + "\n)"
    return " @link(" + args + ")"


def _print_composed(facts: List[GraphFacts]) -> String:
    """Print composed and executable directive definitions.

    Args:
        facts: The subgraphs, in id order.

    Returns:
        The definitions, separated by blank lines, or empty.
    """
    var seen = List[String]()
    var out = String("")
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        for index in range(len(graph.directives)):
            ref directive = graph.directives[index]
            if not directive.composed and not directive.executable:
                continue
            var already = False
            for seen_index in range(len(seen)):
                if seen[seen_index] == directive.name:
                    already = True
            if already:
                continue
            seen.append(String(directive.name))
            var merged = _directive_copy(directive)
            _absorb_directive_sites(merged, facts)
            if not _keep_executable_directive(merged, facts):
                continue
            if out.byte_length() > 0:
                out += "\n\n"
            out += _print_directive(merged)
        graph_index += 1
    return out


def _keep_executable_directive(
    mut directive: DirectiveFact, facts: List[GraphFacts]
) -> Bool:
    """Apply Hive's executable-directive filter.

    A directive with arguments is omitted when it is missing from a
    subgraph. An executable location is kept only when every subgraph
    that defines the directive lists it. A schema location is kept only
    when the directive is composed. An empty location list omits the
    directive. A directive that is not executable is unchanged.

    Args:
        directive: The merged definition.
        facts: The subgraphs, in id order.

    Returns:
        Whether the definition is printed.
    """
    if not directive.executable:
        return True
    var defined = 0
    var graph_index = 0
    while graph_index < len(facts):
        if _defines_directive(facts[graph_index], directive.name):
            defined += 1
        graph_index += 1
    if len(directive.args) > 0 and defined != len(facts):
        return False
    var kept = List[String]()
    var index = 0
    while index < len(directive.locations):
        var location = directive.locations[index]
        if not _is_executable_location(location):
            if directive.composed:
                kept.append(String(location))
            index += 1
            continue
        if _every_definition_has(facts, directive.name, location):
            kept.append(String(location))
        index += 1
    directive.locations = kept^
    return len(directive.locations) > 0


def _defines_directive(graph: GraphFacts, name: String) -> Bool:
    """Return True when a subgraph defines a directive.

    Args:
        graph: The subgraph.
        name: The directive name.

    Returns:
        Whether the definition is executable or composed.
    """
    for index in range(len(graph.directives)):
        ref item = graph.directives[index]
        if item.name == name and (item.composed or item.executable):
            return True
    return False


def _every_definition_has(
    facts: List[GraphFacts], name: String, location: String
) -> Bool:
    """Return True when every definition lists a location.

    Args:
        facts: The subgraphs, in id order.
        name: The directive name.
        location: The location.

    Returns:
        Whether each subgraph that defines the directive lists it.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        for index in range(len(graph.directives)):
            ref item = graph.directives[index]
            if item.name != name or not (item.composed or item.executable):
                continue
            var found = False
            var loc_index = 0
            while loc_index < len(item.locations):
                if item.locations[loc_index] == location:
                    found = True
                loc_index += 1
            if not found:
                return False
        graph_index += 1
    return True


def _is_executable_location(location: String) -> Bool:
    """Return True for an executable directive location.

    Args:
        location: A GraphQL directive location.

    Returns:
        Whether Hive's `isExecutableDirectiveLocation` is true.
    """
    return (
        location == "FIELD"
        or location == "FRAGMENT_DEFINITION"
        or location == "FRAGMENT_SPREAD"
        or location == "INLINE_FRAGMENT"
        or location == "VARIABLE_DEFINITION"
        or location == "QUERY"
        or location == "MUTATION"
        or location == "SUBSCRIPTION"
    )


def _directive_copy(directive: DirectiveFact) -> DirectiveFact:
    """Copy one directive definition.

    Args:
        directive: The definition in one subgraph.

    Returns:
        A definition the printer can merge into.
    """
    var args = List[ArgFact]()
    for index in range(len(directive.args)):
        args.append(_copy_directive_arg(directive.args[index]))
    return DirectiveFact(
        String(directive.name),
        directive.executable,
        args^,
        directive.locations.copy(),
        directive.composed,
        directive.repeatable,
    )


def _copy_directive_arg(arg: ArgFact) -> ArgFact:
    """Copy one directive argument.

    Args:
        arg: The argument.

    Returns:
        A new argument with the same text.
    """
    return ArgFact(
        String(arg.name),
        String(arg.type_text),
        String(arg.default_value),
        arg.inaccessible,
        arg.from_context,
        String(arg.context_name),
        String(arg.context_selection),
        _copied_tags(arg.tags),
        String(arg.printed),
        String(arg.applied),
    )


def _absorb_directive_sites(mut dest: DirectiveFact, facts: List[GraphFacts]):
    """Merge every subgraph's definition of one directive.

    Locations stay in first-seen order. An argument becomes non-null when
    any subgraph declares it non-null. A later default replaces an earlier
    one. `@tag` names are combined, and `@inaccessible` is kept when any
    subgraph sets it. `repeatable` is set when any subgraph sets it.

    Args:
        dest: The definition being built. Its name selects the sites.
        facts: The subgraphs, in id order.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref directives = facts[graph_index].directives
        for index in range(len(directives)):
            ref source = directives[index]
            if source.name != dest.name:
                continue
            if not source.composed and not source.executable:
                continue
            if source.repeatable:
                dest.repeatable = True
            if source.executable:
                dest.executable = True
            if source.composed:
                dest.composed = True
            _merge_tags(dest.locations, source.locations)
            for arg_index in range(len(source.args)):
                ref arg = source.args[arg_index]
                var at = -1
                var have = 0
                while have < len(dest.args):
                    if dest.args[have].name == arg.name:
                        at = have
                    have += 1
                if at == -1:
                    dest.args.append(_copy_directive_arg(arg))
                    continue
                ref found = dest.args[at]
                if arg.type_text.endswith("!") and not found.type_text.endswith(
                    "!"
                ):
                    found.type_text = String(arg.type_text)
                if arg.default_value.byte_length() > 0:
                    found.default_value = String(arg.default_value)
                if arg.inaccessible:
                    found.inaccessible = True
                _merge_tags(found.tags, arg.tags)
                _merge_applied(found.applied, arg.applied)
        graph_index += 1


def _print_directive(directive: DirectiveFact) -> String:
    """Print one directive definition.

    Args:
        directive: The directive.

    Returns:
        The definition, such as `directive @foo(bar: String) on FIELD_DEFINITION`.
    """
    var out = String("directive @" + directive.name)
    if len(directive.args) > 0:
        var parts = List[String]()
        var index = 0
        while index < len(directive.args):
            ref arg = directive.args[index]
            var part = arg.name + ": " + arg.type_text
            if arg.default_value.byte_length() > 0:
                part += " = " + arg.default_value
            part += arg.applied
            part += tag_suffix(arg.tags)
            if arg.inaccessible:
                part += " @inaccessible"
            parts.append(part^)
            index += 1
        out += _parenthesize_args(parts)
    if directive.repeatable:
        out += " repeatable"
    out += " on "
    var index = 0
    while index < len(directive.locations):
        if index > 0:
            out += " | "
        out += directive.locations[index]
        index += 1
    return out


def _cost_link(facts: List[GraphFacts]) -> String:
    """Return the cost specification link, or empty.

    Args:
        facts: The subgraphs, in id order.

    Returns:
        The `@link` text, including a leading space, or empty.
    """
    var used = False
    var list_size = False
    var cost_name = String("")
    var list_name = String("")
    var index = 0
    while index < len(facts):
        if facts[index].cost_used:
            used = True
        if facts[index].list_size_used:
            list_size = True
        if (
            cost_name.byte_length() == 0
            and facts[index].cost_name.byte_length() > 0
        ):
            cost_name = String(facts[index].cost_name)
        if (
            list_name.byte_length() == 0
            and facts[index].list_size_name.byte_length() > 0
        ):
            list_name = String(facts[index].list_size_name)
        index += 1
    if not used:
        return String("")
    var imports = List[String]()
    if cost_name.byte_length() > 0 and cost_name != "cost":
        imports.append('{name: "@cost", as: "@' + cost_name + '"}')
    if list_size:
        if list_name != "listSize":
            imports.append('{name: "@listSize", as: "@' + list_name + '"}')
        else:
            imports.append(String('"@listSize"'))
    var url = String('url: "https://specs.apollo.dev/cost/v0.1"')
    if len(imports) == 0:
        return " @link(" + url + ")"
    var inside = String("")
    index = 0
    while index < len(imports):
        if index > 0:
            inside += ", "
        inside += imports[index]
        index += 1
    var args = url + ", import: [" + inside + "]"
    if args.byte_length() + 2 > 80:
        return " @link(\n  " + url + "\n  import: [" + inside + "]\n)"
    return " @link(" + args + ")"


def _cost_definitions(facts: List[GraphFacts]) -> String:
    """Return the cost directive definitions.

    Args:
        facts: The subgraphs, in id order.

    Returns:
        The `@cost` and `@listSize` definitions, using a local name when
        a subgraph renames one.
    """
    var cost_name = String("cost")
    var list_name = String("listSize")
    var index = 0
    while index < len(facts):
        if facts[index].cost_name.byte_length() > 0:
            cost_name = String(facts[index].cost_name)
        if facts[index].list_size_name.byte_length() > 0:
            list_name = String(facts[index].list_size_name)
        index += 1
    return (
        "directive @"
        + cost_name
        + "(weight: Int!) on ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION |"
        " INPUT_FIELD_DEFINITION | OBJECT | SCALAR\n\ndirective @"
        + list_name
        + "(\n  assumedSize: Int\n  slicingArguments: [String!]\n  sizedFields:"
        " [String!]\n  requireOneSlicingArgument: Boolean = true\n) on"
        " FIELD_DEFINITION"
    )


def _spec_suffix(specified_by: String, is_one_of: Bool) -> String:
    """Return `@specifiedBy` and `@oneOf`.

    Args:
        specified_by: The URL, or empty.
        is_one_of: Whether the input object has `@oneOf`.

    Returns:
        The directives, or empty.
    """
    var out = String("")
    if specified_by.byte_length() > 0:
        out += " @specifiedBy(url: " + _quoted(specified_by) + ")"
    if is_one_of:
        out += " @oneOf"
    return out


def _cost_text(has_cost: Bool, cost: Int, name: String) -> String:
    """Return the printed cost directive.

    Args:
        has_cost: Whether the element has `@cost`.
        cost: The weight.
        name: The local directive name, or empty for `cost`.

    Returns:
        ` @cost(weight: N)`, or empty.
    """
    if not has_cost:
        return String("")
    var directive = name
    if directive.byte_length() == 0:
        directive = String("cost")
    return " @" + directive + "(weight: " + String(cost) + ")"


def _any_authenticated(facts: List[GraphFacts]) -> Bool:
    """Return True when a type or field is `@authenticated`.

    Args:
        facts: The subgraphs, in id order.

    Returns:
        Whether the supergraph should link the authenticated spec.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        var type_index = 0
        while type_index < len(graph.types):
            ref type = graph.types[type_index]
            if type.authenticated:
                return True
            for field_index in range(len(type.fields)):
                if type.fields[field_index].authenticated:
                    return True
            type_index += 1
        graph_index += 1
    return False


def _any_policies(facts: List[GraphFacts]) -> Bool:
    """Return True when a type or field has `@policy`.

    Args:
        facts: The subgraphs, in id order.

    Returns:
        Whether the supergraph should link the policy spec.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        var type_index = 0
        while type_index < len(graph.types):
            ref type = graph.types[type_index]
            if len(type.policies) > 0:
                return True
            for field_index in range(len(type.fields)):
                if len(type.fields[field_index].policies) > 0:
                    return True
            type_index += 1
        graph_index += 1
    return False


def _any_scopes(facts: List[GraphFacts]) -> Bool:
    """Return True when a type or field has `@requiresScopes`.

    Args:
        facts: The subgraphs, in id order.

    Returns:
        Whether the supergraph should link the requiresScopes spec.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        var type_index = 0
        while type_index < len(graph.types):
            ref type = graph.types[type_index]
            if len(type.scopes) > 0:
                return True
            for field_index in range(len(type.fields)):
                if len(type.fields[field_index].scopes) > 0:
                    return True
            type_index += 1
        graph_index += 1
    return False


def _any_context(facts: List[GraphFacts]) -> Bool:
    """Return True when a subgraph uses `@context`.

    Validation refuses a `@fromContext` without its `@context` in the same
    subgraph (`CONTEXT_NOT_SET`), so `@context` alone decides.

    Args:
        facts: The subgraphs, in id order.

    Returns:
        Whether the supergraph should link the context spec.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        var type_index = 0
        while type_index < len(graph.types):
            if len(graph.types[type_index].contexts) > 0:
                return True
            type_index += 1
        graph_index += 1
    return False


def _any_tag(facts: List[GraphFacts]) -> Bool:
    """Return True when a type, field, argument, or enum value has `@tag`.

    Args:
        facts: The subgraphs, in id order.

    Returns:
        Whether the supergraph should link the tag spec.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        var type_index = 0
        while type_index < len(graph.types):
            ref type = graph.types[type_index]
            if len(type.tags) > 0:
                return True
            for field_index in range(len(type.fields)):
                ref field = type.fields[field_index]
                if len(field.tags) > 0:
                    return True
                for arg_index in range(len(field.arg_facts)):
                    if len(field.arg_facts[arg_index].tags) > 0:
                        return True
            for value_index in range(len(type.value_tags)):
                if len(type.value_tags[value_index]) > 0:
                    return True
            type_index += 1
        graph_index += 1
    return False


def _any_inaccessible(facts: List[GraphFacts]) -> Bool:
    """Return True when a type, field, argument, or enum value is `@inaccessible`.

    Args:
        facts: The subgraphs, in id order.

    Returns:
        Whether the supergraph should link the inaccessible spec.
    """
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        var type_index = 0
        while type_index < len(graph.types):
            ref type = graph.types[type_index]
            if type.inaccessible:
                return True
            for field_index in range(len(type.fields)):
                ref field = type.fields[field_index]
                if field.inaccessible:
                    return True
                for arg_index in range(len(field.arg_facts)):
                    if field.arg_facts[arg_index].inaccessible:
                        return True
            for value_index in range(len(type.value_hidden)):
                if type.value_hidden[value_index]:
                    return True
            type_index += 1
        graph_index += 1
    return False


def _highest_version(facts: List[GraphFacts]) -> FederationVersion:
    """Return the highest federation version among the subgraphs."""
    var number = 100
    var index = 0
    while index < len(facts):
        if facts[index].version_number > number:
            number = facts[index].version_number
        index += 1
    if number == 100:
        return FederationVersion.V1_0
    return FederationVersion(UInt8(number - 199))


def _named_root(facts: List[GraphFacts], kind: Int) -> String:
    """Return the first root name of one kind.

    Args:
        facts: The subgraphs, in id order.
        kind: `1` for mutation and `2` for subscription.

    Returns:
        The name, or empty when no subgraph defines that root.
    """
    var index = 0
    while index < len(facts):
        var name = String(facts[index].subscription_name)
        if kind == 1:
            name = String(facts[index].mutation_name)
        if name.byte_length() > 0:
            return name
        index += 1
    return String("")


def _query_name(facts: List[GraphFacts]) -> String:
    """Return the first query root name.

    Validation refuses subgraphs where none defines a query root
    (`NO_QUERIES`), so one subgraph has a name.
    """
    var index = 0
    while facts[index].query_name.byte_length() == 0:
        index += 1
    return String(facts[index].query_name)


def _url(subgraphs: List[Subgraph], name: String) -> String:
    """Return the URL of a subgraph, or empty.

    Args:
        subgraphs: The subgraphs passed to `compose_subgraphs`.
        name: The subgraph name.

    Returns:
        The URL, or empty when the subgraph has none. Each fact comes from
        one of `subgraphs`, so the name is always found.
    """
    var index = 0
    while subgraphs[index].name != name:
        index += 1
    if subgraphs[index].url:
        return String(subgraphs[index].url.value())
    return String("")


def _escape_string(text: String) -> String:
    """Escape a value for the inside of a GraphQL string.

    Args:
        text: The raw text.

    Returns:
        The text with quotes, backslashes, line breaks, and other control
        characters escaped.
    """
    return graphql_escape(text)


def _graphs(facts: List[GraphFacts], subgraphs: List[Subgraph]) -> String:
    """Print `enum join__Graph`."""
    var out = String("enum join__Graph {\n")
    var index = 0
    while index < len(facts):
        ref graph = facts[index]
        out += (
            "  "
            + graph.graph_id
            + ' @join__graph(name: "'
            + _escape_string(graph.graph_name)
            + '", url: "'
            + _escape_string(_url(subgraphs, graph.graph_name))
            + '")\n'
        )
        index += 1
    out += "}"
    return out


@fieldwise_init
struct _FieldSite(Movable):
    """One subgraph's contribution to a field."""

    var graph_id: String
    var graph_name: String
    var external: Bool
    var requires: String
    var provides: String
    var override_from: String
    var override_label: String
    var context_arguments: String
    var keep_when_overridden: Bool
    var used_overridden: Bool
    var type_text: String
    var fed_v1: Bool
    var referenced: Bool
    var required: Bool
    var on_extension: Bool
    var shareable: Bool
    var site_description: String


@fieldwise_init
struct _FieldUse(Movable):
    """The graphs that define one field, in id order."""

    var name: String
    var type_text: String
    var arguments: String
    var sites: List[_FieldSite]
    var inaccessible: Bool
    var tags: List[String]
    var bare_join: Bool
    var description: String
    var deprecation: String
    var authenticated: Bool
    var policies: List[List[String]]
    var scopes: List[List[String]]
    var has_cost: Bool
    var cost: Int
    var list_size: String
    var applied: String
    var seen_output: Bool
    var default_value: String
    var arg_names: List[String]
    var arg_texts: List[String]
    var arg_counts: List[Int]
    var arg_types: List[String]
    var arg_defaults: List[String]
    var default_sites: Int
    var has_list_size: Bool
    var list_assumed: Int
    var list_require: Bool
    var list_print_require: Bool
    var list_slicing: List[String]
    var list_sized: List[String]
    var list_directive: String
    var list_has_slicing: Bool
    var list_has_sized: Bool


@fieldwise_init
struct _JoinType(Movable):
    """One subgraph's `@join__type` for an object."""

    var graph_id: String
    var extension: Bool
    var keys: List[String]
    var key_resolvable: List[Bool]
    var interfaces: List[String]
    var interface_object: Bool
    var members: List[String]


@fieldwise_init
struct _Merged(Movable):
    """An object type gathered from every subgraph."""

    var name: String
    var is_enum: Bool
    var is_interface: Bool
    var is_union: Bool
    var is_input: Bool
    var is_scalar: Bool
    var joins: List[_JoinType]
    var fields: List[_FieldUse]
    var values: List[_FieldUse]
    var inaccessible: Bool
    var tags: List[String]
    var contexts: List[String]
    var description: String
    var authenticated: Bool
    var policies: List[List[String]]
    var scopes: List[List[String]]
    var has_cost: Bool
    var cost: Int
    var applied: String
    var specified_by: String
    var is_one_of: Bool
    var is_query: Bool
    var used_as_input: Bool
    var used_as_output: Bool
    var cost_name: String


def _types(facts: List[GraphFacts]) raises -> String:
    """Print types in Hive's kind order, each kind in first-seen order."""
    var names = List[String]()
    var merged = List[_Merged]()
    var index_of = Dict[String, Int]()
    var objects = List[Int]()
    var interfaces = List[Int]()
    var unions = List[Int]()
    var enums = List[Int]()
    var inputs = List[Int]()
    var scalars = List[Int]()
    var graph_index = 0
    while graph_index < len(facts):
        _merge_graph(
            names,
            merged,
            index_of,
            objects,
            interfaces,
            unions,
            enums,
            inputs,
            scalars,
            facts[graph_index],
        )
        graph_index += 1
    # A field copied from an interface object is in no subgraph, so it does
    # not mark the interface field.
    _mark_interface_list_size(merged)
    _add_interface_object_fields(merged, index_of)
    _copy_implementor_auth(merged)
    _apply_override_descriptions(merged)
    _fill_query_joins(merged, facts)
    var order = List[Int]()
    for index in range(len(scalars)):
        order.append(scalars[index])
    var index = 0
    while index < len(objects):
        order.append(objects[index])
        index += 1
    for index in range(len(interfaces)):
        order.append(interfaces[index])
    for index in range(len(unions)):
        order.append(unions[index])
    for index in range(len(enums)):
        order.append(enums[index])
    for index in range(len(inputs)):
        order.append(inputs[index])
    var out = String("")
    index = 0
    while index < len(order):
        if index > 0:
            out += "\n\n"
        out += _print_type(merged[order[index]], len(facts))
        index += 1
    # Upstream `supergraphSdl` has no trailing line break.
    return out


def _merge_graph(
    mut names: List[String],
    mut merged: List[_Merged],
    mut index_of: Dict[String, Int],
    mut objects: List[Int],
    mut interfaces: List[Int],
    mut unions: List[Int],
    mut enums: List[Int],
    mut inputs: List[Int],
    mut scalars: List[Int],
    graph: GraphFacts,
) raises:
    """Add one subgraph's object, interface, union, enum, and input types."""
    var type_index = 0
    while type_index < len(graph.types):
        ref type = graph.types[type_index]
        if type.kind == TypeKind.DIRECTIVE:
            type_index += 1
            continue
        var at = _merged_index(
            names,
            merged,
            index_of,
            objects,
            interfaces,
            unions,
            enums,
            inputs,
            scalars,
            type.name,
            type.kind == TypeKind.ENUM,
            type.kind == TypeKind.INTERFACE,
            type.kind == TypeKind.UNION,
            type.kind == TypeKind.INPUT_OBJECT,
            type.kind == TypeKind.SCALAR,
        )
        var keys = List[String]()
        var resolvable = List[Bool]()
        var keep_keys = (
            type.kind != TypeKind.INTERFACE or graph.version_number >= 200
        )
        if keep_keys:
            for key_index in range(len(type.keys)):
                keys.append(String(type.keys[key_index]))
                resolvable.append(type.key_resolvable[key_index])
        var extension = _federation_extension(type, graph.version_number)
        if type.kind == TypeKind.INTERFACE:
            extension = _interface_extension(
                type, graph.version_number, len(keys)
            )
        var implemented = List[String]()
        for name_index in range(len(type.interfaces)):
            implemented.append(String(type.interfaces[name_index]))
        var members = List[String]()
        if type.kind == TypeKind.UNION:
            members = type.values.copy()
        merged[at].joins.append(
            _JoinType(
                String(graph.graph_id),
                extension,
                keys^,
                resolvable^,
                implemented^,
                type.is_interface_object,
                members^,
            )
        )
        if type.inaccessible:
            merged[at].inaccessible = True
        _merge_tags(merged[at].tags, type.tags)
        var prefixed = List[String]()
        for context_index in range(len(type.contexts)):
            prefixed.append(
                graph.graph_name + "__" + type.contexts[context_index]
            )
        _merge_tags(merged[at].contexts, prefixed)
        if (
            merged[at].description.byte_length() == 0
            and type.description.byte_length() > 0
        ):
            merged[at].description = String(type.description)
        if type.authenticated:
            merged[at].authenticated = True
        merged[at].policies = merge_scope_policies(
            merged[at].policies, type.policies
        )
        merged[at].scopes = merge_scope_policies(merged[at].scopes, type.scopes)
        if type.has_cost and (
            not merged[at].has_cost or type.cost > merged[at].cost
        ):
            merged[at].has_cost = True
            merged[at].cost = type.cost
        if type.applied.byte_length() > 0:
            _merge_applied(merged[at].applied, type.applied)
        if (
            merged[at].specified_by.byte_length() == 0
            and type.specified_by.byte_length() > 0
        ):
            merged[at].specified_by = String(type.specified_by)
        if type.is_one_of:
            merged[at].is_one_of = True
        if len(type.input_refs) > 0:
            merged[at].used_as_input = True
        if len(type.output_refs) > 0:
            merged[at].used_as_output = True
        if (
            graph.cost_name.byte_length() > 0
            and merged[at].cost_name.byte_length() == 0
        ):
            merged[at].cost_name = String(graph.cost_name)
        if graph.query_name.byte_length() > 0 and type.name == graph.query_name:
            merged[at].is_query = True
        for field_index in range(len(type.fields)):
            _add_field(
                merged[at],
                type.fields[field_index],
                String(graph.graph_id),
                String(graph.graph_name),
                _is_interface_field(graph, type, type.fields[field_index].name),
                graph.version_number < 200,
                _selected_by_directive(
                    graph, type.name, type.fields[field_index].name
                ),
                type.keys,
                graph,
                type.extension,
            )
        for value_index in range(len(type.values)):
            var hidden = False
            if value_index < len(type.value_hidden):
                hidden = type.value_hidden[value_index]
            # An enum or a union fills these lists for each value.
            _add_value(
                merged[at],
                type.values[value_index],
                graph.graph_id,
                hidden,
                type.value_tags[value_index].copy(),
                String(type.value_descriptions[value_index]),
                String(type.value_deprecations[value_index]),
                String(type.value_applied[value_index]),
            )
        type_index += 1


def _merged_index(
    mut names: List[String],
    mut merged: List[_Merged],
    mut index_of: Dict[String, Int],
    mut objects: List[Int],
    mut interfaces: List[Int],
    mut unions: List[Int],
    mut enums: List[Int],
    mut inputs: List[Int],
    mut scalars: List[Int],
    name: String,
    is_enum: Bool,
    is_interface: Bool,
    is_union: Bool,
    is_input: Bool,
    is_scalar: Bool,
) -> Int:
    """Return the merged type, creating it on first sight."""
    var found = index_of.get(name)
    if found:
        return found.value()
    var at = len(names)
    names.append(name)
    merged.append(
        _Merged(
            name,
            is_enum,
            is_interface,
            is_union,
            is_input,
            is_scalar,
            List[_JoinType](),
            List[_FieldUse](),
            List[_FieldUse](),
            False,
            List[String](),
            List[String](),
            String(""),
            False,
            List[List[String]](),
            List[List[String]](),
            False,
            0,
            String(""),
            String(""),
            False,
            False,
            False,
            False,
            String(""),
        )
    )
    if is_interface:
        interfaces.append(at)
    elif is_union:
        unions.append(at)
    elif is_enum:
        enums.append(at)
    elif is_input:
        inputs.append(at)
    elif is_scalar:
        scalars.append(at)
    else:
        objects.append(at)
    index_of[name] = at
    return at


def _provides_text(graph: GraphFacts, field: FieldFact) raises -> String:
    """Return the printed `@provides` selection.

    A referenced extension drops the fields that are in every `@key`.
    The remaining fields use Hive's spacing. A union keeps the source
    text.

    Args:
        graph: The subgraph.
        field: The field that has `@provides`.

    Returns:
        The selection, or empty when there is no `@provides`.
    """
    if field.provides.byte_length() == 0:
        return String("")
    var named = _named_type(field.type_text)
    # The subgraph defines the type of each of its fields.
    var index = 0
    while graph.types[index].name != named:
        index += 1
    ref owner = graph.types[index]
    if owner.kind == TypeKind.UNION:
        return String(field.provides)
    var keys = List[String]()
    if owner.extension:
        keys = owner.keys.copy()
    return _without_key_fields(keys^, field.provides)


def _without_key_fields(keys: List[String], selection: String) raises -> String:
    """Remove `@key` fields from a `@requires` or `@provides` selection.

    Upstream `createFieldsTransformer`: a top-level leaf that is in every
    `@key` is dropped, and the rest is printed with ignored characters
    stripped. Upstream `filterSelectionSetNode` starts a nested path with
    a dot, so a nested leaf never matches a key path and stays.

    Args:
        keys: The `@key` field sets.
        selection: The field set.

    Returns:
        The selection without those leaves, or empty.

    Raises:
        Error: When a field set does not parse. Validation parses each
        field set first.
    """
    if selection.byte_length() == 0:
        return String("")
    var common = List[String]()
    if len(keys) > 0:
        common = _key_leaves(keys[0])
        for index in range(1, len(keys)):
            var leaves = _key_leaves(keys[index])
            var next = List[String]()
            for common_index in range(len(common)):
                if _listed(leaves, common[common_index]):
                    next.append(String(common[common_index]))
            common = next^
    var document = parse_fields(selection)
    var out = String("{")
    var child = document.first_child(selection_set_of(document))
    while child != NO_NODE:
        if not _is_leaf_in(document, child, common):
            out += print_ast_node(document, child) + " "
        child = document.next_sibling(child)
    var printed = strip_ignored_characters(out + "}")
    return String(printed[byte = 1 : printed.byte_length() - 1])


def _key_leaves(key: String) raises -> List[String]:
    """Return the top-level leaf fields of a `@key`.

    Args:
        key: A `@key` field set.

    Returns:
        The names of the fields that have no selection set.

    Raises:
        Error: When the field set does not parse.
    """
    var document = parse_fields(key)
    var leaves = List[String]()
    var child = document.first_child(selection_set_of(document))
    while child != NO_NODE:
        if document.child(child, Role.SELECTION_SET) == NO_NODE:
            leaves.append(String(document.name(child)))
        child = document.next_sibling(child)
    return leaves^


def _is_leaf_in(
    document: Document, selection: Int, names: List[String]
) -> Bool:
    """Return True for a field with no selection set whose name is listed.

    Args:
        document: The parsed field set.
        selection: A top-level selection.
        names: The leaf names to drop.

    Returns:
        Whether upstream `filterSelectionSetNode` removes the selection.
    """
    if document.kind(selection) != Kind.FIELD:
        return False
    if document.child(selection, Role.SELECTION_SET) != NO_NODE:
        return False
    return _listed(names, String(document.name(selection)))


def _listed(names: List[String], name: String) -> Bool:
    """Return True when `name` is in `names`.

    Args:
        names: The names.
        name: The name to find.

    Returns:
        Whether the name is present.
    """
    for index in range(len(names)):
        if names[index] == name:
            return True
    return False


def _is_interface_field(
    graph: GraphFacts, type: TypeFacts, field_name: String
) -> Bool:
    """Return True when an implemented interface defines this field here.

    Args:
        graph: The subgraph.
        type: The object type.
        field_name: The field name.

    Returns:
        Whether this graph's interface contributes the field.
    """
    for name_index in range(len(type.interfaces)):
        var interface_name = type.interfaces[name_index]
        var type_index = 0
        while type_index < len(graph.types):
            ref candidate = graph.types[type_index]
            # A subgraph has one type of each name, so it is the interface.
            if candidate.name != interface_name:
                type_index += 1
                continue
            var field_index = 0
            while field_index < len(candidate.fields):
                if candidate.fields[field_index].name == field_name:
                    return True
                field_index += 1
            type_index += 1
    return False


def _is_name_start(byte: UInt8) -> Bool:
    """Return True when a byte can start a GraphQL name.

    Args:
        byte: One byte of a field set.

    Returns:
        Whether the byte is a letter or `_`.
    """
    return (
        (byte >= UInt8(ord("A")) and byte <= UInt8(ord("Z")))
        or (byte >= UInt8(ord("a")) and byte <= UInt8(ord("z")))
        or byte == UInt8(ord("_"))
    )


def _is_name_continue(byte: UInt8) -> Bool:
    """Return True when a byte can continue a GraphQL name.

    Args:
        byte: One byte of a field set.

    Returns:
        Whether the byte is a letter, a digit, or `_`.
    """
    return _is_name_start(byte) or _is_digit(byte)


def _top_level_has(text: String, name: String) -> Bool:
    """Return True when a field set selects `name` on this type.

    Nested selections belong to another type. Arguments are ignored.

    Args:
        text: A `@requires` or `@provides` field set.
        name: The field name.

    Returns:
        Whether `name` is a top-level selection.
    """
    var bytes = text.as_bytes()
    var depth = 0
    var in_arguments = False
    var index = 0
    var limit = len(bytes)
    while index < limit:
        var byte = bytes[index]
        if in_arguments:
            # GraphQL values do not nest parentheses.
            if byte == UInt8(ord(")")):
                in_arguments = False
            index += 1
            continue
        if byte == UInt8(ord("(")):
            in_arguments = True
            index += 1
            continue
        if byte == UInt8(ord("{")):
            depth += 1
            index += 1
            continue
        if byte == UInt8(ord("}")):
            depth -= 1
            index += 1
            continue
        if depth == 0 and _is_name_start(byte):
            var end = index + 1
            while end < limit and _is_name_continue(bytes[end]):
                end += 1
            if String(text[byte=index:end]) == name:
                return True
            index = end
            continue
        index += 1
    return False


def _named_type(text: String) -> String:
    """Return the named type inside a printed type.

    Args:
        text: A printed type, such as `[User!]!`.

    Returns:
        The name, such as `User`.
    """
    return text.replace("[", "").replace("]", "").replace("!", "")


def _selected_by_directive(
    graph: GraphFacts, type_name: String, field_name: String
) -> Bool:
    """Return True when `@requires` or `@provides` selects the field.

    Args:
        graph: The subgraph.
        type_name: The object type that declares the field.
        field_name: The field name.

    Returns:
        Whether a directive in this subgraph selects the field.
    """
    var type_index = 0
    while type_index < len(graph.types):
        ref owner = graph.types[type_index]
        for field_index in range(len(owner.fields)):
            ref field = owner.fields[field_index]
            if owner.name == type_name and field.requires.byte_length() > 0:
                if _top_level_has(field.requires, field_name):
                    return True
            if (
                field.provides.byte_length() > 0
                and _named_type(field.type_text) == type_name
            ):
                if _top_level_has(field.provides, field_name):
                    return True
        type_index += 1
    return False


def _add_field(
    mut merged: _Merged,
    field: FieldFact,
    graph_id: String,
    graph_name: String,
    interface_field: Bool,
    fed_v1: Bool,
    referenced: Bool,
    keys: List[String],
    graph: GraphFacts,
    on_extension: Bool,
) raises:
    """Record a field on the graph that defines it.

    Args:
        merged: The type being built.
        field: The field in one subgraph.
        graph_id: The subgraph id.
        graph_name: The subgraph name.
        interface_field: Whether an interface in this subgraph defines it.
        fed_v1: Whether the subgraph is federation v1.
        referenced: Whether `@requires` or `@provides` selects the field.
        keys: The `@key` field sets of the type in this subgraph.
        graph: The subgraph. `@provides` is read from the type it returns.
        on_extension: Whether this subgraph extends the type.
    """
    var site = _FieldSite(
        graph_id,
        graph_name,
        field.external and not field.used_as_key,
        _without_key_fields(keys, field.requires),
        _provides_text(graph, field),
        String(field.override_from),
        String(field.override_label),
        _context_arguments(field, graph_name),
        (field.used_as_key and not field.external) or interface_field,
        False,
        String(field.type_text),
        fed_v1,
        referenced,
        field.required,
        on_extension,
        field.shareable,
        String(field.description),
    )
    for index in range(len(merged.fields)):
        if merged.fields[index].name != field.name:
            continue
        ref found = merged.fields[index]
        if field.inaccessible:
            found.inaccessible = True
        _merge_tags(found.tags, field.tags)
        if (
            found.description.byte_length() == 0
            and field.description.byte_length() > 0
        ):
            found.description = String(field.description)
        if (
            found.deprecation.byte_length() == 0
            and field.deprecation.byte_length() > 0
        ):
            found.deprecation = String(field.deprecation)
        if field.authenticated:
            found.authenticated = True
        found.policies = merge_scope_policies(found.policies, field.policies)
        found.scopes = merge_scope_policies(found.scopes, field.scopes)
        if field.has_cost and (not found.has_cost or field.cost > found.cost):
            found.has_cost = True
            found.cost = field.cost
        _merge_list_size(found, field)
        if field.applied.byte_length() > 0:
            _merge_applied(found.applied, field.applied)
        _note_input_default(found, field)
        if merged.is_input:
            _merge_input_type(found, field)
        else:
            _widen_output(found, field)
        found.sites.append(site^)
        _record_args(found, field, merged.is_interface)
        return
    var sites = List[_FieldSite]()
    sites.append(site^)
    merged.fields.append(
        _FieldUse(
            String(field.name),
            String(field.type_text),
            String(field.arguments),
            sites^,
            field.inaccessible,
            _copied_tags(field.tags),
            False,
            String(field.description),
            String(field.deprecation),
            field.authenticated,
            _copied_groups(field.policies),
            _copied_groups(field.scopes),
            field.has_cost,
            field.cost,
            String(field.list_size),
            String(field.applied),
            (not field.used_as_key) and (not field.external),
            String(field.default_value),
            List[String](),
            List[String](),
            List[Int](),
            List[String](),
            List[String](),
            0,
            field.has_list_size,
            field.list_assumed,
            field.list_require,
            field.list_print_require,
            _copied_tags(field.slicing_arguments),
            _copied_tags(field.list_sized),
            String(field.list_directive),
            field.has_slicing_arguments,
            field.has_sized_fields,
        )
    )
    _record_args(
        merged.fields[len(merged.fields) - 1], field, merged.is_interface
    )
    _note_input_default(merged.fields[len(merged.fields) - 1], field)


def _merge_list_size(mut found: _FieldUse, field: FieldFact):
    """Merge `@listSize` the way Hive does.

    `assumedSize` keeps the highest number. Slicing arguments and sized
    fields are combined in first-seen order. `requireOneSlicingArgument`
    stays true only when every subgraph leaves it true.

    Args:
        found: The merged field.
        field: The field in one more subgraph.
    """
    if not field.has_list_size:
        return
    if not found.has_list_size:
        found.has_list_size = True
        found.list_assumed = field.list_assumed
        found.list_require = field.list_require
        found.list_print_require = field.list_print_require
        found.list_slicing = _copied_tags(field.slicing_arguments)
        found.list_sized = _copied_tags(field.list_sized)
        found.list_has_slicing = field.has_slicing_arguments
        found.list_has_sized = field.has_sized_fields
        found.list_directive = String(field.list_directive)
        found.list_size = String(field.list_size)
        return
    found.list_print_require = False
    if field.list_assumed >= 0 and (
        found.list_assumed < 0 or field.list_assumed > found.list_assumed
    ):
        found.list_assumed = field.list_assumed
    found.list_require = found.list_require and field.list_require
    if field.has_slicing_arguments:
        found.list_has_slicing = True
    if field.has_sized_fields:
        found.list_has_sized = True
    _merge_tags(found.list_slicing, field.slicing_arguments)
    _merge_tags(found.list_sized, field.list_sized)
    found.list_size = _format_list_size(found)


def _format_list_size(field: _FieldUse) -> String:
    """Print a merged `@listSize`.

    Args:
        field: The merged field.

    Returns:
        The directive, with a leading space, or empty.
    """
    if not field.has_list_size:
        return String("")
    # A field with `@listSize` always has the directive's local name.
    var directive = String(field.list_directive)
    var parts = List[String]()
    if not field.list_require or field.list_print_require:
        var flag = String("requireOneSlicingArgument: ")
        if field.list_require:
            flag += "true"
        else:
            flag += "false"
        parts.append(flag^)
    if field.list_assumed >= 0:
        parts.append("assumedSize: " + String(field.list_assumed))
    if field.list_has_slicing:
        # Validation refuses a field whose slicing arguments are all
        # dropped (`LIST_SIZE_INVALID_SLICING_ARGUMENT`).
        parts.append("slicingArguments: " + _quoted_list(_kept_slicing(field)))
    if field.list_has_sized:
        parts.append("sizedFields: " + _quoted_list(field.list_sized))
    if len(parts) == 0:
        return " @" + directive
    var joined = String("")
    var index = 0
    while index < len(parts):
        if index > 0:
            joined += ", "
        joined += parts[index]
        index += 1
    if joined.byte_length() + 2 > 80:
        var wrapped = String("")
        var index = 0
        while index < len(parts):
            if index > 0:
                wrapped += "\n  "
            wrapped += parts[index]
            index += 1
        return " @" + directive + "(\n  " + wrapped + "\n)"
    return " @" + directive + "(" + joined + ")"


def _kept_slicing(field: _FieldUse) -> List[String]:
    """Return slicing arguments that exist in every subgraph.

    Args:
        field: The merged field.

    Returns:
        The names Hive still prints. A field with no sites keeps every name.
    """
    var graphs = len(field.sites)
    var kept = List[String]()
    for index in range(len(field.list_slicing)):
        var name = field.list_slicing[index]
        var count = 0
        var arg_index = 0
        while arg_index < len(field.arg_names):
            if field.arg_names[arg_index] == name:
                count = field.arg_counts[arg_index]
            arg_index += 1
        if graphs == 0 or count == graphs:
            kept.append(String(name))
    return kept^


def _quoted_list(names: List[String]) -> String:
    """Return a printed list of GraphQL strings.

    Args:
        names: The strings.

    Returns:
        Text such as `["first", "last"]`.
    """
    var out = String("[")
    for index in range(len(names)):
        if index > 0:
            out += ", "
        out += '"' + _escape_string(names[index]) + '"'
    out += "]"
    return out


def _note_input_default(mut found: _FieldUse, field: FieldFact):
    """Count an input-field default from one subgraph.

    The first subgraph's default is kept. When the first subgraph has no
    default, the default is not printed, so a later one is not kept.

    Args:
        found: The merged field.
        field: The field in that subgraph.
    """
    if field.default_value.byte_length() > 0:
        found.default_sites += 1


def _strip_inaccessible(text: String) -> String:
    """Remove `@inaccessible` from a printed argument.

    Args:
        text: The printed argument.

    Returns:
        The argument without that directive.
    """
    var needle = String(" @inaccessible")
    var cleaned = String(text)
    var at = cleaned.find(needle)
    while at != -1:
        var skip = at + needle.byte_length()
        var head = String(cleaned[byte=0:at])
        var tail = String(cleaned[byte = skip : cleaned.byte_length()])
        cleaned = head + tail
        at = cleaned.find(needle)
    return cleaned


def _record_args(
    mut found: _FieldUse, field: FieldFact, omit_inaccessible: Bool
):
    """Count the arguments present in one more subgraph.

    An interface field argument does not print `@inaccessible`.

    Args:
        found: The merged field.
        field: The field in that subgraph.
        omit_inaccessible: Whether to drop `@inaccessible` from the argument.
    """
    for index in range(len(field.arg_facts)):
        ref arg = field.arg_facts[index]
        if arg.from_context:
            continue
        var at = -1
        for name_index in range(len(found.arg_names)):
            if found.arg_names[name_index] == arg.name:
                at = name_index
        if at == -1:
            var printed = String(arg.printed)
            if omit_inaccessible:
                printed = _strip_inaccessible(printed)
            found.arg_names.append(String(arg.name))
            found.arg_texts.append(printed^)
            found.arg_counts.append(1)
            found.arg_types.append(String(arg.type_text))
            found.arg_defaults.append(String(arg.default_value))
        else:
            found.arg_counts[at] += 1
            var described = _description_prefix(arg.printed)
            if described.byte_length() > 0 and not found.arg_texts[
                at
            ].startswith('"""'):
                found.arg_texts[at] = described + found.arg_texts[at]
            var type_text = String(found.arg_types[at])
            if arg.type_text.endswith("!") and not type_text.endswith("!"):
                found.arg_texts[at] = found.arg_texts[at].replace(
                    arg.name + ": " + type_text, arg.name + ": " + arg.type_text
                )
                found.arg_types[at] = String(arg.type_text)
                type_text = String(arg.type_text)
            if (
                found.arg_defaults[at].byte_length() == 0
                and arg.default_value.byte_length() > 0
            ):
                found.arg_texts[at] = found.arg_texts[at].replace(
                    arg.name + ": " + type_text,
                    arg.name + ": " + type_text + " = " + arg.default_value,
                )
                found.arg_defaults[at] = String(arg.default_value)
            for tag_index in range(len(arg.tags)):
                var piece = (
                    ' @tag(name: "' + _escape_string(arg.tags[tag_index]) + '")'
                )
                if found.arg_texts[at].find(piece) == -1:
                    _insert_before(
                        found.arg_texts[at],
                        piece,
                        [
                            String(" @inaccessible"),
                            String(" @deprecated"),
                        ],
                    )
            var weight = _argument_cost(arg.printed)
            if weight:
                var had = _argument_cost(found.arg_texts[at])
                var name = _weight_name(arg.printed)
                if not had:
                    _insert_before(
                        found.arg_texts[at],
                        " @"
                        + name
                        + "(weight: "
                        + String(weight.value())
                        + ")",
                        [String(" @deprecated")],
                    )
                elif weight.value() > had.value():
                    found.arg_texts[at] = found.arg_texts[at].replace(
                        "@" + name + "(weight: " + String(had.value()) + ")",
                        "@" + name + "(weight: " + String(weight.value()) + ")",
                    )
            if arg.applied.byte_length() > 0:
                var pieces = _split_applied(arg.applied)
                var piece_index = 0
                while piece_index < len(pieces):
                    if found.arg_texts[at].find(pieces[piece_index]) == -1:
                        _insert_before(
                            found.arg_texts[at],
                            pieces[piece_index],
                            [
                                String(" @tag("),
                                String(" @inaccessible"),
                                String(" @deprecated"),
                            ],
                        )
                    piece_index += 1
            if (
                arg.inaccessible
                and not omit_inaccessible
                and found.arg_texts[at].find("@inaccessible") == -1
            ):
                _insert_before(
                    found.arg_texts[at],
                    " @inaccessible",
                    [
                        String(" @deprecated"),
                    ],
                )
            if found.arg_texts[at].find("@deprecated") == -1:
                var marker = arg.printed.find(" @deprecated")
                if marker != -1:
                    found.arg_texts[at] += String(arg.printed[byte=marker:])


def _description_prefix(printed: String) -> String:
    """Return the leading description block of a printed argument.

    Args:
        printed: The argument, including its description when one is set.

    Returns:
        The block string and its trailing newline, or empty.
    """
    if not printed.startswith('"""'):
        return String("")
    # `description_block` closes the block with a line of its own, and it
    # escapes `"""` in the text.
    var close = printed.find('\n"""\n')
    return String(printed[byte = 0 : close + 5])


def _insert_before(mut text: String, piece: String, later: List[String]):
    """Insert directives before the first of some later directives.

    Hive prints an argument's directives in this order: composed
    directives, `@tag`, `@inaccessible`, the cost directive, `@deprecated`.

    Args:
        text: The printed argument.
        piece: The directives, with a leading space.
        later: The texts of the directives that print after `piece`. The
            cost directive is always one of them. A cost piece is inserted
            only when the text has no cost directive.
    """
    var needles = later.copy()
    needles.append(_cost_needle(text))
    var at = -1
    var index = 0
    while index < len(needles):
        var found = text.find(needles[index])
        if found != -1 and (at == -1 or found < at):
            at = found
        index += 1
    if at == -1:
        text += piece
        return
    text = String(text[byte=0:at]) + piece + String(text[byte=at:])


def _cost_needle(text: String) -> String:
    """Return the text that starts the cost directive of a printed argument.

    Args:
        text: The printed argument.

    Returns:
        Text such as ` @cost(weight: `.
    """
    return " @" + _weight_name(text) + "(weight: "


def _weight_name(printed: String) -> String:
    """Return the directive name before `(weight:`.

    Args:
        printed: Printed GraphQL that can contain a cost directive.

    Returns:
        The name, or `cost` when the text has no cost directive.
    """
    var marker = printed.find("(weight: ")
    if marker == -1:
        return String("cost")
    var at = String(printed[byte=0:marker]).rfind("@")
    return String(printed[byte = at + 1 : marker])


def _is_digit(byte: UInt8) -> Bool:
    """Return True for an ASCII digit.

    Args:
        byte: One byte.

    Returns:
        Whether the byte is `0` to `9`.
    """
    return byte >= 48 and byte <= 57


def _argument_cost(printed: String) -> Optional[Int]:
    """Return the cost weight in a printed argument.

    Args:
        printed: The printed argument.

    Returns:
        The weight, including a negative weight, or none when there is no
        cost directive.
    """
    var needle = "(weight: "
    var marker = printed.find(needle)
    if marker == -1:
        return None
    # The printer writes an integer and then `)`.
    var bytes = printed.as_bytes()
    var digits = marker + needle.byte_length()
    var negative = bytes[digits] == 45
    if negative:
        digits += 1
    var value = 0
    while _is_digit(bytes[digits]):
        value = value * 10 + Int(bytes[digits] - 48)
        digits += 1
    if negative:
        value = -value
    return value


def _copied_arguments(field: _FieldUse) -> String:
    """Return arguments copied from an interface-object field.

    Args:
        field: The interface field.

    Returns:
        The arguments every subgraph that defines the field declares,
        separated by a comma and a space, or empty.
    """
    # An interface-object field comes from a subgraph, so it has sites.
    var out = String("")
    var graphs = len(field.sites)
    for index in range(len(field.arg_names)):
        if field.arg_counts[index] != graphs:
            continue
        if out.byte_length() > 0:
            out += ", "
        out += field.arg_texts[index]
    return out


def _shared_arguments(field: _FieldUse) -> String:
    """Return the parenthesized arguments of a field, or empty.

    An argument is printed when every subgraph that defines the field
    defines it. The list is one line when that line is 80 characters or
    fewer. A longer list is one argument per line, with no commas.

    Args:
        field: The merged field.

    Returns:
        The argument list, including parentheses, or empty.
    """
    var parts = List[String]()
    if len(field.sites) == 0:
        if field.arguments.byte_length() == 0:
            return String("")
        parts.append(String(field.arguments))
    else:
        var graphs = len(field.sites)
        for index in range(len(field.arg_names)):
            if field.arg_counts[index] != graphs:
                continue
            parts.append(String(field.arg_texts[index]))
    if len(parts) == 0:
        return String("")
    return _parenthesize_args(parts)


def _parenthesize_args(parts: List[String]) -> String:
    """Print arguments as Hive `printArgs` does.

    Args:
        parts: The printed arguments, in source order.

    Returns:
        The parenthesized list.
    """
    var line = String("(")
    var index = 0
    while index < len(parts):
        if index > 0:
            line += ", "
        line += parts[index]
        index += 1
    line += ")"
    if line.byte_length() <= 80:
        return line
    var joined = String("")
    index = 0
    while index < len(parts):
        if index > 0:
            joined += "\n"
        joined += parts[index]
        index += 1
    return "(\n  " + joined.replace("\n", "\n  ") + "\n)"


def _copied_groups(groups: List[List[String]]) -> List[List[String]]:
    """Copy scope or policy groups.

    Args:
        groups: The groups.

    Returns:
        A new list with the same groups.
    """
    return merge_scope_policies(List[List[String]](), groups)


def _copied_tags(tags: List[String]) -> List[String]:
    """Copy tag names.

    Args:
        tags: The names, in source order.

    Returns:
        A new list with the same names.
    """
    var copied = List[String]()
    for index in range(len(tags)):
        copied.append(String(tags[index]))
    return copied^


def _merge_applied(mut dest: String, source: String):
    """Add composed directive applications that are not already present.

    Hive keeps the first printed form of each application.

    Args:
        dest: The applications already printed, each with a leading space.
        source: The applications from one more subgraph.
    """
    if source.byte_length() == 0:
        return
    var existing = _split_applied(dest)
    var incoming = _split_applied(source)
    var index = 0
    while index < len(incoming):
        if not _listed(existing, incoming[index]):
            dest += incoming[index]
            existing.append(String(incoming[index]))
        index += 1


def _split_applied(text: String) -> List[String]:
    """Split composed applications into one directive each.

    Args:
        text: Applications, each with a leading space.

    Returns:
        The directives, including the leading space.
    """
    var parts = List[String]()
    if text.byte_length() == 0:
        return parts^
    var bytes = text.as_bytes()
    var limit = len(bytes)
    var start = 0
    var index = 0
    var depth = 0
    var quoted = False
    while index < limit:
        var byte = bytes[index]
        if quoted:
            if byte == UInt8(ord("\\")):
                index += 2
                continue
            if byte == UInt8(ord('"')):
                quoted = False
            index += 1
            continue
        if byte == UInt8(ord('"')):
            quoted = True
            index += 1
            continue
        # Outside the arguments, a printed space starts the next directive.
        if byte == UInt8(ord("(")):
            depth += 1
        elif byte == UInt8(ord(")")):
            depth -= 1
        elif depth == 0 and byte == UInt8(ord(" ")) and index != start:
            parts.append(String(text[byte=start:index]))
            start = index
        index += 1
    parts.append(String(text[byte=start:limit]))
    return parts^


def _merge_tags(mut dest: List[String], source: List[String]):
    """Append tag names that are not already present.

    Args:
        dest: The names already recorded, in first-seen order.
        source: The names from one more subgraph.
    """
    for index in range(len(source)):
        var seen = False
        for earlier in range(len(dest)):
            if dest[earlier] == source[index]:
                seen = True
        if not seen:
            dest.append(String(source[index]))


def _add_value(
    mut merged: _Merged,
    name: String,
    graph_id: String,
    hidden: Bool,
    tags: List[String],
    description: String,
    deprecation: String,
    applied: String,
):
    """Record an enum value or union member on the graph that defines it.

    Args:
        merged: The type being built.
        name: The enum value or union member.
        graph_id: The subgraph id.
        hidden: Whether the enum value is `@inaccessible`.
        tags: The `@tag` names on the enum value.
        description: The description text, or empty.
        deprecation: The printed `@deprecated`, or empty.
        applied: The composed directives, each with a leading space.
    """
    var site = _FieldSite(
        graph_id,
        String(""),
        False,
        String(""),
        String(""),
        String(""),
        String(""),
        String(""),
        False,
        False,
        String(""),
        False,
        False,
        False,
        False,
        False,
        String(""),
    )
    for index in range(len(merged.values)):
        if merged.values[index].name == name:
            if hidden:
                merged.values[index].inaccessible = True
            _merge_tags(merged.values[index].tags, tags)
            if (
                merged.values[index].description.byte_length() == 0
                and description.byte_length() > 0
            ):
                merged.values[index].description = String(description)
            if (
                merged.values[index].deprecation.byte_length() == 0
                and deprecation.byte_length() > 0
            ):
                merged.values[index].deprecation = String(deprecation)
            if applied.byte_length() > 0:
                _merge_applied(merged.values[index].applied, applied)
            merged.values[index].sites.append(site^)
            return
    var sites = List[_FieldSite]()
    sites.append(site^)
    merged.values.append(
        _FieldUse(
            name,
            String(""),
            String(""),
            sites^,
            hidden,
            _copied_tags(tags),
            False,
            String(description),
            String(deprecation),
            False,
            List[List[String]](),
            List[List[String]](),
            False,
            0,
            String(""),
            String(applied),
            False,
            String(""),
            List[String](),
            List[String](),
            List[Int](),
            List[String](),
            List[String](),
            0,
            False,
            -1,
            True,
            False,
            List[String](),
            List[String](),
            String(""),
            False,
            False,
        )
    )


def _indent(text: String) -> String:
    """Indent every line by two spaces.

    Args:
        text: The text.

    Returns:
        The indented text.
    """
    return "  " + text.replace("\n", "\n  ")


def _with_description(body: String, description: String) -> String:
    """Put a block description before a definition.

    Args:
        body: The definition.
        description: The description text, or empty.

    Returns:
        The description and the definition, or the definition alone.
    """
    var block = description_block(description)
    if block.byte_length() == 0:
        return body
    return block + "\n" + body


def _print_type(merged: _Merged, graph_count: Int) -> String:
    """Print one object or interface type.

    Args:
        merged: The type.
        graph_count: The number of subgraphs. A query field in every
            subgraph omits `@join__field` unless it uses `@override`.

    Returns:
        The printed type.
    """
    if merged.is_scalar:
        var scalar = String("scalar " + merged.name)
        scalar += merged.applied
        var index = 0
        while index < len(merged.joins):
            scalar += " " + _print_join(merged.joins[index])
            index += 1
        scalar += tag_suffix(merged.tags)
        if merged.inaccessible:
            scalar += " @inaccessible"
        scalar += _auth_suffix(
            merged.authenticated, merged.policies, merged.scopes
        )
        scalar += _cost_text(merged.has_cost, merged.cost, merged.cost_name)
        scalar += _spec_suffix(merged.specified_by, merged.is_one_of)
        return _with_description(scalar, merged.description)
    if merged.is_enum:
        return _print_enum(merged)
    if merged.is_union:
        return _print_union(merged)
    var keyword = String("type")
    if merged.is_interface:
        keyword = String("interface")
    if merged.is_input:
        keyword = String("input")
    var out = keyword + " " + merged.name
    var implemented = _implemented(merged)
    if len(implemented) > 0:
        out += " implements " + implemented[0]
        for index in range(1, len(implemented)):
            out += " & " + implemented[index]
    out += merged.applied
    var index = 0
    while index < len(merged.joins):
        out += " " + _print_join(merged.joins[index])
        index += 1
    index = 0
    while index < len(merged.joins):
        for name_index in range(len(merged.joins[index].interfaces)):
            out += (
                " @join__implements(graph: "
                + merged.joins[index].graph_id
                + ', interface: "'
                + merged.joins[index].interfaces[name_index]
                + '")'
            )
        index += 1
    out += _print_contexts(merged.contexts)
    out += tag_suffix(merged.tags)
    if merged.inaccessible:
        out += " @inaccessible"
    out += _auth_suffix(merged.authenticated, merged.policies, merged.scopes)
    out += _cost_text(merged.has_cost, merged.cost, merged.cost_name)
    out += _spec_suffix(merged.specified_by, merged.is_one_of)
    out += " {\n"
    var owners = len(merged.joins)
    index = 0
    while index < len(merged.fields):
        ref field = merged.fields[index]
        if merged.is_input and len(field.sites) != owners:
            index += 1
            continue
        var body = String("")
        var block = description_block(field.description)
        if block.byte_length() > 0:
            body += block + "\n"
        body += field.name
        body += _shared_arguments(field)
        body += ": " + field.type_text
        # Only an input field has a default.
        if field.default_value.byte_length() > 0 and field.default_sites == len(
            field.sites
        ):
            body += " = " + field.default_value
        body += field.applied
        if field.bare_join:
            body += " @join__field"
        var sites = _kept_sites(field, not merged.is_query)
        if len(sites) == 0 and not field.bare_join:
            index += 1
            continue
        var types_differ = not merged.is_query and _types_differ(
            sites, field.type_text
        )
        var include_all = types_differ and not merged.is_interface
        var interface_complete = merged.is_interface and len(sites) == owners
        var query_complete = merged.is_query and len(sites) == graph_count
        if query_complete:
            var site_index = 0
            while site_index < len(sites):
                if sites[site_index].override_from.byte_length() > 0:
                    query_complete = False
                site_index += 1
        if (
            not field.bare_join
            and not interface_complete
            and not query_complete
            and (include_all or not _field_is_plain(sites, owners))
        ):
            var site_index = 0
            while site_index < len(sites):
                var include_type = include_all or (
                    merged.is_interface
                    and sites[site_index].type_text != field.type_text
                )
                body += " " + _print_field(sites[site_index], include_type)
                site_index += 1
        body += tag_suffix(field.tags)
        if field.inaccessible:
            body += " @inaccessible"
        body += _auth_suffix(field.authenticated, field.policies, field.scopes)
        body += _cost_text(field.has_cost, field.cost, merged.cost_name)
        body += _format_list_size(field)
        body += field.deprecation
        out += _indent(body) + "\n"
        index += 1
    out += "}"
    return _with_description(out, merged.description)


def _print_union(merged: _Merged) -> String:
    """Print one union. Each graph lists its members in source order."""
    var out = String("union " + merged.name)
    out += merged.applied
    var index = 0
    while index < len(merged.joins):
        out += " " + _print_join(merged.joins[index])
        index += 1
    index = 0
    while index < len(merged.joins):
        ref join = merged.joins[index]
        var member_index = 0
        while member_index < len(join.members):
            out += (
                " @join__unionMember(graph: "
                + join.graph_id
                + ', member: "'
                + join.members[member_index]
                + '")'
            )
            member_index += 1
        index += 1
    out += _print_contexts(merged.contexts)
    out += tag_suffix(merged.tags)
    if merged.inaccessible:
        out += " @inaccessible"
    out += " = " + merged.values[0].name
    for index in range(1, len(merged.values)):
        out += " | " + merged.values[index].name
    return _with_description(out, merged.description)


def _implemented(merged: _Merged) -> List[String]:
    """Return implemented interfaces in first-seen order."""
    var names = List[String]()
    var index = 0
    while index < len(merged.joins):
        for name_index in range(len(merged.joins[index].interfaces)):
            var name = merged.joins[index].interfaces[name_index]
            var seen = False
            for earlier in range(len(names)):
                if names[earlier] == name:
                    seen = True
            if not seen:
                names.append(name)
        index += 1
    return names^


def _print_enum(merged: _Merged) -> String:
    """Print one enum. Each value lists every graph that defines it."""
    var out = String("enum " + merged.name)
    out += merged.applied
    var index = 0
    while index < len(merged.joins):
        out += " " + _print_join(merged.joins[index])
        index += 1
    out += tag_suffix(merged.tags)
    if merged.inaccessible:
        out += " @inaccessible"
    out += _auth_suffix(merged.authenticated, merged.policies, merged.scopes)
    out += _cost_text(merged.has_cost, merged.cost, merged.cost_name)
    out += _spec_suffix(merged.specified_by, merged.is_one_of)
    out += " {\n"
    index = 0
    while index < len(merged.values):
        ref value = merged.values[index]
        if (
            merged.used_as_input
            and not merged.used_as_output
            and len(value.sites) != len(merged.joins)
        ):
            index += 1
            continue
        var body = String("")
        var block = description_block(value.description)
        if block.byte_length() > 0:
            body += block + "\n"
        body += value.name
        body += value.applied
        var graph_index = 0
        while graph_index < len(value.sites):
            body += (
                " @join__enumValue(graph: "
                + value.sites[graph_index].graph_id
                + ")"
            )
            graph_index += 1
        body += tag_suffix(value.tags)
        if value.inaccessible:
            body += " @inaccessible"
        body += value.deprecation
        out += _indent(body) + "\n"
        index += 1
    out += "}"
    return _with_description(out, merged.description)


def _kept_sites(field: _FieldUse, copy_label: Bool) -> List[_FieldSite]:
    """Drop a field only for an `@override` that has no label.

    A labeled override is progressive. Both graphs keep the field, and the
    source graph copies the label. A query field does not copy that label.
    An unlabeled override keeps the source when that source uses the field
    as a key or as an interface field, and then prints `usedOverridden:
    true`. A federation v1 `@external` field that no `@key`, `@requires`,
    or `@provides` uses is omitted.

    Args:
        field: The merged field.
        copy_label: Whether the source graph prints `overrideLabel`.

    Returns:
        The sites to print, in graph order.
    """
    var dropped = List[String]()
    var labeled_from = List[String]()
    var labeled_value = List[String]()
    for index in range(len(field.sites)):
        ref site = field.sites[index]
        if site.override_from.byte_length() == 0:
            continue
        if site.override_label.byte_length() == 0:
            dropped.append(String(site.override_from))
        else:
            labeled_from.append(String(site.override_from))
            labeled_value.append(String(site.override_label))
    var kept = List[_FieldSite]()
    for index in range(len(field.sites)):
        ref site = field.sites[index]
        var skip = False
        for name_index in range(len(dropped)):
            if site.graph_name == dropped[name_index]:
                skip = True
        if skip and not site.keep_when_overridden:
            continue
        # A site that is still here when skipped keeps the field.
        var mark_overridden = skip
        # Federation v1 has no `@override`.
        if site.fed_v1 and site.external and not site.referenced:
            continue
        # An `@external` field has no `@requires`, `@provides`, `@override`,
        # or `@fromContext` argument of its own here. `required` covers
        # `referenced`: both mean a `@requires` or `@provides` selects it.
        if (
            site.external
            and site.on_extension
            and not site.required
            and not site.keep_when_overridden
        ):
            continue
        var label = String(site.override_label)
        if copy_label and label.byte_length() == 0:
            for name_index in range(len(labeled_from)):
                if site.graph_name == labeled_from[name_index]:
                    label = String(labeled_value[name_index])
        kept.append(
            _FieldSite(
                String(site.graph_id),
                String(site.graph_name),
                site.external,
                String(site.requires),
                String(site.provides),
                String(site.override_from),
                label^,
                String(site.context_arguments),
                site.keep_when_overridden,
                mark_overridden,
                String(site.type_text),
                site.fed_v1,
                site.referenced,
                site.required,
                site.on_extension,
                site.shareable,
                String(site.site_description),
            )
        )
    return kept^


def _types_differ(sites: List[_FieldSite], merged_type: String) -> Bool:
    """Return True when a graph's field type differs from the merged type.

    Args:
        sites: The graphs that define the field.
        merged_type: The type printed on the field.

    Returns:
        Whether each `@join__field` should include `type`.
    """
    for index in range(len(sites)):
        if sites[index].type_text != merged_type:
            return True
    return False


def _last_bang(text: String) -> Int:
    """Return the index of the last `!`, or -1.

    Args:
        text: A printed type.

    Returns:
        The byte index, or -1 when the type is nullable.
    """
    return text.rfind("!")


def _merge_input_type(mut found: _FieldUse, field: FieldFact):
    """Keep a non-null input type when any subgraph uses one.

    Args:
        found: The merged field.
        field: The field in one more subgraph.
    """
    if field.type_text.endswith("!") and not found.type_text.endswith("!"):
        found.type_text = String(field.type_text)


def _widen_output(mut found: _FieldUse, field: FieldFact):
    """Keep the least non-null output type, as Hive does.

    Args:
        found: The merged field.
        field: The field in one more subgraph.
    """
    var contributes = (not field.used_as_key) and (not field.external)
    var force = contributes and (not found.seen_output)
    var wider = _last_bang(found.type_text) > _last_bang(field.type_text)
    if force or ((not field.external) and wider):
        found.type_text = String(field.type_text)
    if contributes:
        found.seen_output = True


def _field_is_plain(sites: List[_FieldSite], owners: Int) -> Bool:
    """Return True when every owner defines the field with no join metadata."""
    if len(sites) != owners:
        return False
    var index = 0
    while index < len(sites):
        if _has_join_metadata(sites[index]):
            return False
        index += 1
    return True


def _has_join_metadata(site: _FieldSite) -> Bool:
    """Return True when a site prints an argument on `@join__field`.

    Args:
        site: One subgraph's field.

    Returns:
        Whether the site is external, uses `@requires`, `@provides`, or
        `@override`, is overridden, or has a `@fromContext` argument.
    """
    return (
        site.external
        or site.requires.byte_length() > 0
        or site.provides.byte_length() > 0
        or site.override_from.byte_length() > 0
        or site.override_label.byte_length() > 0
        or site.used_overridden
        or site.context_arguments.byte_length() > 0
    )


def _print_field(site: _FieldSite, include_type: Bool) -> String:
    """Print one `@join__field`.

    Argument order matches Hive: `graph`, `type`, `override`,
    `overrideLabel`, `usedOverridden`, `external`, `provides`, `requires`,
    `contextArguments`.
    """
    var args = List[String]()
    args.append(String("graph: " + site.graph_id))
    if include_type:
        args.append(String("type: " + _quoted(site.type_text)))
    if site.override_from.byte_length() > 0:
        args.append(String("override: " + _quoted(site.override_from)))
    if site.override_label.byte_length() > 0:
        args.append(String("overrideLabel: " + _quoted(site.override_label)))
    if site.used_overridden:
        args.append(String("usedOverridden: true"))
    if site.external:
        args.append(String("external: true"))
    if site.provides.byte_length() > 0:
        args.append(String("provides: " + _quoted(site.provides)))
    if site.requires.byte_length() > 0:
        args.append(String("requires: " + _quoted(site.requires)))
    if site.context_arguments.byte_length() > 0:
        args.append(String("contextArguments: " + site.context_arguments))
    var line = String("(")
    var index = 0
    while index < len(args):
        if index > 0:
            line += ", "
        line += args[index]
        index += 1
    line += ")"
    if line.byte_length() <= 80:
        return "@join__field" + line
    var wrapped = String("(\n  ")
    index = 0
    while index < len(args):
        if index > 0:
            wrapped += "\n  "
        wrapped += args[index]
        index += 1
    wrapped += "\n)"
    return "@join__field" + wrapped


def _context_arguments(field: FieldFact, graph_name: String) -> String:
    """Return the printed `contextArguments` list for one graph.

    Args:
        field: The field.
        graph_name: The subgraph name. Hive prefixes each context with it.

    Returns:
        The list, or empty when the field has no `@fromContext` argument.
    """
    var items = String("")
    for index in range(len(field.arg_facts)):
        ref argument = field.arg_facts[index]
        if not argument.from_context:
            continue
        if items.byte_length() > 0:
            items += ", "
        items += (
            "{context: "
            + _quoted(graph_name + "__" + argument.context_name)
            + ", name: "
            + _quoted(argument.name)
            + ", type: "
            + _quoted(argument.type_text)
            + ", selection: "
            + _quoted(argument.context_selection)
            + "}"
        )
    if items.byte_length() == 0:
        return String("")
    return "[" + items + "]"


def _quoted(text: String) -> String:
    """Return a GraphQL string literal, escaped as JSON.

    Args:
        text: The string value.

    Returns:
        The value inside double quotes.
    """
    return '"' + graphql_escape(text) + '"'


def _print_contexts(contexts: List[String]) -> String:
    """Return the printed `@context` directives.

    Args:
        contexts: The context names, already prefixed with the graph name.

    Returns:
        ` @context(name: "...")` for each name, or empty.
    """
    var out = String("")
    for index in range(len(contexts)):
        out += ' @context(name: "' + _escape_string(contexts[index]) + '")'
    return out


def _interface_extension(type: TypeFacts, version: Int, key_count: Int) -> Bool:
    """Return whether an interface `@join__type` prints `extension: true`.

    Hive prints it only for a federation v2 interface that has a key and is
    extended. A definition in the same subgraph does not remove it. A
    federation v1 interface does not print a key.

    Args:
        type: The interface in one subgraph.
        version: The federation version number, `major * 100 + minor`.
        key_count: The number of keys this join prints.

    Returns:
        Whether the join prints `extension: true`.
    """
    # A federation v1 interface keeps no key, so `key_count` is zero there.
    if key_count == 0:
        return False
    return type.extension


def _federation_extension(type: TypeFacts, version: Int) -> Bool:
    """Return whether `@join__type` prints `extension: true`.

    Args:
        type: The type in one subgraph.
        version: The federation version number, `major * 100 + minor`.

    Returns:
        Whether Hive treats the type as a federation extension.
    """
    if not type.extension:
        return False
    if version < 200 and type.extension_type != ExtensionType.EXTENDS:
        return False
    if type.extension_type == ExtensionType.EXTENDS:
        return True
    if type.is_definition:
        return False
    return True


def _print_join(join: _JoinType) -> String:
    """Print one `@join__type`."""
    if len(join.keys) == 0:
        # Upstream prints `extension` only with a key, and
        # `@interfaceObject` needs a key.
        return "@join__type(graph: " + join.graph_id + ")"
    var out = String("")
    var index = 0
    while index < len(join.keys):
        if index > 0:
            out += " "
        out += (
            "@join__type(graph: "
            + join.graph_id
            + ", key: "
            + _quoted(join.keys[index])
        )
        if not join.key_resolvable[index]:
            out += ", resolvable: false"
        if join.interface_object:
            out += ", isInterfaceObject: true"
        if join.extension:
            out += ", extension: true"
        out += ")"
        index += 1
    return out


def _mark_interface_list_size(mut merged: List[_Merged]):
    """Print `requireOneSlicingArgument` on an interface field.

    Hive sets the flag when the interface field and an implementor both
    have `@listSize` slicing arguments.

    Args:
        merged: The types gathered from every subgraph.
    """
    var iface_index = 0
    while iface_index < len(merged):
        if not merged[iface_index].is_interface:
            iface_index += 1
            continue
        var iface_name = String(merged[iface_index].name)
        var object_index = 0
        while object_index < len(merged):
            if not _implements_name(merged[object_index], iface_name):
                object_index += 1
                continue
            var field_index = 0
            while field_index < len(merged[iface_index].fields):
                if (
                    len(_kept_slicing(merged[iface_index].fields[field_index]))
                    == 0
                ):
                    field_index += 1
                    continue
                var field_name = merged[iface_index].fields[field_index].name
                var object_field = 0
                while object_field < len(merged[object_index].fields):
                    if (
                        merged[object_index].fields[object_field].name
                        != field_name
                    ):
                        object_field += 1
                        continue
                    if (
                        len(
                            _kept_slicing(
                                merged[object_index].fields[object_field]
                            )
                        )
                        == 0
                    ):
                        object_field += 1
                        continue
                    merged[iface_index].fields[
                        field_index
                    ].list_print_require = True
                    object_field += 1
                field_index += 1
            object_index += 1
        iface_index += 1


def _implements_name(merged: _Merged, name: String) -> Bool:
    """Return True when an object implements an interface.

    Args:
        merged: The object type.
        name: The interface name.

    Returns:
        Whether one `@join__type` lists the interface.
    """
    var index = 0
    while index < len(merged.joins):
        for name_index in range(len(merged.joins[index].interfaces)):
            if merged.joins[index].interfaces[name_index] == name:
                return True
        index += 1
    return False


def _query_interfaces(joins: List[_JoinType], graph_id: String) -> List[String]:
    """Return the interfaces one subgraph declares on Query.

    Args:
        joins: The joins already gathered for Query.
        graph_id: The subgraph id.

    Returns:
        The interface names, or an empty list when that subgraph does not
        define Query.
    """
    var index = 0
    while index < len(joins):
        if joins[index].graph_id != graph_id:
            index += 1
            continue
        var interfaces = List[String]()
        for name_index in range(len(joins[index].interfaces)):
            interfaces.append(String(joins[index].interfaces[name_index]))
        return interfaces^
    return List[String]()


def _fill_query_joins(mut merged: List[_Merged], facts: List[GraphFacts]):
    """Give Query a bare `@join__type` for every subgraph.

    Hive prints one join type per subgraph, including a subgraph that does
    not define Query. A key on Query is not printed. Interfaces stay on the
    subgraph that declares them. Mutation and Subscription are unchanged.

    Args:
        merged: The types gathered from every subgraph.
        facts: The subgraphs, in id order.
    """
    var type_index = 0
    while type_index < len(merged):
        if not merged[type_index].is_query:
            type_index += 1
            continue
        var filled = List[_JoinType]()
        var graph_index = 0
        while graph_index < len(facts):
            var graph_id = String(facts[graph_index].graph_id)
            var interfaces = _query_interfaces(
                merged[type_index].joins, graph_id
            )
            filled.append(
                _JoinType(
                    graph_id^,
                    False,
                    List[String](),
                    List[Bool](),
                    interfaces^,
                    False,
                    List[String](),
                )
            )
            graph_index += 1
        merged[type_index].joins = filled^
        type_index += 1


def _type_has_key(merged: _Merged) -> Bool:
    """Return True when any subgraph declares a key on the type.

    Args:
        merged: The type.

    Returns:
        Whether the type is an entity.
    """
    var index = 0
    while index < len(merged.joins):
        if len(merged.joins[index].keys) > 0:
            return True
        index += 1
    return False


def _apply_override_descriptions(mut merged: List[_Merged]):
    """Replace an entity field description from a non-shareable override.

    The first description is kept while subgraphs are merged. Hive then
    walks an entity field that uses `@override`. Each subgraph where that
    field is overridden and not `@shareable` replaces the description. The
    last such subgraph wins. An empty description removes the text. A key
    field is `@shareable`, so its description stays. A type that is not an
    entity is unchanged.

    Args:
        merged: The types gathered from every subgraph.
    """
    var type_index = 0
    while type_index < len(merged):
        if not _is_object(merged[type_index]):
            type_index += 1
            continue
        if not _type_has_key(merged[type_index]):
            type_index += 1
            continue
        var field_index = 0
        while field_index < len(merged[type_index].fields):
            var replaced = False
            var text = String("")
            var count = len(merged[type_index].fields[field_index].sites)
            for site_index in range(count):
                var override_from = String(
                    merged[type_index]
                    .fields[field_index]
                    .sites[site_index]
                    .override_from
                )
                var shareable = (
                    merged[type_index]
                    .fields[field_index]
                    .sites[site_index]
                    .shareable
                )
                if override_from.byte_length() == 0 or shareable:
                    continue
                replaced = True
                text = String(
                    merged[type_index]
                    .fields[field_index]
                    .sites[site_index]
                    .site_description
                )
            if replaced:
                merged[type_index].fields[field_index].description = text^
            field_index += 1
        type_index += 1


def _is_object(merged: _Merged) -> Bool:
    """Return True for an object type.

    Args:
        merged: A merged type.

    Returns:
        Whether the type is not an enum, an interface, a union, an input
        object, or a scalar.
    """
    return not (
        merged.is_enum
        or merged.is_interface
        or merged.is_union
        or merged.is_input
        or merged.is_scalar
    )


def _copy_implementor_auth(mut merged: List[_Merged]):
    """Copy implementor authorization onto an interface.

    Hive merges `@authenticated`, `@policy`, and `@requiresScopes` from
    each object onto the interface it implements, and onto each field that
    object defines. The groups are merged.

    Args:
        merged: The types gathered from every subgraph.
    """
    var iface_index = 0
    while iface_index < len(merged):
        if not merged[iface_index].is_interface:
            iface_index += 1
            continue
        var iface_name = String(merged[iface_index].name)
        var object_index = 0
        while object_index < len(merged):
            # Only an object or an interface lists interfaces.
            if merged[object_index].is_interface or not _implements_name(
                merged[object_index], iface_name
            ):
                object_index += 1
                continue
            if merged[object_index].authenticated:
                merged[iface_index].authenticated = True
            merged[iface_index].policies = merge_scope_policies(
                merged[iface_index].policies, merged[object_index].policies
            )
            merged[iface_index].scopes = merge_scope_policies(
                merged[iface_index].scopes, merged[object_index].scopes
            )
            var field_index = 0
            while field_index < len(merged[iface_index].fields):
                var field_name = String(
                    merged[iface_index].fields[field_index].name
                )
                # Validation refuses an implementor that lacks an interface
                # field (`INTERFACE_FIELD_NO_IMPLEM`).
                var at = 0
                while merged[object_index].fields[at].name != field_name:
                    at += 1
                if merged[object_index].fields[at].authenticated:
                    merged[iface_index].fields[field_index].authenticated = True
                merged[iface_index].fields[
                    field_index
                ].policies = merge_scope_policies(
                    merged[iface_index].fields[field_index].policies,
                    merged[object_index].fields[at].policies,
                )
                merged[iface_index].fields[
                    field_index
                ].scopes = merge_scope_policies(
                    merged[iface_index].fields[field_index].scopes,
                    merged[object_index].fields[at].scopes,
                )
                field_index += 1
            object_index += 1
        iface_index += 1


def _add_interface_object_fields(
    mut merged: List[_Merged], index_of: Dict[String, Int]
):
    """Add interface-object fields an object does not define.

    A field the object already defines keeps `@authenticated`, `@policy`,
    and `@requiresScopes` from the interface object.

    Args:
        merged: The types gathered from every subgraph.
        index_of: Type name to index in `merged`.
    """
    var object_index = 0
    while object_index < len(merged):
        if not _is_object(merged[object_index]):
            object_index += 1
            continue
        var interfaces = _implemented(merged[object_index])
        for name_index in range(len(interfaces)):
            # Each implemented interface is a merged type.
            var iface = index_of.get(interfaces[name_index]).value()
            var from_object = False
            var join_index = 0
            while join_index < len(merged[iface].joins):
                if merged[iface].joins[join_index].interface_object:
                    from_object = True
                join_index += 1
            if not from_object:
                continue
            var field_index = 0
            while field_index < len(merged[iface].fields):
                var name = String(merged[iface].fields[field_index].name)
                var at = -1
                var have = 0
                while have < len(merged[object_index].fields):
                    if merged[object_index].fields[have].name == name:
                        at = have
                    have += 1
                if at != -1:
                    if merged[iface].fields[field_index].authenticated:
                        merged[object_index].fields[at].authenticated = True
                    merged[object_index].fields[
                        at
                    ].policies = merge_scope_policies(
                        merged[object_index].fields[at].policies,
                        merged[iface].fields[field_index].policies,
                    )
                    merged[object_index].fields[
                        at
                    ].scopes = merge_scope_policies(
                        merged[object_index].fields[at].scopes,
                        merged[iface].fields[field_index].scopes,
                    )
                    field_index += 1
                    continue
                var type_text = String(
                    merged[iface].fields[field_index].type_text
                )
                var arguments = _copied_arguments(
                    merged[iface].fields[field_index]
                )
                var inaccessible = (
                    merged[iface].fields[field_index].inaccessible
                )
                var tags = _copied_tags(merged[iface].fields[field_index].tags)
                var described = String(
                    merged[iface].fields[field_index].description
                )
                var deprecated = String(
                    merged[iface].fields[field_index].deprecation
                )
                var authenticated = (
                    merged[iface].fields[field_index].authenticated
                )
                var policies = _copied_groups(
                    merged[iface].fields[field_index].policies
                )
                var scopes = _copied_groups(
                    merged[iface].fields[field_index].scopes
                )
                merged[object_index].fields.append(
                    _FieldUse(
                        name^,
                        type_text^,
                        arguments^,
                        List[_FieldSite](),
                        inaccessible,
                        tags^,
                        True,
                        described^,
                        deprecated^,
                        authenticated,
                        policies^,
                        scopes^,
                        merged[iface].fields[field_index].has_cost,
                        merged[iface].fields[field_index].cost,
                        String(merged[iface].fields[field_index].list_size),
                        String(merged[iface].fields[field_index].applied),
                        merged[iface].fields[field_index].seen_output,
                        String(merged[iface].fields[field_index].default_value),
                        List[String](),
                        List[String](),
                        List[Int](),
                        List[String](),
                        List[String](),
                        0,
                        merged[iface].fields[field_index].has_list_size,
                        merged[iface].fields[field_index].list_assumed,
                        merged[iface].fields[field_index].list_require,
                        merged[iface].fields[field_index].list_print_require,
                        _copied_tags(
                            merged[iface].fields[field_index].list_slicing
                        ),
                        _copied_tags(
                            merged[iface].fields[field_index].list_sized
                        ),
                        String(
                            merged[iface].fields[field_index].list_directive
                        ),
                        merged[iface].fields[field_index].list_has_slicing,
                        merged[iface].fields[field_index].list_has_sized,
                    )
                )
                field_index += 1
        object_index += 1
