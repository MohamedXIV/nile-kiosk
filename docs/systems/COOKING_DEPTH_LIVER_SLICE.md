# First cooking expansion: Egyptian liver sandwich

**Status:** domain implementation and integration contract; player scene integration belongs to GPT-6. This is the user-authorized Game-First expansion after the bounded E1–E6 closeout, not a reopened #58 or #55. Human-gated art #20 remains separate. All quantities, timings, sensory scores and prices below are **PROPOSED** tuning values.

## Design and authority

One sandwich has three preparation stages: season liver/garlic, pan-sear with pepper/oil and a deliberate turn, assemble in bread with lemon. A turn is an action **inside** an active cooking step: it does not complete that step or create an item. The second face requires its own elapsed work. This differs from the tea kettle/pour handoff.

P3 owns inputs, reservation, station occupancy, the action event, completion, produced item and event-derived quality. Existing P1 time, P5 paid supplies and WorldKernel replay remain authoritative. No UI-owned state, second clock, random grade, XP, free ingredient or cash grant is introduced. Godot geometry, animation, audio and input remain the other worker's presentation responsibility; this domain extension contains no spatial/physics substitute.

## Content and paid acquisition

Call `preload("res://scripts/core/cooking_content.gd").install(world)` after the existing opening catalog has defined `bread`. It preflights the whole trusted pack against a replayed candidate, then synchronously dispatches its canonical commands. It does not replace/reset the live world, overwrite definitions or alter old event streams. A content conflict fails before any live installation event. Stable command IDs make repeated installation a true no-op.

The existing C0 importer builds a **new** world and does not allow supply-offer registration; using it here would reset saves or require shared-file edits. The narrow cooking installer instead reuses the existing Kernel dispatch seam and whitelists only ingredient/recipe/station definitions and paid offer registration. It has no stock/funding/gameplay authoring command.

Pack: `content/cooking/nile_liver_sandwich.v1.json`. Recipe: **`liver_sandwich`**. Stations: **`sandwich_board`** (`prep_board`) and **`sandwich_pan`** (`frying_pan`). These are authored P3 station definitions, not paid appliance/visual placement features.

| Ingredient ID | One sandwich | Paid lot | Cost, minor units |
| --- | ---: | ---: | ---: |
| `liver` | 100 g | 400 g | 1200 |
| `garlic` | 3 g | 12 g | 40 |
| `green_pepper` | 20 g | 80 g | 100 |
| `cooking_oil` | 5 ml | 20 ml | 60 |
| `lemon_juice` | 5 ml | 20 ml | 40 |
| `bread` (existing ID/unit) | 1 piece | 4 pieces | 120 |

Each public offer ID is `sandwich:<ingredient_id>`. Use existing `supply.purchase {offer_id}` as `player` at the real kiosk. Six independent transactions cost **1560** and advance **six canonical minutes** in total. Purchases are not an atomic basket; display their individual outcomes. Existing initial bread remains legitimate opening stock. No purchase is silently executed by installation or preparation. Offers have explicit finite four-portion lots, one resolution per offer, full-day collection windows, no fabricated referral/knowledge, and existing debit/receipt/idempotency checks. No restocking system is added.

## Stable canonical cooking interface

Start intentionally:

```gdscript
world.dispatch({"id": unique_command_id, "actor_id":"player", "kind":"cook.start",
    "payload":{"job_id":unique_job_id,"recipe_id":"liver_sandwich",
               "deadline_minute":current_world_minute + 60}})
```

| Step index | P3 operations | Timing/input result |
| --- | --- | --- |
| 0: season | `cook.step.begin {job_id,station_id:"sandwich_board"}`, then `cook.step.finish {job_id}` | Consumes reserved liver + garlic; one world minute before finish. |
| 1: sear | `cook.step.begin {job_id,station_id:"sandwich_pan"}` | Consumes reserved oil + pepper; pan remains occupied. |
| 1: turn | **`cook.step.action {job_id,action_id:"turn"}`** | Earliest after two active minutes; preferred through minute six inclusive. Later is accepted and affects sensory quality. |
| 1: lift | `cook.step.finish {job_id}` | Requires the committed turn and at least two further active minutes. Time alone cannot substitute for turning. |
| 2: assemble | Begin on `sandwich_board`, then finish | Consumes reserved bread + lemon; zero extra work minutes, produces one actual item. |

Existing `cook.step.interrupt/resume`, cancellation, station exclusivity, deadlines and shelf expiry apply. A caller may group routine begin/finish operations into a small number of presentation gestures; inspect canonical state after any partially successful group. Never maintain a separate progression counter.

### New reusable step schema

An ordinary recipe step is unchanged. An opted-in step adds:

```json
"technique": {"action_id":"turn", "earliest_minutes":2, "finish_minutes":2}
```

`work_minutes` on that step is the **preferred latest action time**, not permission to bypass the gesture. Earliest and finish durations must be positive integral values; earliest must not exceed work_minutes. No liver/recipe ID is hardcoded into action validation.

New canonical event: **`cook.step_actioned`**. Its normal envelope records actor, command ID, event ID, sequence and world minute. Request is `{job_id,action_id}`; effect is `{action_id,ready_minute}`. Effect ready minute is the action minute plus finish duration. The job adds `step_action {action_id,world_minute,event_id}` until the step finishes; ready minute then represents post-action readiness. No top-level save schema or legacy field change is needed.

### Read-only cue data for GPT-6

Use `world.cooking_view()` and the canonical world minute. Job `stage`, `step_index`, `station_id`, `ready_minute` and optional `step_action` are the source for prompts:

- Active technique step **without** `step_action`: display its action; earliest = `ready_minute - (work_minutes - earliest_minutes)`, preferred by `ready_minute`. Do not display “ready to finish” for this state.
- Active technique step **with** `step_action`: display lift/finish, ready at `ready_minute`.
- Interrupted: display resume using the existing command. Remaining work and whether the turn occurred survive disk reload.
- Waiting: next step may begin at its matching free station. Completed: use the actual `item:<job_id>` and `world.prepared_quality(item_id)`.

No shared architectural hook is pending: existing WorldState delegates P3 command/event kinds, and existing Kernel projections expose everything needed. `world_kernel.gd` and `world_state.gd` are unchanged.

### Rejections and retries

New action accepts only `player` and exactly `{job_id,action_id}`. Important codes: `UNAUTHORIZED`, `INVALID_PAYLOAD`, `UNKNOWN_PREPARATION`, `INVALID_STAGE`, `ACTION_NOT_SUPPORTED`, `WRONG_ACTION`, `ACTION_ALREADY_DONE`, `ACTION_TOO_EARLY`, `TIME_OVERFLOW`. Finish without the required gesture returns `ACTION_REQUIRED`. Existing station, stock, readiness and identity failures remain unchanged. A repeated successful command ID returns its original receipt; a new repeated-action/completion ID is rejected without extra consumption or item creation.

## Understandable quality, not hidden randomness

`prepared_quality` derives sensory results only for a real completed item and its verified event history. Tea's existing policy is unchanged; ordinary bread still has no invented grade. Technique recipes additionally expose `action_late_minutes` and `technique_actions`, alongside score/grade, finishing lateness, handoff delay, interruptions and the actual completion event ID.

Time on heat is summed over active begin/resume intervals. Off-pan interruption time does not burn food, but interrupts remain visible; interrupt/resume cannot erase prior over-searing. PROPOSED score: `max(25,100 - 8×(finish_late + action_late) - 2×handoff - 10×interruptions)`, with bounded component totals and `good ≥85`, `okay ≥60`, otherwise `rough`. The score changes no cash, needs or relationships.

Recorded production cases: turn after 2/9/14/2 pan minutes, then cook the other face for 2 → **good100 / okay76 / rough36 / good100**. The final good attempt demonstrates repeatable improvement without a permanent skill number or silently granted learning. Minimum two minutes per face is a proposed cozy game timing abstraction.

## Integration work reserved for GPT-6

1. Call the installer after normal catalog bootstrap, including restored worlds; handle content conflicts without wiping saves.
2. Package the cooking JSON in Web exports (`content/cooking/*.json` must be included; verify the existing export filter when integrating).
3. Expose the existing paid offer choices and their individual costs/results; enforce real proximity in the player controller as existing actions do.
4. Connect intentional preparation, season/sear, turn, lift and assemble gestures to the commands above; derive cues from canonical job/time and preserve them over reload. No new keybindings or HUD are supplied here.
5. Present sensory explanations from `prepared_quality`, consumed inputs and the actual item. Use Godot animation/audio for tactile feedback.
6. Verify default-scene Native/Web play, actual pacing and hard reload after integration. No browser-playable or human feel acceptance is claimed by this domain batch.

No new customer demand, sandwich price/sale behavior, needs nutrition entry or conversation knowledge is configured. Existing `cook.item.use` can claim the physical item once, but is **not** a Hunger effect. If later teaching is desired, earn it through actual P2/P6 conversation events; installing this assigned starter recipe does not pretend a lesson happened. Additional foods, supplier restocking, sale/customer integration and final balancing remain outside this slice.

## Executable evidence

`godot --headless --path . --script tests/test_cooking_depth.gd` exercises actual starter-world purchases, four full preparations, exact consumption and item identity, good/okay/rough outcomes, deterministic recovery, day crossing, mid-pan/interrupted and final disk replay, strict rejection, retries, overflow, cancellation/deadline/shelf boundaries and event/state forgery. No browser storage or invented production ingredients are seeded.

The same cases are called by `tests/test_sys_p3.gd`, preserving existing shared workflow coverage without editing workflow definitions. Run all `tests/test_*.gd` and existing startup scenes before delivery; exact results and final SHA belong to the PR/delivery evidence. No independent reviewer is claimed: the assignment explicitly prohibited delegation, so implementation review is local and GPT-6 owns PR review/integration.
