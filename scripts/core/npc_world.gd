extends RefCounted
## SYS P2 canonical NPC presence and socially scoped knowledge.
## Domain-only: no Nodes, paths, scenes, Ink or player-centric tick loops.
const DAY_MINUTES: int = 1440
const MAX_TIME: int = 2147483647

var npcs: Dictionary = {}
var routines: Dictionary = {}
var social_facts: Dictionary = {}
var knowledge: Dictionary = {}
var familiarity: Dictionary = {}
var player_location: String = ""

static func valid_id(value: Variant) -> bool:
    return typeof(value) == TYPE_STRING and not (value as String).strip_edges().is_empty() and (value as String).length() <= 128

static func as_int(value: Variant, minimum: int = 0) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    return is_finite(float(value)) and value >= minimum and value <= MAX_TIME and float(value) == float(int(value))

static func exact(payload: Dictionary, keys: Array) -> bool:
    if payload.size() != keys.size():
        return false
    for key in keys:
        if not payload.has(key):
            return false
    return true

static func is_domain_command(kind: String) -> bool:
    return kind in [
        "npc.register", "npc.move", "npc.routine.create", "npc.routine.cancel",
        "npc.visit.interrupt", "social.player.place", "social.familiarity.set",
        "social.fact.register", "social.speak"
    ]

static func event_kind(kind: String) -> String:
    match kind:
        "npc.register": return "npc.registered"
        "npc.move": return "npc.moved"
        "npc.routine.create": return "npc.routine_created"
        "npc.routine.cancel": return "npc.routine_cancelled"
        "npc.visit.interrupt": return "npc.visit_interrupted"
        "social.player.place": return "social.player_placed"
        "social.familiarity.set": return "social.familiarity_changed"
        "social.fact.register": return "social.fact_registered"
        "social.speak": return "social.spoken"
    return ""

static func command_kind(kind: String) -> String:
    match kind:
        "npc.registered": return "npc.register"
        "npc.moved": return "npc.move"
        "npc.routine_created": return "npc.routine.create"
        "npc.routine_cancelled": return "npc.routine.cancel"
        "npc.visit_interrupted": return "npc.visit.interrupt"
        "social.player_placed": return "social.player.place"
        "social.familiarity_changed": return "social.familiarity.set"
        "social.fact_registered": return "social.fact.register"
        "social.spoken": return "social.speak"
    return ""

func snapshot() -> Dictionary:
    return {
        "npcs": npcs.duplicate(true), "routines": routines.duplicate(true),
        "social_facts": social_facts.duplicate(true),
        "knowledge": knowledge.duplicate(true),
        "familiarity": familiarity.duplicate(true),
        "player_location": player_location
    }

func clone_state() -> RefCounted:
    var duplicate_state = get_script().new()
    duplicate_state.npcs = npcs.duplicate(true)
    duplicate_state.routines = routines.duplicate(true)
    duplicate_state.social_facts = social_facts.duplicate(true)
    duplicate_state.knowledge = knowledge.duplicate(true)
    duplicate_state.familiarity = familiarity.duplicate(true)
    duplicate_state.player_location = player_location
    return duplicate_state

func _known(receiver: String, fact_id: String) -> bool:
    return knowledge.get(receiver, {}).has(fact_id)

func _at(receiver: String) -> String:
    if receiver == "player":
        return player_location
    return npcs.get(receiver, {}).get("location_id", "")

func _existing_receiver(receiver: String) -> bool:
    return receiver == "player" or npcs.has(receiver)

func _audience(speaker: String, fact_id: String, mode: String, explicit: Array) -> Array:
    var place: String = _at(speaker)
    var recipients: Array = []
    if mode == "broadcast":
        var everyone: Array = npcs.keys()
        everyone.append("player")
        everyone.sort()
        for person in everyone:
            if person != speaker and _at(person) == place:
                recipients.append(person)
    else:
        recipients = explicit.duplicate()
        recipients.sort()
    # Private facts only reach trusted specifically addressed listeners.
    if social_facts[fact_id]["visibility"] == "trusted":
        for person in recipients:
            if familiarity.get(person, {}).get(speaker, "") != "trusted":
                return []
    return recipients

func plan(kind: String, payload: Dictionary, actor: String, jobs: Dictionary, minute: int) -> Dictionary:
    if not is_domain_command(kind):
        return {"ok": false, "code": "UNKNOWN_COMMAND"}
    match kind:
        "npc.register":
            if not exact(payload, ["npc_id", "location_id"]) or not valid_id(payload.get("npc_id")):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if typeof(payload.get("location_id")) != TYPE_STRING:
                return {"ok": false, "code": "INVALID_LOCATION"}
            if payload["npc_id"] == "player" or npcs.has(payload["npc_id"]):
                return {"ok": false, "code": "NPC_EXISTS"}
            if not knowledge.has(payload["npc_id"]):
                pass
            return {"ok": true, "effect": {"npc_id": payload["npc_id"]}}
        "npc.move":
            if not exact(payload, ["npc_id", "location_id"]) or not valid_id(payload.get("npc_id")) or typeof(payload.get("location_id")) != TYPE_STRING:
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if not npcs.has(payload["npc_id"]):
                return {"ok": false, "code": "UNKNOWN_NPC"}
            if not npcs[payload["npc_id"]]["routine_id"].is_empty():
                return {"ok": false, "code": "NPC_BUSY"}
            return {"ok": true, "effect": {"npc_id": payload["npc_id"]}}
        "npc.routine.create":
            if not exact(payload, ["routine_id", "npc_id", "location_id", "start_minute", "end_minute", "period_minutes"]):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if not valid_id(payload.get("routine_id")) or not valid_id(payload.get("npc_id")) or not valid_id(payload.get("location_id")):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if not npcs.has(payload["npc_id"]):
                return {"ok": false, "code": "UNKNOWN_NPC"}
            if not as_int(payload["start_minute"], minute + 1) or not as_int(payload["end_minute"], minute + 2):
                return {"ok": false, "code": "INVALID_TIME"}
            if int(payload["end_minute"]) <= int(payload["start_minute"]) or not as_int(payload["period_minutes"]):
                return {"ok": false, "code": "INVALID_TIME"}
            if int(payload["period_minutes"]) > 0 and int(payload["period_minutes"]) < int(payload["end_minute"]) - int(payload["start_minute"]):
                return {"ok": false, "code": "OVERLAPPING_PERIOD"}
            var start_id: String = "npc:" + payload["routine_id"] + ":begin"
            var end_id: String = "npc:" + payload["routine_id"] + ":end"
            if routines.has(payload["routine_id"]) or jobs.has(start_id) or jobs.has(end_id):
                return {"ok": false, "code": "ROUTINE_EXISTS"}
            return {"ok": true, "effect": {"job_ids": [start_id, end_id]}}
        "npc.routine.cancel":
            if not exact(payload, ["routine_id"]) or not valid_id(payload.get("routine_id")):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if not routines.has(payload["routine_id"]) or routines[payload["routine_id"]]["status"] != "active":
                return {"ok": false, "code": "ROUTINE_NOT_ACTIVE"}
            return {"ok": true, "effect": {"routine_id": payload["routine_id"]}}
        "npc.visit.interrupt":
            if not exact(payload, ["npc_id", "reason"]) or not valid_id(payload.get("npc_id")) or not valid_id(payload.get("reason")):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if not npcs.has(payload["npc_id"]) or npcs[payload["npc_id"]]["routine_id"].is_empty():
                return {"ok": false, "code": "NO_ACTIVE_VISIT"}
            return {"ok": true, "effect": {"routine_id": npcs[payload["npc_id"]]["routine_id"]}}
        "social.player.place":
            if not exact(payload, ["location_id"]) or typeof(payload.get("location_id")) != TYPE_STRING:
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            return {"ok": true, "effect": {"location_id": payload["location_id"]}}
        "social.familiarity.set":
            if not exact(payload, ["observer_id", "npc_id", "level"]) or not valid_id(payload.get("observer_id")) or not valid_id(payload.get("npc_id")):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if payload.get("level") not in ["unknown", "known", "trusted"]:
                return {"ok": false, "code": "INVALID_LEVEL"}
            if not _existing_receiver(payload["observer_id"]) or not npcs.has(payload["npc_id"]) or payload["observer_id"] == payload["npc_id"]:
                return {"ok": false, "code": "UNKNOWN_PARTICIPANT"}
            return {"ok": true, "effect": {"level": payload["level"]}}
        "social.fact.register":
            if not exact(payload, ["fact_id", "source_npc_id", "visibility"]) or not valid_id(payload.get("fact_id")) or not valid_id(payload.get("source_npc_id")):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if payload.get("visibility") not in ["public", "trusted"]:
                return {"ok": false, "code": "INVALID_VISIBILITY"}
            if not npcs.has(payload["source_npc_id"]):
                return {"ok": false, "code": "UNKNOWN_NPC"}
            if social_facts.has(payload["fact_id"]):
                return {"ok": false, "code": "FACT_EXISTS"}
            return {"ok": true, "effect": {"fact_id": payload["fact_id"]}}
        "social.speak":
            if not exact(payload, ["speaker_id", "fact_id", "mode", "audience_ids"]) or not valid_id(payload.get("speaker_id")) or not valid_id(payload.get("fact_id")):
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            if actor != payload["speaker_id"] or not npcs.has(payload["speaker_id"]):
                return {"ok": false, "code": "INVALID_SPEAKER"}
            if not social_facts.has(payload["fact_id"]) or not _known(actor, payload["fact_id"]):
                return {"ok": false, "code": "FACT_NOT_KNOWN"}
            if _at(actor).is_empty():
                return {"ok": false, "code": "SPEAKER_ABSENT"}
            if payload.get("mode") not in ["broadcast", "directed"] or typeof(payload.get("audience_ids")) != TYPE_ARRAY:
                return {"ok": false, "code": "INVALID_PAYLOAD"}
            var explicit: Array = payload["audience_ids"]
            if explicit.size() > 128 or (payload["mode"] == "broadcast" and not explicit.is_empty()):
                return {"ok": false, "code": "INVALID_AUDIENCE"}
            if payload["mode"] == "directed" and explicit.is_empty():
                return {"ok": false, "code": "INVALID_AUDIENCE"}
            var seen: Dictionary = {}
            for listener in explicit:
                if not valid_id(listener) or listener == actor or seen.has(listener) or not _existing_receiver(listener):
                    return {"ok": false, "code": "INVALID_AUDIENCE"}
                if _at(listener) != _at(actor):
                    return {"ok": false, "code": "AUDIENCE_ABSENT"}
                seen[listener] = true
            if social_facts[payload["fact_id"]]["visibility"] == "trusted":
                if payload["mode"] != "directed":
                    return {"ok": false, "code": "PRIVATE_BROADCAST"}
                for listener in explicit:
                    if familiarity.get(listener, {}).get(actor, "") != "trusted":
                        return {"ok": false, "code": "PRIVACY_DENIED"}
            var listeners: Array = _audience(actor, payload["fact_id"], payload["mode"], explicit)
            return {"ok": true, "effect": {
                "location_id": _at(actor), "heard_by": listeners
            }}
    return {"ok": false, "code": "UNKNOWN_COMMAND"}

func _remember(receiver: String, fact_id: String, speaker: String, at: int, event_id: String) -> void:
    if not knowledge.has(receiver):
        knowledge[receiver] = {}
    if not knowledge[receiver].has(fact_id):
        knowledge[receiver][fact_id] = {
            "source_npc_id": speaker, "heard_minute": at, "event_id": event_id
        }

func _end_visit(npc_id: String) -> void:
    npcs[npc_id]["location_id"] = npcs[npc_id]["base_location_id"]
    npcs[npc_id]["routine_id"] = ""

func apply_command(kind: String, payload: Dictionary, effect: Dictionary, minute: int, event_id: String, sequence: int, actor: String, jobs: Dictionary) -> void:
    match kind:
        "npc.register":
            npcs[payload["npc_id"]] = {
                "npc_id": payload["npc_id"], "base_location_id": payload["location_id"],
                "location_id": payload["location_id"], "routine_id": ""
            }
            knowledge[payload["npc_id"]] = {}
        "npc.move":
            npcs[payload["npc_id"]]["base_location_id"] = payload["location_id"]
            npcs[payload["npc_id"]]["location_id"] = payload["location_id"]
        "npc.routine.create":
            var rid: String = payload["routine_id"]
            var ids: Array = effect["job_ids"]
            routines[rid] = {
                "routine_id": rid, "npc_id": payload["npc_id"],
                "location_id": payload["location_id"], "status": "active",
                "start_job_id": ids[0], "end_job_id": ids[1]
            }
            for index in range(2):
                var is_start: bool = index == 0
                var job_id: String = ids[index]
                jobs[job_id] = {
                    "job_id": job_id,
                    "due_minute": int(payload["start_minute"]) if is_start else int(payload["end_minute"]),
                    "priority": 200 if is_start else 100,
                    "topic": "npc.visit.start" if is_start else "npc.visit.end",
                    "data": {"routine_id": rid, "npc_id": payload["npc_id"], "location_id": payload["location_id"]},
                    "every_minutes": int(payload["period_minutes"]), "created_sequence": sequence,
                    "source_actor_id": actor, "source_command_id": event_id,
                    "status": "pending", "execution_count": 0, "last_fire_id": ""
                }
        "npc.routine.cancel":
            var routine: Dictionary = routines[payload["routine_id"]]
            routine["status"] = "cancelled"
            for id in [routine["start_job_id"], routine["end_job_id"]]:
                if jobs[id]["status"] == "pending":
                    jobs[id]["status"] = "cancelled"
            var person: String = routine["npc_id"]
            if npcs[person]["routine_id"] == routine["routine_id"]:
                _end_visit(person)
        "npc.visit.interrupt":
            _end_visit(payload["npc_id"])
        "social.player.place":
            player_location = payload["location_id"]
        "social.familiarity.set":
            var viewer: String = payload["observer_id"]
            if not familiarity.has(viewer):
                familiarity[viewer] = {}
            familiarity[viewer][payload["npc_id"]] = payload["level"]
        "social.fact.register":
            social_facts[payload["fact_id"]] = {
                "fact_id": payload["fact_id"], "source_npc_id": payload["source_npc_id"],
                "visibility": payload["visibility"], "established_event_id": event_id
            }
            _remember(payload["source_npc_id"], payload["fact_id"], payload["source_npc_id"], minute, event_id)
        "social.speak":
            for listener in effect["heard_by"]:
                _remember(listener, payload["fact_id"], payload["speaker_id"], minute, event_id)

func apply_firing(fire: Dictionary) -> Dictionary:
    if fire["topic"] not in ["npc.visit.start", "npc.visit.end"]:
        return {}
    var data: Dictionary = fire["data"]
    var rid: String = data["routine_id"]
    var npc_id: String = data["npc_id"]
    var result: String = "skipped"
    if routines.has(rid) and npcs.has(npc_id) and routines[rid]["status"] == "active":
        if fire["topic"] == "npc.visit.start":
            if npcs[npc_id]["routine_id"].is_empty():
                npcs[npc_id]["routine_id"] = rid
                npcs[npc_id]["location_id"] = data["location_id"]
                result = "arrived"
            else:
                result = "missed_busy"
        elif npcs[npc_id]["routine_id"] == rid:
            _end_visit(npc_id)
            result = "departed"
    return {"fire_id": fire["fire_id"], "npc_id": npc_id, "routine_id": rid, "outcome": result, "at_minute": fire["world_minute"]}

func project_firings(fires: Array) -> Array:
    var working = clone_state()
    var outcomes: Array = []
    for fire in fires:
        var outcome: Dictionary = working.apply_firing(fire)
        if not outcome.is_empty():
            outcomes.append(outcome)
    return outcomes

func apply_firings(fires: Array) -> void:
    for fire in fires:
        apply_firing(fire)
