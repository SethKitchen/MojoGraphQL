# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests ported from graphql-go-tools v2
`v2/pkg/astnormalization/defer_expand_into_internal_test.go`.

The "ignored" cases set the `ignore` flag of the upstream visitor. It has
the same effect as `disabled`, so they run with `disabled`. The tests after
`test_with_interface_type` are extra. Their outputs are the outputs of the
upstream visitor.
"""

from _norm import *
from _norm_fixtures import *
from gql_language.ast import Document
from gql_normalization.defer import defer_expand_into_internal
from gql_schema.definition import Schema
from std.testing import TestSuite


def expand_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `deferExpandIntoInternal`."""
    _ = defer_expand_into_internal(document, variables, False)


def disabled_pass(
    mut document: Document, schema: Schema, mut variables: String
) raises:
    """Upstream `deferExpandIntoInternalWithDisabled(walker, true)`."""
    _ = defer_expand_into_internal(document, variables, True)


comptime DOG_DEFER = """
					query dog {
						dog {
							... @defer {
								name
							}
						}
					}"""

comptime DOG_DEFER_IF_TRUE = """
					query dog {
						dog {
							... @defer(if: true) {
								name
							}
						}
					}"""

comptime DOG_DEFER_VARIABLE = """
					query dog($defer: Boolean!) {
						dog {
							... @defer(if: $defer) {
								name
							}
						}
					}"""

comptime DOG_DEFERRED = """
					query dog {
						dog {
							... {
								name  @__defer_internal(id: 1)
							}
						}
					}"""

comptime DOG_PLAIN = """
					query dog {
						dog {
							... {
								name
							}
						}
					}"""

comptime DOG_VARIABLE_DEFERRED = """
					query dog($defer: Boolean!) {
						dog {
							... {
								name  @__defer_internal(id: 1)
							}
						}
					}"""

comptime DOG_VARIABLE_PLAIN = """
					query dog($defer: Boolean!) {
						dog {
							... {
								name
							}
						}
					}"""


def test_simple_enabled_by_default() raises:
    run(expand_pass, TEST_DEFINITION, DOG_DEFER, DOG_DEFERRED)


def test_simple_enabled_by_default_but_ignored() raises:
    run(disabled_pass, TEST_DEFINITION, DOG_DEFER, DOG_PLAIN)


def test_simple_explicitly_enabled() raises:
    run(expand_pass, TEST_DEFINITION, DOG_DEFER_IF_TRUE, DOG_DEFERRED)


def test_simple_explicitly_enabled_but_ignored() raises:
    run(disabled_pass, TEST_DEFINITION, DOG_DEFER_IF_TRUE, DOG_PLAIN)


def test_simple_explicitly_disabled() raises:
    run(
        expand_pass,
        TEST_DEFINITION,
        """
					query dog {
						dog {
							... @defer(if: false) {
								name
							}
						}
					}""",
        DOG_PLAIN,
    )


def test_simple_disabled_no_variable_value() raises:
    run(expand_pass, TEST_DEFINITION, DOG_DEFER_VARIABLE, DOG_VARIABLE_PLAIN)


def test_simple_enabled_via_variable() raises:
    run_with_variables(
        expand_pass,
        TEST_DEFINITION,
        DOG_DEFER_VARIABLE,
        DOG_VARIABLE_DEFERRED,
        '{"defer": true}',
    )


def test_simple_enabled_via_variable_but_ignored() raises:
    run_with_variables(
        disabled_pass,
        TEST_DEFINITION,
        DOG_DEFER_VARIABLE,
        DOG_VARIABLE_PLAIN,
        '{"defer": true}',
    )


def test_simple_enabled_via_variable_but_disabled() raises:
    run_with_variables(
        disabled_pass,
        TEST_DEFINITION,
        DOG_DEFER_VARIABLE,
        DOG_VARIABLE_PLAIN,
        '{"defer": true}',
    )


def test_simple_disabled_via_variable() raises:
    run_with_variables(
        expand_pass,
        TEST_DEFINITION,
        DOG_DEFER_VARIABLE,
        DOG_VARIABLE_PLAIN,
        '{"defer": false}',
    )


def test_simple_enabled_via_variable_default_value() raises:
    run(
        expand_pass,
        TEST_DEFINITION,
        """
					query dog($defer: Boolean = true) {
						dog {
							... @defer(if: $defer) {
								name
							}
						}
					}""",
        """
					query dog($defer: Boolean = true) {
						dog {
							... {
								name  @__defer_internal(id: 1)
							}
						}
					}""",
    )


def test_simple_disabled_via_variable_default_value() raises:
    run(
        expand_pass,
        TEST_DEFINITION,
        """
					query dog($defer: Boolean = false) {
						dog {
							... @defer(if: $defer) {
								name
							}
						}
					}""",
        """
					query dog($defer: Boolean = false) {
						dog {
							... {
								name
							}
						}
					}""",
    )


def test_with_interface_type() raises:
    run(
        expand_pass,
        TEST_DEFINITION,
        """
					query pet {
						pet {
							... on Dog @defer {
								name
								nickname
								... @defer {
									barkVolume
								}
							}
							... on Dog {
								... @defer {
									extra {
										noString
									}
								}
								... @defer {
									extra {
										string
										noString
									}
								}
							}
							... on Cat @defer {
								name
								meowVolume
							}
						}
					}""",
        """
					query pet {
						pet {
							... on Dog {
								name @__defer_internal(id: 1)
								nickname @__defer_internal(id: 1)
								... {
									barkVolume @__defer_internal(id: 2, parentDeferId: 1)
								}
							}
							... on Dog {
								... {
									extra @__defer_internal(id: 3) {
										noString @__defer_internal(id: 3)
									}
								}
								... {
									extra @__defer_internal(id: 4) {
										string @__defer_internal(id: 4)
										noString @__defer_internal(id: 4)
									}
								}
							}
							... on Cat {
								name @__defer_internal(id: 5)
								meowVolume @__defer_internal(id: 5)
							}
						}
					}""",
    )


def test_extra_label() raises:
    run(
        expand_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog {
					... @defer(label: "first") { name }
					... @include(if: true) { barkVolume }
				}
			}""",
        """
			query dog {
				dog {
					... { name @__defer_internal(id: 1, label: "first") }
					... @include(if: true) { barkVolume }
				}
			}""",
    )


def test_extra_label_not_a_string() raises:
    """A difference from upstream: upstream reads a string of the document
    at the index of the variable, here `"first"`."""
    run(
        expand_pass,
        TEST_DEFINITION,
        """
			query dog($l: String) {
				dog {
					... @defer(label: "first") { name }
					... @defer(label: $l) { nickname }
				}
			}""",
        """
			query dog($l: String) {
				dog {
					... { name @__defer_internal(id: 1, label: "first") }
					... { nickname @__defer_internal(id: 2) }
				}
			}""",
    )


def test_extra_condition_not_boolean() raises:
    run(
        expand_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog {
					... @defer(if: "yes") { name }
				}
			}""",
        """
			query dog {
				dog {
					... { name }
				}
			}""",
    )


def test_extra_fragment_without_fields() raises:
    run(
        expand_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog {
					... @defer(label: "outer") {
						... on Dog @defer { name }
					}
				}
			}""",
        """
			query dog {
				dog {
					... {
						... on Dog { name @__defer_internal(id: 1) }
					}
				}
			}""",
    )


def test_extra_fragment_definition_and_spread() raises:
    run(
        expand_pass,
        TEST_DEFINITION,
        """
			query dog {
				dog {
					...DogFields
					... @defer { name }
				}
			}
			fragment DogFields on Dog {
				... @defer { nickname }
			}""",
        """
			query dog {
				dog {
					...DogFields
					... { name @__defer_internal(id: 1) }
				}
			}
			fragment DogFields on Dog {
				... @defer { nickname }
			}""",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
