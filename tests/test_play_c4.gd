extends SceneTree
## PLAY C4: independent world-timed NPC intent, capacity, replay and chunking.
const Session = preload("res://scripts/integration/world_session.gd")
const Config = preload("res://scripts/integration/customer_demand_config.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const CATALOG = "res://content/world/qa_nile_kiosk.v1.json"
const POLICY = "res://content/service/qa_autonomous_demand.v1.json"
const SAVE = "user://nk-play-c4-native.json"
const PLAN_ID = "qa:reda:regular"
const OFFER_ID = "demand:qa:reda:regular:1"
var errors: Array[String] = []

func _initialize() -> void:
    _run()
    if errors.is_empty():
        print("PLAY C4: PASS (NPC-independent demand, timed expiry, no forged schedules, chunking/replay/save)")
        quit(0)
    else:
        for e in errors: push_error(e)
        print("PLAY C4: FAIL (%d)" % errors.size())
        quit(1)

func check(condition: bool, label: String) -> void:
    if not condition: errors.append(label)

func command(w: RefCounted, id: String, kind: String, p: Dictionary, actor: String = "system:director") -> Dictionary:
    return w.command("c4:"+id, actor, kind, p)

func _setup(seed: int, path: String) -> RefCounted:
    var s = Session.new(seed,path)
    check(s.bootstrap_from_content(CATALOG).get("ok",false),"C0 authored setup")
    check(s.configure_navigation("res://content/navigation/qa_routes.v1.json").get("ok",false),"C2 nav")
    check(Config.configure(s,POLICY).get("ok",false),"C4 policy configure")
    return s

func _run() -> void:
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var p: Dictionary = Config.load_plan(POLICY)
    check(p.get("ok",false),"packaged plan")
    if not p.get("ok",false): return
    var bad: Dictionary = p["plan"].duplicate(true)
    check(Config.load_plan("user://unsafe.json")["code"]=="UNTRUSTED_POLICY_PATH","user-writable policy")
    check(Config.load_plan("res://content/service/../world/qa.json")["code"]=="UNTRUSTED_POLICY_PATH","path traversal")
    check(Config.load_plan("res://content/service/nonexistent.json")["code"]=="POLICY_NOT_FOUND","missing file")
    var s = _setup(72,SAVE)
    var first: Dictionary=s.world.view()
    check(first["society"]["player_location"]=="roof","player should be offscreen")
    check(first["service"]["orders"].is_empty(),"demand should not occur until time")
    check(Config.configure(s,POLICY)["code"]=="ALREADY_CONFIGURED","duplicate config")
    check(command(s,"spoof","service.demand.configure",p["plan"],"player")["code"]=="INVALID_AUTHOR_OR_PAYLOAD","forged policy actor")
    check(command(s,"same","service.demand.configure",p["plan"])["code"]=="DEMAND_ALREADY_CONFIGURED","conflicting duplicate policy")
    bad["first_minute"]=0
    check(command(s,"past","service.demand.configure",bad)["code"]=="INVALID_PAYLOAD","past demand")
    bad=p["plan"].duplicate(true)
    bad["chance_bp"]=10001
    check(command(s,"chance","service.demand.configure",bad)["code"]=="INVALID_PAYLOAD","out-of-range chance")
    bad=p["plan"].duplicate(true)
    bad["interval_minutes"]=20
    check(command(s,"overlap","service.demand.configure",bad)["code"]=="OVERLAPPING_DEMAND","overlap policy")
    bad=p["plan"].duplicate(true)
    bad["npc_id"]="unknown"
    check(command(s,"unknown","service.demand.configure",bad)["code"]=="UNKNOWN_DEMAND_REFERENCE","unknown customer")
    var generic: Dictionary={
        "job_id":"service:demand:offer:forged","due_minute":2,"priority":250,
        "topic":"service.demand.offer","data":p["plan"],"every_minutes":0
    }
    check(command(s,"fake_schedule","schedule.create",generic)["code"]=="INVALID_PAYLOAD","forged generic service timer")
    check(command(s,"fake_cancel","schedule.cancel",{"job_id":"service:demand:offer:"+PLAN_ID})["code"]=="DOMAIN_OWNED_JOB","untrusted demand cancellation")
    check(command(s,"fake_move","schedule.reschedule",{"job_id":"service:demand:offer:"+PLAN_ID,"due_minute":9,"priority":100})["code"]=="DOMAIN_OWNED_JOB","untrusted demand reschedule")
    check(JSON.stringify(s.world.view())==JSON.stringify(first),"rejected commands mutated world")
    var again = _setup(72,"user://nk-play-c4-repeat.json")
    check(JSON.stringify(s.world.view())==JSON.stringify(again.world.view()),"same seed policy import not deterministic")
    check(s.advance(5,"c4:clock:5").get("ok",false),"NPC arrival at minute5")
    check(s.world.npc("reda")["location_id"]=="kiosk","routine arrival")
    check(s.world.orders_view()["orders"].is_empty(),"offer before due")
    check(s.advance(1,"c4:clock:6").get("ok",false),"autonomous offer minute6")
    check(s.world.order(OFFER_ID)["status"]=="offered","NPC didn't order without player")
    check(s.world.order(OFFER_ID)["created_minute"]==6 and s.world.order(OFFER_ID)["deadline_minute"]==26,"authored exact due and wait")
    check(s.world.balance_minor()==300,"world generated free money")
    check(command(s,"accept","order.accept",{"order_id":OFFER_ID,"seat_id":""},"player")["code"]=="PLAYER_ABSENT","offscreen player accepted")
    check(s.save().get("ok",false),"save at autonomous offer")
    var snap: Dictionary=s.world.view()
    var reloaded=Session.new(9,SAVE)
    check(reloaded.load_existing().get("code")=="RESTORED","independent NPC offer restore")
    check(JSON.stringify(reloaded.world.view())==JSON.stringify(snap),"full event replay at mid-order")
    check(reloaded.advance(20,"c4:clock:26").get("ok",false),"customer deadline")
    check(reloaded.world.order(OFFER_ID)["status"]=="abandoned" and reloaded.world.order(OFFER_ID)["closed_minute"]==26,"autonomous deadline expiry")
    check(reloaded.world.balance_minor()==300,"expired offer paid customer")
    var outcome: Array=[]
    for e in reloaded.world.event_history_after(0):
        if e["kind"]=="time.advanced":
            outcome.append_array(e["payload"]["effect"]["order_outcomes"])
    check(outcome.any(func(x: Dictionary) -> bool: return x.get("order_id","")==OFFER_ID and x.get("outcome","")=="offered"),"missing offered provenance")
    check(outcome.any(func(x: Dictionary) -> bool: return x.get("order_id","")==OFFER_ID and x.get("outcome","")=="deadline"),"missing deadline provenance")
    # Big versus split timeline: expected same domain state and scheduling.
    var big=_setup(72,"user://nk-play-c4-big.json")
    var small=_setup(72,"user://nk-play-c4-small.json")
    check(big.advance(50,"c4:large:50").get("ok",false),"large tick")
    for minute in range(1,51):
        check(small.advance(1,"c4:minute:"+str(minute)).get("ok",false),"small tick:"+str(minute))
    check(big.world.orders_view()==small.world.orders_view(),"big/small demand order state")
    check(big.world.npc("reda")==small.world.npc("reda"),"NPC chunking diverged")
    var due_id: String="service:demand:expire:"+PLAN_ID
    for id in ["service:demand:offer:"+PLAN_ID,due_id]:
        var a: Dictionary=big.world.view()["jobs"][id]
        var b: Dictionary=small.world.view()["jobs"][id]
        check(a["status"]==b["status"] and a["due_minute"]==b["due_minute"] and a["execution_count"]==b["execution_count"],"scheduled repeat drift "+id)
    check(big.world.order(OFFER_ID)["status"]=="abandoned" and big.world.order(OFFER_ID)["closed_minute"]==26,"large tick deadline handled")
    check(big.world.view()["society"]["player_location"]=="roof","world still independent of player")
    check(big.advance(1396,"c4:clock:1446").get("ok",false),"repeat due without routine")
    var order2: String="demand:"+PLAN_ID+":2"
    check(not big.world.orders_view()["orders"].has(order2),"absent NPC manufactured next-day order")
    var repeated: Array=big.world.event_history_after(0)[-1]["payload"]["effect"]["order_outcomes"]
    check(repeated.any(func(x: Dictionary) -> bool: return x.get("order_id","")==order2 and x.get("reason","")=="npc_absent"),"missing skipped absence provenance")
    # Zero interest policy is a real deterministic no-order case.
    var zero=_setup(9,"user://nk-play-c4-zero.json")
    var no: Dictionary=p["plan"].duplicate(true)
    no["plan_id"]="qa:zero"
    no["npc_id"]="amina"
    no["first_minute"]=7
    no["interval_minutes"]=0
    no["chance_bp"]=0
    check(command(zero,"zero","service.demand.configure",no).get("ok",false),"configure zero intent")
    check(zero.advance(7,"c4:zero:time").get("ok",false),"zero intent advance")
    check(not zero.world.orders_view()["orders"].has("demand:qa:zero:1"),"zero chance created order")
    check(zero.world.restore_snapshot(zero.world.view()),"canonical replay with service policy")
    var forged: Dictionary=big.world.view()
    forged["service"]["orders"][OFFER_ID]["status"]="delivered"
    check(not big.world.restore_snapshot(forged),"forged autonomous fulfillment accepted")
    var normal: Dictionary=big.world.view()
    check(big.world.restore_snapshot(normal),"real recorded world won't replay")
    check(JSON.stringify(big.world.view())==JSON.stringify(normal),"replay changed autonomous timeline")
    for path in [SAVE,"user://nk-play-c4-repeat.json","user://nk-play-c4-big.json","user://nk-play-c4-small.json","user://nk-play-c4-zero.json"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
