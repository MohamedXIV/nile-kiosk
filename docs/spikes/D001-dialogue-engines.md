# D001 — concurrent dialogue systems spike

**Status:** planned; no runtime claims yet.
**Candidates:** Godot 4 GDScript + Dialogue Manager, Godot 4 GDScript + Ink/inkgd.
**Goal:** select narrative scripting runtime for in-world social conversation in Nile Kiosk, or establish why neither qualifies.

## Non-goals

- Arabic/RTL, voice acting, AI text generation, cinematic dialogue portraits and final character art.
- Benchmarking arbitrary thousands of sessions from a four-NPC demo.

## Fair comparison rules

- Same Godot scene, world clock, movement/cooking simulation, content meaning, state model, input, UI and acceptance script.
- Two adapters behind one small, documented contract. No engine-specific knowledge in player controls, GameState or UI.
- Pin and document versions/commit SHAs; explicitly record known install/build issues.
- **Web boot test first for Ink:** no full implementation before verifying the parser/runtime actually runs in exported Chromium Web build.

## Scenario

**Conversation A — football:** Samir and Mahmoud discuss a match at the left table.
- Speaker turns proceed while player makes tea.
- Hearing is proximity-dependent; entering listening range does not globally pause the simulation.
- At an authored boundary the player may interject **only** when within range and `knows_match` is true. An unfamiliar player can listen but cannot choose the expert interjection.
- Selected answer leads to a short reaction, then **rejoins** the original sequence.

**Conversation B — neighborhood rumor:** Mona and Hossam discuss Hassan's shop at a separate table.
- B advances on its own while A is advancing or awaiting a player response.
- Listening/hearing the relevant authored fact produces one canonical knowledge event (once only).
- B must not be rewound or advanced by A's choices or by the user engaging with A.

**World:** Player can walk between stations, prepare a simple tea order and ignore both conversations.

## State ownership

`GameState` stores facts and progression. `ConversationSession` contains `session_id`, participants, speaker/beat state, next delay, choice-window state and adapter-defined serialized state. The orchestrator owns time, awareness, participant positions and session lifecycle. Game effects have unique event IDs and are idempotent.

Either adapter may hold transient narrative variables, but its save blob **must never be the sole source** of durable world facts. No global default dialogue session allowed.

## Implementation phases

1. **P0 common harness:** small kiosk scene, player walking, cooking tick and proximity, concurrent fixture conversations with no third-party addon, tracing and deterministic clock.
2. **P1 Dialogue Manager:** independent sessions using scripted authored data; never use a global balloon/dialogue runner as the only active session.
3. **P2 Ink:** early Web-export boot probe with minimal text, then independent Ink story instances and identical scenario.
4. **P3 save/load:** restore both sessions mid-turn and mid-choice, apply knowledge events exactly once, deterministic event-log comparison.
5. **P4 desktop+web acceptance:** export both variants and run automated Chromium checks for browser exceptions, movement, progression and reload.
6. **P5 comparison:** document dependency versions, issue links, behavior, defects, authoring difficulty, adapter complexity and recommendation.

## Acceptance tests — same for both implementations

| ID | Verification |
| --- | --- |
| D01 | Two conversations proceed on independent clocks; each emits its expected speaker events. |
| D02 | Player walking, tea preparation and world ticks continue while conversations run or one awaits choice. |
| D03 | Hearing and player prompts respect distance; remote conversation continues unheard. |
| D04 | With `knows_match=false`, expert interjection is never offered; with true and in range it appears at authorized beat only. |
| D05 | Interjection invokes local reaction and rejoins shared flow; ignoring it also completes the base dialogue. |
| D06 | Ignoring both sessions allows them to complete without player-as-center-of-world blocking. |
| D07 | Hearing rumor generates exactly one canonical world knowledge event, with stable source ID. |
| D08 | Save/load with two active conversations, one pending choice and one finished session reproduces exact next events, no double effects. |
| D09 | Choice in A cannot mutate B's script cursor, pending timer or speakers. |
| D10 | Same seed/input schedule yields equivalent semantic trace on repeated executions; avoid comparing engine-specific transient IDs. |
| D11 | Desktop launch and tests pass, with addon versions recorded. |
| D12 | Actual exported Web app in Chromium runs scenario and reloads without script startup errors. |

**Explicitly excluded in D001:** Arabic shaping/RTL. English fixtures only.

## Evidence to collect

- `test_results.md` containing engine/addon/compiler revisions and OS/browser.
- Machine-readable event traces from both implementations.
- Headless deterministic assertions and browser smoke screenshots/logs.
- Exact unresolved blockers and supported recommendation (including inconclusive).

## Stop condition

A failing Web boot gate makes that candidate **blocked for a Web-first delivery** until investigated. Do not record Desktop success as Web success. If both fail required gates, do not choose a winner.
