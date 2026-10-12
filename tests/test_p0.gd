extends SceneTree
## Pure headless deterministic tests — no third-party dialogue engines yet.

const Orchestrator = preload("res://scripts/conversation_orchestrator.gd")
var failures: Array[String] = []

func _initialize() -> void:
    _test_uninformed_player()
    _test_concurrency_and_interjection()
    _test_knowledge_and_tea()
    _test_determinism()
    if failures.is_empty():
        print("D001 P0: PASS (4 test groups)")
        quit(0)
    else:
        for message in failures:
            push_error(message)
        print("D001 P0: FAIL (%d checks)" % failures.size())
        quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _run_ticks(world, count: int) -> void:
    for i in range(count):
        world.advance(0.25)

func _has_event(world, event_kind: String, session_id: String = "") -> bool:
    for item in world.events:
        if item.get("kind") == event_kind and (session_id.is_empty() or item.get("session") == session_id):
            return true
    return false

func _test_uninformed_player() -> void:
    var world = Orchestrator.new()
    world.player_position = Orchestrator.TABLE_A
    _run_ticks(world, 50)
    _check(not _has_event(world, "choice"), "Uninformed player received expert choice")
    _check(world.sessions["football"].phase == "finished", "Football should finish without a player's participation")
    _check(world.sessions["rumor"].phase == "finished", "Rumor should finish independently")

func _test_concurrency_and_interjection() -> void:
    var world = Orchestrator.new()
    world.player_position = Orchestrator.TABLE_A
    world.grant_match_knowledge()
    _run_ticks(world, 8)
    _check(world.sessions["football"].phase == "choice", "Knowledgeable nearby player should get an interjection window")
    var previous_a: int = world.sessions["football"].cursor
    var previous_b: int = world.sessions["rumor"].cursor
    _run_ticks(world, 6)
    _check(world.sessions["football"].cursor == previous_a, "A advanced while awaiting player's choice")
    _check(world.sessions["rumor"].cursor > previous_b, "B did not advance while A waited for choice")
    _check(world.interject(), "Valid interjection was rejected")
    _run_ticks(world, 12)
    _check(_has_event(world, "interjection", "football"), "Missing selected interjection event")
    _check(world.sessions["football"].phase == "finished", "A failed to rejoin/finish after selected interjection")
    _check(world.sessions["rumor"].phase == "finished", "B failed to finish independently")

func _test_knowledge_and_tea() -> void:
    var world = Orchestrator.new()
    world.player_position = Orchestrator.TABLE_B
    _run_ticks(world, 40)
    _check(world.game_state.has_fact("hassan_shop_rumor"), "Rumor not recorded when heard")
    var count: int = 0
    for item in world.events:
        if item.get("kind") == "fact" and item.get("fact") == "hassan_shop_rumor":
            count += 1
    _check(count == 1, "Rumor fact should be emitted only once")
    _check(not world.game_state.grant_fact("hassan_shop_rumor", "heard:rumor:hassan_shop_rumor"), "Repeated effect applied twice")
    world.player_position = Orchestrator.COUNTER
    for i in range(3):
        _check(world.prepare_tea_step(), "Tea step failed at counter")
        world.advance(0.25)
    _check(_has_event(world, "tea_served", "world"), "Tea was not served")
    _check(world.tea_steps == 0, "Tea steps did not reset")

func _test_determinism() -> void:
    var a = Orchestrator.new()
    var b = Orchestrator.new()
    a.player_position = Orchestrator.TABLE_B
    b.player_position = Orchestrator.TABLE_B
    _run_ticks(a, 40)
    _run_ticks(b, 40)
    _check(JSON.stringify(a.events) == JSON.stringify(b.events), "Identical simulation runs yielded different traces")
