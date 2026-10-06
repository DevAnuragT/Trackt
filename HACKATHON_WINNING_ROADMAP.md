# 🏆 Monad Metropolis Hackathon: Winning Roadmap & Action Plan

**Target Event:** Monad Metropolis Global Online Hackathon  
**Prize Pool:** $250,000+ USD  
**Submission Deadline:** October 13, 2026 (~7 Days Remaining)  
**Target Tracks:**  
- **Primary:** *Consumer Products & Payments* (Mobile-first, invisible Web3, real-world utility)  
- **Secondary:** *Social, Attention, and Culture* (Clubs, community coordination, geo-territory conquest)  
**Target Network:** Monad Testnet (Chain ID: `143`)

---

## 1. The Core Narrative: "Why Monad?" (Pitch Thesis)

Judges evaluate hundreds of projects. Your submission must answer this question in the first 15 seconds:  
> **"Why does this app need Monad instead of a traditional blockchain or Web2 database?"**

### The Answer:
* **High-Frequency Real-World State Changes:** Physical runners generate real-time GPS paths that trigger instant spatial collisions. On Ethereum or Arbitrum, waiting 15–60 seconds for block finality and paying $0.50–$2.00 per territory claim ruins mobile gameplay.
* **10,000 TPS & 1-Second Finality:** Monad enables **instant, frictionless territory conquest**. When a runner closes a loop, their territory is minted and enemy lands are clipped in under a second with fractions of a cent in gas.
* **Invisible Mobile Web3:** By combining Monad's micro-gas economics with embedded mobile wallets, users run and conquer without being prompted by intrusive wallet popups on the road.

---

## 2. P0: Anti-Disqualification & Monad On-Chain Core (Days 1–3)

Without on-chain deployment on Monad Testnet, the app cannot qualify.

- [ ] **Task 0.1: Rebranding & Repository Decoupling**
  - Scrub legacy "Starknet" naming from configs, package identifiers, and docs.
  - Create the fresh public GitHub repository under the chosen brand name.
- [ ] **Task 0.2: Deploy Core Smart Contracts to Monad Testnet (Chain ID: 143)**
  - `TerritoryRegistry.sol`:
    - Stores territory records on-chain: `(uint256 territoryId, address owner, int256 centerLat, int256 centerLng, uint256 areaSqMeters, string geohash, uint256 timestamp)`.
    - Function `claimTerritory(...)` called when a loop run finishes.
    - Function `recordConquest(...)` emitting `TerritoryConquered(uint256 stolenTerritoryId, address previousOwner, address conqueror, uint256 areaStolen)`.
  - `RunRewardToken.sol` (ERC-20):
    - Token reward for completing daily quests (500m / 10min) and conquering territory.
    - Mintable by authoritative game controller contract.
- [ ] **Task 0.3: Flutter Mobile Web3 Integration**
  - Add `web3dart` to [pubspec.yaml](file:///Users/anurag/Starknet-Outpost-App/pubspec.yaml).
  - Create a lightweight `MonadService`:
    - Connect to Monad Testnet RPC endpoint.
    - Generate or import a local burner/session wallet securely in `SharedPreferences`.
    - Automatically fund or sign transactions when runs complete.
  - Wire [run_tracker_controller.dart](file:///Users/anurag/Starknet-Outpost-App/lib/controllers/map/run_tracker_controller.dart#L1000) to broadcast `claimTerritory` to Monad upon run completion.

---

## 3. P1: The Winning Features (Days 3–5)

These features convert a standard prototype into a top-scoring hackathon winner.

- [ ] **Task 1.1: "Judge Simulation Mode" (CRITICAL for Evaluation)**
  - *Problem:* Judges sit at desks in SF, NYC, or Europe. They will NOT lace up running shoes and run 500m outside to test the app.
  - *Solution:* Add a debug switch in the map HUD: **"Simulate 500m Run in Central Park / London"**.
  - When pressed:
    1. Animates a simulated runner along a closed polygon path on the map.
    2. Closes the loop visually.
    3. Triggers PostGIS conflict resolution against rival territories.
    4. Submits the transaction to Monad Testnet.
    5. Displays the live transaction hash and Monad Explorer link in a celebratory modal!
- [ ] **Task 1.2: Seeded Global Rival Territories**
  - Pre-populate 50–100 colorful mock territories across major tech capitals:
    - San Francisco (Presidio, Mission, SoMa)
    - New York (Central Park, Brooklyn)
    - London (Hyde Park)
    - Singapore (Marina Bay)
  - Ensure any judge opening the map sees vibrant rival territories ready to be conquered.
- [ ] **Task 1.3: Anti-Cheat & Velocity Sanity Checks**
  - Add basic server/contract velocity checks (e.g. speed < 25 km/h) to reject obvious teleport/spoof hacks.
  - Highlight this in the pitch deck as "Proof of Physical Movement".

---

## 4. P2: Codebase Hygiene & UX Polish (Days 5–6)

- [ ] **Task 2.1: Clean Out Dead Stubs & Ghost Files**
  - Remove or complete empty stubs:
    - Delete/replace empty `models/user_model.dart` (ensure `models/auth/user_model.dart` is clean).
    - Remove unused `my_runs_controller.dart` stubs.
  - Replace the "Coming Soon" card in [store_view.dart](file:///Users/anurag/Starknet-Outpost-App/lib/views/store/store_view.dart) with an on-chain Power-Up Shop (e.g., purchase "Shield 24h" or "Territory Multiplier" using Run Tokens).
- [ ] **Task 2.2: Polish Mapbox Visuals**
  - Ensure territory polygons load fast with smooth opacity layering and custom user colors.
  - Verify camera animation recentering works smoothly.

---

## 5. P3: Submission & Pitch Package (Days 6–7)

- [ ] **Task 3.1: 2.5-Minute Video Walkthrough (Script)**
  - **0:00–0:25:** The Problem & The Hook ("Fitness apps are boring single-player trackers. Trackt turns the real world into an on-chain territory conquest game powered by Monad.")
  - **0:25–0:50:** Why Monad? (High-frequency micro-conquests, 1-second finality, micro-gas economics).
  - **0:50–1:45:** Live Mobile Demo (Simulating/recording a run, loop closure, territorial theft, live Mapbox rendering).
  - **1:45–2:15:** On-chain Verification (Showing the Monad Testnet Block Explorer transaction, minted territory, and token reward).
  - **2:15–2:30:** Roadmap & Future (Monad Mainnet launch, Guild wars, sponsored brand territories).
- [ ] **Task 3.2: High-Quality README & Architecture Diagram**
  - Clear architectural breakdown (Flutter + PostGIS + Monad EVM).
  - Deployed Monad Testnet contract addresses with clickable explorer links.
  - Instructions to run locally or download test APK.
- [ ] **Task 3.3: Submit on Monad Metropolis Portal**
  - Register project profile on `https://hackathon.monad.xyz/`.
  - Add video, GitHub link, contract addresses, and team bios.

---

## 6. Daily Execution Timeline (Oct 6 – Oct 13)

| Date | Focus Area | Deliverables |
| :--- | :--- | :--- |
| **Oct 6 (Today)** | Setup & Repo Creation | Finalize brand name, create new GitHub repo, commit roadmap. |
| **Oct 7** | Monad Smart Contracts | Write & deploy `TerritoryRegistry.sol` and `RunRewardToken.sol` on Monad Testnet. |
| **Oct 8** | Web3 Mobile Wiring | Integrate `web3dart` / session keys to sign and broadcast run completions. |
| **Oct 9** | Judge Demo Mode | Build the "One-Tap Run Simulator" & seed territories in key tech cities. |
| **Oct 10** | Power-Up Shop & Polish | Replace store "Coming Soon" with token power-ups; delete 0-byte ghost files. |
| **Oct 11** | Demo Video Recording | Record screen capture, voiceover walkthrough, and explorer proof. |
| **Oct 12** | Documentation & Portal Prep | Final README, graphics, block explorer verification, Metropolis draft submission. |
| **Oct 13** | Final Submission | Final sanity check & submit before deadline! 🚀 |
