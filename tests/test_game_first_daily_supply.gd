extends SceneTree
## P5 Game-First: world-day public stock resets only via a fresh paid
## transaction; canonical receipt, lot stock, time, save and replay prove it.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Supply = preload("res://scripts/core/supply_contracts.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const SAVE = "user://nk-game-first-daily-supply.json"
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
    if not value: failures.append(message)

func _initialize() -> void:
    _run()
    if failures.is_empty():
        print("GAME FIRST DAILY SUPPLY: PASS (day-bounded paid stock, shared lot, reload)")
        quit(0)
    else:
        for message in failures: push_error(message)
        print("GAME FIRST DAILY SUPPLY: FAIL (%d)" % failures.size())
        quit(1)

func _run() -> void:
    for path in [SAVE,SAVE+".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var g: RefCounted = Game.new()
    check(g.start(SAVE).get("ok",false),"start actual world")
    if g.session == null: return
    check(Supply.receipt_id("private:learned",{"quantity":10},{},2300)=="private:learned",
        "learned/one-time private offers cannot replenish")
    check(g.travel_near().get("ok",false),"roof exit")
    for i in range(9): check(g.move_world(18,0).get("ok",false),"landing walk")
    check(g.travel_near().get("ok",false),"street entry")
    for i in range(9): check(g.move_world(18,0).get("ok",false),"street walk")
    check(g.travel_near().get("ok",false),"kiosk entry")
    for i in range(4): check(g.move_world(18,0).get("ok",false),"counter approach")
    var day0_cash: int = g.status()["money"]
    var original: Array[Dictionary] = g.sandwich_offers()
    check(original.size()==6 and original.all(func(x: Dictionary) -> bool:
        return not x["resolved"]),"six actual untouched first-day public lots")
    for i in range(original.size()):
        check(g.sandwich_purchase(i).get("ok",false),"paid day0 lot %d" % i)
    check(g.status()["money"]==day0_cash-1560,"first day real vendor payment")
    check(g.sandwich_offers().all(func(x: Dictionary) -> bool:
        return x["resolved"]),"same-day 6 offers resolved")
    check(g.sandwich_purchase(0).get("code","")=="OFFER_RESOLVED",
        "cannot buy same-day stock twice")
    var before: Dictionary = g.session.world.view()
    check(g.save_game().get("ok",false),"save resolved first-day lots")
    var restored: RefCounted = Game.new()
    check(restored.start(SAVE).get("code","")=="RESTORED","restore first-day snapshot")
    check(JSON.stringify(before)==JSON.stringify(restored.session.world.view()),
        "restored world had phantom stock or extra commands")
    var minute: int = restored.status()["minute"]
    check(restored.session.advance(1440-minute+5,"daily:next-day:clock").get("ok",false),
        "advance canonical P1 time into world day 2")
    check(restored.status()["minute"]==1445,"actual P1 next calendar day")
    check(restored.sandwich_offers().all(func(x: Dictionary) -> bool:
        return not x["resolved"]),"public market does not reopen on next day")
    var offers: Dictionary = restored.session.world.economy_view()["supply_offers"]
    var alternate: Dictionary = offers["sandwich:liver"].duplicate(true)
    alternate["offer_id"]="sandwich:liver:alternate"
    check(restored.session.command("daily:alternate:register","system:catalog",
        "supply.offer.register",alternate).get("ok",false),
        "second listing on same real finite public lot")
    var fork: RefCounted = Kernel.new()
    check(fork.restore_snapshot(restored.session.world.view()),"replay fork before purchase")
    var receipt: Dictionary = fork.dispatch({"id":"daily:alternate:buy","actor_id":"player",
        "kind":"supply.purchase","payload":{"offer_id":"sandwich:liver:alternate"}})
    check(receipt.get("ok",false),"purchase shared public lot from alternate listing")
    var fail: Dictionary = fork.dispatch({"id":"daily:alternate:double","actor_id":"player",
        "kind":"supply.purchase","payload":{"offer_id":"sandwich:liver"}})
    check(fail.get("code","")=="SUPPLY_OUT_OF_STOCK",
        "same daily finite lot must be shared across different supplier listings")
    check(Kernel.new().restore_snapshot(fork.view()),
        "shared-lot transaction must replay and reject a double-bought lot")
    var cash: int = restored.status()["money"]
    for i in range(6):
        var purchased: Dictionary = restored.sandwich_purchase(i)
        check(purchased.get("ok",false),"daily repeat paid purchase %d: %s" % [i,purchased])
    check(restored.status()["money"]==cash-1560,
        "day2 repeat purchase did not debit another real 1560")
    var p5: Dictionary = restored.session.world.economy_view()
    check(p5["supply_resolutions"].has("sandwich:liver") and
        p5["supply_resolutions"].has("sandwich:liver:day:1"),
        "each world day needs a separately authenticated purchase receipt")
    check(p5["transactions"].has("supply:sandwich:liver") and
        p5["transactions"].has("supply:sandwich:liver:day:1"),
        "second day has a fresh P5 transaction, not a reused ID")
    check(restored.sandwich_purchase(0).get("code","")=="OFFER_RESOLVED",
        "no double purchase on day 2")
    check(restored.session.world.cooking_view()["stock"]["liver"]==800,
        "only two paid public lots grant exactly 800g liver")
    check(restored.save_game().get("ok",false),"disk save after second-day purchase")
    var loaded: RefCounted = Game.new()
    var result: Dictionary = loaded.start(SAVE)
    check(result.get("code","")=="RESTORED","reload second-day public receipts")
    check(loaded.status()["money"]==restored.status()["money"] and
        loaded.sandwich_offers()[0]["resolved"],
        "day2 real receipts, availability and cash survive disk reload")
    check(loaded.session.world.cooking_view()["stock"]["liver"]==800,
        "restored live stock not doubled")
    check(Kernel.new().restore_snapshot(loaded.session.world.view()),
        "canonical daily purchase events replay byte-identically")
    loaded.dispose()
    restored.dispose()
    g.dispose()
