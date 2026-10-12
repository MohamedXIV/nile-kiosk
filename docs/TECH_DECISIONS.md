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
