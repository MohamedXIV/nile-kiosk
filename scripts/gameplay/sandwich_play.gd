extends RefCounted
## Game-First adapter: read-only P3 cues and spatially gated player commands.
## Recipe/station, stock, quality and clocks remain owned by WorldKernel.
const Supply = preload("res://scripts/core/supply_contracts.gd")
const RECIPE = "liver_sandwich"
const PREFIX = "player:sandwich:"
const COUNTER = Vector2(115, 80)
const RADIUS = 48.0

static func near(session: RefCounted) -> bool:
    var point: Dictionary = session.world.spatial_view()["player"]
    return str(point["room_id"]) == "kiosk" and \
        Vector2(int(point["x"]),int(point["y"])).distance_to(COUNTER) <= RADIUS

static func offers(session: RefCounted) -> Array[Dictionary]:
    var economy: Dictionary = session.world.economy_view()
    var minute: int = int(session.world.view()["world_minute"])
    var ingredients: Dictionary = session.world.cooking_view()["ingredients"]
    var ids: Array = economy["supply_offers"].keys()
    ids.sort()
    var found: Array[Dictionary] = []
    for id in ids:
        if not str(id).begins_with("sandwich:"): continue
        var terms: Dictionary = economy["supply_offers"][id]
        found.append({"offer_id":str(id),"ingredient_id":str(terms["ingredient_id"]),
            "unit":str(ingredients[terms["ingredient_id"]]["unit"]),
            "quantity":int(terms["quantity"]),"cost":int(terms["goods_minor"])+int(terms["delivery_minor"]),
            "minutes":int(terms["minutes"]),
            "resolved":economy["supply_resolutions"].has(
                Supply.receipt_id(str(id),terms,economy["supply_resolutions"],minute))})
    return found

static func active_job(session: RefCounted) -> Dictionary:
    var jobs: Dictionary = session.world.cooking_view()["preparations"]
    var ids: Array = jobs.keys()
    ids.sort()
    for id in ids:
        var job: Dictionary = jobs[id]
        if str(id).begins_with(PREFIX) and job["recipe_id"] == RECIPE and \
                job["stage"] in ["waiting","active","interrupted"]:
            return job
    return {}

static func context(session: RefCounted) -> Dictionary:
    var cooking: Dictionary = session.world.cooking_view()
    var job: Dictionary = active_job(session)
    var required: Dictionary = cooking["recipes"][RECIPE]["total_inputs"]
    var remaining: Dictionary = {}
    var enough: bool = true
    for ingredient_id in required:
        remaining[ingredient_id] = int(cooking["stock"].get(ingredient_id,0))
        if int(remaining[ingredient_id]) < int(required[ingredient_id]):
            enough = false
    var result: Dictionary = {"near":near(session),"offers":offers(session),
        "stage":"","step_index":-1,"ready_in":0,"cue":"Enter · Begin a liver sandwich",
        "item_id":"","grade":"","score":0,"stock":remaining,"can_start":enough,
        "phase_label":"Stock the counter","heat_state":"idle","heat_minutes":0,
        "heat_caption":"Ingredients still need real market purchases" if not enough else
            "Ingredients ready · Enter to season"}
    if not job.is_empty():
        var index: int = int(job["step_index"])
        var step: Dictionary = cooking["recipes"][RECIPE]["steps"][index]
        var stage: String = str(job["stage"])
        result["stage"] = stage
        result["step_index"] = index
        result["job_id"] = str(job["job_id"])
        var minute: int = int(session.world.view()["world_minute"])
        result["ready_in"] = maxi(0,int(job["ready_minute"])-minute) if stage == "active" else 0
        result["phase_label"] = ["Seasoning","Pan-searing","Assembly"][index]
        result["heat_state"] = "inactive"
        result["heat_caption"] = "Workstation clear · ready for the next gesture"
        if stage == "interrupted":
            result["heat_state"] = "paused"
            result["heat_caption"] = "Preparation paused · resume the station"
        elif stage == "waiting":
            result["heat_caption"] = "Station ready · press Enter to begin"
        elif index == 1:
            var technique: Dictionary = step["technique"]
            if job.has("step_action"):
                result["heat_minutes"] = absi(int(job["ready_minute"])-minute)
                result["heat_state"] = "turned" if minute <= int(job["ready_minute"]) else "second_face_late"
                result["heat_caption"] = "Other side needs %d min" % result["heat_minutes"] if result["heat_state"] == "turned" else \
                    "Second side left %d min too long" % result["heat_minutes"]
            else:
                var earliest: int = int(job["ready_minute"]) - int(step["work_minutes"]) + int(technique["earliest_minutes"])
                var latest: int = int(job["ready_minute"])
                if minute < earliest:
                    result["heat_state"] = "warming"
                    result["heat_minutes"] = earliest-minute
                    result["heat_caption"] = "First side · wait %d min to turn" % result["heat_minutes"]
                elif minute <= latest:
                    result["heat_state"] = "turn_window"
                    result["heat_minutes"] = latest-minute
                    result["heat_caption"] = "Turn now · %d min left in the best window" % result["heat_minutes"]
                else:
                    result["heat_state"] = "overseared"
                    result["heat_minutes"] = minute-latest
                    result["heat_caption"] = "First side is %d min late · turn to finish" % result["heat_minutes"]
        elif stage == "active":
            result["heat_state"] = "working" if result["ready_in"] > 0 else "ready"
            result["heat_caption"] = "Work in progress · %d min remaining" % result["ready_in"] if result["ready_in"] > 0 else \
                "Ready for the next gesture"
        if stage == "interrupted":
            result["cue"] = "Enter · Resume preparation"
        elif stage == "waiting":
            result["cue"] = ["Enter · Season liver and garlic",
                "Enter · Put the pan on the heat","Enter · Assemble bread and lemon"][index]
        elif step.has("technique") and not job.has("step_action"):
            var until_turn: int = maxi(0,int(job["ready_minute"]) - int(step["work_minutes"]) + int(step["technique"]["earliest_minutes"]) - int(session.world.view()["world_minute"]))
            result["cue"] = "Turn in %d world min · Enter" % until_turn if until_turn > 0 else "Enter · Turn the liver now"
            result["ready_in"] = until_turn
        else:
            result["cue"] = "Wait %d world min · Enter to finish" % result["ready_in"] if result["ready_in"] > 0 else \
                ["Enter · Finish seasoning","Enter · Lift from pan","Enter · Finish sandwich"][index]
    var latest: Dictionary = {}
    for item in cooking["items"].values():
        if item["recipe_id"] != RECIPE or not str(item["job_id"]).begins_with(PREFIX):
            continue
        if latest.is_empty() or int(item["created_minute"]) > int(latest["created_minute"]):
            latest = item
    if not latest.is_empty():
        var quality: Dictionary = session.world.prepared_quality(str(latest["item_id"]))
        result["item_id"] = str(latest["item_id"])
        result["grade"] = str(quality.get("grade",""))
        result["score"] = int(quality.get("score",0))
    # This is a P4 projection only; F7 still uses P3 and never accepts,
    # delivers or settles an order. G remains the real service interaction.
    result["service_note"] = "No liver order yet · prepare one ahead, or wait"
    var orders: Dictionary = session.world.orders_view()["orders"]
    var selected: Dictionary = {}
    for order in orders.values():
        if order["recipe_id"] != RECIPE or order["npc_id"] != "salma":
            continue
        if selected.is_empty() or int(order["created_minute"]) > int(selected["created_minute"]):
            selected = order
    if not selected.is_empty():
        match str(selected["status"]):
            "offered":
                result["service_note"] = "Salma wants a sandwich · G to accept"
            "accepted":
                result["service_note"] = "Salma is waiting · F7 prepare, G deliver"
            "delivered":
                result["service_note"] = "Delivered · G to quote and settle" if selected["payment_status"] != "settled" else \
                    "Salma paid for the delivered sandwich"
            "abandoned":
                result["service_note"] = "Salma left without a sandwich"
    return result

static func purchase(session: RefCounted, index: int, id: String) -> Dictionary:
    if not near(session): return {"ok":false,"code":"COUNTER_TOO_FAR"}
    var options: Array[Dictionary] = offers(session)
    if index < 0 or index >= options.size(): return {"ok":false,"code":"UNKNOWN_OFFER"}
    var selected: Dictionary = options[index]
    var receipt: Dictionary = session.command(id,"player","supply.purchase",
        {"offer_id":selected["offer_id"]})
    if receipt.get("ok",false):
        receipt["caption"] = "Bought %s: %d for %d piastres." % [
            selected["ingredient_id"],selected["quantity"],selected["cost"]]
    return receipt

static func advance(session: RefCounted, id: String) -> Dictionary:
    if not near(session): return {"ok":false,"code":"COUNTER_TOO_FAR"}
    var job: Dictionary = active_job(session)
    var kind: String = "cook.start"
    var payload: Dictionary = {}
    if job.is_empty():
        var minute: int = int(session.world.view()["world_minute"])
        if minute > 2147483587: return {"ok":false,"code":"TIME_OVERFLOW"}
        payload = {"job_id":PREFIX+str(int(session.world.view()["sequence"])+1),
            "recipe_id":RECIPE,"deadline_minute":minute+60}
    else:
        var idx: int = int(job["step_index"])
        var stage: String = str(job["stage"])
        payload = {"job_id":str(job["job_id"])}
        if stage == "interrupted" or stage == "waiting":
            kind = "cook.step.resume" if stage == "interrupted" else "cook.step.begin"
            payload["station_id"] = "sandwich_pan" if idx == 1 else "sandwich_board"
        elif stage == "active":
            var step: Dictionary = session.world.cooking_view()["recipes"][RECIPE]["steps"][idx]
            if step.has("technique") and not job.has("step_action"):
                kind = "cook.step.action"
                payload["action_id"] = str(step["technique"]["action_id"])
            else:
                kind = "cook.step.finish"
        else: return {"ok":false,"code":"INVALID_STAGE"}
    var receipt: Dictionary = session.command(id,"player",kind,payload)
    if receipt.get("ok",false):
        receipt["caption"] = "Sandwich: " + str(context(session)["cue"])
        if kind == "cook.step.finish" and active_job(session).is_empty():
            var quality: Dictionary = session.world.prepared_quality("item:"+str(payload["job_id"]))
            receipt["caption"] = "Sandwich ready: %s (%d/100)." % [quality.get("grade","unknown"),quality.get("score",0)]
            receipt["quality"] = quality
    return receipt
