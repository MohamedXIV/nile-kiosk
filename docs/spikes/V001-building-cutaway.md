# V001 — fixed-camera apartment-building cutaway spike

**Status:** planned. Independent of D001, though it can reuse Godot project scaffolding.

## Hypothesis

A **fixed oblique/dimetric 2D presentation** with assets authored in 3D and rendered as separate 2D elements can deliver both the beauty of a 1940s–1950s Cairo residential building seen in the unnamed early 2000s and the spatial interaction normally expected from a 3D world.

## Visual reference and restrictions

- Tree-lined, orderly but lived-in Cairo street, graceful mid-century apartment block (~5–6 floors), older shutters/balconies, some AC units, roof dishes and real aging.
- Beautiful modest apartment with few initial objects and room to improve it; floor near roof is **provisional**.
- Avoid copy-paste generative art detail, implausibly idealized vegetation, identical golden-hour lighting everywhere.
- **No camera rotation is required.** A fixed oblique view is acceptable; strict 2:1 isometric is not required.

## Coordinate and visibility model

- Each floor has an independent logical 2D plane (`building_id`, `floor_id`, local `x,y`).
- A projection maps local coordinates and a floor visual offset to screen coordinates. This is not physical 3D simulation.
- Floor geometry/sprites, facade, roof, room furniture and foreground walls are independently hideable.
- `z_index` and Y-sort only determine pixel overlap. They do **not** substitute for logical floor IDs or consistent projection.

## Slice walkthrough

1. Approach the building from a playable street. Exterior architecture reads clearly at the fixed camera angle.
2. Enter and navigate a minimal shared entrance/stairs; choose/ascend to player's floor.
3. Reveal corresponding apartment by fading/hiding upper exterior layers, roof and front occluders. Preserve architectural continuity.
4. Walk behind/in front of appropriate furniture; move a chair and a table; trigger a visible light or TV state.
5. Exit/re-enter; persist furniture positions and restore exterior when leaving.
6. Render daytime and nighttime scenes; examine foreground occlusion, player silhouettes, sprites, light integration and texture coherence.
7. Test remote automated screenshot/browser preview where supported.

## Acceptance

- No interior visibility or occlusion glitches while switching between exterior and interior.
- Player path remains readable; accessible collision boundaries match artwork.
- Furniture moves independently and persists across scene reloads.
- The view reads as an apartment inside *that very building*, rather than an arbitrary disconnected room.
- Screenshots are evaluated at actual game resolution, not only zoomed concept-art resolution.
- Record art pipeline cost and how easily Blender scene edits regenerate correctly projected sprites.

## Decision

Choose full 2D runtime only if V001 passes both technical and art-readability gates. If the art and occlusion layer burden proves excessive, compare limited 3D runtime again rather than forcing a preconceived result.
