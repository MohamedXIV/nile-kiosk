# D001 P3 — full scene Chromium verification

Status: PR implementation pending CI.

Unlike the earlier isolated Ink Web boot, this gates the real main kiosk scene for **both** P1 Dialogue Manager and P2 Ink adapters. Web exports are generated one candidate at a time, without modifying committed engine settings. Both use the identical shared scene, three-step tea action and authored independent NPC sessions.

## Acceptance

For each candidate, Chromium must execute the exported Godot app with actual add-ons installed. The browser harness presses E three times near the initial tea counter to prepare a drink. The scene emits a PASS marker only after **both NPC sessions actually finish**, **both emitted at least two authored lines** and **tea_served was emitted**. Capture screenshot and console errors. A successful export alone does not count.

Artifacts: GitHub Actions browser screenshots (no deployment).

## Exclusions

This is not a save/load or knowledge/interjection Web acceptance; those currently have native integration tests. Final D001 choice must wait for P3 save/load and comparable evidence. Arabic/RTL deferred.
