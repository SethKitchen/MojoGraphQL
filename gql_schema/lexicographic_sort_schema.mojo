# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Sort a schema by name: its types, fields, arguments, input fields, enum
values, interfaces, union members, directives and directive locations.

Port of graphql-js 16.14.2 `utilities/lexicographicSortSchema.ts`. The
names are sorted in natural order, as graphql-js `naturalCompare` sorts
them. The specified scalars and the introspection types keep their order,
as in graphql-js.

graphql-js gives the sorted types to the `GraphQLSchema` constructor. That
constructor removes each type from its set and adds it again, so the type
map of the result is in name order too; this port sorts the type map
directly. The objects and interfaces that implement an interface are kept
in type map order, which is now name order.

**Differences from upstream.**

- A `Schema` is a value: the result is a copy with new lists of fields,
  input values, enum values and type lists, and new name tables. A type
  keeps its index in `types`, so a `TypeRef` stays valid.
- A directive's locations are read from its definition node, for
  `print_schema` and for introspection. So the location names of each
  definition node are put in sorted order, in the copy of the document
  that the sorted schema holds. In graphql-js the `astNode` keeps its order
  and only `locations` is sorted.
"""

from gql_language.ast import Document, Role
from gql_schema.definition import (
    HASHED_MEMBERS,
    DirectiveDef,
    EnumValueDef,
    FieldDef,
    InputValueDef,
    Range,
    Schema,
)
from gql_language.names import NameTable
from gql_schema.suggestions import natural_compare


def _sorted_positions(names: List[String]) -> List[Int]:
    """Return the positions of names in natural order; a stable merge sort,
    as JavaScript `Array.prototype.sort` is stable."""
    var count = len(names)
    var order = List[Int](capacity=count)
    var index = 0
    while index < count:
        order.append(index)
        index += 1
    var buffer = order.copy()
    var width = 1
    while width < count:
        var low = 0
        while low < count:
            var middle = min(low + width, count)
            var high = min(low + 2 * width, count)
            var left = low
            var right = middle
            var at = low
            while at < high:
                if right >= high or (
                    left < middle
                    and natural_compare(names[order[left]], names[order[right]])
                    <= 0
                ):
                    buffer[at] = order[left]
                    left += 1
                else:
                    buffer[at] = order[right]
                    right += 1
                at += 1
            low = high
        swap(order, buffer)
        width *= 2
    return order^


def _order(names: List[String], sort: Bool) -> List[Int]:
    """Return the positions of names, sorted or in their own order."""
    if sort:
        return _sorted_positions(names)
    var order = List[Int](capacity=len(names))
    var index = 0
    while index < len(names):
        order.append(index)
        index += 1
    return order^


struct _Sorter:
    """The schema being sorted, and the lists and name tables of the
    result."""

    var fields: List[FieldDef]
    var input_values: List[InputValueDef]
    var enum_values: List[EnumValueDef]
    var type_lists: List[Int32]
    var member_names: NameTable
    var argument_names: NameTable

    def __init__(out self, schema: Schema):
        """Start empty lists, with room for every entry of the schema."""
        self.fields = List[FieldDef](capacity=len(schema.fields))
        self.input_values = List[InputValueDef](
            capacity=len(schema.input_values)
        )
        self.enum_values = List[EnumValueDef](capacity=len(schema.enum_values))
        self.type_lists = List[Int32](capacity=len(schema.type_lists))
        self.member_names = NameTable()
        self.argument_names = NameTable()

    def input_values_of(
        mut self,
        schema: Schema,
        span: Range,
        sort: Bool,
        key: Int,
        by_argument: Bool,
    ) -> Range:
        """Copy a run of arguments or input fields; return the new run."""
        var names = List[String](capacity=Int(span.count))
        var index = Int(span.start)
        while index < span.end():
            names.append(schema.input_values[index].name)
            index += 1
        var start = len(self.input_values)
        var hashed = Int(span.count) >= HASHED_MEMBERS
        for position in _order(names, sort):
            var member = len(self.input_values)
            self.input_values.append(
                schema.input_values[Int(span.start) + position].copy()
            )
            if hashed:
                if by_argument:
                    self.argument_names.assign(key, names[position], member)
                else:
                    self.member_names.assign(key, names[position], member)
        return Range(Int32(start), span.count)

    def fields_of(
        mut self, schema: Schema, span: Range, sort: Bool, type: Int
    ) -> Range:
        """Copy a run of fields, each with its arguments; return the new
        run."""
        var names = List[String](capacity=Int(span.count))
        var index = Int(span.start)
        while index < span.end():
            names.append(schema.fields[index].name)
            index += 1
        var start = len(self.fields)
        var hashed = Int(span.count) >= HASHED_MEMBERS
        for position in _order(names, sort):
            var member = len(self.fields)
            var field = schema.fields[Int(span.start) + position].copy()
            field.arguments = self.input_values_of(
                schema, field.arguments, sort, member, True
            )
            self.fields.append(field^)
            if hashed:
                self.member_names.assign(type, names[position], member)
        return Range(Int32(start), span.count)

    def enum_values_of(
        mut self, schema: Schema, span: Range, sort: Bool, type: Int
    ) -> Range:
        """Copy a run of enum values; return the new run."""
        var names = List[String](capacity=Int(span.count))
        var index = Int(span.start)
        while index < span.end():
            names.append(schema.enum_values[index].name)
            index += 1
        var start = len(self.enum_values)
        var hashed = Int(span.count) >= HASHED_MEMBERS
        for position in _order(names, sort):
            var member = len(self.enum_values)
            self.enum_values.append(
                schema.enum_values[Int(span.start) + position].copy()
            )
            if hashed:
                self.member_names.assign(type, names[position], member)
        return Range(Int32(start), span.count)

    def type_list_of(
        mut self, schema: Schema, span: Range, sort: Bool
    ) -> Range:
        """Copy a run of type indices; return the new run."""
        var names = List[String](capacity=Int(span.count))
        var index = Int(span.start)
        while index < span.end():
            names.append(schema.types[Int(schema.type_lists[index])].name)
            index += 1
        var start = len(self.type_lists)
        for position in _order(names, sort):
            self.type_lists.append(
                schema.type_lists[Int(span.start) + position]
            )
        return Range(Int32(start), span.count)


def _sort_locations(mut document: Document, node: Int):
    """Put the location names of a directive definition in natural order:
    each location node takes the text range of the name that sorts into
    its place."""
    var locations = document.children(node, Role.LOCATION)
    var names = List[String](capacity=len(locations))
    var starts = List[Int32](capacity=len(locations))
    var ends = List[Int32](capacity=len(locations))
    var index = 0
    while index < len(locations):
        names.append(String(document.text(locations[index])))
        starts.append(document.nodes[locations[index]].start)
        ends.append(document.nodes[locations[index]].end)
        index += 1
    var order = _sorted_positions(names)
    index = 0
    while index < len(locations):
        document.nodes[locations[index]].start = starts[order[index]]
        document.nodes[locations[index]].end = ends[order[index]]
        index += 1


def lexicographic_sort_schema(schema: Schema) -> Schema:
    """Return a copy of a schema with everything in it sorted by name, as
    graphql-js `lexicographicSortSchema`.

    Args:
        schema: The schema to sort.

    Returns:
        A new schema. Its type map, the fields, arguments, input fields,
        enum values, interfaces and members of each type that is not
        built in, its directives, their arguments and their locations are
        in natural name order.
    """
    var out = schema.copy()
    var sorter = _Sorter(schema)
    var type = 0
    while type < len(schema.types):
        ref named = schema.types[type]
        # The specified scalars and the introspection types stay as they
        # are, as graphql-js returns them unchanged.
        var sort = not named.is_builtin
        out.types[type].fields = sorter.fields_of(
            schema, named.fields, sort, type
        )
        out.types[type].input_fields = sorter.input_values_of(
            schema, named.input_fields, sort, type, False
        )
        out.types[type].enum_values = sorter.enum_values_of(
            schema, named.enum_values, sort, type
        )
        out.types[type].interfaces = sorter.type_list_of(
            schema, named.interfaces, sort
        )
        out.types[type].members = sorter.type_list_of(
            schema, named.members, sort
        )
        # Implementations are in type map order, which is name order now.
        out.implementing_objects[type] = sorter.type_list_of(
            schema, schema.implementing_objects[type], True
        )
        out.implementing_interfaces[type] = sorter.type_list_of(
            schema, schema.implementing_interfaces[type], True
        )
        type += 1

    var type_names = List[String](capacity=len(schema.type_map))
    var position = 0
    while position < len(schema.type_map):
        type_names.append(schema.types[Int(schema.type_map[position])].name)
        position += 1
    var type_order = _sorted_positions(type_names)
    out.type_map = List[Int32](capacity=len(schema.type_map))
    position = 0
    while position < len(type_order):
        out.type_map.append(schema.type_map[type_order[position]])
        position += 1

    var directive_names = List[String](capacity=len(schema.directives))
    position = 0
    while position < len(schema.directives):
        directive_names.append(schema.directives[position].name)
        position += 1
    out.directives = List[DirectiveDef](capacity=len(schema.directives))
    out._directive_names = NameTable()
    var directive_order = _sorted_positions(directive_names)
    var index = 0
    while index < len(directive_order):
        var directive = schema.directives[directive_order[index]].copy()
        directive.arguments = sorter.input_values_of(
            schema, directive.arguments, True, -2 - index, True
        )
        ref definition = directive.definition
        _sort_locations(
            out.documents[Int(definition.document)], Int(definition.node)
        )
        out.directives.append(directive^)
        _ = out.register_directive_name(index)
        index += 1

    swap(out.fields, sorter.fields)
    swap(out.input_values, sorter.input_values)
    swap(out.enum_values, sorter.enum_values)
    swap(out.type_lists, sorter.type_lists)
    swap(out._member_names, sorter.member_names)
    swap(out._argument_names, sorter.argument_names)
    return out^
