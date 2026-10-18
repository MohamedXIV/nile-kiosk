# E5 bounded procurement alternatives

**Issue #60 / ECON-02 PARTIAL.** Stacked branch `feat/procurement-alternatives`, based on `feat/living-conversations`. No merge or hosted CI success is implied.

## Playable choice — all new balance PROPOSED

| Route | Access | Goods | Money | P1 time | Availability |
| --- | --- | --- | --- | --- | --- |
| Hoda delivery, F3 buy / F4 decline | Actually hear Mahmoud's existing returning-customer Ink answer | 30g leaves | 450 + 100 fee | 15 minutes | Existing 120 minutes after first hearing; one delivery |
| Market collection, F5 collect / F6 decline | Public; no learned contact | Same 30g leaves | 450; no delivery fee | 40 minutes away | 17:00–19:00 each day, enough time to finish before closing; one finite30g lot, no restock in this slice |

Both are invoked from the actual kiosk counter. Collection is explicitly a **bounded elapsed trip**, not an invented walkable market. There is no market room in the existing graph. The command starts and ends at the kiosk, processes the whole P1 interval atomically, and adds goods on return; there are no intermediate saved positions or retroactive speech/knowledge grants. The kiosk remains open if the player left it open: NPC arrivals/departures, scheduled orders, cooking firings and E2 needs continue. No supply action pauses the clock or automatically completes a player's physical cooking gestures.

The referral has a measurable purpose: paying100minor saves25minutes, and delivery can remain available after collection closes. In the real scheduled afternoon, leaving at17:50 gets the delivery back at18:05 while Mona is still independently visiting; collection returns18:30 after she has left. Declining and ignoring remain valid, with no money/time/stock reward. This is not a transport system, market economy, replenishing supplier simulation or approved final balance.

## Canonical contract

P5's existing `supply.offer.register` optionally carries exact `availability: {opens_minute, closes_minute, lot_id, stock_quantity}`. Bounds, positive window, integral stock and existing P3 ingredient are validated. Empty `required_fact` is accepted only for an explicit authored availability contract; existing fact-gated offers keep their original semantics and event shape. Public receipts store an empty knowledge-event ID, not fabricated social knowledge.

Vendor stock is a pure projection of immutable authored lot size minus **purchased** quantities in existing P5 resolutions sharing the lot. Alternate listings cannot oversell; conflicting lot stock/ingredient registration rejects. Declines do not consume goods. No second mutable vendor stock store or save version is added. The public channel's daily P1 window controls its validity; the legacy `valid_minutes` field retains its fact-relative meaning for learned offers.

Before committing, purchase validates known fact if required, location, resolution, fact expiry, daily availability, completion before closing, finite supply, pause, funds and P3 bounds. The existing event composes the audited zero-sum P5 transfer, every P1 firing/E2 needs consequence and the P3 stock addition at completion. Same command-ID retries are P0 idempotent; new attempts after resolution reject. Whole-world event replay reconstructs both stock use and the receipt. Raw economic refunds remain forbidden for domain purchases.

## Evidence

- `test_e5_procurement.gd`: actual default Game travel and public collection; genuine P6-earned contact; equivalent-state route comparison; real Mona schedule difference; funds, before-open/closed/too-late/empty/short/shared-lot/decline/pause/duplicate/extra-field rejection; stock/ledger/needs and P1 firing+ACK; disk/replay and tampered goods.
- `web-procurement-smoke.mjs`: default production controls only, public purchase without contact, decline and expiry, actual earlier tea/returning Ink/contact followed by either route, real independent visit consequences, duplicate and hard reload. No injected browser world or test-only command.
- Added to existing full native and Chromium/Ink workflows; no duplicate heavy jobs. Read actual execution reports for exact feature SHAs/results; local tests are distinct from hosted CI.

## Remaining

#55/#59/#60/#61 remain OPEN/PARTIAL. Restocking, richer suppliers, substitutions/delays, transport/market geometry, future home comfort, contextual audio/RTL and final UX/art remain separate scope. #20 remains human-gated and untouched. English controls and all prices, opening hours, quantities and travel durations here are provisional implementation values, explicitly **PROPOSED**.
