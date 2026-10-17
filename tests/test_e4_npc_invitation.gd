extends SceneTree
## E4: real customer delivery -> unsolicited invite -> accept/ignore -> real Ink.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const SAVE = "user://nk-e4-npc-invite.json"
const IGNORE = "user://nk-e4-npc-ignored.json"
var errors: Array[String] = []

func check(ok: bool, label: String) -> void:
    if not ok: errors.append(label)

func action(g: RefCounted, result: Dictionary, label: String) -> void:
    check(result.get("ok", false), label + ": " + str(result.get("code", "")))

func move(g: RefCounted, dx: int, dy: int, steps: int) -> void:
    for i in range(steps):
        action(g,g.move_world(dx,dy),"walk %d" % i)

func _initialize() -> void:
    call_deferred("_run")

func _ready_ink(g: RefCounted) -> bool:
    for i in range(180):
        if g.session.ink != null and g.session.ink.sessions.has(Game.MAHMOUD_STORY_ID):
            if g.session.ink.sessions[Game.MAHMOUD_STORY_ID]["failed"]: return false
            if g.session.ink_ready(Game.MAHMOUD_STORY_ID): return true
        await process_frame
    return false

func _run() -> void:
    for path in [SAVE,IGNORE]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var g: RefCounted = Game.new()
    action(g,g.start(SAVE),"start authored world")
    check(g.mahmoud_invitation().is_empty(),"invitation present before any real service")
    check(g.mahmoud_story_decline().get("code","")=="INVITATION_NOT_NEARBY","ignore before offer accepted")
    move(g,18,0,1)
    action(g,g.travel_near(),"roof to landing")
    move(g,18,0,9)
    action(g,g.travel_near(),"landing to street")
    move(g,18,0,9)
    action(g,g.travel_near(),"street to kiosk")
    move(g,18,0,4)
    action(g,g.open_kiosk(),"open kiosk")
    for i in range(3): action(g,g.wait_minutes(),"wait for real autonomous demand")
    check(g.status()["order_status"]=="offered","NPC did not order")
    action(g,g.wait_minutes(4),"NPC approach")
    action(g,g.service_near(),"accept tea order")
    action(g,g.service_near(),"start physical cooking")
    action(g,g.tea_action_near("H"),"put kettle on")
    action(g,g.wait_minutes(2),"heat kettle")
    action(g,g.tea_action_near("H"),"lift kettle")
    action(g,g.tea_action_near("U"),"pour tea")
    action(g,g.wait_minutes(1),"pour duration")
    action(g,g.tea_action_near("U"),"finish pour")
    check(g.mahmoud_invitation().is_empty(),"conversation before delivery")
    var served: Dictionary = g.service_near()
    check(served.get("kind","")=="order.deliver","real prepared tea was not delivered")
    var invite: Dictionary = g.mahmoud_invitation()
    check(invite.get("source_event_id","")==served.get("event_id",""),"not sourced from actual delivery event")
    check(invite.get("initiator_npc_id","")=="mahmoud","wrong NPC initiated contact")
    check(g.mahmoud_invite_near(),"real NPC didn't call player within physical proximity")
    check(g.mahmoud_story_session().is_empty(),"NPC silently started conversation without consent")
    action(g,g.save_game(),"save canonical post-delivery invitation")
    var original: Dictionary = g.session.world.view()
    var refused: RefCounted = Game.new()
    check(refused.start(SAVE).get("code","")=="RESTORED","load invite for ignore branch")
    check(refused.mahmoud_invite_near(),"invitation lost on reload")
    var declined: Dictionary = refused.mahmoud_story_decline()
    action(refused,declined,"decline on request")
    check(refused.mahmoud_invitation().get("declined_event_id","")==declined.get("event_id",""),"canonical ignore has no provenance")
    check(refused.mahmoud_story_begin().get("code","")=="OPPORTUNITY_DECLINED","ignored invitation still starts")
    var denied: String = refused.status()["digest"]
    check(refused.mahmoud_story_decline().get("code","")=="INVITATION_NOT_NEARBY","declined offer repeated")
    check(refused.status()["digest"]==denied,"second ignore mutated world")
    refused.session.save_path = IGNORE
    action(refused,refused.save_game(),"save declined invitation")
    refused.dispose()
    var ignored: RefCounted = Game.new()
    check(ignored.start(IGNORE).get("code","")=="RESTORED","ignored invite reload")
    check(ignored.mahmoud_invitation().get("declined_event_id","")==declined.get("event_id",""),"ignore wasn't durable")
    check(ignored.mahmoud_story_begin().get("code","")=="OPPORTUNITY_DECLINED","ignored NPC still speaks on reload")
    ignored.dispose()
    check(JSON.stringify(g.session.world.view())==JSON.stringify(original),"decline in fork mutated accepted-world branch")
    check(g.mahmoud_story_begin().get("code","")=="INK_LOADING","real NPC Ink must attach")
    if not await _ready_ink(g):
        check(false,"real post-service Ink failed to load")
        g.dispose()
        _done()
        return
    action(g,g.mahmoud_story_begin(),"player accepts invite")
    check(g.mahmoud_story_session().get("opportunity_id","")==Game.MAHMOUD_STORY_ID,"started session lacked invitation provenance")
    check(g.mahmoud_story_next().get("beat_id","")=="mahmoud_open","real initiated first Ink line")
    check(g.mahmoud_story_next().get("code","")=="WAITING","not at native Ink choice point")
    check(g.status()["mahmoud_story_choices"].size()==2,"Ink response choices not projected")
    check(g.mahmoud_story_decline().get("code","")=="INVITATION_NOT_NEARBY" or not g.mahmoud_story_session().is_empty(),"decline after begin allowed")
    action(g,g.save_game(),"save mid-choice Ink")
    var halfway: Dictionary = g.session.world.view()
    g.dispose()
    var restored: RefCounted = Game.new()
    check(restored.start(SAVE).get("code","")=="RESTORED","load real Ink choice")
    check(JSON.stringify(restored.session.world.view())==JSON.stringify(halfway),"mid-choice world differed")
    check(restored.mahmoud_story_begin().get("code","")=="INK_LOADING","attach existing Ink on reload")
    if not await _ready_ink(restored):
        check(false,"Ink did not restore after save")
        restored.dispose()
        _done()
        return
    check(restored.mahmoud_story_begin().get("code","")=="RESUMED","Ink resumed instead of restarting")
    var choices: Array = restored.status()["mahmoud_story_choices"]
    check(choices.size()==2,"persisted Ink options lost")
    action(restored,restored.mahmoud_story_choose("listen"),"choose listened response")
    check(restored.mahmoud_story_next().get("beat_id","")=="mahmoud_listen","branch did not follow authored choice")
    check(restored.mahmoud_story_next().get("beat_id","")=="mahmoud_end","narrative did not reconverge")
    check(restored.mahmoud_story_next().get("code","")=="FINISHED","Ink session did not finish")
    check(restored.mahmoud_story_begin().get("code","")=="STORY_ALREADY_FINISHED","finished NPC initiated repeatedly")
    var forged: Dictionary = restored.session.world.view()
    forged["narrative"]["opportunities"][Game.MAHMOUD_STORY_ID]["source_event_id"] = "forged"
    check(not restored.session.world.restore_snapshot(forged),"forged invite provenance accepted")
    action(restored,restored.save_game(),"save completed NPC interaction")
    var ended: Dictionary = restored.session.world.view()
    restored.dispose()
    var after: RefCounted = Game.new()
    check(after.start(SAVE).get("code","")=="RESTORED","reload completed narrative")
    check(JSON.stringify(after.session.world.view())==JSON.stringify(ended),"whole-world replay changed")
    check(after.mahmoud_story_begin().get("code","")=="STORY_ALREADY_FINISHED","completed NPC speaks again after reload")
    var replay: RefCounted = Kernel.new()
    check(replay.restore_snapshot(ended),"fresh canonical replay")
    after.dispose()
    for path in [SAVE,IGNORE]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    _done()

func _done() -> void:
    if errors.is_empty():
        print("E4 NPC INVITATION: PASS (real customer provenance, accepted/declined branching, physical contact, P6 Ink choice and replay)")
        quit(0)
    else:
        for error in errors: push_error(error)
        print("E4 NPC INVITATION: FAIL "+str(errors.size()))
        quit(1)
