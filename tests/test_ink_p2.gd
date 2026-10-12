extends SceneTree
## Real InkPlayer instances with authored and compiled Ink stories.
## English-only D001 P2 integration gates, not Web or save/load parity.

const Orchestrator = preload("res://scripts/ink_conversation_orchestrator.gd")
const Core = preload("res://scripts/conversation_orchestrator.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    await _test_ignored()
    await _test_player_choice_and_independence()
    await _test_rumor_and_cooking()
    if failures.is_empty():
        print("D001 P2 Ink sessions: PASS (3 test groups)")
        quit(0)
    else:
        for message in failures:
            push_error(message)
        print("D001 P2 Ink sessions: FAIL (%d assertions)" % failures.size())
        quit(1)

func _check(success: bool, message: String) -> void:
    if not success:
        failures.append(message)

func _await_ready(world) -> void:
    for i in range(90):
        if world.sessions["football"].ready and world.sessions["rumor"].ready:
            return
        if world.sessions["football"].load_failed or world.sessions["rumor"].load_failed:
            break
        await process_frame
    _check(false, "InkPlayer story load timed out or failed")

func _advance(world, ticks: int) -> void:
    for i in range(ticks):
        world.advance_async(0.25)

func _has(world, kind: String, sid: String = "") -> bool:
    for item in world.events:
        if item.get("kind") == kind and (sid.is_empty() or item.get("session") == sid):
            return true
    return false

func _test_ignored() -> void:
    var world = Orchestrator.new()
    await _await_ready(world)
    world.player_position = Core.TABLE_A
    _advance(world, 50)
    _check(not _has(world, "choice"), "Expert choice was offered with no match knowledge")
    _check(world.sessions["football"].phase == "finished", "Football did not finish when ignored")
    _check(world.sessions["rumor"].phase == "finished", "Rumor did not finish when ignored")
    world.dispose()

func _test_player_choice_and_independence() -> void:
    var world = Orchestrator.new()
    await _await_ready(world)
    world.player_position = Core.TABLE_A
    world.grant_match_knowledge()
    for i in range(20):
        world.advance_async(0.25)
        if world.sessions["football"].phase == "choice":
            break
    _check(world.sessions["football"].phase == "choice", "Ink did not expose gated choice")
    var waiting_lines: int = world.sessions["football"].line_count
    var rumor_lines: int = world.sessions["rumor"].line_count
    _advance(world, 4)
    _check(world.sessions["football"].line_count == waiting_lines, "A advanced during pending choice")
    _check(world.sessions["rumor"].line_count > rumor_lines, "B did not advance during A's choice")
    _check(world.interject(), "Eligible Ink interjection denied")
    _advance(world, 40)
    _check(world.sessions["football"].phase == "finished", "Ink A not finished after choice")
    _check(world.sessions["rumor"].phase == "finished", "Ink B not finished")
    _check(_has(world, "interjection", "football"), "Ink choice event missing")
    var reaction := false
    var rejoined := false
    for item in world.events:
        if item.get("speaker") == "Mahmoud" and item.get("text") == "Finally, somebody gets it!":
            reaction = true
        if item.get("speaker") == "Samir" and item.get("text") == "Next Thursday, we'll see.":
            rejoined = true
    _check(reaction and rejoined, "Ink choice did not produce reaction+rejoin")
    world.dispose()

func _test_rumor_and_cooking() -> void:
    var world = Orchestrator.new()
    await _await_ready(world)
    world.player_position = Core.TABLE_B
    _advance(world, 40)
    _check(world.game_state.has_fact("hassan_shop_rumor"), "Ink rumor fact did not reach GameState")
    var fact_count := 0
    for item in world.events:
        if item.get("kind") == "fact" and item.get("fact") == "hassan_shop_rumor":
            fact_count += 1
    _check(fact_count == 1, "Ink rumor fact not idempotent")
    world.player_position = Core.COUNTER
    for i in range(3):
        _check(world.prepare_tea_step(), "Tea step refused")
        world.advance_async(0.25)
    _check(_has(world, "tea_served"), "Tea didn't finish")
    world.dispose()
