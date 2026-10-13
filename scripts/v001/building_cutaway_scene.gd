extends Node2D
## V001 P0 blockout only. Visual art and baked Blender layers are NOT proven here.

const Building = preload("res://scripts/v001/building_model.gd")
var model := Building.new()
var selected_item: String = "chair"
var notice: String = "Your 4 x 6 m rooftop room"
const BAKED := "res://assets/v001/"
const SPRITE_LAYERS := ["facade_lower", "facade_upper", "roof", "apartment", "lobby", "chair", "table", "neighbor", "landing", "front_wall_cut", "roof_room", "roof_room_cut"]
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
    _setup_dynamic_lighting()
    _setup_view()

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
    match model.mode:
        "street":
            _baked_layer("facade_upper")
            _baked_layer("roof")
            _baked_layer("roof_room")
        "roof":
            _baked_layer("facade_upper")
            _baked_layer("roof")
            _baked_layer("roof_room")
            _actor(Building.project(model.player_local, Building.ROOF_FLOOR))
        "roof_room":
            _baked_layer("facade_upper")
            _baked_layer("roof")
            _baked_layer("roof_room_cut")
            _actor(Building.project(model.player_local, Building.ROOF_FLOOR))
        "lobby":
            _baked_layer("lobby")
            _actor(Building.project(model.player_local, 1))
        "landing":
            _baked_layer("neighbor")
            _baked_layer("landing")
            _actor(Building.project(model.player_local, Building.PLAYER_FLOOR))
        "apartment":
            _baked_layer("neighbor")
            _baked_layer("landing")
            _baked_layer("apartment")
            _baked_layer("front_wall_cut")
            _draw_furniture_and_player()

func _draw_furniture_and_player() -> void:
    var level: int = Building.PLAYER_FLOOR
    var objects: Array[String] = ["chair", "table"]
    objects.sort_custom(func(a: String, b: String) -> bool:
        return Building.project(model.furniture[a], level).y < Building.project(model.furniture[b], level).y)
    var player_pos: Vector2 = Building.project(model.player_local, level)
    var drawn: bool = false
    for id in objects:
        var pos: Vector2 = Building.project(model.furniture[id], level)
        if not drawn and player_pos.y < pos.y:
            _actor(player_pos)
            drawn = true
        var original_pos: Vector2 = Vector2(83,101) if id == "chair" else Vector2(145,103)
        _baked_layer(id, pos - Building.project(original_pos, level))
    if not drawn:
        _actor(player_pos)

var _lamp: PointLight2D
var _wall_occluder: LightOccluder2D

func _make_radial_light() -> Texture2D:
    var pixels: Image = Image.create(96, 96, false, Image.FORMAT_RGBA8)
    for y in range(96):
        for x in range(96):
            var distance: float = Vector2(float(x)-47.5, float(y)-47.5).length() / 47.5
            var strength: float = pow(maxf(0.0, 1.0-distance), 1.8)
            pixels.set_pixel(x, y, Color(1.0, 0.81, 0.50, strength))
    return ImageTexture.create_from_image(pixels)

func _setup_dynamic_lighting() -> void:
    _lamp = PointLight2D.new()
    _lamp.name = "RuntimeLamp"
    _lamp.texture = _make_radial_light()
    _lamp.texture_scale = 2.4
    _lamp.energy = 0.9
    add_child(_lamp)
    # Independent runtime shadow casting from a permanent BACK wall segment.
    # Front cutaway walls must NOT continue casting a shadow after disappearing.
    var shadow: OccluderPolygon2D = OccluderPolygon2D.new()
    shadow.polygon = PackedVector2Array([
        Building.project(Vector2(48, 60), 6),
        Building.project(Vector2(168, 60), 6),
        Building.project(Vector2(168, 63), 6),
        Building.project(Vector2(48, 63), 6)
    ])
    _wall_occluder = LightOccluder2D.new()
    _wall_occluder.name = "BackWallShadow"
    _wall_occluder.occluder = shadow
    add_child(_wall_occluder)
    _sync_dynamic_lights()

func _sync_dynamic_lights() -> void:
    if _lamp == null or _wall_occluder == null:
        return
    var indoors: bool = model.mode in ["roof_room", "apartment"]
    _lamp.visible = indoors and model.night and model.lamp_on
    _lamp.position = Building.project(
        Vector2(83, 100) if model.mode == "roof_room" else Vector2(119, 91),
        Building.ROOF_FLOOR if model.mode == "roof_room" else Building.PLAYER_FLOOR)
    _wall_occluder.visible = model.mode == "apartment" and model.night
# Same LOCKED oblique projection; only zoom/pan changes between hand-authored views.
# No free camera rotation and no per-object offsets.
var _camera: Camera2D
var _hud: Label

func _setup_view() -> void:
    _camera = Camera2D.new()
    _camera.name = "FixedAngleInteriorCamera"
    _camera.enabled = true
    add_child(_camera)
    var overlay: CanvasLayer = CanvasLayer.new()
    overlay.layer = 10
    add_child(overlay)
    _hud = Label.new()
    _hud.name = "V001DebugHud"
    _hud.position = Vector2(18, 12)
    _hud.add_theme_font_size_override("font_size", 14)
    _hud.add_theme_color_override("font_color", Color("#fff4d7"))
    _hud.add_theme_color_override("font_outline_color", Color("#24313a"))
    _hud.add_theme_constant_override("outline_size", 4)
    overlay.add_child(_hud)
    _sync_view()

func _sync_view() -> void:
    if _camera == null:
        return
    var focus: Vector2 = Vector2(480, 270)
    var scale_factor: float = 1.0
    match model.mode:
        "roof_room":
            focus = Building.project(Building.ROOF_ROOM_BOUNDS.get_center(), Building.ROOF_FLOOR)
            scale_factor = 3.5
        "roof":
            focus = Building.project(Vector2(90, 66), Building.ROOF_FLOOR)
            scale_factor = 1.9
        "landing":
            focus = Building.project(Vector2(105, 54), Building.PLAYER_FLOOR)
            scale_factor = 2.5
        "apartment":
            focus = Building.project(Building.APARTMENT_BOUNDS.get_center(), Building.PLAYER_FLOOR)
            scale_factor = 2.8
        "lobby":
            focus = Building.project(Vector2(90, 66), 1)
            scale_factor = 1.4
    _camera.position = focus
    _camera.zoom = Vector2.ONE * scale_factor
    var layers: Dictionary = model.visible_layers()
    _hud.text = ("NILE KIOSK — V001 V2 | %s, floor %d\n" % [model.mode, model.floor_id]
        + "E forward / Backspace back / R QA unlock / WASD move / G chair\n"
        + "N day-night / L lamp / F6 save / F7 load\n"
        + "%s | roof: %s | neighbor door: %s" % [notice, str(layers.roof), str(layers.neighbor)])

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
            match model.mode:
                "roof_room": model.leave_roof_room()
                "roof": model.descend_from_roof()
                "landing":
                    if not model.go_to_apartment():
                        notice = "Apartment not rented. R = QA rental preview."
                "street": model.enter_building()
                "lobby": model.go_to_landing()
        KEY_ESCAPE, KEY_BACKSPACE:
            match model.mode:
                "apartment": model.leave_apartment()
                "landing": model.ascend_to_roof()
                "roof": model.enter_roof_room()
                "lobby": model.exit_building()
        KEY_R:
            model.rent_apartment_for_spike()
            notice = "QA preview: southern apartment rental unlocked."
        KEY_1:
            selected_item = "chair"
        KEY_2:
            selected_item = "table"
        KEY_G:
            if model.move_furniture(selected_item, model.player_local + Vector2(-20, 25)):
                notice = "Moved %s" % selected_item
                print("V001_FURNITURE_MOVED: %s" % selected_item)
            else:
                notice = "No free space for %s" % selected_item
        KEY_N:
            model.toggle_night()
        KEY_L:
            if model.toggle_lamp():
                print("V001_LAMP: %s" % str(model.lamp_on))
        KEY_F6:
            notice = "Saved" if model.save_to_file("user://v001-cutaway.json") else "Save failed"
        KEY_F7:
            notice = "Restored" if model.load_from_file("user://v001-cutaway.json") else "No valid save"
    _sync_dynamic_lights()
    _sync_view()
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
        _draw_rect_floor(Building.ROOF_ROOM_BOUNDS, Building.ROOF_FLOOR, Color("#c6b299"))
    elif model.mode == "lobby":
        _room_floor(1, true)
        _lobby_details()
    else:
        if model.mode in ["landing", "apartment"]:
            _draw_rect_floor(Building.NEIGHBOR_BOUNDS, Building.PLAYER_FLOOR, Color("#968c7e"))
            _draw_rect_floor(Building.LANDING_BOUNDS, Building.PLAYER_FLOOR, Color("#b2a18c"))
            _txt(Building.project(Vector2(111,48), 6), "NEIGHBOR", 12)
            _txt(Building.project(Vector2(111,60), 6), "OUR DOOR", 12)
        if model.mode == "apartment":
            _draw_rect_floor(Building.APARTMENT_BOUNDS, Building.PLAYER_FLOOR, Color("#ddc5a2"))
            _draw_cut_wall(Building.APARTMENT_BOUNDS, Building.PLAYER_FLOOR)
            _apartment_details()
        elif model.mode == "roof_room":
            _draw_rect_floor(Building.ROOF_ROOM_BOUNDS, Building.ROOF_FLOOR, Color("#d4bb9b"))
            _draw_cut_wall(Building.ROOF_ROOM_BOUNDS, Building.ROOF_FLOOR)
            _actor(Building.project(model.player_local, Building.ROOF_FLOOR))
        elif model.mode == "roof":
            _roof()
            _draw_rect_floor(Building.ROOF_ROOM_BOUNDS, Building.ROOF_FLOOR, Color("#948576"))
            _actor(Building.project(model.player_local, Building.ROOF_FLOOR))
        else:
            _actor(Building.project(model.player_local, Building.PLAYER_FLOOR))


func _draw_rect_floor(area: Rect2, level: int, color: Color) -> void:
    var points := PackedVector2Array([
        Building.project(area.position, level),
        Building.project(Vector2(area.end.x, area.position.y), level),
        Building.project(area.end, level),
        Building.project(Vector2(area.position.x, area.end.y), level)
    ])
    draw_colored_polygon(points, color.darkened(0.40) if model.night else color)
    draw_polyline(points, Color("#776956"), 3.0, true)

func _draw_cut_wall(area: Rect2, level: int) -> void:
    # A permanent low sill outlines the southern unit while the blocking upper wall is gone.
    var left := Building.project(Vector2(area.position.x, area.end.y), level)
    var right := Building.project(area.end, level)
    draw_line(left, right, Color("#917a61"), 8.0)
    draw_line(left+Vector2(0,-4), right+Vector2(0,-4), Color("#d2ba98"), 3.0)

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
    _prop(Building.project(Vector2(65, 80), level), Color("#8c7661"), "bed")
    var items: Array[String] = ["chair", "table"]
    items.sort_custom(func(a: String, b: String) -> bool:
        return Building.project(model.furniture[a], level).y < Building.project(model.furniture[b], level).y)
    for id in items:
        var point: Vector2 = Building.project(model.furniture[id], level)
        _prop(point, Color("#597c77") if id == selected_item else Color("#b2875d"), id)
    _actor(Building.project(model.player_local, level))
    var balcony: Vector2 = Building.project(Vector2(168, 100), level)
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
