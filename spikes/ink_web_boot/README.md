# D001 P2 — actual inkgd Web boot gate

**Status:** **Web boot verified** on Godot 4.6.3 after [PR #10](https://github.com/MohamedXIV/nile-kiosk/pull/10); this is not full D001 P2 adapter parity.

This isolated Godot 4.6.3/GDScript project deliberately uses **a real InkPlayer and InkResource**, not a simulated Ink parser. The compiled Ink fixture is taken from `ephread/inkgd` upstream test source, `test/fixture/compiled/runtime/booleans/true.ink.json`.

## Fixed external dependency

- Source: https://github.com/ephread/inkgd
- Branch: `godot4`, pinned to commit `fea9098ee18d6cdbe9a5e25f8f0296bcdf0fd96a`.
- CI obtains `addons/inkgd/` from the upstream commit; the addon is intentionally not vendored.
- `InkPlayer.loads_in_background=false` to target single-threaded Web; this is an explicit strategy, not a benchmark.
- Export uses Compatibility/WebGL 2 with `variant/thread_support=false`.

## Gate criteria

1. Actual Godot native headless `InkPlayer.loaded(true)` followed by nonempty `continue_story()`.
2. `godot --export-release Web` succeeds.
3. Chromium loads the exported app over HTTP and receives `INK_WEB_BOOT_PASS` emitted *after* actual Ink story load and continuation. Browser console errors should be reported.
4. Do not claim full authored dialogue parity, multiple independent players, persistence or Ink-to-Godot import parity based on this small boot test.

An existing inkgd issue #96 reports Web initialization not finishing in an older Godot build. Failure here should be investigated for single-thread boot/cross-platform compatibility instead of assuming Ink cannot work on Web.

## Verified evidence

- [GitHub Actions run #38308642648](https://github.com/MohamedXIV/nile-kiosk/actions/runs/38308642648): native InkPlayer load/continue PASS, Web export PASS, actual headless Chromium execution PASS (`D001 P2: REAL CHROMIUM WEB BOOT PASS`).
- Pin: inkgd Godot-4 branch commit `fea9098ee18d6cdbe9a5e25f8f0296bcdf0fd96a`; `__InkRuntime` explicitly registered as an autoload to avoid missing-root-node diagnostics.
- **Residual:** Godot's headless Web export exits with resource/RID leak warnings although the command returns success. Browser runtime completion is verified, but shutdown is not leak-free. Investigate separately rather than claiming it clean.
- **Not yet tested:** two independent Ink stories, equivalent authored dialogue flow/interjections, save/load. Those remain open in issue #7/#8.

This is intentionally isolated from the game's Dialogue Manager P1 baseline.
