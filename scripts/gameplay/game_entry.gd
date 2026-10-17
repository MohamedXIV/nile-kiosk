extends RefCounted
## E6/P0: game entry adapter over the one canonical WorldSession.
## No scene-local cash, NPC, location, order, or clock authority.
const Session = preload("res://scripts/integration/world_session.gd")
const Graph = preload("res://scripts/integration/room_traversal.gd")
const Demand = preload("res://scripts/integration/customer_demand_config.gd")
const ServicePlay = preload("res://scripts/integration/kiosk_service_play.gd")
const CONTENT = "res://content/world/nile_opening.v1.json"
const ROUTES = "res://content/navigation/nile_opening_routes.v1.json"
const DEMAND = "res://content/service/nile_opening_demand.v1.json"
const DAILY_POLICY = "res://content/life/nile_opening.v1.json"
const QUIET_POLICY = "res://content/life/nile_quiet_activities.v1.json"
const DEFAULT_SAVE = "user://nile-kiosk-game-v1.json"
const START_MINUTE = 17 * 60  # Provisional opening moment, not an agreed schedule.
const COUNTER = Vector2(115, 80)
const COUNTER_RADIUS = 48.0

var session: RefCounted
var graph: RefCounted
var quiet_captions: Dictionary = {}

func start(save_path: String = DEFAULT_SAVE) -> Dictionary:
    session = Session.new(71, save_path)
    var existing: Dictionary = session.load_existing()
    if not existing.get("ok", false):
        return existing  # Never erase a corrupt or incompatible save.
    if existing["code"] == "NEW_WORLD":
        var boot: Dictionary = session.bootstrap_from_content(CONTENT)
        if not boot.get("ok", false): return boot
    var nav: Dictionary = session.configure_navigation(ROUTES)
    if not nav.get("ok", false): return nav
    var parsed: Dictionary = Graph.from_data(session.world.spatial_view()["graph"])
    if not parsed.get("ok", false): return parsed
    graph = parsed["graph"]
    if session.world.view()["life"]["policy"].is_empty():
        if not FileAccess.file_exists(DAILY_POLICY):
            return {"ok":false,"code":"DAILY_POLICY_NOT_FOUND"}
        var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DAILY_POLICY))
        if typeof(raw) != TYPE_DICTIONARY or raw.size() != 2 or raw.get("schema") != 1 or typeof(raw.get("policy")) != TYPE_DICTIONARY:
            return {"ok":false,"code":"INVALID_DAILY_POLICY"}
        var configured_life: Dictionary = session.command("game:life:configure", "system:director",
            "life.configure", raw["policy"])
        if not configured_life.get("ok",false): return configured_life
    if not FileAccess.file_exists(QUIET_POLICY):
        return {"ok":false,"code":"QUIET_POLICY_NOT_FOUND"}
    var quiet: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUIET_POLICY))
    if typeof(quiet) != TYPE_DICTIONARY or quiet.size() != 3 or quiet.get("schema") != 1 or typeof(quiet.get("activities")) != TYPE_ARRAY or typeof(quiet.get("captions")) != TYPE_DICTIONARY:
        return {"ok":false,"code":"INVALID_QUIET_POLICY"}
    quiet_captions = quiet["captions"].duplicate(true)
    if not session.world.view()["life"]["policy"].has("activities"):
        var configured_quiet: Dictionary = session.command("game:life:quiet:v1","system:director",
            "life.activities.configure",{"activities":quiet["activities"]})
        if not configured_quiet.get("ok",false): return configured_quiet
    if existing["code"] == "NEW_WORLD":
        var configured: Dictionary = Demand.configure(session, DEMAND)
        if not configured.get("ok", false): return configured
        var opening: Dictionary = session.advance(START_MINUTE, "game:opening:clock")
        if not opening.get("ok", false): return opening
    return {"ok": true, "code": existing["code"], "location": room()}

func room() -> String:
    return str(session.world.spatial_view()["player"]["room_id"])

func position() -> Vector2:
    var p: Dictionary = session.world.spatial_view()["player"]
    return Vector2(int(p["x"]), int(p["y"]))

func _id(action: String) -> String:
    return "game:e6:%s:%d" % [action, int(session.world.view()["sequence"]) + 1]

func move_world(dx: int, dy: int) -> Dictionary:
    return session.command(_id("move"), "player", "spatial.player.move", {"dx": dx, "dy": dy})

func move_screen(horizontal: int, vertical: int) -> Dictionary:
    if horizontal == 0 and vertical == 0:
        return {"ok": true, "code": "NO_OP"}
    # Screen-relative controls: W is up and D is right in the 2:1 projection.
    var world_direction: Vector2 = Vector2(horizontal + vertical, vertical - horizontal).normalized() * 17.0
    return move_world(roundi(world_direction.x), roundi(world_direction.y))

func nearest_portal() -> Dictionary:
    var nearest: Dictionary = {}
    var distance: float = INF
    for portal in graph.visible_exits(room()):
        var d: float = position().distance_to(Graph.point(portal["entry"]))
        if d <= Graph.RADIUS and (d < distance or (is_equal_approx(d, distance) and str(portal["id"]) < str(nearest.get("id","")))):
            nearest = portal
            distance = d
    return nearest.duplicate(true)

func travel_near() -> Dictionary:
    var portal: Dictionary = nearest_portal()
    if portal.is_empty(): return {"ok": false, "code": "NO_NEARBY_DOOR"}
    return session.command(_id("travel"), "player", "spatial.player.travel", {"portal_id":portal["id"]})

func listen_near() -> Dictionary:
    return graph.overhear(session, position(), _id("listen"))

func service_near() -> Dictionary:
    if not session.world.view()["life"]["open"]:
        return {"ok":false,"code":"KIOSK_CLOSED"}
    if room() != "kiosk":
        return {"ok":false,"code":"NOT_AT_KIOSK"}
    if position().distance_to(COUNTER) > COUNTER_RADIUS:
        return {"ok":false,"code":"COUNTER_TOO_FAR"}
    return ServicePlay.perform_next(session, "kiosk")

func open_kiosk() -> Dictionary:
    return session.command(_id("open"),"player","life.open",{})

func close_kiosk() -> Dictionary:
    return session.command(_id("close"),"player","life.close",{})

func sleep_at_home() -> Dictionary:
    return session.command(_id("sleep"),"player","life.sleep",{})

func quiet_activities() -> Array:
    return session.world.view()["life"]["policy"].get("activities",[])

func quiet_near() -> Dictionary:
    var current: Vector2 = position()
    var chosen: Dictionary = {}
    var nearest: float = INF
    for activity in quiet_activities():
        if activity["room_id"] != room(): continue
        var d: float = current.distance_to(Vector2(int(activity["x"]),int(activity["y"])))
        if d <= int(activity["radius"]) and d < nearest:
            chosen = activity
            nearest = d
    if chosen.is_empty(): return {"ok":false,"code":"NO_QUIET_SPOT_NEARBY"}
    var response: Dictionary = session.command(_id("quiet"),"player","life.activity",
        {"activity_id":chosen["id"]})
    if response.get("ok",false):
        response["activity_id"] = chosen["id"]
        response["caption"] = quiet_captions.get(chosen["id"],"A quiet moment passes.")
    return response

func wait_minutes(minutes: int = 5) -> Dictionary:
    if minutes < 1 or minutes > 5:
        return {"ok":false,"code":"INVALID_WAIT"}
    return session.advance(minutes, _id("wait"))

func save_game() -> Dictionary:
    return session.save()

func status() -> Dictionary:
    var v: Dictionary = session.world.view()
    var clock: Dictionary = session.world.calendar()
    var orders: Dictionary = v["service"]["orders"]
    var pending: Array[String] = []
    for key in orders:
        if orders[key]["status"] in ["offered","accepted","delivered"]:
            pending.append(str(key))
    pending.sort()
    var active: Dictionary = orders.get(pending[0], {}) if not pending.is_empty() else {}
    var last_quiet: String = ""
    var quiet_count: int = 0
    for event in v["events"]:
        if event["kind"] == "life.activity_done":
            quiet_count += 1
            last_quiet = str(event["payload"]["request"]["activity_id"])
    return {
        "location": room(),
        "x": int(position().x),
        "y": int(position().y),
        "minute": int(v["world_minute"]),
        "day": int(clock["day_index"]) + 1,
        "hour": int(clock["hour"]),
        "minute_of_hour": int(clock["minute"]),
        "money": session.world.balance_minor(),
        "revision": int(v["sequence"]),
        "digest": JSON.stringify(v).sha256_text(),
        "offer_count": orders.size(),
        "kiosk_open": bool(v["life"]["open"]),
        "sleep_count": int(v["life"]["sleep_count"]),
        "quiet_count": quiet_count,
        "last_quiet": last_quiet,
        "active_order": active.get("order_id",""),
        "order_status": active.get("status","none"),
        "npc_mahmoud": session.world.npc("mahmoud").get("location_id",""),
        "roof_access": session.world.can_access_unit("roof"),
        "flat_access": session.world.can_access_unit("flat")
    }

func dispose() -> void:
    if session != null:
        session.dispose()
