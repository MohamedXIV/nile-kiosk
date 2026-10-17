# Experience delivery board & agent handoff

**Reconciled 2026-10-17 against \`main\` \`1f0e80abc33c483f15b8192878d7a50dbcf6e1d2\`. This SHA is a historical checkpoint, NOT a branch to assume is still current.** Before every execution, inspect live \`main\`, issues, PRs, CI and source through the connected GitHub tools.

**Purpose:** let a new implementing agent recover **what has shipped, which gameplay behaviors remain, possible future ideas, their dependencies, and the evidence needed to call something done** without access to any ChatGPT conversation. This board augments, rather than replaces, [design traceability](../design/DESIGN_IMPLEMENTATION_TRACEABILITY.md), [decision register](../DECISION_REGISTER.md), [system architecture](../architecture/SYSTEM_FIRST_ARCHITECTURE.md) and [experience Epic #55](https://github.com/MohamedXIV/nile-kiosk/issues/55).

## Non-negotiable vocabulary

- **AGREED:** approved direction or gameplay principle. **PROPOSED:** potentially good authoring or mechanics idea, not a user decision. **OPEN:** design/trade-off not resolved.
- **VERIFIED_SCOPE:** specific tested behavior, not necessarily the whole Epic. **PARTIAL:** implemented visible subset with missing acceptance. **FOUNDATION_ONLY:** canonical components exist but the intended player experience does not. **NONE:** no production domain/gameplay proof.
- **P0 / P1 / P2 below are planning *candidates*** for the remaining *Experience* work. They do not override the names or completion claims of existing SYS P0–P7, E1 P0–P2, or PLAY C1–C6. Split/merge a batch when real dependency or review scope warrants it; never turn a suggested candidate into a locked commitment without approval.
- **Playable proof** = player action in the default production game scene plus correct canonical state, negative paths, disk replay, and Chromium evidence where relevant. Green CI for an unrelated fixture is not player acceptance. Screenshot/concept art is not approved production art.
- This is **system-first**, not "build a disposable one-day vertical slice." Existing systems are production foundations; compose them into complete bounded gameplay behaviors, then validate longer player days. Keep implementation modules coherent, without duplicate world authorities or giant feature files.

## Current board — proven and outstanding

| Workstream | Existing evidence on main | Still required (Epic stays OPEN) |
| --- | --- | --- |
| SYS P0–P7, C0, PLAY C1–C6 | Previously merged/tested foundations in [systems delivery board](../systems/SYSTEM_DELIVERY_BOARD.md) | Maintain regressions; do NOT infer that player-facing E1–E6 is done |
| **E6 #61 / ATM-02** | [PR #63](https://github.com/MohamedXIV/nile-kiosk/pull/63): default Godot scene now starts canonical authored playable world; roof↔kiosk traversal, autonomous request/service, saving, native and Chromium | Spatial conversational UI, real audio and time/location feedback, UX/readability, Arabic/RTL testing, visual approval |
| **E1 #56 / LIFE-01** | [PR #64](https://github.com/MohamedXIV/nile-kiosk/pull/64): kiosk opens/closes by player, no sales quota, authentic home sleep/next day, closed order demand, replay and Web | Complete longer play/cadence & order-in-progress edge cases; player feeling/acceptance; tune proposed hours |
| **E1 #56 / LIFE-02** | [PR #65](https://github.com/MohamedXIV/nile-kiosk/pull/65): roof/Nile quiet moments, correct spatial range, real scheduled time, no fake rewards. [PR #66](https://github.com/MohamedXIV/nile-kiosk/pull/66): paid owned/stored/placed radio, atomic P5 use and canonical listening time, old save adoption; Web verification | Actual era-sensitive radio/broadcast audio (with rights), better interactions/placement, home context via E2, optional fishing only if adopted |
| **E2 #57 / NEED-01/02** | [PR #68](https://github.com/MohamedXIV/nile-kiosk/pull/68): canonical v10 Hunger/Rest/Mood + hidden baseline, E1 quiet/radio saturation, P5 placed-bed sleep, P3 personal bread, HUD and [native CI](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39037366128) | **PARTIAL:** environment/heat, home use and food variety, tuning, nuanced mood recovery, human/RTL feedback; mandatory exact-head [Chromium PR checks](https://github.com/MohamedXIV/nile-kiosk/pull/68/checks) |
| **E3 #58 / COOK-02/03** | P3/C3 foundation plus **[PR #70](https://github.com/MohamedXIV/nile-kiosk/pull/70)**: player-performed heat/lift/pour/finish tea via P3 with browser proof | **PARTIAL:** [PR #71](https://github.com/MohamedXIV/nile-kiosk/pull/71) adds deterministic actual cup-quality consequence from player timing; other dishes, authored customer response/price, social recipe learning and human accessibility feel tests remain |
| **E4 #59 / SOC-02/03/04/05** | P2 NPC routines/witnesses, P6 Ink sessions, PLAY C5/6 NPC-only hearing and repeat demand | **FOUNDATION/PARTIAL:** natural visit modes, nonblocking spatial speech/interjections, authored relationships and real referral opportunity |
| **E5 #60 / ECON-02/HOME-02** | P5 auditable ledger/leases/owned furniture; radio **can be bought/placed/used** but no comfort gain | **FOUNDATION/PARTIAL object use:** supplier/market decisions, real social deal, actual household comfort under E2, optional apartment progression |
| **VIS-01 #19 / PR #20** | Standalone technical Blender/Godot art feasibility exists in [open PR #20](https://github.com/MohamedXIV/nile-kiosk/pull/20), NOT merged to main | **DEFERRED USER ART GATE:** final coherent Cairo 2D layers, cutaway readability/visual signoff; never auto-merge |
| **#16** | Shutdown warning report, no established runtime leak | Deferred, low priority; do not block Experience work |

**Remaining effort cannot be reduced to a trustworthy percent or "three PRs left":** E1 has three verified sub-deliveries but unfinished user experience, E6 an executable baseline, E2 not started, E3/E4/E5 substantial player-facing gaps, and final art a separate approval. These are six open Experience Epics with heterogeneous acceptance. Count *proven behaviors*, not arbitrary feature completion percentages.

## Next candidate execution batches / dependencies

### E2 — Needs & Wellbeing ([#57](https://github.com/MohamedXIV/nile-kiosk/issues/57))

**AGREED:** Hunger, Rest and **Mood as the only visible psychological meter**; hidden slowly evolving \`wellbeingBaseline\`. **OPEN:** numerical curves, rates, UI labels and exact modifiers. Do not create Contentment/Relaxation bars, punitive spirals or a happiness-grind.

1. **E2 candidate A — canonical needs state:** P1 time/food/sleep/inventory events feed deterministic needs; define caps and serialized/replayable recovery/depletion; preserve no parallel scene HUD truth. Add replay, time chunks, invalid input and recovery tests.
2. **E2 candidate B — meaningful context:** same rooftop quiet activity/radio/meal under contrasting tired/well-rested, hot/cool, and two distinct living circumstances; repeated actions saturate. Purchasing a fan should NOT instant-grant happiness; actually using a legitimate comfort object under appropriate conditions should change rest quality. Include long vs short horizon proof.
3. **E2 candidate C — player-readable feedback:** in-world cues and restrained Hunger/Rest/Mood indicators that remain accessible/sound-off; test bad-day recovery without locking skillful cooking or income behind low Mood. Browser and human playtest.
4. **Later / proposal:** model nuanced room temperature/ventilation, food preferences and emotionally meaningful social events once authored conditions exist. No speculative simulation complexity first.

**Dependencies:** E1 clock/sleep/quiet & P5 use are ready; **E5 HOME-02** depends on a tested E2 context contract; E3 personal meals later use E2 consumption.

### E3 — Tactile cooking and recipe learning ([#58](https://github.com/MohamedXIV/nile-kiosk/issues/58))

**AGREED:** cooking is a craft, not a G-key shortcut or a stressful 20-click minigame. **PROPOSED:** around 3–6 distinct gestures for suitable starting dishes; "poor/okay/good/excellent" labels, exact timing thresholds, attempt-state names and quality curves.

1. **E3 candidate A — interactive tea/kebda actions:** add player performed pour/heat/stir/turn/season/assemble where sensible (not identical inputs for every recipe), with readable timing and physical cues. Integrate *existing* P3 ingredients, station and item jobs and P4 order; never mint a phantom cooked item. Verify good vs imperfect outcomes follow actions, not random luck.
2. **E3 candidate B — quality and interruption:** real feedback and service consequences, failed/late/invalid input, attention while conversations continue, cancelled orders, kitchen stock depletion; mid-step replay and native/Web actual controls.
3. **E3 candidate C — socially learned technique:** witnessed NPC hints → attempt(s) → better understanding; illustrative \`heard_of → rough_idea → attempted → understood → mastered\` is **not yet a locked schema**. Keep knowledge canonical; authored Ink only presents. A noncommercial home-only meal is valid; connect eating to E2 when ready.
4. **Later / proposal:** recipe variations/period-local delicacies, advice after failed attempts, meaningful personal kitchen preparation rather than more kiosk recipes for their own sake.

**Dependencies:** P3/P4/C3 already work; E4 authored hint integration later, E2 personal use later. Can be implemented in bounded parallel with E2/E4 but share explicit command contracts.

### E4 — Living social space ([#59](https://github.com/MohamedXIV/nile-kiosk/issues/59))

**AGREED:** customers are neighbors, not queueing quests. NPCs can talk to *one another* even when the player ignores them; silence and no transaction are valid outcomes.

1. **E4 candidate A — actual visit circulation:** data-authored takeaway/counter/table/railing/standing visit modes; arrival→optional order→linger→leave; brief passerby vs repeat regular, possible buy-nothing trip. Player remains able to cook. Use P2/P4 schedule and C6 paid/unpaid history.
2. **E4 candidate B — proximity-driven Ink dialogue:** spatial subtitles/speech near actual participants, natural optional interjection at authored beats, privacy/familiarity/hearing gates, silence/rejoin/reconvergent branch, no freeze or scene-owned conversation truth. Test two NPCs talk while player works or walks out.
3. **E4 candidate C — small real consequences:** one genuine witnessed fact leads to an authored E5 supplier/repair/ingredient opportunity with bounded audited ledger; remembered real customer preference/previous encounter reflected in dialogue without a friendship XP bar.
4. **Later / proposal:** richer recurring cast, incidental personal stories, occasional closed/private talks, creative authoring of ordinary football/river/everyday chat. Optional BYOK AI may someday vary **noncanonical dialogue flavour only**, default Off, never required or truth-authoritative.

**Dependencies:** P2/P6/C5/C6 ready; E5 referral storefront contract can land alongside C; E6 spatial UI is an integration concern.

### E5 — Everyday economy and lived-in home ([#60](https://github.com/MohamedXIV/nile-kiosk/issues/60))

**AGREED:** money buys time, comfort and dignity, **not a business empire**. Home objects matter through use; P5 is the sole source for ownership and payments.

1. **E5 candidate A — tangible supplier choice:** one real vendor delivery vs market run with authenticated stock, price, waiting, transport/time cost and potential out-of-stock or substitution; reconcile all with P5 ledger/P1 scheduler. No invented inflation or arbitrary compulsory cost.
2. **E5 candidate B — social referral:** an E4 witnessed/authored fact changes an actual vendor offer/price/access with audit trail and time limits; decline/no-knowledge path also works. No AI-invented deals or instant relationship %.
3. **E5 candidate C — conditional comfort:** actual fan/bed/curtains/radio *usage* affects environmental/rest context through E2, rather than +points at purchase. Existing [PR #66](https://github.com/MohamedXIV/nile-kiosk/pull/66) paid radio proves ownership/use **only**, not this acceptance.
4. **Later / PROPOSED:** bus timetable, market trip, a small tricycle, carrying/fuel/repair choices, eventual move from **24 m² rooftop room** to **~60 m² south flat**, TV/era electronics and possible duplex. None is automatically committed; exact rents and second-home terms are **OPEN**.

**Dependencies:** existing P5 and E1 ready; E4 factual referral and E2 comfort need canonical contracts.

### E6 — In-world presentation and atmosphere ([#61](https://github.com/MohamedXIV/nile-kiosk/issues/61))

**Already done in narrow scope:** [PR #63](https://github.com/MohamedXIV/nile-kiosk/pull/63) makes the *actual default* game entry runnable; E1 actions are available with provisional 2D schematic and keyboard commands. The old D001/default statement in some 2026-10-14 design docs is **historical**, not current.

1. **E6 candidate A — readable actual controls:** replace generic debug-like placeholders and Q/G key complexity with clear spatial context, no modal app-like text spam, readable feedback for cooking/needs/conversation; support sound-off/reduced-overload.
2. **E6 candidate B — environmental ambience:** authored layers of Nile, wind, tea kettle, grill, street, rooftop and eventually radio with proximity/time/location/weather handling where grounded. Radio in PR #66 **does not output real broadcast audio**. Historical recording rights, actual stations/music, detailed mixing and assets remain OPEN; no unauthorized era music.
3. **E6 candidate C — integrated dialogue + RTL:** production spatial Ink interactions while cooking and moving; later Arabic/RTL QA, since D001 English fixtures never proved localized acceptance; web and actual human readability checks.
4. **E6 candidate D — authored 2D visual integration (independent gate):** art remains deferred per [#19](https://github.com/MohamedXIV/nile-kiosk/issues/19)/[PR #20](https://github.com/MohamedXIV/nile-kiosk/pull/20), not a blocker for domain work. Current game schematic **does not** prove final style.

**Camera & art ideas that must not get lost:** fixed-angle orthographic **2D isometric/dimetric** is the *working gameplay baseline*, with pleasant movement in the tested iso prototype; three-quarter top-down remains a visual comparison reference and real-time 3D has been removed from active gameplay camera comparison. **PROPOSED usability test:** bounded smooth zoom and camera follow, wider rooftop framing, closer kiosk action and automatic interior framing/cutaway; orthographic zoom (not perspective dolly) must preserve world interaction, occlusion, screen-relative movement and accurate 2:1 correspondence. The exact **2:1 projection contract is still PROPOSED**; unmerged V001 PR #20 is ~2.067:1. Never combine sprite camera exports from both without coordinated rebake/approval. User specifically requires visual comparisons to **match the prototype camera framing/projection**, not prettier perspective-shifted concept images.

## Cross-epic integration and progress checkpoints

These are **playable acceptance checkpoints**, *not replacements for production-system architecture* or arbitrary sprint deadlines:

1. **Connected working day (partially proven)**: home→kiosk→open→receive order→serve/choose quiet→close voluntarily→go home→sleep→next day, same canonical world and disk/Web replay. E1/E6 smoke provides narrow engineering proof; *human pacing/feel review is still outstanding*.
2. **Cooking + simultaneous people (not complete):** hands-on tea/kebda while two NPCs speak to each other, with optional proximity interjection; no pause; completed food has credible deterministic quality.
3. **Quiet day with personal consequences (not complete):** context changes Hunger/Rest/Mood slowly and recoverably; radio/room/meal choices offer a *feeling* and restrained signal, not grind or punitive loop.
4. **Earn, spend, hear about a useful contact (not complete):** canonical supplier alternative, real expense/time trade-off and one authored information-driven offer; returning NPC acknowledges genuine history.
5. **Presentation and art acceptance (open separate gate):** real atmosphere, user playtest, final art and camera proof, Arabic/RTL; **do not block E2–E5 on #19**.

**Execution preference:** choose the highest-impact *dependency-ready* coherent gameplay behavior from any E2/E3/E4/E5/E6 (not automatically an extra E1 P3/P4). Keep future ideas recorded even when implementation is deferred; don't silently drop them to make roadmap percentages look faster. Priorities may change with live GitHub/user decisions; document why.

## Design candidates / deferred idea parking lot (do not quietly implement)

| Idea / question | Status | Owner |
| --- | --- | --- |
| Full radio tuning, contextual program, licensed era recordings & speaker sound | PROPOSED details; feature direction agreed, no final audio | E6 + E1 #56 |
| Fishing at Nile: tackle, catches, food/economic effect, interaction method | PROPOSED / undecided | E1 #56, E3/E5 only if adopted |
| Market delivery versus personal shopping, vendor trust/credit, repair friend | AGREED choice principle; specifics PROPOSED | E5 #60, E4 #59 |
| Bus/last departure, tricycle, carrying constraints, fuel/maintenance | PROPOSED | E5 #60 |
| Fan, curtains, bed, TV comfort effects and conditional heat/rest | AGREED principle; exact items and curves PROPOSED | E2 #57 + E5 #60 |
| Move to modest south apartment, additional lease, roof-room use/duplex | Modest apartment direction agreed; lease/duplex specifics OPEN/PROPOSED | E5 #60, VIS #19 |
| More recipes/home meals and recipe-advice aftermath | AGREED learning direction; foods/stages PROPOSED | E3 #58 + E4 #59 |
| Nontransactional visits, conversations not yielding quests, relationships not shown as XP | AGREED | E4 #59 |
| Optional BYOK AI flavour only, offline authored game fully functional | AGREED boundary; feature/provider/UX OPEN | E4 #59; not a dependency |
| Exact wake/work time, radio price 1,200 minor units, cook quality bands | Provisional implementation or examples, **not approved game balance** | E1/E2/E3/E5 |
| Zoom/follow/interior cutaway, fixed-angle 2:1 export, artistic style | PROPOSED production details, final visual review OPEN | E6 #61, #19/#20 |
| Shutdown ObjectDB/RID warnings | DEFERRED, no verified player leak | #16 |

## Mandatory agent update protocol

1. **Before working:** refresh live \`main\`, open PRs/issues and recent exact-head checks; read this board, [#55](https://github.com/MohamedXIV/nile-kiosk/issues/55), target Epic, design spec, traceability row and actual source/tests. Do not rely on stored commit SHAs, other agents' chat memory, or a stale issue description.
2. **When choosing a batch:** attach it to an existing Epic, note its proposed/approved status and cross-Epic dependencies. Use a small child issue only when a separate independently closable tracking unit is helpful; don't create one for every ten lines or every idea.
3. **During implementation:** preserve SYS/PLAY canonical authority, small cohesive modules, authored external data, negative tests/idempotency, live player action and save/replay. Work through a coherent PR; CI is permitted and should test real behavior. No competing PR to pending art #20.
4. **On each merge:** update its exact traceability ID, this board's shipped-vs-open scope, [roadmap](../ROADMAP.md) overview, and *target Epic issue* with merged PR, production paths, exact-head native/Web proof and remaining work. Keep status PARTIAL until its whole acceptance is actually proven.
5. **On suggestions/brainstorming:** register ideas in the owning Epic and this board as **PROPOSED**, with rationale and dependencies. Never write "approved", add a binding economic constant or silently implement a future idea simply because an agent suggested it.
6. **On handoff:** report last verified main SHA, PRs and active branches, which gate passed/failed/not run, next dependency-ready batches, and known unresolved design questions. An incoming agent should be able to proceed without conversation transcript.

**No work on this documentation board alone constitutes implementation, additional test proof, final art signoff, or a change to E1–E6 issue closure status.**

## E2 P0 delivery and remaining gates (2026-10-17)
[PR #68](https://github.com/MohamedXIV/nile-kiosk/pull/68) includes canonical bounded Hunger/Rest/Mood and hidden baseline, authenticated P3 stepwise personal bread on K at kiosk counter, conditional real P5 bed rest, E1 contextual leisure saturation, v10 verified historical replay and HUD. Native gate: [native CI](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39037366128). Require successful exact-head [Chromium PR checks](https://github.com/MohamedXIV/nile-kiosk/pull/68/checks) before merge. Keep #57 OPEN; further environment, food, home, long-run economy and playtesting are genuinely unfinished. Check live PR/issue state; do not infer merge from this text.

## E2/E5 delivered scope: attainable household rest choice (2026-10-17; merged [PR #69](https://github.com/MohamedXIV/nile-kiosk/pull/69))

The E2 follow-on adds a provisional-price, P5-ledger-paid secondhand bed to the **actual default roof-room game**, rather than leaving its conditional sleep benefit available only through test-only commands. Authored `content/life/nile_bed.v1.json` defines the item and provisional 3400-piastre price; `game_entry.gd` exposes purchase/place/store, and `game_scene.gd` draws it in the room with T/Y controls. Actual P5 possession and placement gate the existing canonical E2 sleep recovery. No free starter bed; buying it **alone** must not change Mood, Rest or hidden baseline. Native tests and real Web/Chromium verify no ghost furniture, no double charging, storage, insufficient funds, location restrictions, saving and next-day sleep. **This is partial E2 NEED-02/E5 HOME-02 only**: temperature, actual fan use, meal/household variety, market/supplier choices, social referrals, audio and prolonged human playtests remain unfinished. Price is a testable opening balance **proposal**, not approved economy balancing; art PR #20 remains separately gated.

**Verified at exact PR head `50157cb38a4663b7e54e66150005184b61801a88`:** [native suite](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39041517548) SUCCESS and [full Chromium/Ink](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39041517429) SUCCESS (`E2_HOME_BED_CHROMIUM_PASS`), squash merge `18cea54ac3a2929be57098580332b33b45e07a3f`. These prove a constrained player-facing roof-room comfort choice, not whole E2/E5 acceptance. [E2 #57](https://github.com/MohamedXIV/nile-kiosk/issues/57), [E5 #60](https://github.com/MohamedXIV/nile-kiosk/issues/60) and parent #55 stay OPEN.

## E3 hands-on tea input — MERGED scoped delivery (2026-10-17, PR #70)

The default game now routes an authored tea profile (H kettle heat/lift, U pour/finish) through **existing** P3 `cook.step.begin/finish` world commands. G is reserved for non-cooking service transitions, not an automatic tea-cooking shortcut. Wrong gesture, early finish and location checks are authoritative, and in-world prompts are derived from P3 preparation stage and ready minute instead of scene-local state. Native and Chromium verify actual player gestures, rejected paths, WorldKernel replay and existing service/needs coexistence. **This is only COOK-02 PARTIAL**: no food-quality score/price changes, turn/season gestures, multi-dish breadth, or social recipe knowledge yet. The profile's choice of H/U and two-stage tea gestures is an implementation trial, not approved final input/accessibility design; PR #20 remains untouched.

**PR #70 exact-head evidence:** `d7a7cd3f8098358b08c79184568c4cf50ff23a6e`, [full native success](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39043142518), [full Web/Chromium success](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39043142663) including `E3_TEA_HANDS_CHROMIUM_PASS`, squash-merged as `c3ec8fa313be351eb5cc541ca538e69437878f73`. E3 #58 stays OPEN; this does **not** satisfy deterministic quality/skill, recipe discovery or human playtesting. PR #20 is still separately user-gated.

## E3 P1 — merged event-sourced sensory result (2026-10-17; [PR #71](https://github.com/MohamedXIV/nile-kiosk/pull/71))

Built a bounded `WorldKernel.prepared_quality` / `CookingWorld.item_quality` projection for actual prepared tea using P3 step event timestamps, with no parallel recipe state, no snapshot/schema change and no player-facing XP. Late kettle lift or pour creates a worse *specific physical cup* than a careful preparation; an ordinary product quality label appears in the game and survives disk/replay/Chromium hard reload. Native counterfactual tests compare the same accepted customer order with different player timing, reject forged items and altered event records, and assert identical payouts (quality pricing is **NOT** in this batch). Initial numerical rates/labels are only PROPOSED balance trials. Still missing: richer gestures, audio/animation, variable recipes, taste/customer response, social hints and full E3 acceptance. PR #20 remains art-gated.

**PR #71 proof:** exact PR head `e5f570bb16667812bba920284c117d8dca83cb90`, [Godot native SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39045625348) and [full Chromium/Ink SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39045625356) (`E3_TEA_QUALITY_CHROMIUM_PASS`) passed; squash-merged as `4ac542cf679dea8fe59e247e704839057581d30e`. Same real P3 preparation produces `good` when timely or `rough` when overdue, without invented purchases, item minting, financial penalty or v11 schema churn. Replay-derived grade persists after genuine P4 delivery, P5 settlement and Web hard reload. Numerical scores and final controls are PROPOSED, not user-approved. #58/#55 remain OPEN.

## E3 P2 — verified brief NPC reaction (merged 2026-10-17, [merged PR #72](https://github.com/MohamedXIV/nile-kiosk/pull/72))

Follow-up to real quality: a short authored Mahmoud reaction on P4 tea **delivery** changes with good/okay/rough score, shown in the actual Godot scene near the actor. Projection reuses P3/P4 source events and P2 physical NPC presence; no canonical new state or schema migration, no trust/price effect, no AI dialogue generation. A finished cup alone triggers no reply. The spoken moment disappears after 30 world minutes or moving away, and derives identically after save/replay and Web hard reload. Real dialogues, other recipe/customer situations and human acceptance stay outside this scoped addition. Voice/text wording and visibility threshold are **PROPOSED**. Art PR #20 remains untouched.

**E3 P2 post-merge proof:** [merged PR #72](https://github.com/MohamedXIV/nile-kiosk/pull/72) / merge `40ae4fe7102e5165fcbe328ee44b04bada5b6143`, PR head `6d509fddebc8433947b5a462df17ac72420d85ad`; [Godot Native SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39046722296), [Full Web/Chromium SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39046722305), `E3_CUSTOMER_REACTION_CHROMIUM_PASS`. The brief authored rough/okay/good line is derived only after real P4 delivery to a present NPC; no extra social GameState/price/affinity. E3 #58, E4 #59, parent #55 remain OPEN. The visual art review PR #20 stays untouched.

## E4 P0 — incidental NPC-to-NPC exchange (2026-10-17)

A single bounded authored conversation *presentation trial* at the actual kiosk: Salma and Mahmoud exchange brief remarks while the world and the player's cooking keep running, only when P2 confirms both in the kiosk; P1 elapsed minutes cause one beat, then silence, then the answer, once per day. Speaker text appears by the real authored NPC anchor, subject to hearing distance, and does not use the order/customer-reaction cue when a delivered-cup line is active. No new simulation, unlock, story truth, reputation, schema or prices. Native should check presence, read-only projection, 2 beats, silence and precedence; Web should verify both lines while cooking. Exact dialogue and timing are PROPOSED. This does NOT complete E4 NPC visit modes, Ink participation, fact referrals or actual conversation interactions.
