extends RefCounted
## PLAY C1 — authored presentation-space portals into canonical P2 player location.
## Physical coordinates here are ephemeral render/input state; no second world clock.
const WorldState = preload("res://scripts/core/world_state.gd")
const RADIUS: float = 38.0
const STEP: float = 18.0
const MAX_SIZE: int = 2000
var rooms: Dictionary = {}
var portals: Dictionary = {}
var anchors: Dictionary = {}
var graph_id: String = ""

static func fail(code: String) -> Dictionary:
    return {"ok": false, "code": code}

static func exact(p: Dictionary, keys: Array) -> bool:
    if p.size() != keys.size(): return false
    for k in keys:
        if not p.has(k): return false
    return true

static func ident(v: Variant) -> bool:
    return WorldState.valid_identity(v)

static func pos(v: Variant, w: int, h: int) -> bool:
    return typeof(v) == TYPE_ARRAY and v.size() == 2 and WorldState.integral(v[0]) and WorldState.integral(v[1]) and int(v[0]) >= 0 and int(v[0]) <= w and int(v[1]) >= 0 and int(v[1]) <= h

static func point(v: Array) -> Vector2:
    return Vector2(float(v[0]), float(v[1]))

static func from_data(raw: Variant) -> Dictionary:
    if typeof(raw) != TYPE_DICTIONARY or not exact(raw, ["schema", "graph_id", "rooms", "portals", "anchors"]):
        return fail("INVALID_GRAPH")
    if not WorldState.integral(raw["schema"], 1) or int(raw["schema"]) != 1 or not ident(raw["graph_id"]):
        return fail("UNSUPPORTED_GRAPH")
    if typeof(raw["rooms"]) != TYPE_ARRAY or raw["rooms"].is_empty() or raw["rooms"].size() > 32 or typeof(raw["portals"]) != TYPE_ARRAY or raw["portals"].size() > 128 or typeof(raw["anchors"]) != TYPE_ARRAY or raw["anchors"].size() > 64:
        return fail("INVALID_LISTS")
    var temp: RefCounted = load("res://scripts/integration/room_traversal.gd").new()
    temp.graph_id = raw["graph_id"]
    for room in raw["rooms"]:
        if typeof(room) != TYPE_DICTIONARY or not exact(room, ["id", "width", "height", "spawn"]) or not ident(room.get("id")):
            return fail("INVALID_ROOM")
        if not WorldState.integral(room.get("width"), 100, MAX_SIZE) or not WorldState.integral(room.get("height"), 100, MAX_SIZE):
            return fail("INVALID_ROOM_SIZE")
        if not pos(room["spawn"], int(room["width"]), int(room["height"])) or temp.rooms.has(room["id"]):
            return fail("INVALID_ROOM_SPAWN")
        temp.rooms[room["id"]] = room.duplicate(true)
    for portal in raw["portals"]:
        if typeof(portal) != TYPE_DICTIONARY or not exact(portal, ["id", "from", "to", "entry", "arrival", "unit_id"]) or not ident(portal.get("id")) or not ident(portal.get("from")) or not ident(portal.get("to")) or typeof(portal.get("unit_id")) != TYPE_STRING:
            return fail("INVALID_PORTAL")
        if temp.portals.has(portal["id"]) or not temp.rooms.has(portal["from"]) or not temp.rooms.has(portal["to"]) or portal["from"] == portal["to"]:
            return fail("INVALID_PORTAL_LINK")
        var a: Dictionary = temp.rooms[portal["from"]]
        var b: Dictionary = temp.rooms[portal["to"]]
        if not pos(portal["entry"], int(a["width"]), int(a["height"])) or not pos(portal["arrival"], int(b["width"]), int(b["height"])):
            return fail("INVALID_PORTAL_POINT")
        # Rights must be checked when ENTERING a registered unit, not leaving it.
        if not portal["unit_id"].is_empty() and not ident(portal["unit_id"]):
            return fail("INVALID_UNIT_ID")
        temp.portals[portal["id"]] = portal.duplicate(true)
    for anchor in raw["anchors"]:
        if typeof(anchor) != TYPE_DICTIONARY or not exact(anchor, ["npc_id", "room_id", "point"]) or not ident(anchor.get("npc_id")) or not ident(anchor.get("room_id")):
            return fail("INVALID_ANCHOR")
        if temp.anchors.has(anchor["npc_id"]) or not temp.rooms.has(anchor["room_id"]):
            return fail("INVALID_ANCHOR")
        var room: Dictionary = temp.rooms[anchor["room_id"]]
        if not pos(anchor["point"], int(room["width"]), int(room["height"])):
            return fail("INVALID_ANCHOR_POINT")
        temp.anchors[anchor["npc_id"]] = anchor.duplicate(true)
    return {"ok": true, "graph": temp}

static func load_packaged(path: String) -> Dictionary:
    if not path.begins_with("res://content/navigation/") or path.contains("..") or not path.ends_with(".json"):
        return fail("UNTRUSTED_GRAPH_PATH")
    if not FileAccess.file_exists(path):
        return fail("GRAPH_NOT_FOUND")
    return from_data(JSON.parse_string(FileAccess.get_file_as_string(path)))

func spawn_for(location: String) -> Dictionary:
    if not rooms.has(location): return fail("UNKNOWN_LOCATION")
    return {"ok": true, "location_id": location, "position": point(rooms[location]["spawn"])}

func move(location: String, origin: Vector2, delta: Vector2) -> Dictionary:
    if not rooms.has(location): return fail("UNKNOWN_LOCATION")
    if not origin.is_finite() or not delta.is_finite() or delta.length() > STEP + 0.00001:
        return fail("INVALID_MOVE")
    var room: Dictionary = rooms[location]
    var next: Vector2 = origin + delta
    if next.x < 0.0 or next.y < 0.0 or next.x > float(room["width"]) or next.y > float(room["height"]):
        return fail("WALL")
    return {"ok": true, "position": next}

func visible_exits(location: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var keys: Array = portals.keys()
    keys.sort()
    for key in keys:
        if portals[key]["from"] == location:
            result.append(portals[key].duplicate(true))
    return result

func travel(session: RefCounted, portal_id: String, physical_position: Vector2, command_id: String) -> Dictionary:
    if not portals.has(portal_id): return fail("UNKNOWN_PORTAL")
    var door: Dictionary = portals[portal_id]
    var current: String = str(session.world.social_view()["player_location"])
    if current != door["from"]: return fail("WRONG_ROOM")
    if not physical_position.is_finite() or physical_position.distance_to(point(door["entry"])) > RADIUS:
        return fail("TOO_FAR")
    if not door["unit_id"].is_empty():
        var units: Dictionary = session.world.housing_view()["units"]
        if not units.has(door["unit_id"]) or units[door["unit_id"]]["location_id"] != door["to"]:
            return fail("INVALID_UNIT_GATE")
        if not session.world.can_access_unit(door["unit_id"]):
            return fail("ACCESS_DENIED")
    var applied: Dictionary = session.command(command_id, "system:director", "social.player.place",
        {"location_id": door["to"]})
    if not applied.get("ok", false): return applied
    return {"ok": true, "code": "TRAVELLED", "receipt": applied,
        "location_id": door["to"], "position": point(door["arrival"])}

func nearby_npc(session: RefCounted, current: Vector2) -> Dictionary:
    var loc: String = str(session.world.social_view()["player_location"])
    var ids: Array = anchors.keys()
    ids.sort()
    for id in ids:
        var a: Dictionary = anchors[id]
        if a["room_id"] != loc or current.distance_to(point(a["point"])) > RADIUS:
            continue
        var npc: Dictionary = session.world.npc(id)
        if not npc.is_empty() and npc["location_id"] == loc:
            return {"ok": true, "npc_id": id}
    return fail("NO_NEARBY_NPC")

func overhear(session: RefCounted, current: Vector2, command_id: String) -> Dictionary:
    var target: Dictionary = nearby_npc(session, current)
    if not target.get("ok", false): return target
    var speaker: String = target["npc_id"]
    var facts: Dictionary = session.world.social_view()["social_facts"]
    var keys: Array = facts.keys()
    keys.sort()
    for fact_id in keys:
        var fact: Dictionary = facts[fact_id]
        if fact["source_npc_id"] != speaker or fact["visibility"] != "public" or session.world.player_knows(fact_id):
            continue
        var utterance: Dictionary = session.command(command_id, speaker, "social.speak",
            {"speaker_id": speaker, "fact_id": fact_id, "mode": "broadcast", "audience_ids": []})
        if not utterance.get("ok", false): return utterance
        return {"ok": true, "code": "HEARD", "npc_id": speaker, "fact_id": fact_id, "receipt": utterance}
    return fail("NO_AUTHORED_PUBLIC_FACT")
