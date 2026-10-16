# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The federation rules of a subgraph that check names and root types.

Port of these rules of Hive Federation Composition v0.27.0
`src/subgraph/validation/rules/`: `reserved-subgraph-name-rule.ts`,
`known-federation-directive-rule.ts`, `elements/field-set.ts`,
`query-root-type-inaccessible-rule.ts`, `known-type-names-rule.ts`,
`known-root-type-rule.ts` and `root-type-used-rule.ts`.

`BasicRules` holds what these rules compute before the walk.
"""

from std.collections import Dict
from gql_language.ast import NO_NODE, Document, Kind, OperationType, Role
from gql_composition.context import SubgraphContext
from gql_composition.error_code import ErrorCode
from gql_composition.federation_spec import is_specified_scalar


struct BasicRules(Movable):
    """The data of the basic rules, as their upstream closures hold it."""

    var available_directives: Dict[String, Bool]
    """The federation directives and the directive definitions."""
    var known_directives: Dict[String, Bool]
    """Every federation directive of the version."""
    var type_names: Dict[String, Bool]
    """The type definitions and extensions of the subgraph."""
    var root_query_name: String
    """The query root type for `QueryRootTypeInaccessibleRule`."""
    var default_roots: List[String]
    """The `Query`, `Mutation` and `Subscription` type definitions that
    exist, or empty."""

    def __init__(out self, mut context: SubgraphContext):
        """Run the rule constructors, as upstream does before the walk.

        `ReservedSubgraphNameRule` reports at this point.

        Args:
            context: The context.
        """
        if context.name == "_":
            context.report(
                "Invalid name _ for a subgraph: this name is reserved",
                ErrorCode.INVALID_SUBGRAPH_NAME,
            )
        self.available_directives = Dict[String, Bool]()
        self.known_directives = Dict[String, Bool]()
        self.type_names = Dict[String, Bool]()
        self.root_query_name = String("Query")
        self.default_roots = [String(""), String(""), String("")]
        for ref definition in context.known.directives:
            self.known_directives[definition.name] = True
        for ref definition in context.available.directives:
            self.available_directives[definition.name] = True
        ref document = context.document
        for definition in context.definitions:
            var kind = document.kind(definition)
            var name = String(document.name(definition))
            if kind == Kind.DIRECTIVE_DEFINITION:
                self.available_directives[name] = True
            elif kind.is_type_definition() or kind.is_type_extension():
                self.type_names[name] = True
            if kind.is_type_definition():
                if name == "Query":
                    self.default_roots[0] = name
                elif name == "Mutation":
                    self.default_roots[1] = name
                elif name == "Subscription":
                    self.default_roots[2] = name

    def enter_directive(self, mut context: SubgraphContext, node: Int):
        """Check that a federation directive is available, as upstream
        `KnownFederationDirectivesRule`.

        Args:
            context: The context.
            node: The `Directive`.
        """
        var name = String(context.document.name(node))
        if name in self.available_directives:
            return
        if name == "interfaceObject":
            context.report(
                (
                    'Unknown directive "@interfaceObject". If you meant the'
                    ' "@interfaceObject" federation 2 directive, note that this'
                    " schema is a federation 1 schema. To be a federation 2"
                    " schema, it needs to @link to the federation specification"
                    " v2."
                ),
                ErrorCode.INVALID_GRAPHQL,
            )
            return
        if name in self.known_directives and not name.startswith(
            "federation__"
        ):
            context.report(
                'Unknown directive "@'
                + name
                + '". If you meant the "@'
                + name
                + '" federation directive, you should use fully-qualified'
                ' name "@federation__'
                + name
                + '" or add "@'
                + name
                + '" to the `import` argument of the @link to the federation'
                " specification.",
                ErrorCode.INVALID_GRAPHQL,
            )

    def enter_named_type(
        self, mut context: SubgraphContext, node: Int, definition: Int
    ):
        """Check that a type exists, as upstream `KnownTypeNamesRule`.

        A specified scalar is known only in a type system definition or
        extension; in an operation or a fragment it is unknown, as
        upstream.

        Args:
            context: The context.
            node: The `NamedType`.
            definition: The top-level definition that holds the node.
        """
        var name = String(context.document.name(node))
        if name in self.type_names:
            return
        var kind = context.document.kind(definition)
        if is_specified_scalar(name) and (
            kind.is_type_system_definition() or kind.is_type_system_extension()
        ):
            return
        context.report("Unknown type " + name, ErrorCode.INVALID_GRAPHQL)

    def enter_schema(mut self, mut context: SubgraphContext, node: Int):
        """Check a schema definition or extension, as upstream
        `QueryRootTypeInaccessibleRule`, `KnownRootTypeRule` (definitions
        only) and `RootTypeUsedRule`.

        Args:
            context: The context.
            node: A `SchemaDefinition` or `SchemaExtension`.
        """
        var operations = List[Int]()
        var child = context.document.first_child(node)
        while child != NO_NODE:
            if context.document.role(child) == Role.OPERATION_TYPE:
                operations.append(child)
            child = context.document.next_sibling(child)
        for operation in operations:
            var name = String(
                context.document.name(
                    context.document.child(operation, Role.TYPE)
                )
            )
            if (
                context.document.operation(operation) == OperationType.QUERY
                and name != "Query"
            ):
                self.root_query_name = name
                break
        if context.document.kind(node) == Kind.SCHEMA_DEFINITION:
            for operation in operations:
                var name = String(
                    context.document.name(
                        context.document.child(operation, Role.TYPE)
                    )
                )
                if name not in self.type_names:
                    context.report(
                        "Cannot set schema "
                        + String(context.document.operation(operation).text())
                        + " root to unknown type "
                        + name,
                        ErrorCode.INVALID_GRAPHQL,
                    )
        for operation in operations:
            var kind = context.document.operation(operation)
            var used = String(
                context.document.name(
                    context.document.child(operation, Role.TYPE)
                )
            )
            var default = self.default_roots[Int(kind.value)]
            if default.byte_length() > 0 and default != used:
                var code = ErrorCode.ROOT_QUERY_USED
                if kind == OperationType.MUTATION:
                    code = ErrorCode.ROOT_MUTATION_USED
                elif kind == OperationType.SUBSCRIPTION:
                    code = ErrorCode.ROOT_SUBSCRIPTION_USED
                context.report(
                    'The schema has a type named "'
                    + default
                    + '" but it is not set as the '
                    + String(kind.text())
                    + ' root type ("'
                    + used
                    + '" is instead): this is not supported by federation.'
                    " If a root type does not use its default name, there"
                    " should be no other type with that default name.",
                    code,
                )

    def enter_type(self, mut context: SubgraphContext, node: Int):
        """Check a type definition, as upstream `FieldSetRules` and
        `QueryRootTypeInaccessibleRule`.

        Args:
            context: The context.
            node: A type definition.
        """
        var kind = context.document.kind(node)
        var name = String(context.document.name(node))
        if name == "FieldSet" and context.is_available_type("FieldSet"):
            if kind == Kind.SCALAR_TYPE_DEFINITION:
                context.replacements.add(name)
            else:
                var received: StaticString = "InputObjectType"
                if kind == Kind.OBJECT_TYPE_DEFINITION:
                    received = "ObjectType"
                elif kind == Kind.INTERFACE_TYPE_DEFINITION:
                    received = "InterfaceType"
                elif kind == Kind.UNION_TYPE_DEFINITION:
                    received = "UnionType"
                elif kind == Kind.ENUM_TYPE_DEFINITION:
                    received = "EnumType"
                context.report(
                    "Invalid definition for type FieldSet: FieldSet should be"
                    " a ScalarType but is defined as a "
                    + received,
                    ErrorCode.TYPE_DEFINITION_INVALID,
                )
        if kind != Kind.OBJECT_TYPE_DEFINITION or name != self.root_query_name:
            return
        var child = context.document.first_child(node)
        while child != NO_NODE:
            if context.document.role(
                child
            ) == Role.DIRECTIVE and context.is_available_directive(
                "inaccessible", context.document.name(child)
            ):
                context.report(
                    (
                        'Type "Query" is @inaccessible but is the root query'
                        " type, which must be in the API schema."
                    ),
                    ErrorCode.QUERY_ROOT_TYPE_INACCESSIBLE,
                )
                return
            child = context.document.next_sibling(child)
