extends SceneTree
const Ambient = preload("res://scripts/gameplay/ambient_soundscape.gd")
const SETTINGS = "user://nile-kiosk-sound.cfg"
var failures: Array[String] = []
func check(ok: bool, why: String) -> void:
    if not ok: failures.append(why)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    if FileAccess.file_exists(SETTINGS):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
    var a: Node = Ambient.new()
    root.add_child(a)
    await process_frame
    check(a.enabled, "sound-on default")
    check(a.voice is AudioStreamPlayer, "real Godot audio stream player absent")
    check(a.voice.stream is AudioStreamGenerator, "missing runtime-generated nonlicensed sound stream")
    a.set_context("roof", false, false)
    check(a.room_id == "roof" and not a.kitchen_active, "quiet rooftop context")
    a.set_context("kiosk", true, false)
    check(a.room_id == "kiosk" and a.kitchen_active, "real-kettle context")
    a.set_context("street", true, true)
    check(a.room_id == "street" and not a.kitchen_active and a.night, "night street and no kettle outside kiosk")
    check(not a.toggle_sound(), "mute failed")
    var settings: ConfigFile = ConfigFile.new()
    check(settings.load(SETTINGS) == OK and not bool(settings.get_value("audio","enabled",true)), "sound-off preference file missing")
    a.queue_free()
    await process_frame
    var b: Node = Ambient.new()
    root.add_child(b)
    await process_frame
    check(not b.enabled, "sound-off setting lost on recreated Godot node")
    check(b.toggle_sound(), "sound could not be re-enabled")
    b.queue_free()
    await process_frame
    if failures.is_empty():
        print("E6 AMBIENCE: PASS")
    else:
        for message in failures: push_error(message)
    quit(0 if failures.is_empty() else 1)
