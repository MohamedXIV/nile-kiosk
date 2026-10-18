extends SceneTree
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const SAVE = "user://nk-living-conversation.json"
const STORY = "river_neighbors"
var errors: Array[String] = []
func check(ok: bool, why: String) -> void:
    if not ok: errors.append(why)
func _initialize() -> void: call_deferred("run")
func move(g: RefCounted, x: int, y: int, n: int) -> void:
    for i in range(n): check(g.move_world(x,y).get("ok",false),"move")
func arrive(g: RefCounted) -> void:
    move(g,18,0,1); check(g.travel_near().get("ok",false),"roof exit")
    move(g,18,0,9); check(g.travel_near().get("ok",false),"landing exit")
    move(g,18,0,9); check(g.travel_near().get("ok",false),"street exit")
    move(g,18,0,4); check(g.open_kiosk().get("ok",false),"open")
func ready(g: RefCounted, id: String) -> bool:
    for i in range(180):
        if g.session.ink_ready(id): return true
        await process_frame
    return false
func wait(g: RefCounted, minutes: int) -> Dictionary:
    for i in range(minutes):
        var r: Dictionary = g.wait_minutes(1)
        if not r.get("ok",false): return r
    return {"ok":true}
func run() -> void:
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var g: RefCounted = Game.new()
    check(g.start(SAVE).get("ok",false),"boot")
    if not g.has_method("conversation_begin"):
        check(false,"production conversation adapter missing"); g.dispose(); done(); return
    arrive(g)
    check(g.conversation_begin().get("code","") == "CONVERSATION_UNAVAILABLE","before authored boundary")
    check(wait(g,19).get("ok",false),"first beat")
    check(g.ambient_exchange().get("beat",-1)==0,"independent Salma opening")
    check(wait(g,10).get("ok",false),"second beat")
    check(g.ambient_exchange().get("beat",-1)==1,"independent Mahmoud answer")
    check(g.status()["conversation_near"],"natural join boundary at counter")
    check(not g.session.world.player_knows("salma:evening-boats"),"ambient silence invents no fact")
    move(g,13,-12,1); move(g,18,0,1)
    for i in range(12): g.listen_near()
    move(g,-18,0,1); move(g,-13,12,1)
    check(not g.session.world.player_knows("salma:evening-boats"),"generic F must not bypass authored answer")
    # Test public acoustic range separately from furniture visual contact.
    var before: Dictionary = g.session.world.view()
    var closed: Dictionary = g.session.world.narrative_view()["stories"][STORY].duplicate(true)
    closed["story_id"]="closed_neighbors"
    closed["conversation"]["public"]=false
    check(g.session.command("living:private:register","system:narrative","narrative.story.register",closed).get("ok",false),"private authored contract")
    check(not g.session.world.conversation_view("closed_neighbors")["joinable"],"private prompt forbidden")
    check(g.session.world.conversation_view("closed_neighbors")["line"].is_empty(),"private caption forbidden")
    check(not g.session.command("living:private:start","system:narrative","narrative.session.start",{"session_id":"closed_neighbors:0","story_id":"closed_neighbors","participants":["salma","mahmoud","player"],"ink_state":["fake"]}).get("ok",false),"canonical private join denied")
    move(g,-18,0,5)
    check(not g.status()["conversation_near"],"distant prompt suppressed")
    check(g.conversation_begin().get("code","")=="CONVERSATION_UNAVAILABLE","remote begin rejected")
    check(not g.session.command("living:remote:start","system:narrative","narrative.session.start",{"session_id":"river_neighbors:0","story_id":STORY,"participants":["salma","mahmoud","player"],"ink_state":["fake"]}).get("ok",false),"canonical remote bypass denied")
    move(g,18,0,5)
    check(g.conversation_begin().get("code","")=="INK_LOADING","load actual Ink")
    var id: String = g.conversation_id()
    if not await ready(g,id): check(false,"compiled Ink readiness"); g.dispose(); done(); return
    check(g.conversation_begin().get("code","")=="STARTED","join independent conversation")
    check(g.conversation_next().get("beat_id","")=="join","actual invitation line")
    check(g.save_game().get("ok",false),"save immediately after tagged line")
    g.dispose(); g = Game.new(); check(g.start(SAVE).get("ok",false),"restore line boundary")
    check(g.conversation_begin().get("code","")=="INK_LOADING","reattach")
    check(await ready(g,id),"restore Ink")
    check(g.conversation_begin().get("code","")=="RESUMED","resume accepted occurrence")
    check(g.conversation_next().get("code","")=="WAITING","recover actual pending choice")
    check(g.status()["conversation_choices"].size()==2,"meaningful options restored")
    check(g.save_game().get("ok",false),"pending choice disk")
    var pending: Dictionary = g.session.world.view()
    check(wait(g,12).get("ok",false),"world progresses during choice")
    check(g.ambient_exchange().get("beat",-1)==2,"NPCs reconverge without player reply")
    move(g,-18,0,5)
    check(not g.conversation_choose("boats").get("ok",false),"remote choice rejected")
    check(not g.session.world.player_knows("salma:evening-boats"),"remote choice leaks no fact")
    move(g,18,0,5)
    check(not g.conversation_choose("invented").get("ok",false),"invented response")
    check(g.conversation_choose("boats").get("ok",false),"accepted question after independent continuation")
    check(not g.session.world.player_knows("salma:evening-boats"),"question alone is not hearing")
    check(g.conversation_next().get("beat_id","")=="boats","hear authored answer")
    check(g.session.world.player_knows("salma:evening-boats"),"P2 learns legitimately heard answer")
    check(g.conversation_next().get("beat_id","")=="end","Ink reconverges")
    check(g.conversation_next().get("code","")=="FINISHED","finish")
    check(not g.conversation_begin().get("ok",false),"no duplicate join")
    var w: RefCounted = Kernel.new()
    check(w.restore_snapshot(g.session.world.view()),"full deterministic replay")
    check(Kernel._matches(w.view(),g.session.world.view()),"identical outcome")
    var fake: Dictionary = g.session.world.view()
    fake["narrative"]["sessions"][id]["conversation_day"] = 99
    check(not w.restore_snapshot(fake),"forged occurrence rejected")
    check(w.restore_snapshot(pending),"pending choice replay")
    # Canonical command bypass cannot reuse a consumed boundary or start remotely.
    var reply: Dictionary = g.session.command("living:duplicate","system:narrative","narrative.session.start",
        {"session_id":"forged-second","story_id":STORY,"participants":["salma","mahmoud","player"],"ink_state":["fake"]})
    check(not reply.get("ok",false),"core duplicate/boundary guard")
    g.dispose()
    # Ignoring: same actual production world, no knowledge/session, progresses to silence.
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    g = Game.new(); check(g.start(SAVE).get("ok",false),"ignore boot"); arrive(g)
    check(wait(g,29).get("ok",false),"ignore boundary")
    check(wait(g,10).get("ok",false),"ignore tail")
    check(g.ambient_exchange().get("beat",-1)==2,"ignored exchange has authored ending")
    check(wait(g,6).get("ok",false),"silence")
    check(g.ambient_exchange().is_empty(),"silence is valid")
    check(g.session.world.narrative_session(g.conversation_id()).is_empty(),"ignoring never creates player session")
    check(not g.session.world.player_knows("salma:evening-boats"),"ignoring grants no fact")
    check(not g.conversation_begin().get("ok",false),"expired window")
    check(g.session.world.view()["cooking"] == before["cooking"],"ordinary conversation grants no stock")
    g.dispose(); done()
func done() -> void:
    if errors.is_empty(): print("E4 LIVING CONVERSATION: PASS")
    else:
        for e in errors: push_error(e)
        print("E4 LIVING CONVERSATION: FAIL ",errors.size())
    quit(0 if errors.is_empty() else 1)
