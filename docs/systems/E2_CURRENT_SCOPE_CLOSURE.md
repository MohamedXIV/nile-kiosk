# E2 frozen-scope closure

Base main9db0338; dedicated branch `feat/e2-current-scope-closure`. No expansion, additional meters, weather/appliances, recipes or cosmetic UI. E3/E6 shared ownership and art#20 untouched.

## Acceptance plan
1. Exercise actual default Game quiet time, P5 paid furniture, physical tea service/income at depleted needs, public paid procurement and P3 personal bread. Contrast the same sleep with the legitimately owned bed stored versus placed; buying/placing alone changes no need. Contrast real quiet time before and after recovery.
2. Recover through canonical days with food/sleep, observe temporary Mood versus slower hidden baseline, and reject saturation farming. Existing no-punitive-Mood-gate behavior is tested, not replaced.
3. Cover invalid/duplicate/unauthorized actions, whole-world disk/replay, physiology bounds and ordinary/depleted long-versus-small P1 time chunks. The existing Hunger bar decreases over time; do not reinterpret it as increasing hunger.
4. Use only normal controls and displayed Hunger/Rest/Mood for real default-game Chromium contrasts and hard reload. No seeded browser save, hidden-baseline HUD or test-only commands.
5. Run complete existing native and Web/Ink acceptance at final feature head without editing shared workflows or common roadmap/board/traceability. Provide isolated issue57/integration note; do not close57 or55 before authorized verified integration.

## Concrete finding
From a real closed-kiosk Game after2400world minutes and one depleted rooftop quiet activity, Mood is59. Advancing one day in one event gives58, whereas144 ten-minute events give59. Both have identical Hunger/Rest and initial history. The current batch-capped discomfort deduction is not associative. This is a real E2 determinism defect; it must not be hidden by weakening test expectations.

## Proposed compatibility interface (coordination pending)
Retain legacy Needs arithmetic for existing event streams. A versioned E2 request marker on new `needs.meals.configure` / `needs.eat` events selects corrected absolute-slot Mood progression. Needs owns validation, effect, projection and both reducers; a narrow WorldKernel dispatch annotation is required so the existing production adapter can issue versioned requests without modifying the other worker's GameEntry/HUD. Old requests/snapshot shape remain legacy and restore exactly; an old world adopts the corrected policy through its next real E2 meal event. No global schema change or unrecorded migration. New numerical behavior remains PROPOSED; preserve the existing per120-minute drift/discomfort rates and finite activity benefits.

No shared Kernel change is made pending ownership coordination. Positive proof and E2-owned tests proceed independently.


### Exact integration hook requested
In `WorldKernel.dispatch`, after `_canonical(payload)` and before receipt lookup/planning:

```gdscript
var original_signature: String = WorldState.command_signature(kind, actor, payload)
payload = WorldState.Needs.current_request(kind, payload)
```

`Needs.current_request` would annotate **only** `needs.meals.configure` and `needs.eat` with an absent `policy_version` as integer `2`, leaving all other commands and explicit/malformed fields unchanged. The receipt check must accept either the normalized signature or `original_signature` so retrying an old successful E2 command still returns its original receipt. The normalized request must be the actual recorded event request; replay must never annotate historical requests. Needs validates the optional marker, emits it in the effect, preserves v1 snapshot shape and arithmetic for unmarked history, and selects v2 only when an authenticated marked E2 event applies. Do not implement a silent on-load policy switch.

This is an interface proposal, **not implemented production behavior**. No GameEntry, HUD, cooking or workflow edit is requested. Exact numerical policy remains PROPOSED and needs legacy replay + threshold-crossing chunk tests before adoption.
