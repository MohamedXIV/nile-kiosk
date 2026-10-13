extends RefCounted
## SYS P3 production food domain. All effects are replayed by WorldState.
## No scenes, NPC scripts, prices, RNG or D001 tea_steps here.
const MAX_AMOUNT: int = 2147483647
const MAX_STEPS: int = 32

var ingredients: Dictionary = {}
var stock: Dictionary = {}
var recipes: Dictionary = {}
var stations: Dictionary = {}
var preparations: Dictionary = {}
var items: Dictionary = {}
var waste: Dictionary = {}

static func valid_id(v: Variant) -> bool:
    return typeof(v) == TYPE_STRING and not (v as String).strip_edges().is_empty() and (v as String).length() <= 128

static func num(v: Variant, minimum: int = 0) -> bool:
    if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
        return false
    return is_finite(float(v)) and float(v) >= float(minimum) and float(v) <= float(MAX_AMOUNT) and float(v) == float(int(v))

static func exact(d: Dictionary, keys: Array) -> bool:
    if d.size() != keys.size():
        return false
    for k in keys:
        if not d.has(k):
            return false
    return true

static func command(kind: String) -> bool:
    return kind in [
        "ingredient.define", "stock.add", "stock.discard", "recipe.define",
        "station.register", "station.block", "station.unblock",
        "cook.start", "cook.step.begin", "cook.step.finish",
        "cook.step.interrupt", "cook.step.resume", "cook.cancel", "cook.item.use"
    ]

static func event_kind(kind: String) -> String:
    match kind:
        "ingredient.define": return "ingredient.defined"
        "stock.add": return "stock.added"
        "stock.discard": return "stock.discarded"
        "recipe.define": return "recipe.defined"
        "station.register": return "station.registered"
        "station.block": return "station.blocked"
        "station.unblock": return "station.unblocked"
        "cook.start": return "cook.started"
        "cook.step.begin": return "cook.step_begun"
        "cook.step.finish": return "cook.step_finished"
        "cook.step.interrupt": return "cook.step_interrupted"
        "cook.step.resume": return "cook.step_resumed"
        "cook.cancel": return "cook.cancelled"
        "cook.item.use": return "cook.item_used"
    return ""

static func command_kind(kind: String) -> String:
    match kind:
        "ingredient.defined": return "ingredient.define"
        "stock.added": return "stock.add"
        "stock.discarded": return "stock.discard"
        "recipe.defined": return "recipe.define"
        "station.registered": return "station.register"
        "station.blocked": return "station.block"
        "station.unblocked": return "station.unblock"
        "cook.started": return "cook.start"
        "cook.step_begun": return "cook.step.begin"
        "cook.step_finished": return "cook.step.finish"
        "cook.step_interrupted": return "cook.step.interrupt"
        "cook.step_resumed": return "cook.step.resume"
        "cook.cancelled": return "cook.cancel"
        "cook.item_used": return "cook.item.use"
    return ""

func snapshot() -> Dictionary:
    return {
        "ingredients": ingredients.duplicate(true), "stock": stock.duplicate(true),
        "recipes": recipes.duplicate(true), "stations": stations.duplicate(true),
        "preparations": preparations.duplicate(true),
        "items": items.duplicate(true), "waste": waste.duplicate(true)
    }

func copy_domain() -> RefCounted:
    var cloned: RefCounted = get_script().new()
    cloned.ingredients = ingredients.duplicate(true)
    cloned.stock = stock.duplicate(true)
    cloned.recipes = recipes.duplicate(true)
    cloned.stations = stations.duplicate(true)
    cloned.preparations = preparations.duplicate(true)
    cloned.items = items.duplicate(true)
    cloned.waste = waste.duplicate(true)
    return cloned

static func rejected(code: String) -> Dictionary:
    return {"ok": false, "code": code}

func _validate_steps(steps: Array) -> Dictionary:
    if steps.is_empty() or steps.size() > MAX_STEPS:
        return rejected("INVALID_STEPS")
    var totals: Dictionary = {}
    for step in steps:
        if typeof(step) != TYPE_DICTIONARY or not exact(step, ["station_type", "inputs", "work_minutes"]):
            return rejected("INVALID_STEPS")
        if not valid_id(step.get("station_type")) or not num(step.get("work_minutes")) or typeof(step.get("inputs")) != TYPE_DICTIONARY:
            return rejected("INVALID_STEPS")
        var inputs: Dictionary = step["inputs"]
        if inputs.is_empty():
            return rejected("INVALID_STEPS")
        for ingredient_id in inputs:
            if not valid_id(ingredient_id) or not ingredients.has(ingredient_id) or not num(inputs[ingredient_id], 1):
                return rejected("INVALID_INGREDIENT")
            var existing: int = int(totals.get(ingredient_id, 0))
            var quantity: int = int(inputs[ingredient_id])
            if quantity > MAX_AMOUNT - existing:
                return rejected("AMOUNT_OVERFLOW")
            totals[ingredient_id] = existing + quantity
    return {"ok": true, "totals": totals}

func _job(payload: Dictionary, stage: String = "") -> Dictionary:
    if not exact(payload, ["job_id"]) or not valid_id(payload.get("job_id")):
        return rejected("INVALID_PAYLOAD")
    if not preparations.has(payload["job_id"]):
        return rejected("UNKNOWN_PREPARATION")
    var j: Dictionary = preparations[payload["job_id"]]
    if not stage.is_empty() and j["stage"] != stage:
        return rejected("INVALID_STAGE")
    return {"ok": true, "job": j}

func plan(kind: String, p: Dictionary, actor: String, scheduler_jobs: Dictionary, minute: int) -> Dictionary:
    if not command(kind):
        return rejected("UNKNOWN_COMMAND")
    match kind:
        "ingredient.define":
            if not exact(p, ["ingredient_id", "unit"]) or not valid_id(p.get("ingredient_id")) or not valid_id(p.get("unit")):
                return rejected("INVALID_PAYLOAD")
            if ingredients.has(p["ingredient_id"]):
                return rejected("INGREDIENT_EXISTS")
            return {"ok": true, "effect": {"ingredient_id": p["ingredient_id"]}}
        "stock.add", "stock.discard":
            if not exact(p, ["ingredient_id", "quantity"]) or not valid_id(p.get("ingredient_id")) or not num(p.get("quantity"), 1):
                return rejected("INVALID_PAYLOAD")
            if not ingredients.has(p["ingredient_id"]):
                return rejected("UNKNOWN_INGREDIENT")
            var available: int = int(stock.get(p["ingredient_id"], 0))
            if kind == "stock.add" and int(p["quantity"]) > MAX_AMOUNT - available:
                return rejected("AMOUNT_OVERFLOW")
            if kind == "stock.discard" and int(p["quantity"]) > available:
                return rejected("INSUFFICIENT_STOCK")
            if kind == "stock.discard" and int(p["quantity"]) > MAX_AMOUNT - int(waste.get(p["ingredient_id"], 0)):
                return rejected("AMOUNT_OVERFLOW")
            return {"ok": true, "effect": {"quantity": int(p["quantity"])}}
        "recipe.define":
            if not exact(p, ["recipe_id", "steps", "shelf_minutes"]) or not valid_id(p.get("recipe_id")) or typeof(p.get("steps")) != TYPE_ARRAY or not num(p.get("shelf_minutes")):
                return rejected("INVALID_PAYLOAD")
            if recipes.has(p["recipe_id"]):
                return rejected("RECIPE_EXISTS")
            var validated: Dictionary = _validate_steps(p["steps"])
            if not validated["ok"]:
                return validated
            return {"ok": true, "effect": {"total_inputs": validated["totals"]}}
        "station.register":
            if not exact(p, ["station_id", "station_type"]) or not valid_id(p.get("station_id")) or not valid_id(p.get("station_type")):
                return rejected("INVALID_PAYLOAD")
            if stations.has(p["station_id"]):
                return rejected("STATION_EXISTS")
            return {"ok": true, "effect": {"station_id": p["station_id"]}}
        "station.block", "station.unblock":
            if not exact(p, ["station_id"]) or not valid_id(p.get("station_id")):
                return rejected("INVALID_PAYLOAD")
            if not stations.has(p["station_id"]):
                return rejected("UNKNOWN_STATION")
            var station: Dictionary = stations[p["station_id"]]
            if kind == "station.block" and (station["blocked"] or not station["busy_job"].is_empty()):
                return rejected("STATION_UNAVAILABLE")
            if kind == "station.unblock" and not station["blocked"]:
                return rejected("STATION_NOT_BLOCKED")
            return {"ok": true, "effect": {"blocked": kind == "station.block"}}
        "cook.start":
            if not exact(p, ["job_id", "recipe_id", "deadline_minute"]) or not valid_id(p.get("job_id")) or not valid_id(p.get("recipe_id")) or not num(p.get("deadline_minute"), minute + 1):
                return rejected("INVALID_PAYLOAD")
            if preparations.has(p["job_id"]):
                return rejected("PREPARATION_EXISTS")
            if not recipes.has(p["recipe_id"]):
                return rejected("UNKNOWN_RECIPE")
            var expire_job_id: String = "cook:job:" + p["job_id"]
            var item_expire_id: String = "cook:item:" + p["job_id"]
            if scheduler_jobs.has(expire_job_id) or scheduler_jobs.has(item_expire_id):
                return rejected("JOB_ID_CONFLICT")
            var totals: Dictionary = recipes[p["recipe_id"]]["total_inputs"]
            for ingredient_id in totals:
                if int(stock.get(ingredient_id, 0)) < int(totals[ingredient_id]):
                    return rejected("INSUFFICIENT_STOCK")
            return {"ok": true, "effect": {"reserved": totals.duplicate(true), "expire_job_id": expire_job_id}}
        "cook.step.begin":
            if not exact(p, ["job_id", "station_id"]) or not valid_id(p.get("job_id")) or not valid_id(p.get("station_id")):
                return rejected("INVALID_PAYLOAD")
            if not preparations.has(p["job_id"]):
                return rejected("UNKNOWN_PREPARATION")
            var j: Dictionary = preparations[p["job_id"]]
            if j["stage"] != "waiting":
                return rejected("INVALID_STAGE")
            if not stations.has(p["station_id"]):
                return rejected("UNKNOWN_STATION")
            var station: Dictionary = stations[p["station_id"]]
            if station["blocked"] or not station["busy_job"].is_empty():
                return rejected("STATION_UNAVAILABLE")
            var step: Dictionary = recipes[j["recipe_id"]]["steps"][j["step_index"]]
            if step["station_type"] != station["station_type"]:
                return rejected("WRONG_STATION_TYPE")
            if int(step["work_minutes"]) > MAX_AMOUNT - minute:
                return rejected("TIME_OVERFLOW")
            return {"ok": true, "effect": {"ready_minute": minute + int(step["work_minutes"]), "inputs": step["inputs"].duplicate(true)}}
        "cook.step.finish":
            var validated: Dictionary = _job(p, "active")
            if not validated["ok"]:
                return validated
            var j: Dictionary = validated["job"]
            if minute < j["ready_minute"]:
                return rejected("STEP_NOT_READY")
            var final_step: bool = j["step_index"] == recipes[j["recipe_id"]]["steps"].size() - 1
            var shelf: int = int(recipes[j["recipe_id"]]["shelf_minutes"])
            if final_step and shelf > 0 and minute > MAX_AMOUNT - shelf:
                return rejected("TIME_OVERFLOW")
            var item_id: String = "item:" + j["job_id"]
            if final_step and items.has(item_id):
                return rejected("ITEM_ID_CONFLICT")
            return {"ok": true, "effect": {"completed": final_step, "item_id": item_id if final_step else "", "expires_minute": minute + shelf if final_step and shelf > 0 else 0}}
        "cook.step.interrupt":
            var validated: Dictionary = _job(p, "active")
            if not validated["ok"]:
                return validated
            var j: Dictionary = validated["job"]
            return {"ok": true, "effect": {"remaining_minutes": maxi(0, int(j["ready_minute"]) - minute)}}
        "cook.step.resume":
            if not exact(p, ["job_id", "station_id"]) or not valid_id(p.get("job_id")) or not valid_id(p.get("station_id")):
                return rejected("INVALID_PAYLOAD")
            if not preparations.has(p["job_id"]):
                return rejected("UNKNOWN_PREPARATION")
            var j: Dictionary = preparations[p["job_id"]]
            if j["stage"] != "interrupted":
                return rejected("INVALID_STAGE")
            if not stations.has(p["station_id"]):
                return rejected("UNKNOWN_STATION")
            var station: Dictionary = stations[p["station_id"]]
            if station["blocked"] or not station["busy_job"].is_empty():
                return rejected("STATION_UNAVAILABLE")
            var step: Dictionary = recipes[j["recipe_id"]]["steps"][j["step_index"]]
            if station["station_type"] != step["station_type"]:
                return rejected("WRONG_STATION_TYPE")
            if j["remaining_minutes"] > MAX_AMOUNT - minute:
                return rejected("TIME_OVERFLOW")
            return {"ok": true, "effect": {"ready_minute": minute + int(j["remaining_minutes"])}}
        "cook.cancel":
            var validated: Dictionary = _job(p)
            if not validated["ok"]:
                return validated
            if validated["job"]["stage"] in ["completed", "cancelled", "expired"]:
                return rejected("PREPARATION_FINAL")
            return {"ok": true, "effect": {"refunded": validated["job"]["reserved"].duplicate(true), "wasted": validated["job"]["consumed"].duplicate(true)}}
        "cook.item.use":
            if not exact(p, ["item_id", "purpose_id"]) or not valid_id(p.get("item_id")) or not valid_id(p.get("purpose_id")):
                return rejected("INVALID_PAYLOAD")
            if not items.has(p["item_id"]):
                return rejected("UNKNOWN_ITEM")
            if items[p["item_id"]]["status"] != "ready":
                return rejected("ITEM_NOT_READY")
            return {"ok": true, "effect": {"item_id": p["item_id"]}}
    return rejected("UNKNOWN_COMMAND")

func _scheduler_job(id: String, due: int, topic: String, data: Dictionary, seq: int, actor: String, cmd_id: String) -> Dictionary:
    return {
        "job_id": id, "due_minute": due, "priority": 50, "topic": topic,
        "data": data.duplicate(true), "every_minutes": 0,
        "created_sequence": seq, "source_actor_id": actor,
        "source_command_id": cmd_id, "status": "pending",
        "execution_count": 0, "last_fire_id": ""
    }

func _release_station(job: Dictionary) -> void:
    if not job["station_id"].is_empty():
        stations[job["station_id"]]["busy_job"] = ""
        job["station_id"] = ""

func _settle_job(job: Dictionary, new_stage: String, scheduler_jobs: Dictionary) -> Dictionary:
    _release_station(job)
    var refunded: Dictionary = job["reserved"].duplicate(true)
    var spoiled: Dictionary = job["consumed"].duplicate(true)
    for ingredient_id in refunded:
        stock[ingredient_id] = int(stock[ingredient_id]) + int(refunded[ingredient_id])
    for ingredient_id in spoiled:
        waste[ingredient_id] = int(waste.get(ingredient_id, 0)) + int(spoiled[ingredient_id])
    job["reserved"] = {}
    job["stage"] = new_stage
    if scheduler_jobs[job["expire_job_id"]]["status"] == "pending":
        scheduler_jobs[job["expire_job_id"]]["status"] = "cancelled"
    return {"refunded": refunded, "wasted": spoiled}

func apply_command(kind: String, p: Dictionary, effect: Dictionary, minute: int, event_id: String, seq: int, actor: String, cmd_id: String, scheduler_jobs: Dictionary) -> void:
    match kind:
        "ingredient.define":
            ingredients[p["ingredient_id"]] = {"ingredient_id": p["ingredient_id"], "unit": p["unit"], "event_id": event_id}
            stock[p["ingredient_id"]] = 0
            waste[p["ingredient_id"]] = 0
        "stock.add":
            stock[p["ingredient_id"]] += int(p["quantity"])
        "stock.discard":
            stock[p["ingredient_id"]] -= int(p["quantity"])
            waste[p["ingredient_id"]] += int(p["quantity"])
        "recipe.define":
            recipes[p["recipe_id"]] = {
                "recipe_id": p["recipe_id"], "steps": p["steps"].duplicate(true),
                "total_inputs": effect["total_inputs"].duplicate(true),
                "shelf_minutes": int(p["shelf_minutes"]), "event_id": event_id
            }
        "station.register":
            stations[p["station_id"]] = {
                "station_id": p["station_id"], "station_type": p["station_type"],
                "blocked": false, "busy_job": "", "event_id": event_id
            }
        "station.block", "station.unblock":
            stations[p["station_id"]]["blocked"] = effect["blocked"]
        "cook.start":
            var totals: Dictionary = effect["reserved"]
            for ingredient_id in totals:
                stock[ingredient_id] -= int(totals[ingredient_id])
            preparations[p["job_id"]] = {
                "job_id": p["job_id"], "recipe_id": p["recipe_id"], "stage": "waiting",
                "started_minute": minute, "deadline_minute": int(p["deadline_minute"]),
                "step_index": 0, "station_id": "", "ready_minute": 0,
                "remaining_minutes": 0, "reserved": totals.duplicate(true),
                "consumed": {}, "expire_job_id": effect["expire_job_id"],
                "start_event_id": event_id
            }
            scheduler_jobs[effect["expire_job_id"]] = _scheduler_job(
                effect["expire_job_id"], int(p["deadline_minute"]), "cook.job.expire",
                {"job_id": p["job_id"]}, seq, actor, cmd_id
            )
        "cook.step.begin":
            var job: Dictionary = preparations[p["job_id"]]
            for ingredient_id in effect["inputs"]:
                var amount: int = int(effect["inputs"][ingredient_id])
                job["reserved"][ingredient_id] = int(job["reserved"][ingredient_id]) - amount
                if job["reserved"][ingredient_id] == 0:
                    job["reserved"].erase(ingredient_id)
                job["consumed"][ingredient_id] = int(job["consumed"].get(ingredient_id, 0)) + amount
            job["stage"] = "active"
            job["station_id"] = p["station_id"]
            job["ready_minute"] = effect["ready_minute"]
            stations[p["station_id"]]["busy_job"] = p["job_id"]
        "cook.step.finish":
            var job: Dictionary = preparations[p["job_id"]]
            _release_station(job)
            if effect["completed"]:
                job["stage"] = "completed"
                job["reserved"] = {}
                scheduler_jobs[job["expire_job_id"]]["status"] = "cancelled"
                var item_id: String = effect["item_id"]
                items[item_id] = {
                    "item_id": item_id, "job_id": job["job_id"],
                    "recipe_id": job["recipe_id"], "status": "ready",
                    "created_minute": minute, "expires_minute": effect["expires_minute"],
                    "event_id": event_id, "purpose_id": ""
                }
                if int(effect["expires_minute"]) > 0:
                    var expiry_id: String = "cook:item:" + job["job_id"]
                    scheduler_jobs[expiry_id] = _scheduler_job(
                        expiry_id, int(effect["expires_minute"]), "cook.item.expire",
                        {"item_id": item_id}, seq, actor, cmd_id
                    )
            else:
                job["step_index"] += 1
                job["stage"] = "waiting"
                job["ready_minute"] = 0
        "cook.step.interrupt":
            var job: Dictionary = preparations[p["job_id"]]
            _release_station(job)
            job["stage"] = "interrupted"
            job["remaining_minutes"] = effect["remaining_minutes"]
            job["ready_minute"] = 0
        "cook.step.resume":
            var job: Dictionary = preparations[p["job_id"]]
            job["station_id"] = p["station_id"]
            job["stage"] = "active"
            job["ready_minute"] = effect["ready_minute"]
            job["remaining_minutes"] = 0
            stations[p["station_id"]]["busy_job"] = p["job_id"]
        "cook.cancel":
            _settle_job(preparations[p["job_id"]], "cancelled", scheduler_jobs)
        "cook.item.use":
            items[p["item_id"]]["status"] = "used"
            items[p["item_id"]]["purpose_id"] = p["purpose_id"]
            var j: Dictionary = preparations[items[p["item_id"]]["job_id"]]
            var expiry_id: String = "cook:item:" + j["job_id"]
            if scheduler_jobs.has(expiry_id) and scheduler_jobs[expiry_id]["status"] == "pending":
                scheduler_jobs[expiry_id]["status"] = "cancelled"

func apply_fire(fire: Dictionary, scheduler_jobs: Dictionary) -> Dictionary:
    if fire["topic"] == "cook.job.expire":
        var job_id: String = fire["data"]["job_id"]
        var job: Dictionary = preparations[job_id]
        var settled: Dictionary = _settle_job(job, "expired", scheduler_jobs)
        return {"fire_id": fire["fire_id"], "job_id": job_id, "outcome": "expired",
            "at_minute": fire["world_minute"],
            "refunded": settled["refunded"], "wasted": settled["wasted"]}
    if fire["topic"] == "cook.item.expire":
        var item_id: String = fire["data"]["item_id"]
        items[item_id]["status"] = "expired"
        return {"fire_id": fire["fire_id"], "item_id": item_id,
            "outcome": "item_expired", "at_minute": fire["world_minute"]}
    return {}

func _simulate_fires(fires: Array, scheduler_jobs: Dictionary) -> Array:
    var outcomes: Array = []
    for fire in fires:
        var result: Dictionary = apply_fire(fire, scheduler_jobs)
        if not result.is_empty():
            outcomes.append(result)
    return outcomes

func project_firings(fires: Array, scheduler_jobs: Dictionary) -> Array:
    return copy_domain()._simulate_fires(fires, scheduler_jobs.duplicate(true))

func apply_firings(fires: Array, scheduler_jobs: Dictionary) -> void:
    _simulate_fires(fires, scheduler_jobs)
