# World Time & Scheduler — production contract

**Status:** production P1 implementation under verification (issue #25). D001's \`tick_number\` is a spike fixture and **must not become the world's calendar**.

**Goal:** exactly one deterministic game clock whose time advances explicitly, drives NPC schedules and cooking/order deadlines, and can be saved/reloaded halfway through any activity.

## Canonical time

- Store **absolute integer simulated minutes or finer integer ticks** as a monotonic counter, not formatted clock strings or accumulating floats. Choose minute/tick resolution deliberately before code; avoid claiming an unchosen game-day length.
- Derive \`day_index\`, \`minute_of_day\`, named calendar fields, daypart and opening hours from that integer via one calendar policy. Day/year/era **fictional specifics not agreed yet**; do not assert a date.
- A time jump is a deterministic sequence of events crossing scheduled boundaries. Advance \`0\` is a no-op; negative/overflow advances are rejected, not converted silently.
- Time scale / sleep / pause are **commands/policies**, not \`Engine.time_scale\` as the canonical source of truth.
- Pausing the game doesn't necessarily pause an individual authored Ink choice timer; that policy must be explicit, not an accidental frame update.

## Scheduler contract

- Durable jobs use stable IDs, exact due game-time, causation/provenance, optional repeat rule. If two jobs are due together, define **priority → stable sequence → event ID** ordering.
- Once-only effects do not fire twice after save/load. Canceled jobs cannot execute. Jobs in the past are rejected or handled by a documented recovery policy.
- An advance that skips many hours/days produces the **same ordered domain events** as multiple equivalent small advances (unless an explicitly documented system boundary changes such semantics).
- Recurring daily schedules survive midnight without drift; no timer that accumulates unbounded floating point seconds.
- Scheduler emits **domain intentions/events**, not raw Godot \`Timer\` nodes, scene actions or direct Ink mutations.
- No missing/duplicate NPC arrival, kiosk closure, order expiry, rent due or recipe completion merely because game was backgrounded or time-jumped.

## Integration ownership

\`WorldKernel.advance_time\` is the exclusive public way to change clock. NPC scheduler registers arrival/movement commitments; kiosk operations register time-bound prep; orders register wait/abandon deadlines; housing schedules obligations. They do **not** each increment their own wall clock.

Events carry \`world_time\`, stable \`sequence\`, \`event_id\` and \`source\`. Domain consumers apply idempotently; system services should not call one another's private mutation routines.

## Tests required before *Time/Scheduler* issue closure

1. Tick/midnight rollover (including large advance and zero), overflow/negative/invalid input rejection.
2. Strict event order for equal due times with tie priority and stable ID.
3. Cancel, reschedule and recurring jobs across at least multiple days, no duplicate execution.
4. Large-step/small-step equivalence and deterministic JSON or digest event stream.
5. Save/load **mid-day and mid-schedule**, no lost/duplicated jobs, versioned migration/error behavior.
6. Multiple domain consumers receiving the same event (NPC presence + order deadline) and exactly-once effect semantics.
7. Explicit pause/resume and time-scale boundaries, with frame-rate independence and no fictional calendar/date hardcoded unreviewed.
8. Godot headless; Web integration whenever visible clock or suspend/resume exists.

Implement as domain logic with minimal engine dependencies. Do **not** use this document as permission to invent economic values, NPC schedules or exact day duration.
