extends RefCounted
## SYS P0 public command boundary. Future domain systems register commands in
## this world authority, not a second timer, ledger or Ink side effect.

const WorldState = preload("res://scripts/core/world_state.gd")

var _state: RefCounted

func _init(world_seed: int = 1) -> void:
    _state = WorldState.new(world_seed)

func view() -> Dictionary:
    return _state.snapshot()

func has_fact(fact_id: String) -> bool:
    return _state.facts.get(fact_id, false) == true

func event_history_after(revision: int) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for e in _state.events:
        if int(e["sequence"]) > revision:
            out.append(e.duplicate(true))
    return out

func _rejected(code: String) -> Dictionary:
    return {"ok": false, "code": code}

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
    if kind != "knowledge.grant":
        return _rejected("UNKNOWN_COMMAND")
    var fact_id: Variant = payload.get("fact_id")
    if payload.size() != 1 or not WorldState.valid_identity(fact_id):
        return _rejected("INVALID_PAYLOAD")
    var signature: String = WorldState.signature(actor, fact_id)
    if _state.receipts.has(id):
        var existing: Dictionary = _state.receipts[id]
        if existing["signature"] != signature:
            return _rejected("ID_CONFLICT")
        return (existing["result"] as Dictionary).duplicate(true)
    if _state.facts.has(fact_id):
        return _rejected("ALREADY_KNOWN")
    if _state.sequence >= WorldState.MAX_INT_JSON:
        return _rejected("SEQUENCE_EXHAUSTED")
    var number: int = _state.sequence + 1
    var event: Dictionary = {
        "sequence": number, "world_minute": _state.world_minute,
        "event_id": "evt:%012d" % number, "kind": "knowledge.granted",
        "command_id": id, "actor_id": actor, "payload": {"fact_id": fact_id}
    }
    if not _state._apply_event(event):
        return _rejected("STATE_REJECTED")
    return (_state.receipts[id]["result"] as Dictionary).duplicate(true)

func restore_snapshot(data: Dictionary) -> bool:
    if data.size() != 7:
        return false
    if not WorldState.integral(data.get("version"), 1) or int(data["version"]) != WorldState.VERSION:
        return false
    if not WorldState.integral(data.get("seed"), 1):
        return false
    if not WorldState.integral(data.get("world_minute")) or int(data["world_minute"]) != 0:
        # P0 deliberately has no clock advances. P1 must version the schema to add them.
        return false
    if not WorldState.integral(data.get("sequence")):
        return false
    if typeof(data.get("events")) != TYPE_ARRAY or typeof(data.get("receipts")) != TYPE_DICTIONARY or typeof(data.get("facts")) != TYPE_DICTIONARY:
        return false
    var candidate: RefCounted = WorldState.new(int(data["seed"]))
    for raw in data["events"]:
        if typeof(raw) != TYPE_DICTIONARY:
            print("SYS_P0_RESTORE_DIAG: non-dict event")
            return false
        if not candidate._apply_event(raw):
            print("SYS_P0_RESTORE_DIAG: rejected event ", JSON.stringify(raw))
            return false
    if candidate.sequence != int(data["sequence"]):
        return false
    if candidate.facts != data["facts"]:
        print("SYS_P0_RESTORE_DIAG: fact projection mismatch ", JSON.stringify(candidate.facts), " | ", JSON.stringify(data["facts"]))
        return false
    if candidate.receipts != data["receipts"]:
        print("SYS_P0_RESTORE_DIAG: receipt projection mismatch ", JSON.stringify(candidate.receipts), " | ", JSON.stringify(data["receipts"]))
        return false
    _state = candidate # Atomic swap after full replay/validation.
    return true

func save_to_file(path: String) -> bool:
    var temp: String = path + ".tmp"
    var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(view()))
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
