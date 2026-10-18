# E6 current-scope closure — contextual prompts and minimum ambience

**Issue:** [#61](https://github.com/MohamedXIV/nile-kiosk/issues/61), **status:** VERIFIED / MERGED under bounded current-scope acceptance. **Decision:** [frozen current scope](../experience/CURRENT_SCOPE_CLOSEOUT.md). This is E6 core intelligibility and sound-off functionality, not art/audio polish or a licensed radio.

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


## Verified evidence — 2026-10-18

[PR #85](https://github.com/MohamedXIV/nile-kiosk/pull/85) squash merged `33eaaa3e6c37dd3bb8fc3688bc57bdbc21a45a34`, exact tested head `a5e71c8fffc2e77d2e8f35527809a695660d401d`: [Native SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39144054185) and [Chromium/Ink SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39144054203), including `E6 AMBIENCE: PASS`, `E6_AMBIENCE_CHROMIUM_PASS` and old E1–E5/P7 regressions.
The actual production room/active-kettle audio and persistent mute now run through Godot. Web uses synchronous browser `localStorage` for its sound-off preference because ordinary auxiliary `user://` files are not guaranteed to finish Web IndexedDB sync before reload; native Godot keeps ConfigFile. No separate canonical state or copyrighted audio is introduced. Contextual in-world keyboard hints, bounded audio and no phantom remote purchase prompts satisfy this scoped functional gate. Visual/art, historical soundtrack rights, Arabic/RTL, comprehensive accessibility and human feel approval are deferred, not claimed delivered.
