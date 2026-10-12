# V001 P1 — Blender-authored layered 2D cutaway

The source of truth is \`tools/v001/bake_building.py\`: real editable 3D geometry, non-AI-generated, intentionally rough art blockout for a six-storey modest Cairo building (constructed earlier, scene set circa 2000–2005).

Run: \`blender -b -t 2 --python tools/v001/bake_building.py -- --output assets/v001\`.

The baker produces \`assets/v001/manifest.json\`, the editable \`v001_cairo_building.blend\` and 14 untrimmed transparent 960×540 PNGs (seven conceptual layers, day/night). Every source shares a **single fixed orthographic oblique camera** calibrated against \`Building.project\` with a maximum 1.5-pixel discrepancy. No free camera rotation, manual sprite offsets or retouching are needed.

Godot \`V001\` continues to use a logical location independent of draw order; the room is drawn at the **actual bottom of floor 6**, not the roof (top of floor 6). The two props are sprites whose \`draw_texture\` translation depends on the same projection function used by the collision/saved placements.

**P1 visual gate stays pending art review** until the CI-produced exterior/cutaway day/night previews are inspected at 960×540 in the Actions artifacts. Automated tests can prove the asset dimensions, transparency and projection registration, but not whether the building looks convincing or feels spatially coherent.

The intentional style uses slightly aged Mediterranean-influenced plaster, restrained molded cornices, weathered teal shutters, wrought-iron balconies, roof water tank and early dish, a small modest furnished apartment (CRT TV, bed, fan planned later), rather than ornate generic "European palace" architecture. The baker does not claim final architectural or stylistic quality.

## Verified execution evidence (October 13, 2026, Cairo time)

- [CI #38316346234](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38316346234) passed on Ubuntu 24.04: **Blender 4.0.2** (Cycles CPU) generated 14 transparent 960×540 PNGs, 4 composite previews and the editable `.blend` project.
- The Blender manifest measured a shared camera origin (490.00002, 390.00011), logical X (11.15997, 5.39999) px/metre-scaled step, logical Y (-11.16003, 5.39999) and floor delta (-0.00006, -46.96078) px: all within the 1.5 px camera tolerance of Godot's existing fixed projection.
- Godot **4.6.3 Standard/GDScript** successfully imported the assets and passed the integration test `V001 P1 ART REGISTRATION PASS`, including day/night texture selection and projected chair relocation.
- Both standalone Web export and an **actual headless Chromium walkthrough** succeeded: `V001_REAL_WEB_ART_PASS`. The test entered the lobby and apartment, moved a chair, switched to night, returned to the street, and captured five live Godot screenshots.
- [Editable source, 14 sprites, four Blender composites and five actual Chromium screenshots](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38316346234/artifacts/11777125733). The art layers are currently **workflow artifacts**, not vendored into Git; developers can bake or download/unzip them into `assets/v001` to view the sprite-backed scene.

### Visual review: NOT ACCEPTED YET

The technical 3D-authored → 2D-rendered cutaway approach is proven at 960×540 in real Godot Web gameplay. The **look itself is not yet approved**. Reviewing the generated contact sheet shows a boxy, repetitive/overregular facade and simplified circular street trees, still too sterile for a modest 1930s–50s Cairo apartment building in the early 2000s. The top-floor placeholder presently shows an entire slab more than a believable small rented flat. Treat this as a spatial/projection/rendering proof, not a production art or neighborhood pass.

Next art pass should focus on an asymmetrical corner/facade treatment, detailed Cairo streetscape and period cues, a subdivided smaller rented unit and more authentic window/balcony hierarchy, while keeping the camera and coordinate contract unchanged. The user should inspect actual web screenshot artifact before approving closure of #19. Do not merge a visual-acceptance claim solely because CI passes.

### Known nonblocking technical notes

Godot headless Web export still produces known resource/RID shutdown diagnostics despite successful browser proof; investigation is tracked in #16. CI temporarily renames the editable .blend before Godot imports PNGs, avoiding Godot's separate .blend importer in headless mode.
