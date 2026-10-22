<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# How to host a gateway

This guide runs ScorchQL, the federated gateway of `gql_scorchql`, on a Linux machine. You publish subgraphs to it, and you open its explorer from another machine on the network. The [ScorchQL](ScorchQL) page is the reference.

## Build the programs

1. Install the toolchain, as [How to install](How-to-install) tells you.
2. Build the gateway, the demo subgraphs and seamstress:

   ```bash
   make scorchql
   ```

The command writes `dist/scorchql`, `dist/scorchql-demo` and `dist/seamstress`.

## Start the gateway

1. Start the gateway:

   ```bash
   dist/scorchql --token "$(openssl rand -hex 16)"
   ```

2. Read the address in the first line of the output, such as `http://my-vm:4000/`.
3. Open that address in a browser on another machine.

The gateway listens on every IPv4 address, on port 4000. It keeps the published subgraphs in `.scorchql/`. Use `--registry` to put them in another directory. The `--token` value protects publishing; keep it to publish later.

If the browser cannot connect, open the port in the firewall of the machine:

```bash
sudo ufw allow 4000/tcp
```

## Publish a subgraph

Publish with [seamstress](Seamstress), as you publish with `rover subgraph publish`. Give the gateway URL, the name and the routing URL of a running subgraph:

```bash
export SCORCHQL_TOKEN=<TOKEN>
dist/seamstress subgraph publish http://my-vm:4000 --name products \
    --routing-url http://10.0.0.5:4001/graphql
```

The gateway reads the SDL of the subgraph with `{ _service { sdl } }`, and composes the supergraph again. When the subgraphs do not compose, the gateway refuses the publish, and seamstress prints the errors. Add `--schema products.graphql` to publish an SDL file instead. `dist/seamstress subgraph list http://my-vm:4000` shows the published subgraphs.

`dist/scorchql publish --gateway http://my-vm:4000 --name products --url <URL>` does the same, without seamstress.

The routing URL must be reachable from the gateway. The gateway reads the SDL of each subgraph again every 10 seconds, and publishes each change. Use `--poll` to change the interval.

You can also publish from the **Subgraphs** view of the explorer, or with one HTTP request:

```bash
curl http://my-vm:4000/scorchql/publish -H 'content-type: application/json' \
    -H 'authorization: Bearer <TOKEN>' \
    --data '{"name":"products","url":"http://10.0.0.5:4001/graphql"}'
```

## Try the demo subgraphs

The demo serves two subgraphs of a fire gear shop: `products` on port 4001 and `reviews` on port 4002.

```bash
dist/scorchql-demo &
dist/scorchql --config examples/scorchql/supergraph.yaml
```

`--config` reads a Rover `supergraph.yaml` at start, and publishes each subgraph in it. Then open the explorer, and run this operation:

```graphql
query {
  products { name price reviews { rating author } averageRating }
}
```

The **Query plan** tab shows the fetch to `products`, then the entity fetch to `reviews`.

You can also run a subscription or a query with `@defer` in the explorer:

```graphql
subscription {
  reviewAdded { rating author body product { name price } }
}
```

## Serve HTTP/2 and HTTP/3

Give the gateway a certificate and its key:

```bash
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -days 365 -subj "/CN=my-vm" -addext "subjectAltName=DNS:my-vm,IP:10.0.0.4" \
    -keyout key.pem -out cert.pem
dist/scorchql --tls-cert cert.pem --tls-key key.pem
```

The gateway then also serves HTTPS on TCP port 4443, with HTTP/2 and HTTP/1.1. It serves HTTP/3 on UDP port 4443, and announces it in the `Alt-Svc` header. Open both ports in the firewall.

A browser uses HTTP/3 only with a certificate that it trusts. A self-signed certificate gives HTTP/2. The HTTP version chip in the explorer header shows the version of each response.

## Keep the gateway running

`examples/scorchql/scorchql.service` is a systemd unit. Copy the programs and the unit, then start it:

```bash
sudo install dist/scorchql /usr/local/bin/scorchql
sudo cp examples/scorchql/scorchql.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now scorchql
```

Put the token in `/etc/scorchql.env`, as `SCORCHQL_TOKEN=<TOKEN>`. The unit keeps the registry in `/var/lib/scorchql`.
