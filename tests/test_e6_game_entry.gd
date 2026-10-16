extends SceneTree
## E6/P0 acceptance: separate gameplay catalog, real portals, demand, service and disk replay.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const SAVE = "user://nk-e6-game-entry-acceptance.json"
var failures: Array[String] = []

func _initialize() -> void:
    _run()
    if failures.is_empty():
        print("E6 GAME ENTRY: PASS (canonical opening, traversal, demand, cooking, payment, save/reload)")
        quit(0)
    else:
        for f in failures: push_error(f)
        print("E6 GAME ENTRY: FAIL (%d)" % failures.size())
        quit(1)

func check(value: bool, label: String) -> void:
    if not value: failures.append(label)

func _run() -> void:
    for path in [SAVE, SAVE+".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var g: RefCounted = Game.new()
    var started: Dictionary = g.start(SAVE)
    check(started.get("ok",false) and started.get("code","")=="NEW_WORLD","new session")
    if not started.get("ok",false): return
    check(g.room()=="roof" and g.status()["minute"]==1020,"initial roof at authored opening time")
    check(g.status()["money"]==6000 and g.status()["roof_access"],"world content vs QA economics")
    check(g.status()["npc_mahmoud"]=="street","visitor not pre-teleported")
    var digest_before: String = g.status()["digest"]
    check(g.move_world(60,0)["code"]=="INVALID_DELTA","no movement teleport")
    check(g.status()["digest"]==digest_before,"invalid move wrote event")
    check(g.move_world(18,0).get("ok",false),"roof move")
    check(g.travel_near().get("ok",false) and g.room()=="landing","roof/landing")
    check(g.travel_near().get("ok",false) and g.room()=="roof","return to roof")
    check(g.travel_near().get("ok",false) and g.room()=="landing","return to landing")
    for i in range(9):
        check(g.move_world(18,0).get("ok",false),"landing walk %d" % i)
    check(g.travel_near().get("ok",false) and g.room()=="street","landing/street")
    for i in range(9):
        check(g.move_world(18,0).get("ok",false),"street walk %d" % i)
    check(g.travel_near().get("ok",false) and g.room()=="kiosk","street/kiosk")
    check(g.service_near()["code"]=="KIOSK_CLOSED","closed store rejects service")
    for i in range(4):
        check(g.move_world(18,0).get("ok",false),"kiosk counter approach %d" % i)
    check(g.open_kiosk().get("ok",false),"player opens kiosk")
    check(g.service_near()["code"]=="NO_ACTIVE_ORDER","no fake offer")
    for i in range(3):
        check(g.wait_minutes().get("ok",false),"real clock waiting")
    check(g.status()["minute"]==1035 and g.status()["npc_mahmoud"]=="kiosk","independent NPC visit")
    check(g.status()["order_status"]=="offered","autonomous customer order")
    var first: Dictionary = g.service_near()
    check(first.get("ok",false) and first.get("kind","")=="order.accept","accept real order")
    check(g.service_near().get("kind","")=="cook.start","start recipe")
    check(g.service_near().get("kind","")=="cook.step.begin","begin heating")
    check(g.service_near()["code"]=="STEP_NOT_READY","can't skip cooking duration")
    check(g.save_game().get("ok",false),"save mid-cooking")
    var before_load: Dictionary = g.session.world.view()
    var restored: RefCounted = Game.new()
    check(restored.start(SAVE).get("code","")=="RESTORED","restore existing opening game")
    check(JSON.stringify(restored.session.world.view())==JSON.stringify(before_load),"entire world state preserved")
    check(restored.room()=="kiosk" and restored.position()==g.position(),"canonical world pose retained")
    check(restored.wait_minutes(2).get("ok",false),"wait for heat")
    check(restored.service_near().get("kind","")=="cook.step.finish","finish heating")
    check(restored.service_near().get("kind","")=="cook.step.begin","begin serving")
    check(restored.wait_minutes(1).get("ok",false),"wait for serving")
    check(restored.service_near().get("kind","")=="cook.step.finish","finish serving")
    check(restored.service_near().get("kind","")=="order.deliver","deliver paid item")
    check(restored.service_near().get("kind","")=="economy.order.quote","quote")
    check(restored.service_near().get("kind","")=="economy.order.settle","settle")
    check(restored.status()["money"]==6200,"no duplicate payment")
    check(restored.save_game().get("ok",false),"save settled state")
    var once: String=restored.status()["digest"]
    var final: RefCounted=Game.new()
    check(final.start(SAVE).get("code","")=="RESTORED","second game boot")
    check(final.status()["digest"]==once and final.status()["money"]==6200,"settled state unchanged after reload")
    check(final.service_near()["code"]=="NO_ACTIVE_ORDER","no duplicate order service")
    check(final.status()["digest"]==once,"rejected service mutated settled state")
    for obj in [g,restored,final]: obj.dispose()
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
