extends Control
## P3 game-feel: one nearby hand-action and one context action over a small
## bottom cooking strip. All stock, timing and orders remain P1/P3/P5 facts.
## Choosing an ingredient is a disposable view index, never a persisted item.
var on_toggle: Callable
var on_purchase: Callable
var on_step: Callable
var on_wait: Callable
var on_save: Callable
var on_close: Callable
var opener: Button
var action_button: Button
var wait_button: Button
var save_button: Button
var menu_button: Button
var close_button: Button
var selected_offer_index: int = 0
var utility_open: bool = false
var action_kind: String = ""
var view_context: Dictionary = {}
var panel_active: bool = false

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

static func shopping(context: Dictionary) -> bool:
    if not str(context.get("stage","")).is_empty(): return false
    for offer in context.get("offers",[]):
        if not bool(offer.get("resolved",false)): return true
    return false

static func next_offer(offers: Array, current: int, include_current: bool = false) -> int:
    if offers.is_empty(): return -1
    # The hidden startup state has cursor -1: never treat negative Godot
    # array indexing as the last ingredient in a fresh purchase flow.
    if current < 0 or current >= offers.size(): current = 0
    for delta in range(0 if include_current else 1,offers.size() + (0 if include_current else 1)):
        var idx: int = (current + delta) % offers.size()
        if not bool(offers[idx].get("resolved",false)):
            return idx
    return -1

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
        for side in ["left","right","top","bottom"]:
            box.set("border_width_" + side,2)
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

func _ready() -> void: build()

func build() -> void:
    if opener != null: return
    size = Vector2(960,540)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    opener = _button("Sandwich counter",Rect2(366,455,228,70),Color("#365e53"))
    opener.pressed.connect(_toggle_pressed)
    # Exactly two contextual cooking controls in the bottom strip.
    action_button = _button("Buy ingredient",Rect2(572,456,174,70),Color("#496c55"))
    action_button.pressed.connect(_primary_pressed)
    wait_button = _button("Next ingredient",Rect2(754,456,174,70),Color("#34515b"))
    wait_button.pressed.connect(_secondary_pressed)
    # Explicit close/utility are separate non-cooking affordances.
    menu_button = _button("Menu",Rect2(798,382,72,68),Color("#34515b"))
    menu_button.pressed.connect(_utility_toggle)
    close_button = _button("X",Rect2(880,382,68,68),Color("#5d4c45"))
    close_button.pressed.connect(_close_pressed)
    save_button = _button("Save",Rect2(572,456,174,70),Color("#34515b"))
    save_button.pressed.connect(_save_pressed)
    update_view({},false,true,false)

func _toggle_pressed() -> void:
    if on_toggle.is_valid(): on_toggle.call()

func _primary_pressed() -> void:
    if not panel_active or utility_open: return
    if action_kind == "buy":
        if selected_offer_index >= 0 and on_purchase.is_valid():
            on_purchase.call(selected_offer_index)
    elif action_kind == "step" and on_step.is_valid():
        on_step.call()

func _secondary_pressed() -> void:
    if not panel_active or utility_open: return
    if action_kind == "buy":
        if bool(view_context.get("can_start",false)):
            if on_step.is_valid(): on_step.call()
        else:
            var offers: Array = view_context.get("offers",[])
            var next: int = next_offer(offers,selected_offer_index)
            if next >= 0:
                selected_offer_index = next
                update_view(view_context,true,false,false)
    elif action_kind == "step" and on_wait.is_valid():
        on_wait.call()

func _utility_toggle() -> void:
    if not panel_active: return
    utility_open = not utility_open
    update_view(view_context,true,false,false)

func _save_pressed() -> void:
    if on_save.is_valid() and utility_open:
        utility_open = false
        on_save.call()

func _close_pressed() -> void:
    utility_open = false
    if on_close.is_valid(): on_close.call()

func update_view(context: Dictionary, panel_open: bool, story_busy: bool,
        help_open: bool) -> void:
    if opener == null: return
    view_context = context
    var near: bool = bool(context.get("near",false))
    var visible: bool = panel_open and not story_busy and not help_open and near
    panel_active = visible
    opener.visible = not panel_open and not story_busy and not help_open and near
    menu_button.visible = visible
    close_button.visible = visible
    save_button.visible = visible and utility_open
    var offers: Array = context.get("offers",[])
    var offer_index: int = next_offer(offers,selected_offer_index,true)
    selected_offer_index = offer_index
    action_kind = "buy" if shopping(context) and offer_index>=0 else "step"
    var buy_mode: bool = action_kind == "buy"
    action_button.visible = visible and not utility_open and (not shopping(context) or offer_index>=0)
    action_button.disabled = not near
    if buy_mode:
        var offer: Dictionary = offers[offer_index]
        action_button.text = "Buy %s · %dp" % [
            str(offer.get("ingredient_id","")).replace("_"," "),
            int(offer.get("cost",0))]
    else:
        action_button.text = action_label(context)
    wait_button.visible = visible and not utility_open and (
        (buy_mode and (bool(context.get("can_start",false)) or
            (next_offer(offers,offer_index)>=0 and
            next_offer(offers,offer_index)!=offer_index))) or
        (not buy_mode and not str(context.get("stage","")).is_empty()))
    wait_button.text = ("Start cooking" if bool(context.get("can_start",false))
        else "Next ingredient") if buy_mode else "Wait 5 min"
    wait_button.disabled = not near
