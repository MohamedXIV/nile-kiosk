extends SceneTree
## Tests the *real* Dialogue Manager imported .dialogue files and runtime.
## English-only fixture. Browser and save/load acceptance remain separate.

const Orchestrator = preload("res://scripts/dm_conversation_orchestrator.gd")
const Core = preload("res://scripts/conversation_orchestrator.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    await _check_uninformed_and_independent()
    await _check_choice_and_rejoin()
    await _check_knowledge_cooking_and_determinism()
    if failures.is_empty():
        print("D001 P1 Dialogue Manager: PASS (3 test groups)")
        quit(0)
    else:
        for msg in failures:
            push_error(msg)
        print("D001 P1 Dialogue Manager: FAIL (%d assertions)" % failures.size())
        quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _run_ticks(world, count: int) -> void:
    for i in range(count):
        await world.advance_async(0.25)

func _has_event(world, kind: String, session_id: String = "") -> bool:
    for e in world.events:
        if e.get("kind") == kind and (session_id.is_empty() or e.get("session") == session_id):
            return true
    return false

func _check_uninformed_and_independent() -> void:
    var world = Orchestrator.new()
    world.player_position = Core.TABLE_A
    await _run_ticks(world, 45)
    _check(not _has_event(world, "choice", "football"), "Uninformed player received gated interjection")
    _check(world.sessions["football"].phase == "finished", "A not finished when ignored")
    _check(world.sessions["rumor"].phase == "finished", "B not finished independently")
    _check(_has_event(world, "line", "football"), "A has no authentic plugin lines")
    _check(_has_event(world, "line", "rumor"), "B has no authentic plugin lines")

func _check_choice_and_rejoin() -> void:
    var world = Orchestrator.new()
    world.player_position = Core.TABLE_A
    world.grant_match_knowledge()
    await _run_ticks(world, 4)
    _check(world.sessions["football"].phase == "choice", "Expected an authored response window in A")
    var waiting_cursor: String = world.sessions["football"].next_id
    var rumor_cursor: String = world.sessions["rumor"].next_id
    await _run_ticks(world, 7)
    _check(world.sessions["football"].next_id == waiting_cursor, "A progressed while choice pending")
    _check(world.sessions["rumor"].next_id != rumor_cursor, "B did not advance while A waited")
    _check(world.interject(), "Interjection rejected despite proximity/knowledge")
    await _run_ticks(world, 25)
    _check(world.sessions["football"].phase == "finished", "A did not finish after interjection")
    _check(world.sessions["rumor"].phase == "finished", "B did not finish after interjection")
    _check(_has_event(world, "interjection", "football"), "Chosen interjection missing")
    var saw_reaction := false
    var saw_rejoin := false
    for event in world.events:
        if event.get("speaker") == "Mahmoud" and event.get("text") == "Finally, somebody gets it!":
            saw_reaction = true
        if event.get("speaker") == "Samir" and event.get("text") == "Next Thursday, we'll see.":
            saw_rejoin = true
    _check(saw_reaction and saw_rejoin, "Authored reaction/rejoin not both produced")

func _check_knowledge_cooking_and_determinism() -> void:
    var world = Orchestrator.new()
    world.player_position = Core.TABLE_B
    await _run_ticks(world, 40)
    _check(world.game_state.has_fact("hassan_shop_rumor"), "Listening failed to grant canonical rumor fact")
    var facts := 0
    for event in world.events:
        if event.get("kind") == "fact" and event.get("fact") == "hassan_shop_rumor":
            facts += 1
    _check(facts == 1, "Rumor fact emitted more than once")
    world.player_position = Core.COUNTER
    for i in range(3):
        _check(world.prepare_tea_step(), "Tea action rejected at kiosk")
        await world.advance_async(0.25)
    _check(_has_event(world, "tea_served"), "Tea did not finish while dialogues were active")

    var repeat = Orchestrator.new()
    repeat.player_position = Core.TABLE_B
    await _run_ticks(repeat, 40)
    _check(repeat.game_state.has_fact("hassan_shop_rumor"), "Second run lost canonical fact")
    var a: Array[Dictionary] = []
    var b: Array[Dictionary] = []
    for event in world.events:
        if event.get("kind") != "tea_step" and event.get("kind") != "tea_served":
            a.append(event)
    for event in repeat.events:
        b.append(event)
    _check(JSON.stringify(a) == JSON.stringify(b), "Event replay differed for identical inputs before tea")
