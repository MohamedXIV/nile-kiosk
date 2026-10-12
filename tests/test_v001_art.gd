extends SceneTree
## Test actual imported Blender textures and exact projection alignment, not aesthetics.

const Building = preload("res://scripts/v001/building_model.gd")
const ArtView = preload("res://scenes/building_cutaway_spike.tscn")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var path := "res://assets/v001/manifest.json"
    if not FileAccess.file_exists(path):
        push_error("V001 P1 manifest missing")
        quit(1)
        return
    var obj: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(obj) != TYPE_DICTIONARY:
        push_error("V001 P1 manifest invalid")
        quit(1)
        return
    var expect: Dictionary = {"origin": Vector2(490,390), "axis_x": Vector2(11.16,5.4),
        "axis_y": Vector2(-11.16,5.4), "floor_delta": Vector2(0,-47)}
    for key in expect.keys():
        var samples: Array = obj["projection"][key]
        if Vector2(float(samples[0]), float(samples[1])).distance_to(expect[key]) > 1.5:
            push_error("V001 P1 camera registration mismatch " + key)
            quit(1)
            return
    for layer in ["facade_lower","facade_upper","roof","apartment","lobby","chair","table"]:
        for time in ["day","night"]:
            var texture: Texture2D = load("res://assets/v001/%s_%s.png" % [layer,time])
            if texture == null or texture.get_size() != Vector2(960,540):
                push_error("V001 P1 texture missing or wrong-sized: " + layer + "_" + time)
                quit(1)
                return
    var instance = ArtView.instantiate()
    root.add_child(instance)
    if not instance._has_baked_art():
        push_error("V001 P1 did not use baked textures")
        quit(1)
        return
    instance.model.enter_building()
    instance.model.go_to_apartment()
    instance.model.toggle_night()
    if not instance._has_baked_art():
        push_error("V001 P1 missing night variant")
        quit(1)
        return
    var before: Vector2 = Building.project(instance.model.furniture["chair"], Building.PLAYER_FLOOR)
    if not instance.model.move_furniture("chair", Vector2(52,100)):
        push_error("V001 P1 chair placement refused")
        quit(1)
        return
    var after: Vector2 = Building.project(instance.model.furniture["chair"], Building.PLAYER_FLOOR)
    if before.distance_to(after) < 1.0:
        push_error("V001 P1 translated chair not moving")
        quit(1)
        return
    print("V001 P1 ART REGISTRATION PASS (14 imported textures, day/night, camera and furniture)")
    instance.queue_free()
    await process_frame
    quit(0)
