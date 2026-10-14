# Everyday economy, social markets and making a small home

**Gap IDs:** ECON-01/HOME-01 verified foundation; ECON-02/HOME-02 missing user experience. **Implementation tracker:** [E5 #60](https://github.com/MohamedXIV/nile-kiosk/issues/60).

## Money buys stability, comfort, time and choice

The goal is not a restaurant chain or one-million-EGP score. Money pays living and operating costs, and gradually removes the pressure to squeeze every workday. Some purchases are economically inefficient but humanly valuable: a radio after work, a comfortable chair, a second-hand TV, a fan on a hot night. The player should be able to choose a shorter day when they have a financial cushion.

Possible categories: home/kiosk rents and utilities, ingredients and disposable supplies, logistics/transport, repairs, home food/furniture, optional entertainment, and kitchen equipment. These are **design categories**, not a locked price list or automatic resource tax. Keep ordinary hard times humane: two quiet days should not necessarily mean game over; credible supplier grace or relationship-driven solutions can exist without inventing infinite free credit.

### Suppliers, transport and real alternatives

A supplier delivery can save the player time for a fee but sometimes be late, out of stock or substitute goods. Going to a market may cost time and transport but allow price/product choice. The **bus schedule and tricycle** are examples of potentially strong trade-offs (last service, fuel, maintenance, carrying stock), **PROPOSED** until specifically chosen as production scope. Buying a vehicle must not merely add `efficiency +20%`, and supplier delivery must remain a useful alternative. Better equipment can buy *less repetitive labor*, not only more revenue.

A socially learned referral should have concrete implications: used goods, a particular seller, a time-limited offer, cheaper repair, credit/payment terms, special ingredients. Offer/discount terms and prices must be **authored, bounded and audited**, not LLM-created or inferred solely from a hidden numeric familiarity bar. Period-compatible early-2000s electronics are examples, not a mandated technology unlock tree.

## Home progression is not property tycoon progression

The player starts in a **4×6m 24m² rooftop room**; a modest ~60m² separate south flat below may become possible. The room and building should remain emotionally real. The upgrade is privacy, proper kitchen/bathroom and daily comfort, not a penthouse. A fan, curtains, bed, kettle, radio and TV are meaningful **because of use and circumstances**, not permanent purchase-point bonuses. The exact items, costs, leases, second-home policy and duplex are separate provisional choices. See [building spatial spec](../architecture/HOME_BUILDING_SPATIAL_SPEC.md).

**Already verified:** [P5](../systems/SYS_P5_ECONOMY_HOUSING_HOME.md) provides an auditable ledger, rental entitlement/arrears and persisted furniture ownership/placement/use. Its own doc explicitly states furniture use has **no production comfort/rest/mood effects yet**. [C3](../systems/PLAY_C3_KIOSK_SERVICE_INTERACTION.md) proves actual paid service. Do not create a duplicate currency or owner state to add convenience, markets or home comfort.

## Acceptance contract (pending)

Playable vendor-supply decision with ledger/time/stock consequences; one authored information-driven purchase/referral offer; a home item that changes actual conditions or routine upon use; visible before/after feel; save/replay of all costs, deadlines, belongings and effects. The existing housing arrears policy and economic non-scaling principle remain protected. Tests must distinguish actual player benefit from pure catalog decoration.
