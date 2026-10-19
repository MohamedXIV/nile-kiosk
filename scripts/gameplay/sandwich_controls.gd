extends Control
## Built-in Godot Buttons for the live F7 counter. Drawing and the P3/P5
## world authority remain separate. No simulation or persisted UI state.
var on_toggle: Callable
var on_purchase: Callable
var on_step: Callable
var on_wait: Callable
var on_save: Callable
var on_close: Callable
var opener: Button
var purchases: Array[Button] = []
var action_button: Button
var wait_button: Button
var save_button: Button
var close_button: Button

static func action_label(context: Dictionary) -> String:
    var cue: String = str(context.get("cue",""))
    if cue.contains("Turn"): return "Turn liver"
    if cue.contains("Resume"): return "Resume"
    if cue.contains("Finish") or cue.contains("Lift"): return "Finish step"
    if cue.contains("Wait"): return "Finish step"
    if cue.contains("Assemble"): return "Assemble"
    if cue.contains("Season"): return "Season"
    if cue.contains("heat") or cue.contains("pan"): return "Start pan"
    return "Start sandwich"

func _style(btn: Button, background: Color) -> void:
    btn.add_theme_font_size_override("font_size",16)
    btn.add_theme_color_override("font_color",Color("#f5e5c8"))
    btn.add_theme_color_override("font_hover_color",Color("#ffffff"))
    btn.add_theme_color_override("font_disabled_color",Color("#bfc5bf"))
    for variant in ["normal","hover","pressed","disabled","focus"]:
        var box := StyleBoxFlat.new()
        box.bg_color = background
        if variant == "hover": box.bg_color = Color("#516d65")
        if variant == "pressed": box.bg_color = Color("#728671")
        if variant == "disabled": box.bg_color = Color("#334744")
        box.border_width_left = 2
        box.border_width_right = 2
        box.border_width_top = 2
        box.border_width_bottom = 2
        box.border_color = Color("#ddb982") if variant in ["hover","focus"] else Color("#51665d")
        btn.add_theme_stylebox_override(variant,box)

func _button(text: String, area: Rect2, background: Color) -> Button:
    var b := Button.new()
    b.text = text
    b.position = area.position
    b.size = area.size
    b.focus_mode = Control.FOCUS_ALL
    b.mouse_filter = Control.MOUSE_FILTER_STOP
    _style(b,background)
    add_child(b)
    return b

func _ready() -> void:
    build()

# Headless SceneTree tests may inspect this Control before the first frame
# delivers NOTIFICATION_READY. Building twice must never duplicate Buttons.
func build() -> void:
    if opener != null: return
    size = Vector2(960,540)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    # All actionable surfaces stay >= 68 logical px in compact landscape:
    # 640x360 Web maps 70 logical px to ~46.7 physical CSS pixels.
    # The opener lives below the guidance and away from the P10/P11 pad.
    opener = _button("Sandwich counter",Rect2(366,455,228,70),Color("#365e53"))
    opener.pressed.connect(_toggle_pressed)
    # Six honest P5 lots, arranged in two 3-row columns beside the pan.
    # Every button remains attached to its original offer index.
    for i in range(6):
        var column: int = int(i / 3)
        var row: int = i % 3
        var buy: Button = _button("BUY",
            Rect2(204+column*300,153+row*78,104,70),Color("#3c6156"))
        buy.tooltip_text = "Purchase real ingredient lot %d" % (i+1)
        buy.pressed.connect(_buy_pressed.bind(i))
        purchases.append(buy)
    # Four full-sized controls occupy the bottom action bar, with no overlap.
    action_button = _button("Start sandwich",Rect2(22,454,218,70),Color("#496c55"))
    action_button.pressed.connect(_step_pressed)
    wait_button = _button("Wait 5 min",Rect2(252,454,218,70),Color("#34515b"))
    wait_button.pressed.connect(_wait_pressed)
    save_button = _button("Save",Rect2(482,454,218,70),Color("#34515b"))
    save_button.pressed.connect(_save_pressed)
    close_button = _button("Close",Rect2(712,454,218,70),Color("#5d4c45"))
    close_button.pressed.connect(_close_pressed)
    update_view({},false,true,false)

func _toggle_pressed() -> void:
    if on_toggle.is_valid(): on_toggle.call()

func _buy_pressed(index: int) -> void:
    if on_purchase.is_valid(): on_purchase.call(index)

func _step_pressed() -> void:
    if on_step.is_valid(): on_step.call()

func _wait_pressed() -> void:
    if on_wait.is_valid(): on_wait.call()

func _save_pressed() -> void:
    if on_save.is_valid(): on_save.call()

func _close_pressed() -> void:
    if on_close.is_valid(): on_close.call()

func update_view(context: Dictionary, panel_open: bool, story_busy: bool,
        help_open: bool) -> void:
    var near: bool = bool(context.get("near",false))
    opener.visible = not panel_open and not story_busy and not help_open and near
    var show_panel: bool = panel_open and not story_busy and not help_open
    var offers: Array = context.get("offers",[])
    for i in range(purchases.size()):
        var button: Button = purchases[i]
        button.visible = show_panel and i < offers.size()
        if i >= offers.size(): continue
        var offer: Dictionary = offers[i]
        var bought: bool = bool(offer["resolved"])
        button.text = "BOUGHT" if bought else "BUY"
        button.disabled = bought or not near
        button.tooltip_text = ("Already paid for this day's lot" if bought else
            "Pay %d piastres for %s" % [int(offer["cost"]),str(offer["ingredient_id"]).replace("_"," ")])
    for button in [action_button,wait_button,save_button,close_button]:
        button.visible = show_panel
    action_button.text = action_label(context)
    action_button.disabled = not near
    wait_button.disabled = not near
