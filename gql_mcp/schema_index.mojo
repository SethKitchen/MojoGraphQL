# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Index a GraphQL schema and search it for the paths from a root type to
the types that match a set of terms.

Port of Apollo MCP Server 2.0.0 (04e4e6e) `crates/apollo-schema-index/src`:
`lib.rs` (`SchemaIndex`, `Options`, `OperationType`), `path.rs`
(`PathNode`, `Scored`), `traverse.rs` (`SchemaExt::traverse`) and
`error.rs`. The upstream keeps its documents in a tantivy 0.26.2 index in
memory. This module keeps the same three text fields, `type_name`,
`description` and `fields`, as inverted lists, and scores a query as tantivy
does: BM25 with `k1 = 1.2` and `b = 0.75`, the tantivy `idf`, the field
lengths quantized with the tantivy field norm table, a term frequency of 1
(the `IndexRecordOption::Basic` of the upstream term queries), and the sum
of the matching `Should` clauses. Equal scores keep the order of the
documents.

Differences from upstream:

- The upstream adds one document per type in the order of a Rust
  `HashMap`, which changes from run to run. This module adds them in the
  order of the traversal, which is deterministic. The order matters only
  for types with equal scores.
- `format_f32` takes the digits whose value is strictly inside the rounding
  interval of the score. Rust also takes a value on the edge of the
  interval when the mantissa is even. Only a score whose interval edge is a
  short decimal can print otherwise.
- The index has no memory budget and no `IndexingError` or `SearchError`:
  nothing here can fail after the schema is valid.
- The analyzer is `gql_mcp.text_analysis`; see its differences.
"""

from gql_mcp.text_analysis import analyze, expand_identifiers
from gql_schema.definition import AstRef, NO_TYPE, Schema, TypeKind, TypeRef
from std.math import floor, log, log10
from std.memory import bitcast


def format_f32(value: Float32) -> String:
    """Return the text of a `Float32`, as Rust `Display` writes an `f32`:
    the shortest digits that read back as the value, and no exponent.

    Args:
        value: A finite value.

    Returns:
        The text, such as `6.170166`, `3` or `0.0001`.
    """
    if value == 0:
        return "0"
    var sign = String("-") if value < 0 else String()
    var positive = -value if value < 0 else value
    var bits = bitcast[DType.uint32](positive)
    var v = Float64(positive)
    var low = (v + Float64(bitcast[DType.float32](bits - 1))) / 2
    var high = (v + Float64(bitcast[DType.float32](bits + 1))) / 2
    var exponent = Int(floor(log10(v)))
    var digits = 0
    var mantissa = 0
    var found = False
    while not found:
        digits += 1
        var scale = 10.0 ** Float64(digits - 1 - exponent)
        mantissa = Int(round(v * scale))
        var back = Float64(mantissa) / scale
        found = back > low and back < high
    # The first digit count that reads back has no trailing zero: with one
    # digit less, the mantissa without its zero would have read back.
    var power = exponent - (digits - 1)
    var text = String(mantissa)
    if power >= 0:
        return sign + text + "0" * power
    var size = text.byte_length()
    if size > -power:
        return (
            sign + text[byte = : size + power] + "." + text[byte = size + power :]
        )
    return sign + "0." + "0" * (-power - size) + text


@fieldwise_init
struct PathSegment(Copyable, Equatable, Movable):
    """One node of a path: a type, and the field to the next node."""

    var node_type: String
    """The name of the schema type of this node."""
    var field_name: Optional[String]
    """The field that references the next type, when the next type is the
    type of a field; empty for the last node and for union members and
    interface implementers."""
    var field_args: List[String]
    """The named types of the arguments of that field."""

    def __eq__(self, other: Self) -> Bool:
        """Return whether two segments are equal.

        Args:
            other: The other segment.

        Returns:
            Whether the type, the field and the arguments are equal.
        """
        return (
            self.node_type == other.node_type
            and self.field_name == other.field_name
            and self.field_args == other.field_args
        )


struct PathNode(Copyable, Movable, Sized, Writable):
    """A path from a root type to a type, as upstream `PathNode`. The
    upstream links each node to its child; here the nodes are a list, from
    the root to the last type."""

    var segments: List[PathSegment]
    """The nodes, from the first to the last."""

    def __init__(out self, var node_type: String):
        """Make a path of one type.

        Args:
            node_type: The type's name.
        """
        self.segments = List[PathSegment]()
        self.segments.append(PathSegment(node_type^, None, List[String]()))

    def add_child(
        self,
        var field_name: Optional[String],
        var field_args: List[String],
        var child_type: String,
    ) -> PathNode:
        """Return the path with a type added at the end.

        Args:
            field_name: The field of the last type that references the new
                type, if any.
            field_args: The named types of the field's arguments.
            child_type: The new type.

        Returns:
            The longer path.
        """
        var out = self.copy()
        ref last = out.segments[len(out.segments) - 1]
        last.field_name = field_name^
        last.field_args = field_args^
        out.segments.append(PathSegment(child_type^, None, List[String]()))
        return out^

    def add_parent(
        self,
        var field_name: Optional[String],
        var field_args: List[String],
        var parent_type: String,
    ) -> PathNode:
        """Return the path with a type added at the start.

        Args:
            field_name: The field of the new type that references the first
                type, if any.
            field_args: The named types of the field's arguments.
            parent_type: The new type.

        Returns:
            The longer path.
        """
        var out = self.copy()
        out.segments.insert(
            0, PathSegment(parent_type^, field_name^, field_args^)
        )
        return out^

    def referencing_type(self) -> Optional[PathSegment]:
        """Return the node before the last one.

        Returns:
            The penultimate node, with the field that references the last
            type, or nothing for a path of one type.
        """
        if len(self.segments) < 2:
            return None
        return self.segments[len(self.segments) - 2].copy()

    def has_cycle(self) -> Bool:
        """Return whether a type is in the path twice.

        Returns:
            Whether the path has a cycle.
        """
        var i = 1
        while i < len(self.segments):
            var j = 0
            while j < i:
                if self.segments[j].node_type == self.segments[i].node_type:
                    return True
                j += 1
            i += 1
        return False

    def __len__(self) -> Int:
        """Return the number of types in the path.

        Returns:
            The length.
        """
        return len(self.segments)

    def write_to(self, mut writer: Some[Writer]):
        """Write the path as upstream `Display`, such as
        `Query -> post(ID) -> Post`.

        Args:
            writer: The writer.
        """
        writer.write(self.segments[0].node_type)
        var i = 1
        while i < len(self.segments):
            ref segment = self.segments[i - 1]
            if segment.field_name:
                writer.write(" -> ", segment.field_name.value())
                if len(segment.field_args) > 0:
                    writer.write("(")
                    var a = 0
                    while a < len(segment.field_args):
                        if a > 0:
                            writer.write(",")
                        writer.write(segment.field_args[a])
                        a += 1
                    writer.write(")")
            writer.write(" -> ", self.segments[i].node_type)
            i += 1


@fieldwise_init
struct ScoredPath(Copyable, Movable, Writable):
    """A path with its score, as upstream `Scored<PathNode>`."""

    var inner: PathNode
    """The path."""
    var score: Float32
    """The score; a higher score is a better match."""

    def write_to(self, mut writer: Some[Writer]):
        """Write the path and its score, such as `Query -> Post (1.5)`.

        Args:
            writer: The writer.
        """
        writer.write(self.inner, " (", format_f32(self.score), ")")


struct RootTypes(Equatable, ImplicitlyCopyable):
    """A set of operation types, as the upstream `EnumSet<OperationType>`."""

    var bits: UInt8
    """One bit for each operation type."""

    comptime NONE = RootTypes(0)
    """No operation type."""
    comptime QUERY = RootTypes(1)
    """The query type."""
    comptime MUTATION = RootTypes(2)
    """The mutation type."""
    comptime SUBSCRIPTION = RootTypes(4)
    """The subscription type."""

    def __init__(out self, bits: UInt8):
        """Make a set from its bits.

        Args:
            bits: The bits: 1 query, 2 mutation, 4 subscription.
        """
        self.bits = bits

    def is_valid(self) -> Bool:
        """Return whether the set has only the three operation types.

        Returns:
            Whether no other bit is set.
        """
        return self.bits <= 7

    def __or__(self, other: Self) -> Self:
        """Return the union of two sets.

        Args:
            other: The other set.

        Returns:
            The union.
        """
        return RootTypes(self.bits | other.bits)

    def contains(self, operation: UInt8) -> Bool:
        """Return whether the set has an operation type.

        Args:
            operation: 0 query, 1 mutation, 2 subscription.

        Returns:
            Whether the set has it.
        """
        return (self.bits >> operation) & 1 == 1


@fieldwise_init
struct SearchOptions(Copyable, Movable):
    """The options of a search, as upstream `Options`."""

    var max_type_matches: Int
    """The most matching types in the results."""
    var max_paths_per_type: Int
    """The most paths to each matching type."""
    var short_path_boost_factor: Float32
    """The boost of shorter paths: 0 for none, 1 for 100%."""
    var parent_match_boost_factor: Float32
    """The part of the score of each matching type in a path that the
    path gets."""

    def __init__(out self):
        """Make the upstream default options: 10 types, 3 paths each, a
        short path boost of 0.5 and a parent match boost of 0.2."""
        self.max_type_matches = 10
        self.max_paths_per_type = 3
        self.short_path_boost_factor = 0.5
        self.parent_match_boost_factor = 0.2


@fieldwise_init
struct TraversedType(Copyable, Movable):
    """A type that a traversal reaches, and the path that reaches it."""

    var type: Int
    """The type's index in the schema."""
    var path: PathNode
    """The path from a root type."""


def document_order(schema: Schema) -> List[Int]:
    """Return the types that the SDL defines, in the order of their
    definitions, as the apollo-compiler type map keeps them.

    Args:
        schema: The schema.

    Returns:
        The indices of the types that are not built in.
    """
    var keys = List[Int]()
    var index = 0
    while index < len(schema.types):
        ref type = schema.types[index]
        if not type.is_builtin:
            var at = type.definition
            var start = schema.documents[Int(at.document)].start(Int(at.node))
            keys.append(
                (((Int(at.document) << 32) | start) << 20) | index
            )
        index += 1
    sort(keys)
    var out = List[Int]()
    var i = 0
    while i < len(keys):
        out.append(keys[i] & 0xFFFFF)
        i += 1
    return out^


def _named(schema: Schema, type: TypeRef) -> String:
    """Return the name of the named type under the wrappers."""
    return schema.types[Int(type.named)].name.copy()


def _push_fields(
    schema: Schema,
    type: Int,
    path: PathNode,
    mut stack: List[TraversedType],
):
    """Push the field types of an object or interface type."""
    ref span = schema.types[type].fields
    var f = Int(span.start)
    while f < span.end():
        ref field = schema.fields[f]
        var args = List[String]()
        var a = Int(field.arguments.start)
        while a < field.arguments.end():
            args.append(_named(schema, schema.input_values[a].type))
            a += 1
        stack.append(
            TraversedType(
                Int(field.type.named),
                path.add_child(
                    field.name.copy(), args^, _named(schema, field.type)
                ),
            )
        )
        f += 1


def traverse(schema: Schema, root_types: RootTypes) -> List[TraversedType]:
    """Visit the types of a schema depth first from its root types, as
    upstream `SchemaExt::traverse`.

    A type's children are visited only the first time the type is reached,
    but each later path to the type is still returned. A path with a cycle
    stops there. Built-in types are not returned.

    Args:
        schema: The schema.
        root_types: The root types to start from.

    Returns:
        Each type that is reached, with its path, in the order of the
        upstream iterator.
    """
    var order = document_order(schema)
    var stack = List[TraversedType]()
    var operation = 3
    while operation > 0:
        operation -= 1
        var root = schema.root_type(UInt8(operation))
        if root != NO_TYPE and root_types.contains(UInt8(operation)):
            var name = schema.types[root].name.copy()
            stack.append(TraversedType(root, PathNode(name^)))
    var seen = List[Bool](length=len(schema.types), fill=False)
    var out = List[TraversedType]()
    while len(stack) > 0:
        var item = stack.pop()
        if item.path.has_cycle():
            continue
        var first = not seen[item.type]
        seen[item.type] = True
        ref type = schema.types[item.type]
        if type.is_builtin:
            continue
        if first:
            if type.kind == TypeKind.OBJECT:
                _push_fields(schema, item.type, item.path, stack)
            elif type.kind == TypeKind.INTERFACE:
                _push_fields(schema, item.type, item.path, stack)
                var i = 0
                while i < len(order):
                    var object = order[i]
                    if schema.types[
                        object
                    ].kind == TypeKind.OBJECT and schema.is_sub_type(
                        item.type, object
                    ):
                        var name = schema.types[object].name.copy()
                        stack.append(
                            TraversedType(
                                object,
                                item.path.add_child(None, List[String](), name^),
                            )
                        )
                    i += 1
            elif type.kind == TypeKind.UNION:
                ref span = type.members
                var m = Int(span.start)
                while m < span.end():
                    var member = Int(schema.type_lists[m])
                    var name = schema.types[member].name.copy()
                    stack.append(
                        TraversedType(
                            member,
                            item.path.add_child(None, List[String](), name^),
                        )
                    )
                    m += 1
        out.append(item^)
    return out^


def field_norm_table() -> List[UInt32]:
    """Return the 256 field lengths that tantivy can store, as
    `FIELD_NORMS_TABLE` of tantivy 0.26.2 `src/fieldnorm/code.rs`.

    Returns:
        The table: 0 to 40 exactly, then steps that double each 8 entries.
    """
    var table = List[UInt32](capacity=256)
    var value: UInt32 = 0
    var step: UInt32 = 2
    var count = 0
    while len(table) < 256:
        table.append(value)
        if value < 40:
            value += 1
        else:
            value += step
            count += 1
            if count % 8 == 0:
                step *= 2
    return table^


def field_norm_id(table: List[UInt32], length: Int) -> Int:
    """Return the id of the largest stored length that is not more than a
    length, as tantivy `fieldnorm_to_id`.

    Args:
        table: The `field_norm_table`.
        length: The number of tokens of a field.

    Returns:
        The id, 0 to 255.
    """
    var low = 0
    var high = 255
    while low < high:
        var middle = (low + high + 1) // 2
        if Int(table[middle]) <= length:
            low = middle
        else:
            high = middle - 1
    return low


struct _TextField(Copyable, Movable):
    """One indexed text field: its inverted lists and its lengths."""

    var terms: Dict[String, Int]
    """The position of each term in `postings`."""
    var postings: List[List[Int]]
    """The documents of each term, in order, each once."""
    var lengths: List[Int]
    """The number of tokens of the field in each document."""
    var total: Int
    """The number of tokens of the field in all documents."""

    def __init__(out self):
        """Make an empty field."""
        self.terms = Dict[String, Int]()
        self.postings = List[List[Int]]()
        self.lengths = List[Int]()
        self.total = 0

    def add(mut self, document: Int, text: String):
        """Add the tokens of a text to a document.

        Args:
            document: The document, the last one added or a new one.
            text: The text.
        """
        if document == len(self.lengths):
            self.lengths.append(0)
        var terms = analyze(text)
        self.lengths[document] += len(terms)
        self.total += len(terms)
        var i = 0
        while i < len(terms):
            var at = self.terms.get(terms[i], -1)
            if at < 0:
                self.terms[terms[i]] = len(self.postings)
                self.postings.append(List[Int]())
                at = len(self.postings) - 1
            ref docs = self.postings[at]
            if len(docs) == 0 or docs[len(docs) - 1] != document:
                docs.append(document)
            i += 1


def _fields_text(schema: Schema, type: Int) -> String:
    """Return the text of the `fields` field of a type's document: `name:
    Type` for each field, joined by `, `, or `Enum: A | B` for an enum.

    A traversal reaches only output types, so the upstream case of an input
    object type never happens and is not here."""
    ref named = schema.types[type]
    var out = String()
    if named.kind == TypeKind.OBJECT or named.kind == TypeKind.INTERFACE:
        var i = Int(named.fields.start)
        while i < named.fields.end():
            if i > Int(named.fields.start):
                out += ", "
            ref field = schema.fields[i]
            out += field.name + ": " + _named(schema, field.type)
            i += 1
    elif named.kind == TypeKind.ENUM:
        out = named.name + ": "
        var i = Int(named.enum_values.start)
        while i < named.enum_values.end():
            if i > Int(named.enum_values.start):
                out += " | "
            out += schema.enum_values[i].name
            i += 1
    return out^


def _member_descriptions(schema: Schema, type: Int) -> String:
    """Return the descriptions of a type's fields or enum values, joined by
    line breaks."""
    ref named = schema.types[type]
    var descriptions = List[AstRef]()
    if named.kind == TypeKind.OBJECT or named.kind == TypeKind.INTERFACE:
        var i = Int(named.fields.start)
        while i < named.fields.end():
            descriptions.append(schema.fields[i].description)
            i += 1
    elif named.kind == TypeKind.ENUM:
        var i = Int(named.enum_values.start)
        while i < named.enum_values.end():
            descriptions.append(schema.enum_values[i].description)
            i += 1
    var out = String()
    var count = 0
    var d = 0
    while d < len(descriptions):
        if descriptions[d].exists():
            if count > 0:
                out += "\n"
            out += schema.description_text(descriptions[d])
            count += 1
        d += 1
    return out^


struct SchemaIndex(Movable):
    """A search index of the types of a schema, as upstream `SchemaIndex`.
    """

    var names: List[String]
    """The type name of each document."""
    var references: List[List[String]]
    """The types that reference each document's type: `Type#field#Arg,Arg`,
    `Type#field`, or `Type` for a union or an interface."""
    var documents: Dict[String, Int]
    """The document of each type name."""
    var texts: List[_TextField]
    """The three text fields: the words of the type name (`type_name`), of
    the type's description and its members' descriptions (`description`),
    and of its fields, input fields or enum values (`fields`)."""
    var norms: List[UInt32]
    """The tantivy field norm table."""

    def __init__(out self, schema: Schema, root_types: RootTypes):
        """Index the types that the root types reach.

        Args:
            schema: The schema.
            root_types: The root types to start from.
        """
        self.names = List[String]()
        self.references = List[List[String]]()
        self.documents = Dict[String, Int]()
        self.texts = List[_TextField]()
        self.texts.append(_TextField())
        self.texts.append(_TextField())
        self.texts.append(_TextField())
        self.norms = field_norm_table()
        var types = List[Int]()
        var traversed = traverse(schema, root_types)
        var i = 0
        while i < len(traversed):
            ref item = traversed[i]
            var name = schema.types[item.type].name.copy()
            var document = self.documents.get(name, -1)
            if document < 0:
                document = len(self.names)
                self.documents[name] = document
                self.names.append(name.copy())
                self.references.append(List[String]())
                types.append(item.type)
            var referencing = item.path.referencing_type()
            if referencing:
                ref segment = referencing.value()
                var text = segment.node_type.copy()
                if segment.field_name:
                    text += "#" + segment.field_name.value()
                    var a = 0
                    while a < len(segment.field_args):
                        text += ("#" if a == 0 else ",") + segment.field_args[a]
                        a += 1
                self.references[document].append(text^)
            i += 1
        var d = 0
        while d < len(types):
            ref named = schema.types[types[d]]
            self.texts[0].add(d, expand_identifiers(named.name))
            self.texts[1].add(
                d, expand_identifiers(schema.description_text(named.description))
            )
            self.texts[1].add(
                d, expand_identifiers(_member_descriptions(schema, types[d]))
            )
            self.texts[2].add(d, expand_identifiers(_fields_text(schema, types[d])))
            d += 1

    def _scorers(self, terms: List[String]) -> List[_TermScorer]:
        """Return the term scorers of the query of the terms, in clause
        order, without the terms that no document has."""
        var scorers = List[_TermScorer]()
        var count = Float32(len(self.names))
        var t = 0
        while t < len(terms):
            var tokens = analyze(expand_identifiers(terms[t]))
            var k = 0
            while k < len(tokens):
                var which = 0
                while which < 3:
                    ref field = self.texts[which]
                    var at = field.terms.get(tokens[k], -1)
                    if at >= 0:
                        var frequency = Float32(len(field.postings[at]))
                        var x = _div(
                            _add(count - frequency, 0.5), _add(frequency, 0.5)
                        )
                        var idf = Float32(log(Float64(_add(1.0, x))))
                        scorers.append(
                            _TermScorer(
                                which,
                                at,
                                0,
                                _mul(idf, _add(1.0, _K1)),
                                _div(Float32(field.total), count),
                            )
                        )
                    which += 1
                k += 1
            t += 1
        return scorers^

    def _score(self, scorer: _TermScorer, doc: Int) -> Float32:
        """Return the BM25 score of a term scorer for a document, as tantivy
        `Bm25Weight::score` with a term frequency of 1."""
        ref field = self.texts[scorer.field]
        var length = self.norms[field_norm_id(self.norms, field.lengths[doc])]
        var part = _div(_mul(_B, Float32(length)), scorer.average)
        var norm = _mul(_K1, _add(_sub(1.0, _B), part))
        return _mul(scorer.weight, _div(1.0, _add(1.0, norm)))

    def _top_documents(self, terms: List[String]) -> List[ScoredPath]:
        """Return the 100 best documents for the terms, best first and
        equal scores in document order, as one-type paths with the score.

        The scores add up as tantivy `BufferedUnionScorer` adds them: in
        windows of 4096 documents, each scorer in turn, and a scorer that
        ends is replaced by the last one (`unordered_drain_filter`).
        """
        var scores = List[Float32](length=len(self.names), fill=0)
        var matched = List[Bool](length=len(self.names), fill=False)
        var active = self._scorers(terms)
        while len(active) > 0:
            var low = len(self.names)
            var s = 0
            while s < len(active):
                low = min(low, self._doc(active[s]))
                s += 1
            var horizon = low + 4096
            var i = 0
            while i < len(active):
                var ended = False
                while not ended and self._doc(active[i]) < horizon:
                    var doc = self._doc(active[i])
                    scores[doc] = _add(scores[doc], self._score(active[i], doc))
                    matched[doc] = True
                    active[i].position += 1
                    ended = active[i].position == len(
                        self.texts[active[i].field].postings[active[i].postings]
                    )
                if ended:
                    active.swap_elements(i, len(active) - 1)
                    _ = active.pop()
                else:
                    i += 1
        var top = List[ScoredPath]()
        var doc = 0
        while doc < len(self.names):
            if matched[doc]:
                top.append(
                    ScoredPath(PathNode(self.names[doc].copy()), scores[doc])
                )
            doc += 1
        _sort_by_score(top)
        if len(top) > 100:
            top.resize(100, ScoredPath(PathNode(String()), 0))
        return top^

    def _doc(self, scorer: _TermScorer) -> Int:
        """Return the document that a term scorer is on."""
        return self.texts[scorer.field].postings[scorer.postings][
            scorer.position
        ]

    def search(
        self, terms: List[String], options: SearchOptions
    ) -> List[ScoredPath]:
        """Search for the types that match terms, and return the paths from
        a root type to them, best first, as upstream `SchemaIndex::search`.

        Args:
            terms: The search terms.
            options: The limits and the boosts.

        Returns:
            The scored paths.
        """
        var top = self._top_documents(terms)
        var scores = Dict[String, Float32]()
        var i = 0
        while i < len(top):
            scores[top[i].inner.segments[0].node_type] = top[i].score
            i += 1
        var paths = List[ScoredPath]()
        var m = 0
        while m < len(top) and m < options.max_type_matches:
            var path_score = top[m].score
            var visited = Dict[String, Bool]()
            var queue = List[PathNode]()
            queue.append(top[m].inner.copy())
            var head = 0
            var count = 0
            while head < len(queue) and count < options.max_paths_per_type:
                var current = queue[head].copy()
                head += 1
                var current_type = current.segments[0].node_type.copy()
                visited[current_type] = True
                var document = self.documents.get(current_type, 0)
                path_score = _add(
                    path_score,
                    _mul(
                        options.parent_match_boost_factor,
                        scores.get(current_type, 0),
                    ),
                )
                ref references = self.references[document]
                if len(references) == 0:
                    paths.append(ScoredPath(current^, path_score))
                    count += 1
                    continue
                var r = 0
                while r < len(references):
                    ref text = references[r]
                    if text not in visited:
                        queue.append(_add_reference(current, text))
                    r += 1
            m += 1
        _boost_shorter_paths(paths, options.short_path_boost_factor)
        _sort_by_score(paths)
        return paths^


def _add_reference(path: PathNode, reference: String) -> PathNode:
    """Return a path with the referencing type of `reference` added at the
    start: `Type#field#Arg,Arg`, `Type#field` or `Type`."""
    var parts = reference.split("#")
    var field_name = Optional[String](None)
    var args = List[String]()
    if len(parts) > 1:
        field_name = String(parts[1])
    if len(parts) > 2:
        var names = parts[2].split(",")
        var a = 0
        while a < len(names):
            args.append(String(names[a].strip()))
            a += 1
    return path.add_parent(field_name^, args^, String(parts[0]))


def _sort_by_score(mut paths: List[ScoredPath]):
    """Sort by score, highest first, keeping the order of equal scores."""
    var i = 1
    while i < len(paths):
        var j = i
        while j > 0 and paths[j - 1].score < paths[j].score:
            paths.swap_elements(j - 1, j)
            j -= 1
        i += 1


def _boost_shorter_paths(mut paths: List[ScoredPath], factor: Float32):
    """Boost shorter paths, as upstream `boost_shorter_paths`: the shortest
    paths get `factor` more score, the longest none."""
    if len(paths) == 0 or factor == 0:
        return
    var shortest = len(paths[0].inner)
    var longest = shortest
    var i = 1
    while i < len(paths):
        shortest = min(shortest, len(paths[i].inner))
        longest = max(longest, len(paths[i].inner))
        i += 1
    if longest <= shortest:
        return
    var range = Float32(longest - shortest)
    i = 0
    while i < len(paths):
        var normalized = _div(Float32(len(paths[i].inner) - shortest), range)
        var boost = _sub(1.0, normalized)
        paths[i].score = _mul(paths[i].score, _add(1.0, _mul(factor, boost)))
        i += 1


comptime _K1: Float32 = 1.2
"""The BM25 term saturation of tantivy."""
comptime _B: Float32 = 0.75
"""The BM25 length normalization of tantivy."""


# The score arithmetic goes through functions that the compiler does not
# inline, so that each operation rounds to `Float32` in the order of the
# Rust code. Fused or reassociated operations change the last digit of a
# score, which the search results print.


@inline(.never)
def _add(a: Float32, b: Float32) -> Float32:
    """Return `a + b`, rounded once."""
    return a + b


@inline(.never)
def _sub(a: Float32, b: Float32) -> Float32:
    """Return `a - b`, rounded once."""
    return a - b


@inline(.never)
def _mul(a: Float32, b: Float32) -> Float32:
    """Return `a * b`, rounded once."""
    return a * b


@inline(.never)
def _div(a: Float32, b: Float32) -> Float32:
    """Return `a / b`, rounded once."""
    return a / b


@fieldwise_init
struct _TermScorer(Copyable, Movable):
    """One term query of a search: its field, its documents, where it is
    in them, and its BM25 weight."""

    var field: Int
    """The field: 0 `type_name`, 1 `description`, 2 `fields`."""
    var postings: Int
    """The term's position in the field's `postings`."""
    var position: Int
    """The next document, as a position in the postings."""
    var weight: Float32
    """The idf times `k1 + 1`."""
    var average: Float32
    """The average length of the field."""
