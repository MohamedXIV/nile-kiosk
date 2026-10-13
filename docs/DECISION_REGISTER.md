# Nile Kiosk — Decision register (design vs proof)

**Updated 2026-10-13.** This is the durable orientation map for future authors and agents; consult the linked detailed specifications before editing the game. **Agreed experience ≠ shipped implementation ≠ final art approval.**

| Topic | Design direction / commitment | Status and caveats |
| --- | --- | --- |
| Game premise | Quiet Egyptian riverside kiosk and home; modest stability rather than wealth/grind | **Game vision agreed** |
| Setting | Cairo/Nile neighborhood, unnamed roughly 2000–2005, lived as present | **Game vision agreed**; details authored later |
| Home progression | Start in **4×6m = 24m²** rooftop room; later aspire to a **10×6m ≈60m²** small separate south apartment | **Design agreed**; economy is not implemented |
| Building | ~six-storey pre-1960 residential block, shared top landing and **two facing doors**. North unit only entrance; player's unit south (camera side) | **Design agreed**, exact room detailing still art/prototype work |
| Housing economics | Roof room and flat could each have rent; examples EGP 200 + EGP 1000 | **Illustrative numbers only**; no locked balance or double-lease decision |
| Duplex | Optional future internal stair between the south apartment and room directly above | **Only a possibility**; not required feature and would demand plausible structural/owner permissions |
| Visual target | Fixed-angle playable, cozy, lived-in Egyptian isometric-style cutaway, **not an SVG icon / miniature villa** | **Direction agreed**; final 2D painted style NOT approved |
| Art workflow | 3D as authored **spatial guide**, 2D as delivered layered modular game assets with actual cleanup and pivots | **Chosen direction for next experiments**; individual packs not yet production-ready |
| Projection | One consistent affine mapping, fixed orthographic view, transparent layers with contact anchors | **Requirement agreed**; exact **2:1** parameters in [v0.1](architecture/ISOMETRIC_PROJECTION_CONTRACT_V0_1.md) are **proposed**, current PR #20 is ~2.067:1 |
| Cutaways | Unit-aware roof/upper-front-wall hiding, low wall silhouettes, collisions kept, neighbor opaque | **Design agreed**; production-quality implementation to verify |
| Lighting | Local runtime lights/shadows with neutral base, optional normal/emissive maps | **Target agreed**; current lamp toggle is only a spike |
| Engine | Godot 4/GDScript currently validating fixed-camera 2D presentation; browser build highly desirable | **Provisional** until V001 visual sign-off |
| Narrative | Two independent NPC conversations, proximity/familiarity/knowledge-gated interjection; persistent canonical state | **Design agreed** |
| Narrative implementation | Ink/inkgd selected after D001 comparison, Dialogue Manager fallback | **Chosen baseline for next slice**; browser reload verified for Ink |
| Language | Arabic/RTL not in first D001 test fixtures | **Deferred**, not cancelled or claimed complete |
| Art review | Real Web screenshots and final user approval required beyond green tests | **Mandatory gate**, open on V001 PR #20 |

## Verified against live GitHub when written

- [PR #20 — V001 actual Blender/Godot cutaway spike](https://github.com/MohamedXIV/nile-kiosk/pull/20): open; 24 semantic renders, room/roof/landing/south unit structure and basic dynamic lamp have passed engineering/browser testing in earlier runs; **style and visual acceptance pending**.
- [PR #22 — this documentation and proposed exact 2:1 parameters](https://github.com/MohamedXIV/nile-kiosk/pull/22): docs reference, not migrated runtime.
- [V001 issue #19](https://github.com/MohamedXIV/nile-kiosk/issues/19): separate artist/visual review required.
- [D001 decision](spikes/D001-DECISION.md) and [browser refresh persistence](spikes/D001-browser-refresh.md): prior proof of genuine Ink Web save/refresh within covered smoke scope, not claim of cross-device permanence.

## Next actionable order

1. Keep PR #20's working proof intact while **reviewing source art at actual Web gameplay size**. Do not merge on numeric checks alone.
2. Align/apply projection v0.1 only in a coherent gated Blender + Godot migration if its exact 2:1 advantage justifies the change; no mixed generations.
3. Deliver **V001-A roof-room 2D modular art pack** with valid pivots, named layers, cutaway, light response, collision and one movable saved prop.
4. Review actual screenshots for scale, readability, lived-in Cairo character and style before expanding to the two-door landing and 60m² flat.
5. Return to the **kiosk** and a complete ordinary day once home spatial/art language is demonstrated.

**Not decided:** exact rent progression and retention policy, duplex, specific final painted technique, full normal-map pipeline, alternate engine commitment, full opening date of residence and neighbor's character. Do not present these as canon.
