extends RefCounted
## Sole public production command/time/scheduling boundary (SYS P0–P6).
const WorldState = preload("res://scripts/core/world_state.gd")
const Clock = preload("res://scripts/core/world_clock.gd")

var _state: RefCounted
var last_restore_was_migration: bool = false

func _init(world_seed: int = 1) -> void:
    _state = WorldState.new(world_seed)

func view() -> Dictionary:
    return _state.snapshot()

func calendar() -> Dictionary:
    return Clock.at(_state.world_minute)

func npc(npc_id: String) -> Dictionary:
    return _state.society.npcs.get(npc_id, {}).duplicate(true)

func npc_routines() -> Dictionary:
    return _state.society.routines.duplicate(true)

func player_knows(fact_id: String) -> bool:
    return _state.society.knowledge.get("player", {}).has(fact_id)

func narrative_view() -> Dictionary:
    return _state.narrative.snapshot()

func narrative_opportunities() -> Dictionary:
    return _state.narrative.opportunities.duplicate(true)

func narrative_session(session_id: String) -> Dictionary:
    return _state.narrative.sessions.get(session_id, {}).duplicate(true)

func narrative_choices(session_id: String) -> Array[Dictionary]:
    return _state.narrative.available(session_id, _state.society)

func needs_view() -> Dictionary:
    return _state.needs.snapshot()

func economy_view() -> Dictionary:
    return _state.economy.snapshot()

func balance_minor() -> int:
    return int(_state.economy.accounts["player"])

func housing_view() -> Dictionary:
    return _state.housing.snapshot()

func can_access_unit(unit_id: String) -> bool:
    return _state.housing.allowed(unit_id)

func orders_view() -> Dictionary:
    return _state.service.snapshot()

func service_queue(venue_id: String, route: String) -> Array[Dictionary]:
    return _state.service.queue(venue_id, route)

func order(order_id: String) -> Dictionary:
    return _state.service.orders.get(order_id, {}).duplicate(true)

func cooking_view() -> Dictionary:
    return _state.cooking.snapshot()

func prepared_item(item_id: String) -> Dictionary:
    return _state.cooking.items.get(item_id, {}).duplicate(true)

func prepared_quality(item_id: String) -> Dictionary:
    # Fully deterministic from authenticated item + immutable canonical P3
    # event timestamps. The receipt survives save/replay and item delivery.
    return _state.cooking.item_quality(item_id, _state.events).duplicate(true)

func spatial_view() -> Dictionary:
    return _state.spatial.snapshot()

func social_view() -> Dictionary:
    return _state.society.snapshot()

func has_fact(fact_id: String) -> bool:
    return _state.facts.get(fact_id, false) == true

func event_history_after(revision: int) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for e in _state.events:
        if int(e["sequence"]) > revision:
            out.append(e.duplicate(true))
    return out

func scheduled_events_after(revision: int) -> Array[Dictionary]:
    ## Every firing is an immutable intention with its exact due time and
    ## separate fire_id. Independent consumers can use revision/ACK cursors.
    var out: Array[Dictionary] = []
    for event in _state.events:
        if event["sequence"] <= revision or event["kind"] != "time.advanced":
            continue
        for item in event["payload"]["effect"]["fires"]:
            var fire: Dictionary = item.duplicate(true)
            fire["sequence"] = event["sequence"]
            fire["event_id"] = event["event_id"]
            out.append(fire)
    return out

func unacknowledged_firings(consumer_id: String, topic: String = "") -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    var acked: Dictionary = _state.acknowledgements.get(consumer_id, {})
    for fire in scheduled_events_after(0):
        if not acked.has(fire["fire_id"]) and (topic.is_empty() or fire["topic"] == topic):
            out.append(fire)
    return out

func _rejected(code: String) -> Dictionary:
    return {"ok": false, "code": code}

func advance_time(steps: Variant, command_id: String, actor_id: String = "system:clock") -> Dictionary:
    ## steps are logical simulation steps, NOT frames or real-world seconds.
    return dispatch({"id": command_id, "actor_id": actor_id,
        "kind": "time.advance", "payload": {"steps": steps}})

func dispatch(command: Dictionary) -> Dictionary:
    if not WorldState.integral(_state.seed, 1):
        return _rejected("INVALID_WORLD_SEED")
    var id: Variant = command.get("id")
    var actor: Variant = command.get("actor_id")
    var kind: Variant = command.get("kind")
    var payload: Variant = command.get("payload")
    if not WorldState.valid_identity(id) or not WorldState.valid_identity(actor):
        return _rejected("INVALID_ID")
    if typeof(kind) != TYPE_STRING or typeof(payload) != TYPE_DICTIONARY:
        return _rejected("INVALID_COMMAND")
    if WorldState._event_kind(kind).is_empty():
        return _rejected("UNKNOWN_COMMAND")
    if not WorldState._json_value(payload):
        return _rejected("INVALID_PAYLOAD")
    payload = WorldState._canonical(payload)
    if kind == "knowledge.grant" and not WorldState._exact_keys(payload, ["fact_id"]):
        return _rejected("INVALID_PAYLOAD")
    # Idempotency must be resolved BEFORE re-planning a transition:
    # after an open or a sleep, re-planning the same command would reject.
    if _state.receipts.has(id):
        if _state.receipts[id]["signature"] != WorldState.command_signature(kind, actor, payload):
            return _rejected("ID_CONFLICT")
        return (_state.receipts[id]["result"] as Dictionary).duplicate(true)
    var checked: Dictionary = _state.plan(kind, payload, actor)
    if not checked.get("ok", false):
        return _rejected(checked["code"])
    if kind == "time.advance" and int(payload["steps"]) == 0:
        # A zero advance is a true no-op; it doesn't consume a command ID.
        return {"ok": true, "code": "NO_OP", "revision": _state.sequence, "world_minute": _state.world_minute}
    if _state.sequence >= WorldState.MAX_INT_JSON:
        return _rejected("SEQUENCE_EXHAUSTED")
    var number: int = _state.sequence + 1
    var event_payload: Dictionary = payload.duplicate(true) if kind == "knowledge.grant" else {
        "request": payload.duplicate(true), "effect": checked["effect"].duplicate(true)
    }
    var event: Dictionary = {
        "sequence": number, "world_minute": _state.world_minute,
        "event_id": "evt:%012d" % number, "kind": WorldState._event_kind(kind),
        "command_id": id, "actor_id": actor, "payload": event_payload
    }
    if not _state._apply_event(event):
        return _rejected("STATE_REJECTED")
    return (_state.receipts[id]["result"] as Dictionary).duplicate(true)

static func _matches(actual: Variant, expected: Variant) -> bool:
    ## Godot JSON may deserialize integer tokens as integral floats.
    if typeof(expected) == TYPE_INT:
        return WorldState.integral(actual, -WorldState.MAX_INT_JSON) and int(actual) == expected
    if typeof(actual) != typeof(expected):
        return false
    if typeof(expected) == TYPE_DICTIONARY:
        if actual.size() != expected.size():
            return false
        for key in expected:
            if not actual.has(key) or not _matches(actual[key], expected[key]):
                return false
        return true
    if typeof(expected) == TYPE_ARRAY:
        if actual.size() != expected.size():
            return false
        for i in range(expected.size()):
            if not _matches(actual[i], expected[i]):
                return false
        return true
    return actual == expected

func restore_snapshot(data: Dictionary) -> bool:
    # v7 -> v8 is an explicit full-replay upgrade, not an unchecked field patch.
    last_restore_was_migration = false
    if not WorldState.integral(data.get("version"), 1):
        return false
    var version: int = int(data["version"])
    if version == 11 and data.size() != 20: return false
    if version == 10 and data.size() != 20: return false
    if version == 9 and data.size() != 19: return false
    if version == 8 and data.size() != 18: return false
    if version == 7 and data.size() != 17: return false
    if version not in [7, 8, 9, 10, 11]: return false
    if not WorldState.integral(data.get("seed"), 1) or typeof(data.get("events")) != TYPE_ARRAY:
        return false
    var candidate: RefCounted = WorldState.new(int(data["seed"]))
    for raw in data["events"]:
        if typeof(raw) != TYPE_DICTIONARY or not candidate._apply_event(raw):
            return false
    var expected: Dictionary = candidate.snapshot()
    if version <= 10:
        # v11's rule/outcome projections are deterministic and reconstructable.
        # Older saves genuinely lack them; compare their original shape.
        expected["narrative"].erase("opportunity_rules")
        expected["narrative"].erase("opportunities")
        expected["version"] = version
    if version in [7, 8, 9]:
        # Older saves replay needs from the event log without trusting an invented projection.
        expected.erase("needs")
    if version in [7, 8]:
        # Older saves have no canonical daily-life projection.
        expected.erase("life")
    if version == 8: expected["version"] = 8
    if version == 7:
        # v7 has no spatial events. Every other domain and receipt is replayed.
        if candidate.spatial.initialized(): return false
        expected.erase("spatial")
        expected["version"] = 7
    if not _matches(data, expected):
        return false
    _state = candidate
    last_restore_was_migration = version in [7, 8, 9, 10]
    return true

func save_to_file(path: String) -> bool:
    var temp: String = path + ".tmp"
    var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(view()))
    file.flush()
    file.close()
    var err: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path))
    return err == OK

func load_from_file(path: String) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    return restore_snapshot(parsed)
