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
- Prefer official engine features before inventing custom substitutes. Pin add-on versions/commits for reproducible spikes.

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
