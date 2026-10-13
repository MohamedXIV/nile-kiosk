# System-First Production Board & Completion Gates

**Status:** intended execution order, adopted 2026-10-13. [Architecture and ownership](../architecture/SYSTEM_FIRST_ARCHITECTURE.md). Implementation issues are the live execution board: [parent #23](https://github.com/MohamedXIV/nile-kiosk/issues/23).

**SYS P0 kernel is verified/merged** ([PR #33](https://github.com/MohamedXIV/nile-kiosk/pull/33)); **P1 world time/scheduler is NEXT and NOT implemented.**

A **complete system** is production-owned logic with all lifecycle and persistence edges; a visual demo is only a consumer, never the system of record. It is fine to land coherent, named foundations, but **do not mark a whole system complete because one tiny scenario works**.

| Priority | Work package / boundary | Required completion evidence |
| --- | --- | --- |
| [P0 #24 — DONE](https://github.com/MohamedXIV/nile-kiosk/issues/24) | **World Kernel** — schema, command validation/result, event ID/provenance and deterministic reducer/ordering, versioned whole-world envelope | accepted/rejected commands, stable event sequences, applied effect idempotency, deterministic replay, serialization roundtrip and malformed-save rejection |
| [P1 #25](https://github.com/MohamedXIV/nile-kiosk/issues/25) | **Time & Scheduling** — calendar and deterministic durable event scheduler | [clock/scheduler contract](WORLD_TIME_AND_SCHEDULER.md); midnight, cancellation, recurring scheduling, step-size equivalence and real save/reload |
| [P2 #26](https://github.com/MohamedXIV/nile-kiosk/issues/26) | **NPC Life/Presence** — identity, locations, routines, offscreen schedules, arrivals/departures, availability; separate Social & Knowledge service | multiple independent NPCs and shared space; player absence never stops world; test routine conflicts, idle and time skips, save/replay |
| [P3 #27](https://github.com/MohamedXIV/nile-kiosk/issues/27) | **Kiosk Production** — inventory, ingredient quantities, recipe definitions, workstation states, action sequences, valid/invalid operations and waste/abandonment | distinct items/recipes data-driven, ingredient reservation/consumption, concurrency, interruption/refund policy, yield quality if adopted, persistence |
| [P4 #28](https://github.com/MohamedXIV/nile-kiosk/issues/28) | **Orders & Service** — order lifecycle, waiting rules, seats/counter/takeaway, fulfillment/abandon | NPCs with valid order intentions, queue/station constraints, stale orders never paid twice, events/ledger boundaries, save at each order state |
| [P5 #29](https://github.com/MohamedXIV/nile-kiosk/issues/29) | **Economy, Housing & Home** — precise ledger, recurring obligations, rent rights, property ownership/use and persistent furniture | double-entry or other consistent audit ledger, affordability/debt policy explicitly decided, roof-room starter entitlement, 60m² flat access only after legitimate lease, save/load; *no fixed example rents as gospel* |
| [P6 #30](https://github.com/MohamedXIV/nile-kiosk/issues/30) | **Social + Ink Narrative Bridge** — canonical knowledge, social memory/familiarity/privacy, concurrent independent speech and authored choices | world-verified knowledge/choice guards, hearing/proximity, not every talk player-facing, no independent Ink authority, branching/reconvergence, repeat encounters and resumed Ink Web story |
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
