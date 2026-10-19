# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Validate SDL before a schema is built from it.

Port of graphql-js 16.14.2 `validation/validate.ts` (`validateSDL`,
`assertValidSDL`, `assertValidSDLExtension`), `validation/specifiedRules.ts`
(`specifiedSDLRules`) and the fifteen SDL rules of `validation/rules/`:
`LoneSchemaDefinitionRule`, `UniqueOperationTypesRule`,
`UniqueTypeNamesRule`, `UniqueEnumValueNamesRule`,
`UniqueFieldDefinitionNamesRule`, `UniqueArgumentDefinitionNamesRule`,
`UniqueDirectiveNamesRule`, `KnownTypeNamesRule`, `KnownDirectivesRule`,
`UniqueDirectivesPerLocationRule`, `PossibleTypeExtensionsRule`,
`KnownArgumentNamesOnDirectivesRule`, `UniqueArgumentNamesRule`,
`UniqueInputFieldNamesRule` and `ProvidedRequiredArgumentsOnDirectivesRule`.

graphql-js runs the rules in parallel over one visit of the document: at
each node, each rule in turn sees the node. This module does the same walk
and calls the rules in the same order, so the errors come out in the
graphql-js order. A rule is an `SDLRule` value, not a function.

**Differences from graphql-js.**

- `validate_sdl` takes a list of documents and treats them as one
  document with all their definitions, as graphql-js `concatAST`. An
  error's locations are each in its own document.
- A rule that returns `false` in graphql-js skips the rest of the subtree
  for that rule. No SDL rule has a handler below a node where it returns
  `false`, so the walk does not track this.
- graphql-js gives the location `ARGUMENT_DEFINITION` to a directive on a
  field of an `extend input`. This port does the same.
"""

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_language.directive_location import DirectiveLocation
from gql_language.error import GraphQLError
from gql_schema.builtins import INTROSPECTION_TYPE_NAMES, SPECIFIED_SCALAR_NAMES
from gql_schema.definition import NO_TYPE, AstRef, Schema, TypeKind
from gql_schema.errors import error_at
from gql_language.names import NOT_FOUND, NameTable
from gql_schema.suggestions import did_you_mean, suggestion_list


@fieldwise_init
struct SDLRule(Equatable, ImplicitlyCopyable, Writable):
    """One of the rules of graphql-js `specifiedSDLRules`."""

    var value: UInt8
    """The rule's index in `specifiedSDLRules`; see `is_valid`."""

    comptime LONE_SCHEMA_DEFINITION = SDLRule(0)
    """`LoneSchemaDefinitionRule`: at most one `schema` definition."""
    comptime UNIQUE_OPERATION_TYPES = SDLRule(1)
    """`UniqueOperationTypesRule`: one root type per operation."""
    comptime UNIQUE_TYPE_NAMES = SDLRule(2)
    """`UniqueTypeNamesRule`: one type per name."""
    comptime UNIQUE_ENUM_VALUE_NAMES = SDLRule(3)
    """`UniqueEnumValueNamesRule`: one enum value per name."""
    comptime UNIQUE_FIELD_DEFINITION_NAMES = SDLRule(4)
    """`UniqueFieldDefinitionNamesRule`: one field per name."""
    comptime UNIQUE_ARGUMENT_DEFINITION_NAMES = SDLRule(5)
    """`UniqueArgumentDefinitionNamesRule`: one argument definition per
    name."""
    comptime UNIQUE_DIRECTIVE_NAMES = SDLRule(6)
    """`UniqueDirectiveNamesRule`: one directive per name."""
    comptime KNOWN_TYPE_NAMES = SDLRule(7)
    """`KnownTypeNamesRule`: every referenced type exists."""
    comptime KNOWN_DIRECTIVES = SDLRule(8)
    """`KnownDirectivesRule`: every directive exists and is in place."""
    comptime UNIQUE_DIRECTIVES_PER_LOCATION = SDLRule(9)
    """`UniqueDirectivesPerLocationRule`: a non-repeatable directive once
    per location."""
    comptime POSSIBLE_TYPE_EXTENSIONS = SDLRule(10)
    """`PossibleTypeExtensionsRule`: an extension extends a type of its
    kind."""
    comptime KNOWN_ARGUMENT_NAMES_ON_DIRECTIVES = SDLRule(11)
    """`KnownArgumentNamesOnDirectivesRule`: every directive argument
    exists."""
    comptime UNIQUE_ARGUMENT_NAMES = SDLRule(12)
    """`UniqueArgumentNamesRule`: one argument per name."""
    comptime UNIQUE_INPUT_FIELD_NAMES = SDLRule(13)
    """`UniqueInputFieldNamesRule`: one input object field per name."""
    comptime PROVIDED_REQUIRED_ARGUMENTS_ON_DIRECTIVES = SDLRule(14)
    """`ProvidedRequiredArgumentsOnDirectivesRule`: every required directive
    argument is given."""
    comptime COUNT = 15
    """How many rules there are."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the fifteen rules.

        Returns:
            Whether the value is in range.
        """
        return self.value < UInt8(SDLRule.COUNT)

    def text(self) -> StaticString:
        """Return the graphql-js name of the rule, such as
        `UniqueTypeNamesRule`.

        Returns:
            The name, or `<invalid>`.
        """
        comptime names: Array[StaticString, 15] = [
            "LoneSchemaDefinitionRule",
            "UniqueOperationTypesRule",
            "UniqueTypeNamesRule",
            "UniqueEnumValueNamesRule",
            "UniqueFieldDefinitionNamesRule",
            "UniqueArgumentDefinitionNamesRule",
            "UniqueDirectiveNamesRule",
            "KnownTypeNamesRule",
            "KnownDirectivesRule",
            "UniqueDirectivesPerLocationRule",
            "PossibleTypeExtensionsRule",
            "KnownArgumentNamesOnDirectivesRule",
            "UniqueArgumentNamesRule",
            "UniqueInputFieldNamesRule",
            "ProvidedRequiredArgumentsOnDirectivesRule",
        ]
        if not self.is_valid():
            return "<invalid>"
        return materialize[names]()[Int(self.value)]

    def write_to(self, mut writer: Some[Writer]):
        """Write the graphql-js name of the rule.

        Args:
            writer: The destination.
        """
        writer.write(self.text())


def specified_sdl_rules() -> List[SDLRule]:
    """Return the rules of graphql-js `specifiedSDLRules`, in order.

    Returns:
        The fifteen rules.
    """
    var rules = List[SDLRule](capacity=SDLRule.COUNT)
    var index = 0
    while index < SDLRule.COUNT:
        rules.append(SDLRule(UInt8(index)))
        index += 1
    return rules^


# For each `Kind`, the directive location of a node of that kind, as
# graphql-js `getDirectiveLocationForASTPath`. An operation and an input
# value definition depend on more than the kind; a kind that cannot hold a
# directive has 0.
comptime _LOCATION_OF_KIND: Array[UInt8, 49] = [
    0,
    0,
    0,
    7,
    0,
    3,
    0,
    5,
    6,
    4,  # Name .. FragmentDefinition
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,  # Variable .. ObjectField
    0,
    0,
    0,
    0,
    8,
    0,
    9,
    10,
    11,
    0,  # Directive .. InputValueDefinition
    13,
    14,
    15,
    16,
    17,
    19,
    8,
    19,
    9,
    10,  # Interface .. ObjectTypeExtension
    13,
    14,
    15,
    17,
    0,
    0,
    0,
    0,
    0,  # InterfaceTypeExtension .. coordinates
]

# For each `Kind`, the `TypeKind` that a type definition or a type extension
# of that kind gives.
comptime _TYPE_KIND_OF_KIND: Array[UInt8, 49] = [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,  # ScalarTypeDefinition, ObjectTypeDefinition
    2,
    3,
    4,
    0,
    5,
    0,
    0,
    0,
    0,
    1,  # .. ObjectTypeExtension
    2,
    3,
    4,
    5,
    0,
    0,
    0,
    0,
    0,
]


def _kind_text(kind: TypeKind) -> StaticString:
    """Return the kind word of graphql-js `extensionKindToTypeName`."""
    if kind == TypeKind.SCALAR:
        return "scalar"
    if kind == TypeKind.OBJECT:
        return "object"
    if kind == TypeKind.INTERFACE:
        return "interface"
    if kind == TypeKind.UNION:
        return "union"
    if kind == TypeKind.ENUM:
        return "enum"
    return "input object"


def _print_type(document: Document, node: Int) -> String:
    """Return a type reference as graphql-js `print` writes it."""
    var suffix = String("")
    var prefix = String("")
    var current = node
    while document.kind(current) != Kind.NAMED_TYPE:
        if document.kind(current) == Kind.LIST_TYPE:
            prefix += "["
            suffix = "]" + suffix
        else:
            suffix = "!" + suffix
        current = document.first_child(current)
    return prefix + String(document.name(current)) + suffix


struct _Directive(Copyable, Movable):
    """What the rules know of one directive."""

    var locations: UInt32
    """One bit per `DirectiveLocation` where it can appear."""
    var unique: Bool
    """Whether it is not repeatable."""
    var arguments: List[String]
    """Its argument names."""
    var required: List[String]
    """The names of its required arguments."""
    var required_types: List[String]
    """The printed type of each required argument."""

    def __init__(out self, locations: UInt32, unique: Bool):
        """Start a directive with no arguments.

        Args:
            locations: The location bits.
            unique: Whether it is not repeatable.
        """
        self.locations = locations
        self.unique = unique
        self.arguments = List[String]()
        self.required = List[String]()
        self.required_types = List[String]()

    def add_argument(mut self, name: String, required: Bool, type: String):
        """Add an argument, as graphql-js `keyMap` keeps the last of a name.

        Args:
            name: The argument's name.
            required: Whether it is non-null without a default.
            type: Its printed type.
        """
        self.arguments.append(name)
        if not required:
            return
        for index in range(len(self.required)):
            if self.required[index] == name:
                self.required_types[index] = type
                return
        self.required.append(name)
        self.required_types.append(type)


@always_inline
def _bit(location: DirectiveLocation) -> UInt32:
    """Return a location's bit."""
    return UInt32(1) << UInt32(location.value)


struct _Validator(Movable):
    """The state of all the rules during one walk."""

    var rules: List[SDLRule]
    var errors: List[GraphQLError]
    # Nodes that the name tables below remember, by index.
    var refs: List[AstRef]
    # LoneSchemaDefinitionRule.
    var schema_already_defined: Bool
    var schema_definitions: Int
    # UniqueOperationTypesRule, by operation type.
    var existing_operations: List[Bool]
    var defined_operations: List[AstRef]
    # Unique*NamesRule: the first node of each name.
    var type_names: NameTable
    var enum_value_names: NameTable
    var field_names: NameTable
    var directive_names: NameTable
    # The last type definition of each name, and the names in order.
    var defined_types: NameTable
    var defined_type_names: List[String]
    # The directives that the schema and the documents define.
    var directive_table: NameTable
    var directives: List[_Directive]
    # UniqueDirectivesPerLocationRule: the first use in each scope.
    var directive_uses: NameTable
    # UniqueInputFieldNamesRule: a scope per object value.
    var object_scopes: List[Int]
    var object_count: Int
    var input_field_names: NameTable

    def __init__(out self, var rules: List[SDLRule]):
        """Start with empty state."""
        self.rules = rules^
        self.errors = List[GraphQLError]()
        self.refs = List[AstRef]()
        self.schema_already_defined = False
        self.schema_definitions = 0
        self.existing_operations = [False, False, False]
        self.defined_operations = [AstRef.NONE, AstRef.NONE, AstRef.NONE]
        self.type_names = NameTable()
        self.enum_value_names = NameTable()
        self.field_names = NameTable()
        self.directive_names = NameTable()
        self.defined_types = NameTable()
        self.defined_type_names = List[String]()
        self.directive_table = NameTable()
        self.directives = List[_Directive]()
        self.directive_uses = NameTable()
        self.object_scopes = List[Int]()
        self.object_count = 0
        self.input_field_names = NameTable()

    # --- setup ------------------------------------------------------------

    def add_directive(mut self, name: StringSlice, var directive: _Directive):
        """Define a directive; a later definition of a name wins."""
        self.directive_table.assign(-1, name, len(self.directives))
        self.directives.append(directive^)

    def add_specified_directives(mut self):
        """Define graphql-js `specifiedDirectives`."""
        var executable = (
            _bit(DirectiveLocation.FIELD)
            | _bit(DirectiveLocation.FRAGMENT_SPREAD)
            | _bit(DirectiveLocation.INLINE_FRAGMENT)
        )
        var include = _Directive(executable, True)
        include.add_argument("if", True, "Boolean!")
        self.add_directive("include", include^)
        var skip = _Directive(executable, True)
        skip.add_argument("if", True, "Boolean!")
        self.add_directive("skip", skip^)
        var deprecated = _Directive(
            _bit(DirectiveLocation.FIELD_DEFINITION)
            | _bit(DirectiveLocation.ARGUMENT_DEFINITION)
            | _bit(DirectiveLocation.INPUT_FIELD_DEFINITION)
            | _bit(DirectiveLocation.ENUM_VALUE)
            | _bit(DirectiveLocation.DIRECTIVE_DEFINITION),
            True,
        )
        deprecated.add_argument("reason", False, "String")
        self.add_directive("deprecated", deprecated^)
        var specified_by = _Directive(_bit(DirectiveLocation.SCALAR), True)
        specified_by.add_argument("url", True, "String!")
        self.add_directive("specifiedBy", specified_by^)
        self.add_directive(
            "oneOf", _Directive(_bit(DirectiveLocation.INPUT_OBJECT), True)
        )

    def add_schema_directives(mut self, schema: Schema):
        """Define the directives of the schema being extended."""
        var position = 0
        while position < len(schema.directives):
            ref found = schema.directives[position]
            position += 1
            var directive = _Directive(found.locations, not found.is_repeatable)
            for index in range(
                Int(found.arguments.start), found.arguments.end()
            ):
                ref argument = schema.input_values[index]
                directive.add_argument(
                    argument.name,
                    argument.type.is_non_null() and not argument.has_default(),
                    schema.type_name(argument.type),
                )
            self.add_directive(found.name, directive^)

    def add_document_directive(mut self, document: Document, node: Int):
        """Define a directive from its definition node."""
        var locations: UInt32 = 0
        var current = document.child(node, Role.LOCATION)
        while current != NO_NODE:
            # The parser accepts only location names; a name that is not
            # one maps to bit 31, which no location uses.
            var index = DirectiveLocation.from_name(document.text(current))
            locations |= UInt32(1) << UInt32(index & 31)
            current = document.next_with_role(current)
        var directive = _Directive(locations, not document.is_repeatable(node))
        current = document.child(node, Role.ARGUMENT)
        while current != NO_NODE:
            var type = document.child(current, Role.TYPE)
            directive.add_argument(
                String(document.name(current)),
                document.kind(type) == Kind.NON_NULL_TYPE
                and document.child(current, Role.DEFAULT_VALUE) == NO_NODE,
                _print_type(document, type),
            )
            current = document.next_with_role(current)
        self.add_directive(document.name(node), directive^)

    def prepare(
        mut self, documents: List[Document], schema: Schema, has_schema: Bool
    ):
        """Read what the rules need before the walk."""
        self.schema_already_defined = (
            schema.schema_definition.exists()
            or schema.root_type(0) != NO_TYPE
            or schema.root_type(1) != NO_TYPE
            or schema.root_type(2) != NO_TYPE
        )
        self.existing_operations[0] = schema.root_type(0) != NO_TYPE
        self.existing_operations[1] = schema.root_type(1) != NO_TYPE
        self.existing_operations[2] = schema.root_type(2) != NO_TYPE
        if has_schema:
            self.add_schema_directives(schema)
        else:
            self.add_specified_directives()
        for index in range(len(documents)):
            ref document = documents[index]
            var current = document.first_child(document.root)
            while current != NO_NODE:
                var kind = document.kind(current)
                if kind.is_type_definition():
                    var name = document.name(current)
                    if self.defined_types.find(-1, name) == NOT_FOUND:
                        self.defined_type_names.append(String(name))
                    self.defined_types.assign(-1, name, len(self.refs))
                    self.refs.append(AstRef(Int32(index), Int32(current)))
                elif kind == Kind.DIRECTIVE_DEFINITION:
                    self.add_document_directive(document, current)
                current = document.next_sibling(current)

    # --- reporting ----------------------------------------------------------

    def report(
        mut self,
        message: String,
        documents: List[Document],
        var nodes: List[AstRef],
    ):
        """Record an error located at nodes."""
        self.errors.append(error_at(message, documents, nodes))

    def take_errors(deinit self) -> List[GraphQLError]:
        """Return the errors, ending the walk."""
        return self.errors^

    def remember(mut self, document: Int, node: Int) -> Int:
        """Keep a node for a name table, and return its index in `refs`."""
        self.refs.append(AstRef(Int32(document), Int32(node)))
        return len(self.refs) - 1

    def check_argument_groups(
        mut self,
        documents: List[Document],
        document: Int,
        parent: Int,
        before: String,
        after: String,
    ):
        """Report each argument name used more than once under a node.

        The message is `before + name + after`, and the error is at every
        `name` node of the group, as graphql-js `groupBy`.
        """
        ref doc = documents[document]
        var groups = NameTable()
        var names = List[List[AstRef]]()
        var current = doc.child(parent, Role.ARGUMENT)
        while current != NO_NODE:
            var name = doc.child(current, Role.NAME)
            var at = AstRef(Int32(document), Int32(name))
            var group = groups.find(-1, doc.text(name))
            if group == NOT_FOUND:
                _ = groups.insert(-1, doc.text(name), len(names))
                names.append([at])
            else:
                names[group].append(at)
            current = doc.next_with_role(current)
        for ref group in names:
            if len(group) > 1:
                var name = String(doc.text(Int(group[0].node)))
                self.report(before + name + after, documents, group.copy())

    # --- the walk -------------------------------------------------------------

    def walk(mut self, documents: List[Document], schema: Schema):
        """Visit every node of every document, depth first."""
        for index in range(len(documents)):
            ref document = documents[index]
            var path: List[Int] = [document.root]
            var current = document.first_child(document.root)
            while len(path) > 0:
                if current != NO_NODE:
                    path.append(current)
                    self.enter(documents, schema, index, path)
                    current = document.first_child(current)
                else:
                    var done = path.pop()
                    self.leave(documents, index, done)
                    current = document.next_sibling(done)

    def enter(
        mut self,
        documents: List[Document],
        schema: Schema,
        document: Int,
        path: List[Int],
    ):
        """Call each rule on entry to the last node of a path."""
        var node = path[len(path) - 1]
        var kind = documents[document].kind(node)
        for position in range(len(self.rules)):
            var rule = self.rules[position]
            if rule == SDLRule.LONE_SCHEMA_DEFINITION:
                if kind == Kind.SCHEMA_DEFINITION:
                    self.lone_schema_definition(documents, document, node)
            elif rule == SDLRule.UNIQUE_OPERATION_TYPES:
                if (
                    kind == Kind.SCHEMA_DEFINITION
                    or kind == Kind.SCHEMA_EXTENSION
                ):
                    self.unique_operation_types(documents, document, node)
            elif rule == SDLRule.UNIQUE_TYPE_NAMES:
                if kind.is_type_definition():
                    self.unique_type_names(documents, schema, document, node)
            elif rule == SDLRule.UNIQUE_ENUM_VALUE_NAMES:
                if (
                    kind == Kind.ENUM_TYPE_DEFINITION
                    or kind == Kind.ENUM_TYPE_EXTENSION
                ):
                    self.unique_enum_value_names(
                        documents, schema, document, node
                    )
            elif rule == SDLRule.UNIQUE_FIELD_DEFINITION_NAMES:
                if _has_field_definitions(kind):
                    self.unique_field_definition_names(
                        documents, schema, document, node
                    )
            elif rule == SDLRule.UNIQUE_ARGUMENT_DEFINITION_NAMES:
                self.unique_argument_definition_names(
                    documents, document, node, kind
                )
            elif rule == SDLRule.UNIQUE_DIRECTIVE_NAMES:
                if kind == Kind.DIRECTIVE_DEFINITION:
                    self.unique_directive_names(
                        documents, schema, document, node
                    )
            elif rule == SDLRule.KNOWN_TYPE_NAMES:
                if kind == Kind.NAMED_TYPE:
                    self.known_type_names(documents, schema, document, path)
            elif rule == SDLRule.KNOWN_DIRECTIVES:
                if kind == Kind.DIRECTIVE:
                    self.known_directives(documents, document, path)
            elif rule == SDLRule.UNIQUE_DIRECTIVES_PER_LOCATION:
                self.unique_directives_per_location(documents, document, node)
            elif rule == SDLRule.POSSIBLE_TYPE_EXTENSIONS:
                if kind.is_type_extension():
                    self.possible_type_extensions(
                        documents, schema, document, node
                    )
            elif rule == SDLRule.KNOWN_ARGUMENT_NAMES_ON_DIRECTIVES:
                if kind == Kind.DIRECTIVE:
                    self.known_argument_names(documents, document, node)
            elif rule == SDLRule.UNIQUE_ARGUMENT_NAMES:
                if kind == Kind.FIELD or kind == Kind.DIRECTIVE:
                    self.check_argument_groups(
                        documents,
                        document,
                        node,
                        'There can be only one argument named "',
                        '".',
                    )
            elif rule == SDLRule.UNIQUE_INPUT_FIELD_NAMES:
                if kind == Kind.OBJECT:
                    self.object_scopes.append(self.object_count)
                    self.object_count += 1
                elif kind == Kind.OBJECT_FIELD:
                    self.unique_input_field_name(documents, document, node)

    def leave(mut self, documents: List[Document], document: Int, node: Int):
        """Call each rule on exit from a node."""
        var kind = documents[document].kind(node)
        for position in range(len(self.rules)):
            var rule = self.rules[position]
            if rule == SDLRule.UNIQUE_INPUT_FIELD_NAMES:
                if kind == Kind.OBJECT:
                    _ = self.object_scopes.pop()
            elif rule == SDLRule.PROVIDED_REQUIRED_ARGUMENTS_ON_DIRECTIVES:
                if kind == Kind.DIRECTIVE:
                    self.provided_required_arguments(documents, document, node)

    # --- the rules --------------------------------------------------------------

    def lone_schema_definition(
        mut self, documents: List[Document], document: Int, node: Int
    ):
        """LoneSchemaDefinitionRule, on a `SchemaDefinition`."""
        var at = AstRef(Int32(document), Int32(node))
        if self.schema_already_defined:
            self.report(
                "Cannot define a new schema within a schema extension.",
                documents,
                [at],
            )
            return
        if self.schema_definitions > 0:
            self.report(
                "Must provide only one schema definition.", documents, [at]
            )
        self.schema_definitions += 1

    def unique_operation_types(
        mut self, documents: List[Document], document: Int, node: Int
    ):
        """UniqueOperationTypesRule, on a schema definition or extension."""
        ref doc = documents[document]
        var current = doc.child(node, Role.OPERATION_TYPE)
        while current != NO_NODE:
            var operation = doc.operation(current)
            var index = Int(operation.value)
            var at = AstRef(Int32(document), Int32(current))
            if self.existing_operations[index]:
                self.report(
                    String("Type for ")
                    + operation.text()
                    + " already defined in the schema. It cannot be redefined.",
                    documents,
                    [at],
                )
            elif self.defined_operations[index].exists():
                self.report(
                    String("There can be only one ")
                    + operation.text()
                    + " type in schema.",
                    documents,
                    [self.defined_operations[index], at],
                )
            else:
                self.defined_operations[index] = at
            current = doc.next_with_role(current)

    def unique_type_names(
        mut self,
        documents: List[Document],
        schema: Schema,
        document: Int,
        node: Int,
    ):
        """UniqueTypeNamesRule, on a type definition."""
        ref doc = documents[document]
        var name_node = doc.child(node, Role.NAME)
        var name = String(doc.text(name_node))
        if schema.type_named(name) != NO_TYPE:
            self.report(
                'Type "'
                + name
                + '" already exists in the schema. It cannot also be defined in'
                " this type definition.",
                documents,
                [AstRef(Int32(document), Int32(name_node))],
            )
            return
        _check_unique(
            self.type_names,
            self.refs,
            self.errors,
            name,
            'There can be only one type named "' + name + '".',
            documents,
            document,
            name_node,
        )

    def unique_enum_value_names(
        mut self,
        documents: List[Document],
        schema: Schema,
        document: Int,
        node: Int,
    ):
        """UniqueEnumValueNamesRule, on an enum definition or extension."""
        ref doc = documents[document]
        var type_name = String(doc.name(node))
        var existing = schema.type_named(type_name)
        var current = doc.child(node, Role.ENUM_VALUE)
        while current != NO_NODE:
            var name_node = doc.child(current, Role.NAME)
            var key = type_name + "." + String(doc.text(name_node))
            if (
                existing != NO_TYPE
                and schema.enum_value_named(existing, doc.text(name_node))
                != NO_TYPE
            ):
                self.report(
                    'Enum value "'
                    + key
                    + '" already exists in the schema. It cannot also be'
                    " defined in this type extension.",
                    documents,
                    [AstRef(Int32(document), Int32(name_node))],
                )
            else:
                _check_unique(
                    self.enum_value_names,
                    self.refs,
                    self.errors,
                    key,
                    'Enum value "' + key + '" can only be defined once.',
                    documents,
                    document,
                    name_node,
                )
            current = doc.next_with_role(current)

    def unique_field_definition_names(
        mut self,
        documents: List[Document],
        schema: Schema,
        document: Int,
        node: Int,
    ):
        """UniqueFieldDefinitionNamesRule, on a type with fields."""
        ref doc = documents[document]
        var type_name = String(doc.name(node))
        var existing = schema.type_named(type_name)
        var current = doc.child(node, Role.FIELD)
        while current != NO_NODE:
            var name_node = doc.child(current, Role.NAME)
            var name = doc.text(name_node)
            var key = type_name + "." + String(name)
            if existing != NO_TYPE and (
                schema.field_named(existing, name) != NO_TYPE
                or schema.input_field_named(existing, name) != NO_TYPE
            ):
                self.report(
                    'Field "'
                    + key
                    + '" already exists in the schema. It cannot also be'
                    " defined in this type extension.",
                    documents,
                    [AstRef(Int32(document), Int32(name_node))],
                )
            else:
                _check_unique(
                    self.field_names,
                    self.refs,
                    self.errors,
                    key,
                    'Field "' + key + '" can only be defined once.',
                    documents,
                    document,
                    name_node,
                )
            current = doc.next_with_role(current)

    def unique_argument_definition_names(
        mut self,
        documents: List[Document],
        document: Int,
        node: Int,
        kind: Kind,
    ):
        """UniqueArgumentDefinitionNamesRule, on a directive definition or
        a type with fields."""
        ref doc = documents[document]
        if kind == Kind.DIRECTIVE_DEFINITION:
            self.check_argument_groups(
                documents,
                document,
                node,
                'Argument "@' + String(doc.name(node)) + "(",
                ':)" can only be defined once.',
            )
            return
        if not (
            kind == Kind.OBJECT_TYPE_DEFINITION
            or kind == Kind.OBJECT_TYPE_EXTENSION
            or kind == Kind.INTERFACE_TYPE_DEFINITION
            or kind == Kind.INTERFACE_TYPE_EXTENSION
        ):
            return
        var type_name = String(doc.name(node))
        var current = doc.child(node, Role.FIELD)
        while current != NO_NODE:
            self.check_argument_groups(
                documents,
                document,
                current,
                'Argument "'
                + type_name
                + "."
                + String(doc.name(current))
                + "(",
                ':)" can only be defined once.',
            )
            current = doc.next_with_role(current)

    def unique_directive_names(
        mut self,
        documents: List[Document],
        schema: Schema,
        document: Int,
        node: Int,
    ):
        """UniqueDirectiveNamesRule, on a directive definition."""
        ref doc = documents[document]
        var name_node = doc.child(node, Role.NAME)
        var name = String(doc.text(name_node))
        if schema.directive_named(name) != NO_TYPE:
            self.report(
                'Directive "@'
                + name
                + '" already exists in the schema. It cannot be redefined.',
                documents,
                [AstRef(Int32(document), Int32(name_node))],
            )
            return
        _check_unique(
            self.directive_names,
            self.refs,
            self.errors,
            name,
            'There can be only one directive named "@' + name + '".',
            documents,
            document,
            name_node,
        )

    def known_type_names(
        mut self,
        documents: List[Document],
        schema: Schema,
        document: Int,
        path: List[Int],
    ):
        """KnownTypeNamesRule, on a `NamedType`."""
        ref doc = documents[document]
        var node = path[len(path) - 1]
        var name = String(doc.name(node))
        if (
            schema.type_named(name) != NO_TYPE
            or self.defined_types.find(-1, name) != NOT_FOUND
        ):
            return
        # graphql-js `ancestors[2] ?? parent`: the top-level definition.
        var definition_kind = doc.kind(path[1])
        var is_sdl = (
            definition_kind.is_type_system_definition()
            or definition_kind.is_type_system_extension()
        )
        var options = List[String]()
        if is_sdl:
            var scalars = materialize[SPECIFIED_SCALAR_NAMES]()
            var index = 0
            while index < len(scalars):
                options.append(String(scalars[index]))
                index += 1
            var introspection = materialize[INTROSPECTION_TYPE_NAMES]()
            index = 0
            while index < len(introspection):
                options.append(String(introspection[index]))
                index += 1
            index = 0
            while index < len(options):
                if options[index] == name:
                    return
                index += 1
        for type in schema.type_map:
            options.append(schema.types[Int(type)].name)
        options.extend(self.defined_type_names.copy())
        self.report(
            'Unknown type "'
            + name
            + '".'
            + did_you_mean(suggestion_list(name, options)),
            documents,
            [AstRef(Int32(document), Int32(node))],
        )

    def known_directives(
        mut self, documents: List[Document], document: Int, path: List[Int]
    ):
        """KnownDirectivesRule, on a `Directive`."""
        ref doc = documents[document]
        var node = path[len(path) - 1]
        var name = String(doc.name(node))
        var at = AstRef(Int32(document), Int32(node))
        var found = self.directive_table.find(-1, name)
        if found == NOT_FOUND:
            self.report('Unknown directive "@' + name + '".', documents, [at])
            return
        var location = _location_of(doc, path)
        if self.directives[found].locations & _bit(location) == 0:
            self.report(
                'Directive "@'
                + name
                + '" may not be used on '
                + location.text()
                + ".",
                documents,
                [at],
            )

    def unique_directives_per_location(
        mut self, documents: List[Document], document: Int, node: Int
    ):
        """UniqueDirectivesPerLocationRule, on any node with directives."""
        ref doc = documents[document]
        var current = doc.child(node, Role.DIRECTIVE)
        if current == NO_NODE:
            return
        var kind = doc.kind(node)
        var scope: String
        if kind == Kind.SCHEMA_DEFINITION or kind == Kind.SCHEMA_EXTENSION:
            scope = String("schema")
        elif kind.is_type_definition() or kind.is_type_extension():
            scope = "type " + String(doc.name(node))
        elif (
            kind == Kind.DIRECTIVE_DEFINITION
            or kind == Kind.DIRECTIVE_EXTENSION
        ):
            scope = "directive " + String(doc.name(node))
        else:
            scope = "node " + String(document) + " " + String(node)
        while current != NO_NODE:
            var name = String(doc.name(current))
            var found = self.directive_table.find(-1, name)
            if found != NOT_FOUND and self.directives[found].unique:
                _check_unique(
                    self.directive_uses,
                    self.refs,
                    self.errors,
                    scope + "@" + name,
                    'The directive "@'
                    + name
                    + '" can only be used once at this location.',
                    documents,
                    document,
                    current,
                )
            current = doc.next_with_role(current)

    def possible_type_extensions(
        mut self,
        documents: List[Document],
        schema: Schema,
        document: Int,
        node: Int,
    ):
        """PossibleTypeExtensionsRule, on a type extension."""
        ref doc = documents[document]
        var name_node = doc.child(node, Role.NAME)
        var name = String(doc.text(name_node))
        var definition = self.defined_types.find(-1, name)
        var existing = schema.type_named(name)
        var kind = _type_kind_of(doc.kind(node))
        var at = AstRef(Int32(document), Int32(node))
        if definition != NOT_FOUND or existing != NO_TYPE:
            var expected: TypeKind
            var nodes = List[AstRef]()
            if definition != NOT_FOUND:
                var def_at = self.refs[definition]
                expected = _type_kind_of(
                    documents[Int(def_at.document)].kind(Int(def_at.node))
                )
                nodes.append(def_at)
            else:
                expected = schema.types[existing].kind
            nodes.append(at)
            if expected != kind:
                self.report(
                    String("Cannot extend non-")
                    + _kind_text(kind)
                    + ' type "'
                    + name
                    + '".',
                    documents,
                    nodes^,
                )
            return
        var options = self.defined_type_names.copy()
        for type in schema.type_map:
            options.append(schema.types[Int(type)].name)
        self.report(
            'Cannot extend type "'
            + name
            + '" because it is not defined.'
            + did_you_mean(suggestion_list(name, options)),
            documents,
            [AstRef(Int32(document), Int32(name_node))],
        )

    def known_argument_names(
        mut self, documents: List[Document], document: Int, node: Int
    ):
        """KnownArgumentNamesOnDirectivesRule, on a `Directive`."""
        ref doc = documents[document]
        var directive_name = String(doc.name(node))
        var found = self.directive_table.find(-1, directive_name)
        if found == NOT_FOUND:
            return
        var arguments = self.directives[found].arguments.copy()
        var current = doc.child(node, Role.ARGUMENT)
        while current != NO_NODE:
            var name = String(doc.name(current))
            var known = False
            for ref argument in arguments:
                if argument == name:
                    known = True
            if not known:
                self.report(
                    'Unknown argument "'
                    + name
                    + '" on directive "@'
                    + directive_name
                    + '".'
                    + did_you_mean(suggestion_list(name, arguments)),
                    documents,
                    [AstRef(Int32(document), Int32(current))],
                )
            current = doc.next_with_role(current)

    def unique_input_field_name(
        mut self, documents: List[Document], document: Int, node: Int
    ):
        """UniqueInputFieldNamesRule, on an `ObjectField`."""
        ref doc = documents[document]
        var name_node = doc.child(node, Role.NAME)
        var name = doc.text(name_node)
        var scope = self.object_scopes[len(self.object_scopes) - 1]
        var seen = self.input_field_names.find(scope, name)
        if seen != NOT_FOUND:
            self.report(
                'There can be only one input field named "'
                + String(name)
                + '".',
                documents,
                [self.refs[seen], AstRef(Int32(document), Int32(name_node))],
            )
        else:
            _ = self.input_field_names.insert(
                scope, name, self.remember(document, name_node)
            )

    def provided_required_arguments(
        mut self, documents: List[Document], document: Int, node: Int
    ):
        """ProvidedRequiredArgumentsOnDirectivesRule, on leaving a
        `Directive`."""
        ref doc = documents[document]
        var directive_name = String(doc.name(node))
        var found = self.directive_table.find(-1, directive_name)
        if found == NOT_FOUND:
            return
        var required = self.directives[found].required.copy()
        var required_types = self.directives[found].required_types.copy()
        for index in range(len(required)):
            var name = required[index]
            var provided = False
            var current = doc.child(node, Role.ARGUMENT)
            while current != NO_NODE:
                if doc.name(current) == name:
                    provided = True
                current = doc.next_with_role(current)
            if not provided:
                var message = (
                    'Directive "@'
                    + directive_name
                    + '" argument "'
                    + name
                    + '" of type "'
                    + required_types[index]
                    + '" is required, but it was not provided.'
                )
                self.report(
                    message, documents, [AstRef(Int32(document), Int32(node))]
                )


def _check_unique(
    mut table: NameTable,
    mut refs: List[AstRef],
    mut errors: List[GraphQLError],
    key: String,
    message: String,
    documents: List[Document],
    document: Int,
    node: Int,
):
    """Report a key seen before, at both nodes; else remember it."""
    var at = AstRef(Int32(document), Int32(node))
    var seen = table.find(-1, key)
    if seen != NOT_FOUND:
        errors.append(error_at(message, documents, [refs[seen], at]))
        return
    _ = table.insert(-1, key, len(refs))
    refs.append(at)


def _has_field_definitions(kind: Kind) -> Bool:
    """Return True for an object, interface or input object definition or
    extension."""
    return _type_kind_of(kind).has_fields() or (
        kind == Kind.INPUT_OBJECT_TYPE_DEFINITION
        or kind == Kind.INPUT_OBJECT_TYPE_EXTENSION
    )


def _type_kind_of(kind: Kind) -> TypeKind:
    """Return the `TypeKind` of a type definition or extension kind."""
    return TypeKind(materialize[_TYPE_KIND_OF_KIND]()[Int(kind.value)])


def _location_of(document: Document, path: List[Int]) -> DirectiveLocation:
    """Return the location of a directive, the last node of a path, as
    graphql-js `getDirectiveLocationForASTPath`."""
    var applied_to = path[len(path) - 2]
    var kind = document.kind(applied_to)
    if kind == Kind.OPERATION_DEFINITION:
        # QUERY, MUTATION and SUBSCRIPTION have the operation's index.
        return DirectiveLocation(document.operation(applied_to).value)
    if kind == Kind.INPUT_VALUE_DEFINITION:
        if (
            document.kind(path[len(path) - 3])
            == Kind.INPUT_OBJECT_TYPE_DEFINITION
        ):
            return DirectiveLocation.INPUT_FIELD_DEFINITION
        return DirectiveLocation.ARGUMENT_DEFINITION
    return DirectiveLocation(materialize[_LOCATION_OF_KIND]()[Int(kind.value)])


def _validate(
    documents: List[Document],
    schema: Schema,
    has_schema: Bool,
    var rules: List[SDLRule],
) -> List[GraphQLError]:
    """Run rules over documents, with or without a schema to extend."""
    var validator = _Validator(rules^)
    validator.prepare(documents, schema, has_schema)
    validator.walk(documents, schema)
    return validator^.take_errors()


def validate_sdl(documents: List[Document]) -> List[GraphQLError]:
    """Check SDL with every specified rule, as graphql-js `validateSDL`.

    Args:
        documents: The SDL documents, treated as one document.

    Returns:
        The errors, in graphql-js order; empty when the SDL is valid.
    """
    return _validate(documents, Schema(), False, specified_sdl_rules())


def validate_sdl(
    documents: List[Document], schema_to_extend: Schema
) -> List[GraphQLError]:
    """Check SDL that extends a schema, as graphql-js
    `validateSDL(documentAST, schemaToExtend)`.

    Args:
        documents: The SDL documents, treated as one document.
        schema_to_extend: The schema that the SDL extends.

    Returns:
        The errors, in graphql-js order; empty when the SDL is valid.
    """
    return _validate(documents, schema_to_extend, True, specified_sdl_rules())


def validate_sdl_with_rules(
    documents: List[Document], var rules: List[SDLRule]
) -> List[GraphQLError]:
    """Check SDL with some rules, as graphql-js
    `validateSDL(documentAST, undefined, rules)`.

    Args:
        documents: The SDL documents, treated as one document.
        rules: The rules to run, in the order to run them.

    Returns:
        The errors, in graphql-js order.
    """
    return _validate(documents, Schema(), False, rules^)


def validate_sdl_with_rules(
    documents: List[Document],
    schema_to_extend: Schema,
    var rules: List[SDLRule],
) -> List[GraphQLError]:
    """Check SDL that extends a schema with some rules, as graphql-js
    `validateSDL(documentAST, schemaToExtend, rules)`.

    Args:
        documents: The SDL documents, treated as one document.
        schema_to_extend: The schema that the SDL extends.
        rules: The rules to run, in the order to run them.

    Returns:
        The errors, in graphql-js order.
    """
    return _validate(documents, schema_to_extend, True, rules^)


def _raise_errors(errors: List[GraphQLError]) raises:
    """Raise the messages of errors joined by blank lines, if any."""
    if len(errors) == 0:
        return
    var message = errors[0].message
    var index = 1
    while index < len(errors):
        message += "\n\n" + errors[index].message
        index += 1
    raise Error(message)


def assert_valid_sdl(documents: List[Document]) raises:
    """Raise if SDL is not valid, as graphql-js `assertValidSDL`.

    Args:
        documents: The SDL documents, treated as one document.

    Raises:
        Error: The message of each error of `validate_sdl`, joined by
            blank lines.
    """
    _raise_errors(validate_sdl(documents))


def assert_valid_sdl_extension(
    documents: List[Document], schema: Schema
) raises:
    """Raise if SDL that extends a schema is not valid, as graphql-js
    `assertValidSDLExtension`.

    Args:
        documents: The SDL documents, treated as one document.
        schema: The schema that the SDL extends.

    Raises:
        Error: The message of each error of `validate_sdl`, joined by
            blank lines.
    """
    _raise_errors(validate_sdl(documents, schema))
