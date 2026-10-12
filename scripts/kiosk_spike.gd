extends Node2D
## Simple code-drawn top-down scene. Visuals are placeholders, not final art.

const Orchestrator = preload("res://scripts/conversation_orchestrator.gd")
const STEP: float = 0.25
const WALK_SPEED: float = 180.0

@export var use_dialogue_manager: bool = false

var model = Orchestrator.new()
var _dm_tick_active: bool = false

func _ready() -> void:
    if use_dialogue_manager:
        model = load("res://scripts/dm_conversation_orchestrator.gd").new()
var accumulator: float = 0.0
var event_cursor: int = 0
var latest_football: String = ""
var latest_rumor: String = ""
var last_notice: String = ""

func _process(delta: float) -> void:
    var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    direction += Vector2(
        int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)),
        int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))
    )
    if direction.length() > 1.0:
        direction = direction.normalized()
    model.player_position += direction * WALK_SPEED * delta
    model.player_position.x = clampf(model.player_position.x, 30.0, 930.0)
    model.player_position.y = clampf(model.player_position.y, 93.0, 430.0)

    accumulator += minf(delta, 0.5)
    if model.has_method("advance_async"):
        if not _dm_tick_active and accumulator >= STEP:
            _dm_tick_active = true
            accumulator -= STEP
            await model.advance_async(STEP)
            _dm_tick_active = false
    else:
        while accumulator >= STEP:
            model.advance(STEP)
            accumulator -= STEP

    while event_cursor < model.events.size():
        var event: Dictionary = model.events[event_cursor]
        event_cursor += 1
        if event.get("kind") == "line":
            if event["session"] == "football":
                latest_football = "%s: %s" % [event["speaker"], event["text"]]
            if event["session"] == "rumor":
                latest_rumor = "%s: %s" % [event["speaker"], event["text"]]
        elif event.get("kind") == "fact":
            last_notice = "Learned: %s" % event["fact"]
        elif event.get("kind") == "tea_served":
            last_notice = "Tea served!"
        elif event.get("kind") == "choice_expired":
            last_notice = "Conversation continues without you."
    queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_E:
                model.prepare_tea_step()
            KEY_K:
                model.grant_match_knowledge()
                last_notice = "You know the match details."
            KEY_1:
                if model.interject():
                    last_notice = "Joined the football conversation."

func _draw() -> void:
    draw_rect(Rect2(0, 0, 960, 540), Color("#c9b999"))
    draw_rect(Rect2(0, 0, 960, 85), Color("#4e463d"))
    draw_rect(Rect2(0, 445, 960, 95), Color("#2c6a77"))
    draw_line(Vector2(0, 443), Vector2(960, 443), Color("#45685d"), 8.0)
    draw_rect(Rect2(350, 88, 260, 75), Color("#92633e"))
    draw_rect(Rect2(364, 104, 230, 39), Color("#534033"))
    _text(Vector2(418, 80), "KIOSK COUNTER", 16, Color("#f3e8cf"))
    _text(Vector2(419, 183), "Tea: E near counter (3 steps)", 13, Color("#473e30"))
    _table(Orchestrator.TABLE_A, Color("#65858a"), Color("#9f7355"))
    _table(Orchestrator.TABLE_B, Color("#6d8870"), Color("#a77b55"))
    draw_circle(model.player_position, 13.0, Color("#365779"))
    _text(model.player_position + Vector2(-18, -19), "YOU", 12, Color("#253d55"))
    _text(Vector2(456, 496), "THE NILE", 18, Color("#e2e9e2"))
    _text(Vector2(20, 24), "Move: WASD/arrows   K: know match   1: join football   E: make tea", 15)
    var football = model.sessions["football"]
    var rumor = model.sessions["rumor"]
    _text(Vector2(20, 50), "A: %s | B: %s | tea: %d/3 | tick: %d" % [football.phase, rumor.phase, model.tea_steps, model.tick_number], 13)
    if model.heard("football"):
        _text(Vector2(80, 266), latest_football, 13, Color("#253b4f"))
        if football.phase == "choice":
            _text(Vector2(90, 283), "[1] I watched the match.", 13, Color("#214d83"))
    if model.heard("rumor"):
        _text(Vector2(525, 266), latest_rumor, 13, Color("#2b443a"))
    if not last_notice.is_empty():
        _text(Vector2(20, 426), last_notice, 14, Color("#3b3024"))

func _table(pos: Vector2, shirt1: Color, shirt2: Color) -> void:
    draw_rect(Rect2(pos - Vector2(49, 18), Vector2(98, 37)), Color("#e7d4ac"))
    draw_circle(pos + Vector2(-24, -29), 11.0, shirt1)
    draw_circle(pos + Vector2(26, 29), 11.0, shirt2)
    draw_rect(Rect2(pos - Vector2(49, 18), Vector2(98, 37)), Color("#8a7250"), false, 2.0)

func _text(pos: Vector2, value: String, size: int = 14, ink: Color = Color.WHITE) -> void:
    draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
