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

**Differences from upstream.** The subgraphs are sorted by id with a
comparison that agrees with `localeCompare` for ids of `A`-`Z`, `0`-`9`
and `_`, which are all the ids that `constantCase` makes.
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
from gql_composition.state import SubgraphState
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
    for byte in name.as_bytes():
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
    var start = 0
    var end = len(words)
    while start < end and words[start] == 0:
        start += 1
    while end > start and words[end - 1] == 0:
        end -= 1
    var out = List[UInt8]()
    for position in range(start, end):
        var byte = words[position]
        if byte == 0:
            out.append(95)
        elif _is_lower(byte):
            out.append(byte - 32)
        else:
            out.append(byte)
    return String(unsafe_from_utf8=out)


def _weight(byte: UInt8) -> Int:
    """Return the collation weight of an id byte: `_`, then the digits,
    then the letters."""
    if byte == 95:
        return 1
    if _is_digit(byte):
        return 2 + Int(byte) - 48
    if _is_upper(byte):
        return 12 + Int(byte) - 65
    return 100 + Int(byte)


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
    for index in range(len(subgraphs)):
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
                for ref graph in graphs:
                    if graph.id == id:
                        graph.id += "_1"
                        break
            graphs.append(_Graph(name, id + "_" + String(seen + 1), index))
            counts[id] = seen + 1
        else:
            counts[id] = 1
            graphs.append(_Graph(name, id, index))
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
    """Return True for a version that matches upstream `/^v\\d+\\.\\d+/`."""
    var bytes = version.as_bytes()
    if len(bytes) < 4 or bytes[0] != 118 or not _is_digit(bytes[1]):
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
    for ref item in versions:
        if item == version:
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
    for definition in definitions:
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
    var federation_found = False
    for ref link in links:
        if link.is_federation():
            if not federation_found:
                state.federation_imports = link.imports.copy()
                federation_found = True
            continue
        for ref item in link.imports:
            if item.kind == ImportKind.DIRECTIVE:
                state.links.append(link.copy())
                break
    var schema_seen = False
    for definition in definitions:
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
    """Validate subgraphs, as the subgraph phase of upstream `validate`.

    Args:
        subgraphs: The subgraphs, in any order.

    Returns:
        The `@link` errors of all subgraphs when there are any; else the
        errors of each subgraph, in id order. Each message has the
        `[<subgraph>] ` prefix. An empty list means the subgraphs are
        valid.

    Raises:
        Error: `A subgraph named <name> already exists` for two subgraphs
            with one name, and the errors of `detect_federation_version`.
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
            )
        )
    return errors^
