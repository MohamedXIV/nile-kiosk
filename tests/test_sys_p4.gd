extends SceneTree
## P4 accepts only real kernel commands, cross-domain NPC, cooking and scheduler state.
const Kernel = preload("res://scripts/core/world_kernel.gd")
var failures: Array[String] = []

func _initialize() -> void:
    _offer_and_queue()
    _seats_and_routes()
    _delivery_and_payment_boundary()
    _time_and_departure()
    _persistence_and_replay()
    if failures.is_empty():
        print("SYS P4: PASS (5 groups: queues, seats, delivery, offscreen expiry, persistence)")
        quit(0)
        return
    for message in failures:
        push_error(message)
    print("SYS P4: FAIL (%d assertions)" % failures.size())
    quit(1)

func check(condition: bool, label: String) -> void:
    if not condition:
        failures.append(label)

func send(k, id: String, kind: String, p: Dictionary = {}, actor: String = "system:setup") -> Dictionary:
    return k.dispatch({"id": id, "actor_id": actor, "kind": kind, "payload": p})

func offer(k, id: String, npc: String, route: String = "counter", deadline: int = 30, recipe: String = "tea") -> Dictionary:
    return send(k, "offer:" + id, "order.offer", {"order_id": id, "npc_id": npc,
        "venue_id": "k", "recipe_id": recipe, "route": route, "deadline_minute": deadline}, npc)

func accept(k, id: String, seat: String = "") -> Dictionary:
    return send(k, "accept:" + id + ":" + seat, "order.accept", {"order_id": id, "seat_id": seat}, "player")

func setup(k, customer_count: int = 3, player_here: bool = true) -> void:
    check(send(k, "leaf", "ingredient.define", {"ingredient_id": "leaf", "unit": "g"})["ok"], "define ingredient")
    check(send(k, "supply", "stock.add", {"ingredient_id": "leaf", "quantity": 20})["ok"], "supply")
    check(send(k, "station", "station.register", {"station_id": "hotplate", "station_type": "hot"})["ok"], "station")
    check(send(k, "recipe:tea", "recipe.define", {"recipe_id": "tea",
        "steps": [{"station_type": "hot", "inputs": {"leaf": 1}, "work_minutes": 2}],
        "shelf_minutes": 5})["ok"], "recipe")
    check(send(k, "recipe:soup", "recipe.define", {"recipe_id": "soup",
        "steps": [{"station_type": "hot", "inputs": {"leaf": 2}, "work_minutes": 2}],
        "shelf_minutes": 0})["ok"], "other recipe")
    check(send(k, "venue", "service.configure", {"venue_id": "k", "location_id": "kiosk",
        "counter_slots": 1, "takeaway_slots": 2, "table_ids": ["t1", "t2"]})["ok"], "venue")
    for i in range(customer_count):
        check(send(k, "npc:%d" % i, "npc.register",
            {"npc_id": "n%d" % i, "location_id": "kiosk"})["ok"], "NPC register")
    if player_here:
        check(send(k, "player:here", "social.player.place", {"location_id": "kiosk"})["ok"], "player presence")

func cook(k, id: String) -> String:
    check(send(k, "start:" + id, "cook.start",
        {"job_id": "cook:" + id, "recipe_id": "tea", "deadline_minute": 80})["ok"], "cook start " + id)
    check(send(k, "begin:" + id, "cook.step.begin",
        {"job_id": "cook:" + id, "station_id": "hotplate"})["ok"], "cook begin " + id)
    check(k.advance_time(2, "cook:advance:" + id)["ok"], "cook time " + id)
    check(send(k, "finish:" + id, "cook.step.finish", {"job_id": "cook:" + id})["ok"], "cook finish " + id)
    return "item:cook:" + id

func _offer_and_queue() -> void:
    var k = Kernel.new(9)
    setup(k)
    check(offer(k,"o1","n0")["ok"], "first counter offer")
    var initial: Dictionary = k.order("o1")
    check(initial["status"] == "offered" and initial["queue_position_at_offer"] == 1, "offer/queue state")
    check(offer(k,"o2","n1")["code"] == "QUEUE_FULL", "counter capacity")
    check(offer(k,"o3","n0","takeaway")["code"] == "CUSTOMER_HAS_ORDER", "one active order per customer")
    check(send(k,"forged","order.offer",{"order_id":"false","venue_id":"k","npc_id":"n1",
        "recipe_id":"tea","route":"counter","deadline_minute":30},"n0")["code"] == "ACTOR_NOT_CUSTOMER", "NPC spoof")
    check(accept(k,"o1")["ok"], "counter accept")
    check(k.order("o1")["status"] == "accepted", "accepted projection")
    check(offer(k,"o2","n1")["code"] == "QUEUE_FULL", "accepted queue still occupied")
    check(send(k,"cancel","order.cancel",{"order_id":"o1","reason":"client_changed_mind"},"n0")["ok"], "NPC cancel")
    check(k.order("o1")["status"] == "cancelled", "cancel transition")
    check(offer(k,"o2","n1")["ok"], "released counter slot")
    check(send(k,"double","order.cancel",{"order_id":"o1","reason":"again"},"n0")["code"] == "ORDER_FINAL", "double cancel")
    var copy: Dictionary = k.orders_view()
    copy["orders"]["o2"]["status"] = "forged"
    check(k.order("o2")["status"] == "offered", "projection mutability")
    check(send(k,"clash","service.configure",{"venue_id":"k","location_id":"other",
        "counter_slots":9,"takeaway_slots":9,"table_ids":[]})["code"] == "VENUE_EXISTS", "venue immutable")
    check(send(k,"unknown_recipe","order.offer",{"order_id":"x","venue_id":"k","npc_id":"n2",
        "recipe_id":"unknown","route":"table","deadline_minute":50},"n2")["code"] == "UNKNOWN_RECIPE", "unknown recipe")

func _seats_and_routes() -> void:
    var k = Kernel.new(10)
    setup(k)
    check(offer(k,"tab1","n0","table")["ok"], "table offer 1")
    check(offer(k,"tab2","n1","table")["ok"], "table offer 2")
    check(offer(k,"tab3","n2","table")["code"] == "QUEUE_FULL", "table capacity")
    check(accept(k,"tab1","t1")["ok"], "seat t1")
    check(accept(k,"tab2","t1")["code"] == "SEAT_OCCUPIED", "same seat double occupation")
    check(accept(k,"tab2","t2")["ok"], "seat t2")
    check(k.order("tab1")["seat_id"] == "t1" and k.order("tab2")["seat_id"] == "t2", "seating projection")
    check(send(k,"leave","order.abandon",{"order_id":"tab1","reason":"impatient"},"n0")["ok"], "abandon")
    check(k.order("tab1")["status"] == "abandoned", "abandoned state")
    check(offer(k,"tab3","n2","table")["ok"], "table slot freed")
    check(accept(k,"tab3","t1")["ok"], "seat reused")
    check(send(k,"wrong_actor","order.cancel",{"order_id":"tab2","reason":"other"},"n0")["code"] == "UNAUTHORIZED", "unrelated customer cancellation")
    check(accept(k,"tab2","t2")["code"] == "INVALID_ORDER_STAGE", "duplicate accept")
    check(send(k,"badseat","order.accept",{"order_id":"tab3","seat_id":"t7"},"player")["code"] == "INVALID_ORDER_STAGE", "accepted not changeable")
    check(send(k,"kick","order.cancel",{"order_id":"tab3","reason":"out_of_stock"},"player")["ok"], "player cancellation")

func _delivery_and_payment_boundary() -> void:
    var k = Kernel.new(11)
    setup(k)
    check(offer(k,"one","n0")["ok"] and accept(k,"one")["ok"], "ready order")
    var wrong: String = cook(k,"wrong")
    # Start a new order with a different recipe; both must be valid item identities.
    check(offer(k,"other","n1","takeaway",40,"soup")["ok"], "soup order")
    check(accept(k,"other")["ok"], "takeaway acceptance")
    check(send(k,"bad_recipe","order.deliver",{"order_id":"other","item_id":wrong},"player")["code"] == "WRONG_RECIPE", "wrong recipe accepted")
    check(send(k,"unauthorized","order.deliver",{"order_id":"one","item_id":wrong},"n0")["code"] == "ACTOR_NOT_PLAYER", "NPC delivered")
    var before: Dictionary = k.cooking_view()["items"][wrong]
    check(before["status"] == "ready", "failed delivery consumed item")
    var delivered: Dictionary = send(k,"deliver1","order.deliver",{"order_id":"one","item_id":wrong},"player")
    check(delivered["ok"], "delivery")
    check(send(k,"deliver1","order.deliver",{"order_id":"one","item_id":wrong},"player") == delivered, "idempotent delivery retry")
    check(k.order("one")["status"] == "delivered", "order not delivered")
    check(k.prepared_item(wrong)["status"] == "used", "cooking item not used atomically")
    check(k.prepared_item(wrong)["purpose_id"] == "one", "item missing order provenance")
    check(k.orders_view()["payment_claims"].size() == 1, "payment claim missing or doubled")
    check(k.order("one")["payment_status"] == "awaiting_ledger", "invented payment")
    check(k.orders_view()["payment_claims"]["payment:order:one"]["amount"] == null, "invented money")
    check(send(k,"dup_delivery","order.deliver",{"order_id":"other","item_id":wrong},"player")["code"] == "ITEM_NOT_READY", "double delivery crossed orders")
    check(send(k,"redeliver","order.deliver",{"order_id":"one","item_id":wrong},"player")["code"] == "INVALID_ORDER_STAGE", "final order fulfilled twice")
    check(send(k,"wrong_purpose","cook.item.use",{"item_id":wrong,"purpose_id":"other"})["code"] == "ITEM_NOT_READY", "P3 can re-use claimed item")
    check(send(k,"no_payment","order.deliver",{"order_id":"missing","item_id":wrong},"player")["code"] == "UNKNOWN_ORDER", "unknown order delivered")

func _time_and_departure() -> void:
    var k = Kernel.new(12)
    setup(k,3,false)
    check(offer(k,"waiting","n0","counter",6)["ok"], "NPC offer without player")
    check(accept(k,"waiting")["code"] == "PLAYER_ABSENT", "player absent accepted")
    check(k.advance_time(6,"deadline")["ok"], "clock expiry")
    check(k.order("waiting")["status"] == "abandoned", "offscreen order did not abandon")
    check(k.order("waiting")["closed_minute"] == 6, "deadline time")
    check(send(k,"playerlate","social.player.place",{"location_id":"kiosk"})["ok"], "late player")
    check(accept(k,"waiting")["code"] == "INVALID_ORDER_STAGE", "stale order accepted")
    check(offer(k,"leave","n1","takeaway",20)["ok"], "departure offer")
    check(send(k,"move","npc.move",{"npc_id":"n1","location_id":"home"})["ok"], "NPC left kiosk")
    check(k.order("leave")["status"] == "abandoned", "manual exit retained order")
    check(send(k,"frozen","schedule.create",{"job_id":"x","due_minute":100,"priority":1,
        "topic":"order.deadline","data":{},"every_minutes":0})["code"] == "INVALID_PAYLOAD", "forged order timer")
    check(send(k,"foreign","schedule.reschedule",{"job_id":"order:deadline:waiting",
        "due_minute":50,"priority":1})["code"] == "JOB_NOT_PENDING", "rescheduled closed order timer")
    var route = Kernel.new(33)
    setup(route,1,false)
    check(send(route,"go_home","npc.move",{"npc_id":"n0","location_id":"home"})["ok"], "set NPC home")
    check(send(route,"routine","npc.routine.create",{"routine_id":"visit","npc_id":"n0",
        "location_id":"kiosk","start_minute":1,"end_minute":4,"period_minutes":0})["ok"], "scheduled visit")
    check(route.advance_time(1,"arrival")["ok"], "NPC arrival")
    check(offer(route,"visitorder","n0","counter",8)["ok"], "customer intent during visit")
    var serialized: Dictionary = route.view()
    var large = Kernel.new()
    var small = Kernel.new()
    check(large.restore_snapshot(serialized) and small.restore_snapshot(serialized), "restore before departure")
    check(large.advance_time(8,"big")["ok"], "big time leap")
    for i in range(8):
        check(small.advance_time(1,"minute:%d"%i)["ok"], "split time leap")
    check(large.order("visitorder")["status"] == "abandoned", "NPC departure did not abandon")
    check(large.order("visitorder")["closed_minute"] == 4, "NPC departure processed after deadline")
    check(large.orders_view() == small.orders_view(), "chunking changed NPC order state")
    var big_outcomes: Array = []
    var small_outcomes: Array = []
    for e in large.event_history_after(0):
        if e["kind"] == "time.advanced":
            for value in e["payload"]["effect"]["order_outcomes"]:
                big_outcomes.append([value["order_id"],value["outcome"],value["at_minute"]])
    for e in small.event_history_after(0):
        if e["kind"] == "time.advanced":
            for value in e["payload"]["effect"]["order_outcomes"]:
                small_outcomes.append([value["order_id"],value["outcome"],value["at_minute"]])
    check(big_outcomes == small_outcomes, "chunked departure outcomes diverged")

func _persistence_and_replay() -> void:
    var k = Kernel.new(55)
    setup(k)
    offer(k,"save","n0")
    accept(k,"save")
    check(send(k,"start","cook.start",{"job_id":"mid","recipe_id":"tea","deadline_minute":25})["ok"], "mid-order prep")
    check(send(k,"begin","cook.step.begin",{"job_id":"mid","station_id":"hotplate"})["ok"], "mid-order step")
    k.advance_time(1,"midadvance")
    var file_path: String = "user://nk-sys-p4.json"
    check(k.save_to_file(file_path), "disk save mid-order")
    var loaded = Kernel.new(1)
    check(loaded.load_from_file(file_path), "disk restore mid-order")
    check(JSON.stringify(loaded.view()) == JSON.stringify(k.view()), "disk roundtrip")
    loaded.advance_time(1,"resume:minute")
    check(send(loaded,"finish","cook.step.finish",{"job_id":"mid"})["ok"], "resume cooking")
    var r: Dictionary = send(loaded,"deliver","order.deliver",{"order_id":"save","item_id":"item:mid"},"player")
    check(r["ok"], "deliver after restore")
    check(loaded.order("save")["status"] == "delivered" and loaded.prepared_item("item:mid")["status"] == "used", "restore lost atomicity")
    var repeat = Kernel.new(55)
    check(repeat.restore_snapshot(loaded.view()), "replay mixed delivered snapshot")
    check(JSON.stringify(repeat.view()) == JSON.stringify(loaded.view()), "mixed replay bytes")
    var expected: String = JSON.stringify(k.view())
    var forged: Dictionary = k.view()
    forged["service"]["orders"]["save"]["status"] = "delivered"
    check(not k.restore_snapshot(forged), "forged order status accepted")
    forged = k.view()
    forged["service"]["venues"]["k"]["counter_slots"] = 99
    check(not k.restore_snapshot(forged), "forged venue accepted")
    forged = k.view()
    forged["events"][forged["events"].size() - 1]["payload"]["effect"]["order_outcomes"] = [{"ghost":true}]
    check(not k.restore_snapshot(forged), "forged order outcome accepted")
    forged = k.view()
    forged["version"] = 4
    check(not k.restore_snapshot(forged), "old v4 snapshot silently accepted")
    check(JSON.stringify(k.view()) == expected, "corrupt restore damaged live world")
    if FileAccess.file_exists(file_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
