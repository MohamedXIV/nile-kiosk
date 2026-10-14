# Daily life, pacing and player autonomy

**Gap IDs:** LIFE-01, LIFE-02. **Implementation tracker:** [E1 #56](https://github.com/MohamedXIV/nile-kiosk/issues/56). **Status:** design direction AGREED; gameplay **not implemented beyond existing clock/NPC/order foundations**.

## The experience

The player works in a small kiosk by the Nile, not to build a restaurant empire, but to pay for a modest life and make room for things they love. A day might include waking in the rented rooftop room, preparing or commuting, opening the kiosk, cooking/serving while others live around them, deciding when enough is enough, closing, returning home, enjoying a tiny comfort, sleeping, and doing it again. Do not force an endless achievement/profit schedule. Quiet survival is **not** poverty punishment.

**Player control matters:** the player decides how long to stay open; closing early should normally mean less revenue and more personal time, not instant loss. A day with few customers may be pleasant. Independent NPC movement and talk do not stop when nobody orders food. Some NPCs merely pass through, some linger, and sometimes no one appears for minutes.

Time off is meaningful even when not profitable. Standing by the railing to watch the Nile, making personal tea, turning on a radio, talking quietly, sitting at home or fishing are examples; the precise fishing loop, tackle and economic returns are **PROPOSED**, not locked. No mandatory "relax +5" UI, customer spawn to fill every lull, compulsory nightly quests, or quota to unlock returning home.

## Domain and UX boundaries

- Reuse canonical **P1 World Time/Scheduler** for duration, calendar and transitions, **P2** for offscreen lives, **P4** for actual order expiry. No scene-local fake day clock, free cash or automatic NPC demand tied to the player's distance.
- E1 defines authored opening/closing state and a repeatable world-to-home experience, not a one-day fixture promoted to game authority. Day lengths, hours and travel mechanics are **OPEN/tunable**.
- Needs and wellbeing consequences belong to [NEEDS_AND_WELLBEING](NEEDS_AND_WELLBEING.md); purchases and commute economics belong to [EVERYDAY_ECONOMY_AND_HOME](EVERYDAY_ECONOMY_AND_HOME.md).
- Narrative opportunities can be ignored. The flow must continue with no dialogue participation.
- Future buses, last departure times and independently explorable streets are **examples/candidates**, not compulsory content in this milestone.

## Player acceptance contract (pending)

A player can enter the actual game, move through the authored home↔kiosk transition, open, serve or quietly wait, choose to close early, return home, sleep and begin a later day. Leaving and reentering respects independent NPC/order history. Save/reload preserves the current workday and doesn't re-pay, re-serve or roll back time. Observe one profitable day and one deliberately quiet day; neither is treated as failure. These gates are **to implement**, not evidence that current QA T-key tests already fulfill them.
