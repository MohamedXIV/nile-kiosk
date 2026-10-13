# Roadmap — System-First Development (2026-10-13)

**Policy: system-first, not vertical-slice-first.** Live implementation tracker: [parent #23 and system epics #24–#31](https://github.com/MohamedXIV/nile-kiosk/issues/23). The game is early pre-production. **SYS P0–P7 are now verified and merged** with real native/Chromium whole-world integration. Next: production content authoring and actual playable spatial presentation (still pending art review), not a second authoritative world implementation. The D001 and V001 spikes remain evidence, not automatic production implementations. See [architecture](architecture/SYSTEM_FIRST_ARCHITECTURE.md), [delivery board](systems/SYSTEM_DELIVERY_BOARD.md) and [time contract](systems/WORLD_TIME_AND_SCHEDULER.md).

| Order | Workstream | Delivery gate |
| --- | --- | --- |
| 0 | Foundation documentation | Core fantasy, era, visual assumptions and open choices recorded |
| 1 | D001 Dialogue system spike — **complete for defined scope** | Both candidates passed native concurrency and disk save, full kiosk browser; Ink selected as provisional narrative baseline |
| 2 | V001 spatial/cutaway and **visual art approval** | Existing Godot/Blender/Chromium geometry proof in PR #20; roof-room start, neighbor and 60m² flat; art **still under user review** |
| 2a | **V001-A — roof-room real 2D asset pack** | 3D measured model → independently authored/cleaned 2D floor/walls/cutaway/bed/desk/fan/lamp; pivot/lighting/collision/save and real browser art review |
| 2b | V001-B landing and V001-C south-flat pack | Two clearly opposed doors + opaque north neighbor; 60m² flat kitchen/bath and unit cutaway, without icon-like room framing |
| 2c | Proposed 2:1 projection migration (only if adopted) | Rebuild Blender/Godot/manifest/sprites simultaneously from projection v0.1; no mixed generations; reprojection and real Chromium proof |
| 3 | **World Kernel (P0) — DONE, [PR #33](https://github.com/MohamedXIV/nile-kiosk/pull/33)** | Tested canonical schema, deterministic commands/events, replay, versioned JSON saves, rejection paths |
| 4 | **World Clock & Scheduler (P1) — DONE** | Durable ordering, boundary time advances, recurring events, save/replay and midnight behavior |
| 5 | **NPC Life/Presence + Social Foundations (P2) — DONE** | Independent offscreen action, identities/routines, observed vs unknown facts; state persistence |
| 6 | **Kiosk Production (P3) — DONE** | Data-defined recipes/stations/ingredients and full start/cancel/finish lifecycle, no hardcoded global tea counter |
| 7 | **Orders & Service (P4) — DONE** | Customer/order lifecycle, waiting, fulfillment/abandonment and independent systems' event wiring |
| 8 | **Economy, Housing & Home (P5) — DONE** | Auditable cash/payment, obligations/access/prop state; prices and duplex remain design choices |
| 9 | **Ink Social/Narrative Bridge (P6) — DONE** | Concurrent independent dialogue, familiarity/knowledge/proximity gates and canonical effect provenance |
| 10 | **Whole-world Persistence & Runtime Integration (P7) — DONE** | Save under active systems, deterministic resume, Web Chromium and debug tools; art remains separate |
| 11 | **Content/polish/release — IN PROGRESS: C0 + PLAY C1/C2/C3 DONE** | [C0 #41 / PR #42](https://github.com/MohamedXIV/nile-kiosk/pull/42) implements validated transactional authored-world imports; [PLAY C1 #43 / PR #44](https://github.com/MohamedXIV/nile-kiosk/pull/44) provides QA-only playable Godot/Web interactions; [PLAY C2 #45 / PR #46](https://github.com/MohamedXIV/nile-kiosk/pull/46) adds **canonical room XY/portal authority**, two Web reloads and verified v7→v8 migration. [PLAY C3 #47 / PR #48](https://github.com/MohamedXIV/nile-kiosk/pull/48) now connects real customer orders, multi-step cooking and priced P5 ledger settlement to **keyboard interactions with two actual browser reloads**. Still next: real authored NPC stories/recipes, visual/art review and game-facing UI, localization and balance |

## Working rules

- **Do not design the implementation around a throwaway one-day vertical slice.** Build complete bounded systems and use scenario fixtures strictly as tests. Avoid building an oversized general-purpose engine with abstractions unsupported by actual domain needs.
- NPCs must be able to converse without the player; authored dialogue opportunities are not all quests.
- Use independent short modules, coherent assets and reproducible tests.
- CI is welcome on this **public** repository. Prefer one useful smoke job after runnable tests exist, cache imports, cancel superseded runs; don't run empty workflows.
- Arabic text and RTL testing **deferred** from D001 at user's request, not marked completed.

## Completion boundaries

- D001 acceptance completed for **headless Godot native** and **the two Web kiosk smoke exports**; see `spikes/D001-DECISION.md`.
- **Ink browser reload persistence for the tested Chrome/Web origin passed** in [D001 Web refresh acceptance](spikes/D001-browser-refresh.md); cross-origin, cross-device, storage eviction, and other browsers are not proven.
- Production art-resolution dialogue inspection, Arabic/RTL, realistic NPC density/performance, and release build pipeline remain future work.
- **Art work can pause without blocking system development.** V001 PR #20 remains open for independent visual review; don't merge it into gameplay kernel as a dependency. [Visual bible](design/VISUAL_WORLD_BIBLE.md), [asset pipeline](art/3D_AUTHORED_2D_PRODUCTION.md), [design register](DECISION_REGISTER.md).
- **Completion means full contract and tests for the declared system**, including rejected transitions, mid-operation save/replay, deterministic results and immediate cross-system boundaries. See [system board](systems/SYSTEM_DELIVERY_BOARD.md).
