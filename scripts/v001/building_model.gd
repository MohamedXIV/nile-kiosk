extends RefCounted
## V001 V2: authored Cairo building topology. Unit/floor coordinates are logical,
## independent of projected pixel elevation or visual cutaway state.
const BUILDING_ID := "old_cairo_home"
const SAVE_VERSION: int = 2
const FLOOR_COUNT: int = 6
const PLAYER_FLOOR: int = 6
const ROOF_FLOOR: int = 7
const PIXELS_PER_METRE: float = 12.0
const FOOTPRINT := Vector2(180.0, 132.0) # 15 x 11 metres, whole building
const APARTMENT_BOUNDS := Rect2(Vector2(48, 60), Vector2(120, 72)) # southern unit: 10 x 6 = 60m2
const NEIGHBOR_BOUNDS := Rect2(Vector2(48, 0), Vector2(120, 48)) # never rendered internally
const LANDING_BOUNDS := Rect2(Vector2(48, 48), Vector2(120, 12))
const ROOF_ROOM_BOUNDS := Rect2(Vector2(60, 60), Vector2(48, 72)) # directly over apartment: 4 x 6 = 24m2
const ORIGIN := Vector2(490.0, 390.0)
const AXIS_X := Vector2(0.93, 0.45)
const AXIS_Y := Vector2(-0.93, 0.45)
const FLOOR_PIXELS: float = 47.0

# We start with a *rented roof room*, not the larger apartment.
var mode: String = "roof_room" # street | lobby | landing | roof | roof_room | apartment
var floor_id: int = ROOF_FLOOR
var player_local: Vector2 = Vector2(85, 99)
var apartment_rented: bool = false
var night: bool = false
var lamp_on: bool = true
var furniture: Dictionary = {"chair": Vector2(83, 101), "table": Vector2(145, 103)}

static func project(local: Vector2, level: int) -> Vector2:
    return ORIGIN + AXIS_X * local.x + AXIS_Y * local.y - Vector2(0, FLOOR_PIXELS * float(level - 1))

static func apartment_square_metres() -> float:
    return APARTMENT_BOUNDS.get_area() / (PIXELS_PER_METRE * PIXELS_PER_METRE)

static func roof_room_square_metres() -> float:
    return ROOF_ROOM_BOUNDS.get_area() / (PIXELS_PER_METRE * PIXELS_PER_METRE)

func unit_id() -> String:
    if mode == "roof_room":
        return "roof_room_south"
    if mode == "apartment":
        return "unit_south"
    if mode == "landing":
        return "shared_landing"
    return ""

func visible_layers() -> Dictionary:
    return {
        "roof": mode in ["street", "roof", "roof_room"],
        "roof_room": mode in ["street", "roof"],
        "roof_room_cut": mode == "roof_room",
        "upper_facade": mode in ["street", "roof", "roof_room"],
        "lower_facade": true,
        "lobby": mode == "lobby",
        "landing": mode in ["landing", "apartment"],
        "neighbor": mode in ["landing", "apartment"],
        "apartment": mode == "apartment",
        "front_wall_cut": mode == "apartment",
        "front_occluders": mode not in ["apartment", "roof_room"]
    }

func _go(target: String, level: int, position: Vector2) -> bool:
    mode = target
    floor_id = level
    player_local = position
    return true

func leave_roof_room() -> bool:
    if mode != "roof_room": return false
    return _go("roof", ROOF_FLOOR, Vector2(114, 96))

func enter_roof_room() -> bool:
    if mode != "roof": return false
    return _go("roof_room", ROOF_FLOOR, Vector2(85, 99))

func descend_from_roof() -> bool:
    if mode != "roof": return false
    return _go("landing", PLAYER_FLOOR, Vector2(109, 54))

func ascend_to_roof() -> bool:
    if mode != "landing": return false
    return _go("roof", ROOF_FLOOR, Vector2(114, 96))

func go_to_apartment() -> bool:
    if mode != "landing" or not apartment_rented: return false
    return _go("apartment", PLAYER_FLOOR, Vector2(114, 85))

func leave_apartment() -> bool:
    if mode != "apartment": return false
    return _go("landing", PLAYER_FLOOR, Vector2(109, 54))

func enter_building() -> bool:
    if mode != "street": return false
    return _go("lobby", 0, Vector2(45, 70))

func go_to_landing() -> bool:
    if mode != "lobby": return false
    return _go("landing", PLAYER_FLOOR, Vector2(109, 54))

func exit_building() -> bool:
    if mode != "lobby": return false
    return _go("street", -1, Vector2(86, 58))

func descend_to_lobby() -> bool:
    if mode != "landing": return false
    return _go("lobby", 0, Vector2(45, 70))

func rent_apartment_for_spike() -> void:
    # QA-only progression switch; NO rent economy implemented yet.
    apartment_rented = true

func _inside(rect: Rect2, point: Vector2, margin: float) -> bool:
    return point.x >= rect.position.x + margin and point.x <= rect.end.x - margin and point.y >= rect.position.y + margin and point.y <= rect.end.y - margin

func is_walkable(point: Vector2) -> bool:
    if mode == "apartment":
        if not _inside(APARTMENT_BOUNDS, point, 8): return false
        for location in furniture.values():
            if point.distance_to(location) < 13: return false
        return true
    if mode == "roof_room":
        return _inside(ROOF_ROOM_BOUNDS, point, 7)
    if mode == "landing":
        return _inside(LANDING_BOUNDS, point, 3)
    return _inside(Rect2(Vector2.ZERO, FOOTPRINT), point, 8)

func move_player(delta: Vector2) -> bool:
    var next: Vector2 = player_local + delta
    if not is_walkable(next): return false
    player_local = next
    return true

func move_furniture(item_id: String, position: Vector2) -> bool:
    if mode != "apartment" or not furniture.has(item_id): return false
    if not _inside(APARTMENT_BOUNDS, position, 13): return false
    if position.distance_to(player_local) < 15: return false
    for key in furniture:
        if key != item_id and position.distance_to(furniture[key]) < 25: return false
    furniture[item_id] = position
    return true

func toggle_night() -> void:
    night = not night

func toggle_lamp() -> bool:
    if mode not in ["roof_room", "apartment"]: return false
    lamp_on = not lamp_on
    return true

func snapshot() -> Dictionary:
    var placements: Dictionary = {}
    for item_id in furniture:
        var p: Vector2 = furniture[item_id]
        placements[item_id] = {"x": p.x, "y": p.y}
    return {
        "version": SAVE_VERSION, "building_id": BUILDING_ID,
        "mode": mode, "floor_id": floor_id, "unit_id": unit_id(),
        "player_local": {"x": player_local.x, "y": player_local.y},
        "night": night, "lamp_on": lamp_on, "apartment_rented": apartment_rented,
        "furniture": placements
    }

func restore(data: Dictionary) -> bool:
    if int(data.get("version", -1)) != SAVE_VERSION or data.get("building_id", "") != BUILDING_ID: return false
    var m: String = str(data.get("mode", ""))
    var f: int = int(data.get("floor_id", -99))
    var valid: bool = (m == "street" and f == -1) or (m == "lobby" and f == 0) or (
        m in ["landing","apartment"] and f == PLAYER_FLOOR) or (
        m in ["roof","roof_room"] and f == ROOF_FLOOR)
    if not valid: return false
    if m == "apartment" and not bool(data.get("apartment_rented", false)): return false
    var loc: Variant = data.get("player_local")
    var poses: Variant = data.get("furniture")
    if typeof(loc) != TYPE_DICTIONARY or typeof(poses) != TYPE_DICTIONARY: return false
    if not loc.has("x") or not loc.has("y"): return false
    var new_furniture: Dictionary = {}
    for item_id in ["chair", "table"]:
        var item: Variant = poses.get(item_id)
        if typeof(item) != TYPE_DICTIONARY or not item.has("x") or not item.has("y"): return false
        new_furniture[item_id] = Vector2(float(item.x), float(item.y))
    var position := Vector2(float(loc.x), float(loc.y))
    if m == "roof_room" and not _inside(ROOF_ROOM_BOUNDS, position, 7): return false
    if m == "apartment" and not _inside(APARTMENT_BOUNDS, position, 8): return false
    for item in new_furniture.values():
        if not _inside(APARTMENT_BOUNDS, item, 13): return false
    if new_furniture["chair"].distance_to(new_furniture["table"]) < 25: return false
    # Only commit after fully validating; malformed saves never partially mutate world state.
    mode = m
    floor_id = f
    player_local = position
    furniture = new_furniture
    night = bool(data.get("night", false))
    lamp_on = bool(data.get("lamp_on", true))
    apartment_rented = bool(data.get("apartment_rented", false))
    return true

func save_to_file(path: String) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null: return false
    file.store_string(JSON.stringify(snapshot()))
    file.close()
    return true

func load_from_file(path: String) -> bool:
    if not FileAccess.file_exists(path): return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return typeof(parsed) == TYPE_DICTIONARY and restore(parsed)
