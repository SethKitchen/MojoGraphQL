# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Operation minification: a port of graphql-go-tools v2 `v2/pkg/astminify`
(`minify.go`) at 9ef6e24.

The minifier finds the selection sets that occur more than once in an
operation, with the same enclosing type and the same directives on their
field or inline fragment. It moves each repeated selection set into a new
fragment definition, `fragment A on T { ... }`, and puts a spread of the
fragment in its place. The deepest sets move first, so a fragment can
spread a fragment of a deeper set. The output is printed with the
graphql-go-tools printer of `gql_normalization.go_printer`.

```mojo
from gql_normalization.minify import Minifier, MinifyOptions

var out = String("")
var minifier = Minifier()
if minifier.minify(operation, schema, MinifyOptions(sort_ast=True), out):
    print(out)
```

Differences from upstream:

- The definition is a `gql_schema` `Schema`, not a definition
  `ast.Document` with the base schema merged in. `__typename` resolves to
  `String`, and `__schema` and `__type` resolve to `__Schema` and `__Type`
  on the query type, as the base schema of upstream does.
- `minify` writes to a `String`, not to an `io.Writer`.
- The key of a selection set is its printed text, its enclosing type name
  and its printed directives, not the xxhash of that text. Two different
  sets cannot collide.
- Repeated sets of the same depth and the same enclosing type name move in
  the order that the walk finds them. Upstream takes them from a Go map, so
  their order, and the letters of their fragments, can change from run to
  run.
- The sort of `SortAST` is an insertion sort, as Go `slices.SortFunc` is
  for 12 items or fewer. For more items Go uses pdqsort, which can put
  equal items, and fragment spreads, in a different order.
- The 677th fragment raises an error. Upstream indexes past its alphabet
  and panics.
- The free function `minify` returns the operation text unchanged when no
  selection set repeats. `Minifier.minify` writes nothing then, as
  upstream.
"""

from gql_language.ast import Document, Kind, NO_NODE, Node, Role, role_bit
from gql_language.parser import parse
from gql_language.source import Source
from gql_normalization.go_printer import GoPrinter, print_compact, print_indent
from gql_schema.definition import NO_TYPE, Schema

comptime _SORT_INSERTION_LIMIT = 12
"""The largest slice that Go `slices.SortFunc` sorts by insertion."""
comptime _MAX_FRAGMENTS = 676
"""How many fragment names the two-letter alphabet of upstream has."""


@fieldwise_init
struct MinifyOptions(ImplicitlyCopyable, Movable):
    """The options of a minification, as upstream `MinifyOptions`."""

    var pretty: Bool
    """Print with an indent of four spaces, as upstream `Pretty`."""
    var sort_ast: Bool
    """Sort the selections, arguments and directives first, so more sets
    are equal, as upstream `SortAST`."""

    def __init__(out self):
        """Make the default options: compact output and no sort."""
        self.pretty = False
        self.sort_ast = False


@fieldwise_init
struct _Item(ImplicitlyCopyable, Movable):
    """One occurrence of a selection set."""

    var selection_set: Int
    """The `SelectionSet` node."""
    var ancestor: Int
    """The field, inline fragment or operation that owns the set."""
    var parent_selection_set: Int
    """The set that holds the inline fragment, or `NO_NODE`."""


struct _Stats(Copyable, Movable):
    """The occurrences of one selection set key."""

    var items: List[_Item]
    """The occurrences, in walk order."""
    var depth: Int
    """The largest walker depth of an occurrence."""
    var type_name: String
    """The name of the enclosing type, or empty when it is not known."""

    def __init__(out self, item: _Item, depth: Int, var type_name: String):
        """Start the stats of a key with its first occurrence.

        Args:
            item: The occurrence.
            depth: Its walker depth.
            type_name: The enclosing type's name.
        """
        self.items = [item]
        self.depth = depth
        self.type_name = type_name^


struct Minifier(Movable):
    """The minifier of upstream `astminify.Minifier`."""

    var _fragment_definition_count: Int
    var _printer: GoPrinter
    var _cursor: Int
    var _keys: Dict[String, Int]
    var _stats: List[_Stats]

    def __init__(out self):
        """Make a minifier, as upstream `NewMinifier`."""
        self._fragment_definition_count = -1
        self._printer = GoPrinter(String(""))
        self._cursor = 0
        self._keys = Dict[String, Int]()
        self._stats = List[_Stats]()

    def minify(
        mut self,
        operation: StringSlice,
        definition: Schema,
        options: MinifyOptions,
        mut out: String,
    ) raises -> Bool:
        """Minify an operation, as upstream `Minifier.Minify`.

        Args:
            operation: The text of a document with exactly one operation.
            definition: The schema of the operation.
            options: The options.
            out: The output; the minified document is appended to it when
                a selection set repeats.

        Returns:
            True when the minifier made a fragment, as upstream
            `madeReplacements`. When it is False, `out` is not changed.

        Raises:
            Error: If the operation does not parse, if it has not exactly
                one operation definition, if its root type is not in the
                schema, or if an inline fragment names an unknown type.
        """
        self._fragment_definition_count = -1
        self._keys = Dict[String, Int]()
        self._stats = List[_Stats]()
        self._cursor = 0
        var doc = parse(Source(String(operation)))
        var root = _the_operation(doc)
        if options.sort_ast:
            _sort_ast(doc)
        var root_type = definition.root_type(doc.operation(root).value)
        if root_type == NO_TYPE:
            raise Error(
                "operation type ",
                doc.operation(root).text(),
                " is not defined; did you forget to merge the base schema?",
            )
        var selection_set = doc.child(root, Role.SELECTION_SET)
        self._printer.out = String("")
        self._printer.spans.clear()
        self._printer.record = True
        self._printer.selection_set(doc, selection_set, 0)
        self._enter_selection_set(
            doc, definition, selection_set, root, NO_NODE, root_type, 2
        )
        if not self._apply(doc):
            return False
        if options.pretty:
            out += print_indent(doc, "    ")
        else:
            out += print_compact(doc)
        return True

    def _enter_selection_set(
        mut self,
        doc: Document,
        schema: Schema,
        node: Int,
        ancestor: Int,
        parent: Int,
        type: Int,
        depth: Int,
    ) raises:
        """Count one selection set, then walk into its selections, as
        upstream `minifyVisitor.EnterSelectionSet`."""
        var slot = self._cursor * 3
        self._cursor += 1
        var start = self._printer.spans[slot + 1]
        var end = self._printer.spans[slot + 2]
        var type_name = String("")
        if type != NO_TYPE:
            type_name = schema.types[type].name.copy()
        var key = String(
            StringSlice(
                unsafe_from_utf8=self._printer.out.as_bytes()[start:end]
            )
        )
        key += type_name
        # The directives of the field or the inline fragment keep sets with
        # different directives apart.
        if (
            doc.kind(ancestor) != Kind.OPERATION_DEFINITION
            and doc.nodes[ancestor].roles & role_bit(Role.DIRECTIVE) != 0
        ):
            var printer = GoPrinter(String(""))
            var directive = doc.child(ancestor, Role.DIRECTIVE)
            while directive != NO_NODE:
                printer.directive(doc, directive)
                directive = doc.next_with_role(directive)
            key += printer.out
        var item = _Item(node, ancestor, parent)
        var found = self._keys.get(key)
        if found:
            ref stats = self._stats[found.value()]
            stats.items.append(item)
            if depth > stats.depth:
                stats.depth = depth
        else:
            self._keys[key^] = len(self._stats)
            self._stats.append(_Stats(item, depth, type_name^))
        var child = doc.first_child(node)
        while child != NO_NODE:
            var kind = doc.kind(child)
            if kind == Kind.FIELD:
                var selection_set = doc.child(child, Role.SELECTION_SET)
                if selection_set != NO_NODE:
                    self._enter_selection_set(
                        doc,
                        schema,
                        selection_set,
                        child,
                        node,
                        _field_type(doc, schema, child, type),
                        depth + 2,
                    )
            elif kind == Kind.INLINE_FRAGMENT:
                var inner = type
                var condition = doc.child(child, Role.TYPE_CONDITION)
                if condition != NO_NODE:
                    inner = schema.type_named(doc.name(condition))
                    if inner == NO_TYPE:
                        raise Error('Unknown type "', doc.name(condition), '".')
                self._enter_selection_set(
                    doc,
                    schema,
                    doc.child(child, Role.SELECTION_SET),
                    child,
                    node,
                    inner,
                    depth + 2,
                )
            child = doc.next_sibling(child)

    def _apply(mut self, mut doc: Document) raises -> Bool:
        """Replace every repeated selection set, deepest first, as upstream
        `Minifier.apply`."""
        var order = List[Int]()
        var index = 0
        while index < len(self._stats):
            if len(self._stats[index].items) > 1:
                order.append(index)
            index += 1
        if len(order) == 0:
            return False
        # A stable insertion sort: deeper first, then by type name, Z first.
        var i = 1
        while i < len(order):
            var j = i
            while j > 0 and self._before(order[j], order[j - 1]):
                order.swap_elements(j, j - 1)
                j -= 1
            i += 1
        var next = 0
        while next < len(order):
            self._replace_items(doc, order[next])
            next += 1
        return True

    def _before(self, a: Int, b: Int) -> Bool:
        """Return True if the stats `a` must be replaced before `b`."""
        ref left = self._stats[a]
        ref right = self._stats[b]
        if left.depth == right.depth:
            return right.type_name < left.type_name
        return left.depth > right.depth

    def _replace_items(mut self, mut doc: Document, index: Int) raises:
        """Make the fragment of one repeated set and spread it in each
        place, as upstream `Minifier.replaceItems`."""
        var name = self._fragment_name(doc)
        ref stats = self._stats[index]
        var first = stats.items[0]
        var fragment = doc.add(Kind.FRAGMENT_DEFINITION, Role.DEFINITION)
        _ = doc.add_name(fragment, Role.NAME, name)
        var condition = doc.add_child(
            fragment, Kind.NAMED_TYPE, Role.TYPE_CONDITION
        )
        _ = doc.add_name(condition, Role.NAME, stats.type_name)
        # Every set is inside the root set, so the root set never repeats:
        # each occurrence belongs to a field or an inline fragment.
        var directive = doc.child(first.ancestor, Role.DIRECTIVE)
        while directive != NO_NODE:
            doc.append_child(
                fragment, _copy_tree(doc, directive, Role.DIRECTIVE)
            )
            directive = doc.next_with_role(directive)
        doc.append_child(
            fragment,
            _copy_tree(doc, first.selection_set, Role.SELECTION_SET),
        )
        doc.append_child(doc.root, fragment)
        var index_of_item = 0
        while index_of_item < len(stats.items):
            var item = stats.items[index_of_item]
            index_of_item += 1
            if doc.kind(item.ancestor) == Kind.INLINE_FRAGMENT:
                _replace_selection(
                    doc,
                    item.parent_selection_set,
                    item.ancestor,
                    _spread(doc, name),
                )
            else:
                var spread = Int32(_spread(doc, name))
                doc.nodes[item.selection_set].first = spread
                doc.nodes[item.selection_set].last = spread
                doc.nodes[item.selection_set].roles = role_bit(Role.SELECTION)

    def _fragment_name(mut self, doc: Document) raises -> String:
        """Return the next fragment name: `A` to `Z`, then `BA` on, as
        upstream `Minifier.fragmentName`."""
        while True:
            self._fragment_definition_count += 1
            var count = self._fragment_definition_count
            if count < 26:
                return chr(65 + count)
            if count >= _MAX_FRAGMENTS:
                raise Error("astminify: more than 676 fragments")
            var name = chr(65 + count // 26) + chr(65 + count % 26)
            if not _has_fragment(doc, name):
                return name


def minify(
    operation: StringSlice,
    definition: Schema,
    options: MinifyOptions = MinifyOptions(),
) raises -> String:
    """Minify an operation with a new `Minifier`.

    Args:
        operation: The text of a document with exactly one operation.
        definition: The schema of the operation.
        options: The options.

    Returns:
        The minified document, or the operation text unchanged when no
        selection set repeats.

    Raises:
        Error: As `Minifier.minify`.
    """
    var out = String("")
    var minifier = Minifier()
    if minifier.minify(operation, definition, options, out):
        return out^
    return String(operation)


def _the_operation(doc: Document) raises -> Int:
    """Return the one operation definition, as upstream `validate`."""
    var found = NO_NODE
    var count = 0
    var current = doc.first_child(doc.root)
    while current != NO_NODE:
        if doc.kind(current) == Kind.OPERATION_DEFINITION:
            found = current
            count += 1
        current = doc.next_sibling(current)
    if count != 1:
        raise Error("AST must have exactly one operation definition")
    return found


def _field_type(doc: Document, schema: Schema, field: Int, type: Int) -> Int:
    """Return the named type of a field's selection set, or `NO_TYPE`.

    An unknown field gives `NO_TYPE` and no error, as the upstream walker
    gives an invalid enclosing type.
    """
    var name = doc.name(field)
    if type != NO_TYPE:
        var found = schema.field_named(type, name)
        if found != NO_TYPE:
            return Int(schema.fields[found].type.named)
        if type == Int(schema.query_type):
            if name == "__schema":
                return schema.type_named("__Schema")
            if name == "__type":
                return schema.type_named("__Type")
    if name == "__typename":
        return schema.type_named("String")
    return NO_TYPE


def _has_fragment(doc: Document, name: StringSlice) -> Bool:
    """Return True if the document defines a fragment with a name."""
    var current = doc.first_child(doc.root)
    while current != NO_NODE:
        if (
            doc.kind(current) == Kind.FRAGMENT_DEFINITION
            and doc.name(current) == name
        ):
            return True
        current = doc.next_sibling(current)
    return False


def _spread(mut doc: Document, name: StringSlice) -> Int:
    """Add a fragment spread of a fragment, with no parent yet."""
    var node = doc.add(Kind.FRAGMENT_SPREAD, Role.SELECTION)
    _ = doc.add_name(node, Role.NAME, name)
    return node


def _replace_selection(mut doc: Document, parent: Int, old: Int, new: Int):
    """Put a new selection in the place of a selection of a set."""
    var previous = NO_NODE
    var current = doc.first_child(parent)
    while current != old:
        previous = current
        current = doc.next_sibling(current)
    doc.nodes[new].next = doc.nodes[old].next
    if previous == NO_NODE:
        doc.nodes[parent].first = Int32(new)
    else:
        doc.nodes[previous].next = Int32(new)
    if Int(doc.nodes[parent].last) == old:
        doc.nodes[parent].last = Int32(new)


def _copy_tree(mut doc: Document, node: Int, role: Role) -> Int:
    """Copy a node and its descendants inside one document.

    The copies keep the text ranges of the originals, so no text is copied.
    """
    var root = _copy_node(doc, node, role)
    var stack: List[Int] = [node, root]
    while len(stack) > 0:
        var copy = stack.pop()
        var original = stack.pop()
        var child = doc.first_child(original)
        while child != NO_NODE:
            var child_copy = _copy_node(doc, child, doc.role(child))
            doc.append_child(copy, child_copy)
            stack.append(child)
            stack.append(child_copy)
            child = doc.next_sibling(child)
    return root


def _copy_node(mut doc: Document, node: Int, role: Role) -> Int:
    """Copy one node without its children."""
    var found = doc.nodes[node]
    doc.nodes.append(
        Node(
            found.kind,
            role,
            found.flags,
            found.start,
            found.end,
            NO_NODE,
            NO_NODE,
            NO_NODE,
            0,
        )
    )
    return len(doc.nodes) - 1


def _sort_ast(mut doc: Document):
    """Sort the selections, arguments and directives, as upstream
    `Minifier.sortAst`."""
    var node = 0
    var total = len(doc.nodes)
    while node < total:
        var kind = doc.kind(node)
        if kind == Kind.SELECTION_SET:
            _sort_children(doc, node, Role.SELECTION)
        elif kind == Kind.FIELD:
            _sort_children(doc, node, Role.DIRECTIVE)
            _sort_children(doc, node, Role.ARGUMENT)
        elif kind == Kind.INLINE_FRAGMENT:
            _sort_children(doc, node, Role.DIRECTIVE)
        elif kind == Kind.DIRECTIVE:
            _sort_children(doc, node, Role.ARGUMENT)
        node += 1


def _sort_children(mut doc: Document, parent: Int, role: Role):
    """Sort the children of a node with a role, as Go `slices.SortFunc`
    sorts a short slice: by insertion."""
    if doc.nodes[parent].roles & role_bit(role) == 0:
        return
    var items = doc.children(parent, role)
    var changed = False
    var i = 1
    while i < len(items):
        var j = i
        while j > 0 and _compare(doc, items[j], items[j - 1], role) < 0:
            items.swap_elements(j, j - 1)
            changed = True
            j -= 1
        i += 1
    if not changed:
        return
    var all = List[Int]()
    var current = doc.first_child(parent)
    while current != NO_NODE:
        all.append(current)
        current = doc.next_sibling(current)
    var next_item = 0
    var index = 0
    while index < len(all):
        if doc.role(all[index]) == role:
            all[index] = items[next_item]
            next_item += 1
        index += 1
    doc.nodes[parent].first = Int32(all[0])
    index = 1
    while index < len(all):
        doc.nodes[all[index - 1]].next = Int32(all[index])
        index += 1
    doc.nodes[all[len(all) - 1]].next = NO_NODE
    doc.nodes[parent].last = Int32(all[len(all) - 1])


def _compare(doc: Document, a: Int, b: Int, role: Role) -> Int:
    """Compare two children, as the comparators of upstream `sortAst`."""
    if role != Role.SELECTION:
        return _compare_text(doc.name(a), doc.name(b))
    var left = doc.kind(a)
    var right = doc.kind(b)
    if left == Kind.FIELD:
        if right == Kind.INLINE_FRAGMENT:
            return -1
        if right == Kind.FIELD:
            var names = _compare_text(doc.name(a), doc.name(b))
            if names != 0:
                return names
            return _compare_text(_alias(doc, a), _alias(doc, b))
        return 0
    if left == Kind.INLINE_FRAGMENT:
        if right == Kind.FIELD:
            return 1
        if right == Kind.INLINE_FRAGMENT:
            return _compare_text(_condition(doc, a), _condition(doc, b))
    return 0


def _alias(doc: Document, field: Int) -> String:
    """Return a field's alias, or empty when it has none."""
    var alias = doc.child(field, Role.ALIAS)
    if alias == NO_NODE:
        return String("")
    return String(doc.text(alias))


def _condition(doc: Document, fragment: Int) -> String:
    """Return the type condition of an inline fragment, or empty."""
    var condition = doc.child(fragment, Role.TYPE_CONDITION)
    if condition == NO_NODE:
        return String("")
    return String(doc.name(condition))


def _compare_text(a: StringSlice, b: StringSlice) -> Int:
    """Compare two texts by their bytes, as Go `strings.Compare`."""
    if a == b:
        return 0
    if a < b:
        return -1
    return 1
