# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Build the model of a subgraph from its SDL, as `buildSubgraph`.

`@apollo/subgraph` 2.14.4 `buildSubgraphSchema.ts` calls `buildSubgraph`
of `@apollo/federation-internals`, which is Elastic licensed and is not
read. `build_subgraph` implements it from the Apollo Federation subgraph
specification and the federation/v2.x specifications, with Hive Federation
Composition v0.27.0 (MIT) as the reference. What it adds, in which order,
and its error messages, are those of `@apollo/subgraph` 2.14.4, observed
as a black box:

- Federation 1: the definitions of `@key`, `@requires`, `@provides`,
  `@external`, `@tag` and `@extends`, and `scalar _FieldSet`, when the SDL
  does not define them.
- Federation 2: the `@link` definition and its types, and each directive
  and type of the linked version, under its imported name or with the
  `federation__` prefix (or the `as` prefix of the link). A
  `@link(url: "https://specs.apollo.dev/link/v1.0")` goes first on the
  schema definition, unless the SDL links the link specification.
- Then `scalar _Any`, `type _Service { sdl: String }`, and
  `union _Entity` of each object type with a `@key`, sorted by name.
- `_entities(representations: [_Any!]!): [_Entity]!` when there is an
  entity, and `_service: _Service!`, at the end of the query root type,
  which is `Query` and is added when there is none.

**Differences from upstream.** See `gql_subgraph.model`.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.concat_ast import concat_ast
from gql_language.parser import parse
from gql_language.names import NOT_FOUND, NameTable
from gql_schema.suggestions import did_you_mean, suggestion_list
from gql_subgraph.link import LinkInfo, read_links
from gql_subgraph.model import (
    GENERATED,
    USER,
    DirectiveEntry,
    Part,
    Ref,
    SubgraphModel,
    TypeEntry,
)
from gql_subgraph.spec import (
    DIRECTIVE_COUNT,
    FED1_DIRECTIVE_COUNT,
    LINK_SDL,
    LINK_PURPOSE_SDL,
    TYPE_COUNT,
    directive_body,
    directive_index,
    has_type,
)

comptime INVALID_SCHEMA = (
    "The schema is not a valid GraphQL schema.. Caused by:\n"
)
"""The start of the message of a schema that does not build."""

comptime _BUILTIN_SCALARS: Array[StaticString, 5] = [
    "Int",
    "Float",
    "String",
    "Boolean",
    "ID",
]

comptime _BUILTIN_DIRECTIVES: Array[StaticString, 5] = [
    "include",
    "skip",
    "deprecated",
    "specifiedBy",
    "oneOf",
]


def invalid_schema(messages: List[String]) -> Error:
    """Return the error of a schema that does not build.

    Args:
        messages: The causes, at least one.

    Returns:
        An `Error` whose message is `INVALID_SCHEMA` and the causes,
        separated by blank lines.
    """
    var message = String(INVALID_SCHEMA) + messages[0]
    var index = 1
    while index < len(messages):
        message += "\n\n" + messages[index]
        index += 1
    return Error(message)


def _is_builtin_directive(name: StringSlice) -> Bool:
    """Return True for the name of a directive that graphql-js defines."""
    var index = 0
    while index < 5:
        if name == materialize[_BUILTIN_DIRECTIVES]()[index]:
            return True
        index += 1
    return False


def _collect(
    doc: Document, mut model: SubgraphModel, mut schema_nodes: List[Int]
) raises -> Bool:
    """Add each definition of the user's SDL to the model, the directive
    definitions first; return whether the SDL has an executable
    definition."""
    var known = NameTable()
    var definition = doc.first_child(doc.root)
    while definition != NO_NODE:
        if doc.kind(definition) == Kind.DIRECTIVE_DEFINITION:
            var name = doc.name(definition)
            if not known.insert(-1, name, 0):
                raise Error(
                    "Directive @"
                    + String(name)
                    + " already exists in this schema"
                )
            # printSubgraphSchema leaves out a definition of a graphql-js
            # directive, as it leaves out the federation definitions.
            model.directives.append(
                DirectiveEntry(
                    Ref(USER, definition), _is_builtin_directive(name)
                )
            )
        definition = doc.next_sibling(definition)
    var executable = False
    var schema_definition = NO_NODE
    definition = doc.first_child(doc.root)
    while definition != NO_NODE:
        var kind = doc.kind(definition)
        if kind == Kind.SCHEMA_DEFINITION and schema_definition == NO_NODE:
            schema_definition = definition
            schema_nodes.insert(0, definition)
        elif kind == Kind.SCHEMA_DEFINITION or kind == Kind.SCHEMA_EXTENSION:
            schema_nodes.append(definition)
            model.schema_parts.append(Part(USER, definition, True))
        elif kind.is_type_definition() or kind.is_type_extension():
            _ = model.add_part(
                USER, definition, kind, String(doc.name(definition))
            )
        elif kind != Kind.DIRECTIVE_DEFINITION:
            executable = True
        definition = doc.next_sibling(definition)
    model.schema_parts.insert(0, Part(USER, schema_definition, False))
    return executable


def _added_type_names(info: LinkInfo) -> List[String]:
    """Return the names of the types that federation can add."""
    var names: List[String] = [
        String("_Any"),
        String("_Service"),
        String("_Entity"),
    ]
    if info.version.is_fed2() or info.links_link_spec:
        names.append(String("link__Purpose"))
        names.append(String("link__Import"))
    if not info.version.is_fed2():
        names.append(String("_FieldSet"))
        return names^
    var index = 0
    while index < TYPE_COUNT:
        if has_type(info.version, index):
            names.append(info.type_refs[index])
        index += 1
    return names^


def _check_types(doc: Document, model: SubgraphModel, info: LinkInfo) raises:
    """Raise `Unknown type X` for the first reference to an undefined type."""
    var known = NameTable()
    var index = 0
    while index < 5:
        _ = known.insert(-1, materialize[_BUILTIN_SCALARS]()[index], 0)
        index += 1
    var added = _added_type_names(info)
    index = 0
    while index < len(added):
        _ = known.insert(-1, added[index], 0)
        index += 1
    index = 0
    while index < len(doc.nodes):
        if doc.kind(index) == Kind.NAMED_TYPE:
            var name = doc.name(index)
            if (
                model.type_index(name) == NOT_FOUND
                and known.find(-1, name) == NOT_FOUND
            ):
                raise Error("Unknown type " + String(name))
        index += 1


def _hint(info: LinkInfo, name: String, candidates: List[String]) -> String:
    """Return the end of the message for an unknown directive."""
    var index = directive_index(name)
    var quoted = '"@' + name + '"'
    if info.version.is_fed2() and index >= 0:
        if info.renamed[index]:
            return (
                " If you meant the "
                + quoted
                + ' federation directive, you should use "@'
                + info.names[index]
                + '" as it is imported under that name in the @link to the'
                " federation specification of this schema."
            )
        return (
            " If you meant the "
            + quoted
            + ' federation directive, you should use fully-qualified name "@'
            + info.prefix
            + name
            + '" or add '
            + quoted
            + " to the `import` argument of the @link to the federation"
            " specification."
        )
    if not info.version.is_fed2() and index >= FED1_DIRECTIVE_COUNT:
        return (
            " If you meant the "
            + quoted
            + " federation 2 directive, note that this schema is a"
            " federation 1 schema. To be a federation 2 schema, it needs to"
            " @link to the federation specifcation v2."
        )
    return did_you_mean(suggestion_list("@" + name, candidates))


def _check_directives(
    doc: Document, model: SubgraphModel, info: LinkInfo
) -> List[String]:
    """Return an `Unknown directive` message for each application of a
    directive that is not defined."""
    var known = NameTable()
    var candidates = List[String]()
    var index = 0
    while index < len(model.directives):
        # `_collect` refused a second definition of a name.
        var name = String(doc.name(model.directives[index].at.node))
        _ = known.insert(-1, name, 0)
        candidates.append("@" + name)
        index += 1
    var links = info.version.is_fed2() or info.links_link_spec
    if links and known.insert(-1, "link", 0):
        candidates.append("@link")
    index = 0
    while index < DIRECTIVE_COUNT:
        if info.names[index] != "" and known.insert(-1, info.names[index], 0):
            candidates.append("@" + info.names[index])
        index += 1
    index = 0
    while index < 5:
        var name = String(materialize[_BUILTIN_DIRECTIVES]()[index])
        if known.insert(-1, name, 0):
            candidates.append("@" + name)
        index += 1
    var errors = List[String]()
    index = 0
    while index < len(doc.nodes):
        if doc.kind(index) == Kind.DIRECTIVE:
            var name = String(doc.name(index))
            if known.find(-1, name) == NOT_FOUND:
                errors.append(
                    'Unknown directive "@'
                    + name
                    + '".'
                    + _hint(info, name, candidates)
                )
        index += 1
    return errors^


def _weight(byte: Int) -> Int:
    """Return the primary collation weight of a byte of a name: a GraphQL
    name has only `_`, letters and digits."""
    if byte >= 97:
        return byte + 1000 - 97
    if byte >= 65 and byte <= 90:
        return byte + 1000 - 65
    if byte <= 57:
        return byte + 500
    return byte


def locale_compare(a: StringSlice, b: StringSlice) -> Int:
    """Compare two names as JavaScript `localeCompare` does for names: the
    letters without case first, so `_x < aType < Atype < bType`.

    Args:
        a: The first name.
        b: The second name.

    Returns:
        A negative number, zero or a positive number.
    """
    var x = a.as_bytes()
    var y = b.as_bytes()
    var index = 0
    var tie = 0
    while index < len(x) and index < len(y):
        var left = Int(x[index])
        var right = Int(y[index])
        if _weight(left) != _weight(right):
            return _weight(left) - _weight(right)
        if tie == 0 and left != right:
            # The same letter in another case: the lowercase one first.
            tie = right - left
        index += 1
    if len(x) != len(y):
        return len(x) - len(y)
    return tie


def _find_entities(doc: Document, mut model: SubgraphModel, key: String):
    """Set the members of `_Entity`: the object types with `@key`."""
    var index = 0
    while index < len(model.types):
        ref entry = model.types[index]
        var found = False
        var part = 0
        while part < len(entry.parts) and not found:
            var directive = doc.child(entry.parts[part].node, Role.DIRECTIVE)
            while directive != NO_NODE and not found:
                found = String(doc.name(directive)) == key
                directive = doc.next_with_role(directive)
            part += 1
        if found and entry.kind == Kind.OBJECT_TYPE_DEFINITION:
            var at = len(model.entities)
            while (
                at > 0
                and locale_compare(model.entities[at - 1], entry.name) > 0
            ):
                at -= 1
            model.entities.insert(at, entry.name)
        index += 1


def _user_directive(doc: Document, model: SubgraphModel, name: String) -> Int:
    """Return the index of a directive definition of the user, or -1."""
    var index = 0
    while index < len(model.directives):
        if String(doc.name(model.directives[index].at.node)) == name:
            return index
        index += 1
    return -1


def _add_directive(
    doc: Document,
    mut model: SubgraphModel,
    mut sdl: String,
    name: String,
    body: StringSlice,
):
    """Generate a federation directive, or hide the user's definition."""
    var index = _user_directive(doc, model, name)
    if index >= 0:
        model.directives[index].hidden = True
    else:
        sdl += "directive @" + name + body + "\n"


def _add_type(
    mut model: SubgraphModel, mut sdl: String, name: String, definition: String
):
    """Generate a federation type, or hide the user's type."""
    var index = model.type_index(name)
    if index != NOT_FOUND:
        model.types[index].hidden = True
    else:
        sdl += definition + "\n"


def _generate(
    doc: Document, mut model: SubgraphModel, info: LinkInfo
) -> String:
    """Return the SDL that federation adds to the user's SDL."""
    var sdl = String("")
    var fed2 = info.version.is_fed2()
    if fed2 and not info.links_link_spec:
        sdl += (
            'extend schema @link(url: "https://specs.apollo.dev/link/v1.0")\n'
        )
    # A link to the link specification alone adds its definitions too.
    var links = fed2 or info.links_link_spec
    if links:
        _add_directive(doc, model, sdl, "link", LINK_SDL[byte=15:])
    var index = 0
    while index < DIRECTIVE_COUNT:
        if info.names[index] != "":
            _add_directive(
                doc,
                model,
                sdl,
                info.names[index],
                directive_body(index, info.version, info.type_refs),
            )
        index += 1
    if links:
        _add_type(model, sdl, "link__Purpose", LINK_PURPOSE_SDL)
        _add_type(model, sdl, "link__Import", "scalar link__Import")
    index = 0
    while index < TYPE_COUNT:
        if (fed2 and has_type(info.version, index)) or index == 0:
            var name = info.type_refs[index]
            _add_type(model, sdl, name, "scalar " + name)
        index += 1
    _add_type(model, sdl, "_Any", "scalar _Any")
    _add_type(model, sdl, "_Service", "type _Service {\n  sdl: String\n}")
    if len(model.entities) > 0:
        var members = String("")
        index = 0
        while index < len(model.entities):
            members += (" | " if index > 0 else "") + model.entities[index]
            index += 1
        _add_type(model, sdl, "_Entity", "union _Entity = " + members)
    sdl += "extend type Query {\n"
    if len(model.entities) > 0:
        sdl += "  _entities(representations: [_Any!]!): [_Entity]!\n"
    return sdl + "  _service: _Service!\n}\n"


def _register(gen: Document, mut model: SubgraphModel) raises -> List[Ref]:
    """Add the generated definitions to the model; return the fields of
    the generated `Query`, which is the last definition."""
    var definition = gen.first_child(gen.root)
    var fields = List[Ref]()
    while definition != NO_NODE:
        var kind = gen.kind(definition)
        if kind == Kind.SCHEMA_EXTENSION:
            model.schema_parts[0].prefix.append(
                Ref(GENERATED, gen.child(definition, Role.DIRECTIVE))
            )
        elif kind == Kind.DIRECTIVE_DEFINITION:
            model.directives.append(
                DirectiveEntry(Ref(GENERATED, definition), True)
            )
        elif gen.next_sibling(definition) != NO_NODE:
            var at = model.add_part(
                GENERATED, definition, kind, String(gen.name(definition))
            )
            model.types[at].hidden = True
        else:
            var field = gen.child(definition, Role.FIELD)
            while field != NO_NODE:
                fields.append(Ref(GENERATED, field))
                field = gen.next_with_role(field)
        definition = gen.next_sibling(definition)
    return fields^


comptime _DEFAULT_ROOTS: Array[StaticString, 3] = [
    "Query",
    "Mutation",
    "Subscription",
]


def _set_roots(doc: Document, mut model: SubgraphModel, var fields: List[Ref]):
    """Find the root types, add `Query` when there is none, and add the
    federation fields to the query root type."""
    var part = 0
    while part < len(model.schema_parts):
        var node = model.schema_parts[part].node
        var operation = NO_NODE
        if node != NO_NODE:
            operation = doc.child(node, Role.OPERATION_TYPE)
        while operation != NO_NODE:
            var which = Int(doc.operation(operation).value)
            model.roots[which] = String(
                doc.named_type(doc.child(operation, Role.TYPE))
            )
            model.declared[which] = True
            operation = doc.next_with_role(operation)
        part += 1
    var index = 0
    while index < 3:
        var name = String(materialize[_DEFAULT_ROOTS]()[index])
        if (
            model.schema_parts[0].node == NO_NODE
            and not model.declared[index]
            and model.type_index(name) != NOT_FOUND
        ):
            model.roots[index] = name
        index += 1
    if model.roots[0] == "":
        model.roots[0] = "Query"
        _ = model.type_names.insert(-1, "Query", len(model.types))
        model.types.append(TypeEntry("Query", Kind.OBJECT_TYPE_DEFINITION))
    ref query = model.types[model.type_index(model.roots[0])]
    index = 0
    while index < len(query.parts) and query.parts[index].is_extension:
        index += 1
    if index == len(query.parts):
        index = 0
        query.parts.insert(0, Part(USER, NO_NODE, False))
    query.parts[index].added = fields^


def build_subgraph(documents: List[Document]) raises -> SubgraphModel:
    """Build the model of a subgraph, as federation-internals
    `buildSubgraph(name, url, document, false)`.

    Args:
        documents: The SDL documents, which are joined as graphql-js
            `concatAST` joins them.

    Returns:
        The model, with the federation definitions added.

    Raises:
        Error: `Directive @x already exists in this schema`, `There can be
            only one type named "X"`, `Unknown type X`, a malformed
            federation version, a second link to the federation
            specification, or `INVALID_SCHEMA` with an executable
            definition, the unknown directives, the link and import
            errors, or an unsupported federation version.
    """
    var user = concat_ast(documents)
    var model = SubgraphModel()
    var schema_nodes = List[Int]()
    var executable = _collect(user, model, schema_nodes)
    var info: LinkInfo
    try:
        info = read_links(user, schema_nodes)
    except error:
        var message = String(error)
        if message.startswith("Invalid version"):
            raise invalid_schema([message])
        raise error^
    _check_types(user, model, info)
    if executable:
        raise invalid_schema(
            ["Invalid executable definition found while building schema"]
        )
    var errors = info.errors.copy()
    errors.extend(_check_directives(user, model, info))
    if len(errors) > 0:
        raise invalid_schema(errors)
    _find_entities(user, model, info.names[0])
    var gen = parse(_generate(user, model, info))
    var fields = _register(gen, model)
    _set_roots(user, model, fields^)
    model.version = info.version
    model.names = info.names.copy()
    model.type_refs = info.type_refs.copy()
    model.docs.append(user^)
    model.docs.append(gen^)
    return model^
