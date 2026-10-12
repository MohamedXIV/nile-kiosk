# D001 P0 — implementation status

**Branch:** `spike/d001-p0-shared-godot-harness`
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

Pending actual CI execution. Do not mark P0 PASS until a pinned Godot build runs the tests.
