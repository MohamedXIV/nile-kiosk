extends SceneTree
## SYS P7 production integration: no D001 fixture, actual two native InkPlayers.
const World = preload("res://scripts/integration/world_session.gd")
const Fixture = preload("res://scripts/integration/p7_acceptance_fixture.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, reason: String) -> void:
    if not value: failures.append(reason)

func _ready_ink(world: RefCounted) -> bool:
    for i in range(140):
        if world.ink.sessions["a"]["failed"] or world.ink.sessions["b"]["failed"]: return false
        if world.ink_ready("a") and world.ink_ready("b"): return true
        await process_frame
    return false

func action(world: RefCounted, cid: String, actor: String, kind: String, p: Dictionary) -> Dictionary:
    return world.command(cid, actor, kind, p)

func _run() -> void:
    var path="user://nk-p7-integration.json"
    var world=World.new(97,path)
    var setup: Dictionary = Fixture.populate(world)
    if not setup.get("ok",false):
        failures.append("populate full world: "+str(setup))
        _done()
        return
    check(world.attach_ink("a","res://content/ink/sys_p6_conversation.ink.json"),"Ink A")
    check(world.attach_ink("b","res://content/ink/sys_p6_gossip.ink.json"),"Ink B")
    if not await _ready_ink(world):
        failures.append("initial native Ink loading")
        _done()
        return
    var sessions: Dictionary = Fixture.seed_sessions(world)
    if not sessions.get("ok",false):
        failures.append("seed independent conversations: "+str(sessions))
        _done()
        return
    var v: Dictionary=world.world.view()
    check(v["sequence"]>20 and v["version"]==11,"P0 all-domain replay envelope")
    check(v["world_minute"]==12 and v["jobs"].has("housing:due:lease"),"P1/P5 world clock/scheduler")
    check(world.world.npc("visitor")["location_id"]=="kiosk","P2 scheduled presence")
    check(v["cooking"]["preparations"]["batch"]["stage"]=="active","P3 mid-cook")
    check(world.world.order("order:tea")["status"]=="accepted","P4 mid-order")
    check(world.world.housing_view()["leases"]["lease"]["dues_owed"]==1,"P5 rent outstanding")
    check(world.world.narrative_session("a")["phase"]=="choice","P6 choice pending")
    check(world.world.narrative_session("b")["phase"]=="finished","P6 independent story")
    check(not world.world.player_knows("shop:rumor"),"P2 offscreen knowledge leak")
    check(world.world.social_view()["knowledge"]["mona"].has("shop:rumor"),"NPC gossip missing")
    check(world.world.housing_view()["objects"]["cupboard1"]["unit_id"]=="roof","P5 furniture missing")
    check(world.ink_choices("a").size()==2,"pending Ink choices")
    var start: Dictionary=world.world.view()
    check(world.save().get("ok",false),"whole world save + readback")
    check(world.diagnostics()["last_save_revision"]==start["sequence"],"diagnostics revision")
    world.dispose()
    var restored=World.new(1,path)
    var status: Dictionary=restored.load_existing()
    check(status.get("code")=="RESTORED","save reload result")
    check(JSON.stringify(restored.world.view())==JSON.stringify(start),"disk bytes/replay mismatch")
    check(restored.attach_ink("a","res://content/ink/sys_p6_conversation.ink.json"),"recreate A")
    check(restored.attach_ink("b","res://content/ink/sys_p6_gossip.ink.json"),"recreate B")
    if not await _ready_ink(restored):
        failures.append("restored native Ink loading")
        _done()
        return
    check(restored.ink_choices("a").size()==2,"real Ink pending choices lost")
    check(restored.ink_choose("a","ask","p7:native:choose").get("ok",false),"branch")
    check(restored.world.player_knows("sports:result"),"gated world knowledge missing")
    for id in ["reaction","rejoin"]:
        check(restored.ink_next("a","p7:native:"+id).get("code")=="LINE","Ink branch "+id)
    check(restored.ink_next("a","p7:native:finish").get("code")=="FINISHED","Ink close")
    var prepared: Dictionary=action(restored,"p7:native:finish_cook","player","cook.step.finish",{"job_id":"batch"})
    check(prepared.get("ok",false),"finished cooking")
    var delivered: Dictionary=action(restored,"p7:native:deliver","player","order.deliver",
        {"order_id":"order:tea","item_id":"item:batch"})
    check(delivered.get("ok",false),"delivered real item")
    check(action(restored,"p7:native:quote","system:pricing","economy.order.quote",
        {"claim_id":"payment:order:order:tea"}).get("ok",false),"priced real claim")
    var settled: Dictionary=action(restored,"p7:native:settle","system:service","economy.order.settle",
        {"claim_id":"payment:order:order:tea","transaction_id":"p7:native:payment"})
    check(settled.get("ok",false),"ledger settlement")
    check(action(restored,"p7:native:settle","system:service","economy.order.settle",
        {"claim_id":"payment:order:order:tea","transaction_id":"p7:native:payment"})==settled,"settlement idempotency")
    check(restored.world.balance_minor()==1025,"money duplication after order")
    check(action(restored,"p7:native:rent","player","housing.rent.pay",
        {"lease_id":"lease","transaction_id":"p7:native:rentpayment"}).get("ok",false),"pay accrued rent")
    check(restored.world.balance_minor()==875 and restored.world.can_access_unit("flat"),"ledger/housing entitlements")
    check(restored.advance(6,"p7:native:time:18").get("ok",false),"clock while finished story")
    check(restored.world.npc("visitor")["location_id"]=="home","NPC left after time advance")
    var final_state: Dictionary=restored.world.view()
    check(restored.save().get("ok",false),"second disk save")
    restored.dispose()
    var twice=World.new(2,path)
    check(twice.load_existing().get("ok",false),"second load")
    check(JSON.stringify(twice.world.view())==JSON.stringify(final_state),"duplicate effects after second restore")
    check(twice.save().get("ok",false),"unchanged second save")
    check(JSON.stringify(twice.world.view())==JSON.stringify(final_state),"repeat save changed state")
    var poisoned: Dictionary=final_state.duplicate(true)
    poisoned["economy"]["accounts"]["player"]=999
    check(not twice.world.restore_snapshot(poisoned),"forged money accepted")
    poisoned=final_state.duplicate(true)
    poisoned["version"]=6
    check(not twice.world.restore_snapshot(poisoned),"old version implicitly migrated")
    poisoned=final_state.duplicate(true)
    poisoned["narrative"]["sessions"]["a"]["ink_state"]=["forged"]
    check(not twice.world.restore_snapshot(poisoned),"forged Ink cursor accepted")
    check(JSON.stringify(twice.world.view())==JSON.stringify(final_state),"failed restore damaged live world")
    var previous_path: String=twice.save_path
    twice.save_path="user://nk-p7-invalid.json"
    var file=FileAccess.open(twice.save_path,FileAccess.WRITE)
    file.store_string("{broken-json")
    file.close()
    check(not twice.load_existing().get("ok",false),"invalid disk save accepted")
    check(JSON.stringify(twice.world.view())==JSON.stringify(final_state),"invalid disk load mutated world")
    twice.save_path=previous_path
    twice.dispose()
    for p in [path,"user://nk-p7-invalid.json"]:
        if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    _done()

func _done() -> void:
    if failures.is_empty():
        print("SYS P7: PASS (all domains, real Ink, twice disk reload, replay and corrupt save)")
        quit(0)
    else:
        for why in failures: push_error(why)
        print("SYS P7: FAIL (%d assertions)"%failures.size())
        quit(1)
