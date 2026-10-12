# Nile Kiosk

*A quiet Egyptian life simulation about finding enough.*

**Status:** pre-production — design and technical spikes, not a playable game yet.

Set in an intentionally unnamed early-2000s Egypt (roughly 2000–2005), Nile Kiosk follows a person who runs a modest riverside food-and-tea kiosk and returns each evening to a small rented apartment in a graceful, aging Cairo residential building.

The game is **not** a restaurant empire, a misery simulator, or a quest-driven visual novel. Its center is everyday work, a neighborhood with lives of its own, social familiarity, and the gradual pleasure of turning a sparse apartment into a home.

## Design pillars

1. **Enough, not infinite growth.** A sustainable routine and a comfortable home matter more than maximum revenue.
2. **A place where people exist without the player.** Customers talk, wait, eat, watch the Nile, leave, and sometimes return.
3. **Tactile, unhurried work.** Cooking and service have meaningful physical steps without turning the game into a speed challenge.
4. **The home is half the game.** A modest, beautiful pre-1960 apartment building and a tiny rentable home provide a refuge after work.
5. **A lived-in era, not a nostalgia museum.** People in the world treat the early 2000s as their present.
6. **Readable fixed-angle spatial play.** The player moves, rearranges furniture, and enters building cutaways within a coherent top-down world.

## Current direction — provisional

- **Preferred visual candidate:** fixed overhead oblique/dimetric 2D presentation; neither strict 2:1 isometric nor a rotating camera is mandatory.
- **Asset-production candidate:** model environments and interactive props in 3D, then render coherent 2D layers/sprites; compare against hybrid 3D runtime before committing.
- **Engine candidate under test:** Godot 4 + GDScript + Compatibility/Web export. **Not selected yet.**
- **Narrative candidates under test:** Dialogue Manager and Ink/inkgd; neither has been selected.
- **Authored dialogue first:** optional AI flavor must never own canonical facts, choices, consequences or progression.

## What is next?

- [Game vision](docs/GAME_VISION.md)
- [Architecture and technical decisions](docs/TECH_DECISIONS.md)
- [Roadmap](docs/ROADMAP.md)
- [D001 — dialogue-engine comparison spike](docs/spikes/D001-dialogue-engines.md)
- [V001 — building cutaway and 2D rendering spike](docs/spikes/V001-building-cutaway.md)

Please do not treat exploratory art, scene layouts, or tool choices as signed-off final specifications.
