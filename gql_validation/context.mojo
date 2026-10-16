# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""What the validation rules share during one walk of a document.

Port of graphql-js 16.14.2 `validation/ValidationContext.ts`
(`ASTValidationContext` and `ValidationContext`).

A `ValidationContext` holds the errors, the `TypeInfo` of the walk, the
fragments of the document, and the caches of graphql-js:
`getFragmentSpreads`, `getRecursivelyReferencedFragments`,
`getVariableUsages` and `getRecursiveVariableUsages`. It also holds the
state of each rule, because a rule here is a value, not a closure.

A cache is a list with one slot per node of the document, made the first
time it is used, so a lookup is one load.

**Differences from graphql-js.**

- graphql-js `getVariableUsages` walks the operation or fragment again
  with a new `TypeInfo`. Here the walk of `validate` records the usages of
  each definition as it passes. Only a fragment that is used before its
  definition is walked again. The usages are the same, in the same order.
- `report_error` takes the message and the nodes, and makes the error. The
  error and its source excerpt are the same as graphql-js gives.
- The rules, the schema and the document are not kept in the context: each
  method that needs the document or the schema takes it.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.block_string import utf16_count
from gql_language.error import GraphQLError, print_source_location
from gql_language.source import Source, SourceLocation
from gql_schema.definition import Schema, TypeRef
from gql_schema.names import NOT_FOUND, NameTable
from gql_validation.type_info import TypeInfo

comptime TOO_MANY_ERRORS = (
    "Too many validation errors, error limit reached. Validation aborted."
)
"""The message of the error that ends a validation at `max_errors`."""
comptime _SMALL_SOURCE = 4096
"""A source of at most this many bytes prints its excerpt directly."""


def _unit_offset(source: Source, start: Int, end: Int, units: Int) -> Int:
    """Return the byte offset after the first `units` UTF-16 units of a
    line, or `end` when the line, with its line break, is not longer.

    A character of four bytes is two units, and is not split.
    """
    var data = source.bytes.unsafe_ptr()
    var index = start
    var count = 0
    while index < end:
        var byte = data[unsafe_offset=index]
        if byte == 10 or byte == 13:
            return end
        if count >= units:
            return index
        if byte < 0x80:
            index += 1
            count += 1
        elif byte < 0xE0:
            index += 2
            count += 1
        elif byte < 0xF0:
            index += 3
            count += 1
        else:
            index += 4
            count += 2
    return end


@fieldwise_init
struct VariableUsage(ImplicitlyCopyable, Movable):
    """One use of a variable: graphql-js `VariableUsage`."""

    var node: Int
    """The `Variable` node."""
    var type: TypeRef
    """The input type of the position, or `NO_TYPE_REF`."""
    var default_value: Int
    """The argument or input field whose default value applies at the
    position, or -1; see `TypeInfo.get_default_value`."""
    var parent_type: TypeRef
    """The input type of the value that holds the variable, or
    `NO_TYPE_REF`."""


struct ValidationContext(Movable):
    """The errors, caches and rule state of one validation: graphql-js
    `ValidationContext`."""

    var type_info: TypeInfo
    """The types at the current node of the walk."""
    var errors: List[GraphQLError]
    """The errors reported so far, in order."""
    var max_errors: Int
    """How many errors to keep before the walk stops."""
    var aborted: Bool
    """True once the error limit stopped the walk."""
    var path: List[Int]
    """The nodes from the document root down to the current node."""

    # Fragments, by name. A name gets an id the first time it is seen.
    var _fragment_ids: NameTable
    var _fragment_nodes: List[Int32]
    var _fragments_ready: Bool
    # Caches: one slot per node, made on first use; -1 is no entry.
    var _spread_slots: List[Int32]
    var _spread_lists: List[List[Int32]]
    var _referenced_slots: List[Int32]
    var _referenced_lists: List[List[Int32]]
    var _usage_slots: List[Int32]
    var _usage_lists: List[List[VariableUsage]]
    var _usage_done: List[Bool]
    var _recursive_slots: List[Int32]
    var _recursive_lists: List[List[VariableUsage]]
    var _recording: Int
    var _line_starts: List[Int]

    def __init__(out self, schema: Schema, max_errors: Int = 100):
        """Start a validation.

        Args:
            schema: The schema the document is checked against.
            max_errors: How many errors to keep, as graphql-js `maxErrors`.
        """
        self.type_info = TypeInfo(schema)
        self.errors = List[GraphQLError]()
        self.max_errors = max_errors
        self.aborted = False
        self.path = List[Int](capacity=32)
        self._fragment_ids = NameTable()
        self._fragment_nodes = List[Int32]()
        self._fragments_ready = False
        self._spread_slots = List[Int32]()
        self._spread_lists = List[List[Int32]]()
        self._referenced_slots = List[Int32]()
        self._referenced_lists = List[List[Int32]]()
        self._usage_slots = List[Int32]()
        self._usage_lists = List[List[VariableUsage]]()
        self._usage_done = List[Bool]()
        self._recursive_slots = List[Int32]()
        self._recursive_lists = List[List[VariableUsage]]()
        self._recording = -1
        self._line_starts = List[Int]()

    def take_errors(deinit self) -> List[GraphQLError]:
        """End the validation and return its errors.

        Returns:
            The errors, in order.
        """
        return self.errors^

    # --- errors -------------------------------------------------------------

    def report_error_nodes(
        mut self, document: Document, message: String, nodes: List[Int]
    ):
        """Report an error located at nodes, as graphql-js `reportError`.

        When `max_errors` errors are kept, the error is replaced by `Too
        many validation errors, error limit reached. Validation aborted.`,
        and the validation stops.

        Args:
            document: The document that holds the nodes.
            message: The description.
            nodes: The nodes, in order; their starts are the locations.
        """
        if not self._admit():
            return
        var error = GraphQLError(message)
        var index = 0
        while index < len(nodes):
            var node = nodes[index]
            index += 1
            # A node that a program built has no location, as graphql-js
            # gives none for a node without `loc`.
            if document.start(node) == 0 and document.end(node) == 0:
                continue
            var location = self.location(document, document.start(node))
            error.locations.append(location)
            error.excerpt += "\n\n" + self._excerpt(document, location)
        self.errors.append(error^)

    def report_error(mut self, document: Document, message: String, node: Int):
        """Report an error located at one node.

        Args:
            document: The document that holds the node.
            message: The description.
            node: The node.
        """
        var nodes = List[Int](capacity=1)
        nodes.append(node)
        self.report_error_nodes(document, message, nodes)

    def keep_error(mut self, var error: GraphQLError):
        """Report an error that is already made, as graphql-js
        `reportError(error)`.

        Args:
            error: The error.
        """
        if self._admit():
            self.errors.append(error^)

    def _admit(mut self) -> Bool:
        """Return True when one more error fits; at the limit, add the error
        that ends the validation instead, as graphql-js `onError` does."""
        if self.aborted:
            return False
        if len(self.errors) < self.max_errors:
            return True
        self.errors.append(GraphQLError(String(TOO_MANY_ERRORS)))
        self.aborted = True
        return False

    def location(mut self, document: Document, position: Int) -> SourceLocation:
        """Return the line and column of a byte offset, as
        `Source.get_location` does.

        The first call finds where each line starts, so each later call is
        a binary search.

        Args:
            document: The document whose source holds the offset.
            position: A byte offset into the source body.

        Returns:
            The one-based line and column.
        """
        if len(self._line_starts) == 0:
            self._find_lines(document.source)
        var low = 0
        var high = len(self._line_starts)
        var starts = self._line_starts.unsafe_ptr()
        while high - low > 1:
            var middle = (low + high) // 2
            if starts[unsafe_offset=middle] <= position:
                low = middle
            else:
                high = middle
        var start = starts[unsafe_offset=low]
        var stop = min(position, document.source.length)
        return SourceLocation(
            low + 1,
            1
            + utf16_count(
                Span(document.source.bytes)[start : max(stop, start)]
            ),
        )

    def _find_lines(mut self, source: Source):
        """Record the byte offset where each line of a source starts."""
        self._line_starts.append(0)
        var data = source.bytes.unsafe_ptr()
        var index = 0
        while index < source.length:
            var byte = data[unsafe_offset=index]
            if byte == 10:
                self._line_starts.append(index + 1)
            elif byte == 13:
                if data[unsafe_offset=index + 1] == 10:
                    index += 1
                self._line_starts.append(index + 1)
            index += 1

    def _excerpt(self, document: Document, location: SourceLocation) -> String:
        """Return graphql-js `printSourceLocation` for a location.

        A long source is cut down to the lines around the location first,
        so that each error does not copy the whole source. A line longer
        than 120 UTF-16 units prints as pieces of 80 units, only up to the
        piece after the location, so a long line is cut after that piece.
        """
        ref source = document.source
        if source.length <= _SMALL_SOURCE:
            return print_source_location(source, location)
        var line = location.line - 1
        var line_start = self._line_starts[line]
        var line_end = source.length
        if line + 1 < len(self._line_starts):
            line_end = self._line_starts[line + 1]
        if source.location_offset.column == 1:
            # Keep the pieces up to the one after the location. A piece is
            # 81 units when it keeps a surrogate pair, so keep one more
            # piece of 82: at least 246 units, more than the 120 of a long
            # line.
            var keep = (location.column // 80 + 3) * 82
            var cut = _unit_offset(source, line_start, line_end, keep)
            if cut < line_end:
                var piece = Source(source.slice(line_start, cut), source.name)
                piece.location_offset = SourceLocation(
                    source.location_offset.line + line, 1
                )
                return print_source_location(
                    piece, SourceLocation(1, location.column)
                )
        var first = max(line - 1, 0)
        var stop = source.length
        if line + 2 < len(self._line_starts):
            stop = self._line_starts[line + 2]
        var part = Source(
            source.slice(self._line_starts[first], stop), source.name
        )
        part.location_offset = SourceLocation(
            source.location_offset.line + first,
            source.location_offset.column if first == 0 else 1,
        )
        return print_source_location(
            part, SourceLocation(location.line - first, location.column)
        )

    # --- fragments ----------------------------------------------------------

    def fragment_id(mut self, name: StringSlice) -> Int:
        """Return the id of a fragment name, as a small number.

        Args:
            name: The fragment name.

        Returns:
            The same id for the same name, from 0 up.
        """
        var found = self._fragment_ids.find_or_insert(
            -1, name, len(self._fragment_nodes)
        )
        if found != NOT_FOUND:
            return found
        self._fragment_nodes.append(Int32(NO_NODE))
        return len(self._fragment_nodes) - 1

    def _load_fragments(mut self, document: Document):
        """Find the fragment definitions; the last one with a name wins."""
        self._fragments_ready = True
        var current = document.first_child(document.root)
        while current != NO_NODE:
            if document.kind(current) == Kind.FRAGMENT_DEFINITION:
                var id = self.fragment_id(document.name(current))
                self._fragment_nodes[id] = Int32(current)
            current = document.next_sibling(current)

    def fragment_by_id(mut self, document: Document, id: Int) -> Int:
        """Return the definition of a fragment id.

        Args:
            document: The document of the walk.
            id: A fragment id from `fragment_id`.

        Returns:
            The last `FragmentDefinition` node with the name, or `NO_NODE`.
        """
        if not self._fragments_ready:
            self._load_fragments(document)
        return Int(self._fragment_nodes[id])

    def get_fragment(mut self, document: Document, name: StringSlice) -> Int:
        """Return the fragment with a name, as graphql-js `getFragment`.

        Args:
            document: The document of the walk.
            name: The fragment name.

        Returns:
            The last `FragmentDefinition` node with the name, or `NO_NODE`.
        """
        if not self._fragments_ready:
            self._load_fragments(document)
        var found = self._fragment_ids.find(-1, name)
        if found == NOT_FOUND:
            return NO_NODE
        return Int(self._fragment_nodes[found])

    def spreads_index(mut self, document: Document, selection_set: Int) -> Int:
        """Return where the spreads of a selection set are cached.

        Args:
            document: The document of the walk.
            selection_set: A `SelectionSet` node.

        Returns:
            An index into the spread lists; see `get_fragment_spreads`.
        """
        if len(self._spread_slots) == 0:
            self._spread_slots = List[Int32](
                length=len(document.nodes), fill=-1
            )
        var slot = Int(self._spread_slots[selection_set])
        if slot >= 0:
            return slot
        var spreads = List[Int32]()
        var sets: List[Int] = [selection_set]
        while len(sets) > 0:
            var set = sets.pop()
            var selection = document.child(set, Role.SELECTION)
            while selection != NO_NODE:
                if document.kind(selection) == Kind.FRAGMENT_SPREAD:
                    spreads.append(Int32(selection))
                else:
                    var inner = document.child(selection, Role.SELECTION_SET)
                    if inner != NO_NODE:
                        sets.append(inner)
                selection = document.next_with_role(selection)
        slot = len(self._spread_lists)
        self._spread_lists.append(spreads^)
        self._spread_slots[selection_set] = Int32(slot)
        return slot

    def get_fragment_spreads(
        mut self, document: Document, selection_set: Int
    ) -> List[Int]:
        """Return the fragment spreads in a selection set and the sets
        inside it, as graphql-js `getFragmentSpreads`.

        Args:
            document: The document of the walk.
            selection_set: A `SelectionSet` node.

        Returns:
            The `FragmentSpread` nodes, in the graphql-js order.
        """
        var slot = self.spreads_index(document, selection_set)
        var out = List[Int]()
        for spread in self._spread_lists[slot]:
            out.append(Int(spread))
        return out^

    def referenced_index(mut self, document: Document, operation: Int) -> Int:
        """Return where the fragments an operation uses are cached.

        Args:
            document: The document of the walk.
            operation: An `OperationDefinition` node.

        Returns:
            An index into the fragment lists; see
            `get_recursively_referenced_fragments`.
        """
        if len(self._referenced_slots) == 0:
            self._referenced_slots = List[Int32](
                length=len(document.nodes), fill=-1
            )
        var slot = Int(self._referenced_slots[operation])
        if slot >= 0:
            return slot
        var fragments = List[Int32]()
        var collected = List[Bool]()
        var nodes: List[Int] = [document.child(operation, Role.SELECTION_SET)]
        while len(nodes) > 0:
            var spreads = self.spreads_index(document, nodes.pop())
            var index = 0
            while index < len(self._spread_lists[spreads]):
                var spread = Int(self._spread_lists[spreads][index])
                index += 1
                var id = self.fragment_id(document.name(spread))
                while len(collected) <= id:
                    collected.append(False)
                if collected[id]:
                    continue
                collected[id] = True
                var fragment = self.fragment_by_id(document, id)
                if fragment != NO_NODE:
                    fragments.append(Int32(fragment))
                    nodes.append(document.child(fragment, Role.SELECTION_SET))
        slot = len(self._referenced_lists)
        self._referenced_lists.append(fragments^)
        self._referenced_slots[operation] = Int32(slot)
        return slot

    def get_recursively_referenced_fragments(
        mut self, document: Document, operation: Int
    ) -> List[Int]:
        """Return the fragments an operation uses, directly or through other
        fragments, as graphql-js `getRecursivelyReferencedFragments`.

        Args:
            document: The document of the walk.
            operation: An `OperationDefinition` node.

        Returns:
            The `FragmentDefinition` nodes, in the graphql-js order.
        """
        var slot = self.referenced_index(document, operation)
        var out = List[Int]()
        for fragment in self._referenced_lists[slot]:
            out.append(Int(fragment))
        return out^

    # --- variable usages ----------------------------------------------------

    def _usage_slot(mut self, document: Document, definition: Int) -> Int:
        """Return the usage list of a definition, made when missing."""
        if len(self._usage_slots) == 0:
            self._usage_slots = List[Int32](length=len(document.nodes), fill=-1)
        var slot = Int(self._usage_slots[definition])
        if slot < 0:
            slot = len(self._usage_lists)
            self._usage_lists.append(List[VariableUsage]())
            self._usage_done.append(False)
            self._usage_slots[definition] = Int32(slot)
        return slot

    def start_recording(mut self, document: Document, definition: Int):
        """Start to record the variable usages of a definition that the walk
        enters, unless they are known.

        Args:
            document: The document of the walk.
            definition: An `OperationDefinition` or `FragmentDefinition`.
        """
        var slot = self._usage_slot(document, definition)
        self._recording = -1 if self._usage_done[slot] else slot

    def record_usage(mut self, node: Int):
        """Record a variable usage at the current node of the walk.

        Args:
            node: The `Variable` node, outside a variable definition.
        """
        if self._recording < 0:
            return
        self._usage_lists[self._recording].append(
            VariableUsage(
                node,
                self.type_info.get_input_type(),
                self.type_info.get_default_value(),
                self.type_info.get_parent_input_type(),
            )
        )

    def stop_recording(mut self):
        """Mark the usages of the definition the walk leaves as known."""
        if self._recording >= 0:
            self._usage_done[self._recording] = True
            self._recording = -1

    def usages_index(
        mut self, schema: Schema, document: Document, definition: Int
    ) -> Int:
        """Return where the variable usages of a definition are kept.

        Args:
            schema: The schema of the walk.
            document: The document of the walk.
            definition: An `OperationDefinition` or `FragmentDefinition`.

        Returns:
            An index into the usage lists; see `get_variable_usages`.
        """
        var slot = self._usage_slot(document, definition)
        if not self._usage_done[slot]:
            self._usage_lists[slot] = collect_usages(
                schema, document, definition
            )
            self._usage_done[slot] = True
        return slot

    def get_variable_usages(
        mut self, schema: Schema, document: Document, definition: Int
    ) -> List[VariableUsage]:
        """Return the variables an operation or a fragment uses, as graphql-js
        `getVariableUsages`.

        Args:
            schema: The schema of the walk.
            document: The document of the walk.
            definition: An `OperationDefinition` or `FragmentDefinition`.

        Returns:
            One usage per `Variable` node outside the variable definitions,
            in document order.
        """
        var slot = self.usages_index(schema, document, definition)
        return self._usage_lists[slot].copy()

    def recursive_usages_index(
        mut self, schema: Schema, document: Document, operation: Int
    ) -> Int:
        """Return where the recursive variable usages of an operation are
        kept.

        Args:
            schema: The schema of the walk.
            document: The document of the walk.
            operation: An `OperationDefinition` node.

        Returns:
            An index into the recursive usage lists; see
            `get_recursive_variable_usages`.
        """
        if len(self._recursive_slots) == 0:
            self._recursive_slots = List[Int32](
                length=len(document.nodes), fill=-1
            )
        var slot = Int(self._recursive_slots[operation])
        if slot >= 0:
            return slot
        var own = self.usages_index(schema, document, operation)
        var usages = self._usage_lists[own].copy()
        var fragments = self.referenced_index(document, operation)
        var index = 0
        while index < len(self._referenced_lists[fragments]):
            var fragment = Int(self._referenced_lists[fragments][index])
            var theirs = self.usages_index(schema, document, fragment)
            usages.extend(Span(self._usage_lists[theirs]))
            index += 1
        slot = len(self._recursive_lists)
        self._recursive_lists.append(usages^)
        self._recursive_slots[operation] = Int32(slot)
        return slot

    def get_recursive_variable_usages(
        mut self, schema: Schema, document: Document, operation: Int
    ) -> List[VariableUsage]:
        """Return the variables an operation uses, directly or through its
        fragments, as graphql-js `getRecursiveVariableUsages`.

        Args:
            schema: The schema of the walk.
            document: The document of the walk.
            operation: An `OperationDefinition` node.

        Returns:
            The operation's usages, then those of each fragment it uses.
        """
        var slot = self.recursive_usages_index(schema, document, operation)
        return self._recursive_lists[slot].copy()


def collect_usages(
    schema: Schema, document: Document, definition: Int
) -> List[VariableUsage]:
    """Walk a definition with a new `TypeInfo` and list its variable usages,
    as graphql-js `getVariableUsages` does.

    Args:
        schema: The schema of the walk.
        document: The document that holds the definition.
        definition: An `OperationDefinition` or `FragmentDefinition`.

    Returns:
        One usage per `Variable` node outside the variable definitions.
    """
    var usages = List[VariableUsage]()
    var type_info = TypeInfo(schema)
    var path: List[Int] = [definition]
    type_info.enter(schema, document, definition)
    var current = document.first_child(definition)
    while len(path) > 0:
        if current != NO_NODE:
            var kind = document.kind(current)
            if kind == Kind.VARIABLE_DEFINITION:
                current = document.next_sibling(current)
                continue
            path.append(current)
            type_info.enter(schema, document, current)
            if kind == Kind.VARIABLE:
                usages.append(
                    VariableUsage(
                        current,
                        type_info.get_input_type(),
                        type_info.get_default_value(),
                        type_info.get_parent_input_type(),
                    )
                )
            current = document.first_child(current)
        else:
            var done = path.pop()
            type_info.leave(document, done)
            current = document.next_sibling(done) if len(path) > 0 else NO_NODE
    return usages^
