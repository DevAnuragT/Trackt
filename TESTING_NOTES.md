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

