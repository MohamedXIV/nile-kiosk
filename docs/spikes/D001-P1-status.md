# D001 P1 — Dialogue Manager integration

**Status:** integration branch; tests awaiting CI result.
**Issue:** #6; parent #2.
**Engine:** Godot 4.6.3 Standard/GDScript, Compatibility.
**Addon:** Nathan Hoad Dialogue Manager **v3.10.4**, commit `5487c524b9eac303b059e5859e2980b134c59d79` (pinned and installed on CI).

Why v3.10.4? The published v4.1 release targets a newer Godot than the currently pinned Godot 4.6.3 baseline. Don't accidentally conflate an addon upgrade with test results.

## Development

After clone run `bash tools/install-dialogue-manager.sh` once to install the pinned addon into ignored `addons/dialogue_manager/`. Open/import project in Godot; the editor plugin is enabled by `project.godot`.

- Main scene `scenes/kiosk_spike.tscn`: original P0 mock.
- `scenes/dialogue_manager_spike.tscn`: same top-down visual world, game controls and world state, but uses the real Dialogue Manager adapter.
- Authored source: `content/dialogue_manager/*.dialogue`.
- CI imports plugin, executes original P0 deterministic tests, new P1 integration tests, and boots both scenes.

## Boundaries

- The addon supplies actual dialogue authoring, compiled lines, response conditions and branching. It is not a replacement for the session clock or GameState.
- Session IDs, independent next IDs, choice timer and two separate resources live in `dm_conversation_session.gd`. Proximity/knowledge and persistent world effects stay in shared orchestrator.
- Save/load and actual Web export are **not** part of the P1 claim; tracked in issue #8.
- Arabic/RTL remain deferred. No full art, voice or advanced NPC AI.

Record CI run IDs and any failures before treating this phase as verified.
