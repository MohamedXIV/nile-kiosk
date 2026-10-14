# Game vision — Nile Kiosk

**Design status:** working direction, updated 2026-10-13. Agreed experience and proposed technical values are recorded separately in [the decision register](DECISION_REGISTER.md). This document records intended experience rather than implementation claims.

**Delivery warning:** This is an experience vision, not evidence that all features are implemented. Read [Design-to-Implementation Traceability](design/DESIGN_IMPLEMENTATION_TRACEABILITY.md) and the six associated specifications for missing behavior and work issue links. SYS P0–P7 verify their declared domain scope, **not** the entire player experience.

## Premise and emotional core

A player runs a small tea-and-food kiosk by the Nile, earns enough to cover daily living, knows people by seeing them repeatedly, and gradually makes a small rented apartment feel like home.

The fantasy is **modest stability, personal dignity, small pleasures and the ability to have an unhurried evening**. The game does not equate low income with ugliness. It should not coerce every quiet moment into a quest, progression meter, or monetized action.

## Time and place

- Egypt, evocative of **roughly 2000–2005**, without a specific date announced in-game.
- Kiosk by a Nile promenade; a small nearby/socially connected residential world; a separate rented apartment as a primary location.
- Correct period cues appear naturally: CRT TVs, radio/cassette, landline phones, early mobile phones, old cars, satellite dishes, window AC units, internet cafés where appropriate.
- The period is the *characters' present*, not a retro joke, VHS filter, or reference checklist.

## Residential building and home

- Player **starts in a rented 4×6 m = 24m² rooftop room** above a graceful, lived-in mid-century Egyptian building (roughly 1940s–1950s), around six residential storeys, on a relatively orderly, tree-lined street.
- Inspired by older Zeitoun, old Heliopolis, old Dokki, Manial and related Cairo residential architectural language, **without** copying elite Garden City residences or idealizing an untouched heritage museum.
- Proportions, tiled/terrazzo hall, old wooden shutters, stair railings, balconies and high ceilings can be lovely; aging is credible, not dereliction.
- **Upper floor:** a small shared stair landing with two **opposed apartment doors**. The northern neighbor's flat is not rendered inside; the **southern ~60m² flat** (10×6m nominal) faces the camera and is the player's possible later home.
- The 24m² **roof room is directly over part of the southern flat**, and starts comfortable though sparsely furnished; common roof access gives it emotional identity.
- **The upgrade is privacy, kitchen and bathroom of one's own**, not a mansion. The south flat is also small and initially sparsely furnished, beautiful in its bones. Player may add second-hand furniture and comforts over time.
- Housing economics is deferred; EGP 200 roof rent + EGP 1,000 flat rent were only discussion examples, potentially combined if both leases retained. Retention, owner approval and optional internal duplex stairs remain **open design questions**, not shipped systems.
- Shared roof, visible neighbor door, landing, stairs and per-unit reveal contribute to building credibility; precise furnishings and art are still under V001 review.

## Kiosk activity

- A handful of satisfying, tactile cooking/serving interactions, generally around 3–6 meaningful actions per item; no Overcooked-style constant pressure.
- Flexible operating rhythm, including the ability to close early or spend quiet time observing the river.
- Customers vary: takeaway visitors, counter patrons, table sitters, people drinking at the railing. Only a few should occupy the counter.
- Hunger, rest and mood may matter, but the game must not demand grinding numerical happiness. Longer-term wellbeing should be reflected in habits and lived conditions.

## Social simulation and dialogue

- NPCs have lives and conversations that do not require the player's attention.
- Regulars emerge from repeated contact, not from a loud `Friendship Level 3` notification.
- Two NPCs may converse while the player cooks; the player can hear them depending on distance and, at authored conversational boundaries, sometimes join.
- Interjection permission considers proximity, topic knowledge, familiarity and privacy. Some conversations are closed to intrusion.
- Short locally branching authored responses **reconverge**; avoid exponential trees.
- Facts, connections, recipes, opportunities and consequences belong to **canonical GameState**, not mutable dialogue runtime state.
- Silence, small talk and background chatter are content, not design failures.
- No voice acting is required. Dialogue appears in world space without pausing play.

## Visual direction — playable 2D isometric spaces

- Fixed top-down **oblique/dimetric 3/4** viewing angle, with **no camera rotation**. Zoom/pan is allowed to focus a room. Final 2:1 camera parameters are still a proposed migration target, not V001's current camera.
- **The player sees an inhabitable room, not a tiny isometric icon, web illustration, glossy mobile asset, or floating villa.** Use readable room structure, true player/prop scale, selective wear and modest Cairo detail. Pixel art is **not required**.
- **3D is the authored spatial guide; the delivered assets are genuine independent 2D sprites/layers**, with meaningful polished 2D art, registered pivots, furniture/occluder separation and neutral base textures where dynamic lighting matters. A beautiful render/single generated image is not sufficient.
- **Project Zomboid is a cutaway/room-readability reference**, not an art-style copy or assertion of identical engine implementation: reveal only the entered room, fade/hide ceilings and occluding upper walls, keep low sill, leave structural collisions intact, preserve neighboring door/shell.
- Runtime local lights and correct wall occluder variants should add warmth and night mood; static baked lamp shadows must not contradict toggleable lighting.
- Test: street/exterior → entry/stairs → shared landing/roof → roof room / later small south apartment → movable furniture and light switches → leave/restore shell.
- Distinguish per-floor world coordinates, unit IDs, asset pivots and pixels. **Spatial correctness enables modularity; visual approval remains independent of green tests.**
- [Visual Bible](design/VISUAL_WORLD_BIBLE.md), [Spatial Specification](architecture/HOME_BUILDING_SPATIAL_SPEC.md), [Art Production](art/3D_AUTHORED_2D_PRODUCTION.md).

## Non-goals

- Restaurant-chain management, endless optimization, and obligatory quests for each visitor.
- Smartphone-centered social interactions, contemporary Cairo styling, or luxury-apartment fantasy.
- Fully AI-generated narrative authority, invented player facts, and live voice-generation dependency.
- Rotating free-look camera, multiple art angles for each room, or realistic 3D physics unless a later test proves they add value.
