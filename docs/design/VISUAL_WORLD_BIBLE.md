# Nile Kiosk — Visual World Bible

**Status: product direction agreed in conversation; individual assets and final art style NOT approved.**  
**Updated:** 2026-10-13.  
**Read with:** [spatial spec](../architecture/HOME_BUILDING_SPATIAL_SPEC.md), [projection contract](../architecture/ISOMETRIC_PROJECTION_CONTRACT_V0_1.md), [2D production pipeline](../art/3D_AUTHORED_2D_PRODUCTION.md).

## Experience before technique

Nile Kiosk is a quiet early-2000s Egyptian life simulation about finding **enough**, not accumulating wealth. The home is half the game, not decoration. A person works a small Nile-side tea/food kiosk and comes home to a modest old Cairo residential building. Ordinary places should feel dignified, lived in, warm, and worth returning to. Not a misery simulator, not a villa/penthouse fantasy.

The unnamed era is approximately 2000–2005 **as the characters' present**, not a nostalgia montage. Period cues: modest CRTs, fan, radio/cassette, common satellite dishes, old AC units, plain furniture, terrazzo/tile, plants, shutters, used-but-maintained walls. Add them intentionally, not as arbitrary clutter.

## What the user means by 'isometric'

**A playable isometric/angled top-down ENVIRONMENT, not an isometric building ICON.**

Desired appearance:
- Consistent fixed axonometric/oblique viewpoint, no rotating or free-look camera; pan/zoom is allowed to frame interiors.
- Legible, explorable rooms with believable proportions and paths between objects. An actual home within an actual building.
- Deliberately authored environmental storytelling: a chair, a book, a fan, a window, a kettle, the relief of a tiny kitchen and private bathroom.
- Cozy illustrative 2D finish with shaped values, material differentiation, selective detail and a grounded Cairo identity. Avoid glossy mobile-city-building/asset-pack aesthetics, flat website-SVG icons, uniform symmetrical interiors, sterile 3D blockouts, and incoherent AI-generated texture/detail.
- **No mandated pixel art**: screenshots discussed include different rendering styles. Their shared reference is **spatial readability, cutaway construction, room density and player-scale**, not matching a specific style.
- The player must look proportionate to the room. A 24 m² roof room and 60 m² flat must never read as detached miniature mansions.
- Warm local lights and credible night mood; bright daylight remains important. Do not make every shot golden-hour.

## Reference interpretation, not asset copying

**Project Zomboid** is a technical/compositional reference for room ownership, logical multi-storey buildings, hiding ceilings/upper front-facing walls, leaving low walls where necessary, furnishing, seeing neighbors' doors, and playable 2D spaces. Do **not** copy its art or suggest its implementation is identical to Godot.

Other user-supplied examples include stylized cutaway interiors, cozy illustrated rooms, and isometric scene editors. They establish *camera, spatial relationships, and game readability*, not a single agreed paint technique. Generated visual concepts are exploratory images; they are NOT automatically game-ready layered assets, architectural plans, or final style approvals.

## Residential architecture

- Quiet tree-lined Cairo street, modest yet beautiful pre-1960 residential building (1940s–1950s inspiration), approximately six residential storeys; not luxury heritage-palace, not condemned ruin.
- Credible Cairo details: aging plaster, appropriate shutters, balustrades, shop/entry and landing furniture, balcony plants, utility roof and satellite dishes.
- **Two opposing apartment doors on the upper residential landing**. North unit may belong to a neighbor; its **interior remains unseen**. It still has social existence (door, footsteps, light under door, radio, possible future neighbor interactions).
- Player's future apartment is the **south-facing unit nearer the camera**, nominal **60 m² (10 × 6 m)**. It has a tiny *private kitchen and bathroom* and only modest space for living/sleeping, never a full-floor apartment.
- The **initial home** is a **4 × 6 m = 24 m² roof room**, placed over part of the player's eventual south unit. Initially humble yet comfortable; a compact bed, desk, fan, chair. The common rooftop remains common.
- Player may later rent the apartment below without losing the value of the roof room. Whether and how the player retains both, combines rents, or someday installs an internal duplex staircase is deferred.

## A successful game-scale screenshot should prove

1. The same floor plan, wall corners, door and furniture stay aligned between full shell and reveal.
2. Cutaway reads as a **room inside a building**, not a floating slab with random furniture.
3. The person can navigate around a bed and desk; there is readable clear space, yet not exaggerated emptiness.
4. Room lighting reacts when the lamp turns off and furniture moves, without a permanently baked contradictory shadow.
5. Neighbor's entrance and common landing still read as shared space.
6. Painted/cleaned final sprites communicate recognizable material and character. V001's early Blender 24-layer bake is **technical proof**, not visual acceptance.

## Non-goals for this art slice

No city of fully explorable interiors, giant architectural editor, fully 3D runtime requirement, ubiquitous procedural buildings, whole-building hand-painted composite as the only gameplay layer, or AI image treated as automatically modular/game-ready.

**Next visual target:** one small roof room at **true gameplay zoom**, with real layered 2D art and a character silhouette, then upper landing, then south apartment, then the kiosk. See [production pipeline](../art/3D_AUTHORED_2D_PRODUCTION.md).
