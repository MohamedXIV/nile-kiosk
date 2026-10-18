# E4 — Independent nonbuyer social visit (Mona visiting Salma)

**Status: VERIFIED / MERGED 2026-10-18** — [PR #81](https://github.com/MohamedXIV/nile-kiosk/pull/81), squash merge `c65629bca42131360f2d9493186cfcc476838c08`; exact feature head `da6bc6f794ed734106824d8bd27b31f4bafa93cd` passed [Full Native](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39082795869) and [Full Chromium/Ink](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39082795900) including `E4 NONBUYER VISIT: PASS`, `E4_NONBUYER_CHROMIUM_PASS` plus Mahmoud/Salma whole-world regression markers. Scope remains a bounded authored visit.

## Player-visible behavior

Mona is a **social guest**, not a customer order. P2 begins her at the street, sends her to the kiosk by a recurring, authored `npc.routine.create` at **17:44** (world minute 1064), and sends her back at **18:20** (world minute 1100). The existing P1 WorldScheduler owns both firings, even if the player is at home, the kiosk is closed, or the player sleeps through it. **No fake shop order, payment, new scene timer or cloned NPC state.**

When Mona is present, `RoomTraversal.npc_pose` uses the **existing Godot AStarGrid2D path and clearance** to derive entrance → meeting spot → return-to-entrance animation from P2 routine state and P1 scheduled job due minutes. The real P2 arrival and departure remain the canonical presence gate; the path is nonauthoritative presentation. The spot, NPC ID, routine, path duration and story are packaged in `content/social/nile_mona_visit.v1.json`.

An authored E4 `narrative.opportunity.register` with trigger `time.advanced` unlocks a one-time player option only if Mona is actually inside the kiosk, the player is there, the kiosk is open, and canonical time has reached her visit. A player who misses the whole visit is **not retroactively invited** or taught anything; revisiting on a later day with co-presence may unlock the still-unclaimed opportunity. Mona still follows her schedule regardless of this opportunity. There is no involuntary cutscene.

Nearby player can press **L** to start an actual authored `nile_mona_salma_visit.ink` two-choice conversation. Hearing Mona's first **committed** `mona_hello` beat discloses her genuine pre-registered P2 fact `mona:visiting-salma` to co-present listeners; a remote player knows nothing. Ink progression, choices, intermediate saves, and one-shot finish remain owned by P6. The whole conversation stays optional and cannot begin after Mona leaves.

## Boundaries

- Reuses P1 job firings + P2 routine, P6 authored story/choice and E4 pure predicate engine. No new independent time, quest scripting, AI decisioning or world schema bump.
- `scripts/gameplay/social_visitor_play.gd` owns this single encounter's validated manifest, registration and proximity-gated P6 calls to avoid growing GameEntry into a narrative monolith.
- One authored, recurring short visit, not generic multi-NPC goal selection, unscripted plans, social gossip network, dynamic actor-to-actor avoidance, full 3D art or acoustic occlusion.
- Existing Mahmoud sales/social invite and Salma river dialogue must remain intact; no changes to art PR #20. E4 #59, E6 #61 and parent #55 remain OPEN.

## Acceptance

`tests/test_e4_nonbuyer_visit.gd` covers offsite/closed-kiosk visit arrival, navigation-mode transitions, zero order generation, no offsite knowledge/offer, departure, canonical save replay; a separate open-kiosk branch verifies conditional unlock, real optional Ink speech and P2 knowledge, choices, mid-choice disk restoration, completion/no replay, tamper rejection. The production default-scene `tools/web-e6-game-entry-smoke.mjs` exercises the same real social visitor from the canvas, speaks with her by the riverside, verifies no phantom fact before actual Ink dialogue, and hard reloads alongside prior Mahmoud, Salma, service and housing smoke checks.
