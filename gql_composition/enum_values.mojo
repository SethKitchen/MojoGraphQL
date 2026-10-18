# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Enum values must merge to a usable type.

Port of `EnumValuesRule` of Hive Federation Composition v0.27.0
`src/supergraph/validation/rules/enum-values-rule.ts`.

An enum used as both an input and an output must define each value in
every subgraph that defines the enum, unless the value is
`@inaccessible`. An enum used only as an input must keep at least one
value that every subgraph defines.
"""

from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.later_versions import GraphFacts
from gql_composition.merged import contains, subgraph_place, type_names
from gql_composition.state import TypeKind


@fieldwise_init
struct _Value(Movable):
    """One enum value and the subgraphs that define it."""

    var name: String
    """The value name."""
    var graphs: List[String]
    """The subgraph names, in id order."""
    var hidden: Bool
    """Whether any subgraph marks the value `@inaccessible`."""


def check_enum_values(
    facts: List[GraphFacts], mut found: List[String]
) -> List[CompositionError]:
    """Report enum values that cannot merge.

    Args:
        facts: The subgraphs, in id order, after a clean subgraph phase.
        found: Receives the enum name for each error, in the same order.

    Returns:
        The `ENUM_VALUE_MISMATCH` and `EMPTY_MERGED_ENUM_TYPE` errors,
        in first-seen enum order.
    """
    var names = type_names(facts, TypeKind.ENUM)
    var errors = List[CompositionError]()
    for name_index in range(len(names)):
        var name = String(names[name_index])
        _check_one(facts, name, errors, found)
    return errors^


def _check_one(
    facts: List[GraphFacts],
    name: String,
    mut errors: List[CompositionError],
    mut found: List[String],
):
    """Append the errors for one enum.

    Args:
        facts: The subgraphs, in id order.
        name: The enum name.
        errors: The errors to append.
        found: Receives the enum name for each error.
    """
    var graphs = List[String]()
    var values = List[_Value]()
    var input = False
    var output = False
    var input_example = String("")
    var output_example = String("")
    # The enum comes from a subgraph, so `facts` is not empty.
    var graph_index = 0
    while graph_index < len(facts):
        ref graph = facts[graph_index]
        graph_index += 1
        var found_type = graph.find_kind(name, TypeKind.ENUM)
        if found_type == -1:
            continue
        ref type = graph.types[found_type]
        graphs.append(String(graph.graph_name))
        if len(type.input_refs) > 0:
            input = True
            if input_example.byte_length() == 0:
                input_example = String(type.input_refs[0])
        if len(type.output_refs) > 0:
            output = True
            if output_example.byte_length() == 0:
                output_example = String(type.output_refs[0])
        # The subgraph phase refuses an enum without values.
        var value_index = 0
        while value_index < len(type.values):
            _add_value(
                values,
                type.values[value_index],
                graph.graph_name,
                type.value_hidden[value_index],
            )
            value_index += 1
    if input and output:
        _mismatches(
            errors,
            found,
            name,
            graphs,
            values,
            input_example,
            output_example,
        )
    elif input:
        _empty(errors, found, name, graphs, values)


def _mismatches(
    mut errors: List[CompositionError],
    mut found: List[String],
    name: String,
    graphs: List[String],
    values: List[_Value],
    input_example: String,
    output_example: String,
):
    """Append one error for each value missing from a subgraph.

    Args:
        errors: The errors to append.
        found: Receives the enum name for each error.
        name: The enum name.
        graphs: The subgraphs that define the enum, in id order.
        values: The values, in first-seen order.
        input_example: A coordinate that uses the enum as an input.
        output_example: A coordinate that uses the enum as an output.
    """
    # The subgraph phase refuses an enum without values.
    var value_index = 0
    while value_index < len(values):
        ref value = values[value_index]
        value_index += 1
        if len(value.graphs) == len(graphs) or value.hidden:
            continue
        var absent = _absent(graphs, value.graphs)
        found.append(String(name))
        errors.append(
            CompositionError(
                'Enum type "'
                + name
                + '" is used as both input type (for example, as type of "'
                + input_example
                + '") and output type (for example, as type of "'
                + output_example
                + '"), but value "'
                + value.name
                + '" is not defined in all the subgraphs defining "'
                + name
                + '": "'
                + value.name
                + '" is defined in '
                + subgraph_place(value.graphs)
                + " but not in "
                + subgraph_place(absent),
                ErrorCode.ENUM_VALUE_MISMATCH,
                None,
            )
        )


def _empty(
    mut errors: List[CompositionError],
    mut found: List[String],
    name: String,
    graphs: List[String],
    values: List[_Value],
):
    """Append an error when an input enum would merge to no values.

    Args:
        errors: The errors to append.
        found: Receives the enum name when an error is appended.
        name: The enum name.
        graphs: The subgraphs that define the enum.
        values: The values, in first-seen order.
    """
    var total = len(graphs)
    # The subgraph phase refuses an enum without values.
    var value_index = 0
    while value_index < len(values):
        if len(values[value_index].graphs) == total:
            return
        value_index += 1
    found.append(String(name))
    errors.append(
        CompositionError(
            'None of the values of enum type "'
            + name
            + '" are defined consistently in all the subgraphs defining'
            + " that type. As only values common to all subgraphs are"
            + " merged, this would result in an empty type.",
            ErrorCode.EMPTY_MERGED_ENUM_TYPE,
            None,
        )
    )


def _add_value(
    mut values: List[_Value], name: String, graph_name: String, hidden: Bool
):
    """Record that a subgraph defines an enum value.

    Args:
        values: The values so far.
        name: The value name.
        graph_name: The subgraph name.
        hidden: Whether this subgraph marks the value `@inaccessible`.
    """
    for index in range(len(values)):
        if values[index].name != name:
            continue
        values[index].graphs.append(String(graph_name))
        if hidden:
            values[index].hidden = True
        return
    var graphs = List[String]()
    graphs.append(String(graph_name))
    values.append(_Value(String(name), graphs^, hidden))


def _absent(graphs: List[String], present: List[String]) -> List[String]:
    """Return the enum's subgraphs that do not define a value.

    Args:
        graphs: The subgraphs that define the enum, in id order.
        present: The subgraphs that define the value.

    Returns:
        The missing subgraph names, in id order.
    """
    var names = List[String]()
    # The caller reports a value that some subgraph of the enum omits.
    var graph_index = 0
    while graph_index < len(graphs):
        if not contains(present, graphs[graph_index]):
            names.append(graphs[graph_index])
        graph_index += 1
    return names^
