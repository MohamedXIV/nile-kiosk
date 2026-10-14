# Atmosphere, feedback and a real entry into daily play

**Gap IDs:** ATM-01/ATM-02, related VIS-01. **Implementation tracker:** [E6 #61](https://github.com/MohamedXIV/nile-kiosk/issues/61); independent art approval [#19](https://github.com/MohamedXIV/nile-kiosk/issues/19) / [PR #20](https://github.com/MohamedXIV/nile-kiosk/pull/20).

## Atmosphere is gameplay texture, not optional polish

A small kiosk can feel alive through the water, kettle, sizzling grill, distant traffic, a radio playing from nearby, a rooftop fan, changing light, people entering and leaving, an occasional boat passing. Long intervals without orders **must not be automatically fixed by spawning customers**. A quiet moment can make the player genuinely want to stand by the river.

The experience reference is the user's **standalone Three.js HTML prototype**: it puts the player in a Nile kiosk and roof-room loop with movement, simple cooking, environmental audio, spatial speech and quick feedback, demonstrating a feeling of place. It is **not a production port, proof of final game design, or mandate to replace Godot/2D with Three.js/3D**. Its random NPC motion, fixed stats and single-file state are not authoritative.

## In-world UI and feedback

Gameplay is spatial. Short text belongs near actual NPC speakers, not a global chatbot window or full-screen VN replacement. Interaction hints should appear near relevant objects/visitors. The player should be able to move/cook while someone else is talking; an optional answer should never confiscate control without reason. Let animation, sound, posture, timing and lighting carry the feeling of cooking success, tiredness or comfort before a numerical UI does. No spammy XP/trophy/relationship toasts for an ordinary cup of tea.

Use a restrained readable period-authentic presentation; Arabic/RTL and localization require their own eventual signoff, since D001 used English test fixtures. Sound settings/off mode must not block gameplay; visual interaction cues remain clear without audio. Detailed mixing, soundtrack rights, fonts and scene density are **OPEN** production choices.

## Architecture and visual gate

- `project.godot` currently boots the D001 dialogue `kiosk_spike.tscn`; `qa_traversal_scene.gd` is honest debug visualization (circles/labels/QA control keys), **not a shippable game UI**. E6 must connect a real production-owned world entry with E1/E3/E4 gameplay, without promoting test fixtures to permanent content.
- Keep the art direction in [Visual World Bible](VISUAL_WORLD_BIBLE.md): fixed oblique angled 2D cutaways, 3D-authored spatial accuracy, **2D-delivered** distinct assets, warm light, real room proportions. Existing [V001 PR #20](https://github.com/MohamedXIV/nile-kiosk/pull/20) is technically proven but **visually unapproved**. Never auto-merge on a green screenshot test.
- The game can prove mechanics with placeholder presentation first, but must not label that a complete atmospheric experience.

## Acceptance contract (pending)

A real initial scene (not QA/D001 default) allows recognizable kiosk↔home play using canonical commands; contextual sound changes with place/activity/time; spatial speech stays positioned and usable while moving/working; controls retain focus and access; save/reload consistent. Separate browser engineering proof from user visual/audio acceptance, and keep PR #20 independent.
