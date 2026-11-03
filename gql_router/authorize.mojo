# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Apply `@authenticated`, `@requiresScopes` and `@policy` to a request.

Port of `apply_authorization_to_operation` in Hive Router `1a29df9`
`bin/router/src/pipeline/authorization/mod.rs`, on the normalized
operation of this router.

`AuthRules.from_supergraph` reads the directives of each type and field of
the supergraph. For one request, `denied_elements` names the types and
fields that its `UserAuth` cannot see, with `authorization_allows`. A field
is denied when its parent type, the field, or its output type is denied.

`filter_operation` copies the normalized operation without the denied
fields, so that no subgraph resolves them, and returns one error for each:
`Unauthorized field or type` with the code `UNAUTHORIZED_FIELD_OR_TYPE` and
the `affectedPath` of its response keys. A selection set that loses every
field keeps `__typename`, so the subgraph operation stays valid. The
projection plan of the whole operation then writes `null` for each denied
field, and the `null` bubbles as for any non-null field.

**Differences from upstream.** This router has no JWT plugin. The caller
gives the identity, the scopes and the policies of a request as a
`UserAuth`, and an anonymous request is the default. `@authenticated` and
`@requiresScopes` apply by default: a router with no identity source
treats each request as anonymous, and does not serve those fields. Upstream
applies them only when JWT authentication is configured. Only filter mode
is ported: a denied field is `null` with an error, and the request is not
rejected. An error has no `path`, only `affectedPath`.
"""

from std.collections import Dict, Set

from gql_language.ast import NO_NODE, Document, Kind, Role
from gql_router.ast import NONE, ItemKind
from gql_router.authorization import AuthRule, UserAuth, authorization_allows
from gql_router.graphql_error import GraphQLError, graphql_error
from gql_router.operation import OperationDefinition
from gql_router.schema_metadata import SchemaMetadata
from gql_router.store import Store

comptime UNAUTHORIZED_MESSAGE = "Unauthorized field or type"
"""The message of the error of a denied field."""
comptime UNAUTHORIZED_CODE = "UNAUTHORIZED_FIELD_OR_TYPE"
"""The code of the error of a denied field."""


def anonymous() -> UserAuth:
    """Return the identity of a request that has none.

    Returns:
        Not authenticated, with no scopes and no policies.
    """
    return UserAuth(False, List[String](), List[String]())


def _groups(document: Document, value: Int) -> List[List[String]]:
    """Read a `[[String!]!]!` argument: an OR of AND groups. An outer item
    that is one string is a group of that string, as input coercion makes
    it."""
    var out = List[List[String]]()
    if value == NO_NODE or document.kind(value) != Kind.LIST:
        return out^
    for item in document.children(value, Role.LIST_ITEM):
        var group = List[String]()
        if document.kind(item) == Kind.LIST:
            for name in document.children(item, Role.LIST_ITEM):
                if document.kind(name) == Kind.STRING:
                    group.append(document.string_value(name))
        elif document.kind(item) == Kind.STRING:
            group.append(document.string_value(item))
        out.append(group^)
    return out^


def _argument(document: Document, directive: Int, name: StringSlice) -> Int:
    """Return the value of a directive argument, or `NO_NODE`."""
    for argument in document.children(directive, Role.ARGUMENT):
        if document.name(argument) == name:
            return document.child(argument, Role.VALUE)
    return NO_NODE


def _rule_of(document: Document, node: Int) -> Optional[AuthRule]:
    """Return the authorization directives of a definition, or none."""
    var rule = AuthRule(
        False, False, List[List[String]](), False, List[List[String]]()
    )
    var found = False
    for directive in document.children(node, Role.DIRECTIVE):
        var name = document.name(directive)
        if name == "authenticated":
            rule.authenticated = True
            found = True
        elif name == "requiresScopes":
            rule.has_scopes = True
            rule.scope_groups.extend(
                _groups(document, _argument(document, directive, "scopes"))
            )
            found = True
        elif name == "policy":
            rule.has_policies = True
            rule.policy_groups.extend(
                _groups(document, _argument(document, directive, "policies"))
            )
            found = True
    if not found:
        return None
    return rule^


def _merge(mut rules: Dict[String, AuthRule], key: String, var rule: AuthRule):
    """Add a rule, or join it to the rule of a type and its extension."""
    var existing = rules.get(key)
    if not existing:
        rules[key] = rule^
        return
    var joined = existing.value().copy()
    joined.authenticated = joined.authenticated or rule.authenticated
    if rule.has_scopes:
        joined.has_scopes = True
        joined.scope_groups.extend(rule.scope_groups.copy())
    if rule.has_policies:
        joined.has_policies = True
        joined.policy_groups.extend(rule.policy_groups.copy())
    rules[key] = joined^


struct AuthRules(Copyable, Movable):
    """The authorization directives of a supergraph."""

    var types: Dict[String, AuthRule]
    """The rule of each type that has one, by type name."""
    var fields: Dict[String, AuthRule]
    """The rule of each field that has one, by `Type.field`."""

    def __init__(out self):
        """Make an empty set of rules."""
        self.types = Dict[String, AuthRule]()
        self.fields = Dict[String, AuthRule]()

    def is_empty(self) -> Bool:
        """Return True when no type and no field has a rule.

        Returns:
            Whether the supergraph has no authorization directive.
        """
        return len(self.types) == 0 and len(self.fields) == 0

    @staticmethod
    def from_supergraph(document: Document) -> AuthRules:
        """Read the rules of each type and field of a supergraph.

        Args:
            document: The supergraph document.

        Returns:
            The rules.
        """
        var out = AuthRules()
        for definition in document.definitions():
            var kind = document.kind(definition)
            if not (kind.is_type_definition() or kind.is_type_extension()):
                continue
            var type_name = String(document.name(definition))
            var own = _rule_of(document, definition)
            if own:
                _merge(out.types, type_name, own.value().copy())
            for field in document.children(definition, Role.FIELD):
                var rule = _rule_of(document, field)
                if rule:
                    _merge(
                        out.fields,
                        type_name + "." + String(document.name(field)),
                        rule.value().copy(),
                    )
        return out^


struct DeniedElements(Copyable, Movable):
    """The types and fields that one request cannot see."""

    var types: Set[String]
    """The denied type names."""
    var fields: Set[String]
    """The denied fields, as `Type.field`."""
    var signature: String
    """The denied names, sorted and joined: the part of the cache key that
    depends on the request. Empty when nothing is denied."""

    def __init__(out self):
        """Deny nothing."""
        self.types = Set[String]()
        self.fields = Set[String]()
        self.signature = String()

    def is_empty(self) -> Bool:
        """Return True when the request can see everything.

        Returns:
            Whether no type and no field is denied.
        """
        return self.signature.byte_length() == 0

    def field_denied(
        self, parent: StringSlice, field: StringSlice, output: StringSlice
    ) -> Bool:
        """Return True when a field is denied.

        Args:
            parent: The parent type.
            field: The field name.
            output: The named output type of the field.

        Returns:
            Whether the parent type, the field or the output type is denied.
        """
        if self.is_empty():
            return False
        return (
            String(parent) in self.types
            or String(parent) + "." + String(field) in self.fields
            or String(output) in self.types
        )


def denied_elements(
    rules: AuthRules, user: UserAuth, enforce_jwt: Bool
) -> DeniedElements:
    """Name the types and fields that a request cannot see.

    Args:
        rules: The rules of the supergraph.
        user: The identity, scopes and policies of the request.
        enforce_jwt: Whether `@authenticated` and `@requiresScopes` apply.

    Returns:
        The denied elements.
    """
    var out = DeniedElements()
    var names = List[String]()
    for entry in rules.types.items():
        if not authorization_allows(entry.value, user, enforce_jwt):
            out.types.add(entry.key)
            names.append("type " + entry.key)
    for entry in rules.fields.items():
        if not authorization_allows(entry.value, user, enforce_jwt):
            out.fields.add(entry.key)
            names.append(entry.key)
    sort(names)
    out.signature = String(",").join(names)
    return out^


def _unauthorized(path: String) -> GraphQLError:
    """Return the error of a denied field at a path of response keys."""
    var error = graphql_error(String(UNAUTHORIZED_MESSAGE))
    error.code = String(UNAUTHORIZED_CODE)
    error.affected_path = path
    return error^


def _filter_set(
    mut store: Store,
    metadata: SchemaMetadata,
    set: Int,
    parent_type: String,
    prefix: String,
    denied: DeniedElements,
    mut errors: List[GraphQLError],
):
    """Remove the denied fields under a selection set, in place."""
    var kept = List[Int]()
    for child in store.children(set):
        var item = store.items[child]
        if item.kind == ItemKind.FIELD:
            var name = String(store.name(item.name))
            var info = metadata.field_types.get(parent_type + "." + name)
            if not info:
                # `__typename` and the introspection fields have no rule.
                kept.append(child)
                continue
            var output = info.value().output_type_name
            var key = String(store.name(store.response_key(child)))
            if denied.field_denied(parent_type, name, output):
                errors.append(_unauthorized(prefix + key))
                continue
            if item.first != NONE:
                _filter_set(
                    store,
                    metadata,
                    child,
                    output,
                    prefix + key + ".",
                    denied,
                    errors,
                )
            kept.append(child)
        else:
            # A normalized operation has only inline fragments.
            var condition = String(store.name(item.name))
            _filter_set(
                store, metadata, child, condition, prefix, denied, errors
            )
            if not store.is_empty(child):
                kept.append(child)
    if len(kept) == 0 and prefix.byte_length() > 0:
        # An empty selection set under a field is not valid: ask for
        # `__typename`, which the projection of the client operation does
        # not write. An empty root set plans no fetch.
        kept.append(
            store.add_item(
                ItemKind.FIELD, name=store.sym("__typename"), omit=True
            )
        )
    store.set_children(set, kept)


def filter_operation(
    mut store: Store,
    metadata: SchemaMetadata,
    operation: OperationDefinition,
    root_type: String,
    denied: DeniedElements,
) -> Tuple[OperationDefinition, List[GraphQLError]]:
    """Copy an operation without the fields that a request cannot see.

    Args:
        store: The store with the selections; the copy goes into it.
        metadata: The metadata of the consumer schema.
        operation: The normalized operation. It does not change.
        root_type: The root type of the operation.
        denied: The denied elements of the request.

    Returns:
        The filtered copy, and one error for each removed field.
    """
    var errors = List[GraphQLError]()
    var copy = operation.copy()
    copy.selection_set = store.copy_set(operation.selection_set)
    _filter_set(
        store,
        metadata,
        copy.selection_set,
        root_type,
        String(),
        denied,
        errors,
    )
    return (copy^, errors^)
