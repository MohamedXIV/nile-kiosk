# Needs and wellbeing — the difference between mood and a life worth living

**Gap IDs:** NEED-01, NEED-02. **Implementation tracker:** [E2 #57](https://github.com/MohamedXIV/nile-kiosk/issues/57). **Status:** design principles AGREED; production gameplay **NOT STARTED**.

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
