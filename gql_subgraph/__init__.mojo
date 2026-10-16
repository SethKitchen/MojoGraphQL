# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Apollo Federation subgraphs: build a subgraph schema, print it, and
resolve its entities.

Port of `@apollo/subgraph` 2.14.4 (`subgraph-js/`, MIT). The parts that
upstream takes from `@apollo/federation-internals` (Elastic License 2.0)
are implemented from the public Apollo Federation subgraph specification
and from Hive Federation Composition (MIT). See the Subgraph page of the
wiki.
"""
