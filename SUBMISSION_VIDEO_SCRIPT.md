# 🎬 Trackt — 2.5-Minute Demo Video Walkthrough Script

**Target:** Monad Metropolis Hackathon submission (Consumer Products & Payments / Social).
**Runtime:** ~2 min 30 sec. **Format:** screen recording of the mobile app + voiceover, cut to a browser for the on-chain proof.

> Tip: record the Judge Simulation Mode run in **🎬 Demo (~14s)** speed so the loop closure reads clearly on camera.

---

## 0:00 – 0:25 — The Hook & The Problem

**On screen:** Cold open on the Trackt map (dark, Monad-purple UI) with rival territories already dotting the city.

**Voiceover:**
> "Fitness apps are lonely. You run, a line appears on a map, and… that's it. Trackt turns every run into a real-world territory war. Lace up, close a loop around a city block, and that land becomes *yours* — minted on-chain, defended against rivals, and worth something."

---

## 0:25 – 0:50 — Why Monad?

**On screen:** Slowly pan the map over the seeded rival territories (New York, San Francisco, London). Briefly show the wallet pill on the HUD.

**Voiceover:**
> "A territory game needs blockchain speed a runner won't notice. On most chains, 15-to-60-second blocks and dollar gas fees kill mobile gameplay. Monad gives us 10,000 TPS and sub-800-millisecond finality, so a territory claim settles for a fraction of a cent before you've taken your next stride. And with an on-device burner wallet, there are no MetaMask popups mid-run — Web3 goes invisible."

---

## 0:50 – 1:40 — Live Mobile Demo

**On screen:**
1. Tap the **⚡ Judge Demo Lab** pill.
2. Pick **Central Park, NYC** and **🎬 Demo** speed; tap launch.
3. Watch the simulated runner trace an organic loop on Mapbox and close it.
4. The territory fills in with the player's color beside the colored rivals.

**Voiceover:**
> "Judges don't need running shoes. Trackt ships a one-tap simulator. I'll pick Central Park and send a runner. Watch the GPS trail curve into a closed loop — and the instant it closes, the enclosed land is claimed and painted onto the map, right next to rival runners' territory. Behind the scenes, an anti-cheat filter rejects any movement faster than a human can run, so this is Proof of Physical Movement, not GPS spoofing."

---

## 1:40 – 2:15 — On-Chain Verification

**On screen:**
1. The victory dialog appears: area claimed, loop distance, **+100 $TRACKT**, and the Monad Testnet settlement card with the transaction hash.
2. Tap **View on Monad Explorer** → cut to the browser showing the transaction on the Monad Testnet explorer.
3. Cut to the **Shop** tab: spend $TRACKT on a **Speed Multiplier** or **Territory Shield**.

**Voiceover:**
> "The moment the loop closed, the claim was signed by the on-device wallet and broadcast to Monad Testnet. Here's the transaction on the explorer — real on-chain state, settled in well under a second. The run also paid out $TRACKT, our reward token, which I can spend right now in the shop: a Speed Multiplier to double my next payout, or a Territory Shield to lock my land against rivals for 24 hours."

---

## 2:15 – 2:30 — Vision & Roadmap

**On screen:** Return to the map, zoom out across the three seeded cities.

**Voiceover:**
> "This is day one. Next: Monad mainnet, guild-versus-guild territory wars, and sponsor-branded zones that turn real neighborhoods into contested ground. Trackt — run, claim, conquer. Powered by Monad."

---

## Shot checklist
- [ ] Fresh install so the burner wallet is created on camera (optional, shows zero-friction onboarding).
- [ ] Seeded rivals visible before the run (open on NYC / SF / London).
- [ ] Loop closure + territory fill captured clearly.
- [ ] Victory dialog tx hash readable; explorer page loads the real transaction.
  - Requires contracts **deployed** and `MONAD_TERRITORY_CONTRACT` set — otherwise the hash is a local proof. Deploy first (see `contracts/README.md`).
- [ ] Shop purchase shown changing the $TRACKT balance.
- [ ] Keep total under 2:30.
