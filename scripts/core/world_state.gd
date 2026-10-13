extends RefCounted
## SYS P0/P1 canonical event reducer. No scene or dialogue runtime owns time.
const Clock = preload("res://scripts/core/world_clock.gd")
const Scheduler = preload("res://scripts/core/world_scheduler.gd")
const VERSION: int = 2
const MAX_INT_JSON: int = 2147483647

var seed: int = 1
var world_minute: int = 0
var sequence: int = 0
var paused: bool = false
var minutes_per_step: int = 1
var jobs: Dictionary = {}
var acknowledgements: Dictionary = {}
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
            return {"ok": true, "effect": {"to_minute": target["target"], "fires": fires["fires"]}}
        "schedule.create":
            if not _exact_keys(payload, ["job_id", "due_minute", "priority", "topic", "data", "every_minutes"]):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if not valid_identity(payload["job_id"]) or not valid_identity(payload["topic"]):
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
    if raw != expected:
        return false
    sequence = int(next_seq)
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
        "facts": facts.duplicate(true), "receipts": receipts.duplicate(true),
        "events": events.duplicate(true)
    }
