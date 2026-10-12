extends Control
## Minimal real InkPlayer Web boot test, explicitly single-threaded.
## Uses a published compiled upstream inkgd fixture (true.ink.json).
## The compiled story MUST actually load and continue before printing PASS.

signal finished(success: bool)

const COMPILED_INK_JSON := '{"inkVersion":21,"root":[["ev",true,"out","/ev","\\n",["done",{"#n":"g-0"}],null],"done",null],"listDefs":{}}'

var _player: Node

func _ready() -> void:
    var player_script: GDScript = load("res://addons/inkgd/ink_player.gd")
    var resource_script: GDScript = load("res://addons/inkgd/editor/import_plugins/ink_resource.gd")
    if player_script == null or resource_script == null:
        _fail("Missing inkgd runtime classes")
        return

    _player = player_script.new()
    # Web single-threaded export: do not use background loading.
    _player.loads_in_background = false
    var ink_resource: Resource = resource_script.new()
    ink_resource.set("json", COMPILED_INK_JSON)
    _player.ink_file = ink_resource
    _player.loaded.connect(_on_story_loaded)
    _player.exception_raised.connect(_on_story_exception)
    add_child(_player)
    _player.create_story()

func _on_story_loaded(success: bool) -> void:
    if not success:
        _fail("InkPlayer emitted loaded(false)")
        return
    var result: String = _player.continue_story().strip_edges()
    if result.is_empty():
        _fail("InkPlayer loaded but could not continue a compiled Ink story")
        return
    $Status.text = "INK WEB BOOT PASS: " + result
    print("INK_WEB_BOOT_PASS: " + result)
    finished.emit(true)

func _on_story_exception(message: String, _stack_trace: Variant) -> void:
    _fail("InkPlayer exception: " + message)

func _fail(reason: String) -> void:
    $Status.text = "INK WEB BOOT FAIL: " + reason
    push_error("INK_WEB_BOOT_FAIL: " + reason)
    finished.emit(false)
