extends SceneTree
## Game-First P6: a full, honest two-day player shop loop. Real P1 sleep,
## P2 portals, P3 hand-cooking, P4 returning customer, P5 cash/stock and
## disk replay. No authored/test-only NPC or world-state injections.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const SAVE = "user://nk-game-first-two-day-loop.json"
const PLAN = "demand:evening:salma:liver-sandwich:"
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
    if not value: failures.append(message)

func _initialize() -> void:
    _run()
    if failures.is_empty():
        print("GAME FIRST TWO-DAY LOOP: PASS (2 real orders, sleep, restock, revenue and replay)")
        quit(0)
    else:
        for message in failures: push_error(message)
        print("GAME FIRST TWO-DAY LOOP: FAIL (%d)" % failures.size())
        quit(1)

func require(result: Dictionary, label: String) -> void:
    check(result.get("ok",false), "%s: %s" % [label,result])

func wait_until(game: RefCounted, target: int) -> void:
    while int(game.status()["minute"]) < target:
        require(game.wait_minutes(mini(5,target-int(game.status()["minute"]))),
            "player waits on P1 clock")

func walk(game: RefCounted, steps: int, sign: int) -> void:
    for i in range(steps):
        require(game.move_world(18*sign,0), "P2 collision-aware movement %d" % i)

func go_kiosk(game: RefCounted) -> void:
    check(game.room()=="roof","start at real roof home")
    require(game.travel_near(),"roof to landing")
    walk(game,9,1)
    require(game.travel_near(),"landing to street")
    walk(game,9,1)
    require(game.travel_near(),"street to kiosk")
    walk(game,4,1)
    check(game.room()=="kiosk" and game.sandwich_context()["near"],
        "real player is physically at kitchen counter")

func go_home(game: RefCounted) -> void:
    walk(game,4,-1)
    require(game.travel_near(),"kiosk to street")
    walk(game,8,-1)
    require(game.travel_near(),"street to landing")
    walk(game,9,-1)
    require(game.travel_near(),"landing to roof")
    check(game.room()=="roof","player walked home, no teleport")

func buy_lots(game: RefCounted, day: int) -> void:
    var before_cash: int = game.status()["money"]
    var offers: Array[Dictionary] = game.sandwich_offers()
    check(offers.size()==6 and offers.all(func(o: Dictionary) -> bool: return not o["resolved"]),
        "real fresh daily supplier offers day %d" % day)
    for i in range(offers.size()):
        require(game.sandwich_purchase(i),"paid lot %d on day %d" % [i,day])
    check(game.status()["money"]==before_cash-1560,
        "player paid full 1560 to vendors on day %d" % day)
    check(game.sandwich_purchase(0).get("code","")=="OFFER_RESOLVED",
        "cannot buy a second time same-day after paying")

func prepare(game: RefCounted) -> String:
    require(game.sandwich_step(),"start physical recipe")
    require(game.sandwich_step(),"season")
    require(game.wait_minutes(1),"season for one minute")
    require(game.sandwich_step(),"finish seasoning")
    require(game.sandwich_step(),"heat pan")
    check(game.sandwich_step().get("code","")=="ACTION_TOO_EARLY",
        "real pan cannot flip instantly")
    require(game.wait_minutes(2),"heat first face")
    require(game.sandwich_step(),"player turns pan")
    require(game.wait_minutes(2),"cook other side")
    require(game.sandwich_step(),"lift")
    require(game.sandwich_step(),"assemble bread and lemon")
    require(game.sandwich_step(),"finish item")
    var item: String = str(game.sandwich_context()["item_id"])
    check(game.session.world.prepared_quality(item).get("grade","")=="good",
        "one actual high-quality timed sandwich")
    return item

func serve(game: RefCounted, occurrence: int) -> String:
    var oid: String = PLAN+str(occurrence)
    var snapshot: Dictionary = game.session.world.orders_view()["orders"]
    check(snapshot.has(oid),"P4 did not schedule real Salma order %d" % occurrence)
    if not snapshot.has(oid): return ""
    check(snapshot[oid]["status"]=="offered" and snapshot[oid]["npc_id"]=="salma",
        "missing returning customer offer")
    var accepted: Dictionary = game.service_near()
    require(accepted,"G accepts live order")
    check(accepted.get("kind","")=="order.accept","G did not actually accept order")
    check(game.service_near().get("code","")=="SANDWICH_HAND_ACTION_REQUIRED",
        "G incorrectly bypasses the physical pan technique")
    var item: String = prepare(game)
    var pre_income: int = game.status()["money"]
    var delivered: Dictionary = game.service_near()
    check(delivered.get("kind","")=="order.deliver","customer receives real item")
    check(game.status()["money"]==pre_income,"item delivery is not instant money")
    check(game.session.world.prepared_item(item)["status"]=="used",
        "P3 item must be consumed exactly once in P4 delivery")
    check(game.session.world.orders_view()["orders"][oid]["item_id"]==item,
        "customer order linked to actual item")
    check(game.customer_reaction().get("grade","")=="good",
        "returning customer's line based on true verified quality")
    check(game.service_near().get("kind","")=="economy.order.quote",
        "P5 quote from one authentic delivered order")
    check(game.status()["money"]==pre_income,"quote does not pay")
    check(game.service_near().get("kind","")=="economy.order.settle",
        "P5 settled customer claim")
    check(game.status()["money"]==pre_income+550,
        "player earned only 550 after genuine delivery and payment")
    check(game.service_near().get("code","")=="NO_ACTIVE_ORDER",
        "cannot sell/pay the same order twice")
    return item

func _run() -> void:
    for path in [SAVE,SAVE+".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var game: RefCounted = Game.new()
    require(game.start(SAVE),"bootstrap opening")
    if game.session == null: return
    var initial_cash: int = game.status()["money"]
    go_kiosk(game)
    wait_until(game,1050)
    require(game.open_kiosk(),"open shop on day 1 after Mahmoud tea offer")
    buy_lots(game,1)
    wait_until(game,1080)
    var first_item: String = serve(game,1)
    check(not first_item.is_empty(),"first delivered item id absent")
    check(game.status()["money"]==initial_cash-1560+550,"end of day 1 exact cashflow")
    require(game.close_kiosk(),"close shop before leaving")
    go_home(game)
    var before_sleep: Dictionary = game.status()
    require(game.sleep_at_home(),"real E1 sleep from home with kiosk closed")
    check(game.status()["day"]==2 and game.status()["minute"]==1920,
        "P1 next morning is 8:00 on day 2")
    check(game.status()["sleep_count"]==1 and
        game.status()["rest"]>=before_sleep["rest"],
        "genuine sleep restores rest, not free time travel")
    require(game.save_game(),"save after day1 and actual overnight sleep")
    var at_wake: Dictionary = game.session.world.view()
    var next_day: RefCounted = Game.new()
    check(next_day.start(SAVE).get("code","")=="RESTORED","disk replay at morning wake")
    check(Kernel._matches(next_day.session.world.view(),at_wake),
        "next-day restart mutated authoritative event history")
    go_kiosk(next_day)
    buy_lots(next_day,2)
    check(next_day.status()["money"]==initial_cash-1560+550-1560,
        "second-day stock isn't free or charged twice")
    # Keep store closed for the historical recurring tea. The authored
    # Salma order is a separate daily 18:00 event.
    wait_until(next_day,2490)
    require(next_day.open_kiosk(),"open shop for Salma on day 2")
    wait_until(next_day,2520)
    var second_item: String = serve(next_day,2)
    check(not second_item.is_empty() and first_item != second_item,
        "two days must produce distinct single-use prepared items")
    check(next_day.status()["money"]==initial_cash-2*1560+2*550,
        "real cumulative shop cashflow after two days")
    check(next_day.session.world.cooking_view()["stock"]["liver"]==600,
        "two paid 400g lots minus exactly two used 100g servings")
    check(next_day.session.world.orders_view()["orders"][PLAN+"1"]["payment_status"]=="settled" and
        next_day.session.world.orders_view()["orders"][PLAN+"2"]["payment_status"]=="settled",
        "both repeat customers paid once")
    require(next_day.save_game(),"save two-day finished world")
    var end_state: Dictionary = next_day.session.world.view()
    var reloaded: RefCounted = Game.new()
    check(reloaded.start(SAVE).get("code","")=="RESTORED","reload two-day shop")
    check(Kernel._matches(reloaded.session.world.view(),end_state),
        "two-day shop event replay not byte-identical after disk roundtrip")
    check(reloaded.status()["money"]==initial_cash-2*1560+2*550 and
        reloaded.session.world.prepared_item(second_item)["status"]=="used",
        "paid revenue and consumed dish lost on final replay")
    game.dispose()
    next_day.dispose()
    reloaded.dispose()
