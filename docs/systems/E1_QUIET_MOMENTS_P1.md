# E1/P1 — authored quiet moments, without score farming

Tracker: [E1 #56](https://github.com/MohamedXIV/nile-kiosk/issues/56), LIFE-02. **Partial gameplay delivery; no full E1/E2/art approval.**

## Approved scope and meaning

Work should never be mandatory for an entire in-game day. The user can spend several minutes watching the Nile or sitting quietly on their rooftop without receiving a fabricated mood bonus, money or a customer quota. E1 owns **the decision and the elapsed time**; E2 will later own context-aware Mood/Rest/Wellbeing effects. Radio listening is deferred until it can require a real owned/placed household object; fishing remains proposed and is **not** included here.

The two initial, clearly **provisional** authored positions and durations are in `content/life/nile_quiet_activities.v1.json`:

- `roof_breeze`: roof spot next to the room, requires closing the kiosk, 10 canonical minutes.
- `river_watch`: Nile-side kiosk railing spot, valid while either open or closed, 8 canonical minutes.

These are **world coordinates in the temporary 240×160 gameplay graph**, not approved Cairo building metre dimensions, final 2:1 art or an artwork sign-off. Captions are authored presentation-only strings, stored separately from world truth.

## Authority and persistence

`life.activities.configure` is authorized to `system:director` and installs a strictly checked immutable activity catalog into the **existing `DailyLifeWorld.policy` (v9)** after validating the spatial graph. Fresh games and pre-P1 v9 saves acquire it through a single idempotent event; existing saves are never erased or silently rewritten. No new WorldState schema is required. World kernel commands retain their exact-once receipt semantics.

`life.activity` takes only an activity ID, must originate from `player`, validates current **canonical room/XY** versus authored spot radius and optional closed requirement, rejects paused time and overflow, and atomically advances canonical P1 world minute via the same scheduler as normal `time.advance` and sleep. Therefore NPC arrivals/departures, unattended order expirations, cooking timers and rent continue normally. The event log records `life.activity_done` with the verified scheduler outcome, making the choice observable and replayable. Neither money nor any imagined E2 need is altered by leisure itself. Repeated activities have no `+5 Relax` or other numeric farming payoff.

Presentation: `Q` at an actual marked spot triggers the authored action; the provisional E6 screen displays its location, the textual moment and the number of historical quiet moments derived from events. The view never keeps an independent authoritative counter.

## Acceptance

- Native: `tests/test_e1_quiet_moments.gd` — wrong room/distance/actor/activity rejected without mutation; paused world rejected; offscreen NPC arrives while player sits; kiosk closure suppresses offers; work can resume afterward; exact receipt re-submission, forged elapsed minutes, save/reload/replay and no reward.
- Chromium: `tools/web-e6-game-entry-smoke.mjs` — walk to river during an accepted live order, enjoy a non-pausing quiet moment, save/reload with order intact, go home, spend quiet rooftop time, sleep, and verify exact hard-browser-reload identity.

**Not delivered:** recorded/broadcast radio, household ownership/comfort loop, tactile individual seating animations, contextual personal tea, meaningful E2 Mood or long-term wellbeing effects, balancing approval, in-world localized Arabic captions, quiet ambient sound, real visual asset approval. Keep #56 and #57 OPEN and V001 [PR #20](https://github.com/MohamedXIV/nile-kiosk/pull/20) separate.
