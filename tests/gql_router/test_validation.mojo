# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the validation step of the router, `gql_router.validation`.

The cases follow Hive Router `1a29df9`
`bin/router/src/pipeline/validation/mod.rs`, the rule list of
`lib/graphql-tools/src/validation/rules/defaults.rs`, and the codes,
messages and locations of the rules in
`lib/graphql-tools/src/validation/rules/`. The expected response of an
unknown field is the snapshot of `plugin_examples/feature_flags/src/test.rs`:
status 400, and `extensions.code` `FieldsOnCorrectType`. Upstream has no
test of its own for the validation step.

The supergraph is `_validation_supergraph.mojo`. Its
`ProductDimension.unit` has `@inaccessible`, as in the compatibility suite.
"""

from _exec_harness import run_router
from _validation_supergraph import sdl
from gql_json.value import NO_NODE, JsonDocument
from gql_language.parser import parse
from gql_router.exec_http import CannedTransport
from gql_router.pipeline import Router, RouterSchema
from gql_router.validation import (
    LocationPolicy,
    default_rules_validation_plan,
    errors_json,
    location_policy,
    rule_error_code,
    validate_operation,
    validation_schema,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _errors(query: String) raises -> String:
    """Validate one operation against the test supergraph."""
    var schema = validation_schema(parse(sdl()))
    return errors_json(
        validate_operation(
            schema, parse(query), default_rules_validation_plan()
        )
    )


def _error(message: String, code: String, location: String = "") -> String:
    """Write one expected error."""
    var out = String('{"message":"') + message + '"'
    if location.byte_length() > 0:
        out += ',"locations":[' + location + "]"
    return out + ',"extensions":{"code":"' + code + '"}}'


def _at(line: Int, column: Int) -> String:
    """Write one location."""
    return '{"line":' + String(line) + ',"column":' + String(column) + "}"


def _one(message: String, code: String, location: String = "") -> String:
    """Write the body of one expected error."""
    return '{"errors":[' + _error(message, code, location) + "]}"


def test_the_rules_are_the_upstream_default_plan() raises:
    var rules = default_rules_validation_plan()
    var codes: List[String] = [
        "UniqueOperationNames",
        "LoneAnonymousOperation",
        "SingleFieldSubscriptions",
        "KnownTypeNames",
        "FragmentsOnCompositeTypes",
        "VariablesAreInputTypes",
        "LeafFieldSelections",
        "FieldsOnCorrectType",
        "UniqueFragmentNames",
        "KnownFragmentNames",
        "NoUnusedFragments",
        "OverlappingFieldsCanBeMerged",
        "NoFragmentsCycle",
        "PossibleFragmentSpreads",
        "NoUnusedVariables",
        "NoUndefinedVariables",
        "KnownArgumentNames",
        "UniqueArgumentNames",
        "UniqueVariableNames",
        "ProvidedRequiredArguments",
        "KnownDirectives",
        "VariablesInAllowedPosition",
        "ValuesOfCorrectType",
        "UniqueInputFieldNames",
        "UniqueDirectivesPerLocation",
    ]
    assert_equal(len(rules), len(codes))
    var none = 0
    for index in range(len(rules)):
        assert_equal(rule_error_code(rules[index]), codes[index])
        var policy = location_policy(rules[index])
        assert_true(policy.is_valid())
        if policy == LocationPolicy.NONE:
            none += 1
    assert_equal(none, 9)
    assert_true(location_policy(rules[21]) == LocationPolicy.FIRST)
    assert_true(location_policy(rules[24]) == LocationPolicy.LAST)
    assert_true(location_policy(rules[0]) == LocationPolicy.NONE)
    assert_true(location_policy(rules[7]) == LocationPolicy.ALL)
    assert_false(LocationPolicy(4).is_valid())


def test_a_valid_operation_has_no_errors() raises:
    assert_equal(
        _errors('{ product(id: "1") { id sku dimensions { size } } }'),
        '{"errors":[]}',
    )


def test_an_inaccessible_field_is_an_unknown_field() raises:
    assert_equal(
        _errors('{ product(id: "1") { dimensions { unit } } }'),
        _one(
            'Cannot query field \\"unit\\" on type \\"ProductDimension\\".',
            "FieldsOnCorrectType",
            _at(1, 35),
        ),
    )
    assert_equal(
        _errors("{ secret }"),
        _one(
            'Cannot query field \\"secret\\" on type \\"Query\\".',
            "FieldsOnCorrectType",
            _at(1, 3),
        ),
    )
    assert_equal(
        _errors("{ products(filter: {color: BLUE, limit: 1}) { id } }"),
        _one(
            'Value \\"BLUE\\" does not exist in \\"Color\\" enum.',
            "ValuesOfCorrectType",
        ),
    )


def test_an_unknown_field_has_no_suggestion() raises:
    # graphql-js adds `Did you mean "sku"?`; `graphql_tools` does not.
    assert_equal(
        _errors('{ product(id: "1") { skuu } }'),
        _one(
            'Cannot query field \\"skuu\\" on type \\"Product\\".',
            "FieldsOnCorrectType",
            _at(1, 22),
        ),
    )


def test_a_field_that_starts_with_two_underscores_is_not_reported() raises:
    assert_equal(_errors('{ product(id: "1") { __foo } }'), '{"errors":[]}')


def test_the_errors_keep_the_order_of_the_walk() raises:
    assert_equal(
        _errors('{ product(id: "1", bad: 1) { nope } }'),
        '{"errors":['
        + _error(
            'Unknown argument \\"bad\\" on field \\"Query.product\\".',
            "KnownArgumentNames",
        )
        + ","
        + _error(
            'Cannot query field \\"nope\\" on type \\"Product\\".',
            "FieldsOnCorrectType",
            _at(1, 30),
        )
        + "]}",
    )


def test_directive_messages() raises:
    assert_equal(
        _errors(
            '{ product(id: "1") @skip(if: false) @skip(if: false) { id } }'
        ),
        _one(
            'Duplicate directive \\"skip\\"',
            "UniqueDirectivesPerLocation",
            _at(1, 37),
        ),
    )
    assert_equal(
        _errors('{ product(id: "1") @deprecated { id } }'),
        _one(
            'Directive \\"@deprecated\\" may not be used on FIELD',
            "KnownDirectives",
            _at(1, 20),
        ),
    )
    assert_equal(
        _errors('{ product(id: "1") @nope { id } }'),
        _one('Unknown directive \\"@nope\\".', "KnownDirectives", _at(1, 20)),
    )


def test_variable_messages() raises:
    var unused = _error(
        'Variable \\"$a\\" is never used in operation \\"Q\\".',
        "NoUnusedVariables",
    )
    assert_equal(
        _errors('query Q($a: Int, $a: Int) { product(id: "1") { id } }'),
        '{"errors":['
        + _error(
            'There can only be one variable named \\"$a\\".',
            "UniqueVariableNames",
            _at(1, 10) + "," + _at(1, 19),
        )
        + ","
        + unused
        + ","
        + unused
        + "]}",
    )
    assert_equal(
        _errors("query Q($id: ID) { product(id: $id) { id } }"),
        _one(
            (
                'Variable \\"$id\\" of type \\"ID\\" used in position expecting'
                ' type \\"ID!\\".'
            ),
            "VariablesInAllowedPosition",
            _at(1, 9),
        ),
    )
    assert_equal(
        _errors("query ($v: Int) { products(first: $u) { id } }"),
        '{"errors":['
        + _error('Variable \\"$v\\" is never used.', "NoUnusedVariables")
        + ","
        + _error('Variable \\"$u\\" is not defined.', "NoUndefinedVariables")
        + "]}",
    )
    assert_equal(
        _errors("query ($f: Product) { products { id } }"),
        '{"errors":['
        + _error(
            'Variable \\"$f\\" cannot be non-input type \\"Product\\".',
            "VariablesAreInputTypes",
            _at(1, 12),
        )
        + ","
        + _error('Variable \\"$f\\" is never used.', "NoUnusedVariables")
        + "]}",
    )


def _value_error(message: String) -> String:
    """Write the body of one `ValuesOfCorrectType` error."""
    return _one(message, "ValuesOfCorrectType")


def test_value_messages() raises:
    assert_equal(
        _errors('{ products(first: "x") { id } }'),
        _value_error('Expected value of type \\"Int\\", found \\"x\\".'),
    )
    assert_equal(
        _errors("{ products(first: 1.5, tags: [true]) { id } }"),
        '{"errors":['
        + _error(
            'Expected value of type \\"Int\\", found 1.5.',
            "ValuesOfCorrectType",
        )
        + ","
        + _error(
            'Expected value of type \\"String\\", found true.',
            "ValuesOfCorrectType",
        )
        + "]}",
    )
    assert_equal(
        _errors("{ product(id: true) { id } }"),
        _value_error('Expected value of type \\"ID\\", found true.'),
    )
    assert_equal(
        _errors("{ products(tags: 1.5, first: GREEN) { id } }"),
        '{"errors":['
        + _error(
            'Expected value of type \\"String\\", found 1.5.',
            "ValuesOfCorrectType",
        )
        + ","
        + _error(
            'Expected value of type \\"Int\\", found GREEN.',
            "ValuesOfCorrectType",
        )
        + "]}",
    )
    assert_equal(
        _errors("{ products(filter: {color: PINK, limit: 1}) { id } }"),
        _value_error('Value \\"PINK\\" does not exist in \\"Color\\" enum.'),
    )
    assert_equal(
        _errors('{ products(filter: {color: "RED", limit: 1}) { id } }'),
        _value_error(
            'Enum \\"Color\\" cannot represent non-enum value: \\"RED\\"'
        ),
    )
    assert_equal(
        _errors("{ product(id: null) { id } }"),
        _value_error('Expected value of type \\"ID!\\", found null'),
    )
    assert_equal(
        _errors("{ products(filter: 1) { id } }"),
        _value_error('Expected value of type \\"Filter\\", found 1.'),
    )
    # graphql-js writes `[Filter!]`; `graphql_tools` writes the named type.
    assert_equal(
        _errors("{ products(filters: true) { id } }"),
        _value_error('Expected value of type \\"Filter\\", found true.'),
    )
    assert_equal(
        _errors("{ products(first: 99999999999) { id } }"),
        _value_error(
            "Int cannot represent non 32-bit signed integer value: 99999999999"
        ),
    )
    assert_equal(
        _errors("{ products(filter: {colr: RED, limit: 1}) { id } }"),
        _value_error('Field \\"colr\\" is not defined by type \\"Filter\\".'),
    )
    assert_equal(
        _errors("{ products(filter: {}) { id } }"),
        _value_error(
            'Field \\"Filter.limit\\" of required type \\"Int!\\" was not'
            " provided."
        ),
    )


def test_selection_and_fragment_messages() raises:
    assert_equal(
        _errors('{ product(id: "1") }'),
        _one(
            (
                'Field \\"product\\" of type \\"Product\\" must have a'
                ' selection of subfields. Did you mean \\"product { ... }\\"?'
            ),
            "LeafFieldSelections",
            _at(1, 3),
        ),
    )
    assert_equal(
        _errors('{ product(id: "1") { ...A } } fragment A on Product { ...A }'),
        _one(
            'Cannot spread fragment \\"A\\" within itself.',
            "NoFragmentsCycle",
            _at(1, 55),
        ),
    )
    assert_equal(
        _errors(
            '{ product(id: "1") { ...F } } fragment F on ProductDimension'
            " { size }"
        ),
        _one(
            (
                'Fragment \\"F\\" cannot be spread here as objects of type'
                ' \\"Product\\" can never be of type \\"ProductDimension\\".'
            ),
            "PossibleFragmentSpreads",
        ),
    )
    var unused = _error('Fragment \\"X\\" is never used.', "NoUnusedFragments")
    assert_equal(
        _errors(
            "{ products(filter: {limit: 1, limit: 2}) { id } }"
            " fragment X on Product { id } fragment X on Product { id }"
        ),
        '{"errors":['
        + _error(
            'There can be only one input field named \\"limit\\".',
            "UniqueInputFieldNames",
        )
        + ","
        + _error(
            'There can be only one fragment named \\"X\\".',
            "UniqueFragmentNames",
        )
        + ","
        + unused
        + ","
        + unused
        + "]}",
    )
    assert_equal(
        _errors("{ products { ... on Nope { id } } }"),
        _one('Unknown type \\"Nope\\".', "KnownTypeNames", _at(1, 21)),
    )
    assert_equal(
        _errors("query A { products { id } } query A { products { id } }"),
        _one(
            'There can be only one operation named \\"A\\".',
            "UniqueOperationNames",
        ),
    )


def test_the_router_rejects_an_inaccessible_field() raises:
    var query = '{ product(id: "1") { dimensions { unit } } }'
    var body = _one(
        'Cannot query field \\"unit\\" on type \\"ProductDimension\\".',
        "FieldsOnCorrectType",
        _at(1, 35),
    )
    # Upstream answers 400, or 200 when the response type is
    # `application/json`.
    assert_equal(
        run_router(sdl(), CannedTransport(), query, prefer_ok=False),
        "400 " + body,
    )
    assert_equal(run_router(sdl(), CannedTransport(), query), "200 " + body)


def test_the_router_rejects_an_unknown_field_and_an_invalid_operation() raises:
    assert_equal(
        run_router(
            sdl(),
            CannedTransport(),
            '{ product(id: "1") { skuu } }',
            prefer_ok=False,
        ),
        "400 "
        + _one(
            'Cannot query field \\"skuu\\" on type \\"Product\\".',
            "FieldsOnCorrectType",
            _at(1, 22),
        ),
    )
    assert_equal(
        run_router(
            sdl(),
            CannedTransport(),
            "query ($v: Int) { products(first: $u) { id } }",
            prefer_ok=False,
        ),
        '400 {"errors":['
        + _error('Variable \\"$v\\" is never used.', "NoUnusedVariables")
        + ","
        + _error('Variable \\"$u\\" is not defined.', "NoUndefinedVariables")
        + "]}",
    )


def _run(
    mut router: Router[CannedTransport],
    query: String,
    operation_name: Optional[String] = None,
) -> String:
    """Run one request through a router that is kept between requests."""
    var response = router.execute(
        query, operation_name, JsonDocument(), NO_NODE, False, False
    )
    return (
        String(response.status) + " " + String(unsafe_from_utf8=response.body^)
    )


def test_the_router_caches_each_validation_result() raises:
    var router = Router(RouterSchema(sdl()), CannedTransport())
    var invalid = "{ secret }"
    var first = _run(router, invalid)
    assert_true(first.startswith("400 "))
    # The second request finds the errors in the cache.
    assert_equal(_run(router, invalid), first)
    assert_equal(router.validated.entry_count(0), 1)
    # Two operations of one document share one validation result.
    var document = (
        "query A { __schema { queryType { name } } }"
        " query B { __schema { queryType { name } } }"
    )
    var answer = '200 {"data":{"__schema":{"queryType":{"name":"Query"}}}}'
    assert_equal(_run(router, document, String("A")), answer)
    assert_equal(_run(router, document, String("B")), answer)
    assert_equal(router.validated.entry_count(0), 2)
    assert_equal(len(router.slots), 2)


def test_a_check_that_raises_is_a_validation_failure() raises:
    # `gql_validation` raises for `@skip` with no `if` on a subscription
    # field.
    var out = run_router(
        sdl(),
        CannedTransport(),
        "subscription { productAdded @skip { id } }",
        prefer_ok=False,
    )
    assert_true(out.startswith('400 {"errors":[{"message":"'))
    assert_true("GRAPHQL_VALIDATION_FAILED" in out)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
