# Run a Nile Kiosk playtest

This is a **pre-release functional gameplay test**, not approved final art, user-validated mobile UX, Arabic localization, or a commercial release.

## Windows desktop (no Godot required)

1. Open [GitHub Releases](https://github.com/MohamedXIV/nile-kiosk/releases).
2. Choose the latest `playtest-...` **Pre-release**, download `Nile-Kiosk-Windows-x64-playtest.zip`.
3. Extract the entire ZIP to a normal folder. Run `NileKiosk.exe`. This is an **unsigned** x64 early playtest; if Windows security warnings appear, independently verify the file source/hash using the release's `SHA256SUMS.txt`. Do not disable system security settings.
4. Keep the folder in the same location if you want to continue saving locally. Standard Godot user data is stored by the engine in the user's application data, not in a test fixture.

## Mobile and desktop browser

When [GitHub Pages](https://github.com/MohamedXIV/nile-kiosk/settings/pages) is enabled with **Source: GitHub Actions**, the `Nile Kiosk playtest builds` workflow can publish the Web build. Open the resulting `https://mohamedxiv.github.io/nile-kiosk/` address on desktop or mobile after confirming that the deployment succeeded. **This URL is not promised to be active before Pages is enabled and a successful deployment finishes.**

The same GitHub Release also offers `Nile-Kiosk-Web-playtest.zip`, for hosting on any local/HTTPS static server. **Opening `index.html` directly as `file://` is not supported by Godot's Web export**. On a computer with Python installed, extract the ZIP then from that extracted folder run `python -m http.server 8765` and visit `http://localhost:8765/` in your browser. Other devices on your network need a properly bound local server/network address; HTTPS hosting is preferred.

Web saves are stored in that browser's site storage, not shared between Windows and different browsers/devices. Clearing site data or switching origin can delete your playtest progress.

## How builds are made

`.github/workflows/playtest-builds.yml` assembles **both pinned narrative addons**, compiles authored Ink with verified inklecate v1.2.1, uses Godot 4.6.3 Web/Windows export templates, creates user-facing ZIPs and checksum hashes, and attaches them to a **public GitHub prerelease** at the reviewed `main` commit. It runs on a change to the build workflow, or by manual Actions dispatch. No constant daily build or new game logic.

On mobile, landscape is currently the tested viewport. The 640×360 Chromium acceptance covers a narrow set of touch gameplay flows, not actual device comfort or phone-only parity with every keyboard shortcut; see [Game-First touch acceptance](experience/GAME_FIRST_TOUCH_ACCEPTANCE.md).
