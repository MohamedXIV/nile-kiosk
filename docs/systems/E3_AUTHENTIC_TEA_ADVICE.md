# E3 current-scope COOK-03 — source-attributed tea advice

**Status:** implementation branch, NOT yet tested/merged/accepted. Owner scope freeze: [CURRENT_SCOPE_CLOSEOUT](../experience/CURRENT_SCOPE_CLOSEOUT.md); issue [#58](https://github.com/MohamedXIV/nile-kiosk/issues/58).

## What happens in the *existing* playable experience

- Salma's existing, player-invoked river-reflection P6/Ink talk is legitimately unlocked by a real P1/E1 riverside quiet action with co-presence. The player may select its existing `rest` response, and Salma offers one concrete tea technique: lift the kettle promptly as soon as it is ready. The `city` response does **not** teach it.
- **Choosing is not hearing**. Only reading Salma's committed Ink `river_rest` beat triggers authenticated P2 speech of `salma:tea-timing-tip`. The source fact is P2-owned, public and seeded into Salma, not into the player or a UI game variable.
- `scripts/gameplay/tea_technique_play.gd` is a **pure projection** of P2 heard-event provenance and genuine **player** `cook.started` events after hearing. P3 authenticated item-quality receipts decide outcome: heard, attempted, and understood after a real `good` finished tea. A bad cup remains an attempt and provides no free quality improvement.
- A small optional nearby Salma acknowledgment is derived from the actual recent prepared cup quality, independent of NPC trust, money, inventory, reputation or new narrative/needs state. No game-score reward for selecting dialogue.
- Existing P3 H/U physical actions, P4 orders, payment, P5 ledger and P1 clock are unchanged. Story choice and cooking outcomes survive deterministic save/replay.
- This is the deliberately smallest approved **learning direction**; more recipes, chef XP, complex mastery ladders, full home cooking diversity and cosmetic production expansion belong to the later phase.

## Independent acceptance gate — MUST run before merge

- New `tests/test_e3_tea_technique.gd` exercises: no free knowledge, genuine proximity/unlocked Ink, option not automatically hearing, actual Salma beat granting P2 fact, hard disk reload, player post-hearing physical P3 steps with prompt/late quality and a deterministic kernel replay, no permanent mastery after poor execution.
- `tools/web-e6-game-entry-smoke.mjs` performs real default Godot/Web entry, the Salma story choice and actual heard beat, confirms no retroactive skill credit for an earlier tea, then performs a post-hearing second-day P3 cooking job through ordinary keys and verifies hard browser reload of that outcome.
- Exact final head requires **full hosted Godot Native and Web/Chromium/Ink SUCCESS**, not only an isolated native helper or local claim.
- The E6 [PR #85](https://github.com/MohamedXIV/nile-kiosk/pull/85) is a stacked prerequisite so the same scene/Chromium file is not modified in competing PRs. Rebase/merge cleanly onto current main after #85 is verified and merged. Art PR #20 is human-gated and never touched.

**Status must remain OPEN until the evidence above is complete, merged and reconciled with issues/roadmap/traceability.**
