extends RefCounted
## Each session owns its *own* real InkPlayer, story and cursor.
## The shared inkgd runtime handles errors, not conversation ownership.

var session_id: String
var player: Node
var ready: bool = false
var load_failed: bool = false
var phase: String = "running"
var delay_remaining: float = 0.5
var choice_remaining: float = 0.0
var offered_choice: int = -1
var quiet_choice: int = -1
var line_count: int = 0

func _init(id: String, ink_json_path: String) -> void:
    session_id = id
    var script: GDScript = load("res://addons/inkgd/ink_player.gd")
    var resource_script: GDScript = load("res://addons/inkgd/editor/import_plugins/ink_resource.gd")
    assert(script != null and resource_script != null, "inkgd GDScript runtime must be installed")
    player = script.new()
    player.name = "InkPlayer_" + session_id
    player.loads_in_background = false
    var story_resource: Resource = resource_script.new()
    var json: String = FileAccess.get_file_as_string(ink_json_path)
    assert(not json.is_empty(), "Ink compilation missing: " + ink_json_path)
    story_resource.set("json", json)
    player.ink_file = story_resource
    player.loaded.connect(_on_loaded)
    (Engine.get_main_loop() as SceneTree).root.add_child(player)
    player.create_story()

func _on_loaded(success: bool) -> void:
    ready = success
    load_failed = not success

func tick(delta: float, can_interject: bool) -> Array[Dictionary]:
    var emitted: Array[Dictionary] = []
    if not ready or phase == "finished":
        return emitted
    if phase == "choice":
        choice_remaining -= delta
        if choice_remaining <= 0.0:
            _take_quiet_choice()
            emitted.append({"kind": "choice_expired", "session": session_id})
        return emitted

    delay_remaining -= delta
    if delay_remaining > 0.0:
        return emitted

    if session_id == "football":
        player.set_variable("knows_match", can_interject)

    var raw: String = ""
    if player.can_continue:
        raw = player.continue_story().strip_edges()
    if not raw.is_empty():
        var colon: int = raw.find(":")
        var speaker: String = raw.substr(0, colon).strip_edges() if colon >= 0 else ""
        var line_text: String = raw.substr(colon + 1).strip_edges() if colon >= 0 else raw
        var fact: String = ""
        for tag in player.current_tags:
            var tag_text: String = str(tag)
            if tag_text.begins_with("fact:"):
                fact = tag_text.trim_prefix("fact:")
        emitted.append({"kind": "line", "session": session_id, "speaker": speaker, "text": line_text, "fact": fact})
        line_count += 1

    if player.has_choices:
        offered_choice = -1
        quiet_choice = -1
        for index in range(player.current_choices.size()):
            var choice_text: String = str(player.current_choices[index].text).strip_edges()
            if choice_text == "Stay quiet.":
                quiet_choice = index
            elif choice_text == "I watched the match.":
                offered_choice = index
        if offered_choice >= 0 and can_interject:
            phase = "choice"
            choice_remaining = 4.0
            emitted.append({"kind": "choice", "session": session_id, "text": "I watched the match."})
        else:
            _take_quiet_choice()
    elif not player.can_continue and raw.is_empty():
        phase = "finished"
        emitted.append({"kind": "finished", "session": session_id})
    delay_remaining = 0.5
    return emitted

func choose_interjection() -> Array[Dictionary]:
    var emitted: Array[Dictionary] = []
    if phase != "choice" or offered_choice < 0:
        return emitted
    player.choose_choice_index(offered_choice)
    offered_choice = -1
    quiet_choice = -1
    phase = "running"
    delay_remaining = 0.5
    emitted.append({"kind": "interjection", "session": session_id, "text": "I watched the match."})
    return emitted

func _take_quiet_choice() -> void:
    assert(quiet_choice >= 0, "Missing Ink 'Stay quiet.' escape branch")
    player.choose_choice_index(quiet_choice)
    quiet_choice = -1
    offered_choice = -1
    phase = "running"
    delay_remaining = 0.5

func dispose() -> void:
    if is_instance_valid(player):
        player.queue_free()
