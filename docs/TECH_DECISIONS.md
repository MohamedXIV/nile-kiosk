# Technical direction and decision record

**Status:** exploratory, 2026-10-12. An initial GitHub Godot .gitignore is not evidence of engine commitment.

## Constraints

- Primarily autonomous development and testing on remote Linux/CI; browser-visible build previews are valuable for reviewing without a local engine.
- Prefer code and editable text assets in Git, deterministic tests, modular files and low-burden workflows.
- Avoid unnecessary custom systems where engine features suffice, but keep core game state engine-independent where practical.
- Camera expected to be fixed; visual coherence and interaction matter more than free rotation.

## Candidate stack

| Layer | Candidate | Status |
| --- | --- | --- |
| Runtime | Godot 4 / GDScript | Trial only |
| Renderer | Godot Compatibility, Web export | Trial only |
| Visual pipeline | Blender / 3D-authored → baked 2D with independent sprites | Trial only |
| World layout | Fixed 3/4 oblique/dimetric view; logical per-floor spaces | Trial only |
| Dialogue | **Ink + inkgd** (authored primary), Dialogue Manager retained as tested fallback | D001 accepted in small-scope proof; scale/performance not proven |
| State | Canonical GameState outside dialogue engine | Architectural requirement |
| CI | GitHub Actions for lean meaningful checks, public repo | Add when runnable project exists |

## Important technical boundaries

1. **Logical position vs projection:** store a room/building/floor ID and local 2D coordinates. Derive image position from a consistent projection, not from an ad-hoc z-index. `z_index` is drawing order, not physical elevation.
2. **Cutaways:** separate floors, facades, roof, front occluders and room interiors into controllable render assets. Opening an apartment must show a consistent authored interior, not simply delete an exterior picture.
3. **Movable furniture:** independent sprites/scene nodes with logical coordinates, collisions and persistence; room background cannot be one monolithic illustration.
4. **Dialogue:** world scheduler decides who speaks and when; engines only provide authored content/choices. GameState applies idempotent effects; no dialogue plugin is authoritative.
5. **Web:** verify actual browser runtime, not merely successful export. Ink/inkgd compatibility is a specific early risk; record pinned versions/commits in spike results.
6. **Arabic:** intentionally **out of scope for the first D001 spike**. English fixtures only. Future localization support must remain possible without prematurely adding RTL gates.
7. **Automation:** GitHub Actions is now acceptable because this is public; use focused workflows with caching and concurrency cancellation once there is runnable code, and avoid redundant CI.

## Decision gates

- **D001:** Dialogue Manager vs Ink/inkgd must each undergo same two-conversation, state, save/load, gameplay-continuity and web tests.
- **V001:** Godot 2D presentation must prove building cutaway, room traversability, independently moveable props, persistent changes and acceptable visual readability.
- Reevaluate Phaser / Babylon / 3D-runtime only with direct evidence from the spikes. Don't convert provisional choices into permanent architecture via documentation alone.

## D001 decision (2026-10-12)

**Choose Ink + inkgd as the authoring/runtime baseline for the next game slice**, with Dialogue Manager kept in the repository as a working comparison/fallback until we establish a production-quality workflow.

Both real alternatives passed native independent concurrent conversations, conditional authored interjection, canonical fact effects, deterministic save/resume mid-choice, and separate full-kiosk Chromium Web smokes. There is no measured runtime performance advantage established for either. Ink wins **as a design/workflow tradeoff**: compositional authored narrative (short branches with rapid reconvergence), plain text scripts, and portability if the game later leaves Godot. It costs a compiler build step, requires a Git-pinned Godot-4 branch of inkgd, and has a more involved integration than Dialogue Manager. These are explicit costs, not ignored.

Decision evidence: [D001 comparison report](spikes/D001-DECISION.md). Next visual/engine trial (V001) remains required before we commit to Godot as the final game engine.

## Proposed iso authoring contract (2026-10-13)

See [Isometric Projection Contract v0.1](architecture/ISOMETRIC_PROJECTION_CONTRACT_V0_1.md) and its JSON parameters and stdlib-only math validator. It **proposes** exact 2:1 dimetric projection for future modular 3D-authored → 2D-delivered assets. **PR #20 still uses its existing approximately 2.067:1 camera** and remains the validated-but-art-unapproved V001 spike. Do not mix renders or silently change the live camera; adoption requires a single separately gated Blender/Godot migration plus real Chromium proof. This is an authoring specification, not the final Godot engine commitment.

## Cross-disciplinary art and building decisions (2026-10-13)

- **[Decision register](DECISION_REGISTER.md)** is the authoritative index distinguishing agreed game experience, optional proposals, validated code and unapproved art.
- **[Visual World Bible](design/VISUAL_WORLD_BIBLE.md)** defines the illustrated, playable isometric room goal (not icons or concept-art screenshots); [spatial specification](architecture/HOME_BUILDING_SPATIAL_SPEC.md) records the **24m² rooftop start, 60m² south flat, two facing doors, opaque neighbor and shared landing**.
- **[3D-authored/2D-delivered workflow](art/3D_AUTHORED_2D_PRODUCTION.md)** defines semantic passes, pivots, crop metadata, lighting and acceptance. Blender is source of measured geometry and projection, **not an obligation to preserve raw 3D shading as final 2D style**.
- Project Zomboid is a **design lesson** for local cutaways, low wall silhouettes and room continuity, not a mandate to adopt Zomboid's renderer/tilesets or clone its world scale.
- The 2:1 projection document remains a **proposed target only** until exact-projection Blender/Godot/Chromium evidence proves the migration. Current V001 open PR #20 remains ~2.067:1, with separate visual art review still required.
- Rent sample (EGP 200 + EGP 1,000) and duplex are **discussion-only**. No property system or construction permission is implied.
