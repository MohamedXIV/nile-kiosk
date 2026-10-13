# SYS P0 — World Kernel implementation contract

**PR target:** [SYS P0 #24](https://github.com/MohamedXIV/nile-kiosk/issues/24). **Status: implementation being verified; tests must pass before merging or closing.**

The world kernel is independent of D001 and V001: \`scripts/core/world_state.gd\` is the mutable event-validated authoritative state and \`scripts/core/world_kernel.gd\` is the only command boundary. There is no Godot Node, authored Ink session, drawing, food-counter fixture or real-time clock in these domain files.

P0 defines:
- Seed identity (positive bounded integer), versioned \`WorldState\` snapshot and deterministic event sequence;
- Explicit input command with \`id\`, \`actor_id\`, \`kind\`, \`payload\`; typed result \`ok\`, \`code\`, optional \`event_id\` and \`revision\`;
- Working domain command \`knowledge.grant\` producing canonical \`knowledge.granted\` events, with stable command idempotency, conflict rejection and exactly-once facts;
- Read-only copies for consumers (\`view\` / \`event_history_after\`), deterministic event IDs and explicit cause/actor/time;
- Replay-validated restore that **rejects corrupted snapshots atomically** and restores receipt history, including event/receipt/fact consistency;
- Filesystem JSON snapshot round-trip via temporary file and rename.

The kernel's current \`world_minute=0\` is **reserved, not a live scheduler**. P1 will introduce canonical time advancement and versioned schema evolution, with its own tests. Do not infer any player day-length or NPC calendar from P0.

These APIs deliberately cover **one real command** rather than pretending NPC, cooking, money and housing already exist. New bounded-domain handlers must be explicitly integrated into the same authority; do not create new authoritative \`GameState\` copies and do not turn this into a generic ECS prematurely. The D001 dialogue fact fixture remains in its isolated spike until migration is tested.

**Acceptance:** four headless test groups cover validation/idempotency, deterministic replay, real JSON file roundtrip, and tampered snapshot rejection. A PR passing only P0 is a verified **kernel**, not a completed simulation, time/calendar system or playable game.
