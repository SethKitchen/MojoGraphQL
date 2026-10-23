# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Forge, a control plane for customer-hosted supergraphs.

Forge is original work. It ports no upstream project. People and companies
register the ScorchQL gateways or routers that they already run. Forge
does not host those graphs. The customer allowlists the Forge IP, or they
upload SDL. Forge then supplies telemetry, schema exploration, environment
comparison and an analyst.

The `forge` program is `bin/forge.mojo`.
"""
