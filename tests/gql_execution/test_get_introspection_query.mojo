# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `get_introspection_query`, ported from graphql-js 16.14.2
`src/utilities/__tests__/getIntrospectionQuery-test.ts`.

Every upstream case is ported, with the same word counts. Upstream also
validates each query against a dummy schema; validation is the
`gql_validation` package, so this port executes each query against the
dummy schema and checks that there is no error. The cases at the end
compare the whole text with graphql-js 16.14.2 for the defaults and two
other option sets.
"""


from std.testing import TestSuite, assert_equal, assert_false, assert_true
from _helpers import run
from gql_execution.introspection import (
    IntrospectionOptions,
    get_introspection_query,
)


def _is_word(byte: UInt8) -> Bool:
    return (
        (byte >= 48 and byte <= 57)
        or (byte >= 65 and byte <= 90)
        or (byte >= 97 and byte <= 122)
        or byte == 95
    )


def _count(text: String, word: String) -> Int:
    """Count `\\bword\\b` in a text, as the upstream regular expression."""
    var bytes = text.as_bytes()
    var size = word.byte_length()
    var total = 0
    var start = 0
    while True:
        var at = text.find(word, start)
        if at < 0:
            return total
        var before = at == 0 or not _is_word(bytes[at - 1])
        var end = at + size
        var after = end >= len(bytes) or not _is_word(bytes[end])
        if before and after:
            total += 1
        start = at + 1


def expect_query(
    options: IntrospectionOptions, word: String, times: Int
) raises:
    var query = get_introspection_query(options)
    assert_equal(_count(query, word), times)
    var result = run("type Query { dummy: String }", query)
    assert_false('"errors"' in result)


def test_skip_all_description_fields() raises:
    var options = IntrospectionOptions()
    expect_query(options, "description", 5)
    options.descriptions = True
    expect_query(options, "description", 5)
    options.descriptions = False
    expect_query(options, "description", 0)


def test_include_is_repeatable_field_on_directives() raises:
    var options = IntrospectionOptions()
    expect_query(options, "isRepeatable", 0)
    options.directive_is_repeatable = True
    expect_query(options, "isRepeatable", 1)
    options.directive_is_repeatable = False
    expect_query(options, "isRepeatable", 0)


def test_include_description_field_on_schema() raises:
    var options = IntrospectionOptions()
    expect_query(options, "description", 5)
    options.schema_description = False
    expect_query(options, "description", 5)
    options.schema_description = True
    expect_query(options, "description", 6)
    options.descriptions = False
    expect_query(options, "description", 0)


def test_include_specified_by_field() raises:
    var options = IntrospectionOptions()
    expect_query(options, "specifiedByURL", 0)
    options.specified_by_url = True
    expect_query(options, "specifiedByURL", 1)
    options.specified_by_url = False
    expect_query(options, "specifiedByURL", 0)


def test_include_is_deprecated_field_on_input_values() raises:
    var options = IntrospectionOptions()
    expect_query(options, "isDeprecated", 2)
    options.input_value_deprecation = True
    expect_query(options, "isDeprecated", 3)
    options.input_value_deprecation = False
    expect_query(options, "isDeprecated", 2)


def test_include_deprecation_reason_field_on_input_values() raises:
    var options = IntrospectionOptions()
    expect_query(options, "deprecationReason", 2)
    options.input_value_deprecation = True
    expect_query(options, "deprecationReason", 3)
    options.input_value_deprecation = False
    expect_query(options, "deprecationReason", 2)


def test_include_is_one_of_field_on_input_objects() raises:
    var options = IntrospectionOptions()
    expect_query(options, "isOneOf", 0)
    options.one_of = True
    expect_query(options, "isOneOf", 1)
    options.one_of = False
    expect_query(options, "isOneOf", 0)


def test_include_deprecated_input_field_and_args() raises:
    var options = IntrospectionOptions()
    expect_query(options, "includeDeprecated: true", 2)
    options.input_value_deprecation = True
    expect_query(options, "includeDeprecated: true", 5)
    options.input_value_deprecation = False
    expect_query(options, "includeDeprecated: true", 2)


def test_include_is_deprecated_field_on_directives() raises:
    var options = IntrospectionOptions()
    expect_query(options, "isDeprecated", 2)
    options.experimental_directive_deprecation = True
    expect_query(options, "isDeprecated", 3)
    options.experimental_directive_deprecation = False
    expect_query(options, "isDeprecated", 2)


def test_include_deprecation_reason_field_on_directives() raises:
    var options = IntrospectionOptions()
    var marker = "directives(includeDeprecated: true) {"
    assert_false(marker in get_introspection_query(options))
    expect_query(options, "deprecationReason", 2)
    options.experimental_directive_deprecation = True
    assert_true(marker in get_introspection_query(options))
    expect_query(options, "deprecationReason", 3)
    options.experimental_directive_deprecation = False
    assert_false(marker in get_introspection_query(options))
    expect_query(options, "deprecationReason", 2)


def test_throw_error_if_type_depth_is_too_high() raises:
    var options = IntrospectionOptions()
    options.type_depth = 101
    var raised = False
    try:
        _ = get_introspection_query(options)
    except e:
        raised = True
        assert_equal(
            String(e),
            (
                "Please set typeDepth to a reasonable value between 0 and 100;"
                " the default is 9."
            ),
        )
    assert_true(raised)


# --- not upstream ------------------------------------------------------------


def test_the_default_query_is_the_graphql_js_text() raises:
    assert_equal(
        get_introspection_query(),
        DEFAULT,
    )


def test_every_option_on_is_the_graphql_js_text() raises:
    var options = IntrospectionOptions(
        True, True, True, True, True, True, True, 2
    )
    assert_equal(get_introspection_query(options), ALL_ON)


def test_no_descriptions_and_no_type_depth_is_the_graphql_js_text() raises:
    var options = IntrospectionOptions()
    options.descriptions = False
    options.type_depth = 0
    assert_equal(get_introspection_query(options), NONE)


comptime ALL_ON = (
    "\n    query IntrospectionQuery {\n      __schema {\n        descri"
    "ption\n        queryType { name kind }\n        mutationType { nam"
    "e kind }\n        subscriptionType { name kind }\n        types {\n"
    "          ...FullType\n        }\n        directives(includeDeprec"
    "ated: true) {\n          name\n          description\n          is"
    "Repeatable\n          isDeprecated\n          deprecationReason\n "
    "         locations\n          args(includeDeprecated: true) {\n   "
    "         ...InputValue\n          }\n        }\n      }\n    }\n\n"
    "    fragment FullType on __Type {\n      kind\n      name\n      d"
    "escription\n      specifiedByURL\n      isOneOf\n      fields(incl"
    "udeDeprecated: true) {\n        name\n        description\n       "
    " args(includeDeprecated: true) {\n          ...InputValue\n       "
    " }\n        type {\n          ...TypeRef\n        }\n        isDep"
    "recated\n        deprecationReason\n      }\n      inputFields(inc"
    "ludeDeprecated: true) {\n        ...InputValue\n      }\n      int"
    "erfaces {\n        ...TypeRef\n      }\n      enumValues(includeDe"
    "precated: true) {\n        name\n        description\n        isDe"
    "precated\n        deprecationReason\n      }\n      possibleTypes "
    "{\n        ...TypeRef\n      }\n    }\n\n    fragment InputValue o"
    "n __InputValue {\n      name\n      description\n      type { ...T"
    "ypeRef }\n      defaultValue\n      isDeprecated\n      deprecatio"
    "nReason\n    }\n\n    fragment TypeRef on __Type {\n      kind\n  "
    "    name\n      ofType {\n        name\n        kind\n        ofTy"
    "pe {\n          name\n          kind\n        }\n      }\n    }\n "
    " "
)
comptime DEFAULT = (
    "\n    query IntrospectionQuery {\n      __schema {\n        \n    "
    "    queryType { name kind }\n        mutationType { name kind }\n "
    "       subscriptionType { name kind }\n        types {\n          "
    "...FullType\n        }\n        directives {\n          name\n    "
    "      description\n          \n          \n          \n          l"
    "ocations\n          args {\n            ...InputValue\n          }"
    "\n        }\n      }\n    }\n\n    fragment FullType on __Type {\n"
    "      kind\n      name\n      description\n      \n      \n      f"
    "ields(includeDeprecated: true) {\n        name\n        descriptio"
    "n\n        args {\n          ...InputValue\n        }\n        typ"
    "e {\n          ...TypeRef\n        }\n        isDeprecated\n      "
    "  deprecationReason\n      }\n      inputFields {\n        ...Inpu"
    "tValue\n      }\n      interfaces {\n        ...TypeRef\n      }\n"
    "      enumValues(includeDeprecated: true) {\n        name\n       "
    " description\n        isDeprecated\n        deprecationReason\n   "
    "   }\n      possibleTypes {\n        ...TypeRef\n      }\n    }\n\n"
    "    fragment InputValue on __InputValue {\n      name\n      descr"
    "iption\n      type { ...TypeRef }\n      defaultValue\n      \n   "
    "   \n    }\n\n    fragment TypeRef on __Type {\n      kind\n      "
    "name\n      ofType {\n        name\n        kind\n        ofType {"
    "\n          name\n          kind\n          ofType {\n            "
    "name\n            kind\n            ofType {\n              name\n"
    "              kind\n              ofType {\n                name\n"
    "                kind\n                ofType {\n                  "
    "name\n                  kind\n                  ofType {\n        "
    "            name\n                    kind\n                    of"
    "Type {\n                      name\n                      kind\n  "
    "                    ofType {\n                        name\n      "
    "                  kind\n                      }\n                 "
    "   }\n                  }\n                }\n              }\n   "
    "         }\n          }\n        }\n      }\n    }\n  "
)
comptime NONE = (
    "\n    query IntrospectionQuery {\n      __schema {\n        \n    "
    "    queryType { name kind }\n        mutationType { name kind }\n "
    "       subscriptionType { name kind }\n        types {\n          "
    "...FullType\n        }\n        directives {\n          name\n    "
    "      \n          \n          \n          \n          locations\n "
    "         args {\n            ...InputValue\n          }\n        }"
    "\n      }\n    }\n\n    fragment FullType on __Type {\n      kind\n"
    "      name\n      \n      \n      \n      fields(includeDeprecated"
    ": true) {\n        name\n        \n        args {\n          ...In"
    "putValue\n        }\n        type {\n          ...TypeRef\n       "
    " }\n        isDeprecated\n        deprecationReason\n      }\n    "
    "  inputFields {\n        ...InputValue\n      }\n      interfaces "
    "{\n        ...TypeRef\n      }\n      enumValues(includeDeprecated"
    ": true) {\n        name\n        \n        isDeprecated\n        d"
    "eprecationReason\n      }\n      possibleTypes {\n        ...TypeR"
    "ef\n      }\n    }\n\n    fragment InputValue on __InputValue {\n "
    "     name\n      \n      type { ...TypeRef }\n      defaultValue\n"
    "      \n      \n    }\n\n    fragment TypeRef on __Type {\n      k"
    "ind\n      name\n    }\n  "
)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
