# 📖 Trackt — Comprehensive Project Context & Developer Handbook

> **For Claude / AI Assistants & Developers**: This document contains the complete context, architecture, progress status, and roadmap for **Trackt** in the **Monad Metropolis Hackathon**. Read this file before initiating any new task to resume development seamlessly with zero friction.

---

## 1. Executive Summary & Hackathon Profile

| Attribute | Details |
| :--- | :--- |
| **Project Name** | **Trackt** (formerly Starknet-Outpost-App) |
| **Tagline** | *Run. Claim. Conquer.* — Real-World Territory Conquest Powered by Monad |
| **Hackathon** | [Monad Metropolis](https://hackathon.monad.xyz/) (Global Online Hackathon) |
| **Prize Pool** | $250,000+ USD |
| **Submission Deadline** | October 13, 2026 |
| **Target Tracks** | **Primary:** *Consumer Products & Payments* (Mobile-first, frictionless, invisible Web3) <br> **Secondary:** *Social, Attention & Culture* (Clubs, geo-territory conquest, social coordination) |
| **Target Network** | **Monad Testnet** (Chain ID: `143`, Currency: `MON`) |
| **Official Repository** | [`https://github.com/DevAnuragT/Trackt`](https://github.com/DevAnuragT/Trackt) |
| **Active Working Branch** | **`monad`** (All development and commits must go here) |

---

## 2. Core Value Proposition: "Why Monad?"

Every winning hackathon entry needs an undeniable 15-second thesis:

1. **High-Frequency Real-World State Changes:** Runners generate continuous GPS coordinates. When closed loops occur, territory boundaries are calculated and rival lands are stolen in real-time.
2. **Sub-Second Finality (<800ms) & 10,000 TPS:** On traditional L1s or slow rollups (15–60s blocks, $0.50–$2.00 gas fees), mobile gaming breaks down. Monad allows instant on-chain territory minting and clipping for fractions of a cent without interrupting the runner's stride.
3. **Invisible Mobile Web3:** Trackt uses burner/session wallets generated locally on device. Runners do not need to confirm MetaMask popups mid-run; transactions settle silently in the background at Monad speed.

---

## 3. Team Responsibilities & Division of Labor

- **Our Focus (User & Claude / Mobile Engineering)**:
  - Mobile client engineering (Flutter / Dart).
  - Mapbox real-time GPS tracking, camera smoothing, path drawing, and dynamic polygon rendering.
  - Judge Simulation Mode (frictionless evaluation for remote desk-bound judges).
  - Client-side Web3 integration (`web3dart`, burner wallet management, JSON-RPC dispatch to Monad Testnet).
  - Supabase & PostGIS spatial database queries (loop detection, `ST_Difference`, `ST_Area`).
  - Mobile UI/UX polish (dark-mode glassmorphism, Monad purple/cyan aesthetics, power-up shop).
- **Teammate's Focus**:
  - Solidity smart contract development (`TerritoryRegistry.sol`, `RunRewardToken.sol`).
  - Deploying and verifying contracts on Monad Testnet (Chain ID `143`).
  - Providing contract ABIs and deployed addresses to the mobile client.

---

## 4. Technology Stack & Key Libraries

```
Trackt Mobile App (Flutter 3.x / Dart)
 ├── UI & State Management: GetX (Reactive observables, GetMaterialApp)
 ├── Mapping Engine: Mapbox Maps Flutter (^2.0.0, MapWidget, PointAnnotationManager, PolygonManager)
 ├── Geolocation: Geolocator (^13.0.2) + LocationPermissionService
 ├── Spatial Backend: Supabase Flutter (^2.8.4) + PostGIS (RPC: upload_territory, get_territories)
 ├── Web3 Blockchain: web3dart (^2.7.3), http (^1.3.0), hex, convert
 └── Simulation Engine: Custom SimulationService (organic waypoint generator, GPS injection)
```

---

## 5. Current Implementation Status (What Has Been Completed)

### ✅ Repository Setup & Security Guard
- Reset to clean initial commit (`def8eea`), pushed to `DevAnuragT/Trackt`.
- Hardened `.gitignore`: `android/app/google-services.json` and `.env.*` are ignored. Sanitized `google-services.json.template` provided.
- Active branch renamed to `monad` (`origin/monad`).

### ✅ Task 1: Judge Simulation Mode (CRITICAL for Evaluation)
Judges sit at desks in SF, NYC, or Europe; they will not run 500m outside to test the app.
- **Simulation Engine ([`lib/services/simulation_service.dart`](file:///Users/anurag/Starknet-Outpost-App/lib/services/simulation_service.dart))**:
  - 4 Preset Circuits:
    1. *Central Park Great Lawn (NYC)*: 520m perimeter loop.
    2. *Hyde Park Serpentine (London)*: 480m scenic circuit.
    3. *The Presidio Coast (San Francisco)*: 510m bay-side loop.
    4. *Local Proximity Loop*: 400m synthetic loop around current device GPS.
  - 3 Speed Modes: ⚡ Turbo (~5s), 🎬 Demo (~14s), 🏃 Natural (~30s).
  - Organic Perturbation: Waypoints generate smooth, natural park contours (radius perturbation $>10\%$) rather than sterile geometric circles.
- **Simulation Runner Controller ([`lib/controllers/map/run_tracker_controller.dart`](file:///Users/anurag/Starknet-Outpost-App/lib/controllers/map/run_tracker_controller.dart))**:
  - `startSimulatedRun()`, `injectSimulatedPosition()`, `endSimulatedRun()`, `cancelSimulatedRun()`.
  - **Auth & Offline Guard**: Automatically bypasses cloud login rejections during simulation so judges can conquer territory locally in-memory and on Mapbox without needing a registered account.
  - Camera tracking dynamically follows the simulated runner.
- **UI Components**:
  - **Main Map Trigger ([`lib/views/map/map_view.dart`](file:///Users/anurag/Starknet-Outpost-App/lib/views/map/map_view.dart))**: Floating glassmorphic `[ ⚡ Judge Demo Lab ]` pill button in top HUD.
  - **Simulation Sheet ([`lib/views/map/components/simulation_sheet.dart`](file:///Users/anurag/Starknet-Outpost-App/lib/views/map/components/simulation_sheet.dart))**: Modal bottom sheet with circuit cards, speed selector chips, and instant launcher (wrapped in `SingleChildScrollView` for responsive small-screen safety).
  - **Active Run HUD ([`lib/views/run/run_page.dart`](file:///Users/anurag/Starknet-Outpost-App/lib/views/run/run_page.dart))**: Real-time progress bar, waypoint counter, phase status, and cancel button.
  - **Settlement Dialog ([`lib/views/map/components/simulation_victory_dialog.dart`](file:///Users/anurag/Starknet-Outpost-App/lib/views/map/components/simulation_victory_dialog.dart))**: Celebratory modal showing claimed area ($m^2$), distance, $+100\ \$TRACKT$ coins, and Monad Testnet settlement proof (`Chain ID 143`, `10,000 TPS`, Tx hash with copy button).

### ✅ Automated Test Suite (13/13 Tests Passing)
Run `flutter test` to verify:
1. [`test/services/simulation_service_test.dart`](file:///Users/anurag/Starknet-Outpost-App/test/services/simulation_service_test.dart) (8 tests): Validates presets, closed-loop waypoint generation ($pointCount + 1$, first == last point), organic perturbation math, runner velocity/accuracy, and lifecycle resetting.
2. [`test/views/simulation_sheet_test.dart`](file:///Users/anurag/Starknet-Outpost-App/test/views/simulation_sheet_test.dart) (3 tests): Verifies widget layout, responsive scrolling, and reactive speed/preset chip selection.
3. [`test/views/simulation_victory_dialog_test.dart`](file:///Users/anurag/Starknet-Outpost-App/test/views/simulation_victory_dialog_test.dart) (1 test): Verifies victory dialog metrics, Monad Testnet details, and action buttons.
4. [`test/widget_test.dart`](file:///Users/anurag/Starknet-Outpost-App/test/widget_test.dart) (1 test): Baseline Flutter widget verification.

---

## 6. Directory Structure & Key Files

```
lib/
├── controllers/
│   ├── map/
│   │   ├── run_tracker_controller.dart     <-- Main tracking engine & simulation injection
│   │   ├── territory_display_controller.dart<-- Mapbox polygon rendering & styling
│   │   ├── map_controller.dart             <-- Mapbox camera, zoom, style layers
│   │   └── run_path_display_controller.dart<-- Line layers on active run
│   ├── auth/auth_controller.dart           <-- Supabase auth & user sessions
│   └── location/location_controller.dart   <-- Location permissions & GPS status
├── services/
│   ├── simulation_service.dart             <-- Judge Simulation Engine (presets, waypoints)
│   ├── location_service.dart               <-- Geolocator streams
│   ├── territory_service.dart              <-- Local & remote territory caches
│   ├── database_service.dart               <-- Supabase PostGIS RPC calls
│   └── env_config.dart                     <-- Environment variables & fallbacks
├── views/
│   ├── map/
│   │   ├── map_view.dart                   <-- Main map screen with Judge Demo button
│   │   └── components/
│   │       ├── simulation_sheet.dart       <-- Bottom sheet circuit & speed selector
│   │       ├── simulation_victory_dialog.dart<-- Victory modal with Monad Tx proof
│   │       ├── bottom_sheet_widget.dart    <-- Territory stats & start run CTA
│   │       └── map_controls_widget.dart    <-- Zoom in/out, recenter buttons
│   ├── run/
│   │   ├── run_page.dart                   <-- Live tracking screen with Simulation HUD
│   │   └── components/
│   │       ├── run_stats_widget.dart       <-- Real-time distance, duration, pace
│   │       └── run_controls_widget.dart    <-- Pause, stop, cancel controls
│   ├── store/store_view.dart               <-- Power-Up Shop (needs upgrade from Coming Soon)
│   └── club/                               <-- Social clubs & leaderboards
test/
├── services/simulation_service_test.dart   <-- Simulation unit tests
└── views/
    ├── simulation_sheet_test.dart          <-- SimulationSheet widget tests
    └── simulation_victory_dialog_test.dart <-- Victory dialog widget tests
```

---

## 7. Immediate Next Steps (Roadmap & Priority Queue)

### Priority P0: Monad Mobile Web3 Client Integration
* **File to Create:** `lib/services/monad_service.dart`
* **Tasks**:
  1. Initialize `Web3Client` connected to Monad Testnet RPC endpoint:
     - RPC URL: `https://testnet-rpc.monad.xyz` (or fallback public RPC).
     - Chain ID: `143`.
  2. Implement Burner/Session Wallet:
     - Generate a local Ethereum private key using `EthPrivateKey.createRandom(Random.secure())` if not found in `SharedPreferences`.
     - Expose `walletAddress` (`EthereumAddress`).
     - Display wallet pill/badge on the profile or map HUD.
  3. Prepare contract interaction stubs matching teammate's contracts:
     - `claimTerritory(uint256 territoryId, int256 lat, int256 lng, uint256 area)`
     - `getTracktBalance(address user)`
  4. Wire `RunTrackerController.stopRun()`:
     - When a real run or simulation completes, trigger `MonadService.claimTerritory()`.

### Priority P1: Seeded Global Rival Territories
* **Goal:** When a judge opens the app anywhere in the world (SF, NYC, London), the map must already look like a vibrant, active battlefield with rival territories ready to be attacked and stolen.
* **Tasks**:
  - Add mock competitor territories in `lib/services/territory_service.dart` for key coordinates:
    - New York (Central Park, Brooklyn): 15-20 territories.
    - San Francisco (Presidio, Mission, SoMa): 15-20 territories.
    - London (Hyde Park, Westminster): 15-20 territories.
  - Assign distinct rival colors (`#EF4444` Red, `#10B981` Green, `#F59E0B` Amber, `#8B5CF6` Purple) and competitor usernames (e.g., `@MonadRunner`, `@SatoshiSprint`, `@GmonadAthlete`).

### Priority P2: Upgrade In-Game Power-Up Shop
* **File to Update:** `lib/views/store/store_view.dart`
* **Problem:** Currently displays a generic "Coming Soon" card.
* **Solution**: Replace with a gamified Power-Up Shop where users spend earned `$TRACKT` tokens:
  1. **🛡️ Territory Shield (24h)**: Protects user territories from rival theft for 24 hours (Cost: 250 $TRACKT).
  2. **⚡ Speed Multiplier (1 hr)**: Doubles token rewards earned during high-cadence runs (Cost: 150 $TRACKT).
  3. **🎨 Custom Flag / Banner**: Custom color and crest for conquered territories (Cost: 500 $TRACKT).

### Priority P3: Anti-Cheat "Proof of Physical Movement"
* **Tasks**:
  - Velocity filter in `RunTrackerController`: reject GPS updates with speed $> 25\text{ km/h}$ (eliminates vehicle driving and teleportation hacks).
  - Emphasize "Proof of Physical Work" in documentation and presentation.

---

## 8. Development Rules & Quality Standards

1. **Always Work on Branch `monad`**:
   - Check with `git branch --show-current` before starting.
   - Commit often with conventional commit messages (`feat:`, `fix:`, `test:`, `docs:`).
2. **Never Commit Secrets**:
   - Never commit `android/app/google-services.json` or `.env` files containing live private keys or tokens.
   - Always verify with `git status` before pushing.
3. **Keep Tests Green**:
   - Run `flutter test` before pushing to ensure all 13+ tests pass.
   - Run `flutter analyze | grep "error •"` to ensure zero compile errors.
4. **Rich Visual Aesthetics**:
   - Monad palette: Deep background `#141124`, Accent Purple `#8338EC`, Neon Cyan `#00F5D4`, Gold `#FFBE0B`.
   - Use rounded glassmorphic cards, smooth animations, and clean typographic hierarchy.

---

*Document created on October 10, 2026 for the Trackt Core Team.*

---

## 9. Progress Addendum — October 11, 2026 (Mobile Web3 + Features Session)

All mobile-side roadmap priorities P0–P3 are implemented, unit/widget-tested, and committed on `monad`. Test suite: **40/40 passing**, `flutter analyze` **0 errors**.

- **P0 — Monad Web3 client** (`lib/services/monad_service.dart`): `web3dart` client to Monad Testnet (`143`), on-device burner wallet persisted in `SharedPreferences`, `claimTerritoryOnChain()` + `getTracktTokenBalance()`, wired into `RunTrackerController` run completion. Degrades to a local settlement proof until contracts are deployed. Config via `MONAD_*` env vars (see README).
- **P1 — Seeded rivals** (`lib/services/seed_territory_service.dart`): ~48 colorful rival territories across NYC, SF, London, merged into the map on every refresh (works offline).
- **P2 — Power-Up Shop** (`lib/services/power_up_service.dart`, `lib/views/store/store_view.dart`): Shield (250), Speed Multiplier (150), Custom Flag (500). Purchases persist; `$TRACKT` spent via `UserPreferencesService.spendUserCoins()`.
- **P3 — Anti-cheat**: `RunTrackerController.isImplausibleRunningSpeed()` rejects > 25 km/h GPS updates (skipped during simulation).
- **Economy loop**: completing a run/sim awards 100 `$TRACKT` (×2 while Speed Multiplier active). Wallet HUD pill on the map shows address + balance.
- **Hygiene**: removed 4 zero-byte ghost stub files; made `DatabaseService` resilient when Supabase isn't initialized.

**Known gaps / next:** Shield has no effect yet (conquest resolution is still stubbed, pending teammate contracts); deployed contract addresses TBD; Mapbox visual polish and submission video outstanding. Manual on-device checks are tracked in [TESTING_NOTES.md](TESTING_NOTES.md).

## 10. Integration handoff - October 12, 2026

Current app/network configuration uses Monad Testnet chain **10143**, not the
older `143` references above. Before extending the sponsor integrations, the
existing Flutter baseline was verified: **48 tests pass**, no analyzer compile
errors, and 1,011 existing lint/info/warning findings.

- **Envio:** the deployable `indexer/` is published on `monad`; strict TypeScript
  and four real-handler tests pass. Deploy it in Envio Cloud with root
  `indexer`, branch `monad`, and config `config.yaml`. The user deployed it and
  saved its public GraphQL endpoint; the actual leaderboard query returns
  HTTP 200 with two real players and two claim records. Ownership/area totals
  agree with the indexed territories; both claim events match confirmed
  Monad receipts fetched through Alchemy. Indexer metadata shows historical
  sync in progress, not yet caught up to head.
  See [indexer/README.md](indexer/README.md).
- **AI removal (October 13):** KIMI has been removed from the mobile client,
  victory UI, tests and deployable backend source. The deployed recap function
  was deleted (HTTP 404 verified), and its server secrets/local settings were
  removed. It is not a target bounty or a claimed feature. Previously applied
  isolated quota migration/table history remains inert; no runtime calls it.
  Do not reintroduce paid AI dependencies or deployment steps for submission.
- **Privy:** the SDK, email OTP UI, wallet restoration, source selection,
  account-bound signing and burner preservation are implemented and tested.
  App ID and the mobile Client ID are now saved locally. The mobile client
  must allow `com.devanuragt.starlink_outpost_app` and URL scheme `trackt`;
  Email OTP must be enabled before wallet login can be demonstrated; the
  user was given the Login methods dashboard link.
  The installed SDK actually requires Android API 28+ and iOS 17+; native
  targets and the `trackt` callback scheme have been updated accordingly.
  Existing burner credentials now survive sign-out; funds never move
  automatically. RPC/SDK tests verify the exact claim ABI and source-switching
  races; these tests do not replace a live funded Privy transaction.
- **Alchemy:** the user enabled Monad Testnet. The endpoint now returns
  chain 10143, and the development app selects it explicitly using
  `MONAD_RPC_PROVIDER=alchemy`. The public RPC remains an explicit option.

After AI removal, the Flutter suite has **69 passing tests** and Envio has
four handler tests; a retained small-screen victory test covers the cleaned UI.
The Android debug
APK builds successfully; its contents were checked for server secrets.
Native build fixes include excluding duplicated OSGi manifest metadata and
restoring Flutter's standard Gradle build output directory.
Touched wallet, victory and leaderboard UI uses the shared `AppColors`
palette with flat controls, neutral borders and no glow/gradient decorations.
The release APK (arm64, about 93 MB) also builds and launches on a fresh
headless Android test device without crash markers. Both debug and release
APK contents include the saved public settings and exclude server secrets.
Historical Envio sync was diagnosed against the real public RPC: log ranges
above 100 blocks return HTTP 413. The configuration now caps batches at 100
to avoid repeated oversized requests and retry backoff.

The connected Android device was no longer available by the end of this
setup check. Real wallet login, funding and live claims still need device
verification; configuration alone does not establish bounty eligibility.

## 11. Sponsor submission criteria - October 13, 2026

The supplied official portal pages list **October 14, 2026 at 09:29
GMT+5:30** for Envio, Alchemy and Privy. This supersedes the older dates for
these sponsor bounties; verify the overall project deadline separately.

- **Envio:** $1,000 USD, one prize. A deployed Envio pipeline, public
  configuration/schema/handlers, useful data-consuming app and short demo or
  live link are required. Non-trivial derived aggregates are relevant to the
  depth criterion. The live leaderboard is verified, but fresh claim-to-app
  footage and completed historical sync are still outstanding.
- **Alchemy:** $1,000 in Alchemy credits, not cash. At least one meaningful
  supported service/tool in a functional Monad project is sufficient; no
  wallet replacement or extra sponsor features are mandatory. Demonstrate
  the actual RPC reads/network checks/gas estimation. Privy broadcasting
  must not be mislabeled as an Alchemy broadcast.
- **Privy:** $5,000 USD, one prize. Login-only is explicitly ineligible.
  Embedded-wallet creation/restoration and a funded registry transaction are
  our beyond-authentication functionality; capture it from the Privy address.
  Multiple meaningful Privy features are a bonus, not a mandatory checklist.

All three forms request an integration description and offer an optional
video of up to two minutes. Draft descriptions and verified receipt links
are in README; the video and device evidence are not marked complete.

## 12. Professional club UI - October 13, 2026

The clubs list and inside-club overview now use Trackt's shared flat
neutral/indigo palette, compact initial avatars, clear typography and
consistent panels/buttons. The create/join forms follow the same design.
All four screens scroll correctly on small displays, large text and keyboards.

Club behavior is preserved with tightly related corrections: one initial
membership load instead of duplicate requests, refresh after returning from
club/form routes, invite-code copying with confirmation, actual creator-ID
Founder badges instead of fake list-position ranks, matching-code join
navigation, and error/retry states instead of fabricated empty rosters.
Leave confirmation remains available and a server-rejected leave never
dismisses the club or claims success. Async completions check mounted state.

Validation: **89 Flutter tests pass**, including **20 club-specific widget and
service tests**. Club UI/new tests analyze cleanly; full analysis has zero
compile errors and 1,000 existing findings. The rebuilt arm64 release was
installed as an update on the connected phone. The real clubs list and
member roster were inspected with no app crash or overflow markers, and
no clubs or memberships were created/deleted during device validation.

## 13. Connected-phone proof and demo rehearsal - October 13, 2026

One burner-backed Judge Demo claim was filmed and its successful receipt
verified through Alchemy: transaction
`0x43d33d544a37b923460be8c13f22d3ec7eca7ee8c7d4e267c1aed0cb820d5e75`,
block **70602621**, preserved burner sender and TerritoryRegistry target.
The actual wallet token balance increased from 100 to 200. That new hash
was still pending in Envio during the recording check.

Privy OTP dispatch works, a session is connected, and the selected wallet is
`0xa0e1F726D2f01f7e325418E05ac4C5820990c71c`, but it has no Testnet MON.
No unauthorized wallet-to-wallet funding was performed. A funded Privy
transaction is still an external proof gap, not a completed test.

Actual phone testing found/fixed stale balances after broadcast and overlapping
wallet navigation. Receipts now trigger balance refresh; manual refresh and
explicit confirmation errors are available. Wallet-to-connect/standings
navigation uses the correct modal route and was physically rechecked.
Current test suite: **94 passing tests**, including five new regressions.

`build/demo/trackt-demo-rehearsal.mp4` is a validated **97-second**, silent,
captioned phone rehearsal. It explicitly labels burner use, simulated GPS,
older indexed data and the missing Privy/new-claim Envio proof. It is not
advertised as a completed sponsor submission video.

## 14. Funded Privy transaction verified - October 13, 2026

After the user added 5 Testnet MON, the connected Privy wallet completed a
real registry claim on the phone. Confirmed successful transaction:
`0x6ae6d7b3497c35943f7103f8140b58e7ec71d07e342987b9e1982b2df5f1104d`,
block **70607206**, actual sender
`0xa0e1f726d2f01f7e325418e05ac4c5820990c71c`, deployed registry target,
matching event owner and **25,463 m2**. Alchemy independently verified the
receipt; the actual Privy balance became **100 TRACKT** and **4.969141838 MON**.
No burner fallback or additional wallet-to-wallet transfer was performed.

The updated `build/demo/trackt-privy-demo.mp4` is **under two minutes**, silent with
captions, and demonstrates the funded gameplay transaction beyond login.
This resolves the earlier Privy funding/proof gap. Envio's exact-hash query
still did not contain this new transaction during verification; the video
labels the older real standings and pending backfill honestly.
