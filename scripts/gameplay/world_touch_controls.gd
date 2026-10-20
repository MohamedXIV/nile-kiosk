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
var menu_button: Button
var utility_buttons: Dictionary = {}
var utility_open: bool = false

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
    # Only two proximity-resolved actions: E primary, F alternate.
    # No permanently visible wall of disabled world-command buttons.
    for spec in [
        {"kind":"primary","key":"E","column":0},
        {"kind":"alternate","key":"F","column":1}
    ]:
        var kind: String = str(spec["kind"])
        var position := Vector2(728+int(spec["column"])*114,124)
        var button: Button = _button(str(spec["key"]),
            Rect2(position,Vector2(104,68)),Color("#426251"))
        button.pressed.connect(_action_pressed.bind(kind))
        actions[kind] = button
    # Utilities are deliberately separate from nearby world actions.
    # Save/Wait are reachable on phones without adding permanent world verbs.
    menu_button = _button("Menu",Rect2(650,455,136,70),Color("#34515b"))
    menu_button.pressed.connect(_utility_toggle)
    for spec in [
        {"kind":"save","label":"Save","column":0},
        {"kind":"wait","label":"Wait 5m","column":1}
    ]:
        var kind: String = str(spec["kind"])
        var button: Button = _button(str(spec["label"]),
            Rect2(Vector2(728+int(spec["column"])*114,222),Vector2(104,68)),
            Color("#34515b"))
        button.pressed.connect(_utility_pressed.bind(kind))
        utility_buttons[kind] = button
    # Conversational controls replace world actions without a separate Ink UI.
    # Direct authored Ink replies are visible without enabling the optional
    # movement pad. Four slots fit the existing scene; no invented choices.
    # Two rows are used only when the canonical P6 session offers >2 choices.
    for spec in [
        {"key":"next","label":"Continue","column":0,"row":1},
        {"key":"leave","label":"Leave","column":1,"row":1},
        {"key":"choice_0","label":"Reply 1","column":0,"row":0},
        {"key":"choice_1","label":"Reply 2","column":1,"row":0},
        {"key":"choice_2","label":"Reply 3","column":0,"row":1},
        {"key":"choice_3","label":"Reply 4","column":1,"row":1}
    ]:
        var key: String = str(spec["key"])
        var btn: Button = _button(str(spec["label"]),
            Rect2(Vector2(100+int(spec["column"])*390,302+int(spec["row"])*70),
                Vector2(370,68)),Color("#425e68"))
        btn.clip_text = true
        btn.pressed.connect(_action_pressed.bind(key))
        dialogue_buttons[key] = btn
    update_view({},false,false,false,false)

func _toggle() -> void:
    mode_enabled = not mode_enabled
    utility_open = false
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
    # Ink replies are world-visible click/touch actions even with pad Off.
    # The scene revalidates the current P6 option_id at press time.
    if on_action.is_valid() and (mode_enabled or dialogue_buttons.has(kind)) and not utility_open:
        on_action.call(kind)

func _utility_toggle() -> void:
    if not mode_enabled: return
    utility_open = not utility_open
    release()
    if on_action.is_valid(): on_action.call("menu")

func _utility_pressed(kind: String) -> void:
    if on_action.is_valid() and mode_enabled and utility_open:
        utility_open = false
        on_action.call(kind)

func release() -> void:
    held_direction = Vector2i.ZERO

func _notification(what: int) -> void:
    if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
        release()

# Existing call signature retains canonical P2/Ink inputs. The new final
# parameter is the *read-only*, press-time-verified two-slot action list.
static func touch_caption(kind: String) -> String:
    return {
        "door":"Door", "serve":"Serve","open":"Open","close":"Close",
        "talk":"Talk", "tea_heat":"Heat / Lift", "tea_pour":"Pour",
        "wait":"Wait 5m", "sleep":"Sleep", "sandwich":"Cook",
        "quiet":"Quiet", "market_buy":"Buy leaves", "market_decline":"Decline",
        "supply_buy":"Order leaves", "supply_decline":"Decline"
    }.get(kind,"Interact")

func update_view(state: Dictionary, portal_near: bool, counter_near: bool,
        story_busy: bool, overlay_busy: bool, talk_action: String = "",
        conversation_open: bool = false, choices: Array = [],
        contextual: Array = []) -> void:
    if toggle == null: return
    var allowed: bool = controls_allowed(story_busy,overlay_busy)
    toggle.visible = allowed
    toggle.text = "Hide pad" if mode_enabled else "On-screen"
    if not allowed: release()
    var showing: bool = mode_enabled and allowed
    var showing_dialogue: bool = conversation_open and not overlay_busy
    menu_button.visible = showing
    for kind in utility_buttons:
        utility_buttons[kind].visible = showing and utility_open
    for key in dialogue_buttons:
        var btn: Button = dialogue_buttons[key]
        var index: int = int(key.trim_prefix("choice_")) if key.begins_with("choice_") else -1
        btn.visible = showing_dialogue and (key == "leave" or
            (key == "next" and choices.is_empty()) or
            (index >= 0 and index < choices.size()))
        if index >= 0 and index < choices.size():
            btn.text = str(choices[index].get("text","Reply"))
            btn.tooltip_text = btn.text
    for arrow in arrows: arrow.visible = showing and not utility_open
    for i in range(2):
        var button: Button = actions["primary" if i == 0 else "alternate"]
        button.visible = showing and not utility_open and i < contextual.size()
        button.disabled = false
        if i < contextual.size():
            var action: Dictionary = contextual[i]
            button.text = ("%s  %s" % ["E" if i==0 else "F",
                touch_caption(str(action.get("kind","")))])
            button.tooltip_text = str(action.get("label",""))
