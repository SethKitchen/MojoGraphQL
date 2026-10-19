# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The state of the rules during one walk of a document.

A graphql-js rule keeps its state in the closure of the function that makes
its visitor. Here each rule is a value, so `Walk` holds the state of every
rule, and the code of each rule takes the `Walk`. A rule's state is used
only by that rule.

A set keyed by a node, such as "the variables that this operation defines",
is one `NameTable` whose owner is the node, so a new operation needs no new
table.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.error import GraphQLError
from gql_schema.definition import NO_TYPE, Schema
from gql_language.names import NOT_FOUND, NameTable
from gql_validation.context import ValidationContext
from gql_validation.overlapping import OverlapState
from gql_validation.rules import ValidationRule


struct Walk(Movable):
    """The validation context and the state of each rule."""

    var ctx: ValidationContext
    """The errors and the caches that the rules share."""
    var overlap: OverlapState
    """The caches of `OverlappingFieldsCanBeMergedRule`."""
    var doc_directives: NameTable
    """The directive definitions of the document, by name; the last
    wins."""
    var defined_types: NameTable
    """The type definitions of the document, by name."""
    var defined_type_names: List[String]
    """The names of `defined_types`, in first-definition order."""
    var operation_names: NameTable
    """`UniqueOperationNamesRule`: the name node of each operation name."""
    var operation_count: Int
    """`LoneAnonymousOperationRule`: how many operations there are."""
    var fragment_names: NameTable
    """`UniqueFragmentNamesRule`: the name node of each fragment name."""
    var operation_defs: List[Int]
    """`NoUnusedFragmentsRule`: the operations, in order."""
    var fragment_defs: List[Int]
    """`NoUnusedFragmentsRule`: the fragments, in order."""
    var visited_fragments: List[Bool]
    """`NoFragmentCyclesRule`: the fragment ids already checked."""
    var spread_path: List[Int]
    """`NoFragmentCyclesRule`: the spreads from the fragment being checked
    down to the current one."""
    var spread_path_index: List[Int]
    """`NoFragmentCyclesRule`: for each fragment id, its place in
    `spread_path`, or -1."""
    var defined_variables: NameTable
    """`NoUndefinedVariablesRule`: the variables of each operation, keyed
    by the operation node."""
    var variable_defs: List[Int]
    """`NoUnusedVariablesRule`: the variable definitions of the current
    operation."""
    var used_variables: NameTable
    """`NoUnusedVariablesRule`: the used variables of each operation."""
    var variable_def_nodes: NameTable
    """`VariablesInAllowedPositionRule`: the definition of each variable,
    keyed by the definition that holds it; the last wins."""
    var seen_directives: NameTable
    """`UniqueDirectivesPerLocationRule`: the first use of a non-repeatable
    directive in each scope."""
    var directive_scopes: NameTable
    """`UniqueDirectivesPerLocationRule`: an id for each type and
    directive name that has a scope."""
    var input_field_names: NameTable
    """`UniqueInputFieldNamesRule`: the first name node of each field,
    keyed by the object value."""
    var in_variable_definition: Int
    """How many variable definitions the walk is in; usages there do not
    count."""

    def __init__(out self, schema: Schema, max_errors: Int):
        """Start the state of a walk.

        Args:
            schema: The schema the document is checked against.
            max_errors: The error limit.
        """
        self.ctx = ValidationContext(schema, max_errors)
        self.overlap = OverlapState()
        self.doc_directives = NameTable()
        self.defined_types = NameTable()
        self.defined_type_names = List[String]()
        self.operation_names = NameTable()
        self.operation_count = 0
        self.fragment_names = NameTable()
        self.operation_defs = List[Int]()
        self.fragment_defs = List[Int]()
        self.visited_fragments = List[Bool]()
        self.spread_path = List[Int]()
        self.spread_path_index = List[Int]()
        self.defined_variables = NameTable()
        self.variable_defs = List[Int]()
        self.used_variables = NameTable()
        self.variable_def_nodes = NameTable()
        self.seen_directives = NameTable()
        self.directive_scopes = NameTable()
        self.input_field_names = NameTable()
        self.in_variable_definition = 0

    def find_definitions(mut self, document: Document):
        """Find the directive and type definitions of the document, which
        some rules read before the walk.

        Args:
            document: The document of the walk.
        """
        var current = document.first_child(document.root)
        while current != NO_NODE:
            var kind = document.kind(current)
            if kind == Kind.DIRECTIVE_DEFINITION:
                self.doc_directives.assign(-1, document.name(current), current)
            elif kind.is_type_definition():
                var name = document.name(current)
                if self.defined_types.insert(-1, name, current):
                    self.defined_type_names.append(String(name))
            current = document.next_sibling(current)

    def doc_directive(self, name: StringSlice) -> Int:
        """Return the document's definition of a directive.

        Args:
            name: The directive name.

        Returns:
            The last `DirectiveDefinition` node with the name, or `NO_NODE`.
        """
        if self.doc_directives.__len__() == 0:
            return NO_NODE
        var found = self.doc_directives.find(-1, name)
        if found == NOT_FOUND:
            return NO_NODE
        return found

    def definition(self) -> Int:
        """Return the top-level definition that holds the current node.

        The walk calls it only below a definition.

        Returns:
            The definition node.
        """
        return self.ctx.path[1]

    def parent(self) -> Int:
        """Return the parent of the current node.

        The walk calls it only below the document node.

        Returns:
            The parent node.
        """
        return self.ctx.path[len(self.ctx.path) - 2]

    def take_errors(deinit self) -> List[GraphQLError]:
        """End the walk and return its errors.

        Returns:
            The errors, in order.
        """
        return self.ctx^.take_errors()
