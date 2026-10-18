# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Hive Router `1a29df9` `bin/router/src/query_planner/planner/query_plan/optimize.rs` test snapshots (MIT)."""


def optimize_parallel_node_batches_compatible_fetches_and_keeps_order() -> (
    String
):
    """Return the upstream snapshot of `optimize_parallel_node_batches_compatible_fetches_and_keeps_order`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  Parallel {
    Fetch(service: "products") {
      {
        products {
          upc
        }
      }
    },
    BatchFetch(service: "inventory") {
      {
        _e0 {
          paths: [
            "products.@"
          ]
          {
            ... on Product {
              upc
            }
          }
        }
      }
      {
        _e0: _entities(representations: $__batch_reps_0) {
          ... on Product {
            shippingEstimate
          }
        }
      }
    },
  },
},
"""
    )


def optimize_parallel_node_does_not_batch_incompatible_variables() -> String:
    """Return the upstream snapshot of `optimize_parallel_node_does_not_batch_incompatible_variables`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  Parallel {
    Flatten(path: "products.@") {
      Fetch(service: "inventory") {
        {
          ... on Product {
            upc
          }
        } =>
        ($locale:String) {
          ... on Product {
            shippingEstimate
          }
        }
      },
    },
    Flatten(path: "products.@") {
      Fetch(service: "inventory") {
        {
          ... on Product {
            upc
          }
        } =>
        ($locale:String!) {
          ... on Product {
            shippingEstimate
          }
        }
      },
    },
  },
},
"""
    )


def optimize_parallel_node_avoids_representations_variable_collision() -> (
    String
):
    """Return the upstream snapshot of `optimize_parallel_node_avoids_representations_variable_collision`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  BatchFetch(service: "inventory") {
    {
      _e0 {
        paths: [
          "products.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
    }
    ($__batch_reps_0:String) {
      _e0: _entities(representations: $__batch_reps_1) {
        ... on Product {
          shippingEstimate
        }
      }
    }
  },
},
"""
    )


def optimize_parallel_node_does_not_batch_across_subgraphs() -> String:
    """Return the upstream snapshot of `optimize_parallel_node_does_not_batch_across_subgraphs`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  Parallel {
    Flatten(path: "products.@") {
      Fetch(service: "inventory") {
        {
          ... on Product {
            upc
          }
        } =>
        {
          ... on Product {
            shippingEstimate
          }
        }
      },
    },
    Flatten(path: "products.@") {
      Fetch(service: "products") {
        {
          ... on Product {
            upc
          }
        } =>
        {
          ... on Product {
            shippingEstimate
          }
        }
      },
    },
  },
},
"""
    )


def optimize_parallel_node_batches_same_shape_with_different_merge_paths() -> (
    String
):
    """Return the upstream snapshot of `optimize_parallel_node_batches_same_shape_with_different_merge_paths`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  BatchFetch(service: "inventory") {
    {
      _e0 {
        paths: [
          "products.@"
          "topProducts.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
    }
    {
      _e0: _entities(representations: $__batch_reps_0) {
        ... on Product {
          shippingEstimate
        }
      }
    }
  },
},
"""
    )


def optimize_parallel_node_splits_aliases_when_entities_query_differs() -> (
    String
):
    """Return the upstream snapshot of `optimize_parallel_node_splits_aliases_when_entities_query_differs`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  BatchFetch(service: "inventory") {
    {
      _e0 {
        paths: [
          "products.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
      _e1 {
        paths: [
          "topProducts.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
    }
    {
      _e0: _entities(representations: $__batch_reps_0) {
        ... on Product {
          shippingEstimate
        }
      }
      _e1: _entities(representations: $__batch_reps_1) {
        ... on Product {
          inStock
        }
      }
    }
  },
},
"""
    )


def optimize_parallel_node_shares_representations_variable_when_input_and_paths_match() -> (
    String
):
    """Return the upstream snapshot of `optimize_parallel_node_shares_representations_variable_when_input_and_paths_match`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  BatchFetch(service: "inventory") {
    {
      _e0 {
        paths: [
          "products.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
      _e1 {
        paths: [
          "products.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
    }
    {
      _e0: _entities(representations: $__batch_reps_0) {
        ... on Product {
          shippingEstimate
        }
      }
      _e1: _entities(representations: $__batch_reps_0) {
        ... on Product {
          inStock
        }
      }
    }
  },
},
"""
    )


def optimize_parallel_node_does_not_share_representations_variable_when_requires_differs() -> (
    String
):
    """Return the upstream snapshot of `optimize_parallel_node_does_not_share_representations_variable_when_requires_differs`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  BatchFetch(service: "inventory") {
    {
      _e0 {
        paths: [
          "products.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
      _e1 {
        paths: [
          "products.@"
        ]
        {
          ... on Product {
            name
          }
        }
      }
    }
    {
      _e0: _entities(representations: $__batch_reps_0) {
        ... on Product {
          ...a
        }
      }
      _e1: _entities(representations: $__batch_reps_1) {
        ... on Product {
          ...a
        }
      }
    }
    fragment a on Product {
      shippingEstimate
    }
  },
},
"""
    )


def optimize_parallel_node_does_not_share_representations_variable_when_input_rewrites_differ() -> (
    String
):
    """Return the upstream snapshot of `optimize_parallel_node_does_not_share_representations_variable_when_input_rewrites_differ`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  BatchFetch(service: "inventory") {
    {
      _e0 {
        paths: [
          "products.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
      _e1 {
        paths: [
          "products.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
    }
    {
      _e0: _entities(representations: $__batch_reps_0) {
        ... on Product {
          ...a
        }
      }
      _e1: _entities(representations: $__batch_reps_1) {
        ... on Product {
          ...a
        }
      }
    }
    fragment a on Product {
      shippingEstimate
    }
  },
},
"""
    )


def optimize_parallel_node_splits_aliases_when_requires_differs() -> String:
    """Return the upstream snapshot of `optimize_parallel_node_splits_aliases_when_requires_differs`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  BatchFetch(service: "inventory") {
    {
      _e0 {
        paths: [
          "products.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
      _e1 {
        paths: [
          "topProducts.@"
        ]
        {
          ... on Product {
            name
          }
        }
      }
    }
    {
      _e0: _entities(representations: $__batch_reps_0) {
        ... on Product {
          ...a
        }
      }
      _e1: _entities(representations: $__batch_reps_1) {
        ... on Product {
          ...a
        }
      }
    }
    fragment a on Product {
      shippingEstimate
    }
  },
},
"""
    )


def optimize_parallel_node_splits_aliases_when_input_rewrites_differ() -> (
    String
):
    """Return the upstream snapshot of `optimize_parallel_node_splits_aliases_when_input_rewrites_differ`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  BatchFetch(service: "inventory") {
    {
      _e0 {
        paths: [
          "products.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
      _e1 {
        paths: [
          "topProducts.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
    }
    {
      _e0: _entities(representations: $__batch_reps_0) {
        ... on Product {
          ...a
        }
      }
      _e1: _entities(representations: $__batch_reps_1) {
        ... on Product {
          ...a
        }
      }
    }
    fragment a on Product {
      shippingEstimate
    }
  },
},
"""
    )


def optimize_parallel_node_splits_aliases_when_output_rewrites_differ() -> (
    String
):
    """Return the upstream snapshot of `optimize_parallel_node_splits_aliases_when_output_rewrites_differ`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  BatchFetch(service: "inventory") {
    {
      _e0 {
        paths: [
          "products.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
      _e1 {
        paths: [
          "topProducts.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
    }
    {
      _e0: _entities(representations: $__batch_reps_0) {
        ... on Product {
          ...a
        }
      }
      _e1: _entities(representations: $__batch_reps_1) {
        ... on Product {
          ...a
        }
      }
    }
    fragment a on Product {
      shippingEstimate
    }
  },
},
"""
    )


def optimize_parallel_node_shares_representations_variable_when_only_output_rewrites_differ() -> (
    String
):
    """Return the upstream snapshot of `optimize_parallel_node_shares_representations_variable_when_only_output_rewrites_differ`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  BatchFetch(service: "inventory") {
    {
      _e0 {
        paths: [
          "products.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
      _e1 {
        paths: [
          "products.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
    }
    {
      _e0: _entities(representations: $__batch_reps_0) {
        ... on Product {
          ...a
        }
      }
      _e1: _entities(representations: $__batch_reps_0) {
        ... on Product {
          ...a
        }
      }
    }
    fragment a on Product {
      shippingEstimate
    }
  },
},
"""
    )


def optimize_parallel_node_alias_order_is_deterministic() -> String:
    """Return the upstream snapshot of `optimize_parallel_node_alias_order_is_deterministic`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  BatchFetch(service: "inventory") {
    {
      _e0 {
        paths: [
          "products.@"
          "products2.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
      _e1 {
        paths: [
          "topProducts.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
    }
    {
      _e0: _entities(representations: $__batch_reps_0) {
        ... on Product {
          shippingEstimate
        }
      }
      _e1: _entities(representations: $__batch_reps_1) {
        ... on Product {
          inStock
        }
      }
    }
  },
},
"""
    )


def optimize_parallel_node_batches_entities_query_with_fragment_spread() -> (
    String
):
    """Return the upstream snapshot of `optimize_parallel_node_batches_entities_query_with_fragment_spread`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  BatchFetch(service: "inventory") {
    {
      _e0 {
        paths: [
          "products.@"
          "topProducts.@"
        ]
        {
          ... on Product {
            upc
          }
        }
      }
    }
    {
      _e0: _entities(representations: $__batch_reps_0) {
        ... on Product {
          ... on Product {
            shippingEstimate
          }
        }
      }
    }
  },
},
"""
    )


def optimize_parallel_node_returns_original_when_no_entity_candidates() -> (
    String
):
    """Return the upstream snapshot of `optimize_parallel_node_returns_original_when_no_entity_candidates`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  Parallel {
    Fetch(service: "products") {
      {
        products {
          upc
        }
      }
    },
    Fetch(service: "inventory") {
      {
        products {
          upc
        }
      }
    },
  },
},
"""
    )


def optimize_parallel_node_does_not_batch_single_candidate() -> String:
    """Return the upstream snapshot of `optimize_parallel_node_does_not_batch_single_candidate`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  Flatten(path: "products.@") {
    Fetch(service: "inventory") {
      {
        ... on Product {
          upc
        }
      } =>
      {
        ... on Product {
          shippingEstimate
        }
      }
    },
  },
},
"""
    )


def optimize_parallel_node_creates_multiple_batch_nodes_for_multiple_services() -> (
    String
):
    """Return the upstream snapshot of `optimize_parallel_node_creates_multiple_batch_nodes_for_multiple_services`.

    Returns:
        The plan text.
    """
    return String(
        """QueryPlan {
  Parallel {
    BatchFetch(service: "inventory") {
      {
        _e0 {
          paths: [
            "products.@"
            "topProducts.@"
          ]
          {
            ... on Product {
              upc
            }
          }
        }
      }
      {
        _e0: _entities(representations: $__batch_reps_0) {
          ... on Product {
            shippingEstimate
          }
        }
      }
    },
    BatchFetch(service: "products") {
      {
        _e0 {
          paths: [
            "products.@"
            "topProducts.@"
          ]
          {
            ... on Product {
              upc
            }
          }
        }
      }
      {
        _e0: _entities(representations: $__batch_reps_0) {
          ... on Product {
            shippingEstimate
          }
        }
      }
    },
  },
},
"""
    )
