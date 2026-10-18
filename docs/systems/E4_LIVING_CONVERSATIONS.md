# E4 living conversation — bounded production scope

**VERIFIED / MERGED 2026-10-18; E4 #59 and E6 #61 remain PARTIAL.** [PR #83](https://github.com/MohamedXIV/nile-kiosk/pull/83) merged `1a33a66520fb1790073eaeb368d11592823dc309`; exact tested head `c5cba014b56a8db04344f88ddd5112dee07f01ca`: [Full Native SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39129619895), [Full Web/Chromium/Ink SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39129619978).

## Play
At the open kiosk, Salma speaks at day minute 1039 and Mahmoud answers at 1049. Both must be present and mutually visible at their existing Godot AStarGrid2D route-derived poses. The player can prepare tea, move, or ignore them. During the second beat's ten-minute boundary, **T** offers nearby participation. Two genuine Ink replies ask about ordinary evening boats or simply keep listening while working. Both reconverge; no cash, inventory, relationship score or quest reward exists. At minute 1059 the NPC exchange continues even if a player choice remains unfinished, then falls silent. An answered reply changes that closing remark.

**T remains buy/place bed at home.** In this conversation movement, G/H/U cooking/service, J wait, E travel and P save remain active. Walking beyond participation range dismisses the panel; T can resume the saved answer when both neighbors are nearby again. Enter advances actual authored lines; 1/2 chooses; Esc leaves without erasing P6. Other existing N/M/I/L/F2 dialogues remain independent.

## Authority and evidence
`ConversationRules.timeline` is a pure P1 minute + P2 presence + P6 session projection. It does not tick, own NPC state or save a parallel conversation clock. The authored P6 story carries strict bounded `conversation` metadata. Joining freezes `conversation_day` in the existing canonical session. Its canonical ID binds the daily occurrence; duplicate joins cannot bypass it with another session ID. Every line/choice/finish uses the same spatial guard during planning and replay. The guard samples the **existing** RoomTraversal/Godot navigation route through a read-only state facade; it does not invent another kernel or use static NPC anchors in place of current positions.

Participation requires a public topic, same-room player, both participants present, existing mutual visual contact, and player within **70 units of both current poses**. Authored known/trusted requirements are respected at entry. Captions require **110 units to their active speaker**. These ranges, ten-minute beat/window and English prose are **PROPOSED** experience defaults. Same-room public sound can pass furniture; furniture vision occlusion is not acoustic occlusion. Private talk yields no outsider captions or participation. Room-to-room sound propagation, doors/materials, gaze and comprehensive acoustic simulation remain OPEN.

Generic **F** listening excludes facts bound to authored P6 beats/choice disclosures, including the existing learned supplier contact; it cannot skip the reviewed Ink context. Other unbound public hearing remains available.

An ordinary public P2 observation is learned only when its actual Ink answer line commits; selecting the question is not hearing. The other reply and ignoring grant no fact. Existing P2 visibility/trust/source checks remain authoritative. New metadata lives in existing P6 stories/sessions and replayed events, so schema 12 needs no additional projection or migration.

## Evidence and remaining work
`test_e4_living_conversation.gd` exercises real default Game setup/travel/time, independent beats, boundaries, private and remote canonical rejection, real compiled Ink, pending/immediate-line disk reload, remote answer rejection, legitimate knowledge, unknown/duplicate rejection, replay and forged occurrence denial. `web-living-conversation-smoke.mjs` uses only normal controls in the default production scene for both responses and ignored tea preparation, movement/dismissal and hard reload. Full native and Web workflows include it; local execution and hosted CI must be reported separately.

This is one authored daily river conversation, not arbitrary group AI, full conversational motives, comprehensive acoustic simulation, final spatial UI/art, audio or Arabic/RTL acceptance. #55/#59/#60/#61 remain OPEN/PARTIAL. PR #20 is untouched. Existing referral/procurement and later home/needs work stay on their owning backlog.


## Verified delivery
[PR #83](https://github.com/MohamedXIV/nile-kiosk/pull/83) merged `1a33a66520fb1790073eaeb368d11592823dc309`; exact tested head `c5cba014b56a8db04344f88ddd5112dee07f01ca`: [Full Native SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39129619895), [Full Web/Chromium/Ink SUCCESS](https://github.com/MohamedXIV/nile-kiosk/actions/runs/39129619978).
Native `E4 LIVING CONVERSATION: PASS`, Chromium `E4_LIVING_CONVERSATION_CHROMIUM_PASS boats/work/ignore` with existing Mona/Mahmoud/Salma/E6 tests green. No broad acoustic simulation, full social motivation, RTL or art acceptance implied.
