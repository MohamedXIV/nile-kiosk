extends SceneTree
const Cases = preload("res://tests/cooking_depth_cases.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var failures: Array[String] = Cases.new().run()
    quit(0 if failures.is_empty() else 1)
