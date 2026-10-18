# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The intermediate representation of the code generator: the IR.

Port of Apollo Kotlin `apollo-compiler` `ir/IrOperations.kt`,
`ir/IrType.kt`, `ir/BooleanExpression.kt` and `UsedCoordinates.kt`, for
the `operationBased` models.

**Arenas, not trees.** A Mojo struct cannot hold a list of itself, so the
recursive upstream classes are kept in lists and named by index:

- `Conditions` holds every `BooleanExpression`. A condition is an index.
  The arena makes each distinct condition once, so two conditions are equal
  when their indices are equal, as the upstream data classes are equal.
- `IrOperations.models` holds every `IrModel`. A model names the models of
  its properties by index.

**Differences from upstream.**

- An `IrFieldInfo` keeps no description, deprecation reason or opt-in
  feature: the generated Mojo has no documentation comments.
- `IrType` has no `catchTo` and no `maybeError`: the `@catch`,
  `@semanticNonNull` and `@nonnull` directives of the Apollo foreign
  schemas are not ported.
- The compiled selections (`IrSelectionSet`) are not built: they serve the
  Apollo normalized cache, which is not ported.
"""

from gql_json.writer import write_string
from gql_language.ast import OperationType
from gql_schema.definition import TypeKind

from gql_codegen.strings import capitalize_first_letter


@fieldwise_init
struct ConditionKind(Equatable, ImplicitlyCopyable, Writable):
    """The kind of a condition node, as the upstream subclasses of
    `BooleanExpression` and `BTerm`."""

    var value: UInt8
    """The kind's index; see `is_valid`."""

    comptime TRUE = ConditionKind(0)
    """`BooleanExpression.True`."""
    comptime FALSE = ConditionKind(1)
    """`BooleanExpression.False`."""
    comptime NOT = ConditionKind(2)
    """`BooleanExpression.Not`: one operand."""
    comptime OR = ConditionKind(3)
    """`BooleanExpression.Or`: a set of operands."""
    comptime AND = ConditionKind(4)
    """`BooleanExpression.And`: a set of operands."""
    comptime VARIABLE = ConditionKind(5)
    """An element `BVariable`: true unless the variable is false."""
    comptime LABEL = ConditionKind(6)
    """An element `BLabel`: a `@defer` fragment, with an optional label."""
    comptime POSSIBLE_TYPES = ConditionKind(7)
    """An element `BPossibleTypes`: true when `__typename` is one of the
    types."""

    def is_valid(self) -> Bool:
        """Return True if the value names one of the eight kinds.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 7

    def write_to(self, mut writer: Some[Writer]):
        """Write the kind's index.

        Args:
            writer: The destination.
        """
        writer.write("ConditionKind(", self.value, ")")


@fieldwise_init
struct ConditionNode(Copyable, Movable):
    """One condition: a constant, an element or an operator."""

    var kind: ConditionKind
    """What the node is."""
    var operands: List[Int]
    """The operands of `NOT`, `OR` and `AND`, in insertion order."""
    var name: String
    """The variable of `VARIABLE`, or the label of `LABEL`."""
    var has_label: Bool
    """Whether a `LABEL` has a label; `@defer` without `label` has none."""
    var types: List[String]
    """The type names of `POSSIBLE_TYPES`, in schema order."""


struct Conditions(Copyable, Movable):
    """Every condition of a compilation, each made once."""

    var nodes: List[ConditionNode]
    """The nodes; `TRUE` is 0 and `FALSE` is 1."""
    var _keys: Dict[String, Int]
    """The canonical text of each node, to find an equal node."""

    comptime TRUE = 0
    """The index of `BooleanExpression.True`."""
    comptime FALSE = 1
    """The index of `BooleanExpression.False`."""

    def __init__(out self):
        """Make an arena with `TRUE` and `FALSE`."""
        self.nodes = List[ConditionNode]()
        self._keys = Dict[String, Int]()
        _ = self._intern(
            ConditionNode(ConditionKind.TRUE, [], "", False, []), "T"
        )
        _ = self._intern(
            ConditionNode(ConditionKind.FALSE, [], "", False, []), "F"
        )

    def _intern(mut self, var node: ConditionNode, key: String) -> Int:
        """Return the node with a key, or add the node."""
        var found = self._keys.get(key)
        if found:
            return found.value()
        self.nodes.append(node^)
        self._keys[key] = len(self.nodes) - 1
        return len(self.nodes) - 1

    def key(self, condition: Int) -> String:
        """Return the canonical text of a condition: equal conditions have
        equal texts, whatever the order of the operands of a set.

        Args:
            condition: The condition.

        Returns:
            Such as `&(!(v:a),p:Droid)`.
        """
        ref node = self.nodes[condition]
        var kind = node.kind
        if kind == ConditionKind.TRUE:
            return "T"
        if kind == ConditionKind.FALSE:
            return "F"
        if kind == ConditionKind.VARIABLE:
            return "v:" + node.name
        if kind == ConditionKind.LABEL:
            if node.has_label:
                return "l:" + node.name
            return "l"
        if kind == ConditionKind.POSSIBLE_TYPES:
            var types = node.types.copy()
            sort(types)
            return "p:" + ",".join(types)
        if kind == ConditionKind.NOT:
            return "!(" + self.key(node.operands[0]) + ")"
        var keys = List[String]()
        # An `OR` or `AND` node has at least one operand.
        for operand in node.operands:  # pragma: no branch
            keys.append(self.key(operand))
        sort(keys)
        var operator = "|(" if kind == ConditionKind.OR else "&("
        return operator + ",".join(keys) + ")"

    def variable(mut self, name: StringSlice) -> Int:
        """Return the element `BVariable(name)`.

        Args:
            name: The variable's name, without `$`.

        Returns:
            The condition.
        """
        return self._intern(
            ConditionNode(ConditionKind.VARIABLE, [], String(name), False, []),
            "v:" + String(name),
        )

    def label(mut self, label: Optional[String]) -> Int:
        """Return the element `BLabel(label)`.

        Args:
            label: The `@defer` label, if any.

        Returns:
            The condition.
        """
        if label:
            return self._intern(
                ConditionNode(ConditionKind.LABEL, [], label.value(), True, []),
                "l:" + label.value(),
            )
        return self._intern(
            ConditionNode(ConditionKind.LABEL, [], "", False, []), "l"
        )

    def possible_types(mut self, var types: List[String]) -> Int:
        """Return the element `BPossibleTypes(types)`.

        Args:
            types: The object type names.

        Returns:
            The condition.
        """
        var sorted = types.copy()
        sort(sorted)
        var key = "p:" + ",".join(sorted)
        return self._intern(
            ConditionNode(ConditionKind.POSSIBLE_TYPES, [], "", False, types^),
            key,
        )

    def not_(mut self, operand: Int) -> Int:
        """Return `BooleanExpression.Not(operand)`.

        Args:
            operand: The condition to negate.

        Returns:
            The condition.
        """
        return self._intern(
            ConditionNode(ConditionKind.NOT, [operand], "", False, []),
            "!(" + self.key(operand) + ")",
        )

    def _set(mut self, kind: ConditionKind, operands: List[Int]) -> Int:
        """Return an `OR` or `AND` of a set of operands."""
        var unique = List[Int]()
        # `or_`, `and_` and `simplify` pass at least one operand.
        for operand in operands:  # pragma: no branch
            if not operand in unique:
                unique.append(operand)
        var keys = List[String]()
        for operand in unique:  # pragma: no branch
            keys.append(self.key(operand))
        sort(keys)
        var operator = "|(" if kind == ConditionKind.OR else "&("
        return self._intern(
            ConditionNode(kind, unique^, "", False, []),
            operator + ",".join(keys) + ")",
        )

    def or_(mut self, operands: List[Int]) raises -> Int:
        """Return `BooleanExpression.Or(operands.toSet())`.

        Args:
            operands: The conditions; at least one.

        Returns:
            The condition.

        Raises:
            Error: For no operand, as upstream.
        """
        if len(operands) == 0:
            raise Error(
                "Apollo: cannot create a 'Or' condition from an empty list"
            )
        return self._set(ConditionKind.OR, operands)

    def and_(mut self, operands: List[Int]) raises -> Int:
        """Return `BooleanExpression.And(operands.toSet())`.

        Args:
            operands: The conditions; at least one.

        Returns:
            The condition.

        Raises:
            Error: For no operand, as upstream.
        """
        if len(operands) == 0:
            raise Error(
                "Apollo: cannot create a 'And' condition from an empty list"
            )
        return self._set(ConditionKind.AND, operands)

    def simplify(mut self, condition: Int) -> Int:
        """Simplify a condition, as upstream `simplify`: constants fold, and
        a set of one operand becomes that operand.

        Args:
            condition: The condition.

        Returns:
            The simplified condition.
        """
        var kind = self.nodes[condition].kind
        if kind == ConditionKind.NOT:
            var operand = self.nodes[condition].operands[0]
            if operand == Conditions.TRUE:
                return Conditions.FALSE
            if operand == Conditions.FALSE:
                return Conditions.TRUE
            return condition
        if kind != ConditionKind.OR and kind != ConditionKind.AND:
            return condition
        var is_or = kind == ConditionKind.OR
        # Upstream drops the neutral constant before it simplifies.
        var neutral = Conditions.FALSE if is_or else Conditions.TRUE
        var absorbing = Conditions.TRUE if is_or else Conditions.FALSE
        var operands = self.nodes[condition].operands.copy()
        var simplified = List[Int]()
        # An `OR` or `AND` node has at least one operand.
        for operand in operands:  # pragma: no branch
            if operand != neutral:
                simplified.append(self.simplify(operand))
        if absorbing in simplified:
            return absorbing
        if len(simplified) == 0:
            return neutral
        if len(simplified) == 1:
            return simplified[0]
        return self._set(kind, simplified)

    def to_name(self, condition: Int) -> String:
        """Return the name part of a condition, as upstream
        `BooleanExpression.toName` of `OperationBasedModelGroupBuilder`.

        Args:
            condition: A condition of variables.

        Returns:
            Such as `FooAndNotBar`.
        """
        ref node = self.nodes[condition]
        var kind = node.kind
        if kind == ConditionKind.TRUE:
            return "True"
        if kind == ConditionKind.FALSE:
            return "False"
        if kind == ConditionKind.NOT:
            return "Not" + self.to_name(node.operands[0])
        if kind == ConditionKind.OR or kind == ConditionKind.AND:
            var names = List[String]()
            for operand in node.operands:  # pragma: no branch
                names.append(self.to_name(operand))
            var separator = "Or" if kind == ConditionKind.OR else "And"
            return separator.join(names)
        return capitalize_first_letter(node.name)

    def first_label(self, condition: Int) -> Int:
        """Return the first `LABEL` element of a condition, as upstream
        `firstElementOfType(BLabel::class)`.

        Args:
            condition: The condition.

        Returns:
            The label element, or -1.
        """
        ref node = self.nodes[condition]
        if node.kind == ConditionKind.LABEL:
            return condition
        for operand in node.operands:
            var found = self.first_label(operand)
            if found >= 0:
                return found
        return -1


@fieldwise_init
struct IrType(Copyable, Equatable, Movable):
    """A field or variable type, as upstream `IrType`: a named type or a
    model, in lists, each level nullable or not."""

    var name: String
    """The named type, such as `String`; for a model, the composite type."""
    var kind: TypeKind
    """The kind of the named type."""
    var model: String
    """The id of the model, for a composite type; else empty."""
    var lists: Int
    """How many lists wrap the named type."""
    var nullable: UInt32
    """One bit per level, the outermost in bit 0: 1 when it is nullable.
    The named type is level `lists`."""
    var optional: Bool
    """Whether a variable can be absent, as upstream `optional`."""

    def is_list(self) -> Bool:
        """Return True when the outermost level is a list, as upstream
        `isList`.

        Returns:
            Whether the type is a list.
        """
        return self.lists > 0

    def is_nullable(self, level: Int = 0) -> Bool:
        """Return True when a level is nullable.

        Args:
            level: 0 for the outermost level.

        Returns:
            Whether `null` is allowed at the level.
        """
        return (self.nullable >> UInt32(level)) & 1 == 1

    def with_nullable(self, nullable: Bool) -> IrType:
        """Return the type with its outermost level nullable or not, as
        upstream `nullable`.

        Args:
            nullable: Whether `null` is allowed.

        Returns:
            The new type.
        """
        var out = self.copy()
        if nullable:
            out.nullable |= 1
        else:
            out.nullable &= ~UInt32(1)
        return out^

    def with_optional(self, optional: Bool) -> IrType:
        """Return the type with `optional` set, as upstream `optional`.

        Args:
            optional: Whether the variable can be absent.

        Returns:
            The new type.
        """
        var out = self.copy()
        out.optional = optional
        return out^

    def with_model(self, model: StringSlice) -> IrType:
        """Return the type of a composite field with its model id, as
        upstream `replacePlaceholder`.

        Args:
            model: The id of the model.

        Returns:
            The new type.
        """
        var out = self.copy()
        out.model = String(model)
        return out^

    def text(self) -> String:
        """Return the type as SDL writes it, with the model id for a model.

        Returns:
            Such as `[Hero!]` or `String`.
        """
        var inner = self.name if self.model == "" else self.model
        var out = inner
        if not self.is_nullable(self.lists):
            out += "!"
        var level = self.lists - 1
        while level >= 0:
            out = "[" + out + "]"
            if not self.is_nullable(level):
                out += "!"
            level -= 1
        if self.optional:
            out = "Optional<" + out + ">"
        return out^


@fieldwise_init
struct IrFieldInfo(Copyable, Movable):
    """What a property knows of its field, as upstream `IrFieldInfo`."""

    var response_name: String
    """The response name: the alias or the field name; for a synthetic
    field, such as `onDroid` or `heroDetails`."""
    var type: IrType
    """The type of the property."""
    var is_synthetic: Bool
    """Whether no field of the schema backs the property (upstream
    `gqlType == null`): an inline fragment or a fragment spread."""


@fieldwise_init
struct IrProperty(Copyable, Movable):
    """One property of a model, as upstream `IrProperty`."""

    var info: IrFieldInfo
    """The field."""
    var condition: Int
    """When the property is read: a condition of `Conditions`."""
    var requires_buffering: Bool
    """Whether the model of the property has synthetic fields."""
    var fragment: String
    """The fragment of a fragment spread property; else empty."""
    var type_condition: String
    """The type condition of an inline fragment or a fragment spread."""


@fieldwise_init
struct IrModel(Copyable, Movable):
    """A model: the fields of one selection set, as upstream `IrModel`."""

    var id: String
    """The path of the model, such as `operationData.TestQuery.data.hero`."""
    var model_name: String
    """The name, such as `Hero`."""
    var type_name: String
    """The type of the selection set, such as `Character`."""
    var properties: List[IrProperty]
    """The properties: fields, then inline fragments, then fragment
    spreads."""
    var models: List[Int]
    """The models of the properties that have one, in order."""


@fieldwise_init
struct IrVariable(Copyable, Movable):
    """A variable of an operation, as upstream `IrVariable`."""

    var name: String
    """The name, without `$`."""
    var type: IrType
    """The type; `optional` when it can be absent."""
    var default_json: String
    """The default value as JSON, or empty when there is none."""


@fieldwise_init
struct IrOperation(Copyable, Movable):
    """An operation, as upstream `IrOperationDefinition`."""

    var name: String
    """The operation's name."""
    var operation_type: OperationType
    """Query, mutation or subscription."""
    var type_condition: String
    """The root type, such as `Query`."""
    var variables: List[IrVariable]
    """The variables, in order."""
    var source_with_fragments: String
    """The printed operation and the fragments it uses, without the last
    line feed."""
    var data_property: IrProperty
    """The `data` property."""
    var data_model: Int
    """The root model."""


@fieldwise_init
struct IrFragment(Copyable, Movable):
    """A fragment definition, as upstream `IrFragmentDefinition`."""

    var name: String
    """The fragment's name."""
    var type_condition: String
    """The type condition."""
    var source: String
    """The printed fragment."""
    var data_property: IrProperty
    """The property of the fragment's data."""
    var data_model: Int
    """The root model."""
    var is_type_condition_abstract: Bool
    """Whether the type condition is an interface or a union."""


@fieldwise_init
struct _TypeUse(Copyable, Movable):
    """The fields and arguments of one used type."""

    var name: String
    """The type."""
    var fields: List[String]
    """The used fields, in first-use order."""
    var arguments: List[List[String]]
    """The used arguments of each field."""


struct UsedCoordinates(Copyable, Movable):
    """The types, fields and arguments that the operations use, as upstream
    `UsedCoordinates`."""

    var _uses: List[_TypeUse]
    """One entry per type, in first-use order."""
    var _index: Dict[String, Int]
    """The entry of each type."""

    def __init__(out self):
        """Start with no types."""
        self._uses = List[_TypeUse]()
        self._index = Dict[String, Int]()

    def _entry(mut self, type: StringSlice) -> Int:
        """Return the entry of a type, made on first use."""
        var key = String(type)
        var found = self._index.get(key)
        if found:
            return found.value()
        self._uses.append(_TypeUse(key, [], []))
        self._index[key] = len(self._uses) - 1
        return len(self._uses) - 1

    def put_type(mut self, type: StringSlice):
        """Record a type, as upstream `putType`.

        Args:
            type: The type's name.
        """
        _ = self._entry(type)

    def put_argument(
        mut self, type: StringSlice, field: StringSlice, argument: StringSlice
    ):
        """Record an argument of a field, as upstream `putArgument`.

        Args:
            type: The type's name.
            field: The field's name.
            argument: The argument's name.
        """
        var entry = self._entry(type)
        ref use = self._uses[entry]
        var at = -1
        for index in range(len(use.fields)):
            if use.fields[index] == field:
                at = index
        if at < 0:
            use.fields.append(String(field))
            use.arguments.append(List[String]())
            at = len(use.fields) - 1
        if not String(argument) in use.arguments[at]:
            use.arguments[at].append(String(argument))

    def types(self) -> List[String]:
        """Return the types, in first-use order, as upstream `getTypes`.

        Returns:
            The type names.
        """
        var out = List[String]()
        for ref use in self._uses:
            out.append(use.name)
        return out^

    def has_type(self, type: StringSlice) -> Bool:
        """Return True when a type is recorded, as upstream `hasType`.

        Args:
            type: The type's name.

        Returns:
            Whether the type is used.
        """
        return String(type) in self._index

    def to_json(self) -> String:
        """Write the coordinates as upstream `UsedCoordinates.writeTo` does,
        with an indent of four spaces.

        Returns:
            The JSON text, without a final line feed.
        """
        var out = String('{\n    "typeToFieldsToArguments": {')
        for type_index in range(len(self._uses)):
            ref use = self._uses[type_index]
            out += "\n        " if type_index == 0 else ",\n        "
            out += _json_string(use.name) + ": {"
            for field_index in range(len(use.fields)):
                out += "\n            " if field_index == 0 else (
                    ",\n            "
                )
                out += _json_string(use.fields[field_index]) + ": ["
                ref arguments = use.arguments[field_index]
                # `put_argument` records a field with its first argument.
                for argument_index in range(
                    len(arguments)
                ):  # pragma: no branch
                    out += "\n                " if argument_index == 0 else (
                        ",\n                "
                    )
                    out += _json_string(arguments[argument_index])
                out += "\n            ]"
            if len(use.fields) > 0:
                out += "\n        "
            out += "}"
        if len(self._uses) > 0:
            out += "\n    "
        out += "}\n}"
        return out^


def _json_string(text: StringSlice) -> String:
    """Quote text as a JSON string."""
    var bytes = List[UInt8]()
    write_string(bytes, text.as_bytes())
    return String(unsafe_from_utf8=bytes)


struct IrOperations(Movable):
    """Everything that the generator needs, as upstream `IrOperations`."""

    var operations: List[IrOperation]
    """The operations, in source order."""
    var fragments: List[IrFragment]
    """The fragments, in source order."""
    var models: List[IrModel]
    """Every model; operations and fragments name theirs by index."""
    var conditions: Conditions
    """Every condition; properties name theirs by index."""
    var used_coordinates: UsedCoordinates
    """The used schema coordinates, for the schema types to generate."""

    def __init__(out self):
        """Start with nothing."""
        self.operations = List[IrOperation]()
        self.fragments = List[IrFragment]()
        self.models = List[IrModel]()
        self.conditions = Conditions()
        self.used_coordinates = UsedCoordinates()
