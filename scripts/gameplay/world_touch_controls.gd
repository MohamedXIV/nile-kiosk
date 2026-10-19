extends Control
## On-screen input for the existing production scene. Godot Buttons provide
## pointer/touch/focus handling; this component never owns P1–P5 state.
var on_move: Callable
var on_action: Callable
var mode_enabled: bool = false
var held_direction: Vector2i = Vector2i.ZERO
var toggle: Button
var arrows: Array[Button] = []
var actions: Dictionary = {}
var dialogue_buttons: Dictionary = {}

static func controls_allowed(story_busy: bool, overlay_busy: bool) -> bool:
    return not story_busy and not overlay_busy

# Prefer the closest authored opportunity already exposed by P2/P6.
# Contextual text only; the scene rechecks before calling the original Ink entry.
static func dialogue_target(state: Dictionary, salma_near: bool) -> String:
    if str(state.get("location","")) != "kiosk": return ""
    if state.get("mahmoud_invite_near",false): return "mahmoud"
    if state.get("mona_visit_near",false): return "mona"
    if state.get("memory_near",false): return "memory"
    if salma_near and str(state.get("river_story_phase","")) != "finished": return "salma"
    if state.get("conversation_near",false): return "neighbors"
    return ""

func _button(label: String, area: Rect2, tint: Color) -> Button:
    var result := Button.new()
    result.text = label
    result.position = area.position
    result.size = area.size
    result.focus_mode = Control.FOCUS_ALL
    result.mouse_filter = Control.MOUSE_FILTER_STOP
    result.add_theme_font_size_override("font_size",17)
    result.add_theme_color_override("font_color",Color("#f4e5ca"))
    result.add_theme_color_override("font_disabled_color",Color("#a1ada7"))
    for variant in ["normal","hover","pressed","disabled","focus"]:
        var style := StyleBoxFlat.new()
        style.bg_color = tint if variant == "normal" else Color("#57716c") if variant == "hover" else \
            Color("#344442") if variant == "disabled" else Color("#73958a")
        style.border_width_left = 2
        style.border_width_top = 2
        style.border_width_right = 2
        style.border_width_bottom = 2
        style.border_color = Color("#e2ba7c") if variant in ["hover","focus"] else Color("#49615e")
        result.add_theme_stylebox_override(variant,style)
    add_child(result)
    return result

func _ready() -> void:
    build()

func build() -> void:
    if toggle != null: return
    size = Vector2(960,540)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    toggle = _button("On-screen",Rect2(810,455,136,70),Color("#386055"))
    # Wide touch targets stay at least 46 CSS pixels at 640px landscape width.
    # Buttons sit outside the camera-safe middle playfield.
    toggle.tooltip_text = "Show optional movement and world action buttons"
    toggle.pressed.connect(_toggle)
    # Eight directions, including the two diagonals used by the room exits.
    var directions: Array[Vector2i] = [
        Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),
        Vector2i(-1,0),Vector2i(1,0),
        Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]
    var labels: Array[String] = ["NW","N","NE","W","E","SW","S","SE"]
    var locations: Array[Vector2i] = [
        Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),
        Vector2i(0,1),Vector2i(2,1),
        Vector2i(0,2),Vector2i(1,2),Vector2i(2,2)]
    for i in range(directions.size()):
        var pos: Vector2 = Vector2(14+locations[i].x*76,118+locations[i].y*76)
        var b: Button = _button(labels[i],Rect2(pos,Vector2(70,70)),Color("#3d5b59"))
        b.tooltip_text = "Walk %s: hold or tap" % labels[i]
        b.button_down.connect(_direction_down.bind(directions[i]))
        b.button_up.connect(_direction_up.bind(directions[i]))
        arrows.append(b)
    for spec in [
        {"key":"door","caption":"Door","row":0,"col":0},
        {"key":"serve","caption":"Serve","row":0,"col":1},
        {"key":"shop","caption":"Open/Close","row":1,"col":0},
        {"key":"sleep","caption":"Sleep","row":1,"col":1},
        {"key":"save","caption":"Save","row":2,"col":0},
        {"key":"talk","caption":"Talk","row":2,"col":1},
        {"key":"wait","caption":"Wait 5m","row":3,"col":0},
        {"key":"tea","caption":"Tea","row":3,"col":1}
    ]:
        var kind: String = spec["key"]
        var position: Vector2 = Vector2(728+int(spec["col"])*114,124+int(spec["row"])*75)
        var button: Button = _button(str(spec["caption"]),
            Rect2(position,Vector2(104,68)),Color("#426251"))
        button.tooltip_text = "Use real world action: %s" % kind
        button.pressed.connect(_action_pressed.bind(kind))
        actions[kind] = button
    # Conversational controls replace world actions without a separate Ink UI.
    for spec in [
        {"key":"next","label":"Continue","column":0},
        {"key":"leave","label":"Leave","column":1},
        {"key":"choice_0","label":"Reply 1","column":0},
        {"key":"choice_1","label":"Reply 2","column":1}
    ]:
        var key: String = str(spec["key"])
        var btn: Button = _button(str(spec["label"]),
            Rect2(Vector2(728+int(spec["column"])*114,344),Vector2(104,68)),
            Color("#425e68"))
        btn.pressed.connect(_action_pressed.bind(key))
        dialogue_buttons[key] = btn
    update_view({},false,false,false,false)

func _toggle() -> void:
    mode_enabled = not mode_enabled
    held_direction = Vector2i.ZERO
    update_view({},false,false,false,false) # Scene sync supplies the real context.
    if on_action.is_valid(): on_action.call("toggle")

func _direction_down(direction: Vector2i) -> void:
    if not mode_enabled: return
    held_direction = direction
    if on_move.is_valid(): on_move.call()

func _direction_up(direction: Vector2i) -> void:
    if held_direction == direction:
        held_direction = Vector2i.ZERO

func _action_pressed(kind: String) -> void:
    if on_action.is_valid() and mode_enabled:
        on_action.call(kind)

func release() -> void:
    held_direction = Vector2i.ZERO

func _notification(what: int) -> void:
    if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
        release()

func update_view(state: Dictionary, portal_near: bool, counter_near: bool,
        story_busy: bool, overlay_busy: bool, talk_action: String = "",
        conversation_open: bool = false, choices: Array = []) -> void:
    if toggle == null: return
    var allowed: bool = controls_allowed(story_busy,overlay_busy)
    toggle.visible = allowed
    toggle.text = "Hide pad" if mode_enabled else "On-screen"
    if not allowed: release()
    var showing: bool = mode_enabled and allowed
    var showing_dialogue: bool = mode_enabled and conversation_open and not overlay_busy
    for key in dialogue_buttons:
        var btn: Button = dialogue_buttons[key]
        btn.visible = showing_dialogue and (
            (key == "next" and choices.is_empty()) or
            (key == "leave") or
            (key == "choice_0" and choices.size() > 0) or
            (key == "choice_1" and choices.size() > 1))
    for arrow in arrows: arrow.visible = showing
    for kind in actions:
        var button: Button = actions[kind]
        button.visible = showing
        match kind:
            "door": button.disabled = not portal_near
            "serve": button.disabled = not counter_near
            "shop":
                button.disabled = state.get("location","") != "kiosk"
                button.text = "Close shop" if state.get("kiosk_open",false) else "Open shop"
            "sleep": button.disabled = state.get("location","") != "roof"
            "save", "wait": button.disabled = false
            "talk":
                button.disabled = talk_action.is_empty()
                # The nearby speaker is given in a tooltip; keep 104px targets legible.
                button.text = "Talk"
                button.tooltip_text = "Talk to " + talk_action if not talk_action.is_empty() else "No one near"
            "tea":
                var gesture: String = str(state.get("tea_action",""))
                button.disabled = not counter_near or not (gesture in ["H","U"])
                button.text = "Heat / Lift" if gesture == "H" else "Pour" if gesture == "U" else "Tea"
