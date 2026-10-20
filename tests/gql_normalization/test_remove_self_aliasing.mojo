# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/remove_self_aliasing_test.go`."""

from _norm import *
from _norm_fixtures import *
from std.testing import TestSuite


def test_simple() raises:
    run(
        self_aliasing_pass,
        TEST_DEFINITION,
        """
				{dog: dog}""",
        """
				{dog}""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
