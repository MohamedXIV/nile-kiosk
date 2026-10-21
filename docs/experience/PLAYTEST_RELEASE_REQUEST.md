# Explicit Web & Windows Playtest Release Request

This file is an intentional, reviewable trigger for `.github/workflows/playtest-builds.yml` **only on pushes to `main`**. Editing the request produces reproducible Godot 4.6.3 Web and Windows x64 playtest ZIPs and a **public prerelease** tagged `playtest-<main commit SHA>`, using pinned Dialogue Manager / inkgd / Ink compiler and SHA-256 checksums.

## Release request — 2026-10-21

- Purpose: first playable post–Game-Feel P4c release, with Mahmoud and Mona's physically grounded NPC-initiated dialogues, optional timed Ink replies, uninterrupted cooking/payment, and touch improvements.
- **Merge gate:** merge this request only **after** P4c2 [#131](https://github.com/MohamedXIV/nile-kiosk/pull/131) is merged into `main`, with exact-head Godot Native and full Chromium Web acceptance passing. Do not publish a P4c2-labelled build of unmerged code.
- Delivery: GitHub Actions creates `Nile-Kiosk-Windows-x64-playtest.zip`, `Nile-Kiosk-Web-playtest.zip`, and `SHA256SUMS.txt` in GitHub Releases. Windows build is unsigned. Web ZIP needs HTTP(S), not `file://`.
- Caveats: early functional prototype, **not final art**, no claim of real-user phone/PC comfort sign-off or Arabic/RTL readiness. Leave V001 art PR #20 untouched.

For another *explicit* release, update the date and tested release scope in this file on `main`. Ordinary gameplay commits do **not** publish prereleases automatically.
