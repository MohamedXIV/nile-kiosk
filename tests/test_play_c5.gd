extends SceneTree
## C5 — world-owned social modifiers; customer facts are NPC-owned, never player meters.
const Session = preload("res://scripts/integration/world_session.gd")
const Config = preload("res://scripts/integration/customer_demand_config.gd")
const C0 = "res://content/world/qa_nile_kiosk.v1.json"
const TRUSTED = "res://content/world/qa_nile_kiosk_social.v1.json"
const POLICY = "res://content/service/qa_social_demand.v1.json"
const SAVE = "user://nk-play-c5-test.json"
const OFFER = "demand:qa:reda:social:1"
var failures: Array[String] = []

func _initialize() -> void:
    _run()
    if failures.is_empty():
        print("PLAY C5: PASS (fact and trust modifiers, NPC-only knowledge, chunking, tamper/replay, legacy C4)")
        quit(0)
    else:
        for f in failures: push_error(f)
        print("PLAY C5: FAIL (%d)" % failures.size())
        quit(1)

func check(ok: bool, why: String) -> void:
    if not ok: failures.append(why)

func setup(seed: int, catalog: String = C0) -> RefCounted:
    var s = Session.new(seed,SAVE)
    check(s.bootstrap_from_content(catalog).get("ok",false),"C0 catalog "+catalog)
    check(s.configure_navigation("res://content/navigation/qa_routes.v1.json").get("ok",false),"navigation")
    var configured: Dictionary = Config.configure(s,POLICY)
    check(configured.get("ok",false),"C5 configured: "+str(configured))
    return s

func send(s: RefCounted, id: String, actor: String, kind: String, payload: Dictionary) -> Dictionary:
    return s.command("c5:"+id,actor,kind,payload)

func result_at(s: RefCounted, order_id: String) -> Dictionary:
    for event in s.world.event_history_after(0):
        if event["kind"] == "time.advanced":
            for outcome in event["payload"]["effect"]["order_outcomes"]:
                if outcome.get("order_id","") == order_id:
                    return outcome
    return {}

func _run() -> void:
    if FileAccess.file_exists(SAVE):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var configured: Dictionary = Config.load_plan(POLICY)
    check(configured.get("ok",false),"packaged social demand")
    if not configured.get("ok",false): return
    var plan: Dictionary = configured["plan"]
    check(plan["chance_bp"]==0 and plan["social_rule"]["trust_bonus_bp"]==10000,
        "QA social policy identity")
    var tamper: Dictionary=plan.duplicate(true)
    tamper["social_rule"]["fact_bonus_bp"]=-2
    var guard=setup(90)
    check(send(guard,"negative","system:director","service.demand.configure",tamper)["code"]=="INVALID_SOCIAL_RULE","negative boost")
    tamper=plan.duplicate(true)
    tamper["social_rule"]["trusted_peer_id"]="unknown"
    check(send(guard,"ghost-peer","system:director","service.demand.configure",tamper)["code"]=="UNKNOWN_SOCIAL_REFERENCE","ghost peer")
    tamper=plan.duplicate(true)
    tamper["social_rule"]["fact_id"]="missing"
    check(send(guard,"ghost-fact","system:director","service.demand.configure",tamper)["code"]=="UNKNOWN_SOCIAL_REFERENCE","invented fact")
    tamper=plan.duplicate(true)
    tamper["social_rule"]["extra"]="unexpected"
    check(send(guard,"extra","system:director","service.demand.configure",tamper)["code"]=="INVALID_SOCIAL_RULE","extra rule")
    tamper=plan.duplicate(true)
    tamper["social_rule"]["trusted_peer_id"]="reda"
    check(send(guard,"self","system:director","service.demand.configure",tamper)["code"]=="UNKNOWN_SOCIAL_REFERENCE","self-trust")
    check(Config.load_plan("res://content/service/qa_autonomous_demand.v1.json").get("ok",false),"legacy C4 manifest rejected")

    # Counterfactuals: same NPC/seed/scheduled time; player knows NOTHING.
    var neutral=setup(7)
    check(neutral.advance(6,"c5:neutral:6").get("ok",false),"neutral advance")
    check(not neutral.world.orders_view()["orders"].has(OFFER),"baseline 0% unexpectedly offered")
    var skipped: Dictionary=result_at(neutral,OFFER)
    check(skipped.get("reason","")=="not_interested" and skipped["social_evidence"]=={"fact_known":false,"peer_trusted":false,"chance_bp":0},"no relationship evidence")
    var trusted=setup(7,TRUSTED)
    check(trusted.world.view()["society"]["familiarity"]["reda"]["amina"]=="trusted","trusted author fixture")
    check(trusted.advance(6,"c5:trust:6").get("ok",false),"trusted world tick")
    check(trusted.world.order(OFFER)["status"]=="offered","NPC trust failed to cause scheduled interest")
    check(result_at(trusted,OFFER)["social_evidence"]=={"fact_known":false,"peer_trusted":true,"chance_bp":10000},"trust context not sampled")
    check(trusted.world.social_view()["player_location"]=="roof","world demand teleported player")
    check(not trusted.world.player_knows("weather:nile"),"player stole unrelated knowledge")

    # Knowledge modifier exists separately from peer trust: Reda hears Amina at
    # actual co-presence at minute five; the player stays on the roof.
    var learned=setup(7)
    var fact_plan: Dictionary=plan.duplicate(true)
    fact_plan["plan_id"]="qa:reda:fact-only"
    fact_plan["social_rule"]["fact_bonus_bp"]=10000
    fact_plan["social_rule"]["trust_bonus_bp"]=0
    check(send(learned,"fact-policy","system:director","service.demand.configure",fact_plan).get("ok",false),"fact policy configure")
    check(learned.advance(5,"c5:arrive:5").get("ok",false),"Reda arrival")
    check(learned.world.npc("reda")["location_id"]=="kiosk","Reda not co-present")
    check(send(learned,"speak","amina","social.speak",{"speaker_id":"amina","fact_id":"weather:nile","mode":"broadcast","audience_ids":[]}).get("ok",false),"legitimate NPC broadcast")
    check(learned.world.social_view()["knowledge"]["reda"].has("weather:nile"),"Reda didn't hear Amina")
    check(not learned.world.player_knows("weather:nile"),"offscreen social hearing leaked to player")
    check(learned.advance(1,"c5:learn:6").get("ok",false),"fact tick")
    var fact_order="demand:qa:reda:fact-only:1"
    check(learned.world.order(fact_order)["status"]=="offered","fact-known NPC didn't request item")
    check(result_at(learned,fact_order)["social_evidence"]=={"fact_known":true,"peer_trusted":false,"chance_bp":10000},"fact sample wrong")

    # Same customer may have only one active order; it must not generate the
    # original zero-interest plan after a context-free second chance.
    check(result_at(learned,OFFER)["reason"]=="not_interested","base zero-interest policy changed")
    # Two actual social paths yield independent outcomes from the same seed.
    var large=setup(81,TRUSTED)
    var small=setup(81,TRUSTED)
    check(large.advance(31,"c5:large").get("ok",false),"large advance")
    for i in range(31):
        check(small.advance(1,"c5:split:"+str(i)).get("ok",false),"small advance "+str(i))
    check(large.world.orders_view()==small.world.orders_view(),"chunking changed social demands")
    check(large.world.order(OFFER)["status"]=="abandoned" and large.world.order(OFFER)["closed_minute"]==26,"real deadline after social interest")
    var sig: Dictionary = large.world.view()
    check(large.world.restore_snapshot(sig),"valid social event replay")
    check(JSON.stringify(large.world.view())==JSON.stringify(sig),"social replay altered bytes")
    var forged: Dictionary=sig.duplicate(true)
    forged["service"]["orders"][OFFER]["status"]="delivered"
    check(not large.world.restore_snapshot(forged),"forged fulfillment accepted")
    forged=sig.duplicate(true)
    for index in range(forged["events"].size()):
        var evt: Dictionary=forged["events"][index]
        if evt["kind"]=="time.advanced":
            var outcomes: Array=evt["payload"]["effect"]["order_outcomes"]
            for pos in range(outcomes.size()):
                if outcomes[pos].get("order_id","")==OFFER and outcomes[pos].has("social_evidence"):
                    outcomes[pos]["social_evidence"]["chance_bp"]=0
    check(not large.world.restore_snapshot(forged),"forged social probability evidence accepted")
    check(JSON.stringify(large.world.view())==JSON.stringify(sig),"rejected tamper modified world")

    # Full disk save/reload preserves independently created orders and P2 trust.
    check(trusted.save().get("ok",false),"save after offscreen socially prompted order")
    var expected: String=JSON.stringify(trusted.world.view())
    var restored=Session.new(95,SAVE)
    check(restored.load_existing().get("code")=="RESTORED","restore social order")
    check(JSON.stringify(restored.world.view())==expected,"saved social order did not replay")
    check(restored.world.social_view()["familiarity"]["reda"]["amina"]=="trusted","NPC trust lost on disk")
    check(restored.advance(20,"c5:expire").get("ok",false),"expire social demand")
    check(restored.world.order(OFFER)["status"]=="abandoned","social order did not expire")
    if FileAccess.file_exists(SAVE):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
