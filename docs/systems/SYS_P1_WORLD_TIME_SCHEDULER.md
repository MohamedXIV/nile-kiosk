# SYS P1 — Production World Clock & Durable Scheduler

Issue: [#25](https://github.com/MohamedXIV/nile-kiosk/issues/25). Contract: [WORLD_TIME_AND_SCHEDULER.md](WORLD_TIME_AND_SCHEDULER.md).

**Status: VERIFIED AND MERGED** — [PR #34](https://github.com/MohamedXIV/nile-kiosk/pull/34), merge `dd595102be652f1c01b214be9400b120a7dec8d2`. Godot 4.6.3 [P0/P1 and native regressions PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38390984961); [Chromium Ink/Dialogue Manager Web PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38390984743).

## Ownership and invariants

- `WorldKernel.dispatch` is the command boundary; `WorldKernel.advance_time(steps, command_id, actor_id)` is the single public time-advancement API. Neither an Ink session nor a Godot Timer owns time.
- `WorldState` v2 is the canonical replay-reconstructed state; `world_minute` is a nonnegative integer bounded to 2,147,483,647. Civil clock projections use 1,440 minutes per day, day index starting at zero. **No fictional calendar date, duration of gameplay day, NPC schedule, price, or working hours are set.**
- `time.advance` uses **explicit logical simulation steps**, not FPS or operating-system time. The rationalized gameplay adapter is responsible for choosing when to submit a command; do not call this once per frame by accident. The `time.rate.set` integer `minutes_per_step` policy (1..64; default 1) transforms steps to simulated minutes without floating-point accumulation. Pause rejects advances; resume restores advances. Zero steps is a genuine no-op (no consumed command ID). Invalid time/rate and overflow reject without mutating state.
- Jobs are scheduled at exact **absolute integer simulated minutes** with required `job_id`, `due_minute`, `priority`, `topic`, `data`, `every_minutes`. Repeating interval 0 is one-off. Job IDs cannot be reused even after completion/cancellation.
- Each advance executes all due intentions in order **due minute → priority (ascending) → creation sequence → job ID**, including every recurrence crossed. Event IDs and origin actor/command provenance survive replay; recurring jobs preserve cadence, including across midnight.
- Jobs retain terminal history: `pending | completed | cancelled`, number of executions, most recent fire ID and originating event sequence. Rescheduling affects pending jobs only; historic firings stay immutable.
- One `time.advanced` ledger event contains the deterministically calculated ordered `fires` array. Each firing is independently identifiable (`fire:<advance-sequence>:<ordinal>`) with its **actual due minute**, causation and topic. Its envelope has the time at which the advance began. This makes the complete advance atomic and verifiable during replay rather than publishing partial queued effects.
- `scheduled_events_after(revision)` provides a flat independent copy; `unacknowledged_firings(consumer_id, topic)` provides durable per-consumer delivery; `schedule.ack` is recorded as a canonical event. Different consumers can acknowledge the same firing separately. **Future domain consumers must apply effects and the fire-ID dedupe atomically within the canonical world command.** A standalone ACK does not pretend to provide exactly-once external filesystem/network side effects.
- To avoid unbounded work, an advance producing over 20,000 firings rejects atomically with `FIRING_LIMIT`; split time advances for exceptionally dense simulated horizons. This is not a content or balance limit.

## Persistence / corruption

Snapshot schema v2 includes version, seed, monotonic time, pause/rate policy, entire retained job registry, all consumer acknowledgements, facts, P0-compatible command receipts, and event log. JSON parsing may convert integral tokens into floats; the canonical input normalizer reconstructs safe integer representations and sorts JSON object keys. Restore validates every historical command **and re-derives firing intentions**, compares the complete materialized snapshot against replay, then swaps state only after all checks pass. Version-1 P0 snapshots are **explicitly rejected**, not silently fabricated into scheduler-enabled worlds. Saves use temp-write/flush and rename as in P0.

## Commands and contracts

```gdscript
var world = WorldKernel.new(seed)
world.dispatch({"id":"job-1", "actor_id":"npc:director", "kind":"schedule.create",
  "payload":{"job_id":"visit:samir:01", "due_minute":720,
             "priority":100, "topic":"npc.arrive",
             "data":{"npc_id":"samir"}, "every_minutes":1440}})
world.advance_time(720, "advance-1", "system:clock")
var intentions = world.unacknowledged_firings("npc.presence", "npc.arrive")
# Future NPC consumer validates and applies domain-specific effects atomically.
# P1 only verifies scheduler delivery/acknowledgement, never invents NPCs.
```

Available command kinds: `knowledge.grant` (P0), `time.advance`, `time.pause`, `time.resume`, `time.rate.set`, `schedule.create`, `schedule.cancel`, `schedule.reschedule`, `schedule.ack`. Commands require unique IDs and actor provenance. Identical retries return the stored receipt; conflicting reuse rejects.

## Acceptance

`tests/test_sys_p1.gd` checks calendar/midnight, multi-day, zero/negative/fractional/overflow, pause/rate, same-time priority and insertion order, cancel/reschedule/completion, recurring step-size equivalence, independent consumer ACK, durable mid-schedule disk JSON, canceled-job restoration, forged queue/receipt/event/firing corruption rejection, replay byte stability, provenance and P0 knowledge preservation. Existing `tests/test_sys_p0.gd` and D001/V001 tests still run in the **existing** Godot workflow. No Web presentation changed in this PR, so Chromium Web checks remain prior unaffected regression.
