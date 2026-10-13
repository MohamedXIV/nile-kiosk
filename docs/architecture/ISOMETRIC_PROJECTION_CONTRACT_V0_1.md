# Nile Kiosk — Isometric Projection Contract v0.1

**Status: proposed production authoring target; not yet implemented in V001 runtime.**  
**Scope:** 3D-authored → polished modular 2D sprites, Godot 4, fixed camera, V001 roof room / upper landing / south apartment.  
**Machine-readable companion:** [art/contracts/isometric-v0.1.json](../../art/contracts/isometric-v0.1.json).  
**Validation:** \`python3 tools/v001/verify_projection_contract.py\` (stdlib only).

## 0. Decision and compatibility — do not silently break the working spike

The **target** is conventional **2:1 dimetric/isometric-style orthographic** ground projection. This is not geometrically *true isometric* (equal apparent axis lengths). It fixes a tile's horizontal diamond diagonal at twice its vertical diagonal. Camera orientation remains fixed; \`Camera2D\` pan/zoom may change framing without rotating or changing the world projection.

The **current open V001 implementation**, PR #20, is close but **NOT identical**:

| Measurement | Existing V001 P1/V2 (not modified here) | Target v0.1 |
|---|---:|---:|
| Source logical units | 12 units / metre | 1 world unit = 1 metre; adapt legacy coordinates by ÷12 |
| 1-metre x basis (native screen) | (+11.16, +5.40) px | (+12, +6) px |
| 1-metre y basis | (−11.16, +5.40) px | (−12, +6) px |
| Tile diamond full diagonals | 22.32 × 10.80 px | **24 × 12 px** |
| Horizontal / vertical ratio | **2.066666…:1** | **exactly 2:1** |
| One residential floor height | 3.4 m → 47 px | 3.4 m → **49.9696 px** |
| Godot projected origin for V001 reference | (490, 390) px | (490, 390) px, for comparison only |
| Blender camera elevation | asin(0.45/0.93) ≈ 28.95° | **30°** |

**Migration is a separate gated change.** Never mix a new camera/render with old V001 sprites, and never present the test target as already shipped. PR #20 remains the visual/spatial spike with its existing alignment. Existing 24 baked transparent images must all be regenerated together if this target is adopted; the Godot projection, Blender camera, manifest version, prop placement and web screenshot assertions must change in lockstep.

The old suggestion of 128×64 pixels was an illustrative tile size, **not** a constraint that would fit our 960×540 room preview. At native 960×540, the v0.1 reference cell is 24×12 px; interactive zoom may scale it uniformly.

## 1. Coordinate space and camera

**Authoritative units: metres.** All geometry, furniture contact points, collisions, room boundaries and saves are recorded in logical world metres, not PNG pixels.

- \`+X\`: east/right along building footprint.
- \`+Y\`: south/toward the lower/camera-facing side of the plan.
- \`+Z\`: vertically upward.
- A floor identity and a \`unit_id\` are separate from a room's projected height or \`z_index\`.
- Base project registration \`O=(490,390)\` is a **V001 reference-frame offset**, not a baked-in asset pivot or universal screen centre.

For an orthographic camera at azimuth 45° and elevation 30°:

\`\`\`text
a = tile_width_px / 2  = 12 px/m
b = tile_height_px / 2 =  6 px/m
h = a * sqrt(3/2)     = 14.6969384567 px/m

screen_x = O.x + a * (world_x - world_y)
screen_y = O.y + b * (world_x + world_y) - h * world_z
\`\`\`

An alternative floor-index view uses \`world_z = elevation_index × 3.4 m + local_height_m\`; do **not** multiply an arbitrary semantic \`floor_id\` when a lobby or roof is assigned a special ID.

At \`O=(490,390)\`:

| World metres \`(x,y,z)\` | Projected native px \`(screen_x,screen_y)\` |
| --- | --- |
| (0,0,0) | (490,390) |
| (1,0,0) | (502,396) |
| (0,1,0) | (478,396) |
| (0,0,3.4) | (490,340.0304) |
| (4,5,0) | (478,444) |

To invert a screen position on a **known world-height plane**:

\`\`\`text
d = (screen_x - O.x) / a                # x - y
s = (screen_y - O.y + h * world_z) / b # x + y
world_x = (s + d) / 2
world_y = (s - d) / 2
\`\`\`

A screen pixel by itself **cannot** identify world height/floor; floor, unit, walkable polygon and elevation must be supplied by gameplay context / picking rules. \`Camera2D\` viewport transforms must be undone before this inverse operation.

**Blender basis:** the current baker deliberately swaps authored logical X/Y to the physical Blender X/Y axes. Maintain that same, explicitly tested transform or replace it consistently. Never "fix" a bad mapping by manually moving exported PNGs.

## 2. Dimensional and snapping contract

| Quantity | v0.1 proposed value | Role |
| --- | ---: | --- |
| Logical tile | 1 × 1 m | Topology/design unit, not a required tilemap renderer |
| Primary plan snap | 0.25 m | Reusable modules and prop placement anchors |
| Residential floor rise | 3.40 m | Floors and Blender elevations |
| Structural slab thickness | 0.15 m | Geometry/blockout reference |
| Typical wall height | 2.80 m | Preliminary authoring value; not historical architectural proof |
| Door clear height | 2.10 m | Preliminary; openings can vary per asset |
| Revealed front-wall sill | 0.75 m | Variant per wall, no erasure of spatial silhouette |
| Roof parapet | 1.00 m | Preliminary roof-safe visual form |
| Reference render | 960×540 RGBA | Runtime alignment tests |
| Master render | 1920×1080 RGBA | 2× higher-quality paintover/source export |

Snapping applies to **module origins and structural boundaries**; 0.9-m doors, steps, trim, and irregular existing architecture may use measured non-grid subcomponents. Do not distort real-world sizes to force every decorative edge onto a 0.25-m grid.

Our current authored building reference is 15 × 11 m; **it is not a claim about typical Cairo building dimensions**:

- **Roof room:** 4 × 6 m = **24 m²**; local rectangle \`x=5..9, y=5..11\`, above part of the flat. Starter home, not a penthouse.
- **South apartment:** 10 × 6 m = **60 m²**; rectangle \`x=4..14, y=5..11\`, compact private kitchen and bathroom.
- **Landing:** \`x=4..14, y=4..5\` (shared); **two opposed doors**, one to each unit.
- **Northern neighbor:** \`x=4..14, y=0..4\`; its entrance is visible but its interior stays opaque/unmodeled for this slice.
- Apartment is on residential elevation index 5, roof/roof room on index 6. The semantic labels \`floor_id=6\` and \`floor_id=7\` do not have to equal those indices.
- Rooftop room and south flat can be held simultaneously in **future** game state; rent prices/duplex intervention are deferred, not implemented by this contract.

## 3. One source of truth for all assets

Every Blender source object has a semantic \`asset_id\`, a \`unit_id\` or building-level owner, a transform in metres, a category and export variants. Prefer one locked orthographic Blender camera per **building projection family**. Render all states from the same view basis.

**Static registration:** room-wide floor/wall/facade/roof PNG passes may all use the same **untrimmed 960×540 RGBA frame**, drawn at \`(0,0)\` in the fixed V001 render frame. This maximizes alignment, but static full-canvas images are not the preferred format for hundreds of independent props.

**Modular props:** may be tightly cropped to save space. The export manifest **must** include \`crop_origin_px\`, \`contact_point_px_in_image\`, \`world_anchor_m\`, \`footprint_m\`, \`render_variant\` and \`source_object_id\`. Draw a cropped prop at:

\`\`\`text
draw_top_left_px = project(prop.world_contact_m) - prop.contact_point_px_in_image
contact_point_px_in_image = project(authored_contact_m) - crop_origin_px
\`\`\`

This is why two chairs with different bounding boxes still share one modular floor-contact convention. Source image scale, import scale and pivot math must be tested; no hidden per-instance offsets such as \`+7px\` or \`-4px\` may be used to compensate for bad projection. Painterly color/contour changes can be freely made in a paintover **only if the contact point, extent and cutaway silhouette remain registered**.

### Asset roles and anchors

| Role | Examples | Pivot/anchor | Persistence |
| --- | --- | --- | --- |
| \`structural\` | floor tile/slab, partition | logical minimum X/Y ground corner | topology; not movable |
| \`wall_full\` | roof shell, wall upper | base start/corner of wall | visibility only |
| \`wall_cut\` | southern front low sill | **same base** as its full-wall variant | visibility only |
| \`insert\` | door, window, balcony railing | hinge/base or opening-specific anchor defined in manifest | state if interactive |
| \`prop\` | bed, table, chair, fan | ground contact point, generally bottom-centre | save logical transform |
| \`lighting\` | lamp emissive/normal/occluder | world light-source/occluder geometry | save on/off, not lit pixels |

Suggested ID: \`nk_v001_<space>_<category>_<asset>_<variant>\`, e.g. \`nk_v001_roofroom_wall_cut_south.png\` and \`nk_v001_apartment_prop_chair_a.png\`.

Keep normal/emissive/shadow masks separate from diffuse. Avoid permanently baking a movable chair's cast shadow into the room floor.

## 4. Godot runtime and cutaway

The **game model owns space**. Rendering never grants an extra collision bypass or changes a room's \`unit_id\`:

1. Player enters roof room → show roof-room interior floor, rear walls, furniture and low front sill; hide **its** blocking upper walls/ceiling; do not delete the apartment below.
2. Player steps to shared roof → restore roof-room shell and preserve the supporting floor-6 facade.
3. Player enters floor-6 shared landing → show stair and both opposed doors. Keep northern neighbor **opaque**; do not reveal a fake second apartment interior.
4. Player enters rented south apartment → show its 60-m² interior, rear walls and low south/east cutaway sill; hide upper front-wall/ceiling occluders **for this unit only**.
5. Player exits → restore the corresponding shell and correct lighting occluders.
6. In all cases movement/collision is evaluated in the authoritative same-floor logical metre polygons; hidden walls remain solid.

**Draw order is not world height.** Process each floor/unit in a separate visibility group. Within one exposed walkable plane, Y-sort independently moving prop/character sprites by their **projected floor contact Y**, not the top of the tall sprites. Foreground low cut walls and walls expressly intended to occlude the player may be ordered in fixed groups after floor content. Do not rely on a global single Y-sort of full-canvas architecture images.

**Runtime light:** Godot \`PointLight2D\` lamp switches, emissive sprites/masks and \`LightOccluder2D\` for currently visible wall variants; hide/replace shadows when the corresponding wall is cut. Base/diffuse art should remain broadly neutral where light is meant to change interactively. Normal maps are **optional and unproven as a production art requirement** until their orientation and browser visual quality pass a real spike.

Cutaway and zoom may **change the composition**, but neither changes the authored projection; Godot camera pan/zoom must be uniform scale plus translation with rotation locked.

## 5. Source/build/runtime file structure

\`\`\`text
art/contracts/isometric-v0.1.json            # canonical proposed parameters
art/source/blender/v001/...                   # 3D source and editable geometry
art/renders/v001/{roof_room,landing,apartment}/
art/paintover/v001/...                        # optional disciplined art pass
assets/v001/{roof_room,landing,apartment}/
    structure/  props/  lighting/  manifests/
scripts/v001/...                             # Godot logical geometry/cutaway
tools/v001/verify_projection_contract.py     # math/plan validation
\`\`\`

A generated manifest should specify the exact projection **contract ID**, camera basis, native/master resolution, contact anchors, crop offsets, lighting passes and source revision. Do not let Godot quietly load a target-v0.1 asset with a legacy V001 P1 camera.

## 6. Acceptance / migration checklist

1. Contract JSON validates deterministically: inverse projection, true 2:1 ratio, floor rise and rooftop-over-flat containment.
2. Controlled Blender bake with test markers at **three non-collinear ground points and two different heights** agrees with target Godot projection within **0.5 native pixel** at all markers (stricter than legacy 1.5-pixel tolerance). Cover master→native scaling.
3. Bake **all** structural passes, cut walls, roof shell and props at the new projection in one revision; do not mix assets from legacy and v0.1.
4. Player/prop logical positions, saved furniture contact points and collision shapes remain consistent with the new metre-based coordinate schema. Migrate old save schema explicitly where desired; disposable test saves may instead be marked incompatible.
5. Demonstrate roof-room → roof → two-door landing → south apartment → landing at runtime; verify neighbor remains hidden, walls remain solid, cut wall has no ghost shadows and a moved prop's contact matches its collision.
6. Test lamp on/off, day/night, actual **Godot Web/Chromium** screenshots and no broken draw order; evaluate at 960×540 **at real gameplay zoom**.
7. Art review confirms a believable **small lived-in Cairo home**, not an architectural SVG icon or a luxury floating villa. Green math/CI is **necessary but not sufficient** for art approval.

**Migration ownership:** a new, separately reviewed implementation change should reconcile V001 PR #20 and this proposed contract; do not merge two contradictory projection authorities. If the existing near-2:1 projection is preferred aesthetically, amend this target explicitly before migration rather than hiding the discrepancy.
