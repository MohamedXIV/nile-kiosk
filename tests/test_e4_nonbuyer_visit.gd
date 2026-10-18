extends SceneTree
## E4: a nonbuyer visits on P1/P2 time, without the player or service,
## and a nearby player may later choose real P6 Ink.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const SAVE = "user://nk-e4-mona-real-visit.json"
const OFFSITE = "user://nk-e4-mona-offsite.json"
var errors: Array[String] = []

func check(value: bool, label: String) -> void:
    if not value: errors.append(label)

func command(result: Dictionary, label: String) -> void:
    check(result.get("ok",false),label+": "+str(result.get("code","")))

func move(g: RefCounted, dx: int, dy: int, n: int) -> void:
    for i in range(n): command(g.move_world(dx,dy),"movement %d" % i)

func progress(g: RefCounted, n: int) -> void:
    while n > 0:
        var step: int = mini(5,n)
        command(g.wait_minutes(step),"canonical time step")
        n -= step

func no_mona_orders(g: RefCounted) -> bool:
    for o in g.session.world.orders_view()["orders"].values():
        if o["npc_id"] == "mona": return false
    return true

func _initialize() -> void:
    call_deferred("_run")

func _wait_ink(g: RefCounted) -> bool:
    for i in range(180):
        if g.session.ink != null and g.session.ink.sessions.has("mona_visits_salma"):
            if g.session.ink.sessions["mona_visits_salma"]["failed"]: return false
            if g.session.ink_ready("mona_visits_salma"): return true
        await process_frame
    return false

func _run() -> void:
    for p in [SAVE, OFFSITE]:
        if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    var remote: RefCounted = Game.new()
    command(remote.start(OFFSITE),"offsite world")
    check(remote.session.world.npc("mona").get("location_id","")=="street","not based on P2 street origin")
    check(remote.mona_story_begin().get("code","")=="VISIT_NOT_AVAILABLE","unearned story before visit")
    progress(remote,43)
    check(remote.session.world.npc("mona").get("location_id","")=="street","early NPC teleport")
    progress(remote,1)
    check(remote.session.world.npc("mona").get("location_id","")=="kiosk","independent P2 NPC didn't arrive offscreen")
    check(remote.npc_pose("mona").get("mode","")=="arriving","scheduled AStar arrival missing")
    check(remote.session.world.narrative_opportunities().get("mona_visits_salma",{}).is_empty(),"offsite player wrongly offered conversation")
    check(remote.session.world.orders_view()["orders"].is_empty(),"social visitor minted order while kiosk closed")
    progress(remote,3)
    check(remote.npc_pose("mona").get("mode","")=="visiting","NPC not staying at visit spot")
    check(remote.npc_pose("mona").get("position",Vector2.ZERO)==Vector2(196,76),"NPC not at authored meeting spot")
    check(not remote.session.world.player_knows("mona:visiting-salma"),"offscreen visitor taught player fact")
    progress(remote,30)
    check(remote.npc_pose("mona").get("mode","")=="leaving","canonical predeparture walk missing")
    progress(remote,3)
    check(remote.session.world.npc("mona").get("location_id","")=="street","NPC didn't leave on world schedule")
    check(remote.npc_pose("mona").is_empty(),"visitor still drawn after P2 leave")
    check(remote.session.world.orders_view()["orders"].is_empty(),"social visitor caused demand")
    var snapshot: Dictionary = remote.session.world.view()
    command(remote.save_game(),"save offsite complete visit")
    remote.dispose()
    var again: RefCounted = Game.new()
    check(again.start(OFFSITE).get("code","")=="RESTORED","offsite visit not restored")
    check(JSON.stringify(again.session.world.view())==JSON.stringify(snapshot),"offsite scheduled timeline not replay-equivalent")
    again.dispose()

    var g: RefCounted = Game.new()
    command(g.start(SAVE),"player visit start")
    move(g,18,0,1)
    command(g.travel_near(),"roof to landing")
    move(g,18,0,9)
    command(g.travel_near(),"landing to street")
    move(g,18,0,9)
    command(g.travel_near(),"street to kiosk")
    move(g,18,0,8)
    command(g.open_kiosk(),"open kiosk")
    check(g.mona_story_begin().get("code","")=="VISIT_NOT_AVAILABLE","NPC visit offered early")
    progress(g,43)
    check(g.session.world.narrative_opportunities().get("mona_visits_salma",{}).is_empty(),"premature arrival offer")
    progress(g,1)
    var invite: Dictionary = g.session.world.narrative_opportunities().get("mona_visits_salma",{})
    check(invite.get("trigger_event","")=="time.advanced","invite not tied to clock and P2 presence")
    check(g.mona_visit_near(),"first moment not near guest")
    progress(g,3)
    check(g.npc_pose("mona").get("mode","")=="visiting","visitor not at meeting spot")
    check(g.mona_visit_near(),"offer not nearby after P2 visitor stops")
    check(no_mona_orders(g),"nonbuyer created order")
    check(not g.session.world.player_knows("mona:visiting-salma"),"learned fact before spoken")
    check(g.mona_story_session().is_empty(),"unexpected forced conversation")
    check(g.mona_story_begin().get("code","")=="INK_LOADING","actual Ink not attached lazily")
    if not await _wait_ink(g):
        check(false,"real Ink didn't load")
        g.dispose()
        _done()
        return
    check(g.mona_story_begin().get("code","")=="STARTED","player couldn't voluntarily engage")
    check(g.mona_story_next().get("beat_id","")=="mona_hello","Mona authored first line missed")
    check(g.session.world.player_knows("mona:visiting-salma"),"real heard story didn't share canonical P2 fact")
    check(g.mona_story_next().get("code","")=="WAITING","missing authored choice")
    check(g.status()["mona_story_choices"].size()==2,"options not shown")
    command(g.save_game(),"save true Ink pending choice")
    var mid: Dictionary = g.session.world.view()
    g.dispose()
    var resumed: RefCounted = Game.new()
    check(resumed.start(SAVE).get("code","")=="RESTORED","load pending choice")
    check(JSON.stringify(resumed.session.world.view())==JSON.stringify(mid),"Ink choice not saved")
    check(resumed.mona_story_begin().get("code","")=="INK_LOADING","Ink reattach after reload")
    if not await _wait_ink(resumed):
        check(false,"reloaded Ink failed")
        resumed.dispose()
        _done()
        return
    check(resumed.mona_story_begin().get("code","")=="RESUMED","Ink restarted after reload")
    check(resumed.status()["mona_story_choices"].size()==2,"pending choices weren't restored")
    command(resumed.mona_story_choose("looking"),"player choice")
    check(resumed.mona_story_next().get("beat_id","")=="mona_looking","Ink branch mismatch")
    check(resumed.mona_story_next().get("beat_id","")=="mona_goodbye","Ink merge beat")
    check(resumed.mona_story_next().get("code","")=="FINISHED","real session not finished")
    check(resumed.mona_story_begin().get("code","")=="STORY_ALREADY_FINISHED","replayed one-shot conversation")
    check(no_mona_orders(resumed),"speech generated fake service")
    var forged: Dictionary = resumed.session.world.view()
    forged["narrative"]["opportunities"]["mona_visits_salma"]["source_event_id"]="forged"
    check(not resumed.session.world.restore_snapshot(forged),"fake visiting source accepted")
    command(resumed.save_game(),"finished visit conversation save")
    var ended: Dictionary = resumed.session.world.view()
    var replay: RefCounted = Kernel.new()
    check(replay.restore_snapshot(ended),"canonical full-world replay")
    check(JSON.stringify(replay.view())==JSON.stringify(ended),"canonical conversation digest changed")
    resumed.dispose()
    for p in [SAVE,OFFSITE]:
        if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    _done()

func _done() -> void:
    if errors.is_empty():
        print("E4 NONBUYER VISIT: PASS (independent P2 schedule, AStar path, offscreen lifecycle, player-chosen fact/Ink, hard disk replay)")
        quit(0)
    else:
        for err in errors: push_error(err)
        print("E4 NONBUYER VISIT: FAIL "+str(errors.size()))
        quit(1)
