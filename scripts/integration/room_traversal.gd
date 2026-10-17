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
const KioskNav = preload("res://scripts/integration/kiosk_navigation.gd")
var visit_spots: Dictionary = {}
var navigator: RefCounted
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

# P4's authentic order route determines only the NPC's presentation pose,
# not a second location authority or mutable simulated walking state.
func configure_visit_spots(raw: Variant) -> Dictionary:
    if typeof(raw) != TYPE_DICTIONARY or not exact(raw,
            ["schema", "venue_id", "room_id", "move_minutes", "route_points"]):
        return fail("INVALID_VISIT_SPOTS")
    if raw["schema"] != 1 or raw["venue_id"] != "kiosk" or not rooms.has(raw["room_id"]):
        return fail("INVALID_VISIT_SPOTS")
    if not WorldState.integral(raw["move_minutes"], 1, 10) or typeof(raw["route_points"]) != TYPE_DICTIONARY:
        return fail("INVALID_VISIT_SPOTS")
    var routes: Dictionary = raw["route_points"]
    if routes.size() != 3: return fail("INVALID_VISIT_SPOTS")
    var room: Dictionary = rooms[raw["room_id"]]
    for route in ["counter", "takeaway", "table"]:
        if not routes.has(route) or not pos(routes[route],int(room["width"]),int(room["height"])):
            return fail("INVALID_VISIT_SPOTS")
    visit_spots = raw.duplicate(true)
    return {"ok":true}

func configure_walkable(raw: Variant) -> Dictionary:
    if visit_spots.is_empty(): return fail("VISITS_NOT_CONFIGURED")
    var nav: RefCounted = KioskNav.new()
    var homes: Array = []
    var destinations: Array = []
    for npc in anchors:
        if anchors[npc]["room_id"] == visit_spots["room_id"]:
            homes.append(point(anchors[npc]["point"]))
    for route in ["counter","takeaway","table"]:
        destinations.append(point(visit_spots["route_points"][route]))
    var result: Dictionary = nav.configure(raw,rooms[visit_spots["room_id"]],homes,destinations)
    if not result.get("ok",false): return result
    if navigator != null: navigator.dispose()
    navigator = nav
    return {"ok":true}

func navigation_path(origin: Vector2, target: Vector2) -> PackedVector2Array:
    if navigator == null: return PackedVector2Array()
    return navigator.path_between(origin,target)

# Sample distances across Godot's navmesh path, not a straight line.
# P1 minute and P4 order state alone set temporal progress so reloads
# restore the same world-derived hearing and rendering position.
static func sample_path(path: PackedVector2Array, fraction: float) -> Vector2:
    if path.is_empty(): return Vector2.ZERO
    if path.size() == 1: return path[0]
    var total: float = 0.0
    for i in range(1,path.size()):
        total += path[i-1].distance_to(path[i])
    var remaining: float = total * clampf(fraction,0.0,1.0)
    for i in range(1,path.size()):
        var length: float = path[i-1].distance_to(path[i])
        if remaining <= length:
            return path[i-1].lerp(path[i],remaining/length) if length > 0.00001 else path[i]
        remaining -= length
    return path[path.size()-1]

func dispose_navigation() -> void:
    if navigator != null:
        navigator.dispose()
        navigator = null

func npc_pose(session: RefCounted, npc_id: String) -> Dictionary:
    if not anchors.has(npc_id): return {}
    var anchor: Dictionary = anchors[npc_id]
    var room_id: String = str(anchor["room_id"])
    if session.world.npc(npc_id).get("location_id","") != room_id:
        return {}
    var home: Vector2 = point(anchor["point"])
    var current: Vector2 = home
    var mode: String = "standing"
    var order_id: String = ""
    if not visit_spots.is_empty() and room_id == str(visit_spots["room_id"]):
        var orders: Dictionary = session.world.orders_view()["orders"]
        var latest: Dictionary = {}
        for o in orders.values():
            if o["npc_id"] != npc_id or o["venue_id"] != visit_spots["venue_id"]:
                continue
            if latest.is_empty() or int(o["offer_sequence"]) > int(latest["offer_sequence"]):
                latest = o
        if not latest.is_empty() and visit_spots["route_points"].has(latest["route"]):
            var destination: Vector2 = point(visit_spots["route_points"][latest["route"]])
            var duration: int = int(visit_spots["move_minutes"])
            var minute: int = int(session.world.view()["world_minute"])
            if latest["status"] in ["offered", "accepted"]:
                var progress: float = clampf(
                    float(minute-int(latest["created_minute"]))/float(duration),0.0,1.0)
                var route_path: PackedVector2Array = navigation_path(home,destination)
                if route_path.size() < 2: return {}
                current = sample_path(route_path,progress)
                mode = "approaching" if progress < 1.0 else str(latest["route"])
                order_id = str(latest["order_id"])
            elif int(latest["closed_minute"]) >= 0:
                var since: int = minute-int(latest["closed_minute"])
                if since >= 0 and since < duration:
                    var return_path: PackedVector2Array = navigation_path(destination,home)
                    if return_path.size() < 2: return {}
                    current = sample_path(return_path,float(since)/float(duration))
                    mode = "returning"
                    order_id = str(latest["order_id"])
    return {"npc_id":npc_id,"room_id":room_id,"position":current,
        "mode":mode,"order_id":order_id}

func nearby_npc(session: RefCounted, current: Vector2) -> Dictionary:
    var loc: String = str(session.world.social_view()["player_location"])
    var ids: Array = anchors.keys()
    ids.sort()
    for id in ids:
        var pose: Dictionary = npc_pose(session,str(id))
        if not pose.is_empty() and pose["room_id"] == loc and current.distance_to(pose["position"]) <= RADIUS:
            return {"ok":true,"npc_id":id}
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
