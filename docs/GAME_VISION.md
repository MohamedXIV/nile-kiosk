# Game vision — Nile Kiosk

**Design status:** working direction, updated 2026-10-12. This document records intended experience rather than implementation claims.

## Premise and emotional core

A player runs a small tea-and-food kiosk by the Nile, earns enough to cover daily living, knows people by seeing them repeatedly, and gradually makes a small rented apartment feel like home.

The fantasy is **modest stability, personal dignity, small pleasures and the ability to have an unhurried evening**. The game does not equate low income with ugliness. It should not coerce every quiet moment into a quest, progression meter, or monetized action.

## Time and place

- Egypt, evocative of **roughly 2000–2005**, without a specific date announced in-game.
- Kiosk by a Nile promenade; a small nearby/socially connected residential world; a separate rented apartment as a primary location.
- Correct period cues appear naturally: CRT TVs, radio/cassette, landline phones, early mobile phones, old cars, satellite dishes, window AC units, internet cafés where appropriate.
- The period is the *characters' present*, not a retro joke, VHS filter, or reference checklist.

## Residential building and home

- Player rents a tiny apartment in a **graceful, lived-in mid-century Egyptian building** (roughly 1940s–1950s), about five or six stories, on a relatively orderly, tree-lined street.
- Inspired by older Zeitoun, old Heliopolis, old Dokki, Manial and related Cairo residential architectural language, **without** copying elite Garden City residences or idealizing an untouched heritage museum.
- Proportions, tiled/terrazzo hall, old wooden shutters, stair railings, balconies and high ceilings can be lovely; aging is credible, not dereliction.
- The player's floor is unresolved (a high floor near the roof is appealing, but not canon).
- The apartment is small and initially sparsely furnished, **beautiful in its bones**. The player adds chairs, a fan, storage, a radio/TV, rugs, kitchen conveniences, plants, etc.
- Roof access may support quiet moments, but rooftop and floor access must be tested for scope and design value.

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

## Visual direction — still being tested

- Fixed top-down **oblique/dimetric 3/4** viewing angle, not a side view or strictly overhead 90-degree camera.
- Strong environmental authorship, calm believable lighting and period-specific detail; avoid uniform golden-hour AI-slop compositions and excessive decoration.
- Main candidate: **3D-authored assets rendered into interactive 2D layers** with separately interactable furniture and occluders.
- Test a multi-storey apartment cutaway: street/exterior → entry/stairs → chosen apartment floor → movable furniture → exterior restored.
- Distinguish per-floor logical position from render-layer order and projected screen coordinates; do not infer that floors are merely stacked flat sprites.

## Non-goals

- Restaurant-chain management, endless optimization, and obligatory quests for each visitor.
- Smartphone-centered social interactions, contemporary Cairo styling, or luxury-apartment fantasy.
- Fully AI-generated narrative authority, invented player facts, and live voice-generation dependency.
- Rotating free-look camera, multiple art angles for each room, or realistic 3D physics unless a later test proves they add value.
