extends SceneTree
## E1/P0: world-owned player day and scheduler; closed days are valid.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const SAVE = "user://nk-e1-day-test.json"
var errors: Array[String] = []

func _initialize() -> void:
    run()
    for err in errors: push_error(err)
    print("E1 DAILY LIFE: PASS (closed demand, optional work, sleep, independence and verified replay)" if errors.is_empty() else "E1 DAILY LIFE: FAIL (%d)" % errors.size())
    quit(0 if errors.is_empty() else 1)

func check(value: bool, label: String) -> void:
    if not value: errors.append(label)

func move(g: RefCounted, x: int, times: int, label: String) -> void:
    for n in range(times):
        check(g.move_world(x,0).get("ok",false),label+":"+str(n))

func run() -> void:
    for path in [SAVE,SAVE+".tmp"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var g: RefCounted = Game.new()
    check(g.start(SAVE).get("code","")=="NEW_WORLD","new game")
    check(g.room()=="roof" and not g.status()["kiosk_open"],"roof and closed")
    check(g.open_kiosk().get("code")=="NOT_AT_KIOSK","cannot open remotely")
    check(g.close_kiosk().get("code")=="NOT_AT_KIOSK","cannot remotely close")
    var before: String = g.status()["digest"]
    check(g.status()["offer_count"]==0,"unexpected starting orders")
    check(g.wait_minutes(5).get("ok",false),"quiet 1")
    check(g.wait_minutes(5).get("ok",false),"quiet 2")
    check(g.wait_minutes(5).get("ok",false),"quiet 3")
    check(g.status()["npc_mahmoud"]=="kiosk","NPC arrival while player stays home")
    check(g.status()["offer_count"]==0,"closed kiosk should suppress scheduled customer intent")
    check(g.save_game().get("ok",false),"quiet day saved")
    var quiet: String = g.status()["digest"]
    var resumed: RefCounted = Game.new()
    check(resumed.start(SAVE).get("code","")=="RESTORED","quiet save restores")
    check(resumed.status()["digest"]==quiet,"quiet save state unchanged")
    check(resumed.status()["npc_mahmoud"]=="kiosk","independent NPC retained")
    move(resumed,18,1,"roof")
    check(resumed.travel_near().get("ok",false) and resumed.room()=="landing","to landing")
    move(resumed,18,9,"landing")
    check(resumed.travel_near().get("ok",false) and resumed.room()=="street","to street")
    move(resumed,18,9,"street")
    check(resumed.travel_near().get("ok",false) and resumed.room()=="kiosk","to kiosk")
    check(resumed.service_near().get("code")=="KIOSK_CLOSED","no work while closed")
    check(resumed.open_kiosk().get("ok",false),"player opens")
    var opened_id: String = str(resumed.session.world.view()["events"][-1]["command_id"])
    var opened_digest: String = resumed.status()["digest"]
    check(resumed.session.command(opened_id,"player","life.open",{}).get("ok",false),"repeat open receipt")
    check(resumed.status()["digest"]==opened_digest,"duplicate open created event")
    check(resumed.session.command(opened_id,"player","life.close",{}).get("code")=="ID_CONFLICT","reused ID for wrong action")
    check(resumed.open_kiosk().get("code")=="ALREADY_OPEN","double open rejected")
    check(resumed.close_kiosk().get("ok",false),"early closure without quota")
    check(resumed.close_kiosk().get("code")=="ALREADY_CLOSED","double close rejected")
    check(resumed.status()["offer_count"]==0,"early closure did not mint income")
    move(resumed,-18,1,"kiosk to street")
    check(resumed.travel_near().get("ok",false) and resumed.room()=="street","back to street")
    move(resumed,-18,9,"street to landing")
    check(resumed.travel_near().get("ok",false) and resumed.room()=="landing","back to landing")
    move(resumed,-18,9,"landing to roof")
    check(resumed.travel_near().get("ok",false) and resumed.room()=="roof","back home")
    check(resumed.session.command("e1:test:pause","system:clock","time.pause",{}).get("ok",false),"pause world")
    check(resumed.sleep_at_home().get("code")=="PAUSED","sleep bypassed paused world clock")
    check(resumed.session.command("e1:test:resume","system:clock","time.resume",{}).get("ok",false),"resume world")
    check(resumed.sleep_at_home().get("ok",false),"sleep at home")
    var sleep_id: String = str(resumed.session.world.view()["events"][-1]["command_id"])
    var slept_digest: String = resumed.status()["digest"]
    check(resumed.session.command(sleep_id,"player","life.sleep",{}).get("ok",false),"repeat sleep receipt")
    check(resumed.status()["digest"]==slept_digest,"duplicate sleep jumped time")
    var morning: Dictionary = resumed.status()
    check(morning["day"]==2 and morning["hour"]==8 and morning["minute_of_hour"]==0,"next morning")
    check(morning["sleep_count"]==1 and not morning["kiosk_open"],"closed next day state")
    check(morning["npc_mahmoud"]=="street","offscreen NPC returns to routine home")
    var slept: String = morning["digest"]
    check(resumed.sleep_at_home().get("code")=="ALREADY_SLEPT_TODAY","sleep repeated same day")
    check(resumed.status()["digest"]==slept,"rejected sleep added event")
    var tamper: Dictionary = resumed.session.world.view()
    tamper["life"]["open"] = true
    check(not resumed.session.world.restore_snapshot(tamper),"tampered life projection accepted")
    check(resumed.status()["digest"]==slept,"failed tamper corrupted session")
    check(resumed.save_game().get("ok",false),"sleep save")
    var next: RefCounted = Game.new()
    check(next.start(SAVE).get("code","")=="RESTORED","morning restore")
    check(next.status()["digest"]==slept and next.status()["sleep_count"]==1,"sleep state and scheduler not replayed")
    # A fresh open morning may be quiet. The next visitor must still appear
    # when scheduled after the player explicitly opens for the following day.
    move(next,18,1,"roof second day")
    check(next.travel_near().get("ok",false),"second day landing")
    move(next,18,9,"landing second day")
    check(next.travel_near().get("ok",false),"second day street")
    move(next,18,9,"street second day")
    check(next.travel_near().get("ok",false) and next.room()=="kiosk","second day kiosk")
    check(next.open_kiosk().get("ok",false),"reopen next day")
    # Deliberately advance canonical time in one chunk; all due NPC firings
    # must remain identical to sequential world steps.
    check(next.session.advance(555,"e1:test:day2:afternoon").get("ok",false),"canonical afternoon advance")
    check(next.status()["npc_mahmoud"]=="kiosk" and next.status()["order_status"]=="offered",
        "next-day independently scheduled customer")
    var chunk: RefCounted = Kernel.new()
    check(chunk.restore_snapshot(next.session.world.view()),"v9 command-history replay")
    check(JSON.stringify(chunk.view())==JSON.stringify(next.session.world.view()),"v9 snapshot replay diverged")
    check(next.save_game().get("ok",false),"save reopened shop and queued customer")
    var final_state: String = next.status()["digest"]
    var third: RefCounted = Game.new()
    check(third.start(SAVE).get("code","")=="RESTORED","open shop restored")
    check(third.status()["digest"]==final_state and third.status()["kiosk_open"],"open status/orders not replayed")
    for obj in [g,resumed,next,third]: obj.dispose()
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
