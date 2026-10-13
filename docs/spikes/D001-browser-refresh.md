# D001 browser refresh persistence

**Status:** **PASS** on Godot 4.6.3 actual Web/Chromium, [CI run #38346547761](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38346547761) (PR #21). User-facing fiction text is intentionally English-only.

The chosen Ink/inkgd baseline has a versioned GameState + independent story state serializer in `scripts/spike_save_codec.gd`. In the browser kiosk, press **P** to persist a story snapshot to `user://nile-kiosk-d001-ink.json`. On a subsequent page load, the scene waits for both real `InkPlayer` instances to finish their deferred startup before applying the snapshot, and reconstructs the visible dialogue transcript from the canonical event history.

The scene suspends world ticking during restore to prevent NPCs advancing by a frame while the save has yet to load. This path is enabled for **Ink in Godot Web only** so the native tests and Dialogue Manager alternative remain unaffected.

The additional Playwright test in `tools/web-ink-refresh-smoke.mjs` uses the actual exported `ink-persist/index.html` **dedicated test fixture** (identical kiosk+Ink runtime; starts at football table with canonical match knowledge at tick zero, with no browser-only teleport input), reaches a knowledge-gated mid-dialogue player interjection, saves through Godot FileAccess, reloads the browser page, verifies the pending choice, world tick, canonical knowledge, player position, and event history, then chooses the interjection. After finishing, it saves/reloads again, verifying completed conversations do not replay. In this browser run the rumor was not in hearing range, so **the saved rumor-fact count was zero**; idempotency of a genuinely learned rumor was verified separately in the native P3 tests, not by this browser run.

A passing test confirms IndexedDB/user storage in its particular Chromium origin/profile. It **does not** guarantee saves survive browser data removal, private sessions, a different site origin, storage eviction, or transfer to another device.

Web smoke runs in the existing full-dialogue workflow (no duplicate heavy action runner). **Verified marker:** `D001_BROWSER_REFRESH_PASS` in the live Chromium job. Saved and restored snapshots were byte-matching for the tested clock/event/position fields (first save tick 4, events 5; second save tick 21, events 12). Both real narrative candidates also passed the legacy full Web smoke in the same run; Godot P0 smoke completed successfully ([run #38346547742](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38346547742)).
