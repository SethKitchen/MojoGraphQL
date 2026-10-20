# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Variable remapping: graphql-go-tools v2 `astnormalization`
`variables_mapper.go` and `variables_mapping.go`.

`VariablesMapper` gives the variables of an operation sequential names, in
the order of their first use in an argument: `a`, `b`, ..., `z`, then `aa`,
`bb`, ..., `zz`, then `aaa`, and so on. Then it sorts the variable
definitions by name. Two operations of the same shape get the same text,
also when their variable names or the order of their definitions differ.

The mapper changes only the variables that an argument in the operation uses
directly. It does not change a variable that a fragment definition uses, or
a variable of the `Upload` type, because the file upload specification needs
the original name. The result maps each new name to the old name.

Run the mapper after the normalization with `extract_variables`, so that
each inline argument value is a variable.

Differences from upstream:

- A document without an operation does not change. Upstream sorts the
  variable definitions of the operation at index 0, and panics.
- The result is a `Dict` that does not raise. Upstream returns nil for an
  error of its walker, and the walker of the mapper reports no error.
"""

from std.collections import Dict

from gql_language.ast import Document, FLAG_EXTRA, Kind, NO_NODE, Role
from gql_schema.definition import Schema


struct _VariableItem(Copyable, Movable):
    """A variable and its uses: upstream `variableItem`."""

    var variable_name: String
    """The old name of the variable."""
    var value_refs: List[Int]
    """The `Variable` node of each use, in walk order."""
    var variable_definition_ref: Int
    """The `VariableDefinition` node."""

    def __init__(out self, name: String, value: Int, definition: Int):
        """Make the item of the first use of a variable.

        Args:
            name: The old name of the variable.
            value: The `Variable` node of the use.
            definition: The `VariableDefinition` node.
        """
        self.variable_name = name
        self.value_refs = [value]
        self.variable_definition_ref = definition


def _definition_named(
    document: Document, operation: Int, name: StringSlice
) -> Int:
    """Return the variable definition of an operation with a name, or
    `NO_NODE`: `VariableDefinitionByNameAndOperation`."""
    var variable = document.child(operation, Role.VARIABLE_DEFINITION)
    while variable != NO_NODE:
        if document.name(document.child(variable, Role.VARIABLE)) == name:
            return variable
        variable = document.next_with_role(variable)
    return NO_NODE


def _enter_argument(
    document: Document,
    operation: Int,
    argument: Int,
    mut items: List[_VariableItem],
):
    """Note a use of a variable as an argument value: `EnterArgument`."""
    var value = document.child(argument, Role.VALUE)
    if document.kind(value) != Kind.VARIABLE:
        return
    var name = document.name(value)
    var definition = _definition_named(document, operation, name)
    if definition == NO_NODE:
        return
    if document.named_type(document.child(definition, Role.TYPE)) == "Upload":
        # The file upload specification needs the original name.
        return
    var index = 0
    while index < len(items):
        if items[index].variable_name == name:
            items[index].value_refs.append(value)
            return
        index += 1
    items.append(_VariableItem(String(name), value, definition))


def _walk(
    document: Document,
    operation: Int,
    node: Int,
    mut items: List[_VariableItem],
):
    """Visit each argument under a node of an operation, in walk order."""
    var child = document.first_child(node)
    while child != NO_NODE:
        if document.kind(child) == Kind.ARGUMENT:
            _enter_argument(document, operation, child, items)
        else:
            _walk(document, operation, child, items)
        child = document.next_sibling(child)


def _rename(mut document: Document, variable: Int, start: Int, end: Int):
    """Point the name of a `Variable` node at new text."""
    var name = document.child(variable, Role.NAME)
    document.nodes[name].start = Int32(start)
    document.nodes[name].end = Int32(end)
    document.nodes[name].flags |= FLAG_EXTRA


def _definition_name(document: Document, definition: Int) -> String:
    """Return the variable name of a `VariableDefinition` node."""
    return String(document.name(document.child(definition, Role.VARIABLE)))


def _sort_definitions(mut document: Document, operation: Int):
    """Sort the variable definitions of an operation by name, and keep the
    other children in place."""
    var sorted = document.children(operation, Role.VARIABLE_DEFINITION)
    var index = 1
    while index < len(sorted):
        var moving = sorted[index]
        var name = _definition_name(document, moving)
        var place = index
        while place > 0 and name < _definition_name(
            document, sorted[place - 1]
        ):
            sorted[place] = sorted[place - 1]
            place -= 1
        sorted[place] = moving
        index += 1
    var order = List[Int]()
    var next_definition = 0
    var child = document.first_child(operation)
    while child != NO_NODE:
        if document.role(child) == Role.VARIABLE_DEFINITION:
            order.append(sorted[next_definition])
            next_definition += 1
        else:
            order.append(child)
        child = document.next_sibling(child)
    # An operation has a selection set, so `order` is not empty.
    document.nodes[operation].first = Int32(order[0])
    index = 1
    while index < len(order):
        document.nodes[order[index - 1]].next = Int32(order[index])
        index += 1
    document.nodes[order[len(order) - 1]].next = Int32(NO_NODE)
    document.nodes[operation].last = Int32(order[len(order) - 1])


def mapping_name(index: Int) -> String:
    """Returns the generated variable name at a position.

    It is `generateUnusedVariableMappingName` for a mapping that holds the
    names of the positions before `index`: the letter `index % 26`, `index /
    26 + 1` times.

    Args:
        index: The zero-based position of the variable.

    Returns:
        The name, such as `a`, `z`, `aa` or `bbb`.
    """
    var letter = String(chr(ord("a") + index % 26))
    var out = String()
    var count = index // 26 + 1
    while count > 0:
        out += letter
        count -= 1
    return out^


struct VariablesMapper(Copyable, Movable):
    """Gives the variables of an operation sequential names: upstream
    `VariablesMapper`."""

    def __init__(out self):
        """Make the mapper of `NewVariablesMapper`."""
        pass

    def normalize_operation(
        self, mut operation: Document, schema: Schema
    ) -> Dict[String, String]:
        """Rename the variables of the operations, and sort the variable
        definitions of the last operation by name: `NormalizeOperation`.

        A variable keeps its first position in walk order. Each argument
        of each operation counts, in the variable definitions, in the
        directives and in the selections. An argument in a fragment
        definition does not count. The uses of a variable in the operations
        share one item, so a variable with one name in two operations gets
        one new name.

        Args:
            operation: The operation document, changed in place.
            schema: The schema. The mapper does not read it.

        Returns:
            The old name of each variable by its new name.
        """
        var items = List[_VariableItem]()
        var last = NO_NODE
        var definition = operation.first_child(operation.root)
        while definition != NO_NODE:
            if operation.kind(definition) == Kind.OPERATION_DEFINITION:
                last = definition
                _walk(operation, definition, definition, items)
            definition = operation.next_sibling(definition)
        var mapping = Dict[String, String]()
        var index = 0
        while index < len(items):
            var name = mapping_name(index)
            mapping[name] = items[index].variable_name
            var start = len(operation.source.bytes)
            operation.source.bytes.extend(name.as_bytes())
            var end = len(operation.source.bytes)
            var use = 0
            while use < len(items[index].value_refs):
                _rename(operation, items[index].value_refs[use], start, end)
                use += 1
            _rename(
                operation,
                operation.child(
                    items[index].variable_definition_ref, Role.VARIABLE
                ),
                start,
                end,
            )
            index += 1
        if last != NO_NODE:
            _sort_definitions(operation, last)
        return mapping^
