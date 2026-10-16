# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for the definitions of each federation version, ported from
`@apollo/subgraph` 2.14.4 `src/__tests__/buildSubgraphSchema.test.ts`
(`federation specification backward compatibility`).

Upstream tests the versions 2.0 to 2.3. This suite also tests 2.4 to 2.14
in the same way; their expected SDL comes from `@apollo/subgraph` 2.14.4
itself, run in Node.js with the same SDL.
"""

from std.testing import TestSuite, assert_equal
from _helpers import assert_service_sdl, subgraph


def _check_version(version: String, expected: String) raises:
    var schema = subgraph(
        "extend schema\n  @link(url:"
        ' "https://specs.apollo.dev/federation/v'
        + version
        + '", import: ["@key"])\n\ntype Query {\n  x: Int\n}'
    )
    assert_service_sdl(schema, expected)


def test_expands_federation_2_0_correctly() raises:
    _check_version("2.0", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.0", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!) on FIELD_DEFINITION

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar _Any

type _Service {
  sdl: String
}''')


def test_expands_federation_2_1_correctly() raises:
    _check_version("2.1", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.1", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!) on FIELD_DEFINITION

directive @federation__composeDirective(name: String) repeatable on SCHEMA

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar _Any

type _Service {
  sdl: String
}''')


def test_expands_federation_2_2_correctly() raises:
    _check_version("2.2", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.2", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable repeatable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!) on FIELD_DEFINITION

directive @federation__composeDirective(name: String) repeatable on SCHEMA

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar _Any

type _Service {
  sdl: String
}''')


def test_expands_federation_2_3_correctly() raises:
    _check_version("2.3", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.3", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable repeatable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!) on FIELD_DEFINITION

directive @federation__composeDirective(name: String) repeatable on SCHEMA

directive @federation__interfaceObject on OBJECT

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar _Any

type _Service {
  sdl: String
}''')


def test_expands_federation_2_4_correctly() raises:
    _check_version("2.4", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.4", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable repeatable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!) on FIELD_DEFINITION

directive @federation__composeDirective(name: String) repeatable on SCHEMA

directive @federation__interfaceObject on OBJECT

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar _Any

type _Service {
  sdl: String
}''')


def test_expands_federation_2_5_correctly() raises:
    _check_version("2.5", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.5", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable repeatable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!) on FIELD_DEFINITION

directive @federation__composeDirective(name: String) repeatable on SCHEMA

directive @federation__interfaceObject on OBJECT

directive @federation__authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__requiresScopes(scopes: [[federation__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar federation__Scope

scalar _Any

type _Service {
  sdl: String
}''')


def test_expands_federation_2_6_correctly() raises:
    _check_version("2.6", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.6", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable repeatable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!) on FIELD_DEFINITION

directive @federation__composeDirective(name: String) repeatable on SCHEMA

directive @federation__interfaceObject on OBJECT

directive @federation__authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__requiresScopes(scopes: [[federation__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__policy(policies: [[federation__Policy!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar federation__Scope

scalar federation__Policy

scalar _Any

type _Service {
  sdl: String
}''')


def test_expands_federation_2_7_correctly() raises:
    _check_version("2.7", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.7", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable repeatable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!, label: String) on FIELD_DEFINITION

directive @federation__composeDirective(name: String) repeatable on SCHEMA

directive @federation__interfaceObject on OBJECT

directive @federation__authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__requiresScopes(scopes: [[federation__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__policy(policies: [[federation__Policy!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar federation__Scope

scalar federation__Policy

scalar _Any

type _Service {
  sdl: String
}''')


def test_expands_federation_2_8_correctly() raises:
    _check_version("2.8", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.8", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable repeatable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!, label: String) on FIELD_DEFINITION

directive @federation__composeDirective(name: String) repeatable on SCHEMA

directive @federation__interfaceObject on OBJECT

directive @federation__authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__requiresScopes(scopes: [[federation__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__policy(policies: [[federation__Policy!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__context(name: String!) repeatable on INTERFACE | OBJECT | UNION

directive @federation__fromContext(field: federation__ContextFieldValue) on ARGUMENT_DEFINITION

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar federation__Scope

scalar federation__Policy

scalar federation__ContextFieldValue

scalar _Any

type _Service {
  sdl: String
}''')


def test_expands_federation_2_9_correctly() raises:
    _check_version("2.9", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.9", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable repeatable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!, label: String) on FIELD_DEFINITION

directive @federation__composeDirective(name: String) repeatable on SCHEMA

directive @federation__interfaceObject on OBJECT

directive @federation__authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__requiresScopes(scopes: [[federation__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__policy(policies: [[federation__Policy!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__context(name: String!) repeatable on INTERFACE | OBJECT | UNION

directive @federation__fromContext(field: federation__ContextFieldValue) on ARGUMENT_DEFINITION

directive @federation__cost(weight: Int!) on ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION | INPUT_FIELD_DEFINITION | OBJECT | SCALAR

directive @federation__listSize(assumedSize: Int, slicingArguments: [String!], sizedFields: [String!], requireOneSlicingArgument: Boolean = true) on FIELD_DEFINITION

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar federation__Scope

scalar federation__Policy

scalar federation__ContextFieldValue

scalar _Any

type _Service {
  sdl: String
}''')


def test_expands_federation_2_10_correctly() raises:
    _check_version("2.10", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.10", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable repeatable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!, label: String) on FIELD_DEFINITION

directive @federation__composeDirective(name: String) repeatable on SCHEMA

directive @federation__interfaceObject on OBJECT

directive @federation__authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__requiresScopes(scopes: [[federation__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__policy(policies: [[federation__Policy!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__context(name: String!) repeatable on INTERFACE | OBJECT | UNION

directive @federation__fromContext(field: federation__ContextFieldValue) on ARGUMENT_DEFINITION

directive @federation__cost(weight: Int!) on ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION | INPUT_FIELD_DEFINITION | OBJECT | SCALAR

directive @federation__listSize(assumedSize: Int, slicingArguments: [String!], sizedFields: [String!], requireOneSlicingArgument: Boolean = true) on FIELD_DEFINITION

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar federation__Scope

scalar federation__Policy

scalar federation__ContextFieldValue

scalar _Any

type _Service {
  sdl: String
}''')


def test_expands_federation_2_11_correctly() raises:
    _check_version("2.11", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.11", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable repeatable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!, label: String) on FIELD_DEFINITION

directive @federation__composeDirective(name: String) repeatable on SCHEMA

directive @federation__interfaceObject on OBJECT

directive @federation__authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__requiresScopes(scopes: [[federation__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__policy(policies: [[federation__Policy!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__context(name: String!) repeatable on INTERFACE | OBJECT | UNION

directive @federation__fromContext(field: federation__ContextFieldValue) on ARGUMENT_DEFINITION

directive @federation__cost(weight: Int!) on ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION | INPUT_FIELD_DEFINITION | OBJECT | SCALAR

directive @federation__listSize(assumedSize: Int, slicingArguments: [String!], sizedFields: [String!], requireOneSlicingArgument: Boolean = true) on FIELD_DEFINITION

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar federation__Scope

scalar federation__Policy

scalar federation__ContextFieldValue

scalar _Any

type _Service {
  sdl: String
}''')


def test_expands_federation_2_12_correctly() raises:
    _check_version("2.12", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.12", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable repeatable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!, label: String) on FIELD_DEFINITION

directive @federation__composeDirective(name: String) repeatable on SCHEMA

directive @federation__interfaceObject on OBJECT

directive @federation__authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__requiresScopes(scopes: [[federation__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__policy(policies: [[federation__Policy!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__context(name: String!) repeatable on INTERFACE | OBJECT | UNION

directive @federation__fromContext(field: federation__ContextFieldValue) on ARGUMENT_DEFINITION

directive @federation__cost(weight: Int!) on ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION | INPUT_FIELD_DEFINITION | OBJECT | SCALAR

directive @federation__listSize(assumedSize: Int, slicingArguments: [String!], sizedFields: [String!], requireOneSlicingArgument: Boolean = true) on FIELD_DEFINITION

directive @federation__cacheTag(format: String!) repeatable on OBJECT | FIELD_DEFINITION

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar federation__Scope

scalar federation__Policy

scalar federation__ContextFieldValue

scalar _Any

type _Service {
  sdl: String
}''')


def test_expands_federation_2_13_correctly() raises:
    _check_version("2.13", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.13", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable repeatable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!, label: String) on FIELD_DEFINITION

directive @federation__composeDirective(name: String) repeatable on SCHEMA

directive @federation__interfaceObject on OBJECT

directive @federation__authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__requiresScopes(scopes: [[federation__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__policy(policies: [[federation__Policy!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__context(name: String!) repeatable on INTERFACE | OBJECT | UNION

directive @federation__fromContext(field: federation__ContextFieldValue) on ARGUMENT_DEFINITION

directive @federation__cost(weight: Int!) on ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION | INPUT_FIELD_DEFINITION | OBJECT | SCALAR

directive @federation__listSize(assumedSize: Int, slicingArguments: [String!], sizedFields: [String!], requireOneSlicingArgument: Boolean = true) on FIELD_DEFINITION

directive @federation__cacheTag(format: String!) repeatable on OBJECT | FIELD_DEFINITION

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar federation__Scope

scalar federation__Policy

scalar federation__ContextFieldValue

scalar _Any

type _Service {
  sdl: String
}''')


def test_expands_federation_2_14_correctly() raises:
    _check_version("2.14", '''schema
  @link(url: "https://specs.apollo.dev/link/v1.0")
{
  query: Query
}

extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.14", import: ["@key"])

directive @link(url: String, as: String, for: link__Purpose, import: [link__Import]) repeatable on SCHEMA

directive @key(fields: federation__FieldSet!, resolvable: Boolean = true) repeatable on OBJECT | INTERFACE

directive @federation__requires(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__provides(fields: federation__FieldSet!) on FIELD_DEFINITION

directive @federation__external(reason: String) on OBJECT | FIELD_DEFINITION

directive @federation__tag(name: String!) repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION | SCHEMA

directive @federation__extends on OBJECT | INTERFACE

directive @federation__shareable repeatable on OBJECT | FIELD_DEFINITION

directive @federation__inaccessible on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | ARGUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | INPUT_FIELD_DEFINITION

directive @federation__override(from: String!, label: String) on FIELD_DEFINITION

directive @federation__composeDirective(name: String) repeatable on SCHEMA

directive @federation__interfaceObject on OBJECT

directive @federation__authenticated on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__requiresScopes(scopes: [[federation__Scope!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__policy(policies: [[federation__Policy!]!]!) on FIELD_DEFINITION | OBJECT | INTERFACE | SCALAR | ENUM

directive @federation__context(name: String!) repeatable on INTERFACE | OBJECT | UNION

directive @federation__fromContext(field: federation__ContextFieldValue) on ARGUMENT_DEFINITION

directive @federation__cost(weight: Int!) on ARGUMENT_DEFINITION | ENUM | FIELD_DEFINITION | INPUT_FIELD_DEFINITION | OBJECT | SCALAR

directive @federation__listSize(assumedSize: Int, slicingArguments: [String!], sizedFields: [String!], requireOneSlicingArgument: Boolean = true) on FIELD_DEFINITION

directive @federation__cacheTag(format: String!) repeatable on OBJECT | FIELD_DEFINITION

type Query {
  x: Int
  _service: _Service!
}

enum link__Purpose {
  """
  `SECURITY` features provide metadata necessary to securely resolve fields.
  """
  SECURITY

  """
  `EXECUTION` features provide metadata necessary for operation execution.
  """
  EXECUTION
}

scalar link__Import

scalar federation__FieldSet

scalar federation__Scope

scalar federation__Policy

scalar federation__ContextFieldValue

scalar _Any

type _Service {
  sdl: String
}''')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
