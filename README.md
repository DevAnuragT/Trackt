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
│  • ST_MakePolygon / Unions   │  │   (Chain ID: 143)    │
│  • ST_Intersection / Diff    │  │  • TerritoryRegistry │
│  • Fast Viewport Culling     │  │  • RunRewardToken    │
└──────────────────────────────┘  └──────────────────────┘
```

* **Frontend:** Flutter & Dart, GetX state management, Mapbox Maps SDK v2.0.
* **Spatial Engine:** PostgreSQL + PostGIS (`ST_MakePolygon`, `ST_UnaryUnion`, `ST_Intersection`, `ST_Difference`).
* **Blockchain:** Monad Testnet (`Chain ID: 143`) for territory ownership verification, steal audit trails, and tokenized run rewards.
* **Mobile Web3 client:** `web3dart` + an on-device burner wallet (`MonadService`). The private key is generated with `Random.secure()` and persisted in `SharedPreferences`; territory claims are signed locally and broadcast to the Monad RPC. Falls back to a local settlement proof until the contracts are deployed, so the demo never breaks.
* **Smart contracts (teammate):** `TerritoryRegistry.sol` (`claimTerritory`) and `RunRewardToken.sol` (ERC-20 `$TRACKT`).
* **Native Android:** Sticky Foreground Service (`GpsTrackingService.kt`) with wake-locks and Samsung One UI optimization.

---

## 🚀 Hackathon Roadmap & Progress

For our day-by-day action plan leading to the October 13 deadline, see [HACKATHON_WINNING_ROADMAP.md](HACKATHON_WINNING_ROADMAP.md).

---

## 🛠️ Getting Started

### Prerequisites
* Flutter SDK (3.8+)
* Dart SDK (3.8+)
* Android Studio / Xcode

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
MONAD_CHAIN_ID=143
MONAD_TERRITORY_CONTRACT=0x...   # TerritoryRegistry address
MONAD_TOKEN_CONTRACT=0x...       # RunRewardToken ($TRACKT) address
```

Once `MONAD_TERRITORY_CONTRACT` is set, completed runs broadcast a real `claimTerritory` transaction to Monad Testnet automatically.

> **Deployed contract addresses:** _TBD — add here with Monad Explorer links once the teammate verifies deployment._

---

## 📜 License
MIT License
