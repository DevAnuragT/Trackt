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

---

## 📜 License
MIT License
