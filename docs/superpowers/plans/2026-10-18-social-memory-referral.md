# Social Memory and Referral Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Execute inline under the user's autonomous engineering authorization.

**Goal:** Let a returning customer remember genuine service in authored dialogue and teach a fact enabling a paid stock delivery.

**Architecture:** Derive memory from P4/C6 and P3; freeze evidence in a guarded P6 session. P2 grants supplier knowledge only on heard speech. A focused supply-contract helper composes P5 payment, P1 elapsed time and P3 stock in one kernel event.

**Tech Stack:** Godot 4.6.3, GDScript, pinned inkgd, Ink 1.2.1, Playwright/Chromium.

**Spec:** `docs/superpowers/specs/2026-10-18-social-memory-referral-design.md`

## Global Constraints
- One authoritative WorldKernel; retain P1/P2/P3/P4/P5/P6 responsibilities.
- Preserve existing E4 conversations and human-gated art PR #20.
- Terms and authored prose are provisional; no trust/cash/stock from ordinary dialogue.
- Preserve supported saves/replay, and keep #55/#59/#60/#61 OPEN/PARTIAL.

## Review Focus
- Returning order must be later than the remembered closure, and belong to that customer/venue.
- Unsettled or cancelled orders cannot become paid memories; unrelated NPCs cannot claim them.
- Supplier knowledge must have real P2 provenance, including privacy/audience checks.
- Failed and duplicate purchases must leave ledger, clock, stock and resolutions unchanged.
- Pending choices and committed effects must survive disk/Web reload without repetition.

### Task 1: Derived and authored returning-customer memory
**Files:** `scripts/core/customer_experience.gd`, `world_kernel.gd`, `narrative_world.gd`, `ink_world_bridge.gd`, production `customer_memory_play.gd`, `game_entry.gd`, `game_scene.gd`, `content/social/nile_returning_customer.v1.json`, matching Ink, `tests/test_e4_customer_memory.gd`.
**Interfaces:** `WorldKernel.customer_memory(npc_id, venue_id) -> Dictionary`; guarded story metadata `customer_memory`; production adapter configure/begin/next/choose/state/near over the existing session and graph.
- [ ] Write production-adapter native acceptance for fresh/real settled good/rough/abandoned histories, canonical branch rejection, physical knowledge and pending-choice replay; run RED.
- [ ] Implement pure memory derivation, guarded P6 evidence and Ink branch, adapter and normal input/UI.
- [ ] Run native acceptance plus existing E4/C6 tests; commit the coherent playable feature.

### Task 2: Knowledge-gated audited delivery
**Files:** `scripts/core/supply_contracts.gd`, `economy_world.gd`, `world_state.gd`, `world_kernel.gd`, production adapter/UI/content, `tests/test_e5_referral.gd`, schema assertions in existing tests/browser fixture.
**Interfaces:** `supply.offer.register`, `supply.purchase`, `supply.decline`; P5 `supply_offers` and `supply_resolutions`; purchase request is only `{offer_id}` and terms come from registered catalog.
- [ ] Write RED native tests for unknown/unheard/private fact, insufficient funds, expiry, paused time, overflow, decline, duplicates, ledger/stock/time/provenance and schema-11 migration.
- [ ] Implement validated one-event cross-domain procurement and visible terms/accept/decline controls.
- [ ] Run new acceptance and P0–P7/E4/C6 regressions; commit.

### Task 3: Browser acceptance, full verification and delivery
**Files:** `tools/web-social-memory-referral-smoke.mjs`, existing Native/Web workflows, execution board/roadmap/traceability/design evidence.
**Interfaces:** Production status diagnostics only expose canonical projections; browser uses real key input and disk reload, with no production test command/cheat API.
- [ ] Add Chromium positive/negative history, earned/unheard referral, pending-choice hard reload, decline and duplicate coverage; watch new checks fail before corresponding UI integration if not already exercised natively.
- [ ] Integrate tests into existing workflows and run full native/Web/Ink locally at final committed head.
- [ ] Obtain a fresh whole-branch review, fix important findings and rerun affected acceptance.
- [ ] Publish feature branch/PR and exact-head CI when access permits; merge only with full exact-head success and authorization. Reconcile documents/issues with actual evidence and remaining gaps.
