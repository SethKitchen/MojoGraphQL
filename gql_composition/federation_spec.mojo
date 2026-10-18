# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The directives and types of each federation version.

Port of Hive Federation Composition v0.27.0 `src/specifications/federation.ts`
(`createSpecSchema`, `createTypeDefinitions`, `detectFederationVersion`),
`src/specifications/tag.ts`, `src/specifications/inaccessible.ts` and the
`sdl` of `src/specifications/link.ts`.

`create_spec_schema` gives the definitions that a subgraph of a version can
use, as upstream: the imported ones without a prefix, and all of them with
the `federation__` prefix. Version `v1.0` has no prefix and adds `@tag` and
`@inaccessible`.

**Differences from upstream.** Upstream parses the SDL of a version on each
call and renames the nodes for the prefix. This port parses the SDL once
per `SpecCache` and keeps each prefixed name beside the node.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.parser import parse
from gql_composition.link import (
    Link,
    LinkImport,
    parse_link_import,
    parse_link_url,
)
from gql_composition.printer import print_node
from gql_composition.version import VERSION_COUNT, FederationVersion

comptime FEDERATION_PREFIX = "federation__"
"""The prefix of the namespaced federation definitions."""

comptime TAG_SDL = """directive @tag(
name: String!
) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA
"""
"""The `@tag` definition that a `v1.0` subgraph can use."""

comptime INACCESSIBLE_SDL = """directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION
"""
"""The `@inaccessible` definition that a `v1.0` subgraph can use."""

comptime LINK_SPEC_SDL = """enum Purpose {
EXECUTION
SECURITY
}
directive @link(
url: String
as: String
for: link__Purpose
import: [link__Import]
) repeatable on SCHEMA
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
}
"""
"""The link specification definitions that `validateSubgraph` adds to a
federation 2 subgraph without its own `@link` definition."""

comptime _BASE_SDL: Array[Int, VERSION_COUNT] = [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    10,
    10,
    10,
    10,
    10,
    10,
]
"""The entry of `_SPEC_SDL` that each version starts from: `v2.10` to
`v2.15` start from `v2.9`."""

comptime _ADDED_COUNT = 1
"""How many definitions later versions add to `v2.9`."""

comptime _ADDED_SINCE: Array[Int, _ADDED_COUNT] = [212]
"""The first version of each added definition, as
`FederationVersion.number` gives it."""

comptime _ADDED_SDL: Array[StaticString, _ADDED_COUNT] = [
    (
        "directive @cacheTag(format: String!) repeatable on FIELD_DEFINITION |"
        " OBJECT\n"
    ),
]
"""The added definitions. `@cacheTag` is from the Apollo GraphOS page
"Federation versions" for `v2.12`."""

comptime _SPEC_SDL: Array[StaticString, 11] = [
    # v1.0
    """directive @key(
fields: _FieldSet!
resolvable: Boolean = true
) repeatable on OBJECT | INTERFACE
directive @requires(fields: _FieldSet!) on FIELD_DEFINITION
directive @provides(fields: _FieldSet!) on FIELD_DEFINITION
directive @external on OBJECT | FIELD_DEFINITION
directive @extends on OBJECT | INTERFACE
directive @override(from: String!) on FIELD_DEFINITION
scalar _FieldSet
""",
    # v2.0
    """directive @key(
fields: FieldSet!
resolvable: Boolean = true
) repeatable on OBJECT | INTERFACE
directive @requires(fields: FieldSet!) on FIELD_DEFINITION
directive @provides(fields: FieldSet!) on FIELD_DEFINITION
directive @external on OBJECT | FIELD_DEFINITION
directive @shareable on FIELD_DEFINITION | OBJECT
directive @extends on OBJECT | INTERFACE
directive @override(from: String!) on FIELD_DEFINITION
directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION
directive @tag(
name: String!
) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION
scalar FieldSet
""",
    # v2.1
    """directive @composeDirective(name: String!) repeatable on SCHEMA
directive @extends on OBJECT | INTERFACE
directive @external on OBJECT | FIELD_DEFINITION
directive @key(
fields: FieldSet!
resolvable: Boolean = true
) repeatable on OBJECT | INTERFACE
directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION
directive @override(from: String!) on FIELD_DEFINITION
directive @provides(fields: FieldSet!) on FIELD_DEFINITION
directive @requires(fields: FieldSet!) on FIELD_DEFINITION
directive @shareable on FIELD_DEFINITION | OBJECT
directive @tag(
name: String!
) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION
scalar FieldSet
""",
    # v2.2
    """directive @composeDirective(name: String!) repeatable on SCHEMA
directive @extends on OBJECT | INTERFACE
directive @external on OBJECT | FIELD_DEFINITION
directive @key(
fields: FieldSet!
resolvable: Boolean = true
) repeatable on OBJECT | INTERFACE
directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION
directive @override(from: String!) on FIELD_DEFINITION
directive @provides(fields: FieldSet!) on FIELD_DEFINITION
directive @requires(fields: FieldSet!) on FIELD_DEFINITION
directive @shareable repeatable on FIELD_DEFINITION | OBJECT
directive @tag(
name: String!
) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION
scalar FieldSet
""",
    # v2.3
    """directive @composeDirective(name: String!) repeatable on SCHEMA
directive @extends on OBJECT | INTERFACE
directive @external on OBJECT | FIELD_DEFINITION
directive @key(
fields: FieldSet!
resolvable: Boolean = true
) repeatable on OBJECT | INTERFACE
directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION
directive @interfaceObject on OBJECT
directive @override(from: String!) on FIELD_DEFINITION
directive @provides(fields: FieldSet!) on FIELD_DEFINITION
directive @requires(fields: FieldSet!) on FIELD_DEFINITION
directive @shareable repeatable on FIELD_DEFINITION | OBJECT
directive @tag(
name: String!
) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION
scalar FieldSet
""",
    # v2.4
    """directive @composeDirective(name: String!) repeatable on SCHEMA
directive @extends on OBJECT | INTERFACE
directive @external on OBJECT | FIELD_DEFINITION
directive @key(
fields: FieldSet!
resolvable: Boolean = true
) repeatable on OBJECT | INTERFACE
directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION
directive @interfaceObject on OBJECT
directive @override(from: String!) on FIELD_DEFINITION
directive @provides(fields: FieldSet!) on FIELD_DEFINITION
directive @requires(fields: FieldSet!) on FIELD_DEFINITION
directive @shareable repeatable on FIELD_DEFINITION | OBJECT
directive @tag(
name: String!
) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION
scalar FieldSet
""",
    # v2.5
    """directive @authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @requiresScopes(
scopes: [[Scope!]!]!
) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @composeDirective(name: String!) repeatable on SCHEMA
directive @extends on OBJECT | INTERFACE
directive @external on OBJECT | FIELD_DEFINITION
directive @key(
fields: FieldSet!
resolvable: Boolean = true
) repeatable on OBJECT | INTERFACE
directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION
directive @interfaceObject on OBJECT
directive @override(from: String!) on FIELD_DEFINITION
directive @provides(fields: FieldSet!) on FIELD_DEFINITION
directive @requires(fields: FieldSet!) on FIELD_DEFINITION
directive @shareable repeatable on FIELD_DEFINITION | OBJECT
directive @tag(
name: String!
) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION
scalar FieldSet
scalar Scope
""",
    # v2.6
    """directive @policy(
policies: [[federation__Policy!]!]!
) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @requiresScopes(
scopes: [[federation__Scope!]!]!
) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @composeDirective(name: String!) repeatable on SCHEMA
directive @extends on OBJECT | INTERFACE
directive @external on OBJECT | FIELD_DEFINITION
directive @key(
fields: FieldSet!
resolvable: Boolean = true
) repeatable on OBJECT | INTERFACE
directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION
directive @interfaceObject on OBJECT
directive @override(from: String!) on FIELD_DEFINITION
directive @provides(fields: FieldSet!) on FIELD_DEFINITION
directive @requires(fields: FieldSet!) on FIELD_DEFINITION
directive @shareable repeatable on FIELD_DEFINITION | OBJECT
directive @tag(
name: String!
) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION
scalar FieldSet
scalar federation__Policy
scalar federation__Scope
""",
    # v2.7
    """directive @policy(
policies: [[federation__Policy!]!]!
) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @requiresScopes(
scopes: [[federation__Scope!]!]!
) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @composeDirective(name: String!) repeatable on SCHEMA
directive @extends on OBJECT | INTERFACE
directive @external on OBJECT | FIELD_DEFINITION
directive @key(
fields: FieldSet!
resolvable: Boolean = true
) repeatable on OBJECT | INTERFACE
directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION
directive @interfaceObject on OBJECT
directive @override(from: String!, label: String) on FIELD_DEFINITION
directive @provides(fields: FieldSet!) on FIELD_DEFINITION
directive @requires(fields: FieldSet!) on FIELD_DEFINITION
directive @shareable repeatable on FIELD_DEFINITION | OBJECT
directive @tag(
name: String!
) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION
scalar FieldSet
scalar federation__Policy
scalar federation__Scope
""",
    # v2.8
    """directive @policy(
policies: [[federation__Policy!]!]!
) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @requiresScopes(
scopes: [[federation__Scope!]!]!
) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @composeDirective(name: String!) repeatable on SCHEMA
directive @extends on OBJECT | INTERFACE
directive @external on OBJECT | FIELD_DEFINITION
directive @key(
fields: FieldSet!
resolvable: Boolean = true
) repeatable on OBJECT | INTERFACE
directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION
directive @interfaceObject on OBJECT
directive @override(from: String!, label: String) on FIELD_DEFINITION
directive @provides(fields: FieldSet!) on FIELD_DEFINITION
directive @requires(fields: FieldSet!) on FIELD_DEFINITION
directive @shareable repeatable on FIELD_DEFINITION | OBJECT
directive @tag(
name: String!
) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION
directive @cost(
weight: Int!
) on ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION | INPUT_FIELD_DEFINITION | OBJECT | SCALAR
directive @listSize(
assumedSize: Int
slicingArguments: [String!]
sizedFields: [String!]
requireOneSlicingArgument: Boolean = true
) on FIELD_DEFINITION
directive @context(
name: String!
) repeatable on INTERFACE | OBJECT | UNION
directive @fromContext(
field: federation__ContextFieldValue
) on ARGUMENT_DEFINITION
scalar FieldSet
scalar federation__Policy
scalar federation__Scope
scalar federation__ContextFieldValue
""",
    # v2.9
    """directive @policy(
policies: [[federation__Policy!]!]!
) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @requiresScopes(
scopes: [[federation__Scope!]!]!
) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM
directive @composeDirective(name: String!) repeatable on SCHEMA
directive @extends on OBJECT | INTERFACE
directive @external on OBJECT | FIELD_DEFINITION
directive @key(
fields: FieldSet!
resolvable: Boolean = true
) repeatable on OBJECT | INTERFACE
directive @inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION
directive @interfaceObject on OBJECT
directive @override(from: String!, label: String) on FIELD_DEFINITION
directive @provides(fields: FieldSet!) on FIELD_DEFINITION
directive @requires(fields: FieldSet!) on FIELD_DEFINITION
directive @shareable repeatable on FIELD_DEFINITION | OBJECT
directive @tag(
name: String!
) repeatable on FIELD_DEFINITION | INTERFACE | OBJECT | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION
directive @cost(
weight: Int!
) on ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION | INPUT_FIELD_DEFINITION | OBJECT | SCALAR
directive @listSize(
assumedSize: Int
slicingArguments: [String!]
sizedFields: [String!]
requireOneSlicingArgument: Boolean = true
) on FIELD_DEFINITION
directive @context(
name: String!
) repeatable on INTERFACE | OBJECT | UNION
directive @fromContext(
field: federation__ContextFieldValue
) on ARGUMENT_DEFINITION
scalar FieldSet
scalar federation__Policy
scalar federation__Scope
scalar federation__ContextFieldValue
""",
]
"""The SDL of each version, in `FederationVersion` order."""


def is_specified_scalar(name: StringSlice) -> Bool:
    """Return True for the five scalars of the GraphQL specification.

    Args:
        name: A type name.

    Returns:
        Whether it is `String`, `Int`, `Float`, `Boolean` or `ID`.
    """
    return (
        name == "String"
        or name == "Int"
        or name == "Float"
        or name == "Boolean"
        or name == "ID"
    )


def strip_at(name: StringSlice) -> String:
    """Return a name without one leading `@`, as upstream
    `name.replace(/^@/, "")`.

    Args:
        name: A name such as `@key`.

    Returns:
        The name without the `@`.
    """
    if name.startswith("@"):
        return String(name[byte=1:])
    return String(name)


@fieldwise_init
struct SpecArgument(Copyable):
    """An argument of a federation directive definition."""

    var name: String
    """The argument's name."""
    var type: String
    """The printed type, with the prefix applied, such as `FieldSet!`."""
    var non_null: Bool
    """Whether the type is a non-null type."""
    var boolean_default: Int
    """-1 without a boolean default value, else 0 for false and 1 for
    true."""


@fieldwise_init
struct SpecDefinition(Copyable):
    """A directive or type definition of the federation specification."""

    var name: String
    """The name with the prefix applied, such as `federation__key`."""
    var node: Int
    """The definition node in the `SpecSchema` document."""
    var prefix: String
    """The prefix: empty or `federation__`."""
    var is_directive: Bool
    """Whether it is a directive definition."""
    var arguments: List[SpecArgument]
    """The arguments of a directive, in order."""
    var locations: List[String]
    """The locations of a directive, in order."""
    var repeatable: Bool
    """Whether a directive is repeatable."""


struct SpecSchema(Copyable):
    """The federation directives and types of a version, as upstream
    `createSpecSchema` returns them."""

    var document: Document
    """The parsed SDL of the version, which holds the nodes."""
    var directives: List[SpecDefinition]
    """The directive definitions, in upstream order."""
    var types: List[SpecDefinition]
    """The type definitions, in upstream order."""

    def __init__(out self, var document: Document):
        """Start an empty schema over a parsed document.

        Args:
            document: The parsed SDL.
        """
        self.document = document^
        self.directives = List[SpecDefinition]()
        self.types = List[SpecDefinition]()

    def has_directive(self, name: StringSlice) -> Bool:
        """Return True if a directive with a name is in the schema.

        Args:
            name: The name, with the prefix.

        Returns:
            Whether such a directive exists.
        """
        var index = 0
        while index < len(self.directives):
            if self.directives[index].name == name:
                return True
            index += 1
        return False

    def has_type(self, name: StringSlice) -> Bool:
        """Return True if a type with a name is in the schema.

        Args:
            name: The name, with the prefix.

        Returns:
            Whether such a type exists.
        """
        for ref definition in self.types:
            if definition.name == name:
                return True
        return False


struct SpecCache(Movable):
    """The parsed SDL of each federation version, parsed on first use."""

    var documents: List[Document]
    """One document per version."""
    var parsed: List[Bool]
    """Whether the document of a version is parsed."""

    def __init__(out self):
        """Start an empty cache."""
        self.documents = List[Document](length=VERSION_COUNT, fill=Document())
        self.parsed = List[Bool](length=VERSION_COUNT, fill=False)

    def document(mut self, version: FederationVersion) raises -> Document:
        """Return a copy of the parsed SDL of a version.

        Args:
            version: A valid version.

        Returns:
            The document; for `v1.0` it also holds `@tag` and
            `@inaccessible`.

        Raises:
            Error: Never for the SDL of this module; `parse` can raise.
        """
        var index = Int(version.value)
        if not self.parsed[index]:
            var text = String(
                materialize[_SPEC_SDL]()[materialize[_BASE_SDL]()[index]]
            )
            if index == 0:
                text += TAG_SDL + INACCESSIBLE_SDL
            var added = 0
            while added < _ADDED_COUNT:
                if version.at_least(materialize[_ADDED_SINCE]()[added]):
                    text += materialize[_ADDED_SDL]()[added]
                added += 1
            self.documents[index] = parse(text)
            self.parsed[index] = True
        return self.documents[index].copy()


def _print_type(document: Document, node: Int, prefix: String) -> String:
    """Print a type reference with the prefix on a named type that is not
    a specified scalar, as upstream `applyPrefix` renames it."""
    var kind = document.kind(node)
    if kind == Kind.NON_NULL_TYPE:
        return _print_type(document, document.first_child(node), prefix) + "!"
    if kind == Kind.LIST_TYPE:
        return (
            "["
            + _print_type(document, document.first_child(node), prefix)
            + "]"
        )
    var name = String(document.name(node))
    if is_specified_scalar(name):
        return name^
    return prefix + name


def _contains(names: List[String], name: StringSlice) -> Bool:
    """Return True if a list holds a name. The list is never empty."""
    var index = 0
    while index < len(names):
        if names[index] == name:
            return True
        index += 1
    return False


def _add_definitions(
    mut schema: SpecSchema,
    prefix: String,
    imports: List[LinkImport],
    has_imports: Bool,
):
    """Add the definitions of the document with a prefix, filtered by the
    imports, as upstream `createTypeDefinitions`."""
    var include = List[String]()
    for ref item in imports:
        include.append(strip_at(item.name))
    if (
        len(imports) == 0
        or _contains(include, "key")
        or _contains(include, "requires")
        or _contains(include, "provides")
    ):
        include.append("FieldSet")
        include.append("federation__FieldSet")
    if _contains(include, "requiresScopes"):
        include.append("federation__Scope")
    if _contains(include, "policy"):
        include.append("federation__Policy")
    ref document = schema.document
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        var name = prefix + String(document.name(definition))
        if document.kind(definition) == Kind.DIRECTIVE_DEFINITION:
            if not has_imports or _contains(include, name):
                var arguments = List[SpecArgument]()
                var locations = List[String]()
                var child = document.first_child(definition)
                while child != NO_NODE:
                    if document.role(child) == Role.ARGUMENT:
                        var type_node = document.child(child, Role.TYPE)
                        var default = document.child(child, Role.DEFAULT_VALUE)
                        # Every default value in the federation SDL is a
                        # Boolean.
                        var boolean_default = -1
                        if default != NO_NODE:
                            boolean_default = Int(
                                document.boolean_value(default)
                            )
                        arguments.append(
                            SpecArgument(
                                String(document.name(child)),
                                _print_type(document, type_node, prefix),
                                document.kind(type_node) == Kind.NON_NULL_TYPE,
                                boolean_default,
                            )
                        )
                    elif document.role(child) == Role.LOCATION:
                        locations.append(String(document.text(child)))
                    child = document.next_sibling(child)
                schema.directives.append(
                    SpecDefinition(
                        name^,
                        definition,
                        prefix,
                        True,
                        arguments^,
                        locations^,
                        document.is_repeatable(definition),
                    )
                )
        elif _contains(include, name):
            schema.types.append(
                SpecDefinition(
                    name^,
                    definition,
                    prefix,
                    False,
                    List[SpecArgument](),
                    List[String](),
                    False,
                )
            )
        definition = document.next_sibling(definition)


def create_spec_schema(
    mut cache: SpecCache,
    version: FederationVersion,
    imports: List[LinkImport],
    has_imports: Bool,
) raises -> SpecSchema:
    """Return the federation directives and types of a version, as upstream
    `createSpecSchema(version, imports)`.

    Args:
        cache: The parsed SDL of each version.
        version: A valid version.
        imports: The imports of the federation link.
        has_imports: False for upstream `imports` `undefined`: then every
            directive is in the result.

    Returns:
        The imported definitions without a prefix, then every definition
        with the `federation__` prefix. For `v1.0`, every definition and
        `@tag` and `@inaccessible`.

    Raises:
        Error: Only if the SDL of the version does not parse.
    """
    var schema = SpecSchema(cache.document(version))
    if version != FederationVersion.V1_0:
        _add_definitions(schema, String(""), imports, has_imports)
        _add_definitions(
            schema, String(FEDERATION_PREFIX), List[LinkImport](), False
        )
    else:
        _add_definitions(schema, String(""), List[LinkImport](), False)
    return schema^


@fieldwise_init
struct FederationSpec(Copyable):
    """The federation version of a subgraph and its imports, as upstream
    `detectFederationVersion` returns them."""

    var version: FederationVersion
    """The version."""
    var imports: List[LinkImport]
    """The imports of the federation link; empty for `v1.0`."""


def _first_argument(
    document: Document, directive: Int, name: StringSlice
) -> Int:
    """Return the first argument of a directive with a name, or
    `NO_NODE`."""
    var argument = document.first_child(directive)
    while argument != NO_NODE:
        if (
            document.role(argument) == Role.ARGUMENT
            and document.name(argument) == name
        ):
            return argument
        argument = document.next_sibling(argument)
    return NO_NODE


def detect_federation_version(
    document: Document, definitions: List[Int]
) raises -> FederationSpec:
    """Return the federation version of a subgraph, as upstream
    `detectFederationVersion`.

    The first schema definition or extension whose `@link` directives
    link the federation specification with a version decides.

    Args:
        document: The subgraph's document.
        definitions: Its definitions, in order.

    Returns:
        The version and the imports; `v1.0` without a federation link.

    Raises:
        Error: `Invalid @link directive` for a `@link` without `url`, or
            the error of `parse_link_import`.
    """
    var position = 0
    while position < len(definitions):
        var definition = definitions[position]
        position += 1
        var kind = document.kind(definition)
        if kind != Kind.SCHEMA_DEFINITION and kind != Kind.SCHEMA_EXTENSION:
            continue
        var found = False
        var federation = FederationSpec(FederationVersion.V1_0, [])
        var directive = document.first_child(definition)
        while directive != NO_NODE:
            if (
                document.role(directive) == Role.DIRECTIVE
                and document.name(directive) == "link"
            ):
                var url = _first_argument(document, directive, "url")
                if url == NO_NODE:
                    raise Error("Invalid @link directive")
                var import_argument = _first_argument(
                    document, directive, "import"
                )
                var imports = parse_link_import(
                    document,
                    NO_NODE if import_argument
                    == NO_NODE else document.child(import_argument, Role.VALUE),
                )
                var value = document.child(url, Role.VALUE)
                if not found and document.kind(value) == Kind.STRING:
                    var spec = parse_link_url(document.string_value(value))
                    if spec.identity == "https://specs.apollo.dev/federation":
                        found = True
                        # The `@link` rules of `validate` reject a
                        # federation link without a version, or with an
                        # unknown version, before this runs.
                        var index = FederationVersion.from_text(
                            spec.version.value()
                        )
                        federation = FederationSpec(
                            FederationVersion(UInt8(index)), imports^
                        )
            directive = document.next_sibling(directive)
        if found:
            return federation^
    return FederationSpec(FederationVersion.V1_0, [])


def _set_text(mut document: Document, node: Int, text: StringSlice):
    """Point a node's text at new bytes after the document's source."""
    var start = len(document.source.bytes)
    document.source.bytes.extend(text.as_bytes())
    document.nodes[node].start = Int32(start)
    document.nodes[node].end = Int32(len(document.source.bytes))


def copy_spec_definition(
    mut target: Document,
    schema: SpecSchema,
    definition: SpecDefinition,
    name: String,
) -> Int:
    """Copy a definition of the specification into a document, renamed, as
    upstream `applyPrefix` and the import aliases rename it.

    Args:
        target: The document to copy into.
        schema: The schema that holds the definition.
        definition: The definition.
        name: The name of the copy.

    Returns:
        The copy, which has no parent. A directive copy with a prefix has
        the prefix on the named type of each argument that is not a
        specified scalar.
    """
    var copy = target.copy_subtree(
        schema.document, definition.node, Role.DEFINITION
    )
    _set_text(target, target.child(copy, Role.NAME), name)
    if definition.prefix.byte_length() == 0 or not definition.is_directive:
        return copy
    var argument = target.first_child(copy)
    while argument != NO_NODE:
        if target.role(argument) == Role.ARGUMENT:
            var type = target.child(argument, Role.TYPE)
            while target.kind(type) != Kind.NAMED_TYPE:
                type = target.first_child(type)
            var type_name = String(target.name(type))
            if not is_specified_scalar(type_name):
                _set_text(
                    target,
                    target.child(type, Role.NAME),
                    definition.prefix + type_name,
                )
        argument = target.next_sibling(argument)
    return copy


def link_spec_schema() raises -> SpecSchema:
    """Return the link specification definitions that upstream
    `validateSubgraph` adds, in order, all in `types`.

    Returns:
        The schema; each definition keeps its name.

    Raises:
        Error: Only if the SDL does not parse.
    """
    var schema = SpecSchema(parse(LINK_SPEC_SDL))
    ref document = schema.document
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        schema.types.append(
            SpecDefinition(
                String(document.name(definition)),
                definition,
                String(""),
                document.kind(definition) == Kind.DIRECTIVE_DEFINITION,
                List[SpecArgument](),
                List[String](),
                False,
            )
        )
        definition = document.next_sibling(definition)
    return schema^
