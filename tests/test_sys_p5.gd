extends SceneTree
## SYS P5 production acceptance: integer ledger, order settlement, rental and objects.
const Kernel = preload("res://scripts/core/world_kernel.gd")
var failures: Array[String] = []

func _initialize() -> void:
    _balanced_ledger()
    _order_quote_and_settlement()
    _roof_home_and_access()
    _rental_and_deterministic_dues()
    _save_replay_and_tampering()
    if failures.is_empty():
        print("SYS P5: PASS (5 groups: ledger, order settlement, housing, recurring rent, replay)")
        quit(0)
        return
    for message in failures:
        push_error(message)
    print("SYS P5: FAIL (%d assertions)" % failures.size())
    quit(1)

func check(value: bool, note: String) -> void:
    if not value:
        failures.append(note)

func send(k, id: String, kind: String, payload: Dictionary = {}, actor: String = "player") -> Dictionary:
    return k.dispatch({"id": id, "actor_id": actor, "kind": kind, "payload": payload})

func fund(k, id: String, amount: int) -> Dictionary:
    return send(k, "fund:" + id, "economy.fund", {"transaction_id": id,
        "amount_minor": amount, "source_id": "test:funding:" + id}, "system:treasury")

func _balanced_ledger() -> void:
    var k = Kernel.new(123)
    check(k.balance_minor() == 0, "invented starting cash")
    check(send(k,"fake","economy.fund",{"transaction_id":"f", "amount_minor":100,"source_id":"x"})["code"] == "UNAUTHORIZED", "player minted money")
    check(fund(k,"initial",1000)["ok"], "funded")
    check(k.balance_minor() == 1000, "wrong initial funds")
    check(send(k,"pay","economy.pay",{"transaction_id":"purchase","recipient_id":"world:vendors",
        "amount_minor":250,"cause_id":"fixture:equipment"})["ok"], "payment")
    check(k.balance_minor() == 750, "payment debit")
    var retry: Dictionary = send(k,"pay","economy.pay",{"transaction_id":"purchase","recipient_id":"world:vendors",
        "amount_minor":250,"cause_id":"fixture:equipment"})
    check(retry["ok"], "same command receipt")
    check(k.balance_minor() == 750, "duplicate payment")
    check(send(k,"differentid","economy.pay",{"transaction_id":"purchase","recipient_id":"world:vendors",
        "amount_minor":250,"cause_id":"fixture:equipment"})["code"] == "TRANSACTION_EXISTS", "same tx replay via different command id")
    check(send(k,"over","economy.pay",{"transaction_id":"bad","recipient_id":"world:vendors",
        "amount_minor":751,"cause_id":"test"})["code"] == "INSUFFICIENT_FUNDS", "overdraft")
    check(send(k,"badaccount","economy.pay",{"transaction_id":"bad","recipient_id":"player",
        "amount_minor":4,"cause_id":"test"})["code"] == "UNAUTHORIZED", "self pay")
    check(send(k,"refundbad","economy.refund",{"transaction_id":"refund", "original_transaction_id":"purchase"})["code"] == "UNAUTHORIZED", "player initiated refund")
    check(send(k,"refund","economy.refund",{"transaction_id":"refund","original_transaction_id":"purchase"},"system:treasury")["ok"], "refund")
    check(k.balance_minor() == 1000, "refund math")
    check(send(k,"refund2","economy.refund",{"transaction_id":"refund2","original_transaction_id":"purchase"},"system:treasury")["code"] == "ALREADY_REFUNDED", "repeat refund")
    var money: Dictionary = k.economy_view()
    for entry in money["journal"]:
        check(entry["entries"].size() == 2 and int(entry["entries"][0]["delta_minor"]) + int(entry["entries"][1]["delta_minor"]) == 0, "unbalanced journal")
    var total: int = 0
    for account in money["accounts"]:
        total += int(money["accounts"][account])
    check(total == 0, "money created outside paired accounts")
    check(money["journal"].size() == 3, "transaction audit count")
    money["accounts"]["player"] = 90000
    check(k.balance_minor() == 1000, "mutable ledger projection")

func _service_setup(k) -> void:
    check(send(k,"leaf","ingredient.define",{"ingredient_id":"leaf","unit":"g"})["ok"], "ingredient")
    check(send(k,"stock","stock.add",{"ingredient_id":"leaf","quantity":10})["ok"], "stock")
    check(send(k,"heat","station.register",{"station_id":"fire","station_type":"heat"})["ok"], "station")
    check(send(k,"recipe","recipe.define",{"recipe_id":"tea","steps":[{"station_type":"heat","inputs":{"leaf":1},"work_minutes":1}],"shelf_minutes":0})["ok"], "recipe")
    check(send(k,"venue","service.configure",{"venue_id":"kiosk","location_id":"kiosk","counter_slots":2,"takeaway_slots":1,"table_ids":[]})["ok"], "venue")
    check(send(k,"npc","npc.register",{"npc_id":"samir","location_id":"kiosk"})["ok"], "NPC")
    check(send(k,"here","social.player.place",{"location_id":"kiosk"})["ok"], "at venue")

func _order_quote_and_settlement() -> void:
    var k = Kernel.new()
    _service_setup(k)
    check(send(k,"price","economy.recipe.price.set",{"recipe_id":"tea","amount_minor":175},"system:pricing")["ok"], "price")
    check(send(k,"offer","order.offer",{"order_id":"o1","venue_id":"kiosk","npc_id":"samir","recipe_id":"tea","route":"counter","deadline_minute":40},"samir")["ok"], "NPC offer")
    check(send(k,"accept","order.accept",{"order_id":"o1","seat_id":""})["ok"], "order accept")
    check(send(k,"start","cook.start",{"job_id":"batch","recipe_id":"tea","deadline_minute":30})["ok"], "cook start")
    check(send(k,"begin","cook.step.begin",{"job_id":"batch","station_id":"fire"})["ok"], "cook begin")
    check(k.advance_time(1,"minute")["ok"], "clock")
    check(send(k,"finish","cook.step.finish",{"job_id":"batch"})["ok"], "cook finish")
    check(send(k,"deliver","order.deliver",{"order_id":"o1","item_id":"item:batch"})["ok"], "deliver")
    var claim_id: String = "payment:order:o1"
    check(k.order("o1")["payment_status"] == "awaiting_ledger", "settled before ledger")
    check(send(k,"unquoted","economy.order.settle",{"claim_id":claim_id,"transaction_id":"tx:sale"},"system:service")["code"] == "UNQUOTED_CLAIM", "unquoted payment")
    check(send(k,"quote","economy.order.quote",{"claim_id":claim_id},"system:pricing")["ok"], "quote")
    check(k.economy_view()["quotes"][claim_id]["amount_minor"] == 175, "incorrect quoted price")
    check(send(k,"changeprice","economy.recipe.price.set",{"recipe_id":"tea","amount_minor":210},"system:pricing")["ok"], "change future price")
    var settled: Dictionary = send(k,"settle","economy.order.settle",{"claim_id":claim_id,"transaction_id":"tx:sale"},"system:service")
    check(settled["ok"], "settle")
    check(k.balance_minor() == 175, "repriced past delivered order")
    check(k.order("o1")["payment_status"] == "settled", "P4 payment not linked")
    check(k.orders_view()["payment_claims"][claim_id]["amount"] == 175, "claim missing actual paid amount")
    check(send(k,"settle","economy.order.settle",{"claim_id":claim_id,"transaction_id":"tx:sale"},"system:service") == settled, "retry")
    check(send(k,"settle_again","economy.order.settle",{"claim_id":claim_id,"transaction_id":"tx:sale2"},"system:service")["code"] == "CLAIM_ALREADY_SETTLED", "double credit")
    check(k.balance_minor() == 175, "double payment")
    check(k.cooking_view()["items"]["item:batch"]["status"] == "used", "paid food reappeared")

func _house_setup(k) -> void:
    check(send(k,"roof","housing.unit.register",{"unit_id":"roof_room","location_id":"roof","kind":"roof",
        "area_sqm":0,"rent_minor":0,"period_minutes":0},"system:housing")["ok"], "roof unit")
    check(send(k,"apt","housing.unit.register",{"unit_id":"south_apartment","location_id":"south",
        "kind":"apartment","area_sqm":60,"rent_minor":300,"period_minutes":10},"system:housing")["ok"], "south apartment")
    check(send(k,"bed","home.type.define",{"type_id":"bed","price_minor":120,"actions":["sleep","sit"]},"system:catalog")["ok"], "bed type")
    check(send(k,"cupboard","home.type.define",{"type_id":"cupboard","price_minor":0,"actions":["open"]},"system:catalog")["ok"], "cupboard type")

func _roof_home_and_access() -> void:
    var k = Kernel.new()
    _house_setup(k)
    check(not k.can_access_unit("roof_room") and not k.can_access_unit("south_apartment"), "rights invented")
    check(send(k,"roofrights","housing.roof.grant",{"unit_id":"roof_room"},"system:bootstrap")["ok"], "roof entitlement")
    check(k.can_access_unit("roof_room") and not k.can_access_unit("south_apartment"), "roof right leaked apartment")
    check(send(k,"roof_repeat","housing.roof.grant",{"unit_id":"roof_room"},"system:bootstrap")["code"] == "RIGHT_EXISTS", "duplicate right")
    check(send(k,"freebie","home.object.grant",{"object_id":"starter_cupboard","type_id":"cupboard"},"system:bootstrap")["ok"], "starter prop")
    check(send(k,"absent_place","home.object.place",{"object_id":"starter_cupboard","unit_id":"roof_room","slot_id":"wall"})["code"] == "PLAYER_ABSENT", "teleport furniture while absent")
    check(send(k,"arrive","social.player.place",{"location_id":"roof"})["ok"], "arrive roof")
    check(send(k,"place","home.object.place",{"object_id":"starter_cupboard","unit_id":"roof_room","slot_id":"wall"})["ok"], "place")
    check(send(k,"again","home.object.place",{"object_id":"starter_cupboard","unit_id":"roof_room","slot_id":"other"})["code"] == "OBJECT_NOT_STORED", "duplicate furniture")
    check(send(k,"interact","home.object.interact",{"object_id":"starter_cupboard","action_id":"open"})["ok"], "use furniture")
    check(k.housing_view()["objects"]["starter_cupboard"]["use_count"] == 1, "interaction audit")
    check(send(k,"wrong","home.object.interact",{"object_id":"starter_cupboard","action_id":"drink"})["code"] == "INVALID_ACTION", "unknown furniture action")
    check(send(k,"store","home.object.store",{"object_id":"starter_cupboard"})["ok"], "store")
    check(send(k,"store2","home.object.store",{"object_id":"starter_cupboard"})["code"] == "OBJECT_ALREADY_STORED", "duplicate store")
    check(send(k,"no_money","home.object.acquire",{"object_id":"bed1","type_id":"bed","transaction_id":"tx:bed"})["code"] == "INSUFFICIENT_FUNDS", "free paid prop")
    check(fund(k,"furniture_cash",120)["ok"], "furniture cash")
    check(send(k,"purchase","home.object.acquire",{"object_id":"bed1","type_id":"bed","transaction_id":"tx:bed"})["ok"], "buy furniture")
    check(k.balance_minor() == 0, "furniture uncharged")
    check(send(k,"refund_bed","economy.refund",{"transaction_id":"tx:bed:refund",
        "original_transaction_id":"tx:bed"},"system:treasury")["code"] == "DOMAIN_REFUND_REQUIRED", "free furniture via standalone refund")
    check(send(k,"place_bed","home.object.place",{"object_id":"bed1","unit_id":"roof_room","slot_id":"wall"})["ok"], "place bed into freed slot")
    check(send(k,"place_other","home.object.place",{"object_id":"starter_cupboard","unit_id":"roof_room","slot_id":"wall"})["code"] == "SLOT_OCCUPIED", "slot collision")
    check(send(k,"leave","social.player.place",{"location_id":"market"})["ok"], "leave roof")
    check(send(k,"remote","home.object.interact",{"object_id":"bed1","action_id":"sleep"})["code"] == "ACCESS_DENIED", "remote use")

func _rental_and_deterministic_dues() -> void:
    var a = Kernel.new(8)
    _house_setup(a)
    check(send(a,"start_no_cash","housing.lease.start",{"lease_id":"lease1","unit_id":"south_apartment",
        "transaction_id":"tx:first"})["code"] == "INSUFFICIENT_FUNDS", "rent without funds")
    check(fund(a,"rent_cash",1000)["ok"], "rent funds")
    check(send(a,"start","housing.lease.start",{"lease_id":"lease1","unit_id":"south_apartment",
        "transaction_id":"tx:first"})["ok"], "lease start")
    check(a.balance_minor() == 700, "first rent debit")
    check(send(a,"refund_lease","economy.refund",{"transaction_id":"tx:lease:refund",
        "original_transaction_id":"tx:first"},"system:treasury")["code"] == "DOMAIN_REFUND_REQUIRED", "money-only refund kept rental entitlement")
    check(a.can_access_unit("south_apartment"), "paid-up lease access")
    check(send(a,"start2","housing.lease.start",{"lease_id":"lease2","unit_id":"south_apartment",
        "transaction_id":"tx:another"})["code"] == "UNIT_OCCUPIED", "double lease")
    var saved: Dictionary = a.view()
    var large = Kernel.new()
    var small = Kernel.new()
    check(large.restore_snapshot(saved) and small.restore_snapshot(saved), "duplicate before rent")
    check(large.advance_time(30,"large")["ok"], "large time skip")
    for i in range(3):
        check(small.advance_time(10,"small:%d"%i)["ok"], "split time")
    check(large.housing_view() == small.housing_view(), "rent differs across step sizes")
    check(large.housing_view()["leases"]["lease1"]["dues_owed"] == 3, "missed recurring periods")
    check(not large.can_access_unit("south_apartment"), "unpaid lease access")
    check(large.can_access_unit("roof_room") == false, "ungranted roof unlocked")
    check(send(large,"pay_1","housing.rent.pay",{"lease_id":"lease1","transaction_id":"tx:due:1"})["ok"], "pay oldest debt")
    check(large.balance_minor() == 400 and not large.can_access_unit("south_apartment"), "one paid clears all arrears")
    check(send(large,"pay_2","housing.rent.pay",{"lease_id":"lease1","transaction_id":"tx:due:2"})["ok"], "pay second")
    check(send(large,"pay_3","housing.rent.pay",{"lease_id":"lease1","transaction_id":"tx:due:3"})["code"] == "INSUFFICIENT_FUNDS", "arrears overdraft")
    check(fund(large,"rent_topup",300)["ok"], "topup")
    check(send(large,"pay_3_again","housing.rent.pay",{"lease_id":"lease1","transaction_id":"tx:due:3"})["ok"], "settle arrears")
    check(large.can_access_unit("south_apartment"), "access not restored after cleared arrears")
    check(send(large,"end","housing.lease.end",{"lease_id":"lease1"})["ok"], "lease end")
    check(not large.can_access_unit("south_apartment"), "ended lease still accessible")
    check(large.advance_time(40,"after_end")["ok"], "advance after termination")
    check(large.housing_view()["leases"]["lease1"]["dues_owed"] == 0, "ended lease accrued new rent")
    check(send(large,"end2","housing.lease.end",{"lease_id":"lease1"})["code"] == "LEASE_NOT_ACTIVE", "double termination")

func _save_replay_and_tampering() -> void:
    var k = Kernel.new(42)
    _house_setup(k)
    fund(k,"cash",2000)
    send(k,"roofright","housing.roof.grant",{"unit_id":"roof_room"},"system:bootstrap")
    send(k,"lease","housing.lease.start",{"lease_id":"lease1","unit_id":"south_apartment","transaction_id":"tx:lease"})
    send(k,"here","social.player.place",{"location_id":"south"})
    send(k,"buy","home.object.acquire",{"object_id":"bed1","type_id":"bed","transaction_id":"tx:bed"})
    send(k,"place","home.object.place",{"object_id":"bed1","unit_id":"south_apartment","slot_id":"corner"})
    k.advance_time(10,"due")
    var path: String = "user://nk-sys-p5.json"
    check(k.save_to_file(path), "disk save")
    var loaded = Kernel.new()
    check(loaded.load_from_file(path), "disk load")
    check(JSON.stringify(loaded.view()) == JSON.stringify(k.view()), "disk state diff")
    check(not loaded.can_access_unit("south_apartment"), "rental dues lost on disk")
    check(send(loaded,"pay","housing.rent.pay",{"lease_id":"lease1","transaction_id":"tx:rent"})["ok"], "pay after reload")
    check(loaded.can_access_unit("south_apartment"), "access still denied")
    check(send(loaded,"use","home.object.interact",{"object_id":"bed1","action_id":"sleep"})["ok"], "interact after reload")
    var repeat = Kernel.new()
    check(repeat.restore_snapshot(loaded.view()), "replay updated state")
    check(JSON.stringify(repeat.view()) == JSON.stringify(loaded.view()), "replay byte equality")
    var original: String = JSON.stringify(k.view())
    var corrupt: Dictionary = k.view()
    corrupt["economy"]["accounts"]["player"] += 1
    check(not k.restore_snapshot(corrupt), "forged cash accepted")
    corrupt = k.view()
    corrupt["economy"]["journal"][0]["amount_minor"] += 1
    check(not k.restore_snapshot(corrupt), "forged ledger entry accepted")
    corrupt = k.view()
    corrupt["housing"]["leases"]["lease1"]["dues_owed"] = 0
    check(not k.restore_snapshot(corrupt), "forged lease accepted")
    corrupt = k.view()
    corrupt["housing"]["objects"]["bed1"]["slot_id"] = "phantom"
    check(not k.restore_snapshot(corrupt), "forged furniture accepted")
    corrupt = k.view()
    corrupt["events"][corrupt["events"].size()-1]["payload"]["effect"]["housing_outcomes"] = []
    check(not k.restore_snapshot(corrupt), "forged rent expiry accepted")
    corrupt = k.view()
    corrupt["version"] = 5
    check(not k.restore_snapshot(corrupt), "silently migrated v5 world")
    check(JSON.stringify(k.view()) == original, "corruption changed live world")
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
