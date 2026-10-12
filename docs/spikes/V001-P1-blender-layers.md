# V001 P1 — Blender-authored layered 2D cutaway

The source of truth is \`tools/v001/bake_building.py\`: real editable 3D geometry, non-AI-generated, intentionally rough art blockout for a six-storey modest Cairo building (constructed earlier, scene set circa 2000–2005).

Run: \`blender -b -t 2 --python tools/v001/bake_building.py -- --output assets/v001\`.

The baker produces \`assets/v001/manifest.json\`, the editable \`v001_cairo_building.blend\` and 14 untrimmed transparent 960×540 PNGs (seven conceptual layers, day/night). Every source shares a **single fixed orthographic oblique camera** calibrated against \`Building.project\` with a maximum 1.5-pixel discrepancy. No free camera rotation, manual sprite offsets or retouching are needed.

Godot \`V001\` continues to use a logical location independent of draw order; the room is drawn at the **actual bottom of floor 6**, not the roof (top of floor 6). The two props are sprites whose \`draw_texture\` translation depends on the same projection function used by the collision/saved placements.

**P1 visual gate stays pending art review** until the CI-produced exterior/cutaway day/night previews are inspected at 960×540 in the Actions artifacts. Automated tests can prove the asset dimensions, transparency and projection registration, but not whether the building looks convincing or feels spatially coherent.

The intentional style uses slightly aged Mediterranean-influenced plaster, restrained molded cornices, weathered teal shutters, wrought-iron balconies, roof water tank and early dish, a small modest furnished apartment (CRT TV, bed, fan planned later), rather than ornate generic "European palace" architecture. The baker does not claim final architectural or stylistic quality.
