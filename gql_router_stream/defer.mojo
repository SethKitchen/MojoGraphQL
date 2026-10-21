# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Streamed `@defer` through the router.

Hive Router `1a29df9` has a `Defer` plan node, but its planner never makes
one and its executor does not run one. This module is the router's own
delivery of `@defer`, in the payload format of the incremental delivery
RFC and graphql-js 17.0.2: `pending`, `incremental`, `completed` and
`hasNext`.

`plan_defer` reads the operation and finds each deferred fragment: an
inline fragment or a fragment spread with `@defer`, whose `if` is not
`false`. It makes two documents:

- **The primary document** has `__typename` in place of each deferred
  fragment, so that no selection set is empty.
- **The full document** has each fragment with its `@defer` removed.

`DeferredResponse.start` runs the primary document through the router and
writes the initial payload at once. Each object at the path of a deferred
fragment gets one `pending` entry, with the path and the label. The added
`__typename` is removed from the data. `DeferredResponse.next` then runs
the full document, and writes one subsequent payload: for each pending
entry, the fields of the fragment that the initial payload does not
have, and the errors below them; then `completed` for each entry.

**Differences from graphql-js.** The deferred fragments of one request
are delivered together, in one payload, when the full document has run.
A nested `@defer` is delivered with its parent. A fragment that has no
field of its own in the response is completed without an `incremental`
entry. A deferred fragment under a type condition gets a pending entry
for each object at its path whose `__typename` is the condition, or that
has a field of the fragment. The `@defer` validation rules do not run.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.parser import parse
from gql_http.body import BodyPoll
from gql_json.parser import parse_bytes
from gql_json.value import NO_NODE as NO_JSON, JsonDocument, JsonKind
from gql_json.writer import write_string
from gql_router.exec_http import SubgraphTransport
from gql_router.exec_value import write_value
from gql_router.federation_spec import OperationKind
from gql_router.pipeline import (
    PipelineError,
    PreparedRequest,
    Router,
    client_error_prefer_ok,
    internal_error,
)
from gql_router.schema_metadata import PossibleTypes


struct DeferSite(Copyable, Movable):
    """One deferred fragment of the operation."""

    var path: List[String]
    """The response keys of the fields from the root to the fragment."""
    var label: String
    """The `label` argument, or empty."""
    var has_label: Bool
    """Whether there is a `label`."""
    var keys: List[String]
    """The response keys of the fields of the fragment."""
    var condition: String
    """The type condition of an inline fragment, or the fragment
    definition, or empty."""
    var keep_typename: Bool
    """Whether the parent selects `__typename` itself."""

    def __init__(out self, var path: List[String]):
        """Start a site at a path.

        Args:
            path: The response keys from the root.
        """
        self.path = path^
        self.label = String()
        self.has_label = False
        self.keys = List[String]()
        self.condition = String()
        self.keep_typename = False


struct DeferPlan(Movable):
    """The documents and the deferred fragments of an operation."""

    var primary: String
    """The document without the deferred fragments."""
    var full: String
    """The document without `@defer`."""
    var sites: List[DeferSite]
    """The deferred fragments, in document order."""

    def __init__(out self):
        """Make an empty plan."""
        self.primary = String()
        self.full = String()
        self.sites = List[DeferSite]()


@fieldwise_init
struct _Edit(Copyable, Movable):
    """A replacement of a byte range of the source."""

    var start: Int
    var end: Int
    var text: String


def has_defer(query: StringSlice) -> Bool:
    """Tell if a document can have `@defer`, without a parse.

    Args:
        query: The document.

    Returns:
        True when the text has `@defer`.
    """
    return query.find("@defer") >= 0


def _key(doc: Document, field: Int) -> String:
    """Return the response key of a field: its alias, or its name."""
    var alias = doc.child(field, Role.ALIAS)
    if alias != NO_NODE:
        return String(doc.text(alias))
    return String(doc.name(field))


def _defer_directive(doc: Document, node: Int) -> Int:
    """Return the `@defer` directive of a fragment, or `NO_NODE`."""
    for directive in doc.children(node, Role.DIRECTIVE):
        if doc.name(directive) == "defer":
            return directive
    return NO_NODE


def _argument(doc: Document, directive: Int, name: StringSlice) -> Int:
    """Return the value of a directive argument, or `NO_NODE`."""
    for argument in doc.children(directive, Role.ARGUMENT):
        if doc.name(argument) == name:
            return doc.child(argument, Role.VALUE)
    return NO_NODE


def _is_active(
    doc: Document, directive: Int, variables: JsonDocument, root: Int
) -> Bool:
    """Tell if `@defer(if:)` defers: a literal `false`, or a variable that
    is `false`, does not."""
    var value = _argument(doc, directive, "if")
    if value == NO_NODE:
        return True
    if doc.kind(value) == Kind.BOOLEAN:
        return doc.boolean_value(value)
    if doc.kind(value) == Kind.VARIABLE and root != NO_JSON:
        var found = variables.find(root, doc.name(value))
        if found != NO_JSON and variables.kind(found) == JsonKind.BOOLEAN:
            return variables.bool_value(found)
    return True


def _fragment(doc: Document, name: StringSlice) -> Int:
    """Return the fragment definition of a name, or `NO_NODE`."""
    # A document has a definition, so the loops are `while` loops.
    var definitions = doc.definitions()
    var index = 0
    while index < len(definitions):
        var definition = definitions[index]
        index += 1
        if (
            doc.kind(definition) == Kind.FRAGMENT_DEFINITION
            and doc.name(definition) == name
        ):
            return definition
    return NO_NODE


def _operation(doc: Document, name: Optional[String]) -> Int:
    """Return the operation of a name, or the first one."""
    var definitions = doc.definitions()
    var index = 0
    while index < len(definitions):
        var definition = definitions[index]
        index += 1
        if doc.kind(definition) != Kind.OPERATION_DEFINITION:
            continue
        if not name or doc.name(definition) == name.value():
            return definition
    return NO_NODE


def _collect_keys(
    doc: Document, set: Int, mut keys: List[String], depth: Int = 0
):
    """Add the response keys of the fields of a selection set, through its
    fragments, deferred or not."""
    if depth > 64:
        return
    # A selection set has a selection.
    var selections = doc.children(set, Role.SELECTION)
    var at = 0
    while at < len(selections):
        var selection = selections[at]
        at += 1
        var kind = doc.kind(selection)
        if kind == Kind.FIELD:
            var key = _key(doc, selection)
            if key not in keys:
                keys.append(key^)
        elif kind == Kind.INLINE_FRAGMENT:
            _collect_keys(
                doc, doc.child(selection, Role.SELECTION_SET), keys, depth + 1
            )
        else:
            var definition = _fragment(doc, doc.name(selection))
            if definition != NO_NODE:
                _collect_keys(
                    doc,
                    doc.child(definition, Role.SELECTION_SET),
                    keys,
                    depth + 1,
                )


def _selects_typename(doc: Document, set: Int) -> Bool:
    """Tell if a selection set has the field `__typename` itself."""
    var selections = doc.children(set, Role.SELECTION)
    var at = 0
    while at < len(selections):
        var selection = selections[at]
        at += 1
        if (
            doc.kind(selection) == Kind.FIELD
            and _key(doc, selection) == "__typename"
        ):
            return True
    return False


def _condition(doc: Document, node: Int) -> String:
    """Return the type condition of a fragment, or empty."""
    var condition = doc.child(node, Role.TYPE_CONDITION)
    if condition == NO_NODE:
        return String()
    return String(doc.name(condition))


def _walk(
    doc: Document,
    set: Int,
    path: List[String],
    variables: JsonDocument,
    root: Int,
    mut edits: List[_Edit],
    mut sites: List[DeferSite],
    depth: Int = 0,
):
    """Find the deferred fragments of a selection set."""
    if depth > 64:
        return
    var selections = doc.children(set, Role.SELECTION)
    var at = 0
    while at < len(selections):
        var selection = selections[at]
        at += 1
        var kind = doc.kind(selection)
        if kind == Kind.FIELD:
            var sub = doc.child(selection, Role.SELECTION_SET)
            if sub != NO_NODE:
                var inner = path.copy()
                inner.append(_key(doc, selection))
                _walk(doc, sub, inner, variables, root, edits, sites, depth + 1)
            continue
        var body = doc.child(selection, Role.SELECTION_SET)
        var condition = _condition(doc, selection)
        if kind == Kind.FRAGMENT_SPREAD:
            var definition = _fragment(doc, doc.name(selection))
            if definition == NO_NODE:
                continue
            body = doc.child(definition, Role.SELECTION_SET)
            condition = _condition(doc, definition)
        var directive = _defer_directive(doc, selection)
        if directive == NO_NODE or not _is_active(
            doc, directive, variables, root
        ):
            _walk(doc, body, path, variables, root, edits, sites, depth + 1)
            continue
        var site = DeferSite(path.copy())
        var label = _argument(doc, directive, "label")
        if label != NO_NODE and doc.kind(label) == Kind.STRING:
            site.label = doc.string_value(label)
            site.has_label = True
        _collect_keys(doc, body, site.keys)
        site.condition = condition^
        site.keep_typename = _selects_typename(doc, set)
        sites.append(site^)
        var start = doc.start(selection)
        var known = False
        for edit in edits:
            if edit.start == start:
                known = True
        if not known:
            edits.append(_Edit(start, doc.end(selection), "__typename"))


def _apply(source: StringSlice, var edits: List[_Edit]) -> String:
    """Replace byte ranges of a text; the ranges do not overlap."""
    # An insertion sort by start; the lists are short.
    for position in range(1, len(edits)):
        var moving = position
        while moving > 0 and edits[moving].start < edits[moving - 1].start:
            edits.swap_elements(moving, moving - 1)
            moving -= 1
    var out = String()
    var at = 0
    for edit in edits:
        out += source[byte = at : edit.start]
        out += edit.text
        at = edit.end
    out += source[byte=at:]
    return out^


def plan_defer(
    query: String,
    operation_name: Optional[String],
    variables: JsonDocument,
    root: Int,
) raises -> DeferPlan:
    """Find the deferred fragments of an operation and make its two
    documents.

    Args:
        query: The document.
        operation_name: The operation to run, or None for the first.
        variables: The request variables, for `@defer(if: $variable)`.
        root: The variables object, or `NO_NODE` of `gql_json`.

    Returns:
        The plan. Without an active deferred fragment, `sites` is empty and
        both documents are the full one.

    Raises:
        Error: When the document does not parse.
    """
    var doc = parse(query)
    var plan = DeferPlan()
    var full_edits = List[_Edit]()
    # A parsed document has nodes.
    var index = 0
    while index < len(doc.nodes):
        if doc.kind(index) == Kind.DIRECTIVE and doc.name(index) == "defer":
            full_edits.append(_Edit(doc.start(index), doc.end(index), ""))
        index += 1
    plan.full = _apply(query, full_edits^)
    var operation = _operation(doc, operation_name)
    var edits = List[_Edit]()
    if operation != NO_NODE:
        _walk(
            doc,
            doc.child(operation, Role.SELECTION_SET),
            List[String](),
            variables,
            root,
            edits,
            plan.sites,
        )
    if len(plan.sites) == 0:
        plan.primary = plan.full
    else:
        plan.primary = _apply(query, edits^)
    return plan^


struct _Pending(Copyable, Movable):
    """One pending entry: a deferred fragment at one object."""

    var site: Int
    var path: List[String]
    var omit: List[String]

    def __init__(out self, site: Int, var path: List[String]):
        self.site = site
        self.path = path^
        self.omit = List[String]()


def _append(mut out: List[UInt8], text: StringSlice):
    """Append the bytes of a text."""
    out.extend(text.as_bytes())


def _key_text(key: StringSlice) -> String:
    """Return the JSON string of a key."""
    var out = List[UInt8]()
    write_string(out, key.as_bytes())
    return String(unsafe_from_utf8=Span(out))


def _targets(
    doc: JsonDocument,
    node: Int,
    site: DeferSite,
    site_index: Int,
    depth: Int,
    prefix: List[String],
    possible: PossibleTypes,
    mut out: List[_Pending],
    mut nodes: List[Int],
):
    """Find the objects at the path of a site, through lists."""
    var kind = doc.kind(node)
    if kind == JsonKind.ARRAY:
        var index = 0
        for item in doc.children(node):
            var inner = prefix.copy()
            inner.append(String(index))
            _targets(
                doc, item, site, site_index, depth, inner, possible, out, nodes
            )
            index += 1
        return
    if kind != JsonKind.OBJECT:
        return
    if depth < len(site.path):
        var child = doc.find(node, site.path[depth])
        if child != NO_JSON:
            var inner = prefix.copy()
            inner.append(_key_text(site.path[depth]))
            _targets(
                doc,
                child,
                site,
                site_index,
                depth + 1,
                inner,
                possible,
                out,
                nodes,
            )
        return
    var typename = doc.find(node, "__typename")
    if (
        site.condition.byte_length() > 0
        and typename != NO_JSON
        and doc.kind(typename) == JsonKind.STRING
        and not possible.entity_satisfies_type_condition(
            doc.string_value(typename), site.condition
        )
    ):
        return
    var pending = _Pending(site_index, prefix.copy())
    if not site.keep_typename:
        pending.omit.append("__typename")
    out.append(pending^)
    nodes.append(node)


def _write_omitting(
    doc: JsonDocument,
    node: Int,
    objects: List[Int],
    omits: List[List[String]],
    mut out: List[UInt8],
):
    """Write a value; the listed objects leave out the listed keys."""
    var kind = doc.kind(node)
    if kind == JsonKind.ARRAY:
        out.append(UInt8(ord("[")))
        var first = True
        for item in doc.children(node):
            if not first:
                out.append(UInt8(ord(",")))
            first = False
            _write_omitting(doc, item, objects, omits, out)
        out.append(UInt8(ord("]")))
        return
    if kind != JsonKind.OBJECT:
        write_value(doc, node, out)
        return
    var skip = List[String]()
    for index in range(len(objects)):
        if objects[index] == node:
            skip.extend(omits[index].copy())
    out.append(UInt8(ord("{")))
    var first = True
    for member in doc.children(node):
        var key = doc.key(member)
        if String(key) in skip:
            continue
        if not first:
            out.append(UInt8(ord(",")))
        first = False
        _append(out, _key_text(key))
        out.append(UInt8(ord(":")))
        _write_omitting(doc, member, objects, omits, out)
    out.append(UInt8(ord("}")))


def _parse_body(body: List[UInt8]) raises -> JsonDocument:
    """Parse a response body of the router."""
    return parse_bytes(body.copy())


struct DeferredResponse(Movable):
    """The payloads of an operation with `@defer`."""

    var initial: List[UInt8]
    """The JSON of the initial payload."""
    var done: Bool
    """Whether no payload follows."""
    var sites: List[DeferSite]
    """The deferred fragments."""
    var pending: List[_Pending]
    """The pending entries; the id of each is its index."""
    var primary: JsonDocument
    """The response of the primary document."""
    var primary_objects: List[Int]
    """The object of each pending entry in `primary`."""
    var full: Optional[PreparedRequest]
    """The full document; its slot is pinned until `next` runs it."""
    var first: List[UInt8]
    """The response of the primary document, before `write_initial`."""
    var full_body: List[UInt8]
    """The response of the full document, when it ran first: for a
    mutation, which must run once."""

    def __init__(out self):
        """Make an empty response."""
        self.initial = List[UInt8]()
        self.done = True
        self.sites = List[DeferSite]()
        self.pending = List[_Pending]()
        self.primary = JsonDocument()
        self.primary_objects = List[Int]()
        self.full = None
        self.full_body = List[UInt8]()
        self.first = List[UInt8]()

    @staticmethod
    def start[
        T: SubgraphTransport
    ](
        mut router: Router[T],
        query: String,
        operation_name: Optional[String],
        var variables: JsonDocument,
        root: Int,
        is_get: Bool,
        stream: Bool = True,
    ) raises PipelineError -> DeferredResponse:
        """Run the primary document and make the initial payload.

        Args:
            router: The router.
            query: The document, with `@defer`.
            operation_name: The operation to run.
            variables: The request variables.
            root: The variables object, or `NO_NODE` of `gql_json`.
            is_get: Whether the request is a `GET`.
            stream: False when the client takes one response: the full
                document runs, and `initial` is its response.

        Returns:
            The response. Without an active deferred fragment, `initial` is
            the whole response and `done` is True.

        Raises:
            PipelineError: The errors of the pipeline.

        Parameters:
            T: The transport of the router.
        """
        var plan: DeferPlan
        try:
            plan = plan_defer(query, operation_name, variables, root)
        except error:
            raise client_error_prefer_ok(
                "Failed to parse GraphQL operation: " + String(error),
                "GRAPHQL_PARSE_FAILED",
            )
        var full = router.prepare_request(
            plan.full, operation_name, variables^, root, is_get, False
        )
        var response = DeferredResponse()
        if len(plan.sites) == 0 or not stream:
            response.initial = router.run_prepared(full).take_body()
            return response^
        var first: List[UInt8]
        if full.kind == OperationKind.MUTATION:
            response.full_body = router.run_prepared(full).take_body()
            first = response.full_body.copy()
        else:
            var primary = router.prepare_coerced(
                plan.primary, operation_name, full.variables, False
            )
            first = router.run_prepared(primary).take_body()
            router.pin(full.slot)
            response.full = full^
        response.first = first^
        response.sites = plan.sites.copy()
        response.done = False
        return response^

    def write_initial(mut self, possible: PossibleTypes) raises:
        """Find the pending entries and write the initial payload.

        Without a deferred fragment, `initial` is the response as it is.

        Args:
            possible: The possible types, for the type conditions.

        Raises:
            Error: When the primary response is not JSON.
        """
        if self.done:
            return
        self.primary = _parse_body(self.first)
        var doc = self.primary.copy()
        var root = doc.root
        var data = doc.find(root, "data")
        if data != NO_JSON:
            # A response that is not done has a site.
            var index = 0
            while index < len(self.sites):
                _targets(
                    doc,
                    data,
                    self.sites[index],
                    index,
                    0,
                    List[String](),
                    possible,
                    self.pending,
                    self.primary_objects,
                )
                index += 1
        var omits = List[List[String]]()
        for ref entry in self.pending:
            if self.full_body:
                # A mutation ran once; its deferred fields wait.
                entry.omit.extend(self.sites[entry.site].keys.copy())
            omits.append(entry.omit.copy())
        var out = List[UInt8]()
        out.append(UInt8(ord("{")))
        var first = True
        for member in doc.children(root):
            if not first:
                out.append(UInt8(ord(",")))
            first = False
            _append(out, _key_text(doc.key(member)))
            out.append(UInt8(ord(":")))
            _write_omitting(doc, member, self.primary_objects, omits, out)
        if not first:
            out.append(UInt8(ord(",")))
        _append(out, '"pending":[')
        for index in range(len(self.pending)):
            if index > 0:
                out.append(UInt8(ord(",")))
            _append(out, '{"id":"' + String(index) + '","path":[')
            _append(out, String(",").join(self.pending[index].path))
            out.append(UInt8(ord("]")))
            ref site = self.sites[self.pending[index].site]
            if site.has_label:
                _append(out, ',"label":' + _key_text(site.label))
            out.append(UInt8(ord("}")))
        _append(
            out,
            '],"hasNext":'
            + ("true" if len(self.pending) > 0 else "false")
            + "}",
        )
        self.done = len(self.pending) == 0
        self.initial = out^

    def next[
        T: SubgraphTransport
    ](mut self, mut router: Router[T], mut out: List[UInt8]) raises -> BodyPoll:
        """Run the full document and write the subsequent payload.

        Args:
            router: The router.
            out: Where the JSON of the payload goes.

        Returns:
            `READY` with the payload, or `DONE` when none follows.

        Raises:
            Error: When the response of the router is not JSON.

        Parameters:
            T: The transport of the router.
        """
        if self.done:
            return BodyPoll.DONE
        self.done = True
        var body = self.full_body.copy()
        var failed = False
        if self.full:
            var full = self.full.take()
            try:
                body = router.run_prepared(full).take_body()
            except error:
                body = List[UInt8](error.body().as_bytes())
                failed = True
            router.unpin(full.slot)
        var doc = _parse_body(body)
        var data = doc.find(doc.root, "data")
        var errors = doc.find(doc.root, "errors")
        _append(out, '{"hasNext":false')
        var entries = List[UInt8]()
        var completed = List[UInt8]()
        # A response that is not done has a pending entry.
        var index = 0
        while index < len(self.pending):
            if index > 0:
                completed.append(UInt8(ord(",")))
            _append(completed, '{"id":"' + String(index) + '"')
            if failed:
                _append(completed, ',"errors":')
                write_value(doc, errors, completed)
            completed.append(UInt8(ord("}")))
            if not failed:
                self._entry(doc, data, errors, index, entries)
            index += 1
        if len(entries) > 0:
            _append(out, ',"incremental":[')
            out.extend(Span(entries))
            out.append(UInt8(ord("]")))
        _append(out, ',"completed":[')
        out.extend(Span(completed))
        _append(out, "]}")
        return BodyPoll.READY

    def _entry(
        self,
        doc: JsonDocument,
        data: Int,
        errors: Int,
        index: Int,
        mut out: List[UInt8],
    ):
        """Write the `incremental` entry of one pending entry, if it has a
        field of its own."""
        ref entry = self.pending[index]
        ref site = self.sites[entry.site]
        var target = data
        var depth = 0
        for segment in entry.path:
            if target == NO_JSON:
                break
            if segment.startswith('"'):
                target = doc.find(target, site.path[depth])
                depth += 1
            else:
                target = doc.at(target, _digits(segment))
        if target == NO_JSON or doc.kind(target) != JsonKind.OBJECT:
            return
        var before = self.primary_objects[index]
        var fields = List[UInt8]()
        var own = List[String]()
        for member in doc.children(target):
            var key = String(doc.key(member))
            var listed = key in site.keys
            var sent = (
                self.primary.find(before, key) != NO_JSON
                and key not in entry.omit
            )
            if not listed or sent:
                continue
            if len(fields) > 0:
                fields.append(UInt8(ord(",")))
            _append(fields, _key_text(key))
            fields.append(UInt8(ord(":")))
            write_value(doc, member, fields)
            own.append(_key_text(key))
        if len(own) == 0:
            return
        if len(out) > 0:
            out.append(UInt8(ord(",")))
        _append(out, '{"id":"' + String(index) + '","data":{')
        out.extend(Span(fields))
        out.append(UInt8(ord("}")))
        var mine = List[UInt8]()
        if errors != NO_JSON:
            for error in doc.children(errors):
                if _below(doc, error, entry.path, own):
                    if len(mine) > 0:
                        mine.append(UInt8(ord(",")))
                    write_value(doc, error, mine)
        if len(mine) > 0:
            _append(out, ',"errors":[')
            out.extend(Span(mine))
            out.append(UInt8(ord("]")))
        out.append(UInt8(ord("}")))


def _digits(text: String) -> Int:
    """Read a list index of a path."""
    var bytes = text.as_bytes()
    var value = 0
    var index = 0
    while index < len(bytes):
        value = value * 10 + Int(bytes[index] - 48)
        index += 1
    return value


def _below(
    doc: JsonDocument, error: Int, path: List[String], own: List[String]
) -> Bool:
    """Tell if an error is under one of the fields of an entry."""
    var found = doc.find(error, "path")
    if found == NO_JSON or doc.kind(found) != JsonKind.ARRAY:
        return False
    var items = doc.children(found)
    if len(items) <= len(path):
        return False
    for index in range(len(path)):
        var text = List[UInt8]()
        write_value(doc, items[index], text)
        if String(unsafe_from_utf8=Span(text)) != path[index]:
            return False
    var next = List[UInt8]()
    write_value(doc, items[len(path)], next)
    return String(unsafe_from_utf8=Span(next)) in own
