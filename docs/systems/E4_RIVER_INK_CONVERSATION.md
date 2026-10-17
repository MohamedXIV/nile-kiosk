# E4 — Player-Selected River Opportunity → Real Ink Conversation

**Status: implementation candidate until exact-head Native + Chromium/Ink pass and merge.** This is the playable follow-up to [PR #78](https://github.com/MohamedXIV/nile-kiosk/pull/78), not a new narrative authority or general quest scripting engine.

## Behavior

- A genuine `life.activity_done` by the Nile while the kiosk is open unlocks `river_watch_reflection` via the existing E4 authored rule. The event and its provenance live in WorldState v11.
- The opportunity offers a small `N` interaction with **Salma**, but does not begin a conversation automatically. The player must enter the kiosk and come within `RoomTraversal.RADIUS` of her **world-minute-driven** pose.
- `N` attaches the reviewed `content/ink/nile_river_reflection.ink` runtime lazily and issues exactly one canonical `narrative.opportunity.begin` event, with the real InkPlayer cursor, when ready. `InkWorldBridge` never owns additional game time, social knowledge or currency.
- `Enter` commits each real authored `# beat:` line and opens `# point:` choices via P6 validation. `1` / `2` choose the current eligible branch (ordered by stable option ID); `Esc` dismisses the *overlay only*. `P` saves mid-dialogue. The P6 narrative session remains running or waiting when the player closes the overlay and may be resumed, including across a hard Web reload, without replaying any prior lines or choosing again.
- Completed story is **once-only**. A second `narrative.opportunity.begin` with a fresh session ID is rejected by the canonical narrative domain based on the already associated `opportunity_id`; retrying the original command is still P0-idempotent.

## Code ownership

- `scripts/core/narrative_world.gd`: authorized atomic new command `narrative.opportunity.begin` validates the unlocked marker, story match, participant presence, and one-start invariant. Saves the real session with `opportunity_id` and `started_event_id`; all subsequent line/choice/finish transitions remain P6.
- `scripts/core/ink_world_bridge.gd`: existing inkgd runtime (unchanged story serialization semantics) now accepts opportunity begin, never directly writes canonical state.
- `scripts/gameplay/game_entry.gd`: loads/validates the bounded authored story manifest; registers once, checks Salma's Godot-derived pose/proximity, and exposes read-only Ink choices to the game status. No general scripting hook.
- `scripts/gameplay/game_scene.gd`: provisional Godot keyboard/canvas presentation and an ephemeral text overlay. World minutes still advance normally, even during dialogue; player directional input is temporarily suppressed while the overlay is open. Dismissal never undoes already committed narrative events.
- `content/social/nile_river_reflection.v1.json` + `content/ink/nile_river_reflection.ink`: reviewable, authored two-choice dialogue, intentionally **no fabricated world fact, reward, currency transfer or relationship boost**. Ink compiler builds JSON in the existing CI, not a new scene timer.
- **No save schema bump** from v11: opportunity association is an optional key only on the *new* session type; existing ordinary P6 sessions and verified old save snapshots retain byte-equivalent replay.

## Acceptance and constraints

`tests/test_e4_story_ink.gd` requires actual inkgd runtime and compiled Ink, verifies a locked begin leaves state unchanged, remote player cannot talk, near player can begin once, real Ink lines and options, rejected fake choices, mid-choice disk reload/resume, chosen branch/ending, blocked duplicate and terminal replay. Existing `tests/test_e4_story_opportunities.gd` + E1/E6 stay green. `tools/web-e6-game-entry-smoke.mjs` exercises player-selected story in the **actual default game canvas**, saves mid-choice, hard reloads, selects branch, finishes and verifies no repeat. CI uses preexisting pinned Native/Web workflows.

**Explicit limits:** The example is one authored Salma exchange, not all NPC conversations or context-aware referrals; text and visuals are provisional, not final E4 content or human-reviewed V001 art. No full acoustic privacy, NPC crowd collision, localization/RTL, arbitrary event-side command chains, automatic "everything happens when" author scripting or alternate world clock. E4 #59 and parent #55 remain OPEN. Art PR #20 remains human-gated and untouched.
