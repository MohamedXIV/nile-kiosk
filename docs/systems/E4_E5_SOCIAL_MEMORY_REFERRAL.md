# E4 returning-customer memory and E5 tea-supplier contract

**Scope:** production default game, English provisional authored content. E4/E5/E6 and parent #55 remain **PARTIAL/OPEN**. This branch does not implement optional interjection, broad NPC motivation, a marketplace, pickup/delivery comparison, localization or final visual approval. Art PR #20 is untouched.

## Play the loop

1. Open the kiosk and actually serve Mahmoud, including delivery, quote and settlement. Alternatively let his genuine request expire. Cooking timing determines the real cup quality.
2. On his later scheduled visit, approach his current physical pose. **F2** starts/resumes a separate optional catch-up. His first authored Ink line recognizes the previous paid cup (good/okay/rough or unspecified quality) or the missed order. First-time, cancelled and unpaid-only encounters do not produce paid memories.
3. Choose to ask about fresh leaves, then **hear the answer**. Merely selecting the question does not grant the supplier contact. Leaving the conversation is valid. The P2 fact is public everyday information; existing directed/trusted P2 rules remain mandatory for private information.
4. At the counter, **F3** requests Hoda's one-time delivery; **F4** declines. Ignoring the offer lets it expire. The visible provisional terms are **30g leaves; 450 goods + 100 delivery minor units; 15 world minutes; available for 120 minutes after first learning the contact**. No ordinary line grants stock, money or trust.
5. **P** saves, including unfinished choices. After a hard reload, F2 resumes the P6 cursor. Purchased/declined contracts stay resolved.

## Canonical interfaces

`WorldKernel.customer_memory(npc_id, venue_id)` is a pure P4/C6/P3 projection. It requires a genuine active later order, selects the latest earlier settled/abandoned order from the same customer and venue, and derives quality from the actual delivered P3 item's verified event log. It returns both order IDs, outcome, quality/branch, closure minute and closure provenance. It stores no sentiment/reputation state.

A P6 story may include strict `customer_memory: {npc_id, venue_id}` metadata. Session start verifies real return history and player/customer participation; it freezes the derived evidence in the existing event-sourced session. Another session cannot reuse that return order. A beat's optional `requires_memory` must match that frozen branch, preventing invented positive/negative memories. The inkgd adapter sets only the derived `last_service` text variable. Ink cannot set world history or inventory. The production adapter checks same-room and Godot route-derived proximity before starting, advancing and choosing; P2 validates fact ownership, speaker/audience and trusted privacy.

P5 owns `economy.supply_offers` and `economy.supply_resolutions`; `SupplyContracts` is a stateless cross-domain validation helper. Commands:

- `supply.offer.register` (`system:catalog`): exact authored terms, positive bounded quantity/goods/time, nonnegative delivery charge, valid P3 ingredient/P2 fact and bounded catalog. Duplicate IDs reject.
- `supply.purchase` (`player`): exact `{offer_id}`. Price/quantity/time cannot be supplied by the client. Requires genuinely known fact, correct location, unexpired/unresolved offer, funds, stock bounds, running clock and safe target time. Plans the P5 zero-sum transfer, P1 scheduler projection and P3 stock effect before any commit.
- `supply.decline` (`player`): exact `{offer_id}` with actual known, located, unexpired offer; records a one-shot refusal and no economic/time/stock effect.

A purchase is one authenticated `supply.purchased` event. P5 posts one transfer to `world:vendors`; P1 applies every due firing and needs consequence over the 15 minutes; P3 adds the purchased stock at completion. The resolution records supplier, speech knowledge-event ID, purchase event, transaction, completion minute and actual goods. Consumer firing/ACK APIs include all elapsed-time events (advance, sleep, activity, supply). A delivery can genuinely consume an outstanding order's deadline. Receipts reject duplicate attempts and raw refunds that would leave free goods behind. Failure commits nothing.

The small contract does not render a runner or pretend there is a traversable market. It is a bounded kiosk delivery action analogous to existing canonical elapsed activities. Future suppliers, stock availability/substitutions, shared supplier lots, market geometry and transport require their own authored contracts.

## Persistence

Schema **12** adds the P5 supply projections. Supported schemas **7–11** are validated by replaying the original events and comparing their original shape before adopting the new empty projections. Saves that erase supply receipts while retaining new supply events cannot masquerade as an older schema. No unchecked data patching, reset or stock grants on migration. Existing supported saves acquire this authored content through idempotent production configuration.

## Executable evidence

- `tests/test_e4_customer_memory.gd`: real production order/cooking/payment, good/rough/abandoned and cancelled/unpaid controls; wrong customer/venue, genuine later visit/current Godot pose, remote hearing rejection, real Ink choice, pending disk restore, wrong-branch/provenance forgery and no repeat.
- `tests/test_e5_referral.gd`: genuine P6-earned supplier contact, private/unwitnessed/unknown facts, funds/expiry/pause/overflow, decline, canonical transfer/stock/time and firing ACK, duplicate/refund rejection, whole-world disk/replay, forged provenance and version migration.
- `tools/web-social-memory-referral-smoke.mjs`: normal controls in the default production scene for actual earlier good/rough/missed service and later visits; authored recognition, pending-choice hard reload, heard/declined contact and one-time paid/declined stock consequence across hard reload. No injected world, seeded browser save or test command.
- Existing full Native and Web/Chromium/Ink workflows run these checks alongside previous systems and E4/E6 journeys. Consult actual run conclusions; this document does not imply unexecuted or unavailable CI passed.

Broader SOC-03/SOC-04/ECON-02/ATM-02 acceptance remains incomplete. Exact numbers and dialogue need human content/balance review; no final art decision is made.
