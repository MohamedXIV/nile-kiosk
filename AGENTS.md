# Agent working agreement — Nile Kiosk

- Always inspect current GitHub `main`, open PRs, issues and checks before taking work; never assume a recorded SHA is current.
- This is a **public game repository**, but project decisions are provisional. Don't rewrite the game vision to justify an engine already chosen.
- Prefer working branches + PRs for meaningful changes; avoid overlapping changes and duplicate spike implementations.
- D001 uses **English dialogue fixtures only**. Arabic/RTL is intentionally deferred.
- Keep authored dialogue/story distinct from the social orchestrator and canonical GameState. No story addon owns world truth.
- The world keeps running while NPCs talk; an uninvolved player can keep cooking or leave.
- For the visual spike, use a fixed oblique top-down camera with floor-aware logic; avoid a misleading side-view stack of flat layers.
- Avoid single monster files and unnecessary one-file-per-trivial-function fragmentation.
- Use GitHub Actions when they provide real value: public-runner CI is allowed, but do not add repeated heavy jobs or empty placeholder workflows.
- Report actually run tests separately from proposed acceptance gates. Failed or unrun checks are not PASS.
- Prefer official engine features before inventing custom substitutes. Pin add-on versions/commits for reproducible spikes.
