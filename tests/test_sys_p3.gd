extends SceneTree
## SYS P3 acceptance: production WorldKernel, not D001 tea_steps.
const Kernel = preload("res://scripts/core/world_kernel.gd")
var errors: Array[String] = []

func _initialize() -> void:
    _definitions_and_units()
    _parallel_reservations()
    _interrupt_and_resume()
    _cancel_and_deadlines()
    _items_and_expiry()
    _replay_and_persistence()
    if errors.is_empty():
        print("SYS P3: PASS (6 groups: data, reservations, interruption, expiry, items, replay)")
        quit(0)
        return
    for e in errors:
        push_error(e)
    print("SYS P3: FAIL (%d assertions)" % errors.size())
    quit(1)

func check(condition: bool, label: String) -> void:
    if not condition:
        errors.append(label)

func cmd(id: String, kind: String, p: Dictionary = {}, actor: String = "player") -> Dictionary:
    return {"id": id, "actor_id": actor, "kind": kind, "payload": p}

func send(k, id: String, kind: String, p: Dictionary = {}, actor: String = "player") -> Dictionary:
    return k.dispatch(cmd(id, kind, p, actor))

func step(kind: String, inputs: Dictionary, work: int) -> Dictionary:
    return {"station_type": kind, "inputs": inputs, "work_minutes": work}

func setup(k) -> void:
    check(send(k,"f","ingredient.define",{"ingredient_id":"flour","unit":"g"})["ok"], "define flour")
    check(send(k,"w","ingredient.define",{"ingredient_id":"water","unit":"ml"})["ok"], "define water")
    check(send(k,"o","ingredient.define",{"ingredient_id":"oil","unit":"ml"})["ok"], "define oil")
    check(send(k,"fstock","stock.add",{"ingredient_id":"flour","quantity":8})["ok"], "stock flour")
    check(send(k,"wstock","stock.add",{"ingredient_id":"water","quantity":4})["ok"], "stock water")
    check(send(k,"ostock","stock.add",{"ingredient_id":"oil","quantity":4})["ok"], "stock oil")
    check(send(k,"mixing","station.register",{"station_id":"mixing","station_type":"mix"})["ok"], "mix station")
    check(send(k,"heating","station.register",{"station_id":"heating","station_type":"heat"})["ok"], "heat station")
    check(send(k,"recipe","recipe.define",{
        "recipe_id":"bread","steps":[step("mix",{"flour":2,"water":1},5),step("heat",{"oil":1},3)],
        "shelf_minutes":10
    })["ok"], "recipe fixture")
    check(send(k,"otherrecipe","recipe.define",{"recipe_id":"porridge","steps":[
        step("heat",{"water":1},2)],"shelf_minutes":0})["ok"], "different recipe")

func prep(k, id: String, recipe: String = "bread", deadline: int = 30) -> Dictionary:
    return send(k,"start:"+id,"cook.start",{"job_id":id,"recipe_id":recipe,"deadline_minute":deadline})

func begin(k, id: String, station: String, suffix: String = "") -> Dictionary:
    return send(k,"begin:"+id+":"+station+suffix,"cook.step.begin",{"job_id":id,"station_id":station})

func finish(k, id: String, suffix: String = "") -> Dictionary:
    return send(k,"finish:"+id+suffix,"cook.step.finish",{"job_id":id})

func world(k) -> Dictionary:
    return k.cooking_view()

func _definitions_and_units() -> void:
    var k = Kernel.new(100)
    setup(k)
    check(world(k)["ingredients"]["water"]["unit"] == "ml", "unit missing")
    check(send(k,"bad","ingredient.define",{"ingredient_id":"flour","unit":"kg"})["code"] == "INGREDIENT_EXISTS", "redefine unit")
    check(send(k,"bad2","recipe.define",{"recipe_id":"evil","steps":[step("mix",{"unregistered":1},1)],"shelf_minutes":1})["code"] == "INVALID_INGREDIENT", "unregistered recipe input")
    check(send(k,"bad3","recipe.define",{"recipe_id":"evil","steps":[step("mix",{"water":0},1)],"shelf_minutes":1})["code"] == "INVALID_INGREDIENT", "zero recipe input")
    check(send(k,"bad4","stock.add",{"ingredient_id":"oil","quantity":0})["code"] == "INVALID_PAYLOAD", "zero stock")
    check(send(k,"bad5","stock.discard",{"ingredient_id":"oil","quantity":5})["code"] == "INSUFFICIENT_STOCK", "negative stock")
    check(world(k)["recipes"]["bread"]["total_inputs"] == {"flour":2,"water":1,"oil":1}, "incorrect recipe totals")
    check(send(k,"missing","cook.start",{"job_id":"z","recipe_id":"unknown","deadline_minute":20})["code"] == "UNKNOWN_RECIPE", "unknown recipe")
    check(send(k,"off","station.block",{"station_id":"mixing"})["ok"], "block station")
    check(send(k,"off2","station.block",{"station_id":"mixing"})["code"] == "STATION_UNAVAILABLE", "repeat block")
    check(send(k,"on","station.unblock",{"station_id":"mixing"})["ok"], "unblock station")
    var cloned: Dictionary = world(k)
    cloned["stock"]["flour"] = 500
    check(world(k)["stock"]["flour"] == 8, "mutable projection")

func _parallel_reservations() -> void:
    var k = Kernel.new()
    setup(k)
    var baseline: Dictionary = world(k)
    var retry: Dictionary = prep(k,"job:a")
    check(retry["ok"], "start job")
    check(send(k,"start:job:a","cook.start",{"job_id":"job:a","recipe_id":"bread","deadline_minute":30}) == retry, "command retry charged twice")
    check(world(k)["stock"] == {"flour":6,"water":3,"oil":3}, "reservation not atomic")
    check(prep(k,"job:b")["ok"], "parallel start")
    check(begin(k,"job:a","heating")["code"] == "WRONG_STATION_TYPE", "wrong workstation")
    check(begin(k,"job:a","mixing")["ok"], "begin first")
    check(begin(k,"job:b","mixing")["code"] == "STATION_UNAVAILABLE", "simultaneous single-station work")
    check(send(k,"block_busy","station.block",{"station_id":"mixing"})["code"] == "STATION_UNAVAILABLE", "blocking active workstation")
    check(finish(k,"job:a")["code"] == "STEP_NOT_READY", "early finish")
    check(k.advance_time(5,"tick5")["ok"], "advance mixing")
    check(finish(k,"job:a")["ok"], "first step finish")
    check(begin(k,"job:b","mixing")["ok"], "released workstation")
    check(begin(k,"job:a","heating")["ok"], "other station available")
    check(world(k)["stations"]["mixing"]["busy_job"] == "job:b" and world(k)["stations"]["heating"]["busy_job"] == "job:a", "parallel station occupation")
    check(k.advance_time(3,"tick8")["ok"], "heat timer")
    check(finish(k,"job:a",":bake")["ok"], "final step")
    check(world(k)["items"].has("item:job:a"), "missing unique prepared item")
    check(world(k)["preparations"]["job:a"]["stage"] == "completed", "completed job state")
    check(world(k)["stations"]["heating"]["busy_job"] == "", "station release")
    check(send(k,"start:job:a:again","cook.start",{"job_id":"job:a","recipe_id":"bread","deadline_minute":29})["code"] == "PREPARATION_EXISTS", "reused preparation identity")
    check(baseline["stock"]["flour"] == 8, "test mutated base projection")

func _interrupt_and_resume() -> void:
    var k = Kernel.new()
    setup(k)
    prep(k,"job:a")
    begin(k,"job:a","mixing")
    k.advance_time(2,"two")
    check(send(k,"break","cook.step.interrupt",{"job_id":"job:a"})["ok"], "interrupt")
    check(world(k)["preparations"]["job:a"]["remaining_minutes"] == 3, "incorrect remaining time")
    check(world(k)["stations"]["mixing"]["busy_job"] == "", "interrupt did not release station")
    check(send(k,"bad_resume","cook.step.resume",{"job_id":"job:a","station_id":"heating"})["code"] == "WRONG_STATION_TYPE", "resuming wrong station")
    check(send(k,"back","cook.step.resume",{"job_id":"job:a","station_id":"mixing"})["ok"], "resume")
    check(world(k)["stock"]["flour"] == 6, "resume duplicated ingredient usage")
    k.advance_time(3,"three")
    check(finish(k,"job:a")["ok"], "finish resumed")
    check(world(k)["preparations"]["job:a"]["consumed"]["flour"] == 2, "interrupted ingredients double-consumed")

func _cancel_and_deadlines() -> void:
    var k = Kernel.new()
    setup(k)
    prep(k,"job:a", "bread", 10)
    prep(k,"job:b", "porridge", 6)
    begin(k,"job:a","mixing")
    check(send(k,"cancel","cook.cancel",{"job_id":"job:a"})["ok"], "cancel active")
    check(world(k)["stock"]["flour"] == 8 and world(k)["stock"]["water"] == 2 and world(k)["stock"]["oil"] == 4, "cancel escrow accounting")
    check(world(k)["waste"]["flour"] == 2 and world(k)["waste"]["water"] == 1, "consumed ingredients not recorded waste")
    check(send(k,"cancel:again","cook.cancel",{"job_id":"job:a"})["code"] == "PREPARATION_FINAL", "double-cancel")
    check(k.advance_time(10,"time10")["ok"], "deadline fired")
    check(world(k)["preparations"]["job:b"]["stage"] == "expired", "pending preparation never expired")
    check(world(k)["stock"]["water"] == 3, "unused ingredient not returned after deadline")
    check(world(k)["waste"]["water"] == 1, "expired unstarted ingredients wasted")
    check(world(k)["stations"]["mixing"]["busy_job"] == "", "canceled station still busy")
    check(world(k)["preparations"]["job:a"]["stage"] == "cancelled", "cancelled job expired later")
    var outcomes: Array = []
    for e in k.event_history_after(0):
        if e["kind"] == "time.advanced":
            outcomes.append_array(e["payload"]["effect"]["cooking_outcomes"])
    check(outcomes.size() == 1 and outcomes[0]["outcome"] == "expired", "deadline outcome multiplied")
    var base: String = JSON.stringify(k.view())
    check(send(k,"unauthorized","schedule.create",{"job_id":"x","due_minute":20,"priority":1,"topic":"cook.item.expire","data":{},"every_minutes":0})["code"] == "INVALID_PAYLOAD", "forged expiry topic")
    check(send(k,"cancel_owned","schedule.cancel",{"job_id":"cook:job:job:a"})["code"] == "JOB_NOT_PENDING", "post-cancel scheduler state")
    check(base == JSON.stringify(k.view()), "rejected commands changed world")

func _items_and_expiry() -> void:
    var k = Kernel.new()
    setup(k)
    prep(k,"job:a")
    begin(k,"job:a","mixing")
    k.advance_time(5,"five")
    finish(k,"job:a")
    begin(k,"job:a","heating")
    k.advance_time(3,"eight")
    finish(k,"job:a",":bake")
    check(world(k)["items"]["item:job:a"]["expires_minute"] == 18, "shelf duration")
    check(send(k,"wrong","cook.item.use",{"item_id":"item:missing","purpose_id":"order:1"})["code"] == "UNKNOWN_ITEM", "ghost item")
    check(send(k,"used","cook.item.use",{"item_id":"item:job:a","purpose_id":"order:1"})["ok"], "item consumption")
    check(send(k,"used2","cook.item.use",{"item_id":"item:job:a","purpose_id":"order:2"})["code"] == "ITEM_NOT_READY", "double sell")
    k.advance_time(20,"future")
    check(world(k)["items"]["item:job:a"]["status"] == "used", "consumed item expired")
    prep(k,"job:c","porridge",35)
    begin(k,"job:c","heating")
    k.advance_time(2,"step")
    finish(k,"job:c")
    check(world(k)["items"]["item:job:c"]["expires_minute"] == 0, "nonperishable item incorrectly timed")
    check(world(k)["items"]["item:job:c"]["status"] == "ready", "nonperishable finished item not ready")
    # New perishable product remains on shelf and expires even without player interaction.
    prep(k,"job:d","bread", 60)
    begin(k,"job:d","mixing")
    k.advance_time(5,"mix:d")
    finish(k,"job:d")
    begin(k,"job:d","heating")
    k.advance_time(3,"heat:d")
    finish(k,"job:d",":bake")
    k.advance_time(10,"expiry:d")
    check(world(k)["items"]["item:job:d"]["status"] == "expired", "unclaimed item stayed fresh")
    check(send(k,"expired_item","cook.item.use",{"item_id":"item:job:d","purpose_id":"order:3"})["code"] == "ITEM_NOT_READY", "expired item used")

func _normalized(k) -> Array:
    var out: Array = []
    for e in k.event_history_after(0):
        if e["kind"] == "time.advanced":
            for effect in e["payload"]["effect"]["cooking_outcomes"]:
                out.append([effect.get("job_id",effect.get("item_id")),effect["outcome"],effect["at_minute"]])
    return out

func _replay_and_persistence() -> void:
    var a = Kernel.new(25)
    var b = Kernel.new(25)
    var split = Kernel.new(25)
    for k in [a,b,split]:
        setup(k)
        send(k,"npc","npc.register",{"npc_id":"guest","location_id":"home"})
        send(k,"npc_r","npc.routine.create",{
            "routine_id":"visit","npc_id":"guest","location_id":"kiosk",
            "start_minute":9,"end_minute":15,"period_minutes":1440
        })
        prep(k,"job:x","bread",12)
        begin(k,"job:x","mixing")
    check(a.advance_time(20,"jump")["ok"], "coarse time jump")
    check(b.advance_time(20,"jump")["ok"], "deterministic identical time jump")
    for i in range(4):
        check(split.advance_time(5,"chunk:%d"%i)["ok"], "chunk advance")
    check(a.cooking_view() == split.cooking_view(), "time chunking changed recipe state")
    check(a.social_view() == split.social_view(), "time chunking changed unrelated NPC")
    check(_normalized(a) == _normalized(split), "time chunking changed cooking outcomes")
    check(JSON.stringify(a.view()) == JSON.stringify(b.view()), "repeated run diverged")
    check(a.cooking_view()["preparations"]["job:x"]["stage"] == "expired", "active cooking time skip")
    check(a.cooking_view()["stations"]["mixing"]["busy_job"] == "", "expired active station occupied")
    var mid = Kernel.new(25)
    setup(mid)
    prep(mid,"job:mid")
    begin(mid,"job:mid","mixing")
    mid.advance_time(2,"mid")
    var file_path: String = "user://nk-sys-p3.json"
    check(mid.save_to_file(file_path), "save mid-preparation")
    var loaded = Kernel.new(1)
    check(loaded.load_from_file(file_path), "load mid-preparation")
    check(JSON.stringify(mid.view()) == JSON.stringify(loaded.view()), "saved world differs from restored")
    loaded.advance_time(3,"advance")
    check(finish(loaded,"job:mid")["ok"], "resume step after disk reload")
    var original: String = JSON.stringify(mid.view())
    var corrupt: Dictionary = mid.view()
    corrupt["cooking"]["stock"]["flour"] = 999999
    check(not mid.restore_snapshot(corrupt), "forged stock accepted")
    corrupt = mid.view()
    corrupt["cooking"]["stations"]["mixing"]["busy_job"] = ""
    check(not mid.restore_snapshot(corrupt), "forged occupancy accepted")
    corrupt = mid.view()
    corrupt["events"][corrupt["events"].size()-1]["payload"]["effect"]["cooking_outcomes"] = [{"forged":true}]
    check(not mid.restore_snapshot(corrupt), "forged cooking event accepted")
    corrupt = mid.view()
    corrupt["version"] = 3
    check(not mid.restore_snapshot(corrupt), "old v3 save silently accepted")
    check(original == JSON.stringify(mid.view()), "bad restore changed canonical state")
    if FileAccess.file_exists(file_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
