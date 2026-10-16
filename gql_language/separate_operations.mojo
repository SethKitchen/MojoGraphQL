# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Split a document into one document for each operation.

Port of graphql-js 16.14.2 `utilities/separateOperations.ts`. Each new
document has one operation and the fragment definitions that it uses, also
through other fragments, in the order of the original document.

**Differences from upstream.**

- graphql-js returns an object that maps each operation name to its
  document. This port returns a list of `OperationDocument`, in the order
  of the object's keys. As for the object, a second operation with the
  same name replaces the document of the first, in the first one's place.
- graphql-js puts the same definition objects in the new documents. A
  `Document` is one arena, so this port copies each definition. The copies
  have no source locations.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role


struct OperationDocument(Copyable, Movable):
    """One operation of a document, with the fragments that it uses."""

    var name: String
    """The operation's name; empty for an anonymous operation."""
    var document: Document
    """The operation and its fragment definitions, in source order."""

    def __init__(out self, var name: String, var document: Document):
        """Hold an operation's name and document.

        Args:
            name: The operation's name, or empty.
            document: The document of the operation.
        """
        self.name = name^
        self.document = document^


def _collect_dependencies(document: Document, node: Int) -> List[String]:
    """Return the names of the fragment spreads in a selection set, in
    preorder, as graphql-js `collectDependencies` visits them."""
    var names = List[String]()
    var stack: List[Int] = [node]
    while len(stack) > 0:
        var current = stack.pop()
        if document.kind(current) == Kind.FRAGMENT_SPREAD:
            names.append(String(document.name(current)))
        # The children are pushed last first, so they are visited in order.
        var children = List[Int]()
        var child = document.first_child(current)
        while child != NO_NODE:
            children.append(child)
            child = document.next_sibling(child)
        var index = len(children) - 1
        while index >= 0:
            stack.append(children[index])
            index -= 1
    return names^


def separate_operations(document: Document) -> List[OperationDocument]:
    """Return one document for each operation of a document, as graphql-js
    `separateOperations`.

    Args:
        document: A document with operations and fragment definitions.
            Definitions that are not executable are ignored.

    Returns:
        An operation name, empty for an anonymous operation, and its
        document, for each operation name in order of first use.
    """
    var operations = List[Int]()
    var dependency_graph = Dict[String, List[String]]()
    var definition = document.first_child(document.root)
    while definition != NO_NODE:
        var kind = document.kind(definition)
        if kind == Kind.OPERATION_DEFINITION:
            operations.append(definition)
        elif kind == Kind.FRAGMENT_DEFINITION:
            dependency_graph[
                String(document.name(definition))
            ] = _collect_dependencies(
                document, document.child(definition, Role.SELECTION_SET)
            )
        definition = document.next_sibling(definition)

    var out = List[OperationDocument]()
    for operation in operations:
        # Every fragment the operation uses, directly or through another.
        var dependencies = Dict[String, Bool]()
        var pending = _collect_dependencies(
            document, document.child(operation, Role.SELECTION_SET)
        )
        while len(pending) > 0:
            var name = pending.pop()
            if name in dependencies:
                continue
            dependencies[name] = True
            var found = dependency_graph.get(name)
            if found:
                pending.extend(found.value().copy())
        var separated = Document()
        var current = document.first_child(document.root)
        while current != NO_NODE:
            if current == operation or (
                document.kind(current) == Kind.FRAGMENT_DEFINITION
                and String(document.name(current)) in dependencies
            ):
                separated.append_child(
                    separated.root,
                    separated.copy_subtree(document, current, Role.DEFINITION),
                )
            current = document.next_sibling(current)
        var name = String(document.name(operation))
        var index = 0
        while index < len(out) and out[index].name != name:
            index += 1
        if index < len(out):
            out[index].document = separated^
        else:
            out.append(OperationDocument(name^, separated^))
    return out^
