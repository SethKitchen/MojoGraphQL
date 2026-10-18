# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The errors of the Apollo Kotlin compiler and of its validation.

Ports:

- `libraries/apollo-compiler/src/test/kotlin/com/apollographql/apollo/
  compiler/CheckCapitalizedFieldsTest.kt` with the fixtures of
  `src/test/validation/operation/capitalized_fields/`: the issues, kinds
  and messages, exactly.
- `libraries/apollo-ast/src/jvmTest/kotlin/com/apollographql/apollo/
  graphql/ast/test/ExecutableValidationTest.kt` with the top-level
  fixtures of `test-fixtures/validation/executable/`: the place of each
  issue. The messages are the graphql-js messages of `gql_validation`, so
  only the line and column are compared.
"""

from std.testing import TestSuite, assert_equal, assert_true

from gql_language.parser import parse

from gql_codegen.checks import check_capitalized_fields
from gql_codegen.compiler import CodegenDocument, build_codegen_schema, compile
from gql_codegen.issues import Issue, serialize

from _fixtures import read


def capitalized(name: String) raises -> String:
    """Run the capitalized fields check on a fixture, as upstream.

    Args:
        name: The fixture, such as `capitalized_fields_allowed`.

    Returns:
        The serialized issues.

    Raises:
        Error: If the fixture does not parse.
    """
    var document = parse(
        read("capitalized_fields_validation/" + name + ".graphql")
    )
    var fragments_only = not name.startswith("capitalized_fields_disallowed")
    return serialize(check_capitalized_fields(document, fragments_only))


def expected_capitalized(name: String) raises -> String:
    """Read the expected issues of a capitalized fields fixture.

    Args:
        name: The fixture.

    Returns:
        The text of the `.expected` file.

    Raises:
        Error: If the file cannot be read.
    """
    return read("capitalized_fields_validation/" + name + ".expected")


def test_capitalized_fields_allowed() raises:
    assert_equal(
        capitalized("capitalized_fields_allowed"),
        expected_capitalized("capitalized_fields_allowed"),
    )


def test_capitalized_fields_allowed_with_fragment_spread() raises:
    assert_equal(
        capitalized("capitalized_fields_allowed_with_fragment_spread"),
        expected_capitalized("capitalized_fields_allowed_with_fragment_spread"),
    )


def test_capitalized_fields_disallowed() raises:
    assert_equal(
        capitalized("capitalized_fields_disallowed"),
        expected_capitalized("capitalized_fields_disallowed"),
    )


def test_capitalized_fields_disallowed_with_fragment_spread() raises:
    assert_equal(
        capitalized("capitalized_fields_disallowed_with_fragment_spread"),
        expected_capitalized(
            "capitalized_fields_disallowed_with_fragment_spread"
        ),
    )


comptime VALIDATION: Array[StaticString, 20] = [
    "ArgumentNonOptional",
    "BadDirectiveArgument",
    "CircularFragmentReference",
    "DuplicateOperation",
    "FragmentDuplication",
    "FragmentUnknownType",
    "InlineFragmentCanNotBeSpread",
    "InlineFragmentUnknonwType",
    "InputObjectFieldNonOptional",
    "InputObjectFieldTypeMismatch",
    "InputObjectListFieldTypeMismatch",
    "MissingDirective",
    "MissingDirectiveArgument",
    "MissingSelectionSet",
    "QueryUnknowField",
    "SyntaxError",
    "TypeSystemDefinition",
    "UnusedVariable",
    "VariableMissing",
    "VariableTypeMismatch",
]
"""The top-level fixtures of `test-fixtures/validation/executable/`."""


def places(issues: List[Issue]) -> String:
    """Return the `line:column` of each issue, one per line, sorted."""
    var out = List[String]()
    for ref issue in issues:
        out.append(String(issue.line) + ":" + String(issue.column))
    sort(out)
    return "\n".join(out)


def expected_places(name: String) raises -> String:
    """Read the places of the issues of an upstream `.expected` file.

    Args:
        name: The fixture.

    Returns:
        The `line:column` of each issue, one per line, sorted.

    Raises:
        Error: If the file cannot be read.
    """
    var out = List[String]()
    for line in read("validation/" + name + ".expected").split("\n"):
        var open = line.find(" (")
        if open < 0 or not line.endswith(")"):
            continue
        out.append(String(line[byte = open + 2 : line.byte_length() - 1]))
    sort(out)
    return "\n".join(out)


def places_of(name: String) raises -> String:
    """Compile a validation fixture, and return the places of its errors
    and warnings.

    Args:
        name: The fixture.

    Returns:
        The `line:column` of each issue, one per line, sorted.

    Raises:
        Error: If a file cannot be read.
    """
    # The upstream schema has interfaces that implement interfaces without
    # their objects implementing both: `apollo-ast` accepts it.
    var schema = build_codegen_schema(
        read("validation/schema.graphqls"), check=False
    )
    var documents = List[CodegenDocument]()
    documents.append(
        CodegenDocument(name, read("validation/" + name + ".graphql"))
    )
    var result = compile(schema, documents)
    var issues = result.errors.copy()
    issues.extend(result.warnings.copy())
    assert_true(len(issues) > 0, name)
    return places(issues)


comptime OTHER_PLACES: Array[StaticString, 14] = [
    # graphql-js reports the first spread of the cycle; upstream the last.
    "CircularFragmentReference",
    "9:5",
    # graphql-js reports the first operation's name first; upstream the
    # second operation.
    "DuplicateOperation",
    "1:7",
    # graphql-js reports the first fragment's name first, and both
    # fragments as unused; upstream reports the second fragment.
    "FragmentDuplication",
    "11:1\n7:1\n7:10",
    # graphql-js reports the inline fragment; upstream its type condition.
    "InlineFragmentCanNotBeSpread",
    "3:5",
    # graphql-js reports a variable in the wrong position at its
    # definition first; upstream at its use.
    "InputObjectFieldNonOptional",
    "1:20\n2:24\n2:24",
    "InputObjectFieldTypeMismatch",
    "1:20\n2:24\n2:24",
    "InputObjectListFieldTypeMismatch",
    "1:20\n2:24\n2:24",
]
"""The fixtures where the first location of a graphql-js error is another
place than the upstream issue, with the graphql-js places."""


def test_validation_places_as_upstream() raises:
    var names = materialize[VALIDATION]()
    var other = materialize[OTHER_PLACES]()
    var checked = 0
    for index in range(len(names)):
        var name = String(names[index])
        var differs = name == "VariableTypeMismatch"
        for at in range(0, len(other), 2):
            if name == other[at]:
                differs = True
        if differs:
            continue
        assert_equal(places_of(name), expected_places(name), name)
        checked += 1
    assert_equal(checked, 12)


def test_validation_places_of_graphql_js() raises:
    var other = materialize[OTHER_PLACES]()
    for at in range(0, len(other), 2):
        var name = String(other[at])
        assert_equal(places_of(name), String(other[at + 1]), name)
    # The variable definition, where upstream reports the use at 2:17.
    assert_equal(places_of("VariableTypeMismatch"), "1:17")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
