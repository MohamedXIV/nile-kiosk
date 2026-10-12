# D001 P2 — Ink/inkgd native integration

**Status:** D001 P2 native adapter merged via [PR #11](https://github.com/MohamedXIV/nile-kiosk/pull/11). The isolated inkgd Chromium Web boot was verified separately in PR #10; full-session Web acceptance remains issue #8.

- Uses Godot 4.6.3, inkgd pinned at `fea9098ee18d6cdbe9a5e25f8f0296bcdf0fd96a` and compiler inklecate v1.2.1 (verified SHA256 in CI).
- Source files `content/ink/*.ink` are compiled to JSON during CI via `tools/compile-ink.sh`. Generated JSON is intentionally ignored to avoid hand-editing compiler output.
- Main Godot kiosk view supports `scenes/ink_spike.tscn`, sharing existing movement, proximity, tea action, world authority and display implementation.
- Two independent live `InkPlayer` nodes and story state objects, separated by conversation ID; engine owns prose/conditional choices, orchestrator controls interjection permission and world facts.
- One story has a knowledge-conditioned choice, a brief reaction and reconvergence; the other tells a rumor with an authored fact tag.
- Tests are English-only by user instruction. No save/load or Web export of the full two-session game yet; this is a native D001 P2 acceptance phase.
- Separate verified Ink Web boot evidence: [CI #38308642648](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38308642648) on isolated real InkPlayer runtime. Don't confuse this with full scenario Web validation.

## Local development

Run `bash tools/install-dialogue-manager.sh` and `bash tools/install-inkgd.sh` and set `INKLECATE` to the official pinned linux compiler executable, then `bash tools/compile-ink.sh`. Both add-ons are external MIT projects not vendored.

## Evidence

**Verified:** [GitHub Actions #38309510460](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38309510460) on Godot 4.6.3: P0 4/4 groups PASS; Dialogue Manager P1 3/3 groups PASS; real InkPlayer P2 3/3 groups PASS; project import and all three headless scene boots PASS. Compiler v1.2.1 download verified by SHA256.

**Resolved during spike:** Ink authored content under knot `start` required explicit `choose_path("start")` after story load. The InkPlayer also needed deferred scene-tree attachment to avoid root busy errors during `_ready`.

**Residual:** Dialogue Manager headless suite still logs 3 resources in use on quit. Earlier Godot headless export can log resource/RID leaks. These are tracked as shutdown diagnostics, not clean acceptance. Full dual-session Web export, save/load, Arabic and visual review remain untested.
