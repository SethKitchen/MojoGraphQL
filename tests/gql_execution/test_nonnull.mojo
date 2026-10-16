# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for non-null propagation in `gql_execution.execute`, ported from
graphql-js 16.14.2 `src/execution/__tests__/nonnull-test.ts`.

`throwingData` and `nullingData` are handles: tag 1 throws, tag 2 returns
`null`, and each nest field returns its source again. Execution is
synchronous, so the `promise` fields resolve at once, as the `sync` fields
do. The expected results are those of graphql-js 16.14.2 `executeSync`
with the same data, where the `promise` fields also resolve at once; the
upstream async cases list the same errors in the order that their promises
settle instead.

Upstream cases that are not ported:

- The checks after `resolveOnNextTick` in the two "slower nested error"
  cases: there are no pending promises. The results are ported.
"""

from std.testing import TestSuite, assert_equal
from _helpers import json_value, run, run_query
from gql_execution.execute import ExecutionArgs, ResolveInfo
from gql_execution.value import Values
from gql_schema.build import build_schema

comptime SDL = """
  type DataType {
    sync: String
    syncNonNull: String!
    promise: String
    promiseNonNull: String!
    syncNest: DataType
    syncNonNullNest: DataType!
    promiseNest: DataType
    promiseNonNullNest: DataType!
  }

  schema {
    query: DataType
  }
"""
comptime THROWING = 1
comptime NULLING = 2


def leaf(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    if values.tag(source) == THROWING:
        raise Error(info.field_name)
    return values.add_null()


def nest(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_handle(values.tag(source), 0)


def check(query: String, data: String, expected: String) raises:
    var schema = build_schema(SDL)
    var args = ExecutionArgs()
    var tag = THROWING if data == "throwing" else NULLING
    args.root_value = args.values.add_handle(tag, 0)
    for name in ["sync", "syncNonNull", "promise", "promiseNonNull"]:
        args.resolvers.field("DataType", name, leaf)
    for name in [
        "syncNest",
        "syncNonNullNest",
        "promiseNest",
        "promiseNonNullNest",
    ]:
        args.resolvers.field("DataType", name, nest)
    assert_equal(run_query(schema, query, args), expected)


comptime ARG_SDL = (
    "type Query { withNonNullArg(cannotBeNull: String!): String }"
)


def passed(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    return values.add_string(
        "Passed: " + String(values.string(values.get(args, "cannotBeNull")))
    )


def check_argument(query: String, variables: String, expected: String) raises:
    var schema = build_schema(ARG_SDL)
    var args = ExecutionArgs()
    args.resolvers.field("Query", "withNonNullArg", passed)
    if variables != "":
        args.variable_values = json_value(args.values, variables)
    assert_equal(run_query(schema, query, args), expected)


comptime Q0 = """
      {
        sync
      }
    """

comptime Q1 = """
      {
        syncNest {
          syncNonNull,
        }
      }
    """

comptime Q2 = """
      {
        syncNest {
          sync
          promise
          syncNest { sync promise }
          promiseNest { sync promise }
        }
        promiseNest {
          sync
          promise
          syncNest { sync promise }
          promiseNest { sync promise }
        }
      }
    """

comptime Q3 = """
      {
        syncNest {
          syncNonNullNest {
            promiseNonNullNest {
              syncNonNullNest {
                promiseNonNullNest {
                  syncNonNull
                }
              }
            }
          }
        }
        promiseNest {
          syncNonNullNest {
            promiseNonNullNest {
              syncNonNullNest {
                promiseNonNullNest {
                  syncNonNull
                }
              }
            }
          }
        }
        anotherNest: syncNest {
          syncNonNullNest {
            promiseNonNullNest {
              syncNonNullNest {
                promiseNonNullNest {
                  promiseNonNull
                }
              }
            }
          }
        }
        anotherPromiseNest: promiseNest {
          syncNonNullNest {
            promiseNonNullNest {
              syncNonNullNest {
                promiseNonNullNest {
                  promiseNonNull
                }
              }
            }
          }
        }
      }
    """

comptime Q4 = """
      {
        syncNonNull
      }
    """

comptime Q5 = """
        {
          promiseNonNullNest {
            syncNonNull
          }
          promiseNest {
            syncNonNull
          }
        }
      """

comptime Q6 = """
        {
          promiseNonNullNest {
            syncNonNull
          }
          promiseNest {
            promiseNonNull
          }
        }
      """

comptime Q7 = """
        {
          syncNest {
            promiseNonNullNest {
              syncNonNull
            }
            promiseNest {
              syncNonNull
            }
          }
        }
      """

comptime Q8 = """
        {
          syncNest {
            promiseNonNullNest {
              syncNonNull
            }
            promiseNest {
              promiseNest {
                promiseNest {
                  promiseNonNull
                }
              }
            }
          }
        }
      """


def test_query_0_nulling() raises:
    check(Q0, "nulling", '{"data":{"sync":null}}')


def test_query_0_throwing() raises:
    check(
        Q0,
        "throwing",
        (
            '{"errors":[{"message":"sync","locations":[{"line":3,"column":9}],"'
            'path":["sync"]}],"data":{"sync":null}}'
        ),
    )


def test_query_1_nulling() raises:
    check(
        Q1,
        "nulling",
        (
            '{"errors":[{"message":"Cannot return null for non-nullable field D'
            'ataType.syncNonNull.","locations":[{"line":4,"column":11}],"path":'
            '["syncNest","syncNonNull"]}],"data":{"syncNest":null}}'
        ),
    )


def test_query_1_throwing() raises:
    check(
        Q1,
        "throwing",
        (
            '{"errors":[{"message":"syncNonNull","locations":[{"line":4,"column'
            '":11}],"path":["syncNest","syncNonNull"]}],"data":{"syncNest":null'
            "}}"
        ),
    )


def test_query_2_nulling() raises:
    check(
        Q2,
        "nulling",
        (
            '{"data":{"syncNest":{"sync":null,"promise":null,"syncNest":{"sync"'
            ':null,"promise":null},"promiseNest":{"sync":null,"promise":null}},'
            '"promiseNest":{"sync":null,"promise":null,"syncNest":{"sync":null,'
            '"promise":null},"promiseNest":{"sync":null,"promise":null}}}}'
        ),
    )


def test_query_2_throwing() raises:
    check(
        Q2,
        "throwing",
        (
            '{"errors":[{"message":"sync","locations":[{"line":4,"column":11}],'
            '"path":["syncNest","sync"]},{"message":"promise","locations":[{"li'
            'ne":5,"column":11}],"path":["syncNest","promise"]},{"message":"syn'
            'c","locations":[{"line":6,"column":22}],"path":["syncNest","syncNe'
            'st","sync"]},{"message":"promise","locations":[{"line":6,"column":'
            '27}],"path":["syncNest","syncNest","promise"]},{"message":"sync","'
            'locations":[{"line":7,"column":25}],"path":["syncNest","promiseNes'
            't","sync"]},{"message":"promise","locations":[{"line":7,"column":3'
            '0}],"path":["syncNest","promiseNest","promise"]},{"message":"sync"'
            ',"locations":[{"line":10,"column":11}],"path":["promiseNest","sync'
            '"]},{"message":"promise","locations":[{"line":11,"column":11}],"pa'
            'th":["promiseNest","promise"]},{"message":"sync","locations":[{"li'
            'ne":12,"column":22}],"path":["promiseNest","syncNest","sync"]},{"m'
            'essage":"promise","locations":[{"line":12,"column":27}],"path":["p'
            'romiseNest","syncNest","promise"]},{"message":"sync","locations":['
            '{"line":13,"column":25}],"path":["promiseNest","promiseNest","sync'
            '"]},{"message":"promise","locations":[{"line":13,"column":30}],"pa'
            'th":["promiseNest","promiseNest","promise"]}],"data":{"syncNest":{'
            '"sync":null,"promise":null,"syncNest":{"sync":null,"promise":null}'
            ',"promiseNest":{"sync":null,"promise":null}},"promiseNest":{"sync"'
            ':null,"promise":null,"syncNest":{"sync":null,"promise":null},"prom'
            'iseNest":{"sync":null,"promise":null}}}}'
        ),
    )


def test_query_3_nulling() raises:
    check(
        Q3,
        "nulling",
        (
            '{"errors":[{"message":"Cannot return null for non-nullable field D'
            'ataType.syncNonNull.","locations":[{"line":8,"column":19}],"path":'
            '["syncNest","syncNonNullNest","promiseNonNullNest","syncNonNullNes'
            't","promiseNonNullNest","syncNonNull"]},{"message":"Cannot return '
            'null for non-nullable field DataType.syncNonNull.","locations":[{"'
            'line":19,"column":19}],"path":["promiseNest","syncNonNullNest","pr'
            'omiseNonNullNest","syncNonNullNest","promiseNonNullNest","syncNonN'
            'ull"]},{"message":"Cannot return null for non-nullable field DataT'
            'ype.promiseNonNull.","locations":[{"line":30,"column":19}],"path":'
            '["anotherNest","syncNonNullNest","promiseNonNullNest","syncNonNull'
            'Nest","promiseNonNullNest","promiseNonNull"]},{"message":"Cannot r'
            'eturn null for non-nullable field DataType.promiseNonNull.","locat'
            'ions":[{"line":41,"column":19}],"path":["anotherPromiseNest","sync'
            'NonNullNest","promiseNonNullNest","syncNonNullNest","promiseNonNul'
            'lNest","promiseNonNull"]}],"data":{"syncNest":null,"promiseNest":n'
            'ull,"anotherNest":null,"anotherPromiseNest":null}}'
        ),
    )


def test_query_3_throwing() raises:
    check(
        Q3,
        "throwing",
        (
            '{"errors":[{"message":"syncNonNull","locations":[{"line":8,"column'
            '":19}],"path":["syncNest","syncNonNullNest","promiseNonNullNest","'
            'syncNonNullNest","promiseNonNullNest","syncNonNull"]},{"message":"'
            'syncNonNull","locations":[{"line":19,"column":19}],"path":["promis'
            'eNest","syncNonNullNest","promiseNonNullNest","syncNonNullNest","p'
            'romiseNonNullNest","syncNonNull"]},{"message":"promiseNonNull","lo'
            'cations":[{"line":30,"column":19}],"path":["anotherNest","syncNonN'
            'ullNest","promiseNonNullNest","syncNonNullNest","promiseNonNullNes'
            't","promiseNonNull"]},{"message":"promiseNonNull","locations":[{"l'
            'ine":41,"column":19}],"path":["anotherPromiseNest","syncNonNullNes'
            't","promiseNonNullNest","syncNonNullNest","promiseNonNullNest","pr'
            'omiseNonNull"]}],"data":{"syncNest":null,"promiseNest":null,"anoth'
            'erNest":null,"anotherPromiseNest":null}}'
        ),
    )


def test_query_4_nulling() raises:
    check(
        Q4,
        "nulling",
        (
            '{"errors":[{"message":"Cannot return null for non-nullable field D'
            'ataType.syncNonNull.","locations":[{"line":3,"column":9}],"path":['
            '"syncNonNull"]}],"data":null}'
        ),
    )


def test_query_4_throwing() raises:
    check(
        Q4,
        "throwing",
        (
            '{"errors":[{"message":"syncNonNull","locations":[{"line":3,"column'
            '":9}],"path":["syncNonNull"]}],"data":null}'
        ),
    )


def test_query_5_nulling() raises:
    check(
        Q5,
        "nulling",
        (
            '{"errors":[{"message":"Cannot return null for non-nullable field D'
            'ataType.syncNonNull.","locations":[{"line":4,"column":13}],"path":'
            '["promiseNonNullNest","syncNonNull"]}],"data":null}'
        ),
    )


def test_query_5_throwing() raises:
    check(
        Q5,
        "throwing",
        (
            '{"errors":[{"message":"syncNonNull","locations":[{"line":4,"column'
            '":13}],"path":["promiseNonNullNest","syncNonNull"]}],"data":null}'
        ),
    )


def test_query_6_nulling() raises:
    check(
        Q6,
        "nulling",
        (
            '{"errors":[{"message":"Cannot return null for non-nullable field D'
            'ataType.syncNonNull.","locations":[{"line":4,"column":13}],"path":'
            '["promiseNonNullNest","syncNonNull"]}],"data":null}'
        ),
    )


def test_query_6_throwing() raises:
    check(
        Q6,
        "throwing",
        (
            '{"errors":[{"message":"syncNonNull","locations":[{"line":4,"column'
            '":13}],"path":["promiseNonNullNest","syncNonNull"]}],"data":null}'
        ),
    )


def test_query_7_nulling() raises:
    check(
        Q7,
        "nulling",
        (
            '{"errors":[{"message":"Cannot return null for non-nullable field D'
            'ataType.syncNonNull.","locations":[{"line":5,"column":15}],"path":'
            '["syncNest","promiseNonNullNest","syncNonNull"]}],"data":{"syncNes'
            't":null}}'
        ),
    )


def test_query_7_throwing() raises:
    check(
        Q7,
        "throwing",
        (
            '{"errors":[{"message":"syncNonNull","locations":[{"line":5,"column'
            '":15}],"path":["syncNest","promiseNonNullNest","syncNonNull"]}],"d'
            'ata":{"syncNest":null}}'
        ),
    )


def test_query_8_nulling() raises:
    check(
        Q8,
        "nulling",
        (
            '{"errors":[{"message":"Cannot return null for non-nullable field D'
            'ataType.syncNonNull.","locations":[{"line":5,"column":15}],"path":'
            '["syncNest","promiseNonNullNest","syncNonNull"]}],"data":{"syncNes'
            't":null}}'
        ),
    )


def test_query_8_throwing() raises:
    check(
        Q8,
        "throwing",
        (
            '{"errors":[{"message":"syncNonNull","locations":[{"line":5,"column'
            '":15}],"path":["syncNest","promiseNonNullNest","syncNonNull"]}],"d'
            'ata":{"syncNest":null}}'
        ),
    )


def test_succeeds_when_passed_non_null_literal_value() raises:
    check_argument(
        """
          query {
            withNonNullArg (cannotBeNull: "literal value")
          }
        """,
        "",
        '{"data":{"withNonNullArg":"Passed: literal value"}}',
    )


def test_succeeds_when_passed_non_null_variable_value() raises:
    check_argument(
        """
          query ($testVar: String!) {
            withNonNullArg (cannotBeNull: $testVar)
          }
        """,
        '{"testVar":"variable value"}',
        '{"data":{"withNonNullArg":"Passed: variable value"}}',
    )


def test_succeeds_when_missing_variable_has_default_value() raises:
    check_argument(
        """
          query ($testVar: String = "default value") {
            withNonNullArg (cannotBeNull: $testVar)
          }
        """,
        "{}",
        '{"data":{"withNonNullArg":"Passed: default value"}}',
    )


def test_field_error_when_missing_non_null_arg() raises:
    check_argument(
        """
          query {
            withNonNullArg
          }
        """,
        "",
        (
            '{"errors":[{"message":"Argument \\"cannotBeNull\\" of required typ'
            'e \\"String!\\" was not provided.","locations":[{"line":3,"column"'
            ':13}],"path":["withNonNullArg"]}],"data":{"withNonNullArg":null}}'
        ),
    )


def test_field_error_when_non_null_arg_provided_null() raises:
    check_argument(
        """
          query {
            withNonNullArg(cannotBeNull: null)
          }
        """,
        "",
        (
            '{"errors":[{"message":"Argument \\"cannotBeNull\\" of non-null typ'
            'e \\"String!\\" must not be null.","locations":[{"line":3,"column"'
            ':42}],"path":["withNonNullArg"]}],"data":{"withNonNullArg":null}}'
        ),
    )


def test_field_error_when_non_null_arg_not_provided_variable_value() raises:
    check_argument(
        """
          query ($testVar: String) {
            withNonNullArg(cannotBeNull: $testVar)
          }
        """,
        "{}",
        (
            '{"errors":[{"message":"Argument \\"cannotBeNull\\" of required typ'
            'e \\"String!\\" was provided the variable \\"$testVar\\" which was'
            ' not provided a runtime value.","locations":[{"line":3,"column":42'
            '}],"path":["withNonNullArg"]}],"data":{"withNonNullArg":null}}'
        ),
    )


def test_field_error_when_non_null_arg_provided_variable_with_explicit_null_value() raises:
    check_argument(
        """
          query ($testVar: String = "default value") {
            withNonNullArg (cannotBeNull: $testVar)
          }
        """,
        '{"testVar":null}',
        (
            '{"errors":[{"message":"Argument \\"cannotBeNull\\" of non-null typ'
            'e \\"String!\\" must not be null.","locations":[{"line":3,"column"'
            ':43}],"path":["withNonNullArg"]}],"data":{"withNonNullArg":null}}'
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
