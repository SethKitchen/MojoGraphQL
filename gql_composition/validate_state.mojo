# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The validation of the state that the walk of a subgraph built.

Port of `validateSubgraphState` of Hive Federation Composition v0.27.0
`src/subgraph/validation/validate-state.ts`, with `andList` of
`src/utils/format.ts` and the type helpers of `src/utils/state.ts`.

**Differences from upstream.** Upstream checks that a field, an argument
or an input field has an output or input type with a `SKIP` result for an
unknown type, after it already skipped the unknown types; and it checks
that a type implements an interface only once, which its `Set` of
interfaces already ensures. Upstream also checks that the root types are
different and known, but the state names each root type `Query`,
`Mutation` or `Subscription` and holds it. Upstream checks that a required
argument of a directive definition is not deprecated, but the state never
records `@deprecated` on a directive argument. Those branches cannot run,
and this port does not have them. The literal checks of the specified scalars are those of
graphql-js 16 `parseLiteral`.
"""

from std.collections import Dict
from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.parser import parse_value
from gql_composition.error_code import CompositionError, ErrorCode
from gql_composition.federation_spec import is_specified_scalar
from gql_composition.state import (
    FieldState,
    InputValueState,
    RootKind,
    StringSet,
    SubgraphState,
    TypeKind,
    TypeState,
)


comptime _INTROSPECTION_TYPES: Array[StaticString, 8] = [
    "__Schema",
    "__Directive",
    "__DirectiveLocation",
    "__Type",
    "__Field",
    "__InputValue",
    "__EnumValue",
    "__TypeKind",
]
"""The graphql-js `introspectionTypes`."""


def _is_introspection_type(name: String) -> Bool:
    """Return True for the name of an introspection type."""
    var index = 0
    while index < 8:
        if name == materialize[_INTROSPECTION_TYPES]()[index]:
            return True
        index += 1
    return False


def strip_non_null(type: String) -> String:
    """Drop the trailing `!` of a printed type, as upstream `stripNonNull`.

    Args:
        type: A printed type that ends with `!`.

    Returns:
        The nullable type.
    """
    return String(type[byte = : type.byte_length() - 1])


def strip_list(type: String) -> String:
    """Drop the outer brackets of a printed list type, as upstream
    `stripList`.

    Args:
        type: A printed list type, such as `[Int!]`.

    Returns:
        The item type, such as `Int!`.
    """
    return String(type[byte = 1 : type.byte_length() - 1])


def _is_non_null(type: String) -> Bool:
    """Return True for a printed non-null type."""
    return type.endswith("!")


def _is_list(type: String) -> Bool:
    """Return True for a printed list type."""
    return type.endswith("]")


def _named(type: String) -> String:
    """Return the named type of a printed type. The name is never empty."""
    var bytes = type.as_bytes()
    var start = 0
    var end = len(bytes)
    while bytes[start] == UInt8(ord("[")):
        start += 1
    while bytes[end - 1] == UInt8(ord("]")) or bytes[end - 1] == UInt8(
        ord("!")
    ):
        end -= 1
    return String(type[byte=start:end])


def _capitalized(kind: RootKind) -> String:
    """Return the operation name of a root kind, such as `Query`."""
    if kind == RootKind.QUERY:
        return String("Query")
    if kind == RootKind.MUTATION:
        return String("Mutation")
    return String("Subscription")


struct _Validator:
    """The state of `validateSubgraphState` for one subgraph."""

    var errors: List[CompositionError]
    var implementations: Dict[String, StringSet]
    """The object and interface types that implement each interface."""
    var visited: Dict[String, Bool]
    """The input objects that the cycle check visited."""
    var field_path: List[String]
    var path_index: Dict[String, Int]
    """The position in `field_path` of each input object on the path."""

    def __init__(out self):
        self.errors = List[CompositionError]()
        self.implementations = Dict[String, StringSet]()
        self.visited = Dict[String, Bool]()
        self.field_path = List[String]()
        self.path_index = Dict[String, Int]()

    def report(mut self, message: String):
        """Report an `INVALID_GRAPHQL` error."""
        self.errors.append(
            CompositionError(message, ErrorCode.INVALID_GRAPHQL, None)
        )

    def validate_name(mut self, name: String):
        """Report a name that begins with `__`, as upstream
        `validateName`."""
        if name.startswith("__"):
            self.report(
                'Name "'
                + name
                + '" must not begin with "__", which is reserved by GraphQL'
                " introspection."
            )

    def validate_root_types(mut self, state: SubgraphState):
        """Check the root types, as upstream `validateRootTypes`. The state
        names each root type after its kind and holds it."""
        for kind in state.root_order:
            var name = state.root_names[Int(kind.value)]
            var found = state.find_type(name)
            if state.types[found].kind != TypeKind.OBJECT:
                var operation = _capitalized(kind)
                if kind == RootKind.QUERY:
                    self.report(
                        operation
                        + " root type must be Object type, it cannot be "
                        + name
                        + "."
                    )
                else:
                    self.report(
                        operation
                        + " root type must be Object type if provided, it"
                        " cannot be "
                        + name
                        + "."
                    )

    def validate_directives(mut self, state: SubgraphState):
        """Check the directive definitions, as upstream
        `validateDirectives`."""
        for ref directive in state.types:
            if directive.kind != TypeKind.DIRECTIVE or directive.name == "link":
                continue
            self.validate_name(directive.name)
            for ref argument in directive.input_fields:
                self.validate_name(argument.name)
                var type_name = _named(argument.type)
                if type_name == "link__Import" or type_name == "link__Purpose":
                    continue
                var found = state.find_type(type_name)
                if found == -1 and not is_specified_scalar(type_name):
                    continue
                if found != -1 and not _is_input_kind(state.types[found].kind):
                    self.report(
                        "The type of @"
                        + directive.name
                        + "("
                        + argument.name
                        + ":) must be Input Type but got: "
                        + argument.type
                        + "."
                    )

    def validate_types(mut self, state: SubgraphState) raises:
        """Check the types, as upstream `validateTypes`."""
        for ref type in state.types:
            if type.kind != TypeKind.INTERFACE and type.kind != TypeKind.OBJECT:
                continue
            for ref interface in type.interfaces.items:
                var found = state.find_type(interface)
                if (
                    found != -1
                    and state.types[found].kind == TypeKind.INTERFACE
                ):
                    if interface not in self.implementations:
                        self.implementations[interface] = StringSet()
                    self.implementations[interface].add(type.name)
        for ref type in state.types:
            if not _is_introspection_type(type.name):
                self.validate_name(type.name)
            if type.kind == TypeKind.OBJECT or type.kind == TypeKind.INTERFACE:
                self.validate_fields(state, type)
                self.validate_interfaces(state, type)
            elif type.kind == TypeKind.UNION:
                self.validate_union(state, type)
            elif type.kind == TypeKind.ENUM:
                if len(type.values) == 0:
                    self.report(
                        "Enum type "
                        + type.name
                        + " must define one or more values."
                    )
                for ref value in type.values:
                    self.validate_name(value.name)
            elif type.kind == TypeKind.INPUT_OBJECT:
                self.validate_input_fields(state, type)
                self.detect_cycles(state, type)

    def validate_fields(mut self, state: SubgraphState, type: TypeState) raises:
        """Check the fields of an object or interface type, as upstream
        `validateFields`."""
        var name = type.name
        if len(type.fields) == 0 and name not in state.root_names:
            self.report("Type " + name + " must define one or more fields.")
        for ref field in type.fields:
            self.validate_name(field.name)
            var found = state.find_type(_named(field.type))
            if found == -1 and not is_specified_scalar(_named(field.type)):
                continue
            if found != -1 and state.types[found].kind == TypeKind.INPUT_OBJECT:
                self.report(
                    'The type of "'
                    + name
                    + "."
                    + field.name
                    + '" must be Output Type but got: "'
                    + field.type
                    + '".'
                )
            for ref argument in field.args:
                self.validate_argument(
                    state, name + "." + field.name, argument, False
                )

    def validate_input_fields(
        mut self, state: SubgraphState, type: TypeState
    ) raises:
        """Check the fields of an input object type, as upstream
        `validateInputFields`."""
        if len(type.input_fields) == 0:
            self.report(
                "Input Object type "
                + type.name
                + " must define one or more fields."
            )
        for ref field in type.input_fields:
            self.validate_argument(state, type.name, field, True)

    def validate_argument(
        mut self,
        state: SubgraphState,
        owner: String,
        value: InputValueState,
        is_input_field: Bool,
    ) raises:
        """Check an argument of a field or a field of an input object
        type."""
        self.validate_name(value.name)
        var type_name = _named(value.type)
        var found = state.find_type(type_name)
        if found == -1 and not is_specified_scalar(type_name):
            return
        var subject: String
        if is_input_field:
            subject = owner + "." + value.name
        else:
            subject = owner + "(" + value.name + ":)"
        if found != -1 and not _is_input_kind(state.types[found].kind):
            var extra = String("")
            if _is_list(value.type):
                extra = ", a ListType"
            elif _is_non_null(value.type):
                extra = ", a NonNullType"
            if is_input_field:
                self.report(
                    "The type of "
                    + subject
                    + ' must be Input Type but got "'
                    + value.type
                    + '"'
                    + extra
                    + "."
                )
            else:
                self.report(
                    'The type of "'
                    + subject
                    + '" must be Input Type but got "'
                    + value.type
                    + '"'
                    + extra
                    + "."
                )
        var label = String("input field ") if is_input_field else String(
            "argument "
        )
        if _is_required(value) and value.deprecated:
            var noun = String(
                "Required input field "
            ) if is_input_field else String("Required argument ")
            self.report(noun + subject + " cannot be deprecated.")
        if value.default_value:
            var text = value.default_value.value()
            var parsed = parse_value(text)
            if not _is_valid_default(state, value.type, parsed, parsed.root):
                self.report(
                    "Invalid default value (got: "
                    + text
                    + ") provided for "
                    + label
                    + subject
                    + " of type "
                    + value.type
                    + "."
                )

    def validate_union(mut self, state: SubgraphState, union: TypeState):
        """Check the members of a union type, as upstream
        `validateUnionMembers`."""
        if len(union.members) == 0:
            self.report(
                "Union type "
                + union.name
                + " must define one or more member types."
            )
        for ref member in union.members.items:
            var found = state.find_type(member)
            if found == -1 or state.types[found].kind != TypeKind.OBJECT:
                self.report(
                    "Union type "
                    + union.name
                    + " can only include Object types, it cannot include "
                    + member
                    + "."
                )

    def validate_interfaces(mut self, state: SubgraphState, type: TypeState):
        """Check the interfaces of an object or interface type, as upstream
        `validateInterfaces`."""
        for ref name in type.interfaces.items:
            var found = state.find_type(name)
            if found == -1:
                continue
            ref interface = state.types[found]
            if interface.kind != TypeKind.INTERFACE:
                self.report(
                    "Type "
                    + type.name
                    + " must only implement Interface types, it cannot"
                    " implement "
                    + name
                    + "."
                )
                continue
            if type.name == name:
                self.report(
                    "Type "
                    + type.name
                    + " cannot implement itself because it would create a"
                    " circular reference."
                )
                continue
            for ref transitive in interface.interfaces.items:
                if type.interfaces.contains(transitive):
                    continue
                if transitive == type.name:
                    self.report(
                        "Type "
                        + type.name
                        + " cannot implement "
                        + name
                        + " because it would create a circular reference."
                    )
                else:
                    self.report(
                        "Type "
                        + type.name
                        + " must implement "
                        + transitive
                        + " because it is implemented by "
                        + name
                        + "."
                    )
            self.validate_implementation(state, type, interface)

    def validate_implementation(
        mut self, state: SubgraphState, type: TypeState, interface: TypeState
    ):
        """Check that a type has the fields of an interface, as upstream
        `validateTypeImplementsInterface`."""
        var prefix = interface.name + "."
        for ref interface_field in interface.fields:
            var field_name = interface_field.name
            var at = type.find_field(field_name)
            if at == -1:
                self.report(
                    "Interface field "
                    + prefix
                    + field_name
                    + " expected but "
                    + type.name
                    + " does not provide it."
                )
                continue
            ref field = type.fields[at]
            if not _is_sub_type(
                state, self.implementations, field.type, interface_field.type
            ):
                self.report(
                    "Interface field "
                    + prefix
                    + field_name
                    + " expects type "
                    + interface_field.type
                    + " but "
                    + type.name
                    + "."
                    + field_name
                    + " of type "
                    + field.type
                    + " is not a proper subtype."
                )
            for ref interface_argument in interface_field.args:
                var argument_name = interface_argument.name
                var found = field.find_arg(argument_name)
                if found == -1:
                    self.report(
                        "Interface field argument "
                        + prefix
                        + field_name
                        + "("
                        + argument_name
                        + ":) expected but "
                        + type.name
                        + "."
                        + field_name
                        + " does not provide it."
                    )
                    continue
                ref argument_type = field.args[found].type
                if interface_argument.type != argument_type:
                    self.report(
                        "Interface field argument "
                        + prefix
                        + field_name
                        + "("
                        + argument_name
                        + ":) expects type "
                        + interface_argument.type
                        + " but "
                        + type.name
                        + "."
                        + field_name
                        + "("
                        + argument_name
                        + ":) is type "
                        + argument_type
                        + "."
                    )
            for ref argument in field.args:
                if interface_field.find_arg(
                    argument.name
                ) == -1 and _is_required(argument):
                    self.report(
                        "Object field "
                        + type.name
                        + "."
                        + field_name
                        + " includes required argument "
                        + argument.name
                        + " that is missing from the Interface field "
                        + prefix
                        + field_name
                        + "."
                    )

    def detect_cycles(mut self, state: SubgraphState, input: TypeState) raises:
        """Report the cycles of non-null fields through an input object
        type, as upstream `createInputObjectCircularRefsValidator`."""
        if input.name in self.visited:
            return
        self.visited[input.name] = True
        self.path_index[input.name] = len(self.field_path)
        for ref field in input.input_fields:
            if not _is_non_null(field.type):
                continue
            var found = state.find_type(strip_non_null(field.type))
            if found == -1 or state.types[found].kind != TypeKind.INPUT_OBJECT:
                continue
            ref field_type = state.types[found]
            var cycle = self.path_index.get(field_type.name)
            self.field_path.append(field.name)
            if not cycle:
                self.detect_cycles(state, field_type)
            else:
                var path = String(".").join(self.field_path[cycle.value() :])
                self.report(
                    'Cannot reference Input Object "'
                    + field_type.name
                    + '" within itself through a series of non-null fields: "'
                    + path
                    + '".'
                )
            _ = self.field_path.pop()
        _ = self.path_index.pop(input.name)


def _is_input_kind(kind: TypeKind) -> Bool:
    """Return True for the kinds of input types."""
    return (
        kind == TypeKind.SCALAR
        or kind == TypeKind.ENUM
        or kind == TypeKind.INPUT_OBJECT
    )


def _is_required(value: InputValueState) -> Bool:
    """Return True for a non-null input value without a default value, as
    upstream `isRequiredArgument`."""
    return _is_non_null(value.type) and not value.default_value


def _is_int32(text: StringSlice) -> Bool:
    """Return True for the text of an integer in the 32-bit range."""
    var bytes = text.as_bytes()
    var negative = len(bytes) > 0 and bytes[0] == UInt8(ord("-"))
    var start = 1 if negative else 0
    if len(bytes) - start > 10:
        return False
    var value = 0
    var index = start
    while index < len(bytes):
        value = value * 10 + Int(bytes[index]) - ord("0")
        index += 1
    if negative:
        return value <= 2147483648
    return value <= 2147483647


def _parses_as_scalar(name: String, kind: Kind, text: StringSlice) -> Bool:
    """Return True when graphql-js 16 `parseLiteral` of a specified scalar
    accepts a literal."""
    if name == "Int":
        return kind == Kind.INT and _is_int32(text)
    if name == "Float":
        return kind == Kind.INT or kind == Kind.FLOAT
    if name == "String":
        return kind == Kind.STRING
    if name == "Boolean":
        return kind == Kind.BOOLEAN
    return kind == Kind.STRING or kind == Kind.INT


def _is_valid_default(
    state: SubgraphState, type: String, document: Document, value: Int
) raises -> Bool:
    """Return True when a default value fits a printed type, as upstream
    `isValidateDefaultValue`."""
    var kind = document.kind(value)
    if _is_non_null(type):
        if kind == Kind.NULL:
            return False
        return _is_valid_default(state, strip_non_null(type), document, value)
    if kind == Kind.NULL:
        return True
    var name = _named(type)
    var found = state.find_type(name)
    if found != -1 and state.types[found].kind == TypeKind.SCALAR:
        return True
    if _is_list(type):
        if kind != Kind.LIST:
            return _is_valid_default(state, strip_list(type), document, value)
        var item = document.first_child(value)
        while item != NO_NODE:
            if not _is_valid_default(state, strip_list(type), document, item):
                return False
            item = document.next_sibling(item)
        return True
    if is_specified_scalar(name):
        return _parses_as_scalar(name, kind, document.text(value))
    if found == -1:
        return True
    ref input = state.types[found]
    if input.kind == TypeKind.INPUT_OBJECT:
        if kind != Kind.OBJECT:
            return False
        var field = document.first_child(value)
        while field != NO_NODE:
            var at = input.find_input_field(document.name(field))
            if at == -1:
                return False
            if not _is_valid_default(
                state,
                input.input_fields[at].type,
                document,
                document.child(field, Role.VALUE),
            ):
                return False
            field = document.next_sibling(field)
        return True
    if input.kind == TypeKind.ENUM:
        if kind == Kind.ENUM:
            return input.find_value(document.text(value)) != -1
        if kind == Kind.STRING:
            return input.find_value(document.string_value(value)) != -1
    return False


def _is_sub_type(
    state: SubgraphState,
    implementations: Dict[String, StringSet],
    sub_type: String,
    super_type: String,
) -> Bool:
    """Return True when a printed type is a subtype of another, as upstream
    `isTypeSubTypeOf`."""
    var sub = sub_type
    var sup = super_type
    while sub != sup:
        if _is_non_null(sup):
            if not _is_non_null(sub):
                return False
            sub = strip_non_null(sub)
            sup = strip_non_null(sup)
        elif _is_non_null(sub):
            sub = strip_non_null(sub)
        elif _is_list(sup):
            if not _is_list(sub):
                return False
            sub = strip_list(sub)
            sup = strip_list(sup)
        elif _is_list(sub):
            return False
        else:
            var found_super = state.find_type(sup)
            var found_sub = state.find_type(sub)
            if found_super == -1 or found_sub == -1:
                return False
            var sub_kind = state.types[found_sub].kind
            if sub_kind != TypeKind.INTERFACE and sub_kind != TypeKind.OBJECT:
                return False
            ref abstract = state.types[found_super]
            if abstract.kind == TypeKind.UNION:
                return abstract.members.contains(sub)
            var implemented = implementations.get(sup)
            if abstract.kind != TypeKind.INTERFACE or not implemented:
                return False
            return implemented.value().contains(sub)
    return True


def validate_subgraph_state(
    state: SubgraphState,
) raises -> List[CompositionError]:
    """Check the state of a subgraph, as upstream `validateSubgraphState`.

    Args:
        state: The state that the walk built.

    Returns:
        The errors: of the root types, then of the directive definitions,
        then of the types.

    Raises:
        Error: Never; a default value that the state printed parses.
    """
    var validator = _Validator()
    validator.validate_root_types(state)
    validator.validate_directives(state)
    validator.validate_types(state)
    return validator.errors.copy()
