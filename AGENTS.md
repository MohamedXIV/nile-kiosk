# Agent working agreement — Nile Kiosk

- Always inspect current GitHub `main`, open PRs, issues and checks before taking work; never assume a recorded SHA is current.
- This is a **public game repository**, but project decisions are provisional. Don't rewrite the game vision to justify an engine already chosen.
- Prefer working branches + PRs for meaningful changes; avoid overlapping changes and duplicate spike implementations.
- D001 uses **English dialogue fixtures only**. Arabic/RTL is intentionally deferred.
- Keep authored dialogue/story distinct from the social orchestrator and canonical GameState. No story addon owns world truth.
- The world keeps running while NPCs talk; an uninvolved player can keep cooking or leave.
- For the visual spike, use a fixed oblique top-down camera with floor-aware logic; avoid a misleading side-view stack of flat layers.
- Avoid single monster files and unnecessary one-file-per-trivial-function fragmentation.
- Use GitHub Actions when they provide real value: public-runner CI is allowed, but do not add repeated heavy jobs or empty placeholder workflows.
- Report actually run tests separately from proposed acceptance gates. Failed or unrun checks are not PASS.
- **ENGINE-FIRST RULE (mandatory across every Nile Kiosk workstream):** Before writing a gameplay-facing custom subsystem, check and use Godot's built-ins where they fit: NavigationRegion2D/NavigationPolygon/NavigationServer2D or NavigationAgent2D for routes, CharacterBody2D/CollisionShape2D for solid movement, Area2D/RayCast2D/physics queries for physical hearing/visibility, AnimationPlayer/Tween, signals, resources, UI, and audio. Write custom code only for game-specific rules that Godot does not provide. Never replace physics/nav/visibility with straight-line LERP or fake distance checks merely to save setup effort. If an engine feature is unsuitable, document the concrete reason and tests first. **Godot owns geometry/path/physics presentation; canonical WorldKernel owns orders, schedule/time, economic facts, event persistence and gameplay decisions.** Do not create a second authoritative position/clock: derive positions deterministically from world events and an authored Godot navmesh, or explicitly design persisted movement before adding nondeterministic agents. Test route/occlusion against real walls and furniture, collisions, load/replay, and real browser output. Dynamic NPC avoidance is conditional on actual simultaneous motion; navmesh alone does NOT provide crowd avoidance or vision. Pin add-on versions/commits for reproducible spikes.

## Mandatory: preserve executable roadmap and future ideas across agents (2026-10-17)

- **Read [Experience Execution Board & Agent Handoff](docs/experience/EXECUTION_BOARD_AND_AGENT_HANDOFF.md) before selecting a new E1–E6 batch.** It contains shipped PRs, exact remaining feature gates, candidate next batches/dependencies, and the PROPOSED idea parking lot. Also read [Roadmap](docs/ROADMAP.md), Epic [#55](https://github.com/MohamedXIV/nile-kiosk/issues/55) and the relevant E-issue; never assume another agent has this chat context.
- **Preserve depth, not shrink scope to make a progress bar move.** E1 P0–P2 [PRs #64–#66](https://github.com/MohamedXIV/nile-kiosk/pulls?q=is%3Apr+is%3Amerged+E1) and E6 P0 [PR #63](https://github.com/MohamedXIV/nile-kiosk/pull/63) have shipped **narrow verified subsets**. E1–E6 are still OPEN, and the exact future work is tracked in the board and issues.
- **Record every newly proposed gameplay/art/production idea** in its owning Epic or a useful independently closable issue, the [execution board](docs/experience/EXECUTION_BOARD_AND_AGENT_HANDOFF.md), and where relevant the [decision register](docs/DECISION_REGISTER.md). Label `AGREED` vs `PROPOSED` vs `OPEN`, dependencies, and any default numbers as provisional. New ideas are **not** automatically user-approved work.
- **After each implementation merge:** update the relevant traceability row, Epic issue, execution board and roadmap **with exact proof and remaining acceptance**. Keep the most recent verified commit/runs as historical context, but always recheck current GitHub state. Record any live PR/CI failure or unresolved choice before handing off.
- **Visual direction:** fixed-angle **2D isometric/dimetric is the current working gameplay baseline**, with 3D allowed for authoring assets, **not active real-time 3D gameplay**. Exact 2:1 camera and zoom/follow/interior framing remain proposed production details; final visual approval is deferred under #19/PR #20. Art comparison screenshots must preserve actual prototype projection/framing.

## Mandatory: do not confuse designed, built and verified

**Before selecting, implementing or closing gameplay work:**
1. Read [design-to-implementation traceability](docs/design/DESIGN_IMPLEMENTATION_TRACEABILITY.md), then the relevant recovered design spec and [epic #55](https://github.com/MohamedXIV/nile-kiosk/issues/55) / child E1–E6. This is the **feature-level gap ledger**, not a replacement for [existing architecture](docs/architecture/SYSTEM_FIRST_ARCHITECTURE.md).
2. Check actual live source, tests, merged PRs and open work. `SYS P0–P7 DONE` / `PLAY C1–C6 DONE` **does not** imply `Mood DONE`, `tactile cooking DONE`, `social economy DONE` or `home comfort DONE`. Their own narrower lifecycles may be verified while the experience is absent.
3. Track separately **design** (`AGREED | PROPOSED | OPEN`), **implementation** (`NONE | FOUNDATION_ONLY | PARTIAL | VERIFIED_SCOPE`) and **evidence** (production files, specific tests/PR SHA, true native/Web or user visual proof). Never upgrade implementation status because a new doc or issue exists; never convert an illustrative number into an approved rule.
4. Implement using existing world-time, NPC, cooking, order, economy, housing, Ink and save authorities. Test both rejected/correct transitions and actual player-facing behavior. Browser/visual/audio evidence when relevant is **not** replaceable with only headless tests.
5. On each merged feature PR, update its matrix row with **exactly the proven scoped behavior and links** and reconcile its issue. Do not close whole E1–E6 epics on a single demo path. A release feature is not shipped while only D001/V001 or QA scene proves it.
6. The standalone Three.js HTML prototype is an **experience/feel comparison**, not an authoritative runtime or art decision. V001 #19/#20 remain separately gated by visual user approval. Do not auto-merge V001 to complete E6.

## Canonical design memory — read before visual work

- Start with [decision register](docs/DECISION_REGISTER.md): agreed user direction, implemented proof, proposed values and unapproved art must **not** be conflated.
- [Visual World Bible](docs/design/VISUAL_WORLD_BIBLE.md): a **playable** Cairo home and kiosk; never replace it with glossy isometric icons or a floating luxury penthouse. The game's emotional economy is **enough**, not wealth.
- [Home spatial spec](docs/architecture/HOME_BUILDING_SPATIAL_SPEC.md): player **starts in 24m² (4×6) roof room**; 60m² (10×6) southern apartment below, **two opposing landing doors** and **unrendered northern neighbor**. Roof room is over the player's future flat. Rents and duplex are deferred.
- [3D → 2D pipeline](docs/art/3D_AUTHORED_2D_PRODUCTION.md): Blender measured spatial authoring, distinct game-ready 2D sprites/layers, world contact/pivots/crop offsets, dynamic lighting, explicit visual acceptance. **Concept images are not automatically runnable assets.**
- [Iso projection v0.1](docs/architecture/ISOMETRIC_PROJECTION_CONTRACT_V0_1.md) is **proposed 2:1**, while [open PR #20](https://github.com/MohamedXIV/nile-kiosk/pull/20) still uses validated **~2.067:1**. Do not silently swap cameras, mix sprite generations or claim the proposed contract is implemented.
- Structural collision survives cutting roofs/walls. Reveal **only the relevant unit**, keep low front sills and correct light occluders, and preserve stairs/shared landing/neighbor door continuity.
- Do not merge/close art work solely on green headless/Chromium acceptance if the user has not approved the visual result.

## System-First mandate (2026-10-13)

- **Do not build a one-day/one-recipe/one-customer vertical slice as the product foundation.** The user explicitly requested production domain systems from day one after bad experiences with agents extending half-baked prototypes.
- Start with [System-First Architecture](docs/architecture/SYSTEM_FIRST_ARCHITECTURE.md), [System Delivery Board](docs/systems/SYSTEM_DELIVERY_BOARD.md) and [World Time/Scheduler contract](docs/systems/WORLD_TIME_AND_SCHEDULER.md). Reconcile old roadmap entries accordingly.
- **Quarantine D001/V001 spikes:** `scripts/conversation_orchestrator.gd`, `scripts/game_state.gd`, `scripts/spike_save_codec.gd`, `scripts/kiosk_spike.gd`, V001 art scripts are tests/prototypes; do not wire their hardcoded tea counter/tick directly as production authority.
- Exactly one canonical owner for time, NPC state, ingredients/recipes, orders, cash/rents, home access and social facts. Ink is the authored dialogue adapter, NEVER a second GameState.
- Every system needs explicit API/schema, full lifecycle, rejection/idempotency, deterministic progression, versioned save and real dependency tests before closing its epic; meaningful kernel sub-deliverables can land without claiming the entire system is complete.
- Keep unrelated PR #20 visual work independent. Prefer lean Godot headless tests and actual Chromium checks where the behavior becomes browser-facing; no expensive duplicate CI jobs.
