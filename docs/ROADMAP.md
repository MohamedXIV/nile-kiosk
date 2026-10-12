# Roadmap — discovery-first

This roadmap records **work to prove**, not features already shipped. The game is early pre-production.

| Order | Workstream | Delivery gate |
| --- | --- | --- |
| 0 | Foundation documentation | Core fantasy, era, visual assumptions and open choices recorded |
| 1 | D001 Dialogue system spike | Head-to-head Dialogue Manager vs Ink: concurrent sessions, authored interjection, save, independent GameState, browser |
| 2 | V001 Building cutaway spike | Street → building → correct apartment floor cutaway → movable furniture → persistence |
| 3 | Technical decision | Lock runtime/visual/narrative combination based on D001/V001 evidence |
| 4 | Kiosk vertical slice | One cooking recipe, one meaningful day, NPC arrivals/table/counter/Nile behavior, return home |
| 5 | Game-state and narrative foundations | Knowledge, relationships, housing expenses, conversations without player, repeat encounters |
| 6 | Content and systems expansion | Recipes, neighborhood stories, ordinary purchases, ambience and home comfort |
| 7 | Polish, balance and release | Usability, accessibility/localization later, save stability, distribution |

## Working rules

- Keep game vision broader than the spike code. Avoid building an entire platform before validating the experience.
- NPCs must be able to converse without the player; authored dialogue opportunities are not all quests.
- Use independent short modules, coherent assets and reproducible tests.
- CI is welcome on this **public** repository. Prefer one useful smoke job after runnable tests exist, cache imports, cancel superseded runs; don't run empty workflows.
- Arabic text and RTL testing **deferred** from D001 at user's request, not marked completed.
