extends SceneTree
## COOK-03 bounded real Salma Ink advice -> P2 witness -> later actual P3 tea.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const Technique = preload("res://scripts/gameplay/tea_technique_play.gd")
const SAVE = "user://nk-e3-learned-tea.json"
var errors: Array[String] = []
func check(ok: bool, label: String) -> void:
    if not ok: errors.append(label)
func _initialize() -> void: call_deferred("run")
func move(g: RefCounted, dx: int, dy: int, count: int) -> void:
    for i in range(count): check(g.move_world(dx,dy).get("ok",false), "walk " + str(i))
func ready(g: RefCounted) -> bool:
    for i in range(180):
        if g.session.ink_ready(Game.RIVER_STORY_ID): return true
        await process_frame
    return false
func step(g: RefCounted, id: String, station: String, minutes: int) -> void:
    var started: Dictionary = g.session.command("learn:"+id+":"+station+":begin","player",
        "cook.step.begin",{"job_id":id,"station_id":station})
    check(started.get("ok",false), "real P3 "+station+" start")
    check(g.wait_minutes(minutes).get("ok",false), "canonical wait for "+station)
    var finished: Dictionary = g.session.command("learn:"+id+":"+station+":finish","player",
        "cook.step.finish",{"job_id":id})
    check(finished.get("ok",false), "real P3 "+station+" finish")
func tea(g: RefCounted, id: String, lateness: int) -> void:
    var start: Dictionary = g.session.command("learn:"+id+":start","player","cook.start",
        {"job_id":id,"recipe_id":"tea","deadline_minute":g.status()["minute"]+100})
    check(start.get("ok",false),"P3 tea job from player")
    step(g,id,"kettle",2+lateness)
    step(g,id,"counter",1)
func run() -> void:
    for p in [SAVE,SAVE+".tmp"]:
        if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    var g: RefCounted = Game.new()
    check(g.start(SAVE).get("ok",false), "boot")
    check(g.session.world.social_view()["social_facts"].has(Technique.FACT),"Salma owns registered authored advice")
    check(not g.session.world.player_knows(Technique.FACT),"no free player advice at boot")
    check(g.status()["tea_technique"]["phase"]=="unheard","unheard skill state")
    move(g,18,0,1);check(g.travel_near().get("ok",false),"roof exit")
    move(g,18,0,9);check(g.travel_near().get("ok",false),"landing exit")
    move(g,18,0,9);check(g.travel_near().get("ok",false),"street exit")
    move(g,18,0,7);move(g,0,18,1)
    check(g.open_kiosk().get("ok",false),"open actual kiosk")
    check(g.quiet_near().get("ok",false),"river quiet unlock")
    move(g,-18,0,2)
    check(g.river_story_begin().get("code","")=="INK_LOADING","real Salma Ink attach")
    if not await ready(g): check(false,"Ink compile readiness"); g.dispose(); done();return
    check(g.river_story_begin().get("code","")=="STARTED","river narrative start")
    check(g.river_story_next().get("beat_id","")=="river_open","authored opening")
    check(g.river_story_next().get("code","")=="WAITING","actual two-choice Ink")
    check(not g.session.world.player_knows(Technique.FACT),"merely seeing choice teaches nothing")
    check(g.river_story_choose("rest").get("ok",false),"choose optional cooking advice")
    check(not g.session.world.player_knows(Technique.FACT),"choice is not hearing")
    check(g.river_story_next().get("beat_id","")=="river_rest","actually hear Salma timing beat")
    check(g.session.world.player_knows(Technique.FACT),"authored P6 beat taught canonical P2 fact")
    check(g.status()["tea_technique"]["phase"]=="heard","heard but no attempt")
    check(g.river_story_next().get("beat_id","")=="river_end","branch reconverges")
    check(g.river_story_next().get("code","")=="FINISHED","Ink finishes normally")
    check(g.save_game().get("ok",false),"save after real witnessed tip")
    g.dispose()
    g=Game.new()
    check(g.start(SAVE).get("code","")=="RESTORED","restore heard-only tip")
    check(g.status()["tea_technique"]["phase"]=="heard","P2 knowledge persists after reload")
    tea(g,"learn:careful-cup",0)
    check(g.status()["tea_technique"]["phase"]=="understood","timely actual P3 cup verifies understanding")
    check(g.status()["tea_technique"]["grade"]=="good","good grade from real P3 step timings")
    check(g.session.world.prepared_quality("item:learn:careful-cup")["grade"]=="good","no fake cooking grade")
    check(g.save_game().get("ok",false),"save practiced cup")
    var authoritative: Dictionary = g.session.world.view()
    var fork: RefCounted = Kernel.new()
    check(fork.restore_snapshot(authoritative),"authenticated replay")
    check(JSON.stringify(fork.view())==JSON.stringify(authoritative),"event-sourced deterministic replay")
    g.dispose();g=Game.new()
    check(g.start(SAVE).get("code","")=="RESTORED","reload understood practice")
    check(g.status()["tea_technique"]["phase"]=="understood","learned physical result persists")
    tea(g,"learn:late-cup",7)
    check(g.status()["tea_technique"]["phase"]=="attempted" and g.status()["tea_technique"]["grade"]=="rough",
        "late practice is honest attempt, not automatic mastery bonus")
    check(not g.river_story_begin().get("ok",false),"no repeatable magic teaching")
    g.dispose()
    for p in [SAVE,SAVE+".tmp"]:
        if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    done()
func done() -> void:
    if errors.is_empty(): print("E3 TEA TECHNIQUE: PASS")
    else:
        for message in errors: push_error(message)
        print("E3 TEA TECHNIQUE: FAIL (%d)" % errors.size())
    quit(0 if errors.is_empty() else 1)
