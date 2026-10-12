import { indexer, type Player } from "envio";

function newPlayer(chainId: number, address: string): Player {
  return {
    id: `${chainId}_${address.toLowerCase()}`,
    address: address.toLowerCase(),
    chainId,
    territoryCount: 0,
    totalArea: 0n,
    claimCount: 0,
    conquestCount: 0,
    lastActivityAt: 0n,
  };
}

indexer.onEvent(
  {
    contract: "TerritoryRegistry",
    event: "TerritoryClaimed",
    fields: { transaction: ["hash"] },
  },
  async ({ event, context }) => {
    const params = event.params;
    const territoryId = `${event.chainId}_${params.territoryId}`;
    const ownerId = `${event.chainId}_${params.owner.toLowerCase()}`;
    const [territory, existingOwner] = await Promise.all([
      context.Territory.get(territoryId),
      context.Player.get(ownerId),
    ]);
    const owner = existingOwner ?? newPlayer(event.chainId, params.owner);

    if (territory && territory.owner_id !== ownerId) {
      const previousOwner = await context.Player.getOrThrow(territory.owner_id);
      context.Player.set({
        ...previousOwner,
        territoryCount: previousOwner.territoryCount - 1,
        totalArea: previousOwner.totalArea - territory.areaSqMeters,
      });
    }

    const sameOwner = territory?.owner_id === ownerId;
    context.Player.set({
      ...owner,
      territoryCount: owner.territoryCount + (sameOwner ? 0 : 1),
      totalArea:
        owner.totalArea -
        (sameOwner ? territory.areaSqMeters : 0n) +
        params.areaSqMeters,
      claimCount: owner.claimCount + 1,
      lastActivityAt: params.timestamp,
    });
    context.Territory.set({
      id: territoryId,
      territoryId: params.territoryId,
      chainId: event.chainId,
      owner_id: ownerId,
      centerLat: params.centerLat,
      centerLng: params.centerLng,
      areaSqMeters: params.areaSqMeters,
      claimedAt: params.timestamp,
      latestTxHash: event.transaction.hash,
    });
    context.Claim.set({
      id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
      territoryId: params.territoryId,
      owner_id: ownerId,
      areaSqMeters: params.areaSqMeters,
      timestamp: params.timestamp,
      blockNumber: event.block.number,
      txHash: event.transaction.hash,
    });
  },
);

// A conquest also emits TerritoryClaimed; only that event updates ownership.
indexer.onEvent(
  {
    contract: "TerritoryRegistry",
    event: "TerritoryConquered",
    fields: { transaction: ["hash"], block: ["timestamp"] },
  },
  async ({ event, context }) => {
    const params = event.params;
    const conquerorId = `${event.chainId}_${params.conqueror.toLowerCase()}`;
    const existing = await context.Player.get(conquerorId);
    const conqueror = existing ?? newPlayer(event.chainId, params.conqueror);
    context.Player.set({
      ...conqueror,
      conquestCount: conqueror.conquestCount + 1,
      lastActivityAt: BigInt(event.block.timestamp),
    });
    context.Conquest.set({
      id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
      territoryId: params.stolenTerritoryId,
      previousOwner: params.previousOwner.toLowerCase(),
      conqueror_id: conquerorId,
      areaStolen: params.areaStolen,
      blockNumber: event.block.number,
      txHash: event.transaction.hash,
    });
  },
);
