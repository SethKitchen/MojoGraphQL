# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The GraphQL rules that run over the full subgraph document.

Port of these rules of Hive Federation Composition v0.27.0
`src/subgraph/validation/rules/`: `only-interface-implementation-rule.ts`,
`lone-schema-definition-rule.ts`, `unique-operation-types-rule.ts`,
`unique-type-names-rule.ts`, `unique-enum-value-names-rule.ts`,
`unique-field-definition-names-rule.ts`,
`unique-argument-definition-names-rule.ts`, `known-directives-rule.ts`,
`unique-directives-per-location-rule.ts`,
`known-argument-names-on-directives-rule.ts`,
`unique-argument-names-rule.ts`, `unique-input-field-names-rule.ts`,
`unique-directive-names-rule.ts`,
`provided-required-arguments-on-directives-rule.ts` and
`provided-arguments-on-directives-rule.ts`, and of
`createSimpleValidationContext` of `validation-context.ts`.

The rules run in parallel, in upstream order, on each node of the full
document: the federation definitions, the link definitions and the
subgraph.

**Differences from upstream.** The rules are one struct. The specified
directives are those of graphql-js 16.14.2, the version that upstream
v0.27.0 runs with in the benchmark baseline.
"""

from std.collections import Dict
from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.federation_spec import is_specified_scalar


@fieldwise_init
struct _RequiredArgument(Copyable):
    """A required argument of a directive definition."""

    var name: String
    var type: String
    """The printed type."""


def print_type_node(document: Document, node: Int) -> String:
    """Print a type reference, as graphql-js `print` prints it.

    Args:
        document: The document that holds the type.
        node: A named, list or non-null type node.

    Returns:
        Such as `[String!]!`.
    """
    var kind = document.kind(node)
    var suffix = String("")
    var current = node
    var text = String("")
    while kind != Kind.NAMED_TYPE:
        if kind == Kind.NON_NULL_TYPE:
            suffix = "!" + suffix
        else:
            text += "["
            suffix = "]" + suffix
        current = document.first_child(current)
        kind = document.kind(current)
    return text + String(document.name(current)) + suffix


def _named_type_name(document: Document, node: Int) -> String:
    """Return the name of the named type inside a type reference."""
    var current = node
    while document.kind(current) != Kind.NAMED_TYPE:
        current = document.first_child(current)
    return String(document.name(current))


def _value_kind_text(document: Document, value: Int) -> String:
    """Return the kind of a value, as upstream `printValueNode`."""
    var current = value
    var kind = document.kind(current)
    while kind == Kind.LIST:
        current = document.first_child(current)
        if current == NO_NODE:
            return String("[]")
        kind = document.kind(current)
    if kind == Kind.ENUM:
        return String("Enum")
    if kind == Kind.NULL:
        return String("Null")
    if kind == Kind.INT:
        return String("Int")
    if kind == Kind.FLOAT:
        return String("Float")
    if kind == Kind.STRING:
        return String("String")
    if kind == Kind.BOOLEAN:
        return String("Boolean")
    return String("Object")


def _directive_location(document: Document, path: List[Int]) -> String:
    """Return the location of a directive from the node that holds it, as
    upstream `getDirectiveLocationForASTPath`; empty when there is none."""
    var applied = path[len(path) - 1]
    var kind = document.kind(applied)
    if kind == Kind.SCHEMA_DEFINITION or kind == Kind.SCHEMA_EXTENSION:
        return String("SCHEMA")
    if (
        kind == Kind.SCALAR_TYPE_DEFINITION
        or kind == Kind.SCALAR_TYPE_EXTENSION
    ):
        return String("SCALAR")
    if (
        kind == Kind.OBJECT_TYPE_DEFINITION
        or kind == Kind.OBJECT_TYPE_EXTENSION
    ):
        return String("OBJECT")
    if kind == Kind.FIELD_DEFINITION:
        return String("FIELD_DEFINITION")
    if (
        kind == Kind.INTERFACE_TYPE_DEFINITION
        or kind == Kind.INTERFACE_TYPE_EXTENSION
    ):
        return String("INTERFACE")
    if kind == Kind.UNION_TYPE_DEFINITION or kind == Kind.UNION_TYPE_EXTENSION:
        return String("UNION")
    if kind == Kind.ENUM_TYPE_DEFINITION or kind == Kind.ENUM_TYPE_EXTENSION:
        return String("ENUM")
    if kind == Kind.ENUM_VALUE_DEFINITION:
        return String("ENUM_VALUE")
    if (
        kind == Kind.INPUT_OBJECT_TYPE_DEFINITION
        or kind == Kind.INPUT_OBJECT_TYPE_EXTENSION
    ):
        return String("INPUT_OBJECT")
    if kind == Kind.INPUT_VALUE_DEFINITION:
        var holder = document.kind(path[len(path) - 2])
        if holder == Kind.INPUT_OBJECT_TYPE_DEFINITION:
            return String("INPUT_FIELD_DEFINITION")
        return String("ARGUMENT_DEFINITION")
    return _executable_location(document, applied)


def _executable_location(document: Document, applied: Int) -> String:
    """Return the location of a directive on an executable node."""
    var kind = document.kind(applied)
    if kind == Kind.OPERATION_DEFINITION:
        var operation = document.operation(applied)
        return String(operation.text()).upper()
    if kind == Kind.FIELD:
        return String("FIELD")
    if kind == Kind.FRAGMENT_SPREAD:
        return String("FRAGMENT_SPREAD")
    if kind == Kind.INLINE_FRAGMENT:
        return String("INLINE_FRAGMENT")
    if kind == Kind.FRAGMENT_DEFINITION:
        return String("FRAGMENT_DEFINITION")
    if kind == Kind.VARIABLE_DEFINITION:
        return String("VARIABLE_DEFINITION")
    return String("")


comptime _SPECIFIED_DIRECTIVES: Array[StaticString, 5] = [
    "include",
    "skip",
    "deprecated",
    "specifiedBy",
    "oneOf",
]
"""The graphql-js 16.14.2 `specifiedDirectives`."""

comptime _SPECIFIED_LOCATIONS: Array[StaticString, 5] = [
    "FIELD|FRAGMENT_SPREAD|INLINE_FRAGMENT",
    "FIELD|FRAGMENT_SPREAD|INLINE_FRAGMENT",
    (
        "FIELD_DEFINITION|ARGUMENT_DEFINITION|INPUT_FIELD_DEFINITION|"
        "ENUM_VALUE|DIRECTIVE_DEFINITION"
    ),
    "SCALAR",
    "INPUT_OBJECT",
]
"""The locations of each specified directive, joined by `|`."""


def _is_type_kind(kind: Kind) -> Bool:
    """Return True for a type definition or a type extension."""
    return kind.is_type_definition() or kind.is_type_extension()


struct GraphQLRules(Movable):
    """The state of the GraphQL rules over one full document."""

    var locations: Dict[String, String]
    """The locations of each known directive, as `|LOC|LOC|`."""
    var arguments: Dict[String, String]
    """The argument names of each defined directive, as `|a|b|`."""
    var unique: Dict[String, Bool]
    """Whether each defined directive is not repeatable."""
    var required: Dict[String, List[_RequiredArgument]]
    """The required arguments of each defined directive."""
    var directive_nodes: Dict[String, Int]
    """The last definition of each directive."""
    var type_kinds: Dict[String, Kind]
    """The kind of the last definition or extension of each type name."""
    var schema_count: Int
    """How many schema definitions the walk saw."""
    var operations: List[Bool]
    """Which operation types a schema definition or extension set."""
    var type_names: Dict[String, Bool]
    """The names of the type definitions the walk saw."""
    var members: Dict[String, Bool]
    """The seen enum values and fields, as `Type.name`."""
    var schema_directives: Dict[String, Bool]
    """The non-repeatable directives seen on the schema."""
    var type_directives: Dict[String, Bool]
    """The non-repeatable directives seen on types, as `Type@name`."""
    var input_names: List[Dict[String, Bool]]
    """The field names of each object value the walk is in."""
    var directive_names: Dict[String, Bool]
    """The names of the directive definitions the walk saw."""
    var errors: List[CompositionError]
    """The errors, in the order of the walk."""

    def __init__(out self, document: Document, definitions: List[Int]):
        """Index the definitions of the full document.

        Args:
            document: The document.
            definitions: The definitions of the full document, in order.
        """
        self.locations = Dict[String, String]()
        self.arguments = Dict[String, String]()
        self.unique = Dict[String, Bool]()
        self.required = Dict[String, List[_RequiredArgument]]()
        self.directive_nodes = Dict[String, Int]()
        self.type_kinds = Dict[String, Kind]()
        self.schema_count = 0
        self.operations = [False, False, False]
        self.type_names = Dict[String, Bool]()
        self.members = Dict[String, Bool]()
        self.schema_directives = Dict[String, Bool]()
        self.type_directives = Dict[String, Bool]()
        self.input_names = List[Dict[String, Bool]]()
        self.directive_names = Dict[String, Bool]()
        self.errors = List[CompositionError]()
        var at = 0
        while at < len(definitions):
            var definition = definitions[at]
            at += 1
            var kind = document.kind(definition)
            var name = String(document.name(definition))
            if kind == Kind.DIRECTIVE_DEFINITION:
                self._index_directive(document, definition, name)
            elif _is_type_kind(kind):
                self.type_kinds[name] = kind
        var index = 0
        while index < 5:
            var name = String(materialize[_SPECIFIED_DIRECTIVES]()[index])
            if name not in self.locations:
                self.locations[name] = (
                    "|"
                    + String(materialize[_SPECIFIED_LOCATIONS]()[index])
                    + "|"
                )
            index += 1

    def _index_directive(
        mut self, document: Document, definition: Int, name: String
    ):
        """Index a directive definition."""
        var locations = String("|")
        var arguments = String("|")
        var required = List[_RequiredArgument]()
        var child = document.first_child(definition)
        while child != NO_NODE:
            var role = document.role(child)
            if role == Role.LOCATION:
                locations += String(document.text(child)) + "|"
            elif role == Role.ARGUMENT:
                var argument = String(document.name(child))
                arguments += argument + "|"
                var type = document.child(child, Role.TYPE)
                if (
                    document.kind(type) == Kind.NON_NULL_TYPE
                    and document.child(child, Role.DEFAULT_VALUE) == NO_NODE
                ):
                    required.append(
                        _RequiredArgument(
                            argument, print_type_node(document, type)
                        )
                    )
            child = document.next_sibling(child)
        self.locations[name] = locations^
        self.arguments[name] = arguments^
        self.unique[name] = not document.is_repeatable(definition)
        self.required[name] = required^
        self.directive_nodes[name] = definition

    def _report(mut self, message: String):
        """Report an `INVALID_GRAPHQL` error."""
        self.errors.append(
            CompositionError(message, ErrorCode.INVALID_GRAPHQL, None)
        )

    def enter(mut self, document: Document, node: Int, path: List[Int]):
        """Run the rules on entry to a node, in upstream order.

        Args:
            document: The full document.
            node: The node.
            path: The entered nodes that hold the node, from the top.
        """
        var kind = document.kind(node)
        if (
            kind == Kind.OBJECT_TYPE_DEFINITION
            or kind == Kind.OBJECT_TYPE_EXTENSION
        ):
            self._check_interfaces(document, node)
        if kind == Kind.SCHEMA_DEFINITION:
            if self.schema_count > 0:
                self._report("Must provide only one schema definition.")
            self.schema_count += 1
        if kind == Kind.SCHEMA_DEFINITION or kind == Kind.SCHEMA_EXTENSION:
            self._check_operations(document, node)
        if kind.is_type_definition():
            var name = String(document.name(node))
            if name in self.type_names:
                self._report('There can be only one type named "' + name + '".')
            else:
                self.type_names[name] = True
        if (
            kind == Kind.ENUM_TYPE_DEFINITION
            or kind == Kind.ENUM_TYPE_EXTENSION
            or kind == Kind.INPUT_OBJECT_TYPE_DEFINITION
            or kind == Kind.INPUT_OBJECT_TYPE_EXTENSION
            or kind == Kind.INTERFACE_TYPE_DEFINITION
            or kind == Kind.INTERFACE_TYPE_EXTENSION
            or kind == Kind.OBJECT_TYPE_DEFINITION
            or kind == Kind.OBJECT_TYPE_EXTENSION
        ):
            self._check_members(document, node, kind)
        if kind == Kind.DIRECTIVE_DEFINITION:
            self._check_arguments(
                document, node, "@" + String(document.name(node))
            )
        elif (
            kind == Kind.INTERFACE_TYPE_DEFINITION
            or kind == Kind.INTERFACE_TYPE_EXTENSION
            or kind == Kind.OBJECT_TYPE_DEFINITION
            or kind == Kind.OBJECT_TYPE_EXTENSION
        ):
            var type_name = String(document.name(node))
            var field = document.first_child(node)
            while field != NO_NODE:
                if document.kind(field) == Kind.FIELD_DEFINITION:
                    self._check_arguments(
                        document,
                        field,
                        type_name + "." + String(document.name(field)),
                    )
                field = document.next_sibling(field)
        if kind == Kind.DIRECTIVE:
            self._check_known_directive(document, node, path)
        self._check_unique_directives(document, node, kind)
        if kind == Kind.DIRECTIVE:
            self._check_known_arguments(document, node)
        if kind == Kind.DIRECTIVE or kind == Kind.FIELD:
            self._check_unique_arguments(document, node)
        if kind == Kind.OBJECT:
            self.input_names.append(Dict[String, Bool]())
        elif kind == Kind.OBJECT_FIELD:
            var field_name = String(document.name(node))
            ref names = self.input_names[len(self.input_names) - 1]
            if field_name in names:
                self._report(
                    'There can be only one input field named "'
                    + field_name
                    + '".'
                )
            else:
                names[field_name] = True
        if kind == Kind.DIRECTIVE_DEFINITION:
            var directive_name = String(document.name(node))
            if directive_name in self.directive_names:
                self._report(
                    'There can be only one directive named "@'
                    + directive_name
                    + '".'
                )
            else:
                self.directive_names[directive_name] = True

    def leave(mut self, document: Document, node: Int, path: List[Int]):
        """Run the rules on exit from a node, in upstream order.

        Args:
            document: The full document.
            node: The node.
            path: The entered nodes that hold the node, from the top.
        """
        var kind = document.kind(node)
        if kind == Kind.OBJECT:
            _ = self.input_names.pop()
        elif kind == Kind.DIRECTIVE:
            self._check_required_arguments(document, node)
            self._check_argument_values(document, node, path)

    def _check_interfaces(mut self, document: Document, node: Int):
        """Report each interface of an object type that is not an
        interface, as upstream `OnlyInterfaceImplementationRule`."""
        var child = document.first_child(node)
        while child != NO_NODE:
            if document.role(child) == Role.INTERFACE:
                var name = String(document.name(child))
                var found = self.type_kinds.get(name)
                if found and not (
                    found.value() == Kind.INTERFACE_TYPE_DEFINITION
                    or found.value() == Kind.INTERFACE_TYPE_EXTENSION
                ):
                    self._report(
                        "Cannot implement non-interface type "
                        + name
                        + " (of type ObjectType)"
                    )
            child = document.next_sibling(child)

    def _check_operations(mut self, document: Document, node: Int):
        """Report a second root type of an operation, as upstream
        `UniqueOperationTypesRule`."""
        var child = document.first_child(node)
        while child != NO_NODE:
            if document.role(child) == Role.OPERATION_TYPE:
                var operation = document.operation(child)
                var index = Int(operation.value)
                if self.operations[index]:
                    self._report(
                        "There can be only one "
                        + String(operation.text())
                        + " type in schema."
                    )
                else:
                    self.operations[index] = True
            child = document.next_sibling(child)

    def _check_members(mut self, document: Document, node: Int, kind: Kind):
        """Report a second enum value or field with a name, as upstream
        `UniqueEnumValueNamesRule` and `UniqueFieldDefinitionNamesRule`."""
        var is_enum = (
            kind == Kind.ENUM_TYPE_DEFINITION
            or kind == Kind.ENUM_TYPE_EXTENSION
        )
        var type_name = String(document.name(node))
        var child = document.first_child(node)
        while child != NO_NODE:
            var child_kind = document.kind(child)
            if (
                child_kind == Kind.ENUM_VALUE_DEFINITION
                or child_kind == Kind.FIELD_DEFINITION
                or child_kind == Kind.INPUT_VALUE_DEFINITION
            ):
                var coordinate = type_name + "." + String(document.name(child))
                var key = ("e:" if is_enum else "f:") + coordinate
                if key in self.members:
                    if is_enum:
                        self._report(
                            'Enum value "'
                            + coordinate
                            + '" can only be defined once.'
                        )
                    else:
                        self._report(
                            'Field "'
                            + coordinate
                            + '" can only be defined once.'
                        )
                else:
                    self.members[key] = True
            child = document.next_sibling(child)

    def _check_arguments(
        mut self, document: Document, node: Int, parent_name: String
    ):
        """Report a second argument definition with a name, as upstream
        `UniqueArgumentDefinitionNamesRule`."""
        var seen = Dict[String, Bool]()
        var child = document.first_child(node)
        while child != NO_NODE:
            if document.role(child) == Role.ARGUMENT:
                var name = String(document.name(child))
                if name in seen:
                    self._report(
                        'Argument "'
                        + parent_name
                        + "("
                        + name
                        + ':)" can only be defined once.'
                    )
                else:
                    seen[name] = True
            child = document.next_sibling(child)

    def _check_known_directive(
        mut self, document: Document, node: Int, path: List[Int]
    ):
        """Report an unknown directive or one at a wrong location, as
        upstream `KnownDirectivesRule`."""
        var name = String(document.name(node))
        var locations = self.locations.get(name)
        if not locations:
            self._report('Unknown directive "@' + name + '".')
            return
        var location = _directive_location(document, path)
        if (
            location.byte_length() > 0
            and ("|" + location + "|") not in locations.value()
        ):
            self._report(
                'Directive "@' + name + '" may not be used on ' + location + "."
            )

    def _check_unique_directives(
        mut self, document: Document, node: Int, kind: Kind
    ):
        """Report a second non-repeatable directive at a location, as
        upstream `UniqueDirectivesPerLocationRule`."""
        if document.child(node, Role.DIRECTIVE) == NO_NODE:
            return
        var is_schema = (
            kind == Kind.SCHEMA_DEFINITION or kind == Kind.SCHEMA_EXTENSION
        )
        var is_type = _is_type_kind(kind)
        var prefix = String(document.name(node)) + "@"
        var local = Dict[String, Bool]()
        var child = document.first_child(node)
        while child != NO_NODE:
            if document.role(child) == Role.DIRECTIVE:
                var name = String(document.name(child))
                if self.unique.get(name, False):
                    var seen: Bool
                    if is_schema:
                        seen = name in self.schema_directives
                        self.schema_directives[name] = True
                    elif is_type:
                        seen = (prefix + name) in self.type_directives
                        self.type_directives[prefix + name] = True
                    else:
                        seen = name in local
                        local[name] = True
                    if seen:
                        self._report(
                            'The directive "@'
                            + name
                            + '" can only be used once at this location.'
                        )
            child = document.next_sibling(child)

    def _check_known_arguments(mut self, document: Document, node: Int):
        """Report an argument that the directive does not define, as
        upstream `KnownArgumentNamesOnDirectivesRule`."""
        var name = String(document.name(node))
        var known = self.arguments.get(name)
        if not known:
            return
        var child = document.first_child(node)
        while child != NO_NODE:
            if document.role(child) == Role.ARGUMENT:
                var argument = String(document.name(child))
                if ("|" + argument + "|") not in known.value():
                    self._report(
                        'Unknown argument "'
                        + argument
                        + '" on directive "@'
                        + name
                        + '".'
                    )
            child = document.next_sibling(child)

    def _check_unique_arguments(mut self, document: Document, node: Int):
        """Report a second argument with a name, as upstream
        `UniqueArgumentNamesRule`."""
        var seen = Dict[String, Bool]()
        var child = document.first_child(node)
        while child != NO_NODE:
            if document.role(child) == Role.ARGUMENT:
                var argument = String(document.name(child))
                if argument in seen:
                    self._report(
                        'There can be only one argument named "'
                        + argument
                        + '".'
                    )
                else:
                    seen[argument] = True
            child = document.next_sibling(child)

    def _check_required_arguments(mut self, document: Document, node: Int):
        """Report a required argument that a directive does not set, as
        upstream `ProvidedRequiredArgumentsOnDirectivesRule`."""
        var name = String(document.name(node))
        var required = self.required.get(name)
        if not required:
            return
        for ref argument in required.value():
            var found = False
            var child = document.first_child(node)
            while child != NO_NODE:
                if (
                    document.role(child) == Role.ARGUMENT
                    and document.name(child) == argument.name
                ):
                    found = True
                child = document.next_sibling(child)
            if not found:
                self._report(
                    'Directive "@'
                    + name
                    + '" argument "'
                    + argument.name
                    + '" of type "'
                    + argument.type
                    + '" is required, but it was not provided.'
                )

    def _type_kind_text(self, document: Document, type: Int) -> String:
        """Return what a type accepts, as upstream `printTypeNode`: `Any`,
        `Enum`, `Object`, a specified scalar, or empty for an unknown
        type."""
        var name = _named_type_name(document, type)
        var found = self.type_kinds.get(name)
        if not found:
            if is_specified_scalar(name):
                return name
            return String("")
        var kind = found.value()
        if (
            kind == Kind.SCALAR_TYPE_DEFINITION
            or kind == Kind.SCALAR_TYPE_EXTENSION
        ):
            return String("Any")
        if (
            kind == Kind.ENUM_TYPE_DEFINITION
            or kind == Kind.ENUM_TYPE_EXTENSION
        ):
            return String("Enum")
        return String("Object")

    def _check_argument_values(
        mut self, document: Document, node: Int, path: List[Int]
    ):
        """Report an argument value of a wrong kind, as upstream
        `ProvidedArgumentsOnDirectivesRule`."""
        var name = String(document.name(node))
        var found = self.directive_nodes.get(name)
        if not found:
            return
        var definition = found.value()
        var coordinate = _coordinate(document, path)
        var child = document.first_child(node)
        while child != NO_NODE:
            if document.role(child) == Role.ARGUMENT:
                var argument = document.name(child)
                var value = document.child(child, Role.VALUE)
                var argument_definition = NO_NODE
                var candidate = document.first_child(definition)
                while candidate != NO_NODE and argument_definition == NO_NODE:
                    if (
                        document.role(candidate) == Role.ARGUMENT
                        and document.name(candidate) == argument
                    ):
                        argument_definition = candidate
                    candidate = document.next_sibling(candidate)
                if argument_definition != NO_NODE:
                    self._check_value(
                        document,
                        name,
                        String(argument),
                        document.child(argument_definition, Role.TYPE),
                        value,
                        coordinate,
                    )
            child = document.next_sibling(child)

    def _check_value(
        mut self,
        document: Document,
        directive: String,
        argument: String,
        type: Int,
        value: Int,
        coordinate: String,
    ):
        """Check one argument value against its definition's type."""
        var type_kind = document.kind(type)
        var value_kind = document.kind(value)
        if type_kind == Kind.NON_NULL_TYPE and value_kind == Kind.NULL:
            return
        var printed_type = self._type_kind_text(document, type)
        var printed_value = _value_kind_text(document, value)
        if (
            printed_type.byte_length() == 0
            or printed_type == "Any"
            or printed_type == printed_value
        ):
            return
        if printed_value == "[]" and (
            type_kind == Kind.LIST_TYPE
            or (
                type_kind == Kind.NON_NULL_TYPE
                and document.kind(document.first_child(type)) == Kind.LIST_TYPE
            )
        ):
            return
        if (
            printed_value == "Int"
            and _named_type_name(document, type) == "Float"
        ):
            return
        self._report(
            'Invalid value for "@'
            + directive
            + "("
            + argument
            + ':)" of type "'
            + print_type_node(document, type)
            + '" in application of "@'
            + directive
            + '" to "'
            + coordinate
            + '".'
        )


def _coordinate(document: Document, path: List[Int]) -> String:
    """Join the names of the nodes that hold a directive, as upstream
    `getSchemaCoordinate`; a schema is `schema`."""
    var coordinate = String("")
    var index = 0
    while index < len(path):
        var node = path[index]
        index += 1
        var kind = document.kind(node)
        var name: String
        if kind == Kind.SCHEMA_DEFINITION or kind == Kind.SCHEMA_EXTENSION:
            name = String("schema")
        else:
            name = String(document.name(node))
        if coordinate.byte_length() > 0:
            coordinate += "." + name
        else:
            coordinate = name^
    return coordinate^
