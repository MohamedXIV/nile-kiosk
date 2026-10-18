# Procurement Alternatives Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Real audited delivery-versus-market collection choice.
**Architecture:** Existing P5 supply offers/resolutions, strict optional availability and public gate; P1 elapsed events/needs and P3 stock; thin production adapter.
**Tech Stack:** Godot4.6.3/GDScript/inkgd.
**Spec:** docs/superpowers/specs/2026-10-18-procurement-alternatives-design.md

## Global Constraints
One WorldKernel and existing P1–P6 authorities; price450, quantity30, travel40min, 17–19 window and stock30 explicitly PROPOSED; no invented market geometry. #55/#59/#60/#61 OPEN, #20 untouched.

## Review Focus
- Starting late must not complete after closing.
- Shared vendor lot must not permit overselling through a second offer.
- Public collection must never accidentally require/fabricate knowledge provenance.
- Scheduler events must affect unattended orders and needs during collection.
- Decline and replay must not restore consumed vendor stock.

### Task1: Canonical availability and playable alternative
Files: core/supply_contracts.gd, gameplay/procurement_play.gd, content/economy/nile_market_collection.v1.json, game_entry/scene; tests/test_e5_procurement.gd.
- [ ] Write/run failing real Game test for missing public collection.
- [ ] Implement strict optional availability, public gate, shared finite stock derived from resolutions and explicit status projection.
- [ ] Compose existing atomic P5/P1/P3 purchase, preserve old offer event shapes.
- [ ] Add counter controls and honest terms/completion; run focused procurement/referral/E4/E6 tests.
- [ ] Commit.

### Task2: Browser and separate delivery
Files: browser driver, existing native/Web workflow steps, system/traceability/board/roadmap docs.
- [ ] Test default public collection/decline/expiry and equal-start learned delivery versus self-collection with actual controls.
- [ ] Update scoped docs and workflow; commit.
- [ ] Full native4startup/9export/allChromium acceptance at exact HEAD, independent review and important regression fixes.
- [ ] Push branch, verify remoteSHA, normal PRattempt/prepared body, evidence archive; report local versus hosted accurately.
