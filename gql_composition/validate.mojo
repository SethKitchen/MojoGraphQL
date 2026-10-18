# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Validate subgraphs: the subgraph phase of composition.

Port of `buildGraphList`, `validateSubgraph` and the subgraph phase of
`validate` of Hive Federation Composition v0.27.0 `src/validate.ts`, of
`moveSchemaAndDirectiveDefinitionsToTop` of `src/graphql/helpers.ts`, and of
`constantCase` of the `constant-case` package (MIT), which upstream calls.

`validate_subgraphs` returns the errors that upstream `composeServices`
returns when a subgraph is invalid: first the `@link` errors of all
subgraphs; when there are none, the errors of each subgraph in id order.
When those are also empty, it runs the federation `v2.14` and `v2.15`
checks, then `InterfaceFieldNoImplementationRule`, `ExtensionWithBaseRule`, `FieldsOfTheSameTypeRule`,
`InvalidFieldSharingRule`, `FieldArgumentsOfTheSameTypeRule` and
`OverrideSourceHasOverrideRule`. `InterfaceFieldNoImplementationRule` reports before the extension errors
of that object. `InterfaceKeyMissingImplementationTypeRule` reports on
the interface, after an all-inaccessible error and before its fields.
A required `@inaccessible` argument reports after that field's other
argument errors. A required `@inaccessible` input field reports after
that field's inaccessible-default error.
`ExtensionWithBaseRule` reports before
the fields of that object, and after the fields of earlier objects. An
`@override` chain error reports after that field's type error and
before its sharing error. A labeled `@override` of a `@requires` field reports after the chain
error. An `@external` field that has no base reports after that.
`ExternalTypeMismatchRule` reports next, still before the sharing
error. An argument error reports after the sharing
error. Enum errors come after object fields and before input fields.
An empty merged input reports before that input's field errors. A
required argument that some subgraphs omit reports after that field's
argument-type error.

**Differences from upstream.** The subgraphs are sorted by id with a
comparison that agrees with `localeCompare` for ids of `A`-`Z`, `0`-`9`
and `_`, which are all the ids that `constantCase` makes. From federation
`v2.15`, a custom specification cannot use the `https://specs.apollo.dev`
domain. From `v2.14`, a Federation 1 `@key` on an interface conflicts with
`@interfaceObject` on a type with the same name. From `v2.15`, an
interface cannot implement an `@interfaceObject` type. The public Apollo
GraphOS page "Federation versions" states those rules. Hive v0.27.0 does
not know these versions. The sentences are from this port. A subgraph
set below these versions gets the result of Hive v0.27.0.
"""

from std.collections import Dict
from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.federation_spec import (
    SpecCache,
    create_spec_schema,
    detect_federation_version,
    strip_at,
)
from gql_composition.link import ImportKind, Link, parse_link_directive
from gql_composition.later_versions import (
    GraphFacts,
    check_version_2_14_and_2_15,
)
from gql_composition.argument_default import check_argument_defaults
from gql_composition.inaccessible_default import check_inaccessible_defaults
from gql_composition.enum_values import check_enum_values
from gql_composition.extension_base import check_extension_with_no_base
from gql_composition.external_argument import check_external_arguments
from gql_composition.external_missing import check_external_missing
from gql_composition.external_type import check_external_type_mismatch
from gql_composition.interface_field import check_interface_fields
from gql_composition.interface_key import check_interface_key
from gql_composition.interface_object_usage import check_interface_object_usage
from gql_composition.subgraph_name import check_subgraph_names
from gql_composition.directive_composition import check_directive_composition
from gql_composition.auth_requires import (
    check_auth_context,
    check_auth_requires,
)
from gql_composition.required_inaccessible import check_required_inaccessible
from gql_composition.implemented_inaccessible import (
    check_implemented_inaccessible,
)
from gql_composition.interface_subtype import check_interface_subtype
from gql_composition.list_size_slicing import check_list_size_slicing
from gql_composition.contextual_argument import check_contextual_arguments
from gql_composition.input_default import check_input_defaults
from gql_composition.input_values import check_input_values
from gql_composition.only_inaccessible import check_only_inaccessible
from gql_composition.required_argument import check_required_arguments
from gql_composition.required_input import check_required_input_fields
from gql_composition.override_label import check_override_label
from gql_composition.override_source import check_override_source
from gql_composition.referenced_inaccessible import (
    check_referenced_inaccessible,
)
from gql_composition.field_arguments import check_field_arguments
from gql_composition.field_types import check_field_types
from gql_composition.field_sharing import check_field_sharing
from gql_composition.state import SubgraphState, TypeKind
from gql_composition.validate_subgraph import validate_subgraph
from gql_composition.version import FederationVersion


@fieldwise_init
struct Subgraph(Copyable):
    """A subgraph to validate, as upstream `ServiceDefinition`."""

    var name: String
    """The name of the subgraph."""
    var url: Optional[String]
    """The URL of the subgraph, if any."""
    var type_defs: Document
    """The parsed SDL of the subgraph."""


def _is_lower(byte: UInt8) -> Bool:
    """Return True for an ASCII lowercase letter."""
    return byte >= 97 and byte <= 122


def _is_upper(byte: UInt8) -> Bool:
    """Return True for an ASCII uppercase letter."""
    return byte >= 65 and byte <= 90


def _is_digit(byte: UInt8) -> Bool:
    """Return True for an ASCII digit."""
    return byte >= 48 and byte <= 57


def constant_case(name: String) -> String:
    """Return the id of a subgraph name, as upstream
    `constantCase(name.replace(/[^A-Z0-9]/gi, "_"), ...)`.

    Args:
        name: The name of the subgraph.

    Returns:
        The words of the name in uppercase, joined by `_`, such as
        `MY_SERVICE` for `myService`.
    """
    var replaced = List[UInt8]()
    var bytes = name.as_bytes()
    var at = 0
    while at < len(bytes):
        var byte = bytes[at]
        at += 1
        if _is_lower(byte) or _is_upper(byte) or _is_digit(byte):
            replaced.append(byte)
        elif byte >= 0xF0:
            replaced.append(95)
            replaced.append(95)
        elif byte < 0x80 or byte >= 0xC0:
            replaced.append(95)
    var split = List[UInt8]()
    var index = 0
    while index < len(replaced):
        var byte = replaced[index]
        split.append(byte)
        if (
            (_is_lower(byte) or _is_digit(byte))
            and index + 1 < len(replaced)
            and _is_upper(replaced[index + 1])
        ):
            split.append(0)
            split.append(replaced[index + 1])
            index += 1
        index += 1
    var words = List[UInt8]()
    index = 0
    while index < len(split):
        var byte = split[index]
        words.append(byte)
        if (
            _is_upper(byte)
            and index + 2 < len(split)
            and _is_upper(split[index + 1])
            and _is_lower(split[index + 2])
        ):
            words.append(0)
            words.append(split[index + 1])
            words.append(split[index + 2])
            index += 2
        index += 1
    # A word break (0) is always between two bytes, so the words need no
    # trim.
    var out = List[UInt8]()
    index = 0
    while index < len(words):
        var byte = words[index]
        index += 1
        if byte == 0:
            out.append(95)
        elif _is_lower(byte):
            out.append(byte - 32)
        else:
            out.append(byte)
    return String(unsafe_from_utf8=out)


def _weight(byte: UInt8) -> Int:
    """Return the collation weight of an id byte: `_`, then the digits,
    then the uppercase letters. An id holds no other bytes."""
    if byte == 95:
        return 1
    if _is_digit(byte):
        return 2 + Int(byte) - 48
    return 12 + Int(byte) - 65


def id_less(left: String, right: String) -> Bool:
    """Return True if one id sorts before another, as `localeCompare`
    orders ids.

    Args:
        left: An id.
        right: Another id.

    Returns:
        Whether `left` comes first.
    """
    var a = left.as_bytes()
    var b = right.as_bytes()
    var index = 0
    while index < len(a) and index < len(b):
        var wa = _weight(a[index])
        var wb = _weight(b[index])
        if wa != wb:
            return wa < wb
        index += 1
    return len(a) < len(b)


@fieldwise_init
struct _Graph(Copyable):
    """A subgraph with its id, as upstream `buildGraphList` makes it."""

    var name: String
    var id: String
    var source: Int
    """The index of the subgraph in the input list."""


def _graph_list(subgraphs: List[Subgraph]) raises -> List[_Graph]:
    """Give each subgraph an id and sort them by id, as upstream
    `buildGraphList`."""
    var graphs = List[_Graph]()
    var names = Dict[String, Bool]()
    var counts = Dict[String, Int]()
    var index = 0
    while index < len(subgraphs):
        var name = subgraphs[index].name
        if name in names:
            raise Error("A subgraph named " + name + " already exists")
        names[name] = True
        var id = constant_case(name)
        if name.byte_length() > 0 and _is_digit(name.as_bytes()[0]):
            id = "_" + id + "_"
        var count = counts.get(id)
        if count:
            var seen = count.value()
            if seen == 1:
                # The first subgraph with the id is in the list.
                var first = 0
                while graphs[first].id != id:
                    first += 1
                graphs[first].id += "_1"
            graphs.append(_Graph(name, id + "_" + String(seen + 1), index))
            counts[id] = seen + 1
        else:
            counts[id] = 1
            graphs.append(_Graph(name, id, index))
        index += 1
    for position in range(1, len(graphs)):
        var current = graphs[position].copy()
        var at = position
        while at > 0 and id_less(current.id, graphs[at - 1].id):
            graphs[at] = graphs[at - 1].copy()
            at -= 1
        graphs[at] = current^
    return graphs^


def _definition_weight(kind: Kind) -> Int:
    """Return the order weight of a definition, as upstream
    `kindOrderWeightMap`."""
    if kind == Kind.SCHEMA_DEFINITION:
        return 0
    if kind == Kind.SCHEMA_EXTENSION:
        return 1
    if kind == Kind.DIRECTIVE_DEFINITION:
        return 2
    return 3


def sorted_definitions(document: Document) -> List[Int]:
    """Return the definitions of a document with the schema definitions,
    the schema extensions and the directive definitions first, as upstream
    `moveSchemaAndDirectiveDefinitionsToTop`.

    Args:
        document: The subgraph's document.

    Returns:
        The definitions, in a stable order by kind weight.
    """
    var out = List[Int]()
    var weight = 0
    while weight < 4:
        var definition = document.first_child(document.root)
        while definition != NO_NODE:
            if _definition_weight(document.kind(definition)) == weight:
                out.append(definition)
            definition = document.next_sibling(definition)
        weight += 1
    return out^


def _has_version_form(version: String) -> Bool:
    """Return True for a version that matches upstream `/^v\\d+\\.\\d+/`.
    The link parser reads a version only when a digit follows `v` or
    `V`."""
    var bytes = version.as_bytes()
    if len(bytes) < 4 or bytes[0] != 118:
        return False
    var index = 1
    while index < len(bytes) and _is_digit(bytes[index]):
        index += 1
    return (
        index + 1 < len(bytes)
        and bytes[index] == 46
        and _is_digit(bytes[index + 1])
    )


def _known_feature_version(name: String, version: String) -> Int:
    """Return 1 when upstream `availableFeatures` lists the version of a
    feature, 0 when it lists the feature but not the version, and -1 when
    it does not list the feature."""
    var versions: List[String]
    if name == "link":
        versions = [String("v1.0")]
    elif name == "tag" or name == "kotlin_labs" or name == "inaccessible":
        versions = [String("v0.1"), String("v0.2")]
    elif name == "core":
        versions = [String("v0.1"), String("v0.2")]
    elif name == "join":
        versions = [
            String("v0.1"),
            String("v0.2"),
            String("v0.3"),
            String("v0.4"),
            String("v0.5"),
        ]
    else:
        return -1
    if version in versions:
        return 1
    return 0


struct _Core(Movable):
    """The links of a subgraph, or the errors of its `@link` directives."""

    var links: List[Link]
    var errors: List[CompositionError]

    def __init__(out self):
        self.links = List[Link]()
        self.errors = List[CompositionError]()


def _link_error(mut core: _Core, message: String, code: ErrorCode):
    """Add a `@link` error."""
    core.errors.append(CompositionError(message, code, None))


def _extract_links(
    mut cache: SpecCache, document: Document, definitions: List[Int]
) -> _Core:
    """Read and check the `@link` directives of the schema, as upstream
    `extractLinks`."""
    var core = _Core()
    var identities = Dict[String, Bool]()
    var reported = Dict[String, Bool]()
    var index = 0
    while index < len(definitions):
        var definition = definitions[index]
        index += 1
        var kind = document.kind(definition)
        if kind != Kind.SCHEMA_DEFINITION and kind != Kind.SCHEMA_EXTENSION:
            continue
        var directive = document.first_child(definition)
        while directive != NO_NODE:
            if (
                document.role(directive) == Role.DIRECTIVE
                and document.name(directive) == "link"
            ):
                try:
                    _check_link(
                        cache, core, identities, reported, document, directive
                    )
                except error:
                    _link_error(core, "Error: " + String(error), ErrorCode.NONE)
            directive = document.next_sibling(directive)
    _check_custom_domains(core)
    return core^


def _check_link(
    mut cache: SpecCache,
    mut core: _Core,
    mut identities: Dict[String, Bool],
    mut reported: Dict[String, Bool],
    document: Document,
    directive: Int,
) raises:
    """Check one `@link` directive, as the loop body of upstream
    `extractLinks`."""
    var parsed = parse_link_directive(document, directive)
    if not parsed:
        return
    var link = parsed.value().copy()
    if link.identity in identities and link.identity not in reported:
        _link_error(
            core,
            "Duplicate inclusion of feature " + link.identity,
            ErrorCode.INVALID_LINK_DIRECTIVE_USAGE,
        )
        reported[link.identity] = True
    identities[link.identity] = True
    if link.version and not _has_version_form(link.version.value()):
        _link_error(
            core,
            "Expected a version string (of the form v1.2), got "
            + link.version.value(),
            ErrorCode.INVALID_LINK_IDENTIFIER,
        )
        return
    if link.identity == "https://specs.apollo.dev" or link.identity.startswith(
        "https://specs.apollo.dev/"
    ):
        if not link.name and not link.version:
            _link_error(
                core,
                "Invalid @link url '"
                + link.identity
                + "': expected '/<feature>/vX.Y' (for example"
                " '/federation/v2.9')",
                ErrorCode.INVALID_LINK_IDENTIFIER,
            )
            return
        if not link.version:
            _link_error(
                core,
                "Expected a version string (of the form v1.2), got null",
                ErrorCode.INVALID_LINK_IDENTIFIER,
            )
            return
        var version = link.version.value()
        var name = link.name.value() if link.name else String("")
        if name == "federation":
            var index = FederationVersion.from_text(version)
            if index == -1:
                _link_error(
                    core,
                    "Invalid version "
                    + version
                    + " for the federation feature in @link directive on"
                    " schema",
                    ErrorCode.UNKNOWN_FEDERATION_LINK_VERSION,
                )
                return
            var spec = create_spec_schema(
                cache, FederationVersion(UInt8(index)), [], False
            )
            var unknown = False
            for ref item in link.imports:
                var bare = strip_at(item.name)
                if not spec.has_directive(bare) and not spec.has_type(bare):
                    unknown = True
                    _link_error(
                        core,
                        'Cannot import unknown element "' + item.name + '".',
                        ErrorCode.INVALID_LINK_DIRECTIVE_USAGE,
                    )
            if unknown:
                return
        elif name.byte_length() > 0:
            if _known_feature_version(name, version) == 0:
                _link_error(
                    core,
                    "Schema uses unknown version "
                    + version
                    + " of the "
                    + name
                    + " spec",
                    ErrorCode.UNKNOWN_LINK_VERSION,
                )
                return
    core.links.append(link^)


def _is_apollo_feature(name: String) -> Bool:
    """Return True for a feature name that Apollo publishes on
    `https://specs.apollo.dev`.

    Args:
        name: The feature name of a link, such as `cost`.

    Returns:
        Whether the name is a feature of `availableFeatures` or another
        Apollo specification.
    """
    var names: List[String] = [
        "link",
        "tag",
        "kotlin_labs",
        "inaccessible",
        "core",
        "join",
        "authenticated",
        "requiresScopes",
        "policy",
        "context",
        "cost",
        "connect",
        "source",
        "cacheTag",
    ]
    return name in names


def _check_custom_domains(mut core: _Core):
    """Report a custom specification on the Apollo domain.

    Federation `v2.15` refuses a custom specification on
    `https://specs.apollo.dev`. The public Apollo GraphOS page "Federation
    versions" states the rule. The check runs only when the federation
    link of the subgraph is `v2.15` or higher. Hive v0.27.0 does not
    have the check.

    Args:
        core: The links of one subgraph. Receives the errors.
    """
    var federation = 0
    for ref link in core.links:
        # `_check_link` keeps a federation link only with a known version.
        if link.is_federation():
            var index = FederationVersion.from_text(link.version.value())
            federation = FederationVersion(UInt8(index)).number()
    if federation < 215:
        return
    var index = 0
    while index < len(core.links):
        ref link = core.links[index]
        index += 1
        if not link.identity.startswith("https://specs.apollo.dev/"):
            continue
        # A URL with a path under that domain always gives a name.
        if link.is_federation():
            continue
        if _is_apollo_feature(link.name.value()):
            continue
        _link_error(
            core,
            'Custom specification "'
            + link.identity
            + '" cannot use the https://specs.apollo.dev domain.',
            ErrorCode.INVALID_LINK_DIRECTIVE_USAGE,
        )


def create_state(
    id: String,
    name: String,
    document: Document,
    definitions: List[Int],
    version: FederationVersion,
    links: List[Link],
) -> SubgraphState:
    """Start the state of a subgraph, as upstream
    `createSubgraphStateBuilder`.

    Args:
        id: The id of the subgraph.
        name: The name of the subgraph.
        document: The subgraph's document.
        definitions: Its definitions, before the subgraph specification
            types are dropped.
        version: The federation version.
        links: The links that `@link` checks found.

    Returns:
        The state, without types.
    """
    var state = SubgraphState(id, name, version)
    # A second federation link is a duplicate inclusion, and its errors
    # stop the validation before the state, so one link at most is the
    # federation link.
    for ref link in links:
        state.core_links.append(link.copy())
        if link.is_federation():
            state.federation_imports = link.imports.copy()
            continue
        for ref item in link.imports:
            if item.kind == ImportKind.DIRECTIVE:
                state.links.append(link.copy())
                break
    var schema_seen = False
    var index = 0
    while index < len(definitions):
        var definition = definitions[index]
        index += 1
        var kind = document.kind(definition)
        var type_name = String(document.name(definition))
        if kind == Kind.DIRECTIVE_DEFINITION and type_name == "link":
            var only_schema = True
            var child = document.first_child(definition)
            while child != NO_NODE:
                if document.role(
                    child
                ) == Role.LOCATION and not document.has_text(child, "SCHEMA"):
                    only_schema = False
                child = document.next_sibling(child)
            if only_schema:
                state.specs.link = True
        elif kind == Kind.SCHEMA_DEFINITION and not schema_seen:
            schema_seen = True
            var child = document.first_child(definition)
            while child != NO_NODE:
                if document.role(child) == Role.OPERATION_TYPE:
                    var operation = Int(document.operation(child).value)
                    var root = String(
                        document.name(document.child(child, Role.TYPE))
                    )
                    var found = False
                    var earlier = document.first_child(definition)
                    while earlier != child:
                        if (
                            document.role(earlier) == Role.OPERATION_TYPE
                            and Int(document.operation(earlier).value)
                            == operation
                        ):
                            found = True
                        earlier = document.next_sibling(earlier)
                    if not found:
                        state.expected_roots[operation] = root
                child = document.next_sibling(child)
        elif (
            kind == Kind.ENUM_TYPE_DEFINITION
            or kind == Kind.ENUM_TYPE_EXTENSION
        ):
            state.enum_names[type_name] = True
        elif (
            kind == Kind.SCALAR_TYPE_DEFINITION
            or kind == Kind.SCALAR_TYPE_EXTENSION
        ):
            state.scalar_names[type_name] = True
        elif (
            kind == Kind.INPUT_OBJECT_TYPE_DEFINITION
            or kind == Kind.INPUT_OBJECT_TYPE_EXTENSION
        ):
            state.input_object_names[type_name] = True
    return state^


def validate_subgraphs(
    subgraphs: List[Subgraph],
) raises -> List[CompositionError]:
    """Validate subgraphs, as upstream `validate` without its
    satisfiability check.

    Args:
        subgraphs: The subgraphs, in any order.

    Returns:
        The `@link` errors of all subgraphs when there are any; else the
        errors of each subgraph, in id order. When those are empty, the
        errors of the supergraph rules. Each subgraph message has the
        `[<subgraph>] ` prefix. An empty list means the subgraphs are
        valid.

    Raises:
        Error: `A subgraph named <name> already exists` for two subgraphs
            with one name, and the errors of `detect_federation_version`.
    """
    var facts = List[GraphFacts]()
    return validate_with_facts(subgraphs, facts)


def validate_subgraph_phase(
    subgraphs: List[Subgraph],
) raises -> List[CompositionError]:
    """Validate subgraphs, as the subgraph phase of upstream `validate`.

    Args:
        subgraphs: The subgraphs, in any order.

    Returns:
        The `@link` errors of all subgraphs when there are any; else the
        errors of each subgraph, in id order. The supergraph rules do not
        run.

    Raises:
        Error: `A subgraph named <name> already exists` for two subgraphs
            with one name, and the errors of `detect_federation_version`.
    """
    var facts = List[GraphFacts]()
    return _subgraph_phase(subgraphs, facts)


def validate_with_facts(
    subgraphs: List[Subgraph], mut facts: List[GraphFacts]
) raises -> List[CompositionError]:
    """Validate subgraphs and keep the facts the supergraph printer reads.

    Args:
        subgraphs: The subgraphs, in any order.
        facts: Receives one entry per subgraph, in id order, when
            validation reaches the subgraph walk.

    Returns:
        The same errors as `validate_subgraphs`.

    Raises:
        Error: `A subgraph named <name> already exists` for two subgraphs
            with one name, and the errors of `detect_federation_version`.
    """
    var errors = _subgraph_phase(subgraphs, facts)
    if len(errors) == 0:
        errors = _supergraph_rules(facts)
    return errors^


def _subgraph_phase(
    subgraphs: List[Subgraph], mut facts: List[GraphFacts]
) raises -> List[CompositionError]:
    """Run the subgraph phase and keep the facts of each subgraph.

    Args:
        subgraphs: The subgraphs, in any order.
        facts: Receives one entry per subgraph, in id order.

    Returns:
        The errors of `validate_subgraph_phase`.

    Raises:
        Error: The errors of `validate_subgraph_phase`.
    """
    var graphs = _graph_list(subgraphs)
    var cache = SpecCache()
    var documents = List[Document]()
    var orders = List[List[Int]]()
    var links = List[List[Link]]()
    var core_errors = List[CompositionError]()
    for ref graph in graphs:
        var document = subgraphs[graph.source].type_defs.copy()
        var definitions = sorted_definitions(document)
        var core = _extract_links(cache, document, definitions)
        for ref error in core.errors:
            core_errors.append(
                CompositionError(
                    "[" + graph.name + "] " + error.message,
                    error.code,
                    graph.name,
                )
            )
        documents.append(document^)
        orders.append(definitions^)
        links.append(core.links.copy())
    if len(core_errors) > 0:
        return core_errors^
    var errors = List[CompositionError]()
    for index in range(len(graphs)):
        ref graph = graphs[index]
        var federation = detect_federation_version(
            documents[index], orders[index]
        )
        var state = create_state(
            graph.id,
            graph.name,
            documents[index],
            orders[index],
            federation.version,
            links[index],
        )
        errors.extend(
            validate_subgraph(
                cache,
                documents[index].copy(),
                orders[index],
                graph.name,
                graph.id,
                federation,
                state^,
                facts,
            )
        )
    return errors^


def _supergraph_rules(
    facts: List[GraphFacts],
) raises -> List[CompositionError]:
    """Run the supergraph rules after a clean subgraph phase.

    Args:
        facts: The subgraphs, in id order.

    Returns:
        The errors, in the order of upstream `validate`.

    Raises:
        GraphQLError: An auth rule reads a selection that does not parse.
            The subgraph phase rejects such a selection first.
    """
    var errors = List[CompositionError]()
    errors.extend(check_version_2_14_and_2_15(facts))
    var extension_where = List[String]()
    var type_where = List[String]()
    var share_where = List[String]()
    var argument_found = List[String]()
    var enum_found = List[String]()
    var override_found = List[String]()
    var label_found = List[String]()
    var external_found = List[String]()
    var external_type_found = List[String]()
    var input_found = List[String]()
    var required_found = List[String]()
    var input_required_found = List[String]()
    var external_arg_found = List[String]()
    var input_default_found = List[String]()
    var argument_default_found = List[String]()
    var hidden_default_found = List[String]()
    var only_found = List[String]()
    var referenced_found = List[String]()
    var referenced_arg_found = List[String]()
    var interface_found = List[String]()
    var interface_errors = check_interface_fields(facts, interface_found)
    var key_found = List[String]()
    var key_errors = check_interface_key(facts, key_found)
    var object_usage_found = List[String]()
    var object_usage_errors = check_interface_object_usage(
        facts, object_usage_found
    )
    var required_hidden_found = List[String]()
    var required_hidden_errors = List[CompositionError]()
    var required_hidden_arg_found = List[String]()
    var required_hidden_arg_errors = List[CompositionError]()
    check_required_inaccessible(
        facts,
        required_hidden_errors,
        required_hidden_found,
        required_hidden_arg_errors,
        required_hidden_arg_found,
    )
    var implemented_found = List[String]()
    var implemented_errors = check_implemented_inaccessible(
        facts, implemented_found
    )
    var subtype_found = List[String]()
    var subtype_errors = check_interface_subtype(facts, subtype_found)
    var slicing_found = List[String]()
    var slicing_errors = check_list_size_slicing(facts, slicing_found)
    var contextual_found = List[String]()
    var contextual_errors = check_contextual_arguments(facts, contextual_found)
    var extension_errors = check_extension_with_no_base(facts, extension_where)
    var type_errors = check_field_types(facts, type_where)
    var share_errors = check_field_sharing(facts, share_where)
    var argument_errors = check_field_arguments(facts, argument_found)
    var enum_errors = check_enum_values(facts, enum_found)
    var override_errors = check_override_source(facts, override_found)
    var label_errors = check_override_label(facts, label_found)
    var external_errors = check_external_missing(facts, external_found)
    var external_type_errors = check_external_type_mismatch(
        facts, external_type_found
    )
    var input_errors = check_input_values(facts, input_found)
    var required_errors = check_required_arguments(facts, required_found)
    var input_required_errors = check_required_input_fields(
        facts, input_required_found
    )
    var external_arg_errors = check_external_arguments(
        facts, external_arg_found
    )
    var input_default_errors = check_input_defaults(facts, input_default_found)
    var argument_default_errors = check_argument_defaults(
        facts, argument_default_found
    )
    var hidden_default_errors = check_inaccessible_defaults(
        facts, hidden_default_found
    )
    var only_errors = check_only_inaccessible(facts, only_found)
    var referenced_errors = List[CompositionError]()
    var referenced_arg_errors = List[CompositionError]()
    check_referenced_inaccessible(
        facts,
        referenced_errors,
        referenced_found,
        referenced_arg_errors,
        referenced_arg_found,
    )
    var directive_links = List[CompositionError]()
    var directive_locations = List[CompositionError]()
    check_directive_composition(facts, directive_links, directive_locations)
    errors.extend(directive_links^)
    errors.extend(check_subgraph_names(facts))
    errors.extend(
        _interleave_fields(
            facts,
            type_errors,
            type_where,
            share_errors,
            share_where,
            extension_errors,
            extension_where,
            argument_errors,
            argument_found,
            enum_errors,
            enum_found,
            override_errors,
            override_found,
            label_errors,
            label_found,
            external_errors,
            external_found,
            external_type_errors,
            external_type_found,
            input_errors,
            input_found,
            required_errors,
            required_found,
            input_required_errors,
            input_required_found,
            external_arg_errors,
            external_arg_found,
            input_default_errors,
            input_default_found,
            argument_default_errors,
            argument_default_found,
            hidden_default_errors,
            hidden_default_found,
            only_errors,
            only_found,
            referenced_errors,
            referenced_found,
            referenced_arg_errors,
            referenced_arg_found,
            interface_errors,
            interface_found,
            key_errors,
            key_found,
            object_usage_errors,
            object_usage_found,
            required_hidden_errors,
            required_hidden_found,
            required_hidden_arg_errors,
            required_hidden_arg_found,
            implemented_errors,
            implemented_found,
            subtype_errors,
            subtype_found,
            slicing_errors,
            slicing_found,
            contextual_errors,
            contextual_found,
        )
    )
    errors.extend(directive_locations^)
    if len(errors) == 0:
        errors.extend(check_auth_requires(facts))
        errors.extend(check_auth_context(facts))
    return errors^


def _append_new(mut names: List[String], name: String):
    """Append a name that is not already present."""
    for index in range(len(names)):
        if names[index] == name:
            return
    names.append(String(name))


def _type_names(facts: List[GraphFacts], kind: TypeKind) -> List[String]:
    """Return type names of one kind, in first-seen order.

    Args:
        facts: The subgraphs, in id order.
        kind: The kind to collect.

    Returns:
        The names, once each.
    """
    var names = List[String]()
    for graph_index in range(len(facts)):
        ref graph = facts[graph_index]
        # Each subgraph that reaches the supergraph rules has types.
        var type_index = 0
        while type_index < len(graph.types):
            ref type = graph.types[type_index]
            type_index += 1
            if type.kind == kind:
                _append_new(names, type.name)
    return names^


def _field_names(
    facts: List[GraphFacts], name: String, kind: TypeKind
) -> List[String]:
    """Return the fields of one type, in first-seen order.

    Args:
        facts: The subgraphs, in id order.
        name: The type name.
        kind: The kind of that type.

    Returns:
        The field names, once each.
    """
    var fields = List[String]()
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var type_index = 0
        while type_index < len(graph.types):
            ref type = graph.types[type_index]
            type_index += 1
            if type.kind != kind or type.name != name:
                continue
            for field_index in range(len(type.fields)):
                _append_new(fields, type.fields[field_index].name)
    return fields^


def _flags(count: Int) -> List[Bool]:
    """Return `count` false flags.

    Args:
        count: How many flags.

    Returns:
        A list of false values.
    """
    var used = List[Bool]()
    var index = 0
    while index < count:
        used.append(False)
        index += 1
    return used^


def _interleave_fields(
    facts: List[GraphFacts],
    type_errors: List[CompositionError],
    type_where: List[String],
    share_errors: List[CompositionError],
    share_where: List[String],
    extension_errors: List[CompositionError],
    extension_where: List[String],
    argument_errors: List[CompositionError],
    argument_found: List[String],
    enum_errors: List[CompositionError],
    enum_found: List[String],
    override_errors: List[CompositionError],
    override_found: List[String],
    label_errors: List[CompositionError],
    label_found: List[String],
    external_errors: List[CompositionError],
    external_found: List[String],
    external_type_errors: List[CompositionError],
    external_type_found: List[String],
    input_errors: List[CompositionError],
    input_found: List[String],
    required_errors: List[CompositionError],
    required_found: List[String],
    input_required_errors: List[CompositionError],
    input_required_found: List[String],
    external_arg_errors: List[CompositionError],
    external_arg_found: List[String],
    input_default_errors: List[CompositionError],
    input_default_found: List[String],
    argument_default_errors: List[CompositionError],
    argument_default_found: List[String],
    hidden_default_errors: List[CompositionError],
    hidden_default_found: List[String],
    only_errors: List[CompositionError],
    only_found: List[String],
    referenced_errors: List[CompositionError],
    referenced_found: List[String],
    referenced_arg_errors: List[CompositionError],
    referenced_arg_found: List[String],
    interface_errors: List[CompositionError],
    interface_found: List[String],
    key_errors: List[CompositionError],
    key_found: List[String],
    object_usage_errors: List[CompositionError],
    object_usage_found: List[String],
    required_hidden_errors: List[CompositionError],
    required_hidden_found: List[String],
    required_hidden_arg_errors: List[CompositionError],
    required_hidden_arg_found: List[String],
    implemented_errors: List[CompositionError],
    implemented_found: List[String],
    subtype_errors: List[CompositionError],
    subtype_found: List[String],
    slicing_errors: List[CompositionError],
    slicing_found: List[String],
    contextual_errors: List[CompositionError],
    contextual_found: List[String],
) -> List[CompositionError]:
    """Put extension errors before that object's field errors.

    Args:
        facts: The subgraphs, in id order.
        type_errors: The field type errors.
        type_where: `Type.field` for each type error.
        share_errors: The field sharing errors.
        share_where: `Type.field` for each sharing error.
        extension_errors: The extension errors.
        extension_where: The type name for each extension error.
        argument_errors: The argument type errors.
        argument_found: `Type.field` or `@directive` for each argument
            error.
        enum_errors: The enum value errors.
        enum_found: The enum name for each enum error.
        override_errors: The `@override` chain errors.
        override_found: `Type.field` for each `@override` chain error.
        label_errors: The labeled `@override` errors.
        label_found: `Type.field` for each labeled `@override` error.
        external_errors: The `@external` base errors.
        external_found: The type name or `Type.field` for each
            `@external` error.
        external_type_errors: The `@external` type mismatch errors.
        external_type_found: `Type.field` for each `@external` type error.
        input_errors: The empty merged input errors.
        input_found: The input type name for each empty-input error.
        required_errors: The missing required-argument errors.
        required_found: `Type.field` for each missing required argument.
        input_required_errors: The missing required input-field errors.
        input_required_found: `Type.field` for each missing required
            input field.
        external_arg_errors: The missing `@external` argument errors.
        external_arg_found: `Type.field` for each missing `@external`
            argument.
        input_default_errors: The input default mismatch errors.
        input_default_found: `Type.field` for each input default error.
        argument_default_errors: The field-argument default errors.
        argument_default_found: `Type.field` for each argument default
            error.
        hidden_default_errors: The inaccessible-default errors.
        hidden_default_found: `Type.field` for each inaccessible default.
        only_errors: The all-inaccessible-children errors.
        only_found: The type name for each all-inaccessible error.
        referenced_errors: Field references to `@inaccessible` types.
        referenced_found: `Type.field` for each field reference error.
        referenced_arg_errors: Argument references to `@inaccessible` types.
        referenced_arg_found: `Type.field` for each argument reference
            error.
        interface_errors: The missing interface-field errors.
        interface_found: The object type name for each missing
            interface field.
        key_errors: The interface `@key` implementation errors.
        key_found: The interface name for each `@key` implementation
            error.
        object_usage_errors: The all-`@interfaceObject` errors.
        object_usage_found: The interface name for each
            `@interfaceObject` error.
        required_hidden_errors: The required `@inaccessible` input-field
            errors.
        required_hidden_found: `Type.field` for each required hidden
            input field.
        required_hidden_arg_errors: The required `@inaccessible` argument
            errors.
        required_hidden_arg_found: `Type.field` for each required hidden
            argument.
        implemented_errors: The `@inaccessible` interface-implementation
            errors.
        implemented_found: `Type.field` for each interface-implementation
            error.
        subtype_errors: The interface subtype errors.
        subtype_found: `Type.field` for each interface subtype error.
        slicing_errors: The disregarded `@listSize` slicing-argument errors.
        slicing_found: `Type.field` for each slicing-argument error.
        contextual_errors: The contextual-argument errors.
        contextual_found: `Type.field` for each contextual argument.

    Returns:
        The errors in Hive's visitor order.
    """
    var objects = _type_names(facts, TypeKind.OBJECT)
    var inputs = _type_names(facts, TypeKind.INPUT_OBJECT)
    var interfaces = _type_names(facts, TypeKind.INTERFACE)
    var enums = _type_names(facts, TypeKind.ENUM)
    var out = List[CompositionError]()
    var extension_used = _flags(len(extension_errors))
    var type_used = _flags(len(type_errors))
    var share_used = _flags(len(share_errors))
    var argument_used = _flags(len(argument_errors))
    var enum_used = _flags(len(enum_errors))
    var override_used = _flags(len(override_errors))
    var label_used = _flags(len(label_errors))
    var external_used = _flags(len(external_errors))
    var external_type_used = _flags(len(external_type_errors))
    var input_used = _flags(len(input_errors))
    var required_used = _flags(len(required_errors))
    var input_required_used = _flags(len(input_required_errors))
    var external_arg_used = _flags(len(external_arg_errors))
    var input_default_used = _flags(len(input_default_errors))
    var argument_default_used = _flags(len(argument_default_errors))
    var hidden_default_used = _flags(len(hidden_default_errors))
    var only_used = _flags(len(only_errors))
    var referenced_used = _flags(len(referenced_errors))
    var referenced_arg_used = _flags(len(referenced_arg_errors))
    var interface_used = _flags(len(interface_errors))
    var key_used = _flags(len(key_errors))
    var object_usage_used = _flags(len(object_usage_errors))
    var required_hidden_used = _flags(len(required_hidden_errors))
    var required_hidden_arg_used = _flags(len(required_hidden_arg_errors))
    var implemented_used = _flags(len(implemented_errors))
    var subtype_used = _flags(len(subtype_errors))
    var slicing_used = _flags(len(slicing_errors))
    var contextual_used = _flags(len(contextual_errors))
    for name_index in range(len(objects)):
        var name = String(objects[name_index])
        _take(out, interface_errors, interface_found, interface_used, name)
        _take(out, extension_errors, extension_where, extension_used, name)
        _take(out, external_errors, external_found, external_used, name)
        _take(out, only_errors, only_found, only_used, name)
        var fields = _field_names(facts, name, TypeKind.OBJECT)
        for field_index in range(len(fields)):
            var coordinate = name + "." + fields[field_index]
            _take(out, type_errors, type_where, type_used, coordinate)
            _take(
                out,
                override_errors,
                override_found,
                override_used,
                coordinate,
            )
            _take(out, label_errors, label_found, label_used, coordinate)
            _take(
                out, external_errors, external_found, external_used, coordinate
            )
            _take(
                out,
                external_type_errors,
                external_type_found,
                external_type_used,
                coordinate,
            )
            _take(out, share_errors, share_where, share_used, coordinate)
            _take(out, subtype_errors, subtype_found, subtype_used, coordinate)
            _take(
                out,
                implemented_errors,
                implemented_found,
                implemented_used,
                coordinate,
            )
            _take(out, slicing_errors, slicing_found, slicing_used, coordinate)
            _take(
                out,
                referenced_errors,
                referenced_found,
                referenced_used,
                coordinate,
            )
            _take(
                out, argument_errors, argument_found, argument_used, coordinate
            )
            _take(
                out,
                required_errors,
                required_found,
                required_used,
                coordinate,
            )
            _take(
                out,
                external_arg_errors,
                external_arg_found,
                external_arg_used,
                coordinate,
            )
            _take(
                out,
                argument_default_errors,
                argument_default_found,
                argument_default_used,
                coordinate,
            )
            _take(
                out,
                hidden_default_errors,
                hidden_default_found,
                hidden_default_used,
                coordinate,
            )
            _take(
                out,
                referenced_arg_errors,
                referenced_arg_found,
                referenced_arg_used,
                coordinate,
            )
            _take(
                out,
                required_hidden_arg_errors,
                required_hidden_arg_found,
                required_hidden_arg_used,
                coordinate,
            )
            _take(
                out,
                contextual_errors,
                contextual_found,
                contextual_used,
                coordinate,
            )
    for name_index in range(len(enums)):
        _take(out, enum_errors, enum_found, enum_used, enums[name_index])
        _take(out, only_errors, only_found, only_used, enums[name_index])
    for name_index in range(len(inputs)):
        var input_name = String(inputs[name_index])
        _take(out, input_errors, input_found, input_used, input_name)
        _take(out, only_errors, only_found, only_used, input_name)
        var input_fields = _field_names(
            facts, input_name, TypeKind.INPUT_OBJECT
        )
        # A valid input object type has fields.
        var field_index = 0
        while field_index < len(input_fields):
            var coordinate = input_name + "." + input_fields[field_index]
            field_index += 1
            _take(out, type_errors, type_where, type_used, coordinate)
            _take(
                out,
                input_required_errors,
                input_required_found,
                input_required_used,
                coordinate,
            )
            _take(
                out,
                input_default_errors,
                input_default_found,
                input_default_used,
                coordinate,
            )
            _take(
                out,
                hidden_default_errors,
                hidden_default_found,
                hidden_default_used,
                coordinate,
            )
            _take(
                out,
                required_hidden_errors,
                required_hidden_found,
                required_hidden_used,
                coordinate,
            )
            _take(out, share_errors, share_where, share_used, coordinate)
    for name_index in range(len(interfaces)):
        var interface_name = String(interfaces[name_index])
        _take(out, only_errors, only_found, only_used, interface_name)
        _take(
            out,
            object_usage_errors,
            object_usage_found,
            object_usage_used,
            interface_name,
        )
        _take(out, key_errors, key_found, key_used, interface_name)
        var interface_fields = _field_names(
            facts, interface_name, TypeKind.INTERFACE
        )
        # A valid interface type has fields.
        var field_index = 0
        while field_index < len(interface_fields):
            var coordinate = (
                interface_name + "." + interface_fields[field_index]
            )
            field_index += 1
            _take(out, type_errors, type_where, type_used, coordinate)
            _take(out, share_errors, share_where, share_used, coordinate)
            _take(out, slicing_errors, slicing_found, slicing_used, coordinate)
    _take_rest(out, extension_errors, extension_used)
    _take_rest(out, type_errors, type_used)
    _take_rest(out, share_errors, share_used)
    _take_rest(out, argument_errors, argument_used)
    _take_rest(out, enum_errors, enum_used)
    _take_rest(out, override_errors, override_used)
    _take_rest(out, label_errors, label_used)
    _take_rest(out, external_errors, external_used)
    _take_rest(out, external_type_errors, external_type_used)
    _take_rest(out, input_errors, input_used)
    _take_rest(out, required_errors, required_used)
    _take_rest(out, input_required_errors, input_required_used)
    _take_rest(out, external_arg_errors, external_arg_used)
    _take_rest(out, input_default_errors, input_default_used)
    _take_rest(out, argument_default_errors, argument_default_used)
    _take_rest(out, hidden_default_errors, hidden_default_used)
    _take_rest(out, only_errors, only_used)
    _take_rest(out, referenced_errors, referenced_used)
    _take_rest(out, referenced_arg_errors, referenced_arg_used)
    _take_rest(out, interface_errors, interface_used)
    _take_rest(out, key_errors, key_used)
    _take_rest(out, object_usage_errors, object_usage_used)
    _take_rest(out, required_hidden_errors, required_hidden_used)
    _take_rest(out, required_hidden_arg_errors, required_hidden_arg_used)
    _take_rest(out, contextual_errors, contextual_used)
    _take_rest(out, implemented_errors, implemented_used)
    _take_rest(out, subtype_errors, subtype_used)
    _take_rest(out, slicing_errors, slicing_used)
    return out^


def _take(
    mut out: List[CompositionError],
    errors: List[CompositionError],
    found: List[String],
    mut used: List[Bool],
    coordinate: String,
):
    """Append unused errors for one field.

    Args:
        out: The combined errors.
        errors: One rule's errors.
        found: `Type.field` for each error.
        used: Whether each error was already copied.
        coordinate: The field to copy.
    """
    for index in range(len(errors)):
        if used[index] or found[index] != coordinate:
            continue
        used[index] = True
        out.append(errors[index].copy())


def _take_rest(
    mut out: List[CompositionError],
    errors: List[CompositionError],
    mut used: List[Bool],
):
    """Append errors that did not match a field.

    Args:
        out: The combined errors.
        errors: One rule's errors.
        used: Whether each error was already copied.
    """
    for index in range(len(errors)):
        if used[index]:
            continue
        used[index] = True
        out.append(errors[index].copy())
