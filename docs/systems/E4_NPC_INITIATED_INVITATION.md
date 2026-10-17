# E4 — NPC-initiated conversation after a real customer interaction

**Status: proposed until exact-head Native + Web/Ink verification.** Builds on the merged [E4 authored triggers](E4_CANONICAL_EVENT_OPPORTUNITIES.md) and [player-selected Ink session](E4_RIVER_INK_CONVERSATION.md).

## One concrete in-world loop

1. A real P4 order is offered and accepted; the player prepares a real P3 tea and delivers it while the kiosk is open. Mahmoud is physically present, not a remote or fabricated customer.
2. The **committed** `order.delivered` event is observed by E4. Authored `narrative.opportunity.register` for `mahmoud_after_tea` requires player and Mahmoud in the kiosk, kiosk open, earlier `order.accepted`, and `initiator_npc_id = mahmoud`. The rule verifies **that exact delivered order belongs to Mahmoud**, rather than unlocking from a different NPC's tea.
3. The opportunity records source event, minute and initiator in the sole `WorldState.narrative` projection. It is an **NPC call-out**, not an involuntary cutscene: a small line at Mahmoud's actual live P1/P4 location offers `M · Listen` or `I · Ignore` while the player is physically near. No second scene clock or social ledger.
4. Accepting uses the existing one-event `narrative.opportunity.begin` with an authentic InkPlayer cursor, reuses P6 `beat` and `point` tags, and presents two reviewed player replies. `Enter` continues, numbered options select, `Esc` only hides the overlay and `P` saves the actual pending choice. Player's movement is suppressed while the overlay is visible, but the world time continues.
5. Ignoring uses **new** `narrative.opportunity.decline` (authorized `system:narrative` adapter only), marking `declined_event_id` and `declined_minute` inside the existing canonical opportunity dictionary. A declined invitation can never begin, and a session that has begun can never be declined retroactively. Both decisions survive P0 disk reload and deterministic replay. No automatic reward, currency, rumor or trust boost.

## Architecture / intentional limits

- The *only* new authoring field is optional `initiator_npc_id` on an opportunity rule, validated as an existing NPC and currently allowed for the canonical `order.delivered` trigger. It must match the delivered order's actual NPC. Existing authored rules, event order and snapshots remain unchanged.
- The *only* new WorldKernel command is `narrative.opportunity.decline`, with strict payload, authorization, active offer and one-start constraints. Declines have stable event provenance, are idempotent by command ID and reject forged snapshots on replay. No v11 schema bump.
- `GameEntry` registers an authored, checked-in Mahmoud dialogue manifest and validates the same Godot-derived NPC pose and player proximity as other E4 interactions. `GameScene` only displays input hints and a shared nonauthoritative overlay. It doesn't create NPC state.
- The invitation is generated from **his recent transaction with the player**, not a generic AI social decision algorithm. It can be ignored without penalizing the player. This intentionally does **not** imply autonomous nonbuyer wandering, AI-selected dialogue, generic relationship memory, acoustically realistic hearing, or an unlimited narrative engine.
- This slice must not alter preexisting Salma E4 mid-choice Ink behavior, P4 customer routing/payment, or the art-human-review PR #20. Keep E4 #59 and parent #55 OPEN.

## Acceptance

`tests/test_e4_npc_invitation.gd` plays the real opening, waits for real customer demand, physically brews and delivers tea, verifies exact source event/NPC, tests separate accept/ignore save branches, real inkgd branching and middle-choice disk resume, forged event rejection and complete replay. The existing full Native workflow runs it. The default game Chromium smoke verifies a player-visible prompt, genuine consent and Ink choice, one-time ending and persistence across later reload, alongside the earlier Salma/river story and all existing world regression markers. Both full CI workflows must pass on the exact PR head before merge.
