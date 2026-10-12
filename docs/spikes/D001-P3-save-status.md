# D001 P3 — save/load roundtrip

**Status:** implementation proposed in PR, acceptance awaiting CI.

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
