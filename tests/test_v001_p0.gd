extends SceneTree
## Deterministic blockout gates, distinct from visual art acceptance.

const Model = preload("res://scripts/v001/building_model.gd")
var failures: Array[String] = []

func _initialize() -> void:
    _test_projection_and_floors()
    _test_visibility_and_navigation()
    _test_collision_and_furniture()
    _test_disk_persistence()
    if failures.is_empty():
        print("V001 P0: PASS (4 logical test groups)")
        quit(0)
    else:
        for error in failures:
            push_error(error)
        print("V001 P0: FAIL (%d assertions)" % failures.size())
        quit(1)

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func _test_projection_and_floors() -> void:
    var at: Vector2 = Vector2(60, 82)
    var lower: Vector2 = Model.project(at, 3)
    var upper: Vector2 = Model.project(at, 4)
    _check(is_equal_approx(lower.x, upper.x), "Floor change should not shift X in fixed oblique projection")
    _check(is_equal_approx(lower.y - upper.y, Model.FLOOR_PIXELS), "Floor visual offset is not consistent")
    var east: Vector2 = Model.project(at + Vector2(12, 0), 4)
    var south: Vector2 = Model.project(at + Vector2(0, 12), 4)
    _check(east.x > upper.x and south.x < upper.x, "Projection is not oblique/dimetric")

func _test_visibility_and_navigation() -> void:
    var world = Model.new()
    _check(world.visible_layers().roof and world.visible_layers().upper_facade, "Exterior must display roof and facade")
    _check(not world.go_to_apartment(), "Cannot teleport directly to apartment from street")
    _check(world.enter_building() and world.floor_id == 0, "Street entry did not reach ground lobby")
    _check(not world.visible_layers().roof, "Lobby should not show full exterior roof")
    _check(world.go_to_apartment() and world.floor_id == Model.PLAYER_FLOOR, "Stairs failed to reach chosen logical floor")
    _check(world.visible_layers().apartment and not world.visible_layers().front_occluders,
        "Cutaway must reveal apartment and hide obstructing facade")
    _check(world.leave_apartment() and world.floor_id == 0, "Leaving apartment did not restore lobby")
    _check(world.exit_building() and world.floor_id == -1 and world.visible_layers().roof,
        "Street exit did not restore full exterior")

func _test_collision_and_furniture() -> void:
    var world = Model.new()
    world.enter_building()
    world.go_to_apartment()
    var old: Vector2 = world.furniture["chair"]
    _check(not world.move_furniture("chair", Vector2(3, 3)), "Furniture moved outside walls")
    _check(not world.move_furniture("chair", world.furniture["table"]), "Furniture overlapped table")
    _check(not world.move_player(Vector2(-300, -300)), "Player walked outside apartment")
    _check(world.move_furniture("chair", Vector2(52, 100)), "Valid chair placement refused")
    _check(world.furniture["chair"] != old, "Chair move failed to change canonical placement")
    _check(world.furniture["table"] == Vector2(129, 84), "Moving chair unexpectedly moved table")
    _check(not world.is_walkable(world.furniture["chair"]), "Furniture has no collision")

func _test_disk_persistence() -> void:
    var world = Model.new()
    world.enter_building()
    world.go_to_apartment()
    world.move_furniture("chair", Vector2(52, 100))
    world.toggle_night()
    var saved_at: String = "user://v001-p0-test.json"
    _check(world.save_to_file(saved_at), "Couldn't write V001 JSON")
    var restored = Model.new()
    _check(restored.load_from_file(saved_at), "Couldn't restore V001 JSON")
    _check(restored.mode == "apartment" and restored.floor_id == Model.PLAYER_FLOOR,
        "Floor/view were lost across save")
    _check(restored.furniture["chair"] == Vector2(52, 100), "Moved chair placement did not persist")
    _check(restored.furniture["table"] == Vector2(129, 84), "Unmoved table placement changed after restore")
    _check(restored.night and not restored.visible_layers().roof, "Night/cutaway state not restored")
    var before: Dictionary = restored.snapshot()
    _check(not restored.restore({"version": 1, "building_id": "different"}), "Invalid building save was accepted")
    _check(restored.snapshot() == before, "Invalid save partially modified building")
    if FileAccess.file_exists(saved_at):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_at))
