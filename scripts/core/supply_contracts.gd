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

static func remaining(offers: Dictionary, resolutions: Dictionary, offer: Dictionary) -> int:
    if not offer.has("availability"): return int(offer["quantity"])
    var lot: Dictionary = offer["availability"]
    var stock: int = int(lot["stock_quantity"])
    for id in resolutions:
        var receipt: Dictionary = resolutions[id]
        var terms: Dictionary = offers[id]
        if receipt["status"]=="purchased" and terms.get("availability",{}).get("lot_id","")==lot["lot_id"]:
            stock-=int(receipt["quantity"])
    return stock

static func availability(offer: Dictionary, minute: int, purchase: bool) -> String:
    if not offer.has("availability"): return ""
    var a: Dictionary = offer["availability"]
    var today: int = minute%1440
    if today<int(a["opens_minute"]): return "OFFER_NOT_OPEN"
    if today>=int(a["closes_minute"]): return "OFFER_EXPIRED"
    if purchase and int(offer["minutes"])>int(a["closes_minute"])-today: return "COLLECTION_TOO_LATE"
    return ""

static func plan(kind: String, p: Dictionary, actor: String, world: RefCounted) -> Dictionary:
    var economy: RefCounted = world.economy
    if kind == "supply.offer.register":
        if actor != "system:catalog": return fail("UNAUTHORIZED")
        var keys: Array = ["offer_id","supplier_id","required_fact","ingredient_id","quantity","goods_minor","delivery_minor","minutes","location_id","valid_minutes"]
        if p.has("availability"): keys.append("availability")
        if not economy.exact(p,keys):
            return fail("INVALID_PAYLOAD")
        for field in ["offer_id","supplier_id","ingredient_id","location_id"]:
            if not economy.identity(p[field]): return fail("INVALID_OFFER")
        if typeof(p["required_fact"])!=TYPE_STRING or (not p["required_fact"].is_empty() and not economy.identity(p["required_fact"])) or (p["required_fact"].is_empty() and not p.has("availability")):
            return fail("INVALID_OFFER")
        if p.has("availability"):
            var a: Variant = p["availability"]
            if typeof(a)!=TYPE_DICTIONARY or not economy.exact(a,["opens_minute","closes_minute","lot_id","stock_quantity"]) or not economy.identity(a.get("lot_id")):
                return fail("INVALID_AVAILABILITY")
            for field in ["opens_minute","closes_minute","stock_quantity"]:
                if not economy.minor(a[field]): return fail("INVALID_AVAILABILITY")
            if int(a["opens_minute"])>=int(a["closes_minute"]) or int(a["closes_minute"])>1440:
                return fail("INVALID_AVAILABILITY")
            for existing in economy.supply_offers.values():
                var lot: Dictionary=existing.get("availability",{})
                if lot.get("lot_id","")==a["lot_id"] and (lot["stock_quantity"]!=a["stock_quantity"] or existing["ingredient_id"]!=p["ingredient_id"]):
                    return fail("SUPPLY_LOT_CONFLICT")
        for field in ["quantity","goods_minor","minutes","valid_minutes"]:
            if not economy.minor(p[field],1): return fail("INVALID_OFFER")
        if not economy.minor(p["delivery_minor"]) or int(p["goods_minor"]) > LIMIT-int(p["delivery_minor"]) or int(p["minutes"]) > 1440 or int(p["valid_minutes"]) > 1440:
            return fail("INVALID_OFFER")
        if not world.cooking.ingredients.has(p["ingredient_id"]) or (not p["required_fact"].is_empty() and not world.society.social_facts.has(p["required_fact"])):
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
    if not offer["required_fact"].is_empty() and known.is_empty(): return fail("FACT_NOT_KNOWN")
    if world.society.player_location != offer["location_id"]: return fail("WRONG_LOCATION")
    if not known.is_empty() and world.world_minute-int(known["heard_minute"]) >= int(offer["valid_minutes"]): return fail("OFFER_EXPIRED")
    # Public collection reopens daily: refusing a future trip remains valid
    # outside opening hours. Learned offers still use the expiry check above.
    if kind=="supply.purchase":
        var unavailable: String = availability(offer,world.world_minute,true)
        if not unavailable.is_empty(): return fail(unavailable)
    var effect: Dictionary = {"offer_id":p["offer_id"],"knowledge_event_id":known.get("event_id",""),
        "supplier_id":offer["supplier_id"],"status":"declined" if kind == "supply.decline" else "purchased"}
    if kind == "supply.decline": return {"ok":true,"effect":effect}
    if remaining(economy.supply_offers,economy.supply_resolutions,offer)<int(offer["quantity"]): return fail("SUPPLY_OUT_OF_STOCK")
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
