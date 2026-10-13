extends RefCounted
## SYS P5: authored rental units, access entitlements and logical home objects.
## No scene geometry, arbitrary rents, physical layouts or automatic evictions.
const LIMIT: int = 2147483647
var units: Dictionary = {}
var roof_rights: Dictionary = {}
var leases: Dictionary = {}
var types: Dictionary = {}
var objects: Dictionary = {}
var due_log: Array = []

static func ident(v: Variant) -> bool:
    return typeof(v) == TYPE_STRING and not (v as String).strip_edges().is_empty() and (v as String).length() <= 128

static func integer(v: Variant, minimum: int = 0) -> bool:
    if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT: return false
    var f: float = float(v)
    return is_finite(f) and f >= float(minimum) and f <= float(LIMIT) and f == float(int(v))

static func exact(p: Dictionary, keys: Array) -> bool:
    if p.size() != keys.size(): return false
    for key in keys:
        if not p.has(key): return false
    return true

static func owns(kind: String) -> bool:
    return kind in ["housing.unit.register", "housing.roof.grant", "housing.lease.start",
        "housing.rent.pay", "housing.lease.end", "home.type.define",
        "home.object.grant", "home.object.acquire", "home.object.place",
        "home.object.store", "home.object.interact"]

static func event_kind(kind: String) -> String:
    match kind:
        "housing.unit.register": return "housing.unit_registered"
        "housing.roof.grant": return "housing.roof_granted"
        "housing.lease.start": return "housing.lease_started"
        "housing.rent.pay": return "housing.rent_paid"
        "housing.lease.end": return "housing.lease_ended"
        "home.type.define": return "home.type_defined"
        "home.object.grant": return "home.object_granted"
        "home.object.acquire": return "home.object_acquired"
        "home.object.place": return "home.object_placed"
        "home.object.store": return "home.object_stored"
        "home.object.interact": return "home.object_interacted"
    return ""

static func command_kind(kind: String) -> String:
    match kind:
        "housing.unit_registered": return "housing.unit.register"
        "housing.roof_granted": return "housing.roof.grant"
        "housing.lease_started": return "housing.lease.start"
        "housing.rent_paid": return "housing.rent.pay"
        "housing.lease_ended": return "housing.lease.end"
        "home.type_defined": return "home.type.define"
        "home.object_granted": return "home.object.grant"
        "home.object_acquired": return "home.object.acquire"
        "home.object_placed": return "home.object.place"
        "home.object_stored": return "home.object.store"
        "home.object_interacted": return "home.object.interact"
    return ""

static func fail(code: String) -> Dictionary:
    return {"ok": false, "code": code}

func snapshot() -> Dictionary:
    return {"units": units.duplicate(true), "roof_rights": roof_rights.duplicate(true),
        "leases": leases.duplicate(true), "types": types.duplicate(true),
        "objects": objects.duplicate(true), "due_log": due_log.duplicate(true)}

func copy_domain() -> RefCounted:
    var c: RefCounted = get_script().new()
    c.units = units.duplicate(true)
    c.roof_rights = roof_rights.duplicate(true)
    c.leases = leases.duplicate(true)
    c.types = types.duplicate(true)
    c.objects = objects.duplicate(true)
    c.due_log = due_log.duplicate(true)
    return c

func allowed(unit_id: String) -> bool:
    if not units.has(unit_id): return false
    if roof_rights.has(unit_id): return true
    var lease_id: String = units[unit_id]["active_lease_id"]
    if lease_id.is_empty(): return false
    return leases[lease_id]["status"] == "active" and leases[lease_id]["dues_owed"] == 0

func _player_here(unit_id: String, society: RefCounted) -> bool:
    return units.has(unit_id) and society.player_location == units[unit_id]["location_id"]

func _slot_available(unit_id: String, slot_id: String, exclude: String = "") -> bool:
    for id in objects:
        if id != exclude and objects[id]["unit_id"] == unit_id and objects[id]["slot_id"] == slot_id:
            return false
    return true

func plan(kind: String, p: Dictionary, actor: String, society: RefCounted, economy: RefCounted,
        jobs: Dictionary, minute: int) -> Dictionary:
    match kind:
        "housing.unit.register":
            if not exact(p, ["unit_id", "location_id", "kind", "area_sqm", "rent_minor", "period_minutes"]):
                return fail("INVALID_PAYLOAD")
            if actor != "system:housing":
                return fail("UNAUTHORIZED")
            if not ident(p.get("unit_id")) or not ident(p.get("location_id")) or p.get("kind") not in ["roof", "apartment"]:
                return fail("INVALID_PAYLOAD")
            if not integer(p.get("area_sqm")) or not integer(p.get("rent_minor")) or not integer(p.get("period_minutes")):
                return fail("INVALID_PAYLOAD")
            if p["kind"] == "roof" and (int(p["rent_minor"]) != 0 or int(p["period_minutes"]) != 0):
                return fail("INVALID_ROOF")
            if p["kind"] == "apartment" and (int(p["rent_minor"]) == 0 or int(p["period_minutes"]) < 1):
                return fail("INVALID_RENT")
            if units.has(p["unit_id"]): return fail("UNIT_EXISTS")
            return {"ok": true, "effect": {"unit_id": p["unit_id"]}}
        "housing.roof.grant":
            if not exact(p, ["unit_id"]) or not ident(p.get("unit_id")): return fail("INVALID_PAYLOAD")
            if actor != "system:bootstrap": return fail("UNAUTHORIZED")
            if not units.has(p["unit_id"]) or units[p["unit_id"]]["kind"] != "roof": return fail("NOT_ROOF")
            if roof_rights.has(p["unit_id"]): return fail("RIGHT_EXISTS")
            return {"ok": true, "effect": {"unit_id": p["unit_id"]}}
        "housing.lease.start":
            if not exact(p, ["lease_id", "unit_id", "transaction_id"]) or not ident(p.get("lease_id")) or not ident(p.get("unit_id")) or not ident(p.get("transaction_id")):
                return fail("INVALID_PAYLOAD")
            if actor != "player": return fail("UNAUTHORIZED")
            if not units.has(p["unit_id"]) or units[p["unit_id"]]["kind"] != "apartment": return fail("NOT_RENTABLE")
            if not units[p["unit_id"]]["active_lease_id"].is_empty(): return fail("UNIT_OCCUPIED")
            if leases.has(p["lease_id"]): return fail("LEASE_EXISTS")
            for previous in leases.values():
                if previous["unit_id"] == p["unit_id"] and previous["dues_owed"] > 0:
                    return fail("OUTSTANDING_DUES")
            var unit: Dictionary = units[p["unit_id"]]
            if int(unit["period_minutes"]) > LIMIT - minute: return fail("TIME_OVERFLOW")
            var job_id: String = "housing:due:" + p["lease_id"]
            if jobs.has(job_id): return fail("JOB_ID_CONFLICT")
            return {"ok": true, "effect": {
                "job_id": job_id, "due_minute": minute + int(unit["period_minutes"]),
                "transfer": {"transaction_id": p["transaction_id"],
                    "from_account": "player", "to_account": "world:landlord",
                    "amount_minor": int(unit["rent_minor"]), "cause_id": "lease:" + p["lease_id"]}
            }}
        "housing.rent.pay":
            if not exact(p, ["lease_id", "transaction_id"]) or not ident(p.get("lease_id")) or not ident(p.get("transaction_id")): return fail("INVALID_PAYLOAD")
            if actor != "player": return fail("UNAUTHORIZED")
            if not leases.has(p["lease_id"]): return fail("UNKNOWN_LEASE")
            var lease: Dictionary = leases[p["lease_id"]]
            if lease["dues_owed"] < 1: return fail("NO_DUES")
            return {"ok": true, "effect": {"lease_id": p["lease_id"], "transfer": {
                "transaction_id": p["transaction_id"], "from_account": "player",
                "to_account": "world:landlord", "amount_minor": lease["rent_minor"],
                "cause_id": "rent:" + p["lease_id"] + ":" + str(lease["dues_owed"])}
            }}
        "housing.lease.end":
            if not exact(p, ["lease_id"]) or not ident(p.get("lease_id")): return fail("INVALID_PAYLOAD")
            if actor != "player": return fail("UNAUTHORIZED")
            if not leases.has(p["lease_id"]) or leases[p["lease_id"]]["status"] != "active":
                return fail("LEASE_NOT_ACTIVE")
            return {"ok": true, "effect": {"lease_id": p["lease_id"]}}
        "home.type.define":
            if not exact(p, ["type_id", "price_minor", "actions"]) or not ident(p.get("type_id")) or not integer(p.get("price_minor")) or typeof(p.get("actions")) != TYPE_ARRAY:
                return fail("INVALID_PAYLOAD")
            if actor != "system:catalog": return fail("UNAUTHORIZED")
            if types.has(p["type_id"]): return fail("TYPE_EXISTS")
            if p["actions"].size() > 128: return fail("INVALID_ACTIONS")
            var seen: Dictionary = {}
            for action in p["actions"]:
                if not ident(action) or seen.has(action): return fail("INVALID_ACTIONS")
                seen[action] = true
            return {"ok": true, "effect": {"type_id": p["type_id"]}}
        "home.object.grant", "home.object.acquire":
            var buy: bool = kind == "home.object.acquire"
            if not exact(p, ["object_id", "type_id", "transaction_id"] if buy else ["object_id", "type_id"]):
                return fail("INVALID_PAYLOAD")
            if not ident(p.get("object_id")) or not ident(p.get("type_id")): return fail("INVALID_PAYLOAD")
            if not types.has(p["type_id"]): return fail("UNKNOWN_TYPE")
            if objects.has(p["object_id"]): return fail("OBJECT_EXISTS")
            if buy and actor != "player" or not buy and actor != "system:bootstrap":
                return fail("UNAUTHORIZED")
            var effect: Dictionary = {"object_id": p["object_id"], "type_id": p["type_id"]}
            if buy and int(types[p["type_id"]]["price_minor"]) > 0:
                if not ident(p.get("transaction_id")): return fail("INVALID_PAYLOAD")
                effect["transfer"] = {"transaction_id": p["transaction_id"], "from_account": "player",
                    "to_account": "world:vendors", "amount_minor": types[p["type_id"]]["price_minor"],
                    "cause_id": "object:" + p["object_id"]}
            return {"ok": true, "effect": effect}
        "home.object.place":
            if not exact(p, ["object_id", "unit_id", "slot_id"]) or not ident(p.get("object_id")) or not ident(p.get("unit_id")) or not ident(p.get("slot_id")):
                return fail("INVALID_PAYLOAD")
            if actor != "player": return fail("UNAUTHORIZED")
            if not objects.has(p["object_id"]): return fail("UNKNOWN_OBJECT")
            if not objects[p["object_id"]]["unit_id"].is_empty(): return fail("OBJECT_NOT_STORED")
            if not allowed(p["unit_id"]): return fail("ACCESS_DENIED")
            if not _player_here(p["unit_id"], society): return fail("PLAYER_ABSENT")
            if not _slot_available(p["unit_id"], p["slot_id"]): return fail("SLOT_OCCUPIED")
            return {"ok": true, "effect": {"object_id": p["object_id"]}}
        "home.object.store":
            if not exact(p, ["object_id"]) or not ident(p.get("object_id")): return fail("INVALID_PAYLOAD")
            if actor != "player": return fail("UNAUTHORIZED")
            if not objects.has(p["object_id"]): return fail("UNKNOWN_OBJECT")
            var place: String = objects[p["object_id"]]["unit_id"]
            if place.is_empty(): return fail("OBJECT_ALREADY_STORED")
            if not allowed(place) or not _player_here(place, society): return fail("ACCESS_DENIED")
            return {"ok": true, "effect": {"object_id": p["object_id"]}}
        "home.object.interact":
            if not exact(p, ["object_id", "action_id"]) or not ident(p.get("object_id")) or not ident(p.get("action_id")):
                return fail("INVALID_PAYLOAD")
            if actor != "player": return fail("UNAUTHORIZED")
            if not objects.has(p["object_id"]): return fail("UNKNOWN_OBJECT")
            var item: Dictionary = objects[p["object_id"]]
            if p["action_id"] not in types[item["type_id"]]["actions"]: return fail("INVALID_ACTION")
            if item["unit_id"].is_empty() or not allowed(item["unit_id"]) or not _player_here(item["unit_id"], society):
                return fail("ACCESS_DENIED")
            if item["use_count"] >= LIMIT: return fail("COUNTER_OVERFLOW")
            return {"ok": true, "effect": {"object_id": p["object_id"], "action_id": p["action_id"]}}
    return fail("UNKNOWN_COMMAND")

static func _due_job(id: String, due: int, repeat: int, seq: int, actor: String, command_id: String) -> Dictionary:
    return {"job_id": id, "due_minute": due, "priority": 400,
        "topic": "housing.rent.due", "data": {"lease_id": id.trim_prefix("housing:due:")},
        "every_minutes": repeat, "created_sequence": seq, "source_actor_id": actor,
        "source_command_id": command_id, "status": "pending",
        "execution_count": 0, "last_fire_id": ""}

func apply_command(kind: String, p: Dictionary, effect: Dictionary, minute: int, event_id: String,
        seq: int, actor: String, command_id: String, jobs: Dictionary) -> void:
    match kind:
        "housing.unit.register":
            units[p["unit_id"]] = {"unit_id": p["unit_id"], "location_id": p["location_id"],
                "kind": p["kind"], "area_sqm": int(p["area_sqm"]),
                "rent_minor": int(p["rent_minor"]), "period_minutes": int(p["period_minutes"]),
                "active_lease_id": "", "event_id": event_id}
        "housing.roof.grant":
            roof_rights[p["unit_id"]] = {"unit_id": p["unit_id"], "event_id": event_id}
        "housing.lease.start":
            var u: Dictionary = units[p["unit_id"]]
            u["active_lease_id"] = p["lease_id"]
            leases[p["lease_id"]] = {"lease_id": p["lease_id"], "unit_id": p["unit_id"],
                "rent_minor": u["rent_minor"], "period_minutes": u["period_minutes"],
                "started_minute": minute, "start_event_id": event_id,
                "status": "active", "dues_owed": 0, "dues_assessed": 0,
                "dues_paid": 1, "job_id": effect["job_id"]}
            jobs[effect["job_id"]] = _due_job(effect["job_id"], int(effect["due_minute"]),
                int(u["period_minutes"]), seq, actor, command_id)
        "housing.rent.pay":
            var lease: Dictionary = leases[p["lease_id"]]
            lease["dues_owed"] -= 1
            lease["dues_paid"] += 1
        "housing.lease.end":
            var lease: Dictionary = leases[p["lease_id"]]
            lease["status"] = "ended"
            units[lease["unit_id"]]["active_lease_id"] = ""
            if jobs[lease["job_id"]]["status"] == "pending":
                jobs[lease["job_id"]]["status"] = "cancelled"
        "home.type.define":
            types[p["type_id"]] = {"type_id": p["type_id"],
                "price_minor": int(p["price_minor"]), "actions": p["actions"].duplicate(true),
                "event_id": event_id}
        "home.object.grant", "home.object.acquire":
            objects[p["object_id"]] = {"object_id": p["object_id"], "type_id": p["type_id"],
                "unit_id": "", "slot_id": "", "acquired_event_id": event_id,
                "last_action": "", "last_action_event_id": "", "use_count": 0}
        "home.object.place":
            objects[p["object_id"]]["unit_id"] = p["unit_id"]
            objects[p["object_id"]]["slot_id"] = p["slot_id"]
        "home.object.store":
            objects[p["object_id"]]["unit_id"] = ""
            objects[p["object_id"]]["slot_id"] = ""
        "home.object.interact":
            var obj: Dictionary = objects[p["object_id"]]
            obj["use_count"] += 1
            obj["last_action"] = p["action_id"]
            obj["last_action_event_id"] = event_id

func _simulate_fires(fires: Array) -> Array:
    var outcomes: Array = []
    for fire in fires:
        if fire["topic"] != "housing.rent.due": continue
        var lease_id: String = fire["data"]["lease_id"]
        var lease: Dictionary = leases[lease_id]
        if lease["status"] != "active": continue
        lease["dues_owed"] += 1
        lease["dues_assessed"] += 1
        var occurrence: String = "schedule:" + fire["job_id"] + ":" + str(fire["occurrence"])
        var outcome: Dictionary = {"lease_id": lease_id, "unit_id": lease["unit_id"],
            "at_minute": fire["world_minute"], "outcome": "rent_due",
            "cause_id": occurrence, "dues_owed": lease["dues_owed"]}
        due_log.append(outcome)
        outcomes.append(outcome.duplicate(true))
    return outcomes

func project_firings(fires: Array) -> Array:
    return copy_domain()._simulate_fires(fires)

func apply_firings(fires: Array) -> void:
    _simulate_fires(fires)
