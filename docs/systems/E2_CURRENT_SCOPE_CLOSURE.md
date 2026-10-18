# E2 — Current bounded scope closure and deterministic needs

**Issue:** [#57](https://github.com/MohamedXIV/nile-kiosk/issues/57) and parent [#55](https://github.com/MohamedXIV/nile-kiosk/issues/55). **Status:** candidate pending exact-head hosted acceptance and merge; no claims of verification merely from source. [Frozen scope](../experience/CURRENT_SCOPE_CLOSEOUT.md) excludes weather, additional appliances, meals, animation, art #20, and deeper content.

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
