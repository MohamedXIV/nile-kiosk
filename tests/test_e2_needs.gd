extends SceneTree
## E2 P0: canonical needs, contextual leisure, verified P3 food and P5 sleep.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const SAVE = "user://nk-e2-needs.json"
var failures: Array[String] = []

func _initialize() -> void:
    run()
    for error in failures: push_error(error)
    print("E2 NEEDS: PASS (clock chunks, leisure saturation, real food, bed sleep, replay)" if failures.is_empty() else "E2 NEEDS: FAIL (%d)" % failures.size())
    quit(0 if failures.is_empty() else 1)

func check(value: bool, label: String) -> void:
    if not value: failures.append(label)

func cmd(world: RefCounted, id: String, actor: String, kind: String, payload: Dictionary) -> Dictionary:
    return world.dispatch({"id":id,"actor_id":actor,"kind":kind,"payload":payload})

func run() -> void:
    if FileAccess.file_exists(SAVE):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var g: RefCounted = Game.new()
    var boot: Dictionary = g.start(SAVE)
    check(boot.get("ok",false), "new world")
    if not boot.get("ok",false): return
    var start: Dictionary = g.status()
    check(g.session.world.view()["version"]==10 and g.session.world.view()["needs"]["meal_values"].has("plain_bread"),"schema/personal nutrition")
    check(start["hunger"] < 75 and start["rest"] < 80 and start["mood"]>=25,"opening time evolved needs")
    check(not g.listen_radio().get("ok",false),"radio requires real placed object")
    var before: int = g.status()["mood"]
    check(g.buy_radio().get("ok",false) and g.place_radio().get("ok",false),"purchase and placement")
    check(g.status()["mood"]==before,"purchase alone granted mood")
    check(g.listen_radio().get("ok",false),"first listening")
    var first: int = g.status()["mood"]
    check(first>before,"first quiet activity affected mood")
    check(g.listen_radio().get("ok",false),"second listening")
    var second: int = g.status()["mood"]
    check(g.listen_radio().get("ok",false),"third listening")
    check(second-first <= 1 and g.status()["mood"]==second,"repetition does not farm mood")
    var snapshot: Dictionary = g.session.world.view()
    var a: RefCounted = Kernel.new()
    var b: RefCounted = Kernel.new()
    check(a.restore_snapshot(snapshot) and b.restore_snapshot(snapshot),"kernel replay")
    check(a.advance_time(600,"e2:chunk").get("ok",false),"chunk clock")
    for i in range(6):
        check(b.advance_time(100,"e2:step:%d" % i).get("ok",false),"chunked clock %d" % i)
    check(a.needs_view()==b.needs_view(),"time chunk invariance")
    check(cmd(b,"e2:bed:type","system:catalog","home.type.define",{"type_id":"bed","price_minor":0,"actions":["sleep"]}).get("ok",false),"bed catalog")
    check(cmd(b,"e2:bed:grant","system:bootstrap","home.object.grant",{"object_id":"e2_bed","type_id":"bed"}).get("ok",false),"bed grant")
    check(cmd(b,"e2:bed:place","player","home.object.place",{"object_id":"e2_bed","unit_id":"roof","slot_id":"e2_bed_corner"}).get("ok",false),"bed placed in owned home")
    check(a.needs_view()["mood"]==b.needs_view()["mood"],"bed purchase alone has no benefit")
    check(cmd(a,"e2:sleep:plain","player","life.sleep",{}).get("ok",false),"plain sleep")
    check(cmd(b,"e2:sleep:bed","player","life.sleep",{}).get("ok",false),"placed bed sleep")
    check(b.needs_view()["rest"] > a.needs_view()["rest"],"placed bed improves sleep only when used")
    # Prepared food must be a real P3 item; no free self-feeding or remote eating.
    check(g.session.command("e2:meal:start","player","cook.start",{"job_id":"e2_personal","recipe_id":"plain_bread","deadline_minute":g.status()["minute"]+100}).get("ok",false),"prepare personal bread")
    check(g.session.command("e2:meal:begin","player","cook.step.begin",{"job_id":"e2_personal","station_id":"counter"}).get("ok",false),"use actual station")
    check(g.wait_minutes(1).get("ok",false),"cook time")
    check(g.session.command("e2:meal:finish","player","cook.step.finish",{"job_id":"e2_personal"}).get("ok",false),"finished P3 item")
    var item_id: String = "item:e2_personal"
    check(g.session.command("e2:meal:remote","player","needs.eat",{"item_id":item_id}).get("code")=="PLAYER_ABSENT","remote eating rejected")
    check(g.session.command("e2:meal:fake","player","needs.eat",{"item_id":"item:fake"}).get("code")=="UNKNOWN_ITEM","forged food rejected")
    check(g.travel_near().get("ok",false),"roof to landing")
    check(g.travel_near().get("ok",false),"landing to roof return")
    check(g.travel_near().get("ok",false),"re-enter landing")
    for i in range(9): check(g.move_world(18,0).get("ok",false),"landing move")
    check(g.travel_near().get("ok",false),"street")
    for i in range(9): check(g.move_world(18,0).get("ok",false),"street move")
    check(g.travel_near().get("ok",false) and g.room()=="kiosk","arrive at kiosk")
    var hunger_before: int = g.status()["hunger"]
    var digest_before: String = g.status()["digest"]
    check(g.session.command("e2:meal:actor","system:director","needs.eat",{"item_id":item_id}).get("code")=="INVALID_PLAYER_ACTION","unauthorized eating rejected")
    check(g.status()["digest"]==digest_before,"rejected meal must not change state")
    check(g.session.command("e2:meal:eat","player","needs.eat",{"item_id":item_id}).get("ok",false),"consume real P3 item")
    check(g.status()["hunger"] == mini(100,hunger_before+24),"authored nourishment")
    check(g.session.world.prepared_item(item_id)["purpose_id"]=="player:meal","physical item consumed exactly once")
    var eaten: String = g.status()["digest"]
    check(g.session.command("e2:meal:eat","player","needs.eat",{"item_id":item_id}).get("ok",false),"duplicate receipt")
    check(g.status()["digest"]==eaten,"duplicate eating granted food twice")
    check(g.session.command("e2:meal:again","player","needs.eat",{"item_id":item_id}).get("code")=="ITEM_NOT_READY","second item consumption rejected")
    # Real player-facing self-meal interaction, using the same stock/stations
    # and prepared items as P3 rather than a second hunger inventory.
    check(g.personal_bread_near().get("code","")=="COUNTER_TOO_FAR","personal food proximity")
    for i in range(4): check(g.move_world(18,0).get("ok",false),"approach counter")
    check(g.personal_bread_near().get("phase","")=="start","personal recipe starts")
    check(g.personal_bread_near().get("phase","")=="begin","personal recipe begins")
    check(g.personal_bread_near().get("code","")=="STEP_NOT_READY","cannot skip preparation")
    check(g.wait_minutes(1).get("ok",false),"personal preparation time")
    check(g.personal_bread_near().get("phase","")=="finish","personal bread ready")
    var pre_second_meal: int = g.status()["hunger"]
    check(g.personal_bread_near().get("phase","")=="eat","player eats prepared bread")
    check(g.status()["hunger"] == mini(100,pre_second_meal+24),"personal meal restored actual need")
    eaten = g.status()["digest"]
    check(g.save_game().get("ok",false),"disk and replay")
    var loaded: RefCounted = Game.new()
    check(loaded.start(SAVE).get("code")=="RESTORED","disk reload")
    check(loaded.status()["digest"]==eaten,"needs save/reload differs")
    var tampered: Dictionary = loaded.session.world.view()
    tampered["needs"]["mood"] = 100
    check(not loaded.session.world.restore_snapshot(tampered),"forged mood accepted")
    check(loaded.status()["digest"]==eaten,"failed restore changed live world")
    for obj in [g,loaded]: obj.dispose()
    if FileAccess.file_exists(SAVE):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
