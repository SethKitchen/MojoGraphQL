<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# How to run Forge

This guide starts Forge, the control plane of `gql_forge`. You register a supergraph that you already host. Then you open the site and compare environments.

## Build the program

1. Install the toolchain, as [How to install](How-to-install) tells you.
2. Build Forge:

   ```bash
   make forge
   ```

The command writes `dist/forge`.

## Start Forge

1. Start Forge:

   ```bash
   dist/forge --advertise-ip 203.0.113.10 --token "$(openssl rand -hex 16)"
   ```

2. Read the address in the first line, such as `http://my-vm:4100/`.
3. Open that address in a browser on another machine.

This command starts only the control plane. It starts no graph. Forge listens on every IPv4 address, on port 4100. It keeps the catalog in `.forge/`. Use `--data` to put it in another directory. The `--token` value protects catalog writes; keep it to register graphs later.

Forge does not host GraphQL traffic. The `--advertise-ip` value is the address that customers allowlist so Forge can pull schemas.

If the browser cannot connect, open the port in the firewall of the machine:

```bash
sudo ufw allow 4100/tcp
```

## Register a graph

1. Open the **Connect** view.
2. Create an organization and a graph.
3. Create a variant with the URL of the ScorchQL or router that you already run.
4. Allowlist the Forge IP on that graph, or upload SDL.

`http://` endpoints can be pulled. Upload SDL for `https://` endpoints.

## Send telemetry

The variant has an ingest token. Send one JSON event after each operation:

```bash
curl http://my-vm:4100/forge/telemetry \
    -H 'content-type: application/json' \
    -H 'authorization: Bearer <INGEST_TOKEN>' \
    --data '{"org":"acme","graph":"shop","variant":"prod","name":"Hero","durationMs":12,"ok":true}'
```

The Insights view then shows counts, errors and percentiles.

## Compare environments

Create a second variant, such as `staging`. Pull or upload its schema. Open **Compare** and select the two variants. Forge lists breaking, dangerous and additive changes.

The [Forge](Forge) page is the reference.
