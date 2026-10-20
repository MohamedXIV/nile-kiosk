extends SceneTree
## Gameplay acceptance: real starter P2 path, paid P5 offers, timed P3 steps,
## one item, save/replay and no phantom stock or duplicated results.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const SandwichControls = preload("res://scripts/gameplay/sandwich_controls.gd")
const SAVE = "user://nk-game-first-sandwich-play.json"
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
    if not ok: failures.append(label)

func _initialize() -> void:
    _run()
    if failures.is_empty():
        print("GAME FIRST SANDWICH: PASS (real shop, turn, replay and item)")
        quit(0)
    else:
        for failure in failures: push_error(failure)
        print("GAME FIRST SANDWICH: FAIL (%d)" % failures.size())
        quit(1)

func _run() -> void:
    # Real Godot Buttons, not painted/pointer hitboxes or fake world state.
    var controls: Control = SandwichControls.new()
    root.add_child(controls)
    controls.build() # SceneTree._initialize runs before root's first READY.
    var sample_offers: Array = [
        {"ingredient_id":"bread","cost":120,"resolved":false},
        {"ingredient_id":"liver","cost":1200,"resolved":false}
    ]
    var stock_view: Dictionary = {"near":true,"offers":sample_offers,
        "stage":"","can_start":false,"cue":"Get cooking ingredients"}
    controls.update_view(stock_view,false,false,false)
    check(controls.opener.visible,"nearby cooking opener must be visible")
    controls.update_view(stock_view,true,false,false)
    check(not controls.opener.visible and controls.action_button.visible and
        controls.action_button.text.contains("bread") and
        controls.wait_button.visible and controls.wait_button.text=="Next ingredient",
        "in-reach bottom strip must expose one Buy and optional Next only")
    check(controls.selected_offer_index==0,"first unpaid lot selected")
    controls._secondary_pressed()
    check(controls.selected_offer_index==1 and
        controls.action_button.text.contains("liver"),
        "player can freely browse offered ingredients without buying")
    stock_view["offers"][1]["resolved"]=true
    controls.update_view(stock_view,true,false,false)
    check(controls.selected_offer_index==0 and
        not controls.wait_button.visible,
        "buy cursor must skip purchased lots and hide unavailable Next")
    # A recipe can become cookable before all optional P5 lots are bought.
    # The player decides: E can still buy the remaining lot, F can start.
    var ready_with_optional: Dictionary = stock_view.duplicate(true)
    ready_with_optional["can_start"]=true
    controls.update_view(ready_with_optional,true,false,false)
    check(controls.action_kind=="buy" and
        controls.action_button.text.contains("bread") and
        controls.wait_button.visible and controls.wait_button.text=="Start cooking",
        "remaining stock must not disappear just because cooking is ready")
    # No supplies and no active P3 recipe is not an actionable context.
    var unavailable: Dictionary = stock_view.duplicate(true)
    for offer in unavailable["offers"]:
        offer["resolved"]=true
    unavailable["can_start"]=false
    controls.update_view(unavailable,true,false,false)
    check(not controls.action_button.visible and not controls.wait_button.visible,
        "sold-out unready workstation must not render a bogus Start action")
    var cooking: Dictionary = stock_view.duplicate(true)
    cooking["stage"]="active"
    cooking["can_start"]=true
    cooking["cue"]="Enter · Turn the liver now"
    controls.update_view(cooking,true,false,false)
    check(controls.action_button.visible and
        controls.action_button.text=="Turn liver" and
        controls.wait_button.visible and
        controls.action_kind=="step",
        "ongoing cooking switches contextual Buy to Step / Wait")
    controls._utility_toggle()
    check(controls.save_button.visible and not controls.action_button.visible and
        not controls.wait_button.visible,"Save utility cannot crowd cooking verbs")
    controls._utility_toggle()
    var far: Dictionary = stock_view.duplicate(true)
    far["near"] = false
    controls.update_view(far,true,false,false)
    check(not controls.action_button.visible and not controls.close_button.visible,
        "distant player cannot act through the strip")
    controls.update_view(cooking,true,true,false)
    check(not controls.action_button.visible and not controls.menu_button.visible,
        "Ink conversations suppress all competing cooking controls")
    controls.update_view(cooking,true,false,true)
    check(not controls.wait_button.visible and not controls.close_button.visible,
        "F1 help hides the workstation overlay")
    root.remove_child(controls)
    controls.free()
    if FileAccess.file_exists(SAVE):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var g: RefCounted = Game.new()
    var boot: Dictionary = g.start(SAVE)
    check(boot.get("ok",false), "game boots with cooking content")
    if not boot.get("ok",false): return
    check(g.session.world.cooking_view()["recipes"].has("liver_sandwich"),
        "default world includes real recipe")
    check(g.session.world.cooking_view()["stock"]["liver"] == 0,
        "installer must not gift meat")
    var offers: Array[Dictionary] = g.sandwich_offers()
    check(offers.size()==6,"six paid offers, not auto-shopping")
    check(g.sandwich_context()["heat_state"]=="idle" and
        not g.sandwich_context()["can_start"] and
        int(g.sandwich_context()["stock"]["liver"])==0,
        "unpaid ingredients must show a real not-ready station")
    check(g.sandwich_purchase(0).get("code","")=="COUNTER_TOO_FAR",
        "roof cannot buy kiosk ingredients remotely")
    check(g.sandwich_step().get("code","")=="COUNTER_TOO_FAR",
        "roof cannot remotely cook")
    check(g.travel_near().get("ok",false),"roof to landing")
    for i in range(9): check(g.move_world(18,0).get("ok",false),"landing approach")
    check(g.travel_near().get("ok",false),"landing to street")
    for i in range(9): check(g.move_world(18,0).get("ok",false),"street approach")
    check(g.travel_near().get("ok",false),"street to kiosk")
    for i in range(4): check(g.move_world(18,0).get("ok",false),"counter approach")
    check(g.sandwich_context()["near"],"real canonical counter proximity")
    check(g.sandwich_step().get("code","")=="INSUFFICIENT_STOCK",
        "no cooking unpaid liver")
    var balance: int = g.session.world.balance_minor()
    var spent: int = 0
    for i in range(offers.size()):
        var bought: Dictionary = g.sandwich_purchase(i)
        check(bought.get("ok",false),"real purchase %d: %s" % [i,bought])
        spent += int(offers[i]["cost"])
    check(spent==1560 and g.session.world.balance_minor()==balance-spent,
        "P5 debited actual total of six separately paid items")
    check(g.sandwich_context()["can_start"] and
        int(g.sandwich_context()["stock"]["liver"])==400 and
        offers[0].has("unit"),"P3 current inventory and real units shown after payment")
    check(g.sandwich_purchase(0).get("code","")=="OFFER_RESOLVED",
        "cannot duplicate paid stock")
    var started: Dictionary = g.sandwich_step()
    check(started.get("ok",false) and g.sandwich_context()["stage"]=="waiting",
        "real player starts sandwich job")
    check(g.sandwich_step().get("ok",false),"season begins")
    check(g.sandwich_step().get("code","")=="STEP_NOT_READY",
        "season cannot finish early")
    check(g.wait_minutes(1).get("ok",false),"one season minute")
    check(g.sandwich_step().get("ok",false),"finish seasoning")
    check(g.sandwich_step().get("ok",false),"sear begins")
    check(g.sandwich_context()["heat_state"]=="warming" and
        g.sandwich_context()["heat_minutes"]==2,
        "P1 clock supplies first-face lead-in, no visual timer state")
    check(g.sandwich_step().get("code","")=="ACTION_TOO_EARLY",
        "must sear first face before turning")
    check(g.wait_minutes(2).get("ok",false),"first face two minutes")
    check(g.sandwich_context()["heat_state"]=="turn_window" and
        g.sandwich_context()["heat_minutes"]==4,
        "safe turn window is derived from the canonical heat step")
    check(g.sandwich_step().get("ok",false) and
        g.sandwich_context()["stage"]=="active", "actual recorded turn")
    check(g.sandwich_context()["heat_state"]=="turned" and
        g.sandwich_context()["heat_minutes"]==2,
        "display recognizes real cook.step_actioned event")
    check(g.save_game().get("ok",false),"save midway through second face")
    var before: Dictionary = g.session.world.view()
    var resumed: RefCounted = Game.new()
    check(resumed.start(SAVE).get("code","")=="RESTORED",
        "restored world including installed recipe")
    check(JSON.stringify(resumed.session.world.view())==JSON.stringify(before),
        "loading game should not append duplicate installation events")
    check(resumed.sandwich_context()["stage"]=="active" and
        resumed.sandwich_context()["step_index"]==1 and
        resumed.sandwich_context()["ready_in"]==2,"restore genuine mid-pan action")
    check(resumed.sandwich_context()["heat_state"]=="turned" and
        resumed.sandwich_context()["heat_minutes"]==2,
        "heat view survives save/reload without storing display state")
    check(resumed.sandwich_step().get("code","")=="STEP_NOT_READY",
        "cannot lift second face before time")
    check(resumed.wait_minutes(2).get("ok",false),"second face two minutes")
    check(resumed.sandwich_step().get("ok",false),"lift from pan")
    check(resumed.sandwich_step().get("ok",false),"assemble bread and lemon")
    var final: Dictionary = resumed.sandwich_step()
    check(final.get("ok",false),"finish actual prepared sandwich")
    var cue: Dictionary = resumed.sandwich_context()
    check(cue["stage"]=="" and cue["grade"]=="good" and cue["score"]==100,
        "on-time quality is projected from authenticated timing")
    check(not cue["item_id"].is_empty() and
        resumed.session.world.prepared_item(str(cue["item_id"]))["status"]=="ready",
        "one real item, not synthetic UI reward")
    check(resumed.session.world.cooking_view()["stock"]["liver"]==300,
        "100g exactly consumed from paid lot")
    check(resumed.save_game().get("ok",false),"save completed sandwich")
    var completed: RefCounted = Game.new()
    check(completed.start(SAVE).get("code","")=="RESTORED",
        "completed game restores")
    check(completed.sandwich_context()["grade"]=="good" and
        completed.sandwich_context()["item_id"]==cue["item_id"],
        "authentic item/quality survives game reload")
    check(completed.session.world.cooking_view()["stock"]["liver"]==300,
        "reload never refills ingredient stock")
    g.dispose()
    resumed.dispose()
    completed.dispose()
