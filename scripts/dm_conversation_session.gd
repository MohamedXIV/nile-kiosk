extends RefCounted
## Dialogue Manager-backed independent story cursor; no dialogue balloon or global session.
## Dialogue Manager v3.10.4 pinned for Godot 4.6.3 during P1.

var session_id: String
var resource: Resource
var next_id: String = "start"
var phase: String = "running"
var delay_remaining: float = 0.5
var choice_remaining: float = 0.0
var pending_responses: Array = []
var choice_response: Variant = null
var quiet_response: Variant = null

func _init(id: String, resource_path: String) -> void:
    session_id = id
    resource = load(resource_path)
    if session_id == "rumor":
        delay_remaining = 1.0
    assert(resource != null, "Missing imported Dialogue Manager resource: " + resource_path)

func tick(delta: float, can_interject: bool) -> Array[Dictionary]:
    var emitted: Array[Dictionary] = []
    if phase == "finished":
        return emitted
    if phase == "choice":
        choice_remaining -= delta
        if choice_remaining <= 0.0:
            _take_quiet_branch()
            emitted.append({"kind": "choice_expired", "session": session_id})
        return emitted

    delay_remaining -= delta
    if delay_remaining > 0.0:
        return emitted

    var manager: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("DialogueManager")
    assert(manager != null, "Dialogue Manager singleton has not been installed/enabled")
    var context: Dictionary = {"knows_match": can_interject}
    var line: Variant = await manager.get_next_dialogue_line(resource, next_id, [context])
    if line == null:
        phase = "finished"
        emitted.append({"kind": "finished", "session": session_id})
        return emitted

    next_id = line.next_id
    var fact_id: String = line.get_tag_value("fact")
    emitted.append({
        "kind": "line",
        "session": session_id,
        "speaker": line.character,
        "text": line.text,
        "fact": fact_id
    })

    pending_responses = line.responses
    choice_response = null
    quiet_response = null
    for response in pending_responses:
        if response.text == "Stay quiet.":
            quiet_response = response
        elif response.is_allowed:
            choice_response = response

    if choice_response != null and can_interject:
        phase = "choice"
        choice_remaining = 4.0
        emitted.append({"kind": "choice", "session": session_id, "text": choice_response.text})
    elif quiet_response != null:
        _take_quiet_branch()
    else:
        delay_remaining = 0.5
    return emitted

func choose_interjection() -> Array[Dictionary]:
    var emitted: Array[Dictionary] = []
    if phase != "choice" or choice_response == null:
        return emitted
    next_id = choice_response.next_id
    pending_responses.clear()
    choice_response = null
    quiet_response = null
    phase = "running"
    delay_remaining = 0.5
    emitted.append({"kind": "interjection", "session": session_id, "text": "I watched the match."})
    return emitted

func _take_quiet_branch() -> void:
    assert(quiet_response != null, "Authored 'Stay quiet.' fallback response missing")
    next_id = quiet_response.next_id
    pending_responses.clear()
    choice_response = null
    quiet_response = null
    phase = "running"
    delay_remaining = 0.5

## Persist the *logical* cursor and pending response destinations, never plugin objects.
func snapshot() -> Dictionary:
    return {
        "session_id": session_id,
        "next_id": next_id,
        "phase": phase,
        "delay_remaining": delay_remaining,
        "choice_remaining": choice_remaining,
        "choice_next_id": choice_response.next_id if choice_response != null else "",
        "quiet_next_id": quiet_response.next_id if quiet_response != null else ""
    }

func restore(data: Dictionary) -> void:
    assert(data.get("session_id", "") == session_id, "Dialogue Manager session identity mismatch")
    next_id = str(data.get("next_id", "start"))
    phase = str(data.get("phase", "running"))
    delay_remaining = float(data.get("delay_remaining", 0.5))
    choice_remaining = float(data.get("choice_remaining", 0.0))
    pending_responses.clear()
    var choice_target: String = str(data.get("choice_next_id", ""))
    var quiet_target: String = str(data.get("quiet_next_id", ""))
    choice_response = {"next_id": choice_target} if not choice_target.is_empty() else null
    quiet_response = {"next_id": quiet_target} if not quiet_target.is_empty() else null
    assert(phase != "choice" or (choice_response != null and quiet_response != null), "Pending choice missing its branch targets")
