# Nile Kiosk — 3D-authored, 2D-delivered production workflow

**Status: intended asset-production workflow / production acceptance rules.** Not proof that the current Blender blockout or AI visual concepts are production-ready assets.  
**Read with:** [Visual bible](../design/VISUAL_WORLD_BIBLE.md), [Projection v0.1](../architecture/ISOMETRIC_PROJECTION_CONTRACT_V0_1.md), [Home topology](../architecture/HOME_BUILDING_SPATIAL_SPEC.md).

## Core principle: 3D supplies spatial truth, 2D supplies visual identity

Blender is for authored measured space: geometry, consistent fixed orthographic camera, dimensions, doors, walls, floors, source transforms, contact points, repeatable masks/passes, and cutaway variants. **The exported game is 2D.** The 3D blockout need not dictate the final material/art style.

Production sequence:

```text
3D model and measured logical placement
 → single locked orthographic projection
 → semantic independent passes (RGBA + support maps)
 → deliberate 2D cleanup/paintover (same geometry/anchors)
 → pack + manifest validation
 → Godot 2D layered scenes + collision + light/cutaway state
 → actual browser playtest + visual approval
```

**Do not mistake a 3D render or AI-generated room illustration for a final asset pack.** A beautiful still alone cannot be re-layered reliably when the player opens a door, hides a roof, moves a table or turns off a lamp. Style explorations are references; game-ready 2D output requires independent source-aligned components and metadata.

## Asset classes and required responsibility

| Category | Examples | Output / gameplay rule |
| --- | --- | --- |
| Structural static | floor, rear wall, roof, stair base | Fixed world anchors; hide/show per unit |
| Cutaway variants | full/front upper, low sill, roof without ceiling | Variants share **identical ground anchor and geometry boundary** |
| Architectural inserts | doors, shutters, windows, kitchen builtins, bathroom partition | Meaningful anchors and separate state as needed |
| Props | bed, chair, table, desk, fan, lamp, refrigerator | Separate cropped 2D sprites, collision footprints, movable when designed |
| Light support | normal, emissive, light masks, occluders, contact shadows | Runtime on/off without double-baked shadows |

Do not create a file for every unimportant brushstroke. Split by **meaningful independent render, occlusion, movement or light behavior**; keep related noninteractive minor details in composited structural art.

## Modular export contract

- **World-space authority:** geometry and furniture contact points in metres, tied to `building_id`, `unit_id`, room and elevation.
- **Target 2:1 native reference grid:** diamond 24×12 px per world metre on the 960×540 base canvas, according to the proposed v0.1 contract. V001 PR #20 currently uses a slightly different, validated camera; **do not combine its images with v0.1 target assets**.
- Full-canvas static structural layers may remain **untrimmed** (all exactly the same 960×540 canvas) for deterministic first-pass registration.
- Individual props may be cropped for efficient atlases **only with manifest metadata**: `asset_id`, `source_object_id`, `world_contact_m`, `crop_origin_px`, `contact_point_px_in_image`, `footprint_m`, `elevation`, `render_state`, and `projection_contract_id`.
- Feet/contact-ground anchors — not arbitrary image bottom-centres — drive prop placement and Y-sort.
- **No unexplained pixel fudges** for structural alignment. Fix camera, anchor or geometry in source. 2D paintover is free to improve contour/colors/details but **may not invalidate pivots, collision dimensions or full/cut silhouettes**.
- One pack = one declared projection/camera generation. Regenerate *all* affected layers when changing projection. Verify camera and source revision hashes.
- **Masters**: suggest 1920×1080 for paintover/high-resolution archival work; **runtime**: test 960×540 and game zoom. Source master and downsample must keep exact coordinate scaling. The current V001 art bake is 960×540 technical proof, not a high-res master.

## Lighting and shadows

Separate predominantly neutral diffuse/albedo art from mutable runtime light. Blender may provide subtle broad ambient occlusion and deliberately static material shading, but must **not bake the final cone/shadow of a movable or toggleable lamp** irreversibly into the room floor.

Candidate runtime: Godot 4 `PointLight2D` with independent emissive masks and `LightOccluder2D`; optional normal-map tests for props/walls. The current V001 basic lamp toggle is a spike, **not proof that full directional normal mapping/realistic shadows work**. All occluders have the same reveal visibility semantics as their walls. Roof hides → its light-blocking roof occluder hides; low front sill remains where expected.

## Art direction gates

Avoid:
- glossy prefab isometric city icons, generic web-SVG flats, symmetric toy/miniatures
- clean empty showroom penthouse that contradicts the 24m² and 60m² contracts
- AI texture mush, inconsistent edges, meaningless micro-details, repeated golden-hour lighting
- baked shadows that contradict on/off lamps or movable furniture
- accidental lookalikes of references without authored decisions

Target:
- recognizable early-2000s Cairo, graceful mid-century building with believable aging
- modest but desirable lived-in home; purposeful items with human proportions
- room cutaway that preserves an actual building shell and walkable paths
- visible warm/cool lighting relationships and an intimate night mood
- readable at gameplay camera zoom, not just as a high-resolution mockup

**A generated visual reference** can demonstrate desired mood, but cannot pass geometry/pivot/collision/light validation without actual separated assets.

## V001 asset packs in dependency order

| Pack | Static passes | Independent props / light support | Acceptance |
| --- | --- | --- | --- |
| **A: Roof room (FIRST)** | floor, rear walls, low front wall, full shell/roof, door, window | bed, small desk, chair, fan, lamp; local emissive/occluder | Player walk, cutaway, lamp on/off, **one prop move/save**, game-resolution screenshot |
| B: Upper landing | shared floor/stairs, wall segments, two opposing doors and frames | landing lamp; door light-underlay, notice board | Roof/landing continuity, north opaque, south rentable only |
| C: South apartment | 60m² floor, partitions, full/cut front walls, windows, compact kitchen and bath | table, chair, bed, storage, fridge, fan/lamp; masks | Collision/interaction/save, cutaway, lighting and personal scale |
| D: Kiosk and promenade (later) | counter, Nile edge, walkway/table areas | cups, kettles, chairs, customers and lights | First full gameplay-day slice, NPC activity |

Prototype references to these spaces can be made in plain Blender geometry; **final polish is not achieved merely by increasing render samples**. Cleanup can be done as coherent hand-directed 2D passes (edges, palettes, material treatment, selective wear) that preserve contact coordinates.

## Proposed folders

```text
art/
  contracts/isometric-v0.1.json
  source/blender/v001/
  renders/v001/{roof_room,landing,apartment}/
  paintover/v001/{roof_room,landing,apartment}/
assets/v001/{roof_room,landing,apartment}/
  structure/
  props/
  lighting/
  manifests/
```

Naming suggestion: `nk_v001_<space>_<category>_<asset>_<variant>.<ext>`. Document the projection ID in the manifest, not only filenames. Preserve editable source plus final sprites together; generated large assets may travel through reproducible CI artifacts during V001, but do not assume CI artifacts are permanent archiving.

## Pack acceptance checklist

1. **Mathematics:** sample at least three non-collinear ground anchors and two heights; target v0.1 Blender/Godot reprojection difference ≤0.5 native px, incl. master/runtime transform.
2. **Modularity:** at least two structural modules meet without seam at zoom; cropped prop contact exactly matches logical position and collision.
3. **Cutaway:** reveal/restore correct unit roof and walls; low sill remains, north neighbor closed, no lingering occluder shadows.
4. **Interactions:** a prop moves independently, remains in walkable/valid positions and survives save/load.
5. **Lighting:** same neutral diffuse base responds to lamp on/off without contradictory baked shadows; real screenshot verifies observable change.
6. **Visual quality:** user's review at **actual Godot Web gameplay size**, not concept art alone. No icon-like composition, implausibly huge flat or luxury apartment.
7. **Reproducibility:** rebuild from editable Blender plus any authored 2D refinements; manifest and deterministic checks enforce camera/pivot/crop rules.

**V001 status:** [PR #20](https://github.com/MohamedXIV/nile-kiosk/pull/20) has verified earlier 24-layer technical/browsing evidence, but **visual acceptance is still open**. [PR #22](https://github.com/MohamedXIV/nile-kiosk/pull/22) documents a **proposed target projection**, not the current shipped pipeline.
