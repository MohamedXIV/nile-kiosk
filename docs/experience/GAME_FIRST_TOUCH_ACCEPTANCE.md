# Game-First touchscreen acceptance — bounded verified baseline

**Status:** verified through merged PRs #108, #110, #112, #114 and #116; scope evidence last reconciled 2026-10-20. This is **not** mobile-platform, final-art, whole-game or human-UX approval.

The production entry remains `scripts/gameplay/game_scene.gd` (Godot 4.6/Web). P1 time, P2 presence and navigation, P3 cooking, P4 orders, P5 economy and P6 Ink all retain their existing WorldKernel/session authority. Godot Controls are inputs/presentation only; no second simulated clock, stock, social memory or save.

## Shipped touch paths

| Game path | Exact bounded behavior | Production/acceptance source |
| --- | --- | --- |
| P8 / #108 | Native onscreen directional movement, Door, Serve, Open/Close, Sleep and Save with browser persistence | `scripts/gameplay/world_touch_controls.gd`; `tools/web-game-first-world-pad-smoke.mjs` |
| P9 / #110 | Read-only next-step and nearby guidance from the actual current world state | `scripts/gameplay/next_step_guide.gd`; default game scene |
| P10 / [PR #112](https://github.com/MohamedXIV/nile-kiosk/pull/112) | Optional 8-way onscreen pad with landscape-sized targets, room framing clear of controls, hold/tap and return from toggle. Issue #111 closed. | [Native PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39312863198), [real Chromium PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39312863216) |
| P11 / [PR #114](https://github.com/MohamedXIV/nile-kiosk/pull/114) | Context-grounded Talk, authored Ink Continue/Reply 1/Reply 2/Leave, real P3 Heat/Lift/Pour, P1 Wait 5m; opening/closing pad callbacks both processed. Issue #113 closed. | [Native PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39325008330), [real Chromium PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39325008357); `tools/web-game-first-world-pad-smoke.mjs` |
| P12 / [PR #116](https://github.com/MohamedXIV/nile-kiosk/pull/116) | Six distinct 104×70 ingredient purchase targets; 70px-high cooking/wait/save/close actions and separate sandwich opener; real bought/near/story gating. Issue #115 closed. | [Native PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39337588413), [real Chromium PASS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39337588425); `tools/web-game-first-sandwich-smoke.mjs` |

The production Chromium tests use a **640×360 landscape browser viewport with real browser touchscreen events**. P12 explicitly verifies paying for **all six P5 ingredient lots** through six separate native buttons, starting/cooking/turning a P3 sandwich, mid-pan save/reload and service to an actual scheduled P4 customer. The extended P11 world-pad test exercises an actual tea order, P3 cooking, delivery, and Mahmoud's authored Ink reply via touch. Native tests assert location/overlay gating and control geometry. No test swaps a synthetic GameState into the live production scene.

**Verified merge baseline:** `main` at `367bb76eb6ce76c87e43e6b04510da125a4ca251` after P12. Historical runner results belong to their exact PR heads; inspect live `main`, PRs and checks again before future changes.

## Limitations — do not silently mark complete

- **Human-device acceptance absent.** Automated landscape Chromium is not proof on an actual Android/iOS phone, accessibility zoom, screen-reader/focus operation, accidental-tap comfort, portrait mode or broader touch devices. These require separate review.
- **Full keyboard parity is not shipped for touch.** The source still handles home bed buy/store, radio buy/place/store/listen, quiet activities, public market and learned supply actions, personal meal, sound toggle and help primarily through `_unhandled_key_input`. The first production touchscreen paths above do not establish phone-only access to those optional systems.
- **Ink concurrency caveat.** Existing keyboard controls permit some world/cooking actions while the `river_neighbors:` authored exchange is open; the P11 onscreen pad intentionally suppresses world buttons while showing Ink controls. Do not claim feature-for-feature concurrency parity. Any change needs an explicit interaction design and browser proof.
- **Visual acceptance separate.** Current world rendering is provisional; final Cairo 3D-authored/2D-delivered art, cutaway and human review remain gated under [issue #19](https://github.com/MohamedXIV/nile-kiosk/issues/19) / [PR #20](https://github.com/MohamedXIV/nile-kiosk/pull/20). Do not merge that PR based on functional smoke tests.
- **Scope freeze:** E1–E6 were closed for their explicitly bounded current experience; new NPCs, recipes, furniture, locale/RTL and visual polish belong to a separately approved future phase, not automatic regression blockers. See [current-scope closeout](CURRENT_SCOPE_CLOSEOUT.md).

## Real-device exploratory playtest checklist (not executed)

1. Start an actual mobile browser in landscape and open the production game scene. Confirm screen legibility and physical reach to all 8 directions, both action columns, contextual Talk and overlay controls without accidental world actions.
2. Travel from roof through landing and street into the kiosk via real Door and movement controls, open the shop, accept an independent customer order, prepare and serve tea through its genuine Heat/Lift/Pour timing.
3. Hear a nearby authored optional NPC invitation and complete at least one Ink choice, including how the world behaves while dialogue is open. Check physical button focus and leave/reopen.
4. At the counter, open the sandwich station, buy six separately priced lots, prepare/turn/finish without hidden keyboard input, close station, deliver and collect actual payment.
5. Save during cooking, hard reload, and verify exact money, NPC/order phase, inventory, current item, Ink cursor and play position. Try with and without the pad enabled.
6. Note unreachable actions, tap-misses, text clipping/overlaps, font-size comfort, and whether another orientation or accessibility setting is required. Treat findings as player-reported evidence, not pre-approved design scope.

## Verification protocol

Before any follow-up implementation: inspect live `main`, existing PRs/issues and checks using the connected GitHub tools. Restrict new work to an actual indispensable player problem, preserve kernel/Ink authority and source identities, use scoped PRs with real native/browser acceptance, and avoid duplicate CI runs. For docs-only updates, no gameplay CI result is needed or claimed.
