extends RefCounted
## One authored cooking expansion pack, installed through canonical commands.
## Defines a recipe/stations/public paid offers; never grants cash or ingredients.
const Kernel = preload("res://scripts/core/world_kernel.gd")
const PATH = "res://content/cooking/nile_liver_sandwich.v1.json"
const AUTHORS = {"ingredient.define":"system:director","recipe.define":"system:director",
    "station.register":"system:director","supply.offer.register":"system:catalog"}

static func install(world: RefCounted) -> Dictionary:
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if typeof(data) != TYPE_DICTIONARY or not Kernel.WorldState._exact_keys(data,["schema","pack_id","terms_status","commands"]) or data.get("terms_status") != "PROPOSED" or data.get("schema") != 1 or data.get("pack_id") != "nile-liver-sandwich-v1":
        return {"ok":false,"code":"INVALID_COOKING_CONTENT"}
    if typeof(data["commands"]) != TYPE_ARRAY or data["commands"].is_empty() or data["commands"].size() > 32:
        return {"ok":false,"code":"INVALID_COOKING_CONTENT"}
    var candidate: RefCounted = Kernel.new()
    if not candidate.restore_snapshot(world.view()): return {"ok":false,"code":"INVALID_WORLD"}
    var commands: Array[Dictionary] = []
    var seen: Dictionary = {}
    for entry in data["commands"]:
        if typeof(entry) != TYPE_DICTIONARY or not Kernel.WorldState._exact_keys(entry,["id","actor_id","kind","payload"]):
            return {"ok":false,"code":"INVALID_COOKING_CONTENT"}
        if not Kernel.WorldState.valid_identity(entry["id"]) or typeof(entry["kind"]) != TYPE_STRING or not AUTHORS.has(entry["kind"]) or entry["actor_id"] != AUTHORS[entry["kind"]]:
            return {"ok":false,"code":"INVALID_COOKING_CONTENT"}
        if seen.has(entry["id"]): return {"ok":false,"code":"INVALID_COOKING_CONTENT"}
        seen[entry["id"]] = true
        var command: Dictionary = entry.duplicate(true)
        command["id"] = "cooking:pack:v1:" + str(entry["id"])
        var checked: Dictionary = candidate.dispatch(command)
        if not checked.get("ok",false): return {"ok":false,"code":"COOKING_CONTENT_REJECTED","cause":checked.get("code"),"entry":entry["id"]}
        commands.append(command)
    # Preflight the entire pack before emitting any live event. Calls are
    # synchronous; there is no await or second authoritative world/clock.
    for command in commands:
        var result: Dictionary = world.dispatch(command)
        if not result.get("ok",false): return result
    return {"ok":true,"code":"INSTALLED","commands":commands.size()}
