# Tactile cooking, serving and learning recipes from people

**Gap IDs:** COOK-01 (verified foundation), COOK-02/COOK-03 (missing). **Implementation tracker:** [E3 #58](https://github.com/MohamedXIV/nile-kiosk/issues/58).

## Cooking is a craft, not an abstract menu or a frantic combo race

For an appropriate dish, expect roughly **3–6 meaningful player actions**: add/heat, flip/stir, season, pour, assemble, serve. An Eskandarani liver sandwich or glass of tea should have satisfying timing and feedback without demanding every knife cut, cup wash or inventory drawer click. Routine prep can be bundled; skilled timing and rhythm matter, not dozens of button presses.

Quality should follow **player-performed actions, timing and context** (poor/okay/good/excellent are possible labels), not hidden random outcomes. The sequence is `order → prepare → cook → talk → plate → serve`; conversations may continue while hands are busy, and an NPC may not be rushing. Home-only personal food is valid; not every discovery exists to raise kiosk revenue.

### Separate existing production truth from missing experience

- **Verified narrow foundation:** [SYS P3](../systems/SYS_P3_COOKING_INVENTORY.md) stores units, ingredients, reservations, jobs, stations and items; [PLAY C3](../systems/PLAY_C3_KIOSK_SERVICE_INTERACTION.md) moves those steps through canonical commands and settlement, with QA G/T keys.
- **Still missing:** tactile input and responsive animation/feedback; recipe yield quality/taste; context-sensitive use of cooked food and conversation during real player actions. QA one-command progression is not this design.
- No duplicate kitchen state machine that can create unsanctioned sale items. If adding quality to production items changes state/schema, design the migration and replay contract first.

## Recipe knowledge is progressive, not a level unlock

Illustrative progression: `heard_of → rough_idea → attempted → understood → mastered`. The precise enum and thresholds are **PROPOSED**, but the principle is **AGREED**: knowledge comes through conversations, listening, trying, failing, tasting and revisiting a person, rather than `Reach level 6 to unlock recipe`.

Example: a visitor mentions chickpea falafel; much later the player asks about soaking, tries an imperfect batch, and discusses the result on their next encounter. An NPC need not give a recipe, may only recall a family dish, and may disagree honestly on seasoning. Facts, performed attempts and recipe consequences are canonical GameState; Ink/AI present authored conversations but never decide the truth. A dish may exist only for home cooking.

## Acceptance contract (pending)

One complete authored food item with meaningful distinct manual actions and reproducible quality differences; a player can serve and be paid through P3/P4/P5, and cook for themselves with correct needs where implemented. A separate witnessed hint alters an attempt or available meaningful action, and later dialogue reflects the actual attempt. Check interruptions, bad timings, ingredient depletion, stale orders and save/reload mid-process. Do **not** mark E3 complete simply because the P3 recipe lifecycle already passes.
