# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Helpers of the policies.ts port: building policies and reading values."""

from std.collections import Dict

from gql_client.cache import FieldFunctionOptions, InMemoryCacheConfig
from gql_client.policies import FieldPolicy, TypePolicy
from gql_client.values import NO_VALUE, ValueKind


def add_field(
    mut config: InMemoryCacheConfig,
    typename: String,
    field: String,
    var policy: FieldPolicy,
):
    """Add a field policy to a config, making the type policy if needed."""
    if typename not in config.type_policies:
        config.type_policies[typename] = TypePolicy()
    try:
        config.type_policies[typename].fields[field] = policy^
    except:
        pass


def possible(
    mut config: InMemoryCacheConfig, supertype: String, subtypes: List[String]
):
    """Add a `possibleTypes` entry to a config."""
    config.possible_types[supertype] = subtypes.copy()


def text(mut options: FieldFunctionOptions, value: Int) -> String:
    """Return the text of a string or number value, or its JSON."""
    ref values = options.cache[].values
    var kind = values.kind(value)
    if kind == ValueKind.STRING or kind == ValueKind.NUMBER:
        return String(values.text(value))
    return values.stringify(value)


def number(mut options: FieldFunctionOptions, value: Int) -> Int:
    """Return an integer value, or 0 when the value is not a number."""
    ref values = options.cache[].values
    if values.kind(value) != ValueKind.NUMBER:
        return 0
    try:
        return Int(atol(values.text(value)))
    except:
        return 0


def arg(mut options: FieldFunctionOptions, name: StringSlice) -> Int:
    """Return an argument of the field, or `NO_VALUE`."""
    return options.cache[].values.get(options.args, name)
