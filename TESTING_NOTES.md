# 🧪 Trackt — Manual Test Notes (for Anurag)

Autonomous session log. Each feature below was implemented, unit/widget-tested, and committed on branch `monad`. The items here need **manual / on-device checks** that automated tests can't cover (visuals, map rendering, real RPC, gestures).

> Automated status is kept green throughout: `flutter test` + `flutter analyze | grep "error •"` run after every feature.

---

## Current sponsor evidence checklist - October 13, 2026

This section supersedes older settlement/UI descriptions below. Use the new
APK as an update; do not uninstall or reset preferences to test onboarding.
Touched UI uses the shared flat neutral/indigo theme, not old neon/glow styles.

- [ ] **Privy beyond login:** use your existing Trackt account; wallet pill ->
  Connect Privy wallet -> send/verify the email OTP. Confirm the title reads
  Privy Embedded Wallet and copy the selected address. OTP itself requires no
  MON, but it is not sufficient for the bounty.
- [ ] **Funded Privy claim:** send Testnet MON to that address, run a Judge
  simulation, and open the broadcast hash on the explorer. Verify receipt
  status is success, target is TerritoryRegistry and sender is the selected
  Privy address. A local proof cannot substitute for this.
- [ ] **Wallet persistence:** relaunch and confirm the same Privy address;
  explicitly choose the preserved burner and check its address/funds remain.
  An unverified Privy session must not silently sign with the burner.
- [ ] **Alchemy:** with `MONAD_RPC_PROVIDER=alchemy`, refresh MON and token
  balances and run the funded claim. Capture corresponding app activity in
  Alchemy's dashboard without exposing the API key. Alchemy supplies reads,
  network validation and Privy gas estimation; Privy's provider handles its
  own transaction signing/broadcast.
- [ ] **Envio:** confirm historical indexing has caught up, then record a new
  claim arriving through the hosted GraphQL API and in wallet pill -> On-chain
  standings after refresh. Show the runner's territory count and owned area.
  Current live evidence already contains two real indexed claims/players
  whose events and aggregates were verified against Monad receipts.
- [ ] **Victory UI:** metrics and actions are scrollable on a small screen;
  there is no AI recap/loading/error card. A local proof is labeled unverified
  and has no explorer link; a broadcast is not called receipt-confirmed.
- [ ] **Submission:** use README's sponsor descriptions, attach public
  repository/deployed contract details and record the two-minute walkthrough.
  Submit only observed behavior; do not claim test mocks or seeded rivals
  are live indexed activity.

Automated removal baseline: **69 Flutter tests**, four Envio handler tests,
zero analyzer compile errors (the existing lint backlog is unchanged).

## Club UI update - October 13, 2026

The clubs list, club overview and create/join forms now share the neutral dark
`AppColors` theme, a single indigo action color, flat panels and consistent
spacing/type. Member entries are a roster, not a ranked leaderboard; Founder
is determined by the club's creator ID rather than the first row.

- [ ] Open Club: check compact cards, create/join controls and copyable invite
  codes. Pull down to refresh; return from a club/form to refresh memberships.
- [ ] Open a club: check the overview dates/member count, invite panel and
  roster. Confirm the Founder badge belongs to the actual creator.
- [ ] Create/join: check the keyboard does not hide the submit button.
  Name validation remains 3-50 characters; invite codes remain 8 characters
  and case-insensitive. Joining should open the matching club, not the last
  item in the returned list.
- [ ] Leave: Cancel must preserve membership. Confirmed leave returns to the
  updated list; server failure must not dismiss the club or claim success.
- [ ] Small screen/large text: all content scrolls, labels wrap and controls
  remain usable. Load failures show retry, not a fabricated empty roster.

---

## P0 — MonadService (done earlier, committed `24b895e`)
- [ ] Launch app on device/emulator. Confirm no boot crash from `MonadService().init()`.
- [ ] Check logs for `⛓️ MonadService ready. Wallet: 0x…` — wallet address generated once, same on relaunch (persisted).
- [ ] Complete a Judge Sim run → logs show `⛓️ Monad territory claim settled: 0x…` (local proof until contracts deployed).

## Live phone testing and rehearsal - October 13, 2026

- Privy OTP dispatch succeeded. The connected embedded wallet is
  `0xa0e1F726D2f01f7e325418E05ac4C5820990c71c`; the session and source selection
  survived the update. It has **zero Testnet MON**. No funds were transferred
  from the preserved burner without authorization, and no successful Privy
  transaction is claimed.
- One explicitly burner-backed Judge Demo run completed on the real phone.
  Alchemy independently confirmed successful transaction
  [`0x43d33d544a37b923460be8c13f22d3ec7eca7ee8c7d4e267c1aed0cb820d5e75`](https://testnet.monadexplorer.com/tx/0x43d33d544a37b923460be8c13f22d3ec7eca7ee8c7d4e267c1aed0cb820d5e75)
  at block **70602621**, from the preserved burner to TerritoryRegistry.
  The burner's actual ERC-20 balance increased from 100 to 200. The victory
  dialog's variable in-game reward is separate from that ERC-20 mint.
- Live testing exposed stale wallet balances after broadcasting, plus
  overlapping wallet/connect/standings sheets. Balance refresh now follows a
  successful receipt, with a manual refresh button and explicit reverted/
  unavailable receipt errors. Modal navigation closes the correct route
  before opening another. Both fixes were rechecked on the phone.
- The exact new transaction hash was not yet in Envio at the recording check;
  existing real indexed standings remained available. Do not pass off those
  older entries as this new claim.
- Generated `build/demo/trackt-demo-rehearsal.mp4`: **97 seconds**, 720x1600
  H.264 at 30fps, silent with readable captions. The recording and phone
  snapshots are labeled, including the burner source, pending indexing and
  incomplete Privy proof. It is a rehearsal, not a finished sponsor demo.

Five additional receipt/navigation regressions bring the full Flutter suite
to **94 passing tests**. The corrected release APK was rebuilt and installed
without uninstalling or clearing data. Privy is left selected for the funded
follow-up; the burner remains preserved.

---
<!-- APPEND-NEW-FEATURES-BELOW -->

## P1 — Seeded Global Rival Territories
`SeedTerritoryService` + `TerritoryService._mergeSeededRivals()`. 48 rival territories (16× NYC, SF, London), 5 rival colors + `@`usernames, organic polygons.
- [ ] Open map, pan to **Central Park NYC** (40.7812, -73.9665) → cluster of colored rival polygons visible.
- [ ] Pan to **Hyde Park London** (51.5048, -0.1650) and **Presidio SF** (37.7989, -122.4662) → rivals there too.
- [ ] Confirm rival colors render distinct (red/green/amber/purple/cyan), not all one color.
- [ ] Confirm rivals are NOT owned by you (owner shows `@MonadRunner` etc.) — tap a polygon if info popup exists.
- [ ] Run a Judge Sim in a seeded city → your territory draws on top of / beside rivals without crash.
- [ ] Offline/airplane mode: rivals still appear (seeded locally, no network needed).

## Victory dialog → real Monad settlement
Sim victory now uses `MonadService` tx + explorer link.
- [ ] Finish a Judge Sim → victory dialog tx hash matches the one in logs (`claim settled: 0x…`).
- [ ] Tap **View on Monad Explorer** → opens `testnet.monadexplorer.com/tx/…` in browser (link valid once contracts deployed; local-proof hash until then).
- [ ] Status line reads "Broadcast on-chain" only when a real tx went out; otherwise "Sub-second finality verified".
- [ ] Copy-tx button still copies hash.

## Monad wallet HUD pill
`MonadWalletPill` on map, below Judge Demo button (top-left).
- [ ] Pill shows short address `0x12…aB9c` + `$TRACKT` balance.
- [ ] Tap pill → bottom sheet with full address (copy button), MON gas balance, $TRACKT, "View on Monad Explorer" (address page).
- [ ] MON balance populates once wallet funded on testnet (0.00000 until then — expected).
- [ ] Pill doesn't overlap map zoom controls (right side) or Judge button awkwardly — eyeball spacing on a real screen.

## P2 — Power-Up Shop
`store_view.dart` rebuilt; `PowerUpService` economy. Shield (250), Speed (150), Flag (500, permanent).
- [ ] Open Store tab → 3 power-up cards + $TRACKT balance chip in app bar (not "Coming Soon").
- [ ] With enough coins: Buy → success snackbar, balance drops, card shows ACTIVE / time-left badge (Shield/Speed) or OWNED (Flag).
- [ ] With too few coins: Buy → "Not enough $TRACKT" red snackbar, balance unchanged.
- [ ] Flag: after buying, button disables to "Owned", can't rebuy.
- [ ] Kill + relaunch app → purchased power-ups still active (persisted).
- [ ] NOTE / known gap: purchases are tracked but gameplay **effects aren't enforced yet** (shield doesn't yet block theft, speed doesn't yet 2× rewards). Economy + UI only for now — flag if you want effects wired next.

## P3 — Anti-cheat "Proof of Physical Movement"
Velocity filter in `RunTrackerController._onLocationUpdate`: GPS updates implying > 25 km/h rejected (not counted toward distance). `rejectedGpsPoints` observable tracks count. Skipped during simulation.
- [ ] Real outdoor run: normal pace tracked fine, no false rejects (watch logs for `🚫 Anti-cheat` — should be rare/none while running).
- [ ] In a car / spoofed GPS: updates rejected, distance doesn't balloon.
- [ ] Judge Sim still completes normally (filter bypassed during sim) — turbo/demo/natural all finish.
- [ ] (Pitch) `rejectedGpsPoints` can be surfaced in UI as "spoof attempts blocked" if you want a visible anti-cheat stat.

## Reward loop (run → $TRACKT → shop) + Speed Multiplier effect
Completing a run/sim now awards 100 $TRACKT (×2 while Speed Multiplier active). Closes the economy loop.
- [ ] Finish a Judge Sim → wallet pill / profile `$TRACKT` balance goes **up by 100**.
- [ ] Buy **Speed Multiplier** in Store, then finish another sim → balance goes up by **200** (2×). Victory dialog "Tokens Earned" shows +200.
- [ ] After Speed Multiplier expires (1h) → back to +100.
- [ ] Earn enough from a few sims → afford Shield/Flag without hand-editing coins.
- [ ] NOTE: this partially wires the earlier "effects not enforced" gap — Speed Multiplier now has a real effect; Shield still pending conquest logic.

## Smart contracts (Foundry) — `contracts/`
`RunRewardToken.sol` (ERC-20 $TRACKT) + `TerritoryRegistry.sol` (claim/conquest/reward). 32 Foundry tests, all passing.
- [ ] `cd contracts && forge test -vvv` → 32 pass (needs Foundry: `brew install foundry`).
- [ ] Deploy to Monad Testnet: `PRIVATE_KEY=0x… forge script script/Deploy.s.sol:Deploy --rpc-url https://testnet-rpc.monad.xyz --broadcast` (needs a funded testnet key).
- [ ] After deploy: put addresses in `.env.<env>` (`MONAD_TERRITORY_CONTRACT`, `MONAD_TOKEN_CONTRACT`); then a real run broadcasts an on-chain `claimTerritory` and the victory dialog's "View on Monad Explorer" resolves to a live tx.
- [ ] Verify contract ABI matches `monad_service.dart` (it does: `claimTerritory(uint256,int256,int256,uint256)`, ERC-20 `balanceOf`).
- [ ] (If coordinating with teammate) reconcile this registry with their design before mainnet — interface already matches the client.

## Real-run victory dialog
Finishing a real (non-sim) run now shows the same Monad victory dialog (badge reads "MONAD TESTNET"), after awaiting the on-chain claim.
- [ ] Do a real/outdoor run that closes a loop → victory dialog appears with area, distance, +$TRACKT, and tx (explorer link if contracts deployed).
- [ ] "View Territory on Map" button returns to the map (no double-navigation — auto-nav is suppressed while the dialog is up).
- [ ] Balance increases by the awarded $TRACKT.

## Scan + UX pass (navigation, theme, cleanup)
From a full app scan. Functional fixes + cohesion.
- [ ] **Forgot-password now works**: Sign In → "Forgot Password?" → reset flow no longer hits "Page not found" (routes `/reset-password-request` + `/reset-password-verify` registered).
- [ ] **Shop is in the bottom nav** now (World / Club / Quests / Shop / Profile) — no longer buried only in Profile. Tap Shop → Power-Up Shop.
- [ ] **Consistent dark Monad theme** app-wide (bg #141124, cyan-accent nav). Check all 5 tabs look cohesive, text readable, nothing washed-out/invisible on the dark background.
- [ ] Quests / Profile / Club backgrounds match the Monad theme (no leftover grey/black87 panels clashing).
- [ ] Removed dead screens (AddPasswordView, NotificationsSection) — nothing should navigate to them; confirm no broken links.
- [ ] Known-minor (not blocking): Daily Quests is one focused challenge card; `coins_earned_animation.dart` exists but is unwired; conquest/Shield still backend-scoped.

## UI/UX polish pass (modern simplistic look)
Global theme + per-screen Monad palette. Visual only — verify on device.
- [ ] Buttons across the app look consistent: rounded (14), purple primary / cyan outline, ~48px tall, no harsh elevation. Check Start Run (map), Shop buy buttons, auth sign-in/up, dialogs.
- [ ] Text fields (auth, username, create club) are filled dark rounded with a purple focus ring.
- [ ] Cards, bottom sheets, and dialogs share rounded corners + the dark surface (#1C1733 / #181528).
- [ ] Map HUD: Start Run button is purple with a play icon; zoom/recenter controls are dark-glass (recenter = cyan); Judge Demo + wallet pills consistent.
- [ ] Live run stats card uses cyan/amber/purple metrics (not blue/green/orange).
- [ ] No leftover bright-blue Material accents on primary surfaces (swapped to Monad purple/cyan). Semantic red (stop) / green (go) on run controls intentionally kept.
- [ ] Nothing clipped or overflowing at phone width after the spacing/compactness changes.







