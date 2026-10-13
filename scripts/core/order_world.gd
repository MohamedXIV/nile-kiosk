extends RefCounted
## SYS P4: canonical service and orders. No prices, dialogue/UI ownership, or NPC scripting.
const MAXIMUM: int = 2147483647

var venues: Dictionary = {}
var orders: Dictionary = {}
var payment_claims: Dictionary = {}

static func ident(v: Variant) -> bool:
    return typeof(v) == TYPE_STRING and not (v as String).strip_edges().is_empty() and (v as String).length() <= 128

static func integer(v: Variant, min_value: int = 0) -> bool:
    if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
        return false
    var f: float = float(v)
    return is_finite(f) and f >= float(min_value) and f <= float(MAXIMUM) and f == float(int(v))

static func exact(p: Dictionary, keys: Array) -> bool:
    if p.size() != keys.size():
        return false
    for k in keys:
        if not p.has(k):
            return false
    return true

static func owns(kind: String) -> bool:
    return kind in ["service.configure", "order.offer", "order.accept", "order.cancel", "order.abandon", "order.deliver"]

static func event_kind(kind: String) -> String:
    match kind:
        "service.configure": return "service.configured"
        "order.offer": return "order.offered"
        "order.accept": return "order.accepted"
        "order.cancel": return "order.cancelled"
        "order.abandon": return "order.abandoned"
        "order.deliver": return "order.delivered"
    return ""

static func command_kind(kind: String) -> String:
    match kind:
        "service.configured": return "service.configure"
        "order.offered": return "order.offer"
        "order.accepted": return "order.accept"
        "order.cancelled": return "order.cancel"
        "order.abandoned": return "order.abandon"
        "order.delivered": return "order.deliver"
    return ""

static func fail(code: String) -> Dictionary:
    return {"ok": false, "code": code}

func snapshot() -> Dictionary:
    return {"venues": venues.duplicate(true), "orders": orders.duplicate(true),
        "payment_claims": payment_claims.duplicate(true)}

func duplicate_domain() -> RefCounted:
    var c: RefCounted = get_script().new()
    c.venues = venues.duplicate(true)
    c.orders = orders.duplicate(true)
    c.payment_claims = payment_claims.duplicate(true)
    return c

static func active(o: Dictionary) -> bool:
    return o["status"] in ["offered", "accepted"]

func _count(venue_id: String, route: String) -> int:
    var count: int = 0
    for o in orders.values():
        if o["venue_id"] == venue_id and o["route"] == route and active(o):
            count += 1
    return count

func _seat_occupied(venue_id: String, seat_id: String) -> bool:
    for o in orders.values():
        if o["venue_id"] == venue_id and o["status"] == "accepted" and o["seat_id"] == seat_id:
            return true
    return false

func _customer_at(society: RefCounted, npc_id: String, place: String) -> bool:
    return society.npcs.has(npc_id) and society.npcs[npc_id]["location_id"] == place

func plan(kind: String, p: Dictionary, actor: String, society: RefCounted,
          cooking: RefCounted, scheduler_jobs: Dictionary, minute: int) -> Dictionary:
    match kind:
        "service.configure":
            if not exact(p, ["venue_id", "location_id", "counter_slots", "takeaway_slots", "table_ids"]):
                return fail("INVALID_PAYLOAD")
            if not ident(p.get("venue_id")) or not ident(p.get("location_id")) or not integer(p.get("counter_slots")) or not integer(p.get("takeaway_slots")) or typeof(p.get("table_ids")) != TYPE_ARRAY:
                return fail("INVALID_PAYLOAD")
            if int(p["counter_slots"]) > 128 or int(p["takeaway_slots"]) > 128 or p["table_ids"].size() > 128:
                return fail("INVALID_CAPACITY")
            if venues.has(p["venue_id"]):
                return fail("VENUE_EXISTS")
            var seen: Dictionary = {}
            for seat in p["table_ids"]:
                if not ident(seat) or seen.has(seat):
                    return fail("INVALID_SEATS")
                seen[seat] = true
            return {"ok": true, "effect": {"venue_id": p["venue_id"]}}
        "order.offer":
            if not exact(p, ["order_id", "venue_id", "npc_id", "recipe_id", "route", "deadline_minute"]):
                return fail("INVALID_PAYLOAD")
            if not ident(p.get("order_id")) or not ident(p.get("venue_id")) or not ident(p.get("npc_id")) or not ident(p.get("recipe_id")):
                return fail("INVALID_PAYLOAD")
            if p.get("route") not in ["counter", "takeaway", "table"] or not integer(p.get("deadline_minute"), minute + 1):
                return fail("INVALID_PAYLOAD")
            if actor != p["npc_id"]:
                return fail("ACTOR_NOT_CUSTOMER")
            if orders.has(p["order_id"]):
                return fail("ORDER_EXISTS")
            if not venues.has(p["venue_id"]):
                return fail("UNKNOWN_VENUE")
            if not cooking.recipes.has(p["recipe_id"]):
                return fail("UNKNOWN_RECIPE")
            var v: Dictionary = venues[p["venue_id"]]
            if not _customer_at(society, p["npc_id"], v["location_id"]):
                return fail("CUSTOMER_ABSENT")
            for other in orders.values():
                if active(other) and other["npc_id"] == p["npc_id"]:
                    return fail("CUSTOMER_HAS_ORDER")
            var capacity: int = int(v["counter_slots"]) if p["route"] == "counter" else (int(v["takeaway_slots"]) if p["route"] == "takeaway" else v["table_ids"].size())
            if _count(p["venue_id"], p["route"]) >= capacity:
                return fail("QUEUE_FULL")
            var deadline_id: String = "order:deadline:" + p["order_id"]
            if scheduler_jobs.has(deadline_id):
                return fail("JOB_ID_CONFLICT")
            return {"ok": true, "effect": {"deadline_job_id": deadline_id, "queue_position": _count(p["venue_id"], p["route"]) + 1}}
        "order.accept":
            if not exact(p, ["order_id", "seat_id"]) or not ident(p.get("order_id")) or typeof(p.get("seat_id")) != TYPE_STRING:
                return fail("INVALID_PAYLOAD")
            if not orders.has(p["order_id"]):
                return fail("UNKNOWN_ORDER")
            var o: Dictionary = orders[p["order_id"]]
            if o["status"] != "offered":
                return fail("INVALID_ORDER_STAGE")
            if actor != "player":
                return fail("ACTOR_NOT_PLAYER")
            if society.player_location != venues[o["venue_id"]]["location_id"]:
                return fail("PLAYER_ABSENT")
            if not _customer_at(society, o["npc_id"], society.player_location):
                return fail("CUSTOMER_ABSENT")
            if minute >= int(o["deadline_minute"]):
                return fail("ORDER_STALE")
            if o["route"] == "table":
                if not ident(p["seat_id"]) or not (p["seat_id"] in venues[o["venue_id"]]["table_ids"]):
                    return fail("INVALID_SEAT")
                if _seat_occupied(o["venue_id"], p["seat_id"]):
                    return fail("SEAT_OCCUPIED")
            elif not p["seat_id"].is_empty():
                return fail("UNEXPECTED_SEAT")
            return {"ok": true, "effect": {"seat_id": p["seat_id"]}}
        "order.cancel", "order.abandon":
            if not exact(p, ["order_id", "reason"]) or not ident(p.get("order_id")) or not ident(p.get("reason")):
                return fail("INVALID_PAYLOAD")
            if not orders.has(p["order_id"]):
                return fail("UNKNOWN_ORDER")
            var o: Dictionary = orders[p["order_id"]]
            if not active(o):
                return fail("ORDER_FINAL")
            if kind == "order.cancel" and actor != "player" and actor != o["npc_id"]:
                return fail("UNAUTHORIZED")
            if kind == "order.abandon" and actor != o["npc_id"] and actor != "system:service":
                return fail("UNAUTHORIZED")
            return {"ok": true, "effect": {"status": "cancelled" if kind == "order.cancel" else "abandoned"}}
        "order.deliver":
            if not exact(p, ["order_id", "item_id"]) or not ident(p.get("order_id")) or not ident(p.get("item_id")):
                return fail("INVALID_PAYLOAD")
            if actor != "player":
                return fail("ACTOR_NOT_PLAYER")
            if not orders.has(p["order_id"]):
                return fail("UNKNOWN_ORDER")
            var o: Dictionary = orders[p["order_id"]]
            if o["status"] != "accepted":
                return fail("INVALID_ORDER_STAGE")
            if minute >= int(o["deadline_minute"]):
                return fail("ORDER_STALE")
            var loc: String = venues[o["venue_id"]]["location_id"]
            if society.player_location != loc:
                return fail("PLAYER_ABSENT")
            if not _customer_at(society, o["npc_id"], loc):
                return fail("CUSTOMER_ABSENT")
            if not cooking.items.has(p["item_id"]):
                return fail("UNKNOWN_ITEM")
            var item: Dictionary = cooking.items[p["item_id"]]
            if item["status"] != "ready":
                return fail("ITEM_NOT_READY")
            if item["recipe_id"] != o["recipe_id"]:
                return fail("WRONG_RECIPE")
            var claim: String = "payment:order:" + p["order_id"]
            if payment_claims.has(claim):
                return fail("PAYMENT_CLAIM_CONFLICT")
            # Explicit deferred ledger boundary; a delivery is NOT money.
            return {"ok": true, "effect": {"payment_claim_id": claim, "item_id": p["item_id"], "customer_id": o["npc_id"], "recipe_id": o["recipe_id"]}}
    return fail("UNKNOWN_COMMAND")

static func _make_job(id: String, due: int, data: Dictionary, seq: int, actor: String, command_id: String) -> Dictionary:
    return {
        "job_id": id, "due_minute": due, "priority": 300,
        "topic": "order.deadline", "data": data.duplicate(true), "every_minutes": 0,
        "created_sequence": seq, "source_actor_id": actor, "source_command_id": command_id,
        "status": "pending", "execution_count": 0, "last_fire_id": ""
    }

func _end_order(o: Dictionary, status: String, at: int, cause_id: String, scheduler_jobs: Dictionary, cancel_deadline: bool = true) -> void:
    o["status"] = status
    o["closed_minute"] = at
    o["closure_event_id"] = cause_id
    if cancel_deadline and scheduler_jobs[o["deadline_job_id"]]["status"] == "pending":
        scheduler_jobs[o["deadline_job_id"]]["status"] = "cancelled"

func apply_command(kind: String, p: Dictionary, effect: Dictionary, minute: int, event_id: String,
                  seq: int, actor: String, command_id: String, scheduler_jobs: Dictionary,
                  cooking: RefCounted) -> void:
    match kind:
        "service.configure":
            venues[p["venue_id"]] = {
                "venue_id": p["venue_id"], "location_id": p["location_id"],
                "counter_slots": int(p["counter_slots"]), "takeaway_slots": int(p["takeaway_slots"]),
                "table_ids": p["table_ids"].duplicate(true), "created_event_id": event_id
            }
        "order.offer":
            var job_id: String = effect["deadline_job_id"]
            orders[p["order_id"]] = {
                "order_id": p["order_id"], "npc_id": p["npc_id"], "venue_id": p["venue_id"],
                "recipe_id": p["recipe_id"], "route": p["route"], "status": "offered",
                "deadline_minute": int(p["deadline_minute"]), "deadline_job_id": job_id,
                "created_minute": minute, "created_event_id": event_id,
                "queue_position_at_offer": effect["queue_position"],
                "accepted_minute": -1, "seat_id": "", "item_id": "",
                "closed_minute": -1, "closure_event_id": "",
                "payment_claim_id": "", "payment_status": "none"
            }
            scheduler_jobs[job_id] = _make_job(job_id, int(p["deadline_minute"]), {"order_id": p["order_id"]}, seq, actor, command_id)
        "order.accept":
            orders[p["order_id"]]["status"] = "accepted"
            orders[p["order_id"]]["accepted_minute"] = minute
            orders[p["order_id"]]["seat_id"] = effect["seat_id"]
        "order.cancel", "order.abandon":
            _end_order(orders[p["order_id"]], effect["status"], minute, event_id, scheduler_jobs)
        "order.deliver":
            var o: Dictionary = orders[p["order_id"]]
            # The item transition and order settlement are within THIS event.
            cooking.apply_command("cook.item.use",
                {"item_id": p["item_id"], "purpose_id": p["order_id"]},
                {"item_id": p["item_id"]}, minute, event_id, seq, actor, command_id, scheduler_jobs)
            _end_order(o, "delivered", minute, event_id, scheduler_jobs)
            o["item_id"] = p["item_id"]
            o["payment_claim_id"] = effect["payment_claim_id"]
            o["payment_status"] = "awaiting_ledger"
            payment_claims[effect["payment_claim_id"]] = {
                "claim_id": effect["payment_claim_id"], "order_id": p["order_id"],
                "item_id": p["item_id"], "status": "awaiting_ledger",
                "amount": null, "created_event_id": event_id
            }

func departing(npc_id: String, at: int, cause_id: String, scheduler_jobs: Dictionary, cancel_deadline: bool = true) -> Array:
    var affected: Array = []
    var ids: Array = orders.keys()
    ids.sort()
    for id in ids:
        var o: Dictionary = orders[id]
        if o["npc_id"] != npc_id or not active(o):
            continue
        _end_order(o, "abandoned", at, cause_id, scheduler_jobs, cancel_deadline)
        affected.append({"order_id": id, "npc_id": npc_id, "outcome": "customer_left",
            "at_minute": at, "cause_id": cause_id})
    return affected

func simulate(fires: Array, starting_society: RefCounted, scheduler_jobs: Dictionary) -> Array:
    var living: RefCounted = starting_society.clone_state()
    var outcomes: Array = []
    for fire in fires:
        var npc_result: Dictionary = living.apply_firing(fire)
        if npc_result.get("outcome", "") == "departed":
            # Keep the scheduled deadline alive after an automatic NPC exit.
            # A single coarse advance already plans that deadline firing, and
            # smaller advances must reach the same completed scheduler state.
            var cause: String = "schedule:" + fire["job_id"] + ":" + str(fire["occurrence"])
            outcomes.append_array(departing(npc_result["npc_id"], int(fire["world_minute"]), cause, scheduler_jobs, false))
        if fire["topic"] == "order.deadline":
            var order_id: String = fire["data"]["order_id"]
            var o: Dictionary = orders[order_id]
            if active(o):
                _end_order(o, "abandoned", int(fire["world_minute"]),
                    "schedule:" + fire["job_id"] + ":" + str(fire["occurrence"]), scheduler_jobs)
                outcomes.append({"order_id": order_id, "npc_id": o["npc_id"],
                    "outcome": "deadline", "at_minute": fire["world_minute"], "cause_id": "schedule:" + fire["job_id"] + ":" + str(fire["occurrence"])})
    return outcomes

func project_firings(fires: Array, society: RefCounted, scheduler_jobs: Dictionary) -> Array:
    return duplicate_domain().simulate(fires, society, scheduler_jobs.duplicate(true))

func apply_firings(fires: Array, society: RefCounted, scheduler_jobs: Dictionary) -> void:
    simulate(fires, society, scheduler_jobs)
