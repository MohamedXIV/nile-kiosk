# D001 browser refresh persistence

**Status:** acceptance pending actual Chromium CI. User-facing fiction text is intentionally English-only.

The chosen Ink/inkgd baseline has a versioned GameState + independent story state serializer in `scripts/spike_save_codec.gd`. In the browser kiosk, press **P** to persist a story snapshot to `user://nile-kiosk-d001-ink.json`. On a subsequent page load, the scene waits for both real `InkPlayer` instances to finish their deferred startup before applying the snapshot, and reconstructs the visible dialogue transcript from the canonical event history.

The scene suspends world ticking during restore to prevent NPCs advancing by a frame while the save has yet to load. This path is enabled for **Ink in Godot Web only** so the native tests and Dialogue Manager alternative remain unaffected.

The additional Playwright test in `tools/web-ink-refresh-smoke.mjs` uses the *same real exported* `ink/index.html` browser scene, reaches a knowledge-gated mid-dialogue player interjection, saves through Godot FileAccess, reloads the browser page, verifies the pending choice, world tick, canonical knowledge, player position, and event history, then chooses the interjection. After finishing, it saves/reloads again, verifying completed conversations do not replay and rumor facts are not duplicated.

A passing test confirms IndexedDB/user storage in its particular Chromium origin/profile. It **does not** guarantee saves survive browser data removal, private sessions, a different site origin, storage eviction, or transfer to another device.

Web smoke runs in the existing full-dialogue workflow (no duplicate heavy action runner). Test must print `D001_BROWSER_REFRESH_PASS` before claiming browser persistence acceptance.
