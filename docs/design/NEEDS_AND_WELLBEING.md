# Needs and wellbeing — the difference between mood and a life worth living

**Gap IDs:** NEED-01, NEED-02. **Implementation tracker:** [E2 #57](https://github.com/MohamedXIV/nile-kiosk/issues/57). **Status:** design principles AGREED; E2 P0 implementation in [PR #68](https://github.com/MohamedXIV/nile-kiosk/pull/68), [native CI](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39037366128); [Chromium PR checks](https://github.com/MohamedXIV/nile-kiosk/pull/68/checks) must pass before merge. **Current bounded E2 acceptance VERIFIED / CLOSED in PR #87; broader optional and subjective designs deferred.**

## Three visible needs, one hidden long-term tendency

- **Hunger** — physical food need and consequences of eating/working.
- **Rest** — tiredness, sleep, daily energy and actual quality of rest.
- **Mood (المزاج)** — the *only* visible psychological indicator, possibly a small bar or qualitative state.
- **Hidden `wellbeingBaseline`** — slow, persistent tendency for current Mood to recover toward. Not a second "Contentment" bar; never a visible Relaxation resource.

Mood is what happened today; the baseline is what the player has built over weeks. A pleasant evening can lift mood briefly even in an uncomfortable life. A stable home, a reasonable routine and meaningful connections mean a bad day doesn't permanently trap the player at a low value. This is the opposite of a high-score Happiness meter.

## Behavior, not a collection of fixed buffs

Internal contributors can include **comfort, food, leisure, social encounters, environment, autonomy**. Their influence must be contextual: a satisfying meal after tiring work may feel better than identical food repeated daily; warmth and a working fan change sleep conditions; watching the Nile after a rush matters more than pressing a `Relax` button; a player can choose to close early and preserve energy. Activity saturation prevents infinite grinding of one "happy" action.

Mood can subtly color cooking attentiveness, reactions and interaction cadence, but **low Mood must not produce a punitive death spiral** (worse food → less cash → worse mood forever). Good outcomes must remain achievable by player care and skill. Prefer environmental/body/audio cues to floating numerical +Mood toasts; the real mood change should be felt before read.

## Implementation contract

- Canonical needs, modifiers, baselines and decay/recovery must live in the **world domain**, integrate with P1 time and P5 home use, and persist and replay. Do **not** implement needs as three scene-only HUD progress bars.
- Separate immediate modifiers from durable baseline. Don't make purchasing a fan instant permanent happiness; **using it in a warm room** changes conditions and may indirectly improve next-day rest.
- Rates, exact caps, penalties, wording and curves are **OPEN to measured balancing**; examples from a one-file Three.js demo (80/90/75, 70→82) are **not canon**.
- No AI-generated text can silently change needs or invent social events.

## Acceptance contract (pending)

Test same meal/activity under two distinct contexts and repeated over time; one short-lived mood boost versus a slower sustained baseline improvement; poor-mood recovery with bounded gameplay impact; sleeping with and without a real comfort object; movement between kiosk and home, persistence, deterministic replay, browser-visible readable state. None of these tests are complete in P5 today.

## E2 P0 production contract (balance not approved)

`scripts/core/needs_world.gd` owns Hunger/Rest/Mood, hidden `wellbeingBaseline`, activity saturation and authored recipe nourishment. It is projected in schema v10 and reconstructed exclusively by WorldKernel event replay; legacy v7–v9 snapshots are verified against their historical envelopes then migrated through replay. Clock loss uses absolute slot boundaries, so equivalent elapsed-time chunking yields identical physical readings. Sleep restores actual Rest, with a conditional benefit only from a **legitimately placed owned bed**; buying/granting furniture alone never changes Mood. Leisure at an authored site gives a small contextual lift with within-day saturation. The slower baseline can improve through multiple qualifying days, never a freely repeatable interaction.

A personal meal may only consume an already **ready** P3 cooked item at an operating venue, through an atomic WorldKernel command whose event marks the item `player:meal`; accepted-order recipes are protected. Current authored nourishment is provisional (`content/life/nile_meals.v1.json`). The live production scene has restrained Hunger/Rest/Mood presentation, and a contextual **K personal-bread interaction** at the kiosk counter: start / prepare / await one canonical world minute / finish / consume a real P3 cooked item. Unfinished stages persist; it is not the eventual E3 tactile food experience. Hidden baseline is never shown. Further E2 work must connect actual home food preparation, nuanced environmental heat/comfort, food variety and authored social events, tune long-term rates from real play, and test extended negative/positive mood scenarios.

**Evidence:** `tests/test_e2_needs.gd`, [native CI](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39037366128), [Chromium PR checks](https://github.com/MohamedXIV/nile-kiosk/pull/68/checks), historical migration `tests/test_play_c2.gd`. Browser must pass at merge head. Unmet environment and pacing behavior remains E2 work.

## Delivered practical home context: paid bed in the playable room (2026-10-17; [PR #69](https://github.com/MohamedXIV/nile-kiosk/pull/69))

The production entry now offers a secondhand bed through P5 paid ownership, explicit placement and storage (T buy/place, Y store), with a visible room drawing. **No effect at purchase**: existing E2 placed-bed-only Rest improvement occurs when the player actually sleeps via E1 in their owned roof room. Native and Chromium coverage must prove ledger spend, stored-vs-placed contrast, insufficient funds, restricted home actions, sleep and reload. The authored 3400-piastre bed price is a **provisional testing value**, not agreed period economic balance. E2 remains PARTIAL, without invented environment/fan mood curves, and depends on a human playtest for pacing.

**Final exact-head acceptance:** [native suite](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39041517548) succeeded and [full Chromium/Ink](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39041517429) succeeded (including `E2_HOME_BED_CHROMIUM_PASS`) at PR head `50157cb38a4663b7e54e66150005184b61801a88`; squash merge `18cea54ac3a2929be57098580332b33b45e07a3f`. All broader NEED-02 environmental, social and human-gamefeel gates remain open.


## E2 frozen-scope completion — VERIFIED / MERGED 2026-10-18

[PR #87](https://github.com/MohamedXIV/nile-kiosk/pull/87) squash-merged `6fe9943497d460ef27b675ad3170227a5908f303`; exact feature head `a15744a76c89d0074f9e5ba4f30ad47503e04f53` passed [Full Native SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39160267854) (`E2 CLOSURE: PASS`, `E2 NEEDS: PASS`, `PLAY C2: PASS`) and [Full Web/Chromium/Ink SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39160267835) (`E2_CLOSURE_CHROMIUM_PASS` plus E3/E4/E5/E6 regressions).
New default worlds record `policy_version:2` with the P2/P3-safe E2 meal-configuration event. `NeedsWorld` now advances Mood/discomfort once per crossed absolute 120-minute P1 slot using genuine at-slot Hunger/Rest, rather than capping discomfort per submitted command. This fixes depleted 1,440-minute-vs-144 × 10-minute mismatch while retaining the former arithmetic and exact snapshot shape for old unmarked event streams. Real P5 paid/placed/stored bed has no buy/place Mood or Rest buff; only actual sleep yields 12 Rest advantage compared with genuinely stored owned bed at the same history. Real quiet mood attenuates when exhausted, saturates across repeat uses and recovers after fed/rested days; slow hidden `wellbeingBaseline` changes only through earned good days, not arbitrarily. Low Mood never blocks service, physical P3 cooking, procurement or closing. Positive/negative, long-lived Native/disk and real keyboard-only Chromium/IndexedDB acceptance pass. E2 #57 current scope is complete; future richer recipes, temperature, fan/TV, further needs-tuning, human pacing reviews, localization and final art remain intentionally deferred.
