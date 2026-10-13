# PLAY C3 — Player-driven Kiosk Service on the Canonical World

Tracked by **Status: VERIFIED / MERGED** — [PR #48](https://github.com/MohamedXIV/nile-kiosk/pull/48), squash `540760fe2a6ca666fa9ef7a8e269c3095a1c6edd`; [native P0–P7/C0/C1/C2/C3 and D001/V001 PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38463521522), [real Web Chrome PLAY_C3_CHROMIUM_PASS + P7/C1/D001 regressions](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38463521605), GitGuardian PASS. The real browser completed customer offer, accept, recipe heat/serve, mid-cook save and reload, delivery, quoted price, exact-once ledger settlement and second browser reload.

[Issue #47](https://github.com/MohamedXIV/nile-kiosk/issues/47). This is the next gameplay-facing integration after C0 data authored worlds and C1/C2 walkable/canonical room XY. It is **not** final content, balanced Egypt 2000–2005 economy or finished art.

## Production boundary

`scripts/integration/kiosk_service_play.gd` is deliberately a **stateless UI/input adapter**. It reads the real P3/P4/P5 world snapshot on every action and determines exactly one next allowed command:
- nearest authored, physically present NPC's one-shot scripted `order.offer` (QA-only NPC intent file; **not AI**)
- `order.accept` (table route selects a free authored table; other routes use no seat)
- `cook.start` for the actual order recipe, reserving its ingredient quantities
- `cook.step.begin` on an available authored station of the correct type; if cooking is not ready, return the remaining world minutes without changing state
- `cook.step.finish`, producing a real prepared P3 item after every recipe step
- `order.deliver` consuming one ready item of the correct recipe through the existing atomic P3/P4 boundary
- `economy.order.quote` from the existing **C0 explicit recipe price**, then `economy.order.settle` through the existing P5 ledger; no cash on delivery or quote, no repeat settlement.

Accepted orders, job IDs, station occupancy, step index, deadlines, service queue, payment claims, quotes and double-entry journal are owned **exclusively** by the kernel. The adapter does not cache “current order” or invent prices, work durations, sellable items or customer trust. Actions are chosen by canonical offer sequence with deterministic ID tie-breaks; completed paid orders are skipped. User interaction triggers one command per press; the real world clock advances only through the existing T key, not a fake progress bar. This is discrete, not final tactile real-time cooking UX.

QA customer desire is defined in `content/service/qa_customer_intents.v1.json`, a versioned bounded manifest, safely packaged from `res://`. Intents are validated before use. The player must be in the actual P4 venue and within C2 canonical XY range of the authored NPC anchor; the NPC must exist and be physically in that same room. The **client does not supply a trusted “nearby witness”**. An authored waiting-window field is QA test data, not the population's global waiting policy. No service purchase is accepted from a user-writable JSON path.

The existing walkable Godot/Web QA scene adds **O** (trigger nearby scripted customer order) and **G** (one next available service step); **T** advances actual minutes and **P** saves. It surfaces order, stage, consumable and payment status, all from `WorldKernel.view()`. The underlying C0/C2 commands, player location and movement, NPC social knowledge and existing save format remain unchanged.

## Acceptance and deferrals

`tests/test_play_c3.gd` checks rejected distant offers and service from the roof, duplicate and malformed customer manifests, one command at a time, no premature station finish, legitimate timed multi-step recipe, mid-cook disk save/reload with matching XY and active service state, correct stock use, delivery not crediting money, priced quote not crediting money, **settlement exactly once**, and a second disk restore with byte-equivalent world replay.

`tools/web-play-c3-smoke.mjs` performs **actual Chrome keyboard navigation**, offer, accept, start, heat, save *while a station is active*, hard browser reload, finish heat/start next station, wait, finish, deliver, price and settle, save, hard reload again and verify exact money/claim/item/status/digest. It runs in the **existing Chromium job** alongside C1, P7 and D001. Native acceptance joins the existing pinned Godot job.

**Not implemented by C3:** autonomous demand generation/NPC decision-making, player-facing contextual menus, collision with stations, tactile tools, a believable paid economic balance, a real opening day, completed dialogue writing, final UX or V001 3D-authored 2D cutaway art. The V001 [Visual PR #20](https://github.com/MohamedXIV/nile-kiosk/pull/20) remains separate and untouched.
