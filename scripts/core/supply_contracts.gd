extends RefCounted
## Bounded P5 supply contracts. This stateless helper validates cross-domain
## terms; EconomyWorld owns catalog/receipts, P1 time, P3 ingredients, P2 knowledge.
const LIMIT = 2147483647

static func owns(kind: String) -> bool:
    return kind in ["supply.offer.register","supply.purchase","supply.decline"]

static func event_kind(kind: String) -> String:
    return {"supply.offer.register":"supply.offer_registered","supply.purchase":"supply.purchased","supply.decline":"supply.declined"}.get(kind,"")

static func command_kind(kind: String) -> String:
    return {"supply.offer_registered":"supply.offer.register","supply.purchased":"supply.purchase","supply.declined":"supply.decline"}.get(kind,"")

static func fail(code: String) -> Dictionary: return {"ok":false,"code":code}

static func plan(kind: String, p: Dictionary, actor: String, world: RefCounted) -> Dictionary:
    var economy: RefCounted = world.economy
    if kind == "supply.offer.register":
        if actor != "system:catalog": return fail("UNAUTHORIZED")
        if not economy.exact(p,["offer_id","supplier_id","required_fact","ingredient_id","quantity","goods_minor","delivery_minor","minutes","location_id","valid_minutes"]):
            return fail("INVALID_PAYLOAD")
        for field in ["offer_id","supplier_id","required_fact","ingredient_id","location_id"]:
            if not economy.identity(p[field]): return fail("INVALID_OFFER")
        for field in ["quantity","goods_minor","minutes","valid_minutes"]:
            if not economy.minor(p[field],1): return fail("INVALID_OFFER")
        if not economy.minor(p["delivery_minor"]) or int(p["goods_minor"]) > LIMIT-int(p["delivery_minor"]) or int(p["minutes"]) > 1440 or int(p["valid_minutes"]) > 1440:
            return fail("INVALID_OFFER")
        if not world.cooking.ingredients.has(p["ingredient_id"]) or not world.society.social_facts.has(p["required_fact"]):
            return fail("UNKNOWN_OFFER_DEPENDENCY")
        if economy.supply_offers.has(p["offer_id"]): return fail("OFFER_EXISTS")
        if economy.supply_offers.size() >= 64: return fail("OFFER_LIMIT")
        return {"ok":true,"effect":{"offer_id":p["offer_id"]}}
    if actor != "player": return fail("UNAUTHORIZED")
    if not economy.exact(p,["offer_id"]) or not economy.identity(p.get("offer_id")): return fail("INVALID_PAYLOAD")
    if not economy.supply_offers.has(p["offer_id"]): return fail("UNKNOWN_OFFER")
    var offer: Dictionary = economy.supply_offers[p["offer_id"]]
    if economy.supply_resolutions.has(p["offer_id"]): return fail("OFFER_RESOLVED")
    var known: Dictionary = world.society.knowledge.get("player",{}).get(offer["required_fact"],{})
    if known.is_empty(): return fail("FACT_NOT_KNOWN")
    if world.society.player_location != offer["location_id"]: return fail("WRONG_LOCATION")
    if world.world_minute-int(known["heard_minute"]) >= int(offer["valid_minutes"]): return fail("OFFER_EXPIRED")
    var effect: Dictionary = {"offer_id":p["offer_id"],"knowledge_event_id":known["event_id"],
        "supplier_id":offer["supplier_id"],"status":"declined" if kind == "supply.decline" else "purchased"}
    if kind == "supply.decline": return {"ok":true,"effect":effect}
    if world.paused: return fail("PAUSED")
    if int(offer["minutes"]) > LIMIT-world.world_minute: return fail("TIME_OVERFLOW")
    var transfer: Dictionary = economy.plan_transfer({"transaction_id":"supply:"+str(p["offer_id"]),
        "from_account":"player","to_account":"world:vendors",
        "amount_minor":int(offer["goods_minor"])+int(offer["delivery_minor"]),"cause_id":p["offer_id"]})
    if not transfer.get("ok",false): return transfer
    var stock_request: Dictionary = {"ingredient_id":offer["ingredient_id"],"quantity":int(offer["quantity"])}
    var stock: Dictionary = world.cooking.plan("stock.add",stock_request,"system:stock",world.jobs,world.world_minute)
    if not stock.get("ok",false): return stock
    effect["transfer"] = transfer["effect"]
    effect["stock_request"] = stock_request
    effect["stock_effect"] = stock["effect"]
    effect["to_minute"] = world.world_minute+int(offer["minutes"])
    return {"ok":true,"effect":effect}

static func apply(economy: RefCounted, kind: String, p: Dictionary, effect: Dictionary, event_id: String, minute: int) -> void:
    if kind == "supply.offer.register":
        economy.supply_offers[p["offer_id"]] = p.duplicate(true)
        return
    var resolution: Dictionary = {"status":effect["status"],"event_id":event_id,
        "world_minute":minute,"knowledge_event_id":effect["knowledge_event_id"],"supplier_id":effect["supplier_id"]}
    if kind == "supply.purchase":
        economy.apply_transfer(effect["transfer"],event_id,minute,kind)
        resolution["transaction_id"] = effect["transfer"]["transaction_id"]
        resolution["completed_minute"] = effect["to_minute"]
        resolution["ingredient_id"] = effect["stock_request"]["ingredient_id"]
        resolution["quantity"] = effect["stock_request"]["quantity"]
    economy.supply_resolutions[p["offer_id"]] = resolution
