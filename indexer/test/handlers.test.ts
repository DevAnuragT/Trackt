import { createTestIndexer } from "envio";
import { describe, expect, it } from "vitest";

const alice = "0x1111111111111111111111111111111111111111";
const bob = "0x2222222222222222222222222222222222222222";

function claim(owner: `0x${string}`, areaSqMeters: bigint, territoryId = 1n) {
  return {
    contract: "TerritoryRegistry" as const,
    event: "TerritoryClaimed" as const,
    params: {
      territoryId,
      owner,
      centerLat: -33500000n,
      centerLng: 151000000n,
      areaSqMeters,
      timestamp: 1700000000n,
    },
  };
}

describe("TerritoryRegistry leaderboard", () => {
  it("records a fresh claim with signed coordinates and exact large integers", async () => {
    const indexer = createTestIndexer();
    await indexer.process({
      chains: {
        10143: { simulate: [claim(alice, 1200n, 2n ** 128n)] },
      },
    });
    expect(await indexer.Player.getOrThrow(`10143_${alice}`)).toMatchObject({
      territoryCount: 1,
      totalArea: 1200n,
      claimCount: 1,
      conquestCount: 0,
    });
    expect(
      await indexer.Territory.getOrThrow(`10143_${2n ** 128n}`),
    ).toMatchObject({
      centerLat: -33500000n,
      centerLng: 151000000n,
      owner_id: `10143_${alice}`,
    });
  });

  it("refreshes geometry without counting the same territory twice", async () => {
    const indexer = createTestIndexer();
    await indexer.process({
      chains: {
        10143: { simulate: [claim(alice, 1200n), claim(alice, 900n)] },
      },
    });
    expect(await indexer.Player.getOrThrow(`10143_${alice}`)).toMatchObject({
      territoryCount: 1,
      totalArea: 900n,
      claimCount: 2,
    });
    expect(await indexer.Claim.getAll()).toHaveLength(2);
  });

  it("transfers ownership once when a conquest emits both events", async () => {
    const indexer = createTestIndexer();
    await indexer.process({
      chains: {
        10143: {
          simulate: [
            claim(alice, 1200n),
            {
              contract: "TerritoryRegistry",
              event: "TerritoryConquered",
              params: {
                stolenTerritoryId: 1n,
                previousOwner: alice,
                conqueror: bob,
                areaStolen: 1200n,
              },
            },
            claim(bob, 900n),
          ],
        },
      },
    });
    expect(await indexer.Player.getOrThrow(`10143_${alice}`)).toMatchObject({
      territoryCount: 0,
      totalArea: 0n,
    });
    expect(await indexer.Player.getOrThrow(`10143_${bob}`)).toMatchObject({
      territoryCount: 1,
      totalArea: 900n,
      conquestCount: 1,
    });
    expect(await indexer.Conquest.getAll()).toHaveLength(1);
    expect(await indexer.Territory.getOrThrow("10143_1")).toMatchObject({
      owner_id: `10143_${bob}`,
      areaSqMeters: 900n,
    });
  });

  it("aggregates multiple territories and handles a conquest back", async () => {
    const indexer = createTestIndexer();
    await indexer.process({
      chains: {
        10143: {
          simulate: [
            claim(alice, 1000n),
            claim(alice, 500n, 2n),
            {
              contract: "TerritoryRegistry",
              event: "TerritoryConquered",
              params: {
                stolenTerritoryId: 1n,
                previousOwner: alice,
                conqueror: bob,
                areaStolen: 1000n,
              },
            },
            claim(bob, 800n),
            {
              contract: "TerritoryRegistry",
              event: "TerritoryConquered",
              params: {
                stolenTerritoryId: 1n,
                previousOwner: bob,
                conqueror: alice,
                areaStolen: 800n,
              },
            },
            claim(alice, 1100n),
          ],
        },
      },
    });
    expect(await indexer.Player.getOrThrow(`10143_${alice}`)).toMatchObject({
      territoryCount: 2,
      totalArea: 1600n,
      conquestCount: 1,
    });
    expect(await indexer.Player.getOrThrow(`10143_${bob}`)).toMatchObject({
      territoryCount: 0,
      totalArea: 0n,
      conquestCount: 1,
    });
  });
});
