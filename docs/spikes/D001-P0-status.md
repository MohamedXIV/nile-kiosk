# D001 P0 — implementation status

**Merged:** PR #5 → `main` (`eae37fc51e4beb6b05f4c416512355b755242083`)
**Scope:** Shared mock sessions and deterministic headless acceptance; no third-party runtime yet.

## Included

- Godot 4 standard/GDScript fixed-camera 2D code-drawn kiosk mock.
- Keyboard input: arrows/WASD movement; K to grant match knowledge; 1 to interject in an allowed window; E to prepare tea at counter.
- Two authored concurrent conversation fixtures on independent clocks, separate A and B session cursors.
- Canonical GameState with exactly-once knowledge application and event traces.
- CLI headless tests for session independence, gating, ignored interactions, tea workflow and deterministic replay.
- One GitHub Actions smoke workflow for public repository PRs and main changes touching runnable code. No export job until Web export is part of the acceptance scope.

## Explicitly not yet implemented

- Dialogue Manager / Ink integration.
- Save/load persistence and actual Web export, for subsequent phases.
- Arabic / RTL and authored game art.
- Full spatial audio, full NPC AI or apartment environment.

## Acceptance evidence

**P0 headless smoke PASS** on [GitHub Actions run #38307147917](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38307147917), Godot `4.6.3.stable.official`: import succeeded, 4/4 deterministic test groups passed, headless main scene startup succeeded. This does **not** constitute visual acceptance, save/load, Web export or addon comparison. Subsequent push-to-main CI should also be inspected independently.
