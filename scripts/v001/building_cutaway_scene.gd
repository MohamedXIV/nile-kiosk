extends Node2D
## V001 P0 blockout only. Visual art and baked Blender layers are NOT proven here.

const Building = preload("res://scripts/v001/building_model.gd")
var model := Building.new()
var selected_item: String = "chair"
var notice: String = "E: enter building"
const BAKED := "res://assets/v001/"
const SPRITE_LAYERS := ["facade_lower", "facade_upper", "roof", "apartment", "lobby", "chair", "table"]
var _baked_cache: Dictionary = {}

func _ready() -> void:
    # Without baked PNGs this stays a fully playable P0 fallback.
    for time_key in ["day", "night"]:
        for layer_key in SPRITE_LAYERS:
            var path: String = BAKED + layer_key + "_" + time_key + ".png"
            if ResourceLoader.exists(path):
                _baked_cache[layer_key + "_" + time_key] = load(path)
    if _has_baked_art():
        print("V001_BAKED_READY")

func _has_baked_art() -> bool:
    var suffix: String = "_night" if model.night else "_day"
    for key in SPRITE_LAYERS:
        if not _baked_cache.has(key + suffix):
            return false
    return true

func _baked_layer(key: String, offset: Vector2 = Vector2.ZERO) -> void:
    var suffix: String = "_night" if model.night else "_day"
    var image: Texture2D = _baked_cache.get(key + suffix)
    if image != null:
        draw_texture(image, offset)

func _draw_baked_building() -> void:
    _baked_layer("facade_lower")
    if model.mode == "street":
        _baked_layer("facade_upper")
        _baked_layer("roof")
    elif model.mode == "lobby":
        _baked_layer("lobby")
        _actor(Building.project(model.player_local, 1))
    elif model.mode == "apartment":
        _baked_layer("apartment")
        var level: int = Building.PLAYER_FLOOR
        var objects: Array[String] = ["chair", "table"]
        objects.sort_custom(func(a: String, b: String) -> bool:
            return Building.project(model.furniture[a], level).y < Building.project(model.furniture[b], level).y)
        var player_y: float = Building.project(model.player_local, level).y
        var drawn: bool = false
        for id in objects:
            var pos: Vector2 = Building.project(model.furniture[id], level)
            if not drawn and player_y < pos.y:
                _actor(Building.project(model.player_local, level))
                drawn = true
            var original_pos: Vector2 = Vector2(45.0, 68.0) if id == "chair" else Vector2(129.0, 84.0)
            _baked_layer(id, pos - Building.project(original_pos, level))
        if not drawn:
            _actor(Building.project(model.player_local, level))


func _process(delta: float) -> void:
    var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    direction += Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
        float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
    if direction.length() > 1.0:
        direction = direction.normalized()
    if direction != Vector2.ZERO:
        model.move_player(direction * minf(delta, 0.08) * 56.0)
    queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_E:
            if model.mode == "street":
                model.enter_building()
            elif model.mode == "lobby":
                model.go_to_apartment()
        KEY_ESCAPE, KEY_BACKSPACE:
            if model.mode == "apartment":
                model.leave_apartment()
            elif model.mode == "lobby":
                model.exit_building()
        KEY_1:
            selected_item = "chair"
        KEY_2:
            selected_item = "table"
        KEY_G:
            if model.move_furniture(selected_item, model.player_local + Vector2(24.0, -12.0)):
                notice = "Moved %s" % selected_item
                print("V001_FURNITURE_MOVED: %s" % selected_item)
            else:
                notice = "No free space for %s" % selected_item
        KEY_N:
            model.toggle_night()
        KEY_F6:
            notice = "Saved" if model.save_to_file("user://v001-cutaway.json") else "Save failed"
        KEY_F7:
            notice = "Restored" if model.load_from_file("user://v001-cutaway.json") else "No valid save"
    print("V001_MODE: %s | night: %s" % [model.mode, str(model.night)])
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(0, 0, 960, 540), Color("#243d4a") if model.night else Color("#9cc3bc"))
    _street()
    if _has_baked_art():
        _draw_baked_building()
    elif model.mode == "street":
        _building_facade(Building.FLOOR_COUNT)
        _roof()
    elif model.mode == "lobby":
        _building_facade(0)
        _room_floor(1, true)
        _lobby_details()
    else:
        _building_facade(Building.PLAYER_FLOOR - 1)
        _room_floor(Building.PLAYER_FLOOR, false)
        _apartment_details()

    var layers: Dictionary = model.visible_layers()
    _txt(Vector2(18, 26), "NILE KIOSK — V001 BUILDING CUTAWAY", 20)
    _txt(Vector2(18, 52), "View: %s | Logical floor: %d | roof: %s | upper facade: %s" %
        [model.mode, model.floor_id, str(layers.roof), str(layers.upper_facade)], 14)
    _txt(Vector2(18, 80), "E enter / stairs   Backspace return   WASD move   1 chair / 2 table   G move", 13)
    _txt(Vector2(18, 103), "N day-night   F6 save   F7 load   |  %s" % notice, 13)
    _txt(Vector2(18, 523), "Blender baked layers (art review pending)" if _has_baked_art() else "P0 fallback — bake Blender assets to preview P1", 12)

func _street() -> void:
    draw_rect(Rect2(0, 411, 960, 129), Color("#3d4544") if model.night else Color("#6c7772"))
    draw_rect(Rect2(0, 393, 960, 19), Color("#8a8f79"))
    for x in [125.0, 315.0, 738.0, 876.0]:
        draw_circle(Vector2(x, 368), 28.0, Color("#243a2b") if model.night else Color("#48704b"))
        draw_circle(Vector2(x - 9, 355), 17.0, Color("#34533b") if model.night else Color("#669668"))
    for x in [54.0, 212.0, 760.0]:
        draw_rect(Rect2(x, 451, 76, 27), Color("#38414b"))
        draw_rect(Rect2(x + 10.0, 454, 30, 13), Color("#899fa2"))
        draw_circle(Vector2(x + 15, 479), 7, Color("#22262c"))
        draw_circle(Vector2(x + 61, 479), 7, Color("#22262c"))

func _diamond(level: int) -> PackedVector2Array:
    return PackedVector2Array([
        Building.project(Vector2(0, 0), level),
        Building.project(Vector2(Building.FOOTPRINT.x, 0), level),
        Building.project(Building.FOOTPRINT, level),
        Building.project(Vector2(0, Building.FOOTPRINT.y), level)
    ])

func _building_facade(count: int) -> void:
    for level in range(1, count + 1):
        var a: PackedVector2Array = _diamond(level + 1)
        var b: PackedVector2Array = _diamond(level)
        draw_colored_polygon(PackedVector2Array([a[1], a[2], b[2], b[1]]), Color("#b89a78") if not model.night else Color("#665d5b"))
        draw_colored_polygon(PackedVector2Array([a[2], a[3], b[3], b[2]]), Color("#d4bd95") if not model.night else Color("#77716a"))
        draw_line(a[1], a[2], Color("#776858"), 2.0)
        draw_line(a[2], a[3], Color("#776858"), 2.0)
        # Each projected storey is a portion of the same oblique multi-floor facade.
        for face_pos in [0.27, 0.7]:
            var window_right: Vector2 = a[1].lerp(a[2], face_pos).lerp(b[1].lerp(b[2], face_pos), 0.5)
            var window_front: Vector2 = a[2].lerp(a[3], face_pos).lerp(b[2].lerp(b[3], face_pos), 0.5)
            draw_circle(window_right, 6.0, Color("#ffc77c") if model.night else Color("#597c80"))
            draw_circle(window_front, 6.0, Color("#ffc77c") if model.night else Color("#597c80"))

func _roof() -> void:
    draw_colored_polygon(_diamond(Building.FLOOR_COUNT + 1), Color("#928676"))
    draw_polyline(_diamond(Building.FLOOR_COUNT + 1), Color("#4e534e"), 3.0, true)
    var tank: Vector2 = Building.project(Vector2(50, 38), Building.FLOOR_COUNT + 1)
    draw_circle(tank, 15.0, Color("#455f67"))
    var dish: Vector2 = Building.project(Vector2(125, 83), Building.FLOOR_COUNT + 1)
    draw_arc(dish, 12.0, 0, TAU, 22, Color("#cbd0c8"), 4.0)

func _room_floor(level: int, is_lobby: bool) -> void:
    var color: Color = Color("#c3b39e") if is_lobby else Color("#decaab")
    draw_colored_polygon(_diamond(level), color if not model.night else color.darkened(0.44))
    draw_polyline(_diamond(level), Color("#4c5148"), 3.0, true)
    for i in range(1, 6):
        var fraction: float = i / 6.0
        draw_line(Building.project(Vector2(Building.FOOTPRINT.x * fraction, 0), level),
            Building.project(Vector2(Building.FOOTPRINT.x * fraction, Building.FOOTPRINT.y), level),
            Color("#8f8171", 0.24), 1.0)
        draw_line(Building.project(Vector2(0, Building.FOOTPRINT.y * fraction), level),
            Building.project(Vector2(Building.FOOTPRINT.x, Building.FOOTPRINT.y * fraction), level),
            Color("#8f8171", 0.24), 1.0)
    var pts: PackedVector2Array = _diamond(level)
    draw_line(pts[0], pts[1], Color("#776b5c"), 8)
    draw_line(pts[0], pts[3], Color("#776b5c"), 8)

func _lobby_details() -> void:
    var steps: Vector2 = Building.project(Vector2(38, 35), 1)
    for i in range(4):
        draw_line(steps + Vector2(i * 2.0, i * 7.0),
            steps + Vector2(58.0 + i * 2.0, i * 7.0), Color("#7c6c59"), 3)
    _txt(steps + Vector2(-45, -26), "STAIRS", 13, Color("#322f2a"))
    _actor(Building.project(model.player_local, 1))

func _apartment_details() -> void:
    var level: int = Building.PLAYER_FLOOR
    _prop(Building.project(Vector2(40, 30), level), Color("#8c7661"), "bed")
    var items: Array[String] = ["chair", "table"]
    items.sort_custom(func(a: String, b: String) -> bool:
        return Building.project(model.furniture[a], level).y < Building.project(model.furniture[b], level).y)
    for id in items:
        var point: Vector2 = Building.project(model.furniture[id], level)
        _prop(point, Color("#597c77") if id == selected_item else Color("#b2875d"), id)
    _actor(Building.project(model.player_local, level))
    var balcony: Vector2 = Building.project(Vector2(170, 60), level)
    draw_line(balcony, balcony + Vector2(26, 13), Color("#637f79"), 4)

func _prop(pos: Vector2, shade: Color, caption: String) -> void:
    draw_colored_polygon(PackedVector2Array([
        pos + Vector2(0, -9), pos + Vector2(17, 0),
        pos + Vector2(0, 9), pos + Vector2(-17, 0)]), shade)
    _txt(pos + Vector2(-20, -14), caption, 12, Color("#282e30"))

func _actor(pos: Vector2) -> void:
    draw_circle(pos + Vector2(4, 7), 7, Color("#3e4a44", 0.45))
    draw_circle(pos, 7, Color("#2d5e87"))
    _txt(pos + Vector2(-18, -17), "YOU", 12, Color("#1d2b38"))

func _txt(at: Vector2, content: String, size: int = 14, color: Color = Color("#f7f5e9")) -> void:
    draw_string(ThemeDB.fallback_font, at, content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
