# E6 / P0 — canonical playable game entry (provisional)

Tracker: E6 #61, parent #55. This PR does not close E6.

## Scope

Replace the default D001 fixture with a playable Godot entry using the existing WorldSession/WorldKernel, independent authored starter data, and screen-relative 2D movement. No second authority for time, money, positions, NPCs, recipes, orders, or payments.

- scenes/nile_kiosk_game.tscn and scripts/gameplay/game_scene.gd: *temporary code-drawn* 2D view, doors, nearby overhearing, kiosk service and save/reload. Not final art.
- scripts/gameplay/game_entry.gd: calls C0/P0–P7, PLAY C2 spatial travel, PLAY C3 service and PLAY C4 autonomous demand; refuses corrupt saves rather than deleting them.
- content/world/nile_opening.v1.json: authored separate starting roof room, two simple recipes, stock, two NPCs, starter cash, optional unleased southern apartment.
- content/navigation/nile_opening_routes.v1.json: temporary 240×160 *gameplay* rectangles and door graph, not architectural metres or the V001 geometry.
- content/service/nile_opening_demand.v1.json: one scheduled visitor; not final population balancing.
- P1 advances time through canonical events, including an authored new-world initial 17:00, player waiting and periodic time progression while playing. Saved world reloads do not reissue startup events.

## Controls

WASD/arrows move screen-relative on a provisional 2:1 diamond; E door, F overhear, G one canonical service command near counter, J wait five world minutes, P verified save.

## Verification

tests/test_e6_game_entry.gd checks production catalog/graph, rejected teleport or remote work, roof→landing→street→kiosk, independent NPC visit/order, P3 steps and P4 delivery/P5 payment, mid-cook and settled save/reload.

tools/web-e6-game-entry-smoke.mjs verifies the actual default game scene through Chromium, keyboard movement, autonomous offer, player acceptance and Web hard refresh integrity.

## Explicitly unfinished

E6 #61 stays OPEN. None of these are claimed complete: production painting or 3D-authored 2D asset workflow, atmosphere/soundscape, spatial authored Ink dialogue, Arabic RTL, smooth animation, real furniture collisions, tactile cooking gestures, wellbeing, E1 open/close/day/sleep loop, polished UI or balanced economy. Starting cash/prices/rent/stock/schedules are **provisional implementation examples**, not approved numbers. The 2:1 ground drawing is not an approved V001 projection migration. V001 #19 and PR #20 remain gated and independent.

Before merging: check actual native/Chromium test results on the exact PR head, and update the traceability ledger only for narrow proven scope.
