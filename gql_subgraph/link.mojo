# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Read the `@link` directives of a subgraph: its federation version, and
the name of each federation directive and type in it.

Implemented from the link specification (https://specs.apollo.dev/link/v1.0:
`url`, `as` and `import`) and the federation/v2.x specifications, with
Hive Federation Composition v0.27.0 `src/utils/link.ts` (MIT) as the
reference. `@apollo/subgraph` 2.14.4 does this in
`@apollo/federation-internals`, which is Elastic licensed and is not read;
the error messages are those it gives, observed as a black box.

**Differences from upstream.** The link specification itself cannot be
renamed with `as` or imported from: its directive is always `@link`.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_subgraph.sdl_printer import print_value
from gql_subgraph.spec import (
    DIRECTIVE_COUNT,
    FEDERATION_URL,
    LINK_URL,
    TYPE_COUNT,
    FederationVersion,
    directive_index,
    directive_name,
    has_directive,
    has_type,
    parse_federation_url,
    type_index,
    type_name,
)


struct LinkInfo(Movable):
    """What the `@link` directives of a subgraph say."""

    var version: FederationVersion
    """The federation version; federation 1 without a federation link."""
    var prefix: String
    """The prefix of the federation names that are not imported, such as
    `federation__`."""
    var names: List[String]
    """The name of each federation directive, or empty when the version
    does not have it."""
    var renamed: List[Bool]
    """Whether each directive is imported under another name."""
    var type_refs: List[String]
    """The name of each federation type."""
    var links_link_spec: Bool
    """Whether a `@link` names the link specification."""
    var errors: List[String]
    """The import errors."""

    def __init__(out self):
        """Describe a federation 1 subgraph."""
        self.version = FederationVersion.FED1
        self.prefix = String("")
        self.names = List[String]()
        self.renamed = List[Bool]()
        self.type_refs = List[String]()
        self.links_link_spec = False
        self.errors = List[String]()


def argument_value(doc: Document, directive: Int, name: StringSlice) -> Int:
    """Return the value of an argument of a directive application.

    Args:
        doc: The document.
        directive: A `Directive` node.
        name: The argument's name.

    Returns:
        The value node, or `NO_NODE` when the argument is not given.
    """
    var argument = doc.child(directive, Role.ARGUMENT)
    while argument != NO_NODE:
        if doc.name(argument) == name:
            return doc.child(argument, Role.VALUE)
        argument = doc.next_with_role(argument)
    return NO_NODE


def string_argument(doc: Document, directive: Int, name: StringSlice) -> String:
    """Return the string value of an argument of a directive application.

    Args:
        doc: The document.
        directive: A `Directive` node.
        name: The argument's name.

    Returns:
        The string, or empty when the argument is not a string.
    """
    var value = argument_value(doc, directive, name)
    if value == NO_NODE or doc.kind(value) != Kind.STRING:
        return String("")
    return doc.string_value(value)


def _object_string(doc: Document, object: Int, key: StringSlice) -> String:
    """Return the string of a field of an object value, or empty."""
    var field = doc.first_child(object)
    while field != NO_NODE:
        var value = doc.child(field, Role.VALUE)
        if doc.name(field) == key and doc.kind(value) == Kind.STRING:
            return doc.string_value(value)
        field = doc.next_sibling(field)
    return String("")


def _import(mut info: LinkInfo, name: String, var alias: String):
    """Apply one element of the `import` argument of the federation link."""
    if alias == "":
        alias = name
    if name.startswith("@"):
        var index = directive_index(name[byte=1:])
        if index >= 0 and has_directive(info.version, index):
            info.names[index] = String(alias.removeprefix("@"))
            info.renamed[index] = alias != name
            return
    else:
        var index = type_index(name)
        if index >= 0 and has_type(info.version, index):
            info.type_refs[index] = alias
            return
    info.errors.append('Cannot import unknown element "' + name + '".')


def read_links(doc: Document, schema_nodes: List[Int]) raises -> LinkInfo:
    """Read the `@link` directives of the schema definition and extensions.

    Args:
        doc: The document.
        schema_nodes: The `SchemaDefinition` and `SchemaExtension` nodes.

    Returns:
        The version, and the federation names.

    Raises:
        Error: The error of `parse_federation_url` for a version that is
            not supported.
    """
    var info = LinkInfo()
    var federation = NO_NODE
    var index = 0
    while index < len(schema_nodes):
        var directive = doc.child(schema_nodes[index], Role.DIRECTIVE)
        while directive != NO_NODE:
            var url = string_argument(doc, directive, "url")
            if String(doc.name(directive)) != "link":
                pass
            elif url == LINK_URL:
                info.links_link_spec = True
            elif url.startswith(FEDERATION_URL) and federation == NO_NODE:
                federation = directive
                info.version = parse_federation_url(url)
            directive = doc.next_with_role(directive)
        index += 1
    var fed2 = info.version.is_fed2()
    if fed2:
        var alias = string_argument(doc, federation, "as")
        info.prefix = (alias if alias != "" else String("federation")) + "__"
    index = 0
    while index < DIRECTIVE_COUNT:
        var name = String("")
        if has_directive(info.version, index):
            name = info.prefix + directive_name(index)
        info.names.append(name^)
        info.renamed.append(False)
        index += 1
    index = 0
    while index < TYPE_COUNT:
        info.type_refs.append(
            info.prefix + type_name(index) if fed2 else String("_FieldSet")
        )
        index += 1
    var imports = NO_NODE
    if fed2:
        imports = argument_value(doc, federation, "import")
    if imports == NO_NODE or doc.kind(imports) != Kind.LIST:
        return info^
    var item = doc.first_child(imports)
    while item != NO_NODE:
        if doc.kind(item) == Kind.STRING:
            _import(info, doc.string_value(item), String(""))
        elif doc.kind(item) == Kind.OBJECT:
            _import(
                info,
                _object_string(doc, item, "name"),
                _object_string(doc, item, "as"),
            )
        else:
            info.errors.append(
                "Invalid sub-value "
                + print_value(doc, item)
                + " for @link(import:) argument: values should be either"
                " strings or input object values of the form { name:"
                ' "<importedElement>", as: "<alias>" }.'
            )
        item = doc.next_sibling(item)
    return info^
