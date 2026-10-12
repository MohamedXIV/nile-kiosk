# D001 P2 — Ink/inkgd native integration

**Status:** implementation submitted, awaiting main-project CI evidence (separate P2 Web boot gate already passed).

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

**Pending.** Verify compiler, test `D001 P2 Ink sessions`, P0/P1 regressions and actual scene boot on PR checks before merging.
