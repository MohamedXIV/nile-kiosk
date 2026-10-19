extends SceneTree
## Game-First P4: actual authored Salma demand -> accepted order -> paid
## P3 turn -> one delivery -> real P5 quote/settlement -> hard disk replay.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const SAVE = "user://nk-game-first-sandwich-service.json"
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
    if not value: failures.append(message)

func _initialize() -> void:
    _run()
    if failures.is_empty():
        print("GAME FIRST SANDWICH SERVICE: PASS (real demand, hand action, delivery, ledger, replay)")
        quit(0)
    else:
        for failure in failures: push_error(failure)
        print("GAME FIRST SANDWICH SERVICE: FAIL (%d)" % failures.size())
        quit(1)

func wait_until(g: RefCounted, target: int) -> void:
    while int(g.status()["minute"]) < target:
        check(g.wait_minutes(mini(5,target-int(g.status()["minute"]))).get("ok",false),"advance real P1 clock")

func _run() -> void:
    if FileAccess.file_exists(SAVE):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var game: RefCounted = Game.new()
    check(game.start(SAVE).get("ok",false),"starter world with real demand")
    if game.session == null: return
    check(game.session.world.economy_view()["prices"].get("liver_sandwich")==550,
        "P5 proposed price installed, no automatic reward")
    check(game.session.world.view()["jobs"].has("service:demand:offer:evening:salma:liver-sandwich"),
        "actual recurring P4 demand scheduled")
    check(game.travel_near().get("ok",false),"roof door")
    for i in range(9): check(game.move_world(18,0).get("ok",false),"landing approach")
    check(game.travel_near().get("ok",false),"street door")
    for i in range(9): check(game.move_world(18,0).get("ok",false),"street approach")
    check(game.travel_near().get("ok",false),"kiosk door")
    for i in range(4): check(game.move_world(18,0).get("ok",false),"counter approach")
    check(game.sandwich_context()["near"],"actual P2 counter location")
    # Keep the shop closed for the preexisting 17:15 tea order. This test
    # isolates the 18:00 *new* sandwich order without fabricating its event.
    wait_until(game,1050)
    check(game.open_kiosk().get("ok",false),"shop opens before authored 18:00 demand")
    check(game.status()["active_order"]=="","old closed-store demand not invented")
    var starting_cash: int = game.status()["money"]
    for i in range(game.sandwich_offers().size()):
        check(game.sandwich_purchase(i).get("ok",false),"paid P5 lot %d" % i)
    check(game.status()["money"]==starting_cash-1560,"all six lots debited")
    wait_until(game,1080)
    var orders: Dictionary = game.session.world.orders_view()["orders"]
    var id: String = "demand:evening:salma:liver-sandwich:1"
    check(orders.has(id),"P4 scheduler emitted authentic Salma demand")
    if not orders.has(id): game.dispose();return
    check(orders[id]["status"]=="offered" and orders[id]["recipe_id"]=="liver_sandwich",
        "correct actual NPC/product from authored demand")
    var accepted: Dictionary = game.service_near()
    check(accepted.get("kind","")=="order.accept","G accepts the real order")
    check(game.service_near().get("code","")=="SANDWICH_HAND_ACTION_REQUIRED",
        "G cannot start recipe automatically or bypass physical turning")
    check(game.status()["money"]==starting_cash-1560,"accepted order creates no free revenue")
    check(game.sandwich_step().get("ok",false),"F7 starts one real preparation")
    check(game.sandwich_step().get("ok",false),"seasoning work starts")
    check(game.wait_minutes(1).get("ok",false),"seasoning time")
    check(game.sandwich_step().get("ok",false),"finish seasoning")
    check(game.sandwich_step().get("ok",false),"pan starts")
    check(game.sandwich_step().get("code","")=="ACTION_TOO_EARLY","no automatic pan flip")
    check(game.wait_minutes(2).get("ok",false),"first face heat")
    check(game.sandwich_step().get("ok",false),"actual turn")
    check(game.wait_minutes(2).get("ok",false),"second face heat")
    check(game.sandwich_step().get("ok",false),"lift from pan")
    check(game.sandwich_step().get("ok",false),"assembly begins")
    check(game.sandwich_step().get("ok",false),"finish authentic item")
    var item_id: String = str(game.sandwich_context()["item_id"])
    check(game.session.world.prepared_quality(item_id).get("grade")=="good",
        "real P3 grade depends on action times")
    var delivered: Dictionary = game.service_near()
    check(delivered.get("kind","")=="order.deliver","G delivers verified item")
    orders=game.session.world.orders_view()["orders"]
    check(orders[id]["item_id"]==item_id and orders[id]["status"]=="delivered",
        "P4 references the exact cooked item")
    check(game.session.world.prepared_item(item_id)["status"]=="used",
        "item can no longer be delivered again")
    check(game.status()["money"]==starting_cash-1560,
        "delivery is NOT payment")
    check(game.customer_reaction().get("grade")=="good" and
        game.customer_reaction().get("npc_id")=="salma",
        "Salma reacts to authenticated grade and actual delivery")
    check(game.save_game().get("ok",false),"save real delivered but unpaid claim")
    var prior: Dictionary = game.session.world.view()
    var restored: RefCounted = Game.new()
    check(restored.start(SAVE).get("code","")=="RESTORED","reopen delivered order")
    check(JSON.stringify(restored.session.world.view())==JSON.stringify(prior),
        "content installer idempotent, no phantom price or demand reinstallation")
    check(restored.service_near().get("kind","")=="economy.order.quote",
        "quote tied to actual delivered P4 item")
    check(restored.status()["money"]==starting_cash-1560,
        "quote alone adds no player cash")
    check(restored.service_near().get("kind","")=="economy.order.settle",
        "real P5 settlement")
    check(restored.status()["money"]==starting_cash-1560+550,
        "550 credited once, after delivery and real settlement")
    check(restored.session.world.orders_view()["orders"][id]["payment_status"]=="settled",
        "P4 payment status settled")
    check(restored.service_near().get("code","")=="NO_ACTIVE_ORDER",
        "settled order cannot be paid again")
    check(restored.session.world.prepared_item(item_id)["status"]=="used",
        "settled order never refunds or remints consumed item")
    check(restored.save_game().get("ok",false),"save after settlement")
    var fork: RefCounted = Game.new()
    check(fork.start(SAVE).get("code","")=="RESTORED","reopen complete customer visit")
    check(fork.status()["money"]==starting_cash-1560+550 and
        fork.session.world.orders_view()["orders"][id]["payment_status"]=="settled",
        "P3/P4/P5 ledger and item ownership survive another disk replay")
    check(fork.session.world.view()["jobs"].has("service:demand:offer:evening:salma:liver-sandwich"),
        "recurring P4 demand remains installed after reload")
    game.dispose()
    restored.dispose()
    fork.dispose()
