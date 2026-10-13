extends RefCounted
## PLAY C3: presentation adapter over P3/P4/P5, no second order/job/payment state.
## Each player key press performs at most ONE canonical world command.
const WorldState = preload("res://scripts/core/world_state.gd")
const Graph = preload("res://scripts/integration/room_traversal.gd")
const MAX_WAIT: int = 10080

static func fail(code: String) -> Dictionary:
    return {"ok":false,"code":code}

static func _keys(value: Dictionary, fields: Array) -> bool:
    if value.size() != fields.size(): return false
    for key in fields:
        if not value.has(key): return false
    return true

static func validate_manifest(raw: Variant) -> Dictionary:
    if typeof(raw) != TYPE_DICTIONARY or not _keys(raw, ["schema","intents"]) or not WorldState.integral(raw["schema"],1) or int(raw["schema"]) != 1 or typeof(raw["intents"]) != TYPE_ARRAY or raw["intents"].is_empty() or raw["intents"].size() > 32:
        return fail("INVALID_INTENTS")
    var result: Dictionary = {}
    for row in raw["intents"]:
        if typeof(row) != TYPE_DICTIONARY or not _keys(row, ["order_id","npc_id","venue_id","recipe_id","route","wait_minutes"]):
            return fail("INVALID_INTENT")
        for field in ["order_id","npc_id","venue_id","recipe_id"]:
            if not WorldState.valid_identity(row[field]): return fail("INVALID_INTENT")
        if row["route"] not in ["counter","takeaway","table"] or not WorldState.integral(row["wait_minutes"],1,MAX_WAIT) or result.has(row["order_id"]):
            return fail("INVALID_INTENT")
        result[row["order_id"]] = row.duplicate(true)
    return {"ok":true,"intents":result}

static func load_packaged(path: String) -> Dictionary:
    if not path.begins_with("res://content/service/") or path.contains("..") or not path.ends_with(".json"):
        return fail("UNTRUSTED_INTENTS")
    if not FileAccess.file_exists(path): return fail("INTENTS_NOT_FOUND")
    return validate_manifest(JSON.parse_string(FileAccess.get_file_as_string(path)))

static func offer(session: RefCounted, intent: Dictionary) -> Dictionary:
    # Scripted QA-only NPC intention; verify real canonical player XY and NPC room.
    var state: Dictionary = session.world.view()
    var venue: Dictionary = state["service"]["venues"].get(intent["venue_id"], {})
    if venue.is_empty(): return fail("UNKNOWN_VENUE")
    var pose: Dictionary = state["spatial"]["player"]
    var room: String = str(venue["location_id"])
    if pose["room_id"] != room: return fail("PLAYER_ABSENT")
    var npc: Dictionary = state["society"]["npcs"].get(intent["npc_id"],{})
    if npc.is_empty() or npc["location_id"] != room: return fail("CUSTOMER_ABSENT")
    var close: bool = false
    for anchor in state["spatial"]["graph"].get("anchors",[]):
        if anchor["npc_id"] != intent["npc_id"] or anchor["room_id"] != room: continue
        var dx: int = int(pose["x"]) - int(anchor["point"][0])
        var dy: int = int(pose["y"]) - int(anchor["point"][1])
        close = dx*dx+dy*dy <= int(Graph.RADIUS*Graph.RADIUS)
    if not close: return fail("CUSTOMER_NOT_NEARBY")
    if state["service"]["orders"].has(intent["order_id"]): return fail("ORDER_EXISTS")
    var now: int = int(state["world_minute"])
    if now > WorldState.MAX_INT_JSON - int(intent["wait_minutes"]):
        return fail("DEADLINE_OVERFLOW")
    var data: Dictionary = {
        "order_id":intent["order_id"],"npc_id":intent["npc_id"],
        "venue_id":intent["venue_id"],"recipe_id":intent["recipe_id"],
        "route":intent["route"],"deadline_minute":now+int(intent["wait_minutes"])
    }
    return session.command("play:c3:offer:"+str(intent["order_id"]),str(intent["npc_id"]),"order.offer",data)

static func _oldest_order(orders: Dictionary, status: String, venue: String) -> Dictionary:
    var matches: Array = []
    for id in orders:
        var order: Dictionary = orders[id]
        if order["venue_id"] == venue and order["status"] == status:
            matches.append(order)
    matches.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        if int(a["offer_sequence"]) != int(b["offer_sequence"]):
            return int(a["offer_sequence"]) < int(b["offer_sequence"])
        return str(a["order_id"]) < str(b["order_id"]))
    return {} if matches.is_empty() else matches[0]

static func next_action(session: RefCounted, venue_id: String) -> Dictionary:
    var v: Dictionary = session.world.view()
    var venue: Dictionary = v["service"]["venues"].get(venue_id,{})
    if venue.is_empty(): return fail("UNKNOWN_VENUE")
    if v["society"]["player_location"] != venue["location_id"]:
        return fail("PLAYER_ABSENT")
    var orders: Dictionary = v["service"]["orders"]
    var offered: Dictionary = _oldest_order(orders,"offered",venue_id)
    if not offered.is_empty():
        if offered["route"] == "table":
            var seat: String = ""
            for candidate in venue["table_ids"]:
                var occupied: bool = false
                for other in orders.values():
                    if other["status"] == "accepted" and other["venue_id"] == venue_id and other["seat_id"] == candidate:
                        occupied = true
                if not occupied:
                    seat = candidate
                    break
            if seat.is_empty(): return fail("NO_SEAT")
            return {"ok":true,"kind":"order.accept","actor":"player",
                "payload":{"order_id":offered["order_id"],"seat_id":seat}}
        return {"ok":true,"kind":"order.accept","actor":"player",
            "payload":{"order_id":offered["order_id"],"seat_id":""}}
    # Settle only real prior deliveries, never mint money for an offered order.
    var unsettled: Dictionary = {}
    var unpaid: Array = []
    for order in orders.values():
        if order["venue_id"] == venue_id and order["status"] == "delivered" and order["payment_status"] != "settled":
            unpaid.append(order)
    unpaid.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        if int(a["offer_sequence"]) != int(b["offer_sequence"]):
            return int(a["offer_sequence"]) < int(b["offer_sequence"])
        return str(a["order_id"]) < str(b["order_id"]))
    if not unpaid.is_empty(): unsettled = unpaid[0]
    var delivered: Dictionary = unsettled
    if not delivered.is_empty():
        var claim: String = delivered["payment_claim_id"]
        if not v["economy"]["quotes"].has(claim):
            return {"ok":true,"kind":"economy.order.quote","actor":"system:pricing",
                "payload":{"claim_id":claim}}
        return {"ok":true,"kind":"economy.order.settle","actor":"system:service",
            "payload":{"claim_id":claim,"transaction_id":"play:c3:payment:"+str(delivered["order_id"])}}
    var accepted: Dictionary = _oldest_order(orders,"accepted",venue_id)
    if accepted.is_empty(): return fail("NO_ACTIVE_ORDER")
    var prepared: Dictionary = {}
    var item_ids: Array = v["cooking"]["items"].keys()
    item_ids.sort()
    for item_id in item_ids:
        var item: Dictionary = v["cooking"]["items"][item_id]
        if item["recipe_id"] == accepted["recipe_id"] and item["status"] == "ready":
            return {"ok":true,"kind":"order.deliver","actor":"player",
                "payload":{"order_id":accepted["order_id"],"item_id":item_id}}
    var job_id: String = "play:c3:prep:"+str(accepted["order_id"])
    var cooking: Dictionary = v["cooking"]
    if not cooking["preparations"].has(job_id):
        return {"ok":true,"kind":"cook.start","actor":"player",
            "payload":{"job_id":job_id,"recipe_id":accepted["recipe_id"],
                "deadline_minute":accepted["deadline_minute"]}}
    var job: Dictionary = cooking["preparations"][job_id]
    if job["stage"] in ["cancelled","expired","completed"]:
        return fail("PREPARATION_UNAVAILABLE")
    if job["stage"] == "active":
        if int(v["world_minute"]) < int(job["ready_minute"]):
            return {"ok":false,"code":"STEP_NOT_READY","wait_minutes":int(job["ready_minute"])-int(v["world_minute"])}
        return {"ok":true,"kind":"cook.step.finish","actor":"player",
            "payload":{"job_id":job_id}}
    if job["stage"] == "waiting" or job["stage"] == "interrupted":
        var recipe: Dictionary = cooking["recipes"][job["recipe_id"]]
        var step: Dictionary = recipe["steps"][job["step_index"]]
        var station_ids: Array = cooking["stations"].keys()
        station_ids.sort()
        for station_id in station_ids:
            var station: Dictionary = cooking["stations"][station_id]
            if station["station_type"] == step["station_type"] and not station["blocked"] and station["busy_job"].is_empty():
                return {"ok":true,"kind":"cook.step.begin" if job["stage"] == "waiting" else "cook.step.resume",
                    "actor":"player","payload":{"job_id":job_id,"station_id":station_id}}
        return fail("NO_AVAILABLE_STATION")
    return fail("INVALID_PREPARATION")

static func perform_next(session: RefCounted, venue_id: String) -> Dictionary:
    var step: Dictionary = next_action(session,venue_id)
    if not step.get("ok",false): return step
    var revision: int = int(session.world.view()["sequence"])+1
    var response: Dictionary = session.command("play:c3:step:"+str(revision),
        step["actor"],step["kind"],step["payload"])
    if not response.get("ok",false): return response
    return {"ok":true,"code":"ACTION_APPLIED","kind":step["kind"],
        "payload":step["payload"].duplicate(true),"receipt":response}
