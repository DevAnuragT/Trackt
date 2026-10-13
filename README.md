# 🏃 Trackt

> **Real-World Geo-Spatial Territory Conquest & Fitness Game on Monad**  
> *Built for the [Monad Metropolis Hackathon](https://hackathon.monad.xyz/) (Consumer Products & Payments / Social Tracks)*

---

## 🌍 Overview

**Trackt** turns everyday outdoor runs into a high-stakes, real-world territory conquest game. 

As runners traverse physical routes, their GPS trajectory traces closed loops that convert into geometric polygons ("Territories"). When paths cross rival runners' land, real-time spatial conquest battles trigger on the **Monad blockchain**—allowing runners to capture, shrink, or completely conquer enemy land, earn on-chain run rewards, join running clubs, and compete on citywide leaderboards.

---

## ⚡ Why Monad?

Physical runners generate continuous, high-frequency spatial interactions. Traditional EVM blockchains fail this use case due to 15–30 second block times and high gas fees that ruin mobile gameplay.

* **10,000 TPS & 1-Second Finality:** Real-time territory capture and conflict clipping resolve in under a second.
* **Micro-Gas Economics:** Payouts, badge mints, and territorial claims cost fractions of a cent, allowing smooth on-chain execution without bankrupting runners.
* **Invisible Mobile UX:** Monad’s speed combined with mobile session keys enables seamless gameplay—no signing wallet popups mid-stride.

---

## ✨ Key Features

* **Real-time territory conquest** — closed-loop runs become on-chain polygons; overlapping rival land is clipped and captured.
* **Judge Demo Mode** — a one-tap run simulator so remote, desk-bound judges can conquer territory without running 500m outside (see below).
* **Invisible mobile Web3** — an on-device Monad burner/session wallet signs and dispatches territory claims silently; no wallet popups mid-run.
* **Seeded global battlefield** — ~50 colorful rival territories across New York, San Francisco, and London so the map is alive the moment it opens.
* **$TRACKT economy & Power-Up Shop** — earn tokens by conquering territory; spend them on a Territory Shield, Speed Multiplier (2× rewards), or a Custom Flag.
* **Proof of Physical Movement** — an anti-cheat velocity filter rejects GPS updates implying speeds above 25 km/h (vehicles, teleport spoofs).

---

## 🧪 Judge Demo Mode (for Evaluators)

No running shoes required. From the map screen:

1. Tap the **⚡ Judge Demo Lab** pill (top-left).
2. Pick a circuit (Central Park NYC, Hyde Park London, Presidio SF, or your local GPS) and a speed (⚡ Turbo ~5s, 🎬 Demo ~14s, 🏃 Natural ~30s).
3. Watch the simulated runner trace an organic closed loop, close it, and claim the territory.
4. A victory dialog shows the claimed area, distance, +$TRACKT earned, and a **Monad Testnet settlement proof** (tx hash + Monad Explorer link).

Simulation bypasses auth and network so it works on a fresh install with no account.

---

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────┐
│                   Flutter Mobile App                   │
│   (Mapbox Vector Maps • GetX Reactive • Geolocator)    │
└───────────────┬────────────────────────┬───────────────┘
                │                        │
       [Spatial Polygon]         [On-Chain State]
                ▼                        ▼
┌──────────────────────────────┐  ┌──────────────────────┐
│     PostGIS Spatial Engine   │  │   Monad Testnet      │
│  • ST_MakePolygon / Unions   │  │   (Chain ID: 10143)    │
│  • ST_Intersection / Diff    │  │  • TerritoryRegistry │
│  • Fast Viewport Culling     │  │  • RunRewardToken    │
└──────────────────────────────┘  └──────────────────────┘
```

* **Frontend:** Flutter & Dart, GetX state management, Mapbox Maps SDK v2.0.
* **Spatial Engine:** PostgreSQL + PostGIS (`ST_MakePolygon`, `ST_UnaryUnion`, `ST_Intersection`, `ST_Difference`).
* **Blockchain:** Monad Testnet (`Chain ID: 10143`) for territory ownership verification, steal audit trails, and tokenized run rewards.
* **Mobile Web3 client:** `web3dart` + an on-device burner wallet (`MonadService`). The private key is generated with `Random.secure()` and persisted in `SharedPreferences`; territory claims are signed locally and broadcast to the Monad RPC. Falls back to a local settlement proof until the contracts are deployed, so the demo never breaks.
* **Smart contracts:** [`TerritoryRegistry.sol`](contracts/src/TerritoryRegistry.sol) (`claimTerritory` + conquest) and [`RunRewardToken.sol`](contracts/src/RunRewardToken.sol) (ERC-20 `$TRACKT`), built and tested with Foundry (32 passing tests). See [`contracts/`](contracts/README.md).
* **Native Android:** Sticky Foreground Service (`GpsTrackingService.kt`) with wake-locks and Samsung One UI optimization.

---

## 🚀 Hackathon Roadmap & Progress

For our action plan, see [HACKATHON_WINNING_ROADMAP.md](HACKATHON_WINNING_ROADMAP.md).
The supplied Envio, Alchemy and Privy portal pages display a bounty deadline of
**October 14, 2026 at 09:29 GMT+5:30**. Confirm the overall project deadline in
the submission portal rather than relying on the older roadmap dates.

---

## 🛠️ Getting Started

### Prerequisites
* Flutter SDK (3.8+)
* Dart SDK (3.8+)
* Android Studio / Xcode
* Android 9 / API 28+ or iOS 17+ (required by `privy_flutter` 0.11)

### Setup & Run
1. Clone the repository:
   ```bash
   git clone https://github.com/DevAnuragT/Trackt.git
   cd Trackt
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the development build:
   ```bash
   flutter run --dart-define=ENV=dev
   ```

### Monad configuration

The app ships with sensible defaults and runs with **no extra config** (it uses a local settlement proof until contracts are live). To point it at deployed contracts, set these in your `.env.<env>` file:

```env
MONAD_RPC_URL=https://testnet-rpc.monad.xyz
MONAD_CHAIN_ID=10143
MONAD_TERRITORY_CONTRACT=0x...   # TerritoryRegistry address
MONAD_TOKEN_CONTRACT=0x...       # RunRewardToken ($TRACKT) address
```

Once `MONAD_TERRITORY_CONTRACT` is set, completed runs broadcast a real `claimTerritory` transaction to Monad Testnet automatically.

To build, test, and deploy the contracts, see [`contracts/README.md`](contracts/README.md).

### Sponsor integration deployment

The [Envio indexer](indexer/README.md) is ready to deploy from branch `monad`
with root directory `indexer` and config file `config.yaml`. It indexes real
Monad territory claims and conquests; authorizing the GitHub App alone does
not deploy it.

Configure public mobile settings in `.env.dev` and rebuild/restart:

```env
PRIVY_APP_ID=your_public_app_id
PRIVY_CLIENT_ID=your_public_mobile_client_id
ENVIO_GRAPHQL_URL=https://your-public-indexer-endpoint
MONAD_RPC_PROVIDER=alchemy
ALCHEMY_API_KEY=your_restricted_rpc_key
```

Use `MONAD_RPC_PROVIDER=public` to retain the configured public RPC. Enable
Monad Testnet in the Alchemy dashboard before selecting `alchemy`; the client
rejects a wrong-chain RPC rather than signing on it.

Tap the map's wallet pill to **Connect Privy wallet** or open **On-chain
standings**. Privy uses email OTP and signs actual registry calls; it does not
replace the Trackt/Supabase login. Selecting it creates/uses a separate address.
The original burner address and private key remain intact, including during
sign-out. Fund the selected wallet with Testnet MON; no funds are moved
automatically. An offline/unverified selected Privy session is not silently
replaced by the burner for signing.

The leaderboard contains real indexed claims, not seeded rivals or local demo
proofs. Missing configuration, an unavailable indexer, and an empty indexed
chain have distinct states. A broadcast hash is not labeled confirmed;
check its receipt on the explorer.

Never put deployment tokens or service-role credentials into Flutter assets.
The retired AI integration is not part of Trackt or its submission; retained
database migration history is documented in [supabase/README.md](supabase/README.md).

### Bounty requirements and evidence

The requirements below come from the sponsor portal screenshots supplied on
October 13, 2026. Meeting technical requirements is not a guarantee of a prize.
All three bounties are track-agnostic and request a written description of the
integration; each form also offers an optional demo video of up to two minutes.

| Bounty | Prize shown | Required functionality | Current evidence and remaining work |
| --- | --- | --- | --- |
| Envio | $1,000 USD, one prize | HyperIndex, HyperSync or HyperRPC must drive a useful feature with real on-chain data; deployed pipeline, public source and consuming frontend/API; short end-to-end demo or live link | HyperIndex indexes claims/conquests into `Player`, `Territory`, `Claim` and `Conquest` entities; Flutter consumes its leaderboard. The live query returns two real players, with ownership/area aggregates checked against indexed territories and claim events checked against successful Monad receipts. Historical sync is still in progress. Record a new claim reaching the app before calling the demo complete. |
| Alchemy | $1,000 in Alchemy credits, one prize (not cash) | A functional Monad project meaningfully using at least one supported Alchemy service/tool | Alchemy RPC is the configured development provider and returns chain `10143`. The app uses it for MON/token balances, network validation and Privy claim gas estimation; burner transactions also use this RPC. Capture app-driven request activity and a successful claim. Privy's provider broadcasts Privy-signed transactions; do not attribute that broadcast to Alchemy without verifying its route. |
| Privy | $5,000 USD, one prize | Functionality beyond login/authentication, clearly demonstrated | Privy creates/restores the embedded EVM wallet and signs/sends registry calls. A funded claim was recorded on the real phone and its successful receipt, Privy sender and matching territory event independently verified through Alchemy at block `70607206`. The captioned `build/demo/trackt-privy-demo.mp4` is under two minutes; fresh-claim Envio indexing is still pending and labeled accordingly. |

Envio judges value depth of use, correct live data, originality and readable
code/schema. Our derived ownership/area aggregates and conquest history are
relevant; multichain support is an example of extra depth, not a requirement.
Alchemy judges integration quality, technical execution and usefulness.
Privy awards bonus consideration for multiple meaningful features, but does
not require adding unrelated features merely to increase a feature count.

**Draft submission descriptions (verify the demo evidence before submitting):**

- **Envio:** "Trackt uses Envio HyperIndex to turn Monad territory claim and
  conquest events into current ownership records, runner area/count aggregates
  and an auditable claim/conquest history. Its Flutter on-chain standings query
  the deployed GraphQL API and rank runners by currently owned area. The handlers
  remove a conquered territory from the previous owner's totals and avoid
  double-counting the accompanying claim event; local demo proofs and seeded
  rivals never enter these standings."
- **Alchemy:** "Trackt uses Alchemy's Monad Testnet JSON-RPC for live native and
  reward-token balances, network validation and gas estimation for territory
  claims. The client checks the RPC chain before signing. Its supported burner
  path also broadcasts registry calls through Alchemy; embedded-wallet claims
  use Privy's provider for signing/broadcast and Alchemy for reads/estimation."
- **Privy:** "Trackt uses Privy beyond authentication: runners create or restore
  a non-custodial embedded EVM wallet and use its native provider to sign and
  send `claimTerritory` calls on Monad Testnet. The selected wallet persists for
  the Trackt account, drives displayed balances and is never silently replaced
  by a burner when its session is unverified. The existing burner and funds
  remain intact; a funded on-device claim demonstrates the wallet functionality."

Confirmed indexed claim examples (these establish Envio data correctness, not
that the original sender used Privy or Alchemy):

- [`0xd3ff7652921c4aaf0e9fcecb084622b269a71f3daae267190bffe5db7db1aa6d`](https://testnet.monadexplorer.com/tx/0xd3ff7652921c4aaf0e9fcecb084622b269a71f3daae267190bffe5db7db1aa6d)
- [`0xa62998f9c0ede05fd7534fb1fc793aa521b7b3945e04061440a13ab0240439d3`](https://testnet.monadexplorer.com/tx/0xa62998f9c0ede05fd7534fb1fc793aa521b7b3945e04061440a13ab0240439d3)

**Confirmed funded Privy claim, October 13:** transaction
[`0x6ae6d7b3497c35943f7103f8140b58e7ec71d07e342987b9e1982b2df5f1104d`](https://testnet.monadexplorer.com/tx/0x6ae6d7b3497c35943f7103f8140b58e7ec71d07e342987b9e1982b2df5f1104d)
at block `70607206`, from the connected Privy address
`0xa0e1F726D2f01f7e325418E05ac4C5820990c71c` to TerritoryRegistry.
Its successful receipt and claim event agree on the owner and `25463` square
meters; the wallet received `100` on-chain TRACKT. No burner fallback was used.
The exact new hash was not yet returned by Envio during this check, so that
transaction is not presented as fresh indexed proof in the video.

See [SUBMISSION_VIDEO_SCRIPT.md](SUBMISSION_VIDEO_SCRIPT.md) for an end-to-end
two-minute recording plan and [TESTING_NOTES.md](TESTING_NOTES.md) for live
verification steps. No AI sponsor integration is claimed.

> **Deployed on Monad Testnet (Chain ID `10143`):**
> - `TerritoryRegistry`: [`0x9ed60acE1E5288F010bD12b33a5D9d531f65bBb1`](https://testnet.monadexplorer.com/address/0x9ed60acE1E5288F010bD12b33a5D9d531f65bBb1)
> - `RunRewardToken` ($TRACKT): [`0x3f660583F7D2Fbf2f2484b468BE3F7e3121Bf8B6`](https://testnet.monadexplorer.com/address/0x3f660583F7D2Fbf2f2484b468BE3F7e3121Bf8B6)

---

## 📜 License
MIT License
