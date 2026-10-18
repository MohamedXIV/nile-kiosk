## Scope and status

**Domain-complete and integration-ready; not fully playable.** One Egyptian liver-sandwich vertical slice for the authorized Game-First phase. Base: `c10aad115f1ff54bb62c40ebb20cdb21b6d697aa`. E1–E6 stay closed; art PR #20 and player-feedback PR #89 remain separate. Do not merge automatically: GPT-6 owns review and player integration.

## Delivered

- Actual paid P5 acquisition of six ingredient lots, no free cash/stock or fabricated learning. Four sandwich portions cost 1560 minor units over six existing supply transactions; all terms are PROPOSED.
- Three P3 stages: season liver/garlic, pan-sear with pepper/oil and a deliberate turn, assemble bread/lemon. The turn is inside an active step and does not create an item or finish cooking. The second face needs real world time.
- Reusable optional step `technique {action_id,earliest_minutes,finish_minutes}` and player command `cook.step.action {job_id,action_id}` → `cook.step_actioned`. No recipe ID hardcoded into the action implementation.
- Actual `item:<job_id>`, exact-once ingredient reservation/consumption, finite supply, station occupancy, single-use item claim, cancellation/deadline/shelf accounting and idempotency.
- Quality derived from verified action/timing history: actual production cases yield **good100 / okay76 / rough36 / good100**. Interrupt/resume cannot erase over-searing; off-pan time does not burn food. No random grade, price penalty, XP or needs mutation.
- Existing generic Kernel/WorldState P3 delegation handles the new event. No shared architectural change or save-version bump. Legacy tea/bread histories remain unchanged.

## Integration handoff

See `docs/systems/COOKING_DEPTH_LIVER_SLICE.md` for exact requests, effects, identifiers, step cues, rejection codes, paid offer list and owner boundary.

GPT-6 should call `CookingContent.install(world)` after normal catalog bootstrap, package `content/cooking/*.json`, expose real paid acquisition and connect preparation/turn/lift/assembly to existing canonical time. Before turning, `ready_minute` means the preferred latest action time; after turning it means finish readiness. `step_action` is canonical, and finish refuses missing gestures. The installer works with existing saves, preflights the complete pack and emits no live installation events on content conflict.

No GameEntry, scene/controller, input, HUD, camera, navigation, audio/art, shared workflow, roadmap/board/traceability or PR #20 edits. No new knowledge/dialogue is used; installing a starter recipe does not pretend that a conversation happened. Selling/nutrition/demand integration and restocking are outside this slice. Six purchase transactions are not an atomic basket.

## Verification

- Pinned Godot 4.6.3 and freshly compiled Ink 1.2.1; compiler archive verified against the existing workflow SHA256.
- Focused new cases pass with real starter-world purchases and four preparations, rejection/early/wrong/unauthorized actions, retries, time chunking, interrupt/resume, overflow, exact deadlines and shelf expiry, mid-pan save across midnight, interrupted/final disk replay and tampered state/event rejection.
- Full available Native development suite: **38 scripts passed; 4 startup scenes passed**. Existing P3 entry also runs the new cases, so current workflows cover them without definition changes. Final pushed HEAD is rechecked before delivery.
- Known diagnostics retained in raw output: #16 resource shutdown messages in DM/save tests, and the intentional malformed-JSON save test in SYS P7. No script/parse failure or failed assertion.
- No browser-playable or human feel acceptance claimed. Native startup is not Web proof. Default-scene/Web interaction and pacing verification belongs to the GPT-6 integration batch. No manually triggered GitHub Actions run or hosted success claim.

## Review

Local self-review only, honoring the assignment's explicit prohibition on delegation. GPT-6 review/integration remains required. This PR does not close/reopen existing experience or art issues.
