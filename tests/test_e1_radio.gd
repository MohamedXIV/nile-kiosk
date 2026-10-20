extends SceneTree
## E1/P2: radio is an owned, purchased, placed P5 item — no free radio hotkey.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const WorldState = preload("res://scripts/core/world_state.gd")
const SAVE = "user://nk-radio-player-test.json"
const OLD_SAVE = "user://nk-radio-pre-p2-v9.json"
var failures: Array[String] = []

func _initialize() -> void:
    run()
    for error in failures: push_error(error)
    print("E1 RADIO: PASS (real purchase, place/use/store, time, reload and old-save adoption)" if failures.is_empty() else "E1 RADIO: FAIL (%d)" % failures.size())
    quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
    if not ok: failures.append(message)

func run() -> void:
    for file in [SAVE, OLD_SAVE]:
        if FileAccess.file_exists(file):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
    var g: RefCounted = Game.new()
    check(g.start(SAVE).get("code","") == "NEW_WORLD", "new game")
    check(g.status()["radio_owned"] == false and g.status()["radio_placed"] == false, "unearned radio")
    check(g.status()["money"] == 6000, "starter funds intact")
    check(g.listen_radio().get("code") == "REQUIRED_OBJECT_NOT_PLACED", "phantom radio listening")
    var unchanged: String = g.status()["digest"]
    check(g.session.command("bad:radio:actor","system:director","life.activity",{"activity_id":"radio_listen"}).get("code") == "INVALID_PLAYER_ACTION","forged actor")
    check(g.status()["digest"] == unchanged, "phantom radio mutated world")

    # An old, valid v9 save before radio type/catalog extension adopts exactly once.
    var earlier: RefCounted = WorldState.new(71)
    var n: int = 0
    for event in g.session.world.view()["events"]:
        if event["kind"] == "home.type_defined" and event["payload"]["request"]["type_id"] == "portable_radio":
            break
        check(earlier._apply_event(event),"replay pre-radio history")
        n += 1
    check(n > 20 and not earlier.snapshot()["housing"]["types"].has("portable_radio"),"old snapshot has no radio")
    var old: RefCounted = Kernel.new()
    check(old.restore_snapshot(earlier.snapshot()),"old v9 valid")
    check(old.save_to_file(OLD_SAVE),"write old v9")
    var adopted: RefCounted = Game.new()
    check(adopted.start(OLD_SAVE).get("code","")=="RESTORED","old save restored")
    check(adopted.quiet_activities().size()==3 and adopted.session.world.housing_view()["types"].has("portable_radio"),"radio adoption")
    check(adopted.status()["radio_owned"]==false and adopted.status()["money"]==6000,"migration gifted radio or charged cash")
    check(adopted.save_game().get("ok",false),"save adopted radio")
    var applied_count: int = int(adopted.session.world.view()["sequence"])
    var adopted_twice: RefCounted = Game.new()
    check(adopted_twice.start(OLD_SAVE).get("code","")=="RESTORED","adopted reload")
    check(int(adopted_twice.session.world.view()["sequence"]) == applied_count,"duplicate catalog insertion")
    check(adopted_twice.status()["money"]==6000,"catalog altered cash")

    check(g.buy_radio().get("ok",false),"radio purchase")
    check(g.status()["money"]==4800 and g.status()["radio_owned"] and not g.status()["radio_placed"],"ledger purchase and stored ownership")
    var purchased: String = g.status()["digest"]
    check(g.buy_radio().get("code")=="OBJECT_EXISTS","second radio purchase")
    check(g.status()["digest"]==purchased,"duplicate charge occurred")
    check(g.listen_radio().get("code")=="REQUIRED_OBJECT_NOT_PLACED","listen before placing")
    check(g.place_radio().get("ok",false),"place radio in owned rooftop home")
    check(g.status()["radio_placed"],"placed radio not visible in projection")
    check(g.place_radio().get("code")=="OBJECT_NOT_STORED","duplicate place")
    check(g.listen_radio().get("ok",false),"listen placed radio")
    check(g.status()["radio_uses"]==1 and g.status()["quiet_count"]==1,"single radio use and event")
    check(g.status()["money"]==4800 and g.status()["minute"]==1002,"radio cost and authored minutes")
    check(g.status()["npc_mahmoud"]=="kiosk" and g.status()["offer_count"]==0,"scheduled NPC continues but closed demand suppressed")
    var listened_id: String = str(g.session.world.view()["events"][-1]["command_id"])
    var listened_digest: String = g.status()["digest"]
    check(g.session.command(listened_id,"player","life.activity",{"activity_id":"radio_listen"}).get("ok",false),"listen receipt")
    check(g.status()["digest"]==listened_digest and g.status()["radio_uses"]==1,"repeat use duplicated")
    check(g.store_radio().get("ok",false),"store placed radio")
    check(g.listen_radio().get("code")=="REQUIRED_OBJECT_NOT_PLACED","stored radio played")
    check(g.status()["radio_uses"]==1,"stored use count changed")
    check(g.place_radio().get("ok",false),"replace stored radio")
    for i in range(5):
        check(g.move_world(-18,0).get("ok",false),"walk away %d" % i)
    check(g.listen_radio().get("code")=="TOO_FAR","radio works across entire room")
    for i in range(5):
        check(g.move_world(18,0).get("ok",false),"walk home %d" % i)
    check(g.listen_radio().get("ok",false),"second local radio play")
    check(g.status()["radio_uses"]==2 and g.status()["quiet_count"]==2,"second use")
    check(g.sleep_at_home().get("ok",false),"sleep with owned radio")
    check(g.status()["day"]==2 and g.status()["radio_placed"],"radio persists next morning")
    check(g.save_game().get("ok",false),"verify disk save")
    var saved: String = g.status()["digest"]
    var reloaded: RefCounted = Game.new()
    check(reloaded.start(SAVE).get("code","")=="RESTORED","reopen game")
    check(reloaded.status()["digest"]==saved and reloaded.status()["radio_uses"]==2 and reloaded.status()["radio_placed"],"radio room/use/save lost")
    var forged: Dictionary = reloaded.session.world.view()
    forged["housing"]["objects"]["player_radio_1"]["use_count"] += 1
    check(not reloaded.session.world.restore_snapshot(forged),"forged radio use count accepted")
    check(reloaded.status()["digest"]==saved,"forged replay damaged live save")
    var verified: RefCounted = Kernel.new()
    check(verified.restore_snapshot(reloaded.session.world.view()),"full radio event replay")
    check(JSON.stringify(verified.view())==JSON.stringify(reloaded.session.world.view()),"replayed radio diverged")
    for instance in [g,adopted,adopted_twice,reloaded]: instance.dispose()
    for file in [SAVE, OLD_SAVE]:
        if FileAccess.file_exists(file): DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
