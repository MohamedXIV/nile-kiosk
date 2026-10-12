extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://scenes/ink_boot.tscn")
    var instance: Control = scene.instantiate()
    root.add_child(instance)
    var succeeded: bool = await instance.finished
    if succeeded:
        print("D001 P2 Ink native boot: PASS")
        quit(0)
    else:
        push_error("D001 P2 Ink native boot: FAIL")
        quit(1)
