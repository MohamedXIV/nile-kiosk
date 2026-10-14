# PLAY C6 — Repeat Customer Experience Without a Reputation Bar

**Status: VERIFIED / MERGED** — [PR #54](https://github.com/MohamedXIV/nile-kiosk/pull/54), squash `f68f92986143a3ed6a63029f75d1c908565e59e7`. [Exact-head Godot P0–P7/C0–C6/D001/V001 PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38518204470), [real Chromium C6 + C5/C4/C3/C1/P7/D001 PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38518204515), GitGuardian PASS. Native tests prove paid service improves future intent, abandonment suppresses repeat intent, cancelled/other-venue remain neutral, and replay/long-vs-split world time are valid. Browser proves a missed customer does not place another order and survives two hard reloads.

[Issue #53](https://github.com/MohamedXIV/nile-kiosk/issues/53). A completed or missed service now influences **that specific NPC's future decision to visit the same venue**, if and only if a reviewed demand policy opts in. It does not create an arbitrary satisfaction, popularity or player reputation meter.

## Canonical boundary

`scripts/core/customer_experience.gd` is a **pure query** of P4's already authoritative `orders` and `payment_status`. It stores no mutable sentiment, counters, tick loops or new save fields. For a customer + venue + scheduled instant, it selects the most recent prior meaningful closure strictly **before** the firing minute, with a stable order-ID tie-break. Only these outcomes matter:

- `delivered` **and** `payment_status=settled`: actual P3/P4 delivery **plus** P5 priced ledger settlement, never a mere quote or prepared item.
- `abandoned`: customer left or deadline expired without a completed order.
- `cancelled`, `delivered` without payment settlement, and no history: **neutral**. This is a technical signal and not an assertion of the customer's feelings.

`service.demand.configure` accepts its original C4 nine fields and C5 optional `social_rule` unchanged. The additional optional `experience_rule` has exactly two nonnegative, bounded integer-basis-point authoring fields: `settled_bonus_bp` (0–10,000) and `abandoned_penalty_bp` (0–10,000). An authored positive or negative adjustment is applied *after* any optional C5 customer's-own P2 fact/trust signal and clamped to 0–10,000. The unchanged seeded C4 choice then determines whether that NPC visits. History is scoped to **the same NPC at the same venue** and the actual time: no cross-customer/venue reputation contagion. The unit is one most recent meaningful service, not an infinitely accumulating grinder score.

An opted-in policy records an `experience_evidence` struct in its **canonical `time.advanced` effect**, naming the last eligible order ID/outcome and effective adjustment/chance. Replay recomputes the entire scheduled world from old commands/receipts and rejects tampered evidence. Existing C4/C5 demand events without `experience_rule` get **no new outcome fields**, preserving v8 save compatibility and prior deterministic replay.

## Acceptance

`tests/test_play_c6.gd` exercises real C0 world bootstrapping and P1–P5 boundaries: a pre-existing automatically offered order expires while the player is on the roof, and the customer's second attempt is suppressed; one large time.advance and twenty 1-minute advances agree. In a separate session Reda receives real P3 multi-step tea, P4 accepts/delivers it and P5 quotes/settles the ledger, after which even a 0% base-chance policy can generate the next offer from the authored positive adjustment. Cancelled visits stay neutral, and an abandoned order at a **different venue** does not alter the next kiosk visit. Further tests check malformed rules, full disk restore, same schema, and forged order/evidence rejection.

`content/service/qa_repeat_customer.v1.json` is intentionally **QA-only**: first Reda kiosk visit at minute 5, 5-minute wait, repeat 12-minute interval, 100% base intent, -100% authored penalty for abandonment. Those are **testing numbers, not game tuning**. The independent `scenes/qa_repeat_customer.tscn` uses its own saved-world slot and the same world-owning Godot QA scene as C1–C5. `tools/web-play-c6-smoke.mjs` drives *actual Chromium and Godot Web*: offer at minute 5 without pressing O, missed customer at minute 10, next attempt at minute 17 with no repeated order, canonical evidence and digest preserved across two real hard reloads. The pinned native + Web regression jobs remain shared with P0–P7/C0–C5/D001/V001.

## What is still not claimed

The rule does **not** infer feelings, personality, narrative motivations or why a customer departed. It does not add auto-restocking, final recipe balance, long-run memory decay, social gossip about a kiosk, complex order preferences, UI sentiment bars or the released game scene. Genuine character writing, customer reactions and era-appropriate content are separate editorial/gameplay decisions. Do **not** treat the 100% QA test modifiers as canonical. [V001 PR #20](https://github.com/MohamedXIV/nile-kiosk/pull/20) is still under independent visual approval, untouched.
