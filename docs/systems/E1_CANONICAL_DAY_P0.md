# E1/P0 — canonical day rhythm

Issue: #56 (LIFE-01/LIFE-02). **Partial implementation only**. E1 remains open.

## Domain authority

`scripts/core/daily_life_world.gd` is part of the single WorldKernel snapshot (v9) and event log. `life.configure` requires explicit trusted `system:director` authoring and a valid spatial graph and kiosk venue. The game entry configures its authored provisional values only once when the canonical daily policy is absent; reloading an existing world never reopens the shop. Existing v7/v8 event-log snapshots are verified before being migrated to v9; malformed/tampered life projections are rejected.

Commands: `life.open`, `life.close`, `life.sleep` (player only, empty payload). Open/close require the actual kiosk location, do not require a sales quota, and cannot silently grant money or complete orders. The game starts closed. A closed venue cannot receive canonical autonomous P4 offers or accept fresh orders, but all NPC routines and expiry schedules continue, including while the player is away. Historical QA worlds without a configured daily policy retain existing demand semantics.

Sleeping requires a closed shop and the actual roof room; it atomically advances P1 World Time and all dependent scheduled NPC/service/cooking/housing firings to the next authored wake time. The sleep receipt, elapsed time, morning day index and workday state are event-replayed; repeat sleeping on the same wake day is rejected. The current starting example uses **08:00 wake**, **240-minute minimum overnight interval**, and **17:00 new-world opening moment**. These are **PROVISIONAL authoring policy**, not locked pacing or final Egypt shop hours. The 60 m² southern apartment is separate from the starter roof room; sleeping there will require a later owned-home mapping rather than inventing rent rules.

## Gameplay

New key actions on the existing E6 game scene: `O` open, `C` close, `Z` sleep at home. `G` remains canonical P3/P4 service and is blocked while closed. The quiet-day and early-close options are valid even without revenue, and NPCs do not freeze because the player goes home. Existing E6 world status projects kiosk open/closed and number of nights, rather than keeping UI-owned authoritative state.

## Acceptance and limits

- Native `tests/test_e1_daily_life.gd`: closed scheduled demand, independent NPCs, rejected remote/double open and close, no enforced quota, roof travel, next day, replay/tampered life state, and next-day demand when reopened.
- Existing native E6 and Chromium E6 smoke are extended for deliberate opening. Browser test also closes, travels home, sleeps, saves and verifies hard reload.
- All SYS P0–P7/C0/C1–C6 regressions must remain green.

**Not done:** actual in-home downtime interaction objects, fishing/radio, E2 needs, authored multi-day/supplier balance, spatial furniture collision, full service closing behavior for in-progress orders, final world clock scale, audio, art, Arabic/RTL, player acceptance. This is E1 **P0** only, not a full experience sign-off. Independent V001 PR #20 stays unmerged and visually unapproved.
