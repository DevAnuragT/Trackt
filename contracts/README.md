# Trackt Smart Contracts

Solidity contracts for Trackt's on-chain territory conquest, built and tested with [Foundry](https://getfoundry.sh), targeting **Monad Testnet** (Chain ID `143`).

## Contracts

| Contract | Purpose |
| :--- | :--- |
| [`RunRewardToken.sol`](src/RunRewardToken.sol) | ERC-20 `$TRACKT` reward token. Minted to runners by authorized game controllers. Owner-managed minter allowlist. |
| [`TerritoryRegistry.sol`](src/TerritoryRegistry.sol) | Registry of claimed territories. `claimTerritory` mints a fresh territory or conquers a rival's, transferring ownership and emitting `TerritoryConquered`. Each claim/conquest mints a `$TRACKT` reward (best-effort). |

### Client integration

The mobile client (`lib/services/monad_service.dart`) calls:

```solidity
claimTerritory(uint256 territoryId, int256 lat, int256 lng, uint256 area)
balanceOf(address account) // RunRewardToken (ERC-20)
```

Coordinates are fixed-point: `degrees * 1e6` (the client sends `(lat * 1e6).round()`).

## Build & test

```bash
cd contracts
forge build
forge test -vvv
```

32 tests cover ERC-20 mechanics, minter access control, fresh claims, conquest,
owner re-affirmation, reward best-effort behavior, area bounds, admin guards,
views, and fuzzed inputs.

## Deploy to Monad Testnet

```bash
export PRIVATE_KEY=0x<deployer-key>
export CLAIM_REWARD=100000000000000000000   # optional, 100 $TRACKT (18 decimals)

forge script script/Deploy.s.sol:Deploy \
  --rpc-url https://testnet-rpc.monad.xyz \
  --broadcast
```

The script deploys both contracts and authorizes the registry as a token minter.
After deployment, set the addresses in the app's `.env.<env>`:

```env
MONAD_TERRITORY_CONTRACT=0x...
MONAD_TOKEN_CONTRACT=0x...
```
