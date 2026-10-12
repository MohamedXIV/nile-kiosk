extends SceneTree
## D001 P3 disk-backed persistence. Identical scenario and assertions for BOTH real addons.

const Codec = preload("res://scripts/spike_save_codec.gd")
const DM = preload("res://scripts/dm_conversation_orchestrator.gd")
const Ink = preload("res://scripts/ink_conversation_orchestrator.gd")
const Core = preload("res://scripts/conversation_orchestrator.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    await _check_engine("dm", DM)
    await _check_engine("ink", Ink)
    if failures.is_empty():
        print("D001 P3 Save/Load: PASS (2 engines, pending-choice, rumor effects, replay, finished state)")
        quit(0)
    else:
        for message in failures:
            push_error(message)
        print("D001 P3 Save/Load: FAIL (%d assertions)" % failures.size())
        quit(1)

func _check(value: bool, detail: String) -> void:
    if not value:
        failures.append(detail)

func _wait_ready(world, engine_id: String) -> bool:
    if engine_id != "ink":
        return true
    for i in range(120):
        if world.sessions["football"].ready and world.sessions["rumor"].ready:
            return true
        if world.sessions["football"].load_failed or world.sessions["rumor"].load_failed:
            return false
        await process_frame
    return false

func _advance(world, ticks: int) -> void:
    for i in range(ticks):
        await world.advance_async(0.25)

func _count_fact(world, fact_id: String) -> int:
    var count: int = 0
    for event in world.events:
        if event.get("kind") == "fact" and event.get("fact") == fact_id:
            count += 1
    return count

func _check_engine(engine_id: String, Factory) -> void:
    var original = Factory.new()
    if not await _wait_ready(original, engine_id):
        _check(false, engine_id + " initial story failed to load")
        return

    original.player_position = Core.TABLE_A
    original.grant_match_knowledge()
    for i in range(20):
        await original.advance_async(0.25)
        if original.sessions["football"].phase == "choice":
            break
    _check(original.sessions["football"].phase == "choice", engine_id + " failed to reach pending choice")
    _check(original.sessions["rumor"].phase == "running", engine_id + " B not active at A choice")

    var mid: Dictionary = Codec.snapshot(original, engine_id)
    var path: String = "user://d001_%s_save.json" % engine_id
    _check(Codec.write_json(path, mid), engine_id + " failed saving to disk")
    var disk: Dictionary = Codec.read_json(path)
    _check(not disk.is_empty(), engine_id + " failed reading JSON disk save")
    _check(not Codec.restore(Factory.new() if engine_id == "dm" else original, disk, "wrong_engine"),
        engine_id + " accepted wrong engine snapshot")

    var restored = Factory.new()
    if not await _wait_ready(restored, engine_id):
        _check(false, engine_id + " restore story load failed")
        return
    _check(Codec.restore(restored, disk, engine_id), engine_id + " refused valid disk save")
    _check(restored.sessions["football"].phase == "choice", engine_id + " lost pending choice")
    if JSON.stringify(restored.events) != JSON.stringify(original.events):
        print(engine_id, " LOAD_TRACE_ORIGINAL: ", JSON.stringify(original.events))
        print(engine_id, " LOAD_TRACE_RESTORED: ", JSON.stringify(restored.events))
    _check(JSON.stringify(restored.events) == JSON.stringify(original.events), engine_id + " lost past event log")
    _check(restored.game_state.has_fact("knows_match"), engine_id + " lost player match knowledge")
    _check(restored.tick_number == original.tick_number, engine_id + " lost world clock")

    # Hear the independent B rumor while A is still offering the original choice.
    original.player_position = Core.TABLE_B
    restored.player_position = Core.TABLE_B
    for i in range(12):
        await original.advance_async(0.25)
        await restored.advance_async(0.25)
        if original.game_state.has_fact("hassan_shop_rumor"):
            break
    _check(original.game_state.has_fact("hassan_shop_rumor"), engine_id + " B rumor was not heard")
    _check(original.sessions["football"].phase == "choice", engine_id + " A choice expired before rumor")
    _check(_count_fact(original, "hassan_shop_rumor") == 1, engine_id + " recorded duplicate rumor")
    _check(JSON.stringify(restored.events) == JSON.stringify(original.events), engine_id + " diverged while B advanced")

    original.player_position = Core.TABLE_A
    restored.player_position = Core.TABLE_A
    var with_rumor: Dictionary = Codec.snapshot(original, engine_id)
    _check(Codec.write_json(path, with_rumor), engine_id + " could not save after rumor")
    var after_rumor = Factory.new()
    if not await _wait_ready(after_rumor, engine_id):
        _check(false, engine_id + " second restore story load failed")
        return
    _check(Codec.restore(after_rumor, Codec.read_json(path), engine_id), engine_id + " could not restore learned rumor")
    _check(after_rumor.game_state.has_fact("hassan_shop_rumor"), engine_id + " lost rumor after load")
    _check(not after_rumor.game_state.grant_fact("hassan_shop_rumor", "heard:rumor:hassan_shop_rumor"),
        engine_id + " replayed canonical knowledge effect")
    _check(original.interject(), engine_id + " original interjection failed")
    _check(restored.interject(), engine_id + " restored interjection failed")
    _check(after_rumor.interject(), engine_id + " second restored interjection failed")
    await _advance(original, 30)
    await _advance(restored, 30)
    await _advance(after_rumor, 30)
    _check(JSON.stringify(original.events) == JSON.stringify(restored.events), engine_id + " resumed trace mismatch")
    _check(JSON.stringify(original.events) == JSON.stringify(after_rumor.events), engine_id + " second resumed trace mismatch")
    _check(original.sessions["football"].phase == "finished", engine_id + " football not finished after restore")
    _check(original.sessions["rumor"].phase == "finished", engine_id + " rumor not finished after restore")
    _check(_count_fact(restored, "hassan_shop_rumor") == 1, engine_id + " rumor duplicated after restore")

    var done_save: Dictionary = Codec.snapshot(original, engine_id)
    var done_world = Factory.new()
    if not await _wait_ready(done_world, engine_id):
        _check(false, engine_id + " finished restore story load failed")
        return
    _check(Codec.restore(done_world, done_save, engine_id), engine_id + " finished session restore rejected")
    var count_before: int = done_world.events.size()
    await _advance(done_world, 8)
    _check(done_world.events.size() == count_before, engine_id + " replayed finished conversation after restore")
    _check(_count_fact(done_world, "hassan_shop_rumor") == 1, engine_id + " replayed rumor on finished restore")
    if engine_id == "ink":
        original.dispose()
        restored.dispose()
        after_rumor.dispose()
        done_world.dispose()
    var absolute_path: String = ProjectSettings.globalize_path(path)
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(absolute_path)
