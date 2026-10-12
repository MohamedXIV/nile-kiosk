# D001 P3 — save/load roundtrip

**Status:** merged via [PR #13](https://github.com/MohamedXIV/nile-kiosk/pull/13); Godot native disk save/load verified for both engines (Web page-reload persistence is not verified).

Purpose: prove that either narrative candidate resumes two independent NPC sessions while a player choice is pending and the other conversation progresses.

## Save format

- Stable schema version and dialogue engine discriminator.
- Canonical facts, idempotency effect IDs, world ticks, player location, three-step tea state and event history.
- Separate per-conversation timers and pending-choice branch positions.
- Dialogue Manager: store stable line ID and pending response's `next_id` (never serialized plugin objects).
- Ink: store `InkPlayer.get_state()` story state and session-local timing/choice metadata; restore after story is ready.

## Tests

Each real engine in a headless project with installed add-ons and compiled content:
1. Save and read actual `user://` disk JSON in the middle of football choice while rumor is active.
2. New model restores same pending choice, facts, clock and event log.
3. Visit other table while A still awaits answer, hearing Hassan shop rumor in B.
4. Save and restore again, verify once-only knowledge and idempotency tokens.
5. Pick matching interjection in original and restored worlds and compare deterministic event traces through completion.
6. Restore completed session and verify no old dialogue/event replay.
7. Reject snapshot labeled as different dialogue engine.

English-only fixtures; RTL deferred. This **does not yet** prove browser page reload persistence or visual/UI reconstruction; test browser persistence separately before final D001 recommendation.

## Results

- [Native save/load CI run #38310579858](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38310579858): **D001 P3 Save/Load PASS** for Dialogue Manager and Ink, as well as P0, P1 and P2 regressions and headless scene startup checks.
- [Chromium full kiosk CI run #38310579864](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38310579864): both Dialogue Manager and Ink exports pass two-session-and-tea smoke tests after save codec changes.
- Fixes made during work: normalize integer tick/step fields when reading `JSON.parse_string`; align rumor-session initial timing so a player can hear it during an independent interjection window.
- Residual: Godot headless runner reports resources-in-use warnings at process exit, not correlated with failing app behavior. No user-level Web persistence across browser refresh has been proven.
