# E2 — Current bounded scope closure and deterministic needs

**Issue:** [#57](https://github.com/MohamedXIV/nile-kiosk/issues/57) and parent [#55](https://github.com/MohamedXIV/nile-kiosk/issues/55). **Status: VERIFIED / MERGED / #57 CLOSED for current bounded scope.** [PR #87](https://github.com/MohamedXIV/nile-kiosk/pull/87) squash-merged `6fe9943497d460ef27b675ad3170227a5908f303`; exact feature head `a15744a76c89d0074f9e5ba4f30ad47503e04f53` passed [Full Native SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39160267854) (`E2 CLOSURE: PASS`, `E2 NEEDS: PASS`, `PLAY C2: PASS`) and [Full Web/Chromium/Ink SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39160267835) (`E2_CLOSURE_CHROMIUM_PASS` plus E3/E4/E5/E6 regressions). [Frozen scope](../experience/CURRENT_SCOPE_CLOSEOUT.md) excludes weather, additional appliances, meals, animation, art #20, and deeper content.

## Failure reproduced in Codex handoff

For a genuinely neglected player after two canonical days and a rooftop quiet action, the original event-batched Mood discomfort rule deducted at most two points **per event**. A single 1,440-minute event and 144 equivalent ten-minute P1 events therefore ended with **Mood 58 vs 59**, despite the same starting state, Hunger and Rest. This violates deterministic chunk-invariance.

## Resolution in this branch

- **New worlds opt into explicit E2 policy version 2** through the existing canonical P2/P3-safe `needs.meals.configure` command, with `policy_version: 2` in its **recorded event request** and effect. No silent runtime flags, NPC mood meters or novel need categories.
- **Previously recorded configure events without this field remain policy 1**, whose snapshot shape and historical arithmetic are preserved precisely during replay. No automatic upgrade on an old save and no in-place rewrite of authenticated previous events. Old events do not need to be migrated to claim the *new-run* bounded E2 gate.
- Policy 2 updates Mood at each crossed **absolute 120-minute world slot** with correct at-slot Hunger and Rest. Its capped, recoverable discomfort applies once per true slot rather than once per arbitrary command boundary. Once Hunger is depleted, the repeated transformation reaches a fixed point; an equivalent bounded pass avoids a millions-of-iterations loop after a far-future single advance.
- Actual E2 conditions still use only Hunger/Rest/Mood and hidden `wellbeingBaseline`. Genuine P5 owned-and-placed bed affects Rest **on sleep only**, physical P3 meal restores Hunger, ordinary quiet/radio has diminishing returns, poor context attenuates Mood lift, player work and payment remain possible with low Mood.
- No new authority outside `WorldKernel`, no scene-only recovery/sentiment state, no trust rewards and no fake audio/art approval.

## Acceptance and regression gate

1. `tests/test_e2_needs.gd`: legacy behavior, food, paid bed vs no/put-away bed, saturation, invalid input/replay.
2. `tests/test_e2_closure.gd` / `tests/e2_closure_cases.gd`: physically depleted **real** world; 1,440 contiguous minutes vs 144 × 10 min must produce identical Needs state; player can trade/cook despite low Mood; same real sleep in stored-versus-placed owned bed yields different Rest without purchase buff; food and quiet recovery across days, hidden baseline tendency, zero Mood farming, authenticated disk restore and tamper denial.
3. `tools/web-e2-closure-smoke.mjs`: actual default Godot Web scene using keyboard only, user-bought and placed/stored bed, repeated quiet with real multi-day time, sleep/needs, genuine save + IndexedDB observation and hard browser reload.
4. **Gate:** full Godot Native and full Web/Chromium/Ink workflows `SUCCESS` on the *same final pushed feature head*. Do not close #57 / parent #55 before this and any required scope reconciliation. No human pacing approval implied.

Additional recipes, fans/temperature, wider household comfort and multiweek human balance are postponed by user scope freeze, not represented as implemented. Art PR #20 is untouched.


## Final hosted verification and issue disposition

[PR #87](https://github.com/MohamedXIV/nile-kiosk/pull/87) squash-merged `6fe9943497d460ef27b675ad3170227a5908f303`; exact feature head `a15744a76c89d0074f9e5ba4f30ad47503e04f53` passed [Full Native SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39160267854) (`E2 CLOSURE: PASS`, `E2 NEEDS: PASS`, `PLAY C2: PASS`) and [Full Web/Chromium/Ink SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39160267835) (`E2_CLOSURE_CHROMIUM_PASS` plus E3/E4/E5/E6 regressions).
One new E2 domain test plus the original E2 core/regression paths ran under hosted Godot 4.6 Native; production Chromium/Ink ran the real multi-day scenario, existing P7/E3/E4/E5/E6 drivers and exact persisted reload. Parent #55 closed after scope matrix reconciliation. No broader comfort/economic scenarios or human art direction are implied. Art PR #20 untouched.
