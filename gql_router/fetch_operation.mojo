# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The operation that a fetch sends to a subgraph.

Port of Hive Router `1a29df9` `bin/router/src/query_planner/ast/`:
`document.rs` (`Document`), `fragment.rs` (`FragmentDefinition`),
`fragment_expansion.rs` (`inline_fragment_spreads`), and the
`SubgraphFetchOperation` and `PlanningFetchOperation` part of
`operation.rs`.

**Differences from upstream.** `SubgraphFetchOperation` has no `hash`
field. Upstream hashes the document text with XXH3 for the executor and
for JSON. This port does not run plans yet, so it keeps only the text and
the operation name position.
"""

from gql_router.ast import NONE, ItemKind
from gql_router.federation_spec import OperationKind
from gql_router.operation import OperationDefinition
from gql_router.selection_set import pretty_set, write_indent, write_set
from gql_router.store import Store


@fieldwise_init
struct FragmentDefinition(Copyable, Movable):
    """A fragment of a fetch document, as upstream `FragmentDefinition`."""

    var name: Int
    """The fragment name, as a symbol."""
    var selection_set: Int
    """The selection set, a `ROOT` item."""
    var type_condition: Int
    """The type condition, as a symbol."""

    def text(self, store: Store) -> String:
        """Return the fragment as upstream `Display`.

        Args:
            store: The store with the names.

        Returns:
            Such as `fragment a on User {id name}`.
        """
        var out = String("fragment ")
        out += store.name(self.name)
        out += " on "
        out += store.name(self.type_condition)
        out += " "
        write_set(store, out, self.selection_set)
        return out^

    def pretty(self, store: Store, mut out: String, depth: Int):
        """Write the fragment as upstream `PrettyDisplay`.

        Args:
            store: The store with the names.
            out: The destination.
            depth: The indentation depth.
        """
        write_indent(out, depth)
        out += "  fragment "
        out += store.name(self.name)
        out += " on "
        out += store.name(self.type_condition)
        out += " {\n"
        pretty_set(store, out, self.selection_set, depth + 2)
        write_indent(out, depth)
        out += "  }\n"


@fieldwise_init
struct FetchDocument(Copyable, Movable):
    """An operation with its fragments, as upstream `Document`."""

    var operation: OperationDefinition
    """The operation."""
    var fragments: List[FragmentDefinition]
    """The fragments, sorted by name."""

    def text(self, store: Store) -> String:
        """Return the document as upstream `Display`.

        Args:
            store: The store with the selections.

        Returns:
            The operation, then a blank line and one fragment per line
            when there are fragments.
        """
        var out = self.operation.text(store)
        if len(self.fragments) == 0:
            return out^
        out += "\n\n"
        var index = 0
        while index < len(self.fragments):
            out += self.fragments[index].text(store)
            out += "\n"
            index += 1
        return out^


def inner_selection_set(store: Store, document: FetchDocument) -> Int:
    """Return the set that a fetch prints, as upstream
    `inner_selection_set`: the selections of a lone unaliased `_entities`
    field, or the operation's set.

    Args:
        store: The store.
        document: The document.

    Returns:
        The set.
    """
    var set = document.operation.selection_set
    var first = store.items[set].first
    if first != NONE and store.items[first].next == NONE:
        ref item = store.items[first]
        if (
            item.kind == ItemKind.FIELD
            and store.name(item.name) == "_entities"
            and item.alias == NONE
        ):
            return first
    return set


struct PlanningFetchOperation(Copyable, Movable):
    """A fetch operation with its document, as upstream
    `PlanningFetchOperation` and its `SubgraphFetchOperation`."""

    var document: FetchDocument
    """The minified document."""
    var document_str: String
    """The document text that execution sends."""
    var name_write_position: Int
    """Where an operation name can be written into `document_str`."""

    def __init__(out self, var document: FetchDocument, store: Store):
        """Print a document, as upstream `from_anonymous_operation`.

        Args:
            document: The minified document.
            store: The store with the selections.
        """
        self.document_str = document.text(store)
        self.name_write_position = 0
        var keywords: List[StaticString] = ["query", "mutation", "subscription"]
        var index = 0
        while index < len(keywords):
            var keyword = keywords[index]
            index += 1
            if self.document_str.startswith(keyword):
                var rest = self.document_str[byte = keyword.byte_length() :]
                if rest.startswith("(") or rest.startswith("{"):
                    self.name_write_position = keyword.byte_length()
                    break
        self.document = document^

    def pretty(self, store: Store, mut out: String, depth: Int):
        """Write the operation as upstream `PrettyDisplay` of
        `PlanningFetchOperation`.

        Args:
            store: The store with the selections.
            out: The destination.
            depth: The indentation depth.
        """
        ref operation = self.document.operation
        var representationless = List[Int]()
        for index in range(len(operation.variables)):
            if (
                store.name(operation.variables[index].variable_type.name)
                != "_Any"
            ):
                representationless.append(index)
        var has_variables = len(operation.variables) > 0 and len(
            representationless
        ) == len(operation.variables)
        write_indent(out, depth)
        out += "  "
        if operation.kind == OperationKind.QUERY:
            if has_variables:
                out += "query "
        elif operation.kind == OperationKind.MUTATION:
            out += "mutation "
        else:
            out += "subscription "
        if len(representationless) > 0:
            out += "("
            operation.variables[representationless[0]].write(store, out)
            var index = 1
            while index < len(representationless):
                out += ","
                operation.variables[representationless[index]].write(store, out)
                index += 1
            out += ") "
        out += "{\n"
        pretty_set(
            store, out, inner_selection_set(store, self.document), depth + 2
        )
        write_indent(out, depth)
        out += "  }\n"
        for fragment in self.document.fragments:
            fragment.pretty(store, out, depth)

    def pretty_executable(self, mut out: String, depth: Int):
        """Write the operation as upstream `PrettyDisplay` of
        `SubgraphFetchOperation`: the document text on one line.

        Args:
            out: The destination.
            depth: The indentation depth.
        """
        write_indent(out, depth)
        out += "  "
        out += self.document_str
        out += "\n"


def inline_fragment_spreads(
    mut store: Store, set: Int, fragments: List[FragmentDefinition]
) raises -> Int:
    """Return a copy of a set with every spread replaced by an inline
    fragment, as upstream `inline_fragment_spreads`.

    Args:
        store: The store.
        set: The set; any item with children works.
        fragments: The fragments a spread can name.

    Returns:
        A new `ROOT` set.

    Raises:
        Error: `Could not find fragment definition 'name'` for an unknown
            fragment, or `Detected cycle while expanding fragment spread
            'name'` for a cycle.
    """
    var visiting = List[Int]()
    var out = store.new_set()
    _inline_into(store, set, out, fragments, visiting)
    return out


def _inline_into(
    mut store: Store,
    set: Int,
    target: Int,
    fragments: List[FragmentDefinition],
    mut visiting: List[Int],
) raises:
    """Append the expanded children of `set` to `target`."""
    for child in store.children(set):
        var found = store.items[child]
        if found.kind == ItemKind.SPREAD:
            for name in visiting:
                if name == found.name:
                    raise Error(
                        "Detected cycle while expanding fragment spread '"
                        + store.name(found.name)
                        + "'"
                    )
            var definition = NONE
            for index in range(len(fragments)):
                if fragments[index].name == found.name:
                    definition = index
                    break
            if definition == NONE:
                raise Error(
                    "Could not find fragment definition '"
                    + store.name(found.name)
                    + "'"
                )
            visiting.append(found.name)
            var fragment = store.add_item(
                ItemKind.FRAGMENT, fragments[definition].type_condition
            )
            _inline_into(
                store,
                fragments[definition].selection_set,
                fragment,
                fragments,
                visiting,
            )
            _ = visiting.pop()
            store.append(target, fragment)
            continue
        var copy = store.add_item(
            found.kind,
            found.name,
            found.alias,
            found.args,
            found.skip,
            found.include,
            found.omit,
        )
        store.items[copy].directives = found.directives
        _inline_into(store, child, copy, fragments, visiting)
        store.append(target, copy)
