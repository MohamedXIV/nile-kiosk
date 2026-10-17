extends SceneTree
## E6/P0 acceptance: separate gameplay catalog, real portals, demand, service and disk replay.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const SAVE = "user://nk-e6-game-entry-acceptance.json"
var failures: Array[String] = []

func _initialize() -> void:
    _run()
    if failures.is_empty():
        print("E6 GAME ENTRY: PASS (canonical opening, traversal, demand, cooking, payment, save/reload)")
        quit(0)
    else:
        for f in failures: push_error(f)
        print("E6 GAME ENTRY: FAIL (%d)" % failures.size())
        quit(1)

func check(value: bool, label: String) -> void:
    if not value: failures.append(label)

func _run() -> void:
    for path in [SAVE, SAVE+".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var g: RefCounted = Game.new()
    var started: Dictionary = g.start(SAVE)
    check(started.get("ok",false) and started.get("code","")=="NEW_WORLD","new session")
    if not started.get("ok",false): return
    check(g.room()=="roof" and g.status()["minute"]==1020,"initial roof at authored opening time")
    check(g.status()["money"]==6000 and g.status()["roof_access"],"world content vs QA economics")
    check(g.status()["npc_mahmoud"]=="street","visitor not pre-teleported")
    check(g.npc_pose("mahmoud").is_empty(),"absent visitor cannot be drawn")
    check(g.ambient_exchange().is_empty(),"no dialogue while on roof or Mahmoud absent")
    check(not g.graph.configure_visit_spots({"schema":1}).get("ok",false),"invalid visits must reject")
    var digest_before: String = g.status()["digest"]
    check(g.move_world(60,0)["code"]=="INVALID_DELTA","no movement teleport")
    check(g.status()["digest"]==digest_before,"invalid move wrote event")
    check(g.move_world(18,0).get("ok",false),"roof move")
    check(g.travel_near().get("ok",false) and g.room()=="landing","roof/landing")
    check(g.travel_near().get("ok",false) and g.room()=="roof","return to roof")
    check(g.travel_near().get("ok",false) and g.room()=="landing","return to landing")
    for i in range(9):
        check(g.move_world(18,0).get("ok",false),"landing walk %d" % i)
    check(g.travel_near().get("ok",false) and g.room()=="street","landing/street")
    for i in range(9):
        check(g.move_world(18,0).get("ok",false),"street walk %d" % i)
    check(g.travel_near().get("ok",false) and g.room()=="kiosk","street/kiosk")
    check(g.service_near()["code"]=="KIOSK_CLOSED","closed store rejects service")
    for i in range(4):
        check(g.move_world(18,0).get("ok",false),"kiosk counter approach %d" % i)
    check(g.open_kiosk().get("ok",false),"player opens kiosk")
    check(g.service_near()["code"]=="NO_ACTIVE_ORDER","no fake offer")
    for i in range(3):
        check(g.wait_minutes().get("ok",false),"real clock waiting")
    check(g.status()["minute"]==1035 and g.status()["npc_mahmoud"]=="kiosk","independent NPC visit")
    check(g.status()["order_status"]=="offered","autonomous customer order")
    var approaching: Dictionary = g.npc_pose("mahmoud")
    check(approaching.get("mode","")=="approaching" and
        approaching.get("position",Vector2.ZERO)==Vector2(200,110),
        "visitor didn't begin from authored standing position on real offer")
    check(g.ambient_exchange().is_empty(),"no incidental exchange before the first authored beat")
    check(g.wait_minutes(4).get("ok",false),"reach first spontaneous NPC aside")
    var before_aside: String = g.status()["digest"]
    var first_aside: Dictionary = g.ambient_exchange()
    check(first_aside.get("npc_id","")=="salma" and first_aside.get("beat",-1)==0 and
        first_aside.get("line","").contains("river"),"Salma did not speak during real joint presence")
    check(g.status()["ambient_line"]==first_aside.get("line","") and g.status()["digest"]==before_aside,
        "ambient projection wrote GameState or failed to reach UI")
    check(g.customer_reaction().is_empty(),"customer cannot react before delivery")
    var first: Dictionary = g.service_near()
    check(first.get("ok",false) and first.get("kind","")=="order.accept","accept real order")
    check(g.service_near().get("kind","")=="cook.start","start recipe")
    check(g.service_near().get("code","")=="HAND_ACTION_REQUIRED","G cannot skip player hand action")
    var stalled: String = g.status()["digest"]
    check(g.tea_action_near("U").get("code","")=="WRONG_GESTURE","cannot pour before heating")
    check(g.status()["digest"]==stalled,"wrong gesture changed canonical world")
    check(g.tea_action_near("H").get("kind","")=="cook.step.begin","player puts kettle on")
    check(g.tea_action_near("H").get("code","")=="STEP_NOT_READY","cannot lift kettle early")
    check(g.save_game().get("ok",false),"save mid-cooking")
    var before_load: Dictionary = g.session.world.view()
    var restored: RefCounted = Game.new()
    check(restored.start(SAVE).get("code","")=="RESTORED","restore existing opening game")
    check(JSON.stringify(restored.session.world.view())==JSON.stringify(before_load),"entire world state preserved")
    check(restored.room()=="kiosk" and restored.position()==g.position(),"canonical world pose retained")
    var job_id: String = "play:c3:prep:" + str(g.status()["active_order"])
    var item_id: String = "item:" + job_id
    # A counterfactual world from the exact same persisted mid-heat snapshot:
    # intentionally late hands produce a different real item-quality outcome.
    var slow: RefCounted = Kernel.new()
    check(slow.restore_snapshot(before_load),"counterfactual replay baseline")
    check(slow.prepared_quality(item_id).is_empty(),"no quality for food not yet prepared")
    check(slow.prepared_quality("item:forged").is_empty(),"forged item quality rejected")
    check(slow.advance_time(9,"e3:slow:heat").get("ok",false),"deliberate slow heating")
    check(slow.dispatch({"id":"e3:slow:lift","actor_id":"player","kind":"cook.step.finish",
        "payload":{"job_id":job_id}}).get("ok",false),"slow lift P3 step")
    check(slow.dispatch({"id":"e3:slow:pour","actor_id":"player","kind":"cook.step.begin",
        "payload":{"job_id":job_id,"station_id":"counter"}}).get("ok",false),"slow pour P3 step")
    check(slow.advance_time(7,"e3:slow:pour:time").get("ok",false),"deliberate slow pour")
    check(slow.dispatch({"id":"e3:slow:finish","actor_id":"player","kind":"cook.step.finish",
        "payload":{"job_id":job_id}}).get("ok",false),"slow tea made a real cup")
    var rough: Dictionary = slow.prepared_quality(item_id)
    check(rough.get("grade","")=="rough" and int(rough.get("score",0)) < 60,
        "late tea did not receive worse world-owned quality")
    check(rough.get("source_event_id","") == slow.prepared_item(item_id).get("event_id",""),
        "quality lacks physical item provenance")
    var slow_again: RefCounted = Kernel.new()
    check(slow_again.restore_snapshot(slow.view()) and slow_again.prepared_quality(item_id)==rough,
        "late cup quality changed across canonical replay")
    check(restored.wait_minutes(2).get("ok",false),"wait for heat")
    var at_counter: Dictionary = restored.npc_pose("mahmoud")
    check(at_counter.get("mode","")=="counter" and at_counter.get("position",Vector2.ZERO)==Vector2(145,85),
        "visitor failed to reach authored counter with canonical time")
    check(restored.graph.nearby_npc(restored.session,restored.position()).get("npc_id","")=="mahmoud",
        "hearing target disagrees with visible counter position")
    check(restored.tea_action_near("H").get("kind","")=="cook.step.finish","player lifts hot kettle")
    check(restored.tea_action_near("U").get("kind","")=="cook.step.begin","player pours tea")
    check(restored.wait_minutes(1).get("ok",false),"wait for serving")
    check(restored.tea_action_near("U").get("kind","")=="cook.step.finish","finish physical pour")
    var balanced: Dictionary = restored.session.world.prepared_quality(item_id)
    check(balanced.get("grade","")=="good" and int(balanced.get("score",0))==100,
        "on-time hand actions didn't produce a good cup")
    check(balanced["score"] > rough["score"],"patient vs delayed tea same quality")
    check(restored.status()["tea_quality"]=="good" and restored.status()["tea_quality_item"]==item_id,
        "real game failed to surface canonical sensory quality")
    # Nonblocking: Salma's short line remains visible while tea is brewed.
    check(restored.ambient_exchange().get("npc_id","")=="salma","cooking should not freeze the nearby speaker")
    check(restored.wait_minutes(5).get("ok",false) and restored.wait_minutes(2).get("ok",false),
        "advance to the second authored speech beat without moving NPCs by hand")
    var second_aside: Dictionary = restored.ambient_exchange()
    check(second_aside.get("npc_id","")=="mahmoud" and second_aside.get("beat",-1)==1 and
        second_aside.get("line","").contains("still"),"Mahmoud did not answer Salma without player interaction")
    check(restored.customer_reaction().is_empty(),"finished but undelivered cup triggered conversation")
    var served: Dictionary = restored.service_near()
    check(served.get("kind","")=="order.deliver","deliver paid item")
    var reply: Dictionary = restored.customer_reaction()
    check(reply.get("npc_id","")=="mahmoud" and reply.get("grade","")=="good" and
        reply.get("line","").contains("cup"),"real delivered tea did not trigger authored good reaction")
    check(reply.get("order_id","")==restored.status()["active_order"] and
        reply.get("source_event_id","")==restored.session.world.order(reply["order_id"])["closure_event_id"],
        "reaction unlinked from real P4 delivery event")
    check(served.get("customer_reaction",{})==reply and restored.status()["customer_reaction"]==reply["line"],
        "customer response not visible to production gameplay")
    check(restored.ambient_exchange().is_empty(),"incidental remark must give way to genuine customer response")
    check(restored.npc_pose("mahmoud").get("mode","")=="returning" and
        restored.npc_pose("mahmoud").get("position",Vector2.ZERO)==Vector2(145,85),
        "visitor jumped to anchor on delivery")
    check(restored.service_near().get("kind","")=="economy.order.quote","quote")
    check(restored.service_near().get("kind","")=="economy.order.settle","settle")
    check(restored.status()["money"]==6200,"no duplicate payment")
    check(restored.save_game().get("ok",false),"save settled state")
    var once: String=restored.status()["digest"]
    var final: RefCounted=Game.new()
    check(final.start(SAVE).get("code","")=="RESTORED","second game boot")
    check(final.status()["digest"]==once and final.status()["money"]==6200,"settled state unchanged after reload")
    check(final.session.world.prepared_quality(item_id)==balanced and final.status()["tea_quality"]=="good",
        "delivered tea lost immutable quality after paid service and disk reload")
    check(final.customer_reaction()==reply,"delivered response lost after canonical P5 settlement and save")
    check(final.ambient_exchange().is_empty(),"settled customer response takes precedence")
    check(final.npc_pose("mahmoud")==restored.npc_pose("mahmoud"),
        "visitor position changed after P5 settlement and world reload")
    check(final.wait_minutes(3).get("ok",false),"advance world while visitor steps away")
    check(final.npc_pose("mahmoud").get("mode","")=="standing" and
        final.npc_pose("mahmoud").get("position",Vector2.ZERO)==Vector2(200,110),
        "visitor did not return to standing spot")
    check(final.status()["money"]==6200,"visual visit changed economy")
    var same: String = final.status()["digest"]
    check(final.service_near()["code"]=="NO_ACTIVE_ORDER","already served customer can no longer order again")
    check(final.status()["digest"]==same,"rejected second service changed delivery/reaction")
    var forged: Dictionary = final.session.world.view()
    for record in forged["events"]:
        if record["kind"] == "cook.step_finished" and record["payload"]["request"]["job_id"] == job_id:
            record["world_minute"] = int(record["world_minute"]) + 1
            break
    check(not final.session.world.restore_snapshot(forged),"changed cooking timing bypassed event replay")
    check(final.status()["digest"]==same,"failed event replay changed live world")
    check(final.service_near()["code"]=="NO_ACTIVE_ORDER","no duplicate order service")
    check(final.status()["digest"]==same,"rejected service mutated settled state")
    for obj in [g,restored,final]: obj.dispose()
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
