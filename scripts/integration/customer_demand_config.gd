extends RefCounted
## Trusted QA content delivery for one canonical autonomous-demand configuration.
## The demand, offer/skip and expiry are always WorldKernel commands/firings.
const State = preload("res://scripts/core/world_state.gd")
const KEYS: Array = ["plan_id","npc_id","venue_id","recipe_id","route","first_minute","interval_minutes","wait_minutes","chance_bp"]

static func load_plan(path: String) -> Dictionary:
    if not path.begins_with("res://content/service/") or path.contains("..") or not path.ends_with(".json"):
        return {"ok":false,"code":"UNTRUSTED_POLICY_PATH"}
    if not FileAccess.file_exists(path):
        return {"ok":false,"code":"POLICY_NOT_FOUND"}
    var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(doc) != TYPE_DICTIONARY or doc.size() != 2 or not doc.has("schema") or not doc.has("plan") or not State.integral(doc["schema"],1) or int(doc["schema"]) != 1:
        return {"ok":false,"code":"INVALID_POLICY"}
    if typeof(doc["plan"]) != TYPE_DICTIONARY or (doc["plan"].size() != KEYS.size() and doc["plan"].size() != KEYS.size()+1) or not State._json_value(doc["plan"]):
        return {"ok":false,"code":"INVALID_POLICY"}
    for key in KEYS:
        if not doc["plan"].has(key):
            return {"ok":false,"code":"INVALID_POLICY"}
    if doc["plan"].size() == KEYS.size()+1 and not doc["plan"].has("social_rule"):
        return {"ok":false,"code":"INVALID_POLICY"}
    return {"ok":true,"plan":doc["plan"].duplicate(true)}

static func configure(session: RefCounted, path: String) -> Dictionary:
    var parsed: Dictionary = load_plan(path)
    if not parsed.get("ok",false): return parsed
    var plan: Dictionary = parsed["plan"]
    var jid: String = "service:demand:offer:"+str(plan["plan_id"])
    if session.world.view()["jobs"].has(jid):
        return {"ok":true,"code":"ALREADY_CONFIGURED"}
    return session.command("service:demand:configure:"+str(plan["plan_id"]),
        "system:director","service.demand.configure",plan)
