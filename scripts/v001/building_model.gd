extends RefCounted
## V001: floor-aware logical world and fixed oblique projection.
## No 3D runtime; floor_id is NOT draw z-index or a side-scroller world coordinate.

const BUILDING_ID := "old_cairo_home"
const FLOOR_COUNT: int = 6
const PLAYER_FLOOR: int = 6  # Provisional top residential floor, immediately below roof.
const FOOTPRINT := Vector2(180.0, 132.0)
const ORIGIN := Vector2(490.0, 390.0)
const AXIS_X := Vector2(0.93, 0.45)
const AXIS_Y := Vector2(-0.93, 0.45)
const FLOOR_PIXELS: float = 47.0

var mode: String = "street"  # street | lobby | apartment
var floor_id: int = -1
var player_local := Vector2(86.0, 58.0)
var furniture: Dictionary = {
    "chair": Vector2(45.0, 68.0),
    "table": Vector2(129.0, 84.0)
}
var night: bool = false

static func project(local: Vector2, level: int) -> Vector2:
    # World 2D plane projection + a visual elevation offset.
    return ORIGIN + AXIS_X * local.x + AXIS_Y * local.y - Vector2(0.0, FLOOR_PIXELS * float(level - 1))

func visible_layers() -> Dictionary:
    return {
        "roof": mode == "street",
        "upper_facade": mode == "street",
        "lower_facade": true,
        "lobby": mode == "lobby",
        "apartment": mode == "apartment",
        "front_occluders": mode == "street"
    }

func enter_building() -> bool:
    if mode != "street":
        return false
    mode = "lobby"
    floor_id = 0
    player_local = Vector2(86.0, 58.0)
    return true

func go_to_apartment() -> bool:
    if mode != "lobby":
        return false
    mode = "apartment"
    floor_id = PLAYER_FLOOR
    player_local = Vector2(86.0, 58.0)
    return true

func leave_apartment() -> bool:
    if mode != "apartment":
        return false
    mode = "lobby"
    floor_id = 0
    return true

func exit_building() -> bool:
    if mode != "lobby":
        return false
    mode = "street"
    floor_id = -1
    return true

func is_walkable(point: Vector2) -> bool:
    if mode != "apartment":
        return true
    if point.x < 12.0 or point.y < 12.0 or point.x > FOOTPRINT.x - 12.0 or point.y > FOOTPRINT.y - 12.0:
        return false
    for item in furniture.values():
        if point.distance_to(item) < 17.0:
            return false
    return true

func move_player(delta: Vector2) -> bool:
    if mode != "apartment":
        player_local += delta
        player_local = player_local.clamp(Vector2(15.0, 15.0), FOOTPRINT - Vector2(15.0, 15.0))
        return true
    var next: Vector2 = player_local + delta
    if not is_walkable(next):
        return false
    player_local = next
    return true

func move_furniture(item_id: String, position: Vector2) -> bool:
    if mode != "apartment" or not furniture.has(item_id):
        return false
    if position.x < 22.0 or position.y < 22.0 or position.x > FOOTPRINT.x - 22.0 or position.y > FOOTPRINT.y - 22.0:
        return false
    if position.distance_to(player_local) < 17.0:
        return false
    for key in furniture.keys():
        if key != item_id and position.distance_to(furniture[key]) < 32.0:
            return false
    furniture[item_id] = position
    return true

func toggle_night() -> void:
    night = not night

func snapshot() -> Dictionary:
    var placements: Dictionary = {}
    for item_id in furniture.keys():
        var pos: Vector2 = furniture[item_id]
        placements[item_id] = {"x": pos.x, "y": pos.y}
    return {
        "version": 1,
        "building_id": BUILDING_ID,
        "mode": mode,
        "floor_id": floor_id,
        "player_local": {"x": player_local.x, "y": player_local.y},
        "night": night,
        "furniture": placements
    }

func restore(data: Dictionary) -> bool:
    if int(data.get("version", -1)) != 1 or data.get("building_id", "") != BUILDING_ID:
        return false
    var saved_mode: String = str(data.get("mode", ""))
    var saved_floor: int = int(data.get("floor_id", -100))
    if not ((saved_mode == "street" and saved_floor == -1)
            or (saved_mode == "lobby" and saved_floor == 0)
            or (saved_mode == "apartment" and saved_floor == PLAYER_FLOOR)):
        return false
    var loc: Dictionary = data.get("player_local", {})
    var placements: Dictionary = data.get("furniture", {})
    if not loc.has("x") or not loc.has("y") or not placements.has("chair") or not placements.has("table"):
        return false
    mode = saved_mode
    floor_id = saved_floor
    night = bool(data.get("night", false))
    player_local = Vector2(float(loc.x), float(loc.y))
    for item_id in ["chair", "table"]:
        var item: Dictionary = placements[item_id]
        furniture[item_id] = Vector2(float(item.x), float(item.y))
    return true

func save_to_file(path: String) -> bool:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(snapshot()))
    file.close()
    return true

func load_from_file(path: String) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return typeof(parsed) == TYPE_DICTIONARY and restore(parsed)
