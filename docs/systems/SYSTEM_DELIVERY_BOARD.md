# System-First Production Board & Completion Gates

**Status:** intended execution order, adopted 2026-10-13. [Architecture and ownership](../architecture/SYSTEM_FIRST_ARCHITECTURE.md). Implementation issues are the live execution board: [parent #23](https://github.com/MohamedXIV/nile-kiosk/issues/23).

**SYS P0 World Kernel** ([PR #33](https://github.com/MohamedXIV/nile-kiosk/pull/33)) and **SYS P1 World Time/Scheduler** ([PR #34](https://github.com/MohamedXIV/nile-kiosk/pull/34)) are verified and merged. **SYS P2 NPC Life/Presence/Social** ([PR #35](https://github.com/MohamedXIV/nile-kiosk/pull/35)) is verified and merged. **SYS P3 Cooking & Inventory** ([PR #36](https://github.com/MohamedXIV/nile-kiosk/pull/36)) is verified and merged. **SYS P4 Orders & Service** ([PR #37](https://github.com/MohamedXIV/nile-kiosk/pull/37)) is verified and merged. **SYS P5 Economy, Housing & Home** ([PR #38](https://github.com/MohamedXIV/nile-kiosk/pull/38)) is verified and merged. **SYS P6 Social + Ink Narrative Bridge** ([PR #39](https://github.com/MohamedXIV/nile-kiosk/pull/39)) is verified and merged. **SYS P7 Whole-world Persistence & Integration is NEXT** (#31). P6 evidence: [Godot SYS P0–P6/D001/V001](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38417014553) and [Chromium Web D001 regression](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38417014473); real production InkPlayer mid-choice world save/reload was verified in the native P6 acceptance. P5 evidence: [Godot P0–P5/D001/V001](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38412511881), [Chromium Web](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38412511851). P4 evidence: [Godot SYS P0–P4, D001/V001](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38407495937) and [Chromium Web](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38407496379). P3 evidence: [Godot P0–P3 and D001/V001](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38404606973), [Chromium Web](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38404606957). P2 evidence: [Godot P0/P1/P2/D001/V001](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38401158052) and [Chromium Web](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38401158037). P1 evidence: [Godot P0/P1/D001/V001 CI](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38390984961) and [Chromium Web](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38390984743).

A **complete system** is production-owned logic with all lifecycle and persistence edges; a visual demo is only a consumer, never the system of record. It is fine to land coherent, named foundations, but **do not mark a whole system complete because one tiny scenario works**.

| Priority | Work package / boundary | Required completion evidence |
| --- | --- | --- |
| [P0 #24 — DONE](https://github.com/MohamedXIV/nile-kiosk/issues/24) | **World Kernel** — schema, command validation/result, event ID/provenance and deterministic reducer/ordering, versioned whole-world envelope | accepted/rejected commands, stable event sequences, applied effect idempotency, deterministic replay, serialization roundtrip and malformed-save rejection |
| [P1 #25 — DONE](https://github.com/MohamedXIV/nile-kiosk/issues/25) | **Time & Scheduling** — calendar and deterministic durable event scheduler | [clock/scheduler contract](WORLD_TIME_AND_SCHEDULER.md); midnight, cancellation, recurring scheduling, step-size equivalence and real save/reload |
| [P2 #26 — DONE](https://github.com/MohamedXIV/nile-kiosk/issues/26) | **NPC Life/Presence** — identity, locations, routines, offscreen schedules, arrivals/departures, availability; separate Social & Knowledge service | multiple independent NPCs and shared space; player absence never stops world; test routine conflicts, idle and time skips, save/replay |
| [P3 #27 — DONE](https://github.com/MohamedXIV/nile-kiosk/issues/27) | **Kiosk Production** — inventory, ingredient quantities, recipe definitions, workstation states, action sequences, valid/invalid operations and waste/abandonment | distinct items/recipes data-driven, ingredient reservation/consumption, concurrency, interruption/refund policy, yield quality if adopted, persistence |
| [P4 #28 — DONE](https://github.com/MohamedXIV/nile-kiosk/issues/28) | **Orders & Service** — order lifecycle, waiting rules, seats/counter/takeaway, fulfillment/abandon | NPCs with valid order intentions, queue/station constraints, stale orders never paid twice, events/ledger boundaries, save at each order state |
| [P5 #29 — DONE](https://github.com/MohamedXIV/nile-kiosk/issues/29) | **Economy, Housing & Home** — precise ledger, recurring obligations, rent rights, property ownership/use and persistent furniture | double-entry or other consistent audit ledger, affordability/debt policy explicitly decided, roof-room starter entitlement, 60m² flat access only after legitimate lease, save/load; *no fixed example rents as gospel* |
| [P6 #30 — DONE](https://github.com/MohamedXIV/nile-kiosk/issues/30) | **Social + Ink Narrative Bridge** — canonical knowledge, social memory/familiarity/privacy, concurrent independent speech and authored choices | world-verified knowledge/choice guards, hearing/proximity, not every talk player-facing, no independent Ink authority, branching/reconvergence, repeat encounters and resumed Ink Web story |
| [P7 #31](https://github.com/MohamedXIV/nile-kiosk/issues/31) | **Whole-world Persistence & Integration** — versioned state and compatibility, gameplay adapters, browser/autosave/reload and observability | full mid-activity/mid-dialogue/mid-day save, migration or rejection of old snapshots, deterministic resume, Chromium proof, trace diagnostics; no hidden desync between UI and world |

**System ownership differs from sequencing.** Start persistence interfaces at P0, NPC social concepts at P2, and Ink bridge at P6; later integration passes are not permission to postpone basic correctness until the end.

### Design choices left open, not hidden placeholders

- Actual clock speed/day duration, working hours and sleep/fast-forward policy.
- Number of recipes/food variants, taste/quality scoring, ingredient supply/pricing.
- NPC population and calendar semantics; duration/frequency of routines; relationship decay.
- Debt/rent policy, prices and duplex construction permission.
- UI presentation, light/art style and exact timing for user-facing interruptions.

**Agent rule:** when unspecified behavior blocks completion, record the question and choose a clearly tagged reversible policy with tests **only if** it does not fix a consequential design preference for the user. Otherwise seek the user's decision. Never invent world economics just to close a ticket.

### Integrating systems without an accidental vertical slice

Build a **headless world simulator** that can exercise each domain through commands and event traces, plus minimal Godot debugging adapters as needed. Scenario fixtures (one NPC/one recipe/day) may test a system but must **not define its production boundaries**. Broader content arrives through data, not changing system semantics.

### Current known boundary

D001 and V001 are **spikes**. They provide useful tests and patterns, not permanent production state. Existing \`GameState\` facts and \`tea_steps\` demonstrate independent dialogue and simple interaction but are not a recipe/inventory/clock/customer simulation.
