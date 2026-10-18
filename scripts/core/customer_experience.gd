extends RefCounted
## PLAY C6 — derived, non-mutable experience of a customer's most recent
## meaningful visit. The canonical P4 order/payment record is the sole truth.

static func validate(rule: Variant) -> bool:
    if typeof(rule) != TYPE_DICTIONARY or rule.size() != 2:
        return false
    if not rule.has("settled_bonus_bp") or not rule.has("abandoned_penalty_bp"):
        return false
    for key in ["settled_bonus_bp", "abandoned_penalty_bp"]:
        var value: Variant = rule[key]
        if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
            return false
        if not is_finite(float(value)) or float(value) != float(int(value)) or value < 0 or value > 10000:
            return false
    return true

static func prior(orders: Dictionary, npc_id: String, venue_id: String, before_minute: int) -> Dictionary:
    var chosen: Dictionary = {}
    var ids: Array = orders.keys()
    ids.sort()
    for id in ids:
        var order: Dictionary = orders[id]
        if order["npc_id"] != npc_id or order["venue_id"] != venue_id:
            continue
        if int(order["closed_minute"]) < 0 or int(order["closed_minute"]) >= before_minute:
            continue
        # A delivered but not-yet-settled item is not evidence of a completed
        # customer transaction. Cancelled orders are neutral, not punishments.
        var outcome: String = ""
        if order["status"] == "delivered" and order["payment_status"] == "settled":
            outcome = "settled"
        elif order["status"] == "abandoned":
            outcome = "abandoned"
        if outcome.is_empty(): continue
        if chosen.is_empty() or int(order["closed_minute"]) > int(chosen["minute"]) or (int(order["closed_minute"]) == int(chosen["minute"]) and str(id) > str(chosen["order_id"])):
            chosen = {"order_id":str(id), "outcome":outcome, "minute":int(order["closed_minute"])}
    return chosen

static func evidence(orders: Dictionary, data: Dictionary, at_minute: int, chance: int) -> Dictionary:
    var found: Dictionary = prior(orders,str(data["npc_id"]),str(data["venue_id"]),at_minute)
    var delta: int = 0
    if found.get("outcome","") == "settled":
        delta = int(data["experience_rule"]["settled_bonus_bp"])
    elif found.get("outcome","") == "abandoned":
        delta = -int(data["experience_rule"]["abandoned_penalty_bp"])
    return {
        "last_order_id":found.get("order_id",""),
        "last_outcome":found.get("outcome","none"),
        "adjustment_bp":delta,
        "chance_bp":clampi(chance + delta, 0, 10000)
    }

# A later, actual P4 request is evidence of a returning encounter. This is a
# projection, not mutable sentiment or knowledge granted to unrelated actors.
static func returning(orders: Dictionary, cooking: RefCounted, events: Array, npc_id: String, venue_id: String) -> Dictionary:
    var current: Dictionary = {}
    for order in orders.values():
        if order["npc_id"] != npc_id or order["venue_id"] != venue_id or order["status"] not in ["offered","accepted"]:
            continue
        if current.is_empty() or int(order["offer_sequence"]) > int(current["offer_sequence"]): current = order
    if current.is_empty(): return {}
    var previous: Dictionary = prior(orders,npc_id,venue_id,int(current["created_minute"]))
    if previous.is_empty(): return {}
    var order: Dictionary = orders[previous["order_id"]]
    var quality: Dictionary = cooking.item_quality(str(order["item_id"]),events) if previous["outcome"] == "settled" else {}
    var branch: String = str(quality.get("grade","settled")) if previous["outcome"] == "settled" else "abandoned"
    return {"npc_id":npc_id,"venue_id":venue_id,"order_id":previous["order_id"],
        "return_order_id":current["order_id"],"minute":previous["minute"],
        "closure_event_id":order["closure_event_id"],"outcome":previous["outcome"],
        "quality":quality.get("grade",""),"branch":branch}
