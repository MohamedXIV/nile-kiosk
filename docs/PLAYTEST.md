# Run a Nile Kiosk playtest

This is a **pre-release functional gameplay test**, not approved final art, user-validated mobile UX, Arabic localization, or a commercial release.

## Windows desktop (no Godot required)

1. Download the [Windows x64 ZIP from first verified playtest release](https://github.com/MohamedXIV/nile-kiosk/releases/download/playtest-8dfb28ffac36/Nile-Kiosk-Windows-x64-playtest.zip), or browse [all prereleases](https://github.com/MohamedXIV/nile-kiosk/releases).
2. Extract the downloaded archive.
3. Run `NileKiosk.exe` from the extracted folder. This is an **unsigned** x64 early playtest; if Windows security warnings appear, independently verify the file source/hash using the release's `SHA256SUMS.txt`. Do not disable system security settings.
4. Standard Godot user data is stored in the user's application data, not in the test fixture or the extracted ZIP.

## Mobile and desktop browser

**Play online now:** [https://nile-kiosk-playtest.vercel.app/](https://nile-kiosk-playtest.vercel.app/) (Vercel production deployment of the reviewed `playtest-8dfb28ffac36` Web release asset, verified `READY` and HTTP `200` on the Godot HTML/JS entry). Open this HTTPS URL in a desktop browser or mobile Chrome. Rotate the phone to **landscape** and tap **On-screen** for the native Godot touch pad. Automated 640×360 Web acceptance passed before this release; no human phone-device signoff is claimed.

**Optional fallback:** GitHub Pages is currently not configured for the repo; the release workflow can deploy there after the owner enables Settings → Pages → Source: GitHub Actions and manually runs the `Nile Kiosk playtest builds` workflow. Do not treat `https://mohamedxiv.github.io/nile-kiosk/` as live without a successful Pages deployment.

The same GitHub Release also offers `Nile-Kiosk-Web-playtest.zip`, for hosting on any local/HTTPS static server. **Opening `index.html` directly as `file://` is not supported by Godot's Web export**. On a computer with Python installed, extract the ZIP then from that extracted folder run `python -m http.server 8765` and visit `http://localhost:8765/` in your browser. Other devices on your network need a properly bound local server/network address; HTTPS hosting is preferred.

Web saves are stored in that browser's site storage, not shared between Windows and different browsers/devices. Clearing site data or switching origin can delete your playtest progress.

## How builds are made

`.github/workflows/playtest-builds.yml` assembles **both pinned narrative addons**, compiles authored Ink with verified inklecate v1.2.1, uses Godot 4.6.3 Web/Windows export templates, creates user-facing ZIPs and checksum hashes, and attaches them to a **public GitHub prerelease** at the reviewed `main` commit. It runs on a change to the build workflow, or by manual Actions dispatch. No constant daily build or new game logic.

On mobile, landscape is currently the tested viewport. The 640×360 Chromium acceptance covers a narrow set of touch gameplay flows, not actual device comfort or phone-only parity with every keyboard shortcut; see [Game-First touch acceptance](experience/GAME_FIRST_TOUCH_ACCEPTANCE.md).
