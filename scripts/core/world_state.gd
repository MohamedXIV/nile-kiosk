extends RefCounted
## SYS P0–P5 canonical event reducer. No scene or dialogue runtime owns time.
const Clock = preload("res://scripts/core/world_clock.gd")
const Scheduler = preload("res://scripts/core/world_scheduler.gd")
const NpcWorld = preload("res://scripts/core/npc_world.gd")
const CookingWorld = preload("res://scripts/core/cooking_world.gd")
const OrderWorld = preload("res://scripts/core/order_world.gd")
const EconomyWorld = preload("res://scripts/core/economy_world.gd")
const HousingWorld = preload("res://scripts/core/housing_world.gd")
const VERSION: int = 6
const MAX_INT_JSON: int = 2147483647

var seed: int = 1
var world_minute: int = 0
var sequence: int = 0
var paused: bool = false
var minutes_per_step: int = 1
var jobs: Dictionary = {}
var acknowledgements: Dictionary = {}
var society: RefCounted = NpcWorld.new()
var cooking: RefCounted = CookingWorld.new()
var service: RefCounted = OrderWorld.new()
var economy: RefCounted = EconomyWorld.new()
var housing: RefCounted = HousingWorld.new()
var facts: Dictionary = {}
var receipts: Dictionary = {}
var events: Array[Dictionary] = []

func _init(world_seed: int = 1) -> void:
    seed = world_seed

static func valid_identity(value: Variant) -> bool:
    return typeof(value) == TYPE_STRING and not (value as String).strip_edges().is_empty() and (value as String).length() <= 128

static func integral(value: Variant, minimum: int = 0, maximum: int = MAX_INT_JSON) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    var as_float: float = float(value)
    return is_finite(as_float) and as_float >= float(minimum) and as_float <= float(maximum) and as_float == float(int(value))

static func signature(actor_id: String, fact_id: String) -> String:
    return JSON.stringify(["knowledge.grant", actor_id, fact_id])

static func _canonical(value: Variant) -> Variant:
    if typeof(value) == TYPE_DICTIONARY:
        var sorted: Dictionary = {}
        var keys: Array = value.keys()
        keys.sort()
        for key in keys:
            sorted[key] = _canonical(value[key])
        return sorted
    if typeof(value) == TYPE_ARRAY:
        var values: Array = []
        for child in value:
            values.append(_canonical(child))
        return values
    if typeof(value) == TYPE_FLOAT and is_finite(value) and value == float(int(value)) and absf(value) <= float(MAX_INT_JSON):
        return int(value)
    return value

static func matching_json(actual: Variant, expected: Variant) -> bool:
    # Godot JSON parses some integral numeric tokens as floats. The reducer
    # normalizes them without relaxing structure, type or fractional checks.
    if typeof(expected) == TYPE_INT:
        return integral(actual, -MAX_INT_JSON) and int(actual) == expected
    if typeof(actual) != typeof(expected):
        return false
    if typeof(expected) == TYPE_DICTIONARY:
        if actual.size() != expected.size():
            return false
        for key in expected:
            if not actual.has(key) or not matching_json(actual[key], expected[key]):
                return false
        return true
    if typeof(expected) == TYPE_ARRAY:
        if actual.size() != expected.size():
            return false
        for i in range(expected.size()):
            if not matching_json(actual[i], expected[i]):
                return false
        return true
    return actual == expected

static func command_signature(kind: String, actor: String, payload: Dictionary) -> String:
    if kind == "knowledge.grant":
        return signature(actor, payload["fact_id"])
    return JSON.stringify([kind, actor, _canonical(payload)])

static func _json_value(value: Variant, depth: int = 0) -> bool:
    if depth > 8:
        return false
    match typeof(value):
        TYPE_NIL, TYPE_BOOL:
            return true
        TYPE_STRING:
            return (value as String).length() <= 4096
        TYPE_INT:
            return value >= -MAX_INT_JSON and value <= MAX_INT_JSON
        TYPE_FLOAT:
            return is_finite(value) and absf(value) <= float(MAX_INT_JSON)
        TYPE_ARRAY:
            if value.size() > 128:
                return false
            for item in value:
                if not _json_value(item, depth + 1):
                    return false
            return true
        TYPE_DICTIONARY:
            if value.size() > 128:
                return false
            for key in value:
                if not valid_identity(key) or not _json_value(value[key], depth + 1):
                    return false
            return true
    return false

static func _exact_keys(value: Dictionary, expected: Array) -> bool:
    if value.size() != expected.size():
        return false
    for key in expected:
        if not value.has(key):
            return false
    return true

static func _event_kind(command_kind: String) -> String:
    if EconomyWorld.owns(command_kind):
        return EconomyWorld.event_kind(command_kind)
    if HousingWorld.owns(command_kind):
        return HousingWorld.event_kind(command_kind)
    if OrderWorld.owns(command_kind):
        return OrderWorld.event_kind(command_kind)
    if CookingWorld.command(command_kind):
        return CookingWorld.event_kind(command_kind)
    if NpcWorld.is_domain_command(command_kind):
        return NpcWorld.event_kind(command_kind)
    match command_kind:
        "knowledge.grant": return "knowledge.granted"
        "time.advance": return "time.advanced"
        "time.pause": return "time.paused"
        "time.resume": return "time.resumed"
        "time.rate.set": return "time.rate_changed"
        "schedule.create": return "schedule.created"
        "schedule.cancel": return "schedule.cancelled"
        "schedule.reschedule": return "schedule.rescheduled"
        "schedule.ack": return "schedule.acknowledged"
    return ""

static func _command_kind(event_kind: String) -> String:
    var economy_command: String = EconomyWorld.command_kind(event_kind)
    if not economy_command.is_empty(): return economy_command
    var housing_command: String = HousingWorld.command_kind(event_kind)
    if not housing_command.is_empty(): return housing_command
    var order_command: String = OrderWorld.command_kind(event_kind)
    if not order_command.is_empty():
        return order_command
    var cook_command: String = CookingWorld.command_kind(event_kind)
    if not cook_command.is_empty():
        return cook_command
    var npc_command: String = NpcWorld.command_kind(event_kind)
    if not npc_command.is_empty():
        return npc_command
    match event_kind:
        "knowledge.granted": return "knowledge.grant"
        "time.advanced": return "time.advance"
        "time.paused": return "time.pause"
        "time.resumed": return "time.resume"
        "time.rate_changed": return "time.rate.set"
        "schedule.created": return "schedule.create"
        "schedule.cancelled": return "schedule.cancel"
        "schedule.rescheduled": return "schedule.reschedule"
        "schedule.acknowledged": return "schedule.ack"
    return ""

func _find_fire(fire_id: String) -> bool:
    for event in events:
        if event["kind"] != "time.advanced":
            continue
        for fire in event["payload"]["effect"]["fires"]:
            if fire["fire_id"] == fire_id:
                return true
    return false

func plan(kind: String, payload: Dictionary, actor_id: String) -> Dictionary:
    if EconomyWorld.owns(kind):
        return economy.plan(kind, payload, actor_id, service, cooking)
    if HousingWorld.owns(kind):
        var planned: Dictionary = housing.plan(kind, payload, actor_id, society, economy, jobs, world_minute)
        if not planned.get("ok", false): return planned
        if planned["effect"].has("transfer"):
            var checked: Dictionary = economy.plan_transfer(planned["effect"]["transfer"])
            if not checked.get("ok", false): return checked
            planned["effect"]["transfer"] = checked["effect"]
        return planned
    if OrderWorld.owns(kind):
        return service.plan(kind, payload, actor_id, society, cooking, jobs, world_minute)
    if CookingWorld.command(kind):
        return cooking.plan(kind, payload, actor_id, jobs, world_minute)
    if NpcWorld.is_domain_command(kind):
        var result: Dictionary = society.plan(kind, payload, actor_id, jobs, world_minute)
        if not result.get("ok", false):
            return result
        var departing_id: String = ""
        if kind == "npc.move" and society.npcs[payload["npc_id"]]["location_id"] != payload["location_id"]:
            departing_id = payload["npc_id"]
        if kind == "npc.visit.interrupt":
            departing_id = payload["npc_id"]
        if kind == "npc.routine.cancel":
            var rid: String = payload["routine_id"]
            var owner: String = society.routines[rid]["npc_id"]
            if society.npcs[owner]["routine_id"] == rid:
                departing_id = owner
        var changes: Array = []
        if not departing_id.is_empty():
            var predicted: RefCounted = service.duplicate_domain()
            changes = predicted.departing(departing_id, world_minute, "evt:%012d" % (sequence + 1), jobs.duplicate(true))
        result["effect"]["departing_npc_id"] = departing_id
        result["effect"]["abandoned_orders"] = changes
        return result
    if _event_kind(kind).is_empty():
        return {"ok": false, "code": "UNKNOWN_COMMAND"}
    match kind:
        "knowledge.grant":
            if not _exact_keys(payload, ["fact_id"]) or not valid_identity(payload.get("fact_id")):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if facts.has(payload["fact_id"]):
                return {"ok": false, "code": "ALREADY_KNOWN"}
            return {"ok": true, "effect": {"fact_id": payload["fact_id"]}}
        "time.pause", "time.resume":
            if not payload.is_empty():
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if kind == "time.pause" and paused:
                return {"ok": false, "code": "ALREADY_PAUSED"}
            if kind == "time.resume" and not paused:
                return {"ok": false, "code": "NOT_PAUSED"}
            return {"ok": true, "effect": {"paused": kind == "time.pause"}}
        "time.rate.set":
            if not _exact_keys(payload, ["minutes_per_step"]) or not integral(payload.get("minutes_per_step"), 1, Clock.MAX_RATE):
                return {"ok": false, "code": "INVALID_RATE"}
            return {"ok": true, "effect": {"minutes_per_step": int(payload["minutes_per_step"])}}
        "time.advance":
            if not _exact_keys(payload, ["steps"]) or not integral(payload.get("steps")):
                return {"ok": false, "code": "INVALID_TIME"}
            if paused:
                return {"ok": false, "code": "PAUSED"}
            var target: Dictionary = Clock.advance_target(world_minute, int(payload["steps"]), minutes_per_step)
            if not target["ok"]:
                return target
            var fires: Dictionary = Scheduler.plan(jobs, target["target"], sequence + 1)
            if not fires["ok"]:
                return fires
            return {"ok": true, "effect": {
                "to_minute": target["target"], "fires": fires["fires"],
                "npc_outcomes": society.project_firings(fires["fires"]),
                "cooking_outcomes": cooking.project_firings(fires["fires"], jobs),
                "order_outcomes": service.project_firings(fires["fires"], society, jobs),
                "housing_outcomes": housing.project_firings(fires["fires"])
            }}
        "schedule.create":
            if not _exact_keys(payload, ["job_id", "due_minute", "priority", "topic", "data", "every_minutes"]):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if not valid_identity(payload["job_id"]) or not valid_identity(payload["topic"]):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            # Domain-owned firings can only be created as part of a verified NPC command.
            if (payload["topic"] as String).begins_with("npc.visit.") or (payload["job_id"] as String).begins_with("npc:") or (payload["topic"] as String).begins_with("cook.") or (payload["job_id"] as String).begins_with("cook:") or payload["topic"] == "order.deadline" or (payload["job_id"] as String).begins_with("order:") or payload["topic"] == "housing.rent.due" or (payload["job_id"] as String).begins_with("housing:"):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if not integral(payload["due_minute"], 1) or int(payload["due_minute"]) <= world_minute:
                return {"ok": false, "code": "INVALID_DUE_TIME"}
            if not integral(payload["priority"], 0, 1000) or not integral(payload["every_minutes"]):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if typeof(payload["data"]) != TYPE_DICTIONARY or not _json_value(payload["data"]):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if jobs.has(payload["job_id"]):
                return {"ok": false, "code": "JOB_ID_CONFLICT"}
            return {"ok": true, "effect": {"job_id": payload["job_id"]}}
        "schedule.cancel":
            if not _exact_keys(payload, ["job_id"]) or not valid_identity(payload.get("job_id")):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if not jobs.has(payload["job_id"]) or jobs[payload["job_id"]]["status"] != "pending":
                return {"ok": false, "code": "JOB_NOT_PENDING"}
            if (payload["job_id"] as String).begins_with("npc:") or (payload["job_id"] as String).begins_with("cook:") or (payload["job_id"] as String).begins_with("order:") or (payload["job_id"] as String).begins_with("housing:"):
                return {"ok": false, "code": "DOMAIN_OWNED_JOB"}
            return {"ok": true, "effect": {"job_id": payload["job_id"]}}
        "schedule.reschedule":
            if not _exact_keys(payload, ["job_id", "due_minute", "priority"]) or not valid_identity(payload.get("job_id")):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if not integral(payload.get("due_minute"), 1) or int(payload["due_minute"]) <= world_minute:
                return {"ok": false, "code": "INVALID_DUE_TIME"}
            if not integral(payload.get("priority"), 0, 1000):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if not jobs.has(payload["job_id"]) or jobs[payload["job_id"]]["status"] != "pending":
                return {"ok": false, "code": "JOB_NOT_PENDING"}
            if (payload["job_id"] as String).begins_with("npc:") or (payload["job_id"] as String).begins_with("cook:") or (payload["job_id"] as String).begins_with("order:") or (payload["job_id"] as String).begins_with("housing:"):
                return {"ok": false, "code": "DOMAIN_OWNED_JOB"}
            return {"ok": true, "effect": {"job_id": payload["job_id"]}}
        "schedule.ack":
            if not _exact_keys(payload, ["consumer_id", "fire_id"]) or not valid_identity(payload.get("consumer_id")) or not valid_identity(payload.get("fire_id")):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if not _find_fire(payload["fire_id"]):
                return {"ok": false, "code": "FIRE_NOT_FOUND"}
            if acknowledgements.get(payload["consumer_id"], {}).has(payload["fire_id"]):
                return {"ok": false, "code": "ALREADY_ACKNOWLEDGED"}
            return {"ok": true, "effect": {"consumer_id": payload["consumer_id"], "fire_id": payload["fire_id"]}}
    return {"ok": false, "code": "UNKNOWN_COMMAND"}

func _apply_event(raw: Dictionary) -> bool:
    if raw.size() != 7:
        return false
    var next_seq: Variant = raw.get("sequence")
    var at: Variant = raw.get("world_minute")
    if not integral(next_seq, 1) or int(next_seq) != sequence + 1:
        return false
    if not integral(at) or int(at) != world_minute:
        return false
    var command_id: Variant = raw.get("command_id")
    var actor_id: Variant = raw.get("actor_id")
    var kind: String = _command_kind(str(raw.get("kind", "")))
    if not valid_identity(command_id) or not valid_identity(actor_id) or kind.is_empty() or receipts.has(command_id):
        return false
    var value: Variant = raw.get("payload")
    if typeof(value) != TYPE_DICTIONARY:
        return false
    var request: Dictionary
    if kind == "knowledge.grant":
        request = value
    else:
        if not _exact_keys(value, ["request", "effect"]) or typeof(value["request"]) != TYPE_DICTIONARY:
            return false
        request = value["request"]
    request = _canonical(request)
    var planned: Dictionary = plan(kind, request, actor_id)
    if not planned.get("ok", false) or (kind == "time.advance" and int(request["steps"]) == 0):
        return false
    var event_payload: Dictionary = request.duplicate(true) if kind == "knowledge.grant" else {"request": request.duplicate(true), "effect": planned["effect"].duplicate(true)}
    var expected: Dictionary = {
        "sequence": int(next_seq), "world_minute": world_minute,
        "event_id": "evt:%012d" % int(next_seq), "kind": _event_kind(kind),
        "command_id": command_id, "actor_id": actor_id, "payload": event_payload
    }
    if not matching_json(raw, expected):
        return false
    sequence = int(next_seq)
    if EconomyWorld.owns(kind):
        economy.apply_command(kind, request, planned["effect"], expected["event_id"], world_minute, service)
    if HousingWorld.owns(kind):
        if planned["effect"].has("transfer"):
            economy.apply_transfer(planned["effect"]["transfer"], expected["event_id"], world_minute, kind)
        housing.apply_command(kind, request, planned["effect"], world_minute, expected["event_id"], sequence, actor_id, command_id, jobs)
    if OrderWorld.owns(kind):
        service.apply_command(kind, request, planned["effect"], world_minute, expected["event_id"], sequence, actor_id, command_id, jobs, cooking)
    if CookingWorld.command(kind):
        cooking.apply_command(kind, request, planned["effect"], world_minute, expected["event_id"], sequence, actor_id, command_id, jobs)
    if NpcWorld.is_domain_command(kind):
        if not planned["effect"]["departing_npc_id"].is_empty():
            service.departing(planned["effect"]["departing_npc_id"], world_minute, expected["event_id"], jobs)
        society.apply_command(kind, request, planned["effect"], world_minute, expected["event_id"], sequence, actor_id, command_id, jobs)
    match kind:
        "knowledge.grant":
            facts[request["fact_id"]] = true
        "time.pause", "time.resume":
            paused = planned["effect"]["paused"]
        "time.rate.set":
            minutes_per_step = int(request["minutes_per_step"])
        "schedule.create":
            jobs[request["job_id"]] = {
                "job_id": request["job_id"], "due_minute": int(request["due_minute"]),
                "priority": int(request["priority"]), "topic": request["topic"],
                "data": request["data"].duplicate(true), "every_minutes": int(request["every_minutes"]),
                "created_sequence": sequence, "source_actor_id": actor_id,
                "source_command_id": command_id, "status": "pending",
                "execution_count": 0, "last_fire_id": ""
            }
        "schedule.cancel":
            jobs[request["job_id"]]["status"] = "cancelled"
        "schedule.reschedule":
            jobs[request["job_id"]]["due_minute"] = int(request["due_minute"])
            jobs[request["job_id"]]["priority"] = int(request["priority"])
        "schedule.ack":
            if not acknowledgements.has(request["consumer_id"]):
                acknowledgements[request["consumer_id"]] = {}
            acknowledgements[request["consumer_id"]][request["fire_id"]] = true
        "time.advance":
            for fire in planned["effect"]["fires"]:
                var job: Dictionary = jobs[fire["job_id"]]
                job["execution_count"] += 1
                job["last_fire_id"] = fire["fire_id"]
                if job["every_minutes"] == 0 or job["every_minutes"] > MAX_INT_JSON - job["due_minute"]:
                    job["status"] = "completed"
                else:
                    job["due_minute"] += job["every_minutes"]
            service.apply_firings(planned["effect"]["fires"], society, jobs)
            society.apply_firings(planned["effect"]["fires"])
            cooking.apply_firings(planned["effect"]["fires"], jobs)
            housing.apply_firings(planned["effect"]["fires"])
            world_minute = int(planned["effect"]["to_minute"])
    events.append(expected)
    receipts[command_id] = {
        "signature": command_signature(kind, actor_id, request),
        "result": {"ok": true, "code": "APPLIED", "event_id": expected["event_id"], "revision": sequence}
    }
    return true

func snapshot() -> Dictionary:
    return {
        "version": VERSION, "seed": seed, "world_minute": world_minute,
        "sequence": sequence, "paused": paused, "minutes_per_step": minutes_per_step,
        "jobs": jobs.duplicate(true), "acknowledgements": acknowledgements.duplicate(true),
        "society": society.snapshot(), "cooking": cooking.snapshot(), "service": service.snapshot(),
        "economy": economy.snapshot(), "housing": housing.snapshot(),
        "facts": facts.duplicate(true), "receipts": receipts.duplicate(true),
        "events": events.duplicate(true)
    }
