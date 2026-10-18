extends SceneTree
const Cases = preload("res://tests/e2_closure_cases.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var errors: Array[String] = Cases.new().run()
    quit(0 if errors.is_empty() else 1)
