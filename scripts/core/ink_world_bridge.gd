extends RefCounted
## Production Ink/inkgd adapter. Ink is text and cursor ONLY; Kernel verifies every effect.
## Loaded InkPlayer instances are independent and are not part of D001 spike state.
var kernel: RefCounted
var sessions: Dictionary = {}

func _init(world_kernel: RefCounted) -> void:
    kernel = world_kernel

func _cursor(player: Node) -> Array:
    var raw: String = player.get_state()
    var parts: Array = []
    for offset in range(0, raw.length(), 4096):
        parts.append(raw.substr(offset, 4096))
    return parts

func _restore_cursor(player: Node, chunks: Array) -> void:
    var raw: String = ""
    for chunk in chunks:
        raw += str(chunk)
    player.set_state(raw)

func _command(id: String, kind: String, payload: Dictionary) -> Dictionary:
    return kernel.dispatch({"id": id, "kind": kind, "payload": payload, "actor_id": "system:narrative"})

func attach(session_id: String, ink_json_path: String) -> bool:
    if sessions.has(session_id) or not FileAccess.file_exists(ink_json_path):
        return false
    var ink_script: GDScript = load("res://addons/inkgd/ink_player.gd")
    var resource_script: GDScript = load("res://addons/inkgd/editor/import_plugins/ink_resource.gd")
    if ink_script == null or resource_script == null: return false
    var player: Node = ink_script.new()
    player.name = "ProductionInk_" + session_id
    player.loads_in_background = false
    var resource: Resource = resource_script.new()
    var json: String = FileAccess.get_file_as_string(ink_json_path)
    if json.is_empty(): return false
    resource.set("json", json)
    player.ink_file = resource
    sessions[session_id] = {"player": player, "ready": false, "failed": false,
        "point_id": "", "story_id": ""}
    player.loaded.connect(_on_loaded.bind(session_id))
    call_deferred("_attach_player", session_id)
    return true

func _attach_player(id: String) -> void:
    var player: Node = sessions[id]["player"]
    (Engine.get_main_loop() as SceneTree).root.add_child(player)
    player.create_story()

func _on_loaded(success: bool, id: String) -> void:
    var s: Dictionary = sessions[id]
    s["failed"] = not success
    if not success: return
    var previous: Dictionary = kernel.narrative_session(id)
    if not previous.is_empty():
        _restore_cursor(s["player"], previous["ink_state"])
        s["story_id"] = previous["story_id"]
        s["point_id"] = previous["point_id"]
    else:
        s["player"].choose_path("start")
    s["ready"] = true

func ready(id: String) -> bool:
    return sessions.has(id) and sessions[id]["ready"]

func begin(id: String, story_id: String, participants: Array, command_id: String) -> Dictionary:
    if not ready(id): return {"ok": false, "code": "INK_NOT_READY"}
    if not kernel.narrative_session(id).is_empty():
        return {"ok": false, "code": "SESSION_EXISTS"}
    var s: Dictionary = sessions[id]
    var result: Dictionary = _command(command_id, "narrative.session.start", {
        "session_id": id, "story_id": story_id,
        "participants": participants, "ink_state": _cursor(s["player"])
    })
    if result.get("ok", false):
        s["story_id"] = story_id
    return result

func _tags(player: Node) -> Dictionary:
    var beat: String = ""
    var point: String = ""
    for tag in player.current_tags:
        var t: String = str(tag).strip_edges()
        if t.begins_with("beat:"): beat = t.trim_prefix("beat:")
        if t.begins_with("point:"): point = t.trim_prefix("point:")
    return {"beat_id": beat, "point_id": point}

func _choices(id: String) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    var allowed: Array[Dictionary] = kernel.narrative_choices(id)
    var player: Node = sessions[id]["player"]
    for option in allowed:
        for i in range(player.current_choices.size()):
            if str(player.current_choices[i].text).strip_edges() == option["text"]:
                out.append({"option_id": option["option_id"], "text": option["text"]})
    return out

func choices(id: String) -> Array[Dictionary]:
    if not ready(id): return []
    return _choices(id)

func advance(id: String, command_id: String) -> Dictionary:
    if not ready(id): return {"ok": false, "code": "INK_NOT_READY"}
    var session: Dictionary = kernel.narrative_session(id)
    if session.is_empty(): return {"ok": false, "code": "UNKNOWN_SESSION"}
    if session["phase"] == "choice":
        return {"ok": true, "code": "WAITING", "choices": _choices(id)}
    if session["phase"] == "finished":
        return {"ok": true, "code": "FINISHED"}
    var local: Dictionary = sessions[id]
    var player: Node = local["player"]
    if player.has_choices:
        var point: String = local["point_id"]
        var result: Dictionary = _command(command_id, "narrative.choice.wait", {
            "session_id": id, "point_id": point, "ink_state": _cursor(player)})
        if result.get("ok", false):
            return {"ok": true, "code": "WAITING", "choices": _choices(id)}
        return result
    if not player.can_continue:
        var finish: Dictionary = _command(command_id, "narrative.session.finish",
            {"session_id": id, "ink_state": _cursor(player)})
        return {"ok": finish.get("ok", false), "code": "FINISHED" if finish.get("ok", false) else finish["code"]}
    var before: Array = _cursor(player)
    var line: String = str(player.continue_story()).strip_edges()
    var tags: Dictionary = _tags(player)
    if not tags["point_id"].is_empty():
        local["point_id"] = tags["point_id"]
    if tags["beat_id"].is_empty():
        _restore_cursor(player, before)
        return {"ok": false, "code": "INK_BEAT_TAG_REQUIRED"}
    var story: Dictionary = kernel.narrative_view()["stories"].get(session["story_id"], {})
    var beat: Dictionary = story.get("beats", {}).get(tags["beat_id"], {})
    if beat.is_empty():
        _restore_cursor(player, before)
        return {"ok": false, "code": "INK_UNKNOWN_BEAT"}
    var mode: String = "broadcast"
    var audience: Array = []
    if not beat["fact_id"].is_empty():
        var fact: Dictionary = kernel.social_view()["social_facts"].get(beat["fact_id"], {})
        if fact.get("visibility") == "trusted":
            mode = "directed"
            audience = ["player"]
    var response: Dictionary = _command(command_id, "narrative.line.commit", {
        "session_id": id, "beat_id": tags["beat_id"], "mode": mode,
        "audience_ids": audience, "ink_state": _cursor(player)
    })
    if not response.get("ok", false):
        _restore_cursor(player, before)
        return response
    var last: Dictionary = kernel.narrative_session(id)["lines"][-1]
    return {"ok": true, "code": "LINE", "text": line, "speaker_id": last["speaker_id"],
        "beat_id": tags["beat_id"], "heard_by": last["heard_by"].duplicate(true)}

func choose(id: String, option_id: String, command_id: String) -> Dictionary:
    if not ready(id): return {"ok": false, "code": "INK_NOT_READY"}
    var session: Dictionary = kernel.narrative_session(id)
    if session.get("phase") != "choice": return {"ok": false, "code": "INVALID_PHASE"}
    var eligible: Array[Dictionary] = _choices(id)
    var option_text: String = ""
    for option in eligible:
        if option["option_id"] == option_id:
            option_text = option["text"]
            break
    if option_text.is_empty(): return {"ok": false, "code": "CHOICE_GATED"}
    var player: Node = sessions[id]["player"]
    var index: int = -1
    for i in range(player.current_choices.size()):
        if str(player.current_choices[i].text).strip_edges() == option_text:
            index = i
            break
    if index < 0: return {"ok": false, "code": "INK_OPTION_MISSING"}
    var before: Array = _cursor(player)
    player.choose_choice_index(index)
    var applied: Dictionary = _command(command_id, "narrative.choice.select", {
        "session_id": id, "point_id": session["point_id"],
        "option_id": option_id, "ink_state": _cursor(player)
    })
    if not applied.get("ok", false):
        _restore_cursor(player, before)
    return applied

func dispose() -> void:
    for state in sessions.values():
        var player: Node = state["player"]
        if is_instance_valid(player):
            player.queue_free()
    sessions.clear()
