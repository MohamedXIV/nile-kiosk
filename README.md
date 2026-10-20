# Nile Kiosk

*A quiet Egyptian life simulation about finding enough.*

## Try the early playtest

- **[Play in your browser or on a phone (landscape)](https://nile-kiosk-playtest.vercel.app/)** — hosted Web export; enable the `On-screen` touch pad in-game.
- **[Download Windows x64](https://github.com/MohamedXIV/nile-kiosk/releases/download/playtest-8dfb28ffac36/Nile-Kiosk-Windows-x64-playtest.zip)** — extract ZIP and run `NileKiosk.exe`; unsigned pre-release.
- [Full instructions, save behavior and known limitations](docs/PLAYTEST.md) — no final art, accessibility or human-phone approval implied.

**Status:** pre-production; **SYS P0–P7 production gameplay systems and whole-world Godot/Web persistence are verified and merged**, plus [CONTENT C0 transactional world imports](https://github.com/MohamedXIV/nile-kiosk/pull/42) and [PLAY C1/C2 Godot/Web room traversal](https://github.com/MohamedXIV/nile-kiosk/pull/46) (QA-only presentation, **canonical saved room/XY**, NPC hearing and rental-gated doors, verified v7→v8 save compatibility), plus [PLAY C3 player-operated kiosk service](https://github.com/MohamedXIV/nile-kiosk/pull/48) (multi-step recipe, real customer order, ledger settlement and mid-cook Web reload), and [PLAY C4 independent NPC demand](https://github.com/MohamedXIV/nile-kiosk/pull/50) (world-timed policy, offscreen order and expiry, Web save/reload), plus [PLAY C5 NPC social demand](https://github.com/MohamedXIV/nile-kiosk/pull/52) (actual heard facts and trusted-peer relations influencing demand, replay-verified), plus [PLAY C6 repeat-customer experiences](https://github.com/MohamedXIV/nile-kiosk/pull/54) (canonical actual paid service or missed wait changes future customer demand without a reputation meter). A dedicated production integration/QA scene runs, but this is **not yet a finished playable game** and V001 visual art is not approved.

Set in an intentionally unnamed early-2000s Egypt (roughly 2000–2005), Nile Kiosk follows a person who runs a modest riverside food-and-tea kiosk and returns home to a **4×6m rented rooftop room** in a graceful, aging Cairo residential building; a modest **~60m² private flat one floor below** is a possible later step.

The game is **not** a restaurant empire, a misery simulator, or a quest-driven visual novel. Its center is everyday work, a neighborhood with lives of its own, social familiarity, and the gradual pleasure of turning a sparse apartment into a home.

## Design pillars

1. **Enough, not infinite growth.** A sustainable routine and a comfortable home matter more than maximum revenue.
2. **A place where people exist without the player.** Customers talk, wait, eat, watch the Nile, leave, and sometimes return.
3. **Tactile, unhurried work.** Cooking and service have meaningful physical steps without turning the game into a speed challenge.
4. **The home is half the game.** A modest, beautiful pre-1960 apartment building and a tiny rentable home provide a refuge after work.
5. **A lived-in era, not a nostalgia museum.** People in the world treat the early 2000s as their present.
6. **Readable fixed-angle spatial play.** The player moves, rearranges furniture, and enters building cutaways within a coherent top-down world.

## Current direction — provisional

- **Visual experience:** fixed-angle **playable** angled-isometric rooms, not web-SVG/building icons, toy dioramas or giant detached luxury rooms. Camera pan/zoom may frame spaces but not rotate.
- **Asset workflow to validate:** **3D-authored, 2D-delivered**; Blender is measured spatial guide, distinct painted/cleaned game sprites are the deliverable; props/occluders/collisions are modular.
- **Projection:** existing V001 uses ~2.067:1; exact **2:1** is documented as a *proposed v0.1 production contract* only. Never mix their sprite generations.
- **Engine candidate:** Godot 4 + GDScript + Web export, **tested, not yet permanently selected**.
- **Narrative choice for next slice:** **Ink + inkgd** after D001 comparison; Dialogue Manager remains tested fallback; Ink Web hard-refresh state passed its scoped Chromium smoke.
- **Authored dialogue first:** optional AI flavor must never own canonical facts, choices, consequences or progression.

## What is actually implemented vs still missing?

**Start with [Design → Implementation Traceability](docs/design/DESIGN_IMPLEMENTATION_TRACEABILITY.md).** It marks *individual* player-experience behaviors as `NONE`, `FOUNDATION_ONLY`, `PARTIAL` or narrowly `VERIFIED_SCOPE`, separately from agreed/proposed design. **Verified SYS P0–P7 and PLAY C1–C6 are foundations, not proof that the player's day, Mood, recipe discovery, spatial social play, home comfort, markets or atmospheric UI are finished.** The remaining work is tracked in [Design Recovery epic #55](https://github.com/MohamedXIV/nile-kiosk/issues/55) and implementation issues [E1–E6](https://github.com/MohamedXIV/nile-kiosk/issues/56). Do not promote the experimental HTML experience or QA Godot circles/keys into shipping authority.

### Recovered player-experience specifications

- [Daily life and pacing](docs/design/DAILY_LIFE_AND_PACING.md)
- [Hunger, Rest, Mood and hidden wellbeing](docs/design/NEEDS_AND_WELLBEING.md)
- [Tactile cooking and social recipe learning](docs/design/COOKING_AND_RECIPE_LEARNING.md)
- [Spatial social space, conversations and knowledge](docs/design/SOCIAL_SPACE_AND_NARRATIVE.md)
- [Everyday economy and meaningful home upgrades](docs/design/EVERYDAY_ECONOMY_AND_HOME.md)
- [Atmosphere, UI and authentic game entry](docs/design/ATMOSPHERE_AND_PRESENTATION.md)

## Documentation and project memory

- **[Decision register — start here](docs/DECISION_REGISTER.md)**: agreed decisions vs provisional details vs implementation proof.
- **[System-First Architecture](docs/architecture/SYSTEM_FIRST_ARCHITECTURE.md)**: production gameplay architecture; never grow a one-day demo into the whole game.
- **[Systems Delivery Board](docs/systems/SYSTEM_DELIVERY_BOARD.md)** and **[World Time Contract](docs/systems/WORLD_TIME_AND_SCHEDULER.md)**: system ownership, dependencies and acceptance gates.
- **[Visual World Bible](docs/design/VISUAL_WORLD_BIBLE.md)**: what playable isometric means, art look and Cairo/home direction.
- **[Home building topology and cutaways](docs/architecture/HOME_BUILDING_SPATIAL_SPEC.md)**: 24m² roof room, two opposed doors, 60m² southern unit, roof/shared landing.
- **[3D-authored → 2D-delivered production workflow](docs/art/3D_AUTHORED_2D_PRODUCTION.md)**: modular sprites, pivots/crops, light masks, art acceptance.
- **[Isometric projection contract v0.1](docs/architecture/ISOMETRIC_PROJECTION_CONTRACT_V0_1.md)**: proposed math, manifest and migration rules.

## Other references

- [Game vision](docs/GAME_VISION.md)
- [Architecture and technical decisions](docs/TECH_DECISIONS.md)
- [Roadmap](docs/ROADMAP.md)
- [D001 — dialogue-engine comparison spike](docs/spikes/D001-dialogue-engines.md)
- [V001 — building cutaway and 2D rendering spike](docs/spikes/V001-building-cutaway.md)

Please do not treat exploratory art, scene layouts, or tool choices as signed-off final specifications.
