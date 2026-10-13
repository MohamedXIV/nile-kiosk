# SYS P3 — Production Cooking, Inventory and Stations

**Status: VERIFIED / MERGED** — [PR #36](https://github.com/MohamedXIV/nile-kiosk/pull/36), squash merge `72f6f826f21fc276a5752dd81c727b2d10de0ffc`. Verified [Godot 4.6.3 P0–P3/D001/V001 PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38404606973), [Chromium Ink/DM + refresh PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38404606957), security check green.

Tracks [#27](https://github.com/MohamedXIV/nile-kiosk/issues/27); production code `scripts/core/cooking_world.gd` (owned domain) integrated through `scripts/core/world_state.gd` / `world_kernel.gd`, not D001 `tea_steps`.

## Authority and scope

Production **WorldKernel** emits replay-validated, command-ID-idempotent events. `CookingWorld` is the canonical state of ingredient definitions and units, stock, data-driven recipes, stations, active preparations, physical finished items, and waste. Its *entire* state is in save envelope v4 and is rebuilt from the event log. No money, NPC orders, service, balancing, quality scoring, sprite cooking animations, recipe counts or economics are invented here.

Quantities are positive **integer minor units** of a registered ingredient: e.g. a recipe can request 2 of an ingredient measured in grams and 1 of one measured in milliliters, but there is **no implicit unit conversion** or floating arithmetic. Content authors define the actual unit granularity via `ingredient.define`. Recipe steps are a bounded ordered array of `{station_type, inputs: {ingredient_id: amount}, work_minutes}`, checked for valid ingredient IDs, nonzero inputs, bounded totals and no empty step list; `recipe.define {recipe_id,steps,shelf_minutes}` freezes the definition as an immutable recorded event.

## Commands and lifecycle

| Command | Accepted contract / rejection |
| --- | --- |
| `ingredient.define {ingredient_id,unit}` | Registers a stock-keeping ID with a canonical unit. No redefinition. |
| `stock.add {ingredient_id,quantity}` | Adds audited supply of a registered ingredient, nonzero integer quantity. Amounts bounded and cannot overflow. No prices/payment here. |
| `stock.discard {ingredient_id,quantity}` | Removes unreserved stock into waste; cannot discard reservations or make stock negative. |
| `recipe.define {recipe_id,steps,shelf_minutes}` | Immutable data-defined recipe with validated sequential steps, registered input ingredients, integer station work duration and final shelf lifetime (zero = nonperishable). |
| `station.register {station_id,station_type}` | Adds one-capacity station. No invented default station catalog. |
| `station.block/unblock {station_id}` | Availability toggle; cannot block occupied stations; blocked station refuses begin/resume. |
| `cook.start {job_id,recipe_id,deadline_minute}` | Atomically reserves **all** ingredient inputs, subtracts from free stock, records unique preparation ID, schedules one expiry. Reject insufficient free stock, unknown recipe, old deadline and ID conflict. |
| `cook.step.begin {job_id,station_id}` | Requires waiting stage, free matching station; consumes next step's inputs **from its reservation**, not free stock; locks station until finish/interrupt/abort/expiry and records ready minute. |
| `cook.step.finish {job_id}` | Only if current step active and canonical time >= ready minute. Releases station; intermediate steps increment index. Final step atomically produces one unique `item:<job_id>`, marks job completed and cancels its deadline; optional `cook.item.expire` scheduled at finish + shelf_minutes. |
| `cook.step.interrupt {job_id}` | Releases current station and stores remaining work minutes without repeating ingredient expenditure. |
| `cook.step.resume {job_id,station_id}` | Reacquires a suitable free station (not necessarily the previous one) with remaining work duration. |
| `cook.cancel {job_id}` | At any unfinished stage: releases station, refunds **unused reserved** ingredients, records already consumed inputs as waste, cancels pending deadline. Repeating/canceling completed jobs is rejected. |
| `cook.item.use {item_id,purpose_id}` | Single-use claim for P4 integration; rejects double claim and expired item, cancels pending shelf expiry; consumer/order payment authority belongs to P4, not this domain. |

**Canonical scheduler:** `cook.job.expire` removes stale preparations even while player/NPCs are offscreen, releases stations, refunds unused reservations and wastes previously consumed materials. `cook.item.expire` spoils an unclaimed ready item. All outcomes appear as `time.advanced.payload.effect.cooking_outcomes` with stable firing provenance. When time skips several events, the **scheduler** orders every firing, and the cooking reducer processes them deterministically along with P2 NPC routines. These are domain-owned jobs: raw `schedule.*` cannot create/cancel/reschedule `cook:` jobs or forge `cook.*` firings.

## Inventory accounting, audit and pending integration

Inventory categories do not overlap:
- `stock`: immediately available quantities for new reservations;
- `preparations[job].reserved`: temporarily locked but not yet used ingredients;
- `preparations[job].consumed`: ingredients already applied to started steps (never refunded on cancel/expiry);
- `waste`: cumulative discarded inventory and in-progress preparation inputs abandoned/spoiled.
- `items`: uniquely identified outputs, each `ready | used | expired`. A perishable finished item can expire offscreen; completed ingredients are accounted for in produced units, not instantly classified as waste.

Supply, reservation, use, interrupt, waste, expiry, item consumption and every provenance are observable via P0/P3 ordered world events; no side effects are applied by reading a view. Projections return deep copies.

**Integration boundaries:** P4 service must validate order payment/delivery and item claim *atomically within the kernel*; a standalone `cook.item.use` does not itself pay a customer, imply ownership by an NPC, or satisfy an order. P5 economy introduces supply purchases. Ingredient-batch storage conditions/lot-level expiry and spoilage policy, recipe quality/taste, food substitutions, kitchen automation, recipe quantities, time scaling and player-facing gesture pacing are deferred design decisions; do not infer them from single recipe tests. Expiry covered in P3 is explicit **preparation deadline and completed-item shelf expiry**, with audited waste for abandoned input. Zero shelf means intentionally nonperishable until content policy defines otherwise.

## Determinism, save and acceptance

World snapshot version **4** adds `cooking`, with all recipes/inventory/stations/jobs/items/waste. v1/v2/v3 saves are **explicitly rejected**, never silently filled with stock. `restore_snapshot` independently replays and compares every event effect and final state; corruption or wrong version leaves the old live state unchanged. P0/P1/P2 command receipts, clock, NPC routines and social knowledge remain intact.

`tests/test_sys_p3.gd` exercises two recipes, multiple ingredient units, invalid recipes, stock accounting, station availability, parallel preparations and contention, step readiness, interrupt/resume without duplicate resource use, cancel/refund/waste, offscreen deadline and item expiry, unique single-use item claims, large-vs-small advances with live P2 NPC schedules, command idempotency, mid-step JSON disk save/load, forged state/event rejection and explicit v3 rejection. It runs on pinned Godot 4.6.3 beside existing SYS P0–P2 and D001/V001 regressions. Chromium test continues to protect narrative Web as no presentation adapter is changed here.
