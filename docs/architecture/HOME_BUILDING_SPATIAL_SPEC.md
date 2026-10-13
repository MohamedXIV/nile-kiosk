# Nile Kiosk — Home Building Spatial Specification

**Status: design topology agreed; the exact doors, grids, roof access geometry, paint and final architecture remain art/engineering tasks.**  
**Updated:** 2026-10-13. **Canonical spatial intents**, not an assertion that the game is finished.  
**Related:** [visual bible](../design/VISUAL_WORLD_BIBLE.md), [projection contract](ISOMETRIC_PROJECTION_CONTRACT_V0_1.md), [PR #20 — active V001 implementation](https://github.com/MohamedXIV/nile-kiosk/pull/20).

## One building; several logical spaces

The model must retain the same place while switching its visual representation:

| Space / identity | Nominal size | Access & visual contract |
| --- | --- | --- |
| Street / exterior | contextual | Old Cairo facade and roof visible, walkable approach and entry |
| Lobby and shared stairs | small | Credible entrance, stairs/landing with consistent floor level; can be a focused view |
| Upper residential landing | shared | Exactly **two opposed doors**; player flat south (toward camera), neighbor north |
| North neighbor unit | *interior out of scope* | Door, wall and perhaps light/sound from outside; **no rendered internal space** |
| South apartment | **10×6 m = 60 m² nominal** | Small rentable home; sleeping/living plus compact personal kitchen & bathroom |
| Common roof | building footprint | Utility equipment, circulation and believable edges/parapet |
| Rooftop room | **4×6 m = 24 m²** | **Initial playable home**, occupying a region above the south apartment |

**Floor numbering contract:** identify `building_id`, `floor_id`, `unit_id` and `elevation_index` distinctly. The current V001 code calls upper residential floor 6 and roof 7, but visual elevation indices differ. Roof room is **not** a seventh full apartment floor.

### Measured rectangles (projection v0.1 target, world metres)

```text
Whole blockout footprint: 15 m X 11 m
North neighbor (opaque): x=[4,14], y=[0,4]
Shared landing:          x=[4,14], y=[4,5]
Player south unit:       x=[4,14], y=[5,11] = 60 m²
Roof room above:         x=[5, 9], y=[5,11] = 24 m²
```

The same arrangement is currently implemented in V001 using **12 legacy logical units per metre**, with roof room above part of the apartment. Nominal area is a planning envelope; thick old walls, shafts, and partitions reduce **usable internal** space. These are design dimensions, not surveyed real-world measurements.

### Topology, not an infinitely nested view

```text
Quiet Cairo street
      ⇅
    Lobby ⇅ shared stairs
                  ⇅
Upper landing ── south unit (locked until rented)
     │          north neighbor entrance [opaque, never enters]
     ⇅
 Shared roof ── rooftop room [START]
```

The roof room is over part of the south flat in the authoritative geometry. **Future duplex stair** is only a potential connection between these two nodes, not an existing route or promised feature.

## Housing progression without a property tycoon

- **Start:** roof room, rented, pleasant though compact; roof is shared.
- **Next aspiration:** a modest independent apartment with private bathroom and kitchenette. The upgrade is privacy and daily dignity, not a mansion.
- **Illustrative prices only:** roof room **EGP 200** and south apartment **EGP 1,000**; if rented together, combined expense might be **EGP 1,200**. These are discussion examples, **not balanced economy rules** or present-tense gameplay.
- Retaining both spaces, owner permission, safe structural modifications and internal duplex access are **deferred decisions**. No apartment ownership or construction system is implied.
- Existing `R` access in V001 is a **QA-only shortcut** to preview the apartment, not a housing economy.

## Project Zomboid lessons translated into our much smaller scope

Borrow **observable spatial design principles**, not proprietary engine mechanics:

1. **Space and collision are independent of art visibility.** A hidden upper wall still blocks motion.
2. Roof/shell hide behavior is controlled per visible room/unit, not a universal hide-all-above-player switch.
3. Front-facing upper walls may fade/disappear; **low wall sills remain** to establish limits. Back/side walls stay as needed for room depth.
4. Large furniture may need independent occlusion rules and projected footpoint sorting.
5. Doorway, corridor, stairs and exterior reveal must preserve one coherent plan, even if level transitions are handled by focused scenes.
6. Lighting and shadow occluders must change with **visible** wall variant; do not leave ghosts from a hidden roof/wall.

Because only a few interiors matter, **author deliberate transitions and per-room reveal groups** rather than a city-scale general algorithm. Avoid turning the build into a full-fledged building editor.

## Room and rendering state model

For each unit, distinguish permanent world geometry from visual variants:

```text
World:     Building / Level / Unit / Room / Portal / Collision / Furniture
Render:    Floor / RearWalls / FrontUpper / FrontLow / RoofShell
           Doors / Windows / Builtins / Props / Normal/Emissive
           RoomLights / VisibleWallOccluders / ForegroundCut
```

Allowed visual modes include `exterior`, `landing`, `roof_shared`, `roof_room_revealed`, and `south_flat_revealed`. The north apartment always stays opaque in V001. Match shell/cutaway overlays to the **same base anchors**, never hand-nudge sprites. Restore roof/shell and occluders on exit.

**Camera:** one stable axonometric projection, no angle rotation. Pan/zoom changes framing for small interiors so rooms fill the screen; it does not rewrite logical geometry or author a different camera for each prop.

**Save and reload:** persist `building_id`, `floor_id`, `unit_id`, positions in metres, actual rental state once designed, prop transforms and light states. Avoid save data expressed only as render pixels or layer order.

## Technical checks for V001

- 24m² rectangle lies within footprint of 60m² south unit.
- Landing touches both unit entrances; south and north doors are visibly opposed.
- Player **starts on roof room**, can reach common roof and stair landing; north unit is not traversable.
- Before rental, entering south apartment must fail, except the explicitly labeled debug/QA preview.
- Collisions remain stable under wall reveal, zoom and lighting changes.
- After cutaway, no transparent holes between partitions; foreground low walls remain, hidden upper walls stop casting runtime shadows.
- Furniture/contact sorting remains correct while moving and after save/load.
- Browser screenshots at 960×540/real gameplay zoom plus visual sign-off.

No art or lighting acceptance may be inferred from the numerical topology tests alone.
