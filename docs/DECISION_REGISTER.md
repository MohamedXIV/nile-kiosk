# Nile Kiosk — Decision register (design vs proof)

**Updated 2026-10-14.** This is the durable orientation map for future authors and agents; consult the linked detailed specifications before editing the game. **Agreed experience ≠ shipped implementation ≠ final art approval.**

| Topic | Design direction / commitment | Status and caveats |
| --- | --- | --- |
| Game premise | Quiet Egyptian riverside kiosk and home; modest stability rather than wealth/grind | **Game vision agreed** |
| Setting | Cairo/Nile neighborhood, unnamed roughly 2000–2005, lived as present | **Game vision agreed**; details authored later |
| Home progression | Start in **4×6m = 24m²** rooftop room; later aspire to a **10×6m ≈60m²** small separate south apartment | **Design agreed**; SYS P5 implemented canonical economy/rental contracts, but actual rent amounts and retention policy remain undecided |
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
| Implementation strategy | **System-first, NOT vertical-slice-first**: full bounded production systems with persistence, deterministic behavior and interface contracts | **Agreed 2026-10-13**; SYS P0 kernel merged via [PR #33](https://github.com/MohamedXIV/nile-kiosk/pull/33), SYS P0–P7 verified and merged; CONTENT C0 authored bundles merged via [PR #42](https://github.com/MohamedXIV/nile-kiosk/pull/42). D001/V001 remain separate spikes |

## Verified against live GitHub when written

- [PR #20 — V001 actual Blender/Godot cutaway spike](https://github.com/MohamedXIV/nile-kiosk/pull/20): open; 24 semantic renders, room/roof/landing/south unit structure and basic dynamic lamp have passed engineering/browser testing in earlier runs; **style and visual acceptance pending**.
- [PR #22 — this documentation and proposed exact 2:1 parameters](https://github.com/MohamedXIV/nile-kiosk/pull/22): docs reference, not migrated runtime.
- [V001 issue #19](https://github.com/MohamedXIV/nile-kiosk/issues/19): separate artist/visual review required.
- [D001 decision](spikes/D001-DECISION.md) and [browser refresh persistence](spikes/D001-browser-refresh.md): prior proof of genuine Ink Web save/refresh within covered smoke scope, not claim of cross-device permanence.

## Next actionable order — authored content and actual playable integration (2026-10-13)

1. SYS P0–P7, Content C0 and PLAY C1/C2/C3/C4/C5/C6 are done; PLAY C3 [PR #48](https://github.com/MohamedXIV/nile-kiosk/pull/48) adds real game-input cooking/orders/payment on the QA scene, while [PLAY C4 PR #50](https://github.com/MohamedXIV/nile-kiosk/pull/50) adds world-time customer demand independently of player UI; [PLAY C5 PR #52](https://github.com/MohamedXIV/nile-kiosk/pull/52) makes these demand probabilities conditionally depend on NPC knowledge and NPC-to-NPC trust at the scheduled world minute, while [PLAY C6 PR #54](https://github.com/MohamedXIV/nile-kiosk/pull/54) derives visit memory from real paid/abandoned service, with no parallel reputation state. Real character writing and balance remain pending. Use [the production world importer](systems/CONTENT_C0_WORLD_BOOTSTRAP.md) to author real NPC/recipe/location data; the C0 QA catalog is **not balanced gameplay content**.
2. Connect real gameplay input/navigation/interaction presentation to the already-owned domain commands. Do not promote P7 test-fixture prices/NPCs or the D001 scene to a shipped default.
3. Art PR #20 can remain open for visual review without blocking headless domain development. Keep agreed 24m² roof room, 60m² south flat, 3D→2D asset direction and pending 2:1 migration documented for later.
4. Once complete systems exist, integrate them into gameplay without rewriting their truth or adding a second controller per domain.

**Not decided:** exact rent progression and retention policy, duplex, specific final painted technique, full normal-map pipeline, alternate engine commitment, full opening date of residence and neighbor's character. Do not present these as canon.
