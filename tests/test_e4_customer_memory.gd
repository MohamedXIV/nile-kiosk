extends SceneTree
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const SAVE = "user://e4-customer-memory-test.json"
var errors: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
    if not value:
        errors.append(message)
        push_error(message)
func ok(result: Dictionary, message: String) -> void:
    check(result.get("ok",false), message+": "+str(result))
func move(g: RefCounted, count: int) -> void:
    for i in range(count): ok(g.move_world(18,0),"walk")
func elapse(g: RefCounted, minutes: int) -> Dictionary:
    return g.session.advance(minutes,"test:memory:clock:"+str(g.session.world.view()["sequence"]))
func enter(g: RefCounted) -> void:
    move(g,1); ok(g.travel_near(),"roof exit")
    move(g,9); ok(g.travel_near(),"landing exit")
    move(g,9); ok(g.travel_near(),"street exit")
    move(g,4); ok(g.open_kiosk(),"open")
    ok(elapse(g,19),"first scheduled customer")
func serve(g: RefCounted, rough: bool, settle: bool = true) -> void:
    ok(g.service_near(),"accept"); ok(g.service_near(),"prepare")
    ok(g.tea_action_near("H"),"heat")
    ok(elapse(g,20 if rough else 2),"actual kettle timing")
    ok(g.tea_action_near("H"),"lift"); ok(g.tea_action_near("U"),"pour")
    ok(g.wait_minutes(1),"pour time"); ok(g.tea_action_near("U"),"finish")
    ok(g.service_near(),"deliver")
    if settle:
        ok(g.service_near(),"quote"); ok(g.service_near(),"settle")
func ready(g: RefCounted) -> bool:
    for i in range(180):
        if g.memory_story_ready(): return true
        await process_frame
    return false
func _run() -> void:
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var probe: RefCounted = Game.new()
    ok(probe.start(SAVE),"boot")
    if not probe.session.world.has_method("customer_memory"):
        check(false,"canonical returning-customer memory API is missing")
        probe.dispose(); done(); return
    check(probe.session.world.customer_memory("mahmoud","kiosk").is_empty(),"invented first-visit memory")
    check(not probe.memory_story_begin().get("ok",false),"offsite/fresh customer starts memory")
    probe.dispose()
    for neutral in ["cancelled","unpaid"]:
        var n: RefCounted = Game.new(); ok(n.start(SAVE),"neutral history boot"); enter(n)
        if neutral == "cancelled":
            var id: String = str(n.session.world.orders_view()["orders"].keys()[0])
            ok(n.session.command("memory:cancel","player","order.cancel",{"order_id":id,"reason":"changed-mind"}),"cancel actual order")
        else: serve(n,false,false)
        ok(elapse(n,2479-int(n.status()["minute"])),"neutral return")
        check(n.session.world.customer_memory("mahmoud","kiosk").is_empty(),"neutral/unpaid visit invented paid memory")
        check(n.memory_story_begin().get("code","")=="NO_CUSTOMER_MEMORY","neutral history launched memory dialogue")
        n.dispose()
    for outcome in ["good","rough","abandoned"]:
        var g: RefCounted = Game.new()
        ok(g.start(SAVE),"new branch"); enter(g)
        check(g.session.world.customer_memory("mahmoud","kiosk").is_empty(),"first order called a return")
        if outcome == "abandoned":
            ok(elapse(g,121),"genuine deadline abandonment")
        else: serve(g,outcome=="rough")
        var orders: Dictionary = g.session.world.orders_view()["orders"]
        if orders.is_empty():
            g.dispose(); done(); return
        var first_id: String = str(orders.keys()[0])
        check(g.session.world.customer_memory("salma","kiosk").is_empty(),"another NPC inherited customer's history")
        check(g.session.world.customer_memory("mahmoud","elsewhere").is_empty(),"history crossed venues")
        check(g.session.world.customer_memory("mahmoud","kiosk").is_empty(),"same encounter counted as a return")
        ok(elapse(g,2479-int(g.status()["minute"])),"next actual day/visit")
        var memory: Dictionary = g.session.world.customer_memory("mahmoud","kiosk")
        check(memory.get("order_id","")==first_id and memory.get("branch","")==outcome,"wrong authoritative history "+str(memory))
        check(memory.get("return_order_id","")!=first_id,"did not require a new order")
        check(g.status()["active_order"]==memory.get("return_order_id","") and g.status()["order_status"]=="offered","HUD still prioritizes previous settled order")
        check(g.npc_pose("mahmoud").get("order_id","")==memory.get("return_order_id",""),"returning visitor pose used previous day order")
        var attachment: Dictionary = g.memory_story_begin()
        check(attachment.get("code","")=="INK_LOADING","attach real Ink "+str(attachment)+" orders="+str(g.session.world.orders_view()["orders"])+" pos="+str(g.position())+" npc="+str(g.npc_pose("mahmoud")))
        if not await ready(g): check(false,"Ink not ready"); g.dispose(); continue
        ok(g.memory_story_begin(),"begin returned customer story")
        var line: Dictionary = g.memory_story_next()
        check(line.get("beat_id","")=="memory_"+outcome,"authored history branch wrong "+str(line))
        check(str(line.get("text","")).contains("last time"),"returning customer does not recognize earlier visit")
        if outcome == "good":
            ok(g.save_game(),"save directly after recognition line before choice wait")
            g.dispose()
            g = Game.new(); ok(g.start(SAVE),"restore line-to-choice handoff")
            g.memory_story_begin(); check(await ready(g),"attach line-boundary cursor")
            ok(g.memory_story_begin(),"resume line boundary")
        var s: Dictionary = g.memory_story_session()
        check(s.get("customer_memory",{})==memory,"P6 did not pin authoritative provenance")
        var wrong: Dictionary = g.session.command("memory:wrong:"+outcome,"system:narrative","narrative.line.commit",{
            "session_id":s["session_id"],"beat_id":"memory_rough" if outcome!="rough" else "memory_good",
            "mode":"broadcast","audience_ids":[],"ink_state":s["ink_state"]})
        check(wrong.get("code","")=="MEMORY_BRANCH_MISMATCH","forged memory line accepted")
        check(g.memory_story_next().get("code","")=="WAITING","line-boundary reload lost pending Ink choice point" if outcome=="good" else "pending authored choice missing")
        check(not g.status()["supplier_known"],"contact granted before hearing")
        for i in range(4): ok(g.move_world(-18,0),"leave hearing range")
        var far: String = g.status()["digest"]
        check(g.memory_story_choose("supplier").get("code","")=="CUSTOMER_TOO_FAR","remote choice leaked contact")
        check(g.memory_story_next().get("code","")=="CUSTOMER_TOO_FAR","remote speech advanced")
        check(g.status()["digest"]==far and not g.status()["supplier_known"],"unheard memory changed world")
        move(g,4)
        ok(g.save_game(),"pending choice disk save")
        var before: Dictionary = g.session.world.view(); g.dispose()
        var restored: RefCounted = Game.new(); ok(restored.start(SAVE),"restore pending")
        check(Kernel._matches(before,restored.session.world.view()),"pending whole-world replay mismatch")
        restored.memory_story_begin(); check(await ready(restored),"reattach pending Ink")
        check(restored.memory_story_begin().get("code","")=="RESUMED","cursor restarted")
        var chosen: String = "leave" if outcome=="abandoned" else "supplier"
        ok(restored.memory_story_choose(chosen),"authored optional response")
        var answer: Dictionary = restored.memory_story_next()
        check(answer.get("beat_id","")==("memory_leave" if chosen=="leave" else "memory_supplier"),"choice branch mismatch")
        check(restored.status()["supplier_known"]==(chosen=="supplier"),"unheard contact leaked / heard contact missing")
        if chosen=="supplier":
            var knowledge: Dictionary = restored.session.world.social_view()["knowledge"]["player"]["mahmoud:tea-supplier"]
            check(knowledge.get("source_npc_id","")=="mahmoud" and not knowledge.get("event_id","").is_empty(),"no canonical speech provenance")
        restored.memory_story_next(); check(restored.memory_story_next().get("code","")=="FINISHED","story did not finish")
        check(not restored.memory_story_begin().get("ok",false),"same return repeated")
        var forged: Dictionary = restored.session.world.view()
        forged["narrative"]["sessions"][s["session_id"]]["customer_memory"]["order_id"]="invented"
        check(not Kernel.new().restore_snapshot(forged),"forged memory evidence restored")
        restored.dispose(); DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    done()
func done() -> void:
    if errors.is_empty(): print("E4 CUSTOMER MEMORY: PASS"); quit(0)
    else:
        for message in errors: push_error(message)
        print("E4 CUSTOMER MEMORY: FAIL "+str(errors.size())); quit(1)
