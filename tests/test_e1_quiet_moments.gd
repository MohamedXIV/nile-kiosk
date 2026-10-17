extends SceneTree
## E1/P1: optional spatial downtime, not an E2 Mood/Rest system.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const SAVE = "user://nk-e1-quiet-test.json"
var errors: Array[String] = []

func _initialize() -> void:
    run()
    for failure in errors: push_error(failure)
    print("E1 QUIET MOMENTS: PASS (spatial constraints, independent scheduler, receipt replay, disk persistence)" if errors.is_empty() else "E1 QUIET MOMENTS: FAIL (%d)" % errors.size())
    quit(0 if errors.is_empty() else 1)

func check(condition: bool, label: String) -> void:
    if not condition: errors.append(label)

func move(g: RefCounted, dx: int, dy: int, times: int, label: String) -> void:
    for n in range(times):
        check(g.move_world(dx,dy).get("ok",false),label+":"+str(n))

func run() -> void:
    for path in [SAVE,SAVE+".tmp"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var g: RefCounted = Game.new()
    check(g.start(SAVE).get("code","")=="NEW_WORLD","new game boot")
    check(g.quiet_activities().size()==2,"only authored quiet activities")
    check(g.status()["quiet_count"]==0 and g.status()["money"]==6000,"no pregranted leisure reward")
    check(g.session.command("e1:bad:activity","player","life.activity",{"activity_id":"pretend_radio"}).get("code")=="UNKNOWN_ACTIVITY","unknown activity accepted")
    check(g.session.command("e1:bad:actor","system:director","life.activity",{"activity_id":"roof_breeze"}).get("code")=="INVALID_PLAYER_ACTION","director can invoke player leisure")
    check(g.session.command("e1:pause","system:clock","time.pause",{}).get("ok",false),"pause")
    var stopped: String = g.status()["digest"]
    check(g.quiet_near().get("code")=="PAUSED","quiet action bypasses pause")
    check(g.status()["digest"]==stopped,"paused quiet changed state")
    check(g.session.command("e1:resume","system:clock","time.resume",{}).get("ok",false),"resume")
    var breeze: Dictionary = g.quiet_near()
    check(breeze.get("ok",false) and breeze.get("activity_id","")=="roof_breeze","roof quiet action")
    check(g.status()["minute"]==1030 and g.status()["quiet_count"]==1 and g.status()["last_quiet"]=="roof_breeze","canonical quiet duration and marker")
    check(g.status()["npc_mahmoud"]=="kiosk","offscreen NPC moved during quiet roof moment")
    check(g.status()["money"]==6000 and g.status()["offer_count"]==0,"quiet moment minted money/order")
    var breeze_id: String = str(g.session.world.view()["events"][-1]["command_id"])
    var breeze_state: String = g.status()["digest"]
    check(g.session.command(breeze_id,"player","life.activity",{"activity_id":"roof_breeze"}).get("ok",false),"receipt for repeated quiet action")
    check(g.status()["digest"]==breeze_state,"duplicate activity advanced the clock")
    check(g.session.command(breeze_id,"player","life.activity",{"activity_id":"river_watch"}).get("code")=="ID_CONFLICT","activity ID conflict")
    move(g,18,0,1,"roof to landing")
    check(g.travel_near().get("ok",false) and g.room()=="landing","landing")
    check(g.session.command("e1:wrongroom","player","life.activity",{"activity_id":"river_watch"}).get("code")=="WRONG_ACTIVITY_ROOM","remote river activity accepted")
    move(g,18,0,9,"landing to street")
    check(g.travel_near().get("ok",false) and g.room()=="street","street")
    move(g,18,0,9,"street to kiosk")
    check(g.travel_near().get("ok",false) and g.room()=="kiosk","kiosk")
    var far_digest: String = g.status()["digest"]
    check(g.session.command("e1:far","player","life.activity",{"activity_id":"river_watch"}).get("code")=="TOO_FAR","ignored distance to railing")
    check(g.status()["digest"]==far_digest,"distant activity changed world")
    move(g,18,0,7,"approach river railing")
    move(g,0,18,1,"approach river y")
    var river: Dictionary = g.quiet_near()
    check(river.get("ok",false) and river.get("activity_id","")=="river_watch","river quiet action")
    check(g.status()["minute"]==1038 and g.status()["quiet_count"]==2,"river time and world history")
    check(g.status()["npc_mahmoud"]=="kiosk" and g.status()["offer_count"]==0,"closed kiosk and independent NPC while river-watching")
    check(g.open_kiosk().get("ok",false),"quiet time doesn't prevent opening")
    check(g.quiet_near().get("ok",false),"river-watching also possible while open")
    check(g.status()["money"]==6000 and g.status()["quiet_count"]==3,"no farmable rewards")
    var last: String = g.status()["digest"]
    var tampered: Dictionary = g.session.world.view()
    tampered["events"][-1]["payload"]["effect"]["to_minute"] += 1
    check(not g.session.world.restore_snapshot(tampered),"tampered quiet time accepted on replay")
    check(g.status()["digest"]==last,"invalid replay damaged world")
    check(g.save_game().get("ok",false),"save with quiet history")
    var loaded: RefCounted = Game.new()
    check(loaded.start(SAVE).get("code","")=="RESTORED","game restored")
    check(loaded.status()["digest"]==last and loaded.status()["quiet_count"]==3 and loaded.status()["last_quiet"]=="river_watch","quiet history lost after disk reload")
    check(loaded.quiet_activities().size()==2,"authored activity policy lost on reload")
    var live: RefCounted = Kernel.new()
    check(live.restore_snapshot(loaded.session.world.view()),"event replay failed")
    check(JSON.stringify(live.view())==JSON.stringify(loaded.session.world.view()),"replay changed canonical snapshot")
    for obj in [g,loaded]: obj.dispose()
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
