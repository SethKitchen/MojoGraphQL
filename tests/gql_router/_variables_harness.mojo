# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The harness of the variable coercion tests.

Port of Hive Router `1a29df9`
`bin/router/src/executor/variables/tests/harness.rs`.

`Harness.coerce` normalizes an operation with `Planner.normalize`, parses
the JSON variables with `gql_json`, and calls the real
`collect_variables`.

**Differences from upstream.** Upstream reads the metadata from the
consumer schema. This harness reads it from the supergraph document; the
fixture has no `@inaccessible`, so the input types and the enums are the
same. Upstream also runs `partition_operation`; the partition does not
change the variable definitions, so the harness does not run it.
`assert_rejected_by_validation` runs one `gql_validation` rule, named as
the graphql-tools error code, against a schema built from the supergraph.
"""

from _fixtures import variables_coercion
from gql_json.parser import parse as parse_json
from gql_json.value import NO_NODE, JsonDocument, JsonKind
from gql_json.writer import write_string
from gql_language.parser import parse
from gql_router.exec_variables import CoerceVariablesPayload, collect_variables
from gql_router.planner import Planner
from gql_router.schema_metadata import SchemaMetadata, schema_metadata
from gql_schema.build import build_schema
from gql_validation.rules import ValidationRule
from gql_validation.validate import validate
from std.testing import assert_equal, assert_false, assert_true


struct Outcome(Movable):
    """What coercion produced for a request, as upstream `Outcome`."""

    var rejected: Bool
    """True for a request error."""
    var message: String
    """The request error message, when rejected."""
    var coerced: String
    """The coerced variables in a canonical form, when accepted."""
    var forwarded: String
    """The coerced variables as their source JSON, keys sorted."""
    var is_some: Bool
    """The `is_some` of the payload."""

    def __init__(out self, message: String):
        """Make a rejection.

        Args:
            message: The error message.
        """
        self.rejected = True
        self.message = message
        self.coerced = String()
        self.forwarded = String()
        self.is_some = False

    def __init__(out self, payload: CoerceVariablesPayload):
        """Read an accepted payload.

        Args:
            payload: The coerced variables.
        """
        self.rejected = False
        self.message = String()
        var names = payload.names.copy()
        _sort(names)
        var coerced = String("{")
        var forwarded = String("{")
        var index = 0
        while index < len(names):
            if index > 0:
                coerced += ","
                forwarded += ","
            var node = payload.variable(names[index])
            coerced += names[index] + ":"
            _canonical(coerced, payload.document, node)
            _quote(forwarded, names[index])
            forwarded += ":"
            _source(forwarded, payload.document, node)
            index += 1
        self.coerced = coerced + "}"
        self.forwarded = forwarded + "}"
        self.is_some = payload.is_some


def _sort(mut names: List[String]):
    """Sort names in byte order (insertion sort)."""
    var index = 1
    while index < len(names):
        var at = index
        while at > 0 and names[at - 1] > names[at]:
            names.swap_elements(at - 1, at)
            at -= 1
        index += 1


def _quote(mut out: String, text: String):
    """Append a JSON string."""
    var bytes = List[UInt8]()
    write_string(bytes, text.as_bytes())
    out += String(unsafe_from_utf8=bytes)


def _members(document: JsonDocument, node: Int) -> List[Int]:
    """Return the members of an object, sorted by key."""
    var members = List[Int]()
    var member = document.first(node)
    while member != NO_NODE:
        var at = len(members)
        members.append(member)
        while at > 0 and document.key(members[at - 1]) > document.key(
            members[at]
        ):
            members.swap_elements(at - 1, at)
            at -= 1
        member = document.next(member)
    return members^


def _canonical(mut out: String, document: JsonDocument, node: Int):
    """Append a form that is equal for equal `sonic_rs` values: integers
    and floats differ, object keys are sorted."""
    var kind = document.kind(node)
    if kind == JsonKind.NUMBER:
        var text = String(document.text(node))
        if (
            "." in text
            or "e" in text
            or "E" in text
            or text == "-0"
            or len(text.as_bytes()) > 20
        ):
            var value = document.as_float64(node)
            if value == 0.0:
                value = 0.0
            out += "f" + String(value)
        else:
            out += "i" + text
    elif kind == JsonKind.STRING:
        _quote(out, document.string_value(node))
    elif kind == JsonKind.ARRAY:
        out += "["
        var item = document.first(node)
        while item != NO_NODE:
            if item != document.first(node):
                out += ","
            _canonical(out, document, item)
            item = document.next(item)
        out += "]"
    elif kind == JsonKind.OBJECT:
        out += "{"
        var members = _members(document, node)
        for index in range(len(members)):
            if index > 0:
                out += ","
            _quote(out, document.key(members[index]))
            out += ":"
            _canonical(out, document, members[index])
        out += "}"
    elif kind == JsonKind.BOOLEAN:
        out += "true" if document.bool_value(node) else "false"
    else:
        out += "null"


def _source(mut out: String, document: JsonDocument, node: Int):
    """Append a value as its source JSON: numbers and escaped strings keep
    their text."""
    var kind = document.kind(node)
    if kind == JsonKind.NUMBER:
        out += document.text(node)
    elif kind == JsonKind.STRING:
        if document.has_escapes(node):
            out += '"' + String(document.text(node)) + '"'
        else:
            _quote(out, document.string_value(node))
    elif kind == JsonKind.ARRAY:
        out += "["
        var item = document.first(node)
        while item != NO_NODE:
            if item != document.first(node):
                out += ","
            _source(out, document, item)
            item = document.next(item)
        out += "]"
    elif kind == JsonKind.OBJECT:
        out += "{"
        var member = document.first(node)
        while member != NO_NODE:
            if member != document.first(node):
                out += ","
            _quote(out, document.key(member))
            out += ":"
            _source(out, document, member)
            member = document.next(member)
        out += "}"
    elif kind == JsonKind.BOOLEAN:
        out += "true" if document.bool_value(node) else "false"
    else:
        out += "null"


def expected_form(expected: String) raises -> String:
    """Return the canonical form of an expected JSON object.

    Args:
        expected: A JSON object.

    Returns:
        The form that `Outcome.coerced` has for equal values.

    Raises:
        Error: When the text is not a JSON object.
    """
    var document = parse_json(expected)
    assert_true(document.kind(0) == JsonKind.OBJECT, "expected an object")
    var members = _members(document, 0)
    var out = String("{")
    for index in range(len(members)):
        if index > 0:
            out += ","
        out += document.key(members[index]) + ":"
        _canonical(out, document, members[index])
    return out + "}"


def assert_invalid_json(variables: String) raises:
    """Assert that the JSON parser refuses `variables`, so the request
    fails before coercion runs.

    Args:
        variables: The JSON text.

    Raises:
        Error: When the text parses.
    """
    var failed = False
    try:
        _ = parse_json(variables)
    except:
        failed = True
    assert_true(failed, String("expected invalid JSON: ", variables))


def _rule(name: String) raises -> ValidationRule:
    """Return the rule of a graphql-tools error code."""
    if name == "ValuesOfCorrectType":
        return ValidationRule.VALUES_OF_CORRECT_TYPE
    if name == "VariablesInAllowedPosition":
        return ValidationRule.VARIABLES_IN_ALLOWED_POSITION
    if name == "UniqueVariableNames":
        return ValidationRule.UNIQUE_VARIABLE_NAMES
    if name == "VariablesAreInputTypes":
        return ValidationRule.VARIABLES_ARE_INPUT_TYPES
    if name == "KnownTypeNames":
        return ValidationRule.KNOWN_TYPE_NAMES
    assert_equal(name, "ProvidedRequiredArguments")
    return ValidationRule.PROVIDED_REQUIRED_ARGUMENTS


struct Harness(Movable):
    """The fixture planner and metadata, built once for a test."""

    var planner: Planner
    """The planner of the fixture supergraph."""
    var metadata: SchemaMetadata
    """The schema metadata of the fixture."""

    def __init__(out self) raises:
        """Read the fixture supergraph.

        Raises:
            Error: When the fixture does not parse.
        """
        var sdl = variables_coercion.sdl()
        self.planner = Planner(sdl)
        self.metadata = schema_metadata(parse(sdl))

    def coerce(
        mut self, operation: String, variables: String
    ) raises -> Outcome:
        """Coerce `variables` (a JSON object) for `operation`, without
        validation first, as upstream `coerce`.

        Args:
            operation: The operation document.
            variables: The JSON object of the variables.

        Returns:
            The outcome.

        Raises:
            Error: When the operation or the variables do not parse.
        """
        var normalized = self.planner.normalize(operation)
        var document = parse_json(variables)
        try:
            var payload = collect_variables(
                self.planner.store, normalized, document^, 0, self.metadata
            )
            return Outcome(payload)
        except error:
            return Outcome(String(error))

    def assert_coerced(
        mut self, operation: String, variables: String, expected: String
    ) raises:
        """Assert that coercion accepts `variables` and produces
        `expected` (a JSON object).

        Args:
            operation: The operation document.
            variables: The JSON object of the variables.
            expected: The JSON object of the coerced variables.

        Raises:
            Error: When the outcome differs.
        """
        var outcome = self.coerce(operation, variables)
        assert_false(
            outcome.rejected,
            String(outcome.message, "\noperation: ", operation),
        )
        assert_equal(
            outcome.coerced,
            expected_form(expected),
            String("\noperation: ", operation, "\nvariables: ", variables),
        )

    def assert_forwarded(
        mut self, operation: String, variables: String, expected: String
    ) raises:
        """Assert that coercion accepts `variables` and that the coerced
        variables serialize to exactly `expected`, keys sorted.

        Args:
            operation: The operation document.
            variables: The JSON object of the variables.
            expected: The JSON text sent to subgraphs.

        Raises:
            Error: When the outcome differs.
        """
        var outcome = self.coerce(operation, variables)
        assert_false(
            outcome.rejected,
            String(outcome.message, "\noperation: ", operation),
        )
        assert_equal(outcome.forwarded, expected)

    def assert_rejected(
        mut self, operation: String, variables: String, expected: String
    ) raises:
        """Assert that coercion rejects `variables` with one request error,
        `expected`.

        Args:
            operation: The operation document.
            variables: The JSON object of the variables.
            expected: The error message.

        Raises:
            Error: When the outcome differs.
        """
        var outcome = self.coerce(operation, variables)
        assert_true(
            outcome.rejected,
            String("expected a rejection\noperation: ", operation),
        )
        assert_equal(outcome.message, expected)

    def assert_rejected_by_validation(
        self, operation: String, rule: String
    ) raises:
        """Assert that validation rejects `operation` with an error of
        `rule`, a graphql-tools error code such as `ValuesOfCorrectType`.

        Args:
            operation: The operation document.
            rule: The error code.

        Raises:
            Error: When the rule finds no error.
        """
        var schema = build_schema(variables_coercion.sdl())
        var rules = List[ValidationRule]()
        rules.append(_rule(rule))
        var errors = validate(schema, parse(operation), rules)
        assert_true(
            len(errors) > 0,
            String("expected a ", rule, " error\noperation: ", operation),
        )
