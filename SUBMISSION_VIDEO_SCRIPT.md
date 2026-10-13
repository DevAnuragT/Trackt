# Trackt - Two-minute sponsor demo

**Targets:** Envio, Alchemy and Privy alongside the core Monad project.
**Runtime:** at most 2:00, suitable for the optional video field on each
sponsor form. A submission description is still required for each bounty.

The supplied sponsor pages display October 14, 2026 at 09:29 GMT+5:30.
Check the general project deadline separately.

## Before recording

- Install the latest APK as an update. Do not uninstall or clear wallet data.
- Sign into the existing Trackt account and connect its Privy embedded wallet.
  Enable Privy Email login and verify the OTP before the timed recording;
  login alone is not the sponsor functionality.
- Fund the selected Privy address with Monad Testnet MON.
- Confirm Alchemy is the app's configured provider, and its dashboard records
  app-driven balance/network/gas-estimation requests. Hide API keys.
- Confirm Envio's historical indexer has caught up to the current chain.
  Prepare the public GraphQL query and the on-chain standings screen.
- Make one rehearsal claim, then verify its successful receipt and sender.
  Do not record a local proof as a blockchain transaction.

## 0:00-0:15 - Hook

**Screen:** map, territory overlays and wallet pill; flat dark UI.

**Voiceover:**
> "Trackt turns running into territory conquest. Close a GPS loop, claim its
> area, and compete through verifiable ownership on Monad."

Label seeded rival polygons as demo content if they are shown. They are not
real Envio leaderboard entries or proof of live multiplayer activity.

## 0:15-0:35 - Privy wallet functionality

**Screen:** wallet details showing Privy Embedded Wallet, address and funded
MON balance. Briefly show relaunch persistence if captured in advance.

**Voiceover:**
> "Privy does more than login. This embedded wallet belongs to my account and
> signs the game's territory claims. My original burner is preserved, with
> no automatic movement of funds."

## 0:35-1:00 - Conquest

**Screen:** Judge Demo Lab, a preset circuit at Demo speed, closed loop and
filled territory. The simulation is explicitly labeled.

**Voiceover:**
> "Desk-bound judges can test the same claim flow with a simulated run. The
> runner closes a loop, the app calculates the territory, and the selected
> Privy wallet submits the registry call."

Do not describe simulated GPS as a real physical run. Client-side speed
filtering is not cryptographic proof that movement cannot be spoofed.

## 1:00-1:20 - Confirmed on-chain result

**Screen:** victory broadcast hash -> explorer receipt. Highlight success,
TerritoryRegistry target and sender matching the Privy address.

**Voiceover:**
> "Here is the successful Monad receipt from that Privy address to our deployed
> TerritoryRegistry. The app distinguishes a broadcast from an unverified
> local proof; the explorer confirms the actual state change."

Do not claim a measured finality time that has not been recorded. The local
shop coin balance and contract ERC-20 balance are distinct; do not conflate them.

## 1:20-1:45 - Envio data flowing into the app

**Screen:** hosted GraphQL entry for this transaction -> refresh On-chain
standings -> matching runner/count/area.

**Voiceover:**
> "Envio HyperIndex consumes the claim and conquest events. It derives current
> ownership and each runner's total area and territory count. These live
> standings come from the indexer, not from seeded map rivals or local proofs."

Wait for actual indexing. If the pipeline is delayed, show the elapsed time
or disclose an edit; never present an older transaction as the new claim.

## 1:45-2:00 - Alchemy and close

**Screen:** Alchemy request activity for the app's balance/network/gas reads,
then return to the map.

**Voiceover:**
> "Alchemy supplies Monad balance reads, network validation and gas estimation.
> Privy signs and broadcasts its wallet transaction, while Envio powers the
> standings. Run, claim, conquer."

Show meaningful app-driven requests rather than just an installed SDK or an
API key. Do not attribute Privy's broadcast to Alchemy without verifying that
provider route.

## Evidence gate

Only call the recording complete when it shows a successful Privy-sent
receipt, meaningful Alchemy activity and the matching indexed claim driving
the frontend. Missing credits, mocked tests or portal bounty selection are
not evidence of live functionality. No AI sponsor functionality is claimed.
