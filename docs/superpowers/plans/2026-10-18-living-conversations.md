# Living Conversations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Independently progressing Salma/Mahmoud exchange with optional spatial Ink participation.
**Architecture:** Pure P1-derived conversation projection, canonical P6 session guard/history, P2 hearing, shared existing Godot navigation poses; thin gameplay adapter.
**Tech Stack:** Godot 4.6.3, GDScript, inkgd, pinned Ink 1.2.1.
**Spec:** docs/superpowers/specs/2026-10-18-living-conversations-design.md

## Global Constraints
One WorldKernel; no second time/NPC/knowledge authority. English provisional content. #55/#59/#60/#61 OPEN; art #20 untouched. Full native/Web exact-head proof before delivery.

## Review Focus
- An unfinished choice must not stop NPC progression or cooking.
- Walking away during a choice must withhold information and reject answers.
- A line-boundary save must restore the actual Ink choices.
- Reusing another session ID must not consume the same daily boundary twice.
- Private and absent participants must not leak caption or knowledge.

### Task 1: Canonical conversation and production integration
**Files:** new core/conversation_rules.gd, gameplay/living_conversation_play.gd, social/Ink authored content; modify narrative_world.gd, game_entry.gd, game_scene.gd.
**Interfaces:** `conversation_view(story_id)` returns pure timeline; adapter `begin/next/choose` invokes P6. Existing session `conversation_day` freezes occurrence.
- [ ] Write production native test `test_e4_living_conversation.gd`: ignored/near/remote/early/late/private/absent, real Ink choices, P2 hearing, save/replay/duplicate.
- [ ] Run test and observe missing production conversation behavior.
- [ ] Implement bounded metadata/rules and adapter, shared Godot spatial evidence, default input/presentation.
- [ ] Run focused new and existing E4/E6 tests, fix regressions.
- [ ] Commit coherent production batch.

### Task 2: Browser proof and delivery
**Files:** new tools/web-living-conversation-smoke.mjs; existing native/Web workflows; system/design/traceability/board/roadmap docs.
- [ ] Exercise actual default controls: tea+independent exchange, joining/responses, movement away, ignored completion, pending hard reload and fact persistence.
- [ ] Add acceptance to existing workflows, update exact scoped documentation.
- [ ] Commit; run all native tests, four startups, nine exports and all Chromium drivers at exact HEAD.
- [ ] Obtain independent final review, fix important findings with regression evidence, rerun exact-head gates.
- [ ] Push and verify remote SHA; normal PR attempt or prepared body/report with truthful local/hosted distinction.
