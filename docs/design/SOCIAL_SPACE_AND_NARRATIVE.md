# The kiosk as a social place — visitors, listening, silence and connected knowledge

**Gap IDs:** SOC-01 verified foundation; SOC-02/03/04/05 partly or wholly missing. **Implementation tracker:** [E4 #59](https://github.com/MohamedXIV/nile-kiosk/issues/59).

## People first, customers second

The kiosk faces the Nile and includes a **small counter (roughly 2–3 stools, provisional), a few tables, standing space, and the railing**. Visitors are not a conveyor belt of front-facing VN portraits. Authored *visit modes* include takeaway, counter, table, railing and standing/waiting. A person can change mode during one visit (`arrive → order → receive → linger/talk/observe → leave`), buy nothing, or appear and leave unnoticed. Most human traffic can be brief takeaway, with less dialogue than their numbers imply.

Some NPCs appear once; some become regulars without a "Friendship level" popup; others fade out of view. Many encounters reveal no fact, quest, discount, achievement or benefit. A silence, "آه والله", a shared observation about football, or a customer drinking quietly **is content**. Regularity should be remembered naturally, not turned into grind bars or scripted gifts every visit.

## Spatial, nonblocking conversation

Characters can speak to **one another**, independently of the player, as work continues. Spatial subtitles/speech should follow the speaking character without freezing camera or cooking. Proximity, actual hearing time, orientation/occlusion where appropriate and participation gate what the player can know. Nearby dialogue is readable; distant remarks may be partial or absent.

At a **natural beat boundary**, nearby interested players may join a conversation if topic, familiarity, privacy and knowledge allow. Choices are short; local response branches **reconverge** rapidly. Moving toward a group can signal interest; ignoring choices or continuing cooking lets NPCs continue. Some topics are closed to outsiders. Do not build unrestricted 3-person free-form AI conversation, and do not assume the player is the subject of every exchange.

## Social knowledge has real consequences — sometimes

Conceptual network: `NPC → facts → relationships → locations → opportunities`. A fact about someone's job, a trusted furniture vendor, a repair contact, or a cooking technique can eventually enable a **real** referral, limited stock, better terms or another dialogue response. Most facts are not inventory or quest items, and most chit-chat yields no gameplay unlock. Relationships are largely hidden; player-facing "Trust 67%" widgets are not the target.

Existing [P2](../systems/SYS_P2_NPC_LIFE_SOCIAL.md) already verifies actor presence, overheard facts and directional trusted audiences. [P6](../systems/SYS_P6_INK_NARRATIVE_BRIDGE.md) verifies independent Ink session state and guarded choices. [C5](../systems/PLAY_C5_SOCIAL_CUSTOMER_DEMAND.md) verifies NPC-to-NPC social signals for demand; [C6](../systems/PLAY_C6_REPEAT_CUSTOMER_EXPERIENCE.md) verifies **recent settlement/abandonment affects that customer's future demand**, not an explicit memory of tea sugar preference. The choreography, final dialogue, personalized memories and referral economics **remain implementation work**.

## AI boundary (agreed, no production feature claimed)

The complete game must work with **authored offline dialogue**. Optional `Expanded Dialogue Variety (AI)` can someday be **Off by default** and use BYOK, restricted to bounded noncanonical line flavour. It may not introduce facts, unlock a recipe, alter relationships, set prices or change save truth. Authored original is always fallback. This is not a dependency of E4; provider/model choice is open.

## Acceptance contract (pending)

Two NPCs converse while player cooks/ignores; moving close at an authored boundary provides an allowed interjection with quick return; staying far or encountering private talk does not leak knowledge; silence is a valid non-quest outcome; a repeat visitor visibly recognizes a prior real event; a verified social fact leads to an actual deterministic, authored opportunity. Save/load a pending choice without duplicate grants. Arabic/RTL final localization is beyond English-only D001 fixtures and must be separately reviewed.

## E4 P0 — incidental two-neighbor exchange (proposed production trial, 2026-10-17)

Small **player-visible** addition: `content/social/nile_kiosk_exchange.v1.json` authors a short exchange between Salma and Mahmoud over two **canonical P1 world-time beats** with quiet gaps; it is only displayed when **both are physically present via P2**, and the player can hear the active speaker at their authored kiosk anchor. No player's F-button or scripted teleport is necessary. The player keeps walking, preparing food or ignoring them. A real P4 delivered-cup reaction takes visual precedence. The game never creates extra social facts, Ink choices, relationship counters, quest rewards or a scene-owned world clock. The chosen lines, 10-minute beat, 3-minute visibility and 110-world-unit hearing distance are **PROPOSED** first experience defaults, not approved authored script/cadence. No promise of a fully authored Ink conversation, interjection, private talk or believable visitor roaming; all remain OPEN in E4.
