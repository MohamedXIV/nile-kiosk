# V001 P0 — Fixed-angle apartment cutaway blockout

**Status:** mechanical prototype under test, NOT art approval.

Scene: `res://scenes/building_cutaway_spike.tscn` running in Godot 4/GDScript. In Godot launcher, select this scene.

The player can explore a street view of a six-storey imagined 1940s–1950s Cairo building, enter an abstract lobby, reach the top residential floor, and reveal a room in a **consistent fixed oblique projection**. The front occluders and roof are independently hidden when exploring inside; lower facade remains.

## Inputs

- `E`: street → entrance/lobby → apartment.
- `Backspace`: apartment → lobby → street.
- `WASD`/arrows: move within local 2D floor plane.
- `1`, `2`: select chair or table.
- `G`: attempt move selected object near player; bounds/other furniture prevent invalid placement.
- `N`: day/night mood toggle.
- `F6`: save scene state to `user://v001-cutaway.json`; `F7`: reload (browser persistence across tab close is not established).

## Logical model

`(building_id, floor_id, local_x, local_y)` describes player location. Fixed camera projection maps that location onto two nonparallel screen axes with a per-floor visual offset. Rendering/occlusion are **visibility state**, not logical geometry or an actual Z buffer. The room/collision graph remains an independent 2D plane on the same floor.

## Acceptance claims

Automated: floor transitions, screen projection invariants, hide/show facade and roof state, movement and furniture collision, and JSON persistence. Visual: only a developer placeholder using Godot `draw_colored_polygon`, not production sprites or Blender output.

## Next technical gate (V001 P1)

Build one actual authored Blender blockout with a fixed orthographic oblique camera; export roof, facade, cutaway room, front occluders, chair and table as independent sprite assets from identical camera/scale. Import into Godot and compare actual game-resolution screenshots at day/night. **Until then V001 cannot be declared visually successful.**
