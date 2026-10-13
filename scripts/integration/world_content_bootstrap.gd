extends RefCounted
## CONTENT C0 — versioned authored catalog import. Never mutate an existing world.
## A trusted local bundle supplies data, NOT an executable script or arbitrary actors.
const Kernel = preload("res://scripts/core/world_kernel.gd")
const WorldState = preload("res://scripts/core/world_state.gd")
const FORMAT: int = 1
const MAX_COMMANDS: int = 256

# Allowed authored setup boundaries. No gameplay steps, settlement, schedule
# overrides, narrative cursor manipulation, or unrestricted system identities.
const AUTHORS: Dictionary = {
    "npc.register": "system:director",
    "npc.routine.create": "system:director",
    "social.player.place": "system:director",
    "social.fact.register": "system:director",
    "ingredient.define": "system:director",
    "stock.add": "system:director",
    "recipe.define": "system:director",
    "station.register": "system:director",
    "service.configure": "system:director",
    "service.demand.configure": "system:director",
    "housing.unit.register": "system:housing",
    "housing.roof.grant": "system:bootstrap",
    "home.type.define": "system:catalog",
    "home.object.grant": "system:bootstrap",
    "economy.recipe.price.set": "system:pricing",
    "economy.fund": "system:treasury"
}

static func _error(code: String, index: int = -1, cause: String = "") -> Dictionary:
    return {"ok": false, "code": code, "command_index": index, "cause": cause}

static func _exact(value: Dictionary, fields: Array) -> bool:
    if value.size() != fields.size(): return false
    for field in fields:
        if not value.has(field): return false
    return true

static func _valid_bundle_id(value: Variant) -> bool:
    return WorldState.valid_identity(value) and not (value as String).contains("..")

static func prepare(bundle: Variant, seed: int) -> Dictionary:
    if not WorldState.integral(seed, 1):
        return _error("INVALID_SEED")
    if typeof(bundle) != TYPE_DICTIONARY:
        return _error("INVALID_BUNDLE")
    if not _exact(bundle, ["schema", "bundle_id", "commands"]) or not WorldState.integral(bundle.get("schema"), 1) or int(bundle["schema"]) != FORMAT:
        return _error("UNSUPPORTED_BUNDLE_SCHEMA")
    if not _valid_bundle_id(bundle.get("bundle_id")):
        return _error("INVALID_BUNDLE_ID")
    if typeof(bundle.get("commands")) != TYPE_ARRAY or bundle["commands"].is_empty() or bundle["commands"].size() > MAX_COMMANDS:
        return _error("INVALID_COMMAND_LIST")
    var candidate: RefCounted = Kernel.new(seed)
    var seen: Dictionary = {}
    for index in range(bundle["commands"].size()):
        var raw: Variant = bundle["commands"][index]
        if typeof(raw) != TYPE_DICTIONARY or not _exact(raw, ["id", "kind", "actor_id", "payload"]):
            return _error("INVALID_ENTRY", index)
        var local_id: Variant = raw.get("id")
        var kind: Variant = raw.get("kind")
        var actor: Variant = raw.get("actor_id")
        var payload: Variant = raw.get("payload")
        if not WorldState.valid_identity(local_id) or not WorldState.valid_identity(kind) or not WorldState.valid_identity(actor) or typeof(payload) != TYPE_DICTIONARY or not WorldState._json_value(payload):
            return _error("INVALID_ENTRY", index)
        if seen.has(local_id):
            return _error("DUPLICATE_COMMAND_ID", index)
        seen[local_id] = true
        if not AUTHORS.has(kind) or actor != AUTHORS[kind]:
            return _error("DISALLOWED_AUTHORING_COMMAND", index)
        var command_id: String = "catalog:" + str(bundle["bundle_id"]) + ":" + str(local_id)
        if not WorldState.valid_identity(command_id):
            return _error("INVALID_SCOPED_COMMAND_ID", index)
        var result: Dictionary = candidate.dispatch({
            "id": command_id, "kind": kind, "actor_id": actor, "payload": payload
        })
        if not result.get("ok", false):
            return _error("BUNDLE_COMMAND_REJECTED", index, str(result.get("code", "UNKNOWN")))
    return {"ok": true, "code": "STAGED",
        "bundle_id": bundle["bundle_id"], "commands": bundle["commands"].size(),
        "revision": candidate.view()["sequence"], "candidate": candidate}

static func from_file(path: String, seed: int) -> Dictionary:
    # Only packaged, trusted and reviewable content is eligible to author a world.
    if not path.begins_with("res://content/world/") or path.contains("..") or not path.ends_with(".json"):
        return _error("UNTRUSTED_CONTENT_PATH")
    if not FileAccess.file_exists(path):
        return _error("CONTENT_NOT_FOUND")
    var source: String = FileAccess.get_file_as_string(path)
    if source.is_empty():
        return _error("INVALID_JSON")
    var decoded: Variant = JSON.parse_string(source)
    if typeof(decoded) != TYPE_DICTIONARY:
        return _error("INVALID_JSON")
    return prepare(decoded, seed)
