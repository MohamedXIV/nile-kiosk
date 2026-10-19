extends RefCounted
## Read-only, non-authoritative player orientation. Progress is derived from
## P1 time, P3 inventory/hand work, P4 order and P5 settlement every frame.
## Never writes world state, persists flags or grants quest rewards.

static func _hint(phase: String, message: String) -> Dictionary:
    return {"phase":phase,"text":message}

static func describe(state: Dictionary) -> Dictionary:
    var location: String = str(state.get("location",""))
    var sandwich: Dictionary = state.get("sandwich",{})
    var recipe: String = str(state.get("order_recipe",""))
    var status: String = str(state.get("order_status","none"))
    var minute: int = int(state.get("minute",0))
    var created: int = int(state.get("order_created_minute",-1))
    # Old *settled* orders remain in P4 history. Don't turn them into a
    # permanent tutorial-completed flag or tell day-two players to go home.
    var sale_today: bool = created >= 0 and created/1440 == minute/1440
    if status == "offered":
        if location != "kiosk":
            return _hint("return_to_customer","A customer is waiting. Return to the kiosk.")
        if recipe == "liver_sandwich":
            return _hint("accept_order","Salma requested liver. Accept the order with G / Serve.")
        return _hint("accept_order","Customer request waiting. Use G / Serve to accept.")
    if status == "accepted":
        if location != "kiosk":
            return _hint("return_to_customer","Your accepted customer order needs you at the kiosk.")
        if recipe == "liver_sandwich":
            if str(sandwich.get("item_status","")) == "ready":
                return _hint("deliver_order","A sandwich is ready. Use G / Serve to hand it over.")
            if not str(sandwich.get("stage","")).is_empty():
                return _hint("prepare_liver",str(sandwich.get("heat_caption","Continue the pan at F7.")))
            if not sandwich.get("can_start",false):
                return _hint("stock_counter","Buy the missing ingredients at the F7 counter.")
            return _hint("prepare_liver","Use F7 to season, turn and assemble the liver sandwich.")
        if not str(state.get("tea_stage","")).is_empty():
            return _hint("prepare_tea","Finish the real tea steps: %s." % str(state.get("tea_action","H / U")))
        return _hint("prepare_tea","Prepare the ordered tea at the counter (H / U).")
    if status == "delivered" and state.get("order_payment","") != "settled":
        if location != "kiosk":
            return _hint("collect_payment","Return to the kiosk to collect the outstanding payment.")
        return _hint("collect_payment","Food delivered. Use G / Serve to quote and settle payment.")
    if status == "delivered" and sale_today and state.get("order_payment","") == "settled":
        if state.get("kiosk_open",false):
            return _hint("close_after_sale","Sale settled. Close the kiosk when you're done (C).")
        if location != "roof":
            return _hint("go_home","Shop closed. Walk back home through the doorways.")
        return _hint("sleep_after_sale","Back at home. Sleep with Z when you're ready for day two.")
    if location != "kiosk":
        if location == "roof":
            return _hint("head_to_shop","Start your evening: use the roof door (E) to reach the kiosk.")
        return _hint("head_to_shop","Follow the next doorway (E) toward the kiosk.")
    if not state.get("kiosk_open",false):
        return _hint("open_kiosk","Open your kiosk (O / Open shop) to welcome visitors.")
    var offers: Array = sandwich.get("offers",[])
    var bought: int = 0
    for offer in offers:
        if bool(offer.get("resolved",false)): bought += 1
    if not sandwich.get("can_start",false) and bought < offers.size():
        return _hint("stock_counter","Buy ingredients at F7 (%d/%d market lots bought today)." % [bought,offers.size()])
    if not sandwich.get("can_start",false):
        return _hint("wait_for_customer","Stock is low. Watch for customer requests or restock tomorrow.")
    return _hint("wait_for_customer","Counter ready. Wait for a customer or prepare a sandwich at F7.")
