# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Choose the operation name sent to a subgraph.

Port of `OperationNameForwardConfig` and `OperationNameFactory` in Hive
Router `1a29df9` `bin/router/src/executor/execution/operation_name.rs`.

`All` forwards the client name to every subgraph. `Only` forwards it to
the named subgraphs. An empty `Only` set forwards nothing. The subgraph
name is not part of the generated name. The name is the client name, two
underscores, and the fetch step id.

**Differences from upstream.** There is no traffic-shaping config type.
`operation_forward` takes the resolved all-rule and the subgraph lists.
"""


@fieldwise_init
struct ForwardKind(Equatable, ImplicitlyCopyable, Movable):
    """Which subgraphs receive the client operation name."""

    var value: UInt8
    """The kind's index. See `is_valid`."""

    comptime NONE = ForwardKind(0)
    """Forward the name to no subgraph."""
    comptime ALL = ForwardKind(1)
    """Forward the name to every subgraph."""
    comptime ONLY = ForwardKind(2)
    """Forward the name to the listed subgraphs."""

    def is_valid(self) -> Bool:
        """Return True when the value names one of the three modes.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 2


@fieldwise_init
struct OperationForward(Copyable, Movable):
    """The subgraphs that receive the client operation name."""

    var kind: ForwardKind
    """`NONE`, `ALL`, or `ONLY`."""
    var subgraphs: List[String]
    """The subgraph names. Used when `kind` is `ONLY`."""


def forward_none() -> OperationForward:
    """Forward the operation name to no subgraph.

    Returns:
        A `NONE` rule.
    """
    return OperationForward(ForwardKind.NONE, List[String]())


def forward_all() -> OperationForward:
    """Forward the operation name to every subgraph.

    Returns:
        An `ALL` rule.
    """
    return OperationForward(ForwardKind.ALL, List[String]())


def forward_only(names: List[String]) -> OperationForward:
    """Forward the operation name to these subgraphs.

    Args:
        names: The subgraph names. Duplicates are kept once.

    Returns:
        An `ONLY` rule. An empty list is a `NONE` rule.
    """
    var kept = _unique(names)
    if len(kept) == 0:
        return forward_none()
    return OperationForward(ForwardKind.ONLY, kept^)


def forward_all_except(
    known: List[String], excluded: List[String]
) -> OperationForward:
    """Forward the operation name to every known subgraph except these.

    Args:
        known: The subgraph names the router knows.
        excluded: The subgraphs that do not receive the name.

    Returns:
        `ALL` when `excluded` is empty. Otherwise the known names that
        are not excluded.
    """
    if len(excluded) == 0:
        return forward_all()
    var kept = List[String]()
    for index in range(len(known)):
        if _listed(excluded, known[index]):
            continue
        if _listed(kept, known[index]):
            continue
        kept.append(String(known[index]))
    return forward_only(kept)


def operation_forward(
    all_on: Bool,
    known: List[String],
    enabled: List[String],
    disabled: List[String],
) -> OperationForward:
    """Build the forward rule from the all-rule and the subgraph lists.

    Args:
        all_on: True when every subgraph forwards the name by default.
        known: The subgraph names the router knows.
        enabled: Subgraphs that turn forwarding on. Used when `all_on` is false.
        disabled: Subgraphs that turn forwarding off. Used when `all_on` is true.

    Returns:
        The forward rule. A disabled name is ignored when `all_on` is false.
    """
    if all_on:
        return forward_all_except(known, disabled)
    return forward_only(enabled)


def should_forward(rule: OperationForward, subgraph: String) -> Bool:
    """Return True when this subgraph receives the client operation name.

    Args:
        rule: The forward rule.
        subgraph: The subgraph name.

    Returns:
        Whether the name is forwarded.
    """
    if rule.kind == ForwardKind.ALL:
        return True
    if rule.kind == ForwardKind.ONLY:
        return _listed(rule.subgraphs, subgraph)
    return False


def subgraph_operation_name(
    rule: OperationForward,
    has_client_name: Bool,
    client_name: String,
    subgraph: String,
    step_id: Int,
) -> String:
    """Return the operation name for one subgraph fetch.

    Args:
        rule: The forward rule.
        has_client_name: True when the client sent an operation name.
        client_name: That name. It is used raw.
        subgraph: The subgraph name. It selects the rule and is not copied
            into the result.
        step_id: The fetch step id.

    Returns:
        `name__id`. Empty when the name is not forwarded or the client sent
        no name.
    """
    if not should_forward(rule, subgraph):
        return String("")
    if not has_client_name:
        return String("")
    return client_name + "__" + String(step_id)


def _unique(names: List[String]) -> List[String]:
    """Copy names and drop later duplicates.

    Args:
        names: The subgraph names.

    Returns:
        The names, in first-seen order.
    """
    var kept = List[String]()
    for index in range(len(names)):
        if _listed(kept, names[index]):
            continue
        kept.append(String(names[index]))
    return kept^


def _listed(names: List[String], name: String) -> Bool:
    """Return True when a name is present.

    Args:
        names: The names.
        name: The candidate.

    Returns:
        Whether `name` is present.
    """
    for index in range(len(names)):
        if names[index] == name:
            return True
    return False
