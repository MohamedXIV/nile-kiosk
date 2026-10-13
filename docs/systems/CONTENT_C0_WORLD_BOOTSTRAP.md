# CONTENT C0 — Transactional, Data-Authored World Bootstrapping

[Issue #41](https://github.com/MohamedXIV/nile-kiosk/issues/41). The P0–P7 world simulator is complete, but **authored data is not yet final gameplay content**. This contract permits designers to supply a versioned world catalog without rewriting production kernel systems or silently treating the P7 QA scene's hardcoded fixture as canonical content.

## Format and boundary

- Packaged `res://content/world/*.json` only. `schema: 1`, `bundle_id`, and a non-empty ordered `commands` array. Every entry requires exactly `id`, `kind`, `actor_id`, `payload`. Commands run through `WorldKernel.dispatch` in authored order (up to 256), receiving stable scoped IDs `catalog:<bundle-id>:<id>`. Duplicate IDs, unknown fields, invalid JSON values, unsupported schema or unknown dependencies are rejected.
- **Strict local authoring allowlist:** NPC registration and routine definitions; player start location and authored public/private world facts; ingredient definitions and initial ingredient stock; recipe/station/venue catalogs; housing unit and roof grants; furniture types/grants; explicit recipe prices and first-money grants. Each kind is tied to its appropriate trusted `system:` actor, and every normal production domain validates the payload. The file cannot schedule arbitrary jobs, advance time, buy/deliver food, settle orders, secretly grant dialogue facts by script, refund rent, or masquerade as a customer.
- The importer is a **trusted, shipped local-content interface**, not permission to accept user-uploaded JSON, paths or arbitrary actor identities from a network. For genuine modding, sandbox/content validation and actor isolation would require a separate design.
- `WorldContentBootstrap.prepare(...)` constructs a **fresh candidate kernel** and applies all commands. If any entry fails, no partly imported world is returned and the caller retains the original untouched world. Diagnostic result includes the rejected index and typed kernel cause. Same ordered bundle + seed produces the same canonical event history/snapshot.
- `WorldSession.bootstrap_from_content(path)` commits a staged world only for a genuinely uninitialized session **and only if its chosen save slot does not already exist**. Existing live sessions, resumed saves and existing disk slots are never overwritten or reseeded. Worlds then use ordinary P0–P7 commands, version-7 save/restore, events, receipts and deterministic replay; no second authoritative economy or NPC data.
- **All authored values are data**. The importer has no built-in EGP amount, special NPC, global recipe count, hardcoded clock speed, default rent or private-flat ownership. It makes no irreversible art or gameplay assumptions.

## Current QA content — *not* game balancing

`content/world/qa_nile_kiosk.v1.json` is **explicitly test-only**. It proves two NPCs, one scheduled routine, initial world location and a fact, two recipes and stations, inventory, service venue, a roof right and separately leasable 60 m² apartment, furniture, and deliberately artificial sample cash/prices/rent. These values **are not approved economic design** and must not be reused as the shipped content or inferred as 2000–2005 Egyptian purchasing power.

`tests/test_content_c0.gd` verifies strict schema/actor/command allowlists, duplicates, invalid fields, missing content, directory traversal, rejection after partially valid commands, deterministic reimports, two genuine recipe operations and an order paid at an authored price, authored apartment rental, strict-save readback, refusal to overwrite an existing save and unchanged repeat-save integrity.

**Next content work** is to author the real NPC, recipe, ingredient and place catalog from design (and reconcile the V001 home visual art). The P7 scene remains an isolated QA scenario rather than becoming the shipped game by accident. No V001 PR #20 modifications; no claims of final art, content scale or balancing.
