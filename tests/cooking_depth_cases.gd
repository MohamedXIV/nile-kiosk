extends RefCounted
const Kernel = preload("res://scripts/core/world_kernel.gd")
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
    if not value: failures.append(label); push_error(label)
func send(k: RefCounted, id: String, kind: String, payload: Dictionary, actor: String="player") -> Dictionary:
    return k.dispatch({"id":id,"actor_id":actor,"kind":kind,"payload":payload})
func run() -> Array[String]:
    var k: RefCounted = Kernel.new()
    check(send(k,"ingredient","ingredient.define",{"ingredient_id":"test_input","unit":"g"})["ok"],"ingredient fixture")
    var recipe: Dictionary={"recipe_id":"test_pan","steps":[{
        "station_type":"pan","inputs":{"test_input":1},"work_minutes":6,
        "technique":{"action_id":"turn","earliest_minutes":2,"finish_minutes":2}}],"shelf_minutes":30}
    var result: Dictionary=send(k,"recipe","recipe.define",recipe)
    check(result.get("ok",false),"P3 accepts reusable timed in-step technique: "+str(result))
    if result.get("ok",false): technique_actions(k)
    production_sandwich()
    print("COOKING DEPTH: PASS" if failures.is_empty() else "COOKING DEPTH: FAIL (%d)" % failures.size())
    return failures

func technique_actions(k: RefCounted) -> void:
    check(send(k,"stock","stock.add",{"ingredient_id":"test_input","quantity":2})["ok"],"stock fixture")
    check(send(k,"station","station.register",{"station_id":"pan","station_type":"pan"})["ok"],"pan fixture")
    check(send(k,"start","cook.start",{"job_id":"test","recipe_id":"test_pan","deadline_minute":60})["ok"],"start actual job")
    check(send(k,"begin","cook.step.begin",{"job_id":"test","station_id":"pan"})["ok"],"begin actual step")
    var early: String=JSON.stringify(k.view())
    check(send(k,"too:early","cook.step.action",{"job_id":"test","action_id":"turn"}).get("code")=="ACTION_TOO_EARLY" and JSON.stringify(k.view())==early,"cannot turn before real lead-in")
    check(k.advance_time(2,"two")["ok"],"time to turn")
    var before_action: Dictionary=k.view()
    var before: Dictionary=k.cooking_view()
    var turn: Dictionary=send(k,"turn","cook.step.action",{"job_id":"test","action_id":"turn"})
    check(turn.get("ok",false),"P3 records actual in-step turn: "+str(turn))
    if not turn.get("ok",false): return
    check(send(k,"turn","cook.step.action",{"job_id":"test","action_id":"turn"})==turn,"action receipt retry")
    check(send(k,"turn:twice","cook.step.action",{"job_id":"test","action_id":"turn"}).get("code")=="ACTION_ALREADY_DONE","no repeated turn")
    check(k.cooking_view()["stock"]==before["stock"] and k.cooking_view()["preparations"]["test"]["consumed"]==before["preparations"]["test"]["consumed"],"turn cannot consume twice")
    check(send(k,"early:finish","cook.step.finish",{"job_id":"test"}).get("code")=="STEP_NOT_READY","second face needs real time")
    check(k.advance_time(2,"second:face")["ok"],"cook other face")
    check(send(k,"finish","cook.step.finish",{"job_id":"test"})["ok"],"complete real item")
    check(k.cooking_view()["items"].has("item:test"),"one real produced item")
    check(send(k,"finish:twice","cook.step.finish",{"job_id":"test"}).get("code")=="INVALID_STAGE","no duplicate item minting")
    var restored: RefCounted=Kernel.new()
    check(restored.restore_snapshot(k.view()),"new action replays through existing Kernel seam")
    check(Kernel._matches(k.view(),restored.view()),"replayed item/state identical")
    var good: Dictionary=k.prepared_quality("item:test")
    check(good.get("grade")=="good" and good.get("action_late_minutes")==0,"on-time technique earns justified good quality")
    for interrupted in [false,true]:
        var late: RefCounted=Kernel.new()
        check(late.restore_snapshot(before_action),"fork genuine active history")
        check(late.advance_time(12,"late:time")["ok"],"actual over-searing")
        if interrupted:
            check(send(late,"late:interrupt","cook.step.interrupt",{"job_id":"test"})["ok"],"interrupt over-seared pan")
            check(send(late,"late:resume","cook.step.resume",{"job_id":"test","station_id":"pan"})["ok"],"resume over-seared pan")
        check(send(late,"late:turn","cook.step.action",{"job_id":"test","action_id":"turn"})["ok"],"late turn still allowed")
        check(late.advance_time(2,"late:other:face")["ok"],"late second face")
        check(send(late,"late:finish","cook.step.finish",{"job_id":"test"})["ok"],"imperfect but genuine item")
        var rough: Dictionary=late.prepared_quality("item:test")
        check(rough.get("grade")=="rough" and rough.get("action_late_minutes")==8,"timing history explains imperfect result; interrupt cannot wash it")
        var replayed: RefCounted=Kernel.new()
        check(replayed.restore_snapshot(late.view()) and replayed.prepared_quality("item:test")==rough,"quality survives verified replay")

    edge_cases(before_action,k)

func production_sandwich() -> void:
    check(ResourceLoader.exists("res://scripts/core/cooking_content.gd"),"executable cooking-content installer exists")
    if not ResourceLoader.exists("res://scripts/core/cooking_content.gd"): return
    var content: GDScript=load("res://scripts/core/cooking_content.gd")
    const Game=preload("res://scripts/gameplay/game_entry.gd")
    var path: String="user://nk-cooking-depth-game.json"
    if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var g: RefCounted=Game.new()
    check(g.start(path).get("ok",false),"real starter world")
    var k: RefCounted=g.session.world
    var stock_before: Dictionary=k.cooking_view()["stock"]
    var money_before: int=k.balance_minor()
    # The production Game now installs the pack on boot. For a genuine
    # *pre-install* conflict, bootstrap a pristine authored C0 world instead
    # of trying to redefine green_pepper in the already-installed game.
    var pristine: Dictionary=preload("res://scripts/integration/world_content_bootstrap.gd").from_file(
        "res://content/world/nile_opening.v1.json",71)
    check(pristine.get("ok",false),"pristine C0 preflight fixture")
    if not pristine.get("ok",false): return
    var conflict: RefCounted=pristine["candidate"]
    check(send(conflict,"conflict","ingredient.define",{"ingredient_id":"green_pepper","unit":"g"})["ok"],"existing content conflict fixture")
    var unchanged: String=JSON.stringify(conflict.view())
    check(not content.install(conflict).get("ok",false) and JSON.stringify(conflict.view())==unchanged,"whole-pack preflight prevents partial live installation")
    check(content.install(k).get("ok",false),"install authored recipe and paid ingredient offers")
    check(k.balance_minor()==money_before and k.cooking_view()["stock"]["bread"]==stock_before["bread"],"install grants neither cash nor stock")
    var digest: String=JSON.stringify(k.view())
    check(content.install(k).get("ok",false) and JSON.stringify(k.view())==digest,"idempotent content install on existing world")
    check(send(k,"no:stock","cook.start",{"job_id":"unpaid","recipe_id":"liver_sandwich","deadline_minute":1100}).get("code")=="INSUFFICIENT_STOCK","cannot cook without paying for real ingredients")
    check(send(k,"remote:buy","supply.purchase",{"offer_id":"sandwich:liver"}).get("code")=="WRONG_LOCATION","cannot remotely acquire stock")
    for r in range(3):
        if r>0:
            for i in range(9): check(g.move_world(18,0).get("ok",false),"actual travel approach")
        check(g.travel_near().get("ok",false),"actual travel to kiosk")
    check(g.room()=="kiosk","real P2 player at purchase location")
    var quantities: Dictionary={"liver":400,"garlic":12,"green_pepper":80,"cooking_oil":20,"lemon_juice":20,"bread":4}
    for ingredient in quantities:
        var old: int=int(k.cooking_view()["stock"][ingredient])
        var purchase: Dictionary=send(k,"buy:"+ingredient,"supply.purchase",{"offer_id":"sandwich:"+ingredient})
        check(purchase.get("ok",false),"paid acquisition "+ingredient)
        check(int(k.cooking_view()["stock"][ingredient])==old+int(quantities[ingredient]),"actual stock received "+ingredient)
        var state: String=JSON.stringify(k.view())
        check(send(k,"buy:"+ingredient,"supply.purchase",{"offer_id":"sandwich:"+ingredient})==purchase and JSON.stringify(k.view())==state,"purchase retry cannot bypass cost "+ingredient)
    check(k.balance_minor()==money_before-1560,"six genuine P5 paid transactions")
    check(send(k,"buy:liver:again","supply.purchase",{"offer_id":"sandwich:liver"}).get("code")=="OFFER_RESOLVED","finite stock lot cannot be minted twice")
    var before: Dictionary=k.cooking_view()["stock"]
    check(k.advance_time(1438-int(k.view()["world_minute"]),"before:midnight")["ok"],"real time near day boundary")
    for batch in range(4):
        var id: String="sandwich:"+str(batch)
        check(send(k,id+":start","cook.start",{"job_id":id,"recipe_id":"liver_sandwich","deadline_minute":int(k.view()["world_minute"])+60})["ok"],"reserve complete sandwich")
        check(send(k,id+":season","cook.step.begin",{"job_id":id,"station_id":"sandwich_board"})["ok"],"season actual liver and garlic")
        check(send(k,id+":wrong:gesture","cook.step.action",{"job_id":id,"action_id":"turn"}).get("code")=="ACTION_NOT_SUPPORTED","turn is a pan action, not a renamed bread step")
        check(k.advance_time(1,id+":season:time")["ok"],"seasoning minute")
        check(send(k,id+":seasoned","cook.step.finish",{"job_id":id})["ok"],"finish seasoning")
        check(send(k,id+":sear","cook.step.begin",{"job_id":id,"station_id":"sandwich_pan"})["ok"],"oil and pepper on actual pan")
        var turn_time: int=[2,9,14,2][batch]
        check(k.advance_time(turn_time,id+":sear:time")["ok"],"chosen searing time")
        check(send(k,id+":turn","cook.step.action",{"job_id":id,"action_id":"turn"})["ok"],"intentional turn")
        if batch==0:
            check(k.save_to_file("user://nk-cooking-depth-pan.json"),"save on pan after turn across midnight")
            var disk: RefCounted=Kernel.new()
            check(disk.load_from_file("user://nk-cooking-depth-pan.json") and Kernel._matches(k.view(),disk.view()),"real mid-pan disk/replay")
        check(k.advance_time(2,id+":other:face")["ok"],"second face cooks")
        check(send(k,id+":lift","cook.step.finish",{"job_id":id})["ok"],"lift after second face")
        check(send(k,id+":assemble","cook.step.begin",{"job_id":id,"station_id":"sandwich_board"})["ok"],"actual bread and lemon assembly")
        check(send(k,id+":finish","cook.step.finish",{"job_id":id})["ok"],"produce actual sandwich")
        var q: Dictionary=k.prepared_quality("item:"+id)
        check(q.get("grade")==["good","okay","rough","good"][batch],"repeatable quality explains timing: "+str(q))
        print("SANDWICH_RESULT "+JSON.stringify(q))
    for ingredient in quantities:
        var consumed: int=4*int(k.cooking_view()["recipes"]["liver_sandwich"]["total_inputs"][ingredient])
        check(int(k.cooking_view()["stock"][ingredient])==int(before[ingredient])-consumed,"all inputs consumed exactly once "+ingredient)
    check(send(k,"depleted","cook.start",{"job_id":"fifth","recipe_id":"liver_sandwich","deadline_minute":int(k.view()["world_minute"])+60}).get("code")=="INSUFFICIENT_STOCK","no infinite sandwich supply")
    check(k.save_to_file("user://nk-cooking-depth-complete.json"),"save four actual items")
    var loaded: RefCounted=Kernel.new()
    check(loaded.load_from_file("user://nk-cooking-depth-complete.json") and Kernel._matches(k.view(),loaded.view()),"all production state survives disk reload")
    check(loaded.prepared_quality("item:sandwich:2")==k.prepared_quality("item:sandwich:2"),"rough quality provenance survives reload")
    check(send(loaded,"plate","cook.item.use",{"item_id":"item:sandwich:1","purpose_id":"player:plate"})["ok"],"one actual prepared-item claim")
    check(send(loaded,"plate:twice","cook.item.use",{"item_id":"item:sandwich:1","purpose_id":"player:plate"}).get("code")=="ITEM_NOT_READY","no repeated inventory claim")
    var expiry: int=int(loaded.cooking_view()["items"]["item:sandwich:0"]["expires_minute"])
    check(loaded.advance_time(expiry-int(loaded.view()["world_minute"]),"exact:shelf:expiry")["ok"],"exact shelf boundary")
    check(loaded.cooking_view()["items"]["item:sandwich:0"]["status"]=="expired","shelf expiry remains authoritative")
    check(send(loaded,"expired:plate","cook.item.use",{"item_id":"item:sandwich:0","purpose_id":"player:plate"}).get("code")=="ITEM_NOT_READY","expired sandwich cannot be used")
    check(loaded.prepared_quality("item:sandwich:0").get("score")==100,"historical sensory outcome survives later expiry")
    g.dispose()

func fork(snapshot: Dictionary) -> RefCounted:
    var k: RefCounted=Kernel.new()
    check(k.restore_snapshot(snapshot),"fork verified domain history")
    return k

func edge_cases(active: Dictionary, complete: RefCounted) -> void:
    var k: RefCounted=fork(active)
    var state: String=JSON.stringify(k.view())
    for request in [
        {"job_id":"test","action_id":"stir"},
        {"job_id":"test","action_id":"turn","quality":"good"},
        {"job_id":"test"}, {"job_id":"missing","action_id":"turn"}]:
        check(not send(k,"invalid:"+str(request.size())+str(request),"cook.step.action",request).get("ok",false),"invalid action rejected")
    check(send(k,"not:player","cook.step.action",{"job_id":"test","action_id":"turn"},"system:director").get("code")=="UNAUTHORIZED","only player performs technique")
    check(send(k,"no:turn:finish","cook.step.finish",{"job_id":"test"}).get("code")=="ACTION_REQUIRED","time alone cannot bypass turn")
    check(JSON.stringify(k.view())==state,"all rejected gestures leave world intact")
    check(send(k,"turn:pause","cook.step.action",{"job_id":"test","action_id":"turn"})["ok"],"turn before pause")
    check(k.advance_time(1,"pause:time")["ok"],"partially cook second face")
    check(send(k,"pause","cook.step.interrupt",{"job_id":"test"})["ok"],"release actual pan")
    check(k.save_to_file("user://nk-cooking-depth-interrupted.json"),"save interrupted technique")
    var disk: RefCounted=Kernel.new()
    check(disk.load_from_file("user://nk-cooking-depth-interrupted.json"),"load interrupted technique")
    for branch in [k,disk]:
        check(branch.advance_time(20,"off:heat")["ok"],"clock continues off heat")
        check(send(branch,"resume","cook.step.resume",{"job_id":"test","station_id":"pan"})["ok"],"resume only remaining second-face work")
        check(send(branch,"repeat:after:resume","cook.step.action",{"job_id":"test","action_id":"turn"}).get("code")=="ACTION_ALREADY_DONE","resume cannot repeat turn")
        check(send(branch,"resume:early:finish","cook.step.finish",{"job_id":"test"}).get("code")=="STEP_NOT_READY","resume cannot skip remaining work")
        check(branch.advance_time(1,"remaining:minute")["ok"],"remaining canonical minute")
        check(send(branch,"resume:finish","cook.step.finish",{"job_id":"test"})["ok"],"finish after loaded interruption")
        check(branch.prepared_quality("item:test").get("score")==90,"off-pan time is not burning; interruption still visible")
    check(Kernel._matches(k.view(),disk.view()),"identical continuation after actual disk replay")
    var expired: RefCounted=fork(active)
    check(expired.advance_time(58,"deadline")["ok"],"exact preparation deadline")
    check(send(expired,"expired:turn","cook.step.action",{"job_id":"test","action_id":"turn"}).get("code")=="INVALID_STAGE","expired pan cannot mint food")
    check(expired.cooking_view()["items"].is_empty() and expired.cooking_view()["waste"]["test_input"]==1 and expired.cooking_view()["stations"]["pan"]["busy_job"]=="","deadline releases pan and accounts waste")
    var cancelled: RefCounted=fork(active)
    check(send(cancelled,"cancel:turn","cook.step.action",{"job_id":"test","action_id":"turn"})["ok"],"turn before cancellation")
    check(send(cancelled,"cancel","cook.cancel",{"job_id":"test"})["ok"],"cancel turned food")
    check(cancelled.cooking_view()["stock"]["test_input"]==1 and cancelled.cooking_view()["waste"]["test_input"]==1,"cancel cannot refund consumed food")
    var bad: Dictionary=complete.view()
    for event in bad["events"]:
        if event["kind"]=="cook.step_actioned": event["payload"]["effect"]["ready_minute"]+=1
    check(not Kernel.new().restore_snapshot(bad),"forged action timing rejected on replay")
    bad=active.duplicate(true)
    bad["cooking"]["preparations"]["test"]["step_action"]={"action_id":"turn"}
    check(not Kernel.new().restore_snapshot(bad),"forged projected action cannot bypass gesture")
    var chunks: Array[RefCounted]=[fork(active),fork(active)]
    check(chunks[0].advance_time(3,"whole")["ok"],"whole sear interval")
    for n in range(3): check(chunks[1].advance_time(1,"split:"+str(n))["ok"],"split sear interval")
    var qualities: Array[Dictionary]=[]
    for branch in chunks:
        check(send(branch,"chunk:turn","cook.step.action",{"job_id":"test","action_id":"turn"})["ok"],"same turn after elapsed chunks")
        check(branch.advance_time(2,"chunk:after")["ok"],"same second face")
        check(send(branch,"chunk:finish","cook.step.finish",{"job_id":"test"})["ok"],"same item after elapsed chunks")
        var q: Dictionary=branch.prepared_quality("item:test")
        q.erase("source_event_id") # Extra time commands legitimately change event IDs.
        qualities.append(q)
    check(qualities[0]==qualities[1],"quality and timing invariant under time chunking")
    var invalid: RefCounted=fork(active)
    var base: Dictionary=invalid.cooking_view()["recipes"]["test_pan"]["steps"][0]
    for value in [null,{}, {"action_id":"turn","earliest_minutes":0,"finish_minutes":2},
        {"action_id":"turn","earliest_minutes":7,"finish_minutes":2},
        {"action_id":"turn","earliest_minutes":2,"finish_minutes":1.5},
        {"action_id":"turn","earliest_minutes":2,"finish_minutes":false}]:
        var step: Dictionary=base.duplicate(true);step["technique"]=value
        check(not send(invalid,"invalid:tech:"+str(value),"recipe.define",{"recipe_id":"bad","steps":[step],"shelf_minutes":0}).get("ok",false),"invalid technique definition rejected")
    check(send(invalid,"free:pan","cook.cancel",{"job_id":"test"})["ok"],"free pan for time-bound test")
    var huge: Dictionary=base.duplicate(true);huge["technique"]["finish_minutes"]=2147483647
    check(send(invalid,"huge:recipe","recipe.define",{"recipe_id":"huge","steps":[huge],"shelf_minutes":0})["ok"],"bounded integer policy")
    check(send(invalid,"huge:start","cook.start",{"job_id":"huge","recipe_id":"huge","deadline_minute":60})["ok"],"reserve huge-duration recipe")
    check(send(invalid,"huge:begin","cook.step.begin",{"job_id":"huge","station_id":"pan"})["ok"],"begin huge-duration recipe")
    check(invalid.advance_time(2,"huge:time")["ok"],"lead-in before overflow")
    state=JSON.stringify(invalid.view())
    check(send(invalid,"huge:turn","cook.step.action",{"job_id":"huge","action_id":"turn"}).get("code")=="TIME_OVERFLOW" and JSON.stringify(invalid.view())==state,"action time overflow rejected atomically")
