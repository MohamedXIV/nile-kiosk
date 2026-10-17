extends SceneTree
## PLAY C2: authoritative XY replay, doorway/lease, forged state and audited v7 promotion.
const Session = preload("res://scripts/integration/world_session.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const WorldState = preload("res://scripts/core/world_state.gd")
const Catalog = "res://content/world/qa_nile_kiosk.v1.json"
const Routes = "res://content/navigation/qa_routes.v1.json"
const SAVE = "user://nk-play-c2-test.json"
var errors: Array[String] = []

func _initialize() -> void:
    _run()
    if errors.is_empty():
        print("PLAY C2: PASS (canonical XY and portals, v7 verified upgrade, replay, forged saves)")
        quit(0)
    else:
        for e in errors: push_error(e)
        print("PLAY C2: FAIL (%d)" % errors.size())
        quit(1)

func check(ok: bool, label: String) -> void:
    if not ok: errors.append(label)

func act(s: RefCounted, id: String, actor: String, kind: String, payload: Dictionary) -> Dictionary:
    return s.command("c2:"+id,actor,kind,payload)

func pos(s: RefCounted) -> Dictionary:
    return s.world.spatial_view()["player"]

func _run() -> void:
    for path in [SAVE,SAVE+".tmp","user://nk-v7-upgrade.json"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var model=Session.new(81,SAVE)
    check(model.bootstrap_from_content(Catalog).get("ok",false),"C0 import")
    var legacy: Dictionary=model.world.view()
    check(legacy["version"]==11 and legacy["spatial"]["graph"].is_empty(),"fresh baseline")
    check(model.configure_navigation(Routes).get("ok",false),"graph init")
    check(model.world.spatial_view()["graph"]["graph_id"]=="qa-room-route-c1","graph not event-owned")
    check(pos(model)=={"room_id":"roof","x":175,"y":70},"initial pose")
    check(model.configure_navigation(Routes)["code"]=="ALREADY_INITIALIZED","reinitialized graph")
    var start: String=JSON.stringify(model.world.view())
    check(act(model,"remote","system:director","social.player.place",{"location_id":"flat"})["code"]=="SPATIAL_TRAVEL_REQUIRED","direct P2 teleport allowed")
    check(act(model,"bad_delta","player","spatial.player.move",{"dx":180,"dy":0})["code"]=="INVALID_DELTA","teleport by huge movement")
    check(act(model,"zero","player","spatial.player.move",{"dx":0,"dy":0})["code"]=="INVALID_DELTA","zero movement creates event")
    check(act(model,"offscreen","system:director","spatial.player.move",{"dx":1,"dy":0})["code"]=="INVALID_ACTOR","spoofed movement actor")
    check(act(model,"jump","player","spatial.player.travel",{"portal_id":"street_to_kiosk"})["code"]=="WRONG_ROOM","cross-room remote travel")
    check(JSON.stringify(model.world.view())==start,"invalid commands changed world")
    check(act(model,"walk","player","spatial.player.move",{"dx":18,"dy":0}).get("ok",false),"valid step")
    check(pos(model)["x"]==193 and pos(model)["y"]==70,"moved position not canonical")
    check(act(model,"roof_to_landing","player","spatial.player.travel",{"portal_id":"roof_to_landing"}).get("ok",false),"roof door")
    check(pos(model)["room_id"]=="landing" and pos(model)["x"]==40,"portal arrival not canonical")
    check(model.world.social_view()["player_location"]=="landing","P2 room diverged from spatial")
    check(act(model,"flat:too_far","player","spatial.player.travel",{"portal_id":"landing_to_flat"})["code"]=="TOO_FAR","remote locked flat")
    for i in range(4):
        check(act(model,"walk:flat:"+str(i),"player","spatial.player.move",{"dx":18,"dy":0}).get("ok",false),"toward flat")
    check(act(model,"flat:locked","player","spatial.player.travel",{"portal_id":"landing_to_flat"})["code"]=="ACCESS_DENIED","entered unleased flat")
    check(act(model,"rent","player","housing.lease.start",{"lease_id":"c2:lease","unit_id":"flat","transaction_id":"c2:rent"}).get("ok",false),"legitimate lease")
    check(act(model,"flat:enter","player","spatial.player.travel",{"portal_id":"landing_to_flat"}).get("ok",false),"legit entering flat")
    check(pos(model)["room_id"]=="flat" and pos(model)["x"]==50 and pos(model)["y"]==80,"flat arrival")
    check(act(model,"flat:step","player","spatial.player.move",{"dx":18,"dy":0}).get("ok",false),"walking inside flat")
    check(pos(model)["x"]==68,"room XY after movement")
    var expected: Dictionary=model.world.view()
    check(model.save().get("ok",false),"whole-world saved")
    var reloaded=Session.new(555,SAVE)
    check(reloaded.load_existing().get("code")=="RESTORED","saved v8 restore")
    check(pos(reloaded)["room_id"]=="flat" and pos(reloaded)["x"]==68,"exact XY lost on disk restore")
    check(JSON.stringify(reloaded.world.view())==JSON.stringify(expected),"v8 replay byte identity")
    check(reloaded.configure_navigation(Routes)["code"]=="ALREADY_INITIALIZED","restored graph overwritten")
    var invalid: Dictionary=expected.duplicate(true)
    invalid["spatial"]["player"]["x"]=200
    check(not reloaded.world.restore_snapshot(invalid),"forged spatial position accepted")
    invalid=expected.duplicate(true)
    invalid["events"][-1]["payload"]["effect"]["x"]=200
    check(not reloaded.world.restore_snapshot(invalid),"forged movement event accepted")
    invalid=expected.duplicate(true)
    invalid["spatial"]["graph"]["rooms"][0]["width"]=999
    check(not reloaded.world.restore_snapshot(invalid),"forged navigation graph accepted")
    check(JSON.stringify(reloaded.world.view())==JSON.stringify(expected),"bad restore mutated live world")
    # Legacy v7: remove the v8-only, uninitialized spatial projection from a
    # pre-spatial C0 catalog snapshot. All 24 previous events are still verified.
    var old: Dictionary=legacy.duplicate(true)
    old.erase("spatial")
    old.erase("life")
    old.erase("needs")
    # v7 also predates E4 opportunity definitions and their result projection.
    old["narrative"].erase("opportunity_rules")
    old["narrative"].erase("opportunities")
    old["version"]=7
    var old_path="user://nk-v7-upgrade.json"
    var f=FileAccess.open(old_path,FileAccess.WRITE)
    f.store_string(JSON.stringify(old))
    f.close()
    var migrated=Session.new(2,old_path)
    check(migrated.load_existing().get("code")=="MIGRATED","verified v7 upgrade not recognized")
    check(migrated.world.last_restore_was_migration,"migration not declared")
    check(migrated.world.view()["version"]==11 and migrated.world.view()["sequence"]==old["sequence"],"upgrade altered existing event log")
    check(migrated.world.balance_minor()==300 and migrated.world.npc("reda")["location_id"]=="street","legacy social/economy altered")
    check(migrated.world.spatial_view()["graph"].is_empty(),"invented legacy pose")
    check(migrated.configure_navigation(Routes).get("ok",false),"audited initial pose event after migration")
    check(migrated.world.view()["sequence"]==old["sequence"]+1,"migration didn't record graph event")
    check(migrated.save().get("ok",false),"persist promoted v8")
    var after=Session.new(1,old_path)
    check(after.load_existing().get("code")=="RESTORED","promoted v8 restore not normal")
    check(JSON.stringify(after.world.view())==JSON.stringify(migrated.world.view()),"upgraded save didn't replay")
    old["economy"]["accounts"]["player"]=999
    f=FileAccess.open(old_path,FileAccess.WRITE)
    f.store_string(JSON.stringify(old))
    f.close()
    var preserved: String=JSON.stringify(after.world.view())
    check(not after.load_existing().get("ok",false),"tampered v7 accepted")
    check(JSON.stringify(after.world.view())==preserved,"tampered v7 mutated restored world")
    for path in [SAVE,SAVE+".tmp",old_path]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
