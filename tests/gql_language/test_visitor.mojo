# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_language.visitor`, ported from graphql-js 16.14.2
`src/language/__tests__/visitor-test.ts`.

The editing tests are not ported: this walk does not edit (see the module
docstring). The `visitorKeyMap` and named-function tests check JavaScript
call shapes; a Mojo visitor tests the kind itself, as `Recorder` does.
"""

from _fixtures import KITCHEN_SINK_QUERY
from _visit_fixture import KITCHEN_SINK_VISIT
from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.parser import ParseOptions, parse
from gql_language.visitor import (
    ParallelVisitor,
    VisitAction,
    VisitPath,
    Visitor,
    is_list_role,
    visit,
)
from std.memory import ArcPointer
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def value_of(document: Document, node: Int) -> String:
    """Return graphql-js `getValue(node)`, or `-` for none."""
    var kind = document.kind(node)
    if (
        kind == Kind.NAME
        or kind == Kind.INT
        or kind == Kind.FLOAT
        or kind == Kind.ENUM
    ):
        return String(document.text(node))
    if kind == Kind.STRING:
        return document.string_value(node)
    if kind == Kind.BOOLEAN:
        if document.boolean_value(node):
            return String("true")
        return String("false")
    return String("-")


def field_name(document: Document, node: Int) -> String:
    """Return a field's name, or empty for another kind."""
    if document.kind(node) != Kind.FIELD:
        return String("")
    return String(document.name(node))


struct Recorder(Movable, Visitor):
    """Logs each call as graphql-js tests do, and skips or breaks on cue."""

    var log: ArcPointer[List[String]]
    var label: String
    var skip_field: String
    var break_enter_name: String
    var break_leave_name: String
    var break_leave_field: String

    def __init__(out self, log: ArcPointer[List[String]], label: String = ""):
        self.log = log
        self.label = label
        self.skip_field = String("")
        self.break_enter_name = String("")
        self.break_leave_name = String("")
        self.break_leave_field = String("")

    def record(mut self, phase: StaticString, document: Document, node: Int):
        var line = String("")
        if self.label != "":
            line += self.label + " "
        line += String(phase) + " " + String(document.kind(node).text())
        line += " " + value_of(document, node)
        self.log[].append(line^)

    def enter(
        mut self, document: Document, node: Int, path: VisitPath
    ) raises -> VisitAction:
        self.record("enter", document, node)
        if (
            self.skip_field != ""
            and field_name(document, node) == self.skip_field
        ):
            return VisitAction.SKIP
        if (
            self.break_enter_name != ""
            and document.kind(node) == Kind.NAME
            and document.has_text(node, self.break_enter_name)
        ):
            return VisitAction.BREAK
        return VisitAction.CONTINUE

    def leave(
        mut self, document: Document, node: Int, path: VisitPath
    ) raises -> VisitAction:
        self.record("leave", document, node)
        if (
            self.break_leave_name != ""
            and document.kind(node) == Kind.NAME
            and document.has_text(node, self.break_leave_name)
        ):
            return VisitAction.BREAK
        if (
            self.break_leave_field != ""
            and field_name(document, node) == self.break_leave_field
        ):
            return VisitAction.BREAK
        return VisitAction.CONTINUE


struct PathRecorder(Movable, Visitor):
    """Logs graphql-js `path` at each call, and checks the ancestors."""

    var log: List[String]

    def __init__(out self):
        self.log = List[String]()

    def record(
        mut self, phase: StaticString, document: Document, path: VisitPath
    ):
        var keys = path.keys(document)
        var line = String(phase) + " ["
        for index in range(len(keys)):
            if index > 0:
                line += ","
            line += keys[index]
        self.log.append(line + "]")

    def enter(
        mut self, document: Document, node: Int, path: VisitPath
    ) raises -> VisitAction:
        assert_equal(path.node(), node)
        if path.depth() > 0:
            var parent = path.parent()
            var child = document.first_child(parent)
            var found = False
            while child != NO_NODE:
                found = found or child == node
                child = document.next_sibling(child)
            assert_true(found)
        else:
            assert_equal(path.parent(), NO_NODE)
        self.record("enter", document, path)
        return VisitAction.CONTINUE

    def leave(
        mut self, document: Document, node: Int, path: VisitPath
    ) raises -> VisitAction:
        assert_equal(path.node(), node)
        self.record("leave", document, path)
        return VisitAction.CONTINUE


struct KeyRecorder(Movable, Visitor):
    """Logs the kind, key and parent kind, as the kitchen sink test does."""

    var log: List[String]

    def __init__(out self):
        self.log = List[String]()

    def record(
        mut self,
        phase: StaticString,
        document: Document,
        node: Int,
        path: VisitPath,
    ):
        var line = String(phase) + " " + String(document.kind(node).text())
        if path.depth() == 0:
            line += " - -"
        elif path.index() >= 0:
            line += " " + String(path.index()) + " -"
        else:
            line += " " + String(document.role(node).text())
            line += " " + String(document.kind(path.parent()).text())
        self.log.append(line^)

    def enter(
        mut self, document: Document, node: Int, path: VisitPath
    ) raises -> VisitAction:
        self.record("enter", document, node, path)
        return VisitAction.CONTINUE

    def leave(
        mut self, document: Document, node: Int, path: VisitPath
    ) raises -> VisitAction:
        self.record("leave", document, node, path)
        return VisitAction.CONTINUE


def joined(lines: List[String]) -> String:
    """Join lines with line feeds."""
    var out = String("")
    for index in range(len(lines)):
        if index > 0:
            out += "\n"
        out += lines[index]
    return out^


def walk(text: StringSlice, var visitor: Recorder) raises -> String:
    """Walk a document with one recorder; return its log."""
    var log = visitor.log
    visit(parse(text), visitor)
    return joined(log[])


def walk_parallel(
    text: StringSlice, var first: Recorder, var second: Recorder
) raises -> String:
    """Walk a document with two recorders in parallel; return the log."""
    var log = first.log
    var both = ParallelVisitor(first^, second^)
    visit(parse(text), both)
    return joined(log[])


def new_log() -> ArcPointer[List[String]]:
    """Return an empty shared log."""
    return ArcPointer(List[String]())


def test_handles_empty_visitor() raises:
    var recorder = Recorder(new_log())
    visit(parse("{ a }"), recorder)
    assert_equal(len(recorder.log[]), 10)


def test_validates_path_argument() raises:
    var recorder = PathRecorder()
    visit(parse("{ a }"), recorder)
    assert_equal(
        joined(recorder.log),
        "enter []\n"
        + "enter [definitions,0]\n"
        + "enter [definitions,0,selectionSet]\n"
        + "enter [definitions,0,selectionSet,selections,0]\n"
        + "enter [definitions,0,selectionSet,selections,0,name]\n"
        + "leave [definitions,0,selectionSet,selections,0,name]\n"
        + "leave [definitions,0,selectionSet,selections,0]\n"
        + "leave [definitions,0,selectionSet]\n"
        + "leave [definitions,0]\n"
        + "leave []",
    )


comptime ABC = "{ a, b { x }, c }"

comptime SKIPPED_B = """enter Document -
enter OperationDefinition -
enter SelectionSet -
enter Field -
enter Name a
leave Name a
leave Field -
enter Field -
enter Field -
enter Name c
leave Name c
leave Field -
leave SelectionSet -
leave OperationDefinition -
leave Document -"""

comptime BROKE_AT_X = """enter Document -
enter OperationDefinition -
enter SelectionSet -
enter Field -
enter Name a
leave Name a
leave Field -
enter Field -
enter Name b
leave Name b
enter SelectionSet -
enter Field -
enter Name x"""


def test_allows_skipping_a_sub_tree() raises:
    var recorder = Recorder(new_log())
    recorder.skip_field = String("b")
    assert_equal(walk(ABC, recorder^), SKIPPED_B)


def test_allows_early_exit_while_visiting() raises:
    var recorder = Recorder(new_log())
    recorder.break_enter_name = String("x")
    assert_equal(walk(ABC, recorder^), BROKE_AT_X)


def test_allows_early_exit_while_leaving() raises:
    var recorder = Recorder(new_log())
    recorder.break_leave_name = String("x")
    assert_equal(walk(ABC, recorder^), BROKE_AT_X + "\nleave Name x")


def test_visits_only_the_names() raises:
    # graphql-js "allows a named functions visitor API": a visitor that
    # acts on two kinds sees every node and tests the kind.
    var recorder = Recorder(new_log())
    visit(parse(ABC), recorder)
    var names = List[String]()
    for ref line in recorder.log[]:
        if (
            line.startswith("enter Name")
            or line.startswith("enter SelectionSet")
            or line.startswith("leave SelectionSet")
        ):
            names.append(line)
    assert_equal(
        joined(names),
        "enter SelectionSet -\nenter Name a\nenter Name b\n"
        + "enter SelectionSet -\nenter Name x\nleave SelectionSet -\n"
        + "enter Name c\nleave SelectionSet -",
    )


def test_legacy_visits_variables_defined_in_fragments() raises:
    var options = ParseOptions()
    options.allow_legacy_fragment_variables = True
    var recorder = Recorder(new_log())
    visit(
        parse("fragment a($v: Boolean = false) on t { f }", options), recorder
    )
    assert_equal(
        joined(recorder.log[]),
        """enter Document -
enter FragmentDefinition -
enter Name a
leave Name a
enter VariableDefinition -
enter Variable -
enter Name v
leave Name v
leave Variable -
enter NamedType -
enter Name Boolean
leave Name Boolean
leave NamedType -
enter BooleanValue false
leave BooleanValue false
leave VariableDefinition -
enter NamedType -
enter Name t
leave Name t
leave NamedType -
enter SelectionSet -
enter Field -
enter Name f
leave Name f
leave Field -
leave SelectionSet -
leave FragmentDefinition -
leave Document -""",
    )


def test_visits_kitchen_sink() raises:
    var recorder = KeyRecorder()
    visit(parse(KITCHEN_SINK_QUERY), recorder)
    assert_equal(
        joined(recorder.log) + "\n",
        String(KITCHEN_SINK_VISIT[byte=1:]),
    )


def test_visits_a_sub_tree_from_a_given_root() raises:
    var document = parse("{ a { b } }")
    var operation = document.definitions()[0]
    var recorder = Recorder(new_log())
    visit(document, recorder, document.child(operation, Role.SELECTION_SET))
    assert_equal(len(recorder.log[]), 12)
    assert_true(recorder.log[][0].startswith("enter SelectionSet"))


def test_values_and_actions() raises:
    var recorder = Recorder(new_log())
    visit(parse('{ a(i: 1, f: 2.5, s: "x", e: E, b: true) }'), recorder)
    var log = joined(recorder.log[])
    assert_true("enter IntValue 1" in log)
    assert_true("enter FloatValue 2.5" in log)
    assert_true("enter StringValue x" in log)
    assert_true("enter EnumValue E" in log)
    assert_true("enter BooleanValue true" in log)
    assert_equal(String(VisitAction.CONTINUE), "CONTINUE")
    assert_equal(String(VisitAction.SKIP), "SKIP")
    assert_equal(String(VisitAction.BREAK), "BREAK")
    assert_equal(String(VisitAction(3)), "<invalid>")
    assert_true(VisitAction.BREAK.is_valid())
    assert_false(VisitAction(3).is_valid())
    assert_true(is_list_role(Role.SELECTION))
    assert_false(is_list_role(Role.NAME))


def test_list_index_with_interleaved_roles() raises:
    # A built node can hold its list items out of order; each index still
    # counts the earlier items of the same list.
    var document = Document()
    var field = document.add_child(document.root, Kind.FIELD, Role.DEFINITION)
    var first = document.add_child(field, Kind.ARGUMENT, Role.ARGUMENT)
    _ = document.add_child(field, Kind.DIRECTIVE, Role.DIRECTIVE)
    var second = document.add_child(field, Kind.ARGUMENT, Role.ARGUMENT)
    _ = first
    _ = second
    var recorder = KeyRecorder()
    visit(document, recorder)
    assert_equal(
        joined(recorder.log),
        "enter Document - -\nenter Field 0 -\nenter Argument 0 -\n"
        + "leave Argument 0 -\nenter Directive 0 -\nleave Directive 0 -\n"
        + "enter Argument 1 -\nleave Argument 1 -\nleave Field 0 -\n"
        + "leave Document - -",
    )


def test_skipping_or_breaking_the_root() raises:
    var skip = Recorder(new_log())
    skip.skip_field = String("a")
    var document = parse("{ a }")
    var field = document.child(
        document.child(document.definitions()[0], Role.SELECTION_SET),
        Role.SELECTION,
    )
    visit(document, skip, field)
    assert_equal(joined(skip.log[]), "enter Field -")


def test_parallel_allows_skipping_a_sub_tree() raises:
    var first = Recorder(new_log())
    first.skip_field = String("b")
    var log = first.log
    var idle = Recorder(new_log())
    var both = ParallelVisitor(first^, idle^)
    visit(parse(ABC), both)
    assert_equal(joined(log[]), SKIPPED_B)


def test_parallel_allows_skipping_different_sub_trees() raises:
    var log = new_log()
    var no_a = Recorder(log, "no-a")
    no_a.skip_field = String("a")
    var no_b = Recorder(log, "no-b")
    no_b.skip_field = String("b")
    assert_equal(
        walk_parallel("{ a { x }, b { y} }", no_a^, no_b^),
        """no-a enter Document -
no-b enter Document -
no-a enter OperationDefinition -
no-b enter OperationDefinition -
no-a enter SelectionSet -
no-b enter SelectionSet -
no-a enter Field -
no-b enter Field -
no-b enter Name a
no-b leave Name a
no-b enter SelectionSet -
no-b enter Field -
no-b enter Name x
no-b leave Name x
no-b leave Field -
no-b leave SelectionSet -
no-b leave Field -
no-a enter Field -
no-b enter Field -
no-a enter Name b
no-a leave Name b
no-a enter SelectionSet -
no-a enter Field -
no-a enter Name y
no-a leave Name y
no-a leave Field -
no-a leave SelectionSet -
no-a leave Field -
no-a leave SelectionSet -
no-b leave SelectionSet -
no-a leave OperationDefinition -
no-b leave OperationDefinition -
no-a leave Document -
no-b leave Document -""",
    )


def test_parallel_allows_early_exit_while_visiting() raises:
    var first = Recorder(new_log())
    first.break_enter_name = String("x")
    var idle = Recorder(new_log())
    assert_equal(walk_parallel(ABC, first^, idle^), BROKE_AT_X)


def test_parallel_allows_early_exit_from_different_points() raises:
    var log = new_log()
    var break_a = Recorder(log, "break-a")
    break_a.break_enter_name = String("a")
    var break_b = Recorder(log, "break-b")
    break_b.break_enter_name = String("b")
    assert_equal(
        walk_parallel("{ a { y }, b { x } }", break_a^, break_b^),
        """break-a enter Document -
break-b enter Document -
break-a enter OperationDefinition -
break-b enter OperationDefinition -
break-a enter SelectionSet -
break-b enter SelectionSet -
break-a enter Field -
break-b enter Field -
break-a enter Name a
break-b enter Name a
break-b leave Name a
break-b enter SelectionSet -
break-b enter Field -
break-b enter Name y
break-b leave Name y
break-b leave Field -
break-b leave SelectionSet -
break-b leave Field -
break-b enter Field -
break-b enter Name b""",
    )


def test_parallel_allows_early_exit_while_leaving() raises:
    var first = Recorder(new_log())
    first.break_leave_name = String("x")
    var idle = Recorder(new_log())
    assert_equal(
        walk_parallel(ABC, first^, idle^), BROKE_AT_X + "\nleave Name x"
    )


def test_parallel_allows_early_exit_from_leaving_different_points() raises:
    var log = new_log()
    var break_a = Recorder(log, "break-a")
    break_a.break_leave_field = String("a")
    var break_b = Recorder(log, "break-b")
    break_b.break_leave_field = String("b")
    assert_equal(
        walk_parallel("{ a { y }, b { x } }", break_a^, break_b^),
        """break-a enter Document -
break-b enter Document -
break-a enter OperationDefinition -
break-b enter OperationDefinition -
break-a enter SelectionSet -
break-b enter SelectionSet -
break-a enter Field -
break-b enter Field -
break-a enter Name a
break-b enter Name a
break-a leave Name a
break-b leave Name a
break-a enter SelectionSet -
break-b enter SelectionSet -
break-a enter Field -
break-b enter Field -
break-a enter Name y
break-b enter Name y
break-a leave Name y
break-b leave Name y
break-a leave Field -
break-b leave Field -
break-a leave SelectionSet -
break-b leave SelectionSet -
break-a leave Field -
break-b leave Field -
break-b enter Field -
break-b enter Name b
break-b leave Name b
break-b enter SelectionSet -
break-b enter Field -
break-b enter Name x
break-b leave Name x
break-b leave Field -
break-b leave SelectionSet -
break-b leave Field -""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
