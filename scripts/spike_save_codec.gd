extends RefCounted
## D001 spike save contract: canonical world plus candidate-specific session state.
## Saves must round-trip through actual UTF-8 JSON on disk, not just copy references.

const VERSION: int = 1

static func snapshot(model, engine_id: String) -> Dictionary:
    var saved_sessions: Dictionary = {}
    for session_id in ["football", "rumor"]:
        saved_sessions[session_id] = model.sessions[session_id].snapshot()
    return {
        "version": VERSION,
        "engine": engine_id,
        "player_position": {"x": model.player_position.x, "y": model.player_position.y},
        "tick_number": model.tick_number,
        "tea_steps": model.tea_steps,
        "facts": model.game_state.facts.duplicate(true),
        "applied_effects": model.game_state.applied_effects.duplicate(true),
        "events": model.events.duplicate(true),
        "sessions": saved_sessions
    }

static func restore(model, data: Dictionary, engine_id: String) -> bool:
    if int(data.get("version", -1)) != VERSION or data.get("engine", "") != engine_id:
        return false
    if not data.has("sessions") or not data.has("facts") or not data.has("applied_effects"):
        return false
    for id in ["football", "rumor"]:
        if not data.sessions.has(id):
            return false
        if engine_id == "ink" and not model.sessions[id].ready:
            return false
    var position: Dictionary = data.get("player_position", {})
    if not position.has("x") or not position.has("y"):
        return false
    model.player_position = Vector2(float(position.x), float(position.y))
    model.world.tick_number = int(data.get("tick_number", 0))
    model.world.tea_steps = int(data.get("tea_steps", 0))
    model.game_state.facts = (data.facts as Dictionary).duplicate(true)
    model.game_state.applied_effects = (data.applied_effects as Dictionary).duplicate(true)
    model.world.events.clear()
    for entry in data.get("events", []):
        model.world.events.append(entry)
    for id in ["football", "rumor"]:
        model.sessions[id].restore(data.sessions[id])
    return true

static func write_json(path: String, data: Dictionary) -> bool:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("D001 save could not open: " + path)
        return false
    file.store_string(JSON.stringify(data))
    file.close()
    return true

static func read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    return parsed
