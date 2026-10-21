# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The cache writes of a client: each payload of an incremental request
and each result of a subscription.

Port of the parts of Apollo Client 4.3.3 `src/core/QueryInfo.ts` that the
cache needs: `markQueryResult`, `markSubscriptionResult` and
`shouldWriteResult`, and of the result mapping of
`QueryManager.startGraphQLSubscription` in `src/core/QueryManager.ts`.

`mark_result` takes one payload of an incremental request. It reads the
query from the cache with partial data, gives the read to the handler as
`cacheData`, writes the merged result with the stream information, and
reads the query again. `mark_subscription_result` writes one result of a
subscription to `ROOT_SUBSCRIPTION` and reads it back.

Differences from upstream:

- `QueryManager`, `ObservableQuery`, watches, broadcasts, `fetchPolicy`
  and the network are not ported: Apollo Link has the network, and the
  cache has no watches. The caller gives `CacheWriteBehavior` and
  `ErrorPolicy`.
- The incremental reads of Apollo Client 4.3 are not ported:
  `cache.diff` does not prune the pending `@defer` boundaries
  (`deferInfo`, `prunePendingDeferFragments`) or cut the pending
  `@stream` arrays (`StreamArrayState.truncate`). A result whose
  deferred data is pending has the data state `STREAMING` and the data of
  the read with partial data.
- `CombinedGraphQLErrors` and the protocol errors are not error objects:
  `SubscribeResult.error` is the array of the GraphQL errors.
- Data masking (`maskOperation`, `@unmask`) is not ported. It changes
  what a client gives to a component, not what the cache stores.
"""

from gql_json.value import JsonDocument, JsonKind, NO_NODE
from gql_language.ast import Document, OperationType
from gql_language.ast import NO_NODE as NO_AST_NODE
from gql_client.cache import InMemoryCache
from gql_client.helpers import get_operation_definition
from gql_client.incremental import IncrementalRequestType


@fieldwise_init
struct ErrorPolicy(Equatable, ImplicitlyCopyable, Writable):
    """The `errorPolicy` of an operation."""

    var value: UInt8
    """The policy's index; see `is_valid`."""

    comptime NONE = ErrorPolicy(0)
    """`"none"`: a result with errors has no data."""
    comptime IGNORE = ErrorPolicy(1)
    """`"ignore"`: errors are dropped."""
    comptime ALL = ErrorPolicy(2)
    """`"all"`: data and errors are both kept."""

    def is_valid(self) -> Bool:
        """Return True for one of the three policies.

        Returns:
            Whether the index names a policy.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the policy's index.

        Args:
            writer: The destination.
        """
        writer.write("ErrorPolicy(", self.value, ")")


@fieldwise_init
struct CacheWriteBehavior(Equatable, ImplicitlyCopyable, Writable):
    """How a result goes to the cache: upstream `CacheWriteBehavior`."""

    var value: UInt8
    """The behavior's index; see `is_valid`."""

    comptime FORBID = CacheWriteBehavior(0)
    """No write: the `no-cache` fetch policy."""
    comptime OVERWRITE = CacheWriteBehavior(1)
    """A write with `overwrite`: a refetch."""
    comptime MERGE = CacheWriteBehavior(2)
    """A write that merges with the existing data."""

    def is_valid(self) -> Bool:
        """Return True for one of the three behaviors.

        Returns:
            Whether the index names a behavior.
        """
        return self.value <= 2

    def write_to(self, mut writer: Some[Writer]):
        """Write the behavior's index.

        Args:
            writer: The destination.
        """
        writer.write("CacheWriteBehavior(", self.value, ")")


@fieldwise_init
struct DataState(Equatable, ImplicitlyCopyable, Writable):
    """The `dataState` of a result."""

    var value: UInt8
    """The state's index; see `is_valid`."""

    comptime EMPTY = DataState(0)
    """`"empty"`: no data."""
    comptime PARTIAL = DataState(1)
    """`"partial"`: some fields are missing."""
    comptime STREAMING = DataState(2)
    """`"streaming"`: deferred data is to come."""
    comptime COMPLETE = DataState(3)
    """`"complete"`: the data is complete."""

    def is_valid(self) -> Bool:
        """Return True for one of the four states.

        Returns:
            Whether the index names a state.
        """
        return self.value <= 3

    def write_to(self, mut writer: Some[Writer]):
        """Write the state's index.

        Args:
            writer: The destination.
        """
        writer.write("DataState(", self.value, ")")


def has_errors(result: JsonDocument) -> Bool:
    """Tell if a result has errors: upstream `graphQLResultHasError`.

    Args:
        result: The result.

    Returns:
        True when `errors` is an array with an item.
    """
    var errors = result.find(result.root, "errors")
    return (
        errors != NO_NODE
        and result.kind(errors) == JsonKind.ARRAY
        and result.length(errors) > 0
    )


def should_write_result(
    result: JsonDocument, error_policy: ErrorPolicy
) -> Bool:
    """Tell if a result goes to the cache: upstream `shouldWriteResult`.

    Args:
        result: The result.
        error_policy: The error policy.

    Returns:
        True for a result without errors, or with `IGNORE` or `ALL` for a
        result that has data.
    """
    if not has_errors(result):
        return True
    if error_policy == ErrorPolicy.NONE:
        return False
    var data = result.find(result.root, "data")
    return data != NO_NODE and result.kind(data) != JsonKind.NULL


def as_query(document: Document) raises -> Document:
    """Return a copy of a document whose operation is a query, as the
    `asQuery` of upstream `getDocumentInfo`.

    Args:
        document: The document.

    Returns:
        The copy.

    Raises:
        Error: For a document with more than one operation.
    """
    var out = document.copy()
    var operation = get_operation_definition(out)
    if operation != NO_AST_NODE:
        out.nodes[operation].flags &= ~UInt8(3)
    return out^


def member_document(result: JsonDocument, key: StringSlice) -> JsonDocument:
    """Return a copy of one member of a result as a document.

    Args:
        result: The result.
        key: The member, such as `data` or `extensions`.

    Returns:
        The document; its root is `NO_NODE` when the member is missing.
    """
    var out = JsonDocument()
    var found = result.find(result.root, key)
    if found != NO_NODE:
        out.root = out.add_copy(result, found)
    return out^


def with_data(
    result: JsonDocument, data: Optional[JsonDocument]
) -> JsonDocument:
    """Return a copy of a result whose `data` is another value, as
    `result.data = data`.

    Args:
        result: The result object.
        data: The new data, or None for `null`.

    Returns:
        The new result; `data` keeps its position, or comes last.
    """
    var out = JsonDocument()
    out.root = out.add_object()
    var replaced = False
    var member = result.first(result.root)
    while member != NO_NODE:
        var key = result.key(member)
        if key == "data":
            out.add_member(out.root, key, _data_node(out, data))
            replaced = True
        else:
            out.add_member(out.root, key, out.add_copy(result, member))
        member = result.next(member)
    if not replaced:
        out.add_member(out.root, "data", _data_node(out, data))
    return out^


def _data_node(mut out: JsonDocument, data: Optional[JsonDocument]) -> Int:
    """Copy new data into a document: `null` for None."""
    if data:
        ref found = data.value()
        if found.root != NO_NODE:
            return out.add_copy(found, found.root)
    return out.add_null()


def mark_subscription_result(
    mut cache: InMemoryCache,
    document: Document,
    result: JsonDocument,
    variables: JsonDocument = JsonDocument(),
    error_policy: ErrorPolicy = ErrorPolicy.NONE,
    cache_write_behavior: CacheWriteBehavior = CacheWriteBehavior.MERGE,
) raises -> JsonDocument:
    """Write one result of a subscription to the cache, as upstream
    `QueryInfo.markSubscriptionResult`.

    The data goes to `ROOT_SUBSCRIPTION`. A complete read of the
    subscription, as a query, replaces the data of the result.

    Args:
        cache: The cache.
        document: The subscription.
        result: The result: `data`, `errors` and `extensions`.
        variables: The variables object, or an empty document.
        error_policy: The error policy.
        cache_write_behavior: `FORBID` for no write, else `MERGE`.

    Returns:
        The result, with the data of the cache when the read is complete.

    Raises:
        Error: For the errors of the write and of the read.
    """
    if cache_write_behavior == CacheWriteBehavior.FORBID:
        return result.copy()
    if not should_write_result(result, error_policy):
        return result.copy()
    _ = cache.write_query(
        document,
        member_document(result, "data"),
        variables,
        "ROOT_SUBSCRIPTION",
        False,
        member_document(result, "extensions"),
    )
    var diff = cache.diff(
        as_query(document), variables, "ROOT_SUBSCRIPTION", True
    )
    if diff.complete:
        return with_data(result, diff.result.copy())
    return result.copy()


struct SubscribeResult(Movable):
    """What a subscription gives for one result: upstream
    `ApolloClient.SubscribeResult`."""

    var data: Optional[JsonDocument]
    """The data, or None (upstream `undefined`)."""
    var error: Optional[JsonDocument]
    """The array of the GraphQL errors, or None."""
    var extensions: Optional[JsonDocument]
    """The extensions, or None when there are none."""

    def __init__(
        out self,
        var data: Optional[JsonDocument],
        var error: Optional[JsonDocument],
        var extensions: Optional[JsonDocument],
    ):
        """Make a result.

        Args:
            data: The data, or None.
            error: The errors, or None.
            extensions: The extensions, or None.
        """
        self.data = data^
        self.error = error^
        self.extensions = extensions^


def subscribe_result(
    raw: JsonDocument, error_policy: ErrorPolicy = ErrorPolicy.NONE
) -> Optional[SubscribeResult]:
    """Map one raw result of a subscription, as the `map` and `filter`
    steps of upstream `QueryManager.startGraphQLSubscription`.

    Args:
        raw: The result, after `mark_subscription_result`.
        error_policy: The error policy.

    Returns:
        The result, or None when it has no data and no error.
    """
    var data = Optional[JsonDocument](None)
    var found = raw.find(raw.root, "data")
    if found != NO_NODE and raw.kind(found) != JsonKind.NULL:
        data = member_document(raw, "data")
    var error = Optional[JsonDocument](None)
    if has_errors(raw):
        error = member_document(raw, "errors")
    var extensions = Optional[JsonDocument](None)
    var ext = raw.find(raw.root, "extensions")
    if (
        ext != NO_NODE
        and raw.kind(ext) == JsonKind.OBJECT
        and raw.length(ext) > 0
    ):
        extensions = member_document(raw, "extensions")
    if error and error_policy == ErrorPolicy.NONE:
        data = None
    if error_policy == ErrorPolicy.IGNORE:
        error = None
    if not data and not error:
        return None
    return SubscribeResult(data^, error^, extensions^)


struct MarkQueryResult(Movable):
    """What `mark_result` gives: upstream `MarkQueryResult`."""

    var result: JsonDocument
    """The result: `data`, `errors` and `extensions`."""
    var data_state: DataState
    """The data state."""

    def __init__(out self, var result: JsonDocument, data_state: DataState):
        """Make a result.

        Args:
            result: The result.
            data_state: The data state.
        """
        self.result = result^
        self.data_state = data_state


def mark_result[
    R: IncrementalRequestType
](
    mut cache: InMemoryCache,
    mut request: R,
    query: Document,
    chunk: JsonDocument,
    variables: JsonDocument = JsonDocument(),
    error_policy: ErrorPolicy = ErrorPolicy.NONE,
    cache_write_behavior: CacheWriteBehavior = CacheWriteBehavior.MERGE,
    return_partial_data: Bool = False,
) raises -> MarkQueryResult:
    """Merge one payload and write the result to the cache, as upstream
    `QueryInfo.markQueryResult`.

    The request gets the read of the query with partial data as
    `cacheData`, so that a payload merges with what the cache has. After
    the write, a complete or streaming read replaces the data.

    Parameters:
        R: The type of the request: `IncrementalRequest` or
            `DeferRequest`.

    Args:
        cache: The cache.
        request: The incremental request of the query.
        query: The query, as the handler transforms it.
        chunk: The payload, or a result that is not incremental.
        variables: The variables object, or an empty document.
        error_policy: The error policy.
        cache_write_behavior: `FORBID`, `OVERWRITE` or `MERGE`.
        return_partial_data: Whether a partial read replaces the data.

    Returns:
        The result and its data state.

    Raises:
        Error: For the errors of the handler, the write and the read.
    """
    var skip = cache_write_behavior == CacheWriteBehavior.FORBID
    var cache_data = Optional[JsonDocument](None)
    if not skip:
        var partial = (
            error_policy != ErrorPolicy.NONE
            or not request.chunk_has_errors(chunk)
        )
        var diff = cache.diff(query, variables, "ROOT_QUERY", partial)
        cache_data = diff.result.copy()
    var handled = request.handle(cache_data, chunk)
    var result = request.to_json(handled)
    # The result of a request always has `data`.
    var data = result.find(result.root, "data")
    var state = DataState.COMPLETE
    if result.kind(data) == JsonKind.NULL:
        state = DataState.EMPTY
    if request.is_streaming(query):
        state = DataState.STREAMING
    if skip or not should_write_result(result, error_policy):
        return MarkQueryResult(result^, state)
    _ = cache.write_query(
        query,
        request.data_json(handled),
        variables,
        "ROOT_QUERY",
        cache_write_behavior == CacheWriteBehavior.OVERWRITE,
        member_document(result, "extensions"),
        request.current_stream_info(),
    )
    var diff = cache.diff(query, variables, "ROOT_QUERY", True)
    var read_state = DataState.PARTIAL
    if diff.complete:
        read_state = DataState.COMPLETE
    elif state == DataState.STREAMING:
        read_state = DataState.STREAMING
    if read_state != DataState.PARTIAL or return_partial_data:
        return MarkQueryResult(
            with_data(result, diff.result.copy()), read_state
        )
    return MarkQueryResult(result^, state)
