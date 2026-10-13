extends RefCounted
## PLAY C2: authoritative integer room pose and reviewed topology, replayed by Kernel.
const Graph = preload("res://scripts/integration/room_traversal.gd")
const STEP_SQ: int = 324
const RADIUS_SQ: int = 1444
var graph: Dictionary = {}
var player: Dictionary = {"room_id": "", "x": 0, "y": 0}

static func owns(kind: String) -> bool:
    return kind in ["spatial.initialize", "spatial.player.move", "spatial.player.travel"]

static func event_kind(kind: String) -> String:
    match kind:
        "spatial.initialize": return "spatial.initialized"
        "spatial.player.move": return "spatial.player_moved"
        "spatial.player.travel": return "spatial.player_travelled"
    return ""

static func command_kind(kind: String) -> String:
    match kind:
        "spatial.initialized": return "spatial.initialize"
        "spatial.player_moved": return "spatial.player.move"
        "spatial.player_travelled": return "spatial.player.travel"
    return ""

func initialized() -> bool:
    return not graph.is_empty()

func snapshot() -> Dictionary:
    return {"graph": graph.duplicate(true), "player": player.duplicate(true)}

static func fail(code: String) -> Dictionary:
    return {"ok": false, "code": code}

static func _keys(p: Dictionary, fields: Array) -> bool:
    if p.size() != fields.size(): return false
    for key in fields:
        if not p.has(key): return false
    return true

static func _square(x: int, y: int) -> int:
    return x * x + y * y

func plan(kind: String, payload: Dictionary, actor_id: String, society: RefCounted, housing: RefCounted) -> Dictionary:
    if kind == "spatial.initialize":
        if actor_id != "system:director" or not _keys(payload, ["graph"]):
            return fail("INVALID_AUTHOR")
        if initialized(): return fail("SPATIAL_ALREADY_INITIALIZED")
        var parsed: Dictionary = Graph.from_data(payload["graph"])
        if not parsed.get("ok", false): return fail(str(parsed.get("code", "INVALID_GRAPH")))
        var layout: RefCounted = parsed["graph"]
        var loc: String = society.player_location
        if not layout.rooms.has(loc): return fail("UNKNOWN_START_LOCATION")
        for door in layout.portals.values():
            if not door["unit_id"].is_empty():
                var unit: Dictionary = housing.units.get(door["unit_id"], {})
                if unit.is_empty() or unit["location_id"] != door["to"]:
                    return fail("INVALID_UNIT_GATE")
        for npc_id in layout.anchors:
            if not society.npcs.has(npc_id):
                return fail("UNKNOWN_ANCHOR_NPC")
        var spawn: Array = layout.rooms[loc]["spawn"]
        return {"ok": true, "effect": {"room_id": loc, "x": int(spawn[0]), "y": int(spawn[1])}}
    if not initialized(): return fail("SPATIAL_NOT_INITIALIZED")
    if actor_id != "player": return fail("INVALID_ACTOR")
    if player["room_id"] != society.player_location:
        return fail("SPATIAL_LOCATION_MISMATCH")
    if kind == "spatial.player.move":
        if not _keys(payload, ["dx","dy"]) or typeof(payload.get("dx")) != TYPE_INT or typeof(payload.get("dy")) != TYPE_INT:
            return fail("INVALID_DELTA")
        var dx: int = payload["dx"]
        var dy: int = payload["dy"]
        if absi(dx) > 18 or absi(dy) > 18 or (dx == 0 and dy == 0) or _square(dx, dy) > STEP_SQ:
            return fail("INVALID_DELTA")
        var room: Dictionary = {}
        for candidate in graph["rooms"]:
            if candidate["id"] == player["room_id"]:
                room = candidate
                break
        var x: int = int(player["x"]) + dx
        var y: int = int(player["y"]) + dy
        if x < 0 or y < 0 or x > int(room["width"]) or y > int(room["height"]):
            return fail("WALL")
        return {"ok": true, "effect": {"room_id": player["room_id"], "x": x, "y": y}}
    if kind == "spatial.player.travel":
        if not _keys(payload, ["portal_id"]) or typeof(payload.get("portal_id")) != TYPE_STRING:
            return fail("INVALID_PORTAL")
        var door: Dictionary = {}
        for candidate in graph["portals"]:
            if candidate["id"] == payload["portal_id"]:
                door = candidate
                break
        if door.is_empty(): return fail("UNKNOWN_PORTAL")
        if door["from"] != player["room_id"]: return fail("WRONG_ROOM")
        var dx: int = int(player["x"]) - int(door["entry"][0])
        var dy: int = int(player["y"]) - int(door["entry"][1])
        if _square(dx, dy) > RADIUS_SQ: return fail("TOO_FAR")
        if not door["unit_id"].is_empty() and not housing.allowed(door["unit_id"]):
            return fail("ACCESS_DENIED")
        return {"ok": true, "effect": {"room_id": door["to"], "x": int(door["arrival"][0]), "y": int(door["arrival"][1])}}
    return fail("UNKNOWN_COMMAND")

func apply_command(kind: String, payload: Dictionary, effect: Dictionary) -> void:
    if kind == "spatial.initialize":
        graph = payload["graph"].duplicate(true)
    player = effect.duplicate(true)
