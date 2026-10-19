extends RefCounted
## Game-First service glue: authored P4 demand, P5 price and read-only P3
## quality reactions. The WorldKernel still owns orders, time and money.
const Demand = preload("res://scripts/integration/customer_demand_config.gd")
const PLAN = "res://content/service/nile_sandwich_demand.v1.json"
const REACTIONS = "res://content/service/nile_sandwich_reactions.v1.json"
const RECIPE = "liver_sandwich"

static func configure(session: RefCounted) -> Dictionary:
    var demand: Dictionary = Demand.load_plan(PLAN)
    if not demand.get("ok",false): return demand
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(REACTIONS))
    if typeof(raw) != TYPE_DICTIONARY or raw.size() != 5 or raw.get("schema") != 1 or \
            raw.get("recipe_id") != RECIPE or raw.get("terms_status") != "PROPOSED" or \
            not raw.has("price_minor") or typeof(raw["price_minor"]) != TYPE_FLOAT and typeof(raw["price_minor"]) != TYPE_INT or \
            int(raw["price_minor"]) != float(raw["price_minor"]) or int(raw["price_minor"]) <= 0 or \
            int(raw["price_minor"]) > 2147483647 or typeof(raw.get("npcs")) != TYPE_DICTIONARY:
        return {"ok":false,"code":"INVALID_SANDWICH_SERVICE"}
    if raw["npcs"].size() != 1 or not raw["npcs"].has("salma"):
        return {"ok":false,"code":"INVALID_SANDWICH_REACTIONS"}
    var lines: Variant = raw["npcs"]["salma"]
    if typeof(lines) != TYPE_DICTIONARY or lines.size() != 3:
        return {"ok":false,"code":"INVALID_SANDWICH_REACTIONS"}
    for grade in ["good","okay","rough"]:
        if typeof(lines.get(grade)) != TYPE_STRING or str(lines[grade]).strip_edges().is_empty() or str(lines[grade]).length() > 80:
            return {"ok":false,"code":"INVALID_SANDWICH_REACTIONS"}
    var prices: Dictionary = session.world.economy_view()["prices"]
    if not prices.has(RECIPE):
        var price: Dictionary = session.command("game:sandwich:price:v1","system:pricing",
            "economy.recipe.price.set",{"recipe_id":RECIPE,"amount_minor":int(raw["price_minor"])})
        if not price.get("ok",false): return price
    elif int(prices[RECIPE]) != int(raw["price_minor"]):
        return {"ok":false,"code":"SANDWICH_PRICE_CONFLICT"}
    var plan: Dictionary = demand["plan"]
    var job_id: String = "service:demand:offer:"+str(plan["plan_id"])
    if not session.world.view()["jobs"].has(job_id):
        # Existing saves from before this content pack should get the next
        # real occurrence; never retroactively create NPC orders in the past.
        var now: int = int(session.world.view()["world_minute"])
        var first: int = int(plan["first_minute"])
        var interval: int = int(plan["interval_minutes"])
        if now >= first:
            first += (floori(float(now-first)/float(interval))+1)*interval
        if first > 2147483647-int(plan["wait_minutes"]):
            return {"ok":false,"code":"SANDWICH_SCHEDULE_OVERFLOW"}
        plan["first_minute"] = first
        var assigned: Dictionary = session.command("game:sandwich:demand:v1",
            "system:director","service.demand.configure",plan)
        if not assigned.get("ok",false): return assigned
    return {"ok":true,"code":"SANDWICH_SERVICE_READY","reactions":lines.duplicate(true)}

static func reaction(session: RefCounted, lines: Dictionary) -> Dictionary:
    var snapshot: Dictionary = session.world.view()
    var chosen: Dictionary = {}
    for order in snapshot["service"]["orders"].values():
        if order["status"] != "delivered" or order["recipe_id"] != RECIPE or \
                order["npc_id"] != "salma":
            continue
        if chosen.is_empty() or int(order["closed_minute"]) > int(chosen["closed_minute"]):
            chosen = order
    if chosen.is_empty() or session.world.npc("salma").get("location_id","") != "kiosk":
        return {}
    var elapsed: int = int(snapshot["world_minute"])-int(chosen["closed_minute"])
    if elapsed < 0 or elapsed > 30: return {}
    var quality: Dictionary = session.world.prepared_quality(str(chosen["item_id"]))
    var grade: String = str(quality.get("grade",""))
    if not lines.has(grade): return {}
    return {"order_id":str(chosen["order_id"]),"npc_id":"salma",
        "item_id":str(chosen["item_id"]),"grade":grade,
        "line":str(lines[grade]),"source_event_id":str(chosen["closure_event_id"]),
        "closed_minute":int(chosen["closed_minute"])}
