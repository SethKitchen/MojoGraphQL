# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Build an executable subgraph schema, as `buildSubgraphSchema`.

Port of `@apollo/subgraph` 2.14.4 `src/buildSubgraphSchema.ts` and the
`modulesFromSDL` and `addResolversToSchema` of
`src/schema-helper/buildSchemaFromSDL.ts` (MIT). The subgraph itself comes
from `gql_subgraph.subgraph.build_subgraph`, which implements the
`buildSubgraph` of `@apollo/federation-internals` from the public
specifications.

`build_subgraph_schema` builds the model, prints `_service.sdl`, checks the
schema, and builds the executable `gql_schema` schema. The resolvers are
those of `Query._service`, `Query._entities` and `_Entity`, then those of
each module, so a module can replace them.

```mojo
var subgraph = build_subgraph_schema(parse(sdl))
var args = ExecutionArgs()
var result = subgraph.execute(parse("{ _service { sdl } }"), args)
```

**Differences from upstream.**

- A resolver map is a `SubgraphResolvers`: field resolvers, `subscribe`
  functions, `__resolveType`, `__isTypeOf` and `__resolveReference`. A
  `GraphQLScalarType` and the internal values of an enum cannot be given;
  `gql_execution` has no such things.
- A `subscribe` function returns a `gql_stream` event stream, made with
  `Values.add_stream`, not an async iterator. `SubgraphSchema.subscribe`
  runs the subscription, as graphql-js `subscribe` runs the schema of
  upstream.
- `SubgraphSchema.execute_incrementally` runs `@defer` and `@stream`, as
  graphql-js 17 `experimentalExecuteIncrementally` runs the schema of
  upstream. `@apollo/subgraph` adds nothing for them.
- The result is a `SubgraphSchema`: the `gql_schema` schema with its
  resolvers and its SDL. Execute it with `SubgraphSchema.execute`, which
  runs with the resolvers of the subgraph, not with `args.resolvers`.
  Another executor, such as `gql_server`, runs `schema` with
  `resolvers.resolvers` when it calls `SubgraphSchema.attach` on the arena
  of each operation.
- An error has no source excerpt; a schema error has the message of
  upstream, with `[<unnamed>] ` before each graphql-js validation message.
- `buildFederatedSchema`, the deprecated name, is not ported.
"""

from std.memory import ArcPointer

from gql_execution.incremental import (
    ExperimentalIncrementalExecutionResults,
    experimental_execute_incrementally,
)
from gql_execution.subscribe import Subscription, subscribe
from gql_execution.execute import (
    ExecutionArgs,
    ExecutionResult,
    FieldResolver,
    IsTypeOf,
    ResolveInfo,
    Resolvers,
    TypeResolver,
    execute_with_resolvers,
)
from gql_execution.value import ValueKind, Values
from gql_language.ast import Document
from gql_language.error import GraphQLError
from gql_schema.build import BuildOptions, build_schema
from gql_schema.definition import Schema
from gql_schema.sdl_validation import (
    SDLRule,
    specified_sdl_rules,
    validate_sdl_with_rules,
)
from gql_schema.validate import validate_schema
from gql_subgraph.entities import (
    ReferenceResolver,
    ReferenceResolvers,
    entities_resolver,
)
from gql_subgraph.model import SubgraphModel
from gql_subgraph.printer import PrintMode, print_model
from gql_subgraph.subgraph import INVALID_SCHEMA, build_subgraph

comptime CONTEXT_TAG = -1000
"""The tag of the handle that `SubgraphSchema.execute` adds to the arena,
whose id is the address of the subgraph schema. The federation resolvers
find the subgraph through it."""


struct SubgraphResolvers(Copyable, Movable):
    """The resolvers of a schema module: graphql-js `GraphQLResolverMap`
    with the federation `__resolveReference`."""

    var resolvers: Resolvers
    """The field resolvers, `__resolveType` and `__isTypeOf`."""
    var references: ReferenceResolvers
    """The `__resolveReference` functions."""

    def __init__(out self):
        """Start with no resolvers."""
        self.resolvers = Resolvers()
        self.references = ReferenceResolvers()

    def field(
        mut self, type_name: String, field_name: String, resolve: FieldResolver
    ):
        """Set the resolver of a field.

        Args:
            type_name: The object type.
            field_name: The field.
            resolve: The resolver.
        """
        self.resolvers.field(type_name, field_name, resolve)

    def subscribe(
        mut self,
        type_name: String,
        field_name: String,
        subscribe: FieldResolver,
    ):
        """Set the `subscribe` function of a subscription field, as the
        `subscribe` key of a field config.

        It returns the source event stream: a value that
        `Values.add_stream` made, such as a `gql_stream` `PubSub` iterator.

        Args:
            type_name: The subscription type, such as `Subscription`.
            field_name: The field.
            subscribe: The function.
        """
        self.resolvers.subscribe(type_name, field_name, subscribe)

    def resolve_type(mut self, type_name: String, resolve: TypeResolver):
        """Set `__resolveType` of an interface or union type.

        Args:
            type_name: The abstract type.
            resolve: The type resolver.
        """
        self.resolvers.type_resolver(type_name, resolve)

    def is_type_of(mut self, type_name: String, check: IsTypeOf):
        """Set `__isTypeOf` of an object type.

        Args:
            type_name: The object type.
            check: The function.
        """
        self.resolvers.is_type_of(type_name, check)

    def resolve_reference(
        mut self, type_name: String, resolve: ReferenceResolver
    ):
        """Set `__resolveReference` of an entity type.

        Args:
            type_name: The object or interface type.
            resolve: The function.
        """
        self.references.add(type_name, resolve)

    def add(mut self, other: SubgraphResolvers):
        """Add the resolvers of another map after these, so they win.

        Args:
            other: The other map.
        """
        ref theirs = other.resolvers
        var index = 0
        while index < len(theirs.field_functions):
            self.resolvers.field(
                theirs.field_types[index],
                theirs.field_names[index],
                theirs.field_functions[index],
            )
            index += 1
        index = 0
        while index < len(theirs.subscribe_functions):
            self.resolvers.subscribe(
                theirs.subscribe_types[index],
                theirs.subscribe_names[index],
                theirs.subscribe_functions[index],
            )
            index += 1
        index = 0
        while index < len(theirs.type_functions):
            self.resolvers.type_resolver(
                theirs.type_names[index], theirs.type_functions[index]
            )
            index += 1
        index = 0
        while index < len(theirs.object_functions):
            self.resolvers.is_type_of(
                theirs.object_names[index], theirs.object_functions[index]
            )
            index += 1
        index = 0
        while index < len(other.references.functions):
            self.references.add(
                other.references.type_names[index],
                other.references.functions[index],
            )
            index += 1


struct SchemaModule(Copyable, Movable):
    """A module: SDL and its resolvers, as `GraphQLSchemaModule`."""

    var type_defs: Document
    """The SDL: `typeDefs`."""
    var resolvers: SubgraphResolvers
    """The resolvers: `resolvers`."""

    def __init__(out self, var type_defs: Document):
        """Make a module with no resolvers.

        Args:
            type_defs: The SDL.
        """
        self.type_defs = type_defs^
        self.resolvers = SubgraphResolvers()

    def __init__(
        out self, var type_defs: Document, var resolvers: SubgraphResolvers
    ):
        """Make a module.

        Args:
            type_defs: The SDL.
            resolvers: The resolvers.
        """
        self.type_defs = type_defs^
        self.resolvers = resolvers^


struct SubgraphSchema(Movable):
    """An executable subgraph schema: what `buildSubgraphSchema` returns."""

    var schema: Schema
    """The executable schema, with the federation types and fields."""
    var resolvers: SubgraphResolvers
    """The resolvers: the federation ones, then those of each module."""
    var sdl: String
    """The `_service.sdl` text."""
    var model: SubgraphModel
    """The subgraph, as parts of the SDL."""
    var order: List[Int]
    """The types of `model`, in the order of the types of `schema`."""
    var shared_schema: Optional[ArcPointer[Schema]]
    """A copy of `schema` that response streams share; made by the first
    `subscribe` or `execute_incrementally`."""
    var shared_resolvers: Optional[ArcPointer[Resolvers]]
    """A copy of the resolvers that response streams share."""

    def __init__(
        out self,
        var schema: Schema,
        var resolvers: SubgraphResolvers,
        var sdl: String,
        var model: SubgraphModel,
        var order: List[Int],
    ):
        """Gather the parts of a subgraph schema.

        Args:
            schema: The executable schema.
            resolvers: The resolvers.
            sdl: The `_service.sdl` text.
            model: The subgraph.
            order: The model types in schema order.
        """
        self.schema = schema^
        self.resolvers = resolvers^
        self.sdl = sdl^
        self.model = model^
        self.order = order^
        self.shared_schema = None
        self.shared_resolvers = None

    def attach(self, mut values: Values):
        """Add the handle that the federation resolvers find this subgraph
        through to the arena of an operation.

        `execute` calls it. Call it yourself when another executor runs
        the operation with `schema` and `resolvers.resolvers`, such as a
        `gql_server` plugin in `execution_did_start`. The subgraph must
        not move while the operation runs.

        Args:
            values: The arena that the operation runs in.
        """
        _ = values.add_handle(CONTEXT_TAG, Int(Pointer(to=self)))

    def execute(
        self, document: Document, mut args: ExecutionArgs
    ) raises -> ExecutionResult:
        """Execute an operation against the subgraph, as graphql-js
        `executeSync` with the resolvers of the subgraph.

        Args:
            document: The operation; it is not validated.
            args: The root value, the context, the variables and the
                options. Its resolvers are not read: the operation runs
                with those of the subgraph.

        Returns:
            The result.

        Raises:
            Error: As `gql_execution.execute.execute` raises.
        """
        self.attach(args.values)
        args.assume_valid_schema = True
        return execute_with_resolvers(
            self.schema, document, self.resolvers.resolvers, args
        )

    def _shared(mut self):
        """Make the copies of the schema and the resolvers that streams
        share, once."""
        if not self.shared_schema:
            self.shared_schema = ArcPointer(self.schema.copy())
            self.shared_resolvers = ArcPointer(self.resolvers.resolvers.copy())

    def subscribe(
        mut self, document: ArcPointer[Document], var args: ExecutionArgs
    ) raises -> Subscription:
        """Subscribe to an operation against the subgraph, as graphql-js
        `subscribe` with the schema of `buildSubgraphSchema`.

        Each event of the source stream of the root field executes with
        the resolvers of the subgraph.

        Args:
            document: The operation; it is not validated.
            args: The inputs; the response stream keeps them. Its resolvers
                are not read.

        Returns:
            The response stream, or a result with the errors.

        Raises:
            Error: As `gql_execution.subscribe.subscribe` raises.
        """
        self._shared()
        self.attach(args.values)
        args.resolvers = self.shared_resolvers.value()[].copy()
        return subscribe(self.shared_schema.value(), document, args^)

    def execute_incrementally(
        mut self, document: ArcPointer[Document], var args: ExecutionArgs
    ) raises -> ExperimentalIncrementalExecutionResults:
        """Execute an operation with `@defer` and `@stream` against the
        subgraph, as graphql-js 17 `experimentalExecuteIncrementally`.

        The schema must define the `@defer` and `@stream` directives that
        the operation uses, as the validation of a server requires.

        Args:
            document: The operation; it is not validated.
            args: The inputs; the subsequent results keep them. Its
                resolvers are not read.

        Returns:
            A single result, or the initial result and the stream of the
            subsequent results. The subgraph must not move while the
            stream runs.

        Raises:
            Error: As `experimental_execute_incrementally` raises.
        """
        self._shared()
        self.attach(args.values)
        return experimental_execute_incrementally(
            self.shared_schema.value(),
            document,
            self.shared_resolvers.value(),
            args^,
        )


def _context(
    values: Values,
) raises -> Pointer[SubgraphSchema, ImmUntrackedOrigin]:
    """Find the subgraph schema that executes, from its handle."""
    var index = len(values.nodes) - 1
    while index >= 0:
        if (
            values.kind(index) == ValueKind.HANDLE
            and values.tag(index) == CONTEXT_TAG
        ):
            return Pointer[SubgraphSchema, ImmUntrackedOrigin](
                unsafe_from_address=values.id(index)
            )
        index -= 1
    raise Error("A subgraph field must execute with SubgraphSchema.execute")


def _resolve_service(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """Resolve `Query._service` to `{ sdl }`."""
    var context = _context(values)
    var service = values.add_object()
    values.add_member(service, "sdl", values.add_string(context[].sdl))
    return service


def _resolve_entities(
    mut values: Values, source: Int, args: Int, info: ResolveInfo
) raises -> Int:
    """Resolve `Query._entities` with `entities_resolver`."""
    var context = _context(values)
    return entities_resolver(
        context[].schema,
        context[].resolvers.resolvers,
        context[].resolvers.references,
        values,
        args,
        info,
    )


def _resolve_entity_type(
    mut values: Values, value: Int, info: ResolveInfo, abstract_type: Int
) raises -> Int:
    """Resolve the type of an `_Entity` to its `__typename`."""
    return values.get(value, "__typename")


def _schema_errors(model: SubgraphModel) raises -> Schema:
    """Check the subgraph as a GraphQL schema and build it."""
    var rules = List[SDLRule]()
    var all = specified_sdl_rules()
    var index = 0
    while index < len(all):
        var name = String(all[index])
        if (
            name != "KnownTypeNamesRule"
            and name != "PossibleTypeExtensionsRule"
        ):
            rules.append(all[index])
        index += 1
    var errors = validate_sdl_with_rules(model.docs, rules^)
    var schema = Schema()
    if len(errors) == 0:
        var options = BuildOptions()
        options.assume_valid_sdl = True
        schema = build_schema(print_model(model, PrintMode.MERGED), options)
        errors = validate_schema(schema)
    if len(errors) == 1:
        raise Error("[<unnamed>] " + errors[0].message)
    if len(errors) > 1:
        var message = String(INVALID_SCHEMA)
        index = 0
        while index < len(errors):
            message += ("\n\n" if index > 0 else "") + "[<unnamed>] "
            message += errors[index].message
            index += 1
        raise Error(message)
    return schema^


def build_subgraph_schema(
    var modules: List[SchemaModule],
) raises -> SubgraphSchema:
    """Build an executable subgraph schema from modules, as
    `buildSubgraphSchema(modules)`.

    Args:
        modules: The modules; their SDL is joined, and their resolvers are
            added in order.

    Returns:
        The subgraph schema.

    Raises:
        Error: The errors of `build_subgraph`, or the graphql-js
            validation errors of the schema, each after `[<unnamed>] `:
            one error alone, or several after `INVALID_SCHEMA`.
    """
    var documents = List[Document](capacity=len(modules))
    var index = 0
    while index < len(modules):
        documents.append(modules[index].type_defs.copy())
        index += 1
    var model = build_subgraph(documents)
    var sdl = print_model(model, PrintMode.SDL)
    var schema = _schema_errors(model)
    var order = List[Int]()
    index = 0
    while index < len(schema.types):
        if not schema.types[index].is_builtin:
            order.append(model.type_index(schema.types[index].name))
        index += 1
    var resolvers = SubgraphResolvers()
    var query = model.roots[0]
    resolvers.field(query, "_service", _resolve_service)
    if len(model.entities) > 0:
        resolvers.field(query, "_entities", _resolve_entities)
        resolvers.resolve_type("_Entity", _resolve_entity_type)
    index = 0
    while index < len(modules):
        resolvers.add(modules[index].resolvers)
        index += 1
    return SubgraphSchema(schema^, resolvers^, sdl^, model^, order^)


def build_subgraph_schema(var document: Document) raises -> SubgraphSchema:
    """Build an executable subgraph schema from SDL, as
    `buildSubgraphSchema(typeDefs)`.

    Args:
        document: The SDL.

    Returns:
        The subgraph schema, with no resolvers of its own.

    Raises:
        Error: As `build_subgraph_schema(modules)` raises.
    """
    var modules = List[SchemaModule]()
    modules.append(SchemaModule(document^))
    return build_subgraph_schema(modules^)


def build_subgraph_schema(
    var documents: List[Document], var resolvers: SubgraphResolvers
) raises -> SubgraphSchema:
    """Build an executable subgraph schema from the legacy module
    `{ typeDefs, resolvers }`: the resolvers go with the first document.

    Args:
        documents: The SDL documents.
        resolvers: The resolvers.

    Returns:
        The subgraph schema.

    Raises:
        Error: As `build_subgraph_schema(modules)` raises.
    """
    var modules = List[SchemaModule]()
    var index = 0
    while index < len(documents):
        modules.append(SchemaModule(documents[index].copy()))
        index += 1
    if len(modules) > 0:
        modules[0].resolvers = resolvers^
    return build_subgraph_schema(modules^)
