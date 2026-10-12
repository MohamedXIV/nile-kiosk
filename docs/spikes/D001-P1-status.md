# D001 P1 — Dialogue Manager integration

**Status:** P1 implementation merged into `main` via [PR #9](https://github.com/MohamedXIV/nile-kiosk/pull/9); headless integration tests passed.
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

**Evidence:** [GitHub Actions run #38308027392](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38308027392) on Godot 4.6.3: P0 4/4 groups PASS, Dialogue Manager P1 3/3 groups PASS, project import and both headless scene startup smoke steps PASS. Original first P1 CI failed because the addon autoload was not registered in headless runtime; fixed explicitly in `project.godot` and retested successfully.

**Residual:** the P1 test process logs `ObjectDB instances leaked at exit` and `3 resources still in use at exit` despite exit 0. Treat as cleanup investigation; not a claim of leak-free shutdown. No Web export / save/load pass claimed.
