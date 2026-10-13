# PLAY C5 — Socially Conditioned NPC Demand

**Status: VERIFIED / MERGED** — [PR #52](https://github.com/MohamedXIV/nile-kiosk/pull/52), squash `2559f20668cf9ebaab78300b6f28ada580365b9e`. [Exact-head Godot P0–P7/C0–C5/D001/V001 PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38470973474), [real Chromium PLAY_C5_CHROMIUM_PASS plus C4/C3/C1/P7/D001 PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38470973284), GitGuardian PASS.

[Issue #51](https://github.com/MohamedXIV/nile-kiosk/issues/51). Following PLAY C4, customer demand now supports a **bounded, optional, authored social signal** derived from the actual P2 state of the **customer** at the scheduled world minute. This is a domain rule, not a new scene-owned demand simulator or inferred affection stat.

## Immutable and backward-compatible authoring

The existing `service.demand.configure` P4 command still accepts its exact nine-field C4 payload. New authors may include one additional **`social_rule`** dictionary with exactly these four keys:

```json
{"fact_id":"weather:nile","fact_bonus_bp":5000,"trusted_peer_id":"amina","trust_bonus_bp":5000}
```

The fact and peer NPC must already be registered by P2; a customer may not target themselves as their own trusted peer. Bonuses are non-negative bounded integers in basis points (0–10,000). Rule structure is strict and cannot reference invented facts/peers, player-only friendship stats, a user-writable file or arbitrary evaluation code. Existing C4 policies and all their prior event effects and whole-world v8 snapshots **remain byte-compatible**; no migration or new schema field is necessary. A versioned C0 bundle can now explicitly declare `social.familiarity.set` by the same constrained `system:director` actor used for NPC/venue authoring. This is an **authored initial relationship**, not dialogue content masquerading as truth.

At the **P1 time.advance** firing for this plan, P4 evaluates whether the customer actually knows the authored fact (`society.knowledge[npc_id][fact_id]`) and whether that customer considers a second NPC **trusted** (`society.familiarity[npc_id][trusted_peer_id]`). These are strictly NPC-owned P2 records; **the player's own knowledge/familiarity is not consulted**, and the player need not be nearby. The effective chance is `min(10000, base_chance + applicable bonuses)`, followed by the same seeded deterministic `seed:plan_id:occurrence` roll already used in C4. A 0% base chance may become 100% after a real offscreen social event without manually issuing an order.

A C5 rule appends a bounded `social_evidence` triple—`fact_known`, `peer_trusted`, `chance_bp`—to that order attempt's P4 time-advance result. Save/replay recomputes the evidence at the **same world event** and rejects forged values. C4 attempts without a social rule do **not** get this extra result field: replay of old events is unchanged. Existing queue, customer-presence, station work, deadline and ledger behavior still comes from P2/P3/P4/P5 and is not weakened.

## QA-only proof and honest limits

`content/world/qa_nile_kiosk_social.v1.json` is an isolated C0 fixture differing from the original QA world by an explicitly authored Reda→Amina trusted relation. `content/service/qa_social_demand.v1.json` has **base 0% demand**, with a trusted-peer-only 100% boost, allowing deterministic counterfactual verification. `scenes/qa_social_kiosk.tscn` opts in to those data files and a separate Web save slot; the original C1/C2/C3/C4 scenes and unbalanced fixtures are unaffected.

`tests/test_play_c5.gd` checks malformed/forged social policy rejection, the **same seed** and recipe with/without NPC trust, genuine P2 offscreen `social.speak` from Amina to Reda conveying a fact (not heard by the rooftop player), a fact-only demand boost, big/small world-time chunks, expiring offers, signed event/probability evidence replay, full disk persistence and backward compatibility of a C4 policy. `tools/web-play-c5-smoke.mjs` opens the actual Godot Web QA scene in Chromium and confirms Reda independently makes an offer despite zero authored base chance and absent player, with real co-timed NPC presence, no remote fulfillment and exact canonical-world digest equality across two hard browser reloads.

**Still deferred:** true emergent desires/social preferences/longitudinal habits, advanced recipe choices, customer satisfaction after service, feedback loops for repeated good/bad food, extensive NPC casts, contextual prose, a production day loop, 2000–2005 economy balancing and V001 visual art approval. The social bonuses and names are strictly QA content and **not approved game tuning**. No live AI inference, mood meter or new player-dependent tick exists. [V001 PR #20](https://github.com/MohamedXIV/nile-kiosk/pull/20) remains separate.
