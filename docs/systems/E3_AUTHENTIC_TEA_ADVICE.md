# E3 current-scope COOK-03 — source-attributed tea advice

**Status:** **VERIFIED / MERGED 2026-10-18** for the explicitly frozen bounded COOK-03 scope. [PR #86](https://github.com/MohamedXIV/nile-kiosk/pull/86), squash merge `3df255c4b67447192f41782004b7732ae1aad2c4` from exact feature head `342891c33a89063702aed1166e9d37e5d10599ee`. [Full hosted Native SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39145549953) and [full hosted Chromium/Ink SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39145549942). Owner scope freeze: [CURRENT_SCOPE_CLOSEOUT](../experience/CURRENT_SCOPE_CLOSEOUT.md); issue [#58](https://github.com/MohamedXIV/nile-kiosk/issues/58).

## What happens in the *existing* playable experience

- Salma's existing, player-invoked river-reflection P6/Ink talk is legitimately unlocked by a real P1/E1 riverside quiet action with co-presence. The player may select its existing `rest` response, and Salma offers one concrete tea technique: lift the kettle promptly as soon as it is ready. The `city` response does **not** teach it.
- **Choosing is not hearing**. Only reading Salma's committed Ink `river_rest` beat triggers authenticated P2 speech of `salma:tea-timing-tip`. The source fact is P2-owned, public and seeded into Salma, not into the player or a UI game variable.
- `scripts/gameplay/tea_technique_play.gd` is a **pure projection** of P2 heard-event provenance and genuine **player** `cook.started` events after hearing. P3 authenticated item-quality receipts decide outcome: heard, attempted, and understood after a real `good` finished tea. A bad cup remains an attempt and provides no free quality improvement.
- A small optional nearby Salma acknowledgment is derived from the actual recent prepared cup quality, independent of NPC trust, money, inventory, reputation or new narrative/needs state. No game-score reward for selecting dialogue.
- Existing P3 H/U physical actions, P4 orders, payment, P5 ledger and P1 clock are unchanged. Story choice and cooking outcomes survive deterministic save/replay.
- This is the deliberately smallest approved **learning direction**; more recipes, chef XP, complex mastery ladders, full home cooking diversity and cosmetic production expansion belong to the later phase.

## Independent acceptance gate — verified before merge

- New `tests/test_e3_tea_technique.gd` exercises: no free knowledge, genuine proximity/unlocked Ink, option not automatically hearing, actual Salma beat granting P2 fact, hard disk reload, player post-hearing physical P3 steps with prompt/late quality and a deterministic kernel replay, no permanent mastery after poor execution.
- `tools/web-e3-tea-technique-smoke.mjs` performs real default Godot/Web entry, the Salma story choice and actual heard beat, then performs a later P3 cooking job through ordinary keys and verifies hard browser reload of that outcome; existing `tools/web-e6-game-entry-smoke.mjs` continues covering earlier genuine tea service, its mid-cook rejection paths and the canonical P3 save/replay journey.
- The exact final head has **full hosted Godot Native and Web/Chromium/Ink SUCCESS**. Native logs include `E3 TEA TECHNIQUE: PASS` (including P2 hearing / full disk restore / timely and late real player tea and all-domain replay); browser logs include `E3_TEA_TECHNIQUE_CHROMIUM_PASS` and pre-existing `E3_TEA_HANDS_CHROMIUM_PASS`, `E3_TEA_QUALITY_CHROMIUM_PASS`, `E6_AMBIENCE_CHROMIUM_PASS`, E4 living conversation and E5 procurement. Neither a local-only report nor an isolated QA scene is being passed off as hosted proof.
- The preceding E6 [PR #85](https://github.com/MohamedXIV/nile-kiosk/pull/85) was already merged and verified; PR #86 was verified against `main` and merged as a clean follow-on. Art PR #20 is human-gated and untouched.

**E3 #58 current scope completed; follow-up recipe variety, new gestures, deeper culinary learning and full human pacing/art review remain explicitly deferred to the next phase.** Closing the scoped issue does not claim all future COOK-03 designs, balanced thresholds or final localization.
