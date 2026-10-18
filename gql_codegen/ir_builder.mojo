# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Build the `operationBased` IR of a validated document.

Port of Apollo Kotlin `apollo-compiler` `ir/IrOperationsBuilder.kt`
(`build`, `toIr`, `merge`, the variable types and the `@include`, `@skip`
and `@defer` conditions), `ir/OperationBasedModelGroupBuilder.kt`
(`buildOperationData`, `buildFragmentData` and `buildField`),
`ir/usedFragments.kt` and the `modelName` of `codegen/LayoutImpl.kt`.

The builder expects a document that the schema validates. It still checks
what upstream checks with `check` and `error`, and raises the upstream
message.

**Differences from upstream.**

- The variables that a fragment uses are not inferred: a fragment
  struct of the generated Mojo has no variables. So the types of those
  variables are not in the used coordinates of a fragment.
- `@optional`, `@nonnull`, `@catch` and `@semanticNonNull` are not read:
  they need a `@link` to an Apollo foreign schema, which is not ported.
- Data builders are not ported, so no field is recorded in the used
  coordinates, only types and arguments.
"""

from gql_json.writer import JsonWriter
from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_schema.definition import NO_TYPE, Schema, TypeKind, TypeRef
from gql_schema.type_from_ast import type_from_ast

from gql_codegen.ir import (
    Conditions,
    IrFieldInfo,
    IrFragment,
    IrModel,
    IrOperation,
    IrOperations,
    IrProperty,
    IrType,
    IrVariable,
)
from gql_codegen.options import CodegenOptions
from gql_codegen.printer import print_executable
from gql_codegen.schema_util import (
    field_type as _field_type,
    is_sub_type_of,
    possible_types,
)
from gql_codegen.strings import (
    capitalize_first_letter,
    decapitalize_first_letter,
    singularize,
)


def ir_type(schema: Schema, type: TypeRef) -> IrType:
    """Map a schema type to an IR type, as upstream `GQLType.toIr`. Every
    level is nullable unless a non-null wraps it.

    Args:
        schema: The schema.
        type: The type reference.

    Returns:
        The IR type, with no model and not optional.
    """
    var current = type
    var lists = 0
    var non_null = UInt32(0)
    while current.is_wrapped():
        if current.is_non_null():
            non_null |= UInt32(1) << UInt32(lists)
        else:
            lists += 1
        current = current.of_type()
    var mask = (UInt32(1) << UInt32(lists + 1)) - 1
    ref named = schema.types[Int(type.named)]
    return IrType(named.name, named.kind, "", lists, mask & ~non_null, False)


def model_name(info: IrFieldInfo) -> String:
    """Return the name of the model of a field, as upstream `modelName`:
    the response name, singular for a list, with a capital first letter.

    Args:
        info: The field.

    Returns:
        Such as `Friend` for `friends: [Character]`.
    """
    if info.type.is_list():
        return capitalize_first_letter(singularize(info.response_name))
    return capitalize_first_letter(info.response_name)


@fieldwise_init
struct _MergedField(Copyable, Movable):
    """The fields with one response name, as upstream `MergedField`."""

    var response_name: String
    """The alias or the name."""
    var type: TypeRef
    """The type of the field definition."""
    var condition: Int
    """The `Or` of the `@include` and `@skip` conditions of the fields."""
    var selections: List[Int]
    """The selections of every field, in order."""
    var has_selections: Bool
    """Whether a field has a selection set."""


struct _Fragments(Movable):
    """The fragment definitions of a document, by name."""

    var names: List[String]
    """The names, in source order."""
    var nodes: List[Int]
    """The definition nodes, in the same order."""

    def __init__(out self, document: Document):
        """Collect the fragment definitions.

        Args:
            document: The document.
        """
        self.names = List[String]()
        self.nodes = List[Int]()
        for definition in document.definitions():
            if document.kind(definition) == Kind.FRAGMENT_DEFINITION:
                self.names.append(String(document.name(definition)))
                self.nodes.append(definition)

    def find(self, name: StringSlice) -> Int:
        """Return the first definition with a name, or `NO_NODE`.

        Args:
            name: The fragment's name.

        Returns:
            The definition node.
        """
        for index in range(len(self.names)):
            if self.names[index] == name:
                return self.nodes[index]
        return NO_NODE


def _selections_of(document: Document, selection_set: Int) -> List[Int]:
    """Return the selections of a selection set, in order."""
    var out = List[Int]()
    if selection_set == NO_NODE:
        return out^
    var current = document.first_child(selection_set)
    while current != NO_NODE:
        out.append(current)
        current = document.next_sibling(current)
    return out^


def _type_condition_name(document: Document, node: Int) -> String:
    """Return the type condition of an inline fragment or a fragment
    definition, or empty when there is none."""
    var condition = document.child(node, Role.TYPE_CONDITION)
    if condition == NO_NODE:
        return ""
    return String(document.name(condition))


def _value_text(document: Document, node: Int) -> String:
    """Print a value for an upstream error message."""
    var kind = document.kind(node)
    if kind == Kind.STRING:
        return '"' + document.string_value(node) + '"'
    if kind == Kind.VARIABLE:
        return "$" + String(document.name(node))
    return String(document.text(node))


def _write_const(mut writer: JsonWriter, document: Document, node: Int):
    """Write a constant value as JSON: an enum value as a string."""
    var kind = document.kind(node)
    if kind == Kind.INT or kind == Kind.FLOAT:
        writer.raw(document.text(node))
    elif kind == Kind.STRING:
        writer.string(document.string_value(node))
    elif kind == Kind.ENUM:
        writer.string(document.text(node))
    elif kind == Kind.BOOLEAN:
        writer.bool(document.boolean_value(node))
    elif kind == Kind.LIST:
        writer.begin_array()
        for item in document.children(node, Role.LIST_ITEM):
            _write_const(writer, document, item)
        writer.end_array()
    elif kind == Kind.OBJECT:
        writer.begin_object()
        for field in document.children(node, Role.FIELD):
            writer.key(document.name(field))
            _write_const(writer, document, document.child(field, Role.VALUE))
        writer.end_object()
    else:
        writer.null()


def const_json(document: Document, node: Int) -> String:
    """Return a constant value, such as a default value, as JSON.

    Args:
        document: The document.
        node: The value node.

    Returns:
        The JSON text; an enum value is a string.
    """
    var writer = JsonWriter()
    _write_const(writer, document, node)
    return writer^.take_string()


struct _Builder(Movable):
    """The state of one IR build."""

    var ir: IrOperations
    """What the builder makes."""
    var options: CodegenOptions
    """The options."""
    var fragments: _Fragments
    """The fragment definitions."""
    var used_fragments_cache: Dict[String, List[String]]
    """The fragments that each fragment uses, as upstream
    `usedFragmentsCache`."""

    def __init__(out self, document: Document, options: CodegenOptions):
        """Start a build.

        Args:
            document: The validated document.
            options: The options.
        """
        self.ir = IrOperations()
        self.options = options
        self.fragments = _Fragments(document)
        self.used_fragments_cache = Dict[String, List[String]]()

    def take(deinit self) -> IrOperations:
        """Return what the builder made.

        Returns:
            The IR.
        """
        return self.ir^

    # --- conditions ------------------------------------------------------

    def include_condition(
        mut self, document: Document, node: Int
    ) raises -> Int:
        """Return the `@include` and `@skip` condition of a node, as
        upstream `List<GQLDirective>.toIncludeBooleanExpression`.

        Args:
            document: The document.
            node: A field, a fragment spread or an inline fragment.

        Returns:
            The condition.

        Raises:
            Error: With the upstream message, for a wrong argument or a
                repeated directive.
        """
        var conditions = List[Int]()
        for directive in document.children(node, Role.DIRECTIVE):
            var name = String(document.name(directive))
            if name != "skip" and name != "include":
                continue
            var arguments = document.children(directive, Role.ARGUMENT)
            if len(arguments) != 1:
                raise Error(
                    "Apollo: wrong number of arguments for '"
                    + name
                    + "' directive: "
                    + String(len(arguments))
                )
            var value = document.child(arguments[0], Role.VALUE)
            var kind = document.kind(value)
            var condition: Int
            if kind == Kind.BOOLEAN:
                condition = Conditions.TRUE if document.boolean_value(
                    value
                ) else Conditions.FALSE
            elif kind == Kind.VARIABLE:
                condition = self.ir.conditions.variable(document.name(value))
            else:
                raise Error(
                    "Apollo: cannot pass "
                    + _value_text(document, value)
                    + " to '"
                    + name
                    + "' directive"
                )
            if name == "skip":
                condition = self.ir.conditions.not_(condition)
            conditions.append(condition)
        for index in range(len(conditions)):
            for other in range(index):
                if conditions[other] == conditions[index]:
                    raise Error(
                        "Apollo: duplicate @skip/@include directives are not"
                        " allowed"
                    )
        if len(conditions) == 0:
            return Conditions.TRUE
        return self.ir.conditions.simplify(self.ir.conditions.and_(conditions))

    def defer_condition(
        mut self, document: Document, directive: Int
    ) raises -> Int:
        """Return the condition of one `@defer`, as upstream
        `GQLDirective.toDeferBooleanExpression`.

        Args:
            document: The document.
            directive: A `@defer` directive.

        Returns:
            The condition.

        Raises:
            Error: With the upstream message, for a wrong argument.
        """
        var if_value = NO_NODE
        var label = Optional[String](None)
        for argument in document.children(directive, Role.ARGUMENT):
            var value = document.child(argument, Role.VALUE)
            if document.name(argument) == "if":
                if_value = value
            elif document.name(argument) == "label":
                if document.kind(value) != Kind.STRING:
                    raise Error(
                        "Apollo: cannot pass "
                        + _value_text(document, value)
                        + " to 'label' argument of 'defer' directive"
                    )
                label = document.string_value(value)
        var element = self.ir.conditions.label(label)
        if if_value == NO_NODE:
            return element
        var kind = document.kind(if_value)
        if kind == Kind.BOOLEAN:
            if document.boolean_value(if_value):
                return element
            return Conditions.TRUE
        if kind == Kind.VARIABLE:
            var variable = self.ir.conditions.variable(document.name(if_value))
            var negated = self.ir.conditions.not_(variable)
            return self.ir.conditions.or_([negated, element])
        raise Error(
            "Apollo: cannot pass "
            + _value_text(document, if_value)
            + " to 'if' argument of 'defer' directive"
        )

    def directive_condition(
        mut self, document: Document, node: Int
    ) raises -> Int:
        """Return the condition of the directives of a fragment, as upstream
        `List<GQLDirective>.toBooleanExpression`: the `@include` and `@skip`
        condition and the `@defer` condition.

        Args:
            document: The document.
            node: A fragment spread or an inline fragment.

        Returns:
            The condition.

        Raises:
            Error: With the upstream message, for a wrong argument or a
                repeated directive.
        """
        var defers = List[Int]()
        for directive in document.children(node, Role.DIRECTIVE):
            if document.name(directive) == "defer":
                defers.append(self.defer_condition(document, directive))
        var defer = Conditions.TRUE
        if len(defers) > 1:
            raise Error("Apollo: duplicate @defer directives are not allowed")
        if len(defers) == 1:
            defer = defers[0]
        var include = self.include_condition(document, node)
        return self.ir.conditions.simplify(
            self.ir.conditions.and_([defer, include])
        )

    def type_condition(
        mut self,
        schema: Schema,
        type: Int,
        parent_type_conditions: List[Int],
    ) -> Int:
        """Return `True` when a parent type condition is a sub type of a
        type condition, else the possible types of the type condition.

        Args:
            schema: The schema.
            type: The type condition.
            parent_type_conditions: The type conditions of the parents.

        Returns:
            The condition.
        """
        # The parents always hold at least the parent type.
        for parent in parent_type_conditions:  # pragma: no branch
            if is_sub_type_of(schema, parent, type):
                return Conditions.TRUE
        var names = List[String]()
        for possible in possible_types(schema, type):
            names.append(schema.types[possible].name)
        return self.ir.conditions.possible_types(names^)

    # --- fields ----------------------------------------------------------

    def merge(
        mut self,
        document: Document,
        schema: Schema,
        fields: List[Int],
        parent: Int,
    ) raises -> List[_MergedField]:
        """Merge the fields of a selection set by response name, as
        upstream `IrOperationsBuilder.merge`, and record their types and
        arguments.

        Args:
            document: The document.
            schema: The schema.
            fields: The field nodes.
            parent: The parent type.

        Returns:
            One merged field per response name, in first-use order.

        Raises:
            Error: When a field is not defined, as upstream.
        """
        var out = List[_MergedField]()
        var names = List[String]()
        var firsts = List[Int]()
        var conditions = List[List[Int]]()
        var parent_name = schema.types[parent].name
        for field in fields:
            var name = String(document.name(field))
            var alias = document.child(field, Role.ALIAS)
            var response = name if alias == NO_NODE else String(
                document.text(alias)
            )
            var type = _field_type(schema, parent, name)
            if Int(type.named) == NO_TYPE:
                raise Error(
                    "cannot find field definition for field '"
                    + response
                    + "' of type '"
                    + parent_name
                    + "'"
                )
            var condition = self.include_condition(document, field)
            var selection_set = document.child(field, Role.SELECTION_SET)
            var at = -1
            for index in range(len(names)):
                if names[index] == response:
                    at = index
            if at < 0:
                names.append(response)
                firsts.append(field)
                conditions.append(List[Int]())
                out.append(
                    _MergedField(response, type, Conditions.TRUE, [], False)
                )
                at = len(out) - 1
            conditions[at].append(condition)
            if selection_set != NO_NODE:
                out[at].has_selections = True
                out[at].selections.extend(
                    _selections_of(document, selection_set)
                )
        for index in range(len(out)):
            out[index].condition = self.ir.conditions.simplify(
                self.ir.conditions.or_(conditions[index])
            )
            var first = firsts[index]
            self.ir.used_coordinates.put_type(
                schema.types[Int(out[index].type.named)].name
            )
            for argument in document.children(first, Role.ARGUMENT):
                self.ir.used_coordinates.put_argument(
                    parent_name, document.name(first), document.name(argument)
                )
        return out^

    def build_field(
        mut self,
        document: Document,
        schema: Schema,
        path: String,
        var info: IrFieldInfo,
        selections: List[Int],
        has_selections: Bool,
        parent: Int,
        condition: Int,
        parent_type_conditions: List[Int],
    ) raises -> Tuple[IrProperty, Int]:
        """Build the property of a field and the model of its selections, as
        upstream `OperationBasedModelGroupBuilder.buildField`.

        Args:
            document: The document.
            schema: The schema.
            path: The id of the parent model.
            info: The field.
            selections: The selections of the field.
            has_selections: Whether the field has a selection set; a leaf
                field has no model.
            parent: The type of the selections.
            condition: The condition of the property.
            parent_type_conditions: The type conditions on the way here.

        Returns:
            The property, and the index of its model or -1.

        Raises:
            Error: With the upstream message, for a field that is not
                defined or a wrong directive argument.
        """
        if not has_selections:
            return (IrProperty(info^, condition, False, "", ""), -1)
        var self_path = path + "." + info.response_name
        var fields = List[Int]()
        var inline_fragments = List[Int]()
        var spreads = List[Int]()
        for selection in selections:
            var kind = document.kind(selection)
            if kind == Kind.FIELD:
                fields.append(selection)
            elif kind == Kind.INLINE_FRAGMENT:
                inline_fragments.append(selection)
            else:
                spreads.append(selection)

        var properties = List[IrProperty]()
        var models = List[Int]()
        var synthetic = List[IrProperty]()
        var synthetic_models = List[Int]()
        var parent_name = schema.types[parent].name

        # Inline fragments, grouped by type condition, then by condition.
        var type_names = List[String]()
        var groups = List[List[Int]]()
        for fragment in inline_fragments:
            var name = _type_condition_name(document, fragment)
            if name == "":
                name = parent_name
            var at = -1
            for index in range(len(type_names)):
                if type_names[index] == name:
                    at = index
            if at < 0:
                type_names.append(name)
                groups.append(List[Int]())
                at = len(groups) - 1
            groups[at].append(fragment)
        for group_index in range(len(groups)):
            var type_name = type_names[group_index]
            var type = schema.type_named(type_name)
            var name_needs_condition = len(groups[group_index]) > 1
            var keys = List[Int]()
            var members = List[List[Int]]()
            # A group holds at least the fragment that made it.
            for fragment in groups[group_index]:  # pragma: no branch
                var key = self.directive_condition(document, fragment)
                var at = -1
                for index in range(len(keys)):
                    if keys[index] == key:
                        at = index
                if at < 0:
                    keys.append(key)
                    members.append(List[Int]())
                    at = len(keys) - 1
                members[at].append(fragment)
            for key_index in range(len(keys)):  # pragma: no branch
                var key = keys[key_index]
                var name = capitalize_first_letter(type_name)
                if name_needs_condition and key != Conditions.TRUE:
                    var label = self.ir.conditions.first_label(key)
                    if label >= 0:
                        name += "Defer"
                        ref node = self.ir.conditions.nodes[label]
                        if node.has_label:
                            name += capitalize_first_letter(node.name)
                    else:
                        name += "If" + self.ir.conditions.to_name(key)
                var child_condition = self.type_condition(
                    schema, type, parent_type_conditions
                )
                child_condition = self.ir.conditions.simplify(
                    self.ir.conditions.and_([child_condition, key])
                )
                ref named = schema.types[type]
                var child_type = IrType(
                    named.name,
                    named.kind,
                    "",
                    0,
                    UInt32(0 if child_condition == Conditions.TRUE else 1),
                    False,
                )
                var child_selections = List[Int]()
                for fragment in members[key_index]:  # pragma: no branch
                    child_selections.extend(
                        _selections_of(
                            document,
                            document.child(fragment, Role.SELECTION_SET),
                        )
                    )
                var conditions = parent_type_conditions.copy()
                conditions.append(type)
                var built = self.build_field(
                    document,
                    schema,
                    self_path,
                    IrFieldInfo("on" + name, child_type^, True),
                    child_selections,
                    True,
                    type,
                    child_condition,
                    conditions,
                )
                var property = built[0].copy()
                property.type_condition = type_name
                synthetic.append(property^)
                synthetic_models.append(built[1])

        # Fragment spreads, grouped by name.
        var spread_names = List[String]()
        var spread_groups = List[List[Int]]()
        for spread in spreads:
            var name = String(document.name(spread))
            var at = -1
            for index in range(len(spread_names)):
                if spread_names[index] == name:
                    at = index
            if at < 0:
                spread_names.append(name)
                spread_groups.append(List[Int]())
                at = len(spread_names) - 1
            spread_groups[at].append(spread)
        var spread_properties = List[IrProperty]()
        for group_index in range(len(spread_names)):
            var name = spread_names[group_index]
            var definition = self.fragments.find(name)
            if definition == NO_NODE:
                raise Error("cannot find fragment " + name)
            var type_name = _type_condition_name(document, definition)
            var type = schema.type_named(type_name)
            var child_condition = self.type_condition(
                schema, type, parent_type_conditions
            )
            var alternatives = List[Int]()
            # A group holds at least the spread that made it.
            for spread in spread_groups[group_index]:  # pragma: no branch
                alternatives.append(self.directive_condition(document, spread))
            var either = self.ir.conditions.simplify(
                self.ir.conditions.or_(alternatives)
            )
            child_condition = self.ir.conditions.simplify(
                self.ir.conditions.and_([child_condition, either])
            )
            ref named = schema.types[type]
            var child_type = IrType(
                named.name,
                named.kind,
                "fragmentData." + name + "." + name,
                0,
                UInt32(0 if child_condition == Conditions.TRUE else 1),
                False,
            )
            spread_properties.append(
                IrProperty(
                    IrFieldInfo(
                        decapitalize_first_letter(name), child_type^, True
                    ),
                    child_condition,
                    False,
                    name,
                    type_name,
                )
            )

        var name = model_name(info)

        # Fields, merged by response name.
        for merged in self.merge(document, schema, fields, parent):
            var child_type = ir_type(schema, merged.type)
            if merged.condition != Conditions.TRUE:
                child_type = child_type.with_nullable(True)
            var raw = Int(merged.type.named)
            var built = self.build_field(
                document,
                schema,
                self_path,
                IrFieldInfo(merged.response_name, child_type^, False),
                merged.selections,
                merged.has_selections,
                raw,
                Conditions.TRUE,
                [raw],
            )
            properties.append(built[0].copy())
            if built[1] >= 0:
                models.append(built[1])

        var requires_buffering = (
            len(synthetic) > 0 or len(spread_properties) > 0
        )
        properties.extend(synthetic^)
        for model in synthetic_models:
            models.append(model)
        properties.extend(spread_properties^)
        self.ir.models.append(
            IrModel(self_path, name, parent_name, properties^, models^)
        )
        var patched = info.type.with_model(self_path)
        var response_name = info.response_name
        if info.is_synthetic:
            response_name = decapitalize_first_letter(name)
        return (
            IrProperty(
                IrFieldInfo(response_name, patched^, info.is_synthetic),
                condition,
                requires_buffering,
                "",
                "",
            ),
            len(self.ir.models) - 1,
        )

    # --- definitions -----------------------------------------------------

    def used_fragments(
        mut self,
        document: Document,
        schema: Schema,
        selections: List[Int],
        parent: Int,
    ) -> List[String]:
        """Return the fragments that selections use, each once, as upstream
        `usedFragments`: the fragments that a fragment uses come before
        it.

        Args:
            document: The document.
            schema: The schema.
            selections: The selections.
            parent: Their type.

        Returns:
            The fragment names.
        """
        var out = List[String]()
        for selection in selections:
            var kind = document.kind(selection)
            var found = List[String]()
            if kind == Kind.FIELD:
                var type = _field_type(schema, parent, document.name(selection))
                if Int(type.named) != NO_TYPE:
                    found = self.used_fragments(
                        document,
                        schema,
                        _selections_of(
                            document,
                            document.child(selection, Role.SELECTION_SET),
                        ),
                        Int(type.named),
                    )
            elif kind == Kind.INLINE_FRAGMENT:
                var name = _type_condition_name(document, selection)
                var type = parent if name == "" else schema.type_named(name)
                found = self.used_fragments(
                    document,
                    schema,
                    _selections_of(
                        document,
                        document.child(selection, Role.SELECTION_SET),
                    ),
                    type,
                )
            else:
                var name = String(document.name(selection))
                var cached = self.used_fragments_cache.get(name)
                if cached:
                    found = cached.value().copy()
                else:
                    # A placeholder ends a fragment cycle, which validation
                    # refuses but a caller of `build_ir` can pass.
                    self.used_fragments_cache[name] = List[String]()
                    var definition = self.fragments.find(name)
                    if definition != NO_NODE:
                        found = self.used_fragments(
                            document,
                            schema,
                            _selections_of(
                                document,
                                document.child(definition, Role.SELECTION_SET),
                            ),
                            schema.type_named(
                                _type_condition_name(document, definition)
                            ),
                        )
                    found.append(name)
                    self.used_fragments_cache[name] = found.copy()
            for ref fragment in found:
                if not fragment in out:
                    out.append(fragment)
        return out^

    def variable(
        mut self, document: Document, schema: Schema, node: Int
    ) raises -> IrVariable:
        """Build a variable, as upstream `GQLVariableDefinition.toIr`.

        Args:
            document: The document.
            schema: The schema.
            node: A variable definition.

        Returns:
            The variable.

        Raises:
            Error: When the type of the variable is not in the schema.
        """
        var name = String(document.name(document.child(node, Role.VARIABLE)))
        var found = type_from_ast(
            schema, document, document.child(node, Role.TYPE)
        )
        if not found:
            raise Error("Apollo: unknown type of variable '$" + name + "'")
        var type = ir_type(schema, found.value())
        self.ir.used_coordinates.put_type(type.name)
        var default = document.child(node, Role.DEFAULT_VALUE)
        var default_json = String("")
        if default != NO_NODE:
            default_json = const_json(document, default)
            type = type.with_optional(True)
        elif type.is_nullable() and (
            self.options.generate_optional_operation_variables
        ):
            type = type.with_optional(True)
        return IrVariable(name, type^, default_json^)

    def operation(
        mut self, document: Document, schema: Schema, node: Int
    ) raises:
        """Build an operation, as upstream `GQLOperationDefinition.toIr`.

        Args:
            document: The document.
            schema: The schema.
            node: An operation definition.

        Raises:
            Error: With the upstream message, for an operation without a
                root type or without a name.
        """
        var operation_type = document.operation(node)
        var root = schema.root_type(operation_type.value)
        if root == NO_TYPE:
            raise Error(
                "ApolloGraphql: cannot find root type for '"
                + String(operation_type.text())
                + "'"
            )
        var name_node = document.child(node, Role.NAME)
        if name_node == NO_NODE:
            raise Error("Apollo doesn't support anonymous operation.")
        var name = String(document.text(name_node))
        var selections = _selections_of(
            document, document.child(node, Role.SELECTION_SET)
        )
        var source = print_executable(document, node)
        for fragment in self.used_fragments(document, schema, selections, root):
            var definition = self.fragments.find(fragment)
            if definition == NO_NODE:
                raise Error("cannot find fragment " + fragment)
            source += "\n"
            source += print_executable(document, definition)
        var root_name = schema.types[root].name
        var data = IrFieldInfo(
            "data",
            IrType(root_name, TypeKind.OBJECT, "", 0, 0, False),
            False,
        )
        var built = self.build_field(
            document,
            schema,
            "operationData." + name,
            data^,
            selections,
            True,
            root,
            Conditions.TRUE,
            [root],
        )
        self.ir.used_coordinates.put_type(root_name)
        var variables = List[IrVariable]()
        for variable in document.children(node, Role.VARIABLE_DEFINITION):
            variables.append(self.variable(document, schema, variable))
        self.ir.operations.append(
            IrOperation(
                name,
                operation_type,
                root_name,
                variables^,
                String(source.rstrip("\n")),
                built[0].copy(),
                built[1],
            )
        )

    def fragment(
        mut self, document: Document, schema: Schema, node: Int
    ) raises:
        """Build a fragment, as upstream `GQLFragmentDefinition.toIr`.

        Args:
            document: The document.
            schema: The schema.
            node: A fragment definition.

        Raises:
            Error: With the upstream message, for a field that is not
                defined or a wrong directive argument.
        """
        var name = String(document.name(node))
        var type_name = _type_condition_name(document, node)
        var type = schema.type_named(type_name)
        ref named = schema.types[type]
        var data = IrFieldInfo(
            name, IrType(type_name, named.kind, "", 0, 0, False), False
        )
        var built = self.build_field(
            document,
            schema,
            "fragmentData." + name,
            data^,
            _selections_of(document, document.child(node, Role.SELECTION_SET)),
            True,
            type,
            Conditions.TRUE,
            [type],
        )
        self.ir.used_coordinates.put_type(type_name)
        self.ir.fragments.append(
            IrFragment(
                name,
                type_name,
                print_executable(document, node),
                built[0].copy(),
                built[1],
                named.kind != TypeKind.OBJECT,
            )
        )

    def add_referenced_types(mut self, schema: Schema):
        """Record the types that the used types reference, as the loop of
        upstream `IrOperationsBuilder.build`: the interfaces of objects and
        interfaces, the members of unions, and the field types of input
        objects.

        Args:
            schema: The schema.
        """
        var visited = List[String]()
        var to_visit = self.ir.used_coordinates.types()
        var index = 0
        while index < len(to_visit):
            var name = to_visit[index]
            index += 1
            if name in visited:
                continue
            visited.append(name)
            var type = schema.type_named(name)
            ref named = schema.types[type]
            var referenced = List[Int]()
            if named.kind == TypeKind.OBJECT or (
                named.kind == TypeKind.INTERFACE
            ):
                referenced = schema.interfaces_of(type)
            elif named.kind == TypeKind.UNION:
                referenced = schema.possible_types(type)
            elif named.kind == TypeKind.INPUT_OBJECT:
                var span = named.input_fields
                for field in range(Int(span.start), span.end()):
                    referenced.append(
                        Int(schema.input_values[field].type.named)
                    )
            for reference in referenced:
                var reference_name = schema.types[reference].name
                self.ir.used_coordinates.put_type(reference_name)
                to_visit.append(reference_name)


def build_ir(
    document: Document, schema: Schema, options: CodegenOptions
) raises -> IrOperations:
    """Build the IR of a validated document, as upstream
    `IrOperationsBuilder.build`.

    Args:
        document: The executable document, after `add_required_fields`.
        schema: The schema.
        options: The options.

    Returns:
        The operations, the fragments, their models and conditions, and the
        used coordinates.

    Raises:
        Error: With the upstream message, for what validation does not
            refuse but the builder cannot build.
    """
    var builder = _Builder(document, options)
    for definition in document.definitions():
        if document.kind(definition) == Kind.OPERATION_DEFINITION:
            builder.operation(document, schema, definition)
    for definition in document.definitions():
        if document.kind(definition) == Kind.FRAGMENT_DEFINITION:
            builder.fragment(document, schema, definition)
    builder.add_referenced_types(schema)
    return builder^.take()
