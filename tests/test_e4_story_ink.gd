extends SceneTree
## E4: real authored Salma Ink conversation, gated from canonical opportunity.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const SAVE = "user://nk-e4-story-ink.json"
var errors: Array[String] = []

func check(ok: bool, reason: String) -> void:
    if not ok: errors.append(reason)

func move(g: RefCounted, dx: int, dy: int, count: int, label: String) -> void:
    for i in range(count):
        check(g.move_world(dx,dy).get("ok",false), label + ":" + str(i))

func _initialize() -> void:
    call_deferred("_run")

func _ready_ink(g: RefCounted) -> bool:
    for i in range(180):
        if g.session.ink != null and g.session.ink.sessions.has(Game.RIVER_STORY_ID):
            if g.session.ink.sessions[Game.RIVER_STORY_ID]["failed"]:
                return false
            if g.session.ink_ready(Game.RIVER_STORY_ID):
                return true
        await process_frame
    return false

func _run() -> void:
    for path in [SAVE, SAVE+".tmp"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var g: RefCounted = Game.new()
    var boot: Dictionary = g.start(SAVE)
    check(boot.get("code","") == "NEW_WORLD", "new game boots with authored story")
    if not boot.get("ok",false):
        _done()
        return
    check(g.session.world.narrative_view()["stories"].has(Game.RIVER_STORY_ID), "P6 manifest not registered")
    check(g.river_story_begin().get("code","") == "STORY_NOT_UNLOCKED", "talking before opportunity was unlocked")
    var pre: String = g.status()["digest"]
    check(g.session.command("e4:before","system:narrative","narrative.opportunity.begin",
        {"session_id":"forged","story_id":Game.RIVER_STORY_ID,"opportunity_id":Game.RIVER_STORY_ID,
         "participants":["salma","player"],"ink_state":["fake"]}).get("code","") == "OPPORTUNITY_LOCKED",
         "bypass via canonical command before opportunity")
    check(g.status()["digest"] == pre, "locked begin mutated world")
    move(g,18,0,1,"roof")
    check(g.travel_near().get("ok",false),"roof to landing")
    move(g,18,0,9,"landing")
    check(g.travel_near().get("ok",false),"landing to street")
    move(g,18,0,9,"street")
    check(g.travel_near().get("ok",false),"street to kiosk")
    move(g,18,0,7,"riverside x")
    move(g,0,18,1,"riverside y")
    check(g.open_kiosk().get("ok",false), "opening kiosk")
    var quiet: Dictionary = g.quiet_near()
    check(quiet.get("ok",false) and quiet.get("activity_id","") == "river_watch", "river activity")
    check(g.river_story_available(),"real quiet event did not unlock opportunity")
    check(g.river_story_begin().get("code","") == "SALMA_TOO_FAR", "remote talk bypassed Godot NPC pose")
    move(g,-18,0,2,"approach Salma")
    check(g.river_story_begin().get("code","") == "INK_LOADING", "Ink should attach lazily and safely")
    if not await _ready_ink(g):
        check(false, "real compiled Ink failed to load")
        g.dispose()
        _done()
        return
    var started: Dictionary = g.river_story_begin()
    check(started.get("code","") == "STARTED", "canonical opportunity did not start")
    check(g.river_story_session().get("opportunity_id","") == Game.RIVER_STORY_ID, "session not linked to source opportunity")
    check(g.river_story_next().get("beat_id","") == "river_open", "real authored opening beat")
    check(g.river_story_next().get("code","") == "WAITING", "Ink choice point did not wait")
    var choices: Array = g.status()["river_story_choices"]
    check(choices.size() == 2 and choices[0]["option_id"] == "city" and choices[1]["option_id"] == "rest","stable real Ink options")
    var before_reject: String = g.status()["digest"]
    check(g.river_story_choose("invented").get("code","") == "CHOICE_GATED", "unknown choice bypass")
    check(g.status()["digest"] == before_reject,"denied choice mutated world")
    var mid: Dictionary = g.session.world.view()
    check(g.save_game().get("ok",false),"persist native pending choice")
    g.dispose()
    var resumed: RefCounted = Game.new()
    check(resumed.start(SAVE).get("code","") == "RESTORED","resuming world")
    check(JSON.stringify(resumed.session.world.view()) == JSON.stringify(mid),"save changed unlocked narrative session")
    check(resumed.river_story_begin().get("code","") == "INK_LOADING","reload must reattach real Ink")
    if not await _ready_ink(resumed):
        check(false, "reloaded Ink session failed to restore")
        resumed.dispose()
        _done()
        return
    check(resumed.river_story_begin().get("code","") == "RESUMED","existing session replayed instead of resumed")
    check(resumed.status()["river_story_choices"].size()==2,"real pending options lost across disk reload")
    var selected: Dictionary = resumed.river_story_choose("city")
    check(selected.get("ok",false),"select authored reply")
    check(resumed.river_story_next().get("beat_id","") == "river_city","selected Ink branch")
    check(resumed.river_story_next().get("beat_id","") == "river_end","Ink branch reconverged")
    check(resumed.river_story_next().get("code","") == "FINISHED","canonical Ink session not finished")
    check(resumed.river_story_begin().get("code","") == "STORY_ALREADY_FINISHED","completed opportunity replayed")
    var once: String = resumed.status()["digest"]
    check(resumed.session.command("e4:repeat","system:narrative","narrative.opportunity.begin",
        {"session_id":"second","story_id":Game.RIVER_STORY_ID,"opportunity_id":Game.RIVER_STORY_ID,
         "participants":["salma","player"],"ink_state":["fake"]}).get("code","")=="OPPORTUNITY_ALREADY_STARTED",
         "second session consumed same opportunity")
    check(resumed.status()["digest"] == once,"duplicate begin changed canonical world")
    check(resumed.status()["money"] == 6000 and not resumed.session.world.player_knows("nile:evening-breeze"),
        "story magically changed economy/knowledge")
    check(resumed.save_game().get("ok",false),"save finished story")
    var authoritative: Dictionary = resumed.session.world.view()
    resumed.dispose()
    var reloaded: RefCounted = Game.new()
    check(reloaded.start(SAVE).get("code","") == "RESTORED","finished story restored")
    check(JSON.stringify(reloaded.session.world.view()) == JSON.stringify(authoritative),
        "finished story not deterministic on disk replay")
    check(reloaded.river_story_begin().get("code","") == "STORY_ALREADY_FINISHED","finished story repeat after reload")
    var copy: RefCounted = Kernel.new()
    check(copy.restore_snapshot(authoritative),"replay all-domain Ink opportunity")
    check(JSON.stringify(copy.view()) == JSON.stringify(authoritative),"headless replay not identical")
    reloaded.dispose()
    for path in [SAVE,SAVE+".tmp"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    _done()

func _done() -> void:
    if errors.is_empty():
        print("E4 STORY INK: PASS (player proximity, locked trigger, authored choices, one-shot, real Ink disk resume, replay)")
        quit(0)
    else:
        for why in errors: push_error(why)
        print("E4 STORY INK: FAIL (%d)" % errors.size())
        quit(1)
