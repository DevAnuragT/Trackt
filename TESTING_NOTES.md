# 🧪 Trackt — Manual Test Notes (for Anurag)

Autonomous session log. Each feature below was implemented, unit/widget-tested, and committed on branch `monad`. The items here need **manual / on-device checks** that automated tests can't cover (visuals, map rendering, real RPC, gestures).

> Automated status is kept green throughout: `flutter test` + `flutter analyze | grep "error •"` run after every feature.

---

## P0 — MonadService (done earlier, committed `24b895e`)
- [ ] Launch app on device/emulator. Confirm no boot crash from `MonadService().init()`.
- [ ] Check logs for `⛓️ MonadService ready. Wallet: 0x…` — wallet address generated once, same on relaunch (persisted).
- [ ] Complete a Judge Sim run → logs show `⛓️ Monad territory claim settled: 0x…` (local proof until contracts deployed).

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









