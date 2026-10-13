# SYS P2 — NPC Life, Presence and Social Knowledge

**Status: VERIFIED / MERGED** — [PR #35](https://github.com/MohamedXIV/nile-kiosk/pull/35) merge `072a910726e6e4ce286b134b2fb4952931efeff9`, [Godot P0/P1/P2 + native regressions PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38401158052), [Chromium Ink + Dialogue Manager PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38401158037).

Issue: [#26](https://github.com/MohamedXIV/nile-kiosk/issues/26). Production files: `scripts/core/npc_world.gd`, `world_state.gd`, `world_kernel.gd`.

## Scope and authority

One `WorldKernel` event authority owns the canonical clock, all NPC locations, durable routines, social facts, recipient knowledge, and explicit familiarity permissions. `NpcWorld` is a bounded **domain state/reducer**, not an independent global GameState, scene singleton, or Ink state. Its state is included in schema v3 snapshots and fully reconstructed by the same replay. No hardcoded population, kiosk opening hours, relationship growth speed, walk-time, AI character personalities, food/content or fictional calendar have been chosen.

## NPC identities and presence

- `npc.register {npc_id, location_id}` creates durable ID and initial/base position; `""` is **offstage/absent**. The literal `player` ID is reserved. `npc.move {npc_id, location_id}` sets idle NPC base/current location; cannot teleport an active scheduled visit.
- `npc.routine.create {routine_id, npc_id, location_id, start_minute, end_minute, period_minutes}` creates paired **domain-owned canonical scheduler** begin/end jobs in one event transaction. Times are absolute simulated minutes; duration must be positive; repeating period is 0 (once) or >= duration. There is no fixed number of visits, NPCs, places or days. Jobs include source actor/command and stable IDs, with paired start priority 200 and end priority 100 so simultaneous departures precede arrivals. The scheduler executes while the player is offstage, does not depend on frame rate, and leaves a durable `npc_outcomes` trace in the `time.advanced` event.
- If NPC has a different active commitment when another start fires, the second is recorded as `missed_busy`. Its eventual end is recorded `skipped` and does not evict the incumbent routine. If the NPC is interrupted early, the matching end becomes `skipped`. Later recurring commitments can succeed. These are explicit deterministic conflict rules, **not** prioritization by customer type or money.
- `npc.visit.interrupt {npc_id, reason}` ends the current visit and returns to the recorded base location. `npc.routine.cancel {routine_id}` cancels both pending scheduler jobs and ends that routine's active visit if needed. Canceled IDs are never recycled; failed or completed occurrences remain in the ledger. Generic scheduler commands cannot create/modify reserved `npc.` jobs.
- `npc(id)`, `npc_routines()`, `social_view()` provide *copies*, not mutable state references. An NPC is present when its location is non-empty and is occupied when `routine_id` is non-empty. No temporary scene presentation or virtual "NPC counter" determines existence.

## Social knowledge and privacy

- `social.fact.register {fact_id, source_npc_id, visibility}` establishes a canonical fact with an owner/provenance event. Only `public` or `trusted` visibility exists in this contract; variants/levels are **categorical**, not arbitrary friendship numbers.
- `social.player.place {location_id}` records the player's listening location. Unset/`""` means absent. This is the minimal authoritative presence hook for P6; actual navigation adapters will dispatch it, never edit the state.
- `social.familiarity.set {observer_id, npc_id, level}` updates an explicitly authored relationship permission (`unknown | known | trusted`). Values are not auto-incremented by visits or dialogue. Trust for private disclosure is **listener-specific and directional**.
- `social.speak {speaker_id, fact_id, mode, audience_ids}`, dispatched by `actor_id == speaker_id`, first requires the NPC to *know* the established fact and be present. `broadcast` of a **public** fact reaches all co-located NPCs and player, whether the player is interacting with them or not. `directed` addresses an explicit co-located listener set. `trusted` facts can only be **directed** to trusted recipients; absent recipients, forged speakers and unsafe publicity are rejected atomically.
- The first legitimate fact acquisition for a listener records source speaker, absolute hearing minute and event ID. A person who was absent **does not retroactively acquire knowledge**; NPCs can transmit facts to one another offscreen without involving the player. Already-known facts do not produce duplicate acquisitions.
- `player_knows(fact_id)` queries heard social facts; it is separate from P0's generic `has_fact`. Ink and optional AI will never be permitted to directly mutate these facts or invent canonical NPC identities.

## Save/replay and integration caveats

Schema **v3** adds the `society` domain section, including NPCs, routines, social facts, knowledge, familiarity, player location. Version 1/2 snapshots are **explicitly rejected**, not silently interpreted as P2 worlds. Every event is replayed and its expected domain/scheduler effects are independently recalculated; forged location, hearing, job deadlines, event outputs, receipt or chronology must fail **atomically**. Godot JSON's integral float decoding is normalized only after numerical validation. New commands share P0/P1 idempotent command receipts.

This P2 contract models *when and where* NPCs can be present and what information each actor could know. It intentionally does **not** implement Ink, text utterances, probabilistic encounter pacing, line-of-sight/proximity measured in meters, mood tuning, group conversation orchestration, product/service operations or actual 2D scene population. Those are separate data/presentation/integration responsibilities. The speech event models world-verified **meaningful factual disclosure**, not generated dialogue text.

## Verification gate

`tests/test_sys_p2.gd` is a new headless production acceptance suite in **the existing Godot 4.6.3 CI workflow**, beside unmodified P0/P1/D001/V001 tests. It covers lifecycle/ID collisions, multiple independently scheduled NPCs, conflict/missed/interrupt/cancel, recurrent shifts across days, large-vs-small advancement equivalence, offscreen/social transmission, absent listeners, private-trust gates, no duplicate knowledge, idempotent command receipts, disk JSON mid-visit restore, forged NPC state/queue/event rejection, explicit old-version rejection and deterministic replay. No browser presentation changed in P2; existing Chromium regression should remain green.
