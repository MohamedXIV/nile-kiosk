# Roadmap — discovery-first

This roadmap records **work to prove**, not features already shipped. The game is early pre-production.

| Order | Workstream | Delivery gate |
| --- | --- | --- |
| 0 | Foundation documentation | Core fantasy, era, visual assumptions and open choices recorded |
| 1 | D001 Dialogue system spike — **complete for defined scope** | Both candidates passed native concurrency and disk save, full kiosk browser; Ink selected as provisional narrative baseline |
| 2 | V001 spatial/cutaway and **visual art approval** | Existing Godot/Blender/Chromium geometry proof in PR #20; roof-room start, neighbor and 60m² flat; art **still under user review** |
| 2a | **V001-A — roof-room real 2D asset pack** | 3D measured model → independently authored/cleaned 2D floor/walls/cutaway/bed/desk/fan/lamp; pivot/lighting/collision/save and real browser art review |
| 2b | V001-B landing and V001-C south-flat pack | Two clearly opposed doors + opaque north neighbor; 60m² flat kitchen/bath and unit cutaway, without icon-like room framing |
| 2c | Proposed 2:1 projection migration (only if adopted) | Rebuild Blender/Godot/manifest/sprites simultaneously from projection v0.1; no mixed generations; reprojection and real Chromium proof |
| 3 | Technical decision | Lock runtime/visual/narrative combination based on D001/V001 evidence |
| 4 | Kiosk vertical slice | One cooking recipe, one meaningful day, NPC arrivals/table/counter/Nile behavior, return home |
| 5 | Game-state and narrative foundations | Knowledge, relationships, housing expenses, conversations without player, repeat encounters |
| 6 | Content and systems expansion | Recipes, neighborhood stories, ordinary purchases, ambience and home comfort |
| 7 | Polish, balance and release | Usability, accessibility/localization later, save stability, distribution |

## Working rules

- Keep game vision broader than the spike code. Avoid building an entire platform before validating the experience.
- NPCs must be able to converse without the player; authored dialogue opportunities are not all quests.
- Use independent short modules, coherent assets and reproducible tests.
- CI is welcome on this **public** repository. Prefer one useful smoke job after runnable tests exist, cache imports, cancel superseded runs; don't run empty workflows.
- Arabic text and RTL testing **deferred** from D001 at user's request, not marked completed.

## Completion boundaries

- D001 acceptance completed for **headless Godot native** and **the two Web kiosk smoke exports**; see `spikes/D001-DECISION.md`.
- **Ink browser reload persistence for the tested Chrome/Web origin passed** in [D001 Web refresh acceptance](spikes/D001-browser-refresh.md); cross-origin, cross-device, storage eviction, and other browsers are not proven.
- Production art-resolution dialogue inspection, Arabic/RTL, realistic NPC density/performance, and release build pipeline remain future work.
- Primary visual workstream: **V001 3D-authored → 2D-delivered MODULAR asset pack**, starting with the 24m² roof room. Engineering proof and visual quality are separate gates; [visual bible](design/VISUAL_WORLD_BIBLE.md), [asset pipeline](art/3D_AUTHORED_2D_PRODUCTION.md), [design register](DECISION_REGISTER.md).
