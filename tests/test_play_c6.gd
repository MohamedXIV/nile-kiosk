extends SceneTree
## PLAY C6: derived prior service, no player-facing reputation domain.
const Session = preload("res://scripts/integration/world_session.gd")
const Demand = preload("res://scripts/integration/customer_demand_config.gd")
const Service = preload("res://scripts/integration/kiosk_service_play.gd")
const Experience = preload("res://scripts/core/customer_experience.gd")
const C0 = "res://content/world/qa_nile_kiosk.v1.json"
const QA = "res://content/service/qa_repeat_customer.v1.json"
const SAVE = "user://nk-play-c6-test.json"
var problems: Array[String] = []
var serial: int = 0

func _initialize() -> void:
    _run()
    if problems.is_empty():
        print("PLAY C6: PASS (settled/abandoned/neutral visit feedback, isolation, chunking and replay)")
        quit(0)
    else:
        for problem in problems: push_error(problem)
        print("PLAY C6: FAIL (%d)" % problems.size())
        quit(1)

func check(ok: bool, why: String) -> void:
    if not ok: problems.append(why)

func command(s: RefCounted, actor: String, kind: String, payload: Dictionary) -> Dictionary:
    serial += 1
    return s.command("c6:test:"+str(serial),actor,kind,payload)

func world(seed: int = 42) -> RefCounted:
    var s = Session.new(seed,SAVE)
    check(s.bootstrap_from_content(C0).get("ok",false),"C0 boot")
    return s

func add_plan(s: RefCounted, id: String, initial: int, base: int, success: int, abandoned: int, include_social: bool = false) -> Dictionary:
    var plan: Dictionary = {
        "plan_id":id,"npc_id":"reda","venue_id":"kiosk","recipe_id":"tea",
        "route":"counter","first_minute":initial,"interval_minutes":0,
        "wait_minutes":5,"chance_bp":base,
        "experience_rule":{"settled_bonus_bp":success,"abandoned_penalty_bp":abandoned}
    }
    if include_social:
        plan["social_rule"]={"fact_id":"weather:nile","fact_bonus_bp":5000,
            "trusted_peer_id":"amina","trust_bonus_bp":0}
    check(command(s,"system:director","service.demand.configure",plan).get("ok",false),"configure "+id)
    return plan

func offer(s: RefCounted, id: String, venue: String, end_at: int = 16) -> void:
    check(command(s,"reda","order.offer",{
        "order_id":id,"npc_id":"reda","venue_id":venue,"recipe_id":"tea",
        "route":"counter","deadline_minute":end_at
    }).get("ok",false),"NPC first offer "+id)

func find_outcome(s: RefCounted, order_id: String) -> Dictionary:
    for e in s.world.event_history_after(0):
        if e["kind"]!="time.advanced": continue
        for outcome in e["payload"]["effect"]["order_outcomes"]:
            if outcome.get("order_id","")==order_id and outcome.has("experience_evidence"):
                return outcome
    return {}

func _run() -> void:
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var parsed: Dictionary = Demand.load_plan(QA)
    check(parsed.get("ok",false),"packaged QA recurrence")
    if not parsed.get("ok",false): return
    var qa: Dictionary=parsed["plan"]
    check(qa["experience_rule"]=={"settled_bonus_bp":0,"abandoned_penalty_bp":10000},"QA isolated policy")
    var old: Dictionary=Demand.load_plan("res://content/service/qa_autonomous_demand.v1.json")
    var social: Dictionary=Demand.load_plan("res://content/service/qa_social_demand.v1.json")
    check(old.get("ok",false) and social.get("ok",false),"C4/C5 policies rejected")
    check(Experience.validate({"settled_bonus_bp":5000,"abandoned_penalty_bp":2000}),"valid experience rule")
    for invalid in [
        {"settled_bonus_bp":-1,"abandoned_penalty_bp":0},
        {"settled_bonus_bp":1,"abandoned_penalty_bp":10001},
        {"settled_bonus_bp":1,"abandoned_penalty_bp":0,"fake":"yes"},
        {"settled_bonus_bp":"100","abandoned_penalty_bp":0}
    ]:
        check(not Experience.validate(invalid),"malformed feedback passed "+str(invalid))
    var invalid_s: RefCounted=world()
    var malformed: Dictionary=qa.duplicate(true)
    malformed["experience_rule"]["abandoned_penalty_bp"]=10001
    check(command(invalid_s,"system:director","service.demand.configure",malformed)["code"]=="INVALID_EXPERIENCE_RULE","kernel accepted forged bonus")
    malformed=qa.duplicate(true)
    malformed["experience_rule"]["unexpected"]=true
    check(command(invalid_s,"system:director","service.demand.configure",malformed)["code"]=="INVALID_EXPERIENCE_RULE","kernel accepted extra experience key")

    # First real world-time offer expires with the player away. The second
    # recurrence is suppressed by a previous same-venue abandonment.
    var large=world(21)
    var small=world(21)
    check(Demand.configure(large,QA).get("ok",false),"QA plan large")
    check(Demand.configure(small,QA).get("ok",false),"QA plan small")
    check(large.advance(20,"c6:large:20").get("ok",false),"large scheduled tick")
    for i in range(20):
        check(small.advance(1,"c6:small:"+str(i)).get("ok",false),"small scheduled tick")
    var first_id="demand:qa:reda:revisit:1"
    var second_id="demand:qa:reda:revisit:2"
    check(large.world.order(first_id)["status"]=="abandoned","first offer did not expire")
    check(large.world.order(first_id)["closed_minute"]==10,"first deadline not minute10")
    check(not large.world.orders_view()["orders"].has(second_id),"abandoned customer returned at same base chance")
    var second: Dictionary=find_outcome(large,second_id)
    check(second.get("reason","")=="not_interested","second attempt not declined")
    check(second.get("experience_evidence",{})=={"last_order_id":first_id,"last_outcome":"abandoned",
        "adjustment_bp":-10000,"chance_bp":0},"abandoned experience evidence wrong")
    check(large.world.orders_view()==small.world.orders_view(),"demand chunking diverged")
    check(find_outcome(large,second_id)==find_outcome(small,second_id),"chunked decision evidence diverged")
    check(large.world.balance_minor()==300,"customer departure minted cash")

    # Successful service, quote and *real* ledger settlement change only the
    # customer's next propensity, with NO new mutable sentiment state.
    var paid=world(88)
    check(command(paid,"system:director","social.player.place",{"location_id":"kiosk"}).get("ok",false),"player to kiosk pre-spatial QA")
    check(paid.advance(5,"c6:paid:arrive").get("ok",false),"Reda arrives")
    offer(paid,"first:paid","kiosk")
    check(command(paid,"player","order.accept",{"order_id":"first:paid","seat_id":""}).get("ok",false),"accept paid job")
    for pair in [
        ["cook.start",{"job_id":"prep:paid","recipe_id":"tea","deadline_minute":16}],
        ["cook.step.begin",{"job_id":"prep:paid","station_id":"kettle"}]
    ]:
        check(command(paid,"player",pair[0],pair[1]).get("ok",false),"prep "+str(pair[0]))
    check(paid.advance(2,"c6:paid:heat").get("ok",false),"heating 2 minutes")
    check(command(paid,"player","cook.step.finish",{"job_id":"prep:paid"}).get("ok",false),"heat finished")
    check(command(paid,"player","cook.step.begin",{"job_id":"prep:paid","station_id":"counter"}).get("ok",false),"serve began")
    check(paid.advance(1,"c6:paid:serve").get("ok",false),"serve minute")
    check(command(paid,"player","cook.step.finish",{"job_id":"prep:paid"}).get("ok",false),"serve finished")
    check(command(paid,"player","order.deliver",{"order_id":"first:paid","item_id":"item:prep:paid"}).get("ok",false),"real item delivery")
    var claim: String="payment:order:first:paid"
    check(command(paid,"system:pricing","economy.order.quote",{"claim_id":claim}).get("ok",false),"quoted price")
    check(command(paid,"system:service","economy.order.settle",{"claim_id":claim,"transaction_id":"c6:paid:tx"}).get("ok",false),"real settlement")
    check(paid.world.balance_minor()==317 and paid.world.order("first:paid")["payment_status"]=="settled","ledger not paid")
    add_plan(paid,"qa:paid:next",18,0,10000,10000)
    check(paid.advance(10,"c6:paid:next18").get("ok",false),"second paid visit")
    var paid_id="demand:qa:paid:next:1"
    check(paid.world.order(paid_id)["status"]=="offered","previous paid service did not improve repeat demand")
    check(find_outcome(paid,paid_id)["experience_evidence"]=={"last_order_id":"first:paid","last_outcome":"settled",
        "adjustment_bp":10000,"chance_bp":10000},"paid provenance incorrect")

    # Delivered but NOT settled is neutral; cancel is neutral too.
    var quoted=world(88)
    check(quoted.advance(5,"c6:quoted:visit").get("ok",false),"quoted Reda arrival")
    offer(quoted,"first:unpaid","kiosk",14)
    check(command(quoted,"reda","order.cancel",{"order_id":"first:unpaid","reason":"withdrawn"}).get("ok",false),"cancel first order")
    add_plan(quoted,"qa:cancel:neutral",18,0,10000,10000)
    check(quoted.advance(13,"c6:neutral:next18").get("ok",false),"neutral clock")
    var neutral_id="demand:qa:cancel:neutral:1"
    check(not quoted.world.orders_view()["orders"].has(neutral_id),"cancelled order produced positive/negative memory")
    check(find_outcome(quoted,neutral_id)["experience_evidence"]["last_outcome"]=="none","cancelled visit counted as failure")

    # Old service at a DIFFERENT venue must not alter the kiosk regular.
    var other=world(88)
    check(command(other,"system:director","service.configure",{"venue_id":"other_counter",
        "location_id":"kiosk","counter_slots":1,"takeaway_slots":0,"table_ids":[]}).get("ok",false),"second venue")
    check(other.advance(5,"c6:other:arrive").get("ok",false),"other venue Reda")
    offer(other,"other:abandon","other_counter",10)
    check(other.advance(5,"c6:other:expire").get("ok",false),"other venue abandoned")
    add_plan(other,"qa:other:isolate",18,10000,0,10000)
    check(other.advance(8,"c6:other:next").get("ok",false),"other venue repeat")
    var other_id="demand:qa:other:isolate:1"
    check(other.world.order(other_id)["status"]=="offered","other venue unfairly penalized kiosk")
    check(find_outcome(other,other_id)["experience_evidence"]["last_outcome"]=="none","cross-venue memory contamination")

    # Save and reload never synthesizes another customer outcome or ledger.
    var expected: Dictionary=paid.world.view()
    check(paid.save().get("ok",false),"save paid repeat experience")
    var restored=Session.new(1,SAVE)
    check(restored.load_existing().get("code")=="RESTORED","restore paid repeat experience")
    check(JSON.stringify(restored.world.view())==JSON.stringify(expected),"disk restore changed paid customer decision")
    check(restored.world.restore_snapshot(restored.world.view()),"legitimate replay failed")
    var forged: Dictionary=expected.duplicate(true)
    forged["service"]["orders"][paid_id]["status"]="delivered"
    check(not restored.world.restore_snapshot(forged),"forged repeat outcome accepted")
    forged=expected.duplicate(true)
    for event in forged["events"]:
        if event["kind"]!="time.advanced": continue
        for outcome in event["payload"]["effect"]["order_outcomes"]:
            if outcome.get("order_id","")==paid_id and outcome.has("experience_evidence"):
                outcome["experience_evidence"]["chance_bp"]=0
    check(not restored.world.restore_snapshot(forged),"forged experience evidence accepted")
    check(JSON.stringify(restored.world.view())==JSON.stringify(expected),"bad restore corrupted state")
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
