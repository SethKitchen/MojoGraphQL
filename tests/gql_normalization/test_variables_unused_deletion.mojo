# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/variables_unused_deletion_test.go`.

Upstream detects the variable usage and extracts the variables on a first
walker, then deletes the unused variables on a second one.
"""

from _norm import *
from _norm_fixtures import *
from gql_language.parser import parse
from gql_language.printer import print_ast
from gql_normalization.selections import (
    delete_unused_variables,
    directive_include_skip,
)
from gql_normalization.variables import extract_variables
from std.testing import TestSuite, assert_equal


def test_variables_unused_deletion() raises:
    var schema = schema_of(VARIABLES_EXTRACTION_DEFINITION)
    var document = parse(
        """
		mutation HttpBinPost($foo: String! $bar: String!){
		  httpBinPost(input: {foo: $foo}){
			headers {
			  userAgent
			}
			data {
			  foo
			}
		  }
		}
		"""
    )
    var variables = String('{"foo":"bar"}')
    var used = directive_include_skip(document, schema, variables, True)
    extract_variables(document, schema, variables)
    delete_unused_variables(document, variables, used)
    assert_equal(
        print_ast(document),
        printed(
            "mutation HttpBinPost($bar: String!, $a: HttpBinPostInput){"
            "httpBinPost(input: $a){headers {userAgent} data {foo}}}"
        ),
    )
    assert_equal(variables, '{"a":{"foo":"bar"}}')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
