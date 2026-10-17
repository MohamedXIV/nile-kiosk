# E4 — Canonical Event/Condition Opportunities (bounded first slice)

**Status: implementation candidate; do not declare verified until exact-head native and Chromium checks complete.** Scope: authored, once-only **narrative opportunity unlocks**. This is not an unrestricted quest scripting language and does not launch an Ink session.

## Authority

- `WorldKernel.dispatch` is the only command entry; `WorldState` v11 owns a single `world_minute`, the ordered event history and the canonical P0–P7 domain projections.
- `NarrativeWorld` owns the registered rule definitions and one-time unlocked opportunities **inside the existing authoritative narrative snapshot**. The pure `story_opportunity_rules.gd` has no mutable state, Godot Nodes, timers, ledger or Ink cursor.
- Each accepted gameplay command applies its normal domain transition, appends its verified canonical event, then checks registered rules against that committed world. A matching rule records `{source_event_id, source_command_id, world_minute, trigger_event}` in the narrative domain. Rule registration itself cannot unlock an opportunity.
- Registration and any unlocked marker replay from the immutable event history. A forged condition, marker, event ID or minute fails strict whole-world replay and leaves the running world unchanged. Retrying the original command is idempotent.
- **The only action supported is unlock.** No arbitrary command dispatch, economy mutation, NPC teleport, knowledge grant, recursive event generation or automatic Ink session start. Game-facing UI can read `WorldKernel.narrative_opportunities()` or `GameEntry.status().story_opportunities`, which are read-only copies.

## Authored contract

A trusted `content/world/*.json` C0 bootstrap can include:

```json
{
  "id": "moment:river-watch",
  "kind": "narrative.opportunity.register",
  "actor_id": "system:narrative",
  "payload": {
    "opportunity_id": "river_watch_reflection",
    "trigger_event": "life.activity_done",
    "when": {
      "all": [
        {"player_at": "kiosk"},
        {"kiosk_open": true},
        {"time_at_least": 1020},
        {"event_seen": "life.opened"}
      ]
    }
  }
}
```

This **real authored rule** is in `content/world/nile_opening.v1.json`. Watching the river after the kiosk has opened unlocks the opportunity; watching while closed or on the roof does not. Unlocking does not silently make up a conversation, fact or choice.

Allowed condition nodes are **one operator per object**: `all`, `any`, `not`, `time_at_least`, `time_before`, `player_knows`, `has_fact`, `event_seen`, `player_at`, `npc_at:{npc_id,location_id}`, `kiosk_open:boolean`. A condition may nest to depth 4; conjunction/disjunction children are capped at 8; registrations are capped at 64 and validate IDs/schema. Conditions read authoritative state only; event ordering follows WorldKernel's stable commit order. `event_seen` means a matching canonical **top-level** event exists in the history by the time the trigger is committed; it is not a scene signal or a scheduler fire topic.

## Current limits / deliberate next steps

1. A trigger matches a **top-level canonical event kind** after a successful command. A `time.advance` can trigger on `time.advanced` with the final elapsed world minute, but does **not** yet independently trigger once for each nested scheduled firing. Explicit support for individual fire topics and exact due-minute rule evaluation must preserve existing P1 coarse/fine equivalence, not invent mid-advance state.
2. `event_seen` is a bounded-authoring first slice but scans the canonical history; do not claim large-scale indexed quest prerequisites or a generic `after/before` dependency graph.
3. Opportunities are save-persistent **offers** for later presentation/narrative wiring; currently unlocking does not display a new Ink dialogue. Content wording, target NPC, player selection/dismissal and dynamic in-world cues are later E4 deliverables.
4. The authored predicate checks kiosk open state, not a global opening-hours calendar. The time gate at minute 1020 and the example text/beat are **provisional content**, not hardcoded world policy.
5. The `WorldState` v11 snapshot retains strict replay verification; v7–v10 snapshots reconstruct through events. No second world state, scene clock, AI-generated gameplay authority or art changes.

## Acceptance

`tests/test_e4_story_opportunities.gd` covers authored C0 import, early/late and prior-event prerequisites, disallowed predicates and actors, repeat-command safety, once-only provenance, read-only projection, real save/load and corruption rejection. `tests/test_e1_quiet_moments.gd` verifies the real kiosk/roof life loop, closed/open gating and disk reload. Both are part of the existing pinned Godot Native workflow. Existing production E6 game and full Web/Chromium/Ink smoke remain regression gates. **E4 #59 and parent #55 stay OPEN**; this is a narrow foundation, not completion of social or narrative play.
