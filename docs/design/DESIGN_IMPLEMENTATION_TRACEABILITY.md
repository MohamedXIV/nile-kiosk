# Nile Kiosk — design-to-implementation traceability

**Baseline reviewed: `main` at `f6eb3557754d3475a71d8b7f36ac99bfe0943b68`, 2026-10-14.** This is a **gap register**, not a declaration that design work has shipped. [Parent issue #55](https://github.com/MohamedXIV/nile-kiosk/issues/55).

## Reading and updating statuses

There are **three different axes**; never collapse them into one "DONE" label:

- **Design:** `AGREED` (accepted direction), `PROPOSED` (candidate illustration), `OPEN` (requires consequential design decision).
- **Implementation:** `NONE` (not found in production); `FOUNDATION_ONLY` (verified prerequisite, but feature behavior absent); `PARTIAL` (some user-observable feature behavior exists, full acceptance missing); `VERIFIED_SCOPE` (precisely the stated limited behavior has evidence, **not** necessarily the whole pillar).
- **Evidence:** exact source and tests, merged PR or live commit, and actual browser/player proof for presentation. A markdown sentence, old assistant statement, issue closure, spike, QA-only controls, or authored fixture **is not implementation evidence**.

The `verified scope` for SYS P0–P7, CONTENT C0 and PLAY C1–C6 remains real and valuable. Those milestones DO NOT complete the features below. An implementation issue stays open until its **own** behavior passes acceptance. For a partially implemented row, name the exact existing sub-behavior; do not claim a percentage.

| ID | Feature / design decision | Design | Implementation *for this behavior* | Narrow existing evidence (not completion) | Work |
| --- | --- | --- | --- | --- | --- |
| LIFE-01 | Player-driven work/home day; close early with no quota | AGREED | FOUNDATION_ONLY | P1 clock + P2 routines; QA uses T-key time advance, not a player day | [#56](https://github.com/MohamedXIV/nile-kiosk/issues/56) |
| LIFE-02 | Quiet river, radio, fishing/optional unprofitable activities; no forced customer pacing | AGREED direction; fishing specifics PROPOSED | NONE | C4 offers are scheduled, not a quiet-time/agency system | [#56](https://github.com/MohamedXIV/nile-kiosk/issues/56) |
| NEED-01 | Hunger, Rest, visible Mood + hidden long-term wellbeing baseline | AGREED | NONE | No production needs domain; prototype's bars are NOT production | [#57](https://github.com/MohamedXIV/nile-kiosk/issues/57) |
| NEED-02 | Context, saturation, environment and autonomy shape Mood without death spiral | AGREED principles; curves OPEN | NONE | P5 furniture tracks interaction, no recovery/comfort effect | [#57](https://github.com/MohamedXIV/nile-kiosk/issues/57) |
| COOK-01 | Data-authored recipe/jobs, ingredient reservation and order settlement | AGREED | VERIFIED_SCOPE | [P3](../systems/SYS_P3_COOKING_INVENTORY.md), [C3](../systems/PLAY_C3_KIOSK_SERVICE_INTERACTION.md), PRs #36/#48; timed *world-command* steps | Existing, preserve |
| COOK-02 | Tactile flip/pour/season/assembly with player-skill food quality | AGREED | FOUNDATION_ONLY | C3 advances next available canonical command by G-key; no tactile gestures/quality scoring | [#58](https://github.com/MohamedXIV/nile-kiosk/issues/58) |
| COOK-03 | Socially discovered, attempted, refined recipe knowledge | AGREED direction; state names PROPOSED | FOUNDATION_ONLY | P2 fact witnessing and P6 authored consequences, no progressive recipe discovery | [#58](https://github.com/MohamedXIV/nile-kiosk/issues/58) |
| SOC-01 | NPC independent presence, witnessed facts and non-player conversations | AGREED | VERIFIED_SCOPE | [P2](../systems/SYS_P2_NPC_LIFE_SOCIAL.md), [P6](../systems/SYS_P6_INK_NARRATIVE_BRIDGE.md), PRs #35/#39 | Existing, preserve |
| SOC-02 | Kiosk visit modes and spatial circulation: takeaway/counter/table/railing/standing | AGREED | FOUNDATION_ONLY | P4 has order routes/seat capacities; scene population/circulation unfinished | [#59](https://github.com/MohamedXIV/nile-kiosk/issues/59) |
| SOC-03 | Unpaused spatial speech, proximity-based interjections, silence/rejoin | AGREED | PARTIAL | P6 persists independent Ink sessions/choices; D001 tests interjection; no production spatial UI choreography | [#59](https://github.com/MohamedXIV/nile-kiosk/issues/59) |
| SOC-04 | Facts/referrals affect actual shop inventory, discounts or service access | AGREED direction; exact goods/prices OPEN | FOUNDATION_ONLY | P2 facts + P5 ledger, no referral-to-market production bridge | [#59](https://github.com/MohamedXIV/nile-kiosk/issues/59) |
| SOC-05 | Returning customers with lived familiarity and remembered preferences | AGREED | PARTIAL | [C6](../systems/PLAY_C6_REPEAT_CUSTOMER_EXPERIENCE.md) verifies per-customer recent paid/abandoned order affecting **demand probability only**; no natural preference/relationship writing | [#59](https://github.com/MohamedXIV/nile-kiosk/issues/59) |
| ECON-01 | Ledger, order settlement, leases and saved furniture ownership | AGREED | VERIFIED_SCOPE | [P5](../systems/SYS_P5_ECONOMY_HOUSING_HOME.md), [C3](../systems/PLAY_C3_KIOSK_SERVICE_INTERACTION.md), PRs #38/#48 | Existing, preserve |
| ECON-02 | Suppliers, market access, transport/time and opportunity cost | AGREED principle; tricycle/bus details PROPOSED | FOUNDATION_ONLY | P5 ledger and C0 authored catalogs; not procurement/commuting gameplay | [#60](https://github.com/MohamedXIV/nile-kiosk/issues/60) |
| HOME-01 | Rentable 24m² roof room, optional 60m² flat, object purchase/place/use | AGREED topology; economic numbers OPEN | VERIFIED_SCOPE | [P5](../systems/SYS_P5_ECONOMY_HOUSING_HOME.md), PR #38. Art approval separately pending | Existing, preserve |
| HOME-02 | Fan/bed/radio/TV/etc. improve daily living **when used**, not arbitrary +ROI | AGREED direction; individual effects PROPOSED | FOUNDATION_ONLY | P5 records usage only, explicitly defers effects | [#60](https://github.com/MohamedXIV/nile-kiosk/issues/60) |
| ATM-01 | Dynamic Nile/Cairo soundscape, contextual visual/audio feedback | AGREED direction; technical implementation OPEN | NONE | HTML prototype audio is not repository production | [#61](https://github.com/MohamedXIV/nile-kiosk/issues/61) |
| ATM-02 | Coherent default production game entry and in-world UI | AGREED | FOUNDATION_ONLY | `project.godot` defaults to D001 kiosk spike; `qa_traversal_scene.gd` renders debug circles and QA text | [#61](https://github.com/MohamedXIV/nile-kiosk/issues/61) |
| VIS-01 | Fixed-angle playable 3D-authored/2D-delivered Cairo cutaways | AGREED direction; style unapproved | PARTIAL | [V001 PR #20](https://github.com/MohamedXIV/nile-kiosk/pull/20) technical spike, [#19](https://github.com/MohamedXIV/nile-kiosk/issues/19) art gate OPEN; not merged visual acceptance | #19/#20 (do not duplicate) |
| AI-01 | Complete offline authored game; optional BYOK AI **flavour only**, default Off, no world authority | AGREED boundary; provider/UX OPEN | FOUNDATION_ONLY | Authored Ink P6 exists. No production runtime AI flavor provider; not a release dependency | Later explicit issue if chosen |

## Source-of-truth map and change protocol

1. **Experience specification** lives in this file's six linked design docs. These say what player-facing behavior means, label proposals and preserve the mood of the game.
2. **Production ownership** lives in [architecture](../architecture/SYSTEM_FIRST_ARCHITECTURE.md) and existing SYS/PLAY docs. These say who can mutate canonical truth, how persistence and replay work.
3. **Work and acceptance** live in issues #55–#61, with V001 #19/#20 separate. If scope expands, update a gap row and its issue; do not create a parallel workstream with different semantics.
4. **Proof** needs actual production source paths, tests and exact commits/merged PR links; for tactile/spatial/ambient behavior, capture a playable native/Web result and user-facing review. No claimed visual approval from green CI.
5. **Reconciliation on every merge:** update row status/evidence *only for behavior actually demonstrated*; close a child issue only when all of its stated gates pass or it is explicitly re-scoped. README/ROADMAP can summarize, never override this ledger.
6. **Legacy QA/prototype exception:** `scripts/kiosk_spike.gd`, D001, V001, `content/world/qa_*`, `scripts/integration/qa_traversal_scene.gd`, and the standalone HTML reference can test or inspire a design, but are not automatically a production default.

## Suggested dependency-aware execution (not an artificial waterfall)

E6 production entry and E1 day loop can start by wiring existing domains and content **without** waiting for final V001 art. E2 wellbeing can then make E1 activities and E5 home objects meaningful. E3/E4 evolve in parallel over P3/P4/P6; E5 adds genuine market/referral effects after shared canonical interface contracts are clear. Select the smallest high-value missing behavior first; preserve independence of visual-art approval. Update this document as source and evidence change.
