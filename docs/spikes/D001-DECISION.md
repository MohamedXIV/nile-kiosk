# D001 — dialogue-engine decision report

**Decision date:** 2026-10-12
**Decision:** **Ink + inkgd selected as the primary authored dialogue candidate for the next slice**, contingent on the engine/visual trial V001; keep Dialogue Manager as a verified fallback, not a second production authoring format.
**User direction:** Arabic/RTL deliberately deferred; test scripts are English.

## Objective

Evaluate a Godot 4/GDScript life-sim scenario that has two independent NPC conversations, player movement and tea preparation while people talk, spatial hearing, an authored knowledge-gated interjection with local branch/rejoin, persistent canonical facts, save/load during a pending decision, and actual Chromium Web runtime.

## Measured result, not inferred compatibility

| Gate | Dialogue Manager | Ink/inkgd |
| --- | --- | --- |
| Real authored source and compiled runtime | PASS, v3.10.4 | PASS, inkgd godot4 pinned |
| Independent NPC A and B sessions, while player moves/prepares tea | PASS P1 | PASS P2 |
| Proximity/knowledge-gated interjection, reaction and rejoin | PASS native | PASS native |
| Canonical once-only rumor fact | PASS native | PASS native |
| Save/read JSON/recreate sessions mid-choice + canonical idempotency + deterministic replay | PASS native P3 | PASS native P3 |
| Web export of **full kiosk** scene | PASS | PASS |
| Real Chromium sessions complete, tea prepared from keyboard | PASS | PASS |
| Persist save across **actual browser refresh** | NOT TESTED (fallback only) | **PASS** (chosen Ink, PR #21) |
| Arabic/RTL | DEFERRED | DEFERRED |
| Many simultaneous stories/prod-scale performance | NOT TESTED | NOT TESTED |

## Exact reproducible evidence

- **Godot:** v4.6.3 Standard/GDScript, Compatibility Web renderer.
- **Dialogue Manager:** v3.10.4 from SHA `5487c524b9eac303b059e5859e2980b134c59d79`. PR [#9](https://github.com/MohamedXIV/nile-kiosk/pull/9), [native CI #38308027392](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38308027392).
- **Ink:** GDScript inkgd `godot4` SHA `fea9098ee18d6cdbe9a5e25f8f0296bcdf0fd96a`; source compiled with official inklecate 1.2.1, SHA256 checked for zip. Isolated [Chromium InkPlayer boot #38308642648](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38308642648); [P2 native CI #38309510460](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38309510460) from [PR #11](https://github.com/MohamedXIV/nile-kiosk/pull/11).
- **Full kiosk Web:** [CI #38309832390](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38309832390) from [PR #12](https://github.com/MohamedXIV/nile-kiosk/pull/12): both candidates emitted their verified Web PASS markers after finishing two authored conversations and serving tea. Browser screenshots captured as Actions artifacts.
- **Native Save/Load:** [CI #38310579858](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38310579858) from [PR #13](https://github.com/MohamedXIV/nile-kiosk/pull/13): both passed mid-choice restoration, separate B rumor, once-only fact application, deterministic rejoin and completed-session restore. [Full browser regressions #38310579864](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38310579864) also passed.

## Comparative tradeoffs

**Dialogue Manager:** Minimal compiler/toolchain overhead, editor-native .dialogue authoring, easy Godot API for authored conditions and branching. Tighter coupling to Godot. In our integration it requires an explicit autoload for deterministic headless CI. Saving a pending choice requires storing the response's destination line ID rather than serializing plugin resources.

**Ink/inkgd:** Plain-text Ink, weaving/reconvergence and compositional narrative are especially suited to player interventions within otherwise independent NPC banter; offers potential cross-engine portability via another Ink runtime (not proof of zero effort). Downsides: separate pinned compiler, third-party `godot4` branch without a formal Godot-4 release, more session setup, and documented slower GDScript implementation compared to Ink's C# runtime. No comparative benchmarks were run.

**Rationale:** Both met the core functional criteria, so choosing Ink reflects our particular *narrative authoring philosophy and portability preference*, not a claim that it ran faster, had lower memory consumption, or was objectively stronger than Dialogue Manager.

## Residual risks and intentionally deferred work

1. **Update 2026-10-13:** Ink Web save/restoration across a real Chromium page reload **PASS** via [PR #21](https://github.com/MohamedXIV/nile-kiosk/pull/21), [CI #38346547761](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38346547761). The dedicated Ink scene persisted a pending choice, knowledge, position, world tick and event log; interjection after refresh and completed-story second reload passed. This does **not** cover tab-close/other-browser profiles/storage eviction, and Dialogue Manager browser persistence remains untested.
2. Godot headless export/test shutdown can report resource/RID leak warnings even when checks pass; investigate as a diagnostic issue without conflating native boot success with clean resource lifecycle.
3. No stress simulation with many concurrent NPC sessions; no accessibility, localization/RTL or real authored content scale evaluation.
4. No decision yet on Godot vs alternatives for the full game: **V001 visual/cutaway** still needs implementation, art assets and scene consistency proof.

## Next step

Prototype V001 apartment cutaway with a **fixed oblique/dimetric camera**. Establish floor-aware logical coordinates and moveable furniture/persistent state with placeholder graphics first, then calibrate Blender-rendered 2D layers at genuine game resolution. Keep Ink's shared canonical-state boundary and use the other candidate only as fallback.
