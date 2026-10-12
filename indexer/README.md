# Trackt on-chain leaderboard

Envio HyperIndex indexes the deployed `TerritoryRegistry` on Monad Testnet
(chain `10143`) from its deployment block, `70154932`. Current ownership and
area come from `TerritoryClaimed`; `TerritoryConquered` records conquest history
without double-counting the accompanying claim event.

## Local validation

Node 24+ is required. Use the pinned package manager:

```sh
npx --yes pnpm@10.32.0 install --frozen-lockfile
npx --yes pnpm@10.32.0 typecheck
npx --yes pnpm@10.32.0 test
```

Tests exercise real Envio handlers with simulated events and do not require
Docker or a HyperSync token. `pnpm dev` additionally requires a running Docker
daemon. Historical indexing uses the public Monad RPC, so no Envio API token
is required by this configuration.

The public RPC rejects `eth_getLogs` ranges above 100 blocks with HTTP 413.
The indexer caps historical batches at this verified limit instead of
repeatedly growing into rejected ranges and backing off. Initial history
still takes time to sync; an empty player list does not mean sync is complete.

## Envio Cloud

Authorize the Envio Deployments GitHub App for `DevAnuragT/Trackt`, then add an
indexer with:

| Setting | Value |
| --- | --- |
| Repository | `DevAnuragT/Trackt` |
| Branch | `monad` |
| Root directory | `indexer` |
| Config file, relative to root | `config.yaml` |
| Node | 24+ |

Deploy and wait until it catches up to the chain head. Copy the public GraphQL
endpoint into the mobile app's local environment as `ENVIO_GRAPHQL_URL`.
Do not put an Envio admin secret or deployment token in the mobile app.

If the dashboard shows **0/3 deployments**, the indexer has been configured
but no instance has been started. A new commit pushed to the configured
branch triggers the first deployment; a push with "Everything up-to-date"
does not. Open the resulting deployment to find its query/GraphQL endpoint
and inspect build or indexing logs if it fails to start.

Verify the endpoint returns real indexed runners:

```graphql
query TracktLeaderboard {
  Player(
    where: { territoryCount: { _gt: 0 } }
    order_by: [{ totalArea: desc }, { territoryCount: desc }, { address: asc }]
    limit: 20
  ) {
    address
    territoryCount
    totalArea
    conquestCount
  }
}
```

Inspect synchronization separately:

```graphql
query TracktIndexingStatus {
  chain_metadata {
    chain_id
    block_height
    latest_processed_block
    num_events_processed
    timestamp_caught_up_to_head_or_endblock
  }
}
```

The indexer does not create mock runners or submit blockchain transactions.
