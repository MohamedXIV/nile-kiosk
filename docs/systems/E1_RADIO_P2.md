# E1/P2 — owned and placed portable radio

Tracker: [E1 #56](https://github.com/MohamedXIV/nile-kiosk/issues/56), LIFE-02. **Partial life-sim gameplay**; not E2 Mood/Rest, supplier discovery, finished sound design, final art or economy approval.

## Player-facing loop

At the rooftop home the player can:
- **B** — purchase a secondhand portable radio through a **temporary home-order affordance** for a data-authored 1,200 minor currency units, debited by the existing P5 balanced ledger to the existing world-vendors account. This is a *provisional test price*, not a verified 2000s Cairo market price or finished supplier system.
- **V** — place the owned radio in the reserved `roof_radio_nook` slot through `home.object.place` (never automatically granted).
- **R** — listen when actually near the authored position. Listening spends 12 *canonical* world minutes and records **one audited housing use** inside that same immutable WorldKernel event.
- **X** — put the radio away through `home.object.store`. A stored radio cannot play. Buying or placing twice fails rather than duplicating items or money.

A simple rectangle/speaker mark is a **provisional visual affordance**, not production radio art. The sound/content is represented by an authored caption for now, **not actual emitted 2000–2005 broadcast audio**. No Mood/Rest bonus, XP, radio station choice, time-independent cutscene, or "relax +5".

## Domain and safety contract

The already-existing P5 `home.type.define`, `home.object.acquire`, `home.object.place`, and `home.object.store` remain the only inventory/ledger/placement authority. Data lives in `content/life/nile_radio.v1.json`: exact type, slot, location, duration and provisional line. No new global inventory or save schema.

The life domain supports **appending validated authored activity definitions** with `life.activities.extend`. An object-gated activity requires an existing appropriate housing item **owned and actually placed in the authored home slot**, a matching action exposed by its type, and a player within real spatial radius. `life.activity` with radio evidence uses P5 `home.object.interact` as an **atomic effect within the same event** as canonical scheduled time progression. Repeated command IDs resolve via existing verified receipts; forged item/use or time effects do not replay. NPC routines and independent order expiry keep advancing.

New games and existing validated v9 saves can adopt the type and activity once at boot without silently gifting a radio or resetting earlier progress. The existing E1 quieter (roof/Nile) moments remain intact.

## Exact test contract

`tests/test_e1_radio.gd`: no phantom radio, real balance deduction, duplicate purchase/placement rejections, absent/stored/out-of-range usage denial, P5 use_count, P1/P2 offscreen continuity, exactly-once receipt, forced replay validation, next-day save/reload, and adoption by an earlier v9 event-prefix save without extra cash/duplicates.

`tools/web-e6-game-entry-smoke.mjs`: actual user key sequence B → V → R at home, rejection before ownership, verifies 1,200 ledger debit and the same scheduled 12-minute world time, then enters the existing kiosk/customer/river/roof/sleep loop and verifies real Web hard reload retains radio placement, use count, other activities and day state.

**Remaining:** radio broadcast licensing/audio + song era accuracy, physical placement UI, proximity-reachable home animation, shopping/supplier contact and transport (E5 #60), contextual needs/comfort (E2 #57), localization and finalized art (E6 #61/#19). E1 stays open for remaining authored choices/human playtest. [V001 PR #20](https://github.com/MohamedXIV/nile-kiosk/pull/20) stays open/unmerged.
