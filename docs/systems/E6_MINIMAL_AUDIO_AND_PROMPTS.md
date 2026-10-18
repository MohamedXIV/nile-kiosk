# E6 current-scope closure — contextual prompts and minimum ambience

**Issue:** [#61](https://github.com/MohamedXIV/nile-kiosk/issues/61), **status:** implementation branch, not verified/merged. **Decision:** [frozen current scope](../experience/CURRENT_SCOPE_CLOSEOUT.md). This is E6 core intelligibility and sound-off functionality, not art/audio polish or a licensed radio.

## Gameplay

- The unchanged authoritative default Godot entry continues to use P1 clock, P2 NPC presence, P3 cooking, P4 order, P5 economy and P6 Ink through `GameEntry` and `WorldKernel`.
- Replace the globally displayed one-line keyboard command catalog with **situational prompts**: nearby doorway, actual counter service/cooking, rooftop bed/radio and currently available NPC conversational opportunities.
- Market collection or referral prompts are displayed only near the actual kiosk supply counter, and don't crowd active tea stage guidance. Expired market offers are labelled unavailable rather than calling an expired purchase action available. Failed off-range keys still go through unchanged canonical rejection.
- `scripts/gameplay/ambient_soundscape.gd` creates an actual Godot `AudioStreamGenerator` plus player. Its intentionally quiet **procedural** sound bed changes by roof/street/kiosk, night, and kettle preparation; no third-party audio recordings, historical station claims, new RNG game authority or saved sound simulation.
- `0` toggles sound even during a dialogue. The user's choice is stored separately in `user://nile-kiosk-sound.cfg` and survives browser reload. World saves, story/needs/ledger and deterministic replay have **no audio-derived canonical changes**.
- Audio remains *provisional* in sonic quality and is not a substitute for eventual era-authentic sound design, visual art approval or localized captions.

## Tests to verify before merge

- `tests/test_e6_ambience.gd` on Godot: real AudioStreamGenerator/Player, location/night/active-kettle contexts, mute/re-enable and persisted settings.
- `tools/web-e6-game-entry-smoke.mjs`: actual default production Web/Chromium scene, sound on/off, location- and cooking-dependent contexts, hard reload preserving sound-off, and all previous E1/E2/E3/E4/E5/P7 regressions.
- Full Godot Native and full Chromium/Ink workflows must pass on the exact final PR head. **Until then this is an implementation candidate, not accepted E6.**
- E6 #61 stays open until exact-head tests and any genuinely missing closure gates are resolved. Visual art #19 / PR #20 remain independently human-gated and untouched.

## Remaining after this bounded implementation

Human accessibility/play feel review, rich audio mixing/sound sources, Arabic/RTL, production fixed-angle sprite art / V001 signoff, future contextual audio nuance and camera/presentation refinement are deferred under the owner's scope freeze and **not claimed delivered**.
