# Nile Kiosk — System-First Gameplay Architecture

**Decision: APPROVED direction, 2026-10-13.** This supersedes the old *Kiosk Vertical Slice → game-state foundations later* implementation order, **not** the fictional/gameplay vision and **not** the still-open V001 art review.

## Why system-first here

The user explicitly rejected relying on an ever-expanding vertical slice: a prototype with one day, one recipe and one NPC often becomes the de facto production game and accumulates half-built systems. We will instead establish **real systems from day one**, with system-owned data, lifecycle, commands, invariants, persistence, integration tests and a clearly stated Definition of Done. Reusable production code may be developed incrementally, but **prototype logic may not quietly become the engine of record**.

**System-first does NOT mean** prematurely writing a general-purpose game engine, abstract entity-component framework, custom scripting language or 200 interfaces before real gameplay needs them. Build the simplest complete domain module that covers its stated responsibility, and extend its declared scope in versioned changes. Do not start 7 unfinished gameplay systems merely to show movement.

## Current reality (do not conflate with production)

- Godot 4/GDScript + Web **are validated candidates**, not permanently selected pending V001 visuals.
- Ink/inkgd is the **selected narrative authoring runtime** from D001, with Dialogue Manager as tested fallback; story engines do not own the world.
- \`scripts/game_state.gd\`, \`conversation_orchestrator.gd\`, \`kiosk_spike.gd\`, \`spike_save_codec.gd\` and V001 scripts are **spike code**, not a versioned production world contract. Existing \`tea_steps=3\`, two NPC conversations and fixed scene positions are fixtures.
- V001 PR #20 is an open, technically validated 3D-authored/2D-gameplay cutaway; **do not change its art/projection branch to build simulation systems**. New systems work branches from actual \`main\` after checking for competing PRs.
- Visual polish is paused as a priority, **not abandoned**. Use cheap placeholders only in adapters/screens used to verify a complete domain system.

## Bounded contexts and ownership

| System | Owns | Does **not** own | Production contract |
| --- | --- | --- | --- |
| **World Kernel & Time** | Canonical world clock/calendar, deterministic advance, event sequence, scheduling/ordering, command boundary | Sprite draw order, scripts' text, arbitrary real-time timers | [time contract](../systems/WORLD_TIME_AND_SCHEDULER.md) |
| **NPC Life & Presence** | NPC identity and persistent state, daily schedules, location/availability, presence, arrivals/departures, independent actor intents | Ink branching, UI dialogue boxes, player inventory | [system delivery board](../systems/SYSTEM_DELIVERY_BOARD.md) |
| **Social & Knowledge** | Facts, witnessed/overheard provenance, acquaintance familiarity, privacy/gating, relationships and once-only effects | Story text ownership, economy's ledger | [system delivery board](../systems/SYSTEM_DELIVERY_BOARD.md) |
| **Kiosk Production** | Recipes, ingredients, valid station operations, multi-step preparations, cancel/waste/finished items, workstation contention | Customer schedule, money transfers | [system delivery board](../systems/SYSTEM_DELIVERY_BOARD.md) |
| **Orders & Service** | Customer intent, order state, queue, fulfillment, waiting/abandonment, table/takeaway/counter service | Preparing item physics/ingredients, coin balances | [system delivery board](../systems/SYSTEM_DELIVERY_BOARD.md) |
| **Economy & Housing** | Cash/ledger, income/expense provenance, payments, costs, rental rights/obligations, affordability | Room rendering or dialogue script mutation | [system delivery board](../systems/SYSTEM_DELIVERY_BOARD.md) |
| **Home & Objects** | Building/unit identity, access rights, placed belongings, comfort/use interactions, furniture persistence | Housing payment calculations, sprite projection | [system delivery board](../systems/SYSTEM_DELIVERY_BOARD.md) |
| **Narrative Integration** | Bridge from world events to independent Ink sessions, time/knowledge/familiarity/visibility choices and canonical outcomes | Arbitrary writes by Ink directly into world | [D001 decision](../spikes/D001-DECISION.md) |
| **Persistence & Compatibility** | Atomic versioned whole-world save/load, validation, migrations, reproducibility | Gameplay decisions, silently dropping missing NPC sessions | [system delivery board](../systems/SYSTEM_DELIVERY_BOARD.md) |
| **Presentation Adapters** | Godot input, UI, animation, render layer and lights; command dispatch and projection | Changing world state as a side-effect of drawing | Existing V001 art docs |

No duplication: there is exactly **one authority** for clock, money, housing rights and facts. Never maintain a separate authoritative counter in UI, a dialogue-session variable, and the underlying world.

## Dependency and integration order

\`\`\`text
               WORLD KERNEL
            (time + commands/events)
              /        |        \
          Presence  Kiosk Production  Economy
             |          |               |
        Social/Knowledge Orders       Housing
             \          |             /
             Narrative Bridge     Home/Objects
                     \            /
                  World Persistence
                         |
                 Godot Presentation
\`\`\`

This represents **data/ownership dependencies**, not an instruction to postpone persistence until the end. Every finished system must already serialize its own state through the shared versioned contract. Persistence end-to-end hardening is itself a system milestone.

1. **P0 domain contract and world kernel:** deterministic, testable, versioned ground truth; do not create fake kiosk customers before it exists.
2. **P1 time/calendar/scheduler** complete with scheduled event ordering, missed/late events, large time advances, day crossing, pause/resume policy, save/load and replay tests. This is the first owned system, not a "clock label" demo.
3. **P2 NPC life/presence + social/knowledge** (separate modules, integrated through kernel); NPCs can act or converse **even if the player ignores them**.
4. **P3 production/cooking**, with recipe-defined actions/resources and item state; no hardcoded 3-step global tea counter as production authority.
5. **P4 customer orders/service** married to cooking/NPC presence using canonical events rather than script-driven single-customer demos.
6. **P5 ledger/economy/housing and home objects**, with once-only transactions and property/rental state separate from rendering; leave example rents unbalanced.
7. **P6 Ink world adapter and global persistence hardening**, maintaining unpausing NPC sessions and proper gate provenance; include actual browser refresh proof.
8. **P7 UX/runtime/integration** of already-complete domains, with placeholders and actual Web browser smoke; eventually art, balancing and content pipelines.

Teams may adjust dependency-ready order **only by updating the board and explaining it**. A subsystem can be completed and merged independently when its public contract and tests are met; no "temporary" production scaffolding may pass itself off as full implementation.

## Canonical state shape (proposed interface, not yet implemented)

\`\`\`text
WorldState
  schema_version
  world_seed
  clock                 # integer canonical game time + pause/rate policy
  event_sequence        # stable event provenance/order
  scheduled_events      # durable, cancellable, unique IDs
  npc_state             # identities, presence and next commitments
  social_state          # knowledge, witnesses, relationship provenance
  kiosk_state           # stations, recipes, ingredients, prepared items
  order_state           # requests, service, cancellation and fulfillment
  economy_state         # money, items/obligations, ledger entries
  housing_state         # roof room entitlement, future flat lease state
  location_objects      # room identity, props, placement and interactions
  narrative_sessions    # Ink state + independent session references
\`\`\`

Keep runtime caches/projections out of serialized authoritative state. Session state from Ink is serialized **as an adapter payload**, and replay must never duplicate world effects.

## Commands and events

- Inputs are **commands** with actor/source, payload and a globally unique or scoped idempotency key when repeat submission is possible.
- A handler first validates the world facts/available resources/time, and either returns typed rejection or emits deterministic events applied to canonical state.
- Events have stable IDs/order, simulated time, cause and provenance. Multiple modules may react to events but **must not silently double-charge/double-grant**.
- Advance is explicit: UI frame rate does not define canonical elapsed world time. Time scale is an adapter policy; fixed simulation intervals or scheduled event boundaries derive exact time.
- System logic must behave identically in headless and Godot Web with the same state, command order and seed. Real system clock / OS randomness is never gameplay authority.
- No plugin, visual render, particle effect or NPC text playback mutates canonical truth behind the command boundary.

**Implementation freedom:** Plain GDScript RefCounted modules and typed Dictionaries/resources can be sufficient; only introduce heavier ECS/event-sourcing frameworks if a demonstrated scaling need arises. Tests must cover behavior, not class names.

## System-level Definition of Done — mandatory before labeling 'complete'

Every system ticket/PR must show all of:

1. **Model & invariants:** authoritative state schema, precise accepted/rejected transitions, rules for edges/absence/midnight and idempotent operations.
2. **API contract:** named operations, stable IDs, explicit time and error results, integration points. Nothing depends on UI position except an injected world coordinate.
3. **Full lifecycle:** create/start, update/advance, cancel/expire where applicable, complete, cleanup; no "forever pending" state.
4. **Persistence:** versioned serialize/restore, malformed-input rejection, representative mid-operation resume and no duplicate events/economic effects on reload.
5. **Determinism:** repeatable outcomes with identical seed/input and equivalent small-step vs coarse time-advance where required. No frame-rate-dependent results.
6. **Cross-system contract tests:** consume/emit real events from immediate dependencies, not only happy-path mocks; ensure player presence is not a prerequisite for NPC action.
7. **Web/runtime compatibility:** Godot headless tests at minimum; actual Chromium smoke when the subsystem adds player-visible runtime behavior or save integration.
8. **Documentation:** rules, meaning of metrics/values, file ownership, tests run and deliberate deferrals. Defer *content scale*, not core correctness.

A PR that implements only a \`WorldClock\` data class can be a valid **kernel milestone**, but may **not close the entire Time/Scheduler system** until scheduling, save, boundary and deterministic replay tests pass. Likewise a recipe prototype isn't "Cooking complete" without inventory/operations/failure paths.

## Quality and cost guardrails

- Prefer **system-coherent** files/modules (not monoliths; not one file per 10 lines), fully tested domain semantics and one coherent GitHub PR per deliverable.
- No generic "WorldManager" that handles dialogue, money, cooking and roof art in a single class.
- Reuse Godot's suitable built-in infrastructure for presentation, not as a world-truth substitute.
- No unnecessary GitHub Actions job fan-out: reuse existing Godot CI and add one domain test entry point when needed; public runner allowance is not unlimited.
- Check live GitHub main/open PRs/issues before any implementation and avoid concurrent competing branches.
- Report **system completion** only when all declared acceptance items are evidenced; distinguish implemented kernel from fully finished system and playable demo from an art-approved game.

## Mandatory engine-first implementation rule (approved 2026-10-17)

**Prefer native Godot features over reinvention, for all new and refactored player-facing functionality.** NavMesh/NavigationServer2D/NavigationAgent2D for paths, CharacterBody2D/CollisionShape2D for blocking, physics queries or RayCast2D for visibility/occlusion, Area2D for areas, Godot signals/animations/UI/audio where applicable. Custom simulation code belongs to Nile Kiosk's domain *decisions*, not generic engine services. Deliberate exceptions require a clear Godot limitation and verified behavioral tests.

**Critical separation:** WorldKernel/P1/P2/P4/P5 is canonical for NPC arrival, order intent, elapsed world time, ledger, replay and story facts. Godot native navigation and physics govern where people *can* travel. Never introduce an unsaved scene-only NPC position as the authoritative location used by hearing or interactions; canonical time can sample an immutable Godot-generated route. Navigation polygons MUST exclude actual walls/furniture with actor-radius margin; a NavMesh is not collision, visual line-of-sight, or RVO crowd avoidance by itself. Use the latter only when the scene calls for it. Distinguish live physics collision for the player from canonical world-level command gates.

**First E4 movement scope:** the small tile-aligned kiosk uses Godot's **AStarGrid2D** (built in) and obstacle cells authored in `content/navigation/nile_kiosk_walkable.v1.json`. The first attempted NavigationServer2D map was unsuitable for synchronous WorldKernel bootstrap/headless checks on Godot 4.6.3: path queries failed before the first map synchronization despite forced updates. This is a concrete engine integration limitation, not a justification for a custom A* implementation. Native Godot grid routes are sampled using canonical P1 minutes so sprite, hearing, ambient captions and reload agree. The default scene also uses a CharacterBody2D collision probe against StaticBody2D furniture for player input. Use NavigationRegion2D/NavigationAgent2D for larger or dynamic room navigation if later acceptance requires it; moving-crowd avoidance and line-of-sight still remain OPEN.

### Sight vs sound is an engine geometry concern, not a relationship system (E4 P1)

Use Godot's `Geometry2D` segment intersection for deterministic, synchronously testable eye-to-eye visibility against authored solid furniture in the small kiosk, sharing the same geometry used for Godot native AStarGrid2D routes and 2D body collisions. `RayCast2D`/`PhysicsDirectSpaceState2D` remains suitable for scene-driven perception and richer architecture when actual scene physics is authoritative. Visual contact gates a physically co-present NPC-to-NPC remark; it is **not** equivalent to sound propagation, a NPC vision cone, or a substitute for private-dialogue knowledge checks. No extra GameState, system clocks, physics substitute, or generic AI.
